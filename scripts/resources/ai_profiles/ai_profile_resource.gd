class_name AIProfileResource
extends Resource

## AI Profile Resource
##
## Defines AI behavior profiles for different difficulty levels.
## Maps to ai_profiles.tbl, ai.tbl
## Each profile defines AI behavior flags that control how AI ships behave in combat.

@export_group("AI Profile")
@export var difficulty_level: String = ""  ## Difficulty level: Very Easy, Easy, Medium, Hard, Insane
@export var profile_name: String = ""  ## Name of the profile (usually matches difficulty_level)

## Legacy float attributes (may not be in all TBL versions)
@export var accuracy: float = 1.0
@export var evasion: float = 1.0
@export var courage: float = 1.0

@export_group("AI Behavior Flags")
## Ship behavior
@export var player_use_ai: bool = false
@export var disable_linked_fire_penalty: bool = false
@export var disable_weapon_damage_scaling: bool = false
@export var use_additive_weapon_velocity: bool = false
@export var use_newtonian_dampening: bool = false
@export var hack_improve_non_homing_swarm_turret_fire_accuracy: bool = false
@export var shockwaves_damage_small_ship_subsystems: bool = false
@export var ignore_lower_bound_for_minimum_speed_of_docked_ship: bool = false

## Navigation
@export var navigation_subsystem_governs_warpout_capability: bool = false
@export var allow_vertical_dodge: bool = false

## Turrets and Weapons
@export var smart_primary_weapon_selection: bool = false
@export var smart_secondary_weapon_selection: bool = false
@export var smart_shield_management: bool = false
@export var smart_afterburner_management: bool = false
@export var allow_rapid_secondary_dumbfire: bool = false
@export var huge_turret_weapons_ignore_bombs: bool = false
@export var dont_insert_random_turret_fire_delay: bool = false
@export var big_ships_can_attack_beam_turrets_on_untargeted_ships: bool = false
@export var smart_subsystem_targeting_for_turrets: bool = false
@export var prevent_turrets_targeting_too_distant_bombs: bool = false
@export var allow_turrets_target_weapons_freely: bool = false
@export var use_only_single_fov_for_turrets: bool = false

## Scoring and multiplayer
@export var include_beams_for_kills_and_assists: bool = false
@export var score_kills_based_on_damage_caused: bool = false
@export var score_assists_based_on_damage_caused: bool = false
@export var allow_event_and_goal_scoring_in_multiplayer: bool = false
@export var multi_allow_empty_primaries: bool = false
@export var multi_allow_empty_secondaries: bool = false

## Bug fixes
@export var fix_linked_primary_weapon_decision_bug: bool = false
@export var fix_heat_seekers_homing_on_stealth_ships_bug: bool = false
@export var fix_ai_class_bug: bool = false

## Advanced behavior
@export var disarm_or_disable_cause_global_ai_goal_effects: bool = false
@export var do_capship_vs_capship_collisions: bool = false

@export_group("Numeric AI Parameters")
## Player scaling factors
@export var player_afterburner_recharge_scale: float = 1.0
@export var player_countermeasure_life_scale: float = 1.0
@export var player_shield_recharge_scale: float = 1.0
@export var player_weapon_recharge_scale: float = 1.0
@export var player_damage_factor: float = 1.0
@export var player_subsys_damage_factor: float = 1.0

## AI combat parameters
@export var max_beam_friendly_fire_damage: float = 0.0
@export var ai_countermeasure_firing_chance: float = 0.5
@export var ai_in_range_time: float = 0.0
@export var ai_shield_manage_delay: float = 2.0
@export var ai_turn_time_scale: float = 1.0
@export var predict_position_delay: float = 1.0
@export var max_aim_update_delay: float = 0.0

## AI weapon linking behavior
@export var ai_always_links_ammo_weapons: float = 60.0
@export var ai_maybe_links_ammo_weapons: float = 40.0
@export var ai_always_links_energy_weapons: float = 25.0
@export var ai_maybe_links_energy_weapons: float = 10.0
@export var primary_ammo_burst_multiplier: int = 0

## Fire delay scaling
@export var friendly_ai_fire_delay_scale: float = 1.0
@export var hostile_ai_fire_delay_scale: float = 1.0
@export var friendly_ai_secondary_fire_delay_scale: float = 30.0
@export var hostile_ai_secondary_fire_delay_scale: float = 1.0

## Combat limits and thresholds
@export var max_missles_locked_on_player: int = 4
@export var max_player_attackers: int = 999
@export var max_incoming_asteroids: int = 5
@export var max_turret_target_ownage: int = 999
@export var max_turret_player_ownage: int = 999
@export var chance_ai_has_to_fire_missiles_at_player: int = 0

## Combat behavior percentages
@export var glide_attack_percent: float = 10.0
@export var circle_strafe_percent: float = 0.0
@export var glide_strafe_percent: float = 10.0

## Stalemate detection
@export var stalemate_time_threshold: float = 15.0
@export var stalemate_distance_threshold: float = 500.0

## Scoring thresholds
@export var percentage_required_for_kill_scale: float = 0.5
@export var percentage_required_for_assist_scale: float = 0.25
@export var percentage_awarded_for_capship_assist: float = 0.5

## Miscellaneous
@export var repair_penalty: int = 35
@export var delay_before_allowing_bombs_to_be_shot_down: float = 1.5


func get_resource_type() -> String:
	return "ai_profile"
