class_name WCSCreditsParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const CreditsResource = preload("res://scripts/resources/ui/localisation/credits_resource.gd")

func _parse_content() -> Variant:
	var credits_resource = CreditsResource.new()
	var current_section = ""
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		if line.begins_with("#"):
			if line == "#end":
				break
			current_section = line
			continue
			
		if current_section == "#Credits":
			# Credits are usually just raw text lines
			if not line.begins_with(";"):
				credits_resource.credits_text += line + "\n"
				
	return credits_resource
