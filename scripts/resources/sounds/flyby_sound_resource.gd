class_name FlybySoundResource
extends "res://scripts/resources/sounds/audio_config_resource.gd"

## Flyby Sound Resource
##
## Defines flyby sounds for specific factions.
## Maps to #Flyby Sounds Start section in sounds.tbl

@export var faction: String = ""
@export var index: int = 0

func get_resource_type() -> String:
	return "flyby_sound"
