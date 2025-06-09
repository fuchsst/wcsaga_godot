class_name TargetingDataCollector
extends RefCounted

## EPIC-012 HUD-002: Specialized targeting data collector for real-time combat information
## Provides optimized access to targeting systems and combat data

signal targeting_data_updated(data: Dictionary)
signal targeting_data_error(error: String)

# Targeting system references
var player_ship: BaseShip = null
var targeting_system: Node = null
var object_manager: Node = null

# Data caching and optimization
var last_targeting_data: Dictionary = {}
var data_update_time: float = 0.0
var collection_performance_ms: float = 0.0

# Update frequency control
var update_interval: float = 0.016  # 60 FPS for critical targeting data
var last_update_time: float = 0.0

## Initialize targeting data collector with system references
func initialize(ship: BaseShip, obj_mgr: Node = null) -> bool:
	player_ship = ship
	object_manager = obj_mgr
	
	if not player_ship:
		targeting_data_error.emit("Player ship not found for targeting")
		return false
	
	# Find targeting system
	targeting_system = _find_targeting_system()
	
	print("TargetingDataCollector: Initialized with ship: %s" % player_ship.name)
	return true

## Check if targeting data should be updated this frame
func should_update() -> bool:
	var current_time = Time.get_ticks_usec() / 1000000.0
	return (current_time - last_update_time) >= update_interval

## Collect comprehensive targeting data
func collect_targeting_data() -> Dictionary:
	if not player_ship or not should_update():
		return last_targeting_data
	
	var start_time = Time.get_ticks_usec()
	var targeting_data: Dictionary = {}
	
	# Get current target
	var current_target = _get_current_target()
	
	if current_target:
		# Target identification
		targeting_data["has_target"] = true
		targeting_data["target_name"] = _get_target_name(current_target)
		targeting_data["target_type"] = _get_target_type(current_target)
		targeting_data["target_class"] = _get_target_class(current_target)
		
		# Target status
		targeting_data["target_hull"] = _get_target_hull(current_target)
		targeting_data["target_shield"] = _get_target_shield(current_target)
		targeting_data["target_shield_quadrants"] = _get_target_shield_quadrants(current_target)
		
		# Target position and movement
		targeting_data["target_position"] = _get_target_position(current_target)
		targeting_data["target_distance"] = _get_target_distance(current_target)
		targeting_data["target_velocity"] = _get_target_velocity(current_target)
		targeting_data["target_relative_velocity"] = _get_relative_velocity(current_target)
		
		# Target relationship and classification
		targeting_data["is_hostile"] = _is_target_hostile(current_target)
		targeting_data["is_friendly"] = _is_target_friendly(current_target)
		targeting_data["threat_level"] = _get_threat_level(current_target)
		
		# Weapon lock and firing solution
		targeting_data["weapon_lock_status"] = _get_weapon_lock_status(current_target)
		targeting_data["firing_solution"] = _get_firing_solution(current_target)
		targeting_data["target_in_reticle"] = _is_target_in_reticle(current_target)
		targeting_data["time_to_impact"] = _get_time_to_impact(current_target)
		
		# Target subsystem targeting
		targeting_data["targeted_subsystem"] = _get_targeted_subsystem(current_target)
		targeting_data["subsystem_health"] = _get_subsystem_health(current_target)
		
		# Target capabilities and status
		targeting_data["target_capabilities"] = _get_target_capabilities(current_target)
		targeting_data["target_status_flags"] = _get_target_status_flags(current_target)
	else:
		# No target data
		targeting_data["has_target"] = false
		targeting_data["target_name"] = ""
		targeting_data["target_type"] = ""
		targeting_data["last_target_lost_time"] = _get_last_target_lost_time()
	
	# Multi-target tracking
	targeting_data["secondary_targets"] = _get_secondary_targets()
	targeting_data["potential_targets"] = _get_potential_targets()
	targeting_data["target_history"] = _get_target_history()
	
	# Targeting system status
	targeting_data["targeting_system_operational"] = _is_targeting_system_operational()
	targeting_data["sensor_range"] = _get_sensor_range()
	targeting_data["targeting_computer_efficiency"] = _get_targeting_computer_efficiency()
	
	# Performance tracking
	var end_time = Time.get_ticks_usec()
	collection_performance_ms = (end_time - start_time) / 1000.0
	data_update_time = Time.get_ticks_usec() / 1000000.0
	last_update_time = data_update_time
	
	# Cache and emit update
	last_targeting_data = targeting_data
	targeting_data_updated.emit(targeting_data)
	
	return targeting_data

## Get current target from player ship
func _get_current_target() -> Node:
	if player_ship.has_method("get_target"):
		return player_ship.get_target()
	elif player_ship.has_method("get_current_target"):
		return player_ship.get_current_target()
	elif "current_target" in player_ship:
		return player_ship.current_target
	else:
		return null

## Get target name
func _get_target_name(target: Node) -> String:
	if target is BaseShip:
		return target.get_ship_name()
	elif target is BaseSpaceObject:
		var info = target.get_space_object_info()
		return info.get("name", target.name)
	else:
		return target.name

## Get target type classification
func _get_target_type(target: Node) -> String:
	if target is BaseShip:
		return target.get_ship_type()
	elif target is BaseSpaceObject:
		return target.get_object_type()
	else:
		return "unknown"

## Get target class (fighter, capital, etc.)
func _get_target_class(target: Node) -> String:
	if target is BaseShip:
		return target.get_ship_class()
	else:
		var ship_type = _get_target_type(target)
		# Basic classification based on type
		match ship_type.to_lower():
			"fighter", "interceptor", "bomber":
				return "fighter"
			"cruiser", "destroyer", "corvette":
				return "capital"
			"freighter", "transport":
				return "transport"
			_:
				return "unknown"

## Get target hull percentage
func _get_target_hull(target: Node) -> float:
	if target is BaseShip:
		return target.get_hull_percentage()
	else:
		return 100.0

## Get target shield percentage
func _get_target_shield(target: Node) -> float:
	if target is BaseShip:
		return target.get_shield_percentage()
	else:
		return 0.0  # Non-ship objects don't have shields

## Get target shield quadrant status
func _get_target_shield_quadrants(target: Node) -> Dictionary:
	if target is BaseShip:
		return target.get_shield_quadrants()
	else:
		return {
			"front": 0.0,
			"rear": 0.0,
			"left": 0.0,
			"right": 0.0
		}

## Get target position
func _get_target_position(target: Node) -> Vector3:
	return target.global_position

## Get distance to target
func _get_target_distance(target: Node) -> float:
	var player_pos = player_ship.global_position
	var target_pos = target.global_position
	return player_pos.distance_to(target_pos)

## Get target velocity
func _get_target_velocity(target: Node) -> Vector3:
	if target.has_method("get_velocity"):
		return target.get_velocity()
	elif "velocity" in target:
		return target.velocity
	else:
		return Vector3.ZERO

## Get relative velocity between player and target
func _get_relative_velocity(target: Node) -> Vector3:
	var target_velocity = _get_target_velocity(target)
	var player_velocity = Vector3.ZERO
	
	if player_ship.has_method("get_velocity"):
		player_velocity = player_ship.get_velocity()
	elif "velocity" in player_ship:
		player_velocity = player_ship.velocity
	
	return target_velocity - player_velocity

## Check if target is hostile
func _is_target_hostile(target: Node) -> bool:
	if target is BaseShip and player_ship is BaseShip:
		return target.is_hostile_to_ship(player_ship)
	else:
		return false

## Check if target is friendly
func _is_target_friendly(target: Node) -> bool:
	if target is BaseShip and player_ship is BaseShip:
		# If not hostile, consider friendly (neutral counts as friendly for targeting)
		return not target.is_hostile_to_ship(player_ship)
	else:
		return true  # Non-ship objects are considered neutral/friendly

## Get threat level assessment
func _get_threat_level(target: Node) -> String:
	if not _is_target_hostile(target):
		return "none"
	
	var target_type = _get_target_type(target).to_lower()
	var distance = _get_target_distance(target)
	
	# Basic threat assessment
	if distance > 5000:  # Far away
		return "low"
	elif target_type in ["fighter", "interceptor"]:
		return "medium"
	elif target_type in ["bomber", "cruiser"]:
		return "high"
	else:
		return "medium"

## Get weapon lock status
func _get_weapon_lock_status(target: Node) -> Dictionary:
	var lock_status = {
		"locked": false,
		"locking": false,
		"lock_percentage": 0.0,
		"lock_time_remaining": 0.0,
		"weapon_can_lock": false
	}
	
	if targeting_system and targeting_system.has_method("get_weapon_lock_status"):
		return targeting_system.get_weapon_lock_status(target)
	elif player_ship.has_method("get_weapon_lock_status"):
		return player_ship.get_weapon_lock_status(target)
	
	return lock_status

## Get firing solution data
func _get_firing_solution(target: Node) -> Dictionary:
	var firing_solution = {
		"has_solution": false,
		"lead_angle": 0.0,
		"time_to_target": 0.0,
		"intercept_position": Vector3.ZERO,
		"weapon_in_range": false
	}
	
	if targeting_system and targeting_system.has_method("get_firing_solution"):
		return targeting_system.get_firing_solution(target)
	
	# Basic firing solution calculation
	var distance = _get_target_distance(target)
	var relative_velocity = _get_relative_velocity(target)
	
	# Estimate time to target (simplified)
	if relative_velocity.length() > 0:
		firing_solution.time_to_target = distance / relative_velocity.length()
		firing_solution.has_solution = distance < 2000  # Basic range check
		firing_solution.weapon_in_range = distance < 1500
	
	return firing_solution

## Check if target is in reticle
func _is_target_in_reticle(target: Node) -> bool:
	if targeting_system and targeting_system.has_method("is_target_in_reticle"):
		return targeting_system.is_target_in_reticle(target)
	
	# Basic angle check
	var to_target = (target.global_position - player_ship.global_position).normalized()
	var forward = -player_ship.global_transform.basis.z
	var angle = forward.angle_to(to_target)
	
	return angle < deg_to_rad(15.0)  # 15 degree cone

## Get estimated time to impact
func _get_time_to_impact(target: Node) -> float:
	var firing_solution = _get_firing_solution(target)
	return firing_solution.get("time_to_target", 0.0)

## Get targeted subsystem
func _get_targeted_subsystem(target: Node) -> String:
	if targeting_system and targeting_system.has_method("get_targeted_subsystem"):
		return targeting_system.get_targeted_subsystem(target)
	else:
		return "hull"  # Default to hull targeting

## Get subsystem health
func _get_subsystem_health(target: Node) -> Dictionary:
	var subsystem_name = _get_targeted_subsystem(target)
	
	if target.has_method("get_subsystem_health"):
		return target.get_subsystem_health(subsystem_name)
	
	# Default subsystem health
	return {"health": 100.0, "operational": true, "critical": false}

## Get target capabilities
func _get_target_capabilities(target: Node) -> Dictionary:
	var capabilities = {
		"has_shields": true,
		"has_weapons": true,
		"can_dock": false,
		"max_speed": 100.0,
		"maneuverability": "medium"
	}
	
	if target.has_method("get_capabilities"):
		return target.get_capabilities()
	
	return capabilities

## Get target status flags
func _get_target_status_flags(target: Node) -> int:
	if target.has_method("get_ship_flags"):
		return target.get_ship_flags()
	else:
		return 0

## Get last target lost time
func _get_last_target_lost_time() -> float:
	# This would be tracked by the targeting system
	return 0.0

## Get secondary targets (multi-target tracking)
func _get_secondary_targets() -> Array[Dictionary]:
	var secondary_targets: Array[Dictionary] = []
	
	if targeting_system and targeting_system.has_method("get_secondary_targets"):
		return targeting_system.get_secondary_targets()
	
	return secondary_targets

## Get potential targets in sensor range
func _get_potential_targets() -> Array[Dictionary]:
	var potential_targets: Array[Dictionary] = []
	
	if object_manager and object_manager.has_method("get_objects_in_range"):
		var nearby_objects = object_manager.get_objects_in_range(player_ship.global_position, 5000.0)
		
		for obj in nearby_objects:
			if obj != player_ship and _is_valid_target(obj):
				potential_targets.append({
					"object": obj,
					"name": _get_target_name(obj),
					"distance": _get_target_distance(obj),
					"type": _get_target_type(obj)
				})
	
	return potential_targets

## Get targeting history
func _get_target_history() -> Array[String]:
	# This would be maintained by the targeting system
	return []

## Check if targeting system is operational
func _is_targeting_system_operational() -> bool:
	if targeting_system and targeting_system.has_method("is_operational"):
		return targeting_system.is_operational()
	elif player_ship.has_method("is_targeting_operational"):
		return player_ship.is_targeting_operational()
	else:
		return true  # Assume operational

## Get sensor range
func _get_sensor_range() -> float:
	if player_ship.has_method("get_sensor_range"):
		return player_ship.get_sensor_range()
	else:
		return 10000.0  # Default sensor range

## Get targeting computer efficiency
func _get_targeting_computer_efficiency() -> float:
	if targeting_system and targeting_system.has_method("get_efficiency"):
		return targeting_system.get_efficiency()
	else:
		return 100.0  # Assume full efficiency

## Check if object is a valid target
func _is_valid_target(obj: Node) -> bool:
	# Check if object has targeting-relevant methods
	return obj.has_method("get_ship_type") or obj.has_method("get_object_type")

## Find targeting system
func _find_targeting_system() -> Node:
	# Look for targeting system as child of player ship
	if player_ship:
		for child in player_ship.get_children():
			if child.name.to_lower().contains("targeting") or child.has_method("get_weapon_lock_status"):
				return child
	
	return null

## Get performance statistics
func get_performance_statistics() -> Dictionary:
	return {
		"collection_time_ms": collection_performance_ms,
		"update_frequency": 1.0 / update_interval,
		"last_update_time": data_update_time,
		"data_size": last_targeting_data.size()
	}

## Set update frequency for targeting data collection
func set_update_frequency(frequency_hz: float) -> void:
	update_interval = 1.0 / max(1.0, frequency_hz)
	print("TargetingDataCollector: Update frequency set to %.1f Hz" % frequency_hz)

## Get cached targeting data without triggering collection
func get_cached_data() -> Dictionary:
	return last_targeting_data.duplicate()

## Check if targeting data collector is functional
func is_functional() -> bool:
	return player_ship != null and is_instance_valid(player_ship)