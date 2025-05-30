class_name WhenFunction
extends BaseSexpFunction

## WHEN conditional operator for SEXP expressions
##
## Implements the 'when' conditional which only executes its body when
## the condition is true. Unlike 'if', it has no else branch and returns
## void when the condition is false.
##
## Usage: (when condition expression ...)
## Returns: Result of expressions if condition is true, void otherwise

func _init():
	super._init("when", "conditional", "When conditional - executes expressions only if condition is true")
	function_signature = "(when condition expression ...)"
	minimum_args = 2  # condition and at least one expression
	maximum_args = -1  # unlimited expressions
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Conditional execution with implicit progn (multiple expressions)"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	var condition_arg: SexpResult = args[0]
	
	# Handle null condition
	if condition_arg == null:
		return SexpResult.create_error("Condition (first argument) is null", SexpResult.ErrorType.TYPE_MISMATCH)
	
	# Return error if condition is an error
	if condition_arg.is_error():
		return condition_arg
	
	# Evaluate condition to boolean
	var condition_bool: bool = _convert_to_boolean(condition_arg)
	
	# If condition is false, return void without evaluating expressions
	if not condition_bool:
		return SexpResult.create_void()
	
	# Condition is true - evaluate all expressions and return the last result
	var last_result: SexpResult = SexpResult.create_void()
	
	for i in range(1, args.size()):
		var expr_arg: SexpResult = args[i]
		
		# Handle null expression
		if expr_arg == null:
			var error_msg: String = "Expression %d is null" % i
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		# Return error if expression is an error
		if expr_arg.is_error():
			return expr_arg
		
		# Update last result (acts like progn - sequential evaluation)
		last_result = expr_arg
	
	return last_result

func _convert_to_boolean(result: SexpResult) -> bool:
	## Convert SEXP result to boolean following WCS semantics
	match result.result_type:
		SexpResult.ResultType.BOOLEAN:
			return result.get_boolean_value()
		SexpResult.ResultType.NUMBER:
			var num: float = result.get_number_value()
			# WCS treats non-zero as true, zero as false
			return num != 0.0
		SexpResult.ResultType.STRING:
			var str_val: String = result.get_string_value()
			# WCS uses atoi() conversion: non-empty numeric strings are true
			if str_val.is_empty():
				return false
			# Check if string represents a number
			if str_val.is_valid_int() or str_val.is_valid_float():
				return str_val.to_float() != 0.0
			# Non-numeric strings are considered true if non-empty
			return true
		SexpResult.ResultType.OBJECT_REFERENCE:
			# Object references are true if they point to a valid object
			return result.get_object_reference() != null
		SexpResult.ResultType.VOID:
			# Void results are considered false
			return false
		SexpResult.ResultType.ERROR:
			# Error results are considered false
			return false
		_:
			# Unknown types default to false
			return false

func get_usage_examples() -> Array[String]:
	return [
		"(when true 42) ; Returns 42",
		"(when false 42) ; Returns void",
		"(when (> 5 3) \"condition\" \"met\") ; Returns \"met\" (last expression)",
		"(when 1 \"first\" \"second\") ; Returns \"second\" (non-zero is truthy)",
		"(when \"\" 42) ; Returns void (empty string is falsy)",
		"(when (= 2 2) 100) ; Returns 100"
	]

func get_detailed_help() -> String:
	return """WHEN Conditional Operator

The 'when' operator performs conditional execution of multiple expressions.
It only executes the expressions if the condition is true, returning void
if the condition is false.

Syntax:
- (when condition expr1 expr2 ...) - Execute expressions if condition is true

Behavior:
- If condition is false: returns void immediately (no expressions evaluated)
- If condition is true: evaluates all expressions sequentially, returns last result
- Acts like an implicit 'progn' for multiple expressions

Type Conversion Rules for Condition (WCS Compatible):
- Numbers: Non-zero = true, zero = false
- Strings: Non-empty = true, empty = false (numeric strings use numeric value)
- Booleans: Direct boolean value
- Objects: Non-null = true, null = false
- Void/Error: Always false

Use Cases:
- Side effects that should only happen when a condition is met
- Multiple related operations that depend on a condition
- Cleaner alternative to (if condition (progn expr1 expr2 ...))

Performance: O(1) for condition + O(n) for expressions if condition is true
Memory: O(1) additional space"""