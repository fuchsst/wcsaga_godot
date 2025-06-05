class_name PhysicsCuller
extends Node

## Physics Culling System for Distance-Based Optimization
##
## Automatically disables physics simulation for objects that are too far away 
## to impact gameplay, improving performance by reducing physics calculations.
## Based on WCS optimization patterns and modern LOD techniques.
##
## Key features:
## - Distance-based physics culling with hysteresis
## - View frustum considerations for camera-relative optimization  
## - Smart re-activation when objects become relevant again
## - Separate culling rules for different object types
## - Performance monitoring and adaptive thresholds

# EPIC-002 Asset Core Integration - MANDATORY
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

signal object_culled(object: Node3D, reason: String)
signal object_unculled(object: Node3D, reason: String)
signal culling_thresholds_adjusted(new_thresholds: Dictionary)

# Culling Configuration
@export_group("Culling Distances")
@export var default_cull_distance: float = 20000.0        # Default culling distance
@export var weapon_cull_distance: float = 5000.0          # Weapons cull closer (short lifetime)
@export var debris_cull_distance: float = 15000.0         # Debris culls at medium distance
@export var capital_cull_distance: float = 50000.0        # Capital ships cull farther out
@export var effect_cull_distance: float = 10000.0         # Effects cull at medium distance

@export_group("Hysteresis")
@export var uncull_hysteresis_factor: float = 0.8         # Uncull at 80% of cull distance
@export var emergency_cull_factor: float = 0.5            # Emergency cull at 50% of normal distance

@export_group("Performance Optimization")
@export var enable_view_frustum_culling: bool = true      # Enable camera-based culling
@export var enable_adaptive_thresholds: bool = true       # Automatically adjust thresholds
@export var performance_check_interval: float = 2.0       # How often to check performance
@export var target_culled_ratio: float = 0.3              # Target 30% of objects culled

# Object tracking
var registered_objects: Dictionary = {}                   # object_id -> CullData
var culled_objects: Dictionary = {}                       # object_id -> CullData (culled objects)
var player_position: Vector3 = Vector3.ZERO
var camera_position: Vector3 = Vector3.ZERO
var camera_forward: Vector3 = Vector3.FORWARD

# Performance tracking
var last_performance_check: float = 0.0
var culling_operations_per_frame: int = 0
var total_objects_registered: int = 0
var total_objects_culled: int = 0

# Cull Data Structure
class CullData:
	var object: Node3D
	var object_type: ObjectTypes.Type
	var cull_distance: float
	var uncull_distance: float
	var last_distance: float
	var is_culled: bool
	var cull_reason: String
	var last_check_time: float
	var never_cull: bool  # For critical objects that should never be culled

	func _init(obj: Node3D, obj_type: ObjectTypes.Type, cull_dist: float) -> void:
		object = obj
		object_type = obj_type
		cull_distance = cull_dist
		uncull_distance = cull_dist * 0.8  # Default hysteresis
		last_distance = 0.0
		is_culled = false
		cull_reason = ""
		last_check_time = 0.0
		never_cull = false

func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	print("PhysicsCuller: Initialized with adaptive thresholds %s" % ("enabled" if enable_adaptive_thresholds else "disabled"))

func _process(delta: float) -> void:
	# Reset per-frame counters
	culling_operations_per_frame = 0
	
	# Check for adaptive threshold adjustments
	if enable_adaptive_thresholds:
		var current_time: float = Time.get_ticks_msec() / 1000.0
		if current_time - last_performance_check >= performance_check_interval:
			_check_adaptive_thresholds()
			last_performance_check = current_time

func _physics_process(delta: float) -> void:
	# Update culling states for all registered objects
	_update_culling_states()

## Register object for physics culling management
func register_object(object: Node3D, object_type: ObjectTypes.Type) -> bool:
	"""Register an object for physics culling management.
	
	Args:
		object: Node3D object to register
		object_type: Object type for culling distance determination
		
	Returns:
		true if registration successful
	"""
	if not is_instance_valid(object):
		push_error("PhysicsCuller: Cannot register invalid object")
		return false
	
	if not object.has_method("get_object_id"):
		push_error("PhysicsCuller: Object must implement get_object_id() method")
		return false
	
	var object_id: int = object.get_object_id()
	if object_id in registered_objects:
		push_warning("PhysicsCuller: Object already registered: %d" % object_id)
		return false
	
	# Determine appropriate cull distance for object type
	var cull_distance: float = _get_cull_distance_for_type(object_type)
	
	# Create cull data
	var cull_data: CullData = CullData.new(object, object_type, cull_distance)
	
	# Set hysteresis
	cull_data.uncull_distance = cull_distance * uncull_hysteresis_factor
	
	# Check if object should never be culled
	cull_data.never_cull = _should_never_cull(object, object_type)
	
	registered_objects[object_id] = cull_data
	total_objects_registered += 1
	
	print("PhysicsCuller: Registered object %d (type: %s, cull distance: %.1f)" % [
		object_id, ObjectTypes.Type.keys()[object_type], cull_distance
	])
	return true

## Unregister object from physics culling
func unregister_object(object: Node3D) -> void:
	"""Unregister an object from physics culling management.
	
	Args:
		object: Node3D object to unregister
	"""
	if not is_instance_valid(object) or not object.has_method("get_object_id"):
		return
	
	var object_id: int = object.get_object_id()
	
	# Remove from registered objects
	if object_id in registered_objects:
		var cull_data: CullData = registered_objects[object_id]
		if cull_data.is_culled:
			_uncull_object(cull_data, "UNREGISTERED")
		registered_objects.erase(object_id)
		total_objects_registered -= 1
	
	# Remove from culled objects
	if object_id in culled_objects:
		culled_objects.erase(object_id)

## Set player position for distance calculations
func set_player_position(position: Vector3) -> void:
	"""Set player position for distance-based culling calculations.
	
	Args:
		position: Current player world position
	"""
	player_position = position

## Set camera position and orientation for view frustum culling
func set_camera_transform(position: Vector3, forward: Vector3) -> void:
	"""Set camera transform for view frustum culling.
	
	Args:
		position: Current camera world position
		forward: Camera forward direction vector
	"""
	camera_position = position
	camera_forward = forward.normalized()

## Update culling states for all registered objects
func _update_culling_states() -> void:
	"""Update culling states for all registered objects."""
	for object_id in registered_objects:
		var cull_data: CullData = registered_objects[object_id]
		
		if not is_instance_valid(cull_data.object):
			# Clean up invalid objects
			registered_objects.erase(object_id)
			total_objects_registered -= 1
			continue
		
		# Skip objects that should never be culled
		if cull_data.never_cull:
			continue
		
		# Calculate distance to player
		var distance_to_player: float = cull_data.object.global_position.distance_to(player_position)
		cull_data.last_distance = distance_to_player
		cull_data.last_check_time = Time.get_ticks_msec() / 1000.0
		
		# Determine if culling state should change
		var should_cull: bool = _should_cull_object(cull_data, distance_to_player)
		
		if should_cull and not cull_data.is_culled:
			_cull_object(cull_data, "DISTANCE")
		elif not should_cull and cull_data.is_culled:
			_uncull_object(cull_data, "DISTANCE")
		
		culling_operations_per_frame += 1

## Determine if object should be culled
func _should_cull_object(cull_data: CullData, distance: float) -> bool:
	"""Determine if an object should be culled based on various factors.
	
	Args:
		cull_data: Object cull data
		distance: Distance to player
		
	Returns:
		true if object should be culled
	"""
	# Use hysteresis to prevent thrashing
	var threshold: float = cull_data.cull_distance if not cull_data.is_culled else cull_data.uncull_distance
	
	# Basic distance check
	if distance > threshold:
		return true
	
	# View frustum culling (if enabled)
	if enable_view_frustum_culling and not cull_data.is_culled:
		if _is_behind_camera(cull_data.object.global_position):
			# Additional distance penalty for objects behind camera
			return distance > (threshold * 0.7)
	
	return false

## Check if position is behind camera
func _is_behind_camera(position: Vector3) -> bool:
	"""Check if a position is behind the camera.
	
	Args:
		position: World position to check
		
	Returns:
		true if position is behind camera
	"""
	var to_position: Vector3 = (position - camera_position).normalized()
	return to_position.dot(camera_forward) < 0.0

## Cull an object (disable physics)
func _cull_object(cull_data: CullData, reason: String) -> void:
	"""Disable physics for an object (cull it).
	
	Args:
		cull_data: Object cull data
		reason: Reason for culling (for debugging)
	"""
	if cull_data.is_culled:
		return
	
	cull_data.is_culled = true
	cull_data.cull_reason = reason
	
	# Disable physics on the object
	if cull_data.object.has_method("set_physics_enabled"):
		cull_data.object.set_physics_enabled(false)
	elif cull_data.object is RigidBody3D:
		var rigid_body: RigidBody3D = cull_data.object as RigidBody3D
		rigid_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rigid_body.freeze = true
	
	# Move to culled objects dictionary
	var object_id: int = cull_data.object.get_object_id()
	culled_objects[object_id] = cull_data
	total_objects_culled += 1
	
	object_culled.emit(cull_data.object, reason)

## Uncull an object (re-enable physics)
func _uncull_object(cull_data: CullData, reason: String) -> void:
	"""Re-enable physics for an object (uncull it).
	
	Args:
		cull_data: Object cull data
		reason: Reason for unculling (for debugging)
	"""
	if not cull_data.is_culled:
		return
	
	cull_data.is_culled = false
	cull_data.cull_reason = ""
	
	# Re-enable physics on the object
	if cull_data.object.has_method("set_physics_enabled"):
		cull_data.object.set_physics_enabled(true)
	elif cull_data.object is RigidBody3D:
		var rigid_body: RigidBody3D = cull_data.object as RigidBody3D
		rigid_body.freeze = false
	
	# Remove from culled objects dictionary
	var object_id: int = cull_data.object.get_object_id()
	if object_id in culled_objects:
		culled_objects.erase(object_id)
	total_objects_culled -= 1
	
	object_unculled.emit(cull_data.object, reason)

## Get cull distance for object type
func _get_cull_distance_for_type(object_type: ObjectTypes.Type) -> float:
	"""Get appropriate cull distance for an object type.
	
	Args:
		object_type: Object type enum
		
	Returns:
		Cull distance for the object type
	"""
	match object_type:
		ObjectTypes.Type.WEAPON:
			return weapon_cull_distance
		ObjectTypes.Type.DEBRIS:
			return debris_cull_distance
		ObjectTypes.Type.CAPITAL:
			return capital_cull_distance
		ObjectTypes.Type.EFFECT:
			return effect_cull_distance
		ObjectTypes.Type.FIGHTER, ObjectTypes.Type.BOMBER, ObjectTypes.Type.SUPPORT:
			return default_cull_distance
		_:
			return default_cull_distance

## Check if object should never be culled
func _should_never_cull(object: Node3D, object_type: ObjectTypes.Type) -> bool:
	"""Determine if an object should never be culled.
	
	Args:
		object: Object to check
		object_type: Object type
		
	Returns:
		true if object should never be culled
	"""
	# Never cull the player
	if object.has_method("is_player") and object.is_player():
		return true
	
	# Never cull objects in active combat
	if object.has_method("get_engagement_status"):
		var engagement_status: String = object.get_engagement_status()
		if engagement_status == "ACTIVE_COMBAT":
			return true
	
	# Never cull critical mission objects
	if object.has_method("is_mission_critical") and object.is_mission_critical():
		return true
	
	return false

## Check and adjust adaptive thresholds
func _check_adaptive_thresholds() -> void:
	"""Check performance and adjust culling thresholds adaptively."""
	var total_objects: int = total_objects_registered
	var culled_objects_count: int = total_objects_culled
	
	if total_objects == 0:
		return
	
	var current_culled_ratio: float = float(culled_objects_count) / float(total_objects)
	
	# Adjust thresholds based on performance
	var fps_samples: Array[float] = []
	if has_node("/root/LODManager"):
		var lod_manager = get_node("/root/LODManager")
		var performance_stats: Dictionary = lod_manager.get_performance_stats()
		var avg_fps: float = performance_stats.get("average_frame_rate", 60.0)
		
		# If FPS is low and we're not culling enough, reduce cull distances
		if avg_fps < 50.0 and current_culled_ratio < target_culled_ratio:
			_adjust_cull_distances(0.9)  # Reduce by 10%
		# If FPS is good and we're culling too much, increase cull distances
		elif avg_fps > 55.0 and current_culled_ratio > (target_culled_ratio + 0.1):
			_adjust_cull_distances(1.1)  # Increase by 10%

## Adjust all cull distances by a factor
func _adjust_cull_distances(factor: float) -> void:
	"""Adjust all cull distances by a multiplication factor.
	
	Args:
		factor: Multiplication factor for cull distances
	"""
	default_cull_distance *= factor
	weapon_cull_distance *= factor
	debris_cull_distance *= factor
	capital_cull_distance *= factor
	effect_cull_distance *= factor
	
	# Update existing registered objects
	for object_id in registered_objects:
		var cull_data: CullData = registered_objects[object_id]
		cull_data.cull_distance *= factor
		cull_data.uncull_distance = cull_data.cull_distance * uncull_hysteresis_factor
	
	var new_thresholds: Dictionary = {
		"default": default_cull_distance,
		"weapon": weapon_cull_distance,
		"debris": debris_cull_distance,
		"capital": capital_cull_distance,
		"effect": effect_cull_distance
	}
	
	culling_thresholds_adjusted.emit(new_thresholds)
	print("PhysicsCuller: Adjusted cull distances by factor %.2f" % factor)

## Force emergency culling to improve performance
func force_emergency_culling() -> int:
	"""Force emergency culling to improve performance immediately.
	
	Returns:
		Number of objects that were emergency culled
	"""
	var emergency_culled: int = 0
	
	for object_id in registered_objects:
		var cull_data: CullData = registered_objects[object_id]
		
		if cull_data.is_culled or cull_data.never_cull:
			continue
		
		# Apply emergency cull factor
		var emergency_threshold: float = cull_data.cull_distance * emergency_cull_factor
		
		if cull_data.last_distance > emergency_threshold:
			_cull_object(cull_data, "EMERGENCY")
			emergency_culled += 1
	
	print("PhysicsCuller: Emergency culling performed - %d objects culled" % emergency_culled)
	return emergency_culled

## Get performance statistics
func get_performance_stats() -> Dictionary:
	"""Get current physics culler performance statistics.
	
	Returns:
		Dictionary containing performance data
	"""
	var culled_ratio: float = 0.0
	if total_objects_registered > 0:
		culled_ratio = float(total_objects_culled) / float(total_objects_registered)
	
	return {
		"total_objects_registered": total_objects_registered,
		"total_objects_culled": total_objects_culled,
		"culled_ratio": culled_ratio,
		"target_culled_ratio": target_culled_ratio,
		"culling_operations_per_frame": culling_operations_per_frame,
		"adaptive_thresholds_enabled": enable_adaptive_thresholds,
		"view_frustum_culling_enabled": enable_view_frustum_culling,
		"cull_distances": {
			"default": default_cull_distance,
			"weapon": weapon_cull_distance,
			"debris": debris_cull_distance,
			"capital": capital_cull_distance,
			"effect": effect_cull_distance
		}
	}