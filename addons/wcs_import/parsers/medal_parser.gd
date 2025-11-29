class_name WCSMedalParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const MedalRes = preload("res://scripts/resources/campaigns/medal_resource.gd")
const MedalManifest = preload("res://scripts/resources/campaigns/medal_manifest.gd")

func _parse_content() -> Variant:
	var manifest = MedalManifest.new()
	var current_medal = null
	var in_promotion_text = false
	var promotion_text_buffer = ""
	var badge_counter = 0
	
	_skip_empty_lines()
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("$Name:"):
			if current_medal != null:
				if in_promotion_text:
					current_medal.promotion_text = promotion_text_buffer.strip_edges()
				manifest.medals.append(current_medal)
				
			current_medal = MedalRes.new()
			current_medal.name = _extract_string_value(line, "$Name:")
			in_promotion_text = false
			promotion_text_buffer = ""
			
		elif line.begins_with("$Bitmap:"):
			if current_medal:
				current_medal.bitmap = _extract_string_value(line, "$Bitmap:")
				
		elif line.begins_with("$Num mods:"):
			if current_medal:
				current_medal.num_mods = _extract_int_value(line, "$Num mods:")
				
		elif line.begins_with("+Num Kills:"):
			if current_medal:
				current_medal.kills_needed = _extract_int_value(line, "+Num Kills:")
				current_medal.badge_num = badge_counter
				badge_counter += 1
				
		elif line.begins_with("$Wavefile Base:"):
			if current_medal:
				current_medal.wavefile_base = _extract_string_value(line, "$Wavefile Base:")

		elif line.begins_with("$Wavefile 1:"):
			if current_medal:
				current_medal.wavefile_1 = _extract_string_value(line, "$Wavefile 1:")

		elif line.begins_with("$Wavefile 2:"):
			if current_medal:
				current_medal.wavefile_2 = _extract_string_value(line, "$Wavefile 2:")
				
		elif line.begins_with("$Promotion Text:"):
			in_promotion_text = true
			var inline_text = _extract_string_value(line, "$Promotion Text:")
			if not inline_text.is_empty():
				promotion_text_buffer += inline_text + "\n"
				
		elif line.begins_with("#End"):
			if current_medal:
				if in_promotion_text:
					current_medal.promotion_text = promotion_text_buffer.strip_edges()
				manifest.medals.append(current_medal)
				current_medal = null
				in_promotion_text = false
				
		elif in_promotion_text:
			if line.begins_with("XTRA:"):
				continue
			promotion_text_buffer += line + "\n"
			
	if current_medal != null:
		if in_promotion_text:
			current_medal.promotion_text = promotion_text_buffer.strip_edges()
		manifest.medals.append(current_medal)
		
	return manifest
