class_name MissionData
extends Resource

## Central mission data structure using Godot's resource system
## Provides serialization, type safety, and editor integration for WCS missions
##
## This replaces the C++ mission struct from FRED2 with a modern Godot Resource
## that provides automatic serialization, type safety, and integration with
## Godot's property system for seamless editor functionality.
##
## Converted from original .fs2 files with enhanced validation and change tracking.

@export var mission_title: String = ""
@export var mission_notes: String = ""
@export var mission_desc: String = ""

# --- Mission Info ---
@export var game_type: int = 0 # Corresponds to MISSION_TYPE_* flags
@export var flags: int = 0     # Corresponds to MISSION_FLAG_* flags
@export var num_players: int = 1
@export var num_respawns: int = 0
@export var max_respawn_delay: int = -1
@export var red_alert: bool = false
@export var scramble: bool = false
@export var hull_repair_ceiling: float = 0.0 # Percentage
@export var subsys_repair_ceiling: float = 100.0 # Percentage
@export var disallow_support: bool = false
@export var all_teams_attack: bool = false
@export var player_entry_delay: float = 0.0 # Seconds
@export var squad_reassign_name: String = ""
@export var squad_reassign_logo: String = ""
@export var loading_screen_640: String = "" # Path to texture
@export var loading_screen_1024: String = "" # Path to texture
@export var skybox_model: String = "" # Path to model
@export var skybox_flags: int = 0
@export var ai_profile_name: String = "Default" # Name of the AIProfile resource

# --- Music ---
@export var event_music_name: String = ""
@export var substitute_event_music_name: String = ""
@export var briefing_music_name: String = ""
@export var substitute_briefing_music_name: String = ""
@export var success_debrief_music_name: String = ""
@export var average_debrief_music_name: String = ""
@export var fail_debrief_music_name: String = ""
@export var fiction_viewer_music_name: String = ""

# --- Environment ---
@export var num_stars: int = 100
@export var ambient_light_level: Color = Color(0.47, 0.47, 0.47) # Default 0x787878
@export var nebula_index: int = -1 # Index into Nebula_filenames array (or similar lookup)
@export var nebula_color_index: int = 0 # Index into Nebula_colors array
@export var nebula_pitch: int = 0
@export var nebula_bank: int = 0
@export var nebula_heading: int = 0
@export var full_nebula: bool = false # Corresponds to MISSION_FLAG_FULLNEB
@export var neb2_awacs: float = -1.0
@export var storm_name: String = "none"

# --- Player Starts (Per Team) ---
# Array of PlayerStartData resources
@export var player_starts: Array[Resource] = [] # Array[PlayerStartData]

# --- Ships and Wings ---
# Array of ShipInstanceData resources
@export var ships: Array[Resource] = [] # Array[ShipInstanceData]
# Array of WingInstanceData resources
@export var wings: Array[Resource] = [] # Array[WingInstanceData]

# --- Mission Logic ---
# Array of MissionEventData resources
@export var events: Array[Resource] = [] # Array[MissionEventData]
# Array of MissionObjectiveData resources
@export var goals: Array[Resource] = [] # Array[MissionObjectiveData]
# Array of WaypointListData resources
@export var waypoint_lists: Array[Resource] = [] # Array[WaypointListData]
# Array of SexpVariableData resources
@export var variables: Array[Resource] = [] # Array[SexpVariableData]

# --- Messages and Personas ---
@export var command_sender: String = "Command"
@export var command_persona_name: String = "" # Name of the PersonaData resource
# Array of MessageData resources
@export var messages: Array[Resource] = [] # Array[MessageData]
# Array of PersonaData resources (can be global or mission-specific)
@export var personas: Array[Resource] = [] # Array[PersonaData]

# --- Briefing/Debriefing (Per Team) ---
# Array of BriefingData resources
@export var briefings: Array[Resource] = [] # Array[BriefingData]
# Array of DebriefingData resources
@export var debriefings: Array[Resource] = [] # Array[DebriefingData]

# --- Reinforcements ---
# Array of ReinforcementData resources
@export var reinforcements: Array[Resource] = [] # Array[ReinforcementData]

# --- Other ---
# Array of TextureReplacementData resources
@export var texture_replacements: Array[Resource] = [] # Array[TextureReplacementData]
# Array of String resources (alt names)
@export var alternate_type_names: Array[String] = []
# Array of String resources (callsigns)
@export var callsigns: Array[String] = []

# --- Cutscenes ---
# Array of MissionCutsceneData resources
@export var cutscenes: Array[Resource] = [] # Array[MissionCutsceneData]

# --- Fiction ---
@export var fiction_file: String = ""
@export var fiction_font: String = ""

# --- Command Briefing ---
# Array of CommandBriefingData resources
@export var command_briefings: Array[Resource] = [] # Array[CommandBriefingData]

# --- Asteroid Fields ---
# Array of AsteroidFieldData resources
@export var asteroid_fields: Array[Resource] = [] # Array[AsteroidFieldData]

# --- Jump Nodes ---
# Array of JumpNodeData resources
@export var jump_nodes: Array[Resource] = [] # Array[JumpNodeData]

## Emitted when any mission data changes
signal data_changed(property: String, old_value: Variant, new_value: Variant)

## Emitted when validation status changes
signal validation_changed(is_valid: bool, errors: Array[String])

# Internal validation cache
var _validation_cache: ValidationResult
var _last_validation_hash: int = -1

## Validates the complete mission data structure
## Returns a ValidationResult with detailed information about any issues
func validate() -> ValidationResult:
	var result := ValidationResult.new()
	
	# Check if we need to revalidate
	var current_hash := _calculate_data_hash()
	if _validation_cache and current_hash == _last_validation_hash:
		return _validation_cache
	
	# Validate basic mission info
	if mission_title.is_empty():
		result.add_error("Mission title cannot be empty")
	
	if num_players < 1:
		result.add_error("Mission must have at least one player")
	
	if num_players > 12:
		result.add_warning("Mission has more than 12 players - may cause performance issues")
	
	# Validate ships
	var ship_names: Dictionary = {}
	for i in range(ships.size()):
		var ship := ships[i] as ShipInstanceData
		if not ship:
			result.add_error("Ship at index %d is null" % i)
			continue
		
		# Check for duplicate ship names
		if ship.ship_name in ship_names:
			result.add_error("Duplicate ship name: '%s'" % ship.ship_name)
		else:
			ship_names[ship.ship_name] = true
		
		# Validate ship if it has a validate method
		if ship.has_method("validate"):
			var ship_result := ship.validate() as ValidationResult
			if ship_result:
				result.merge(ship_result)
	
	# Validate wings
	for i in range(wings.size()):
		var wing := wings[i] as WingInstanceData
		if not wing:
			result.add_error("Wing at index %d is null" % i)
			continue
		
		# Validate wing if it has a validate method
		if wing.has_method("validate"):
			var wing_result := wing.validate() as ValidationResult
			if wing_result:
				result.merge(wing_result)
	
	# Validate events
	for i in range(events.size()):
		var event := events[i] as MissionEventData
		if not event:
			result.add_error("Event at index %d is null" % i)
			continue
		
		# Validate event if it has a validate method
		if event.has_method("validate"):
			var event_result := event.validate() as ValidationResult
			if event_result:
				result.merge(event_result)
	
	# Validate goals
	for i in range(goals.size()):
		var goal := goals[i] as MissionObjectiveData
		if not goal:
			result.add_error("Goal at index %d is null" % i)
			continue
		
		# Validate goal if it has a validate method
		if goal.has_method("validate"):
			var goal_result := goal.validate() as ValidationResult
			if goal_result:
				result.merge(goal_result)
	
	# Cache validation result
	_validation_cache = result
	_last_validation_hash = current_hash
	
	# Emit validation signal
	validation_changed.emit(result.is_valid(), result.get_all_errors())
	
	return result

## Gets mission statistics for display
func get_mission_statistics() -> Dictionary:
	return {
		"total_ships": ships.size(),
		"total_wings": wings.size(),
		"total_events": events.size(),
		"total_goals": goals.size(),
		"waypoint_lists": waypoint_lists.size(),
		"variables": variables.size(),
		"player_starts": player_starts.size(),
		"estimated_complexity": _calculate_complexity_score()
	}

## Finds a ship by name
func get_ship_by_name(ship_name: String) -> Resource:
	for ship in ships:
		var ship_data := ship as ShipInstanceData
		if ship_data and ship_data.ship_name == ship_name:
			return ship_data
	return null

## Finds a wing by name
func get_wing_by_name(wing_name: String) -> Resource:
	for wing in wings:
		var wing_data := wing as WingInstanceData
		if wing_data and wing_data.wing_name == wing_name:
			return wing_data
	return null

## Adds a new ship with automatic name generation if needed
func add_ship(ship: Resource) -> void:
	if not ship:
		push_error("Cannot add null ship to mission")
		return
	
	var ship_data := ship as ShipInstanceData
	if ship_data and ship_data.ship_name.is_empty():
		ship_data.ship_name = _generate_unique_ship_name()
	
	ships.append(ship)
	_emit_data_changed("ships", ships.slice(0, -1), ships)

## Adds a new wing with automatic name generation if needed
func add_wing(wing: Resource) -> void:
	if not wing:
		push_error("Cannot add null wing to mission")
		return
	
	var wing_data := wing as WingInstanceData
	if wing_data and wing_data.wing_name.is_empty():
		wing_data.wing_name = _generate_unique_wing_name()
	
	wings.append(wing)
	_emit_data_changed("wings", wings.slice(0, -1), wings)

## Adds a new event
func add_event(event: Resource) -> void:
	if not event:
		push_error("Cannot add null event to mission")
		return
	
	events.append(event)
	_emit_data_changed("events", events.slice(0, -1), events)

## Adds a new goal
func add_goal(goal: Resource) -> void:
	if not goal:
		push_error("Cannot add null goal to mission")
		return
	
	goals.append(goal)
	_emit_data_changed("goals", goals.slice(0, -1), goals)

## Private helper functions

func _generate_unique_ship_name() -> String:
	var counter := 1
	var candidate_name := "Ship " + str(counter)
	
	while get_ship_by_name(candidate_name):
		counter += 1
		candidate_name = "Ship " + str(counter)
	
	return candidate_name

func _generate_unique_wing_name() -> String:
	var counter := 1
	var candidate_name := "Wing " + str(counter)
	
	while get_wing_by_name(candidate_name):
		counter += 1
		candidate_name = "Wing " + str(counter)
	
	return candidate_name

func _calculate_data_hash() -> int:
	# Simple hash based on key properties for validation caching
	var hash_string := ""
	hash_string += mission_title
	hash_string += str(ships.size())
	hash_string += str(wings.size())
	hash_string += str(events.size())
	hash_string += str(goals.size())
	hash_string += str(num_players)
	return hash_string.hash()

func _calculate_complexity_score() -> int:
	# Simple complexity score for performance warnings
	var score := 0
	score += ships.size() * 2
	score += wings.size() * 5
	score += events.size() * 10
	score += goals.size() * 3
	score += waypoint_lists.size() * 2
	score += variables.size()
	return score

func _emit_data_changed(property: String, old_value: Variant, new_value: Variant) -> void:
	# Invalidate validation cache when data changes
	_validation_cache = null
	_last_validation_hash = -1
	
	# Emit change signal
	data_changed.emit(property, old_value, new_value)

## Creates a new empty mission with default values
static func create_empty_mission() -> MissionData:
	var mission := MissionData.new()
	mission.mission_title = "New Mission"
	mission.mission_desc = "A new mission"
	mission.mission_notes = ""
	mission.num_players = 1
	mission.ambient_light_level = Color(0.47, 0.47, 0.47)
	mission.num_stars = 100
	return mission
