# scripts/core_systems/game_sequence_manager.gd
# Singleton (Autoload) responsible for managing the game state machine.
# Corresponds to gamesequence.cpp functionality.
class_name GameSequenceManager
extends Node

# --- State Management ---
# Stack to keep track of game states. Stores GameState enum values.
var state_stack: Array[GlobalConstants.GameState] = []
var current_state: GlobalConstants.GameState = GlobalConstants.GameState.NONE

# --- Scene Paths (Map GameState enums to scene file paths) ---
# TODO: Populate this dictionary with actual scene paths as they are created.
var state_scene_paths: Dictionary = {
	GlobalConstants.GameState.MAIN_MENU: "res://scenes/ui/main_menu.tscn",
	GlobalConstants.GameState.GAME_PLAY: "res://scenes/gameplay/space_flight.tscn",
	GlobalConstants.GameState.BRIEFING: "res://scenes/missions/briefing/briefing_screen.tscn",
	GlobalConstants.GameState.DEBRIEF: "res://scenes/missions/debriefing/debriefing_screen.tscn",
	GlobalConstants.GameState.SHIP_SELECT: "res://scenes/ui/ship_select.tscn",
	GlobalConstants.GameState.WEAPON_SELECT: "res://scenes/ui/weapon_select.tscn",
	GlobalConstants.GameState.OPTIONS_MENU: "res://scenes/ui/options_menu.tscn",
	# Add paths for all other relevant game states...
	GlobalConstants.GameState.QUIT_GAME: "" # Special case, handled differently
}

# --- Signals ---
signal state_changed(previous_state: GlobalConstants.GameState, new_state: GlobalConstants.GameState)
signal state_pushed(new_state: GlobalConstants.GameState)
signal state_popped(popped_state: GlobalConstants.GameState, new_state: GlobalConstants.GameState)

func _ready():
	print("GameSequenceManager initialized.")
	# Optionally start in a specific initial state (e.g., Main Menu)
	# set_state(GlobalConstants.GameState.MAIN_MENU)

# --- Public Methods ---

func post_event(event: GlobalConstants.GameEvent):
	# In Godot, we often use direct function calls or signals instead of an event queue.
	# This function maps events to state changes.
	# TODO: Expand this mapping based on gamesequence.cpp::game_process_event
	print("GameSequenceManager: Processing event ", GlobalConstants.GameEvent.keys()[event])
	match event:
		GlobalConstants.GameEvent.MAIN_MENU:
			set_state(GlobalConstants.GameState.MAIN_MENU)
		GlobalConstants.GameEvent.START_GAME:
			# This might trigger loading logic first, then set state
			set_state(GlobalConstants.GameState.START_GAME) # Or directly to briefing/ship select?
		GlobalConstants.GameEvent.ENTER_GAME:
			set_state(GlobalConstants.GameState.GAME_PLAY)
		GlobalConstants.GameEvent.OPTIONS_MENU:
			push_state(GlobalConstants.GameState.OPTIONS_MENU)
		GlobalConstants.GameEvent.PREVIOUS_STATE:
			pop_state()
		GlobalConstants.GameEvent.QUIT_GAME:
			# Handle quit logic directly
			get_tree().quit()
		GlobalConstants.GameEvent.START_BRIEFING:
			set_state(GlobalConstants.GameState.BRIEFING)
		GlobalConstants.GameEvent.SHIP_SELECTION:
			set_state(GlobalConstants.GameState.SHIP_SELECT)
		GlobalConstants.GameEvent.WEAPON_SELECTION:
			set_state(GlobalConstants.GameState.WEAPON_SELECT)
		GlobalConstants.GameEvent.DEBRIEF:
			set_state(GlobalConstants.GameState.DEBRIEF)
		# Add other event mappings...
		_:
			printerr("GameSequenceManager: Unhandled game event: ", event)


func set_state(new_state: GlobalConstants.GameState, override: bool = false):
	if new_state == current_state and not override:
		print("GameSequenceManager: Already in state ", GlobalConstants.GameState.keys()[new_state])
		return

	var old_state = current_state
	print("GameSequenceManager: Setting state from %s to %s" % [GlobalConstants.GameState.keys()[old_state], GlobalConstants.GameState.keys()[new_state]])

	# --- Leave Old State ---
	_leave_state(old_state, new_state)

	# --- Update State Stack ---
	state_stack.clear() # set_state clears the stack
	state_stack.push_back(new_state)
	current_state = new_state

	# --- Enter New State ---
	_enter_state(old_state, new_state)

	# --- Change Scene ---
	_change_scene_for_state(new_state)

	emit_signal("state_changed", old_state, new_state)


func push_state(new_state: GlobalConstants.GameState):
	if new_state == current_state:
		print("GameSequenceManager: Already in state ", GlobalConstants.GameState.keys()[new_state])
		return

	var old_state = current_state
	print("GameSequenceManager: Pushing state %s onto %s" % [GlobalConstants.GameState.keys()[new_state], GlobalConstants.GameState.keys()[old_state]])

	# --- Leave Old State (Potentially pause it instead of full leave?) ---
	_leave_state(old_state, new_state) # Or a specific _pause_state?

	# --- Update State Stack ---
	state_stack.push_back(new_state)
	current_state = new_state

	# --- Enter New State ---
	_enter_state(old_state, new_state)

	# --- Change Scene ---
	# Pushing often implies overlaying scenes or pausing the previous one,
	# rather than a full scene change. This needs careful design based on
	# which states can be pushed (e.g., Pause, Options).
	# For now, assume it might change scene like set_state.
	_change_scene_for_state(new_state)

	emit_signal("state_pushed", new_state)
	emit_signal("state_changed", old_state, new_state)


func pop_state():
	if state_stack.size() <= 1:
		printerr("GameSequenceManager: Cannot pop the last state!")
		return

	var old_state = current_state
	state_stack.pop_back()
	var new_state = state_stack.back()
	current_state = new_state

	print("GameSequenceManager: Popping state %s, returning to %s" % [GlobalConstants.GameState.keys()[old_state], GlobalConstants.GameState.keys()[new_state]])

	# --- Leave Old State ---
	_leave_state(old_state, new_state)

	# --- Enter New State (Potentially unpause it?) ---
	_enter_state(old_state, new_state) # Or a specific _unpause_state?

	# --- Change Scene ---
	_change_scene_for_state(new_state)

	emit_signal("state_popped", old_state, new_state)
	emit_signal("state_changed", old_state, new_state)


func get_current_state() -> GlobalConstants.GameState:
	return current_state

func get_previous_state() -> GlobalConstants.GameState:
	if state_stack.size() >= 2:
		return state_stack[-2]
	return GlobalConstants.GameState.NONE # Or current_state? C++ returned previous_state member

func get_depth() -> int:
	return state_stack.size()


# --- Internal Helper Methods ---

func _change_scene_for_state(state: GlobalConstants.GameState):
	if state_scene_paths.has(state):
		var scene_path = state_scene_paths[state]
		if not scene_path.is_empty():
			var error = get_tree().change_scene_to_file(scene_path)
			if error != OK:
				printerr("GameSequenceManager: Failed to change scene to %s for state %s. Error code: %d" % [scene_path, GlobalConstants.GameState.keys()[state], error])
		#else: Handle states without scenes (like QUIT_GAME) if needed
	else:
		printerr("GameSequenceManager: No scene path defined for state %s" % GlobalConstants.GameState.keys()[state])


func _leave_state(old_state: GlobalConstants.GameState, new_state: GlobalConstants.GameState):
	# Corresponds to C++ game_leave_state
	# TODO: Implement cleanup logic specific to leaving 'old_state'.
	# This might involve:
	# - Stopping music/sounds specific to the state (call SoundManager/MusicManager)
	# - Saving state if necessary
	# - Hiding UI elements
	# - Emitting a signal like "leaving_state_[state_name]"
	print("GameSequenceManager: Leaving state ", GlobalConstants.GameState.keys()[old_state])
	match old_state:
		GlobalConstants.GameState.GAME_PLAY:
			# Example: Stop gameplay music, save checkpoint?
			if Engine.has_singleton("MusicManager"):
				MusicManager.stop_gameplay_music() # Assuming method exists
			if Engine.has_singleton("GameManager"):
				GameManager.unpause_game() # Ensure game isn't left paused
		GlobalConstants.GameState.MAIN_MENU:
			# Example: Stop menu music
			if Engine.has_singleton("MusicManager"):
				MusicManager.stop_menu_music() # Assuming method exists
		# Add cases for other states...


func _enter_state(old_state: GlobalConstants.GameState, new_state: GlobalConstants.GameState):
	# Corresponds to C++ game_enter_state
	# TODO: Implement setup logic specific to entering 'new_state'.
	# This might involve:
	# - Starting music/sounds for the new state
	# - Loading necessary resources
	# - Resetting state variables
	# - Showing UI elements
	# - Emitting a signal like "entering_state_[state_name]"
	print("GameSequenceManager: Entering state ", GlobalConstants.GameState.keys()[new_state])
	match new_state:
		GlobalConstants.GameState.GAME_PLAY:
			# Example: Start gameplay music, reset mission timer
			if Engine.has_singleton("MusicManager"):
				MusicManager.start_gameplay_music() # Assuming method exists
			if Engine.has_singleton("GameManager"):
				GameManager.reset_mission_time()
				GameManager.unpause_game() # Ensure game starts unpaused
		GlobalConstants.GameState.MAIN_MENU:
			# Example: Start menu music
			if Engine.has_singleton("MusicManager"):
				MusicManager.start_menu_music() # Assuming method exists
		# Add cases for other states...
