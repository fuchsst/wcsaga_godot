class_name ShipCombatPerformanceMonitor
extends Node

## SHIP-016 AC1: Performance Monitor with real-time profiling and bottleneck detection
## Tracks frame rate, memory usage, and system performance with bottleneck identification
## Provides comprehensive performance monitoring for ship combat systems

signal performance_threshold_exceeded(metric_name: String, current_value: float, threshold: float)
signal bottleneck_detected(system_name: String, severity: float, details: Dictionary)
signal memory_warning(usage_mb: float, threshold_mb: float, growth_rate: float)
signal frame_rate_warning(current_fps: float, target_fps: float, duration: float)

# Performance tracking configuration
@export var target_fps: float = 60.0
@export var memory_warning_threshold_mb: float = 1500.0
@export var memory_critical_threshold_mb: float = 2000.0
@export var update_frequency: float = 0.1  # Updates per second
@export var sample_window_size: int = 60  # Number of samples to keep
@export var bottleneck_detection_enabled: bool = true

# Real-time metrics
var current_fps: float = 60.0
var average_fps: float = 60.0
var minimum_fps: float = 60.0
var frame_time_ms: float = 16.67
var memory_usage_mb: float = 0.0
var memory_peak_mb: float = 0.0
var memory_growth_rate: float = 0.0

# System-specific performance metrics
var ship_count: int = 0
var active_ships: int = 0
var ships_in_view: int = 0
var ships_updating: int = 0
var ships_culled: int = 0
var effect_count: int = 0
var active_effects: int = 0
var rendered_effects: int = 0
var culled_effects: int = 0
var pooled_effects: int = 0

# CPU and GPU metrics
var cpu_usage_percent: float = 0.0
var gpu_usage_percent: float = 0.0
var main_thread_time_ms: float = 0.0
var physics_thread_time_ms: float = 0.0
var render_thread_time_ms: float = 0.0

# Sample storage for analysis
var fps_samples: Array[float] = []
var frame_time_samples: Array[float] = []
var memory_samples: Array[float] = []
var cpu_samples: Array[float] = []

# Bottleneck detection
var system_performance_trackers: Dictionary = {}
var bottleneck_thresholds: Dictionary = {
	"ship_update": 8.0,  # Max ms per frame for ship updates
	"weapon_processing": 4.0,  # Max ms per frame for weapon processing
	"effect_rendering": 6.0,  # Max ms per frame for effects
	"physics_simulation": 5.0,  # Max ms per frame for physics
	"collision_detection": 3.0,  # Max ms per frame for collisions
	"ai_processing": 2.0,  # Max ms per frame for AI
	"audio_processing": 1.0  # Max ms per frame for audio
}

# Performance tracking state
var last_update_time: float = 0.0
var monitoring_active: bool = false
var performance_log: Array[Dictionary] = []
var max_log_entries: int = 1000

func _ready() -> void:
	_initialize_performance_tracking()
	set_process(true)
	monitoring_active = true
	print("PerformanceMonitor: Real-time performance monitoring initialized")

## Initialize performance tracking systems
func _initialize_performance_tracking() -> void:
	# Initialize sample arrays
	fps_samples.resize(sample_window_size)
	frame_time_samples.resize(sample_window_size)
	memory_samples.resize(sample_window_size)
	cpu_samples.resize(sample_window_size)
	
	# Fill with initial values
	for i in range(sample_window_size):
		fps_samples[i] = target_fps
		frame_time_samples[i] = 1000.0 / target_fps
		memory_samples[i] = 0.0
		cpu_samples[i] = 0.0
	
	# Initialize system performance trackers
	for system_name in bottleneck_thresholds.keys():
		system_performance_trackers[system_name] = {
			"samples": [],
			"current_time": 0.0,
			"peak_time": 0.0,
			"warning_count": 0,
			"last_warning_time": 0.0
		}

func _process(delta: float) -> void:
	if not monitoring_active:
		return
	
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Update at specified frequency
	if current_time - last_update_time >= update_frequency:
		_update_performance_metrics(delta)
		_detect_bottlenecks()
		_check_performance_thresholds()
		last_update_time = current_time

## Update all performance metrics
func _update_performance_metrics(delta: float) -> void:
	# Calculate frame rate metrics
	current_fps = 1.0 / delta if delta > 0.0 else 60.0
	frame_time_ms = delta * 1000.0
	
	# Update FPS samples
	_add_sample(fps_samples, current_fps)
	_add_sample(frame_time_samples, frame_time_ms)
	
	# Calculate averages
	average_fps = _calculate_average(fps_samples)
	minimum_fps = _calculate_minimum(fps_samples)
	
	# Update memory metrics
	_update_memory_metrics()
	
	# Update system-specific metrics
	_update_system_metrics()
	
	# Update CPU/GPU metrics (estimated)
	_update_hardware_metrics()

## Update memory usage metrics
func _update_memory_metrics() -> void:
	# Get current memory usage (Godot doesn't expose direct memory stats)
	# We estimate based on object counts and known allocations
	var previous_memory: float = memory_usage_mb
	
	# Estimate memory usage based on system state
	memory_usage_mb = _estimate_memory_usage()
	memory_peak_mb = max(memory_peak_mb, memory_usage_mb)
	
	# Calculate growth rate
	if previous_memory > 0.0:
		var growth: float = memory_usage_mb - previous_memory
		memory_growth_rate = growth / update_frequency  # MB per second
	
	_add_sample(memory_samples, memory_usage_mb)

## Estimate current memory usage based on game state
func _estimate_memory_usage() -> float:
	var estimated_mb: float = 100.0  # Base game memory
	
	# Add ship memory estimates (approximately 1MB per active ship)
	estimated_mb += active_ships * 1.0
	
	# Add effect memory estimates (approximately 100KB per active effect)
	estimated_mb += active_effects * 0.1
	
	# Add physics memory estimates
	estimated_mb += ship_count * 0.5  # Physics bodies
	
	# Add audio memory estimates
	estimated_mb += active_effects * 0.05  # Audio instances
	
	return estimated_mb

## Update system-specific performance metrics
func _update_system_metrics() -> void:
	# These would be updated by the respective systems
	# For now, we provide default values
	
	# Ship metrics (would be provided by ShipManager)
	ship_count = _count_total_ships()
	active_ships = _count_active_ships()
	ships_in_view = _count_ships_in_view()
	ships_updating = active_ships  # Estimate
	ships_culled = ship_count - ships_in_view
	
	# Effect metrics (would be provided by EffectManager)
	effect_count = _count_total_effects()
	active_effects = _count_active_effects()
	rendered_effects = _count_rendered_effects()
	culled_effects = effect_count - rendered_effects
	pooled_effects = _count_pooled_effects()

## Update hardware performance metrics (estimated)
func _update_hardware_metrics() -> void:
	# Estimate CPU usage based on frame time
	var target_frame_time: float = 1000.0 / target_fps
	cpu_usage_percent = min(100.0, (frame_time_ms / target_frame_time) * 100.0)
	
	# Estimate GPU usage based on rendering load
	gpu_usage_percent = min(100.0, (rendered_effects + ships_in_view) * 2.0)
	
	# Thread time estimates
	main_thread_time_ms = frame_time_ms * 0.6  # Most work on main thread
	physics_thread_time_ms = frame_time_ms * 0.2  # Physics on separate thread
	render_thread_time_ms = frame_time_ms * 0.2  # Rendering work
	
	_add_sample(cpu_samples, cpu_usage_percent)

## Detect performance bottlenecks in systems
func _detect_bottlenecks() -> void:
	if not bottleneck_detection_enabled:
		return
	
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	
	for system_name in system_performance_trackers.keys():
		var tracker: Dictionary = system_performance_trackers[system_name]
		var threshold: float = bottleneck_thresholds[system_name]
		var current_system_time: float = tracker.get("current_time", 0.0)
		
		# Check if system is exceeding threshold
		if current_system_time > threshold:
			tracker["peak_time"] = max(tracker["peak_time"], current_system_time)
			tracker["warning_count"] += 1
			
			# Emit bottleneck warning (rate limited)
			if current_time - tracker.get("last_warning_time", 0.0) > 1.0:
				var severity: float = current_system_time / threshold
				var details: Dictionary = {
					"current_time_ms": current_system_time,
					"threshold_ms": threshold,
					"peak_time_ms": tracker["peak_time"],
					"warning_count": tracker["warning_count"]
				}
				
				bottleneck_detected.emit(system_name, severity, details)
				tracker["last_warning_time"] = current_time

## Check performance thresholds and emit warnings
func _check_performance_thresholds() -> void:
	# Frame rate warnings
	if current_fps < target_fps * 0.9:  # 10% below target
		var duration: float = _calculate_low_fps_duration()
		if duration > 1.0:  # Low FPS for more than 1 second
			frame_rate_warning.emit(current_fps, target_fps, duration)
	
	# Memory warnings
	if memory_usage_mb > memory_warning_threshold_mb:
		memory_warning.emit(memory_usage_mb, memory_warning_threshold_mb, memory_growth_rate)
	
	# Critical memory check
	if memory_usage_mb > memory_critical_threshold_mb:
		performance_threshold_exceeded.emit("memory_critical", memory_usage_mb, memory_critical_threshold_mb)

## Record system performance timing (called by other systems)
func record_system_performance(system_name: String, time_ms: float) -> void:
	if not system_performance_trackers.has(system_name):
		return
	
	var tracker: Dictionary = system_performance_trackers[system_name]
	tracker["current_time"] = time_ms
	
	# Add to samples for trending analysis
	var samples: Array = tracker.get("samples", [])
	samples.append(time_ms)
	if samples.size() > sample_window_size:
		samples.pop_front()
	tracker["samples"] = samples

## Get comprehensive performance statistics
func get_performance_statistics() -> Dictionary:
	return {
		# Frame rate metrics
		"current_fps": current_fps,
		"average_fps": average_fps,
		"minimum_fps": minimum_fps,
		"target_fps": target_fps,
		"frame_time_ms": frame_time_ms,
		
		# Memory metrics
		"memory_usage_mb": memory_usage_mb,
		"memory_peak_mb": memory_peak_mb,
		"memory_growth_rate": memory_growth_rate,
		"memory_warning_threshold": memory_warning_threshold_mb,
		"memory_critical_threshold": memory_critical_threshold_mb,
		
		# System metrics
		"ship_count": ship_count,
		"active_ships": active_ships,
		"ships_in_view": ships_in_view,
		"ships_updating": ships_updating,
		"ships_culled": ships_culled,
		"effect_count": effect_count,
		"active_effects": active_effects,
		"rendered_effects": rendered_effects,
		"culled_effects": culled_effects,
		"pooled_effects": pooled_effects,
		
		# Hardware metrics
		"cpu_usage_percent": cpu_usage_percent,
		"gpu_usage_percent": gpu_usage_percent,
		"main_thread_time_ms": main_thread_time_ms,
		"physics_thread_time_ms": physics_thread_time_ms,
		"render_thread_time_ms": render_thread_time_ms,
		
		# Analysis
		"bottlenecks": _get_current_bottlenecks(),
		"recommendations": _get_optimization_recommendations()
	}

## Get current system bottlenecks
func _get_current_bottlenecks() -> Array[Dictionary]:
	var bottlenecks: Array[Dictionary] = []
	
	for system_name in system_performance_trackers.keys():
		var tracker: Dictionary = system_performance_trackers[system_name]
		var threshold: float = bottleneck_thresholds[system_name]
		var current_time: float = tracker.get("current_time", 0.0)
		
		if current_time > threshold:
			bottlenecks.append({
				"system": system_name,
				"current_time_ms": current_time,
				"threshold_ms": threshold,
				"severity": current_time / threshold,
				"warning_count": tracker.get("warning_count", 0)
			})
	
	return bottlenecks

## Get optimization recommendations based on current performance
func _get_optimization_recommendations() -> Array[String]:
	var recommendations: Array[String] = []
	
	# Frame rate recommendations
	if average_fps < target_fps * 0.9:
		recommendations.append("Consider reducing visual quality settings")
		recommendations.append("Enable aggressive object culling")
	
	# Memory recommendations
	if memory_usage_mb > memory_warning_threshold_mb:
		recommendations.append("Enable object pooling for effects")
		recommendations.append("Reduce effect particle counts")
	
	# CPU recommendations
	if cpu_usage_percent > 80.0:
		recommendations.append("Reduce ship update frequency for distant objects")
		recommendations.append("Enable level-of-detail (LOD) scaling")
	
	# System-specific recommendations
	var bottlenecks: Array[Dictionary] = _get_current_bottlenecks()
	for bottleneck in bottlenecks:
		var system: String = bottleneck["system"]
		match system:
			"ship_update":
				recommendations.append("Reduce ship update frequency")
			"weapon_processing":
				recommendations.append("Limit simultaneous weapon effects")
			"effect_rendering":
				recommendations.append("Enable effect culling and LOD")
			"physics_simulation":
				recommendations.append("Reduce physics simulation quality")
	
	return recommendations

# Utility functions for metric calculation

func _add_sample(samples: Array, value: float) -> void:
	samples.pop_front()
	samples.append(value)

func _calculate_average(samples: Array) -> float:
	if samples.is_empty():
		return 0.0
	
	var sum: float = 0.0
	for sample in samples:
		sum += sample
	return sum / samples.size()

func _calculate_minimum(samples: Array) -> float:
	if samples.is_empty():
		return 0.0
	
	var minimum: float = samples[0]
	for sample in samples:
		if sample < minimum:
			minimum = sample
	return minimum

func _calculate_low_fps_duration() -> float:
	var low_fps_count: int = 0
	var threshold: float = target_fps * 0.9
	
	for fps_sample in fps_samples:
		if fps_sample < threshold:
			low_fps_count += 1
	
	return (low_fps_count / float(sample_window_size)) * update_frequency * sample_window_size

# Mock functions for system counting (would be replaced by actual system integration)

func _count_total_ships() -> int:
	# Mock implementation - would integrate with ObjectManager
	return 0

func _count_active_ships() -> int:
	# Mock implementation - would integrate with ShipManager
	return 0

func _count_ships_in_view() -> int:
	# Mock implementation - would integrate with Camera/Culling system
	return 0

func _count_total_effects() -> int:
	# Mock implementation - would integrate with EffectManager
	return 0

func _count_active_effects() -> int:
	# Mock implementation - would integrate with EffectManager
	return 0

func _count_rendered_effects() -> int:
	# Mock implementation - would integrate with Renderer
	return 0

func _count_pooled_effects() -> int:
	# Mock implementation - would integrate with ObjectPool
	return 0

## Public API for external systems

## Start performance monitoring
func start_monitoring() -> void:
	monitoring_active = true
	print("PerformanceMonitor: Performance monitoring started")

## Stop performance monitoring
func stop_monitoring() -> void:
	monitoring_active = false
	print("PerformanceMonitor: Performance monitoring stopped")

## Set performance monitoring frequency
func set_update_frequency(frequency: float) -> void:
	update_frequency = max(0.01, frequency)  # Minimum 100Hz
	print("PerformanceMonitor: Update frequency set to %.2f Hz" % (1.0 / update_frequency))

## Set target frame rate
func set_target_fps(fps: float) -> void:
	target_fps = max(30.0, fps)
	print("PerformanceMonitor: Target FPS set to %.1f" % target_fps)

## Enable/disable bottleneck detection
func set_bottleneck_detection(enabled: bool) -> void:
	bottleneck_detection_enabled = enabled
	print("PerformanceMonitor: Bottleneck detection %s" % ("enabled" if enabled else "disabled"))

## Add performance log entry
func log_performance_event(event_type: String, details: Dictionary) -> void:
	var log_entry: Dictionary = {
		"timestamp": Time.get_ticks_usec() / 1000000.0,
		"event_type": event_type,
		"details": details,
		"performance_snapshot": get_performance_statistics()
	}
	
	performance_log.append(log_entry)
	
	# Limit log size
	if performance_log.size() > max_log_entries:
		performance_log.pop_front()

## Get performance log for analysis
func get_performance_log() -> Array[Dictionary]:
	return performance_log.duplicate()

## Clear performance log
func clear_performance_log() -> void:
	performance_log.clear()
	print("PerformanceMonitor: Performance log cleared")