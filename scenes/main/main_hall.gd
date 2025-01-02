extends Control

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
		var pressed_func = buttons[button_name][1]		
		button.pressed.connect(Callable(self, pressed_func))
	
	# Start ambient sounds
	_start_ambient_loop()
	_start_intercom_timer()
		
	# Show first-time tip if needed
	GameState.show_pilot_tip()

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
	var entry = sounds.interface_sounds[index]
	if not entry:
		return -1
		
	var stream = entry.audio_file
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
		door.play_backwards("default")  # Play in reverse
		_play_door_sound(door_name, false)


func _on_exit_pressed() -> void:
	# Let door animation and sound finish before quitting
	await get_tree().create_timer(0.5).timeout
	_stop_ambient_loop()
	get_tree().quit()

func _transition_to_scene(scene_key: String) -> void:
	# Let door animation and sound finish before transitioning
	await get_tree().create_timer(0.5).timeout
	
	SceneManager.change_scene(scene_key,
		SceneManager.create_options(0.5, "fade"),
		SceneManager.create_options(0.5, "fade"),
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


func _on_exit_button_mouse_entered() -> void:
	_animate_door("ExitDoor", true)


func _on_exit_button_mouse_exited() -> void:
	_animate_door("ExitDoor", false)


func _on_briefing_room_button_mouse_entered() -> void:
	_animate_door("BriefingDoor", true)


func _on_briefing_room_button_mouse_exited() -> void:
	_animate_door("BriefingDoor", false)


func _on_pilot_room_button_mouse_entered() -> void:
	_animate_door("PilotRoomDoor", true)


func _on_pilot_room_button_mouse_exited() -> void:
	_animate_door("PilotRoomDoor", false)


func _on_campaign_button_mouse_entered() -> void:
	_play_hotspot_sound(true)


func _on_campaign_button_mouse_exited() -> void:
	_play_hotspot_sound(false)


func _on_options_button_mouse_entered() -> void:
	_play_hotspot_sound(true)


func _on_options_button_mouse_exited() -> void:
	_play_hotspot_sound(false)


func _on_tech_room_button_mouse_entered() -> void:
	_play_hotspot_sound(true)


func _on_tech_room_button_mouse_exited() -> void:
	_play_hotspot_sound(false)
