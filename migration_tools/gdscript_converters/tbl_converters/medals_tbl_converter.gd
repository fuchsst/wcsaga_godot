@tool
extends BaseTblConverter
# Converts medals.tbl into individual Godot MedalInfo resources (.tres).

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const MedalInfo = preload("res://scripts/resources/player/medal_info.gd")

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/medals.tbl" # Adjust if needed
const OUTPUT_RES_DIR = "res://resources/medals" # Output dir for .tres files

# --- Main Execution ---
func _run():
	print("Converting medals.tbl...")

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
	# Skip header lines until #Medals section
	if not _skip_to_token(file, current_line_num_ref, "#Medals"):
		printerr("Error: '#Medals' marker not found in medals.tbl")
		file.close()
		return

	print("  Parsing #Medals section...")

	# Loop through each medal definition
	while not file.eof_reached():
		var line = _peek_line(file) # Peek first

		# Stop at end marker
		if line != null and line.begins_with("#End"):
			print("  Reached #End.")
			break

		# Find the start of the next medal
		if line == null or not line.begins_with("$Name:"):
			_read_line(file, current_line_num_ref) # Consume the non-starting line
			continue

		# Parse the medal
		var medal_data: MedalInfo = _parse_single_medal(file, current_line_num_ref)
		if medal_data:
			# Save the resource
			var output_path = OUTPUT_RES_DIR.path_join(medal_data.name.to_lower().replace(" ", "_") + ".tres")
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var save_result = ResourceSaver.save(medal_data, output_path, save_flags)
			if save_result != OK:
				printerr(f"Error saving MedalInfo resource '{output_path}': {save_result}")
				error_count += 1
			else:
				processed_count += 1
				print(f"    Saved: {output_path}")
		else:
			printerr(f"Failed to parse medal definition starting near line {current_line_num_ref[0]}.")
			error_count += 1
			# Attempt to recover by skipping to the next potential medal start
			_skip_to_next_section_or_token(file, current_line_num_ref, "$Name:")

	file.close()
	print(f"Finished converting medals.tbl. Processed: {processed_count}, Errors: {error_count}.")


# --- Medal Parsing Helper ---
func _parse_single_medal(file: FileAccess, current_line_num_ref: Variant) -> MedalInfo:
	"""Parses one $Name: block for a medal definition."""
	var medal_data = MedalInfo.new()

	# --- Required Basic Info ---
	var name_str = _parse_required_token(file, current_line_num_ref, "$Name:")
	if name_str == null: return null
	medal_data.name = name_str.trim_prefix("+") # Handle potential '+' prefix
	print(f"    Parsing Medal: {medal_data.name}")

	# --- Optional Fields ---
	var bitmap_str = _parse_optional_token(file, current_line_num_ref, "$Bitmap:")
	if bitmap_str != null: medal_data.bitmap_base_name = bitmap_str

	var num_levels_str = _parse_optional_token(file, current_line_num_ref, "$Num levels:")
	if num_levels_str != null: medal_data.num_levels = TblParserUtils.parse_int(num_levels_str, 1)

	var kills_str = _parse_optional_token(file, current_line_num_ref, "$Kills required:")
	if kills_str != null: medal_data.kills_required = TblParserUtils.parse_int(kills_str, 0)

	# Consume any remaining lines until the next $ or #
	while _peek_line(file) != null and not _peek_line(file).begins_with("$") and not _peek_line(file).begins_with("#"):
		_read_line(file, current_line_num_ref)

	return medal_data
