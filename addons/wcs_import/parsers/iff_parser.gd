class_name WCSIffParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const IffResource = preload("res://scripts/resources/iff_defs/iff_resource.gd")

func _parse_content() -> Variant:
	var iff_defs: Array[IffResource] = []
	var current_iff: IffResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$IFF Name:"):
			current_iff = IffResource.new()
			current_iff.iff_name = _extract_string_value(line, "$IFF Name:")
			iff_defs.append(current_iff)
		elif current_iff:
			if line.begins_with("$Color:"):
				current_iff.color = _parse_color(line)
			elif line.begins_with("+Flags:"):
				# Parse flags if needed
				pass
				
	return iff_defs
