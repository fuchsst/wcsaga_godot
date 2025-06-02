class_name CampaignProgressionManager
extends RefCounted

## Campaign Progression Manager
## Manages campaign progression and mission unlocking using existing CampaignData and CampaignState resources
## Leverages comprehensive existing save system and asset core structures

signal campaign_loaded(campaign_state: CampaignState)
signal mission_completed(mission_id: String, mission_result: Dictionary, newly_available: Array[String])
signal campaign_completed(campaign_state: CampaignState)
signal mission_unlocked(mission_id: String, unlock_reason: String)

# Current campaign management
var current_campaign_data: CampaignData
var current_campaign_state: CampaignState
var mission_unlocking: MissionUnlocking
var progression_analytics: ProgressionAnalytics

func _init() -> void:
	mission_unlocking = MissionUnlocking.new()
	progression_analytics = ProgressionAnalytics.new()
	print("CampaignProgressionManager: Initialized with existing resource integration")

## Load campaign using existing CampaignData and CampaignState resources
func load_campaign(campaign_filename: String, pilot: PlayerProfile) -> bool:
	# Load campaign data using existing WCS asset system
	var campaign_data_path = "campaigns/" + campaign_filename
	current_campaign_data = WCSAssetLoader.load_asset(campaign_data_path)
	
	if not current_campaign_data:
		push_error("CampaignProgressionManager: Failed to load campaign data: %s" % campaign_filename)
		return false
	
	# Load or create campaign state using existing save system
	current_campaign_state = _load_or_create_campaign_state(campaign_filename, pilot)
	if not current_campaign_state:
		push_error("CampaignProgressionManager: Failed to initialize campaign state")
		return false
	
	# Initialize mission availability using existing campaign data
	_initialize_mission_availability()
	
	campaign_loaded.emit(current_campaign_state)
	
	print("CampaignProgressionManager: Campaign loaded: %s (%.1f%% complete)" % [
		current_campaign_state.campaign_name, 
		current_campaign_state.get_completion_percentage() * 100
	])
	return true

## Process mission completion using existing CampaignState mission tracking
func complete_mission(mission_filename: String, mission_result: Dictionary) -> void:
	if not current_campaign_state or not current_campaign_data:
		push_error("CampaignProgressionManager: No active campaign")
		return
	
	# Find mission index using existing CampaignData structure
	var mission_index = _find_mission_index(mission_filename)
	if mission_index == -1:
		push_error("CampaignProgressionManager: Mission not found in campaign: %s" % mission_filename)
		return
	
	# Skip if already completed
	if current_campaign_state.is_mission_completed(mission_index):
		print("CampaignProgressionManager: Mission already completed: %s" % mission_filename)
		return
	
	# Complete mission using existing CampaignState functionality
	current_campaign_state.complete_mission(mission_index, mission_result)
	
	# Process mission result for campaign variables using existing variable system
	_process_mission_result_variables(mission_filename, mission_result)
	
	# Calculate newly available missions using mission unlocking system
	var newly_available = mission_unlocking.calculate_newly_available_missions(
		mission_filename, mission_result, current_campaign_state, current_campaign_data
	)
	
	# Update available missions in campaign state
	for mission_id in newly_available:
		var mission_index_new = _find_mission_index(mission_id)
		if mission_index_new != -1:
			_mark_mission_available(mission_index_new, "mission_completion")
	
	# Update completion percentage and analytics
	_update_progression_analytics(mission_filename, mission_result)
	
	# Save campaign state using existing save system
	_save_campaign_progress()
	
	# Check for campaign completion
	if _is_campaign_completed():
		campaign_completed.emit(current_campaign_state)
		print("CampaignProgressionManager: Campaign completed!")
	
	mission_completed.emit(mission_filename, mission_result, newly_available)
	
	print("CampaignProgressionManager: Mission completed: %s -> %d new missions available" % [
		mission_filename, newly_available.size()
	])

## Get currently available missions using existing campaign state
func get_available_missions() -> Array[Dictionary]:
	if not current_campaign_state or not current_campaign_data:
		return []
	
	var available_missions: Array[Dictionary] = []
	
	for i in range(current_campaign_data.missions.size()):
		var mission_data = current_campaign_data.missions[i]
		var mission_info = {
			"filename": mission_data.filename,
			"name": mission_data.name,
			"index": mission_data.index,
			"is_available": _is_mission_available(i),
			"is_completed": current_campaign_state.is_mission_completed(i),
			"best_score": 0,
			"completion_time": 0.0
		}
		
		# Add completion data if mission is completed
		if mission_info.is_completed and i < current_campaign_state.best_mission_scores.size():
			mission_info.best_score = current_campaign_state.best_mission_scores[i]
			if i < current_campaign_state.mission_results.size():
				var result = current_campaign_state.mission_results[i]
				mission_info.completion_time = result.get("time", 0.0)
		
		available_missions.append(mission_info)
	
	return available_missions

## Get campaign progression summary using existing campaign state data
func get_campaign_summary() -> Dictionary:
	if not current_campaign_state or not current_campaign_data:
		return {}
	
	return {
		"campaign_name": current_campaign_state.campaign_name,
		"campaign_filename": current_campaign_state.campaign_filename,
		"total_missions": current_campaign_state.total_missions,
		"missions_completed": current_campaign_state.get_missions_completed_count(),
		"completion_percentage": current_campaign_state.get_completion_percentage() * 100,
		"current_mission": current_campaign_state.current_mission_name,
		"campaign_score": current_campaign_state.campaign_score,
		"playtime": current_campaign_state.campaign_playtime,
		"available_missions": _count_available_missions(),
		"story_branch": current_campaign_state.current_branch
	}

## Check if specific mission is available using existing data structures
func is_mission_available(mission_filename: String) -> bool:
	var mission_index = _find_mission_index(mission_filename)
	if mission_index == -1:
		return false
	return _is_mission_available(mission_index)

## Set campaign variable using existing CampaignState variable system
func set_campaign_variable(variable_name: String, value: Variant, persistent: bool = true) -> void:
	if current_campaign_state:
		current_campaign_state.set_variable(variable_name, value, persistent)
		_save_campaign_progress()

## Get campaign variable using existing CampaignState variable system
func get_campaign_variable(variable_name: String, default_value: Variant = null) -> Variant:
	if current_campaign_state:
		return current_campaign_state.get_variable(variable_name, default_value)
	return default_value

## Record player choice using existing CampaignState choice system
func record_player_choice(choice_id: String, choice_value: Variant, choice_data: Dictionary = {}) -> void:
	if current_campaign_state:
		choice_data["value"] = choice_value
		current_campaign_state.record_player_choice(choice_id, choice_data)
		_save_campaign_progress()
		
		# Check if this choice affects mission availability
		_evaluate_choice_consequences(choice_id, choice_value)

## Private helper methods

func _load_or_create_campaign_state(campaign_filename: String, pilot: PlayerProfile) -> CampaignState:
	# Try to load existing campaign state from save system
	var campaign_state = SaveGameManager.load_campaign_state(pilot.current_save_slot)
	
	if campaign_state and campaign_state.campaign_filename == campaign_filename:
		# Validate existing campaign state
		var validation = campaign_state.validate_campaign_state()
		if validation.is_valid:
			return campaign_state
		else:
			print("CampaignProgressionManager: Campaign state validation failed, creating new state")
	
	# Create new campaign state using existing CampaignState initialization
	campaign_state = CampaignState.new()
	campaign_state.initialize_from_campaign_data({
		"campaign_name": current_campaign_data.name,
		"campaign_filename": campaign_filename,
		"total_missions": current_campaign_data.get_mission_count(),
		"version": current_campaign_data.version,
		"author": current_campaign_data.author
	})
	
	return campaign_state

func _initialize_mission_availability() -> void:
	# Initialize first mission as available
	if current_campaign_data.missions.size() > 0:
		_mark_mission_available(0, "campaign_start")

func _find_mission_index(mission_filename: String) -> int:
	for i in range(current_campaign_data.missions.size()):
		if current_campaign_data.missions[i].filename == mission_filename:
			return i
	return -1

func _is_mission_available(mission_index: int) -> bool:
	if mission_index < 0 or mission_index >= current_campaign_data.missions.size():
		return false
	
	# First mission is always available
	if mission_index == 0:
		return true
	
	# Check if mission has been explicitly made available
	var mission_data = current_campaign_data.missions[mission_index]
	return mission_unlocking.check_mission_availability(mission_data, current_campaign_state)

func _mark_mission_available(mission_index: int, reason: String) -> void:
	if mission_index >= 0 and mission_index < current_campaign_data.missions.size():
		var mission_data = current_campaign_data.missions[mission_index]
		
		# Use conditional missions tracking in campaign state
		if not current_campaign_state.conditional_missions.has(mission_data.filename):
			current_campaign_state.conditional_missions[mission_data.filename] = true
			mission_unlocked.emit(mission_data.filename, reason)

func _process_mission_result_variables(mission_filename: String, mission_result: Dictionary) -> void:
	# Set standard completion variables
	current_campaign_state.set_variable("last_mission_completed", mission_filename, true)
	current_campaign_state.set_variable("last_mission_score", mission_result.get("score", 0), true)
	current_campaign_state.set_variable("last_mission_success", mission_result.get("success", false), true)
	
	# Process any custom variables from mission result
	if mission_result.has("variables"):
		var variables = mission_result["variables"]
		for variable_name in variables:
			current_campaign_state.set_variable(variable_name, variables[variable_name], true)

func _evaluate_choice_consequences(choice_id: String, choice_value: Variant) -> void:
	# Check if any missions become available based on this choice
	for i in range(current_campaign_data.missions.size()):
		var mission_data = current_campaign_data.missions[i]
		if not _is_mission_available(i):
			if mission_unlocking.check_choice_unlocks_mission(mission_data, choice_id, choice_value, current_campaign_state):
				_mark_mission_available(i, "player_choice")

func _count_available_missions() -> int:
	var count = 0
	for i in range(current_campaign_data.missions.size()):
		if _is_mission_available(i) and not current_campaign_state.is_mission_completed(i):
			count += 1
	return count

func _is_campaign_completed() -> bool:
	return current_campaign_state.get_completion_percentage() >= 1.0

func _update_progression_analytics(mission_filename: String, mission_result: Dictionary) -> void:
	progression_analytics.record_mission_completion(mission_filename, mission_result, current_campaign_state)

func _save_campaign_progress() -> void:
	if current_campaign_state:
		SaveGameManager.save_campaign_state(current_campaign_state, SaveGameManager.get_current_save_slot())