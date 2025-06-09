class_name TestDebugManager
extends GdUnitTestSuite

## Unit tests for DebugManager cross-platform debug output functionality.
## Tests WCS-compatible debug output replacement using Godot's print system.

const DebugManager = preload("res://scripts/core/platform/debug_manager.gd")
const SettingsManager = preload("res://scripts/core/platform/settings_manager.gd")

var test_log_file: String = "user://test_debug_log.txt"
var original_settings: Dictionary = {}

func before_test() -> void:
	# Initialize both debug and settings managers
	DebugManager.initialize(false)  # Start without file logging for most tests
	SettingsManager.initialize()
	
	# Clear any existing message buffer
	DebugManager.clear_message_buffer()

func after_test() -> void:
	# Clean up test log file if it exists
	if FileAccess.file_exists(test_log_file):
		DirAccess.remove_absolute(test_log_file)
	
	# Disable file logging to clean up
	DebugManager.disable_file_logging()

func after_all() -> void:
	# Shutdown systems
	DebugManager.shutdown()
	SettingsManager.shutdown()

func test_debug_manager_initialization() -> void:
	# Test that initialization works correctly
	var success: bool = DebugManager.initialize()
	assert_that(success).is_true()
	
	# Test initialization with file logging
	var file_success: bool = DebugManager.initialize(true, test_log_file)
	assert_that(file_success).is_true()
	
	# Verify debug stats
	var stats: Dictionary = DebugManager.get_debug_stats()
	assert_that(stats["initialized"]).is_true()
	assert_that(stats).has_key("log_level")
	assert_that(stats).has_key("buffer_size")

func test_log_level_filtering() -> void:
	# Set log level to WARNING
	DebugManager.set_log_level(DebugManager.LogLevel.WARNING)
	assert_that(DebugManager.get_log_level()).is_equal(DebugManager.LogLevel.WARNING)
	
	# Clear buffer before test
	DebugManager.clear_message_buffer()
	
	# Log messages at different levels
	DebugManager.log_trace(DebugManager.Category.GENERAL, "Trace message")
	DebugManager.log_debug(DebugManager.Category.GENERAL, "Debug message")
	DebugManager.log_info(DebugManager.Category.GENERAL, "Info message")
	DebugManager.log_warning(DebugManager.Category.GENERAL, "Warning message")
	DebugManager.log_error(DebugManager.Category.GENERAL, "Error message")
	DebugManager.log_critical(DebugManager.Category.GENERAL, "Critical message")
	
	# Get recent messages
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(10)
	
	# Should only have WARNING, ERROR, and CRITICAL messages (3 total)
	assert_that(messages.size()).is_equal(3)
	
	# Verify message levels
	for message: Dictionary in messages:
		var level: DebugManager.LogLevel = message.get("level", DebugManager.LogLevel.TRACE)
		assert_that(level).is_greater_equal(DebugManager.LogLevel.WARNING)

func test_category_filtering() -> void:
	# Disable all categories except GRAPHICS
	for i: int in range(DebugManager.Category.size()):
		DebugManager.set_category_enabled(i, false)
	
	DebugManager.set_category_enabled(DebugManager.Category.GRAPHICS, true)
	
	# Clear buffer
	DebugManager.clear_message_buffer()
	
	# Log messages to different categories
	DebugManager.log_info(DebugManager.Category.GENERAL, "General message")
	DebugManager.log_info(DebugManager.Category.PHYSICS, "Physics message")
	DebugManager.log_info(DebugManager.Category.GRAPHICS, "Graphics message")
	DebugManager.log_info(DebugManager.Category.SOUND, "Sound message")
	
	# Get recent messages
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(10)
	
	# Should only have 1 message (GRAPHICS)
	assert_that(messages.size()).is_equal(1)
	
	# Verify it's the graphics message
	var message: Dictionary = messages[0]
	assert_that(message.get("category", -1)).is_equal(DebugManager.Category.GRAPHICS)
	assert_that(message.get("message", "")).contains("Graphics message")
	
	# Re-enable all categories for other tests
	for i: int in range(DebugManager.Category.size()):
		DebugManager.set_category_enabled(i, true)

func test_convenience_logging_functions() -> void:
	DebugManager.clear_message_buffer()
	
	# Test all convenience functions
	DebugManager.log_trace(DebugManager.Category.GENERAL, "Trace test")
	DebugManager.log_debug(DebugManager.Category.PHYSICS, "Debug test")
	DebugManager.log_info(DebugManager.Category.AI, "Info test")
	DebugManager.log_warning(DebugManager.Category.GRAPHICS, "Warning test")
	DebugManager.log_error(DebugManager.Category.SOUND, "Error test")
	DebugManager.log_critical(DebugManager.Category.NETWORK, "Critical test")
	
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(10)
	assert_that(messages.size()).is_equal(6)
	
	# Verify message contents and levels
	var expected_levels: Array[DebugManager.LogLevel] = [
		DebugManager.LogLevel.TRACE,
		DebugManager.LogLevel.DEBUG,
		DebugManager.LogLevel.INFO,
		DebugManager.LogLevel.WARNING,
		DebugManager.LogLevel.ERROR,
		DebugManager.LogLevel.CRITICAL
	]
	
	for i: int in range(messages.size()):
		var message: Dictionary = messages[i]
		assert_that(message.get("level", -1)).is_equal(expected_levels[i])

func test_wcs_compatible_outwnd_functions() -> void:
	DebugManager.clear_message_buffer()
	
	# Test outwnd_printf without arguments
	DebugManager.outwnd_printf("general", "Simple message")
	
	# Test outwnd_printf with arguments
	DebugManager.outwnd_printf("physics", "Player ship position: %s, %s, %s", ["100.5", "200.3", "50.7"])
	
	# Test outwnd_printf2 (simplified version)
	DebugManager.outwnd_printf2("Health: %d/%d", ["75", "100"])
	
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(10)
	assert_that(messages.size()).is_equal(3)
	
	# Verify category mapping
	var physics_message: Dictionary = messages[1]
	assert_that(physics_message.get("category", -1)).is_equal(DebugManager.Category.PHYSICS)
	assert_that(physics_message.get("message", "")).contains("Player ship position")

func test_wcs_category_id_mapping() -> void:
	DebugManager.clear_message_buffer()
	
	# Test various WCS debug IDs
	var test_cases: Array[Dictionary] = [
		{"id": "general", "expected_category": DebugManager.Category.GENERAL},
		{"id": "phys", "expected_category": DebugManager.Category.PHYSICS},
		{"id": "ai", "expected_category": DebugManager.Category.AI},
		{"id": "gfx", "expected_category": DebugManager.Category.GRAPHICS},
		{"id": "sound", "expected_category": DebugManager.Category.SOUND},
		{"id": "net", "expected_category": DebugManager.Category.NETWORK},
		{"id": "input", "expected_category": DebugManager.Category.INPUT},
		{"id": "file", "expected_category": DebugManager.Category.FILE_IO},
		{"id": "script", "expected_category": DebugManager.Category.SCRIPT},
		{"id": "perf", "expected_category": DebugManager.Category.PERFORMANCE}
	]
	
	for test_case: Dictionary in test_cases:
		var id: String = test_case["id"]
		var expected: DebugManager.Category = test_case["expected_category"]
		
		DebugManager.outwnd_printf(id, "Test message for %s" % id)
	
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(test_cases.size())
	assert_that(messages.size()).is_equal(test_cases.size())
	
	for i: int in range(messages.size()):
		var message: Dictionary = messages[i]
		var expected_category: DebugManager.Category = test_cases[i]["expected_category"]
		assert_that(message.get("category", -1)).is_equal(expected_category)

func test_file_logging_functionality() -> void:
	# Enable file logging
	var enable_success: bool = DebugManager.enable_file_logging(test_log_file)
	assert_that(enable_success).is_true()
	
	# Log some messages
	DebugManager.log_info(DebugManager.Category.GENERAL, "File logging test message 1")
	DebugManager.log_warning(DebugManager.Category.GRAPHICS, "File logging test message 2")
	DebugManager.log_error(DebugManager.Category.SOUND, "File logging test message 3")
	
	# Disable file logging to flush and close file
	DebugManager.disable_file_logging()
	
	# Verify log file exists and contains our messages
	assert_that(FileAccess.file_exists(test_log_file)).is_true()
	
	var log_file: FileAccess = FileAccess.open(test_log_file, FileAccess.READ)
	assert_that(log_file).is_not_null()
	
	var log_content: String = log_file.get_as_text()
	log_file.close()
	
	assert_that(log_content).contains("File logging test message 1")
	assert_that(log_content).contains("File logging test message 2")
	assert_that(log_content).contains("File logging test message 3")
	assert_that(log_content).contains("WCS-Godot Debug Log")

func test_message_buffer_management() -> void:
	DebugManager.clear_message_buffer()
	
	# Add messages to buffer
	for i: int in range(50):
		DebugManager.log_info(DebugManager.Category.GENERAL, "Buffer test message %d" % i)
	
	var all_messages: Array[Dictionary] = DebugManager.get_recent_messages(100)
	assert_that(all_messages.size()).is_equal(50)
	
	# Test limited retrieval
	var limited_messages: Array[Dictionary] = DebugManager.get_recent_messages(10)
	assert_that(limited_messages.size()).is_equal(10)
	
	# Verify messages are in chronological order (newest last)
	var first_message: Dictionary = limited_messages[0]
	var last_message: Dictionary = limited_messages[-1]
	assert_that(first_message.get("timestamp", 0.0)).is_less_equal(last_message.get("timestamp", 0.0))

func test_filtered_message_retrieval() -> void:
	DebugManager.clear_message_buffer()
	
	# Add messages with different levels and categories
	DebugManager.log_info(DebugManager.Category.GENERAL, "General info")
	DebugManager.log_warning(DebugManager.Category.PHYSICS, "Physics warning")
	DebugManager.log_error(DebugManager.Category.GRAPHICS, "Graphics error")
	DebugManager.log_info(DebugManager.Category.PHYSICS, "Physics info")
	DebugManager.log_critical(DebugManager.Category.SOUND, "Sound critical")
	
	# Test filtering by minimum level
	var warning_and_above: Array[Dictionary] = DebugManager.get_filtered_messages(DebugManager.LogLevel.WARNING, DebugManager.Category.GENERAL, 10)
	var warning_count: int = 0
	for message: Dictionary in warning_and_above:
		var level: DebugManager.LogLevel = message.get("level", DebugManager.LogLevel.TRACE)
		if level >= DebugManager.LogLevel.WARNING:
			warning_count += 1
	assert_that(warning_count).is_greater(0)
	
	# Test filtering by category
	var physics_messages: Array[Dictionary] = DebugManager.get_filtered_messages(DebugManager.LogLevel.TRACE, DebugManager.Category.PHYSICS, 10)
	for message: Dictionary in physics_messages:
		var category: DebugManager.Category = message.get("category", DebugManager.Category.GENERAL)
		assert_that(category).is_equal(DebugManager.Category.PHYSICS)

func test_performance_logging() -> void:
	DebugManager.clear_message_buffer()
	
	# Test performance logging
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Simulate some work
	await get_tree().create_timer(0.1).timeout
	
	DebugManager.log_performance(DebugManager.Category.PERFORMANCE, "Test operation", start_time)
	
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(5)
	assert_that(messages.size()).is_greater(0)
	
	var perf_message: Dictionary = messages[-1]
	assert_that(perf_message.get("message", "")).contains("Test operation completed")
	assert_that(perf_message.get("category", -1)).is_equal(DebugManager.Category.PERFORMANCE)

func test_time_operation_wrapper() -> void:
	DebugManager.clear_message_buffer()
	
	# Test time_operation function
	var test_callable: Callable = func() -> String:
		await get_tree().create_timer(0.05).timeout  # 50ms delay
		return "operation_result"
	
	var result: Variant = await DebugManager.time_operation(DebugManager.Category.PERFORMANCE, "Wrapped operation", test_callable)
	
	# Verify result is returned correctly
	assert_that(result).is_equal("operation_result")
	
	# Verify timing message was logged
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(5)
	var found_timing: bool = false
	for message: Dictionary in messages:
		if message.get("message", "").contains("Wrapped operation completed"):
			found_timing = true
			break
	assert_that(found_timing).is_true()

func test_debug_stats_and_configuration() -> void:
	# Test getting debug statistics
	var stats: Dictionary = DebugManager.get_debug_stats()
	
	assert_that(stats).has_key("initialized")
	assert_that(stats).has_key("log_level")
	assert_that(stats).has_key("log_level_name")
	assert_that(stats).has_key("file_logging")
	assert_that(stats).has_key("buffer_size")
	assert_that(stats).has_key("max_buffer_size")
	
	# Test configuration dump
	DebugManager.clear_message_buffer()
	DebugManager.dump_config()
	
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(20)
	var found_config_dump: bool = false
	for message: Dictionary in messages:
		if message.get("message", "").contains("Debug System Configuration"):
			found_config_dump = true
			break
	assert_that(found_config_dump).is_true()

func test_settings_integration() -> void:
	# Test loading configuration from settings
	SettingsManager.os_config_write_uint("Debug", "log_level", DebugManager.LogLevel.ERROR)
	SettingsManager.os_config_write_uint("Debug", "file_logging", 1)
	SettingsManager.os_config_write_string("Debug", "log_file_path", test_log_file)
	SettingsManager.os_config_write_uint("Debug", "category_general", 1)
	SettingsManager.os_config_write_uint("Debug", "category_physics", 0)
	
	DebugManager.load_config_from_settings()
	
	# Verify settings were applied
	assert_that(DebugManager.get_log_level()).is_equal(DebugManager.LogLevel.ERROR)
	assert_that(DebugManager.is_category_enabled(DebugManager.Category.GENERAL)).is_true()
	assert_that(DebugManager.is_category_enabled(DebugManager.Category.PHYSICS)).is_false()
	
	# Test saving configuration to settings
	DebugManager.set_log_level(DebugManager.LogLevel.WARNING)
	DebugManager.set_category_enabled(DebugManager.Category.SOUND, false)
	
	DebugManager.save_config_to_settings()
	
	# Verify settings were saved
	var saved_level: int = SettingsManager.os_config_read_uint("Debug", "log_level", 0)
	assert_that(saved_level).is_equal(DebugManager.LogLevel.WARNING)
	
	var saved_sound_category: int = SettingsManager.os_config_read_uint("Debug", "category_sound", 1)
	assert_that(saved_sound_category).is_equal(0)

func test_edge_cases_and_error_conditions() -> void:
	# Test with empty messages
	DebugManager.log_info(DebugManager.Category.GENERAL, "")
	
	# Test with very long messages
	var long_message: String = ""
	for i: int in range(1000):
		long_message += "Very long message part %d. " % i
	
	DebugManager.log_info(DebugManager.Category.GENERAL, long_message)
	
	# Test with special characters
	DebugManager.log_info(DebugManager.Category.GENERAL, "Message with special chars: áéíóú ñ ¿¡ 中文 русский")
	
	# Test with null/invalid category (should default to GENERAL)
	DebugManager.outwnd_printf("invalid_category", "Test message")
	
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(10)
	assert_that(messages.size()).is_greater(0)
	
	# Verify all messages were logged without errors
	for message: Dictionary in messages:
		assert_that(message.has("message")).is_true()
		assert_that(message.has("timestamp")).is_true()

func test_buffer_size_limits() -> void:
	DebugManager.clear_message_buffer()
	
	# Add more messages than the buffer limit
	for i: int in range(1200):  # Assuming max buffer size is 1000
		DebugManager.log_info(DebugManager.Category.GENERAL, "Buffer overflow test %d" % i)
	
	var all_messages: Array[Dictionary] = DebugManager.get_recent_messages(2000)
	
	# Should not exceed maximum buffer size
	assert_that(all_messages.size()).is_less_equal(1000)
	
	# Should contain the most recent messages
	var last_message: Dictionary = all_messages[-1]
	assert_that(last_message.get("message", "")).contains("Buffer overflow test 1199")

func test_concurrent_logging_simulation() -> void:
	DebugManager.clear_message_buffer()
	
	# Simulate concurrent logging from different systems
	var categories: Array[DebugManager.Category] = [
		DebugManager.Category.GENERAL,
		DebugManager.Category.PHYSICS,
		DebugManager.Category.GRAPHICS,
		DebugManager.Category.SOUND,
		DebugManager.Category.NETWORK
	]
	
	# Log many messages rapidly across different categories
	for i: int in range(100):
		var category: DebugManager.Category = categories[i % categories.size()]
		DebugManager.log_info(category, "Concurrent log %d from category %d" % [i, category])
	
	var messages: Array[Dictionary] = DebugManager.get_recent_messages(150)
	assert_that(messages.size()).is_equal(100)
	
	# Verify messages are properly categorized
	var category_counts: Dictionary = {}
	for message: Dictionary in messages:
		var category: DebugManager.Category = message.get("category", DebugManager.Category.GENERAL)
		if not category_counts.has(category):
			category_counts[category] = 0
		category_counts[category] += 1
	
	# Each category should have been used
	assert_that(category_counts.size()).is_equal(categories.size())

func test_performance_characteristics() -> void:
	# Test logging performance
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Log many messages rapidly
	for i: int in range(1000):
		DebugManager.log_info(DebugManager.Category.PERFORMANCE, "Performance test message %d" % i)
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var duration: float = end_time - start_time
	
	# Logging 1000 messages should complete quickly (less than 1 second)
	assert_that(duration).is_less(1.0)
	
	# Test message retrieval performance
	var retrieval_start: float = Time.get_ticks_msec() / 1000.0
	
	for i: int in range(100):
		var messages: Array[Dictionary] = DebugManager.get_recent_messages(50)
		assert_that(messages.size()).is_greater(0)
	
	var retrieval_end: float = Time.get_ticks_msec() / 1000.0
	var retrieval_duration: float = retrieval_end - retrieval_start
	
	# 100 retrievals should also be fast (less than 0.5 seconds)
	assert_that(retrieval_duration).is_less(0.5)

func test_shutdown_and_cleanup() -> void:
	# Enable file logging for this test
	DebugManager.enable_file_logging(test_log_file)
	
	# Log some messages
	DebugManager.log_info(DebugManager.Category.GENERAL, "Pre-shutdown message")
	
	# Test shutdown
	DebugManager.shutdown()
	
	# Verify file was closed properly (should be able to read it)
	if FileAccess.file_exists(test_log_file):
		var log_file: FileAccess = FileAccess.open(test_log_file, FileAccess.READ)
		assert_that(log_file).is_not_null()
		var content: String = log_file.get_as_text()
		log_file.close()
		assert_that(content).contains("Pre-shutdown message")
	
	# Re-initialize for cleanup
	DebugManager.initialize(false)