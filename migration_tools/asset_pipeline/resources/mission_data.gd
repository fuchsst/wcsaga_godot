class_name MissionData
extends Resource

## WCS mission data resource containing complete mission definition from .fs2 files
## Represents a playable mission with objectives, ships, events, and scripting

@export var mission_name: String = ""
@export var mission_title: String = ""
@export var mission_description: String = ""
@export var mission_designer: String = ""
@export var mission_created: String = ""
@export var mission_modified: String = ""
@export var mission_notes: String = ""

# Mission type and properties
@export var mission_type: String = "single"  # single, multi, training, campaign
@export var game_type_flags: int = 0  # Mission game type flags
@export var mission_flags: int = 0  # Mission behavior flags
@export var num_players: int = 1  # Number of players (multiplayer)
@export var num_respawns: int = 3  # Number of respawns allowed

# Mission environment
@export var background_bitmap: Array[String] = []  # Background bitmap files
@export var sun_bitmap: String = ""  # Sun bitmap
@export var lighting_conditions: Dictionary = {}  # Lighting setup
@export var nebula_intensity: float = 0.0  # Nebula density
@export var nebula_rgb: Vector3 = Vector3(0.8, 0.8, 1.0)  # Nebula color
@export var ambient_light_level: int = 1000000  # Ambient light intensity

# Music and audio
@export var event_music: String = ""  # Event music track
@export var substitute_event_music: String = ""  # Substitute music
@export var briefing_music: String = ""  # Briefing music
@export var substitute_briefing_music: String = ""  # Substitute briefing music
@export var command_briefing_music: String = ""  # Command briefing music
@export var substitute_command_briefing_music: String = ""  # Substitute command music
@export var debriefing_music: String = ""  # Debriefing music
@export var substitute_debriefing_music: String = ""  # Substitute debriefing music

# Mission scripts and variables
@export var sexp_variables: Array[Dictionary] = []  # SEXP variables
@export var mission_events: Array[Dictionary] = []  # Mission events
@export var mission_goals: Array[Dictionary] = []  # Mission objectives

# Ships and wings
@export var ships: Array[Dictionary] = []  # Ship instances
@export var wings: Array[Dictionary] = []  # Wing formations
@export var player_start_shipnum: int = -1  # Player's starting ship

# Waypoints and navigation
@export var waypoint_lists: Array[Dictionary] = []  # Waypoint paths
@export var jump_nodes: Array[Dictionary] = []  # Jump node locations

# Mission briefing
@export var briefing_stages: Array[Dictionary] = []  # Briefing stages
@export var debriefing_stages: Array[Dictionary] = []  # Debriefing stages
@export var command_briefing_stages: Array[Dictionary] = []  # Command briefing stages

# Asteroids and environment objects
@export var asteroid_fields: Array[Dictionary] = []  # Asteroid field definitions
@export var debris_fields: Array[Dictionary] = []  # Debris field definitions

# Mission reinforcements
@export var reinforcements: Array[Dictionary] = []  # Reinforcement waves

# Special mission features
@export var fiction_viewer: String = ""  # Fiction viewer content
@export var command_persona: String = ""  # Command persona for briefings
@export var full_war: bool = false  # Full war mission flag
@export var red_alert: bool = false  # Red alert mission
@export var scramble: bool = false  # Scramble mission

# Cutscene data
@export var cutscenes: Array[Dictionary] = []  # Mission cutscenes

# Loading screen
@export var loading_screen_640: String = ""  # Loading screen 640x480
@export var loading_screen_1024: String = ""  # Loading screen 1024x768

func _init() -> void:
	# Initialize arrays if empty
	if background_bitmap.is_empty():
		background_bitmap = []
	if lighting_conditions.is_empty():
		lighting_conditions = {}
	if sexp_variables.is_empty():
		sexp_variables = []
	if mission_events.is_empty():
		mission_events = []
	if mission_goals.is_empty():
		mission_goals = []
	if ships.is_empty():
		ships = []
	if wings.is_empty():
		wings = []
	if waypoint_lists.is_empty():
		waypoint_lists = []
	if jump_nodes.is_empty():
		jump_nodes = []
	if briefing_stages.is_empty():
		briefing_stages = []
	if debriefing_stages.is_empty():
		debriefing_stages = []
	if command_briefing_stages.is_empty():
		command_briefing_stages = []
	if asteroid_fields.is_empty():
		asteroid_fields = []
	if debris_fields.is_empty():
		debris_fields = []
	if reinforcements.is_empty():
		reinforcements = []
	if cutscenes.is_empty():
		cutscenes = []

## Utility functions for mission data

func get_total_ships() -> int:
	"""Get total number of ships in mission."""
	return ships.size()

func get_total_wings() -> int:
	"""Get total number of wings in mission."""
	return wings.size()

func get_player_ships() -> Array[Dictionary]:
	"""Get all ships that can be used by players."""
	var player_ships: Array[Dictionary] = []
	
	for ship in ships:
		if ship.get("player_ship", false):
			player_ships.append(ship)
	
	return player_ships

func get_ai_ships() -> Array[Dictionary]:
	"""Get all AI-controlled ships."""
	var ai_ships: Array[Dictionary] = []
	
	for ship in ships:
		if not ship.get("player_ship", false):
			ai_ships.append(ship)
	
	return ai_ships

func get_ship_by_name(ship_name: String) -> Dictionary:
	"""Get ship data by name."""
	for ship in ships:
		if ship.get("name", "") == ship_name:
			return ship
	
	return {}

func get_wing_by_name(wing_name: String) -> Dictionary:
	"""Get wing data by name."""
	for wing in wings:
		if wing.get("name", "") == wing_name:
			return wing
	
	return {}

func get_primary_objectives() -> Array[Dictionary]:
	"""Get all primary mission objectives."""
	var primary_goals: Array[Dictionary] = []
	
	for goal in mission_goals:
		if goal.get("type", "") == "primary":
			primary_goals.append(goal)
	
	return primary_goals

func get_secondary_objectives() -> Array[Dictionary]:
	"""Get all secondary mission objectives."""
	var secondary_goals: Array[Dictionary] = []
	
	for goal in mission_goals:
		if goal.get("type", "") == "secondary":
			secondary_goals.append(goal)
	
	return secondary_goals

func get_bonus_objectives() -> Array[Dictionary]:
	"""Get all bonus mission objectives."""
	var bonus_goals: Array[Dictionary] = []
	
	for goal in mission_goals:
		if goal.get("type", "") == "bonus":
			bonus_goals.append(goal)
	
	return bonus_goals

func has_briefing() -> bool:
	"""Check if mission has briefing stages."""
	return briefing_stages.size() > 0

func has_command_briefing() -> bool:
	"""Check if mission has command briefing."""
	return command_briefing_stages.size() > 0

func has_debriefing() -> bool:
	"""Check if mission has debriefing stages."""
	return debriefing_stages.size() > 0

func is_multiplayer_mission() -> bool:
	"""Check if this is a multiplayer mission."""
	return mission_type == "multi" or num_players > 1

func is_training_mission() -> bool:
	"""Check if this is a training mission."""
	return mission_type == "training"

func is_campaign_mission() -> bool:
	"""Check if this is part of a campaign."""
	return mission_type == "campaign"

func get_mission_difficulty() -> String:
	"""Estimate mission difficulty based on content."""
	var ship_count: int = get_total_ships()
	var objective_count: int = mission_goals.size()
	var event_count: int = mission_events.size()
	
	var complexity_score: int = ship_count + (objective_count * 2) + event_count
	
	if complexity_score < 20:
		return "Easy"
	elif complexity_score < 50:
		return "Medium"
	elif complexity_score < 100:
		return "Hard"
	else:
		return "Very Hard"

func get_environment_hazards() -> Array[String]:
	"""Get list of environmental hazards in mission."""
	var hazards: Array[String] = []
	
	if nebula_intensity > 0.5:
		hazards.append("Dense Nebula")
	
	if asteroid_fields.size() > 0:
		hazards.append("Asteroid Fields")
	
	if debris_fields.size() > 0:
		hazards.append("Debris Fields")
	
	# Check for special mission flags that indicate hazards
	if red_alert:
		hazards.append("Red Alert")
	
	if scramble:
		hazards.append("Scramble")
	
	return hazards

func get_estimated_play_time() -> float:
	"""Estimate mission play time in minutes."""
	var base_time: float = 10.0  # Base 10 minutes
	
	# Add time based on ship count
	base_time += float(get_total_ships()) * 0.5
	
	# Add time based on objectives
	base_time += float(mission_goals.size()) * 2.0
	
	# Add time based on events
	base_time += float(mission_events.size()) * 0.5
	
	# Add time for briefings
	if has_briefing():
		base_time += float(briefing_stages.size()) * 1.0
	
	# Multiplayer missions typically take longer
	if is_multiplayer_mission():
		base_time *= 1.5
	
	return base_time

func get_faction_breakdown() -> Dictionary:
	"""Get breakdown of ships by faction."""
	var factions: Dictionary = {}
	
	for ship in ships:
		var team: String = ship.get("team", "Unknown")
		if not factions.has(team):
			factions[team] = 0
		factions[team] += 1
	
	return factions

func validate_mission_integrity() -> Array[String]:
	"""Validate mission data integrity and return list of issues."""
	var issues: Array[String] = []
	
	# Check for required fields
	if mission_name.is_empty():
		issues.append("Mission name is required")
	
	if mission_title.is_empty():
		issues.append("Mission title is required")
	
	# Check for player ships
	if get_player_ships().is_empty() and not is_training_mission():
		issues.append("No player ships defined")
	
	# Check for objectives
	if mission_goals.is_empty():
		issues.append("No mission objectives defined")
	
	# Check for ships
	if ships.is_empty():
		issues.append("No ships defined in mission")
	
	# Validate ship references in events
	for event in mission_events:
		var event_sexp: String = event.get("formula", "")
		# Basic validation - more complex SEXP validation would be needed
		if event_sexp.is_empty():
			issues.append("Event without formula found")
	
	return issues

func clone_with_overrides(overrides: Dictionary) -> MissionData:
	"""Create a copy of this mission data with specific property overrides."""
	var clone: MissionData = MissionData.new()
	
	# Copy all properties with overrides
	clone.mission_name = overrides.get("mission_name", mission_name)
	clone.mission_title = overrides.get("mission_title", mission_title)
	clone.mission_type = overrides.get("mission_type", mission_type)
	clone.num_players = overrides.get("num_players", num_players)
	clone.ships = ships.duplicate(true)
	clone.wings = wings.duplicate(true)
	clone.mission_goals = mission_goals.duplicate(true)
	clone.mission_events = mission_events.duplicate(true)
	
	return clone

func to_debug_string() -> String:
	"""Get debug information about this mission."""
	var debug_info: Array[String] = []
	
	debug_info.append("Mission: %s" % mission_title)
	debug_info.append("Type: %s, Players: %d" % [mission_type, num_players])
	debug_info.append("Ships: %d, Wings: %d" % [get_total_ships(), get_total_wings()])
	debug_info.append("Objectives: %d (P:%d, S:%d, B:%d)" % [
		mission_goals.size(),
		get_primary_objectives().size(),
		get_secondary_objectives().size(),
		get_bonus_objectives().size()
	])
	debug_info.append("Events: %d" % mission_events.size())
	debug_info.append("Difficulty: %s" % get_mission_difficulty())
	debug_info.append("Est. Time: %.1f minutes" % get_estimated_play_time())
	
	var hazards: Array[String] = get_environment_hazards()
	if not hazards.is_empty():
		debug_info.append("Hazards: %s" % ", ".join(hazards))
	
	return "\n".join(debug_info)