class_name CampaignData
extends Resource

## WCS campaign data resource containing mission structure and metadata.
## Represents a complete campaign with missions, progression logic, and story elements.
## Compatible with WCS FC2 campaign file format and SEXP integration.

@export var name: String = ""
@export var description: String = ""
@export var filename: String = ""
@export var type: CampaignDataManager.CampaignType = CampaignDataManager.CampaignType.SINGLE_PLAYER

# Campaign structure
@export var missions: Array[CampaignMissionData] = []
@export var num_missions: int = 0
@export var num_players: int = 1

# Campaign flow
@export var intro_cutscene: String = ""
@export var end_cutscene: String = ""
@export var loop_enabled: bool = false
@export var loop_mission_index: int = -1
@export var loop_reentry_index: int = -1

# Available assets
@export var allowed_ships: Array[String] = []
@export var allowed_weapons: Array[String] = []

# Campaign flags and settings
@export var custom_tech_database: bool = false
@export var reset_rank: bool = false
@export var main_hall: String = "default"

# Campaign progression metadata
@export var created_date: String = ""
@export var version: String = "1.0"
@export var author: String = ""

func _init() -> void:
	"""Initialize campaign data resource."""
	resource_name = "CampaignData"

func get_mission_count() -> int:
	"""Get total number of missions in campaign."""
	return missions.size()

func get_mission_by_index(index: int) -> CampaignMissionData:
	"""Get mission by index."""
	if index < 0 or index >= missions.size():
		return null
	return missions[index]

func get_mission_by_filename(mission_filename: String) -> CampaignMissionData:
	"""Get mission by filename."""
	for mission in missions:
		if mission.filename == mission_filename:
			return mission
	return null

func add_mission(mission: CampaignMissionData) -> void:
	"""Add mission to campaign."""
	mission.index = missions.size()
	missions.append(mission)
	num_missions = missions.size()

func is_multiplayer_campaign() -> bool:
	"""Check if campaign is multiplayer."""
	return type != CampaignDataManager.CampaignType.SINGLE_PLAYER

func get_campaign_info() -> Dictionary:
	"""Get campaign information summary."""
	return {
		"name": name,
		"description": description,
		"filename": filename,
		"type": CampaignDataManager.CampaignType.keys()[type],
		"mission_count": get_mission_count(),
		"is_multiplayer": is_multiplayer_campaign(),
		"author": author,
		"version": version
	}

# Additional resource classes for campaign data

class_name CampaignMissionData
extends Resource

## WCS campaign mission data containing mission metadata and progression logic.
## Represents a single mission within a campaign with SEXP conditions and branching.

@export var name: String = ""
@export var filename: String = ""
@export var notes: String = ""
@export var index: int = 0

# Mission flow control
@export var formula_sexp: String = ""  # SEXP formula for mission branching
@export var has_mission_loop: bool = false
@export var mission_loop_formula: String = ""
@export var mission_loop_description: String = ""
@export var mission_loop_brief_anim: String = ""
@export var mission_loop_brief_sound: String = ""

# Mission metadata
@export var level: int = 0  # Tree level for editor
@export var position: int = 0  # X position for editor
@export var flags: int = 0
@export var main_hall: String = "default"
@export var debrief_persona: String = "default"

# Mission completion tracking
@export var goals: Array = []  # Array of CampaignGoalData
@export var events: Array = []  # Array of CampaignEventData
@export var saved_variables: Array = []  # Array of SexpVariableData

# Mission statistics
@export var completion_time: float = 0.0
@export var best_score: int = 0
@export var medals_earned: Array[String] = []

func _init() -> void:
	"""Initialize mission data resource."""
	resource_name = "CampaignMissionData"

func is_available() -> bool:
	"""Check if mission prerequisites are met."""
	# TODO: Implement SEXP evaluation for mission availability
	return true

func get_mission_info() -> Dictionary:
	"""Get mission information summary."""
	return {
		"name": name,
		"filename": filename,
		"notes": notes,
		"index": index,
		"has_loop": has_mission_loop,
		"goal_count": goals.size(),
		"event_count": events.size()
	}

class_name CampaignGoalData
extends Resource

## WCS campaign goal data for mission completion tracking.

@export var name: String = ""
@export var status: int = 0  # MissionCompletionState value

func _init() -> void:
	"""Initialize goal data resource."""
	resource_name = "CampaignGoalData"

class_name CampaignEventData
extends Resource

## WCS campaign event data for mission event tracking.

@export var name: String = ""
@export var status: int = 0  # MissionCompletionState value

func _init() -> void:
	"""Initialize event data resource."""
	resource_name = "CampaignEventData"

class_name SexpVariableData
extends Resource

## WCS SEXP variable data for campaign state persistence.

@export var name: String = ""
@export var value: Variant
@export var type: String = "number"

func _init() -> void:
	"""Initialize SEXP variable data resource."""
	resource_name = "SexpVariableData"