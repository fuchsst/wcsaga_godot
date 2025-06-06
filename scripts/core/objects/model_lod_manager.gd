class_name ModelLODManager
extends Node

## LOD (Level of Detail) management system integrated with EPIC-008 Graphics Rendering Engine
## Provides distance-based LOD switching with automatic optimization and performance monitoring
## Integrates with EPIC-003 converted POF models and EPIC-002 ModelMetadata

# EPIC-002 Asset Core Integration
const ModelMetadata = preload("res://addons/wcs_asset_core/resources/object/model_metadata.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

# LOD System Signals (AC3)
signal lod_level_changed(space_object: BaseSpaceObject, old_level: int, new_level: int)
signal lod_update_completed(objects_processed: int, total_time_ms: float)
signal lod_performance_warning(object: BaseSpaceObject, switch_time_ms: float)

# Performance tracking for 0.1ms LOD switching target (AC3)
var _lod_switch_times: Array[float] = []
var _camera_position: Vector3 = Vector3.ZERO
var _update_interval: float = 0.1  # Update LOD every 100ms for performance

# LOD distance thresholds (configurable based on object importance)
var _base_lod_distances: Array[float] = [50.0, 150.0, 400.0, 1000.0, 2500.0, 5000.0, 10000.0]
var _importance_multipliers: Dictionary = {
	ObjectTypes.Type.SHIP: 1.0,
	ObjectTypes.Type.CAPITAL: 0.5,  # Keep detailed longer
	ObjectTypes.Type.FIGHTER: 1.2,  # Switch earlier
	ObjectTypes.Type.WEAPON: 2.0,   # Switch much earlier
	ObjectTypes.Type.DEBRIS: 3.0,   # Switch very early
	ObjectTypes.Type.CARGO: 1.5
}

# Registered objects for LOD management
var _managed_objects: Dictionary = {}  # BaseSpaceObject -> LODObjectData
var _update_timer: float = 0.0

# EPIC-008 Graphics Engine integration
var graphics_engine: Node = null
var performance_monitor: Node = null

class LODObjectData:
	var space_object: BaseSpaceObject
	var current_lod_level: int = 0
	var model_metadata: ModelMetadata = null
	var importance_multiplier: float = 1.0
	var last_distance: float = 0.0
	var lod_locked: bool = false  # For cutscenes or important events
	
	func _init(obj: BaseSpaceObject, metadata: ModelMetadata = null) -> void:
		space_object = obj
		model_metadata = metadata
		if obj.has_meta("object_type_enum"):
			var obj_type: int = obj.get_meta("object_type_enum", ObjectTypes.Type.NONE)
			importance_multiplier = _get_importance_multiplier(obj_type)

func _ready() -> void:
	name = "ModelLODManager"
	_initialize_graphics_integration()
	set_process(true)

## Initialize EPIC-008 Graphics integration
func _initialize_graphics_integration() -> void:
	graphics_engine = get_node_or_null("/root/GraphicsRenderingEngine")
	if graphics_engine:
		performance_monitor = graphics_engine.get("performance_monitor")
		print("ModelLODManager: Integrated with EPIC-008 Graphics Rendering Engine")
	else:
		push_warning("ModelLODManager: Graphics Rendering Engine not found")

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_all_lod_levels()
		_update_timer = 0.0

## Register BaseSpaceObject for LOD management (AC3)
func register_object_for_lod(space_object: BaseSpaceObject) -> bool:
	if not space_object or not space_object.mesh_instance:
		return false
	
	# Get model metadata from EPIC-003 converted POF model
	var metadata: ModelMetadata = space_object.get_meta("model_metadata", null)
	if not metadata or metadata.detail_level_paths.size() <= 1:
		# No LOD levels available from POF conversion
		return false
	
	# Create LOD data for this object
	var lod_data: LODObjectData = LODObjectData.new(space_object, metadata)
	_managed_objects[space_object] = lod_data
	
	print("ModelLODManager: Registered object %s with %d LOD levels" % [space_object.name, metadata.detail_level_paths.size()])
	return true

## Unregister object from LOD management
func unregister_object(space_object: BaseSpaceObject) -> void:
	if _managed_objects.has(space_object):
		_managed_objects.erase(space_object)

## Update camera position for LOD calculations (called by camera system)
func update_camera_position(new_position: Vector3) -> void:
	_camera_position = new_position

## Update LOD levels for all managed objects
func _update_all_lod_levels() -> void:
	var start_time: int = Time.get_ticks_msec()
	var objects_processed: int = 0
	
	for space_object in _managed_objects.keys():
		if is_instance_valid(space_object):
			_update_object_lod(space_object)
			objects_processed += 1
		else:
			# Clean up invalid objects
			_managed_objects.erase(space_object)
	
	var total_time: float = (Time.get_ticks_msec() - start_time) / 1000.0
	lod_update_completed.emit(objects_processed, total_time * 1000)

## Update LOD level for specific object
func _update_object_lod(space_object: BaseSpaceObject) -> void:
	var lod_data: LODObjectData = _managed_objects.get(space_object, null)
	if not lod_data or lod_data.lod_locked:
		return
	
	var distance: float = space_object.global_position.distance_to(_camera_position)
	lod_data.last_distance = distance
	
	# Calculate appropriate LOD level based on distance and importance
	var new_lod_level: int = _calculate_lod_level(distance, lod_data.importance_multiplier, lod_data.model_metadata)
	
	if new_lod_level != lod_data.current_lod_level:
		_switch_lod_level(space_object, lod_data, new_lod_level)

## Calculate appropriate LOD level based on distance and importance
func _calculate_lod_level(distance: float, importance_multiplier: float, metadata: ModelMetadata) -> int:
	var adjusted_distances: Array[float] = []
	
	# Apply importance multiplier to distance thresholds
	for base_distance in _base_lod_distances:
		adjusted_distances.append(base_distance * importance_multiplier)
	
	# Find appropriate LOD level
	var lod_level: int = 0
	var max_lod: int = metadata.detail_level_paths.size() - 1
	
	for i in range(min(adjusted_distances.size(), max_lod)):
		if distance > adjusted_distances[i]:
			lod_level = i + 1
	
	return min(lod_level, max_lod)

## Switch LOD level with performance tracking (AC3 - 0.1ms target)
func _switch_lod_level(space_object: BaseSpaceObject, lod_data: LODObjectData, new_lod_level: int) -> void:
	var switch_start: int = Time.get_ticks_usec()
	var old_lod_level: int = lod_data.current_lod_level
	
	# Get LOD model path from EPIC-003 converted POF model metadata
	var lod_model_path: String = lod_data.model_metadata.detail_level_paths[new_lod_level]
	
	# Load and apply LOD model (converted from POF by EPIC-003 pipeline)
	var lod_model: Mesh = load(lod_model_path) as Mesh
	if not lod_model:
		push_error("ModelLODManager: Failed to load LOD level %d model: %s" % [new_lod_level, lod_model_path])
		return
	
	# Apply LOD model to mesh instance
	space_object.mesh_instance.mesh = lod_model
	lod_data.current_lod_level = new_lod_level
	
	# Track performance (AC3 - targeting 0.1ms)
	var switch_time: float = (Time.get_ticks_usec() - switch_start) / 1000000.0  # Convert to seconds
	_lod_switch_times.append(switch_time)
	if _lod_switch_times.size() > 100:
		_lod_switch_times.pop_front()
	
	# Check performance target: LOD switching under 0.1ms
	if switch_time > 0.0001:  # 0.1ms = 0.0001s
		var switch_time_ms: float = switch_time * 1000
		push_warning("ModelLODManager: LOD switch exceeded 0.1ms target: %.3fms for %s" % [switch_time_ms, space_object.name])
		lod_performance_warning.emit(space_object, switch_time_ms)
	
	# Notify EPIC-008 performance monitor if available
	if performance_monitor and performance_monitor.has_method("record_lod_switch"):
		performance_monitor.record_lod_switch(space_object, switch_time * 1000)
	
	lod_level_changed.emit(space_object, old_lod_level, new_lod_level)

## Force specific LOD level (for cutscenes, debugging, etc.)
func force_lod_level(space_object: BaseSpaceObject, lod_level: int, lock: bool = false) -> bool:
	var lod_data: LODObjectData = _managed_objects.get(space_object, null)
	if not lod_data:
		return false
	
	if lod_level < 0 or lod_level >= lod_data.model_metadata.detail_level_paths.size():
		push_error("ModelLODManager: Invalid LOD level %d for object %s" % [lod_level, space_object.name])
		return false
	
	_switch_lod_level(space_object, lod_data, lod_level)
	lod_data.lod_locked = lock
	return true

## Unlock LOD level to resume automatic management
func unlock_lod_level(space_object: BaseSpaceObject) -> void:
	var lod_data: LODObjectData = _managed_objects.get(space_object, null)
	if lod_data:
		lod_data.lod_locked = false

## Get current LOD level for object
func get_current_lod_level(space_object: BaseSpaceObject) -> int:
	var lod_data: LODObjectData = _managed_objects.get(space_object, null)
	return lod_data.current_lod_level if lod_data else -1

## Get LOD statistics for performance monitoring
func get_lod_performance_stats() -> Dictionary:
	var avg_switch_time: float = 0.0
	var max_switch_time: float = 0.0
	var violations_count: int = 0
	
	if _lod_switch_times.size() > 0:
		for time in _lod_switch_times:
			avg_switch_time += time
			max_switch_time = max(max_switch_time, time)
			if time > 0.0001:  # 0.1ms violation
				violations_count += 1
		avg_switch_time /= _lod_switch_times.size()
	
	return {
		"average_switch_time_ms": avg_switch_time * 1000,
		"max_switch_time_ms": max_switch_time * 1000,
		"performance_violations": violations_count,
		"total_switches": _lod_switch_times.size(),
		"managed_objects_count": _managed_objects.size()
	}

## Configure LOD distance thresholds
func configure_lod_distances(new_distances: Array[float]) -> void:
	_base_lod_distances = new_distances.duplicate()

## Configure importance multiplier for object type
func configure_importance_multiplier(object_type: int, multiplier: float) -> void:
	_importance_multipliers[object_type] = multiplier

## Get importance multiplier for object type
func _get_importance_multiplier(object_type: int) -> float:
	return _importance_multipliers.get(object_type, 1.0)

## Clear performance history
func clear_performance_history() -> void:
	_lod_switch_times.clear()

## Set LOD update interval (default 0.1s for performance)
func set_update_interval(interval: float) -> void:
	_update_interval = max(0.01, interval)  # Minimum 10ms

## Get debug information for specific object
func get_object_debug_info(space_object: BaseSpaceObject) -> Dictionary:
	var lod_data: LODObjectData = _managed_objects.get(space_object, null)
	if not lod_data:
		return {}
	
	return {
		"current_lod_level": lod_data.current_lod_level,
		"last_distance": lod_data.last_distance,
		"importance_multiplier": lod_data.importance_multiplier,
		"lod_locked": lod_data.lod_locked,
		"available_lod_levels": lod_data.model_metadata.detail_level_paths.size() if lod_data.model_metadata else 0
	}