@tool
extends BaseTblConverter
# Converts species_defs.tbl into individual Godot SpeciesInfo resources (.tres).

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const SpeciesInfo = preload("res://scripts/resources/game_data/species_info.gd")

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/species_defs.tbl" # Adjust if needed
const OUTPUT_RES_DIR = "res://resources/game_data/species" # Output dir for .tres files

# --- Main Execution ---
func _run():
	print("Converting species_defs.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_DIR)

	var current_line_num_ref = [0] # Use array as reference
	var processed_count = 0
	var error_count = 0

	# --- Parsing Logic ---
	# Skip header lines until #Species section
	if not _skip_to_token(file, current_line_num_ref, "#Species"):
		printerr("Error: '#Species' marker not found in species_defs.tbl")
		file.close()
		return

	print("  Parsing #Species section...")

	# Loop through each species definition
	while not file.eof_reached():
		var line = _peek_line(file) # Peek first

		# Stop at end marker
		if line != null and line.begins_with("#End"):
			print("  Reached #End.")
			break

		# Find the start of the next species
		if line == null or not line.begins_with("$Name:"):
			_read_line(file, current_line_num_ref) # Consume the non-starting line
			continue

		# Parse the species
		var species_data: SpeciesInfo = _parse_single_species(file, current_line_num_ref)
		if species_data:
			# Save the resource
			var output_path = OUTPUT_RES_DIR.path_join(species_data.species_name.to_lower().replace(" ", "_") + ".tres")
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var save_result = ResourceSaver.save(species_data, output_path, save_flags)
			if save_result != OK:
				printerr(f"Error saving SpeciesInfo resource '{output_path}': {save_result}")
				error_count += 1
			else:
				processed_count += 1
				print(f"    Saved: {output_path}")
		else:
			printerr(f"Failed to parse species definition starting near line {current_line_num_ref[0]}.")
			error_count += 1
			# Attempt to recover by skipping to the next potential species start
			_skip_to_next_section_or_token(file, current_line_num_ref, "$Name:")

	file.close()
	print(f"Finished converting species_defs.tbl. Processed: {processed_count}, Errors: {error_count}.")


# --- Species Parsing Helper ---
func _parse_single_species(file: FileAccess, current_line_num_ref: Variant) -> SpeciesInfo:
	"""Parses one $Name: block for a species definition."""
	var species_data = SpeciesInfo.new()

	# --- Required Basic Info ---
	var name_str = _parse_required_token(file, current_line_num_ref, "$Name:")
	if name_str == null: return null
	species_data.species_name = name_str.trim_prefix("+") # Handle potential '+' prefix
	print(f"    Parsing Species: {species_data.species_name}")

	# --- Optional Fields ---
	var flyby_fighter_str = _parse_optional_token(file, current_line_num_ref, "$Flyby Sound Fighter:")
	if flyby_fighter_str != null: species_data.flyby_sound_fighter_name = flyby_fighter_str

	var flyby_bomber_str = _parse_optional_token(file, current_line_num_ref, "$Flyby Sound Bomber:")
	if flyby_bomber_str != null: species_data.flyby_sound_bomber_name = flyby_bomber_str

	# Consume any remaining lines until the next $ or #
	while _peek_line(file) != null and not _peek_line(file).begins_with("$") and not _peek_line(file).begins_with("#"):
		_read_line(file, current_line_num_ref)

	return species_data
