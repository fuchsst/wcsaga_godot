# scripts/sound_animation/sound_manager.gd
extends Node
# Autoload Singleton for managing sound effect playback (2D and 3D).

# References (Set via editor or _ready)
@onready var GameSounds = get_node_or_null("/root/GameSounds") # Access to sound definitions
@onready var GameSettings = get_node_or_null("/root/GameSettings") # Access to volume settings

# Constants for sound priorities, mirroring original logic conceptually.
enum SoundPriority {
	MUST_PLAY, 			# Highest priority, might stop lower priority sounds.
	SINGLE_INSTANCE, 	# Only one instance of this sound can play at a time.
	DOUBLE_INSTANCE, 	# Max two instances.
	TRIPLE_INSTANCE, 	# Max three instances.
	DEFAULT = SINGLE_INSTANCE # Default if not specified
}

# Audio Bus Names (Ensure these exist in Project Settings -> Audio)
const MASTER_BUS = "Master"
const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"
const VOICE_BUS = "Voice"

# Configuration
const MAX_SOUND_PLAYERS := 32  # Maximum concurrent sounds (Adjust as needed)

# Dictionary to track currently playing sound instances
# Key: handle (int), Value: Dictionary { node: AudioStreamPlayer/3D, sound_id_name: String, priority: SoundPriority, start_time: float }
var _active_sounds: Dictionary = {}
# Dictionary to track counts of playing sounds by their ID name for priority limiting.
var _active_sound_counts: Dictionary = {}

# Node to parent dynamically created sound players.
var _sound_players_node_2d: Node
var _sound_players_node_3d: Node3D

# Player Pools
var _available_players_2d: Array[AudioStreamPlayer] = []
var _available_players_3d: Array[AudioStreamPlayer3D] = []

# Next available handle for sound instances.
var _next_handle: int = 1

# Loaded GameSoundsData resource
var _game_sounds_data: GameSoundsData = null

# Preload the SoundEntry script to access its enum
const SoundEntry = preload("res://scripts/resources/game_data/sound_entry.gd")

func _ready():
	name = "SoundManager" # Ensure singleton name

	if GameSounds == null:
		printerr("SoundManager: GameSounds autoload not found!")
		set_process(false)
		return
	if GameSettings == null:
		printerr("SoundManager: GameSettings autoload not found!")
		# Proceed with default volumes?
		# set_process(false)
		# return

	# Get the loaded data resource from GameSounds
	_game_sounds_data = GameSounds.get_data_resource()
	if _game_sounds_data == null:
		printerr("SoundManager: Could not get GameSoundsData resource from GameSounds autoload!")
		set_process(false)
		return

	# Create root nodes for sound players
	_sound_players_node_2d = Node.new()
	_sound_players_node_2d.name = "SoundPlayers2D"
	add_child(_sound_players_node_2d)

	_sound_players_node_3d = Node3D.new()
	_sound_players_node_3d.name = "SoundPlayers3D"
	add_child(_sound_players_node_3d)

	# Initialize sound player pools
	_initialize_sound_players()

	# Connect to settings changes if GameSettings provides a signal
	if GameSettings and GameSettings.has_signal("settings_changed"):
		GameSettings.settings_changed.connect(_on_settings_changed)
		# Apply initial volumes from settings
		_apply_bus_volumes()
	else:
		printerr("SoundManager: GameSettings does not have 'settings_changed' signal. Volumes won't auto-update.")
	# Apply default volumes maybe? Or assume buses are set correctly initially.
	_apply_bus_volumes() # Apply volumes on init

	print("SoundManager initialized.")


func _initialize_sound_players() -> void:
	# Create pool of 2D audio players
	for i in range(MAX_SOUND_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.name = "SoundPlayer2D_%d" % i
		_sound_players_node_2d.add_child(player)
		# Don't connect finished here, connect when taken from pool
		_available_players_2d.append(player)

	# Create pool of 3D audio players
	for i in range(MAX_SOUND_PLAYERS):
		var player := AudioStreamPlayer3D.new()
		player.name = "SoundPlayer3D_%d" % i
		_sound_players_node_3d.add_child(player)
		# Don't connect finished here, connect when taken from pool
		_available_players_3d.append(player)

func _get_next_sig() -> int:
	var sig = _next_handle
	_next_handle += 1
	if _next_handle <= 0: # Handle overflow and reserved -1
		_next_handle = 1
	return sig

# --- Volume Control ---

func _get_bus_name_for_category(category: SoundEntry.Category) -> StringName:
	match category:
		SoundEntry.Category.MUSIC: return MUSIC_BUS
		SoundEntry.Category.VOICE: return VOICE_BUS
		_: return SFX_BUS # Default to SFX bus

func _apply_bus_volumes():
	"""Applies volumes from GameSettings to the audio buses."""
	if not GameSettings: return
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), linear_to_db(GameSettings.master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), linear_to_db(GameSettings.music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), linear_to_db(GameSettings.effects_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(VOICE_BUS), linear_to_db(GameSettings.voice_volume))

func _on_settings_changed():
	"""Callback when game settings change."""
	_apply_bus_volumes()

# --- Sound Playback ---

func play_sound_2d(sound_id_name: String, volume_scale: float = 1.0, p_priority: SoundPriority = SoundPriority.DEFAULT, pitch_scale: float = 1.0) -> int:
	"""Plays a 2D (non-positional) sound effect."""
	var entry = _get_sound_entry(sound_id_name)
	if not entry: return -1

	var handle = _allocate_sound_channel(entry, p_priority)
	if handle == -1: return -1 # Could not play due to priority/limits

	var stream = entry.get_stream()
	if not stream:
		printerr("SoundManager: Failed to get stream for 2D sound: ", sound_id_name)
		_free_sound_channel(handle, sound_id_name) # Free the allocated slot
		return -1

	# Get a player from the pool
	var player: AudioStreamPlayer = _get_player_from_pool_2d()
	if not player:
		# Pool is empty, cannot play sound (or implement logic to stop oldest/lowest priority)
		printerr("SoundManager: No available 2D sound players!")
		_free_sound_channel(handle, sound_id_name) # Free the allocated slot
		return -1

	# Configure player
	player.stream = stream
	# Volume is controlled by bus + individual scale
	player.volume_db = linear_to_db(clamp(volume_scale, 0.0, 1.0)) if volume_scale > 0.0 else -80.0
	player.pitch_scale = pitch_scale
	player.bus = _get_bus_name_for_category(entry.category)

	# Store tracking info
	_active_sounds[handle] = {
		"node": player,
		"sound_id_name": sound_id_name,
		"priority": p_priority,
		"start_time": Time.get_ticks_msec() / 1000.0
	}

	# Connect finished signal with necessary parameters
	player.finished.connect(Callable(self, "_on_sound_finished").bind(player, handle, sound_id_name), CONNECT_ONE_SHOT)

	player.play()
	return handle

func play_sound_3d(sound_id_name: String, p_position: Vector3, p_velocity: Vector3 = Vector3.ZERO, volume_scale: float = 1.0, radius: float = 0.0, p_priority: SoundPriority = SoundPriority.DEFAULT, pitch_scale: float = 1.0) -> int:
	"""Plays a 3D positional sound effect."""
	var entry = _get_sound_entry(sound_id_name)
	if not entry: return -1

	var handle = _allocate_sound_channel(entry, p_priority)
	if handle == -1: return -1 # Could not play due to priority/limits

	var stream = entry.get_stream()
	if not stream:
		printerr("SoundManager: Failed to get stream for 3D sound: ", sound_id_name)
		_free_sound_channel(handle, sound_id_name)
		return -1

	# Get a player from the pool
	var player: AudioStreamPlayer3D = _get_player_from_pool_3d()
	if not player:
		# Pool is empty, cannot play sound (or implement logic to stop oldest/lowest priority)
		printerr("SoundManager: No available 3D sound players!")
		_free_sound_channel(handle, sound_id_name)
		return -1

	# Configure player
	player.stream = stream
	player.global_position = p_position
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED # Keep disabled unless needed

	# Volume is controlled by bus + individual scale
	player.unit_db = linear_to_db(clamp(volume_scale, 0.0, 1.0)) if volume_scale > 0.0 else -80.0
	player.pitch_scale = pitch_scale
	player.bus = _get_bus_name_for_category(entry.category)

	# Set attenuation based on min/max distances.
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE # Or Logarithmic?
	# Heuristic: unit_size is where volume is roughly halved. Let's use min_distance if > 0, else a default.
	player.unit_size = entry.min_distance if entry.min_distance > 1.0 else 5.0 # Avoid very small unit_size
	player.max_distance = entry.max_distance + radius # Adjust max distance by object radius

	# Store tracking info
	_active_sounds[handle] = {
		"node": player,
		"sound_id_name": sound_id_name,
		"priority": p_priority,
		"start_time": Time.get_ticks_msec() / 1000.0
	}

	# Connect finished signal with necessary parameters
	player.finished.connect(Callable(self, "_on_sound_finished").bind(player, handle, sound_id_name), CONNECT_ONE_SHOT)

	player.play()
	return handle

# --- Sound Control ---

func stop_sound(handle: int):
	"""Stops a specific sound instance by its handle."""
	if _active_sounds.has(handle):
		var sound_data = _active_sounds[handle]
		var player_node = sound_data["node"]
		var sound_id_name = sound_data["sound_id_name"]

		if is_instance_valid(player_node):
			player_node.stop()
			# Manually trigger cleanup since 'finished' signal won't emit
			_on_sound_finished(player_node, handle, sound_id_name)
		else:
			# Node might have been freed already, just clean up dictionaries
			_free_sound_channel(handle, sound_id_name)
	else:
		pass # Ignore invalid handle

func stop_all_sounds():
	"""Stops all currently playing sound effects managed by this manager."""
	# Create a copy of keys because stop_sound modifies the dictionary
	var handles_to_stop = _active_sounds.keys()
	for handle in handles_to_stop:
		stop_sound(handle)
	# Dictionaries should be empty now if cleanup worked

func set_sound_volume(handle: int, volume_scale: float):
	"""Sets the volume scale multiplier for a specific sound instance."""
	if _active_sounds.has(handle):
		var player_node = _active_sounds[handle]["node"]
		if is_instance_valid(player_node):
			# Apply scale relative to bus volume (which is handled by AudioServer)
			# Note: unit_db for 3D, volume_db for 2D
			if player_node is AudioStreamPlayer3D:
				player_node.unit_db = linear_to_db(clamp(volume_scale, 0.0, 1.0)) if volume_scale > 0.0 else -80.0
			elif player_node is AudioStreamPlayer:
				player_node.volume_db = linear_to_db(clamp(volume_scale, 0.0, 1.0)) if volume_scale > 0.0 else -80.0
	# else: # Don't spam errors for sounds that might have just finished
		# printerr("SoundManager: Cannot set volume - handle not found: ", handle)

func set_sound_pitch(handle: int, pitch_scale: float):
	"""Sets the pitch scale for a specific sound instance."""
	if _active_sounds.has(handle):
		var player_node = _active_sounds[handle]["node"]
		if is_instance_valid(player_node):
			player_node.pitch_scale = pitch_scale
	# else:
		# printerr("SoundManager: Cannot set pitch - handle not found: ", handle)

func is_sound_playing(handle: int) -> bool:
	"""Checks if a sound instance is currently playing."""
	if _active_sounds.has(handle):
		var player_node = _active_sounds[handle]["node"]
		# Check if node is valid *and* playing
		return is_instance_valid(player_node) and player_node.playing
	return false

func update_3d_sound_pos(handle: int, new_position: Vector3):
	"""Updates the position of a playing 3D sound."""
	if _active_sounds.has(handle):
		var player_node = _active_sounds[handle]["node"]
		if is_instance_valid(player_node) and player_node is AudioStreamPlayer3D:
			player_node.global_position = new_position
		elif is_instance_valid(player_node):
			# printerr("SoundManager: Attempted to update position of a 2D sound handle: ", handle)
			pass
	# else: # Don't spam errors for sounds that might have just finished
		# printerr("SoundManager: Cannot update 3D sound position - handle not found: ", handle)
		# pass

# --- Internal Callbacks & Helpers ---

func _on_sound_finished(player_node: Node, handle: int, sound_id_name: String):
	"""Callback function connected to the 'finished' signal of sound players."""
	_free_sound_channel(handle, sound_id_name)

	# Return player to pool
	if is_instance_valid(player_node):
		player_node.stop() # Ensure stopped
		player_node.stream = null # Release stream reference
		if player_node is AudioStreamPlayer:
			if not player_node in _available_players_2d:
				_available_players_2d.append(player_node)
		elif player_node is AudioStreamPlayer3D:
			if not player_node in _available_players_3d:
				_available_players_3d.append(player_node)
		# Don't queue_free, reuse it

func _get_sound_entry(sound_id_name: String) -> SoundEntry:
	"""Retrieves a SoundEntry from the GameSounds autoload."""
	if _game_sounds_data and _game_sounds_data.sound_entries.has(sound_id_name):
		return _game_sounds_data.sound_entries[sound_id_name]
	else:
		printerr("SoundManager: Sound entry not found: ", sound_id_name)
		return null

func _allocate_sound_channel(sound_entry: SoundEntry, priority: SoundPriority) -> int:
	"""Checks limits and potentially stops another sound to return a valid handle, or -1."""
	if not sound_entry: return -1

	var sound_id_name = sound_entry.id_name
	var current_count = _active_sound_counts.get(sound_id_name, 0)
	var limit = _get_limit_for_priority(priority)

	if current_count < limit:
		# Space available, allocate
		_active_sound_counts[sound_id_name] = current_count + 1
		return _generate_handle()
	elif priority == SoundPriority.MUST_PLAY:
		# Limit reached, but MUST_PLAY - find oldest/lowest priority sound of SAME ID to stop
		var oldest_handle = -1
		var oldest_time = Time.get_ticks_msec()
		for handle in _active_sounds:
			var sound_data = _active_sounds[handle]
			if sound_data["sound_id_name"] == sound_id_name:
				# Found an instance of the same sound
				# Simple approach: stop the oldest one found
				if sound_data["start_time"] < oldest_time:
					oldest_time = sound_data["start_time"]
					oldest_handle = handle
				# More complex: consider priority of existing sounds if needed

		if oldest_handle != -1:
			print(f"SoundManager: MUST_PLAY stopping existing sound '{sound_id_name}' (handle {oldest_handle})")
			stop_sound(oldest_handle) # This will call _free_sound_channel
			# Now allocate the new one
			_active_sound_counts[sound_id_name] = _active_sound_counts.get(sound_id_name, 0) + 1 # Increment count again
			return _generate_handle()
		else:
			# Should not happen if current_count >= limit, but safety check
			printerr(f"SoundManager: MUST_PLAY failed to find existing sound '{sound_id_name}' to stop.")
			return -1
	else:
		# Limit reached, and not MUST_PLAY
		# print(f"SoundManager: Limit ({limit}) reached for sound: {sound_id_name}")
		return -1

func _free_sound_channel(handle: int, sound_id_name: String):
	"""Frees bookkeeping info for a finished/stopped sound."""
	if _active_sounds.has(handle):
		_active_sounds.erase(handle)

	if _active_sound_counts.has(sound_id_name):
		_active_sound_counts[sound_id_name] -= 1
		if _active_sound_counts[sound_id_name] <= 0:
			_active_sound_counts.erase(sound_id_name)

func _get_limit_for_priority(priority: SoundPriority) -> int:
	"""Maps SoundPriority enum to instance limits."""
	match priority:
		SoundPriority.SINGLE_INSTANCE: return 1
		SoundPriority.DOUBLE_INSTANCE: return 2
		SoundPriority.TRIPLE_INSTANCE: return 3
		_: return 99 # Effectively no limit for MUST_PLAY or others

func _get_player_from_pool_2d() -> AudioStreamPlayer:
	if not _available_players_2d.is_empty():
		return _available_players_2d.pop_back()
	# Optional: Create new if pool empty and total count < MAX_SOUND_PLAYERS
	# var total_active = _active_sounds.size() # Need to count 2D/3D separately
	# if total_active < MAX_SOUND_PLAYERS:
	# 	var player = AudioStreamPlayer.new()
	# 	player.name = "SoundPlayer2D_Dyn_%d" % _next_handle
	# 	_sound_players_node_2d.add_child(player)
	# 	return player
	return null

func _get_player_from_pool_3d() -> AudioStreamPlayer3D:
	if not _available_players_3d.is_empty():
		return _available_players_3d.pop_back()
	# Optional: Create new if pool empty and total count < MAX_SOUND_PLAYERS
	# var total_active = _active_sounds.size() # Need to count 2D/3D separately
	# if total_active < MAX_SOUND_PLAYERS:
	# 	var player = AudioStreamPlayer3D.new()
	# 	player.name = "SoundPlayer3D_Dyn_%d" % _next_handle
	# 	_sound_players_node_3d.add_child(player)
	# 	return player
	return null

# --- Cleanup ---
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		stop_all_sounds()
		# Nodes in the pool are children, Godot should free them.
		print("SoundManager shutting down.")
