extends GdUnitTestSuite

## Unit tests for EPIC-007 GameStateManager enhancements
## Tests the new game flow states and transition validation

var game_state_manager: Node

func before():
	# Get reference to GameStateManager autoload
	game_state_manager = GameStateManager
	if not game_state_manager:
		fail("GameStateManager autoload not found")

func after():
	# Clean up any test state and reset to MAIN_MENU
	if game_state_manager:
		game_state_manager.clear_session_data()
		if game_state_manager.get_current_state() != GameStateManager.GameState.MAIN_MENU:
			game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
			await game_state_manager.state_transition_completed

func test_new_game_states_exist():
	"""Test that all new EPIC-007 game states are properly defined"""
	# Verify new states exist in enum
	assert_that(GameStateManager.GameState.has("PILOT_SELECTION")).is_true()
	assert_that(GameStateManager.GameState.has("SHIP_SELECTION")).is_true() 
	assert_that(GameStateManager.GameState.has("MISSION_COMPLETE")).is_true()
	assert_that(GameStateManager.GameState.has("CAMPAIGN_COMPLETE")).is_true()
	assert_that(GameStateManager.GameState.has("STATISTICS_REVIEW")).is_true()
	assert_that(GameStateManager.GameState.has("SAVE_GAME_MENU")).is_true()

func test_enhanced_state_transitions_valid():
	"""Test that valid state transitions for new game flow work correctly"""
	# Test MAIN_MENU -> PILOT_SELECTION
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.PILOT_SELECTION)).is_true()
	await game_state_manager.state_transition_completed
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.PILOT_SELECTION)
	
	# Test PILOT_SELECTION -> CAMPAIGN_MENU
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.CAMPAIGN_MENU)).is_true()
	await game_state_manager.state_transition_completed
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.CAMPAIGN_MENU)
	
	# Test CAMPAIGN_MENU -> BRIEFING
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.BRIEFING)).is_true()
	await game_state_manager.state_transition_completed
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.BRIEFING)
	
	# Test BRIEFING -> SHIP_SELECTION
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.SHIP_SELECTION)).is_true()
	await game_state_manager.state_transition_completed
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.SHIP_SELECTION)

func test_enhanced_state_transitions_invalid():
	"""Test that invalid state transitions are properly rejected"""
	# Ensure we start from MAIN_MENU
	if game_state_manager.get_current_state() != GameStateManager.GameState.MAIN_MENU:
		game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
		await game_state_manager.state_transition_completed
	
	# Invalid transitions should be rejected
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.SHIP_SELECTION)).is_false()
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.MISSION_COMPLETE)).is_false()
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.CAMPAIGN_COMPLETE)).is_false()
	
	# State should remain unchanged after invalid transition attempts
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.MAIN_MENU)

func test_mission_completion_flow():
	"""Test the mission completion state flow"""
	# Simulate mission completion flow
	game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
	game_state_manager.request_state_change(GameStateManager.GameState.BRIEFING)
	game_state_manager.request_state_change(GameStateManager.GameState.MISSION)
	
	# Test mission -> mission complete transition
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.MISSION_COMPLETE)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.MISSION_COMPLETE)
	
	# Test mission complete -> debrief transition
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.DEBRIEF)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.DEBRIEF)

func test_campaign_completion_flow():
	"""Test the campaign completion state flow"""
	# Simulate campaign completion
	game_state_manager.request_state_change(GameStateManager.GameState.MISSION_COMPLETE)
	
	# Test campaign completion transition
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.CAMPAIGN_COMPLETE)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.CAMPAIGN_COMPLETE)
	
	# Test campaign complete -> statistics review transition
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.STATISTICS_REVIEW)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.STATISTICS_REVIEW)

func test_save_game_menu_transitions():
	"""Test save game menu state transitions"""
	# Test access from main menu
	game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.SAVE_GAME_MENU)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.SAVE_GAME_MENU)
	
	# Test return to main menu
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.MAIN_MENU)

func test_statistics_review_transitions():
	"""Test statistics review state transitions"""
	# Test access from various states
	game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.STATISTICS_REVIEW)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.STATISTICS_REVIEW)
	
	# Test transition to pilot selection
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.PILOT_SELECTION)).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.PILOT_SELECTION)

func test_state_history_tracking_with_new_states():
	"""Test that state history is properly tracked with new states"""
	var initial_state: GameStateManager.GameState = game_state_manager.get_current_state()
	
	# Change to pilot selection
	game_state_manager.request_state_change(GameStateManager.GameState.PILOT_SELECTION)
	assert_that(game_state_manager.get_previous_state()).is_equal(initial_state)
	
	# Change to statistics review
	game_state_manager.request_state_change(GameStateManager.GameState.STATISTICS_REVIEW)
	assert_that(game_state_manager.get_previous_state()).is_equal(GameStateManager.GameState.PILOT_SELECTION)

func test_scene_map_includes_new_states():
	"""Test that scene map includes all new states"""
	# Access private scene_map through performance stats or debug methods
	var stats: Dictionary = game_state_manager.get_performance_stats()
	
	# Verify current state is tracked
	assert_that(stats.has("current_state")).is_true()
	assert_that(stats.has("previous_state")).is_true()
	
	# Test state changes work (indirect verification that scene map is correct)
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.PILOT_SELECTION)).is_true()
	assert_that(game_state_manager.request_state_change(GameStateManager.GameState.SAVE_GAME_MENU)).is_true()

func test_state_cleanup_initialization():
	"""Test that new state cleanup and initialization methods are called"""
	# Test ship selection state cleanup/initialization
	game_state_manager.request_state_change(GameStateManager.GameState.BRIEFING)
	game_state_manager.request_state_change(GameStateManager.GameState.SHIP_SELECTION)
	
	# Store session data to test cleanup
	game_state_manager.set_session_data("selected_ship", "Hercules")
	game_state_manager.set_session_data("ship_loadout", {"primary": "laser", "secondary": "missile"})
	
	# Change state to trigger cleanup
	game_state_manager.request_state_change(GameStateManager.GameState.BRIEFING)
	
	# Verify cleanup occurred (ship data should be cleared)
	assert_that(game_state_manager.get_session_data("selected_ship")).is_null()
	assert_that(game_state_manager.get_session_data("ship_loadout")).is_null()

func test_performance_requirements():
	"""Test that state transitions meet performance requirements (under 16ms)"""
	var start_time: int = Time.get_ticks_msec()
	
	# Perform multiple state transitions
	game_state_manager.request_state_change(GameStateManager.GameState.PILOT_SELECTION)
	game_state_manager.request_state_change(GameStateManager.GameState.CAMPAIGN_MENU)
	game_state_manager.request_state_change(GameStateManager.GameState.STATISTICS_REVIEW)
	
	var elapsed_time: int = Time.get_ticks_msec() - start_time
	
	# Each transition should be under 16ms (we test 3 transitions)
	assert_that(elapsed_time).is_less(48)  # 16ms * 3 transitions

func test_error_recovery_with_new_states():
	"""Test error recovery mechanisms work with new states"""
	# Force an invalid state scenario
	game_state_manager.request_state_change(GameStateManager.GameState.PILOT_SELECTION)
	
	# Attempt invalid transition
	var result: bool = game_state_manager.request_state_change(GameStateManager.GameState.MISSION_COMPLETE)
	assert_that(result).is_false()
	
	# Verify state remains valid
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.PILOT_SELECTION)
	assert_that(game_state_manager.is_transitioning_to_state()).is_false()