class_name SexpNode extends Resource

enum Type {
	OPERATOR,
	STRING,
	NUMBER,
	BOOLEAN,
	VARIABLE,
	UNKNOWN
}

@export var type: Type = Type.UNKNOWN
@export var value: Variant
@export var arguments: Array[SexpNode] = []

func _init(p_type: Type = Type.UNKNOWN, p_value: Variant = null) -> void:
	type = p_type
	value = p_value

func add_argument(arg: SexpNode) -> void:
	arguments.append(arg)

func _to_string() -> String:
	var s = ""
	match type:
		Type.OPERATOR: s = "(" + str(value)
		Type.STRING: return "\"" + str(value) + "\""
		_: return str(value)
	
	for arg in arguments:
		s += " " + arg.to_string()
	
	s += ")"
	return s
