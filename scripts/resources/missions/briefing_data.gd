extends Resource
class_name BriefingData
const BriefingStage = preload("res://scripts/resources/missions/briefing_stage.gd")
@export var stages: Array[BriefingStage] = []
@export var music: String = ""
