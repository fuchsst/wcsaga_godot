extends GdUnitTestSuite

## Test suite for SettingsValidationFramework
## Tests validation rules, real-time validation, caching, and custom rule registration

var validation_framework: SettingsValidationFramework
var test_menu_settings: MenuSettingsData
var test_graphics_settings: MockGraphicsSettings

func before_test() -> void:
	"""Setup test environment before each test."""
	validation_framework = SettingsValidationFramework.new()
	add_child(validation_framework)
	
	# Create test settings
	test_menu_settings = MenuSettingsData.new()
	test_menu_settings.ui_scale = 1.5
	test_menu_settings.animation_speed = 1.2
	test_menu_settings.max_menu_fps = 60
	test_menu_settings.menu_volume = 0.8
	
	test_graphics_settings = MockGraphicsSettings.new()

func after_test() -> void:
	"""Cleanup after each test."""
	if validation_framework:
		validation_framework.queue_free()

# ============================================================================
# BASIC VALIDATION TESTS
# ============================================================================

func test_validate_settings_returns_valid_result_for_valid_settings() -> void:
	"""Test that validate_settings returns valid result for valid settings."""
	var result: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(test_menu_settings, "menu_system")
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid).is_true()
	assert_that(result.errors).is_empty()
	assert_that(result.settings_type).is_equal("menu_system")

func test_validate_settings_returns_invalid_result_for_invalid_settings() -> void:
	"""Test that validate_settings returns invalid result for invalid settings."""
	# Create invalid settings
	test_menu_settings.ui_scale = 10.0  # Out of range
	test_menu_settings.animation_speed = -1.0  # Invalid
	
	var result: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(test_menu_settings, "menu_system")
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()
	assert_that(result.validation_score).is_less(1.0)

func test_validate_settings_handles_null_settings() -> void:
	"""Test that validate_settings handles null settings gracefully."""
	var result: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(null, "unknown")
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).contains("Settings object is null")

func test_validate_settings_handles_missing_methods() -> void:
	"""Test that validate_settings handles settings without required methods."""
	var invalid_resource: Resource = Resource.new()
	
	var result: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(invalid_resource, "test")
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()

func test_validate_settings_emits_signals() -> void:
	"""Test that validate_settings emits appropriate signals."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(validation_framework)
	
	validation_framework.validate_settings(test_menu_settings, "menu_system")
	
	assert_signal(signal_monitor).is_emitted("validation_started")
	assert_signal(signal_monitor).is_emitted("validation_completed")

# ============================================================================
# REAL-TIME VALIDATION TESTS
# ============================================================================

func test_validate_field_real_time_queues_validation() -> void:
	"""Test that validate_field_real_time queues field validation."""
	validation_framework.enable_real_time_validation = true
	
	var success: bool = validation_framework.validate_field_real_time("ui_scale", 1.5, "menu_system")
	
	assert_that(success).is_true()
	assert_that(validation_framework.real_time_validators.has("ui_scale")).is_true()

func test_validate_field_real_time_disabled_when_setting_disabled() -> void:
	"""Test that validate_field_real_time is disabled when setting is disabled."""
	validation_framework.enable_real_time_validation = false
	
	var success: bool = validation_framework.validate_field_real_time("ui_scale", 1.5, "menu_system")
	
	assert_that(success).is_true()
	assert_that(validation_framework.real_time_validators).is_empty()

func test_real_time_validation_processes_queued_validations() -> void:
	"""Test that real-time validation processes queued validations."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(validation_framework)
	validation_framework.enable_real_time_validation = true
	
	# Queue several validations
	validation_framework.validate_field_real_time("ui_scale", 1.5, "menu_system")
	validation_framework.validate_field_real_time("animation_speed", 1.2, "menu_system")
	
	# Manually trigger processing
	validation_framework._process_real_time_validations()
	
	assert_signal(signal_monitor).is_emitted("real_time_feedback_updated", [2])

func test_real_time_validation_validates_field_values() -> void:
	"""Test that real-time validation validates field values correctly."""
	validation_framework.enable_real_time_validation = true
	
	# Valid value
	var valid_result: bool = validation_framework._validate_field_value("ui_scale", 1.5, "menu_system")
	assert_that(valid_result).is_true()
	
	# Invalid value
	var invalid_result: bool = validation_framework._validate_field_value("ui_scale", 10.0, "menu_system")
	assert_that(invalid_result).is_false()

func test_real_time_validation_provides_error_messages() -> void:
	"""Test that real-time validation provides appropriate error messages."""
	var error_message: String = validation_framework._get_field_validation_error("ui_scale", 10.0, "menu_system")
	
	assert_that(error_message).is_not_empty()
	assert_that(error_message).contains("must be between")
	assert_that(error_message).contains("10")

# ============================================================================
# VALIDATION RULES TESTS
# ============================================================================

func test_register_validation_rule_adds_rule() -> void:
	"""Test that register_validation_rule adds validation rule."""
	var custom_rule: Callable = func(settings: Resource) -> SettingsValidationFramework.ValidationRuleResult:
		var result: SettingsValidationFramework.ValidationRuleResult = SettingsValidationFramework.ValidationRuleResult.new()
		result.rule_name = "test_rule"
		return result
	
	validation_framework.register_validation_rule("test_rule", custom_rule, ["menu_system"])
	
	var rules: Array[String] = validation_framework.get_validation_rules()
	assert_that(rules).contains("test_rule")

func test_enable_validation_rule_toggles_rule() -> void:
	"""Test that enable_validation_rule toggles rule enabled state."""
	# Register a rule first
	var custom_rule: Callable = func(settings: Resource) -> SettingsValidationFramework.ValidationRuleResult:
		return SettingsValidationFramework.ValidationRuleResult.new()
	
	validation_framework.register_validation_rule("test_rule", custom_rule)
	
	# Disable rule
	validation_framework.enable_validation_rule("test_rule", false)
	
	assert_that(validation_framework.validation_rules["test_rule"]["enabled"]).is_false()

func test_default_validation_rules_are_registered() -> void:
	"""Test that default validation rules are registered during initialization."""
	var rules: Array[String] = validation_framework.get_validation_rules()
	
	assert_that(rules).contains("settings_consistency")
	assert_that(rules).contains("performance_compatibility")
	assert_that(rules).contains("accessibility_coherence")
	assert_that(rules).contains("resource_limits")

func test_settings_consistency_rule_detects_conflicts() -> void:
	"""Test that settings_consistency rule detects conflicting settings."""
	# Create conflicting settings
	test_menu_settings.reduce_menu_effects = true
	test_menu_settings.particle_effects_enabled = true  # Conflict
	
	var result: SettingsValidationFramework.ValidationRuleResult = validation_framework._validate_settings_consistency(test_menu_settings)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()

func test_performance_compatibility_rule_detects_issues() -> void:
	"""Test that performance_compatibility rule detects performance issues."""
	# Create performance conflict
	test_menu_settings.max_menu_fps = 120
	test_menu_settings.reduce_menu_effects = true  # Conflict
	
	var result: SettingsValidationFramework.ValidationRuleResult = validation_framework._validate_performance_compatibility(test_menu_settings)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()

func test_accessibility_coherence_rule_detects_incoherence() -> void:
	"""Test that accessibility_coherence rule detects incoherent settings."""
	# Create accessibility incoherence
	test_menu_settings.screen_reader_support = true
	test_menu_settings.keyboard_navigation_enabled = false  # Conflict
	
	var result: SettingsValidationFramework.ValidationRuleResult = validation_framework._validate_accessibility_coherence(test_menu_settings)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()

func test_resource_limits_rule_detects_excessive_usage() -> void:
	"""Test that resource_limits rule detects excessive resource usage."""
	# Create high resource usage settings
	test_menu_settings.preload_assets = true
	test_menu_settings.particle_effects_enabled = true
	test_menu_settings.auto_backup_interval = 30  # Too frequent
	
	var result: SettingsValidationFramework.ValidationRuleResult = validation_framework._validate_resource_limits(test_menu_settings)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.errors).is_not_empty()

# ============================================================================
# VALIDATION CACHING TESTS
# ============================================================================

func test_validation_caching_stores_results() -> void:
	"""Test that validation caching stores validation results."""
	validation_framework.enable_validation_caching = true
	
	# Perform validation (should be cached)
	var result1: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(test_menu_settings, "menu_system")
	
	# Perform same validation (should use cache)
	var result2: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(test_menu_settings, "menu_system")
	
	assert_that(result1.is_valid).is_equal(result2.is_valid)
	assert_that(validation_framework.validation_cache).is_not_empty()

func test_validation_caching_respects_ttl() -> void:
	"""Test that validation caching respects TTL."""
	validation_framework.enable_validation_caching = true
	validation_framework.validation_cache_ttl = 0.1  # Very short TTL
	
	# Perform validation
	validation_framework.validate_settings(test_menu_settings, "menu_system")
	assert_that(validation_framework.validation_cache).is_not_empty()
	
	# Wait for TTL to expire
	await get_tree().create_timer(0.2).timeout
	
	# Cache should be cleaned up on next validation
	validation_framework.validate_settings(test_menu_settings, "menu_system")

func test_clear_validation_cache_clears_cache() -> void:
	"""Test that clear_validation_cache clears the cache."""
	validation_framework.enable_validation_caching = true
	
	# Populate cache
	validation_framework.validate_settings(test_menu_settings, "menu_system")
	assert_that(validation_framework.validation_cache).is_not_empty()
	
	# Clear cache
	validation_framework.clear_validation_cache()
	
	assert_that(validation_framework.validation_cache).is_empty()

func test_caching_disabled_doesnt_cache() -> void:
	"""Test that caching disabled doesn't cache results."""
	validation_framework.enable_validation_caching = false
	
	validation_framework.validate_settings(test_menu_settings, "menu_system")
	
	assert_that(validation_framework.validation_cache).is_empty()

# ============================================================================
# VALIDATION SCORE TESTS
# ============================================================================

func test_calculate_validation_score_perfect_score() -> void:
	"""Test that _calculate_validation_score returns perfect score for no errors."""
	var score: float = validation_framework._calculate_validation_score([])
	
	assert_that(score).is_equal(1.0)

func test_calculate_validation_score_reduced_for_errors() -> void:
	"""Test that _calculate_validation_score reduces score for errors."""
	var errors: Array[String] = ["Some error", "Another error"]
	var score: float = validation_framework._calculate_validation_score(errors)
	
	assert_that(score).is_less(1.0)
	assert_that(score).is_greater_equal(0.0)

func test_calculate_validation_score_critical_errors_reduce_more() -> void:
	"""Test that critical errors reduce score more than warnings."""
	var critical_errors: Array[String] = ["Critical error", "Invalid data"]
	var warning_errors: Array[String] = ["Warning message", "Minor issue"]
	
	var critical_score: float = validation_framework._calculate_validation_score(critical_errors)
	var warning_score: float = validation_framework._calculate_validation_score(warning_errors)
	
	assert_that(critical_score).is_less(warning_score)

# ============================================================================
# STATISTICS AND UTILITIES TESTS
# ============================================================================

func test_get_validation_statistics_returns_stats() -> void:
	"""Test that get_validation_statistics returns framework statistics."""
	var stats: Dictionary = validation_framework.get_validation_statistics()
	
	assert_that(stats.has("cached_validations")).is_true()
	assert_that(stats.has("active_validations")).is_true()
	assert_that(stats.has("registered_rules")).is_true()
	assert_that(stats.has("real_time_validators")).is_true()
	assert_that(stats.has("cache_enabled")).is_true()
	assert_that(stats.has("real_time_enabled")).is_true()

func test_cache_key_generation_consistent() -> void:
	"""Test that cache key generation is consistent for same settings."""
	var key1: String = validation_framework._generate_cache_key(test_menu_settings, "menu_system")
	var key2: String = validation_framework._generate_cache_key(test_menu_settings, "menu_system")
	
	assert_that(key1).is_equal(key2)

func test_cache_key_generation_different_for_different_settings() -> void:
	"""Test that cache key generation differs for different settings."""
	var settings2: MenuSettingsData = MenuSettingsData.new()
	settings2.ui_scale = 2.0  # Different value
	
	var key1: String = validation_framework._generate_cache_key(test_menu_settings, "menu_system")
	var key2: String = validation_framework._generate_cache_key(settings2, "menu_system")
	
	assert_that(key1).is_not_equal(key2)

# ============================================================================
# FIELD VALIDATION TESTS
# ============================================================================

func test_field_validation_ui_scale() -> void:
	"""Test field validation for ui_scale."""
	assert_that(validation_framework._validate_field_value("ui_scale", 1.0, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("ui_scale", 0.5, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("ui_scale", 3.0, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("ui_scale", 0.4, "menu_system")).is_false()
	assert_that(validation_framework._validate_field_value("ui_scale", 3.1, "menu_system")).is_false()

func test_field_validation_animation_speed() -> void:
	"""Test field validation for animation_speed."""
	assert_that(validation_framework._validate_field_value("animation_speed", 1.0, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("animation_speed", 0.1, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("animation_speed", 5.0, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("animation_speed", 0.09, "menu_system")).is_false()
	assert_that(validation_framework._validate_field_value("animation_speed", 5.1, "menu_system")).is_false()

func test_field_validation_max_menu_fps() -> void:
	"""Test field validation for max_menu_fps."""
	assert_that(validation_framework._validate_field_value("max_menu_fps", 60, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("max_menu_fps", 30, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("max_menu_fps", 120, "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("max_menu_fps", 29, "menu_system")).is_false()
	assert_that(validation_framework._validate_field_value("max_menu_fps", 121, "menu_system")).is_false()

func test_field_validation_volumes() -> void:
	"""Test field validation for volume settings."""
	var volume_fields: Array[String] = ["menu_volume", "background_music_volume", "sound_effects_volume", "voice_volume"]
	
	for field in volume_fields:
		assert_that(validation_framework._validate_field_value(field, 0.0, "menu_system")).is_true()
		assert_that(validation_framework._validate_field_value(field, 0.5, "menu_system")).is_true()
		assert_that(validation_framework._validate_field_value(field, 1.0, "menu_system")).is_true()
		assert_that(validation_framework._validate_field_value(field, -0.1, "menu_system")).is_false()
		assert_that(validation_framework._validate_field_value(field, 1.1, "menu_system")).is_false()

func test_field_validation_string_fields() -> void:
	"""Test field validation for string fields."""
	assert_that(validation_framework._validate_field_value("menu_audio_bus", "UI", "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("menu_audio_bus", "", "menu_system")).is_false()
	
	assert_that(validation_framework._validate_field_value("ui_theme", "default", "menu_system")).is_true()
	assert_that(validation_framework._validate_field_value("ui_theme", "", "menu_system")).is_false()

func test_field_validation_unknown_fields() -> void:
	"""Test field validation for unknown fields."""
	# Unknown fields should pass by default
	assert_that(validation_framework._validate_field_value("unknown_field", "any_value", "menu_system")).is_true()

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_complete_validation_workflow() -> void:
	"""Test complete validation workflow with all components."""
	var signal_monitor: GdUnitSignalMonitor = monitor_signals(validation_framework)
	
	# Enable all features
	validation_framework.enable_real_time_validation = true
	validation_framework.enable_validation_caching = true
	
	# Perform comprehensive validation
	var result: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(test_menu_settings, "menu_system")
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid).is_true()
	assert_signal(signal_monitor).is_emitted("validation_started")
	assert_signal(signal_monitor).is_emitted("validation_completed")

func test_validation_with_custom_rules() -> void:
	"""Test validation with custom rules."""
	# Register custom rule
	var custom_rule: Callable = func(settings: Resource) -> SettingsValidationFramework.ValidationRuleResult:
		var result: SettingsValidationFramework.ValidationRuleResult = SettingsValidationFramework.ValidationRuleResult.new()
		result.rule_name = "custom_test_rule"
		if settings is MenuSettingsData:
			var menu_settings: MenuSettingsData = settings as MenuSettingsData
			if menu_settings.ui_scale > 2.0:
				result.errors.append("UI scale too high for custom rule")
				result.is_valid = false
		return result
	
	validation_framework.register_validation_rule("custom_test_rule", custom_rule, ["menu_system"])
	
	# Test with valid settings
	var result1: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(test_menu_settings, "menu_system")
	assert_that(result1.is_valid).is_true()
	
	# Test with invalid settings
	test_menu_settings.ui_scale = 2.5
	var result2: SettingsValidationFramework.ValidationResult = validation_framework.validate_settings(test_menu_settings, "menu_system")
	assert_that(result2.is_valid).is_false()
	assert_that(result2.errors).contains("UI scale too high for custom rule")

# ============================================================================
# MOCK GRAPHICS SETTINGS
# ============================================================================

class MockGraphicsSettings:
	extends Resource
	
	var target_fps: int = 60
	var vsync_enabled: bool = true
	
	func is_valid() -> bool:
		return true
	
	func get_validation_errors() -> Array[String]:
		return []
	
	func to_dictionary() -> Dictionary:
		return {"target_fps": target_fps, "vsync_enabled": vsync_enabled}