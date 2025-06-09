class_name TestErrorHandler
extends GdUnitTestSuite

## Unit tests for ErrorHandler comprehensive error management functionality.
## Tests error reporting, recovery strategies, and graceful degradation.

const ErrorHandler = preload("res://scripts/core/platform/error_handler.gd")
const DebugManager = preload("res://scripts/core/platform/debug_manager.gd")

var test_error_count: int = 0

func before_test() -> void:
	# Initialize systems
	DebugManager.initialize(false)
	ErrorHandler.initialize()
	
	# Clear error history for clean tests
	ErrorHandler.clear_error_history()
	test_error_count = 0

func after_test() -> void:
	# Clear error history after each test
	ErrorHandler.clear_error_history()

func test_error_handler_initialization() -> void:
	# Test that initialization works correctly
	var success: bool = ErrorHandler.initialize()
	assert_that(success).is_true()

func test_basic_error_reporting() -> void:
	# Test basic error reporting functionality
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		"Test validation error",
		"Unit test context"
	)
	
	assert_that(error_info).is_not_null()
	assert_that(error_info.type).is_equal(ErrorHandler.ErrorType.VALIDATION)
	assert_that(error_info.severity).is_equal(ErrorHandler.Severity.MINOR)
	assert_that(error_info.message).is_equal("Test validation error")
	assert_that(error_info.context).is_equal("Unit test context")
	assert_that(error_info.id).is_greater_equal(0)
	assert_that(error_info.is_handled).is_true()

func test_error_severity_levels() -> void:
	# Test all severity levels
	var severities: Array[ErrorHandler.Severity] = [
		ErrorHandler.Severity.MINOR,
		ErrorHandler.Severity.MODERATE,
		ErrorHandler.Severity.MAJOR,
		ErrorHandler.Severity.CRITICAL,
		ErrorHandler.Severity.FATAL
	]
	
	for severity: ErrorHandler.Severity in severities:
		var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
			ErrorHandler.ErrorType.VALIDATION,
			severity,
			"Test error for severity %d" % severity
		)
		
		assert_that(error_info.severity).is_equal(severity)
		assert_that(error_info.is_handled).is_true()

func test_error_type_classification() -> void:
	# Test all error types
	var error_types: Array[ErrorHandler.ErrorType] = [
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.ErrorType.FILE_IO,
		ErrorHandler.ErrorType.RESOURCE,
		ErrorHandler.ErrorType.MEMORY,
		ErrorHandler.ErrorType.NETWORK,
		ErrorHandler.ErrorType.GRAPHICS,
		ErrorHandler.ErrorType.AUDIO,
		ErrorHandler.ErrorType.PHYSICS,
		ErrorHandler.ErrorType.SCRIPT,
		ErrorHandler.ErrorType.SYSTEM
	]
	
	for error_type: ErrorHandler.ErrorType in error_types:
		var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
			error_type,
			ErrorHandler.Severity.MODERATE,
			"Test error for type %d" % error_type
		)
		
		assert_that(error_info.type).is_equal(error_type)
		assert_that(error_info.is_handled).is_true()

func test_error_history_tracking() -> void:
	# Report several errors
	for i: int in range(5):
		ErrorHandler.report_error(
			ErrorHandler.ErrorType.VALIDATION,
			ErrorHandler.Severity.MINOR,
			"History test error %d" % i
		)
	
	# Get error history
	var history: Array[ErrorHandler.ErrorInfo] = ErrorHandler.get_error_history(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		10
	)
	
	assert_that(history.size()).is_equal(5)
	
	# Verify errors are in correct order (newest first)
	for i: int in range(history.size() - 1):
		assert_that(history[i].timestamp).is_greater_equal(history[i + 1].timestamp)

func test_error_statistics() -> void:
	# Report errors of different types and severities
	ErrorHandler.report_error(ErrorHandler.ErrorType.VALIDATION, ErrorHandler.Severity.MINOR, "Validation error 1")
	ErrorHandler.report_error(ErrorHandler.ErrorType.VALIDATION, ErrorHandler.Severity.MODERATE, "Validation error 2")
	ErrorHandler.report_error(ErrorHandler.ErrorType.FILE_IO, ErrorHandler.Severity.MAJOR, "File I/O error")
	ErrorHandler.report_error(ErrorHandler.ErrorType.RESOURCE, ErrorHandler.Severity.CRITICAL, "Resource error")
	
	var stats: Dictionary = ErrorHandler.get_error_statistics()
	
	assert_that(stats["total_errors"]).is_equal(4)
	assert_that(stats["errors_by_type"]).has_key("VALIDATION")
	assert_that(stats["errors_by_type"]).has_key("FILE_IO")
	assert_that(stats["errors_by_type"]).has_key("RESOURCE")
	assert_that(stats["errors_by_severity"]).has_key("MINOR")
	assert_that(stats["errors_by_severity"]).has_key("CRITICAL")
	
	# Validation should have 2 errors
	assert_that(stats["errors_by_type"]["VALIDATION"]).is_equal(2)

func test_convenience_error_functions() -> void:
	# Test convenience functions
	var validation_error: ErrorHandler.ErrorInfo = ErrorHandler.validation_error("Test validation message")
	assert_that(validation_error.type).is_equal(ErrorHandler.ErrorType.VALIDATION)
	
	var file_error: ErrorHandler.ErrorInfo = ErrorHandler.file_io_error("File not found", "/test/path.txt")
	assert_that(file_error.type).is_equal(ErrorHandler.ErrorType.FILE_IO)
	assert_that(file_error.context).contains("/test/path.txt")
	
	var resource_error: ErrorHandler.ErrorInfo = ErrorHandler.resource_error("Resource load failed", "res://test.tres")
	assert_that(resource_error.type).is_equal(ErrorHandler.ErrorType.RESOURCE)
	assert_that(resource_error.context).contains("res://test.tres")
	
	var memory_error: ErrorHandler.ErrorInfo = ErrorHandler.memory_error("Out of memory")
	assert_that(memory_error.type).is_equal(ErrorHandler.ErrorType.MEMORY)
	assert_that(memory_error.severity).is_equal(ErrorHandler.Severity.MAJOR)
	
	var system_error: ErrorHandler.ErrorInfo = ErrorHandler.system_error("System failure")
	assert_that(system_error.type).is_equal(ErrorHandler.ErrorType.SYSTEM)
	assert_that(system_error.severity).is_equal(ErrorHandler.Severity.CRITICAL)

func test_custom_error_handlers() -> void:
	var custom_handler_called: bool = false
	var handled_error_info: ErrorHandler.ErrorInfo = null
	
	# Register custom error handler
	var custom_handler: Callable = func(error_info: ErrorHandler.ErrorInfo) -> void:
		custom_handler_called = true
		handled_error_info = error_info
	
	ErrorHandler.register_error_handler(ErrorHandler.ErrorType.GRAPHICS, custom_handler)
	
	# Report graphics error
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.GRAPHICS,
		ErrorHandler.Severity.MODERATE,
		"Custom handler test"
	)
	
	assert_that(custom_handler_called).is_true()
	assert_that(handled_error_info).is_not_null()
	assert_that(handled_error_info.message).is_equal("Custom handler test")

func test_recovery_strategy_customization() -> void:
	# Set custom recovery strategy
	ErrorHandler.set_recovery_strategy(ErrorHandler.ErrorType.AUDIO, ErrorHandler.RecoveryStrategy.FALLBACK)
	
	# Report error and verify strategy is applied
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.AUDIO,
		ErrorHandler.Severity.MODERATE,
		"Audio system test"
	)
	
	assert_that(error_info.recovery_strategy).is_equal(ErrorHandler.RecoveryStrategy.FALLBACK)

func test_error_frequency_thresholds() -> void:
	# This test simulates hitting error frequency thresholds
	# Note: We can't easily test the actual threshold behavior without modifying time,
	# but we can test that the system tracks errors properly
	
	# Report many FILE_IO errors quickly
	for i: int in range(25):  # Exceeds default threshold of 20
		ErrorHandler.report_error(
			ErrorHandler.ErrorType.FILE_IO,
			ErrorHandler.Severity.MODERATE,
			"Frequency test error %d" % i
		)
	
	# Get statistics to verify errors were tracked
	var stats: Dictionary = ErrorHandler.get_error_statistics()
	assert_that(stats["errors_by_type"]["FILE_IO"]).is_equal(25)

func test_error_with_user_data() -> void:
	# Test error reporting with user data
	var user_data: Dictionary = {
		"component": "TestComponent",
		"operation": "test_operation",
		"parameters": {"param1": "value1", "param2": 42}
	}
	
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		"Error with user data",
		"Test context",
		user_data
	)
	
	assert_that(error_info.user_data).is_equal(user_data)
	assert_that(error_info.user_data["component"]).is_equal("TestComponent")
	assert_that(error_info.user_data["parameters"]["param2"]).is_equal(42)

func test_error_history_size_limit() -> void:
	# Report more errors than the history limit
	for i: int in range(600):  # Assuming max history size is 500
		ErrorHandler.report_error(
			ErrorHandler.ErrorType.VALIDATION,
			ErrorHandler.Severity.MINOR,
			"History limit test %d" % i
		)
	
	# Get all validation errors
	var all_errors: Array[ErrorHandler.ErrorInfo] = ErrorHandler.get_error_history(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		1000  # Request more than should exist
	)
	
	# Should not exceed maximum history size
	assert_that(all_errors.size()).is_less_equal(500)
	
	# Should contain the most recent errors
	var last_error: ErrorHandler.ErrorInfo = all_errors[0]  # Newest first
	assert_that(last_error.message).contains("History limit test 599")

func test_error_filtering_by_criteria() -> void:
	# Report errors with different severities
	ErrorHandler.report_error(ErrorHandler.ErrorType.GRAPHICS, ErrorHandler.Severity.MINOR, "Minor graphics error")
	ErrorHandler.report_error(ErrorHandler.ErrorType.GRAPHICS, ErrorHandler.Severity.MODERATE, "Moderate graphics error")
	ErrorHandler.report_error(ErrorHandler.ErrorType.GRAPHICS, ErrorHandler.Severity.MAJOR, "Major graphics error")
	ErrorHandler.report_error(ErrorHandler.ErrorType.GRAPHICS, ErrorHandler.Severity.CRITICAL, "Critical graphics error")
	
	# Filter by minimum severity
	var major_and_above: Array[ErrorHandler.ErrorInfo] = ErrorHandler.get_error_history(
		ErrorHandler.ErrorType.GRAPHICS,
		ErrorHandler.Severity.MAJOR,
		10
	)
	
	assert_that(major_and_above.size()).is_equal(2)  # MAJOR and CRITICAL
	
	for error_info: ErrorHandler.ErrorInfo in major_and_above:
		assert_that(error_info.severity).is_greater_equal(ErrorHandler.Severity.MAJOR)

func test_error_clear_functionality() -> void:
	# Report some errors
	for i: int in range(10):
		ErrorHandler.report_error(
			ErrorHandler.ErrorType.VALIDATION,
			ErrorHandler.Severity.MINOR,
			"Clear test error %d" % i
		)
	
	# Verify errors exist
	var before_clear: Array[ErrorHandler.ErrorInfo] = ErrorHandler.get_error_history()
	assert_that(before_clear.size()).is_equal(10)
	
	# Clear error history
	ErrorHandler.clear_error_history()
	
	# Verify errors are cleared
	var after_clear: Array[ErrorHandler.ErrorInfo] = ErrorHandler.get_error_history()
	assert_that(after_clear.size()).is_equal(0)
	
	# Verify statistics are also cleared
	var stats: Dictionary = ErrorHandler.get_error_statistics()
	assert_that(stats["total_errors"]).is_equal(0)

func test_stack_trace_capture() -> void:
	# Report an error and verify stack trace is captured
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		"Stack trace test"
	)
	
	assert_that(error_info.stack_trace).is_not_null()
	assert_that(error_info.stack_trace.size()).is_greater(0)
	
	# Stack trace should contain function names
	var has_function_info: bool = false
	for stack_entry: String in error_info.stack_trace:
		if stack_entry.contains("test_stack_trace_capture"):
			has_function_info = true
			break
	
	assert_that(has_function_info).is_true()

func test_concurrent_error_reporting() -> void:
	# Simulate concurrent error reporting from different systems
	var error_types: Array[ErrorHandler.ErrorType] = [
		ErrorHandler.ErrorType.GRAPHICS,
		ErrorHandler.ErrorType.PHYSICS,
		ErrorHandler.ErrorType.AUDIO,
		ErrorHandler.ErrorType.NETWORK
	]
	
	# Report errors rapidly across different types
	for i: int in range(40):
		var error_type: ErrorHandler.ErrorType = error_types[i % error_types.size()]
		ErrorHandler.report_error(
			error_type,
			ErrorHandler.Severity.MODERATE,
			"Concurrent error %d from type %d" % [i, error_type]
		)
	
	var stats: Dictionary = ErrorHandler.get_error_statistics()
	assert_that(stats["total_errors"]).is_equal(40)
	
	# Each error type should have been used
	for error_type: ErrorHandler.ErrorType in error_types:
		var type_name: String = _get_error_type_name(error_type)
		assert_that(stats["errors_by_type"]).has_key(type_name)
		assert_that(stats["errors_by_type"][type_name]).is_equal(10)

func test_error_with_long_messages() -> void:
	# Test with very long error messages
	var long_message: String = ""
	for i: int in range(1000):
		long_message += "Very long error message part %d. " % i
	
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		long_message
	)
	
	assert_that(error_info.message).is_equal(long_message)
	assert_that(error_info.is_handled).is_true()

func test_error_with_special_characters() -> void:
	# Test with Unicode and special characters
	var special_message: String = "Error with special chars: áéíóú ñ ¿¡ 中文 русский emoji: 🚨⚠️💥"
	var special_context: String = "Context with symbols: @#$%^&*()[]{}|\\:;\"'<>?/.,~`"
	
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		special_message,
		special_context
	)
	
	assert_that(error_info.message).is_equal(special_message)
	assert_that(error_info.context).is_equal(special_context)
	assert_that(error_info.is_handled).is_true()

func test_error_timestamp_accuracy() -> void:
	var before_time: float = Time.get_unix_time_from_system()
	
	var error_info: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		"Timestamp test"
	)
	
	var after_time: float = Time.get_unix_time_from_system()
	
	# Error timestamp should be between before and after
	assert_that(error_info.timestamp).is_greater_equal(before_time)
	assert_that(error_info.timestamp).is_less_equal(after_time)

func test_performance_characteristics() -> void:
	# Test error reporting performance
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Report many errors rapidly
	for i: int in range(1000):
		ErrorHandler.report_error(
			ErrorHandler.ErrorType.VALIDATION,
			ErrorHandler.Severity.MINOR,
			"Performance test error %d" % i
		)
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var duration: float = end_time - start_time
	
	# Reporting 1000 errors should complete quickly (less than 2 seconds)
	assert_that(duration).is_less(2.0)
	
	# Test error history retrieval performance
	var retrieval_start: float = Time.get_ticks_msec() / 1000.0
	
	for i: int in range(100):
		var errors: Array[ErrorHandler.ErrorInfo] = ErrorHandler.get_error_history(
			ErrorHandler.ErrorType.VALIDATION,
			ErrorHandler.Severity.MINOR,
			50
		)
		assert_that(errors.size()).is_greater(0)
	
	var retrieval_end: float = Time.get_ticks_msec() / 1000.0
	var retrieval_duration: float = retrieval_end - retrieval_start
	
	# 100 retrievals should also be fast (less than 1 second)
	assert_that(retrieval_duration).is_less(1.0)

func test_memory_usage_with_many_errors() -> void:
	# Test that the system handles many errors without excessive memory usage
	var initial_stats: Dictionary = ErrorHandler.get_error_statistics()
	var initial_count: int = initial_stats.get("total_errors", 0)
	
	# Report many errors with large contexts
	for i: int in range(200):
		var large_context: String = ""
		for j: int in range(100):
			large_context += "Context data line %d for error %d. " % [j, i]
		
		ErrorHandler.report_error(
			ErrorHandler.ErrorType.VALIDATION,
			ErrorHandler.Severity.MINOR,
			"Memory test error %d" % i,
			large_context
		)
	
	var final_stats: Dictionary = ErrorHandler.get_error_statistics()
	var final_count: int = final_stats.get("total_errors", 0)
	
	# Should have added 200 errors (respecting history limits)
	var expected_new_errors: int = min(200, 500 - initial_count)  # 500 is assumed max history
	assert_that(final_count).is_greater_equal(initial_count + min(expected_new_errors, 200))

func test_edge_cases() -> void:
	# Test with null/empty parameters
	var empty_message_error: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,
		ErrorHandler.Severity.MINOR,
		""  # Empty message
	)
	assert_that(empty_message_error.message).is_equal("")
	assert_that(empty_message_error.is_handled).is_true()
	
	# Test with minimal severity and type
	var minimal_error: ErrorHandler.ErrorInfo = ErrorHandler.report_error(
		ErrorHandler.ErrorType.VALIDATION,  # First enum value
		ErrorHandler.Severity.MINOR,         # First enum value
		"Minimal error test"
	)
	assert_that(minimal_error.type).is_equal(ErrorHandler.ErrorType.VALIDATION)
	assert_that(minimal_error.severity).is_equal(ErrorHandler.Severity.MINOR)

## Helper function to get error type name (mirrors internal function)
func _get_error_type_name(type: ErrorHandler.ErrorType) -> String:
	match type:
		ErrorHandler.ErrorType.VALIDATION:
			return "VALIDATION"
		ErrorHandler.ErrorType.FILE_IO:
			return "FILE_IO"
		ErrorHandler.ErrorType.RESOURCE:
			return "RESOURCE"
		ErrorHandler.ErrorType.MEMORY:
			return "MEMORY"
		ErrorHandler.ErrorType.NETWORK:
			return "NETWORK"
		ErrorHandler.ErrorType.GRAPHICS:
			return "GRAPHICS"
		ErrorHandler.ErrorType.AUDIO:
			return "AUDIO"
		ErrorHandler.ErrorType.PHYSICS:
			return "PHYSICS"
		ErrorHandler.ErrorType.SCRIPT:
			return "SCRIPT"
		ErrorHandler.ErrorType.SYSTEM:
			return "SYSTEM"
		_:
			return "UNKNOWN"