class_name GameStateDebrief
extends LimboState

# Debrief State - Post-mission results display
# Shows mission success/failure, goal status, and statistics
# Extends LimboAI's LimboState for HSM integration

# === SIGNALS ===
signal debrief_complete()

# === SCENE PATHS ===
const DEBRIEF_SCENE := "res://scenes/ui/debrief/debrief.tscn"

# === STATE ===
var _debrief_scene: Control = null
var _mission: Resource = null
var _mission_success: bool = false


func _enter() -> void:
	print("Entering Debrief State")

	# Get MissionManager and results
	var mm = _get_mission_manager()
	if mm:
		_mission = mm.current_mission
		_mission_success = mm.last_mission_success if "last_mission_success" in mm else false

	_setup_debrief_scene()
	_display_results()

	print("GameStateDebrief: Mission " + ("SUCCESS" if _mission_success else "FAILED"))


func _exit() -> void:
	print("Exiting Debrief State")
	_cleanup_debrief()


func _update(_delta: float) -> void:
	# Handle input
	if Input.is_action_just_pressed("ui_accept"):
		_on_continue_pressed()
	elif Input.is_action_just_pressed("ui_cancel"):
		_on_continue_pressed()


# === SETUP METHODS ===

func _setup_debrief_scene() -> void:
	"""Load and configure debrief UI scene"""
	var root = get_tree().root

	if ResourceLoader.exists(DEBRIEF_SCENE):
		var scene = load(DEBRIEF_SCENE)
		if scene:
			_debrief_scene = scene.instantiate()
			root.add_child(_debrief_scene)
			_connect_debrief_signals()
			return

	# Create fallback debrief UI
	_create_fallback_debrief_ui(root)


func _create_fallback_debrief_ui(root: Node) -> void:
	"""Create minimal debrief UI if scene not found"""
	_debrief_scene = CanvasLayer.new()
	_debrief_scene.name = "DebriefUI"
	_debrief_scene.layer = 100
	root.add_child(_debrief_scene)

	# Background panel
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.05, 0.1, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debrief_scene.add_child(bg)

	# Container
	var container = VBoxContainer.new()
	container.name = "Container"
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.custom_minimum_size = Vector2(600, 400)
	container.add_theme_constant_override("separation", 20)
	_debrief_scene.add_child(container)

	# Result header
	var result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 48)
	container.add_child(result_label)

	# Mission title
	var title = Label.new()
	title.name = "MissionTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)

	# Goals section
	var goals_header = Label.new()
	goals_header.name = "GoalsHeader"
	goals_header.text = "OBJECTIVES"
	goals_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goals_header.add_theme_font_size_override("font_size", 18)
	container.add_child(goals_header)

	var goals_list = VBoxContainer.new()
	goals_list.name = "GoalsList"
	goals_list.add_theme_constant_override("separation", 5)
	container.add_child(goals_list)

	# Stats section
	var stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(stats_label)

	# Continue button
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(btn_container)

	var continue_btn = Button.new()
	continue_btn.name = "ContinueButton"
	continue_btn.text = "CONTINUE"
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.pressed.connect(_on_continue_pressed)
	btn_container.add_child(continue_btn)


func _connect_debrief_signals() -> void:
	"""Connect signals from debrief scene UI"""
	if not _debrief_scene:
		return

	var continue_btn = _debrief_scene.find_child("ContinueButton", true, false)
	if continue_btn and continue_btn.has_signal("pressed"):
		if not continue_btn.pressed.is_connected(_on_continue_pressed):
			continue_btn.pressed.connect(_on_continue_pressed)


# === DISPLAY METHODS ===

func _display_results() -> void:
	"""Display mission results"""
	if not _debrief_scene:
		return

	# Result label
	var result_label = _debrief_scene.find_child("ResultLabel", true, false)
	if result_label:
		if _mission_success:
			result_label.text = "MISSION COMPLETE"
			result_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			result_label.text = "MISSION FAILED"
			result_label.add_theme_color_override("font_color", Color.RED)

	# Mission title
	var title = _debrief_scene.find_child("MissionTitle", true, false)
	if title and _mission:
		title.text = _mission.mission_title if "mission_title" in _mission else "Unknown Mission"

	# Display goals
	_display_goals()

	# Display stats
	_display_stats()


func _display_goals() -> void:
	"""Display goal completion status"""
	var goals_list = _debrief_scene.find_child("GoalsList", true, false)
	if not goals_list:
		return

	# Clear existing
	for child in goals_list.get_children():
		child.queue_free()

	# Get goal status from MissionManager
	var mm = _get_mission_manager()
	var goal_status = mm.goal_status if mm and "goal_status" in mm else {}

	if not _mission or not "goals" in _mission:
		return

	for goal in _mission.goals:
		var goal_name = goal.goal_name if "goal_name" in goal else "Objective"
		var status = goal_status.get(goal_name, 0)

		var goal_container = HBoxContainer.new()
		goals_list.add_child(goal_container)

		var status_icon = Label.new()
		match status:
			1: # Complete
				status_icon.text = "✓"
				status_icon.add_theme_color_override("font_color", Color.GREEN)
			2: # Failed
				status_icon.text = "✗"
				status_icon.add_theme_color_override("font_color", Color.RED)
			_: # Incomplete
				status_icon.text = "○"
				status_icon.add_theme_color_override("font_color", Color.YELLOW)
		goal_container.add_child(status_icon)

		var spacer = Control.new()
		spacer.custom_minimum_size.x = 10
		goal_container.add_child(spacer)

		var goal_label = Label.new()
		goal_label.text = goal_name
		goal_container.add_child(goal_label)


func _display_stats() -> void:
	"""Display mission statistics"""
	var stats_label = _debrief_scene.find_child("StatsLabel", true, false)
	if not stats_label:
		return

	var mm = _get_mission_manager()
	var mission_time = mm.mission_time if mm else 0.0

	var minutes = int(mission_time) / 60
	var seconds = int(mission_time) % 60

	stats_label.text = "Mission Time: %02d:%02d" % [minutes, seconds]


# === EVENT HANDLERS ===

func _on_continue_pressed() -> void:
	"""Handle continue button"""
	print("GameStateDebrief: Continuing to menu")
	debrief_complete.emit()
	_transition_to_menu()


# === TRANSITIONS ===

func _transition_to_menu() -> void:
	"""Transition back to main menu"""
	# Clean up mission state
	var mm = _get_mission_manager()
	if mm and mm.has_method("cleanup_mission"):
		mm.cleanup_mission()

	var gsm = get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_menu")


# === CLEANUP ===

func _cleanup_debrief() -> void:
	"""Clean up debrief UI"""
	if _debrief_scene and is_instance_valid(_debrief_scene):
		_debrief_scene.queue_free()
		_debrief_scene = null


# === HELPERS ===

func _get_mission_manager() -> Node:
	"""Get MissionManager autoload safely"""
	if Engine.has_singleton("MissionManager"):
		return Engine.get_singleton("MissionManager")
	return get_node_or_null("/root/MissionManager")
