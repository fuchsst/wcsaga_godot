@tool # Allows running from editor/command line
extends EditorScript

# Updates GameSounds.tres and MusicTracks.tres based on converted table data
# and audio files found in the assets directory.

# --- Configuration ---
const CONVERTED_SOUND_DIR = "res://assets/sounds"
const CONVERTED_MUSIC_DIR = "res://assets/music"
const CONVERTED_VOICE_DIR = "res://assets/voices"
# TODO: Define path to converted sounds.tbl and music.tbl data (e.g., JSON or TRES)
const SOUND_TABLE_DATA_PATH = "res://resources/game_data/sounds_table_data.tres" # Placeholder
const MUSIC_TABLE_DATA_PATH = "res://resources/game_data/music_table_data.tres" # Placeholder

const OUTPUT_GAME_SOUNDS_RES = "res://resources/game_data/game_sounds.tres"
const OUTPUT_MUSIC_TRACKS_RES = "res://resources/game_data/music_tracks.tres"

# Preload necessary resource scripts/classes
const GameSounds = preload("res://scripts/resources/game_data/game_sounds.gd")
const SoundEntry = preload("res://scripts/resources/game_data/sound_entry.gd")
const MusicTracks = preload("res://scripts/resources/game_data/music_tracks.gd") # Assuming this exists
const MusicEntry = preload("res://scripts/resources/game_data/music_entry.gd")

var force_overwrite: bool = false # Might not be needed if we're updating existing resources

# --- Main Execution ---
func _run():
	print("Updating Audio Resources (GameSounds, MusicTracks)...")
	var args = OS.get_cmdline_args()
	# Force overwrite might mean rebuilding from scratch vs updating
	# if "--force" in args:
	#	force_overwrite = true
	#	print("  Force overwrite enabled.")

	var sounds_updated = _update_game_sounds()
	var music_updated = _update_music_tracks()

	if sounds_updated and music_updated:
		print("Audio Resource update finished successfully.")
	else:
		printerr("Audio Resource update finished with errors.")


func _update_game_sounds() -> bool:
	print("  Updating GameSounds resource...")
	var success = true

	# 1. Load converted sounds.tbl data
	# TODO: Implement loading logic based on actual converted format (JSON/TRES)
	# Example placeholder:
	var sound_table_data = _load_sound_table_data(SOUND_TABLE_DATA_PATH)
	if sound_table_data == null:
		printerr(f"Error: Could not load sound table data from {SOUND_TABLE_DATA_PATH}")
		return false
	print(f"    Loaded {sound_table_data.size()} sound definitions from table data.")

	# 2. Load or create the main GameSounds resource
	var game_sounds_res: GameSounds
	if ResourceLoader.exists(OUTPUT_GAME_SOUNDS_RES):
		game_sounds_res = load(OUTPUT_GAME_SOUNDS_RES)
		if not game_sounds_res is GameSounds:
			printerr(f"Error: Existing resource at {OUTPUT_GAME_SOUNDS_RES} is not a GameSounds resource. Creating new.")
			game_sounds_res = GameSounds.new()
	else:
		game_sounds_res = GameSounds.new()

	# Ensure the dictionary exists
	if game_sounds_res.sound_entries == null:
		game_sounds_res.sound_entries = {}

	# 3. Iterate through table data and update/add entries
	var updated_count = 0
	var added_count = 0
	var error_count = 0

	for sound_id_name in sound_table_data:
		var entry_data: Dictionary = sound_table_data[sound_id_name]
		var filename = entry_data.get("filename", "")
		if filename.is_empty() or filename.to_lower() == "none.wav":
			# Remove existing entry if filename is none, or just skip
			if game_sounds_res.sound_entries.has(sound_id_name):
				game_sounds_res.sound_entries.erase(sound_id_name)
				print(f"      Removed sound entry '{sound_id_name}' due to 'none' filename.")
			continue

		# Find the corresponding audio file in assets (check sounds and voices)
		var audio_path = _find_audio_file(filename, [CONVERTED_SOUND_DIR, CONVERTED_VOICE_DIR])
		if audio_path.is_empty():
			printerr(f"Error: Audio file '{filename}' not found for sound '{sound_id_name}' in {CONVERTED_SOUND_DIR} or {CONVERTED_VOICE_DIR}")
			error_count += 1
			continue

		# Get or create the SoundEntry resource
		var sound_entry: SoundEntry
		if game_sounds_res.sound_entries.has(sound_id_name):
			sound_entry = game_sounds_res.sound_entries[sound_id_name]
			if not sound_entry is SoundEntry: # Check if it's the correct type
				printerr(f"Warning: Existing entry for '{sound_id_name}' is not a SoundEntry. Replacing.")
				sound_entry = SoundEntry.new()
			updated_count += 1
		else:
			sound_entry = SoundEntry.new()
			added_count += 1

		# Populate the SoundEntry
		sound_entry.id_name = sound_id_name # Ensure name is set
		sound_entry.audio_stream_path = audio_path
		sound_entry.default_volume = entry_data.get("volume", 1.0)
		sound_entry.min_distance = entry_data.get("min_dist", 0.0) # Assuming keys from table data
		sound_entry.max_distance = entry_data.get("max_dist", 1000.0) # Assuming keys from table data
		sound_entry.preload = entry_data.get("preload", false)
		sound_entry.original_sig = entry_data.get("signature", -1) # Store original signature if available
		# TODO: Add flags if needed (e.g., GAME_SND_USE_DS3D)

		# Store it back in the dictionary
		game_sounds_res.sound_entries[sound_id_name] = sound_entry

	# 4. Save the updated resource
	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	var save_result = ResourceSaver.save(game_sounds_res, OUTPUT_GAME_SOUNDS_RES, save_flags)
	if save_result != OK:
		printerr(f"Error saving GameSounds resource '{OUTPUT_GAME_SOUNDS_RES}': {save_result}")
		success = false
	else:
		print(f"  Finished updating GameSounds. Added: {added_count}, Updated: {updated_count}, Errors: {error_count}.")

	return success


func _update_music_tracks() -> bool:
	print("  Updating MusicTracks resource...")
	var success = true

	# TODO: Implement logic similar to _update_game_sounds()
	# 1. Load converted music.tbl data
	# 2. Load or create MusicTracks.tres
	# 3. Iterate through table data:
	#    - Find corresponding .ogg in CONVERTED_MUSIC_DIR
	#    - Create/Update MusicEntry resource
	#    - Set audio_stream_path, loop points, etc.
	#    - Add/Update entry in the main resource's dictionary/array
	# 4. Save the updated MusicTracks.tres
	print("  MusicTracks update NOT YET IMPLEMENTED.")
	return true # Placeholder


func _load_sound_table_data(path: String) -> Dictionary:
	# Placeholder: Load data from the converted sounds.tbl
	# This should return a dictionary like:
	# { "SND_LASER_FIRE": {"filename": "laser01.ogg", "volume": 0.8, ...}, ... }
	printerr(f"Warning: Sound table data loading from {path} is not implemented. Returning empty data.")
	# Example structure:
	# var data = {
	# 	"SND_LASER_FIRE": {"filename": "laser01.ogg", "volume": 0.8, "min_dist": 10.0, "max_dist": 500.0, "preload": true, "signature": 76},
	# 	"SND_MISSILE_LAUNCH": {"filename": "mlsl01.ogg", "volume": 1.0, "min_dist": 50.0, "max_dist": 2000.0, "preload": false, "signature": 87}
	# }
	# return data
	return {}


func _find_audio_file(base_filename: String, search_dirs: Array[String]) -> String:
	"""Searches for the audio file (likely .ogg) in the specified asset directories."""
	var base_name = base_filename.get_basename().get_slice(".", 0) # Remove extension
	var target_filename = base_name + ".ogg" # Assume target is OGG

	for search_dir in search_dirs:
		var full_path = search_dir.path_join(target_filename)
		if FileAccess.file_exists(full_path):
			return full_path
		# Maybe check subdirs if structure is nested?
		# var dir = DirAccess.open(search_dir)
		# if dir:
		#     if dir.file_exists(target_filename):
		#         return search_dir.path_join(target_filename)
		#     # Recursive search could be added here if needed
		# else:
		#     printerr(f"Warning: Could not open search directory {search_dir}")

	return "" # Not found
