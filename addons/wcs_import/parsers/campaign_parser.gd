class_name WCSCampaignParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

## Parser for Freespace 2 campaign files (.fc2).

const CampaignManifest = preload("res://scripts/resources/campaigns/campaign_manifest.gd")
const CampaignMission = preload("res://scripts/resources/campaigns/campaign_mission.gd")

func _parse_content() -> Variant:
	var manifest = CampaignManifest.new()
	
	_current_line_index = 0
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
			
		if line.begins_with("$Name:"):
			manifest.campaign_name = _extract_string_value(line, "$Name:")
		elif line.begins_with("$Type:"):
			manifest.campaign_type = _extract_string_value(line, "$Type:")
		elif line.begins_with("+Description:"):
			manifest.description = _extract_string_value(line, "+Description:")
		elif line.begins_with("$Mission:"):
			var mission_name = _extract_string_value(line, "$Mission:")
			var mission = CampaignMission.new()
			mission.mission_name = mission_name
			manifest.missions.append(mission)
			
	return manifest
