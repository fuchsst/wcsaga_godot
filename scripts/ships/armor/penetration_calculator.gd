class_name PenetrationCalculator
extends Node

## SHIP-011 AC2: Impact Angle Calculations
## Determines penetration effectiveness based on hit vector and armor surface orientation
## Implements WCS-authentic angle-based armor effectiveness and deflection mechanics

# EPIC-002 Asset Core Integration
const ArmorTypes = preload("res://addons/wcs_asset_core/constants/armor_types.gd")
const DamageTypes = preload("res://addons/wcs_asset_core/constants/damage_types.gd")

# Signals
signal penetration_calculated(impact_data: Dictionary, penetration_result: Dictionary)
signal deflection_occurred(impact_angle: float, deflection_angle: float)
signal critical_angle_hit(impact_angle: float, effectiveness_bonus: float)

# Penetration calculation data
var angle_effectiveness_curves: Dictionary = {}
var armor_surface_normals: Dictionary = {}
var penetration_thresholds: Dictionary = {}

# Configuration
@export var enable_realistic_physics: bool = true
@export var enable_deflection_mechanics: bool = true
@export var enable_ricochet_calculation: bool = true
@export var debug_penetration_logging: bool = false

# Penetration parameters
@export var minimum_penetration_angle: float = 15.0  # Degrees - minimum angle for any penetration
@export var maximum_effectiveness_angle: float = 30.0  # Degrees - angle for maximum effectiveness
@export var deflection_threshold_angle: float = 70.0  # Degrees - angle where deflection becomes likely
@export var ricochet_probability_angle: float = 80.0  # Degrees - angle where ricochet is highly likely

# Physics constants
@export var armor_hardness_factor: float = 1.0
@export var velocity_penetration_factor: float = 0.8
@export var mass_penetration_factor: float = 0.6

func _ready() -> void:
	_setup_angle_effectiveness_curves()
	_setup_penetration_thresholds()

## Calculate penetration effectiveness based on impact angle and conditions
func calculate_penetration_effectiveness(
	impact_vector: Vector3,
	surface_normal: Vector3,
	armor_type: int,
	damage_type: int,
	impact_conditions: Dictionary = {}
) -> Dictionary:
	
	# Calculate impact angle
	var impact_angle = _calculate_impact_angle(impact_vector, surface_normal)
	
	# Get base penetration data
	var base_effectiveness = _get_base_angle_effectiveness(impact_angle, armor_type)
	var deflection_probability = _calculate_deflection_probability(impact_angle, armor_type, damage_type)
	var ricochet_probability = _calculate_ricochet_probability(impact_angle, impact_conditions)
	
	# Apply damage type modifiers
	var damage_modifier = _get_damage_type_angle_modifier(damage_type, impact_angle)
	
	# Apply velocity and mass effects
	var kinetic_modifier = _calculate_kinetic_effects(impact_conditions, damage_type)
	
	# Calculate final effectiveness
	var final_effectiveness = base_effectiveness * damage_modifier * kinetic_modifier
	final_effectiveness = clamp(final_effectiveness, 0.0, 1.0)
	
	# Determine penetration result
	var penetration_result = _determine_penetration_result(
		final_effectiveness,
		deflection_probability,
		ricochet_probability,
		impact_angle
	)
	
	# Create result data
	var result: Dictionary = {
		"impact_angle": impact_angle,
		"base_effectiveness": base_effectiveness,
		"damage_modifier": damage_modifier,
		"kinetic_modifier": kinetic_modifier,
		"final_effectiveness": final_effectiveness,
		"deflection_probability": deflection_probability,
		"ricochet_probability": ricochet_probability,
		"penetration_result": penetration_result,
		"armor_type": armor_type,
		"damage_type": damage_type
	}
	
	# Emit signals
	penetration_calculated.emit(impact_conditions, result)
	
	if penetration_result == "deflected":
		var deflection_angle = _calculate_deflection_angle(impact_angle, surface_normal)
		deflection_occurred.emit(impact_angle, deflection_angle)
	
	if impact_angle <= maximum_effectiveness_angle:
		var effectiveness_bonus = (maximum_effectiveness_angle - impact_angle) / maximum_effectiveness_angle
		critical_angle_hit.emit(impact_angle, effectiveness_bonus)
	
	if debug_penetration_logging:
		print("PenetrationCalculator: Impact %.1f° vs %s armor: %.1f%% effectiveness (%s)" % [
			impact_angle,
			ArmorTypes.get_armor_class_name(armor_type),
			final_effectiveness * 100,
			penetration_result
		])
	
	return result

## Calculate optimal attack angle for maximum penetration
func calculate_optimal_attack_angle(
	target_position: Vector3,
	target_surface_normal: Vector3,
	attacker_position: Vector3,
	armor_type: int,
	damage_type: int
) -> Dictionary:
	
	var optimal_angle = 0.0  # Perpendicular is optimal
	var optimal_effectiveness = 0.0
	var recommended_position: Vector3
	
	# Test angles in 5-degree increments
	for angle_deg in range(0, 91, 5):
		var test_angle = deg_to_rad(angle_deg)
		
		# Calculate hypothetical effectiveness at this angle
		var test_effectiveness = _get_base_angle_effectiveness(angle_deg, armor_type)
		var damage_modifier = _get_damage_type_angle_modifier(damage_type, angle_deg)
		var total_effectiveness = test_effectiveness * damage_modifier
		
		if total_effectiveness > optimal_effectiveness:
			optimal_effectiveness = total_effectiveness
			optimal_angle = angle_deg
	
	# Calculate recommended attack position
	recommended_position = _calculate_optimal_position(
		target_position,
		target_surface_normal,
		attacker_position,
		optimal_angle
	)
	
	return {
		"optimal_angle": optimal_angle,
		"optimal_effectiveness": optimal_effectiveness,
		"recommended_position": recommended_position,
		"current_angle": _calculate_impact_angle(
			(target_position - attacker_position).normalized(),
			target_surface_normal
		),
		"improvement_factor": optimal_effectiveness / max(0.1, _get_base_angle_effectiveness(
			_calculate_impact_angle(
				(target_position - attacker_position).normalized(),
				target_surface_normal
			), armor_type
		))
	}

## Calculate armor vulnerability zones based on surface geometry
func calculate_armor_vulnerability_zones(ship_mesh: MeshInstance3D, armor_configuration: Dictionary) -> Array[Dictionary]:
	var vulnerability_zones: Array[Dictionary] = []
	
	if not ship_mesh or not ship_mesh.mesh:
		return vulnerability_zones
	
	# Analyze mesh surface normals to find vulnerable angles
	var mesh_data = ship_mesh.mesh
	if mesh_data is ArrayMesh:
		var arrays = mesh_data.surface_get_arrays(0)
		var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		
		if vertices.size() == normals.size():
			for i in range(vertices.size()):
				var vertex = vertices[i]
				var normal = normals[i]
				
				# Calculate vulnerability based on surface angle
				var vulnerability_factor = _calculate_surface_vulnerability(normal, armor_configuration)
				
				if vulnerability_factor > 0.7:  # High vulnerability threshold
					vulnerability_zones.append({
						"position": vertex,
						"normal": normal,
						"vulnerability_factor": vulnerability_factor,
						"recommended_attack_angle": _get_optimal_attack_angle_for_surface(normal),
						"armor_type": armor_configuration.get("default_armor_type", ArmorTypes.Class.STANDARD)
					})
	
	# Sort by vulnerability (highest first)
	vulnerability_zones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["vulnerability_factor"] > b["vulnerability_factor"]
	)
	
	return vulnerability_zones

## Calculate impact angle between impact vector and surface normal
func _calculate_impact_angle(impact_vector: Vector3, surface_normal: Vector3) -> float:
	if impact_vector.length() == 0.0 or surface_normal.length() == 0.0:
		return 90.0  # Glancing blow if invalid vectors
	
	# Normalize vectors
	var impact_normalized = impact_vector.normalized()
	var normal_normalized = surface_normal.normalized()
	
	# Calculate dot product to get cosine of angle
	var dot_product = impact_normalized.dot(normal_normalized)
	dot_product = clamp(dot_product, -1.0, 1.0)
	
	# Convert to angle in degrees
	var angle_rad = acos(abs(dot_product))
	var angle_deg = rad_to_deg(angle_rad)
	
	return angle_deg

## Get base effectiveness based on impact angle
func _get_base_angle_effectiveness(impact_angle: float, armor_type: int) -> float:
	var curve = angle_effectiveness_curves.get(armor_type, {})
	
	# WCS-authentic angle effectiveness calculation
	if impact_angle <= maximum_effectiveness_angle:
		# Maximum effectiveness at perpendicular angles
		return curve.get("max_effectiveness", 1.0)
	elif impact_angle >= deflection_threshold_angle:
		# Minimal effectiveness at glancing angles
		return curve.get("min_effectiveness", 0.1)
	else:
		# Linear interpolation between maximum and deflection threshold
		var range_factor = (impact_angle - maximum_effectiveness_angle) / (deflection_threshold_angle - maximum_effectiveness_angle)
		var max_eff = curve.get("max_effectiveness", 1.0)
		var min_eff = curve.get("min_effectiveness", 0.1)
		return max_eff - (range_factor * (max_eff - min_eff))

## Calculate deflection probability based on angle and armor
func _calculate_deflection_probability(impact_angle: float, armor_type: int, damage_type: int) -> float:
	if not enable_deflection_mechanics:
		return 0.0
	
	if impact_angle < minimum_penetration_angle:
		return 1.0  # Always deflect at very shallow angles
	elif impact_angle >= deflection_threshold_angle:
		# Increasing deflection probability at glancing angles
		var deflection_factor = (impact_angle - deflection_threshold_angle) / (90.0 - deflection_threshold_angle)
		return 0.3 + (deflection_factor * 0.6)  # 30% to 90% deflection chance
	else:
		return 0.0  # No deflection at good angles

## Calculate ricochet probability
func _calculate_ricochet_probability(impact_angle: float, impact_conditions: Dictionary) -> float:
	if not enable_ricochet_calculation:
		return 0.0
	
	if impact_angle >= ricochet_probability_angle:
		var ricochet_factor = (impact_angle - ricochet_probability_angle) / (90.0 - ricochet_probability_angle)
		
		# Velocity affects ricochet - higher velocity reduces ricochet chance
		var velocity = impact_conditions.get("velocity", 100.0)
		var velocity_modifier = clamp(1.0 - (velocity / 1000.0), 0.2, 1.0)
		
		return ricochet_factor * velocity_modifier
	
	return 0.0

## Get damage type modifier for angle effectiveness
func _get_damage_type_angle_modifier(damage_type: int, impact_angle: float) -> float:
	match damage_type:
		DamageTypes.Type.KINETIC:
			# Kinetic weapons benefit more from perpendicular impacts
			if impact_angle <= 30.0:
				return 1.2  # 20% bonus for good angles
			elif impact_angle >= 60.0:
				return 0.7  # 30% penalty for poor angles
			else:
				return 1.0
		
		DamageTypes.Type.ENERGY:
			# Energy weapons less affected by angle
			return 1.0 - (impact_angle / 180.0)  # Slight reduction at glancing angles
		
		DamageTypes.Type.EXPLOSIVE:
			# Explosive weapons relatively angle-independent
			return 0.9 + (0.1 * (1.0 - impact_angle / 90.0))
		
		DamageTypes.Type.PLASMA:
			# Plasma weapons very effective at all angles
			return 1.0
		
		_:
			return 1.0

## Calculate kinetic effects on penetration
func _calculate_kinetic_effects(impact_conditions: Dictionary, damage_type: int) -> float:
	if not enable_realistic_physics:
		return 1.0
	
	var velocity = impact_conditions.get("velocity", 100.0)  # m/s
	var mass = impact_conditions.get("projectile_mass", 1.0)  # kg
	var kinetic_energy = 0.5 * mass * velocity * velocity
	
	# Kinetic damage types benefit more from kinetic energy
	var energy_factor = kinetic_energy / 10000.0  # Normalize
	
	match damage_type:
		DamageTypes.Type.KINETIC:
			return 1.0 + (energy_factor * velocity_penetration_factor)
		DamageTypes.Type.EXPLOSIVE:
			return 1.0 + (energy_factor * 0.3)  # Less velocity dependent
		_:
			return 1.0 + (energy_factor * 0.1)  # Minimal velocity dependence

## Determine final penetration result
func _determine_penetration_result(
	effectiveness: float,
	deflection_prob: float,
	ricochet_prob: float,
	impact_angle: float
) -> String:
	
	# Roll for deflection/ricochet
	var random_roll = randf()
	
	if random_roll < ricochet_prob:
		return "ricochet"
	elif random_roll < deflection_prob:
		return "deflected"
	elif effectiveness >= 0.8:
		return "full_penetration"
	elif effectiveness >= 0.5:
		return "partial_penetration"
	elif effectiveness >= 0.2:
		return "reduced_penetration"
	else:
		return "minimal_penetration"

## Calculate deflection angle
func _calculate_deflection_angle(impact_angle: float, surface_normal: Vector3) -> float:
	# Simple deflection calculation - angle of incidence equals angle of reflection
	return impact_angle

## Calculate optimal position for attack
func _calculate_optimal_position(
	target_position: Vector3,
	target_normal: Vector3,
	current_position: Vector3,
	optimal_angle: float
) -> Vector3:
	
	var distance = current_position.distance_to(target_position)
	var optimal_direction = target_normal * -1.0  # Perpendicular to surface
	
	# Adjust for optimal angle if not perpendicular
	if optimal_angle > 0.0:
		var tangent = Vector3.UP.cross(target_normal).normalized()
		var angle_adjustment = tan(deg_to_rad(optimal_angle))
		optimal_direction = (optimal_direction + tangent * angle_adjustment).normalized()
	
	return target_position + optimal_direction * distance

## Setup angle effectiveness curves for different armor types
func _setup_angle_effectiveness_curves() -> void:
	angle_effectiveness_curves = {
		ArmorTypes.Class.LIGHT: {
			"max_effectiveness": 0.9,
			"min_effectiveness": 0.2,
			"deflection_resistance": 0.3
		},
		ArmorTypes.Class.STANDARD: {
			"max_effectiveness": 1.0,
			"min_effectiveness": 0.1,
			"deflection_resistance": 0.5
		},
		ArmorTypes.Class.HEAVY: {
			"max_effectiveness": 1.2,
			"min_effectiveness": 0.05,
			"deflection_resistance": 0.8
		},
		ArmorTypes.Class.ADAPTIVE: {
			"max_effectiveness": 1.1,
			"min_effectiveness": 0.15,
			"deflection_resistance": 0.6
		}
	}

## Setup penetration thresholds
func _setup_penetration_thresholds() -> void:
	penetration_thresholds = {
		"minimum_angle": minimum_penetration_angle,
		"maximum_effectiveness_angle": maximum_effectiveness_angle,
		"deflection_threshold": deflection_threshold_angle,
		"ricochet_threshold": ricochet_probability_angle
	}

## Calculate surface vulnerability factor
func _calculate_surface_vulnerability(surface_normal: Vector3, armor_config: Dictionary) -> float:
	# Surfaces facing more directly toward common attack vectors are more vulnerable
	var front_facing_factor = max(0.0, surface_normal.dot(Vector3.FORWARD))
	var side_facing_factor = max(0.0, abs(surface_normal.dot(Vector3.RIGHT)))
	
	# Top and bottom surfaces are generally more vulnerable
	var vertical_factor = abs(surface_normal.dot(Vector3.UP))
	
	# Calculate overall vulnerability
	var vulnerability = (front_facing_factor * 0.5 + side_facing_factor * 0.3 + vertical_factor * 0.2)
	
	# Apply armor configuration modifiers
	var armor_thickness = armor_config.get("thickness_multiplier", 1.0)
	vulnerability *= (2.0 - armor_thickness)  # Thicker armor reduces vulnerability
	
	return clamp(vulnerability, 0.0, 1.0)

## Get optimal attack angle for surface
func _get_optimal_attack_angle_for_surface(surface_normal: Vector3) -> float:
	# Always prefer perpendicular attacks
	return 0.0

## Get penetration analysis for debugging
func get_penetration_analysis(
	impact_vector: Vector3,
	surface_normal: Vector3,
	armor_type: int,
	damage_type: int
) -> Dictionary:
	
	var impact_angle = _calculate_impact_angle(impact_vector, surface_normal)
	var base_effectiveness = _get_base_angle_effectiveness(impact_angle, armor_type)
	var damage_modifier = _get_damage_type_angle_modifier(damage_type, impact_angle)
	var deflection_prob = _calculate_deflection_probability(impact_angle, armor_type, damage_type)
	
	return {
		"impact_angle": impact_angle,
		"base_effectiveness": base_effectiveness,
		"damage_modifier": damage_modifier,
		"deflection_probability": deflection_prob,
		"effectiveness_rating": _get_effectiveness_rating(base_effectiveness * damage_modifier),
		"angle_classification": _classify_impact_angle(impact_angle)
	}

## Get effectiveness rating description
func _get_effectiveness_rating(effectiveness: float) -> String:
	if effectiveness >= 0.9:
		return "Excellent"
	elif effectiveness >= 0.7:
		return "Good"
	elif effectiveness >= 0.5:
		return "Fair"
	elif effectiveness >= 0.3:
		return "Poor"
	else:
		return "Minimal"

## Classify impact angle
func _classify_impact_angle(angle: float) -> String:
	if angle <= maximum_effectiveness_angle:
		return "Optimal"
	elif angle <= 45.0:
		return "Good"
	elif angle <= deflection_threshold_angle:
		return "Moderate"
	elif angle <= ricochet_probability_angle:
		return "Poor"
	else:
		return "Glancing"