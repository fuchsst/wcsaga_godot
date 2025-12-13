class_name GameStateFictionViewer
extends LimboState

## Fiction Viewer State - Story text display between missions

signal fiction_complete

const FICTION_SCENE := "res://scenes/ui/fiction/fiction_viewer.tscn"

var _fiction_scene: Control = null
var _fiction_text: String = ""
var _fiction_title: String = ""


func _enter() -> void:
	print("Entering Fiction Viewer State")

	var mm := _get_mission_manager()
	if mm and mm.current_mission:
		_load_fiction(mm.current_mission)

	if _fiction_text.is_empty():
		print("No fiction to display, skipping")
		_complete()
		return

	_setup_fiction_scene()


func _exit() -> void:
	print("Exiting Fiction Viewer State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_complete()
	elif Input.is_action_just_pressed("ui_cancel"):
		_complete()


func _load_fiction(mission: Resource) -> void:
	_fiction_text = ""
	_fiction_title = ""

	if not mission:
		return

	# Check for fiction data in mission
	if "fiction" in mission and mission.fiction:
		if "text" in mission.fiction:
			_fiction_text = mission.fiction.text
		if "title" in mission.fiction:
			_fiction_title = mission.fiction.title


func _setup_fiction_scene() -> bool:
	if ResourceLoader.exists(FICTION_SCENE):
		var scene := load(FICTION_SCENE)
		if scene:
			_fiction_scene = scene.instantiate()
			get_tree().root.add_child(_fiction_scene)
			_connect_signals()
			_populate_text()
			return true

	_create_fallback_ui()
	return true


func _create_fallback_ui() -> void:
	_fiction_scene = Control.new()
	_fiction_scene.name = "FictionOverlay"
	_fiction_scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fiction_scene.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(700, 500)
	_fiction_scene.add_child(vbox)

	var title := Label.new()
	title.name = "FictionTitle"
	title.text = _fiction_title if not _fiction_title.is_empty() else "FICTION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var text_label := RichTextLabel.new()
	text_label.name = "FictionText"
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.custom_minimum_size.x = 680
	text_label.text = _fiction_text
	scroll.add_child(text_label)

	var continue_btn := Button.new()
	continue_btn.name = "ContinueButton"
	continue_btn.text = "Continue"
	continue_btn.pressed.connect(_complete)
	vbox.add_child(continue_btn)

	get_tree().root.add_child(_fiction_scene)


func _connect_signals() -> void:
	if not _fiction_scene:
		return

	var continue_btn := _fiction_scene.find_child("ContinueButton", true, false)
	if continue_btn and continue_btn.has_signal("pressed"):
		if not continue_btn.pressed.is_connected(_complete):
			continue_btn.pressed.connect(_complete)


func _populate_text() -> void:
	var title_label := _fiction_scene.find_child("FictionTitle", true, false)
	if title_label:
		title_label.text = _fiction_title if not _fiction_title.is_empty() else "FICTION"

	var text_label := _fiction_scene.find_child("FictionText", true, false)
	if text_label:
		text_label.text = _fiction_text


func _complete() -> void:
	fiction_complete.emit()

	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"fiction_done")


func _cleanup_scene() -> void:
	if _fiction_scene and is_instance_valid(_fiction_scene):
		_fiction_scene.queue_free()
		_fiction_scene = null


func _get_mission_manager() -> Node:
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	return get_node_or_null("/root/MissionManager")
