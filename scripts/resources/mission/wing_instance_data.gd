# scripts/resources/wing_instance_data.gd
# Represents a wing definition from the mission file.
# Corresponds to the C++ 'wing' struct.
class_name WingInstanceData
extends Resource

# --- Nested Resource Definitions ---
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Assuming SexpNode exists
const AIGoal = preload("ai_goal.gd") # Assuming AIGoal resource exists

# --- Wing Properties ---
@export var name: String = ""
@export var num_waves: int = 1
@export var wave_threshold: int = 0 # Number of ships needed before next wave arrives
@export var special_ship_index: int = 0 # Index of the 'special' ship in the wing list (relative to original parsed list)
@export var flags: int = 0 # Bitmask using GlobalConstants.WF_*
@export var hotkey: int = -1 # 0-9 for F5-F12, -1 for none
@export var squad_logo_texture_path: String = "" # Path to squad logo texture

# --- Arrival / Departure ---
@export var arrival_location: int = 0 # Enum: ARRIVE_AT_LOCATION, etc.
@export var arrival_distance: int = 0
@export var arrival_anchor_name: String = "" # Name of anchor object/waypoint
@export var arrival_path_mask: int = -1 # Bitmask for docking paths
@export var arrival_cue_sexp: SexpNode = null # SEXP node for arrival condition
@export var arrival_delay_seconds: int = 0 # Delay in seconds after cue is true

@export var departure_location: int = 0 # Enum: DEPART_AT_LOCATION, etc.
@export var departure_anchor_name: String = "" # Name of anchor object/waypoint
@export var departure_path_mask: int = -1 # Bitmask for docking paths
@export var departure_cue_sexp: SexpNode = null # SEXP node for departure condition
@export var departure_delay_seconds: int = 0 # Delay in seconds after cue is true

# --- Wave Timing ---
@export var wave_delay_min_seconds: int = 0
@export var wave_delay_max_seconds: int = 0

# --- Ships & Goals ---
# Array of ship names belonging to this wing (references ShipInstanceData by name)
@export var ship_names: Array[String] = []
# Array of AIGoal resources applied to all ships in the wing
@export var ai_goals: Array[AIGoal] = []

# --- Runtime Info ---
@export var net_signature: int = 0 # Base signature for wing ships in multiplayer
