extends Resource
class_name MissionWing

## Wing formation configuration
const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")

@export var wing_name: String = ""
@export var special_ship: String = "" # Special ship class for this wing
@export var waves: int = 1 # Number of waves
@export var wave_threshold: int = 0 # Wave arrival threshold

@export var arrival_location: MissionEnums.ArrivalLocation = MissionEnums.ArrivalLocation.HYPERSPACE
@export var arrival_cue: String = "" # SEXP arrival condition
@export var arrival_cue_bt: Resource # Compiled LimboAI BehaviorTree

@export var departure_location: MissionEnums.DepartureLocation = MissionEnums.DepartureLocation.HYPERSPACE
@export var departure_anchor: String = ""
@export var departure_paths: Array[String] = []
@export var departure_cue: String = "" # SEXP departure condition
@export var departure_cue_bt: Resource # Compiled LimboAI BehaviorTree

@export var ships: Array[String] = [] # List of ship names in this wing
@export var hotkey: int = -1
@export var flags: Array[MissionEnums.WingFlags] = []
