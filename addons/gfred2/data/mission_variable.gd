@tool
class_name MissionVariable
extends Resource

## Mission variable data structure for GFRED2-010 Mission Component Editors.
## Defines mission variables with type safety and SEXP integration.

signal variable_changed(property_name: String, old_value: Variant, new_value: Variant)
signal usage_updated(new_usage_count: int)

# Basic variable properties
@export var variable_id: String = ""
@export var variable_name: String = ""
@export var variable_type: String = "number"  # number, string, boolean, time, block
@export var default_value: String = "0"
@export var description: String = ""

# Type-specific properties
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step_value: float = 1.0
@export var max_length: int = 100
@export var string_validation: String = "None"

# Usage tracking
@export var track_usage: bool = true
@export var usage_count: int = 0
@export var usage_locations: Array[String] = []

# SEXP integration
@export var sexp_accessible: bool = true
@export var persistent: bool = false
@export var campaign_variable: bool = false

func _init() -> void:
	# Initialize with default values
	variable_id = "variable_" + str(randi() % 10000)
	variable_name = "NewVariable"
	variable_type = "number"
	default_value = "0"
	min_value = 0.0
	max_value = 100.0
	step_value = 1.0
	max_length = 100
	string_validation = "None"
	track_usage = true
	sexp_accessible = true

func _set(property: StringName, value: Variant) -> bool:
	var old_value: Variant = get(property)
	var result: bool = false
	
	match property:
		"variable_id":
			variable_id = value as String
			result = true
		"variable_name":
			variable_name = value as String
			result = true
		"variable_type":
			variable_type = value as String
			result = true
		"default_value":
			default_value = value as String
			result = true
		"description":
			description = value as String
			result = true
		"min_value":
			min_value = value as float
			result = true
		"max_value":
			max_value = value as float
			result = true
		"step_value":
			step_value = max(0.01, value as float)
			result = true
		"max_length":
			max_length = max(1, value as int)
			result = true
		"string_validation":
			string_validation = value as String
			result = true
		"track_usage":
			track_usage = value as bool
			result = true
		"usage_count":
			usage_count = max(0, value as int)
			result = true
		"usage_locations":
			usage_locations = value as Array[String]
			result = true
		"sexp_accessible":
			sexp_accessible = value as bool
			result = true
		"persistent":
			persistent = value as bool
			result = true
		"campaign_variable":
			campaign_variable = value as bool
			result = true
	
	if result:
		variable_changed.emit(property, old_value, value)
	
	return result

## Validates the mission variable
func validate() -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# Validate basic properties
	if variable_id.is_empty():
		result.add_error("Variable ID cannot be empty")
	
	if variable_name.is_empty():
		result.add_error("Variable name cannot be empty")
	
	if not variable_type in ["number", "string", "boolean", "time", "block"]:
		result.add_error("Invalid variable type: %s" % variable_type)
	
	# Validate default value based on type
	match variable_type:
		"number":
			if not _is_valid_number(default_value):
				result.add_error("Default value is not a valid number")
			else:
				var num_value: float = default_value.to_float()
				if num_value < min_value or num_value > max_value:
					result.add_error("Default value is outside valid range [%s, %s]" % [min_value, max_value])
		
		"time":
			if not _is_valid_number(default_value):
				result.add_error("Default time value is not a valid number")
			else:
				var time_value: float = default_value.to_float()
				if time_value < 0.0:
					result.add_error("Time value cannot be negative")
		
		"boolean":
			if not default_value.to_lower() in ["true", "false", "0", "1"]:
				result.add_error("Default value must be 'true', 'false', '0', or '1' for boolean variables")
		
		"string":
			if default_value.length() > max_length:
				result.add_error("Default string value exceeds maximum length (%d)" % max_length)
	
	# Validate type-specific constraints
	if variable_type in ["number", "time"]:
		if min_value > max_value:
			result.add_error("Minimum value cannot be greater than maximum value")
		
		if step_value <= 0.0:
			result.add_error("Step value must be greater than 0")
	
	if variable_type == "string":
		if max_length <= 0:
			result.add_error("String maximum length must be greater than 0")
	
	# Validate usage tracking
	if usage_count < 0:
		result.add_error("Usage count cannot be negative")
	
	return result

func _is_valid_number(value: String) -> bool:
	if value.is_empty():
		return false
	
	# Check if string represents a valid number
	var regex: RegEx = RegEx.new()
	regex.compile("^-?\\d*\\.?\\d+$")
	return regex.search(value) != null

## Gets the typed default value
func get_typed_default_value() -> Variant:
	match variable_type:
		"number", "time":
			return default_value.to_float()
		"boolean":
			return default_value.to_lower() in ["true", "1"]
		"string":
			return default_value
		"block":
			return default_value.to_lower() in ["true", "1"]
		_:
			return default_value

## Sets the default value with type checking
func set_typed_default_value(value: Variant) -> bool:
	match variable_type:
		"number", "time":
			if value is float or value is int:
				default_value = str(value)
				return true
		"boolean", "block":
			if value is bool:
				default_value = "true" if value else "false"
				return true
		"string":
			if value is String:
				default_value = value as String
				return true
	
	return false

## Validates a value against this variable's constraints
func validate_value(value: Variant) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	match variable_type:
		"number", "time":
			if not (value is float or value is int):
				result.add_error("Value must be a number")
			else:
				var num_value: float = value as float
				if num_value < min_value or num_value > max_value:
					result.add_error("Value %s is outside valid range [%s, %s]" % [num_value, min_value, max_value])
		
		"boolean", "block":
			if not value is bool:
				result.add_error("Value must be a boolean")
		
		"string":
			if not value is String:
				result.add_error("Value must be a string")
			else:
				var str_value: String = value as String
				if str_value.length() > max_length:
					result.add_error("String length %d exceeds maximum length %d" % [str_value.length(), max_length])
	
	return result

## Updates usage tracking
func add_usage_location(location: String) -> void:
	if not location in usage_locations:
		usage_locations.append(location)
		usage_count = usage_locations.size()
		usage_updated.emit(usage_count)

func remove_usage_location(location: String) -> void:
	var index: int = usage_locations.find(location)
	if index >= 0:
		usage_locations.remove_at(index)
		usage_count = usage_locations.size()
		usage_updated.emit(usage_count)

func clear_usage_tracking() -> void:
	usage_locations.clear()
	usage_count = 0
	usage_updated.emit(usage_count)

## Exports to WCS mission format
func export_to_wcs() -> Dictionary:
	return {
		"name": variable_name,
		"id": variable_id,
		"type": variable_type,
		"default_value": default_value,
		"description": description,
		"min_value": min_value,
		"max_value": max_value,
		"step_value": step_value,
		"max_length": max_length,
		"string_validation": string_validation,
		"persistent": persistent,
		"campaign_variable": campaign_variable,
		"sexp_accessible": sexp_accessible
	}

## Gets a display string for UI representation
func get_display_string() -> String:
	var type_info: String = variable_type.capitalize()
	if variable_type in ["number", "time"] and min_value != max_value:
		type_info += " [%s-%s]" % [min_value, max_value]
	elif variable_type == "string" and max_length != 100:
		type_info += " (max %d)" % max_length
	
	return "%s (%s) = %s" % [variable_name, type_info, default_value]

## Gets variable summary for tooltips/info
func get_summary() -> Dictionary:
	return {
		"name": variable_name,
		"id": variable_id,
		"type": variable_type,
		"default_value": default_value,
		"usage_count": usage_count,
		"persistent": persistent,
		"campaign_variable": campaign_variable,
		"sexp_accessible": sexp_accessible,
		"description": description
	}

## Duplicates the mission variable
func duplicate(deep: bool = true) -> MissionVariable:
	var copy: MissionVariable = MissionVariable.new()
	
	copy.variable_id = variable_id + "_copy"
	copy.variable_name = variable_name + "_Copy"
	copy.variable_type = variable_type
	copy.default_value = default_value
	copy.description = description
	copy.min_value = min_value
	copy.max_value = max_value
	copy.step_value = step_value
	copy.max_length = max_length
	copy.string_validation = string_validation
	copy.track_usage = track_usage
	copy.sexp_accessible = sexp_accessible
	copy.persistent = persistent
	copy.campaign_variable = campaign_variable
	
	# Deep copy usage tracking
	if deep:
		copy.usage_locations = usage_locations.duplicate()
		copy.usage_count = usage_count
	else:
		copy.usage_count = 0
		copy.usage_locations = []
	
	return copy

## Gets SEXP representation for this variable
func get_sexp_reference() -> String:
	return variable_name

## Checks if variable can be used in SEXP expressions
func is_sexp_compatible() -> bool:
	return sexp_accessible and not variable_name.is_empty()

## Gets the variable's type for SEXP type checking
func get_sexp_type() -> String:
	match variable_type:
		"number", "time":
			return "number"
		"boolean", "block":
			return "boolean"
		"string":
			return "string"
		_:
			return "unknown"