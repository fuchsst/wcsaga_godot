@tool
class_name CampaignData
extends Resource

## Campaign data structure for GFRED2-008 Campaign Editor Integration.
## Contains all campaign information including missions, prerequisites, and variables.

@export var campaign_name: String = ""
@export var campaign_description: String = ""
@export var campaign_author: String = ""
@export var campaign_version: String = "1.0"
@export var campaign_created_date: String = ""
@export var campaign_modified_date: String = ""
@export var missions: Array[CampaignMission] = []
@export var campaign_variables: Array[CampaignVariable] = []
@export var starting_mission_id: String = ""
@export var campaign_flags: Array[String] = []

signal campaign_data_changed()
signal mission_added(mission: CampaignMission)
signal mission_removed(mission_id: String)
signal variable_added(variable: CampaignVariable)
signal variable_removed(variable_name: String)

func _init() -> void:
	resource_name = "CampaignData"
	campaign_created_date = Time.get_datetime_string_from_system()

## Adds a mission to the campaign
func add_mission(mission: CampaignMission) -> void:
	missions.append(mission)
	campaign_data_changed.emit()
	mission_added.emit(mission)

## Removes a mission from the campaign
func remove_mission(mission_id: String) -> void:
	for i in range(missions.size()):
		if missions[i].mission_id == mission_id:
			# Remove dependencies that reference this mission
			_remove_mission_dependencies(mission_id)
			missions.remove_at(i)
			campaign_data_changed.emit()
			mission_removed.emit(mission_id)
			break

## Gets a mission by ID
func get_mission(mission_id: String) -> CampaignMission:
	for mission in missions:
		if mission.mission_id == mission_id:
			return mission
	return null

## Gets mission by index
func get_mission_at_index(index: int) -> CampaignMission:
	if index >= 0 and index < missions.size():
		return missions[index]
	return null

## Removes dependencies that reference a mission
func _remove_mission_dependencies(mission_id: String) -> void:
	for mission in missions:
		mission.prerequisite_missions.erase(mission_id)
		for branch in mission.mission_branches:
			branch.target_mission_id = "" if branch.target_mission_id == mission_id else branch.target_mission_id

## Adds a campaign variable
func add_campaign_variable(variable: CampaignVariable) -> void:
	campaign_variables.append(variable)
	campaign_data_changed.emit()
	variable_added.emit(variable)

## Removes a campaign variable
func remove_campaign_variable(variable_name: String) -> void:
	for i in range(campaign_variables.size()):
		if campaign_variables[i].variable_name == variable_name:
			campaign_variables.remove_at(i)
			campaign_data_changed.emit()
			variable_removed.emit(variable_name)
			break

## Gets a campaign variable by name
func get_campaign_variable(variable_name: String) -> CampaignVariable:
	for variable in campaign_variables:
		if variable.variable_name == variable_name:
			return variable
	return null

## Validates campaign data
func validate_campaign() -> Array[String]:
	var errors: Array[String] = []
	
	if campaign_name.is_empty():
		errors.append("Campaign must have a name")
	
	if missions.is_empty():
		errors.append("Campaign must have at least one mission")
	
	if starting_mission_id.is_empty():
		errors.append("Campaign must have a starting mission")
	elif not get_mission(starting_mission_id):
		errors.append("Starting mission ID '%s' does not exist" % starting_mission_id)
	
	# Validate mission structure
	for i in range(missions.size()):
		var mission: CampaignMission = missions[i]
		var mission_errors: Array[String] = mission.validate_mission()
		for error in mission_errors:
			errors.append("Mission %d (%s): %s" % [i + 1, mission.mission_name, error])
	
	# Check for circular dependencies
	var circular_deps: Array[String] = _detect_circular_dependencies()
	errors.append_array(circular_deps)
	
	# Validate variable references
	var variable_errors: Array[String] = _validate_variable_references()
	errors.append_array(variable_errors)
	
	return errors

## Detects circular dependencies in mission prerequisites
func _detect_circular_dependencies() -> Array[String]:
	var errors: Array[String] = []
	var visited: Dictionary = {}
	var in_progress: Dictionary = {}
	
	for mission in missions:
		if not visited.has(mission.mission_id):
			var cycle: Array[String] = _find_dependency_cycle(mission.mission_id, visited, in_progress, [])
			if not cycle.is_empty():
				errors.append("Circular dependency detected: %s" % " -> ".join(cycle))
	
	return errors

## Finds dependency cycles using DFS
func _find_dependency_cycle(mission_id: String, visited: Dictionary, in_progress: Dictionary, path: Array[String]) -> Array[String]:
	if in_progress.has(mission_id):
		# Found cycle
		var cycle_start: int = path.find(mission_id)
		return path.slice(cycle_start) + [mission_id]
	
	if visited.has(mission_id):
		return []
	
	visited[mission_id] = true
	in_progress[mission_id] = true
	path.append(mission_id)
	
	var mission: CampaignMission = get_mission(mission_id)
	if mission:
		for prerequisite_id in mission.prerequisite_missions:
			var cycle: Array[String] = _find_dependency_cycle(prerequisite_id, visited, in_progress, path)
			if not cycle.is_empty():
				return cycle
	
	in_progress.erase(mission_id)
	path.pop_back()
	return []

## Validates variable references in missions
func _validate_variable_references() -> Array[String]:
	var errors: Array[String] = []
	var variable_names: Array[String] = []
	
	for variable in campaign_variables:
		variable_names.append(variable.variable_name)
	
	for mission in missions:
		for branch in mission.mission_branches:
			# TODO: Parse SEXP conditions to find variable references
			# This would integrate with EPIC-004 SEXP system
			pass
	
	return errors

## Gets missions that depend on a specific mission
func get_dependent_missions(mission_id: String) -> Array[CampaignMission]:
	var dependents: Array[CampaignMission] = []
	
	for mission in missions:
		if mission.prerequisite_missions.has(mission_id):
			dependents.append(mission)
		
		for branch in mission.mission_branches:
			if branch.target_mission_id == mission_id:
				dependents.append(mission)
				break
	
	return dependents

## Gets missions that have no prerequisites (starting points)
func get_starting_missions() -> Array[CampaignMission]:
	var starting: Array[CampaignMission] = []
	
	for mission in missions:
		if mission.prerequisite_missions.is_empty():
			starting.append(mission)
	
	return starting

## Updates campaign modification date
func update_modification_date() -> void:
	campaign_modified_date = Time.get_datetime_string_from_system()
	campaign_data_changed.emit()

## Duplicates campaign data
func duplicate_campaign() -> CampaignData:
	var duplicate: CampaignData = CampaignData.new()
	duplicate.campaign_name = campaign_name + " (Copy)"
	duplicate.campaign_description = campaign_description
	duplicate.campaign_author = campaign_author
	duplicate.campaign_version = campaign_version
	duplicate.campaign_created_date = Time.get_datetime_string_from_system()
	
	for mission in missions:
		duplicate.missions.append(mission.duplicate_mission())
	
	for variable in campaign_variables:
		duplicate.campaign_variables.append(variable.duplicate_variable())
	
	duplicate.starting_mission_id = starting_mission_id
	duplicate.campaign_flags = campaign_flags.duplicate()
	
	return duplicate

class CampaignMission extends Resource:

	## Individual mission within a campaign.

	@export var mission_id: String = ""
	@export var mission_name: String = ""
	@export var mission_filename: String = ""
	@export var mission_description: String = ""
	@export var mission_author: String = ""
	@export var position: Vector2 = Vector2.ZERO  # Position in campaign flow diagram
	@export var prerequisite_missions: Array[String] = []
	@export var mission_branches: Array[CampaignMissionBranch] = []
	@export var mission_flags: Array[String] = []
	@export var is_required: bool = true
	@export var difficulty_level: int = 1
	@export var mission_briefing_text: String = ""
	@export var mission_debriefing_text: String = ""

	func _init() -> void:
		resource_name = "CampaignMission"
		if mission_id.is_empty():
			mission_id = "mission_%d" % (Time.get_ticks_msec() % 100000)

	## Validates mission data
	func validate_mission() -> Array[String]:
		var errors: Array[String] = []
		
		if mission_id.is_empty():
			errors.append("Mission must have an ID")
		
		if mission_name.is_empty():
			errors.append("Mission must have a name")
		
		if mission_filename.is_empty():
			errors.append("Mission must have a filename")
		
		# Validate mission branches
		for i in range(mission_branches.size()):
			var branch: CampaignMissionBranch = mission_branches[i]
			var branch_errors: Array[String] = branch.validate_branch()
			for error in branch_errors:
				errors.append("Branch %d: %s" % [i + 1, error])
		
		return errors

	## Adds a prerequisite mission
	func add_prerequisite(mission_id: String) -> void:
		if not prerequisite_missions.has(mission_id):
			prerequisite_missions.append(mission_id)

	## Removes a prerequisite mission
	func remove_prerequisite(mission_id: String) -> void:
		prerequisite_missions.erase(mission_id)

	## Adds a mission branch
	func add_mission_branch(branch: CampaignMissionBranch) -> void:
		mission_branches.append(branch)

	## Removes a mission branch
	func remove_mission_branch(branch_index: int) -> void:
		if branch_index >= 0 and branch_index < mission_branches.size():
			mission_branches.remove_at(branch_index)

	## Duplicates mission data
	func duplicate_mission() -> CampaignMission:
		var duplicate: CampaignMission = CampaignMission.new()
		duplicate.mission_id = mission_id + "_copy"
		duplicate.mission_name = mission_name + " (Copy)"
		duplicate.mission_filename = mission_filename
		duplicate.mission_description = mission_description
		duplicate.mission_author = mission_author
		duplicate.position = position + Vector2(50, 50)  # Offset copy position
		duplicate.prerequisite_missions = prerequisite_missions.duplicate()
		duplicate.mission_flags = mission_flags.duplicate()
		duplicate.is_required = is_required
		duplicate.difficulty_level = difficulty_level
		duplicate.mission_briefing_text = mission_briefing_text
		duplicate.mission_debriefing_text = mission_debriefing_text
		
		for branch in mission_branches:
			duplicate.mission_branches.append(branch.duplicate_branch())
		
		return duplicate

class CampaignMissionBranch extends Resource:
## Branching logic for campaign missions.

	enum BranchType {
		SUCCESS,    # Mission completed successfully
		FAILURE,    # Mission failed
		CONDITION   # Custom SEXP condition
	}

	@export var branch_type: BranchType = BranchType.SUCCESS
	@export var target_mission_id: String = ""
	@export var branch_condition: String = ""  # SEXP expression for conditional branches
	@export var branch_description: String = ""
	@export var is_enabled: bool = true

	func _init() -> void:
		resource_name = "CampaignMissionBranch"

	## Validates branch data
	func validate_branch() -> Array[String]:
		var errors: Array[String] = []
		
		if target_mission_id.is_empty():
			errors.append("Branch must have a target mission")
		
		if branch_type == BranchType.CONDITION and branch_condition.is_empty():
			errors.append("Conditional branch must have a condition expression")
		
		return errors

	## Duplicates branch data
	func duplicate_branch() -> CampaignMissionBranch:
		var duplicate: CampaignMissionBranch = CampaignMissionBranch.new()
		duplicate.branch_type = branch_type
		duplicate.target_mission_id = target_mission_id
		duplicate.branch_condition = branch_condition
		duplicate.branch_description = branch_description
		duplicate.is_enabled = is_enabled
		return duplicate

class CampaignVariable extends Resource:
## Campaign-wide variable for persistent state.

	enum VariableType {
		INTEGER,
		FLOAT,
		BOOLEAN,
		STRING
	}

	@export var variable_name: String = ""
	@export var variable_type: VariableType = VariableType.INTEGER
	@export var initial_value: String = "0"
	@export var description: String = ""
	@export var is_persistent: bool = true

	func _init() -> void:
		resource_name = "CampaignVariable"

	## Validates variable data
	func validate_variable() -> Array[String]:
		var errors: Array[String] = []
		
		if variable_name.is_empty():
			errors.append("Variable must have a name")
		
		# Validate initial value format
		match variable_type:
			VariableType.INTEGER:
				if not initial_value.is_valid_int():
					errors.append("Initial value must be a valid integer")
			VariableType.FLOAT:
				if not initial_value.is_valid_float():
					errors.append("Initial value must be a valid float")
			VariableType.BOOLEAN:
				if not (initial_value.to_lower() in ["true", "false", "0", "1"]):
					errors.append("Initial value must be a valid boolean (true/false/0/1)")
		
		return errors

	## Gets the typed initial value
	func get_typed_initial_value() -> Variant:
		match variable_type:
			VariableType.INTEGER:
				return initial_value.to_int()
			VariableType.FLOAT:
				return initial_value.to_float()
			VariableType.BOOLEAN:
				return initial_value.to_lower() in ["true", "1"]
			VariableType.STRING:
				return initial_value
		return null

	## Duplicates variable data
	func duplicate_variable() -> CampaignVariable:
		var duplicate: CampaignVariable = CampaignVariable.new()
		duplicate.variable_name = variable_name
		duplicate.variable_type = variable_type
		duplicate.initial_value = initial_value
		duplicate.description = description
		duplicate.is_persistent = is_persistent
		return duplicate
