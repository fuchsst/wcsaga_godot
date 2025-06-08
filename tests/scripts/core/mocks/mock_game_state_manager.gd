extends Node

## Mock GameStateManager for testing menu systems
## Provides minimal functionality to support menu testing

# Mock GameState enum to match the real one
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

# Mock state management
var current_state: GameState = GameState.MAIN_MENU
var is_transitioning: bool = false

# Mock methods
func change_state(new_state: GameState) -> void:
	"""Mock state change method."""
	var old_state: GameState = current_state
	current_state = new_state
	
	state_transition_started.emit(new_state)
	state_changed.emit(old_state, new_state)
	state_transition_completed.emit(new_state)

func shutdown() -> void:
	"""Mock shutdown method."""
	change_state(GameState.SHUTDOWN)
	
func get_current_state() -> GameState:
	"""Mock get current state method."""
	return current_state

func has_method(method_name: String) -> bool:
	"""Override to return true for expected methods."""
	var expected_methods: Array[String] = ["change_state", "shutdown", "get_current_state"]
	return method_name in expected_methods or super.has_method(method_name)