@tool
extends RefCounted
class_name SexpDefinitions

const OPS = {
	# Logical / Structural
	"and": {"type": "logic", "bt_type": "BTSequence"},
	"or": {"type": "logic", "bt_type": "BTSelector"},
	"not": {"type": "logic", "bt_type": "BTInverter"},
	"when": {"type": "special", "handler": "_compile_when"},
	"cond": {"type": "special", "handler": "_compile_cond"},
	
	# Conditions (Atoms that return boolean)
	"true": {"type": "condition"},
	"false": {"type": "condition"},
	"is-destroyed": {"type": "condition"},
	"has-arrived-delay": {"type": "condition"},
	"is-event-true-delay": {"type": "condition"},
	"=": {"type": "condition"},
	"<": {"type": "condition"},
	">": {"type": "condition"},

	# Actions (Atoms that do something / return void usually)
	"do-nothing": {"type": "action"},
	"training-msg": {"type": "action"},
	"send-message": {"type": "action"},
	"add-goal": {"type": "action"},
	"next-mission": {"type": "action"},
	"end-of-campaign": {"type": "action"}
}

static func get_op(name: String) -> Dictionary:
	return OPS.get(name, {"type": "unknown"})
