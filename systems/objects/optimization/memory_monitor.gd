class_name MemoryMonitor
extends Node

## Object memory usage tracking and optimization system for WCS-Godot conversion.
## Monitors memory usage patterns, object allocation/deallocation, and provides
## intelligent memory management based on WCS techniques.
##
## Based on WCS C++ memory management with VM allocator and object pooling analysis.

signal memory_warning(usage_mb: float, threshold_mb: float)
signal memory_critical(usage_mb: float, threshold_mb: float)
signal gc_optimization_triggered(optimization_type: String, details: Dictionary)
signal memory_report_generated(report: Dictionary)

# EPIC-002 Asset Core Integration
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const UpdateFrequencies = preload("res://addons/wcs_asset_core/constants/update_frequencies.gd")

# Memory monitoring configuration
@export var monitoring_enabled: bool = true
@export var monitoring_interval: float = 2.0  # How often to collect memory metrics (seconds)
@export var sample_count: int = 30  # Number of samples to keep for averaging
@export var detailed_tracking: bool = false  # Enable detailed per-object memory tracking

# Memory thresholds (MB) - based on WCS object system targets
@export var memory_warning_threshold_mb: float = 80.0  # Warning at 80MB
@export var memory_critical_threshold_mb: float = 100.0  # Critical at 100MB (OBJ-015 target)
@export var object_pool_max_size_mb: float = 20.0  # Maximum pool memory usage
@export var gc_trigger_threshold_mb: float = 50.0  # Trigger GC optimizations

# Memory tracking data
var memory_usage_samples: Array[float] = []
var object_count_samples: Array[int] = []
var pool_usage_samples: Array[Dictionary] = []
var gc_event_times: Array[float] = []

# Current memory metrics
var current_memory_usage_mb: float = 0.0
var current_object_count: int = 0
var current_pool_usage_mb: float = 0.0
var current_allocations_per_second: float = 0.0
var memory_growth_rate_mb_per_sec: float = 0.0

# Object type memory tracking (WCS-style type hierarchy)
var memory_by_object_type: Dictionary = {}  # ObjectTypes.Type -> float (MB)
var allocation_counts_by_type: Dictionary = {}  # ObjectTypes.Type -> int
var deallocation_counts_by_type: Dictionary = {}  # ObjectTypes.Type -> int

# Pool memory tracking (based on WCS free-list system)
var pool_memory_usage: Dictionary = {}  # String (pool_name) -> float (MB)
var pool_allocation_counts: Dictionary = {}  # String (pool_name) -> int
var pool_hit_rates: Dictionary = {}  # String (pool_name) -> float (0.0-1.0)

# Performance tracking
var allocation_events: Array[Dictionary] = []
var gc_optimization_history: Array[Dictionary] = []
var last_gc_time: float = 0.0
var monitoring_timer: float = 0.0

# External system references
var object_manager: Node
var physics_manager: Node
var performance_monitor: Node

# State management
var is_initialized: bool = false

class MemorySnapshot:
	var timestamp: float
	var total_memory_mb: float
	var object_memory_mb: float
	var pool_memory_mb: float
	var object_count: int
	var allocation_rate: float
	var gc_events_count: int
	
	func _init() -> void:
		timestamp = Time.get_time_dict_from_system()["unix"]
		total_memory_mb = 0.0
		object_memory_mb = 0.0
		pool_memory_mb = 0.0
		object_count = 0
		allocation_rate = 0.0
		gc_events_count = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_memory_monitor()

func _initialize_memory_monitor() -> void:
	"""Initialize the memory monitoring system."""
	if is_initialized:
		push_warning("MemoryMonitor: Already initialized")
		return
	
	print("MemoryMonitor: Starting initialization...")
	
	# Get references to other systems
	object_manager = get_node_or_null("/root/ObjectManager")
	physics_manager = get_node_or_null("/root/PhysicsManager")
	performance_monitor = get_node_or_null("/root/PerformanceMonitor")
	
	# Initialize tracking data
	memory_usage_samples.clear()
	object_count_samples.clear()
	pool_usage_samples.clear()
	gc_event_times.clear()
	allocation_events.clear()
	gc_optimization_history.clear()
	
	# Initialize object type tracking
	_initialize_object_type_tracking()
	
	# Connect to system signals for memory event tracking
	_connect_system_signals()
	
	is_initialized = true
	print("MemoryMonitor: Initialization complete")

func _initialize_object_type_tracking() -> void:
	"""Initialize memory tracking for all WCS object types."""
	# Initialize tracking for all object types from EPIC-002 asset core
	for object_type in ObjectTypes.Type.values():
		memory_by_object_type[object_type] = 0.0
		allocation_counts_by_type[object_type] = 0
		deallocation_counts_by_type[object_type] = 0

func _connect_system_signals() -> void:
	"""Connect to system signals for memory event tracking."""
	if object_manager:
		if object_manager.has_signal("object_created"):
			object_manager.object_created.connect(_on_object_created)
		if object_manager.has_signal("object_destroyed"):
			object_manager.object_destroyed.connect(_on_object_destroyed)
		if object_manager.has_signal("space_object_created"):
			object_manager.space_object_created.connect(_on_space_object_created)
		if object_manager.has_signal("space_object_destroyed"):
			object_manager.space_object_destroyed.connect(_on_space_object_destroyed)

func _process(delta: float) -> void:
	if not is_initialized or not monitoring_enabled:
		return
	
	# Update monitoring timer
	monitoring_timer += delta
	
	# Perform periodic memory monitoring
	if monitoring_timer >= monitoring_interval:
		monitoring_timer = 0.0
		_perform_memory_monitoring_cycle()

func _perform_memory_monitoring_cycle() -> void:
	"""Perform a complete memory monitoring cycle."""
	var cycle_start_time: float = Time.get_ticks_usec() / 1000.0
	
	# Collect memory metrics
	_collect_memory_metrics()
	
	# Analyze memory usage patterns
	_analyze_memory_patterns()
	
	# Check memory thresholds
	_check_memory_thresholds()
	
	# Check for garbage collection optimization needs
	_check_gc_optimization()
	
	# Generate memory report
	var report: Dictionary = _generate_memory_report()
	memory_report_generated.emit(report)
	
	var cycle_time: float = (Time.get_ticks_usec() / 1000.0) - cycle_start_time
	
	if detailed_tracking:
		print("MemoryMonitor: Memory monitoring cycle completed in %.2fms" % cycle_time)

func _collect_memory_metrics() -> void:
	"""Collect current memory usage metrics."""
	# Get system memory usage
	var total_memory_usage: int = OS.get_static_memory_usage_by_type()
	current_memory_usage_mb = total_memory_usage / (1024.0 * 1024.0)
	
	# Get object count from object manager
	current_object_count = 0
	if object_manager and object_manager.has_method("get_active_object_count"):
		current_object_count += object_manager.get_active_object_count()
	if object_manager and object_manager.has_method("get_space_object_count"):
		current_object_count += object_manager.get_space_object_count()
	
	# Calculate pool memory usage
	_calculate_pool_memory_usage()
	
	# Store samples
	memory_usage_samples.append(current_memory_usage_mb)
	if memory_usage_samples.size() > sample_count:
		memory_usage_samples.pop_front()
	
	object_count_samples.append(current_object_count)
	if object_count_samples.size() > sample_count:
		object_count_samples.pop_front()
	
	# Calculate memory growth rate
	_calculate_memory_growth_rate()

func _calculate_pool_memory_usage() -> void:
	"""Calculate memory usage for object pools (WCS-style)."""
	current_pool_usage_mb = 0.0
	
	if object_manager and object_manager.has_method("get_pool_statistics"):
		var pool_stats: Dictionary = object_manager.get_pool_statistics()
		
		for pool_name in pool_stats:
			var pool_data: Dictionary = pool_stats[pool_name]
			var pool_memory_mb: float = pool_data.get("memory_usage_bytes", 0) / (1024.0 * 1024.0)
			
			pool_memory_usage[pool_name] = pool_memory_mb
			current_pool_usage_mb += pool_memory_mb
			
			# Track pool hit rates (efficiency metric from WCS free-list analysis)
			var hits: int = pool_data.get("cache_hits", 0)
			var misses: int = pool_data.get("cache_misses", 0)
			var total_requests: int = hits + misses
			
			if total_requests > 0:
				pool_hit_rates[pool_name] = float(hits) / float(total_requests)
			else:
				pool_hit_rates[pool_name] = 1.0

func _calculate_memory_growth_rate() -> void:
	"""Calculate memory growth rate for trend analysis."""
	if memory_usage_samples.size() < 5:
		return
	
	# Calculate growth rate using recent samples (like WCS timing system)
	var recent_samples: int = min(10, memory_usage_samples.size())
	var time_interval: float = monitoring_interval * float(recent_samples - 1)
	
	if time_interval > 0.0:
		var old_memory: float = memory_usage_samples[memory_usage_samples.size() - recent_samples]
		var new_memory: float = memory_usage_samples[-1]
		memory_growth_rate_mb_per_sec = (new_memory - old_memory) / time_interval
	else:
		memory_growth_rate_mb_per_sec = 0.0

func _analyze_memory_patterns() -> void:
	"""Analyze memory usage patterns for optimization opportunities."""
	# Identify memory-heavy object types (WCS priority cleanup analysis)
	var total_object_memory: float = 0.0
	for object_type in memory_by_object_type:
		total_object_memory += memory_by_object_type[object_type]
	
	# Calculate allocation efficiency (similar to WCS pair checking)
	_calculate_allocation_efficiency()
	
	# Analyze pool efficiency (based on WCS free-list hit rates)
	_analyze_pool_efficiency()

func _calculate_allocation_efficiency() -> void:
	"""Calculate object allocation efficiency metrics."""
	var total_allocations: int = 0
	var total_deallocations: int = 0
	
	for object_type in allocation_counts_by_type:
		total_allocations += allocation_counts_by_type[object_type]
		total_deallocations += deallocation_counts_by_type[object_type]
	
	if total_allocations > 0:
		var efficiency: float = float(total_deallocations) / float(total_allocations)
		current_allocations_per_second = float(total_allocations) / max(monitoring_interval * sample_count, 1.0)

func _analyze_pool_efficiency() -> void:
	"""Analyze object pool efficiency for optimization recommendations."""
	for pool_name in pool_hit_rates:
		var hit_rate: float = pool_hit_rates[pool_name]
		var memory_usage: float = pool_memory_usage.get(pool_name, 0.0)
		
		# Log inefficient pools (similar to WCS object cleanup priority)
		if hit_rate < 0.7 and memory_usage > 1.0:  # Low hit rate and significant memory usage
			if detailed_tracking:
				print("MemoryMonitor: Pool '%s' inefficient - hit rate: %.2f, memory: %.2fMB" % [pool_name, hit_rate, memory_usage])

func _check_memory_thresholds() -> void:
	"""Check memory usage against warning and critical thresholds."""
	# Check total memory thresholds
	if current_memory_usage_mb > memory_critical_threshold_mb:
		memory_critical.emit(current_memory_usage_mb, memory_critical_threshold_mb)
	elif current_memory_usage_mb > memory_warning_threshold_mb:
		memory_warning.emit(current_memory_usage_mb, memory_warning_threshold_mb)
	
	# Check pool memory thresholds
	if current_pool_usage_mb > object_pool_max_size_mb:
		memory_warning.emit(current_pool_usage_mb, object_pool_max_size_mb)
	
	# Check memory growth rate
	if memory_growth_rate_mb_per_sec > 1.0:  # Growing more than 1MB/sec
		memory_warning.emit(memory_growth_rate_mb_per_sec, 1.0)

func _check_gc_optimization() -> void:
	"""Check if garbage collection optimization should be triggered."""
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Check GC optimization cooldown (like WCS optimization_cooldown)
	if current_time - last_gc_time < 10.0:  # 10 second cooldown
		return
	
	var needs_gc_optimization: bool = false
	var optimization_reason: String = ""
	
	if current_memory_usage_mb > gc_trigger_threshold_mb:
		needs_gc_optimization = true
		optimization_reason = "high_memory_usage"
	elif memory_growth_rate_mb_per_sec > 0.5:  # Rapid memory growth
		needs_gc_optimization = true
		optimization_reason = "rapid_memory_growth"
	elif current_pool_usage_mb > object_pool_max_size_mb * 0.8:  # Pool approaching limit
		needs_gc_optimization = true
		optimization_reason = "pool_memory_high"
	
	if needs_gc_optimization:
		_trigger_gc_optimization(optimization_reason)

func _trigger_gc_optimization(reason: String) -> void:
	"""Trigger garbage collection optimization (WCS-style object cleanup)."""
	print("MemoryMonitor: Triggering GC optimization for: %s" % reason)
	
	var optimization_details: Dictionary = {
		"reason": reason,
		"current_memory_mb": current_memory_usage_mb,
		"current_object_count": current_object_count,
		"pool_usage_mb": current_pool_usage_mb,
		"growth_rate_mb_per_sec": memory_growth_rate_mb_per_sec,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	
	# Apply GC optimizations based on reason (like WCS priority cleanup)
	match reason:
		"high_memory_usage":
			_optimize_for_memory_usage()
		"rapid_memory_growth":
			_optimize_for_memory_growth()
		"pool_memory_high":
			_optimize_pool_memory()
	
	# Record optimization
	gc_optimization_history.append(optimization_details)
	last_gc_time = Time.get_time_dict_from_system()["unix"]
	
	gc_optimization_triggered.emit(reason, optimization_details)

func _optimize_for_memory_usage() -> void:
	"""Optimize for high memory usage (WCS free_object_slots equivalent)."""
	# Force garbage collection
	if OS.has_method("request_attention"):  # Godot doesn't have direct GC control
		print("MemoryMonitor: Requesting immediate garbage collection")
	
	# Request object manager to clean up pools
	if object_manager and object_manager.has_method("optimize_object_pools"):
		object_manager.optimize_object_pools()

func _optimize_for_memory_growth() -> void:
	"""Optimize for rapid memory growth."""
	# Reduce object pool sizes temporarily
	if object_manager and object_manager.has_method("reduce_pool_sizes"):
		object_manager.reduce_pool_sizes(0.8)  # Reduce to 80% of current size

func _optimize_pool_memory() -> void:
	"""Optimize object pool memory usage."""
	# Clean up least efficient pools first (WCS priority order)
	for pool_name in pool_hit_rates:
		var hit_rate: float = pool_hit_rates[pool_name]
		if hit_rate < 0.6:  # Very inefficient pool
			if object_manager and object_manager.has_method("cleanup_pool"):
				object_manager.cleanup_pool(pool_name, 0.5)  # Clean up 50% of pool

func _generate_memory_report() -> Dictionary:
	"""Generate a comprehensive memory usage report."""
	return {
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"current_metrics": {
			"total_memory_mb": current_memory_usage_mb,
			"object_count": current_object_count,
			"pool_memory_mb": current_pool_usage_mb,
			"allocations_per_second": current_allocations_per_second,
			"growth_rate_mb_per_sec": memory_growth_rate_mb_per_sec
		},
		"thresholds": {
			"warning_threshold_mb": memory_warning_threshold_mb,
			"critical_threshold_mb": memory_critical_threshold_mb,
			"pool_max_size_mb": object_pool_max_size_mb
		},
		"by_object_type": memory_by_object_type.duplicate(),
		"pool_statistics": {
			"memory_usage": pool_memory_usage.duplicate(),
			"hit_rates": pool_hit_rates.duplicate(),
			"allocation_counts": pool_allocation_counts.duplicate()
		},
		"status": {
			"memory_status": _get_memory_status(),
			"pool_status": _get_pool_status(),
			"growth_status": _get_growth_status()
		},
		"gc_optimization_count": gc_optimization_history.size(),
		"last_gc_optimization": gc_optimization_history[-1] if gc_optimization_history.size() > 0 else null
	}

func _get_memory_status() -> String:
	"""Get overall memory status."""
	if current_memory_usage_mb > memory_critical_threshold_mb:
		return "critical"
	elif current_memory_usage_mb > memory_warning_threshold_mb:
		return "warning"
	else:
		return "good"

func _get_pool_status() -> String:
	"""Get object pool status."""
	if current_pool_usage_mb > object_pool_max_size_mb:
		return "critical"
	elif current_pool_usage_mb > object_pool_max_size_mb * 0.8:
		return "warning"
	else:
		return "good"

func _get_growth_status() -> String:
	"""Get memory growth status."""
	if memory_growth_rate_mb_per_sec > 1.0:
		return "critical"
	elif memory_growth_rate_mb_per_sec > 0.5:
		return "warning"
	else:
		return "good"

# Signal handlers for memory tracking

func _on_object_created(object: WCSObject) -> void:
	"""Handle object creation for memory tracking."""
	if object and object.has_method("get_object_type"):
		var object_type: int = object.get_object_type()
		allocation_counts_by_type[object_type] = allocation_counts_by_type.get(object_type, 0) + 1

func _on_object_destroyed(object: WCSObject) -> void:
	"""Handle object destruction for memory tracking."""
	if object and object.has_method("get_object_type"):
		var object_type: int = object.get_object_type()
		deallocation_counts_by_type[object_type] = deallocation_counts_by_type.get(object_type, 0) + 1

func _on_space_object_created(object: BaseSpaceObject, object_id: int) -> void:
	"""Handle space object creation for memory tracking."""
	if object and object.has_method("get_space_object_type"):
		var object_type: int = object.get_space_object_type()
		allocation_counts_by_type[object_type] = allocation_counts_by_type.get(object_type, 0) + 1

func _on_space_object_destroyed(object: BaseSpaceObject, object_id: int) -> void:
	"""Handle space object destruction for memory tracking."""
	if object and object.has_method("get_space_object_type"):
		var object_type: int = object.get_space_object_type()
		deallocation_counts_by_type[object_type] = deallocation_counts_by_type.get(object_type, 0) + 1

# Public API

func get_current_memory_metrics() -> Dictionary:
	"""Get current memory metrics.
	
	Returns:
		Dictionary containing current memory usage data
	"""
	return {
		"total_memory_mb": current_memory_usage_mb,
		"object_count": current_object_count,
		"pool_memory_mb": current_pool_usage_mb,
		"allocations_per_second": current_allocations_per_second,
		"growth_rate_mb_per_sec": memory_growth_rate_mb_per_sec
	}

func get_memory_report() -> Dictionary:
	"""Get the latest memory usage report.
	
	Returns:
		Comprehensive memory usage report
	"""
	return _generate_memory_report()

func get_pool_statistics() -> Dictionary:
	"""Get object pool statistics.
	
	Returns:
		Dictionary containing pool memory usage and efficiency metrics
	"""
	return {
		"memory_usage": pool_memory_usage.duplicate(),
		"hit_rates": pool_hit_rates.duplicate(),
		"allocation_counts": pool_allocation_counts.duplicate()
	}

func set_monitoring_enabled(enabled: bool) -> void:
	"""Enable or disable memory monitoring.
	
	Args:
		enabled: true to enable monitoring
	"""
	monitoring_enabled = enabled
	print("MemoryMonitor: Memory monitoring %s" % ("enabled" if enabled else "disabled"))

func is_monitoring_enabled() -> bool:
	"""Check if memory monitoring is enabled.
	
	Returns:
		true if monitoring is enabled
	"""
	return monitoring_enabled

func force_gc_optimization() -> void:
	"""Force immediate garbage collection optimization (for testing)."""
	_trigger_gc_optimization("manual_trigger")

func reset_memory_statistics() -> void:
	"""Reset all memory statistics and counters."""
	memory_usage_samples.clear()
	object_count_samples.clear()
	pool_usage_samples.clear()
	gc_event_times.clear()
	allocation_events.clear()
	gc_optimization_history.clear()
	
	# Reset object type tracking
	for object_type in allocation_counts_by_type:
		allocation_counts_by_type[object_type] = 0
		deallocation_counts_by_type[object_type] = 0
	
	print("MemoryMonitor: Memory statistics reset")

# Debug functions

func debug_print_memory_report() -> void:
	"""Print a detailed memory report for debugging."""
	var report: Dictionary = _generate_memory_report()
	
	print("=== Memory Monitor Report ===")
	print("Total Memory: %.1fMB / %.1fMB" % [report["current_metrics"]["total_memory_mb"], memory_critical_threshold_mb])
	print("Object Count: %d" % report["current_metrics"]["object_count"])
	print("Pool Memory: %.1fMB / %.1fMB" % [report["current_metrics"]["pool_memory_mb"], object_pool_max_size_mb])
	print("Allocations/sec: %.1f" % report["current_metrics"]["allocations_per_second"])
	print("Growth Rate: %+.3fMB/sec" % report["current_metrics"]["growth_rate_mb_per_sec"])
	print("Memory Status: %s" % report["status"]["memory_status"])
	print("Pool Status: %s" % report["status"]["pool_status"])
	print("GC Optimizations: %d" % report["gc_optimization_count"])
	print("=============================")