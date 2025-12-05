extends Resource
class_name MissionGoal

enum Type {PRIMARY, SECONDARY, BONUS}

@export var name: String = ""
@export var message: String = "" # Goal description displayed to user
@export var type: Type = Type.PRIMARY
@export var formula: String = ""
@export var score: int = 0
@export var behavior_tree: Resource # Compiled LimboAI BehaviorTree
@export var is_invalid: bool = false # +Invalid flag
@export var team: int = 0 # default team?
