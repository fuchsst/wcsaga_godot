# migration_tools/gdscript_converters/fs2_parsers/reinforcements_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name ReinforcementsParser

# --- Dependencies ---
# TODO: Preload ReinforcementData if it's a defined resource script
# const ReinforcementData = preload("res://scripts/resources/mission/reinforcement_data.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed reinforcement instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var reinforcements_array: Array = [] # Array[ReinforcementData] or Dictionary

	print("Parsing #Reinforcements section...")

	# Loop through $Name: blocks for each reinforcement definition
	while _peek_line() != null and _peek_line().begins_with("$Name:"):
		var reinforcement_data = _parse_single_reinforcement()
		if reinforcement_data:
			reinforcements_array.append(reinforcement_data)
		else:
			# Error occurred in parsing this reinforcement, try to recover
			printerr(f"Failed to parse reinforcement starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Name:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Reinforcements section. Found {reinforcements_array.size()} reinforcements.")
	return { "data": reinforcements_array, "next_line": _current_line_num }


# --- Reinforcement Parsing Helper ---
func _parse_single_reinforcement() -> Dictionary:
	"""Parses one $Name: block for a reinforcement instance."""
	var reinforcement_data: Dictionary = {} # Use Dictionary for now

	reinforcement_data["reinforcement_name"] = _parse_required_token("$Name:")

	# Parse Type
	var type_str = _parse_required_token("$Type:")
	# TODO: Convert type_str ("Attack/Protect", "Repair/Rearm") to enum/int
	# reinforcement_data["reinforcement_type"] = GlobalConstants.lookup_reinforcement_type(type_str)

	# Parse Num times
	reinforcement_data["num_uses"] = int(_parse_required_token("$Num times:"))

	# Optional Arrival delay
	reinforcement_data["arrival_delay_ms"] = int(_parse_optional_token("+Arrival delay:") or "0") * 1000

	# Optional No Messages list
	var no_msgs_str = _parse_optional_token("+No Messages:")
	if no_msgs_str != null:
		reinforcement_data["no_messages"] = no_msgs_str.split(" ", false) # Assuming space-separated
	else:
		reinforcement_data["no_messages"] = []

	# Optional Yes Messages list
	var yes_msgs_str = _parse_optional_token("+Yes Messages:")
	if yes_msgs_str != null:
		reinforcement_data["yes_messages"] = yes_msgs_str.split(" ", false) # Assuming space-separated
	else:
		reinforcement_data["yes_messages"] = []

	return reinforcement_data


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
