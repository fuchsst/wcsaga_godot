class_name SpecialWeaponResistance
extends Node

## SHIP-014 AC6: Special Weapon Resistance System
## Applies ship-specific immunity modifiers and capital ship protection mechanics
## Manages resistance calculations for EMP, flak, and swarm weapons with WCS-authentic scaling

# EPIC-002 Asset Core Integration
const WeaponTypes = preload("res://addons/wcs_asset_core/constants/weapon_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const ShipSizes = preload("res://addons/wcs_asset_core/constants/ship_sizes.gd")
const ShipTypes = preload("res://addons/wcs_asset_core/constants/ship_types.gd")

# Signals
signal resistance_applied(target: Node, weapon_type: int, original_damage: float, reduced_damage: float)
signal immunity_activated(target: Node, weapon_type: int, immunity_reason: String)
signal resistance_modifier_calculated(target: Node, resistance_type: String, modifier: float)
signal capital_ship_protection_applied(target: Node, protected_systems: Array)

# Resistance types
enum ResistanceType {
	EMP_RESISTANCE,
	KINETIC_RESISTANCE,
	ENERGY_RESISTANCE,
	AREA_EFFECT_RESISTANCE,
	PENETRATION_RESISTANCE,
	SYSTEM_DISRUPTION_RESISTANCE
}

# Ship size-based resistance values (WCS-authentic)
var ship_size_resistance: Dictionary = {
	ShipSizes.Size.FIGHTER: {
		ResistanceType.EMP_RESISTANCE: 0.0,           # No EMP resistance
		ResistanceType.KINETIC_RESISTANCE: 0.0,       # No kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.0,        # No energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.0,   # No area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.0,   # No penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.0
	},
	ShipSizes.Size.BOMBER: {
		ResistanceType.EMP_RESISTANCE: 0.1,           # 10% EMP resistance
		ResistanceType.KINETIC_RESISTANCE: 0.05,      # 5% kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.0,        # No energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.1,   # 10% area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.05,  # 5% penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.1
	},
	ShipSizes.Size.CORVETTE: {
		ResistanceType.EMP_RESISTANCE: 0.3,           # 30% EMP resistance
		ResistanceType.KINETIC_RESISTANCE: 0.15,      # 15% kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.1,        # 10% energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.25,  # 25% area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.2,   # 20% penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.3
	},
	ShipSizes.Size.FRIGATE: {
		ResistanceType.EMP_RESISTANCE: 0.5,           # 50% EMP resistance
		ResistanceType.KINETIC_RESISTANCE: 0.3,       # 30% kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.2,        # 20% energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.4,   # 40% area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.35,  # 35% penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.5
	},
	ShipSizes.Size.DESTROYER: {
		ResistanceType.EMP_RESISTANCE: 0.7,           # 70% EMP resistance
		ResistanceType.KINETIC_RESISTANCE: 0.45,      # 45% kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.35,       # 35% energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.6,   # 60% area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.5,   # 50% penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.7
	},
	ShipSizes.Size.CRUISER: {
		ResistanceType.EMP_RESISTANCE: 0.8,           # 80% EMP resistance
		ResistanceType.KINETIC_RESISTANCE: 0.6,       # 60% kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.5,        # 50% energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.75,  # 75% area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.65,  # 65% penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.8
	},
	ShipSizes.Size.BATTLESHIP: {
		ResistanceType.EMP_RESISTANCE: 0.9,           # 90% EMP resistance
		ResistanceType.KINETIC_RESISTANCE: 0.75,      # 75% kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.65,       # 65% energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.85,  # 85% area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.8,   # 80% penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.9
	},
	ShipSizes.Size.CAPITAL: {
		ResistanceType.EMP_RESISTANCE: 0.95,          # 95% EMP resistance (turrets only affected)
		ResistanceType.KINETIC_RESISTANCE: 0.85,      # 85% kinetic resistance
		ResistanceType.ENERGY_RESISTANCE: 0.75,       # 75% energy resistance
		ResistanceType.AREA_EFFECT_RESISTANCE: 0.9,   # 90% area resistance
		ResistanceType.PENETRATION_RESISTANCE: 0.9,   # 90% penetration resistance
		ResistanceType.SYSTEM_DISRUPTION_RESISTANCE: 0.95
	}
}

# Special immunity conditions
var immunity_conditions: Dictionary = {
	"shielded_from_emp": {
		"weapon_types": [WeaponTypes.Type.EMP_BOMB, WeaponTypes.Type.EMP_MISSILE, WeaponTypes.Type.EMP_CANNON],
		"immunity_factor": 0.8,  # 80% immunity when shields active
		"condition": "active_shields"
	},
	"capital_ship_core_protection": {
		"weapon_types": [WeaponTypes.Type.EMP_BOMB, WeaponTypes.Type.EMP_MISSILE],
		"immunity_factor": 1.0,  # Complete immunity to core systems
		"condition": "capital_ship_core"
	},
	"armor_kinetic_reduction": {
		"weapon_types": [WeaponTypes.Type.FLAK_CANNON, WeaponTypes.Type.FLAK_BURST],
		"immunity_factor": 0.5,  # 50% reduction against heavy armor
		"condition": "heavy_armor"
	},
	"point_defense_swarm_immunity": {
		"weapon_types": [WeaponTypes.Type.SWARM_MISSILE, WeaponTypes.Type.HEAVY_SWARM],
		"immunity_factor": 0.7,  # 70% immunity with active point defense
		"condition": "active_point_defense"
	}
}

# Configuration
@export var enable_resistance_debugging: bool = false
@export var enable_ship_size_resistance: bool = true
@export var enable_immunity_conditions: bool = true
@export var enable_capital_ship_protection: bool = true
@export var enable_dynamic_resistance: bool = true

# System references
var ship_owner: Node = null

# Resistance tracking
var active_resistances: Dictionary = {}  # ship -> resistance_data
var immunity_states: Dictionary = {}  # ship -> immunity_states
var capital_ship_protections: Dictionary = {}  # capital_ship -> protected_systems

# Performance tracking
var resistance_performance_stats: Dictionary = {
	"total_resistance_calculations": 0,
	"immunity_activations": 0,
	"capital_protections_applied": 0,
	"resistance_modifiers_calculated": 0
}

func _ready() -> void:
	_setup_resistance_system()

## Initialize resistance system
func initialize_resistance_system(owner_ship: Node) -> void:
	ship_owner = owner_ship
	
	if enable_resistance_debugging:
		print("SpecialWeaponResistance: Initialized for ship %s" % ship_owner.name)

## Calculate resistance for weapon damage
func calculate_resistance(target: Node, weapon_type: int, damage_amount: float, damage_data: Dictionary = {}) -> Dictionary:
	var original_damage = damage_amount
	var resistance_modifiers: Array[float] = []
	var immunity_reasons: Array[String] = []
	
	var result = {
		"target": target,
		"weapon_type": weapon_type,
		"original_damage": original_damage,
		"final_damage": damage_amount,
		"total_resistance": 0.0,
		"resistance_breakdown": {},
		"immunity_applied": false,
		"immunity_reasons": immunity_reasons
	}
	
	# Check for complete immunity first
	var immunity_data = _check_immunity_conditions(target, weapon_type, damage_data)
	if immunity_data["immune"]:
		result["final_damage"] = damage_amount * (1.0 - immunity_data["immunity_factor"])
		result["immunity_applied"] = true
		result["immunity_reasons"] = immunity_data["reasons"]
		
		immunity_activated.emit(target, weapon_type, immunity_data["reasons"][0] if immunity_data["reasons"].size() > 0 else "unknown")
		resistance_performance_stats["immunity_activations"] += 1
		
		if enable_resistance_debugging:
			print("SpecialWeaponResistance: Immunity applied to %s - %.1f%% reduction" % [
				target.name, immunity_data["immunity_factor"] * 100.0
			])
		
		return result
	
	# Calculate ship size-based resistance
	if enable_ship_size_resistance:
		var size_resistance = _calculate_ship_size_resistance(target, weapon_type)
		if size_resistance > 0.0:
			resistance_modifiers.append(size_resistance)
			result["resistance_breakdown"]["ship_size"] = size_resistance
			resistance_modifier_calculated.emit(target, "ship_size", size_resistance)
	
	# Calculate dynamic resistance based on ship state
	if enable_dynamic_resistance:
		var dynamic_resistance = _calculate_dynamic_resistance(target, weapon_type, damage_data)
		if dynamic_resistance > 0.0:
			resistance_modifiers.append(dynamic_resistance)
			result["resistance_breakdown"]["dynamic"] = dynamic_resistance
			resistance_modifier_calculated.emit(target, "dynamic", dynamic_resistance)
	
	# Calculate special protection resistance
	var protection_resistance = _calculate_protection_resistance(target, weapon_type, damage_data)
	if protection_resistance > 0.0:
		resistance_modifiers.append(protection_resistance)
		result["resistance_breakdown"]["protection"] = protection_resistance
		resistance_modifier_calculated.emit(target, "protection", protection_resistance)
	
	# Apply capital ship protection if applicable
	if enable_capital_ship_protection:
		var capital_protection = _apply_capital_ship_protection(target, weapon_type, damage_data)
		if capital_protection > 0.0:
			resistance_modifiers.append(capital_protection)
			result["resistance_breakdown"]["capital_protection"] = capital_protection
			resistance_modifier_calculated.emit(target, "capital_protection", capital_protection)
	
	# Calculate total resistance (resistance values don't stack additively, they compound)
	var total_resistance = _calculate_compound_resistance(resistance_modifiers)
	result["total_resistance"] = total_resistance
	result["final_damage"] = damage_amount * (1.0 - total_resistance)
	
	# Update performance stats
	resistance_performance_stats["total_resistance_calculations"] += 1
	resistance_performance_stats["resistance_modifiers_calculated"] += resistance_modifiers.size()
	
	resistance_applied.emit(target, weapon_type, original_damage, result["final_damage"])
	
	if enable_resistance_debugging and total_resistance > 0.0:
		print("SpecialWeaponResistance: Applied %.1f%% resistance to %s (%.1f -> %.1f damage)" % [
			total_resistance * 100.0, target.name, original_damage, result["final_damage"]
		])
	
	return result

## Check immunity conditions
func _check_immunity_conditions(target: Node, weapon_type: int, damage_data: Dictionary) -> Dictionary:
	var immunity_result = {
		"immune": false,
		"immunity_factor": 0.0,
		"reasons": []
	}
	
	if not enable_immunity_conditions:
		return immunity_result
	
	for condition_name in immunity_conditions.keys():
		var condition_data = immunity_conditions[condition_name]
		var weapon_types = condition_data["weapon_types"]
		
		# Check if this weapon type is affected by this immunity
		if weapon_type in weapon_types:
			var condition_met = _evaluate_immunity_condition(target, condition_data["condition"], damage_data)
			
			if condition_met:
				immunity_result["immune"] = true
				immunity_result["immunity_factor"] = max(immunity_result["immunity_factor"], condition_data["immunity_factor"])
				immunity_result["reasons"].append(condition_name)
	
	return immunity_result

## Evaluate specific immunity condition
func _evaluate_immunity_condition(target: Node, condition: String, damage_data: Dictionary) -> bool:
	match condition:
		"active_shields":
			return _has_active_shields(target)
		"capital_ship_core":
			return _is_capital_ship_core_system(target, damage_data)
		"heavy_armor":
			return _has_heavy_armor(target)
		"active_point_defense":
			return _has_active_point_defense(target)
		_:
			return false

## Calculate ship size-based resistance
func _calculate_ship_size_resistance(target: Node, weapon_type: int) -> float:
	var ship_size = _get_ship_size(target)
	var size_resistances = ship_size_resistance.get(ship_size, {})
	
	# Determine resistance type based on weapon type
	var resistance_type = _get_resistance_type_for_weapon(weapon_type)
	
	return size_resistances.get(resistance_type, 0.0)

## Calculate dynamic resistance based on ship state
func _calculate_dynamic_resistance(target: Node, weapon_type: int, damage_data: Dictionary) -> float:
	var dynamic_resistance = 0.0
	
	# Shield-based resistance
	if _has_active_shields(target):
		dynamic_resistance += _calculate_shield_resistance(target, weapon_type)
	
	# Armor-based resistance
	var armor_resistance = _calculate_armor_resistance(target, weapon_type)
	dynamic_resistance += armor_resistance
	
	# Subsystem health resistance
	var subsystem_resistance = _calculate_subsystem_resistance(target, weapon_type)
	dynamic_resistance += subsystem_resistance
	
	return min(dynamic_resistance, 0.9)  # Cap at 90% resistance

## Calculate protection resistance from special systems
func _calculate_protection_resistance(target: Node, weapon_type: int, damage_data: Dictionary) -> float:
	var protection_resistance = 0.0
	
	# EMP shielding systems
	if _is_emp_weapon(weapon_type) and _has_emp_shielding(target):
		protection_resistance += 0.4  # 40% EMP resistance from shielding
	
	# Point defense resistance against swarm weapons
	if _is_swarm_weapon(weapon_type) and _has_active_point_defense(target):
		protection_resistance += 0.6  # 60% resistance to swarm weapons
	
	# Armor plating resistance to kinetic weapons
	if _is_kinetic_weapon(weapon_type) and _has_reinforced_armor(target):
		protection_resistance += 0.3  # 30% kinetic resistance
	
	return min(protection_resistance, 0.8)  # Cap at 80% protection

## Apply capital ship protection mechanics
func _apply_capital_ship_protection(target: Node, weapon_type: int, damage_data: Dictionary) -> float:
	if not _is_capital_ship(target):
		return 0.0
	
	var protection_level = 0.0
	var protected_systems: Array[String] = []
	
	# Capital ships have inherent resistance to special weapons
	if _is_emp_weapon(weapon_type):
		# EMP only affects turrets on capital ships, not core systems
		if _is_core_system_targeted(damage_data):
			protection_level = 0.95  # 95% protection for core systems
			protected_systems.append("core_systems")
		else:
			protection_level = 0.3   # 30% protection for turrets
			protected_systems.append("turret_systems")
	
	# Flak resistance for capital ships
	elif _is_flak_weapon(weapon_type):
		protection_level = 0.5  # 50% flak resistance
		protected_systems.append("armor_sections")
	
	# Swarm missile resistance due to point defense
	elif _is_swarm_weapon(weapon_type):
		protection_level = 0.7  # 70% swarm resistance
		protected_systems.append("point_defense_grid")
	
	if protection_level > 0.0:
		# Track protected systems for this capital ship
		var ship_id = _get_ship_id(target)
		capital_ship_protections[ship_id] = protected_systems
		
		capital_ship_protection_applied.emit(target, protected_systems)
		resistance_performance_stats["capital_protections_applied"] += 1
	
	return protection_level

## Calculate compound resistance from multiple sources
func _calculate_compound_resistance(resistance_modifiers: Array[float]) -> float:
	var compound_resistance = 0.0
	
	# Resistance values compound multiplicatively, not additively
	# Formula: 1 - (1 - r1) * (1 - r2) * (1 - r3) ...
	var damage_multiplier = 1.0
	
	for resistance in resistance_modifiers:
		damage_multiplier *= (1.0 - resistance)
	
	compound_resistance = 1.0 - damage_multiplier
	
	# Cap total resistance at 95% to prevent complete immunity through stacking
	return min(compound_resistance, 0.95)

## Helper functions for ship property checking

func _has_active_shields(target: Node) -> bool:
	if target.has_method("get_shield_strength"):
		return target.get_shield_strength() > 0.0
	elif target.has_method("has_shields"):
		return target.has_shields()
	return false

func _is_capital_ship_core_system(target: Node, damage_data: Dictionary) -> bool:
	return _is_capital_ship(target) and _is_core_system_targeted(damage_data)

func _has_heavy_armor(target: Node) -> bool:
	if target.has_method("get_armor_type"):
		var armor_type = target.get_armor_type()
		return armor_type in ["HEAVY", "CAPITAL", "REINFORCED"]
	return _get_ship_size(target) >= ShipSizes.Size.CRUISER

func _has_active_point_defense(target: Node) -> bool:
	if target.has_method("has_point_defense"):
		return target.has_point_defense()
	elif target.has_method("get_subsystem_manager"):
		var subsystem_manager = target.get_subsystem_manager()
		if subsystem_manager and subsystem_manager.has_method("is_subsystem_functional"):
			return subsystem_manager.is_subsystem_functional("PointDefense")
	return false

func _has_emp_shielding(target: Node) -> bool:
	if target.has_method("has_emp_shielding"):
		return target.has_emp_shielding()
	# Larger ships typically have better EMP protection
	return _get_ship_size(target) >= ShipSizes.Size.FRIGATE

func _has_reinforced_armor(target: Node) -> bool:
	if target.has_method("has_reinforced_armor"):
		return target.has_reinforced_armor()
	# Capital ships typically have reinforced armor
	return _get_ship_size(target) >= ShipSizes.Size.DESTROYER

func _is_capital_ship(target: Node) -> bool:
	var ship_size = _get_ship_size(target)
	return ship_size >= ShipSizes.Size.CRUISER

func _is_core_system_targeted(damage_data: Dictionary) -> bool:
	var target_subsystem = damage_data.get("target_subsystem", "")
	var core_systems = ["Engine", "Reactor", "Bridge", "Navigation"]
	return target_subsystem in core_systems

## Weapon type classification functions

func _is_emp_weapon(weapon_type: int) -> bool:
	return weapon_type in [WeaponTypes.Type.EMP_BOMB, WeaponTypes.Type.EMP_MISSILE, WeaponTypes.Type.EMP_CANNON]

func _is_flak_weapon(weapon_type: int) -> bool:
	return weapon_type in [WeaponTypes.Type.FLAK_CANNON, WeaponTypes.Type.FLAK_BURST, WeaponTypes.Type.FLAK_AAA]

func _is_swarm_weapon(weapon_type: int) -> bool:
	return weapon_type in [WeaponTypes.Type.SWARM_MISSILE, WeaponTypes.Type.HEAVY_SWARM, WeaponTypes.Type.LIGHT_SWARM]

func _is_kinetic_weapon(weapon_type: int) -> bool:
	return _is_flak_weapon(weapon_type)  # Flak weapons are kinetic

func _get_resistance_type_for_weapon(weapon_type: int) -> int:
	if _is_emp_weapon(weapon_type):
		return ResistanceType.EMP_RESISTANCE
	elif _is_flak_weapon(weapon_type):
		return ResistanceType.KINETIC_RESISTANCE
	elif _is_swarm_weapon(weapon_type):
		return ResistanceType.AREA_EFFECT_RESISTANCE
	else:
		return ResistanceType.ENERGY_RESISTANCE

## Calculate specific resistance types

func _calculate_shield_resistance(target: Node, weapon_type: int) -> float:
	var shield_strength = 0.0
	if target.has_method("get_shield_strength_percent"):
		shield_strength = target.get_shield_strength_percent()
	elif target.has_method("get_shield_strength"):
		var current_shields = target.get_shield_strength()
		var max_shields = target.get_max_shield_strength() if target.has_method("get_max_shield_strength") else 100.0
		shield_strength = current_shields / max_shields
	
	# Shields provide more resistance to energy weapons than kinetic
	var shield_effectiveness = 0.8 if not _is_kinetic_weapon(weapon_type) else 0.3
	return shield_strength * shield_effectiveness

func _calculate_armor_resistance(target: Node, weapon_type: int) -> float:
	var armor_thickness = 1.0
	if target.has_method("get_armor_thickness"):
		armor_thickness = target.get_armor_thickness()
	else:
		# Estimate based on ship size
		var ship_size = _get_ship_size(target)
		armor_thickness = float(ship_size) / float(ShipSizes.Size.CAPITAL)
	
	# Armor provides more resistance to kinetic weapons
	var armor_effectiveness = 0.6 if _is_kinetic_weapon(weapon_type) else 0.2
	return armor_thickness * armor_effectiveness

func _calculate_subsystem_resistance(target: Node, weapon_type: int) -> float:
	# Subsystem health affects resistance to special weapons
	var subsystem_health = 1.0
	if target.has_method("get_subsystem_performance"):
		subsystem_health = target.get_subsystem_performance("sensors")  # Sensor health affects resistance
	
	# Poor subsystem health reduces resistance
	var health_factor = max(0.0, subsystem_health - 0.3)  # Only healthy systems provide resistance
	return health_factor * 0.2  # Maximum 20% resistance from subsystem health

## Utility functions

func _get_ship_size(target: Node) -> int:
	if target.has_method("get_ship_size"):
		return target.get_ship_size()
	elif target.has_method("get_ship_class"):
		var ship_class = target.get_ship_class()
		if ship_class and ship_class.has_method("get", "ship_size"):
			return ship_class.ship_size
	
	return ShipSizes.Size.FIGHTER  # Default

func _get_ship_id(target: Node) -> String:
	if target.has_method("get_ship_id"):
		return target.get_ship_id()
	elif target.has_method("get_instance_id"):
		return str(target.get_instance_id())
	else:
		return target.name

## Get resistance system status
func get_resistance_system_status() -> Dictionary:
	return {
		"active_resistances": active_resistances.size(),
		"immunity_states": immunity_states.size(),
		"capital_ship_protections": capital_ship_protections.size(),
		"ship_size_resistance_enabled": enable_ship_size_resistance,
		"immunity_conditions_enabled": enable_immunity_conditions,
		"capital_ship_protection_enabled": enable_capital_ship_protection,
		"performance_stats": resistance_performance_stats.duplicate()
	}

## Get performance statistics
func get_resistance_performance_statistics() -> Dictionary:
	return resistance_performance_stats.duplicate()

## Get ship resistance profile
func get_ship_resistance_profile(target: Node) -> Dictionary:
	var ship_size = _get_ship_size(target)
	var resistances = ship_size_resistance.get(ship_size, {})
	
	return {
		"ship_size": ship_size,
		"base_resistances": resistances.duplicate(),
		"has_active_shields": _has_active_shields(target),
		"has_heavy_armor": _has_heavy_armor(target),
		"has_point_defense": _has_active_point_defense(target),
		"is_capital_ship": _is_capital_ship(target)
	}

## Setup resistance system
func _setup_resistance_system() -> void:
	active_resistances.clear()
	immunity_states.clear()
	capital_ship_protections.clear()
	
	# Reset performance stats
	resistance_performance_stats = {
		"total_resistance_calculations": 0,
		"immunity_activations": 0,
		"capital_protections_applied": 0,
		"resistance_modifiers_calculated": 0
	}