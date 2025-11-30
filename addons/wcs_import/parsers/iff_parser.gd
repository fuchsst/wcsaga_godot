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
					current_iff.perceptions[target_iff] = color_val
			elif line.begins_with("$Flags:"):
				var flag_strings = _extract_list_value(line)
				for flag_str in flag_strings:
					match flag_str:
						"support allowed":
							current_iff.flags.append(IffResource.IFFFlags.SUPPORT_ALLOWED)
						"exempt from all teams at war":
							current_iff.flags.append(IffResource.IFFFlags.EXEMPT_FROM_ALL_TEAMS_AT_WAR)
						"orders hidden":
							current_iff.flags.append(IffResource.IFFFlags.ORDERS_HIDDEN)
						"orders shown":
							current_iff.flags.append(IffResource.IFFFlags.ORDERS_SHOWN)
						"wing name hidden":
							current_iff.flags.append(IffResource.IFFFlags.WING_NAME_HIDDEN)
			elif line.begins_with("$Default Ship Flags:"):
				current_iff.default_ship_flags = _extract_list_value(line)
			elif line.begins_with("$Default Ship Flags2:"):
				current_iff.default_ship_flags2 = _extract_list_value(line)
				
	return manifest
