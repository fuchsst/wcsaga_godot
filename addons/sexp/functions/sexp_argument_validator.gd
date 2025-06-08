class_name SexpArgumentValidator
extends RefCounted

## SEXP Argument Validation Framework
##
## Provides comprehensive argument validation for SEXP functions including
## type checking, count verification, range validation, and custom validation
## rules. Supports both strict and flexible validation modes.

const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Validation rule types
enum ValidationRule {
	EXACT_COUNT,        # Exact argument count
	MIN_COUNT,          # Minimum argument count
	MAX_COUNT,          # Maximum argument count
	RANGE_COUNT,        # Range of argument counts
	REQUIRED_TYPES,     # Required argument types
	ALLOWED_TYPES,      # Allowed argument types
	NUMERIC_RANGE,      # Numeric value ranges
	STRING_LENGTH,      # String length constraints
	CUSTOM_VALIDATOR    # Custom validation function
}

## Validation configuration
var validation_rules: Array[Dictionary] = []
var strict_mode: bool = true
var allow_type_coercion: bool = false
var generate_suggestions: bool = true

## Validation statistics
var validation_count: int = 0
var validation_errors: int = 0
var validation_warnings: int = 0

## Type coercion support
var type_coercion_rules: Dictionary = {}

## Initialize validator
func _init():
	_setup_default_coercion_rules()

## Setup default type coercion rules
func _setup_default_coercion_rules() -> void:
	type_coercion_rules = {
		# Number coercions
		SexpResult.Type.STRING: {
			SexpResult.Type.NUMBER: func(value: String) -> float:
				if value.is_valid_float():
					return value.to_float()
				return NAN
		},
		SexpResult.Type.BOOLEAN: {
			SexpResult.Type.NUMBER: func(value: bool) -> float:
				return 1.0 if value else 0.0
		},
		
		# String coercions
		SexpResult.Type.NUMBER: {
			SexpResult.Type.STRING: func(value: float) -> String:
				return str(value)
		},
		SexpResult.Type.BOOLEAN: {
			SexpResult.Type.STRING: func(value: bool) -> String:
				return "true" if value else "false"
		},
		
		# Boolean coercions
		SexpResult.Type.NUMBER: {
			SexpResult.Type.BOOLEAN: func(value: float) -> bool:
				return value != 0.0
		},
		SexpResult.Type.STRING: {
			SexpResult.Type.BOOLEAN: func(value: String) -> bool:
				var lower: String = value.to_lower()
				return lower == "true" or lower == "1" or lower == "yes"
		}
	}

## Add validation rule
func add_rule(rule_type: ValidationRule, parameters: Dictionary = {}) -> void:
	validation_rules.append({
		"type": rule_type,
		"parameters": parameters
	})

## Add exact count rule
func require_exact_count(count: int) -> void:
	add_rule(ValidationRule.EXACT_COUNT, {"count": count})

## Add minimum count rule
func require_min_count(min_count: int) -> void:
	add_rule(ValidationRule.MIN_COUNT, {"min_count": min_count})

## Add maximum count rule
func require_max_count(max_count: int) -> void:
	add_rule(ValidationRule.MAX_COUNT, {"max_count": max_count})

## Add count range rule
func require_count_range(min_count: int, max_count: int) -> void:
	add_rule(ValidationRule.RANGE_COUNT, {"min_count": min_count, "max_count": max_count})

## Add required types rule
func require_types(types: Array[SexpResult.Type]) -> void:
	add_rule(ValidationRule.REQUIRED_TYPES, {"types": types})

## Add allowed types rule
func allow_types(types: Array[SexpResult.Type]) -> void:
	add_rule(ValidationRule.ALLOWED_TYPES, {"types": types})

## Add numeric range rule for specific argument
func require_numeric_range(arg_index: int, min_value: float, max_value: float) -> void:
	add_rule(ValidationRule.NUMERIC_RANGE, {
		"arg_index": arg_index,
		"min_value": min_value,
		"max_value": max_value
	})

## Add string length rule for specific argument
func require_string_length(arg_index: int, min_length: int, max_length: int = -1) -> void:
	add_rule(ValidationRule.STRING_LENGTH, {
		"arg_index": arg_index,
		"min_length": min_length,
		"max_length": max_length
	})

## Add custom validation rule
func add_custom_validator(validator_func: Callable, description: String = "") -> void:
	add_rule(ValidationRule.CUSTOM_VALIDATOR, {
		"validator": validator_func,
		"description": description
	})

## Validate arguments according to all rules
func validate_arguments(args: Array[SexpResult], function_name: String = "") -> SexpResult:
	validation_count += 1
	
	# Apply each validation rule
	for rule in validation_rules:
		var result: SexpResult = _apply_validation_rule(rule, args, function_name)
		if result.is_error():
			validation_errors += 1
			return result
	
	# Apply type coercion if enabled
	if allow_type_coercion:
		var coercion_result: SexpResult = _apply_type_coercion(args)
		if coercion_result.is_error():
			validation_errors += 1
			return coercion_result
	
	return SexpResult.create_void()  # Validation passed

## Apply single validation rule
func _apply_validation_rule(rule: Dictionary, args: Array[SexpResult], function_name: String) -> SexpResult:
	var rule_type: ValidationRule = rule["type"]
	var parameters: Dictionary = rule["parameters"]
	
	match rule_type:
		ValidationRule.EXACT_COUNT:
			return _validate_exact_count(args, parameters["count"], function_name)
		
		ValidationRule.MIN_COUNT:
			return _validate_min_count(args, parameters["min_count"], function_name)
		
		ValidationRule.MAX_COUNT:
			return _validate_max_count(args, parameters["max_count"], function_name)
		
		ValidationRule.RANGE_COUNT:
			return _validate_count_range(args, parameters["min_count"], parameters["max_count"], function_name)
		
		ValidationRule.REQUIRED_TYPES:
			return _validate_required_types(args, parameters["types"], function_name)
		
		ValidationRule.ALLOWED_TYPES:
			return _validate_allowed_types(args, parameters["types"], function_name)
		
		ValidationRule.NUMERIC_RANGE:
			return _validate_numeric_range(args, parameters, function_name)
		
		ValidationRule.STRING_LENGTH:
			return _validate_string_length(args, parameters, function_name)
		
		ValidationRule.CUSTOM_VALIDATOR:
			return _validate_custom(args, parameters, function_name)
		
		_:
			return SexpResult.create_error("Unknown validation rule type: %d" % rule_type)

## Validate exact argument count
func _validate_exact_count(args: Array[SexpResult], expected_count: int, function_name: String) -> SexpResult:
	if args.size() != expected_count:
		var suggestion: String = ""
		if generate_suggestions:
			if args.size() < expected_count:
				suggestion = "Add %d more argument(s)" % (expected_count - args.size())
			else:
				suggestion = "Remove %d argument(s)" % (args.size() - expected_count)
		
		return SexpResult.create_contextual_error(
			"Argument count mismatch: expected exactly %d, got %d" % [expected_count, args.size()],
			"In function '%s'" % function_name,
			-1, -1, -1,
			suggestion,
			SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH
		)
	
	return SexpResult.create_void()

## Validate minimum argument count
func _validate_min_count(args: Array[SexpResult], min_count: int, function_name: String) -> SexpResult:
	if args.size() < min_count:
		var suggestion: String = ""
		if generate_suggestions:
			suggestion = "Add %d more argument(s)" % (min_count - args.size())
		
		return SexpResult.create_contextual_error(
			"Too few arguments: expected at least %d, got %d" % [min_count, args.size()],
			"In function '%s'" % function_name,
			-1, -1, -1,
			suggestion,
			SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH
		)
	
	return SexpResult.create_void()

## Validate maximum argument count
func _validate_max_count(args: Array[SexpResult], max_count: int, function_name: String) -> SexpResult:
	if args.size() > max_count:
		var suggestion: String = ""
		if generate_suggestions:
			suggestion = "Remove %d argument(s)" % (args.size() - max_count)
		
		return SexpResult.create_contextual_error(
			"Too many arguments: expected at most %d, got %d" % [max_count, args.size()],
			"In function '%s'" % function_name,
			-1, -1, -1,
			suggestion,
			SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH
		)
	
	return SexpResult.create_void()

## Validate argument count range
func _validate_count_range(args: Array[SexpResult], min_count: int, max_count: int, function_name: String) -> SexpResult:
	var arg_count: int = args.size()
	
	if arg_count < min_count or arg_count > max_count:
		var suggestion: String = ""
		if generate_suggestions:
			if arg_count < min_count:
				suggestion = "Add %d more argument(s)" % (min_count - arg_count)
			else:
				suggestion = "Remove %d argument(s)" % (arg_count - max_count)
		
		return SexpResult.create_contextual_error(
			"Argument count out of range: expected %d to %d, got %d" % [min_count, max_count, arg_count],
			"In function '%s'" % function_name,
			-1, -1, -1,
			suggestion,
			SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH
		)
	
	return SexpResult.create_void()

## Validate required argument types (position-specific)
func _validate_required_types(args: Array[SexpResult], required_types: Array[SexpResult.Type], function_name: String) -> SexpResult:
	for i in range(min(args.size(), required_types.size())):
		var arg: SexpResult = args[i]
		var required_type: SexpResult.Type = required_types[i]
		
		if arg.result_type != required_type:
			var suggestion: String = ""
			if generate_suggestions:
				suggestion = _generate_type_conversion_suggestion(arg.result_type, required_type)
			
			return SexpResult.create_contextual_error(
				"Type mismatch at position %d: expected %s, got %s" % [
					i + 1,
					SexpResult.get_type_name(required_type),
					SexpResult.get_type_name(arg.result_type)
				],
				"In function '%s'" % function_name,
				-1, -1, -1,
				suggestion,
				SexpResult.ErrorType.TYPE_MISMATCH
			)
	
	return SexpResult.create_void()

## Validate allowed argument types (any argument can be any allowed type)
func _validate_allowed_types(args: Array[SexpResult], allowed_types: Array[SexpResult.Type], function_name: String) -> SexpResult:
	for i in range(args.size()):
		var arg: SexpResult = args[i]
		
		if arg.result_type not in allowed_types:
			var type_names: Array[String] = []
			for type in allowed_types:
				type_names.append(SexpResult.get_type_name(type))
			
			var suggestion: String = ""
			if generate_suggestions:
				suggestion = "Convert to one of: %s" % ", ".join(type_names)
			
			return SexpResult.create_contextual_error(
				"Invalid argument type at position %d: expected one of [%s], got %s" % [
					i + 1,
					", ".join(type_names),
					SexpResult.get_type_name(arg.result_type)
				],
				"In function '%s'" % function_name,
				-1, -1, -1,
				suggestion,
				SexpResult.ErrorType.TYPE_MISMATCH
			)
	
	return SexpResult.create_void()

## Validate numeric range for specific argument
func _validate_numeric_range(args: Array[SexpResult], parameters: Dictionary, function_name: String) -> SexpResult:
	var arg_index: int = parameters["arg_index"]
	var min_value: float = parameters["min_value"]
	var max_value: float = parameters["max_value"]
	
	if arg_index >= args.size():
		return SexpResult.create_void()  # Argument doesn't exist, let count validation handle it
	
	var arg: SexpResult = args[arg_index]
	
	if not arg.is_number():
		return SexpResult.create_contextual_error(
			"Argument at position %d must be numeric for range validation" % (arg_index + 1),
			"In function '%s'" % function_name,
			-1, -1, -1,
			"Convert argument to number",
			SexpResult.ErrorType.TYPE_MISMATCH
		)
	
	var value: float = arg.get_number_value()
	
	if value < min_value or value > max_value:
		var suggestion: String = ""
		if generate_suggestions:
			suggestion = "Value must be between %g and %g" % [min_value, max_value]
		
		return SexpResult.create_contextual_error(
			"Numeric value out of range at position %d: %g not in [%g, %g]" % [arg_index + 1, value, min_value, max_value],
			"In function '%s'" % function_name,
			-1, -1, -1,
			suggestion,
			SexpResult.ErrorType.VALUE_OUT_OF_RANGE
		)
	
	return SexpResult.create_void()

## Validate string length for specific argument
func _validate_string_length(args: Array[SexpResult], parameters: Dictionary, function_name: String) -> SexpResult:
	var arg_index: int = parameters["arg_index"]
	var min_length: int = parameters["min_length"]
	var max_length: int = parameters.get("max_length", -1)
	
	if arg_index >= args.size():
		return SexpResult.create_void()  # Argument doesn't exist, let count validation handle it
	
	var arg: SexpResult = args[arg_index]
	
	if not arg.is_string():
		return SexpResult.create_contextual_error(
			"Argument at position %d must be string for length validation" % (arg_index + 1),
			"In function '%s'" % function_name,
			-1, -1, -1,
			"Convert argument to string",
			SexpResult.ErrorType.TYPE_MISMATCH
		)
	
	var value: String = arg.get_string_value()
	var length: int = value.length()
	
	if length < min_length:
		var suggestion: String = ""
		if generate_suggestions:
			suggestion = "String must be at least %d characters long" % min_length
		
		return SexpResult.create_contextual_error(
			"String too short at position %d: %d characters, minimum %d" % [arg_index + 1, length, min_length],
			"In function '%s'" % function_name,
			-1, -1, -1,
			suggestion,
			SexpResult.ErrorType.VALUE_OUT_OF_RANGE
		)
	
	if max_length >= 0 and length > max_length:
		var suggestion: String = ""
		if generate_suggestions:
			suggestion = "String must be at most %d characters long" % max_length
		
		return SexpResult.create_contextual_error(
			"String too long at position %d: %d characters, maximum %d" % [arg_index + 1, length, max_length],
			"In function '%s'" % function_name,
			-1, -1, -1,
			suggestion,
			SexpResult.ErrorType.VALUE_OUT_OF_RANGE
		)
	
	return SexpResult.create_void()

## Validate using custom validator function
func _validate_custom(args: Array[SexpResult], parameters: Dictionary, function_name: String) -> SexpResult:
	var validator: Callable = parameters["validator"]
	var description: String = parameters.get("description", "custom validation")
	
	try:
		var result = validator.call(args)
		
		# Support different return types from custom validators
		if result is SexpResult:
			return result
		elif result is bool:
			if result:
				return SexpResult.create_void()  # Validation passed
			else:
				return SexpResult.create_contextual_error(
					"Custom validation failed: %s" % description,
					"In function '%s'" % function_name,
					-1, -1, -1,
					"Check argument values and constraints",
					SexpResult.ErrorType.VALIDATION_ERROR
				)
		elif result is String:
			if result.is_empty():
				return SexpResult.create_void()  # Empty string means success
			else:
				return SexpResult.create_contextual_error(
					"Custom validation failed: %s" % result,
					"In function '%s'" % function_name,
					-1, -1, -1,
					"Check argument values and constraints",
					SexpResult.ErrorType.VALIDATION_ERROR
				)
		else:
			return SexpResult.create_error("Custom validator returned invalid result type")
	
	except error:
		return SexpResult.create_contextual_error(
			"Custom validation error: %s" % error,
			"In function '%s'" % function_name,
			-1, -1, -1,
			"Check custom validator implementation",
			SexpResult.ErrorType.RUNTIME_ERROR
		)

## Apply type coercion if enabled
func _apply_type_coercion(args: Array[SexpResult]) -> SexpResult:
	# This is a placeholder for future type coercion implementation
	# For now, return success to indicate no coercion errors
	return SexpResult.create_void()

## Generate type conversion suggestion
func _generate_type_conversion_suggestion(from_type: SexpResult.Type, to_type: SexpResult.Type) -> String:
	var from_name: String = SexpResult.get_type_name(from_type)
	var to_name: String = SexpResult.get_type_name(to_type)
	
	# Provide specific conversion suggestions
	match [from_type, to_type]:
		[SexpResult.Type.STRING, SexpResult.Type.NUMBER]:
			return "Use (string-to-number \"%s\") or ensure string contains valid number" % from_name
		[SexpResult.Type.NUMBER, SexpResult.Type.STRING]:
			return "Use (number-to-string %s) to convert number to string" % from_name
		[SexpResult.Type.BOOLEAN, SexpResult.Type.NUMBER]:
			return "Use (if %s 1 0) to convert boolean to number" % from_name
		[SexpResult.Type.NUMBER, SexpResult.Type.BOOLEAN]:
			return "Use (!= %s 0) to convert number to boolean" % from_name
		_:
			return "Convert %s to %s" % [from_name, to_name]

## Create validator for common patterns
static func create_arithmetic_validator() -> SexpArgumentValidator:
	var validator: SexpArgumentValidator = SexpArgumentValidator.new()
	validator.require_min_count(1)
	validator.allow_types([SexpResult.Type.NUMBER])
	return validator

static func create_comparison_validator() -> SexpArgumentValidator:
	var validator: SexpArgumentValidator = SexpArgumentValidator.new()
	validator.require_exact_count(2)
	validator.allow_types([SexpResult.Type.NUMBER, SexpResult.Type.STRING, SexpResult.Type.BOOLEAN])
	return validator

static func create_logical_validator() -> SexpArgumentValidator:
	var validator: SexpArgumentValidator = SexpArgumentValidator.new()
	validator.require_min_count(1)
	validator.allow_types([SexpResult.Type.BOOLEAN])
	return validator

static func create_string_validator() -> SexpArgumentValidator:
	var validator: SexpArgumentValidator = SexpArgumentValidator.new()
	validator.require_min_count(1)
	validator.allow_types([SexpResult.Type.STRING])
	return validator

## Clear all validation rules
func clear_rules() -> void:
	validation_rules.clear()

## Get validation statistics
func get_statistics() -> Dictionary:
	return {
		"validation_count": validation_count,
		"validation_errors": validation_errors,
		"validation_warnings": validation_warnings,
		"error_rate": float(validation_errors) / max(1, validation_count),
		"rules_count": validation_rules.size(),
		"strict_mode": strict_mode,
		"type_coercion": allow_type_coercion
	}

## Reset validation statistics
func reset_statistics() -> void:
	validation_count = 0
	validation_errors = 0
	validation_warnings = 0

## String representation for debugging
func _to_string() -> String:
	return "SexpArgumentValidator(rules=%d, validations=%d, errors=%d)" % [
		validation_rules.size(),
		validation_count,
		validation_errors
	]