class_name ShieldTypes
extends RefCounted

## Shield type constants for WCS-Godot conversion
## Defines shield classifications and quadrant properties
## Based on WCS shield system analysis

# Shield generator types
enum GeneratorType {
	BASIC = 0,        # Basic shield generator
	ADVANCED = 1,     # Advanced shield generator
	MILITARY = 2,     # Military-grade generator
	CAPITAL = 3,      # Capital ship generator
	REGENERATIVE = 4, # Self-repairing generator
	ADAPTIVE = 5      # Adaptive frequency generator
}

# Shield quadrant configuration types
enum QuadrantType {
	BALANCED = 0,     # Equal quadrant distribution
	FRONT_HEAVY = 1,  # Front-focused distribution
	REAR_HEAVY = 2,   # Rear-focused distribution
	SIDE_HEAVY = 3,   # Side-focused distribution
	CUSTOM = 4        # Custom distribution
}

# Shield resistance types
enum ResistanceType {
	STANDARD = 0,     # Standard shield resistance
	ENERGY_FOCUSED = 1, # Enhanced energy resistance
	KINETIC_FOCUSED = 2, # Enhanced kinetic resistance
	BALANCED = 3,     # Balanced resistance
	ADAPTIVE = 4      # Adaptive resistance
}

# Shield generator names for display
const GENERATOR_TYPE_NAMES: Array[String] = [
	"Basic",
	"Advanced",
	"Military",
	"Capital",
	"Regenerative",
	"Adaptive"
]

# Quadrant configuration names
const QUADRANT_TYPE_NAMES: Array[String] = [
	"Balanced",
	"Front-Heavy",
	"Rear-Heavy", 
	"Side-Heavy",
	"Custom"
]

# Resistance type names
const RESISTANCE_TYPE_NAMES: Array[String] = [
	"Standard",
	"Energy-Focused",
	"Kinetic-Focused",
	"Balanced",
	"Adaptive"
]

# Base shield properties by generator type
const GENERATOR_PROPERTIES: Dictionary = {
	GeneratorType.BASIC: {
		"base_strength": 50.0,
		"recharge_rate": 5.0,
		"recharge_delay": 4.0,
		"power_consumption": 1.0
	},
	GeneratorType.ADVANCED: {
		"base_strength": 80.0,
		"recharge_rate": 8.0,
		"recharge_delay": 3.5,
		"power_consumption": 1.5
	},
	GeneratorType.MILITARY: {
		"base_strength": 120.0,
		"recharge_rate": 10.0,
		"recharge_delay": 3.0,
		"power_consumption": 2.0
	},
	GeneratorType.CAPITAL: {
		"base_strength": 300.0,
		"recharge_rate": 20.0,
		"recharge_delay": 2.5,
		"power_consumption": 5.0
	},
	GeneratorType.REGENERATIVE: {
		"base_strength": 100.0,
		"recharge_rate": 12.0,
		"recharge_delay": 2.0,
		"power_consumption": 2.5
	},
	GeneratorType.ADAPTIVE: {
		"base_strength": 90.0,
		"recharge_rate": 9.0,
		"recharge_delay": 3.0,
		"power_consumption": 2.2
	}
}

# Quadrant distribution patterns (Front, Rear, Left, Right)
const QUADRANT_DISTRIBUTIONS: Dictionary = {
	QuadrantType.BALANCED: [0.25, 0.25, 0.25, 0.25],
	QuadrantType.FRONT_HEAVY: [0.4, 0.2, 0.2, 0.2],
	QuadrantType.REAR_HEAVY: [0.2, 0.4, 0.2, 0.2],
	QuadrantType.SIDE_HEAVY: [0.2, 0.2, 0.3, 0.3]
}

## Get generator type name
static func get_generator_type_name(generator_type: GeneratorType) -> String:
	"""Get human-readable name for shield generator type."""
	var index: int = generator_type as int
	if index >= 0 and index < GENERATOR_TYPE_NAMES.size():
		return GENERATOR_TYPE_NAMES[index]
	return "Unknown"

## Get quadrant type name
static func get_quadrant_type_name(quadrant_type: QuadrantType) -> String:
	"""Get human-readable name for quadrant configuration type."""
	var index: int = quadrant_type as int
	if index >= 0 and index < QUADRANT_TYPE_NAMES.size():
		return QUADRANT_TYPE_NAMES[index]
	return "Unknown"

## Get resistance type name
static func get_resistance_type_name(resistance_type: ResistanceType) -> String:
	"""Get human-readable name for resistance type."""
	var index: int = resistance_type as int
	if index >= 0 and index < RESISTANCE_TYPE_NAMES.size():
		return RESISTANCE_TYPE_NAMES[index]
	return "Unknown"

## Get generator properties
static func get_generator_properties(generator_type: GeneratorType) -> Dictionary:
	"""Get properties for shield generator type."""
	return GENERATOR_PROPERTIES.get(generator_type, {})

## Get quadrant distribution
static func get_quadrant_distribution(quadrant_type: QuadrantType) -> Array[float]:
	"""Get quadrant distribution pattern for configuration type."""
	return QUADRANT_DISTRIBUTIONS.get(quadrant_type, [0.25, 0.25, 0.25, 0.25])

## Check if generator type is military-grade
static func is_military_grade(generator_type: GeneratorType) -> bool:
	"""Check if generator type is military-grade."""
	return generator_type in [GeneratorType.MILITARY, GeneratorType.CAPITAL]

## Check if generator type has regenerative capabilities
static func has_regenerative_capability(generator_type: GeneratorType) -> bool:
	"""Check if generator type has regenerative capabilities."""
	return generator_type in [GeneratorType.REGENERATIVE, GeneratorType.ADAPTIVE]