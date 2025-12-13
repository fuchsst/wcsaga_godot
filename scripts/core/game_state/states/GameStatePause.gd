class_name GameStatePause
extends LimboState

## Pause State - Game pause overlay
## Shows pause menu with resume/options/quit

const PAUSE_SCENE := "res://scenes/ui/pause/pause_menu.tscn"

var _pause_scene: Control = null


func _enter() -> void:
	print("Entering Pause State")
	get_tree().paused = true
	_setup_pause_scene()


func _exit() -> void:
	print("Exiting Pause State")
	get_tree().paused = false
	_cleanup_pause()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_resume_game()


func _setup_pause_scene() -> bool:
	if ResourceLoader.exists(PAUSE_SCENE):
		var scene := load(PAUSE_SCENE)
		if scene:
			_pause_scene = scene.instantiate()
			_pause_scene.process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().root.add_child(_pause_scene)
			_connect_signals()
			return true

	# Fallback: create simple pause overlay
	_create_fallback_pause_ui()
	return true


func _create_fallback_pause_ui() -> void:
	_pause_scene = Control.new()
	_pause_scene.name = "PauseOverlay"
	_pause_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_scene.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_scene.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_scene.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.name = "ResumeButton"
	resume_btn.text = "Resume"
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)

	var options_btn := Button.new()
	options_btn.name = "OptionsButton"
	options_btn.text = "Options"
	options_btn.pressed.connect(_show_options)
	vbox.add_child(options_btn)

	var quit_btn := Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "Quit to Menu"
	quit_btn.pressed.connect(_quit_to_menu)
	vbox.add_child(quit_btn)

	get_tree().root.add_child(_pause_scene)


func _connect_signals() -> void:
	if not _pause_scene:
		return

	var resume_btn := _pause_scene.find_child("ResumeButton", true, false)
	if resume_btn and resume_btn.has_signal("pressed"):
		if not resume_btn.pressed.is_connected(_resume_game):
			resume_btn.pressed.connect(_resume_game)

	var options_btn := _pause_scene.find_child("OptionsButton", true, false)
	if options_btn and options_btn.has_signal("pressed"):
		if not options_btn.pressed.is_connected(_show_options):
			options_btn.pressed.connect(_show_options)

	var quit_btn := _pause_scene.find_child("QuitButton", true, false)
	if quit_btn and quit_btn.has_signal("pressed"):
		if not quit_btn.pressed.is_connected(_quit_to_menu):
			quit_btn.pressed.connect(_quit_to_menu)


func _resume_game() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"resume_game")


func _show_options() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_options")


func _quit_to_menu() -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("end_mission"):
		mm.end_mission(false)

	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_menu")


func _cleanup_pause() -> void:
	if _pause_scene and is_instance_valid(_pause_scene):
		_pause_scene.queue_free()
		_pause_scene = null
