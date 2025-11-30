class_name WCSSSMParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const SSMResource = preload("res://scripts/resources/weapons/ssm_resource.gd")


func _parse_content() -> Variant:
	var ssm_resource = SSMResource.new()

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#end":
				break
			continue

		if line.begins_with("$SSM:"):
			# Parse SSM definition
			pass

	return ssm_resource
