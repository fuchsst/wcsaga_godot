class_name WCSHelpParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const HelpResource = preload("res://scripts/resources/ui/localisation/help_resource.gd")

func _parse_content() -> Variant:
	var help_resource = HelpResource.new()
	var current_topic = ""
	var current_text = ""
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$"):
			# New topic usually starts with $
			if current_topic != "":
				help_resource.topics[current_topic] = current_text
			current_topic = line.substr(1).strip_edges()
			current_text = ""
		else:
			current_text += line + "\n"
			
	if current_topic != "":
		help_resource.topics[current_topic] = current_text
		
	return help_resource
