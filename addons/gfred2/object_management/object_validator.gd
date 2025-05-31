class_name ObjectValidator
extends Node

## Validator for mission object properties in the FRED2 editor plugin.
## Provides real-time validation and error reporting.
## Uses addons/wcs_core_asstes core foundation validation patterns for consistency.

signal validation_error(object_data: MissionObjectData, property: String, error: String)
signal validation_passed(object_data: MissionObjectData, property: String)

var object_manager: MissionObjectManager

func _ready() -> void:
	name = "ObjectValidator"

func validate_object(object_data: MissionObjectData) -> ValidationResult:
	"""Validate an entire object and return result using core validation patterns."""
	var result: ValidationResult = ValidationResult.new("mission_object", "MissionObjectData")
	
	if not object_data:
		result.add_error("Object data is null")
		return result
	
	# Validate basic properties
	_validate_object_id(object_data, result)
	_validate_object_name(object_data, result)
	_validate_position(object_data, result)
	_validate_rotation(object_data, result)
	_validate_scale(object_data, result)
	
	# Validate type-specific properties
	match object_data.object_type:
		MissionObjectData.ObjectType.SHIP:
			_validate_ship_properties(object_data, result)
		MissionObjectData.ObjectType.WEAPON:
			_validate_weapon_properties(object_data, result)
		MissionObjectData.ObjectType.CARGO:
			_validate_cargo_properties(object_data, result)
		MissionObjectData.ObjectType.WAYPOINT:
			_validate_waypoint_properties(object_data, result)
	
	return result

func validate_object_property(object_data: MissionObjectData, property: String) -> ValidationResult:
	"""Validate a specific property of an object using core validation patterns."""
	var result: ValidationResult = ValidationResult.new("mission_object_property", property)
	
	if not object_data:
		result.add_error("Object data is null")
		return result
	
	match property:
		"object_id":
			if not _is_valid_object_id(object_data.object_id):
				result.add_error("Invalid object ID format")
		"object_name":
			if not _is_valid_object_name(object_data.object_name):
				result.add_error("Object name cannot be empty")
		"position":
			if not _is_valid_position(object_data.position):
				result.add_error("Invalid position values")
		"rotation":
			if not _is_valid_rotation(object_data.rotation):
				result.add_error("Invalid rotation values")
		"scale":
			if not _is_valid_scale(object_data.scale):
				result.add_error("Scale values must be positive")
		_:
			# Custom property validation
			var custom_result: ValidationResult = _validate_custom_property(object_data, property)
			if not custom_result.is_valid():
				for error in custom_result.get_errors():
					result.add_error(error)
	
	# Emit signals
	if result.is_valid():
		validation_passed.emit(object_data, property)
	else:
		var errors: Array[String] = result.get_errors()
		if not errors.is_empty():
			validation_error.emit(object_data, property, errors[0])
	
	return result

func validate_property_change(object_data: MissionObjectData, property: String, new_value: Variant) -> bool:
	"""Validate a property change before it's applied."""
	if not object_data:
		return false
	
	# Create temporary copy to test validation
	var temp_object: MissionObjectData = object_data.duplicate_data()
	temp_object.set(property, new_value)
	
	var validation_result: ValidationResult = validate_object_property(temp_object, property)
	return validation_result.is_valid()

func _validate_object_id(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate object ID."""
	if not _is_valid_object_id(object_data.object_id):
		result.add_error("Invalid object ID: " + object_data.object_id)

func _validate_object_name(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate object name."""
	if not _is_valid_object_name(object_data.object_name):
		result.add_error("Object name cannot be empty")

func _validate_position(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate position."""
	if not _is_valid_position(object_data.position):
		result.add_error("Invalid position values")

func _validate_rotation(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate rotation."""
	if not _is_valid_rotation(object_data.rotation):
		result.add_error("Invalid rotation values")

func _validate_scale(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate scale."""
	if not _is_valid_scale(object_data.scale):
		result.add_error("Scale values must be positive")

func _validate_ship_properties(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate ship-specific properties."""
	var ship_class: String = object_data.properties.get("ship_class", "")
	if ship_class.is_empty():
		result.add_warning("Ship class not specified")

func _validate_weapon_properties(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate weapon-specific properties."""
	var weapon_type: String = object_data.properties.get("weapon_type", "")
	if weapon_type.is_empty():
		result.add_warning("Weapon type not specified")

func _validate_cargo_properties(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate cargo-specific properties."""
	var cargo_type: String = object_data.properties.get("cargo_type", "")
	if cargo_type.is_empty():
		result.add_warning("Cargo type not specified")

func _validate_waypoint_properties(object_data: MissionObjectData, result: ValidationResult) -> void:
	"""Validate waypoint-specific properties."""
	var waypoint_path: String = object_data.properties.get("waypoint_path", "")
	if waypoint_path.is_empty():
		result.add_warning("Waypoint path not specified")

func _validate_custom_property(object_data: MissionObjectData, property: String) -> ValidationResult:
	"""Validate custom properties based on object type."""
	var result: ValidationResult = ValidationResult.new("custom_property", property)
	
	var property_value: Variant = object_data.properties.get(property, null)
	
	# Type-specific validation
	match object_data.object_type:
		MissionObjectData.ObjectType.SHIP:
			result = _validate_ship_custom_property(property, property_value)
		MissionObjectData.ObjectType.WEAPON:
			result = _validate_weapon_custom_property(property, property_value)
		MissionObjectData.ObjectType.CARGO:
			result = _validate_cargo_custom_property(property, property_value)
		MissionObjectData.ObjectType.WAYPOINT:
			result = _validate_waypoint_custom_property(property, property_value)
	
	return result

func _validate_ship_custom_property(property: String, value: Variant) -> Dictionary:
	"""Validate ship custom properties."""
	var result: Dictionary = {"is_valid": true, "error_message": ""}
	
	match property:
		"ship_class":
			if not value is String or (value as String).is_empty():
				result.is_valid = false
				result.error_message = "Ship class must be a non-empty string"
		"ai_goals":
			if not value is String:
				result.is_valid = false
				result.error_message = "AI goals must be a string"
	
	return result

func _validate_weapon_custom_property(property: String, value: Variant) -> Dictionary:
	"""Validate weapon custom properties."""
	var result: Dictionary = {"is_valid": true, "error_message": ""}
	
	match property:
		"weapon_type":
			if not value is String or (value as String).is_empty():
				result.is_valid = false
				result.error_message = "Weapon type must be a non-empty string"
		"lifeleft":
			if not value is float or (value as float) < 0:
				result.is_valid = false
				result.error_message = "Life left must be a positive number"
	
	return result

func _validate_cargo_custom_property(property: String, value: Variant) -> Dictionary:
	"""Validate cargo custom properties."""
	var result: Dictionary = {"is_valid": true, "error_message": ""}
	
	match property:
		"cargo_type":
			if not value is String or (value as String).is_empty():
				result.is_valid = false
				result.error_message = "Cargo type must be a non-empty string"
		"mass":
			if not value is float or (value as float) <= 0:
				result.is_valid = false
				result.error_message = "Mass must be a positive number"
	
	return result

func _validate_waypoint_custom_property(property: String, value: Variant) -> Dictionary:
	"""Validate waypoint custom properties."""
	var result: Dictionary = {"is_valid": true, "error_message": ""}
	
	match property:
		"waypoint_path":
			if not value is String or (value as String).is_empty():
				result.is_valid = false
				result.error_message = "Waypoint path must be a non-empty string"
		"speed":
			if not value is float or (value as float) < 0:
				result.is_valid = false
				result.error_message = "Speed must be a positive number"
	
	return result

func _is_valid_object_id(id: String) -> bool:
	"""Check if object ID is valid."""
	return not id.is_empty() and id.length() > 0

func _is_valid_object_name(name: String) -> bool:
	"""Check if object name is valid."""
	return not name.is_empty()

func _is_valid_position(pos: Vector3) -> bool:
	"""Check if position is valid."""
	return not (is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z) or 
	           is_inf(pos.x) or is_inf(pos.y) or is_inf(pos.z))

func _is_valid_rotation(rot: Vector3) -> bool:
	"""Check if rotation is valid."""
	return not (is_nan(rot.x) or is_nan(rot.y) or is_nan(rot.z) or 
	           is_inf(rot.x) or is_inf(rot.y) or is_inf(rot.z))

func _is_valid_scale(scale: Vector3) -> bool:
	"""Check if scale is valid."""
	return (scale.x > 0 and scale.y > 0 and scale.z > 0 and 
	        not (is_nan(scale.x) or is_nan(scale.y) or is_nan(scale.z) or 
	             is_inf(scale.x) or is_inf(scale.y) or is_inf(scale.z)))