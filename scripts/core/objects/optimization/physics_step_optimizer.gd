class_name PhysicsStepOptimizer
extends Node

## Physics Step Integration and Performance Optimizer
##
## Manages physics step timing, LOD-based update scheduling, and performance optimization.
## Implements WCS-style fixed timestep with modern optimization techniques for handling
## hundreds of objects while maintaining 60 FPS performance.
##
## Key features:
## - Fixed timestep physics integration (60Hz)
## - Update frequency groups (HIGH/MEDIUM/LOW/MINIMAL)
## - Automatic performance scaling based on frame rate
## - Physics culling for distant objects
## - Smart update scheduling to spread load across frames

# EPIC-002 Asset Core Integration - MANDATORY
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")

signal optimization_level_changed(new_level: int)
signal physics_budget_exceeded(step_time_ms: float, budget_ms: float)
signal update_frequency_adjusted(frequency: UpdateFrequencies.Frequency, object_count: int)

# Performance Configuration
@export_group("Performance Targets")
@export var target_fps: float = 60.0                    # Target frame rate
@export var physics_step_budget_ms: float = 2.0         # Max physics step time budget
@export var max_objects_per_step: int = 50              # Max objects to update per step
@export var performance_check_interval: float = 1.0     # Performance check frequency

@export_group("Update Scheduling")
@export var spread_updates_across_frames: bool = true   # Spread updates across multiple frames
@export var priority_boost_radius: float = 1000.0       # Radius for priority boost around player
@export var emergency_optimization_threshold: float = 0.8  # Frame rate threshold for emergency optimization

# Update Frequency Groups
var update_groups: Dictionary = {
	UpdateFrequencies.Frequency.HIGH_FREQUENCY: [],
	UpdateFrequencies.Frequency.MEDIUM_FREQUENCY: [],
	UpdateFrequencies.Frequency.LOW_FREQUENCY: [],
	UpdateFrequencies.Frequency.MINIMAL_FREQUENCY: []
}

# Update timing and scheduling
var frame_counters: Dictionary = {}                     # Frame counters for each frequency
var update_schedules: Dictionary = {}                   # Scheduled updates for load balancing
var current_optimization_level: int = 0                # 0=normal, 1=light, 2=heavy, 3=emergency

# Performance tracking
var physics_step_times: Array[float] = []              # Recent physics step times
var frame_rate_samples: Array[float] = []              # Recent frame rate samples
var last_performance_check: float = 0.0
var objects_updated_this_frame: int = 0
var total_objects_managed: int = 0

# Player tracking
var player_position: Vector3 = Vector3.ZERO
var camera_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	
	# Initialize frame counters
	for frequency in UpdateFrequencies.Frequency.values():
		frame_counters[frequency] = 0
		update_schedules[frequency] = []
	
	# Connect to physics manager
	if has_node("/root/PhysicsManager"):
		var physics_manager = get_node("/root/PhysicsManager")
		physics_manager.physics_step_completed.connect(_on_physics_step_completed)
	
	print("PhysicsStepOptimizer: Initialized with %d optimization levels" % 4)

func _process(delta: float) -> void:
	# Track frame rate
	var current_fps: float = 1.0 / delta
	frame_rate_samples.append(current_fps)
	if frame_rate_samples.size() > 60:  # Keep 1 second of samples
		frame_rate_samples.pop_front()
	
	# Check performance periodically
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - last_performance_check >= performance_check_interval:
		_check_performance_optimization()
		last_performance_check = current_time

func _physics_process(delta: float) -> void:
	var step_start_time: float = Time.get_ticks_usec()
	objects_updated_this_frame = 0
	
	# Process scheduled updates for this physics step
	_process_scheduled_updates(delta)
	
	# Track physics step timing
	var step_end_time: float = Time.get_ticks_usec()
	var step_time_ms: float = (step_end_time - step_start_time) / 1000.0
	
	physics_step_times.append(step_time_ms)
	if physics_step_times.size() > 120:  # Keep 2 seconds of samples at 60Hz
		physics_step_times.pop_front()
	
	# Check if we exceeded physics budget
	if step_time_ms > physics_step_budget_ms:
		physics_budget_exceeded.emit(step_time_ms, physics_step_budget_ms)

## Register object for optimized physics updates
func register_object(object: Node3D, frequency: UpdateFrequencies.Frequency) -> bool:
	"""Register an object for optimized physics step processing.
	
	Args:
		object: Node3D object to register
		frequency: Initial update frequency
		
	Returns:
		true if registration successful
	"""
	if not is_instance_valid(object):
		push_error("PhysicsStepOptimizer: Cannot register invalid object")
		return false
	
	if not object.has_method("get_object_id"):
		push_error("PhysicsStepOptimizer: Object must implement get_object_id() method")
		return false
	
	# Add to appropriate update group
	if not update_groups[frequency].has(object):
		update_groups[frequency].append(object)
		total_objects_managed += 1
		
		# Schedule initial update
		_schedule_object_update(object, frequency)
		
		print("PhysicsStepOptimizer: Registered object for %s updates" % UpdateFrequencies.frequency_to_string(frequency))
		return true
	
	return false

## Unregister object from optimized physics updates
func unregister_object(object: Node3D) -> void:
	"""Unregister an object from optimized physics processing.
	
	Args:
		object: Node3D object to unregister
	"""
	if not is_instance_valid(object):
		return
	
	# Remove from all update groups
	for frequency in update_groups:
		var group: Array = update_groups[frequency]
		var index: int = group.find(object)
		if index >= 0:
			group.remove_at(index)
			total_objects_managed -= 1
			print("PhysicsStepOptimizer: Unregistered object from %s updates" % UpdateFrequencies.frequency_to_string(frequency))
			return

## Change object update frequency
func set_object_frequency(object: Node3D, new_frequency: UpdateFrequencies.Frequency) -> bool:
	"""Change the update frequency for a registered object.
	
	Args:
		object: Node3D object to modify
		new_frequency: New update frequency
		
	Returns:
		true if frequency changed successfully
	"""
	if not is_instance_valid(object):
		return false
	
	# Find and remove from current group
	var found: bool = false
	for frequency in update_groups:
		var group: Array = update_groups[frequency]
		var index: int = group.find(object)
		if index >= 0:
			group.remove_at(index)
			found = true
			break
	
	if not found:
		push_warning("PhysicsStepOptimizer: Object not found in any update group")
		return false
	
	# Add to new group
	update_groups[new_frequency].append(object)
	_schedule_object_update(object, new_frequency)
	
	update_frequency_adjusted.emit(new_frequency, update_groups[new_frequency].size())
	return true

## Set player position for proximity-based optimization
func set_player_position(position: Vector3) -> void:
	"""Set player position for distance-based optimization.
	
	Args:
		position: Current player world position
	"""
	player_position = position

## Set camera position for view frustum optimization
func set_camera_position(position: Vector3) -> void:
	"""Set camera position for view frustum optimization.
	
	Args:
		position: Current camera world position
	"""
	camera_position = position

## Process scheduled updates for this physics step
func _process_scheduled_updates(delta: float) -> void:
	"""Process all scheduled physics updates for this step."""
	var objects_processed: int = 0
	var max_objects_this_step: int = max_objects_per_step
	
	# Adjust max objects based on optimization level
	match current_optimization_level:
		1:  # Light optimization
			max_objects_this_step = int(max_objects_per_step * 0.8)
		2:  # Heavy optimization
			max_objects_this_step = int(max_objects_per_step * 0.6)
		3:  # Emergency optimization
			max_objects_this_step = int(max_objects_per_step * 0.4)
	
	# Process HIGH frequency objects every frame
	objects_processed += _process_frequency_group(UpdateFrequencies.Frequency.HIGH_FREQUENCY, delta, max_objects_this_step)
	
	# Process other frequencies based on their schedules
	if objects_processed < max_objects_this_step:
		objects_processed += _process_frequency_group(UpdateFrequencies.Frequency.MEDIUM_FREQUENCY, delta, max_objects_this_step - objects_processed)
	
	if objects_processed < max_objects_this_step:
		objects_processed += _process_frequency_group(UpdateFrequencies.Frequency.LOW_FREQUENCY, delta, max_objects_this_step - objects_processed)
	
	if objects_processed < max_objects_this_step:
		objects_processed += _process_frequency_group(UpdateFrequencies.Frequency.MINIMAL_FREQUENCY, delta, max_objects_this_step - objects_processed)
	
	objects_updated_this_frame = objects_processed

## Process a specific frequency group
func _process_frequency_group(frequency: UpdateFrequencies.Frequency, delta: float, max_objects: int) -> int:
	"""Process objects in a specific frequency group.
	
	Args:
		frequency: Update frequency to process
		delta: Physics timestep
		max_objects: Maximum objects to process
		
	Returns:
		Number of objects actually processed
	"""
	var group: Array = update_groups[frequency]
	if group.is_empty():
		return 0
	
	var objects_processed: int = 0
	var update_interval: int = _get_update_interval_frames(frequency)
	
	# Increment frame counter for this frequency
	frame_counters[frequency] += 1
	
	# Check if it's time to update this frequency group
	if frame_counters[frequency] % update_interval != 0:
		return 0  # Not time to update this frequency yet
	
	# Process objects in this group
	for i in range(min(group.size(), max_objects)):
		var object: Node3D = group[i]
		
		if not is_instance_valid(object):
			# Clean up invalid objects
			group.remove_at(i)
			total_objects_managed -= 1
			continue
		
		# Apply priority boost for objects near player
		var should_boost: bool = _should_boost_priority(object)
		if should_boost and frequency != UpdateFrequencies.Frequency.HIGH_FREQUENCY:
			# Temporarily boost to high frequency
			_process_object_physics(object, delta, true)
		else:
			_process_object_physics(object, delta, false)
		
		objects_processed += 1
		
		# Check if we've reached the object limit for this step
		if objects_processed >= max_objects:
			break
	
	return objects_processed

## Process physics for a single object
func _process_object_physics(object: Node3D, delta: float, is_boosted: bool) -> void:
	"""Process physics update for a single object.
	
	Args:
		object: Object to update
		delta: Physics timestep
		is_boosted: Whether this is a priority-boosted update
	"""
	# Let the object handle its physics update
	if object.has_method("physics_update"):
		object.physics_update(delta)
	elif object.has_method("_physics_process"):
		# Fallback to standard physics process
		object._physics_process(delta)
	
	# Apply WCS-style physics if the object supports it
	if object.has_method("apply_wcs_physics"):
		object.apply_wcs_physics(delta)

## Get update interval in frames for a frequency
func _get_update_interval_frames(frequency: UpdateFrequencies.Frequency) -> int:
	"""Get update interval in frames for a given frequency."""
	match frequency:
		UpdateFrequencies.Frequency.HIGH_FREQUENCY:
			return 1   # Every frame (60Hz)
		UpdateFrequencies.Frequency.MEDIUM_FREQUENCY:
			return 2   # Every 2 frames (30Hz)
		UpdateFrequencies.Frequency.LOW_FREQUENCY:
			return 4   # Every 4 frames (15Hz)
		UpdateFrequencies.Frequency.MINIMAL_FREQUENCY:
			return 12  # Every 12 frames (5Hz)
		_:
			return 1

## Check if object should get priority boost
func _should_boost_priority(object: Node3D) -> bool:
	"""Check if object should receive priority boost based on proximity."""
	var distance_to_player: float = object.global_position.distance_to(player_position)
	return distance_to_player < priority_boost_radius

## Schedule object update for load balancing
func _schedule_object_update(object: Node3D, frequency: UpdateFrequencies.Frequency) -> void:
	"""Schedule an object update to balance load across frames."""
	if not spread_updates_across_frames:
		return  # No scheduling needed
	
	var schedule: Array = update_schedules[frequency]
	var update_interval: int = _get_update_interval_frames(frequency)
	
	# Distribute objects across frames for this frequency
	var target_frame: int = schedule.size() % update_interval
	
	# Add to schedule (simplified scheduling for now)
	schedule.append({
		"object": object,
		"target_frame": target_frame
	})

## Check performance and adjust optimization level
func _check_performance_optimization() -> void:
	"""Check current performance and adjust optimization level accordingly."""
	if frame_rate_samples.size() < 30:  # Need enough samples
		return
	
	# Calculate average frame rate
	var avg_fps: float = 0.0
	for sample in frame_rate_samples:
		avg_fps += sample
	avg_fps /= frame_rate_samples.size()
	
	# Calculate average physics step time
	var avg_step_time: float = 0.0
	if physics_step_times.size() > 0:
		for step_time in physics_step_times:
			avg_step_time += step_time
		avg_step_time /= physics_step_times.size()
	
	# Determine optimization level
	var new_optimization_level: int = 0
	var performance_ratio: float = avg_fps / target_fps
	
	if performance_ratio < emergency_optimization_threshold:
		new_optimization_level = 3  # Emergency
	elif performance_ratio < 0.85:
		new_optimization_level = 2  # Heavy
	elif performance_ratio < 0.9:
		new_optimization_level = 1  # Light
	else:
		new_optimization_level = 0  # Normal
	
	# Apply optimization level change
	if new_optimization_level != current_optimization_level:
		_apply_optimization_level(new_optimization_level)

## Apply optimization level changes
func _apply_optimization_level(new_level: int) -> void:
	"""Apply performance optimization level changes.
	
	Args:
		new_level: New optimization level (0-3)
	"""
	var old_level: int = current_optimization_level
	current_optimization_level = new_level
	
	match new_level:
		0:  # Normal performance
			max_objects_per_step = 50
			print("PhysicsStepOptimizer: Normal performance mode")
		1:  # Light optimization
			max_objects_per_step = 40
			print("PhysicsStepOptimizer: Light optimization mode")
		2:  # Heavy optimization
			max_objects_per_step = 30
			print("PhysicsStepOptimizer: Heavy optimization mode")
		3:  # Emergency optimization
			max_objects_per_step = 20
			print("PhysicsStepOptimizer: Emergency optimization mode")
	
	optimization_level_changed.emit(new_level)

## Signal handler for physics step completion
func _on_physics_step_completed(delta: float) -> void:
	"""Handle physics step completion from PhysicsManager."""
	# Physics step timing is already tracked in _physics_process
	pass

## Get performance statistics
func get_performance_stats() -> Dictionary:
	"""Get current performance statistics.
	
	Returns:
		Dictionary containing performance data
	"""
	var avg_fps: float = 0.0
	if frame_rate_samples.size() > 0:
		for sample in frame_rate_samples:
			avg_fps += sample
		avg_fps /= frame_rate_samples.size()
	
	var avg_step_time: float = 0.0
	if physics_step_times.size() > 0:
		for step_time in physics_step_times:
			avg_step_time += step_time
		avg_step_time /= physics_step_times.size()
	
	return {
		"total_objects_managed": total_objects_managed,
		"objects_updated_this_frame": objects_updated_this_frame,
		"optimization_level": current_optimization_level,
		"average_fps": avg_fps,
		"average_step_time_ms": avg_step_time,
		"physics_budget_ms": physics_step_budget_ms,
		"max_objects_per_step": max_objects_per_step,
		"update_group_sizes": {
			"HIGH": update_groups[UpdateFrequencies.Frequency.HIGH_FREQUENCY].size(),
			"MEDIUM": update_groups[UpdateFrequencies.Frequency.MEDIUM_FREQUENCY].size(),
			"LOW": update_groups[UpdateFrequencies.Frequency.LOW_FREQUENCY].size(),
			"MINIMAL": update_groups[UpdateFrequencies.Frequency.MINIMAL_FREQUENCY].size()
		}
	}