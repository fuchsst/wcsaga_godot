class_name WeaponData
extends "res://scripts/resources/core/wcs_base_resource.gd"

# Enums
enum WeaponType {
	ENERGY = 0,
	BALLISTIC = 1,
	MISSILE = 2,
	BEAM = 3
}

enum HomingType {
	NONE = 0,
	HEAT_SEEKING = 1,
	ASPECT_SEEKING = 2,
	LASER_GUIDED = 3,
	# Aliases for Parser
	HEAT = 1,
	ASPECT = 2
}

# Inner Classes for Weapon Configurations
class SwarmConfiguration extends Resource:
	@export var count: int = 0
	@export var wait_time: float = 0.0

class BeamConfiguration extends Resource:
	@export var beam_type: int = 0
	@export var beam_life: float = 0.0
	@export var beam_warmup: float = 0.0
	@export var beam_warmdown: float = 0.0
	@export var beam_width: float = 1.0
	@export var range_multiplier: float = 1.0

class TrailConfiguration extends Resource:
	@export var bitmap: String = ""
	@export var start_width: float = 0.0
	@export var end_width: float = 0.0
	@export var start_alpha: float = 0.0
	@export var end_alpha: float = 0.0
	@export var max_life: float = 0.0

class CorkscrewConfiguration extends Resource:
	@export var num_missiles: int = 0
	@export var radius: float = 0.0
	@export var twist_rate: float = 0.0
	@export var shrink_rate: float = 0.0
	@export var fire_delay: float = 0.0
	@export var counter_rotate: bool = false
	@export var helix: bool = false

class SpawnConfiguration extends Resource:
	@export var spawn_angle: float = 180.0

class ParticleSpew extends Resource:
	@export var count: int = 0
	@export var time: int = 0
	@export var velocity: float = 0.0
	@export var radius: float = 0.0
	@export var lifetime: float = 0.0
	@export var scale: float = 0.0
	@export var bitmap: String = ""

# Weapon Flags
enum WeaponFlags {
	PLAYER_ALLOWED = 1 << 0,
	BEAM = 1 << 1,
	BOMB = 1 << 2,
	HUGE = 1 << 3,
	PARTICLE_SPEW = 1 << 4,
	BALLISTIC = 1 << 5,
	SWARM = 1 << 6,
	CORKSCREW = 1 << 7,
	FLAK = 1 << 8,
	ELECTRONICS = 1 << 9,
	SPAWN_CHILD = 1 << 10,
	REMOTE_DETONATE = 1 << 11,
	PUNCTURE = 1 << 12,
	SHIELD_PIERCE = 1 << 13,
	BOMBER_PLUS = 1 << 14,
	ENERGY_SUCK = 1 << 16,
	EMP = 1 << 17,
	TAGGED = 1 << 15, # Re-verify value? Defined as TAGGED above? No, WIF_TAG is 1<<27. WIF_TAGGED is legacy?
	# Aligning with local consts if needed, or just adding new ones logic.
	# C++ WIF_TAG = 1 << 27
	TAG = 1 << 18,
	SHUDDER = 1 << 19,
	MUZZLE_FLASH = 1 << 20,
	LOCK_ARM = 1 << 21,
	STREAM = 1 << 22
}

# -------------------------------------------------------------------------
# 1. Identification & UI
# -------------------------------------------------------------------------
@export_group("Identification")
@export var id: String = ""
@export var display_name: String = "Generic Weapon"
@export var category: String = "weapon"
@export var manufacturer_species: String = "Terran"
@export var weapon_type: WeaponType = WeaponType.ENERGY
@export var tech_title: String = ""
@export var tech_animation: String = ""
@export var tech_description: String = ""
@export var display_icon: String = ""
@export var anim_file: String = "" # Loadout animation, TODO, make reference to spriteframes resource tres file

# -------------------------------------------------------------------------
# 2. Physics & Ballistics
# -------------------------------------------------------------------------
@export_group("Physics")
@export var projectile_mass_kg: float = 0.1
@export var muzzle_velocity_mps: float = 100.0
@export var weapon_range_meters: float = 1000.0
@export var fire_rate_hz: float = 1.0 # Derived from 1 / $Fire Wait
@export var lifetime: float = 1.0
@export var free_flight_time: float = 0.0

# -------------------------------------------------------------------------
# 3. Damage & Impact
# -------------------------------------------------------------------------
@export_group("Damage - Direct")
@export var base_damage_energy: float = 10.0
@export var base_damage_hull: float = 0.0 # Often 0 in TBL if generic $Damage used
@export var armor_factor: float = 1.0
@export var shield_factor: float = 1.0
@export var subsystem_factor: float = 1.0

@export_group("Damage - Area/Blast")
@export var blast_force: float = 0.0
@export var inner_radius: float = 0.0
@export var outer_radius: float = 0.0
@export var shockwave_speed: float = 0.0
@export var shockwave_damage: float = 0.0

# -------------------------------------------------------------------------
# 4. Energy & Ammo
# -------------------------------------------------------------------------
@export_group("Energy & Ammo")
@export var energy_per_shot: float = 1.0
@export var cargo_size: float = 0.0
@export var rearm_rate: float = 0.0

# -------------------------------------------------------------------------
# 5. Guidance & Homing
# -------------------------------------------------------------------------
@export_group("Homing")
@export var homing_type: HomingType = HomingType.NONE
@export var swarm_count: int = 0
@export var turn_time: float = 0.0
@export var min_lock_time: float = 0.0
@export var lock_pixels_per_sec: float = 0.0
@export var catch_up_pixels_per_sec: float = 0.0
@export var catch_up_penalty: float = 0.0
@export var fof_field_of_view: float = 0.0 # $FOF
@export var view_cone_degrees: float = 0.0 # $View Cone

@export_group("Arming & Safety")
@export var arm_time: float = 0.0
@export var arm_dist: float = 0.0
@export var arm_radius: float = 0.0 # Safety radius

@export_group("Special Effects")
@export var tag_time: float = 0.0
@export var tag_level: int = 0
@export var shudder_amount: float = 0.0
@export var muzzle_flash_id: int = -1 # TODO: make MuzzleFlashResource

# -------------------------------------------------------------------------
# 6. Visuals - Laser
# -------------------------------------------------------------------------
@export_group("Visuals - Laser")
var _laser_bitmap_source: String = ""
var _laser_glow_source: String = ""
@export var laser_bitmap: Texture2D
@export var laser_glow: Texture2D
@export var laser_color: Color = Color.WHITE
@export var laser_color_2: Color = Color.BLACK
@export var laser_length: float = 0.0
@export var laser_head_radius: float = 0.0
@export var laser_tail_radius: float = 0.0

# -------------------------------------------------------------------------
# 7. Visuals - Trail
# -------------------------------------------------------------------------
@export_group("Visuals - Trail")
@export var trail_bitmap: String = ""
@export var trail_start_width: float = 0.0
@export var trail_end_width: float = 0.0
@export var trail_start_alpha: float = 0.0
@export var trail_end_alpha: float = 0.0
@export var trail_max_life: float = 0.0

# -------------------------------------------------------------------------
# 8. Visuals - Impact & Model
# -------------------------------------------------------------------------
@export_group("Visuals - Impact & Misc")
@export var projectile_model: String = "" # $Model File
@export var impact_explosion: String = ""
@export var impact_explosion_radius: float = 0.0
@export var muzzle_flash_effect: String = "" # Usually implied by weapon type or separate tbl

# -------------------------------------------------------------------------
# 8.1 Advanced Configurations
# -------------------------------------------------------------------------
@export var swarm_config: Resource
@export var beam_config: Resource
@export var trail_config: Resource
@export var corkscrew_config: Resource
@export var spawn_config: Resource
@export var flak_config: Resource
@export var particle_spew: Resource

# -------------------------------------------------------------------------
# 9. Audio
# -------------------------------------------------------------------------
@export_group("Audio")
@export var launch_sound_index: int = -1
@export var impact_sound_index: int = -1
@export var flyby_sound_index: int = -1

# -------------------------------------------------------------------------
# 10. Flags
# -------------------------------------------------------------------------
@export_group("Flags")
@export var flags: int = 0 # Bitmask using WeaponFlags
@export var appears_in_tech_db: bool = false
@export var is_beam: bool = false
@export var no_shield_piercing: bool = false
@export var is_bomb_type: bool = false
@export var is_huge_weapon: bool = false

# -------------------------------------------------------------------------
# Logic & Helpers
# -------------------------------------------------------------------------

func get_damage_per_second() -> float:
	# Approximate DPS
	return base_damage_energy * fire_rate_hz

func get_energy_efficiency() -> float:
	if energy_per_shot <= 0.001:
		return 1000.0
	return base_damage_energy / energy_per_shot

func is_explosive() -> bool:
	return outer_radius > 0 or blast_force > 0

func is_homing() -> bool:
	return homing_type != HomingType.NONE

func calculate_damage_against_target(
	_target_species: String,
	_target_armor_rating: float,
	target_shield_strength: float,
	impact_point: Vector3,
	impact_angle: float,
	impact_velocity: float
) -> Dictionary:
	# Basic calculation
	var damage = base_damage_energy
	
	var shield_dam = damage * shield_factor
	var hull_dam = damage * armor_factor # Using armor factor as hull multiplier
	var sub_dam = damage * subsystem_factor
	
	return {
		"total_damage": shield_dam + hull_dam,
		"shield_damage": shield_dam,
		"hull_damage": hull_dam,
		"subsystem_damage": sub_dam
	}

# Documentation Interface
func get_class_name() -> String:
	return "WeaponData"

func validate() -> bool:
	var valid = super.validate()
	
	if id.is_empty():
		_add_validation_error("Weapon class is empty")
		valid = false
		
	return valid
