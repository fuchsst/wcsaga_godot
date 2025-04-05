# migration_tools/gdscript_converters/fs2_parsers/reinforcements_parser.gd
extends BaseFS2Parser
class_name ReinforcementsParser

# --- Dependencies ---
const ReinforcementData = preload("res://scripts/resources/mission/reinforcement_data.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Mappings ---
const REINFORCEMENT_TYPE_MAP: Dictionary = {
	"attack/protect": ReinforcementData.ReinforcementType.ATTACK_PROTECT, 
	"repair/rearm": ReinforcementData.ReinforcementType.REPAIR_REARM,
}

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed reinforcement instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var reinforcements_array: Array[ReinforcementData] = []

	print("Parsing #Reinforcements section...")

	# Loop through $Name: blocks for each reinforcement definition
	while _peek_line() != null and _peek_line().begins_with("$Name:"):
		var reinforcement_data: ReinforcementData = _parse_single_reinforcement()
		if reinforcement_data:
			reinforcements_array.append(reinforcement_data)
		else:
			# Error occurred in parsing this reinforcement, try to recover
			printerr(f"Failed to parse reinforcement starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			_skip_to_next_section_or_token("$Name:")

	# Skip any remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Reinforcements section. Found {reinforcements_array.size()} reinforcements.")
	return { "data": reinforcements_array, "next_line": _current_line_num }


# --- Reinforcement Parsing Helper ---
func _parse_single_reinforcement() -> ReinforcementData:
	"""Parses one $Name: block for a reinforcement instance."""
	var reinforcement_data = ReinforcementData.new()

	var name_str = _parse_required_token("$Name:")
	if name_str == null: return null
	reinforcement_data.name = name_str

	# Parse Type
	var type_str = _parse_required_token("$Type:")
	if type_str == null: return null
	var type_lower = type_str.to_lower()
	if REINFORCEMENT_TYPE_MAP.has(type_lower):
		reinforcement_data.type = REINFORCEMENT_TYPE_MAP[type_lower]
	else:
		printerr(f"Unknown reinforcement type '{type_str}' at line {_current_line_num}")
		reinforcement_data.type = 0 # Default to Attack/Protect

	# Parse Num times
	var num_times_str = _parse_required_token("$Num times:")
	if num_times_str == null: return null
	reinforcement_data.total_uses = num_times_str.to_int()

	# Optional Arrival delay
	var delay_str = _parse_optional_token("+Arrival delay:")
	reinforcement_data.arrival_delay_seconds = int(delay_str) if delay_str != null and delay_str.is_valid_int() else 0

	# Optional No Messages list
	var no_msgs_str = _parse_optional_token("+No Messages:")
	if no_msgs_str != null:
		reinforcement_data.no_messages = _parse_string_list(no_msgs_str)
	else:
		reinforcement_data.no_messages = []

	# Optional Yes Messages list
	var yes_msgs_str = _parse_optional_token("+Yes Messages:")
	if yes_msgs_str != null:
		reinforcement_data.yes_messages = _parse_string_list(yes_msgs_str)
	else:
		reinforcement_data.yes_messages = []

	return reinforcement_data


# --- Helper Functions ---

func _parse_string_list(list_string: String) -> Array[String]:
	# Parses a space-separated list of strings, handling potential quotes
	var result: Array[String] = []
	var current_token = ""
	var in_quotes = false
	for char in list_string:
		if char == '"':
			in_quotes = not in_quotes
		elif char == ' ' and not in_quotes:
			if current_token:
				result.append(current_token)
				current_token = ""
		else:
			current_token += char
	if current_token: # Add the last token
		result.append(current_token)
	return result

