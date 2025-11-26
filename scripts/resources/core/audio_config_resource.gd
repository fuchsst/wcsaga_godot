class_name AudioConfigResource
extends WCSBaseResource

## Audio Configuration Resource
##
## Defines sound effects and music tracks.
## Maps to sounds.tbl, music.tbl

@export_group("Audio Entry")
@export var entry_name: String = ""
@export var filename: String = ""
@export var volume: float = 1.0
@export var preload: bool = false

func get_resource_type() -> String:
	return "audio_config"
