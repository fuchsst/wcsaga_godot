class_name CampaignState
extends Resource

## Campaign state resource for tracking campaign progression and mission states.
## Contains all persistent campaign data including mission completion, variables, and player choices.

signal mission_completed(mission_index: int)
signal variable_changed(variable_name: String, old_value: Variant, new_value: Variant)
signal campaign_branch_changed(branch_name: String)

# --- Campaign Identity ---
@export var campaign_filename: String = ""      ## .fsc campaign filename
@export var campaign_name: String = ""          ## Display name of campaign
@export var campaign_version: String = ""       ## Campaign version string
@export var campaign_author: String = ""        ## Campaign author

# --- Mission Progression ---
@export var current_mission_index: int = 0      ## Current mission index (0-based)
@export var current_mission_name: String = ""   ## Current mission filename
@export var total_missions: int = 0             ## Total missions in campaign
@export var missions_completed: PackedInt32Array = [] ## Completed missions bitmask
@export var mission_results: Array[Dictionary] = [] ## Results for each completed mission

# --- Campaign Variables (SEXP Variables) ---
@export var persistent_variables: Dictionary = {} ## Campaign-persistent SEXP variables
@export var mission_variables: Dictionary = {}   ## Current mission variables
@export var player_choices: Dictionary = {}      ## Player choice tracking

# --- Campaign Branches and Loops ---
@export var current_branch: String = "main"     ## Current campaign branch
@export var branch_history: Array[String] = []  ## History of branches taken
@export var loop_counters: Dictionary = {}      ## Mission loop counters
@export var conditional_missions: Dictionary = {} ## Conditional mission unlock status

# --- Ship and Equipment Persistence ---
@export var persistent_ships: Array[Dictionary] = [] ## Ships that carry between missions
@export var persistent_loadouts: Dictionary = {} ## Equipment loadouts that persist
@export var wingman_status: Dictionary = {}      ## Wingman alive/dead status
@export var ship_modifications: Dictionary = {}  ## Player ship modifications

# --- Campaign Statistics ---
@export var campaign_score: int = 0             ## Total campaign score
@export var campaign_start_time: int = 0        ## Unix timestamp of campaign start
@export var campaign_playtime: float = 0.0      ## Total campaign playtime in seconds
@export var best_mission_scores: Array[int] = [] ## Best score for each mission

# --- Story and Narrative State ---
@export var story_flags: Dictionary = {}        ## Story progression flags
@export var character_relationships: Dictionary = {} ## Character relationship values
@export var narrative_choices: Array[Dictionary] = [] ## Important narrative choices made
@export var cutscenes_viewed: Array[String] = [] ## Cutscenes already viewed

# --- Technical State ---
@export var save_version: int = 1               ## Save format version
@export var last_save_time: int = 0             ## Unix timestamp of last save
@export var checkpoints: Array[Dictionary] = [] ## Mission checkpoints

func _init() -> void:
	campaign_start_time = Time.get_unix_time_from_system()
	last_save_time = campaign_start_time
	current_branch = "main"
	branch_history.append("main")

## Initialize campaign state from campaign file data
func initialize_from_campaign_data(campaign_data: Dictionary) -> void:
	if campaign_data.has("campaign_name"):
		campaign_name = campaign_data.campaign_name
	if campaign_data.has("campaign_filename"):
		campaign_filename = campaign_data.campaign_filename
	if campaign_data.has("version"):
		campaign_version = campaign_data.version
	if campaign_data.has("author"):
		campaign_author = campaign_data.author
	if campaign_data.has("total_missions"):
		total_missions = campaign_data.total_missions
		
	# Initialize mission completion tracking
	var required_size: int = (total_missions + 31) / 32  # Round up for bitmask
	missions_completed.resize(required_size)
	missions_completed.fill(0)
	
	# Initialize mission results array
	mission_results.resize(total_missions)
	for i in range(total_missions):
		mission_results[i] = {}
	
	# Initialize best scores array
	best_mission_scores.resize(total_missions)
	best_mission_scores.fill(0)

## Check if a specific mission is completed
func is_mission_completed(mission_index: int) -> bool:
	if mission_index < 0 or mission_index >= total_missions:
		return false
	
	var array_index: int = mission_index / 32
	var bit_index: int = mission_index % 32
	
	if array_index >= missions_completed.size():
		return false
	
	return (missions_completed[array_index] & (1 << bit_index)) != 0

## Mark a mission as completed
func complete_mission(mission_index: int, mission_result: Dictionary = {}) -> void:
	if mission_index < 0 or mission_index >= total_missions:
		return
	
	# Set completion bit
	var array_index: int = mission_index / 32
	var bit_index: int = mission_index % 32
	
	# Ensure array is large enough
	while array_index >= missions_completed.size():
		missions_completed.append(0)
	
	missions_completed[array_index] |= (1 << bit_index)
	
	# Store mission result
	if mission_index < mission_results.size():
		mission_results[mission_index] = mission_result
		
		# Update best score if provided
		if mission_result.has("score") and mission_index < best_mission_scores.size():
			var score: int = mission_result.score
			if score > best_mission_scores[mission_index]:
				best_mission_scores[mission_index] = score
				
		# Update campaign score
		if mission_result.has("score"):
			campaign_score += mission_result.score
	
	mission_completed.emit(mission_index)

## Advance to next mission
func advance_to_mission(mission_index: int, mission_name: String = "") -> void:
	current_mission_index = mission_index
	current_mission_name = mission_name
	last_save_time = Time.get_unix_time_from_system()

## Set campaign variable (SEXP variable)
func set_variable(variable_name: String, value: Variant, persistent: bool = false) -> void:
	var old_value: Variant = null
	
	if persistent:
		old_value = persistent_variables.get(variable_name, null)
		persistent_variables[variable_name] = value
	else:
		old_value = mission_variables.get(variable_name, null)
		mission_variables[variable_name] = value
	
	variable_changed.emit(variable_name, old_value, value)

## Get campaign variable value
func get_variable(variable_name: String, default_value: Variant = null) -> Variant:
	# Check persistent variables first, then mission variables
	if persistent_variables.has(variable_name):
		return persistent_variables[variable_name]
	elif mission_variables.has(variable_name):
		return mission_variables[variable_name]
	else:
		return default_value

## Clear mission variables (called at mission start)
func clear_mission_variables() -> void:
	mission_variables.clear()

## Set story flag
func set_story_flag(flag_name: String, value: bool) -> void:
	story_flags[flag_name] = value

## Check story flag
func get_story_flag(flag_name: String, default_value: bool = false) -> bool:
	return story_flags.get(flag_name, default_value)

## Record player choice
func record_player_choice(choice_id: String, choice_data: Dictionary) -> void:
	player_choices[choice_id] = choice_data
	
	# Add to narrative choices if significant
	if choice_data.get("significant", false):
		var narrative_choice: Dictionary = {
			"id": choice_id,
			"mission": current_mission_name,
			"timestamp": Time.get_unix_time_from_system(),
			"data": choice_data
		}
		narrative_choices.append(narrative_choice)

## Get player choice
func get_player_choice(choice_id: String) -> Dictionary:
	return player_choices.get(choice_id, {})

## Change campaign branch
func change_branch(branch_name: String) -> void:
	if current_branch != branch_name:
		current_branch = branch_name
		branch_history.append(branch_name)
		campaign_branch_changed.emit(branch_name)

## Add persistent ship
func add_persistent_ship(ship_data: Dictionary) -> void:
	# Remove existing ship with same name
	for i in range(persistent_ships.size() - 1, -1, -1):
		if persistent_ships[i].get("name", "") == ship_data.get("name", ""):
			persistent_ships.remove_at(i)
	
	# Add new ship data
	persistent_ships.append(ship_data)

## Get persistent ship data
func get_persistent_ship(ship_name: String) -> Dictionary:
	for ship in persistent_ships:
		if ship.get("name", "") == ship_name:
			return ship
	return {}

## Remove persistent ship
func remove_persistent_ship(ship_name: String) -> bool:
	for i in range(persistent_ships.size()):
		if persistent_ships[i].get("name", "") == ship_name:
			persistent_ships.remove_at(i)
			return true
	return false

## Set wingman status
func set_wingman_status(wingman_name: String, status: String) -> void:
	wingman_status[wingman_name] = {
		"status": status,  # "alive", "dead", "missing", "retired"
		"last_mission": current_mission_name,
		"timestamp": Time.get_unix_time_from_system()
	}

## Get wingman status
func get_wingman_status(wingman_name: String) -> String:
	var status_data: Dictionary = wingman_status.get(wingman_name, {})
	return status_data.get("status", "alive")

## Create mission checkpoint
func create_checkpoint(checkpoint_name: String, checkpoint_data: Dictionary = {}) -> void:
	var checkpoint: Dictionary = {
		"name": checkpoint_name,
		"mission_index": current_mission_index,
		"mission_name": current_mission_name,
		"timestamp": Time.get_unix_time_from_system(),
		"variables": mission_variables.duplicate(),
		"data": checkpoint_data
	}
	
	checkpoints.append(checkpoint)
	
	# Limit checkpoint count to prevent memory bloat
	if checkpoints.size() > 10:
		checkpoints.remove_at(0)

## Get campaign completion percentage
func get_completion_percentage() -> float:
	if total_missions <= 0:
		return 0.0
	
	var completed_count: int = 0
	for i in range(total_missions):
		if is_mission_completed(i):
			completed_count += 1
	
	return float(completed_count) / float(total_missions)

## Get missions completed count
func get_missions_completed_count() -> int:
	var count: int = 0
	for i in range(total_missions):
		if is_mission_completed(i):
			count += 1
	return count

## Validate campaign state
func validate_campaign_state() -> Dictionary:
	var validation_result: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Validate basic data
	if campaign_filename.is_empty():
		validation_result.errors.append("Campaign filename is empty")
		validation_result.is_valid = false
	
	if total_missions <= 0:
		validation_result.errors.append("Invalid total missions count")
		validation_result.is_valid = false
	
	if current_mission_index < 0 or current_mission_index >= total_missions:
		validation_result.warnings.append("Current mission index out of range")
		current_mission_index = clampi(current_mission_index, 0, total_missions - 1)
	
	# Validate arrays
	if mission_results.size() != total_missions:
		validation_result.warnings.append("Mission results array size mismatch")
		mission_results.resize(total_missions)
	
	if best_mission_scores.size() != total_missions:
		validation_result.warnings.append("Best scores array size mismatch")
		best_mission_scores.resize(total_missions)
	
	# Validate completion data
	var required_size: int = (total_missions + 31) / 32
	if missions_completed.size() != required_size:
		validation_result.warnings.append("Missions completed array size incorrect")
		missions_completed.resize(required_size)
	
	# Validate timestamps
	if campaign_start_time <= 0:
		validation_result.warnings.append("Invalid campaign start time")
		campaign_start_time = Time.get_unix_time_from_system()
	
	if last_save_time < campaign_start_time:
		validation_result.warnings.append("Last save time before campaign start")
		last_save_time = Time.get_unix_time_from_system()
	
	# Validate playtime
	if campaign_playtime < 0:
		validation_result.warnings.append("Invalid campaign playtime")
		campaign_playtime = 0.0
	
	return validation_result

## Export campaign state to dictionary
func export_to_dictionary() -> Dictionary:
	return {
		"metadata": {
			"campaign_filename": campaign_filename,
			"campaign_name": campaign_name,
			"campaign_version": campaign_version,
			"campaign_author": campaign_author,
			"save_version": save_version
		},
		"progression": {
			"current_mission_index": current_mission_index,
			"current_mission_name": current_mission_name,
			"total_missions": total_missions,
			"missions_completed": missions_completed,
			"mission_results": mission_results,
			"best_mission_scores": best_mission_scores,
			"campaign_score": campaign_score,
			"completion_percentage": get_completion_percentage()
		},
		"variables": {
			"persistent_variables": persistent_variables,
			"mission_variables": mission_variables,
			"player_choices": player_choices
		},
		"narrative": {
			"current_branch": current_branch,
			"branch_history": branch_history,
			"story_flags": story_flags,
			"character_relationships": character_relationships,
			"narrative_choices": narrative_choices,
			"cutscenes_viewed": cutscenes_viewed
		},
		"ships": {
			"persistent_ships": persistent_ships,
			"persistent_loadouts": persistent_loadouts,
			"wingman_status": wingman_status,
			"ship_modifications": ship_modifications
		},
		"timing": {
			"campaign_start_time": campaign_start_time,
			"campaign_playtime": campaign_playtime,
			"last_save_time": last_save_time
		},
		"checkpoints": checkpoints
	}

## Import campaign state from dictionary
func import_from_dictionary(data: Dictionary) -> bool:
	if not data.has("metadata") or not data.has("progression"):
		return false
	
	var metadata: Dictionary = data.metadata
	var progression: Dictionary = data.progression
	
	# Import metadata
	campaign_filename = metadata.get("campaign_filename", "")
	campaign_name = metadata.get("campaign_name", "")
	campaign_version = metadata.get("campaign_version", "")
	campaign_author = metadata.get("campaign_author", "")
	save_version = metadata.get("save_version", 1)
	
	# Import progression
	current_mission_index = progression.get("current_mission_index", 0)
	current_mission_name = progression.get("current_mission_name", "")
	total_missions = progression.get("total_missions", 0)
	missions_completed = progression.get("missions_completed", PackedInt32Array())
	mission_results = progression.get("mission_results", [])
	best_mission_scores = progression.get("best_mission_scores", [])
	campaign_score = progression.get("campaign_score", 0)
	
	# Import variables
	if data.has("variables"):
		var variables: Dictionary = data.variables
		persistent_variables = variables.get("persistent_variables", {})
		mission_variables = variables.get("mission_variables", {})
		player_choices = variables.get("player_choices", {})
	
	# Import narrative
	if data.has("narrative"):
		var narrative: Dictionary = data.narrative
		current_branch = narrative.get("current_branch", "main")
		branch_history = narrative.get("branch_history", ["main"])
		story_flags = narrative.get("story_flags", {})
		character_relationships = narrative.get("character_relationships", {})
		narrative_choices = narrative.get("narrative_choices", [])
		cutscenes_viewed = narrative.get("cutscenes_viewed", [])
	
	# Import ships
	if data.has("ships"):
		var ships: Dictionary = data.ships
		persistent_ships = ships.get("persistent_ships", [])
		persistent_loadouts = ships.get("persistent_loadouts", {})
		wingman_status = ships.get("wingman_status", {})
		ship_modifications = ships.get("ship_modifications", {})
	
	# Import timing
	if data.has("timing"):
		var timing: Dictionary = data.timing
		campaign_start_time = timing.get("campaign_start_time", Time.get_unix_time_from_system())
		campaign_playtime = timing.get("campaign_playtime", 0.0)
		last_save_time = timing.get("last_save_time", Time.get_unix_time_from_system())
	
	# Import checkpoints
	checkpoints = data.get("checkpoints", [])
	
	var validation: Dictionary = validate_campaign_state()
	return validation.is_valid

## Reset campaign state for new campaign
func reset_for_new_campaign() -> void:
	current_mission_index = 0
	current_mission_name = ""
	missions_completed.fill(0)
	mission_results.clear()
	best_mission_scores.fill(0)
	
	persistent_variables.clear()
	mission_variables.clear()
	player_choices.clear()
	
	current_branch = "main"
	branch_history = ["main"]
	story_flags.clear()
	character_relationships.clear()
	narrative_choices.clear()
	cutscenes_viewed.clear()
	
	persistent_ships.clear()
	persistent_loadouts.clear()
	wingman_status.clear()
	ship_modifications.clear()
	
	campaign_score = 0
	campaign_start_time = Time.get_unix_time_from_system()
	campaign_playtime = 0.0
	last_save_time = campaign_start_time
	
	checkpoints.clear()

## Get summary for save slot display
func get_summary_for_save_slot() -> Dictionary:
	return {
		"campaign_name": campaign_name,
		"campaign_filename": campaign_filename,
		"current_mission_name": current_mission_name,
		"current_mission_index": current_mission_index,
		"completion_percentage": get_completion_percentage(),
		"missions_completed": get_missions_completed_count(),
		"total_missions": total_missions,
		"campaign_score": campaign_score,
		"playtime": campaign_playtime
	}