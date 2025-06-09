extends Node

## Enhanced object lifecycle manager with space object registry (EPIC-009)
## Handles creation, updates, and destruction of all game objects including space objects.
##
## This manager provides the foundational object system for WCS-Godot conversion,
## implementing object pooling, lifecycle management, update scheduling, and spatial queries
## to replace the original C++ object pointer system with Godot's node-based approach.

signal object_created(object: WCSObject)
signal object_destroyed(object: WCSObject)
signal physics_frame_processed(delta: float)
signal manager_initialized()
signal manager_shutdown()
signal critical_error(error_message: String)

# Enhanced Space Object Signals (OBJ-002)
signal space_object_created(object: BaseSpaceObject, object_id: int)
signal space_object_destroyed(object: BaseSpaceObject, object_id: int)
signal spatial_query_ready(query_id: int, results: Array[BaseSpaceObject])

# --- Core Classes ---
const WCSObject = preload("res://scripts/core/wcs_object.gd")
const WCSObjectData = preload("res://scripts/core/wcs_object_data.gd")
const BaseSpaceObject = preload("res://scripts/core/objects/base_space_object.gd")

# EPIC-002 Asset Core Integration (MANDATORY for OBJ-002)
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

# Configuration
@export var max_objects: int = 1000
@export var update_frequency: int = 60  # Hz
@export var enable_object_pooling: bool = true
@export var enable_debug_logging: bool = false
@export var max_space_objects: int = 800  # Maximum space objects from wcs_asset_core
@export var spatial_query_grid_size: float = 100.0  # Grid size for spatial partitioning
@export var enable_spatial_optimization: bool = true

# Object tracking (enhanced for OBJ-002)
var active_objects: Array[WCSObject] = []
var object_pools: Dictionary = {}  # String (type) -> Array[WCSObject]
var update_groups: Dictionary = {}  # int (frequency) -> Array[WCSObject]
var id_counter: int = 0

# Enhanced Space Object Registry (OBJ-002)
var space_objects_registry: Dictionary = {}  # int (object_id) -> BaseSpaceObject
var space_objects_by_type: Dictionary = {}  # ObjectTypes.Type -> Array[BaseSpaceObject]
var space_object_pools: Dictionary = {}  # ObjectTypes.Type -> Array[BaseSpaceObject]
var spatial_grid: Dictionary = {}  # Vector3i (grid_pos) -> Array[BaseSpaceObject]
var space_update_groups: Dictionary = {}  # UpdateFrequencies.Frequency -> Array[BaseSpaceObject]

# Spatial query system
var spatial_query_counter: int = 0
var pending_spatial_queries: Dictionary = {}  # int (query_id) -> Dictionary (query_data)

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
	_initialize_space_object_systems()  # OBJ-002 enhancement
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
	
	# OBJ-002 validation
	if max_space_objects <= 0 or max_space_objects > max_objects:
		initialization_error = "max_space_objects must be positive and <= max_objects"
		_handle_critical_error(initialization_error)
		return false
	
	if spatial_query_grid_size <= 0.0:
		initialization_error = "spatial_query_grid_size must be positive"
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

## Enhanced Space Object Systems Initialization (OBJ-002)
func _initialize_space_object_systems() -> void:
	# Initialize space object type pools using wcs_asset_core constants
	for object_type in _get_space_object_types():
		space_objects_by_type[object_type] = []
		space_object_pools[object_type] = []
		if enable_debug_logging:
			print("ObjectManager: Initialized space object pool for type: %s" % ObjectTypes.get_type_name(object_type))
	
	# Initialize update frequency groups using asset core constants
	for frequency in _get_update_frequencies():
		space_update_groups[frequency] = []
		if enable_debug_logging:
			print("ObjectManager: Initialized space update group for %s" % str(frequency))
	
	# Initialize spatial grid
	spatial_grid.clear()
	spatial_query_counter = 0
	pending_spatial_queries.clear()
	
	if enable_debug_logging:
		print("ObjectManager: Space object systems initialized with grid size %.1f" % spatial_query_grid_size)

## Get all space object types from wcs_asset_core
func _get_space_object_types() -> Array[int]:
	return [
		ObjectTypes.Type.SHIP,
		ObjectTypes.Type.FIGHTER,
		ObjectTypes.Type.BOMBER,
		ObjectTypes.Type.CAPITAL,
		ObjectTypes.Type.SUPPORT,
		ObjectTypes.Type.WEAPON,
		ObjectTypes.Type.DEBRIS,
		ObjectTypes.Type.ASTEROID,
		ObjectTypes.Type.CARGO,
		ObjectTypes.Type.WAYPOINT,
		ObjectTypes.Type.EFFECT,
		ObjectTypes.Type.BEAM
	]

## Get all update frequencies from wcs_asset_core
func _get_update_frequencies() -> Array[int]:
	return [
		UpdateFrequencies.Frequency.CRITICAL,
		UpdateFrequencies.Frequency.HIGH,
		UpdateFrequencies.Frequency.MEDIUM,
		UpdateFrequencies.Frequency.LOW,
		UpdateFrequencies.Frequency.MINIMAL
	]

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
	
	# Clear space object collections (OBJ-002)
	_clear_all_space_objects()

# ============================================================================
# ENHANCED SPACE OBJECT API (OBJ-002)
# ============================================================================

## Enhanced space object creation with asset core integration (OBJ-002 AC3)
func create_space_object(object_type: int, physics_profile = null, object_data = null) -> BaseSpaceObject:
	if not is_initialized:
		push_error("ObjectManager: Cannot create space object - manager not initialized")
		return null
	
	if space_objects_registry.size() >= max_space_objects:
		push_warning("ObjectManager: Maximum space object limit reached (%d)" % max_space_objects)
		return null
	
	var new_object: BaseSpaceObject = _get_pooled_space_object(object_type)
	if not new_object:
		new_object = _create_new_space_object(object_type)
	
	if new_object:
		_initialize_space_object(new_object, object_type, physics_profile, object_data)
		_register_space_object(new_object)
		space_object_created.emit(new_object, new_object.get_object_id())
		
		if enable_debug_logging:
			print("ObjectManager: Created space object type %s, ID %d" % [ObjectTypes.get_type_name(object_type), new_object.get_object_id()])
	
	return new_object

## Enhanced space object destruction with proper cleanup (OBJ-002 AC4)
func destroy_space_object(space_object: BaseSpaceObject) -> void:
	if not is_instance_valid(space_object):
		return
	
	var object_id: int = space_object.get_object_id()
	
	if enable_debug_logging:
		print("ObjectManager: Destroying space object ID %d" % object_id)
	
	# Remove from spatial grid
	_remove_from_spatial_grid(space_object)
	
	# Remove from registry and groups
	_unregister_space_object(space_object)
	
	# Return to pool if pooling is enabled
	if enable_object_pooling:
		_return_space_object_to_pool(space_object)
	else:
		space_object.queue_free()
	
	space_object_destroyed.emit(space_object, object_id)

## Get space objects by type using asset core constants (OBJ-002 AC2)
func get_space_objects_by_type(object_type: int) -> Array[BaseSpaceObject]:
	return space_objects_by_type.get(object_type, []).duplicate()

## Get space objects within radius for spatial queries (OBJ-002 AC6)
func get_space_objects_in_radius(center: Vector3, radius: float, object_types: Array[int] = []) -> Array[BaseSpaceObject]:
	var start_time: int = Time.get_ticks_usec()
	var results: Array[BaseSpaceObject] = []
	
	if enable_spatial_optimization:
		results = _spatial_grid_query(center, radius, object_types)
	else:
		results = _brute_force_radius_query(center, radius, object_types)
	
	var query_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	if query_time > 1.0:  # Target: under 1ms
		push_warning("ObjectManager: Spatial query exceeded target time: %.2fms" % query_time)
	
	return results

## Async spatial query with callback (OBJ-002 AC6)
func get_space_objects_in_radius_async(center: Vector3, radius: float, object_types: Array[int] = []) -> int:
	spatial_query_counter += 1
	var query_id: int = spatial_query_counter
	
	# Store query for deferred processing
	pending_spatial_queries[query_id] = {
		"center": center,
		"radius": radius,
		"object_types": object_types,
		"timestamp": Time.get_ticks_msec()
	}
	
	# Process on next frame
	_process_spatial_query.call_deferred(query_id)
	
	return query_id

## Get space object by ID from registry (OBJ-002 AC7)
func get_space_object_by_id(object_id: int) -> BaseSpaceObject:
	return space_objects_registry.get(object_id, null)

## Register existing space object (OBJ-002 AC7)
func register_object(object: WCSObject) -> void:
	if object is BaseSpaceObject:
		_register_space_object(object as BaseSpaceObject)
	else:
		_register_object(object)

## Unregister existing space object (OBJ-002 AC7)
func unregister_object(object: WCSObject) -> void:
	if object is BaseSpaceObject:
		_unregister_space_object(object as BaseSpaceObject)
	else:
		_unregister_object(object)

## Update frequency group management using asset core constants (OBJ-002 AC5)
func get_space_objects_by_frequency(frequency: int) -> Array[BaseSpaceObject]:
	return space_update_groups.get(frequency, []).duplicate()

## SEXP system integration for object queries (OBJ-002 AC8)
func sexp_get_ship_by_name(ship_name: String) -> BaseSpaceObject:
	for space_object in space_objects_registry.values():
		if space_object.name == ship_name and ObjectTypes.is_ship_type(space_object.object_type_enum):
			return space_object
	return null

func sexp_get_ships_in_wing(wing_name: String) -> Array[BaseSpaceObject]:
	var wing_ships: Array[BaseSpaceObject] = []
	for space_object in space_objects_registry.values():
		if ObjectTypes.is_ship_type(space_object.object_type_enum):
			# TODO: Add wing assignment when wing system is implemented
			pass
	return wing_ships

func sexp_get_object_count_by_type(object_type: int) -> int:
	return space_objects_by_type.get(object_type, []).size()

# IFF Management
func is_friendly(team1: int, team2: int) -> bool:
	# A simple implementation for now.
	# In the future, this should use the data from iff_defs_data.gd
	return team1 == team2

func is_hostile(team1: int, team2: int) -> bool:
	# A simple implementation for now.
	# In the future, this should use the data from iff_defs_data.gd
	return team1 != team2

## Clear all space objects
func _clear_all_space_objects() -> void:
	# Destroy all space objects
	var space_objects_to_destroy: Array = space_objects_registry.values().duplicate()
	for space_obj in space_objects_to_destroy:
		destroy_space_object(space_obj as BaseSpaceObject)
	
	# Clear all space object collections
	space_objects_registry.clear()
	for object_type in space_objects_by_type.keys():
		space_objects_by_type[object_type].clear()
	for frequency in space_update_groups.keys():
		space_update_groups[frequency].clear()
	spatial_grid.clear()
	pending_spatial_queries.clear()

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

# ============================================================================
# ENHANCED SPACE OBJECT PRIVATE METHODS (OBJ-002)
# ============================================================================

## Get pooled space object by type (OBJ-002 AC3)
func _get_pooled_space_object(object_type: int) -> BaseSpaceObject:
	if not enable_object_pooling:
		return null
	
	if not space_object_pools.has(object_type):
		space_object_pools[object_type] = []
		return null
	
	var pool: Array = space_object_pools[object_type]
	if pool.is_empty():
		return null
	
	return pool.pop_back() as BaseSpaceObject

## Create new space object instance (OBJ-002 AC3)
func _create_new_space_object(object_type: int) -> BaseSpaceObject:
	var new_object: BaseSpaceObject = BaseSpaceObject.new()
	new_object.set_object_id(_generate_object_id())
	
	# Add to scene tree
	add_child(new_object)
	
	return new_object

## Initialize space object with type and profiles (OBJ-002 AC4)
func _initialize_space_object(space_object: BaseSpaceObject, object_type: int, physics_profile = null, object_data = null) -> void:
	# Initialize with enhanced space object method
	if space_object.has_method("initialize_space_object_enhanced"):
		space_object.call("initialize_space_object_enhanced", object_type, physics_profile, object_data)
	else:
		push_error("ObjectManager: BaseSpaceObject missing initialize_space_object_enhanced method")

## Register space object in all tracking systems (OBJ-002 AC7)
func _register_space_object(space_object: BaseSpaceObject) -> void:
	var object_id: int = space_object.get_object_id()
	var object_type: int = space_object.object_type_enum
	
	# Add to registry
	space_objects_registry[object_id] = space_object
	
	# Add to type-based tracking
	if not space_objects_by_type.has(object_type):
		space_objects_by_type[object_type] = []
	space_objects_by_type[object_type].append(space_object)
	
	# Add to update frequency group based on distance and importance
	var update_frequency: int = _determine_update_frequency(space_object)
	if not space_update_groups.has(update_frequency):
		space_update_groups[update_frequency] = []
	space_update_groups[update_frequency].append(space_object)
	
	# Add to spatial grid
	_add_to_spatial_grid(space_object)
	
	# Also register with legacy system for compatibility
	_register_object(space_object)

## Unregister space object from all tracking systems (OBJ-002 AC7)
func _unregister_space_object(space_object: BaseSpaceObject) -> void:
	var object_id: int = space_object.get_object_id()
	var object_type: int = space_object.object_type_enum
	
	# Remove from registry
	space_objects_registry.erase(object_id)
	
	# Remove from type-based tracking
	if space_objects_by_type.has(object_type):
		var type_array: Array = space_objects_by_type[object_type]
		var index: int = type_array.find(space_object)
		if index >= 0:
			type_array.remove_at(index)
	
	# Remove from update frequency groups
	for frequency in space_update_groups.keys():
		var group: Array = space_update_groups[frequency]
		var group_index: int = group.find(space_object)
		if group_index >= 0:
			group.remove_at(group_index)
			break
	
	# Remove from spatial grid
	_remove_from_spatial_grid(space_object)
	
	# Also unregister from legacy system
	_unregister_object(space_object)

## Return space object to pool (OBJ-002 AC3)
func _return_space_object_to_pool(space_object: BaseSpaceObject) -> void:
	var object_type: int = space_object.object_type_enum
	
	# Reset object state
	space_object.reset_state()
	space_object.set_visible(false)
	space_object.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Return to appropriate pool
	if not space_object_pools.has(object_type):
		space_object_pools[object_type] = []
	
	space_object_pools[object_type].append(space_object)

## Determine update frequency based on object importance and distance (OBJ-002 AC5)
func _determine_update_frequency(space_object: BaseSpaceObject) -> int:
	var object_type: int = space_object.object_type_enum
	
	# Player ships and critical objects get highest priority
	# TODO: Check object_flags when BaseSpaceObject has this property
	# if ObjectTypes.has_flag(space_object.object_flags, ObjectTypes.Flags.PLAYER_SHIP):
	#	return UpdateFrequencies.Frequency.CRITICAL
	
	# Active combat participants get high priority
	if ObjectTypes.is_ship_type(object_type) or ObjectTypes.is_weapon_type(object_type):
		return UpdateFrequencies.Frequency.HIGH
	
	# Environmental objects get medium priority
	if ObjectTypes.is_environment_type(object_type):
		return UpdateFrequencies.Frequency.MEDIUM
	
	# Effects and other objects get low priority
	if ObjectTypes.is_effect_type(object_type):
		return UpdateFrequencies.Frequency.LOW
	
	# System objects get minimal priority
	return UpdateFrequencies.Frequency.MINIMAL

## Add space object to spatial grid (OBJ-002 AC6)
func _add_to_spatial_grid(space_object: BaseSpaceObject) -> void:
	if not enable_spatial_optimization:
		return
	
	var grid_pos: Vector3i = _world_to_grid_position(space_object.global_position)
	
	if not spatial_grid.has(grid_pos):
		spatial_grid[grid_pos] = []
	
	spatial_grid[grid_pos].append(space_object)

## Remove space object from spatial grid (OBJ-002 AC6)
func _remove_from_spatial_grid(space_object: BaseSpaceObject) -> void:
	if not enable_spatial_optimization:
		return
	
	var grid_pos: Vector3i = _world_to_grid_position(space_object.global_position)
	
	if spatial_grid.has(grid_pos):
		var grid_cell: Array = spatial_grid[grid_pos]
		var index: int = grid_cell.find(space_object)
		if index >= 0:
			grid_cell.remove_at(index)
			
		# Clean up empty cells
		if grid_cell.is_empty():
			spatial_grid.erase(grid_pos)

## Convert world position to grid coordinates (OBJ-002 AC6)
func _world_to_grid_position(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(world_pos.x / spatial_query_grid_size),
		int(world_pos.y / spatial_query_grid_size),
		int(world_pos.z / spatial_query_grid_size)
	)

## Spatial grid-based radius query (OBJ-002 AC6)
func _spatial_grid_query(center: Vector3, radius: float, object_types: Array[int]) -> Array[BaseSpaceObject]:
	var results: Array[BaseSpaceObject] = []
	var radius_squared: float = radius * radius
	
	# Calculate grid bounds for query
	var min_grid: Vector3i = _world_to_grid_position(center - Vector3.ONE * radius)
	var max_grid: Vector3i = _world_to_grid_position(center + Vector3.ONE * radius)
	
	# Search grid cells within bounds
	for x in range(min_grid.x, max_grid.x + 1):
		for y in range(min_grid.y, max_grid.y + 1):
			for z in range(min_grid.z, max_grid.z + 1):
				var grid_pos: Vector3i = Vector3i(x, y, z)
				
				if spatial_grid.has(grid_pos):
					for space_object in spatial_grid[grid_pos]:
						if _matches_query_criteria(space_object, center, radius_squared, object_types):
							results.append(space_object)
	
	return results

## Brute force radius query fallback (OBJ-002 AC6)
func _brute_force_radius_query(center: Vector3, radius: float, object_types: Array[int]) -> Array[BaseSpaceObject]:
	var results: Array[BaseSpaceObject] = []
	var radius_squared: float = radius * radius
	
	for space_object in space_objects_registry.values():
		if _matches_query_criteria(space_object, center, radius_squared, object_types):
			results.append(space_object)
	
	return results

## Check if space object matches query criteria (OBJ-002 AC6)
func _matches_query_criteria(space_object: BaseSpaceObject, center: Vector3, radius_squared: float, object_types: Array[int]) -> bool:
	# Check distance
	var distance_squared: float = space_object.global_position.distance_squared_to(center)
	if distance_squared > radius_squared:
		return false
	
	# Check type filter if specified
	if not object_types.is_empty():
		if not object_types.has(space_object.object_type_enum):
			return false
	
	# Check if object is valid and active
	if not is_instance_valid(space_object) or not space_object.is_object_active():
		return false
	
	return true

## Process spatial query asynchronously (OBJ-002 AC6)
func _process_spatial_query(query_id: int) -> void:
	if not pending_spatial_queries.has(query_id):
		return
	
	var query_data: Dictionary = pending_spatial_queries[query_id]
	var results: Array[BaseSpaceObject] = get_space_objects_in_radius(
		query_data["center"],
		query_data["radius"],
		query_data["object_types"]
	)
	
	pending_spatial_queries.erase(query_id)
	spatial_query_ready.emit(query_id, results)

## Enhanced signal connection for space objects (OBJ-002 AC7)
func _on_space_object_destroyed(space_object: BaseSpaceObject) -> void:
	# This method is called by BaseSpaceObject when it's destroyed
	# Ensures proper cleanup even if destroy_space_object wasn't called directly
	_unregister_space_object(space_object)

# Performance and debugging

func get_performance_stats() -> Dictionary:
	return {
		"active_objects": active_objects.size(),
		"objects_created_this_frame": objects_created_this_frame,
		"objects_destroyed_this_frame": objects_destroyed_this_frame,
		"total_pool_size": _get_total_pool_size(),
		"update_groups": _get_update_group_stats(),
		"memory_usage_mb": _estimate_memory_usage(),
		# Enhanced space object stats (OBJ-002)
		"space_objects": space_objects_registry.size(),
		"space_object_pools": _get_space_pool_stats(),
		"spatial_grid_cells": spatial_grid.size(),
		"pending_spatial_queries": pending_spatial_queries.size(),
		"space_update_groups": _get_space_update_group_stats()
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
	var space_object_size: float = space_objects_registry.size() * 0.002  # ~2KB per space object
	var space_pool_size: float = _get_total_space_pool_size() * 0.001  # ~1KB per pooled space object
	var spatial_grid_size: float = spatial_grid.size() * 0.0001  # ~0.1KB per grid cell
	return base_size + object_size + pool_size + space_object_size + space_pool_size + spatial_grid_size

## Get space object pool statistics (OBJ-002)
func _get_space_pool_stats() -> Dictionary:
	var stats: Dictionary = {}
	for object_type in space_object_pools.keys():
		var type_name: String = ObjectTypes.get_type_name(object_type)
		stats[type_name] = (space_object_pools[object_type] as Array).size()
	return stats

## Get space object update group statistics (OBJ-002)
func _get_space_update_group_stats() -> Dictionary:
	var stats: Dictionary = {}
	for frequency in space_update_groups.keys():
		stats[str(frequency)] = (space_update_groups[frequency] as Array).size()
	return stats

## Get total space object pool size (OBJ-002)
func _get_total_space_pool_size() -> int:
	var total: int = 0
	for pool in space_object_pools.values():
		total += (pool as Array).size()
	return total

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
	
	# Clear space object systems (OBJ-002)
	space_objects_registry.clear()
	space_objects_by_type.clear()
	space_object_pools.clear()
	space_update_groups.clear()
	spatial_grid.clear()
	pending_spatial_queries.clear()
	
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
	print("Space objects: %d/%d" % [space_objects_registry.size(), max_space_objects])
	
	var type_counts: Dictionary = {}
	for obj in active_objects:
		if is_instance_valid(obj):
			var type: String = obj.get_object_type()
			type_counts[type] = type_counts.get(type, 0) + 1
	
	print("Objects by type:")
	for type in type_counts.keys():
		print("  %s: %d" % [type, type_counts[type]])
	
	print("Space objects by type:")
	for object_type in space_objects_by_type.keys():
		var type_name: String = ObjectTypes.get_type_name(object_type)
		var count: int = space_objects_by_type[object_type].size()
		if count > 0:
			print("  %s: %d" % [type_name, count])
	
	print("Pool sizes:")
	for type in object_pools.keys():
		print("  %s pool: %d" % [type, (object_pools[type] as Array).size()])
	
	print("Space object pools:")
	for object_type in space_object_pools.keys():
		var type_name: String = ObjectTypes.get_type_name(object_type)
		var pool_size: int = (space_object_pools[object_type] as Array).size()
		if pool_size > 0:
			print("  %s pool: %d" % [type_name, pool_size])
	
	print("Update groups:")
	for frequency in update_groups.keys():
		print("  %dHz: %d objects" % [frequency, (update_groups[frequency] as Array).size()])
	
	print("Space update groups:")
	for frequency in space_update_groups.keys():
		var group_size: int = (space_update_groups[frequency] as Array).size()
		if group_size > 0:
			print("  %s: %d objects" % [str(frequency), group_size])
	
	print("Spatial grid: %d cells" % spatial_grid.size())
	print("Pending queries: %d" % pending_spatial_queries.size())
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
	
	# Enhanced space object validation (OBJ-002)
	valid = _validate_space_object_integrity() && valid
	
	return valid

## Validate space object system integrity (OBJ-002)
func _validate_space_object_integrity() -> bool:
	var valid: bool = true
	
	# Check for null space objects in registry
	for object_id in space_objects_registry.keys():
		var space_object: BaseSpaceObject = space_objects_registry[object_id]
		if not is_instance_valid(space_object):
			push_error("ObjectManager: Found invalid space object in registry, ID: %d" % object_id)
			valid = false
		elif space_object.get_object_id() != object_id:
			push_error("ObjectManager: Space object ID mismatch - Registry: %d, Object: %d" % [object_id, space_object.get_object_id()])
			valid = false
	
	# Check type consistency
	for object_type in space_objects_by_type.keys():
		var type_array: Array = space_objects_by_type[object_type]
		for space_object in type_array:
			if is_instance_valid(space_object):
				if space_object.object_type_enum != object_type:
					push_error("ObjectManager: Space object type mismatch - Expected: %s, Actual: %s" % [ObjectTypes.get_type_name(object_type), ObjectTypes.get_type_name(space_object.object_type_enum)])
					valid = false
			else:
				push_error("ObjectManager: Found invalid space object in type array: %s" % ObjectTypes.get_type_name(object_type))
				valid = false
	
	# Check for space objects in multiple update groups
	var all_space_grouped_objects: Array = []
	for frequency in space_update_groups.keys():
		var group: Array = space_update_groups[frequency]
		for space_obj in group:
			if all_space_grouped_objects.has(space_obj):
				push_error("ObjectManager: Space object found in multiple update groups")
				valid = false
			all_space_grouped_objects.append(space_obj)
	
	# Validate spatial grid consistency
	for grid_pos in spatial_grid.keys():
		var grid_cell: Array = spatial_grid[grid_pos]
		for space_object in grid_cell:
			if is_instance_valid(space_object):
				var expected_grid_pos: Vector3i = _world_to_grid_position(space_object.global_position)
				if expected_grid_pos != grid_pos:
					push_warning("ObjectManager: Space object in wrong grid cell - Expected: %s, Actual: %s" % [str(expected_grid_pos), str(grid_pos)])
					# Note: This is a warning as objects can move between frames
			else:
				push_error("ObjectManager: Found invalid space object in spatial grid")
				valid = false
	
	return valid
