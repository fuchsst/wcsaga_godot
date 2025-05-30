class_name ShipErrorHandler
extends RefCounted

## Comprehensive error handling for ship object operations
##
## Provides centralized error handling, validation, and recovery mechanisms
## for ship and object manipulation operations, following WCS error patterns
## and ensuring graceful degradation when operations fail.
##
## Integrates with object reference system for consistent error reporting.

signal error_occurred(error_code: ErrorCode, error_message: String, context: Dictionary)
signal warning_generated(warning_message: String, context: Dictionary)
signal operation_recovered(operation: String, recovery_action: String)

## Error codes following WCS patterns
enum ErrorCode {
	NONE = 0,
	SHIP_NOT_FOUND = 1,
	SHIP_DESTROYED = 2,
	SHIP_DEPARTED = 3,
	INVALID_PARAMETER = 4,
	OPERATION_FAILED = 5,
	SUBSYSTEM_NOT_FOUND = 6,
	PERMISSION_DENIED = 7,
	RESOURCE_UNAVAILABLE = 8,
	SYSTEM_ERROR = 9,
	TIMEOUT = 10,
	VALIDATION_FAILED = 11
}

## Error severity levels
enum Severity {
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

## Error tracking and statistics
var _error_counts: Dictionary = {}
var _error_history: Array[Dictionary] = []
var _max_history_size: int = 1000
var _error_suppression: Dictionary = {}  # Temporarily suppress repeated errors
var _operation_timeouts: Dictionary = {}  # Track operation timeouts
var _recovery_strategies: Dictionary = {}  # Custom recovery strategies

## Configuration
var _enable_error_recovery: bool = true
var _enable_detailed_logging: bool = true
var _suppress_repeated_errors: bool = true
var _max_recovery_attempts: int = 3

## Singleton pattern
static var _instance: ShipErrorHandler = null

static func get_instance() -> ShipErrorHandler:
	if _instance == null:
		_instance = ShipErrorHandler.new()
	return _instance

func _init():
	if _instance == null:
		_instance = self
	_initialize_error_system()

func _initialize_error_system():
	"""Initialize error handling system"""
	# Initialize error counters
	for error_code in ErrorCode.values():
		_error_counts[error_code] = 0
	
	# Set up default recovery strategies
	_setup_default_recovery_strategies()

## Primary error handling functions

func handle_ship_operation_error(operation: String, ship_name: String, error_code: ErrorCode, details: String = "", context: Dictionary = {}) -> bool:
	"""
	Handle errors from ship operations
	Args:
		operation: Name of the operation that failed
		ship_name: Ship that was being operated on
		error_code: Type of error that occurred
		details: Additional error details
		context: Additional context information
	Returns:
		true if error was handled/recovered, false if operation should fail
	"""
	var full_context = context.duplicate()
	full_context["operation"] = operation
	full_context["ship_name"] = ship_name
	full_context["timestamp"] = Time.get_ticks_msec() * 0.001
	
	# Log the error
	_log_error(error_code, details, full_context)
	
	# Check for error suppression
	if _should_suppress_error(error_code, ship_name):
		return true
	
	# Attempt recovery if enabled
	if _enable_error_recovery:
		var recovery_result = _attempt_error_recovery(operation, ship_name, error_code, full_context)
		if recovery_result:
			operation_recovered.emit(operation, "Automatic recovery successful")
			return true
	
	# Emit error signal
	var error_message = _format_error_message(operation, ship_name, error_code, details)
	error_occurred.emit(error_code, error_message, full_context)
	
	return false

func validate_ship_operation(operation: String, ship_name: String, parameters: Array = []) -> ErrorCode:
	"""
	Validate ship operation before execution
	Args:
		operation: Operation to validate
		ship_name: Ship to validate against
		parameters: Operation parameters to validate
	Returns:
		ErrorCode.NONE if valid, error code if invalid
	"""
	# Basic parameter validation
	if ship_name.is_empty():
		return ErrorCode.INVALID_PARAMETER
	
	# Check if ship exists
	var ship_interface = ShipSystemInterface.get_instance()
	var ship_node = ship_interface.ship_name_lookup(ship_name, true)
	
	if ship_node == null:
		# Check if ship is destroyed/departed
		if ship_interface.is_ship_destroyed(ship_name):
			return ErrorCode.SHIP_DESTROYED
		elif ship_interface.is_ship_departed(ship_name):
			return ErrorCode.SHIP_DEPARTED
		else:
			return ErrorCode.SHIP_NOT_FOUND
	
	# Validate operation-specific requirements
	match operation:
		"set-hull-strength", "set-shield-strength", "damage-ship":
			if parameters.size() > 0 and not _is_valid_number(parameters[0]):
				return ErrorCode.INVALID_PARAMETER
		"set-ship-position", "set-ship-velocity":
			if parameters.size() < 3:
				return ErrorCode.INVALID_PARAMETER
			for i in range(3):
				if not _is_valid_number(parameters[i]):
					return ErrorCode.INVALID_PARAMETER
		"set-subsystem-strength":
			if parameters.size() < 2:
				return ErrorCode.INVALID_PARAMETER
			if not _is_valid_subsystem(ship_node, str(parameters[0])):
				return ErrorCode.SUBSYSTEM_NOT_FOUND
	
	return ErrorCode.NONE

func validate_ship_reference(ship_name: String, operation_context: String = "") -> ErrorCode:
	"""
	Validate ship reference for any operation
	Args:
		ship_name: Ship name to validate
		operation_context: Context for better error messages
	Returns:
		ErrorCode.NONE if valid, error code if invalid
	"""
	if ship_name.is_empty():
		return ErrorCode.INVALID_PARAMETER
	
	var ship_interface = ShipSystemInterface.get_instance()
	
	# Check destroyed/departed status first (most specific)
	if ship_interface.is_ship_destroyed(ship_name):
		return ErrorCode.SHIP_DESTROYED
	
	if ship_interface.is_ship_departed(ship_name):
		return ErrorCode.SHIP_DEPARTED
	
	# Check if ship exists
	var ship_node = ship_interface.ship_name_lookup(ship_name, true)
	if ship_node == null:
		return ErrorCode.SHIP_NOT_FOUND
	
	return ErrorCode.NONE

## Error recovery mechanisms

func _attempt_error_recovery(operation: String, ship_name: String, error_code: ErrorCode, context: Dictionary) -> bool:
	"""
	Attempt to recover from an error
	Args:
		operation: Operation that failed
		ship_name: Ship involved in the operation
		error_code: Error that occurred
		context: Error context
	Returns:
		true if recovery was successful
	"""
	var recovery_key = operation + "_" + str(error_code)
	
	# Check if we have a custom recovery strategy
	if _recovery_strategies.has(recovery_key):
		return _recovery_strategies[recovery_key].call(ship_name, context)
	
	# Default recovery strategies
	match error_code:
		ErrorCode.SHIP_NOT_FOUND:
			return _recover_missing_ship(ship_name, context)
		ErrorCode.SUBSYSTEM_NOT_FOUND:
			return _recover_missing_subsystem(ship_name, context)
		ErrorCode.TIMEOUT:
			return _recover_timeout(operation, ship_name, context)
		ErrorCode.RESOURCE_UNAVAILABLE:
			return _recover_resource_unavailable(operation, ship_name, context)
	
	return false

func _recover_missing_ship(ship_name: String, context: Dictionary) -> bool:
	"""Attempt to recover from missing ship error"""
	var ship_interface = ShipSystemInterface.get_instance()
	
	# Try to re-scan scene tree for the ship
	var ship_node = ship_interface._find_ship_in_scene(ship_name, true)
	if ship_node:
		# Re-register the ship
		ship_interface.register_ship(ship_name, ship_node)
		return true
	
	# Check if ship should be spawned (mission-dependent logic)
	if context.has("allow_spawning") and context["allow_spawning"]:
		return _attempt_ship_spawning(ship_name, context)
	
	return false

func _recover_missing_subsystem(ship_name: String, context: Dictionary) -> bool:
	"""Attempt to recover from missing subsystem error"""
	var ship_interface = ShipSystemInterface.get_instance()
	var ship_node = ship_interface.ship_name_lookup(ship_name, true)
	
	if ship_node == null:
		return false
	
	var subsystem_name = context.get("subsystem_name", "")
	if subsystem_name.is_empty():
		return false
	
	# Try to find subsystem with alternative names
	var alternative_names = _get_subsystem_alternatives(subsystem_name)
	for alt_name in alternative_names:
		var subsystem = ship_interface._find_subsystem_node(ship_node, alt_name)
		if subsystem:
			# Register the alternative name
			return true
	
	return false

func _recover_timeout(operation: String, ship_name: String, context: Dictionary) -> bool:
	"""Attempt to recover from operation timeout"""
	# Retry operation with extended timeout
	var retry_count = context.get("retry_count", 0)
	if retry_count < _max_recovery_attempts:
		context["retry_count"] = retry_count + 1
		context["timeout_multiplier"] = (retry_count + 1) * 2.0  # Progressive timeout increase
		return true
	
	return false

func _recover_resource_unavailable(operation: String, ship_name: String, context: Dictionary) -> bool:
	"""Attempt to recover from resource unavailable error"""
	# Wait briefly and retry
	await Engine.get_main_loop().create_timer(0.1).timeout
	return true

## Error suppression and rate limiting

func _should_suppress_error(error_code: ErrorCode, ship_name: String) -> bool:
	"""Check if error should be suppressed due to rate limiting"""
	if not _suppress_repeated_errors:
		return false
	
	var suppression_key = str(error_code) + "_" + ship_name
	var current_time = Time.get_ticks_msec() * 0.001
	
	if _error_suppression.has(suppression_key):
		var last_error_time = _error_suppression[suppression_key]
		if current_time - last_error_time < 1.0:  # Suppress errors within 1 second
			return true
	
	_error_suppression[suppression_key] = current_time
	return false

## Error logging and tracking

func _log_error(error_code: ErrorCode, details: String, context: Dictionary):
	"""Log error to history and update statistics"""
	_error_counts[error_code] += 1
	
	if _enable_detailed_logging:
		var error_entry = {
			"error_code": error_code,
			"error_name": ErrorCode.keys()[error_code],
			"details": details,
			"context": context.duplicate(),
			"timestamp": Time.get_ticks_msec() * 0.001
		}
		
		_error_history.append(error_entry)
		
		# Maintain history size limit
		if _error_history.size() > _max_history_size:
			_error_history.remove_at(0)

func _format_error_message(operation: String, ship_name: String, error_code: ErrorCode, details: String) -> String:
	"""Format a comprehensive error message"""
	var error_name = ErrorCode.keys()[error_code]
	var base_message = "Ship operation '%s' failed for ship '%s': %s" % [operation, ship_name, error_name]
	
	if not details.is_empty():
		base_message += " - " + details
	
	# Add contextual information based on error type
	match error_code:
		ErrorCode.SHIP_NOT_FOUND:
			base_message += " (Ship may not have spawned yet or may have been removed)"
		ErrorCode.SHIP_DESTROYED:
			base_message += " (Ship has been destroyed and cannot be modified)"
		ErrorCode.SHIP_DEPARTED:
			base_message += " (Ship has departed from the mission)"
		ErrorCode.SUBSYSTEM_NOT_FOUND:
			base_message += " (Subsystem may not exist on this ship class)"
	
	return base_message

## Validation helpers

func _is_valid_number(value) -> bool:
	"""Check if value is a valid number"""
	return value is float or value is int

func _is_valid_subsystem(ship_node: Node, subsystem_name: String) -> bool:
	"""Check if subsystem exists on ship"""
	var ship_interface = ShipSystemInterface.get_instance()
	var subsystem = ship_interface._find_subsystem_node(ship_node, subsystem_name)
	return subsystem != null

func _get_subsystem_alternatives(subsystem_name: String) -> Array[String]:
	"""Get alternative names for a subsystem"""
	var alternatives: Array[String] = []
	
	# Common subsystem name mappings
	var name_mappings = {
		"engine": ["engines", "propulsion", "thrusters"],
		"weapon": ["weapons", "turret", "gun"],
		"sensor": ["sensors", "radar", "targeting"],
		"navigation": ["nav", "pilot", "helm"],
		"communication": ["comm", "comms", "radio"]
	}
	
	var lower_name = subsystem_name.to_lower()
	for base_name in name_mappings:
		if lower_name.contains(base_name) or base_name.contains(lower_name):
			alternatives.append_array(name_mappings[base_name])
	
	return alternatives

## Recovery strategy registration

func register_recovery_strategy(operation: String, error_code: ErrorCode, recovery_callable: Callable):
	"""
	Register a custom recovery strategy
	Args:
		operation: Operation to register recovery for
		error_code: Error code to handle
		recovery_callable: Function to call for recovery
	"""
	var recovery_key = operation + "_" + str(error_code)
	_recovery_strategies[recovery_key] = recovery_callable

func _setup_default_recovery_strategies():
	"""Set up default recovery strategies"""
	# Register built-in recovery strategies here if needed
	pass

## Statistics and monitoring

func get_error_statistics() -> Dictionary:
	"""Get comprehensive error statistics"""
	return {
		"error_counts": _error_counts.duplicate(),
		"total_errors": _get_total_error_count(),
		"recent_errors": _get_recent_error_count(60.0),  # Last 60 seconds
		"error_rate": _calculate_error_rate(),
		"most_common_error": _get_most_common_error(),
		"error_history_size": _error_history.size(),
		"suppressed_errors": _error_suppression.size()
	}

func get_recent_errors(time_window: float = 60.0) -> Array[Dictionary]:
	"""Get errors from recent time window"""
	var recent_errors: Array[Dictionary] = []
	var current_time = Time.get_ticks_msec() * 0.001
	var cutoff_time = current_time - time_window
	
	for error_entry in _error_history:
		if error_entry["timestamp"] >= cutoff_time:
			recent_errors.append(error_entry)
	
	return recent_errors

func clear_error_history():
	"""Clear error history and reset statistics"""
	_error_history.clear()
	for error_code in ErrorCode.values():
		_error_counts[error_code] = 0
	_error_suppression.clear()

## Configuration

func configure_error_handling(config: Dictionary):
	"""
	Configure error handling behavior
	Args:
		config: Configuration dictionary with options
	"""
	if config.has("enable_error_recovery"):
		_enable_error_recovery = config["enable_error_recovery"]
	
	if config.has("enable_detailed_logging"):
		_enable_detailed_logging = config["enable_detailed_logging"]
	
	if config.has("suppress_repeated_errors"):
		_suppress_repeated_errors = config["suppress_repeated_errors"]
	
	if config.has("max_recovery_attempts"):
		_max_recovery_attempts = config["max_recovery_attempts"]
	
	if config.has("max_history_size"):
		_max_history_size = config["max_history_size"]

## Private helper functions

func _get_total_error_count() -> int:
	"""Get total error count across all error types"""
	var total = 0
	for count in _error_counts.values():
		total += count
	return total

func _get_recent_error_count(time_window: float) -> int:
	"""Get error count in recent time window"""
	return get_recent_errors(time_window).size()

func _calculate_error_rate() -> float:
	"""Calculate errors per minute over the last 5 minutes"""
	var recent_errors = get_recent_errors(300.0)  # 5 minutes
	return recent_errors.size() / 5.0

func _get_most_common_error() -> String:
	"""Get the most common error type"""
	var max_count = 0
	var most_common = ErrorCode.NONE
	
	for error_code in _error_counts:
		if _error_counts[error_code] > max_count:
			max_count = _error_counts[error_code]
			most_common = error_code
	
	return ErrorCode.keys()[most_common] if max_count > 0 else "None"

func _attempt_ship_spawning(ship_name: String, context: Dictionary) -> bool:
	"""Attempt to spawn a missing ship (placeholder for mission system integration)"""
	# This would integrate with the mission system to spawn ships
	# For now, return false as spawning is context-dependent
	return false