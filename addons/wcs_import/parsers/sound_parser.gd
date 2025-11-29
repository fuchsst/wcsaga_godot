class_name WCSSoundParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const AudioConfigResource = preload("res://scripts/resources/sounds/audio_config_resource.gd")

func _parse_content() -> Variant:
	var audio_config = AudioConfigResource.new()
	var current_section = ""
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			current_section = line
			continue
			
		if current_section == "#Game Sounds":
			# Parse game sounds
			pass
		elif current_section == "#Interface Sounds":
			# Parse interface sounds
			pass
				
	return audio_config
