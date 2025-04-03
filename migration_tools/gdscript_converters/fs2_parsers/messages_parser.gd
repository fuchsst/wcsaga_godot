# migration_tools/gdscript_converters/fs2_parsers/messages_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name MessagesParser

# --- Dependencies ---
# TODO: Preload MessageData and PersonaData if they are defined resource scripts
# const MessageData = preload("res://scripts/resources/mission/message_data.gd")
# const PersonaData = preload("res://scripts/resources/mission/persona_data.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the command sender/persona and list of messages ('command_sender', 'command_persona_name', 'messages')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var messages_array: Array = [] # Array[MessageData] or Dictionary
	var command_sender = "Command" # Default
	var command_persona_name = ""

	print("Parsing #Messages section...")

	# Check for optional command sender/persona first
	var sender_token = _parse_optional_token("$Command Sender:")
	if sender_token != null:
		command_sender = sender_token
		# Handle potential '#' prefix in older files
		if command_sender.begins_with("#"):
			command_sender = command_sender.substr(1)

	var persona_token = _parse_optional_token("$Command Persona:")
	if persona_token != null:
		command_persona_name = persona_token

	# Loop through $Name: blocks for each message definition
	while _peek_line() != null and _peek_line().begins_with("$Name:"):
		var message_data = _parse_single_message()
		if message_data:
			messages_array.append(message_data)
		else:
			# Error occurred in parsing this message, try to recover
			printerr(f"Failed to parse message starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Name:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Messages section. Found {messages_array.size()} messages.")
	return {
		"command_sender": command_sender,
		"command_persona_name": command_persona_name,
		"messages": messages_array,
		"next_line": _current_line_num
	}


# --- Message Parsing Helper ---
func _parse_single_message() -> Dictionary:
	"""Parses one $Name: block for a message instance."""
	var message_data: Dictionary = {} # Use Dictionary for now

	message_data["message_name"] = _parse_required_token("$Name:")

	# Optional Team
	message_data["team"] = int(_parse_optional_token("$Team:") or "-1") # Default to -1 (all teams?)

	# Message Text (can be $Message: or $MessageNew:)
	var msg_token = _parse_optional_token("$Message:")
	if msg_token != null:
		message_data["message_text"] = msg_token # Single line message
	else:
		# Consume $MessageNew: token before parsing multi-text
		_parse_required_token("$MessageNew:")
		message_data["message_text"] = _parse_multitext()

	# Optional Persona
	message_data["persona_name"] = _parse_optional_token("+Persona:") or "" # TODO: Link to PersonaData resource?

	# Optional AVI Name
	message_data["avi_filename"] = _parse_optional_token("+AVI Name:") or ""

	# Optional Wave Name
	message_data["wave_filename"] = _parse_optional_token("+Wave Name:") or ""

	return message_data


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

func _parse_multitext() -> String:
	var text_lines: PackedStringArray = []
	while true:
		var line = _read_line()
		if line == null:
			printerr("Error: Unexpected end of file while parsing multi-text")
			break
		if line.strip_edges() == "#end_multi_text":
			break
		text_lines.append(line)
	return "\n".join(text_lines)
