# migration_tools/gdscript_converters/fs2_parsers/background_parser.gd
extends BaseFS2Parser
class_name BackgroundParser

# --- Dependencies ---
# None specific needed for basic parsing, but might need constants later

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the parsed background data
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var background_data: Dictionary = {
		"num_stars": 100, # Default
		"ambient_light_level": Color(0.47, 0.47, 0.47), # Default 0x787878
		"nebula_index": -1,
		"nebula_color_index": 0,
		"nebula_pitch": 0,
		"nebula_bank": 0,
		"nebula_heading": 0,
		"envmap_name": "",
		"suns": [],
		"star_bitmaps": []
	}

	print("Parsing #Background bitmaps section...")

	# Required fields
	background_data["num_stars"] = int(_parse_required_token("$Num stars:"))
	var ambient_str = _parse_required_token("$Ambient light level:")
	# Assuming ambient light is a single integer representing packed RGB?
	# Need clarification on FS2 format vs Godot Color. Using placeholder.
	var ambient_int = ambient_str.to_int()
	# Example conversion assuming 0xRRGGBB format, ignoring alpha
	var r = float((ambient_int >> 16) & 0xFF) / 255.0
	var g = float((ambient_int >> 8) & 0xFF) / 255.0
	var b = float(ambient_int & 0xFF) / 255.0
	background_data["ambient_light_level"] = Color(r, g, b)

	# Optional Nebula settings
	var neb2_token = _parse_optional_token("+Neb2:") # Check for Neb2 first
	if neb2_token != null:
		# Handle Neb2 settings if needed (e.g., store texture name)
		# background_data["neb2_texture_name"] = neb2_token
		var neb2_flags_str = _parse_optional_token("+Neb2Flags:")
		# if neb2_flags_str != null: background_data["neb2_flags"] = neb2_flags_str.to_int()
		pass # Skip Neb2 specific parsing for now unless needed by MissionData

	var nebula_token = _parse_optional_token("+Nebula:")
	if nebula_token != null:
		# TODO: Convert nebula filename to index if using predefined list
		# background_data["nebula_index"] = lookup_nebula_index(nebula_token)
		background_data["nebula_filename"] = nebula_token # Store name for now

		var color_token = _parse_optional_token("+Color:")
		if color_token != null:
			# TODO: Convert color name to index
			# background_data["nebula_color_index"] = lookup_nebula_color_index(color_token)
			background_data["nebula_color_name"] = color_token # Store name for now

		var pitch_str = _parse_optional_token("+Pitch:")
		if pitch_str != null: background_data["nebula_pitch"] = pitch_str.to_int()
		var bank_str = _parse_optional_token("+Bank:")
		if bank_str != null: background_data["nebula_bank"] = bank_str.to_int()
		var heading_str = _parse_optional_token("+Heading:")
		if heading_str != null: background_data["nebula_heading"] = heading_str.to_int()

	# Optional Sun/Star Bitmaps (More complex parsing needed)
	while _peek_line() != null and (_peek_line().begins_with("$Sun:") or _peek_line().begins_with("$Starbitmap:")):
		if _peek_line().begins_with("$Sun:"):
			# TODO: Parse Sun definition
			_parse_required_token("$Sun:")
			_parse_required_token("+Angles:")
			_parse_required_token("+Scale:")
			print("TODO: Parse Sun definition")
		elif _peek_line().begins_with("$Starbitmap:"):
			# TODO: Parse Starbitmap definition
			_parse_required_token("$Starbitmap:")
			_parse_required_token("+Angles:")
			if _parse_optional_token("+Scale:") == null:
				_parse_required_token("+ScaleX:")
				_parse_required_token("+ScaleY:")
				_parse_required_token("+DivX:")
				_parse_required_token("+DivY:")
			print("TODO: Parse Starbitmap definition")

	# Optional Environment Map
	var envmap_str = _parse_optional_token("$Environment Map:")
	if envmap_str != null: background_data["envmap_name"] = envmap_str

	# Skip any remaining lines until the next section
	while _peek_line() != null and not _peek_line().begins_with("#"):
		_read_line()

	print("Finished parsing #Background bitmaps section.")
	return { "data": background_data, "next_line": _current_line_num }

