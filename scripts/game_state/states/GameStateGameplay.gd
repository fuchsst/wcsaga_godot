class_name GameStateGameplay
extends LimboState

# Gameplay State
# Handles the main game loop

func _enter() -> void:
	print("Entering Gameplay State")
	# Initialize mission if needed
	# Unpause game

func _exit() -> void:
	print("Exiting Gameplay State")
	# Pause game or cleanup mission
