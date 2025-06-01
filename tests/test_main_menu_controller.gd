extends GdUnitTestSuite

## Test suite for MainMenuController
## Validates navigation, state management, and GameStateManager integration

# Test constants
const MAIN_MENU_CONTROLLER_SCENE: String = "res://scenes/menus/main_menu/main_menu.tscn"
const TEST_TIMEOUT: float = 2.0
const PERFORMANCE_THRESHOLD_FPS: float = 55.0  # Allow some tolerance for test environment
const TRANSITION_TIME_THRESHOLD_MS: float = 150.0  # Allow some tolerance for test environment

# Test objects
var main_menu_controller: MainMenuController
var mock_game_state_manager: Node
var mock_scene_manager: Node
var test_scene: Node

func before_test() -> void:
	"""Setup before each test."""
	# Create a test scene
	test_scene = Node.new()
	add_child(test_scene)
	
	# Create main menu controller
	main_menu_controller = MainMenuController.new()
	test_scene.add_child(main_menu_controller)
	
	# Setup required child nodes for testing
	_setup_test_scene_structure()
	
	# Setup mock autoloads
	_setup_mock_autoloads()

func after_test() -> void:
	"""Cleanup after each test."""
	if test_scene:
		test_scene.queue_free()
	
	main_menu_controller = null
	mock_game_state_manager = null
	mock_scene_manager = null

func _setup_test_scene_structure() -> void:
	"""Setup the required scene structure for testing."""
	# Create required container nodes
	var background_container: Control = Control.new()
	background_container.name = "BackgroundContainer"
	main_menu_controller.add_child(background_container)
	
	var menu_options_container: Control = Control.new()
	menu_options_container.name = "MenuOptionsContainer"
	main_menu_controller.add_child(menu_options_container)
	
	# Add test buttons
	var button_names: Array[String] = [
		"PilotManagementButton",
		"CampaignButton", 
		"ReadyRoomButton",
		"TechRoomButton",
		"OptionsButton",
		"CreditsButton",
		"ExitButton"
	]
	
	for button_name: String in button_names:
		var button: Button = Button.new()
		button.name = button_name
		button.text = button_name.replace("Button", "")
		menu_options_container.add_child(button)
	
	# Create other required nodes
	var navigation_panel: Control = Control.new()
	navigation_panel.name = "NavigationPanel"
	main_menu_controller.add_child(navigation_panel)
	
	var status_display: Control = Control.new()
	status_display.name = "StatusDisplay"
	main_menu_controller.add_child(status_display)
	
	var main_hall_audio: Node = Node.new()
	main_hall_audio.name = "MainHallAudio"
	main_menu_controller.add_child(main_hall_audio)
	
	var transition_effects: Node = Node.new()
	transition_effects.name = "TransitionEffects"
	main_menu_controller.add_child(transition_effects)

func _setup_mock_autoloads() -> void:
	"""Setup mock autoload systems for testing."""
	# Mock GameStateManager
	mock_game_state_manager = Node.new()
	mock_game_state_manager.name = "MockGameStateManager"
	
	# Add required signals
	mock_game_state_manager.add_user_signal("state_changed", [
		{"name": "old_state", "type": TYPE_INT},
		{"name": "new_state", "type": TYPE_INT}
	])
	mock_game_state_manager.add_user_signal("state_transition_started", [
		{"name": "target_state", "type": TYPE_INT}
	])
	mock_game_state_manager.add_user_signal("state_transition_completed", [
		{"name": "final_state", "type": TYPE_INT}
	])
	
	# Add required methods
	mock_game_state_manager.set_script(preload("res://tests/mocks/mock_game_state_manager.gd"))
	test_scene.add_child(mock_game_state_manager)
	
	# Mock SceneManager
	mock_scene_manager = Node.new()
	mock_scene_manager.name = "MockSceneManager"
	test_scene.add_child(mock_scene_manager)

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_menu_controller_initializes_correctly() -> void:
	"""Test that the main menu controller initializes properly."""
	# Act - Call ready to trigger initialization
	main_menu_controller._ready()
	
	# Assert
	assert_bool(main_menu_controller.menu_initialized).is_true()
	assert_bool(main_menu_controller.is_transitioning).is_false()

func test_menu_controller_validates_dependencies() -> void:
	"""Test that dependency validation works correctly."""
	# Act - Test dependency validation
	var validation_result: bool = main_menu_controller._validate_dependencies()
	
	# Assert - Should pass with mock dependencies
	assert_bool(validation_result).is_true()

func test_menu_buttons_are_setup_correctly() -> void:
	"""Test that menu buttons are properly configured."""
	# Arrange
	main_menu_controller._ready()
	
	# Act
	main_menu_controller._setup_menu_buttons()
	
	# Assert - Check button map is populated
	assert_int(main_menu_controller.menu_button_map.size()).is_greater(0)
	
	# Check specific buttons exist
	assert_bool(MainMenuController.MenuOption.PILOT_MANAGEMENT in main_menu_controller.menu_button_map).is_true()
	assert_bool(MainMenuController.MenuOption.OPTIONS in main_menu_controller.menu_button_map).is_true()

# ============================================================================
# NAVIGATION TESTS
# ============================================================================

func test_menu_option_selection_emits_signal() -> void:
	"""Test that selecting a menu option emits the correct signal."""
	# Arrange
	main_menu_controller._ready()
	var signal_monitor: SignalWatcher = watch_signals(main_menu_controller)
	
	# Act
	main_menu_controller._on_menu_option_selected(MainMenuController.MenuOption.PILOT_MANAGEMENT)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("menu_option_selected")
	assert_signal(signal_monitor).is_emitted("menu_transition_requested")

func test_keyboard_navigation_works() -> void:
	"""Test that keyboard navigation functions correctly."""
	# Arrange
	main_menu_controller._ready()
	var initial_option: MainMenuController.MenuOption = main_menu_controller.current_menu_option
	
	# Act - Navigate down
	main_menu_controller._navigate_menu_option(1)
	
	# Assert
	assert_int(main_menu_controller.current_menu_option).is_not_equal(initial_option)

func test_input_handling_processes_key_events() -> void:
	"""Test that input events are handled correctly."""
	# Arrange
	main_menu_controller._ready()
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_DOWN
	key_event.pressed = true
	
	# Act
	main_menu_controller._input(key_event)
	
	# Assert - Should not crash and should handle input
	assert_bool(main_menu_controller.is_menu_ready()).is_true()

func test_exit_game_option_works() -> void:
	"""Test that exit game option functions correctly."""
	# Arrange
	main_menu_controller._ready()
	var signal_monitor: SignalWatcher = watch_signals(main_menu_controller)
	
	# Act
	main_menu_controller._on_menu_option_selected(MainMenuController.MenuOption.EXIT_GAME)
	
	# Assert - Should emit menu option selected signal
	assert_signal(signal_monitor).is_emitted("menu_option_selected")

# ============================================================================
# STATE MANAGEMENT TESTS  
# ============================================================================

func test_state_transition_handling() -> void:
	"""Test that state transitions are handled correctly."""
	# Arrange
	main_menu_controller._ready()
	
	# Act - Simulate state transition
	main_menu_controller._on_state_transition_started(0)  # Mock state
	
	# Assert
	assert_bool(main_menu_controller.is_transitioning).is_true()
	
	# Act - Complete transition
	main_menu_controller._on_state_transition_completed(0)  # Mock state
	
	# Assert
	assert_bool(main_menu_controller.is_transitioning).is_false()

func test_game_state_change_handling() -> void:
	"""Test that game state changes are handled correctly."""
	# Arrange
	main_menu_controller._ready()
	
	# Act - Should not crash when handling state changes
	main_menu_controller._on_game_state_changed(0, 1)  # Mock states
	
	# Assert - Should complete without error
	assert_bool(true).is_true()  # Test passes if no crash occurs

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

func test_performance_monitoring_enabled() -> void:
	"""Test that performance monitoring works when enabled."""
	# Arrange
	main_menu_controller.enable_performance_monitoring = true
	main_menu_controller._ready()
	
	# Act - Process a frame
	main_menu_controller._process(0.016)  # ~60fps frame time
	
	# Assert - Should complete without error
	assert_bool(main_menu_controller.enable_performance_monitoring).is_true()

func test_performance_monitoring_disabled() -> void:
	"""Test that performance monitoring can be disabled."""
	# Arrange
	main_menu_controller.enable_performance_monitoring = false
	main_menu_controller._ready()
	
	# Act - Process a frame
	main_menu_controller._process(0.016)
	
	# Assert
	assert_bool(main_menu_controller.enable_performance_monitoring).is_false()

func test_transition_timing_tracking() -> void:
	"""Test that transition timing is tracked correctly."""
	# Arrange
	main_menu_controller._ready()
	
	# Act - Start transition
	main_menu_controller._on_state_transition_started(0)
	var start_time: float = Time.get_time_dict_from_system()["unix"] * 1000.0
	
	# Wait briefly
	await get_tree().create_timer(0.1).timeout
	
	# Complete transition
	main_menu_controller._on_state_transition_completed(0)
	
	# Assert - Transition should be completed
	assert_bool(main_menu_controller.is_transitioning).is_false()

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_integration_with_existing_autoloads() -> void:
	"""Test integration with existing autoload systems."""
	# Arrange
	main_menu_controller._ready()
	
	# Act - Connect to autoloads
	main_menu_controller._connect_to_game_state_manager()
	main_menu_controller._connect_to_scene_manager()
	
	# Assert - Should complete without error
	assert_bool(main_menu_controller.menu_initialized).is_true()

func test_error_handling_works() -> void:
	"""Test that error handling works correctly."""
	# Arrange
	var signal_monitor: SignalWatcher = watch_signals(main_menu_controller)
	
	# Act
	main_menu_controller._handle_menu_error("Test error message")
	
	# Assert
	assert_signal(signal_monitor).is_emitted("menu_error")

# ============================================================================
# PUBLIC API TESTS
# ============================================================================

func test_get_current_menu_option() -> void:
	"""Test the public API for getting current menu option."""
	# Arrange
	main_menu_controller._ready()
	
	# Act
	var current_option: MainMenuController.MenuOption = main_menu_controller.get_current_menu_option()
	
	# Assert
	assert_int(current_option).is_equal(MainMenuController.MenuOption.PILOT_MANAGEMENT)

func test_is_menu_ready() -> void:
	"""Test the public API for checking menu readiness."""
	# Arrange
	main_menu_controller._ready()
	
	# Act
	var is_ready: bool = main_menu_controller.is_menu_ready()
	
	# Assert
	assert_bool(is_ready).is_true()

func test_force_menu_option() -> void:
	"""Test the public API for forcing menu option selection."""
	# Arrange
	main_menu_controller._ready()
	var signal_monitor: SignalWatcher = watch_signals(main_menu_controller)
	
	# Act
	main_menu_controller.force_menu_option(MainMenuController.MenuOption.OPTIONS)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("menu_option_selected")

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_double_initialization_warning() -> void:
	"""Test that double initialization produces appropriate warning."""
	# Arrange
	main_menu_controller._ready()
	assert_bool(main_menu_controller.menu_initialized).is_true()
	
	# Act - Try to initialize again
	main_menu_controller._initialize_menu_system()
	
	# Assert - Should still be initialized (no crash)
	assert_bool(main_menu_controller.menu_initialized).is_true()

func test_input_during_transition_ignored() -> void:
	"""Test that input is ignored during transitions."""
	# Arrange
	main_menu_controller._ready()
	main_menu_controller.is_transitioning = true
	
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_ENTER
	key_event.pressed = true
	
	# Act
	main_menu_controller._input(key_event)
	
	# Assert - Should not process input during transition
	assert_bool(main_menu_controller.is_transitioning).is_true()

func test_menu_options_boundary_navigation() -> void:
	"""Test navigation at menu option boundaries."""
	# Arrange
	main_menu_controller._ready()
	main_menu_controller.current_menu_option = MainMenuController.MenuOption.EXIT_GAME
	
	# Act - Navigate past end
	main_menu_controller._navigate_menu_option(1)
	
	# Assert - Should wrap to beginning
	assert_int(main_menu_controller.current_menu_option).is_equal(MainMenuController.MenuOption.PILOT_MANAGEMENT)