@tool
extends BaseTblConverter
# Converts cutscenes.tbl into an intermediate Godot resource (cutscenes_table_data.tres)
# containing a dictionary mapping cutscene IDs to filenames.

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/cutscenes.tbl" # Adjust if needed
# Output an intermediate resource containing the parsed table data
const OUTPUT_RES_PATH = "res://resources/game_data/cutscenes_table_data.tres"

# --- Main Execution ---
func _run():
	print("Converting cutscenes.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	# Use a plain Dictionary to store the parsed data
	# Structure: { "CutsceneIDName": {"filename": "file.mve", "name": "Display Name", "description": "...", "cd": 1}, ... }
	var cutscenes_data: Dictionary = {}
	var current_line_num_ref = [0] # Use array as reference
	var current_cutscene_id = ""
	var current_cutscene_dict = {}

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
			if line == "#Cutscenes":
				print("  Parsing #Cutscenes section...")
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

			# --- Cutscene Entry Start/Fields ---
			if key == "$Filename":
				# Store previous entry if one was being built
				if not current_cutscene_id.is_empty():
					cutscenes_data[current_cutscene_id] = current_cutscene_dict

				# Start new entry (Filename marks the start)
				current_cutscene_id = "" # Reset ID until $Name is found
				current_cutscene_dict = {
					"filename": value,
					"name": "", # Will be filled by $Name
					"description": "", # Will be filled by $Description
					"cd": 1 # Default CD
				}
				print(f"    Found Filename: {value}")

			elif key == "$Name":
				if not current_cutscene_dict.has("filename"): # Check if we started an entry
					printerr(f"Error: Found $Name before $Filename at line {current_line_num_ref[0]}")
					continue
				current_cutscene_id = value # Use the $Name as the ID key
				current_cutscene_dict["name"] = value
				print(f"      ID/Name: {value}")

			elif key == "$Description":
				if not current_cutscene_dict.has("filename"): continue
				# Read multi-line description using inherited helper
				current_cutscene_dict["description"] = _parse_multitext(file, current_line_num_ref)

			elif key == "$cd":
				if not current_cutscene_dict.has("filename"): continue
				current_cutscene_dict["cd"] = TblParserUtils.parse_int(value, 1)

			else:
				# Ignore other keys for cutscenes.tbl
				pass
		else:
			# Ignore other lines
			_read_line(file, current_line_num_ref) # Consume the line
			pass

	# Add the very last parsed cutscene entry
	if not current_cutscene_id.is_empty() and current_cutscene_dict.has("filename"):
		cutscenes_data[current_cutscene_id] = current_cutscene_dict

	file.close()

	# --- Save Resource ---
	# Wrap the dictionary in a generic Resource for saving
	var resource_to_save = Resource.new()
	# Optionally assign a script if you create one for this intermediate data
	# resource_to_save.set_script(preload("res://path/to/cutscene_table_data.gd"))
	resource_to_save.set_meta("cutscene_data", cutscenes_data) # Store data in meta

	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_PATH.get_base_dir())
	var save_result = ResourceSaver.save(resource_to_save, OUTPUT_RES_PATH, save_flags)

	if save_result != OK:
		printerr(f"Error saving resource '{OUTPUT_RES_PATH}': {save_result}")
	else:
		print(f"Successfully converted cutscenes.tbl data to {OUTPUT_RES_PATH}")

