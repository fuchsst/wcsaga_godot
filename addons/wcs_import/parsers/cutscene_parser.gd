class_name WCSCutsceneParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const CutsceneResource = preload("res://scripts/resources/cutscenes/cutscene_resource.gd")

func _parse_content() -> Variant:
	var cutscenes: Array[CutsceneResource] = []
	var current_cutscene: CutsceneResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Filename:"):
			current_cutscene = CutsceneResource.new()
			current_cutscene.filename = _extract_string_value(line, "$Filename:")
			cutscenes.append(current_cutscene)
		elif current_cutscene:
			if line.begins_with("$Name:"):
				current_cutscene.name = _extract_string_value(line, "$Name:")
			elif line.begins_with("$Description:"):
				current_cutscene.description = _extract_string_value(line, "$Description:")
				
	return cutscenes
