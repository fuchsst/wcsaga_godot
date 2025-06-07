class_name ObjectValidator
extends Node

## Validator for mission object properties in the FRED2 editor plugin.
## Provides real-time validation and error reporting.
## Uses addons/wcs_core_asstes core foundation validation patterns for consistency.

signal validation_error(object_data: MissionObject, property: String, error: String)
signal validation_passed(object_data: MissionObject, property: String)

var object_manager: MissionObjectManager

func _ready() -> void:
	name = "ObjectValidator"

func validate_object(object_data: MissionObject) -> ValidationResult:
	"""Validate an entire object and return result using core validation patterns."""
	var result: ValidationResult = ValidationResult.new("", "")
	
	if not object_data:
		result.add_error("Object data is null")
		return result
	
	# Validate basic properties
	_validate_object_id(object_data, result)
	_validate_object_name(object_data, result)
	_validate_position(object_data, result)
	_validate_rotation(object_data, result)
	
	# Validate type-specific properties
	match object_data.type:
		MissionObject.Type.SHIP:
			_validate_ship_properties(object_data, result)
		MissionObject.Type.CARGO:
			_validate_cargo_properties(object_data, result)
		MissionObject.Type.WAYPOINT:
			_validate_waypoint_properties(object_data, result)
	
	return result

func validate_object_property(object_data: MissionObject, property: String) -> ValidationResult:
	"""Validate a specific property of an object using core validation patterns."""
	var result: ValidationResult = ValidationResult.new("", "")
	
	if not object_data:
		result.add_error("Object data is null")
		return result
	
	match property:
		"id":
			if not _is_valid_object_id(object_data.id):
				result.add_error("Invalid object ID format")
		"name":
			if not _is_valid_object_name(object_data.name):
				result.add_error("Object name cannot be empty")
		"position":
			if not _is_valid_position(object_data.position):
				result.add_error("Invalid position values")
		"rotation":
			if not _is_valid_rotation(object_data.rotation):
				result.add_error("Invalid rotation values")
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

func validate_property_change(object_data: MissionObject, property: String, new_value: Variant) -> bool:
	"""Validate a property change before it's applied."""
	if not object_data:
		return false
	
	# Create temporary copy to test validation
	var temp_object: MissionObject = object_data.duplicate()
	temp_object.set(property, new_value)
	
	var validation_result: ValidationResult = validate_object_property(temp_object, property)
	return validation_result.is_valid()

func _validate_object_id(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate object ID."""
	if not _is_valid_object_id(object_data.id):
		result.add_error("Invalid object ID: " + object_data.id)

func _validate_object_name(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate object name."""
	if not _is_valid_object_name(object_data.name):
		result.add_error("Object name cannot be empty")

func _validate_position(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate position."""
	if not _is_valid_position(object_data.position):
		result.add_error("Invalid position values")

func _validate_rotation(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate rotation."""
	if not _is_valid_rotation(object_data.rotation):
		result.add_error("Invalid rotation values")

# _validate_scale method removed - scale property not used in MissionObject

func _validate_ship_properties(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate ship-specific properties."""
	if object_data.team < 0:
		result.add_error("Ship must have a valid team assignment")
	
	if object_data.primary_banks.is_empty() and object_data.secondary_banks.is_empty():
		result.add_warning("Ship has no weapons configured")

func _validate_weapon_properties(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate weapon-specific properties."""
	# Weapons are handled as part of ship validation
	pass

func _validate_cargo_properties(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate cargo-specific properties."""
	# Basic cargo validation
	pass

func _validate_waypoint_properties(object_data: MissionObject, result: ValidationResult) -> void:
	"""Validate waypoint-specific properties."""
	# Waypoint validation focuses on position
	pass

func _validate_custom_property(object_data: MissionObject, property: String) -> ValidationResult:
	"""Validate custom properties based on object type."""
	var result: ValidationResult = ValidationResult.new("", "")
	
	# For now, just return valid result since MissionObject doesn't have a properties dict
	# This method can be extended when custom properties are needed
	return result

# Custom property validation methods removed - not needed for current MissionObject structure

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

# _is_valid_scale method removed - scale property not used in MissionObject