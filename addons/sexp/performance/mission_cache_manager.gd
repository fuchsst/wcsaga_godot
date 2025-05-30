class_name MissionCacheManager
extends RefCounted

## Mission Cache Manager for SEXP-009
##
## Manages cache lifecycle during long-running missions, providing automatic
## cleanup, memory management, and performance optimization tailored for
## mission progression and memory usage patterns.

signal memory_warning(usage_mb: float, threshold_mb: float)
signal cache_cleanup_performed(entries_removed: int, memory_freed_mb: float)
signal mission_phase_detected(phase: MissionPhase, recommendation: String)

enum MissionPhase {
	LOADING,      # Mission initialization
	BRIEFING,     # Briefing and setup
	ACTIVE,       # Active gameplay
	CUTSCENE,     # Cutscene or scripted sequence
	DEBRIEFING,   # Mission conclusion
	CLEANUP       # Mission cleanup/transition
}

enum CleanupStrategy {
	CONSERVATIVE,  # Keep most cache entries
	BALANCED,      # Normal cleanup based on usage
	AGGRESSIVE,    # Remove most entries to free memory
	EMERGENCY      # Remove everything non-essential
}

# Core components
var _expression_cache: ExpressionCache
var _performance_monitor: SexpPerformanceMonitor
var _performance_hints: PerformanceHintsSystem

# Mission state tracking
var current_mission_phase: MissionPhase = MissionPhase.LOADING
var mission_start_time: float = 0.0
var mission_duration_hours: float = 0.0
var phase_change_time: float = 0.0

# Memory management configuration
var memory_warning_threshold_mb: float = 100.0
var memory_critical_threshold_mb: float = 200.0
var cache_cleanup_interval_sec: float = 300.0  # 5 minutes
var aggressive_cleanup_threshold_hours: float = 2.0
var emergency_cleanup_threshold_mb: float = 250.0

# Cleanup timers and state
var _cleanup_timer: Timer
var _memory_check_timer: Timer
var _last_cleanup_time: float = 0.0
var _cleanup_statistics: Dictionary = {}

# Mission-specific optimization settings
var _phase_cache_strategies: Dictionary = {
	MissionPhase.LOADING: {"max_entries": 200, "cleanup_ratio": 0.1},
	MissionPhase.BRIEFING: {"max_entries": 500, "cleanup_ratio": 0.2},
	MissionPhase.ACTIVE: {"max_entries": 1500, "cleanup_ratio": 0.3},
	MissionPhase.CUTSCENE: {"max_entries": 800, "cleanup_ratio": 0.4},
	MissionPhase.DEBRIEFING: {"max_entries": 300, "cleanup_ratio": 0.5},
	MissionPhase.CLEANUP: {"max_entries": 100, "cleanup_ratio": 0.8}
}

func _init(
	expression_cache: ExpressionCache,
	performance_monitor: SexpPerformanceMonitor,
	performance_hints: PerformanceHintsSystem
) -> void:
	_expression_cache = expression_cache
	_performance_monitor = performance_monitor
	_performance_hints = performance_hints
	
	_setup_timers()
	_reset_mission_tracking()
	
	print("MissionCacheManager: Initialized with %.1f MB warning threshold" % memory_warning_threshold_mb)

func _setup_timers() -> void:
	"""Setup periodic cleanup and monitoring timers"""
	# Cache cleanup timer
	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = cache_cleanup_interval_sec
	_cleanup_timer.timeout.connect(_periodic_cache_cleanup)
	_cleanup_timer.autostart = true
	
	# Memory monitoring timer
	_memory_check_timer = Timer.new()
	_memory_check_timer.wait_time = 30.0  # Check every 30 seconds
	_memory_check_timer.timeout.connect(_check_memory_usage)
	_memory_check_timer.autostart = true

## Mission lifecycle management

func start_mission() -> void:
	"""Initialize cache management for new mission"""
	mission_start_time = Time.get_ticks_msec() / 1000.0
	current_mission_phase = MissionPhase.LOADING
	phase_change_time = mission_start_time
	
	# Reset cache for new mission
	_expression_cache.invalidate_all()
	
	# Reset performance tracking
	if _performance_monitor:
		_performance_monitor.reset_statistics()
	
	if _performance_hints:
		_performance_hints.reset_analysis_data()
	
	_reset_mission_tracking()
	print("MissionCacheManager: Mission started, cache reset")

func set_mission_phase(phase: MissionPhase) -> void:
	"""Update mission phase and adjust cache settings"""
	if phase == current_mission_phase:
		return
	
	var previous_phase = current_mission_phase
	current_mission_phase = phase
	phase_change_time = Time.get_ticks_msec() / 1000.0
	
	# Apply phase-specific optimizations
	_apply_phase_optimizations(phase)
	
	# Generate phase-specific recommendations
	var recommendation = _get_phase_recommendation(phase, previous_phase)
	mission_phase_detected.emit(phase, recommendation)
	
	print("MissionCacheManager: Phase changed to %s - %s" % [MissionPhase.keys()[phase], recommendation])

func end_mission() -> void:
	"""Clean up cache for mission completion"""
	current_mission_phase = MissionPhase.CLEANUP
	mission_duration_hours = (Time.get_ticks_msec() / 1000.0 - mission_start_time) / 3600.0
	
	# Aggressive cleanup for mission end
	perform_cleanup(CleanupStrategy.AGGRESSIVE)
	
	# Generate mission performance summary
	var summary = _generate_mission_summary()
	print("MissionCacheManager: Mission ended after %.2f hours. %s" % [mission_duration_hours, summary])

## Cache cleanup and memory management

func perform_cleanup(strategy: CleanupStrategy = CleanupStrategy.BALANCED) -> Dictionary:
	"""Perform cache cleanup with specified strategy"""
	var cleanup_start_time = Time.get_ticks_msec() / 1000.0
	var initial_memory = _get_estimated_cache_memory_usage()
	var initial_entries = _get_cache_entry_count()
	
	var entries_removed = 0
	var memory_freed = 0.0
	
	match strategy:
		CleanupStrategy.CONSERVATIVE:
			entries_removed = _conservative_cleanup()
		CleanupStrategy.BALANCED:
			entries_removed = _balanced_cleanup()
		CleanupStrategy.AGGRESSIVE:
			entries_removed = _aggressive_cleanup()
		CleanupStrategy.EMERGENCY:
			entries_removed = _emergency_cleanup()
	
	var final_memory = _get_estimated_cache_memory_usage()
	memory_freed = initial_memory - final_memory
	var cleanup_time = (Time.get_ticks_msec() / 1000.0) - cleanup_start_time
	
	# Update cleanup statistics
	var cleanup_info = {
		"strategy": CleanupStrategy.keys()[strategy],
		"entries_removed": entries_removed,
		"memory_freed_mb": memory_freed,
		"cleanup_time_ms": cleanup_time * 1000.0,
		"initial_entries": initial_entries,
		"final_entries": _get_cache_entry_count(),
		"phase": MissionPhase.keys()[current_mission_phase],
		"timestamp": cleanup_start_time
	}
	
	_cleanup_statistics[cleanup_start_time] = cleanup_info
	_last_cleanup_time = cleanup_start_time
	
	cache_cleanup_performed.emit(entries_removed, memory_freed)
	
	return cleanup_info

func _conservative_cleanup() -> int:
	"""Conservative cleanup - remove only idle entries"""
	var max_idle_time = 600.0  # 10 minutes
	return _expression_cache.cleanup_idle_entries(max_idle_time)

func _balanced_cleanup() -> int:
	"""Balanced cleanup based on mission phase and usage patterns"""
	var removed_count = 0
	
	# Remove idle entries
	var idle_time = 300.0  # 5 minutes
	if current_mission_phase == MissionPhase.ACTIVE:
		idle_time = 180.0  # 3 minutes during active gameplay
	
	removed_count += _expression_cache.cleanup_idle_entries(idle_time)
	
	# Apply phase-specific cache size limits
	var phase_config = _phase_cache_strategies.get(current_mission_phase, {})
	var max_entries = phase_config.get("max_entries", 1000)
	
	var current_entries = _get_cache_entry_count()
	if current_entries > max_entries:
		var target_removal = current_entries - max_entries
		removed_count += _remove_least_valuable_entries(target_removal)
	
	return removed_count

func _aggressive_cleanup() -> int:
	"""Aggressive cleanup for memory pressure situations"""
	var removed_count = 0
	
	# Remove idle entries with shorter threshold
	removed_count += _expression_cache.cleanup_idle_entries(120.0)  # 2 minutes
	
	# Remove entries with low cache hit ratios
	removed_count += _remove_low_efficiency_entries()
	
	# Reduce cache size significantly
	var target_entries = 300
	var current_entries = _get_cache_entry_count()
	if current_entries > target_entries:
		removed_count += _remove_least_valuable_entries(current_entries - target_entries)
	
	return removed_count

func _emergency_cleanup() -> int:
	"""Emergency cleanup - remove almost everything"""
	var initial_count = _get_cache_entry_count()
	
	# Clear all but most essential entries
	_expression_cache.invalidate_all()
	
	# Keep only very frequently accessed constant expressions
	_preserve_essential_constants()
	
	var final_count = _get_cache_entry_count()
	return initial_count - final_count

func _remove_least_valuable_entries(target_count: int) -> int:
	"""Remove entries with lowest value score"""
	# Get detailed cache statistics
	var cache_stats = _expression_cache.get_detailed_statistics()
	var entries = cache_stats.get("cache_entries", [])
	
	if entries.is_empty():
		return 0
	
	# Calculate value scores for each entry
	var scored_entries: Array[Dictionary] = []
	for entry in entries:
		var score = _calculate_entry_value_score(entry)
		scored_entries.append({
			"key": entry.get("key", ""),
			"score": score,
			"entry": entry
		})
	
	# Sort by score (lowest first)
	scored_entries.sort_custom(func(a, b): return a.score < b.score)
	
	# Remove lowest scoring entries
	var removed_count = 0
	var removal_limit = min(target_count, scored_entries.size())
	
	for i in range(removal_limit):
		var key = scored_entries[i]["key"]
		if _expression_cache.invalidate_by_dependency(key) > 0:
			removed_count += 1
	
	return removed_count

func _remove_low_efficiency_entries() -> int:
	"""Remove entries with poor cache efficiency"""
	# This would require extending ExpressionCache to support efficiency-based removal
	# For now, use cleanup_idle_entries as approximation
	return _expression_cache.cleanup_idle_entries(60.0)  # 1 minute

func _preserve_essential_constants() -> void:
	"""Preserve essential constant expressions after emergency cleanup"""
	# This is a placeholder - would need specific implementation
	# to identify and preserve truly essential expressions
	pass

func _calculate_entry_value_score(entry: Dictionary) -> float:
	"""Calculate value score for cache entry prioritization"""
	var score = 0.0
	
	# Access frequency component
	var access_count = entry.get("access_count", 0)
	var frequency = entry.get("frequency", 0.0)
	score += access_count * 0.3 + frequency * 0.2
	
	# Recency component
	var idle_time = entry.get("idle_time", 999999.0)
	score += max(0.0, 1.0 - (idle_time / 300.0)) * 0.3  # 5 minute decay
	
	# Dependency component (constant expressions are more valuable)
	var dependencies = entry.get("dependencies", [])
	if dependencies.is_empty():
		score += 0.2  # Constant expressions bonus
	
	return score

## Memory monitoring and warnings

func _check_memory_usage() -> void:
	"""Check current memory usage and trigger warnings"""
	var current_memory = _get_estimated_cache_memory_usage()
	
	if current_memory > emergency_cleanup_threshold_mb:
		# Emergency cleanup
		perform_cleanup(CleanupStrategy.EMERGENCY)
		memory_warning.emit(current_memory, emergency_cleanup_threshold_mb)
	elif current_memory > memory_critical_threshold_mb:
		# Aggressive cleanup
		perform_cleanup(CleanupStrategy.AGGRESSIVE)
		memory_warning.emit(current_memory, memory_critical_threshold_mb)
	elif current_memory > memory_warning_threshold_mb:
		# Balanced cleanup
		perform_cleanup(CleanupStrategy.BALANCED)
		memory_warning.emit(current_memory, memory_warning_threshold_mb)

func _periodic_cache_cleanup() -> void:
	"""Periodic cache cleanup based on mission state"""
	var current_time = Time.get_ticks_msec() / 1000.0
	mission_duration_hours = (current_time - mission_start_time) / 3600.0
	
	# Choose cleanup strategy based on mission duration and phase
	var strategy = CleanupStrategy.BALANCED
	
	if mission_duration_hours > aggressive_cleanup_threshold_hours:
		strategy = CleanupStrategy.AGGRESSIVE
	elif current_mission_phase in [MissionPhase.LOADING, MissionPhase.DEBRIEFING]:
		strategy = CleanupStrategy.CONSERVATIVE
	
	perform_cleanup(strategy)

## Mission phase optimization

func _apply_phase_optimizations(phase: MissionPhase) -> void:
	"""Apply phase-specific cache optimizations"""
	var phase_config = _phase_cache_strategies.get(phase, {})
	var max_entries = phase_config.get("max_entries", 1000)
	
	# Adjust cache size
	_expression_cache.set_cache_size(max_entries)
	
	# Adjust performance monitoring sensitivity
	if _performance_monitor:
		match phase:
			MissionPhase.ACTIVE:
				_performance_monitor.set_performance_thresholds(3.0, 150.0, 0.8)
			MissionPhase.CUTSCENE:
				_performance_monitor.set_performance_thresholds(5.0, 100.0, 0.7)
			_:
				_performance_monitor.set_performance_thresholds(5.0, 100.0, 0.7)
	
	# Adjust performance hints generation
	if _performance_hints:
		match phase:
			MissionPhase.ACTIVE:
				_performance_hints.set_configuration(1.0, 3, 0.7, 5, true)
			MissionPhase.BRIEFING, MissionPhase.DEBRIEFING:
				_performance_hints.set_configuration(3.0, 5, 0.6, 3, false)
			_:
				_performance_hints.set_configuration(2.0, 5, 0.6, 3, true)

func _get_phase_recommendation(current_phase: MissionPhase, previous_phase: MissionPhase) -> String:
	"""Generate optimization recommendations for phase transitions"""
	match current_phase:
		MissionPhase.LOADING:
			return "Cache reset, conservative memory usage"
		MissionPhase.BRIEFING:
			return "Moderate caching for UI interactions"
		MissionPhase.ACTIVE:
			return "Aggressive caching for gameplay performance"
		MissionPhase.CUTSCENE:
			return "Reduced cache size for memory efficiency"
		MissionPhase.DEBRIEFING:
			return "Cache cleanup, prepare for mission end"
		MissionPhase.CLEANUP:
			return "Aggressive cleanup, reset for next mission"
		_:
			return "Standard caching configuration"

## Utility and reporting methods

func _get_estimated_cache_memory_usage() -> float:
	"""Estimate current cache memory usage in MB"""
	if _expression_cache:
		var stats = _expression_cache.get_statistics()
		return stats.get("memory_usage_mb", 0.0)
	return 0.0

func _get_cache_entry_count() -> int:
	"""Get current number of cache entries"""
	if _expression_cache:
		var stats = _expression_cache.get_statistics()
		return stats.get("total_entries", 0)
	return 0

func _reset_mission_tracking() -> void:
	"""Reset mission tracking variables"""
	_cleanup_statistics.clear()
	_last_cleanup_time = 0.0
	mission_duration_hours = 0.0

func _generate_mission_summary() -> String:
	"""Generate mission performance summary"""
	var cache_stats = _expression_cache.get_statistics() if _expression_cache else {}
	var hit_rate = cache_stats.get("hit_rate", 0.0) * 100.0
	var total_entries = cache_stats.get("total_entries", 0)
	var memory_usage = cache_stats.get("memory_usage_mb", 0.0)
	var cleanup_count = _cleanup_statistics.size()
	
	return "Cache: %.1f%% hit rate, %d entries, %.1f MB, %d cleanups" % [
		hit_rate, total_entries, memory_usage, cleanup_count
	]

func get_mission_performance_report() -> Dictionary:
	"""Generate comprehensive mission performance report"""
	return {
		"mission_duration_hours": mission_duration_hours,
		"current_phase": MissionPhase.keys()[current_mission_phase],
		"cache_statistics": _expression_cache.get_statistics() if _expression_cache else {},
		"cleanup_history": _cleanup_statistics.values(),
		"memory_usage_mb": _get_estimated_cache_memory_usage(),
		"total_cleanups": _cleanup_statistics.size(),
		"last_cleanup_time": _last_cleanup_time,
		"phase_optimizations": _phase_cache_strategies.duplicate()
	}

## Configuration methods

func set_memory_thresholds(warning_mb: float, critical_mb: float, emergency_mb: float) -> void:
	"""Configure memory usage thresholds"""
	memory_warning_threshold_mb = warning_mb
	memory_critical_threshold_mb = critical_mb
	emergency_cleanup_threshold_mb = emergency_mb

func set_cleanup_intervals(cleanup_interval_sec: float, memory_check_sec: float) -> void:
	"""Configure cleanup and monitoring intervals"""
	cache_cleanup_interval_sec = cleanup_interval_sec
	if _cleanup_timer:
		_cleanup_timer.wait_time = cleanup_interval_sec
	
	if _memory_check_timer:
		_memory_check_timer.wait_time = memory_check_sec

func configure_phase_strategy(phase: MissionPhase, max_entries: int, cleanup_ratio: float) -> void:
	"""Configure strategy for specific mission phase"""
	_phase_cache_strategies[phase] = {
		"max_entries": max_entries,
		"cleanup_ratio": cleanup_ratio
	}