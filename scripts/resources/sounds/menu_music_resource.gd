class_name MenuMusicResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Menu Music Configuration
##
## Defines music tracks for various menu screens and states.
## Maps to #Menu Music Start section in music.tbl

@export var command_brief: AudioStream
@export var briefing_1: AudioStream
@export var briefing_2: AudioStream
@export var briefing_3: AudioStream
@export var briefing_4: AudioStream
@export var debriefing_success: AudioStream
@export var debriefing_average: AudioStream
@export var debriefing_failure: AudioStream
@export var fiction_viewer: AudioStream
@export var prologue_menu: AudioStream
@export var credits: AudioStream

func get_resource_type() -> String:
	return "menu_music"
