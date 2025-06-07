class_name ThreatDetectedCondition
extends WCSBTCondition

## Condition that checks for nearby threats and evaluates danger level

@export var detection_range: float = 2000.0
@export var threat_threshold: float = 0.3  # Minimum threat level to trigger
@export var check_missiles: bool = true
@export var check_enemy_ships: bool = true
@export var check_weapons_fire: bool = true
@export var immediate_threat_range: float = 500.0  # Range for immediate threats

var detected_threats: Array = []  # Array[Dictionary] - simplified for compatibility
var last_scan_time: float = 0.0
var scan_frequency: float = 0.2  # Scan every 0.2 seconds

func evaluate_wcs_condition(delta: float) -> bool:
	var current_time: float = Time.get_time_from_start()
	
	# Only scan for threats periodically for performance
	if current_time - last_scan_time >= scan_frequency:
		_scan_for_threats()
		last_scan_time = current_time
	
	# Evaluate current threat level
	var threat_level: float = _calculate_total_threat_level()
	
	return threat_level >= threat_threshold

func _scan_for_threats() -> void:
	detected_threats.clear()
	var ship_pos: Vector3 = get_ship_position()
	
	if check_enemy_ships:
		_scan_for_enemy_ships(ship_pos)
	
	if check_missiles:
		_scan_for_incoming_missiles(ship_pos)
	
	if check_weapons_fire:
		_scan_for_weapons_fire(ship_pos)

func _scan_for_enemy_ships(ship_pos: Vector3) -> void:
	# Get all objects in detection range (this would need proper object management system)
	var nearby_objects: Array = _get_nearby_objects(ship_pos, detection_range)
	
	for obj in nearby_objects:
		if _is_enemy_ship(obj):
			var threat_info: Dictionary = _analyze_ship_threat(obj, ship_pos)
			if threat_info.get("threat_level", 0.0) > 0.1:
				detected_threats.append(threat_info)

func _scan_for_incoming_missiles(ship_pos: Vector3) -> void:
	# Scan for missiles targeting this ship
	var nearby_objects: Array = _get_nearby_objects(ship_pos, detection_range)
	
	for obj in nearby_objects:
		if _is_missile(obj) and _is_targeting_us(obj):
			var threat_info: Dictionary = _analyze_missile_threat(obj, ship_pos)
			detected_threats.append(threat_info)

func _scan_for_weapons_fire(ship_pos: Vector3) -> void:
	# Check for incoming weapons fire (lasers, projectiles)
	var nearby_objects: Array = _get_nearby_objects(ship_pos, detection_range * 0.5)
	
	for obj in nearby_objects:
		if _is_hostile_projectile(obj):
			var threat_info: Dictionary = _analyze_projectile_threat(obj, ship_pos)
			if threat_info.get("threat_level", 0.0) > 0.0:
				detected_threats.append(threat_info)

func _get_nearby_objects(center_pos: Vector3, range: float) -> Array:
	# This would interface with the game's object management system
	# For now, return empty array - would be implemented with proper object queries
	if ai_agent and ai_agent.has_method("get_nearby_objects"):
		return ai_agent.get_nearby_objects(range)
	
	# Fallback: basic area query using AIManager
	if AIManager and AIManager.has_method("get_objects_in_range"):
		return AIManager.get_objects_in_range(center_pos, range)
	
	return []

func _is_enemy_ship(obj: Node) -> bool:
	if not obj or not is_instance_valid(obj):
		return false
	
	# Check if object is a ship and is hostile
	if obj.has_method("get_ship_type") and obj.has_method("get_team"):
		var our_team: int = ai_agent.get_team() if ai_agent.has_method("get_team") else 0
		var their_team: int = obj.get_team()
		return their_team != our_team and their_team >= 0  # -1 might be neutral
	
	return false

func _is_missile(obj: Node) -> bool:
	if not obj or not is_instance_valid(obj):
		return false
	
	return obj.has_method("get_weapon_type") and "missile" in obj.get_weapon_type().to_lower()

func _is_targeting_us(missile: Node) -> bool:
	if not missile.has_method("get_target"):
		return false
	
	var missile_target: Node = missile.get_target()
	return missile_target == ai_agent or missile_target == ship_controller

func _is_hostile_projectile(obj: Node) -> bool:
	if not obj or not is_instance_valid(obj):
		return false
	
	# Check if it's a projectile and from an enemy
	if obj.has_method("get_source_team"):
		var our_team: int = ai_agent.get_team() if ai_agent.has_method("get_team") else 0
		var projectile_team: int = obj.get_source_team()
		return projectile_team != our_team and projectile_team >= 0
	
	return false

func _analyze_ship_threat(ship: Node, our_pos: Vector3) -> Dictionary:
	var ship_pos: Vector3 = ship.global_position if ship.has_method("global_position") else Vector3.ZERO
	var distance: float = our_pos.distance_to(ship_pos)
	
	# Base threat based on distance (closer = more threatening)
	var distance_threat: float = 1.0 - (distance / detection_range)
	distance_threat = max(distance_threat, 0.0)
	
	# Increase threat if ship is facing us or has weapons locked
	var facing_threat: float = 0.0
	if ship.has_method("get_forward_vector"):
		var ship_forward: Vector3 = ship.get_forward_vector()
		var to_us: Vector3 = (our_pos - ship_pos).normalized()
		facing_threat = max(ship_forward.dot(to_us), 0.0) * 0.3
	
	# Check ship size/class for threat multiplier
	var size_multiplier: float = 1.0
	if ship.has_method("get_ship_class"):
		var ship_class: String = ship.get_ship_class()
		if "capital" in ship_class.to_lower() or "cruiser" in ship_class.to_lower():
			size_multiplier = 2.0
		elif "fighter" in ship_class.to_lower():
			size_multiplier = 0.8
	
	var total_threat: float = (distance_threat + facing_threat) * size_multiplier
	
	# Immediate threat if very close
	if distance < immediate_threat_range:
		total_threat *= 2.0
	
	return {
		"object": ship,
		"type": "enemy_ship",
		"threat_level": clamp(total_threat, 0.0, 2.0),
		"distance": distance,
		"position": ship_pos
	}

func _analyze_missile_threat(missile: Node, our_pos: Vector3) -> Dictionary:
	var missile_pos: Vector3 = missile.global_position if missile.has_method("global_position") else Vector3.ZERO
	var distance: float = our_pos.distance_to(missile_pos)
	
	# Missiles are high priority threats
	var threat_level: float = 2.0 - (distance / (detection_range * 0.5))
	threat_level = clamp(threat_level, 0.5, 2.0)  # Always at least moderate threat
	
	# Check missile type for threat adjustment
	if missile.has_method("get_damage_potential"):
		var damage: float = missile.get_damage_potential()
		threat_level *= (1.0 + damage / 100.0)  # Scale with damage
	
	return {
		"object": missile,
		"type": "incoming_missile",
		"threat_level": clamp(threat_level, 0.0, 3.0),
		"distance": distance,
		"position": missile_pos
	}

func _analyze_projectile_threat(projectile: Node, our_pos: Vector3) -> Dictionary:
	var proj_pos: Vector3 = projectile.global_position if projectile.has_method("global_position") else Vector3.ZERO
	var distance: float = our_pos.distance_to(proj_pos)
	
	# Projectiles are lower threat than missiles but still dangerous
	var threat_level: float = 1.0 - (distance / (detection_range * 0.3))
	threat_level = clamp(threat_level, 0.0, 1.0)
	
	# Check if projectile is aimed at us
	if projectile.has_method("get_velocity"):
		var proj_velocity: Vector3 = projectile.get_velocity()
		var to_us: Vector3 = (our_pos - proj_pos).normalized()
		var aim_factor: float = proj_velocity.normalized().dot(to_us)
		if aim_factor > 0.8:  # Projectile heading towards us
			threat_level *= 1.5
	
	return {
		"object": projectile,
		"type": "hostile_projectile",
		"threat_level": clamp(threat_level, 0.0, 1.5),
		"distance": distance,
		"position": proj_pos
	}

func _calculate_total_threat_level() -> float:
	if detected_threats.is_empty():
		return 0.0
	
	var total_threat: float = 0.0
	var max_single_threat: float = 0.0
	
	for threat in detected_threats:
		var threat_val: float = threat.get("threat_level", 0.0)
		total_threat += threat_val * 0.3  # Each threat adds 30% of its value
		max_single_threat = max(max_single_threat, threat_val)
	
	# Use combination of highest single threat and accumulated threat
	return max_single_threat + (total_threat * 0.5)

func get_detected_threats() -> Array:
	return detected_threats

func get_highest_threat() -> Dictionary:
	if detected_threats.is_empty():
		return {}
	
	var highest_threat: Dictionary = {}
	var highest_level: float = 0.0
	
	for threat in detected_threats:
		var level: float = threat.get("threat_level", 0.0)
		if level > highest_level:
			highest_level = level
			highest_threat = threat
	
	return highest_threat

func get_immediate_threats() -> Array:
	var immediate: Array = []  # Array[Dictionary] - simplified for compatibility
	
	for threat in detected_threats:
		var distance: float = threat.get("distance", INF)
		if distance <= immediate_threat_range:
			immediate.append(threat)
	
	return immediate