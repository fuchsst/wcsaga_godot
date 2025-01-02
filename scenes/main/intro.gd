extends Control

@onready var video_player = $VideoPlayer

func _ready() -> void:
	video_player.play()

func _input(event: InputEvent) -> void:
	# Allow skipping the video with any input
	if event.is_action_pressed("ui_cancel") or \
	   event.is_action_pressed("ui_accept") or \
	   event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		_on_video_player_finished()


func _on_video_player_finished() -> void:
	# Transition to user management scene
	SceneManager.change_scene("user_management", 
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_general_options(Color.BLACK))
