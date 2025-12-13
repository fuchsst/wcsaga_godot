class_name GameStateTechRoom
extends LimboState

## Tech Room State - Ship/Weapon/Intel database viewer

const TECH_ROOM_SCENE := "res://scenes/ui/tech_room/TechRoom.tscn"

var _tech_room_scene: Control = null


func _enter() -> void:
	print("Entering Tech Room State")
	_setup_tech_room_scene()


func _exit() -> void:
	print("Exiting Tech Room State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_go_back()


func _setup_tech_room_scene() -> bool:
	if ResourceLoader.exists(TECH_ROOM_SCENE):
		var scene := load(TECH_ROOM_SCENE)
		if scene:
			_tech_room_scene = scene.instantiate()
			get_tree().root.add_child(_tech_room_scene)
			return true

	push_warning("Tech room scene not found at: " + TECH_ROOM_SCENE)
	_go_back()
	return false


func _go_back() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_menu")


func _cleanup_scene() -> void:
	if _tech_room_scene and is_instance_valid(_tech_room_scene):
		_tech_room_scene.queue_free()
		_tech_room_scene = null
