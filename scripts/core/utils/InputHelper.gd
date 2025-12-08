extends Node

# InputHelper.gd
# Helper for input mapping persistence

const KEYBINDINGS_PATH = "user://keybindings.json"

func _ready():
	load_keybindings()

func load_keybindings():
	if FileAccess.file_exists(KEYBINDINGS_PATH):
		# Load and apply keybindings
		pass

func save_keybindings():
	# Save current keybindings to JSON
	pass

func reset_to_defaults():
	# Reset InputMap to project defaults
	InputMap.load_from_project_settings()
	save_keybindings()
