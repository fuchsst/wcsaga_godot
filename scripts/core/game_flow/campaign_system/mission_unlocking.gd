class_name MissionUnlocking
extends RefCounted

## Mission Unlocking System
## Handles mission availability logic using existing CampaignData and CampaignState resources
## Supports prerequisite-based, performance-based, and choice-based mission unlocking

# Mission unlocking reasons for tracking
enum UnlockReason {
	CAMPAIGN_START,      # First mission
	MISSION_COMPLETION,  # Previous mission completed
	PERFORMANCE_UNLOCK,  # Performance threshold met
	CHOICE_UNLOCK,      # Player choice consequence
	VARIABLE_CONDITION, # Campaign variable condition
	BRANCH_UNLOCK       # Story branch condition
}

## Calculate newly available missions after mission completion
func calculate_newly_available_missions(
	completed_mission: String, 
	mission_result: Dictionary, 
	campaign_state: CampaignState, 
	campaign_data: CampaignData
) -> Array[String]:
	var newly_available: Array[String] = []
	
	for mission_data in campaign_data.missions:
		if mission_data.filename == completed_mission:
			continue # Skip the just completed mission
		
		# Skip if already available
		if campaign_state.conditional_missions.get(mission_data.filename, false):
			continue
		
		# Skip if already completed
		var mission_index = _find_mission_index(mission_data.filename, campaign_data)
		if mission_index != -1 and campaign_state.is_mission_completed(mission_index):
			continue
		
		# Check if this mission should be unlocked
		if _evaluate_mission_unlock_conditions(mission_data, completed_mission, mission_result, campaign_state, campaign_data):
			newly_available.append(mission_data.filename)
	
	return newly_available

## Check if mission is currently available based on all unlock conditions
func check_mission_availability(mission_data: CampaignMissionData, campaign_state: CampaignState) -> bool:
	# First mission is always available
	if mission_data.index == 0:
		return true
	
	# Check if explicitly marked as available
	if campaign_state.conditional_missions.get(mission_data.filename, false):
		return true
	
	# Check basic prerequisites (previous missions completed)
	if _check_prerequisite_missions(mission_data, campaign_state):
		return true
	
	return false

## Check if a player choice unlocks this mission
func check_choice_unlocks_mission(
	mission_data: CampaignMissionData, 
	choice_id: String, 
	choice_value: Variant, 
	campaign_state: CampaignState
) -> bool:
	# Simple choice-based unlocking logic
	# This would be enhanced with SEXP integration in EPIC-004
	
	# Check mission formula for choice references
	if mission_data.formula_sexp.length() > 0:
		# For now, simple string matching - will be replaced with SEXP evaluation
		if mission_data.formula_sexp.contains(choice_id):
			return _evaluate_simple_choice_condition(mission_data.formula_sexp, choice_id, choice_value)
	
	return false

## Private helper methods

func _evaluate_mission_unlock_conditions(
	mission_data: CampaignMissionData,
	completed_mission: String,
	mission_result: Dictionary,
	campaign_state: CampaignState,
	campaign_data: CampaignData
) -> bool:
	
	# Check prerequisite completion
	if _check_prerequisite_completion(mission_data, completed_mission, campaign_state, campaign_data):
		return true
	
	# Check performance-based unlocking
	if _check_performance_requirements(mission_data, mission_result, campaign_state):
		return true
	
	# Check variable conditions
	if _check_variable_conditions(mission_data, campaign_state):
		return true
	
	# Check story branch conditions
	if _check_branch_conditions(mission_data, campaign_state):
		return true
	
	return false

func _check_prerequisite_completion(
	mission_data: CampaignMissionData,
	completed_mission: String,
	campaign_state: CampaignState,
	campaign_data: CampaignData
) -> bool:
	
	# Linear progression: next mission unlocks when previous is completed
	if mission_data.index > 0:
		var previous_mission = campaign_data.missions[mission_data.index - 1]
		if previous_mission.filename == completed_mission:
			return true
	
	# Check SEXP formula for specific prerequisites
	if mission_data.formula_sexp.length() > 0:
		return _evaluate_prerequisite_formula(mission_data.formula_sexp, completed_mission, campaign_state)
	
	return false

func _check_prerequisite_missions(mission_data: CampaignMissionData, campaign_state: CampaignState) -> bool:
	# Check if required previous missions are completed
	for i in range(mission_data.index):
		# For linear campaigns, all previous missions must be completed
		if not campaign_state.is_mission_completed(i):
			return false
	
	return mission_data.index > 0

func _check_performance_requirements(
	mission_data: CampaignMissionData,
	mission_result: Dictionary,
	campaign_state: CampaignState
) -> bool:
	
	# Check if mission result meets performance thresholds
	# This would typically be defined in mission notes or SEXP formula
	
	if mission_data.notes.contains("score_required"):
		var required_score = _extract_score_requirement(mission_data.notes)
		var actual_score = mission_result.get("score", 0)
		if actual_score >= required_score:
			return true
	
	if mission_data.notes.contains("time_limit"):
		var time_limit = _extract_time_requirement(mission_data.notes)
		var actual_time = mission_result.get("time", 9999.0)
		if actual_time <= time_limit:
			return true
	
	return false

func _check_variable_conditions(mission_data: CampaignMissionData, campaign_state: CampaignState) -> bool:
	# Check campaign variable conditions in SEXP formula
	if mission_data.formula_sexp.length() > 0:
		return _evaluate_variable_formula(mission_data.formula_sexp, campaign_state)
	
	return false

func _check_branch_conditions(mission_data: CampaignMissionData, campaign_state: CampaignState) -> bool:
	# Check story branch conditions
	if mission_data.notes.contains("branch:"):
		var required_branch = _extract_branch_requirement(mission_data.notes)
		return campaign_state.current_branch == required_branch
	
	return false

func _evaluate_prerequisite_formula(formula: String, completed_mission: String, campaign_state: CampaignState) -> bool:
	# Simple SEXP formula evaluation - will be replaced with full SEXP system in EPIC-004
	
	# Check for mission completion references
	if formula.contains("is-mission-complete"):
		var mission_refs = _extract_mission_references(formula)
		for mission_ref in mission_refs:
			var mission_index = _find_mission_index_by_name(mission_ref, campaign_state)
			if mission_index != -1 and not campaign_state.is_mission_completed(mission_index):
				return false
		return true
	
	# Check for specific mission completion
	if formula.contains(completed_mission):
		return true
	
	return false

func _evaluate_variable_formula(formula: String, campaign_state: CampaignState) -> bool:
	# Simple variable evaluation - will be enhanced with SEXP system
	
	# Check for variable references
	if formula.contains("variable-"):
		var variables = _extract_variable_references(formula)
		for var_ref in variables:
			var var_name = var_ref.var_name
			var var_value = var_ref.expected_value
			var actual_value = campaign_state.get_variable(var_name)
			
			if actual_value != var_value:
				return false
		return true
	
	return false

func _evaluate_simple_choice_condition(formula: String, choice_id: String, choice_value: Variant) -> bool:
	# Simple choice condition evaluation
	if formula.contains(choice_id):
		if formula.contains("=" + str(choice_value)):
			return true
		if formula.contains("true") and choice_value == true:
			return true
		if formula.contains("false") and choice_value == false:
			return true
	
	return false

func _find_mission_index(mission_filename: String, campaign_data: CampaignData) -> int:
	for i in range(campaign_data.missions.size()):
		if campaign_data.missions[i].filename == mission_filename:
			return i
	return -1

func _find_mission_index_by_name(mission_name: String, campaign_state: CampaignState) -> int:
	# Simple lookup - would need mission name to index mapping
	# For now, return -1 to indicate not found
	return -1

func _extract_score_requirement(notes: String) -> int:
	# Extract score requirement from mission notes
	var regex = RegEx.new()
	regex.compile("score_required:(\\d+)")
	var result = regex.search(notes)
	if result:
		return result.get_string(1).to_int()
	return 0

func _extract_time_requirement(notes: String) -> float:
	# Extract time requirement from mission notes
	var regex = RegEx.new()
	regex.compile("time_limit:([\\d.]+)")
	var result = regex.search(notes)
	if result:
		return result.get_string(1).to_float()
	return 9999.0

func _extract_branch_requirement(notes: String) -> String:
	# Extract branch requirement from mission notes
	var regex = RegEx.new()
	regex.compile("branch:(\\w+)")
	var result = regex.search(notes)
	if result:
		return result.get_string(1)
	return "main"

func _extract_mission_references(formula: String) -> Array[String]:
	# Extract mission references from SEXP formula
	var missions: Array[String] = []
	var regex = RegEx.new()
	regex.compile("\"([^\"]+\\.fs2)\"")
	var results = regex.search_all(formula)
	for result in results:
		missions.append(result.get_string(1))
	return missions

func _extract_variable_references(formula: String) -> Array[Dictionary]:
	# Extract variable references from SEXP formula
	var variables: Array[Dictionary] = []
	
	# Simple pattern matching - will be enhanced with SEXP parser
	var regex = RegEx.new()
	regex.compile("variable-(\\w+)\\s+(\\w+)")
	var results = regex.search_all(formula)
	for result in results:
		variables.append({
			"var_name": result.get_string(1),
			"expected_value": result.get_string(2)
		})
	
	return variables