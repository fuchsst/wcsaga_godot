class_name WCSSoundParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const AudioConfigResource = preload("res://scripts/resources/sounds/audio_config_resource.gd")

# Base path for sound files
const SOUND_BASE_PATH = "res://assets/sounds/"

func _parse_content() -> Variant:
	var audio_configs: Array[AudioConfigResource] = []
	var current_section = ""
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line == "#end":
				break
			current_section = line
			continue
			
		if line.begins_with("$Name:"):
			# Format: $Name: index filename, preload, volume, 3d_flag, min_dist, max_dist
			# Note: The format in the file seems to be:
			# $Name: index filename, preload, volume, 3d_flag [, min_dist, max_dist] ; comment
			var config = AudioConfigResource.new()
			
			# Remove comment
			var comment_idx = line.find(";")
			var clean_line = line
			if comment_idx != -1:
				clean_line = line.substr(0, comment_idx)
			
			# Remove $Name:
			clean_line = clean_line.substr(6).strip_edges()
			
			# Split by comma first to handle the parts after filename
			# But the first part contains "index filename" separated by space
			
			# Let's try to parse manually
			var parts = clean_line.split(",")
			
			if parts.size() > 0:
				var first_part = parts[0].strip_edges().split(" ", false)
				if first_part.size() >= 2:
					config.signature = first_part[0].to_int()
					var filename = first_part[1]
					
					# Load AudioStream
					var path = SOUND_BASE_PATH + filename
					if not FileAccess.file_exists(path):
						# Try swapping extension
						if filename.ends_with(".wav"):
							path = SOUND_BASE_PATH + filename.replace(".wav", ".ogg")
						elif filename.ends_with(".ogg"):
							path = SOUND_BASE_PATH + filename.replace(".ogg", ".wav")
					
					if FileAccess.file_exists(path):
						config.audio_stream = load(path)
					else:
						push_warning("Sound file not found: " + filename + " (checked " + path + ")")
			
			if parts.size() > 1:
				config.preload_sound = parts[1].strip_edges().to_int() == 1
				
			if parts.size() > 2:
				config.default_volume = parts[2].strip_edges().to_float()
				
			if parts.size() > 3:
				config.is_3d = parts[3].strip_edges().to_int()
				
			if parts.size() > 4:
				config.min_distance = parts[4].strip_edges().to_float()
				
			if parts.size() > 5:
				config.max_distance = parts[5].strip_edges().to_float()
				
			audio_configs.append(config)
				
	return audio_configs
