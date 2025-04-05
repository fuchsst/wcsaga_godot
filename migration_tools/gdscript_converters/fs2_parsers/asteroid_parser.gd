# migration_tools/gdscript_converters/fs2_parsers/asteroid_parser.gd
extends BaseFS2Parser
class_name AsteroidParser

# --- Dependencies ---
const AsteroidFieldData = preload("res://scripts/resources/mission/asteroid_field_data.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed asteroid field instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var asteroid_fields_array: Array = [] # Array[Dictionary] for now

	print("Parsing #Asteroid Fields section...")

	# FS2 only supports one asteroid field per mission, but we'll loop just in case
	# The loop condition might need adjustment based on how the section ends.
	# Assuming it ends when a non-field related token or a new section starts.
	while _peek_line() != null and _peek_line().begins_with("$Density:"): # FS2 uses $Density:
		var field_data = _parse_single_field()
		if field_data:
			asteroid_fields_array.append(field_data)
		else:
			# Error occurred in parsing this field, try to recover
			printerr(f"Failed to parse asteroid field starting near line {_current_line_num}. Attempting to skip to next '$Density:' or '#'.")
			_skip_to_next_section_or_token("$Density:") # Try skipping to next potential start

	print(f"Finished parsing #Asteroid Fields section. Found {asteroid_fields_array.size()} fields.")
	# Even if multiple are parsed (unlikely for FS2), MissionData likely holds only one.
	# The main converter will need to handle this.
	return { "data": asteroid_fields_array, "next_line": _current_line_num }


# --- Asteroid Field Parsing Helper ---
func _parse_single_field() -> Dictionary:
	"""Parses one asteroid field definition."""
	var field_data: Dictionary = {} # Use Dictionary for now

	# Required fields
	var density_str = _parse_required_token("$Density:")
	if density_str == null: return null
	field_data["density"] = density_str.to_float() # FS2 uses density for initial count? Clarify.

	var avg_speed_str = _parse_required_token("$Average Speed:")
	if avg_speed_str == null: return null
	field_data["average_speed"] = avg_speed_str.to_float()

	# Optional fields
	var field_type_str = _parse_optional_token("+Field Type:")
	if field_type_str != null:
		# TODO: Map to AsteroidFieldData.FieldType enum
		field_data["field_type"] = field_type_str.to_int()

	var debris_genre_str = _parse_optional_token("+Debris Genre:")
	if debris_genre_str != null:
		# TODO: Map to AsteroidFieldData.DebrisGenre enum
		field_data["debris_genre"] = debris_genre_str.to_int()

	# Field Debris Type (can appear multiple times)
	var debris_types: Array[int] = []
	while true:
		var debris_type_str = _parse_optional_token("+Field Debris Type:")
		if debris_type_str == null:
			break
		# Assuming these are indices into some debris definition table/resource
		if debris_type_str.is_valid_int():
			debris_types.append(debris_type_str.to_int())
		else:
			printerr(f"Warning: Invalid integer for +Field Debris Type: '{debris_type_str}'")
	field_data["field_debris_type_indices"] = debris_types # Store indices

	# Bounds are required
	var min_bound_str = _parse_required_token("$Minimum:")
	if min_bound_str == null: return null
	field_data["min_bound"] = _parse_vector(min_bound_str)

	var max_bound_str = _parse_required_token("$Maximum:")
	if max_bound_str == null: return null
	field_data["max_bound"] = _parse_vector(max_bound_str)

	# Optional Inner Bound
	var inner_bound_token = _parse_optional_token("+Inner Bound:")
	if inner_bound_token != null:
		field_data["has_inner_bound"] = true
		var inner_min_str = _parse_required_token("$Minimum:")
		if inner_min_str == null: return null
		field_data["inner_min_bound"] = _parse_vector(inner_min_str)

		var inner_max_str = _parse_required_token("$Maximum:")
		if inner_max_str == null: return null
		field_data["inner_max_bound"] = _parse_vector(inner_max_str)
	else:
		field_data["has_inner_bound"] = false

	# The C++ code suggests $Average Speed: sets magnitude and uses a random direction.
	# We store only the speed magnitude here. Runtime generates direction.
	field_data["initial_velocity_magnitude"] = field_data["average_speed"]

	return field_data

