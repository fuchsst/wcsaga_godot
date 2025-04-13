# scripts/globals/game_sounds.gd
extends Node
# Autoload Singleton for accessing SoundEntry and MusicEntry definitions.

# Path to the main GameSoundsData resource file.
const GAME_SOUNDS_DATA_RESOURCE_PATH = "res://resources/game_data/game_sounds_data.tres"

# Preload the resource definition script
const GameSoundsData = preload("res://scripts/resources/game_data/game_sounds.gd")
const SoundEntry = preload("res://scripts/resources/game_data/sound_entry.gd")
const MusicEntry = preload("res://scripts/resources/game_data/music_entry.gd")

# Holds the loaded GameSoundsData resource instance.
var _game_sounds_data: GameSoundsData = null

# Dictionary mapping original sound signatures (int) to id_name (String) for quick lookup.
var _sig_to_id_map: Dictionary = {}

func _ready():
	_load_game_sounds_data()
	_build_signature_map()
	_preload_sounds()

func _load_game_sounds_data():
	"""Loads the main GameSoundsData resource file."""
	if ResourceLoader.exists(GAME_SOUNDS_DATA_RESOURCE_PATH):
		_game_sounds_data = load(GAME_SOUNDS_DATA_RESOURCE_PATH)
		if _game_sounds_data is GameSoundsData:
			if _game_sounds_data.sound_entries == null: _game_sounds_data.sound_entries = {}
			if _game_sounds_data.music_entries == null: _game_sounds_data.music_entries = {}
			print("GameSounds Autoload: Loaded %d sound entries and %d music entries." % [_game_sounds_data.sound_entries.size(), _game_sounds_data.music_entries.size()])
		else:
			printerr("GameSounds Autoload: Failed to load! Resource is not a GameSoundsData: ", GAME_SOUNDS_DATA_RESOURCE_PATH)
			_game_sounds_data = null # Ensure it's null if load failed
	else:
		printerr("GameSounds Autoload: Failed to load game sounds data resource, file not found: ", GAME_SOUNDS_DATA_RESOURCE_PATH)

func _build_signature_map():
	"""Builds the map from original signature to ID name."""
	_sig_to_id_map.clear()
	if _game_sounds_data == null or _game_sounds_data.sound_entries == null:
		return

	for id_name in _game_sounds_data.sound_entries:
		var entry: SoundEntry = _game_sounds_data.sound_entries[id_name]
		if entry and entry.original_sig != -1:
			if _sig_to_id_map.has(entry.original_sig):
				printerr(f"GameSounds Autoload: Duplicate signature {entry.original_sig} found for '{id_name}' and '{_sig_to_id_map[entry.original_sig]}'. Using first encountered.")
			else:
				_sig_to_id_map[entry.original_sig] = id_name

func _preload_sounds():
	"""Preloads AudioStream resources for entries marked with preload = true."""
	if _game_sounds_data == null or _game_sounds_data.sound_entries == null:
		return

	var preload_count = 0
	for id_name in _game_sounds_data.sound_entries:
		var entry: SoundEntry = _game_sounds_data.sound_entries[id_name]
		if entry and entry.preload:
			if entry.get_stream() != null: # This triggers the lazy load
				preload_count += 1
			else:
				printerr("GameSounds Autoload: Failed to preload sound: ", entry.audio_stream_path)
	if preload_count > 0:
		print("GameSounds Autoload: Preloaded %d sounds." % preload_count)

func get_data_resource() -> GameSoundsData:
	"""Returns the loaded GameSoundsData resource instance."""
	return _game_sounds_data

func get_sound_entry(id_name: String) -> SoundEntry:
	"""Returns the SoundEntry resource for the given ID name."""
	if _game_sounds_data and _game_sounds_data.sound_entries.has(id_name):
		return _game_sounds_data.sound_entries[id_name]
	else:
		# Don't spam errors for potentially optional sounds
		# printerr("GameSounds Autoload: Sound entry not found: ", id_name)
		return null

func get_sound_entry_by_sig(signature: int) -> SoundEntry:
	"""Returns the SoundEntry resource for the given original signature."""
	if _sig_to_id_map.has(signature):
		var id_name = _sig_to_id_map[signature]
		return get_sound_entry(id_name)
	else:
		# printerr("GameSounds Autoload: Sound entry not found for signature: ", signature)
		return null

func get_music_entry(pattern_enum_value: int) -> MusicEntry:
	"""Returns the MusicEntry resource for the given pattern enum value."""
	# Assuming music_entries uses the enum value as key
	if _game_sounds_data and _game_sounds_data.music_entries.has(pattern_enum_value):
		return _game_sounds_data.music_entries[pattern_enum_value]
	else:
		# printerr("GameSounds Autoload: Music entry not found for pattern enum: ", pattern_enum_value)
		return null

# Optional: Add functions to get lists of sounds, etc.
