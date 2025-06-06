class_name AnimationCoordinator
extends Node

## Animation coordinator for complex space objects
## Manages multiple subsystem animations and coordinates with LOD system for performance optimization
## Implements AC4 (coordinates multiple animation systems) and AC5 (performance optimization)

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const ModelMetadata = preload("res://addons/wcs_asset_core/resources/object/model_metadata.gd")

# Animation coordination signals
signal animation_system_ready(space_object: BaseSpaceObject)
signal animation_lod_changed(space_object: BaseSpaceObject, old_level: int, new_level: int)
signal animation_performance_warning(space_object: BaseSpaceObject, frame_time_ms: float)

# Animation LOD levels for performance optimization (AC5)
enum AnimationLOD {
	HIGH_DETAIL = 0,    # All animations enabled, highest frequency
	MEDIUM_DETAIL = 1,  # Essential animations only, medium frequency
	LOW_DETAIL = 2,     # Critical animations only, low frequency
	MINIMAL_DETAIL = 3  # No animations except critical alerts
}

# Animation priority levels
enum AnimationPriority {
	CRITICAL = 0,    # Essential for gameplay (weapon turrets)
	HIGH = 1,        # Important for immersion (engine thrust)
	MEDIUM = 2,      # Visual enhancement (radar rotation)
	LOW = 3          # Background detail (minor subsystem animations)
}

# Component references
var _subsystem_integration: Node = null
var _animation_controller: Node = null
var _damage_visualizer: Node = null
var _lod_manager: Node = null

# Animation state tracking
var _current_animation_lod: AnimationLOD = AnimationLOD.HIGH_DETAIL
var _animation_performance_budget: float = 0.2  # ms per frame (AC5)
var _distance_to_camera: float = 0.0
var _object_importance: float = 1.0  # Multiplier for importance-based LOD

# LOD distance thresholds (configurable based on object type)
var _lod_distance_thresholds: Array[float] = [100.0, 300.0, 800.0, 2000.0]
var _last_performance_check: float = 0.0
var _performance_check_interval: float = 0.5  # Check every 500ms

# Animation group management
var _animation_groups: Dictionary = {}  # group_name -> Array[subsystem_names]
var _group_priorities: Dictionary = {}  # group_name -> AnimationPriority

func _ready() -> void:
	name = "AnimationCoordinator"
	_initialize_component_references()
	_setup_animation_groups()
	_configure_lod_thresholds()

## Initialize references to other animation components
func _initialize_component_references() -> void:
	var parent_space_object: BaseSpaceObject = get_parent() as BaseSpaceObject
	if not parent_space_object:
		push_error("AnimationCoordinator: Must be child of BaseSpaceObject")
		return
	
	# Find sibling components
	_subsystem_integration = parent_space_object.find_child("ModelSubsystemIntegration", false, false)
	_animation_controller = parent_space_object.find_child("SubsystemAnimationController", false, false)
	_damage_visualizer = parent_space_object.find_child("SubsystemDamageVisualizer", false, false)
	
	# Find LOD manager from optimization system
	var optimization_container: Node = parent_space_object.find_child("optimization", false, false)
	if optimization_container:
		_lod_manager = optimization_container.find_child("LODManager", false, false)
	
	# Connect to animation events
	if _animation_controller:
		_animation_controller.animation_started.connect(_on_animation_started)
		_animation_controller.animation_completed.connect(_on_animation_completed)

## Setup animation groups for coordinated control (AC4)
func _setup_animation_groups() -> void:
	# Weapon systems group (critical priority)
	_animation_groups["weapons"] = []
	_group_priorities["weapons"] = AnimationPriority.CRITICAL
	
	# Engine systems group (high priority)
	_animation_groups["engines"] = []
	_group_priorities["engines"] = AnimationPriority.HIGH
	
	# Docking systems group (high priority)
	_animation_groups["docking"] = []
	_group_priorities["docking"] = AnimationPriority.HIGH
	
	# Sensors group (medium priority)
	_animation_groups["sensors"] = []
	_group_priorities["sensors"] = AnimationPriority.MEDIUM
	
	# Auxiliary systems group (low priority)
	_animation_groups["auxiliary"] = []
	_group_priorities["auxiliary"] = AnimationPriority.LOW

## Configure LOD distance thresholds based on object type
func _configure_lod_thresholds() -> void:
	var space_object: BaseSpaceObject = get_parent() as BaseSpaceObject
	if not space_object:
		return
	
	var object_type: int = space_object.object_type
	
	# Adjust thresholds based on object type
	match object_type:
		ObjectTypes.Type.CAPITAL:
			# Capital ships visible from farther away
			_lod_distance_thresholds = [200.0, 600.0, 1500.0, 4000.0]
			_object_importance = 1.5
		ObjectTypes.Type.SHIP:
			# Standard fighter/bomber thresholds
			_lod_distance_thresholds = [100.0, 300.0, 800.0, 2000.0]
			_object_importance = 1.0
		ObjectTypes.Type.SUPPORT:
			# Support ships less important
			_lod_distance_thresholds = [75.0, 200.0, 500.0, 1200.0]
			_object_importance = 0.8
		_:
			# Default thresholds for other objects
			_lod_distance_thresholds = [50.0, 150.0, 400.0, 1000.0]
			_object_importance = 0.6

func _process(delta: float) -> void:
	# Performance optimization - limit LOD update frequency
	var current_time: float = Time.get_time_dict_from_system()["msec"] / 1000.0
	if current_time - _last_performance_check < _performance_check_interval:
		return
	
	_last_performance_check = current_time
	
	# Update animation LOD based on distance and performance
	_update_animation_lod()
	
	# Monitor animation performance
	_monitor_animation_performance()

## Initialize animation system for space object (AC1, AC2)
func initialize_animation_system(space_object: BaseSpaceObject, metadata: ModelMetadata) -> bool:
	if not space_object or not metadata:
		return false
	
	# Initialize subsystem animations through controller
	if _animation_controller:
		_animation_controller.initialize_subsystem_animations(space_object, metadata)
	
	# Initialize damage visualization
	if _damage_visualizer:
		# Connect to subsystem signals if not already connected
		if _subsystem_integration:
			pass  # Already connected in _initialize_component_references
	
	# Populate animation groups based on created subsystems
	_populate_animation_groups(space_object)
	
	# Set initial animation LOD
	_update_animation_lod()
	
	animation_system_ready.emit(space_object)
	return true

## Populate animation groups with actual subsystem names
func _populate_animation_groups(space_object: BaseSpaceObject) -> void:
	if not _subsystem_integration:
		return
	
	var subsystems: Array[Node3D] = _subsystem_integration.get_all_subsystems(space_object)
	
	for subsystem in subsystems:
		var subsystem_name: String = subsystem.name
		
		# Categorize subsystems into groups
		if subsystem_name.begins_with("Weapons"):
			_animation_groups["weapons"].append(subsystem_name)
		elif subsystem_name.begins_with("Engine"):
			_animation_groups["engines"].append(subsystem_name)
		elif subsystem_name.begins_with("Docking"):
			_animation_groups["docking"].append(subsystem_name)
		elif subsystem_name in ["Radar", "Navigation", "Communication"]:
			_animation_groups["sensors"].append(subsystem_name)
		else:
			_animation_groups["auxiliary"].append(subsystem_name)

## Update animation LOD based on distance and performance (AC5)
func _update_animation_lod() -> void:
	var new_lod: AnimationLOD = _calculate_optimal_animation_lod()
	
	if new_lod != _current_animation_lod:
		var old_lod: AnimationLOD = _current_animation_lod
		_current_animation_lod = new_lod
		
		# Apply LOD changes to animation systems
		_apply_animation_lod_changes(old_lod, new_lod)
		
		animation_lod_changed.emit(get_parent() as BaseSpaceObject, old_lod, new_lod)

## Calculate optimal animation LOD level
func _calculate_optimal_animation_lod() -> AnimationLOD:
	# Get distance from camera (would be updated by camera system)
	var adjusted_distance: float = _distance_to_camera / _object_importance
	
	# Determine LOD based on distance thresholds
	if adjusted_distance < _lod_distance_thresholds[0]:
		return AnimationLOD.HIGH_DETAIL
	elif adjusted_distance < _lod_distance_thresholds[1]:
		return AnimationLOD.MEDIUM_DETAIL
	elif adjusted_distance < _lod_distance_thresholds[2]:
		return AnimationLOD.LOW_DETAIL
	else:
		return AnimationLOD.MINIMAL_DETAIL

## Apply LOD changes to animation systems
func _apply_animation_lod_changes(old_lod: AnimationLOD, new_lod: AnimationLOD) -> void:
	if not _animation_controller:
		return
	
	# Configure animation controller performance settings based on LOD
	match new_lod:
		AnimationLOD.HIGH_DETAIL:
			_animation_controller.configure_performance(60.0, 0.2)  # 60Hz, 0.2ms budget
			_enable_animation_groups([AnimationPriority.CRITICAL, AnimationPriority.HIGH, AnimationPriority.MEDIUM, AnimationPriority.LOW])
		
		AnimationLOD.MEDIUM_DETAIL:
			_animation_controller.configure_performance(30.0, 0.15)  # 30Hz, 0.15ms budget
			_enable_animation_groups([AnimationPriority.CRITICAL, AnimationPriority.HIGH, AnimationPriority.MEDIUM])
		
		AnimationLOD.LOW_DETAIL:
			_animation_controller.configure_performance(15.0, 0.1)  # 15Hz, 0.1ms budget
			_enable_animation_groups([AnimationPriority.CRITICAL, AnimationPriority.HIGH])
		
		AnimationLOD.MINIMAL_DETAIL:
			_animation_controller.configure_performance(5.0, 0.05)  # 5Hz, 0.05ms budget
			_enable_animation_groups([AnimationPriority.CRITICAL])

## Enable/disable animation groups based on priority levels
func _enable_animation_groups(enabled_priorities: Array[AnimationPriority]) -> void:
	for group_name in _animation_groups.keys():
		var group_priority: AnimationPriority = _group_priorities[group_name]
		var should_enable: bool = group_priority in enabled_priorities
		
		# Enable or disable animations for entire group
		if should_enable:
			_enable_animation_group(group_name)
		else:
			_disable_animation_group(group_name)

## Enable animations for specific group
func _enable_animation_group(group_name: String) -> void:
	if group_name not in _animation_groups:
		return
	
	var subsystem_names: Array = _animation_groups[group_name]
	
	# Re-enable animations for subsystems in this group
	# Note: This doesn't start new animations, just allows them to be queued
	for subsystem_name in subsystem_names:
		var space_object: BaseSpaceObject = get_parent() as BaseSpaceObject
		var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
		if subsystem:
			subsystem.set_meta("animations_enabled", true)

## Disable animations for specific group
func _disable_animation_group(group_name: String) -> void:
	if group_name not in _animation_groups:
		return
	
	var subsystem_names: Array = _animation_groups[group_name]
	
	# Stop and disable animations for subsystems in this group
	for subsystem_name in subsystem_names:
		if _animation_controller:
			_animation_controller.stop_subsystem_animations(subsystem_name)
		
		var space_object: BaseSpaceObject = get_parent() as BaseSpaceObject
		var subsystem: Node3D = _find_subsystem(space_object, subsystem_name)
		if subsystem:
			subsystem.set_meta("animations_enabled", false)

## Monitor animation performance and emit warnings if needed (AC5)
func _monitor_animation_performance() -> void:
	if not _animation_controller:
		return
	
	var performance_stats: Dictionary = _animation_controller.get_animation_performance_stats()
	var current_budget: float = performance_stats.get("performance_budget_ms", 0.2)
	
	# Check if we're exceeding performance budget frequently
	# This is a simplified check - in practice, would track frame times over multiple frames
	if current_budget > _animation_performance_budget * 1.5:
		animation_performance_warning.emit(get_parent() as BaseSpaceObject, current_budget)
		
		# Automatically reduce LOD if performance is poor
		_reduce_animation_lod_for_performance()

## Reduce animation LOD to improve performance
func _reduce_animation_lod_for_performance() -> void:
	var new_lod: AnimationLOD = _current_animation_lod
	
	# Step down one LOD level
	match _current_animation_lod:
		AnimationLOD.HIGH_DETAIL:
			new_lod = AnimationLOD.MEDIUM_DETAIL
		AnimationLOD.MEDIUM_DETAIL:
			new_lod = AnimationLOD.LOW_DETAIL
		AnimationLOD.LOW_DETAIL:
			new_lod = AnimationLOD.MINIMAL_DETAIL
		AnimationLOD.MINIMAL_DETAIL:
			return  # Already at minimum
	
	if new_lod != _current_animation_lod:
		var old_lod: AnimationLOD = _current_animation_lod
		_current_animation_lod = new_lod
		_apply_animation_lod_changes(old_lod, new_lod)

## Coordinate group animations (AC4)
func coordinate_group_animation(group_name: String, animation_type: String, synchronized: bool = false) -> bool:
	if group_name not in _animation_groups:
		return false
	
	if not _animation_controller:
		return false
	
	var subsystem_names: Array = _animation_groups[group_name]
	var success_count: int = 0
	
	# Calculate timing for synchronized animations
	var base_time: float = Time.get_time_dict_from_system()["msec"] / 1000.0
	var delay_increment: float = 0.1 if synchronized else 0.0  # 100ms delay between subsystems
	
	for i in range(subsystem_names.size()):
		var subsystem_name: String = subsystem_names[i]
		var delay: float = delay_increment * i if synchronized else 0.0
		
		# Queue animation with appropriate delay for synchronization
		if _queue_delayed_animation(subsystem_name, animation_type, delay):
			success_count += 1
	
	return success_count > 0

## Queue animation with delay for synchronization
func _queue_delayed_animation(subsystem_name: String, animation_type: String, delay: float) -> bool:
	# This would integrate with the animation controller's queue system
	# For now, we'll trigger immediately if no delay
	if delay <= 0.0:
		return _trigger_subsystem_animation(subsystem_name, animation_type)
	
	# Create timer for delayed execution
	var timer: Timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(_trigger_subsystem_animation.bind(subsystem_name, animation_type))
	add_child(timer)
	timer.start()
	
	# Auto-remove timer after use
	timer.timeout.connect(timer.queue_free)
	
	return true

## Trigger specific subsystem animation
func _trigger_subsystem_animation(subsystem_name: String, animation_type: String) -> bool:
	if not _animation_controller:
		return false
	
	var space_object: BaseSpaceObject = get_parent() as BaseSpaceObject
	if not space_object:
		return false
	
	# Map animation type to controller methods
	match animation_type:
		"turret_rotation":
			return _animation_controller.trigger_turret_rotation(space_object, subsystem_name, Vector3.FORWARD, 2.0)
		"engine_thrust":
			return _animation_controller.trigger_engine_thrust(space_object, subsystem_name, 1.0, 1.0)
		"docking_door_open":
			return _animation_controller.trigger_docking_door(space_object, subsystem_name, true, 3.0)
		"docking_door_close":
			return _animation_controller.trigger_docking_door(space_object, subsystem_name, false, 3.0)
		_:
			push_warning("AnimationCoordinator: Unknown animation type '%s'" % animation_type)
			return false

## Update camera distance for LOD calculations
func update_camera_distance(distance: float) -> void:
	_distance_to_camera = distance

## Set object importance multiplier for LOD calculations
func set_object_importance(importance: float) -> void:
	_object_importance = clamp(importance, 0.1, 3.0)

## Handle animation start events
func _on_animation_started(subsystem_name: String, animation_type: String) -> void:
	# Track animation starts for performance monitoring
	pass

## Handle animation completion events
func _on_animation_completed(subsystem_name: String, animation_type: String) -> void:
	# Track animation completions for coordination
	pass

## Find subsystem by name in space object
func _find_subsystem(space_object: BaseSpaceObject, subsystem_name: String) -> Node3D:
	var subsystems_container: Node = space_object.find_child("Subsystems", false, false)
	if not subsystems_container:
		return null
	
	return subsystems_container.find_child(subsystem_name, false, false) as Node3D

## Get animation system status information
func get_animation_system_status() -> Dictionary:
	var status: Dictionary = {
		"current_lod": _current_animation_lod,
		"distance_to_camera": _distance_to_camera,
		"object_importance": _object_importance,
		"performance_budget_ms": _animation_performance_budget,
		"animation_groups": {},
		"components_connected": {
			"subsystem_integration": _subsystem_integration != null,
			"animation_controller": _animation_controller != null,
			"damage_visualizer": _damage_visualizer != null,
			"lod_manager": _lod_manager != null
		}
	}
	
	# Add group information
	for group_name in _animation_groups.keys():
		status["animation_groups"][group_name] = {
			"subsystem_count": _animation_groups[group_name].size(),
			"priority": _group_priorities[group_name],
			"subsystems": _animation_groups[group_name]
		}
	
	return status

## Configure performance budgets
func configure_performance_budget(budget_ms: float) -> void:
	_animation_performance_budget = clamp(budget_ms, 0.05, 2.0)

## Force specific animation LOD level (for testing/debugging)
func force_animation_lod(lod_level: AnimationLOD) -> void:
	var old_lod: AnimationLOD = _current_animation_lod
	_current_animation_lod = lod_level
	_apply_animation_lod_changes(old_lod, lod_level)