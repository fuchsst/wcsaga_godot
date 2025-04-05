# migration_tools/gdscript_converters/fs2_parsers/variables_parser.gd
extends BaseFS2Parser
class_name VariablesParser

# --- Dependencies ---
const SexpVariableData = preload("res://scripts/resources/mission/sexp_variable_data.gd")
const SexpConstants = preload("res://scripts/scripting/sexp/sexp_constants.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed variable instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var variables_array: Array[SexpVariableData] = []

	print("Parsing #Sexp_variables section...") # FS2 uses #Variables, but map to sexp_variables

	# Loop through $Variable: blocks for each variable definition
	while _peek_line() != null and _peek_line().begins_with("$Variable:"):
		var variable_data: SexpVariableData = _parse_single_variable()
		if variable_data:
			variables_array.append(variable_data)
		else:
			# Error occurred in parsing this variable, try to recover
			printerr(f"Failed to parse variable starting near line {_current_line_num}. Attempting to skip to next '$Variable:' or '#'.")
			_skip_to_next_section_or_token("$Variable:") # Try skipping to next potential start

	# Skip remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Sexp_variables section. Found {variables_array.size()} variables.")
	return { "data": variables_array, "next_line": _current_line_num }


# --- Variable Parsing Helper ---
func _parse_single_variable() -> SexpVariableData:
	"""Parses one $Variable: block."""
	var variable_data = SexpVariableData.new()

	var name_str = _parse_required_token("$Variable:")
	if name_str == null: return null
	variable_data.variable_name = name_str

	var type_str = _parse_required_token("+Type:")
	if type_str == null: return null
	# Map type string to enum/int
	match type_str.to_lower():
		"number":
			variable_data.type = SexpConstants.SEXP_VARIABLE_NUMBER
		"string":
			variable_data.type = SexpConstants.SEXP_VARIABLE_STRING
		_:
			printerr(f"Unknown variable type '{type_str}' for variable '{variable_data.variable_name}'. Defaulting to Number.")
			variable_data.type = SexpConstants.SEXP_VARIABLE_NUMBER

	var value_str = _parse_required_token("+Value:")
	if value_str == null: return null
	variable_data.text = value_str # Store raw value as text for now

	# TODO: Handle persistence flags (+Persistent:) if they exist in FS2 format
	# Example:
	# var persistent_str = _parse_optional_token("+Persistent:")
	# if persistent_str != null:
	#     if persistent_str.to_lower() == "campaign":
	#         variable_data.type |= SexpConstants.SEXP_VARIABLE_CAMPAIGN_PERSISTENT
	#     elif persistent_str.to_lower() == "player":
	#         variable_data.type |= SexpConstants.SEXP_VARIABLE_PLAYER_PERSISTENT

	return variable_data

