class_name WCSMainhallParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const MainhallResource = preload("res://scripts/resources/ui/menus/mainhall_resource.gd")

func _parse_content() -> Variant:
	var mainhall_resource = MainhallResource.new()
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Main Hall"):
			# Parse main hall definition
			pass
		elif line.begins_with("+Bitmap:"):
			mainhall_resource.bitmap = _extract_string_value(line, "+Bitmap:")
		elif line.begins_with("+Music:"):
			mainhall_resource.music = _extract_string_value(line, "+Music:")
			
	return mainhall_resource
