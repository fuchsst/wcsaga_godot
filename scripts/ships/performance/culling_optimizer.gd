class_name CullingOptimizer
extends Node

## SHIP-016 AC4: Culling Optimizer with spatial partitioning and off-screen object management
## Disables unnecessary calculations for off-screen ships and distant objects with spatial partitioning
## Implements frustum culling, distance culling, and occlusion optimization

signal objects_culled(category: String, culled_count: int, total_count: int)
signal spatial_partition_updated(partition_count: int, objects_redistributed: int)
signal culling_mode_changed(new_mode: CullingMode, objects_affected: int)
signal performance_optimization_applied(optimization_type: String, objects_affected: int, performance_gain: float)

# Culling configuration
@export var enable_culling_system: bool = true
@export var culling_update_frequency: float = 0.1  # 10 times per second
@export var spatial_partition_size: float = 1000.0  # Size of each spatial partition
@export var frustum_culling_enabled: bool = true
@export var distance_culling_enabled: bool = true
@export var occlusion_culling_enabled: bool = false  # Expensive, off by default

# Culling modes
enum CullingMode {
	DISABLED,           # No culling
	BASIC,              # Simple frustum and distance culling
	ADVANCED,           # Full culling with spatial partitioning
	AGGRESSIVE,         # Maximum culling for performance
	AUTOMATIC           # Adaptive culling based on performance
}

# Distance thresholds for different object types
var culling_distances: Dictionary = {
	"ship": 5000.0,
	"projectile": 3000.0,
	"effect": 1500.0,
	"debris": 1000.0,
	"audio": 800.0,
	"ui_element": 100.0
}

# Current culling state
var current_culling_mode: CullingMode = CullingMode.ADVANCED
var active_camera: Camera3D = null
var camera_frustum: Array[Plane] = []
var camera_position: Vector3 = Vector3.ZERO
var camera_forward: Vector3 = Vector3.FORWARD

# Spatial partitioning system
var spatial_partitions: Dictionary = {}  # Vector3i -> SpatialPartition
var partition_update_queue: Array[Vector3i] = []
var objects_by_partition: Dictionary = {}  # Node -> Vector3i

# Culling management
var cullable_objects: Dictionary = {}  # Node -> CullableObject
var culling_update_timer: float = 0.0
var last_camera_position: Vector3 = Vector3.ZERO
var camera_movement_threshold: float = 50.0

# Performance tracking
var culling_statistics: Dictionary = {
	"total_objects": 0,
	"culled_objects": 0,
	"visible_objects": 0,
	"partitions_active": 0,
	"culling_time_ms": 0.0,
	"performance_gain": 0.0
}

# Spatial partition class
class SpatialPartition:
	var partition_id: Vector3i
	var center_position: Vector3
	var bounds: AABB
	var objects: Array[Node] = []
	var last_update_time: float = 0.0
	var is_visible: bool = true
	var visibility_check_frame: int = 0
	
	func _init(id: Vector3i, size: float) -> void:
		partition_id = id
		center_position = Vector3(id.x * size, id.y * size, id.z * size)
		bounds = AABB(center_position - Vector3.ONE * size * 0.5, Vector3.ONE * size)
	
	func add_object(obj: Node) -> void:
		if not objects.has(obj):
			objects.append(obj)
	
	func remove_object(obj: Node) -> void:
		var index: int = objects.find(obj)
		if index != -1:
			objects.remove_at(index)
	
	func is_empty() -> bool:
		return objects.is_empty()

# Cullable object data
class CullableObject:
	var node: Node3D
	var object_type: String
	var culling_distance: float
	var last_visible: bool = true
	var last_distance: float = 0.0
	var importance_multiplier: float = 1.0
	var force_visible: bool = false
	var bounds: AABB
	var last_culling_check: int = 0
	
	func _init(n: Node3D, type: String) -> void:
		node = n
		object_type = type
		_update_bounds()
	
	func _update_bounds() -> void:
		if node and is_instance_valid(node):
			if node.has_method("get_aabb"):
				bounds = node.get_aabb()
			elif node is MeshInstance3D:
				var mesh_instance: MeshInstance3D = node as MeshInstance3D
				if mesh_instance.mesh:
					bounds = mesh_instance.mesh.get_aabb()
					bounds = mesh_instance.global_transform * bounds
			else:
				# Default bounds for objects without mesh
				bounds = AABB(node.global_position - Vector3.ONE, Vector3.ONE * 2.0)

func _ready() -> void:
	set_process(enable_culling_system)
	_initialize_culling_system()
	print("CullingOptimizer: Spatial partitioning and off-screen object management initialized")

## Initialize the culling system
func _initialize_culling_system() -> void:
	# Find active camera
	_update_camera_reference()
	
	# Initialize spatial partitioning
	spatial_partitions.clear()
	objects_by_partition.clear()
	
	# Set initial culling mode
	set_culling_mode(current_culling_mode)

func _process(delta: float) -> void:
	if not enable_culling_system:
		return
	
	culling_update_timer += delta
	
	# Update culling system at specified frequency
	if culling_update_timer >= culling_update_frequency:
		_update_culling_system()
		culling_update_timer = 0.0

## Update the entire culling system
func _update_culling_system() -> void:
	var start_time: float = Time.get_ticks_usec() / 1000.0
	
	_update_camera_reference()
	if not active_camera:
		return
	
	_update_camera_data()
	_update_spatial_partitions()
	_perform_culling_checks()
	
	var end_time: float = Time.get_ticks_usec() / 1000.0
	culling_statistics["culling_time_ms"] = end_time - start_time
	
	_update_culling_statistics()

## Update camera reference and data
func _update_camera_reference() -> void:
	if not active_camera:
		var viewport: Viewport = get_viewport()
		if viewport:
			active_camera = viewport.get_camera_3d()

## Update camera data for culling calculations
func _update_camera_data() -> void:
	if not active_camera:
		return
	
	var previous_position: Vector3 = camera_position
	camera_position = active_camera.global_position
	camera_forward = -active_camera.global_transform.basis.z
	
	# Update frustum planes for frustum culling
	if frustum_culling_enabled:
		_update_camera_frustum()
	
	# Check if camera moved significantly
	var camera_moved: float = camera_position.distance_to(previous_position)
	if camera_moved > camera_movement_threshold:
		_mark_partitions_for_update()

## Update camera frustum planes using Godot's built-in system
func _update_camera_frustum() -> void:
	if not active_camera:
		return
	
	# Use Godot's built-in frustum calculation
	camera_frustum = active_camera.get_frustum()

## Update spatial partitions based on object positions
func _update_spatial_partitions() -> void:
	var objects_redistributed: int = 0
	
	# Process objects that need partition updates
	for obj in cullable_objects.keys():
		var cullable: CullableObject = cullable_objects[obj]
		
		if not is_instance_valid(cullable.node):
			_remove_cullable_object(obj)
			continue
		
		var new_partition_id: Vector3i = _get_partition_id(cullable.node.global_position)
		var current_partition_id: Vector3i = objects_by_partition.get(obj, Vector3i(-999, -999, -999))
		
		if new_partition_id != current_partition_id:
			_move_object_to_partition(obj, current_partition_id, new_partition_id)
			objects_redistributed += 1
	
	# Clean up empty partitions
	_cleanup_empty_partitions()
	
	if objects_redistributed > 0:
		spatial_partition_updated.emit(spatial_partitions.size(), objects_redistributed)

## Perform culling checks on all objects
func _perform_culling_checks() -> void:
	var culled_count: int = 0
	var visible_count: int = 0
	var frame_number: int = Engine.get_process_frames()
	
	match current_culling_mode:
		CullingMode.DISABLED:
			_perform_no_culling()
		CullingMode.BASIC:
			culled_count = _perform_basic_culling()
		CullingMode.ADVANCED:
			culled_count = _perform_advanced_culling(frame_number)
		CullingMode.AGGRESSIVE:
			culled_count = _perform_aggressive_culling(frame_number)
		CullingMode.AUTOMATIC:
			culled_count = _perform_automatic_culling(frame_number)
	
	visible_count = cullable_objects.size() - culled_count
	
	culling_statistics["culled_objects"] = culled_count
	culling_statistics["visible_objects"] = visible_count
	culling_statistics["total_objects"] = cullable_objects.size()

## Perform no culling (all objects visible)
func _perform_no_culling() -> void:
	for cullable in cullable_objects.values():
		_set_object_visibility(cullable, true)

## Perform basic culling (frustum + distance)
func _perform_basic_culling() -> int:
	var culled_count: int = 0
	
	for cullable in cullable_objects.values():
		if not is_instance_valid(cullable.node):
			continue
		
		var is_visible: bool = true
		
		# Distance culling
		if distance_culling_enabled:
			var distance: float = camera_position.distance_to(cullable.node.global_position)
			cullable.last_distance = distance
			
			if distance > cullable.culling_distance * cullable.importance_multiplier:
				is_visible = false
		
		# Frustum culling
		if is_visible and frustum_culling_enabled:
			is_visible = _is_object_in_frustum(cullable)
		
		# Force visibility for important objects
		if cullable.force_visible:
			is_visible = true
		
		_set_object_visibility(cullable, is_visible)
		
		if not is_visible:
			culled_count += 1
	
	return culled_count

## Perform advanced culling with spatial partitioning
func _perform_advanced_culling(frame_number: int) -> int:
	var culled_count: int = 0
	
	# First, check partition visibility
	for partition_id in spatial_partitions.keys():
		var partition: SpatialPartition = spatial_partitions[partition_id]
		
		# Skip if partition was checked recently
		if frame_number - partition.visibility_check_frame < 5:
			continue
		
		partition.is_visible = _is_partition_visible(partition)
		partition.visibility_check_frame = frame_number
	
	# Then check objects within visible partitions
	for cullable in cullable_objects.values():
		if not is_instance_valid(cullable.node):
			continue
		
		var partition_id: Vector3i = objects_by_partition.get(cullable.node, Vector3i.ZERO)
		var partition: SpatialPartition = spatial_partitions.get(partition_id)
		
		var is_visible: bool = true
		
		# Partition-level culling
		if partition and not partition.is_visible:
			is_visible = false
		
		# Object-level culling for visible partitions
		if is_visible:
			is_visible = _perform_object_culling_checks(cullable)
		
		# Force visibility for important objects
		if cullable.force_visible:
			is_visible = true
		
		_set_object_visibility(cullable, is_visible)
		
		if not is_visible:
			culled_count += 1
	
	return culled_count

## Perform aggressive culling for maximum performance
func _perform_aggressive_culling(frame_number: int) -> int:
	var culled_count: int = 0
	
	for cullable in cullable_objects.values():
		if not is_instance_valid(cullable.node):
			continue
		
		# Skip culling checks for some objects to improve performance
		cullable.last_culling_check += 1
		var check_frequency: int = _get_culling_check_frequency(cullable)
		
		if cullable.last_culling_check < check_frequency and not cullable.force_visible:
			# Use previous visibility state
			if not cullable.last_visible:
				culled_count += 1
			continue
		
		cullable.last_culling_check = 0
		
		var is_visible: bool = _perform_object_culling_checks(cullable)
		
		# Additional aggressive culling criteria
		if is_visible and cullable.last_distance > cullable.culling_distance * 0.5:
			# More aggressive distance culling
			is_visible = false
		
		# Force visibility for important objects
		if cullable.force_visible:
			is_visible = true
		
		_set_object_visibility(cullable, is_visible)
		
		if not is_visible:
			culled_count += 1
	
	return culled_count

## Perform automatic culling based on performance
func _perform_automatic_culling(frame_number: int) -> int:
	# Determine culling aggressiveness based on current performance
	var current_fps: float = Engine.get_frames_per_second()
	var target_fps: float = 60.0
	
	if current_fps < target_fps * 0.8:
		# Performance is poor, use aggressive culling
		return _perform_aggressive_culling(frame_number)
	elif current_fps < target_fps * 0.95:
		# Performance is okay, use advanced culling
		return _perform_advanced_culling(frame_number)
	else:
		# Performance is good, use basic culling
		return _perform_basic_culling()

## Check if object is visible using all culling methods
func _perform_object_culling_checks(cullable: CullableObject) -> bool:
	# Distance culling
	if distance_culling_enabled:
		var distance: float = camera_position.distance_to(cullable.node.global_position)
		cullable.last_distance = distance
		
		if distance > cullable.culling_distance * cullable.importance_multiplier:
			return false
	
	# Frustum culling
	if frustum_culling_enabled:
		if not _is_object_in_frustum(cullable):
			return false
	
	# Occlusion culling (if enabled)
	if occlusion_culling_enabled:
		if _is_object_occluded(cullable):
			return false
	
	return true

## Check if object is within camera frustum
func _is_object_in_frustum(cullable: CullableObject) -> bool:
	if camera_frustum.is_empty():
		return true
	
	# Update object bounds
	cullable._update_bounds()
	
	# Test AABB against frustum planes
	for plane in camera_frustum:
		if plane.distance_to(cullable.bounds.get_center()) > cullable.bounds.size.length() * 0.5:
			return false
	
	return true

## Check if partition is visible
func _is_partition_visible(partition: SpatialPartition) -> bool:
	if camera_frustum.is_empty():
		return true
	
	# Test partition bounds against frustum
	for plane in camera_frustum:
		if plane.distance_to(partition.bounds.get_center()) > partition.bounds.size.length() * 0.5:
			return false
	
	return true

## Check if object is occluded (simplified implementation)
func _is_object_occluded(cullable: CullableObject) -> bool:
	# Simplified occlusion check - could be improved with proper occlusion queries
	# For now, just check if object is behind a large nearby object
	
	var object_pos: Vector3 = cullable.node.global_position
	var to_camera: Vector3 = camera_position - object_pos
	var distance_to_camera: float = to_camera.length()
	
	# Check against nearby larger objects
	for other_cullable in cullable_objects.values():
		if other_cullable == cullable or not is_instance_valid(other_cullable.node):
			continue
		
		var other_pos: Vector3 = other_cullable.node.global_position
		var other_to_camera: Vector3 = camera_position - other_pos
		var other_distance: float = other_to_camera.length()
		
		# If other object is closer and large enough, it might occlude
		if other_distance < distance_to_camera * 0.9:
			var angular_separation: float = to_camera.normalized().dot(other_to_camera.normalized())
			if angular_separation > 0.95:  # Very close angular positions
				var other_size: float = other_cullable.bounds.size.length()
				if other_size > cullable.bounds.size.length() * 2.0:
					return true
	
	return false

## Set object visibility and update processing
func _set_object_visibility(cullable: CullableObject, visible: bool) -> void:
	if cullable.last_visible == visible:
		return
	
	cullable.last_visible = visible
	
	if is_instance_valid(cullable.node):
		# Update visibility
		cullable.node.visible = visible
		
		# Update processing based on visibility
		if visible:
			cullable.node.set_process_mode(Node.PROCESS_MODE_INHERIT)
		else:
			# Disable processing for invisible objects
			match current_culling_mode:
				CullingMode.AGGRESSIVE:
					cullable.node.set_process_mode(Node.PROCESS_MODE_DISABLED)
				_:
					# Keep minimal processing for less aggressive modes
					cullable.node.set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)

## Get partition ID for a position
func _get_partition_id(position: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(position.x / spatial_partition_size)),
		int(floor(position.y / spatial_partition_size)),
		int(floor(position.z / spatial_partition_size))
	)

## Move object to different partition
func _move_object_to_partition(obj: Node, old_partition_id: Vector3i, new_partition_id: Vector3i) -> void:
	# Remove from old partition
	if spatial_partitions.has(old_partition_id):
		var old_partition: SpatialPartition = spatial_partitions[old_partition_id]
		old_partition.remove_object(obj)
	
	# Add to new partition
	if not spatial_partitions.has(new_partition_id):
		spatial_partitions[new_partition_id] = SpatialPartition.new(new_partition_id, spatial_partition_size)
	
	var new_partition: SpatialPartition = spatial_partitions[new_partition_id]
	new_partition.add_object(obj)
	objects_by_partition[obj] = new_partition_id

## Clean up empty partitions
func _cleanup_empty_partitions() -> void:
	var empty_partitions: Array[Vector3i] = []
	
	for partition_id in spatial_partitions.keys():
		var partition: SpatialPartition = spatial_partitions[partition_id]
		if partition.is_empty():
			empty_partitions.append(partition_id)
	
	for partition_id in empty_partitions:
		spatial_partitions.erase(partition_id)

## Mark partitions for update when camera moves significantly
func _mark_partitions_for_update() -> void:
	for partition in spatial_partitions.values():
		partition.visibility_check_frame = 0  # Force recheck

## Get culling check frequency based on object properties
func _get_culling_check_frequency(cullable: CullableObject) -> int:
	# More important or closer objects get checked more frequently
	var base_frequency: int = 5
	
	if cullable.importance_multiplier > 1.5:
		return max(1, base_frequency - 2)
	elif cullable.last_distance > cullable.culling_distance * 0.8:
		return base_frequency * 2
	else:
		return base_frequency

## Update culling statistics
func _update_culling_statistics() -> void:
	culling_statistics["partitions_active"] = spatial_partitions.size()
	
	# Calculate performance gain (simplified)
	var total_objects: int = culling_statistics["total_objects"]
	var culled_objects: int = culling_statistics["culled_objects"]
	
	if total_objects > 0:
		culling_statistics["performance_gain"] = (float(culled_objects) / float(total_objects)) * 100.0
	else:
		culling_statistics["performance_gain"] = 0.0

## Remove cullable object from system
func _remove_cullable_object(obj: Node) -> void:
	if cullable_objects.has(obj):
		cullable_objects.erase(obj)
	
	if objects_by_partition.has(obj):
		var partition_id: Vector3i = objects_by_partition[obj]
		if spatial_partitions.has(partition_id):
			spatial_partitions[partition_id].remove_object(obj)
		objects_by_partition.erase(obj)

# Public API

## Register object for culling
func register_cullable_object(obj: Node3D, object_type: String = "default", importance: float = 1.0, force_visible: bool = false) -> bool:
	if not obj or cullable_objects.has(obj):
		return false
	
	var cullable: CullableObject = CullableObject.new(obj, object_type)
	cullable.culling_distance = culling_distances.get(object_type, 1000.0)
	cullable.importance_multiplier = importance
	cullable.force_visible = force_visible
	
	cullable_objects[obj] = cullable
	
	# Add to spatial partition
	var partition_id: Vector3i = _get_partition_id(obj.global_position)
	_move_object_to_partition(obj, Vector3i(-999, -999, -999), partition_id)
	
	print("CullingOptimizer: Registered object %s for culling (type: %s)" % [obj.name, object_type])
	return true

## Unregister object from culling
func unregister_cullable_object(obj: Node3D) -> bool:
	if not cullable_objects.has(obj):
		return false
	
	_remove_cullable_object(obj)
	print("CullingOptimizer: Unregistered object %s from culling" % obj.name)
	return true

## Set culling mode
func set_culling_mode(mode: CullingMode) -> void:
	var old_mode: CullingMode = current_culling_mode
	current_culling_mode = mode
	
	var objects_affected: int = cullable_objects.size()
	culling_mode_changed.emit(mode, objects_affected)
	
	print("CullingOptimizer: Culling mode changed from %s to %s" % [CullingMode.keys()[old_mode], CullingMode.keys()[mode]])

## Set culling distance for object type
func set_culling_distance(object_type: String, distance: float) -> void:
	culling_distances[object_type] = distance
	
	# Update existing objects of this type
	for cullable in cullable_objects.values():
		if cullable.object_type == object_type:
			cullable.culling_distance = distance
	
	print("CullingOptimizer: Set culling distance for %s to %.1f units" % [object_type, distance])

## Get culling statistics
func get_culling_statistics() -> Dictionary:
	return culling_statistics.duplicate()

## Force visibility for specific object
func force_object_visibility(obj: Node3D, visible: bool) -> bool:
	if not cullable_objects.has(obj):
		return false
	
	var cullable: CullableObject = cullable_objects[obj]
	cullable.force_visible = visible
	
	if visible:
		_set_object_visibility(cullable, true)
	
	return true

## Enable/disable culling system
func set_culling_enabled(enabled: bool) -> void:
	enable_culling_system = enabled
	set_process(enabled)
	
	if not enabled:
		# Make all objects visible when culling is disabled
		_perform_no_culling()
	
	print("CullingOptimizer: Culling system %s" % ("enabled" if enabled else "disabled"))

## Set spatial partition size
func set_partition_size(size: float) -> void:
	spatial_partition_size = size
	
	# Rebuild partitions with new size
	var objects_to_repartition: Array[Node] = cullable_objects.keys()
	spatial_partitions.clear()
	objects_by_partition.clear()
	
	for obj in objects_to_repartition:
		if is_instance_valid(obj):
			var partition_id: Vector3i = _get_partition_id(obj.global_position)
			_move_object_to_partition(obj, Vector3i(-999, -999, -999), partition_id)
	
	print("CullingOptimizer: Spatial partition size set to %.1f units" % size)