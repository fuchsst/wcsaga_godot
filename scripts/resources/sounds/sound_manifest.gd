class_name SoundManifest
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Sound Manifest
##
## Contains all sound configurations from sounds.tbl.

@export var audio_configs: Array[Resource] = [] # Array[AudioConfigResource]
@export var flyby_sounds: Array[Resource] = [] # Array[FlybySoundResource]

func get_resource_type() -> String:
	return "sound_manifest"
