class_name GameStateIntro
extends LimboState

# Intro State
# Handles splash screens and intro videos

func _enter() -> void:
	print("Entering Intro State")
	# Play intro video or show splash screen
	# For now, just transition to MainMenu after a delay
	get_tree().create_timer(1.0).timeout.connect(func(): dispatch("to_main_menu"))

func _exit() -> void:
	print("Exiting Intro State")
