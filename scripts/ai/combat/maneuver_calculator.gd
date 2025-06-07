class_name ManeuverCalculator
extends RefCounted

## Advanced maneuver calculation system for AI combat ships
## Provides sophisticated flight path calculations for various combat maneuvers

enum ManeuverType {
	INTERCEPT,          # Intercept moving target
	EVASION,            # Evasive maneuvering
	ATTACK_APPROACH,    # Optimal attack approach
	BREAKAWAY,          # Escape maneuver
	PURSUIT,            # Follow target
	DEFENSIVE_CIRCLE,   # Defensive circling
	BARREL_ROLL,        # Evasive barrel roll
	SPLIT_S,            # Split-S maneuver
	IMMELMANN,          # Immelmann turn
	HIGH_G_TURN         # High-G turn maneuver
}

enum FlightPhysics {
	REALISTIC,          # Full physics simulation
	SIMPLIFIED,         # Simplified for performance
	ARCADE              # Arcade-style movement
}

# Physics constants
const GRAVITY: float = 9.81
const AIR_DENSITY: float = 1.225  # Approximate at sea level
const MAX_G_FORCE: float = 12.0   # Maximum G-force for fighters

static func calculate_intercept_course(
	ship_position: Vector3, 
	ship_velocity: Vector3, 
	ship_max_speed: float,
	target_position: Vector3, 
	target_velocity: Vector3, 
	skill_factor: float = 1.0
) -> Dictionary:
	"""Calculate optimal intercept course to moving target"""
	
	var relative_position: Vector3 = target_position - ship_position
	var relative_velocity: Vector3 = target_velocity - ship_velocity
	var distance: float = relative_position.length()
	
	# Calculate time to intercept using quadratic formula
	var a: float = relative_velocity.dot(relative_velocity) - (ship_max_speed * ship_max_speed)
	var b: float = 2.0 * relative_position.dot(relative_velocity)
	var c: float = relative_position.dot(relative_position)
	
	var discriminant: float = b * b - 4.0 * a * c
	var intercept_time: float = 0.0
	
	if discriminant >= 0.0 and abs(a) > 0.001:
		var t1: float = (-b - sqrt(discriminant)) / (2.0 * a)
		var t2: float = (-b + sqrt(discriminant)) / (2.0 * a)
		intercept_time = t1 if t1 > 0.0 else t2
	else:
		# Fallback: simple distance/speed calculation
		intercept_time = distance / ship_max_speed
	
	# Apply skill-based prediction accuracy
	var prediction_accuracy: float = lerp(0.7, 1.0, skill_factor)
	intercept_time *= prediction_accuracy
	
	# Calculate intercept position
	var intercept_position: Vector3 = target_position + (target_velocity * intercept_time)
	var required_velocity: Vector3 = (intercept_position - ship_position) / max(intercept_time, 0.1)
	
	return {
		"intercept_position": intercept_position,
		"intercept_time": intercept_time,
		"required_velocity": required_velocity,
		"required_speed": min(required_velocity.length(), ship_max_speed),
		"success_probability": clamp(1.0 - (distance / (ship_max_speed * intercept_time * 2.0)), 0.1, 1.0)
	}

static func calculate_attack_approach(
	ship_position: Vector3, 
	target_position: Vector3, 
	target_velocity: Vector3,
	approach_type: AttackRunAction.AttackRunType,
	optimal_range: float,
	skill_factor: float = 1.0
) -> Dictionary:
	"""Calculate optimal attack approach vectors"""
	
	var to_target: Vector3 = (target_position - ship_position).normalized()
	var target_speed: float = target_velocity.length()
	
	# Base approach vector
	var approach_vector: Vector3
	var approach_distance: float = optimal_range * 2.0
	
	match approach_type:
		AttackRunAction.AttackRunType.HEAD_ON:
			approach_vector = -to_target
			
		AttackRunAction.AttackRunType.HIGH_ANGLE:
			var up_component: Vector3 = Vector3.UP * 0.6
			var forward_component: Vector3 = -to_target * 0.8
			approach_vector = (up_component + forward_component).normalized()
			approach_distance *= 1.2
			
		AttackRunAction.AttackRunType.LOW_ANGLE:
			var down_component: Vector3 = Vector3.DOWN * 0.4
			var forward_component: Vector3 = -to_target * 0.9
			approach_vector = (down_component + forward_component).normalized()
			
		AttackRunAction.AttackRunType.BEAM_ATTACK:
			var perpendicular: Vector3 = to_target.cross(Vector3.UP).normalized()
			if target_speed > 10.0:
				perpendicular = target_velocity.cross(Vector3.UP).normalized()
			approach_vector = perpendicular
			approach_distance *= 0.8
			
		AttackRunAction.AttackRunType.QUARTER_ATTACK:
			var side_vector: Vector3 = to_target.cross(Vector3.UP).normalized()
			approach_vector = (-to_target * 0.7 + side_vector * 0.7).normalized()
	
	# Apply skill-based variations
	var skill_precision: float = lerp(0.8, 1.0, skill_factor)
	var randomization: float = lerp(0.2, 0.05, skill_factor)
	
	approach_vector += Vector3(
		randf_range(-randomization, randomization),
		randf_range(-randomization * 0.5, randomization * 0.5),
		randf_range(-randomization, randomization)
	)
	approach_vector = approach_vector.normalized()
	
	# Calculate approach position
	var predicted_target_pos: Vector3 = target_position + target_velocity * (approach_distance / 200.0)  # Predict 200 m/s approach speed
	var approach_position: Vector3 = predicted_target_pos + approach_vector * approach_distance * skill_precision
	
	# Calculate optimal firing position
	var firing_position: Vector3 = predicted_target_pos + approach_vector * optimal_range
	
	return {
		"approach_position": approach_position,
		"firing_position": firing_position,
		"approach_vector": approach_vector,
		"approach_distance": approach_distance,
		"estimated_approach_time": approach_distance / 200.0,
		"attack_angle_quality": _calculate_attack_angle_quality(approach_vector, to_target)
	}

static func calculate_evasive_maneuver(
	ship_position: Vector3, 
	ship_velocity: Vector3,
	threat_position: Vector3, 
	threat_velocity: Vector3,
	maneuver_type: ManeuverType,
	ship_agility: float,
	skill_factor: float = 1.0
) -> Dictionary:
	"""Calculate evasive maneuver to avoid threat"""
	
	var threat_vector: Vector3 = (ship_position - threat_position).normalized()
	var relative_velocity: Vector3 = ship_velocity - threat_velocity
	var evasion_vector: Vector3
	var maneuver_intensity: float = lerp(0.7, 1.0, skill_factor)
	
	match maneuver_type:
		ManeuverType.EVASION:
			# Basic evasive movement perpendicular to threat
			evasion_vector = threat_vector.cross(Vector3.UP).normalized()
			if randf() > 0.5:
				evasion_vector = -evasion_vector
				
		ManeuverType.BARREL_ROLL:
			# Barrel roll around velocity vector
			var roll_axis: Vector3 = ship_velocity.normalized()
			var roll_angle: float = PI * 2.0 * (Time.get_time_from_start() * 2.0)  # 2 rolls per second
			evasion_vector = _rotate_vector_around_axis(threat_vector, roll_axis, roll_angle)
			
		ManeuverType.SPLIT_S:
			# Split-S: half loop downward and roll
			var down_vector: Vector3 = Vector3.DOWN
			var half_loop: Vector3 = (threat_vector + down_vector).normalized()
			evasion_vector = half_loop
			
		ManeuverType.IMMELMANN:
			# Immelmann turn: half loop upward and roll
			var up_vector: Vector3 = Vector3.UP
			var half_loop: Vector3 = (threat_vector + up_vector).normalized()
			evasion_vector = half_loop
			
		ManeuverType.HIGH_G_TURN:
			# High-G turn away from threat
			var turn_vector: Vector3 = threat_vector.cross(Vector3.UP).normalized()
			var velocity_component: Vector3 = ship_velocity.normalized()
			evasion_vector = (turn_vector + velocity_component).normalized()
			maneuver_intensity *= 1.5  # More aggressive
			
		_:
			# Default evasion
			evasion_vector = threat_vector
	
	# Calculate G-force requirements
	var turn_radius: float = ship_velocity.length_squared() / (MAX_G_FORCE * GRAVITY)
	var required_g_force: float = ship_velocity.length_squared() / (turn_radius * GRAVITY)
	required_g_force = min(required_g_force, MAX_G_FORCE * skill_factor)
	
	# Apply agility factor
	evasion_vector *= maneuver_intensity * ship_agility
	
	# Calculate evasion target position
	var evasion_distance: float = lerp(300.0, 800.0, skill_factor)
	var evasion_position: Vector3 = ship_position + evasion_vector * evasion_distance
	
	return {
		"evasion_position": evasion_position,
		"evasion_vector": evasion_vector,
		"maneuver_intensity": maneuver_intensity,
		"required_g_force": required_g_force,
		"turn_radius": turn_radius,
		"evasion_effectiveness": _calculate_evasion_effectiveness(evasion_vector, threat_vector, skill_factor)
	}

static func calculate_pursuit_trajectory(
	ship_position: Vector3, 
	ship_velocity: Vector3,
	target_position: Vector3, 
	target_velocity: Vector3,
	pursuit_mode: PursuitAttackAction.PursuitMode,
	optimal_distance: float,
	skill_factor: float = 1.0
) -> Dictionary:
	"""Calculate pursuit trajectory for different pursuit modes"""
	
	var to_target: Vector3 = (target_position - ship_position).normalized()
	var distance_to_target: float = ship_position.distance_to(target_position)
	var target_speed: float = target_velocity.length()
	
	var pursuit_position: Vector3
	var pursuit_vector: Vector3
	var approach_speed_modifier: float = 1.0
	
	match pursuit_mode:
		PursuitAttackAction.PursuitMode.AGGRESSIVE:
			# Direct pursuit with predictive positioning
			var prediction_time: float = distance_to_target / 300.0  # Assume 300 m/s closure
			var predicted_target_pos: Vector3 = target_position + target_velocity * prediction_time * skill_factor
			pursuit_position = predicted_target_pos - to_target * optimal_distance * 0.8
			approach_speed_modifier = 1.2
			
		PursuitAttackAction.PursuitMode.CAUTIOUS:
			# Follow behind target at safe distance
			var behind_vector: Vector3 = -target_velocity.normalized() if target_speed > 1.0 else -to_target
			pursuit_position = target_position + behind_vector * optimal_distance * 1.2
			approach_speed_modifier = 0.9
			
		PursuitAttackAction.PursuitMode.STALKING:
			# Maintain distance, opportunistic positioning
			var offset_vector: Vector3 = _calculate_stalking_offset(target_velocity, skill_factor)
			pursuit_position = target_position + offset_vector * optimal_distance * 1.5
			approach_speed_modifier = 0.8
			
		PursuitAttackAction.PursuitMode.HERDING:
			# Drive target toward specific location
			var herding_vector: Vector3 = _calculate_herding_vector(target_position, target_velocity)
			pursuit_position = target_position + herding_vector * optimal_distance
			approach_speed_modifier = 1.1
	
	pursuit_vector = (pursuit_position - ship_position).normalized()
	
	# Calculate interception parameters
	var intercept_data: Dictionary = calculate_intercept_course(
		ship_position, ship_velocity, 200.0 * approach_speed_modifier,
		target_position, target_velocity, skill_factor
	)
	
	return {
		"pursuit_position": pursuit_position,
		"pursuit_vector": pursuit_vector,
		"approach_speed_modifier": approach_speed_modifier,
		"intercept_position": intercept_data.get("intercept_position"),
		"intercept_time": intercept_data.get("intercept_time"),
		"pursuit_effectiveness": _calculate_pursuit_effectiveness(pursuit_vector, to_target, distance_to_target, optimal_distance)
	}

static func calculate_breakaway_trajectory(
	ship_position: Vector3, 
	ship_velocity: Vector3,
	threat_position: Vector3, 
	escape_distance: float,
	skill_factor: float = 1.0
) -> Dictionary:
	"""Calculate optimal breakaway trajectory"""
	
	var threat_vector: Vector3 = (ship_position - threat_position).normalized()
	var velocity_vector: Vector3 = ship_velocity.normalized() if ship_velocity.length() > 1.0 else threat_vector
	
	# Combine escape vectors
	var primary_escape: Vector3 = threat_vector * 0.7
	var momentum_escape: Vector3 = velocity_vector * 0.5
	var evasive_component: Vector3 = threat_vector.cross(Vector3.UP).normalized() * 0.3 * (1.0 if randf() > 0.5 else -1.0)
	
	var escape_vector: Vector3 = (primary_escape + momentum_escape + evasive_component * skill_factor).normalized()
	
	# Apply skill-based escape optimizations
	var escape_efficiency: float = lerp(0.8, 1.0, skill_factor)
	var escape_position: Vector3 = ship_position + escape_vector * escape_distance * escape_efficiency
	
	# Calculate required G-forces
	var turn_angle: float = velocity_vector.angle_to(escape_vector)
	var required_g: float = (ship_velocity.length() * sin(turn_angle)) / (turn_angle * GRAVITY) if turn_angle > 0.001 else 0.0
	
	return {
		"escape_position": escape_position,
		"escape_vector": escape_vector,
		"escape_efficiency": escape_efficiency,
		"required_g_force": min(required_g, MAX_G_FORCE),
		"escape_time": escape_distance / max(ship_velocity.length(), 50.0),
		"safety_margin": _calculate_safety_margin(escape_vector, threat_vector, escape_distance)
	}

static func calculate_formation_attack_positioning(
	ship_position: Vector3,
	formation_members: Array[Vector3],
	target_position: Vector3,
	attack_pattern: AttackPatternManager.AttackPattern,
	formation_spacing: float
) -> Dictionary:
	"""Calculate positioning for coordinated formation attacks"""
	
	var formation_center: Vector3 = Vector3.ZERO
	for member_pos in formation_members:
		formation_center += member_pos
	formation_center /= formation_members.size()
	
	var to_target: Vector3 = (target_position - formation_center).normalized()
	var formation_front: Vector3 = formation_center + to_target * formation_spacing
	
	var attack_positions: Array[Vector3] = []
	
	match attack_pattern:
		AttackPatternManager.AttackPattern.COORDINATED:
			# Spread formation in line abreast for coordinated attack
			var perpendicular: Vector3 = to_target.cross(Vector3.UP).normalized()
			for i in range(formation_members.size()):
				var offset: float = (i - formation_members.size() * 0.5) * formation_spacing
				var attack_pos: Vector3 = formation_front + perpendicular * offset
				attack_positions.append(attack_pos)
		
		AttackPatternManager.AttackPattern.ATTACK_RUN:
			# Staggered attack runs
			for i in range(formation_members.size()):
				var stagger_offset: Vector3 = to_target * (i * formation_spacing * 0.5)
				var attack_pos: Vector3 = formation_front - stagger_offset
				attack_positions.append(attack_pos)
		
		_:
			# Default spread formation
			attack_positions = _calculate_spread_positions(formation_front, to_target, formation_members.size(), formation_spacing)
	
	return {
		"attack_positions": attack_positions,
		"formation_center": formation_center,
		"target_vector": to_target,
		"coordination_quality": _calculate_coordination_quality(attack_positions, target_position)
	}

# Helper functions

static func _calculate_attack_angle_quality(approach_vector: Vector3, target_vector: Vector3) -> float:
	"""Calculate quality of attack angle (0.0 to 1.0)"""
	var angle_dot: float = approach_vector.dot(-target_vector)
	return clamp((angle_dot + 1.0) * 0.5, 0.0, 1.0)

static func _calculate_evasion_effectiveness(evasion_vector: Vector3, threat_vector: Vector3, skill_factor: float) -> float:
	"""Calculate effectiveness of evasive maneuver"""
	var angle_from_threat: float = evasion_vector.angle_to(threat_vector)
	var base_effectiveness: float = clamp(angle_from_threat / PI, 0.0, 1.0)
	return base_effectiveness * skill_factor

static func _calculate_pursuit_effectiveness(pursuit_vector: Vector3, target_vector: Vector3, distance: float, optimal_distance: float) -> float:
	"""Calculate effectiveness of pursuit trajectory"""
	var directional_quality: float = clamp(pursuit_vector.dot(target_vector), 0.0, 1.0)
	var distance_quality: float = 1.0 - abs(distance - optimal_distance) / optimal_distance
	return (directional_quality + distance_quality) * 0.5

static func _calculate_safety_margin(escape_vector: Vector3, threat_vector: Vector3, escape_distance: float) -> float:
	"""Calculate safety margin for breakaway maneuver"""
	var angle_from_threat: float = escape_vector.angle_to(-threat_vector)
	var angular_safety: float = clamp(angle_from_threat / (PI * 0.5), 0.0, 1.0)
	var distance_safety: float = clamp(escape_distance / 1000.0, 0.0, 1.0)
	return (angular_safety + distance_safety) * 0.5

static func _calculate_coordination_quality(positions: Array[Vector3], target_position: Vector3) -> float:
	"""Calculate quality of formation coordination"""
	if positions.size() < 2:
		return 1.0
	
	var total_quality: float = 0.0
	var center: Vector3 = Vector3.ZERO
	
	for pos in positions:
		center += pos
	center /= positions.size()
	
	var to_target: Vector3 = (target_position - center).normalized()
	
	for pos in positions:
		var pos_to_target: Vector3 = (target_position - pos).normalized()
		var alignment: float = pos_to_target.dot(to_target)
		total_quality += clamp(alignment, 0.0, 1.0)
	
	return total_quality / positions.size()

static func _calculate_stalking_offset(target_velocity: Vector3, skill_factor: float) -> Vector3:
	"""Calculate offset vector for stalking pursuit"""
	var perpendicular: Vector3 = target_velocity.cross(Vector3.UP).normalized()
	var behind: Vector3 = -target_velocity.normalized() if target_velocity.length() > 1.0 else Vector3.BACK
	
	# Mix perpendicular and behind vectors based on skill
	var offset_balance: float = lerp(0.3, 0.7, skill_factor)
	return (behind * offset_balance + perpendicular * (1.0 - offset_balance)).normalized()

static func _calculate_herding_vector(target_position: Vector3, target_velocity: Vector3) -> Vector3:
	"""Calculate vector for herding target toward desired location"""
	# Simplified: push target away from origin
	var from_origin: Vector3 = target_position.normalized()
	var velocity_component: Vector3 = target_velocity.normalized() * 0.3
	return (from_origin + velocity_component).normalized()

static func _calculate_spread_positions(center: Vector3, direction: Vector3, count: int, spacing: float) -> Array[Vector3]:
	"""Calculate spread positions for formation"""
	var positions: Array[Vector3] = []
	var perpendicular: Vector3 = direction.cross(Vector3.UP).normalized()
	
	for i in range(count):
		var offset: float = (i - count * 0.5) * spacing
		var pos: Vector3 = center + perpendicular * offset
		positions.append(pos)
	
	return positions

static func _rotate_vector_around_axis(vector: Vector3, axis: Vector3, angle: float) -> Vector3:
	"""Rotate vector around arbitrary axis using Rodrigues' rotation formula"""
	var cos_angle: float = cos(angle)
	var sin_angle: float = sin(angle)
	var axis_normalized: Vector3 = axis.normalized()
	
	var rotated: Vector3 = vector * cos_angle
	rotated += axis_normalized.cross(vector) * sin_angle
	rotated += axis_normalized * axis_normalized.dot(vector) * (1.0 - cos_angle)
	
	return rotated

static func calculate_weapon_firing_solution(
	ship_position: Vector3,
	ship_velocity: Vector3,
	target_position: Vector3,
	target_velocity: Vector3,
	projectile_speed: float,
	skill_factor: float = 1.0
) -> Dictionary:
	"""Calculate optimal weapon firing solution"""
	
	var relative_position: Vector3 = target_position - ship_position
	var relative_velocity: Vector3 = target_velocity - ship_velocity
	
	# Solve for intercept time using quadratic equation
	var a: float = relative_velocity.dot(relative_velocity) - projectile_speed * projectile_speed
	var b: float = 2.0 * relative_position.dot(relative_velocity)
	var c: float = relative_position.dot(relative_position)
	
	var discriminant: float = b * b - 4.0 * a * c
	var firing_time: float = 0.0
	
	if discriminant >= 0.0 and abs(a) > 0.001:
		var t1: float = (-b - sqrt(discriminant)) / (2.0 * a)
		var t2: float = (-b + sqrt(discriminant)) / (2.0 * a)
		firing_time = t1 if t1 > 0.0 else t2
	else:
		firing_time = relative_position.length() / projectile_speed
	
	# Apply skill-based accuracy
	var accuracy_factor: float = lerp(0.8, 1.0, skill_factor)
	firing_time *= accuracy_factor
	
	var firing_position: Vector3 = target_position + target_velocity * firing_time
	var required_heading: Vector3 = (firing_position - ship_position).normalized()
	
	return {
		"firing_position": firing_position,
		"firing_time": firing_time,
		"required_heading": required_heading,
		"hit_probability": clamp(1.0 - (firing_time / 5.0), 0.1, 1.0),  # Decreases over time
		"lead_distance": target_velocity.length() * firing_time
	}