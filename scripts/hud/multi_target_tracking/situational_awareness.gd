class_name SituationalAwareness
extends Node

## HUD-008 Component 7: Situational Awareness and Tactical Overview System
## Advanced tactical analysis engine providing real-time situational assessment and tactical recommendations
## Synthesizes multi-target data into actionable intelligence for enhanced combat effectiveness

signal tactical_situation_changed(situation_type: String, urgency: int)
signal tactical_recommendation_issued(recommendation: Dictionary)
signal threat_environment_updated(threat_map: Dictionary)
signal engagement_opportunity_detected(opportunity: Dictionary)
signal defensive_alert_raised(alert_level: int, reason: String)
signal formation_analysis_completed(formation_data: Dictionary)

# Situational awareness parameters
@export var prediction_time: float = 5.0  # Seconds to predict ahead
@export var tactical_analysis_frequency: float = 10.0  # 10Hz tactical updates
@export var engagement_opportunity_threshold: float = 0.7
@export var defensive_alert_threshold: float = 0.6
@export var formation_analysis_enabled: bool = true

# Tactical analysis components
var tactical_analyzer: TacticalAnalyzer
var threat_environment_mapper: ThreatEnvironmentMapper
var engagement_calculator: EngagementCalculator
var defensive_advisor: DefensiveAdvisor
var formation_analyzer: FormationAnalyzer
var predictive_engine: PredictiveEngine

# Current situational state
var current_situation: TacticalSituation
var threat_environment: ThreatEnvironment
var engagement_opportunities: Array[EngagementOpportunity] = []
var defensive_recommendations: Array[DefensiveRecommendation] = []
var formation_assessments: Array[FormationAssessment] = []

# Situational history
var situation_history: Array[TacticalSituation] = []
var recommendation_history: Array[Dictionary] = []

# Configuration
var analysis_config: Dictionary = {
	"threat_weight": 0.4,
	"opportunity_weight": 0.3,
	"defensive_weight": 0.3,
	"prediction_accuracy_weight": 0.2,
	"formation_weight": 0.15,
	"experience_weight": 0.1
}

# Tactical situation assessment
class TacticalSituation:
	var timestamp: float
	var overall_threat_level: float = 0.0
	var tactical_advantage: float = 0.0  # -1.0 (disadvantage) to 1.0 (advantage)
	var situation_type: String = "neutral"  # defensive, neutral, offensive, critical
	var confidence: float = 0.0
	var primary_threats: Array[Dictionary] = []
	var available_opportunities: Array[Dictionary] = []
	var recommended_actions: Array[String] = []
	var situational_factors: Dictionary = {}
	var player_position: Vector3 = Vector3.ZERO
	var escape_routes: Array[Vector3] = []
	var tactical_zones: Dictionary = {}
	
	func _init():
		timestamp = Time.get_ticks_usec() / 1000000.0

# Threat environment mapping
class ThreatEnvironment:
	var threat_zones: Dictionary = {}  # zone_id -> ThreatZone
	var safe_zones: Dictionary = {}    # zone_id -> SafeZone
	var contested_zones: Dictionary = {} # zone_id -> ContestedZone
	var escape_vectors: Array[Vector3] = []
	var choke_points: Array[Vector3] = []
	var tactical_landmarks: Array[Vector3] = []
	var environment_confidence: float = 0.0
	
	func _init():
		environment_confidence = 0.5

class ThreatZone:
	var zone_id: String
	var center_position: Vector3
	var radius: float
	var threat_level: float
	var threat_sources: Array[Node] = []
	var zone_type: String  # high_threat, moderate_threat, missile_zone, beam_zone
	var movement_restriction: float = 0.0  # 0.0 = free movement, 1.0 = no-go zone
	
	func _init(id: String, center: Vector3, r: float):
		zone_id = id
		center_position = center
		radius = r

class SafeZone:
	var zone_id: String
	var center_position: Vector3
	var radius: float
	var safety_level: float
	var zone_type: String  # cover, long_range, stealth, friendly_support
	var temporary: bool = false
	var expiry_time: float = -1.0
	
	func _init(id: String, center: Vector3, r: float):
		zone_id = id
		center_position = center
		radius = r
		safety_level = 0.8

class ContestedZone:
	var zone_id: String
	var center_position: Vector3
	var radius: float
	var control_balance: float = 0.0  # -1.0 (enemy controlled) to 1.0 (player controlled)
	var strategic_value: float = 0.0
	var zone_type: String  # objective, choke_point, high_ground, resource
	
	func _init(id: String, center: Vector3, r: float):
		zone_id = id
		center_position = center
		radius = r

# Engagement opportunity assessment
class EngagementOpportunity:
	var opportunity_id: String
	var opportunity_type: String  # flanking, concentrated_fire, vulnerable_target, formation_break
	var target_signatures: Array[String] = []
	var success_probability: float = 0.0
	var tactical_value: float = 0.0
	var time_window: float = 0.0
	var required_actions: Array[String] = []
	var risk_level: float = 0.0
	var positioning_requirements: Vector3 = Vector3.ZERO
	var weapon_requirements: Array[String] = []
	
	func _init(id: String, type: String):
		opportunity_id = id
		opportunity_type = type

# Defensive recommendation system
class DefensiveRecommendation:
	var recommendation_id: String
	var recommendation_type: String  # evasive, defensive_position, retreat, cover_seeking
	var urgency: int = 1  # 1-5 scale
	var threat_sources: Array[String] = []
	var recommended_position: Vector3 = Vector3.ZERO
	var recommended_heading: float = 0.0
	var time_to_execute: float = 0.0
	var success_probability: float = 0.0
	var alternative_options: Array[Dictionary] = []
	
	func _init(id: String, type: String):
		recommendation_id = id
		recommendation_type = type

# Formation assessment
class FormationAssessment:
	var formation_id: String
	var formation_type: String  # enemy_formation, friendly_formation, mixed_formation
	var participants: Array[String] = []  # Target signatures
	var formation_strength: float = 0.0
	var formation_weakness: float = 0.0
	var recommended_counter: String = ""
	var break_up_probability: float = 0.0
	var formation_center: Vector3 = Vector3.ZERO
	var formation_size: float = 0.0
	
	func _init(id: String, type: String):
		formation_id = id
		formation_type = type

# Core tactical analyzer
class SATacticalAnalyzer:
	var analysis_algorithms: Dictionary = {}
	
	func _init():
		_initialize_analysis_algorithms()
	
	func analyze_tactical_situation(track_data: Array[Dictionary]) -> TacticalSituation:
		var situation = TacticalSituation.new()
		
		# Analyze overall threat level
		situation.overall_threat_level = _calculate_overall_threat(track_data)
		
		# Determine tactical advantage
		situation.tactical_advantage = _calculate_tactical_advantage(track_data)
		
		# Classify situation type
		situation.situation_type = _classify_situation_type(situation)
		
		# Identify primary threats
		situation.primary_threats = _identify_primary_threats(track_data)
		
		# Find available opportunities
		situation.available_opportunities = _identify_opportunities(track_data)
		
		# Generate recommendations
		situation.recommended_actions = _generate_action_recommendations(situation)
		
		# Calculate confidence
		situation.confidence = _calculate_situation_confidence(track_data)
		
		# Analyze tactical factors
		situation.situational_factors = _analyze_situational_factors(track_data)
		
		# Find escape routes
		situation.escape_routes = _calculate_escape_routes(track_data)
		
		return situation
	
	func _calculate_overall_threat(track_data: Array[Dictionary]) -> float:
		var total_threat = 0.0
		var threat_count = 0
		
		for track in track_data:
			var threat_level = track.get("threat_level", 0.0)
			var distance = track.get("distance", 10000.0)
			var relationship = track.get("relationship", "unknown")
			
			if relationship == "hostile":
				# Weight threat by proximity
				var proximity_factor = 1.0 - clamp(distance / 10000.0, 0.0, 1.0)
				var weighted_threat = threat_level * (0.7 + 0.3 * proximity_factor)
				total_threat += weighted_threat
				threat_count += 1
		
		return total_threat / max(1, threat_count) if threat_count > 0 else 0.0
	
	func _calculate_tactical_advantage(track_data: Array[Dictionary]) -> float:
		var player_advantages = 0.0
		var enemy_advantages = 0.0
		
		var friendly_count = 0
		var hostile_count = 0
		var player_position = _get_player_position()
		
		for track in track_data:
			var relationship = track.get("relationship", "unknown")
			var distance = track.get("distance", 10000.0)
			var target_type = track.get("target_type", "unknown")
			
			if relationship == "friendly":
				friendly_count += 1
				# Nearby friendlies provide advantage
				if distance < 5000.0:
					player_advantages += 0.3
			elif relationship == "hostile":
				hostile_count += 1
				# Analyze tactical position relative to hostiles
				var position = track.get("position", Vector3.ZERO)
				var tactical_position = _analyze_tactical_position(player_position, position)
				if tactical_position > 0:
					player_advantages += tactical_position * 0.2
				else:
					enemy_advantages += abs(tactical_position) * 0.2
		
		# Factor in numerical advantage/disadvantage
		if friendly_count > 0 and hostile_count > 0:
			var numerical_ratio = float(friendly_count + 1) / float(hostile_count)  # +1 for player
			if numerical_ratio > 1.0:
				player_advantages += (numerical_ratio - 1.0) * 0.4
			else:
				enemy_advantages += (1.0 / numerical_ratio - 1.0) * 0.4
		
		# Return advantage score (-1.0 to 1.0)
		var net_advantage = player_advantages - enemy_advantages
		return clamp(net_advantage, -1.0, 1.0)
	
	func _classify_situation_type(situation: TacticalSituation) -> String:
		var threat = situation.overall_threat_level
		var advantage = situation.tactical_advantage
		
		if threat > 0.8 or advantage < -0.6:
			return "critical"
		elif threat > 0.6 or advantage < -0.3:
			return "defensive"
		elif advantage > 0.3:
			return "offensive"
		else:
			return "neutral"
	
	func _identify_primary_threats(track_data: Array[Dictionary]) -> Array[Dictionary]:
		var threats: Array[Dictionary] = []
		
		for track in track_data:
			var threat_level = track.get("threat_level", 0.0)
			var relationship = track.get("relationship", "unknown")
			
			if relationship == "hostile" and threat_level > 0.5:
				threats.append({
					"track_id": track.get("track_id", -1),
					"threat_level": threat_level,
					"distance": track.get("distance", 10000.0),
					"target_type": track.get("target_type", "unknown"),
					"immediate_threats": track.get("immediate_threats", [])
				})
		
		# Sort by threat level
		threats.sort_custom(func(a, b): return a.threat_level > b.threat_level)
		
		# Return top 5 threats
		return threats.slice(0, min(5, threats.size()))
	
	func _identify_opportunities(track_data: Array[Dictionary]) -> Array[Dictionary]:
		var opportunities: Array[Dictionary] = []
		
		# Look for vulnerable targets
		for track in track_data:
			var relationship = track.get("relationship", "unknown")
			if relationship != "hostile":
				continue
			
			var vulnerability = _assess_target_vulnerability(track)
			if vulnerability > 0.6:
				opportunities.append({
					"type": "vulnerable_target",
					"track_id": track.get("track_id", -1),
					"vulnerability": vulnerability,
					"estimated_success": vulnerability * 0.8
				})
		
		# Look for tactical positioning opportunities
		var positioning_opportunities = _identify_positioning_opportunities(track_data)
		opportunities.append_array(positioning_opportunities)
		
		return opportunities
	
	func _assess_target_vulnerability(track: Dictionary) -> float:
		var vulnerability = 0.0
		
		# Check for damage indicators
		if track.has("hull_percentage"):
			vulnerability += (1.0 - track.hull_percentage) * 0.4
		
		if track.has("shield_percentage"):
			vulnerability += (1.0 - track.shield_percentage) * 0.3
		
		# Check for isolation
		var distance = track.get("distance", 10000.0)
		if distance < 2000.0:  # Close range
			vulnerability += 0.2
		
		# Check for disabled systems
		if track.has("disabled_subsystems"):
			vulnerability += track.disabled_subsystems.size() * 0.1
		
		return clamp(vulnerability, 0.0, 1.0)
	
	func _identify_positioning_opportunities(track_data: Array[Dictionary]) -> Array[Dictionary]:
		var opportunities: Array[Dictionary] = []
		
		# Look for flanking opportunities
		var flanking_opportunity = _analyze_flanking_potential(track_data)
		if flanking_opportunity.success_probability > 0.6:
			opportunities.append({
				"type": "flanking",
				"success_probability": flanking_opportunity.success_probability,
				"tactical_value": flanking_opportunity.tactical_value
			})
		
		return opportunities
	
	func _analyze_flanking_potential(track_data: Array[Dictionary]) -> Dictionary:
		# Simplified flanking analysis
		return {
			"success_probability": 0.5,
			"tactical_value": 0.6
		}
	
	func _generate_action_recommendations(situation: TacticalSituation) -> Array[String]:
		var recommendations: Array[String] = []
		
		match situation.situation_type:
			"critical":
				recommendations.append("Execute immediate evasive maneuvers")
				recommendations.append("Seek cover or concealment")
				recommendations.append("Consider tactical withdrawal")
			"defensive":
				recommendations.append("Maintain defensive posture")
				recommendations.append("Prioritize high-threat targets")
				recommendations.append("Coordinate with friendly forces")
			"offensive":
				recommendations.append("Engage priority targets")
				recommendations.append("Exploit tactical opportunities")
				recommendations.append("Maintain aggressive posture")
			"neutral":
				recommendations.append("Maintain situational awareness")
				recommendations.append("Prepare for engagement")
				recommendations.append("Monitor threat development")
		
		return recommendations
	
	func _calculate_situation_confidence(track_data: Array[Dictionary]) -> float:
		var confidence = 0.5  # Base confidence
		
		# Increase confidence with more data
		confidence += min(0.3, track_data.size() / 20.0)
		
		# Increase confidence with track quality
		var total_quality = 0.0
		for track in track_data:
			total_quality += track.get("quality", 0.5)
		
		if track_data.size() > 0:
			var avg_quality = total_quality / track_data.size()
			confidence += avg_quality * 0.2
		
		return clamp(confidence, 0.0, 1.0)
	
	func _analyze_situational_factors(track_data: Array[Dictionary]) -> Dictionary:
		return {
			"target_count": track_data.size(),
			"hostile_count": _count_hostiles(track_data),
			"friendly_count": _count_friendlies(track_data),
			"average_distance": _calculate_average_distance(track_data),
			"threat_concentration": _calculate_threat_concentration(track_data)
		}
	
	func _calculate_escape_routes(track_data: Array[Dictionary]) -> Array[Vector3]:
		var escape_routes: Array[Vector3] = []
		var player_position = _get_player_position()
		
		# Analyze threat positions to find safe directions
		var threat_positions: Array[Vector3] = []
		for track in track_data:
			if track.get("relationship", "unknown") == "hostile":
				threat_positions.append(track.get("position", Vector3.ZERO))
		
		# Generate potential escape vectors
		var candidate_directions = [
			Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT,
			Vector3.UP, Vector3.DOWN
		]
		
		for direction in candidate_directions:
			var escape_vector = player_position + direction * 5000.0
			if _is_escape_route_safe(escape_vector, threat_positions):
				escape_routes.append(escape_vector)
		
		return escape_routes
	
	func _is_escape_route_safe(escape_vector: Vector3, threat_positions: Array[Vector3]) -> bool:
		var player_position = _get_player_position()
		var escape_direction = (escape_vector - player_position).normalized()
		
		# Check if escape route leads away from threats
		for threat_pos in threat_positions:
			var to_threat = (threat_pos - player_position).normalized()
			var dot_product = escape_direction.dot(to_threat)
			
			if dot_product > 0.3:  # Heading toward threat
				return false
		
		return true
	
	func _analyze_tactical_position(player_pos: Vector3, target_pos: Vector3) -> float:
		# Simplified tactical position analysis
		# In a real implementation, this would consider:
		# - Relative positioning advantages
		# - Cover and concealment
		# - Weapon engagement angles
		# - Escape route availability
		return 0.0
	
	func _count_hostiles(track_data: Array[Dictionary]) -> int:
		var count = 0
		for track in track_data:
			if track.get("relationship", "unknown") == "hostile":
				count += 1
		return count
	
	func _count_friendlies(track_data: Array[Dictionary]) -> int:
		var count = 0
		for track in track_data:
			if track.get("relationship", "unknown") == "friendly":
				count += 1
		return count
	
	func _calculate_average_distance(track_data: Array[Dictionary]) -> float:
		var total_distance = 0.0
		for track in track_data:
			total_distance += track.get("distance", 10000.0)
		return total_distance / max(1, track_data.size())
	
	func _calculate_threat_concentration(track_data: Array[Dictionary]) -> float:
		# Calculate how concentrated threats are
		var hostile_positions: Array[Vector3] = []
		for track in track_data:
			if track.get("relationship", "unknown") == "hostile":
				hostile_positions.append(track.get("position", Vector3.ZERO))
		
		if hostile_positions.size() < 2:
			return 0.0
		
		# Calculate spread of hostile positions
		var center = Vector3.ZERO
		for pos in hostile_positions:
			center += pos
		center /= hostile_positions.size()
		
		var total_distance = 0.0
		for pos in hostile_positions:
			total_distance += center.distance_to(pos)
		
		var average_spread = total_distance / hostile_positions.size()
		return 1.0 - clamp(average_spread / 5000.0, 0.0, 1.0)  # Higher concentration = lower spread
	
	func _initialize_analysis_algorithms() -> void:
		analysis_algorithms = {
			"threat_assessment": {
				"proximity_weight": 0.4,
				"capability_weight": 0.3,
				"intent_weight": 0.3
			},
			"opportunity_detection": {
				"vulnerability_threshold": 0.6,
				"positioning_threshold": 0.7,
				"timing_threshold": 0.5
			},
			"formation_analysis": {
				"coordination_threshold": 0.8,
				"formation_strength_factor": 1.2,
				"break_up_prediction_accuracy": 0.7
			}
		}

# Threat environment mapper
class ThreatEnvironmentMapper:
	func map_threat_environment(track_data: Array[Dictionary]) -> ThreatEnvironment:
		var environment = ThreatEnvironment.new()
		
		# Create threat zones around hostile contacts
		environment.threat_zones = _create_threat_zones(track_data)
		
		# Identify safe zones
		environment.safe_zones = _identify_safe_zones(track_data)
		
		# Map contested areas
		environment.contested_zones = _map_contested_zones(track_data)
		
		# Calculate escape vectors
		environment.escape_vectors = _calculate_escape_vectors(track_data)
		
		# Identify choke points
		environment.choke_points = _identify_choke_points(track_data)
		
		# Calculate confidence
		environment.environment_confidence = _calculate_environment_confidence(track_data)
		
		return environment
	
	func _create_threat_zones(track_data: Array[Dictionary]) -> Dictionary:
		var threat_zones: Dictionary = {}
		var zone_counter = 0
		
		for track in track_data:
			if track.get("relationship", "unknown") != "hostile":
				continue
			
			var position = track.get("position", Vector3.ZERO)
			var threat_level = track.get("threat_level", 0.0)
			var target_type = track.get("target_type", "unknown")
			
			# Calculate threat zone radius based on target type and threat level
			var base_radius = _get_base_threat_radius(target_type)
			var threat_radius = base_radius * (0.5 + threat_level * 0.5)
			
			zone_counter += 1
			var zone_id = "threat_zone_" + str(zone_counter)
			var threat_zone = ThreatZone.new(zone_id, position, threat_radius)
			threat_zone.threat_level = threat_level
			threat_zone.threat_sources = [track.get("track_id", -1)]
			threat_zone.zone_type = _classify_threat_zone_type(target_type, threat_level)
			
			threat_zones[zone_id] = threat_zone
		
		return threat_zones
	
	func _identify_safe_zones(track_data: Array[Dictionary]) -> Dictionary:
		var safe_zones: Dictionary = {}
		var player_position = _get_player_position()
		
		# Look for areas with friendly presence
		for track in track_data:
			if track.get("relationship", "unknown") != "friendly":
				continue
			
			var position = track.get("position", Vector3.ZERO)
			var distance_to_player = player_position.distance_to(position)
			
			if distance_to_player < 3000.0:  # Nearby friendly
				var zone_id = "safe_zone_friendly_" + str(track.get("track_id", 0))
				var safe_zone = SafeZone.new(zone_id, position, 2000.0)
				safe_zone.zone_type = "friendly_support"
				safe_zone.safety_level = 0.7
				safe_zones[zone_id] = safe_zone
		
		# Look for areas away from threats
		var low_threat_areas = _find_low_threat_areas(track_data)
		for i in range(low_threat_areas.size()):
			var zone_id = "safe_zone_clear_" + str(i)
			var safe_zone = SafeZone.new(zone_id, low_threat_areas[i], 1500.0)
			safe_zone.zone_type = "clear_area"
			safe_zone.safety_level = 0.6
			safe_zones[zone_id] = safe_zone
		
		return safe_zones
	
	func _map_contested_zones(track_data: Array[Dictionary]) -> Dictionary:
		var contested_zones: Dictionary = {}
		
		# Find areas with both friendly and hostile presence
		var friendly_positions: Array[Vector3] = []
		var hostile_positions: Array[Vector3] = []
		
		for track in track_data:
			var relationship = track.get("relationship", "unknown")
			var position = track.get("position", Vector3.ZERO)
			
			if relationship == "friendly":
				friendly_positions.append(position)
			elif relationship == "hostile":
				hostile_positions.append(position)
		
		# Identify contested areas
		for i in range(hostile_positions.size()):
			var hostile_pos = hostile_positions[i]
			for j in range(friendly_positions.size()):
				var friendly_pos = friendly_positions[j]
				var distance = hostile_pos.distance_to(friendly_pos)
				
				if distance < 4000.0:  # Contested if within 4km
					var contest_center = (hostile_pos + friendly_pos) / 2.0
					var zone_id = "contested_zone_" + str(i) + "_" + str(j)
					var contested_zone = ContestedZone.new(zone_id, contest_center, distance / 2.0)
					contested_zone.strategic_value = 0.6
					contested_zone.zone_type = "engagement_zone"
					contested_zones[zone_id] = contested_zone
		
		return contested_zones
	
	func _calculate_escape_vectors(track_data: Array[Dictionary]) -> Array[Vector3]:
		var escape_vectors: Array[Vector3] = []
		var player_position = _get_player_position()
		
		# Calculate vectors leading away from threat concentrations
		var threat_center = _calculate_threat_center_of_mass(track_data)
		if threat_center != Vector3.ZERO:
			var escape_direction = (player_position - threat_center).normalized()
			escape_vectors.append(player_position + escape_direction * 10000.0)
		
		return escape_vectors
	
	func _identify_choke_points(track_data: Array[Dictionary]) -> Array[Vector3]:
		var choke_points: Array[Vector3] = []
		
		# Identify areas where movement is restricted by threat coverage
		# This is a simplified implementation
		return choke_points
	
	func _calculate_environment_confidence(track_data: Array[Dictionary]) -> float:
		var confidence = 0.5
		
		# Increase confidence with more track data
		confidence += min(0.4, track_data.size() / 15.0)
		
		# Increase confidence with track quality
		var avg_quality = 0.0
		for track in track_data:
			avg_quality += track.get("quality", 0.5)
		
		if track_data.size() > 0:
			avg_quality /= track_data.size()
			confidence += avg_quality * 0.1
		
		return clamp(confidence, 0.0, 1.0)
	
	func _get_base_threat_radius(target_type: String) -> float:
		match target_type:
			"missile", "torpedo":
				return 500.0
			"fighter", "bomber":
				return 1000.0
			"corvette", "frigate":
				return 2000.0
			"destroyer", "cruiser":
				return 3000.0
			"capital", "dreadnought":
				return 5000.0
			_:
				return 1500.0
	
	func _classify_threat_zone_type(target_type: String, threat_level: float) -> String:
		if target_type in ["missile", "torpedo"]:
			return "missile_zone"
		elif target_type in ["capital", "cruiser"] and threat_level > 0.6:
			return "beam_zone"
		elif threat_level > 0.8:
			return "high_threat"
		else:
			return "moderate_threat"
	
	func _find_low_threat_areas(track_data: Array[Dictionary]) -> Array[Vector3]:
		var low_threat_areas: Array[Vector3] = []
		var player_position = _get_player_position()
		
		# Generate candidate positions in a grid around player
		var search_radius = 8000.0
		var grid_size = 4
		
		for x in range(-grid_size, grid_size + 1):
			for z in range(-grid_size, grid_size + 1):
				var candidate_pos = player_position + Vector3(
					x * search_radius / grid_size,
					0,
					z * search_radius / grid_size
				)
				
				var threat_at_position = _calculate_threat_at_position(candidate_pos, track_data)
				if threat_at_position < 0.3:
					low_threat_areas.append(candidate_pos)
		
		return low_threat_areas
	
	func _calculate_threat_at_position(position: Vector3, track_data: Array[Dictionary]) -> float:
		var total_threat = 0.0
		
		for track in track_data:
			if track.get("relationship", "unknown") != "hostile":
				continue
			
			var threat_pos = track.get("position", Vector3.ZERO)
			var threat_level = track.get("threat_level", 0.0)
			var distance = position.distance_to(threat_pos)
			
			# Threat decreases with distance
			var distance_factor = 1.0 - clamp(distance / 5000.0, 0.0, 1.0)
			total_threat += threat_level * distance_factor
		
		return total_threat
	
	func _calculate_threat_center_of_mass(track_data: Array[Dictionary]) -> Vector3:
		var center = Vector3.ZERO
		var threat_count = 0
		
		for track in track_data:
			if track.get("relationship", "unknown") == "hostile":
				center += track.get("position", Vector3.ZERO)
				threat_count += 1
		
		return center / max(1, threat_count) if threat_count > 0 else Vector3.ZERO

# Remaining component stubs for brevity
class SAEngagementCalculator:
	func calculate_engagement_opportunities(track_data: Array[Dictionary]) -> Array[EngagementOpportunity]:
		return []

class DefensiveAdvisor:
	func generate_defensive_recommendations(situation: TacticalSituation) -> Array[DefensiveRecommendation]:
		return []

class FormationAnalyzer:
	func analyze_formations(track_data: Array[Dictionary]) -> Array[FormationAssessment]:
		return []

class PredictiveEngine:
	func predict_situation_evolution(current_situation: TacticalSituation, prediction_time: float) -> TacticalSituation:
		return current_situation

func _ready() -> void:
	_initialize_situational_awareness()

## Get player position
func _get_player_position() -> Vector3:
	"""Get current player ship position."""
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		return player_nodes[0].global_position
	return Vector3.ZERO

func _initialize_situational_awareness() -> void:
	print("SituationalAwareness: Initializing situational awareness system...")
	
	# Create component instances
	tactical_analyzer = SATacticalAnalyzer.new()
	threat_environment_mapper = ThreatEnvironmentMapper.new()
	engagement_calculator = SAEngagementCalculator.new()
	defensive_advisor = DefensiveAdvisor.new()
	formation_analyzer = FormationAnalyzer.new()
	predictive_engine = PredictiveEngine.new()
	
	# Initialize current situation
	current_situation = TacticalSituation.new()
	threat_environment = ThreatEnvironment.new()
	
	# Setup analysis timer
	var analysis_timer = Timer.new()
	analysis_timer.wait_time = 1.0 / tactical_analysis_frequency
	analysis_timer.timeout.connect(_on_tactical_analysis_timer)
	analysis_timer.autostart = true
	add_child(analysis_timer)
	
	print("SituationalAwareness: Situational awareness system initialized")

## Set prediction time
func set_prediction_time(time: float) -> void:
	prediction_time = time

## Update situational analysis
func update_situational_analysis(track_data: Array[Dictionary]) -> void:
	# Analyze current tactical situation
	var new_situation = tactical_analyzer.analyze_tactical_situation(track_data)
	
	# Check for situation changes
	if _situation_changed_significantly(current_situation, new_situation):
		var old_type = current_situation.situation_type
		current_situation = new_situation
		
		# Add to history
		situation_history.append(current_situation)
		if situation_history.size() > 50:
			situation_history.pop_front()
		
		# Emit situation change signal
		tactical_situation_changed.emit(new_situation.situation_type, _calculate_urgency(new_situation))
	
	# Update threat environment
	threat_environment = threat_environment_mapper.map_threat_environment(track_data)
	threat_environment_updated.emit(_threat_environment_to_dictionary(threat_environment))
	
	# Analyze engagement opportunities
	engagement_opportunities = engagement_calculator.calculate_engagement_opportunities(track_data)
	for opportunity in engagement_opportunities:
		if opportunity.success_probability >= engagement_opportunity_threshold:
			engagement_opportunity_detected.emit(_engagement_opportunity_to_dictionary(opportunity))
	
	# Generate defensive recommendations
	defensive_recommendations = defensive_advisor.generate_defensive_recommendations(current_situation)
	for recommendation in defensive_recommendations:
		if recommendation.urgency >= 3:  # High urgency
			defensive_alert_raised.emit(recommendation.urgency, recommendation.recommendation_type)
	
	# Analyze formations if enabled
	if formation_analysis_enabled:
		formation_assessments = formation_analyzer.analyze_formations(track_data)
		for assessment in formation_assessments:
			formation_analysis_completed.emit(_formation_assessment_to_dictionary(assessment))

## Get current tactical situation
func get_current_situation() -> Dictionary:
	return _tactical_situation_to_dictionary(current_situation)

## Get threat environment
func get_threat_environment() -> Dictionary:
	return _threat_environment_to_dictionary(threat_environment)

## Get engagement opportunities
func get_engagement_opportunities() -> Array[Dictionary]:
	var opportunities: Array[Dictionary] = []
	for opportunity in engagement_opportunities:
		opportunities.append(_engagement_opportunity_to_dictionary(opportunity))
	return opportunities

## Get defensive recommendations
func get_defensive_recommendations() -> Array[Dictionary]:
	var recommendations: Array[Dictionary] = []
	for recommendation in defensive_recommendations:
		recommendations.append(_defensive_recommendation_to_dictionary(recommendation))
	return recommendations

## Get tactical recommendations
func get_tactical_recommendations() -> Array[String]:
	return current_situation.recommended_actions.duplicate()

## Timer callback
func _on_tactical_analysis_timer() -> void:
	# This timer just marks when analysis should occur
	# The actual analysis is triggered by update_situational_analysis()
	pass

## Utility functions

func _situation_changed_significantly(old_situation: TacticalSituation, new_situation: TacticalSituation) -> bool:
	if old_situation.situation_type != new_situation.situation_type:
		return true
	
	var threat_change = abs(old_situation.overall_threat_level - new_situation.overall_threat_level)
	if threat_change > 0.2:
		return true
	
	var advantage_change = abs(old_situation.tactical_advantage - new_situation.tactical_advantage)
	if advantage_change > 0.3:
		return true
	
	return false

func _calculate_urgency(situation: TacticalSituation) -> int:
	match situation.situation_type:
		"critical":
			return 5
		"defensive":
			return 3
		"offensive":
			return 2
		_:
			return 1

func _tactical_situation_to_dictionary(situation: TacticalSituation) -> Dictionary:
	return {
		"timestamp": situation.timestamp,
		"overall_threat_level": situation.overall_threat_level,
		"tactical_advantage": situation.tactical_advantage,
		"situation_type": situation.situation_type,
		"confidence": situation.confidence,
		"primary_threats": situation.primary_threats,
		"available_opportunities": situation.available_opportunities,
		"recommended_actions": situation.recommended_actions,
		"situational_factors": situation.situational_factors,
		"escape_routes": situation.escape_routes
	}

func _threat_environment_to_dictionary(environment: ThreatEnvironment) -> Dictionary:
	return {
		"threat_zones": environment.threat_zones.size(),
		"safe_zones": environment.safe_zones.size(),
		"contested_zones": environment.contested_zones.size(),
		"escape_vectors": environment.escape_vectors,
		"environment_confidence": environment.environment_confidence
	}

func _engagement_opportunity_to_dictionary(opportunity: EngagementOpportunity) -> Dictionary:
	return {
		"opportunity_id": opportunity.opportunity_id,
		"opportunity_type": opportunity.opportunity_type,
		"success_probability": opportunity.success_probability,
		"tactical_value": opportunity.tactical_value,
		"time_window": opportunity.time_window,
		"risk_level": opportunity.risk_level
	}

func _defensive_recommendation_to_dictionary(recommendation: DefensiveRecommendation) -> Dictionary:
	return {
		"recommendation_id": recommendation.recommendation_id,
		"recommendation_type": recommendation.recommendation_type,
		"urgency": recommendation.urgency,
		"recommended_position": recommendation.recommended_position,
		"success_probability": recommendation.success_probability
	}

func _formation_assessment_to_dictionary(assessment: FormationAssessment) -> Dictionary:
	return {
		"formation_id": assessment.formation_id,
		"formation_type": assessment.formation_type,
		"participants": assessment.participants,
		"formation_strength": assessment.formation_strength,
		"recommended_counter": assessment.recommended_counter
	}

func _get_player_position() -> Vector3:
	var player_ship = _get_player_ship()
	return player_ship.global_position if player_ship else Vector3.ZERO

func _get_player_ship() -> Node:
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	return player_ships[0] if not player_ships.is_empty() else null

## Status and debugging

## Get situational awareness status
func get_situational_awareness_status() -> Dictionary:
	return {
		"prediction_time": prediction_time,
		"analysis_frequency": tactical_analysis_frequency,
		"engagement_threshold": engagement_opportunity_threshold,
		"defensive_threshold": defensive_alert_threshold,
		"formation_analysis_enabled": formation_analysis_enabled,
		"current_situation_type": current_situation.situation_type,
		"threat_level": current_situation.overall_threat_level,
		"tactical_advantage": current_situation.tactical_advantage,
		"situation_confidence": current_situation.confidence
	}