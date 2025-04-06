# migration_tools/gdscript_converters/tbl_converters/weapons_tbl_converter.gd
@tool
extends BaseTblConverter # Inherit from the new base class
class_name WeaponsTblConverter

# --- Dependencies ---
const WeaponData = preload("res://scripts/resources/ship_weapon/weapon_data.gd")
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For flags, types, etc.

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/weapons.tbl" # Adjust if needed
const OUTPUT_RES_DIR = "res://resources/weapons" # Default output

# --- Mappings (TODO: Move to GlobalConstants or dedicated mapping script) ---
# Weapon Subtypes (weapon.h - WP_*)
const WP_LASER = 0
const WP_MISSILE = 1
const WP_FLAK = 2
const WP_BEAM = 3
const WP_EMP = 4
const WP_SWARM = 5
const WP_CORKSCREW = 6
const WP_ENERGY_SUCK = 7
const WP_ELECTRONICS = 8
const WP_LOCAL_SSM = 9
const WP_CMEASURE = 10
const WP_TAG = 11
const WP_SPAWN = 12
const WP_BALLISTIC = 13

const WEAPON_SUBTYPE_MAP: Dictionary = {
	"Laser": WP_LASER,
	"Missile": WP_MISSILE,
	"Flak": WP_FLAK,
	"Beam": WP_BEAM,
	"EMP": WP_EMP,
	"Swarm": WP_SWARM,
	"Corkscrew": WP_CORKSCREW,
	"Energy Suck": WP_ENERGY_SUCK,
	"Electronics": WP_ELECTRONICS,
	"Local SSM": WP_LOCAL_SSM,
	"Countermeasure": WP_CMEASURE,
	"Tag": WP_TAG,
	"Spawn": WP_SPAWN,
	"Ballistic": WP_BALLISTIC,
}

# Weapon Render Types (weapon.h - WRT_*)
const WRT_NONE = 0
const WRT_LASER = 1
const WRT_POF = 2
const WRT_BITMAP = 3
const WRT_MISSILE = 4

const RENDER_TYPE_MAP: Dictionary = {
	"None": WRT_NONE,
	"Laser": WRT_LASER,
	"POF": WRT_POF,
	"Bitmap": WRT_BITMAP,
	"Missile": WRT_MISSILE,
}

# --- Flag Mappings (Using GlobalConstants) ---
const WIF_FLAG_MAP: Dictionary = {
	"homing": GlobalConstants.WIF_HOMING,
	"electronic": GlobalConstants.WIF_ELECTRONICS,
	"child": GlobalConstants.WIF_CHILD,
	"heat": GlobalConstants.WIF_HOMING_HEAT,
	"aspect": GlobalConstants.WIF_HOMING_ASPECT,
	"beam": GlobalConstants.WIF_BEAM,
	"bomb": GlobalConstants.WIF_BOMB,
	"nocreate": GlobalConstants.WIF_NOCREATE,
	"noplayer": GlobalConstants.WIF_NO_PLAYER,
	"playerallowed": GlobalConstants.WIF_PLAYER_ALLOWED,
	"flak": GlobalConstants.WIF_FLAK,
	"swarm": GlobalConstants.WIF_SWARM,
	"corkscrew": GlobalConstants.WIF_CORKSCREW,
	"huge": GlobalConstants.WIF_HUGE,
	"burst": GlobalConstants.WIF_BURST,
	"shockwave": GlobalConstants.WIF_SHOCKWAVE,
	"trail": GlobalConstants.WIF_TRAIL,
	"countermeasure": GlobalConstants.WIF_CMEASURE,
	"particle_spew": GlobalConstants.WIF_PARTICLE_SPEW,
	"massdriver": GlobalConstants.WIF_MASSDRIVER,
	"muzzle_flash": GlobalConstants.WIF_MFLASH,
	"energy_suck": GlobalConstants.WIF_ENERGY_SUCK,
	"emp": GlobalConstants.WIF_EMP,
	"tag": GlobalConstants.WIF_TAG,
	"spawn": GlobalConstants.WIF_SPAWN,
	"ballistic": GlobalConstants.WIF_BALLISTIC,
	"no_subspace_drive": GlobalConstants.WIF_NO_SUBSPACE_DRIVE,
	"no_secondary_fire_delay": GlobalConstants.WIF_NO_FIRE_DELAY,
	"no_hud_target": GlobalConstants.WIF_NO_HUD_TARGET,
	"no_intercept": GlobalConstants.WIF_NO_INTERCEPT,
	"no_target_factor": GlobalConstants.WIF_NO_TARGET_FACTOR,
	"no_lock_warn": GlobalConstants.WIF_NO_LOCK_WARN,
	"no_lock_indicator": GlobalConstants.WIF_NO_LOCK_INDICATOR,
	"no_lock_sound": GlobalConstants.WIF_NO_LOCK_SOUND,
	"no_lock_required": GlobalConstants.WIF_NO_LOCK_REQUIRED,
	"no_target_priorities": GlobalConstants.WIF_NO_TARGET_PRIORITIES,
	"no_target_factor_on_turrets": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_TURRETS,
	"no_target_factor_on_bombs": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS,
	"no_target_factor_on_missiles": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_MISSILES,
	"no_target_factor_on_fighters": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_FIGHTERS,
	"no_target_factor_on_bombers": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBERS,
	"no_target_factor_on_cruisers": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_CRUISERS,
	"no_target_factor_on_capitals": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_CAPITALS,
	"no_target_factor_on_freighters": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_FREIGHTERS,
	"no_target_factor_on_transports": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_TRANSPORTS,
	"no_target_factor_on_support": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_SUPPORT,
	"no_target_factor_on_installations": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_INSTALLATIONS,
	"no_target_factor_on_navbuoys": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_NAVBUOYS,
	"no_target_factor_on_sentries": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_SENTRIES,
	"no_target_factor_on_jumpnodes": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_JUMPNODES,
	"no_target_factor_on_debris": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_DEBRIS,
	"no_target_factor_on_asteroids": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_ASTEROIDS,
	"no_target_factor_on_unknowns": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_UNKNOWNS,
	"no_target_factor_on_gasminers": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_GASMINERS,
	"no_target_factor_on_awacs": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_AWACS,
	"no_target_factor_on_cargos": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_CARGOS,
	"no_target_factor_on_large_turrets": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_LARGE_TURRETS,
	"no_target_factor_on_small_turrets": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_SMALL_TURRETS,
	"no_target_factor_on_bombs_emp": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_EMP,
	"no_target_factor_on_bombs_swarm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SWARM,
	"no_target_factor_on_bombs_corkscrew": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CORKSCREW,
	"no_target_factor_on_bombs_cluster": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CLUSTER,
	"no_target_factor_on_bombs_shivan": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SHIVAN,
	"no_target_factor_on_bombs_local_ssm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_LOCAL_SSM,
	"no_target_factor_on_bombs_tag": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_TAG,
	"no_target_factor_on_bombs_spawn": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SPAWN,
	"no_target_factor_on_bombs_ballistic": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_BALLISTIC,
	"no_target_factor_on_bombs_energy_suck": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ENERGY_SUCK,
	"no_target_factor_on_bombs_electronics": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ELECTRONICS,
	"no_target_factor_on_bombs_countermeasure": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_COUNTERMEASURE,
	"no_target_factor_on_bombs_flak": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_FLAK,
	"no_target_factor_on_bombs_beam": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_BEAM,
	"no_target_factor_on_bombs_laser": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_LASER,
	"no_target_factor_on_bombs_missile": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MISSILE,
	"no_target_factor_on_bombs_massdriver": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MASSDRIVER,
	"no_target_factor_on_bombs_muzzle_flash": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MUZZLE_FLASH,
	"no_target_factor_on_bombs_shockwave": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SHOCKWAVE,
	"no_target_factor_on_bombs_trail": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_TRAIL,
	"no_target_factor_on_bombs_particle_spew": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_PARTICLE_SPEW,
	"no_target_factor_on_bombs_homing": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_HOMING,
	"no_target_factor_on_bombs_heat": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_HEAT,
	"no_target_factor_on_bombs_aspect": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ASPECT,
	"no_target_factor_on_bombs_javelin": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_JAVELIN,
	"no_target_factor_on_bombs_swarm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SWARM,
	"no_target_factor_on_bombs_corkscrew": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CORKSCREW,
	"no_target_factor_on_bombs_cluster": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CLUSTER,
	"no_target_factor_on_bombs_shivan": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SHIVAN,
	"no_target_factor_on_bombs_local_ssm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_LOCAL_SSM,
	"no_target_factor_on_bombs_tag": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_TAG,
	"no_target_factor_on_bombs_spawn": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SPAWN,
	"no_target_factor_on_bombs_ballistic": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_BALLISTIC,
	"no_target_factor_on_bombs_energy_suck": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ENERGY_SUCK,
	"no_target_factor_on_bombs_electronics": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ELECTRONICS,
	"no_target_factor_on_bombs_countermeasure": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_COUNTERMEASURE,
	"no_target_factor_on_bombs_flak": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_FLAK,
	"no_target_factor_on_bombs_beam": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_BEAM,
	"no_target_factor_on_bombs_laser": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_LASER,
	"no_target_factor_on_bombs_missile": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MISSILE,
	"no_target_factor_on_bombs_massdriver": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MASSDRIVER,
	"no_target_factor_on_bombs_muzzle_flash": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MUZZLE_FLASH,
	"no_target_factor_on_bombs_shockwave": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SHOCKWAVE,
	"no_target_factor_on_bombs_trail": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_TRAIL,
	"no_target_factor_on_bombs_particle_spew": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_PARTICLE_SPEW,
	"no_target_factor_on_bombs_homing": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_HOMING,
	"no_target_factor_on_bombs_heat": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_HEAT,
	"no_target_factor_on_bombs_aspect": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ASPECT,
	"no_target_factor_on_bombs_javelin": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_JAVELIN,
	"no_target_factor_on_bombs_swarm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SWARM,
	"no_target_factor_on_bombs_corkscrew": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CORKSCREW,
	"no_target_factor_on_bombs_cluster": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CLUSTER,
	"no_target_factor_on_bombs_shivan": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SHIVAN,
	"no_target_factor_on_bombs_local_ssm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_LOCAL_SSM,
	"no_target_factor_on_bombs_tag": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_TAG,
	"no_target_factor_on_bombs_spawn": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SPAWN,
	"no_target_factor_on_bombs_ballistic": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_BALLISTIC,
	"no_target_factor_on_bombs_energy_suck": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ENERGY_SUCK,
	"no_target_factor_on_bombs_electronics": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ELECTRONICS,
	"no_target_factor_on_bombs_countermeasure": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_COUNTERMEASURE,
	"no_target_factor_on_bombs_flak": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_FLAK,
	"no_target_factor_on_bombs_beam": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_BEAM,
	"no_target_factor_on_bombs_laser": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_LASER,
	"no_target_factor_on_bombs_missile": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MISSILE,
	"no_target_factor_on_bombs_massdriver": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MASSDRIVER,
	"no_target_factor_on_bombs_muzzle_flash": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_MUZZLE_FLASH,
	"no_target_factor_on_bombs_shockwave": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SHOCKWAVE,
	"no_target_factor_on_bombs_trail": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_TRAIL,
	"no_target_factor_on_bombs_particle_spew": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_PARTICLE_SPEW,
	"no_target_factor_on_bombs_homing": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_HOMING,
	"no_target_factor_on_bombs_heat": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_HEAT,
	"no_target_factor_on_bombs_aspect": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_ASPECT,
	"no_target_factor_on_bombs_javelin": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_JAVELIN,
	"no_target_factor_on_bombs_swarm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SWARM,
	"no_target_factor_on_bombs_corkscrew": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CORKSCREW,
	"no_target_factor_on_bombs_cluster": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_CLUSTER,
	"no_target_factor_on_bombs_shivan": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_SHIVAN,
	"no_target_factor_on_bombs_local_ssm": GlobalConstants.WIF_NO_TARGET_FACTOR_ON_BOMBS_LOCAL_SSM,
}

const WIF2_FLAG_MAP: Dictionary = {
	"ballistic": GlobalConstants.WIF2_BALLISTIC,
	"pierce shields": GlobalConstants.WIF2_PIERCE_SHIELDS,
	"default tech": GlobalConstants.WIF2_DEFAULT_IN_TECH_DATABASE,
	"local ssm": GlobalConstants.WIF2_LOCAL_SSM,
	"tagged only": GlobalConstants.WIF2_TAGGED_ONLY,
	"cycle": GlobalConstants.WIF2_CYCLE,
	"small only": GlobalConstants.WIF2_SMALL_ONLY,
	"same turret cooldown": GlobalConstants.WIF2_SAME_TURRET_COOLDOWN,
	"no lighting": GlobalConstants.WIF2_MR_NO_LIGHTING,
	"transparent": GlobalConstants.WIF2_TRANSPARENT,
	"training": GlobalConstants.WIF2_TRAINING,
	"smart spawn": GlobalConstants.WIF2_SMART_SPAWN,
	"inherit parent target": GlobalConstants.WIF2_INHERIT_PARENT_TARGET,
	"no emp kill": GlobalConstants.WIF2_NO_EMP_KILL,
	"variable lead homing": GlobalConstants.WIF2_VARIABLE_LEAD_HOMING,
	"untargeted heat seeker": GlobalConstants.WIF2_UNTARGETED_HEAT_SEEKER,
	"hard target bomb": GlobalConstants.WIF2_HARD_TARGET_BOMB,
	"non subsys homing": GlobalConstants.WIF2_NON_SUBSYS_HOMING,
	"no life lost if missed": GlobalConstants.WIF2_NO_LIFE_LOST_IF_MISSED,
	"custom seeker str": GlobalConstants.WIF2_CUSTOM_SEEKER_STR,
	"can be targeted": GlobalConstants.WIF2_CAN_BE_TARGETED,
	"shown on radar": GlobalConstants.WIF2_SHOWN_ON_RADAR,
	"show friendly": GlobalConstants.WIF2_SHOW_FRIENDLY,
	"capital plus": GlobalConstants.WIF2_CAPITAL_PLUS,
}

# --- Main Execution ---
func _run():
	print("Converting weapons.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	# Ensure output directory exists
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_DIR)

	var current_line_num_ref = [0] # Use array as reference
	var processed_count = 0
	var error_count = 0
	var success = true

	# --- Parsing Logic ---
	# Skip header lines until #Weapon Classes section
	if not _skip_to_token(file, current_line_num_ref, "#Weapon Classes"):
		printerr("Error: '#Weapon Classes' marker not found in weapons.tbl")
		file.close()
		return

	print("  Parsing #Weapon Classes section...")

	# Loop through each weapon definition
	while not file.eof_reached():
		var line = _peek_line(file) # Peek first

		# Stop at end marker
		if line != null and line.begins_with("#End"):
			print("  Reached #End.")
			break

		# Find the start of the next weapon
		if line == null or not line.begins_with("$Name:"):
			_read_line(file, current_line_num_ref) # Consume the non-starting line
			continue

		# Parse the weapon
		var weapon_data: WeaponData = _parse_single_weapon(file, current_line_num_ref)
		if weapon_data:
			# Save the resource
			var output_path = OUTPUT_RES_DIR.path_join(weapon_data.weapon_name.to_lower().replace(" ", "_") + ".tres")
			var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
			var save_result = ResourceSaver.save(weapon_data, output_path, save_flags)
			if save_result != OK:
				printerr(f"Error saving WeaponData resource '{output_path}': {save_result}")
				success = false
				error_count += 1
			else:
				print(f"    Saved: {output_path}")
				processed_count += 1
		else:
			printerr(f"Failed to parse weapon definition starting near line {current_line_num_ref[0]}.")
			success = false
			error_count += 1
			# Attempt to recover by skipping to the next potential weapon start
			_skip_to_next_section_or_token(file, current_line_num_ref, "$Name:")

	file.close()
	print(f"Finished converting weapons.tbl. Processed: {processed_count}, Errors: {error_count}.")
	# Return success status? The EditorScript doesn't really use it.


# --- Weapon Parsing Helper ---
func _parse_single_weapon(file: FileAccess, current_line_num_ref: Variant) -> WeaponData:
	"""Parses one $Name: block for a weapon definition."""
	var weapon_data = WeaponData.new()

	# --- Required Basic Info ---
	var name_str = _parse_required_token(file, current_line_num_ref, "$Name:")
	if name_str == null: return null
	weapon_data.weapon_name = name_str.trim_prefix("+") # Handle potential '+' prefix
	print(f"    Parsing Weapon: {weapon_data.weapon_name}")

	# --- Optional Basic Info ---
	weapon_data.alt_name = _parse_optional_token(file, current_line_num_ref, "$Alt Name:") or ""
	weapon_data.short_name = _parse_optional_token(file, current_line_num_ref, "$Short Name:") or ""
	weapon_data.manufacturer = _parse_optional_token(file, current_line_num_ref, "$Manufacturer:") or ""
	weapon_data.description = _parse_multitext(file, current_line_num_ref, "$Description:")
	weapon_data.tech_description = _parse_multitext(file, current_line_num_ref, "$Tech Description:")

	# --- Visuals ---
	weapon_data.pof_file = _parse_optional_token(file, current_line_num_ref, "$POF file:") or ""
	weapon_data.pof_file_hud = _parse_optional_token(file, current_line_num_ref, "$POF file HUD:") or weapon_data.pof_file
	weapon_data.icon_filename = _parse_optional_token(file, current_line_num_ref, "$Icon:") or ""
	weapon_data.anim_filename = _parse_optional_token(file, current_line_num_ref, "$ANI file:") or ""
	# Render Type
	var render_type_str = _parse_optional_token(file, current_line_num_ref, "$Render Type:") or "None"
	weapon_data.render_type = RENDER_TYPE_MAP.get(render_type_str, WRT_NONE)
	# Laser specific visuals
	var laser_len_str = _parse_optional_token(file, current_line_num_ref, "$Laser Length:")
	if laser_len_str != null: weapon_data.laser_length = TblParserUtils.parse_float(laser_len_str)
	var laser_head_str = _parse_optional_token(file, current_line_num_ref, "$Laser Head Bitmap:")
	if laser_head_str != null: weapon_data.laser_head_bitmap_name = laser_head_str
	var laser_tail_str = _parse_optional_token(file, current_line_num_ref, "$Laser Tail Bitmap:")
	if laser_tail_str != null: weapon_data.laser_tail_bitmap_name = laser_tail_str
	var laser_width_str = _parse_optional_token(file, current_line_num_ref, "$Laser Width:")
	if laser_width_str != null: weapon_data.laser_width = TblParserUtils.parse_float(laser_width_str)
	var laser_color_str = _parse_optional_token(file, current_line_num_ref, "$Laser Color:")
	if laser_color_str != null: weapon_data.laser_color = TblParserUtils.parse_color(laser_color_str)
	# Trail info
	var trail_info_str = _parse_optional_token(file, current_line_num_ref, "$Trail:")
	if trail_info_str != null:
		var parts = trail_info_str.split(",", false)
		if parts.size() >= 3:
			weapon_data.trail_bitmap_name = parts[0].strip_edges()
			weapon_data.trail_width = TblParserUtils.parse_float(parts[1].strip_edges())
			weapon_data.trail_length = TblParserUtils.parse_float(parts[2].strip_edges())
			if parts.size() >= 4: weapon_data.trail_segment_length = TblParserUtils.parse_float(parts[3].strip_edges())
			if parts.size() >= 5: weapon_data.trail_alpha = TblParserUtils.parse_float(parts[4].strip_edges())
			if parts.size() >= 6: weapon_data.trail_timestamp = TblParserUtils.parse_float(parts[5].strip_edges()) * 1000.0 # s to ms
	# Muzzle flash
	var mflash_str = _parse_optional_token(file, current_line_num_ref, "$Muzzle Flash:")
	if mflash_str != null:
		var parts = mflash_str.split(",", false)
		if parts.size() >= 3:
			weapon_data.muzzle_flash_anim_name = parts[0].strip_edges()
			weapon_data.muzzle_flash_radius = TblParserUtils.parse_float(parts[1].strip_edges())
			weapon_data.muzzle_flash_lifetime = TblParserUtils.parse_float(parts[2].strip_edges()) * 1000.0 # s to ms

	# --- Physics & Lifetime ---
	var mass_str = _parse_optional_token(file, current_line_num_ref, "$Mass:")
	if mass_str != null: weapon_data.mass = TblParserUtils.parse_float(mass_str)
	var lifetime_str = _parse_optional_token(file, current_line_num_ref, "$Lifetime:")
	if lifetime_str != null: weapon_data.lifetime = TblParserUtils.parse_float(lifetime_str)
	var init_vel_str = _parse_optional_token(file, current_line_num_ref, "$Velocity:")
	if init_vel_str != null: weapon_data.initial_velocity = TblParserUtils.parse_float(init_vel_str)
	var max_vel_str = _parse_optional_token(file, current_line_num_ref, "$Max Velocity:")
	if max_vel_str != null: weapon_data.max_velocity = TblParserUtils.parse_float(max_vel_str)
	var damp_str = _parse_optional_token(file, current_line_num_ref, "$Damp:")
	if damp_str != null: weapon_data.damping = TblParserUtils.parse_float(damp_str)
	var rotvel_str = _parse_optional_token(file, current_line_num_ref, "$Rotational Velocity:")
	if rotvel_str != null: weapon_data.rotational_velocity = TblParserUtils.parse_vector(rotvel_str)
	var phys_flags_str = _parse_optional_token(file, current_line_num_ref, "$Physics Flags:")
	# TODO: Parse physics flags (PF_*)

	# --- Damage & Impact ---
	var damage_str = _parse_optional_token(file, current_line_num_ref, "$Damage:")
	if damage_str != null: weapon_data.damage = TblParserUtils.parse_float(damage_str)
	var inner_rad_str = _parse_optional_token(file, current_line_num_ref, "$Inner Radius:")
	if inner_rad_str != null: weapon_data.inner_radius = TblParserUtils.parse_float(inner_rad_str)
	var outer_rad_str = _parse_optional_token(file, current_line_num_ref, "$Outer Radius:")
	if outer_rad_str != null: weapon_data.outer_radius = TblParserUtils.parse_float(outer_rad_str)
	var impact_snd_str = _parse_optional_token(file, current_line_num_ref, "$Impact Sound:")
	weapon_data.impact_sound_name = impact_snd_str if impact_snd_str else "" # Store name
	var impact_explosion_str = _parse_optional_token(file, current_line_num_ref, "$Impact Explosion:")
	weapon_data.impact_explosion_anim_name = impact_explosion_str if impact_explosion_str else "" # Store name
	# TODO: Parse Impact Particle fields

	# --- Firing & Energy ---
	var energy_cons_str = _parse_optional_token(file, current_line_num_ref, "$Energy Consumed:")
	if energy_cons_str != null: weapon_data.energy_consumed = TblParserUtils.parse_float(energy_cons_str)
	var ammo_usage_str = _parse_optional_token(file, current_line_num_ref, "$Ammo Usage:")
	if ammo_usage_str != null: weapon_data.ammo_usage = TblParserUtils.parse_int(ammo_usage_str)
	var fire_wait_str = _parse_optional_token(file, current_line_num_ref, "$Fire Wait:")
	if fire_wait_str != null: weapon_data.fire_wait = TblParserUtils.parse_float(fire_wait_str)
	var fire_snd_str = _parse_optional_token(file, current_line_num_ref, "$Firing Sound:")
	weapon_data.firing_sound_name = fire_snd_str if fire_snd_str else "" # Store name
	var release_snd_str = _parse_optional_token(file, current_line_num_ref, "$Release Sound:")
	weapon_data.release_sound_name = release_snd_str if release_snd_str else "" # Store name
	var charge_snd_str = _parse_optional_token(file, current_line_num_ref, "$Charging Sound:")
	weapon_data.charging_sound_name = charge_snd_str if charge_snd_str else "" # Store name
	var charge_time_str = _parse_optional_token(file, current_line_num_ref, "$Charge Time:")
	if charge_time_str != null: weapon_data.charge_time = TblParserUtils.parse_float(charge_time_str) * 1000.0 # s to ms

	# --- Homing ---
	var homing_fov_str = _parse_optional_token(file, current_line_num_ref, "$Homing FOV:")
	if homing_fov_str != null: weapon_data.homing_fov = TblParserUtils.parse_float(homing_fov_str)
	var homing_accel_str = _parse_optional_token(file, current_line_num_ref, "$Homing Acceleration:")
	if homing_accel_str != null: weapon_data.homing_acceleration = TblParserUtils.parse_float(homing_accel_str)
	var homing_lock_str = _parse_optional_token(file, current_line_num_ref, "$Lock Time:")
	if homing_lock_str != null: weapon_data.lock_time = TblParserUtils.parse_float(homing_lock_str)
	var homing_pixels_str = _parse_optional_token(file, current_line_num_ref, "$Lock Pixels:")
	if homing_pixels_str != null: weapon_data.lock_pixels = TblParserUtils.parse_int(homing_pixels_str)
	var homing_range_str = _parse_optional_token(file, current_line_num_ref, "$Lock Range:")
	if homing_range_str != null: weapon_data.lock_range = TblParserUtils.parse_float(homing_range_str)
	var homing_snd_str = _parse_optional_token(file, current_line_num_ref, "$Lock Sound:")
	weapon_data.lock_sound_name = homing_snd_str if homing_snd_str else "" # Store name
	var homing_lost_snd_str = _parse_optional_token(file, current_line_num_ref, "$Lock Lost Sound:")
	weapon_data.lock_lost_sound_name = homing_lost_snd_str if homing_lost_snd_str else "" # Store name
	var homing_warn_snd_str = _parse_optional_token(file, current_line_num_ref, "$Lock Warning Sound:")
	weapon_data.lock_warning_sound_name = homing_warn_snd_str if homing_warn_snd_str else "" # Store name
	var homing_seeker_str = _parse_optional_token(file, current_line_num_ref, "$Homing Seeker Strength:")
	if homing_seeker_str != null: weapon_data.homing_seeker_strength = TblParserUtils.parse_float(homing_seeker_str)

	# --- Turret Specific ---
	var turret_fov_str = _parse_optional_token(file, current_line_num_ref, "$Turret FOV:")
	if turret_fov_str != null: weapon_data.turret_fov = TblParserUtils.parse_float(turret_fov_str)
	var turret_turn_str = _parse_optional_token(file, current_line_num_ref, "$Turret Turn Rate:")
	if turret_turn_str != null: weapon_data.turret_turn_rate = TblParserUtils.parse_float(turret_turn_str)

	# --- Flags ---
	var flags_str = _parse_optional_token(file, current_line_num_ref, "$Flags:")
	if flags_str != null: weapon_data.flags = TblParserUtils.parse_flags(flags_str, WIF_FLAG_MAP)
	var flags2_str = _parse_optional_token(file, current_line_num_ref, "$Flags2:")
	if flags2_str != null: weapon_data.flags2 = TblParserUtils.parse_flags(flags2_str, WIF2_FLAG_MAP) # Use WIF2 map

	# --- Subtype ---
	var subtype_str = _parse_optional_token(file, current_line_num_ref, "$Subtype:")
	if subtype_str != null:
		weapon_data.subtype = WEAPON_SUBTYPE_MAP.get(subtype_str, WP_LASER) # Default to Laser
	else:
		weapon_data.subtype = WP_LASER # Default if not specified

	# --- Beam Info (Skip for now) ---
	if _parse_optional_token(file, current_line_num_ref, "$Beam Info:") != null:
		print(f"TODO: Parse Beam Info for {weapon_data.weapon_name}")
		while _peek_line(file) != null and not _peek_line(file).begins_with("$"):
			_read_line(file, current_line_num_ref) # Consume beam info lines

	return weapon_data


# --- Helper Functions (Removed - Now in BaseTblConverter) ---
