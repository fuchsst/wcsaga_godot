# scripts/resources/ai_profile.gd
# Defines the static behavior parameters for an AI entity, based on skill level.
# Corresponds to ai_profile_t in ai_profiles.h and data from ai_profiles.tbl.
class_name AIProfile
extends Resource

# --- AI Profile Flags (AIPF_*) ---
# Copied from tasks/01_ai.md for reference within this script
const AIPF_SMART_SHIELD_MANAGEMENT = 1 << 0
const AIPF_BIG_SHIPS_CAN_ATTACK_BEAM_TURRETS_ON_UNTARGETED_SHIPS = 1 << 1
const AIPF_SMART_PRIMARY_WEAPON_SELECTION = 1 << 2
const AIPF_SMART_SECONDARY_WEAPON_SELECTION = 1 << 3
const AIPF_ALLOW_RAPID_SECONDARY_DUMBFIRE = 1 << 4
const AIPF_HUGE_TURRET_WEAPONS_IGNORE_BOMBS = 1 << 5
const AIPF_DONT_INSERT_RANDOM_TURRET_FIRE_DELAY = 1 << 6
# Flags 7-18 are mostly FS1/unused flags, omitted for brevity unless needed
const AIPF_SMART_AFTERBURNER_MANAGEMENT = 1 << 19
const AIPF_FIX_LINKED_PRIMARY_BUG = 1 << 20
const AIPF_PREVENT_TARGETING_BOMBS_BEYOND_RANGE = 1 << 21
const AIPF_SMART_SUBSYSTEM_TARGETING_FOR_TURRETS = 1 << 22
const AIPF_FIX_HEAT_SEEKER_STEALTH_BUG = 1 << 23
const AIPF_MULTI_ALLOW_EMPTY_PRIMARIES = 1 << 24 # Multiplayer: Allow ships with no primary weapons
const AIPF_MULTI_ALLOW_EMPTY_SECONDARIES = 1 << 25 # Multiplayer: Allow ships with no secondary weapons
const AIPF_ALLOW_TURRETS_TARGET_WEAPONS_FREELY = 1 << 26 # Turrets can target any weapon, not just bombs
const AIPF_USE_ONLY_SINGLE_FOV_FOR_TURRETS = 1 << 27 # Use a simplified FOV check for turrets
const AIPF_ALLOW_VERTICAL_DODGE = 1 << 28 # Allow AI ships to dodge vertically
const AIPF_GLOBAL_DISARM_DISABLE_EFFECTS = 1 << 29 # Disarm/Disable goals affect all AI targeting globally
const AIPF_FORCE_BEAM_TURRET_FOV = 1 << 30 # Force beam turrets to use standard FOV checks
const AIPF_FIX_AI_CLASS_BUG = 1 << 31 # Fix for a potential bug related to AI class scaling

# --- AI Profile Flags 2 (AIPF2_*) ---
const AIPF2_TURRETS_IGNORE_TARGET_RADIUS = 1 << 0 # Turrets ignore target radius in range checks
const AIPF2_CAP_VS_CAP_COLLISIONS = 1 << 1 # Enable collision detection between capital ships
# Add other AIPF2 flags if needed

# --- Exported Properties ---
@export_group("Identification")
@export var profile_name: String = "Default"

@export_group("Skill Parameters (Arrays indexed by skill level 0-4)")
@export var accuracy: Array[float] = [0.2, 0.4, 0.6, 0.8, 0.9]
@export var evasion: Array[float] = [0.2, 0.4, 0.6, 0.8, 0.9]
@export var courage: Array[float] = [0.2, 0.4, 0.6, 0.8, 0.9]
@export var patience: Array[float] = [0.2, 0.4, 0.6, 0.8, 0.9]

@export_group("Behavior Flags (Bitmask using AIPF_* constants)")
@export_flags("Smart Shields", "Big Ship Beam Turret Attack", "Smart Primary Select", "Smart Secondary Select", "Rapid Dumbfire", "Huge Turrets Ignore Bombs", "No Random Turret Delay", "Unused7", "Unused8", "Unused9", "Unused10", "Unused11", "Unused12", "Unused13", "Unused14", "Unused15", "Unused16", "Unused17", "Unused18", "Smart Afterburner", "Fix Linked Primary Bug", "Prevent Bomb Target OOR", "Smart Turret Subsys Target", "Fix Heat Seeker Stealth Bug", "Multi Allow Empty Primary", "Multi Allow Empty Secondary", "Turrets Target Weapons Freely", "Use Single Turret FOV", "Allow Vertical Dodge", "Global Disarm/Disable Effect", "Force Beam Turret FOV", "Fix AI Class Bug") var flags: int = 0
@export_group("Behavior Flags 2 (Bitmask using AIPF2_* constants)")
@export_flags("Turrets Ignore Target Radius", "Cap vs Cap Collisions") var flags2: int = 0

@export_group("Combat Parameters")
@export var max_attackers: Array[int] = [1, 2, 3, 4, 5] # Max ships attacking player
@export var predict_position_delay: Array[float] = [0.5, 0.4, 0.3, 0.2, 0.1] # Seconds
@export var turn_time_scale: Array[float] = [1.5, 1.2, 1.0, 0.9, 0.8] # Multiplier for ship turn rate

@export_group("Weapon Parameters")
@export var cmeasure_fire_chance: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9] # Chance per second under threat?
@export var in_range_time: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2] # Time needed in range before firing accurately?
@export var link_ammo_levels_maybe: Array[float] = [20.0, 30.0, 40.0, 50.0, 60.0] # % ammo above which AI *might* link
@export var link_ammo_levels_always: Array[float] = [60.0, 70.0, 80.0, 90.0, 95.0] # % ammo above which AI *always* links
@export var primary_ammo_burst_mult: Array[float] = [0.5, 0.7, 1.0, 1.2, 1.5] # Multiplier for burst fire probability?
@export var link_energy_levels_maybe: Array[float] = [30.0, 40.0, 50.0, 60.0, 70.0] # % energy above which AI *might* link
@export var link_energy_levels_always: Array[float] = [70.0, 80.0, 85.0, 90.0, 95.0] # % energy above which AI *always* links
@export var shield_manage_delay: Array[float] = [5.0, 4.0, 3.0, 2.0, 1.0] # Seconds between shield management checks
@export var ship_fire_delay_scale_friendly: Array[float] = [1.5, 1.2, 1.0, 0.9, 0.8] # Multiplier on fire delay vs friendlies
@export var ship_fire_delay_scale_hostile: Array[float] = [1.2, 1.1, 1.0, 0.9, 0.8] # Multiplier on fire delay vs hostiles
@export var ship_fire_secondary_delay_scale_friendly: Array[float] = [2.0, 1.5, 1.2, 1.0, 0.9]
@export var ship_fire_secondary_delay_scale_hostile: Array[float] = [1.5, 1.2, 1.0, 0.9, 0.8]

@export_group("Special Tactics")
@export var glide_attack_percent: Array[float] = [0.0, 5.0, 10.0, 15.0, 20.0] # % chance to use glide attack
@export var circle_strafe_percent: Array[float] = [0.0, 5.0, 10.0, 15.0, 20.0] # % chance to circle strafe
@export var glide_strafe_percent: Array[float] = [0.0, 5.0, 10.0, 15.0, 20.0] # % chance to glide strafe
@export var stalemate_time_thresh: Array[float] = [30.0, 25.0, 20.0, 15.0, 10.0] # Seconds in stalemate before trying something else
@export var stalemate_dist_thresh: Array[float] = [300.0, 250.0, 200.0, 150.0, 100.0] # Distance considered 'near' for stalemate
@export var chance_to_use_missiles_on_plr: Array[int] = [10, 20, 30, 40, 50] # % chance? Needs clarification
@export var max_aim_update_delay: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2] # Max seconds between recalculating aim prediction
@export var aburn_use_factor: Array[int] = [10, 8, 6, 4, 2] # Lower means more likely? Divisor for random check?
@export var shockwave_evade_chance: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9] # Chance per second?
@export var get_away_chance: Array[float] = [0.1, 0.2, 0.3, 0.4, 0.5] # Chance to use 'get away' tactic
@export var secondary_range_mult: Array[float] = [0.6, 0.7, 0.8, 0.9, 1.0] # Multiplier for secondary weapon range checks
@export var bump_range_mult: Array[float] = [0.6, 0.7, 0.8, 0.9, 1.0] # Multiplier for bomb range checks

@export_group("Player Specific Scaling (Applied if AI target is player)")
@export var afterburner_recharge_scale: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0] # Player only
@export var beam_friendly_damage_cap: Array[float] = [100.0, 80.0, 60.0, 40.0, 20.0] # Max damage beams can do to friendlies
@export var cmeasure_life_scale: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0] # Player only
@export var max_allowed_player_homers: Array[int] = [5, 4, 3, 2, 1] # Max missiles allowed targeting player
@export var max_incoming_asteroids: Array[int] = [10, 8, 6, 4, 2] # Max asteroids AI will track/evade
@export var player_damage_scale: Array[float] = [0.5, 0.7, 1.0, 1.2, 1.5] # Scales damage AI deals to player hull
@export var subsys_damage_scale: Array[float] = [0.5, 0.7, 1.0, 1.2, 1.5] # Scales damage AI deals to player subsystems
@export var shield_energy_scale: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0] # Player only
@export var weapon_energy_scale: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0] # Player only

@export_group("Turret Targeting")
@export var max_turret_ownage_target: Array[int] = [5, 4, 3, 2, 1] # Max turrets allowed targeting a single non-player ship
@export var max_turret_ownage_player: Array[int] = [3, 2, 2, 1, 1] # Max turrets allowed targeting the player

@export_group("Scoring")
@export var kill_percentage_scale: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0] # Scales damage % required for a kill
@export var assist_percentage_scale: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0] # Scales damage % required for an assist
@export var assist_award_percentage_scale: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0] # Scales % of kill score awarded for assist
@export var repair_penalty: Array[int] = [0, 0, 0, 0, 0] # Score penalty for player requesting repairs

@export_group("Misc")
@export var delay_bomb_arm_timer: Array[float] = [0.5, 0.5, 0.5, 0.5, 0.5] # Delay before bombs can be shot down

# --- Helper methods ---
func get_accuracy(skill_level: int) -> float:
	return accuracy[clamp(skill_level, 0, accuracy.size() - 1)]

func get_evasion(skill_level: int) -> float:
	return evasion[clamp(skill_level, 0, evasion.size() - 1)]

func get_courage(skill_level: int) -> float:
	return courage[clamp(skill_level, 0, courage.size() - 1)]

func get_patience(skill_level: int) -> float:
	return patience[clamp(skill_level, 0, patience.size() - 1)] if patience.size() > 0 else 0.5 # Default if array empty

# --- Getters for Skill-Based Parameters ---
# Ensures skill_level is clamped within the valid array bounds (0-4)

func get_max_attackers(skill: int) -> int:
	return max_attackers[clamp(skill, 0, max_attackers.size() - 1)] if max_attackers.size() > 0 else 3

func get_predict_position_delay(skill: int) -> float:
	return predict_position_delay[clamp(skill, 0, predict_position_delay.size() - 1)] if predict_position_delay.size() > 0 else 0.3

func get_turn_time_scale(skill: int) -> float:
	return turn_time_scale[clamp(skill, 0, turn_time_scale.size() - 1)] if turn_time_scale.size() > 0 else 1.0

func get_cmeasure_fire_chance(skill: int) -> float:
	return cmeasure_fire_chance[clamp(skill, 0, cmeasure_fire_chance.size() - 1)] if cmeasure_fire_chance.size() > 0 else 0.5

func get_in_range_time(skill: int) -> float:
	return in_range_time[clamp(skill, 0, in_range_time.size() - 1)] if in_range_time.size() > 0 else 0.6

func get_link_ammo_levels_maybe(skill: int) -> float:
	return link_ammo_levels_maybe[clamp(skill, 0, link_ammo_levels_maybe.size() - 1)] if link_ammo_levels_maybe.size() > 0 else 40.0

func get_link_ammo_levels_always(skill: int) -> float:
	return link_ammo_levels_always[clamp(skill, 0, link_ammo_levels_always.size() - 1)] if link_ammo_levels_always.size() > 0 else 80.0

func get_primary_ammo_burst_mult(skill: int) -> float:
	return primary_ammo_burst_mult[clamp(skill, 0, primary_ammo_burst_mult.size() - 1)] if primary_ammo_burst_mult.size() > 0 else 1.0

func get_link_energy_levels_maybe(skill: int) -> float:
	return link_energy_levels_maybe[clamp(skill, 0, link_energy_levels_maybe.size() - 1)] if link_energy_levels_maybe.size() > 0 else 50.0

func get_link_energy_levels_always(skill: int) -> float:
	return link_energy_levels_always[clamp(skill, 0, link_energy_levels_always.size() - 1)] if link_energy_levels_always.size() > 0 else 85.0

func get_shield_manage_delay(skill: int) -> float:
	return shield_manage_delay[clamp(skill, 0, shield_manage_delay.size() - 1)] if shield_manage_delay.size() > 0 else 3.0

func get_ship_fire_delay_scale_friendly(skill: int) -> float:
	return ship_fire_delay_scale_friendly[clamp(skill, 0, ship_fire_delay_scale_friendly.size() - 1)] if ship_fire_delay_scale_friendly.size() > 0 else 1.0

func get_ship_fire_delay_scale_hostile(skill: int) -> float:
	return ship_fire_delay_scale_hostile[clamp(skill, 0, ship_fire_delay_scale_hostile.size() - 1)] if ship_fire_delay_scale_hostile.size() > 0 else 1.0

func get_ship_fire_secondary_delay_scale_friendly(skill: int) -> float:
	return ship_fire_secondary_delay_scale_friendly[clamp(skill, 0, ship_fire_secondary_delay_scale_friendly.size() - 1)] if ship_fire_secondary_delay_scale_friendly.size() > 0 else 1.2

func get_ship_fire_secondary_delay_scale_hostile(skill: int) -> float:
	return ship_fire_secondary_delay_scale_hostile[clamp(skill, 0, ship_fire_secondary_delay_scale_hostile.size() - 1)] if ship_fire_secondary_delay_scale_hostile.size() > 0 else 1.0

func get_glide_attack_percent(skill: int) -> float:
	return glide_attack_percent[clamp(skill, 0, glide_attack_percent.size() - 1)] if glide_attack_percent.size() > 0 else 10.0

func get_circle_strafe_percent(skill: int) -> float:
	return circle_strafe_percent[clamp(skill, 0, circle_strafe_percent.size() - 1)] if circle_strafe_percent.size() > 0 else 10.0

func get_glide_strafe_percent(skill: int) -> float:
	return glide_strafe_percent[clamp(skill, 0, glide_strafe_percent.size() - 1)] if glide_strafe_percent.size() > 0 else 10.0

func get_stalemate_time_thresh(skill: int) -> float:
	return stalemate_time_thresh[clamp(skill, 0, stalemate_time_thresh.size() - 1)] if stalemate_time_thresh.size() > 0 else 20.0

func get_stalemate_dist_thresh(skill: int) -> float:
	return stalemate_dist_thresh[clamp(skill, 0, stalemate_dist_thresh.size() - 1)] if stalemate_dist_thresh.size() > 0 else 200.0

func get_chance_to_use_missiles_on_plr(skill: int) -> int:
	return chance_to_use_missiles_on_plr[clamp(skill, 0, chance_to_use_missiles_on_plr.size() - 1)] if chance_to_use_missiles_on_plr.size() > 0 else 30

func get_max_aim_update_delay(skill: int) -> float:
	return max_aim_update_delay[clamp(skill, 0, max_aim_update_delay.size() - 1)] if max_aim_update_delay.size() > 0 else 0.6

func get_aburn_use_factor(skill: int) -> int:
	return aburn_use_factor[clamp(skill, 0, aburn_use_factor.size() - 1)] if aburn_use_factor.size() > 0 else 6

func get_shockwave_evade_chance(skill: int) -> float:
	return shockwave_evade_chance[clamp(skill, 0, shockwave_evade_chance.size() - 1)] if shockwave_evade_chance.size() > 0 else 0.5

func get_get_away_chance(skill: int) -> float:
	return get_away_chance[clamp(skill, 0, get_away_chance.size() - 1)] if get_away_chance.size() > 0 else 0.3

func get_secondary_range_mult(skill: int) -> float:
	return secondary_range_mult[clamp(skill, 0, secondary_range_mult.size() - 1)] if secondary_range_mult.size() > 0 else 0.8

func get_bump_range_mult(skill: int) -> float:
	return bump_range_mult[clamp(skill, 0, bump_range_mult.size() - 1)] if bump_range_mult.size() > 0 else 0.8

func get_afterburner_recharge_scale(skill: int) -> float:
	return afterburner_recharge_scale[clamp(skill, 0, afterburner_recharge_scale.size() - 1)] if afterburner_recharge_scale.size() > 0 else 1.0

func get_beam_friendly_damage_cap(skill: int) -> float:
	return beam_friendly_damage_cap[clamp(skill, 0, beam_friendly_damage_cap.size() - 1)] if beam_friendly_damage_cap.size() > 0 else 60.0

func get_cmeasure_life_scale(skill: int) -> float:
	return cmeasure_life_scale[clamp(skill, 0, cmeasure_life_scale.size() - 1)] if cmeasure_life_scale.size() > 0 else 1.0

func get_max_allowed_player_homers(skill: int) -> int:
	return max_allowed_player_homers[clamp(skill, 0, max_allowed_player_homers.size() - 1)] if max_allowed_player_homers.size() > 0 else 3

func get_max_incoming_asteroids(skill: int) -> int:
	return max_incoming_asteroids[clamp(skill, 0, max_incoming_asteroids.size() - 1)] if max_incoming_asteroids.size() > 0 else 6

func get_player_damage_scale(skill: int) -> float:
	return player_damage_scale[clamp(skill, 0, player_damage_scale.size() - 1)] if player_damage_scale.size() > 0 else 1.0

func get_subsys_damage_scale(skill: int) -> float:
	return subsys_damage_scale[clamp(skill, 0, subsys_damage_scale.size() - 1)] if subsys_damage_scale.size() > 0 else 1.0

func get_shield_energy_scale(skill: int) -> float:
	return shield_energy_scale[clamp(skill, 0, shield_energy_scale.size() - 1)] if shield_energy_scale.size() > 0 else 1.0

func get_weapon_energy_scale(skill: int) -> float:
	return weapon_energy_scale[clamp(skill, 0, weapon_energy_scale.size() - 1)] if weapon_energy_scale.size() > 0 else 1.0

func get_max_turret_ownage_target(skill: int) -> int:
	return max_turret_ownage_target[clamp(skill, 0, max_turret_ownage_target.size() - 1)] if max_turret_ownage_target.size() > 0 else 3

func get_max_turret_ownage_player(skill: int) -> int:
	return max_turret_ownage_player[clamp(skill, 0, max_turret_ownage_player.size() - 1)] if max_turret_ownage_player.size() > 0 else 2

func get_kill_percentage_scale(skill: int) -> float:
	return kill_percentage_scale[clamp(skill, 0, kill_percentage_scale.size() - 1)] if kill_percentage_scale.size() > 0 else 1.0

func get_assist_percentage_scale(skill: int) -> float:
	return assist_percentage_scale[clamp(skill, 0, assist_percentage_scale.size() - 1)] if assist_percentage_scale.size() > 0 else 1.0

func get_assist_award_percentage_scale(skill: int) -> float:
	return assist_award_percentage_scale[clamp(skill, 0, assist_award_percentage_scale.size() - 1)] if assist_award_percentage_scale.size() > 0 else 1.0

func get_repair_penalty(skill: int) -> int:
	return repair_penalty[clamp(skill, 0, repair_penalty.size() - 1)] if repair_penalty.size() > 0 else 0

func get_delay_bomb_arm_timer(skill: int) -> float:
	return delay_bomb_arm_timer[clamp(skill, 0, delay_bomb_arm_timer.size() - 1)] if delay_bomb_arm_timer.size() > 0 else 0.5

# --- Flag Checkers ---
func has_flag(flag: int) -> bool:
	return (flags & flag) != 0

func has_flag2(flag: int) -> bool:
	return (flags2 & flag) != 0
