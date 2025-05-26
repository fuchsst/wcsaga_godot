class_name ShipClassData
extends AssetData

## Ship class data resource for WCS ship definitions.
## Contains all necessary information for ship classes including
## performance characteristics, faction affiliation, and loadout options.

@export var class_name: String = ""
@export var ship_type: String = ""
@export var faction: String = ""
@export var max_velocity: float = 0.0
@export var max_hull_strength: float = 0.0
@export var max_shield_strength: float = 0.0
@export var armor_type: String = ""
@export var shield_type: String = ""

# Weapon hardpoints
@export var primary_banks: int = 0
@export var secondary_banks: int = 0
@export var turret_slots: int = 0

# AI and behavior
@export var ai_class: String = ""
@export var ai_goals: Array[String] = []
@export var default_orders: String = ""

# Model and visual
@export var model_file: String = ""
@export var texture_files: Array[String] = []
@export var mass: float = 0.0
@export var collision_radius: float = 0.0

func _init() -> void:
	super()
	asset_type = "ship_class"
	class_name = ""
	ship_type = ""
	faction = ""
	max_velocity = 75.0
	max_hull_strength = 100.0
	max_shield_strength = 80.0
	armor_type = "Standard"
	shield_type = "Standard"
	primary_banks = 2
	secondary_banks = 2
	turret_slots = 0
	ai_class = "Fighter"
	ai_goals = []
	default_orders = "None"
	model_file = ""
	texture_files = []
	mass = 1000.0
	collision_radius = 10.0

## Get display name using class name if available
func get_display_name() -> String:
	return class_name if not class_name.is_empty() else asset_name

## Get ship type classification
func get_ship_type() -> String:
	return ship_type

## Get faction affiliation
func get_faction() -> String:
	return faction

## Get maximum velocity in m/s
func get_max_velocity() -> float:
	return max_velocity

## Get hull strength points
func get_hull_strength() -> float:
	return max_hull_strength

## Get shield strength points
func get_shield_strength() -> float:
	return max_shield_strength

## Check if this ship can carry fighters in bays
func has_fighter_bays() -> bool:
	return ship_type in ["Carrier", "Cruiser", "Destroyer"]

## Check if this ship is a capital ship
func is_capital_ship() -> bool:
	return ship_type in ["Cruiser", "Destroyer", "Carrier", "Freighter"]

## Check if this ship is a small craft
func is_small_craft() -> bool:
	return ship_type in ["Fighter", "Bomber", "Interceptor"]

## Get weapon bank configuration
func get_weapon_config() -> Dictionary:
	return {
		"primary_banks": primary_banks,
		"secondary_banks": secondary_banks,
		"turret_slots": turret_slots
	}

## Validate ship class data
func validate() -> Dictionary:
	var result: Dictionary = super.validate()
	
	if class_name.is_empty():
		result.is_valid = false
		result.errors.append("Ship class name cannot be empty")
	
	if ship_type.is_empty():
		result.is_valid = false
		result.errors.append("Ship type cannot be empty")
	
	if faction.is_empty():
		result.is_valid = false
		result.errors.append("Faction cannot be empty")
	
	if max_velocity <= 0.0:
		result.is_valid = false
		result.errors.append("Max velocity must be greater than 0")
	
	if max_hull_strength <= 0.0:
		result.is_valid = false
		result.errors.append("Hull strength must be greater than 0")
	
	if primary_banks < 0 or secondary_banks < 0 or turret_slots < 0:
		result.is_valid = false
		result.errors.append("Weapon bank counts cannot be negative")
	
	return result