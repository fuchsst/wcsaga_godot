# migration_tools/gdscript_converters/tbl_converters/ships_tbl_converter.gd
@tool
extends RefCounted # Use RefCounted for now, maybe BaseTblParser later
class_name ShipsTblConverter

# --- Dependencies ---
const ShipData = preload("res://scripts/resources/ship_weapon/ship_data.gd")
const SubsystemDefinition = preload("res://scripts/resources/ship_weapon/subsystem_definition.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For flags, species, etc.

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0
var _output_dir: String = "res://resources/ships" # Default output

# --- Main Parse Function ---
# Takes the full list of lines from ships.tbl.
# Returns true on success, false on failure.
func convert(lines_array: PackedStringArray, output_directory: String) -> bool:
	_lines = lines_array
	_current_line_num = 0
	_output_dir = output_directory
	var success = true

	print("Parsing ships.tbl...")

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(_output_dir)

	# Skip to the start of ship definitions
	if not _skip_to_token("#Ship Classes"):
		printerr("Error: '#Ship Classes' marker not found in ships.tbl")
		return false

	# Loop through each ship definition
	while _peek_line() != null and not _peek_line().begins_with("#End"):
		if _peek_line().begins_with("$Name:"):
			var ship_data: ShipData = _parse_single_ship()
			if ship_data:
				# Save the resource
				var output_path = _output_dir.path_join(ship_data.ship_name.to_lower().replace(" ", "_") + ".tres")
				var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
				var save_result = ResourceSaver.save(ship_data, output_path, save_flags)
				if save_result != OK:
					printerr(f"Error saving ShipData resource '{output_path}': {save_result}")
					success = false
				else:
					print(f"Saved: {output_path}")
			else:
				printerr(f"Failed to parse ship definition starting near line {_current_line_num}.")
				success = false
				# Attempt to recover by skipping to the next potential ship start
				_skip_to_next_section_or_token("$Name:")
		else:
			# Unexpected line, consume and warn
			var line = _read_line()
			if line != null and not line.is_empty(): # Avoid warning on trailing empty lines
				printerr(f"Warning: Unexpected line in ships.tbl: '{line}' at line {_current_line_num}")

	print("Finished parsing ships.tbl.")
	return success

# --- Ship Parsing Helper ---
func _parse_single_ship() -> ShipData:
	"""Parses one $Name: block for a ship definition."""
	var ship_data = ShipData.new()

	# --- Required Basic Info ---
	var name_str = _parse_required_token("$Name:")
	if name_str == null: return null
	ship_data.ship_name = name_str.trim_prefix("+") # Handle potential '+' prefix

	var pof_str = _parse_required_token("$POF file:")
	if pof_str == null: return null
	ship_data.pof_file = pof_str

	var hull_str = _parse_required_token("$Shields:") # Actually Hull in FS2 tables
	if hull_str == null: return null
	ship_data.max_hull_strength = hull_str.to_float()

	var shield_str = _parse_required_token("+Shields:") # This is Shields
	if shield_str == null: return null
	ship_data.max_shield_strength = shield_str.to_float()

	# --- Optional Basic Info ---
	ship_data.alt_name = _parse_optional_token("$Alt Name:") or ""
	ship_data.short_name = _parse_optional_token("$Short Name:") or ""
	# TODO: Species lookup
	var species_str = _parse_optional_token("$Species:") or "Terran"
	ship_data.species = GlobalConstants.species_list.find(species_str) if GlobalConstants.has("species_list") else 0
	# TODO: Class Type lookup
	var class_type_str = _parse_optional_token("$Class Type:") or ""
	# ship_data.class_type = GlobalConstants.lookup_ship_type_index(class_type_str) # Placeholder
	ship_data.manufacturer = _parse_optional_token("$Manufacturer:") or ""
	ship_data.description = _parse_optional_token("$Description:") or ""
	ship_data.tech_description = _parse_optional_token("$Tech Description:") or ""
	ship_data.ship_length = _parse_optional_token("$Length:") or ""

	# --- Models & Visuals ---
	ship_data.pof_file_hud = _parse_optional_token("$POF file HUD:") or ship_data.pof_file # Default to main POF
	ship_data.cockpit_pof_file = _parse_optional_token("$Cockpit POF file:") or ""
	var cockpit_offset_str = _parse_optional_token("$Cockpit Offset:")
	if cockpit_offset_str != null: ship_data.cockpit_offset = _parse_vector(cockpit_offset_str)
	# Detail Distances (FS2 uses single value, map to array?)
	var detail_dist_str = _parse_optional_token("$Detail Distance:")
	if detail_dist_str != null: ship_data.detail_distances = [detail_dist_str.to_int()] # Store as single element array for now
	ship_data.hud_target_lod = int(_parse_optional_token("$LOD:") or "0")
	ship_data.icon_filename = _parse_optional_token("$Icon:") or ""
	ship_data.anim_filename = _parse_optional_token("$ANI file:") or ""
	# Overhead filename not directly in ships.tbl? Might be derived or elsewhere.
	# Thruster bitmaps
	ship_data.thruster_bitmap = _parse_optional_token("$Thruster Flame:") or ""
	ship_data.thruster_glow_bitmap = _parse_optional_token("$Thruster Glow:") or ""
	ship_data.thruster_secondary_glow_bitmap = _parse_optional_token("$Thruster Secondary Glow:") or ""
	ship_data.thruster_tertiary_glow_bitmap = _parse_optional_token("$Thruster Tertiary Glow:") or ""
	# Afterburner trail
	ship_data.afterburner_trail_bitmap = _parse_optional_token("$Afterburner Trail:") or ""
	# Shield color (R, G, B)
	var shield_color_str = _parse_optional_token("$Shield Color:")
	if shield_color_str != null:
		var parts = shield_color_str.split(" ", false)
		if parts.size() == 3:
			ship_data.shield_color = Color8(int(parts[0]), int(parts[1]), int(parts[2]))
	# Radar image index/size
	var radar_img_str = _parse_optional_token("$Radar Image:")
	if radar_img_str != null:
		var parts = radar_img_str.split(",", false)
		if parts.size() == 2:
			ship_data.radar_image_2d_idx = parts[0].strip_edges().to_int()
			ship_data.radar_image_size = parts[1].strip_edges().to_int()
	var radar_proj_str = _parse_optional_token("$Radar Projection Multiplier:")
	if radar_proj_str != null: ship_data.radar_projection_size_mult = radar_proj_str.to_float()
	# Closeup pos/zoom
	var closeup_pos_str = _parse_optional_token("$Closeup Pos:")
	if closeup_pos_str != null: ship_data.closeup_pos = _parse_vector(closeup_pos_str)
	var closeup_zoom_str = _parse_optional_token("$Closeup Zoom:")
	if closeup_zoom_str != null: ship_data.closeup_zoom = closeup_zoom_str.to_float()

	# --- Physics ---
	var density_str = _parse_optional_token("$Density:")
	if density_str != null: ship_data.density = density_str.to_float()
	var mass_str = _parse_optional_token("$Mass:")
	if mass_str != null: ship_data.mass = mass_str.to_float()
	var damp_str = _parse_optional_token("$Damp:")
	if damp_str != null: ship_data.damp = damp_str.to_float()
	var rotdamp_str = _parse_optional_token("$Rotdamp:")
	if rotdamp_str != null: ship_data.rotdamp = rotdamp_str.to_float()
	# Max velocities
	var max_vel_str = _parse_optional_token("$Max Velocity:")
	if max_vel_str != null: ship_data.max_vel = _parse_vector(max_vel_str)
	var aburn_max_vel_str = _parse_optional_token("$ABurn Max Vel:")
	if aburn_max_vel_str != null: ship_data.afterburner_max_vel = _parse_vector(aburn_max_vel_str)
	var max_rotvel_str = _parse_optional_token("$Max Rotvelocity:")
	if max_rotvel_str != null: ship_data.max_rotvel = _parse_vector(max_rotvel_str)
	# Accelerations
	var f_accel_str = _parse_optional_token("$Forward Accel:")
	if f_accel_str != null: ship_data.forward_accel = f_accel_str.to_float()
	var ab_f_accel_str = _parse_optional_token("$ABurn Forward Accel:")
	if ab_f_accel_str != null: ship_data.afterburner_forward_accel = ab_f_accel_str.to_float()
	var f_decel_str = _parse_optional_token("$Forward Decel:")
	if f_decel_str != null: ship_data.forward_decel = f_decel_str.to_float()
	var s_accel_str = _parse_optional_token("$Slide Accel:")
	if s_accel_str != null: ship_data.slide_accel = s_accel_str.to_float()
	var s_decel_str = _parse_optional_token("$Slide Decel:")
	if s_decel_str != null: ship_data.slide_decel = s_decel_str.to_float()

	# --- Afterburner ---
	var ab_fuel_str = _parse_optional_token("$ABurn Fuel:")
	if ab_fuel_str != null: ship_data.afterburner_fuel_capacity = ab_fuel_str.to_float()
	var ab_burn_str = _parse_optional_token("$ABurn Burn Rate:")
	if ab_burn_str != null: ship_data.afterburner_burn_rate = ab_burn_str.to_float()
	var ab_rec_str = _parse_optional_token("$ABurn Recharge Rate:")
	if ab_rec_str != null: ship_data.afterburner_recover_rate = ab_rec_str.to_float()

	# --- Hull, Shields, Energy ---
	var power_str = _parse_optional_token("$Power Output:")
	if power_str != null: ship_data.power_output = power_str.to_float()
	var weapon_res_str = _parse_optional_token("$Max Weapon Energy:")
	if weapon_res_str != null: ship_data.max_weapon_reserve = weapon_res_str.to_float()
	var shield_regen_str = _parse_optional_token("$Shield Recharge Rate:")
	if shield_regen_str != null: ship_data.max_shield_regen_per_second = shield_regen_str.to_float()
	var weapon_regen_str = _parse_optional_token("$Weapon Recharge Rate:")
	if weapon_regen_str != null: ship_data.max_weapon_regen_per_second = weapon_regen_str.to_float()
	# TODO: Armor lookup
	var armor_str = _parse_optional_token("$Armor Type:")
	# ship_data.armor_type_idx = GlobalConstants.lookup_armor_index(armor_str) if armor_str else -1
	var shield_armor_str = _parse_optional_token("$Shield Armor Type:")
	# ship_data.shield_armor_type_idx = GlobalConstants.lookup_armor_index(shield_armor_str) if shield_armor_str else -1

	# --- Weapons ---
	var num_primary_str = _parse_required_token("$Primary Banks:")
	if num_primary_str == null: return null
	ship_data.num_primary_banks = num_primary_str.to_int()
	if ship_data.num_primary_banks > 0:
		var pbanks_str = _parse_required_token("$Default PBanks:")
		ship_data.primary_bank_weapons = _parse_weapon_index_list(pbanks_str)
		var pcap_str = _parse_required_token("$PBank Capacity:")
		ship_data.primary_bank_ammo_capacity = _parse_int_list(pcap_str)

	var num_secondary_str = _parse_required_token("$Secondary Banks:")
	if num_secondary_str == null: return null
	ship_data.num_secondary_banks = num_secondary_str.to_int()
	if ship_data.num_secondary_banks > 0:
		var sbanks_str = _parse_required_token("$Default SBanks:")
		ship_data.secondary_bank_weapons = _parse_weapon_index_list(sbanks_str)
		var scap_str = _parse_required_token("$SBank Capacity:")
		ship_data.secondary_bank_ammo_capacity = _parse_int_list(scap_str)

	# Allowed Weapons (complex parsing needed)
	# TODO: Parse $Allowed Weapons: (list of weapon names)
	# TODO: Parse $Restricted Banks: (list of weapon names)
	# TODO: Parse $Allowed PBanks: / $Allowed SBanks: (bank-specific restrictions)

	# --- Countermeasures ---
	var cmeasure_type_str = _parse_optional_token("$Countermeasure:")
	# ship_data.cmeasure_type = GlobalConstants.lookup_weapon_index(cmeasure_type_str) if cmeasure_type_str else -1
	var cmeasure_max_str = _parse_optional_token("$CMeasure Max:")
	if cmeasure_max_str != null: ship_data.cmeasure_max = cmeasure_max_str.to_int()

	# --- AI ---
	var ai_class_str = _parse_optional_token("$AI Class:")
	# ship_data.ai_class = GlobalConstants.lookup_ai_class_index(ai_class_str) if ai_class_str else 0

	# --- Sounds ---
	var engine_snd_str = _parse_optional_token("$Engine Sound:")
	# ship_data.engine_snd = GlobalConstants.lookup_sound_index(engine_snd_str) if engine_snd_str else -1
	# TODO: Parse other sounds ($Warpin Sound Start:, etc.)

	# --- Warp ---
	var warpin_anim_str = _parse_optional_token("$Warpin Anim:")
	if warpin_anim_str != null: ship_data.warpin_anim = warpin_anim_str
	var warpin_rad_str = _parse_optional_token("$Warpin Radius:")
	if warpin_rad_str != null: ship_data.warpin_radius = warpin_rad_str.to_float()
	var warpin_speed_str = _parse_optional_token("$Warpin Speed:")
	if warpin_speed_str != null: ship_data.warpin_speed = warpin_speed_str.to_float()
	# TODO: Parse Warpout fields

	# --- Destruction ---
	var shockwave_str = _parse_optional_token("$Shockwave:")
	if shockwave_str != null:
		# TODO: Parse shockwave parameters (speed, inner, outer, damage, blast)
		print("TODO: Parse shockwave parameters")
	var death_roll_str = _parse_optional_token("$Death Roll Time:")
	if death_roll_str != null: ship_data.death_roll_time = death_roll_str.to_int() * 1000 # s to ms
	# TODO: Parse other destruction fields

	# --- Flags ---
	var flags_str = _parse_optional_token("$Flags:")
	if flags_str != null:
		ship_data.flags = _parse_ship_flags_bitmask(flags_str) # Placeholder
	var flags2_str = _parse_optional_token("$Flags2:")
	if flags2_str != null:
		ship_data.flags2 = _parse_ship_flags2_bitmask(flags2_str) # Placeholder

	# --- Score ---
	var score_str = _parse_optional_token("$Score:")
	if score_str != null: ship_data.score = score_str.to_int()

	# --- Subsystems ---
	ship_data.subsystems.clear() # Ensure the array is empty before parsing
	while _peek_line() != null and _peek_line().begins_with("$Subsystem:"):
		var subsystem_data = _parse_single_subsystem(ship_data.ship_name)
		if subsystem_data:
			ship_data.subsystems.append(subsystem_data)
		else:
			printerr(f"Failed to parse subsystem block starting near line {_current_line_num} for ship {ship_data.ship_name}")
			# Attempt to recover by skipping to the next potential subsystem or major token
			_skip_to_next_section_or_token("$Subsystem:")


	return ship_data


# --- Helper Functions (Duplicated/Adapted for now, move to Base later) ---

func _peek_line() -> String:
	if _current_line_num < _lines.size():
		return _lines[_current_line_num].strip_edges()
	return null

func _read_line() -> String:
	var line = _peek_line()
	if line != null:
		_current_line_num += 1
	return line

func _skip_whitespace_and_comments():
	while true:
		var line = _peek_line()
		if line == null: break
		# Check if line is not null AND not empty AND does not start with ';' or '#'
		if line and not line.is_empty() and not line.begins_with(';') and not line.begins_with('#'):
			break
		_current_line_num += 1 # Consume the empty/comment line

func _parse_required_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _read_line()
	if line == null or not line.begins_with(expected_token):
		printerr(f"Parser Error: Expected '{expected_token}' but got '{line}' at line {_current_line_num}")
		# Backtrack only if we read a line that wasn't the token
		if line != null: _current_line_num -= 1
		return null
	return line.substr(expected_token.length()).strip_edges()

func _parse_optional_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _peek_line()
	if line != null and line.begins_with(expected_token):
		_read_line()
		return line.substr(expected_token.length()).strip_edges()
	return null

func _parse_vector(line_content: String) -> Vector3:
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 3:
		return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	else:
		printerr(f"Error parsing Vector3: '{line_content}'")
		return Vector3.ZERO

func _parse_basis(line_content: String) -> Basis:
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 9:
		var x = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
		var y = Vector3(parts[3].to_float(), parts[4].to_float(), parts[5].to_float())
		var z = Vector3(parts[6].to_float(), parts[7].to_float(), parts[8].to_float())
		return Basis(x, y, z)
	else:
		printerr(f"Error parsing Basis: '{line_content}'")
		return Basis.IDENTITY

func _parse_multitext() -> String:
	# Assumes the token line ($Notes: or $Description:) was already consumed
	var text_lines: PackedStringArray = []
	while true:
		var line = _peek_line() # Peek first
		if line == null:
			printerr("Error: Unexpected end of file while parsing multi-text")
			break
		# Stop if we hit the next known token starting with '$' or a new section '#'
		if line.begins_with("$") or line.begins_with("#"):
			break
		text_lines.append(_read_line()) # Consume the content line
	return "\n".join(text_lines)

func _parse_int_list(list_string: String) -> Array[int]:
	var result: Array[int] = []
	var content = list_string.trim_prefix("(").trim_suffix(")").strip_edges()
	if content.is_empty(): return result
	var parts = content.split(",", false)
	for part in parts:
		var clean_part = part.strip_edges()
		if clean_part.is_valid_int():
			result.append(clean_part.to_int())
		else:
			printerr(f"Error parsing int list item: '{clean_part}'")
	return result

func _parse_weapon_index_list(list_string: String) -> Array[int]:
	var result: Array[int] = []
	var content = list_string.trim_prefix("(").trim_suffix(")").strip_edges()
	if content.is_empty(): return result
	var parts = content.split(",", false)
	for part in parts:
		var weapon_name = part.strip_edges().trim_prefix('"').trim_suffix('"')
		# TODO: Lookup weapon_name in GlobalConstants.weapon_list
		var weapon_index = GlobalConstants.weapon_list.find(weapon_name) if GlobalConstants.has("weapon_list") else -1 # Placeholder
		if weapon_index == -1:
			printerr(f"Could not find weapon index for '{weapon_name}' in list.")
		result.append(weapon_index)
	return result

func _parse_ship_flags_bitmask(flags_string: String) -> int:
	# Placeholder: Needs actual implementation to parse flag names and OR bits
	# based on SIF_* constants
	print(f"Warning: Ship flag parsing not implemented for: {flags_string}")
	return 0

func _parse_ship_flags2_bitmask(flags_string: String) -> int:
	# Placeholder: Needs actual implementation to parse flag names and OR bits
	# based on SIF2_* constants
	print(f"Warning: Ship flag2 parsing not implemented for: {flags_string}")
	return 0

func _skip_to_next_section_or_token(token: String):
	"""Skips lines until the specified token or a section marker '#' or EOF."""
	while true:
		var line = _peek_line()
		if line == null or line.begins_with(token) or line.begins_with("#"):
			break
		_read_line()

# --- Subsystem Parsing Helper ---
func _parse_single_subsystem(ship_name_for_error: String) -> SubsystemDefinition:
	"""Parses one $Subsystem: block."""
	var subsys_data = SubsystemDefinition.new()

	var subsys_line = _parse_required_token("$Subsystem:")
	if subsys_line == null: return null

	# Parse the main subsystem line: Name, HP, Repair Points
	var parts = subsys_line.split(",", false)
	if parts.size() < 3:
		printerr(f"Error: Malformed $Subsystem line for ship '{ship_name_for_error}' near line {_current_line_num}: '{_lines[_current_line_num-1]}'")
		return null
	subsys_data.subobj_name = parts[0].strip_edges()
	subsys_data.max_subsys_strength = parts[1].strip_edges().to_float()
	# Repair points are ignored for now, but we parse it
	# subsys_data.repair_points = parts[2].strip_edges().to_float()

	# Optional fields within the subsystem block
	subsys_data.alt_sub_name = _parse_optional_token("+Alt Subsystem Name:") or ""
	subsys_data.alt_dmg_sub_name = _parse_optional_token("+Alt Damaged Subsystem Name:") or ""
	# TODO: Armor lookup
	var armor_str = _parse_optional_token("+Armor Type:")
	# subsys_data.armor_type_idx = GlobalConstants.lookup_armor_index(armor_str) if armor_str else -1
	var turn_rate_str = _parse_optional_token("+Turn Rate:")
	if turn_rate_str: subsys_data.turret_turning_rate = turn_rate_str.to_float()
	var fov_str = _parse_optional_token("+FOV:")
	if fov_str: subsys_data.turret_fov = fov_str.to_float() # Assuming FS2 stores cosine? Check C++
	var pbank_str = _parse_optional_token("+Default PBanks:")
	if pbank_str: subsys_data.primary_banks = _parse_weapon_index_list(pbank_str)
	var sbank_str = _parse_optional_token("+Default SBanks:")
	if sbank_str: subsys_data.secondary_banks = _parse_weapon_index_list(sbank_str)
	var pcap_str = _parse_optional_token("+PBank Capacity:")
	if pcap_str: subsys_data.primary_bank_capacity = _parse_int_list(pcap_str)
	var scap_str = _parse_optional_token("+SBank Capacity:")
	if scap_str: subsys_data.secondary_bank_capacity = _parse_int_list(scap_str)
	# TODO: Parse subsystem flags (+flags, +flags2)
	# TODO: Parse turret sounds
	# TODO: Parse engine wash info
	# TODO: Parse AWACS info
	# TODO: Parse turret target priorities

	# Consume any remaining lines until the next $ or #
	while _peek_line() != null and not _peek_line().begins_with("$") and not _peek_line().begins_with("#"):
		_read_line()

	return subsys_data
