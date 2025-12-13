class_name GameStateCmdBrief
extends LimboState

## Command Briefing State - Pre-briefing narrative
## Shows commander talking head with story text

signal cmd_brief_complete

const CMD_BRIEF_SCENE := "res://scenes/ui/briefing/cmd_briefing.tscn"

var _cmd_brief_scene: Control = null
var _current_stage: int = 0
var _num_stages: int = 0
var _mission: Resource = null


func _enter() -> void:
	print("Entering Command Briefing State")

	var mm := _get_mission_manager()
	if mm and mm.current_mission:
		_mission = mm.current_mission

	_num_stages = _count_cmd_brief_stages()
	if _num_stages == 0:
		print("No command briefing stages, skipping")
		_skip_to_briefing()
		return

	_current_stage = 0
	_setup_cmd_brief_scene()
	_show_stage(_current_stage)


func _exit() -> void:
	print("Exiting Command Briefing State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_next_stage()
	elif Input.is_action_just_pressed("ui_cancel"):
		_skip_to_briefing()


func _count_cmd_brief_stages() -> int:
	if not _mission:
		return 0

	# Check for command briefing stages
	if "cmd_briefing" in _mission and _mission.cmd_briefing:
		if "stages" in _mission.cmd_briefing:
			return _mission.cmd_briefing.stages.size()

	return 0


func _setup_cmd_brief_scene() -> bool:
	if ResourceLoader.exists(CMD_BRIEF_SCENE):
		var scene := load(CMD_BRIEF_SCENE)
		if scene:
			_cmd_brief_scene = scene.instantiate()
			get_tree().root.add_child(_cmd_brief_scene)
			_connect_signals()
			return true

	_create_fallback_ui()
	return true


func _create_fallback_ui() -> void:
	_cmd_brief_scene = Control.new()
	_cmd_brief_scene.name = "CmdBriefOverlay"
	_cmd_brief_scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cmd_brief_scene.add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.custom_minimum_size = Vector2(900, 400)
	_cmd_brief_scene.add_child(hbox)

	# Portrait area
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(200, 300)
	hbox.add_child(portrait_panel)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_panel.add_child(portrait)

	# Text area
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var title := Label.new()
	title.name = "SpeakerName"
	title.text = "COMMANDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_vbox.add_child(title)

	var text_scroll := ScrollContainer.new()
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_vbox.add_child(text_scroll)

	var text_label := RichTextLabel.new()
	text_label.name = "StageText"
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.custom_minimum_size.x = 500
	text_scroll.add_child(text_label)

	var stage_indicator := Label.new()
	stage_indicator.name = "StageIndicator"
	stage_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_vbox.add_child(stage_indicator)

	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_child(btn_container)

	var skip_btn := Button.new()
	skip_btn.name = "SkipButton"
	skip_btn.text = "Skip"
	skip_btn.pressed.connect(_skip_to_briefing)
	btn_container.add_child(skip_btn)

	var continue_btn := Button.new()
	continue_btn.name = "ContinueButton"
	continue_btn.text = "Continue"
	continue_btn.pressed.connect(_next_stage)
	btn_container.add_child(continue_btn)

	get_tree().root.add_child(_cmd_brief_scene)


func _connect_signals() -> void:
	if not _cmd_brief_scene:
		return

	var continue_btn := _cmd_brief_scene.find_child("ContinueButton", true, false)
	if continue_btn and continue_btn.has_signal("pressed"):
		if not continue_btn.pressed.is_connected(_next_stage):
			continue_btn.pressed.connect(_next_stage)

	var skip_btn := _cmd_brief_scene.find_child("SkipButton", true, false)
	if skip_btn and skip_btn.has_signal("pressed"):
		if not skip_btn.pressed.is_connected(_skip_to_briefing):
			skip_btn.pressed.connect(_skip_to_briefing)


func _show_stage(stage_index: int) -> void:
	if not _cmd_brief_scene or not _mission:
		return

	_current_stage = clampi(stage_index, 0, max(0, _num_stages - 1))

	var stage_data: Resource = null
	if "cmd_briefing" in _mission and _mission.cmd_briefing:
		if "stages" in _mission.cmd_briefing:
			var stages = _mission.cmd_briefing.stages
			if _current_stage < stages.size():
				stage_data = stages[_current_stage]

	# Update text
	var text_label := _cmd_brief_scene.find_child("StageText", true, false)
	if text_label and stage_data and "text" in stage_data:
		text_label.text = stage_data.text

	# Update speaker
	var speaker_label := _cmd_brief_scene.find_child("SpeakerName", true, false)
	if speaker_label and stage_data and "speaker" in stage_data:
		speaker_label.text = stage_data.speaker.to_upper()

	# Update indicator
	var indicator := _cmd_brief_scene.find_child("StageIndicator", true, false)
	if indicator:
		indicator.text = "Stage %d of %d" % [_current_stage + 1, _num_stages]


func _next_stage() -> void:
	if _current_stage < _num_stages - 1:
		_show_stage(_current_stage + 1)
	else:
		_complete_cmd_brief()


func _complete_cmd_brief() -> void:
	cmd_brief_complete.emit()
	_skip_to_briefing()


func _skip_to_briefing() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_briefing")


func _cleanup_scene() -> void:
	if _cmd_brief_scene and is_instance_valid(_cmd_brief_scene):
		_cmd_brief_scene.queue_free()
		_cmd_brief_scene = null


func _get_mission_manager() -> Node:
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	return get_node_or_null("/root/MissionManager")
