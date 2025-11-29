class_name WCSRankParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const RankRes = preload("res://scripts/resources/campaigns/rank_resource.gd")

func _parse_content() -> Variant:
	var ranks: Array = []
	var current_rank = null
	var in_promotion_text = false
	var promotion_text_buffer = ""
	
	_skip_empty_lines()
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("$Name:"):
			if current_rank != null:
				if in_promotion_text:
					current_rank.promotion_text = promotion_text_buffer.strip_edges()
				ranks.append(current_rank)
				
			current_rank = RankRes.new()
			current_rank.name = _extract_string_value(line, "$Name:")
			in_promotion_text = false
			promotion_text_buffer = ""
			
		elif line.begins_with("$Bitmap:"):
			if current_rank:
				current_rank.bitmap = _extract_string_value(line, "$Bitmap:")
				
		elif line.begins_with("$Promotion Text:"):
			in_promotion_text = true
			var inline_text = _extract_string_value(line, "$Promotion Text:")
			if not inline_text.is_empty():
				promotion_text_buffer += inline_text + "\n"
				
		elif line.begins_with("$End"):
			if current_rank:
				if in_promotion_text:
					current_rank.promotion_text = promotion_text_buffer.strip_edges()
				ranks.append(current_rank)
				current_rank = null
				in_promotion_text = false
				
		elif in_promotion_text:
			if line.begins_with("XTRA:"):
				continue
			promotion_text_buffer += line + "\n"
			
	if current_rank != null:
		if in_promotion_text:
			current_rank.promotion_text = promotion_text_buffer.strip_edges()
		ranks.append(current_rank)
		
	return ranks
