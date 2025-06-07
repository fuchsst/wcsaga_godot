extends GdUnitTestSuite

## Unit tests for FireWeaponAction firing behavior and solution calculation
## Tests firing discipline, hit probability calculation, and weapon fire execution

class_name TestFireWeaponAction

var fire_weapon_action: FireWeaponAction
var mock_ship_controller: MockShipController
var mock_ai_agent: MockAIAgent
var mock_target: MockTarget

func before_test():
	fire_weapon_action = FireWeaponAction.new()
	mock_ship_controller = MockShipController.new()
	mock_ai_agent = MockAIAgent.new()
	mock_target = MockTarget.new()
	
	# Setup mocks
	fire_weapon_action.ship_controller = mock_ship_controller
	fire_weapon_action.ai_agent = mock_ai_agent
	fire_weapon_action._setup()

func after_test():
	fire_weapon_action = null
	mock_ship_controller = null
	mock_ai_agent = null
	mock_target = null

func test_firing_action_initialization():
	assert_that(fire_weapon_action.fire_mode).is_equal(FireWeaponAction.FireMode.BURST_FIRE)
	assert_that(fire_weapon_action.fire_discipline).is_equal(FireWeaponAction.FireDiscipline.STANDARD)
	assert_that(fire_weapon_action.min_hit_probability).is_equal(0.3)
	assert_that(fire_weapon_action.weapon_specifications).is_not_empty()

func test_firing_solution_calculation():
	# Setup scenario
	mock_target.set_position(Vector3(500, 0, 0))
	mock_target.set_velocity(Vector3(50, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_velocity(Vector3(25, 0, 0))
	mock_ai_agent.set_current_target(mock_target)
	
	var solution = fire_weapon_action._calculate_firing_solution(mock_target, 0.1)
	
	assert_that(solution).contains_key("weapon_group")
	assert_that(solution).contains_key("target_distance")
	assert_that(solution).contains_key("hit_probability")
	assert_that(solution).contains_key("lock_quality")
	assert_that(solution.get("target_distance")).is_equal(500.0)

func test_hit_probability_calculation():
	var solution = {
		"target_distance": 600.0,
		"angle_off_target": 0.1,
		"lock_quality": 0.8,
		"relative_velocity": Vector3(30, 0, 0),
		"convergence_distance": 500.0,
		"weapon_spread": 0.03
	}
	
	var hit_prob = fire_weapon_action._calculate_hit_probability(mock_target, solution)
	
	assert_that(hit_prob).is_between(0.0, 1.0)
	assert_that(hit_prob).is_greater(0.4)  # Should be reasonable probability

func test_target_lock_quality_assessment():
	mock_target.set_position(Vector3(800, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	
	var solution = {
		"target_distance": 800.0,
		"angle_off_target": 0.2
	}
	
	var lock_quality = fire_weapon_action._assess_target_lock_quality(mock_target, solution)
	
	assert_that(lock_quality).is_between(0.0, 1.0)

func test_firing_discipline_thresholds():
	# Conservative discipline
	fire_weapon_action.fire_discipline = FireWeaponAction.FireDiscipline.CONSERVATIVE
	var conservative_threshold = fire_weapon_action._get_discipline_threshold()
	assert_that(conservative_threshold).is_equal(0.7)
	
	# Aggressive discipline
	fire_weapon_action.fire_discipline = FireWeaponAction.FireDiscipline.AGGRESSIVE
	var aggressive_threshold = fire_weapon_action._get_discipline_threshold()
	assert_that(aggressive_threshold).is_equal(0.2)
	
	# Precision discipline
	fire_weapon_action.fire_discipline = FireWeaponAction.FireDiscipline.PRECISION
	var precision_threshold = fire_weapon_action._get_discipline_threshold()
	assert_that(precision_threshold).is_equal(0.9)

func test_minimum_lock_quality_requirements():
	# Direct fire mode
	fire_weapon_action.targeting_mode = FireWeaponAction.TargetingMode.DIRECT_FIRE
	var direct_lock = fire_weapon_action._get_minimum_lock_quality()
	assert_that(direct_lock).is_equal(0.3)
	
	# Lead target mode
	fire_weapon_action.targeting_mode = FireWeaponAction.TargetingMode.LEAD_TARGET
	var lead_lock = fire_weapon_action._get_minimum_lock_quality()
	assert_that(lead_lock).is_equal(0.5)
	
	# Convergence mode
	fire_weapon_action.targeting_mode = FireWeaponAction.TargetingMode.CONVERGENCE
	var convergence_lock = fire_weapon_action._get_minimum_lock_quality()
	assert_that(convergence_lock).is_equal(0.6)

func test_weapon_constraint_validation():
	# Setup weapon with normal heat
	mock_ship_controller.set_weapon_heat(0, 30.0)
	mock_ship_controller.set_energy_level(1.0)
	
	var solution = {"target_priority": 0.8}
	fire_weapon_action.current_weapon_group = 0
	
	var valid = fire_weapon_action._check_weapon_constraints(solution)
	assert_that(valid).is_true()
	
	# Test overheated weapon
	mock_ship_controller.set_weapon_heat(0, 90.0)
	fire_weapon_action.heat_threshold = 0.8
	
	var invalid_heat = fire_weapon_action._check_weapon_constraints(solution)
	assert_that(invalid_heat).is_false()

func test_ammunition_conservation_checks():
	# Setup limited ammo weapon
	fire_weapon_action.current_weapon_group = 2  # Missiles
	mock_ship_controller.set_weapon_ammo(2, 15)
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	fire_weapon_action.ammo_conservation_threshold = 0.2
	
	var sufficient_ammo = fire_weapon_action._check_ammo_conservation_rules()
	assert_that(sufficient_ammo).is_true()
	
	# Test low ammunition
	mock_ship_controller.set_weapon_ammo(2, 2)
	var low_ammo = fire_weapon_action._check_ammo_conservation_rules()
	assert_that(low_ammo).is_false()

func test_fire_mode_requirements():
	var solution = {
		"target_priority": 0.9,
		"lock_quality": 0.8,
		"hit_probability": 0.85
	}
	
	# Alpha strike requires high priority
	fire_weapon_action.fire_mode = FireWeaponAction.FireMode.ALPHA_STRIKE
	var alpha_valid = fire_weapon_action._check_fire_mode_requirements(solution)
	assert_that(alpha_valid).is_true()
	
	# Precision requires high hit probability
	fire_weapon_action.fire_mode = FireWeaponAction.FireMode.PRECISION
	var precision_valid = fire_weapon_action._check_fire_mode_requirements(solution)
	assert_that(precision_valid).is_true()
	
	# Sustained fire requires good lock
	fire_weapon_action.fire_mode = FireWeaponAction.FireMode.SUSTAINED_FIRE
	var sustained_valid = fire_weapon_action._check_fire_mode_requirements(solution)
	assert_that(sustained_valid).is_true()

func test_firing_decision_evaluation():
	# Setup favorable firing conditions
	var solution = {
		"hit_probability": 0.6,
		"lock_quality": 0.7,
		"target_distance": 600.0,
		"angle_off_target": 0.15
	}
	
	mock_target.set_position(Vector3(600, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_heat(0, 30.0)
	mock_ship_controller.set_energy_level(1.0)
	fire_weapon_action.fire_discipline = FireWeaponAction.FireDiscipline.STANDARD
	
	var should_fire = fire_weapon_action._evaluate_firing_decision(mock_target, solution)
	assert_that(should_fire).is_true()

func test_firing_decision_rejection():
	# Setup unfavorable conditions (low hit probability)
	var solution = {
		"hit_probability": 0.1,
		"lock_quality": 0.3,
		"target_distance": 600.0,
		"angle_off_target": 0.8
	}
	
	fire_weapon_action.fire_discipline = FireWeaponAction.FireDiscipline.CONSERVATIVE
	
	var should_not_fire = fire_weapon_action._evaluate_firing_decision(mock_target, solution)
	assert_that(should_not_fire).is_false()

func test_single_shot_execution():
	mock_target.set_position(Vector3(500, 0, 0))
	mock_ship_controller.set_fire_weapon_success(true)
	
	var solution = {"optimal_aim_point": Vector3(500, 0, 0)}
	
	var fire_success = fire_weapon_action._execute_single_shot(mock_target, solution)
	assert_that(fire_success).is_true()
	assert_that(mock_ship_controller.fire_calls).has_size(1)

func test_burst_fire_execution():
	mock_target.set_position(Vector3(500, 0, 0))
	mock_ship_controller.set_fire_weapon_success(true)
	fire_weapon_action.burst_size = 3
	fire_weapon_action.refire_delay = 0.1
	
	var solution = {"optimal_aim_point": Vector3(500, 0, 0)}
	
	# First shot should start burst
	var burst_start = fire_weapon_action._execute_burst_fire(mock_target, solution)
	assert_that(burst_start).is_true()
	assert_that(fire_weapon_action.burst_shots_fired).is_equal(1)

func test_sustained_fire_execution():
	mock_target.set_position(Vector3(500, 0, 0))
	mock_ship_controller.set_fire_weapon_success(true)
	mock_ship_controller.set_weapon_heat(0, 40.0)
	fire_weapon_action.heat_threshold = 0.8
	fire_weapon_action.current_weapon_group = 0
	
	var solution = {"optimal_aim_point": Vector3(500, 0, 0)}
	
	var sustained_fire = fire_weapon_action._execute_sustained_fire(mock_target, solution)
	assert_that(sustained_fire).is_true()

func test_optimal_aim_point_calculation():
	mock_target.set_position(Vector3(500, 0, 0))
	mock_target.set_velocity(Vector3(100, 0, 0))
	
	var solution = {
		"intercept_time": 2.0,
		"convergence_distance": 500.0,
		"target_distance": 500.0
	}
	
	var aim_point = fire_weapon_action._calculate_optimal_aim_point(mock_target, solution)
	
	# Should lead target based on velocity and intercept time
	assert_that(aim_point.x).is_greater(500.0)  # Lead the target

func test_weapon_fire_execution_with_refire_delay():
	mock_target.set_position(Vector3(500, 0, 0))
	mock_ship_controller.set_fire_weapon_success(true)
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ai_agent.set_current_target(mock_target)
	
	# Setup weapon specs with fast refire rate
	fire_weapon_action.current_weapon_group = 0
	fire_weapon_action.last_fire_time = Time.get_time_from_start() - 1.0  # 1 second ago
	
	var solution = {
		"hit_probability": 0.8,
		"lock_quality": 0.7,
		"target_distance": 500.0,
		"angle_off_target": 0.1,
		"optimal_aim_point": Vector3(500, 0, 0)
	}
	
	var fire_result = fire_weapon_action._execute_weapon_fire(mock_target, solution)
	assert_that(fire_result).is_true()

func test_angle_off_target_calculation():
	mock_target.set_position(Vector3(500, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_forward_vector(Vector3(1, 0, 0))  # Facing target
	
	var angle = fire_weapon_action._calculate_angle_off_target(mock_target)
	assert_that(angle).is_approximately(0.0, 0.1)
	
	# Test angled target
	mock_ship_controller.set_forward_vector(Vector3(0, 0, 1))  # Facing perpendicular
	var angled = fire_weapon_action._calculate_angle_off_target(mock_target)
	assert_that(angled).is_approximately(PI/2, 0.1)

func test_target_vulnerability_analysis():
	mock_target.set_shield_percentage(0.3)
	mock_target.set_armor_rating(1.2)
	
	var vulnerability = fire_weapon_action._analyze_target_vulnerability(mock_target)
	
	assert_that(vulnerability).contains_key("shield_level")
	assert_that(vulnerability).contains_key("armor_rating")
	assert_that(vulnerability.get("shield_level")).is_equal(0.3)
	assert_that(vulnerability.get("armor_rating")).is_equal(1.2)

func test_fire_window_calculation():
	var solution = {
		"hit_probability": 0.7,
		"lock_quality": 0.8
	}
	
	fire_weapon_action.min_hit_probability = 0.5
	
	var fire_window = fire_weapon_action._calculate_fire_window(mock_target, solution)
	
	assert_that(fire_window).contains_key("window_open")
	assert_that(fire_window).contains_key("window_quality")
	assert_that(fire_window.get("window_open")).is_true()
	assert_that(fire_window.get("window_quality")).is_greater(0.5)

func test_fire_mode_recommendations():
	# Close range, high probability - should recommend burst
	var close_solution = {
		"target_distance": 350.0,
		"hit_probability": 0.8,
		"relative_velocity": Vector3(50, 0, 0)
	}
	
	var close_mode = fire_weapon_action._recommend_fire_mode(mock_target, close_solution)
	assert_that(close_mode).is_equal(FireWeaponAction.FireMode.BURST_FIRE)
	
	# Fast target - should recommend sustained fire
	var fast_solution = {
		"target_distance": 800.0,
		"hit_probability": 0.6,
		"relative_velocity": Vector3(350, 0, 0)
	}
	
	var fast_mode = fire_weapon_action._recommend_fire_mode(mock_target, fast_solution)
	assert_that(fast_mode).is_equal(FireWeaponAction.FireMode.SUSTAINED_FIRE)
	
	# Long range, good shot - should recommend single shot
	var long_solution = {
		"target_distance": 1200.0,
		"hit_probability": 0.7,
		"relative_velocity": Vector3(100, 0, 0)
	}
	
	var long_mode = fire_weapon_action._recommend_fire_mode(mock_target, long_solution)
	assert_that(long_mode).is_equal(FireWeaponAction.FireMode.SINGLE_SHOT)

func test_execution_with_valid_target():
	# Setup valid firing scenario
	mock_target.set_position(Vector3(600, 0, 0))
	mock_target.set_velocity(Vector3(50, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_velocity(Vector3(25, 0, 0))
	mock_ship_controller.set_forward_vector(Vector3(1, 0, 0))
	mock_ship_controller.set_weapon_group_available(0, true)
	mock_ship_controller.set_energy_level(1.0)
	mock_ship_controller.set_weapon_heat(0, 30.0)
	mock_ship_controller.set_fire_weapon_success(true)
	mock_ai_agent.set_current_target(mock_target)
	
	fire_weapon_action.fire_discipline = FireWeaponAction.FireDiscipline.AGGRESSIVE
	fire_weapon_action.min_hit_probability = 0.2
	
	var result = fire_weapon_action.execute_wcs_action(0.1)
	
	# Should succeed in firing
	assert_that(result).is_in([1, 2])  # SUCCESS or RUNNING

func test_execution_without_target():
	mock_ai_agent.set_current_target(null)
	
	var result = fire_weapon_action.execute_wcs_action(0.1)
	
	assert_that(result).is_equal(0)  # FAILURE

func test_firing_statistics_tracking():
	# Fire some shots
	fire_weapon_action.shots_fired_session = 10
	fire_weapon_action.hits_recorded_session = 7
	
	var stats = fire_weapon_action.get_firing_statistics()
	
	assert_that(stats.get("shots_fired")).is_equal(10)
	assert_that(stats.get("hits_recorded")).is_equal(7)
	assert_that(stats.get("accuracy")).is_approximately(0.7, 0.01)

func test_firing_parameters_setting():
	fire_weapon_action.set_fire_parameters(
		FireWeaponAction.FireMode.SUSTAINED_FIRE,
		FireWeaponAction.FireDiscipline.PRECISION,
		FireWeaponAction.TargetingMode.CONVERGENCE
	)
	
	assert_that(fire_weapon_action.fire_mode).is_equal(FireWeaponAction.FireMode.SUSTAINED_FIRE)
	assert_that(fire_weapon_action.fire_discipline).is_equal(FireWeaponAction.FireDiscipline.PRECISION)
	assert_that(fire_weapon_action.targeting_mode).is_equal(FireWeaponAction.TargetingMode.CONVERGENCE)

# Mock classes for testing

class MockShipController:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var forward_vector: Vector3 = Vector3(1, 0, 0)
	var energy_level: float = 1.0
	var weapon_groups: Dictionary = {}
	var weapon_heat: Dictionary = {}
	var weapon_ammo: Dictionary = {}
	var weapon_max_ammo: Dictionary = {}
	var fire_weapon_success: bool = true
	var fire_calls: Array = []
	
	func set_position(pos: Vector3):
		position = pos
	
	func set_velocity(vel: Vector3):
		velocity = vel
	
	func set_forward_vector(forward: Vector3):
		forward_vector = forward
	
	func set_energy_level(level: float):
		energy_level = level
	
	func set_weapon_group_available(group: int, available: bool):
		weapon_groups[group] = available
	
	func set_weapon_heat(group: int, heat: float):
		weapon_heat[group] = heat
	
	func set_weapon_ammo(group: int, ammo: int):
		weapon_ammo[group] = ammo
	
	func set_weapon_max_ammo(group: int, max_ammo: int):
		weapon_max_ammo[group] = max_ammo
	
	func set_fire_weapon_success(success: bool):
		fire_weapon_success = success
	
	func get_position() -> Vector3:
		return position
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_forward_vector() -> Vector3:
		return forward_vector
	
	func get_energy_level() -> float:
		return energy_level
	
	func has_weapon_group(group: int) -> bool:
		return weapon_groups.get(group, true)
	
	func get_weapon_heat(group: int) -> float:
		return weapon_heat.get(group, 0.0)
	
	func get_weapon_ammo(group: int) -> int:
		return weapon_ammo.get(group, 100)
	
	func get_weapon_max_ammo(group: int) -> int:
		return weapon_max_ammo.get(group, 100)
	
	func is_weapon_system_operational(group: int) -> bool:
		return true
	
	func fire_weapon_at_point(group: int, point: Vector3, shots: int) -> bool:
		fire_calls.append({"group": group, "point": point, "shots": shots})
		return fire_weapon_success
	
	func fire_weapons(target: Node3D) -> bool:
		fire_calls.append({"target": target})
		return fire_weapon_success
	
	func get_active_weapon_group() -> int:
		return 0

class MockAIAgent:
	var current_target: Node3D
	var skill_level: float = 0.7
	var selected_weapon_group: int = 0
	
	func set_current_target(target: Node3D):
		current_target = target
	
	func get_current_target() -> Node3D:
		return current_target
	
	func get_skill_level() -> float:
		return skill_level
	
	func get_selected_weapon_group() -> int:
		return selected_weapon_group
	
	func get_target_priority(target: Node3D) -> float:
		return 0.7

class MockTarget extends Node3D:
	var velocity: Vector3 = Vector3.ZERO
	var shield_percentage: float = 0.5
	var armor_rating: float = 1.0
	var damage_level: float = 0.0
	var threat_rating: float = 0.5
	
	func set_velocity(vel: Vector3):
		velocity = vel
	
	func set_shield_percentage(shields: float):
		shield_percentage = shields
	
	func set_armor_rating(armor: float):
		armor_rating = armor
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_shield_percentage() -> float:
		return shield_percentage
	
	func get_armor_rating() -> float:
		return armor_rating
	
	func get_damage_level() -> float:
		return damage_level
	
	func get_threat_rating() -> float:
		return threat_rating