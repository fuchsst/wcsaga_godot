# scripts/resources/mission/wing_instance_data.gd
# Represents a wing definition from the mission file.
# Corresponds to the C++ 'wing' struct.
class_name WingInstanceData
extends Resource

# --- Nested Resource Definitions ---
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const AIGoal = preload("res://scripts/resources/ai/ai_goal.gd")

# --- Wing Properties ---
@export var wing_name: String = ""
@export var num_waves: int = 1
@export var wave_threshold: int = 0 # Number of ships remaining to trigger next wave
@export var special_ship_index: int = 0 # Index of the 'special' ship in the wing list (relative to original parsed list)
@export var flags: int = 0 # Corresponds to WF_* flags
@export var hotkey: int = -1 # 0-9 for F5-F12, -1 for none
@export var squad_logo_filename: String = "" # Path to squad logo texture

# --- Arrival / Departure ---
@export var arrival_location: int = 0 # Enum: ARRIVE_AT_LOCATION, etc.
@export var arrival_distance: int = 0
@export var arrival_anchor_name: String = "" # Name of anchor object/waypoint
@export var arrival_path_name: String = "" # Name of the path restriction (if any)
@export var arrival_cue_sexp: SexpNode = null # SexpNode resource
@export var arrival_delay_ms: int = 0 # Delay in milliseconds after cue is true

@export var departure_location: int = 0 # Corresponds to DEPARTURE_* enum
@export var departure_anchor_name: String = "" # Name of anchor object/waypoint
@export var departure_path_name: String = "" # Name of the path restriction (if any)
@export var departure_cue_sexp: SexpNode = null # SexpNode resource
@export var departure_delay_ms: int = 0 # Delay in milliseconds after cue is true

# --- Wave Timing ---
@export var wave_delay_min: int = 0 # Milliseconds
@export var wave_delay_max: int = 0 # Milliseconds

# --- Ships & Goals ---
# Array of ship names belonging to this wing (references ShipInstanceData by name)
@export var ship_names: Array[String] = []
# Array of AIGoal resources applied to all ships in the wing
@export var ai_goals: Array[AIGoal] = []

# --- Wing Statistics (QA REMEDIATION - missing from original C++ wing struct) ---
@export var total_destroyed: int = 0 # Ships destroyed count
@export var total_departed: int = 0 # Ships departed count  
@export var total_vanished: int = 0 # Ships vanished count
