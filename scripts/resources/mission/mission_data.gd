# scripts/resources/mission/mission_data.gd
extends Resource
class_name MissionData

## Defines the overall structure and data for a single mission.
## Converted from original .fs2 files.

@export var mission_title: String = ""
@export var mission_notes: String = ""
@export var mission_desc: String = ""

# --- Mission Info ---
@export var game_type: int = 0 # Corresponds to MISSION_TYPE_* flags
@export var flags: int = 0     # Corresponds to MISSION_FLAG_* flags
@export var num_players: int = 1
@export var num_respawns: int = 0
@export var max_respawn_delay: int = -1
@export var red_alert: bool = false
@export var scramble: bool = false
@export var hull_repair_ceiling: float = 0.0 # Percentage
@export var subsys_repair_ceiling: float = 100.0 # Percentage
@export var disallow_support: bool = false
@export var all_teams_attack: bool = false
@export var player_entry_delay: float = 0.0 # Seconds
@export var squad_reassign_name: String = ""
@export var squad_reassign_logo: String = ""
@export var loading_screen_640: String = "" # Path to texture
@export var loading_screen_1024: String = "" # Path to texture
@export var skybox_model: String = "" # Path to model
@export var skybox_flags: int = 0
@export var ai_profile_name: String = "Default" # Name of the AIProfile resource

# --- Music ---
@export var event_music_name: String = ""
@export var substitute_event_music_name: String = ""
@export var briefing_music_name: String = ""
@export var substitute_briefing_music_name: String = ""
@export var success_debrief_music_name: String = ""
@export var average_debrief_music_name: String = ""
@export var fail_debrief_music_name: String = ""
@export var fiction_viewer_music_name: String = ""

# --- Environment ---
@export var num_stars: int = 100
@export var ambient_light_level: Color = Color(0.47, 0.47, 0.47) # Default 0x787878
@export var nebula_index: int = -1 # Index into Nebula_filenames array (or similar lookup)
@export var nebula_color_index: int = 0 # Index into Nebula_colors array
@export var nebula_pitch: int = 0
@export var nebula_bank: int = 0
@export var nebula_heading: int = 0
@export var full_nebula: bool = false # Corresponds to MISSION_FLAG_FULLNEB
@export var neb2_awacs: float = -1.0
@export var storm_name: String = "none"

# --- Player Starts (Per Team) ---
# Array of PlayerStartData resources
@export var player_starts: Array[Resource] = [] # Array[PlayerStartData]

# --- Ships and Wings ---
# Array of ShipInstanceData resources
@export var ships: Array[Resource] = [] # Array[ShipInstanceData]
# Array of WingInstanceData resources
@export var wings: Array[Resource] = [] # Array[WingInstanceData]

# --- Mission Logic ---
# Array of MissionEventData resources
@export var events: Array[Resource] = [] # Array[MissionEventData]
# Array of MissionObjectiveData resources
@export var goals: Array[Resource] = [] # Array[MissionObjectiveData]
# Array of WaypointListData resources
@export var waypoint_lists: Array[Resource] = [] # Array[WaypointListData]
# Array of SexpVariableData resources
@export var variables: Array[Resource] = [] # Array[SexpVariableData]

# --- Messages and Personas ---
@export var command_sender: String = "Command"
@export var command_persona_name: String = "" # Name of the PersonaData resource
# Array of MessageData resources
@export var messages: Array[Resource] = [] # Array[MessageData]
# Array of PersonaData resources (can be global or mission-specific)
@export var personas: Array[Resource] = [] # Array[PersonaData]

# --- Briefing/Debriefing (Per Team) ---
# Array of BriefingData resources
@export var briefings: Array[Resource] = [] # Array[BriefingData]
# Array of DebriefingData resources
@export var debriefings: Array[Resource] = [] # Array[DebriefingData]

# --- Reinforcements ---
# Array of ReinforcementData resources
@export var reinforcements: Array[Resource] = [] # Array[ReinforcementData]

# --- Other ---
# Array of TextureReplacementData resources
@export var texture_replacements: Array[Resource] = [] # Array[TextureReplacementData]
# Array of String resources (alt names)
@export var alternate_type_names: Array[String] = []
# Array of String resources (callsigns)
@export var callsigns: Array[String] = []

# --- Cutscenes ---
# Array of MissionCutsceneData resources
@export var cutscenes: Array[Resource] = [] # Array[MissionCutsceneData]

# --- Fiction ---
@export var fiction_file: String = ""
@export var fiction_font: String = ""

# --- Command Briefing ---
# Array of CommandBriefingData resources
@export var command_briefings: Array[Resource] = [] # Array[CommandBriefingData]

# --- Asteroid Fields ---
# Array of AsteroidFieldData resources
@export var asteroid_fields: Array[Resource] = [] # Array[AsteroidFieldData]

# --- Jump Nodes ---
# Array of JumpNodeData resources
@export var jump_nodes: Array[Resource] = [] # Array[JumpNodeData]
