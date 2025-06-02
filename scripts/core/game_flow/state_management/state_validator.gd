class_name StateValidator
extends RefCounted

## Enhanced state transition validation system for EPIC-007
## Provides comprehensive validation rules, dependency checking, and error recovery

# Validation result structure
class StateValidationResult:
	extends RefCounted
	
	var is_valid: bool = false
	var error_message: String = ""
	var warning_messages: Array[String] = []
	var required_resources: Array[String] = []
	var can_retry: bool = false
	var required_conditions: Array[String] = []

# Resource check result structure  
class ResourceCheckResult:
	extends RefCounted
	
	var is_valid: bool = false
	var error_message: String = ""
	var required_resources: Array[String] = []

# Custom validation result structure
class CustomValidationResult:
	extends RefCounted
	
	var is_valid: bool = false
	var error_message: String = ""
	var warnings: Array[String] = []

## Comprehensive state transition validation
func validate_transition_preconditions(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, data: Dictionary) -> StateValidationResult:
	var result: StateValidationResult = StateValidationResult.new()
	
	# Basic transition validity (leverages existing GameStateManager validation)
	if not _is_basic_transition_valid(from_state, to_state):
		result.error_message = "Invalid state transition: %s -> %s" % [GameStateManager.GameState.keys()[from_state], GameStateManager.GameState.keys()[to_state]]
		return result
	
	# Resource requirements validation
	var resource_check: ResourceCheckResult = _validate_resource_requirements(to_state, data)
	if not resource_check.is_valid:
		result.error_message = "Resource requirements not met: " + resource_check.error_message
		result.required_resources = resource_check.required_resources
		result.can_retry = true
		return result
	
	# Dependency validation
	var dependency_check: StateValidationResult = _validate_state_dependencies(to_state, data)
	if not dependency_check.is_valid:
		result.error_message = "State dependencies not satisfied: " + dependency_check.error_message
		result.required_conditions = dependency_check.required_conditions
		result.can_retry = true
		return result
	
	# Custom validation rules
	var custom_check: CustomValidationResult = _validate_custom_rules(from_state, to_state, data)
	if not custom_check.is_valid:
		result.error_message = "Custom validation failed: " + custom_check.error_message
		return result
	
	result.is_valid = true
	result.required_resources = resource_check.required_resources
	result.warning_messages = custom_check.warnings
	
	return result

## Validate basic transition using existing GameStateManager logic
func _is_basic_transition_valid(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState) -> bool:
	# Leverage existing GameStateManager validation
	return GameStateManager._is_valid_transition(from_state, to_state)

## Validate resource requirements for target state
func _validate_resource_requirements(target_state: GameStateManager.GameState, data: Dictionary) -> ResourceCheckResult:
	var result: ResourceCheckResult = ResourceCheckResult.new()
	result.is_valid = true
	
	match target_state:
		GameStateManager.GameState.MISSION:
			# Mission requires loaded mission data
			if not data.has("mission_data") or not data["mission_data"]:
				result.is_valid = false
				result.error_message = "Mission data must be loaded before entering mission state"
				result.required_resources.append("mission_data")
		
		GameStateManager.GameState.SHIP_SELECTION:
			# Ship selection requires available ships and mission context
			if not data.has("available_ships") or (data["available_ships"] as Array).is_empty():
				result.is_valid = false
				result.error_message = "No ships available for selection"
				result.required_resources.append("available_ships")
		
		GameStateManager.GameState.BRIEFING:
			# Briefing requires mission briefing data
			if not data.has("briefing_data"):
				result.is_valid = false
				result.error_message = "Briefing data not available"
				result.required_resources.append("briefing_data")
		
		GameStateManager.GameState.SAVE_GAME_MENU:
			# Save game menu requires valid pilot profile
			if not SaveGameManager or not SaveGameManager.has_active_profile():
				result.is_valid = false
				result.error_message = "No active pilot profile for save operations"
				result.required_resources.append("active_pilot_profile")
	
	return result

## State-specific dependency validation  
func _validate_state_dependencies(target_state: GameStateManager.GameState, data: Dictionary) -> StateValidationResult:
	var result: StateValidationResult = StateValidationResult.new()
	result.is_valid = true
	
	match target_state:
		GameStateManager.GameState.CAMPAIGN_MENU:
			# Campaign menu requires pilot selection
			if not _has_selected_pilot():
				result.is_valid = false
				result.error_message = "No pilot selected for campaign access"
				result.required_conditions.append("pilot_selected")
		
		GameStateManager.GameState.BRIEFING:
			# Briefing requires campaign and mission selection
			if not _has_selected_campaign():
				result.is_valid = false
				result.error_message = "No campaign selected for mission briefing"
				result.required_conditions.append("campaign_selected")
		
		GameStateManager.GameState.SHIP_SELECTION:
			# Ship selection requires mission briefing completion
			if not data.has("briefing_completed") or not data["briefing_completed"]:
				result.is_valid = false
				result.error_message = "Mission briefing must be completed before ship selection"
				result.required_conditions.append("briefing_completed")
		
		GameStateManager.GameState.MISSION:
			# Mission requires ship selection and loadout
			if not data.has("selected_ship") or not data["selected_ship"]:
				result.is_valid = false
				result.error_message = "Ship must be selected before entering mission"
				result.required_conditions.append("ship_selected")
		
		GameStateManager.GameState.MISSION_COMPLETE:
			# Mission complete requires mission to be in progress
			if GameStateManager.get_current_state() != GameStateManager.GameState.MISSION:
				result.is_valid = false
				result.error_message = "Mission must be active to complete"
				result.required_conditions.append("mission_active")
		
		GameStateManager.GameState.STATISTICS_REVIEW:
			# Statistics review requires pilot data
			if not _has_pilot_statistics():
				result.is_valid = false
				result.error_message = "No pilot statistics available for review"
				result.required_conditions.append("pilot_statistics_available")
	
	return result

## Custom validation rules for specific game logic
func _validate_custom_rules(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState, data: Dictionary) -> CustomValidationResult:
	var result: CustomValidationResult = CustomValidationResult.new()
	result.is_valid = true
	
	# Validate campaign completion flow
	if to_state == GameStateManager.GameState.CAMPAIGN_COMPLETE:
		if not _is_campaign_actually_complete():
			result.is_valid = false
			result.error_message = "Campaign is not actually complete"
			return result
	
	# Validate mission flow consistency
	if from_state == GameStateManager.GameState.MISSION and to_state == GameStateManager.GameState.DEBRIEF:
		if not _is_mission_properly_completed():
			result.warnings.append("Mission may not have completed properly")
	
	# Validate save game operations
	if to_state == GameStateManager.GameState.SAVE_GAME_MENU:
		if not _is_safe_to_save():
			result.warnings.append("Current game state may not be optimal for saving")
	
	# Validate editor access
	if to_state == GameStateManager.GameState.FRED_EDITOR:
		if not _is_editor_access_allowed():
			result.is_valid = false
			result.error_message = "FRED Editor access not allowed in current context"
			return result
	
	return result

## Helper methods for dependency checking

func _has_selected_pilot() -> bool:
	# Check if a pilot is currently selected (integrate with existing pilot system)
	return GameStateManager.get_player_data("current_pilot") != null

func _has_selected_campaign() -> bool:
	# Check if a campaign is currently selected
	return GameStateManager.get_session_data("current_campaign") != null

func _has_pilot_statistics() -> bool:
	# Check if pilot statistics are available
	var pilot_data: Variant = GameStateManager.get_player_data("current_pilot")
	return pilot_data != null and pilot_data.get("statistics") != null

func _is_campaign_actually_complete() -> bool:
	# Validate campaign completion status
	var campaign_data: Variant = GameStateManager.get_session_data("current_campaign")
	if not campaign_data:
		return false
	return campaign_data.get("completed", false)

func _is_mission_properly_completed() -> bool:
	# Check if mission completed successfully
	var mission_status: Variant = GameStateManager.get_mission_data("completion_status")
	return mission_status != null and mission_status != "failed"

func _is_safe_to_save() -> bool:
	# Check if current state is safe for saving
	var current_state: GameStateManager.GameState = GameStateManager.get_current_state()
	var safe_save_states: Array[GameStateManager.GameState] = [
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.CAMPAIGN_MENU,
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.DEBRIEF,
		GameStateManager.GameState.PILOT_SELECTION,
		GameStateManager.GameState.STATISTICS_REVIEW
	]
	return current_state in safe_save_states

func _is_editor_access_allowed() -> bool:
	# Check if FRED editor access is allowed (e.g., debug mode, developer build)
	return GameStateManager.debug_mode or OS.is_debug_build()

## Performance validation
func validate_transition_performance(from_state: GameStateManager.GameState, to_state: GameStateManager.GameState) -> bool:
	"""Validate that the transition can be performed within performance requirements"""
	# Some transitions are known to be expensive
	var expensive_transitions: Array[Array] = [
		[GameStateManager.GameState.MAIN_MENU, GameStateManager.GameState.MISSION],
		[GameStateManager.GameState.MISSION, GameStateManager.GameState.MAIN_MENU],
		[GameStateManager.GameState.LOADING, GameStateManager.GameState.MISSION]
	]
	
	var current_transition: Array = [from_state, to_state]
	if current_transition in expensive_transitions:
		# Check system performance
		var available_memory: int = OS.get_static_memory_peak_usage()
		return available_memory > 100 * 1024 * 1024  # Require at least 100MB free
	
	return true

## Memory usage validation
func validate_memory_requirements(target_state: GameStateManager.GameState) -> bool:
	"""Validate memory requirements for target state"""
	var required_memory: Dictionary = {
		GameStateManager.GameState.MISSION: 200 * 1024 * 1024,  # 200MB for mission
		GameStateManager.GameState.FRED_EDITOR: 150 * 1024 * 1024,  # 150MB for editor
		GameStateManager.GameState.LOADING: 100 * 1024 * 1024  # 100MB for loading
	}
	
	if target_state in required_memory:
		var available: int = OS.get_static_memory_peak_usage()
		return available >= required_memory[target_state]
	
	return true