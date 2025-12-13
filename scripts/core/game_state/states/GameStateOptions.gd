class_name GameStateOptions
extends LimboState

## Options State - Settings configuration
## Wraps SettingsWindow for HSM integration

const OPTIONS_SCENE := "res://scenes/ui/settings/SettingsWindow.tscn"

var _options_scene: Control = null


func _enter() -> void:
	print("Entering Options State")
	_setup_options_scene()


func _exit() -> void:
	print("Exiting Options State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_go_back()


func _setup_options_scene() -> bool:
	if ResourceLoader.exists(OPTIONS_SCENE):
		var scene := load(OPTIONS_SCENE)
		if scene:
			_options_scene = scene.instantiate()
			get_tree().root.add_child(_options_scene)
			_connect_signals()
			return true

	push_warning("Options scene not found at: " + OPTIONS_SCENE)
	_go_back()
	return false


func _connect_signals() -> void:
	if not _options_scene:
		return

	# Connect close/back signals if available
	if _options_scene.has_signal("closed"):
		_options_scene.closed.connect(_go_back)

	var close_btn := _options_scene.find_child("CloseButton", true, false)
	if close_btn and close_btn.has_signal("pressed"):
		if not close_btn.pressed.is_connected(_go_back):
			close_btn.pressed.connect(_go_back)

	var back_btn := _options_scene.find_child("BackButton", true, false)
	if back_btn and back_btn.has_signal("pressed"):
		if not back_btn.pressed.is_connected(_go_back):
			back_btn.pressed.connect(_go_back)


func _go_back() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"options_closed")


func _cleanup_scene() -> void:
	if _options_scene and is_instance_valid(_options_scene):
		_options_scene.queue_free()
		_options_scene = null
