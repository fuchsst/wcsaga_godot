class_name WCSStarParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const WCSSunData = preload("res://scripts/resources/environment/stars/sun_data.gd")
const WCSSunFlare = preload("res://scripts/resources/environment/stars/sun_flare.gd")
const WCSDebrisData = preload("res://scripts/resources/environment/stars/debris_data.gd")
const WCSStarBitmapData = preload("res://scripts/resources/environment/stars/star_bitmap_data.gd")

func _parse_content() -> Variant:
	var result = {
		"bitmaps": [],
		"suns": [],
		"debris": []
	}
	
	var current_star: WCSStarBitmapData = null
	var current_sun: Dictionary = {} # Use Dictionary to store raw data before texture loading
	var flare_textures: Dictionary = {} # Map index to filename
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				# Stars.tbl has multiple #end tags
				continue
			continue
			
		if line.begins_with("$Bitmap:"):
			current_star = WCSStarBitmapData.new()
			current_star.filename = _extract_string_value(line, "$Bitmap:")
			result["bitmaps"].append(current_star)
			
		elif line.begins_with("$Sun:"):
			current_sun = {
				"sun_name": _extract_string_value(line, "$Sun:"),
				"sunglow_filename": "",
				"color": Color.WHITE,
				"scale": 1.0,
				"flares": []
			}
			result["suns"].append(current_sun)
			
		elif line.begins_with("$Sunglow:"):
			if not current_sun.is_empty():
				current_sun["sunglow_filename"] = _extract_string_value(line, "$Sunglow:")
				
		elif line.begins_with("$SunRGBI:"):
			if not current_sun.is_empty():
				var values = _extract_vector_values(line, "$SunRGBI:")
				if values.size() >= 3:
					current_sun["color"] = Color(values[0], values[1], values[2])
					# Intensity (4th value) is often 1.0, we can store it or multiply color
					
		elif line.begins_with("$Flare:"):
			# Start parsing flares
			pass
			
		elif line.begins_with("+FlareCount:"):
			# We can ignore count and just parse entries
			pass
			
		elif line.begins_with("$FlareTexture"):
			# e.g. $FlareTexture1: coronaSunG0_001
			# Parse mapping of index to filename
			var parts = line.split(":", false, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()
				var idx_str = key.replace("$FlareTexture", "")
				if idx_str.is_valid_int():
					flare_textures[idx_str.to_int()] = value
			
		elif line.begins_with("$FlareGlow"):
			# e.g. $FlareGlow1:
			# Start of a flare definition
			if not current_sun.is_empty():
				current_sun["flares"].append({})
			
		elif line.begins_with("+FlareTexture:"):
			if not current_sun.is_empty() and not current_sun["flares"].is_empty():
				var flare_idx = _extract_int_value(line, "+FlareTexture:")
				# Resolve filename immediately if possible, or store index
				if flare_textures.has(flare_idx):
					current_sun["flares"].back()["texture_filename"] = flare_textures[flare_idx]
				else:
					current_sun["flares"].back()["texture_index"] = flare_idx
				
		elif line.begins_with("+FlarePos:"):
			if not current_sun.is_empty() and not current_sun["flares"].is_empty():
				current_sun["flares"].back()["position"] = _extract_float_value(line, "+FlarePos:")
				
		elif line.begins_with("+FlareScale:"):
			if not current_sun.is_empty() and not current_sun["flares"].is_empty():
				current_sun["flares"].back()["scale"] = _extract_float_value(line, "+FlareScale:")

		elif line.begins_with("$Debris:"):
			var debris = WCSDebrisData.new()
			debris.filename = _extract_string_value(line, "$Debris:")
			debris.is_nebula_debris = false
			result["debris"].append(debris)
			
		elif line.begins_with("$DebrisNeb:"):
			var debris = WCSDebrisData.new()
			debris.filename = _extract_string_value(line, "$DebrisNeb:")
			debris.is_nebula_debris = true
			result["debris"].append(debris)
				
	return result

func _extract_vector_values(line: String, prefix: String) -> Array[float]:
	var s = _extract_string_value(line, prefix)
	var parts = s.split(" ", false)
	var values: Array[float] = []
	for part in parts:
		values.append(part.to_float())
	return values
