@tool
extends BaseTblConverter
# Converts sounds.tbl into a Godot GameSounds resource (game_sounds.tres)
# containing arrays of SoundEntry resources.

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const SoundEntry = preload("res://scripts/resources/game_data/sound_entry.gd")
const GameSounds = preload("res://scripts/resources/game_data/game_sounds.gd") # Load the target resource type

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/sounds.tbl" # Adjust if needed
const OUTPUT_RES_PATH = "res://resources/game_data/game_sounds.tres" # Output the typed resource

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
	var game_sounds_data = GameSounds.new()
	var current_line_num_ref = [0] # Use array as reference
	var current_section = "" # Track if we are in Game or Interface sounds
	var processed_count = 0
	var error_count = 0

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

			# Assign to the correct array based on the current section
			if current_section == "game":
				game_sounds_data.game_sounds.append(sound_entry)
			elif current_section == "interface":
				game_sounds_data.interface_sounds.append(sound_entry)
			else:
				printerr(f"Warning: Found sound definition '{sound_entry.id_name}' outside a known section at line {current_line_num_ref[0]}. Skipping.")
				continue

			print(f"    Parsed Sound: {sound_entry.id_name}")
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
		print(f"Successfully converted sounds.tbl to {OUTPUT_RES_PATH}")
