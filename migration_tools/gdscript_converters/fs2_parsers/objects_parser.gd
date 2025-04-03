# migration_tools/gdscript_converters/fs2_parsers/objects_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name ObjectsParser

# --- Dependencies ---
const ShipInstanceData = preload("res://scripts/resources/mission/ship_instance_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
# TODO: Preload other needed resources like SubsystemStatusData, AltClassData, etc.

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- SEXP Operator Mapping (Placeholder - Copied for now, centralize later) ---
const OPERATOR_MAP: Dictionary = {
	"true": SexpNode.SexpOperator.OP_TRUE, "false": SexpNode.SexpOperator.OP_FALSE,
	"and": SexpNode.SexpOperator.OP_AND, "or": SexpNode.SexpOperator.OP_OR, "not": SexpNode.SexpOperator.OP_NOT,
	"event-true": SexpNode.SexpOperator.OP_EVENT_TRUE, "goal-true": SexpNode.SexpOperator.OP_GOAL_TRUE,
	"is-destroyed": SexpNode.SexpOperator.OP_IS_DESTROYED,
	# ... add all others ...
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
		var ship_instance = _parse_single_object()
		if ship_instance:
			ships_array.append(ship_instance)
		else:
			# Error occurred in parsing this object, try to recover
			printerr(f"Failed to parse object starting near line {_current_line_num}. Attempting to skip to next '$Name:' or '#'.")
			while true:
				var line = _peek_line()
				if line == null or line.begins_with("$Name:") or line.begins_with("#"):
					break
				_read_line() # Consume the problematic lines

	print(f"Finished parsing #Objects section. Found {ships_array.size()} objects.")
	return { "data": ships_array, "next_line": _current_line_num }


# --- Object Parsing Helper ---
func _parse_single_object() -> ShipInstanceData:
	"""Parses one $Name: block for a ship instance."""
	var ship_instance = ShipInstanceData.new()
	ship_instance.ship_name = _parse_required_token("$Name:")

	ship_instance.ship_class_name = _parse_required_token("$Class:")
	# TODO: Convert team name string to team index based on IFF definitions
	var team_name = _parse_required_token("$Team:")
	# ship_instance.team = GlobalConstants.lookup_team_index(team_name) # Placeholder

	ship_instance.position = _parse_vector(_parse_required_token("$Location:"))
	ship_instance.orientation = _parse_basis(_parse_required_token("$Orientation:"))

	# Optional IFF name (usually same as team, maybe store if different?)
	_parse_optional_token("$IFF:") # Consume if present

	# TODO: Convert AI behavior name string to enum/int
	var behavior_name = _parse_required_token("$AI Behavior:")
	# ship_instance.ai_behavior = GlobalConstants.lookup_ai_behavior(behavior_name) # Placeholder

	ship_instance.ai_class_name = _parse_optional_token("+AI Class:") or "" # TODO: Link to AIProfile resource?

	var ai_goals_str = _parse_optional_token("$AI Goals:")
	if ai_goals_str != null and ai_goals_str.begins_with("$Formula:"):
		ai_goals_str = ai_goals_str.substr(len("$Formula:")).strip_edges()
		ship_instance.ai_goals = _parse_sexp(ai_goals_str)

	ship_instance.cargo1_name = _parse_required_token("$Cargo 1:")
	# Optional Cargo 2 (not stored in ShipInstanceData currently)
	_parse_optional_token("$Cargo 2:")

	# Parse Status Description blocks if present (not directly stored in ShipInstanceData)
	while _peek_line() != null and _peek_line().begins_with("$Status Description:"):
		_read_line() # Consume status desc
		_read_line() # Consume status type
		_read_line() # Consume target

	# --- Arrival ---
	var arrival_loc_str = _parse_required_token("$Arrival Location:")
	# TODO: Convert arrival_loc_str to enum/int
	# ship_instance.arrival_location = GlobalConstants.lookup_arrival_location(arrival_loc_str)
	ship_instance.arrival_distance = int(_parse_optional_token("+Arrival Distance:") or "0")
	ship_instance.arrival_anchor_name = _parse_optional_token("$Arrival Anchor:") or ""
	# TODO: Parse Arrival Paths (+Arrival Paths:) - How is this stored? Bitmask or list?
	_parse_optional_token("+Arrival Paths:") # Consume for now
	ship_instance.arrival_delay_ms = int(_parse_optional_token("+Arrival Delay:") or "0") * 1000
	var arrival_cue_str = _parse_required_token("$Arrival Cue:")
	if arrival_cue_str.begins_with("$Formula:"):
		arrival_cue_str = arrival_cue_str.substr(len("$Formula:")).strip_edges()
		ship_instance.arrival_cue = _parse_sexp(arrival_cue_str)

	# --- Departure ---
	var departure_loc_str = _parse_required_token("$Departure Location:")
	# TODO: Convert departure_loc_str to enum/int
	# ship_instance.departure_location = GlobalConstants.lookup_departure_location(departure_loc_str)
	ship_instance.departure_anchor_name = _parse_optional_token("$Departure Anchor:") or ""
	# TODO: Parse Departure Paths (+Departure Paths:)
	_parse_optional_token("+Departure Paths:") # Consume for now
	ship_instance.departure_delay_ms = int(_parse_optional_token("+Departure Delay:") or "0") * 1000
	var departure_cue_str = _parse_required_token("$Departure Cue:")
	if departure_cue_str.begins_with("$Formula:"):
		departure_cue_str = departure_cue_str.substr(len("$Formula:")).strip_edges()
		ship_instance.departure_cue = _parse_sexp(departure_cue_str)

	# Optional Misc Properties (not stored)
	_parse_optional_token("$Misc Properties:")
	# Optional Determination (not stored)
	_parse_optional_token("$Determination:")

	# --- Flags ---
	# TODO: Implement robust flag parsing based on GlobalConstants definitions
	var flags_str = _parse_optional_token("+Flags:")
	if flags_str != null:
		# ship_instance.flags = _parse_flags_bitmask(flags_str, GlobalConstants.ShipFlags) # Placeholder
		pass
	var flags2_str = _parse_optional_token("+Flags2:")
	if flags2_str != null:
		# ship_instance.flags2 = _parse_flags_bitmask(flags2_str, GlobalConstants.ShipFlags2) # Placeholder
		pass

	# --- Optional Numeric/String Properties ---
	ship_instance.respawn_priority = int(_parse_optional_token("+Respawn Priority:") or "0")
	var escort_priority_str = _parse_optional_token("+Escort Priority:") # Not in ShipInstanceData?
	ship_instance.initial_velocity_percent = int(_parse_optional_token("+Initial Velocity:") or "0")
	ship_instance.initial_hull_percent = int(_parse_optional_token("+Initial Hull:") or "100")
	ship_instance.initial_shields_percent = int(_parse_optional_token("+Initial Shields:") or "100")

	# Special Explosion/Hitpoints
	var special_exp_token = _parse_optional_token("$Special Explosion:")
	if special_exp_token != null:
		ship_instance.use_special_explosion = true
		ship_instance.special_exp_damage = int(_parse_required_token("+Special Exp Damage:"))
		ship_instance.special_exp_blast = int(_parse_required_token("+Special Exp Blast:"))
		ship_instance.special_exp_inner_radius = int(_parse_required_token("+Special Exp Inner Radius:"))
		ship_instance.special_exp_outer_radius = int(_parse_required_token("+Special Exp Outer Radius:"))
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

	var kamikaze_str = _parse_optional_token("+Kamikaze Damage:") # Not in ShipInstanceData?

	ship_instance.hotkey = int(_parse_optional_token("+Hotkey:") or "-1")

	# --- Docking ---
	# TODO: Parse +Docked With blocks and create DockingPairData resources
	while _peek_line() != null and _peek_line().begins_with("+Docked With:"):
		var docked_with = _parse_required_token("+Docked With:")
		var docker_point = _parse_required_token("$Docker Point:")
		var dockee_point = _parse_required_token("$Dockee Point:")
		# Create DockingPairData resource and add to ship_instance.initial_docking
		# Need DockingPairData resource script first.
		print(f"TODO: Parse Docking: {ship_instance.ship_name} docked with {docked_with}")

	# --- Destroy At ---
	var destroy_at_str = _parse_optional_token("+Destroy At:")
	if destroy_at_str != null: ship_instance.destroy_before_mission_time = destroy_at_str.to_int()

	# --- Orders Accepted ---
	var orders_str = _parse_optional_token("+Orders Accepted:")
	if orders_str != null: ship_instance.orders_accepted = orders_str.to_int()

	# --- Group ---
	ship_instance.group = int(_parse_optional_token("+Group:") or "0")

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
	ship_instance.persona_index = int(_parse_optional_token("+Persona Index:") or "-1")

	# --- Texture Replacements ---
	# TODO: Parse $Texture Replace: blocks and create TextureReplacementData resources
	var tex_replace_token = _parse_optional_token("$Texture Replace:") or _parse_optional_token("$Duplicate Model Texture Replace:")
	if tex_replace_token != null:
		while _peek_line() != null and _peek_line().begins_with("+old:"):
			var old_tex = _parse_required_token("+old:")
			var new_tex = _parse_required_token("+new:")
			# Create TextureReplacementData resource and add to ship_instance.texture_replacements
			# Need TextureReplacementData resource script first.
			print(f"TODO: Parse Texture Replace: {old_tex} -> {new_tex}")

	# --- Alt Names ---
	ship_instance.alt_type_name = _parse_optional_token("$Alt:") or ""
	ship_instance.callsign_name = _parse_optional_token("$Callsign:") or ""

	# --- Alternate Ship Classes ---
	# TODO: Parse $Alt Ship Class: blocks and create AltClassData resources
	while _peek_line() != null and _peek_line().begins_with("$Alt Ship Class:"):
		var alt_class_name = _parse_required_token("$Alt Ship Class:")
		var default_class = _parse_optional_token("+Default Class:") != null
		# Create AltClassData resource and add to ship_instance.alternate_classes
		# Need AltClassData resource script first.
		print(f"TODO: Parse Alt Class: {alt_class_name}, Default: {default_class}")

	# --- Subsystems ---
	# TODO: Parse +Subsystem: blocks and create SubsystemStatusData resources
	while _peek_line() != null and _peek_line().begins_with("+Subsystem:"):
		var subsys_name = _parse_required_token("+Subsystem:")
		var damage_pct_str = _parse_optional_token("$Damage:")
		var cargo_name_str = _parse_optional_token("+Cargo Name:")
		var ai_class_name_str = _parse_optional_token("+AI Class:")
		var primary_banks_str = _parse_optional_token("+Primary Banks:")
		var pbank_ammo_str = _parse_optional_token("+Pbank Ammo:")
		var secondary_banks_str = _parse_optional_token("+Secondary Banks:")
		var sbank_ammo_str = _parse_optional_token("+Sbank Ammo:")
		# Create SubsystemStatusData resource and add to ship_instance.subsystem_status
		# Need SubsystemStatusData resource script first.
		print(f"TODO: Parse Subsystem: {subsys_name}")


	return ship_instance


# --- Helper Functions (Duplicated for now, move to Base later) ---

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
		if line and not line.begins_with(';'): break
		_current_line_num += 1

func _parse_required_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _read_line()
	if line == null or not line.begins_with(expected_token):
		printerr(f"Error: Expected '{expected_token}' but found '{line}' at line {_current_line_num}")
		return ""
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
	var text_lines: PackedStringArray = []
	while true:
		var line = _read_line()
		if line == null:
			printerr("Error: Unexpected end of file while parsing multi-text")
			break
		if line.strip_edges() == "#end_multi_text":
			break
		text_lines.append(line)
	return "\n".join(text_lines)

func _parse_sexp(sexp_string_raw : String) -> SexpNode:
	# TODO: Implement actual SEXP parsing
	print(f"Warning: SEXP parsing not implemented. Placeholder for: {sexp_string_raw.left(50)}...")
	var node = SexpNode.new()
	# Placeholder logic
	if sexp_string_raw == "(true)":
		node.node_type = SexpNode.SexpNodeType.ATOM
		node.atom_subtype = SexpNode.SexpAtomSubtype.OPERATOR
		node.text = "true"
		node.op_code = OPERATOR_MAP.get("true", -1)
	elif sexp_string_raw == "(false)":
		node.node_type = SexpNode.SexpNodeType.ATOM
		node.atom_subtype = SexpNode.SexpAtomSubtype.OPERATOR
		node.text = "false"
		node.op_code = OPERATOR_MAP.get("false", -1)
	else:
		node.node_type = SexpNode.SexpNodeType.LIST
		var child_node = SexpNode.new()
		child_node.node_type = SexpNode.SexpNodeType.ATOM
		child_node.atom_subtype = SexpNode.SexpAtomSubtype.STRING
		child_node.text = sexp_string_raw
		node.children.append(child_node)
	return node
