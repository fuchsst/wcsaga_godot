class_name GameStateCampaignSelect
extends LimboState

## Campaign Selection State (Timeline)
##
## Shows campaign timeline for mission selection.
## This is the initial menu after intro, NOT the in-mission main hall.

const CAMPAIGN_SELECT_SCENE := "res://scenes/ui/campaign_select/TimelineMain.tscn"

var _campaign_scene: Control = null


func _enter() -> void:
	print("Entering Campaign Selection State")
	_setup_campaign_scene()


func _exit() -> void:
	print("Exiting Campaign Selection State")
	_cleanup_scene()


func _update(_delta: float) -> void:
	# Handle global input (escape to quit, etc.)
	pass


func _setup_campaign_scene() -> bool:
	if ResourceLoader.exists(CAMPAIGN_SELECT_SCENE):
		var scene := load(CAMPAIGN_SELECT_SCENE)
		if scene:
			_campaign_scene = scene.instantiate()
			get_tree().root.add_child(_campaign_scene)
			_connect_signals()
			return true

	push_warning("Campaign selection scene not found: " + CAMPAIGN_SELECT_SCENE)
	return false


func _connect_signals() -> void:
	if not _campaign_scene:
		return

	# Connect to timeline signals for mission selection
	if _campaign_scene.has_signal("mission_selected"):
		_campaign_scene.mission_selected.connect(_on_mission_selected)

	# Connect campaign button
	var campaign_btn := _campaign_scene.find_child("CampaignButton", true, false)
	if campaign_btn and campaign_btn.has_signal("pressed"):
		if not campaign_btn.pressed.is_connected(_on_campaign_pressed):
			campaign_btn.pressed.connect(_on_campaign_pressed)


func _on_mission_selected(mission_path: String) -> void:
	print("Mission selected: %s" % mission_path)

	# Load mission via MissionManager
	var mm := get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("load_mission"):
		mm.load_mission(mission_path)

	# Transition to main hall (bridge)
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_hall")


func _on_campaign_pressed() -> void:
	# Just trigger the same flow as mission selection for now
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_hall")


func _cleanup_scene() -> void:
	if _campaign_scene and is_instance_valid(_campaign_scene):
		_campaign_scene.queue_free()
		_campaign_scene = null
