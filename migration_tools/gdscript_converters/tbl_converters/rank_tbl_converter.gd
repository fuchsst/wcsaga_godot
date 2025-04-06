@tool
extends BaseTblConverter
# Converts rank.tbl into individual Godot RankInfo resources (.tres).

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const RankInfo = preload("res://scripts/resources/player/rank_info.gd")

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/rank.tbl" # Adjust if needed
const OUTPUT_RES_DIR = "res://resources/ranks" # Output dir for .tres files

# --- Main Execution ---
func _run():
	print("Converting rank.tbl...")

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
	# Skip header lines until #Ranks section
	if not _skip_to_token(file, current_line_num_ref, "#Ranks"):
		printerr("Error: '#Ranks' marker not found in rank.tbl")
		file.close()
		return

	print("  Parsing #Ranks section...")

	# Loop through each rank definition
	while not file.eof_reached():
		var line = _peek_line(file) # Peek first

		# Stop at end marker
		if line != null and line.begins_with("#End"):
			print("  Reached #End.")
			break

		# Find the start of the next rank
		if line == null or not line.begins_with("$Name:"):
			_read_line(file, current_line_num_ref) # Consume the non-starting line
			continue

		# Parse the rank
		var rank_data: RankInfo = _parse_single_rank(file, current_line_num_ref)
		if rank_data:
			# Save the resource
			var output_path = OUTPUT_RES_DIR.path_join(rank_data.name.to_lower().replace(" ", "_") + ".tres")
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var save_result = ResourceSaver.save(rank_data, output_path, save_flags)
			if save_result != OK:
				printerr(f"Error saving RankInfo resource '{output_path}': {save_result}")
				error_count += 1
			else:
				processed_count += 1
				print(f"    Saved: {output_path}")
		else:
			printerr(f"Failed to parse rank definition starting near line {current_line_num_ref[0]}.")
			error_count += 1
			# Attempt to recover by skipping to the next potential rank start
			_skip_to_next_section_or_token(file, current_line_num_ref, "$Name:")

	file.close()
	print(f"Finished converting rank.tbl. Processed: {processed_count}, Errors: {error_count}.")


# --- Rank Parsing Helper ---
func _parse_single_rank(file: FileAccess, current_line_num_ref: Variant) -> RankInfo:
	"""Parses one $Name: block for a rank definition."""
	var rank_data = RankInfo.new()

	# --- Required Basic Info ---
	var name_str = _parse_required_token(file, current_line_num_ref, "$Name:")
	if name_str == null: return null
	rank_data.name = name_str.trim_prefix("+") # Handle potential '+' prefix
	print(f"    Parsing Rank: {rank_data.name}")

	# --- Optional Fields ---
	var points_str = _parse_optional_token(file, current_line_num_ref, "$Points:")
	if points_str != null: rank_data.points = TblParserUtils.parse_int(points_str, 0)

	var bitmap_str = _parse_optional_token(file, current_line_num_ref, "$Bitmap:")
	if bitmap_str != null: rank_data.bitmap_name = bitmap_str

	var promotion_voice_str = _parse_optional_token(file, current_line_num_ref, "$Promotion Voice Base:")
	if promotion_voice_str != null: rank_data.promotion_voice_base_name = promotion_voice_str

	var promotion_text_str = _parse_optional_token(file, current_line_num_ref, "$Promotion Text:")
	if promotion_text_str != null: rank_data.promotion_text = promotion_text_str

	# Consume any remaining lines until the next $ or #
	while _peek_line(file) != null and not _peek_line(file).begins_with("$") and not _peek_line(file).begins_with("#"):
		_read_line(file, current_line_num_ref)

	return rank_data
