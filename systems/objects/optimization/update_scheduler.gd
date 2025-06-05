class_name UpdateScheduler
extends Node

## Staggered update scheduling system for physics step integration and performance optimization.
## Manages update timing across different frequency groups to maintain stable 60 FPS performance.
## 
## This system implements OBJ-007 requirements for staggered update scheduling to distribute
## physics computation load across frames for optimal performance.

signal scheduler_cycle_completed(cycle_stats: Dictionary)
signal frequency_group_updated(frequency: UpdateFrequencies.Frequency, object_count: int, update_time_ms: float)
signal performance_warning(message: String, severity: String)

# EPIC-002 Asset Core Integration
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")
const UpdateFrequency = UpdateFrequencies.Frequency

# Configuration
@export var enable_staggered_updates: bool = true
@export var max_updates_per_frame: int = 50  # Maximum objects to update per frame
@export var update_time_budget_ms: float = 3.0  # Maximum time to spend on updates per frame
@export var adaptive_scheduling: bool = true  # Adjust scheduling based on performance

# Update frequency groups
var critical_frequency_objects: Array[Node3D] = []
var high_frequency_objects: Array[Node3D] = []
var medium_frequency_objects: Array[Node3D] = []
var low_frequency_objects: Array[Node3D] = []
var minimal_frequency_objects: Array[Node3D] = []

# Staggered update indices for round-robin scheduling
var critical_update_index: int = 0
var high_update_index: int = 0
var medium_update_index: int = 0
var low_update_index: int = 0
var minimal_update_index: int = 0

# Update timing control
var critical_timer: float = 0.0
var high_timer: float = 0.0
var medium_timer: float = 0.0
var low_timer: float = 0.0
var minimal_timer: float = 0.0

# Update intervals from frequency constants
var critical_interval: float
var high_interval: float
var medium_interval: float
var low_interval: float
var minimal_interval: float

# Performance tracking
var updates_processed_this_frame: int = 0
var total_update_time_this_frame: float = 0.0
var frame_update_budget_exceeded: bool = false

# Adaptive scheduling state
var recent_frame_times: Array[float] = []
var average_frame_time: float = 16.67  # Target 60 FPS
var performance_factor: float = 1.0

# State management
var is_initialized: bool = false
var is_enabled: bool = true

class UpdateTask:
	var object: Node3D
	var update_function: String
	var priority: int
	var last_update_time: float
	var estimated_time_ms: float
	
	func _init(obj: Node3D, func_name: String, prio: int = 0) -> void:
		object = obj
		update_function = func_name
		priority = prio
		last_update_time = 0.0
		estimated_time_ms = 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_scheduler()

func _initialize_scheduler() -> void:
	"""Initialize the update scheduler system."""
	if is_initialized:
		push_warning("UpdateScheduler: Already initialized")
		return
	
	print("UpdateScheduler: Starting initialization...")
	
	# Calculate update intervals from frequency constants
	critical_interval = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.CRITICAL] / 1000.0
	high_interval = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.HIGH] / 1000.0
	medium_interval = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.MEDIUM] / 1000.0
	low_interval = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.LOW] / 1000.0
	minimal_interval = UpdateFrequencies.UPDATE_FREQUENCY_MS[UpdateFrequency.MINIMAL] / 1000.0
	
	# Initialize arrays
	critical_frequency_objects.clear()
	high_frequency_objects.clear()
	medium_frequency_objects.clear()
	low_frequency_objects.clear()
	minimal_frequency_objects.clear()
	
	# Reset indices
	critical_update_index = 0
	high_update_index = 0
	medium_update_index = 0
	low_update_index = 0
	minimal_update_index = 0
	
	is_initialized = true
	print("UpdateScheduler: Initialization complete")

func _process(delta: float) -> void:
	if not is_initialized or not is_enabled:
		return
	
	# Reset per-frame counters
	updates_processed_this_frame = 0
	total_update_time_this_frame = 0.0
	frame_update_budget_exceeded = false
	
	# Update performance tracking
	_update_performance_monitoring(delta)
	
	# Update timers
	_update_timers(delta)
	
	# Process staggered updates if enabled
	if enable_staggered_updates:
		_process_staggered_updates()
	else:
		_process_all_updates()
	
	# Check for performance warnings
	_check_performance_warnings()

func _update_performance_monitoring(delta: float) -> void:
	"""Update performance monitoring for adaptive scheduling."""
	recent_frame_times.append(delta * 1000.0)  # Convert to milliseconds
	
	# Keep only recent samples
	if recent_frame_times.size() > 60:  # Track last 60 frames
		recent_frame_times.pop_front()
	
	# Calculate average frame time
	var total_time: float = 0.0
	for frame_time in recent_frame_times:
		total_time += frame_time
	
	average_frame_time = total_time / max(recent_frame_times.size(), 1)
	
	# Calculate performance factor for adaptive scheduling
	if adaptive_scheduling:
		performance_factor = UpdateFrequencies.calculate_performance_factor(average_frame_time)

func _update_timers(delta: float) -> void:
	"""Update all frequency timers."""
	critical_timer += delta
	high_timer += delta
	medium_timer += delta
	low_timer += delta
	minimal_timer += delta

func _process_staggered_updates() -> void:
	"""Process staggered updates with time budgeting."""
	var update_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Process critical frequency updates (highest priority)
	if critical_timer >= critical_interval:
		_process_frequency_group_staggered(
			critical_frequency_objects, 
			UpdateFrequency.CRITICAL, 
			critical_update_index
		)
		critical_timer = 0.0
		critical_update_index = 0  # Reset for next cycle
	
	# Check time budget before continuing
	if _is_time_budget_exceeded(update_start_time):
		return
	
	# Process high frequency updates
	if high_timer >= high_interval:
		_process_frequency_group_staggered(
			high_frequency_objects, 
			UpdateFrequency.HIGH, 
			high_update_index
		)
		high_timer = 0.0
		high_update_index = 0
	
	if _is_time_budget_exceeded(update_start_time):
		return
	
	# Process medium frequency updates
	if medium_timer >= medium_interval:
		_process_frequency_group_staggered(
			medium_frequency_objects, 
			UpdateFrequency.MEDIUM, 
			medium_update_index
		)
		medium_timer = 0.0
		medium_update_index = 0
	
	if _is_time_budget_exceeded(update_start_time):
		return
	
	# Process low frequency updates
	if low_timer >= low_interval:
		_process_frequency_group_staggered(
			low_frequency_objects, 
			UpdateFrequency.LOW, 
			low_update_index
		)
		low_timer = 0.0
		low_update_index = 0
	
	if _is_time_budget_exceeded(update_start_time):
		return
	
	# Process minimal frequency updates
	if minimal_timer >= minimal_interval:
		_process_frequency_group_staggered(
			minimal_frequency_objects, 
			UpdateFrequency.MINIMAL, 
			minimal_update_index
		)
		minimal_timer = 0.0
		minimal_update_index = 0
	
	# Record total update time
	total_update_time_this_frame = (Time.get_ticks_usec() / 1000.0) - update_start_time

func _process_frequency_group_staggered(objects: Array[Node3D], frequency: UpdateFrequency, start_index: int) -> void:
	"""Process a frequency group with staggered updates."""
	if objects.is_empty():
		return
	
	var group_start_time: float = Time.get_ticks_usec() / 1000.0
	var objects_updated: int = 0
	var max_updates_this_group: int = max_updates_per_frame / 5  # Distribute across 5 frequency groups
	
	# Adjust max updates based on performance factor
	if adaptive_scheduling:
		max_updates_this_group = int(max_updates_this_group / performance_factor)
	
	# Process objects in round-robin fashion
	var current_index: int = start_index
	var objects_processed: int = 0
	
	while objects_processed < objects.size() and objects_updated < max_updates_this_group:
		if current_index >= objects.size():
			break
		
		var object: Node3D = objects[current_index]
		
		if is_instance_valid(object):
			_update_object(object, frequency)
			objects_updated += 1
			updates_processed_this_frame += 1
		else:
			# Remove invalid objects
			objects.remove_at(current_index)
			current_index -= 1
		
		current_index += 1
		objects_processed += 1
		
		# Check time budget
		if _is_time_budget_exceeded_for_group(group_start_time):
			break
	
	var group_update_time: float = (Time.get_ticks_usec() / 1000.0) - group_start_time
	frequency_group_updated.emit(frequency, objects_updated, group_update_time)

func _process_all_updates() -> void:
	"""Process all updates without staggering (fallback mode)."""
	var update_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Process all frequency groups in order
	if critical_timer >= critical_interval:
		_process_frequency_group_all(critical_frequency_objects, UpdateFrequency.CRITICAL)
		critical_timer = 0.0
	
	if high_timer >= high_interval:
		_process_frequency_group_all(high_frequency_objects, UpdateFrequency.HIGH)
		high_timer = 0.0
	
	if medium_timer >= medium_interval:
		_process_frequency_group_all(medium_frequency_objects, UpdateFrequency.MEDIUM)
		medium_timer = 0.0
	
	if low_timer >= low_interval:
		_process_frequency_group_all(low_frequency_objects, UpdateFrequency.LOW)
		low_timer = 0.0
	
	if minimal_timer >= minimal_interval:
		_process_frequency_group_all(minimal_frequency_objects, UpdateFrequency.MINIMAL)
		minimal_timer = 0.0
	
	total_update_time_this_frame = (Time.get_ticks_usec() / 1000.0) - update_start_time

func _process_frequency_group_all(objects: Array[Node3D], frequency: UpdateFrequency) -> void:
	"""Process all objects in a frequency group immediately."""
	var group_start_time: float = Time.get_ticks_usec() / 1000.0
	var objects_updated: int = 0
	
	for object in objects:
		if is_instance_valid(object):
			_update_object(object, frequency)
			objects_updated += 1
			updates_processed_this_frame += 1
	
	var group_update_time: float = (Time.get_ticks_usec() / 1000.0) - group_start_time
	frequency_group_updated.emit(frequency, objects_updated, group_update_time)

func _update_object(object: Node3D, frequency: UpdateFrequency) -> void:
	"""Update a single object at the specified frequency."""
	var delta: float = _get_frequency_delta(frequency)
	
	# Call the object's physics step function if it exists
	if object.has_method("_physics_step"):
		object._physics_step(delta)
	elif object.has_method("_scheduled_update"):
		object._scheduled_update(delta, frequency)
	elif object.has_method("_process_physics"):
		object._process_physics(delta)

func _get_frequency_delta(frequency: UpdateFrequency) -> float:
	"""Get the delta time for a specific update frequency."""
	match frequency:
		UpdateFrequency.CRITICAL:
			return critical_interval
		UpdateFrequency.HIGH:
			return high_interval
		UpdateFrequency.MEDIUM:
			return medium_interval
		UpdateFrequency.LOW:
			return low_interval
		UpdateFrequency.MINIMAL:
			return minimal_interval
		_:
			return critical_interval

func _is_time_budget_exceeded(start_time: float) -> bool:
	"""Check if the update time budget has been exceeded."""
	var elapsed_time: float = (Time.get_ticks_usec() / 1000.0) - start_time
	
	if elapsed_time > update_time_budget_ms:
		frame_update_budget_exceeded = true
		return true
	
	return false

func _is_time_budget_exceeded_for_group(group_start_time: float) -> bool:
	"""Check if time budget is exceeded for the current group (more lenient)."""
	var elapsed_time: float = (Time.get_ticks_usec() / 1000.0) - group_start_time
	
	# Allow groups to use up to 1/5 of the total budget
	return elapsed_time > (update_time_budget_ms / 5.0)

func _check_performance_warnings() -> void:
	"""Check for performance issues and emit warnings."""
	if frame_update_budget_exceeded:
		performance_warning.emit(
			"Update time budget exceeded: %.2fms > %.2fms" % [total_update_time_this_frame, update_time_budget_ms],
			"warning"
		)
	
	if updates_processed_this_frame > max_updates_per_frame:
		performance_warning.emit(
			"Update count exceeded: %d > %d" % [updates_processed_this_frame, max_updates_per_frame],
			"warning"
		)
	
	if average_frame_time > UpdateFrequencies.PERFORMANCE_THRESHOLDS["frame_time_warning_ms"]:
		performance_warning.emit(
			"Frame time warning: %.2fms > %.2fms" % [average_frame_time, UpdateFrequencies.PERFORMANCE_THRESHOLDS["frame_time_warning_ms"]],
			"warning"
		)

# Public API for object management

func register_object(object: Node3D, frequency: UpdateFrequency) -> bool:
	"""Register an object for scheduled updates.
	
	Args:
		object: Node3D object to schedule
		frequency: Update frequency level
		
	Returns:
		true if registration successful
	"""
	if not is_instance_valid(object):
		push_error("UpdateScheduler: Cannot register invalid object")
		return false
	
	# Remove from any existing frequency group
	unregister_object(object)
	
	# Add to appropriate frequency group
	match frequency:
		UpdateFrequency.CRITICAL:
			critical_frequency_objects.append(object)
		UpdateFrequency.HIGH:
			high_frequency_objects.append(object)
		UpdateFrequency.MEDIUM:
			medium_frequency_objects.append(object)
		UpdateFrequency.LOW:
			low_frequency_objects.append(object)
		UpdateFrequency.MINIMAL:
			minimal_frequency_objects.append(object)
		_:
			push_error("UpdateScheduler: Invalid frequency level")
			return false
	
	print("UpdateScheduler: Registered object for %s frequency updates" % UpdateFrequencies.get_frequency_name(frequency))
	return true

func unregister_object(object: Node3D) -> void:
	"""Unregister an object from scheduled updates.
	
	Args:
		object: Node3D object to unregister
	"""
	# Remove from all frequency groups
	critical_frequency_objects.erase(object)
	high_frequency_objects.erase(object)
	medium_frequency_objects.erase(object)
	low_frequency_objects.erase(object)
	minimal_frequency_objects.erase(object)

func change_object_frequency(object: Node3D, new_frequency: UpdateFrequency) -> bool:
	"""Change the update frequency of a registered object.
	
	Args:
		object: Node3D object to update
		new_frequency: New update frequency
		
	Returns:
		true if frequency changed successfully
	"""
	if not is_instance_valid(object):
		return false
	
	return register_object(object, new_frequency)

func get_object_frequency(object: Node3D) -> UpdateFrequency:
	"""Get the current update frequency of an object.
	
	Args:
		object: Node3D object to query
		
	Returns:
		Current update frequency, or CRITICAL if not found
	"""
	if critical_frequency_objects.has(object):
		return UpdateFrequency.CRITICAL
	elif high_frequency_objects.has(object):
		return UpdateFrequency.HIGH
	elif medium_frequency_objects.has(object):
		return UpdateFrequency.MEDIUM
	elif low_frequency_objects.has(object):
		return UpdateFrequency.LOW
	elif minimal_frequency_objects.has(object):
		return UpdateFrequency.MINIMAL
	else:
		return UpdateFrequency.CRITICAL

func is_object_registered(object: Node3D) -> bool:
	"""Check if an object is registered for scheduled updates.
	
	Args:
		object: Node3D object to check
		
	Returns:
		true if object is registered
	"""
	return (critical_frequency_objects.has(object) or
			high_frequency_objects.has(object) or
			medium_frequency_objects.has(object) or
			low_frequency_objects.has(object) or
			minimal_frequency_objects.has(object))

func get_frequency_group_counts() -> Dictionary:
	"""Get the object count for each frequency group.
	
	Returns:
		Dictionary with frequency counts
	"""
	return {
		"critical": critical_frequency_objects.size(),
		"high": high_frequency_objects.size(),
		"medium": medium_frequency_objects.size(),
		"low": low_frequency_objects.size(),
		"minimal": minimal_frequency_objects.size(),
		"total": get_total_object_count()
	}

func get_total_object_count() -> int:
	"""Get the total number of registered objects.
	
	Returns:
		Total object count
	"""
	return (critical_frequency_objects.size() +
			high_frequency_objects.size() +
			medium_frequency_objects.size() +
			low_frequency_objects.size() +
			minimal_frequency_objects.size())

func get_scheduler_stats() -> Dictionary:
	"""Get current scheduler statistics.
	
	Returns:
		Dictionary containing scheduler metrics
	"""
	return {
		"total_objects": get_total_object_count(),
		"frequency_groups": get_frequency_group_counts(),
		"updates_this_frame": updates_processed_this_frame,
		"update_time_ms": total_update_time_this_frame,
		"time_budget_ms": update_time_budget_ms,
		"budget_exceeded": frame_update_budget_exceeded,
		"average_frame_time_ms": average_frame_time,
		"performance_factor": performance_factor,
		"staggered_updates_enabled": enable_staggered_updates,
		"adaptive_scheduling_enabled": adaptive_scheduling
	}

func set_enabled(enabled: bool) -> void:
	"""Enable or disable the update scheduler.
	
	Args:
		enabled: true to enable scheduling
	"""
	is_enabled = enabled
	print("UpdateScheduler: %s" % ("enabled" if enabled else "disabled"))

func is_scheduler_enabled() -> bool:
	"""Check if the scheduler is enabled.
	
	Returns:
		true if scheduler is enabled
	"""
	return is_enabled

func set_time_budget(budget_ms: float) -> void:
	"""Set the per-frame time budget for updates.
	
	Args:
		budget_ms: Time budget in milliseconds
	"""
	update_time_budget_ms = max(0.1, budget_ms)
	print("UpdateScheduler: Set time budget to %.2fms" % update_time_budget_ms)

func set_max_updates_per_frame(max_updates: int) -> void:
	"""Set the maximum number of updates per frame.
	
	Args:
		max_updates: Maximum updates per frame
	"""
	max_updates_per_frame = max(1, max_updates)
	print("UpdateScheduler: Set max updates per frame to %d" % max_updates_per_frame)

# Debug functions

func debug_print_scheduler_stats() -> void:
	"""Print current scheduler statistics for debugging."""
	var stats: Dictionary = get_scheduler_stats()
	
	print("=== Update Scheduler Statistics ===")
	print("Total objects: %d" % stats.get("total_objects", 0))
	print("Critical frequency: %d" % stats["frequency_groups"]["critical"])
	print("High frequency: %d" % stats["frequency_groups"]["high"])
	print("Medium frequency: %d" % stats["frequency_groups"]["medium"])
	print("Low frequency: %d" % stats["frequency_groups"]["low"])
	print("Minimal frequency: %d" % stats["frequency_groups"]["minimal"])
	print("Updates this frame: %d" % stats.get("updates_this_frame", 0))
	print("Update time: %.2fms / %.2fms" % [stats.get("update_time_ms", 0.0), stats.get("time_budget_ms", 0.0)])
	print("Budget exceeded: %s" % stats.get("budget_exceeded", false))
	print("Average frame time: %.2fms" % stats.get("average_frame_time_ms", 0.0))
	print("Performance factor: %.2f" % stats.get("performance_factor", 1.0))
	print("Staggered updates: %s" % ("enabled" if stats.get("staggered_updates_enabled", false) else "disabled"))
	print("Adaptive scheduling: %s" % ("enabled" if stats.get("adaptive_scheduling_enabled", false) else "disabled"))
	print("===================================")

func force_update_all() -> void:
	"""Force an immediate update of all registered objects (for testing)."""
	_process_all_updates()
	print("UpdateScheduler: Forced update of all objects completed")