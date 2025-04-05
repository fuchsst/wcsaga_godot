# migration_tools/gdscript_converters/fs2_parsers/messages_parser.gd
extends BaseFS2Parser
class_name MessagesParser

# --- Dependencies ---
const MessageData = preload("res://scripts/resources/mission/message_data.gd")
const PersonaData = preload("res://scripts/resources/mission/persona_data.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num
var _personas_output_dir: String = "res://resources/messages/personas" # Default output for personas

# --- Mappings ---
const PERSONA_TYPE_MAP: Dictionary = {
	"wingman": GlobalConstants.PERSONA_FLAG_WINGMAN,
	"support": GlobalConstants.PERSONA_FLAG_SUPPORT,
	"large": GlobalConstants.PERSONA_FLAG_LARGE,
	"command": GlobalConstants.PERSONA_FLAG_COMMAND,
}

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the command sender/persona and list of messages ('command_sender', 'command_persona_name', 'messages')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var messages_array: Array[MessageData] = []
	var command_sender = "Command" # Default
	var command_persona_name = ""

	# --- Parse Personas First (if present before #Messages) ---
	# This assumes messages.tbl structure: #Personas ... #Messages ... #End
	# We need to parse personas separately and save them.
	# The main converter should ideally handle calling this persona parsing step
	# *before* calling the message parsing step if they are in the same file.
	# For now, let's assume this parser is called at the start of the file
	# and handles both sections sequentially.

	# Ensure personas output directory exists
	DirAccess.make_dir_recursive_absolute(_personas_output_dir)

	if _skip_to_token("#Personas"):
		_parse_personas_section() # This will parse and save PersonaData resources
	else:
		printerr("Warning: #Personas section not found in messages.tbl")
		# Reset line number if we skipped too far looking for #Personas
		_current_line_num = start_line_index

	# --- Now Parse Messages ---
	if not _skip_to_token("#Messages"):
		printerr("Error: #Messages section not found in messages.tbl")
		# Return empty data but advance line number past potential persona section
		return {
			"command_sender": command_sender,
			"command_persona_name": command_persona_name,
			"messages": messages_array,
			"next_line": _current_line_num
		}

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
		command_persona_name = persona_token # Store name, index lookup happens at runtime

	# Loop through $Name: blocks for each message definition
	while _peek_line() != null and _peek_line().begins_with("$Name:"):
		var message_data: MessageData = _parse_single_message()
		if message_data:
			messages_array.append(message_data)
		else:
			# Error occurred in parsing this message, try to recover
			printerr(f"Failed to parse message starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			_skip_to_next_section_or_token("$Name:")

	# Skip any remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Messages section. Found {messages_array.size()} messages.")
	return {
		"command_sender": command_sender,
		"command_persona_name": command_persona_name, # Pass name for runtime lookup
		"messages": messages_array,
		"next_line": _current_line_num
	}

# --- Persona Section Parsing ---
func _parse_personas_section():
	print("Parsing #Personas section...")
	while _peek_line() != null and _peek_line().begins_with("$Persona:"):
		var persona_data: PersonaData = _parse_single_persona()
		if persona_data:
			# Save the PersonaData resource
			var output_path = _personas_output_dir.path_join(persona_data.name.to_lower().replace(" ", "_") + ".tres")
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var save_result = ResourceSaver.save(persona_data, output_path, save_flags)
			if save_result != OK:
				printerr(f"Error saving PersonaData resource '{output_path}': {save_result}")
			else:
				print(f"Saved Persona: {output_path}")
		else:
			printerr(f"Failed to parse persona starting near line {_current_line_num}.")
			_skip_to_next_section_or_token("$Persona:") # Attempt recovery

	# Skip to the end of the persona section if not already there
	_skip_to_next_section_or_token("#Messages")
	print("Finished parsing #Personas section.")


# --- Persona Parsing Helper ---
func _parse_single_persona() -> PersonaData:
	"""Parses one $Persona: block."""
	var persona_data = PersonaData.new()

	var name_str = _parse_required_token("$Persona:")
	if name_str == null: return null
	persona_data.name = name_str

	var type_str = _parse_required_token("$Type:")
	if type_str == null: return null
	persona_data.type_flags = PERSONA_TYPE_MAP.get(type_str.to_lower(), 0) # Default to 0 if unknown

	persona_data.auto_assign = _parse_optional_token("+autoassign") != null

	var species_str = _parse_optional_token("+Species:") # FS2 uses '+' prefix here
	if species_str != null:
		persona_data.species_index = GlobalConstants.lookup_species_index(species_str) # Use GlobalConstants lookup
		if persona_data.species_index == -1:
			# Warning already printed by lookup function
			persona_data.species_index = 0 # Default to Terran (index 0)
	else:
		persona_data.species_index = 0 # Default to Terran if not specified

	return persona_data


# --- Message Parsing Helper ---
func _parse_single_message() -> MessageData:
	"""Parses one $Name: block for a message instance."""
	var message_data = MessageData.new()

	var name_str = _parse_required_token("$Name:")
	if name_str == null: return null
	message_data.name = name_str

	# Optional Team
	var team_str = _parse_optional_token("$Team:")
	if team_str != null:
		message_data.multi_team = GlobalConstants.lookup_iff_index(team_str) # Use GlobalConstants lookup
	else:
		message_data.multi_team = -1 # Default to all teams

	# Message Text (can be $Message: or $MessageNew:)
	var msg_token = _parse_optional_token("$Message:")
	if msg_token != null:
		message_data.message_text = msg_token # Single line message
	else:
		# Consume $MessageNew: token before parsing multi-text
		if not _parse_required_token("$MessageNew:"): return null
		message_data.message_text = _parse_multitext()

	# Optional Persona
	var persona_name_str = _parse_optional_token("+Persona:")
	if persona_name_str:
		message_data.persona_index = GlobalConstants.lookup_persona_index(persona_name_str)
		if message_data.persona_index == -1:
			# Warning already printed by lookup function
			pass # Keep index as -1
	else:
		message_data.persona_index = -1

	# Optional AVI Name
	var avi_str = _parse_optional_token("+AVI Name:")
	if avi_str != null and avi_str.to_lower() != "none":
		# Assuming AVI becomes a spritesheet PNG
		message_data.avi_filename = "res://assets/animations/" + avi_str.get_basename() + ".png"
	else:
		message_data.avi_filename = ""

	# Optional Wave Name
	var wave_str = _parse_optional_token("+Wave Name:")
	if wave_str != null and wave_str.to_lower() != "none":
		# Assuming voice files are converted to .ogg
		message_data.wave_filename = "res://assets/voices/" + wave_str.get_basename() + ".ogg"
	else:
		message_data.wave_filename = ""

	return message_data
