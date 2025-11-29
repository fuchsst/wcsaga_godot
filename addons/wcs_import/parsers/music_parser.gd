class_name WCSMusicParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const MusicResource = preload("res://scripts/resources/sounds/music_resource.gd")

func _parse_content() -> Variant:
	var tracks: Array[MusicResource] = []
	var current_track: MusicResource = null
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			continue
			
		if line.begins_with("$Name:"):
			current_track = MusicResource.new()
			current_track.title = _extract_string_value(line, "$Name:")
			tracks.append(current_track)
		elif current_track:
			if line.begins_with("+Filename:"):
				current_track.filename = _extract_string_value(line, "+Filename:")
				
	return tracks
