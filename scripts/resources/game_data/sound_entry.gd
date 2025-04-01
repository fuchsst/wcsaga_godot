@tool
extends Resource
class_name SoundEntry

# Sound categories matching game settings
enum Category {
	MASTER,      # Affected by master_volume
	MUSIC,       # Affected by music_volume
	VOICE,       # Affected by voice_volume
	INTERFACE,   # Affected by master_volume
	WEAPON,      # Affected by master_volume
	SHIP,        # Affected by master_volume
	AMBIENT      # Affected by master_volume
}

# Sound types for 3D positioning
enum SoundType {
	NORMAL = 0,     # Regular non-positional sound
	POSITIONAL = 1, # 3D positioned sound with standard attenuation
	AMBIENT = 2,    # Background/ambient sound
	A3D = 3        # 3D positional sound with enhanced attenuation (legacy A3D)
}

# Core properties
@export var audio_stream: AudioStream  # The actual sound data
@export var category: Category  # Sound category for organization and volume control
@export var type: SoundType = SoundType.NORMAL  # How the sound should be played
@export var default_volume: float = 1.0  # Base volume level
@export var should_preload: bool = false  # Whether to preload this sound

# 3D sound properties
@export_group("3D Sound Properties")
@export var min_distance: float = 1.0  # Distance where sound starts attenuating
@export var max_distance: float = 20.0  # Distance where sound becomes inaudible
@export var attenuation: float = 1.0  # How quickly sound fades with distance

# Unique identifier (similar to original game's sig)
@export var id: String = ""

# Runtime properties
var loaded_audio_player: AudioStreamPlayer3D  # Cached player for preloaded sounds

func _init():
	# Generate unique ID if not set
	if id.is_empty():
		id = str(hash(Time.get_unix_time_from_system()))

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
func preload_sound() -> void:
	if should_preload and audio_stream and not loaded_audio_player:
		loaded_audio_player = AudioStreamPlayer3D.new()
		loaded_audio_player.stream = audio_stream
		loaded_audio_player.max_distance = max_distance
		loaded_audio_player.unit_size = min_distance
		loaded_audio_player.attenuation = attenuation

func unload_sound() -> void:
	if loaded_audio_player:
		loaded_audio_player.queue_free()
		loaded_audio_player = null
