# Enhanced WeaponData Resource with advanced damage profiles and cross-references
# This resource represents comprehensive weapon definition from weapons.tbl
class_name WeaponData
extends WCSDataResource

# Identity and classification
@export var weapon_class: String = ""  # Military designation (@Ion)
@export var weapon_family: String = "" # Cross-reference to weapon families
@export var display_name: String = ""
@export var manufacturer_species: String = "" # Cross-reference to SpeciesData
@export var tech_level: int = 0  # Technology era (0=WC1, 1=WC2, etc.)

# Physical properties (ballistics and targeting)
@export var mass_kg: float = 0.2  # Projectile mass
@export var velocity_mps: float = 810.0  # Meters per second
@export var fire_rate_hz: float = 2.86  # Shots per second (1/0.35)
@export var range_meters: float = 907.2  # velocity * lifetime
@export var lifetime_seconds: float = 1.12

# Damage modeling (energy-based physics)
@export var base_damage_energy: float = 30.0  # Base energy damage
@export var damage_profile: String # Cross-reference to damage profile resource
@export var armor_penetration_factor: float = 1.0
@export var shield_penetration_factor: float = 1.0
@export var hull_penetration_factor: float = 1.0

# Surface damage multipliers (based on impact angle)
@export var fore_damage_mult: float = 1.0
@export var aft_damage_mult: float = 1.0
@export var left_damage_mult: float = 1.0
@export var right_damage_mult: float = 1.0
@export var top_damage_mult: float = 1.0
@export var bottom_damage_mult: float = 1.0

# Energy consumption and heat
@export var energy_per_shot: float = 3.5  # Ship energy consumed
@export var heat_generation: float = 5.0  # Heat units per shot
@export var overheat_threshold: float = 100.0
@export var cooling_rate: float = 10.0

# Targeting systems
@export var homing_type: int = 0  # 0=None, 1=Aspect, 2=Heat, 3=Image
@export var guidance_package: String = "" # Cross-reference guidance system
@export var lock_time_seconds: float = 0.0
@export var lock_range_meters: float = 1500.0
@export var lock_fov_degrees: float = 5.0  # Field of view for locking
@export var max_turn_rate_dps: float = 0.0  # Degrees per second
@export var decoy_resistance: float = 0.8  # 0.0=easily decoyed, 1.0=immune

# Visual effects and particles
@export var muzzle_flash_effect: String = "" # Cross-reference to effect resource
@export var projectile_effect: String = "" # Cross-reference to effect resource
@export var impact_effect: String = "" # Cross-reference to effect resource
@export var explosion_effect: String = "" # Cross-reference to effect resource
@export var laser_length_meters: float = 0.0
@export var laser_color_primary: Color = Color(255, 255, 255)
@export var laser_color_secondary: Color = Color(150, 150, 150)

# Audio systems
@export var launch_sound: String = "" # Cross-reference to audio resource
@export var impact_sound: String = "" # Cross-reference to audio resource
@export var flyby_sound: String = "" # Cross-reference to audio resource
@export var lock_sound: String = "" # Cross-reference to audio resource

# Special characteristics
@export var shot_count: int = 1  # Number of projectiles fired (swarm)
@export var spread_pattern: Vector2 = Vector2.ZERO  # Shot spread angles
@export var burst_fire_count: int = 1
@export var burst_delay_seconds: float = 0.0
@export var cargo_size_units: int = 1

# Countermeasure effectiveness
@export var countermeasure_vulnerability: float = 0.0  # 0.0=unaffected, 1.0=always decoyed
@export var chaff_modifier: float = 1.0
@export var flare_modifier: float = 1.0

# Gameplay restrictions and flags
@export var is_player_allowed: bool = true
@export var appears_in_tech_database: bool = false
@export var is_stealth_weapon: bool = false
@export var is_bomb_type: bool = false
@export var is_huge_weapon: bool = false  # Requires capital ship mounts
@export var no_shield_piercing: bool = false

func validate() -> bool:
	"""Comprehensive weapon data validation"""
	validation_errors.clear()
	conversion_notes.clear()

	# Call parent validation
	if not super.validate():
		return false

	# Validate physics properties
	if mass_kg < 0:
		_add_validation_error("Mass cannot be negative")

	if velocity_mps < 0:
		_add_validation_error("Velocity cannot be negative")

	if fire_rate_hz <= 0:
		_add_validation_error("Fire rate must be positive")

	# Validate damage values
	if base_damage_energy < 0:
		_add_validation_error("Base damage cannot be negative")

	# Validate cross-references for visual effects
	validate_effect_references()
	validate_audio_references()
	validate_targeting_validity()

	is_valid = validation_errors.size() == 0
	validation_changed.emit()
	return is_valid

func validate_effect_references() -> void:
	"""Validate visual effect references"""
	var effect_refs = {
		"muzzle_flash_effect": muzzle_flash_effect,
		"projectile_effect": projectile_effect,
		"impact_effect": impact_effect,
		"explosion_effect": explosion_effect
	}

	for ref_name in effect_refs.keys():
		var path = effect_refs[ref_name]
		if not path.is_empty():
			validate_cross_reference(ref_name, path, "Effect %s not found" % ref_name)

func validate_audio_references() -> void:
	"""Validate audio resource references"""
	var audio_refs = {
		"launch_sound": launch_sound,
		"impact_sound": impact_sound,
		"flyby_sound": flyby_sound,
		"lock_sound": lock_sound
	}

	for ref_name in audio_refs.keys():
		var path = audio_refs[ref_name]
		if not path.is_empty():
			validate_cross_reference(ref_name, path, "Audio %s not found" % ref_name)

func validate_targeting_validity() -> void:
	"""Validate targeting system parameters"""
	if homing_type != 0:  # Any homing weapon
		if lock_time_seconds <= 0:
			_add_validation_warning("Homing weapon has zero lock time")

		if max_turn_rate_dps <= 0:
			_add_validation_warning("Homing weapon has zero turn rate")

func calculate_damage_against_target(target_species: String, target_armor_type: String,
                                   impact_point: Vector3, impact_angle: float) -> Dictionary:
	"""
	Calculate actual damage against target based on physics
	Returns: {total_damage: float, armor_damage: float, shield_damage: float, hull_damage: float}
	"""
	var damage = {
		"total_damage": base_damage_energy,
		"armor_damage": base_damage_energy * armor_penetration_factor,
		"shield_damage": base_damage_energy * shield_penetration_factor,
		"hull_damage": base_damage_energy * hull_penetration_factor
	}

	# Apply surface-specific multipliers
	var surface_mult = 1.0
	if impact_angle > 45:  # Aft impact
		surface_mult = aft_damage_mult
	elif impact_angle < 45 and impact_angle > -45:  # Side impact
		surface_mult = (left_damage_mult + right_damage_mult) / 2.0
	else:  # Fore impact
		surface_mult = fore_damage_mult

	# Apply angle-based damage reduction
	for damage_type in damage.keys():
		damage[damage_type] *= surface_mult * abs(cos(impact_angle))

	return damage