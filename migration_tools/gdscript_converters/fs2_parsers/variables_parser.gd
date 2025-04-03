# migration_tools/gdscript_converters/fs2_parsers/variables_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name VariablesParser

# --- Dependencies ---
# TODO: Preload SexpVariableData if it's a defined resource script
# const SexpVariableData = preload("res://scripts/resources/mission/sexp_variable_data.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed variable instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var variables_array: Array = [] # Array[SexpVariableData] or Dictionary

	print("Parsing #Sexp_variables section...") # FS2 uses #Variables, but map to sexp_variables

	# Loop through $Variable: blocks for each variable definition
	while _peek_line() != null and _peek_line().begins_with("$Variable:"):
		var variable_data = _parse_single_variable()
		if variable_data:
			variables_array.append(variable_data)
		else:
			# Error occurred in parsing this variable, try to recover
			printerr(f"Failed to parse variable starting near line {_current_line_num}. Attempting to skip to next '$Variable:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Variable:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Sexp_variables section. Found {variables_array.size()} variables.")
	return { "data": variables_array, "next_line": _current_line_num }


# --- Variable Parsing Helper ---
func _parse_single_variable() -> Dictionary:
	"""Parses one $Variable: block."""
	var variable_data: Dictionary = {} # Use Dictionary for now

	variable_data["variable_name"] = _parse_required_token("$Variable:")
	variable_data["type_string"] = _parse_required_token("+Type:") # Store type as string for now
	variable_data["value_string"] = _parse_required_token("+Value:") # Store value as string

	# TODO: Convert type_string to enum/int (e.g., SEXP_VARIABLE_NUMBER, SEXP_VARIABLE_STRING)
	# TODO: Convert value_string to appropriate type (int, float, string) based on type_string
	# TODO: Handle persistence flags (+Persistent:) if they exist in FS2 format

	return variable_data


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
