extends GdUnitTestSuite

const SoundParser = preload("res://addons/wcs_import/parsers/sound_parser.gd")
const MusicParser = preload("res://addons/wcs_import/parsers/music_parser.gd")
const SoundtrackResource = preload("res://scripts/resources/sounds/soundtrack_resource.gd")

var _sound_parser
var _music_parser


func before():
	_sound_parser = SoundParser.new()
	_music_parser = MusicParser.new()


func test_parse_sounds_tbl():
	var path = "res://../source_assets/wcs_hermes_campaign/hermes_core/sounds.tbl"
	# We need to ensure the file exists or mock it.
	# Since we are running in the project context and source_assets is outside,
	# we might need to use absolute path or ensure it's accessible.
	# However, GdUnit runs in Godot, so it uses res:// or user://.
	# The source_assets are NOT in res://.
	# But the previous verification script used absolute path.

	path = "/home/fuchsst/data/projects/personal/wcsaga_godot_converter/source_assets/wcs_hermes_campaign/hermes_core/sounds.tbl"

	if not FileAccess.file_exists(path):
		# Skip if file not found (e.g. in CI without assets)
		return

	var sounds = _sound_parser.parse(path)

	assert_that(sounds).is_not_empty()
	assert_that(sounds.size()).is_greater(10)

	var s = sounds[0]
	# assert_that(s.filename).is_equal("snd_missile_tracking.wav") # Property removed
	assert_that(s.signature).is_equal(0)
	assert_that(s.default_volume).is_equal(0.4)

	# We can't easily verify audio_stream is loaded if files are missing
	# But we can verify the parser logic worked for other fields


func test_parse_music_tbl():
	var path = "/home/fuchsst/data/projects/personal/wcsaga_godot_converter/source_assets/wcs_hermes_campaign/hermes_core/music.tbl"

	if not FileAccess.file_exists(path):
		return

	var soundtracks = _music_parser.parse(path)

	assert_that(soundtracks).is_not_empty()

	var st = soundtracks[0]
	assert_that(st).is_instanceof(SoundtrackResource)
	assert_that(st.name).is_equal("Mission Failed")

	# We can't easily verify the AudioStream is loaded without the files being imported in Godot
	# But we can verify the parser didn't crash
