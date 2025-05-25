class_name ShipData
extends Resource

## WCS Ship data resource containing all properties from ships.tbl
## Represents a ship class with combat stats, model info, and behavior data

@export var ship_name: String = ""
@export var ship_info: String = ""
@export var short_name: String = ""
@export var species: String = "Terran"

# Model and visual data
@export var model_file: String = ""
@export var mass: float = 100.0
@export var density: float = 1.0
@export var damp: float = 1.0
@export var rotdamp: float = 1.0
@export var max_vel: Vector3 = Vector3(50, 50, 50)
@export var rotation_time: Vector3 = Vector3(2, 2, 2)

# Combat statistics
@export var max_hull_strength: float = 100.0
@export var max_shield_strength: float = 50.0
@export var max_shield_recharge: float = 10.0
@export var shield_color: Color = Color.BLUE

# Power and engine systems
@export var max_weapon_reserve: float = 100.0
@export var weapon_recharge_rate: float = 20.0
@export var max_ets: Vector3 = Vector3(12, 12, 12)  # Engines, Shields, Weapons
@export var engine_snd: String = ""
@export var min_engine_vol: float = 0.1
@export var afterburner_snd: String = ""

# AI and behavior
@export var ai_class: String = ""
@export var scan_time: float = 2000.0
@export var ask_help_threshold: float = 0.7
@export var smart_shield_usage: bool = true
@export var big_damage_threshold: float = 50.0
@export var avoid_strength: float = 0.0

# Weapon systems
@export var allowed_weapons: Array[String] = []
@export var allowed_banks: Array[int] = []
@export var gun_mounts: Array[Vector3] = []
@export var missile_banks: Array[Vector3] = []

# Special systems and flags
@export var fighter_bay: bool = false
@export var fighter_bay_doors: Array[Vector3] = []
@export var cargo_space: float = 0.0
@export var ship_class_type: String = "fighter"  # fighter, bomber, cruiser, etc.

# Hitpoints and subsystems
@export var subsystems: Array[Dictionary] = []
@export var detail_distance: Array[float] = [0, 500, 1500]
@export var cockpit_model: String = ""
@export var cockpit_offset: Vector3 = Vector3.ZERO

# Thruster data
@export var thruster_flame_info: Array[Dictionary] = []
@export var thruster_glow_info: Array[Dictionary] = []

# Special flags from WCS
@export var no_collide: bool = false
@export var player_ship: bool = false
@export var default_player_ship: bool = false
@export var ship_copy: String = ""  # For ship inheritance
@export var multi_mod: String = ""

# Performance and rendering
@export var detail_levels: int = 3
@export var debris_min_lifetime: float = 1.0
@export var debris_max_lifetime: float = 10.0
@export var debris_min_speed: float = 10.0
@export var debris_max_speed: float = 100.0
@export var debris_min_rotspeed: float = 1.0
@export var debris_max_rotspeed: float = 5.0

func _init() -> void:
	# Set default values for arrays to prevent null reference errors
	if allowed_weapons.is_empty():
		allowed_weapons = []
	if allowed_banks.is_empty():
		allowed_banks = []
	if gun_mounts.is_empty():
		gun_mounts = []
	if missile_banks.is_empty():
		missile_banks = []
	if subsystems.is_empty():
		subsystems = []
	if detail_distance.is_empty():
		detail_distance = [0, 500, 1500]
	if thruster_flame_info.is_empty():
		thruster_flame_info = []
	if thruster_glow_info.is_empty():
		thruster_glow_info = []

## Utility functions for ship data

func get_max_speed() -> float:
	"""Get maximum forward speed."""
	return max_vel.z

func get_max_afterburner_speed() -> float:
	"""Get maximum afterburner speed (typically 150% of max speed)."""
	return max_vel.z * 1.5

func is_fighter_class() -> bool:
	"""Check if this is a fighter-class ship."""
	return ship_class_type.to_lower() in ["fighter", "interceptor", "space_superiority"]

func is_bomber_class() -> bool:
	"""Check if this is a bomber-class ship."""
	return ship_class_type.to_lower() in ["bomber", "assault"]

func is_capital_ship() -> bool:
	"""Check if this is a capital ship."""
	return ship_class_type.to_lower() in ["cruiser", "destroyer", "corvette", "freighter", "transport"]

func get_weapon_hardpoints() -> Array[Vector3]:
	"""Get all weapon mount positions."""
	var hardpoints: Array[Vector3] = []
	hardpoints.append_array(gun_mounts)
	hardpoints.append_array(missile_banks)
	return hardpoints

func get_shield_efficiency() -> float:
	"""Calculate shield recharge efficiency as percentage."""
	if max_shield_strength <= 0:
		return 0.0
	return (max_shield_recharge / max_shield_strength) * 100.0

func get_power_efficiency() -> float:
	"""Calculate weapon power efficiency as percentage."""
	if max_weapon_reserve <= 0:
		return 0.0
	return (weapon_recharge_rate / max_weapon_reserve) * 100.0

func get_turning_rate(axis: int) -> float:
	"""Get turning rate for specific axis (0=pitch, 1=yaw, 2=roll)."""
	if axis < 0 or axis >= 3:
		return 0.0
	return 360.0 / rotation_time[axis]  # degrees per second

func has_afterburner() -> bool:
	"""Check if ship has afterburner capability."""
	return not afterburner_snd.is_empty()

func get_subsystem_by_name(subsystem_name: String) -> Dictionary:
	"""Get subsystem data by name."""
	for subsys in subsystems:
		if subsys.get("name", "") == subsystem_name:
			return subsys
	return {}

func get_threat_level() -> float:
	"""Calculate relative threat level based on ship stats."""
	var threat: float = 0.0
	
	# Base threat from hull and shields
	threat += max_hull_strength * 0.5
	threat += max_shield_strength * 0.3
	
	# Weapon capacity factor
	threat += max_weapon_reserve * 0.1
	
	# Speed factor (faster = more dangerous)
	threat += get_max_speed() * 0.05
	
	# Class modifier
	match ship_class_type.to_lower():
		"fighter", "interceptor":
			threat *= 1.0
		"bomber", "assault":
			threat *= 1.2
		"corvette":
			threat *= 1.5
		"cruiser", "destroyer":
			threat *= 2.0
		"freighter", "transport":
			threat *= 0.5
	
	return threat

func clone_with_overrides(overrides: Dictionary) -> ShipData:
	"""Create a copy of this ship data with specific property overrides."""
	var clone: ShipData = ShipData.new()
	
	# Copy all properties
	clone.ship_name = overrides.get("ship_name", ship_name)
	clone.ship_info = overrides.get("ship_info", ship_info)
	clone.short_name = overrides.get("short_name", short_name)
	clone.species = overrides.get("species", species)
	clone.model_file = overrides.get("model_file", model_file)
	clone.mass = overrides.get("mass", mass)
	clone.max_hull_strength = overrides.get("max_hull_strength", max_hull_strength)
	clone.max_shield_strength = overrides.get("max_shield_strength", max_shield_strength)
	clone.max_vel = overrides.get("max_vel", max_vel)
	clone.ship_class_type = overrides.get("ship_class_type", ship_class_type)
	# ... (would copy all properties in real implementation)
	
	return clone

func to_debug_string() -> String:
	"""Get debug information about this ship."""
	var debug_info: Array[String] = []
	
	debug_info.append("Ship: %s (%s)" % [ship_name, ship_class_type])
	debug_info.append("Hull: %.0f, Shields: %.0f" % [max_hull_strength, max_shield_strength])
	debug_info.append("Speed: %.1f m/s, Mass: %.1f tons" % [get_max_speed(), mass])
	debug_info.append("Weapons: %d hardpoints" % get_weapon_hardpoints().size())
	debug_info.append("Model: %s" % model_file)
	
	return "\n".join(debug_info)