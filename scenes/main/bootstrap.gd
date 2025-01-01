extends Node2D

func _ready() -> void:

	
	# Start the game by transitioning to the intro scene
	SceneManager.change_scene("intro",
		SceneManager.create_options(1.0, "fade"),  # fade out options
		SceneManager.create_options(1.0, "fade"),  # fade in options
		SceneManager.create_general_options(Color.BLACK))  # general options
