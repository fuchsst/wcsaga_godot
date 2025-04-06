# migration_tools/gdscript_converters/tbl_converters/ships_tbl_converter.gd
@tool
extends BaseTblConverter
class_name ShipsTblConverter

# --- Dependencies ---
const ShipData = preload("res://scripts/resources/ship_weapon/ship_data.gd")
const SubsystemDefinition = preload("res://scripts/resources/ship_weapon/subsystem_definition.gd")
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For flags, species, etc.

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/ships.tbl" # Adjust if needed
const OUTPUT_RES_DIR = "res://resources/ships" # Default output

# --- Flag Definitions (Using GlobalConstants) ---
const SIF_FLAG_MAP: Dictionary = {
	"cargo-known": GlobalConstants.SF_CARGO_REVEALED,
	"ignore-count": GlobalConstants.SF_IGNORE_COUNT,
	"protect-ship": GlobalConstants.OF_PROTECTED, # Mapped to Object flag
	"reinforcement": GlobalConstants.SF_REINFORCEMENT,
	"no-shields": GlobalConstants.OF_NO_SHIELDS, # Mapped to Object flag
	"escort": GlobalConstants.SF_ESCORT,
	"player-start": GlobalConstants.OF_PLAYER_START, # Mapped to Object flag
	"no-arrival-music": GlobalConstants.SF_NO_ARRIVAL_MUSIC,
	"no-arrival-warp": GlobalConstants.SF_NO_ARRIVAL_WARP,
	"no-departure-warp": GlobalConstants.SF_NO_DEPARTURE_WARP,
	"locked": GlobalConstants.SF_LOCKED,
	"invulnerable": GlobalConstants.OF_INVULNERABLE, # Mapped to Object flag
	"hidden-from-sensors": GlobalConstants.SF_HIDDEN_FROM_SENSORS,
	"scannable": GlobalConstants.SF_SCANNABLE,
	"kamikaze": GlobalConstants.P_AIF_KAMIKAZE, # Mapped to Parse flag (AI flag)
	"no-dynamic": GlobalConstants.P_AIF_NO_DYNAMIC, # Mapped to Parse flag (AI flag)
	"red-alert-carry": GlobalConstants.P_SF_RED_ALERT_STORE_STATUS, # Mapped to Parse flag
	"beam-protect-ship": GlobalConstants.OF_BEAM_PROTECTED, # Mapped to Object flag
	"guardian": GlobalConstants.P_SF_GUARDIAN, # Mapped to Parse flag
	"special-warp": GlobalConstants.P_KNOSSOS_WARP_IN, # Mapped to Parse flag
	"vaporize": GlobalConstants.P_SF_VAPORIZE, # Mapped to Parse flag
	"stealth": GlobalConstants.SF2_STEALTH, # Mapped to SF2 flag
	"friendly-stealth-invisible": GlobalConstants.SF2_FRIENDLY_STEALTH_INVIS, # Mapped to SF2 flag
	"don't-collide-invisible": GlobalConstants.SF2_DONT_COLLIDE_INVIS, # Mapped to SF2 flag
	"use unique orders": GlobalConstants.P_SF_USE_UNIQUE_ORDERS, # Mapped to Parse flag
	"dock leader": GlobalConstants.P_SF_DOCK_LEADER, # Mapped to Parse flag
	"warp drive broken": GlobalConstants.SF_WARP_BROKEN,
	"never warps": GlobalConstants.SF_WARP_NEVER,
}

const SIF2_FLAG_MAP: Dictionary = {
	"primitive-sensors": GlobalConstants.SF2_PRIMITIVE_SENSORS,
	"no-subspace-drive": GlobalConstants.SF2_NO_SUBSPACE_DRIVE,
	"nav-carry-status": GlobalConstants.SF2_NAVPOINT_CARRY,
	"affected-by-gravity": GlobalConstants.SF2_AFFECTED_BY_GRAVITY,
	"toggle-subsystem-scanning": GlobalConstants.SF2_TOGGLE_SUBSYSTEM_SCANNING,
	"targetable-as-bomb": GlobalConstants.OF_TARGETABLE_AS_BOMB, # Mapped to Object flag
	"no-builtin-messages": GlobalConstants.SF2_NO_BUILTIN_MESSAGES,
	"primaries-locked": GlobalConstants.SF2_PRIMARIES_LOCKED,
	"secondaries-locked": GlobalConstants.SF2_SECONDARIES_LOCKED,
	"no-death-scream": GlobalConstants.SF2_NO_DEATH_SCREAM,
	"always-death-scream": GlobalConstants.SF2_ALWAYS_DEATH_SCREAM,
	"nav-needslink": GlobalConstants.SF2_NAVPOINT_NEEDSLINK,
	"hide-ship-name": GlobalConstants.SF2_HIDE_SHIP_NAME,
	"set-class-dynamically": GlobalConstants.SF2_SET_CLASS_DYNAMICALLY,
	"lock-all-turrets": GlobalConstants.SF2_LOCK_ALL_TURRETS_INITIALLY,
	"afterburners-locked": GlobalConstants.SF2_AFTERBURNER_LOCKED,
	"force-shields-on": GlobalConstants.SF2_FORCE_SHIELDS_ON,
	"hide-log-entries": GlobalConstants.SF2_HIDE_LOG_ENTRIES,
	"no-arrival-log": GlobalConstants.SF2_NO_ARRIVAL_LOG,
	"no-departure-log": GlobalConstants.SF2_NO_DEPARTURE_LOG,
	"is_harmless": GlobalConstants.SF2_IS_HARMLESS,
}

# --- Main Execution ---
func _run():
	print("Converting ships.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_DIR)

	var current_line_num = 0
	var processed_count = 0
	var error_count = 0
	var success = true

	# --- Parsing Logic ---
	# Skip header lines until #Ship Classes section
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		current_line_num += 1
		if line == "#Ship Classes":
			print("  Parsing #Ship Classes section...")
			break
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue

	# Loop through each ship definition
	while not file.eof_reached():
		var line = _peek_line(file) # Peek first

		# Stop at end marker
		if line != null and line.begins_with("#End"):
			print("  Reached #End.")
			break

		# Find the start of the next ship
		if line == null or not line.begins_with("$Name:"):
			file.get_line() # Consume the non-starting line
			current_line_num += 1
			continue

		# Parse the ship
		var ship_data: ShipData = _parse_single_ship(file, current_line_num)
		if ship_data:
			# Save the resource
			var output_path = OUTPUT_RES_DIR.path_join(ship_data.ship_name.to_lower().replace(" ", "_") + ".tres")
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var save_result = ResourceSaver.save(ship_data, output_path, save_flags)
			if save_result != OK:
				printerr(f"Error saving ShipData resource '{output_path}': {save_result}")
				success = false
				error_count += 1
			else:
				print(f"    Saved: {output_path}")
				processed_count += 1
		else:
			printerr(f"Failed to parse ship definition starting near line {current_line_num}.")
			success = false
			error_count += 1
			# Attempt to recover by skipping to the next potential ship start
			_skip_to_next_section_or_token(file, current_line_num, "$Name:")

	file.close()
	print(f"Finished converting ships.tbl. Processed: {processed_count}, Errors: {error_count}.")
	# Return success status? The EditorScript doesn't really use it.


# --- Ship Parsing Helper ---
func _parse_single_ship(file: FileAccess, current_line_num: int) -> ShipData:
	"""Parses one $Name: block for a ship definition."""
	var ship_data = ShipData.new()

	# --- Required Basic Info ---
	var name_str = _parse_required_token(file, current_line_num, "$Name:")
	if name_str == null: return null
	ship_data.ship_name = name_str.trim_prefix("+") # Handle potential '+' prefix
	print(f"    Parsing Ship: {ship_data.ship_name}")

	var pof_str = _parse_required_token(file, current_line_num, "$POF file:")
	if pof_str == null: return null
	ship_data.pof_file = pof_str

	var hull_str = _parse_required_token(file, current_line_num, "$Shields:") # Actually Hull in FS2 tables
	if hull_str == null: return null
	ship_data.max_hull_strength = TblParserUtils.parse_float(hull_str)

	var shield_str = _parse_required_token(file, current_line_num, "+Shields:") # This is Shields
	if shield_str == null: return null
	ship_data.max_shield_strength = TblParserUtils.parse_float(shield_str)

	# --- Optional Basic Info ---
	ship_data.alt_name = _parse_optional_token(file, current_line_num, "$Alt Name:") or ""
	ship_data.short_name = _parse_optional_token(file, current_line_num, "$Short Name:") or ""
	var species_str = _parse_optional_token(file, current_line_num, "$Species:") or "Terran"
	# ship_data.species = GlobalConstants.lookup_species_index(species_str) # Placeholder
	ship_data.species_name = species_str # Store name for now
	var class_type_str = _parse_optional_token(file, current_line_num, "$Class Type:") or ""
	# ship_data.class_type = GlobalConstants.lookup_ship_type_index(class_type_str) # Placeholder
	ship_data.class_type_name = class_type_str # Store name for now
	ship_data.manufacturer = _parse_optional_token(file, current_line_num, "$Manufacturer:") or ""
	ship_data.description = _parse_multitext(file, current_line_num, "$Description:")
	ship_data.tech_description = _parse_multitext(file, current_line_num, "$Tech Description:")
	ship_data.ship_length = _parse_optional_token(file, current_line_num, "$Length:") or ""

	# --- Models & Visuals ---
	ship_data.pof_file_hud = _parse_optional_token(file, current_line_num, "$POF file HUD:") or ship_data.pof_file # Default to main POF
	ship_data.cockpit_pof_file = _parse_optional_token(file, current_line_num, "$Cockpit POF file:") or ""
	var cockpit_offset_str = _parse_optional_token(file, current_line_num, "$Cockpit Offset:")
	if cockpit_offset_str != null: ship_data.cockpit_offset = TblParserUtils.parse_vector(cockpit_offset_str)
	var detail_dist_str = _parse_optional_token(file, current_line_num, "$Detail Distance:")
	if detail_dist_str != null: ship_data.detail_distances = [TblParserUtils.parse_int(detail_dist_str)]
	ship_data.hud_target_lod = TblParserUtils.parse_int(_parse_optional_token(file, current_line_num, "$LOD:") or "0")
	ship_data.icon_filename = _parse_optional_token(file, current_line_num, "$Icon:") or ""
	ship_data.anim_filename = _parse_optional_token(file, current_line_num, "$ANI file:") or ""
	ship_data.thruster_bitmap = _parse_optional_token(file, current_line_num, "$Thruster Flame:") or ""
	ship_data.thruster_glow_bitmap = _parse_optional_token(file, current_line_num, "$Thruster Glow:") or ""
	ship_data.thruster_secondary_glow_bitmap = _parse_optional_token(file, current_line_num, "$Thruster Secondary Glow:") or ""
	ship_data.thruster_tertiary_glow_bitmap = _parse_optional_token(file, current_line_num, "$Thruster Tertiary Glow:") or ""
	ship_data.afterburner_trail_bitmap = _parse_optional_token(file, current_line_num, "$Afterburner Trail:") or ""
	var shield_color_str = _parse_optional_token(file, current_line_num, "$Shield Color:")
	if shield_color_str != null: ship_data.shield_color = TblParserUtils.parse_color(shield_color_str)
	var radar_img_str = _parse_optional_token(file, current_line_num, "$Radar Image:")
	if radar_img_str != null:
		var parts = radar_img_str.split(",", false)
		if parts.size() == 2:
			ship_data.radar_image_2d_idx = TblParserUtils.parse_int(parts[0].strip_edges())
			ship_data.radar_image_size = TblParserUtils.parse_int(parts[1].strip_edges())
	var radar_proj_str = _parse_optional_token(file, current_line_num, "$Radar Projection Multiplier:")
	if radar_proj_str != null: ship_data.radar_projection_size_mult = TblParserUtils.parse_float(radar_proj_str)
	var closeup_pos_str = _parse_optional_token(file, current_line_num, "$Closeup Pos:")
	if closeup_pos_str != null: ship_data.closeup_pos = TblParserUtils.parse_vector(closeup_pos_str)
	var closeup_zoom_str = _parse_optional_token(file, current_line_num, "$Closeup Zoom:")
	if closeup_zoom_str != null: ship_data.closeup_zoom = TblParserUtils.parse_float(closeup_zoom_str)

	# --- Physics ---
	var density_str = _parse_optional_token(file, current_line_num, "$Density:")
	if density_str != null: ship_data.density = TblParserUtils.parse_float(density_str)
	var mass_str = _parse_optional_token(file, current_line_num, "$Mass:")
	if mass_str != null: ship_data.mass = TblParserUtils.parse_float(mass_str)
	var damp_str = _parse_optional_token(file, current_line_num, "$Damp:")
	if damp_str != null: ship_data.damp = TblParserUtils.parse_float(damp_str)
	var rotdamp_str = _parse_optional_token(file, current_line_num, "$Rotdamp:")
	if rotdamp_str != null: ship_data.rotdamp = TblParserUtils.parse_float(rotdamp_str)
	var max_vel_str = _parse_optional_token(file, current_line_num, "$Max Velocity:")
	if max_vel_str != null: ship_data.max_vel = TblParserUtils.parse_vector(max_vel_str)
	var aburn_max_vel_str = _parse_optional_token(file, current_line_num, "$ABurn Max Vel:")
	if aburn_max_vel_str != null: ship_data.afterburner_max_vel = TblParserUtils.parse_vector(aburn_max_vel_str)
	var max_rotvel_str = _parse_optional_token(file, current_line_num, "$Max Rotvelocity:")
	if max_rotvel_str != null: ship_data.max_rotvel = TblParserUtils.parse_vector(max_rotvel_str)
	var f_accel_str = _parse_optional_token(file, current_line_num, "$Forward Accel:")
	if f_accel_str != null: ship_data.forward_accel = TblParserUtils.parse_float(f_accel_str)
	var ab_f_accel_str = _parse_optional_token(file, current_line_num, "$ABurn Forward Accel:")
	if ab_f_accel_str != null: ship_data.afterburner_forward_accel = TblParserUtils.parse_float(ab_f_accel_str)
	var f_decel_str = _parse_optional_token(file, current_line_num, "$Forward Decel:")
	if f_decel_str != null: ship_data.forward_decel = TblParserUtils.parse_float(f_decel_str)
	var s_accel_str = _parse_optional_token(file, current_line_num, "$Slide Accel:")
	if s_accel_str != null: ship_data.slide_accel = TblParserUtils.parse_float(s_accel_str)
	var s_decel_str = _parse_optional_token(file, current_line_num, "$Slide Decel:")
	if s_decel_str != null: ship_data.slide_decel = TblParserUtils.parse_float(s_decel_str)

	# --- Afterburner ---
	var ab_fuel_str = _parse_optional_token(file, current_line_num, "$ABurn Fuel:")
	if ab_fuel_str != null: ship_data.afterburner_fuel_capacity = TblParserUtils.parse_float(ab_fuel_str)
	var ab_burn_str = _parse_optional_token(file, current_line_num, "$ABurn Burn Rate:")
	if ab_burn_str != null: ship_data.afterburner_burn_rate = TblParserUtils.parse_float(ab_burn_str)
	var ab_rec_str = _parse_optional_token(file, current_line_num, "$ABurn Recharge Rate:")
	if ab_rec_str != null: ship_data.afterburner_recover_rate = TblParserUtils.parse_float(ab_rec_str)

	# --- Hull, Shields, Energy ---
	var power_str = _parse_optional_token(file, current_line_num, "$Power Output:")
	if power_str != null: ship_data.power_output = TblParserUtils.parse_float(power_str)
	var weapon_res_str = _parse_optional_token(file, current_line_num, "$Max Weapon Energy:")
	if weapon_res_str != null: ship_data.max_weapon_reserve = TblParserUtils.parse_float(weapon_res_str)
	var shield_regen_str = _parse_optional_token(file, current_line_num, "$Shield Recharge Rate:")
	if shield_regen_str != null: ship_data.max_shield_regen_per_second = TblParserUtils.parse_float(shield_regen_str)
	var weapon_regen_str = _parse_optional_token(file, current_line_num, "$Weapon Recharge Rate:")
	if weapon_regen_str != null: ship_data.max_weapon_regen_per_second = TblParserUtils.parse_float(weapon_regen_str)
	var armor_str = _parse_optional_token(file, current_line_num, "$Armor Type:")
	ship_data.armor_type_name = armor_str if armor_str else "" # Store name
	var shield_armor_str = _parse_optional_token(file, current_line_num, "$Shield Armor Type:")
	ship_data.shield_armor_type_name = shield_armor_str if shield_armor_str else "" # Store name

	# --- Weapons ---
	var num_primary_str = _parse_required_token(file, current_line_num, "$Primary Banks:")
	if num_primary_str == null: return null
	ship_data.num_primary_banks = TblParserUtils.parse_int(num_primary_str)
	if ship_data.num_primary_banks > 0:
		var pbanks_str = _parse_required_token(file, current_line_num, "$Default PBanks:")
		ship_data.primary_bank_weapons = _parse_weapon_name_list(pbanks_str) # Store names
		var pcap_str = _parse_required_token(file, current_line_num, "$PBank Capacity:")
		ship_data.primary_bank_ammo_capacity = TblParserUtils.parse_int_list(pcap_str)

	var num_secondary_str = _parse_required_token(file, current_line_num, "$Secondary Banks:")
	if num_secondary_str == null: return null
	ship_data.num_secondary_banks = TblParserUtils.parse_int(num_secondary_str)
	if ship_data.num_secondary_banks > 0:
		var sbanks_str = _parse_required_token(file, current_line_num, "$Default SBanks:")
		ship_data.secondary_bank_weapons = _parse_weapon_name_list(sbanks_str) # Store names
		var scap_str = _parse_required_token(file, current_line_num, "$SBank Capacity:")
		ship_data.secondary_bank_ammo_capacity = TblParserUtils.parse_int_list(scap_str)

	# Allowed Weapons
	var allowed_weapons_str = _parse_optional_token(file, current_line_num, "$Allowed Weapons:")
	if allowed_weapons_str != null: ship_data.allowed_weapons = TblParserUtils.parse_string_list(allowed_weapons_str)
	# TODO: Parse $Restricted Banks:, $Allowed PBanks:, $Allowed SBanks:

	# --- Countermeasures ---
	var cmeasure_type_str = _parse_optional_token(file, current_line_num, "$Countermeasure:")
	ship_data.cmeasure_type_name = cmeasure_type_str if cmeasure_type_str else "" # Store name
	var cmeasure_max_str = _parse_optional_token(file, current_line_num, "$CMeasure Max:")
	if cmeasure_max_str != null: ship_data.cmeasure_max = TblParserUtils.parse_int(cmeasure_max_str)

	# --- AI ---
	var ai_class_str = _parse_optional_token(file, current_line_num, "$AI Class:")
	ship_data.ai_class_name = ai_class_str if ai_class_str else "" # Store name

	# --- Sounds ---
	var engine_snd_str = _parse_optional_token(file, current_line_num, "$Engine Sound:")
	ship_data.engine_sound_name = engine_snd_str if engine_snd_str else "" # Store name
	# TODO: Parse other sounds

	# --- Warp ---
	var warpin_anim_str = _parse_optional_token(file, current_line_num, "$Warpin Anim:")
	if warpin_anim_str != null: ship_data.warpin_anim = warpin_anim_str
	var warpin_rad_str = _parse_optional_token(file, current_line_num, "$Warpin Radius:")
	if warpin_rad_str != null: ship_data.warpin_radius = TblParserUtils.parse_float(warpin_rad_str)
	var warpin_speed_str = _parse_optional_token(file, current_line_num, "$Warpin Speed:")
	if warpin_speed_str != null: ship_data.warpin_speed = TblParserUtils.parse_float(warpin_speed_str)
	# TODO: Parse Warpout fields

	# --- Destruction ---
	var shockwave_str = _parse_optional_token(file, current_line_num, "$Shockwave:")
	if shockwave_str != null:
		# TODO: Parse shockwave parameters
		print("TODO: Parse shockwave parameters")
	var death_roll_str = _parse_optional_token(file, current_line_num, "$Death Roll Time:")
	if death_roll_str != null: ship_data.death_roll_time = TblParserUtils.parse_int(death_roll_str) * 1000 # s to ms
	# TODO: Parse other destruction fields

	# --- Flags ---
	var flags_str = _parse_optional_token(file, current_line_num, "$Flags:")
	if flags_str != null: ship_data.flags = TblParserUtils.parse_flags(flags_str, SIF_FLAG_MAP)
	var flags2_str = _parse_optional_token(file, current_line_num, "$Flags2:")
	if flags2_str != null: ship_data.flags2 = TblParserUtils.parse_flags(flags2_str, SIF2_FLAG_MAP)

	# --- Score ---
	var score_str = _parse_optional_token(file, current_line_num, "$Score:")
	if score_str != null: ship_data.score = TblParserUtils.parse_int(score_str)

	# --- Subsystems ---
	ship_data.subsystems.clear() # Ensure the array is empty before parsing
	while _peek_line(file) != null and _peek_line(file).begins_with("$Subsystem:"):
		var subsystem_data = _parse_single_subsystem(file, current_line_num, ship_data.ship_name)
		if subsystem_data:
			ship_data.subsystems.append(subsystem_data)
		else:
			printerr(f"Failed to parse subsystem block starting near line {current_line_num} for ship {ship_data.ship_name}")
			# Attempt to recover by skipping to the next potential subsystem or major token
			_skip_to_next_section_or_token(file, current_line_num, "$Subsystem:")

	return ship_data



# --- Subsystem Parsing Helper ---
func _parse_single_subsystem(file: FileAccess, current_line_num_ref: Variant, ship_name_for_error: String) -> SubsystemDefinition:
	"""Parses one $Subsystem: block."""
	var subsys_data = SubsystemDefinition.new()

	var subsys_line = _parse_required_token(file, current_line_num_ref, "$Subsystem:")
	if subsys_line == null: return null

	# Parse the main subsystem line: Name, HP, Repair Points
	var parts = subsys_line.split(",", false)
	if parts.size() < 3:
		printerr(f"Error: Malformed $Subsystem line for ship '{ship_name_for_error}' near line {current_line_num_ref[0]}")
		return null
	subsys_data.subobj_name = parts[0].strip_edges()
	subsys_data.max_subsys_strength = TblParserUtils.parse_float(parts[1])
	# Repair points are ignored for now, but we parse it
	# subsys_data.repair_points = TblParserUtils.parse_float(parts[2])

	# Optional fields within the subsystem block
	subsys_data.alt_sub_name = _parse_optional_token(file, current_line_num_ref, "+Alt Subsystem Name:") or ""
	subsys_data.alt_dmg_sub_name = _parse_optional_token(file, current_line_num_ref, "+Alt Damaged Subsystem Name:") or ""
	var armor_str = _parse_optional_token(file, current_line_num_ref, "+Armor Type:")
	subsys_data.armor_type_name = armor_str if armor_str else "" # Store name
	var turn_rate_str = _parse_optional_token(file, current_line_num_ref, "+Turn Rate:")
	if turn_rate_str: subsys_data.turret_turning_rate = TblParserUtils.parse_float(turn_rate_str)
	var fov_str = _parse_optional_token(file, current_line_num_ref, "+FOV:")
	if fov_str: subsys_data.turret_fov = TblParserUtils.parse_float(fov_str) # Assuming FS2 stores cosine? Check C++
	var pbank_str = _parse_optional_token(file, current_line_num_ref, "+Default PBanks:")
	if pbank_str: subsys_data.primary_banks = _parse_weapon_name_list(pbank_str) # Store names
	var sbank_str = _parse_optional_token(file, current_line_num_ref, "+Default SBanks:")
	if sbank_str: subsys_data.secondary_banks = _parse_weapon_name_list(sbank_str) # Store names
	var pcap_str = _parse_optional_token(file, current_line_num_ref, "+PBank Capacity:")
	if pcap_str: subsys_data.primary_bank_capacity = TblParserUtils.parse_int_list(pcap_str)
	var scap_str = _parse_optional_token(file, current_line_num_ref, "+SBank Capacity:")
	if scap_str: subsys_data.secondary_bank_capacity = TblParserUtils.parse_int_list(scap_str)
	# TODO: Parse subsystem flags (+flags, +flags2)
	# TODO: Parse turret sounds
	# TODO: Parse engine wash info
	# TODO: Parse AWACS info
	# TODO: Parse turret target priorities

	# Consume any remaining lines until the next $ or #
	while _peek_line(file) != null and not _peek_line(file).begins_with("$") and not _peek_line(file).begins_with("#"):
		_read_line(file, current_line_num_ref)

	return subsys_data
