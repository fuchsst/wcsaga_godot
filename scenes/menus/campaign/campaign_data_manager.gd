class_name CampaignDataManager
extends RefCounted

## WCS campaign data management with progression tracking and SEXP integration.
## Handles campaign loading, mission progression, SEXP variable state, and save/load operations.
## Provides complete campaign lifecycle management for the WCS-Godot conversion.

signal campaign_loaded(campaign: CampaignData)
signal campaign_progress_updated(mission_index: int, completion_status: bool)
signal campaign_mission_available(mission_index: int)
signal campaign_error(error_message: String)
signal sexp_variables_updated(variables: Dictionary)

# Campaign constants from WCS
const MAX_CAMPAIGN_MISSIONS: int = 100
const MAX_CAMPAIGNS: int = 128
const CAMPAIGN_FILE_EXTENSION: String = ".fc2"

# Campaign types
enum CampaignType {
	SINGLE_PLAYER = 0,
	MULTI_COOP = 1,
	MULTI_TEAMS = 2
}

# Mission completion states
enum MissionCompletionState {
	NOT_AVAILABLE = 0,
	AVAILABLE = 1,
	COMPLETED = 2,
	FAILED = 3,
	SKIPPED = 4
}

# Internal state
var current_campaign: CampaignData = null
var available_campaigns: Array[CampaignData] = []
var campaign_directory: String = "user://campaigns/"
var sexp_manager: SexpManager = null

# Campaign progression
var mission_completion_states: Array[MissionCompletionState] = []
var campaign_sexp_variables: Dictionary = {}
var current_mission_index: int = -1
var next_mission_index: int = 0

# Performance
var campaign_cache: Dictionary = {}
var cache_expiry_time: float = 300.0  # 5 minutes

func _init() -> void:
	"""Initialize campaign data manager."""
	print("CampaignDataManager: Initializing campaign system")
	
	# Get SEXP manager
	sexp_manager = SexpManager as SexpManager
	if not sexp_manager:
		push_error("CampaignDataManager: SEXP system not available")
	
	# Ensure campaign directory exists
	_ensure_campaign_directory()
	
	# Load available campaigns
	_refresh_campaign_list()

# ============================================================================
# CAMPAIGN LOADING AND MANAGEMENT
# ============================================================================

func load_campaign(campaign_filename: String) -> bool:
	"""Load campaign from file and initialize progression."""
	print("CampaignDataManager: Loading campaign: %s" % campaign_filename)
	
	# Check cache first
	var cache_key: String = campaign_filename
	if campaign_cache.has(cache_key):
		var cached_entry: Dictionary = campaign_cache[cache_key]
		if Time.get_time_dict_from_system()["unix"] - cached_entry["timestamp"] < cache_expiry_time:
			current_campaign = cached_entry["campaign"]
			_initialize_campaign_progression()
			campaign_loaded.emit(current_campaign)
			return true
	
	# Load from file
	var file_path: String = campaign_directory + campaign_filename
	if not FileAccess.file_exists(file_path):
		var error_msg: String = "Campaign file not found: %s" % file_path
		campaign_error.emit(error_msg)
		return false
	
	var campaign_data: CampaignData = _parse_campaign_file(file_path)
	if not campaign_data:
		var error_msg: String = "Failed to parse campaign file: %s" % campaign_filename
		campaign_error.emit(error_msg)
		return false
	
	# Cache the campaign
	campaign_cache[cache_key] = {
		"campaign": campaign_data,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	
	# Set as current
	current_campaign = campaign_data
	_initialize_campaign_progression()
	
	campaign_loaded.emit(current_campaign)
	return true

func get_available_campaigns() -> Array[CampaignData]:
	"""Get list of available campaigns."""
	return available_campaigns.duplicate()

func get_current_campaign() -> CampaignData:
	"""Get currently loaded campaign."""
	return current_campaign

func is_campaign_loaded() -> bool:
	"""Check if campaign is loaded."""
	return current_campaign != null

# ============================================================================
# MISSION PROGRESSION
# ============================================================================

func get_mission_completion_state(mission_index: int) -> MissionCompletionState:
	"""Get completion state for mission at index."""
	if mission_index < 0 or mission_index >= mission_completion_states.size():
		return MissionCompletionState.NOT_AVAILABLE
	return mission_completion_states[mission_index]

func is_mission_available(mission_index: int) -> bool:
	"""Check if mission is available to play."""
	var state: MissionCompletionState = get_mission_completion_state(mission_index)
	return state == MissionCompletionState.AVAILABLE

func is_mission_completed(mission_index: int) -> bool:
	"""Check if mission is completed."""
	var state: MissionCompletionState = get_mission_completion_state(mission_index)
	return state == MissionCompletionState.COMPLETED

func complete_mission(mission_index: int, success: bool = true) -> void:
	"""Mark mission as completed and update progression."""
	if not current_campaign or mission_index < 0 or mission_index >= current_campaign.missions.size():
		return
	
	var new_state: MissionCompletionState = MissionCompletionState.COMPLETED if success else MissionCompletionState.FAILED
	mission_completion_states[mission_index] = new_state
	
	# Update progression based on SEXP conditions
	_evaluate_mission_progression(mission_index, success)
	
	campaign_progress_updated.emit(mission_index, success)
	
	print("CampaignDataManager: Mission %d completed with state: %s" % [mission_index, MissionCompletionState.keys()[new_state]])

func get_next_available_mission() -> int:
	"""Get index of next available mission."""
	return next_mission_index

func get_campaign_progress_percentage() -> float:
	"""Get overall campaign completion percentage."""
	if not current_campaign:
		return 0.0
	
	var completed_count: int = 0
	for state in mission_completion_states:
		if state == MissionCompletionState.COMPLETED:
			completed_count += 1
	
	return float(completed_count) / float(current_campaign.missions.size()) * 100.0

# ============================================================================
# SEXP INTEGRATION
# ============================================================================

func get_sexp_variable(variable_name: String) -> Variant:
	"""Get SEXP variable value."""
	return campaign_sexp_variables.get(variable_name, null)

func set_sexp_variable(variable_name: String, value: Variant) -> void:
	"""Set SEXP variable value."""
	campaign_sexp_variables[variable_name] = value
	sexp_variables_updated.emit(campaign_sexp_variables)

func evaluate_sexp_condition(sexp_formula: String) -> bool:
	"""Evaluate SEXP condition for mission branching."""
	if not sexp_manager:
		push_warning("CampaignDataManager: SEXP manager not available for condition evaluation")
		return true
	
	# Parse and evaluate SEXP expression
	var expression = sexp_manager.parse_expression(sexp_formula)
	if not expression:
		push_warning("CampaignDataManager: Failed to parse SEXP condition: %s" % sexp_formula)
		return true
	
	# TODO: Implement SEXP evaluation with campaign context
	# For now, return true to allow progression
	return true

# ============================================================================
# CAMPAIGN MANAGEMENT
# ============================================================================

func refresh_campaigns() -> void:
	"""Refresh list of available campaigns."""
	_refresh_campaign_list()

func get_campaign_info(campaign_filename: String) -> Dictionary:
	"""Get campaign information without full loading."""
	for campaign in available_campaigns:
		if campaign.filename == campaign_filename:
			return {
				"name": campaign.name,
				"description": campaign.description,
				"type": campaign.type,
				"mission_count": campaign.missions.size(),
				"filename": campaign.filename
			}
	return {}

# ============================================================================
# SAVE/LOAD PROGRESSION
# ============================================================================

func save_campaign_progress() -> bool:
	"""Save current campaign progress."""
	if not current_campaign:
		return false
	
	var save_data: Dictionary = {
		"campaign_filename": current_campaign.filename,
		"mission_completion_states": mission_completion_states,
		"sexp_variables": campaign_sexp_variables,
		"current_mission_index": current_mission_index,
		"next_mission_index": next_mission_index,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	}
	
	var save_path: String = campaign_directory + "progress_" + current_campaign.filename.get_basename() + ".save"
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		campaign_error.emit("Failed to save campaign progress")
		return false
	
	file.store_string(JSON.stringify(save_data))
	file.close()
	
	print("CampaignDataManager: Saved campaign progress to: %s" % save_path)
	return true

func load_campaign_progress(campaign_filename: String) -> bool:
	"""Load campaign progress from save file."""
	var save_path: String = campaign_directory + "progress_" + campaign_filename.get_basename() + ".save"
	if not FileAccess.file_exists(save_path):
		return false
	
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		campaign_error.emit("Failed to parse campaign progress save file")
		return false
	
	var save_data: Dictionary = json.data as Dictionary
	
	# Restore progression state
	mission_completion_states = save_data.get("mission_completion_states", [])
	campaign_sexp_variables = save_data.get("sexp_variables", {})
	current_mission_index = save_data.get("current_mission_index", -1)
	next_mission_index = save_data.get("next_mission_index", 0)
	
	print("CampaignDataManager: Loaded campaign progress from: %s" % save_path)
	return true

# ============================================================================
# PRIVATE IMPLEMENTATION
# ============================================================================

func _ensure_campaign_directory() -> void:
	"""Ensure campaign directory exists."""
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("campaigns"):
		dir.make_dir("campaigns")

func _refresh_campaign_list() -> void:
	"""Refresh available campaigns list."""
	available_campaigns.clear()
	
	var dir: DirAccess = DirAccess.open(campaign_directory)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(CAMPAIGN_FILE_EXTENSION):
			var campaign_data: CampaignData = _parse_campaign_file(campaign_directory + file_name)
			if campaign_data:
				available_campaigns.append(campaign_data)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("CampaignDataManager: Found %d campaigns" % available_campaigns.size())

func _parse_campaign_file(file_path: String) -> CampaignData:
	"""Parse campaign file and return campaign data."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
	
	var campaign_data: CampaignData = CampaignData.new()
	campaign_data.filename = file_path.get_file()
	
	# Parse campaign file format (simplified)
	var content: String = file.get_as_text()
	file.close()
	
	# Basic parsing (this would need to be expanded for full FC2 format)
	var lines: PackedStringArray = content.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.begins_with("$Name:"):
			campaign_data.name = line.split(":", true, 1)[1].strip_edges()
		elif line.begins_with("$Desc:"):
			campaign_data.description = line.split(":", true, 1)[1].strip_edges()
		elif line.begins_with("$Type:"):
			var type_str: String = line.split(":", true, 1)[1].strip_edges()
			match type_str.to_lower():
				"single":
					campaign_data.type = CampaignType.SINGLE_PLAYER
				"multi coop":
					campaign_data.type = CampaignType.MULTI_COOP
				"multi teams":
					campaign_data.type = CampaignType.MULTI_TEAMS
	
	# For now, create default missions (would parse actual mission list)
	for i in range(5):
		var mission: CampaignMissionData = CampaignMissionData.new()
		mission.name = "Mission %d" % (i + 1)
		mission.filename = "mission_%02d.fs2" % (i + 1)
		mission.index = i
		campaign_data.missions.append(mission)
	
	return campaign_data

func _initialize_campaign_progression() -> void:
	"""Initialize campaign progression state."""
	if not current_campaign:
		return
	
	# Initialize mission completion states
	mission_completion_states.clear()
	mission_completion_states.resize(current_campaign.missions.size())
	
	# First mission is always available
	if current_campaign.missions.size() > 0:
		mission_completion_states[0] = MissionCompletionState.AVAILABLE
		next_mission_index = 0
	
	for i in range(1, mission_completion_states.size()):
		mission_completion_states[i] = MissionCompletionState.NOT_AVAILABLE
	
	# Try to load saved progress
	load_campaign_progress(current_campaign.filename)
	
	# Reset current mission
	current_mission_index = -1

func _evaluate_mission_progression(completed_mission_index: int, success: bool) -> void:
	"""Evaluate mission progression based on SEXP conditions."""
	if not current_campaign or completed_mission_index >= current_campaign.missions.size():
		return
	
	var completed_mission: CampaignMissionData = current_campaign.missions[completed_mission_index]
	
	# Simple linear progression for now
	# TODO: Implement SEXP-based branching logic
	if success and completed_mission_index + 1 < current_campaign.missions.size():
		next_mission_index = completed_mission_index + 1
		mission_completion_states[next_mission_index] = MissionCompletionState.AVAILABLE
		campaign_mission_available.emit(next_mission_index)

# ============================================================================
# STATIC UTILITIES
# ============================================================================

static func create_campaign_manager() -> CampaignDataManager:
	"""Create and initialize campaign data manager."""
	return CampaignDataManager.new()

static func validate_campaign_file(file_path: String) -> bool:
	"""Validate campaign file format."""
	if not FileAccess.file_exists(file_path):
		return false
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var content: String = file.get_as_text()
	file.close()
	
	# Basic validation - check for required fields
	return content.contains("$Name:") and content.contains("$Type:")