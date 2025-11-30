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
						"Command Brief":
							menu_music.command_brief = stream
							menu_music.command_brief_filename = filename
						"Brief1":
							menu_music.briefing_1 = stream
							menu_music.briefing_1_filename = filename
						"Brief2":
							menu_music.briefing_2 = stream
							menu_music.briefing_2_filename = filename
						"Brief3":
							menu_music.briefing_3 = stream
							menu_music.briefing_3_filename = filename
						"Brief4":
							menu_music.briefing_4 = stream
							menu_music.briefing_4_filename = filename
						"Success":
							menu_music.debriefing_success = stream
							menu_music.debriefing_success_filename = filename
						"Average":
							menu_music.debriefing_average = stream
							menu_music.debriefing_average_filename = filename
						"Failure":
							menu_music.debriefing_failure = stream
							menu_music.debriefing_failure_filename = filename
						"Hermes":
							menu_music.fiction_viewer = stream
							menu_music.fiction_viewer_filename = filename
						"Wellington":
							menu_music.prologue_menu = stream
							menu_music.prologue_menu_filename = filename
						"Cinema":
							menu_music.credits = stream
							menu_music.credits_filename = filename
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
			var filename = ""
			
			if parts.size() >= 1:
				filename = parts[0]
				
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
				0:
					current_soundtrack.ambience = stream
					current_soundtrack.ambience_filename = filename
				1:
					current_soundtrack.arrival_allied_normal = stream
					current_soundtrack.arrival_allied_normal_filename = filename
				2:
					current_soundtrack.arrival_enemy_normal = stream
					current_soundtrack.arrival_enemy_normal_filename = filename
				3:
					current_soundtrack.battle_1 = stream
					current_soundtrack.battle_1_filename = filename
				4:
					current_soundtrack.battle_2 = stream
					current_soundtrack.battle_2_filename = filename
				5:
					current_soundtrack.battle_3 = stream
					current_soundtrack.battle_3_filename = filename
				6:
					current_soundtrack.arrival_allied_battle = stream
					current_soundtrack.arrival_allied_battle_filename = filename
				7:
					current_soundtrack.arrival_enemy_battle = stream
					current_soundtrack.arrival_enemy_battle_filename = filename
				8:
					current_soundtrack.victory_1 = stream
					current_soundtrack.victory_1_filename = filename
				9:
					current_soundtrack.victory_2 = stream
					current_soundtrack.victory_2_filename = filename
				10:
					current_soundtrack.goal_failed = stream
					current_soundtrack.goal_failed_filename = filename
				11:
					current_soundtrack.player_dead = stream
					current_soundtrack.player_dead_filename = filename
				
			track_index += 1
				
	# Return a dictionary containing both
	return {
		"soundtracks": soundtracks,
		"menu_music": menu_music
	}
