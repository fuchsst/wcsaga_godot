class_name WCSWeaponParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for weapons.tbl files.
## Converts weapon data into WeaponData resources.

func _parse_content() -> Variant:
	var weapons: Array[WCSWeaponData] = []
	
	_current_line_index = 0
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
			
		if line.begins_with("$Name:"):
			var weapon = _parse_weapon(line)
			weapons.append(weapon)
			
	return weapons

func _parse_weapon(first_line: String) -> WCSWeaponData:
	var weapon = WCSWeaponData.new()
	weapon.weapon_class = _extract_string_value(first_line, "$Name:")
	weapon.display_name = weapon.weapon_class # Default
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		if line.begins_with("+Title:"):
			weapon.display_name = _extract_string_value(line, "+Title:")
		elif line.begins_with("+Tech Description:"):
			weapon.tech_description = _parse_multiline_text()
		elif line.begins_with("+Description:"):
			if weapon.tech_description.is_empty():
				weapon.tech_description = _parse_multiline_text()
			else:
				_parse_multiline_text() # Consume but ignore if tech desc exists
		elif line.begins_with("$Damage:"):
			weapon.base_damage_energy = _extract_float_value(line, "$Damage:")
		elif line.begins_with("$Mass:"):
			weapon.projectile_mass_kg = _extract_float_value(line, "$Mass:")
		elif line.begins_with("$Velocity:"):
			weapon.muzzle_velocity_mps = _extract_float_value(line, "$Velocity:")
		elif line.begins_with("$Fire Wait:"):
			var fire_wait = _extract_float_value(line, "$Fire Wait:")
			if fire_wait > 0:
				weapon.fire_rate_hz = 1.0 / fire_wait
		elif line.begins_with("$Life:"):
			weapon.projectile_lifetime = _extract_float_value(line, "$Life:")
		elif line.begins_with("$Weapon Range:"):
			weapon.effective_range_meters = _extract_float_value(line, "$Weapon Range:")
		elif line.begins_with("$Model File:"):
			weapon.projectile_model = _extract_string_value(line, "$Model File:")
		elif line.begins_with("$Icon:"):
			weapon.display_icon = _extract_string_value(line, "$Icon:")
		elif line.begins_with("$Anim:"):
			weapon.tech_animation = _extract_string_value(line, "$Anim:")
		elif line.begins_with("$Launch Snd:"):
			weapon.launch_sound_id = _extract_int_value(line, "$Launch Snd:")
		elif line.begins_with("$Impact Snd:"):
			weapon.impact_sound_id = _extract_int_value(line, "$Impact Snd:")
		elif line.begins_with("$Flyby Snd:"):
			weapon.flyby_sound_id = _extract_int_value(line, "$Flyby Snd:")
			
	# Calculate derived values if missing
	if weapon.effective_range_meters == 0 and weapon.muzzle_velocity_mps > 0 and weapon.projectile_lifetime > 0:
		weapon.effective_range_meters = weapon.muzzle_velocity_mps * weapon.projectile_lifetime
			
	return weapon

func _parse_multiline_text() -> String:
	var text = ""
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$end_multi_text"):
			_get_next_line() # Consume end marker
			break
		text += _get_next_line() + "\n"
	return text.strip_edges()
