extends Node2D

@onready var video_player = $VideoPlayer

func _ready() -> void:
	# Set up video player
	video_player.finished.connect(_on_video_finished)
	video_player.play()

func _input(event: InputEvent) -> void:
	# Allow skipping the video with any input
	if event.is_pressed():
		_on_video_finished()
		get_viewport().set_input_as_handled()

func _on_video_finished() -> void:
	# Transition to user management scene
	SceneManager.change_scene("user_management", 
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_general_options(Color.BLACK))
