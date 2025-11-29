class_name WCSFireballParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const FireballResource = preload("res://scripts/resources/effects/fireball/fireball_resource.gd")

func _parse_content() -> Variant:
	var fireballs: Array[FireballResource] = []
	var current_fireball: FireballResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Name:"):
			current_fireball = FireballResource.new()
			current_fireball.name = _extract_string_value(line, "$Name:")
			fireballs.append(current_fireball)
		elif current_fireball:
			if line.begins_with("$LOD:"):
				current_fireball.lod_count = _extract_int_value(line, "$LOD:")
			elif line.begins_with("+Texture:"):
				# We might need to load the texture here or just store the path
				# For now, let's assume we store the path or a placeholder
				pass
				
	return fireballs
