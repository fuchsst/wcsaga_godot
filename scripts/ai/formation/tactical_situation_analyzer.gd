class_name TacticalSituationAnalyzer
extends Node

## Tactical situation analyzer for formation management.
## Analyzes battlefield conditions to recommend formation changes and adaptations.

signal tactical_situation_changed(situation_summary: Dictionary)
signal threat_assessment_updated(threat_level: float, threat_analysis: Dictionary)
signal terrain_analysis_completed(terrain_assessment: Dictionary)
signal formation_recommendation_generated(formation_id: String, recommended_type: int, confidence: float)

## Threat assessment levels
enum ThreatLevel {
	MINIMAL,      ## 0.0-0.2: Low threat environment
	LOW,          ## 0.2-0.4: Some hostile presence
	MODERATE,     ## 0.4-0.6: Active combat situation
	HIGH,         ## 0.6-0.8: Heavy combat engagement
	CRITICAL      ## 0.8-1.0: Overwhelming enemy presence
}

## Terrain complexity assessment
enum TerrainComplexity {
	OPEN_SPACE,   ## Clear space with minimal obstacles
	LIGHT_DEBRIS, ## Some debris or minor obstacles
	MODERATE,     ## Moderate obstacle density
	DENSE,        ## High obstacle density requiring navigation
	EXTREME       ## Extreme obstacle density limiting maneuvers
}

## Mission phase assessment
enum MissionPhase {
	APPROACH,     ## Moving to objective area
	ENGAGEMENT,   ## Active combat operations
	PATROL,       ## Patrol or reconnaissance operations
	ESCORT,       ## Escort or protection mission
	WITHDRAWAL,   ## Tactical withdrawal or retreat
	TRANSIT       ## Long-distance movement between areas
}

# Analysis parameters
var analysis_parameters: Dictionary = {}
var threat_assessment_range: float = 3000.0
var terrain_analysis_resolution: float = 100.0
var situation_update_frequency: float = 0.5
var tactical_factor_weights: Dictionary = {}

# Current analysis state
var current_threat_level: ThreatLevel = ThreatLevel.MINIMAL
var current_terrain_complexity: TerrainComplexity = TerrainComplexity.OPEN_SPACE
var current_mission_phase: MissionPhase = MissionPhase.PATROL
var last_analysis_time: float = 0.0

# Cached analysis results
var threat_analysis_cache: Dictionary = {}
var terrain_analysis_cache: Dictionary = {}
var formation_context_cache: Dictionary = {}

# Performance tracking
var analysis_performance: Dictionary = {}

func _ready() -> void:
	_initialize_default_parameters()
	_setup_performance_tracking()

func _initialize_default_parameters() -> void:
	analysis_parameters = {
		"threat_assessment_range": 3000.0,
		"terrain_analysis_resolution": 100.0,
		"situation_update_frequency": 0.5,
		"cache_expiry_time": 2.0,
		"analysis_depth": 1.0
	}
	
	tactical_factor_weights = {
		DynamicFormationManager.TacticalFactor.THREAT_LEVEL: 0.25,
		DynamicFormationManager.TacticalFactor.TERRAIN_DENSITY: 0.15,
		DynamicFormationManager.TacticalFactor.MISSION_PHASE: 0.20,
		DynamicFormationManager.TacticalFactor.DAMAGE_STATUS: 0.15,
		DynamicFormationManager.TacticalFactor.ENERGY_LEVELS: 0.10,
		DynamicFormationManager.TacticalFactor.ENEMY_FORMATION: 0.15
	}

func _setup_performance_tracking() -> void:
	analysis_performance = {
		"total_analyses": 0,
		"average_analysis_time": 0.0,
		"cache_hit_rate": 0.0,
		"recommendation_accuracy": 0.0
	}

func initialize_analysis_parameters(parameters: Dictionary) -> void:
	## Initializes analysis parameters for tactical assessment
	analysis_parameters.merge(parameters, true)
	threat_assessment_range = analysis_parameters.get("threat_assessment_range", 3000.0)
	terrain_analysis_resolution = analysis_parameters.get("terrain_analysis_resolution", 100.0)
	situation_update_frequency = analysis_parameters.get("situation_update_frequency", 0.5)
	tactical_factor_weights = analysis_parameters.get("tactical_factor_weights", tactical_factor_weights)

func _process(delta: float) -> void:
	# Update tactical situation periodically
	if Time.get_time_from_start() - last_analysis_time > situation_update_frequency:
		_update_tactical_situation()
		last_analysis_time = Time.get_time_from_start()

func _update_tactical_situation() -> void:
	# Update overall tactical situation assessment
	var situation_summary: Dictionary = {
		"threat_level": current_threat_level,
		"terrain_complexity": current_terrain_complexity,
		"mission_phase": current_mission_phase,
		"timestamp": Time.get_time_from_start()
	}
	
	tactical_situation_changed.emit(situation_summary)

## Analyzes tactical context for a formation
func analyze_formation_context(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	var formation_id: String = dynamic_formation.formation_id
	var current_time: float = Time.get_time_from_start()
	
	# Check cache first
	if formation_context_cache.has(formation_id):
		var cached_data: Dictionary = formation_context_cache[formation_id]
		if current_time - cached_data.get("timestamp", 0.0) < analysis_parameters.get("cache_expiry_time", 2.0):
			analysis_performance["cache_hit_rate"] = min(analysis_performance["cache_hit_rate"] + 0.01, 1.0)
			return cached_data
	
	var start_time: float = Time.get_time_from_system() * 1000.0  # Milliseconds
	
	# Perform fresh analysis
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if not is_instance_valid(base_formation.leader):
		return {}
	
	var formation_center: Vector3 = base_formation.leader.global_position
	
	# Analyze tactical factors
	var threat_analysis: Dictionary = _analyze_threat_environment(formation_center)
	var terrain_analysis: Dictionary = _analyze_terrain_environment(formation_center)
	var mission_analysis: Dictionary = _analyze_mission_context(dynamic_formation)
	var damage_analysis: Dictionary = _analyze_formation_damage_status(dynamic_formation)
	var energy_analysis: Dictionary = _analyze_formation_energy_levels(dynamic_formation)
	var enemy_formation_analysis: Dictionary = _analyze_enemy_formations(formation_center)
	
	# Combine analyses into context
	var tactical_context: Dictionary = {
		"formation_id": formation_id,
		"timestamp": current_time,
		"threat_analysis": threat_analysis,
		"terrain_analysis": terrain_analysis,
		"mission_analysis": mission_analysis,
		"damage_analysis": damage_analysis,
		"energy_analysis": energy_analysis,
		"enemy_formation_analysis": enemy_formation_analysis,
		"overall_threat_level": threat_analysis.get("threat_level", 0.0),
		"terrain_complexity": terrain_analysis.get("complexity_score", 0.0),
		"mission_urgency": mission_analysis.get("urgency", 0.5),
		"formation_readiness": _calculate_formation_readiness(damage_analysis, energy_analysis),
		"tactical_pressure": _calculate_tactical_pressure(threat_analysis, terrain_analysis, mission_analysis)
	}
	
	# Cache result
	formation_context_cache[formation_id] = tactical_context
	
	# Update performance tracking
	var analysis_time: float = (Time.get_time_from_system() * 1000.0) - start_time
	analysis_performance["total_analyses"] += 1
	analysis_performance["average_analysis_time"] = (
		analysis_performance["average_analysis_time"] * (analysis_performance["total_analyses"] - 1) + analysis_time
	) / analysis_performance["total_analyses"]
	
	return tactical_context

func _analyze_threat_environment(position: Vector3) -> Dictionary:
	# Analyze threat environment around position
	var threat_contacts: Array[Node3D] = _detect_threat_contacts(position)
	var threat_level: float = 0.0
	var threat_distribution: Dictionary = {"front": 0, "rear": 0, "left": 0, "right": 0, "above": 0, "below": 0}
	var threat_types: Dictionary = {"fighter": 0, "bomber": 0, "capital": 0, "missile": 0}
	var immediate_threats: Array[Node3D] = []
	
	for threat in threat_contacts:
		if not is_instance_valid(threat):
			continue
		
		var distance: float = position.distance_to(threat.global_position)
		var threat_weight: float = _calculate_threat_weight(threat, distance)
		threat_level += threat_weight
		
		# Analyze threat distribution
		var direction: Vector3 = (threat.global_position - position).normalized()
		_update_threat_distribution(threat_distribution, direction, threat_weight)
		
		# Categorize threat type
		var threat_type: String = _categorize_threat_type(threat)
		threat_types[threat_type] = threat_types.get(threat_type, 0) + 1
		
		# Check for immediate threats
		if distance < threat_assessment_range * 0.3:
			immediate_threats.append(threat)
	
	# Normalize threat level
	threat_level = clamp(threat_level / 10.0, 0.0, 1.0)
	current_threat_level = _determine_threat_level(threat_level)
	
	var threat_analysis: Dictionary = {
		"threat_level": threat_level,
		"threat_level_enum": current_threat_level,
		"threat_count": threat_contacts.size(),
		"immediate_threats": immediate_threats.size(),
		"threat_distribution": threat_distribution,
		"threat_types": threat_types,
		"primary_threat_direction": _get_primary_threat_direction(threat_distribution),
		"threat_density": threat_contacts.size() / (threat_assessment_range / 1000.0)
	}
	
	threat_assessment_updated.emit(threat_level, threat_analysis)
	return threat_analysis

func _detect_threat_contacts(position: Vector3) -> Array[Node3D]:
	# Detect threat contacts within range
	var threats: Array[Node3D] = []
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	# Use sphere query to find potential threats
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = threat_assessment_range
	query.shape = sphere
	query.transform.origin = position
	query.collision_mask = 0b10  # Enemy layer
	
	var results: Array[Dictionary] = space_state.intersect_shape(query)
	
	for result in results:
		var collider: Node = result.get("collider")
		if collider and collider is Node3D:
			var threat_node: Node3D = collider as Node3D
			if _is_hostile_entity(threat_node):
				threats.append(threat_node)
	
	return threats

func _is_hostile_entity(entity: Node3D) -> bool:
	# Check if entity is hostile
	# This would interface with the game's faction/team system
	if entity.has_method("get_team"):
		return entity.get_team() != "player"
	
	# Check for enemy tag
	if entity.is_in_group("enemies"):
		return true
	
	# Default assessment based on naming
	return entity.name.begins_with("Enemy") or entity.name.begins_with("Hostile")

func _calculate_threat_weight(threat: Node3D, distance: float) -> float:
	# Calculate threat weight based on type and distance
	var base_weight: float = 1.0
	var distance_factor: float = clamp(1.0 - (distance / threat_assessment_range), 0.1, 1.0)
	
	# Adjust weight based on threat type
	var threat_type: String = _categorize_threat_type(threat)
	match threat_type:
		"capital":
			base_weight = 3.0
		"bomber":
			base_weight = 2.0
		"fighter":
			base_weight = 1.0
		"missile":
			base_weight = 1.5
		_:
			base_weight = 1.0
	
	# Adjust for threat capabilities
	if threat.has_method("get_weapon_threat_level"):
		base_weight *= threat.get_weapon_threat_level()
	
	return base_weight * distance_factor

func _categorize_threat_type(threat: Node3D) -> String:
	# Categorize threat type for tactical analysis
	if threat.has_method("get_ship_class"):
		var ship_class: String = threat.get_ship_class()
		if "capital" in ship_class.to_lower() or "cruiser" in ship_class.to_lower():
			return "capital"
		elif "bomber" in ship_class.to_lower():
			return "bomber"
		elif "fighter" in ship_class.to_lower():
			return "fighter"
	
	if threat.has_method("is_missile") and threat.is_missile():
		return "missile"
	
	# Default categorization based on scale
	var scale: Vector3 = threat.scale
	var size_factor: float = (scale.x + scale.y + scale.z) / 3.0
	
	if size_factor > 5.0:
		return "capital"
	elif size_factor > 2.0:
		return "bomber"
	else:
		return "fighter"

func _update_threat_distribution(distribution: Dictionary, direction: Vector3, weight: float) -> void:
	# Update threat distribution based on direction
	var abs_dir: Vector3 = direction.abs()
	
	if abs_dir.z > 0.6:  # Front/rear
		if direction.z > 0:
			distribution["front"] = distribution["front"] + weight
		else:
			distribution["rear"] = distribution["rear"] + weight
	
	if abs_dir.x > 0.6:  # Left/right
		if direction.x > 0:
			distribution["right"] = distribution["right"] + weight
		else:
			distribution["left"] = distribution["left"] + weight
	
	if abs_dir.y > 0.6:  # Above/below
		if direction.y > 0:
			distribution["above"] = distribution["above"] + weight
		else:
			distribution["below"] = distribution["below"] + weight

func _get_primary_threat_direction(distribution: Dictionary) -> String:
	# Get primary threat direction
	var max_threat: float = 0.0
	var primary_direction: String = "none"
	
	for direction in distribution:
		var threat_value: float = distribution[direction]
		if threat_value > max_threat:
			max_threat = threat_value
			primary_direction = direction
	
	return primary_direction

func _determine_threat_level(threat_value: float) -> ThreatLevel:
	# Determine threat level enum from value
	if threat_value < 0.2:
		return ThreatLevel.MINIMAL
	elif threat_value < 0.4:
		return ThreatLevel.LOW
	elif threat_value < 0.6:
		return ThreatLevel.MODERATE
	elif threat_value < 0.8:
		return ThreatLevel.HIGH
	else:
		return ThreatLevel.CRITICAL

func _analyze_terrain_environment(position: Vector3) -> Dictionary:
	# Analyze terrain/obstacle environment
	var obstacle_count: int = 0
	var obstacle_density: float = 0.0
	var navigation_difficulty: float = 0.0
	var maneuver_space: float = 1.0
	var terrain_features: Array[String] = []
	
	# Sample terrain in grid around position
	var sample_range: float = threat_assessment_range * 0.5
	var sample_count: int = int(sample_range / terrain_analysis_resolution)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	for x in range(-sample_count, sample_count + 1):
		for z in range(-sample_count, sample_count + 1):
			var sample_pos: Vector3 = position + Vector3(
				x * terrain_analysis_resolution,
				0,
				z * terrain_analysis_resolution
			)
			
			# Raycast to detect obstacles
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				sample_pos + Vector3.UP * 500.0,
				sample_pos + Vector3.DOWN * 500.0
			)
			query.collision_mask = 0b100  # Obstacle layer
			
			var result: Dictionary = space_state.intersect_ray(query)
			if result:
				obstacle_count += 1
				var obstacle: Node = result.get("collider")
				if obstacle:
					_categorize_terrain_feature(obstacle, terrain_features)
	
	# Calculate metrics
	var total_samples: int = (sample_count * 2 + 1) * (sample_count * 2 + 1)
	obstacle_density = float(obstacle_count) / float(total_samples)
	navigation_difficulty = clamp(obstacle_density * 2.0, 0.0, 1.0)
	maneuver_space = 1.0 - navigation_difficulty
	
	current_terrain_complexity = _determine_terrain_complexity(obstacle_density)
	
	var terrain_analysis: Dictionary = {
		"complexity_score": navigation_difficulty,
		"complexity_enum": current_terrain_complexity,
		"obstacle_count": obstacle_count,
		"obstacle_density": obstacle_density,
		"maneuver_space": maneuver_space,
		"terrain_features": terrain_features,
		"navigation_difficulty": navigation_difficulty
	}
	
	terrain_analysis_completed.emit(terrain_analysis)
	return terrain_analysis

func _categorize_terrain_feature(obstacle: Node, features: Array[String]) -> void:
	# Categorize terrain features for tactical analysis
	var feature_name: String = obstacle.name.to_lower()
	
	if "asteroid" in feature_name:
		if "asteroid_field" not in features:
			features.append("asteroid_field")
	elif "debris" in feature_name:
		if "debris_field" not in features:
			features.append("debris_field")
	elif "station" in feature_name or "structure" in feature_name:
		if "structures" not in features:
			features.append("structures")
	elif "ship" in feature_name and "wreck" in feature_name:
		if "ship_graveyard" not in features:
			features.append("ship_graveyard")

func _determine_terrain_complexity(density: float) -> TerrainComplexity:
	# Determine terrain complexity from obstacle density
	if density < 0.1:
		return TerrainComplexity.OPEN_SPACE
	elif density < 0.3:
		return TerrainComplexity.LIGHT_DEBRIS
	elif density < 0.5:
		return TerrainComplexity.MODERATE
	elif density < 0.7:
		return TerrainComplexity.DENSE
	else:
		return TerrainComplexity.EXTREME

func _analyze_mission_context(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Analyze mission context for formation
	var mission_urgency: float = 0.5
	var mission_type: String = "patrol"
	var mission_phase: MissionPhase = MissionPhase.PATROL
	var time_pressure: float = 0.0
	var objective_distance: float = 0.0
	
	# Check for mission objectives (would interface with mission system)
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	if is_instance_valid(base_formation.leader):
		var leader: Node3D = base_formation.leader
		
		# Check if leader has mission data
		if leader.has_method("get_current_mission"):
			var mission_data: Dictionary = leader.get_current_mission()
			mission_type = mission_data.get("type", "patrol")
			mission_urgency = mission_data.get("urgency", 0.5)
			time_pressure = mission_data.get("time_pressure", 0.0)
			
			# Determine mission phase
			mission_phase = _determine_mission_phase(mission_data, leader)
		
		# Check for objectives
		if leader.has_method("get_objective_distance"):
			objective_distance = leader.get_objective_distance()
	
	current_mission_phase = mission_phase
	
	return {
		"mission_type": mission_type,
		"mission_phase": mission_phase,
		"urgency": mission_urgency,
		"time_pressure": time_pressure,
		"objective_distance": objective_distance,
		"mission_criticality": _calculate_mission_criticality(mission_type, mission_urgency)
	}

func _determine_mission_phase(mission_data: Dictionary, leader: Node3D) -> MissionPhase:
	# Determine current mission phase
	var phase_str: String = mission_data.get("phase", "patrol")
	
	match phase_str.to_lower():
		"approach", "transit":
			return MissionPhase.APPROACH
		"engagement", "attack", "assault":
			return MissionPhase.ENGAGEMENT
		"escort", "protect":
			return MissionPhase.ESCORT
		"withdrawal", "retreat":
			return MissionPhase.WITHDRAWAL
		"patrol", "reconnaissance":
			return MissionPhase.PATROL
		_:
			# Determine from ship state
			if leader.has_method("get_combat_state"):
				var combat_state: String = leader.get_combat_state()
				if combat_state == "combat":
					return MissionPhase.ENGAGEMENT
			
			return MissionPhase.PATROL

func _calculate_mission_criticality(mission_type: String, urgency: float) -> float:
	# Calculate mission criticality factor
	var base_criticality: float = urgency
	
	match mission_type.to_lower():
		"assault", "strike":
			base_criticality *= 1.3
		"escort", "protect":
			base_criticality *= 1.2
		"rescue", "emergency":
			base_criticality *= 1.5
		"patrol", "reconnaissance":
			base_criticality *= 0.8
		_:
			base_criticality *= 1.0
	
	return clamp(base_criticality, 0.0, 1.0)

func _analyze_formation_damage_status(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Analyze damage status of formation ships
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var total_damage: float = 0.0
	var ship_count: int = 0
	var damaged_ships: int = 0
	var critical_damage_ships: int = 0
	var ship_damage_levels: Array[float] = []
	
	# Analyze leader damage
	if is_instance_valid(base_formation.leader):
		var leader_damage: float = _get_ship_damage_level(base_formation.leader)
		total_damage += leader_damage
		ship_count += 1
		ship_damage_levels.append(leader_damage)
		
		if leader_damage > 0.3:
			damaged_ships += 1
		if leader_damage > 0.7:
			critical_damage_ships += 1
	
	# Analyze member damage
	for member in base_formation.members:
		if is_instance_valid(member):
			var member_damage: float = _get_ship_damage_level(member)
			total_damage += member_damage
			ship_count += 1
			ship_damage_levels.append(member_damage)
			
			if member_damage > 0.3:
				damaged_ships += 1
			if member_damage > 0.7:
				critical_damage_ships += 1
	
	var average_damage: float = total_damage / max(ship_count, 1)
	var formation_readiness: float = 1.0 - average_damage
	
	return {
		"average_damage": average_damage,
		"formation_readiness": formation_readiness,
		"damaged_ships": damaged_ships,
		"critical_damage_ships": critical_damage_ships,
		"total_ships": ship_count,
		"damage_distribution": ship_damage_levels,
		"needs_adaptation": average_damage > 0.4 or critical_damage_ships > 0
	}

func _get_ship_damage_level(ship: Node3D) -> float:
	# Get damage level for a ship
	if ship.has_method("get_damage_percentage"):
		return ship.get_damage_percentage()
	elif ship.has_method("get_health_percentage"):
		return 1.0 - ship.get_health_percentage()
	else:
		# Estimate from ship state
		return 0.0

func _analyze_formation_energy_levels(dynamic_formation: DynamicFormationManager.DynamicFormation) -> Dictionary:
	# Analyze energy levels of formation ships
	var base_formation: FormationManager.Formation = dynamic_formation.base_formation
	var total_energy: float = 0.0
	var ship_count: int = 0
	var low_energy_ships: int = 0
	var energy_levels: Array[float] = []
	
	# Analyze leader energy
	if is_instance_valid(base_formation.leader):
		var leader_energy: float = _get_ship_energy_level(base_formation.leader)
		total_energy += leader_energy
		ship_count += 1
		energy_levels.append(leader_energy)
		
		if leader_energy < 0.3:
			low_energy_ships += 1
	
	# Analyze member energy
	for member in base_formation.members:
		if is_instance_valid(member):
			var member_energy: float = _get_ship_energy_level(member)
			total_energy += member_energy
			ship_count += 1
			energy_levels.append(member_energy)
			
			if member_energy < 0.3:
				low_energy_ships += 1
	
	var average_energy: float = total_energy / max(ship_count, 1)
	
	return {
		"average_energy": average_energy,
		"low_energy_ships": low_energy_ships,
		"total_ships": ship_count,
		"energy_distribution": energy_levels,
		"energy_crisis": average_energy < 0.2 or low_energy_ships > ship_count / 2
	}

func _get_ship_energy_level(ship: Node3D) -> float:
	# Get energy level for a ship
	if ship.has_method("get_energy_percentage"):
		return ship.get_energy_percentage()
	else:
		# Default assumption of good energy
		return 1.0

func _analyze_enemy_formations(position: Vector3) -> Dictionary:
	# Analyze enemy formation patterns
	var enemy_formations: Array[Dictionary] = []
	var formation_threats: float = 0.0
	var coordinated_enemies: int = 0
	
	# Detect potential enemy formations
	var enemies: Array[Node3D] = _detect_threat_contacts(position)
	var formation_groups: Array[Array] = _group_enemies_by_proximity(enemies)
	
	for group in formation_groups:
		if group.size() >= 3:  # Minimum formation size
			var formation_analysis: Dictionary = _analyze_enemy_group_formation(group)
			enemy_formations.append(formation_analysis)
			formation_threats += formation_analysis.get("threat_multiplier", 1.0)
			coordinated_enemies += group.size()
	
	return {
		"enemy_formations": enemy_formations,
		"formation_count": enemy_formations.size(),
		"coordinated_enemies": coordinated_enemies,
		"formation_threat_multiplier": formation_threats,
		"coordination_detected": enemy_formations.size() > 0
	}

func _group_enemies_by_proximity(enemies: Array[Node3D]) -> Array[Array]:
	# Group enemies by proximity to detect formations
	var groups: Array[Array] = []
	var ungrouped_enemies: Array[Node3D] = enemies.duplicate()
	var formation_detection_range: float = 500.0  # Range for formation detection
	
	while not ungrouped_enemies.is_empty():
		var seed_enemy: Node3D = ungrouped_enemies[0]
		var group: Array[Node3D] = [seed_enemy]
		ungrouped_enemies.erase(seed_enemy)
		
		# Find nearby enemies
		var added_to_group: bool = true
		while added_to_group:
			added_to_group = false
			for enemy in ungrouped_enemies:
				var min_distance: float = INF
				for group_member in group:
					var distance: float = enemy.global_position.distance_to(group_member.global_position)
					min_distance = min(min_distance, distance)
				
				if min_distance <= formation_detection_range:
					group.append(enemy)
					ungrouped_enemies.erase(enemy)
					added_to_group = true
					break
		
		groups.append(group)
	
	return groups

func _analyze_enemy_group_formation(group: Array[Node3D]) -> Dictionary:
	# Analyze formation pattern of enemy group
	var formation_type: String = "unknown"
	var formation_discipline: float = 0.5
	var threat_multiplier: float = 1.0
	
	if group.size() < 2:
		return {"formation_type": "individual", "discipline": 0.0, "threat_multiplier": 1.0}
	
	# Calculate formation metrics
	var center: Vector3 = Vector3.ZERO
	for enemy in group:
		center += enemy.global_position
	center /= group.size()
	
	var distances: Array[float] = []
	var angles: Array[float] = []
	
	for enemy in group:
		var distance: float = center.distance_to(enemy.global_position)
		distances.append(distance)
		
		if group.size() > 2:
			var direction: Vector3 = (enemy.global_position - center).normalized()
			var angle: float = atan2(direction.x, direction.z)
			angles.append(angle)
	
	# Analyze formation pattern
	formation_type = _determine_enemy_formation_type(distances, angles, group.size())
	formation_discipline = _calculate_formation_discipline(distances)
	threat_multiplier = _calculate_formation_threat_multiplier(formation_type, formation_discipline, group.size())
	
	return {
		"formation_type": formation_type,
		"discipline": formation_discipline,
		"threat_multiplier": threat_multiplier,
		"ship_count": group.size(),
		"center_position": center
	}

func _determine_enemy_formation_type(distances: Array[float], angles: Array[float], ship_count: int) -> String:
	# Determine enemy formation type from metrics
	if ship_count < 3:
		return "pair"
	
	# Calculate distance variance
	var avg_distance: float = 0.0
	for distance in distances:
		avg_distance += distance
	avg_distance /= distances.size()
	
	var distance_variance: float = 0.0
	for distance in distances:
		distance_variance += (distance - avg_distance) * (distance - avg_distance)
	distance_variance /= distances.size()
	
	# Analyze formation based on patterns
	if distance_variance < avg_distance * 0.1:  # Low variance = tight formation
		if ship_count >= 4:
			return "diamond"
		else:
			return "tight_group"
	elif angles.size() >= 3:
		# Check for line formation
		var angle_spread: float = _calculate_angle_spread(angles)
		if angle_spread < PI * 0.3:  # Narrow angle spread
			return "line"
		elif angle_spread > PI * 1.5:  # Wide spread
			return "envelopment"
		else:
			return "loose_formation"
	else:
		return "scattered"

func _calculate_angle_spread(angles: Array[float]) -> float:
	# Calculate angular spread of formation
	if angles.size() < 2:
		return 0.0
	
	var min_angle: float = angles[0]
	var max_angle: float = angles[0]
	
	for angle in angles:
		min_angle = min(min_angle, angle)
		max_angle = max(max_angle, angle)
	
	return max_angle - min_angle

func _calculate_formation_discipline(distances: Array[float]) -> float:
	# Calculate formation discipline from distance consistency
	if distances.size() < 2:
		return 1.0
	
	var avg_distance: float = 0.0
	for distance in distances:
		avg_distance += distance
	avg_distance /= distances.size()
	
	var variance: float = 0.0
	for distance in distances:
		variance += abs(distance - avg_distance)
	variance /= distances.size()
	
	# Lower variance = higher discipline
	var discipline: float = 1.0 - clamp(variance / max(avg_distance, 1.0), 0.0, 1.0)
	return discipline

func _calculate_formation_threat_multiplier(formation_type: String, discipline: float, ship_count: int) -> float:
	# Calculate threat multiplier based on formation characteristics
	var base_multiplier: float = 1.0
	
	match formation_type:
		"diamond", "tight_group":
			base_multiplier = 1.3
		"line":
			base_multiplier = 1.2
		"envelopment":
			base_multiplier = 1.5
		"loose_formation":
			base_multiplier = 1.1
		"scattered":
			base_multiplier = 0.9
		_:
			base_multiplier = 1.0
	
	# Adjust for discipline and size
	var discipline_bonus: float = discipline * 0.3
	var size_bonus: float = min(ship_count / 10.0, 0.5)
	
	return base_multiplier + discipline_bonus + size_bonus

func _calculate_formation_readiness(damage_analysis: Dictionary, energy_analysis: Dictionary) -> float:
	# Calculate overall formation readiness
	var damage_factor: float = 1.0 - damage_analysis.get("average_damage", 0.0)
	var energy_factor: float = energy_analysis.get("average_energy", 1.0)
	
	return (damage_factor + energy_factor) * 0.5

func _calculate_tactical_pressure(threat_analysis: Dictionary, terrain_analysis: Dictionary, mission_analysis: Dictionary) -> float:
	# Calculate overall tactical pressure
	var threat_pressure: float = threat_analysis.get("threat_level", 0.0)
	var terrain_pressure: float = terrain_analysis.get("navigation_difficulty", 0.0)
	var mission_pressure: float = mission_analysis.get("urgency", 0.0)
	
	return (threat_pressure * 0.5 + terrain_pressure * 0.2 + mission_pressure * 0.3)

## Generates formation recommendations based on tactical analysis
func generate_formation_recommendation(dynamic_formation: DynamicFormationManager.DynamicFormation, tactical_context: Dictionary) -> Dictionary:
	var current_type: DynamicFormationManager.AdvancedFormationType = dynamic_formation.current_type
	var threat_level: float = tactical_context.get("overall_threat_level", 0.0)
	var terrain_complexity: float = tactical_context.get("terrain_complexity", 0.0)
	var mission_urgency: float = tactical_context.get("mission_urgency", 0.5)
	var formation_readiness: float = tactical_context.get("formation_readiness", 1.0)
	
	var recommendations: Array[Dictionary] = []
	
	# Analyze each potential formation type
	for formation_type in DynamicFormationManager.AdvancedFormationType.values():
		if formation_type == current_type:
			continue  # Skip current formation
		
		var suitability: float = _calculate_formation_suitability(
			formation_type, threat_level, terrain_complexity, mission_urgency, formation_readiness
		)
		
		if suitability > 0.6:  # Only recommend suitable formations
			recommendations.append({
				"formation_type": formation_type,
				"suitability": suitability,
				"reasons": _get_formation_recommendation_reasons(formation_type, tactical_context)
			})
	
	# Sort by suitability
	recommendations.sort_custom(func(a, b): return a["suitability"] > b["suitability"])
	
	var best_recommendation: Dictionary = {}
	if not recommendations.is_empty():
		best_recommendation = recommendations[0]
		formation_recommendation_generated.emit(
			dynamic_formation.formation_id,
			best_recommendation["formation_type"],
			best_recommendation["suitability"]
		)
	
	return {
		"has_recommendation": not recommendations.is_empty(),
		"best_recommendation": best_recommendation,
		"all_recommendations": recommendations,
		"analysis_context": tactical_context
	}

func _calculate_formation_suitability(formation_type: DynamicFormationManager.AdvancedFormationType, threat_level: float, terrain_complexity: float, mission_urgency: float, formation_readiness: float) -> float:
	# Calculate suitability score for formation type
	var base_suitability: float = 0.5
	
	match formation_type:
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD:
			base_suitability = 0.3 + threat_level * 0.5 + (1.0 - terrain_complexity) * 0.2
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE:
			base_suitability = 0.2 + threat_level * 0.6 + (1.0 - formation_readiness) * 0.2
		DynamicFormationManager.AdvancedFormationType.ESCORT_SCREEN:
			base_suitability = 0.4 + mission_urgency * 0.3 + formation_readiness * 0.3
		DynamicFormationManager.AdvancedFormationType.STRIKE_WEDGE:
			base_suitability = 0.2 + mission_urgency * 0.5 + formation_readiness * 0.3
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_LAYERS:
			base_suitability = 0.3 + threat_level * 0.4 + (1.0 - terrain_complexity) * 0.3
		DynamicFormationManager.AdvancedFormationType.PATROL_SWEEP:
			base_suitability = 0.6 + (1.0 - threat_level) * 0.2 + (1.0 - mission_urgency) * 0.2
		DynamicFormationManager.AdvancedFormationType.MISSILE_SCREEN:
			base_suitability = 0.3 + threat_level * 0.5 + formation_readiness * 0.2
		DynamicFormationManager.AdvancedFormationType.PURSUIT_LINE:
			base_suitability = 0.4 + mission_urgency * 0.4 + formation_readiness * 0.2
		_:
			base_suitability = 0.5
	
	return clamp(base_suitability, 0.0, 1.0)

func _get_formation_recommendation_reasons(formation_type: DynamicFormationManager.AdvancedFormationType, tactical_context: Dictionary) -> Array[String]:
	# Get reasons for formation recommendation
	var reasons: Array[String] = []
	
	var threat_level: float = tactical_context.get("overall_threat_level", 0.0)
	var terrain_complexity: float = tactical_context.get("terrain_complexity", 0.0)
	var mission_urgency: float = tactical_context.get("mission_urgency", 0.5)
	
	match formation_type:
		DynamicFormationManager.AdvancedFormationType.COMBAT_SPREAD:
			if threat_level > 0.5:
				reasons.append("High threat level requires dispersed combat formation")
			if terrain_complexity < 0.3:
				reasons.append("Open space allows for wide combat deployment")
		
		DynamicFormationManager.AdvancedFormationType.DEFENSIVE_CIRCLE:
			if threat_level > 0.6:
				reasons.append("Heavy threat requires all-around defensive posture")
		
		DynamicFormationManager.AdvancedFormationType.STRIKE_WEDGE:
			if mission_urgency > 0.7:
				reasons.append("High urgency mission requires aggressive strike formation")
		
		DynamicFormationManager.AdvancedFormationType.PATROL_SWEEP:
			if threat_level < 0.3:
				reasons.append("Low threat environment suitable for wide patrol coverage")
	
	return reasons

## Gets analysis performance statistics
func get_analysis_performance_statistics() -> Dictionary:
	return analysis_performance.duplicate()

## Clears analysis caches
func clear_analysis_caches() -> void:
	threat_analysis_cache.clear()
	terrain_analysis_cache.clear()
	formation_context_cache.clear()