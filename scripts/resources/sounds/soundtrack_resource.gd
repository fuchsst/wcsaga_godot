class_name SoundtrackResource
extends "res://scripts/resources/core/wcs_base_resource.gd"

## Soundtrack Resource
##
## Defines a complete soundtrack configuration including multiple tracks for different game states.
## Maps to sections in music.tbl

@export var name: String = ""
@export var allied_arrival_overlay: bool = false
@export var lock_in_ambient: bool = false


# Explicit tracks based on fixed order in music.tbl
# Explicit tracks based on fixed order in music.tbl
@export var ambience: AudioStream
@export var ambience_filename: String = ""

@export var arrival_allied_normal: AudioStream
@export var arrival_allied_normal_filename: String = ""

@export var arrival_enemy_normal: AudioStream
@export var arrival_enemy_normal_filename: String = ""

@export var battle_1: AudioStream
@export var battle_1_filename: String = ""

@export var battle_2: AudioStream
@export var battle_2_filename: String = ""

@export var battle_3: AudioStream
@export var battle_3_filename: String = ""

@export var arrival_allied_battle: AudioStream
@export var arrival_allied_battle_filename: String = ""

@export var arrival_enemy_battle: AudioStream
@export var arrival_enemy_battle_filename: String = ""

@export var victory_1: AudioStream
@export var victory_1_filename: String = ""

@export var victory_2: AudioStream
@export var victory_2_filename: String = ""

@export var goal_failed: AudioStream
@export var goal_failed_filename: String = ""

@export var player_dead: AudioStream
@export var player_dead_filename: String = ""

func get_resource_type() -> String:
	return "soundtrack"
