class_name MenuMusicResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Menu Music Configuration
##
## Defines music tracks for various menu screens and states.
## Maps to #Menu Music Start section in music.tbl

@export var command_brief: AudioStream
@export var command_brief_filename: String = ""

@export var briefing_1: AudioStream
@export var briefing_1_filename: String = ""

@export var briefing_2: AudioStream
@export var briefing_2_filename: String = ""

@export var briefing_3: AudioStream
@export var briefing_3_filename: String = ""

@export var briefing_4: AudioStream
@export var briefing_4_filename: String = ""

@export var debriefing_success: AudioStream
@export var debriefing_success_filename: String = ""

@export var debriefing_average: AudioStream
@export var debriefing_average_filename: String = ""

@export var debriefing_failure: AudioStream
@export var debriefing_failure_filename: String = ""

@export var fiction_viewer: AudioStream
@export var fiction_viewer_filename: String = ""

@export var prologue_menu: AudioStream
@export var prologue_menu_filename: String = ""

@export var credits: AudioStream
@export var credits_filename: String = ""


func get_resource_type() -> String:
	return "menu_music"
