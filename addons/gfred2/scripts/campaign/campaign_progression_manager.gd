@tool
class_name CampaignProgressionManager
extends RefCounted

## Campaign progression manager for GFRED2-008 Campaign Editor Integration.
## Handles mission unlocking, progression logic, and campaign state management.

signal mission_unlocked(mission_id: String)
signal mission_completed(mission_id: String, success: bool)
signal campaign_completed()
signal progression_state_changed()

# Campaign progression state
var campaign_data: CampaignData = null
var mission_states: Dictionary = {}  # mission_id -> MissionState
var campaign_variables: Dictionary = {}  # variable_name -> value
var current_mission: String = ""
var completed_missions: Array[String] = []
var unlocked_missions: Array[String] = []

## Represents the state of a mission in the campaign
class MissionState:
	var mission_id: String = ""
	var status: Status = Status.LOCKED
	var attempts: int = 0
	var best_score: float = 0.0
	var completion_time: String = ""
	
	enum Status {
		LOCKED,     # Mission not yet available
		UNLOCKED,   # Mission available to play
		COMPLETED,  # Mission completed successfully
		FAILED,     # Mission failed (if allowed)
		SKIPPED     # Mission skipped (optional missions)
	}
	
	func _init(id: String = ""):
		mission_id = id

## Initializes the progression manager with campaign data
func setup_campaign_progression(target_campaign: CampaignData) -> void:
	campaign_data = target_campaign
	if not campaign_data:
		return
	
	# Initialize mission states
	_initialize_mission_states()
	
	# Initialize campaign variables
	_initialize_campaign_variables()
	
	# Determine initial unlocked missions
	_calculate_initial_progression()
	
	print("CampaignProgressionManager: Initialized for campaign: %s" % campaign_data.campaign_name)

## Initializes mission states for all missions
func _initialize_mission_states() -> void:
	mission_states.clear()
	completed_missions.clear()
	unlocked_missions.clear()
	
	for mission in campaign_data.missions:
		var state: MissionState = MissionState.new(mission.mission_id)
		mission_states[mission.mission_id] = state

## Initializes campaign variables with default values
func _initialize_campaign_variables() -> void:
	campaign_variables.clear()
	
	for variable in campaign_data.campaign_variables:
		campaign_variables[variable.variable_name] = variable.get_typed_initial_value()

## Calculates initial mission progression state
func _calculate_initial_progression() -> void:
	# Find starting missions (missions with no prerequisites)
	var starting_missions: Array[CampaignMissionData] = campaign_data.get_starting_missions()
	
	# Unlock starting missions
	for mission in starting_missions:
		_unlock_mission(mission.mission_id, false)  # Don't emit signal during initialization
	
	# Set current mission to the campaign's starting mission if specified
	if not campaign_data.starting_mission_id.is_empty():
		current_mission = campaign_data.starting_mission_id
		_unlock_mission(current_mission, false)

## Unlocks a mission
func _unlock_mission(mission_id: String, emit_signal: bool = true) -> void:
	var state: MissionState = mission_states.get(mission_id)
	if not state:
		return
	
	if state.status == MissionState.Status.LOCKED:
		state.status = MissionState.Status.UNLOCKED
		unlocked_missions.append(mission_id)
		
		if emit_signal:
			mission_unlocked.emit(mission_id)
			progression_state_changed.emit()
		
		print("CampaignProgressionManager: Mission unlocked: %s" % mission_id)

## Completes a mission and processes progression
func complete_mission(mission_id: String, success: bool, score: float = 0.0) -> void:
	var state: MissionState = mission_states.get(mission_id)
	if not state:
		print("CampaignProgressionManager: Unknown mission: %s" % mission_id)
		return
	
	# Update mission state
	if success:
		state.status = MissionState.Status.COMPLETED
		state.best_score = max(state.best_score, score)
		state.completion_time = Time.get_datetime_string_from_system()
		
		if not completed_missions.has(mission_id):
			completed_missions.append(mission_id)
	else:
		state.status = MissionState.Status.FAILED
	
	state.attempts += 1
	
	# Process mission completion effects
	_process_mission_completion(mission_id, success)
	
	# Check for newly unlocked missions
	_update_mission_availability()
	
	# Check if campaign is complete
	_check_campaign_completion()
	
	mission_completed.emit(mission_id, success)
	progression_state_changed.emit()
	
	print("CampaignProgressionManager: Mission %s: %s" % [mission_id, "completed" if success else "failed"])

## Processes mission completion effects (branches, variables)
func _process_mission_completion(mission_id: String, success: bool) -> void:
	var mission: CampaignMissionData = campaign_data.get_mission(mission_id)
	if not mission:
		return
	
	# Process mission branches
	for branch in mission.mission_branches:
		if not branch.is_enabled:
			continue
		
		var should_trigger: bool = false
		
		match branch.branch_type:
			CampaignMissionDataBranch.BranchType.SUCCESS:
				should_trigger = success
			CampaignMissionDataBranch.BranchType.FAILURE:
				should_trigger = not success
			CampaignMissionDataBranch.BranchType.CONDITION:
				should_trigger = _evaluate_branch_condition(branch.branch_condition)
		
		if should_trigger and not branch.target_mission_id.is_empty():
			# Trigger branch - this could unlock new missions or set variables
			_trigger_mission_branch(branch)

## Evaluates a branch condition using SEXP system
func _evaluate_branch_condition(condition: String) -> bool:
	if condition.is_empty():
		return false
	
	# TODO: Integrate with EPIC-004 SEXP system for condition evaluation
	# For now, simple placeholder evaluation
	
	# Replace campaign variables in the condition
	var processed_condition: String = condition
	for var_name in campaign_variables:
		var var_value: String = str(campaign_variables[var_name])
		processed_condition = processed_condition.replace("$" + var_name, var_value)
	
	# Simple condition evaluation (placeholder)
	# Real implementation would use SexpManager.evaluate_expression()
	if processed_condition.contains("true"):
		return true
	elif processed_condition.contains("false"):
		return false
	
	# Default to true for testing
	return true

## Triggers a mission branch
func _trigger_mission_branch(branch: CampaignMissionDataBranch) -> void:
	# The branch target should be unlocked
	if not branch.target_mission_id.is_empty():
		_unlock_mission(branch.target_mission_id)
	
	# TODO: Process branch effects (set variables, trigger events)
	print("CampaignProgressionManager: Branch triggered: %s -> %s" % [branch.branch_description, branch.target_mission_id])

## Updates mission availability based on prerequisites
func _update_mission_availability() -> void:
	for mission in campaign_data.missions:
		var state: MissionState = mission_states.get(mission.mission_id)
		if not state or state.status != MissionState.Status.LOCKED:
			continue
		
		# Check if all prerequisites are met
		if _are_prerequisites_met(mission):
			_unlock_mission(mission.mission_id)

## Checks if mission prerequisites are satisfied
func _are_prerequisites_met(mission: CampaignMissionData) -> bool:
	for prerequisite_id in mission.prerequisite_missions:
		var prerequisite_state: MissionState = mission_states.get(prerequisite_id)
		if not prerequisite_state or prerequisite_state.status != MissionState.Status.COMPLETED:
			return false
	
	return true

## Checks if the campaign is complete
func _check_campaign_completion() -> void:
	# Campaign is complete when all required missions are finished
	var all_required_complete: bool = true
	
	for mission in campaign_data.missions:
		if mission.is_required:
			var state: MissionState = mission_states.get(mission.mission_id)
			if not state or state.status != MissionState.Status.COMPLETED:
				all_required_complete = false
				break
	
	if all_required_complete:
		campaign_completed.emit()
		print("CampaignProgressionManager: Campaign completed!")

## Sets a campaign variable value
func set_campaign_variable(variable_name: String, value: Variant) -> void:
	var variable: SexpVariableData = campaign_data.get_campaign_variable(variable_name)
	if not variable:
		print("CampaignProgressionManager: Unknown variable: %s" % variable_name)
		return
	
	# Type checking
	var old_value: Variant = campaign_variables.get(variable_name)
	match variable.type:
		"number":
			if value is int:
				campaign_variables[variable_name] = value
		"float":
			if value is float or value is int:
				campaign_variables[variable_name] = float(value)
		"boolean":
			if value is bool:
				campaign_variables[variable_name] = value
		"string":
			campaign_variables[variable_name] = str(value)
	
	if campaign_variables.get(variable_name) != old_value:
		progression_state_changed.emit()
		print("CampaignProgressionManager: Variable set: %s = %s" % [variable_name, str(value)])

## Gets a campaign variable value
func get_campaign_variable(variable_name: String) -> Variant:
	return campaign_variables.get(variable_name)

## Gets all campaign variables
func get_all_campaign_variables() -> Dictionary:
	return campaign_variables.duplicate()

## Skips an optional mission
func skip_mission(mission_id: String) -> void:
	var mission: CampaignMissionData = campaign_data.get_mission(mission_id)
	if not mission or mission.is_required:
		print("CampaignProgressionManager: Cannot skip required mission: %s" % mission_id)
		return
	
	var state: MissionState = mission_states.get(mission_id)
	if state:
		state.status = MissionState.Status.SKIPPED
		_update_mission_availability()
		progression_state_changed.emit()
		print("CampaignProgressionManager: Mission skipped: %s" % mission_id)

## Resets mission state (for testing/debugging)
func reset_mission(mission_id: String) -> void:
	var state: MissionState = mission_states.get(mission_id)
	if state:
		state.status = MissionState.Status.LOCKED
		state.attempts = 0
		state.best_score = 0.0
		state.completion_time = ""
		
		completed_missions.erase(mission_id)
		unlocked_missions.erase(mission_id)
		
		_calculate_initial_progression()
		progression_state_changed.emit()
		print("CampaignProgressionManager: Mission reset: %s" % mission_id)

## Validates campaign progression logic
func validate_campaign_progression() -> Array[String]:
	var errors: Array[String] = []
	
	if not campaign_data:
		errors.append("No campaign data")
		return errors
	
	# Check for unreachable missions
	var reachable_missions: Array[String] = []
	var starting_missions: Array[CampaignMissionData] = campaign_data.get_starting_missions()
	
	for mission in starting_missions:
		_find_reachable_missions(mission.mission_id, reachable_missions, [])
	
	for mission in campaign_data.missions:
		if not reachable_missions.has(mission.mission_id):
			errors.append("Mission '%s' is unreachable" % mission.mission_name)
	
	# Check for circular dependencies (already handled by CampaignData)
	var circular_deps: Array[String] = campaign_data._detect_circular_dependencies()
	errors.append_array(circular_deps)
	
	# Check for missing branch targets
	for mission in campaign_data.missions:
		for branch in mission.mission_branches:
			if not branch.target_mission_id.is_empty():
				if not campaign_data.get_mission(branch.target_mission_id):
					errors.append("Mission '%s' has branch targeting non-existent mission '%s'" % [mission.mission_name, branch.target_mission_id])
	
	return errors

## Recursively finds reachable missions
func _find_reachable_missions(mission_id: String, reachable: Array[String], visited: Array[String]) -> void:
	if visited.has(mission_id):
		return  # Avoid infinite loops
	
	visited.append(mission_id)
	reachable.append(mission_id)
	
	var mission: CampaignMissionData = campaign_data.get_mission(mission_id)
	if not mission:
		return
	
	# Follow mission branches
	for branch in mission.mission_branches:
		if not branch.target_mission_id.is_empty():
			_find_reachable_missions(branch.target_mission_id, reachable, visited)
	
	# Find missions that depend on this one
	var dependents: Array[CampaignMissionData] = campaign_data.get_dependent_missions(mission_id)
	for dependent in dependents:
		_find_reachable_missions(dependent.mission_id, reachable, visited)

## Public API - State Queries

## Checks if a mission is unlocked
func is_mission_unlocked(mission_id: String) -> bool:
	var state: MissionState = mission_states.get(mission_id)
	return state and state.status in [MissionState.Status.UNLOCKED, MissionState.Status.COMPLETED, MissionState.Status.FAILED]

## Checks if a mission is completed
func is_mission_completed(mission_id: String) -> bool:
	var state: MissionState = mission_states.get(mission_id)
	return state and state.status == MissionState.Status.COMPLETED

## Gets mission completion percentage
func get_campaign_completion_percentage() -> float:
	if campaign_data.missions.is_empty():
		return 0.0
	
	var required_missions: int = 0
	var completed_required: int = 0
	
	for mission in campaign_data.missions:
		if mission.is_required:
			required_missions += 1
			if is_mission_completed(mission.mission_id):
				completed_required += 1
	
	if required_missions == 0:
		return 100.0
	
	return (float(completed_required) / float(required_missions)) * 100.0

## Gets all unlocked missions
func get_unlocked_missions() -> Array[String]:
	return unlocked_missions.duplicate()

## Gets all completed missions
func get_completed_missions() -> Array[String]:
	return completed_missions.duplicate()

## Gets mission state
func get_mission_state(mission_id: String) -> MissionState:
	return mission_states.get(mission_id)

## Gets current mission
func get_current_mission() -> String:
	return current_mission

## Sets current mission
func set_current_mission(mission_id: String) -> void:
	if is_mission_unlocked(mission_id):
		current_mission = mission_id
		progression_state_changed.emit()

## Gets campaign statistics
func get_campaign_statistics() -> Dictionary:
	var stats: Dictionary = {}
	
	stats["total_missions"] = campaign_data.missions.size() if campaign_data else 0
	stats["completed_missions"] = completed_missions.size()
	stats["unlocked_missions"] = unlocked_missions.size()
	stats["completion_percentage"] = get_campaign_completion_percentage()
	
	var total_attempts: int = 0
	var total_score: float = 0.0
	
	for mission_id in mission_states:
		var state: MissionState = mission_states[mission_id]
		total_attempts += state.attempts
		total_score += state.best_score
	
	stats["total_attempts"] = total_attempts
	stats["average_score"] = total_score / max(1, completed_missions.size())
	
	return stats

## Exports progression state for saving
func export_progression_state() -> Dictionary:
	var state_data: Dictionary = {}
	
	state_data["mission_states"] = {}
	for mission_id in mission_states:
		var state: MissionState = mission_states[mission_id]
		state_data["mission_states"][mission_id] = {
			"status": state.status,
			"attempts": state.attempts,
			"best_score": state.best_score,
			"completion_time": state.completion_time
		}
	
	state_data["campaign_variables"] = campaign_variables.duplicate()
	state_data["current_mission"] = current_mission
	state_data["completed_missions"] = completed_missions.duplicate()
	state_data["unlocked_missions"] = unlocked_missions.duplicate()
	
	return state_data

## Imports progression state from save data
func import_progression_state(state_data: Dictionary) -> void:
	if state_data.has("mission_states"):
		mission_states.clear()
		for mission_id in state_data["mission_states"]:
			var state_info: Dictionary = state_data["mission_states"][mission_id]
			var state: MissionState = MissionState.new(mission_id)
			state.status = state_info.get("status", MissionState.Status.LOCKED)
			state.attempts = state_info.get("attempts", 0)
			state.best_score = state_info.get("best_score", 0.0)
			state.completion_time = state_info.get("completion_time", "")
			mission_states[mission_id] = state
	
	if state_data.has("campaign_variables"):
		campaign_variables = state_data["campaign_variables"].duplicate()
	
	if state_data.has("current_mission"):
		current_mission = state_data["current_mission"]
	
	if state_data.has("completed_missions"):
		completed_missions = state_data["completed_missions"].duplicate()
	
	if state_data.has("unlocked_missions"):
		unlocked_missions = state_data["unlocked_missions"].duplicate()
	
	progression_state_changed.emit()
	print("CampaignProgressionManager: Progression state imported")