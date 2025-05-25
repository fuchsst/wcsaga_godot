class_name CampaignData
extends Resource

## WCS campaign data resource containing campaign progression and mission flow
## Represents a complete campaign with missions, branching, and persistent state

@export var campaign_name: String = ""
@export var campaign_filename: String = ""
@export var campaign_type: String = "single"  # single, multi, template
@export var description: String = ""
@export var briefing_cutscene: String = ""
@export var mainhall: String = ""  # Main hall to use for campaign

# Campaign progression
@export var missions: Array[Dictionary] = []  # Campaign missions
@export var num_players: Array[int] = []  # Number of players for each mission
@export var next_mission: Array[int] = []  # Next mission indices for each mission
@export var loop_reentry: Array[int] = []  # Loop reentry points

# Campaign flags and state
@export var flags: Array[String] = []  # Campaign-wide flags
@export var required_string: String = ""  # Required string for campaign validation
@export var campaign_flags: int = 0  # Campaign behavior flags

# Player progression
@export var starting_ships: Array[String] = []  # Ships available at campaign start
@export var starting_weapons: Array[String] = []  # Weapons available at campaign start
@export var persistent_variables: Dictionary = {}  # Variables that persist across missions

# Campaign branching
@export var branch_info: Array[Dictionary] = []  # Mission branching information
@export var formula: Array[String] = []  # SEXP formulas for mission availability

# Campaign stats tracking
@export var total_missions: int = 0
@export var required_missions: int = 0  # Minimum missions to complete campaign
@export var optional_missions: int = 0

# Fiction and narrative
@export var fiction_files: Array[String] = []  # Associated fiction viewer files
@export var campaign_tree_background: String = ""  # Campaign tree background
@export var campaign_tree_highlight: String = ""  # Campaign tree highlight

func _init() -> void:
	# Initialize arrays if empty
	if missions.is_empty():
		missions = []
	if num_players.is_empty():
		num_players = []
	if next_mission.is_empty():
		next_mission = []
	if loop_reentry.is_empty():
		loop_reentry = []
	if flags.is_empty():
		flags = []
	if starting_ships.is_empty():
		starting_ships = []
	if starting_weapons.is_empty():
		starting_weapons = []
	if persistent_variables.is_empty():
		persistent_variables = {}
	if branch_info.is_empty():
		branch_info = []
	if formula.is_empty():
		formula = []
	if fiction_files.is_empty():
		fiction_files = []

## Utility functions for campaign data

func get_mission_count() -> int:
	"""Get total number of missions in campaign."""
	return missions.size()

func get_mission_data(mission_index: int) -> Dictionary:
	"""Get mission data by index."""
	if mission_index < 0 or mission_index >= missions.size():
		return {}
	
	return missions[mission_index]

func get_mission_by_filename(filename: String) -> Dictionary:
	"""Get mission data by filename."""
	for i in range(missions.size()):
		var mission: Dictionary = missions[i]
		if mission.get("filename", "") == filename:
			mission["index"] = i
			return mission
	
	return {}

func get_starting_mission() -> Dictionary:
	"""Get the first mission in the campaign."""
	if missions.is_empty():
		return {}
	
	var start_mission: Dictionary = missions[0].duplicate()
	start_mission["index"] = 0
	return start_mission

func get_next_missions(current_mission_index: int) -> Array[Dictionary]:
	"""Get possible next missions from current mission."""
	var next_missions: Array[Dictionary] = []
	
	if current_mission_index < 0 or current_mission_index >= next_mission.size():
		return next_missions
	
	var next_index: int = next_mission[current_mission_index]
	
	# Handle branching - may have multiple next missions
	if next_index >= 0 and next_index < missions.size():
		var mission_data: Dictionary = missions[next_index].duplicate()
		mission_data["index"] = next_index
		next_missions.append(mission_data)
	
	# Check for additional branches
	for branch in branch_info:
		if branch.get("from_mission", -1) == current_mission_index:
			var branch_mission: int = branch.get("to_mission", -1)
			if branch_mission >= 0 and branch_mission < missions.size():
				var branch_data: Dictionary = missions[branch_mission].duplicate()
				branch_data["index"] = branch_mission
				branch_data["branch_condition"] = branch.get("condition", "")
				next_missions.append(branch_data)
	
	return next_missions

func is_mission_available(mission_index: int, campaign_state: Dictionary) -> bool:
	"""Check if mission is available based on campaign state."""
	if mission_index < 0 or mission_index >= missions.size():
		return false
	
	# First mission is always available
	if mission_index == 0:
		return true
	
	# Check if mission has been unlocked by completing prerequisites
	var mission_data: Dictionary = missions[mission_index]
	var prereq: String = mission_data.get("prerequisite", "")
	
	if prereq.is_empty():
		return true
	
	# Evaluate prerequisite formula (simplified)
	return evaluate_campaign_formula(prereq, campaign_state)

func get_available_missions(campaign_state: Dictionary) -> Array[Dictionary]:
	"""Get all currently available missions."""
	var available: Array[Dictionary] = []
	
	for i in range(missions.size()):
		if is_mission_available(i, campaign_state):
			var mission_data: Dictionary = missions[i].duplicate()
			mission_data["index"] = i
			available.append(mission_data)
	
	return available

func is_campaign_complete(campaign_state: Dictionary) -> bool:
	"""Check if campaign has been completed."""
	var completed_missions: int = campaign_state.get("completed_missions", 0)
	return completed_missions >= required_missions

func get_campaign_progress(campaign_state: Dictionary) -> float:
	"""Get campaign completion percentage."""
	var completed_missions: int = campaign_state.get("completed_missions", 0)
	if total_missions <= 0:
		return 0.0
	
	return float(completed_missions) / float(total_missions)

func is_multiplayer_campaign() -> bool:
	"""Check if this is a multiplayer campaign."""
	return campaign_type == "multi"

func is_template_campaign() -> bool:
	"""Check if this is a template campaign."""
	return campaign_type == "template"

func get_campaign_difficulty() -> String:
	"""Estimate campaign difficulty based on mission count and structure."""
	var mission_count: int = get_mission_count()
	var branch_count: int = branch_info.size()
	
	if mission_count < 10:
		return "Short"
	elif mission_count < 20:
		return "Medium"
	elif mission_count < 30:
		return "Long"
	else:
		return "Epic"

func get_estimated_play_time() -> float:
	"""Estimate total campaign play time in hours."""
	var base_time_per_mission: float = 15.0  # 15 minutes per mission average
	var total_time: float = float(get_mission_count()) * base_time_per_mission
	
	# Add time for branching complexity
	total_time += float(branch_info.size()) * 5.0
	
	# Convert to hours
	return total_time / 60.0

func get_persistent_variable(var_name: String) -> Variant:
	"""Get a persistent campaign variable."""
	return persistent_variables.get(var_name, null)

func set_persistent_variable(var_name: String, value: Variant) -> void:
	"""Set a persistent campaign variable."""
	persistent_variables[var_name] = value

func has_persistent_variable(var_name: String) -> bool:
	"""Check if persistent variable exists."""
	return persistent_variables.has(var_name)

func clear_persistent_variable(var_name: String) -> void:
	"""Clear a persistent campaign variable."""
	persistent_variables.erase(var_name)

func get_ship_pool() -> Array[String]:
	"""Get available ships for campaign."""
	return starting_ships.duplicate()

func get_weapon_pool() -> Array[String]:
	"""Get available weapons for campaign."""
	return starting_weapons.duplicate()

func add_ship_to_pool(ship_name: String) -> void:
	"""Add ship to available pool."""
	if ship_name not in starting_ships:
		starting_ships.append(ship_name)

func add_weapon_to_pool(weapon_name: String) -> void:
	"""Add weapon to available pool."""
	if weapon_name not in starting_weapons:
		starting_weapons.append(weapon_name)

func remove_ship_from_pool(ship_name: String) -> void:
	"""Remove ship from available pool."""
	starting_ships.erase(ship_name)

func remove_weapon_from_pool(weapon_name: String) -> void:
	"""Remove weapon from available pool."""
	starting_weapons.erase(weapon_name)

func has_campaign_flag(flag_name: String) -> bool:
	"""Check if campaign flag is set."""
	return flag_name in flags

func set_campaign_flag(flag_name: String) -> void:
	"""Set a campaign flag."""
	if flag_name not in flags:
		flags.append(flag_name)

func clear_campaign_flag(flag_name: String) -> void:
	"""Clear a campaign flag."""
	flags.erase(flag_name)

func evaluate_campaign_formula(formula_text: String, campaign_state: Dictionary) -> bool:
	"""Simplified formula evaluation for campaign logic."""
	# This is a simplified implementation - real SEXP evaluation would be more complex
	if formula_text.is_empty():
		return true
	
	# Basic variable checks
	if formula_text.begins_with("is-mission-complete"):
		var mission_name: String = formula_text.split(" ")[1] if " " in formula_text else ""
		return campaign_state.get("completed_missions_list", []).has(mission_name)
	
	if formula_text.begins_with("has-flag"):
		var flag_name: String = formula_text.split(" ")[1] if " " in formula_text else ""
		return has_campaign_flag(flag_name)
	
	# Default to true for unknown formulas
	return true

func get_mission_tree_structure() -> Dictionary:
	"""Get campaign mission tree structure for UI display."""
	var tree: Dictionary = {
		"nodes": [],
		"connections": []
	}
	
	# Add mission nodes
	for i in range(missions.size()):
		var mission: Dictionary = missions[i]
		var node: Dictionary = {
			"id": i,
			"name": mission.get("name", "Mission %d" % (i + 1)),
			"filename": mission.get("filename", ""),
			"position": Vector2(i * 100, 0)  # Simple linear layout
		}
		tree.nodes.append(node)
	
	# Add connections
	for i in range(next_mission.size()):
		var next_idx: int = next_mission[i]
		if next_idx >= 0 and next_idx < missions.size():
			var connection: Dictionary = {
				"from": i,
				"to": next_idx,
				"type": "normal"
			}
			tree.connections.append(connection)
	
	# Add branch connections
	for branch in branch_info:
		var from: int = branch.get("from_mission", -1)
		var to: int = branch.get("to_mission", -1)
		if from >= 0 and to >= 0:
			var connection: Dictionary = {
				"from": from,
				"to": to,
				"type": "branch",
				"condition": branch.get("condition", "")
			}
			tree.connections.append(connection)
	
	return tree

func validate_campaign_integrity() -> Array[String]:
	"""Validate campaign data integrity and return list of issues."""
	var issues: Array[String] = []
	
	# Check for required fields
	if campaign_name.is_empty():
		issues.append("Campaign name is required")
	
	if missions.is_empty():
		issues.append("Campaign must have at least one mission")
	
	# Check mission count consistency
	if num_players.size() != missions.size():
		issues.append("Mission count mismatch: num_players size doesn't match missions")
	
	if next_mission.size() != missions.size():
		issues.append("Mission count mismatch: next_mission size doesn't match missions")
	
	# Validate next mission indices
	for i in range(next_mission.size()):
		var next_idx: int = next_mission[i]
		if next_idx >= missions.size():
			issues.append("Invalid next mission index %d for mission %d" % [next_idx, i])
	
	# Validate branch information
	for branch in branch_info:
		var from: int = branch.get("from_mission", -1)
		var to: int = branch.get("to_mission", -1)
		
		if from < 0 or from >= missions.size():
			issues.append("Invalid branch from mission: %d" % from)
		
		if to < 0 or to >= missions.size():
			issues.append("Invalid branch to mission: %d" % to)
	
	return issues

func clone_with_overrides(overrides: Dictionary) -> CampaignData:
	"""Create a copy of this campaign data with specific property overrides."""
	var clone: CampaignData = CampaignData.new()
	
	# Copy all properties with overrides
	clone.campaign_name = overrides.get("campaign_name", campaign_name)
	clone.campaign_type = overrides.get("campaign_type", campaign_type)
	clone.description = overrides.get("description", description)
	clone.missions = missions.duplicate(true)
	clone.num_players = num_players.duplicate()
	clone.next_mission = next_mission.duplicate()
	clone.starting_ships = starting_ships.duplicate()
	clone.starting_weapons = starting_weapons.duplicate()
	clone.persistent_variables = persistent_variables.duplicate()
	
	return clone

func to_debug_string() -> String:
	"""Get debug information about this campaign."""
	var debug_info: Array[String] = []
	
	debug_info.append("Campaign: %s" % campaign_name)
	debug_info.append("Type: %s" % campaign_type)
	debug_info.append("Missions: %d (Required: %d, Optional: %d)" % [total_missions, required_missions, optional_missions])
	debug_info.append("Branches: %d" % branch_info.size())
	debug_info.append("Difficulty: %s" % get_campaign_difficulty())
	debug_info.append("Est. Time: %.1f hours" % get_estimated_play_time())
	debug_info.append("Starting Ships: %d" % starting_ships.size())
	debug_info.append("Starting Weapons: %d" % starting_weapons.size())
	debug_info.append("Persistent Variables: %d" % persistent_variables.size())
	
	return "\n".join(debug_info)