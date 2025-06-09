class_name TestSettingsManager
extends GdUnitTestSuite

## Unit tests for SettingsManager cross-platform configuration functionality.
## Tests WCS-compatible registry replacement using Godot's ConfigFile system.

const SettingsManager = preload("res://scripts/core/platform/settings_manager.gd")

var test_config_backup: Dictionary = {}

func before_test() -> void:
	# Initialize settings manager
	SettingsManager.initialize()
	
	# Backup current configurations for restoration after tests
	test_config_backup = SettingsManager.export_to_wcs_registry_format()

func after_test() -> void:
	# Restore original configurations
	if not test_config_backup.is_empty():
		SettingsManager.import_wcs_registry_data(test_config_backup)
	
	# Ensure all configs are saved
	SettingsManager.save_all_configs()

func after_all() -> void:
	# Shutdown settings manager
	SettingsManager.shutdown()

func test_settings_manager_initialization() -> void:
	# Test that initialization works correctly
	var success: bool = SettingsManager.initialize()
	assert_that(success).is_true()
	
	# Test that config files are created
	var main_path: String = SettingsManager.get_config_file_path("main")
	var user_path: String = SettingsManager.get_config_file_path("user")
	var pilot_path: String = SettingsManager.get_config_file_path("pilot")
	var controls_path: String = SettingsManager.get_config_file_path("controls")
	
	assert_that(main_path).is_not_empty()
	assert_that(user_path).is_not_empty()
	assert_that(pilot_path).is_not_empty()
	assert_that(controls_path).is_not_empty()

func test_wcs_compatible_string_operations() -> void:
	var test_section: String = "Software\\Volition\\WingCommanderSaga\\Settings"
	var test_key: String = "player_name"
	var test_value: String = "TestPilot"
	
	# Test writing string value
	SettingsManager.os_config_write_string(test_section, test_key, test_value)
	
	# Test reading string value
	var read_value: String = SettingsManager.os_config_read_string(test_section, test_key, "default")
	assert_that(read_value).is_equal(test_value)
	
	# Test reading with default value
	var default_value: String = SettingsManager.os_config_read_string(test_section, "nonexistent_key", "default_value")
	assert_that(default_value).is_equal("default_value")

func test_wcs_compatible_uint_operations() -> void:
	var test_section: String = "Software\\Volition\\WingCommanderSaga\\Settings"
	var test_key: String = "resolution_width"
	var test_value: int = 1920
	
	# Test writing uint value
	SettingsManager.os_config_write_uint(test_section, test_key, test_value)
	
	# Test reading uint value
	var read_value: int = SettingsManager.os_config_read_uint(test_section, test_key, 1024)
	assert_that(read_value).is_equal(test_value)
	
	# Test reading with default value
	var default_value: int = SettingsManager.os_config_read_uint(test_section, "nonexistent_key", 800)
	assert_that(default_value).is_equal(800)
	
	# Test unsigned constraint (negative values become 0)
	SettingsManager.os_config_write_uint(test_section, "negative_test", -100)
	var unsigned_value: int = SettingsManager.os_config_read_uint(test_section, "negative_test", 0)
	assert_that(unsigned_value).is_greater_equal(0)

func test_modern_variant_operations() -> void:
	var test_section: String = "TestSection"
	
	# Test writing different types
	SettingsManager.write_value(test_section, "bool_value", true)
	SettingsManager.write_value(test_section, "float_value", 3.14159)
	SettingsManager.write_value(test_section, "string_value", "Hello World")
	SettingsManager.write_value(test_section, "int_value", 42)
	
	# Test reading with type preservation
	var bool_value: bool = SettingsManager.read_value(test_section, "bool_value", false)
	var float_value: float = SettingsManager.read_value(test_section, "float_value", 0.0)
	var string_value: String = SettingsManager.read_value(test_section, "string_value", "")
	var int_value: int = SettingsManager.read_value(test_section, "int_value", 0)
	
	assert_that(bool_value).is_true()
	assert_that(float_value).is_equal(3.14159)
	assert_that(string_value).is_equal("Hello World")
	assert_that(int_value).is_equal(42)

func test_config_removal_operations() -> void:
	var test_section: String = "Software\\Volition\\WingCommanderSaga\\Settings"
	
	# Add some test values
	SettingsManager.os_config_write_string(test_section, "temp_key1", "temp_value1")
	SettingsManager.os_config_write_string(test_section, "temp_key2", "temp_value2")
	
	# Verify values exist
	var value1: String = SettingsManager.os_config_read_string(test_section, "temp_key1", "not_found")
	assert_that(value1).is_equal("temp_value1")
	
	# Remove specific key
	SettingsManager.os_config_remove(test_section, "temp_key1")
	
	# Verify key is removed
	var removed_value: String = SettingsManager.os_config_read_string(test_section, "temp_key1", "default")
	assert_that(removed_value).is_equal("default")
	
	# Verify other key still exists
	var remaining_value: String = SettingsManager.os_config_read_string(test_section, "temp_key2", "not_found")
	assert_that(remaining_value).is_equal("temp_value2")

func test_config_file_operations() -> void:
	# Test saving specific config types
	SettingsManager.write_value("TestSection", "save_test", "test_value")
	
	var main_save: bool = SettingsManager.save_config("main")
	assert_that(main_save).is_true()
	
	var user_save: bool = SettingsManager.save_config("user")
	assert_that(user_save).is_true()
	
	var pilot_save: bool = SettingsManager.save_config("pilot")
	assert_that(pilot_save).is_true()
	
	var controls_save: bool = SettingsManager.save_config("controls")
	assert_that(controls_save).is_true()
	
	# Test saving all configs
	var save_all: bool = SettingsManager.save_all_configs()
	assert_that(save_all).is_true()

func test_config_reload_operations() -> void:
	# Write a value
	var test_key: String = "reload_test"
	var test_value: String = "original_value"
	SettingsManager.write_value("TestSection", test_key, test_value)
	SettingsManager.save_config("main")
	
	# Modify the value in memory
	SettingsManager.write_value("TestSection", test_key, "modified_value")
	var modified: String = SettingsManager.read_value("TestSection", test_key, "")
	assert_that(modified).is_equal("modified_value")
	
	# Reload from disk
	var reload_success: bool = SettingsManager.reload_config("main")
	assert_that(reload_success).is_true()
	
	# Verify value is restored from disk
	var reloaded: String = SettingsManager.read_value("TestSection", test_key, "")
	assert_that(reloaded).is_equal(test_value)

func test_config_reset_to_defaults() -> void:
	# Modify main config with custom values
	SettingsManager.write_value("CustomSection", "custom_key", "custom_value")
	SettingsManager.save_config("main")
	
	# Verify custom value exists
	var custom_value: String = SettingsManager.read_value("CustomSection", "custom_key", "not_found")
	assert_that(custom_value).is_equal("custom_value")
	
	# Reset to defaults
	var reset_success: bool = SettingsManager.reset_config_to_defaults("main")
	assert_that(reset_success).is_true()
	
	# Verify custom value is gone and defaults are restored
	var after_reset: String = SettingsManager.read_value("CustomSection", "custom_key", "not_found")
	assert_that(after_reset).is_equal("not_found")
	
	# Verify default values are present
	var default_width: int = SettingsManager.read_value("Settings", "resolution_width", 0)
	assert_that(default_width).is_equal(1024)  # From default values

func test_config_key_management() -> void:
	# Add test keys
	SettingsManager.write_value("TestSection", "key1", "value1")
	SettingsManager.write_value("TestSection", "key2", "value2")
	SettingsManager.write_value("TestSection", "key3", "value3")
	
	# Test getting config keys
	var keys: PackedStringArray = SettingsManager.get_config_keys("main")
	assert_that(keys.size()).is_greater(0)
	
	# Test checking key existence
	var has_key1: bool = SettingsManager.has_config_key("main", "key1")
	assert_that(has_key1).is_true()
	
	var has_nonexistent: bool = SettingsManager.has_config_key("main", "nonexistent_key")
	assert_that(has_nonexistent).is_false()

func test_wcs_registry_data_import_export() -> void:
	# Create test registry data structure
	var test_registry_data: Dictionary = {
		"Software\\Volition\\WingCommanderSaga\\Settings": {
			"resolution_width": 1600,
			"resolution_height": 900,
			"fullscreen": true,
			"player_name": "ImportedPilot"
		},
		"Software\\Volition\\WingCommanderSaga\\Controls": {
			"mouse_sensitivity": 1.5,
			"invert_mouse": true
		}
	}
	
	# Import the test data
	var import_success: bool = SettingsManager.import_wcs_registry_data(test_registry_data)
	assert_that(import_success).is_true()
	
	# Verify imported values
	var width: int = SettingsManager.os_config_read_uint("Software\\Volition\\WingCommanderSaga\\Settings", "resolution_width", 0)
	assert_that(width).is_equal(1600)
	
	var player_name: String = SettingsManager.os_config_read_string("Software\\Volition\\WingCommanderSaga\\Settings", "player_name", "")
	assert_that(player_name).is_equal("ImportedPilot")
	
	var sensitivity: float = SettingsManager.read_value("Software\\Volition\\WingCommanderSaga\\Controls", "mouse_sensitivity", 0.0)
	assert_that(sensitivity).is_equal(1.5)
	
	# Test export functionality
	var exported_data: Dictionary = SettingsManager.export_to_wcs_registry_format()
	assert_that(exported_data).is_not_empty()
	assert_that(exported_data.has("Software\\Volition\\WingCommanderSaga\\Settings")).is_true()

func test_configuration_validation() -> void:
	# Test configuration validation
	var is_valid: bool = SettingsManager.validate_configuration()
	assert_that(is_valid).is_true()
	
	# Add some test data and validate again
	SettingsManager.write_value("TestSection", "validation_test", "test_value")
	var still_valid: bool = SettingsManager.validate_configuration()
	assert_that(still_valid).is_true()

func test_default_value_behavior() -> void:
	# Test that default values are properly applied
	var default_resolution_width: int = SettingsManager.read_value("Settings", "resolution_width", 0)
	assert_that(default_resolution_width).is_greater(0)
	
	var default_sound_volume: float = SettingsManager.read_value("Settings", "sound_volume", 0.0)
	assert_that(default_sound_volume).is_greater(0.0)
	
	var default_player_name: String = SettingsManager.read_value("Settings", "player_name", "")
	assert_that(default_player_name).is_not_empty()

func test_different_config_types() -> void:
	# Test that different sections map to different config files correctly
	
	# Main settings
	SettingsManager.os_config_write_string("Software\\Volition\\WingCommanderSaga\\Settings", "main_test", "main_value")
	
	# User settings  
	SettingsManager.os_config_write_string("Software\\Volition\\WingCommanderSaga\\Player", "user_test", "user_value")
	
	# Pilot settings
	SettingsManager.os_config_write_string("Software\\Volition\\WingCommanderSaga\\Pilot", "pilot_test", "pilot_value")
	
	# Controls settings
	SettingsManager.os_config_write_string("Software\\Volition\\WingCommanderSaga\\Controls", "controls_test", "controls_value")
	
	# Save all configs
	SettingsManager.save_all_configs()
	
	# Verify values are stored in correct config types
	var main_value: String = SettingsManager.os_config_read_string("Software\\Volition\\WingCommanderSaga\\Settings", "main_test", "")
	var user_value: String = SettingsManager.os_config_read_string("Software\\Volition\\WingCommanderSaga\\Player", "user_test", "")
	var pilot_value: String = SettingsManager.os_config_read_string("Software\\Volition\\WingCommanderSaga\\Pilot", "pilot_test", "")
	var controls_value: String = SettingsManager.os_config_read_string("Software\\Volition\\WingCommanderSaga\\Controls", "controls_test", "")
	
	assert_that(main_value).is_equal("main_value")
	assert_that(user_value).is_equal("user_value")
	assert_that(pilot_value).is_equal("pilot_value")
	assert_that(controls_value).is_equal("controls_value")

func test_edge_cases_and_error_conditions() -> void:
	# Test empty section names
	SettingsManager.os_config_write_string("", "empty_section_key", "value")
	var empty_section_value: String = SettingsManager.os_config_read_string("", "empty_section_key", "default")
	# Should still work, defaulting to main config
	
	# Test empty key names
	SettingsManager.os_config_write_string("TestSection", "", "empty_key_value")
	var empty_key_value: String = SettingsManager.os_config_read_string("TestSection", "", "default")
	# Behavior may vary, but should not crash
	
	# Test very long strings
	var long_value: String = ""
	for i: int in range(1000):
		long_value += "Long string part %d. " % i
	
	SettingsManager.os_config_write_string("TestSection", "long_value", long_value)
	var read_long_value: String = SettingsManager.os_config_read_string("TestSection", "long_value", "")
	assert_that(read_long_value).is_equal(long_value)
	
	# Test special characters in keys and values
	SettingsManager.os_config_write_string("TestSection", "special_chars", "Value with special chars: áéíóú ñ ¿¡ 中文 русский")
	var special_value: String = SettingsManager.os_config_read_string("TestSection", "special_chars", "")
	assert_that(special_value).contains("special chars")

func test_concurrent_access_simulation() -> void:
	# Simulate concurrent access by rapidly reading/writing different keys
	var base_section: String = "ConcurrentTest"
	
	# Write multiple values rapidly
	for i: int in range(50):
		var key: String = "concurrent_key_%d" % i
		var value: String = "concurrent_value_%d" % i
		SettingsManager.write_value(base_section, key, value)
	
	# Read back all values
	for i: int in range(50):
		var key: String = "concurrent_key_%d" % i
		var expected_value: String = "concurrent_value_%d" % i
		var actual_value: String = SettingsManager.read_value(base_section, key, "not_found")
		assert_that(actual_value).is_equal(expected_value)

func test_large_configuration_data() -> void:
	# Test with large amounts of configuration data
	var large_section: String = "LargeDataTest"
	
	# Create many configuration entries
	for i: int in range(1000):
		var key: String = "large_data_key_%d" % i
		var value: String = "Large data value for key %d with some additional content to make it longer" % i
		SettingsManager.write_value(large_section, key, value)
	
	# Save configuration
	var save_success: bool = SettingsManager.save_config("main")
	assert_that(save_success).is_true()
	
	# Verify all entries can be read back
	for i: int in range(0, 1000, 10):  # Sample every 10th entry to avoid excessive test time
		var key: String = "large_data_key_%d" % i
		var expected_value: String = "Large data value for key %d with some additional content to make it longer" % i
		var actual_value: String = SettingsManager.read_value(large_section, key, "not_found")
		assert_that(actual_value).is_equal(expected_value)

func test_config_file_corruption_recovery() -> void:
	# This test would ideally corrupt a config file and test recovery
	# For now, we'll test the backup/restore functionality
	
	# Create a known good state
	SettingsManager.write_value("CorruptionTest", "good_value", "known_good")
	SettingsManager.save_config("main")
	
	# Export current state
	var backup_data: Dictionary = SettingsManager.export_to_wcs_registry_format()
	
	# Modify the state
	SettingsManager.write_value("CorruptionTest", "good_value", "corrupted")
	
	# Restore from backup
	var restore_success: bool = SettingsManager.import_wcs_registry_data(backup_data)
	assert_that(restore_success).is_true()
	
	# Verify restoration
	var restored_value: String = SettingsManager.read_value("CorruptionTest", "good_value", "not_found")
	assert_that(restored_value).is_equal("known_good")

func test_performance_characteristics() -> void:
	# Test performance of configuration operations
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	# Perform many write operations
	for i: int in range(1000):
		SettingsManager.write_value("PerformanceTest", "perf_key_%d" % i, "perf_value_%d" % i)
	
	var write_time: float = Time.get_ticks_msec() / 1000.0
	var write_duration: float = write_time - start_time
	
	# Writing 1000 entries should complete quickly (less than 2 seconds)
	assert_that(write_duration).is_less(2.0)
	
	# Test read performance
	var read_start: float = Time.get_ticks_msec() / 1000.0
	
	for i: int in range(1000):
		var value: String = SettingsManager.read_value("PerformanceTest", "perf_key_%d" % i, "")
		assert_that(value).is_not_empty()
	
	var read_end: float = Time.get_ticks_msec() / 1000.0
	var read_duration: float = read_end - read_start
	
	# Reading 1000 entries should also be fast (less than 1 second)
	assert_that(read_duration).is_less(1.0)

func test_type_conversion_and_compatibility() -> void:
	# Test that different data types are handled correctly
	
	# Write as different types
	SettingsManager.write_value("TypeTest", "int_as_string", "123")
	SettingsManager.write_value("TypeTest", "float_as_string", "45.67")
	SettingsManager.write_value("TypeTest", "bool_as_string", "true")
	
	# Read back as strings (should work)
	var int_string: String = SettingsManager.read_value("TypeTest", "int_as_string", "")
	var float_string: String = SettingsManager.read_value("TypeTest", "float_as_string", "")
	var bool_string: String = SettingsManager.read_value("TypeTest", "bool_as_string", "")
	
	assert_that(int_string).is_equal("123")
	assert_that(float_string).is_equal("45.67")
	assert_that(bool_string).is_equal("true")
	
	# Test WCS uint compatibility with string values
	SettingsManager.os_config_write_string("TypeTest", "string_number", "789")
	var string_as_uint: int = SettingsManager.os_config_read_uint("TypeTest", "string_number", 0)
	# This might not convert automatically, behavior depends on Godot's ConfigFile implementation