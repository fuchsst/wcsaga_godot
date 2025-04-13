@tool
extends BaseTblConverter
# Converts sounds.tbl into a Godot GameSoundsData resource (game_sounds_data.tres)
# containing a dictionary of SoundEntry resources keyed by ID name.
# It also attempts to find the corresponding .ogg file in the assets directory.

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const SoundEntry = preload("res://scripts/resources/game_data/sound_entry.gd")
const GameSoundsData = preload("res://scripts/resources/game_data/game_sounds.gd") # Load the target resource type (now GameSoundsData)

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/sounds.tbl" # Adjust if needed
const OUTPUT_RES_PATH = "res://resources/game_data/game_sounds_data.tres" # Output the typed resource
const CONVERTED_SOUND_DIR = "res://assets/sounds"
const CONVERTED_VOICE_DIR = "res://assets/voices"

# --- Flag Definitions (Placeholder - Define if sounds.tbl uses flags) ---
# const GAME_SND_FLAG_MAP: Dictionary = { ... }

# --- Main Execution ---
func _run():
	print("Converting sounds.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	# Create an instance of our custom resource type
	var game_sounds_data = GameSoundsData.new()
	# Ensure the dictionary exists
	if game_sounds_data.sound_entries == null:
		game_sounds_data.sound_entries = {}

	var current_line_num_ref = [0] # Use array as reference
	var current_section = "" # Track if we are in Game or Interface sounds
	var processed_count = 0
	var error_count = 0
	var missing_file_count = 0

	# --- Parsing Logic ---
	while not file.eof_reached():
		var line = _peek_line(file) # Use inherited helper

		# Skip comments and empty lines using inherited helper
		if line == null or line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_read_line(file, current_line_num_ref) # Consume the line
			continue

		# Handle section markers
		if line.begins_with("#"):
			_read_line(file, current_line_num_ref) # Consume the section line
			if line == "#Game Sounds Start":
				current_section = "game"
				print("  Parsing #Game Sounds Start section...")
			elif line == "#Interface Sounds Start":
				current_section = "interface"
				print("  Parsing #Interface Sounds Start section...")
			elif line == "#Game Sounds End" or line == "#Interface Sounds End":
				print(f"  Finished section: {line}")
				current_section = "" # Reset section
			elif line == "#End":
				print("  Reached #End.")
				break # Stop parsing
			else:
				# Skip other sections like #Flyby Sounds Start for now
				print(f"  Skipping section: {line}")
				while true:
					var skip_line = _peek_line(file)
					if skip_line == null or skip_line.begins_with("#"): break
					_read_line(file, current_line_num_ref)
			continue

		# Handle sound definition lines (starting with $Name:)
		if line.begins_with("$Name:"):
			_read_line(file, current_line_num_ref) # Consume the line
			# Format: $Name: <Sig>, <Filename>, <Preload>, <Volume>, <3D?>, <Min>, <Max>
			var parts = line.split(":", false, 1)
			if parts.size() != 2:
				printerr(f"Warning: Malformed line '{line}' at line {current_line_num_ref[0]}. Skipping.")
				continue

			var value_part = parts[1].strip_edges()
			var sound_def_parts = value_part.split(",", false)

			if sound_def_parts.size() < 7:
				printerr(f"Error: Incomplete $Name definition at line {current_line_num_ref[0]}: '{line}'")
				continue

			var sound_entry = SoundEntry.new()
			sound_entry.id_name = sound_def_parts[0].strip_edges() # This is the ID Name (e.g., SND_LASER_FIRE)
			sound_entry.original_sig = TblParserUtils.parse_int(sound_def_parts[0].strip_edges(), -1) # Store original sig if needed
			sound_entry.filename = sound_def_parts[1].strip_edges()
			sound_entry.preload = TblParserUtils.parse_bool(sound_def_parts[2])
			sound_entry.default_volume = TblParserUtils.parse_float(sound_def_parts[3], 1.0)
			var is_3d = TblParserUtils.parse_bool(sound_def_parts[4])
			sound_entry.min_distance = TblParserUtils.parse_float(sound_def_parts[5], 0.0)
			sound_entry.max_distance = TblParserUtils.parse_float(sound_def_parts[6], 1000.0)
			# TODO: Parse flags if they exist in the table format using TblParserUtils.parse_flags

			# Find the corresponding audio file path
			var audio_path = _find_audio_file(sound_entry.filename, [CONVERTED_SOUND_DIR, CONVERTED_VOICE_DIR])
			if audio_path.is_empty():
				printerr(f"Warning: Audio file '{sound_entry.filename}' not found for sound '{sound_entry.id_name}' in {CONVERTED_SOUND_DIR} or {CONVERTED_VOICE_DIR}")
				missing_file_count += 1
				# Optionally skip adding this entry if the file is missing
				# continue
			sound_entry.audio_stream_path = audio_path

			# Add to the dictionary using id_name as the key
			if game_sounds_data.sound_entries.has(sound_entry.id_name):
				printerr(f"Warning: Duplicate sound ID name '{sound_entry.id_name}' found at line {current_line_num_ref[0]}. Overwriting previous entry.")
				error_count += 1
			game_sounds_data.sound_entries[sound_entry.id_name] = sound_entry

			# print(f"    Parsed Sound: {sound_entry.id_name} -> {audio_path if not audio_path.is_empty() else 'MISSING FILE'}")
			processed_count += 1

		else:
			# Ignore other lines within sections
			_read_line(file, current_line_num_ref) # Consume the line
			pass

	file.close()

	# --- Save Resource ---
	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_PATH.get_base_dir())
	var save_result = ResourceSaver.save(game_sounds_data, OUTPUT_RES_PATH, save_flags)

	if save_result != OK:
		printerr(f"Error saving resource '{OUTPUT_RES_PATH}': {save_result}")
	else:
		print(f"Successfully converted sounds.tbl to {OUTPUT_RES_PATH}. Processed: {processed_count}, Missing Files: {missing_file_count}, Errors/Duplicates: {error_count}")


# --- Helper Functions ---
# Inherited: _read_line, _peek_line

func _find_audio_file(base_filename: String, search_dirs: Array[String]) -> String:
	"""Searches for the audio file (likely .ogg) in the specified asset directories."""
	if base_filename.is_empty() or base_filename.to_lower() == "none.wav":
		return ""

	var base_name = base_filename.get_basename().get_slice(".", 0) # Remove extension
	var target_filename = base_name + ".ogg" # Assume target is OGG

	for search_dir in search_dirs:
		var full_path = search_dir.path_join(target_filename)
		if FileAccess.file_exists(full_path):
			return full_path
		# Check subdirectories (simple one level deep check)
		var dir = DirAccess.open(search_dir)
		if dir:
			dir.list_dir_begin()
			var item = dir.get_next()
			while item != "":
				if dir.current_is_dir() and item != "." and item != "..":
					var sub_path = search_dir.path_join(item).path_join(target_filename)
					if FileAccess.file_exists(sub_path):
						dir.list_dir_end()
						return sub_path
				item = dir.get_next()
			dir.list_dir_end()
		# else:
			# printerr(f"Warning: Could not open search directory {search_dir}")

	return "" # Not found
