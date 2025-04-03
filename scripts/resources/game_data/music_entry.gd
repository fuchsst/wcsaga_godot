# scripts/resources/game_data/music_entry.gd
extends Resource
class_name MusicEntry

## Defines properties for a single music track pattern, loaded from music.tbl.

# Enum mapping to original pattern names for clarity.
# Ensure this matches the order/values used in MusicManager and data loading.
enum MusicPattern {
	NRML_1, NRML_2, NRML_3,
	AARV_1, AARV_2,
	EARV_1, EARV_2,
	BTTL_1, BTTL_2, BTTL_3,
	FAIL_1,
	VICT_1, VICT_2,
	DEAD_1,
	NONE = -1
}

# The pattern type this entry represents (e.g., MusicPattern.BTTL_1).
@export var pattern_type: MusicPattern = MusicPattern.NONE

# Path to the AudioStream resource file (.ogg).
@export var audio_stream_path: String = ""
# Preloaded AudioStream resource.
@export var audio_stream: AudioStream = null

# Default next pattern to play after this one finishes (FS2 style).
@export var default_next_pattern_fs2: MusicPattern = MusicPattern.NONE
# Default next pattern to play after this one finishes (FS1 style).
@export var default_next_pattern_fs1: MusicPattern = MusicPattern.NONE

# Default number of times to loop this pattern before transitioning.
@export var default_loop_for: int = 1

# Can this pattern be interrupted (forced) by a higher priority event?
@export var can_force: bool = true

# Number of measures in the track (used for timing forced transitions).
@export var num_measures: float = 0.0
# Number of audio samples per measure (used for timing forced transitions).
@export var samples_per_measure: int = 0


func _init(p_pattern_type := MusicPattern.NONE, p_path := "", p_next_fs1 := MusicPattern.NONE, p_next_fs2 := MusicPattern.NONE, p_loop := 1, p_can_force := true, p_measures := 0.0, p_samples := 0):
	pattern_type = p_pattern_type
	audio_stream_path = p_path
	default_next_pattern_fs1 = p_next_fs1
	default_next_pattern_fs2 = p_next_fs2
	default_loop_for = p_loop
	can_force = p_can_force
	num_measures = p_measures
	samples_per_measure = p_samples
	if audio_stream_path != "":
		# Music is usually streamed, so avoid preloading large files here.
		# Loading will be handled by MusicManager when needed.
		pass

func get_stream() -> AudioStream:
	"""Lazily loads the AudioStream if not already loaded."""
	if audio_stream == null and audio_stream_path != "":
		# Consider potential performance impact if called frequently.
		# MusicManager might manage loading/unloading streams.
		audio_stream = load(audio_stream_path)
	return audio_stream
