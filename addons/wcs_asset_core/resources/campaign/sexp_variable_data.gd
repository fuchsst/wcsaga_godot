class_name SexpVariableData
extends Resource

## WCS SEXP variable data for campaign state persistence.

@export var name: String = ""
@export var value: Variant = 0
@export var type: String = "number"

func _init() -> void:
	"""Initialize SEXP variable data resource."""
	resource_name = "SexpVariableData"