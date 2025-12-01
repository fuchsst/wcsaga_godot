extends Resource
class_name MissionEvent

## Mission event configuration (SEXP-driven)
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")

@export var event_name: String = ""
@export var formula: String = "" # SEXP formula
@export var repeat_count: int = 1
@export var interval: int = 1
@export var team: MissionEnums.Team = MissionEnums.Team.UNKNOWN # Team affected by event
@export var score: int = 0
@export var chain_delay: int = 0
@export var objective: String = "" # Objective text
@export var objective_desc: String = "" # Objective description
