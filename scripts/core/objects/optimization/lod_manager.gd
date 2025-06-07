class_name LODManager
extends Node

## Level of Detail Manager for Physics Optimization
## 
## Manages physics update frequency based on distance, threat level, and gameplay importance.
## Implements WCS-style performance optimization with automatic frame rate adaptation.
##
## Key features:
## - Distance-based LOD calculation
## - Threat level consideration for combat scenarios  
## - Automatic optimization based on frame rate performance
## - Physics culling for very distant objects
## - Performance monitoring and adaptive scaling

# EPIC-002 Asset Core Integration - MANDATORY
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

signal lod_level_changed(object: Node3D, new_level: UpdateFrequencies.Frequency)
signal object_culled(object: Node3D)
signal object_unculled(object: Node3D)
signal performance_optimization_triggered(optimization_type: String, details: Dictionary)

# LOD Configuration (tuned based on WCS analysis)
@export_group("LOD Distance Thresholds")
@export var near_distance_threshold: float = 2000.0   # HIGH to MEDIUM transition
@export var medium_distance_threshold: float = 5000.0  # MEDIUM to LOW transition  
@export var far_distance_threshold: float = 10000.0   # LOW to MINIMAL transition
@export var cull_distance_threshold: float = 20000.0  # Physics culling threshold

@export_group("Performance Optimization")
@export var target_frame_rate: float = 60.0          # Target FPS
@export var performance_margin: float = 0.9          # Performance threshold (90% of target)
@export var auto_optimization_enabled: bool = true   # Enable automatic optimization
@export var physics_step_budget_ms: float = 2.0      # Target physics step time budget

@export_group("Threat Level Modifiers")
@export var combat_boost_multiplier: float = 2.0     # Boost for objects in combat
@export var player_importance_radius: float = 1000.0 # Always high frequency around player
@export var weapon_importance_radius: float = 500.0  # Always high frequency for nearby weapons

# Runtime State
var registered_objects: Dictionary = {}              # object_id -> LODObjectData
var player_position: Vector3 = Vector3.ZERO
var current_frame_rate: float = 60.0
var physics_step_time_ms: float = 0.0
var optimization_active: bool = false

# Performance tracking
var lod_calculations_per_frame: int = 0
var objects_culled_count: int = 0
var performance_samples: Array[float] = []
var last_optimization_time: float = 0.0

# LOD Object Data Structure
class LODObjectData:
	var object: Node3D
	var current_frequency: UpdateFrequencies.Frequency
	var last_distance: float
	var threat_level: int
	var object_type: ObjectTypes.Type
	var is_culled: bool
	var last_update_time: float
	var update_interval: float

	func _init(obj: Node3D, obj_type: ObjectTypes.Type) -> void:
		object = obj
		object_type = obj_type
		current_frequency = UpdateFrequencies.Frequency.HIGH
		last_distance = 0.0
		threat_level = 0
		is_culled = false
		last_update_time = 0.0
		update_interval = _calculate_update_interval(current_frequency)
	
	func _calculate_update_interval(frequency: UpdateFrequencies.Frequency) -> float:
		match frequency:
			UpdateFrequencies.Frequency.HIGH:
				return 1.0 / 60.0  # 60 FPS
			UpdateFrequencies.Frequency.MEDIUM:
				return 1.0 / 30.0  # 30 FPS
			UpdateFrequencies.Frequency.LOW:
				return 1.0 / 15.0  # 15 FPS
			UpdateFrequencies.Frequency.MINIMAL:
				return 1.0 / 5.0   # 5 FPS
			_:
				return 1.0 / 60.0  # Default to high frequency

func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	
	# Connect to performance signals
	if has_node("/root/PhysicsManager"):
		var physics_manager = get_node("/root/PhysicsManager")
		physics_manager.physics_step_completed.connect(_on_physics_step_completed)
	
	print("LODManager: Initialized with auto-optimization %s" % ("enabled" if auto_optimization_enabled else "disabled"))

func _process(delta: float) -> void:
	# Update frame rate tracking
	current_frame_rate = 1.0 / delta
	
	# Track performance samples for optimization
	performance_samples.append(current_frame_rate)
	if performance_samples.size() > 60:  # Keep last 60 samples (1 second at 60fps)
		performance_samples.pop_front()
	
	# Reset per-frame counters
	lod_calculations_per_frame = 0

func _physics_process(delta: float) -> void:
	# Update LOD levels for all registered objects
	_update_lod_levels(delta)
	
	# Check for automatic optimization if enabled
	if auto_optimization_enabled:
		_check_automatic_optimization()

## Register object for LOD management
func register_object(object: Node3D, object_type: ObjectTypes.Type) -> bool:
	"""Register an object for LOD management and optimization.
	
	Args:
		object: Node3D object to register
		object_type: ObjectTypes.Type enum value
		
	Returns:
		true if registration successful
	"""
	if not is_instance_valid(object):
		push_error("LODManager: Cannot register invalid object")
		return false
	
	if not object.has_method("get_object_id"):
		push_error("LODManager: Object must implement get_object_id() method")
		return false
	
	var object_id: int = object.get_object_id()
	if object_id in registered_objects:
		push_warning("LODManager: Object already registered: %d" % object_id)
		return false
	
	# Create LOD data for the object
	var lod_data: LODObjectData = LODObjectData.new(object, object_type)
	registered_objects[object_id] = lod_data
	
	print("LODManager: Registered object %d (type: %s)" % [object_id, ObjectTypes.Type.keys()[object_type]])
	return true

## Unregister object from LOD management
func unregister_object(object: Node3D) -> void:
	"""Unregister an object from LOD management.
	
	Args:
		object: Node3D object to unregister
	"""
	if not is_instance_valid(object) or not object.has_method("get_object_id"):
		return
	
	var object_id: int = object.get_object_id()
	if object_id in registered_objects:
		var lod_data: LODObjectData = registered_objects[object_id]
		if lod_data.is_culled:
			objects_culled_count -= 1
		
		registered_objects.erase(object_id)
		print("LODManager: Unregistered object %d" % object_id)

## Set player position for distance calculations
func set_player_position(position: Vector3) -> void:
	"""Set the current player position for distance-based LOD calculations.
	
	Args:
		position: Player's current world position
	"""
	player_position = position

## Update LOD levels for all registered objects
func _update_lod_levels(delta: float) -> void:
	"""Update LOD levels for all registered objects based on distance and importance."""
	for object_id in registered_objects:
		var lod_data: LODObjectData = registered_objects[object_id]
		
		if not is_instance_valid(lod_data.object):
			# Clean up invalid objects
			registered_objects.erase(object_id)
			continue
		
		# Check if it's time to update this object's LOD
		if Time.get_ticks_msec() / 1000.0 - lod_data.last_update_time < lod_data.update_interval:
			continue
		
		lod_data.last_update_time = Time.get_ticks_msec() / 1000.0
		lod_calculations_per_frame += 1
		
		# Calculate new LOD level
		var new_frequency: UpdateFrequencies.Frequency = _calculate_lod_frequency(lod_data)
		var should_cull: bool = _should_cull_object(lod_data)
		
		# Apply LOD changes
		if should_cull != lod_data.is_culled:
			_apply_culling_state(lod_data, should_cull)
		
		if new_frequency != lod_data.current_frequency and not should_cull:
			_apply_frequency_change(lod_data, new_frequency)

## Calculate LOD frequency based on distance, threat, and importance
func _calculate_lod_frequency(lod_data: LODObjectData) -> UpdateFrequencies.Frequency:
	"""Calculate appropriate update frequency for an object based on multiple factors."""
	var distance: float = lod_data.object.global_position.distance_to(player_position)
	lod_data.last_distance = distance
	
	# Get object importance factors
	var threat_level: int = _get_object_threat_level(lod_data.object)
	var engagement_status: String = _get_object_engagement_status(lod_data.object)
	
	# Player importance radius - always high frequency
	if distance < player_importance_radius:
		return UpdateFrequencies.Frequency.HIGH
	
	# Weapon importance radius - always high frequency for nearby weapons
	if lod_data.object_type == ObjectTypes.Type.WEAPON and distance < weapon_importance_radius:
		return UpdateFrequencies.Frequency.HIGH
	
	# Active combat gets priority regardless of distance (with reasonable limits)
	if engagement_status == "ACTIVE_COMBAT" and distance < medium_distance_threshold * combat_boost_multiplier:
		return UpdateFrequencies.Frequency.HIGH
	
	# Threat level modifiers
	var threat_distance_modifier: float = 1.0
	if threat_level > 5:  # High threat
		threat_distance_modifier = 1.5
	elif threat_level > 3:  # Medium threat
		threat_distance_modifier = 1.2
	
	# Distance-based LOD calculation with threat modifiers
	var effective_near_threshold: float = near_distance_threshold * threat_distance_modifier
	var effective_medium_threshold: float = medium_distance_threshold * threat_distance_modifier
	var effective_far_threshold: float = far_distance_threshold * threat_distance_modifier
	
	if distance < effective_near_threshold:
		return UpdateFrequencies.Frequency.HIGH
	elif distance < effective_medium_threshold:
		return UpdateFrequencies.Frequency.MEDIUM
	elif distance < effective_far_threshold:
		return UpdateFrequencies.Frequency.LOW
	else:
		return UpdateFrequencies.Frequency.MINIMAL

## Check if object should be culled from physics
func _should_cull_object(lod_data: LODObjectData) -> bool:
	"""Determine if an object should be culled from physics simulation."""
	# Never cull the player
	if lod_data.object.has_method("is_player") and lod_data.object.is_player():
		return false
	
	# Never cull objects in active combat
	var engagement_status: String = _get_object_engagement_status(lod_data.object)
	if engagement_status == "ACTIVE_COMBAT":
		return false
	
	# Never cull weapons (they have short lifetimes anyway)
	if lod_data.object_type == ObjectTypes.Type.WEAPON:
		return false
	
	# Cull based on distance
	return lod_data.last_distance > cull_distance_threshold

## Apply culling state change
func _apply_culling_state(lod_data: LODObjectData, should_cull: bool) -> void:
	"""Apply culling state change to an object."""
	if should_cull == lod_data.is_culled:
		return
	
	lod_data.is_culled = should_cull
	
	if should_cull:
		# Disable physics for the object
		if lod_data.object.has_method("set_physics_enabled"):
			lod_data.object.set_physics_enabled(false)
		objects_culled_count += 1
		object_culled.emit(lod_data.object)
	else:
		# Re-enable physics for the object
		if lod_data.object.has_method("set_physics_enabled"):
			lod_data.object.set_physics_enabled(true)
		objects_culled_count -= 1
		object_unculled.emit(lod_data.object)

## Apply frequency change
func _apply_frequency_change(lod_data: LODObjectData, new_frequency: UpdateFrequencies.Frequency) -> void:
	"""Apply update frequency change to an object."""
	var old_frequency: UpdateFrequencies.Frequency = lod_data.current_frequency
	lod_data.current_frequency = new_frequency
	lod_data.update_interval = lod_data._calculate_update_interval(new_frequency)
	
	# Apply frequency to object if it supports it
	if lod_data.object.has_method("set_update_frequency"):
		lod_data.object.set_update_frequency(new_frequency)
	
	lod_level_changed.emit(lod_data.object, new_frequency)

## Get object threat level
func _get_object_threat_level(object: Node3D) -> int:
	"""Get threat level of an object (0-10 scale)."""
	if object.has_method("get_threat_level"):
		return object.get_threat_level()
	
	# Default threat levels based on object type
	if object.has_method("get_object_type"):
		var obj_type = object.get_object_type()
		match obj_type:
			ObjectTypes.Type.WEAPON:
				return 8  # High threat
			ObjectTypes.Type.FIGHTER:
				return 6  # Medium-high threat
			ObjectTypes.Type.CAPITAL:
				return 9  # Very high threat
			ObjectTypes.Type.DEBRIS:
				return 2  # Low threat
			_:
				return 3  # Default medium-low threat
	
	return 3  # Default

## Get object engagement status
func _get_object_engagement_status(object: Node3D) -> String:
	"""Get engagement status of an object."""
	if object.has_method("get_engagement_status"):
		return object.get_engagement_status()
	
	# Default to peaceful if no method available
	return "PEACEFUL"

## Check for automatic optimization triggers
func _check_automatic_optimization() -> void:
	"""Check if automatic optimization should be triggered based on performance."""
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Only check every 2 seconds to avoid thrashing
	if current_time - last_optimization_time < 2.0:
		return
	
	last_optimization_time = current_time
	
	# Calculate average frame rate
	if performance_samples.size() < 30:  # Need enough samples
		return
	
	var avg_frame_rate: float = 0.0
	for sample in performance_samples:
		avg_frame_rate += sample
	avg_frame_rate /= performance_samples.size()
	
	# Check if we're below performance threshold
	var performance_ratio: float = avg_frame_rate / target_frame_rate
	
	if performance_ratio < performance_margin and not optimization_active:
		_trigger_performance_optimization("FRAME_RATE_LOW", {
			"avg_fps": avg_frame_rate,
			"target_fps": target_frame_rate,
			"performance_ratio": performance_ratio
		})
	elif performance_ratio > (performance_margin + 0.1) and optimization_active:
		_restore_normal_performance("FRAME_RATE_RESTORED", {
			"avg_fps": avg_frame_rate,
			"target_fps": target_frame_rate,
			"performance_ratio": performance_ratio
		})

## Trigger performance optimization
func _trigger_performance_optimization(optimization_type: String, details: Dictionary) -> void:
	"""Trigger automatic performance optimization."""
	optimization_active = true
	
	# Reduce LOD thresholds by 25%
	near_distance_threshold *= 0.75
	medium_distance_threshold *= 0.75
	far_distance_threshold *= 0.75
	cull_distance_threshold *= 0.75
	
	print("LODManager: Performance optimization triggered - %s" % optimization_type)
	performance_optimization_triggered.emit(optimization_type, details)

## Restore normal performance settings
func _restore_normal_performance(restoration_type: String, details: Dictionary) -> void:
	"""Restore normal performance settings."""
	optimization_active = false
	
	# Restore original LOD thresholds
	near_distance_threshold = 2000.0
	medium_distance_threshold = 5000.0
	far_distance_threshold = 10000.0
	cull_distance_threshold = 20000.0
	
	print("LODManager: Performance settings restored - %s" % restoration_type)
	performance_optimization_triggered.emit(restoration_type, details)

## Signal handler for physics step completion
func _on_physics_step_completed(delta: float) -> void:
	"""Handle physics step completion signal."""
	# Track physics step timing from PhysicsManager
	if has_node("/root/PhysicsManager"):
		var physics_manager = get_node("/root/PhysicsManager")
		var performance_stats: Dictionary = physics_manager.get_performance_stats()
		physics_step_time_ms = performance_stats.get("physics_step_time_ms", 0.0)
		
		# Check physics step budget
		if physics_step_time_ms > physics_step_budget_ms and not optimization_active:
			_trigger_performance_optimization("PHYSICS_STEP_BUDGET_EXCEEDED", {
				"step_time_ms": physics_step_time_ms,
				"budget_ms": physics_step_budget_ms,
				"objects_registered": registered_objects.size()
			})

## Get LOD manager performance statistics
func get_performance_stats() -> Dictionary:
	"""Get current LOD manager performance statistics.
	
	Returns:
		Dictionary containing performance data
	"""
	var avg_frame_rate: float = 0.0
	if performance_samples.size() > 0:
		for sample in performance_samples:
			avg_frame_rate += sample
		avg_frame_rate /= performance_samples.size()
	
	return {
		"registered_objects": registered_objects.size(),
		"objects_culled": objects_culled_count,
		"lod_calculations_per_frame": lod_calculations_per_frame,
		"average_frame_rate": avg_frame_rate,
		"physics_step_time_ms": physics_step_time_ms,
		"optimization_active": optimization_active,
		"performance_samples_count": performance_samples.size(),
		"near_distance_threshold": near_distance_threshold,
		"medium_distance_threshold": medium_distance_threshold,
		"far_distance_threshold": far_distance_threshold,
		"cull_distance_threshold": cull_distance_threshold
	}

## Force LOD level recalculation for all objects
func force_lod_recalculation() -> void:
	"""Force immediate LOD level recalculation for all registered objects."""
	print("LODManager: Forcing LOD recalculation for %d objects" % registered_objects.size())
	
	for object_id in registered_objects:
		var lod_data: LODObjectData = registered_objects[object_id]
		lod_data.last_update_time = 0.0  # Force immediate update