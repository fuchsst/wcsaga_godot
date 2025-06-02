class_name EnhancedTransitionManager
extends RefCounted

## Enhanced state transition management for EPIC-007
## Extends existing GameStateManager with validation, error recovery, and performance monitoring

const StateValidator = preload("res://scripts/core/game_flow/state_management/state_validator.gd")

signal transition_validation_failed(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, error_message: String)
signal transition_performance_warning(transition_time_ms: float, from_state: GameStateManager.GameState, to_state: GameStateManager.GameState)
signal transition_rollback_performed(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, reason: String)

# Enhanced transition result structure
class EnhancedTransitionResult:
	extends RefCounted
	
	var success: bool = false
	var error_message: String = ""
	var transition_time_ms: float = 0.0
	var rollback_performed: bool = false
	var resources_loaded: Array[String] = []
	var resources_unloaded: Array[String] = []
	var performance_metrics: Dictionary = {}

# Resource preparation result
class ResourcePreparationResult:
	extends RefCounted
	
	var success: bool = false
	var error_message: String = ""
	var loaded_resources: Array[String] = []

# Transition execution result
class TransitionExecutionResult:
	extends RefCounted
	
	var success: bool = false
	var error_message: String = ""

# Configuration
var enable_performance_monitoring: bool = true
var enable_rollback: bool = true
var max_transition_time_ms: float = 16.0  # 60 FPS requirement
var warning_transition_time_ms: float = 8.0

# State
var validator: StateValidator
var is_validating: bool = false

func _init():
	validator = StateValidator.new()

## Enhanced state transition with comprehensive validation and error recovery
func execute_enhanced_transition(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, data: Dictionary = {}) -> EnhancedTransitionResult:
	var result: EnhancedTransitionResult = EnhancedTransitionResult.new()
	var start_time: int = Time.get_ticks_msec()
	
	# Prevent concurrent validation
	if is_validating:
		result.error_message = "Transition validation already in progress"
		return result
	
	is_validating = true
	
	# Phase 1: Pre-transition validation
	var validation_result: StateValidator.StateValidationResult = validator.validate_transition_preconditions(from_state, to_state, data)
	if not validation_result.is_valid:
		result.error_message = "Validation failed: " + validation_result.error_message
		transition_validation_failed.emit(from_state, to_state, result.error_message)
		is_validating = false
		return result
	
	# Phase 2: Performance validation
	if not _validate_performance_requirements(from_state, to_state):
		result.error_message = "Performance requirements not met for transition"
		is_validating = false
		return result
	
	# Phase 3: Resource preparation
	var resource_result: ResourcePreparationResult = _prepare_transition_resources(from_state, to_state, data)
	if not resource_result.success:
		result.error_message = "Resource preparation failed: " + resource_result.error_message
		is_validating = false
		return result
	
	# Phase 4: Execute transition using existing GameStateManager
	var execution_result: TransitionExecutionResult = await _execute_transition_logic(from_state, to_state, data)
	if not execution_result.success:
		# Rollback on failure
		if enable_rollback:
			_rollback_transition(from_state, to_state, resource_result)
			result.rollback_performed = true
			transition_rollback_performed.emit(from_state, to_state, execution_result.error_message)
		
		result.error_message = "Transition execution failed: " + execution_result.error_message
		is_validating = false
		return result
	
	# Success - calculate metrics
	result.success = true
	result.transition_time_ms = Time.get_ticks_msec() - start_time
	result.resources_loaded = resource_result.loaded_resources
	result.performance_metrics = _collect_performance_metrics(from_state, to_state, result.transition_time_ms)
	
	# Performance monitoring
	if enable_performance_monitoring:
		_track_transition_performance(from_state, to_state, result.transition_time_ms)
	
	is_validating = false
	return result

## Validate performance requirements for transition
func _validate_performance_requirements(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState) -> bool:
	# Memory validation
	if not validator.validate_memory_requirements(to_state):
		push_warning("Insufficient memory for state transition to %s" % GameStateManager.GameState.keys()[to_state])
		return false
	
	# Performance validation
	if not validator.validate_transition_performance(from_state, to_state):
		push_warning("Performance requirements not met for transition %s -> %s" % [GameStateManager.GameState.keys()[from_state], GameStateManager.GameState.keys()[to_state]])
		return false
	
	return true

## Prepare resources for state transition
func _prepare_transition_resources(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, data: Dictionary) -> ResourcePreparationResult:
	var result: ResourcePreparationResult = ResourcePreparationResult.new()
	result.success = true
	
	# State-specific resource preparation
	match to_state:
		GameStateManager.GameState.MISSION:
			# Preload mission assets
			if data.has("mission_file"):
				var mission_file: String = data["mission_file"]
				if _preload_mission_resources(mission_file):
					result.loaded_resources.append("mission_assets")
				else:
					result.success = false
					result.error_message = "Failed to preload mission resources"
					return result
		
		GameStateManager.GameState.BRIEFING:
			# Preload briefing data and assets
			if _prepare_briefing_resources(data):
				result.loaded_resources.append("briefing_assets")
			else:
				result.success = false
				result.error_message = "Failed to prepare briefing resources"
				return result
		
		GameStateManager.GameState.SHIP_SELECTION:
			# Preload ship models and data
			if _prepare_ship_selection_resources():
				result.loaded_resources.append("ship_models")
			else:
				result.success = false
				result.error_message = "Failed to prepare ship selection resources"
				return result
		
		GameStateManager.GameState.FRED_EDITOR:
			# Prepare editor resources
			if _prepare_editor_resources():
				result.loaded_resources.append("editor_tools")
			else:
				result.success = false
				result.error_message = "Failed to prepare editor resources"
				return result
	
	return result

## Execute transition logic using existing GameStateManager
func _execute_transition_logic(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, data: Dictionary) -> TransitionExecutionResult:
	var result: TransitionExecutionResult = TransitionExecutionResult.new()
	
	# Use existing GameStateManager transition logic
	var transition_success: bool = GameStateManager.request_state_change(to_state)
	
	if transition_success:
		# Wait for transition to complete
		await GameStateManager.state_transition_completed
		result.success = true
	else:
		result.error_message = "GameStateManager transition request failed"
	
	return result

## Rollback failed transition
func _rollback_transition(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, resource_result: ResourcePreparationResult) -> void:
	push_warning("Rolling back failed transition %s -> %s" % [GameStateManager.GameState.keys()[from_state], GameStateManager.GameState.keys()[to_state]])
	
	# Unload resources that were loaded
	for resource: String in resource_result.loaded_resources:
		_unload_resource(resource)
	
	# Attempt to return to previous state
	if GameStateManager.get_current_state() != from_state:
		GameStateManager.request_state_change(from_state)

## Resource management helpers

func _preload_mission_resources(mission_file: String) -> bool:
	# Implement mission resource preloading
	if not mission_file.is_empty() and ResourceLoader.exists(mission_file):
		# Preload mission data
		var mission_resource: Resource = load(mission_file)
		return mission_resource != null
	return false

func _prepare_briefing_resources(data: Dictionary) -> bool:
	# Implement briefing resource preparation
	return true

func _prepare_ship_selection_resources() -> bool:
	# Implement ship selection resource preparation
	return true

func _prepare_editor_resources() -> bool:
	# Implement editor resource preparation
	return OS.is_debug_build()  # Only allow in debug builds

func _unload_resource(resource_name: String) -> void:
	# Implement resource unloading
	match resource_name:
		"mission_assets":
			# Unload mission-specific assets
			pass
		"briefing_assets":
			# Unload briefing assets
			pass
		"ship_models":
			# Unload ship models
			pass
		"editor_tools":
			# Unload editor tools
			pass

## Performance monitoring

func _track_transition_performance(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, duration_ms: float) -> void:
	var transition_name: String = "%s -> %s" % [GameStateManager.GameState.keys()[from_state], GameStateManager.GameState.keys()[to_state]]
	
	# Log performance information
	if duration_ms > warning_transition_time_ms:
		push_warning("Slow state transition detected: %s took %.2fms" % [transition_name, duration_ms])
		transition_performance_warning.emit(duration_ms, from_state, to_state)
	
	# Critical performance warning
	if duration_ms > max_transition_time_ms:
		push_error("Critical performance issue: State transition %s took %.2fms (exceeds %dms limit)" % [transition_name, duration_ms, max_transition_time_ms])
	
	# Store performance data for analysis
	_store_performance_data(from_state, to_state, duration_ms)

func _collect_performance_metrics(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, duration_ms: float) -> Dictionary:
	return {
		"transition_time_ms": duration_ms,
		"memory_usage": OS.get_static_memory_peak_usage(),
		"from_state": GameStateManager.GameState.keys()[from_state],
		"to_state": GameStateManager.GameState.keys()[to_state],
		"timestamp": Time.get_unix_time_from_system()
	}

func _store_performance_data(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, duration_ms: float) -> void:
	# Store performance data for future analysis (could be saved to file or sent to analytics)
	var perf_data: Dictionary = {
		"from_state": from_state,
		"to_state": to_state,
		"duration_ms": duration_ms,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# In debug mode, print performance info
	if GameStateManager.debug_mode:
		print("Transition performance: %s -> %s in %.2fms" % [GameStateManager.GameState.keys()[from_state], GameStateManager.GameState.keys()[to_state], duration_ms])

## Configuration methods

func set_performance_monitoring(enabled: bool) -> void:
	enable_performance_monitoring = enabled

func set_rollback_enabled(enabled: bool) -> void:
	enable_rollback = enabled

func set_performance_limits(max_time_ms: float, warning_time_ms: float) -> void:
	max_transition_time_ms = max_time_ms
	warning_transition_time_ms = warning_time_ms

func get_performance_stats() -> Dictionary:
	return {
		"enable_performance_monitoring": enable_performance_monitoring,
		"enable_rollback": enable_rollback,
		"max_transition_time_ms": max_transition_time_ms,
		"warning_transition_time_ms": warning_transition_time_ms,
		"is_validating": is_validating
	}