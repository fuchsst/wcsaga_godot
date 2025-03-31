# scripts/resources/armor_data.gd
extends Resource
class_name ArmorData

## Armor Properties
@export var armor_name: String = "" # ArmorType.Name
@export var flags: int = 0 # ArmorType.flags (e.g., SAF_IGNORE_SS_ARMOR)

## Damage Resistances
# Dictionary mapping damage type index (int) or name (String) to resistance multiplier (float).
# Example: { 0: 0.8, "Energy": 0.5 }
# A multiplier of 1.0 means no resistance, 0.5 means 50% damage taken, 0.0 means immune.
@export var damage_resistances: Dictionary = {} # ArmorType.DamageTypes -> ArmorType.GetDamage() logic

## Shield Piercing Properties (Relevant if used for shields)
# Dictionary mapping damage type index (int) or name (String) to shield pierce percentage (float, 0.0 to 1.0).
@export var shield_pierce_percentages: Dictionary = {} # ArmorType.GetShieldPiercePCT()

# Dictionary mapping damage type index (int) or name (String) to piercing type (int, SADTF_* constants).
@export var piercing_types: Dictionary = {} # ArmorType.GetPiercingType()

# Dictionary mapping damage type index (int) or name (String) to piercing limit (float, percentage).
@export var piercing_limits: Dictionary = {} # ArmorType.GetPiercingLimit()

# Note: The original C++ used complex calculations within ArmorDamageType.
# For simplicity, we might initially store direct resistance multipliers.
# If the calculation logic is needed, it might require helper functions here
# or within the DamageSystem.

# Helper function to get damage multiplier for a given damage type index/name
func get_damage_multiplier(damage_type_key) -> float:
	if damage_resistances.has(damage_type_key):
		return damage_resistances[damage_type_key]
	# Default resistance if not specified (can be adjusted)
	return 1.0

# Helper function to get shield pierce percentage
func get_shield_pierce_percentage(damage_type_key) -> float:
	if shield_pierce_percentages.has(damage_type_key):
		return shield_pierce_percentages[damage_type_key]
	return 0.0 # Default: no piercing

# Helper function to get piercing type
func get_piercing_type(damage_type_key) -> int:
	if piercing_types.has(damage_type_key):
		return piercing_types[damage_type_key]
	# Default piercing type (adjust as needed, e.g., SADTF_PIERCING_DEFAULT)
	return 1

# Helper function to get piercing limit
func get_piercing_limit(damage_type_key) -> float:
	if piercing_limits.has(damage_type_key):
		return piercing_limits[damage_type_key]
	# Default limit (adjust as needed)
	return 0.0
