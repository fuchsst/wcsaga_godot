@tool
extends BaseTblConverter # Inherit from the new base class
# Converts music.tbl into an intermediate Godot resource (music_tracks.tres)
# containing a dictionary mapping soundtrack names to their pattern data.

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const MusicEntry = preload("res://scripts/resources/game_data/music_entry.gd") # Assuming this exists

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/music.tbl" # Adjust if needed
# Output an intermediate resource containing the parsed table data
const OUTPUT_RES_PATH = "res://resources/game_data/music_tracks.tres"

# Mapping from TBL pattern names to enum values
const PATTERN_NAME_TO_ENUM: Dictionary = {
	"Normal 1": MusicEntry.MusicPattern.NRML_1,
	"Normal 2": MusicEntry.MusicPattern.NRML_2,
	"Normal 3": MusicEntry.MusicPattern.NRML_3,
	"Ally arrival 1": MusicEntry.MusicPattern.AARV_1,
	"Ally arrival 2": MusicEntry.MusicPattern.AARV_2,
	"Enemy arrival 1": MusicEntry.MusicPattern.EARV_1,
	"Enemy arrival 2": MusicEntry.MusicPattern.EARV_2,
	"Battle 1": MusicEntry.MusicPattern.BTTL_1,
	"Battle 2": MusicEntry.MusicPattern.BTTL_2,
	"Battle 3": MusicEntry.MusicPattern.BTTL_3,
	"Failure 1": MusicEntry.MusicPattern.FAIL_1,
	"Victory 1": MusicEntry.MusicPattern.VICT_1,
	"Victory 2": MusicEntry.MusicPattern.VICT_2,
	"Dead 1": MusicEntry.MusicPattern.DEAD_1,
}

# --- Soundtrack Flags (Mirroring eventmusic.h - EMF_*) ---
const EMF_FLAG_MAP: Dictionary = {
	"Cycle FS1": 1 << 2, # EMF_CYCLE_FS1
	"Allied Arrival Overlay": 1 << 1, # EMF_ALLIED_ARRIVAL_OVERLAY
	"Lock in Ambient": 1 << 3, # EMF_LOCK_IN_NORMAL
}

# --- Main Execution ---
func _run():
	print("Converting music.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	# Structure: { "SoundtrackName": {"flags": int, "patterns": {MusicPattern: MusicEntry, ...}}, ... }
	var soundtracks_data: Dictionary = {}
	var current_line_num_ref = [0] # Use array as reference
	var current_soundtrack_name = ""
	var current_soundtrack_dict = {}

	# --- Parsing Logic ---
	while not file.eof_reached():
		var line = _peek_line(file)

		# Skip comments and empty lines using inherited helper
		if line == null or line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_read_line(file, current_line_num_ref) # Consume the line
			continue

		# Handle section markers
		if line.begins_with("#"):
			_read_line(file, current_line_num_ref) # Consume the section line
			if line == "#Soundtrack Definitions":
				print("  Parsing #Soundtrack Definitions section...")
			elif line == "#Menu Music":
				print("  Skipping #Menu Music section (handled separately or ignored)...")
				# Skip until next section or EOF
				while true:
					var skip_line = _peek_line(file)
					if skip_line == null or skip_line.begins_with("#"): break
					_read_line(file, current_line_num_ref)
				continue # Go to next iteration of main loop
			elif line == "#End":
				print("  Reached #End.")
				break # Stop parsing
			else:
				printerr(f"Warning: Unexpected section '{line}' at line {current_line_num_ref[0]}. Skipping.")
			continue

		# Handle key-value pairs
		if line.begins_with("$"):
			var parts = line.split(":", false, 1)
			if parts.size() != 2:
				printerr(f"Warning: Malformed line '{line}' at line {current_line_num_ref[0]}. Skipping.")
				_read_line(file, current_line_num_ref) # Consume the bad line
				continue

			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			_read_line(file, current_line_num_ref) # Consume the key-value line

			# --- Soundtrack Start ---
			if key == "$SoundTrack Name":
				# Store previous soundtrack if one was being built
				if not current_soundtrack_name.is_empty():
					soundtracks_data[current_soundtrack_name] = current_soundtrack_dict

				# Start new soundtrack entry
				current_soundtrack_name = value
				current_soundtrack_dict = {
					"flags": 0,
					"patterns": {} # Dictionary to hold MusicEntry resources keyed by MusicPattern enum
				}
				print(f"    Parsing Soundtrack: {current_soundtrack_name}")

			# --- Soundtrack Fields ---
			elif key == "+Cycle":
				if current_soundtrack_name.is_empty(): printerr(f"Error: Found {key} outside a Soundtrack definition at line {current_line_num_ref[0]}"); continue
				if value.to_lower() == "fs1":
					current_soundtrack_dict["flags"] |= EMF_FLAG_MAP["Cycle FS1"]
			elif key == "+Allied Arrival Overlay":
				if current_soundtrack_name.is_empty(): printerr(f"Error: Found {key} outside a Soundtrack definition at line {current_line_num_ref[0]}"); continue
				if TblParserUtils.parse_bool(value):
					current_soundtrack_dict["flags"] |= EMF_FLAG_MAP["Allied Arrival Overlay"]
			elif key == "+Lock in Ambient":
				if current_soundtrack_name.is_empty(): printerr(f"Error: Found {key} outside a Soundtrack definition at line {current_line_num_ref[0]}"); continue
				if TblParserUtils.parse_bool(value):
					current_soundtrack_dict["flags"] |= EMF_FLAG_MAP["Lock in Ambient"]

			# --- Pattern Definition ---
			elif key == "$Name": # This indicates a pattern within the current soundtrack
				if current_soundtrack_name.is_empty(): printerr(f"Error: Found $Name outside a Soundtrack definition at line {current_line_num_ref[0]}"); continue

				var pattern_name = value
				if not PATTERN_NAME_TO_ENUM.has(pattern_name):
					printerr(f"Warning: Unknown music pattern name '{pattern_name}' at line {current_line_num_ref[0]}. Skipping.")
					# Skip the associated data line
					_read_line(file, current_line_num_ref)
					continue

				var pattern_enum = PATTERN_NAME_TO_ENUM[pattern_name]
				var data_line = _read_line(file, current_line_num_ref) # Read the data line associated with $Name
				if data_line == null:
					printerr(f"Error: Missing data line after $Name: {pattern_name} at line {current_line_num_ref[0]}")
					continue

				var data_parts = data_line.split(",", false)
				if data_parts.size() < 3:
					printerr(f"Warning: Malformed data line '{data_line}' for pattern '{pattern_name}' at line {current_line_num_ref[0]}. Skipping.")
					continue

				var music_entry = MusicEntry.new()
				music_entry.filename = data_parts[0].strip_edges()
				music_entry.num_measures = TblParserUtils.parse_float(data_parts[1].strip_edges())
				music_entry.samples_per_measure = TblParserUtils.parse_int(data_parts[2].strip_edges())

				current_soundtrack_dict["patterns"][pattern_enum] = music_entry
				print(f"      Added Pattern: {pattern_name} -> {music_entry.filename}")

			else:
				# Ignore other keys within a soundtrack definition for now
				pass
		else:
			# Ignore lines not starting with # or $
			_read_line(file, current_line_num_ref) # Consume the line
			pass

	# Add the very last parsed soundtrack entry
	if not current_soundtrack_name.is_empty():
		soundtracks_data[current_soundtrack_name] = current_soundtrack_dict

	file.close()

	# --- Save Resource ---
	# Wrap the dictionary in a generic Resource for saving
	var resource_to_save = Resource.new()
	# Optionally assign a script if you create one for this intermediate data
	# resource_to_save.set_script(preload("res://path/to/music_tracks_data.gd"))
	resource_to_save.set_meta("soundtracks", soundtracks_data) # Store data in meta

	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_PATH.get_base_dir())
	var save_result = ResourceSaver.save(resource_to_save, OUTPUT_RES_PATH, save_flags)

	if save_result != OK:
		printerr(f"Error saving resource '{OUTPUT_RES_PATH}': {save_result}")
	else:
		print(f"Successfully converted music.tbl data to {OUTPUT_RES_PATH}")
