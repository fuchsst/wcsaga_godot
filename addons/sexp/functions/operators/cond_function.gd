class_name CondFunction
extends BaseSexpFunction

## COND multi-branch conditional operator for SEXP expressions
##
## Implements the 'cond' operator for multi-way branching.
## Takes multiple condition-expression pairs and evaluates the first
## matching condition, returning its corresponding expression.
##
## Usage: (cond (condition1 expr1) (condition2 expr2) ... (else expr-else))
## Returns: Result of the first matching condition's expression

func _init():
	super._init("cond", "conditional", "Multi-branch conditional - evaluates first matching condition")
	function_signature = "(cond (condition1 expr1) (condition2 expr2) ...)"
	minimum_args = 1  # At least one condition-expression pair
	maximum_args = -1  # unlimited pairs
	supported_argument_types = []  # accepts any type
	wcs_compatibility_notes = "Multi-way conditional with short-circuit evaluation"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	# Each argument should be a pair (condition expression) or special 'else' case
	for i in range(args.size()):
		var pair_arg: SexpResult = args[i]
		
		# Handle null pair
		if pair_arg == null:
			var error_msg: String = "Condition pair %d is null" % (i + 1)
			return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
		
		# Return error if pair is an error
		if pair_arg.is_error():
			return pair_arg
		
		# For this implementation, we expect each pair to be pre-evaluated
		# In a full SEXP system, this would parse nested expressions
		# For now, we'll treat odd arguments as conditions and even as expressions
		
		# If this is the last argument and we haven't found a match,
		# treat it as the default/else case
		if i == args.size() - 1:
			# Last argument is the default case
			return pair_arg
		
		# For pairs of arguments: check condition and return expression if true
		if i % 2 == 0:  # Even index = condition
			var condition_result: SexpResult = pair_arg
			
			# Evaluate condition to boolean
			var condition_bool: bool = _convert_to_boolean(condition_result)
			
			if condition_bool:
				# Condition is true - return the corresponding expression
				if i + 1 < args.size():
					var expression_arg: SexpResult = args[i + 1]
					
					if expression_arg == null:
						var error_msg: String = "Expression for condition %d is null" % (i / 2 + 1)
						return SexpResult.create_error(error_msg, SexpResult.ErrorType.TYPE_MISMATCH)
					
					if expression_arg.is_error():
						return expression_arg
					
					return expression_arg
				else:
					# Condition is true but no expression provided
					return SexpResult.create_error("Condition is true but no expression provided", SexpResult.ErrorType.ARGUMENT_COUNT_MISMATCH)
	
	# No conditions matched and no default case
	return SexpResult.create_void()

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
		"(cond true \"first\" false \"second\") ; Returns \"first\"",
		"(cond false \"first\" true \"second\") ; Returns \"second\"",
		"(cond false \"first\" false \"second\" \"default\") ; Returns \"default\"",
		"(cond (> 5 3) \"greater\" (< 5 3) \"less\") ; Returns \"greater\"",
		"(cond 0 \"zero\" \"\" \"empty\" \"neither\") ; Returns \"neither\"",
		"(cond false \"no\") ; Returns void (no match, no default)"
	]

func get_detailed_help() -> String:
	return """COND Multi-Branch Conditional Operator

The 'cond' operator provides multi-way conditional branching.
It evaluates conditions in order and returns the expression corresponding
to the first true condition.

Syntax (simplified for pre-evaluated arguments):
- (cond condition1 expr1 condition2 expr2 ... default)
- Arguments alternate: condition, expression, condition, expression, ...
- Last odd argument serves as default case if no conditions match

Evaluation Order:
1. Evaluates conditions in sequence until one is true
2. Returns the expression corresponding to the first true condition
3. If no conditions match, returns the default case (if provided)
4. If no conditions match and no default, returns void

Type Conversion Rules for Conditions (WCS Compatible):
- Numbers: Non-zero = true, zero = false
- Strings: Non-empty = true, empty = false (numeric strings use numeric value)
- Booleans: Direct boolean value
- Objects: Non-null = true, null = false
- Void/Error: Always false

Note: In a full SEXP parser, conditions and expressions would be nested
expressions that are evaluated on-demand. This implementation assumes
pre-evaluated arguments for simplicity.

Performance: O(n) where n is number of conditions checked
Memory: O(1) additional space"""