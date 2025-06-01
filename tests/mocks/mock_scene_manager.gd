extends Node

## Mock SceneManager for testing menu transition systems
## Provides minimal functionality to support transition testing

# Mock scene loading tracking
var current_scene_path: String = ""
var last_transition_type: String = ""
var transition_count: int = 0

# Mock signals
signal scene_changed(new_scene_path: String)
signal transition_started(transition_type: String)
signal transition_completed(scene_path: String)

func change_scene_with_transition(scene_path: String, transition_name: String) -> void:
	"""Mock scene change with transition."""
	print("MockSceneManager: Changing to %s with transition %s" % [scene_path, transition_name])
	
	current_scene_path = scene_path
	last_transition_type = transition_name
	transition_count += 1
	
	# Emit mock signals
	transition_started.emit(transition_name)
	scene_changed.emit(scene_path)
	transition_completed.emit(scene_path)

func change_scene(scene_path: String, fade_out_options: Dictionary = {}, fade_in_options: Dictionary = {}, general_options: Dictionary = {}) -> void:
	"""Mock scene change with options."""
	print("MockSceneManager: Changing to %s with options" % scene_path)
	
	current_scene_path = scene_path
	last_transition_type = "fade"  # Default assumption
	transition_count += 1
	
	# Emit mock signals
	transition_started.emit("fade")
	scene_changed.emit(scene_path)
	transition_completed.emit(scene_path)

func create_options(duration: float, transition: String) -> Dictionary:
	"""Mock options creation."""
	return {
		"duration": duration,
		"transition": transition
	}

func create_general_options(color: Color) -> Dictionary:
	"""Mock general options creation."""
	return {
		"color": color
	}

func has_method(method_name: String) -> bool:
	"""Override to return true for expected methods."""
	var expected_methods: Array[String] = [
		"change_scene_with_transition",
		"change_scene", 
		"create_options",
		"create_general_options"
	]
	return method_name in expected_methods or super.has_method(method_name)

func get_transition_count() -> int:
	"""Get number of transitions performed."""
	return transition_count

func get_last_transition_type() -> String:
	"""Get the last transition type used."""
	return last_transition_type

func reset_mock() -> void:
	"""Reset mock state for testing."""
	current_scene_path = ""
	last_transition_type = ""
	transition_count = 0