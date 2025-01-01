extends Node2D

func _ready() -> void:
	pass


func _on_single_player_pressed() -> void:
	print("Singleplayer mode selected")

func _on_multiplayer_pressed() -> void:
	print("Multiplayer mode selected")


func _on_create_pilot_button_pressed() -> void:
	print("Create pilot clicked")


func _on_clone_pilot_button_pressed() -> void:
	print("Clone pilot clicked")


func _on_remove_pilot_button_pressed() -> void:
	print("Remove pilot clicked")


func _on_up_button_pressed() -> void:
	print("Navigation up")


func _on_down_button_pressed() -> void:
	print("Navigation down")


func _on_select_button_pressed() -> void:
	SceneManager.change_scene("main_hall", 
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_general_options(Color.BLACK))
