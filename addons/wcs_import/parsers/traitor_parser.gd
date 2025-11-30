class_name WCSTraitorParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const TraitorRes = preload("res://scripts/resources/campaigns/traitor_resource.gd")


func _parse_content() -> Variant:
	var res = TraitorRes.new()
	var in_debriefing = false
	var debriefing_buffer = ""

	_skip_empty_lines()
	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("$Debriefing:"):
			in_debriefing = true
			var inline_text = _extract_string_value(line, "$Debriefing:")
			if not inline_text.is_empty():
				debriefing_buffer += inline_text + "\n"

		elif line.begins_with("$End"):
			if in_debriefing:
				res.debriefing_text = debriefing_buffer.strip_edges()
				in_debriefing = false

		elif in_debriefing:
			if line.begins_with("XTRA:"):
				continue
			debriefing_buffer += line + "\n"

	if in_debriefing:
		res.debriefing_text = debriefing_buffer.strip_edges()

	return res
