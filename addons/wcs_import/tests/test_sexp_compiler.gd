@tool
extends SceneTree

const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpCompiler = preload("res://addons/wcs_import/sexp/sexp_compiler.gd")
const BTSexpConditionRef = preload("res://scripts/core/behavior_tree/tasks/bt_sexp_condition.gd")

func _init():
	_test_compile_sequence()
	quit()

func _test_compile_sequence():
	var input = "( and ( true ) ( false ) )"
	var ast = SexpParser.parse(input)
	var bt = SexpCompiler.compile(ast)
	
	_assert(bt != null, "BehaviorTree should not be null")
	_assert(bt.root_task != null, "Root task should not be null")
	
	# Check root type (generic check, we expect BTSequence)
	# Since BTSequence is a class, we can check get_class() or is_instance
	print("Root task class: ", bt.root_task.get_class())
	_assert(bt.root_task.get_child_count() == 2, "Should have 2 children")
	
func _assert(condition: bool, msg: String = ""):
	if not condition:
		printerr("ASSERTION FAILED: " + msg)
		quit(1)
