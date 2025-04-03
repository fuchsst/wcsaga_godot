# scripts/resources/mission/mission_objective_data.gd
# Defines a mission objective (goal).
# Corresponds to the C++ 'mission_goal' struct.
class_name MissionObjectiveData
extends Resource

# --- Nested Resource Definition ---
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Assuming SexpNode exists

# --- Goal Definition ---
@export var objective_name: String = "" # Unique name for the goal
@export var objective_type: int = 0 # Enum: PRIMARY_GOAL, SECONDARY_GOAL, BONUS_GOAL (potentially combined with INVALID_GOAL flag)
@export var message: String = "" # Text description of the goal
@export var formula: SexpNode = null # SEXP node for completion/failure condition
@export var flags: int = 0 # Bitmask using GlobalConstants.MGF_* (e.g., MGF_NO_MUSIC)
@export var score: int = 0 # Score awarded upon completion
@export var team: int = 0 # Team this goal applies to (0 for all in single player)
