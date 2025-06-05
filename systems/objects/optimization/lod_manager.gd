class_name LODManager
extends Node

## Level of Detail manager for physics step integration and performance optimization.
## Manages update frequency groups and adjusts physics processing based on object distance and importance.
## 
## This system implements the OBJ-007 requirements for optimized physics step integration
## with LOD systems maintaining 60 FPS performance with hundreds of objects.

signal lod_level_changed(object: Node3D, old_level: UpdateFrequency, new_level: UpdateFrequency)
signal physics_culling_enabled(object: Node3D)
signal physics_culling_disabled(object: Node3D)
signal automatic_optimization_triggered(performance_data: Dictionary)

# EPIC-002 Asset Core Integration - Update frequency constants
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const UpdateFrequency = UpdateFrequencies.Frequency

# Configuration from architecture.md requirements
@export var near_distance_threshold: float = 2000.0  # Near objects get medium frequency
@export var medium_distance_threshold: float = 8000.0  # Medium distance objects get low frequency
@export var far_distance_threshold: float = 20000.0  # Far objects get minimal frequency
@export var culling_distance_threshold: float = 50000.0  # Very far objects are culled

@export var enable_automatic_optimization: bool = true
@export var target_frame_rate: float = 60.0
@export var performance_check_interval: float = 1.0  # Check performance every second

# Physics integration
const PhysicsManager = preload("res://autoload/physics_manager.gd")
var physics_manager: PhysicsManager

# Object tracking
var tracked_objects: Dictionary = {}  # Node3D -> ObjectLODData
var player_position: Vector3 = Vector3.ZERO
var camera_position: Vector3 = Vector3.ZERO

# Update frequency groups for performance optimization
var high_frequency_objects: Array[Node3D] = []
var medium_frequency_objects: Array[Node3D] = []
var low_frequency_objects: Array[Node3D] = []
var minimal_frequency_objects: Array[Node3D] = []
var culled_objects: Array[Node3D] = []

# Performance monitoring
var frame_timer: float = 0.0
var performance_check_timer: float = 0.0
var recent_frame_times: Array[float] = []
var max_frame_time_samples: int = 60  # Track last 60 frame times

# Update timing - staggered updates for optimization
var high_frequency_timer: float = 0.0
var medium_frequency_timer: float = 0.0
var low_frequency_timer: float = 0.0
var minimal_frequency_timer: float = 0.0

var high_frequency_interval: float = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.CRITICAL] / 1000.0
var medium_frequency_interval: float = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.HIGH] / 1000.0
var low_frequency_interval: float = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.MEDIUM] / 1000.0
var minimal_frequency_interval: float = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.LOW] / 1000.0

# Performance targets from OBJ-007 requirements
var physics_step_target_ms: float = 2.0  # Physics step under 2ms for 200 objects
var lod_switching_target_ms: float = 0.1  # LOD switching under 0.1ms

# State management
var is_initialized: bool = false
var is_enabled: bool = true

class ObjectLODData:
	var object: Node3D
	var current_frequency: UpdateFrequency
	var last_update_time: float
	var distance_to_player: float
	var threat_level: float
	var engagement_status: int
	var is_physics_enabled: bool
	var is_culled: bool
	
	func _init(obj: Node3D) -> void:
		object = obj
		current_frequency = UpdateFrequency.CRITICAL
		last_update_time = 0.0
		distance_to_player = 0.0
		threat_level = 0.0
		engagement_status = 0
		is_physics_enabled = true
		is_culled = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_lod_manager()

func _initialize_lod_manager() -> void:
	"""Initialize the LOD manager and connect to physics manager."""
	if is_initialized:
		push_warning("LODManager: Already initialized")
		return
	
	print("LODManager: Starting initialization...")
	
	# Get physics manager reference
	physics_manager = get_node("/root/PhysicsManager")
	if not physics_manager:
		push_error("LODManager: PhysicsManager not found")
		return
	
	# Connect to physics manager signals
	if physics_manager.has_signal("physics_step_completed"):
		physics_manager.physics_step_completed.connect(_on_physics_step_completed)
	
	# Initialize arrays
	high_frequency_objects.clear()
	medium_frequency_objects.clear()
	low_frequency_objects.clear()
	minimal_frequency_objects.clear()
	culled_objects.clear()
	tracked_objects.clear()
	
	is_initialized = true
	print("LODManager: Initialization complete")

func _process(delta: float) -> void:
	if not is_initialized or not is_enabled:
		return
	
	# Update performance monitoring
	_update_performance_monitoring(delta)
	
	# Update LOD levels for all tracked objects
	_update_lod_levels(delta)
	
	# Process staggered physics updates
	_process_staggered_updates(delta)
	
	# Check for automatic optimization
	if enable_automatic_optimization:
		_check_automatic_optimization(delta)

func _update_performance_monitoring(delta: float) -> void:
	"""Track frame times for performance monitoring."""
	frame_timer += delta
	recent_frame_times.append(delta * 1000.0)  # Convert to milliseconds
	
	# Keep only recent samples
	if recent_frame_times.size() > max_frame_time_samples:
		recent_frame_times.pop_front()

func _update_lod_levels(delta: float) -> void:
	"""Update LOD levels for all tracked objects based on distance and importance."""
	var lod_update_start_time: float = Time.get_ticks_usec() / 1000.0
	
	for object in tracked_objects.keys():
		if not is_instance_valid(object):
			continue
		
		var lod_data: ObjectLODData = tracked_objects[object]
		_update_object_lod(object, lod_data)
	
	var lod_update_time: float = (Time.get_ticks_usec() / 1000.0) - lod_update_start_time
	
	# Check if LOD switching is within performance targets
	if lod_update_time > lod_switching_target_ms:
		push_warning("LODManager: LOD switching took %.2fms (target: %.2fms)" % [lod_update_time, lod_switching_target_ms])

func _update_object_lod(object: Node3D, lod_data: ObjectLODData) -> void:
	"""Update LOD level for a specific object."""
	# Calculate distance to player
	lod_data.distance_to_player = object.global_position.distance_to(player_position)
	
	# Get object importance factors
	var threat_level: float = _get_object_threat_level(object)
	var engagement_status: int = _get_object_engagement_status(object)
	
	# Determine new update frequency
	var new_frequency: UpdateFrequency = _determine_update_frequency(
		lod_data.distance_to_player, 
		threat_level, 
		engagement_status
	)
	
	# Check if object should be culled
	var should_cull: bool = lod_data.distance_to_player > culling_distance_threshold
	
	# Apply changes if needed
	if new_frequency != lod_data.current_frequency or should_cull != lod_data.is_culled:
		_apply_lod_changes(object, lod_data, new_frequency, should_cull)

func _determine_update_frequency(distance: float, threat_level: float, engagement_status: int) -> UpdateFrequency:
	"""Determine update frequency based on object distance and importance."""
	# Priority calculation based on gameplay relevance (from architecture.md)
	if engagement_status == 1:  # ACTIVE_COMBAT
		return UpdateFrequency.HIGH_FREQUENCY
	elif distance < near_distance_threshold:
		return UpdateFrequency.MEDIUM_FREQUENCY
	elif distance < medium_distance_threshold:
		return UpdateFrequency.LOW_FREQUENCY
	else:
		return UpdateFrequency.MINIMAL_FREQUENCY

func _get_object_threat_level(object: Node3D) -> float:
	"""Get threat level of an object for LOD prioritization."""
	if object.has_method("get_threat_level"):
		return object.get_threat_level()
	
	# Default threat levels based on object type
	if object.has_method("get_object_type"):
		var object_type: String = object.get_object_type()
		match object_type:
			"ship", "capital":
				return 1.0
			"weapon":
				return 0.8
			"debris":
				return 0.1
			_:
				return 0.5
	
	return 0.5  # Default medium threat

func _get_object_engagement_status(object: Node3D) -> int:
	"""Get engagement status of an object for LOD prioritization."""
	if object.has_method("get_engagement_status"):
		return object.get_engagement_status()
	
	# Check if object is in combat or has active AI
	if object.has_method("is_in_combat") and object.is_in_combat():
		return 1  # ACTIVE_COMBAT
	
	return 0  # INACTIVE

func _apply_lod_changes(object: Node3D, lod_data: ObjectLODData, new_frequency: UpdateFrequency, should_cull: bool) -> void:
	"""Apply LOD level changes to an object."""
	var old_frequency: UpdateFrequency = lod_data.current_frequency
	var was_culled: bool = lod_data.is_culled
	
	# Remove from old frequency group
	_remove_from_frequency_group(object, old_frequency)
	
	# Handle culling changes
	if should_cull != was_culled:
		if should_cull:
			_cull_object(object, lod_data)
		else:
			_uncull_object(object, lod_data)
	
	# Add to new frequency group if not culled
	if not should_cull:
		_add_to_frequency_group(object, new_frequency)
		lod_data.current_frequency = new_frequency
		
		# Emit signal for frequency change
		if new_frequency != old_frequency:
			lod_level_changed.emit(object, old_frequency, new_frequency)

func _remove_from_frequency_group(object: Node3D, frequency: UpdateFrequency) -> void:
	"""Remove object from its current frequency group."""
	match frequency:
		UpdateFrequency.HIGH_FREQUENCY:
			high_frequency_objects.erase(object)
		UpdateFrequency.MEDIUM_FREQUENCY:
			medium_frequency_objects.erase(object)
		UpdateFrequency.LOW_FREQUENCY:
			low_frequency_objects.erase(object)
		UpdateFrequency.MINIMAL_FREQUENCY:
			minimal_frequency_objects.erase(object)

func _add_to_frequency_group(object: Node3D, frequency: UpdateFrequency) -> void:
	"""Add object to a frequency group."""
	match frequency:
		UpdateFrequency.HIGH_FREQUENCY:
			if not high_frequency_objects.has(object):
				high_frequency_objects.append(object)
		UpdateFrequency.MEDIUM_FREQUENCY:
			if not medium_frequency_objects.has(object):
				medium_frequency_objects.append(object)
		UpdateFrequency.LOW_FREQUENCY:
			if not low_frequency_objects.has(object):
				low_frequency_objects.append(object)
		UpdateFrequency.MINIMAL_FREQUENCY:
			if not minimal_frequency_objects.has(object):
				minimal_frequency_objects.append(object)

func _cull_object(object: Node3D, lod_data: ObjectLODData) -> void:
	"""Cull an object by disabling its physics processing."""
	if not lod_data.is_culled:
		lod_data.is_culled = true
		
		# Disable physics processing
		if object.has_method("set_physics_enabled"):
			object.set_physics_enabled(false)
		
		# Add to culled objects
		if not culled_objects.has(object):
			culled_objects.append(object)
		
		physics_culling_enabled.emit(object)
		print("LODManager: Culled object at distance %.2f" % lod_data.distance_to_player)

func _uncull_object(object: Node3D, lod_data: ObjectLODData) -> void:
	"""Uncull an object by re-enabling its physics processing."""
	if lod_data.is_culled:
		lod_data.is_culled = false
		
		# Re-enable physics processing
		if object.has_method("set_physics_enabled"):
			object.set_physics_enabled(true)
		
		# Remove from culled objects
		culled_objects.erase(object)
		
		physics_culling_disabled.emit(object)
		print("LODManager: Unculled object at distance %.2f" % lod_data.distance_to_player)

func _process_staggered_updates(delta: float) -> void:
	"""Process staggered physics updates for different frequency groups."""
	# Update timers
	high_frequency_timer += delta
	medium_frequency_timer += delta
	low_frequency_timer += delta
	minimal_frequency_timer += delta
	
	# Process high frequency updates (60 FPS)
	if high_frequency_timer >= high_frequency_interval:
		_process_frequency_group(high_frequency_objects, UpdateFrequency.HIGH_FREQUENCY)
		high_frequency_timer = 0.0
	
	# Process medium frequency updates (30 FPS)
	if medium_frequency_timer >= medium_frequency_interval:
		_process_frequency_group(medium_frequency_objects, UpdateFrequency.MEDIUM_FREQUENCY)
		medium_frequency_timer = 0.0
	
	# Process low frequency updates (15 FPS)
	if low_frequency_timer >= low_frequency_interval:
		_process_frequency_group(low_frequency_objects, UpdateFrequency.LOW_FREQUENCY)
		low_frequency_timer = 0.0
	
	# Process minimal frequency updates (5 FPS)
	if minimal_frequency_timer >= minimal_frequency_interval:
		_process_frequency_group(minimal_frequency_objects, UpdateFrequency.MINIMAL_FREQUENCY)
		minimal_frequency_timer = 0.0

func _process_frequency_group(objects: Array[Node3D], frequency: UpdateFrequency) -> void:
	"""Process physics updates for a specific frequency group."""
	for object in objects:
		if not is_instance_valid(object):
			continue
		
		# Trigger object's physics update if it supports it
		if object.has_method("_physics_step"):
			object._physics_step(get_frequency_delta(frequency))

func get_frequency_delta(frequency: UpdateFrequency) -> float:
	"""Get the delta time for a specific update frequency."""
	match frequency:
		UpdateFrequency.HIGH_FREQUENCY:
			return high_frequency_interval
		UpdateFrequency.MEDIUM_FREQUENCY:
			return medium_frequency_interval
		UpdateFrequency.LOW_FREQUENCY:
			return low_frequency_interval
		UpdateFrequency.MINIMAL_FREQUENCY:
			return minimal_frequency_interval
		_:
			return high_frequency_interval

func _check_automatic_optimization(delta: float) -> void:
	"""Check performance and trigger automatic optimization if needed."""
	performance_check_timer += delta
	
	if performance_check_timer >= performance_check_interval:
		performance_check_timer = 0.0
		
		var performance_data: Dictionary = _get_performance_data()
		var current_fps: float = performance_data.get("average_fps", 60.0)
		
		# If performance is below target, trigger optimization
		if current_fps < target_frame_rate * 0.9:  # 10% tolerance
			_trigger_automatic_optimization(performance_data)

func _trigger_automatic_optimization(performance_data: Dictionary) -> void:
	"""Trigger automatic optimization to improve performance."""
	print("LODManager: Triggering automatic optimization - FPS: %.1f" % performance_data.get("average_fps", 0.0))
	
	# Increase culling distance for better performance
	culling_distance_threshold *= 0.9
	far_distance_threshold *= 0.9
	medium_distance_threshold *= 0.9
	
	# Clamp minimum distances
	culling_distance_threshold = max(culling_distance_threshold, 10000.0)
	far_distance_threshold = max(far_distance_threshold, 5000.0)
	medium_distance_threshold = max(medium_distance_threshold, 2000.0)
	
	automatic_optimization_triggered.emit(performance_data)

func _get_performance_data() -> Dictionary:
	"""Get current performance metrics."""
	var total_frame_time: float = 0.0
	for frame_time in recent_frame_times:
		total_frame_time += frame_time
	
	var average_frame_time: float = total_frame_time / max(recent_frame_times.size(), 1)
	var average_fps: float = 1000.0 / max(average_frame_time, 0.001)
	
	return {
		"average_fps": average_fps,
		"average_frame_time_ms": average_frame_time,
		"high_frequency_count": high_frequency_objects.size(),
		"medium_frequency_count": medium_frequency_objects.size(),
		"low_frequency_count": low_frequency_objects.size(),
		"minimal_frequency_count": minimal_frequency_objects.size(),
		"culled_count": culled_objects.size(),
		"total_tracked_objects": tracked_objects.size()
	}

func _on_physics_step_completed(delta: float) -> void:
	"""Handle physics step completion for performance monitoring."""
	# This is called from PhysicsManager after each physics step
	# We can use this to monitor physics step timing
	pass

# Public API for object registration and management

func register_object(object: Node3D) -> bool:
	"""Register an object for LOD management.
	
	Args:
		object: Node3D object to manage
		
	Returns:
		true if registration successful
	"""
	if not is_instance_valid(object):
		push_error("LODManager: Cannot register invalid object")
		return false
	
	if tracked_objects.has(object):
		push_warning("LODManager: Object already registered")
		return false
	
	var lod_data: ObjectLODData = ObjectLODData.new(object)
	tracked_objects[object] = lod_data
	
	# Start with high frequency and let LOD system adjust
	_add_to_frequency_group(object, UpdateFrequency.HIGH_FREQUENCY)
	
	print("LODManager: Registered object for LOD management")
	return true

func unregister_object(object: Node3D) -> void:
	"""Unregister an object from LOD management.
	
	Args:
		object: Node3D object to unregister
	"""
	if not tracked_objects.has(object):
		return
	
	var lod_data: ObjectLODData = tracked_objects[object]
	
	# Remove from all groups
	_remove_from_frequency_group(object, lod_data.current_frequency)
	culled_objects.erase(object)
	
	# Remove from tracking
	tracked_objects.erase(object)
	
	print("LODManager: Unregistered object from LOD management")

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

func get_object_lod_level(object: Node3D) -> UpdateFrequency:
	"""Get the current LOD level of an object.
	
	Args:
		object: Node3D to query
		
	Returns:
		Current UpdateFrequency level
	"""
	if tracked_objects.has(object):
		return tracked_objects[object].current_frequency
	
	return UpdateFrequency.HIGH_FREQUENCY

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

func get_performance_stats() -> Dictionary:
	"""Get current LOD manager performance statistics.
	
	Returns:
		Dictionary containing performance metrics
	"""
	return _get_performance_data()

func set_lod_enabled(enabled: bool) -> void:
	"""Enable or disable LOD processing.
	
	Args:
		enabled: true to enable LOD processing
	"""
	is_enabled = enabled
	print("LODManager: LOD processing %s" % ("enabled" if enabled else "disabled"))

func is_lod_enabled() -> bool:
	"""Check if LOD processing is enabled.
	
	Returns:
		true if LOD processing is enabled
	"""
	return is_enabled

# Debug and testing functions

func debug_print_lod_stats() -> void:
	"""Print current LOD statistics for debugging."""
	var stats: Dictionary = get_performance_stats()
	
	print("=== LOD Manager Statistics ===")
	print("Total tracked objects: %d" % stats.get("total_tracked_objects", 0))
	print("High frequency objects: %d" % stats.get("high_frequency_count", 0))
	print("Medium frequency objects: %d" % stats.get("medium_frequency_count", 0))
	print("Low frequency objects: %d" % stats.get("low_frequency_count", 0))
	print("Minimal frequency objects: %d" % stats.get("minimal_frequency_count", 0))
	print("Culled objects: %d" % stats.get("culled_count", 0))
	print("Average FPS: %.1f" % stats.get("average_fps", 0.0))
	print("Average frame time: %.2fms" % stats.get("average_frame_time_ms", 0.0))
	print("Near distance threshold: %.2f" % near_distance_threshold)
	print("Medium distance threshold: %.2f" % medium_distance_threshold)
	print("Culling distance threshold: %.2f" % culling_distance_threshold)
	print("================================")

func force_lod_update() -> void:
	"""Force an immediate LOD update for all objects (for testing)."""
	_update_lod_levels(0.0)
	print("LODManager: Forced LOD update completed")