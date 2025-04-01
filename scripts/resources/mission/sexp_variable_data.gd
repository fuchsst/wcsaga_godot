# scripts/resources/sexp_variable_data.gd
# Defines an initial SEXP variable value for a mission.
# Corresponds to C++ 'sexp_variable' struct elements used in parsing.
class_name SEXPVariableData
extends Resource

@export var variable_name: String = "" # e.g., "@MyVariable"
@export var initial_value: String = "" # Stored as string, parsed later
@export var type_flags: int = 0 # Bitmask: SEXP_VARIABLE_NUMBER, SEXP_VARIABLE_STRING, SEXP_VARIABLE_PERSISTENT etc.
