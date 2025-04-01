# scripts/mission_system/message_system/message_manager.gd
# Singleton (Autoload) responsible for managing in-mission messages, voice, and personas.
# Corresponds to missionmessage.cpp logic.
class_name MessageManager
extends Node

# --- Dependencies ---
const MessageData = preload("res://scripts/resources/mission/message_data.gd")
const PersonaData = preload("res://scripts/resources/mission/persona_data.gd")
# Access HUDManager, SoundManager, SexpVariableManager via singletons

# --- Constants ---
const MAX_MESSAGE_Q = 30
const MAX_PLAYING_MESSAGES = 1 # Original limit, might increase if needed
const MESSAGE_PRIORITY_LOW = 1
const MESSAGE_PRIORITY_NORMAL = 2
const MESSAGE_PRIORITY_HIGH = 3
const MESSAGE_TIME_IMMEDIATE = 1
const MESSAGE_TIME_SOON = 2
const MESSAGE_TIME_ANYTIME = 3
const MESSAGE_SOURCE_SHIP = 1
const MESSAGE_SOURCE_WINGMAN = 2
const MESSAGE_SOURCE_COMMAND = 3
const MESSAGE_SOURCE_SPECIAL = 4 # For messages with custom sender names

# --- Message Queue Entry ---
# Using a Dictionary for queue entries for flexibility
# Keys: time_added, priority, message_data, special_message_text, who_from, source, flags, min_delay_stamp, group, window_timestamp
var message_queue: Array[Dictionary] = []

# --- Currently Playing Messages ---
# Structure to hold info about messages currently being played (voice/anim)
# Keys: message_data, priority, ship_node, wave_player, anim_player, start_time
var playing_messages: Array[Dictionary] = []

# --- Persona Data ---
var personas: Array[PersonaData] = [] # Loaded globally or per mission?
var default_command_persona_index: int = -1

# --- State ---
var message_wave_muted: bool = false
var next_mute_time: int = -1 # Timestamp
var message_wave_duration_ms: int = 0 # Duration of the currently playing wave

# --- Nodes ---
# References to nodes needed for playback (set externally or found)
var talking_head_anim_player: AnimationPlayer = null # In HUD scene?
var voice_audio_player: AudioStreamPlayer = null # Non-positional voice player

func _ready() -> void:
	print("MessageManager initialized.")
	# TODO: Find/assign talking_head_anim_player and voice_audio_player
	# TODO: Load global personas from resources/messages/personas/
	# TODO: Determine default_command_persona_index based on loaded personas

func _physics_process(delta: float) -> void:
	# 1. Process currently playing messages (check for completion)
	_process_playing_messages(delta)

	# 2. Check message queue for messages ready to play
	_process_message_queue(delta)

	# 3. Handle communication distortion effects if needed
	_apply_distortion_effects(delta)


# --- Public API ---

func load_mission_messages(mission_data: MissionData) -> void:
	# TODO: Load mission-specific messages and potentially personas
	# Clear existing mission messages?
	message_queue.clear() # Clear queue for new mission
	# Reset persona usage flags?
	for p in personas:
		p.used = false
	print("MessageManager: Loaded mission messages (Placeholder).")


func queue_message(
	message_data: MessageData,
	priority: int,
	timing: int, # MESSAGE_TIME_*
	who_from: String,
	source: int, # MESSAGE_SOURCE_*
	group: int = 0, # For potential grouping/canceling logic
	delay_ms: int = 0,
	special_message_text: String = "" # Override text from message_data
	) -> void:

	if message_queue.size() >= MAX_MESSAGE_Q:
		printerr("MessageManager: Message queue full, cannot add message: ", message_data.name if message_data else "N/A")
		return

	# TODO: Implement filtering (e.g., multiplayer team filter from message_data.multi_team)
	# TODO: Implement checks for duplicate messages if needed (e.g., rearm messages)

	var queue_entry: Dictionary = {}
	queue_entry["time_added"] = Time.get_ticks_msec() # Use ticks for sorting
	queue_entry["priority"] = priority
	queue_entry["message_data"] = message_data
	queue_entry["special_message_text"] = special_message_text
	queue_entry["who_from"] = who_from
	queue_entry["source"] = source
	queue_entry["flags"] = 0 # TODO: Determine flags (MQF_CONVERT_TO_COMMAND, MQF_CHECK_ALIVE) based on who_from, persona, etc.
	queue_entry["min_delay_stamp"] = Time.get_ticks_msec() + delay_ms
	queue_entry["group"] = group

	# Set window timestamp based on timing
	match timing:
		MESSAGE_TIME_IMMEDIATE:
			queue_entry["window_timestamp"] = Time.get_ticks_msec() + 1000 # Example: 1 second window
		MESSAGE_TIME_SOON:
			queue_entry["window_timestamp"] = Time.get_ticks_msec() + 5000 # Example: 5 second window
		_: # MESSAGE_TIME_ANYTIME
			queue_entry["window_timestamp"] = -1 # No window limit

	# TODO: Perform SEXP variable replacement on message text if needed
	# var final_text = special_message_text if not special_message_text.is_empty() else message_data.message_text
	# if SexpVariableManager.text_has_variables(final_text):
	#	 queue_entry["special_message_text"] = SexpVariableManager.replace_variables(final_text)

	message_queue.append(queue_entry)
	# Sort queue by priority (descending), then time_added (ascending)
	message_queue.sort_custom(func(a, b):
		if a["priority"] != b["priority"]:
			return a["priority"] > b["priority"]
		return a["time_added"] < b["time_added"]
	)
	#print("MessageManager: Queued message from %s (Priority: %d)" % [who_from, priority])


func send_unique_to_player(message_name: String, sender_data, source_type: int, priority: int, group: int, delay_ms: int):
	# TODO: Find MessageData by name
	# TODO: Determine 'who_from' based on source_type and sender_data (ship node, command string, etc.)
	# TODO: Call queue_message
	pass


func send_builtin_to_player(builtin_type: int, sender_ship: ShipBase, priority: int, timing: int, group: int, delay_ms: int, multi_target: int, multi_team_filter: int):
	# TODO: Implement logic from missionmessage.cpp::message_send_builtin_to_player
	# - Find appropriate MessageData based on type, sender persona/species
	# - Determine 'who_from' (sender_ship name or command sender)
	# - Handle multiplayer filtering/targeting
	# - Call queue_message
	pass


func kill_all_playing_messages(kill_voice: bool = true, kill_anim: bool = true):
	for playing_entry in playing_messages:
		if kill_voice and playing_entry.has("wave_player") and is_instance_valid(playing_entry["wave_player"]):
			playing_entry["wave_player"].stop()
		if kill_anim and playing_entry.has("anim_player") and is_instance_valid(playing_entry["anim_player"]):
			playing_entry["anim_player"].stop()
			# TODO: Hide the talking head UI element
	playing_messages.clear()


# --- Internal Logic ---

func _process_playing_messages(delta: float):
	var i = 0
	while i < playing_messages.size():
		var entry = playing_messages[i]
		var voice_done = true
		var anim_done = true

		if entry.has("wave_player") and is_instance_valid(entry["wave_player"]):
			if entry["wave_player"].is_playing():
				voice_done = false

		if entry.has("anim_player") and is_instance_valid(entry["anim_player"]):
			if entry["anim_player"].is_playing():
				anim_done = false

		# TODO: Add text duration check if no voice/anim

		if voice_done and anim_done:
			# Message finished
			# TODO: Hide talking head UI if needed
			playing_messages.remove_at(i)
			#print("MessageManager: Finished playing message.")
		else:
			i += 1


func _process_message_queue(delta: float):
	# Check if we can play a new message
	if playing_messages.size() >= MAX_PLAYING_MESSAGES:
		return

	# Find the highest priority message ready to play
	var best_entry_index = -1
	for i in range(message_queue.size()):
		var entry = message_queue[i]

		# Check minimum delay
		if Time.get_ticks_msec() < entry["min_delay_stamp"]:
			continue

		# Check time window (if applicable)
		if entry["window_timestamp"] != -1 and Time.get_ticks_msec() > entry["window_timestamp"]:
			# Message expired in window
			print("MessageManager: Message from %s expired in window." % entry["who_from"])
			message_queue.remove_at(i)
			i -= 1 # Adjust index after removal
			continue

		# TODO: Check MQF_CHECK_ALIVE flag - verify sender ship still exists

		# Found a candidate
		best_entry_index = i
		break

	if best_entry_index != -1:
		var entry_to_play = message_queue[best_entry_index]
		message_queue.remove_at(best_entry_index)
		_play_message(entry_to_play)


func _play_message(entry: Dictionary):
	var message_data: MessageData = entry["message_data"]
	if message_data == null:
		printerr("MessageManager: Cannot play message, MessageData is null.")
		return

	# TODO: Check communication status (HUDManager.hud_communications_state())
	# TODO: Check EMP effect (emp_active_local())
	# TODO: Check Sexp_Messages_Scrambled

	var final_text = entry["special_message_text"] if not entry["special_message_text"].is_empty() else message_data.message_text
	var final_sender = entry["who_from"] # TODO: Adjust sender name based on callsign/class/hiding flags

	# --- Play Voice ---
	var wave_player = null
	message_wave_duration_ms = 0
	if not message_data.wave_filename.is_empty():
		# TODO: Handle MQF_CONVERT_TO_COMMAND filename adjustment
		var wave_path = "res://assets/voices/" + message_data.wave_filename # Adjust path
		var stream = load(wave_path) as AudioStream
		if stream:
			if voice_audio_player == null: # Create if needed
				voice_audio_player = AudioStreamPlayer.new()
				add_child(voice_audio_player)
			voice_audio_player.stream = stream
			# TODO: Set volume based on category (VOICE) and settings
			voice_audio_player.play()
			wave_player = voice_audio_player
			message_wave_duration_ms = int(stream.get_length() * 1000)
		else:
			printerr("MessageManager: Failed to load voice wave: ", wave_path)

	# --- Play Animation ---
	var anim_player = null
	if not message_data.avi_filename.is_empty():
		# TODO: Handle persona/command head selection logic to get final anim name
		var final_anim_name = message_data.avi_filename # Placeholder
		# TODO: Load and play animation on talking_head_anim_player
		# anim_player = talking_head_anim_player
		# anim_player.play(final_anim_name)
		# TODO: Show the talking head UI element
		pass

	# --- Display Text ---
	# TODO: Apply distortion to final_text if needed
	# TODO: Call HUDManager.add_hud_message(final_sender, final_text, entry["source"])
	if Engine.has_singleton("HUDManager"):
		HUDManager.add_hud_message(final_sender, final_text, entry["source"])
	else:
		print("HUD: %s: %s" % [final_sender, final_text]) # Fallback print

	# --- Add to Playing List ---
	var playing_entry: Dictionary = {}
	playing_entry["message_data"] = message_data
	playing_entry["priority"] = entry["priority"]
	# playing_entry["ship_node"] = ? # Need to resolve who_from to node if possible
	if wave_player: playing_entry["wave_player"] = wave_player
	if anim_player: playing_entry["anim_player"] = anim_player
	playing_entry["start_time"] = Time.get_ticks_msec()

	playing_messages.append(playing_entry)
	#print("MessageManager: Playing message from %s" % final_sender)


func _apply_distortion_effects(delta: float):
	# TODO: Implement logic from message_maybe_distort()
	# - Check comms status, EMP, Sexp_Messages_Scrambled
	# - If distortion needed, check next_mute_time
	# - Toggle message_wave_muted based on pattern
	# - Adjust volume of playing_messages[i]["wave_player"] based on message_wave_muted
	pass


# --- Persona Management ---
# TODO: Implement persona lookup and assignment logic
# func get_persona(ship: ShipBase) -> PersonaData: ...
# func select_persona(ship: ShipBase, needed_flags: int, auto_assign_only: bool) -> PersonaData: ...
# func message_persona_name_lookup(name: String) -> int: ...
