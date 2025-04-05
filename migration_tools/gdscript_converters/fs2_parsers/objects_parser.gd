# migration_tools/gdscript_converters/fs2_parsers/objects_parser.gd
extends BaseFS2Parser
class_name ObjectsParser

# --- Dependencies ---
const ShipInstanceData = preload("res://scripts/resources/mission/ship_instance_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const SexpParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/sexp_parser.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")
const SubsystemStatusData = preload("res://scripts/resources/mission/subsystem_status_data.gd")
const AltClassData = preload("res://scripts/resources/mission/alt_class_data.gd")
const TextureReplacementData = preload("res://scripts/resources/mission/texture_replacement_data.gd")
const DockingPairData = preload("res://scripts/resources/mission/dock_point_pair_data.gd")


# --- Parser State ---
# Inherited: _lines, _current_line_num (managed externally or via return value)
var _sexp_parser = SexpParser.new()

# --- Mappings (Placeholders - Move to GlobalConstants or dedicated mapping script) ---
const AI_BEHAVIOR_MAP: Dictionary = {
	"Chase": 0, "Evade": 1, "Get behind": 2, "Stay Near": 3, "Still": 4,
	"Guard": 5, "Avoid": 6, "Waypoints": 7, "Dock": 8, "None": 9,
	"Big Ship": 10, "Path": 11, "Be Rearmed": 12, "Safety": 13,
	"Evade Weapon": 14, "Strafe": 15, "Play Dead": 16, "Bay Emerge": 17,
	"Bay Depart": 18, "Sentry Gun": 19, "Warp Out": 20,
}
const ARRIVAL_LOCATION_MAP: Dictionary = {
	"Hyperspace": 0, "Near Ship": 1, "In front of ship": 2, "Docking Bay": 3,
}
const DEPARTURE_LOCATION_MAP: Dictionary = {
	"Hyperspace": 0, "Docking Bay": 1,
}

# --- Flag Mappings (from missionparse.cpp Parse_object_flags/Parse_object_flags_2) ---
const ParseObjectFlags: Dictionary = {
	"cargo-known": GlobalConstants.P_SF_CARGO_KNOWN,
	"ignore-count": GlobalConstants.P_SF_IGNORE_COUNT,
	"protect-ship": GlobalConstants.P_OF_PROTECTED,
	"reinforcement": GlobalConstants.P_SF_REINFORCEMENT,
	"no-shields": GlobalConstants.P_OF_NO_SHIELDS,
	"escort": GlobalConstants.P_SF_ESCORT,
	"player-start": GlobalConstants.P_OF_PLAYER_START,
	"no-arrival-music": GlobalConstants.P_SF_NO_ARRIVAL_MUSIC,
	"no-arrival-warp": GlobalConstants.P_SF_NO_ARRIVAL_WARP,
	"no-departure-warp": GlobalConstants.P_SF_NO_DEPARTURE_WARP,
	"locked": GlobalConstants.P_SF_LOCKED,
	"invulnerable": GlobalConstants.P_OF_INVULNERABLE,
	"hidden-from-sensors": GlobalConstants.P_SF_HIDDEN_FROM_SENSORS,
	"scannable": GlobalConstants.P_SF_SCANNABLE,
	"kamikaze": GlobalConstants.P_AIF_KAMIKAZE,
	"no-dynamic": GlobalConstants.P_AIF_NO_DYNAMIC,
	"red-alert-carry": GlobalConstants.P_SF_RED_ALERT_STORE_STATUS,
	"beam-protect-ship": GlobalConstants.P_OF_BEAM_PROTECTED,
	"guardian": GlobalConstants.P_SF_GUARDIAN,
	"special-warp": GlobalConstants.P_KNOSSOS_WARP_IN,
	"vaporize": GlobalConstants.P_SF_VAPORIZE,
	"stealth": GlobalConstants.P_SF2_STEALTH,
	"friendly-stealth-invisible": GlobalConstants.P_SF2_FRIENDLY_STEALTH_INVIS,
	"don't-collide-invisible": GlobalConstants.P_SF2_DONT_COLLIDE_INVIS,
	# Note: P_SF_USE_UNIQUE_ORDERS, P_SF_DOCK_LEADER, P_SF_CANNOT_ARRIVE,
	# P_SF_WARP_BROKEN, P_SF_WARP_NEVER, P_SF_PLAYER_START_VALID are handled differently or are runtime flags
}

const ParseObjectFlags2: Dictionary = {
	"primitive-sensors": GlobalConstants.P2_SF2_PRIMITIVE_SENSORS,
	"no-subspace-drive": GlobalConstants.P2_SF2_NO_SUBSPACE_DRIVE,
	"nav-carry-status": GlobalConstants.P2_SF2_NAV_CARRY_STATUS,
	"affected-by-gravity": GlobalConstants.P2_SF2_AFFECTED_BY_GRAVITY,
	"toggle-subsystem-scanning": GlobalConstants.P2_SF2_TOGGLE_SUBSYSTEM_SCANNING,
	"targetable-as-bomb": GlobalConstants.P2_OF_TARGETABLE_AS_BOMB,
	"no-builtin-messages": GlobalConstants.P2_SF2_NO_BUILTIN_MESSAGES,
	"primaries-locked": GlobalConstants.P2_SF2_PRIMARIES_LOCKED,
	"secondaries-locked": GlobalConstants.P2_SF2_SECONDARIES_LOCKED,
	"no-death-scream": GlobalConstants.P2_SF2_NO_DEATH_SCREAM,
	"always-death-scream": GlobalConstants.P2_SF2_ALWAYS_DEATH_SCREAM,
	"nav-needslink": GlobalConstants.P2_SF2_NAV_NEEDSLINK,
	"hide-ship-name": GlobalConstants.P2_SF2_HIDE_SHIP_NAME,
	"set-class-dynamically": GlobalConstants.P2_SF2_SET_CLASS_DYNAMICALLY,
	"lock-all-turrets": GlobalConstants.P2_SF2_LOCK_ALL_TURRETS_INITIALLY, # Renamed for clarity
	"afterburners-locked": GlobalConstants.P2_SF2_AFTERBURNER_LOCKED,
	"force-shields-on": GlobalConstants.P2_OF_FORCE_SHIELDS_ON,
	"hide-log-entries": GlobalConstants.P2_SF2_HIDE_LOG_ENTRIES,
	"no-arrival-log": GlobalConstants.P2_SF2_NO_ARRIVAL_LOG,
	"no-departure-log": GlobalConstants.P2_SF2_NO_DEPARTURE_LOG,
	"is_harmless": GlobalConstants.P2_SF2_IS_HARMLESS,
	# Note: P2_ALREADY_HANDLED is internal
}

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing the list of parsed ship instances ('data')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var ships_array: Array[ShipInstanceData] = []

	print("Parsing #Objects section...")

	# Loop through $Name: blocks for each object definition
	while _peek_line() != null and _peek_line().begins_with("$Name:"):
		var ship_instance: ShipInstanceData = _parse_single_object()
		if ship_instance:
			ships_array.append(ship_instance)
		else:
			# Error occurred in parsing this object, try to recover
			printerr(f"Failed to parse object starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			_skip_to_next_section_or_token("$Name:")

	# Skip any remaining lines until the next section marker '#'
	_skip_to_next_section_or_token("#")

	print(f"Finished parsing #Objects section. Found {ships_array.size()} objects.")
	return { "data": ships_array, "next_line": _current_line_num }


# --- Object Parsing Helper ---
func _parse_single_object() -> ShipInstanceData:
	"""Parses one $Name: block for a ship instance."""
	var ship_instance = ShipInstanceData.new()

	var name_str = _parse_required_token("$Name:")
	if name_str == null: return null
	ship_instance.ship_name = name_str

	var class_str = _parse_required_token("$Class:")
	if class_str == null: return null
	ship_instance.ship_class_name = class_str # Store name, index lookup happens at runtime

	var team_str = _parse_required_token("$Team:")
	if team_str == null: return null
	ship_instance.team = _parse_team_or_iff(team_str)

	var pos_str = _parse_required_token("$Location:")
	if pos_str == null: return null
	ship_instance.position = _parse_vector(pos_str)

	var orient_str = _parse_required_token("$Orientation:")
	if orient_str == null: return null
	ship_instance.orientation = _parse_basis(orient_str)

	# Optional IFF name (usually same as team, maybe store if different?)
	_parse_optional_token("$IFF:") # Consume if present

	var behavior_str = _parse_required_token("$AI Behavior:")
	if behavior_str == null: return null
	ship_instance.ai_behavior = AI_BEHAVIOR_MAP.get(behavior_str, 9) # Default to None

	ship_instance.ai_class_name = _parse_optional_token("+AI Class:") or "" # TODO: Link to AIProfile resource?

	# AI Goals SEXP
	var next_line_peek = _peek_line()
	if next_line_peek != null and next_line_peek.begins_with("$AI Goals:"):
		_read_line() # Consume the token line
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			ship_instance.ai_goals = sexp_result["sexp_node"]
			_current_line_num = sexp_result["next_line"]
		else:
			printerr(f"ObjectsParser: Failed to parse SEXP for AI Goals for {ship_instance.ship_name}")
			# Continue parsing object, but goals will be null

	var cargo1_str = _parse_required_token("$Cargo 1:")
	if cargo1_str == null: return null
	ship_instance.cargo1_name = cargo1_str

	# Optional Cargo 2 (not stored in ShipInstanceData currently)
	_parse_optional_token("$Cargo 2:")

	# Parse Status Description blocks if present (not directly stored in ShipInstanceData)
	# These are handled by the +Subsystem block now
	while _peek_line() != null and _peek_line().begins_with("$Status Description:"):
		_read_line() # Consume status desc
		_read_line() # Consume status type
		_read_line() # Consume target

	# --- Arrival ---
	var arrival_loc_str = _parse_required_token("$Arrival Location:")
	if arrival_loc_str == null: return null
	ship_instance.arrival_location = ARRIVAL_LOCATION_MAP.get(arrival_loc_str, 0) # Default Hyperspace

	var arrival_dist_str = _parse_optional_token("+Arrival Distance:")
	ship_instance.arrival_distance = int(arrival_dist_str) if arrival_dist_str != null and arrival_dist_str.is_valid_int() else 0

	ship_instance.arrival_anchor_name = _parse_optional_token("$Arrival Anchor:") or ""

	# TODO: Parse Arrival Paths (+Arrival Paths:) - How is this stored? Bitmask or list?
	_parse_optional_token("+Arrival Paths:") # Consume for now

	var arrival_delay_str = _parse_optional_token("+Arrival Delay:")
	ship_instance.arrival_delay_ms = int(arrival_delay_str) * 1000 if arrival_delay_str != null and arrival_delay_str.is_valid_int() else 0

	# Arrival Cue SEXP
	if not _parse_required_token("$Arrival Cue:"): return null
	next_line_peek = _peek_line()
	if next_line_peek != null and next_line_peek.begins_with("("): # Check if SEXP follows directly
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			ship_instance.arrival_cue = sexp_result["sexp_node"]
			_current_line_num = sexp_result["next_line"]
		else:
			printerr(f"ObjectsParser: Failed to parse SEXP for Arrival Cue for {ship_instance.ship_name}")
			# Continue, cue will be null
	else:
		# Assume it was a simple token like (true) on the same line, which _parse_required_token consumed content of
		# This case might need refinement if complex cues can be single-line without $Formula:
		print(f"Warning: Assuming simple/empty Arrival Cue for {ship_instance.ship_name}")
		pass # Cue remains null

	# --- Departure ---
	var departure_loc_str = _parse_required_token("$Departure Location:")
	if departure_loc_str == null: return null
	ship_instance.departure_location = DEPARTURE_LOCATION_MAP.get(departure_loc_str, 0) # Default Hyperspace

	ship_instance.departure_anchor_name = _parse_optional_token("$Departure Anchor:") or ""

	# TODO: Parse Departure Paths (+Departure Paths:)
	_parse_optional_token("+Departure Paths:") # Consume for now

	var departure_delay_str = _parse_optional_token("+Departure Delay:")
	ship_instance.departure_delay_ms = int(departure_delay_str) * 1000 if departure_delay_str != null and departure_delay_str.is_valid_int() else 0

	# Departure Cue SEXP
	if not _parse_required_token("$Departure Cue:"): return null
	next_line_peek = _peek_line()
	if next_line_peek != null and next_line_peek.begins_with("("): # Check if SEXP follows directly
		var sexp_result = _sexp_parser.parse_sexp_from_string_array(_lines, _current_line_num)
		if sexp_result and sexp_result.has("sexp_node") and sexp_result["sexp_node"] != null:
			ship_instance.departure_cue = sexp_result["sexp_node"]
			_current_line_num = sexp_result["next_line"]
		else:
			printerr(f"ObjectsParser: Failed to parse SEXP for Departure Cue for {ship_instance.ship_name}")
			# Continue, cue will be null
	else:
		print(f"Warning: Assuming simple/empty Departure Cue for {ship_instance.ship_name}")
		pass # Cue remains null


	# Optional Misc Properties (not stored)
	_parse_optional_token("$Misc Properties:")
	# Optional Determination (not stored)
	_parse_optional_token("$Determination:")

	# --- Flags ---
	var flags_str = _parse_optional_token("+Flags:")
	if flags_str != null:
		ship_instance.flags = _parse_flags_bitmask(flags_str, ParseObjectFlags)
	var flags2_str = _parse_optional_token("+Flags2:")
	if flags2_str != null:
		ship_instance.flags2 = _parse_flags_bitmask(flags2_str, ParseObjectFlags2)

	# --- Optional Numeric/String Properties ---
	var respawn_prio_str = _parse_optional_token("+Respawn Priority:")
	ship_instance.respawn_priority = int(respawn_prio_str) if respawn_prio_str != null and respawn_prio_str.is_valid_int() else 0

	var escort_priority_str = _parse_optional_token("+Escort Priority:") # Not in ShipInstanceData?

	var init_vel_str = _parse_optional_token("+Initial Velocity:")
	ship_instance.initial_velocity_percent = int(init_vel_str) if init_vel_str != null and init_vel_str.is_valid_int() else 0

	var init_hull_str = _parse_optional_token("+Initial Hull:")
	ship_instance.initial_hull_percent = int(init_hull_str) if init_hull_str != null and init_hull_str.is_valid_int() else 100

	var init_shield_str = _parse_optional_token("+Initial Shields:")
	ship_instance.initial_shields_percent = int(init_shield_str) if init_shield_str != null and init_shield_str.is_valid_int() else 100

	# Special Explosion/Hitpoints
	var special_exp_token = _parse_optional_token("$Special Explosion:")
	if special_exp_token != null:
		ship_instance.use_special_explosion = true
		var dmg_str = _parse_required_token("+Special Exp Damage:")
		ship_instance.special_exp_damage = int(dmg_str) if dmg_str != null and dmg_str.is_valid_int() else -1

		var blast_str = _parse_required_token("+Special Exp Blast:")
		ship_instance.special_exp_blast = int(blast_str) if blast_str != null and blast_str.is_valid_int() else -1

		var inner_str = _parse_required_token("+Special Exp Inner Radius:")
		ship_instance.special_exp_inner_radius = int(inner_str) if inner_str != null and inner_str.is_valid_int() else -1

		var outer_str = _parse_required_token("+Special Exp Outer Radius:")
		ship_instance.special_exp_outer_radius = int(outer_str) if outer_str != null and outer_str.is_valid_int() else -1

		var shockwave_speed_str = _parse_optional_token("+Special Exp Shockwave Speed:")
		if shockwave_speed_str != null:
			ship_instance.use_shockwave = true
			ship_instance.special_exp_shockwave_speed = shockwave_speed_str.to_int()

	var special_hp_str = _parse_optional_token("+Special Hitpoints:")
	if special_hp_str != null: ship_instance.special_hitpoints = special_hp_str.to_int()
	var special_shield_str = _parse_optional_token("+Special Shield Points:")
	if special_shield_str != null: ship_instance.special_shield_points = special_shield_str.to_int()

	# Skip old index-based special explosion/hitpoints if present
	_parse_optional_token("+Special Exp index:")
	_parse_optional_token("+Special Hitpoint index:")

	var kamikaze_str = _parse_optional_token("+Kamikaze Damage:")
	if kamikaze_str != null: ship_instance.kamikaze_damage = kamikaze_str.to_float()

	var hotkey_str = _parse_optional_token("+Hotkey:")
	ship_instance.hotkey = int(hotkey_str) if hotkey_str != null and hotkey_str.is_valid_int() else -1

	# --- Docking ---
	while _peek_line() != null and _peek_line().begins_with("+Docked With:"):
		var docked_with_str = _parse_required_token("+Docked With:")
		if docked_with_str == null: break # Error
		var docker_point_str = _parse_required_token("$Docker Point:")
		if docker_point_str == null: break # Error
		var dockee_point_str = _parse_required_token("$Dockee Point:")
		if dockee_point_str == null: break # Error

		var dock_pair = DockingPairData.new()
		dock_pair.docked_with_ship_name = docked_with_str
		dock_pair.docker_point_name = docker_point_str
		dock_pair.dockee_point_name = dockee_point_str
		ship_instance.initial_docking.append(dock_pair)

	# --- Destroy At ---
	var destroy_at_str = _parse_optional_token("+Destroy At:")
	if destroy_at_str != null: ship_instance.destroy_before_mission_time = destroy_at_str.to_int()

	# --- Orders Accepted ---
	var orders_str = _parse_optional_token("+Orders Accepted:")
	if orders_str != null: ship_instance.orders_accepted = orders_str.to_int()

	# --- Group ---
	var group_str = _parse_optional_token("+Group:")
	ship_instance.group = int(group_str) if group_str != null and group_str.is_valid_int() else 0

	# --- Score ---
	var use_table_score = _parse_optional_token("+Use Table Score:") != null
	var score_str = _parse_optional_token("+Score:")
	if score_str != null and not use_table_score:
		ship_instance.score = score_str.to_int()
	# If use_table_score is true or +Score is missing, score remains default (0),
	# indicating runtime should use ShipData score.

	var assist_pct_str = _parse_optional_token("+Assist Score Percentage:")
	if assist_pct_str != null: ship_instance.assist_score_pct = assist_pct_str.to_float()

	# --- Persona ---
	var persona_idx_str = _parse_optional_token("+Persona Index:")
	ship_instance.persona_index = int(persona_idx_str) if persona_idx_str != null and persona_idx_str.is_valid_int() else -1

	# --- Texture Replacements ---
	var tex_replace_token = _parse_optional_token("$Texture Replace:") or _parse_optional_token("$Duplicate Model Texture Replace:")
	if tex_replace_token != null:
		while _peek_line() != null and _peek_line().begins_with("+old:"):
			var old_tex_str = _parse_required_token("+old:")
			if old_tex_str == null: break # Error
			var new_tex_str = _parse_required_token("+new:")
			if new_tex_str == null: break # Error

			var tex_replace_data = TextureReplacementData.new()
			tex_replace_data.old_texture_name = old_tex_str
			tex_replace_data.new_texture_name = new_tex_str
			ship_instance.texture_replacements.append(tex_replace_data)

	# --- Alt Names ---
	ship_instance.alt_type_name = _parse_optional_token("$Alt:") or ""
	ship_instance.callsign_name = _parse_optional_token("$Callsign:") or ""

	# --- Alternate Ship Classes ---
	while _peek_line() != null and _peek_line().begins_with("$Alt Ship Class:"):
		var alt_class_name_str = _parse_required_token("$Alt Ship Class:")
		if alt_class_name_str == null: break # Error

		var alt_data = AltClassData.new()
		alt_data.ship_class_name = alt_class_name_str # Store name, resolve later
		alt_data.is_default = _parse_optional_token("+Default Class:") != null
		ship_instance.alternate_classes.append(alt_data)

	# --- Subsystems ---
	while _peek_line() != null and _peek_line().begins_with("+Subsystem:"):
		var subsys_name_str = _parse_required_token("+Subsystem:")
		if subsys_name_str == null: break # Error in required token

		var subsys_data = SubsystemStatusData.new()
		subsys_data.subsystem_name = subsys_name_str

		var damage_pct_str = _parse_optional_token("$Damage:")
		subsys_data.damage_percent = float(damage_pct_str) if damage_pct_str != null and damage_pct_str.is_valid_float() else 0.0

		subsys_data.cargo_name = _parse_optional_token("+Cargo Name:") or ""
		subsys_data.ai_class_name = _parse_optional_token("+AI Class:") or "" # Store name

		var primary_banks_str = _parse_optional_token("+Primary Banks:")
		subsys_data.primary_banks = _parse_int_list(primary_banks_str) if primary_banks_str != null else PackedInt32Array()

		var pbank_ammo_str = _parse_optional_token("+Pbank Ammo:")
		subsys_data.primary_ammo_percent = _parse_int_list(pbank_ammo_str) if pbank_ammo_str != null else PackedInt32Array()

		var secondary_banks_str = _parse_optional_token("+Secondary Banks:")
		subsys_data.secondary_banks = _parse_int_list(secondary_banks_str) if secondary_banks_str != null else PackedInt32Array()

		var sbank_ammo_str = _parse_optional_token("+Sbank Ammo:")
		subsys_data.secondary_ammo_percent = _parse_int_list(sbank_ammo_str) if sbank_ammo_str != null else PackedInt32Array()

		ship_instance.subsystem_status.append(subsys_data)

	return ship_instance
