# scripts/globals/game_sounds.gd
extends Node
# Autoload Singleton for accessing SoundEntry definitions.

# Path to the main GameSounds resource file (likely a Dictionary mapping IDs to SoundEntry resources).
const GAME_SOUNDS_RESOURCE_PATH = "res://resources/game_data/game_sounds.tres"

# Dictionary storing SoundEntry resources, keyed by their id_name (e.g., "SND_LASER_FIRE").
var sound_entries: Dictionary = {}

# Dictionary mapping original sound signatures (int) to id_name (String), if needed for compatibility.
var sig_to_id_map: Dictionary = {}

func _ready():
	_load_game_sounds()
	_preload_sounds()

func _load_game_sounds():
	"""Loads the main GameSounds resource file."""
	var resource = load(GAME_SOUNDS_RESOURCE_PATH)
	if resource is Dictionary:
		sound_entries = resource
		# Build the signature map if needed
		for id_name in sound_entries:
			var entry: SoundEntry = sound_entries[id_name]
			if entry and entry.original_sig != -1:
				sig_to_id_map[entry.original_sig] = id_name
		print("GameSounds: Loaded %d sound entries." % sound_entries.size())
	elif resource != null:
		printerr("GameSounds: Failed to load! Resource is not a Dictionary: ", GAME_SOUNDS_RESOURCE_PATH)
	else:
		printerr("GameSounds: Failed to load game sounds resource: ", GAME_SOUNDS_RESOURCE_PATH)

func _preload_sounds():
	"""Preloads AudioStream resources for entries marked with preload = true."""
	var preload_count = 0
	for id_name in sound_entries:
		var entry: SoundEntry = sound_entries[id_name]
		if entry and entry.preload:
			if entry.get_stream() != null: # This triggers the lazy load
				preload_count += 1
			else:
				printerr("GameSounds: Failed to preload sound: ", entry.audio_stream_path)
	if preload_count > 0:
		print("GameSounds: Preloaded %d sounds." % preload_count)


func get_sound_entry(id_name: String) -> SoundEntry:
	"""Returns the SoundEntry resource for the given ID name."""
	if sound_entries.has(id_name):
		return sound_entries[id_name]
	else:
		printerr("GameSounds: Sound entry not found: ", id_name)
		return null

func get_sound_entry_by_sig(signature: int) -> SoundEntry:
	"""Returns the SoundEntry resource for the given original signature."""
	if sig_to_id_map.has(signature):
		var id_name = sig_to_id_map[signature]
		return get_sound_entry(id_name)
	else:
		printerr("GameSounds: Sound entry not found for signature: ", signature)
		return null

# Optional: Add functions to get lists of sounds, etc.
