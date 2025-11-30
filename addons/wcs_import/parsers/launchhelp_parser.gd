class_name WCSLaunchHelpParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const HelpResource = preload("res://scripts/resources/ui/localisation/help_resource.gd")


func _parse_content() -> Variant:
	var res = HelpResource.new()
	res.topic = "Launch Help"
	res.category = "launch"

	var help_text = ""

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()
		if not line.begins_with(";"):
			help_text += line + "\n"

	res.text = help_text
	return res
