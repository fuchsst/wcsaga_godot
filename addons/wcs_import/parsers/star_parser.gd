class_name WCSStarParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const StarBitmapData = preload("res://scripts/resources/environment/stars/star_bitmap_data.gd")

func _parse_content() -> Variant:
	var stars: Array[StarBitmapData] = []
	var current_star: StarBitmapData = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Bitmap:"):
			current_star = StarBitmapData.new()
			current_star.filename = _extract_string_value(line, "$Bitmap:")
			stars.append(current_star)
				
	return stars
