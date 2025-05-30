class_name SexpMissionTimeFunction
extends BaseSexpFunction

## SEXP function: mission-time
##
## Returns the current mission time in seconds since mission start.
## 
## Usage: (mission-time)
## Returns: Number - seconds since mission started

func _init():
	super._init()
	function_name = "mission-time"
	argument_count = 0
	description = "Returns the current mission time in seconds since mission start"

func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
	# Get mission start time from the game state
	# This would typically be stored in a mission manager or game state singleton
	var mission_manager = _get_mission_manager()
	if not mission_manager:
		return SexpResult.create_error("Mission manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
	
	var mission_time: float = mission_manager.get_mission_time()
	return SexpResult.create_number(mission_time)

func _get_mission_manager():
	## Get the mission manager from the scene tree or global state
	# Check for mission manager in the scene tree
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var mission_manager = tree.get_first_node_in_group("mission_manager")
		if mission_manager:
			return mission_manager
	
	# Check for global mission manager
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	
	# Fallback: use engine time (not ideal but functional)
	var fallback_time = Time.get_time_dict_from_system()["unix"] - Engine.get_process_frames() * 0.016
	return {"get_mission_time": func(): return fallback_time}