class_name SexpVariableWatchSystem
extends RefCounted

## SEXP Variable Watch System for SEXP-010
##
## Provides comprehensive variable monitoring with real-time updates,
## filtering, change detection, and watch conditions. Integrates with
## the debugging system to provide detailed variable inspection.

signal variable_watched(watch: SexpVariableWatch)
signal variable_unwatched(watch_id: String)
signal variable_changed(watch_id: String, old_value: SexpResult, new_value: SexpResult)
signal watch_condition_triggered(watch_id: String, condition: String)
signal watch_list_updated(watches: Array[SexpVariableWatch])

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")
const SexpEvaluationContext = preload("res://addons/sexp/core/sexp_evaluation_context.gd")
const SexpVariableManager = preload("res://addons/sexp/variables/sexp_variable_manager.gd")

enum WatchType {
	READ_WRITE,    # Watch both reads and writes
	READ_ONLY,     # Watch only reads
	WRITE_ONLY,    # Watch only writes
	CONDITIONAL    # Watch based on condition
}

enum FilterType {
	NONE,
	TYPE_FILTER,   # Filter by value type
	VALUE_FILTER,  # Filter by value range/pattern
	SCOPE_FILTER,  # Filter by variable scope
	CHANGE_FILTER  # Filter by change frequency
}

enum UpdateFrequency {
	IMMEDIATE,     # Update immediately on change
	PERIODIC,      # Update on timer
	ON_DEMAND,     # Update only when requested
	THRESHOLD      # Update when threshold exceeded
}

# Watch management
var _watches: Dictionary = {}  # watch_id -> SexpVariableWatch
var _watch_id_counter: int = 0
var _active_contexts: Dictionary = {}  # context_id -> SexpEvaluationContext

# Change tracking
var _variable_history: Dictionary = {}  # variable_name -> Array[VariableChange]
var _max_history_per_variable: int = 100
var _change_statistics: Dictionary = {}

# Filtering and grouping
var _active_filters: Array[SexpWatchFilter] = []
var _watch_groups: Dictionary = {}  # group_name -> Array[watch_id]

# Update management
var _update_queue: Array[String] = []  # watch_ids pending update
var _update_timer: Timer = null
var _periodic_update_interval: float = 1.0

# Performance monitoring
var _watch_statistics: Dictionary = {}
var _performance_mode: bool = false
var _max_watches_warning: int = 50

func _init() -> void:
	_initialize_update_timer()
	_initialize_statistics()
	print("SexpVariableWatchSystem: Initialized with real-time variable monitoring")

func _initialize_update_timer() -> void:
	"""Initialize periodic update timer"""
	_update_timer = Timer.new()
	_update_timer.wait_time = _periodic_update_interval
	_update_timer.timeout.connect(_process_periodic_updates)
	_update_timer.autostart = false

func _initialize_statistics() -> void:
	"""Initialize watch statistics"""
	_watch_statistics = {
		"total_watches": 0,
		"active_watches": 0,
		"total_changes_detected": 0,
		"total_condition_triggers": 0,
		"average_update_time": 0.0,
		"memory_usage_bytes": 0
	}

## Watch management methods

func add_variable_watch(variable_name: String, watch_type: WatchType = WatchType.READ_WRITE, 
					   condition: String = "", group: String = "default") -> String:
	"""Add a new variable watch"""
	var watch = SexpVariableWatch.new()
	watch.id = _generate_watch_id()
	watch.variable_name = variable_name
	watch.watch_type = watch_type
	watch.condition = condition
	watch.group = group
	watch.created_time = Time.get_ticks_msec() / 1000.0
	watch.enabled = true
	
	_watches[watch.id] = watch
	
	# Add to group
	if group not in _watch_groups:
		_watch_groups[group] = []
	_watch_groups[group].append(watch.id)
	
	# Initialize variable history if needed
	if variable_name not in _variable_history:
		_variable_history[variable_name] = []
	
	# Update statistics
	_watch_statistics["total_watches"] += 1
	_watch_statistics["active_watches"] += 1
	
	variable_watched.emit(watch)
	watch_list_updated.emit(get_all_watches())
	
	print("SexpVariableWatchSystem: Added watch for variable '%s' (ID: %s)" % [variable_name, watch.id])
	return watch.id

func remove_variable_watch(watch_id: String) -> bool:
	"""Remove a variable watch"""
	if watch_id not in _watches:
		return false
	
	var watch = _watches[watch_id]
	
	# Remove from group
	if watch.group in _watch_groups:
		_watch_groups[watch.group].erase(watch_id)
		if _watch_groups[watch.group].is_empty():
			_watch_groups.erase(watch.group)
	
	_watches.erase(watch_id)
	
	# Update statistics
	_watch_statistics["active_watches"] -= 1
	
	variable_unwatched.emit(watch_id)
	watch_list_updated.emit(get_all_watches())
	
	print("SexpVariableWatchSystem: Removed watch %s" % watch_id)
	return true

func enable_watch(watch_id: String, enabled: bool = true) -> bool:
	"""Enable or disable a watch"""
	if watch_id not in _watches:
		return false
	
	_watches[watch_id].enabled = enabled
	return true

func update_watch_condition(watch_id: String, condition: String) -> bool:
	"""Update watch condition"""
	if watch_id not in _watches:
		return false
	
	_watches[watch_id].condition = condition
	return true

func get_watch(watch_id: String) -> SexpVariableWatch:
	"""Get watch by ID"""
	return _watches.get(watch_id)

func get_all_watches() -> Array[SexpVariableWatch]:
	"""Get all watches"""
	return _watches.values()

func get_watches_for_variable(variable_name: String) -> Array[SexpVariableWatch]:
	"""Get all watches for a specific variable"""
	var matches: Array[SexpVariableWatch] = []
	for watch in _watches.values():
		if watch.variable_name == variable_name:
			matches.append(watch)
	return matches

func get_watches_in_group(group: String) -> Array[SexpVariableWatch]:
	"""Get all watches in a group"""
	var watches: Array[SexpVariableWatch] = []
	if group in _watch_groups:
		for watch_id in _watch_groups[group]:
			if watch_id in _watches:
				watches.append(_watches[watch_id])
	return watches

## Variable change detection

func notify_variable_read(variable_name: String, value: SexpResult, context: SexpEvaluationContext) -> void:
	"""Notify system of variable read"""
	var matching_watches = _get_watches_for_operation(variable_name, "read")
	
	for watch in matching_watches:
		if watch.enabled:
			_process_variable_access(watch, value, context, "read")

func notify_variable_write(variable_name: String, old_value: SexpResult, new_value: SexpResult, 
						  context: SexpEvaluationContext) -> void:
	"""Notify system of variable write"""
	var matching_watches = _get_watches_for_operation(variable_name, "write")
	
	for watch in matching_watches:
		if watch.enabled:
			_process_variable_change(watch, old_value, new_value, context)
	
	# Record change in history
	_record_variable_change(variable_name, old_value, new_value, context)

func notify_context_changed(context: SexpEvaluationContext) -> void:
	"""Notify system of context change"""
	if context:
		_active_contexts[context.context_id] = context
		_update_watches_for_context(context)

## Change processing

func _process_variable_access(watch: SexpVariableWatch, value: SexpResult, context: SexpEvaluationContext, operation: String) -> void:
	"""Process variable access (read)"""
	watch.last_access_time = Time.get_ticks_msec() / 1000.0
	watch.access_count += 1
	
	# Update current value if not already set
	if not watch.current_value:
		watch.current_value = value
		watch.last_update_time = watch.last_access_time
	
	# Check condition if set
	if not watch.condition.is_empty():
		if _evaluate_watch_condition(watch, value, context):
			watch_condition_triggered.emit(watch.id, watch.condition)

func _process_variable_change(watch: SexpVariableWatch, old_value: SexpResult, new_value: SexpResult, 
							 context: SexpEvaluationContext) -> void:
	"""Process variable change (write)"""
	var change_time = Time.get_ticks_msec() / 1000.0
	
	# Update watch state
	watch.previous_value = watch.current_value if watch.current_value else old_value
	watch.current_value = new_value
	watch.last_update_time = change_time
	watch.change_count += 1
	
	# Calculate change delta
	if old_value and new_value:
		watch.last_change_delta = _calculate_value_delta(old_value, new_value)
	
	# Check if significant change
	var is_significant = _is_significant_change(watch, old_value, new_value)
	if is_significant:
		watch.significant_change_count += 1
	
	# Apply filters
	if _should_report_change(watch, old_value, new_value):
		variable_changed.emit(watch.id, old_value, new_value)
	
	# Check condition
	if not watch.condition.is_empty():
		if _evaluate_watch_condition(watch, new_value, context):
			watch_condition_triggered.emit(watch.id, watch.condition)
	
	# Update statistics
	_watch_statistics["total_changes_detected"] += 1

func _record_variable_change(variable_name: String, old_value: SexpResult, new_value: SexpResult, 
							context: SexpEvaluationContext) -> void:
	"""Record variable change in history"""
	var change = VariableChange.new()
	change.timestamp = Time.get_ticks_msec() / 1000.0
	change.variable_name = variable_name
	change.old_value = old_value
	change.new_value = new_value
	change.context_id = context.context_id if context else ""
	change.change_delta = _calculate_value_delta(old_value, new_value)
	
	if variable_name not in _variable_history:
		_variable_history[variable_name] = []
	
	_variable_history[variable_name].append(change)
	
	# Limit history size
	if _variable_history[variable_name].size() > _max_history_per_variable:
		_variable_history[variable_name] = _variable_history[variable_name].slice(-_max_history_per_variable)

## Filtering and conditions

func add_filter(filter: SexpWatchFilter) -> void:
	"""Add a watch filter"""
	_active_filters.append(filter)
	
	# Reapply all filters
	_apply_filters_to_all_watches()

func remove_filter(filter_id: String) -> bool:
	"""Remove a watch filter"""
	for i in range(_active_filters.size()):
		if _active_filters[i].id == filter_id:
			_active_filters.remove_at(i)
			_apply_filters_to_all_watches()
			return true
	return false

func clear_filters() -> void:
	"""Clear all filters"""
	_active_filters.clear()
	_apply_filters_to_all_watches()

func _apply_filters_to_all_watches() -> void:
	"""Apply all active filters to watches"""
	for watch in _watches.values():
		watch.filtered = _should_filter_watch(watch)

func _should_filter_watch(watch: SexpVariableWatch) -> bool:
	"""Check if watch should be filtered out"""
	for filter in _active_filters:
		if not filter.enabled:
			continue
		
		match filter.filter_type:
			FilterType.TYPE_FILTER:
				if watch.current_value and watch.current_value.result_type != filter.type_criteria:
					return true
			
			FilterType.VALUE_FILTER:
				if not _value_matches_filter(watch.current_value, filter):
					return true
			
			FilterType.SCOPE_FILTER:
				# Would need context information
				pass
			
			FilterType.CHANGE_FILTER:
				if watch.change_count < filter.min_changes or watch.change_count > filter.max_changes:
					return true
	
	return false

func _should_report_change(watch: SexpVariableWatch, old_value: SexpResult, new_value: SexpResult) -> bool:
	"""Check if change should be reported based on filters"""
	if watch.filtered:
		return false
	
	# Check update frequency
	match watch.update_frequency:
		UpdateFrequency.IMMEDIATE:
			return true
		
		UpdateFrequency.PERIODIC:
			# Add to update queue for periodic processing
			if watch.id not in _update_queue:
				_update_queue.append(watch.id)
			return false
		
		UpdateFrequency.ON_DEMAND:
			return false
		
		UpdateFrequency.THRESHOLD:
			return _is_significant_change(watch, old_value, new_value)
	
	return true

func _evaluate_watch_condition(watch: SexpVariableWatch, value: SexpResult, context: SexpEvaluationContext) -> bool:
	"""Evaluate watch condition"""
	if watch.condition.is_empty() or not value:
		return false
	
	# Simple condition evaluation (could be enhanced with SEXP parser)
	var condition = watch.condition.replace("{value}", str(value.value))
	condition = condition.replace("{type}", SexpResult.Type.keys()[value.result_type])
	
	# Basic pattern matching for common conditions
	if condition.begins_with(">"):
		var threshold = condition.substr(1).strip_edges().to_float()
		return value.is_number() and value.get_number_value() > threshold
	
	elif condition.begins_with("<"):
		var threshold = condition.substr(1).strip_edges().to_float()
		return value.is_number() and value.get_number_value() < threshold
	
	elif condition.begins_with("=="):
		var expected = condition.substr(2).strip_edges()
		return str(value.value) == expected
	
	elif condition.begins_with("!="):
		var expected = condition.substr(2).strip_edges()
		return str(value.value) != expected
	
	elif condition == "changed":
		return watch.change_count > 0
	
	return false

## Update management

func _process_periodic_updates() -> void:
	"""Process periodic updates for watches"""
	var updates_to_process = _update_queue.duplicate()
	_update_queue.clear()
	
	for watch_id in updates_to_process:
		if watch_id in _watches:
			var watch = _watches[watch_id]
			if watch.enabled and watch.update_frequency == UpdateFrequency.PERIODIC:
				# Emit delayed change notification
				variable_changed.emit(watch_id, watch.previous_value, watch.current_value)

func request_immediate_update(watch_id: String) -> bool:
	"""Request immediate update for on-demand watch"""
	if watch_id not in _watches:
		return false
	
	var watch = _watches[watch_id]
	if watch.update_frequency == UpdateFrequency.ON_DEMAND:
		variable_changed.emit(watch_id, watch.previous_value, watch.current_value)
		return true
	
	return false

func set_periodic_update_interval(interval: float) -> void:
	"""Set periodic update interval"""
	_periodic_update_interval = max(0.1, interval)
	if _update_timer:
		_update_timer.wait_time = _periodic_update_interval

func start_periodic_updates() -> void:
	"""Start periodic update timer"""
	if _update_timer:
		_update_timer.start()

func stop_periodic_updates() -> void:
	"""Stop periodic update timer"""
	if _update_timer:
		_update_timer.stop()

## Variable history and analysis

func get_variable_history(variable_name: String, limit: int = 50) -> Array[VariableChange]:
	"""Get change history for variable"""
	if variable_name not in _variable_history:
		return []
	
	var history = _variable_history[variable_name]
	var result_limit = min(limit, history.size())
	return history.slice(-result_limit)

func get_variable_statistics(variable_name: String) -> Dictionary:
	"""Get statistics for specific variable"""
	var stats = {
		"total_changes": 0,
		"first_change_time": 0.0,
		"last_change_time": 0.0,
		"average_change_frequency": 0.0,
		"current_value": "",
		"previous_value": "",
		"watch_count": 0
	}
	
	# Get from history
	if variable_name in _variable_history:
		var history = _variable_history[variable_name]
		stats["total_changes"] = history.size()
		if not history.is_empty():
			stats["first_change_time"] = history[0].timestamp
			stats["last_change_time"] = history[-1].timestamp
			stats["current_value"] = history[-1].new_value.to_string()
			stats["previous_value"] = history[-1].old_value.to_string()
			
			if history.size() > 1:
				var time_span = stats["last_change_time"] - stats["first_change_time"]
				stats["average_change_frequency"] = history.size() / max(1.0, time_span)
	
	# Count watches
	stats["watch_count"] = get_watches_for_variable(variable_name).size()
	
	return stats

func analyze_variable_patterns(variable_name: String) -> Dictionary:
	"""Analyze patterns in variable changes"""
	var analysis = {
		"change_pattern": "unknown",
		"trend": "stable",
		"volatility": 0.0,
		"common_values": [],
		"outliers": []
	}
	
	if variable_name not in _variable_history:
		return analysis
	
	var history = _variable_history[variable_name]
	if history.size() < 3:
		return analysis
	
	# Analyze numerical patterns
	var numerical_values: Array[float] = []
	for change in history:
		if change.new_value and change.new_value.is_number():
			numerical_values.append(change.new_value.get_number_value())
	
	if numerical_values.size() >= 3:
		analysis["trend"] = _analyze_trend(numerical_values)
		analysis["volatility"] = _calculate_volatility(numerical_values)
	
	return analysis

## Utility methods

func _generate_watch_id() -> String:
	"""Generate unique watch ID"""
	_watch_id_counter += 1
	return "watch_%d" % _watch_id_counter

func _get_watches_for_operation(variable_name: String, operation: String) -> Array[SexpVariableWatch]:
	"""Get watches that should be triggered for operation"""
	var matches: Array[SexpVariableWatch] = []
	
	for watch in _watches.values():
		if watch.variable_name != variable_name or not watch.enabled:
			continue
		
		match watch.watch_type:
			WatchType.READ_WRITE:
				matches.append(watch)
			WatchType.READ_ONLY:
				if operation == "read":
					matches.append(watch)
			WatchType.WRITE_ONLY:
				if operation == "write":
					matches.append(watch)
			WatchType.CONDITIONAL:
				matches.append(watch)  # Will be filtered by condition
	
	return matches

func _calculate_value_delta(old_value: SexpResult, new_value: SexpResult) -> Variant:
	"""Calculate delta between two values"""
	if not old_value or not new_value:
		return null
	
	if old_value.result_type != new_value.result_type:
		return "type_change"
	
	if old_value.is_number() and new_value.is_number():
		return new_value.get_number_value() - old_value.get_number_value()
	
	if old_value.is_string() and new_value.is_string():
		var old_str = old_value.get_string_value()
		var new_str = new_value.get_string_value()
		return {"old_length": old_str.length(), "new_length": new_str.length(), "changed": old_str != new_str}
	
	if old_value.is_boolean() and new_value.is_boolean():
		return old_value.get_boolean_value() != new_value.get_boolean_value()
	
	return "unknown_change"

func _is_significant_change(watch: SexpVariableWatch, old_value: SexpResult, new_value: SexpResult) -> bool:
	"""Check if change is significant"""
	if not old_value or not new_value:
		return true
	
	# Type change is always significant
	if old_value.result_type != new_value.result_type:
		return true
	
	# Numerical threshold check
	if old_value.is_number() and new_value.is_number():
		var delta = abs(new_value.get_number_value() - old_value.get_number_value())
		return delta >= watch.significance_threshold
	
	# String length change
	if old_value.is_string() and new_value.is_string():
		var old_str = old_value.get_string_value()
		var new_str = new_value.get_string_value()
		return abs(new_str.length() - old_str.length()) >= 5  # Threshold for string changes
	
	# Boolean change is always significant
	if old_value.is_boolean() and new_value.is_boolean():
		return old_value.get_boolean_value() != new_value.get_boolean_value()
	
	return true

func _value_matches_filter(value: SexpResult, filter: SexpWatchFilter) -> bool:
	"""Check if value matches filter criteria"""
	if not value:
		return false
	
	# Implementation would depend on filter criteria
	return true  # Placeholder

func _update_watches_for_context(context: SexpEvaluationContext) -> void:
	"""Update watches when context changes"""
	for watch in _watches.values():
		if watch.enabled:
			var value = context.get_variable(watch.variable_name)
			if value and not value.is_error():
				_process_variable_access(watch, value, context, "context_update")

func _analyze_trend(values: Array[float]) -> String:
	"""Analyze trend in numerical values"""
	if values.size() < 2:
		return "stable"
	
	var increasing = 0
	var decreasing = 0
	
	for i in range(1, values.size()):
		if values[i] > values[i-1]:
			increasing += 1
		elif values[i] < values[i-1]:
			decreasing += 1
	
	if increasing > decreasing * 1.5:
		return "increasing"
	elif decreasing > increasing * 1.5:
		return "decreasing"
	else:
		return "stable"

func _calculate_volatility(values: Array[float]) -> float:
	"""Calculate volatility of numerical values"""
	if values.size() < 2:
		return 0.0
	
	var mean = 0.0
	for value in values:
		mean += value
	mean /= values.size()
	
	var variance = 0.0
	for value in values:
		variance += pow(value - mean, 2)
	variance /= values.size()
	
	return sqrt(variance)

## Configuration and statistics

func configure_system(max_history: int = 100, performance_mode: bool = false, max_watches: int = 50) -> void:
	"""Configure watch system"""
	_max_history_per_variable = max_history
	_performance_mode = performance_mode
	_max_watches_warning = max_watches

func get_system_statistics() -> Dictionary:
	"""Get system statistics"""
	var stats = _watch_statistics.duplicate()
	stats["variable_count"] = _variable_history.size()
	stats["filter_count"] = _active_filters.size()
	stats["group_count"] = _watch_groups.size()
	stats["update_queue_size"] = _update_queue.size()
	stats["memory_estimate_kb"] = _estimate_memory_usage() / 1024.0
	
	return stats

func _estimate_memory_usage() -> int:
	"""Estimate memory usage in bytes"""
	var usage = 0
	
	# Watches
	usage += _watches.size() * 200  # Approximate per watch
	
	# History
	for var_name in _variable_history:
		usage += _variable_history[var_name].size() * 100  # Approximate per change
	
	return usage

func clear_history() -> void:
	"""Clear all variable history"""
	_variable_history.clear()

func clear_all_watches() -> void:
	"""Clear all watches"""
	_watches.clear()
	_watch_groups.clear()
	_update_queue.clear()
	watch_list_updated.emit([])

## Data classes

class SexpVariableWatch:
	extends RefCounted
	
	var id: String = ""
	var variable_name: String = ""
	var watch_type: WatchType = WatchType.READ_WRITE
	var condition: String = ""
	var group: String = "default"
	
	var enabled: bool = true
	var filtered: bool = false
	var update_frequency: UpdateFrequency = UpdateFrequency.IMMEDIATE
	var significance_threshold: float = 0.01
	
	var current_value: SexpResult = null
	var previous_value: SexpResult = null
	var last_change_delta: Variant = null
	
	var created_time: float = 0.0
	var last_update_time: float = 0.0
	var last_access_time: float = 0.0
	
	var change_count: int = 0
	var access_count: int = 0
	var significant_change_count: int = 0
	
	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"variable_name": variable_name,
			"watch_type": WatchType.keys()[watch_type],
			"condition": condition,
			"group": group,
			"enabled": enabled,
			"filtered": filtered,
			"update_frequency": UpdateFrequency.keys()[update_frequency],
			"current_value": current_value.to_string() if current_value else "null",
			"previous_value": previous_value.to_string() if previous_value else "null",
			"change_count": change_count,
			"access_count": access_count,
			"significant_change_count": significant_change_count,
			"last_update_time": last_update_time
		}

class VariableChange:
	extends RefCounted
	
	var timestamp: float = 0.0
	var variable_name: String = ""
	var old_value: SexpResult = null
	var new_value: SexpResult = null
	var context_id: String = ""
	var change_delta: Variant = null
	
	func to_dictionary() -> Dictionary:
		return {
			"timestamp": timestamp,
			"variable_name": variable_name,
			"old_value": old_value.to_string() if old_value else "null",
			"new_value": new_value.to_string() if new_value else "null",
			"context_id": context_id,
			"change_delta": str(change_delta)
		}

class SexpWatchFilter:
	extends RefCounted
	
	var id: String = ""
	var filter_type: FilterType = FilterType.NONE
	var enabled: bool = true
	
	# Type filter criteria
	var type_criteria: int = -1
	
	# Value filter criteria
	var min_value: Variant = null
	var max_value: Variant = null
	var value_pattern: String = ""
	
	# Change filter criteria
	var min_changes: int = 0
	var max_changes: int = 999999
	
	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"filter_type": FilterType.keys()[filter_type],
			"enabled": enabled,
			"type_criteria": type_criteria,
			"min_value": str(min_value),
			"max_value": str(max_value),
			"value_pattern": value_pattern,
			"min_changes": min_changes,
			"max_changes": max_changes
		}