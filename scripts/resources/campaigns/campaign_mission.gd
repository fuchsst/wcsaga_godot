class_name CampaignMission
extends Resource

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")

@export var mission: Resource # The actual mission resource
@export var flags: Array[MissionEnums.CampaignMissionFlags] = []
@export var formula: String = ""
@export var main_hall: int = 0
@export var debriefing_persona: int = 0
@export var level: int = 0
@export var position: int = 0
@export var behavior_tree: Resource # Compiled LimboAI BehaviorTree
