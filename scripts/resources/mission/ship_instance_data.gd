# scripts/resources/ship_instance_data.gd
# Represents a specific ship instance defined in the mission file.
# Corresponds to the C++ 'p_object' struct.
class_name ShipInstanceData
extends Resource

# --- Nested Resource Definitions ---
const SubsystemStatusData = preload("subsystem_status_data.gd")
const TextureReplacementData = preload("texture_replacement_data.gd")
const AltClassData = preload("alt_class_data.gd")
const DockPointPairData = preload("dock_point_pair_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd") # Assuming SexpNode exists
const AIGoal = preload("ai_goal.gd") # Assuming AIGoal resource exists

# --- Basic Info ---
@export var name: String = ""
@export var ship_class_index: int = -1 # Index into GlobalConstants ship list
@export var team: int = 0 # IFF team index
@export var position: Vector3 = Vector3.ZERO
@export var orientation: Basis = Basis.IDENTITY
@export var initial_velocity_percent: int = 0 # Percentage of max speed
@export var initial_hull_percent: int = 100
@export var initial_shields_percent: int = 100
@export var ai_behavior: AIConstants.AIMode = AIConstants.AIMode.NONE
@export var ai_class_index: int = -1 # Index into AIClass array
@export var ai_goals_sexp: SexpNode = null # Root SexpNode for AI goals
@export var cargo1_name: String = "Nothing" # Name of cargo (lookup index later)
@export var flags: int = 0 # Bitmask using GlobalConstants.P_OF_* / P_SF_*
@export var flags2: int = 0 # Bitmask using GlobalConstants.P2_OF_* / P2_SF2_*
@export var orders_accepted: int = -1 # Bitmask for allowed orders (-1 means use default)
@export var group: int = 0 # Multiplayer grouping?
@export var score: int = 0 # Points for destroying this ship
@export var assist_score_pct: float = 0.0 # Percentage of score awarded for assist
@export var persona_index: int = -1 # Index into Personas array
@export var hotkey: int = -1 # 0-9 for F5-F12, -1 for none
@export var respawn_priority: int = 0 # For multiplayer respawn ordering
@export var net_signature: int = 0 # Network signature for multiplayer

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

# --- Wing Info ---
@export var wing_name: String = "" # If part of a wing
@export var position_in_wing: int = -1 # 0-based index within the wing

# --- Special Properties ---
@export var use_special_explosion: bool = false
@export var special_exp_damage: int = -1
@export var special_exp_blast: int = -1
@export var special_exp_inner_radius: int = -1
@export var special_exp_outer_radius: int = -1
@export var use_shockwave: bool = false
@export var special_exp_shockwave_speed: int = 0
@export var special_hitpoints: int = 0 # Overrides ship_data hull if > 0
@export var special_shield_points: int = -1 # Overrides ship_data shields if >= 0

# --- Subsystem Status ---
# Array of SubsystemStatusData resources
@export var subsystem_status: Array[SubsystemStatusData] = []

# --- Texture Replacements ---
# Array of TextureReplacementData resources
@export var texture_replacements: Array[TextureReplacementData] = []

# --- Alternate Types ---
@export var alt_type_name: String = "" # Name from mission's #Alternate Types section
@export var callsign_name: String = "" # Name from mission's #Callsigns section
# Array of AltClassData resources
@export var alternate_classes: Array[AltClassData] = []

# --- Docking ---
# Array of DockPointPairData resources
@export var initial_dock_points: Array[DockPointPairData] = []

# --- FRED Specific / Runtime ---
@export var destroy_before_mission_time: int = -1 # If >= 0, destroy immediately after this time
@export var wing_status_wing_index: int = -1 # Runtime HUD info
@export var wing_status_wing_pos: int = -1 # Runtime HUD info
@export var respawn_count: int = 0 # Runtime multiplayer info
