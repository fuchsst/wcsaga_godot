class_name WCSMenuParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const MenuResource = preload("res://scripts/resources/ui/menus/menu_resource.gd")


func _parse_content() -> Variant:
	var menu_resource = MenuResource.new()

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#end":
				break
			continue

		if line.begins_with("$Menu:"):
			# Parse menu definition
			pass
		elif line.begins_with("+Filename:"):
			menu_resource.bitmap_filename = _extract_string_value(line, "+Filename:")

	return menu_resource
