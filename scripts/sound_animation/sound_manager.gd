# scripts/sound_animation/sound_manager.gd
extends Node
# Autoload Singleton for managing sound effect playback (2D and 3D).

# Reference to the GameSounds autoload
@onready var GameSounds = get_node_or_null("/root/GameSounds")

# Constants for sound priorities, mirroring original logic conceptually.
enum SoundPriority {
	MUST_PLAY, 			# Highest priority, might stop lower priority sounds.
	SINGLE_INSTANCE, 	# Only one instance of this sound can play at a time.
	DOUBLE_INSTANCE, 	# Max two instances.
	TRIPLE_INSTANCE, 	# Max three instances.
	DEFAULT = SINGLE_INSTANCE # Default if not specified
}

# Dictionary to track currently playing sound instances (handle -> Dictionary with 'node' and 'sound_id_name').
var _active_sounds: Dictionary = {}
# Dictionary to track counts of playing sounds by their ID name for priority limiting.
var _active_sound_counts: Dictionary = {}

# Node to parent dynamically created sound players.
var _sound_players_node: Node3D

# Next available handle for sound instances.
var _next_handle: int = 1

func _ready():
	if GameSounds == null:
		printerr("SoundManager: GameSounds autoload not found!")
		set_process(false) # Disable if GameSounds is missing
		return

	# Create a dedicated node to hold the sound players for organization.
	_sound_players_node = Node3D.new()
	_sound_players_node.name = "SoundPlayers"
	add_child(_sound_players_node)
	# Preloading is handled by GameSounds._ready()

func play_sound_2d(sound_id_name: String, volume_scale: float = 1.0, p_priority: SoundPriority = SoundPriority.DEFAULT) -> int:
	"""Plays a 2D (non-positional) sound effect. Corresponds to gamesnd_play_iface."""
	var entry = _get_sound_entry(sound_id_name)
	if not entry: return -1
	if not _can_play_sound(entry): return -1 # Check instance limits

	var stream = entry.get_stream()
	if not stream:
		printerr("SoundManager: Failed to get stream for 2D sound: ", sound_id_name)
		return -1

	var player = AudioStreamPlayer.new()
	player.stream = stream
	# Convert linear volume scale (0-1) to dB. Apply master volume later if using buses.
	var final_volume = entry.default_volume * volume_scale
	player.volume_db = linear_to_db(clamp(final_volume, 0.0, 1.0)) if final_volume > 0.0 else -80.0

	_sound_players_node.add_child(player)

	var handle = _generate_handle()
	_active_sounds[handle] = { "node": player, "sound_id_name": sound_id_name }
	_active_sound_counts[sound_id_name] = _active_sound_counts.get(sound_id_name, 0) + 1

	# Connect finished signal with necessary parameters
	player.connect("finished", Callable(self, "_on_sound_finished").bind(player, handle, sound_id_name), CONNECT_ONE_SHOT)

	player.play()
	# print("Playing 2D sound: ", sound_id_name, " with handle: ", handle)
	return handle

# Note: Changed priority parameter type hint to SoundPriority
func play_sound_3d(sound_id_name: String, p_position: Vector3, p_velocity: Vector3 = Vector3.ZERO, volume_scale: float = 1.0, radius: float = 0.0, p_priority: SoundPriority = SoundPriority.DEFAULT) -> int:
	"""Plays a 3D positional sound effect. Corresponds to snd_play_3d."""
	var entry = _get_sound_entry(sound_id_name)
	if not entry: return -1
	# Use the enum value for priority check
	if not _can_play_sound(entry): return -1 # Check instance limits

	var stream = entry.get_stream()
	if not stream:
		printerr("SoundManager: Failed to get stream for 3D sound: ", sound_id_name)
		return -1

	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.global_position = p_position
	# Velocity is not directly settable on AudioStreamPlayer3D for Doppler.
	# Doppler effect is controlled by doppler_tracking property and listener/source movement.
	# We might need custom Doppler logic if Godot's built-in isn't sufficient.
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED # Or PHYSICS_PROCESS if needed

	# Convert linear volume scale (0-1) to dB.
	var final_volume = entry.default_volume * volume_scale
	player.volume_db = linear_to_db(clamp(final_volume, 0.0, 1.0)) if final_volume > 0.0 else -80.0

	# Set attenuation based on min/max distances.
	# unit_size roughly corresponds to the distance where volume is halved (with inverse distance model).
	# Setting it based on max_distance provides a starting point. Fine-tuning might be needed.
	# Godot uses AttenuationModel enum: INVERSE_DISTANCE, INVERSE_SQUARE_DISTANCE, LOGARITHMIC, DISABLED
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE # Common choice
	player.unit_size = entry.max_distance # Adjust this based on testing how attenuation feels
	# Godot doesn't have a direct 'min_distance' where volume is max.
	# The curve starts attenuating immediately from the source.
	# If min_distance behavior is critical, a custom attenuation curve resource might be needed.

	_sound_players_node.add_child(player)

	var handle = _generate_handle()
	_active_sounds[handle] = { "node": player, "sound_id_name": sound_id_name }
	_active_sound_counts[sound_id_name] = _active_sound_counts.get(sound_id_name, 0) + 1

	# Connect finished signal with necessary parameters
	player.connect("finished", Callable(self, "_on_sound_finished").bind(player, handle, sound_id_name), CONNECT_ONE_SHOT)

	player.play()
	# print("Playing 3D sound: ", sound_id_name, " at ", p_position, " with handle: ", handle)
	return handle


func stop_sound(handle: int):
	"""Stops a specific sound instance by its handle. Corresponds to snd_stop."""
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
			_active_sounds.erase(handle)
			if _active_sound_counts.has(sound_id_name):
				_active_sound_counts[sound_id_name] -= 1
				if _active_sound_counts[sound_id_name] <= 0:
					_active_sound_counts.erase(sound_id_name)
	else:
		# print("SoundManager: Attempted to stop sound with invalid handle: ", handle)
		pass

func stop_all_sounds():
	"""Stops all currently playing sound effects."""
	# TODO: Iterate through _active_sounds.
	# TODO: Call stop() on each player node.
	# TODO: Clear _active_sounds and _active_sound_counts.
	# TODO: Consider freeing nodes immediately or letting _on_sound_finished handle it.
	for player in _sound_players_node.get_children():
		if player is AudioStreamPlayer or player is AudioStreamPlayer3D:
			player.stop()
			# Let the finished signal handle cleanup naturally if possible,
			# otherwise, queue_free here and manage dictionaries.
	_active_sounds.clear()
	_active_sound_counts.clear()


func set_master_volume(volume: float):
	"""Sets the master volume for sound effects."""
	# TODO: Adjust the volume of the 'SFX' audio bus.
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(clamp(volume, 0.0, 1.0)))
	pass

# Note: Added type hints for clarity
func _on_sound_finished(player_node: Node, handle: int, sound_id_name: String):
	"""Callback function connected to the 'finished' signal of sound players."""
	# print("Sound finished: ", sound_id_name, " Handle: ", handle)
	# Remove the player node from tracking
	if _active_sounds.has(handle):
		_active_sounds.erase(handle)

	# Decrement the count for this sound ID
	if _active_sound_counts.has(sound_id_name):
		_active_sound_counts[sound_id_name] -= 1
		if _active_sound_counts[sound_id_name] <= 0:
			_active_sound_counts.erase(sound_id_name)
			# print("Removed count for: ", sound_id_name)
		#else:
			# print("Decremented count for: ", sound_id_name, " to ", _active_sound_counts[sound_id_name])

	# Free the node itself
	if is_instance_valid(player_node):
		player_node.queue_free()

# --- Helper Functions ---
func _get_sound_entry(sound_id_name: String) -> SoundEntry:
	"""Retrieves a SoundEntry from the GameSounds autoload."""
	if GameSounds:
		return GameSounds.get_sound_entry(sound_id_name)
	else:
		printerr("SoundManager: GameSounds not available!")
		return null

func _can_play_sound(sound_entry: SoundEntry) -> bool:
	"""Checks if a sound can be played based on instance limits."""
	if not sound_entry: return false

	var current_count = _active_sound_counts.get(sound_entry.id_name, 0)
	# Assuming SoundEntry.priority maps to SoundPriority enum values
	var limit = _get_limit_for_priority(sound_entry.priority)

	if current_count >= limit:
		# TODO: Implement logic to potentially stop the oldest/lowest priority sound
		# if the new sound has MUST_PLAY priority. For now, just deny.
		# print("SoundManager: Limit reached for sound: ", sound_entry.id_name)
		return false

	return true

# Note: The parameter type hint needs to be SoundPriority after the enum is defined.
# This block assumes the enum definition block above was applied successfully.
func _get_limit_for_priority(priority: SoundPriority) -> int:
	"""Maps SoundPriority enum to instance limits."""
	match priority:
		SoundPriority.SINGLE_INSTANCE: return 1
		SoundPriority.DOUBLE_INSTANCE: return 2
		SoundPriority.TRIPLE_INSTANCE: return 3
		_: return 99 # Effectively no limit for MUST_PLAY or others

func _generate_handle() -> int:
	"""Generates a unique handle for a sound instance."""
	_next_handle += 1
	# Wrap around if necessary, though unlikely to collide soon.
	if _next_handle <= 0:
		_next_handle = 1
	return _next_handle
