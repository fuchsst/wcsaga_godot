class_name GameStateCampaignIntro
extends LimboState

## Campaign Intro State
##
## Plays campaign intro cutscene when starting a new campaign.
## Flow: CampaignSelect -> CampaignIntro -> MainHall

const CUTSCENE_PLAYER_SCENE := "res://scenes/ui/cutscene/cutscene_player.tscn"

var _cutscene_scene: Control = null
var _cutscene_path: String = ""


func _enter() -> void:
	print("Entering Campaign Intro State")

	# Get campaign intro from ProfileManager or MissionManager
	_cutscene_path = _get_campaign_intro_path()

	if _cutscene_path.is_empty():
		print("No campaign intro, skipping to MainHall")
		_skip_to_main_hall()
		return

	if not _setup_cutscene_player():
		_skip_to_main_hall()


func _exit() -> void:
	print("Exiting Campaign Intro State")
	_cleanup()


func _update(_delta: float) -> void:
	# Allow skipping with accept/cancel
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
		_skip_to_main_hall()


func _get_campaign_intro_path() -> String:
	# Try to get from ProfileManager
	var pm := get_node_or_null("/root/ProfileManager")
	if pm and "current_campaign" in pm and pm.current_campaign:
		if "intro_cutscene" in pm.current_campaign:
			return pm.current_campaign.intro_cutscene

	# Try campaign manifest
	var campaign_path := "res://campaigns/hermes/campaign.tres"
	if ResourceLoader.exists(campaign_path):
		var campaign := load(campaign_path)
		if campaign and "intro_cutscene" in campaign:
			return campaign.intro_cutscene

	# Try cutscenes manifest
	var cutscenes_path := "res://campaigns/hermes/cutscenes.tres"
	if ResourceLoader.exists(cutscenes_path):
		var cutscenes := load(cutscenes_path)
		if cutscenes and "cutscenes" in cutscenes:
			if "intro" in cutscenes.cutscenes:
				var intro := cutscenes.cutscenes["intro"]
				if intro and "video_stream" in intro:
					return intro.video_stream.resource_path

	return ""


func _setup_cutscene_player() -> bool:
	if ResourceLoader.exists(CUTSCENE_PLAYER_SCENE):
		var scene := load(CUTSCENE_PLAYER_SCENE)
		if scene:
			_cutscene_scene = scene.instantiate()
			get_tree().root.add_child(_cutscene_scene)

			# Configure cutscene
			if _cutscene_scene.has_method("play_cutscene"):
				_cutscene_scene.play_cutscene(_cutscene_path)

			# Connect completion signal
			if _cutscene_scene.has_signal("cutscene_finished"):
				_cutscene_scene.cutscene_finished.connect(_on_cutscene_finished)

			return true

	# Fallback: use VideoStreamPlayer directly
	return _create_fallback_player()


func _create_fallback_player() -> bool:
	_cutscene_scene = Control.new()
	_cutscene_scene.name = "CutsceneOverlay"
	_cutscene_scene.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cutscene_scene.add_child(bg)

	var video_player := VideoStreamPlayer.new()
	video_player.name = "VideoPlayer"
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.finished.connect(_on_cutscene_finished)
	_cutscene_scene.add_child(video_player)

	# Load and play video
	if ResourceLoader.exists(_cutscene_path):
		video_player.stream = load(_cutscene_path)
		video_player.play()
		get_tree().root.add_child(_cutscene_scene)
		return true

	return false


func _on_cutscene_finished() -> void:
	_skip_to_main_hall()


func _skip_to_main_hall() -> void:
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_main_hall")


func _cleanup() -> void:
	if _cutscene_scene and is_instance_valid(_cutscene_scene):
		_cutscene_scene.queue_free()
		_cutscene_scene = null
