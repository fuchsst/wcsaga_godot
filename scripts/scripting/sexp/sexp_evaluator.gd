# sexp_evaluator.gd
# Evaluates a parsed S-Expression (SEXP) tree represented by SexpNode resources.
# It recursively processes nodes and calls appropriate handlers for operators.
class_name SexpEvaluator
extends RefCounted # Or Node if it needs scene tree access directly

# Import constants and node definition
const SexpConstants = preload("res://scripts/scripting/sexp/sexp_constants.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")

# --- Autoload References ---
# Assumes these are set up as Autoloads/Singletons in project settings
var SexpOperatorHandler # = preload("res://scripts/scripting/sexp/sexp_operators.gd") # Assign in _ready or get node
var SexpVariableManager # = preload("res://scripts/scripting/sexp/sexp_variables.gd") # Assign in _ready or get node

# --- Initialization ---
# Get references to Autoloads. If this script is attached to a Node, use get_node.
# If it's a standalone RefCounted used by MissionManager, MissionManager needs to pass references.
# For simplicity, assuming they are accessible globally for now.
func _init():
	# NOTE: Accessing Autoloads directly by name is generally preferred in Godot 4.
	# Ensure 'SexpOperatorHandler' and 'SexpVariableManager' are configured as Autoloads.
	if Engine.has_singleton("SexpOperatorHandler"):
		SexpOperatorHandler = Engine.get_singleton("SexpOperatorHandler")
	else:
		push_error("SexpOperatorHandler Autoload not found!")

	if Engine.has_singleton("SexpVariableManager"):
		SexpVariableManager = Engine.get_singleton("SexpVariableManager")
	else:
		push_error("SexpVariableManager Autoload not found!")


# --- Public Evaluation API ---

## Evaluates a SEXP node and returns its result.
## The result type depends on the operator (often int for bool/number, sometimes String).
## Returns SexpConstants.SEXP_UNKNOWN or SexpConstants.SEXP_CANT_EVAL on error.
func eval_sexp(node: SexpNode, context: Dictionary) -> Variant:
	if node == null:
		push_error("eval_sexp called with null node!")
		return SexpConstants.SEXP_CANT_EVAL

	if node.is_atom():
		return _eval_atom(node, context)
	elif node.is_list():
		return _eval_list(node, context)
	else:
		push_error("Unknown SexpNode type: %d" % node.node_type)
		return SexpConstants.SEXP_CANT_EVAL


## Evaluates a SEXP node specifically for a boolean result (true/false).
## Uses the original FS2 logic: non-zero numbers are true, specific constants.
func is_sexp_true(node: SexpNode, context: Dictionary) -> bool:
	var result = eval_sexp(node, context)

	match result:
		SexpConstants.SEXP_TRUE, SexpConstants.SEXP_KNOWN_TRUE:
			return true
		SexpConstants.SEXP_FALSE, SexpConstants.SEXP_KNOWN_FALSE:
			return false
		SexpConstants.SEXP_UNKNOWN, SexpConstants.SEXP_CANT_EVAL, SexpConstants.SEXP_NAN, SexpConstants.SEXP_NAN_FOREVER:
			# How should unknown/errors be treated? Defaulting to false for safety.
			# Original FS2 might have specific behavior.
			return false
		_:
			# Check if it's a numerical result
			if result is int or result is float:
				return result != 0
			# Non-numeric, non-constant results are generally false in boolean contexts
			push_warning("is_sexp_true received non-standard result type: %s. Treating as false." % typeof(result))
			return false


# --- Internal Evaluation Logic ---

func _eval_atom(node: SexpNode, context: Dictionary) -> Variant:
	match node.atom_subtype:
		SexpConstants.SEXP_ATOM_NUMBER:
			return node.get_number_value() # Returns float
		SexpConstants.SEXP_ATOM_STRING:
			var text = node.get_string_value()
			# Check if it's a variable reference
			if text.begins_with("@"):
				var value = SexpVariableManager.get_variable(text)
				if value == null:
					push_warning("SEXP Variable '%s' not found during evaluation." % text)
					# Return default based on expected type? Or a specific error?
					# FS2 might return 0 or "" depending on operator context.
					# Returning SEXP_UNKNOWN for now.
					return SexpConstants.SEXP_UNKNOWN
				return value # Can be float or String
			else:
				return text # It's a literal string
		SexpConstants.SEXP_ATOM_OPERATOR:
			# An operator atom shouldn't be evaluated directly like this.
			# It should only appear as the first element of a list.
			push_error("Attempted to evaluate an operator atom directly: %s" % node.text)
			return SexpConstants.SEXP_CANT_EVAL
		_:
			push_error("Unknown SexpNode atom subtype: %d" % node.atom_subtype)
			return SexpConstants.SEXP_CANT_EVAL


func _eval_list(node: SexpNode, context: Dictionary) -> Variant:
	if node.get_child_count() == 0:
		push_warning("Attempted to evaluate an empty SEXP list.")
		return SexpConstants.SEXP_UNKNOWN # Or SEXP_FALSE?

	var operator_node: SexpNode = node.get_child(0)
	if not operator_node.is_operator():
		push_error("First element of SEXP list is not an operator: %s" % operator_node.text)
		return SexpConstants.SEXP_CANT_EVAL

	var op_code: int = operator_node.get_operator()

	# --- Handle Lazy Evaluation Operators (and, or, when, etc.) ---
	# These operators might not evaluate all their arguments.
	# We pass the unevaluated child nodes directly to the handler.
	match op_code:
		SexpConstants.OP_AND, SexpConstants.OP_OR, \
		SexpConstants.OP_WHEN, SexpConstants.OP_EVERY_TIME, \
		SexpConstants.OP_COND: # Add other lazy operators here
			# Get the handler function from the Operator Handler Singleton
			var handler_func: Callable = SexpOperatorHandler.get_operator_handler(op_code)
			if handler_func.is_valid():
				# Pass unevaluated children (excluding the operator itself)
				var args: Array[SexpNode] = node.children.slice(1)
				# Call handler: handler(args_array, context_dict)
				return handler_func.call(args, context)
			else:
				push_error("No handler found for lazy operator: %s (%d)" % [operator_node.text, op_code])
				return SexpConstants.SEXP_CANT_EVAL

	# --- Handle Standard Evaluation Operators ---
	# Evaluate all arguments first, then call the handler.
	var evaluated_args: Array = []
	for i in range(1, node.get_child_count()):
		var arg_node: SexpNode = node.get_child(i)
		var arg_value = eval_sexp(arg_node, context)

		# Handle potential evaluation errors in arguments
		if arg_value == SexpConstants.SEXP_CANT_EVAL or arg_value == SexpConstants.SEXP_UNKNOWN:
			# Propagate error/unknown state? Or default to 0/false?
			# Propagating seems safer.
			push_warning("Argument %d for operator %s evaluated to error/unknown." % [i, operator_node.text])
			# Depending on the operator, this might be handled differently.
			# For now, let's try passing the error state along.
			# evaluated_args.append(SexpConstants.SEXP_UNKNOWN) # Or maybe just return error immediately?
			# Let's return immediately for now.
			return arg_value

		evaluated_args.append(arg_value)

	# Get the handler function from the Operator Handler Singleton
	var handler_func: Callable = SexpOperatorHandler.get_operator_handler(op_code)
	if handler_func.is_valid():
		# Call handler: handler(args_array, context_dict)
		# Using callv for dynamic argument passing based on array size
		return handler_func.call(evaluated_args, context)
		# Note: Original C++ might pass args individually. If handlers expect
		# fixed args (arg1, arg2, context), we might need a different dispatch mechanism
		# or ensure handlers accept an array. Using an array is more flexible.
	else:
		push_error("No handler found for operator: %s (%d)" % [operator_node.text, op_code])
		return SexpConstants.SEXP_CANT_EVAL
