class_name TargetTrackingOptimizer
extends RefCounted

## EPIC-012 HUD-005: Target Tracking Optimizer
## Optimizes target switching, tracking performance, and display updates

signal tracking_optimized(optimizations: Dictionary)
signal target_switch_optimized(old_target: String, new_target: String, duration: float)
signal performance_threshold_reached(metric: String, value: float)

# Optimization configuration
@export var max_tracked_targets: int = 10
@export var update_frequency_base: float = 60.0
@export var adaptive_frequency: bool = true
@export var distance_based_lod: bool = true
@export var performance_monitoring: bool = true

# Performance metrics
var tracking_metrics: Dictionary = {
	"update_times": [],
	"frame_times": [],
	"memory_usage": [],
	"cpu_usage": [],
	"target_switch_times": []
}

# Target tracking data
var tracked_targets: Dictionary = {}
var target_priorities: Dictionary = {}
var update_frequencies: Dictionary = {}
var last_update_times: Dictionary = {}

# Performance thresholds
var performance_thresholds: Dictionary = {
	"max_update_time": 5.0,  # milliseconds
	"max_frame_time": 16.67,  # 60 FPS target
	"max_memory_usage": 100.0,  # MB
	"max_target_switch_time": 100.0  # milliseconds
}

# LOD (Level of Detail) settings
var lod_settings: Dictionary = {
	"close_range": {"distance": 500.0, "frequency": 60.0, "detail": "high"},
	"medium_range": {"distance": 2000.0, "frequency": 30.0, "detail": "medium"},
	"long_range": {"distance": 5000.0, "frequency": 15.0, "detail": "low"},
	"extreme_range": {"distance": 10000.0, "frequency": 5.0, "detail": "minimal"}
}

func _init() -> void:
	print("TargetTrackingOptimizer: Initialized")

## Optimize target tracking for a given target
func optimize_target_tracking(target: Node, player: Node) -> Dictionary:
	if not target or not player:
		return {}
	
	var target_id = _get_target_id(target)
	var optimization_start_time = Time.get_ticks_msec()
	
	# Calculate optimal update frequency
	var optimal_frequency = _calculate_optimal_frequency(target, player)
	
	# Determine LOD level
	var lod_level = _determine_lod_level(target, player)
	
	# Calculate priority score
	var priority_score = _calculate_target_priority(target, player)
	
	# Apply optimizations
	var optimizations = {
		"target_id": target_id,
		"update_frequency": optimal_frequency,
		"lod_level": lod_level,
		"priority_score": priority_score,
		"detail_level": lod_settings[lod_level]["detail"],
		"optimization_time": Time.get_ticks_msec() - optimization_start_time
	}
	
	# Store optimization data
	update_frequencies[target_id] = optimal_frequency
	target_priorities[target_id] = priority_score
	last_update_times[target_id] = Time.get_time_dict_from_system()["unix"]
	
	tracking_optimized.emit(optimizations)
	
	print("TargetTrackingOptimizer: Optimized tracking for %s - Frequency: %.1f Hz, Priority: %d" % [
		target_id, optimal_frequency, priority_score
	])
	
	return optimizations

## Optimize target switching performance
func optimize_target_switch(old_target: Node, new_target: Node) -> Dictionary:
	var switch_start_time = Time.get_ticks_msec()
	
	var old_target_id = _get_target_id(old_target) if old_target else "none"
	var new_target_id = _get_target_id(new_target) if new_target else "none"
	
	# Pre-cache new target data if not already cached
	if new_target and not tracked_targets.has(new_target_id):
		_precache_target_data(new_target)
	
	# Optimize transition animation
	var transition_duration = _calculate_optimal_transition_duration(old_target, new_target)
	
	# Apply memory optimization
	if old_target:
		_optimize_old_target_memory(old_target_id)
	
	var switch_duration = Time.get_ticks_msec() - switch_start_time
	
	# Record metrics
	tracking_metrics["target_switch_times"].append(switch_duration)
	_trim_metrics_array("target_switch_times")
	
	# Check performance threshold
	if switch_duration > performance_thresholds["max_target_switch_time"]:
		performance_threshold_reached.emit("target_switch_time", switch_duration)
	
	var optimization_result = {
		"old_target_id": old_target_id,
		"new_target_id": new_target_id,
		"switch_duration": switch_duration,
		"transition_duration": transition_duration,
		"precached": new_target and tracked_targets.has(new_target_id)
	}
	
	target_switch_optimized.emit(old_target_id, new_target_id, switch_duration)
	
	print("TargetTrackingOptimizer: Target switch optimized in %.1f ms" % switch_duration)
	
	return optimization_result

## Calculate optimal update frequency for target
func _calculate_optimal_frequency(target: Node, player: Node) -> float:
	var base_frequency = update_frequency_base
	
	if not adaptive_frequency:
		return base_frequency
	
	# Distance-based frequency adjustment
	var distance = _calculate_distance(target, player)
	var lod_level = _determine_lod_level_by_distance(distance)
	var distance_modifier = lod_settings[lod_level]["frequency"] / update_frequency_base
	
	# Threat-based frequency adjustment
	var threat_modifier = _calculate_threat_modifier(target)
	
	# Movement-based frequency adjustment
	var movement_modifier = _calculate_movement_modifier(target)
	
	# Player focus modifier (is this the current target?)
	var focus_modifier = _calculate_focus_modifier(target, player)
	
	# Combine all modifiers
	var optimal_frequency = base_frequency * distance_modifier * threat_modifier * movement_modifier * focus_modifier
	
	# Clamp to reasonable range
	return clampf(optimal_frequency, 1.0, 120.0)

## Determine LOD level based on distance and importance
func _determine_lod_level(target: Node, player: Node) -> String:
	if not distance_based_lod:
		return "medium_range"
	
	var distance = _calculate_distance(target, player)
	return _determine_lod_level_by_distance(distance)

func _determine_lod_level_by_distance(distance: float) -> String:
	if distance <= lod_settings["close_range"]["distance"]:
		return "close_range"
	elif distance <= lod_settings["medium_range"]["distance"]:
		return "medium_range"
	elif distance <= lod_settings["long_range"]["distance"]:
		return "long_range"
	else:
		return "extreme_range"

## Calculate target priority score
func _calculate_target_priority(target: Node, player: Node) -> int:
	var priority = 5  # Base priority
	
	# Distance factor (closer = higher priority)
	var distance = _calculate_distance(target, player)
	if distance < 500.0:
		priority += 3
	elif distance < 1500.0:
		priority += 2
	elif distance < 3000.0:
		priority += 1
	else:
		priority -= 1
	
	# Threat factor
	var threat_level = _get_threat_level(target)
	priority += threat_level
	
	# Mission relevance
	if target.has_method("get_mission_priority"):
		priority += target.get_mission_priority()
	
	# Player target status
	if _is_current_target(target, player):
		priority += 3
	
	# Hostility factor
	if _is_hostile(target):
		priority += 2
	
	return clampi(priority, 1, 10)

## Calculate threat modifier for frequency
func _calculate_threat_modifier(target: Node) -> float:
	var threat_level = _get_threat_level(target)
	match threat_level:
		0: return 0.5  # Minimal threat
		1: return 0.8  # Low threat
		2: return 1.0  # Moderate threat
		3: return 1.3  # High threat
		4: return 1.5  # Extreme threat
		_: return 1.0

## Calculate movement modifier for frequency
func _calculate_movement_modifier(target: Node) -> float:
	var velocity = _get_velocity(target)
	var speed = velocity.length()
	
	if speed < 10.0:
		return 0.7  # Nearly stationary
	elif speed < 50.0:
		return 1.0  # Slow moving
	elif speed < 150.0:
		return 1.2  # Fast moving
	else:
		return 1.5  # Very fast moving

## Calculate focus modifier (is target currently selected?)
func _calculate_focus_modifier(target: Node, player: Node) -> float:
	if _is_current_target(target, player):
		return 2.0  # Current target gets high priority
	else:
		return 1.0  # Other targets get normal priority

## Pre-cache target data for smooth switching
func _precache_target_data(target: Node) -> void:
	var target_id = _get_target_id(target)
	
	# Basic data that's expensive to compute
	var cached_data = {
		"basic_info": {
			"name": _safe_call(target, "get_ship_name", target.name),
			"class": _safe_call(target, "get_ship_class", "Unknown"),
			"type": _safe_call(target, "get_ship_type", "Unknown")
		},
		"position_data": {
			"position": _safe_call(target, "get_global_position", Vector3.ZERO),
			"velocity": _safe_call(target, "get_velocity", Vector3.ZERO)
		},
		"status_data": {
			"hull_percentage": _safe_call(target, "get_hull_percentage", 100.0),
			"shield_percentage": _safe_call(target, "get_shield_percentage", 0.0)
		},
		"cache_time": Time.get_time_dict_from_system()["unix"]
	}
	
	tracked_targets[target_id] = cached_data
	print("TargetTrackingOptimizer: Pre-cached data for target %s" % target_id)

## Calculate optimal transition duration
func _calculate_optimal_transition_duration(old_target: Node, new_target: Node) -> float:
	# Base transition time
	var base_duration = 0.2
	
	# If switching between similar targets, faster transition
	if old_target and new_target:
		var old_class = _safe_call(old_target, "get_ship_class", "")
		var new_class = _safe_call(new_target, "get_ship_class", "")
		
		if old_class == new_class:
			base_duration *= 0.7
	
	# If targets are close together, faster transition
	if old_target and new_target:
		var old_pos = _safe_call(old_target, "get_global_position", Vector3.ZERO)
		var new_pos = _safe_call(new_target, "get_global_position", Vector3.ZERO)
		var distance_between = old_pos.distance_to(new_pos)
		
		if distance_between < 1000.0:
			base_duration *= 0.8
	
	return clampf(base_duration, 0.1, 0.5)

## Optimize memory usage for old target
func _optimize_old_target_memory(target_id: String) -> void:
	# Keep some data cached but reduce detail
	if tracked_targets.has(target_id):
		var cached_data = tracked_targets[target_id]
		
		# Keep only essential data
		var optimized_data = {
			"basic_info": cached_data.get("basic_info", {}),
			"last_known_position": cached_data.get("position_data", {}).get("position", Vector3.ZERO),
			"cache_time": cached_data.get("cache_time", 0.0),
			"optimized": true
		}
		
		tracked_targets[target_id] = optimized_data

## Performance monitoring
func monitor_performance() -> Dictionary:
	if not performance_monitoring:
		return {}
	
	var current_metrics = {
		"frame_time": Engine.get_frames_per_second(),
		"memory_usage": _estimate_memory_usage(),
		"tracked_targets_count": tracked_targets.size(),
		"active_update_frequencies": update_frequencies.size()
	}
	
	# Check thresholds
	for metric in performance_thresholds:
		if current_metrics.has(metric):
			var value = current_metrics[metric]
			if value > performance_thresholds[metric]:
				performance_threshold_reached.emit(metric, value)
	
	# Store metrics
	tracking_metrics["frame_times"].append(current_metrics["frame_time"])
	tracking_metrics["memory_usage"].append(current_metrics["memory_usage"])
	
	# Trim old metrics
	_trim_metrics_array("frame_times")
	_trim_metrics_array("memory_usage")
	
	return current_metrics

## Cleanup and optimization
func cleanup_stale_targets() -> int:
	var current_time = Time.get_time_dict_from_system()["unix"]
	var cleanup_threshold = 30.0  # 30 seconds
	var removed_count = 0
	
	var to_remove: Array[String] = []
	
	for target_id in tracked_targets:
		var cached_data = tracked_targets[target_id]
		var cache_time = cached_data.get("cache_time", 0.0)
		
		if current_time - cache_time > cleanup_threshold:
			to_remove.append(target_id)
	
	# Remove stale targets
	for target_id in to_remove:
		tracked_targets.erase(target_id)
		target_priorities.erase(target_id)
		update_frequencies.erase(target_id)
		last_update_times.erase(target_id)
		removed_count += 1
	
	if removed_count > 0:
		print("TargetTrackingOptimizer: Cleaned up %d stale targets" % removed_count)
	
	return removed_count

## Utility functions
func _get_target_id(target: Node) -> String:
	return str(target.get_instance_id())

func _calculate_distance(target: Node, player: Node) -> float:
	if target.has_method("get_global_position") and player.has_method("get_global_position"):
		return target.get_global_position().distance_to(player.get_global_position())
	else:
		return 1000.0

func _get_velocity(target: Node) -> Vector3:
	return _safe_call(target, "get_velocity", Vector3.ZERO)

func _get_threat_level(target: Node) -> int:
	return _safe_call(target, "get_threat_level", 1)

func _is_current_target(target: Node, player: Node) -> bool:
	if player.has_method("get_current_target"):
		return player.get_current_target() == target
	else:
		return false

func _is_hostile(target: Node) -> bool:
	var hostility = _safe_call(target, "get_hostility_status", "unknown")
	return hostility == "hostile"

func _safe_call(target: Node, method_name: String, default_value) -> Variant:
	if target.has_method(method_name):
		return target.call(method_name)
	else:
		return default_value

func _estimate_memory_usage() -> float:
	# Simplified memory estimation
	var base_usage = tracked_targets.size() * 5.0  # 5KB per target estimate
	return base_usage

func _trim_metrics_array(array_name: String, max_size: int = 60) -> void:
	if tracking_metrics.has(array_name):
		var array = tracking_metrics[array_name]
		while array.size() > max_size:
			array.pop_front()

## Public interface
func get_optimization_for_target(target_id: String) -> Dictionary:
	return {
		"update_frequency": update_frequencies.get(target_id, update_frequency_base),
		"priority": target_priorities.get(target_id, 5),
		"last_update": last_update_times.get(target_id, 0.0)
	}

func get_performance_metrics() -> Dictionary:
	return tracking_metrics.duplicate()

func get_tracking_statistics() -> Dictionary:
	return {
		"tracked_targets_count": tracked_targets.size(),
		"active_frequencies": update_frequencies.size(),
		"total_cache_size": tracked_targets.size(),
		"average_priority": _calculate_average_priority()
	}

func _calculate_average_priority() -> float:
	if target_priorities.is_empty():
		return 5.0
	
	var total = 0.0
	for priority in target_priorities.values():
		total += priority
	
	return total / target_priorities.size()

func clear_all_optimizations() -> void:
	tracked_targets.clear()
	target_priorities.clear()
	update_frequencies.clear()
	last_update_times.clear()
	tracking_metrics = {
		"update_times": [],
		"frame_times": [],
		"memory_usage": [],
		"cpu_usage": [],
		"target_switch_times": []
	}
	print("TargetTrackingOptimizer: All optimizations cleared")
