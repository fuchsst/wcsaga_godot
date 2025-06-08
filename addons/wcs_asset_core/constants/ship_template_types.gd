class_name ShipTemplateType
extends RefCounted

## Ship template type constants for WCS-Godot conversion
## Defines template categories and inheritance modes

# Template type enumeration
enum Type {
	VARIANT = 0,        # Ship variant with modified stats (e.g., GTF Apollo#Advanced)
	LOADOUT = 1,        # Weapon/equipment loadout configuration
	MISSION_SPECIFIC = 2, # Mission-specific ship configuration
	CUSTOM = 3,         # User-created custom template
	FACTION = 4,        # Faction-specific version (e.g., Shivan variants)
	CAMPAIGN = 5,       # Campaign progression variant
	PROTOTYPE = 6       # Experimental/prototype ships
}

# Inheritance mode for property overrides
enum InheritanceMode {
	OVERRIDE = 0,       # Override base properties completely
	ADDITIVE = 1,       # Add to base properties (for numerical values)
	MULTIPLICATIVE = 2, # Multiply base properties by modifier
	SELECTIVE = 3       # Override only specific properties
}

# Template validation levels
enum ValidationLevel {
	BASIC = 0,          # Basic name and path validation
	STRUCTURE = 1,      # Validate structure and required fields
	BALANCE = 2,        # Validate for game balance
	PERFORMANCE = 3     # Validate for performance impact
}

## Get display name for template type
static func get_type_name(template_type: Type) -> String:
	match template_type:
		Type.VARIANT: return "Ship Variant"
		Type.LOADOUT: return "Weapon Loadout"
		Type.MISSION_SPECIFIC: return "Mission Specific"
		Type.CUSTOM: return "Custom Template"
		Type.FACTION: return "Faction Variant"
		Type.CAMPAIGN: return "Campaign Variant"
		Type.PROTOTYPE: return "Prototype"
		_: return "Unknown"

## Get inheritance mode name
static func get_inheritance_mode_name(mode: InheritanceMode) -> String:
	match mode:
		InheritanceMode.OVERRIDE: return "Override"
		InheritanceMode.ADDITIVE: return "Additive"
		InheritanceMode.MULTIPLICATIVE: return "Multiplicative"
		InheritanceMode.SELECTIVE: return "Selective"
		_: return "Unknown"

## Get validation level name
static func get_validation_level_name(level: ValidationLevel) -> String:
	match level:
		ValidationLevel.BASIC: return "Basic"
		ValidationLevel.STRUCTURE: return "Structure"
		ValidationLevel.BALANCE: return "Balance"
		ValidationLevel.PERFORMANCE: return "Performance"
		_: return "Unknown"

## Check if template type allows stat modifications
static func allows_stat_modifications(template_type: Type) -> bool:
	return template_type == Type.VARIANT or template_type == Type.PROTOTYPE or template_type == Type.CUSTOM

## Check if template type allows weapon modifications
static func allows_weapon_modifications(template_type: Type) -> bool:
	return template_type != Type.FACTION  # All except faction variants

## Check if template type is user-editable
static func is_user_editable(template_type: Type) -> bool:
	return template_type == Type.CUSTOM or template_type == Type.LOADOUT

## Get recommended validation level for template type
static func get_recommended_validation_level(template_type: Type) -> ValidationLevel:
	match template_type:
		Type.VARIANT, Type.PROTOTYPE:
			return ValidationLevel.BALANCE
		Type.LOADOUT, Type.CUSTOM:
			return ValidationLevel.STRUCTURE
		Type.MISSION_SPECIFIC, Type.CAMPAIGN:
			return ValidationLevel.BASIC
		Type.FACTION:
			return ValidationLevel.PERFORMANCE
		_:
			return ValidationLevel.BASIC