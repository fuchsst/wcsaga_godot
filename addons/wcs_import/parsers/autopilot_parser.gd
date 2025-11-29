class_name WCSAutopilotParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const AutopilotRes = preload("res://scripts/resources/ui/localisation/autopilot_resource.gd")

func _parse_content() -> Variant:
	var res = AutopilotRes.new()
	
	_skip_empty_lines()
	while _has_more_lines():
		var line = _get_next_line()
		if line.begins_with("$Link Distance:"):
			res.link_distance = _extract_float_value(line, "$Link Distance:")
		elif line.begins_with("$Gliding Speed:"):
			res.gliding_speed = _extract_float_value(line, "$Gliding Speed:")
			
	return res
