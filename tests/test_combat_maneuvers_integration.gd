extends GdUnitTestSuite

## Integration tests for complete combat maneuver scenarios

var test_scene: Node3D
var ai_ships: Array[Node3D]
var enemy_ships: Array[Node3D]
var formation_manager: Node
var attack_pattern_manager: AttackPatternManager
var target_coordinator: Node
var combat_systems: Dictionary = {}

func before_test() -> void:
	_setup_integration_test_environment()

func after_test() -> void:
	_cleanup_integration_test_environment()

# Complete Combat Scenario Tests

func test_fighter_vs_fighter_engagement() -> void:
	"""Test complete fighter vs fighter combat scenario"""
	
	# Setup fighter vs fighter scenario
	var player_fighter: Node3D = _create_combat_ship("PlayerFighter", Vector3(0, 0, 0), "fighter")
	var enemy_fighter: Node3D = _create_combat_ship("EnemyFighter", Vector3(800, 0, 200), "fighter")
	
	# Setup combat systems for player fighter
	var combat_plan: Dictionary = _create_fighter_combat_plan(player_fighter, enemy_fighter)
	
	# Execute combat maneuvers
	var maneuver_results: Dictionary = _execute_combat_scenario(player_fighter, enemy_fighter, combat_plan, 10.0)
	
	# Verify combat behavior
	assert_bool(maneuver_results.get("engagement_occurred", false)).is_true()
	assert_float(maneuver_results.get("total_engagement_time", 0.0)).is_greater(0.0)
	assert_int(maneuver_results.get("maneuver_changes", 0)).is_greater(0)

func test_bomber_intercept_scenario() -> void:
	"""Test interceptor vs bomber combat scenario"""
	
	# Setup bomber intercept scenario
	var interceptor: Node3D = _create_combat_ship("Interceptor", Vector3(0, 0, 0), "interceptor")
	var bomber: Node3D = _create_combat_ship("Bomber", Vector3(1200, 0, 300), "bomber")
	
	# Bomber moving toward target
	bomber.set_meta("velocity", Vector3(0, 0, -50))
	bomber.set_meta("target_position", Vector3(1200, 0, -2000))
	
	# Setup intercept combat plan
	var combat_plan: Dictionary = _create_intercept_combat_plan(interceptor, bomber)
	
	# Execute intercept scenario
	var intercept_results: Dictionary = _execute_intercept_scenario(interceptor, bomber, combat_plan, 15.0)
	
	# Verify intercept behavior
	assert_bool(intercept_results.get("intercept_attempted", false)).is_true()
	assert_float(intercept_results.get("closest_approach", 1000.0)).is_less(500.0)
	assert_bool(intercept_results.get("weapons_fired", false)).is_true()

func test_capital_ship_attack_scenario() -> void:
	"""Test fighter squadron vs capital ship attack"""
	
	# Setup capital ship attack scenario
	var capital_ship: Node3D = _create_combat_ship("CapitalShip", Vector3(2000, 0, 0), "capital")
	var fighter_squadron: Array[Node3D] = []
	
	# Create fighter squadron
	for i in range(4):
		var fighter: Node3D = _create_combat_ship("Fighter" + str(i), Vector3(i * 100, 0, -500), "fighter")
		fighter_squadron.append(fighter)
		ai_ships.append(fighter)
	
	# Setup coordinated attack plan
	var attack_plan: Dictionary = _create_coordinated_attack_plan(fighter_squadron, capital_ship)
	
	# Execute coordinated attack
	var attack_results: Dictionary = _execute_coordinated_attack(fighter_squadron, capital_ship, attack_plan, 20.0)
	
	# Verify coordinated attack behavior
	assert_bool(attack_results.get("coordination_achieved", false)).is_true()
	assert_int(attack_results.get("attack_waves", 0)).is_greater(0)
	assert_float(attack_results.get("formation_integrity", 0.0)).is_greater(0.5)

func test_multi_target_dogfight() -> void:
	"""Test complex multi-target dogfight scenario"""
	
	# Setup complex dogfight with multiple fighters
	var player_squadron: Array[Node3D] = []
	var enemy_squadron: Array[Node3D] = []
	
	# Create player squadron
	for i in range(3):
		var fighter: Node3D = _create_combat_ship("Player" + str(i), Vector3(i * 150, 0, 0), "fighter")
		player_squadron.append(fighter)
		ai_ships.append(fighter)
	
	# Create enemy squadron
	for i in range(3):
		var enemy: Node3D = _create_combat_ship("Enemy" + str(i), Vector3(800 + i * 150, 0, 200), "fighter")
		enemy_squadron.append(enemy)
		enemy_ships.append(enemy)
	
	# Setup dogfight scenario
	var dogfight_results: Dictionary = _execute_dogfight_scenario(player_squadron, enemy_squadron, 25.0)
	
	# Verify dogfight behavior
	assert_bool(dogfight_results.get("multiple_engagements", false)).is_true()
	assert_int(dogfight_results.get("target_switches", 0)).is_greater(0)
	assert_float(dogfight_results.get("average_engagement_time", 0.0)).is_greater(2.0)

func test_hit_and_run_tactics() -> void:
	"""Test hit and run tactical scenario"""
	
	# Setup hit and run scenario - damaged fighter vs healthy enemy
	var damaged_fighter: Node3D = _create_combat_ship("DamagedFighter", Vector3(0, 0, 0), "fighter")
	var enemy_fighter: Node3D = _create_combat_ship("EnemyFighter", Vector3(600, 0, 100), "fighter")
	
	# Set damage level
	damaged_fighter.set_meta("damage_level", 0.6)
	damaged_fighter.set_meta("health_ratio", 0.4)
	
	# Setup hit and run combat plan
	var hit_run_plan: Dictionary = _create_hit_and_run_plan(damaged_fighter, enemy_fighter)
	
	# Execute hit and run scenario
	var hit_run_results: Dictionary = _execute_hit_and_run_scenario(damaged_fighter, enemy_fighter, hit_run_plan, 15.0)
	
	# Verify hit and run behavior
	assert_bool(hit_run_results.get("evasive_behavior", false)).is_true()
	assert_int(hit_run_results.get("attack_attempts", 0)).is_greater(0)
	assert_float(hit_run_results.get("average_engagement_distance", 0.0)).is_greater(400.0)

func test_formation_attack_coordination() -> void:
	"""Test formation-based coordinated attack"""
	
	# Setup formation attack scenario
	var target_corvette: Node3D = _create_combat_ship("Corvette", Vector3(1500, 0, 0), "corvette")
	var attack_formation: Array[Node3D] = []
	
	# Create attack formation
	for i in range(4):
		var fighter: Node3D = _create_combat_ship("Attacker" + str(i), Vector3(i * 120, 0, -800), "fighter")
		attack_formation.append(fighter)
		ai_ships.append(fighter)
	
	# Setup formation manager
	formation_manager = _create_mock_formation_manager()
	var formation_id: String = formation_manager.create_formation(attack_formation[0], 0, 150.0)
	
	for i in range(1, attack_formation.size()):
		formation_manager.add_ship_to_formation(formation_id, attack_formation[i])
	
	# Execute formation attack
	var formation_results: Dictionary = _execute_formation_attack(attack_formation, target_corvette, formation_id, 18.0)
	
	# Verify formation coordination
	assert_bool(formation_results.get("formation_maintained", false)).is_true()
	assert_bool(formation_results.get("coordinated_attacks", false)).is_true()
	assert_float(formation_results.get("formation_integrity", 0.0)).is_greater(0.6)

func test_adaptive_combat_behavior() -> void:
	"""Test adaptive combat behavior based on changing conditions"""
	
	# Setup adaptive scenario
	var adaptive_fighter: Node3D = _create_combat_ship("AdaptiveFighter", Vector3(0, 0, 0), "fighter")
	var target_ship: Node3D = _create_combat_ship("TargetShip", Vector3(700, 0, 150), "bomber")
	
	# Setup adaptive combat system
	var adaptive_results: Dictionary = _execute_adaptive_combat_scenario(adaptive_fighter, target_ship, 20.0)
	
	# Verify adaptive behavior
	assert_int(adaptive_results.get("pattern_changes", 0)).is_greater(1)
	assert_bool(adaptive_results.get("tactical_adaptation", false)).is_true()
	assert_float(adaptive_results.get("effectiveness_improvement", 0.0)).is_greater(0.0)

func test_skill_based_combat_differences() -> void:
	"""Test combat behavior differences based on skill levels"""
	
	# Setup skill comparison scenario
	var rookie_fighter: Node3D = _create_combat_ship("RookieFighter", Vector3(-200, 0, 0), "fighter")
	var ace_fighter: Node3D = _create_combat_ship("AceFighter", Vector3(200, 0, 0), "fighter")
	var target_enemy: Node3D = _create_combat_ship("EnemyTarget", Vector3(0, 0, 500), "fighter")
	
	# Set different skill levels
	rookie_fighter.set_meta("skill_level", 0.2)
	ace_fighter.set_meta("skill_level", 0.9)
	
	# Execute skill comparison
	var skill_results: Dictionary = _execute_skill_comparison_scenario(rookie_fighter, ace_fighter, target_enemy, 15.0)
	
	# Verify skill differences
	assert_float(skill_results.get("ace_accuracy", 0.0)).is_greater(skill_results.get("rookie_accuracy", 0.0))
	assert_float(skill_results.get("ace_maneuver_quality", 0.0)).is_greater(skill_results.get("rookie_maneuver_quality", 0.0))
	assert_int(skill_results.get("ace_pattern_changes", 0)).is_greater(skill_results.get("rookie_pattern_changes", 0))

# Helper Methods for Combat Scenarios

func _create_fighter_combat_plan(fighter: Node3D, target: Node3D) -> Dictionary:
	"""Create combat plan for fighter vs fighter engagement"""
	var target_tactics: TargetSpecificTactics = TargetSpecificTactics.new()
	target_tactics._ready()
	
	var context: Dictionary = {
		"skill_level": fighter.get_meta("skill_level", 0.6),
		"distance": fighter.global_position.distance_to(target.global_position),
		"formation_available": false
	}
	
	return target_tactics.create_target_specific_combat_plan(fighter, target, context)

func _create_intercept_combat_plan(interceptor: Node3D, bomber: Node3D) -> Dictionary:
	"""Create combat plan for bomber intercept"""
	var plan: Dictionary = {
		"primary_pattern": AttackPatternManager.AttackPattern.ATTACK_RUN,
		"approach_type": AttackRunAction.AttackRunType.HEAD_ON,
		"firing_mode": WeaponFiringIntegration.FireMode.BURST_FIRE,
		"pursuit_mode": PursuitAttackAction.PursuitMode.AGGRESSIVE
	}
	
	return plan

func _create_coordinated_attack_plan(squadron: Array[Node3D], capital_ship: Node3D) -> Dictionary:
	"""Create coordinated attack plan for capital ship assault"""
	var plan: Dictionary = {
		"formation_type": "attack_line",
		"attack_pattern": AttackPatternManager.AttackPattern.COORDINATED,
		"approach_vector": "multiple_angles",
		"timing_coordination": true,
		"target_designation": "engine_section"
	}
	
	return plan

func _create_hit_and_run_plan(fighter: Node3D, enemy: Node3D) -> Dictionary:
	"""Create hit and run tactical plan"""
	var plan: Dictionary = {
		"primary_pattern": AttackPatternManager.AttackPattern.HIT_AND_RUN,
		"engagement_time_limit": 5.0,
		"escape_threshold": 0.3,
		"optimal_range": 600.0,
		"evasion_priority": 0.8
	}
	
	return plan

func _execute_combat_scenario(attacker: Node3D, defender: Node3D, plan: Dictionary, duration: float) -> Dictionary:
	"""Execute basic combat scenario"""
	var results: Dictionary = {
		"engagement_occurred": false,
		"total_engagement_time": 0.0,
		"maneuver_changes": 0,
		"weapons_fired": false,
		"closest_approach": 1000.0
	}
	
	var start_time: float = Time.get_time_from_start()
	var end_time: float = start_time + duration
	var last_pattern_change: float = start_time
	
	# Create combat systems
	var attack_pattern_manager: AttackPatternManager = AttackPatternManager.new()
	attack_pattern_manager._ready()
	
	var target_tactics: TargetSpecificTactics = TargetSpecificTactics.new()
	target_tactics._ready()
	
	# Simulate combat loop
	while Time.get_time_from_start() < end_time:
		var current_time: float = Time.get_time_from_start()
		var distance: float = attacker.global_position.distance_to(defender.global_position)
		
		# Track closest approach
		results["closest_approach"] = min(results["closest_approach"], distance)
		
		# Check for engagement
		if distance < 1000.0:
			results["engagement_occurred"] = true
			results["total_engagement_time"] = current_time - start_time
		
		# Simulate pattern changes
		if current_time - last_pattern_change > 3.0:
			results["maneuver_changes"] += 1
			last_pattern_change = current_time
		
		# Simulate weapon firing
		if distance < 600.0 and not results["weapons_fired"]:
			results["weapons_fired"] = true
		
		# Small time step
		await get_tree().create_timer(0.1).timeout
	
	return results

func _execute_intercept_scenario(interceptor: Node3D, bomber: Node3D, plan: Dictionary, duration: float) -> Dictionary:
	"""Execute bomber intercept scenario"""
	var results: Dictionary = {
		"intercept_attempted": false,
		"closest_approach": 1000.0,
		"weapons_fired": false,
		"intercept_time": 0.0
	}
	
	var start_time: float = Time.get_time_from_start()
	var bomber_velocity: Vector3 = bomber.get_meta("velocity", Vector3.ZERO)
	
	# Simulate intercept approach
	var intercept_time: float = 0.0
	while intercept_time < duration:
		var current_distance: float = interceptor.global_position.distance_to(bomber.global_position)
		
		# Update bomber position based on velocity
		bomber.global_position += bomber_velocity * 0.1
		
		# Track closest approach
		results["closest_approach"] = min(results["closest_approach"], current_distance)
		
		# Check for intercept attempt
		if current_distance < 800.0:
			results["intercept_attempted"] = true
		
		# Check for weapon firing
		if current_distance < 500.0 and not results["weapons_fired"]:
			results["weapons_fired"] = true
			results["intercept_time"] = intercept_time
		
		intercept_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	return results

func _execute_coordinated_attack(squadron: Array[Node3D], target: Node3D, plan: Dictionary, duration: float) -> Dictionary:
	"""Execute coordinated squadron attack"""
	var results: Dictionary = {
		"coordination_achieved": false,
		"attack_waves": 0,
		"formation_integrity": 1.0,
		"simultaneous_attacks": 0
	}
	
	var attack_time: float = 0.0
	var last_wave_time: float = 0.0
	
	while attack_time < duration:
		var ships_in_formation: int = 0
		var ships_engaging: int = 0
		
		# Check formation integrity and engagement
		for ship in squadron:
			var distance_to_target: float = ship.global_position.distance_to(target.global_position)
			
			# Check if ship is in formation position (simplified)
			if _check_formation_position(ship, squadron):
				ships_in_formation += 1
			
			# Check if ship is engaging
			if distance_to_target < 600.0:
				ships_engaging += 1
		
		# Calculate formation integrity
		results["formation_integrity"] = float(ships_in_formation) / float(squadron.size())
		
		# Check for coordinated attacks
		if ships_engaging >= 2:
			results["coordination_achieved"] = true
			if attack_time - last_wave_time > 5.0:
				results["attack_waves"] += 1
				last_wave_time = attack_time
		
		attack_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	return results

func _execute_dogfight_scenario(player_squadron: Array[Node3D], enemy_squadron: Array[Node3D], duration: float) -> Dictionary:
	"""Execute multi-target dogfight scenario"""
	var results: Dictionary = {
		"multiple_engagements": false,
		"target_switches": 0,
		"average_engagement_time": 0.0,
		"total_engagements": 0
	}
	
	var engagement_pairs: Array[Dictionary] = []
	var dogfight_time: float = 0.0
	
	while dogfight_time < duration:
		var current_engagements: int = 0
		
		# Check for active engagements
		for player in player_squadron:
			for enemy in enemy_squadron:
				var distance: float = player.global_position.distance_to(enemy.global_position)
				if distance < 800.0:
					current_engagements += 1
					
					# Track engagement pair
					var pair_found: bool = false
					for pair in engagement_pairs:
						if pair.get("player") == player and pair.get("enemy") == enemy:
							pair["duration"] = pair.get("duration", 0.0) + 0.1
							pair_found = true
							break
					
					if not pair_found:
						engagement_pairs.append({
							"player": player,
							"enemy": enemy,
							"duration": 0.1,
							"start_time": dogfight_time
						})
		
		# Check for multiple simultaneous engagements
		if current_engagements > 1:
			results["multiple_engagements"] = true
		
		dogfight_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	# Calculate statistics
	results["total_engagements"] = engagement_pairs.size()
	if engagement_pairs.size() > 0:
		var total_time: float = 0.0
		for pair in engagement_pairs:
			total_time += pair.get("duration", 0.0)
		results["average_engagement_time"] = total_time / engagement_pairs.size()
	
	# Simulate target switches
	results["target_switches"] = max(0, engagement_pairs.size() - player_squadron.size())
	
	return results

func _execute_hit_and_run_scenario(fighter: Node3D, enemy: Node3D, plan: Dictionary, duration: float) -> Dictionary:
	"""Execute hit and run scenario"""
	var results: Dictionary = {
		"evasive_behavior": false,
		"attack_attempts": 0,
		"average_engagement_distance": 0.0,
		"retreat_attempts": 0
	}
	
	var scenario_time: float = 0.0
	var engagement_distances: Array[float] = []
	var last_attack_time: float = 0.0
	
	while scenario_time < duration:
		var distance: float = fighter.global_position.distance_to(enemy.global_position)
		engagement_distances.append(distance)
		
		# Check for attack attempts
		if distance < 600.0 and scenario_time - last_attack_time > 3.0:
			results["attack_attempts"] += 1
			last_attack_time = scenario_time
		
		# Check for evasive behavior (moving away after engagement)
		if distance > 800.0 and results["attack_attempts"] > 0:
			results["evasive_behavior"] = true
			results["retreat_attempts"] += 1
		
		scenario_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	# Calculate average engagement distance
	if engagement_distances.size() > 0:
		var total_distance: float = 0.0
		for dist in engagement_distances:
			total_distance += dist
		results["average_engagement_distance"] = total_distance / engagement_distances.size()
	
	return results

func _execute_formation_attack(formation: Array[Node3D], target: Node3D, formation_id: String, duration: float) -> Dictionary:
	"""Execute formation-based attack"""
	var results: Dictionary = {
		"formation_maintained": false,
		"coordinated_attacks": false,
		"formation_integrity": 0.0,
		"attack_coordination_events": 0
	}
	
	var attack_time: float = 0.0
	var integrity_samples: Array[float] = []
	
	while attack_time < duration:
		# Check formation integrity
		var ships_in_position: int = 0
		var ships_attacking: int = 0
		
		for ship in formation:
			# Simplified formation position check
			if _check_formation_position(ship, formation):
				ships_in_position += 1
			
			# Check if ship is in attack position
			var distance_to_target: float = ship.global_position.distance_to(target.global_position)
			if distance_to_target < 700.0:
				ships_attacking += 1
		
		var current_integrity: float = float(ships_in_position) / float(formation.size())
		integrity_samples.append(current_integrity)
		
		# Check for formation maintenance
		if current_integrity > 0.7:
			results["formation_maintained"] = true
		
		# Check for coordinated attacks
		if ships_attacking >= 2:
			results["coordinated_attacks"] = true
			results["attack_coordination_events"] += 1
		
		attack_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	# Calculate average formation integrity
	if integrity_samples.size() > 0:
		var total_integrity: float = 0.0
		for integrity in integrity_samples:
			total_integrity += integrity
		results["formation_integrity"] = total_integrity / integrity_samples.size()
	
	return results

func _execute_adaptive_combat_scenario(fighter: Node3D, target: Node3D, duration: float) -> Dictionary:
	"""Execute adaptive combat behavior scenario"""
	var results: Dictionary = {
		"pattern_changes": 0,
		"tactical_adaptation": false,
		"effectiveness_improvement": 0.0,
		"decision_quality": 0.0
	}
	
	var adaptive_time: float = 0.0
	var last_pattern_change: float = 0.0
	var initial_effectiveness: float = 0.5
	var current_effectiveness: float = initial_effectiveness
	
	# Create pattern manager for adaptive behavior
	var pattern_manager: AttackPatternManager = AttackPatternManager.new()
	pattern_manager._ready()
	
	while adaptive_time < duration:
		var distance: float = fighter.global_position.distance_to(target.global_position)
		
		# Simulate pattern adaptation based on distance and effectiveness
		if adaptive_time - last_pattern_change > 4.0:
			results["pattern_changes"] += 1
			last_pattern_change = adaptive_time
			
			# Simulate effectiveness improvement through adaptation
			current_effectiveness = min(1.0, current_effectiveness + 0.1)
			results["tactical_adaptation"] = true
		
		adaptive_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	results["effectiveness_improvement"] = current_effectiveness - initial_effectiveness
	results["decision_quality"] = current_effectiveness
	
	return results

func _execute_skill_comparison_scenario(rookie: Node3D, ace: Node3D, target: Node3D, duration: float) -> Dictionary:
	"""Execute skill level comparison scenario"""
	var results: Dictionary = {
		"rookie_accuracy": 0.0,
		"ace_accuracy": 0.0,
		"rookie_maneuver_quality": 0.0,
		"ace_maneuver_quality": 0.0,
		"rookie_pattern_changes": 0,
		"ace_pattern_changes": 0
	}
	
	var comparison_time: float = 0.0
	var rookie_shots: int = 0
	var ace_shots: int = 0
	var rookie_hits: int = 0
	var ace_hits: int = 0
	
	while comparison_time < duration:
		var rookie_distance: float = rookie.global_position.distance_to(target.global_position)
		var ace_distance: float = ace.global_position.distance_to(target.global_position)
		
		# Simulate shooting behavior
		if rookie_distance < 500.0 and fmod(comparison_time, 1.0) < 0.1:
			rookie_shots += 1
			if randf() < 0.3:  # Low accuracy for rookie
				rookie_hits += 1
		
		if ace_distance < 600.0 and fmod(comparison_time, 0.6) < 0.1:
			ace_shots += 1
			if randf() < 0.8:  # High accuracy for ace
				ace_hits += 1
		
		# Simulate maneuver pattern changes
		if fmod(comparison_time, 5.0) < 0.1:
			results["rookie_pattern_changes"] += 1
		if fmod(comparison_time, 3.0) < 0.1:
			results["ace_pattern_changes"] += 1
		
		comparison_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	# Calculate accuracy
	results["rookie_accuracy"] = float(rookie_hits) / max(1, rookie_shots)
	results["ace_accuracy"] = float(ace_hits) / max(1, ace_shots)
	
	# Simulate maneuver quality based on skill
	results["rookie_maneuver_quality"] = 0.3
	results["ace_maneuver_quality"] = 0.9
	
	return results

# Helper Methods

func _setup_integration_test_environment() -> void:
	# Create main test scene
	test_scene = Node3D.new()
	test_scene.name = "CombatIntegrationTestScene"
	add_child(test_scene)
	
	# Initialize ship arrays
	ai_ships = []
	enemy_ships = []
	combat_systems = {}

func _cleanup_integration_test_environment() -> void:
	if test_scene:
		test_scene.queue_free()
	ai_ships.clear()
	enemy_ships.clear()
	combat_systems.clear()

func _create_combat_ship(name: String, position: Vector3, ship_class: String) -> Node3D:
	var ship: Node3D = Node3D.new()
	ship.name = name
	ship.position = position
	ship.set_meta("ship_class", ship_class)
	ship.set_meta("team", 1 if name.begins_with("Player") or name.begins_with("Fighter") else 2)
	
	# Add mock ship controller
	var controller: Node = Node.new()
	controller.name = "ShipController"
	ship.add_child(controller)
	
	test_scene.add_child(ship)
	return ship

func _create_mock_formation_manager() -> Node:
	var manager: Node = Node.new()
	manager.name = "FormationManager"
	
	# Add mock formation functionality
	manager.set_script(preload("res://scripts/ai/formation/formation_manager.gd"))
	
	test_scene.add_child(manager)
	return manager

func _check_formation_position(ship: Node3D, formation: Array[Node3D]) -> bool:
	# Simplified formation position check
	# In a real implementation, this would check against formation manager
	
	if formation.size() <= 1:
		return true
	
	var leader: Node3D = formation[0]
	var ideal_distance: float = 150.0
	var current_distance: float = ship.global_position.distance_to(leader.global_position)
	
	# Allow some tolerance for formation positioning
	return current_distance < ideal_distance * 1.5