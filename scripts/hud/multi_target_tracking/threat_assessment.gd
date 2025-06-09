class_name ThreatAssessment
extends Node

## HUD-008 Component 4: Real-Time Threat Level Evaluation System
## Advanced threat analysis engine that evaluates multiple threat factors in real-time
## Provides dynamic threat assessment for tactical decision making and target prioritization

signal threat_level_changed(target: Node, threat_level: float)
signal new_threat_detected(target: Node, threat_data: Dictionary)
signal critical_threat_alert(target: Node, threat_level: float, threat_type: String)
signal threat_eliminated(target: Node, reason: String)
signal threat_pattern_detected(pattern_type: String, involved_targets: Array[Node])

# Threat assessment parameters
@export var real_time_assessment_enabled: bool = true
@export var assessment_frequency: float = 20.0  # 20Hz threat assessment
@export var critical_threat_threshold: float = 0.85
@export var high_threat_threshold: float = 0.65
@export var threat_decay_rate: float = 0.1  # Threat decay per second when not engaged

# Threat analysis components
var threat_analyzer: ThreatAnalyzer
var weapon_threat_calculator: WeaponThreatCalculator
var tactical_analyzer: TacticalAnalyzer
var behavior_predictor: BehaviorPredictor
var formation_analyzer: FormationAnalyzer

# Current threat assessments
var target_threats: Dictionary = {}  # target -> ThreatData
var threat_history: Dictionary = {}  # target -> Array[ThreatSnapshot]
var active_threat_patterns: Array[ThreatPattern] = []

# Threat weighting factors
var threat_weights: Dictionary = {
	"proximity": 0.25,        # Distance-based threat
	"weapon_capability": 0.30, # Weapon systems threat
	"maneuverability": 0.15,  # Target agility and speed
	"target_behavior": 0.20,  # Aggressive/defensive behavior
	"formation_support": 0.10  # Support from other units
}

# Threat categories and multipliers
var threat_categories: Dictionary = {
	"missile_incoming": 3.0,    # Incoming missiles - highest threat
	"beam_lock": 2.5,           # Beam weapon lock
	"torpedo_lock": 2.8,        # Torpedo lock
	"gun_tracking": 1.8,        # Gun systems tracking
	"ramming_course": 2.2,      # Collision course
	"flanking_maneuver": 1.5,   # Tactical positioning
	"formation_attack": 1.7,    # Coordinated attack
	"stealth_approach": 1.3,    # Stealth threat
	"reinforcement": 1.2,       # Additional forces
	"ambush_position": 2.0      # Ambush threat
}

# Threat data structure
class ThreatData:
	var target_node: Node
	var overall_threat: float = 0.0
	var proximity_threat: float = 0.0
	var weapon_threat: float = 0.0
	var maneuver_threat: float = 0.0
	var behavior_threat: float = 0.0
	var formation_threat: float = 0.0
	var immediate_threats: Array[String] = []
	var threat_vector: Vector3 = Vector3.ZERO
	var time_to_impact: float = -1.0
	var confidence: float = 0.0
	var last_updated: float = 0.0
	var threat_trend: float = 0.0  # Positive = increasing threat
	
	func _init(target: Node):
		target_node = target
		last_updated = Time.get_ticks_usec() / 1000000.0

# Threat pattern detection
class ThreatPattern:
	var pattern_type: String
	var involved_targets: Array[Node] = []
	var pattern_confidence: float = 0.0
	var detected_time: float = 0.0
	var expiry_time: float = 0.0
	
	func _init(type: String, targets: Array[Node]):
		pattern_type = type
		involved_targets = targets
		detected_time = Time.get_ticks_usec() / 1000000.0
		expiry_time = detected_time + 30.0  # 30 second expiry

# Core threat analysis engine
class ThreatAnalyzer:
	var threat_models: Dictionary = {}
	
	func _init():
		_load_threat_models()
	
	func analyze_threat(target: Node, track_data: Dictionary) -> ThreatData:
		var threat_data = ThreatData.new(target)
		
		# Analyze different threat components
		threat_data.proximity_threat = _analyze_proximity_threat(target, track_data)
		threat_data.weapon_threat = _analyze_weapon_threat(target, track_data)
		threat_data.maneuver_threat = _analyze_maneuver_threat(target, track_data)
		threat_data.behavior_threat = _analyze_behavior_threat(target, track_data)
		threat_data.formation_threat = _analyze_formation_threat(target, track_data)
		
		# Calculate overall threat
		threat_data.overall_threat = _calculate_overall_threat(threat_data)
		
		# Determine immediate threats
		threat_data.immediate_threats = _identify_immediate_threats(target, track_data)
		
		# Calculate threat vector and time to impact
		threat_data.threat_vector = _calculate_threat_vector(target, track_data)
		threat_data.time_to_impact = _calculate_time_to_impact(target, track_data)
		
		# Calculate confidence
		threat_data.confidence = _calculate_threat_confidence(target, track_data)
		
		return threat_data
	
	func _analyze_proximity_threat(target: Node, track_data: Dictionary) -> float:
		var distance = track_data.get("distance", 10000.0)
		var max_threat_distance = 2000.0  # Distance for maximum proximity threat
		
		# Exponential threat increase as distance decreases
		var proximity_factor = 1.0 - clamp(distance / max_threat_distance, 0.0, 1.0)
		return pow(proximity_factor, 2.0)  # Quadratic increase
	
	func _analyze_weapon_threat(target: Node, track_data: Dictionary) -> float:
		var weapon_threat = 0.0
		
		# Check for weapon locks and targeting
		if track_data.has("weapon_locks"):
			var locks = track_data.weapon_locks
			if locks.has("missile_lock") and locks.missile_lock:
				weapon_threat += 0.9
			if locks.has("beam_lock") and locks.beam_lock:
				weapon_threat += 0.8
			if locks.has("gun_tracking") and locks.gun_tracking:
				weapon_threat += 0.6
		
		# Check target type weapon capability
		var target_type = track_data.get("target_type", "unknown")
		match target_type:
			"bomber":
				weapon_threat += 0.7
			"fighter":
				weapon_threat += 0.5
			"capital":
				weapon_threat += 0.8
			"missile":
				weapon_threat += 1.0  # Missiles are pure weapon threat
		
		return clamp(weapon_threat, 0.0, 1.0)
	
	func _analyze_maneuver_threat(target: Node, track_data: Dictionary) -> float:
		var velocity = track_data.get("velocity", Vector3.ZERO)
		var speed = velocity.length()
		var max_threat_speed = 600.0  # Speed for maximum maneuver threat
		
		# Fast targets are more threatening due to unpredictability
		var speed_factor = clamp(speed / max_threat_speed, 0.0, 1.0)
		
		# Check for erratic movement
		var maneuver_factor = 0.0
		if track_data.has("acceleration"):
			var acceleration = track_data.acceleration as Vector3
			var acceleration_magnitude = acceleration.length()
			maneuver_factor = clamp(acceleration_magnitude / 100.0, 0.0, 0.5)
		
		return speed_factor + maneuver_factor
	
	func _analyze_behavior_threat(target: Node, track_data: Dictionary) -> float:
		var behavior_threat = 0.0
		
		# Check heading toward player
		var player_position = _get_player_position()
		var target_position = track_data.get("position", Vector3.ZERO)
		var target_velocity = track_data.get("velocity", Vector3.ZERO)
		
		if target_velocity.length() > 10.0:  # Only analyze if target is moving
			var to_player = (player_position - target_position).normalized()
			var velocity_normalized = target_velocity.normalized()
			var heading_dot = velocity_normalized.dot(to_player)
			
			if heading_dot > 0.7:  # Heading toward player
				behavior_threat += 0.8
			elif heading_dot > 0.3:  # Somewhat toward player
				behavior_threat += 0.4
		
		# Check for aggressive patterns
		if track_data.has("behavior_flags"):
			var flags = track_data.behavior_flags
			if flags.has("aggressive") and flags.aggressive:
				behavior_threat += 0.6
			if flags.has("pursuing") and flags.pursuing:
				behavior_threat += 0.7
			if flags.has("evasive") and flags.evasive:
				behavior_threat -= 0.3  # Evasive is less threatening
		
		return clamp(behavior_threat, 0.0, 1.0)
	
	func _analyze_formation_threat(target: Node, track_data: Dictionary) -> float:
		var formation_threat = 0.0
		
		# Check for nearby allies
		if track_data.has("nearby_allies"):
			var allies = track_data.nearby_allies as Array
			formation_threat = clamp(allies.size() * 0.2, 0.0, 0.8)
		
		# Check for coordinated movement
		if track_data.has("in_formation") and track_data.in_formation:
			formation_threat += 0.3
		
		return formation_threat
	
	func _calculate_overall_threat(threat_data: ThreatData) -> float:
		var weights = get_parent().threat_weights
		
		var overall = 0.0
		overall += threat_data.proximity_threat * weights.proximity
		overall += threat_data.weapon_threat * weights.weapon_capability
		overall += threat_data.maneuver_threat * weights.maneuverability
		overall += threat_data.behavior_threat * weights.target_behavior
		overall += threat_data.formation_threat * weights.formation_support
		
		return clamp(overall, 0.0, 1.0)
	
	func _identify_immediate_threats(target: Node, track_data: Dictionary) -> Array[String]:
		var threats: Array[String] = []
		
		# Check for incoming missiles
		var target_type = track_data.get("target_type", "unknown")
		if target_type == "missile":
			threats.append("missile_incoming")
		
		# Check for weapon locks
		if track_data.has("weapon_locks"):
			var locks = track_data.weapon_locks
			if locks.has("missile_lock") and locks.missile_lock:
				threats.append("missile_lock")
			if locks.has("beam_lock") and locks.beam_lock:
				threats.append("beam_lock")
		
		# Check for collision course
		var time_to_impact = _calculate_time_to_impact(target, track_data)
		if time_to_impact > 0 and time_to_impact < 10.0:
			threats.append("collision_course")
		
		return threats
	
	func _calculate_threat_vector(target: Node, track_data: Dictionary) -> Vector3:
		var player_position = _get_player_position()
		var target_position = track_data.get("position", Vector3.ZERO)
		return (target_position - player_position).normalized()
	
	func _calculate_time_to_impact(target: Node, track_data: Dictionary) -> float:
		var player_position = _get_player_position()
		var target_position = track_data.get("position", Vector3.ZERO)
		var target_velocity = track_data.get("velocity", Vector3.ZERO)
		
		# Calculate intercept time
		var relative_position = target_position - player_position
		var closing_speed = -target_velocity.dot(relative_position.normalized())
		
		if closing_speed > 0:
			return relative_position.length() / closing_speed
		else:
			return -1.0  # Not approaching
	
	func _calculate_threat_confidence(target: Node, track_data: Dictionary) -> float:
		var confidence = 0.5  # Base confidence
		
		# Increase confidence with track quality
		if track_data.has("track_quality"):
			confidence += track_data.track_quality * 0.3
		
		# Increase confidence with signal strength
		if track_data.has("signal_strength"):
			confidence += track_data.signal_strength * 0.2
		
		return clamp(confidence, 0.0, 1.0)
	
	func _load_threat_models() -> void:
		threat_models = {
			"fighter": {
				"base_threat": 0.5,
				"weapon_multiplier": 1.0,
				"speed_multiplier": 1.2
			},
			"bomber": {
				"base_threat": 0.7,
				"weapon_multiplier": 1.5,
				"speed_multiplier": 0.8
			},
			"capital": {
				"base_threat": 0.4,
				"weapon_multiplier": 2.0,
				"speed_multiplier": 0.3
			},
			"missile": {
				"base_threat": 0.9,
				"weapon_multiplier": 3.0,
				"speed_multiplier": 2.0
			}
		}

# Weapon-specific threat calculation
class WeaponThreatCalculator:
	var weapon_threat_values: Dictionary = {}
	
	func _init():
		_initialize_weapon_threats()
	
	func calculate_weapon_threat(target: Node) -> float:
		var threat = 0.0
		
		# This would integrate with weapon systems when available
		# For now, estimate based on target type
		if target.has_method("get_weapon_systems"):
			var weapons = target.get_weapon_systems()
			for weapon in weapons:
				threat += _get_weapon_threat_value(weapon)
		else:
			# Estimate based on target classification
			if target.is_in_group("fighters"):
				threat = 0.6
			elif target.is_in_group("bombers"):
				threat = 0.8
			elif target.is_in_group("capital"):
				threat = 0.9
			elif target.is_in_group("missiles"):
				threat = 1.0
		
		return clamp(threat, 0.0, 1.0)
	
	func _get_weapon_threat_value(weapon: Node) -> float:
		if weapon.has_method("get_weapon_type"):
			var weapon_type = weapon.get_weapon_type()
			return weapon_threat_values.get(weapon_type, 0.5)
		return 0.5
	
	func _initialize_weapon_threats() -> void:
		weapon_threat_values = {
			"laser": 0.6,
			"plasma": 0.7,
			"missile": 0.9,
			"torpedo": 0.95,
			"beam": 0.8,
			"flak": 0.4,
			"ion": 0.5
		}

# Tactical situation analyzer
class TATacticalAnalyzer:
	func analyze_tactical_situation(all_threats: Dictionary) -> Dictionary:
		var analysis = {
			"overall_threat_level": 0.0,
			"primary_threats": [],
			"threat_distribution": {},
			"recommended_action": "maintain_course"
		}
		
		# Calculate overall threat level
		var total_threat = 0.0
		var threat_count = 0
		
		for threat_data in all_threats.values():
			total_threat += threat_data.overall_threat
			threat_count += 1
		
		if threat_count > 0:
			analysis.overall_threat_level = total_threat / threat_count
		
		# Identify primary threats
		var primary_threats: Array[Dictionary] = []
		for target in all_threats.keys():
			var threat_data = all_threats[target]
			if threat_data.overall_threat >= 0.6:
				primary_threats.append({
					"target": target,
					"threat_level": threat_data.overall_threat,
					"immediate_threats": threat_data.immediate_threats
				})
		
		# Sort by threat level
		primary_threats.sort_custom(func(a, b): return a.threat_level > b.threat_level)
		analysis.primary_threats = primary_threats
		
		# Recommend action
		analysis.recommended_action = _recommend_tactical_action(analysis)
		
		return analysis
	
	func _recommend_tactical_action(analysis: Dictionary) -> String:
		var overall_threat = analysis.overall_threat_level
		var primary_count = analysis.primary_threats.size()
		
		if overall_threat > 0.8:
			return "evasive_maneuvers"
		elif overall_threat > 0.6:
			return "defensive_posture"
		elif primary_count > 3:
			return "target_prioritization"
		elif overall_threat > 0.4:
			return "heightened_awareness"
		else:
			return "maintain_course"

# Behavior prediction system
class BehaviorPredictor:
	var behavior_patterns: Dictionary = {}
	
	func predict_target_behavior(target: Node, threat_data: ThreatData) -> Dictionary:
		var prediction = {
			"predicted_action": "unknown",
			"confidence": 0.0,
			"time_horizon": 5.0,
			"predicted_position": Vector3.ZERO
		}
		
		# Analyze movement patterns
		if threat_data.target_node.has_method("get_movement_pattern"):
			var pattern = threat_data.target_node.get_movement_pattern()
			prediction.predicted_action = _predict_from_pattern(pattern)
			prediction.confidence = 0.7
		else:
			# Basic prediction based on current state
			prediction.predicted_action = _predict_basic_behavior(threat_data)
			prediction.confidence = 0.4
		
		return prediction
	
	func _predict_from_pattern(pattern: Dictionary) -> String:
		# Analyze established movement patterns
		return "continue_current"
	
	func _predict_basic_behavior(threat_data: ThreatData) -> String:
		# Basic behavior prediction
		if threat_data.behavior_threat > 0.7:
			return "attack_run"
		elif threat_data.maneuver_threat > 0.6:
			return "evasive_maneuvers"
		else:
			return "patrol"

# Formation analysis system
class FormationAnalyzer:
	func analyze_formation_threats(all_targets: Array[Node]) -> Array[ThreatPattern]:
		var patterns: Array[ThreatPattern] = []
		
		# Detect coordinated attacks
		var coordinated_groups = _detect_coordinated_movement(all_targets)
		for group in coordinated_groups:
			var pattern = ThreatPattern.new("coordinated_attack", group)
			pattern.pattern_confidence = 0.8
			patterns.append(pattern)
		
		# Detect flanking maneuvers
		var flanking_groups = _detect_flanking_maneuvers(all_targets)
		for group in flanking_groups:
			var pattern = ThreatPattern.new("flanking_maneuver", group)
			pattern.pattern_confidence = 0.7
			patterns.append(pattern)
		
		return patterns
	
	func _detect_coordinated_movement(targets: Array[Node]) -> Array[Array]:
		var groups: Array[Array] = []
		# Implementation would analyze target positions and movements
		return groups
	
	func _detect_flanking_maneuvers(targets: Array[Node]) -> Array[Array]:
		var groups: Array[Array] = []
		# Implementation would detect flanking patterns
		return groups

func _ready() -> void:
	_initialize_threat_assessment()

func _initialize_threat_assessment() -> void:
	print("ThreatAssessment: Initializing threat assessment system...")
	
	# Create component instances
	threat_analyzer = ThreatAnalyzer.new()
	weapon_threat_calculator = WeaponThreatCalculator.new()
	tactical_analyzer = TATacticalAnalyzer.new()
	behavior_predictor = BehaviorPredictor.new()
	formation_analyzer = FormationAnalyzer.new()
	
	# Setup assessment timer if real-time assessment is enabled
	if real_time_assessment_enabled:
		var assessment_timer = Timer.new()
		assessment_timer.wait_time = 1.0 / assessment_frequency
		assessment_timer.timeout.connect(_on_assessment_timer)
		assessment_timer.autostart = true
		add_child(assessment_timer)
	
	print("ThreatAssessment: Threat assessment system initialized")

## Enable or disable real-time assessment
func enable_real_time_assessment(enabled: bool) -> void:
	real_time_assessment_enabled = enabled

## Assess threat for a specific target
func assess_target_threat(target: Node, track_data: Dictionary) -> void:
	if not target or not is_instance_valid(target):
		return
	
	# Analyze threat using threat analyzer
	var threat_data = threat_analyzer.analyze_threat(target, track_data)
	
	# Check if threat level changed significantly
	var old_threat_level = 0.0
	if target_threats.has(target):
		old_threat_level = target_threats[target].overall_threat
	
	# Store threat data
	target_threats[target] = threat_data
	
	# Record threat history
	_record_threat_history(target, threat_data)
	
	# Emit signals for significant changes
	if abs(threat_data.overall_threat - old_threat_level) > 0.1:
		threat_level_changed.emit(target, threat_data.overall_threat)
	
	# Check for new threats
	if old_threat_level < high_threat_threshold and threat_data.overall_threat >= high_threat_threshold:
		new_threat_detected.emit(target, _threat_data_to_dictionary(threat_data))
	
	# Check for critical threats
	if threat_data.overall_threat >= critical_threat_threshold:
		var threat_type = _determine_primary_threat_type(threat_data)
		critical_threat_alert.emit(target, threat_data.overall_threat, threat_type)

## Get current threat level for target
func get_target_threat_level(target: Node) -> float:
	if target_threats.has(target):
		return target_threats[target].overall_threat
	return 0.0

## Get detailed threat data for target
func get_target_threat_data(target: Node) -> Dictionary:
	if target_threats.has(target):
		return _threat_data_to_dictionary(target_threats[target])
	return {}

## Get all current threats
func get_all_threats() -> Dictionary:
	var all_threats: Dictionary = {}
	for target in target_threats.keys():
		all_threats[target] = _threat_data_to_dictionary(target_threats[target])
	return all_threats

## Get high-priority threats
func get_high_priority_threats() -> Array[Dictionary]:
	var high_threats: Array[Dictionary] = []
	
	for target in target_threats.keys():
		var threat_data = target_threats[target]
		if threat_data.overall_threat >= high_threat_threshold:
			high_threats.append({
				"target": target,
				"threat_level": threat_data.overall_threat,
				"threat_type": _determine_primary_threat_type(threat_data),
				"time_to_impact": threat_data.time_to_impact,
				"immediate_threats": threat_data.immediate_threats
			})
	
	# Sort by threat level
	high_threats.sort_custom(func(a, b): return a.threat_level > b.threat_level)
	
	return high_threats

## Remove target from threat assessment
func remove_target_threat(target: Node, reason: String = "target_lost") -> void:
	if target_threats.has(target):
		target_threats.erase(target)
		threat_eliminated.emit(target, reason)

## Clear all threat assessments
func clear_all_threats() -> void:
	target_threats.clear()
	threat_history.clear()
	active_threat_patterns.clear()

## Update threat assessment configuration
func update_threat_weights(new_weights: Dictionary) -> void:
	for key in new_weights.keys():
		if threat_weights.has(key):
			threat_weights[key] = new_weights[key]
	
	# Normalize weights
	_normalize_threat_weights()

func _normalize_threat_weights() -> void:
	var total_weight = 0.0
	for weight in threat_weights.values():
		total_weight += weight
	
	if total_weight > 0.0:
		for key in threat_weights.keys():
			threat_weights[key] = threat_weights[key] / total_weight

## Threat assessment timer callback
func _on_assessment_timer() -> void:
	if not real_time_assessment_enabled:
		return
	
	# Perform real-time threat assessment updates
	_update_threat_trends()
	_apply_threat_decay()
	_detect_threat_patterns()
	_perform_tactical_analysis()

func _update_threat_trends() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	for target in target_threats.keys():
		var threat_data = target_threats[target]
		
		# Calculate threat trend from history
		if threat_history.has(target) and threat_history[target].size() >= 2:
			var history = threat_history[target]
			var recent = history[-1]
			var previous = history[-2]
			
			var time_delta = recent.timestamp - previous.timestamp
			if time_delta > 0:
				threat_data.threat_trend = (recent.threat_level - previous.threat_level) / time_delta

func _apply_threat_decay() -> void:
	var current_time = Time.get_ticks_usec() / 1000000.0
	var decay_interval = 1.0 / assessment_frequency
	
	for target in target_threats.keys():
		var threat_data = target_threats[target]
		var time_since_update = current_time - threat_data.last_updated
		
		# Apply decay if not recently updated
		if time_since_update > 1.0:  # 1 second grace period
			var decay_amount = threat_decay_rate * time_since_update
			threat_data.overall_threat = max(0.0, threat_data.overall_threat - decay_amount)

func _detect_threat_patterns() -> void:
	var all_targets: Array[Node] = []
	for target in target_threats.keys():
		all_targets.append(target)
	
	# Analyze formation threats
	var new_patterns = formation_analyzer.analyze_formation_threats(all_targets)
	
	# Add new patterns and remove expired ones
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	# Remove expired patterns
	active_threat_patterns = active_threat_patterns.filter(
		func(pattern): return pattern.expiry_time > current_time
	)
	
	# Add new patterns
	for pattern in new_patterns:
		var is_duplicate = false
		for existing in active_threat_patterns:
			if existing.pattern_type == pattern.pattern_type:
				is_duplicate = true
				break
		
		if not is_duplicate:
			active_threat_patterns.append(pattern)
			threat_pattern_detected.emit(pattern.pattern_type, pattern.involved_targets)

func _perform_tactical_analysis() -> void:
	# Perform overall tactical situation analysis
	var tactical_situation = tactical_analyzer.analyze_tactical_situation(target_threats)
	
	# This could trigger additional signals or recommendations

## Utility functions

func _record_threat_history(target: Node, threat_data: ThreatData) -> void:
	if not threat_history.has(target):
		threat_history[target] = []
	
	var history = threat_history[target]
	var current_time = Time.get_ticks_usec() / 1000000.0
	
	history.append({
		"timestamp": current_time,
		"threat_level": threat_data.overall_threat,
		"immediate_threats": threat_data.immediate_threats.duplicate()
	})
	
	# Keep only recent history (last 100 entries)
	if history.size() > 100:
		history.pop_front()

func _determine_primary_threat_type(threat_data: ThreatData) -> String:
	if not threat_data.immediate_threats.is_empty():
		return threat_data.immediate_threats[0]
	
	# Determine based on threat components
	if threat_data.weapon_threat > 0.7:
		return "weapon_threat"
	elif threat_data.proximity_threat > 0.7:
		return "proximity_threat"
	elif threat_data.maneuver_threat > 0.7:
		return "maneuver_threat"
	else:
		return "general_threat"

func _threat_data_to_dictionary(threat_data: ThreatData) -> Dictionary:
	return {
		"overall_threat": threat_data.overall_threat,
		"proximity_threat": threat_data.proximity_threat,
		"weapon_threat": threat_data.weapon_threat,
		"maneuver_threat": threat_data.maneuver_threat,
		"behavior_threat": threat_data.behavior_threat,
		"formation_threat": threat_data.formation_threat,
		"immediate_threats": threat_data.immediate_threats,
		"threat_vector": threat_data.threat_vector,
		"time_to_impact": threat_data.time_to_impact,
		"confidence": threat_data.confidence,
		"threat_trend": threat_data.threat_trend,
		"last_updated": threat_data.last_updated
	}

func _get_player_position() -> Vector3:
	var player_ship = _get_player_ship()
	return player_ship.global_position if player_ship else Vector3.ZERO

func _get_player_ship() -> Node:
	var player_ships = get_tree().get_nodes_in_group("player_ships")
	return player_ships[0] if not player_ships.is_empty() else null

## Status and debugging

## Get threat assessment status
func get_threat_status() -> Dictionary:
	return {
		"real_time_enabled": real_time_assessment_enabled,
		"assessment_frequency": assessment_frequency,
		"active_threats": target_threats.size(),
		"high_priority_threats": get_high_priority_threats().size(),
		"active_patterns": active_threat_patterns.size(),
		"critical_threshold": critical_threat_threshold,
		"high_threshold": high_threat_threshold,
		"threat_weights": threat_weights
	}

## Get threat statistics
func get_threat_statistics() -> Dictionary:
	var stats = {
		"total_threats": target_threats.size(),
		"critical_threats": 0,
		"high_threats": 0,
		"medium_threats": 0,
		"low_threats": 0,
		"average_threat_level": 0.0,
		"max_threat_level": 0.0
	}
	
	var total_threat = 0.0
	var max_threat = 0.0
	
	for threat_data in target_threats.values():
		var threat_level = threat_data.overall_threat
		total_threat += threat_level
		max_threat = max(max_threat, threat_level)
		
		if threat_level >= critical_threat_threshold:
			stats.critical_threats += 1
		elif threat_level >= high_threat_threshold:
			stats.high_threats += 1
		elif threat_level >= 0.3:
			stats.medium_threats += 1
		else:
			stats.low_threats += 1
	
	if target_threats.size() > 0:
		stats.average_threat_level = total_threat / target_threats.size()
	stats.max_threat_level = max_threat
	
	return stats
