class_name ShipDataCollector
extends RefCounted

## EPIC-012 HUD-002: Specialized ship data collector for real-time ship status
## Provides optimized access to ship systems data with performance monitoring

signal ship_data_updated(data: Dictionary)
signal ship_data_error(error: String)

# Ship system references
var player_ship: BaseShip = null
var ship_manager: Node = null

# Data caching and optimization
var last_ship_data: Dictionary = {}
var data_update_time: float = 0.0
var collection_performance_ms: float = 0.0

# Update frequency control
var update_interval: float = 0.016  # 60 FPS for critical ship data
var last_update_time: float = 0.0

## Initialize ship data collector with system references
func initialize(ship_mgr: Node = null) -> bool:
	ship_manager = ship_mgr
	
	# Find player ship
	player_ship = _find_player_ship()
	
	if not player_ship:
		ship_data_error.emit("Player ship not found")
		return false
	
	print("ShipDataCollector: Initialized with player ship: %s" % player_ship.name)
	return true

## Check if ship data should be updated this frame
func should_update() -> bool:
	var current_time = Time.get_ticks_usec() / 1000000.0
	return (current_time - last_update_time) >= update_interval

## Collect comprehensive ship status data
func collect_ship_data() -> Dictionary:
	if not player_ship or not should_update():
		return last_ship_data
	
	var start_time = Time.get_ticks_usec()
	var ship_data: Dictionary = {}
	
	# Core ship status
	ship_data["hull_percentage"] = _get_hull_percentage()
	ship_data["shield_percentage"] = _get_shield_percentage()
	ship_data["shield_quadrants"] = _get_shield_quadrant_status()
	
	# Energy and power systems
	ship_data["energy_levels"] = _get_energy_levels()
	ship_data["afterburner_fuel"] = _get_afterburner_fuel()
	ship_data["power_output"] = _get_power_output()
	
	# Flight and movement data
	ship_data["current_speed"] = _get_current_speed()
	ship_data["max_speed"] = _get_max_speed()
	ship_data["velocity"] = _get_velocity()
	ship_data["position"] = _get_position()
	ship_data["orientation"] = _get_orientation()
	
	# Ship status and flags
	ship_data["ship_flags"] = _get_ship_flags()
	ship_data["throttle_percentage"] = _get_throttle_percentage()
	ship_data["afterburner_active"] = _is_afterburner_active()
	ship_data["autopilot_active"] = _is_autopilot_active()
	
	# Subsystem status
	ship_data["subsystem_status"] = _get_subsystem_status()
	ship_data["subsystem_health"] = _get_subsystem_health_summary()
	
	# Combat and damage status
	ship_data["is_disabled"] = _is_ship_disabled()
	ship_data["is_dying"] = _is_ship_dying()
	ship_data["damage_percentage"] = _get_total_damage_percentage()
	
	# Performance tracking
	var end_time = Time.get_ticks_usec()
	collection_performance_ms = (end_time - start_time) / 1000.0
	data_update_time = Time.get_ticks_usec() / 1000000.0
	last_update_time = data_update_time
	
	# Cache and emit update
	last_ship_data = ship_data
	ship_data_updated.emit(ship_data)
	
	return ship_data

## Get hull integrity percentage
func _get_hull_percentage() -> float:
	if player_ship.has_method("get_hull_percentage"):
		return player_ship.get_hull_percentage()
	elif player_ship.has_method("get_hull_strength"):
		var hull_strength = player_ship.get_hull_strength()
		var max_hull = player_ship.get_max_hull_strength() if player_ship.has_method("get_max_hull_strength") else 100.0
		return (hull_strength / max_hull) * 100.0
	else:
		return 100.0  # Default fallback

## Get shield strength percentage
func _get_shield_percentage() -> float:
	if player_ship.has_method("get_shield_percentage"):
		return player_ship.get_shield_percentage()
	elif player_ship.has_method("get_shield_strength"):
		var shield_strength = player_ship.get_shield_strength()
		var max_shields = player_ship.get_max_shield_strength() if player_ship.has_method("get_max_shield_strength") else 100.0
		return (shield_strength / max_shields) * 100.0
	else:
		return 100.0  # Default fallback

## Get individual shield quadrant status
func _get_shield_quadrant_status() -> Dictionary:
	var quadrants = {"front": 100.0, "rear": 100.0, "left": 100.0, "right": 100.0}
	
	if player_ship.has_method("get_shield_quadrants"):
		var shield_data = player_ship.get_shield_quadrants()
		if shield_data is Dictionary:
			quadrants = shield_data
	
	return quadrants

## Get Energy Transfer System (ETS) levels
func _get_energy_levels() -> Dictionary:
	var default_levels = {"shields": 0.33, "weapons": 0.33, "engines": 0.33}
	
	if player_ship.has_method("get_energy_levels"):
		return player_ship.get_energy_levels()
	elif player_ship.has_method("get_ets_levels"):
		return player_ship.get_ets_levels()
	else:
		return default_levels

## Get afterburner fuel percentage
func _get_afterburner_fuel() -> float:
	if player_ship.has_method("get_afterburner_fuel_percentage"):
		return player_ship.get_afterburner_fuel_percentage()
	elif player_ship.has_method("get_afterburner_fuel"):
		var fuel = player_ship.get_afterburner_fuel()
		var max_fuel = player_ship.get_max_afterburner_fuel() if player_ship.has_method("get_max_afterburner_fuel") else 100.0
		return (fuel / max_fuel) * 100.0
	else:
		return 100.0

## Get current power output
func _get_power_output() -> Dictionary:
	var power_data = {"reactor_output": 100.0, "power_distribution": "normal", "emergency_power": false}
	
	if player_ship.has_method("get_power_status"):
		var ship_power = player_ship.get_power_status()
		if ship_power is Dictionary:
			power_data = ship_power
	
	return power_data

## Get current speed
func _get_current_speed() -> float:
	if player_ship.has_method("get_current_speed"):
		return player_ship.get_current_speed()
	elif player_ship.has_method("get_velocity"):
		var velocity = player_ship.get_velocity()
		return velocity.length()
	else:
		return 0.0

## Get maximum speed
func _get_max_speed() -> float:
	if player_ship.has_method("get_max_speed"):
		return player_ship.get_max_speed()
	else:
		return 100.0  # Default fallback

## Get velocity vector
func _get_velocity() -> Vector3:
	if player_ship.has_method("get_velocity"):
		return player_ship.get_velocity()
	elif "velocity" in player_ship:
		return player_ship.velocity
	else:
		return Vector3.ZERO

## Get ship position
func _get_position() -> Vector3:
	return player_ship.global_position

## Get ship orientation
func _get_orientation() -> Vector3:
	if player_ship.has_method("get_orientation"):
		return player_ship.get_orientation()
	else:
		return player_ship.global_rotation

## Get ship status flags
func _get_ship_flags() -> int:
	if player_ship.has_method("get_ship_flags"):
		return player_ship.get_ship_flags()
	else:
		return 0

## Get throttle percentage
func _get_throttle_percentage() -> float:
	if player_ship.has_method("get_throttle_percentage"):
		return player_ship.get_throttle_percentage()
	else:
		return 0.0

## Check if afterburner is active
func _is_afterburner_active() -> bool:
	if "is_afterburner_active" in player_ship:
		return player_ship.is_afterburner_active
	else:
		return false

## Check if autopilot is active
func _is_autopilot_active() -> bool:
	if "is_autopilot_active" in player_ship:
		return player_ship.is_autopilot_active
	else:
		return false

## Get comprehensive subsystem status
func _get_subsystem_status() -> Dictionary:
	var default_subsystems = {
		"engines": {"health": 100.0, "operational": true},
		"sensors": {"health": 100.0, "operational": true},
		"weapons": {"health": 100.0, "operational": true},
		"navigation": {"health": 100.0, "operational": true},
		"communication": {"health": 100.0, "operational": true}
	}
	
	if player_ship.has_method("get_subsystem_status"):
		return player_ship.get_subsystem_status()
	else:
		return default_subsystems

## Get subsystem health summary
func _get_subsystem_health_summary() -> Dictionary:
	var subsystems = _get_subsystem_status()
	var summary = {"average_health": 100.0, "critical_systems": 0, "total_systems": 0}
	
	var total_health = 0.0
	var critical_count = 0
	var system_count = 0
	
	for system_name in subsystems:
		var system_data = subsystems[system_name]
		if system_data is Dictionary and system_data.has("health"):
			var health = system_data.health
			total_health += health
			system_count += 1
			
			if health < 25.0:  # Critical threshold
				critical_count += 1
	
	if system_count > 0:
		summary.average_health = total_health / system_count
		summary.critical_systems = critical_count
		summary.total_systems = system_count
	
	return summary

## Check if ship is disabled
func _is_ship_disabled() -> bool:
	if "is_disabled" in player_ship:
		return player_ship.is_disabled
	else:
		# Check hull threshold
		return _get_hull_percentage() <= 0.0

## Check if ship is dying
func _is_ship_dying() -> bool:
	if "is_dying" in player_ship:
		return player_ship.is_dying
	else:
		# Check critical hull threshold
		return _get_hull_percentage() <= 10.0

## Get total damage percentage
func _get_total_damage_percentage() -> float:
	var hull_damage = 100.0 - _get_hull_percentage()
	var subsystem_health = _get_subsystem_health_summary()
	var subsystem_damage = 100.0 - subsystem_health.average_health
	
	# Weighted average: hull 70%, subsystems 30%
	return (hull_damage * 0.7) + (subsystem_damage * 0.3)

## Find player ship in scene tree
func _find_player_ship() -> BaseShip:
	# First check ship manager
	if ship_manager and ship_manager.has_method("get_player_ship"):
		var ship = ship_manager.get_player_ship()
		if ship is BaseShip:
			return ship
	
	# Check for player ship in groups
	var player_ships = _get_tree_root().get_nodes_in_group("player_ships")
	for ship in player_ships:
		if ship is BaseShip:
			return ship
	
	# Search for BaseShip with player flag
	var base_ships = _get_tree_root().get_nodes_in_group("ships")
	for ship in base_ships:
		if ship is BaseShip and ship.has_method("is_player_ship") and ship.is_player_ship():
			return ship
	
	return null

## Get tree root safely
func _get_tree_root() -> Node:
	# This is a utility method to get tree root in a safe way
	# In actual implementation, this would need proper tree access
	if Engine.get_main_loop() and Engine.get_main_loop().has_method("get_root"):
		return Engine.get_main_loop().get_root()
	return null

## Get performance statistics
func get_performance_statistics() -> Dictionary:
	return {
		"collection_time_ms": collection_performance_ms,
		"update_frequency": 1.0 / update_interval,
		"last_update_time": data_update_time,
		"data_size": last_ship_data.size()
	}

## Set update frequency for ship data collection
func set_update_frequency(frequency_hz: float) -> void:
	update_interval = 1.0 / max(1.0, frequency_hz)
	print("ShipDataCollector: Update frequency set to %.1f Hz" % frequency_hz)

## Get cached ship data without triggering collection
func get_cached_data() -> Dictionary:
	return last_ship_data.duplicate()

## Check if ship data collector is functional
func is_functional() -> bool:
	return player_ship != null and is_instance_valid(player_ship)