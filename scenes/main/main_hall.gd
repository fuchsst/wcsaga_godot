extends Node2D

# Sound configuration
@export var sounds: GameSounds

# Sound indices from tbl file
const DOOR_OPEN_SOUND = 23
const DOOR_CLOSE_SOUND = 24
const HOTSPOT_ON_SOUND = 36
const HOTSPOT_OFF_SOUND = 37
const AMBIENT_LOOP_SOUND = 38

# Intercom sound configuration
const INTERCOM_MIN_DELAY = 30000  # 30 seconds
const INTERCOM_MAX_DELAY = 45000  # 45 seconds
const INTERCOM_SOUNDS = [44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61]

# Animation states
enum DoorState {CLOSED, OPENING, OPEN, CLOSING}
var door_states = {}

# Sound handles
var ambient_loop_handle = -1
var intercom_sound_handle = -1
var door_sound_handles = {}

# Current mouse region
var current_mouse_region = null

# Mask texture for clickable regions
@onready var mask_texture: Texture2D = preload("res://assets/hermes_interface/2_mainhall-M.png")

func _ready() -> void:
	# Initialize door states and sound handles
	for door in $DoorAnimations.get_children():
		door_states[door.name] = DoorState.CLOSED
		door_sound_handles[door.name] = -1
		
	# Set up mask texture for clickable regions
	var mask_image = mask_texture.get_image()
	mask_image.convert(Image.FORMAT_RGBA8)
	
	# Configure buttons to use mask
	for button in $DoorButtons.get_children():
		var rect = button.get_rect()
		var mask_rect = Rect2i(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		var button_mask = mask_image.get_region(mask_rect)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.gui_input.connect(_on_button_gui_input.bind(button, button_mask))
		
	# Connect door button signals
	var buttons = {
		"ExitButton": ["Exit Wing Commander Saga", "_on_exit_pressed", "ExitDoor"],
		"PilotRoomButton": ["Barracks - Manage your Wing Commander Saga pilots", "_on_barracks_pressed", "PilotRoomDoor"],
		"BriefingRoomButton": ["Ready room - Start or continue a campaign", "_on_briefing_pressed", "BriefingDoor"],
		"TechRoomButton": ["Tech room - View specifications of Wing Commander Saga ships and weaponry", "_on_tech_room_pressed", "TechRoomDoor"],
		"OptionsButton": ["Options - Change your Wing Commander Saga options", "_on_options_pressed", "OptionsDoor"],
		"CampaignButton": ["Campaign Room - View all available campaigns", "_on_campaign_pressed", "CampaignDoor"]
	}
	
	for button_name in buttons:
		var button = $DoorButtons.get_node(button_name)
		var tooltip = buttons[button_name][0]
		var pressed_func = buttons[button_name][1]
		var door_name = buttons[button_name][2]
		
		button.mouse_entered.connect(_on_button_mouse_entered.bind(tooltip, door_name))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(door_name))
		button.pressed.connect(Callable(self, pressed_func))
	
	# Start ambient sounds
	_start_ambient_loop()
	_start_intercom_timer()
	
	# Start misc animations
	for anim in $MiscAnimations.get_children():
		if anim.sprite_frames.has_animation("default") and anim.sprite_frames.get_frame_count("default") > 0:
			anim.play("default")

func _process(_delta: float) -> void:
	# Update door animations
	for door_name in door_states:
		var door = $DoorAnimations.get_node(door_name)
		if not door.sprite_frames.has_animation("default") or door.sprite_frames.get_frame_count("default") == 0:
			continue
			
		match door_states[door_name]:
			DoorState.OPENING:
				if door.frame >= door.sprite_frames.get_frame_count("default") - 1:
					door_states[door_name] = DoorState.OPEN
			DoorState.CLOSING:
				if door.frame <= 0:
					door_states[door_name] = DoorState.CLOSED
					door.stop()

func _play_interface_sound(index: int, looping: bool = false) -> int:
	var entry = sounds.get_interface_sound_entry(index)
	if not entry:
		return -1
		
	var stream = sounds.get_sound_stream(entry)
	if not stream:
		return -1
		
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.volume_db = linear_to_db(entry.volume)
	
	if looping:
		player.finished.connect(func(): player.play())
	else:
		player.finished.connect(func(): player.queue_free())
		
	player.play()
	return player.get_instance_id()

func _stop_sound(handle: int) -> void:
	if handle == -1:
		return
		
	var player = instance_from_id(handle)
	if player and is_instance_valid(player):
		player.queue_free()

func _start_ambient_loop() -> void:
	if ambient_loop_handle == -1:
		ambient_loop_handle = _play_interface_sound(AMBIENT_LOOP_SOUND, true)

func _stop_ambient_loop() -> void:
	_stop_sound(ambient_loop_handle)
	ambient_loop_handle = -1

func _start_intercom_timer() -> void:
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_play_random_intercom_sound)
	timer.start(randf_range(INTERCOM_MIN_DELAY / 1000.0, INTERCOM_MAX_DELAY / 1000.0))

func _play_random_intercom_sound() -> void:
	if intercom_sound_handle != -1:
		var player = instance_from_id(intercom_sound_handle)
		if player and is_instance_valid(player) and player.playing:
			return
		intercom_sound_handle = -1
		
	var sound_index = INTERCOM_SOUNDS[randi() % INTERCOM_SOUNDS.size()]
	intercom_sound_handle = _play_interface_sound(sound_index)
	_start_intercom_timer()

func _play_door_sound(door_name: String, open: bool) -> void:
	_stop_sound(door_sound_handles[door_name])
	door_sound_handles[door_name] = -1
	
	var sound_index = DOOR_OPEN_SOUND if open else DOOR_CLOSE_SOUND
	door_sound_handles[door_name] = _play_interface_sound(sound_index)

func _play_hotspot_sound(on: bool) -> void:
	var sound_index = HOTSPOT_ON_SOUND if on else HOTSPOT_OFF_SOUND
	_play_interface_sound(sound_index)

func _animate_door(door_name: String, open: bool) -> void:
	var door = $DoorAnimations.get_node(door_name)
	if not door.sprite_frames.has_animation("default") or door.sprite_frames.get_frame_count("default") == 0:
		return
		
	if open and door_states[door_name] != DoorState.OPEN:
		door_states[door_name] = DoorState.OPENING
		door.play("default")
		_play_door_sound(door_name, true)
	elif not open and door_states[door_name] != DoorState.CLOSED:
		door_states[door_name] = DoorState.CLOSING
		door.play("default", true)  # Play in reverse
		_play_door_sound(door_name, false)

func _on_button_gui_input(event: InputEvent, button: Control, mask: Image) -> void:
	if event is InputEventMouseMotion:
		var local_pos = event.position
		if local_pos.x >= 0 and local_pos.y >= 0 and local_pos.x < mask.get_width() and local_pos.y < mask.get_height():
			var color = mask.get_pixel(local_pos.x, local_pos.y)
			if color.a > 0.5:  # Check if pixel is in clickable region
				if not current_mouse_region:
					_on_button_mouse_entered(button.tooltip_text, button.name.replace("Button", "Door"))
			else:
				if current_mouse_region:
					_on_button_mouse_exited(current_mouse_region.replace("Door", "Button"))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = event.position
		if local_pos.x >= 0 and local_pos.y >= 0 and local_pos.x < mask.get_width() and local_pos.y < mask.get_height():
			var color = mask.get_pixel(local_pos.x, local_pos.y)
			if color.a > 0.5:  # Check if pixel is in clickable region
				button.emit_signal("pressed")

func _on_button_mouse_entered(tooltip: String, door_name: String) -> void:
	current_mouse_region = door_name
	_play_hotspot_sound(true)
	$TooltipPanel.show()
	$TooltipPanel/TooltipLabel.text = tooltip
	_animate_door(door_name, true)

func _on_button_mouse_exited(door_name: String) -> void:
	current_mouse_region = null
	_play_hotspot_sound(false)
	$TooltipPanel.hide()
	$TooltipPanel/TooltipLabel.text = ""
	_animate_door(door_name, false)

func _on_exit_pressed() -> void:
	# Let door animation and sound finish before quitting
	await get_tree().create_timer(0.5).timeout
	_stop_ambient_loop()
	get_tree().quit()

func _transition_to_scene(scene_key: String) -> void:
	# Let door animation and sound finish before transitioning
	await get_tree().create_timer(0.5).timeout
	
	SceneManager.change_scene(scene_key,
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_options(1.0, "fade"),
		SceneManager.create_general_options(Color.BLACK))

func _on_barracks_pressed() -> void:
	_transition_to_scene("barracks")

func _on_briefing_pressed() -> void:
	_transition_to_scene("briefing")

func _on_tech_room_pressed() -> void:
	_transition_to_scene("tech_room")

func _on_options_pressed() -> void:
	_transition_to_scene("options")

func _on_campaign_pressed() -> void:
	_transition_to_scene("campaign")
