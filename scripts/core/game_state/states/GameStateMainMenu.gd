class_name GameStateMainMenu
extends LimboState

# Main Menu State
# Handles main menu UI and user interaction

func _enter() -> void:
	print("Entering Main Menu State")
	# Load Main Menu UI
	# Connect UI signals to dispatch transitions

func _exit() -> void:
	print("Exiting Main Menu State")
	# Unload Main Menu UI
