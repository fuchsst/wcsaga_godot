class_name CampaignInfo
extends Resource

## Campaign information resource for tracking player's campaign progress.
## Stores basic campaign metadata and completion status.

@export var campaign_filename: String = ""  ## .fsc filename
@export var campaign_name: String = ""      ## Display name
@export var description: String = ""        ## Campaign description  
@export var is_completed: bool = false      ## Whether campaign is finished
@export var current_mission: int = 0        ## Current mission index (0-based)
@export var total_missions: int = 0         ## Total missions in campaign
@export var missions_completed: PackedInt32Array = []  ## Bitmask of completed missions
@export var campaign_score: int = 0         ## Total score for this campaign
@export var last_played: int = 0           ## Unix timestamp of last play
@export var difficulty_level: int = 0      ## Difficulty setting for this campaign

func _init() -> void:
	last_played = Time.get_unix_time_from_system()

## Check if a specific mission is completed
func is_mission_completed(mission_index: int) -> bool:
	if mission_index < 0 or mission_index >= missions_completed.size():
		return false
	return (missions_completed[mission_index / 32] & (1 << (mission_index % 32))) != 0

## Mark a mission as completed
func set_mission_completed(mission_index: int, completed: bool = true) -> void:
	if mission_index < 0:
		return
		
	# Ensure array is large enough
	var required_size: int = (mission_index / 32) + 1
	if missions_completed.size() < required_size:
		missions_completed.resize(required_size)
	
	var array_index: int = mission_index / 32
	var bit_index: int = mission_index % 32
	
	if completed:
		missions_completed[array_index] |= (1 << bit_index)
	else:
		missions_completed[array_index] &= ~(1 << bit_index)

## Get completion percentage
func get_completion_percentage() -> float:
	if total_missions <= 0:
		return 0.0
	return float(current_mission) / float(total_missions) * 100.0