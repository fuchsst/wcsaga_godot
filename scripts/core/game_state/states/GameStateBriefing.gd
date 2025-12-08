class_name GameStateBriefing
extends LimboState

# Briefing State - Pre-mission briefing display
# Shows mission objectives and briefing stages before launching
# Extends LimboAI's LimboState for HSM integration

# === SIGNALS ===
signal briefing_complete()
signal stage_changed(stage_index: int)

# === SCENE PATHS ===
const BRIEFING_SCENE := "res://scenes/ui/briefing/briefing.tscn"

# === STATE ===
var _briefing_scene: Control = null
var _current_stage: int = 0
var _num_stages: int = 0
var _mission: Resource = null
var _is_ready_to_launch: bool = false


func _enter() -> void:
	print("Entering Briefing State")

	# Get MissionManager and current mission
	var mm = _get_mission_manager()
	if not mm or not mm.current_mission:
		push_error("GameStateBriefing: No mission loaded!")
		_skip_to_gameplay()
		return

	_mission = mm.current_mission
	_current_stage = 0

	# Count briefing stages
	_num_stages = _count_briefing_stages()
	if _num_stages == 0:
		print("GameStateBriefing: No briefing stages, skipping to gameplay")
		_skip_to_gameplay()
		return

	_setup_briefing_scene()
	_show_stage(_current_stage)

	print("GameStateBriefing: Showing mission - " + _mission.mission_title)


func _exit() -> void:
	print("Exiting Briefing State")
	_cleanup_briefing()


func _update(_delta: float) -> void:
	# Handle input for stage navigation
	if Input.is_action_just_pressed("ui_accept"):
		_on_continue_pressed()
	elif Input.is_action_just_pressed("ui_cancel"):
		_on_back_pressed()
	elif Input.is_action_just_pressed("ui_right"):
		_next_stage()
	elif Input.is_action_just_pressed("ui_left"):
		_prev_stage()


# === SETUP METHODS ===

func _setup_briefing_scene() -> void:
	"""Load and configure briefing UI scene"""
	var root = get_tree().root

	if ResourceLoader.exists(BRIEFING_SCENE):
		var scene = load(BRIEFING_SCENE)
		if scene:
			_briefing_scene = scene.instantiate()
			root.add_child(_briefing_scene)
			_connect_briefing_signals()
			return

	# Create fallback briefing UI
	_create_fallback_briefing_ui(root)


func _create_fallback_briefing_ui(root: Node) -> void:
	"""Create minimal briefing UI if scene not found"""
	_briefing_scene = CanvasLayer.new()
	_briefing_scene.name = "BriefingUI"
	_briefing_scene.layer = 100
	root.add_child(_briefing_scene)

	# Background panel
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.05, 0.1, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing_scene.add_child(bg)

	# Container
	var container = VBoxContainer.new()
	container.name = "Container"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 20)
	_briefing_scene.add_child(container)

	# Title
	var title = Label.new()
	title.name = "MissionTitle"
	title.text = _mission.mission_title if _mission else "MISSION BRIEFING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	container.add_child(title)

	# Stage text
	var stage_panel = PanelContainer.new()
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(stage_panel)

	var stage_text = RichTextLabel.new()
	stage_text.name = "StageText"
	stage_text.bbcode_enabled = true
	stage_text.scroll_active = true
	stage_panel.add_child(stage_text)

	# Objectives section
	var objectives_label = Label.new()
	objectives_label.name = "ObjectivesHeader"
	objectives_label.text = "OBJECTIVES"
	objectives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objectives_label.add_theme_font_size_override("font_size", 20)
	container.add_child(objectives_label)

	var objectives_list = VBoxContainer.new()
	objectives_list.name = "ObjectivesList"
	container.add_child(objectives_list)

	# Stage navigation
	var nav_container = HBoxContainer.new()
	nav_container.name = "NavContainer"
	nav_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(nav_container)

	var prev_btn = Button.new()
	prev_btn.name = "PrevButton"
	prev_btn.text = "< Previous"
	prev_btn.pressed.connect(_prev_stage)
	nav_container.add_child(prev_btn)

	var stage_indicator = Label.new()
	stage_indicator.name = "StageIndicator"
	stage_indicator.text = "Stage 1 of 1"
	stage_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_indicator.custom_minimum_size.x = 150
	nav_container.add_child(stage_indicator)

	var next_btn = Button.new()
	next_btn.name = "NextButton"
	next_btn.text = "Next >"
	next_btn.pressed.connect(_next_stage)
	nav_container.add_child(next_btn)

	# Launch button
	var launch_container = HBoxContainer.new()
	launch_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(launch_container)

	var back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back to Menu"
	back_btn.pressed.connect(_on_back_pressed)
	launch_container.add_child(back_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 50
	launch_container.add_child(spacer)

	var launch_btn = Button.new()
	launch_btn.name = "LaunchButton"
	launch_btn.text = "LAUNCH MISSION"
	launch_btn.pressed.connect(_on_launch_pressed)
	launch_container.add_child(launch_btn)


func _connect_briefing_signals() -> void:
	"""Connect signals from briefing scene UI"""
	if not _briefing_scene:
		return

	# Try to find and connect buttons
	var launch_btn = _briefing_scene.find_child("LaunchButton", true, false)
	if launch_btn and launch_btn.has_signal("pressed"):
		if not launch_btn.pressed.is_connected(_on_launch_pressed):
			launch_btn.pressed.connect(_on_launch_pressed)

	var prev_btn = _briefing_scene.find_child("PrevButton", true, false)
	if prev_btn and prev_btn.has_signal("pressed"):
		if not prev_btn.pressed.is_connected(_prev_stage):
			prev_btn.pressed.connect(_prev_stage)

	var next_btn = _briefing_scene.find_child("NextButton", true, false)
	if next_btn and next_btn.has_signal("pressed"):
		if not next_btn.pressed.is_connected(_next_stage):
			next_btn.pressed.connect(_next_stage)


# === STAGE MANAGEMENT ===

func _count_briefing_stages() -> int:
	"""Count briefing stages from mission data"""
	if not _mission:
		return 0

	# Check for briefing stages in mission
	if "briefing" in _mission and _mission.briefing:
		if "stages" in _mission.briefing:
			return _mission.briefing.stages.size()

	# Fallback: treat objectives as a single stage
	if "goals" in _mission and _mission.goals.size() > 0:
		return 1

	return 1 # Always at least one stage for objectives


func _show_stage(stage_index: int) -> void:
	"""Display a briefing stage"""
	if not _briefing_scene:
		return

	_current_stage = clampi(stage_index, 0, max(0, _num_stages - 1))

	# Update stage text
	var text_node = _briefing_scene.find_child("StageText", true, false)
	if text_node:
		text_node.text = _get_stage_text(_current_stage)

	# Update stage indicator
	var indicator = _briefing_scene.find_child("StageIndicator", true, false)
	if indicator:
		indicator.text = "Stage %d of %d" % [_current_stage + 1, _num_stages]

	# Update objectives on last stage
	if _current_stage == _num_stages - 1:
		_show_objectives()

	# Update button states
	_update_nav_buttons()

	stage_changed.emit(_current_stage)


func _get_stage_text(stage_index: int) -> String:
	"""Get briefing text for a stage"""
	if not _mission:
		return ""

	# Try to get from briefing stages
	if "briefing" in _mission and _mission.briefing:
		if "stages" in _mission.briefing:
			var stages = _mission.briefing.stages
			if stage_index < stages.size():
				return stages[stage_index].text if "text" in stages[stage_index] else ""

	# Fallback: show mission description
	if "mission_desc" in _mission and _mission.mission_desc:
		return _mission.mission_desc

	return "No briefing available for this mission."


func _show_objectives() -> void:
	"""Display mission objectives"""
	var objectives_list = _briefing_scene.find_child("ObjectivesList", true, false)
	if not objectives_list:
		return

	# Clear existing
	for child in objectives_list.get_children():
		child.queue_free()

	if not _mission or not "goals" in _mission:
		return

	# Add each goal
	for goal in _mission.goals:
		var goal_label = Label.new()
		var goal_text = goal.goal_name if "goal_name" in goal else "Objective"
		var type_prefix = "[PRIMARY] " if goal.type == 0 else "[SECONDARY] "
		goal_label.text = type_prefix + goal_text
		objectives_list.add_child(goal_label)


func _update_nav_buttons() -> void:
	"""Update navigation button enabled states"""
	var prev_btn = _briefing_scene.find_child("PrevButton", true, false)
	if prev_btn:
		prev_btn.disabled = _current_stage <= 0

	var next_btn = _briefing_scene.find_child("NextButton", true, false)
	if next_btn:
		next_btn.disabled = _current_stage >= _num_stages - 1


func _next_stage() -> void:
	"""Move to next briefing stage"""
	if _current_stage < _num_stages - 1:
		_show_stage(_current_stage + 1)


func _prev_stage() -> void:
	"""Move to previous briefing stage"""
	if _current_stage > 0:
		_show_stage(_current_stage - 1)


# === EVENT HANDLERS ===

func _on_continue_pressed() -> void:
	"""Handle continue/accept input"""
	if _current_stage < _num_stages - 1:
		_next_stage()
	else:
		_on_launch_pressed()


func _on_back_pressed() -> void:
	"""Handle back/cancel input"""
	if _current_stage > 0:
		_prev_stage()
	else:
		_exit_to_menu()


func _on_launch_pressed() -> void:
	"""Launch the mission"""
	print("GameStateBriefing: Launching mission")
	briefing_complete.emit()
	_transition_to_gameplay()


# === TRANSITIONS ===

func _skip_to_gameplay() -> void:
	"""Skip briefing and go directly to gameplay"""
	_transition_to_gameplay()


func _transition_to_gameplay() -> void:
	"""Transition to gameplay state"""
	var gsm = get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"start_game")


func _exit_to_menu() -> void:
	"""Return to main menu"""
	# End mission in MissionManager
	var mm = _get_mission_manager()
	if mm:
		mm.end_mission(false)

	var gsm = get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_menu")


# === CLEANUP ===

func _cleanup_briefing() -> void:
	"""Clean up briefing UI"""
	if _briefing_scene and is_instance_valid(_briefing_scene):
		_briefing_scene.queue_free()
		_briefing_scene = null


# === HELPERS ===

func _get_mission_manager() -> Node:
	"""Get MissionManager autoload safely"""
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	return get_node_or_null("/root/MissionManager")
