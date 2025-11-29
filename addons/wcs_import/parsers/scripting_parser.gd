class_name WCSScriptingParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const ScriptingResource = preload("res://scripts/resources/scripting/scripting_resource.gd")

func _parse_content() -> Variant:
	var scripting_resource = ScriptingResource.new()
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Script:"):
			# Parse script definition
			pass
				
	return scripting_resource
