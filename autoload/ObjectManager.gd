class_name ObjectManager
extends Node

## Core object lifecycle manager for the WCS-Godot conversion.
## Handles creation, tracking, and destruction of all game objects with proper
## memory management and performance optimization through object pooling.

signal object_created(object: WCSObject)
signal object_destroyed(object: WCSObject) 
signal physics_frame_processed()
signal manager_initialized()
signal manager_error(error_message: String)

# Configuration
@export var max_objects: int = 1000
@export var update_frequency: int = 60  # Hz
@export var enable_debug_logging: bool = false

# Object tracking
var active_objects: Array[WCSObject] = []
var object_pools: Dictionary = {}  # Type -> Array[WCSObject]
var update_groups: Dictionary = {}  # UpdateFreq -> Array[WCSObject]
var object_registry: Dictionary = {}  # ID -> WCSObject

# Performance metrics
var id_counter: int = 0
var objects_created_this_frame: int = 0
var objects_destroyed_this_frame: int = 0
var is_initialized: bool = false

# Update frequency groups
enum UpdateFrequency {
	FRAME_60HZ = 60,
	FRAME_30HZ = 30,
	FRAME_10HZ = 10,
	FRAME_1HZ = 1
}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	"""Initialize the ObjectManager with proper setup and validation."""
	
	if is_initialized:
		push_warning("ObjectManager already initialized")
		return
	
	# Validate configuration
	if max_objects <= 0:
		push_error("ObjectManager: max_objects must be positive")
		manager_error.emit("Invalid max_objects configuration")
		return
	
	if update_frequency <= 0:
		push_error("ObjectManager: update_frequency must be positive")
		manager_error.emit("Invalid update_frequency configuration")
		return
	
	# Initialize update groups
	_initialize_update_groups()
	
	# Initialize object pools
	_initialize_object_pools()
	
	# Set up frame processing
	set_process(true)
	set_physics_process(true)
	
	is_initialized = true
	
	if enable_debug_logging:
		print("ObjectManager: Initialized successfully")
	
	manager_initialized.emit()

func _initialize_update_groups() -> void:
	"""Initialize update frequency groups."""
	
	for frequency in UpdateFrequency.values():
		update_groups[frequency] = []

func _initialize_object_pools() -> void:
	"""Initialize object pools for common object types."""
	
	# Common pooled object types - expand as needed
	var pooled_types: Array[String] = [
		"Bullet",
		"Particle", 
		"Debris",
		"Effect"
	]
	
	for type in pooled_types:
		object_pools[type] = []

func _process(delta: float) -> void:
	"""Main update loop - handles non-physics object updates."""
	
	if not is_initialized:
		return
	
	# Reset frame counters
	objects_created_this_frame = 0
	objects_destroyed_this_frame = 0
	
	# Process different update frequency groups
	_process_update_groups(delta)

func _physics_process(delta: float) -> void:
	"""Physics update loop - handles physics-related object updates."""
	
	if not is_initialized:
		return
	
	# Emit signal for other systems to know physics frame is complete
	physics_frame_processed.emit()

func _process_update_groups(delta: float) -> void:
	"""Process objects in their assigned update frequency groups."""
	
	var frame_count: int = Engine.get_process_frames()
	
	# 60Hz - every frame
	_update_objects_in_group(UpdateFrequency.FRAME_60HZ, delta)
	
	# 30Hz - every other frame
	if frame_count % 2 == 0:
		_update_objects_in_group(UpdateFrequency.FRAME_30HZ, delta * 2.0)
	
	# 10Hz - every 6th frame
	if frame_count % 6 == 0:
		_update_objects_in_group(UpdateFrequency.FRAME_10HZ, delta * 6.0)
	
	# 1Hz - every 60th frame
	if frame_count % 60 == 0:
		_update_objects_in_group(UpdateFrequency.FRAME_1HZ, delta * 60.0)

func _update_objects_in_group(frequency: UpdateFrequency, delta: float) -> void:
	"""Update all objects in a specific frequency group."""
	
	var objects: Array = update_groups.get(frequency, [])
	
	for object in objects:
		if is_instance_valid(object) and object.has_method("update"):
			object.update(delta)

## Public API for object management

func create_object(type: String, data: Dictionary = {}) -> WCSObject:
	"""Create a new game object with the specified type and data."""
	
	if not is_initialized:
		push_error("ObjectManager: Cannot create object - manager not initialized")
		return null
	
	if active_objects.size() >= max_objects:
		push_error("ObjectManager: Cannot create object - max object limit reached")
		return null
	
	var object: WCSObject = _get_or_create_object(type, data)
	
	if object == null:
		push_error("ObjectManager: Failed to create object of type: %s" % type)
		return null
	
	# Assign unique ID
	object.object_id = _generate_object_id()
	
	# Add to tracking
	active_objects.append(object)
	object_registry[object.object_id] = object
	
	# Add to appropriate update group
	var update_freq: UpdateFrequency = object.get_update_frequency()
	update_groups[update_freq].append(object)
	
	# Connect destruction signal
	if object.has_signal("destroyed"):
		object.destroyed.connect(_on_object_destroyed)
	
	objects_created_this_frame += 1
	
	if enable_debug_logging:
		print("ObjectManager: Created object %s (ID: %d)" % [type, object.object_id])
	
	object_created.emit(object)
	return object

func destroy_object(object: WCSObject) -> void:
	"""Destroy a game object and clean up all references."""
	
	if object == null or not is_instance_valid(object):
		return
	
	# Remove from tracking
	var index: int = active_objects.find(object)
	if index >= 0:
		active_objects.remove_at(index)
	
	object_registry.erase(object.object_id)
	
	# Remove from update groups
	for group in update_groups.values():
		var group_index: int = group.find(object)
		if group_index >= 0:
			group.remove_at(group_index)
	
	# Return to pool if poolable
	if object.is_poolable():
		_return_object_to_pool(object)
	else:
		# Destroy normally
		object.queue_free()
	
	objects_destroyed_this_frame += 1
	
	if enable_debug_logging:
		print("ObjectManager: Destroyed object ID: %d" % object.object_id)
	
	object_destroyed.emit(object)

func get_object_by_id(id: int) -> WCSObject:
	"""Get an object by its unique ID."""
	
	return object_registry.get(id, null)

func get_objects_by_type(type: String) -> Array[WCSObject]:
	"""Get all objects of a specific type."""
	
	var result: Array[WCSObject] = []
	
	for object in active_objects:
		if object.get_object_type() == type:
			result.append(object)
	
	return result

func get_object_count() -> int:
	"""Get the total number of active objects."""
	
	return active_objects.size()

func get_performance_stats() -> Dictionary:
	"""Get performance statistics for debugging."""
	
	return {
		"active_objects": active_objects.size(),
		"max_objects": max_objects,
		"objects_created_this_frame": objects_created_this_frame,
		"objects_destroyed_this_frame": objects_destroyed_this_frame,
		"pool_sizes": _get_pool_sizes(),
		"update_group_sizes": _get_update_group_sizes()
	}

## Private implementation

func _get_or_create_object(type: String, data: Dictionary) -> WCSObject:
	"""Get an object from pool or create a new one."""
	
	# Try to get from pool first
	if object_pools.has(type) and not object_pools[type].is_empty():
		var pooled_object: WCSObject = object_pools[type].pop_back()
		pooled_object.reset_for_reuse(data)
		return pooled_object
	
	# Create new object
	return _create_new_object(type, data)

func _create_new_object(type: String, data: Dictionary) -> WCSObject:
	"""Create a brand new object of the specified type."""
	
	# This would normally load from a scene or create programmatically
	# For now, return null as this needs to be implemented based on object types
	push_error("ObjectManager: Object creation not yet implemented for type: %s" % type)
	return null

func _return_object_to_pool(object: WCSObject) -> void:
	"""Return an object to its type pool for reuse."""
	
	var type: String = object.get_object_type()
	
	if not object_pools.has(type):
		object_pools[type] = []
	
	object.reset_for_pool()
	object_pools[type].append(object)

func _generate_object_id() -> int:
	"""Generate a unique object ID."""
	
	id_counter += 1
	return id_counter

func _get_pool_sizes() -> Dictionary:
	"""Get sizes of all object pools."""
	
	var sizes: Dictionary = {}
	
	for type in object_pools.keys():
		sizes[type] = object_pools[type].size()
	
	return sizes

func _get_update_group_sizes() -> Dictionary:
	"""Get sizes of all update groups."""
	
	var sizes: Dictionary = {}
	
	for freq in update_groups.keys():
		sizes[str(freq) + "Hz"] = update_groups[freq].size()
	
	return sizes

func _on_object_destroyed(object: WCSObject) -> void:
	"""Handle object destruction signal."""
	
	destroy_object(object)

## Get debug statistics for monitoring overlay
func get_debug_stats() -> Dictionary:
	return {
		"active_count": active_objects.size(),
		"max_objects": max_objects,
		"pool_count": object_pools.size(),
		"pooled_count": _get_total_pooled_objects(),
		"update_groups": _get_update_group_counts(),
		"average_frame_time": _get_average_frame_time()
	}

## Register a new object with the manager
func register_object(obj: WCSObject) -> void:
	if active_objects.size() >= max_objects:
		print_rich("[color=red]Warning: ObjectManager at capacity, cannot register new object[/color]")
		return
	
	obj.object_id = _generate_object_id()
	active_objects.append(obj)
	_add_to_update_group(obj)
	object_created.emit(obj)

## Unregister an object from the manager
func unregister_object(obj: WCSObject) -> void:
	var index: int = active_objects.find(obj)
	if index >= 0:
		active_objects.remove_at(index)
		_remove_from_update_group(obj)
		object_destroyed.emit(obj)

## Activate an object for updates
func activate_object(obj: WCSObject) -> void:
	if obj not in active_objects and active_objects.size() < max_objects:
		active_objects.append(obj)
		_add_to_update_group(obj)

## Deactivate an object (remove from updates)
func deactivate_object(obj: WCSObject) -> void:
	var index: int = active_objects.find(obj)
	if index >= 0:
		active_objects.remove_at(index)
		_remove_from_update_group(obj)

## Helper methods for debug stats
func _get_total_pooled_objects() -> int:
	var total: int = 0
	for pool in object_pools.values():
		total += pool.size()
	return total

func _get_update_group_counts() -> Dictionary:
	var counts: Dictionary = {}
	counts["EVERY_FRAME"] = update_groups.get(UpdateFrequency.FRAME_60HZ, []).size()
	counts["HIGH"] = update_groups.get(UpdateFrequency.FRAME_30HZ, []).size() 
	counts["MEDIUM"] = update_groups.get(UpdateFrequency.FRAME_10HZ, []).size()
	counts["LOW"] = update_groups.get(UpdateFrequency.FRAME_1HZ, []).size()
	return counts

func _get_average_frame_time() -> float:
	# Simple performance tracking - would be implemented with proper metrics
	return 0.001  # Placeholder

func _add_to_update_group(obj: WCSObject) -> void:
	var freq: UpdateFrequency
	match obj.update_frequency:
		WCSObject.UpdateFrequency.EVERY_FRAME:
			freq = UpdateFrequency.FRAME_60HZ
		WCSObject.UpdateFrequency.HIGH:
			freq = UpdateFrequency.FRAME_30HZ
		WCSObject.UpdateFrequency.MEDIUM:
			freq = UpdateFrequency.FRAME_10HZ
		WCSObject.UpdateFrequency.LOW:
			freq = UpdateFrequency.FRAME_1HZ
		_:
			freq = UpdateFrequency.FRAME_10HZ
	
	if freq in update_groups:
		update_groups[freq].append(obj)

func _remove_from_update_group(obj: WCSObject) -> void:
	for group in update_groups.values():
		var index: int = group.find(obj)
		if index >= 0:
			group.remove_at(index)
			break

func _return_to_pool(obj: WCSObject) -> void:
	if obj.pool_type in object_pools:
		obj.reset_for_pooling()
		object_pools[obj.pool_type].append(obj)

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the manager is removed."""
	
	if enable_debug_logging:
		print("ObjectManager: Shutting down")
	
	# Clear all object references
	active_objects.clear()
	object_registry.clear()
	
	for group in update_groups.values():
		group.clear()
	
	for pool in object_pools.values():
		for object in pool:
			if is_instance_valid(object):
				object.queue_free()
		pool.clear()