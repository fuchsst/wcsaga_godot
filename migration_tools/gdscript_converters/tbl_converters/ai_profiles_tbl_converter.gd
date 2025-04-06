@tool
extends BaseTblConverter
# Converts ai_profiles.tbl into individual Godot AIProfile resources (.tres).

# --- Dependencies ---
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const AIProfile = preload("res://scripts/resources/ai/ai_profile.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For flags

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/ai_profiles.tbl" # Adjust if needed
const OUTPUT_RES_DIR = "res://resources/ai/profiles" # Output dir for .tres files

# --- Main Execution ---
func _run():
	print("Converting ai_profiles.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_DIR)

	var current_line_num = 0
	var processed_count = 0
	var error_count = 0

	# --- Parsing Logic ---
	# Skip header lines until #AI Profiles section
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		current_line_num += 1
		if line == "#AI Profiles":
			print("  Parsing #AI Profiles section...")
			break
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

	# Parse each profile entry
	while not file.eof_reached():
		current_line_num += 1
		var line = file.get_line().strip_edges()

		# Stop at end marker or if line doesn't start with $Name
		if line.begins_with("#End"):
			print("  Reached #End.")
			break
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		if not line.begins_with("$Name:"):
			printerr(f"Warning: Expected '$Name:' but got '{line}' at line {current_line_num}. Skipping.")
			continue

		# Start parsing a new profile
		var ai_profile = AIProfile.new()
		var profile_name = line.substr(6).strip_edges() # Get value after $Name:
		ai_profile.profile_name = profile_name
		print(f"    Parsing AI Profile: {profile_name}")

		# Parse subsequent fields for this profile
		while true:
			var field_line = _peek_line(file)
			# Stop if we hit EOF, the next profile, or the end marker
			if field_line == null or field_line.begins_with("$Name:") or field_line.begins_with("#End"):
				break

			# Consume the line
			file.get_line()
			current_line_num += 1
			field_line = field_line.strip_edges()

			if field_line.is_empty() or field_line.begins_with(";") or field_line.begins_with("//"):
				continue

			# Parse known fields (referencing AIProfile.gd exports)
			if field_line.begins_with("$Accuracy:"):
				ai_profile.accuracy = TblParserUtils.parse_float_list(field_line.substr(10).strip_edges())
			elif field_line.begins_with("$Evasion:"):
				ai_profile.evasion = TblParserUtils.parse_float_list(field_line.substr(9).strip_edges())
			elif field_line.begins_with("$Courage:"):
				ai_profile.courage = TblParserUtils.parse_float_list(field_line.substr(9).strip_edges())
			elif field_line.begins_with("$Patience:"):
				ai_profile.patience = TblParserUtils.parse_float_list(field_line.substr(10).strip_edges())
			elif field_line.begins_with("$Flags:"):
				# TODO: Implement flag parsing based on AIPF_* constants
				# ai_profile.flags = _parse_ai_flags(field_line.substr(7).strip_edges())
				print(f"Warning: AI Profile Flag parsing not implemented yet for line {current_line_num}")
				pass
			elif field_line.begins_with("$Flags2:"):
				# TODO: Implement flag parsing based on AIPF2_* constants
				# ai_profile.flags2 = _parse_ai_flags2(field_line.substr(8).strip_edges())
				print(f"Warning: AI Profile Flag2 parsing not implemented yet for line {current_line_num}")
				pass
			# Add parsing for other AI profile fields as defined in AIProfile.gd
			# Example:
			# elif field_line.begins_with("$Max Attackers:"):
			#     ai_profile.max_attackers = TblParserUtils.parse_int_list(field_line.substr(15).strip_edges())
			# elif field_line.begins_with("$Predict Position Delay:"):
			#     ai_profile.predict_position_delay = TblParserUtils.parse_float_list(field_line.substr(24).strip_edges())
			# ... and so on for all fields in ai_profiles.tbl and AIProfile.gd
			else:
				# Ignore unknown fields for this profile
				pass

		# --- Save Individual Resource ---
		var output_path = OUTPUT_RES_DIR.path_join(profile_name.to_lower().replace(" ", "_") + ".tres")
		var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
		var save_result = ResourceSaver.save(ai_profile, output_path, save_flags)

		if save_result != OK:
			printerr(f"Error saving resource '{output_path}': {save_result}")
			error_count += 1
		else:
			processed_count += 1
			print(f"    Saved: {output_path}")

	file.close()
	print(f"Finished converting ai_profiles.tbl. Processed: {processed_count}, Errors: {error_count}.")



# TODO: Implement _parse_ai_flags and _parse_ai_flags2 using TblParserUtils.parse_flags
# and the AIPF_*, AIPF2_* constants from GlobalConstants or AIConstants
