extends GdUnitTestSuite

## Unit tests for GameStateManager
## Tests state transitions, scene management, and data persistence

var game_state_manager: GameStateManager

func before_test() -> void:
	# Create a clean GameStateManager instance for testing
	game_state_manager = GameStateManager.new()
	game_state_manager._initialize_manager()
	add_child(game_state_manager)

func after_test() -> void:
	if game_state_manager and is_instance_valid(game_state_manager):
		game_state_manager.shutdown()
		game_state_manager.queue_free()

func test_game_state_manager_initialization() -> void:
	assert_that(game_state_manager).is_not_null()
	assert_that(game_state_manager.is_initialized).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.MAIN_MENU)

func test_valid_state_transition() -> void:
	var signal_monitor = monitor_signals(game_state_manager)
	
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.BRIEFING)
	
	assert_that(success).is_true()
	assert_signal(signal_monitor).is_emitted("state_transition_started", [GameStateManager.GameState.BRIEFING])

func test_invalid_state_transition() -> void:
	# Try to go directly from MAIN_MENU to DEBRIEF (invalid)
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.DEBRIEF)
	
	assert_that(success).is_false()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.MAIN_MENU)

func test_state_stack_push_pop() -> void:
	# Push to options from main menu
	var success: bool = game_state_manager.push_state(GameStateManager.GameState.OPTIONS)
	assert_that(success).is_true()
	assert_that(game_state_manager.get_state_stack_depth()).is_equal(1)
	
	# Pop back to main menu
	success = game_state_manager.pop_state()
	assert_that(success).is_true()
	assert_that(game_state_manager.get_current_state()).is_equal(GameStateManager.GameState.MAIN_MENU)
	assert_that(game_state_manager.get_state_stack_depth()).is_equal(0)

func test_state_stack_empty_pop() -> void:
	# Try to pop from empty stack
	var success: bool = game_state_manager.pop_state()
	assert_that(success).is_false()

func test_session_data_management() -> void:
	game_state_manager.set_session_data("test_key", "test_value")
	
	var value: Variant = game_state_manager.get_session_data("test_key")
	assert_that(value).is_equal("test_value")
	
	var default_value: Variant = game_state_manager.get_session_data("nonexistent_key", "default")
	assert_that(default_value).is_equal("default")

func test_player_data_management() -> void:
	game_state_manager.set_player_data("score", 1000)
	game_state_manager.set_player_data("level", 5)
	
	assert_that(game_state_manager.get_player_data("score")).is_equal(1000)
	assert_that(game_state_manager.get_player_data("level")).is_equal(5)

func test_mission_data_management() -> void:
	game_state_manager.set_mission_data("difficulty", "hard")
	game_state_manager.set_mission_data("objectives", ["destroy enemy", "protect cargo"])
	
	assert_that(game_state_manager.get_mission_data("difficulty")).is_equal("hard")
	var objectives: Array = game_state_manager.get_mission_data("objectives")
	assert_that(objectives).has_size(2)

func test_clear_mission_data() -> void:
	game_state_manager.set_mission_data("temp_data", "value")
	assert_that(game_state_manager.get_mission_data("temp_data")).is_equal("value")
	
	game_state_manager.clear_mission_data()
	assert_that(game_state_manager.get_mission_data("temp_data")).is_null()

func test_is_in_state() -> void:
	assert_that(game_state_manager.is_in_state(GameStateManager.GameState.MAIN_MENU)).is_true()
	assert_that(game_state_manager.is_in_state(GameStateManager.GameState.MISSION)).is_false()

func test_is_in_any_state() -> void:
	var test_states: Array[GameStateManager.GameState] = [
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.OPTIONS
	]
	
	assert_that(game_state_manager.is_in_any_state(test_states)).is_true()
	
	var other_states: Array[GameStateManager.GameState] = [
		GameStateManager.GameState.MISSION,
		GameStateManager.GameState.BRIEFING
	]
	
	assert_that(game_state_manager.is_in_any_state(other_states)).is_false()

func test_state_transition_signals() -> void:
	var signal_monitor = monitor_signals(game_state_manager)
	
	game_state_manager.request_state_change(GameStateManager.GameState.OPTIONS)
	
	# Should emit transition started signal
	assert_signal(signal_monitor).is_emitted("state_transition_started", [GameStateManager.GameState.OPTIONS])
	
	# Wait for transition to complete
	await wait_signal(signal_monitor.get_signal("state_transition_completed"), 2.0)
	
	# Should emit state changed and transition completed signals
	assert_signal(signal_monitor).is_emitted("state_changed")
	assert_signal(signal_monitor).is_emitted("state_transition_completed", [GameStateManager.GameState.OPTIONS])

func test_concurrent_state_change_protection() -> void:
	# Start a state transition
	game_state_manager.request_state_change(GameStateManager.GameState.OPTIONS)
	
	# Try to start another transition while first is in progress
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.BRIEFING)
	
	assert_that(success).is_false()
	assert_that(game_state_manager.is_transitioning_to_state()).is_true()

func test_same_state_transition() -> void:
	# Try to transition to the same state
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
	
	assert_that(success).is_true()  # Should succeed but be a no-op

func test_performance_stats() -> void:
	game_state_manager.set_session_data("key1", "value1")
	game_state_manager.set_player_data("key2", "value2")
	game_state_manager.set_mission_data("key3", "value3")
	
	var stats: Dictionary = game_state_manager.get_performance_stats()
	
	assert_that(stats).contains_key("current_state")
	assert_that(stats).contains_key("previous_state")
	assert_that(stats).contains_key("is_transitioning")
	assert_that(stats).contains_key("session_data_size")
	assert_that(stats).contains_key("player_data_size")
	assert_that(stats).contains_key("mission_data_size")
	
	assert_that(stats.get("session_data_size")).is_equal(1)
	assert_that(stats.get("player_data_size")).is_equal(1)
	assert_that(stats.get("mission_data_size")).is_equal(1)

func test_fred_editor_state() -> void:
	# Test transition to FRED editor state
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.FRED_EDITOR)
	
	assert_that(success).is_true()
	assert_that(game_state_manager.is_transitioning_to_state()).is_true()

func test_shutdown_state() -> void:
	# Test transition to shutdown state
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.SHUTDOWN)
	
	assert_that(success).is_true()

func test_state_validation() -> void:
	# All enum values should be valid states
	for state_value in GameStateManager.GameState.values():
		var state: GameStateManager.GameState = state_value as GameStateManager.GameState
		
		# State should have a string representation
		var state_name: String = GameStateManager.GameState.keys()[state]
		assert_that(state_name).is_not_equal("")

func test_debug_print_functionality() -> void:
	# Should not crash when called
	game_state_manager.debug_print_state_info()

func test_error_handling() -> void:
	# Test with invalid transition configuration
	game_state_manager.transition_fade_time = -1.0
	
	# Should handle gracefully without crashing
	var success: bool = game_state_manager.request_state_change(GameStateManager.GameState.OPTIONS)
	# Result may vary based on error handling implementation

func test_scene_map_initialization() -> void:
	# Scene map should be properly initialized
	assert_that(game_state_manager.scene_map).is_not_empty()
	assert_that(game_state_manager.scene_map).contains_key(GameStateManager.GameState.MAIN_MENU)
	assert_that(game_state_manager.scene_map).contains_key(GameStateManager.GameState.MISSION)

func test_cleanup_on_shutdown() -> void:
	# Add some data
	game_state_manager.set_session_data("cleanup_test", "data")
	game_state_manager.set_player_data("cleanup_test", "data")
	game_state_manager.set_mission_data("cleanup_test", "data")
	
	# Shutdown should clear everything
	game_state_manager.shutdown()
	
	assert_that(game_state_manager.is_initialized).is_false()
	
	# Data should be cleared (if accessible after shutdown)
	if game_state_manager.has_method("get_session_data"):
		assert_that(game_state_manager.get_session_data("cleanup_test")).is_null()

func test_state_persistence_across_transitions() -> void:
	# Set some persistent data
	game_state_manager.set_player_data("persistent_score", 500)
	
	# Transition to options and back
	game_state_manager.request_state_change(GameStateManager.GameState.OPTIONS)
	await wait_signal(monitor_signals(game_state_manager).get_signal("state_transition_completed"), 2.0)
	
	game_state_manager.request_state_change(GameStateManager.GameState.MAIN_MENU)
	await wait_signal(monitor_signals(game_state_manager).get_signal("state_transition_completed"), 2.0)
	
	# Player data should persist
	assert_that(game_state_manager.get_player_data("persistent_score")).is_equal(500)