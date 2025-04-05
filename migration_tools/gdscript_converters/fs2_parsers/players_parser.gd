# migration_tools/gdscript_converters/fs2_parsers/players_parser.gd
extends BaseFS2Parser
class_name PlayersParser

# --- Dependencies ---
const PlayerStartData = preload("res://scripts/resources/mission/player_start_data.gd")
const ShipLoadoutChoice = preload("res://scripts/resources/mission/ship_loadout_choice.gd")
const WeaponLoadoutChoice = preload("res://scripts/resources/mission/weapon_loadout_choice.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed player start data ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var player_starts_array: Array[PlayerStartData] = []

	print("Parsing #Players section...")

	# FS2 can have multiple player start blocks for multiplayer teams.
	# Loop until the next section marker is found.
	while _peek_line() != null and not _peek_line().begins_with("#"):
		# Check if the current line indicates the start of a player block
		# (e.g., by looking for $Ship Choices: or $Starting Shipname:)
		# This assumes each player block starts somewhat consistently.
		# If the first token isn't found, we might be at the end or have an error.
		var peeked_line = _peek_line()
		if peeked_line.begins_with("$Ship Choices:") or peeked_line.begins_with("$Starting Shipname:"):
			var player_start_data: PlayerStartData = _parse_single_player_start()
			if player_start_data:
				player_starts_array.append(player_start_data)
			else:
				# Error occurred, try to recover
				printerr(f"Failed to parse player start block near line {_current_line_num}. Attempting to skip to next '$' or '#'.")
				_skip_to_next_section_or_token("$") # Try skipping to next potential start token
		else:
			# If it doesn't start with an expected token, break the loop
			# or consume the line if it's just whitespace/comment
			_skip_whitespace_and_comments()
			if _peek_line() == null or _peek_line().begins_with("#"):
				break # End of section or file
			else:
				# Unexpected content, consume and warn
				var unexpected_line = _read_line()
				printerr(f"Warning: Unexpected line in #Players section: '{unexpected_line}' at line {_current_line_num}")


	# Skip any remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Players section. Found {player_starts_array.size()} player start configurations.")
	return { "data": player_starts_array, "next_line": _current_line_num }


# --- Player Start Parsing Helper ---
func _parse_single_player_start() -> PlayerStartData:
	"""Parses one player start configuration block."""
	var player_start_data = PlayerStartData.new()

	# Optional Starting Shipname (seems less relevant if choices are defined)
	_parse_optional_token("$Starting Shipname:")

	# Ship Choices
	var ship_choices_str = _parse_required_token("$Ship Choices:")
	if ship_choices_str == null: return null
	player_start_data.ship_choices = _parse_loadout_list(ship_choices_str, "ship")

	# Default Ship
	var default_ship_str = _parse_optional_token("+Default_ship:")
	player_start_data.default_ship_name = default_ship_str if default_ship_str != null else "" # Store name

	# Weaponry Pool
	var weapon_pool_str = _parse_required_token("+Weaponry Pool:")
	if weapon_pool_str == null: return null
	player_start_data.weapon_pool = _parse_loadout_list(weapon_pool_str, "weapon")

	return player_start_data

func _parse_loadout_list(list_content: String, item_type: String) -> Array:
	"""Parses a ship or weapon loadout list string into an array of appropriate resources."""
	# Format: ( item_name, var_name, count, count_var_name, ... )
	var items_array: Array = [] # Array[ShipLoadoutChoice] or Array[WeaponLoadoutChoice]
	var content = list_content.trim_prefix("(").trim_suffix(")").strip_edges()
	# Split carefully, respecting potential spaces within quoted names (though unlikely here)
	var parts = content.split(",", false) # Split by comma

	if parts.size() % 4 != 0:
		printerr(f"Error: Loadout list has incorrect number of elements: '{list_content}'")
		return items_array

	for i in range(0, parts.size(), 4):
		var item_data # Will be ShipLoadoutChoice or WeaponLoadoutChoice resource

		if item_type == "ship":
			item_data = ShipLoadoutChoice.new()
			item_data.ship_class_name = parts[i].strip_edges()
			item_data.ship_variable = parts[i+1].strip_edges()
			item_data.count = int(parts[i+2].strip_edges())
			item_data.count_variable = parts[i+3].strip_edges()
			# Handle variable names ('nil' means no variable)
			if item_data.ship_variable.to_lower() == "nil": item_data.ship_variable = ""
			if item_data.count_variable.to_lower() == "nil": item_data.count_variable = ""
		elif item_type == "weapon":
			item_data = WeaponLoadoutChoice.new()
			item_data.weapon_class_name = parts[i].strip_edges()
			item_data.weapon_variable = parts[i+1].strip_edges()
			item_data.count = int(parts[i+2].strip_edges())
			item_data.count_variable = parts[i+3].strip_edges()
			# Handle variable names ('nil' means no variable)
			if item_data.weapon_variable.to_lower() == "nil": item_data.weapon_variable = ""
			if item_data.count_variable.to_lower() == "nil": item_data.count_variable = ""
		else:
			printerr(f"Unknown item type '{item_type}' in _parse_loadout_list")
			continue

		items_array.append(item_data)

	return items_array
