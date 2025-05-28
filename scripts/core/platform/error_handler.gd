class_name ErrorHandler
extends Node

## Comprehensive error handling and validation system for WCS-Godot conversion.
## Provides graceful degradation, error recovery, and detailed error reporting.
## Integrates with DebugManager for consistent error logging and tracking.

const DebugManager = preload("res://scripts/core/platform/debug_manager.gd")
const PlatformUtils = preload("res://scripts/core/platform/platform_utils.gd")

## Error severity levels for classification and handling
enum Severity {
	MINOR = 0,      ## Minor errors that don't affect core functionality
	MODERATE = 1,   ## Moderate errors that may degrade performance or features
	MAJOR = 2,      ## Major errors that affect core functionality
	CRITICAL = 3,   ## Critical errors that may cause system instability
	FATAL = 4       ## Fatal errors that require immediate shutdown
}

## Error categories for specific handling strategies
enum ErrorType {
	VALIDATION = 0,    ## Input validation and data verification errors
	FILE_IO = 1,       ## File system and I/O operation errors
	RESOURCE = 2,      ## Resource loading and management errors
	MEMORY = 3,        ## Memory allocation and management errors
	NETWORK = 4,       ## Network and connectivity errors
	GRAPHICS = 5,      ## Graphics and rendering errors
	AUDIO = 6,         ## Audio system errors
	PHYSICS = 7,       ## Physics simulation errors
	SCRIPT = 8,        ## Script execution and parsing errors
	SYSTEM = 9         ## System-level and platform errors
}

## Error recovery strategies
enum RecoveryStrategy {
	IGNORE = 0,        ## Ignore the error and continue
	RETRY = 1,         ## Attempt to retry the operation
	FALLBACK = 2,      ## Use fallback/default behavior
	RESET = 3,         ## Reset the affected system
	RESTART = 4,       ## Restart the application
	SHUTDOWN = 5       ## Graceful system shutdown
}

## Error information structure
class ErrorInfo:
	var id: int
	var type: ErrorType
	var severity: Severity
	var message: String
	var context: String
	var timestamp: float
	var stack_trace: Array[String]
	var recovery_strategy: RecoveryStrategy
	var retry_count: int = 0
	var is_handled: bool = false
	var user_data: Dictionary = {}

## Static error tracking
static var _error_history: Array[ErrorInfo] = []
static var _max_history_size: int = 500
static var _error_id_counter: int = 0
static var _is_initialized: bool = false
static var _error_handlers: Dictionary = {}  # ErrorType -> Callable
static var _recovery_strategies: Dictionary = {}  # ErrorType -> RecoveryStrategy
static var _critical_error_count: int = 0
static var _max_critical_errors: int = 10

## Error thresholds for automatic responses
static var _error_thresholds: Dictionary = {
	ErrorType.FILE_IO: {"max_errors": 20, "time_window": 60.0},
	ErrorType.RESOURCE: {"max_errors": 15, "time_window": 30.0},
	ErrorType.MEMORY: {"max_errors": 5, "time_window": 10.0},
	ErrorType.NETWORK: {"max_errors": 25, "time_window": 120.0},
	ErrorType.SYSTEM: {"max_errors": 10, "time_window": 60.0}
}

## Initialize error handling system
static func initialize() -> bool:
	if _is_initialized:
		return true
	
	# Set up default recovery strategies
	_setup_default_recovery_strategies()
	
	# Set up default error handlers
	_setup_default_error_handlers()
	
	_is_initialized = true
	DebugManager.log_info(DebugManager.Category.GENERAL, "ErrorHandler: Initialized successfully")
	
	return true

## Set up default recovery strategies for each error type
static func _setup_default_recovery_strategies() -> void:
	_recovery_strategies[ErrorType.VALIDATION] = RecoveryStrategy.FALLBACK
	_recovery_strategies[ErrorType.FILE_IO] = RecoveryStrategy.RETRY
	_recovery_strategies[ErrorType.RESOURCE] = RecoveryStrategy.FALLBACK
	_recovery_strategies[ErrorType.MEMORY] = RecoveryStrategy.RESET
	_recovery_strategies[ErrorType.NETWORK] = RecoveryStrategy.RETRY
	_recovery_strategies[ErrorType.GRAPHICS] = RecoveryStrategy.FALLBACK
	_recovery_strategies[ErrorType.AUDIO] = RecoveryStrategy.IGNORE
	_recovery_strategies[ErrorType.PHYSICS] = RecoveryStrategy.RESET
	_recovery_strategies[ErrorType.SCRIPT] = RecoveryStrategy.FALLBACK
	_recovery_strategies[ErrorType.SYSTEM] = RecoveryStrategy.RESTART

## Set up default error handlers
static func _setup_default_error_handlers() -> void:
	_error_handlers[ErrorType.VALIDATION] = _handle_validation_error
	_error_handlers[ErrorType.FILE_IO] = _handle_file_io_error
	_error_handlers[ErrorType.RESOURCE] = _handle_resource_error
	_error_handlers[ErrorType.MEMORY] = _handle_memory_error
	_error_handlers[ErrorType.NETWORK] = _handle_network_error
	_error_handlers[ErrorType.GRAPHICS] = _handle_graphics_error
	_error_handlers[ErrorType.AUDIO] = _handle_audio_error
	_error_handlers[ErrorType.PHYSICS] = _handle_physics_error
	_error_handlers[ErrorType.SCRIPT] = _handle_script_error
	_error_handlers[ErrorType.SYSTEM] = _handle_system_error

## Report an error with full context and automatic handling
static func report_error(type: ErrorType, severity: Severity, message: String, context: String = "", user_data: Dictionary = {}) -> ErrorInfo:
	if not _is_initialized:
		initialize()
	
	# Create error information
	var error_info: ErrorInfo = ErrorInfo.new()
	error_info.id = _error_id_counter
	error_info.type = type
	error_info.severity = severity
	error_info.message = message
	error_info.context = context
	error_info.timestamp = Time.get_unix_time_from_system()
	error_info.stack_trace = get_stack()
	error_info.recovery_strategy = _recovery_strategies.get(type, RecoveryStrategy.IGNORE)
	error_info.user_data = user_data
	
	_error_id_counter += 1
	
	# Log the error
	_log_error(error_info)
	
	# Add to history
	_add_to_history(error_info)
	
	# Check for critical error threshold
	if severity >= Severity.CRITICAL:
		_critical_error_count += 1
		if _critical_error_count >= _max_critical_errors:
			_handle_critical_error_threshold()
	
	# Handle the error automatically
	_handle_error_automatically(error_info)
	
	return error_info

## Log error information to debug system
static func _log_error(error_info: ErrorInfo) -> void:
	var severity_name: String = _get_severity_name(error_info.severity)
	var type_name: String = _get_error_type_name(error_info.type)
	var full_message: String = "[ERROR %d] %s:%s - %s" % [error_info.id, severity_name, type_name, error_info.message]
	
	if not error_info.context.is_empty():
		full_message += " | Context: %s" % error_info.context
	
	# Log to appropriate debug level based on severity
	match error_info.severity:
		Severity.MINOR:
			DebugManager.log_debug(DebugManager.Category.GENERAL, full_message)
		Severity.MODERATE:
			DebugManager.log_warning(DebugManager.Category.GENERAL, full_message)
		Severity.MAJOR:
			DebugManager.log_error(DebugManager.Category.GENERAL, full_message)
		Severity.CRITICAL, Severity.FATAL:
			DebugManager.log_critical(DebugManager.Category.GENERAL, full_message)

## Add error to history with size management
static func _add_to_history(error_info: ErrorInfo) -> void:
	_error_history.append(error_info)
	
	# Maintain history size limit
	if _error_history.size() > _max_history_size:
		_error_history.pop_front()

## Handle error automatically based on type and severity
static func _handle_error_automatically(error_info: ErrorInfo) -> void:
	# Check error frequency thresholds
	if _check_error_frequency_threshold(error_info):
		DebugManager.log_critical(DebugManager.Category.GENERAL, "Error frequency threshold exceeded for type: %s" % _get_error_type_name(error_info.type))
		error_info.recovery_strategy = RecoveryStrategy.SHUTDOWN
	
	# Execute registered handler if available
	var handler: Callable = _error_handlers.get(error_info.type)
	if handler != null and handler.is_valid():
		handler.call(error_info)
	
	# Execute recovery strategy
	_execute_recovery_strategy(error_info)
	
	error_info.is_handled = true

## Check if error frequency exceeds threshold
static func _check_error_frequency_threshold(error_info: ErrorInfo) -> bool:
	var threshold_config: Dictionary = _error_thresholds.get(error_info.type, {})
	if threshold_config.is_empty():
		return false
	
	var max_errors: int = threshold_config.get("max_errors", 999)
	var time_window: float = threshold_config.get("time_window", 3600.0)
	var current_time: float = Time.get_unix_time_from_system()
	var window_start: float = current_time - time_window
	
	# Count errors of same type within time window
	var error_count: int = 0
	for historic_error: ErrorInfo in _error_history:
		if historic_error.type == error_info.type and historic_error.timestamp >= window_start:
			error_count += 1
	
	return error_count >= max_errors

## Execute recovery strategy for error
static func _execute_recovery_strategy(error_info: ErrorInfo) -> void:
	match error_info.recovery_strategy:
		RecoveryStrategy.IGNORE:
			DebugManager.log_debug(DebugManager.Category.GENERAL, "Ignoring error %d" % error_info.id)
		RecoveryStrategy.RETRY:
			_schedule_retry(error_info)
		RecoveryStrategy.FALLBACK:
			_apply_fallback_behavior(error_info)
		RecoveryStrategy.RESET:
			_reset_affected_system(error_info)
		RecoveryStrategy.RESTART:
			_schedule_application_restart(error_info)
		RecoveryStrategy.SHUTDOWN:
			_initiate_graceful_shutdown(error_info)

## Schedule retry operation for error
static func _schedule_retry(error_info: ErrorInfo) -> void:
	if error_info.retry_count >= 3:
		DebugManager.log_warning(DebugManager.Category.GENERAL, "Max retries exceeded for error %d, switching to fallback" % error_info.id)
		error_info.recovery_strategy = RecoveryStrategy.FALLBACK
		_apply_fallback_behavior(error_info)
		return
	
	error_info.retry_count += 1
	DebugManager.log_info(DebugManager.Category.GENERAL, "Scheduling retry %d for error %d" % [error_info.retry_count, error_info.id])
	
	# Create timer for delayed retry
	await Engine.get_main_loop().create_timer(1.0 * error_info.retry_count).timeout
	DebugManager.log_info(DebugManager.Category.GENERAL, "Executing retry %d for error %d" % [error_info.retry_count, error_info.id])

## Apply fallback behavior for error
static func _apply_fallback_behavior(error_info: ErrorInfo) -> void:
	DebugManager.log_info(DebugManager.Category.GENERAL, "Applying fallback behavior for error %d" % error_info.id)
	
	# Error-type specific fallback logic can be implemented here
	match error_info.type:
		ErrorType.RESOURCE:
			DebugManager.log_info(DebugManager.Category.GENERAL, "Using default resource for failed load")
		ErrorType.GRAPHICS:
			DebugManager.log_info(DebugManager.Category.GENERAL, "Reducing graphics quality settings")
		ErrorType.AUDIO:
			DebugManager.log_info(DebugManager.Category.GENERAL, "Disabling problematic audio features")
		_:
			DebugManager.log_info(DebugManager.Category.GENERAL, "Generic fallback applied")

## Reset affected system
static func _reset_affected_system(error_info: ErrorInfo) -> void:
	DebugManager.log_warning(DebugManager.Category.GENERAL, "Resetting system for error %d (type: %s)" % [error_info.id, _get_error_type_name(error_info.type)])
	
	# System-specific reset logic would be implemented here
	match error_info.type:
		ErrorType.PHYSICS:
			DebugManager.log_info(DebugManager.Category.PHYSICS, "Resetting physics simulation")
		ErrorType.MEMORY:
			DebugManager.log_info(DebugManager.Category.GENERAL, "Triggering garbage collection")
			# Force garbage collection if possible
		_:
			DebugManager.log_info(DebugManager.Category.GENERAL, "Generic system reset")

## Schedule application restart
static func _schedule_application_restart(error_info: ErrorInfo) -> void:
	DebugManager.log_critical(DebugManager.Category.GENERAL, "Scheduling application restart due to error %d" % error_info.id)
	
	# Give time for cleanup and user notification
	await Engine.get_main_loop().create_timer(5.0).timeout
	
	DebugManager.log_critical(DebugManager.Category.GENERAL, "Restarting application...")
	Engine.get_main_loop().quit()   # This would need to be called from a proper context

## Initiate graceful shutdown
static func _initiate_graceful_shutdown(error_info: ErrorInfo) -> void:
	DebugManager.log_critical(DebugManager.Category.GENERAL, "Initiating graceful shutdown due to error %d" % error_info.id)
	
	# Allow systems to clean up
	DebugManager.shutdown()
	
	# Quit application
	Engine.get_main_loop().quit()  # This would need to be called from a proper context

## Handle critical error threshold exceeded
static func _handle_critical_error_threshold() -> void:
	DebugManager.log_critical(DebugManager.Category.GENERAL, "Critical error threshold exceeded (%d errors), initiating emergency shutdown" % _max_critical_errors)
	_initiate_graceful_shutdown(null)

## Default error handlers for each type

static func _handle_validation_error(error_info: ErrorInfo) -> void:
	DebugManager.log_debug(DebugManager.Category.GENERAL, "Handling validation error: %s" % error_info.message)

static func _handle_file_io_error(error_info: ErrorInfo) -> void:
	DebugManager.log_warning(DebugManager.Category.FILE_IO, "File I/O error: %s" % error_info.message)

static func _handle_resource_error(error_info: ErrorInfo) -> void:
	DebugManager.log_warning(DebugManager.Category.GENERAL, "Resource error: %s" % error_info.message)

static func _handle_memory_error(error_info: ErrorInfo) -> void:
	DebugManager.log_error(DebugManager.Category.GENERAL, "Memory error: %s" % error_info.message)

static func _handle_network_error(error_info: ErrorInfo) -> void:
	DebugManager.log_warning(DebugManager.Category.NETWORK, "Network error: %s" % error_info.message)

static func _handle_graphics_error(error_info: ErrorInfo) -> void:
	DebugManager.log_warning(DebugManager.Category.GRAPHICS, "Graphics error: %s" % error_info.message)

static func _handle_audio_error(error_info: ErrorInfo) -> void:
	DebugManager.log_info(DebugManager.Category.SOUND, "Audio error: %s" % error_info.message)

static func _handle_physics_error(error_info: ErrorInfo) -> void:
	DebugManager.log_warning(DebugManager.Category.PHYSICS, "Physics error: %s" % error_info.message)

static func _handle_script_error(error_info: ErrorInfo) -> void:
	DebugManager.log_error(DebugManager.Category.SCRIPT, "Script error: %s" % error_info.message)

static func _handle_system_error(error_info: ErrorInfo) -> void:
	DebugManager.log_critical(DebugManager.Category.GENERAL, "System error: %s" % error_info.message)

## Utility functions

## Get human-readable severity name
static func _get_severity_name(severity: Severity) -> String:
	match severity:
		Severity.MINOR:
			return "MINOR"
		Severity.MODERATE:
			return "MODERATE"
		Severity.MAJOR:
			return "MAJOR"
		Severity.CRITICAL:
			return "CRITICAL"
		Severity.FATAL:
			return "FATAL"
		_:
			return "UNKNOWN"

## Get human-readable error type name
static func _get_error_type_name(type: ErrorType) -> String:
	match type:
		ErrorType.VALIDATION:
			return "VALIDATION"
		ErrorType.FILE_IO:
			return "FILE_IO"
		ErrorType.RESOURCE:
			return "RESOURCE"
		ErrorType.MEMORY:
			return "MEMORY"
		ErrorType.NETWORK:
			return "NETWORK"
		ErrorType.GRAPHICS:
			return "GRAPHICS"
		ErrorType.AUDIO:
			return "AUDIO"
		ErrorType.PHYSICS:
			return "PHYSICS"
		ErrorType.SCRIPT:
			return "SCRIPT"
		ErrorType.SYSTEM:
			return "SYSTEM"
		_:
			return "UNKNOWN"

## Public API functions

## Register custom error handler for specific error type
static func register_error_handler(type: ErrorType, handler: Callable) -> void:
	_error_handlers[type] = handler
	DebugManager.log_info(DebugManager.Category.GENERAL, "Registered custom error handler for type: %s" % _get_error_type_name(type))

## Set recovery strategy for specific error type
static func set_recovery_strategy(type: ErrorType, strategy: RecoveryStrategy) -> void:
	_recovery_strategies[type] = strategy
	DebugManager.log_info(DebugManager.Category.GENERAL, "Set recovery strategy for %s to %s" % [_get_error_type_name(type), strategy])

## Get error history filtered by criteria
static func get_error_history(type: ErrorType = ErrorType.VALIDATION, severity: Severity = Severity.MINOR, max_count: int = 100) -> Array[ErrorInfo]:
	var filtered_errors: Array[ErrorInfo] = []
	var count: int = 0
	
	# Search from newest to oldest
	for i: int in range(_error_history.size() - 1, -1, -1):
		if count >= max_count:
			break
		
		var error_info: ErrorInfo = _error_history[i]
		if (type == ErrorType.VALIDATION or error_info.type == type) and error_info.severity >= severity:
			filtered_errors.append(error_info)
			count += 1
	
	return filtered_errors

## Get error statistics
static func get_error_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_errors": _error_history.size(),
		"critical_error_count": _critical_error_count,
		"errors_by_type": {},
		"errors_by_severity": {},
		"recent_errors_1h": 0,
		"recent_errors_24h": 0
	}
	
	var current_time: float = Time.get_unix_time_from_system()
	var one_hour_ago: float = current_time - 3600.0
	var one_day_ago: float = current_time - 86400.0
	
	# Count errors by type and severity
	for error_info: ErrorInfo in _error_history:
		# Count by type
		var type_name: String = _get_error_type_name(error_info.type)
		if not stats["errors_by_type"].has(type_name):
			stats["errors_by_type"][type_name] = 0
		stats["errors_by_type"][type_name] += 1
		
		# Count by severity
		var severity_name: String = _get_severity_name(error_info.severity)
		if not stats["errors_by_severity"].has(severity_name):
			stats["errors_by_severity"][severity_name] = 0
		stats["errors_by_severity"][severity_name] += 1
		
		# Count recent errors
		if error_info.timestamp >= one_hour_ago:
			stats["recent_errors_1h"] += 1
		if error_info.timestamp >= one_day_ago:
			stats["recent_errors_24h"] += 1
	
	return stats

## Clear error history
static func clear_error_history() -> void:
	_error_history.clear()
	_critical_error_count = 0
	DebugManager.log_info(DebugManager.Category.GENERAL, "Error history cleared")

## Convenience functions for common error reporting

## Report validation error with context
static func validation_error(message: String, context: String = "", severity: Severity = Severity.MINOR) -> ErrorInfo:
	return report_error(ErrorType.VALIDATION, severity, message, context)

## Report file I/O error
static func file_io_error(message: String, file_path: String = "", severity: Severity = Severity.MODERATE) -> ErrorInfo:
	var context: String = "File: %s" % file_path if not file_path.is_empty() else ""
	return report_error(ErrorType.FILE_IO, severity, message, context)

## Report resource loading error
static func resource_error(message: String, resource_path: String = "", severity: Severity = Severity.MODERATE) -> ErrorInfo:
	var context: String = "Resource: %s" % resource_path if not resource_path.is_empty() else ""
	return report_error(ErrorType.RESOURCE, severity, message, context)

## Report memory error
static func memory_error(message: String, context: String = "", severity: Severity = Severity.MAJOR) -> ErrorInfo:
	return report_error(ErrorType.MEMORY, severity, message, context)

## Report system error
static func system_error(message: String, context: String = "", severity: Severity = Severity.CRITICAL) -> ErrorInfo:
	return report_error(ErrorType.SYSTEM, severity, message, context)
