class_name WCSMusicParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const SoundtrackResource = preload("res://scripts/resources/sounds/soundtrack_resource.gd")

# Base path for music files - this should ideally be configurable or passed in
const MUSIC_BASE_PATH = "res://campaigns/hermes/soundtrack/"

func _parse_content() -> Variant:
	var soundtracks: Array[SoundtrackResource] = []
	var current_soundtrack: SoundtrackResource = null
	var track_index: int = 0
	
	_skip_empty_lines()
	
	while _has_more_lines():
		var line = _get_next_line()
		
		if line.begins_with("#"):
			if line.begins_with("#SoundTrack Start"):
				current_soundtrack = SoundtrackResource.new()
				track_index = 0
			elif line.begins_with("#SoundTrack End"):
				if current_soundtrack:
					soundtracks.append(current_soundtrack)
					current_soundtrack = null
			continue
			
		if current_soundtrack == null:
			continue
			
		if line.begins_with("$Soundtrack Name:"):
			current_soundtrack.name = _extract_string_value(line, "$Soundtrack Name:")
		elif line.begins_with("+Allied Arrival Overlay:"):
			current_soundtrack.allied_arrival_overlay = _extract_boolean_value(line, "+Allied Arrival Overlay:")
		elif line.begins_with("+Lock in Ambient:"):
			current_soundtrack.lock_in_ambient = _extract_boolean_value(line, "+Lock in Ambient:")
		elif line.begins_with("$Name:"):
			# Format: $Name: filename.wav num_measures samples_per_measure ; usage
			var parts = line.substr(6).strip_edges().split(" ", false)
			var stream: AudioStream = null
			
			if parts.size() >= 1:
				var filename = parts[0]
				
				# We always convert music to .ogg, so force the extension
				if filename.ends_with(".wav"):
					filename = filename.replace(".wav", ".ogg")
					
				var path = MUSIC_BASE_PATH + filename
				
				if FileAccess.file_exists(path):
					stream = load(path)
				else:
					push_warning("Music file not found: " + filename + " (checked " + path + ")")

			# Assign to explicit field based on index
			match track_index:
				0: current_soundtrack.ambience = stream
				1: current_soundtrack.arrival_allied_normal = stream
				2: current_soundtrack.arrival_enemy_normal = stream
				3: current_soundtrack.battle_1 = stream
				4: current_soundtrack.battle_2 = stream
				5: current_soundtrack.battle_3 = stream
				6: current_soundtrack.arrival_allied_battle = stream
				7: current_soundtrack.arrival_enemy_battle = stream
				8: current_soundtrack.victory_1 = stream
				9: current_soundtrack.victory_2 = stream
				10: current_soundtrack.goal_failed = stream
				11: current_soundtrack.player_dead = stream
				
			track_index += 1
				
	return soundtracks
