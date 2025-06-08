class_name ShipTemplate
extends Resource

## Ship template resource for WCS-Godot conversion
## Handles ship variants, loadout configurations, and inheritance
## Supports WCS naming conventions like "GTF Apollo#Advanced"

# Template identification
@export var template_name: String = ""
@export var display_name: String = ""
@export var base_ship_class: String = ""  # Resource path to base ShipClass
@export var variant_suffix: String = ""   # e.g., "Advanced", "Interceptor"

# Template type and category
@export var template_type: ShipTemplateType.Type = ShipTemplateType.Type.VARIANT
@export var inheritance_mode: ShipTemplateType.InheritanceMode = ShipTemplateType.InheritanceMode.OVERRIDE

# Override properties (only set values that differ from base class)
@export_group("Physics Overrides")
@export var override_mass: float = -1.0
@export var override_max_velocity: float = -1.0
@export var override_max_afterburner_velocity: float = -1.0
@export var override_acceleration: float = -1.0
@export var override_angular_acceleration: float = -1.0

@export_group("Structural Overrides")
@export var override_max_hull_strength: float = -1.0
@export var override_max_shield_strength: float = -1.0
@export var override_armor_type: String = ""

@export_group("Energy System Overrides")
@export var override_max_weapon_energy: float = -1.0
@export var override_weapon_energy_regen_rate: float = -1.0
@export var override_afterburner_fuel_capacity: float = -1.0
@export var override_afterburner_fuel_regen_rate: float = -1.0

@export_group("Weapon Configuration")
@export var primary_weapon_loadout: Array[String] = []    # Weapon resource paths
@export var secondary_weapon_loadout: Array[String] = []  # Weapon resource paths
@export var weapon_bank_configuration: Array[WeaponBankConfig] = []

@export_group("Subsystem Configuration")
@export var subsystem_overrides: Array[SubsystemOverride] = []
@export var additional_subsystems: Array[String] = []  # Additional subsystem definition paths

@export_group("Visual and Audio")
@export var override_model_path: String = ""
@export var override_texture_path: String = ""
@export var override_engine_sound: String = ""
@export var team_color_variations: Array[TeamColorVariation] = []

@export_group("AI Configuration")
@export var override_ai_class: String = ""
@export var ai_behavior_modifiers: Array[AIBehaviorModifier] = []

@export_group("Special Properties")
@export var capability_modifiers: Array[CapabilityModifier] = []
@export var special_flags: Array[String] = []
@export var mission_restrictions: Array[String] = []

# Template validation and metadata
@export_group("Metadata")
@export var description: String = ""
@export var tech_description: String = ""
@export var unlock_requirements: Array[String] = []
@export var compatibility_version: String = "1.0"

# Runtime data (not exported)
var _resolved_ship_class: ShipClass
var _validation_cache: Dictionary = {}
var _last_validation_time: float = 0.0

func _init() -> void:
	resource_name = "ShipTemplate"

## Get the complete template name with variant suffix
func get_full_name() -> String:
	if variant_suffix.is_empty():
		return template_name
	return template_name + "#" + variant_suffix

## Get the display name or fallback to full name
func get_display_name() -> String:
	if display_name.is_empty():
		return get_full_name()
	return display_name

## Resolve and return the base ship class
func get_base_ship_class() -> ShipClass:
	if _resolved_ship_class == null and not base_ship_class.is_empty():
		_resolved_ship_class = load(base_ship_class) as ShipClass
	return _resolved_ship_class

## Create a configured ShipClass from this template
func create_ship_class() -> ShipClass:
	var base_class: ShipClass = get_base_ship_class()
	if base_class == null:
		push_error("ShipTemplate: Cannot resolve base ship class: " + base_ship_class)
		return null
	
	# Create new ShipClass instance
	var configured_class: ShipClass = ShipClass.new()
	
	# Copy all base properties
	_copy_base_properties(base_class, configured_class)
	
	# Apply template overrides
	_apply_template_overrides(configured_class)
	
	# Configure weapons and subsystems
	_configure_weapons(configured_class)
	_configure_subsystems(configured_class)
	
	# Apply AI and special properties
	_apply_ai_configuration(configured_class)
	_apply_capability_modifiers(configured_class)
	
	# Set template-specific properties
	configured_class.class_name = get_full_name()
	configured_class.display_name = get_display_name()
	
	return configured_class

## Copy all properties from base class to configured class
func _copy_base_properties(base: ShipClass, target: ShipClass) -> void:
	# Basic information
	target.short_name = base.short_name
	target.species = base.species
	target.ship_type = base.ship_type
	target.ship_size = base.ship_size
	
	# Physical properties
	target.mass = base.mass
	target.moment_of_inertia = base.moment_of_inertia
	target.max_velocity = base.max_velocity
	target.max_afterburner_velocity = base.max_afterburner_velocity
	target.acceleration = base.acceleration
	target.angular_acceleration = base.angular_acceleration
	
	# Structural properties
	target.max_hull_strength = base.max_hull_strength
	target.max_shield_strength = base.max_shield_strength
	target.armor_type = base.armor_type
	
	# Energy systems
	target.max_weapon_energy = base.max_weapon_energy
	target.weapon_energy_regen_rate = base.weapon_energy_regen_rate
	target.afterburner_fuel_capacity = base.afterburner_fuel_capacity
	target.afterburner_fuel_regen_rate = base.afterburner_fuel_regen_rate
	
	# Combat properties
	target.max_weapon_banks = base.max_weapon_banks
	target.max_secondary_banks = base.max_secondary_banks
	target.primary_weapon_slots = base.primary_weapon_slots.duplicate()
	target.secondary_weapon_slots = base.secondary_weapon_slots.duplicate()
	
	# Model and visual properties
	target.model_path = base.model_path
	target.texture_path = base.texture_path
	target.cockpit_model_path = base.cockpit_model_path
	target.detail_levels = base.detail_levels.duplicate()
	
	# Engine properties
	target.engine_sound = base.engine_sound
	target.engine_wash_info = base.engine_wash_info
	target.thruster_glow_info = base.thruster_glow_info
	
	# Special properties
	target.has_afterburner = base.has_afterburner
	target.has_shields = base.has_shields
	target.can_warp = base.can_warp
	target.stealth_capable = base.stealth_capable
	
	# AI properties
	target.ai_class = base.ai_class
	target.ai_behavior_flags = base.ai_behavior_flags
	
	# Manufacturing info
	target.manufacturer = base.manufacturer
	target.tech_description = base.tech_description
	target.length = base.length
	target.wingspan = base.wingspan
	target.height = base.height
	
	# Special flags
	target.ship_flags = base.ship_flags
	target.ship_flags2 = base.ship_flags2

## Apply template-specific overrides to the configured class
func _apply_template_overrides(target: ShipClass) -> void:
	# Physics overrides
	if override_mass > 0.0:
		target.mass = override_mass
	if override_max_velocity > 0.0:
		target.max_velocity = override_max_velocity
	if override_max_afterburner_velocity > 0.0:
		target.max_afterburner_velocity = override_max_afterburner_velocity
	if override_acceleration > 0.0:
		target.acceleration = override_acceleration
	if override_angular_acceleration > 0.0:
		target.angular_acceleration = override_angular_acceleration
	
	# Structural overrides
	if override_max_hull_strength > 0.0:
		target.max_hull_strength = override_max_hull_strength
	if override_max_shield_strength > 0.0:
		target.max_shield_strength = override_max_shield_strength
	if not override_armor_type.is_empty():
		target.armor_type = override_armor_type
	
	# Energy system overrides
	if override_max_weapon_energy > 0.0:
		target.max_weapon_energy = override_max_weapon_energy
	if override_weapon_energy_regen_rate > 0.0:
		target.weapon_energy_regen_rate = override_weapon_energy_regen_rate
	if override_afterburner_fuel_capacity > 0.0:
		target.afterburner_fuel_capacity = override_afterburner_fuel_capacity
	if override_afterburner_fuel_regen_rate > 0.0:
		target.afterburner_fuel_regen_rate = override_afterburner_fuel_regen_rate
	
	# Visual and audio overrides
	if not override_model_path.is_empty():
		target.model_path = override_model_path
	if not override_texture_path.is_empty():
		target.texture_path = override_texture_path
	if not override_engine_sound.is_empty():
		target.engine_sound = override_engine_sound

## Configure weapon loadout for the ship
func _configure_weapons(target: ShipClass) -> void:
	# Apply primary weapon loadout
	if not primary_weapon_loadout.is_empty():
		target.primary_weapon_slots = primary_weapon_loadout.duplicate()
	
	# Apply secondary weapon loadout
	if not secondary_weapon_loadout.is_empty():
		target.secondary_weapon_slots = secondary_weapon_loadout.duplicate()
	
	# Apply weapon bank configuration
	for bank_config in weapon_bank_configuration:
		if bank_config.is_valid():
			bank_config.apply_to_ship_class(target)

## Configure subsystems for the ship
func _configure_subsystems(target: ShipClass) -> void:
	# Apply subsystem overrides
	for subsystem_override in subsystem_overrides:
		if subsystem_override.is_valid():
			subsystem_override.apply_to_ship_class(target)
	
	# Add additional subsystems
	# Note: This would require extending ShipClass to support dynamic subsystem configuration

## Apply AI configuration
func _apply_ai_configuration(target: ShipClass) -> void:
	if not override_ai_class.is_empty():
		target.ai_class = override_ai_class
	
	# Apply AI behavior modifiers
	for modifier in ai_behavior_modifiers:
		if modifier.is_valid():
			modifier.apply_to_ship_class(target)

## Apply capability modifiers
func _apply_capability_modifiers(target: ShipClass) -> void:
	for modifier in capability_modifiers:
		if modifier.is_valid():
			modifier.apply_to_ship_class(target)

## Validate the template configuration
func is_valid() -> bool:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Use cached validation if recent
	if current_time - _last_validation_time < 1.0 and _validation_cache.has("is_valid"):
		return _validation_cache["is_valid"]
	
	var valid: bool = true
	var errors: Array[String] = []
	
	# Validate basic properties
	if template_name.is_empty():
		errors.append("Template name cannot be empty")
		valid = false
	
	if base_ship_class.is_empty():
		errors.append("Base ship class must be specified")
		valid = false
	
	# Validate base ship class can be loaded
	var base_class: ShipClass = get_base_ship_class()
	if base_class == null:
		errors.append("Cannot load base ship class: " + base_ship_class)
		valid = false
	
	# Validate weapon configurations
	for bank_config in weapon_bank_configuration:
		if not bank_config.is_valid():
			errors.append("Invalid weapon bank configuration")
			valid = false
	
	# Validate subsystem overrides
	for subsystem_override in subsystem_overrides:
		if not subsystem_override.is_valid():
			errors.append("Invalid subsystem override")
			valid = false
	
	# Cache validation results
	_validation_cache["is_valid"] = valid
	_validation_cache["errors"] = errors
	_last_validation_time = current_time
	
	return valid

## Get validation errors
func get_validation_errors() -> Array[String]:
	if not is_valid() and _validation_cache.has("errors"):
		return _validation_cache["errors"]
	return []

## Get template type name
func get_template_type_name() -> String:
	return ShipTemplateType.get_type_name(template_type)

## Check if template has specific capability
func has_capability_modifier(capability: String) -> bool:
	for modifier in capability_modifiers:
		if modifier.capability_name == capability:
			return true
	return false

## Get capability modifier value
func get_capability_modifier_value(capability: String) -> float:
	for modifier in capability_modifiers:
		if modifier.capability_name == capability:
			return modifier.modifier_value
	return 1.0

## Create a default fighter variant template
static func create_default_fighter_variant() -> ShipTemplate:
	var template: ShipTemplate = ShipTemplate.new()
	template.template_name = "GTF Apollo"
	template.variant_suffix = "Advanced"
	template.base_ship_class = "res://resources/ships/terran/gtf_apollo.tres"
	template.template_type = ShipTemplateType.Type.VARIANT
	template.description = "Advanced variant of the GTF Apollo fighter"
	
	# Enhanced performance
	template.override_max_velocity = 85.0  # +10 from base
	template.override_acceleration = 35.0  # +5 from base
	template.override_max_weapon_energy = 90.0  # +10 from base
	
	return template

## Create a default bomber loadout template
static func create_default_bomber_loadout() -> ShipTemplate:
	var template: ShipTemplate = ShipTemplate.new()
	template.template_name = "GTB Medusa"
	template.variant_suffix = "Heavy"
	template.base_ship_class = "res://resources/ships/terran/gtb_medusa.tres"
	template.template_type = ShipTemplateType.Type.LOADOUT
	template.description = "Heavy assault loadout for the GTB Medusa"
	
	# Heavy weapons loadout
	template.primary_weapon_loadout = [
		"res://resources/weapons/primary/prometheus_r.tres",
		"res://resources/weapons/primary/prometheus_r.tres"
	]
	template.secondary_weapon_loadout = [
		"res://resources/weapons/secondary/cyclops.tres",
		"res://resources/weapons/secondary/hornet.tres"
	]
	
	return template

## Get template summary for display
func get_template_summary() -> Dictionary:
	return {
		"template_name": get_full_name(),
		"display_name": get_display_name(),
		"base_class": base_ship_class,
		"template_type": get_template_type_name(),
		"variant_suffix": variant_suffix,
		"description": description,
		"is_valid": is_valid(),
		"override_count": _count_overrides()
	}

## Count number of property overrides
func _count_overrides() -> int:
	var count: int = 0
	
	if override_mass > 0.0: count += 1
	if override_max_velocity > 0.0: count += 1
	if override_max_afterburner_velocity > 0.0: count += 1
	if override_acceleration > 0.0: count += 1
	if override_angular_acceleration > 0.0: count += 1
	if override_max_hull_strength > 0.0: count += 1
	if override_max_shield_strength > 0.0: count += 1
	if not override_armor_type.is_empty(): count += 1
	if override_max_weapon_energy > 0.0: count += 1
	if override_weapon_energy_regen_rate > 0.0: count += 1
	if override_afterburner_fuel_capacity > 0.0: count += 1
	if override_afterburner_fuel_regen_rate > 0.0: count += 1
	if not override_model_path.is_empty(): count += 1
	if not override_texture_path.is_empty(): count += 1
	if not override_engine_sound.is_empty(): count += 1
	if not override_ai_class.is_empty(): count += 1
	
	count += weapon_bank_configuration.size()
	count += subsystem_overrides.size()
	count += capability_modifiers.size()
	count += ai_behavior_modifiers.size()
	
	return count