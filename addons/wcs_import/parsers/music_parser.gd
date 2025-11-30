class_name WCSMusicParser
extends "res://addons/wcs_import/parsers/base_parser.gd"

const SoundtrackResource = preload("res://scripts/resources/sounds/soundtrack_resource.gd")
const MenuMusicResource = preload("res://scripts/resources/sounds/menu_music_resource.gd")

# Base path for music files - this should ideally be configurable or passed in
const MUSIC_BASE_PATH = "res://campaigns/hermes/soundtrack/"

func _parse_content() -> Variant:
	var soundtracks: Array[SoundtrackResource] = []
	var current_soundtrack: SoundtrackResource = null
	var track_index: int = 0
	var menu_music: MenuMusicResource = null
	
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
			elif line.begins_with("#Menu Music Start"):
				menu_music = MenuMusicResource.new()
			elif line.begins_with("#Menu Music End"):
				# We should probably return this or add it to a list?
				# For now, let's assume we return it as the last element or handle it separately.
				# The return type is Variant, so we could return a Dictionary or a custom object.
				# But the caller expects an Array of resources usually.
				# Let's append it to the array, but it's a different type.
				# This might break type safety if the array is typed.
				# Line 10: var soundtracks: Array[SoundtrackResource] = []
				# We need to change the return type or how we handle it.
				pass
			continue
			
		if menu_music != null:
			if line.begins_with("$Name:"):
				var label = _extract_string_value(line, "$Name:")
				var filename_line = _get_next_line()
				if filename_line.begins_with("$Filename:"):
					var filename = _extract_string_value(filename_line, "$Filename:")
					# Clean filename (remove comments)
					if ";" in filename:
						filename = filename.split(";")[0].strip_edges()
					
					if filename.ends_with(".wav"):
						filename = filename.replace(".wav", ".ogg")
						
					var path = MUSIC_BASE_PATH + filename
					var stream = null
					if FileAccess.file_exists(path):
						stream = load(path)
					else:
						push_warning("Menu music file not found: " + filename)
						
					match label:
						"Command Brief": menu_music.command_brief = stream
						"Brief1": menu_music.briefing_1 = stream
						"Brief2": menu_music.briefing_2 = stream
						"Brief3": menu_music.briefing_3 = stream
						"Brief4": menu_music.briefing_4 = stream
						"Success": menu_music.debriefing_success = stream
						"Average": menu_music.debriefing_average = stream
						"Failure": menu_music.debriefing_failure = stream
						"Hermes": menu_music.fiction_viewer = stream
						"Wellington": menu_music.prologue_menu = stream
						"Cinema": menu_music.credits = stream
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
				
	# Return a dictionary containing both
	return {
		"soundtracks": soundtracks,
		"menu_music": menu_music
	}
