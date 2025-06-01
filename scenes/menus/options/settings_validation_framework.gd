class_name SettingsValidationFramework
extends Node

## Settings validation framework for WCS-Godot conversion.
## Provides real-time validation feedback, rule management, and validation result caching.
## Supports custom validation rules and comprehensive error reporting.

signal validation_started(settings_type: String)
signal validation_completed(settings_type: String, is_valid: bool, errors: Array[String])
signal validation_rule_triggered(rule_name: String, error_message: String)
signal validation_error_resolved(rule_name: String)
signal real_time_feedback_updated(field_name: String, is_valid: bool, error_message: String)

# Validation state
var validation_cache: Dictionary = {}
var active_validations: Dictionary = {}
var validation_rules: Dictionary = {}
var real_time_validators: Dictionary = {}

# Configuration
@export var enable_real_time_validation: bool = true
@export var enable_validation_caching: bool = true
@export var validation_cache_ttl: float = 5.0
@export var batch_validation_threshold: int = 10

# Real-time validation timer
var real_time_timer: Timer = null

func _ready() -> void:
	"""Initialize validation framework."""
	name = "SettingsValidationFramework"
	_setup_real_time_validation()
	_register_default_validation_rules()

func _setup_real_time_validation() -> void:
	"""Setup real-time validation timer."""
	if enable_real_time_validation:
		real_time_timer = Timer.new()
		real_time_timer.wait_time = 0.5  # 500ms validation delay
		real_time_timer.one_shot = true
		real_time_timer.timeout.connect(_process_real_time_validations)
		add_child(real_time_timer)

# ============================================================================
# PUBLIC API
# ============================================================================

func validate_settings(settings: Resource, settings_type: String = "unknown") -> ValidationResult:
	"""Validate settings and return comprehensive result."""
	validation_started.emit(settings_type)
	
	if not settings:
		var result: ValidationResult = ValidationResult.new()
		result.is_valid = false
		result.errors = ["Settings object is null"]
		result.settings_type = settings_type
		validation_completed.emit(settings_type, false, result.errors)
		return result
	
	# Check cache first
	if enable_validation_caching:
		var cached_result: ValidationResult = _get_cached_validation(settings, settings_type)
		if cached_result:
			validation_completed.emit(settings_type, cached_result.is_valid, cached_result.errors)
			return cached_result
	
	# Perform validation
	var result: ValidationResult = _perform_comprehensive_validation(settings, settings_type)
	
	# Cache result
	if enable_validation_caching:
		_cache_validation_result(settings, settings_type, result)
	
	validation_completed.emit(settings_type, result.is_valid, result.errors)
	return result

func validate_field_real_time(field_name: String, field_value: Variant, settings_type: String = "unknown") -> bool:
	"""Validate individual field in real-time."""
	if not enable_real_time_validation:
		return true
	
	# Store validation request
	real_time_validators[field_name] = {
		"value": field_value,
		"settings_type": settings_type,
		"timestamp": Time.get_ticks_msec()
	}
	
	# Restart timer for batched validation
	real_time_timer.start()
	
	return true

func register_validation_rule(rule_name: String, validation_func: Callable, settings_types: Array[String] = []) -> void:
	"""Register custom validation rule."""
	validation_rules[rule_name] = {
		"function": validation_func,
		"settings_types": settings_types,
		"enabled": true
	}

func enable_validation_rule(rule_name: String, enabled: bool) -> void:
	"""Enable or disable validation rule."""
	if validation_rules.has(rule_name):
		validation_rules[rule_name]["enabled"] = enabled

func get_validation_rules() -> Array[String]:
	"""Get list of registered validation rules."""
	return validation_rules.keys()

func clear_validation_cache() -> void:
	"""Clear all cached validation results."""
	validation_cache.clear()

func get_validation_statistics() -> Dictionary:
	"""Get validation framework statistics."""
	return {
		"cached_validations": validation_cache.size(),
		"active_validations": active_validations.size(),
		"registered_rules": validation_rules.size(),
		"real_time_validators": real_time_validators.size(),
		"cache_enabled": enable_validation_caching,
		"real_time_enabled": enable_real_time_validation
	}

# ============================================================================
# VALIDATION METHODS
# ============================================================================

func _perform_comprehensive_validation(settings: Resource, settings_type: String) -> ValidationResult:
	"""Perform comprehensive validation with all rules."""
	var result: ValidationResult = ValidationResult.new()
	result.settings_type = settings_type
	result.validation_timestamp = Time.get_unix_time_from_system()
	
	# Basic resource validation
	if not settings.has_method("is_valid"):
		result.errors.append("Settings object does not implement is_valid() method")
		result.is_valid = false
		return result
	
	if not settings.has_method("get_validation_errors"):
		result.errors.append("Settings object does not implement get_validation_errors() method")
		result.is_valid = false
		return result
	
	# Get built-in validation errors
	var built_in_errors: Array[String] = settings.get_validation_errors()
	result.errors.append_array(built_in_errors)
	
	# Apply custom validation rules
	for rule_name in validation_rules:
		var rule: Dictionary = validation_rules[rule_name]
		
		if not rule.enabled:
			continue
		
		# Check if rule applies to this settings type
		var rule_settings_types: Array[String] = rule.settings_types
		if not rule_settings_types.is_empty() and not rule_settings_types.has(settings_type):
			continue
		
		var rule_func: Callable = rule.function
		var rule_result: ValidationRuleResult = rule_func.call(settings)
		
		if not rule_result.is_valid:
			result.errors.append_array(rule_result.errors)
			result.rule_failures[rule_name] = rule_result.errors
			validation_rule_triggered.emit(rule_name, rule_result.errors[0] if not rule_result.errors.is_empty() else "Unknown error")
		else:
			validation_error_resolved.emit(rule_name)
	
	# Calculate validation score
	result.validation_score = _calculate_validation_score(result.errors)
	result.is_valid = result.errors.is_empty()
	
	return result

func _calculate_validation_score(errors: Array[String]) -> float:
	"""Calculate validation score based on error severity."""
	if errors.is_empty():
		return 1.0
	
	var score: float = 1.0
	var critical_errors: int = 0
	var warning_errors: int = 0
	
	for error in errors:
		if error.contains("critical") or error.contains("invalid") or error.contains("corrupted"):
			critical_errors += 1
			score -= 0.3
		else:
			warning_errors += 1
			score -= 0.1
	
	return max(0.0, score)

func _get_cached_validation(settings: Resource, settings_type: String) -> ValidationResult:
	"""Get cached validation result if available and valid."""
	var cache_key: String = _generate_cache_key(settings, settings_type)
	
	if not validation_cache.has(cache_key):
		return null
	
	var cached_data: Dictionary = validation_cache[cache_key]
	var cache_age: float = Time.get_unix_time_from_system() - cached_data.timestamp
	
	if cache_age > validation_cache_ttl:
		validation_cache.erase(cache_key)
		return null
	
	return cached_data.result

func _cache_validation_result(settings: Resource, settings_type: String, result: ValidationResult) -> void:
	"""Cache validation result."""
	var cache_key: String = _generate_cache_key(settings, settings_type)
	
	validation_cache[cache_key] = {
		"result": result,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Cleanup old cache entries
	_cleanup_validation_cache()

func _generate_cache_key(settings: Resource, settings_type: String) -> String:
	"""Generate cache key for settings validation."""
	var settings_hash: int = 0
	
	if settings.has_method("to_dictionary"):
		var settings_dict: Dictionary = settings.to_dictionary()
		var dict_string: String = JSON.stringify(settings_dict)
		settings_hash = dict_string.hash()
	else:
		settings_hash = settings.get_instance_id()
	
	return "%s_%d" % [settings_type, settings_hash]

func _cleanup_validation_cache() -> void:
	"""Clean up expired cache entries."""
	var current_time: float = Time.get_unix_time_from_system()
	var keys_to_remove: Array[String] = []
	
	for cache_key in validation_cache:
		var cached_data: Dictionary = validation_cache[cache_key]
		var cache_age: float = current_time - cached_data.timestamp
		
		if cache_age > validation_cache_ttl:
			keys_to_remove.append(cache_key)
	
	for key in keys_to_remove:
		validation_cache.erase(key)

func _process_real_time_validations() -> void:
	"""Process queued real-time validations."""
	for field_name in real_time_validators:
		var validator_data: Dictionary = real_time_validators[field_name]
		var field_value: Variant = validator_data.value
		var settings_type: String = validator_data.settings_type
		
		var is_valid: bool = _validate_field_value(field_name, field_value, settings_type)
		var error_message: String = ""
		
		if not is_valid:
			error_message = _get_field_validation_error(field_name, field_value, settings_type)
		
		real_time_feedback_updated.emit(field_name, is_valid, error_message)
	
	real_time_validators.clear()

func _validate_field_value(field_name: String, field_value: Variant, settings_type: String) -> bool:
	"""Validate individual field value."""
	# Apply field-specific validation rules
	match field_name:
		"ui_scale":
			return field_value >= 0.5 and field_value <= 3.0
		"animation_speed":
			return field_value >= 0.1 and field_value <= 5.0
		"max_menu_fps":
			return field_value >= 30 and field_value <= 120
		"menu_volume", "background_music_volume", "sound_effects_volume", "voice_volume":
			return field_value >= 0.0 and field_value <= 1.0
		"background_dim_amount":
			return field_value >= 0.0 and field_value <= 1.0
		"double_click_speed":
			return field_value > 0.0 and field_value <= 2.0
		"hover_select_delay":
			return field_value >= 0.0 and field_value <= 5.0
		"auto_backup_interval":
			return field_value >= 60 and field_value <= 3600
		"menu_audio_bus":
			return not field_value.is_empty()
		"ui_theme":
			return not field_value.is_empty()
		_:
			return true  # Unknown fields pass by default

func _get_field_validation_error(field_name: String, field_value: Variant, settings_type: String) -> String:
	"""Get specific error message for field validation failure."""
	match field_name:
		"ui_scale":
			return "UI scale must be between 0.5 and 3.0 (current: %s)" % field_value
		"animation_speed":
			return "Animation speed must be between 0.1 and 5.0 (current: %s)" % field_value
		"max_menu_fps":
			return "Max menu FPS must be between 30 and 120 (current: %s)" % field_value
		"menu_volume", "background_music_volume", "sound_effects_volume", "voice_volume":
			return "Volume must be between 0.0 and 1.0 (current: %s)" % field_value
		"background_dim_amount":
			return "Background dim amount must be between 0.0 and 1.0 (current: %s)" % field_value
		"double_click_speed":
			return "Double click speed must be between 0.0 and 2.0 (current: %s)" % field_value
		"hover_select_delay":
			return "Hover select delay must be between 0.0 and 5.0 (current: %s)" % field_value
		"auto_backup_interval":
			return "Auto backup interval must be between 60 and 3600 seconds (current: %s)" % field_value
		"menu_audio_bus", "ui_theme":
			return "Field cannot be empty"
		_:
			return "Invalid value: %s" % field_value

# ============================================================================
# DEFAULT VALIDATION RULES
# ============================================================================

func _register_default_validation_rules() -> void:
	"""Register default validation rules."""
	register_validation_rule("settings_consistency", _validate_settings_consistency, ["menu_system"])
	register_validation_rule("performance_compatibility", _validate_performance_compatibility, ["menu_system", "graphics", "audio"])
	register_validation_rule("accessibility_coherence", _validate_accessibility_coherence, ["menu_system"])
	register_validation_rule("resource_limits", _validate_resource_limits, ["menu_system", "graphics", "audio"])

func _validate_settings_consistency(settings: Resource) -> ValidationRuleResult:
	"""Validate internal settings consistency."""
	var result: ValidationRuleResult = ValidationRuleResult.new()
	result.rule_name = "settings_consistency"
	
	if not settings is MenuSettingsData:
		result.errors.append("Settings object is not MenuSettingsData type")
		return result
	
	var menu_settings: MenuSettingsData = settings as MenuSettingsData
	
	# Check consistency between related settings
	if menu_settings.reduce_menu_effects and menu_settings.particle_effects_enabled:
		result.errors.append("Reduce menu effects is enabled but particle effects are still enabled")
	
	if menu_settings.motion_reduction and menu_settings.animation_speed > 1.0:
		result.errors.append("Motion reduction is enabled but animation speed is above normal")
	
	if menu_settings.memory_optimization and menu_settings.preload_assets:
		result.errors.append("Memory optimization is enabled but asset preloading is still enabled")
	
	if not menu_settings.menu_music_enabled and menu_settings.background_music_volume > 0.0:
		result.errors.append("Menu music is disabled but background music volume is above zero")
	
	result.is_valid = result.errors.is_empty()
	return result

func _validate_performance_compatibility(settings: Resource) -> ValidationRuleResult:
	"""Validate performance-related settings compatibility."""
	var result: ValidationRuleResult = ValidationRuleResult.new()
	result.rule_name = "performance_compatibility"
	
	if not settings is MenuSettingsData:
		result.errors.append("Settings object is not MenuSettingsData type")
		return result
	
	var menu_settings: MenuSettingsData = settings as MenuSettingsData
	
	# Check for performance conflicts
	if menu_settings.max_menu_fps > 60 and menu_settings.reduce_menu_effects:
		result.errors.append("High FPS with reduced effects may not provide performance benefits")
	
	if not menu_settings.vsync_enabled and menu_settings.max_menu_fps > 120:
		result.errors.append("Very high FPS without vsync may cause screen tearing")
	
	if menu_settings.memory_optimization and menu_settings.max_menu_fps > 60:
		result.errors.append("Memory optimization with high FPS may cause performance issues")
	
	result.is_valid = result.errors.is_empty()
	return result

func _validate_accessibility_coherence(settings: Resource) -> ValidationRuleResult:
	"""Validate accessibility settings coherence."""
	var result: ValidationRuleResult = ValidationRuleResult.new()
	result.rule_name = "accessibility_coherence"
	
	if not settings is MenuSettingsData:
		result.errors.append("Settings object is not MenuSettingsData type")
		return result
	
	var menu_settings: MenuSettingsData = settings as MenuSettingsData
	
	# Check accessibility coherence
	if menu_settings.screen_reader_support and not menu_settings.keyboard_navigation_enabled:
		result.errors.append("Screen reader support requires keyboard navigation to be enabled")
	
	if menu_settings.motion_reduction and menu_settings.screen_flash_effects:
		result.errors.append("Motion reduction is enabled but screen flash effects are still enabled")
	
	if menu_settings.large_text_mode and menu_settings.ui_scale < 1.2:
		result.errors.append("Large text mode should use UI scale of at least 1.2")
	
	result.is_valid = result.errors.is_empty()
	return result

func _validate_resource_limits(settings: Resource) -> ValidationRuleResult:
	"""Validate resource usage limits."""
	var result: ValidationRuleResult = ValidationRuleResult.new()
	result.rule_name = "resource_limits"
	
	if not settings is MenuSettingsData:
		result.errors.append("Settings object is not MenuSettingsData type")
		return result
	
	var menu_settings: MenuSettingsData = settings as MenuSettingsData
	
	# Estimate resource usage and check limits
	var estimated_memory: float = menu_settings.get_estimated_memory_usage()
	
	if estimated_memory > 100.0:  # 100MB limit
		result.errors.append("Estimated memory usage exceeds recommended limit: %s MB" % estimated_memory)
	
	if menu_settings.auto_backup_interval < 60:
		result.errors.append("Auto backup interval too frequent - may impact performance")
	
	result.is_valid = result.errors.is_empty()
	return result

# ============================================================================
# VALIDATION RESULT CLASSES
# ============================================================================

class ValidationResult:
	extends RefCounted
	
	var is_valid: bool = false
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var rule_failures: Dictionary = {}
	var validation_score: float = 0.0
	var settings_type: String = ""
	var validation_timestamp: float = 0.0

class ValidationRuleResult:
	extends RefCounted
	
	var is_valid: bool = true
	var errors: Array[String] = []
	var rule_name: String = ""

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_validation_framework() -> SettingsValidationFramework:
	"""Create a new validation framework instance."""
	var framework: SettingsValidationFramework = SettingsValidationFramework.new()
	return framework