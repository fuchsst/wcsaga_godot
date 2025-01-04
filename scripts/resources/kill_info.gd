extends Node
class_name KillInfo

# Kill types
enum Type {
	FIGHTER,    # Fighter kills
	BOMBER,     # Bomber kills
	CAPITAL,    # Capital ship kills
	TRANSPORT,  # Transport kills
	ASTEROID,   # Asteroid kills
	OTHER       # Other kills
}

# Kill info

var total_kills: int
var kill_types: Dictionary  # KillType -> count
var current_score: int
var mission_kills: int
var mission_score: int
var last_kill_time: float
var flash_time: float

func _init() -> void:
	total_kills = 0
	kill_types = {}
	for type in Type.values():
		kill_types[type] = 0
	current_score = 0
	mission_kills = 0
	mission_score = 0
	last_kill_time = 0.0
	flash_time = 0.0
