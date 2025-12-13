class_name AIClassResource
extends Resource

## AI Class Resource
##
## Defines AI behavior class for different AI ship types.
## Maps to ai.tbl entries from legacy WCS.
## Each AI class has parameters for all 5 difficulty levels.
## Parameters are merged with AIProfileResource at runtime.

@export_group("AI Class")
@export var ai_class_name: String = "" ## Name (e.g., "Coward", "Ace", "Wingman")
@export var difficulty_level: String = "" ## Difficulty this instance represents

@export_group("Core AI Parameters")
## Core behavior values (0.0 - 1.0 range)
@export var accuracy: float = 0.5 ## How accurately this ship fires
@export var evasion: float = 0.5 ## How effective at evading (0.0 - 1.0)
@export var courage: float = 0.5 ## How likely to accept danger
@export var patience: float = 0.5 ## How willing to wait for advantage

@export_group("Aim & Prediction")
## Aiming behavior
@export var ai_in_range_time: float = 2.0 ## Seconds to add to in-range time
@export var ai_predict_position_delay: float = 1.0 ## Delay before predicting
@export var ai_max_aim_update_delay: float = 0.5 ## Max delay updating aim

@export_group("Combat Timing")
## Fire delay scaling
@export var ai_shield_manage_delay: float = 2.0 ## Delay managing shields
@export var friendly_ai_fire_delay_scale: float = 1.0 ## Primary fire delay
@export var hostile_ai_fire_delay_scale: float = 1.0
@export var friendly_ai_secondary_fire_delay_scale: float = 30.0
@export var hostile_ai_secondary_fire_delay_scale: float = 1.0
@export var ai_countermeasure_firing_chance: float = 0.5 ## CM fire chance

@export_group("Advanced Combat Tactics")
## Movement tactics (percentages 0.0 - 1.0)
@export var ai_turn_time_scale: float = 1.0 ## Turn rate multiplier
@export var ai_glide_attack_percent: float = 0.0 ## Chance to glide attack
@export var ai_circle_strafe_percent: float = 0.0 ## Chance to circle strafe
@export var ai_glide_strafe_percent: float = 0.0 ## Chance to glide strafe

## Stalemate detection
@export var ai_stalemate_time_thresh: float = 15.0 ## Seconds before stalemate
@export var ai_stalemate_dist_thresh: float = 500.0 ## Distance threshold

@export_group("Afterburner & Evasion")
## Afterburner usage (0-100 factor, 100 = always use when appropriate)
@export var ai_aburn_use_factor: int = 100
@export var ai_shockwave_evade_chance: float = 0.5 ## Chance to evade shockwave
@export var ai_get_away_chance: float = 0.3 ## Chance to disengage

@export_group("Weapon Selection")
## Weapon linking thresholds (percent of ammo/energy)
@export var ai_link_ammo_levels_maybe: float = 0.4 ## Link if hull low
@export var ai_link_ammo_levels_always: float = 0.6 ## Always link above
@export var ai_link_energy_levels_maybe: float = 0.25 ## Energy threshold
@export var ai_link_energy_levels_always: float = 0.1 ## Min for linking
@export var ai_primary_ammo_burst_mult: float = 1.0 ## Burst frequency mult
@export var ai_secondary_range_mult: float = 1.0 ## Secondary range mult
@export var ai_chance_to_use_missiles_on_plr: int = 3 ## Chance (x/7)

@export_group("Engagement Range")
## Engagement distances
@export var ai_bump_range_mult: float = 1.0 ## Collision avoidance range

@export_group("Behavior Flags")
## Scaling behavior
@export var autoscale_by_ai_class_index: bool = true ## Auto-scale by index


func get_resource_type() -> String:
	return "ai_class"


## Get effective value for a parameter, applying profile overrides
func get_effective_value(param_name: String, profile: Resource) -> Variant:
	# If profile has explicit override, use it; otherwise use class value
	if profile and param_name in profile:
		return profile.get(param_name)
	return get(param_name)
