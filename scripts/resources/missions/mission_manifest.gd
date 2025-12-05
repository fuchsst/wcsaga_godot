extends Resource
class_name MissionManifest

const MissionObject = preload("res://scripts/resources/missions/mission_object.gd")
const MissionWing = preload("res://scripts/resources/missions/mission_wing.gd")
const MissionEvent = preload("res://scripts/resources/missions/mission_event.gd")
const MissionGoal = preload("res://scripts/resources/missions/mission_goal.gd")
const MissionMessage = preload("res://scripts/resources/missions/mission_message.gd")
const MissionCutscene = preload("res://scripts/resources/missions/mission_cutscene.gd")
const BackgroundData = preload("res://scripts/resources/missions/background_data.gd")
const AsteroidField = preload("res://scripts/resources/missions/asteroid_field.gd")
const PlayerData = preload("res://scripts/resources/missions/player_data.gd")
const BriefingStage = preload("res://scripts/resources/missions/briefing_stage.gd")
const DebriefingStage = preload("res://scripts/resources/missions/debriefing_stage.gd")
const CommandBriefingStage = preload("res://scripts/resources/missions/command_briefing_stage.gd")
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const MissionMetadata = preload("res://scripts/resources/missions/mission_metadata.gd")
const SexpVariable = preload("res://scripts/resources/missions/sexp_variable.gd")
const WaypointList = preload("res://scripts/resources/missions/waypoint_list.gd")

## Root resource for a converted FS2 mission

@export var mission_name: String = ""
@export var mission_id: String = "" # Filename without extension, useful ID
# @export var source_file: String = "" # Removed as per feedback

# Metadata
# Metadata
@export var metadata: MissionMetadata = MissionMetadata.new()

@export var game_type: Array[MissionEnums.GameTypeFlags] = []
@export var flags: Array[MissionEnums.MissionFlags] = []

@export var disallow_support: bool = false
@export var hull_repair_ceiling: float = 0.0
@export var subsystem_repair_ceiling: float = 0.0

@export var viewer_orient: Basis = Basis.IDENTITY

# Music
@export var music: AudioStream = null
@export var briefing_music: AudioStream = null
@export var debriefing_music: AudioStream = null

# Content
@export var players: PlayerData = PlayerData.new()
@export var objects: Array[MissionObject] = []
@export var wings: Array[MissionWing] = []
@export var events: Array[MissionEvent] = []
@export var goals: Array[MissionGoal] = []
@export var messages: Array[MissionMessage] = []
@export var cutscenes: Array[MissionCutscene] = []
@export var waypoints: Array[WaypointList] = []
@export var callsigns: Array[String] = []

# Environment
@export var backgrounds: BackgroundData = BackgroundData.new()
@export var asteroid_fields: Array[AsteroidField] = []

# Briefings
@export var command_briefing: Array[CommandBriefingStage] = []
@export var briefing: Array[BriefingStage] = []
@export var debriefing: Array[DebriefingStage] = []

@export var starting_wing_names: Array[String] = []
@export var squadron_wing_names: Array[String] = []
@export var team_versus_team_wing_names: Array[String] = []
@export var ai_profile: String = ""

@export var squad_reassign_name: String = ""
@export var squad_reassign_logo: String = ""

@export var variables: Array[SexpVariable] = []
@export var fiction_viewer_file: String = ""
