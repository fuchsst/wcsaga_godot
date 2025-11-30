class_name WCSNebulaParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const NebulaAssets = preload("res://scripts/resources/environment/nebula/nebula_assets.gd")


func _parse_content() -> Variant:
	var assets = NebulaAssets.new()

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#end":
				# In nebula.tbl, #end appears twice (once for bitmaps, once for poofs).
				# We should just continue to parse the rest of the file.
				continue
			continue

		if line.begins_with("+Nebula:"):
			var bitmap = _extract_string_value(line, "+Nebula:")
			if not bitmap.is_empty():
				assets.backgrounds[bitmap] = null
		elif line.begins_with("+Poof:"):
			var poof = _extract_string_value(line, "+Poof:")
			if not poof.is_empty():
				assets.poofs[poof] = null

	return assets
