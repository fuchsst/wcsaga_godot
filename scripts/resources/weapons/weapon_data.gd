class_name WeaponData
extends WCSBaseResource

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
	LASER_GUIDED = 3
}

# -------------------------------------------------------------------------
# 1. Identification & UI
# -------------------------------------------------------------------------
@export_group("Identification")
@export var weapon_class: String = ""
@export var display_name: String = "Generic Weapon"
@export var weapon_type: WeaponType = WeaponType.ENERGY
@export var tech_title: String = ""
@export var tech_anim: String = ""
@export var tech_description: String = ""
@export var icon_file: String = ""
@export var anim_file: String = "" # Loadout animation

# -------------------------------------------------------------------------
# 2. Physics & Ballistics
# -------------------------------------------------------------------------
@export_group("Physics")
@export var projectile_mass_kg: float = 0.1
@export var muzzle_velocity_mps: float = 100.0
@export var weapon_range_meters: float = 1000.0
@export var fire_rate_hz: float = 1.0 # Derived from 1 / $Fire Wait
@export var lifetime: float = 1.0

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

# -------------------------------------------------------------------------
# 6. Visuals - Laser
# -------------------------------------------------------------------------
@export_group("Visuals - Laser")
@export var laser_bitmap: String = ""
@export var laser_glow: String = ""
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
@export var flags: Array[String] = []

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
	
	if weapon_class.is_empty():
		_add_validation_error("Weapon class is empty")
		valid = false
		
	return valid
