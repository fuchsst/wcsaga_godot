# scripts/resources/mission_objective_data.gd
# Defines a mission objective (goal).
# Corresponds to the C++ 'mission_goal' struct.
class_name MissionObjectiveData
extends Resource

# --- Nested Resource Definition ---
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Assuming SexpNode exists

# --- Goal Definition ---
@export var name: String = "" # Unique name for the goal
@export var type: int = 0 # Enum: PRIMARY_GOAL, SECONDARY_GOAL, BONUS_GOAL (potentially combined with INVALID_GOAL flag)
@export var message: String = "" # Text description of the goal
@export var formula_sexp: SexpNode = null # SEXP node for completion/failure condition
@export var flags: int = 0 # Bitmask using GlobalConstants.MGF_* (e.g., MGF_NO_MUSIC)
@export var score: int = 0 # Score awarded upon completion
@export var team: int = 0 # Team this goal applies to (0 for all in single player)

# --- Runtime State (Managed by MissionManager) ---
# These are not exported, they are set during gameplay
var satisfied: int = GlobalConstants.GOAL_INCOMPLETE # Enum: GOAL_INCOMPLETE, GOAL_COMPLETE, GOAL_FAILED
