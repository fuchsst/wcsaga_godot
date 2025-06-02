class_name VariableValidator
extends RefCounted

## Utility class for validating campaign variables and ensuring data integrity.
## Provides comprehensive validation rules and constraints for different variable types.

## Validation result structure
class ValidationResult:
	var is_valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	func add_error(message: String) -> void:
		errors.append(message)
		is_valid = false
	
	func add_warning(message: String) -> void:
		warnings.append(message)
	
	func has_issues() -> bool:
		return errors.size() > 0 or warnings.size() > 0
	
	func get_summary() -> String:
		var parts: Array[String] = []
		if errors.size() > 0:
			parts.append("%d errors" % errors.size())
		if warnings.size() > 0:
			parts.append("%d warnings" % warnings.size())
		
		if parts.size() == 0:
			return "Valid"
		else:
			return parts.join(", ")

# Validation rules and constraints
const MAX_VARIABLE_NAME_LENGTH: int = 64
const MAX_STRING_VALUE_LENGTH: int = 4096
const MAX_ARRAY_SIZE: int = 1000
const MAX_DICTIONARY_SIZE: int = 100
const MAX_NESTING_DEPTH: int = 5

# Reserved variable name patterns
const RESERVED_PREFIXES: Array[String] = ["_system_", "_internal_", "_temp_", "_debug_"]
const RESERVED_NAMES: Array[String] = ["null", "true", "false", "nil", "undefined"]

## Validate variable name according to naming rules
static func validate_variable_name(name: String) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# Check empty name
	if name.is_empty():
		result.add_error("Variable name cannot be empty")
		return result
	
	# Check length
	if name.length() > MAX_VARIABLE_NAME_LENGTH:
		result.add_error("Variable name too long (max %d characters)" % MAX_VARIABLE_NAME_LENGTH)
	
	# Check for valid characters
	var regex: RegEx = RegEx.new()
	regex.compile("^[a-zA-Z][a-zA-Z0-9_-]*$")
	if regex.search(name) == null:
		result.add_error("Invalid variable name format. Must start with letter and contain only letters, numbers, underscore, or dash")
	
	# Check reserved prefixes
	for prefix: String in RESERVED_PREFIXES:
		if name.begins_with(prefix):
			result.add_error("Variable name uses reserved prefix: %s" % prefix)
			break
	
	# Check reserved names
	if name.to_lower() in RESERVED_NAMES:
		result.add_error("Variable name is reserved: %s" % name)
	
	# Check for potential confusion with keywords
	var keywords: Array[String] = ["if", "else", "for", "while", "function", "class", "extends", "var", "const"]
	if name.to_lower() in keywords:
		result.add_warning("Variable name conflicts with programming keyword: %s" % name)
	
	return result

## Validate variable value based on type and constraints
static func validate_variable_value(value: Variant, expected_type: CampaignVariables.VariableType = -1) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# Validate based on actual type
	match typeof(value):
		TYPE_INT:
			_validate_integer_value(value, result)
		TYPE_FLOAT:
			_validate_float_value(value, result)
		TYPE_BOOL:
			_validate_boolean_value(value, result)
		TYPE_STRING:
			_validate_string_value(value, result)
		TYPE_ARRAY:
			_validate_array_value(value, result)
		TYPE_DICTIONARY:
			_validate_dictionary_value(value, result)
		TYPE_NIL:
			result.add_warning("Variable value is null")
		_:
			result.add_warning("Variable has unsupported type: %s" % typeof(value))
	
	# Check type compatibility if expected type is specified
	if expected_type != -1:
		_validate_type_compatibility(value, expected_type, result)
	
	return result

## Validate variable scope assignment
static func validate_variable_scope(name: String, scope: CampaignVariables.VariableScope) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# System variables should only be global
	if name.begins_with("_system_") and scope != CampaignVariables.VariableScope.GLOBAL:
		result.add_error("System variables must have global scope")
	
	# Temporary variables should be mission or session scope
	if name.begins_with("_temp_") and scope in [CampaignVariables.VariableScope.GLOBAL, CampaignVariables.VariableScope.CAMPAIGN]:
		result.add_warning("Temporary variables should use mission or session scope")
	
	# Debug variables should be session scope
	if name.begins_with("_debug_") and scope != CampaignVariables.VariableScope.SESSION:
		result.add_warning("Debug variables should use session scope")
	
	return result

## Validate complete variable set for consistency
static func validate_variable_set(variables: Dictionary, metadata: Dictionary) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	
	# Check for metadata consistency
	for var_name: String in variables.keys():
		if var_name not in metadata:
			result.add_warning("Variable '%s' missing metadata" % var_name)
		else:
			var meta: Dictionary = metadata[var_name]
			var expected_type: CampaignVariables.VariableType = meta.get("type", -1)
			if expected_type != -1:
				var value_result: ValidationResult = validate_variable_value(variables[var_name], expected_type)
				if not value_result.is_valid:
					result.add_error("Variable '%s' value validation failed: %s" % [var_name, value_result.errors[0]])
	
	# Check for orphaned metadata
	for var_name: String in metadata.keys():
		if var_name not in variables:
			result.add_warning("Orphaned metadata for variable '%s'" % var_name)
	
	# Check for circular references in complex types
	_check_circular_references(variables, result)
	
	return result

# --- Private Validation Helpers ---

static func _validate_integer_value(value: int, result: ValidationResult) -> void:
	# Check for reasonable bounds (prevent overflow issues)
	if value < -2147483648 or value > 2147483647:
		result.add_warning("Integer value outside 32-bit range: %d" % value)

static func _validate_float_value(value: float, result: ValidationResult) -> void:
	# Check for special float values
	if is_nan(value):
		result.add_error("Float value is NaN (Not a Number)")
	elif is_inf(value):
		result.add_error("Float value is infinite")
	elif abs(value) > 3.4e38:
		result.add_warning("Float value very large, may cause precision issues")

static func _validate_boolean_value(value: bool, result: ValidationResult) -> void:
	# Booleans are always valid, nothing to check
	pass

static func _validate_string_value(value: String, result: ValidationResult) -> void:
	# Check string length
	if value.length() > MAX_STRING_VALUE_LENGTH:
		result.add_error("String value too long (max %d characters)" % MAX_STRING_VALUE_LENGTH)
	
	# Check for null characters that might cause issues
	if "\0" in value:
		result.add_warning("String contains null characters")
	
	# Check for extremely long lines that might impact performance
	var lines: PackedStringArray = value.split("\n")
	for line: String in lines:
		if line.length() > 1000:
			result.add_warning("String contains very long line (%d characters)" % line.length())
			break

static func _validate_array_value(value: Array, result: ValidationResult) -> void:
	# Check array size
	if value.size() > MAX_ARRAY_SIZE:
		result.add_error("Array too large (max %d elements)" % MAX_ARRAY_SIZE)
	
	# Check nesting depth
	var max_depth: int = _calculate_array_depth(value)
	if max_depth > MAX_NESTING_DEPTH:
		result.add_warning("Array nesting too deep (max %d levels)" % MAX_NESTING_DEPTH)
	
	# Check for mixed types that might cause issues
	if value.size() > 1:
		var first_type: int = typeof(value[0])
		var has_mixed_types: bool = false
		for item: Variant in value:
			if typeof(item) != first_type:
				has_mixed_types = true
				break
		
		if has_mixed_types:
			result.add_warning("Array contains mixed types, may cause conversion issues")

static func _validate_dictionary_value(value: Dictionary, result: ValidationResult) -> void:
	# Check dictionary size
	if value.size() > MAX_DICTIONARY_SIZE:
		result.add_error("Dictionary too large (max %d entries)" % MAX_DICTIONARY_SIZE)
	
	# Check key types (should be strings for consistency)
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING:
			result.add_warning("Dictionary has non-string key: %s" % str(key))
	
	# Check nesting depth
	var max_depth: int = _calculate_dictionary_depth(value)
	if max_depth > MAX_NESTING_DEPTH:
		result.add_warning("Dictionary nesting too deep (max %d levels)" % MAX_NESTING_DEPTH)

static func _validate_type_compatibility(value: Variant, expected_type: CampaignVariables.VariableType, result: ValidationResult) -> void:
	var actual_godot_type: int = typeof(value)
	var compatible: bool = false
	
	match expected_type:
		CampaignVariables.VariableType.INTEGER:
			compatible = actual_godot_type in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]
		CampaignVariables.VariableType.FLOAT:
			compatible = actual_godot_type in [TYPE_FLOAT, TYPE_INT]
		CampaignVariables.VariableType.BOOLEAN:
			compatible = actual_godot_type in [TYPE_BOOL, TYPE_INT]
		CampaignVariables.VariableType.STRING:
			compatible = true  # Everything can be converted to string
		CampaignVariables.VariableType.ARRAY:
			compatible = actual_godot_type == TYPE_ARRAY
		CampaignVariables.VariableType.DICTIONARY:
			compatible = actual_godot_type == TYPE_DICTIONARY
	
	if not compatible:
		result.add_warning("Value type %s not directly compatible with expected type %s" % [
			_get_godot_type_name(actual_godot_type),
			_get_variable_type_name(expected_type)
		])

static func _calculate_array_depth(arr: Array, current_depth: int = 0) -> int:
	if current_depth > MAX_NESTING_DEPTH:
		return current_depth
	
	var max_child_depth: int = current_depth
	for item: Variant in arr:
		if typeof(item) == TYPE_ARRAY:
			var child_depth: int = _calculate_array_depth(item, current_depth + 1)
			max_child_depth = max(max_child_depth, child_depth)
		elif typeof(item) == TYPE_DICTIONARY:
			var child_depth: int = _calculate_dictionary_depth(item, current_depth + 1)
			max_child_depth = max(max_child_depth, child_depth)
	
	return max_child_depth

static func _calculate_dictionary_depth(dict: Dictionary, current_depth: int = 0) -> int:
	if current_depth > MAX_NESTING_DEPTH:
		return current_depth
	
	var max_child_depth: int = current_depth
	for value: Variant in dict.values():
		if typeof(value) == TYPE_ARRAY:
			var child_depth: int = _calculate_array_depth(value, current_depth + 1)
			max_child_depth = max(max_child_depth, child_depth)
		elif typeof(value) == TYPE_DICTIONARY:
			var child_depth: int = _calculate_dictionary_depth(value, current_depth + 1)
			max_child_depth = max(max_child_depth, child_depth)
	
	return max_child_depth

static func _check_circular_references(variables: Dictionary, result: ValidationResult) -> void:
	# This is a simplified check - could be more sophisticated
	for var_name: String in variables.keys():
		var value: Variant = variables[var_name]
		if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY]:
			if _contains_string_reference(value, var_name):
				result.add_warning("Possible circular reference in variable '%s'" % var_name)

static func _contains_string_reference(value: Variant, target: String) -> bool:
	match typeof(value):
		TYPE_STRING:
			return str(value) == target
		TYPE_ARRAY:
			for item: Variant in value:
				if _contains_string_reference(item, target):
					return true
		TYPE_DICTIONARY:
			for dict_value: Variant in value.values():
				if _contains_string_reference(dict_value, target):
					return true
	return false

static func _get_godot_type_name(godot_type: int) -> String:
	match godot_type:
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_BOOL:
			return "bool"
		TYPE_STRING:
			return "string"
		TYPE_ARRAY:
			return "array"
		TYPE_DICTIONARY:
			return "dictionary"
		TYPE_NIL:
			return "null"
		_:
			return "unknown"

static func _get_variable_type_name(var_type: CampaignVariables.VariableType) -> String:
	match var_type:
		CampaignVariables.VariableType.INTEGER:
			return "integer"
		CampaignVariables.VariableType.FLOAT:
			return "float"
		CampaignVariables.VariableType.BOOLEAN:
			return "boolean"
		CampaignVariables.VariableType.STRING:
			return "string"
		CampaignVariables.VariableType.ARRAY:
			return "array"
		CampaignVariables.VariableType.DICTIONARY:
			return "dictionary"
		_:
			return "unknown"