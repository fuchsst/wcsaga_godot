extends GdUnitTestSuite

## Unit tests for ConserveAmmoAction ammunition and energy conservation behavior
## Tests resource management, conservation strategies, and tactical situation adaptation

class_name TestConserveAmmoAction

var conserve_ammo_action: ConserveAmmoAction
var mock_ship_controller: MockShipController
var mock_ai_agent: MockAIAgent
var mock_target: MockTarget

func before_test():
	conserve_ammo_action = ConserveAmmoAction.new()
	mock_ship_controller = MockShipController.new()
	mock_ai_agent = MockAIAgent.new()
	mock_target = MockTarget.new()
	
	# Setup mocks
	conserve_ammo_action.ship_controller = mock_ship_controller
	conserve_ammo_action.ai_agent = mock_ai_agent
	conserve_ammo_action._setup()

func after_test():
	conserve_ammo_action = null
	mock_ship_controller = null
	mock_ai_agent = null
	mock_target = null

func test_conservation_action_initialization():
	assert_that(conserve_ammo_action.conservation_mode).is_equal(ConserveAmmoAction.ConservationMode.OPTIMAL_USAGE)
	assert_that(conserve_ammo_action.target_resource).is_equal(ConserveAmmoAction.ResourceType.ALL_RESOURCES)
	assert_that(conserve_ammo_action.ammo_reserve_percentage).is_equal(0.2)
	assert_that(conserve_ammo_action.conservation_thresholds).is_not_empty()

func test_conservation_thresholds_setup():
	# Test optimal usage thresholds
	conserve_ammo_action.conservation_mode = ConserveAmmoAction.ConservationMode.OPTIMAL_USAGE
	conserve_ammo_action._setup_conservation_thresholds()
	
	assert_that(conserve_ammo_action.conservation_thresholds[ConserveAmmoAction.ResourceType.AMMUNITION]).is_equal(0.3)
	assert_that(conserve_ammo_action.conservation_thresholds[ConserveAmmoAction.ResourceType.ENERGY]).is_equal(0.2)
	
	# Test emergency reserve thresholds
	conserve_ammo_action.conservation_mode = ConserveAmmoAction.ConservationMode.EMERGENCY_RESERVE
	conserve_ammo_action._setup_conservation_thresholds()
	
	assert_that(conserve_ammo_action.conservation_thresholds[ConserveAmmoAction.ResourceType.AMMUNITION]).is_equal(0.6)
	assert_that(conserve_ammo_action.conservation_thresholds[ConserveAmmoAction.ResourceType.ENERGY]).is_equal(0.4)

func test_resource_level_tracking():
	# Setup mock resource levels
	mock_ship_controller.set_energy_level(0.8)
	mock_ship_controller.set_weapon_ammo(2, 15)  # Missiles
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	mock_ship_controller.set_weapon_ammo(3, 6)   # Torpedoes
	mock_ship_controller.set_weapon_max_ammo(3, 8)
	
	conserve_ammo_action._update_resource_levels()
	
	var ammo_level = conserve_ammo_action.resource_levels[ConserveAmmoAction.ResourceType.AMMUNITION]
	var energy_level = conserve_ammo_action.resource_levels[ConserveAmmoAction.ResourceType.ENERGY]
	
	assert_that(energy_level).is_equal(0.8)
	assert_that(ammo_level).is_greater(0.7)  # Should be weighted average of missile+torpedo ammo

func test_total_ammunition_level_calculation():
	# Setup multiple weapon groups with ammunition
	mock_ship_controller.set_weapon_ammo(2, 10)  # Missiles: 10/20 = 0.5
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	mock_ship_controller.set_weapon_ammo(3, 4)   # Torpedoes: 4/8 = 0.5
	mock_ship_controller.set_weapon_max_ammo(3, 8)
	mock_ship_controller.set_weapon_ammo(4, 6)   # Bombs: 6/12 = 0.5
	mock_ship_controller.set_weapon_max_ammo(4, 12)
	
	var total_ammo_level = conserve_ammo_action._get_total_ammunition_level()
	
	# Should be 0.5 (20 out of 40 total ammo)
	assert_that(total_ammo_level).is_approximately(0.5, 0.1)

func test_threshold_breach_detection():
	# Setup low ammunition scenario
	mock_ship_controller.set_weapon_ammo(2, 2)   # Very low missiles
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	mock_ship_controller.set_energy_level(0.15)  # Low energy
	
	# Set conservative thresholds
	conserve_ammo_action.conservation_mode = ConserveAmmoAction.ConservationMode.OPTIMAL_USAGE
	conserve_ammo_action._setup_conservation_thresholds()
	
	# Connect to threshold signals
	var threshold_reached_fired = false
	conserve_ammo_action.resource_threshold_reached.connect(func(resource_type, current_level, threshold):
		threshold_reached_fired = true
	)
	
	conserve_ammo_action._update_resource_levels()
	conserve_ammo_action._check_conservation_thresholds()
	
	assert_that(threshold_reached_fired).is_true()

func test_combat_situation_evaluation():
	# Setup combat scenario
	mock_target.set_position(Vector3(800, 0, 0))
	mock_target.set_threat_rating(0.7)
	mock_target.set_damage_level(0.3)
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ai_agent.set_current_target(mock_target)
	mock_ai_agent.set_detected_enemies([mock_target])
	mock_ai_agent.set_nearby_allies([])
	
	var situation = conserve_ammo_action._evaluate_combat_situation()
	
	assert_that(situation).contains_key("threat_level")
	assert_that(situation).contains_key("enemy_count")
	assert_that(situation).contains_key("target_priority")
	assert_that(situation).contains_key("resource_burn_rate")

func test_conservation_mode_adjustment():
	# Setup high threat, low resources scenario
	var situation = {
		"threat_level": 0.9,
		"resource_sufficiency": 0.2,
		"expected_combat_duration": 400.0
	}
	
	var old_mode = conserve_ammo_action.conservation_mode
	conserve_ammo_action._adjust_conservation_for_situation(situation)
	
	# Should switch to emergency reserve mode
	assert_that(conserve_ammo_action.conservation_mode).is_equal(ConserveAmmoAction.ConservationMode.EMERGENCY_RESERVE)

func test_weapon_conservation_recommendations():
	# Setup scenario with mixed weapon priorities
	mock_target.set_threat_rating(0.4)  # Low priority target
	mock_ship_controller.set_weapon_ammo(2, 5)   # Low missiles
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	mock_ship_controller.set_energy_level(0.6)
	mock_ai_agent.set_current_target(mock_target)
	
	var situation = {
		"target_priority": ConserveAmmoAction.TargetPriority.LOW_PRIORITY,
		"threat_level": 0.4,
		"resource_sufficiency": 0.8
	}
	
	# Check missile conservation (should conserve for low priority target)
	var should_conserve_missiles = conserve_ammo_action._should_conserve_weapon(2, situation)
	assert_that(should_conserve_missiles).is_true()
	
	# Check primary guns (should not conserve energy weapons with good energy)
	var should_conserve_primary = conserve_ammo_action._should_conserve_weapon(0, situation)
	assert_that(should_conserve_primary).is_false()

func test_target_priority_based_conservation():
	var situation_low = {
		"target_priority": ConserveAmmoAction.TargetPriority.LOW_PRIORITY,
		"threat_level": 0.3,
		"resource_sufficiency": 0.6
	}
	
	var situation_critical = {
		"target_priority": ConserveAmmoAction.TargetPriority.CRITICAL_PRIORITY,
		"threat_level": 0.9,
		"resource_sufficiency": 0.6
	}
	
	# Setup limited ammo weapon
	mock_ship_controller.set_weapon_ammo(2, 8)
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	
	# Low priority target - should conserve
	var conserve_low = conserve_ammo_action._should_conserve_weapon(2, situation_low)
	assert_that(conserve_low).is_true()
	
	# Critical priority target - should not conserve as much
	var conserve_critical = conserve_ammo_action._should_conserve_weapon(2, situation_critical)
	assert_that(conserve_critical).is_false()

func test_energy_weapon_conservation():
	# Setup low energy scenario
	mock_ship_controller.set_energy_level(0.15)  # Low energy
	conserve_ammo_action._setup_conservation_thresholds()
	
	var situation = {
		"target_priority": ConserveAmmoAction.TargetPriority.STANDARD_PRIORITY,
		"threat_level": 0.5,
		"resource_sufficiency": 0.3
	}
	
	# Should conserve energy weapons when energy is low
	var should_conserve_energy = conserve_ammo_action._should_conserve_weapon(0, situation)
	assert_that(should_conserve_energy).is_true()

func test_conservation_reason_generation():
	# Setup low ammo scenario
	mock_ship_controller.set_weapon_ammo(2, 2)  # Very low missiles
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	
	var situation = {
		"target_priority": ConserveAmmoAction.TargetPriority.LOW_PRIORITY,
		"resource_sufficiency": 0.8
	}
	
	var reason = conserve_ammo_action._get_conservation_reason(2, situation)
	
	assert_that(reason).contains("missiles")
	assert_that(reason).contains("2 remaining")

func test_emergency_conservation_trigger():
	# Setup scenario that should trigger emergency conservation
	conserve_ammo_action.conservation_mode = ConserveAmmoAction.ConservationMode.OPTIMAL_USAGE
	
	var emergency_triggered = false
	conserve_ammo_action.emergency_conservation_activated.connect(func(reason):
		emergency_triggered = true
	)
	
	conserve_ammo_action._trigger_emergency_conservation("Test emergency")
	
	assert_that(emergency_triggered).is_true()
	assert_that(conserve_ammo_action.conservation_mode).is_equal(ConserveAmmoAction.ConservationMode.FULL_CONSERVATION)

func test_resource_usage_logging():
	# Setup target and execute logging
	mock_target.set_threat_rating(0.6)
	mock_ai_agent.set_current_target(mock_target)
	
	conserve_ammo_action._log_resource_usage()
	
	assert_that(conserve_ammo_action.resource_usage_history).has_size(1)
	
	var log_entry = conserve_ammo_action.resource_usage_history[0]
	assert_that(log_entry).contains_key("timestamp")
	assert_that(log_entry).contains_key("resource_levels")
	assert_that(log_entry).contains_key("conservation_mode")

func test_resource_burn_rate_calculation():
	# Setup history with resource consumption
	var time_base = Time.get_time_from_start()
	
	conserve_ammo_action.resource_usage_history = [
		{
			"timestamp": time_base - 2.0,
			"resource_levels": {
				ConserveAmmoAction.ResourceType.AMMUNITION: 0.8,
				ConserveAmmoAction.ResourceType.ENERGY: 0.9
			}
		},
		{
			"timestamp": time_base,
			"resource_levels": {
				ConserveAmmoAction.ResourceType.AMMUNITION: 0.7,
				ConserveAmmoAction.ResourceType.ENERGY: 0.8
			}
		}
	]
	
	var burn_rates = conserve_ammo_action._calculate_resource_burn_rate()
	
	# Should show consumption over time
	assert_that(burn_rates).contains_key(ConserveAmmoAction.ResourceType.AMMUNITION)
	assert_that(burn_rates[ConserveAmmoAction.ResourceType.AMMUNITION]).is_greater(0.0)

func test_resource_sufficiency_assessment():
	# Setup burn rate data
	var burn_rates = {
		ConserveAmmoAction.ResourceType.AMMUNITION: 0.1,  # 10% per second
		ConserveAmmoAction.ResourceType.ENERGY: 0.05      # 5% per second
	}
	
	# Setup current resource levels
	conserve_ammo_action.resource_levels = {
		ConserveAmmoAction.ResourceType.AMMUNITION: 0.5,  # 50% remaining
		ConserveAmmoAction.ResourceType.ENERGY: 0.8       # 80% remaining
	}
	
	# Mock burn rate calculation
	var original_method = conserve_ammo_action._calculate_resource_burn_rate
	conserve_ammo_action._calculate_resource_burn_rate = func(): return burn_rates
	
	var sufficiency = conserve_ammo_action._assess_resource_sufficiency(10.0)  # 10 seconds expected
	
	# Ammo: 0.5 / 0.1 = 5 seconds, sufficiency = 5/10 = 0.5
	# Energy: 0.8 / 0.05 = 16 seconds, sufficiency = 1.0
	# Should return minimum (weakest resource) = 0.5
	assert_that(sufficiency).is_approximately(0.5, 0.1)
	
	# Restore original method
	conserve_ammo_action._calculate_resource_burn_rate = original_method

func test_shots_needed_estimation():
	# Setup target with known health
	mock_target.set_health_percentage(0.6)  # 60% health
	mock_ai_agent.set_current_target(mock_target)
	
	var shots_needed = conserve_ammo_action._estimate_shots_needed_for_engagement()
	
	# Should estimate based on health and accuracy
	assert_that(shots_needed).is_between(5, 50)
	assert_that(shots_needed).is_greater(10)  # Should need multiple shots for 60% health

func test_execution_with_conservation_updates():
	# Setup scenario
	mock_target.set_threat_rating(0.5)
	mock_ship_controller.set_energy_level(0.7)
	mock_ship_controller.set_weapon_ammo(2, 12)
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	mock_ai_agent.set_current_target(mock_target)
	mock_ai_agent.set_detected_enemies([mock_target])
	
	var result = conserve_ammo_action.execute_wcs_action(0.1)
	
	# Should complete successfully
	assert_that(result).is_equal(1)
	
	# Should have updated resource levels
	assert_that(conserve_ammo_action.resource_levels).is_not_empty()

func test_conservation_mode_setting():
	var mode_changed_fired = false
	conserve_ammo_action.conservation_mode_changed.connect(func(old_mode, new_mode):
		mode_changed_fired = true
	)
	
	conserve_ammo_action.set_conservation_mode(ConserveAmmoAction.ConservationMode.STRATEGIC_RESERVE)
	
	assert_that(mode_changed_fired).is_true()
	assert_that(conserve_ammo_action.conservation_mode).is_equal(ConserveAmmoAction.ConservationMode.STRATEGIC_RESERVE)

func test_resource_status_retrieval():
	conserve_ammo_action.conservation_effectiveness = 0.85
	
	var status = conserve_ammo_action.get_resource_status()
	
	assert_that(status).contains_key("resource_levels")
	assert_that(status).contains_key("conservation_thresholds")
	assert_that(status).contains_key("conservation_mode")
	assert_that(status.get("conservation_effectiveness")).is_equal(0.85)

func test_conservation_recommendations_retrieval():
	# Setup scenario
	mock_target.set_threat_rating(0.6)
	mock_ship_controller.set_weapon_ammo(2, 8)
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	mock_ship_controller.set_energy_level(0.8)
	mock_ai_agent.set_current_target(mock_target)
	
	var recommendations = conserve_ammo_action.get_conservation_recommendations()
	
	assert_that(recommendations).is_not_empty()
	assert_that(recommendations).contains_key(0)  # Primary weapons
	assert_that(recommendations).contains_key(2)  # Missiles
	
	# Each recommendation should have should_conserve and reason
	var missile_recommendation = recommendations.get(2)
	assert_that(missile_recommendation).contains_key("should_conserve")
	assert_that(missile_recommendation).contains_key("reason")

func test_force_conservation_mode():
	var emergency_triggered = false
	conserve_ammo_action.emergency_conservation_activated.connect(func(reason):
		emergency_triggered = true
	)
	
	conserve_ammo_action.force_conservation_mode(
		ConserveAmmoAction.ConservationMode.EMERGENCY_RESERVE,
		"Testing forced mode"
	)
	
	assert_that(conserve_ammo_action.conservation_mode).is_equal(ConserveAmmoAction.ConservationMode.EMERGENCY_RESERVE)
	assert_that(emergency_triggered).is_true()

func test_conservation_tracking_reset():
	# Add some history
	conserve_ammo_action.resource_usage_history.append({"test": "data"})
	conserve_ammo_action.conservation_effectiveness = 0.5
	conserve_ammo_action.last_conservation_check = 100.0
	
	conserve_ammo_action.reset_conservation_tracking()
	
	assert_that(conserve_ammo_action.resource_usage_history).is_empty()
	assert_that(conserve_ammo_action.conservation_effectiveness).is_equal(1.0)
	assert_that(conserve_ammo_action.last_conservation_check).is_equal(0.0)

# Mock classes for testing

class MockShipController:
	var position: Vector3 = Vector3.ZERO
	var energy_level: float = 1.0
	var weapon_ammo: Dictionary = {}
	var weapon_max_ammo: Dictionary = {}
	var countermeasures: Dictionary = {"chaff": 10, "flares": 10}
	
	func set_position(pos: Vector3):
		position = pos
	
	func set_energy_level(level: float):
		energy_level = level
	
	func set_weapon_ammo(group: int, ammo: int):
		weapon_ammo[group] = ammo
	
	func set_weapon_max_ammo(group: int, max_ammo: int):
		weapon_max_ammo[group] = max_ammo
	
	func get_position() -> Vector3:
		return position
	
	func get_energy_level() -> float:
		return energy_level
	
	func get_weapon_ammo(group: int) -> int:
		return weapon_ammo.get(group, 10)
	
	func get_weapon_max_ammo(group: int) -> int:
		return weapon_max_ammo.get(group, 20)
	
	func get_countermeasure_count(type: String) -> int:
		return countermeasures.get(type, 10)
	
	func has_weapon_group(group: int) -> bool:
		return group < 3

class MockAIAgent:
	var current_target: Node3D
	var detected_enemies: Array[Node3D] = []
	var nearby_allies: Array[Node3D] = []
	
	func set_current_target(target: Node3D):
		current_target = target
	
	func set_detected_enemies(enemies: Array[Node3D]):
		detected_enemies = enemies
	
	func set_nearby_allies(allies: Array[Node3D]):
		nearby_allies = allies
	
	func get_current_target() -> Node3D:
		return current_target
	
	func get_detected_enemies() -> Array[Node3D]:
		return detected_enemies
	
	func get_nearby_allies() -> Array[Node3D]:
		return nearby_allies
	
	func get_target_priority(target: Node3D) -> float:
		if target and target.has_method("get_threat_rating"):
			return target.get_threat_rating()
		return 0.5
	
	func get_target_mission_priority(target: Node3D) -> float:
		return 0.5
	
	func get_energy_level() -> float:
		return 0.8
	
	func get_mission_phase() -> String:
		return "combat"

class MockTarget extends Node3D:
	var threat_rating: float = 0.5
	var damage_level: float = 0.0
	var health_percentage: float = 1.0
	
	func set_threat_rating(rating: float):
		threat_rating = rating
	
	func set_damage_level(damage: float):
		damage_level = damage
	
	func set_health_percentage(health: float):
		health_percentage = health
	
	func get_threat_rating() -> float:
		return threat_rating
	
	func get_damage_level() -> float:
		return damage_level
	
	func get_health_percentage() -> float:
		return health_percentage