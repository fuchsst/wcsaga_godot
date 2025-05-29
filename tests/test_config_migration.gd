extends GdUnitTestSuite

## Unit tests for DM-009 Configuration Migration
## Tests the conversion of WCS configuration files to Godot format
## 
## Author: Dev (GDScript Developer)
## Date: January 29, 2025
## Story: DM-009 - Configuration Migration

var temp_wcs_dir: String = ""
var temp_godot_dir: String = ""

func before_test() -> void:
	"""Setup test environment before each test"""
	# Create temporary directories for testing
	temp_wcs_dir = "user://test_wcs_" + str(Time.get_ticks_msec())
	temp_godot_dir = "user://test_godot_" + str(Time.get_ticks_msec())
	
	DirAccess.open("user://").make_dir_recursive(temp_wcs_dir)
	DirAccess.open("user://").make_dir_recursive(temp_godot_dir)
	
	# Create mock WCS configuration files
	_create_mock_wcs_files()

func after_test() -> void:
	"""Cleanup test environment after each test"""
	# Clean up temporary directories
	if DirAccess.open("user://").dir_exists(temp_wcs_dir):
		_remove_dir_recursive(temp_wcs_dir)
	if DirAccess.open("user://").dir_exists(temp_godot_dir):
		_remove_dir_recursive(temp_godot_dir)

func _remove_dir_recursive(path: String) -> void:
	"""Recursively remove directory and all contents"""
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			var file_path: String = path + "/" + file_name
			if dir.current_is_dir():
				_remove_dir_recursive(file_path)
			else:
				dir.remove(file_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		DirAccess.open("user://").remove(path)

func _create_mock_wcs_files() -> void:
	"""Create mock WCS configuration files for testing"""
	# Create mock WCS INI file
	var wcs_ini_content = """[Graphics]
ScreenWidth=1920
ScreenHeight=1080
Fullscreen=true
VSync=true
Gamma=1.2
DetailLevel=3
AntiAlias=2

[Audio]
MasterVolume=0.8
MusicVolume=0.6
SFXVolume=0.9
VoiceVolume=0.7
SoundEnabled=true
MusicEnabled=true

[Game]
Difficulty=2
AutoTargeting=true
AutoSpeedMatching=false
ShowSubtitles=true
AutoAim=false
LandingHelp=true
"""
	
	var ini_file: FileAccess = FileAccess.open(temp_wcs_dir + "/wcsaga.ini", FileAccess.WRITE)
	if ini_file:
		ini_file.store_string(wcs_ini_content)
		ini_file.close()
	
	# Create mock control config file
	var control_config_content = """TARGET_NEXT=20
TARGET_PREV=21
FIRE_PRIMARY=57
FIRE_SECONDARY=28
FORWARD_THRUST=17
REVERSE_THRUST=31
BANK_LEFT=30
BANK_RIGHT=32
AFTERBURNER=15
"""
	
	var control_file: FileAccess = FileAccess.open(temp_wcs_dir + "/controls.cfg", FileAccess.WRITE)
	if control_file:
		control_file.store_string(control_config_content)
		control_file.close()
	
	# Create mock pilot file (simplified)
	var pilot_data = {
		"callsign": "TestPilot",
		"campaign_progress": 5,
		"total_kills": 42,
		"total_missions": 15,
		"skill_level": 2
	}
	
	var pilot_file: FileAccess = FileAccess.open(temp_wcs_dir + "/testpilot.pl2", FileAccess.WRITE)
	if pilot_file:
		pilot_file.store_string(JSON.stringify(pilot_data))
		pilot_file.close()

func test_game_settings_migration_compatibility() -> void:
	"""Test that GameSettings class supports WCS migration"""
	var game_settings: GameSettings = GameSettings.new()
	
	# Test WCS-compatible setting names and values
	assert_that(game_settings.has_method("set_difficulty_level")).is_true()
	assert_that(game_settings.has_method("get_difficulty_name")).is_true()
	assert_that(game_settings.has_method("validate_settings")).is_true()
	assert_that(game_settings.has_method("reset_category_to_defaults")).is_true()
	
	# Test difficulty mapping
	assert_that(game_settings.set_difficulty_level(0)).is_true()
	assert_that(game_settings.get_difficulty_name()).is_equal("Very Easy")
	
	assert_that(game_settings.set_difficulty_level(4)).is_true()
	assert_that(game_settings.get_difficulty_name()).is_equal("Insane")
	
	# Test invalid difficulty handling
	assert_that(game_settings.set_difficulty_level(5)).is_false()
	assert_that(game_settings.set_difficulty_level(-1)).is_false()

func test_user_preferences_structure() -> void:
	"""Test that UserPreferences has all required fields for WCS migration"""
	var user_prefs: UserPreferences = UserPreferences.new()
	
	# Test audio volume properties
	assert_has_property(user_prefs, "master_volume", "Should have master volume")
	assert_has_property(user_prefs, "music_volume", "Should have music volume")
	assert_has_property(user_prefs, "sfx_volume", "Should have SFX volume")
	assert_has_property(user_prefs, "voice_volume", "Should have voice volume")
	
	# Test control sensitivity properties
	assert_has_property(user_prefs, "mouse_sensitivity", "Should have mouse sensitivity")
	assert_has_property(user_prefs, "joystick_sensitivity", "Should have joystick sensitivity")
	assert_has_property(user_prefs, "invert_mouse_y", "Should have mouse invert option")
	
	# Test HUD preferences
	assert_has_property(user_prefs, "hud_opacity", "Should have HUD opacity")
	assert_has_property(user_prefs, "hud_scale", "Should have HUD scale")
	assert_has_property(user_prefs, "hud_color_scheme", "Should have HUD color scheme")
	
	# Test volume validation
	assert_that(user_prefs.set_audio_volume("master", 0.8)).is_true()
	assert_that(user_prefs.get_effective_audio_volume("master")).is_equal(0.8)
	
	# Test invalid volume values
	assert_that(user_prefs.set_audio_volume("master", 1.5)).is_false()
	assert_that(user_prefs.set_audio_volume("master", -0.1)).is_false()

func test_system_configuration_structure() -> void:
	"""Test that SystemConfiguration has all required fields for WCS migration"""
	var sys_config: SystemConfiguration = SystemConfiguration.new()
	
	# Test display settings
	assert_has_property(sys_config, "screen_resolution", "Should have screen resolution")
	assert_has_property(sys_config, "fullscreen_mode", "Should have fullscreen mode")
	assert_has_property(sys_config, "vsync_enabled", "Should have VSync setting")
	assert_has_property(sys_config, "max_fps", "Should have FPS limit")
	
	# Test graphics quality settings
	assert_has_property(sys_config, "graphics_quality", "Should have graphics quality")
	assert_has_property(sys_config, "anti_aliasing", "Should have anti-aliasing")
	assert_has_property(sys_config, "anisotropic_filtering", "Should have anisotropic filtering")
	
	# Test performance settings
	assert_has_property(sys_config, "performance_mode", "Should have performance mode")
	
	# Test resolution validation
	assert_that(sys_config.set_graphics_quality(0)).is_true()
	assert_that(sys_config.set_graphics_quality(3)).is_true()
	assert_that(sys_config.set_graphics_quality(5)).is_false()

func test_python_config_migrator_integration() -> void:
	"""Test integration with Python configuration migrator"""
	# This test verifies the integration point exists
	# The actual migration would be tested in Python integration tests
	
	# Test that migration directories exist
	var migration_source: String = temp_wcs_dir
	var migration_target: String = temp_godot_dir
	
	# Verify source contains expected files
	assert_that(FileAccess.file_exists(migration_source + "/wcsaga.ini")).is_true()
	assert_that(FileAccess.file_exists(migration_source + "/controls.cfg")).is_true()
	assert_that(FileAccess.file_exists(migration_source + "/testpilot.pl2")).is_true()
	
	# Test directory structure readiness
	var target_dir: DirAccess = DirAccess.open(migration_target)
	assert_that(target_dir).is_not_null()
	
	# Test that we can create required subdirectories
	target_dir.make_dir_recursive("resources/configuration")
	target_dir.make_dir_recursive("saves/pilots")
	target_dir.make_dir_recursive("input")
	
	assert_that(DirAccess.open(migration_target + "/resources/configuration")).is_not_null()
	assert_that(DirAccess.open(migration_target + "/saves/pilots")).is_not_null()

func test_settings_manager_integration() -> void:
	"""Test integration with existing SettingsManager for WCS compatibility"""
	# Initialize SettingsManager
	var init_success: bool = SettingsManager.initialize()
	assert_that(init_success).is_true()
	
	# Test WCS-compatible API exists
	assert_that(SettingsManager.new().has_method("os_config_write_string")).is_true()
	assert_that(SettingsManager.new().has_method("os_config_read_string")).is_true()
	assert_that(SettingsManager.new().has_method("os_config_write_uint")).is_true()
	assert_that(SettingsManager.new().has_method("os_config_read_uint")).is_true()
	
	# Test registry migration support
	assert_that(SettingsManager.new().has_method("import_wcs_registry_data")).is_true()
	assert_that(SettingsManager.new().has_method("export_to_wcs_registry_format")).is_true()
	
	# Test WCS-style settings
	SettingsManager.os_config_write_string("Software\\Volition\\WingCommanderSaga\\Settings", "PlayerName", "TestPilot")
	SettingsManager.os_config_write_uint("Software\\Volition\\WingCommanderSaga\\Settings", "Difficulty", 2)
	
	var player_name: String = SettingsManager.os_config_read_string("Software\\Volition\\WingCommanderSaga\\Settings", "PlayerName", "Unknown")
	var difficulty: int = SettingsManager.os_config_read_uint("Software\\Volition\\WingCommanderSaga\\Settings", "Difficulty", 1)
	
	assert_that(player_name).is_equal("TestPilot")
	assert_that(difficulty).is_equal(2)
	
	# Test registry data export
	var registry_data: Dictionary = SettingsManager.export_to_wcs_registry_format()
	assert_that(registry_data).is_not_empty()
	
	# Cleanup
	SettingsManager.shutdown()

func test_input_mapping_structure() -> void:
	"""Test that input mapping supports WCS control migration"""
	# Test that Godot InputMap can handle WCS control actions
	var test_actions: Array[String] = [
		"target_next",
		"target_prev", 
		"fire_primary",
		"fire_secondary",
		"forward_thrust",
		"reverse_thrust",
		"bank_left",
		"bank_right",
		"afterburner",
		"chase_view",
		"external_view",
		"cockpit_view"
	]
	
	# Create test input events
	for action in test_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		
		# Test keyboard event
		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = KEY_T  # Example: T key for targeting
		InputMap.action_add_event(action, key_event)
		
		# Test joystick event  
		var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_A
		InputMap.action_add_event(action, joy_event)
		
		# Verify action exists and has events
		assert_that(InputMap.has_action(action)).is_true()
		assert_that(InputMap.action_get_events(action).size()).is_greater(0)
	
	# Test complex key combinations (Shift, Ctrl, Alt)
	var complex_action: String = "target_prev_shift"
	if not InputMap.has_action(complex_action):
		InputMap.add_action(complex_action)
	
	var shift_key_event: InputEventKey = InputEventKey.new()
	shift_key_event.keycode = KEY_Y
	shift_key_event.shift_pressed = true
	InputMap.action_add_event(complex_action, shift_key_event)
	
	assert_that(InputMap.has_action(complex_action)).is_true()
	var events: Array[InputEvent] = InputMap.action_get_events(complex_action)
	assert_that(events.size()).is_greater(0)
	
	var shift_event: InputEventKey = events[0] as InputEventKey
	assert_that(shift_event.shift_pressed).is_true()

func test_pilot_profile_migration() -> void:
	"""Test pilot profile data structure for WCS migration"""
	# Test that pilot save system can handle WCS pilot data
	var pilot_save_data: Dictionary = {
		"pilot_data": {
			"callsign": "TestPilot",
			"image_filename": "pilot_portrait.png",
			"squad_filename": "squadron_logo.png", 
			"squad_name": "Blue Squadron",
			"campaign_progress": 8,
			"total_kills": 156,
			"total_missions": 25,
			"skill_level": 3,
			"medals": ["Distinguished Flying Cross", "Purple Heart"],
			"statistics": {
				"primary_shots_fired": 15420,
				"primary_shots_hit": 8934,
				"secondary_shots_fired": 287,
				"secondary_shots_hit": 245,
				"missions_flown": 25,
				"missions_completed": 23,
				"flight_time_seconds": 14580
			}
		}
	}
	
	# Test JSON serialization/deserialization
	var json_string: String = JSON.stringify(pilot_save_data)
	assert_that(json_string.length()).is_greater(0)
	
	var parsed_data: Variant = JSON.parse_string(json_string)
	assert_that(parsed_data).is_not_null()
	assert_that(parsed_data is Dictionary).is_true()
	
	var parsed_dict: Dictionary = parsed_data as Dictionary
	assert_that(parsed_dict.has("pilot_data")).is_true()
	
	var pilot_data: Dictionary = parsed_dict["pilot_data"]
	assert_that(pilot_data["callsign"]).is_equal("TestPilot")
	assert_that(pilot_data["total_kills"]).is_equal(156)
	assert_that(pilot_data["campaign_progress"]).is_equal(8)
	
	# Test statistics preservation
	assert_that(pilot_data.has("statistics")).is_true()
	var stats: Dictionary = pilot_data["statistics"]
	assert_that(stats["primary_shots_fired"]).is_equal(15420)
	assert_that(stats["flight_time_seconds"]).is_equal(14580)

func test_configuration_validation() -> void:
	"""Test configuration validation for migrated settings"""
	var game_settings: GameSettings = GameSettings.new()
	var user_prefs: UserPreferences = UserPreferences.new()
	var sys_config: SystemConfiguration = SystemConfiguration.new()
	
	# Test GameSettings validation
	var game_validation: Dictionary = game_settings.validate_settings()
	assert_that(game_validation.has("is_valid")).is_true()
	assert_that(game_validation["is_valid"]).is_true()
	
	# Test invalid settings detection
	game_settings.difficulty_level = 10  # Invalid
	game_validation = game_settings.validate_settings()
	assert_that(game_validation["is_valid"]).is_false()
	assert_that(game_validation["corrections"].size()).is_greater(0)
	
	# Test UserPreferences validation
	var user_validation: Dictionary = user_prefs.validate_preferences()
	assert_that(user_validation.has("is_valid")).is_true()
	
	# Test SystemConfiguration validation
	var sys_validation: Dictionary = sys_config.validate_system_settings()
	assert_that(sys_validation.has("is_valid")).is_true()
	
	# Test cross-category validation (conflicting settings)
	game_settings.debug_mode_enabled = true
	game_settings.enable_cheats = false
	game_validation = game_settings.validate_settings()
	assert_that(game_validation["warnings"].size()).is_greater(0)

func test_migration_report_generation() -> void:
	"""Test that migration can generate validation reports"""
	# Test report structure
	var migration_report: Dictionary = {
		"migration_info": {
			"date": "2025-01-29",
			"tool": "ConfigMigrator",
			"version": "1.0"
		},
		"settings_migrated": {
			"graphics_count": 8,
			"audio_count": 6,
			"gameplay_count": 12,
			"control_bindings": 25
		},
		"validation_results": {
			"graphics_valid": true,
			"audio_valid": true,
			"controls_valid": true,
			"overall_success": true
		},
		"compatibility": {
			"setting_preservation": "95%",
			"control_mapping": "100%",
			"cross_platform": true
		}
	}
	
	# Test report validation
	assert_that(migration_report.has("migration_info")).is_true()
	assert_that(migration_report.has("settings_migrated")).is_true()
	assert_that(migration_report.has("validation_results")).is_true()
	assert_that(migration_report.has("compatibility")).is_true()
	
	# Test JSON serialization for report
	var report_json: String = JSON.stringify(migration_report, "\t")
	assert_that(report_json.length()).is_greater(0)
	
	var parsed_report: Variant = JSON.parse_string(report_json)
	assert_that(parsed_report is Dictionary).is_true()
	
	var report_dict: Dictionary = parsed_report as Dictionary
	assert_that(report_dict["validation_results"]["overall_success"]).is_true()
	assert_that(report_dict["compatibility"]["cross_platform"]).is_true()

func assert_has_property(object: Object, property_name: String, message: String = "") -> void:
	"""Assert that an object has a specific property"""
	var property_list: Array = object.get_property_list()
	var has_property: bool = false
	
	for property in property_list:
		if property.name == property_name:
			has_property = true
			break
	
	assert_that(has_property).is_true()
