# scripts/resources/alt_class_data.gd
# Defines an alternate ship class entry for dynamic assignment.
class_name AltClassData
extends Resource

@export var ship_class_name: String = "" # Name of the ShipData resource
@export var variable_name: String = "" # SEXP variable name controlling this class (if any)
@export var is_default: bool = false # If this is the default alternate class
