class_name GameStateManager
extends Node

## Central game state controller managing menu/mission/briefing flow.
## Handles state transitions and maintains global game state for the WCS-Godot conversion.

signal state_changed(old_state: GameState, new_state: GameState)
signal state_transition_started(target_state: GameState)
signal state_transition_completed(final_state: GameState)
signal manager_initialized()
signal manager_error(error_message: String)

enum GameState {
	MAIN_MENU,
	BRIEFING,
	MISSION,
	DEBRIEF,
	OPTIONS,
	CAMPAIGN_MENU,
	LOADING,
	PAUSED
}

# Configuration
@export var initial_state: GameState = GameState.MAIN_MENU
@export var enable_debug_logging: bool = false
@export var transition_timeout: float = 10.0  # Max time for state transitions

# State management
var current_state: GameState
var previous_state: GameState
var state_stack: Array[GameState] = []
var is_transitioning: bool = false
var is_initialized: bool = false

# Scene management
var state_scenes: Dictionary = {}  # GameState -> String (scene path)
var current_scene: Node = null
var transition_timer: Timer

# Persistent data
var persistent_data: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_initialize_manager()

func _initialize_manager() -> void:
	"""Initialize the GameStateManager with proper setup."""
	
	if is_initialized:
		push_warning("GameStateManager already initialized")
		return
	
	# Set up transition timer
	transition_timer = Timer.new()
	transition_timer.wait_time = transition_timeout
	transition_timer.timeout.connect(_on_transition_timeout)
	transition_timer.one_shot = true
	add_child(transition_timer)
	
	# Initialize state scene mappings
	_initialize_state_scenes()
	
	# Set initial state
	current_state = initial_state
	previous_state = initial_state
	state_start_time = Time.get_time_dict_from_system()["unix"]
	
	is_initialized = true
	
	if enable_debug_logging:
		print("GameStateManager: Initialized with initial state: %s" % GameState.keys()[initial_state])
	
	manager_initialized.emit()

func _initialize_state_scenes() -> void:
	"""Initialize the mapping of game states to scene paths."""
	
	state_scenes = {
		GameState.MAIN_MENU: "res://scenes/ui/main_menu.tscn",
		GameState.BRIEFING: "res://scenes/ui/briefing.tscn", 
		GameState.MISSION: "res://scenes/gameplay/mission.tscn",
		GameState.DEBRIEF: "res://scenes/ui/debrief.tscn",
		GameState.OPTIONS: "res://scenes/ui/options.tscn",
		GameState.CAMPAIGN_MENU: "res://scenes/ui/campaign_menu.tscn",
		GameState.LOADING: "res://scenes/ui/loading.tscn",
		GameState.PAUSED: "res://scenes/ui/pause_menu.tscn"
	}

## Public API for state management

func request_state_change(new_state: GameState, data: Dictionary = {}) -> bool:
	"""Request a change to a new game state."""
	
	if not is_initialized:
		push_error("GameStateManager: Cannot change state - manager not initialized")
		manager_error.emit("Manager not initialized")
		return false
	
	if is_transitioning:
		push_warning("GameStateManager: State transition already in progress")
		return false
	
	if new_state == current_state:
		if enable_debug_logging:
			print("GameStateManager: Already in requested state: %s" % GameState.keys()[new_state])
		return true
	
	if not _validate_state_transition(current_state, new_state):
		push_error("GameStateManager: Invalid state transition from %s to %s" % 
			[GameState.keys()[current_state], GameState.keys()[new_state]])
		return false
	
	_start_state_transition(new_state, data)
	return true

func push_state(new_state: GameState, data: Dictionary = {}) -> bool:
	"""Push a new state onto the state stack (for pause/resume functionality)."""
	
	if not is_initialized:
		push_error("GameStateManager: Cannot push state - manager not initialized")
		return false
	
	if is_transitioning:
		push_warning("GameStateManager: Cannot push state during transition")
		return false
	
	# Add current state to stack
	state_stack.append(current_state)
	
	# Change to new state
	return request_state_change(new_state, data)

func pop_state(data: Dictionary = {}) -> bool:
	"""Pop the last state from the stack and return to it."""
	
	if not is_initialized:
		push_error("GameStateManager: Cannot pop state - manager not initialized")
		return false
	
	if state_stack.is_empty():
		push_warning("GameStateManager: Cannot pop state - stack is empty")
		return false
	
	var previous_state_value: GameState = state_stack.pop_back()
	return request_state_change(previous_state_value, data)

func get_current_state() -> GameState:
	"""Get the current game state."""
	
	return current_state

func get_previous_state() -> GameState:
	"""Get the previous game state."""
	
	return previous_state

func is_in_state(state: GameState) -> bool:
	"""Check if currently in a specific state."""
	
	return current_state == state

func is_state_transition_in_progress() -> bool:
	"""Check if a state transition is currently in progress."""
	
	return is_transitioning

func set_persistent_data(key: String, value: Variant) -> void:
	"""Set persistent data that survives state transitions."""
	
	persistent_data[key] = value

func get_persistent_data(key: String, default_value: Variant = null) -> Variant:
	"""Get persistent data."""
	
	return persistent_data.get(key, default_value)

func clear_persistent_data() -> void:
	"""Clear all persistent data."""
	
	persistent_data.clear()

## Private implementation

func _validate_state_transition(from_state: GameState, to_state: GameState) -> bool:
	"""Validate if a state transition is allowed."""
	
	# Basic validation - can be extended with more complex rules
	match from_state:
		GameState.LOADING:
			# Can only transition from loading to specific states
			return to_state in [GameState.MAIN_MENU, GameState.MISSION, GameState.BRIEFING]
		GameState.PAUSED:
			# Can return to any non-paused state
			return to_state != GameState.PAUSED
		_:
			# Most transitions are allowed
			return true

func _start_state_transition(new_state: GameState, data: Dictionary) -> void:
	"""Start a state transition."""
	
	is_transitioning = true
	previous_state = current_state
	
	if enable_debug_logging:
		print("GameStateManager: Starting transition from %s to %s" % 
			[GameState.keys()[current_state], GameState.keys()[new_state]])
	
	state_transition_started.emit(new_state)
	
	# Start transition timer
	transition_timer.start()
	
	# Load new scene
	_load_state_scene(new_state, data)

func _load_state_scene(state: GameState, data: Dictionary) -> void:
	"""Load the scene for a specific state."""
	
	var scene_path: String = state_scenes.get(state, "")
	
	if scene_path.is_empty():
		push_error("GameStateManager: No scene defined for state: %s" % GameState.keys()[state])
		_complete_state_transition_with_error("No scene defined for state")
		return
	
	# Check if scene file exists
	if not FileAccess.file_exists(scene_path):
		push_warning("GameStateManager: Scene file does not exist: %s" % scene_path)
		# Continue anyway - scene might be created later
	
	# Unload current scene
	if current_scene != null:
		_unload_current_scene()
	
	# Load new scene (asynchronously if possible)
	_load_scene_async(scene_path, state, data)

func _load_scene_async(scene_path: String, target_state: GameState, data: Dictionary) -> void:
	"""Load a scene asynchronously."""
	
	# For now, load synchronously - can be improved with ResourceLoader.load_threaded_request
	var scene_resource: PackedScene = load(scene_path)
	
	if scene_resource == null:
		push_error("GameStateManager: Failed to load scene: %s" % scene_path)
		_complete_state_transition_with_error("Failed to load scene")
		return
	
	var scene_instance: Node = scene_resource.instantiate()
	
	if scene_instance == null:
		push_error("GameStateManager: Failed to instantiate scene: %s" % scene_path)
		_complete_state_transition_with_error("Failed to instantiate scene")
		return
	
	# Add scene to tree
	get_tree().current_scene.add_child(scene_instance)
	current_scene = scene_instance
	
	# Initialize scene with data if it supports it
	if scene_instance.has_method("initialize_with_data"):
		scene_instance.initialize_with_data(data)
	
	# Complete transition
	_complete_state_transition(target_state)

func _unload_current_scene() -> void:
	"""Unload the current scene."""
	
	if current_scene != null and is_instance_valid(current_scene):
		# Call cleanup if available
		if current_scene.has_method("cleanup"):
			current_scene.cleanup()
		
		current_scene.queue_free()
		current_scene = null

func _complete_state_transition(new_state: GameState) -> void:
	"""Complete a successful state transition."""
	
	transition_timer.stop()
	current_state = new_state
	is_transitioning = false
	state_start_time = Time.get_time_dict_from_system()["unix"]
	
	if enable_debug_logging:
		print("GameStateManager: Completed transition to %s" % GameState.keys()[new_state])
	
	state_changed.emit(previous_state, current_state)
	state_transition_completed.emit(current_state)

func _complete_state_transition_with_error(error_message: String) -> void:
	"""Complete a failed state transition."""
	
	transition_timer.stop()
	is_transitioning = false
	
	push_error("GameStateManager: State transition failed: %s" % error_message)
	manager_error.emit("State transition failed: %s" % error_message)
	
	# Try to recover by staying in current state
	if enable_debug_logging:
		print("GameStateManager: Staying in current state due to transition failure")

func _on_transition_timeout() -> void:
	"""Handle transition timeout."""
	
	_complete_state_transition_with_error("Transition timeout")

## Get debug statistics for monitoring overlay
func get_debug_stats() -> Dictionary:
	return {
		"current_state": GameState.keys()[current_state],
		"previous_state": GameState.keys()[previous_state] if previous_state != null else "None",
		"state_stack_size": state_stack.size(),
		"state_duration": Time.get_time_dict_from_system()["unix"] - state_start_time,
		"transition_in_progress": is_transitioning
	}

# Track state start time for duration calculation
var state_start_time: float = 0.0

## Cleanup

func _exit_tree() -> void:
	"""Clean up when the manager is removed."""
	
	if enable_debug_logging:
		print("GameStateManager: Shutting down")
	
	# Unload current scene
	_unload_current_scene()
	
	# Clear persistent data
	persistent_data.clear()
	
	# Clear state stack
	state_stack.clear()