class_name ShipClass
extends Resource

## Ship class definition resource for WCS-Godot conversion
## Defines ship properties, capabilities, and configuration data
## Based on WCS ship.tbl entries with Godot-native implementation

# Basic ship information
@export var class_name: String = ""
@export var short_name: String = ""
@export var display_name: String = ""
@export var species: String = "Terran"

# Ship type classification
@export var ship_type: int = 0  # ShipTypes.Type enum
@export var ship_size: int = 0  # Fighter, Bomber, Cruiser, Capital, etc.

# Physical properties
@export var mass: float = 1000.0
@export var moment_of_inertia: float = 2000.0
@export var max_velocity: float = 50.0
@export var max_afterburner_velocity: float = 100.0
@export var acceleration: float = 25.0
@export var angular_acceleration: float = 180.0

# Structural properties
@export var max_hull_strength: float = 100.0
@export var max_shield_strength: float = 100.0
@export var armor_type: String = ""

# Energy systems
@export var max_weapon_energy: float = 100.0
@export var weapon_energy_regen_rate: float = 2.0
@export var afterburner_fuel_capacity: float = 100.0
@export var afterburner_fuel_regen_rate: float = 1.0

# Combat properties
@export var max_weapon_banks: int = 4
@export var max_secondary_banks: int = 4
@export var primary_weapon_slots: Array[String] = []
@export var secondary_weapon_slots: Array[String] = []

# Model and visual properties
@export var model_path: String = ""
@export var texture_path: String = ""
@export var cockpit_model_path: String = ""
@export var detail_levels: Array[String] = []

# Engine properties
@export var engine_sound: String = ""
@export var engine_wash_info: String = ""
@export var thruster_glow_info: String = ""

# Special properties
@export var has_afterburner: bool = true
@export var has_shields: bool = true
@export var can_warp: bool = true
@export var stealth_capable: bool = false

# AI properties
@export var ai_class: String = "default"
@export var ai_behavior_flags: int = 0

# Manufacturing info
@export var manufacturer: String = ""
@export var tech_description: String = ""
@export var length: float = 0.0
@export var wingspan: float = 0.0
@export var height: float = 0.0

# Special flags and properties
@export var ship_flags: int = 0
@export var ship_flags2: int = 0

func _init() -> void:
	# Set default values
	resource_name = "ShipClass"

## Create a default fighter ship class for testing
static func create_default_fighter() -> ShipClass:
	var ship_class = ShipClass.new()
	ship_class.class_name = "Default Fighter"
	ship_class.short_name = "fighter"
	ship_class.display_name = "Default Fighter"
	ship_class.species = "Terran"
	
	# Physical properties for a typical fighter
	ship_class.mass = 500.0
	ship_class.moment_of_inertia = 1000.0
	ship_class.max_velocity = 75.0
	ship_class.max_afterburner_velocity = 150.0
	ship_class.acceleration = 30.0
	ship_class.angular_acceleration = 200.0
	
	# Structural properties
	ship_class.max_hull_strength = 80.0
	ship_class.max_shield_strength = 120.0
	
	# Energy systems
	ship_class.max_weapon_energy = 80.0
	ship_class.weapon_energy_regen_rate = 3.0
	ship_class.afterburner_fuel_capacity = 60.0
	ship_class.afterburner_fuel_regen_rate = 1.5
	
	# Combat properties
	ship_class.max_weapon_banks = 2
	ship_class.max_secondary_banks = 2
	
	return ship_class

## Create a default bomber ship class for testing
static func create_default_bomber() -> ShipClass:
	var ship_class = ShipClass.new()
	ship_class.class_name = "Default Bomber"
	ship_class.short_name = "bomber"
	ship_class.display_name = "Default Bomber"
	ship_class.species = "Terran"
	
	# Physical properties for a typical bomber
	ship_class.mass = 1200.0
	ship_class.moment_of_inertia = 2400.0
	ship_class.max_velocity = 45.0
	ship_class.max_afterburner_velocity = 90.0
	ship_class.acceleration = 20.0
	ship_class.angular_acceleration = 120.0
	
	# Structural properties
	ship_class.max_hull_strength = 150.0
	ship_class.max_shield_strength = 180.0
	
	# Energy systems
	ship_class.max_weapon_energy = 120.0
	ship_class.weapon_energy_regen_rate = 2.5
	ship_class.afterburner_fuel_capacity = 80.0
	ship_class.afterburner_fuel_regen_rate = 1.2
	
	# Combat properties
	ship_class.max_weapon_banks = 3
	ship_class.max_secondary_banks = 4
	
	return ship_class

## Create a default capital ship class for testing
static func create_default_capital() -> ShipClass:
	var ship_class = ShipClass.new()
	ship_class.class_name = "Default Capital"
	ship_class.short_name = "capital"
	ship_class.display_name = "Default Capital Ship"
	ship_class.species = "Terran"
	
	# Physical properties for a capital ship
	ship_class.mass = 50000.0
	ship_class.moment_of_inertia = 100000.0
	ship_class.max_velocity = 15.0
	ship_class.max_afterburner_velocity = 25.0
	ship_class.acceleration = 5.0
	ship_class.angular_acceleration = 30.0
	
	# Structural properties
	ship_class.max_hull_strength = 2500.0
	ship_class.max_shield_strength = 3000.0
	
	# Energy systems
	ship_class.max_weapon_energy = 500.0
	ship_class.weapon_energy_regen_rate = 5.0
	ship_class.afterburner_fuel_capacity = 200.0
	ship_class.afterburner_fuel_regen_rate = 2.0
	
	# Combat properties
	ship_class.max_weapon_banks = 8
	ship_class.max_secondary_banks = 6
	
	return ship_class

## Get ship type display name
func get_type_display_name() -> String:
	# This would use ShipTypes constants when available
	match ship_type:
		0: return "Fighter"
		1: return "Bomber"
		2: return "Cruiser"
		3: return "Capital"
		_: return "Unknown"

## Get total combat capability rating
func get_combat_rating() -> float:
	var hull_factor = max_hull_strength / 100.0
	var shield_factor = max_shield_strength / 100.0
	var weapon_factor = max_weapon_energy / 100.0
	var speed_factor = max_velocity / 50.0
	
	return (hull_factor + shield_factor + weapon_factor + speed_factor) / 4.0

## Check if ship has specific capability
func has_capability(capability: String) -> bool:
	match capability:
		"afterburner": return has_afterburner
		"shields": return has_shields
		"warp": return can_warp
		"stealth": return stealth_capable
		_: return false

## Get ship configuration summary
func get_config_summary() -> Dictionary:
	return {
		"class_name": class_name,
		"type": get_type_display_name(),
		"mass": mass,
		"max_speed": max_velocity,
		"afterburner_speed": max_afterburner_velocity,
		"hull": max_hull_strength,
		"shields": max_shield_strength,
		"weapon_energy": max_weapon_energy,
		"afterburner_fuel": afterburner_fuel_capacity,
		"primary_banks": max_weapon_banks,
		"secondary_banks": max_secondary_banks,
		"combat_rating": get_combat_rating()
	}