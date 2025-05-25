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

# Advanced WCS properties
@export var type_data: Dictionary = {}  # Ship type specific data
@export var ship_type: int = 0  # WCS ship type constant
@export var maneuverability: Vector3 = Vector3(1, 1, 1)  # Pitch, yaw, roll multipliers
@export var acceleration: Vector3 = Vector3(10, 10, 10)  # Acceleration rates
@export var velocity_glide_cap: float = 0.0  # Glide velocity cap
@export var rotation_glide_cap: float = 0.0  # Rotation glide cap
@export var glide_accel_mult: float = 1.0  # Glide acceleration multiplier
@export var glide_cap_after_weapon_fire: float = 0.0

# Energy and power management
@export var power_output: float = 100.0  # Total power output
@export var max_oclk_speed: float = 100.0  # Overclocked speed
@export var max_weapon_energy: float = 100.0  # Maximum weapon energy pool
@export var afterburner_consume: float = 1.0  # Afterburner fuel consumption rate
@export var afterburner_vel_mult: float = 1.3  # Afterburner velocity multiplier
@export var afterburner_rec_delay: float = 2.0  # Recovery delay after afterburner
@export var afterburner_fuel_capacity: float = 100.0  # Afterburner fuel capacity

# Shield system properties
@export var shield_quadrants: Array[float] = [25.0, 25.0, 25.0, 25.0]  # Shield quadrant strengths
@export var shield_recharge_rate: float = 10.0  # Shield recharge per second
@export var shield_low_warn: float = 0.25  # Low shield warning threshold
@export var shield_depletion_warn: float = 0.1  # Shield depletion warning
@export var auto_shield_spread: bool = true  # Auto-spread shields when damaged

# Hull and armor
@export var hull_repair_rate: float = 0.0  # Hull self-repair rate
@export var hull_strength_factor: float = 1.0  # Hull strength multiplier
@export var armor_type: String = "standard"  # Armor classification

# Special flags from WCS
@export var no_collide: bool = false
@export var player_ship: bool = false
@export var default_player_ship: bool = false
@export var ship_copy: String = ""  # For ship inheritance
@export var multi_mod: String = ""
@export var big_ship: bool = false  # Capital ship classification
@export var huge_ship: bool = false  # Super capital classification
@export var corvette_ship: bool = false  # Corvette classification
@export var gas_miner: bool = false  # Gas mining ship
@export var awacs: bool = false  # AWACS capability
@export var sentrygun: bool = false  # Sentry gun
@export var escapepod: bool = false  # Escape pod
@export var stealth: bool = false  # Stealth capability
@export var supercap: bool = false  # Super capital ship
@export var drydock: bool = false  # Drydock facility
@export var cruiser: bool = false  # Cruiser classification
@export var freighter: bool = false  # Freighter/transport
@export var transport: bool = false  # Transport ship
@export var bomber: bool = false  # Bomber classification
@export var interceptor: bool = false  # Interceptor classification
@export var fighter: bool = false  # Fighter classification
@export var support: bool = false  # Support ship
@export var no_ship_type: bool = false  # Disable ship type
@export var ship_class_type_multiplayer: String = ""  # MP specific type
@export var auto_repair: bool = false  # Auto-repair capability
@export var disable_built_in_ship: bool = false  # Disable built-in ship
@export var red_alert_carry: bool = false  # Carry over red alert status

# Performance and rendering
@export var detail_levels: int = 3
@export var debris_min_lifetime: float = 1.0
@export var debris_max_lifetime: float = 10.0
@export var debris_min_speed: float = 10.0
@export var debris_max_speed: float = 100.0
@export var debris_min_rotspeed: float = 1.0
@export var debris_max_rotspeed: float = 5.0
@export var density_factor: float = 1.0  # Density scaling factor
@export var surface_shields: float = 0.0  # Surface shield strength

# Countermeasures
@export var cmeasure_type: String = ""  # Default countermeasure type
@export var cmeasure_max: int = 0  # Maximum countermeasures
@export var cmeasure_fire_wait: float = 1.0  # Countermeasure fire delay

# Warpin and warpout effects
@export var warpin_params_start: float = 0.0  # Warpin start distance
@export var warpin_params_end: float = 0.0  # Warpin end distance
@export var warpin_time: float = 3.0  # Warpin duration
@export var warpout_params_start: float = 0.0  # Warpout start distance  
@export var warpout_params_end: float = 0.0  # Warpout end distance
@export var warpout_time: float = 3.0  # Warpout duration
@export var warpin_type: int = 0  # Warpin effect type
@export var warpout_type: int = 0  # Warpout effect type

# Shockwave properties
@export var shockwave_info_inner_rad: float = 0.0  # Inner shockwave radius
@export var shockwave_info_outer_rad: float = 0.0  # Outer shockwave radius
@export var shockwave_info_damage: float = 0.0  # Shockwave damage
@export var shockwave_info_blast: float = 0.0  # Shockwave blast force
@export var shockwave_info_speed: float = 0.0  # Shockwave expansion speed
@export var shockwave_info_rot_angle: float = 0.0  # Shockwave rotation

# Explosion properties
@export var explosion_propagates: bool = false  # Chain explosions
@export var explosion_bitmap_anims: Array[String] = []  # Explosion animations
@export var vaporize_chance: float = 0.0  # Chance to vaporize instead of explode

# Bay doors and cargo
@export var bay_doors: Array[Dictionary] = []  # Bay door definitions
@export var cargo_holds: Array[Dictionary] = []  # Cargo hold definitions

# Special systems
@export var lightning_arc_bitmap: String = ""  # Lightning arc effect
@export var select_picture: String = ""  # Ship selection image
@export var team_coloration: Array[Color] = []  # Team color options
@export var thruster_secondary: Array[Dictionary] = []  # Secondary thrusters

# Radar and targeting
@export var radar_image_2d: String = ""  # 2D radar image
@export var radar_color_image_2d: String = ""  # Colored radar image
@export var radar_image_size: int = 64  # Radar image size
@export var ship_iff: int = 0  # IFF classification
@export var radar_projection_size_mult: float = 1.0  # Radar size multiplier

# AI behavior parameters
@export var ai_actively_pursues: Array[String] = []  # Ships this AI pursues
@export var ai_actively_pursues_temp: Array[String] = []  # Temporary pursue list
@export var ai_auto_attacks: bool = true  # Auto-attack capability
@export var ai_attempt_broadside: bool = false  # Broadside attack preference
@export var ai_guards: bool = true  # Can guard other ships
@export var ai_turrets_prioritize_armed_target: bool = true
@export var ai_big_ship_turrets_attack_armed: bool = true
@export var ai_path_fixup: bool = true  # Path correction
@export var ai_chase_big_ships: bool = false  # Chase large ships
@export var ai_turret_max_target_ownage: float = 1.0
@export var ai_big_ship_turrets_attack_unarmed: bool = false
@export var ai_targeted_by_huge_ignored_by_small_only: bool = false

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
	return afterburner_fuel_capacity > 0.0 and not afterburner_snd.is_empty()

func get_afterburner_max_vel() -> Vector3:
	"""Get maximum afterburner velocity."""
	return max_vel * afterburner_vel_mult

func get_shield_total() -> float:
	"""Get total shield strength across all quadrants."""
	var total: float = 0.0
	for quadrant_strength in shield_quadrants:
		total += quadrant_strength
	return total

func get_shield_quadrant_strength(quadrant: int) -> float:
	"""Get shield strength for specific quadrant (0-3)."""
	if quadrant < 0 or quadrant >= shield_quadrants.size():
		return 0.0
	return shield_quadrants[quadrant]

func is_capital_class() -> bool:
	"""Check if this is any kind of capital ship."""
	return big_ship or huge_ship or supercap or cruiser or corvette_ship

func is_small_craft() -> bool:
	"""Check if this is a small fighter-type craft."""
	return fighter or interceptor or bomber or escapepod

func get_ship_class_flags() -> Array[String]:
	"""Get list of all active ship class flags."""
	var flags: Array[String] = []
	
	if fighter: flags.append("fighter")
	if interceptor: flags.append("interceptor")
	if bomber: flags.append("bomber")
	if corvette_ship: flags.append("corvette")
	if cruiser: flags.append("cruiser")
	if big_ship: flags.append("big_ship")
	if huge_ship: flags.append("huge_ship")
	if supercap: flags.append("supercap")
	if freighter: flags.append("freighter")
	if transport: flags.append("transport")
	if support: flags.append("support")
	if stealth: flags.append("stealth")
	if awacs: flags.append("awacs")
	if sentrygun: flags.append("sentrygun")
	if escapepod: flags.append("escapepod")
	if gas_miner: flags.append("gas_miner")
	if drydock: flags.append("drydock")
	
	return flags

func get_power_distribution() -> Vector3:
	"""Get current ETS (Engine/Shields/Weapons) power distribution."""
	return max_ets

func get_maneuverability_rating() -> float:
	"""Get overall maneuverability rating."""
	var total_turn_rate: float = (360.0 / rotation_time.x) + (360.0 / rotation_time.y) + (360.0 / rotation_time.z)
	var avg_maneuver: float = (maneuverability.x + maneuverability.y + maneuverability.z) / 3.0
	return (total_turn_rate / 3.0) * avg_maneuver

func can_dock() -> bool:
	"""Check if ship has docking capability."""
	return fighter_bay or bay_doors.size() > 0

func has_fighter_bay() -> bool:
	"""Check if ship can launch fighters."""
	return fighter_bay and fighter_bay_doors.size() > 0

func get_countermeasure_capacity() -> int:
	"""Get maximum countermeasure capacity."""
	return cmeasure_max

func has_stealth() -> bool:
	"""Check if ship has stealth capability."""
	return stealth

func has_awacs() -> bool:
	"""Check if ship has AWACS capability."""
	return awacs

func get_explosion_damage() -> float:
	"""Get damage from ship explosion."""
	return shockwave_info_damage

func get_explosion_radius() -> float:
	"""Get radius of ship explosion."""
	return shockwave_info_outer_rad

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
	
	# Power output affects threat
	threat += power_output * 0.02
	
	# Ship type modifiers using WCS flags
	if fighter or interceptor:
		threat *= 1.0
	elif bomber:
		threat *= 1.3
	elif corvette_ship:
		threat *= 1.5
	elif cruiser:
		threat *= 2.0
	elif huge_ship or supercap:
		threat *= 3.0
	elif big_ship:
		threat *= 2.5
	elif freighter or transport:
		threat *= 0.5
	elif support:
		threat *= 0.3
	
	# Special capability modifiers
	if stealth:
		threat *= 1.4
	if awacs:
		threat *= 1.2
	if sentrygun:
		threat *= 0.8
	
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