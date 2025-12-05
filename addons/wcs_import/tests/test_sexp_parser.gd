@tool
extends SceneTree

const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpNode = preload("res://scripts/resources/sexp/sexp_node.gd")

func _init():
	_test_basic_parsing()
	_test_nested_parsing()
	_test_variables()
	quit()

func _test_basic_parsing():
	var input = "( true )"
	var result = SexpParser.parse(input)
	_assert(result != null, "Result should not be null")
	_assert(result.type == SexpNode.Type.OPERATOR, "Root type should be OPERATOR")
	_assert(result.value == "true", "Operator should be 'true'")
	print("Basic parsing passed")

func _test_nested_parsing():
	var input = "( when ( is-destroyed \"Alpha 1\" ) ( true ) )"
	var result = SexpParser.parse(input)
	_assert(result.value == "when")
	_assert(result.arguments.size() == 2)
	_assert(result.arguments[0].type == SexpNode.Type.OPERATOR)
	_assert(result.arguments[0].value == "is-destroyed")
	_assert(result.arguments[0].arguments[0].value == "Alpha 1")
	print("Nested parsing passed")

func _test_variables():
	var input = "( = @Var[0] 10 )"
	var result = SexpParser.parse(input)
	_assert(result.value == "=")
	_assert(result.arguments[0].type == SexpNode.Type.VARIABLE)
	_assert(result.arguments[0].value == "@Var[0]")
	_assert(result.arguments[1].value == 10)
	print("Variable parsing passed")

func _assert(condition: bool, msg: String = ""):
	if not condition:
		printerr("ASSERTION FAILED: " + msg)
		quit(1)
