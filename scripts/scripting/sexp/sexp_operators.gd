# sexp_operators.gd
# Autoload Singleton responsible for handling the execution of individual
# S-Expression (SEXP) operators. The SexpEvaluator calls functions here.
extends Node

# Import constants
const SexpConstants = preload("res://scripts/scripting/sexp/sexp_constants.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Needed for lazy eval args

# --- Operator Handler Storage ---
# Dictionary mapping operator codes (int) to Callable functions.
var _operator_handlers: Dictionary = {}

# --- References (if needed) ---
var ObjectManager # = Engine.get_singleton("ObjectManager") # Example
var MissionManager # = Engine.get_singleton("MissionManager") # Example
var GameManager # = Engine.get_singleton("GameManager") # Example
var MessageManager # = Engine.get_singleton("MessageManager") # Example
# var SexpEvaluator # Need reference for lazy evaluation - passed via context

# --- Initialization ---
func _ready() -> void:
	# Get necessary singleton references
	# Ensure these Autoloads are configured in Project Settings
	if Engine.has_singleton("ObjectManager"):
		ObjectManager = Engine.get_singleton("ObjectManager")
	else:
		push_warning("SexpOperatorHandler: ObjectManager Autoload not found!")

	if Engine.has_singleton("MissionManager"):
		MissionManager = Engine.get_singleton("MissionManager")
	else:
		push_warning("SexpOperatorHandler: MissionManager Autoload not found!")

	if Engine.has_singleton("GameManager"):
		GameManager = Engine.get_singleton("GameManager")
	else:
		push_warning("SexpOperatorHandler: GameManager Autoload not found!")

	if Engine.has_singleton("MessageManager"):
		MessageManager = Engine.get_singleton("MessageManager")
	else:
		push_warning("SexpOperatorHandler: MessageManager Autoload not found!")

	# Register handlers for the core operators
	_register_handler(SexpConstants.OP_TRUE, Callable(self, "_op_true"))
	_register_handler(SexpConstants.OP_FALSE, Callable(self, "_op_false"))
	_register_handler(SexpConstants.OP_AND, Callable(self, "_op_and"))
	_register_handler(SexpConstants.OP_OR, Callable(self, "_op_or"))
	_register_handler(SexpConstants.OP_EQUALS, Callable(self, "_op_equals"))
	_register_handler(SexpConstants.OP_IS_DESTROYED, Callable(self, "_op_is_destroyed"))
	_register_handler(SexpConstants.OP_DISTANCE, Callable(self, "_op_distance"))
	_register_handler(SexpConstants.OP_MISSION_TIME, Callable(self, "_op_mission_time"))
	_register_handler(SexpConstants.OP_HITS_LEFT, Callable(self, "_op_hits_left"))
	_register_handler(SexpConstants.OP_HITS_LEFT_SUBSYSTEM, Callable(self, "_op_hits_left_subsystem"))
	_register_handler(SexpConstants.OP_SEND_MESSAGE, Callable(self, "_op_send_message"))
	_register_handler(SexpConstants.OP_ADD_GOAL, Callable(self, "_op_add_goal"))
	_register_handler(SexpConstants.OP_MODIFY_VARIABLE, Callable(self, "_op_modify_variable"))
	_register_handler(SexpConstants.OP_END_MISSION, Callable(self, "_op_end_mission"))
	_register_handler(SexpConstants.OP_WHEN, Callable(self, "_op_when")) # Lazy
	_register_handler(SexpConstants.OP_EVERY_TIME, Callable(self, "_op_every_time")) # Lazy
	_register_handler(SexpConstants.OP_AI_CHASE, Callable(self, "_op_ai_chase"))
	_register_handler(SexpConstants.OP_AI_WAYPOINTS, Callable(self, "_op_ai_waypoints"))

	# Arithmetic Operators
	_register_handler(SexpConstants.OP_PLUS, Callable(self, "_op_plus"))
	_register_handler(SexpConstants.OP_MINUS, Callable(self, "_op_minus"))
	_register_handler(SexpConstants.OP_MUL, Callable(self, "_op_multiply"))
	_register_handler(SexpConstants.OP_DIV, Callable(self, "_op_divide"))
	_register_handler(SexpConstants.OP_MOD, Callable(self, "_op_modulo"))
	_register_handler(SexpConstants.OP_RAND, Callable(self, "_op_random"))
	_register_handler(SexpConstants.OP_ABS, Callable(self, "_op_absolute"))
	# TODO: Add MIN, MAX, AVG, RAND_MULTIPLE etc.

	# TODO: Register handlers for ALL other operators...


func _register_handler(op_code: int, handler: Callable) -> void:
	if _operator_handlers.has(op_code):
		push_warning("Duplicate handler registration for SEXP operator code: %d" % op_code)
	_operator_handlers[op_code] = handler


## Returns the Callable function associated with the given operator code.
func get_operator_handler(op_code: int) -> Callable:
	if _operator_handlers.has(op_code):
		return _operator_handlers[op_code]
	else:
		# Return an invalid Callable if handler not found
		return Callable()


# --- Operator Handler Implementations (Placeholders) ---
# Convention: _op_operator_name(args: Array, context: Dictionary) -> Variant
# For lazy operators: _op_operator_name(args: Array[SexpNode], context: Dictionary) -> Variant

# --- Logical Operators ---
func _op_true(args: Array, context: Dictionary) -> int:
	# Args: None
	return SexpConstants.SEXP_TRUE

func _op_false(args: Array, context: Dictionary) -> int:
	# Args: None
	return SexpConstants.SEXP_FALSE

func _op_and(args: Array[SexpNode], context: Dictionary) -> int:
	# Args: List of SexpNodes to evaluate
	# Lazy evaluation: return false as soon as one argument is false
	if args.is_empty():
		push_warning("SEXP 'and' called with no arguments.")
		return SexpConstants.SEXP_TRUE # Empty 'and' is true in Lisp? Check FS2 behavior.

	# Need the evaluator instance to call is_sexp_true recursively
	var evaluator = context.get("evaluator") # Assume evaluator is passed in context
	if evaluator == null:
		push_error("'and' operator requires evaluator in context for lazy evaluation.")
		return SexpConstants.SEXP_CANT_EVAL

	for arg_node in args:
		if not evaluator.is_sexp_true(arg_node, context):
			return SexpConstants.SEXP_FALSE
	return SexpConstants.SEXP_TRUE

func _op_or(args: Array[SexpNode], context: Dictionary) -> int:
	# Args: List of SexpNodes to evaluate
	# Lazy evaluation: return true as soon as one argument is true
	if args.is_empty():
		push_warning("SEXP 'or' called with no arguments.")
		return SexpConstants.SEXP_FALSE # Empty 'or' is false in Lisp? Check FS2 behavior.

	var evaluator = context.get("evaluator")
	if evaluator == null:
		push_error("'or' operator requires evaluator in context for lazy evaluation.")
		return SexpConstants.SEXP_CANT_EVAL

	for arg_node in args:
		if evaluator.is_sexp_true(arg_node, context):
			return SexpConstants.SEXP_TRUE
	return SexpConstants.SEXP_FALSE

func _op_equals(args: Array, context: Dictionary) -> int:
	# Args: [value1, value2]
	if args.size() != 2:
		push_error("'equals' requires 2 arguments, got %d" % args.size())
		return SexpConstants.SEXP_CANT_EVAL
	# Basic comparison, might need type coercion logic like FS2
	if args[0] == args[1]:
		return SexpConstants.SEXP_TRUE
	else:
		# Handle float comparison with tolerance?
		if args[0] is float and args[1] is float:
			if is_equal_approx(args[0], args[1]):
				return SexpConstants.SEXP_TRUE
		return SexpConstants.SEXP_FALSE


# --- Helper for Arithmetic ---
# Ensures arguments are numbers (float or int)
func _are_args_numeric(args: Array, op_name: String) -> bool:
	for i in range(args.size()):
		if not (args[i] is float or args[i] is int):
			push_error("SEXP '%s' requires numeric arguments, got %s for argument %d." % [op_name, typeof(args[i]), i+1])
			return false
	return true


# --- Arithmetic Operators ---

func _op_plus(args: Array, context: Dictionary) -> Variant:
	# Args: [num1, num2, ...]
	if args.is_empty():
		push_error("SEXP '+' requires at least one argument.")
		return SexpConstants.SEXP_CANT_EVAL
	if not _are_args_numeric(args, "+"):
		return SexpConstants.SEXP_CANT_EVAL

	var sum: float = 0.0
	for arg in args:
		sum += float(arg)
	return sum

func _op_minus(args: Array, context: Dictionary) -> Variant:
	# Args: [num1, num2] or [num] for negation
	if args.size() == 1: # Negation
		if not _are_args_numeric(args, "- (negation)"):
			return SexpConstants.SEXP_CANT_EVAL
		return -float(args[0])
	elif args.size() == 2: # Subtraction
		if not _are_args_numeric(args, "- (subtraction)"):
			return SexpConstants.SEXP_CANT_EVAL
		return float(args[0]) - float(args[1])
	else:
		push_error("SEXP '-' requires 1 or 2 arguments, got %d." % args.size())
		return SexpConstants.SEXP_CANT_EVAL

func _op_multiply(args: Array, context: Dictionary) -> Variant:
	# Args: [num1, num2, ...]
	if args.is_empty():
		push_error("SEXP '*' requires at least one argument.")
		return SexpConstants.SEXP_CANT_EVAL
	if not _are_args_numeric(args, "*"):
		return SexpConstants.SEXP_CANT_EVAL

	var product: float = 1.0
	for arg in args:
		product *= float(arg)
	return product

func _op_divide(args: Array, context: Dictionary) -> Variant:
	# Args: [numerator, denominator]
	if args.size() != 2:
		push_error("SEXP '/' requires 2 arguments, got %d." % args.size())
		return SexpConstants.SEXP_CANT_EVAL
	if not _are_args_numeric(args, "/"):
		return SexpConstants.SEXP_CANT_EVAL

	var denominator = float(args[1])
	if denominator == 0.0:
		push_error("SEXP '/' division by zero.")
		return SexpConstants.SEXP_CANT_EVAL # Or NaN?
	return float(args[0]) / denominator

func _op_modulo(args: Array, context: Dictionary) -> Variant:
	# Args: [dividend, divisor]
	if args.size() != 2:
		push_error("SEXP '%' requires 2 arguments, got %d." % args.size())
		return SexpConstants.SEXP_CANT_EVAL
	if not _are_args_numeric(args, "%"):
		return SexpConstants.SEXP_CANT_EVAL

	var divisor = int(args[1])
	if divisor == 0:
		push_error("SEXP '%' division by zero.")
		return SexpConstants.SEXP_CANT_EVAL
	# Use fposmod for float behavior consistent with % in GDScript if needed,
	# but original likely used integer modulo.
	return int(args[0]) % divisor

func _op_random(args: Array, context: Dictionary) -> Variant:
	# Args: [max_exclusive] or [min_inclusive, max_exclusive]
	var min_val = 0
	var max_val = 0
	if args.size() == 1:
		if not _are_args_numeric(args, "rand (1 arg)"): return SexpConstants.SEXP_CANT_EVAL
		max_val = int(args[0])
	elif args.size() == 2:
		if not _are_args_numeric(args, "rand (2 args)"): return SexpConstants.SEXP_CANT_EVAL
		min_val = int(args[0])
		max_val = int(args[1])
	else:
		push_error("SEXP 'rand' requires 1 or 2 arguments, got %d." % args.size())
		return SexpConstants.SEXP_CANT_EVAL

	if min_val >= max_val:
		push_warning("SEXP 'rand' max value must be greater than min value.")
		return min_val # Return min if range is invalid?

	# randi() % N produces numbers from 0 to N-1
	# randi_range(min, max) produces numbers from min to max (inclusive)
	# FS2 rand() likely returned 0 to N-1.
	if args.size() == 1:
		if max_val <= 0: return 0 # Avoid modulo by zero or negative
		return randi() % max_val
	else:
		# Ensure max_val is at least min_val + 1 for randi_range
		if max_val <= min_val: max_val = min_val + 1
		return randi_range(min_val, max_val - 1) # randi_range is inclusive, FS2 rand was likely exclusive max

func _op_absolute(args: Array, context: Dictionary) -> Variant:
	# Args: [number]
	if args.size() != 1:
		push_error("SEXP 'abs' requires 1 argument, got %d." % args.size())
		return SexpConstants.SEXP_CANT_EVAL
	if not _are_args_numeric(args, "abs"):
		return SexpConstants.SEXP_CANT_EVAL
	return abs(float(args[0]))


# --- Status Operators ---
func _op_is_destroyed(args: Array, context: Dictionary) -> int:
	# Args: [ship_or_wing_name: String]
	if args.size() != 1 or not args[0] is String:
		push_error("SEXP 'is-destroyed': Requires 1 string argument (ship/wing name).")
		return SexpConstants.SEXP_CANT_EVAL
	var target_name: String = args[0]

	if not MissionManager:
		push_error("SEXP 'is-destroyed': MissionManager not available.")
		return SexpConstants.SEXP_CANT_EVAL

	# Assume MissionManager has a function to resolve names (ship or wing) to objects
	# This function needs to be implemented in MissionManager.
	var objects: Array = MissionManager.resolve_name_to_objects(target_name)

	if objects.is_empty():
		# If the target name doesn't resolve to any *currently existing* objects,
		# FS2 likely considers it "destroyed" in the context of mission goals.
		# print("SEXP 'is-destroyed': Target '%s' not found, assuming destroyed." % target_name) # Debug
		return SexpConstants.SEXP_TRUE

	for obj in objects:
		# Assuming objects have an 'is_destroyed()' method (e.g., in BaseObject or ShipBase)
		if is_instance_valid(obj) and obj.has_method("is_destroyed") and not obj.is_destroyed():
			# If any object resolved from the name is *not* destroyed, the condition is false.
			return SexpConstants.SEXP_FALSE

	# If we reach here, all resolved objects were either invalid or destroyed.
	return SexpConstants.SEXP_TRUE

func _op_distance(args: Array, context: Dictionary) -> Variant:
	# Args: [obj1_name: String, obj2_name: String]
	if args.size() != 2 or not args[0] is String or not args[1] is String:
		push_error("SEXP 'distance': Requires 2 string arguments (object names).")
		return SexpConstants.SEXP_CANT_EVAL
	var name1: String = args[0]
	var name2: String = args[1]

	if not ObjectManager: # Use ObjectManager for direct name lookup if possible
		push_error("SEXP 'distance': ObjectManager not available.")
		return SexpConstants.SEXP_CANT_EVAL

	# Assume ObjectManager has get_object_by_name (needs implementation)
	# This should return a single Node3D or null.
	var obj1 = ObjectManager.get_object_by_name(name1)
	var obj2 = ObjectManager.get_object_by_name(name2)

	if not is_instance_valid(obj1) or not is_instance_valid(obj2):
		# If either object isn't found or valid, the distance is unknown/undefined.
		push_warning("SEXP 'distance': Could not find one or both objects ('%s', '%s')." % [name1, name2])
		return SexpConstants.SEXP_UNKNOWN

	if not obj1 is Node3D or not obj2 is Node3D:
		push_error("SEXP 'distance': Objects '%s' or '%s' are not Node3D." % [name1, name2])
		return SexpConstants.SEXP_CANT_EVAL

	# Return the distance between their global positions.
	return obj1.global_position.distance_to(obj2.global_position)

func _op_mission_time(args: Array, context: Dictionary) -> Variant:
	# Args: None
	if not args.is_empty():
		push_warning("SEXP 'mission-time': Takes no arguments.")
	if GameManager and GameManager.has_method("get_mission_time"):
		return GameManager.get_mission_time() # Returns float
	else:
		push_error("SEXP 'mission-time': GameManager not available or lacks get_mission_time().")
		return SexpConstants.SEXP_UNKNOWN

func _op_hits_left(args: Array, context: Dictionary) -> Variant:
	# Args: [ship_or_wing_name: String]
	if args.size() != 1 or not args[0] is String:
		push_error("SEXP 'hits-left': Requires 1 string argument (ship/wing name).")
		return SexpConstants.SEXP_CANT_EVAL
	var target_name: String = args[0]

	if not MissionManager:
		push_error("SEXP 'hits-left': MissionManager not available.")
		return SexpConstants.SEXP_CANT_EVAL

	var objects: Array = MissionManager.resolve_name_to_objects(target_name)

	if objects.is_empty():
		# If name doesn't resolve, hits are effectively 0 or unknown?
		push_warning("SEXP 'hits-left': Target '%s' not found." % target_name)
		return SexpConstants.SEXP_UNKNOWN # Or 0.0?

	var total_hits: float = 0.0
	for obj in objects:
		# Assuming objects have a 'current_hull_strength' property or 'get_hull_strength()' method
		if is_instance_valid(obj):
			if obj.has_method("get_hull_strength"):
				total_hits += obj.get_hull_strength()
			elif obj.has("current_hull_strength"): # Fallback check for property
				total_hits += obj.current_hull_strength
			else:
				push_warning("SEXP 'hits-left': Object '%s' lacks hull strength info." % obj.name if obj.has("name") else "Unknown")

	return total_hits

func _op_hits_left_subsystem(args: Array, context: Dictionary) -> Variant:
	# Args: [ship_name: String, subsystem_name: String]
	if args.size() != 2 or not args[0] is String or not args[1] is String:
		push_error("SEXP 'hits-left-subsystem': Requires 2 string arguments (ship, subsystem).")
		return SexpConstants.SEXP_CANT_EVAL
	var ship_name: String = args[0]
	var subsys_name: String = args[1]

	if not ObjectManager:
		push_error("SEXP 'hits-left-subsystem': ObjectManager not available.")
		return SexpConstants.SEXP_CANT_EVAL

	var ship = ObjectManager.get_object_by_name(ship_name)

	if not is_instance_valid(ship):
		push_warning("SEXP 'hits-left-subsystem': Ship '%s' not found." % ship_name)
		return SexpConstants.SEXP_UNKNOWN

	# Assuming ShipBase has a method to get a subsystem node by name
	if not ship.has_method("get_subsystem_by_name"):
		push_error("SEXP 'hits-left-subsystem': Ship '%s' lacks get_subsystem_by_name()." % ship_name)
		return SexpConstants.SEXP_CANT_EVAL

	var subsystem = ship.get_subsystem_by_name(subsys_name)

	if not is_instance_valid(subsystem):
		# If subsystem doesn't exist on the ship, hits are 0 or unknown?
		push_warning("SEXP 'hits-left-subsystem': Subsystem '%s' not found on ship '%s'." % [subsys_name, ship_name])
		return SexpConstants.SEXP_UNKNOWN # Or 0.0?

	# Assuming subsystem node script (e.g., ShipSubsystem) has 'current_hits' property or 'get_health()' method
	if subsystem.has_method("get_health"):
		return subsystem.get_health()
	elif subsystem.has("current_hits"):
		return subsystem.current_hits
	else:
		push_error("SEXP 'hits-left-subsystem': Subsystem '%s' on '%s' lacks health info." % [subsys_name, ship_name])
		return SexpConstants.SEXP_UNKNOWN


# --- Change Operators ---
func _op_send_message(args: Array, context: Dictionary) -> int:
	# Args: [message_name: String, who_from: String, priority: int, ...] (optional args depend on message)
	if args.size() < 3 or not args[0] is String or not args[1] is String or not (args[2] is int or args[2] is float):
		push_error("'send-message' requires at least 3 arguments (message_name, who_from, priority).")
		return SexpConstants.SEXP_CANT_EVAL
	var message_name: String = args[0]
	var who_from: String = args[1]
	var priority: int = int(args[2])
	# TODO: Extract optional arguments based on message type if needed
	# TODO: Call MessageManager.send_mission_message(message_name, who_from, priority, ...)
	if MessageManager:
		# MessageManager.send_mission_message(message_name, who_from, priority) # Simplified call
		push_warning("SEXP 'send-message' call to MessageManager not fully implemented.")
	else:
		push_error("MessageManager not available for 'send-message'.")
		return SexpConstants.SEXP_CANT_EVAL
	return SexpConstants.SEXP_TRUE # Actions usually return true

func _op_add_goal(args: Array, context: Dictionary) -> int:
	# Args: [goal_type: String, goal_name: String, ...] (complex args depending on type)
	if args.size() < 2 or not args[0] is String or not args[1] is String:
		push_error("'add-goal' requires at least 2 string arguments (goal_type, goal_name).")
		return SexpConstants.SEXP_CANT_EVAL
	var goal_type: String = args[0]
	var goal_name: String = args[1]
	# TODO: Parse remaining arguments based on goal_type
	# TODO: Call MissionManager.add_mission_goal(...)
	if MissionManager:
		# MissionManager.add_mission_goal(goal_type, goal_name, ...) # Simplified call
		push_warning("SEXP 'add-goal' call to MissionManager not fully implemented.")
	else:
		push_error("MissionManager not available for 'add-goal'.")
		return SexpConstants.SEXP_CANT_EVAL
	return SexpConstants.SEXP_TRUE

func _op_modify_variable(args: Array, context: Dictionary) -> int:
	# Args: [variable_name, operation, value]
	if args.size() != 3:
		push_error("'modify-variable' requires 3 arguments.")
		return SexpConstants.SEXP_CANT_EVAL
	if not args[0] is String or not args[0].begins_with("@"):
		push_error("'modify-variable' first argument must be a variable name string (starting with @).")
		return SexpConstants.SEXP_CANT_EVAL
	if not args[1] is String: # Operation: '=', '+', '-', '*', '/'
		push_error("'modify-variable' second argument must be an operation string.")
		return SexpConstants.SEXP_CANT_EVAL

	var var_name: String = args[0]
	var operation: String = args[1]
	var new_value_part = args[2] # Can be string or number

	var current_value = SexpVariableManager.get_variable(var_name)
	var final_value = null

	match operation:
		"=":
			final_value = new_value_part
		"+", "-", "*", "/":
			if current_value == null: current_value = 0.0 # Default to 0 if not set
			if not (current_value is float or current_value is int):
				push_error("'modify-variable' cannot perform arithmetic on non-number variable '%s'." % var_name)
				return SexpConstants.SEXP_CANT_EVAL
			if not (new_value_part is float or new_value_part is int):
				push_error("'modify-variable' cannot perform arithmetic with non-number value.")
				return SexpConstants.SEXP_CANT_EVAL

			var current_num = float(current_value)
			var new_num_part = float(new_value_part)

			match operation:
				"+": final_value = current_num + new_num_part
				"-": final_value = current_num - new_num_part
				"*": final_value = current_num * new_num_part
				"/":
					if new_num_part == 0.0:
						push_error("Division by zero in 'modify-variable'.")
						return SexpConstants.SEXP_CANT_EVAL
					final_value = current_num / new_num_part
		_:
			push_error("Unknown operation '%s' in 'modify-variable'." % operation)
			return SexpConstants.SEXP_CANT_EVAL

	# Determine persistence (default to mission local if variable doesn't exist)
	var type_flags = SexpVariableManager.get_variable_type_flags(var_name)
	if type_flags == -1: # Variable doesn't exist, default persistence
		type_flags = 0 # Mission local

	SexpVariableManager.set_variable(var_name, final_value, type_flags)
	return SexpConstants.SEXP_TRUE

func _op_end_mission(args: Array, context: Dictionary) -> int:
	# Args: None
	if not args.is_empty():
		push_warning("'end-mission' takes no arguments.")
	# TODO: Call MissionManager.request_end_mission() or similar
	if MissionManager:
		# MissionManager.request_end_mission()
		push_warning("SEXP 'end-mission' call to MissionManager not fully implemented.")
	else:
		push_error("MissionManager not available for 'end-mission'.")
		return SexpConstants.SEXP_CANT_EVAL
	return SexpConstants.SEXP_TRUE

# --- Conditional Operators ---
func _op_when(args: Array[SexpNode], context: Dictionary) -> int:
	# Args: [condition_sexp, action_sexp]
	# Lazy evaluation: only evaluate action if condition is true
	if args.size() != 2:
		push_error("'when' requires 2 arguments.")
		return SexpConstants.SEXP_CANT_EVAL

	var evaluator = context.get("evaluator")
	if evaluator == null:
		push_error("'when' operator requires evaluator in context for lazy evaluation.")
		return SexpConstants.SEXP_CANT_EVAL

	if evaluator.is_sexp_true(args[0], context):
		# Condition is true, evaluate the action
		return evaluator.eval_sexp(args[1], context)
	else:
		# Condition is false, do nothing, return false? Unknown?
		return SexpConstants.SEXP_UNKNOWN # Or SEXP_FALSE? Check FS2 behavior

func _op_every_time(args: Array[SexpNode], context: Dictionary) -> int:
	# Args: [action_sexp]
	# Always evaluates the action sexp
	if args.size() != 1:
		push_error("'every-time' requires 1 argument.")
		return SexpConstants.SEXP_CANT_EVAL

	var evaluator = context.get("evaluator")
	if evaluator == null:
		push_error("'every-time' operator requires evaluator in context for lazy evaluation.")
		return SexpConstants.SEXP_CANT_EVAL

	# Evaluate the action and return its result
	return evaluator.eval_sexp(args[0], context)


# --- AI Operators ---
func _op_ai_chase(args: Array, context: Dictionary) -> int:
	# Args: [ship_to_order: String, target_to_chase: String]
	if args.size() != 2 or not args[0] is String or not args[1] is String:
		push_error("'ai-chase' requires 2 string arguments (ship_name, target_name).")
		return SexpConstants.SEXP_CANT_EVAL
	var ship_name: String = args[0]
	var target_name: String = args[1]
	# TODO: Need ObjectManager/MissionManager to resolve names
	# TODO: Need to get AIController for the ship and add the goal
	# Example conceptual logic:
	# var ship = MissionManager.resolve_name_to_objects(ship_name).front() # Assuming single ship
	# var target = MissionManager.resolve_name_to_objects(target_name).front()
	# if is_instance_valid(ship) and is_instance_valid(target) and ship.has_method("get_ai_controller"):
	#	 var ai_controller = ship.get_ai_controller()
	#	 if ai_controller:
	#		 ai_controller.add_goal(AIGoal.new(AIConstants.AI_GOAL_CHASE, target)) # Need AIGoal resource/class
	#	 else: return SexpConstants.SEXP_CANT_EVAL
	# else: return SexpConstants.SEXP_CANT_EVAL
	push_warning("SEXP 'ai-chase' not fully implemented.")
	return SexpConstants.SEXP_TRUE # AI Orders return true

func _op_ai_waypoints(args: Array, context: Dictionary) -> int:
	# Args: [ship_to_order: String, waypoint_list_name: String]
	if args.size() != 2 or not args[0] is String or not args[1] is String:
		push_error("'ai-waypoints' requires 2 string arguments (ship_name, waypoint_list_name).")
		return SexpConstants.SEXP_CANT_EVAL
	var ship_name: String = args[0]
	var wp_list_name: String = args[1]
	# TODO: Need ObjectManager/MissionManager to resolve ship name
	# TODO: Need MissionManager/WaypointManager to get waypoint list data
	# TODO: Need to get AIController for the ship and add the goal
	# Example conceptual logic:
	# var ship = MissionManager.resolve_name_to_objects(ship_name).front()
	# if is_instance_valid(ship) and ship.has_method("get_ai_controller"):
	#	 var ai_controller = ship.get_ai_controller()
	#	 if ai_controller:
	#		 ai_controller.add_goal(AIGoal.new(AIConstants.AI_GOAL_WAYPOINTS, null, wp_list_name)) # Need AIGoal resource/class
	#	 else: return SexpConstants.SEXP_CANT_EVAL
	# else: return SexpConstants.SEXP_CANT_EVAL
	push_warning("SEXP 'ai-waypoints' not fully implemented.")
	return SexpConstants.SEXP_TRUE # AI Orders return true

# --- Add many more operator handlers here ---
