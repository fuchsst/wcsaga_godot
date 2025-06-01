extends GdUnitTestSuite

## Test suite for MenuSettingsManager
## Tests settings persistence, validation, backup, corruption detection, and import/export functionality

var menu_settings_manager: MenuSettingsManager
var test_settings: MenuSettingsData
var mock_config_manager: MockConfigurationManager

func before_test() -> void:
	"""Setup test environment before each test."""
	# Create mock configuration manager
	mock_config_manager = MockConfigurationManager.new()
	
	# Replace ConfigurationManager with mock for testing
	if Engine.has_singleton("ConfigurationManager"):
		Engine.remove_singleton("ConfigurationManager")
	Engine.register_singleton("ConfigurationManager", mock_config_manager)
	
	# Create manager instance
	menu_settings_manager = MenuSettingsManager.new()
	add_child(menu_settings_manager)
	
	# Create test settings
	test_settings = MenuSettingsData.new()
	test_settings.ui_scale = 1.5
	test_settings.animation_speed = 1.2
	test_settings.max_menu_fps = 60
	test_settings.menu_volume = 0.8

func after_test() -> void:
	"""Cleanup after each test."""
	if menu_settings_manager:
		menu_settings_manager.queue_free()
	
	if mock_config_manager:
		mock_config_manager.clear_all()
	
	# Clean up test backup files
	var dir: DirAccess = DirAccess.open("user://")
	if dir and dir.dir_exists("menu_backups"):
		dir.remove("menu_backups")

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_initialize_settings_creates_defaults_when_no_config() -> void:
	"""Test that initialization creates default settings when no configuration exists."""
	mock_config_manager.clear_all()
	
	var settings: MenuSettingsData = menu_settings_manager.initialize_settings()
	
	assert_that(settings).is_not_null()
	assert_that(settings.is_valid()).is_true()
	assert_that(settings.ui_scale).is_equal(1.0)
	assert_that(settings.animation_speed).is_equal(1.0)

func test_initialize_settings_loads_existing_config() -> void:
	"""Test that initialization loads existing configuration."""
	# Setup existing config
	var config_data: Dictionary = test_settings.to_dictionary()
	mock_config_manager.set_configuration("menu_system", config_data)
	
	var settings: MenuSettingsData = menu_settings_manager.initialize_settings()
	
	assert_that(settings).is_not_null()
	assert_that(settings.ui_scale).is_equal(1.5)
	assert_that(settings.animation_speed).is_equal(1.2)
	assert_that(settings.max_menu_fps).is_equal(60)

func test_initialize_settings_handles_corrupted_config() -> void:
	"""Test that initialization handles corrupted configuration properly."""
	# Setup corrupted config
	var corrupted_config: Dictionary = {
		"ui_scale": "invalid",  # Wrong type
		"animation_speed": -1.0,  # Invalid value
		"max_menu_fps": 999  # Out of range
	}
	mock_config_manager.set_configuration("menu_system", corrupted_config)
	
	var settings: MenuSettingsData = menu_settings_manager.initialize_settings()
	
	assert_that(settings).is_not_null()
	assert_that(settings.is_valid()).is_true()  # Should fall back to defaults
	assert_that(settings.ui_scale).is_equal(1.0)  # Default value

func test_initialize_settings_emits_signals() -> void:
	"""Test that initialization emits appropriate signals."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(menu_settings_manager)
	
	menu_settings_manager.initialize_settings()
	
	assert_signal(signal_monitor).is_emitted("settings_loaded")

# ============================================================================
# LOADING AND SAVING TESTS
# ============================================================================

func test_load_settings_returns_valid_settings() -> void:
	"""Test that load_settings returns valid settings data."""
	var config_data: Dictionary = test_settings.to_dictionary()
	mock_config_manager.set_configuration("menu_system", config_data)
	
	var loaded_settings: MenuSettingsData = menu_settings_manager.load_settings()
	
	assert_that(loaded_settings).is_not_null()
	assert_that(loaded_settings.is_valid()).is_true()
	assert_that(loaded_settings.ui_scale).is_equal(1.5)

func test_load_settings_returns_defaults_on_empty_config() -> void:
	"""Test that load_settings returns defaults when config is empty."""
	mock_config_manager.clear_all()
	
	var loaded_settings: MenuSettingsData = menu_settings_manager.load_settings()
	
	assert_that(loaded_settings).is_not_null()
	assert_that(loaded_settings.is_valid()).is_true()
	assert_that(loaded_settings.ui_scale).is_equal(1.0)

func test_save_settings_stores_configuration() -> void:
	"""Test that save_settings properly stores configuration."""
	var success: bool = menu_settings_manager.save_settings(test_settings)
	
	assert_that(success).is_true()
	var stored_config: Dictionary = mock_config_manager.get_configuration("menu_system")
	assert_that(stored_config).is_not_empty()
	assert_that(stored_config.get("ui_scale")).is_equal(1.5)

func test_save_settings_rejects_invalid_settings() -> void:
	"""Test that save_settings rejects invalid settings."""
	var invalid_settings: MenuSettingsData = MenuSettingsData.new()
	invalid_settings.ui_scale = -1.0  # Invalid value
	
	var success: bool = menu_settings_manager.save_settings(invalid_settings)
	
	assert_that(success).is_false()

func test_save_settings_updates_timestamps() -> void:
	"""Test that save_settings updates timestamps and checksum."""
	var original_timestamp: int = test_settings.last_backup_timestamp
	
	menu_settings_manager.save_settings(test_settings)
	
	assert_that(test_settings.last_backup_timestamp).is_greater(original_timestamp)
	assert_that(test_settings.validation_checksum).is_not_empty()

func test_save_settings_emits_signals() -> void:
	"""Test that save_settings emits appropriate signals."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(menu_settings_manager)
	
	menu_settings_manager.save_settings(test_settings)
	
	assert_signal(signal_monitor).is_emitted("settings_saved")
	assert_signal(signal_monitor).is_emitted("settings_validated")

# ============================================================================
# VALIDATION TESTS
# ============================================================================

func test_validate_settings_returns_no_errors_for_valid_settings() -> void:
	"""Test that validate_settings returns no errors for valid settings."""
	var errors: Array[String] = menu_settings_manager.validate_settings(test_settings)
	
	assert_that(errors).is_empty()

func test_validate_settings_returns_errors_for_invalid_settings() -> void:
	"""Test that validate_settings returns errors for invalid settings."""
	var invalid_settings: MenuSettingsData = MenuSettingsData.new()
	invalid_settings.ui_scale = 10.0  # Out of range
	invalid_settings.animation_speed = -1.0  # Invalid
	
	var errors: Array[String] = menu_settings_manager.validate_settings(invalid_settings)
	
	assert_that(errors).is_not_empty()
	assert_that(errors.size()).is_greater_equal(2)

func test_validate_settings_handles_null_settings() -> void:
	"""Test that validate_settings handles null settings gracefully."""
	var errors: Array[String] = menu_settings_manager.validate_settings(null)
	
	assert_that(errors).is_not_empty()
	assert_that(errors[0]).contains("null")

func test_validate_settings_emits_validation_signals() -> void:
	"""Test that validate_settings emits validation signals."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(menu_settings_manager)
	
	menu_settings_manager.validate_settings(test_settings)
	
	assert_signal(signal_monitor).is_emitted("settings_validated")

# ============================================================================
# BACKUP TESTS
# ============================================================================

func test_create_backup_generates_backup_file() -> void:
	"""Test that create_backup generates a backup file."""
	menu_settings_manager.current_settings = test_settings
	
	var backup_path: String = menu_settings_manager.create_backup("test")
	
	assert_that(backup_path).is_not_empty()
	assert_that(FileAccess.file_exists(backup_path)).is_true()

func test_create_backup_includes_backup_metadata() -> void:
	"""Test that create_backup includes proper metadata."""
	menu_settings_manager.current_settings = test_settings
	
	var backup_path: String = menu_settings_manager.create_backup("test")
	
	var file: FileAccess = FileAccess.open(backup_path, FileAccess.READ)
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	json.parse(json_string)
	var backup_data: Dictionary = json.data
	
	assert_that(backup_data.has("backup_type")).is_true()
	assert_that(backup_data.has("backup_timestamp")).is_true()
	assert_that(backup_data.get("backup_type")).is_equal("test")

func test_create_backup_emits_backup_created_signal() -> void:
	"""Test that create_backup emits backup_created signal."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(menu_settings_manager)
	menu_settings_manager.current_settings = test_settings
	
	menu_settings_manager.create_backup("test")
	
	assert_signal(signal_monitor).is_emitted("backup_created")

func test_restore_backup_loads_settings_from_file() -> void:
	"""Test that restore_backup loads settings from backup file."""
	# Create backup first
	menu_settings_manager.current_settings = test_settings
	var backup_path: String = menu_settings_manager.create_backup("test")
	
	# Modify current settings
	menu_settings_manager.current_settings.ui_scale = 2.0
	
	# Restore from backup
	var success: bool = menu_settings_manager.restore_backup(backup_path)
	
	assert_that(success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(1.5)  # Original value

func test_restore_backup_handles_missing_file() -> void:
	"""Test that restore_backup handles missing backup file."""
	var success: bool = menu_settings_manager.restore_backup("nonexistent_file.json")
	
	assert_that(success).is_false()

func test_restore_backup_handles_corrupted_file() -> void:
	"""Test that restore_backup handles corrupted backup file."""
	# Create corrupted backup file
	var backup_path: String = "user://corrupted_backup.json"
	var file: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
	file.store_string("invalid json content")
	file.close()
	
	var success: bool = menu_settings_manager.restore_backup(backup_path)
	
	assert_that(success).is_false()

func test_get_backup_list_returns_available_backups() -> void:
	"""Test that get_backup_list returns available backups."""
	menu_settings_manager.current_settings = test_settings
	
	# Create multiple backups
	menu_settings_manager.create_backup("test1")
	menu_settings_manager.create_backup("test2")
	
	var backup_list: Array[Dictionary] = menu_settings_manager.get_backup_list()
	
	assert_that(backup_list.size()).is_greater_equal(2)
	assert_that(backup_list[0].has("type")).is_true()
	assert_that(backup_list[0].has("timestamp")).is_true()

# ============================================================================
# IMPORT/EXPORT TESTS
# ============================================================================

func test_export_settings_creates_export_file() -> void:
	"""Test that export_settings creates export file."""
	menu_settings_manager.current_settings = test_settings
	
	var export_path: String = "user://test_export.wcs_menu"
	var success: bool = menu_settings_manager.export_settings(export_path)
	
	assert_that(success).is_true()
	assert_that(FileAccess.file_exists(export_path)).is_true()

func test_export_settings_handles_null_settings() -> void:
	"""Test that export_settings handles null current settings."""
	menu_settings_manager.current_settings = null
	
	var export_path: String = "user://test_export.wcs_menu"
	var success: bool = menu_settings_manager.export_settings(export_path)
	
	assert_that(success).is_false()

func test_import_settings_loads_from_file() -> void:
	"""Test that import_settings loads settings from file."""
	# Export settings first
	menu_settings_manager.current_settings = test_settings
	var export_path: String = "user://test_export.wcs_menu"
	menu_settings_manager.export_settings(export_path)
	
	# Clear current settings
	menu_settings_manager.current_settings = MenuSettingsData.new()
	
	# Import settings
	var success: bool = menu_settings_manager.import_settings(export_path)
	
	assert_that(success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(1.5)

func test_import_settings_handles_missing_file() -> void:
	"""Test that import_settings handles missing import file."""
	var success: bool = menu_settings_manager.import_settings("nonexistent_file.wcs_menu")
	
	assert_that(success).is_false()

func test_import_settings_creates_backup_before_import() -> void:
	"""Test that import_settings creates backup before importing."""
	# Setup existing settings
	menu_settings_manager.current_settings = test_settings
	var original_backup_count: int = menu_settings_manager.get_backup_list().size()
	
	# Create export file
	var export_path: String = "user://test_export.wcs_menu"
	test_settings.export_to_file(export_path)
	
	# Import
	menu_settings_manager.import_settings(export_path)
	
	var new_backup_count: int = menu_settings_manager.get_backup_list().size()
	assert_that(new_backup_count).is_greater(original_backup_count)

func test_import_settings_emits_imported_signal() -> void:
	"""Test that import_settings emits settings_imported signal."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(menu_settings_manager)
	
	# Create valid export file
	var export_path: String = "user://test_export.wcs_menu"
	test_settings.export_to_file(export_path)
	
	menu_settings_manager.import_settings(export_path)
	
	assert_signal(signal_monitor).is_emitted("settings_imported")

# ============================================================================
# RESET TESTS
# ============================================================================

func test_reset_to_defaults_full_resets_all_settings() -> void:
	"""Test that reset_to_defaults with 'full' resets all settings."""
	# Setup modified settings
	test_settings.ui_scale = 2.0
	test_settings.animation_speed = 2.0
	menu_settings_manager.current_settings = test_settings
	
	var success: bool = menu_settings_manager.reset_to_defaults("full")
	
	assert_that(success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(1.0)
	assert_that(menu_settings_manager.current_settings.animation_speed).is_equal(1.0)

func test_reset_to_defaults_interface_resets_interface_only() -> void:
	"""Test that reset_to_defaults with 'interface' resets interface settings only."""
	test_settings.ui_scale = 2.0
	test_settings.max_menu_fps = 30  # Performance setting
	menu_settings_manager.current_settings = test_settings
	
	var success: bool = menu_settings_manager.reset_to_defaults("interface")
	
	assert_that(success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(1.0)  # Reset
	assert_that(menu_settings_manager.current_settings.max_menu_fps).is_equal(30)  # Unchanged

func test_reset_to_defaults_performance_resets_performance_only() -> void:
	"""Test that reset_to_defaults with 'performance' resets performance settings only."""
	test_settings.ui_scale = 2.0  # Interface setting
	test_settings.max_menu_fps = 30  # Performance setting
	menu_settings_manager.current_settings = test_settings
	
	var success: bool = menu_settings_manager.reset_to_defaults("performance")
	
	assert_that(success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(2.0)  # Unchanged
	assert_that(menu_settings_manager.current_settings.max_menu_fps).is_equal(60)  # Reset

func test_reset_to_defaults_accessibility_resets_accessibility_only() -> void:
	"""Test that reset_to_defaults with 'accessibility' resets accessibility settings only."""
	test_settings.ui_scale = 2.0  # Interface setting
	test_settings.high_contrast_mode = true  # Accessibility setting
	menu_settings_manager.current_settings = test_settings
	
	var success: bool = menu_settings_manager.reset_to_defaults("accessibility")
	
	assert_that(success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(2.0)  # Unchanged
	assert_that(menu_settings_manager.current_settings.high_contrast_mode).is_false()  # Reset

func test_reset_to_defaults_handles_unknown_type() -> void:
	"""Test that reset_to_defaults handles unknown reset type."""
	menu_settings_manager.current_settings = test_settings
	
	var success: bool = menu_settings_manager.reset_to_defaults("unknown_type")
	
	assert_that(success).is_false()

func test_reset_to_defaults_emits_reset_signal() -> void:
	"""Test that reset_to_defaults emits settings_reset signal."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(menu_settings_manager)
	menu_settings_manager.current_settings = test_settings
	
	menu_settings_manager.reset_to_defaults("full")
	
	assert_signal(signal_monitor).is_emitted("settings_reset")

# ============================================================================
# CORRUPTION DETECTION TESTS
# ============================================================================

func test_detect_corruption_identifies_corrupted_settings() -> void:
	"""Test that detect_corruption identifies corrupted settings."""
	# Create settings with invalid checksum
	test_settings.validation_checksum = "invalid_checksum"
	menu_settings_manager.current_settings = test_settings
	
	var is_corrupted: bool = menu_settings_manager.detect_corruption()
	
	assert_that(is_corrupted).is_true()

func test_detect_corruption_handles_valid_settings() -> void:
	"""Test that detect_corruption handles valid settings correctly."""
	# Ensure valid checksum
	test_settings.validation_checksum = test_settings._generate_checksum()
	menu_settings_manager.current_settings = test_settings
	
	var is_corrupted: bool = menu_settings_manager.detect_corruption()
	
	assert_that(is_corrupted).is_false()

func test_corruption_detection_emits_corrupted_signal() -> void:
	"""Test that corruption detection emits settings_corrupted signal."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(menu_settings_manager)
	
	# Create corrupted settings
	test_settings.validation_checksum = "invalid_checksum"
	menu_settings_manager.current_settings = test_settings
	
	menu_settings_manager.detect_corruption()
	
	assert_signal(signal_monitor).is_emitted("settings_corrupted")

# ============================================================================
# UTILITY TESTS
# ============================================================================

func test_get_current_settings_returns_initialized_settings() -> void:
	"""Test that get_current_settings returns initialized settings."""
	menu_settings_manager.current_settings = test_settings
	
	var current: MenuSettingsData = menu_settings_manager.get_current_settings()
	
	assert_that(current).is_not_null()
	assert_that(current.ui_scale).is_equal(1.5)

func test_get_current_settings_initializes_if_null() -> void:
	"""Test that get_current_settings initializes if current settings is null."""
	menu_settings_manager.current_settings = null
	
	var current: MenuSettingsData = menu_settings_manager.get_current_settings()
	
	assert_that(current).is_not_null()
	assert_that(current.is_valid()).is_true()

func test_get_settings_info_returns_comprehensive_info() -> void:
	"""Test that get_settings_info returns comprehensive information."""
	menu_settings_manager.current_settings = test_settings
	
	var info: Dictionary = menu_settings_manager.get_settings_info()
	
	assert_that(info.has("version")).is_true()
	assert_that(info.has("is_valid")).is_true()
	assert_that(info.has("validation_errors")).is_true()
	assert_that(info.has("estimated_memory")).is_true()

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_full_workflow_save_load_validate() -> void:
	"""Test complete workflow: save, load, validate."""
	# Save settings
	var save_success: bool = menu_settings_manager.save_settings(test_settings)
	assert_that(save_success).is_true()
	
	# Load settings
	var loaded_settings: MenuSettingsData = menu_settings_manager.load_settings()
	assert_that(loaded_settings.ui_scale).is_equal(1.5)
	
	# Validate settings
	var errors: Array[String] = menu_settings_manager.validate_settings(loaded_settings)
	assert_that(errors).is_empty()

func test_backup_restore_workflow() -> void:
	"""Test backup and restore workflow."""
	menu_settings_manager.current_settings = test_settings
	
	# Create backup
	var backup_path: String = menu_settings_manager.create_backup("workflow_test")
	assert_that(backup_path).is_not_empty()
	
	# Modify settings
	menu_settings_manager.current_settings.ui_scale = 3.0
	
	# Restore backup
	var restore_success: bool = menu_settings_manager.restore_backup(backup_path)
	assert_that(restore_success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(1.5)

func test_export_import_workflow() -> void:
	"""Test export and import workflow."""
	menu_settings_manager.current_settings = test_settings
	
	# Export settings
	var export_path: String = "user://workflow_test.wcs_menu"
	var export_success: bool = menu_settings_manager.export_settings(export_path)
	assert_that(export_success).is_true()
	
	# Clear settings
	menu_settings_manager.current_settings = MenuSettingsData.new()
	
	# Import settings
	var import_success: bool = menu_settings_manager.import_settings(export_path)
	assert_that(import_success).is_true()
	assert_that(menu_settings_manager.current_settings.ui_scale).is_equal(1.5)

# ============================================================================
# MOCK CONFIGURATION MANAGER
# ============================================================================

class MockConfigurationManager:
	extends RefCounted
	
	var config_data: Dictionary = {}
	
	func get_configuration(key: String, default_value: Variant = {}) -> Variant:
		return config_data.get(key, default_value)
	
	func set_configuration(key: String, value: Variant) -> bool:
		config_data[key] = value
		return true
	
	func clear_all() -> void:
		config_data.clear()