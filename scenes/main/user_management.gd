extends Node2D

func _ready() -> void:
	# Connect top right buttons
	$TopRightButtons/SinglePlayer.pressed.connect(_on_single_player_pressed)
	$TopRightButtons/Multiplayer.pressed.connect(_on_multiplayer_pressed)
	
	# Connect left buttons
	$LeftButtons/Button1.pressed.connect(_on_left_button1_pressed)
	$LeftButtons/Button2.pressed.connect(_on_left_button2_pressed)
	$LeftButtons/Button3.pressed.connect(_on_left_button3_pressed)
	
	# Connect right buttons
	$RightButtons/Button1.pressed.connect(_on_right_button1_pressed)
	$RightButtons/Button2.pressed.connect(_on_right_button2_pressed)
	$RightButtons/Button3.pressed.connect(_on_right_button3_pressed)

# Top right button handlers
func _on_single_player_pressed() -> void:
	print("Single Player mode selected")

func _on_multiplayer_pressed() -> void:
	print("Multiplayer mode selected")

# Left button handlers - User selection/creation
func _on_left_button1_pressed() -> void:
	print("User slot 1 selected")

func _on_left_button2_pressed() -> void:
	print("User slot 2 selected")

func _on_left_button3_pressed() -> void:
	print("User slot 3 selected")
	# For now, any user selection leads to main hall
	SceneManager.change_scene("main_hall", 
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_general_options(Color.BLACK))

# Right button handlers - Navigation controls
func _on_right_button1_pressed() -> void:
	print("Navigation up")

func _on_right_button2_pressed() -> void:
	print("Navigation down")

func _on_right_button3_pressed() -> void:
	print("Navigation select")
