class_name WCSLocalizationParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const LocalizationRes = preload("res://scripts/resources/ui/localisation/localization_resource.gd")


func _parse_content() -> Variant:
	var strings_by_locale: Dictionary = {
		"en": [],
		"de": [],
		"fr": [],
		"pl": [] # Just in case
	}
	var current_locale = "en" # Default to English

	_skip_empty_lines()
	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("#"):
			var lang = line.substr(1).strip_edges().to_lower()
			if lang == "english" or lang == "default":
				current_locale = "en"
			elif lang == "german":
				current_locale = "de"
			elif lang == "french":
				current_locale = "fr"
			elif lang == "polish":
				current_locale = "pl"
			continue

		if line.begins_with("$End"):
			continue # Just continue, don't break, there might be other sections

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
				
				if not strings_by_locale.has(current_locale):
					strings_by_locale[current_locale] = []
					
				strings_by_locale[current_locale].append(res)

	return strings_by_locale
