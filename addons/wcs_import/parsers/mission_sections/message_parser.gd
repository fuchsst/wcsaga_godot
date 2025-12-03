class_name MessageParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Messages section (#Messages)
## Handles mission messages, text, audio, and video

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const MissionMessage = preload("res://scripts/resources/missions/mission_message.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Messages are parsed one at a time, each starting with $Name:
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_get_next_line()
			continue
		
		# Each message starts with $Name:
		if line.begins_with("$Name:"):
			_parse_single_message(manifest)
		else:
			_get_next_line() # Skip unexpected lines
	
	return _base_parser._current_line_index


func _parse_single_message(manifest: Resource):
	var msg = MissionMessage.new()
	
	# First line is the name
	var name_line = _get_next_line()
	msg.name = _extract_string_value(name_line, "$Name:")
	
	# Parse message properties until we hit the next $Name: or section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next message or section
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse each field
		_parse_message_field(line, msg)
	
	# Add to manifest
	manifest.messages.append(msg)


func _parse_message_field(line: String, msg: MissionMessage):
	if line.begins_with("$Team:"):
		var team_str = _extract_string_value(line, "$Team:")
		msg.team = _map_team(team_str)
	
	elif line.begins_with("$MessageNew:"):
		msg.message_text = _clean_xstr(_extract_string_value(line, "$MessageNew:"))
	
	elif line.begins_with("$Persona:"):
		msg.persona_name = _extract_string_value(line, "$Persona:")
	
	elif line.begins_with("$AVI Name:"):
		var avi_name = _extract_string_value(line, "$AVI Name:")
		msg.avi_file = _load_video_stream(avi_name)
	
	elif line.begins_with("$Wave Name:"):
		var wave_name = _extract_string_value(line, "$Wave Name:")
		msg.wave_file = _load_audio_stream(wave_name)
