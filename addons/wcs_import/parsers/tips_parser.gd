class_name WCSTipsParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const TipsRes = preload("res://scripts/resources/ui/localisation/tips_resource.gd")


func _parse_content() -> Variant:
	var res = TipsRes.new()
	res.tips.clear()

	_skip_empty_lines()
	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("$End"):
			break

		if line.begins_with("$Tip:"):
			var tip = _extract_string_value(line, "$Tip:")
			if tip.begins_with('"') and tip.ends_with('"'):
				tip = tip.substr(1, tip.length() - 2)
			res.tips.append(tip)
		elif line.begins_with('"'):
			var tip = line.strip_edges()
			if tip.begins_with('"') and tip.ends_with('"'):
				tip = tip.substr(1, tip.length() - 2)
			res.tips.append(tip)

	return res
