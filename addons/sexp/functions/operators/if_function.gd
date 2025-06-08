class_name IfFunction
extends BaseSexpFunction

## Conditional IF operator for SEXP expressions
##
## Implements conditional branching logic with proper evaluation semantics.
## Evaluates condition first, then returns either the 'then' or 'else' expression
## based on the condition's truth value.
##
## Usage: (if condition then-expr else-expr)
## Returns: Result of either then-expr or else-expr based on condition

func _init():
	super._init("if", "conditional", "Conditional branching - evaluates then or else expression based on condition")
	function_signature = "(if condition then-expression else-expression)"
	minimum_args = 2  # condition and then-expr (else-expr optional)
	maximum_args = 3  # condition, then-expr, else-expr
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Standard conditional with lazy evaluation of branches"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var condition_arg: SexpResult = args[0]
	var then_arg: SexpResult = args[1]
	var else_arg: SexpResult = null
	
	# Handle optional else argument
	if args.size() >= 3:
		else_arg = args[2]
	
	# Handle null condition
	if condition_arg == null:
		return SexpResult.create_error("Condition (first argument) is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if condition is an error
	if condition_arg.is_error():
		return condition_arg
	
	# Evaluate condition to boolean
	var condition_bool: bool = _convert_to_boolean(condition_arg)
	
	# Choose branch based on condition
	if condition_bool:
		# Execute then branch
		if then_arg == null:
			return SexpResult.create_error("Then expression (second argument) is null", SexpResult.ErrorType.TYPE_MISMATCH)
		
		if then_arg.is_error():
			return then_arg
		
		return then_arg
	else:
		# Execute else branch (if provided)
		if else_arg != null:
			if else_arg.is_error():
				return else_arg
			
			return else_arg
		else:
			# No else branch provided - return void (WCS behavior)
			return SexpResult.create_void()

func _convert_to_boolean(result: SexpResult) -> bool:
	## Convert SEXP result to boolean following WCS semantics
	match result.result_type:
		SexpResult.Type.BOOLEAN:
			return result.get_boolean_value()
		SexpResult.Type.NUMBER:
			var num: float = result.get_number_value()
			# WCS treats non-zero as true, zero as false
			return num != 0.0
		SexpResult.Type.STRING:
			var str_val: String = result.get_string_value()
			# WCS uses atoi() conversion: non-empty numeric strings are true
			if str_val.is_empty():
				return false
			# Check if string represents a number
			if str_val.is_valid_int() or str_val.is_valid_float():
				return str_val.to_float() != 0.0
			# Non-numeric strings are considered true if non-empty
			return true
		SexpResult.Type.OBJECT_REFERENCE:
			# Object references are true if they point to a valid object
			return result.get_object_reference() != null
		SexpResult.Type.VOID:
			# Void results are considered false
			return false
		SexpResult.Type.ERROR:
			# Error results are considered false
			return false
		_:
			# Unknown types default to false
			return false

func get_usage_examples() -> Array[String]:
	return [
		"(if true 1 2) ; Returns 1",
		"(if false 1 2) ; Returns 2",
		"(if (> 5 3) \"yes\" \"no\") ; Returns \"yes\"",
		"(if 0 \"true\" \"false\") ; Returns \"false\" (0 is falsy)",
		"(if \"hello\" 1) ; Returns 1 (no else clause, non-empty string is truthy)",
		"(if \"\" 1) ; Returns void (no else clause, empty string is falsy)"
	]

func get_detailed_help() -> String:
	return """Conditional IF Operator

The 'if' operator performs conditional branching based on a boolean condition.
It evaluates the condition first, then returns either the 'then' expression
or the 'else' expression based on the condition's truth value.

Syntax:
- (if condition then-expr else-expr) - Full conditional with else
- (if condition then-expr) - Conditional without else (returns void if false)

Type Conversion Rules for Condition (WCS Compatible):
- Numbers: Non-zero = true, zero = false
- Strings: Non-empty = true, empty = false (numeric strings use numeric value)
- Booleans: Direct boolean value
- Objects: Non-null = true, null = false
- Void/Error: Always false

Evaluation Semantics:
- Only the condition is always evaluated
- Only one branch (then or else) is evaluated based on the condition
- If no else branch and condition is false, returns void

Performance: O(1) for condition evaluation + O(branch) for selected branch
Memory: O(1) additional space"""