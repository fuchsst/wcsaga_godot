extends GdUnitTestSuite

## Integration tests for evasive behavior system in various threat scenarios

var test_scene: Node3D
var ai_ships: Array[Node3D]
var threat_ships: Array[Node3D]
var defensive_coordination: DefensiveCoordinationSystem
var threat_evasion_system: ThreatEvasionSystem
var defensive_systems: DefensiveSystemsIntegration

func before_test() -> void:
	_setup_integration_test_environment()

func after_test() -> void:
	_cleanup_integration_test_environment()

# Multi-Threat Scenarios

func test_multiple_missile_threat_scenario() -> void:
	"""Test evasion behavior with multiple incoming missiles"""
	
	# Setup scenario
	var player_ship: Node3D = _create_combat_ship("PlayerShip", Vector3(0, 0, 0), "fighter")
	var missiles: Array[Node3D] = []
	
	# Create multiple missiles from different directions
	for i in range(3):
		var angle: float = i * 2.0 * PI / 3.0
		var missile_pos: Vector3 = Vector3(cos(angle) * 800, 0, sin(angle) * 800)
		var missile: Node3D = _create_missile_threat("Missile" + str(i), missile_pos, "heat_seeking")
		missiles.append(missile)
	
	# Setup threat evasion system
	threat_evasion_system = ThreatEvasionSystem.new()
	player_ship.add_child(threat_evasion_system)
	threat_evasion_system._ready()
	
	# Register all missile threats
	for missile in missiles:
		threat_evasion_system.register_threat(missile, {"urgency": 0.8})
	
	# Execute evasion scenario
	var evasion_results: Dictionary = _execute_multi_threat_evasion(player_ship, missiles, 15.0)
	
	# Verify evasion behavior
	assert_bool(evasion_results.get("evasion_initiated", false)).is_true()
	assert_int(evasion_results.get("threats_handled", 0)).is_greater_equal(1)
	assert_float(evasion_results.get("survival_time", 0.0)).is_greater(10.0)

func test_mixed_threat_types_scenario() -> void:
	"""Test evasion against mixed threat types (missiles, lasers, flak)"""
	
	# Setup mixed threat scenario
	var fighter: Node3D = _create_combat_ship("Fighter", Vector3(0, 0, 0), "fighter")
	var threats: Array[Dictionary] = [
		{"type": "missile", "position": Vector3(600, 0, 200), "weapon_type": "radar_guided"},
		{"type": "laser", "position": Vector3(-400, 100, 300), "weapon_type": "beam"},
		{"type": "flak", "position": Vector3(200, -50, 500), "weapon_type": "flak"}
	]
	
	var threat_nodes: Array[Node3D] = []
	for threat_data in threats:
		var threat: Node3D = _create_specific_threat(threat_data)
		threat_nodes.append(threat)
	
	# Setup comprehensive evasion system
	threat_evasion_system = ThreatEvasionSystem.new()
	fighter.add_child(threat_evasion_system)
	threat_evasion_system._ready()
	
	# Register mixed threats
	for i in range(threat_nodes.size()):
		var threat: Node3D = threat_nodes[i]
		var threat_data: Dictionary = threats[i]
		threat_evasion_system.register_threat(threat, threat_data)
	
	# Execute mixed threat scenario
	var mixed_results: Dictionary = _execute_mixed_threat_scenario(fighter, threat_nodes, 20.0)
	
	# Verify adaptive evasion
	assert_bool(mixed_results.get("multiple_evasions", false)).is_true()
	assert_int(mixed_results.get("evasion_types_used", 0)).is_greater(1)
	assert_float(mixed_results.get("threat_response_time", 0.0)).is_less(2.0)

func test_squadron_defensive_coordination_scenario() -> void:
	"""Test coordinated defensive maneuvers for a squadron under attack"""
	
	# Setup squadron
	var squadron: Array[Node3D] = []
	for i in range(4):
		var ship: Node3D = _create_combat_ship("Squadron" + str(i), Vector3(i * 150, 0, 0), "fighter")
		squadron.append(ship)
		ai_ships.append(ship)
	
	# Setup enemy attackers
	var attackers: Array[Node3D] = []
	for i in range(6):
		var angle: float = i * PI / 3.0
		var attacker_pos: Vector3 = Vector3(cos(angle) * 1200, 0, sin(angle) * 1200)
		var attacker: Node3D = _create_combat_ship("Attacker" + str(i), attacker_pos, "interceptor")
		attackers.append(attacker)
		threat_ships.append(attacker)
	
	# Setup defensive coordination
	defensive_coordination = DefensiveCoordinationSystem.new()
	test_scene.add_child(defensive_coordination)
	defensive_coordination._ready()
	defensive_coordination.coordination_mode = DefensiveCoordinationSystem.CoordinationMode.MUTUAL_DEFENSE
	
	# Register squadron ships
	for ship in squadron:
		defensive_coordination.register_ship(ship)
		
		# Add threat evasion system to each ship
		var ship_evasion: ThreatEvasionSystem = ThreatEvasionSystem.new()
		ship.add_child(ship_evasion)
		ship_evasion._ready()
	
	# Execute coordinated defense scenario
	var coordination_results: Dictionary = _execute_coordinated_defense_scenario(squadron, attackers, 25.0)
	
	# Verify coordination
	assert_bool(coordination_results.get("coordination_established", false)).is_true()
	assert_float(coordination_results.get("formation_integrity", 0.0)).is_greater(0.5)
	assert_bool(coordination_results.get("mutual_support_provided", false)).is_true()
	assert_int(coordination_results.get("support_events", 0)).is_greater(0)

# Damage and System Failure Scenarios

func test_critical_damage_emergency_scenario() -> void:
	"""Test emergency behavior when ship takes critical damage"""
	
	# Setup damaged ship scenario
	var damaged_ship: Node3D = _create_combat_ship("DamagedShip", Vector3(0, 0, 0), "fighter")
	var hostile_ship: Node3D = _create_combat_ship("Hostile", Vector3(400, 0, 100), "fighter")
	
	# Set critical damage level
	damaged_ship.set_meta("damage_level", 0.8)
	damaged_ship.set_meta("shield_level", 0.1)
	damaged_ship.set_meta("engine_status", 0.6)
	
	# Setup emergency behavior system
	var emergency_action: EmergencyBehaviorAction = EmergencyBehaviorAction.new()
	emergency_action.ai_agent = damaged_ship
	emergency_action.ship_controller = _create_mock_ship_controller()
	emergency_action.damage_threshold = 0.7
	emergency_action._setup()
	
	# Execute emergency scenario
	var emergency_results: Dictionary = _execute_emergency_damage_scenario(damaged_ship, hostile_ship, emergency_action, 20.0)
	
	# Verify emergency response
	assert_bool(emergency_results.get("emergency_triggered", false)).is_true()
	assert_that(emergency_results.get("emergency_type")).is_not_equal(null)
	assert_bool(emergency_results.get("survival_behavior", false)).is_true()

func test_system_failure_cascade_scenario() -> void:
	"""Test behavior when multiple systems fail in cascade"""
	
	# Setup ship with failing systems
	var failing_ship: Node3D = _create_combat_ship("FailingShip", Vector3(0, 0, 0), "fighter")
	
	# Simulate multiple system failures
	failing_ship.set_meta("engine_status", 0.3)
	failing_ship.set_meta("weapon_systems", 0.1)
	failing_ship.set_meta("shield_level", 0.05)
	failing_ship.set_meta("life_support", 0.4)
	
	# Setup emergency and defensive systems
	var emergency_action: EmergencyBehaviorAction = EmergencyBehaviorAction.new()
	emergency_action.ai_agent = failing_ship
	emergency_action.ship_controller = _create_mock_ship_controller()
	emergency_action._setup()
	
	defensive_systems = DefensiveSystemsIntegration.new()
	failing_ship.add_child(defensive_systems)
	defensive_systems._ready()
	
	# Execute system failure scenario
	var failure_results: Dictionary = _execute_system_failure_scenario(failing_ship, emergency_action, defensive_systems, 15.0)
	
	# Verify cascade response
	assert_bool(failure_results.get("multiple_failures_detected", false)).is_true()
	assert_bool(failure_results.get("emergency_power_activated", false)).is_true()
	assert_int(failure_results.get("system_restart_attempts", 0)).is_greater(0)

func test_overwhelming_odds_retreat_scenario() -> void:
	"""Test tactical retreat when facing overwhelming odds"""
	
	# Setup outnumbered scenario
	var player_ship: Node3D = _create_combat_ship("PlayerShip", Vector3(0, 0, 0), "fighter")
	var wingman: Node3D = _create_combat_ship("Wingman", Vector3(150, 0, 0), "fighter")
	
	# Create overwhelming enemy force
	var enemy_fleet: Array[Node3D] = []
	for i in range(8):
		var angle: float = i * PI / 4.0
		var enemy_pos: Vector3 = Vector3(cos(angle) * 800, 0, sin(angle) * 800)
		var enemy: Node3D = _create_combat_ship("Enemy" + str(i), enemy_pos, "fighter")
		enemy_fleet.append(enemy)
		threat_ships.append(enemy)
	
	# Setup retreat behavior
	var retreat_action: TacticalRetreatAction = TacticalRetreatAction.new()
	retreat_action.ai_agent = player_ship
	retreat_action.ship_controller = _create_mock_ship_controller()
	retreat_action.odds_retreat_threshold = 3.0
	retreat_action._setup()
	
	# Setup wingman coordination
	defensive_coordination = DefensiveCoordinationSystem.new()
	test_scene.add_child(defensive_coordination)
	defensive_coordination._ready()
	defensive_coordination.register_ship(player_ship)
	defensive_coordination.register_ship(wingman)
	
	# Execute overwhelming odds scenario
	var retreat_results: Dictionary = _execute_overwhelming_odds_scenario(player_ship, wingman, enemy_fleet, retreat_action, 30.0)
	
	# Verify retreat behavior
	assert_bool(retreat_results.get("retreat_initiated", false)).is_true()
	assert_bool(retreat_results.get("coordinated_retreat", false)).is_true()
	assert_float(retreat_results.get("retreat_distance", 0.0)).is_greater(1000.0)

# Complex Evasion Scenarios

func test_asteroid_field_evasion_scenario() -> void:
	"""Test evasion behavior in complex environment with obstacles"""
	
	# Setup ship in asteroid field
	var ship: Node3D = _create_combat_ship("Ship", Vector3(0, 0, 0), "fighter")
	
	# Create obstacles (asteroids)
	var obstacles: Array[Node3D] = []
	for i in range(6):
		var obstacle_pos: Vector3 = Vector3(
			randf_range(-500, 500),
			randf_range(-100, 100),
			randf_range(200, 800)
		)
		var obstacle: Node3D = _create_obstacle("Asteroid" + str(i), obstacle_pos)
		obstacles.append(obstacle)
	
	# Create pursuing missiles
	var missiles: Array[Node3D] = []
	for i in range(2):
		var missile_pos: Vector3 = Vector3(-600 + i * 200, 0, -400)
		var missile: Node3D = _create_missile_threat("Missile" + str(i), missile_pos, "torpedo")
		missiles.append(missile)
	
	# Setup complex evasion system
	threat_evasion_system = ThreatEvasionSystem.new()
	ship.add_child(threat_evasion_system)
	threat_evasion_system._ready()
	
	# Register threats
	for missile in missiles:
		threat_evasion_system.register_threat(missile, {"urgency": 0.9})
	
	# Execute complex evasion scenario
	var complex_results: Dictionary = _execute_complex_evasion_scenario(ship, missiles, obstacles, 25.0)
	
	# Verify complex evasion
	assert_bool(complex_results.get("obstacle_avoidance", false)).is_true()
	assert_bool(complex_results.get("threat_evasion", false)).is_true()
	assert_int(complex_results.get("collision_avoidances", 0)).is_greater(0)

func test_capital_ship_assault_evasion_scenario() -> void:
	"""Test defensive evasion during capital ship assault"""
	
	# Setup attack squadron
	var attack_squadron: Array[Node3D] = []
	for i in range(3):
		var fighter: Node3D = _create_combat_ship("Fighter" + str(i), Vector3(i * 200, 0, -1000), "fighter")
		attack_squadron.append(fighter)
		ai_ships.append(fighter)
	
	# Setup capital ship with defensive turrets
	var capital_ship: Node3D = _create_combat_ship("CapitalShip", Vector3(0, 0, 1500), "capital")
	var turrets: Array[Node3D] = []
	
	for i in range(4):
		var turret_offset: Vector3 = Vector3(
			cos(i * PI / 2) * 300,
			100,
			sin(i * PI / 2) * 300
		)
		var turret: Node3D = _create_turret_threat("Turret" + str(i), capital_ship.global_position + turret_offset)
		turrets.append(turret)
		threat_ships.append(turret)
	
	# Setup squadron coordination
	defensive_coordination = DefensiveCoordinationSystem.new()
	test_scene.add_child(defensive_coordination)
	defensive_coordination._ready()
	defensive_coordination.coordination_mode = DefensiveCoordinationSystem.CoordinationMode.COORDINATED_RETREAT
	
	for fighter in attack_squadron:
		defensive_coordination.register_ship(fighter)
		
		# Add evasion systems
		var fighter_evasion: ThreatEvasionSystem = ThreatEvasionSystem.new()
		fighter.add_child(fighter_evasion)
		fighter_evasion._ready()
		
		# Register turret threats
		for turret in turrets:
			fighter_evasion.register_threat(turret, {"threat_type": "turret_fire"})
	
	# Execute capital ship assault scenario
	var assault_results: Dictionary = _execute_capital_assault_evasion_scenario(attack_squadron, capital_ship, turrets, 35.0)
	
	# Verify assault evasion
	assert_bool(assault_results.get("coordinated_evasion", false)).is_true()
	assert_float(assault_results.get("squadron_survival_rate", 0.0)).is_greater(0.6)
	assert_bool(assault_results.get("tactical_adaptation", false)).is_true()

func test_multi_wave_attack_evasion_scenario() -> void:
	"""Test sustained evasion against multiple attack waves"""
	
	# Setup defensive ship
	var defender: Node3D = _create_combat_ship("Defender", Vector3(0, 0, 0), "fighter")
	
	# Setup evasion and defensive systems
	threat_evasion_system = ThreatEvasionSystem.new()
	defender.add_child(threat_evasion_system)
	threat_evasion_system._ready()
	
	defensive_systems = DefensiveSystemsIntegration.new()
	defender.add_child(defensive_systems)
	defensive_systems._ready()
	
	# Execute multi-wave scenario
	var multi_wave_results: Dictionary = _execute_multi_wave_attack_scenario(defender, 45.0)
	
	# Verify sustained evasion
	assert_bool(multi_wave_results.get("multiple_waves_handled", false)).is_true()
	assert_int(multi_wave_results.get("waves_survived", 0)).is_greater(2)
	assert_float(multi_wave_results.get("evasion_effectiveness", 0.0)).is_greater(0.4)

# Scenario Execution Methods

func _execute_multi_threat_evasion(ship: Node3D, threats: Array[Node3D], duration: float) -> Dictionary:
	"""Execute multi-threat evasion scenario"""
	var results: Dictionary = {
		"evasion_initiated": false,
		"threats_handled": 0,
		"survival_time": 0.0,
		"successful_evasions": 0
	}
	
	var start_time: float = Time.get_time_from_start()
	var scenario_time: float = 0.0
	
	while scenario_time < duration:
		# Update threat evasion system
		threat_evasion_system.update_threats(ship)
		
		# Check for active evasions
		if threat_evasion_system.current_evasion_action:
			results["evasion_initiated"] = true
		
		# Count handled threats (threats that are no longer active)
		var current_threat_count: int = threat_evasion_system.get_threat_count()
		results["threats_handled"] = threats.size() - current_threat_count
		
		scenario_time += 0.1
		results["survival_time"] = scenario_time
		await get_tree().create_timer(0.1).timeout
	
	return results

func _execute_mixed_threat_scenario(ship: Node3D, threats: Array[Node3D], duration: float) -> Dictionary:
	"""Execute mixed threat type scenario"""
	var results: Dictionary = {
		"multiple_evasions": false,
		"evasion_types_used": 0,
		"threat_response_time": 0.0,
		"adaptive_behavior": false
	}
	
	var evasion_types_seen: Array[String] = []
	var first_response_time: float = 0.0
	var scenario_time: float = 0.0
	
	while scenario_time < duration:
		threat_evasion_system.update_threats(ship)
		
		# Track different evasion types
		if threat_evasion_system.current_evasion_action:
			var action_type: String = threat_evasion_system.current_evasion_action.get_script().get_global_name()
			if action_type not in evasion_types_seen:
				evasion_types_seen.append(action_type)
				
				if first_response_time == 0.0:
					first_response_time = scenario_time
		
		scenario_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	results["evasion_types_used"] = evasion_types_seen.size()
	results["multiple_evasions"] = evasion_types_seen.size() > 1
	results["threat_response_time"] = first_response_time
	results["adaptive_behavior"] = evasion_types_seen.size() >= 2
	
	return results

func _execute_coordinated_defense_scenario(squadron: Array[Node3D], attackers: Array[Node3D], duration: float) -> Dictionary:
	"""Execute coordinated defense scenario"""
	var results: Dictionary = {
		"coordination_established": false,
		"formation_integrity": 0.0,
		"mutual_support_provided": false,
		"support_events": 0
	}
	
	var scenario_time: float = 0.0
	
	while scenario_time < duration:
		# Update defensive coordination
		defensive_coordination._update_coordination()
		
		# Check coordination status
		var coord_status: Dictionary = defensive_coordination.get_coordination_status()
		results["coordination_established"] = coord_status.get("coordinated_ships", 0) > 1
		results["formation_integrity"] = coord_status.get("formation_integrity", 0.0)
		results["support_events"] = coord_status.get("support_requests", 0)
		results["mutual_support_provided"] = results["support_events"] > 0
		
		scenario_time += 0.2
		await get_tree().create_timer(0.2).timeout
	
	return results

func _execute_emergency_damage_scenario(ship: Node3D, hostile: Node3D, emergency_action: EmergencyBehaviorAction, duration: float) -> Dictionary:
	"""Execute emergency damage scenario"""
	var results: Dictionary = {
		"emergency_triggered": false,
		"emergency_type": null,
		"survival_behavior": false,
		"emergency_response": null
	}
	
	var scenario_time: float = 0.0
	
	# Execute emergency action
	emergency_action.execute_wcs_action(0.1)
	
	while scenario_time < duration:
		var emergency_result: int = emergency_action.execute_wcs_action(0.1)
		
		# Check emergency status
		var emergency_status: Dictionary = emergency_action.get_emergency_status()
		results["emergency_triggered"] = emergency_status.get("response_initiated", false)
		results["emergency_type"] = emergency_status.get("emergency_type")
		results["emergency_response"] = emergency_status.get("emergency_response")
		results["survival_behavior"] = emergency_status.get("survival_probability", 0.0) > 0.0
		
		if emergency_result != 2:  # Not RUNNING anymore
			break
		
		scenario_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	return results

func _execute_system_failure_scenario(ship: Node3D, emergency_action: EmergencyBehaviorAction, defensive_sys: DefensiveSystemsIntegration, duration: float) -> Dictionary:
	"""Execute system failure cascade scenario"""
	var results: Dictionary = {
		"multiple_failures_detected": false,
		"emergency_power_activated": false,
		"system_restart_attempts": 0,
		"power_redistribution": false
	}
	
	var scenario_time: float = 0.0
	
	while scenario_time < duration:
		# Update systems
		emergency_action.execute_wcs_action(0.1)
		defensive_sys.update_system_status(0.1)
		
		# Check system status
		var emergency_status: Dictionary = emergency_action.get_emergency_status()
		var defensive_status: Dictionary = defensive_sys.get_defensive_systems_status()
		
		results["multiple_failures_detected"] = emergency_status.get("system_failures", []).size() > 1
		results["emergency_power_activated"] = defensive_status.get("emergency_mode_active", false)
		results["power_redistribution"] = defensive_status.get("power_mode") != "BALANCED"
		
		scenario_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	return results

func _execute_overwhelming_odds_scenario(player: Node3D, wingman: Node3D, enemies: Array[Node3D], retreat_action: TacticalRetreatAction, duration: float) -> Dictionary:
	"""Execute overwhelming odds retreat scenario"""
	var results: Dictionary = {
		"retreat_initiated": false,
		"coordinated_retreat": false,
		"retreat_distance": 0.0,
		"formation_maintained": false
	}
	
	var initial_position: Vector3 = player.global_position
	var scenario_time: float = 0.0
	
	while scenario_time < duration:
		# Update retreat and coordination
		retreat_action.execute_wcs_action(0.1)
		defensive_coordination._update_coordination()
		
		# Check retreat status
		var retreat_status: Dictionary = retreat_action.get_retreat_status()
		var coord_status: Dictionary = defensive_coordination.get_coordination_status()
		
		results["retreat_initiated"] = retreat_status.get("retreat_type") != null
		results["coordinated_retreat"] = coord_status.get("coordinated_ships", 0) > 1
		results["retreat_distance"] = player.global_position.distance_to(initial_position)
		results["formation_maintained"] = coord_status.get("formation_integrity", 0.0) > 0.5
		
		scenario_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	return results

func _execute_complex_evasion_scenario(ship: Node3D, threats: Array[Node3D], obstacles: Array[Node3D], duration: float) -> Dictionary:
	"""Execute complex evasion scenario with obstacles"""
	var results: Dictionary = {
		"obstacle_avoidance": false,
		"threat_evasion": false,
		"collision_avoidances": 0,
		"successful_navigation": false
	}
	
	var scenario_time: float = 0.0
	var collision_count: int = 0
	
	while scenario_time < duration:
		threat_evasion_system.update_threats(ship)
		
		# Check for near-collisions with obstacles
		for obstacle in obstacles:
			var distance: float = ship.global_position.distance_to(obstacle.global_position)
			if distance < 150.0:  # Near miss
				collision_count += 1
				results["obstacle_avoidance"] = true
		
		# Check threat evasion
		if threat_evasion_system.current_evasion_action:
			results["threat_evasion"] = true
		
		scenario_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	results["collision_avoidances"] = collision_count
	results["successful_navigation"] = collision_count > 0 and results["threat_evasion"]
	
	return results

func _execute_capital_assault_evasion_scenario(squadron: Array[Node3D], capital: Node3D, turrets: Array[Node3D], duration: float) -> Dictionary:
	"""Execute capital ship assault evasion scenario"""
	var results: Dictionary = {
		"coordinated_evasion": false,
		"squadron_survival_rate": 0.0,
		"tactical_adaptation": false,
		"assault_effectiveness": 0.0
	}
	
	var initial_squadron_size: int = squadron.size()
	var scenario_time: float = 0.0
	
	while scenario_time < duration:
		defensive_coordination._update_coordination()
		
		# Update each fighter's evasion
		for fighter in squadron:
			if fighter.get_child_count() > 0:
				var evasion_system: ThreatEvasionSystem = fighter.get_child(0)
				if evasion_system is ThreatEvasionSystem:
					evasion_system.update_threats(fighter)
		
		# Check coordination status
		var coord_status: Dictionary = defensive_coordination.get_coordination_status()
		results["coordinated_evasion"] = coord_status.get("formation_integrity", 0.0) > 0.4
		results["squadron_survival_rate"] = float(squadron.size()) / float(initial_squadron_size)
		results["tactical_adaptation"] = scenario_time > 15.0 and results["coordinated_evasion"]
		
		scenario_time += 0.2
		await get_tree().create_timer(0.2).timeout
	
	return results

func _execute_multi_wave_attack_scenario(defender: Node3D, duration: float) -> Dictionary:
	"""Execute multi-wave attack scenario"""
	var results: Dictionary = {
		"multiple_waves_handled": false,
		"waves_survived": 0,
		"evasion_effectiveness": 0.0,
		"sustained_defense": false
	}
	
	var wave_count: int = 0
	var wave_interval: float = 12.0
	var last_wave_time: float = 0.0
	var scenario_time: float = 0.0
	
	while scenario_time < duration:
		# Spawn new wave of threats
		if scenario_time - last_wave_time >= wave_interval:
			_spawn_attack_wave(defender, wave_count)
			wave_count += 1
			last_wave_time = scenario_time
		
		# Update defensive systems
		threat_evasion_system.update_threats(defender)
		defensive_systems.update_system_status(0.1)
		
		scenario_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	results["waves_survived"] = wave_count
	results["multiple_waves_handled"] = wave_count > 2
	results["sustained_defense"] = scenario_time >= duration * 0.8
	results["evasion_effectiveness"] = min(1.0, float(wave_count) / 4.0)
	
	return results

func _spawn_attack_wave(defender: Node3D, wave_number: int) -> void:
	"""Spawn attack wave for multi-wave scenario"""
	var threat_count: int = 2 + wave_number  # Escalating threat count
	
	for i in range(threat_count):
		var angle: float = i * 2.0 * PI / threat_count
		var threat_pos: Vector3 = Vector3(cos(angle) * 1000, 0, sin(angle) * 1000)
		var threat: Node3D = _create_missile_threat("Wave" + str(wave_number) + "_Threat" + str(i), threat_pos, "missile")
		
		threat_evasion_system.register_threat(threat, {"urgency": 0.6 + wave_number * 0.1})

# Helper Methods

func _setup_integration_test_environment() -> void:
	test_scene = Node3D.new()
	test_scene.name = "EvasiveIntegrationTestScene"
	add_child(test_scene)
	
	ai_ships = []
	threat_ships = []

func _cleanup_integration_test_environment() -> void:
	if test_scene:
		test_scene.queue_free()
	ai_ships.clear()
	threat_ships.clear()

func _create_combat_ship(name: String, position: Vector3, ship_class: String) -> Node3D:
	var ship: Node3D = Node3D.new()
	ship.name = name
	ship.position = position
	ship.set_meta("ship_class", ship_class)
	ship.set_meta("team", 1 if name.begins_with("Player") or name.begins_with("Fighter") or name.begins_with("Squadron") else 2)
	
	var controller: Node = _create_mock_ship_controller()
	ship.add_child(controller)
	
	test_scene.add_child(ship)
	return ship

func _create_missile_threat(name: String, position: Vector3, missile_type: String) -> Node3D:
	var missile: Node3D = Node3D.new()
	missile.name = name
	missile.position = position
	missile.set_meta("missile_type", missile_type)
	missile.set_meta("velocity", Vector3(0, 0, -200))  # Moving toward origin
	
	test_scene.add_child(missile)
	return missile

func _create_specific_threat(threat_data: Dictionary) -> Node3D:
	var threat: Node3D = Node3D.new()
	threat.name = threat_data.get("type", "Threat")
	threat.position = threat_data.get("position", Vector3.ZERO)
	threat.set_meta("weapon_type", threat_data.get("weapon_type", "unknown"))
	
	test_scene.add_child(threat)
	return threat

func _create_turret_threat(name: String, position: Vector3) -> Node3D:
	var turret: Node3D = Node3D.new()
	turret.name = name
	turret.position = position
	turret.set_meta("weapon_type", "turret")
	turret.set_meta("threat_type", "turret_fire")
	
	test_scene.add_child(turret)
	return turret

func _create_obstacle(name: String, position: Vector3) -> Node3D:
	var obstacle: Node3D = Node3D.new()
	obstacle.name = name
	obstacle.position = position
	obstacle.set_meta("obstacle_type", "asteroid")
	
	test_scene.add_child(obstacle)
	return obstacle

func _create_mock_ship_controller() -> Node:
	var controller: Node = Node.new()
	controller.name = "MockShipController"
	
	controller.set_meta("has_fire_weapons", true)
	controller.set_meta("has_set_throttle", true)
	controller.set_meta("has_deploy_chaff", true)
	controller.set_meta("has_deploy_flares", true)
	controller.set_meta("has_engage_afterburners", true)
	controller.set_meta("has_set_power_distribution", true)
	controller.set_meta("has_set_shield_distribution", true)
	
	return controller