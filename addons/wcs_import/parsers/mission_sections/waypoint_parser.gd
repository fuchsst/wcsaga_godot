class_name WaypointParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Waypoints section (#Waypoints)
## Handles waypoint path definitions

const WaypointList = preload("res://scripts/resources/missions/waypoint_list.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Waypoints are parsed one at a time, each starting with $Name:
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_get_next_line()
			continue
		
		# Each waypoint list starts with $Name:
		if line.begins_with("$Name:"):
			_parse_single_waypoint_list(manifest)
		else:
			_get_next_line() # Skip unexpected lines
	
	return _base_parser._current_line_index


func _parse_single_waypoint_list(manifest: Resource):
	var wp_list = WaypointList.new()
	
	# First line is the name
	var name_line = _get_next_line()
	wp_list.name = _extract_string_value(name_line, "$Name:")
	
	# Parse properties until we hit the next $Name: or section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next waypoint list or section
		if line.begins_with("$Name:") or line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse each field
		if line.begins_with("$List:"):
			wp_list.waypoint_names = _parse_quoted_list(line, "$List:")
	
	# Add to manifest
	manifest.waypoints.append(wp_list)
