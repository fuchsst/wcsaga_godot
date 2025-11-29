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
			var raw_name = _extract_string_value(line, "$Name:")
			current_fireball.name = raw_name.split(";")[0].strip_edges()
			
			# Assign default type based on index
			var index = fireballs.size()
			if index == 0:
				current_fireball.render_type = FireballResource.FireballType.EXPLOSION_MEDIUM
			elif index == 1:
				current_fireball.render_type = FireballResource.FireballType.WARP
				current_fireball.is_warp = true
			elif index == 2:
				current_fireball.render_type = FireballResource.FireballType.KNOSSOS
				current_fireball.is_warp = true
			elif index == 3:
				current_fireball.render_type = FireballResource.FireballType.ASTEROID
			elif index == 4:
				current_fireball.render_type = FireballResource.FireballType.EXPLOSION_LARGE1
			elif index == 5:
				current_fireball.render_type = FireballResource.FireballType.EXPLOSION_LARGE2
			else:
				current_fireball.render_type = FireballResource.FireballType.CUSTOM
				
			fireballs.append(current_fireball)
		elif current_fireball:
			if line.begins_with("$LOD:"):
				var raw_lod = _extract_string_value(line, "$LOD:")
				current_fireball.lod_levels = raw_lod.split(";")[0].strip_edges().to_int()
			elif line.begins_with("+Texture:"):
				# We might need to load the texture here or just store the path
				# For now, let's assume we store the path or a placeholder
				pass
			elif line.begins_with("+Explosion_Medium"):
				current_fireball.render_type = FireballResource.FireballType.EXPLOSION_MEDIUM
			elif line.begins_with("+Warp_Effect"):
				current_fireball.render_type = FireballResource.FireballType.WARP
				current_fireball.is_warp = true
			elif line.begins_with("+Knossos_Effect"):
				current_fireball.render_type = FireballResource.FireballType.KNOSSOS
				current_fireball.is_warp = true
			elif line.begins_with("+Asteroid"):
				current_fireball.render_type = FireballResource.FireballType.ASTEROID
			elif line.begins_with("+Explosion_Large1"):
				current_fireball.render_type = FireballResource.FireballType.EXPLOSION_LARGE1
			elif line.begins_with("+Explosion_Large2"):
				current_fireball.render_type = FireballResource.FireballType.EXPLOSION_LARGE2
			elif line.begins_with("+Custom_Fireball"):
				current_fireball.render_type = FireballResource.FireballType.CUSTOM
				
	return fireballs
