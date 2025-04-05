# migration_tools/gdscript_converters/tbl_converters/weapons_tbl_converter.gd
@tool
extends RefCounted # Use RefCounted for now, maybe BaseTblParser later
class_name WeaponsTblConverter

# --- Dependencies ---
const WeaponData = preload("res://scripts/resources/ship_weapon/weapon_data.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For flags, types, etc.

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0
var _output_dir: String = "res://resources/weapons" # Default output

# --- Mappings (Placeholders - Move to GlobalConstants or dedicated mapping script) ---
const WEAPON_SUBTYPE_MAP: Dictionary = {
	"Laser": GlobalConstants.WP_LASER,
	"Missile": GlobalConstants.WP_MISSILE,
	"Flak": GlobalConstants.WP_FLAK,
	"Beam": GlobalConstants.WP_BEAM,
	"EMP": GlobalConstants.WP_EMP,
	"Swarm": GlobalConstants.WP_SWARM,
	"Corkscrew": GlobalConstants.WP_CORKSCREW,
	"Energy Suck": GlobalConstants.WP_ENERGY_SUCK,
	"Electronics": GlobalConstants.WP_ELECTRONICS,
	"Local SSM": GlobalConstants.WP_LOCAL_SSM,
	"Countermeasure": GlobalConstants.WP_CMEASURE,
	"Tag": GlobalConstants.WP_TAG,
	"Spawn": GlobalConstants.WP_SPAWN,
	"Ballistic": GlobalConstants.WP_BALLISTIC,
}
const RENDER_TYPE_MAP: Dictionary = {
	"None": GlobalConstants.WRT_NONE,
	"Laser": GlobalConstants.WRT_LASER,
	"POF": GlobalConstants.WRT_POF,
	"Bitmap": GlobalConstants.WRT_BITMAP,
	"Missile": GlobalConstants.WRT_MISSILE,
}

# --- Flag Mappings ---
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
	"muzzle_flash": GlobalConstants.WIF_MUZZLE_FLASH,
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
		print(f"TODO: Parse Beam Info for {weapon_data.weapon_name}")
		while _peek_line() != null and not _peek_line().begins_with("$"):
			_read_line() # Consume beam info lines

	return weapon_data


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

func _parse_color(line_content: String) -> Color:
	var content = line_content.strip_edges()
	var parts = content.split(" ", false)
	if parts.size() == 3:
		# Assuming R G B (0-255)
		var r = float(parts[0].to_int()) / 255.0
		var g = float(parts[1].to_int()) / 255.0
		var b = float(parts[2].to_int()) / 255.0
		return Color(r, g, b)
	else:
		printerr(f"Error parsing Color: '{line_content}'")
		return Color(1, 1, 1)

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

func _parse_weapon_flags_bitmask(flags_string: String) -> int:
	# Placeholder: Needs actual implementation to parse flag names and OR bits
	# based on WIF_* constants
	print(f"Warning: Weapon flag parsing not implemented for: {flags_string}")
	return 0

func _parse_weapon_flags2_bitmask(flags_string: String) -> int:
	# Placeholder: Needs actual implementation to parse flag names and OR bits
	# based on WIF2_* constants
	print(f"Warning: Weapon flag2 parsing not implemented for: {flags_string}")
	return 0

func _skip_to_next_section_or_token(token: String):
	"""Skips lines until the specified token or a section marker '#' or EOF."""
	while true:
		var line = _peek_line()
		if line == null or line.begins_with(token) or line.begins_with("#"):
			break
		_read_line()

func _parse_weapon_flags_bitmask(flags_string: String) -> int:
	var bitmask = 0
	var flags_list = flags_string.split("|")
	for flag_str in flags_list:
		var clean_flag = flag_str.strip_edges().to_lower()
		if WIF_FLAG_MAP.has(clean_flag):
			bitmask |= WIF_FLAG_MAP[clean_flag]
		elif not clean_flag.is_empty():
			printerr(f"Warning: Unknown weapon flag '{clean_flag}' in $Flags.")
	return bitmask

func _parse_weapon_flags2_bitmask(flags_string: String) -> int:
	# Placeholder: Needs actual implementation to parse flag names and OR bits
	# based on WIF2_* constants
	# Example structure (assuming WIF2_FLAG_MAP exists):
	# var bitmask = 0
	# var flags_list = flags_string.split("|")
	# for flag_str in flags_list:
	#	 var clean_flag = flag_str.strip_edges().to_lower()
	#	 if WIF2_FLAG_MAP.has(clean_flag):
	#		 bitmask |= WIF2_FLAG_MAP[clean_flag]
	#	 elif not clean_flag.is_empty():
	#		 printerr(f"Warning: Unknown weapon flag2 '{clean_flag}' in $Flags2.")
	# return bitmask
	print(f"Warning: Weapon flag2 parsing not implemented for: {flags_string}")
	return 0

func _skip_to_token(token: String) -> bool:
	"""Skips lines until the specified token is found or EOF."""
	while true:
		var line = _peek_line()
		if line == null:
			return false # Token not found
		if line.begins_with(token):
			return true # Token found
		_read_line() # Consume the line
