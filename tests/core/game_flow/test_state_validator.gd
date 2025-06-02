extends GdUnitTestSuite

## Unit tests for State Validator (FLOW-002)
## Tests comprehensive state transition validation rules, dependency checking, and error recovery

const StateValidator = preload("res://scripts/core/game_flow/state_management/state_validator.gd")

var state_validator: StateValidator
var game_state_manager: Node

func before():
	# Get reference to GameStateManager autoload
	game_state_manager = GameStateManager
	if not game_state_manager:
		fail("GameStateManager autoload not found")
	
	# Create state validator instance
	state_validator = StateValidator.new()
	if not state_validator:
		fail("Failed to create StateValidator instance")

func after():
	# Clean up
	if state_validator:
		state_validator = null
	
	# Reset game state
	if game_state_manager and game_state_manager.get_current_state() != GameStateManager.GameState.MAIN_MENU:
		game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
		await game_state_manager.state_transition_completed

func test_state_validator_initialization():
	"""Test State Validator initialization"""
	assert_that(state_validator).is_not_null()

func test_valid_basic_transitions():
	"""Test basic valid state transitions"""
	# Test valid transitions using existing GameStateManager logic
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.PILOT_SELECTION,
		{}
	)
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid).is_true()
	assert_that(result.error_message).is_empty()

func test_invalid_basic_transitions():
	"""Test invalid basic state transitions"""
	# Test invalid transition
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.SHIP_SELECTION,  # Can't go directly to ship selection
		{}
	)
	
	assert_that(result).is_not_null()
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("Invalid state transition")

func test_resource_requirement_validation():
	"""Test resource requirement validation for different states"""
	# Test mission state resource requirements
	var mission_data_missing: Dictionary = {}
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.MISSION,
		mission_data_missing
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("Mission data must be loaded")
	assert_that(result.required_resources).contains("mission_data")
	assert_that(result.can_retry).is_true()
	
	# Test with valid mission data
	var mission_data_valid: Dictionary = {
		"mission_data": {"name": "Test Mission", "objectives": []}
	}
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.MISSION,
		mission_data_valid
	)
	
	assert_that(result.is_valid).is_true()

func test_ship_selection_validation():
	"""Test ship selection state validation"""
	# Test ship selection without available ships
	var no_ships_data: Dictionary = {}
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.SHIP_SELECTION,
		no_ships_data
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("No ships available")
	assert_that(result.required_resources).contains("available_ships")
	
	# Test with available ships
	var ships_data: Dictionary = {
		"available_ships": ["Hercules", "Perseus", "Ares"]
	}
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.SHIP_SELECTION,
		ships_data
	)
	
	assert_that(result.is_valid).is_true()

func test_briefing_validation():
	"""Test briefing state validation"""
	# Test briefing without briefing data
	var no_briefing_data: Dictionary = {}
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.CAMPAIGN_MENU,
		GameStateManager.GameState.BRIEFING,
		no_briefing_data
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("Briefing data not available")
	assert_that(result.required_resources).contains("briefing_data")
	
	# Test with briefing data
	var briefing_data: Dictionary = {
		"briefing_data": {"mission_name": "Test Mission", "objectives": []}
	}
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.CAMPAIGN_MENU,
		GameStateManager.GameState.BRIEFING,
		briefing_data
	)
	
	assert_that(result.is_valid).is_true()

func test_save_game_menu_validation():
	"""Test save game menu validation"""
	# Test without active pilot profile (assuming SaveGameManager is not initialized with profile)
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.SAVE_GAME_MENU,
		{}
	)
	
	# Should check for active pilot profile
	if not SaveGameManager or not SaveGameManager.has_active_profile():
		assert_that(result.is_valid).is_false()
		assert_that(result.error_message).contains("No active pilot profile")
		assert_that(result.required_resources).contains("active_pilot_profile")

func test_state_dependency_validation():
	"""Test state dependency validation"""
	# Set up pilot data in GameStateManager
	game_state_manager.set_player_data("current_pilot", null)
	
	# Test campaign menu access without pilot
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.CAMPAIGN_MENU,
		{}
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("No pilot selected")
	assert_that(result.required_conditions).contains("pilot_selected")
	
	# Set pilot data and test again
	game_state_manager.set_player_data("current_pilot", {"name": "Test Pilot"})
	
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.CAMPAIGN_MENU,
		{}
	)
	
	assert_that(result.is_valid).is_true()

func test_briefing_dependency_validation():
	"""Test briefing dependency validation (requires campaign selection)"""
	# Clear campaign data
	game_state_manager.set_session_data("current_campaign", null)
	
	var briefing_data: Dictionary = {
		"briefing_data": {"mission_name": "Test Mission"}
	}
	
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.CAMPAIGN_MENU,
		GameStateManager.GameState.BRIEFING,
		briefing_data
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("No campaign selected")
	assert_that(result.required_conditions).contains("campaign_selected")
	
	# Set campaign data
	game_state_manager.set_session_data("current_campaign", {"name": "Test Campaign"})
	
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.CAMPAIGN_MENU,
		GameStateManager.GameState.BRIEFING,
		briefing_data
	)
	
	assert_that(result.is_valid).is_true()

func test_ship_selection_dependency_validation():
	"""Test ship selection dependency validation (requires briefing completion)"""
	var incomplete_briefing_data: Dictionary = {
		"available_ships": ["Hercules"],
		"briefing_completed": false
	}
	
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.SHIP_SELECTION,
		incomplete_briefing_data
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("Mission briefing must be completed")
	assert_that(result.required_conditions).contains("briefing_completed")
	
	# Mark briefing as completed
	var completed_briefing_data: Dictionary = {
		"available_ships": ["Hercules"],
		"briefing_completed": true
	}
	
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.BRIEFING,
		GameStateManager.GameState.SHIP_SELECTION,
		completed_briefing_data
	)
	
	assert_that(result.is_valid).is_true()

func test_mission_dependency_validation():
	"""Test mission dependency validation (requires ship selection)"""
	var no_ship_data: Dictionary = {
		"mission_data": {"name": "Test Mission"}
	}
	
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.SHIP_SELECTION,
		GameStateManager.GameState.MISSION,
		no_ship_data
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("Ship must be selected")
	assert_that(result.required_conditions).contains("ship_selected")
	
	# Add ship selection
	var ship_selected_data: Dictionary = {
		"mission_data": {"name": "Test Mission"},
		"selected_ship": "Hercules"
	}
	
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.SHIP_SELECTION,
		GameStateManager.GameState.MISSION,
		ship_selected_data
	)
	
	assert_that(result.is_valid).is_true()

func test_custom_validation_rules():
	"""Test custom validation rules"""
	# Test campaign completion validation
	game_state_manager.set_session_data("current_campaign", {"completed": false})
	
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MISSION_COMPLETE,
		GameStateManager.GameState.CAMPAIGN_COMPLETE,
		{}
	)
	
	assert_that(result.is_valid).is_false()
	assert_that(result.error_message).contains("Campaign is not actually complete")
	
	# Mark campaign as complete
	game_state_manager.set_session_data("current_campaign", {"completed": true})
	
	result = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MISSION_COMPLETE,
		GameStateManager.GameState.CAMPAIGN_COMPLETE,
		{}
	)
	
	assert_that(result.is_valid).is_true()

func test_editor_access_validation():
	"""Test FRED editor access validation"""
	# Test editor access validation (should check debug mode)
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.FRED_EDITOR,
		{}
	)
	
	# Editor access depends on debug mode or debug build
	if not GameStateManager.debug_mode and not OS.is_debug_build():
		assert_that(result.is_valid).is_false()
		assert_that(result.error_message).contains("FRED Editor access not allowed")

func test_performance_validation():
	"""Test performance requirements validation"""
	# Test expensive transitions
	var performance_valid: bool = state_validator.validate_transition_performance(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.MISSION
	)
	
	# Performance validation should return a boolean
	assert_that(typeof(performance_valid)).is_equal(TYPE_BOOL)

func test_memory_validation():
	"""Test memory requirements validation"""
	# Test memory requirements for different states
	var memory_valid_mission: bool = state_validator.validate_memory_requirements(
		GameStateManager.GameState.MISSION
	)
	var memory_valid_editor: bool = state_validator.validate_memory_requirements(
		GameStateManager.GameState.FRED_EDITOR
	)
	var memory_valid_loading: bool = state_validator.validate_memory_requirements(
		GameStateManager.GameState.LOADING
	)
	
	# Memory validation should return booleans
	assert_that(typeof(memory_valid_mission)).is_equal(TYPE_BOOL)
	assert_that(typeof(memory_valid_editor)).is_equal(TYPE_BOOL)
	assert_that(typeof(memory_valid_loading)).is_equal(TYPE_BOOL)

func test_validation_result_structure():
	"""Test validation result data structure completeness"""
	var result: StateValidator.StateValidationResult = state_validator.validate_transition_preconditions(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.PILOT_SELECTION,
		{}
	)
	
	# Verify all required fields exist
	assert_that(result.has_method("is_valid")).is_true()
	assert_that(result.error_message).is_not_null()
	assert_that(result.warning_messages).is_not_null()
	assert_that(result.required_resources).is_not_null()
	assert_that(result.can_retry).is_not_null()
	assert_that(result.required_conditions).is_not_null()
	
	# Verify field types
	assert_that(typeof(result.is_valid)).is_equal(TYPE_BOOL)
	assert_that(typeof(result.error_message)).is_equal(TYPE_STRING)
	assert_that(typeof(result.warning_messages)).is_equal(TYPE_ARRAY)
	assert_that(typeof(result.required_resources)).is_equal(TYPE_ARRAY)
	assert_that(typeof(result.can_retry)).is_equal(TYPE_BOOL)
	assert_that(typeof(result.required_conditions)).is_equal(TYPE_ARRAY)