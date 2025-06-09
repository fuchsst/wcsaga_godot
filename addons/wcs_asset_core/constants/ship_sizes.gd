class_name ShipSizes
extends RefCounted

## Ship size classifications for WCS-Godot conversion
## Defines ship categories based on scale, mass, and tactical role
## Used for collision detection, targeting, and combat mechanics

# Ship size categories from smallest to largest
enum Size {
	FIGHTER = 0,     # Small, agile single-seat craft
	BOMBER = 1,      # Heavy fighters with anti-capital capability
	CORVETTE = 2,    # Light capital ships, patrol craft
	FRIGATE = 3,     # Medium warships, escort vessels
	DESTROYER = 4,   # Heavy warships, main fleet units
	CRUISER = 5,     # Large capital ships, fleet command
	BATTLESHIP = 6,  # Massive warships, heavy assault
	CAPITAL = 7      # Supercapital ships, flagships
}

# Ship size display names
const SIZE_NAMES: Array[String] = [
	"Fighter",
	"Bomber", 
	"Corvette",
	"Frigate",
	"Destroyer",
	"Cruiser",
	"Battleship",
	"Capital Ship"
]

# Size-based properties for game mechanics
const SIZE_PROPERTIES: Dictionary = {
	Size.FIGHTER: {
		"length_range": [8.0, 25.0],      # Meters
		"mass_range": [5.0, 50.0],        # Tons
		"crew_size": [1, 2],
		"max_subsystems": 8,
		"targeting_priority": 3,
		"evasion_bonus": 0.4,
		"shield_recharge_modifier": 1.2,
		"afterburner_efficiency": 1.5,
		"can_dock_with": ["CORVETTE", "FRIGATE", "DESTROYER", "CRUISER", "BATTLESHIP", "CAPITAL"]
	},
	Size.BOMBER: {
		"length_range": [20.0, 45.0],
		"mass_range": [40.0, 200.0],
		"crew_size": [1, 3],
		"max_subsystems": 12,
		"targeting_priority": 4,
		"evasion_bonus": 0.2,
		"shield_recharge_modifier": 1.0,
		"afterburner_efficiency": 1.2,
		"can_dock_with": ["FRIGATE", "DESTROYER", "CRUISER", "BATTLESHIP", "CAPITAL"]
	},
	Size.CORVETTE: {
		"length_range": [40.0, 100.0],
		"mass_range": [150.0, 800.0],
		"crew_size": [8, 25],
		"max_subsystems": 16,
		"targeting_priority": 5,
		"evasion_bonus": 0.1,
		"shield_recharge_modifier": 0.9,
		"afterburner_efficiency": 1.0,
		"can_dock_with": ["DESTROYER", "CRUISER", "BATTLESHIP", "CAPITAL"]
	},
	Size.FRIGATE: {
		"length_range": [80.0, 200.0],
		"mass_range": [500.0, 3000.0],
		"crew_size": [20, 100],
		"max_subsystems": 20,
		"targeting_priority": 6,
		"evasion_bonus": 0.05,
		"shield_recharge_modifier": 0.8,
		"afterburner_efficiency": 0.8,
		"can_dock_with": ["CRUISER", "BATTLESHIP", "CAPITAL"]
	},
	Size.DESTROYER: {
		"length_range": [150.0, 400.0],
		"mass_range": [2000.0, 15000.0],
		"crew_size": [80, 300],
		"max_subsystems": 25,
		"targeting_priority": 7,
		"evasion_bonus": 0.0,
		"shield_recharge_modifier": 0.7,
		"afterburner_efficiency": 0.6,
		"can_dock_with": ["BATTLESHIP", "CAPITAL"]
	},
	Size.CRUISER: {
		"length_range": [300.0, 800.0],
		"mass_range": [10000.0, 50000.0],
		"crew_size": [200, 800],
		"max_subsystems": 30,
		"targeting_priority": 8,
		"evasion_bonus": -0.1,
		"shield_recharge_modifier": 0.6,
		"afterburner_efficiency": 0.4,
		"can_dock_with": ["CAPITAL"]
	},
	Size.BATTLESHIP: {
		"length_range": [600.0, 1500.0],
		"mass_range": [40000.0, 200000.0],
		"crew_size": [600, 2000],
		"max_subsystems": 35,
		"targeting_priority": 9,
		"evasion_bonus": -0.2,
		"shield_recharge_modifier": 0.5,
		"afterburner_efficiency": 0.2,
		"can_dock_with": []
	},
	Size.CAPITAL: {
		"length_range": [1200.0, 5000.0],
		"mass_range": [150000.0, 1000000.0],
		"crew_size": [1500, 10000],
		"max_subsystems": 40,
		"targeting_priority": 10,
		"evasion_bonus": -0.3,
		"shield_recharge_modifier": 0.4,
		"afterburner_efficiency": 0.1,
		"can_dock_with": []
	}
}

# Collision and physics modifiers by size
const COLLISION_MODIFIERS: Dictionary = {
	Size.FIGHTER: {
		"collision_damage_modifier": 0.5,
		"ramming_damage_dealt": 0.3,
		"ramming_damage_taken": 2.0,
		"debris_count": [1, 3],
		"explosion_scale": 0.5
	},
	Size.BOMBER: {
		"collision_damage_modifier": 0.7,
		"ramming_damage_dealt": 0.5,
		"ramming_damage_taken": 1.5,
		"debris_count": [2, 5],
		"explosion_scale": 0.7
	},
	Size.CORVETTE: {
		"collision_damage_modifier": 1.0,
		"ramming_damage_dealt": 0.8,
		"ramming_damage_taken": 1.2,
		"debris_count": [3, 8],
		"explosion_scale": 1.0
	},
	Size.FRIGATE: {
		"collision_damage_modifier": 1.5,
		"ramming_damage_dealt": 1.2,
		"ramming_damage_taken": 1.0,
		"debris_count": [5, 12],
		"explosion_scale": 1.5
	},
	Size.DESTROYER: {
		"collision_damage_modifier": 2.0,
		"ramming_damage_dealt": 1.8,
		"ramming_damage_taken": 0.8,
		"debris_count": [8, 20],
		"explosion_scale": 2.0
	},
	Size.CRUISER: {
		"collision_damage_modifier": 3.0,
		"ramming_damage_dealt": 2.5,
		"ramming_damage_taken": 0.6,
		"debris_count": [12, 30],
		"explosion_scale": 3.0
	},
	Size.BATTLESHIP: {
		"collision_damage_modifier": 4.0,
		"ramming_damage_dealt": 4.0,
		"ramming_damage_taken": 0.4,
		"debris_count": [20, 50],
		"explosion_scale": 4.0
	},
	Size.CAPITAL: {
		"collision_damage_modifier": 6.0,
		"ramming_damage_dealt": 6.0,
		"ramming_damage_taken": 0.2,
		"debris_count": [30, 80],
		"explosion_scale": 6.0
	}
}

## Get ship size name
static func get_size_name(size: Size) -> String:
	"""Get human-readable name for ship size."""
	var index: int = size as int
	if index >= 0 and index < SIZE_NAMES.size():
		return SIZE_NAMES[index]
	return "Unknown"

## Get size properties
static func get_size_properties(size: Size) -> Dictionary:
	"""Get properties dictionary for ship size."""
	return SIZE_PROPERTIES.get(size, {})

## Get collision modifiers
static func get_collision_modifiers(size: Size) -> Dictionary:
	"""Get collision and physics modifiers for ship size."""
	return COLLISION_MODIFIERS.get(size, {})

## Check if size is capital ship
static func is_capital_ship(size: Size) -> bool:
	"""Check if ship size qualifies as capital ship."""
	return size >= Size.CORVETTE

## Check if size is fighter class
static func is_fighter_class(size: Size) -> bool:
	"""Check if ship size is fighter or bomber class."""
	return size <= Size.BOMBER

## Check if size can be carried
static func can_be_carried(size: Size) -> bool:
	"""Check if ships of this size can be carried in hangars."""
	return size <= Size.BOMBER

## Get targeting priority
static func get_targeting_priority(size: Size) -> int:
	"""Get targeting priority for AI systems (higher = more important target)."""
	var properties: Dictionary = get_size_properties(size)
	return properties.get("targeting_priority", 5)

## Get evasion bonus
static func get_evasion_bonus(size: Size) -> float:
	"""Get evasion modifier for combat calculations."""
	var properties: Dictionary = get_size_properties(size)
	return properties.get("evasion_bonus", 0.0)

## Check docking compatibility
static func can_dock_with(size: Size, dock_target_size: Size) -> bool:
	"""Check if ship of given size can dock with target ship size."""
	var properties: Dictionary = get_size_properties(size)
	var dock_list: Array = properties.get("can_dock_with", [])
	var target_name: String = get_size_name(dock_target_size).to_upper()
	return target_name in dock_list

## Get size by length
static func get_size_by_length(length: float) -> Size:
	"""Determine ship size category based on length in meters."""
	for size in Size.values():
		var properties: Dictionary = get_size_properties(size)
		var length_range: Array = properties.get("length_range", [0.0, 0.0])
		if length >= length_range[0] and length <= length_range[1]:
			return size
	return Size.CAPITAL  # Default to capital for oversized ships

## Get size by mass
static func get_size_by_mass(mass: float) -> Size:
	"""Determine ship size category based on mass in tons."""
	for size in Size.values():
		var properties: Dictionary = get_size_properties(size)
		var mass_range: Array = properties.get("mass_range", [0.0, 0.0])
		if mass >= mass_range[0] and mass <= mass_range[1]:
			return size
	return Size.CAPITAL  # Default to capital for super-heavy ships

## Get all ship sizes
static func get_all_sizes() -> Array[int]:
	"""Get array of all ship size IDs."""
	var sizes: Array[int] = []
	for i in range(Size.size()):
		sizes.append(i)
	return sizes

## Get size range info
static func get_size_range_info() -> Dictionary:
	"""Get summary of all size ranges for validation."""
	var info: Dictionary = {}
	for size in Size.values():
		var properties: Dictionary = get_size_properties(size)
		info[get_size_name(size)] = {
			"length_range": properties.get("length_range", [0.0, 0.0]),
			"mass_range": properties.get("mass_range", [0.0, 0.0]),
			"crew_range": properties.get("crew_size", [0, 0])
		}
	return info