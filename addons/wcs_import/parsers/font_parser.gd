class_name WCSFontParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const FontConfig = preload("res://scripts/resources/ui/fonts/font_config.gd")

func _parse_content() -> Variant:
	var font_config = FontConfig.new()
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Font:"):
			font_config.fonts.append(_extract_string_value(line, "$Font:"))
			
	return font_config
