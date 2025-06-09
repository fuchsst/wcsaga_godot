class_name TacticalAnalyzer
extends RefCounted

## EPIC-012 HUD-005: Tactical Assessment System
## Analyzes target threat level, capabilities, and optimal engagement strategies

signal threat_assessment_updated(assessment: Dictionary)
signal engagement_parameters_changed(parameters: Dictionary)
signal target_priority_updated(priority: int)

# Threat assessment levels
enum ThreatLevel {
	MINIMAL = 0,    # Cargo, unarmed civilian
	LOW = 1,        # Light fighters, scouts
	MODERATE = 2,   # Medium fighters, armed transports
	HIGH = 3,       # Heavy fighters, bombers, corvettes
	EXTREME = 4     # Capital ships, ace pilots, boss encounters
}

# Target classification
enum TargetClass {
	FIGHTER,
	BOMBER,
	CORVETTE,
	CRUISER,
	CAPITAL,
	TRANSPORT,
	CARGO,
	SUPPORT,
	UNKNOWN
}

# Assessment data structure  
class TacticalAssessment:
	var threat_level: ThreatLevel
	var target_class: TargetClass
	var weapon_capabilities: Array[String]
	var optimal_range: float
	var maneuverability_rating: float
	var engagement_priority: int
	var vulnerability_assessment: Dictionary
	var recommended_approach: String
	var estimated_time_to_kill: float
	var risk_assessment: Dictionary

# Current assessment data
var current_assessment: TacticalAssessment
var assessment_cache: Dictionary = {}
var last_assessment_time: float = 0.0

# Analysis configuration
@export var cache_duration: float = 5.0  # Cache assessments for 5 seconds
@export var enable_advanced_analysis: bool = true
@export var consider_player_loadout: bool = true

# Weapon classification data
var weapon_threat_ratings: Dictionary = {
	# Primary weapons
	"laser_cannon": {"threat": 2, "range": 1000, "dps": 45},
	"pulse_cannon": {"threat": 3, "range": 800, "dps": 60},
	"plasma_cannon": {"threat": 4, "range": 600, "dps": 80},
	"beam_cannon": {"threat": 5, "range": 1500, "dps": 120},
	
	# Secondary weapons
	"missile_launcher": {"threat": 4, "range": 2000, "dps": 200},
	"torpedo_launcher": {"threat": 5, "range": 3000, "dps": 400},
	"flak_gun": {"threat": 3, "range": 500, "dps": 75},
	"emp_cannon": {"threat": 2, "range": 800, "dps": 0},
	
	# Capital weapons
	"turret_laser": {"threat": 6, "range": 2000, "dps": 150},
	"turret_beam": {"threat": 8, "range": 3000, "dps": 300},
	"capital_missile": {"threat": 7, "range": 5000, "dps": 500},
}

# Ship class threat modifiers
var class_threat_modifiers: Dictionary = {
	TargetClass.FIGHTER: 1.0,
	TargetClass.BOMBER: 1.2,
	TargetClass.CORVETTE: 1.5,
	TargetClass.CRUISER: 2.0,
	TargetClass.CAPITAL: 3.0,
	TargetClass.TRANSPORT: 0.7,
	TargetClass.CARGO: 0.3,
	TargetClass.SUPPORT: 0.8,
	TargetClass.UNKNOWN: 1.0
}

func _init() -> void:
	current_assessment = TacticalAssessment.new()
	print("TacticalAnalyzer: Initialized")

## Setup tactical analyzer
func setup() -> void:
	print("TacticalAnalyzer: Setup complete")

## Assess target threat level and capabilities
func assess_target_threat(target: Node) -> TacticalAssessment:
	if not target:
		return _create_empty_assessment()
	
	# Check cache first
	var target_id = _get_target_id(target)
	var current_time = Time.get_time_dict_from_system()["unix"]
	
	if assessment_cache.has(target_id):
		var cached = assessment_cache[target_id]
		if current_time - cached.timestamp < cache_duration:
			return cached.assessment
	
	# Perform new assessment
	var assessment = TacticalAssessment.new()
	
	# Basic target classification
	assessment.target_class = _classify_target(target)
	assessment.threat_level = _calculate_base_threat_level(target, assessment.target_class)
	
	# Weapon capability analysis
	assessment.weapon_capabilities = _analyze_weapon_capabilities(target)
	
	# Calculate optimal engagement parameters
	assessment.optimal_range = calculate_optimal_engagement_range(target, _get_player_weapons())
	assessment.maneuverability_rating = evaluate_target_maneuverability(target)
	
	# Advanced analysis
	if enable_advanced_analysis:
		assessment.vulnerability_assessment = _analyze_vulnerabilities(target)
		assessment.recommended_approach = _determine_engagement_approach(target, assessment)
		assessment.estimated_time_to_kill = _estimate_time_to_kill(target)
		assessment.risk_assessment = _assess_engagement_risk(target, assessment)
	
	# Calculate engagement priority
	assessment.engagement_priority = _calculate_engagement_priority(target, assessment)
	
	# Cache the assessment
	assessment_cache[target_id] = {
		"assessment": assessment,
		"timestamp": current_time
	}
	
	current_assessment = assessment
	last_assessment_time = current_time
	
	# Emit signals
	threat_assessment_updated.emit(_assessment_to_dictionary(assessment))
	target_priority_updated.emit(assessment.engagement_priority)
	
	print("TacticalAnalyzer: Assessed %s - Threat: %s, Priority: %d" % [
		_get_target_name(target), 
		ThreatLevel.keys()[assessment.threat_level], 
		assessment.engagement_priority
	])
	
	return assessment

## Calculate optimal engagement range
func calculate_optimal_engagement_range(target: Node, player_weapons: Array) -> float:
	if not target or player_weapons.is_empty():
		return 1000.0  # Default safe range
	
	var target_weapons = _get_target_weapons(target)
	var player_max_range = _get_max_weapon_range(player_weapons)
	var target_max_range = _get_max_weapon_range(target_weapons)
	var target_maneuverability = evaluate_target_maneuverability(target)
	
	# Optimal range calculation
	var optimal_range: float
	
	if target_max_range > player_max_range:
		# Target outranges us - close to medium range
		optimal_range = player_max_range * 0.8
	elif player_max_range > target_max_range * 1.5:
		# We significantly outrange target - stay at max range
		optimal_range = target_max_range * 1.2
	else:
		# Similar ranges - consider maneuverability
		if target_maneuverability > 0.7:
			# Highly maneuverable - close range for better accuracy
			optimal_range = min(player_max_range, target_max_range) * 0.6
		else:
			# Less maneuverable - medium range
			optimal_range = min(player_max_range, target_max_range) * 0.8
	
	# Clamp to reasonable values
	optimal_range = clampf(optimal_range, 200.0, 5000.0)
	
	return optimal_range

## Evaluate target maneuverability
func evaluate_target_maneuverability(target: Node) -> float:
	if not target:
		return 0.0
	
	var maneuverability = 0.5  # Default medium maneuverability
	
	# Base maneuverability by class
	var target_class = _classify_target(target)
	match target_class:
		TargetClass.FIGHTER:
			maneuverability = 0.8
		TargetClass.BOMBER:
			maneuverability = 0.6
		TargetClass.CORVETTE:
			maneuverability = 0.4
		TargetClass.CRUISER:
			maneuverability = 0.3
		TargetClass.CAPITAL:
			maneuverability = 0.1
		TargetClass.TRANSPORT:
			maneuverability = 0.2
		TargetClass.CARGO:
			maneuverability = 0.1
		TargetClass.SUPPORT:
			maneuverability = 0.3
		_:
			maneuverability = 0.5
	
	# Adjust based on target state
	if target.has_method("get_velocity"):
		var velocity = target.get_velocity()
		var speed = velocity.length()
		if speed > 200.0:
			maneuverability += 0.1  # Fast-moving targets are harder to hit
	
	if target.has_method("get_hull_percentage"):
		var hull = target.get_hull_percentage()
		if hull < 50.0:
			maneuverability *= 0.8  # Damaged ships are less maneuverable
	
	# Check for engine damage
	if target.has_method("get_subsystem_status"):
		var subsystems = target.get_subsystem_status()
		if subsystems.has("engines"):
			var engine_health = subsystems["engines"].get("health", 100.0)
			maneuverability *= (engine_health / 100.0)
	
	return clampf(maneuverability, 0.0, 1.0)

## Classify target type
func _classify_target(target: Node) -> TargetClass:
	if target.has_method("get_ship_class"):
		var ship_class = target.get_ship_class().to_lower()
		
		if "fighter" in ship_class or "interceptor" in ship_class:
			return TargetClass.FIGHTER
		elif "bomber" in ship_class or "assault" in ship_class:
			return TargetClass.BOMBER
		elif "corvette" in ship_class or "gunboat" in ship_class:
			return TargetClass.CORVETTE
		elif "cruiser" in ship_class or "destroyer" in ship_class:
			return TargetClass.CRUISER
		elif "capital" in ship_class or "dreadnought" in ship_class or "battleship" in ship_class:
			return TargetClass.CAPITAL
		elif "transport" in ship_class or "freighter" in ship_class:
			return TargetClass.TRANSPORT
		elif "cargo" in ship_class or "container" in ship_class:
			return TargetClass.CARGO
		elif "support" in ship_class or "repair" in ship_class or "refuel" in ship_class:
			return TargetClass.SUPPORT
	
	return TargetClass.UNKNOWN

## Calculate base threat level
func _calculate_base_threat_level(target: Node, target_class: TargetClass) -> ThreatLevel:
	var base_threat: int = 1  # Default to LOW
	
	# Base threat by class
	match target_class:
		TargetClass.FIGHTER:
			base_threat = ThreatLevel.LOW
		TargetClass.BOMBER:
			base_threat = ThreatLevel.MODERATE
		TargetClass.CORVETTE:
			base_threat = ThreatLevel.MODERATE
		TargetClass.CRUISER:
			base_threat = ThreatLevel.HIGH
		TargetClass.CAPITAL:
			base_threat = ThreatLevel.EXTREME
		TargetClass.TRANSPORT:
			base_threat = ThreatLevel.LOW
		TargetClass.CARGO:
			base_threat = ThreatLevel.MINIMAL
		TargetClass.SUPPORT:
			base_threat = ThreatLevel.MINIMAL
		_:
			base_threat = ThreatLevel.LOW
	
	# Modify based on weapon loadout
	var weapons = _get_target_weapons(target)
	var weapon_threat = _calculate_weapon_threat(weapons)
	
	if weapon_threat > 10:
		base_threat = min(base_threat + 2, ThreatLevel.EXTREME)
	elif weapon_threat > 5:
		base_threat = min(base_threat + 1, ThreatLevel.EXTREME)
	
	# Modify based on hull/shield status
	if target.has_method("get_hull_percentage"):
		var hull = target.get_hull_percentage()
		if hull < 25.0:
			base_threat = max(base_threat - 1, ThreatLevel.MINIMAL)
	
	return base_threat as ThreatLevel

## Analyze weapon capabilities
func _analyze_weapon_capabilities(target: Node) -> Array[String]:
	var capabilities: Array[String] = []
	var weapons = _get_target_weapons(target)
	
	for weapon in weapons:
		var weapon_name = weapon.get("name", "unknown")
		var weapon_type = weapon.get("type", "unknown")
		
		# Categorize weapon capabilities
		if "laser" in weapon_name or "pulse" in weapon_name:
			if not capabilities.has("energy_weapons"):
				capabilities.append("energy_weapons")
		
		if "missile" in weapon_name or "torpedo" in weapon_name:
			if not capabilities.has("guided_weapons"):
				capabilities.append("guided_weapons")
		
		if "beam" in weapon_name:
			if not capabilities.has("beam_weapons"):
				capabilities.append("beam_weapons")
		
		if "flak" in weapon_name:
			if not capabilities.has("anti_fighter"):
				capabilities.append("anti_fighter")
		
		if "turret" in weapon_name:
			if not capabilities.has("turret_weapons"):
				capabilities.append("turret_weapons")
	
	# Add special capabilities
	if target.has_method("get_subsystem_status"):
		var subsystems = target.get_subsystem_status()
		if subsystems.has("sensors") and subsystems["sensors"].get("operational", false):
			capabilities.append("advanced_sensors")
		
		if subsystems.has("communication") and subsystems["communication"].get("operational", false):
			capabilities.append("coordination")
	
	return capabilities

## Calculate weapon threat rating
func _calculate_weapon_threat(weapons: Array) -> int:
	var total_threat = 0
	
	for weapon in weapons:
		var weapon_name = weapon.get("name", "unknown").to_lower()
		var weapon_count = weapon.get("count", 1)
		
		# Find matching threat rating
		for rating_name in weapon_threat_ratings:
			if rating_name in weapon_name:
				total_threat += weapon_threat_ratings[rating_name]["threat"] * weapon_count
				break
	
	return total_threat

## Get maximum weapon range
func _get_max_weapon_range(weapons: Array) -> float:
	var max_range = 0.0
	
	for weapon in weapons:
		var weapon_name = weapon.get("name", "unknown").to_lower()
		var weapon_range = weapon.get("range", 1000.0)
		
		# Use configured range if available
		for rating_name in weapon_threat_ratings:
			if rating_name in weapon_name:
				weapon_range = weapon_threat_ratings[rating_name]["range"]
				break
		
		max_range = max(max_range, weapon_range)
	
	return max_range

## Advanced analysis methods
func _analyze_vulnerabilities(target: Node) -> Dictionary:
	var vulnerabilities = {
		"weak_shields": false,
		"damaged_engines": false,
		"weapon_systems_down": false,
		"low_maneuverability": false,
		"exposed_subsystems": []
	}
	
	# Check shield status
	if target.has_method("get_shield_percentage"):
		var shields = target.get_shield_percentage()
		vulnerabilities["weak_shields"] = shields < 25.0
	
	# Check subsystem damage
	if target.has_method("get_subsystem_status"):
		var subsystems = target.get_subsystem_status()
		
		if subsystems.has("engines"):
			var engine_health = subsystems["engines"].get("health", 100.0)
			vulnerabilities["damaged_engines"] = engine_health < 50.0
		
		if subsystems.has("weapons"):
			var weapon_health = subsystems["weapons"].get("health", 100.0)
			vulnerabilities["weapon_systems_down"] = weapon_health < 25.0
		
		# Find exposed (low health) subsystems
		for subsystem_name in subsystems:
			var subsystem = subsystems[subsystem_name]
			var health = subsystem.get("health", 100.0)
			if health < 50.0:
				vulnerabilities["exposed_subsystems"].append(subsystem_name)
	
	# Check maneuverability
	var maneuverability = evaluate_target_maneuverability(target)
	vulnerabilities["low_maneuverability"] = maneuverability < 0.3
	
	return vulnerabilities

## Determine engagement approach
func _determine_engagement_approach(target: Node, assessment: TacticalAssessment) -> String:
	var approach = "standard_attack"
	
	# Consider threat level
	match assessment.threat_level:
		ThreatLevel.MINIMAL:
			approach = "close_assault"
		ThreatLevel.LOW:
			approach = "standard_attack"
		ThreatLevel.MODERATE:
			approach = "cautious_engagement"
		ThreatLevel.HIGH:
			approach = "long_range_harassment"
		ThreatLevel.EXTREME:
			approach = "hit_and_run"
	
	# Modify based on vulnerabilities
	if assessment.vulnerability_assessment.get("weak_shields", false):
		approach = "shield_penetration"
	elif assessment.vulnerability_assessment.get("damaged_engines", false):
		approach = "pursuit_engagement"
	elif assessment.vulnerability_assessment.get("weapon_systems_down", false):
		approach = "close_assault"
	
	# Consider maneuverability difference
	if assessment.maneuverability_rating < 0.3:
		approach = "bombardment"
	elif assessment.maneuverability_rating > 0.8:
		approach = "patient_stalking"
	
	return approach

## Estimate time to kill
func _estimate_time_to_kill(target: Node) -> float:
	if not target:
		return 0.0
	
	# Get target health
	var hull_percentage = 100.0
	if target.has_method("get_hull_percentage"):
		hull_percentage = target.get_hull_percentage()
	
	var shield_percentage = 0.0
	if target.has_method("get_shield_percentage"):
		shield_percentage = target.get_shield_percentage()
	
	# Estimate target health pool
	var estimated_hull_hp = hull_percentage * _estimate_max_hull(target) / 100.0
	var estimated_shield_hp = shield_percentage * _estimate_max_shields(target) / 100.0
	var total_hp = estimated_hull_hp + estimated_shield_hp
	
	# Estimate player DPS
	var player_dps = _estimate_player_dps()
	
	# Calculate time to kill
	if player_dps > 0:
		return total_hp / player_dps
	else:
		return 999.0  # Unknown/infinite

## Calculate engagement priority
func _calculate_engagement_priority(target: Node, assessment: TacticalAssessment) -> int:
	var priority = 5  # Medium priority
	
	# Higher priority for higher threats
	priority += assessment.threat_level * 2
	
	# Mission-specific adjustments (placeholder)
	if target.has_method("get_mission_priority"):
		priority += target.get_mission_priority()
	
	# Vulnerability bonus
	var vuln_count = 0
	for key in assessment.vulnerability_assessment:
		if assessment.vulnerability_assessment[key] == true:
			vuln_count += 1
	priority += vuln_count
	
	# Distance penalty (closer = higher priority)
	var distance = _get_target_distance(target)
	if distance > 2000.0:
		priority -= 2
	elif distance < 500.0:
		priority += 1
	
	return clampi(priority, 1, 10)

## Utility methods
func _create_empty_assessment() -> TacticalAssessment:
	var assessment = TacticalAssessment.new()
	assessment.threat_level = ThreatLevel.MINIMAL
	assessment.target_class = TargetClass.UNKNOWN
	assessment.weapon_capabilities = []
	assessment.optimal_range = 1000.0
	assessment.maneuverability_rating = 0.5
	assessment.engagement_priority = 1
	assessment.vulnerability_assessment = {}
	assessment.recommended_approach = "avoid"
	assessment.estimated_time_to_kill = 999.0
	assessment.risk_assessment = {}
	return assessment

func _get_target_id(target: Node) -> String:
	return str(target.get_instance_id())

func _get_target_name(target: Node) -> String:
	if target.has_method("get_ship_name"):
		return target.get_ship_name()
	else:
		return target.name

func _get_target_weapons(target: Node) -> Array:
	if target.has_method("get_weapon_loadout"):
		return target.get_weapon_loadout()
	else:
		return []

func _get_player_weapons() -> Array:
	# Would get player weapons from game state in real implementation
	return []

func _get_target_distance(target: Node) -> float:
	# Would calculate distance from player in real implementation
	return 1000.0

func _estimate_max_hull(target: Node) -> float:
	# Estimate based on target class
	var target_class = _classify_target(target)
	match target_class:
		TargetClass.FIGHTER: return 150.0
		TargetClass.BOMBER: return 250.0
		TargetClass.CORVETTE: return 800.0
		TargetClass.CRUISER: return 2000.0
		TargetClass.CAPITAL: return 8000.0
		TargetClass.TRANSPORT: return 400.0
		TargetClass.CARGO: return 200.0
		TargetClass.SUPPORT: return 300.0
		_: return 200.0

func _estimate_max_shields(target: Node) -> float:
	# Estimate based on target class
	var target_class = _classify_target(target)
	match target_class:
		TargetClass.FIGHTER: return 100.0
		TargetClass.BOMBER: return 150.0
		TargetClass.CORVETTE: return 600.0
		TargetClass.CRUISER: return 1500.0
		TargetClass.CAPITAL: return 6000.0
		TargetClass.TRANSPORT: return 200.0
		TargetClass.CARGO: return 0.0
		TargetClass.SUPPORT: return 100.0
		_: return 100.0

func _estimate_player_dps() -> float:
	# Placeholder - would calculate based on player weapons
	return 75.0

func _assess_engagement_risk(target: Node, assessment: TacticalAssessment) -> Dictionary:
	return {
		"collision_risk": "low",
		"backup_threat": "none",
		"escape_difficulty": "medium"
	}

func _assessment_to_dictionary(assessment: TacticalAssessment) -> Dictionary:
	return {
		"threat_level": assessment.threat_level,
		"target_class": assessment.target_class,
		"weapon_capabilities": assessment.weapon_capabilities,
		"optimal_range": assessment.optimal_range,
		"maneuverability_rating": assessment.maneuverability_rating,
		"engagement_priority": assessment.engagement_priority,
		"vulnerability_assessment": assessment.vulnerability_assessment,
		"recommended_approach": assessment.recommended_approach,
		"estimated_time_to_kill": assessment.estimated_time_to_kill,
		"risk_assessment": assessment.risk_assessment
	}

## Get current assessment
func get_current_assessment() -> TacticalAssessment:
	return current_assessment

## Clear assessment cache
func clear_cache() -> void:
	assessment_cache.clear()
	print("TacticalAnalyzer: Cache cleared")
