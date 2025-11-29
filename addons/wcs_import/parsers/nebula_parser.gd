class_name WCSNebulaParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const NebulaData = preload("res://scripts/resources/environment/nebula/nebula_data.gd")

func _parse_content() -> Variant:
	var nebula_data = NebulaData.new()
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Nebula:"):
			# Parse nebula definition
			pass
		elif line.begins_with("+Texture:"):
			nebula_data.nebula_texture = _extract_string_value(line, "+Texture:")
			
	return nebula_data
