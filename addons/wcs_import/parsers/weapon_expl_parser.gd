class_name WCSWeaponExplParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const WeaponExplosionResource = preload("res://scripts/resources/effects/explosions/weapon_expl_resource.gd")

func _parse_content() -> Variant:
	var explosions: Array[WeaponExplosionResource] = []
	var current_explosion: WeaponExplosionResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Name:"):
			current_explosion = WeaponExplosionResource.new()
			current_explosion.name = _extract_string_value(line, "$Name:")
			explosions.append(current_explosion)
		elif current_explosion:
			if line.begins_with("$LOD:"):
				current_explosion.lod_count = _extract_int_value(line, "$LOD:")
				
	return explosions
