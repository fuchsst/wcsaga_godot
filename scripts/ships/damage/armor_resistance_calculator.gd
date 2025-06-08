class_name ArmorResistanceCalculator
extends Node

## Armor resistance calculation system implementing WCS-authentic damage reduction mechanics
## Handles material-based armor resistance, angle-of-impact calculations, and penetration mechanics (SHIP-009 AC3)

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Armor resistance calculation signals
signal armor_penetrated(damage_type: int, penetration_depth: float)
signal armor_absorbed(damage_type: int, absorbed_amount: float)
signal critical_penetration(damage_type: int, location: Vector3)

# WCS-Authentic Armor Type Definitions (from armor.tbl)
enum ArmorClass {
	NONE = 0,           # No armor protection
	LIGHT = 1,          # Light fighter armor
	STANDARD = 2,       # Standard ship armor  
	HEAVY = 3,          # Heavy ship armor
	CAPITAL = 4,        # Capital ship armor
	SUPER_CAPITAL = 5   # Super capital armor
}

# Armor resistance matrices (damage reduction by type vs armor)
var armor_resistance_matrix: Dictionary = {
	ArmorClass.NONE: {
		DamageTypes.Type.KINETIC: 0.0,
		DamageTypes.Type.ENERGY: 0.0,
		DamageTypes.Type.EXPLOSIVE: 0.0,
		DamageTypes.Type.BEAM: 0.0,
		DamageTypes.Type.PLASMA: 0.0
	},
	ArmorClass.LIGHT: {
		DamageTypes.Type.KINETIC: 0.15,    # 15% reduction
		DamageTypes.Type.ENERGY: 0.05,     # 5% reduction
		DamageTypes.Type.EXPLOSIVE: 0.25,  # 25% reduction
		DamageTypes.Type.BEAM: 0.10,       # 10% reduction
		DamageTypes.Type.PLASMA: 0.20      # 20% reduction
	},
	ArmorClass.STANDARD: {
		DamageTypes.Type.KINETIC: 0.30,    # 30% reduction
		DamageTypes.Type.ENERGY: 0.15,     # 15% reduction
		DamageTypes.Type.EXPLOSIVE: 0.40,  # 40% reduction
		DamageTypes.Type.BEAM: 0.25,       # 25% reduction
		DamageTypes.Type.PLASMA: 0.35      # 35% reduction
	},
	ArmorClass.HEAVY: {
		DamageTypes.Type.KINETIC: 0.50,    # 50% reduction
		DamageTypes.Type.ENERGY: 0.25,     # 25% reduction
		DamageTypes.Type.EXPLOSIVE: 0.60,  # 60% reduction
		DamageTypes.Type.BEAM: 0.40,       # 40% reduction
		DamageTypes.Type.PLASMA: 0.55      # 55% reduction
	},
	ArmorClass.CAPITAL: {
		DamageTypes.Type.KINETIC: 0.70,    # 70% reduction
		DamageTypes.Type.ENERGY: 0.45,     # 45% reduction
		DamageTypes.Type.EXPLOSIVE: 0.75,  # 75% reduction
		DamageTypes.Type.BEAM: 0.60,       # 60% reduction
		DamageTypes.Type.PLASMA: 0.70      # 70% reduction
	},
	ArmorClass.SUPER_CAPITAL: {
		DamageTypes.Type.KINETIC: 0.85,    # 85% reduction
		DamageTypes.Type.ENERGY: 0.65,     # 65% reduction
		DamageTypes.Type.EXPLOSIVE: 0.90,  # 90% reduction
		DamageTypes.Type.BEAM: 0.75,       # 75% reduction
		DamageTypes.Type.PLASMA: 0.85      # 85% reduction
	}
}

# Angle-of-impact effectiveness modifiers (SHIP-009 AC3)
var angle_effectiveness: Dictionary = {
	"head_on": 1.0,         # 90-degree impact (full effectiveness)
	"angled": 0.75,         # 45-60 degree impact
	"glancing": 0.5,        # 15-45 degree impact
	"deflection": 0.25      # 0-15 degree impact
}

# Penetration depth tracking for progressive damage
var penetration_tracking: Dictionary = {}

func _ready() -> void:
	name = "ArmorResistanceCalculator"

## Calculate damage reduction based on armor type, thickness, and impact parameters (SHIP-009 AC3)
func calculate_damage_reduction(damage_amount: float, damage_type: int, armor_type: int, armor_thickness: float, impact_location: Vector3, impact_velocity: Vector3 = Vector3.ZERO) -> float:
	"""Calculate armor damage reduction with WCS-authentic mechanics.
	
	Args:
		damage_amount: Base damage amount before armor
		damage_type: Type of damage from DamageTypes enum
		armor_type: Armor class from ArmorClass enum
		armor_thickness: Effective armor thickness at impact point
		impact_location: Local coordinates of impact
		impact_velocity: Velocity vector of impacting projectile
		
	Returns:
		Amount of damage absorbed by armor
	"""
	if damage_amount <= 0.0 or armor_type == ArmorClass.NONE:
		return 0.0
	
	# Get base armor resistance
	var base_resistance: float = _get_base_armor_resistance(armor_type, damage_type)
	if base_resistance <= 0.0:
		return 0.0
	
	# Calculate angle-of-impact modifier
	var angle_modifier: float = _calculate_angle_modifier(impact_location, impact_velocity)
	
	# Calculate thickness modifier
	var thickness_modifier: float = _calculate_thickness_modifier(armor_thickness)
	
	# Calculate penetration effects
	var penetration_modifier: float = _calculate_penetration_modifier(impact_location, damage_type)
	
	# Combine all modifiers
	var effective_resistance: float = base_resistance * angle_modifier * thickness_modifier * penetration_modifier
	effective_resistance = clamp(effective_resistance, 0.0, 0.95)  # Max 95% reduction
	
	# Calculate damage reduction
	var damage_reduction: float = damage_amount * effective_resistance
	
	# Check for penetration
	var remaining_damage: float = damage_amount - damage_reduction
	if remaining_damage > damage_amount * 0.5:  # More than 50% penetrates
		_process_armor_penetration(impact_location, damage_type, remaining_damage)
	
	# Emit appropriate signals
	if damage_reduction > 0.0:
		armor_absorbed.emit(damage_type, damage_reduction)
	
	return damage_reduction

## Get base armor resistance from resistance matrix
func _get_base_armor_resistance(armor_type: int, damage_type: int) -> float:
	"""Get base armor resistance percentage from resistance matrix."""
	if not armor_resistance_matrix.has(armor_type):
		return 0.0
	
	var armor_data: Dictionary = armor_resistance_matrix[armor_type]
	return armor_data.get(damage_type, 0.0)

## Calculate angle-of-impact modifier (SHIP-009 AC3)
func _calculate_angle_modifier(impact_location: Vector3, impact_velocity: Vector3) -> float:
	"""Calculate angle-of-impact effectiveness modifier."""
	if impact_velocity.length() < 0.1:
		return 1.0  # No velocity data, assume head-on
	
	# Calculate surface normal at impact point (simplified to location normal)
	var surface_normal: Vector3 = impact_location.normalized()
	if surface_normal.length() < 0.1:
		surface_normal = Vector3.UP  # Fallback normal
	
	# Calculate impact angle (0 = head-on, 90 = parallel/glancing)
	var impact_direction: Vector3 = impact_velocity.normalized()
	var dot_product: float = abs(surface_normal.dot(-impact_direction))
	var impact_angle_degrees: float = acos(clamp(dot_product, 0.0, 1.0)) * 180.0 / PI
	
	# Determine angle category and modifier
	if impact_angle_degrees <= 15.0:
		return angle_effectiveness.deflection
	elif impact_angle_degrees <= 45.0:
		return angle_effectiveness.glancing
	elif impact_angle_degrees <= 60.0:
		return angle_effectiveness.angled
	else:
		return angle_effectiveness.head_on

## Calculate armor thickness modifier
func _calculate_thickness_modifier(armor_thickness: float) -> float:
	"""Calculate armor effectiveness based on thickness."""
	# Thickness modifier: linear scaling with diminishing returns
	var base_thickness: float = 1.0
	var thickness_ratio: float = armor_thickness / base_thickness
	
	# Logarithmic scaling for realistic armor effectiveness
	return 1.0 + log(thickness_ratio) * 0.2

## Calculate penetration modifier based on accumulated damage (SHIP-009 AC3)
func _calculate_penetration_modifier(impact_location: Vector3, damage_type: int) -> float:
	"""Calculate modifier based on accumulated penetration at location."""
	var location_key: String = _get_location_key(impact_location)
	
	if not penetration_tracking.has(location_key):
		penetration_tracking[location_key] = {"total_damage": 0.0, "penetration_depth": 0.0}
	
	var location_data: Dictionary = penetration_tracking[location_key]
	var penetration_depth: float = location_data.penetration_depth
	
	# Reduced effectiveness for deep penetrations
	if penetration_depth > 2.0:
		return 0.5  # 50% effectiveness
	elif penetration_depth > 1.0:
		return 0.75  # 75% effectiveness
	else:
		return 1.0  # Full effectiveness

## Process armor penetration effects (SHIP-009 AC3)
func _process_armor_penetration(impact_location: Vector3, damage_type: int, penetrating_damage: float) -> void:
	"""Process armor penetration and track cumulative effects."""
	var location_key: String = _get_location_key(impact_location)
	
	if not penetration_tracking.has(location_key):
		penetration_tracking[location_key] = {"total_damage": 0.0, "penetration_depth": 0.0}
	
	var location_data: Dictionary = penetration_tracking[location_key]
	location_data.total_damage += penetrating_damage
	location_data.penetration_depth += penetrating_damage * 0.01  # 1% depth per point of damage
	
	# Emit penetration signal
	armor_penetrated.emit(damage_type, location_data.penetration_depth)
	
	# Check for critical penetration
	if location_data.penetration_depth > 3.0:
		critical_penetration.emit(damage_type, impact_location)

## Get location key for penetration tracking
func _get_location_key(location: Vector3) -> String:
	"""Generate location key for penetration tracking (spatial hashing)."""
	var grid_size: float = 2.0  # 2-unit grid for tracking
	var grid_x: int = int(location.x / grid_size)
	var grid_y: int = int(location.y / grid_size)
	var grid_z: int = int(location.z / grid_size)
	return "%d_%d_%d" % [grid_x, grid_y, grid_z]

## Calculate armor piercing effectiveness (for special weapons)
func calculate_piercing_effectiveness(base_damage: float, piercing_value: float, armor_type: int) -> float:
	"""Calculate armor piercing effectiveness for AP weapons.
	
	Args:
		base_damage: Base weapon damage
		piercing_value: Weapon armor piercing value
		armor_type: Target armor type
		
	Returns:
		Damage multiplier for armor piercing
	"""
	if piercing_value <= 0.0:
		return 1.0
	
	# Get armor resistance without piercing
	var base_resistance: float = _get_base_armor_resistance(armor_type, DamageTypes.Type.KINETIC)
	
	# Calculate piercing effectiveness
	var piercing_multiplier: float = 1.0 + (piercing_value * 0.01)  # 1% per piercing point
	var effective_resistance: float = base_resistance / piercing_multiplier
	effective_resistance = max(0.0, effective_resistance)  # Cannot go negative
	
	# Return damage multiplier
	var damage_multiplier: float = (base_resistance - effective_resistance) + 1.0
	return clamp(damage_multiplier, 1.0, 3.0)  # Max 3x damage from piercing

## Check if damage type is effective against armor type
func is_damage_type_effective(damage_type: int, armor_type: int, effectiveness_threshold: float = 0.3) -> bool:
	"""Check if damage type is effective against armor type.
	
	Args:
		damage_type: Damage type to check
		armor_type: Target armor type
		effectiveness_threshold: Minimum effectiveness to consider effective
		
	Returns:
		true if damage type is effective
	"""
	var resistance: float = _get_base_armor_resistance(armor_type, damage_type)
	var effectiveness: float = 1.0 - resistance
	return effectiveness >= effectiveness_threshold

## Get armor vulnerability report
func get_armor_vulnerability_report(armor_type: int) -> Dictionary:
	"""Get vulnerability analysis for armor type.
	
	Args:
		armor_type: Armor type to analyze
		
	Returns:
		Dictionary with vulnerability information
	"""
	var vulnerabilities: Dictionary = {}
	var resistances: Dictionary = {}
	
	if armor_resistance_matrix.has(armor_type):
		var armor_data: Dictionary = armor_resistance_matrix[armor_type]
		
		for damage_type in armor_data.keys():
			var resistance: float = armor_data[damage_type]
			var effectiveness: float = 1.0 - resistance
			
			resistances[DamageTypes.get_damage_type_name(damage_type)] = resistance * 100.0
			
			if effectiveness >= 0.7:
				vulnerabilities[DamageTypes.get_damage_type_name(damage_type)] = "High"
			elif effectiveness >= 0.4:
				vulnerabilities[DamageTypes.get_damage_type_name(damage_type)] = "Medium"
			else:
				vulnerabilities[DamageTypes.get_damage_type_name(damage_type)] = "Low"
	
	return {
		"armor_class": "ArmorClass_%d" % armor_type,
		"resistances": resistances,
		"vulnerabilities": vulnerabilities,
		"penetration_locations": penetration_tracking.size()
	}

## Reset penetration tracking (for repairs or new encounters)
func reset_penetration_tracking() -> void:
	"""Reset accumulated penetration damage."""
	penetration_tracking.clear()

## Get save data for armor penetration state
func get_armor_save_data() -> Dictionary:
	"""Get armor calculator save data for persistence."""
	return {
		"penetration_tracking": penetration_tracking
	}

## Load armor save data from persistence
func load_armor_save_data(save_data: Dictionary) -> bool:
	"""Load armor calculator save data from persistence."""
	if not save_data:
		return false
	
	if save_data.has("penetration_tracking"):
		penetration_tracking = save_data.penetration_tracking
	
	return true

## Get debug information
func debug_info() -> String:
	"""Get debug information string."""
	return "[ArmorCalc Penetrations:%d]" % penetration_tracking.size()