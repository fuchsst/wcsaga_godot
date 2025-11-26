# WeaponData - Comprehensive Weapon Configuration Resource
# Represents complete weapon definition from weapons.tbl with physics-based damage modeling
# and cross-reference resolution for Wing Commander Saga weapons

class_name WeaponData
extends WCSBaseResource

# === IDENTITY AND CLASSIFICATION ===
@export_group("Identity", "identity_")
@export var weapon_class: String = ""                    # Military designation (@Ion)
@export var display_name: String = ""                    # Display name (Ion Cannon)
@export var weapon_family: String = ""                   # Weapon family classification
@export var manufacturer_species: String = ""             # Cross-reference to SpeciesData
@export var tech_level: int = 0                           # Technology era (0=WC1, 1=WC2, etc.)
@export var weapon_type: int = 0                          # 0=Energy, 1=Ballistic, 2=Missile, 3=Special
@export var is_player_allowed: bool = true               # Available to players
@export var appears_in_tech_db: bool = false             # Shows in tech database
@export var is_stealth_weapon: bool = false              # Undetectable when fired

# === PHYSICAL PROPERTIES ===
@export_group("Physics", "physics_")
@export var projectile_mass_kg: float = 0.2              # Projectile mass in kilograms
@export var muzzle_velocity_mps: float = 810.0           # Muzzle velocity in meters/second
@export var effective_range_meters: float = 907.2        # Maximum effective range
@export var projectile_lifetime: float = 1.12            # Projectile lifetime in seconds
@export var fire_rate_hz: float = 2.86                   # Fire rate in shots per second
@export var projectile_drag_coefficient: float = 0.0     # Air resistance (for atmospheric)
@export var projectile_gravity_factor: float = 0.0       # Gravity influence

# === DAMAGE MODELING ===
@export_group("Damage", "damage_")
@export var base_damage_energy: float = 30.0             # Base energy damage
@export var damage_profile: String = ""                  # Cross-reference to damage profile
@export var armor_penetration_factor: float = 1.0        # Armor penetration multiplier
@export var shield_penetration_factor: float = 1.2        # Shield penetration multiplier
@export var hull_penetration_factor: float = 1.0         # Hull penetration multiplier
@export var subsystem_damage_factor: float = 0.7          # Subsystem damage multiplier
@export var blast_radius: float = 0.0                    # Blast radius for explosive weapons
@export var explosion_damage: float = 0.0                # Explosion damage at center
@export var shockwave_speed: float = 0.0                 # Shockwave propagation speed

# === SURFACE DAMAGE MULTIPLIERS ===
@export_group("Surface Multipliers", "surface_")
@export var fore_damage_multiplier: float = 1.0          # Damage to fore armor
@export var aft_damage_multiplier: float = 1.0           # Damage to aft armor
@export var left_damage_multiplier: float = 1.0          # Damage to left armor
@export var right_damage_multiplier: float = 1.0         # Damage to right armor
@export var top_damage_multiplier: float = 1.0           # Damage to top armor
@export var bottom_damage_multiplier: float = 1.0        # Damage to bottom armor

# === ENERGY CONSUMPTION ===
@export_group("Energy", "energy_")
@export var energy_per_shot: float = 3.5                 # Ship energy consumed per shot
@export var heat_generated_per_shot: float = 5.0         # Heat units generated
@export var overheat_threshold: float = 100.0            # Temperature to cause malfunction
@export var cooling_rate: float = 10.0                   # Heat dissipation per second
@export var heat_capacity: float = 200.0                 # Total heat capacity
@export var thermal_efficiency: float = 0.95             # Energy to heat conversion

# === PROJECTILE VISUALS ===
@export_group("Visual Effects", "visual_")
@export var projectile_model: String = ""                 # Cross-reference to 3D model
@export var laser_bitmap: String = ""                     # Cross-reference to 2D texture
@export var laser_glow: String = ""                       # Cross-reference to glow effect
@export var laser_length_meters: float = 10.0            # Visible laser length
@export var laser_head_radius: float = 0.9               # Laser starting radius
@export var laser_tail_radius: float = 0.9               # Laser ending radius
@export var laser_primary_color: Color = Color(212, 16, 229)    # Primary laser color
@export var laser_secondary_color: Color = Color(0, 0, 0)      # Secondary laser color
@export var muzzle_flash_effect: String = ""              # Cross-reference to effect
@export var impact_effect: String = ""                    # Cross-reference to effect
@export var explosion_effect: String = ""                 # Cross-reference to effect
@export var projectile_trail_effect: String = ""          # Cross-reference to trail effect

# === AUTO-TARGETING SYSTEMS ===
@export_group("Targeting", "targeting_")
@export var homing_type: int = 0                          # 0=None, 1=Aspect, 2=Heat, 3=Image, 4=Friend/Foe
@export var guidance_package: String = ""                 # Cross-reference to guidance system
@export var lock_time_seconds: float = 0.0               # Time to achieve lock
@export var lock_range_meters: float = 1500.0            # Maximum lock range
@export var lock_field_of_view_degrees: float = 5.0      # FOV for target acquisition
@export var max_turn_rate_dps: float = 0.0               # Maximum turn rate in degrees/second
@export var max_seek_distance: float = 2000.0            # Maximum seek distance
@export var seeking_duration_seconds: float = 10.0       # Seeking duration
@export var decoy_resistance: float = 0.8                # Resistance to countermeasures
@export var target_tracking_accuracy: float = 0.95       # Tracking accuracy (0.0-1.0)

# === BURST AND MULTI-SHOT ===
@export_group("Burst Fire", "burst_")
@export var shots_per_burst: int = 1                     # Number of shots in burst
@export var burst_fire_delay: float = 0.0                # Delay between burst shots
@export var burst_cooldown: float = 0.0                  # Cooldown after burst
@export var multi_shot_count: int = 1                    # Projectiles per shot (swarm)
@export var shot_spread_pattern: Vector2 = Vector2.ZERO   # Shot spread angles (horizontal, vertical)

# === COUNTERMEASURE INTERACTION ===
@export_group("Countermeasures", "cm_")
@export var countermeasure_vulnerability: float = 0.0      # Vulnerability to countermeasures
@export var chaff_effectiveness_multiplier: float = 1.0    # Chaff effectiveness
@export var flare_effectiveness_multiplier: float = 1.0    # Flare effectiveness
@export var stealth_detection_range_modifier: float = 1.0  # Stealth detection modification

# === SPECIAL CHARACTERISTICS ===
@export_group("Special", "special_")
@export var cargo_size_units: int = 1                    # Cargo space required
@export var is_bomb_type: bool = false                   # Requires bombing bay
@export var is_huge_weapon: bool = false                 # Requires capital ship mount
@export var no_shield_piercing: bool = false            # Cannot penetrate shields
@export var pierces_shields_only: bool = false           # Only damages shields
@export var drains_energy_on_hit: float = 0.0            # Energy drained from target
@export var disables_subsystems_chance: float = 0.0      # Chance to disable subsystems

# === AUDIO SYSTEMS ===
@export_group("Audio", "audio_")
@export var launch_sound_resource: String = ""           # Cross-reference to audio
@export var impact_sound_resource: String = ""           # Cross-reference to audio
@export var flyby_sound_resource: String = ""            # Cross-reference to audio
@export var lock_acquisition_sound: String = ""          # Cross-reference to audio
@export var lock_lost_sound: String = ""                 # Cross-reference to audio
@export var missile_tracking_sound: String = ""          # Cross-reference to audio

# === VISUALIZATION HELPERS ===
@export_group("Visualization", "viz_")
@export var display_icon: String = ""                     # Cross-reference to UI icon
@export var tech_animation: String = ""                   # Cross-reference to tech animation
@export var loadout_visual: String = ""                   # Cross-reference to loadout art
@export var inventory_model: String = ""                  # Cross-reference to inventory model

# Validation signals
signal damage_calculation_changed()
signal targeting_parameters_changed()
signal visual_effects_changed()

# ================== VALIDATION METHODS ==================

func get_resource_type() -> String:
	return "weapon_data"

func validate() -> bool:
	"""Comprehensive weapon data validation with physics modeling"""
	validation_errors.clear()
	validation_warnings.clear()

	# Call parent validation first
	if not super.validate():
		return false

	# Validate identity and classification
	_validate_weapon_identity()
	_validate_physics_modeling()
	_validate_damage_profile()
	_validate_surface_multipliers()
	_validate_energy_system()
	_validate_visual_effects()
	_validate_targeting_system()
	_validate_countermeasures()
	_validate_special_properties()
	_validate_audio_resources()

	# Final validation status
	is_valid = validation_errors.size() == 0
	validation_status_changed.emit(is_valid)

	return is_valid

func _validate_weapon_identity() -> void:
	"""Validate weapon identity properties"""
	if weapon_class.is_empty():
		_add_validation_error("Weapon class cannot be empty")

	if display_name.is_empty():
		_add_validation_warning("Display name not specified - using weapon class")

	if weapon_type < 0 or weapon_type > 3:
		_add_validation_error("Weapon type must be between 0 and 3")

	if tech_level < 0:
		_add_validation_error("Technology level cannot be negative")

	if manufacturer_species.is_empty():
		_add_validation_warning("Manufacturer species not specified")
	else:
		add_cross_reference_dependency("res://scripts/resources/species_data.gd")

func _validate_physics_modeling() -> void:
	"""Validate physics-based properties"""
	if projectile_mass_kg < 0:
		_add_validation_error("Projectile mass cannot be negative")

	if muzzle_velocity_mps <= 0:
		_add_validation_error("Muzzle velocity must be positive")

	if projectile_lifetime <= 0:
		_add_validation_error("Projectile lifetime must be positive")

	if fire_rate_hz <= 0:
		_add_validation_error("Fire rate must be positive")

	# Calculate expected range from velocity and lifetime
	var calculated_range = muzzle_velocity_mps * projectile_lifetime
	if abs(calculated_range - effective_range_meters) > 10.0:
		_add_validation_warning("Effective range doesn't match velocity * lifetime")

	if fire_rate_hz > 50.0:
		_add_validation_warning("Very high fire rate may affect performance")

func _validate_damage_profile() -> void:
	"""Validate damage modeling parameters"""
	if base_damage_energy < 0:
		_add_validation_error("Base damage cannot be negative")

	if armor_penetration_factor < 0:
		_add_validation_error("Armor penetration factor cannot be negative")

	if shield_penetration_factor < 0:
		_add_validation_error("Shield penetration factor cannot be negative")

	if hull_penetration_factor < 0:
		_add_validation_error("Hull penetration factor cannot be negative")

	if subsystem_damage_factor < 0:
		_add_validation_error("Subsystem damage factor cannot be negative")

	# Validate explosion parameters for explosive weapons
	if blast_radius > 0:
		if explosion_damage <= 0:
			_add_validation_error("Explosive weapons must have positive explosion damage")
		if shockwave_speed <= 0:
			_add_validation_error("Explosive weapons must have positive shockwave speed")

func _validate_surface_multipliers() -> void:
	"""Validate surface damage multipliers"""
	var multipliers = [
		fore_damage_multiplier,
		aft_damage_multiplier,
		left_damage_multiplier,
		right_damage_multiplier,
		top_damage_multiplier,
		bottom_damage_multiplier
	]

	for multiplier in multipliers:
		if multiplier < 0:
			_add_validation_error("Surface damage multipliers cannot be negative")

	# Check if any multipliers are significantly different (potential balance issue)
	var avg_multiplier = 0.0
	for multiplier in multipliers:
		avg_multiplier += multiplier
	avg_multiplier /= multipliers.size()

	for multiplier in multipliers:
		if abs(multiplier - avg_multiplier) > 2.0:
			_add_validation_warning("Surface damage multipliers have high variance")
			break

func _validate_energy_system() -> void:
	"""Validate weapon energy consumption"""
	if energy_per_shot < 0:
		_add_validation_error("Energy per shot cannot be negative")

	if heat_generated_per_shot < 0:
		_add_validation_error("Heat generation per shot cannot be negative")

	if overheat_threshold <= 0 and heat_generated_per_shot > 0:
		_add_validation_error("Overheat threshold must be positive when heat is generated")

	if cooling_rate < 0:
		_add_validation_error("Cooling rate cannot be negative")

	if heat_capacity <= 0 and heat_generated_per_shot > 0:
		_add_validation_error("Heat capacity must be positive when heat is generated")

func _validate_visual_effects() -> void:
	"""Validate visual effect references"""
	var effect_refs = [
		projectile_model,
		laser_bitmap,
		laser_glow,
		muzzle_flash_effect,
		impact_effect,
		explosion_effect,
		projectile_trail_effect
	]

	for effect_ref in effect_refs:
		if not effect_ref.is_empty():
			add_cross_reference_dependency(effect_ref)

	# Validate laser visual properties
	if weapon_type == 0:  # Energy weapon
		if laser_length_meters <= 0:
			_add_validation_warning("Laser weapon has zero length")

		if laser_head_radius <= 0 or laser_tail_radius <= 0:
			_add_validation_error("Laser radius must be positive")

func _validate_targeting_system() -> void:
	"""Validate homing and targeting systems"""
	if homing_type < 0 or homing_type > 4:
		_add_validation_error("Homing type must be between 0 and 4")

	if homing_type > 0:  # Any homing weapon
		if lock_time_seconds < 0:
			_add_validation_error("Lock time cannot be negative")

		if lock_range_meters <= 0:
			_add_validation_error("Lock range must be positive for homing weapons")

		if max_turn_rate_dps <= 0:
			_add_validation_error("Turning rate must be positive for homing weapons")

		if seeking_duration_seconds <= 0:
			_add_validation_error("Seeking duration must be positive for homing weapons")

		if not guidance_package.is_empty():
			add_cross_reference_dependency(guidance_package)

	if lock_range_meters > 0 and homing_type == 0:
		_add_validation_warning("Non-homing weapon has lock range defined")

func _validate_countermeasures() -> void:
	"""Validate countermeasure interaction properties"""
	if countermeasure_vulnerability < 0 or countermeasure_vulnerability > 1:
		_add_validation_error("Countermeasure vulnerability must be between 0.0 and 1.0")

	if chaff_effectiveness_multiplier < 0:
		_add_validation_error("Chaff effectiveness multiplier cannot be negative")

	if flare_effectiveness_multiplier < 0:
		_add_validation_error("Flare effectiveness multiplier cannot be negative")

func _validate_special_properties() -> void:
	"""Validate special weapon properties"""
	if drains_energy_on_hit < 0:
		_add_validation_error("Energy drain per hit cannot be negative")

	if disables_subsystems_chance < 0 or disables_subsystems_chance > 1:
		_add_validation_error("Subsystem disable chance must be between 0.0 and 1.0")

	# Validate conflicting flags
	if no_shield_piercing and pierces_shields_only:
		_add_validation_error("Weapon cannot both ignore shields and only damage shields")

	# Validate weapon category flags
	var special_flags = 0
	if is_bomb_type: special_flags += 1
	if is_huge_weapon: special_flags += 1

	if special_flags > 1:
		_add_validation_warning("Weapon has multiple special type flags")

func _validate_audio_resources() -> void:
	"""Validate audio resource references"""
	var audio_refs = [
		launch_sound_resource,
		impact_sound_resource,
		flyby_sound_resource,
		lock_acquisition_sound,
		lock_lost_sound,
		missile_tracking_sound
	]

	for audio_ref in audio_refs:
		if not audio_ref.is_empty():
			add_cross_reference_dependency(audio_ref)

# ================== DAMAGE CALCULATION METHODS ==================

func calculate_damage_against_target(
	target_species: String,
	target_armor_rating: float,
	target_shield_strength: float,
	impact_point_local: Vector3,
	impact_angle_degrees: float,
	impact_velocity: float
) -> Dictionary:
	"""
	Calculate actual damage against target based on detailed physics model.

	Returns dictionary with detailed damage breakdown:
	{
		total_damage: float,
		armor_damage: float,
		shield_damage: float,
		hull_damage: float,
		subsystem_damage: float,
		damage_type: String,
		penetrations: Array[String]
	}
	"""
	var result = {
		"total_damage": 0.0,
		"armor_damage": 0.0,
		"shield_damage": 0.0,
		"hull_damage": 0.0,
		"subsystem_damage": 0.0,
		"damage_type": "energy",
		"penetrations": []
	}

	# Base damage calculation
	var base_damage = base_damage_energy

	# Apply surface-specific multipliers based on impact location
	var surface_multiplier = get_surface_damage_multiplier(impact_point_local)
	base_damage *= surface_multiplier

	# Apply angle-based damage reduction
	var angle_radians = deg_to_rad(impact_angle_degrees)
	var angle_modifier = abs(cos(angle_radians))
	base_damage *= angle_modifier

	# Calculate damage to different defense layers
	if target_shield_strength > 0:
		# Target has active shields
		var shield_damage = base_damage * shield_penetration_factor

		if no_shield_piercing:
			# Weapon cannot penetrate shields
			result["shield_damage"] = min(shield_damage, target_shield_strength)
			result["total_damage"] = result["shield_damage"]
			result["penetrations"].append("shield_only")
		else:
			# Weapon can penetrate shields
			result["shield_damage"] = min(shield_damage, target_shield_strength)
			var remaining_damage = max(0, shield_damage - target_shield_strength)

			# Apply remaining damage to armor/hull
			var remaining_armor = target_armor_rating * armor_penetration_factor
			result["armor_damage"] = min(remaining_damage, remaining_armor)
			result["hull_damage"] = max(0, remaining_damage - remaining_armor)

			if remaining_damage > 0:
				result["penetrations"].append("shield_penetrate")
	else:
		# No active shields - damage goes directly to armor/hull
		var armor_damage = base_damage * armor_penetration_factor
		result["armor_damage"] = min(armor_damage, target_armor_rating)
		result["hull_damage"] = max(0, armor_damage - target_armor_rating)

		if result["hull_damage"] > 0:
			result["penetrations"].append("armor_penetrate")

	# Calculate subsystem damage
	result["subsystem_damage"] = result["hull_damage"] * subsystem_damage_factor

	# Calculate total damage
	result["total_damage"] = result["shield_damage"] + result["armor_damage"] + result["hull_damage"]

	# Apply explosion damage if applicable
	if blast_radius > 0 and result["total_damage"] > 0:
		var explosion_result = calculate_explosion_damage(impact_point_local, blast_radius)
		result["total_damage"] += explosion_result["explosion_damage"]
		result["armor_damage"] += explosion_result["armor_damage"]
		result["hull_damage"] += explosion_result["hull_damage"]
		if explosion_result["explosion_damage"] > 0:
			result["penetrations"].append("explosion")

	# Apply energy drain if applicable
	if drains_energy_on_hit > 0:
		result["energy_drained"] = drains_energy_on_hit

	return result

func get_surface_damage_multiplier(impact_point_local: Vector3) -> float:
	"""Get surface damage multiplier based on impact location"""
	var normalized_point = impact_point_local.normalized()

	# Determine surface based on normal direction
	if normalized_point.z > 0.5:  # Fore
		return fore_damage_multiplier
	elif normalized_point.z < -0.5:  # Aft
		return aft_damage_multiplier
	elif normalized_point.x > 0.5:  # Right
		return right_damage_multiplier
	elif normalized_point.x < -0.5:  # Left
		return left_damage_multiplier
	elif normalized_point.y > 0.5:  # Top
		return top_damage_multiplier
	elif normalized_point.y < -0.5:  # Bottom
		return bottom_damage_multiplier
	else:
		# Inconclusive - return average
		return (fore_damage_multiplier + aft_damage_multiplier +
				left_damage_multiplier + right_damage_multiplier +
				top_damage_multiplier + bottom_damage_multiplier) / 6.0

func calculate_explosion_damage(target_position: Vector3, explosion_radius: float) -> Dictionary:
	"""Calculate explosion damage at target position"""
	var result = {
		"explosion_damage": 0.0,
		"armor_damage": 0.0,
		"hull_damage": 0.0,
		"shield_damage": 0.0
	}

	if blast_radius <= 0 or explosion_damage <= 0:
		return result

	# Damage falls off with distance from explosion center
	var distance_from_center = target_position.length()
	var damage_falloff = 1.0 - clamp(distance_from_center / blast_radius, 0.0, 1.0)

	if damage_falloff <= 0:
		return result  # Too far from explosion

	# Calculate explosion damage
	var explosion_damage_amount = explosion_damage * damage_falloff

	# Distribute damage based on penetration factors
	result["shield_damage"] = explosion_damage_amount * shield_penetration_factor
	result["armor_damage"] = explosion_damage_amount * armor_penetration_factor
	result["hull_damage"] = explosion_damage_amount * hull_penetration_factor
	result["explosion_damage"] = explosion_damage_amount

	return result

# ================== UTILITY METHODS ==================

func get_damage_per_second() -> float:
	"""Calculate theoretical damage per second"""
	return base_damage_energy * fire_rate_hz

func get_energy_efficiency() -> float:
	"""Calculate energy efficiency (damage per energy unit)"""
	if energy_per_shot <= 0:
		return 0.0
	return base_damage_energy / energy_per_shot

func get_thermal_efficiency() -> float:
	"""Calculate thermal efficiency (damage per heat unit)"""
	if heat_generated_per_shot <= 0:
		return 0.0
	return base_damage_energy / heat_generated_per_shot

func is_explosive() -> bool:
	"""Check if weapon is explosive"""
	return blast_radius > 0 and explosion_damage > 0

func is_homing() -> bool:
	"""Check if weapon has homing capability"""
	return homing_type > 0 and max_turn_rate_dps > 0

func is_burst_weapon() -> bool:
	"""Check if weapon fires in bursts"""
	return shots_per_burst > 1

func get_homing_type_name() -> String:
	"""Get human-readable homing type name"""
	var homing_types = ["None", "Aspect", "Heat", "Image", "Friend/Foe"]
	if homing_type >= 0 and homing_type < homing_types.size():
		return homing_types[homing_type]
	return "Unknown"

func get_weapon_type_name() -> String:
	"""Get human-readable weapon type name"""
	var weapon_types = ["Energy", "Ballistic", "Missile", "Special"]
	if weapon_type >= 0 and weapon_type < weapon_types.size():
		return weapon_types[weapon_type]
	return "Unknown"