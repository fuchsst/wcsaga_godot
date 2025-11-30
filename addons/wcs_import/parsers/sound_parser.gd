class_name WCSSoundParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const AudioConfigResource = preload("res://scripts/resources/sounds/audio_config_resource.gd")
const FlybySoundResource = preload("res://scripts/resources/sounds/flyby_sound_resource.gd")

# Base path for sound files
const SOUND_BASE_PATH = "res://assets/sounds/"


func _parse_content() -> Variant:
	var audio_configs: Array[AudioConfigResource] = []
	var flyby_sounds: Array[FlybySoundResource] = []
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
			var config = AudioConfigResource.new()
			_parse_audio_entry(line, config, 6)  # 6 chars for "$Name:"
			audio_configs.append(config)

		elif (
			line.begins_with("$Terran:")
			or line.begins_with("$Pirate:")
			or line.begins_with("$Kilrathi:")
		):
			# Format: $Faction: index filename, ...
			var config = FlybySoundResource.new()
			var faction_end = line.find(":")
			config.faction = line.substr(1, faction_end - 1)

			_parse_audio_entry(line, config, faction_end + 1)

			# Extract index from the first part of the entry
			# _parse_audio_entry sets signature, we can use that as index
			config.index = config.signature

			flyby_sounds.append(config)

	return {"audio_configs": audio_configs, "flyby_sounds": flyby_sounds}


func _parse_audio_entry(line: String, config: AudioConfigResource, prefix_len: int) -> void:
	# Remove comment
	var comment_idx = line.find(";")
	var clean_line = line
	if comment_idx != -1:
		clean_line = line.substr(0, comment_idx)

	# Remove prefix
	clean_line = clean_line.substr(prefix_len).strip_edges()

	var parts = clean_line.split(",")

	if parts.size() > 0:
		var first_part = parts[0].strip_edges().split(" ", false)
		if first_part.size() >= 2:
			config.signature = first_part[0].to_int()
			var filename = first_part[1]

			config.filename = filename

			# Stream will be loaded by CLI runner after conversion
			# var path = SOUND_BASE_PATH + filename
			# if FileAccess.file_exists(path):
			# 	config.audio_stream = load(path)

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
