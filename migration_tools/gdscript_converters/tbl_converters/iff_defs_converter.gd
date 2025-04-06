@tool
extends BaseTblConverter
# Converts iff_defs.tbl into a Godot resource (iff_defs.tres)

# --- Dependencies ---
const IffDefsData = preload("res://scripts/resources/game_data/iff_defs_data.gd")
const TblParserUtils = preload("res://migration_tools/gdscript_converters/tbl_converters/tbl_parser_utils.gd")
# Preload GlobalConstants for flag definitions
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- Configuration ---
const INPUT_TBL_PATH = "res://migration_tools/extracted_tables/iff_defs.tbl" # Adjust if needed
const OUTPUT_RES_PATH = "res://resources/game_data/iff_defs.tres"

# --- Flag Definitions (Using GlobalConstants) ---
const IFFF_FLAG_MAP: Dictionary = {
	"support allowed": GlobalConstants.IFFF_SUPPORT_ALLOWED,
	"exempt from all teams at war": GlobalConstants.IFFF_EXEMPT_FROM_ALL_TEAMS_AT_WAR,
	"orders hidden": GlobalConstants.IFFF_ORDERS_HIDDEN,
	"orders shown": GlobalConstants.IFFF_ORDERS_SHOWN,
	"wing name hidden": GlobalConstants.IFFF_WING_NAME_HIDDEN,
}

const P_FLAG_MAP: Dictionary = {
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
	"use unique orders": GlobalConstants.P_SF_USE_UNIQUE_ORDERS, # Check exact TBL string
	"dock leader": GlobalConstants.P_SF_DOCK_LEADER, # Check exact TBL string
	"warp drive broken": GlobalConstants.P_SF_WARP_BROKEN, # Check exact TBL string
	"never warps": GlobalConstants.P_SF_WARP_NEVER, # Check exact TBL string
}

const P2_FLAG_MAP: Dictionary = {
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
	"lock-all-turrets": GlobalConstants.P2_SF2_LOCK_ALL_TURRETS_INITIALLY,
	"afterburners-locked": GlobalConstants.P2_SF2_AFTERBURNER_LOCKED,
	"force-shields-on": GlobalConstants.P2_OF_FORCE_SHIELDS_ON,
	"hide-log-entries": GlobalConstants.P2_SF2_HIDE_LOG_ENTRIES,
	"no-arrival-log": GlobalConstants.P2_SF2_NO_ARRIVAL_LOG,
	"no-departure-log": GlobalConstants.P2_SF2_NO_DEPARTURE_LOG,
	"is_harmless": GlobalConstants.P2_SF2_IS_HARMLESS,
}

# --- Main Execution ---
func _run():
	print("Converting iff_defs.tbl...")

	var file = FileAccess.open(INPUT_TBL_PATH, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {INPUT_TBL_PATH}")
		return

	var iff_data = IffDefsData.new()
	var temp_attacks: Dictionary = {} # { iff_name: [attackee_name1, ...] }
	var temp_sees_as: Dictionary = {} # { iff_name: { target_name: Color, ...} }

	# --- Parsing Logic ---
	var current_line_num_ref = [0] # Use array as reference for helper functions
	var current_iff_name = ""
	var current_iff_dict = {}

	while not file.eof_reached():
		var line = _peek_line(file)

		# Skip comments and empty lines
		if line == null or line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_read_line(file, current_line_num_ref) # Consume the line
			continue

		# Handle section markers
		if line.begins_with("#"):
			_read_line(file, current_line_num_ref) # Consume the section line
			if line == "#IFFs":
				print("  Parsing #IFFs section...")
			elif line == "#End":
				print("  Reached #End.")
				break # Stop parsing
			else:
				printerr(f"Warning: Unexpected section '{line}' at line {current_line_num_ref[0]}. Skipping.")
			continue

		# Handle key-value pairs
		if line.begins_with("$"):
			var parts = line.split(":", false, 1)
			if parts.size() != 2:
				printerr(f"Warning: Malformed line '{line}' at line {current_line_num_ref[0]}. Skipping.")
				_read_line(file, current_line_num_ref) # Consume the bad line
				continue

			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			_read_line(file, current_line_num_ref) # Consume the key-value line

			# --- Global Settings ---
			if key == "$Traitor IFF":
				iff_data.traitor_iff_name = value
			elif key == "$Selection Color" or key == "$Selection Colour":
				iff_data.selection_color = TblParserUtils.parse_color(value)
			elif key == "$Message Color" or key == "$Message Colour":
				iff_data.message_color = TblParserUtils.parse_color(value)
			elif key == "$Tagged Color" or key == "$Tagged Colour":
				iff_data.tagged_color = TblParserUtils.parse_color(value)
			elif key == "$Dimmed IFF brightness":
				iff_data.dimmed_iff_brightness = TblParserUtils.parse_int(value)
			elif key == "$Use Alternate Blip Coloring":
				iff_data.use_alternate_blip_coloring = TblParserUtils.parse_bool(value)
			elif key == "$Missile Blip Color" or key == "$Missile Blip Colour":
				iff_data.radar_missile_blip_color = TblParserUtils.parse_color(value)
			elif key == "$Navbuoy Blip Color" or key == "$Navbuoy Blip Colour":
				iff_data.radar_navbuoy_blip_color = TblParserUtils.parse_color(value)
			elif key == "$Warping Blip Color" or key == "$Warping Blip Colour":
				iff_data.radar_warping_blip_color = TblParserUtils.parse_color(value)
			elif key == "$Node Blip Color" or key == "$Node Blip Colour":
				iff_data.radar_node_blip_color = TblParserUtils.parse_color(value)
			elif key == "$Tagged Blip Color" or key == "$Tagged Blip Colour":
				iff_data.radar_tagged_blip_color = TblParserUtils.parse_color(value)
			elif key == "$Radar Target ID Flags":
				# TODO: Implement flag parsing based on rti_flags definition
				# iff_data.radar_target_id_flags = TblParserUtils.parse_flags(value, rti_flags)
				print(f"Warning: Radar Target ID Flag parsing not implemented yet for line {current_line_num_ref[0]}")
				pass

			# --- IFF Entry Start ---
			elif key == "$IFF Name":
				# Store previous IFF entry if one was being built
				if not current_iff_name.is_empty():
					iff_data.iff_definitions.append(current_iff_dict)

				# Start new entry
				current_iff_name = value
				current_iff_dict = {
					"name": current_iff_name,
					"default_color": Color.WHITE, # Default
					"flags": 0,
					"default_ship_flags": 0,
					"default_ship_flags2": 0,
					# attacks and sees_as will be added later from temp dicts
				}
				temp_attacks[current_iff_name] = []
				temp_sees_as[current_iff_name] = {}
				print(f"  Parsing IFF: {current_iff_name}")

			# --- IFF Entry Fields ---
			elif key == "$Color" or key == "$Colour":
				if current_iff_name.is_empty(): printerr(f"Error: Found {key} outside an IFF definition at line {current_line_num_ref[0]}"); continue
				current_iff_dict["default_color"] = TblParserUtils.parse_color(value)
			elif key == "$Attacks":
				if current_iff_name.is_empty(): printerr(f"Error: Found {key} outside an IFF definition at line {current_line_num_ref[0]}"); continue
				temp_attacks[current_iff_name] = value.split() # Split by space
			elif key == "$Flags":
				if current_iff_name.is_empty(): printerr(f"Error: Found {key} outside an IFF definition at line {current_line_num_ref[0]}"); continue
				current_iff_dict["flags"] = TblParserUtils.parse_flags(value, IFFF_FLAG_MAP)
			elif key == "$Default Ship Flags":
				if current_iff_name.is_empty(): printerr(f"Error: Found {key} outside an IFF definition at line {current_line_num_ref[0]}"); continue
				current_iff_dict["default_ship_flags"] = TblParserUtils.parse_flags(value, P_FLAG_MAP)
			elif key == "$Default Ship Flags2":
				if current_iff_name.is_empty(): printerr(f"Error: Found {key} outside an IFF definition at line {current_line_num_ref[0]}"); continue
				current_iff_dict["default_ship_flags2"] = TblParserUtils.parse_flags(value, P2_FLAG_MAP)
			else:
				# Potentially handle other keys or log warnings
				# print(f"Warning: Unhandled key '{key}' at line {current_line_num_ref[0]}")
				pass

		# Handle +Sees lines (not starting with $)
		elif line.begins_with("+Sees"):
			_read_line(file, current_line_num_ref) # Consume the line
			if current_iff_name.is_empty(): printerr(f"Error: Found '+Sees' outside an IFF definition at line {current_line_num_ref[0]}"); continue
			# Format: +Sees <TargetIFF> As: <R> <G> <B>
			var sees_parts = line.split(" As:", false, 1)
			if sees_parts.size() != 2: printerr(f"Warning: Malformed '+Sees' line '{line}' at line {current_line_num_ref[0]}"); continue
			var target_iff = sees_parts[0].trim_prefix("+Sees").strip_edges()
			var color_str = sees_parts[1].strip_edges()
			temp_sees_as[current_iff_name][target_iff] = TblParserUtils.parse_color(color_str) # Use Utils
		else:
			# Ignore other lines for now
			_read_line(file, current_line_num_ref) # Consume the line
			pass

	# Add the last parsed IFF entry
	if not current_iff_name.is_empty():
		iff_data.iff_definitions.append(current_iff_dict)

	file.close()

	# --- Post-Process Relationships ---
	print("  Post-processing IFF relationships...")
	for i in range(iff_data.iff_definitions.size()):
		var entry_dict = iff_data.iff_definitions[i]
		var iff_name = entry_dict["name"]
		entry_dict["attacks"] = temp_attacks.get(iff_name, [])
		entry_dict["sees_as"] = temp_sees_as.get(iff_name, {})

	# --- Save Resource ---
	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	DirAccess.make_dir_recursive_absolute(OUTPUT_RES_PATH.get_base_dir())
	var save_result = ResourceSaver.save(iff_data, OUTPUT_RES_PATH, save_flags)

	if save_result != OK:
		printerr(f"Error saving resource '{OUTPUT_RES_PATH}': {save_result}")
	else:
		print(f"Successfully converted iff_defs.tbl to {OUTPUT_RES_PATH}")
