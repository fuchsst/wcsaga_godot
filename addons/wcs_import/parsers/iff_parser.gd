class_name WCSIffParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const IffResource = preload("res://scripts/resources/iff_defs/iff_resource.gd")
const IffManifest = preload("res://scripts/resources/iff_defs/iff_manifest.gd")


func _parse_content() -> Variant:
	var manifest = IffManifest.new()
	var current_iff: IffResource = null

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#End":
				break
			continue

		# Global Settings
		if line.begins_with("$Traitor IFF:"):
			manifest.traitor_iff_name = _extract_string_value(line, "$Traitor IFF:")
		elif line.begins_with("$Selection Color:") or line.begins_with("$Selection Colour:"):
			manifest.selection_color = _parse_color(line)
		elif line.begins_with("$Message Color:") or line.begins_with("$Message Colour:"):
			manifest.message_color = _parse_color(line)
		elif line.begins_with("$Tagged Color:") or line.begins_with("$Tagged Colour:"):
			manifest.tagged_color = _parse_color(line)
		elif line.begins_with("$Dimmed IFF brightness:"):
			manifest.dimmed_iff_brightness = _extract_int_value(line, "$Dimmed IFF brightness:")
		elif line.begins_with("$Use Alternate Blip Coloring:"):
			manifest.use_alternate_blip_coloring = true # Boolean flag presence check usually

		# Radar Blip Colors
		elif line.begins_with("$Missile Blip Color:") or line.begins_with("$Missile Blip Colour:"):
			manifest.missile_blip_color = _parse_color(line)
		elif line.begins_with("$Navbuoy Blip Color:") or line.begins_with("$Navbuoy Blip Colour:"):
			manifest.navbuoy_blip_color = _parse_color(line)
		elif line.begins_with("$Warping Blip Color:") or line.begins_with("$Warping Blip Colour:"):
			manifest.warping_blip_color = _parse_color(line)
		elif line.begins_with("$Node Blip Color:") or line.begins_with("$Node Blip Colour:"):
			manifest.node_blip_color = _parse_color(line)
		elif line.begins_with("$Tagged Blip Color:") or line.begins_with("$Tagged Blip Colour:"):
			manifest.tagged_blip_color = _parse_color(line)

		# Radar Flags
		elif line.begins_with("$Radar Target ID Flags:"):
			var flags = _extract_list_value(line)
			manifest.radar_crosshairs = "crosshairs" in flags
			manifest.radar_blink = "blink" in flags
			manifest.radar_pulsate = "pulsate" in flags
			manifest.radar_enlarge = "enlarge" in flags

		# IFF Entries
		elif line.begins_with("$IFF Name:"):
			current_iff = IffResource.new()
			current_iff.iff_name = _extract_string_value(line, "$IFF Name:")
			manifest.iffs.append(current_iff)

		elif current_iff:
			if line.begins_with("$Color:") or line.begins_with("$Colour:"):
				current_iff.color = _parse_color(line)
			elif line.begins_with("$Attacks:"):
				current_iff.attacks = _extract_list_value(line)
			elif line.begins_with("+Sees"):
				# Format: +Sees [IFF Name] As: ( R, G, B )
				var parts = line.split(" As:")
				if parts.size() == 2:
					var target_iff = parts[0].replace("+Sees", "").strip_edges()
					var color_val = _parse_color(parts[1])
					var perception = IFFPerception.new()
					perception.target_iff_name = target_iff
					perception.perceived_color = color_val
					current_iff.perceptions.append(perception)
			elif line.begins_with("$Flags:"):
				var flag_strings = _extract_list_value(line)
				for flag_str in flag_strings:
					match flag_str:
						"support allowed":
							current_iff.flags.append(IffResource.IFFFlags.SUPPORT_ALLOWED)
						"exempt from all teams at war":
							current_iff.flags.append(
								IffResource.IFFFlags.EXEMPT_FROM_ALL_TEAMS_AT_WAR
							)
						"orders hidden":
							current_iff.flags.append(IffResource.IFFFlags.ORDERS_HIDDEN)
						"orders shown":
							current_iff.flags.append(IffResource.IFFFlags.ORDERS_SHOWN)
						"wing name hidden":
							current_iff.flags.append(IffResource.IFFFlags.WING_NAME_HIDDEN)
			elif line.begins_with("$Default Ship Flags:"):
				var flag_strings = _extract_list_value(line)
				for flag_str in flag_strings:
					var flag := _parse_ship_flag(flag_str)
					if flag >= 0:
						current_iff.default_ship_flags.append(flag)
			elif line.begins_with("$Default Ship Flags2:"):
				var flag_strings = _extract_list_value(line)
				for flag_str in flag_strings:
					var flag := _parse_ship_flag2(flag_str)
					if flag >= 0:
						current_iff.default_ship_flags2.append(flag)

	return manifest


## Convert string flag to MissionEnums.ShipFlags enum
func _parse_ship_flag(flag_str: String) -> int:
	match flag_str.to_lower().strip_edges():
		"cargo-known": return MissionEnums.ShipFlags.CARGO_KNOWN
		"ignore-count": return MissionEnums.ShipFlags.IGNORE_COUNT
		"protect-ship": return MissionEnums.ShipFlags.PROTECT_SHIP
		"reinforcement": return MissionEnums.ShipFlags.REINFORCEMENT
		"no-shields": return MissionEnums.ShipFlags.NO_SHIELDS
		"escort": return MissionEnums.ShipFlags.ESCORT
		"player-start": return MissionEnums.ShipFlags.PLAYER_START
		"no-arrival-music": return MissionEnums.ShipFlags.NO_ARRIVAL_MUSIC
		"no-arrival-warp": return MissionEnums.ShipFlags.NO_ARRIVAL_WARP
		"no-departure-warp": return MissionEnums.ShipFlags.NO_DEPARTURE_WARP
		"locked": return MissionEnums.ShipFlags.LOCKED
		"invulnerable": return MissionEnums.ShipFlags.INVULNERABLE
		"hidden-from-sensors": return MissionEnums.ShipFlags.HIDDEN_FROM_SENSORS
		"scannable": return MissionEnums.ShipFlags.SCANNABLE
		"kamikaze": return MissionEnums.ShipFlags.KAMIKAZE
		"no-dynamic": return MissionEnums.ShipFlags.NO_DYNAMIC
		"red-alert-carry": return MissionEnums.ShipFlags.RED_ALERT_CARRY
		"beam-protect-ship": return MissionEnums.ShipFlags.BEAM_PROTECT_SHIP
		"guardian": return MissionEnums.ShipFlags.GUARDIAN
		"special-warp": return MissionEnums.ShipFlags.SPECIAL_WARP
		"vaporize": return MissionEnums.ShipFlags.VAPORIZE
		"stealth": return MissionEnums.ShipFlags.STEALTH
		"friendly-stealth-invisible": return MissionEnums.ShipFlags.FRIENDLY_STEALTH_INVISIBLE
		"dont-collide-invisible": return MissionEnums.ShipFlags.DONT_COLLIDE_INVISIBLE
		_:
			push_warning("Unknown ship flag: %s" % flag_str)
			return -1


## Convert string flag to MissionEnums.ShipFlags2 enum
func _parse_ship_flag2(flag_str: String) -> int:
	match flag_str.to_lower().strip_edges():
		"primitive-sensors": return MissionEnums.ShipFlags2.PRIMITIVE_SENSORS
		"no-subspace-drive": return MissionEnums.ShipFlags2.NO_SUBSPACE_DRIVE
		"nav-carry-status": return MissionEnums.ShipFlags2.NAV_CARRY_STATUS
		"affected-by-gravity": return MissionEnums.ShipFlags2.AFFECTED_BY_GRAVITY
		"toggle-subsystem-scanning": return MissionEnums.ShipFlags2.TOGGLE_SUBSYSTEM_SCANNING
		"targetable-as-bomb": return MissionEnums.ShipFlags2.TARGETABLE_AS_BOMB
		"no-builtin-messages": return MissionEnums.ShipFlags2.NO_BUILTIN_MESSAGES
		"primaries-locked": return MissionEnums.ShipFlags2.PRIMARIES_LOCKED
		"secondaries-locked": return MissionEnums.ShipFlags2.SECONDARIES_LOCKED
		"no-death-scream": return MissionEnums.ShipFlags2.NO_DEATH_SCREAM
		"always-death-scream": return MissionEnums.ShipFlags2.ALWAYS_DEATH_SCREAM
		"nav-needslink": return MissionEnums.ShipFlags2.NAV_NEEDSLINK
		"hide-ship-name": return MissionEnums.ShipFlags2.HIDE_SHIP_NAME
		"set-class-dynamically": return MissionEnums.ShipFlags2.SET_CLASS_DYNAMICALLY
		"lock-all-turrets": return MissionEnums.ShipFlags2.LOCK_ALL_TURRETS
		"afterburners-locked": return MissionEnums.ShipFlags2.AFTERBURNERS_LOCKED
		"force-shields-on": return MissionEnums.ShipFlags2.FORCE_SHIELDS_ON
		"hide-log-entries": return MissionEnums.ShipFlags2.HIDE_LOG_ENTRIES
		"no-arrival-log": return MissionEnums.ShipFlags2.NO_ARRIVAL_LOG
		"no-departure-log": return MissionEnums.ShipFlags2.NO_DEPARTURE_LOG
		"is-harmless": return MissionEnums.ShipFlags2.IS_HARMLESS
		_:
			push_warning("Unknown ship flag2: %s" % flag_str)
			return -1
