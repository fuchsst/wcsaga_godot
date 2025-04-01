# scripts/resources/player_data.gd
# Resource defining player profile data, statistics, and campaign progress.
# Corresponds to C++ 'player' struct and 'scoring_struct'.
class_name PilotData # Renamed from PlayerData for clarity
extends Resource

# --- Pilot Flags (Mirroring PLAYER_FLAGS_*) ---
enum PilotFlags {
	NONE = 0,
	IS_MULTI = 1 << 0,		# Player is a multiplayer pilot
	IS_TRACKER = 1 << 1,	# Player is a PXO pilot
	PROMOTED = 1 << 2,		# Player was promoted this mission
	SHOW_TIPS = 1 << 3,		# Show pilot tips dialog
	# TODO: Add other flags as needed
}

# --- Basic Info ---
@export var callsign: String = "New Pilot"
@export var short_callsign: String = "" # For HUD display
@export var image_filename: String = "" # Pilot image (e.g., "Ter0001")
@export var squad_filename: String = "" # Squad logo (e.g., "Bloodhounds")
@export var squad_name: String = ""
@export var flags: int = PilotFlags.SHOW_TIPS # Default flags
@export var created_time: int = 0 # Timestamp of creation (Time.get_unix_time_from_system())

# --- Statistics (Mirroring scoring_struct) ---
# Note: Separating mission stats (m_*) from all-time stats.
# All-time stats are stored here. Mission stats are temporary during debriefing.
@export_group("All-Time Statistics")
@export var score: int = 0
@export var rank: int = 0 # Use GlobalConstants.Rank enum
@export var medals: Array[int] = [] # Array size MAX_MEDALS, stores count of each medal
@export var kills: Array[int] = [] # Array size MAX_SHIP_CLASSES, stores kill count per ship class index
@export var assists: int = 0
@export var kill_count: int = 0 # Total kills (all types)
@export var kill_count_ok: int = 0 # Kills valid for stats/badges (non-training, non-friendly?)
@export var p_shots_fired: int = 0
@export var s_shots_fired: int = 0
@export var p_shots_hit: int = 0
@export var s_shots_hit: int = 0
@export var p_bonehead_hits: int = 0 # Friendly hits
@export var s_bonehead_hits: int = 0 # Friendly hits
@export var bonehead_kills: int = 0 # Friendly kills
@export var missions_flown: int = 0
@export var flight_time: int = 0 # Total seconds flown
@export var last_flown: int = 0 # Timestamp of last mission completion
@export var last_backup: int = 0 # Timestamp of previous mission completion

# --- Campaign Progress ---
@export_group("Campaign Progress")
@export var current_campaign: String = "" # Filename of the current campaign (.fsc)
@export var completed_missions: Dictionary = {} # campaign_name: bitmask of completed missions
@export var campaign_stats: Dictionary = {} # campaign_name: scoring_struct (or relevant parts)
@export var persistent_sexp_vars: Dictionary = {} # campaign_name: {var_name: value}

# --- Multiplayer Stats (Optional - depends on MP implementation) ---
@export_group("Multiplayer Statistics")
@export var mp_kills_total: int = 0
@export var mp_assists_total: int = 0
@export var mp_deaths_total: int = 0
# Add more detailed MP stats if needed

# --- Pilot Settings ---
@export_group("Pilot Settings")
@export var show_tips: bool = true
@export var tips_shown: Array[String] = [] # List of tips already displayed

# --- Initialization ---
func _init():
	# Ensure arrays are initialized with correct sizes if needed immediately
	if medals.size() != GlobalConstants.MAX_MEDALS:
		medals.resize(GlobalConstants.MAX_MEDALS)
		medals.fill(0)
	if kills.size() != GlobalConstants.MAX_SHIP_CLASSES: # Assuming MAX_SHIP_CLASSES is defined
		kills.resize(GlobalConstants.MAX_SHIP_CLASSES)
		kills.fill(0)
	created_time = Time.get_unix_time_from_system()

# --- Helper Methods ---
func get_rank_name() -> String:
	# Assumes Ranks array/resource is loaded globally (e.g., in GameData singleton)
	if Engine.has_singleton("GameData") and rank >= 0 and rank < GameData.Ranks.size():
		return GameData.Ranks[rank].name
	return "Unknown Rank"

func get_stat(stat_enum) -> int:
	# Placeholder for potentially accessing stats via enum later
	match stat_enum:
		GlobalConstants.StatType.SCORE: return score
		GlobalConstants.StatType.KILLS_TOTAL: return kill_count_ok
		# ... other stats ...
	return 0

func update_stat(stat_enum, value: int):
	# Placeholder
	match stat_enum:
		GlobalConstants.StatType.SCORE: score = value
		GlobalConstants.StatType.KILLS_TOTAL: kill_count_ok = value
		# ... other stats ...

func add_kill(ship_class_index: int):
	if ship_class_index >= 0 and ship_class_index < kills.size():
		kills[ship_class_index] += 1
		kill_count += 1
		kill_count_ok += 1 # Assuming valid kill

func add_assist():
	assists += 1

# TODO: Add methods for managing campaign progress, SEXP vars, etc.
