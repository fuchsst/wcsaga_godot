class_name AudioConfigResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Audio Configuration Resource
##
## Defines sound effects.
## Maps to sounds.tbl entries.

enum SoundCategory {GAMEPLAY, INTERFACE, WEAPON, ENGINE, DEBRIS, MUSIC, VOICE}

## Symbolic name for lookup (e.g. "SND_MISSILE_TRACKING")
@export var symbolic_name: StringName = &""
@export var category: SoundCategory = SoundCategory.GAMEPLAY

@export var signature: int = -1
@export var filename: String = ""
@export var audio_path: String = "" # res:// path to converted .ogg file for lazy loading
@export var audio_stream: AudioStream
@export var preload_sound: bool = false
@export var default_volume: float = 1.0
@export var is_3d: int = 0 # 0=None, 1=3D
@export var min_distance: float = 0.0
@export var max_distance: float = 0.0


## Lazy-load the audio stream when needed (works outside of headless mode)
func get_audio_stream() -> AudioStream:
	if audio_stream:
		return audio_stream
	if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		audio_stream = load(audio_path)
	return audio_stream


func get_resource_type() -> String:
	return "audio_config"
