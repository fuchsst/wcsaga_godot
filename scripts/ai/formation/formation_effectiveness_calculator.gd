class_name FormationEffectivenessCalculator
extends Node

## Formation effectiveness calculator for dynamic formation management.
## Calculates and tracks formation effectiveness across multiple metrics.

signal effectiveness_calculated(formation_id: String, effectiveness: Dictionary)
signal effectiveness_threshold_crossed(formation_id: String, metric: String, old_value: float, new_value: float)
signal performance_alert(formation_id: String, alert_type: String, details: Dictionary)

## Effectiveness calculation weights
var calculation_parameters: Dictionary = {
	"positioning_weight": 0.25,
	"coverage_weight": 0.20,
	"tactical_weight": 0.25,
	"coordination_weight": 0.20,
	"adaptation_weight": 0.10
}

# Performance tracking
var effectiveness_history: Dictionary = {}
var calculation_performance: Dictionary = {}

# Thresholds for alerts
var alert_thresholds: Dictionary = {
	"poor_effectiveness": 0.4,
	"excellent_effectiveness": 0.85,
	"coordination_breakdown": 0.3,
	"positioning_failure": 0.35
}

func _ready() -> void:
	_initialize_calculation_system()

func _initialize_calculation_system() -> void:
	calculation_performance = {
		"total_calculations": 0,
		"average_calculation_time": 0.0,
		"effectiveness_trends": {},
		"alert_count": 0
	}

func initialize_calculation_parameters(parameters: Dictionary) -> void:
	## Initializes calculation parameters for effectiveness assessment
	calculation_parameters.merge(parameters, true)

## Calculates comprehensive formation effectiveness
func calculate_formation_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	var start_time: float = Time.get_time_from_system() * 1000.0
	var formation_id: String = dynamic_formation.formation_id
	
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if not is_instance_valid(base_formation.leader):
		return _get_default_effectiveness_metrics()
	
	# Calculate individual effectiveness factors
	var positioning_effectiveness: Dictionary = _calculate_positioning_effectiveness(dynamic_formation)
	var coverage_effectiveness: Dictionary = _calculate_coverage_effectiveness(dynamic_formation)
	var tactical_effectiveness: Dictionary = _calculate_tactical_effectiveness(dynamic_formation)
	var coordination_effectiveness: Dictionary = _calculate_coordination_effectiveness(dynamic_formation)
	var adaptation_effectiveness: Dictionary = _calculate_adaptation_effectiveness(dynamic_formation)
	
	# Calculate weighted overall effectiveness
	var overall_effectiveness: float = (
		positioning_effectiveness.get("score", 0.0) * calculation_parameters["positioning_weight"] +
		coverage_effectiveness.get("score", 0.0) * calculation_parameters["coverage_weight"] +
		tactical_effectiveness.get("score", 0.0) * calculation_parameters["tactical_weight"] +
		coordination_effectiveness.get("score", 0.0) * calculation_parameters["coordination_weight"] +
		adaptation_effectiveness.get("score", 0.0) * calculation_parameters["adaptation_weight"]
	)
	
	# Compile comprehensive effectiveness metrics
	var effectiveness_metrics: Dictionary = {
		"overall_effectiveness": overall_effectiveness,
		"positioning_effectiveness": positioning_effectiveness,
		"coverage_effectiveness": coverage_effectiveness,
		"tactical_effectiveness": tactical_effectiveness,
		"coordination_effectiveness": coordination_effectiveness,
		"adaptation_effectiveness": adaptation_effectiveness,
		"calculation_timestamp": Time.get_time_from_start(),
		"formation_type": DynamicFormationManager.AdvancedFormationType.keys()[dynamic_formation.current_type],
		"ship_count": base_formation.members.size() + 1,
		"effectiveness_grade": _determine_effectiveness_grade(overall_effectiveness)
	}
	
	# Update history and check for alerts
	_update_effectiveness_history(formation_id, effectiveness_metrics)
	_check_effectiveness_alerts(formation_id, effectiveness_metrics)
	
	# Update performance tracking
	var calculation_time: float = (Time.get_time_from_system() * 1000.0) - start_time
	_update_calculation_performance(calculation_time)
	
	effectiveness_calculated.emit(formation_id, effectiveness_metrics)
	
	return effectiveness_metrics

func _calculate_positioning_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Calculate how well ships maintain their formation positions
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var total_position_accuracy: float = 0.0
	var ship_count: int = 0
	var position_deviations: Array[float] = []
	var formation_integrity: float = base_formation.get_formation_integrity()
	
	# Update formation positions first
	base_formation.update_formation_positions()
	
	# Calculate position accuracy for each ship
	for i in range(base_formation.members.size()):
		var member: Node3D = base_formation.members[i]
		if not is_instance_valid(member):
			continue
		
		var target_position: Vector3 = base_formation.get_formation_position(i)
		var actual_position: Vector3 = member.global_position
		var distance_error: float = actual_position.distance_to(target_position)
		
		# Normalize error relative to formation spacing
		var normalized_error: float = distance_error / max(base_formation.formation_spacing, 1.0)
		var position_accuracy: float = clamp(1.0 - normalized_error, 0.0, 1.0)
		
		total_position_accuracy += position_accuracy
		position_deviations.append(distance_error)
		ship_count += 1
	
	var average_position_accuracy: float = total_position_accuracy / max(ship_count, 1)
	
	# Calculate spacing consistency
	var spacing_consistency: float = _calculate_spacing_consistency(dynamic_formation)
	
	# Calculate orientation alignment
	var orientation_alignment: float = _calculate_orientation_alignment(dynamic_formation)
	
	# Calculate movement coordination
	var movement_coordination: float = _calculate_movement_coordination(dynamic_formation)
	
	# Combine positioning factors
	var positioning_score: float = (
		average_position_accuracy * 0.4 +
		formation_integrity * 0.3 +
		spacing_consistency * 0.15 +
		orientation_alignment * 0.10 +
		movement_coordination * 0.05
	)
	
	return {
		"score": positioning_score,
		"position_accuracy": average_position_accuracy,
		"formation_integrity": formation_integrity,
		"spacing_consistency": spacing_consistency,
		"orientation_alignment": orientation_alignment,
		"movement_coordination": movement_coordination,
		"position_deviations": position_deviations,
		"ship_count": ship_count
	}

func _calculate_spacing_consistency(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate consistency of ship spacing within formation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var target_spacing: float = base_formation.formation_spacing
	var spacing_deviations: Array[float] = []
	
	if base_formation.members.size() < 2:
		return 1.0  # Single ship formations are perfectly consistent
	
	# Calculate spacing between adjacent ships
	for i in range(base_formation.members.size() - 1):
		var ship1: Node3D = base_formation.members[i]
		var ship2: Node3D = base_formation.members[i + 1]
		
		if is_instance_valid(ship1) and is_instance_valid(ship2):
			var actual_spacing: float = ship1.global_position.distance_to(ship2.global_position)
			var spacing_deviation: float = abs(actual_spacing - target_spacing) / target_spacing
			spacing_deviations.append(spacing_deviation)
	
	# Calculate average deviation
	var total_deviation: float = 0.0
	for deviation in spacing_deviations:
		total_deviation += deviation
	
	var average_deviation: float = total_deviation / max(spacing_deviations.size(), 1)
	return clamp(1.0 - average_deviation, 0.0, 1.0)

func _calculate_orientation_alignment(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate how well ships align their orientations
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if not is_instance_valid(base_formation.leader):
		return 0.0
	
	var leader_forward: Vector3 = base_formation._get_ship_forward(base_formation.leader)
	var total_alignment: float = 0.0
	var ship_count: int = 0
	
	for member in base_formation.members:
		if is_instance_valid(member):
			var member_forward: Vector3 = base_formation._get_ship_forward(member)
			var alignment: float = leader_forward.dot(member_forward)  # -1 to 1
			var normalized_alignment: float = (alignment + 1.0) * 0.5  # 0 to 1
			
			total_alignment += normalized_alignment
			ship_count += 1
	
	return total_alignment / max(ship_count, 1)

func _calculate_movement_coordination(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate how well ships coordinate their movement
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if not is_instance_valid(base_formation.leader):
		return 0.0
	
	var leader_velocity: Vector3 = _get_ship_velocity(base_formation.leader)
	var total_coordination: float = 0.0
	var ship_count: int = 0
	
	for member in base_formation.members:
		if is_instance_valid(member):
			var member_velocity: Vector3 = _get_ship_velocity(member)
			
			# Calculate velocity similarity (direction and magnitude)
			var velocity_dot: float = 0.0
			var magnitude_similarity: float = 0.0
			
			if leader_velocity.length() > 0.1 and member_velocity.length() > 0.1:
				velocity_dot = leader_velocity.normalized().dot(member_velocity.normalized())
				var speed_ratio: float = min(member_velocity.length(), leader_velocity.length()) / max(member_velocity.length(), leader_velocity.length())
				magnitude_similarity = speed_ratio
			else:
				# Both ships stationary or nearly stationary
				velocity_dot = 1.0
				magnitude_similarity = 1.0
			
			var coordination: float = (velocity_dot + 1.0) * 0.5 * magnitude_similarity
			total_coordination += coordination
			ship_count += 1
	
	return total_coordination / max(ship_count, 1)

func _get_ship_velocity(ship: Node3D) -> Vector3:
	# Get ship velocity vector
	if ship.has_method("get_velocity"):
		return ship.get_velocity()
	elif ship is CharacterBody3D:
		return ship.velocity
	elif ship is RigidBody3D:
		return ship.linear_velocity
	else:
		# Estimate velocity from position change
		return Vector3.ZERO

func _calculate_coverage_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Calculate how well the formation provides tactical coverage
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# Calculate area coverage
	var area_coverage: float = _calculate_area_coverage(dynamic_formation)
	
	# Calculate sector coverage (360-degree coverage)
	var sector_coverage: float = _calculate_sector_coverage(dynamic_formation)
	
	# Calculate threat axis coverage
	var threat_axis_coverage: float = _calculate_threat_axis_coverage(dynamic_formation)
	
	# Calculate overlap efficiency (avoiding redundant coverage)
	var overlap_efficiency: float = _calculate_overlap_efficiency(dynamic_formation)
	
	# Calculate defensive depth
	var defensive_depth: float = _calculate_defensive_depth(dynamic_formation)
	
	# Combine coverage factors
	var coverage_score: float = (
		area_coverage * 0.25 +
		sector_coverage * 0.25 +
		threat_axis_coverage * 0.20 +
		overlap_efficiency * 0.15 +
		defensive_depth * 0.15
	)
	
	return {
		"score": coverage_score,
		"area_coverage": area_coverage,
		"sector_coverage": sector_coverage,
		"threat_axis_coverage": threat_axis_coverage,
		"overlap_efficiency": overlap_efficiency,
		"defensive_depth": defensive_depth
	}

func _calculate_area_coverage(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate how much area the formation covers
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if base_formation.members.size() < 2:
		return 0.5  # Single ship formations have limited coverage
	
	# Calculate formation bounding area
	var min_pos: Vector3 = Vector3(INF, INF, INF)
	var max_pos: Vector3 = Vector3(-INF, -INF, -INF)
	var all_ships: Array[Node3D] = [base_formation.leader] + base_formation.members
	
	for ship in all_ships:
		if is_instance_valid(ship):
			var pos: Vector3 = ship.global_position
			min_pos.x = min(min_pos.x, pos.x)
			min_pos.y = min(min_pos.y, pos.y)
			min_pos.z = min(min_pos.z, pos.z)
			max_pos.x = max(max_pos.x, pos.x)
			max_pos.y = max(max_pos.y, pos.y)
			max_pos.z = max(max_pos.z, pos.z)
	
	var coverage_area: float = (max_pos.x - min_pos.x) * (max_pos.z - min_pos.z)
	var target_spacing: float = base_formation.formation_spacing
	var ideal_area: float = target_spacing * target_spacing * all_ships.size()
	
	# Normalize coverage relative to ideal
	var coverage_ratio: float = coverage_area / max(ideal_area, 1.0)
	return clamp(coverage_ratio, 0.0, 1.0)

func _calculate_sector_coverage(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate 360-degree coverage around formation center
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if not is_instance_valid(base_formation.leader):
		return 0.0
	
	var formation_center: Vector3 = base_formation.leader.global_position
	var sectors: Array[bool] = []
	var sector_count: int = 8  # 45-degree sectors
	
	# Initialize sectors
	for i in range(sector_count):
		sectors.append(false)
	
	# Check which sectors are covered by ships
	for member in base_formation.members:
		if is_instance_valid(member):
			var direction: Vector3 = (member.global_position - formation_center).normalized()
			var angle: float = atan2(direction.x, direction.z)
			if angle < 0:
				angle += 2 * PI
			
			var sector_index: int = int(angle / (2 * PI / sector_count))
			sector_index = clamp(sector_index, 0, sector_count - 1)
			sectors[sector_index] = true
	
	# Calculate coverage percentage
	var covered_sectors: int = 0
	for covered in sectors:
		if covered:
			covered_sectors += 1
	
	return float(covered_sectors) / float(sector_count)

func _calculate_threat_axis_coverage(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate coverage of primary threat axes
	# This would integrate with threat assessment system
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# For now, use simplified threat axis calculation
	# In full implementation, this would use data from TacticalSituationAnalyzer
	var threat_axes: Array[Vector3] = [
		Vector3.FORWARD,   # Front
		Vector3.BACK,      # Rear
		Vector3.LEFT,      # Left
		Vector3.RIGHT      # Right
	]
	
	var covered_axes: int = 0
	var formation_center: Vector3 = base_formation.leader.global_position if is_instance_valid(base_formation.leader) else Vector3.ZERO
	
	for axis in threat_axes:
		var axis_covered: bool = false
		
		for member in base_formation.members:
			if is_instance_valid(member):
				var ship_direction: Vector3 = (member.global_position - formation_center).normalized()
				var axis_alignment: float = ship_direction.dot(axis)
				
				if axis_alignment > 0.5:  # Ship covers this axis
					axis_covered = true
					break
		
		if axis_covered:
			covered_axes += 1
	
	return float(covered_axes) / float(threat_axes.size())

func _calculate_overlap_efficiency(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate efficiency by minimizing coverage overlap
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if base_formation.members.size() < 2:
		return 1.0
	
	var total_overlap: float = 0.0
	var comparison_count: int = 0
	var coverage_radius: float = base_formation.formation_spacing * 0.7
	
	# Check overlap between all ship pairs
	for i in range(base_formation.members.size()):
		for j in range(i + 1, base_formation.members.size()):
			var ship1: Node3D = base_formation.members[i]
			var ship2: Node3D = base_formation.members[j]
			
			if is_instance_valid(ship1) and is_instance_valid(ship2):
				var distance: float = ship1.global_position.distance_to(ship2.global_position)
				var overlap_amount: float = max(0.0, (coverage_radius * 2.0) - distance)
				var overlap_ratio: float = overlap_amount / (coverage_radius * 2.0)
				
				total_overlap += overlap_ratio
				comparison_count += 1
	
	var average_overlap: float = total_overlap / max(comparison_count, 1)
	return 1.0 - clamp(average_overlap, 0.0, 1.0)

func _calculate_defensive_depth(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate defensive depth (layers of protection)
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if not is_instance_valid(base_formation.leader):
		return 0.0
	
	var formation_center: Vector3 = base_formation.leader.global_position
	var distances: Array[float] = []
	
	# Get distances from formation center
	for member in base_formation.members:
		if is_instance_valid(member):
			var distance: float = formation_center.distance_to(member.global_position)
			distances.append(distance)
	
	if distances.size() < 2:
		return 0.5
	
	# Sort distances
	distances.sort()
	
	# Calculate depth based on distance distribution
	var min_distance: float = distances[0]
	var max_distance: float = distances[-1]
	var depth_range: float = max_distance - min_distance
	var target_spacing: float = base_formation.formation_spacing
	
	# Good depth has reasonable spread
	var depth_score: float = clamp(depth_range / (target_spacing * 2.0), 0.0, 1.0)
	return depth_score

func _calculate_tactical_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Calculate tactical effectiveness of formation type and positioning
	var formation_type: DynamicFormationManager.AdvancedFormationType = dynamic_formation.current_type
	
	# Calculate formation type appropriateness
	var type_appropriateness: float = _calculate_formation_type_appropriateness(dynamic_formation)
	
	# Calculate engagement readiness
	var engagement_readiness: float = _calculate_engagement_readiness(dynamic_formation)
	
	# Calculate tactical advantage
	var tactical_advantage: float = _calculate_tactical_advantage(dynamic_formation)
	
	# Calculate formation flexibility
	var formation_flexibility: float = _calculate_formation_flexibility(dynamic_formation)
	
	# Calculate threat response capability
	var threat_response: float = _calculate_threat_response_capability(dynamic_formation)
	
	# Combine tactical factors
	var tactical_score: float = (
		type_appropriateness * 0.25 +
		engagement_readiness * 0.25 +
		tactical_advantage * 0.20 +
		formation_flexibility * 0.15 +
		threat_response * 0.15
	)
	
	return {
		"score": tactical_score,
		"type_appropriateness": type_appropriateness,
		"engagement_readiness": engagement_readiness,
		"tactical_advantage": tactical_advantage,
		"formation_flexibility": formation_flexibility,
		"threat_response": threat_response
	}

func _calculate_formation_type_appropriateness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate how appropriate the current formation type is for the situation
	var formation_type: DynamicFormationManager.AdvancedFormationType = dynamic_formation.current_type
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var ship_count: int = base_formation.members.size() + 1
	
	# Get optimal ship count for formation type
	var formation_templates: Dictionary = {
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD: {"optimal_ships": 6},
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE: {"optimal_ships": 8},
		DynamicFormationManager.AdvancedFormationType.ESCORT_SCREEN: {"optimal_ships": 12},
		DynamicFormationManager.AdvancedFormationType.STRIKE_WEDGE: {"optimal_ships": 5},
		DynamicFormationManager.AdvancedFormationType.PATROL_SWEEP: {"optimal_ships": 8}
	}
	
	var template: Dictionary = formation_templates.get(formation_type, {"optimal_ships": 4})
	var optimal_ships: int = template["optimal_ships"]
	
	# Calculate ship count appropriateness
	var ship_count_score: float = 1.0 - abs(ship_count - optimal_ships) / float(optimal_ships)
	ship_count_score = clamp(ship_count_score, 0.0, 1.0)
	
	# This would be enhanced with tactical situation analysis
	return ship_count_score

func _calculate_engagement_readiness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate how ready the formation is for combat engagement
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var total_readiness: float = 0.0
	var ship_count: int = 0
	
	# Check leader readiness
	if is_instance_valid(base_formation.leader):
		total_readiness += _get_ship_combat_readiness(base_formation.leader)
		ship_count += 1
	
	# Check member readiness
	for member in base_formation.members:
		if is_instance_valid(member):
			total_readiness += _get_ship_combat_readiness(member)
			ship_count += 1
	
	return total_readiness / max(ship_count, 1)

func _get_ship_combat_readiness(ship: Node3D) -> float:
	# Get combat readiness for individual ship
	var readiness: float = 1.0
	
	# Check damage level
	if ship.has_method("get_damage_percentage"):
		var damage: float = ship.get_damage_percentage()
		readiness *= (1.0 - damage)
	
	# Check energy level
	if ship.has_method("get_energy_percentage"):
		var energy: float = ship.get_energy_percentage()
		readiness *= energy
	
	# Check weapon status
	if ship.has_method("get_weapon_readiness"):
		var weapons: float = ship.get_weapon_readiness()
		readiness *= weapons
	
	return clamp(readiness, 0.0, 1.0)

func _calculate_tactical_advantage(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate tactical advantage provided by formation
	var formation_type: DynamicFormationManager.AdvancedFormationType = dynamic_formation.current_type
	
	# Different formation types provide different tactical advantages
	match formation_type:
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD:
			return 0.8  # High tactical advantage for combat
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE:
			return 0.7  # Good defensive advantage
		DynamicFormationManager.AdvancedFormationType.STRIKE_WEDGE:
			return 0.9  # Excellent for aggressive attacks
		DynamicFormationManager.AdvancedFormationType.ESCORT_SCREEN:
			return 0.6  # Moderate advantage for protection
		_:
			return 0.5  # Default moderate advantage

func _calculate_formation_flexibility(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate how flexible the formation is for adaptation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var ship_count: int = base_formation.members.size() + 1
	
	# More ships generally provide more flexibility
	var size_flexibility: float = clamp(ship_count / 8.0, 0.0, 1.0)
	
	# Formation integrity affects flexibility
	var integrity: float = base_formation.get_formation_integrity()
	var integrity_flexibility: float = integrity  # Good integrity enables better transitions
	
	return (size_flexibility + integrity_flexibility) * 0.5

func _calculate_threat_response_capability(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate ability to respond to threats
	var formation_type: DynamicFormationManager.AdvancedFormationType = dynamic_formation.current_type
	
	# Calculate based on formation type threat response capabilities
	match formation_type:
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE:
			return 0.9  # Excellent threat response
		DynamicFormationManager.AdvancedFormationType.MISSILE_SCREEN:
			return 0.8  # Good for missile threats
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD:
			return 0.7  # Good general threat response
		_:
			return 0.6  # Moderate threat response

func _calculate_coordination_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Calculate coordination effectiveness between formation members
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# Calculate command and control effectiveness
	var command_control: float = _calculate_command_control_effectiveness(dynamic_formation)
	
	# Calculate communication efficiency
	var communication: float = _calculate_communication_efficiency(dynamic_formation)
	
	# Calculate response synchronization
	var synchronization: float = _calculate_response_synchronization(dynamic_formation)
	
	# Calculate leadership effectiveness
	var leadership: float = _calculate_leadership_effectiveness(dynamic_formation)
	
	# Combine coordination factors
	var coordination_score: float = (
		command_control * 0.3 +
		communication * 0.25 +
		synchronization * 0.25 +
		leadership * 0.2
	)
	
	return {
		"score": coordination_score,
		"command_control": command_control,
		"communication": communication,
		"synchronization": synchronization,
		"leadership": leadership
	}

func _calculate_command_control_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate command and control effectiveness
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# Check if leader is valid and capable
	if not is_instance_valid(base_formation.leader):
		return 0.0
	
	var leadership_capability: float = _get_ship_leadership_capability(base_formation.leader)
	var span_of_control: float = _calculate_span_of_control(base_formation)
	
	return (leadership_capability + span_of_control) * 0.5

func _get_ship_leadership_capability(ship: Node3D) -> float:
	# Get leadership capability of ship
	if ship.has_method("get_leadership_rating"):
		return ship.get_leadership_rating()
	elif ship.has_method("get_experience_level"):
		return ship.get_experience_level()
	else:
		return 0.7  # Default moderate leadership

func _calculate_span_of_control(base_formation: FormationManager.Formation) -> float:
	# Calculate if span of control is manageable
	var ship_count: int = base_formation.members.size() + 1
	var optimal_span: int = 6  # Optimal span of control
	
	if ship_count <= optimal_span:
		return 1.0
	else:
		return optimal_span / float(ship_count)

func _calculate_communication_efficiency(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate communication efficiency within formation
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var total_efficiency: float = 0.0
	var ship_count: int = 0
	
	# Check communication capability of each ship
	if is_instance_valid(base_formation.leader):
		total_efficiency += _get_ship_communication_capability(base_formation.leader)
		ship_count += 1
	
	for member in base_formation.members:
		if is_instance_valid(member):
			total_efficiency += _get_ship_communication_capability(member)
			ship_count += 1
	
	var average_efficiency: float = total_efficiency / max(ship_count, 1)
	
	# Adjust for formation size (larger formations have communication challenges)
	var size_penalty: float = clamp(1.0 - (ship_count - 4) * 0.1, 0.5, 1.0)
	
	return average_efficiency * size_penalty

func _get_ship_communication_capability(ship: Node3D) -> float:
	# Get communication capability of ship
	if ship.has_method("get_communication_efficiency"):
		return ship.get_communication_efficiency()
	else:
		return 0.8  # Default good communication

func _calculate_response_synchronization(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate how well ships synchronize responses
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	# This would be enhanced with actual movement/response data
	var formation_integrity: float = base_formation.get_formation_integrity()
	
	# Use formation integrity as proxy for synchronization
	return formation_integrity

func _calculate_leadership_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate overall leadership effectiveness
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	
	if not is_instance_valid(base_formation.leader):
		return 0.0
	
	var leader_capability: float = _get_ship_leadership_capability(base_formation.leader)
	var leader_status: float = _get_ship_combat_readiness(base_formation.leader)
	
	return (leader_capability + leader_status) * 0.5

func _calculate_adaptation_effectiveness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Calculate adaptation effectiveness
	var transition_state: DynamicFormationManager.TransitionState = dynamic_formation.transition_state
	
	# Calculate transition smoothness
	var transition_smoothness: float = _calculate_transition_smoothness(dynamic_formation)
	
	# Calculate adaptation speed
	var adaptation_speed: float = _calculate_adaptation_speed(dynamic_formation)
	
	# Calculate flexibility in adaptation
	var adaptation_flexibility: float = _calculate_adaptation_flexibility(dynamic_formation)
	
	# Calculate learning capability
	var learning_capability: float = _calculate_learning_capability(dynamic_formation)
	
	# Combine adaptation factors
	var adaptation_score: float = (
		transition_smoothness * 0.3 +
		adaptation_speed * 0.25 +
		adaptation_flexibility * 0.25 +
		learning_capability * 0.2
	)
	
	return {
		"score": adaptation_score,
		"transition_smoothness": transition_smoothness,
		"adaptation_speed": adaptation_speed,
		"adaptation_flexibility": adaptation_flexibility,
		"learning_capability": learning_capability
	}

func _calculate_transition_smoothness(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate smoothness of formation transitions
	var transition_state: DynamicFormationManager.TransitionState = dynamic_formation.transition_state
	
	if not transition_state.is_transitioning:
		return 1.0  # Not transitioning = perfect smoothness
	
	# Use transition effectiveness as smoothness metric
	return transition_state.transition_effectiveness

func _calculate_adaptation_speed(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate speed of adaptation to changing conditions
	# This would track historical adaptation times
	return 0.7  # Default moderate adaptation speed

func _calculate_adaptation_flexibility(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate flexibility in adaptation options
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var ship_count: int = base_formation.members.size() + 1
	
	# More ships provide more adaptation options
	var size_flexibility: float = clamp(ship_count / 10.0, 0.0, 1.0)
	
	# Formation integrity affects adaptation capability
	var integrity_flexibility: float = base_formation.get_formation_integrity()
	
	return (size_flexibility + integrity_flexibility) * 0.5

func _calculate_learning_capability(dynamic_formation: DynamicFormationManager.DynamicFormation) -> float:
	# Calculate learning and improvement capability
	# This would track performance improvement over time
	return 0.6  # Default moderate learning capability

func _get_default_effectiveness_metrics() -> Dictionary:
	# Return default effectiveness metrics for invalid formations
	return {
		"overall_effectiveness": 0.0,
		"positioning_effectiveness": {"score": 0.0},
		"coverage_effectiveness": {"score": 0.0},
		"tactical_effectiveness": {"score": 0.0},
		"coordination_effectiveness": {"score": 0.0},
		"adaptation_effectiveness": {"score": 0.0},
		"calculation_timestamp": Time.get_time_from_start(),
		"formation_type": "invalid",
		"ship_count": 0,
		"effectiveness_grade": "F"
	}

func _determine_effectiveness_grade(overall_effectiveness: float) -> String:
	# Determine effectiveness grade from score
	if overall_effectiveness >= 0.9:
		return "A+"
	elif overall_effectiveness >= 0.85:
		return "A"
	elif overall_effectiveness >= 0.8:
		return "A-"
	elif overall_effectiveness >= 0.75:
		return "B+"
	elif overall_effectiveness >= 0.7:
		return "B"
	elif overall_effectiveness >= 0.65:
		return "B-"
	elif overall_effectiveness >= 0.6:
		return "C+"
	elif overall_effectiveness >= 0.55:
		return "C"
	elif overall_effectiveness >= 0.5:
		return "C-"
	elif overall_effectiveness >= 0.4:
		return "D"
	else:
		return "F"

func _update_effectiveness_history(formation_id: String, effectiveness_metrics: Dictionary) -> void:
	# Update effectiveness history for formation
	if not effectiveness_history.has(formation_id):
		effectiveness_history[formation_id] = []
	
	var history: Array = effectiveness_history[formation_id]
	history.append(effectiveness_metrics)
	
	# Keep only recent history (last 50 measurements)
	if history.size() > 50:
		history = history.slice(-50)
		effectiveness_history[formation_id] = history

func _check_effectiveness_alerts(formation_id: String, effectiveness_metrics: Dictionary) -> void:
	# Check for effectiveness alerts
	var overall_effectiveness: float = effectiveness_metrics.get("overall_effectiveness", 0.0)
	var previous_effectiveness: float = _get_previous_effectiveness(formation_id)
	
	# Check for poor effectiveness
	if overall_effectiveness < alert_thresholds["poor_effectiveness"]:
		performance_alert.emit(formation_id, "poor_effectiveness", {
			"current_effectiveness": overall_effectiveness,
			"threshold": alert_thresholds["poor_effectiveness"],
			"metrics": effectiveness_metrics
		})
		calculation_performance["alert_count"] += 1
	
	# Check for excellent effectiveness
	if overall_effectiveness > alert_thresholds["excellent_effectiveness"]:
		performance_alert.emit(formation_id, "excellent_effectiveness", {
			"current_effectiveness": overall_effectiveness,
			"threshold": alert_thresholds["excellent_effectiveness"],
			"metrics": effectiveness_metrics
		})
	
	# Check for significant changes
	if abs(overall_effectiveness - previous_effectiveness) > 0.2:
		effectiveness_threshold_crossed.emit(formation_id, "overall_effectiveness", previous_effectiveness, overall_effectiveness)

func _get_previous_effectiveness(formation_id: String) -> float:
	# Get previous effectiveness measurement
	if not effectiveness_history.has(formation_id):
		return 0.5
	
	var history: Array = effectiveness_history[formation_id]
	if history.size() < 2:
		return 0.5
	
	var previous_metrics: Dictionary = history[-2]
	return previous_metrics.get("overall_effectiveness", 0.5)

func _update_calculation_performance(calculation_time: float) -> void:
	# Update calculation performance tracking
	calculation_performance["total_calculations"] += 1
	var total_calcs: int = calculation_performance["total_calculations"]
	var current_avg: float = calculation_performance["average_calculation_time"]
	
	calculation_performance["average_calculation_time"] = (current_avg * (total_calcs - 1) + calculation_time) / total_calcs

## Gets formation effectiveness history
func get_formation_effectiveness_history(formation_id: String) -> Array:
	return effectiveness_history.get(formation_id, [])

## Gets calculation performance statistics
func get_calculation_performance_statistics() -> Dictionary:
	return calculation_performance.duplicate()

## Clears effectiveness history for formation
func clear_formation_effectiveness_history(formation_id: String) -> void:
	effectiveness_history.erase(formation_id)