extends Node

## Asset Validation Manager for WCS Asset Core addon.
## Singleton autoload that provides comprehensive asset validation with error detection,
## warnings, and fixing suggestions for all asset types in the WCS conversion.

signal validation_started(asset_path: String)
signal validation_completed(asset_path: String, result: ValidationResult)
signal batch_validation_started(asset_count: int)
signal batch_validation_completed(results: Array[ValidationResult])

# Validation rules registry
var _validators: Dictionary = {}  # AssetTypes.Type -> AssetValidator
var _global_validators: Array[AssetValidator] = []  # Apply to all assets

# Configuration
@export var enable_performance_validation: bool = true
@export var enable_dependency_validation: bool = true
@export var max_validation_errors: int = 50
@export var validation_timeout_ms: int = 5000
@export var debug_logging: bool = false

# Performance tracking
var _validations_performed: int = 0
var _validation_errors_found: int = 0
var _validation_warnings_found: int = 0
var _average_validation_time_ms: float = 0.0

## Base validator interface
class AssetValidator:
	extends RefCounted
	
	var validator_name: String
	var validator_description: String
	var asset_types: Array[AssetTypes.Type] = []  # Empty = all types
	
	func _init(name: String, description: String = "") -> void:
		validator_name = name
		validator_description = description
	
	func can_validate(asset_type: AssetTypes.Type) -> bool:
		return asset_types.is_empty() or asset_types.has(asset_type)
	
	func validate(asset: BaseAssetData, result: ValidationResult) -> void:
		# Override in subclasses
		pass

func _ready() -> void:
	"""Initialize the validation manager singleton."""
	
	if debug_logging:
		print("WCSAssetValidator: Initializing validation manager")
	
	# Set up default validators
	_setup_default_validators()
	
	if debug_logging:
		print("WCSAssetValidator: Validation system ready with %d validators" % (_validators.size() + _global_validators.size()))

## Public API - Validation

func validate_asset(asset: BaseAssetData) -> ValidationResult:
	"""Validate a single asset.
	Args:
		asset: Asset to validate
	Returns:
		Validation result with errors, warnings, and suggestions"""
	
	if asset == null:
		var result: ValidationResult = ValidationResult.new()
		result.add_error("Asset is null")
		return result
	
	var start_time: int = Time.get_ticks_msec()
	
	validation_started.emit(asset.file_path)
	
	if debug_logging:
		print("WCSAssetValidator: Validating asset %s" % asset.file_path)
	
	# Create validation result
	var result: ValidationResult = ValidationResult.new(asset.file_path, asset.get_asset_type())
	
	# Run global validators first
	for validator in _global_validators:
		if validator.can_validate(asset.get_asset_type()):
			validator.validate(asset, result)
			
			# Check for error limit
			if result.errors.size() >= max_validation_errors:
				result.add_warning("Validation stopped - too many errors")
				break
	
	# Run type-specific validators
	var asset_type: AssetTypes.Type = asset.get_asset_type()
	if _validators.has(asset_type):
		var validator: AssetValidator = _validators[asset_type]
		validator.validate(asset, result)
	
	# Run built-in asset validation
	var asset_errors: Array[String] = asset.get_validation_errors()
	for error in asset_errors:
		result.add_error(error)
	
	# Performance validation
	if enable_performance_validation:
		_validate_performance(asset, result)
	
	# Dependency validation
	if enable_dependency_validation:
		_validate_dependencies(asset, result)
	
	# Record timing and statistics
	result.validation_time_ms = Time.get_ticks_msec() - start_time
	_update_validation_stats(result)
	
	validation_completed.emit(asset.file_path, result)
	
	if debug_logging:
		print("WCSAssetValidator: Validation completed for %s - %d errors, %d warnings" % 
			[asset.file_path, result.errors.size(), result.warnings.size()])
	
	return result

func validate_asset_group(assets: Array[BaseAssetData]) -> Array[ValidationResult]:
	"""Validate multiple assets in batch.
	Args:
		assets: Array of assets to validate
	Returns:
		Array of validation results"""
	
	batch_validation_started.emit(assets.size())
	
	var results: Array[ValidationResult] = []
	
	for asset in assets:
		if asset != null:
			var result: ValidationResult = validate_asset(asset)
			results.append(result)
	
	batch_validation_completed.emit(results)
	
	return results

func validate_by_path(asset_path: String) -> ValidationResult:
	"""Validate an asset by file path.
	Args:
		asset_path: Path to asset file
	Returns:
		Validation result"""
	
	# Try to load the asset
	var asset: BaseAssetData = load(asset_path) as BaseAssetData
	
	if asset == null:
		var result: ValidationResult = ValidationResult.new(asset_path)
		result.add_error("Failed to load asset or asset is not BaseAssetData type")
		return result
	
	return validate_asset(asset)

## Public API - Validator Management

func register_validator(asset_type: AssetTypes.Type, validator: AssetValidator) -> void:
	"""Register a validator for a specific asset type.
	Args:
		asset_type: Asset type to validate
		validator: Validator instance"""
	
	_validators[asset_type] = validator
	
	if debug_logging:
		print("WCSAssetValidator: Registered validator '%s' for type %s" % 
			[validator.validator_name, AssetTypes.get_type_name(asset_type)])

func register_global_validator(validator: AssetValidator) -> void:
	"""Register a validator that applies to all asset types.
	Args:
		validator: Validator instance"""
	
	_global_validators.append(validator)
	
	if debug_logging:
		print("WCSAssetValidator: Registered global validator '%s'" % validator.validator_name)

func unregister_validator(asset_type: AssetTypes.Type) -> bool:
	"""Remove validator for an asset type.
	Args:
		asset_type: Asset type to remove validator for
	Returns:
		true if validator was removed"""
	
	if _validators.has(asset_type):
		_validators.erase(asset_type)
		return true
	
	return false

func get_validator(asset_type: AssetTypes.Type) -> AssetValidator:
	"""Get validator for an asset type.
	Args:
		asset_type: Asset type to get validator for
	Returns:
		Validator instance or null if not found"""
	
	return _validators.get(asset_type, null)

func get_all_validators() -> Array[AssetValidator]:
	"""Get all registered validators.
	Returns:
		Array of all validator instances"""
	
	var all_validators: Array[AssetValidator] = _global_validators.duplicate()
	
	for validator in _validators.values():
		all_validators.append(validator)
	
	return all_validators

## Validation Statistics

func get_validation_stats() -> Dictionary:
	"""Get validation performance statistics.
	Returns:
		Dictionary with validation statistics"""
	
	return {
		"validations_performed": _validations_performed,
		"validation_errors_found": _validation_errors_found,
		"validation_warnings_found": _validation_warnings_found,
		"average_validation_time_ms": _average_validation_time_ms,
		"registered_validators": _validators.size(),
		"global_validators": _global_validators.size()
	}

func clear_validation_stats() -> void:
	"""Clear validation statistics."""
	
	_validations_performed = 0
	_validation_errors_found = 0
	_validation_warnings_found = 0
	_average_validation_time_ms = 0.0

## Internal Implementation

func _setup_default_validators() -> void:
	"""Set up built-in validators for different asset types."""
	
	# Ship validator
	var ship_validator: AssetValidator = _create_ship_validator()
	register_validator(AssetTypes.Type.SHIP, ship_validator)
	
	# Weapon validator
	var weapon_validator: AssetValidator = _create_weapon_validator()
	register_validator(AssetTypes.Type.WEAPON, weapon_validator)
	
	# Armor validator
	var armor_validator: AssetValidator = _create_armor_validator()
	register_validator(AssetTypes.Type.ARMOR, armor_validator)
	
	# Global validators
	var path_validator: AssetValidator = _create_path_validator()
	register_global_validator(path_validator)
	
	var metadata_validator: AssetValidator = _create_metadata_validator()
	register_global_validator(metadata_validator)

func _create_ship_validator() -> AssetValidator:
	"""Create ship-specific validator.
	Returns:
		Ship validator instance"""
	
	var validator: AssetValidator = AssetValidator.new("Ship Validator", "Validates ship-specific properties")
	validator.asset_types = [AssetTypes.Type.SHIP]
	
	# Override validate method using a callable
	validator.validate = func(asset: BaseAssetData, result: ValidationResult) -> void:
		if not asset is ShipData:
			return
		
		var ship: ShipData = asset as ShipData
		
		# Ship-specific validation
		if ship.mass <= 0.0:
			result.add_error("Ship mass must be positive")
		
		if ship.max_hull_strength <= 0.0:
			result.add_error("Ship hull strength must be positive")
		
		if ship.max_vel.length() <= 0.0:
			result.add_error("Ship must have positive velocity")
		
		# Weapon bank validation
		if ship.num_primary_banks < 0 or ship.num_primary_banks > 10:
			result.add_warning("Unusual number of primary weapon banks: %d" % ship.num_primary_banks)
		
		if ship.num_secondary_banks < 0 or ship.num_secondary_banks > 10:
			result.add_warning("Unusual number of secondary weapon banks: %d" % ship.num_secondary_banks)
		
		# Performance checks
		if ship.get_max_speed() > 500.0:
			result.add_suggestion("Very high maximum speed - consider balance implications")
		
		if ship.get_combat_rating() > 10000.0:
			result.add_suggestion("Very high combat rating - may be overpowered")
	
	return validator

func _create_weapon_validator() -> AssetValidator:
	"""Create weapon-specific validator.
	Returns:
		Weapon validator instance"""
	
	var validator: AssetValidator = AssetValidator.new("Weapon Validator", "Validates weapon-specific properties")
	validator.asset_types = [AssetTypes.Type.WEAPON, AssetTypes.Type.PRIMARY_WEAPON, AssetTypes.Type.SECONDARY_WEAPON]
	
	validator.validate = func(asset: BaseAssetData, result: ValidationResult) -> void:
		if not asset is WeaponData:
			return
		
		var weapon: WeaponData = asset as WeaponData
		
		# Weapon-specific validation
		if weapon.damage < 0.0:
			result.add_error("Weapon damage cannot be negative")
		
		if weapon.max_speed <= 0.0:
			result.add_error("Weapon projectile speed must be positive")
		
		if weapon.lifetime <= 0.0:
			result.add_error("Weapon lifetime must be positive")
		
		if weapon.fire_wait < 0.0:
			result.add_error("Weapon fire wait cannot be negative")
		
		# Range validation
		if weapon.weapon_range <= 0.0:
			result.add_warning("Weapon has no effective range")
		
		if weapon.get_range_effectiveness() != weapon.weapon_range:
			var calculated_range: float = weapon.get_range_effectiveness()
			if abs(calculated_range - weapon.weapon_range) > weapon.weapon_range * 0.1:
				result.add_suggestion("Range mismatch - calculated: %.1f, specified: %.1f" % [calculated_range, weapon.weapon_range])
		
		# Balance checks
		var dps: float = weapon.get_dps()
		if dps > 1000.0:
			result.add_suggestion("Very high DPS (%.1f) - consider balance implications" % dps)
		
		if weapon.is_homing_weapon() and weapon.get_tracking_ability() > 0.95:
			result.add_suggestion("Extremely high tracking ability - may be too powerful")
	
	return validator

func _create_armor_validator() -> AssetValidator:
	"""Create armor-specific validator.
	Returns:
		Armor validator instance"""
	
	var validator: AssetValidator = AssetValidator.new("Armor Validator", "Validates armor-specific properties")
	validator.asset_types = [AssetTypes.Type.ARMOR, AssetTypes.Type.SHIELD_ARMOR, AssetTypes.Type.HULL_ARMOR]
	
	validator.validate = func(asset: BaseAssetData, result: ValidationResult) -> void:
		if not asset is ArmorData:
			return
		
		var armor: ArmorData = asset as ArmorData
		
		# Armor-specific validation
		if armor.base_damage_modifier < 0.0:
			result.add_error("Base damage modifier cannot be negative")
		
		if armor.armor_thickness <= 0.0:
			result.add_error("Armor thickness must be positive")
		
		# Resistance validation
		for damage_type in armor.damage_resistances.keys():
			var resistance: float = armor.damage_resistances[damage_type]
			if resistance < 0.0:
				result.add_error("Negative resistance for damage type %s" % damage_type)
		
		# Balance checks
		var summary: Dictionary = armor.get_resistance_summary()
		if summary["immunities"].size() > 3:
			result.add_suggestion("Many damage immunities (%d) - may be overpowered" % summary["immunities"].size())
		
		if summary["average_resistance"] < 0.1:
			result.add_suggestion("Very low average resistance - armor may be too weak")
	
	return validator

func _create_path_validator() -> AssetValidator:
	"""Create path and file validator.
	Returns:
		Path validator instance"""
	
	var validator: AssetValidator = AssetValidator.new("Path Validator", "Validates asset paths and file references")
	
	validator.validate = func(asset: BaseAssetData, result: ValidationResult) -> void:
		# File path validation
		if asset.file_path.is_empty():
			result.add_warning("Asset file path is not set")
		elif not FileAccess.file_exists(asset.file_path):
			result.add_error("Asset file does not exist: %s" % asset.file_path)
		
		# Validate resource references for ships
		if asset is ShipData:
			var ship: ShipData = asset as ShipData
			
			# Check weapon references
			for weapon_path in ship.primary_bank_weapons:
				if not weapon_path.is_empty() and not FileAccess.file_exists(weapon_path):
					result.add_error("Primary weapon file not found: %s" % weapon_path)
			
			for weapon_path in ship.secondary_bank_weapons:
				if not weapon_path.is_empty() and not FileAccess.file_exists(weapon_path):
					result.add_error("Secondary weapon file not found: %s" % weapon_path)
	
	return validator

func _create_metadata_validator() -> AssetValidator:
	"""Create metadata validator.
	Returns:
		Metadata validator instance"""
	
	var validator: AssetValidator = AssetValidator.new("Metadata Validator", "Validates asset metadata and tags")
	
	validator.validate = func(asset: BaseAssetData, result: ValidationResult) -> void:
		# Required fields validation
		if asset.asset_name.is_empty():
			result.add_warning("Asset name is empty")
		
		if asset.asset_id.is_empty():
			result.add_warning("Asset ID is empty")
		
		if asset.description.is_empty():
			result.add_suggestion("Consider adding a description for better documentation")
		
		# Version validation
		if asset.asset_version.is_empty():
			result.add_suggestion("Consider setting an asset version")
		
		# Category validation
		if asset.category.is_empty():
			result.add_suggestion("Consider setting a category for better organization")
		
		# Tag validation
		if asset.get_tags().is_empty():
			result.add_suggestion("Consider adding tags for better searchability")
	
	return validator

func _validate_performance(asset: BaseAssetData, result: ValidationResult) -> void:
	"""Validate asset performance characteristics.
	Args:
		asset: Asset to validate
		result: Validation result to update"""
	
	# Memory usage check
	var memory_size: int = asset.get_memory_size()
	if memory_size > 1024 * 1024:  # 1MB
		result.add_warning("Large asset size: %.1f MB" % (memory_size / (1024.0 * 1024.0)))
	elif memory_size > 10 * 1024 * 1024:  # 10MB
		result.add_error("Extremely large asset size: %.1f MB" % (memory_size / (1024.0 * 1024.0)))
	
	# Complexity checks for specific asset types
	if asset is ShipData:
		var ship: ShipData = asset as ShipData
		if ship.get_total_weapon_banks() > 20:
			result.add_warning("Ship has many weapon banks (%d) - may impact performance" % ship.get_total_weapon_banks())
	
	# Validation metadata
	result.metadata["memory_size_bytes"] = memory_size

func _validate_dependencies(asset: BaseAssetData, result: ValidationResult) -> void:
	"""Validate asset dependencies and references.
	Args:
		asset: Asset to validate
		result: Validation result to update"""
	
	# This would check for circular dependencies, missing references, etc.
	# For now, basic implementation
	
	if asset is ShipData:
		var ship: ShipData = asset as ShipData
		
		# Check for weapon references
		var total_weapons: int = ship.primary_bank_weapons.size() + ship.secondary_bank_weapons.size()
		if total_weapons == 0:
			result.add_suggestion("Ship has no weapons configured")
		
		# Check countermeasure references
		if ship.has_countermeasures() and ship.cmeasure_type.is_empty():
			result.add_warning("Ship configured for countermeasures but no countermeasure type specified")

func _update_validation_stats(result: ValidationResult) -> void:
	"""Update validation statistics.
	Args:
		result: Validation result to record"""
	
	_validations_performed += 1
	_validation_errors_found += result.errors.size()
	_validation_warnings_found += result.warnings.size()
	
	# Update average validation time
	var total_time: float = _average_validation_time_ms * (_validations_performed - 1) + result.validation_time_ms
	_average_validation_time_ms = total_time / _validations_performed

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the validation manager is removed."""
	
	if debug_logging:
		print("WCSAssetValidator: Shutting down")
	
	_validators.clear()
	_global_validators.clear()
