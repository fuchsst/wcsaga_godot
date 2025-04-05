# scripts/resources/mission/ship_instance_data.gd
# Represents a specific ship instance defined in the mission file.
# Corresponds to the C++ 'p_object' struct.
class_name ShipInstanceData
extends Resource

# --- Nested Resource Definitions ---
# Forward declare to avoid cyclic dependencies if needed, or ensure they are loaded.
# Example: const SubsystemStatusData = preload("subsystem_status_data.gd")
# For now, assume they will be loaded correctly by the engine.

# --- Basic Info ---
@export var ship_name: String = ""
@export var ship_class_name: String = "" # Name of the ShipData resource
@export var team: int = 0 # IFF Team index
@export var position: Vector3 = Vector3.ZERO
@export var orientation: Basis = Basis.IDENTITY
@export var initial_velocity_percent: int = 0 # Percentage of max speed
@export var initial_hull_percent: int = 100
@export var initial_shields_percent: int = 100
@export var ai_behavior: int = 0 # Corresponds to AI_BEHAVIOR_* enum (defined in AIConstants or similar)
@export var ai_class_name: String = "" # Name of the AIProfile resource
@export var ai_goals: Resource = null # SexpNode resource for AI goals
@export var cargo1_name: String = "Nothing" # Name of the cargo (lookup index later)
@export var flags: int = 0 # Corresponds to P_SF_* flags
@export var flags2: int = 0 # Corresponds to P2_SF2_* flags
@export var escort_priority: int = 0 # Priority if this ship is an escort target
@export var orders_accepted: int = -1 # Bitmask for allowed orders (-1 means use default)
@export var group: int = 0 # Multiplayer grouping?
@export var score: int = 0 # Points for destroying this ship
@export var assist_score_pct: float = 0.0 # Percentage of score awarded for assist
@export var persona_index: int = -1 # Index into Personas array
@export var hotkey: int = -1 # 0-9 for F5-F12, -1 for none
@export var respawn_priority: int = 0 # For multiplayer respawn ordering
@export var net_signature: int = 0 # Network signature for multiplayer
@export var kamikaze_damage: float = 0.0 # Damage dealt on kamikaze attack

# --- Arrival / Departure ---
@export var arrival_location: int = 0 # Enum: ARRIVE_AT_LOCATION, etc.
@export var arrival_distance: int = 0
@export var arrival_anchor_name: String = "" # Name of anchor object/waypoint
@export var arrival_path_mask: int = -1 # Bitmask for docking paths
@export var arrival_cue: Resource = null # SexpNode resource
@export var arrival_delay_ms: int = 0 # Delay in milliseconds after cue is true

@export var departure_location: int = 0 # Corresponds to DEPARTURE_* enum
@export var departure_anchor_name: String = "" # Name of anchor object/waypoint
@export var departure_path_mask: int = -1 # Index into path restrictions or bitmask
@export var departure_cue: Resource = null # SexpNode resource
@export var departure_delay_ms: int = 0 # Delay in milliseconds after cue is true

# --- Wing Info ---
# Note: wing_name and position_in_wing are typically derived from the WingInstanceData
# and the ship's name matching one in the wing's ship_names array during mission load.
# They might not need to be explicitly stored here if the relationship is established elsewhere.
# @export var wing_name: String = "" # If part of a wing
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
@export var subsystem_status: Array[Resource] = [] # Array[SubsystemStatusData]

# --- Texture Replacements ---
# Array of TextureReplacementData resources
@export var texture_replacements: Array[Resource] = [] # Array[TextureReplacementData]

# --- Alternate Types ---
@export var alt_type_name: String = "" # Name from mission's alternate_type_names array
@export var callsign_name: String = "" # Name from mission's callsigns array
# Array of AltClassData resources
@export var alternate_classes: Array[Resource] = [] # Array[AltClassData]

# --- Docking ---
# Array of DockingPairData resources
@export var initial_docking: Array[Resource] = [] # Array[DockingPairData]

# --- FRED Specific / Runtime ---
@export var destroy_before_mission_time: int = -1 # Milliseconds, If >= 0, destroy immediately after this time
@export var wing_status_wing_index: int = -1 # Runtime HUD info
@export var wing_status_wing_pos: int = -1 # Runtime HUD info
@export var respawn_count: int = 0 # Runtime multiplayer info
@export var alternate_iff_colors: Dictionary = {} # Key: team index (int), Value: Color override (Color)
