extends Node

## Core object lifecycle manager replacing C++ object system.
## Handles creation, updates, and destruction of all game objects.
##
## This manager provides the foundational object system for WCS-Godot conversion,
## implementing object pooling, lifecycle management, and update scheduling
## to replace the original C++ object pointer system with Godot's node-based approach.

signal object_created(object: WCSObject)
signal object_destroyed(object: WCSObject)
signal physics_frame_processed(delta: float)
signal manager_initialized()
signal manager_shutdown()
signal critical_error(error_message: String)

# Configuration
@export var max_objects: int = 1000
@export var update_frequency: int = 60  # Hz
@export var enable_object_pooling: bool = true
@export var enable_debug_logging: bool = false

# Object tracking
var active_objects: Array[WCSObject] = []
var object_pools: Dictionary = {}  # String (type) -> Array[WCSObject]
var update_groups: Dictionary = {}  # int (frequency) -> Array[WCSObject]
var id_counter: int = 0

# Performance tracking
var frame_time_accumulator: float = 0.0
var objects_created_this_frame: int = 0
var objects_destroyed_this_frame: int = 0
var update_time_budget: float = 0.016  # 16ms budget per frame

# State management
var is_initialized: bool = false
var is_shutting_down: bool = false
var initialization_error: String = ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	if is_initialized:
		push_warning("ObjectManager: Already initialized")
		return
	
	print("ObjectManager: Starting initialization...")
	
	# Validate configuration
	if not _validate_configuration():
		return
	
	# Initialize subsystems
	_initialize_object_pools()
	_initialize_update_groups()
	_setup_signal_connections()
	
	is_initialized = true
	print("ObjectManager: Initialization complete")
	manager_initialized.emit()

func _validate_configuration() -> bool:
	if max_objects <= 0:
		initialization_error = "max_objects must be positive"
		_handle_critical_error(initialization_error)
		return false
	
	if update_frequency <= 0:
		initialization_error = "update_frequency must be positive"
		_handle_critical_error(initialization_error)
		return false
	
	return true

func _initialize_object_pools() -> void:
	# Pre-initialize common object type pools
	var common_types: Array[String] = [
		"ship",
		"weapon", 
		"debris",
		"particle",
		"waypoint",
		"asteroid"
	]
	
	for object_type in common_types:
		object_pools[object_type] = []
		if enable_debug_logging:
			print("ObjectManager: Initialized pool for type: %s" % object_type)

func _initialize_update_groups() -> void:
	# Create update frequency groups
	var frequencies: Array[int] = [60, 30, 10, 1]  # 60Hz, 30Hz, 10Hz, 1Hz
	
	for frequency in frequencies:
		update_groups[frequency] = []
		if enable_debug_logging:
			print("ObjectManager: Initialized update group for %dHz" % frequency)

func _setup_signal_connections() -> void:
	# Connect to SceneTree signals for proper cleanup
	if get_tree():
		get_tree().node_removed.connect(_on_node_removed)

func _physics_process(delta: float) -> void:
	if not is_initialized or is_shutting_down:
		return
	
	var frame_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Reset per-frame counters
	objects_created_this_frame = 0
	objects_destroyed_this_frame = 0
	
	# Process object updates by frequency groups
	_process_update_groups(delta)
	
	# Clean up destroyed objects
	_cleanup_destroyed_objects()
	
	# Emit physics frame completion
	physics_frame_processed.emit(delta)
	
	# Track performance
	var frame_end_time: float = Time.get_ticks_usec() / 1000.0
	var frame_time: float = frame_end_time - frame_start_time
	
	if frame_time > update_time_budget:
		push_warning("ObjectManager: Frame time exceeded budget: %.2fms > %.2fms" % [frame_time, update_time_budget])

func _process_update_groups(delta: float) -> void:
	# Process different update frequency groups
	for frequency in update_groups.keys():
		var objects_in_group: Array = update_groups[frequency]
		var should_update: bool = _should_update_group(frequency)
		
		if should_update:
			for obj in objects_in_group:
				if is_instance_valid(obj) and not obj.is_queued_for_deletion():
					obj._physics_update(delta)

func _should_update_group(frequency: int) -> bool:
	# Simple frame-based update scheduling
	var current_frame: int = Engine.get_process_frames()
	var frame_interval: int = update_frequency / frequency
	
	return current_frame % frame_interval == 0

func _cleanup_destroyed_objects() -> void:
	# Remove invalid objects from active list
	var i: int = active_objects.size() - 1
	while i >= 0:
		var obj: WCSObject = active_objects[i]
		if not is_instance_valid(obj) or obj.is_queued_for_deletion():
			active_objects.remove_at(i)
			objects_destroyed_this_frame += 1
			object_destroyed.emit(obj)
		i -= 1

# Public API Methods

func create_object(object_type: String, data: WCSObjectData = null) -> WCSObject:
	if not is_initialized:
		push_error("ObjectManager: Cannot create object - manager not initialized")
		return null
	
	if active_objects.size() >= max_objects:
		push_warning("ObjectManager: Maximum object limit reached (%d)" % max_objects)
		return null
	
	var new_object: WCSObject = _get_pooled_object(object_type)
	if not new_object:
		new_object = _create_new_object(object_type)
	
	if new_object:
		_initialize_object(new_object, data)
		_register_object(new_object)
		objects_created_this_frame += 1
		object_created.emit(new_object)
		
		if enable_debug_logging:
			print("ObjectManager: Created object type %s, ID %d" % [object_type, new_object.get_object_id()])
	
	return new_object

func destroy_object(object: WCSObject) -> void:
	if not is_instance_valid(object):
		return
	
	if enable_debug_logging:
		print("ObjectManager: Destroying object ID %d" % object.get_object_id())
	
	# Remove from update groups
	_unregister_object(object)
	
	# Return to pool if pooling is enabled
	if enable_object_pooling:
		_return_to_pool(object)
	else:
		object.queue_free()

func get_objects_by_type(object_type: String) -> Array:
	var result: Array = []
	
	for obj in active_objects:
		if is_instance_valid(obj) and obj.get_object_type() == object_type:
			result.append(obj)
	
	return result

func get_active_object_count() -> int:
	return active_objects.size()

func get_object_by_id(object_id: int) -> WCSObject:
	for obj in active_objects:
		if is_instance_valid(obj) and obj.get_object_id() == object_id:
			return obj
	
	return null

func clear_all_objects() -> void:
	if enable_debug_logging:
		print("ObjectManager: Clearing all objects (%d active)" % active_objects.size())
	
	# Destroy all active objects
	var objects_to_destroy: Array = active_objects.duplicate()
	for obj in objects_to_destroy:
		destroy_object(obj)
	
	# Clear collections
	active_objects.clear()
	for frequency in update_groups.keys():
		update_groups[frequency].clear()

# Private helper methods

func _get_pooled_object(object_type: String) -> WCSObject:
	if not enable_object_pooling:
		return null
	
	if not object_pools.has(object_type):
		object_pools[object_type] = []
		return null
	
	var pool: Array = object_pools[object_type]
	if pool.is_empty():
		return null
	
	return pool.pop_back() as WCSObject

func _create_new_object(object_type: String) -> WCSObject:
	# Create new object instance
	var new_object: WCSObject = WCSObject.new()
	new_object.set_object_type(object_type)
	new_object.set_object_id(_generate_object_id())
	
	# Add to scene tree
	add_child(new_object)
	
	return new_object

func _initialize_object(object: WCSObject, data: WCSObjectData) -> void:
	# Initialize object with provided data
	if data:
		object.initialize_from_data(data)
	else:
		object.initialize_default()

func _register_object(object: WCSObject) -> void:
	# Add to active objects list
	active_objects.append(object)
	
	# Add to appropriate update group
	var update_freq: int = object.get_update_frequency()
	if update_groups.has(update_freq):
		update_groups[update_freq].append(object)
	else:
		# Default to 60Hz if unknown frequency
		update_groups[60].append(object)

func _unregister_object(object: WCSObject) -> void:
	# Remove from active objects
	var index: int = active_objects.find(object)
	if index >= 0:
		active_objects.remove_at(index)
	
	# Remove from update groups
	for frequency in update_groups.keys():
		var group: Array = update_groups[frequency]
		var group_index: int = group.find(object)
		if group_index >= 0:
			group.remove_at(group_index)
			break

func _return_to_pool(object: WCSObject) -> void:
	var object_type: String = object.get_object_type()
	
	# Reset object state
	object.reset_state()
	object.set_visible(false)
	object.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Return to pool
	if not object_pools.has(object_type):
		object_pools[object_type] = []
	
	object_pools[object_type].append(object)

func _generate_object_id() -> int:
	id_counter += 1
	return id_counter

# Performance and debugging

func get_performance_stats() -> Dictionary:
	return {
		"active_objects": active_objects.size(),
		"objects_created_this_frame": objects_created_this_frame,
		"objects_destroyed_this_frame": objects_destroyed_this_frame,
		"total_pool_size": _get_total_pool_size(),
		"update_groups": _get_update_group_stats(),
		"memory_usage_mb": _estimate_memory_usage()
	}

func _get_total_pool_size() -> int:
	var total: int = 0
	for pool in object_pools.values():
		total += (pool as Array).size()
	return total

func _get_update_group_stats() -> Dictionary:
	var stats: Dictionary = {}
	for frequency in update_groups.keys():
		stats[str(frequency) + "Hz"] = (update_groups[frequency] as Array).size()
	return stats

func _estimate_memory_usage() -> float:
	# Rough estimate of memory usage in MB
	var base_size: float = 8.0  # Base manager overhead
	var object_size: float = active_objects.size() * 0.001  # ~1KB per object estimate
	var pool_size: float = _get_total_pool_size() * 0.0005  # ~0.5KB per pooled object
	return base_size + object_size + pool_size

# Signal handlers

func _on_node_removed(node: Node) -> void:
	# Handle unexpected node removal
	if node is WCSObject:
		var wcs_object: WCSObject = node as WCSObject
		_unregister_object(wcs_object)

# Error handling

func _handle_critical_error(error_message: String) -> void:
	push_error("ObjectManager CRITICAL ERROR: " + error_message)
	critical_error.emit(error_message)
	
	# Attempt graceful degradation
	is_shutting_down = true
	print("ObjectManager: Entering error recovery mode")

# Cleanup

func shutdown() -> void:
	if is_shutting_down:
		return
	
	print("ObjectManager: Starting shutdown...")
	is_shutting_down = true
	
	# Clear all objects
	clear_all_objects()
	
	# Clear pools
	object_pools.clear()
	update_groups.clear()
	
	# Disconnect signals
	if get_tree() and get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.disconnect(_on_node_removed)
	
	is_initialized = false
	print("ObjectManager: Shutdown complete")
	manager_shutdown.emit()

func _exit_tree() -> void:
	shutdown()

# Debug helpers

func debug_print_active_objects() -> void:
	print("=== ObjectManager Debug Info ===")
	print("Active objects: %d/%d" % [active_objects.size(), max_objects])
	
	var type_counts: Dictionary = {}
	for obj in active_objects:
		if is_instance_valid(obj):
			var type: String = obj.get_object_type()
			type_counts[type] = type_counts.get(type, 0) + 1
	
	print("Objects by type:")
	for type in type_counts.keys():
		print("  %s: %d" % [type, type_counts[type]])
	
	print("Pool sizes:")
	for type in object_pools.keys():
		print("  %s pool: %d" % [type, (object_pools[type] as Array).size()])
	
	print("Update groups:")
	for frequency in update_groups.keys():
		print("  %dHz: %d objects" % [frequency, (update_groups[frequency] as Array).size()])
	
	print("================================")

func debug_validate_object_integrity() -> bool:
	var valid: bool = true
	
	# Check for null objects in active list
	for i in range(active_objects.size()):
		if not is_instance_valid(active_objects[i]):
			push_error("ObjectManager: Found invalid object at index %d" % i)
			valid = false
	
	# Check for objects in multiple update groups
	var all_grouped_objects: Array = []
	for frequency in update_groups.keys():
		var group: Array = update_groups[frequency]
		for obj in group:
			if all_grouped_objects.has(obj):
				push_error("ObjectManager: Object found in multiple update groups")
				valid = false
			all_grouped_objects.append(obj)
	
	return valid
