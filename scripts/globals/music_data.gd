# scripts/globals/music_data.gd
extends Node
# Autoload Singleton for accessing MusicEntry definitions.

# Path to the main MusicTracks resource file (likely a Dictionary mapping soundtrack names to Dictionaries of MusicEntry).
const MUSIC_TRACKS_RESOURCE_PATH = "res://resources/game_data/music_tracks.tres"

# Dictionary storing soundtrack data. Structure: { "SoundtrackName": { MusicEntry.MusicPattern: MusicEntry, ... }, ... }
# May also include flags per soundtrack, e.g., { "SoundtrackName": { "flags": int, "patterns": { ... } } }
var soundtracks: Dictionary = {}

func _ready():
	_load_music_tracks()

func _load_music_tracks():
	"""Loads the main MusicTracks resource file."""
	var resource = load(MUSIC_TRACKS_RESOURCE_PATH)
	if resource is Dictionary:
		soundtracks = resource
		print("MusicData: Loaded %d soundtracks." % soundtracks.size())
		# Optional: Validate loaded data structure here
	elif resource != null:
		printerr("MusicData: Failed to load! Resource is not a Dictionary: ", MUSIC_TRACKS_RESOURCE_PATH)
	else:
		printerr("MusicData: Failed to load music tracks resource: ", MUSIC_TRACKS_RESOURCE_PATH)

func get_soundtrack_data(soundtrack_name: String) -> Dictionary:
	"""Returns the dictionary of MusicEntry resources for a given soundtrack name."""
	if soundtracks.has(soundtrack_name):
		# Adjust if flags are stored separately
		if soundtracks[soundtrack_name].has("patterns"):
			return soundtracks[soundtrack_name]["patterns"]
		else:
			return soundtracks[soundtrack_name] # Assume direct pattern dictionary
	else:
		printerr("MusicData: Soundtrack not found: ", soundtrack_name)
		return {}

func get_entry(pattern_type: MusicEntry.MusicPattern, soundtrack_name: String = "") -> MusicEntry:
	"""
	Returns the MusicEntry for a specific pattern type within a soundtrack.
	If soundtrack_name is empty, it attempts to use the currently loaded one (requires MusicManager interaction or global state).
	"""
	var target_soundtrack_name = soundtrack_name
	if target_soundtrack_name == "":
		# TODO: Need a way to know the current soundtrack. Get from MusicManager?
		# This might be better handled within MusicManager itself, passing MusicData as a dependency.
		printerr("MusicData: get_entry called without specifying soundtrack_name!")
		return null # Or try a default?

	var soundtrack_patterns = get_soundtrack_data(target_soundtrack_name)
	if soundtrack_patterns.has(pattern_type):
		# Ensure the value retrieved is actually a MusicEntry resource
		var entry = soundtrack_patterns[pattern_type]
		if entry is MusicEntry:
			return entry
		else:
			printerr("MusicData: Entry for pattern %s in soundtrack %s is not a MusicEntry resource!" % [MusicEntry.MusicPattern.keys()[pattern_type], target_soundtrack_name])
			return null
	else:
		# printerr("MusicData: Pattern %s not found in soundtrack %s" % [MusicEntry.MusicPattern.keys()[pattern_type], target_soundtrack_name])
		# Don't spam errors if a pattern simply doesn't exist for a soundtrack
		return null

func get_soundtrack_flags(soundtrack_name: String) -> int:
	"""Returns the flags associated with a specific soundtrack."""
	# Assumes flags are stored at the top level of the soundtrack dictionary.
	if soundtracks.has(soundtrack_name) and soundtracks[soundtrack_name].has("flags"):
		var flags = soundtracks[soundtrack_name]["flags"]
		if typeof(flags) == TYPE_INT:
			return flags
		else:
			printerr("MusicData: Flags for soundtrack %s are not an integer!" % soundtrack_name)
			return 0
	else:
		# printerr("MusicData: Flags not found for soundtrack: ", soundtrack_name)
		return 0 # Default flags (no flags set)

# Optional: Add functions to get lists of soundtracks, etc.
