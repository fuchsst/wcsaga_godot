@tool
extends Resource
class_name MusicEntry

# Pattern types matching original game
enum Pattern {
	NRML_1,  # Normal 1
	NRML_2,  # Normal 2
	NRML_3,  # Normal 3
	AARV_1,  # Ally arrival 1
	AARV_2,  # Ally arrival 2
	EARV_1,  # Enemy arrival 1
	EARV_2,  # Enemy arrival 2
	BTTL_1,  # Battle 1
	BTTL_2,  # Battle 2
	BTTL_3,  # Battle 3
	FAIL_1,  # Failure 1
	VICT_1,  # Victory 1
	VICT_2,  # Victory 2
	DEAD_1,  # Dead 1
}

# Soundtrack flags matching original game
enum SoundtrackFlags {
	NONE = 0,
	VALID = 1 << 0,
	ALLIED_ARRIVAL_OVERLAY = 1 << 1,
	CYCLE_FS1 = 1 << 2,
	LOCK_IN_NORMAL = 1 << 3
}

# Core properties
@export var audio_stream: AudioStream  # The actual music data
@export var pattern: Pattern  # Which pattern this music is for
@export var flags: SoundtrackFlags = SoundtrackFlags.NONE
@export var name: String = ""  # Soundtrack name
@export var default_volume: float = 1.0  # Base volume level

# Pattern info
@export var can_force: bool = false  # Whether pattern can be force-switched
@export var loop_for: int = 1  # How many times to loop
@export var next_pattern_fs1: Pattern  # Next pattern in FS1 mode
@export var next_pattern_fs2: Pattern  # Next pattern in FS2 mode

# Runtime properties
var loaded_audio_player: AudioStreamPlayer  # Cached player for preloaded music

func _init():
	# Generate name if not set
	if name.is_empty():
		name = str(pattern)

func _get_property_list() -> Array:
	# Editor properties
	var properties = []
	properties.append({
		"name": "resource_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT
	})
	return properties

# Runtime methods
func preload_music() -> void:
	if audio_stream and not loaded_audio_player:
		loaded_audio_player = AudioStreamPlayer.new()
		loaded_audio_player.stream = audio_stream
		loaded_audio_player.bus = "Music"

func unload_music() -> void:
	if loaded_audio_player:
		loaded_audio_player.queue_free()
		loaded_audio_player = null
