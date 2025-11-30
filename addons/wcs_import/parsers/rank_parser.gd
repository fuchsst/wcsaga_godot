class_name WCSRankParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const RankRes = preload("res://scripts/resources/campaigns/rank_resource.gd")
const RankManifest = preload("res://scripts/resources/campaigns/rank_manifest.gd")


func _parse_content() -> Variant:
	var manifest = RankManifest.new()
	var current_rank = null
	var in_promotion_text = false
	var promotion_text_buffer = ""

	_skip_empty_lines()

	# Skip [RANK NAMES] header if present
	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("[RANK NAMES]"):
			_get_next_line()  # Consume it
			break
		if line.begins_with("$Name:"):
			break
		_get_next_line()

	while _has_more_lines():
		var line = _get_next_line()

		if line.begins_with("$Name:"):
			if current_rank != null:
				if in_promotion_text:
					current_rank.promotion_text = promotion_text_buffer.strip_edges()
				manifest.ranks.append(current_rank)

			current_rank = RankRes.new()
			current_rank.name = _extract_string_value(line, "$Name:")
			in_promotion_text = false
			promotion_text_buffer = ""

		elif line.begins_with("$Points:"):
			if current_rank:
				current_rank.points = _extract_int_value(line, "$Points:")

		elif line.begins_with("$Bitmap:"):
			current_rank._bitmap_filename = _extract_string_value(line, "$Bitmap:")

		elif line.begins_with("$Promotion Voice Base:"):
			current_rank._promotion_voice_base = _extract_string_value(
				line, "$Promotion Voice Base:"
			)

		elif line.begins_with("$Promotion Text:"):
			in_promotion_text = true
			var inline_text = _extract_string_value(line, "$Promotion Text:")
			if not inline_text.is_empty():
				promotion_text_buffer += inline_text + "\n"

		elif line.begins_with("#End"):
			if current_rank:
				if in_promotion_text:
					current_rank.promotion_text = promotion_text_buffer.strip_edges()
				manifest.ranks.append(current_rank)
				current_rank = null
				in_promotion_text = false

		elif in_promotion_text:
			if line.begins_with("XTRA:"):
				continue
			promotion_text_buffer += line + "\n"

	if current_rank != null:
		if in_promotion_text:
			current_rank.promotion_text = promotion_text_buffer.strip_edges()
		manifest.ranks.append(current_rank)

	return manifest
