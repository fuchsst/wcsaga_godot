# migration_tools/gdscript_converters/fs2_parsers/players_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name PlayersParser

# --- Dependencies ---
# TODO: Preload PlayerStartData if it's a defined resource script
# const PlayerStartData = preload("res://scripts/resources/mission/player_start_data.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed player start data ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var player_starts_array: Array = [] # Array[PlayerStartData] or Dictionary

	print("Parsing #Players section...")

	# FS2 can have multiple player start blocks for multiplayer teams.
	# Loop until the next section marker is found.
	while _peek_line() != null and not _peek_line().begins_with("#"):
		var player_start_data = _parse_single_player_start()
		if player_start_data:
			player_starts_array.append(player_start_data)
		else:
			# Error occurred, try to recover
			printerr(f"Failed to parse player start block near line {_current_line_num}. Attempting to skip to next '$' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Players section. Found {player_starts_array.size()} player start configurations.")
	return { "data": player_starts_array, "next_line": _current_line_num }


# --- Player Start Parsing Helper ---
func _parse_single_player_start() -> Dictionary:
	"""Parses one player start configuration block."""
	var player_start_data: Dictionary = {} # Use Dictionary for now

	# Optional Starting Shipname (seems less relevant if choices are defined)
	_parse_optional_token("$Starting Shipname:")

	# Ship Choices
	var ship_choices_str = _parse_required_token("$Ship Choices:")
	player_start_data["ship_choices"] = _parse_loadout_list(ship_choices_str)

	# Default Ship
	player_start_data["default_ship_name"] = _parse_optional_token("+Default_ship:") or "" # Store name

	# Weaponry Pool
	var weapon_pool_str = _parse_required_token("+Weaponry Pool:")
	player_start_data["weapon_pool"] = _parse_loadout_list(weapon_pool_str)

	return player_start_data

func _parse_loadout_list(list_content: String) -> Array:
	"""Parses a ship or weapon loadout list string."""
	# Format: ( item_name, var_name, count, count_var_name, ... )
	var items_array: Array = []
	var content = list_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false) # Split by comma

	if parts.size() % 4 != 0:
		printerr(f"Error: Loadout list has incorrect number of elements: '{list_content}'")
		return items_array

	for i in range(0, parts.size(), 4):
		var item_data = {
			"item_name": parts[i].strip_edges(),
			"item_variable": parts[i+1].strip_edges(),
			"count": int(parts[i+2].strip_edges()),
			"count_variable": parts[i+3].strip_edges()
		}
		# TODO: Convert item_name to index/resource path later
		# TODO: Handle variable names ('nil' means no variable)
		if item_data["item_variable"].to_lower() == "nil": item_data["item_variable"] = ""
		if item_data["count_variable"].to_lower() == "nil": item_data["count_variable"] = ""

		items_array.append(item_data)

	return items_array


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
