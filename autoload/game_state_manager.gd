extends Node

## Central game state controller managing menu/mission/briefing flow.
## Handles state transitions and maintains global game state.
##
## This manager replaces the original WCS main loop state machine with a 
## Godot-native implementation using signals and proper scene management.

signal state_changed(old_state: GameState, new_state: GameState)
signal state_transition_started(target_state: GameState)
signal state_transition_completed(final_state: GameState)
signal manager_initialized()
signal manager_shutdown()
signal critical_error(error_message: String)

enum GameState {
	MAIN_MENU,
	BRIEFING,
	MISSION,
	DEBRIEF,
	OPTIONS,
	CAMPAIGN_MENU,
	LOADING,
	FRED_EDITOR,
	SHUTDOWN
}

# Configuration
@export var initial_state: GameState = GameState.MAIN_MENU
@export var debug_mode: bool = false
@export var enable_state_logging: bool = true
@export var transition_fade_time: float = 0.5

# State management
var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU
var target_state: GameState = GameState.MAIN_MENU
var state_stack: Array[GameState] = []
var is_transitioning: bool = false
var transition_start_time: float = 0.0

# Scene management
var scene_map: Dictionary = {}
var current_scene: Node = null
var scene_transition_overlay: Control = null

# Persistent data
var session_data: Dictionary = {}
var player_data: Dictionary = {}
var mission_data: Dictionary = {}

# State management
var is_initialized: bool = false
var is_shutting_down: bool = false
var initialization_error: String = ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	if is_initialized:
		push_warning("GameStateManager: Already initialized")
		return
	
	print("GameStateManager: Starting initialization...")
	
	# Validate configuration
	if not _validate_configuration():
		return
	
	# Initialize subsystems
	_initialize_scene_map()
	_initialize_transition_overlay()
	_setup_signal_connections()
	
	# Set initial state
	current_state = initial_state
	previous_state = initial_state
	
	is_initialized = true
	print("GameStateManager: Initialization complete - Initial state: %s" % GameState.keys()[current_state])
	manager_initialized.emit()

func _validate_configuration() -> bool:
	if transition_fade_time < 0.0:
		initialization_error = "transition_fade_time cannot be negative"
		_handle_critical_error(initialization_error)
		return false
	
	return true

func _initialize_scene_map() -> void:
	# Map game states to their corresponding scene paths
	scene_map = {
		GameState.MAIN_MENU: "res://scenes/ui/main_menu.tscn",
		GameState.BRIEFING: "res://scenes/ui/briefing.tscn", 
		GameState.MISSION: "res://scenes/gameplay/mission.tscn",
		GameState.DEBRIEF: "res://scenes/ui/debrief.tscn",
		GameState.OPTIONS: "res://scenes/ui/options.tscn",
		GameState.CAMPAIGN_MENU: "res://scenes/ui/campaign_menu.tscn",
		GameState.LOADING: "res://scenes/ui/loading.tscn",
		GameState.FRED_EDITOR: "res://scenes/tools/fred_editor.tscn"
	}
	
	if enable_state_logging:
		print("GameStateManager: Scene map initialized with %d states" % scene_map.size())

func _initialize_transition_overlay() -> void:
	# Create transition overlay for smooth scene changes
	scene_transition_overlay = Control.new()
	scene_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_transition_overlay.visible = false
	
	var color_rect: ColorRect = ColorRect.new()
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color.BLACK
	color_rect.modulate.a = 0.0
	
	scene_transition_overlay.add_child(color_rect)
	get_tree().root.add_child(scene_transition_overlay)

func _setup_signal_connections() -> void:
	# Connect to scene tree signals
	if get_tree():
		get_tree().node_removed.connect(_on_node_removed)

# Public API Methods

func request_state_change(new_state: GameState) -> bool:
	if not is_initialized:
		push_error("GameStateManager: Cannot change state - manager not initialized")
		return false
	
	if is_transitioning:
		push_warning("GameStateManager: State transition already in progress")
		return false
	
	if current_state == new_state:
		if enable_state_logging:
			print("GameStateManager: Already in requested state: %s" % GameState.keys()[new_state])
		return true
	
	if not _is_valid_transition(current_state, new_state):
		push_error("GameStateManager: Invalid transition from %s to %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])
		return false
	
	if enable_state_logging:
		print("GameStateManager: Requesting state change: %s -> %s" % [GameState.keys()[current_state], GameState.keys()[new_state]])
	
	_start_state_transition(new_state)
	return true

func push_state(new_state: GameState) -> bool:
	if not request_state_change(new_state):
		return false
	
	state_stack.push_back(current_state)
	if enable_state_logging:
		print("GameStateManager: Pushed state %s to stack (depth: %d)" % [GameState.keys()[current_state], state_stack.size()])
	
	return true

func pop_state() -> bool:
	if state_stack.is_empty():
		push_warning("GameStateManager: Cannot pop state - stack is empty")
		return false
	
	var restored_state: GameState = state_stack.pop_back()
	if enable_state_logging:
		print("GameStateManager: Popping state back to %s (depth: %d)" % [GameState.keys()[restored_state], state_stack.size()])
	
	return request_state_change(restored_state)

func get_current_state() -> GameState:
	return current_state

func get_previous_state() -> GameState:
	return previous_state

func is_in_state(state: GameState) -> bool:
	return current_state == state

func is_in_any_state(states: Array[GameState]) -> bool:
	return current_state in states

func is_transitioning_to_state() -> bool:
	return is_transitioning

func get_state_stack_depth() -> int:
	return state_stack.size()

# Session data management

func set_session_data(key: String, value: Variant) -> void:
	session_data[key] = value

func get_session_data(key: String, default_value: Variant = null) -> Variant:
	return session_data.get(key, default_value)

func clear_session_data() -> void:
	session_data.clear()

func set_player_data(key: String, value: Variant) -> void:
	player_data[key] = value

func get_player_data(key: String, default_value: Variant = null) -> Variant:
	return player_data.get(key, default_value)

func set_mission_data(key: String, value: Variant) -> void:
	mission_data[key] = value

func get_mission_data(key: String, default_value: Variant = null) -> Variant:
	return mission_data.get(key, default_value)

func clear_mission_data() -> void:
	mission_data.clear()

# Private state transition methods

func _start_state_transition(new_state: GameState) -> void:
	is_transitioning = true
	target_state = new_state
	transition_start_time = Time.get_ticks_msec() / 1000.0
	
	state_transition_started.emit(target_state)
	
	# Start transition sequence
	_execute_state_transition()

func _execute_state_transition() -> void:
	# Fade out current scene
	await _fade_out_scene()
	
	# Execute state exit logic
	_on_state_exit(current_state)
	
	# Change to new state
	previous_state = current_state
	current_state = target_state
	
	# Load new scene if needed
	await _load_state_scene(current_state)
	
	# Execute state enter logic
	_on_state_enter(current_state)
	
	# Fade in new scene
	await _fade_in_scene()
	
	# Complete transition
	is_transitioning = false
	
	state_changed.emit(previous_state, current_state)
	state_transition_completed.emit(current_state)
	
	if enable_state_logging:
		var transition_time: float = (Time.get_ticks_msec() / 1000.0) - transition_start_time
		print("GameStateManager: State transition completed in %.2fs: %s -> %s" % [transition_time, GameState.keys()[previous_state], GameState.keys()[current_state]])

func _fade_out_scene() -> void:
	if not scene_transition_overlay:
		return
	
	scene_transition_overlay.visible = true
	var color_rect: ColorRect = scene_transition_overlay.get_child(0) as ColorRect
	
	var tween: Tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, transition_fade_time)
	await tween.finished

func _fade_in_scene() -> void:
	if not scene_transition_overlay:
		return
	
	var color_rect: ColorRect = scene_transition_overlay.get_child(0) as ColorRect
	
	var tween: Tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, transition_fade_time)
	await tween.finished
	
	scene_transition_overlay.visible = false

func _load_state_scene(state: GameState) -> void:
	# Remove current scene
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	
	# Load new scene if it exists
	if scene_map.has(state):
		var scene_path: String = scene_map[state]
		
		if ResourceLoader.exists(scene_path):
			var scene_resource: PackedScene = load(scene_path)
			if scene_resource:
				current_scene = scene_resource.instantiate()
				get_tree().root.add_child(current_scene)
				
				if enable_state_logging:
					print("GameStateManager: Loaded scene for state %s: %s" % [GameState.keys()[state], scene_path])
			else:
				push_error("GameStateManager: Failed to load scene resource: %s" % scene_path)
		else:
			if enable_state_logging:
				print("GameStateManager: Scene not found for state %s: %s" % [GameState.keys()[state], scene_path])

func _on_state_exit(state: GameState) -> void:
	# Handle state-specific exit logic
	match state:
		GameState.MISSION:
			_cleanup_mission_state()
		GameState.BRIEFING:
			_cleanup_briefing_state()
		GameState.FRED_EDITOR:
			_cleanup_editor_state()

func _on_state_enter(state: GameState) -> void:
	# Handle state-specific enter logic
	match state:
		GameState.MISSION:
			_initialize_mission_state()
		GameState.BRIEFING:
			_initialize_briefing_state()
		GameState.FRED_EDITOR:
			_initialize_editor_state()

func _cleanup_mission_state() -> void:
	# Clear mission-specific data
	clear_mission_data()
	
	# Notify other systems
	if ObjectManager:
		ObjectManager.clear_all_objects()

func _cleanup_briefing_state() -> void:
	# Clean up briefing data
	pass

func _cleanup_editor_state() -> void:
	# Clean up FRED editor state
	pass

func _initialize_mission_state() -> void:
	# Set up mission environment
	pass

func _initialize_briefing_state() -> void:
	# Set up briefing environment
	pass

func _initialize_editor_state() -> void:
	# Set up FRED editor environment
	pass

func _is_valid_transition(from_state: GameState, to_state: GameState) -> bool:
	# Define valid state transitions
	var valid_transitions: Dictionary = {
		GameState.MAIN_MENU: [GameState.BRIEFING, GameState.OPTIONS, GameState.CAMPAIGN_MENU, GameState.FRED_EDITOR, GameState.SHUTDOWN],
		GameState.BRIEFING: [GameState.MISSION, GameState.MAIN_MENU, GameState.OPTIONS],
		GameState.MISSION: [GameState.DEBRIEF, GameState.MAIN_MENU, GameState.OPTIONS],
		GameState.DEBRIEF: [GameState.MAIN_MENU, GameState.BRIEFING],
		GameState.OPTIONS: [GameState.MAIN_MENU, GameState.BRIEFING, GameState.MISSION],
		GameState.CAMPAIGN_MENU: [GameState.MAIN_MENU, GameState.BRIEFING],
		GameState.LOADING: [GameState.MAIN_MENU, GameState.BRIEFING, GameState.MISSION],
		GameState.FRED_EDITOR: [GameState.MAIN_MENU]
	}
	
	if not valid_transitions.has(from_state):
		return false
	
	return to_state in (valid_transitions[from_state] as Array)

# Debug and performance

func get_performance_stats() -> Dictionary:
	return {
		"current_state": GameState.keys()[current_state],
		"previous_state": GameState.keys()[previous_state],
		"is_transitioning": is_transitioning,
		"state_stack_depth": state_stack.size(),
		"session_data_size": session_data.size(),
		"player_data_size": player_data.size(),
		"mission_data_size": mission_data.size()
	}

# Signal handlers

func _on_node_removed(node: Node) -> void:
	# Handle unexpected scene removal
	if node == current_scene:
		current_scene = null

# Error handling

func _handle_critical_error(error_message: String) -> void:
	push_error("GameStateManager CRITICAL ERROR: " + error_message)
	critical_error.emit(error_message)
	
	# Attempt graceful recovery
	is_shutting_down = true
	print("GameStateManager: Entering error recovery mode")
	request_state_change(GameState.MAIN_MENU)

# Cleanup

func shutdown() -> void:
	if is_shutting_down:
		return
	
	print("GameStateManager: Starting shutdown...")
	is_shutting_down = true
	
	# Clean up transition overlay
	if scene_transition_overlay and is_instance_valid(scene_transition_overlay):
		scene_transition_overlay.queue_free()
		scene_transition_overlay = null
	
	# Clean up current scene
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	
	# Clear data
	session_data.clear()
	player_data.clear()
	mission_data.clear()
	state_stack.clear()
	
	# Disconnect signals
	if get_tree() and get_tree().node_removed.is_connected(_on_node_removed):
		get_tree().node_removed.disconnect(_on_node_removed)
	
	is_initialized = false
	print("GameStateManager: Shutdown complete")
	manager_shutdown.emit()

func _exit_tree() -> void:
	shutdown()

# Debug helpers

func debug_print_state_info() -> void:
	print("=== GameStateManager Debug Info ===")
	print("Current state: %s" % GameState.keys()[current_state])
	print("Previous state: %s" % GameState.keys()[previous_state])
	print("Is transitioning: %s" % is_transitioning)
	print("State stack depth: %d" % state_stack.size())
	
	if state_stack.size() > 0:
		print("State stack:")
		for i in range(state_stack.size()):
			print("  [%d]: %s" % [i, GameState.keys()[state_stack[i]]])
	
	print("Session data keys: %s" % session_data.keys())
	print("Player data keys: %s" % player_data.keys())
	print("Mission data keys: %s" % mission_data.keys())
	print("=====================================")
