# scripts/resources/alt_class_data.gd
# Defines an alternate ship class entry for dynamic assignment.
class_name AltClassData
extends Resource

@export var ship_class_index: int = -1 # Index into GlobalConstants ship list
@export var variable_index: int = -1 # SEXP variable index controlling this class (if any)
@export var default_to_this_class: bool = false # If this is the default alternate class
