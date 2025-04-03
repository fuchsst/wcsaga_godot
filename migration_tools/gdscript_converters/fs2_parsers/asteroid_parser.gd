# migration_tools/gdscript_converters/fs2_parsers/asteroid_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name AsteroidParser

# --- Dependencies ---
# TODO: Preload AsteroidFieldData if it's a defined resource script
# const AsteroidFieldData = preload("res://scripts/resources/mission/asteroid_field_data.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed asteroid field instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var asteroid_fields_array: Array = [] # Array[AsteroidFieldData] or Dictionary

	print("Parsing #Asteroid Fields section...")

	# FS2 only supports one asteroid field per mission, but we'll loop just in case
	# The loop condition might need adjustment based on how the section ends.
	# Assuming it ends when a non-field related token or a new section starts.
	while _peek_line() != null and _peek_line().begins_with("$density:"):
		var field_data = _parse_single_field()
		if field_data:
			asteroid_fields_array.append(field_data)
		else:
			# Error occurred in parsing this field, try to recover
			printerr(f"Failed to parse asteroid field starting near line {_current_line_num}. Attempting to skip to next '$density:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$density:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Asteroid Fields section. Found {asteroid_fields_array.size()} fields.")
	# Even if multiple are parsed (unlikely for FS2), MissionData likely holds only one.
	# The main converter will need to handle this.
	return { "data": asteroid_fields_array, "next_line": _current_line_num }


# --- Asteroid Field Parsing Helper ---
func _parse_single_field() -> Dictionary:
	"""Parses one asteroid field definition."""
	var field_data: Dictionary = {} # Use Dictionary for now

	# Required fields
	field_data["density"] = float(_parse_required_token("$Density:")) # FS2 uses density for initial count? Clarify.
	field_data["average_speed"] = float(_parse_required_token("$Average Speed:"))

	# Optional fields
	var field_type_str = _parse_optional_token("+Field Type:")
	if field_type_str != null:
		field_data["field_type"] = field_type_str.to_int() # TODO: Map to enum if available

	var debris_genre_str = _parse_optional_token("+Debris Genre:")
	if debris_genre_str != null:
		field_data["debris_genre"] = debris_genre_str.to_int() # TODO: Map to enum

	# Field Debris Type (can appear multiple times)
	field_data["field_debris_types"] = [] # Store indices or names
	while true:
		var debris_type_str = _parse_optional_token("+Field Debris Type:")
		if debris_type_str == null:
			break
		# TODO: Store appropriately, maybe as indices or names depending on resource def
		field_data["field_debris_types"].append(debris_type_str.to_int())


	# Bounds are required
	field_data["min_bound"] = _parse_vector(_parse_required_token("$Minimum:"))
	field_data["max_bound"] = _parse_vector(_parse_required_token("$Maximum:"))

	# Optional Inner Bound
	var inner_bound_token = _parse_optional_token("+Inner Bound:")
	if inner_bound_token != null:
		field_data["has_inner_bound"] = true
		field_data["inner_min_bound"] = _parse_vector(_parse_required_token("$Minimum:"))
		field_data["inner_max_bound"] = _parse_vector(_parse_required_token("$Maximum:"))
	else:
		field_data["has_inner_bound"] = false


	# TODO: Parse initial velocity direction if present ($Average Speed: might imply direction too?)
	# The C++ code suggests $Average Speed: sets magnitude and uses a random direction.
	# We might need to store only the speed magnitude here.
	field_data["initial_velocity_magnitude"] = field_data["average_speed"]


	return field_data


# --- Helper Functions (Duplicated for now, move to Base later) ---

func _peek_line() -> String:
	if _current_line_num < _lines.size():
		return _lines[_current_line_num].strip_edges()
	return null

func _read_line() -> String:
	var line = _peek_line()
	if line != null:
		_current_line_num += 1
	return line

func _skip_whitespace_and_comments():
	while true:
		var line = _peek_line()
		if line == null: break
		if line and not line.begins_with(';'): break
		_current_line_num += 1

func _parse_required_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _read_line()
	if line == null or not line.begins_with(expected_token):
		printerr(f"Error: Expected '{expected_token}' but found '{line}' at line {_current_line_num}")
		return ""
	return line.substr(expected_token.length()).strip_edges()

func _parse_optional_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _peek_line()
	if line != null and line.begins_with(expected_token):
		_read_line()
		return line.substr(expected_token.length()).strip_edges()
	return null

func _parse_vector(line_content: String) -> Vector3:
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 3:
		return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	else:
		printerr(f"Error parsing Vector3: '{line_content}'")
		return Vector3.ZERO
