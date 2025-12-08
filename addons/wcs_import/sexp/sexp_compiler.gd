@tool
extends RefCounted
class_name SexpCompiler

const SexpNodeRef = preload("res://scripts/resources/sexp/sexp_node.gd")
const SexpDefs = preload("res://addons/wcs_import/sexp/sexp_definitions.gd")
const BTSexpConditionRef = preload("res://scripts/ai/behavior_tree/tasks/bt_sexp_condition.gd")
const BTSexpActionRef = preload("res://scripts/ai/behavior_tree/tasks/bt_sexp_action.gd")

static func compile(root_node: Resource) -> BehaviorTree:
	if not root_node:
		return null
	
	var bt = BehaviorTree.new()
	bt.root_task = _compile_node(root_node)
	return bt

static func _compile_node(node: Resource) -> BTTask:
	if node.type != SexpNodeRef.Type.OPERATOR:
		# Literals shouldn't be reached here as standalone tasks usually?
		# Actually, 'true' is an atom but handled as condition.
		# If we have a literal here, it might be an error or a constant check?
		# For now, return a generic condition that checks equality to value?
		# No, literals are arguments usually.
		# SEXP format: ( operator arg1 arg2 ... )
		# The root is always an operator or a list.
		push_warning("SexpCompiler: Reached non-operator node in compilation: " + str(node.value))
		return null

	var op_name = str(node.value)
	var op_def = SexpDefs.get_op(op_name)
	var type = op_def.get("type", "unknown")
	
	if type == "logic":
		var bt_type = op_def.get("bt_type")
		if bt_type == null:
			push_error("SexpCompiler: Missing bt_type for operator: " + op_name)
			return null
		var task = ClassDB.instantiate(bt_type) as BTTask
		if task == null:
			push_error("SexpCompiler: Failed to instantiate class: " + str(bt_type))
			return null
		for arg in node.arguments:
			var child_task = _compile_node(arg)
			if child_task:
				task.add_child(child_task)
		return task
		
	elif type == "special":
		if op_name == "when":
			return _compile_when(node)
		elif op_name == "cond":
			return _compile_cond(node)
			
	elif type == "condition":
		var task = BTSexpConditionRef.new()
		task.operator_id = op_name
		task.arguments = _extract_args(node.arguments)
		return task

	elif type == "action":
		var task = BTSexpActionRef.new()
		task.operator_id = op_name
		task.arguments = _extract_args(node.arguments)
		return task
	
	else:
		# Unknown operator, treat as Action by default? Or Error?
		var task = BTSexpActionRef.new()
		task.operator_id = op_name
		task.arguments = _extract_args(node.arguments)
		return task
		
	return null

static func _compile_when(node: Resource) -> BTTask:
	# ( when ( Condition ) ( Action1 ) ( Action2 ) ... )
	# In BT: Selector [ Sequence [Condition, Sequence[Actions]] ]?
	# LimboAI: If we want it to execute actions if condition is true...
	# BTSelector checks children. If child 1 fails, tries child 2.
	# IF we parse 'when' as: "If condition is met, do actions".
	# If condition is not met, fail?
	# 'when' in SEXP is often an event trigger.
	# "When this becomes true, do this."
	# In a BT running every tick:
	# Sequence [ Condition, Action ]
	# If condition false -> Sequence Fails -> Tree continues?
	var seq = ClassDB.instantiate("BTSequence") as BTTask
	if seq == null:
		push_error("SexpCompiler: BTSequence class not found. LimboAI may not be installed.")
		return null
	seq.custom_name = "When " + _get_arg_preview(node.arguments, 0)

	for arg in node.arguments:
		var child = _compile_node(arg)
		if child:
			seq.add_child(child)

	return seq

static func _compile_cond(node: Resource) -> BTTask:
	# ( cond ( (Cond1) (Action1) ) ( (Cond2) (Action2) ) ... )
	# Like a Switch or If/ElseIf chain.
	# In BT: Selector [ Sequence[Cond1, Act1], Sequence[Cond2, Act2] ... ]
	var sel = ClassDB.instantiate("BTSelector") as BTTask
	if sel == null:
		push_error("SexpCompiler: BTSelector class not found. LimboAI may not be installed.")
		return null
	sel.custom_name = "Cond"

	for arg in node.arguments:
		# Each arg is a list ( (Cond) (Next-Mission) )
		if arg.type == SexpNodeRef.Type.OPERATOR:
			# Implicit Sequence?
			# Actually in SEXP, the list wrapper is just a list.
			# We treat it as a Sequence.
			var sub_seq = ClassDB.instantiate("BTSequence") as BTTask
			if sub_seq == null:
				push_error("SexpCompiler: BTSequence class not found. Skipping sub-sequence.")
				continue
			for sub_arg in arg.arguments:
				var sub_child = _compile_node(sub_arg)
				if sub_child:
					sub_seq.add_child(sub_child)
			sel.add_child(sub_seq)

	return sel

static func _extract_args(arg_nodes: Array) -> Array:
	var args = []
	for node in arg_nodes:
		if node.type == SexpNodeRef.Type.OPERATOR:
			# Nested operator as argument? 
			# e.g. ( is-destroyed ( argument-that-calculates-ship-name ) )
			# OR ( distance "Alpha 1" "Alpha 2" )
			# If the argument is an operator, it evaluates to a value?
			# Implementation complexity: We need EVALUATOR tasks vs RUNNER tasks.
			# But for now, we just store the SexpNode/Tree as the argument?
			# Or we assume arguments are literals for this pass.
			# If it's an operator, we might need a Subtree or just keep it as SexpNode for the Task to evaluate.
			# Let's keep the reference to the SexpNode resource!
			args.append(node)
		else:
			args.append(node.value)
	return args

static func _get_arg_preview(args: Array, idx: int) -> String:
	if idx < args.size():
		var node = args[idx]
		if node.type == SexpNodeRef.Type.STRING:
			return str(node.value)
		elif node.type == SexpNodeRef.Type.OPERATOR:
			return "(" + str(node.value) + "...)"
	return ""
