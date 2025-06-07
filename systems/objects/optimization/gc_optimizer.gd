class_name GCOptimizer
extends Node

## Garbage collection optimization system for WCS-Godot conversion.
## Implements intelligent GC scheduling and memory cleanup strategies
## based on WCS C++ free_object_slots() and priority-based cleanup.
##
## Provides automatic garbage collection tuning and object lifecycle optimization
## to maintain stable performance under varying memory pressure conditions.

signal gc_cycle_completed(cycle_stats: Dictionary)
signal gc_optimization_applied(optimization_type: String, details: Dictionary)
signal object_cleanup_completed(objects_cleaned: int, memory_freed_mb: float)
signal gc_schedule_adjusted(new_interval: float, reason: String)

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

# GC optimization configuration
@export var optimization_enabled: bool = true
@export var adaptive_scheduling: bool = true
@export var aggressive_cleanup: bool = false  # Enable WCS-style aggressive cleanup
@export var detailed_logging: bool = false

# GC timing configuration (based on WCS timing analysis)
@export var base_gc_interval: float = 5.0  # Base GC interval (seconds)
@export var min_gc_interval: float = 1.0   # Minimum GC interval under pressure
@export var max_gc_interval: float = 30.0  # Maximum GC interval when stable
@export var gc_time_budget_ms: float = 2.0  # Maximum time budget per GC cycle

# Object cleanup configuration (WCS priority order)
@export var cleanup_batch_size: int = 50   # Objects to clean per batch
@export var max_cleanup_time_ms: float = 1.0  # Maximum cleanup time per frame
@export var debris_cleanup_threshold: int = 100  # Clean debris when count exceeds this
@export var weapon_cleanup_threshold: int = 200  # Clean weapons when count exceeds this

# Memory pressure thresholds
@export var memory_pressure_low_mb: float = 60.0    # Below this = low pressure
@export var memory_pressure_medium_mb: float = 80.0  # Above this = medium pressure
@export var memory_pressure_high_mb: float = 95.0   # Above this = high pressure

# GC optimization state
var current_gc_interval: float = 5.0
var gc_timer: float = 0.0
var memory_pressure_level: int = 0  # 0=low, 1=medium, 2=high, 3=critical
var adaptive_multiplier: float = 1.0
var last_gc_cycle_time: float = 0.0

# Cleanup tracking (WCS-style priority system)
var cleanup_priority_queue: Array[Dictionary] = []
var objects_cleaned_this_cycle: int = 0
var memory_freed_this_cycle: float = 0.0
var cleanup_efficiency_history: Array[float] = []

# Performance metrics
var gc_cycle_count: int = 0
var total_gc_time_ms: float = 0.0
var average_gc_time_ms: float = 0.0
var objects_cleaned_total: int = 0
var memory_freed_total_mb: float = 0.0

# External system references
var memory_monitor: Node
var object_manager: Node
var performance_monitor: Node

# State management
var is_initialized: bool = false
var gc_in_progress: bool = false

# WCS-style object cleanup priorities (from C++ analysis)
enum CleanupPriority {
	IMMEDIATE = 0,    # Critical objects to clean immediately
	HIGH = 1,         # Debris with DEBRIS_EXPIRE flag
	MEDIUM = 2,       # Perishable fireballs, old weapons
	LOW = 3,          # General weapons
	DEFERRED = 4      # Objects to clean when memory is very low
}

class CleanupCandidate:
	var object: Object
	var priority: CleanupPriority
	var age_seconds: float
	var memory_estimate_mb: float
	var object_type: int
	
	func _init(obj: Object, prio: CleanupPriority, age: float, memory_mb: float, type: int) -> void:
		object = obj
		priority = prio
		age_seconds = age
		memory_estimate_mb = memory_mb
		object_type = type

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_gc_optimizer()

func _initialize_gc_optimizer() -> void:
	"""Initialize the garbage collection optimizer."""
	if is_initialized:
		push_warning("GCOptimizer: Already initialized")
		return
	
	print("GCOptimizer: Starting initialization...")
	
	# Get references to other systems
	memory_monitor = get_node_or_null("/root/MemoryMonitor")
	object_manager = get_node_or_null("/root/ObjectManager")
	performance_monitor = get_node_or_null("/root/PerformanceMonitor")
	
	# Initialize GC timing
	current_gc_interval = base_gc_interval
	gc_timer = 0.0
	
	# Connect to system signals
	_connect_system_signals()
	
	is_initialized = true
	print("GCOptimizer: Initialization complete")

func _connect_system_signals() -> void:
	"""Connect to system signals for GC optimization triggers."""
	if memory_monitor:
		if memory_monitor.has_signal("memory_warning"):
			memory_monitor.memory_warning.connect(_on_memory_warning)
		if memory_monitor.has_signal("memory_critical"):
			memory_monitor.memory_critical.connect(_on_memory_critical)
	
	if performance_monitor:
		if performance_monitor.has_signal("performance_warning"):
			performance_monitor.performance_warning.connect(_on_performance_warning)

func _process(delta: float) -> void:
	if not is_initialized or not optimization_enabled or gc_in_progress:
		return
	
	# Update GC timer
	gc_timer += delta
	
	# Update memory pressure level
	_update_memory_pressure_level()
	
	# Adjust GC interval based on conditions
	if adaptive_scheduling:
		_adjust_gc_interval()
	
	# Check if GC cycle should run
	if gc_timer >= current_gc_interval:
		gc_timer = 0.0
		_schedule_gc_cycle()

func _update_memory_pressure_level() -> void:
	"""Update current memory pressure level based on usage."""
	var current_memory: float = 0.0
	
	if memory_monitor and memory_monitor.has_method("get_current_memory_metrics"):
		var metrics: Dictionary = memory_monitor.get_current_memory_metrics()
		current_memory = metrics.get("total_memory_mb", 0.0)
	
	var previous_level: int = memory_pressure_level
	
	if current_memory >= memory_pressure_high_mb:
		memory_pressure_level = 2  # High pressure
	elif current_memory >= memory_pressure_medium_mb:
		memory_pressure_level = 1  # Medium pressure
	else:
		memory_pressure_level = 0  # Low pressure
	
	# Log pressure level changes
	if previous_level != memory_pressure_level and detailed_logging:
		var pressure_names: Array[String] = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
		print("GCOptimizer: Memory pressure level changed to %s (%.1fMB)" % [pressure_names[memory_pressure_level], current_memory])

func _adjust_gc_interval() -> void:
	"""Adjust GC interval based on memory pressure and performance."""
	var target_interval: float = base_gc_interval
	var adjustment_reason: String = ""
	
	# Adjust based on memory pressure (WCS-style adaptive behavior)
	match memory_pressure_level:
		0:  # Low pressure - extend interval
			target_interval = base_gc_interval * 1.5
			adjustment_reason = "low_memory_pressure"
		1:  # Medium pressure - normal interval
			target_interval = base_gc_interval
			adjustment_reason = "medium_memory_pressure"
		2:  # High pressure - reduce interval
			target_interval = base_gc_interval * 0.5
			adjustment_reason = "high_memory_pressure"
	
	# Consider performance factors
	if performance_monitor and performance_monitor.has_method("get_current_performance_metrics"):
		var metrics: Dictionary = performance_monitor.get_current_performance_metrics()
		var current_fps: float = metrics.get("fps", 60.0)
		
		if current_fps < 50.0:  # Poor performance - be more aggressive
			target_interval *= 0.7
			adjustment_reason = "poor_performance"
	
	# Clamp to valid range
	target_interval = clamp(target_interval, min_gc_interval, max_gc_interval)
	
	# Apply smooth adjustment
	if abs(target_interval - current_gc_interval) > 0.5:
		var old_interval: float = current_gc_interval
		current_gc_interval = lerp(current_gc_interval, target_interval, 0.3)
		
		if detailed_logging:
			print("GCOptimizer: Adjusted GC interval from %.1fs to %.1fs (%s)" % [old_interval, current_gc_interval, adjustment_reason])
		
		gc_schedule_adjusted.emit(current_gc_interval, adjustment_reason)

func _schedule_gc_cycle() -> void:
	"""Schedule a garbage collection cycle."""
	if gc_in_progress:
		return
	
	# Run GC cycle in next frame to avoid frame rate impact
	call_deferred("_run_gc_cycle")

func _run_gc_cycle() -> void:
	"""Run a complete garbage collection optimization cycle."""
	if gc_in_progress:
		return
	
	gc_in_progress = true
	var cycle_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Reset cycle counters
	objects_cleaned_this_cycle = 0
	memory_freed_this_cycle = 0.0
	
	print("GCOptimizer: Starting GC cycle %d (pressure level: %d)" % [gc_cycle_count + 1, memory_pressure_level])
	
	# Phase 1: Identify cleanup candidates (WCS object scanning)
	_identify_cleanup_candidates()
	
	# Phase 2: Execute priority-based cleanup (WCS free_object_slots equivalent)
	_execute_priority_cleanup()
	
	# Phase 3: Trigger system garbage collection if needed
	if memory_pressure_level >= 1:
		_trigger_system_gc()
	
	# Phase 4: Optimize object pools
	_optimize_object_pools()
	
	# Calculate cycle statistics
	var cycle_time: float = (Time.get_ticks_usec() / 1000.0) - cycle_start_time
	last_gc_cycle_time = cycle_time
	
	# Update performance metrics
	gc_cycle_count += 1
	total_gc_time_ms += cycle_time
	average_gc_time_ms = total_gc_time_ms / float(gc_cycle_count)
	objects_cleaned_total += objects_cleaned_this_cycle
	memory_freed_total_mb += memory_freed_this_cycle
	
	# Calculate cleanup efficiency
	var efficiency: float = 0.0
	if cycle_time > 0.0:
		efficiency = memory_freed_this_cycle / cycle_time  # MB freed per ms
	
	cleanup_efficiency_history.append(efficiency)
	if cleanup_efficiency_history.size() > 10:
		cleanup_efficiency_history.pop_front()
	
	# Generate cycle statistics
	var cycle_stats: Dictionary = {
		"cycle_number": gc_cycle_count,
		"cycle_time_ms": cycle_time,
		"objects_cleaned": objects_cleaned_this_cycle,
		"memory_freed_mb": memory_freed_this_cycle,
		"memory_pressure_level": memory_pressure_level,
		"cleanup_efficiency": efficiency
	}
	
	gc_cycle_completed.emit(cycle_stats)
	
	print("GCOptimizer: GC cycle completed - %d objects cleaned, %.2fMB freed in %.2fms" % [objects_cleaned_this_cycle, memory_freed_this_cycle, cycle_time])
	
	gc_in_progress = false

func _identify_cleanup_candidates() -> void:
	"""Identify objects that are candidates for cleanup (WCS-style scanning)."""
	cleanup_priority_queue.clear()
	
	if not object_manager:
		return
	
	# Get all active objects for analysis
	var active_objects: Array = []
	if object_manager.has_method("get_all_active_objects"):
		active_objects = object_manager.get_all_active_objects()
	
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Analyze objects for cleanup priority (based on WCS priority system)
	for obj in active_objects:
		if not is_instance_valid(obj):
			continue
		
		var cleanup_candidate: CleanupCandidate = _analyze_object_for_cleanup(obj, current_time)
		if cleanup_candidate:
			cleanup_priority_queue.append({
				"candidate": cleanup_candidate,
				"priority_score": _calculate_priority_score(cleanup_candidate)
			})
	
	# Sort by priority score (highest first - most important to clean)
	cleanup_priority_queue.sort_custom(_compare_cleanup_priority)
	
	if detailed_logging:
		print("GCOptimizer: Identified %d cleanup candidates" % cleanup_priority_queue.size())

func _analyze_object_for_cleanup(obj: Object, current_time: float) -> CleanupCandidate:
	"""Analyze an object to determine if it's a cleanup candidate."""
	if not obj or not is_instance_valid(obj):
		return null
	
	var object_type: int = ObjectTypes.Type.UNKNOWN
	var creation_time: float = current_time
	var memory_estimate: float = 0.1  # Default estimate
	
	# Get object information
	if obj.has_method("get_object_type"):
		object_type = obj.get_object_type()
	if obj.has_method("get_creation_time"):
		creation_time = obj.get_creation_time()
	if obj.has_method("get_memory_footprint"):
		memory_estimate = obj.get_memory_footprint() / (1024.0 * 1024.0)  # Convert to MB
	
	var age: float = current_time - creation_time
	var priority: CleanupPriority = _determine_cleanup_priority(obj, object_type, age)
	
	# Only create candidate if object should be considered for cleanup
	if priority != CleanupPriority.DEFERRED or memory_pressure_level >= 2:
		return CleanupCandidate.new(obj, priority, age, memory_estimate, object_type)
	
	return null

func _determine_cleanup_priority(obj: Object, object_type: int, age: float) -> CleanupPriority:
	"""Determine cleanup priority for an object (WCS cleanup order)."""
	# Immediate priority - objects marked for destruction
	if obj.has_method("is_marked_for_destruction") and obj.is_marked_for_destruction():
		return CleanupPriority.IMMEDIATE
	
	# High priority - debris objects (WCS debris cleanup)
	if object_type == ObjectTypes.Type.DEBRIS:
		if obj.has_method("has_expire_flag") and obj.has_expire_flag():
			return CleanupPriority.HIGH
		elif age > 30.0:  # Old debris
			return CleanupPriority.HIGH
	
	# Medium priority - old weapons and effects (WCS weapon cleanup)
	if object_type == ObjectTypes.Type.WEAPON:
		if age > 15.0:  # Old weapon
			return CleanupPriority.MEDIUM
		elif obj.has_method("is_perishable") and obj.is_perishable():
			return CleanupPriority.MEDIUM
	
	if object_type == ObjectTypes.Type.FIREBALL or object_type == ObjectTypes.Type.EFFECT:
		if age > 10.0:  # Old effect
			return CleanupPriority.MEDIUM
	
	# Low priority - general cleanup candidates
	if age > 60.0:  # Very old objects
		return CleanupPriority.LOW
	
	# Deferred - don't clean unless absolutely necessary
	return CleanupPriority.DEFERRED

func _calculate_priority_score(candidate: CleanupCandidate) -> float:
	"""Calculate priority score for cleanup ordering."""
	var score: float = 0.0
	
	# Base score from priority level
	match candidate.priority:
		CleanupPriority.IMMEDIATE:
			score += 1000.0
		CleanupPriority.HIGH:
			score += 100.0
		CleanupPriority.MEDIUM:
			score += 50.0
		CleanupPriority.LOW:
			score += 10.0
		CleanupPriority.DEFERRED:
			score += 1.0
	
	# Add age bonus (older = higher score)
	score += candidate.age_seconds * 0.1
	
	# Add memory bonus (more memory = higher score)
	score += candidate.memory_estimate_mb * 5.0
	
	# Memory pressure multiplier
	if memory_pressure_level >= 2:
		score *= 2.0
	
	return score

func _compare_cleanup_priority(a: Dictionary, b: Dictionary) -> bool:
	"""Compare cleanup priority for sorting."""
	return a["priority_score"] > b["priority_score"]

func _execute_priority_cleanup() -> void:
	"""Execute priority-based object cleanup (WCS free_object_slots equivalent)."""
	var cleanup_start_time: float = Time.get_ticks_usec() / 1000.0
	var objects_to_clean: int = min(cleanup_batch_size, cleanup_priority_queue.size())
	
	# Adjust cleanup count based on memory pressure
	match memory_pressure_level:
		0:  # Low pressure - conservative cleanup
			objects_to_clean = min(objects_to_clean, 10)
		1:  # Medium pressure - normal cleanup
			objects_to_clean = min(objects_to_clean, cleanup_batch_size)
		2:  # High pressure - aggressive cleanup
			objects_to_clean = min(objects_to_clean, cleanup_batch_size * 2)
	
	var cleaned_count: int = 0
	
	for i in range(objects_to_clean):
		if i >= cleanup_priority_queue.size():
			break
		
		var cleanup_item: Dictionary = cleanup_priority_queue[i]
		var candidate: CleanupCandidate = cleanup_item["candidate"]
		
		# Check time budget
		var elapsed_time: float = (Time.get_ticks_usec() / 1000.0) - cleanup_start_time
		if elapsed_time > max_cleanup_time_ms:
			if detailed_logging:
				print("GCOptimizer: Cleanup time budget exceeded, stopping after %d objects" % cleaned_count)
			break
		
		# Clean up the object
		if _cleanup_object(candidate):
			cleaned_count += 1
			objects_cleaned_this_cycle += 1
			memory_freed_this_cycle += candidate.memory_estimate_mb
	
	if cleaned_count > 0:
		object_cleanup_completed.emit(cleaned_count, memory_freed_this_cycle)

func _cleanup_object(candidate: CleanupCandidate) -> bool:
	"""Clean up a specific object."""
	if not candidate.object or not is_instance_valid(candidate.object):
		return false
	
	# Safely remove object
	if candidate.object.has_method("cleanup"):
		candidate.object.cleanup()
	elif candidate.object.has_method("queue_free"):
		candidate.object.queue_free()
	else:
		return false
	
	return true

func _trigger_system_gc() -> void:
	"""Trigger system-level garbage collection."""
	# Godot doesn't expose direct GC control, but we can suggest it
	if detailed_logging:
		print("GCOptimizer: Suggesting system garbage collection")
	
	# Force some allocations to trigger GC (hack)
	var temp_arrays: Array = []
	for i in range(10):
		temp_arrays.append(Array())
	temp_arrays.clear()

func _optimize_object_pools() -> void:
	"""Optimize object pools (WCS pool optimization)."""
	if not object_manager or not object_manager.has_method("optimize_object_pools"):
		return
	
	object_manager.optimize_object_pools()
	
	gc_optimization_applied.emit("pool_optimization", {
		"memory_pressure_level": memory_pressure_level,
		"objects_cleaned": objects_cleaned_this_cycle
	})

# Signal handlers

func _on_memory_warning(usage_mb: float, threshold_mb: float) -> void:
	"""Handle memory warning by scheduling immediate GC."""
	if detailed_logging:
		print("GCOptimizer: Memory warning received (%.1fMB / %.1fMB)" % [usage_mb, threshold_mb])
	
	# Schedule immediate GC cycle
	gc_timer = current_gc_interval  # Force next cycle

func _on_memory_critical(usage_mb: float, threshold_mb: float) -> void:
	"""Handle critical memory situation with aggressive cleanup."""
	print("GCOptimizer: CRITICAL memory situation (%.1fMB / %.1fMB) - triggering emergency cleanup" % [usage_mb, threshold_mb])
	
	# Set to critical pressure and trigger immediate aggressive cleanup
	memory_pressure_level = 3
	aggressive_cleanup = true
	
	# Force immediate GC cycle
	_schedule_gc_cycle()

func _on_performance_warning(metric: String, current_value: float, threshold: float) -> void:
	"""Handle performance warning by adjusting GC strategy."""
	if metric == "fps" and current_value < 50.0:
		# Reduce GC frequency to improve performance
		current_gc_interval = min(current_gc_interval * 1.2, max_gc_interval)
		
		if detailed_logging:
			print("GCOptimizer: Reduced GC frequency due to low FPS (%.1f)" % current_value)

# Public API

func get_gc_statistics() -> Dictionary:
	"""Get garbage collection statistics.
	
	Returns:
		Dictionary containing GC performance metrics
	"""
	var avg_efficiency: float = 0.0
	if cleanup_efficiency_history.size() > 0:
		for efficiency in cleanup_efficiency_history:
			avg_efficiency += efficiency
		avg_efficiency /= cleanup_efficiency_history.size()
	
	return {
		"gc_cycle_count": gc_cycle_count,
		"total_gc_time_ms": total_gc_time_ms,
		"average_gc_time_ms": average_gc_time_ms,
		"objects_cleaned_total": objects_cleaned_total,
		"memory_freed_total_mb": memory_freed_total_mb,
		"current_interval": current_gc_interval,
		"memory_pressure_level": memory_pressure_level,
		"average_cleanup_efficiency": avg_efficiency,
		"last_cycle_time_ms": last_gc_cycle_time
	}

func set_optimization_enabled(enabled: bool) -> void:
	"""Enable or disable GC optimization.
	
	Args:
		enabled: true to enable optimization
	"""
	optimization_enabled = enabled
	print("GCOptimizer: GC optimization %s" % ("enabled" if enabled else "disabled"))

func force_gc_cycle() -> void:
	"""Force immediate garbage collection cycle (for testing)."""
	gc_timer = current_gc_interval
	_schedule_gc_cycle()

func set_aggressive_mode(aggressive: bool) -> void:
	"""Enable or disable aggressive cleanup mode.
	
	Args:
		aggressive: true to enable aggressive cleanup
	"""
	aggressive_cleanup = aggressive
	print("GCOptimizer: Aggressive cleanup %s" % ("enabled" if aggressive else "disabled"))

# Debug functions

func debug_print_gc_statistics() -> void:
	"""Print detailed GC statistics for debugging."""
	var stats: Dictionary = get_gc_statistics()
	
	print("=== GC Optimizer Statistics ===")
	print("GC Cycles: %d" % stats["gc_cycle_count"])
	print("Total GC Time: %.1fms" % stats["total_gc_time_ms"])
	print("Average GC Time: %.2fms" % stats["average_gc_time_ms"])
	print("Objects Cleaned: %d" % stats["objects_cleaned_total"])
	print("Memory Freed: %.2fMB" % stats["memory_freed_total_mb"])
	print("Current Interval: %.1fs" % stats["current_interval"])
	print("Memory Pressure: %d" % stats["memory_pressure_level"])
	print("Cleanup Efficiency: %.3f MB/ms" % stats["average_cleanup_efficiency"])
	print("Last Cycle Time: %.2fms" % stats["last_cycle_time_ms"])
	print("===============================")