class_name RadarPerformanceOptimizer
extends RefCounted

## HUD-009 Component 5: Radar Performance Optimizer
## Monitors and optimizes radar display performance for complex battlefield scenarios
## Provides Level-of-Detail (LOD) systems and efficient rendering optimizations

signal performance_level_changed(new_level: String)
signal optimization_applied(optimization_type: String)
signal performance_warning(warning_message: String)

# Performance monitoring
var current_performance_level: String = "high"
var target_fps: float = 60.0
var current_fps: float = 60.0
var frame_time_ms: float = 16.67  # Target ~60 FPS
var render_time_ms: float = 0.0

# Performance thresholds
var performance_thresholds: Dictionary = {
	"high": {"min_fps": 55.0, "max_frame_time": 18.0, "max_contacts": 200},
	"medium": {"min_fps": 45.0, "max_frame_time": 22.0, "max_contacts": 100},
	"low": {"min_fps": 30.0, "max_frame_time": 33.0, "max_contacts": 50},
	"minimal": {"min_fps": 20.0, "max_frame_time": 50.0, "max_contacts": 25}
}

# LOD (Level of Detail) system
var lod_enabled: bool = true
var lod_distances: Dictionary = {
	"full": 2000.0,      # Full detail within 2km
	"high": 5000.0,      # High detail within 5km  
	"medium": 15000.0,   # Medium detail within 15km
	"low": 30000.0,      # Low detail within 30km
	"minimal": 100000.0  # Minimal detail beyond 30km
}

# Contact management optimization
var max_rendered_contacts: int = 200
var max_processed_contacts: int = 500
var contact_update_frequency: float = 30.0  # Hz
var contact_culling_enabled: bool = true

# Spatial partitioning optimization
var spatial_partitioning_enabled: bool = true
var partition_grid_size: float = 5000.0
var max_partitions_per_frame: int = 4

# Rendering optimizations
var use_contact_pooling: bool = true
var batch_rendering_enabled: bool = true
var icon_caching_enabled: bool = true
var update_batching_enabled: bool = true

# Memory management
var memory_cleanup_interval: float = 5.0
var last_cleanup_time: float = 0.0
var memory_pressure_threshold: int = 1000  # Number of active objects

# Performance statistics
var frame_times: Array[float] = []
var max_frame_time_samples: int = 30
var average_frame_time: float = 16.67
var worst_frame_time: float = 16.67
var performance_warnings_count: int = 0

# Optimization state
var active_optimizations: Array[String] = []
var automatic_optimization: bool = true
var performance_monitoring_enabled: bool = true

func _init():
	_initialize_performance_optimizer()

func _initialize_performance_optimizer() -> void:
	print("RadarPerformanceOptimizer: Initializing performance optimization system...")
	
	# Initialize frame time tracking
	frame_times.resize(max_frame_time_samples)
	frame_times.fill(16.67)
	
	# Set initial optimization level
	_apply_performance_level("high")
	
	print("RadarPerformanceOptimizer: Performance optimization system initialized")

## Setup performance monitoring
func setup_performance_monitoring() -> void:
	performance_monitoring_enabled = true
	print("RadarPerformanceOptimizer: Performance monitoring enabled")

## Monitor radar performance and apply optimizations
func monitor_performance(render_time: float, contact_count: int) -> void:
	if not performance_monitoring_enabled:
		return
	
	# Update performance metrics
	render_time_ms = render_time
	_update_frame_time_statistics(render_time)
	
	# Calculate current FPS from render time
	current_fps = 1000.0 / max(render_time, 1.0) if render_time > 0 else 60.0
	
	# Determine required performance level
	var required_level = _determine_required_performance_level(current_fps, contact_count)
	
	# Apply performance adjustments if needed
	if required_level != current_performance_level:
		_apply_performance_level(required_level)
	
	# Check for specific optimizations needed
	_check_and_apply_optimizations(contact_count)
	
	# Memory cleanup if needed
	_check_memory_cleanup()

## Update frame time statistics
func _update_frame_time_statistics(frame_time: float) -> void:
	# Shift array and add new sample
	for i in range(frame_times.size() - 1):
		frame_times[i] = frame_times[i + 1]
	frame_times[frame_times.size() - 1] = frame_time
	
	# Calculate average
	var sum = 0.0
	worst_frame_time = 0.0
	for time in frame_times:
		sum += time
		worst_frame_time = max(worst_frame_time, time)
	average_frame_time = sum / frame_times.size()

## Determine required performance level based on current metrics
func _determine_required_performance_level(fps: float, contact_count: int) -> String:
	# Check from most demanding to least demanding
	for level in ["high", "medium", "low", "minimal"]:
		var threshold = performance_thresholds[level]
		if fps >= threshold.min_fps and contact_count <= threshold.max_contacts:
			return level
	
	return "minimal"  # Fallback to minimal performance

## Apply performance level optimizations
func _apply_performance_level(level: String) -> void:
	if level == current_performance_level:
		return
	
	var old_level = current_performance_level
	current_performance_level = level
	
	var threshold = performance_thresholds[level]
	
	# Adjust contact limits
	max_rendered_contacts = threshold.max_contacts
	
	# Adjust LOD distances based on performance level
	match level:
		"high":
			_set_lod_quality(1.0)
			contact_update_frequency = 30.0
			spatial_partitioning_enabled = true
		"medium":
			_set_lod_quality(0.8)
			contact_update_frequency = 20.0
			spatial_partitioning_enabled = true
		"low":
			_set_lod_quality(0.6)
			contact_update_frequency = 15.0
			spatial_partitioning_enabled = true
		"minimal":
			_set_lod_quality(0.4)
			contact_update_frequency = 10.0
			spatial_partitioning_enabled = false
	
	performance_level_changed.emit(current_performance_level)
	print("RadarPerformanceOptimizer: Performance level changed from '%s' to '%s'" % [old_level, current_performance_level])

## Set LOD quality multiplier
func _set_lod_quality(quality: float) -> void:
	var base_distances = {
		"full": 2000.0,
		"high": 5000.0,
		"medium": 15000.0,
		"low": 30000.0,
		"minimal": 100000.0
	}
	
	for level in base_distances.keys():
		lod_distances[level] = base_distances[level] * quality

## Check and apply specific optimizations
func _check_and_apply_optimizations(contact_count: int) -> void:
	# Contact culling optimization
	if contact_count > max_rendered_contacts * 1.5 and not "contact_culling" in active_optimizations:
		_apply_optimization("contact_culling")
	
	# Batch rendering optimization
	if contact_count > 50 and not "batch_rendering" in active_optimizations:
		_apply_optimization("batch_rendering")
	
	# Update frequency reduction
	if average_frame_time > 25.0 and not "reduced_updates" in active_optimizations:
		_apply_optimization("reduced_updates")
	
	# Icon simplification
	if contact_count > 100 and not "simplified_icons" in active_optimizations:
		_apply_optimization("simplified_icons")

## Apply specific optimization
func _apply_optimization(optimization_type: String) -> void:
	if optimization_type in active_optimizations:
		return
	
	active_optimizations.append(optimization_type)
	
	match optimization_type:
		"contact_culling":
			contact_culling_enabled = true
			max_rendered_contacts = min(max_rendered_contacts, 100)
		
		"batch_rendering":
			batch_rendering_enabled = true
			update_batching_enabled = true
		
		"reduced_updates":
			contact_update_frequency = max(contact_update_frequency * 0.7, 5.0)
		
		"simplified_icons":
			icon_caching_enabled = true
			# Would trigger simplified icon rendering in the renderer
		
		"spatial_partitioning":
			spatial_partitioning_enabled = true
			partition_grid_size = 3000.0  # Smaller partitions for better culling
		
		"memory_optimization":
			use_contact_pooling = true
			memory_cleanup_interval = 2.0  # More frequent cleanup
	
	optimization_applied.emit(optimization_type)
	print("RadarPerformanceOptimizer: Applied optimization '%s'" % optimization_type)

## Remove optimization
func _remove_optimization(optimization_type: String) -> void:
	if not optimization_type in active_optimizations:
		return
	
	active_optimizations.erase(optimization_type)
	
	match optimization_type:
		"contact_culling":
			contact_culling_enabled = false
		
		"batch_rendering":
			batch_rendering_enabled = false
			update_batching_enabled = false
		
		"reduced_updates":
			contact_update_frequency = 30.0  # Reset to normal
		
		"simplified_icons":
			icon_caching_enabled = false
		
		"spatial_partitioning":
			spatial_partitioning_enabled = false
	
	print("RadarPerformanceOptimizer: Removed optimization '%s'" % optimization_type)

## Check if memory cleanup is needed
func _check_memory_cleanup() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	if current_time - last_cleanup_time > memory_cleanup_interval:
		_perform_memory_cleanup()
		last_cleanup_time = current_time

## Perform memory cleanup
func _perform_memory_cleanup() -> void:
	# This would trigger cleanup in the radar system
	# For now, just apply memory optimization if needed
	if not "memory_optimization" in active_optimizations:
		_apply_optimization("memory_optimization")

## Get LOD level for distance
func get_lod_level_for_distance(distance: float) -> String:
	if distance <= lod_distances.full:
		return "full"
	elif distance <= lod_distances.high:
		return "high"
	elif distance <= lod_distances.medium:
		return "medium"
	elif distance <= lod_distances.low:
		return "low"
	else:
		return "minimal"

## Check if contact should be rendered at distance
func should_render_contact_at_distance(distance: float, priority: int = 1) -> bool:
	if not lod_enabled:
		return true
	
	var lod_level = get_lod_level_for_distance(distance)
	
	# Priority-based rendering decisions
	match lod_level:
		"full", "high":
			return true
		"medium":
			return priority >= 1  # Normal and high priority
		"low":
			return priority >= 2  # High priority only
		"minimal":
			return priority >= 3  # Critical priority only
		_:
			return false

## Get maximum contacts for current performance level
func get_max_contacts_for_performance() -> int:
	return max_rendered_contacts

## Get update frequency for current performance level
func get_update_frequency() -> float:
	return contact_update_frequency

## Check if spatial partitioning should be used
func should_use_spatial_partitioning() -> bool:
	return spatial_partitioning_enabled

## Get spatial partition size
func get_spatial_partition_size() -> float:
	return partition_grid_size

## Check if contact pooling should be used
func should_use_contact_pooling() -> bool:
	return use_contact_pooling

## Check if batch rendering should be used
func should_use_batch_rendering() -> bool:
	return batch_rendering_enabled

## Get performance statistics
func get_performance_statistics() -> Dictionary:
	return {
		"current_level": current_performance_level,
		"current_fps": current_fps,
		"average_frame_time": average_frame_time,
		"worst_frame_time": worst_frame_time,
		"render_time_ms": render_time_ms,
		"max_rendered_contacts": max_rendered_contacts,
		"contact_update_frequency": contact_update_frequency,
		"active_optimizations": active_optimizations.duplicate(),
		"lod_enabled": lod_enabled,
		"warnings_count": performance_warnings_count
	}

## Get current performance level
func get_performance_level() -> String:
	return current_performance_level

## Get LOD distances
func get_lod_distances() -> Dictionary:
	return lod_distances.duplicate()

## Force performance level (disable automatic optimization)
func force_performance_level(level: String) -> void:
	if level in performance_thresholds:
		automatic_optimization = false
		_apply_performance_level(level)
		print("RadarPerformanceOptimizer: Forced performance level to '%s'" % level)

## Enable automatic optimization
func enable_automatic_optimization() -> void:
	automatic_optimization = true
	print("RadarPerformanceOptimizer: Automatic optimization enabled")

## Set custom LOD distances
func set_lod_distances(distances: Dictionary) -> void:
	for level in distances.keys():
		if level in lod_distances:
			lod_distances[level] = distances[level]

## Set performance thresholds
func set_performance_thresholds(thresholds: Dictionary) -> void:
	for level in thresholds.keys():
		if level in performance_thresholds:
			performance_thresholds[level] = thresholds[level]

## Enable/disable LOD system
func set_lod_enabled(enabled: bool) -> void:
	lod_enabled = enabled
	if enabled:
		print("RadarPerformanceOptimizer: LOD system enabled")
	else:
		print("RadarPerformanceOptimizer: LOD system disabled")

## Set target FPS
func set_target_fps(fps: float) -> void:
	target_fps = clamp(fps, 20.0, 120.0)
	frame_time_ms = 1000.0 / target_fps

## Issue performance warning
func _issue_performance_warning(message: String) -> void:
	performance_warnings_count += 1
	performance_warning.emit(message)
	print("RadarPerformanceOptimizer: WARNING - %s" % message)

## Check for performance issues
func check_performance_health() -> Dictionary:
	var issues: Array[String] = []
	var status = "good"
	
	if current_fps < target_fps * 0.8:
		issues.append("FPS below target (%.1f < %.1f)" % [current_fps, target_fps])
		status = "poor"
	
	if average_frame_time > frame_time_ms * 1.3:
		issues.append("High average frame time (%.1fms)" % average_frame_time)
		if status == "good":
			status = "warning"
	
	if worst_frame_time > frame_time_ms * 2.0:
		issues.append("Frame time spikes detected (%.1fms)" % worst_frame_time)
		if status == "good":
			status = "warning"
	
	if active_optimizations.size() > 3:
		issues.append("Multiple optimizations active (%d)" % active_optimizations.size())
		if status == "good":
			status = "warning"
	
	return {
		"status": status,
		"issues": issues,
		"recommendations": _get_performance_recommendations(issues)
	}

## Get performance recommendations
func _get_performance_recommendations(issues: Array[String]) -> Array[String]:
	var recommendations: Array[String] = []
	
	if current_fps < target_fps * 0.8:
		recommendations.append("Consider reducing max contacts or enabling more aggressive LOD")
	
	if average_frame_time > frame_time_ms * 1.3:
		recommendations.append("Enable spatial partitioning and contact culling")
	
	if not "batch_rendering" in active_optimizations:
		recommendations.append("Enable batch rendering for better performance")
	
	if not spatial_partitioning_enabled and current_performance_level in ["low", "minimal"]:
		recommendations.append("Enable spatial partitioning to reduce processing load")
	
	return recommendations

## Reset performance optimizer to defaults
func reset_to_defaults() -> void:
	current_performance_level = "high"
	automatic_optimization = true
	active_optimizations.clear()
	lod_enabled = true
	performance_monitoring_enabled = true
	
	# Reset to default values
	_apply_performance_level("high")
	
	print("RadarPerformanceOptimizer: Reset to default settings")
