class_name HUDUpdateScheduler
extends Node

## EPIC-012 HUD-003: Update scheduling and optimization system
## Manages temporal distribution of HUD element updates for optimal performance

signal update_scheduled(element_id: String, next_update_time: float)
signal update_completed(element_id: String, execution_time_ms: float)
signal frame_budget_exceeded(total_time_ms: float, budget_ms: float)

# Update scheduling configuration
@export var frame_budget_ms: float = 2.0              # Total HUD update budget per frame
@export var element_budget_ms: float = 0.1            # Individual element budget per frame
@export var max_updates_per_frame: int = 20           # Maximum element updates per frame
@export var scheduler_enabled: bool = true            # Enable/disable scheduling

# Element update tracking
var element_update_frequencies: Dictionary = {}       # element_id -> frequency (Hz)
var element_last_update_times: Dictionary = {}        # element_id -> last update timestamp
var element_next_update_times: Dictionary = {}        # element_id -> next scheduled update time
var element_update_priorities: Dictionary = {}        # element_id -> priority value
var element_update_callbacks: Dictionary = {}         # element_id -> Callable for update

# Performance tracking
var frame_update_time_ms: float = 0.0
var total_updates_this_frame: int = 0
var frame_updates_skipped: int = 0
var average_frame_time_ms: float = 0.0
var frame_time_samples: Array[float] = []
var max_frame_time_samples: int = 60

# Dirty state tracking
var dirty_elements: Dictionary = {}                   # element_id -> dirty flag
var dirty_timestamp: Dictionary = {}                  # element_id -> time when marked dirty
var dirty_reasons: Dictionary = {}                    # element_id -> reason for dirty state

# Update distribution
var update_queue: Array[Dictionary] = []              # Sorted queue of pending updates
var high_priority_queue: Array[Dictionary] = []       # Queue for high-priority updates
var deferred_updates: Array[Dictionary] = []          # Updates deferred to next frame

# Statistics
var total_updates_scheduled: int = 0
var total_updates_completed: int = 0
var total_updates_skipped: int = 0
var performance_optimizations: int = 0

func _ready() -> void:
	print("HUDUpdateScheduler: Initializing update scheduling system")
	_initialize_scheduler()

func _initialize_scheduler() -> void:
	# Set up frame processing
	set_process(true)
	
	# Initialize timing
	frame_time_samples.resize(max_frame_time_samples)
	frame_time_samples.fill(0.0)
	
	print("HUDUpdateScheduler: Scheduler initialized with %.1fms frame budget" % frame_budget_ms)

func _process(delta: float) -> void:
	if not scheduler_enabled:
		return
	
	var frame_start_time = Time.get_ticks_usec()
	
	# Reset frame counters
	total_updates_this_frame = 0
	frame_updates_skipped = 0
	
	# Process scheduled updates
	_process_update_queue()
	
	# Track frame performance
	var frame_end_time = Time.get_ticks_usec()
	frame_update_time_ms = (frame_end_time - frame_start_time) / 1000.0
	
	_update_performance_statistics()
	
	# Check frame budget
	if frame_update_time_ms > frame_budget_ms:
		frame_budget_exceeded.emit(frame_update_time_ms, frame_budget_ms)

## Register an element for scheduled updates
func register_element(element_id: String, update_frequency: float, update_callback: Callable, priority: int = 50) -> void:
	element_update_frequencies[element_id] = update_frequency
	element_update_callbacks[element_id] = update_callback
	element_update_priorities[element_id] = priority
	
	var current_time = Time.get_ticks_usec() / 1000000.0
	element_last_update_times[element_id] = current_time
	element_next_update_times[element_id] = current_time + (1.0 / update_frequency)
	
	print("HUDUpdateScheduler: Registered element %s (%.1f Hz, priority %d)" % [element_id, update_frequency, priority])

## Unregister an element from scheduled updates
func unregister_element(element_id: String) -> void:
	element_update_frequencies.erase(element_id)
	element_update_callbacks.erase(element_id)
	element_update_priorities.erase(element_id)
	element_last_update_times.erase(element_id)
	element_next_update_times.erase(element_id)
	dirty_elements.erase(element_id)
	dirty_timestamp.erase(element_id)
	dirty_reasons.erase(element_id)
	
	print("HUDUpdateScheduler: Unregistered element %s" % element_id)

## Mark an element as dirty (needs update)
func mark_dirty(element_id: String, reason: String = "data_changed") -> void:
	if not element_update_callbacks.has(element_id):
		return
	
	dirty_elements[element_id] = true
	dirty_timestamp[element_id] = Time.get_ticks_usec() / 1000000.0
	dirty_reasons[element_id] = reason
	
	# Schedule immediate update for critical elements
	var priority = element_update_priorities.get(element_id, 50)
	if priority >= 90:  # High priority threshold
		_schedule_immediate_update(element_id)

## Check if an element is dirty
func is_dirty(element_id: String) -> bool:
	return dirty_elements.get(element_id, false)

## Clear dirty state for an element
func clear_dirty(element_id: String) -> void:
	dirty_elements[element_id] = false
	dirty_timestamp.erase(element_id)
	dirty_reasons.erase(element_id)

## Set update frequency for an element
func set_element_frequency(element_id: String, frequency: float) -> void:
	if not element_update_frequencies.has(element_id):
		return
	
	element_update_frequencies[element_id] = frequency
	
	# Recalculate next update time
	var current_time = Time.get_ticks_usec() / 1000000.0
	element_next_update_times[element_id] = current_time + (1.0 / frequency)
	
	print("HUDUpdateScheduler: Updated frequency for %s to %.1f Hz" % [element_id, frequency])

## Force immediate update for an element
func force_immediate_update(element_id: String) -> void:
	if not element_update_callbacks.has(element_id):
		return
	
	_execute_element_update(element_id)

## Process the update queue for this frame
func _process_update_queue() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Build list of elements due for update
	var pending_updates: Array[Dictionary] = []
	
	for element_id in element_update_frequencies.keys():
		var next_update_time = element_next_update_times.get(element_id, 0.0)
		var priority = element_update_priorities.get(element_id, 50)
		var is_dirty = dirty_elements.get(element_id, false)
		
		# Determine if update is needed
		var needs_update = false
		var update_reason = ""
		
		if current_time >= next_update_time:
			needs_update = true
			update_reason = "scheduled"
		elif is_dirty:
			needs_update = true
			update_reason = dirty_reasons.get(element_id, "dirty")
		
		if needs_update:
			pending_updates.append({
				"element_id": element_id,
				"priority": priority,
				"reason": update_reason,
				"scheduled_time": next_update_time
			})
	
	# Sort by priority (highest first)
	pending_updates.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Process updates within frame budget
	var frame_time_used = 0.0
	
	for update_info in pending_updates:
		# Check frame budget constraints
		if total_updates_this_frame >= max_updates_per_frame:
			frame_updates_skipped += 1
			continue
		
		if frame_time_used >= frame_budget_ms:
			frame_updates_skipped += 1
			continue
		
		# Execute the update
		var element_id = update_info.element_id
		var update_start_time = Time.get_ticks_usec()
		
		_execute_element_update(element_id)
		
		var update_end_time = Time.get_ticks_usec()
		var update_time_ms = (update_end_time - update_start_time) / 1000.0
		
		frame_time_used += update_time_ms
		total_updates_this_frame += 1
		
		# Check individual element budget
		if update_time_ms > element_budget_ms:
			push_warning("HUDUpdateScheduler: Element %s exceeded budget (%.3fms > %.3fms)" % [element_id, update_time_ms, element_budget_ms])
			performance_optimizations += 1
			
			# Reduce update frequency for slow elements
			_reduce_element_frequency(element_id)
		
		update_completed.emit(element_id, update_time_ms)

## Execute an update for a specific element
func _execute_element_update(element_id: String) -> void:
	var callback = element_update_callbacks.get(element_id)
	if not callback or not callback.is_valid():
		return
	
	# Call the update function
	callback.call()
	
	# Update timing information
	var current_time = Time.get_ticks_usec() / 1000000.0
	element_last_update_times[element_id] = current_time
	
	# Calculate next update time
	var frequency = element_update_frequencies.get(element_id, 30.0)
	element_next_update_times[element_id] = current_time + (1.0 / frequency)
	
	# Clear dirty state
	clear_dirty(element_id)
	
	# Update statistics
	total_updates_completed += 1

## Schedule an immediate high-priority update
func _schedule_immediate_update(element_id: String) -> void:
	high_priority_queue.append({
		"element_id": element_id,
		"priority": element_update_priorities.get(element_id, 50),
		"reason": "immediate"
	})

## Reduce update frequency for elements that exceed their budget
func _reduce_element_frequency(element_id: String) -> void:
	var current_frequency = element_update_frequencies.get(element_id, 30.0)
	var new_frequency = max(5.0, current_frequency * 0.75)  # Reduce by 25%, minimum 5 Hz
	
	set_element_frequency(element_id, new_frequency)
	print("HUDUpdateScheduler: Reduced frequency for %s to %.1f Hz due to performance" % [element_id, new_frequency])

## Update performance statistics
func _update_performance_statistics() -> void:
	# Update frame time samples for moving average
	frame_time_samples.push_back(frame_update_time_ms)
	if frame_time_samples.size() > max_frame_time_samples:
		frame_time_samples.pop_front()
	
	# Calculate average frame time
	var total_time = 0.0
	for sample in frame_time_samples:
		total_time += sample
	average_frame_time_ms = total_time / frame_time_samples.size()

## Enable or disable the update scheduler
func set_scheduler_enabled(enabled: bool) -> void:
	scheduler_enabled = enabled
	print("HUDUpdateScheduler: Scheduler %s" % ("enabled" if enabled else "disabled"))

## Get scheduler performance statistics
func get_statistics() -> Dictionary:
	return {
		"frame_budget_ms": frame_budget_ms,
		"current_frame_time_ms": frame_update_time_ms,
		"average_frame_time_ms": average_frame_time_ms,
		"updates_this_frame": total_updates_this_frame,
		"updates_skipped_this_frame": frame_updates_skipped,
		"total_updates_scheduled": total_updates_scheduled,
		"total_updates_completed": total_updates_completed,
		"total_updates_skipped": total_updates_skipped,
		"performance_optimizations": performance_optimizations,
		"registered_elements": element_update_frequencies.size(),
		"dirty_elements": dirty_elements.size(),
		"scheduler_enabled": scheduler_enabled,
		"budget_utilization_percent": (frame_update_time_ms / frame_budget_ms) * 100.0
	}

## Get detailed element statistics
func get_element_statistics() -> Dictionary:
	var stats = {}
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	for element_id in element_update_frequencies.keys():
		stats[element_id] = {
			"frequency_hz": element_update_frequencies.get(element_id, 0.0),
			"priority": element_update_priorities.get(element_id, 0),
			"last_update_time": element_last_update_times.get(element_id, 0.0),
			"next_update_time": element_next_update_times.get(element_id, 0.0),
			"is_dirty": dirty_elements.get(element_id, false),
			"dirty_reason": dirty_reasons.get(element_id, ""),
			"time_until_next_update": element_next_update_times.get(element_id, 0.0) - current_time
		}
	
	return stats

## Optimize scheduler performance based on current load
func optimize_performance() -> void:
	var current_fps = Engine.get_frames_per_second()
	var target_fps = 60.0
	
	if current_fps < target_fps * 0.9:  # If FPS drops below 90% of target
		print("HUDUpdateScheduler: Optimizing performance due to low FPS (%.1f)" % current_fps)
		
		# Reduce update frequencies for non-critical elements
		for element_id in element_update_frequencies.keys():
			var priority = element_update_priorities.get(element_id, 50)
			
			if priority < 80:  # Non-critical elements
				var current_freq = element_update_frequencies[element_id]
				var new_freq = max(10.0, current_freq * 0.8)  # Reduce by 20%
				set_element_frequency(element_id, new_freq)
		
		# Reduce frame budget slightly
		frame_budget_ms = max(1.0, frame_budget_ms * 0.9)
		performance_optimizations += 1

## Reset performance optimizations
func reset_performance_optimizations() -> void:
	print("HUDUpdateScheduler: Resetting performance optimizations")
	
	# This would restore original frequencies and budgets
	# Implementation depends on storing original values
	frame_budget_ms = 2.0  # Reset to default
	performance_optimizations = 0

## Batch update multiple elements efficiently
func batch_update_elements(element_ids: Array[String]) -> void:
	var batch_start_time = Time.get_ticks_usec()
	
	for element_id in element_ids:
		if total_updates_this_frame >= max_updates_per_frame:
			break
		
		_execute_element_update(element_id)
		total_updates_this_frame += 1
	
	var batch_end_time = Time.get_ticks_usec()
	var batch_time_ms = (batch_end_time - batch_start_time) / 1000.0
	
	print("HUDUpdateScheduler: Batch updated %d elements in %.3fms" % [element_ids.size(), batch_time_ms])