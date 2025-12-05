extends Resource
class_name MissionObject

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const ShipStats = preload("res://scripts/resources/ships/ship_stats.gd")
const TextureReplacement = preload("res://scripts/resources/missions/texture_replacement.gd")
const AIClassResource = preload("res://scripts/resources/ai_classes/ai_class_resource.gd")

## Mission Object (Ship/Wing/Waypoint)

@export var object_name: String = ""
@export var ship: ShipStats = null # Reference to the Ship resource

@export var team: MissionEnums.Team = MissionEnums.Team.UNKNOWN
@export var team_name: String = ""

@export var callsign: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var orientation: Basis = Basis.IDENTITY

# AI
@export var ai_behavior: MissionEnums.AIBehavior = MissionEnums.AIBehavior.NONE
@export var ai_behavior_name: String = ""
@export var ai_class: AIClassResource = null # Reference to AIClassResource
@export var ai_goals: String = "" # Formula string
@export var ai_goals_bt: Resource # Compiled LimboAI BehaviorTree

# Status
@export var cargo: String = ""
@export var initial_hull: int = 100
@export var initial_shields: int = 100
@export var initial_subsystems: Array[String] = []

# Flags
@export var flags: Array[MissionEnums.ShipFlags] = []
@export var flags2: Array[MissionEnums.ShipFlags2] = []

# Arrival/Departure
@export var arrival_location: MissionEnums.ArrivalLocation = MissionEnums.ArrivalLocation.HYPERSPACE
@export var arrival_cue: String = "" # Formula
@export var arrival_cue_bt: Resource # Compiled LimboAI BehaviorTree
@export var departure_location: MissionEnums.DepartureLocation = MissionEnums.DepartureLocation.HYPERSPACE
@export var departure_cue: String = "" # Formula
@export var departure_cue_bt: Resource # Compiled LimboAI BehaviorTree
@export var determination: int = 10

# Misc
@export var respawn_priority: int = 0
@export var orders_accepted: Array[MissionEnums.OrdersAccepted] = []

@export var group: int = 0
@export var score: int = 0
@export var persona_index: int = 0
@export var use_table_score: bool = false

@export var texture_replacements: Array[TextureReplacement] = []

@export var escort_priority: int = 0
@export var respawn_count: int = 0
@export var special_explosion: String = ""
@export var kamikaze_damage: int = 0

@export var special_hitpoints: int = -1
@export var special_shield_points: int = -1
