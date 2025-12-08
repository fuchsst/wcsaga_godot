class_name SoundManifest
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Sound Manifest
##
## Contains all sound configurations from sounds.tbl.

const AudioConfigResource = preload("res://scripts/resources/sounds/audio_config_resource.gd")
const FlybySoundResource = preload("res://scripts/resources/sounds/flyby_sound_resource.gd")

@export var audio_configs: Array[AudioConfigResource] = []
@export var flyby_sounds: Array[FlybySoundResource] = []


func get_resource_type() -> String:
	return "sound_manifest"
