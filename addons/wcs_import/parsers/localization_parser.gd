class_name WCSLocalizationParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const LocalizationRes = preload("res://scripts/resources/ui/localisation/localization_resource.gd")


func _parse_content() -> Variant:
	var strings: Array = []

	_skip_empty_lines()
	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#") and not line.begins_with("#Default"):
			continue

		if line.begins_with("$End"):
			break

		# Handle tstrings +ID:
		if line.begins_with("+ID:"):
			line = line.substr(4).strip_edges()

		# Format: ID, "String"
		var comma_pos = line.find(",")
		if comma_pos != -1:
			var id_str = line.substr(0, comma_pos).strip_edges()
			var text_str = line.substr(comma_pos + 1).strip_edges()

			if id_str.is_valid_int():
				var res = LocalizationRes.new()
				res.id = id_str.to_int()

				if text_str.begins_with('"') and text_str.ends_with('"'):
					text_str = text_str.substr(1, text_str.length() - 2)

				res.text = text_str
				strings.append(res)

	return strings
