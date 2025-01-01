extends Node2D

@onready var video_player = $VideoPlayer

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	# Allow skipping the video with any input
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_video_player_finished()


func _on_video_player_finished() -> void:
	# Transition to user management scene
	SceneManager.change_scene("user_management", 
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_general_options(Color.BLACK))
