class_name WCSCampaignParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for Freespace 2 campaign files (.fc2).

func _parse_content() -> Dictionary:
	var campaign_data = {
		"name": "",
		"type": "",
		"description": "",
		"missions": []
	}
	
	_current_line_index = 0
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
			
		if line.begins_with("$Name:"):
			campaign_data["name"] = _extract_string_value(line, "$Name:")
		elif line.begins_with("$Type:"):
			campaign_data["type"] = _extract_string_value(line, "$Type:")
		elif line.begins_with("+Description:"):
			campaign_data["description"] = _extract_string_value(line, "+Description:")
		elif line.begins_with("$Mission:"):
			campaign_data["missions"].append(_extract_string_value(line, "$Mission:"))
			
	return {"campaign": campaign_data}
