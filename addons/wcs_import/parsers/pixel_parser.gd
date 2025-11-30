class_name WCSPixelParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const PixelsResource = preload("res://scripts/resources/environment/stars/pixels_resource.gd")


func _parse_content() -> Variant:
	var pixels_resource = PixelsResource.new()

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#end":
				break
			continue

		# Parse pixel definitions
		# Format is usually just numbers or simple keys
		pass

	return pixels_resource
