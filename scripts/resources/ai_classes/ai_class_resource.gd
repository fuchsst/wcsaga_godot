class_name AIClassResource
extends Resource

## AI Class Resource
##
## Defines AI behavior class for different AI ship types.
## Maps to ai.tbl
## Each AI class has parameters for all 5 difficulty levels (Trainee, Rookie, Hotshot, Ace, Insane).

@export_group("AI Class")
@export var ai_class_name: String = "" ## Name of the AI class (e.g., "Coward", "Ace", "Wingman")
@export var difficulty_level: String = "" ## Which difficulty level this instance represents

@export_group("Core AI Parameters")
## Core behavior values (0.0 - 1.0 or 0.0 - 100.0)
@export var accuracy: float = 0.5 ## How accurately this ship fires (0.0 - 1.0)
@export var evasion: float = 50.0 ## How effective at evading (0.0 - 100.0)
@export var courage: float = 50.0 ## How likely to chance danger (0.0 - 100.0)
@export var patience: float = 50.0 ## How willing to wait for advantage (0.0 - 100.0)

@export_group("AI Combat Parameters")
## Scaling and behavior flags
@export var autoscale_by_ai_class_index: bool = false ## Whether to autoscale by AI class index

## Combat timing parameters
@export var ai_countermeasure_firing_chance: float = 0.5
@export var ai_shield_manage_delay: float = 2.0
@export var friendly_ai_fire_delay_scale: float = 1.0
@export var hostile_ai_fire_delay_scale: float = 1.0
@export var friendly_ai_secondary_fire_delay_scale: float = 30.0
@export var hostile_ai_secondary_fire_delay_scale: float = 1.0

func get_resource_type() -> String:
	return "ai_class"
