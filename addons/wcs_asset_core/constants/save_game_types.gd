class_name SaveGameTypes
extends RefCounted

## Save game type constants for WCS-Godot conversion
## Defines save system categories and data organization
## Based on WCS save system analysis

# Save data categories
enum Category {
	PLAYER_PROFILE = 0,    # Player profile and settings
	CAMPAIGN_STATE = 1,    # Campaign progress and variables
	MISSION_STATE = 2,     # Current mission state
	SHIP_STATE = 3,        # Ship configurations and damage
	WEAPON_STATE = 4,      # Weapon configurations and ammunition
	SUBSYSTEM_STATE = 5,   # Subsystem damage and performance
	DAMAGE_STATE = 6,      # Hull and shield damage data
	INVENTORY_STATE = 7,   # Player inventory and equipment
	STATISTICS = 8,        # Game statistics and records
	SETTINGS = 9,          # Game settings and preferences
	DEBUG_DATA = 10        # Debug information
}

# Save priority levels
enum Priority {
	CRITICAL = 0,    # Must be saved immediately
	HIGH = 1,        # Should be saved frequently
	MEDIUM = 2,      # Can be saved periodically
	LOW = 3,         # Save when convenient
	DEBUG = 4        # Only save in debug mode
}

# Save compression levels
enum Compression {
	NONE = 0,        # No compression
	LIGHT = 1,       # Light compression for speed
	MEDIUM = 2,      # Balanced compression
	HEAVY = 3,       # Maximum compression
	ADAPTIVE = 4     # Adaptive based on data size
}

# Save validation levels
enum Validation {
	NONE = 0,        # No validation
	BASIC = 1,       # Basic structure validation
	STANDARD = 2,    # Standard validation checks
	STRICT = 3,      # Strict validation with integrity
	PARANOID = 4     # Maximum validation with checksums
}

# Category names for display
const CATEGORY_NAMES: Array[String] = [
	"Player Profile",
	"Campaign State",
	"Mission State",
	"Ship State",
	"Weapon State",
	"Subsystem State",
	"Damage State",
	"Inventory State",
	"Statistics",
	"Settings",
	"Debug Data"
]

# Priority names
const PRIORITY_NAMES: Array[String] = [
	"Critical",
	"High",
	"Medium",
	"Low",
	"Debug"
]

# Compression names
const COMPRESSION_NAMES: Array[String] = [
	"None",
	"Light",
	"Medium",
	"Heavy",
	"Adaptive"
]

# Validation names
const VALIDATION_NAMES: Array[String] = [
	"None",
	"Basic",
	"Standard", 
	"Strict",
	"Paranoid"
]

# Default save configuration by category
const DEFAULT_CONFIGURATIONS: Dictionary = {
	Category.PLAYER_PROFILE: {
		"priority": Priority.HIGH,
		"compression": Compression.LIGHT,
		"validation": Validation.STANDARD,
		"auto_save": true,
		"backup_count": 3
	},
	Category.CAMPAIGN_STATE: {
		"priority": Priority.CRITICAL,
		"compression": Compression.MEDIUM,
		"validation": Validation.STRICT,
		"auto_save": true,
		"backup_count": 5
	},
	Category.MISSION_STATE: {
		"priority": Priority.CRITICAL,
		"compression": Compression.LIGHT,
		"validation": Validation.STRICT,
		"auto_save": true,
		"backup_count": 2
	},
	Category.SHIP_STATE: {
		"priority": Priority.HIGH,
		"compression": Compression.MEDIUM,
		"validation": Validation.STANDARD,
		"auto_save": true,
		"backup_count": 3
	},
	Category.WEAPON_STATE: {
		"priority": Priority.HIGH,
		"compression": Compression.MEDIUM,
		"validation": Validation.STANDARD,
		"auto_save": true,
		"backup_count": 2
	},
	Category.SUBSYSTEM_STATE: {
		"priority": Priority.HIGH,
		"compression": Compression.MEDIUM,
		"validation": Validation.STANDARD,
		"auto_save": true,
		"backup_count": 2
	},
	Category.DAMAGE_STATE: {
		"priority": Priority.HIGH,
		"compression": Compression.MEDIUM,
		"validation": Validation.STANDARD,
		"auto_save": true,
		"backup_count": 2
	},
	Category.INVENTORY_STATE: {
		"priority": Priority.MEDIUM,
		"compression": Compression.LIGHT,
		"validation": Validation.BASIC,
		"auto_save": false,
		"backup_count": 1
	},
	Category.STATISTICS: {
		"priority": Priority.LOW,
		"compression": Compression.HEAVY,
		"validation": Validation.BASIC,
		"auto_save": false,
		"backup_count": 1
	},
	Category.SETTINGS: {
		"priority": Priority.MEDIUM,
		"compression": Compression.NONE,
		"validation": Validation.BASIC,
		"auto_save": false,
		"backup_count": 2
	},
	Category.DEBUG_DATA: {
		"priority": Priority.DEBUG,
		"compression": Compression.NONE,
		"validation": Validation.NONE,
		"auto_save": false,
		"backup_count": 0
	}
}

## Get category name
static func get_category_name(category: Category) -> String:
	"""Get human-readable name for save category."""
	var index: int = category as int
	if index >= 0 and index < CATEGORY_NAMES.size():
		return CATEGORY_NAMES[index]
	return "Unknown"

## Get priority name
static func get_priority_name(priority: Priority) -> String:
	"""Get human-readable name for save priority."""
	var index: int = priority as int
	if index >= 0 and index < PRIORITY_NAMES.size():
		return PRIORITY_NAMES[index]
	return "Unknown"

## Get compression name
static func get_compression_name(compression: Compression) -> String:
	"""Get human-readable name for compression level."""
	var index: int = compression as int
	if index >= 0 and index < COMPRESSION_NAMES.size():
		return COMPRESSION_NAMES[index]
	return "Unknown"

## Get validation name
static func get_validation_name(validation: Validation) -> String:
	"""Get human-readable name for validation level."""
	var index: int = validation as int
	if index >= 0 and index < VALIDATION_NAMES.size():
		return VALIDATION_NAMES[index]
	return "Unknown"

## Get default configuration for category
static func get_default_configuration(category: Category) -> Dictionary:
	"""Get default save configuration for category."""
	return DEFAULT_CONFIGURATIONS.get(category, {})

## Check if category should auto-save
static func should_auto_save(category: Category) -> bool:
	"""Check if category should auto-save by default."""
	var config: Dictionary = get_default_configuration(category)
	return config.get("auto_save", false)

## Get default backup count for category
static func get_default_backup_count(category: Category) -> int:
	"""Get default backup count for category."""
	var config: Dictionary = get_default_configuration(category)
	return config.get("backup_count", 0)

## Check if category is critical priority
static func is_critical_priority(category: Category) -> bool:
	"""Check if category has critical save priority."""
	var config: Dictionary = get_default_configuration(category)
	return config.get("priority", Priority.LOW) == Priority.CRITICAL