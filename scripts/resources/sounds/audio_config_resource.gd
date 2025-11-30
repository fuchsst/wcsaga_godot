class_name AudioConfigResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Audio Configuration Resource
##
## Defines sound effects.
## Maps to sounds.tbl entries.

@export var signature: int = -1
@export var filename: String = ""
@export var audio_stream: AudioStream
@export var preload_sound: bool = false
@export var default_volume: float = 1.0
@export var is_3d: int = 0  # 0=None, 1=Stereo, 2=Aureal
@export var min_distance: float = 0.0
@export var max_distance: float = 0.0


func get_resource_type() -> String:
	return "audio_config"
