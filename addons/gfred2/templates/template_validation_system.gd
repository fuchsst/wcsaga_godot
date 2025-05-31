@tool
class_name TemplateValidationSystem
extends RefCounted

## Template validation system for GFRED2 Template Library.
## Integrates with addons/wcs_asset_core asset system and addons/sexp system for comprehensive validation.

signal validation_completed(template_id: String, is_valid: bool, errors: Array[String], warnings: Array[String])
signal batch_validation_completed(results: Dictionary)

# Core system references
var asset_registry: WCSAssetRegistry
var sexp_manager: SexpManager
var template_manager: TemplateLibraryManager

# Validation cache for performance
var validation_cache: Dictionary = {}
var cache_timestamps: Dictionary = {}
const CACHE_EXPIRY_SECONDS: int = 300 # 5 minutes

func _init() -> void:
	asset_registry = WCSAssetRegistry
	sexp_manager = SexpManager
	template_manager = TemplateLibraryManager.new()

## Validates a mission template comprehensively
func validate_mission_template(template: MissionTemplate, force_refresh: bool = false) -> Dictionary:
	if not template:
		return _create_validation_result(false, ["Template is null"], [])
	
	# Check cache first
	var cache_key: String = template.template_id + "_" + template.modified_date
	if not force_refresh and validation_cache.has(cache_key):
		var cached_time: int = cache_timestamps.get(cache_key, 0)
		if Time.get_unix_time_from_system() - cached_time < CACHE_EXPIRY_SECONDS:
			return validation_cache[cache_key]
	
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	print("Validating mission template: " + template.template_name)
	
	# Validate basic template structure
	_validate_template_structure(template, errors, warnings)
	
	# Validate required assets
	_validate_template_assets(template, errors, warnings)
	
	# Validate SEXP requirements
	_validate_template_sexp_requirements(template, errors, warnings)
	
	# Validate mission data if present
	if template.template_mission_data:
		_validate_template_mission_data(template.template_mission_data, errors, warnings)
	
	# Validate parameter definitions
	_validate_template_parameters(template, errors, warnings)
	
	# Create result
	var result: Dictionary = _create_validation_result(errors.is_empty(), errors, warnings)
	
	# Cache result
	validation_cache[cache_key] = result
	cache_timestamps[cache_key] = Time.get_unix_time_from_system()
	
	# Emit signal
	validation_completed.emit(template.template_id, result.is_valid, errors, warnings)
	
	return result

## Validates a SEXP pattern
func validate_sexp_pattern(pattern: SexpPattern, force_refresh: bool = false) -> Dictionary:
	if not pattern:
		return _create_validation_result(false, ["Pattern is null"], [])
	
	# Check cache
	var cache_key: String = "sexp_" + pattern.pattern_id
	if not force_refresh and validation_cache.has(cache_key):
		var cached_time: int = cache_timestamps.get(cache_key, 0)
		if Time.get_unix_time_from_system() - cached_time < CACHE_EXPIRY_SECONDS:
			return validation_cache[cache_key]
	
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	print("Validating SEXP pattern: " + pattern.pattern_name)
	
	# Validate pattern structure
	_validate_sexp_pattern_structure(pattern, errors, warnings)
	
	# Validate SEXP syntax
	_validate_sexp_pattern_syntax(pattern, errors, warnings)
	
	# Validate required functions
	_validate_sexp_pattern_functions(pattern, errors, warnings)
	
	# Validate parameter placeholders
	_validate_sexp_pattern_parameters(pattern, errors, warnings)
	
	# Create result
	var result: Dictionary = _create_validation_result(errors.is_empty(), errors, warnings)
	
	# Cache result
	validation_cache[cache_key] = result
	cache_timestamps[cache_key] = Time.get_unix_time_from_system()
	
	return result

## Validates an asset pattern
func validate_asset_pattern(pattern: AssetPattern, force_refresh: bool = false) -> Dictionary:
	if not pattern:
		return _create_validation_result(false, ["Pattern is null"], [])
	
	# Check cache
	var cache_key: String = "asset_" + pattern.pattern_id
	if not force_refresh and validation_cache.has(cache_key):
		var cached_time: int = cache_timestamps.get(cache_key, 0)
		if Time.get_unix_time_from_system() - cached_time < CACHE_EXPIRY_SECONDS:
			return validation_cache[cache_key]
	
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	print("Validating asset pattern: " + pattern.pattern_name)
	
	# Validate pattern structure
	_validate_asset_pattern_structure(pattern, errors, warnings)
	
	# Validate asset availability
	_validate_asset_pattern_assets(pattern, errors, warnings)
	
	# Validate weapon compatibility
	_validate_asset_pattern_weapons(pattern, errors, warnings)
	
	# Validate configuration coherence
	_validate_asset_pattern_configuration(pattern, errors, warnings)
	
	# Create result
	var result: Dictionary = _create_validation_result(errors.is_empty(), errors, warnings)
	
	# Cache result
	validation_cache[cache_key] = result
	cache_timestamps[cache_key] = Time.get_unix_time_from_system()
	
	return result

## Validates template structure and metadata
func _validate_template_structure(template: MissionTemplate, errors: Array[String], warnings: Array[String]) -> void:
	# Check required fields
	if template.template_name.is_empty():
		errors.append("Template name is required")
	
	if template.template_id.is_empty():
		errors.append("Template ID is required")
	
	if template.description.is_empty():
		warnings.append("Template description is recommended")
	
	if template.author.is_empty():
		warnings.append("Template author is recommended")
	
	# Check template type validity
	if template.template_type < 0 or template.template_type >= MissionTemplate.TemplateType.size():
		errors.append("Invalid template type")
	
	# Check difficulty validity
	if template.difficulty < 0 or template.difficulty >= MissionTemplate.Difficulty.size():
		errors.append("Invalid difficulty level")
	
	# Check duration reasonableness
	if template.estimated_duration_minutes <= 0:
		warnings.append("Estimated duration should be positive")
	elif template.estimated_duration_minutes > 120:
		warnings.append("Very long mission duration (>2 hours)")

## Validates template asset requirements
func _validate_template_assets(template: MissionTemplate, errors: Array[String], warnings: Array[String]) -> void:
	for asset_path in template.required_assets:
		if not asset_registry.asset_exists(asset_path):
			errors.append("Required asset not found: " + asset_path)
		else:
			# Check if asset is actually used in template
			var asset_used: bool = _check_asset_usage_in_template(template, asset_path)
			if not asset_used:
				warnings.append("Required asset listed but not used: " + asset_path)

## Validates template SEXP requirements
func _validate_template_sexp_requirements(template: MissionTemplate, errors: Array[String], warnings: Array[String]) -> void:
	for function_name in template.required_sexp_functions:
		if not sexp_manager.function_exists(function_name):
			errors.append("Required SEXP function not available: " + function_name)

## Validates template mission data
func _validate_template_mission_data(mission_data: MissionData, errors: Array[String], warnings: Array[String]) -> void:
	# Validate basic mission data
	var mission_errors: Array[String] = mission_data.validate()
	if not mission_errors.is_empty():
		errors.append("Mission data validation failed:")
		errors.append_array(mission_errors)
	
	# Validate mission objects
	for obj in mission_data.objects.values():
		_validate_mission_object(obj, errors, warnings)
	
	# Validate mission events and SEXP expressions
	for event in mission_data.events:
		_validate_mission_event(event, errors, warnings)
	
	# Validate mission goals
	for goal in mission_data.primary_goals + mission_data.secondary_goals + mission_data.hidden_goals:
		_validate_mission_goal(goal, errors, warnings)

## Validates template parameter definitions
func _validate_template_parameters(template: MissionTemplate, errors: Array[String], warnings: Array[String]) -> void:
	var param_defs: Dictionary = template.get_parameter_definitions()
	
	for param_name in template.parameters.keys():
		if not param_defs.has(param_name):
			warnings.append("Parameter '%s' has no definition" % param_name)
	
	for param_name in param_defs.keys():
		var param_def: Dictionary = param_defs[param_name]
		if not param_def.has("type"):
			warnings.append("Parameter '%s' has no type definition" % param_name)
		if not param_def.has("description"):
			warnings.append("Parameter '%s' has no description" % param_name)

## Validates SEXP pattern structure
func _validate_sexp_pattern_structure(pattern: SexpPattern, errors: Array[String], warnings: Array[String]) -> void:
	if pattern.pattern_name.is_empty():
		errors.append("Pattern name is required")
	
	if pattern.sexp_expression.is_empty():
		errors.append("SEXP expression is required")
	
	if pattern.description.is_empty():
		warnings.append("Pattern description is recommended")
	
	# Check category validity
	if pattern.category < 0 or pattern.category >= SexpPattern.PatternCategory.size():
		errors.append("Invalid pattern category")
	
	# Check complexity validity
	if pattern.complexity < 0 or pattern.complexity >= SexpPattern.ComplexityLevel.size():
		errors.append("Invalid complexity level")

## Validates SEXP pattern syntax
func _validate_sexp_pattern_syntax(pattern: SexpPattern, errors: Array[String], warnings: Array[String]) -> void:
	# Basic syntax validation
	var syntax_valid: bool = sexp_manager.validate_syntax(pattern.sexp_expression)
	if not syntax_valid:
		var syntax_errors: Array[String] = sexp_manager.get_validation_errors(pattern.sexp_expression)
		errors.append("SEXP syntax validation failed:")
		errors.append_array(syntax_errors)
		return
	
	# Check for parameter placeholders in expression
	for placeholder in pattern.parameter_placeholders.keys():
		var placeholder_pattern: String = "{" + placeholder + "}"
		if not pattern.sexp_expression.contains(placeholder_pattern):
			warnings.append("Parameter placeholder '%s' not found in expression" % placeholder)

## Validates SEXP pattern function requirements
func _validate_sexp_pattern_functions(pattern: SexpPattern, errors: Array[String], warnings: Array[String]) -> void:
	for function_name in pattern.required_functions:
		if not sexp_manager.function_exists(function_name):
			errors.append("Required function not available: " + function_name)
		else:
			# Check if function is actually used in expression
			if not pattern.sexp_expression.contains(function_name):
				warnings.append("Required function '%s' not used in expression" % function_name)

## Validates SEXP pattern parameter definitions
func _validate_sexp_pattern_parameters(pattern: SexpPattern, errors: Array[String], warnings: Array[String]) -> void:
	for param_name in pattern.parameter_placeholders.keys():
		var param_info: Dictionary = pattern.parameter_placeholders[param_name]
		
		if not param_info.has("type"):
			warnings.append("Parameter '%s' has no type specified" % param_name)
		
		if not param_info.has("default"):
			warnings.append("Parameter '%s' has no default value" % param_name)
		
		if not param_info.has("description"):
			warnings.append("Parameter '%s' has no description" % param_name)

## Validates asset pattern structure
func _validate_asset_pattern_structure(pattern: AssetPattern, errors: Array[String], warnings: Array[String]) -> void:
	if pattern.pattern_name.is_empty():
		errors.append("Pattern name is required")
	
	if pattern.description.is_empty():
		warnings.append("Pattern description is recommended")
	
	# Check type validity
	if pattern.pattern_type < 0 or pattern.pattern_type >= AssetPattern.PatternType.size():
		errors.append("Invalid pattern type")
	
	# Check role validity
	if pattern.tactical_role < 0 or pattern.tactical_role >= AssetPattern.TacticalRole.size():
		errors.append("Invalid tactical role")
	
	# Check faction validity
	if pattern.faction < 0 or pattern.faction >= AssetPattern.Faction.size():
		errors.append("Invalid faction")

## Validates asset pattern asset availability
func _validate_asset_pattern_assets(pattern: AssetPattern, errors: Array[String], warnings: Array[String]) -> void:
	# Validate ship class
	if not pattern.ship_class.is_empty():
		var ship_found: bool = _check_ship_class_exists(pattern.ship_class)
		if not ship_found:
			errors.append("Ship class not found: " + pattern.ship_class)
	
	# Validate required assets
	for asset_path in pattern.required_assets:
		if not asset_registry.asset_exists(asset_path):
			errors.append("Required asset not found: " + asset_path)

## Validates asset pattern weapon configurations
func _validate_asset_pattern_weapons(pattern: AssetPattern, errors: Array[String], warnings: Array[String]) -> void:
	# Validate primary weapons
	for weapon in pattern.primary_weapons:
		var weapon_found: bool = _check_weapon_exists(weapon)
		if not weapon_found:
			errors.append("Primary weapon not found: " + weapon)
	
	# Validate secondary weapons
	for weapon in pattern.secondary_weapons:
		var weapon_found: bool = _check_weapon_exists(weapon)
		if not weapon_found:
			errors.append("Secondary weapon not found: " + weapon)
	
	# Check weapon loadout consistency
	for bank in pattern.weapon_loadout.keys():
		var weapon: String = pattern.weapon_loadout[bank]
		if not weapon.is_empty():
			var weapon_found: bool = _check_weapon_exists(weapon)
			if not weapon_found:
				errors.append("Loadout weapon not found: " + weapon + " (bank: " + bank + ")")

## Validates asset pattern configuration coherence
func _validate_asset_pattern_configuration(pattern: AssetPattern, errors: Array[String], warnings: Array[String]) -> void:
	# Check wing size reasonableness
	if pattern.wing_size <= 0:
		errors.append("Wing size must be positive")
	elif pattern.wing_size > 12:
		warnings.append("Very large wing size (>12 ships)")
	
	# Check difficulty modifier reasonableness
	if pattern.difficulty_modifier <= 0:
		errors.append("Difficulty modifier must be positive")
	elif pattern.difficulty_modifier > 5.0:
		warnings.append("Extreme difficulty modifier (>5.0x)")
	
	# Check pattern type consistency
	match pattern.pattern_type:
		AssetPattern.PatternType.SHIP_LOADOUT:
			if pattern.ship_class.is_empty():
				errors.append("Ship loadout pattern requires ship class")
		
		AssetPattern.PatternType.WING_FORMATION:
			if pattern.wing_size <= 1:
				warnings.append("Wing formation with only one ship")
		
		AssetPattern.PatternType.WEAPON_CONFIG:
			if pattern.primary_weapons.is_empty() and pattern.secondary_weapons.is_empty():
				warnings.append("Weapon config pattern has no weapons specified")

## Validates mission object asset references
func _validate_mission_object(obj: MissionObject, errors: Array[String], warnings: Array[String]) -> void:
	# Validate ship class if object is a ship
	if obj.type == MissionObject.Type.SHIP:
		var ship_class: String = obj.get_property("ship_class", "")
		if not ship_class.is_empty():
			var ship_found: bool = _check_ship_class_exists(ship_class)
			if not ship_found:
				errors.append("Ship class not found for object '%s': %s" % [obj.name, ship_class])
		else:
			warnings.append("Ship object '%s' has no ship class specified" % obj.name)

## Validates mission event SEXP expressions
func _validate_mission_event(event: MissionEvent, errors: Array[String], warnings: Array[String]) -> void:
	# Validate condition SEXP
	if not event.condition_sexp.is_empty():
		var condition_valid: bool = sexp_manager.validate_syntax(event.condition_sexp)
		if not condition_valid:
			var syntax_errors: Array[String] = sexp_manager.get_validation_errors(event.condition_sexp)
			errors.append("Event '%s' condition invalid:" % event.event_name)
			errors.append_array(syntax_errors)
	
	# Validate action SEXP
	if not event.action_sexp.is_empty():
		var action_valid: bool = sexp_manager.validate_syntax(event.action_sexp)
		if not action_valid:
			var syntax_errors: Array[String] = sexp_manager.get_validation_errors(event.action_sexp)
			errors.append("Event '%s' action invalid:" % event.event_name)
			errors.append_array(syntax_errors)

## Validates mission goal conditions
func _validate_mission_goal(goal: MissionGoal, errors: Array[String], warnings: Array[String]) -> void:
	if goal.has_method("get_condition_sexp"):
		var condition: String = goal.get_condition_sexp()
		if not condition.is_empty():
			var condition_valid: bool = sexp_manager.validate_syntax(condition)
			if not condition_valid:
				var syntax_errors: Array[String] = sexp_manager.get_validation_errors(condition)
				errors.append("Goal '%s' condition invalid:" % goal.goal_name)
				errors.append_array(syntax_errors)

## Checks if ship class exists in asset registry
func _check_ship_class_exists(ship_class: String) -> bool:
	var ship_assets: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
	for ship_path in ship_assets:
		var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
		if ship_data and ship_data.ship_name == ship_class:
			return true
	return false

## Checks if weapon exists in asset registry
func _check_weapon_exists(weapon_name: String) -> bool:
	var weapon_assets: Array[String] = asset_registry.get_asset_paths_by_type(AssetTypes.Type.WEAPON)
	for weapon_path in weapon_assets:
		var weapon_data: WeaponData = WCSAssetLoader.load_asset(weapon_path)
		if weapon_data and weapon_data.weapon_name == weapon_name:
			return true
	return false

## Checks if asset is used in template mission data
func _check_asset_usage_in_template(template: MissionTemplate, asset_path: String) -> bool:
	if not template.template_mission_data:
		return false
	
	# Simple check - look for asset name in mission objects and events
	# This is a simplified implementation
	for obj in template.template_mission_data.objects.values():
		if obj.name.contains(asset_path) or obj.id.contains(asset_path):
			return true
	
	for event in template.template_mission_data.events:
		if event.condition_sexp.contains(asset_path) or event.action_sexp.contains(asset_path):
			return true
	
	return false

## Creates validation result dictionary
func _create_validation_result(is_valid: bool, errors: Array[String], warnings: Array[String]) -> Dictionary:
	return {
		"is_valid": is_valid,
		"errors": errors,
		"warnings": warnings,
		"error_count": errors.size(),
		"warning_count": warnings.size(),
		"timestamp": Time.get_unix_time_from_system()
	}

## Validates all templates in the library
func validate_all_templates(force_refresh: bool = false) -> Dictionary:
	var results: Dictionary = {
		"total_templates": 0,
		"valid_templates": 0,
		"invalid_templates": 0,
		"total_errors": 0,
		"total_warnings": 0,
		"template_results": {}
	}
	
	print("Starting batch validation of all templates...")
	
	# Validate mission templates
	var mission_templates: Array[MissionTemplate] = template_manager.get_all_mission_templates()
	for template in mission_templates:
		var result: Dictionary = validate_mission_template(template, force_refresh)
		results.template_results[template.template_id] = result
		results.total_templates += 1
		if result.is_valid:
			results.valid_templates += 1
		else:
			results.invalid_templates += 1
		results.total_errors += result.error_count
		results.total_warnings += result.warning_count
	
	# Validate SEXP patterns
	var sexp_patterns: Array[SexpPattern] = template_manager.get_all_sexp_patterns()
	for pattern in sexp_patterns:
		var result: Dictionary = validate_sexp_pattern(pattern, force_refresh)
		results.template_results["sexp_" + pattern.pattern_id] = result
		results.total_templates += 1
		if result.is_valid:
			results.valid_templates += 1
		else:
			results.invalid_templates += 1
		results.total_errors += result.error_count
		results.total_warnings += result.warning_count
	
	# Validate asset patterns
	var asset_patterns: Array[AssetPattern] = template_manager.get_all_asset_patterns()
	for pattern in asset_patterns:
		var result: Dictionary = validate_asset_pattern(pattern, force_refresh)
		results.template_results["asset_" + pattern.pattern_id] = result
		results.total_templates += 1
		if result.is_valid:
			results.valid_templates += 1
		else:
			results.invalid_templates += 1
		results.total_errors += result.error_count
		results.total_warnings += result.warning_count
	
	print("Batch validation complete: %d/%d templates valid" % [results.valid_templates, results.total_templates])
	
	batch_validation_completed.emit(results)
	return results

## Clears validation cache
func clear_validation_cache() -> void:
	validation_cache.clear()
	cache_timestamps.clear()
	print("Validation cache cleared")

## Gets validation statistics
func get_validation_statistics() -> Dictionary:
	return {
		"cache_entries": validation_cache.size(),
		"cache_hits": 0, # Would need to track this separately
		"last_batch_validation": "never" # Would need to store this
	}