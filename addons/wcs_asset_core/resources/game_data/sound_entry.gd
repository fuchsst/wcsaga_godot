# addons/wcs_asset_core/resources/game_data/sound_entry.gd
extends Resource
class_name SoundEntry

## Defines properties for a single sound effect, loaded from sounds.tbl.

# The unique identifier/name for this sound (e.g., "SND_LASER_FIRE").
@export var id_name: String = ""

# Path to the AudioStream resource file (.ogg or .wav).
@export var audio_stream_path: String = ""
# Preloaded AudioStream resource.
@export var audio_stream: AudioStream = null

# Default volume (0.0 to 1.0). Corresponds to 'Vol' in sounds.tbl.
@export var default_volume: float = 1.0

# Minimum distance for 3D sound attenuation. Corresponds to 'Min' in sounds.tbl.
@export var min_distance: float = 1.0
# Maximum distance for 3D sound attenuation. Corresponds to 'Max' in sounds.tbl.
@export var max_distance: float = 100.0

# Whether the sound should be preloaded. Corresponds to 'Preload' in sounds.tbl.
@export var do_preload: bool = false

# Sound priority for instance limiting (maps roughly to original logic).
# Higher value means higher priority.
# Corresponds to SND_PRIORITY_* constants conceptually.
# Using SoundManager.SoundPriority enum values is recommended.
@export var priority: int = 1

# Sound category for volume control via audio buses.
enum Category { MASTER, MUSIC, VOICE, INTERFACE, SFX, AMBIENT }
@export var category: Category = Category.SFX # Default to SFX

# Internal signature/handle from original game (optional, for reference).
@export var original_sig: int = -1

func _init(p_id_name := "", p_path := "", p_volume := 1.0, p_min := 1.0, p_max := 100.0, p_preload := false, p_priority := 1, p_orig_sig := -1):
	id_name = p_id_name
	audio_stream_path = p_path
	default_volume = p_volume
	min_distance = p_min
	max_distance = p_max
	do_preload = p_preload
	priority = p_priority
	original_sig = p_orig_sig
	# Category needs to be set after initialization, likely during parsing/loading.

func get_stream() -> AudioStream:
	"""Lazily loads the AudioStream if not already loaded."""
	if audio_stream == null and audio_stream_path != "":
		audio_stream = load(audio_stream_path)
	return audio_stream
