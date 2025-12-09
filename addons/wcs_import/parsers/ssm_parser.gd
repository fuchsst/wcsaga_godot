class_name WCSSSMParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const SSMResource = preload("res://scripts/resources/weapons/ssm_resource.gd")


func _parse_content() -> Variant:
	var ssm_list: Array = []

	_skip_empty_lines()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			if line == "#end":
				break
			continue

		if line.begins_with("$SSM:"):
			# Parse SSM definition
			var ssm_resource = SSMResource.new()
			ssm_resource.name = _extract_string_value(line, "$SSM:")
			ssm_list.append(ssm_resource)

	return ssm_list
