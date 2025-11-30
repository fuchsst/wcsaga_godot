extends SceneTree

func _init():
	print("Starting Sound/Music Parser Verification...")
	
	var sound_parser = load("res://addons/wcs_import/parsers/sound_parser.gd").new()
	var music_parser = load("res://addons/wcs_import/parsers/music_parser.gd").new()
	
	# Test Sound Parser
	print("\nTesting Sound Parser...")
	var sound_file_path = "/home/fuchsst/data/projects/personal/wcsaga_godot_converter/source_assets/wcs_hermes_campaign/hermes_core/sounds.tbl"
	if FileAccess.file_exists(sound_file_path):
		var sounds = sound_parser.parse(sound_file_path)
		print("Parsed " + str(sounds.size()) + " sound entries.")
		if sounds.size() > 0:
			var s = sounds[0]
			print("First Sound: Sig=" + str(s.signature) + ", File=" + s.filename + ", Vol=" + str(s.default_volume))
	else:
		print("Error: sounds.tbl not found at " + sound_file_path)

	# Test Music Parser
	print("\nTesting Music Parser...")
	var music_file_path = "/home/fuchsst/data/projects/personal/wcsaga_godot_converter/source_assets/wcs_hermes_campaign/hermes_core/music.tbl"
	if FileAccess.file_exists(music_file_path):
		var soundtracks = music_parser.parse(music_file_path)
		print("Parsed " + str(soundtracks.size()) + " soundtracks.")
		if soundtracks.size() > 0:
			var st = soundtracks[0]
			print("First Soundtrack: " + st.name)
			
			# Verify explicit fields
			if st.ambience:
				print("  Ambience: " + st.ambience.filename)
			if st.battle_1:
				print("  Battle 1: " + st.battle_1.filename)
			if st.victory_1:
				print("  Victory 1: " + st.victory_1.filename)
			if st.player_dead:
				print("  Player Dead: " + st.player_dead.filename)
	else:
		print("Error: music.tbl not found at " + music_file_path)
		
	quit()
