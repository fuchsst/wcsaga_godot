class_name GameStateMainHall
extends LimboState

## Main Hall State (Bridge)
##
## The in-mission main hall / bridge interface.
## This is where the player can access ready room, tech room, barracks, etc.
## Loaded after selecting a campaign/mission from the timeline.

const MAIN_HALL_SCENE := "res://scenes/ui/main_hall/MainHall.tscn"

var _main_hall_scene: Control = null


func _enter() -> void:
	print("Entering Main Hall State (Bridge)")
	_setup_main_hall_scene()


func _exit() -> void:
	print("Exiting Main Hall State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_return_to_campaign_select()


func _setup_main_hall_scene() -> bool:
	if ResourceLoader.exists(MAIN_HALL_SCENE):
		var scene := load(MAIN_HALL_SCENE)
		if scene:
			_main_hall_scene = scene.instantiate()
			get_tree().root.add_child(_main_hall_scene)
			_connect_signals()
			return true

	push_warning("Main hall scene not found: " + MAIN_HALL_SCENE)
	_create_fallback_ui()
	return true


func _create_fallback_ui() -> void:
	_main_hall_scene = Control.new()
	_main_hall_scene.name = "MainHallFallback"
	_main_hall_scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_hall_scene.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_hall_scene.add_child(vbox)

	var title := Label.new()
	title.text = "MAIN HALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Menu buttons
	var buttons := [
		{"text": "Ready Room", "action": &"start_mission"},
		{"text": "Tech Room", "action": &"to_tech_room"},
		{"text": "Barracks", "action": &"to_barracks"},
		{"text": "Options", "action": &"to_options"},
		{"text": "Back", "action": &"to_campaign_select"},
	]

	for btn_data in buttons:
		var btn := Button.new()
		btn.text = btn_data.text
		btn.pressed.connect(_on_menu_button.bind(btn_data.action))
		vbox.add_child(btn)

	get_tree().root.add_child(_main_hall_scene)


func _connect_signals() -> void:
	if not _main_hall_scene:
		return

	# Connect door_activated signal from MainHall
	if _main_hall_scene.has_signal("door_activated"):
		_main_hall_scene.door_activated.connect(_on_door_activated)


func _on_door_activated(_door_name: String, action_event: StringName) -> void:
	if action_event != &"":
		var gsm := get_parent()
		if gsm and gsm.has_method("dispatch"):
			gsm.dispatch(action_event)


func _on_menu_button(action: StringName) -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(action)


func _return_to_campaign_select() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_campaign_select")


func _cleanup_scene() -> void:
	if _main_hall_scene and is_instance_valid(_main_hall_scene):
		_main_hall_scene.queue_free()
		_main_hall_scene = null
