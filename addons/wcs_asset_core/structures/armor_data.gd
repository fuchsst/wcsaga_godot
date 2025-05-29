class_name ArmorData
extends BaseAssetData

## Armor data resource for the WCS Asset Core addon.
## Comprehensive armor and shield specifications extracted from the existing WCS codebase.
## Defines damage resistance, shield piercing, and armor behavior properties.

# Asset type setup
func _init() -> void:
	asset_type = AssetTypes.Type.ARMOR

## General Armor Properties
@export var armor_name: String = "" # ArmorType.Name
@export var armor_flags: int = 0 # ArmorType.flags (e.g., SAF_IGNORE_SS_ARMOR)

## Damage Resistance System
# Dictionary mapping damage type index (int) or name (String) to resistance multiplier (float).
# A multiplier of 1.0 means no resistance, 0.5 means 50% damage taken, 0.0 means immune, 2.0 means double damage.
@export var damage_resistances: Dictionary = {} # ArmorType.DamageTypes -> GetDamage() logic

## Shield Piercing Properties (Relevant if used for shields)
# Dictionary mapping damage type index (int) or name (String) to shield pierce percentage (float, 0.0 to 1.0).
@export var shield_pierce_percentages: Dictionary = {} # ArmorType.GetShieldPiercePCT()

# Dictionary mapping damage type index (int) or name (String) to piercing type (int, SADTF_* constants).
@export var piercing_types: Dictionary = {} # ArmorType.GetPiercingType()

# Dictionary mapping damage type index (int) or name (String) to piercing limit (float, percentage).
@export var piercing_limits: Dictionary = {} # ArmorType.GetPiercingLimit()

## Advanced Armor Properties
@export var base_damage_modifier: float = 1.0 # Base damage modifier applied to all damage types
@export var minimum_damage_threshold: float = 0.0 # Minimum damage required to penetrate armor
@export var maximum_damage_cap: float = -1.0 # Maximum damage that can be taken in one hit (-1 = no cap)
@export var armor_thickness: float = 1.0 # Relative armor thickness (affects calculations)
@export var repair_rate: float = 0.0 # Armor repair rate per second (if repairable)
@export var degradation_rate: float = 0.0 # Armor degradation rate when damaged

## Specialized Resistance Categories
@export var kinetic_resistance: float = 1.0 # General kinetic damage resistance
@export var energy_resistance: float = 1.0 # General energy damage resistance
@export var explosive_resistance: float = 1.0 # General explosive damage resistance
@export var beam_resistance: float = 1.0 # General beam weapon resistance
@export var emp_resistance: float = 1.0 # EMP damage resistance
@export var ion_resistance: float = 1.0 # Ion damage resistance

## Shield-Specific Properties (when used for shield armor)
@export var shield_regeneration_modifier: float = 1.0 # Affects shield regen rate
@export var shield_capacity_modifier: float = 1.0 # Affects maximum shield strength
@export var shield_recharge_delay_modifier: float = 1.0 # Affects recharge delay after damage
@export var quadrant_damage_distribution: bool = true # Whether damage spreads across quadrants

## Subsystem Armor Properties
@export var subsystem_damage_modifier: float = 1.0 # Modifier for subsystem damage
@export var critical_hit_resistance: float = 1.0 # Resistance to critical hits
@export var armor_degradation_threshold: float = 0.5 # Hull percentage when armor starts degrading

## Visual and Audio Properties
@export var impact_effect_modifier: float = 1.0 # Scaling for impact visual effects
@export var impact_sound_set: String = "" # Sound set to use for impacts
@export var armor_texture_overlay: String = "" # Optional texture overlay for armored surfaces
@export var damage_decal_set: String = "" # Decal set for damage visualization

## Override validation to include armor-specific checks
func get_validation_errors() -> Array[String]:
	"""Get validation errors specific to armor data.
	Returns:
		Array of validation error messages"""
	
	var errors: Array[String] = super.get_validation_errors()
	
	# Armor-specific validation
	if armor_name.is_empty():
		errors.append("Armor name is required")
	
	if base_damage_modifier < 0.0:
		errors.append("Base damage modifier cannot be negative")
	
	if minimum_damage_threshold < 0.0:
		errors.append("Minimum damage threshold cannot be negative")
	
	if maximum_damage_cap >= 0.0 and maximum_damage_cap < minimum_damage_threshold:
		errors.append("Maximum damage cap must be greater than minimum threshold")
	
	if armor_thickness <= 0.0:
		errors.append("Armor thickness must be positive")
	
	# Validate resistance values
	for damage_type in damage_resistances.keys():
		var resistance: float = damage_resistances[damage_type]
		if resistance < 0.0:
			errors.append("Damage resistance for %s cannot be negative" % damage_type)
	
	# Validate piercing percentages
	for damage_type in shield_pierce_percentages.keys():
		var percentage: float = shield_pierce_percentages[damage_type]
		if percentage < 0.0 or percentage > 1.0:
			errors.append("Shield pierce percentage for %s must be between 0.0 and 1.0" % damage_type)
	
	return errors

## Damage Calculation Functions

func get_damage_multiplier(damage_type_key: Variant) -> float:
	"""Get damage multiplier for a given damage type.
	Args:
		damage_type_key: Damage type index (int) or name (String)
	Returns:
		Damage multiplier (1.0 = normal, 0.5 = half damage, 0.0 = immune)"""
	
	var resistance: float = damage_resistances.get(damage_type_key, 1.0)
	return resistance * base_damage_modifier

func calculate_damage_taken(base_damage: float, damage_type_key: Variant = null) -> float:
	"""Calculate actual damage taken after armor resistance.
	Args:
		base_damage: Incoming damage amount
		damage_type_key: Optional damage type for specific resistance
	Returns:
		Actual damage after armor calculations"""
	
	var damage: float = base_damage
	
	# Apply damage type resistance
	if damage_type_key != null:
		damage *= get_damage_multiplier(damage_type_key)
	
	# Apply minimum threshold
	if damage < minimum_damage_threshold:
		return 0.0
	
	# Apply maximum cap
	if maximum_damage_cap > 0.0:
		damage = min(damage, maximum_damage_cap)
	
	return damage

func get_shield_pierce_percentage(damage_type_key: Variant) -> float:
	"""Get shield pierce percentage for a damage type.
	Args:
		damage_type_key: Damage type index (int) or name (String)
	Returns:
		Piercing percentage (0.0 to 1.0)"""
	
	return shield_pierce_percentages.get(damage_type_key, 0.0)

func get_piercing_type(damage_type_key: Variant) -> int:
	"""Get piercing type for a damage type.
	Args:
		damage_type_key: Damage type index (int) or name (String)
	Returns:
		Piercing type constant"""
	
	return piercing_types.get(damage_type_key, 1)

func get_piercing_limit(damage_type_key: Variant) -> float:
	"""Get piercing limit for a damage type.
	Args:
		damage_type_key: Damage type index (int) or name (String)
	Returns:
		Piercing limit percentage"""
	
	return piercing_limits.get(damage_type_key, 0.0)

## Armor Configuration Functions

func set_damage_resistance(damage_type_key: Variant, resistance: float) -> void:
	"""Set damage resistance for a specific damage type.
	Args:
		damage_type_key: Damage type index (int) or name (String)
		resistance: Resistance multiplier (1.0 = normal, 0.5 = half damage)"""
	
	damage_resistances[damage_type_key] = max(0.0, resistance)

func set_shield_pierce_data(damage_type_key: Variant, percentage: float, piercing_type: int = 1, limit: float = 0.0) -> void:
	"""Set shield piercing data for a damage type.
	Args:
		damage_type_key: Damage type index (int) or name (String)
		percentage: Pierce percentage (0.0 to 1.0)
		piercing_type: Piercing type constant
		limit: Piercing limit percentage"""
	
	shield_pierce_percentages[damage_type_key] = clamp(percentage, 0.0, 1.0)
	piercing_types[damage_type_key] = piercing_type
	piercing_limits[damage_type_key] = clamp(limit, 0.0, 1.0)

func remove_damage_type(damage_type_key: Variant) -> void:
	"""Remove all data for a specific damage type.
	Args:
		damage_type_key: Damage type to remove"""
	
	damage_resistances.erase(damage_type_key)
	shield_pierce_percentages.erase(damage_type_key)
	piercing_types.erase(damage_type_key)
	piercing_limits.erase(damage_type_key)

func get_all_damage_types() -> Array:
	"""Get all damage types configured for this armor.
	Returns:
		Array of all damage type keys"""
	
	var types: Array = []
	
	# Combine all damage type keys
	for key in damage_resistances.keys():
		if not types.has(key):
			types.append(key)
	
	for key in shield_pierce_percentages.keys():
		if not types.has(key):
			types.append(key)
	
	return types

## Specialized Resistance Functions

func is_immune_to(damage_type_key: Variant) -> bool:
	"""Check if armor is immune to a damage type.
	Args:
		damage_type_key: Damage type to check
	Returns:
		true if completely immune (0% damage taken)"""
	
	return get_damage_multiplier(damage_type_key) <= 0.0

func is_vulnerable_to(damage_type_key: Variant) -> bool:
	"""Check if armor is vulnerable to a damage type.
	Args:
		damage_type_key: Damage type to check
	Returns:
		true if takes extra damage (>100% damage taken)"""
	
	return get_damage_multiplier(damage_type_key) > 1.0

func get_effective_thickness_vs(damage_type_key: Variant) -> float:
	"""Get effective armor thickness against a damage type.
	Args:
		damage_type_key: Damage type to check
	Returns:
		Effective thickness (higher = more protection)"""
	
	var multiplier: float = get_damage_multiplier(damage_type_key)
	if multiplier <= 0.0:
		return float('inf')  # Infinite protection
	
	return armor_thickness / multiplier

func get_resistance_summary() -> Dictionary:
	"""Get a summary of all damage resistances.
	Returns:
		Dictionary with resistance statistics"""
	
	var summary: Dictionary = {
		"total_damage_types": damage_resistances.size(),
		"immunities": [],
		"vulnerabilities": [],
		"resistances": [],
		"average_resistance": 1.0
	}
	
	var total_resistance: float = 0.0
	var count: int = 0
	
	for damage_type in damage_resistances.keys():
		var resistance: float = damage_resistances[damage_type]
		total_resistance += resistance
		count += 1
		
		if resistance <= 0.0:
			summary["immunities"].append(damage_type)
		elif resistance > 1.0:
			summary["vulnerabilities"].append(damage_type)
		else:
			summary["resistances"].append(damage_type)
	
	if count > 0:
		summary["average_resistance"] = total_resistance / count
	
	return summary

## Utility Functions

func is_shield_armor() -> bool:
	"""Check if this armor is designed for shields.
	Returns:
		true if this is shield armor"""
	
	return asset_type == AssetTypes.Type.SHIELD_ARMOR or shield_regeneration_modifier != 1.0

func is_hull_armor() -> bool:
	"""Check if this armor is designed for hull.
	Returns:
		true if this is hull armor"""
	
	return asset_type == AssetTypes.Type.HULL_ARMOR or not is_shield_armor()

func can_repair() -> bool:
	"""Check if this armor can be repaired.
	Returns:
		true if armor has repair capability"""
	
	return repair_rate > 0.0

func degrades_over_time() -> bool:
	"""Check if this armor degrades over time.
	Returns:
		true if armor degrades"""
	
	return degradation_rate > 0.0

## Enhanced memory size calculation
func get_memory_size() -> int:
	"""Calculate estimated memory usage for this armor data.
	Returns:
		Estimated memory size in bytes"""
	
	var size: int = super.get_memory_size()
	
	# Add armor-specific data sizes
	size += armor_name.length()
	size += impact_sound_set.length() + armor_texture_overlay.length() + damage_decal_set.length()
	
	# Dictionaries - estimate based on key-value pairs
	size += damage_resistances.size() * 50  # key + float value
	size += shield_pierce_percentages.size() * 50
	size += piercing_types.size() * 40
	size += piercing_limits.size() * 50
	
	return size

## Conversion utilities

func convert_from_legacy_armor_data(legacy_data: Resource) -> void:
	"""Convert from existing ArmorData resource format.
	Args:
		legacy_data: Existing ArmorData resource to convert"""
	
	if not legacy_data:
		return
	
	# Copy common properties that exist in both formats
	if legacy_data.has_method("get") or "armor_name" in legacy_data:
		armor_name = legacy_data.get("armor_name") or ""
		armor_flags = legacy_data.get("flags") or 0
		damage_resistances = legacy_data.get("damage_resistances") or {}
		shield_pierce_percentages = legacy_data.get("shield_pierce_percentages") or {}
		# ... more conversion logic
	
	# Mark as converted
	source_file = "legacy_armor_data"
	conversion_notes = "Converted from existing ArmorData resource"

func to_dictionary() -> Dictionary:
	"""Convert armor data to dictionary representation.
	Returns:
		Complete dictionary representation of armor data"""
	
	var dict: Dictionary = super.to_dictionary()
	
	# Add armor-specific fields
	dict["armor_name"] = armor_name
	dict["armor_flags"] = armor_flags
	dict["damage_resistances"] = damage_resistances
	dict["shield_pierce_percentages"] = shield_pierce_percentages
	dict["piercing_types"] = piercing_types
	dict["piercing_limits"] = piercing_limits
	dict["base_damage_modifier"] = base_damage_modifier
	dict["armor_thickness"] = armor_thickness
	dict["kinetic_resistance"] = kinetic_resistance
	dict["energy_resistance"] = energy_resistance
	dict["explosive_resistance"] = explosive_resistance
	
	return dict

## Armor Preset Functions

func setup_as_light_armor() -> void:
	"""Configure as light armor with balanced resistances."""
	
	armor_name = "Light Armor"
	armor_thickness = 0.5
	base_damage_modifier = 1.2  # Takes extra damage
	kinetic_resistance = 0.9
	energy_resistance = 1.1
	explosive_resistance = 1.3

func setup_as_heavy_armor() -> void:
	"""Configure as heavy armor with high kinetic resistance."""
	
	armor_name = "Heavy Armor"
	armor_thickness = 2.0
	base_damage_modifier = 0.8  # Takes less damage
	kinetic_resistance = 0.5
	energy_resistance = 0.9
	explosive_resistance = 0.7

func setup_as_energy_resistant() -> void:
	"""Configure as energy-resistant armor."""
	
	armor_name = "Energy Resistant Armor"
	armor_thickness = 1.0
	kinetic_resistance = 1.2
	energy_resistance = 0.4
	beam_resistance = 0.3
	emp_resistance = 0.6
	explosive_resistance = 1.0
