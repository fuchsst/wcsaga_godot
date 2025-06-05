class_name DistanceCuller
extends Node

## Distance-based object culling system for physics optimization.
## Implements physics culling for very distant or inactive objects to maintain 60 FPS performance.
## 
## This system is part of OBJ-007 requirements for physics step integration and performance optimization.

signal object_culled(object: Node3D, distance: float)
signal object_unculled(object: Node3D, distance: float)
signal culling_stats_updated(stats: Dictionary)

# Configuration
@export var culling_distance: float = 50000.0  # Distance beyond which objects are culled
@export var unculling_distance: float = 45000.0  # Distance at which objects are unculled (hysteresis)
@export var culling_check_interval: float = 0.5  # How often to check culling (seconds)
@export var enable_frustum_culling: bool = true
@export var enable_distance_culling: bool = true

# Object tracking
var tracked_objects: Dictionary = {}  # Node3D -> CullingData
var culled_objects: Array[Node3D] = []
var active_objects: Array[Node3D] = []

# Reference points for culling calculations
var player_position: Vector3 = Vector3.ZERO
var camera_position: Vector3 = Vector3.ZERO
var camera_transform: Transform3D = Transform3D.IDENTITY

# Performance monitoring
var culling_check_timer: float = 0.0
var last_culling_time_ms: float = 0.0
var objects_culled_this_frame: int = 0
var objects_unculled_this_frame: int = 0

# State management
var is_initialized: bool = false
var is_enabled: bool = true

class CullingData:
	var object: Node3D
	var last_distance: float
	var is_culled: bool
	var culling_reason: String
	var last_check_time: float
	var original_physics_enabled: bool
	
	func _init(obj: Node3D) -> void:
		object = obj
		last_distance = 0.0
		is_culled = false
		culling_reason = ""
		last_check_time = 0.0
		original_physics_enabled = true

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_culler()

func _initialize_culler() -> void:
	"""Initialize the distance culler system."""
	if is_initialized:
		push_warning("DistanceCuller: Already initialized")
		return
	
	print("DistanceCuller: Starting initialization...")
	
	# Initialize arrays and dictionaries
	tracked_objects.clear()
	culled_objects.clear()
	active_objects.clear()
	
	is_initialized = true
	print("DistanceCuller: Initialization complete")

func _process(delta: float) -> void:
	if not is_initialized or not is_enabled:
		return
	
	culling_check_timer += delta
	
	# Perform culling checks at specified intervals
	if culling_check_timer >= culling_check_interval:
		culling_check_timer = 0.0
		_perform_culling_check()

func _perform_culling_check() -> void:
	"""Perform distance and frustum culling checks on all tracked objects."""
	var culling_start_time: float = Time.get_ticks_usec() / 1000.0
	
	objects_culled_this_frame = 0
	objects_unculled_this_frame = 0
	
	for object in tracked_objects.keys():
		if not is_instance_valid(object):
			continue
		
		var culling_data: CullingData = tracked_objects[object]
		_check_object_culling(object, culling_data)
	
	var culling_end_time: float = Time.get_ticks_usec() / 1000.0
	last_culling_time_ms = culling_end_time - culling_start_time
	
	# Emit statistics update
	var stats: Dictionary = _get_culling_stats()
	culling_stats_updated.emit(stats)

func _check_object_culling(object: Node3D, culling_data: CullingData) -> void:
	"""Check if an object should be culled or unculled."""
	# Calculate distance to player
	var distance: float = object.global_position.distance_to(player_position)
	culling_data.last_distance = distance
	culling_data.last_check_time = Time.get_time_dict_from_system()["unix"]
	
	var should_cull: bool = false
	var culling_reason: String = ""
	
	# Distance culling check
	if enable_distance_culling:
		if not culling_data.is_culled and distance > culling_distance:
			should_cull = true
			culling_reason = "distance"
		elif culling_data.is_culled and distance < unculling_distance:
			should_cull = false
			culling_reason = "distance_return"
	
	# Frustum culling check (if enabled)
	if enable_frustum_culling and not should_cull:
		if _is_outside_camera_frustum(object):
			# Only frustum cull if also far away to avoid culling nearby objects
			if distance > culling_distance * 0.5:
				should_cull = true
				culling_reason = "frustum"
	
	# Apply culling changes
	if should_cull != culling_data.is_culled:
		if should_cull:
			_cull_object(object, culling_data, culling_reason)
		else:
			_uncull_object(object, culling_data)

func _is_outside_camera_frustum(object: Node3D) -> bool:
	"""Check if object is outside the camera frustum."""
	# Simplified frustum check - in a full implementation this would use
	# proper frustum planes calculation
	var camera_to_object: Vector3 = object.global_position - camera_position
	var camera_forward: Vector3 = -camera_transform.basis.z
	
	# Check if object is behind camera
	if camera_to_object.dot(camera_forward) < 0:
		return true
	
	# Additional frustum checks could be added here
	return false

func _cull_object(object: Node3D, culling_data: CullingData, reason: String) -> void:
	"""Cull an object by disabling its physics and other expensive operations."""
	if culling_data.is_culled:
		return
	
	culling_data.is_culled = true
	culling_data.culling_reason = reason
	
	# Store original physics state
	if object.has_method("is_physics_enabled"):
		culling_data.original_physics_enabled = object.is_physics_enabled()
	
	# Disable physics processing
	if object.has_method("set_physics_enabled"):
		object.set_physics_enabled(false)
	
	# Disable other expensive operations
	if object.has_method("set_processing_enabled"):
		object.set_processing_enabled(false)
	
	# For RigidBody3D objects, set to sleep mode
	if object is RigidBody3D:
		var rigid_body: RigidBody3D = object as RigidBody3D
		rigid_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rigid_body.freeze = true
	
	# Move from active to culled list
	if active_objects.has(object):
		active_objects.erase(object)
	if not culled_objects.has(object):
		culled_objects.append(object)
	
	objects_culled_this_frame += 1
	object_culled.emit(object, culling_data.last_distance)
	
	print("DistanceCuller: Culled object (reason: %s, distance: %.2f)" % [reason, culling_data.last_distance])

func _uncull_object(object: Node3D, culling_data: CullingData) -> void:
	"""Uncull an object by re-enabling its operations."""
	if not culling_data.is_culled:
		return
	
	culling_data.is_culled = false
	culling_data.culling_reason = ""
	
	# Restore physics processing
	if object.has_method("set_physics_enabled"):
		object.set_physics_enabled(culling_data.original_physics_enabled)
	
	# Re-enable other operations
	if object.has_method("set_processing_enabled"):
		object.set_processing_enabled(true)
	
	# For RigidBody3D objects, restore normal physics mode
	if object is RigidBody3D:
		var rigid_body: RigidBody3D = object as RigidBody3D
		rigid_body.freeze = false
		rigid_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC  # Or appropriate mode
	
	# Move from culled to active list
	if culled_objects.has(object):
		culled_objects.erase(object)
	if not active_objects.has(object):
		active_objects.append(object)
	
	objects_unculled_this_frame += 1
	object_unculled.emit(object, culling_data.last_distance)
	
	print("DistanceCuller: Unculled object (distance: %.2f)" % culling_data.last_distance)

func _get_culling_stats() -> Dictionary:
	"""Get current culling statistics."""
	var total_objects: int = tracked_objects.size()
	var culled_count: int = culled_objects.size()
	var active_count: int = active_objects.size()
	
	return {
		"total_tracked": total_objects,
		"culled_count": culled_count,
		"active_count": active_count,
		"culling_ratio": float(culled_count) / max(total_objects, 1),
		"objects_culled_this_check": objects_culled_this_frame,
		"objects_unculled_this_check": objects_unculled_this_frame,
		"last_culling_time_ms": last_culling_time_ms,
		"culling_distance": culling_distance,
		"unculling_distance": unculling_distance,
		"check_interval": culling_check_interval
	}

# Public API

func register_object(object: Node3D) -> bool:
	"""Register an object for distance culling.
	
	Args:
		object: Node3D object to manage
		
	Returns:
		true if registration successful
	"""
	if not is_instance_valid(object):
		push_error("DistanceCuller: Cannot register invalid object")
		return false
	
	if tracked_objects.has(object):
		push_warning("DistanceCuller: Object already registered")
		return false
	
	var culling_data: CullingData = CullingData.new(object)
	tracked_objects[object] = culling_data
	
	# Add to active objects initially
	if not active_objects.has(object):
		active_objects.append(object)
	
	print("DistanceCuller: Registered object for culling")
	return true

func unregister_object(object: Node3D) -> void:
	"""Unregister an object from distance culling.
	
	Args:
		object: Node3D object to unregister
	"""
	if not tracked_objects.has(object):
		return
	
	var culling_data: CullingData = tracked_objects[object]
	
	# Uncull object if it was culled
	if culling_data.is_culled:
		_uncull_object(object, culling_data)
	
	# Remove from all lists
	active_objects.erase(object)
	culled_objects.erase(object)
	tracked_objects.erase(object)
	
	print("DistanceCuller: Unregistered object from culling")

func set_player_position(position: Vector3) -> void:
	"""Set the player position for distance calculations.
	
	Args:
		position: Current player position
	"""
	player_position = position

func set_camera_position(position: Vector3) -> void:
	"""Set the camera position for frustum culling.
	
	Args:
		position: Current camera position
	"""
	camera_position = position

func set_camera_transform(transform: Transform3D) -> void:
	"""Set the camera transform for frustum culling.
	
	Args:
		transform: Current camera transform
	"""
	camera_transform = transform

func get_culling_distance() -> float:
	"""Get the current culling distance.
	
	Returns:
		Current culling distance
	"""
	return culling_distance

func set_culling_distance(distance: float) -> void:
	"""Set the culling distance.
	
	Args:
		distance: New culling distance
	"""
	culling_distance = distance
	unculling_distance = distance * 0.9  # Maintain hysteresis
	print("DistanceCuller: Set culling distance to %.2f" % distance)

func is_object_culled(object: Node3D) -> bool:
	"""Check if an object is currently culled.
	
	Args:
		object: Node3D to query
		
	Returns:
		true if object is culled
	"""
	if tracked_objects.has(object):
		return tracked_objects[object].is_culled
	
	return false

func get_object_distance(object: Node3D) -> float:
	"""Get the last calculated distance of an object to the player.
	
	Args:
		object: Node3D to query
		
	Returns:
		Last calculated distance, or 0.0 if not tracked
	"""
	if tracked_objects.has(object):
		return tracked_objects[object].last_distance
	
	return 0.0

func get_culling_stats() -> Dictionary:
	"""Get current culling statistics.
	
	Returns:
		Dictionary containing culling metrics
	"""
	return _get_culling_stats()

func set_enabled(enabled: bool) -> void:
	"""Enable or disable distance culling.
	
	Args:
		enabled: true to enable culling
	"""
	is_enabled = enabled
	
	# If disabling, uncull all objects
	if not enabled:
		for object in culled_objects.duplicate():
			if tracked_objects.has(object):
				_uncull_object(object, tracked_objects[object])
	
	print("DistanceCuller: %s" % ("enabled" if enabled else "disabled"))

func is_enabled() -> bool:
	"""Check if distance culling is enabled.
	
	Returns:
		true if culling is enabled
	"""
	return is_enabled

func force_culling_check() -> void:
	"""Force an immediate culling check for all objects (for testing)."""
	_perform_culling_check()
	print("DistanceCuller: Forced culling check completed")

# Debug functions

func debug_print_culling_stats() -> void:
	"""Print current culling statistics for debugging."""
	var stats: Dictionary = get_culling_stats()
	
	print("=== Distance Culler Statistics ===")
	print("Total tracked objects: %d" % stats.get("total_tracked", 0))
	print("Active objects: %d" % stats.get("active_count", 0))
	print("Culled objects: %d" % stats.get("culled_count", 0))
	print("Culling ratio: %.2f%%" % (stats.get("culling_ratio", 0.0) * 100.0))
	print("Objects culled this check: %d" % stats.get("objects_culled_this_check", 0))
	print("Objects unculled this check: %d" % stats.get("objects_unculled_this_check", 0))
	print("Last culling time: %.2fms" % stats.get("last_culling_time_ms", 0.0))
	print("Culling distance: %.2f" % stats.get("culling_distance", 0.0))
	print("Unculling distance: %.2f" % stats.get("unculling_distance", 0.0))
	print("Check interval: %.2fs" % stats.get("check_interval", 0.0))
	print("Distance culling: %s" % ("enabled" if enable_distance_culling else "disabled"))
	print("Frustum culling: %s" % ("enabled" if enable_frustum_culling else "disabled"))
	print("===================================")

func debug_list_culled_objects() -> void:
	"""List all currently culled objects for debugging."""
	print("=== Culled Objects ===")
	for object in culled_objects:
		if tracked_objects.has(object):
			var culling_data: CullingData = tracked_objects[object]
			print("Object: %s, Distance: %.2f, Reason: %s" % [
				object.name, 
				culling_data.last_distance, 
				culling_data.culling_reason
			])
	print("Total culled: %d" % culled_objects.size())
	print("======================")