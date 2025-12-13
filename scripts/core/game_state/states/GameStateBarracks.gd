class_name GameStateBarracks
extends LimboState

## Barracks State - Pilot profile management

const BARRACKS_SCENE := "res://scenes/ui/profile/ProfileEditor.tscn"

var _barracks_scene: Control = null


func _enter() -> void:
	print("Entering Barracks State")
	_setup_barracks_scene()


func _exit() -> void:
	print("Exiting Barracks State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_go_back()


func _setup_barracks_scene() -> bool:
	if ResourceLoader.exists(BARRACKS_SCENE):
		var scene := load(BARRACKS_SCENE)
		if scene:
			_barracks_scene = scene.instantiate()
			get_tree().root.add_child(_barracks_scene)
			_connect_signals()
			return true

	push_warning("Barracks scene not found at: " + BARRACKS_SCENE)
	_go_back()
	return false


func _connect_signals() -> void:
	if not _barracks_scene:
		return

	# Connect back button if exists
	var back_btn := _barracks_scene.find_child("BackButton", true, false)
	if back_btn and back_btn.has_signal("pressed"):
		if not back_btn.pressed.is_connected(_go_back):
			back_btn.pressed.connect(_go_back)


func _go_back() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_menu")


func _cleanup_scene() -> void:
	if _barracks_scene and is_instance_valid(_barracks_scene):
		_barracks_scene.queue_free()
		_barracks_scene = null
