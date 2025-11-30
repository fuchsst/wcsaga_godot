class_name WCSWeaponParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for weapons.tbl files.
## Converts weapon data into WeaponData resources.
const WCSWeaponData = preload("res://scripts/resources/weapons/weapon_data.gd")
func _parse_content() -> Variant:
	var weapons: Array[WCSWeaponData] = []
	
	_current_line_index = 0
	
	var current_category = ""
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
			
		if line.begins_with("#"):
			current_category = line.trim_prefix("#").strip_edges()
			continue
			
		if line.begins_with("$Name:"):
			var weapon = _parse_weapon(line)
			weapon.category = current_category
			weapons.append(weapon)
			
	return weapons

func _parse_weapon(first_line: String) -> WCSWeaponData:
	var weapon = WCSWeaponData.new()
	weapon.weapon_class = _extract_string_value(first_line, "$Name:")
	weapon.display_name = weapon.weapon_class # Default
	weapon.manufacturer_species = "Terran" # Default to Terran as TBL doesn't specify
	
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
			
		_get_next_line() # Consume
		
		elif line.begins_with("+Title:"):
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
		elif line.begins_with("$Weapon Range:") or line.begins_with("+Weapon Range:"):
			weapon.effective_range_meters = _extract_float_value(line, "$Weapon Range:", "+Weapon Range:")
		elif line.begins_with("$Model File:"):
			weapon.projectile_model = _extract_string_value(line, "$Model File:")
		elif line.begins_with("$Icon:"):
			weapon.display_icon = _extract_string_value(line, "$Icon:")
		elif line.begins_with("$Anim:"):
			weapon.tech_animation = _extract_string_value(line, "$Anim:")
		elif line.begins_with("$Launch Snd:") or line.begins_with("$LaunchSnd:"):
			weapon.launch_sound_id = _extract_int_value(line, "$Launch Snd:", "$LaunchSnd:")
		elif line.begins_with("$Impact Snd:") or line.begins_with("$ImpactSnd:"):
			weapon.impact_sound_id = _extract_int_value(line, "$Impact Snd:", "$ImpactSnd:")
		elif line.begins_with("$Flyby Snd:") or line.begins_with("$FlybySnd:"):
			weapon.flyby_sound_id = _extract_int_value(line, "$Flyby Snd:", "$FlybySnd:")
		elif line.begins_with("$Flags:"):
			_parse_flags(line, weapon)
		elif line.begins_with("$Armor Factor:"):
			weapon.armor_penetration_factor = _extract_float_value(line, "$Armor Factor:")
		elif line.begins_with("$Shield Factor:"):
			weapon.shield_penetration_factor = _extract_float_value(line, "$Shield Factor:")
		elif line.begins_with("$Subsystem Factor:"):
			weapon.subsystem_damage_factor = _extract_float_value(line, "$Subsystem Factor:")
		elif line.begins_with("$Energy Consumed:"):
			weapon.energy_per_shot = _extract_float_value(line, "$Energy Consumed:")
		elif line.begins_with("$Cargo Size:"):
			weapon.cargo_size_units = _extract_float_value(line, "$Cargo Size:")
		elif line.begins_with("$Homing:"):
			var homing_val = _extract_string_value(line, "$Homing:")
			if homing_val == "YES": weapon.homing_type = 1 # Default to Aspect? Or Heat? Usually implies homing capability
			elif homing_val == "NO": weapon.homing_type = 0
			elif homing_val == "ASPECT": weapon.homing_type = 1
			elif homing_val == "HEAT": weapon.homing_type = 2
		elif line.begins_with("$Impact Explosion:"):
			weapon.impact_explosion = _extract_string_value(line, "$Impact Explosion:")
		elif line.begins_with("$Impact Explosion Radius:"):
			weapon.impact_explosion_radius = _extract_float_value(line, "$Impact Explosion Radius:")
		elif line.begins_with("$Swarm:"):
			weapon.swarm_count = _extract_int_value(line, "$Swarm:")
		elif line.begins_with("$SwarmWait:"):
			weapon.swarm_wait = _extract_float_value(line, "$SwarmWait:")
		elif line.begins_with("$Free Flight Time:"):
			weapon.free_flight_time = _extract_float_value(line, "$Free Flight Time:")
		elif line.begins_with("$Turn Time:"):
			weapon.turn_time = _extract_float_value(line, "$Turn Time:")
			if weapon.turn_time > 0:
				weapon.max_turn_rate_dps = 360.0 / weapon.turn_time
		elif line.begins_with("$Shockwave damage:"):
			weapon.explosion_damage = _extract_float_value(line, "$Shockwave damage:")
		elif line.begins_with("$Blast Force:"):
			# Not currently mapped in WeaponData, but could be added
			pass
		elif line.begins_with("$Inner Radius:"):
			# Map to blast_radius for now, or add specific inner/outer
			weapon.blast_radius = _extract_float_value(line, "$Inner Radius:")
		elif line.begins_with("$Outer Radius:"):
			# If we only have one radius, maybe use outer?
			var outer = _extract_float_value(line, "$Outer Radius:")
			if outer > weapon.blast_radius:
				weapon.blast_radius = outer
		elif line.begins_with("$Shockwave Speed:"):
			weapon.shockwave_speed = _extract_float_value(line, "$Shockwave Speed:")
		elif line.begins_with("$Spawn Angle:"):
			weapon.spawn_angle = _extract_float_value(line, "$Spawn Angle:")
		elif line.begins_with("$Rearm Rate:"):
			weapon.rearm_rate = _extract_float_value(line, "$Rearm Rate:")
		elif line.begins_with("+Min Lock Time:"):
			weapon.min_lock_time = _extract_float_value(line, "+Min Lock Time:")
		elif line.begins_with("+View Cone:"):
			weapon.view_cone_degrees = _extract_float_value(line, "+View Cone:")
		elif line.begins_with("$Trail:"):
			_parse_trail_info(weapon)
		elif line.begins_with("$Pspew:"):
			_parse_pspew_info(weapon)
		elif line.begins_with("$BeamInfo:"):
			_parse_beam_info(weapon)
			
	# Calculate derived values if missing
	if weapon.effective_range_meters == 0 and weapon.muzzle_velocity_mps > 0 and weapon.projectile_lifetime > 0:
		weapon.effective_range_meters = weapon.muzzle_velocity_mps * weapon.projectile_lifetime
			
	return weapon

func _parse_beam_info(weapon: WCSWeaponData) -> void:
	if weapon.beam_config == null:
		weapon.beam_config = WCSWeaponData.BeamConfiguration.new()
		
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Section:"):
			# Beam sections logic could go here, for now consume
			_get_next_line()
			continue
			
		if line.begins_with("$Name:") or line.begins_with("#"):
			break # End of weapon
			
		line = _get_next_line()
		
		if line.begins_with("+Type:"):
			weapon.beam_config.beam_type = _extract_int_value(line, "+Type:")
		elif line.begins_with("+Life:"):
			weapon.beam_config.beam_life = _extract_float_value(line, "+Life:")
		elif line.begins_with("+Warmup:"):
			weapon.beam_config.beam_warmup = _extract_float_value(line, "+Warmup:") / 1000.0 # ms to s
		elif line.begins_with("+Warmdown:"):
			weapon.beam_config.beam_warmdown = _extract_float_value(line, "+Warmdown:") / 1000.0 # ms to s
		elif line.begins_with("+Radius:"):
			weapon.beam_config.beam_width = _extract_float_value(line, "+Radius:") * 2.0
		elif line.begins_with("+Range:"):
			weapon.beam_config.range_multiplier = 1.0 # Range is usually absolute in TBL?
			# If TBL has +Range, it overrides standard range logic
			var range_val = _extract_float_value(line, "+Range:")
			if range_val > 0:
				weapon.effective_range_meters = range_val
		elif line.begins_with("+P Count:"):
			# Particle count
			pass

func _parse_trail_info(weapon: WCSWeaponData) -> void:
	if weapon.trail_config == null:
		weapon.trail_config = WCSWeaponData.TrailConfiguration.new()
		
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
		
		# Check if we exited the trail block (usually implicit or next section)
		# But Trail block usually has +Bitmap, +Start Width etc.
		if not (line.strip_edges().begins_with("+") or line.strip_edges().is_empty()):
			# If it doesn't start with +, it might be next field
			break
			
		line = _get_next_line()
		
		if line.begins_with("+Bitmap:"):
			weapon.trail_config.bitmap = _extract_string_value(line, "+Bitmap:")
		elif line.begins_with("+Start Width:"):
			weapon.trail_config.start_width = _extract_float_value(line, "+Start Width:")
		elif line.begins_with("+End Width:"):
			weapon.trail_config.end_width = _extract_float_value(line, "+End Width:")
		elif line.begins_with("+Start Alpha:"):
			weapon.trail_config.start_alpha = _extract_float_value(line, "+Start Alpha:")
		elif line.begins_with("+End Alpha:"):
			weapon.trail_config.end_alpha = _extract_float_value(line, "+End Alpha:")
		elif line.begins_with("+Max Life:"):
			weapon.trail_config.max_life = _extract_float_value(line, "+Max Life:")

func _parse_pspew_info(weapon: WCSWeaponData) -> void:
	if weapon.particle_spew == null:
		weapon.particle_spew = WCSWeaponData.ParticleSpew.new()
		
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
			
		if not (line.strip_edges().begins_with("+") or line.strip_edges().is_empty()):
			break
			
		line = _get_next_line()
		
		if line.begins_with("+Count:"):
			weapon.particle_spew.count = _extract_int_value(line, "+Count:")
		elif line.begins_with("+Time:"):
			weapon.particle_spew.time = _extract_int_value(line, "+Time:")
		elif line.begins_with("+Vel:"):
			weapon.particle_spew.velocity = _extract_float_value(line, "+Vel:")
		elif line.begins_with("+Radius:"):
			weapon.particle_spew.radius = _extract_float_value(line, "+Radius:")
		elif line.begins_with("+Life:"):
			weapon.particle_spew.lifetime = _extract_float_value(line, "+Life:")
		elif line.begins_with("+Scale:"):
			weapon.particle_spew.scale = _extract_float_value(line, "+Scale:")
		elif line.begins_with("+Bitmap:"):
			weapon.particle_spew.bitmap = _extract_string_value(line, "+Bitmap:")

func _parse_flags(line: String, weapon: WCSWeaponData) -> void:
	var flags_str = _extract_string_value(line, "$Flags:")
	# Remove parens and quotes
	flags_str = flags_str.replace("(", "").replace(")", "").replace("\"", "")
	var flags_list = flags_str.split(" ", false)
	
	for flag in flags_list:
		match flag:
			"player allowed": weapon.is_player_allowed = true
			"in tech database": weapon.appears_in_tech_db = true
			"beam": weapon.is_beam = true
			"stream": weapon.fire_rate_hz = 10.0 # Arbitrary high rate for stream? Or handle differently
			"no pierce shields": weapon.no_shield_piercing = true
			"bomb": weapon.is_bomb_type = true
			"huge": weapon.is_huge_weapon = true
			"particle spew":
				if weapon.particle_spew == null:
					weapon.particle_spew = WCSWeaponData.ParticleSpew.new()
			# Add other flags as needed

func _parse_multiline_text() -> String:
	var text = ""
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$end_multi_text"):
			_get_next_line() # Consume end marker
			break
		text += _get_next_line() + "\n"
	return text.strip_edges()
