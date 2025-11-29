class_name WCSMessageParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const MessageResource = preload("res://scripts/resources/ui/localisation/message_resource.gd")

func _parse_content() -> Variant:
	var message_resource = MessageResource.new()
	var current_message = ""
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Name:"):
			current_message = _extract_string_value(line, "$Name:")
		elif line.begins_with("$Message:"):
			var msg_text = _extract_string_value(line, "$Message:")
			if current_message != "":
				message_resource.messages[current_message] = msg_text
				
	return message_resource
