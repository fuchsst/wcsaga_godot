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
@export var ambience: AudioStream
@export var arrival_allied_normal: AudioStream
@export var arrival_enemy_normal: AudioStream
@export var battle_1: AudioStream
@export var battle_2: AudioStream
@export var battle_3: AudioStream
@export var arrival_allied_battle: AudioStream
@export var arrival_enemy_battle: AudioStream
@export var victory_1: AudioStream
@export var victory_2: AudioStream
@export var goal_failed: AudioStream
@export var player_dead: AudioStream

func get_resource_type() -> String:
	return "soundtrack"
