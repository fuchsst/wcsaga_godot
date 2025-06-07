extends GdUnitTestSuite

## Unit tests for SpecialWeaponAction missile and torpedo management
## Tests special weapon usage, lock acquisition, and launch window evaluation

class_name TestSpecialWeaponAction

var special_weapon_action: SpecialWeaponAction
var mock_ship_controller: MockShipController
var mock_ai_agent: MockAIAgent
var mock_target: MockTarget

func before_test():
	special_weapon_action = SpecialWeaponAction.new()
	mock_ship_controller = MockShipController.new()
	mock_ai_agent = MockAIAgent.new()
	mock_target = MockTarget.new()
	
	# Setup mocks
	special_weapon_action.ship_controller = mock_ship_controller
	special_weapon_action.ai_agent = mock_ai_agent
	special_weapon_action._setup()

func after_test():
	special_weapon_action = null
	mock_ship_controller = null
	mock_ai_agent = null
	mock_target = null

func test_special_weapon_initialization():
	assert_that(special_weapon_action.weapon_type).is_equal(SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE)
	assert_that(special_weapon_action.auto_weapon_selection).is_true()
	assert_that(special_weapon_action.target_priority_threshold).is_equal(0.6)
	assert_that(special_weapon_action.weapon_specifications).is_not_empty()

func test_weapon_specifications_data():
	# Test heat-seeking missile specs
	var heat_missile = special_weapon_action.weapon_specifications[SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE]
	assert_that(heat_missile["lock_time"]).is_equal(1.5)
	assert_that(heat_missile["lock_range"]).is_equal(2500.0)
	assert_that(heat_missile["heat_signature_required"]).is_equal(0.3)
	
	# Test heavy torpedo specs
	var torpedo = special_weapon_action.weapon_specifications[SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO]
	assert_that(torpedo["lock_time"]).is_equal(3.5)
	assert_that(torpedo["damage_vs_capital"]).is_equal(3.5)
	assert_that(torpedo["subsystem_targeting"]).is_true()

func test_target_class_determination():
	# Test fighter classification
	mock_target.set_ship_class("fighter")
	var fighter_class = special_weapon_action._determine_target_class(mock_target)
	assert_that(fighter_class).is_equal(SpecialWeaponAction.TargetClass.FIGHTER)
	
	# Test capital ship classification
	mock_target.set_ship_class("destroyer")
	var destroyer_class = special_weapon_action._determine_target_class(mock_target)
	assert_that(destroyer_class).is_equal(SpecialWeaponAction.TargetClass.DESTROYER)
	
	# Test size-based fallback
	mock_target.set_ship_class("")  # Unknown class
	mock_target.set_mass(5000.0)    # Large mass
	var size_based = special_weapon_action._determine_target_class(mock_target)
	assert_that(size_based).is_in([SpecialWeaponAction.TargetClass.CORVETTE, SpecialWeaponAction.TargetClass.FRIGATE])

func test_tactical_situation_assessment():
	# Setup scenario with multiple enemies
	mock_ai_agent.set_nearby_enemies(["enemy1", "enemy2", "enemy3"])
	mock_ai_agent.set_nearby_allies(["ally1"])
	
	var situation = special_weapon_action._assess_tactical_situation()
	
	# Should be outnumbered (3 enemies > 1 ally + 1 player)
	assert_that(situation).is_equal(SpecialWeaponAction.TacticalSituation.OUTNUMBERED)
	
	# Test equal forces
	mock_ai_agent.set_nearby_enemies(["enemy1"])
	mock_ai_agent.set_nearby_allies([])
	
	var one_on_one = special_weapon_action._assess_tactical_situation()
	assert_that(one_on_one).is_equal(SpecialWeaponAction.TacticalSituation.ONE_ON_ONE)

func test_optimal_weapon_selection():
	mock_target.set_ship_class("fighter")
	mock_target.set_position(Vector3(1500, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(2, 10)  # Heat-seeking missiles available
	
	var optimal_weapon = special_weapon_action._select_optimal_special_weapon(mock_target)
	
	# Should prefer heat-seeking missiles for fighters at medium range
	assert_that(optimal_weapon).is_equal(SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE)

func test_weapon_effectiveness_scoring():
	mock_target.set_ship_class("destroyer")
	mock_target.set_position(Vector3(3500, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(3, 5)  # Torpedoes available
	
	var target_class = SpecialWeaponAction.TargetClass.DESTROYER
	var situation = SpecialWeaponAction.TacticalSituation.CAPITAL_ASSAULT
	
	var torpedo_score = special_weapon_action._calculate_weapon_effectiveness_score(
		SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO, target_class, situation
	)
	
	var missile_score = special_weapon_action._calculate_weapon_effectiveness_score(
		SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE, target_class, situation
	)
	
	# Torpedoes should score higher against capital ships
	assert_that(torpedo_score).is_greater(missile_score)

func test_weapon_validation():
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(2, 5)  # Has ammo
	mock_target.set_heat_signature(0.5)  # Good heat signature
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	var is_valid = special_weapon_action._validate_special_weapon_usage(mock_target)
	assert_that(is_valid).is_true()
	
	# Test no ammo scenario
	mock_ship_controller.set_weapon_ammo(2, 0)
	var no_ammo_valid = special_weapon_action._validate_special_weapon_usage(mock_target)
	assert_that(no_ammo_valid).is_false()

func test_weapon_validation_range_check():
	mock_target.set_position(Vector3(6000, 0, 0))  # Out of range
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(2, 5)
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	var out_of_range = special_weapon_action._validate_special_weapon_usage(mock_target)
	assert_that(out_of_range).is_false()

func test_weapon_validation_signature_requirements():
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(2, 5)
	
	# Test insufficient heat signature
	mock_target.set_heat_signature(0.1)  # Below 0.3 requirement
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	var low_signature = special_weapon_action._validate_special_weapon_usage(mock_target)
	assert_that(low_signature).is_false()
	
	# Test sufficient signature
	mock_target.set_heat_signature(0.6)
	var good_signature = special_weapon_action._validate_special_weapon_usage(mock_target)
	assert_that(good_signature).is_true()

func test_lock_acquisition_process():
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_target.set_velocity(Vector3(100, 0, 0))
	mock_target.set_heat_signature(0.7)
	mock_ship_controller.set_position(Vector3.ZERO)
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	# Start lock process
	var lock_result1 = special_weapon_action._process_weapon_lock(mock_target, 0.5)
	assert_that(lock_result1).is_equal(2)  # RUNNING - lock in progress
	assert_that(special_weapon_action.lock_established).is_false()
	
	# Continue lock process until complete
	var lock_result2 = special_weapon_action._process_weapon_lock(mock_target, 1.5)
	assert_that(lock_result2).is_equal(1)  # SUCCESS - lock established
	assert_that(special_weapon_action.lock_established).is_true()

func test_lock_quality_calculation():
	mock_target.set_position(Vector3(1500, 0, 0))
	mock_target.set_velocity(Vector3(50, 0, 0))
	mock_target.set_heat_signature(0.8)
	mock_ship_controller.set_position(Vector3.ZERO)
	
	var lock_quality = special_weapon_action._calculate_lock_quality_progress(mock_target, 1.0, 1.5)
	
	assert_that(lock_quality).is_between(0.0, 1.0)
	assert_that(lock_quality).is_greater(0.4)  # Should be decent quality

func test_lock_maintenance():
	# Setup established lock
	special_weapon_action.lock_established = true
	special_weapon_action.target_lock_quality = 0.8
	
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_target.set_velocity(Vector3(150, 0, 0))
	mock_target.set_heat_signature(0.6)
	mock_ship_controller.set_position(Vector3.ZERO)
	
	var maintained_quality = special_weapon_action._maintain_target_lock(mock_target, 0.1)
	
	# Quality should degrade slightly but remain above threshold
	assert_that(maintained_quality).is_less_equal(0.8)
	assert_that(maintained_quality).is_greater(0.3)  # Above loss threshold

func test_launch_window_evaluation():
	# Setup good launch conditions
	special_weapon_action.target_lock_quality = 0.8
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_target.set_shield_percentage(0.4)  # Low shields
	mock_ship_controller.set_position(Vector3.ZERO)
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	var window_open = special_weapon_action._evaluate_launch_window(mock_target)
	assert_that(window_open).is_true()
	
	# Test poor conditions (low lock quality)
	special_weapon_action.target_lock_quality = 0.5
	var window_closed = special_weapon_action._evaluate_launch_window(mock_target)
	assert_that(window_closed).is_false()

func test_heat_seeking_launch_conditions():
	mock_target.set_heat_signature(0.6)
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	var conditions_met = special_weapon_action._check_heat_seeking_conditions(mock_target)
	assert_that(conditions_met).is_true()
	
	# Test low heat signature
	mock_target.set_heat_signature(0.2)
	var conditions_failed = special_weapon_action._check_heat_seeking_conditions(mock_target)
	assert_that(conditions_failed).is_false()

func test_torpedo_launch_conditions():
	mock_target.set_position(Vector3(2000, 0, 0))  # Good distance
	mock_target.set_velocity(Vector3(200, 0, 0))   # Moderate speed
	mock_target.set_mass(8000.0)                   # Large target
	mock_ship_controller.set_position(Vector3.ZERO)
	
	var conditions_met = special_weapon_action._check_torpedo_launch_conditions(mock_target)
	assert_that(conditions_met).is_true()
	
	# Test target too close
	mock_target.set_position(Vector3(500, 0, 0))
	var too_close = special_weapon_action._check_torpedo_launch_conditions(mock_target)
	assert_that(too_close).is_false()
	
	# Test target too fast
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_target.set_velocity(Vector3(400, 0, 0))
	var too_fast = special_weapon_action._check_torpedo_launch_conditions(mock_target)
	assert_that(too_fast).is_false()

func test_cluster_bomb_conditions():
	mock_target.set_position(Vector3(800, 0, 0))  # Close range
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ai_agent.set_enemies_in_radius([mock_target])  # Multiple targets
	
	var conditions_met = special_weapon_action._check_cluster_bomb_conditions(mock_target)
	assert_that(conditions_met).is_true()
	
	# Test too far for cluster bombs
	mock_target.set_position(Vector3(1500, 0, 0))
	var too_far = special_weapon_action._check_cluster_bomb_conditions(mock_target)
	assert_that(too_far).is_false()

func test_weapon_launch_execution():
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_target.set_velocity(Vector3(100, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_launch_special_weapon_success(true)
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	var launch_success = special_weapon_action._execute_special_weapon_launch(mock_target)
	assert_that(launch_success).is_true()
	assert_that(mock_ship_controller.launch_calls).has_size(1)

func test_launch_parameter_calculation():
	mock_target.set_position(Vector3(2500, 0, 0))
	mock_target.set_velocity(Vector3(150, 0, 0))
	mock_target.set_heat_signature(0.7)
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_velocity(Vector3(50, 0, 0))
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	special_weapon_action.target_lock_quality = 0.8
	
	var specs = special_weapon_action.weapon_specifications[special_weapon_action.weapon_type]
	var params = special_weapon_action._calculate_launch_parameters(mock_target, specs)
	
	assert_that(params).contains_key("target_position")
	assert_that(params).contains_key("target_velocity")
	assert_that(params).contains_key("launch_distance")
	assert_that(params).contains_key("lock_quality")
	assert_that(params).contains_key("guidance_mode")
	assert_that(params["guidance_mode"]).is_equal("heat_seeking")

func test_torpedo_launch_parameters():
	mock_target.set_position(Vector3(3500, 0, 0))
	mock_target.set_velocity(Vector3(80, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO
	special_weapon_action.target_lock_quality = 0.7
	
	var specs = special_weapon_action.weapon_specifications[special_weapon_action.weapon_type]
	var params = special_weapon_action._calculate_launch_parameters(mock_target, specs)
	
	assert_that(params["guidance_mode"]).is_equal("torpedo")
	assert_that(params).contains_key("subsystem_target")
	assert_that(params).contains_key("approach_vector")

func test_execution_complete_workflow():
	# Setup valid missile scenario
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_target.set_velocity(Vector3(100, 0, 0))
	mock_target.set_heat_signature(0.6)
	mock_target.set_shield_percentage(0.3)
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(2, 8)
	mock_ship_controller.set_launch_special_weapon_success(true)
	mock_ai_agent.set_current_target(mock_target)
	mock_ai_agent.set_target_priority(mock_target, 0.8)
	
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	special_weapon_action.target_priority_threshold = 0.6
	
	# First execution - should start lock acquisition
	var result1 = special_weapon_action.execute_wcs_action(0.5)
	assert_that(result1).is_equal(2)  # RUNNING
	
	# Continue until lock established and fired
	var result2 = special_weapon_action.execute_wcs_action(1.5)
	
	# Should eventually succeed in launching
	assert_that(result2).is_in([1, 2])  # SUCCESS or still RUNNING

func test_execution_without_target():
	mock_ai_agent.set_current_target(null)
	
	var result = special_weapon_action.execute_wcs_action(0.1)
	assert_that(result).is_equal(0)  # FAILURE

func test_auto_weapon_selection_workflow():
	special_weapon_action.auto_weapon_selection = true
	
	# Setup scenario favoring torpedoes
	mock_target.set_ship_class("destroyer")
	mock_target.set_position(Vector3(3500, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(3, 4)  # Torpedoes available
	mock_ai_agent.set_current_target(mock_target)
	
	# Original weapon type is missile
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	var result = special_weapon_action.execute_wcs_action(0.1)
	
	# Should auto-select torpedoes for capital ship
	assert_that(special_weapon_action.weapon_type).is_equal(SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO)

func test_weapon_unavailability_scenarios():
	var unavailable_fired = false
	special_weapon_action.special_weapon_unavailable.connect(func(weapon_type, reason):
		unavailable_fired = true
	)
	
	# Setup no ammo scenario
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(2, 0)  # No ammo
	mock_ai_agent.set_current_target(mock_target)
	
	var result = special_weapon_action.execute_wcs_action(0.1)
	
	assert_that(result).is_equal(0)  # FAILURE
	assert_that(unavailable_fired).is_true()

func test_conservation_mode_integration():
	special_weapon_action.ammunition_conservation = true
	special_weapon_action.target_priority_threshold = 0.8
	
	# Setup low priority target
	mock_target.set_position(Vector3(2000, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_ammo(2, 5)
	mock_ai_agent.set_current_target(mock_target)
	mock_ai_agent.set_target_priority(mock_target, 0.5)  # Below threshold
	
	var result = special_weapon_action.execute_wcs_action(0.1)
	
	# Should refuse to fire at low priority target
	assert_that(result).is_equal(0)  # FAILURE

func test_lock_status_reporting():
	special_weapon_action.lock_established = true
	special_weapon_action.target_lock_quality = 0.75
	special_weapon_action.lock_acquisition_time = 2.3
	special_weapon_action.weapon_ready = true
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.RADAR_GUIDED_MISSILE
	
	var lock_status = special_weapon_action.get_lock_status()
	
	assert_that(lock_status["lock_established"]).is_true()
	assert_that(lock_status["lock_quality"]).is_equal(0.75)
	assert_that(lock_status["lock_time"]).is_equal(2.3)
	assert_that(lock_status["weapon_ready"]).is_true()
	assert_that(lock_status["weapon_type"]).is_equal("RADAR_GUIDED_MISSILE")

func test_force_weapon_selection():
	special_weapon_action.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE
	
	special_weapon_action.force_weapon_selection(SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO)
	
	assert_that(special_weapon_action.weapon_type).is_equal(SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO)
	assert_that(special_weapon_action.lock_established).is_false()  # Should reset state

func test_weapon_group_mapping():
	# Test weapon group assignments
	var heat_group = special_weapon_action._get_weapon_group_for_special_weapon(SpecialWeaponAction.SpecialWeaponType.HEAT_SEEKING_MISSILE)
	assert_that(heat_group).is_equal(2)
	
	var torpedo_group = special_weapon_action._get_weapon_group_for_special_weapon(SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO)
	assert_that(torpedo_group).is_equal(3)
	
	var bomb_group = special_weapon_action._get_weapon_group_for_special_weapon(SpecialWeaponAction.SpecialWeaponType.CLUSTER_BOMB)
	assert_that(bomb_group).is_equal(4)

func test_target_analysis_integration():
	mock_target.set_velocity(Vector3(120, 0, 0))
	mock_target.set_mass(1500.0)
	mock_target.set_heat_signature(0.7)
	mock_target.set_radar_signature(0.6)
	
	var analysis_data = special_weapon_action._get_target_analysis_data(mock_target)
	
	assert_that(analysis_data).contains_key("velocity")
	assert_that(analysis_data).contains_key("size_factor")
	assert_that(analysis_data).contains_key("heat_signature")
	assert_that(analysis_data).contains_key("radar_signature")
	assert_that(analysis_data).contains_key("evasion_capability")
	assert_that(analysis_data).contains_key("vulnerability")

# Mock classes for testing

class MockShipController:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var weapon_ammo: Dictionary = {}
	var launch_special_weapon_success: bool = true
	var fire_weapon_success: bool = true
	var launch_calls: Array = []
	var fire_calls: Array = []
	
	func set_position(pos: Vector3):
		position = pos
	
	func set_velocity(vel: Vector3):
		velocity = vel
	
	func set_weapon_ammo(group: int, ammo: int):
		weapon_ammo[group] = ammo
	
	func set_launch_special_weapon_success(success: bool):
		launch_special_weapon_success = success
	
	func set_fire_weapon_success(success: bool):
		fire_weapon_success = success
	
	func get_position() -> Vector3:
		return position
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_weapon_ammo(group: int) -> int:
		return weapon_ammo.get(group, 0)
	
	func launch_special_weapon(group: int, target: Node3D, params: Dictionary) -> bool:
		launch_calls.append({"group": group, "target": target, "params": params})
		return launch_special_weapon_success
	
	func fire_weapon_at_target(group: int, target: Node3D) -> bool:
		fire_calls.append({"group": group, "target": target})
		return fire_weapon_success

class MockAIAgent:
	var current_target: Node3D
	var nearby_enemies: Array = []
	var nearby_allies: Array = []
	var target_priorities: Dictionary = {}
	var enemies_in_radius: Array[Node3D] = []
	
	func set_current_target(target: Node3D):
		current_target = target
	
	func set_nearby_enemies(enemies: Array):
		nearby_enemies = enemies
	
	func set_nearby_allies(allies: Array):
		nearby_allies = allies
	
	func set_target_priority(target: Node3D, priority: float):
		target_priorities[target] = priority
	
	func set_enemies_in_radius(enemies: Array[Node3D]):
		enemies_in_radius = enemies
	
	func get_current_target() -> Node3D:
		return current_target
	
	func get_target_priority(target: Node3D) -> float:
		return target_priorities.get(target, 0.5)
	
	func get_target_mission_priority(target: Node3D) -> float:
		return 0.5

class MockTarget extends Node3D:
	var ship_class: String = "fighter"
	var velocity: Vector3 = Vector3.ZERO
	var mass: float = 1000.0
	var heat_signature: float = 0.5
	var radar_signature: float = 0.5
	var shield_percentage: float = 1.0
	var damage_level: float = 0.0
	
	func set_ship_class(cls: String):
		ship_class = cls
	
	func set_velocity(vel: Vector3):
		velocity = vel
	
	func set_mass(m: float):
		mass = m
	
	func set_heat_signature(sig: float):
		heat_signature = sig
	
	func set_radar_signature(sig: float):
		radar_signature = sig
	
	func set_shield_percentage(shields: float):
		shield_percentage = shields
	
	func set_damage_level(damage: float):
		damage_level = damage
	
	func get_ship_class() -> String:
		return ship_class
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_mass() -> float:
		return mass
	
	func get_heat_signature() -> float:
		return heat_signature
	
	func get_radar_signature() -> float:
		return radar_signature
	
	func get_shield_percentage() -> float:
		return shield_percentage
	
	func get_damage_level() -> float:
		return damage_level