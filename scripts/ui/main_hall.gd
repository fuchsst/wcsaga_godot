class_name MainHall
extends Control

## Main Hall Scene Controller
##
## Generic main hall implementation that loads campaign-specific
## configuration from MainHallResource.

signal door_activated(door_name: String, action_event: StringName)

## Path to the campaign's mainhall.tres resource
@export var mainhall_resource_path: String = ""

## Reference to loaded MainHallResource
var _mainhall_data: Resource = null

## Background texture
var _background: TextureRect = null

## Hotspot containers
var _hotspot_container: Control = null
var _hotspots: Array[Control] = []

## Audio
var _music_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null

## Tooltip label
var _tooltip_label: Label = null


func _ready() -> void:
	_setup_ui_structure()
	_load_mainhall_data()
	_create_hotspots()
	_start_music()


func _setup_ui_structure() -> void:
	# Background
	_background = TextureRect.new()
	_background.name = "Background"
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_background)

	# Hotspot container
	_hotspot_container = Control.new()
	_hotspot_container.name = "Hotspots"
	_hotspot_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hotspot_container)

	# Tooltip
	_tooltip_label = Label.new()
	_tooltip_label.name = "Tooltip"
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tooltip_label.position.y = -50
	_tooltip_label.visible = false
	add_child(_tooltip_label)

	# Audio players
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)


func _load_mainhall_data() -> void:
	if mainhall_resource_path.is_empty():
		# Try to get from campaign
		var campaign_path := _get_current_campaign_path()
		if not campaign_path.is_empty():
			mainhall_resource_path = campaign_path + "/ui/menu/mainhall.tres"

	if ResourceLoader.exists(mainhall_resource_path):
		_mainhall_data = load(mainhall_resource_path)
		_apply_mainhall_data()
	else:
		push_warning("MainHall: No mainhall resource found at " + mainhall_resource_path)


func _apply_mainhall_data() -> void:
	if not _mainhall_data:
		return

	# Load background
	if "bitmap" in _mainhall_data and not _mainhall_data.bitmap.is_empty():
		var bg_path := _find_texture_path(_mainhall_data.bitmap)
		if ResourceLoader.exists(bg_path):
			_background.texture = load(bg_path)


func _find_texture_path(bitmap_name: String) -> String:
	# Try common paths
	var paths := [
		"res://campaigns/hermes/ui/menu/%s.png" % bitmap_name,
		"res://assets/ui/mainhall/%s.png" % bitmap_name,
		"res://images/%s.png" % bitmap_name,
	]
	for path in paths:
		if ResourceLoader.exists(path):
			return path
	return ""


func _create_hotspots() -> void:
	if not _mainhall_data or not "doors" in _mainhall_data:
		_create_default_hotspots()
		return

	for door in _mainhall_data.doors:
		_create_hotspot_from_door(door)


func _create_default_hotspots() -> void:
	# Create default doors if no configuration
	var default_doors := [
		{"name": "Ready Room", "action": &"start_mission", "pos": Vector2(100, 300)},
		{"name": "Tech Room", "action": &"to_tech_room", "pos": Vector2(300, 300)},
		{"name": "Barracks", "action": &"to_barracks", "pos": Vector2(500, 300)},
		{"name": "Options", "action": &"to_options", "pos": Vector2(700, 300)},
		{"name": "Exit", "action": &"quit_game", "pos": Vector2(900, 300)},
	]

	for door_data in default_doors:
		var btn := Button.new()
		btn.text = door_data.name
		btn.position = door_data.pos
		btn.pressed.connect(_on_door_pressed.bind(door_data.name, door_data.action))
		_hotspot_container.add_child(btn)
		_hotspots.append(btn)


func _create_hotspot_from_door(door: Resource) -> void:
	var hotspot: Control

	if door.polygon.size() > 2:
		# Use polygon for non-rectangular hotspot
		hotspot = _create_polygon_hotspot(door)
	else:
		# Use button for rectangular hotspot
		hotspot = _create_button_hotspot(door)

	if hotspot:
		_hotspot_container.add_child(hotspot)
		_hotspots.append(hotspot)


func _create_button_hotspot(door: Resource) -> Button:
	var btn := Button.new()
	btn.text = door.display_name if "display_name" in door else ""
	btn.position = Vector2(door.position)
	btn.custom_minimum_size = Vector2(door.size) if "size" in door else Vector2(100, 50)
	btn.flat = true  # Invisible button, just for click detection

	var action_event: StringName = door.action_event if "action_event" in door else &""
	var display_name: String = door.display_name if "display_name" in door else "Door"

	btn.pressed.connect(_on_door_pressed.bind(display_name, action_event))
	btn.mouse_entered.connect(_on_door_hover.bind(door))
	btn.mouse_exited.connect(_on_door_unhover)

	return btn


func _create_polygon_hotspot(door: Resource) -> Control:
	# Create Area2D-based hotspot for polygon shapes
	var container := Control.new()
	container.position = Vector2(door.position)

	var area := Area2D.new()
	area.name = "HotspotArea"
	container.add_child(area)

	var collision := CollisionPolygon2D.new()
	collision.polygon = door.polygon
	area.add_child(collision)

	var action_event: StringName = door.action_event if "action_event" in door else &""
	var display_name: String = door.display_name if "display_name" in door else "Door"

	area.input_event.connect(_on_area_input.bind(display_name, action_event))
	area.mouse_entered.connect(_on_door_hover.bind(door))
	area.mouse_exited.connect(_on_door_unhover)

	return container


func _on_door_pressed(door_name: String, action_event: StringName) -> void:
	print("MainHall: Door activated - %s (%s)" % [door_name, action_event])
	door_activated.emit(door_name, action_event)

	# Play click sound
	_play_click_sound()

	# Dispatch state transition
	if action_event != &"":
		var gsm := get_node_or_null("/root/GameStateMachine")
		if gsm and gsm.has_method("dispatch"):
			gsm.dispatch(action_event)


func _on_area_input(
	_viewport: Node, event: InputEvent, _shape_idx: int, door_name: String, action: StringName
) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_door_pressed(door_name, action)


func _on_door_hover(door: Resource) -> void:
	var tooltip_text: String = ""
	if "tooltip" in door and not door.tooltip.is_empty():
		tooltip_text = door.tooltip
	elif "display_name" in door:
		tooltip_text = door.display_name

	if not tooltip_text.is_empty():
		_tooltip_label.text = tooltip_text
		_tooltip_label.visible = true

	# Play hover sound
	if "hover_sound" in door and not door.hover_sound.is_empty():
		_play_sound(door.hover_sound)


func _on_door_unhover() -> void:
	_tooltip_label.visible = false


func _start_music() -> void:
	if not _mainhall_data or not "music" in _mainhall_data:
		return

	var music_name: String = _mainhall_data.music
	if music_name.is_empty():
		return

	# Try to load music
	var music_paths := [
		"res://campaigns/hermes/ui/menu/%s.ogg" % music_name.to_lower(),
		"res://assets/music/%s.ogg" % music_name.to_lower(),
	]

	for path in music_paths:
		if ResourceLoader.exists(path):
			_music_player.stream = load(path)
			_music_player.play()
			return


func _play_click_sound() -> void:
	var click_path := "res://scenes/ui/main_menu/snd_brief_icon_select.ogg"
	if ResourceLoader.exists(click_path):
		_sfx_player.stream = load(click_path)
		_sfx_player.play()


func _play_sound(sound_name: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sound_by_name"):
		audio.play_sound_by_name(sound_name)


func _get_current_campaign_path() -> String:
	# Try to get from ProfileManager or MissionManager
	var pm := get_node_or_null("/root/ProfileManager")
	if pm and "current_campaign" in pm and pm.current_campaign:
		if "campaign_path" in pm.current_campaign:
			return pm.current_campaign.campaign_path

	# Default to hermes
	return "res://campaigns/hermes"
