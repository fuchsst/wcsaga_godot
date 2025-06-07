class_name CampaignMissionData
extends Resource

## WCS campaign mission data containing mission metadata and progression logic.
## Represents a single mission within a campaign with SEXP conditions and branching.

@export var name: String = ""
@export var filename: String = ""
@export var notes: String = ""
@export var index: int = 0

# GFRED2 compatibility properties
@export var mission_id: String = ""
@export var mission_name: String = ""
@export var mission_filename: String = ""
@export var mission_description: String = ""
@export var mission_author: String = ""
@export var position: Vector2 = Vector2.ZERO  # Position in campaign flow diagram
@export var prerequisite_missions: Array[String] = []
@export var mission_branches: Array[CampaignMissionDataBranch] = []
@export var mission_flags: Array[String] = []
@export var is_required: bool = true
@export var difficulty_level: int = 1
@export var mission_briefing_text: String = ""
@export var mission_debriefing_text: String = ""

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
	if mission_id.is_empty():
		mission_id = "mission_%d" % (Time.get_ticks_msec() % 100000)

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

## GFRED2 compatibility methods

## Validates mission data
func validate_mission() -> Array[String]:
	var errors: Array[String] = []
	
	if mission_id.is_empty():
		errors.append("Mission must have an ID")
	
	if mission_name.is_empty():
		errors.append("Mission must have a name")
	
	if mission_filename.is_empty():
		errors.append("Mission must have a filename")
	
	# Validate mission branches
	for i in range(mission_branches.size()):
		var branch: CampaignMissionDataBranch = mission_branches[i]
		var branch_errors: Array[String] = branch.validate_branch()
		for error in branch_errors:
			errors.append("Branch %d: %s" % [i + 1, error])
	
	return errors

## Adds a prerequisite mission
func add_prerequisite(mission_id: String) -> void:
	if not prerequisite_missions.has(mission_id):
		prerequisite_missions.append(mission_id)

## Removes a prerequisite mission
func remove_prerequisite(mission_id: String) -> void:
	prerequisite_missions.erase(mission_id)

## Adds a mission branch
func add_mission_branch(branch: CampaignMissionDataBranch) -> void:
	mission_branches.append(branch)

## Removes a mission branch
func remove_mission_branch(branch_index: int) -> void:
	if branch_index >= 0 and branch_index < mission_branches.size():
		mission_branches.remove_at(branch_index)

## Duplicates mission data
func duplicate_mission() -> CampaignMissionData:
	var duplicate: CampaignMissionData = CampaignMissionData.new()
	duplicate.mission_id = mission_id + "_copy"
	duplicate.mission_name = mission_name + " (Copy)"
	duplicate.mission_filename = mission_filename
	duplicate.mission_description = mission_description
	duplicate.mission_author = mission_author
	duplicate.position = position + Vector2(50, 50)  # Offset copy position
	duplicate.prerequisite_missions = prerequisite_missions.duplicate()
	duplicate.mission_flags = mission_flags.duplicate()
	duplicate.is_required = is_required
	duplicate.difficulty_level = difficulty_level
	duplicate.mission_briefing_text = mission_briefing_text
	duplicate.mission_debriefing_text = mission_debriefing_text
	
	for branch in mission_branches:
		duplicate.mission_branches.append(branch.duplicate_branch())
	
	return duplicate