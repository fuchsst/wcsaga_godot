class_name WCSIconParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const IconResource = preload("res://scripts/resources/ui/icon_resource.gd")


func _parse_content() -> Variant:
	var icons: Array[IconResource] = []
	var current_icon: IconResource = null

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#end":
				break
			continue

		if line.begins_with("$Name:"):
			current_icon = IconResource.new()
			current_icon.name = _extract_string_value(line, "$Name:")
			icons.append(current_icon)
		elif current_icon:
			if line.begins_with("+Filename:"):
				current_icon.filename = _extract_string_value(line, "+Filename:")

	return icons
