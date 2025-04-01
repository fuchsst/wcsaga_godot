# sexp_node.gd
# Represents a node in the S-Expression tree. Can be either a list (containing
# other nodes) or an atom (operator, number, or string).
# This Resource can be saved/loaded to represent parsed mission logic.
class_name SexpNode
extends Resource

# Import constants for type definitions
const SexpConstants = preload("res://scripts/scripting/sexp/sexp_constants.gd")

# --- Exported Properties ---

## The type of this node (SEXP_LIST or SEXP_ATOM).
@export var node_type: int = SexpConstants.SEXP_NOT_USED:
	set(value):
		node_type = value
		notify_property_list_changed() # Update inspector based on type

## If node_type is SEXP_ATOM, this specifies the subtype
## (SEXP_ATOM_OPERATOR, SEXP_ATOM_NUMBER, SEXP_ATOM_STRING).
@export var atom_subtype: int = SexpConstants.SEXP_ATOM_LIST:
	set(value):
		atom_subtype = value
		notify_property_list_changed() # Update inspector based on subtype

## The textual representation of the atom (operator name, number as string, or string content).
## Only relevant if node_type is SEXP_ATOM.
@export var text: String = ""

## The integer code for the operator.
## Only relevant if atom_subtype is SEXP_ATOM_OPERATOR.
@export var op_code: int = -1

## An array containing child SexpNode resources.
## Only relevant if node_type is SEXP_LIST.
@export var children: Array[SexpNode] = []


# --- Helper Methods ---

func is_list() -> bool:
	return node_type == SexpConstants.SEXP_LIST

func is_atom() -> bool:
	return node_type == SexpConstants.SEXP_ATOM

func is_operator() -> bool:
	return is_atom() and atom_subtype == SexpConstants.SEXP_ATOM_OPERATOR

func is_number() -> bool:
	return is_atom() and atom_subtype == SexpConstants.SEXP_ATOM_NUMBER

func is_string() -> bool:
	return is_atom() and atom_subtype == SexpConstants.SEXP_ATOM_STRING

func get_operator() -> int:
	if is_operator():
		return op_code
	return -1 # Or some invalid code

func get_number_value() -> float:
	if is_number():
		return text.to_float()
	push_warning("Attempted to get number value from non-number SexpNode")
	return 0.0 # Or NaN?

func get_string_value() -> String:
	if is_string():
		# Need to handle potential escaping if strings were stored with quotes
		# For now, assume 'text' holds the direct string content.
		return text
	push_warning("Attempted to get string value from non-string SexpNode")
	return ""

func get_child_count() -> int:
	if is_list():
		return children.size()
	return 0

func get_child(index: int) -> SexpNode:
	if is_list() and index >= 0 and index < children.size():
		return children[index]
	push_error("Invalid child index requested for SexpNode")
	return null

# --- Inspector Property Handling ---
# Hide irrelevant properties in the Godot Inspector based on node type/subtype.

func _get_property_list() -> Array:
	var properties: Array = []

	properties.append({
		"name": "node_type",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Not Used:%d,List:%d,Atom:%d" % [SexpConstants.SEXP_NOT_USED, SexpConstants.SEXP_LIST, SexpConstants.SEXP_ATOM]
	})

	if node_type == SexpConstants.SEXP_ATOM:
		properties.append({
			"name": "atom_subtype",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "List:%d,Operator:%d,Number:%d,String:%d" % [SexpConstants.SEXP_ATOM_LIST, SexpConstants.SEXP_ATOM_OPERATOR, SexpConstants.SEXP_ATOM_NUMBER, SexpConstants.SEXP_ATOM_STRING]
		})
		properties.append({
			"name": "text",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		if atom_subtype == SexpConstants.SEXP_ATOM_OPERATOR:
			properties.append({
				"name": "op_code",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT
				# TODO: Could add hint_string with operator names if feasible
			})
	elif node_type == SexpConstants.SEXP_LIST:
		properties.append({
			"name": "children",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ARRAY_TYPE,
			"hint_string": "%s/%s:%s" % [Variant.Type.OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "SexpNode"] # Specify array holds SexpNode resources
		})

	return properties
