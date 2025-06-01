class_name MainMenuController
extends Control

## Main menu controller for WCS-Godot navigation system.
## Integrates with GameStateManager for state transitions and SceneManager for scene loading.
## Preserves WCS main hall functionality with Godot-native implementation.

signal menu_option_selected(option: MenuOption)
signal menu_transition_requested(target_state: GameStateManager.GameState)
signal menu_initialized()
signal menu_error(error_message: String)

# Menu option definitions matching WCS main hall functionality
enum MenuOption {
	PILOT_MANAGEMENT,    # Barracks - pilot creation and selection
	CAMPAIGN_SELECTION,  # Campaign room - campaign browsing and selection
	READY_ROOM,         # Ready room - mission briefing and start
	TECH_ROOM,          # Tech room - ship and weapon database
	OPTIONS,            # Options - game configuration
	CREDITS,            # Credits - game credits and information
	EXIT_GAME           # Exit - quit application
}

# Performance monitoring
@export var target_framerate: int = 60
@export var max_transition_time_ms: float = 100.0
@export var enable_performance_monitoring: bool = true

# Menu state management
var current_menu_option: MenuOption = MenuOption.PILOT_MANAGEMENT
var is_transitioning: bool = false
var transition_start_time: float = 0.0
var menu_initialized: bool = false

# UI references - will be connected in scene
@onready var background_container: Control = $BackgroundContainer
@onready var menu_options_container: Control = $MenuOptionsContainer
@onready var navigation_panel: Control = $NavigationPanel
@onready var status_display: Control = $StatusDisplay

# Sound and animation components
@onready var main_hall_audio: Node = $MainHallAudio
@onready var transition_effects: Node = $TransitionEffects

# Transition system integration
var menu_scene_helper: MenuSceneHelper = null

# Menu button mappings for navigation
var menu_button_map: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_menu_system()

func _initialize_menu_system() -> void:
	"""Initialize the main menu system with proper error handling."""
	if menu_initialized:
		push_warning("MainMenuController: Already initialized")
		return
	
	print("MainMenuController: Initializing main menu system...")
	
	# Validate dependencies
	if not _validate_dependencies():
		return
	
	# Initialize UI components
	_setup_menu_buttons()
	_setup_input_handling()
	_setup_performance_monitoring()
	
	# Connect to existing autoload systems
	_connect_to_game_state_manager()
	_connect_to_scene_manager()
	
	# Initialize audio and visual systems
	_initialize_main_hall_audio()
	_initialize_background_system()
	
	# Initialize transition system
	_initialize_transition_system()
	
	menu_initialized = true
	print("MainMenuController: Menu system initialization complete")
	menu_initialized.emit()

func _validate_dependencies() -> bool:
	"""Validate that required autoload systems are available."""
	if not GameStateManager:
		_handle_menu_error("GameStateManager autoload not found")
		return false
	
	if not SceneManager:
		_handle_menu_error("SceneManager addon not found")
		return false
	
	if not ConfigurationManager:
		_handle_menu_error("ConfigurationManager autoload not found")
		return false
	
	return true

func _setup_menu_buttons() -> void:
	"""Setup menu button connections and mappings."""
	# Define button to menu option mappings
	var button_mappings: Dictionary = {
		"PilotManagementButton": MenuOption.PILOT_MANAGEMENT,
		"CampaignButton": MenuOption.CAMPAIGN_SELECTION,
		"ReadyRoomButton": MenuOption.READY_ROOM,
		"TechRoomButton": MenuOption.TECH_ROOM,
		"OptionsButton": MenuOption.OPTIONS,
		"CreditsButton": MenuOption.CREDITS,
		"ExitButton": MenuOption.EXIT_GAME
	}
	
	# Connect buttons to navigation functions
	for button_name: String in button_mappings:
		var button: Button = menu_options_container.get_node_or_null(button_name)
		if button:
			var menu_option: MenuOption = button_mappings[button_name]
			button.pressed.connect(_on_menu_option_selected.bind(menu_option))
			
			# Setup hover effects for visual feedback
			button.mouse_entered.connect(_on_menu_button_hover_start.bind(menu_option))
			button.mouse_exited.connect(_on_menu_button_hover_end.bind(menu_option))
			
			menu_button_map[menu_option] = button
		else:
			push_warning("MainMenuController: Button not found: %s" % button_name)

func _setup_input_handling() -> void:
	"""Setup keyboard navigation for accessibility."""
	# Ensure this control can receive input
	set_process_input(true)
	
	# Setup focus navigation
	if menu_options_container:
		for child in menu_options_container.get_children():
			if child is Button:
				child.focus_mode = Control.FOCUS_ALL

func _setup_performance_monitoring() -> void:
	"""Setup performance monitoring if enabled."""
	if not enable_performance_monitoring:
		return
	
	# Monitor framerate and transition times
	set_process(true)

func _connect_to_game_state_manager() -> void:
	"""Connect to GameStateManager for state coordination."""
	if GameStateManager:
		# Listen for state changes to update menu state
		GameStateManager.state_changed.connect(_on_game_state_changed)
		GameStateManager.state_transition_started.connect(_on_state_transition_started)
		GameStateManager.state_transition_completed.connect(_on_state_transition_completed)

func _connect_to_scene_manager() -> void:
	"""Connect to SceneManager for scene transitions."""
	if SceneManager:
		# SceneManager will handle scene transitions
		# We just need to request transitions through GameStateManager
		pass

func _initialize_main_hall_audio() -> void:
	"""Initialize main hall ambient audio system."""
	if main_hall_audio and main_hall_audio.has_method("initialize_ambient_audio"):
		main_hall_audio.initialize_ambient_audio()

func _initialize_background_system() -> void:
	"""Initialize main hall background and animations."""
	if background_container and background_container.has_method("initialize_background"):
		background_container.initialize_background()

func _initialize_transition_system() -> void:
	"""Initialize the menu transition system."""
	if not menu_scene_helper:
		menu_scene_helper = MenuSceneHelper.new()
		add_child(menu_scene_helper)
		
		# Connect transition signals
		menu_scene_helper.transition_started.connect(_on_transition_started)
		menu_scene_helper.transition_completed.connect(_on_transition_completed)
		menu_scene_helper.transition_failed.connect(_on_transition_failed)
		
		print("MainMenuController: Transition system initialized")

func _input(event: InputEvent) -> void:
	"""Handle keyboard navigation input."""
	if not menu_initialized or is_transitioning:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_on_menu_option_selected(MenuOption.EXIT_GAME)
			KEY_ENTER:
				_activate_current_menu_option()
			KEY_UP:
				_navigate_menu_option(-1)
			KEY_DOWN:
				_navigate_menu_option(1)

func _process(delta: float) -> void:
	"""Monitor performance and update visual systems."""
	if not enable_performance_monitoring:
		return
	
	# Monitor framerate
	var current_fps: float = Engine.get_frames_per_second()
	if current_fps < target_framerate * 0.9:  # Allow 10% tolerance
		push_warning("MainMenuController: Performance warning - FPS: %.1f" % current_fps)
	
	# Monitor transition times
	if is_transitioning:
		var transition_time: float = (Time.get_time_dict_from_system()["unix"] * 1000.0) - transition_start_time
		if transition_time > max_transition_time_ms:
			push_warning("MainMenuController: Transition time exceeded target: %.1fms" % transition_time)

# ============================================================================
# MENU NAVIGATION METHODS
# ============================================================================

func _on_menu_option_selected(option: MenuOption) -> void:
	"""Handle menu option selection with proper state management."""
	if is_transitioning:
		return
	
	print("MainMenuController: Menu option selected: %s" % MenuOption.keys()[option])
	menu_option_selected.emit(option)
	
	# Start transition timing
	is_transitioning = true
	transition_start_time = Time.get_time_dict_from_system()["unix"] * 1000.0
	
	# Map menu options to GameStateManager states
	var target_state: GameStateManager.GameState
	match option:
		MenuOption.PILOT_MANAGEMENT:
			target_state = GameStateManager.GameState.MAIN_MENU  # Will need proper pilot management state
		MenuOption.CAMPAIGN_SELECTION:
			target_state = GameStateManager.GameState.CAMPAIGN_MENU
		MenuOption.READY_ROOM:
			target_state = GameStateManager.GameState.BRIEFING
		MenuOption.TECH_ROOM:
			target_state = GameStateManager.GameState.MAIN_MENU  # Will need proper tech room state
		MenuOption.OPTIONS:
			target_state = GameStateManager.GameState.OPTIONS
		MenuOption.CREDITS:
			target_state = GameStateManager.GameState.MAIN_MENU  # Will need proper credits state
		MenuOption.EXIT_GAME:
			_handle_exit_game()
			return
	
	# Request state transition through GameStateManager
	menu_transition_requested.emit(target_state)
	_request_state_transition(target_state)

func _request_state_transition(target_state: GameStateManager.GameState) -> void:
	"""Request state transition through GameStateManager with enhanced transitions."""
	if not GameStateManager:
		_handle_menu_error("Cannot request state transition - GameStateManager not available")
		return
	
	# Map GameState to scene paths and transition types
	var scene_path: String = ""
	var transition_type: MenuSceneHelper.WCSTransitionType = MenuSceneHelper.WCSTransitionType.FADE
	
	match target_state:
		GameStateManager.GameState.MAIN_MENU:
			scene_path = "res://scenes/main/main_hall.tscn"
			transition_type = MenuSceneHelper.WCSTransitionType.FADE
		GameStateManager.GameState.BRIEFING:
			scene_path = "res://scenes/missions/briefing/briefing.tscn"
			transition_type = MenuSceneHelper.WCSTransitionType.SLIDE_LEFT
		GameStateManager.GameState.OPTIONS:
			scene_path = "res://scenes/ui/options.tscn"
			transition_type = MenuSceneHelper.WCSTransitionType.DISSOLVE
		GameStateManager.GameState.CAMPAIGN_MENU:
			scene_path = "res://scenes/ui/campaign.tscn"
			transition_type = MenuSceneHelper.WCSTransitionType.FADE
		_:
			_handle_menu_error("Unknown target state: %s" % target_state)
			return
	
	# Use enhanced transition system if available
	if menu_scene_helper:
		var success: bool = menu_scene_helper.transition_to_scene(scene_path, transition_type)
		if not success:
			# Fallback to GameStateManager direct transition
			GameStateManager.change_state(target_state)
	else:
		# Fallback to GameStateManager direct transition
		if GameStateManager.has_method("change_state"):
			GameStateManager.change_state(target_state)
		else:
			_handle_menu_error("No transition system available")

func _navigate_menu_option(direction: int) -> void:
	"""Navigate menu options with keyboard."""
	var option_count: int = MenuOption.size()
	var new_option_index: int = (current_menu_option + direction) % option_count
	if new_option_index < 0:
		new_option_index = option_count - 1
	
	current_menu_option = new_option_index as MenuOption
	_update_menu_focus()

func _activate_current_menu_option() -> void:
	"""Activate the currently focused menu option."""
	_on_menu_option_selected(current_menu_option)

func _update_menu_focus() -> void:
	"""Update visual focus for keyboard navigation."""
	if current_menu_option in menu_button_map:
		var button: Button = menu_button_map[current_menu_option]
		button.grab_focus()

func _handle_exit_game() -> void:
	"""Handle game exit with proper cleanup."""
	print("MainMenuController: Exit game requested")
	
	# Request shutdown through GameStateManager
	if GameStateManager and GameStateManager.has_method("shutdown"):
		GameStateManager.shutdown()
	else:
		# Fallback direct exit
		get_tree().quit()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_menu_button_hover_start(option: MenuOption) -> void:
	"""Handle menu button hover start for visual feedback."""
	current_menu_option = option
	
	# Play hover sound effect
	if main_hall_audio and main_hall_audio.has_method("play_hover_sound"):
		main_hall_audio.play_hover_sound()

func _on_menu_button_hover_end(option: MenuOption) -> void:
	"""Handle menu button hover end."""
	# Visual feedback handled by button themes
	pass

func _on_game_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
	"""Handle game state changes from GameStateManager."""
	print("MainMenuController: Game state changed from %s to %s" % [
		GameStateManager.GameState.keys()[old_state],
		GameStateManager.GameState.keys()[new_state]
	])

func _on_state_transition_started(target_state: GameStateManager.GameState) -> void:
	"""Handle state transition start."""
	is_transitioning = true
	transition_start_time = Time.get_time_dict_from_system()["unix"] * 1000.0

func _on_state_transition_completed(final_state: GameStateManager.GameState) -> void:
	"""Handle state transition completion."""
	is_transitioning = false
	
	# Calculate transition time
	var transition_time: float = (Time.get_time_dict_from_system()["unix"] * 1000.0) - transition_start_time
	print("MainMenuController: State transition completed in %.1fms" % transition_time)

# ============================================================================
# TRANSITION SYSTEM EVENT HANDLERS
# ============================================================================

func _on_transition_started(from_scene: String, to_scene: String, transition_type: MenuSceneHelper.WCSTransitionType) -> void:
	"""Handle transition start from MenuSceneHelper."""
	print("MainMenuController: Enhanced transition started - %s to %s using %s" % [
		from_scene, to_scene, MenuSceneHelper.WCSTransitionType.keys()[transition_type]
	])

func _on_transition_completed(scene_path: String, transition_time_ms: float) -> void:
	"""Handle transition completion from MenuSceneHelper."""
	print("MainMenuController: Enhanced transition completed to %s in %.1fms" % [scene_path, transition_time_ms])
	
	# Validate performance targets
	if transition_time_ms > max_transition_time_ms:
		push_warning("MainMenuController: Transition time exceeded target: %.1fms > %.1fms" % [
			transition_time_ms, max_transition_time_ms
		])

func _on_transition_failed(error_message: String) -> void:
	"""Handle transition failure from MenuSceneHelper."""
	_handle_menu_error("Transition failed: %s" % error_message)

# ============================================================================
# ERROR HANDLING
# ============================================================================

func _handle_menu_error(error_message: String) -> void:
	"""Handle menu system errors with proper reporting."""
	push_error("MainMenuController: %s" % error_message)
	menu_error.emit(error_message)
	
	# Attempt graceful degradation
	menu_initialized = false

# ============================================================================
# PUBLIC API
# ============================================================================

func get_current_menu_option() -> MenuOption:
	"""Get the currently selected menu option."""
	return current_menu_option

func is_menu_ready() -> bool:
	"""Check if the menu system is ready for interaction."""
	return menu_initialized and not is_transitioning

func force_menu_option(option: MenuOption) -> void:
	"""Force selection of a specific menu option (for testing/debugging)."""
	if is_menu_ready():
		_on_menu_option_selected(option)

func get_transition_performance_stats() -> Dictionary:
	"""Get transition system performance statistics."""
	if menu_scene_helper:
		return menu_scene_helper.get_performance_stats()
	else:
		return {
			"error": "Transition system not initialized",
			"average_transition_time_ms": 0.0,
			"total_transitions": 0
		}

func set_transition_performance_targets(max_time_ms: float, memory_limit_mb: float) -> void:
	"""Update transition performance targets."""
	max_transition_time_ms = max_time_ms
	if menu_scene_helper:
		menu_scene_helper.set_performance_targets(max_time_ms, memory_limit_mb)