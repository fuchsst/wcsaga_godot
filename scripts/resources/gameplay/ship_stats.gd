# ShipStats - Comprehensive Ship Configuration Resource
# Represents complete ship configuration from ships.tbl with enhanced validation
# and cross-reference resolution for Wing Commander Saga ships

class_name ShipStats
extends WCSBaseResource

# === IDENTITY AND CLASSIFICATION ===
@export_group("Identity", "identity_")
@export var ship_class: String = "" # Military designation (F-86C Hellcat V)
@export var display_name: String = "" # Common name (Hellcat V)
@export var ship_short_name: String = "" # Short identifier (Hellcat)
@export var ship_role: int = 0 # 0=Fighter, 1=Bomber, 2=Capital, 3=Support
@export var ship_category: String = "" # Light, Medium, Heavy
@export var species_mnemonic: String = "" # Cross-reference to SpeciesData
@export var manufacturer: String = "" # Ship manufacturer
@export var tech_level: int = 0 # Technology era (0=WC1, 1=WC2, etc.)
@export var is_player_ship: bool = false # Can be flown by player
@export var is_civilian: bool = false # Non-combat vessel
@export var description: String = "" # Ship description
@export var tech_description: String = "" # Technical description
@export var density: float = 1.0 # Physics density

# === VISUAL REPRESENTATION ===
@export_group("Visual", "visual_")
@export var model_file: String = "" # Cross-reference to POF resource
@export var model_lod_target: int = 2 # Level of detail target
@export var shield_icon: String = "" # Cross-reference to UI resource
@export var detail_distances: Array[int] = [] # LOD switch distances [0, 250, 375]
@export var closeup_position: Vector3 = Vector3.ZERO # Camera position for close-up view
@export var closeup_zoom: float = 0.4 # Camera zoom factor

# === PHYSICAL SPECIFICATIONS ===
@export_group("Physics", "physics_")
@export var ship_length_meters: float = 0.0 # Ship length in meters
@export var ship_mass_tons: float = 0.0 # Ship mass in tons
@export var armor_thickness: Dictionary = { # Armor thickness in cm
	"fore": 0.0,
	"aft": 0.0,
	"left": 0.0,
	"right": 0.0,
	"top": 0.0,
	"bottom": 0.0
}

# === MOVEMENT AND PERFORMANCE ===
@export_group("Movement", "movement_")
@export var max_velocity: Vector3 = Vector3(0, 0, 66.31) # m/s - X/Y/Z components
@export var afterburner_velocity: Vector3 = Vector3(0, 0, 189.47) # Afterburner max velocity
@export var rotation_time: Vector3 = Vector3(6.0, 6.0, 6.0) # Seconds for 360° in pitch/yaw/roll
@export var movement_dampening: float = 0.6 # Movement damping coefficient
@export var rotational_dampening: float = 1.2 # Rotation damping coefficient
@export var forward_acceleration: float = 0.3734 # Forward acceleration
@export var forward_deceleration: float = 0.7467 # Forward deceleration
@export var slide_acceleration: float = 0.0 # Lateral movement acceleration
@export var slide_deceleration: float = 0.0 # Lateral movement deceleration
@export var glide_enabled: bool = false # Glide mode capability
@export var rear_velocity: float = 0.0 # Maximum reverse velocity

# === SHIELD SYSTEMS ===
@export_group("Shields", "shield_")
@export var shield_strength: int = 880 # Maximum shield hitpoints
@export var shield_regen_rate: float = 0.05 # Percent of max per second
@export var shield_color_primary: Color = Color(0, 100, 255) # Primary shield color
@export var shield_color_secondary: Color = Color(150, 200, 255) # Secondary shield color
@export var shield_icon_name: String = "" # Cross-reference to icon resource
@export var shield_regen_delay: float = 2.0 # Seconds before regeneration starts

# === HULL INTEGRITY ===
@export_group("Hull", "hull_")
@export var hull_hitpoints: int = 360 # Total hull hitpoints
@export var armor_rating: int = 100 # Base armor rating
@export var subsystem_hitpoints: Dictionary = {} # Subsystem name -> hitpoints mapping
@export var explosion_effect: String = "" # Cross-reference to effect resource
@export var explosion_inner_radius: float = 8.54 # Inner explosion damage radius
@export var explosion_outer_radius: float = 34.16 # Outer explosion damage radius
@export var explosion_damage: float = 15.0 # Base explosion damage
@export var explosion_blast: float = 150.0 # Explosion blast force
@export var shockwave_speed: float = 68.32 # Shockwave propagation speed
@export var shockwave_model: String = "" # Cross-reference to shockwave model

# === WEAPON SYSTEMS ===
@export_group("Weapons", "weapon_")
@export var allowed_primary_weapons: Array[String] = [] # Cross-references to WeaponData resources
@export var allowed_secondary_weapons: Array[String] = [] # Cross-references to WeaponData resources
@export var default_primary_loadouts: Array[String] = [] # Default primary weapon assignments
@export var default_secondary_loadouts: Array[String] = [] # Default secondary weapon assignments
@export var weapon_mounts: Array[WeaponMount] = [] # Detailed weapon mount specifications
@export var max_weapon_energy: float = 60.0 # Maximum weapon energy capacity
@export var weapon_energy_regen_rate: float = 0.14 # Weapon energy regeneration per second
@export var weapon_regen_delay: float = 1.0 # Seconds before weapon energy regenerates

# === ENERGY AND POWER ===
@export_group("Power", "power_")
@export var max_afterburner_fuel: float = 250.0 # Maximum afterburner fuel
@export var afterburner_fuel_regen_rate: float = 0.0 # Afterburner fuel regeneration
@export var afterburner_burn_rate: float = 1.0 # Fuel consumption rate
@export var reactor_type: String = "" # Cross-reference power system
@export var power_output: float = 3.9 # Total power output

# === AI BEHAVIOR PARAMETERS ===
@export_group("AI", "ai_")
@export var ai_aggressiveness: float = 0.5 # 0.0-1.0 aggression level
@export var ai_skill_level: float = 0.8 # 0.0-1.0 skill level
@export var ai_reaction_time: float = 0.5 # Seconds to react to threats
@export var ai_optimal_range: float = 600.0 # Optimal combat range in meters
@export var ai_class_level: String = "" # AI difficulty class (Captain, etc.)
@export var scan_time_ms: int = 2000 # Milliseconds to scan target

# === COUNTERMEASURES ===
@export_group("Countermeasures", "cm_")
@export var countermeasures_count: int = 24 # Number of countermeasures
@export var countermeasure_types: Array[String] = [] # Available countermeasure types
@export var cm_effectiveness_multiplier: float = 1.0 # Effectiveness multiplier

# === GAMEPLAY FLAGS ===
@export_group("Gameplay", "gameplay_")
@export var is_player_allowed: bool = true # Can be flown by player
@export var appears_in_tech_database: bool = false # Shows in tech database
@export var is_stealth: bool = false # Has stealth capabilities
@export var is_default_player_ship: bool = false # Default player ship option
@export var cargo_capacity: int = 0 # Cargo space units
@export var score_value: int = 10 # Score value when destroyed
@export var cargo_size_units: int = 1 # Cargo size for loading
@export var engine_sound_id: int = 126 # Cross-reference to audio resource

# === SUBSYSTEM SPECIFICATIONS ===
@export_group("Subsystems", "subsystem_")
@export var engine_subsystems: Array[EngineSubsystem] = [] # Engine subsystem specifications
@export var weapon_subsystems: Array[WeaponSubsystem] = [] # Weapon subsystem specifications
@export var shield_subsystems: Array[ShieldSubsystem] = [] # Shield subsystem specifications

# === TURRET INFORMATION ===
@export_group("Turrets", "turret_")
@export_varturret_mounts: Array[TurretMount] = [] # Turret mounting specifications
@export_varturret_rotation_limits: Dictionary = {} # Turret rotation constraints

# Internal validation signals
signal weapon_mounts_changed()
signal subsystem_configuration_changed()

# === NESTED RESOURCE CLASSES ===

class WeaponMount extends Resource:
	"""Detailed weapon mount specification"""
	@export var mount_name: String = "" # Mount identifier
	@export var mount_type: int = 0 # 0=Primary, 1=Secondary, 2=Special
	@export var position: Vector3 = Vector3.ZERO # Local coordinates on model
	@export var orientation: Vector3 = Vector3.FORWARD # Firing direction
	@export var weapon_class: String = "" # Allowed weapon categories
	@export var fire_cooldown: float = 0.35 # Cooldown between shots
	@export var damage_multiplier: float = 1.0 # Damage output multiplier
	@export var fire_arc_horizontal: float = 360.0 # Horizontal firing arc in degrees
	@export var fire_arc_vertical: float = 360.0 # Vertical firing arc in degrees
	@export var linked_mounts: Array[String] = [] # Other mounts that fire together
	@export var is_gimballed: bool = false # Can track targets
	@export var gimbal_range: float = 0.0 # Gimbal tracking range

class EngineSubsystem extends Resource:
	"""Engine subsystem configuration"""
	@export var subsystem_name: String = "" # Subsystem name
	@export var hitpoints: float = 15.0 # Subsystem hitpoints
	@export var max_hitpoints: float = 15.0 # Maximum hitpoints
	@export var damage_threshold: float = 0.0 # Damage threshold
	@export var affects_performance: bool = true # Damaged engine affects performance
	@export_varthruster_effects: Array[String] = [] # Cross-references to effects

class WeaponSubsystem extends Resource:
	"""Weapon subsystem configuration"""
	@export var subsystem_name: String = "" # Subsystem name
	@export var hitpoints: float = 10.0 # Subsystem hitpoints
	@export var weapon_count: int = 0 # Number of weapons affected
	@export var affected_weapons: Array[int] = [] # Indices of affected weapon mounts
	@export var damage_effect: float = 1.0 # Performance degradation multiplier

class ShieldSubsystem extends Resource:
	"""Shield subsystem configuration"""
	@export var subsystem_name: String = "" # Subsystem name
	@export var shield_generator_type: String = "" # Generator type
	@export var hitpoints: float = 20.0 # Subsystem hitpoints
	@export var shield_regen_multiplier: float = 1.0 # Shield regeneration multiplier

class TurretMount extends Resource:
	"""Turret mount specification"""
	@export var turret_name: String = "" # Turret identifier
	@export var base_position: Vector3 = Vector3.ZERO # Base mount position
	@export var barrel_length: float = 1.0 # Turret barrel length
	@export var rotation_speed: float = 45.0 # Degrees per second
	@export var elevation_limits: Vector2 = Vector2(-90, 90) # Min/max elevation angles
	@export var azimuth_limits: Vector2 = Vector2(-180, 180) # Min/max azimuth angles
	@export var weapon_class: String = "" # Allowed weapon type

# ================== VALIDATION METHODS ==================

func get_resource_type() -> String:
	return "ship_stats"

func validate() -> bool:
	"""Comprehensive ship data validation"""
	validation_errors.clear()
	validation_warnings.clear()

	# Call parent validation first
	if not super.validate():
		return false

	# Validate identity and classification
	_validate_ship_identity()
	_validate_visual_representation()
	_validate_physics_properties()
	_validate_movement_parameters()
	_validate_shield_systems()
	_validate_weapon_systems()
	_validate_power_systems()
	_validate_ai_behavior()
	_validate_subsystems()

	# Final validation status
	is_valid = validation_errors.size() == 0
	validation_status_changed.emit(is_valid)

	return is_valid

func _validate_ship_identity() -> void:
	"""Validate ship identity properties"""
	if ship_class.is_empty():
		_add_validation_error("Ship class cannot be empty")

	if display_name.is_empty():
		_add_validation_warning("Display name not specified - using ship class")

	if species_mnemonic.is_empty():
		_add_validation_error("Species mnemonic is required")
	else:
		add_cross_reference_dependency("res://scripts/resources/species_data.gd")

	if ship_role < 0 or ship_role > 3:
		_add_validation_error("Ship role must be between 0 and 3")

func _validate_visual_representation() -> void:
	"""Validate visual representation properties"""
	if model_file.is_empty():
		_add_validation_error("Model file reference is required")
	else:
		add_cross_reference_dependency(model_file)

	if shield_icon.is_empty() and is_player_ship:
		_add_validation_warning("Player ship lacks shield icon")

	_validate_detail_distances()

func _validate_detail_distances() -> void:
	"""Validate LOD detail distances"""
	if detail_distances.size() < 2:
		_add_validation_warning("Minimum 2 detail distances recommended")
		return

	for i in range(detail_distances.size() - 1):
		if detail_distances[i] >= detail_distances[i + 1]:
			_add_validation_error("Detail distances must be in ascending order")

func _validate_physics_properties() -> void:
	"""Validate physics properties"""
	if ship_length_meters <= 0:
		_add_validation_error("Ship length must be positive")

	if ship_mass_tons <= 0:
		_add_validation_error("Ship mass must be positive")

	# Validate armor thickness
	var armor_valid = true
	var armor_total = 0.0
	for armor_section in armor_thickness.values():
		if armor_section < 0:
			armor_valid = false
			break
		armor_total += armor_section

	if not armor_valid:
		_add_validation_error("Armor thickness cannot be negative")

	if armor_total == 0 and hull_hitpoints > 0:
		_add_validation_warning("No armor specified for a combat vessel")

func _validate_movement_parameters() -> void:
	"""Validate movement and performance parameters"""
	# Validate velocities
	for axis in range(3):
		var velocity = max_velocity[axis]
		if velocity < 0:
			_add_validation_error("Maximum velocity cannot be negative")
			break

	# Validate rotation times
	for axis in range(3):
		var rotation = rotation_time[axis]
		if rotation <= 0:
			_add_validation_error("Rotation time must be positive")
			break

	# Validate damping coefficients
	if movement_dampening < 0:
		_add_validation_error("Movement dampening cannot be negative")

	if rotational_dampening < 0:
		_add_validation_error("Rotational dampening cannot be negative")

func _validate_shield_systems() -> void:
	"""Validate shield system properties"""
	if shield_strength < 0:
		_add_validation_error("Shield strength cannot be negative")

	if shield_regen_rate < 0:
		_add_validation_error("Shield regeneration rate cannot be negative")

	if shield_regen_rate > 1.0:
		_add_validation_error("Shield regeneration rate cannot exceed 100% per second")

	if shield_regen_delay < 0:
		_add_validation_error("Shield regeneration delay cannot be negative")

func _validate_weapon_systems() -> void:
	"""Validate weapon system configuration"""
	# Validate weapon references
	for weapon_path in allowed_primary_weapons:
		if not weapon_path.is_empty():
			add_cross_reference_dependency(weapon_path)

	for weapon_path in allowed_secondary_weapons:
		if not weapon_path.is_empty():
			add_cross_reference_dependency(weapon_path)

	# Validate weapon mounts
	for mount in weapon_mounts:
		_validate_weapon_mount(mount)

	# Validate weapon energy
	if max_weapon_energy <= 0:
		_add_validation_error("Maximum weapon energy must be positive")

	if weapon_energy_regen_rate < 0:
		_add_validation_error("Weapon energy regeneration cannot be negative")

func _validate_weapon_mount(mount: WeaponMount) -> void:
	"""Validate individual weapon mount"""
	if mount.mount_name.is_empty():
		_add_validation_warning("Weapon mount lacks name")

	if mount.mount_type < 0 or mount.mount_type > 2:
		_add_validation_error("Weapon mount type must be 0, 1, or 2")

	if mount.damage_multiplier <= 0:
		_add_validation_error("Weapon mount damage multiplier must be positive")

	if mount.fire_cooldown <= 0:
		_add_validation_error("Weapon mount fire cooldown must be positive")

func _validate_power_systems() -> void:
	"""Validate power and energy systems"""
	if max_afterburner_fuel < 0:
		_add_validation_error("Maximum afterburner fuel cannot be negative")

	if afterburner_burn_rate <= 0 and max_afterburner_fuel > 0:
		_add_validation_error("Afterburner burn rate must be positive when fuel capacity exists")

	if power_output <= 0:
		_add_validation_warning("Power output should be positive for powered vessels")

func _validate_ai_behavior() -> void:
	"""Validate AI behavior parameters"""
	if ai_aggressiveness < 0 or ai_aggressiveness > 1:
		_add_validation_error("AI aggressiveness must be between 0.0 and 1.0")

	if ai_skill_level < 0 or ai_skill_level > 1:
		_add_validation_error("AI skill level must be between 0.0 and 1.0")

	if ai_reaction_time < 0:
		_add_validation_error("AI reaction time cannot be negative")

	if ai_optimal_range <= 0:
		_add_validation_error("AI optimal range must be positive")

func _validate_subsystems() -> void:
	"""Validate subsystem configurations"""
	# Validate engine subsystems
	for engine in engine_subsystems:
		if engine.hitpoints <= 0:
			_add_validation_error("Engine subsystem hitpoints must be positive")

	# Validate weapon subsystems
	for weapon_sub in weapon_subsystems:
		if weapon_sub.damage_effect <= 0:
			_add_validation_error("Weapon subsystem damage effect must be positive")

# ================== UTILITY METHODS ==================

func get_weapon_mount_by_name(mount_name: String) -> WeaponMount:
	"""Get weapon mount by name"""
	for mount in weapon_mounts:
		if mount.mount_name == mount_name:
			return mount
	return null

func get_primary_weapon_mounts() -> Array[WeaponMount]:
	"""Get all primary weapon mounts"""
	var primary_mounts = []
	for mount in weapon_mounts:
		if mount.mount_type == 0:
			primary_mounts.append(mount)
	return primary_mounts

func get_secondary_weapon_mounts() -> Array[WeaponMount]:
	"""Get all secondary weapon mounts"""
	var secondary_mounts = []
	for mount in weapon_mounts:
		if mount.mount_type == 1:
			secondary_mounts.append(mount)
	return secondary_mounts

func calculate_total_armor() -> float:
	"""Calculate total armor value"""
	var total_armor = 0.0
	for armor_value in armor_thickness.values():
		total_armor += armor_value
	return total_armor

func get_damage_profile() -> Dictionary:
	"""Get ship damage profile based on armor distribution"""
	var total_armor = calculate_total_armor()
	if total_armor == 0:
		return {
			"fore_weakness": 1.0,
			"aft_weakness": 1.0,
			"side_weakness": 1.0,
			"top_weakness": 1.0,
			"bottom_weakness": 1.0
		}

	return {
		"fore_weakness": 1.0 - (armor_thickness["fore"] / total_armor),
		"aft_weakness": 1.0 - (armor_thickness["aft"] / total_armor),
		"side_weakness": 1.0 - ((armor_thickness["left"] + armor_thickness["right"]) / (2 * total_armor)),
		"top_weakness": 1.0 - (armor_thickness["top"] / total_armor),
		"bottom_weakness": 1.0 - (armor_thickness["bottom"] / total_armor)
	}