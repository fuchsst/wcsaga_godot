class_name WeaponData
extends Resource

## WCS Weapon data resource containing all properties from weapons.tbl
## Represents a weapon system with damage, projectile, and behavior data

@export var weapon_name: String = ""
@export var title: String = ""
@export var desc: String = ""
@export var tech_title: String = ""
@export var tech_anim: String = ""
@export var tech_desc: String = ""

# Basic weapon properties
@export var subtype: String = "Primary"  # Primary, Secondary
@export var model_file: String = ""
@export var mass: float = 1.0
@export var velocity: float = 100.0
@export var fire_wait: float = 1.0  # Seconds between shots
@export var damage: float = 10.0
@export var damage_type: String = "energy"  # energy, kinetic, heat, etc.

# Projectile behavior
@export var lifetime: float = 5.0
@export var energy_consumed: float = 1.0
@export var cargo_size: float = 1.0
@export var homing_type: String = "none"  # none, heat, aspect, javelin
@export var turn_rate: float = 0.0  # For homing weapons
@export var lock_time: float = 0.0  # Time to achieve lock

# Damage and effects
@export var damage_time: float = 0.0  # Duration of damage effect
@export var blast_radius: float = 0.0
@export var inner_radius: float = 0.0
@export var outer_radius: float = 0.0
@export var shockwave_speed: float = 0.0
@export var armor_factor: float = 1.0
@export var shield_factor: float = 1.0
@export var subsystem_factor: float = 1.0

# Visual and audio
@export var muzzle_flash: String = ""
@export var impact_effect: String = ""
@export var dinky_impact_effect: String = ""
@export var flash_radius: float = 10.0
@export var flash_color: Color = Color.WHITE

# Sounds
@export var launch_sound: String = ""
@export var impact_sound: String = ""
@export var disarmed_impact_sound: String = ""
@export var flyby_sound: String = ""

# Targeting and tracking
@export var target_lead_scaler: float = 1.0
@export var target_restrict: String = "none"  # ships, missiles, debris, etc.
@export var max_lock_range: float = 1000.0
@export var min_lock_range: float = 50.0
@export var lock_pixels_per_sec: int = 50

# Special weapon flags
@export var spawn_children: bool = false
@export var child_weapon: String = ""
@export var spawn_count: int = 1
@export var pierce_shields: bool = false
@export var no_dumbfire: bool = false
@export var in_tech_database: bool = true
@export var player_allowed: bool = true

# Ballistic properties (for projectile weapons)
@export var ballistic: bool = false
@export var pierce_armor: bool = false
@export var no_pierce_shields: bool = false
@export var local_ssm: bool = false
@export var tagged_only: bool = false

# Secondary weapon specific
@export var dual_fire: bool = false
@export var swarm_count: int = 1
@export var swarm_wait: float = 0.1

# EMP and special damage
@export var emp_intensity: float = 0.0
@export var emp_time: float = 0.0
@export var rearm_rate: float = 1.0
@export var weapon_range: float = 1000.0

# Countermeasures
@export var cmeasure_type: String = "none"  # chaff, flare, etc.
@export var cmeasure_effectiveness: float = 0.0

func _init() -> void:
	# Initialize default values
	pass

## Utility functions for weapon data

func is_primary_weapon() -> bool:
	"""Check if this is a primary weapon."""
	return subtype.to_lower() == "primary"

func is_secondary_weapon() -> bool:
	"""Check if this is a secondary/missile weapon."""
	return subtype.to_lower() == "secondary"

func is_homing_weapon() -> bool:
	"""Check if this weapon has homing capability."""
	return homing_type != "none" and turn_rate > 0.0

func is_ballistic_weapon() -> bool:
	"""Check if this is a ballistic projectile weapon."""
	return ballistic

func get_effective_range() -> float:
	"""Calculate effective weapon range based on velocity and lifetime."""
	return velocity * lifetime

func get_dps() -> float:
	"""Calculate damage per second."""
	if fire_wait <= 0:
		return 0.0
	return damage / fire_wait

func get_energy_efficiency() -> float:
	"""Calculate damage per energy unit."""
	if energy_consumed <= 0:
		return damage
	return damage / energy_consumed

func can_target(target_type: String) -> bool:
	"""Check if weapon can target specific object type."""
	if target_restrict == "none":
		return true
	
	var allowed_targets: PackedStringArray = target_restrict.split(",")
	return target_type.to_lower() in allowed_targets

func get_damage_vs_armor() -> float:
	"""Get effective damage against armor."""
	return damage * armor_factor

func get_damage_vs_shields() -> float:
	"""Get effective damage against shields."""
	return damage * shield_factor

func get_damage_vs_subsystems() -> float:
	"""Get effective damage against subsystems."""
	return damage * subsystem_factor

func has_area_effect() -> bool:
	"""Check if weapon has area-of-effect damage."""
	return blast_radius > 0.0

func get_threat_rating() -> float:
	"""Calculate weapon threat rating for AI evaluation."""
	var threat: float = damage
	
	# Factor in rate of fire
	threat *= (1.0 / max(0.1, fire_wait))
	
	# Factor in range
	threat *= min(1.0, get_effective_range() / 1000.0)
	
	# Homing weapons are more threatening
	if is_homing_weapon():
		threat *= 1.5
	
	# Area effect weapons are more dangerous
	if has_area_effect():
		threat *= (1.0 + blast_radius / 100.0)
	
	# Shield piercing is valuable
	if pierce_shields:
		threat *= 1.3
	
	return threat

func get_projectile_speed() -> float:
	"""Get projectile velocity in m/s."""
	return velocity

func get_time_to_target(distance: float) -> float:
	"""Calculate time for projectile to reach target at given distance."""
	if velocity <= 0:
		return -1.0
	return distance / velocity

func can_intercept_at_range(range: float) -> bool:
	"""Check if weapon can effectively engage at given range."""
	var max_range: float = get_effective_range()
	var min_range: float = min_lock_range if is_homing_weapon() else 0.0
	
	return range >= min_range and range <= max_range

func get_lock_time_at_range(range: float) -> float:
	"""Get lock time required at specific range (for homing weapons)."""
	if not is_homing_weapon():
		return 0.0
	
	if range > max_lock_range:
		return -1.0  # Cannot lock at this range
	
	# Lock time typically increases with range
	var range_factor: float = range / max_lock_range
	return lock_time * (0.5 + range_factor * 0.5)

func clone_with_overrides(overrides: Dictionary) -> WeaponData:
	"""Create a copy of this weapon data with specific property overrides."""
	var clone: WeaponData = WeaponData.new()
	
	# Copy all properties with overrides
	clone.weapon_name = overrides.get("weapon_name", weapon_name)
	clone.title = overrides.get("title", title)
	clone.subtype = overrides.get("subtype", subtype)
	clone.damage = overrides.get("damage", damage)
	clone.velocity = overrides.get("velocity", velocity)
	clone.fire_wait = overrides.get("fire_wait", fire_wait)
	clone.homing_type = overrides.get("homing_type", homing_type)
	clone.turn_rate = overrides.get("turn_rate", turn_rate)
	# ... (would copy all properties in real implementation)
	
	return clone

func to_debug_string() -> String:
	"""Get debug information about this weapon."""
	var debug_info: Array[String] = []
	
	debug_info.append("Weapon: %s (%s)" % [weapon_name, subtype])
	debug_info.append("Damage: %.1f, DPS: %.1f" % [damage, get_dps()])
	debug_info.append("Range: %.0fm, Speed: %.0fm/s" % [get_effective_range(), velocity])
	
	if is_homing_weapon():
		debug_info.append("Homing: %s (turn rate: %.1f°/s)" % [homing_type, turn_rate])
	
	if has_area_effect():
		debug_info.append("Blast radius: %.1fm" % blast_radius)
	
	debug_info.append("Energy cost: %.1f per shot" % energy_consumed)
	
	return "\n".join(debug_info)