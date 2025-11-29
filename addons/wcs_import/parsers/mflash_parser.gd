class_name WCSMFlashParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const MFlashResource = preload("res://scripts/resources/effects/mflash/mflash_resource.gd")

func _parse_content() -> Variant:
	var mflashes: Array[MFlashResource] = []
	var current_mflash: MFlashResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Name:"):
			current_mflash = MFlashResource.new()
			current_mflash.name = _extract_string_value(line, "$Name:")
			mflashes.append(current_mflash)
		elif current_mflash:
			if line.begins_with("+Blob_name:"):
				current_mflash.blob_name = _extract_string_value(line, "+Blob_name:")
			elif line.begins_with("+Blob_id:"):
				current_mflash.blob_id = _extract_int_value(line, "+Blob_id:")
				
	return mflashes
