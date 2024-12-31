extends Node2D

func _ready() -> void:
	# Show first scene with fade in
	var fade_in_options = SceneManager.create_options(1.0, "fade")
	var general_options = SceneManager.create_general_options(Color.BLACK)
	SceneManager.show_first_scene(fade_in_options, general_options)
	
	# Start the game by transitioning to the intro scene
	SceneManager.change_scene("intro",
		SceneManager.create_options(1.0, "fade"),  # fade out options
		SceneManager.create_options(1.0, "fade"),  # fade in options
		SceneManager.create_general_options(Color.BLACK))  # general options
