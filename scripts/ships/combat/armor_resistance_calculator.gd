class_name ArmorResistanceCalculator
extends Node

## Armor resistance calculation system for multiple armor types
## Handles weapon-specific damage modifications and armor effectiveness
## Implementation of SHIP-007 AC6: Armor and resistance system

# EPIC-002 Asset Core Integration
const ArmorData = preload("res://addons/wcs_asset_core/structures/armor_data.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")
const WeaponData = preload("res://addons/wcs_asset_core/structures/weapon_data.gd")

# Armor calculation signals (SHIP-007 AC6)
signal armor_damage_calculated(original_damage: float, final_damage: float, absorbed: float)
signal armor_penetrated(armor_type: String, penetration_amount: float)
signal armor_effectiveness_changed(armor_type: String, effectiveness: float)

# Armor layer types for complex armor systems
enum ArmorLayer {
	OUTER = 0,            # Outer armor layer (reactive, ablative)
	MAIN = 1,             # Main structural armor
	INNER = 2,            # Inner armor (spall liner, crew protection)
	SUBSYSTEM = 3         # Subsystem-specific armor
}

# Armor penetration types
enum PenetrationMode {
	NONE = 0,             # No penetration
	PARTIAL = 1,          # Partial penetration (reduced damage)
	FULL = 2,             # Full penetration (full damage)
	OVERPENETRATION = 3   # Overpenetration (reduced effectiveness)
}

# Armor calculation state
var ship: BaseShip
var armor_layers: Dictionary = {}  # ArmorLayer -> ArmorData
var armor_effectiveness: Dictionary = {}  # ArmorLayer -> float (0.0 to 1.0)
var armor_integrity: Dictionary = {}  # ArmorLayer -> float (0.0 to 1.0)

# Armor calculation parameters
var base_armor_thickness: float = 1.0
var armor_angle_effectiveness: bool = true
var spaced_armor_bonus: float = 1.2  # Bonus for spaced armor layers
var composite_armor_bonus: float = 1.1  # Bonus for composite armor

# Damage type armor effectiveness modifiers
var damage_type_armor_effectiveness: Dictionary = {
	DamageTypes.Type.KINETIC: 1.0,     # Standard effectiveness
	DamageTypes.Type.ENERGY: 0.8,      # Energy weapons bypass some armor
	DamageTypes.Type.PLASMA: 0.7,      # Plasma very effective vs armor
	DamageTypes.Type.EXPLOSIVE: 1.2,   # Explosive damage more affected by armor
	DamageTypes.Type.EMP: 0.0,         # EMP ignores physical armor
	DamageTypes.Type.ION: 0.3,         # Ion partially blocked by armor
	DamageTypes.Type.BEAM: 0.6,        # Beam weapons penetrate armor well
	DamageTypes.Type.PIERCING: 0.5,    # Armor-piercing reduces effectiveness
	DamageTypes.Type.SHOCKWAVE: 1.1,   # Shockwave affected by structure
	DamageTypes.Type.COLLISION: 1.3    # Collision damage heavily affected by armor
}

# Performance tracking
var calculations_performed: int = 0
var total_damage_absorbed: float = 0.0
var calculation_time_ms: float = 0.0

## Initialize armor resistance calculator
func initialize_armor_calculator(target_ship: BaseShip) -> void:
	"""Initialize armor calculator for ship.
	
	Args:
		target_ship: Ship to calculate armor for
	"""
	ship = target_ship
	
	# Load armor configuration from ship class
	if ship.ship_class:
		_load_ship_armor_configuration()
	
	# Initialize armor layers
	_initialize_armor_layers()

## Load armor configuration from ship class
func _load_ship_armor_configuration() -> void:
	"""Load armor data from ship class configuration."""
	# Load primary armor data
	if ship.ship_class.has_method("get_hull_armor"):
		var main_armor: ArmorData = ship.ship_class.get_hull_armor()
		if main_armor:
			armor_layers[ArmorLayer.MAIN] = main_armor
	
	# Load additional armor layers if available
	if ship.ship_class.has_method("get_armor_layers"):
		var additional_layers: Dictionary = ship.ship_class.get_armor_layers()
		for layer in additional_layers.keys():
			armor_layers[layer] = additional_layers[layer]

## Initialize armor layers and effectiveness
func _initialize_armor_layers() -> void:
	"""Initialize armor layer effectiveness and integrity."""
	for layer in ArmorLayer.values():
		armor_effectiveness[layer] = 1.0  # Full effectiveness initially
		armor_integrity[layer] = 1.0      # Full integrity initially

## Calculate armor resistance against damage (SHIP-007 AC6)
func calculate_armor_resistance(damage: float, damage_data: Dictionary) -> Dictionary:
	"""Calculate armor resistance and final damage after armor.
	
	Args:
		damage: Base damage amount
		damage_data: Damage information including type and modifiers
	
	Returns:
		Dictionary with armor calculation results:
			- final_damage (float): Damage after armor resistance
			- damage_absorbed (float): Damage absorbed by armor
			- penetration_mode (PenetrationMode): Type of armor penetration
			- armor_layers_affected (Array): Layers that absorbed damage
			- armor_effectiveness_used (float): Overall armor effectiveness
	"""
	var start_time: int = Time.get_ticks_msec()
	var result: Dictionary = {
		"final_damage": damage,
		"damage_absorbed": 0.0,
		"penetration_mode": PenetrationMode.NONE,
		"armor_layers_affected": [],
		"armor_effectiveness_used": 0.0
	}
	
	if damage <= 0.0:
		return result
	
	# Get damage type and modifiers
	var damage_type: String = damage_data.get("damage_type", "kinetic")
	var armor_piercing: float = damage_data.get("armor_piercing", 0.0)
	var impact_angle: float = damage_data.get("impact_angle", 0.0)
	
	# Calculate damage through each armor layer
	var remaining_damage: float = damage
	var total_absorbed: float = 0.0
	var layers_affected: Array = []
	
	# Process armor layers in order (outer to inner)
	var layer_order: Array[ArmorLayer] = [ArmorLayer.OUTER, ArmorLayer.MAIN, ArmorLayer.INNER, ArmorLayer.SUBSYSTEM]
	
	for layer in layer_order:
		if armor_layers.has(layer) and remaining_damage > 0.0:
			var layer_result: Dictionary = _calculate_layer_resistance(remaining_damage, layer, damage_data)
			
			var layer_absorbed: float = layer_result["damage_absorbed"]
			remaining_damage -= layer_absorbed
			total_absorbed += layer_absorbed
			
			if layer_absorbed > 0.0:
				layers_affected.append(layer)
			
			# Check for penetration
			if layer_result["penetrated"]:
				result["penetration_mode"] = layer_result["penetration_mode"]
	
	# Calculate final results
	result["final_damage"] = remaining_damage
	result["damage_absorbed"] = total_absorbed
	result["armor_layers_affected"] = layers_affected
	result["armor_effectiveness_used"] = _calculate_overall_effectiveness(damage_data)
	
	# Update performance tracking
	calculations_performed += 1
	total_damage_absorbed += total_absorbed
	calculation_time_ms += Time.get_ticks_msec() - start_time
	
	# Emit armor calculation signal
	armor_damage_calculated.emit(damage, remaining_damage, total_absorbed)
	
	return result

## Calculate resistance for a specific armor layer
func _calculate_layer_resistance(damage: float, layer: ArmorLayer, damage_data: Dictionary) -> Dictionary:
	"""Calculate damage resistance for a specific armor layer.
	
	Args:
		damage: Damage amount hitting this layer
		layer: Armor layer to calculate for
		damage_data: Damage information
	
	Returns:
		Dictionary with layer calculation results
	"""
	var result: Dictionary = {
		"damage_absorbed": 0.0,
		"penetrated": false,
		"penetration_mode": PenetrationMode.NONE
	}
	
	if not armor_layers.has(layer):
		return result
	
	var armor: ArmorData = armor_layers[layer]
	var layer_effectiveness: float = armor_effectiveness[layer]
	var layer_integrity: float = armor_integrity[layer]
	
	# Get damage type and modifiers
	var damage_type: String = damage_data.get("damage_type", "kinetic")
	var armor_piercing: float = damage_data.get("armor_piercing", 0.0)
	var impact_angle: float = damage_data.get("impact_angle", 0.0)
	
	# Calculate base armor resistance
	var armor_multiplier: float = armor.get_damage_multiplier(damage_type)
	
	# Apply armor piercing
	if armor_piercing > 0.0:
		armor_multiplier = lerp(armor_multiplier, 1.0, armor_piercing)
	
	# Apply impact angle (if enabled)
	if armor_angle_effectiveness and impact_angle > 0.0:
		var angle_factor: float = _calculate_angle_effectiveness(impact_angle)
		armor_multiplier *= angle_factor
	
	# Apply layer effectiveness and integrity
	armor_multiplier = lerp(1.0, armor_multiplier, layer_effectiveness * layer_integrity)
	
	# Apply damage type armor effectiveness
	var damage_type_enum: DamageTypes.Type = _get_damage_type_enum(damage_type)
	if damage_type_armor_effectiveness.has(damage_type_enum):
		var type_effectiveness: float = damage_type_armor_effectiveness[damage_type_enum]
		armor_multiplier = lerp(1.0, armor_multiplier, type_effectiveness)
	
	# Calculate damage absorbed
	var damage_absorbed: float = damage * (1.0 - armor_multiplier)
	var penetrating_damage: float = damage - damage_absorbed
	
	# Determine penetration mode
	if penetrating_damage <= 0.0:
		result["penetration_mode"] = PenetrationMode.NONE
	elif damage_absorbed > damage * 0.5:
		result["penetration_mode"] = PenetrationMode.PARTIAL
		result["penetrated"] = true
	elif damage_absorbed > damage * 0.1:
		result["penetration_mode"] = PenetrationMode.FULL
		result["penetrated"] = true
	else:
		result["penetration_mode"] = PenetrationMode.OVERPENETRATION
		result["penetrated"] = true
	
	result["damage_absorbed"] = damage_absorbed
	
	# Emit penetration signal if applicable
	if result["penetrated"]:
		armor_penetrated.emit(armor.armor_name, penetrating_damage)
	
	return result

## Calculate impact angle effectiveness
func _calculate_angle_effectiveness(impact_angle: float) -> float:
	"""Calculate armor effectiveness based on impact angle.
	
	Args:
		impact_angle: Impact angle in degrees (0 = perpendicular, 90 = glancing)
	
	Returns:
		Angle effectiveness multiplier
	"""
	# Convert to radians and calculate effectiveness
	var angle_rad: float = deg_to_rad(impact_angle)
	var effectiveness: float = cos(angle_rad)  # Perpendicular hits are most effective
	
	# Apply minimum effectiveness (even glancing hits do some damage)
	return max(0.1, effectiveness)

## Calculate overall armor effectiveness
func _calculate_overall_effectiveness(damage_data: Dictionary) -> float:
	"""Calculate overall armor system effectiveness.
	
	Args:
		damage_data: Damage information
	
	Returns:
		Overall effectiveness (0.0 to 1.0)
	"""
	var total_effectiveness: float = 0.0
	var layer_count: int = 0
	
	for layer in armor_layers.keys():
		var layer_effectiveness: float = armor_effectiveness[layer]
		var layer_integrity: float = armor_integrity[layer]
		total_effectiveness += layer_effectiveness * layer_integrity
		layer_count += 1
	
	if layer_count > 0:
		return total_effectiveness / layer_count
	
	return 0.0

## Get damage type enum from string
func _get_damage_type_enum(damage_type: String) -> DamageTypes.Type:
	"""Convert damage type string to enum value.
	
	Args:
		damage_type: Damage type name
	
	Returns:
		Corresponding damage type enum
	"""
	match damage_type.to_lower():
		"kinetic":
			return DamageTypes.Type.KINETIC
		"energy":
			return DamageTypes.Type.ENERGY
		"plasma":
			return DamageTypes.Type.PLASMA
		"explosive":
			return DamageTypes.Type.EXPLOSIVE
		"emp":
			return DamageTypes.Type.EMP
		"ion":
			return DamageTypes.Type.ION
		"beam":
			return DamageTypes.Type.BEAM
		"piercing":
			return DamageTypes.Type.PIERCING
		"shockwave":
			return DamageTypes.Type.SHOCKWAVE
		"collision":
			return DamageTypes.Type.COLLISION
		_:
			return DamageTypes.Type.KINETIC

## Armor management functions

func set_armor_effectiveness(layer: ArmorLayer, effectiveness: float) -> void:
	"""Set effectiveness for armor layer.
	
	Args:
		layer: Armor layer to modify
		effectiveness: Effectiveness value (0.0 to 1.0)
	"""
	armor_effectiveness[layer] = clamp(effectiveness, 0.0, 1.0)
	armor_effectiveness_changed.emit(_get_layer_name(layer), effectiveness)

func damage_armor_layer(layer: ArmorLayer, integrity_loss: float) -> void:
	"""Damage armor layer integrity.
	
	Args:
		layer: Armor layer to damage
		integrity_loss: Amount of integrity to lose (0.0 to 1.0)
	"""
	if armor_integrity.has(layer):
		armor_integrity[layer] = max(0.0, armor_integrity[layer] - integrity_loss)

func repair_armor_layer(layer: ArmorLayer, integrity_gain: float) -> void:
	"""Repair armor layer integrity.
	
	Args:
		layer: Armor layer to repair
		integrity_gain: Amount of integrity to restore (0.0 to 1.0)
	"""
	if armor_integrity.has(layer):
		armor_integrity[layer] = min(1.0, armor_integrity[layer] + integrity_gain)

func get_armor_layer_status(layer: ArmorLayer) -> Dictionary:
	"""Get status information for armor layer.
	
	Args:
		layer: Armor layer to check
	
	Returns:
		Dictionary with layer status information
	"""
	var status: Dictionary = {
		"has_armor": armor_layers.has(layer),
		"effectiveness": armor_effectiveness.get(layer, 0.0),
		"integrity": armor_integrity.get(layer, 0.0),
		"armor_name": "",
		"armor_type": ""
	}
	
	if armor_layers.has(layer):
		var armor: ArmorData = armor_layers[layer]
		status["armor_name"] = armor.armor_name
		status["armor_type"] = armor.get_asset_type_name()
	
	return status

func _get_layer_name(layer: ArmorLayer) -> String:
	"""Get human-readable name for armor layer.
	
	Args:
		layer: Armor layer enum
	
	Returns:
		Layer name string
	"""
	match layer:
		ArmorLayer.OUTER:
			return "Outer Armor"
		ArmorLayer.MAIN:
			return "Main Armor"
		ArmorLayer.INNER:
			return "Inner Armor"
		ArmorLayer.SUBSYSTEM:
			return "Subsystem Armor"
		_:
			return "Unknown Armor"

## Performance and diagnostic functions

func get_armor_stats() -> Dictionary:
	"""Get comprehensive armor system statistics.
	
	Returns:
		Dictionary with armor metrics
	"""
	var stats: Dictionary = {
		"calculations_performed": calculations_performed,
		"total_damage_absorbed": total_damage_absorbed,
		"average_calculation_time_ms": calculation_time_ms / max(1, calculations_performed),
		"armor_layers": {},
		"overall_effectiveness": _calculate_overall_effectiveness({}),
		"damage_type_modifiers": damage_type_armor_effectiveness
	}
	
	# Add layer-specific information
	for layer in armor_layers.keys():
		stats["armor_layers"][_get_layer_name(layer)] = get_armor_layer_status(layer)
	
	return stats

func reset_armor_stats() -> void:
	"""Reset armor calculation statistics."""
	calculations_performed = 0
	total_damage_absorbed = 0.0
	calculation_time_ms = 0.0

func get_debug_info() -> String:
	"""Get debug information about armor system.
	
	Returns:
		Formatted debug information string
	"""
	var info: Array[String] = []
	info.append("=== Armor Resistance Calculator ===")
	info.append("Calculations: %d" % calculations_performed)
	info.append("Total Absorbed: %.1f" % total_damage_absorbed)
	info.append("Overall Effectiveness: %.1f%%" % (_calculate_overall_effectiveness({}) * 100.0))
	
	info.append("\nArmor Layers:")
	for layer in armor_layers.keys():
		var layer_name: String = _get_layer_name(layer)
		var effectiveness: float = armor_effectiveness.get(layer, 0.0)
		var integrity: float = armor_integrity.get(layer, 0.0)
		info.append("  %s: %.1f%% eff, %.1f%% int" % [layer_name, effectiveness * 100.0, integrity * 100.0])
	
	return "\n".join(info)

## Testing and validation functions

func apply_test_damage(damage: float, damage_type: String = "kinetic") -> Dictionary:
	"""Apply test damage for validation and debugging.
	
	Args:
		damage: Damage amount to test
		damage_type: Type of damage to apply
	
	Returns:
		Armor calculation results
	"""
	var test_damage_data: Dictionary = {
		"amount": damage,
		"damage_type": damage_type,
		"armor_piercing": 0.0,
		"impact_angle": 0.0
	}
	
	return calculate_armor_resistance(damage, test_damage_data)

func validate_armor_configuration() -> Array[String]:
	"""Validate armor configuration for errors.
	
	Returns:
		Array of validation error messages
	"""
	var errors: Array[String] = []
	
	# Check for armor data validity
	for layer in armor_layers.keys():
		var armor: ArmorData = armor_layers[layer]
		if not armor:
			errors.append("Missing armor data for layer: %s" % _get_layer_name(layer))
		elif not armor.is_valid():
			errors.append("Invalid armor data for layer: %s" % _get_layer_name(layer))
	
	# Check effectiveness values
	for layer in armor_effectiveness.keys():
		var effectiveness: float = armor_effectiveness[layer]
		if effectiveness < 0.0 or effectiveness > 1.0:
			errors.append("Invalid effectiveness for layer %s: %.2f" % [_get_layer_name(layer), effectiveness])
	
	# Check integrity values
	for layer in armor_integrity.keys():
		var integrity: float = armor_integrity[layer]
		if integrity < 0.0 or integrity > 1.0:
			errors.append("Invalid integrity for layer %s: %.2f" % [_get_layer_name(layer), integrity])
	
	return errors