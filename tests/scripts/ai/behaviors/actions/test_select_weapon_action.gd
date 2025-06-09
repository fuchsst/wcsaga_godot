extends GdUnitTestSuite

## Unit tests for SelectWeaponAction weapon selection behavior
## Tests weapon selection logic, target analysis, and tactical decision making

class_name TestSelectWeaponAction

var select_weapon_action: SelectWeaponAction
var mock_ship_controller: MockShipController
var mock_ai_agent: MockAIAgent
var mock_target: MockTarget

func before_test():
	select_weapon_action = SelectWeaponAction.new()
	mock_ship_controller = MockShipController.new()
	mock_ai_agent = MockAIAgent.new()
	mock_target = MockTarget.new()
	
	# Setup mocks
	select_weapon_action.ship_controller = mock_ship_controller as Node
	select_weapon_action.set_meta("ai_agent", mock_ai_agent)
	select_weapon_action._setup()

func after_test():
	select_weapon_action = null
	mock_ship_controller = null
	mock_ai_agent = null
	mock_target = null

func test_weapon_selection_initialization():
	assert_that(select_weapon_action.current_weapon_selection).is_equal(SelectWeaponAction.WeaponType.PRIMARY_GUNS)
	assert_that(select_weapon_action.auto_weapon_selection).is_true()
	assert_that(select_weapon_action.weapon_effectiveness_history).is_not_null()

func test_target_analysis_basic_metrics():
	# Setup target
	mock_target.set_position(Vector3(500, 0, 0))
	mock_target.set_velocity(Vector3(100, 0, 0))
	mock_target.set_ship_class("fighter")
	
	# Mock ship position
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_velocity(Vector3(50, 0, 0))
	
	var analysis = select_weapon_action._analyze_target(mock_target)
	
	assert_that(analysis["distance"]).is_equal(500.0)
	assert_that(analysis["target_class"]).is_equal(SelectWeaponAction.TargetClass.FIGHTER)
	assert_that(analysis["target_velocity"]).is_equal(Vector3(100, 0, 0))
	assert_that(analysis["relative_velocity"]).is_equal(Vector3(50, 0, 0))

func test_target_class_determination_from_ship_class():
	var test_cases = [
		{"class": "fighter", "expected": SelectWeaponAction.TargetClass.FIGHTER},
		{"class": "bomber", "expected": SelectWeaponAction.TargetClass.BOMBER},
		{"class": "corvette", "expected": SelectWeaponAction.TargetClass.CORVETTE},
		{"class": "frigate", "expected": SelectWeaponAction.TargetClass.FRIGATE},
		{"class": "destroyer", "expected": SelectWeaponAction.TargetClass.DESTROYER},
		{"class": "cruiser", "expected": SelectWeaponAction.TargetClass.CRUISER},
		{"class": "battleship", "expected": SelectWeaponAction.TargetClass.BATTLESHIP},
		{"class": "transport", "expected": SelectWeaponAction.TargetClass.TRANSPORT}
	]
	
	for test_case in test_cases:
		mock_target.set_ship_class(test_case["class"])
		var target_class = select_weapon_action._determine_target_class(mock_target)
		assert_that(target_class).is_equal(test_case["expected"])

func test_weapon_selection_by_range():
	# Test close range - should prefer primary guns
	var close_distance = 400.0
	var weapon = select_weapon_action._select_by_range(close_distance)
	assert_that(weapon).is_equal(SelectWeaponAction.WeaponType.PRIMARY_GUNS)
	
	# Test medium range - could be secondary guns
	var medium_distance = 1000.0
	weapon = select_weapon_action._select_by_range(medium_distance)
	assert_that(weapon).is_in([SelectWeaponAction.WeaponType.PRIMARY_GUNS, SelectWeaponAction.WeaponType.SECONDARY_GUNS])
	
	# Test long range - should prefer missiles if available
	var long_distance = 2500.0
	mock_ship_controller.set_weapon_group_available(2, true)  # Missiles
	weapon = select_weapon_action._select_by_range(long_distance)
	assert_that(weapon).is_equal(SelectWeaponAction.WeaponType.MISSILES)

func test_weapon_selection_by_target_type():
	# Fighter target - should prefer missiles or primary guns
	var fighter_weapon = select_weapon_action._select_by_target_type(SelectWeaponAction.TargetClass.FIGHTER)
	assert_that(fighter_weapon).is_in([SelectWeaponAction.WeaponType.MISSILES, SelectWeaponAction.WeaponType.PRIMARY_GUNS])
	
	# Bomber target - should prefer secondary guns
	mock_ship_controller.set_weapon_group_available(1, true)  # Secondary guns
	var bomber_weapon = select_weapon_action._select_by_target_type(SelectWeaponAction.TargetClass.BOMBER)
	assert_that(bomber_weapon).is_equal(SelectWeaponAction.WeaponType.SECONDARY_GUNS)
	
	# Capital ship target - should prefer torpedoes
	mock_ship_controller.set_weapon_group_available(3, true)  # Torpedoes
	var capital_weapon = select_weapon_action._select_by_target_type(SelectWeaponAction.TargetClass.DESTROYER)
	assert_that(capital_weapon).is_equal(SelectWeaponAction.WeaponType.TORPEDOES)

func test_weapon_score_calculation():
	# Setup scenario
	mock_target.set_position(Vector3(600, 0, 0))  # Optimal range for primary guns
	mock_target.set_ship_class("fighter")
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_energy_level(1.0)
	
	var analysis = select_weapon_action._analyze_target(mock_target)
	var score = select_weapon_action._calculate_weapon_score(SelectWeaponAction.WeaponType.PRIMARY_GUNS, analysis)
	
	# Should get high score for optimal range and good target match
	assert_that(score).is_greater(0.5)

func test_weapon_availability_validation():
	# Test available weapon
	mock_ship_controller.set_weapon_group_available(0, true)
	var available = select_weapon_action._is_weapon_available(SelectWeaponAction.WeaponType.PRIMARY_GUNS)
	assert_that(available).is_true()
	
	# Test unavailable weapon
	mock_ship_controller.set_weapon_group_available(3, false)
	var unavailable = select_weapon_action._is_weapon_available(SelectWeaponAction.WeaponType.TORPEDOES)
	assert_that(unavailable).is_false()

func test_weapon_selection_validation():
	# Setup valid scenario
	mock_target.set_position(Vector3(500, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_group_available(0, true)
	mock_ship_controller.set_energy_level(1.0)
	
	var valid = select_weapon_action._validate_weapon_selection(SelectWeaponAction.WeaponType.PRIMARY_GUNS, mock_target)
	assert_that(valid).is_true()
	
	# Test out of range scenario
	mock_target.set_position(Vector3(5000, 0, 0))  # Very far
	var invalid_range = select_weapon_action._validate_weapon_selection(SelectWeaponAction.WeaponType.PRIMARY_GUNS, mock_target)
	assert_that(invalid_range).is_false()

func test_ammo_conservation_factor():
	# Test unlimited ammo weapon
	var unlimited_factor = select_weapon_action._get_ammo_conservation_factor(SelectWeaponAction.WeaponType.PRIMARY_GUNS)
	assert_that(unlimited_factor).is_equal(1.0)
	
	# Test limited ammo weapon with low ammunition
	mock_ship_controller.set_weapon_ammo(2, 3)  # Low missile count
	var limited_factor = select_weapon_action._get_ammo_conservation_factor(SelectWeaponAction.WeaponType.MISSILES)
	assert_that(limited_factor).is_less(1.0)

func test_auto_weapon_selection_integration():
	# Setup complex scenario
	mock_target.set_position(Vector3(800, 0, 0))
	mock_target.set_ship_class("bomber")
	mock_target.set_velocity(Vector3(150, 0, 0))
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_velocity(Vector3(100, 0, 0))
	mock_ship_controller.set_energy_level(0.8)
	mock_ship_controller.set_weapon_group_available(1, true)  # Secondary guns
	mock_ship_controller.set_weapon_ammo(2, 10)  # Missiles
	
	var analysis = select_weapon_action._analyze_target(mock_target)
	var selected_weapon = select_weapon_action._auto_select_weapon(mock_target, analysis)
	
	# Should select appropriate weapon based on scoring
	assert_that(selected_weapon).is_not_null()

func test_weapon_effectiveness_recording():
	var weapon_type = SelectWeaponAction.WeaponType.PRIMARY_GUNS
	var effectiveness = 0.8
	
	select_weapon_action.record_weapon_effectiveness(weapon_type, effectiveness)
	
	var history = select_weapon_action.weapon_effectiveness_history[weapon_type]
	assert_that(history).contains(effectiveness)
	
	var historical_effectiveness = select_weapon_action._get_historical_effectiveness(weapon_type)
	assert_that(historical_effectiveness).is_equal(effectiveness)

func test_execution_with_valid_target():
	# Setup valid execution scenario
	mock_target.set_position(Vector3(600, 0, 0))
	mock_target.set_ship_class("fighter")
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_group_available(0, true)
	mock_ship_controller.set_energy_level(1.0)
	mock_ai_agent.set_current_target(mock_target)
	
	# Execute action
	var result = select_weapon_action.execute_wcs_action(0.1)
	
	assert_that(result).is_equal(1)  # SUCCESS
	assert_that(select_weapon_action.current_weapon_selection).is_not_null()

func test_execution_without_target():
	# No target available
	mock_ai_agent.set_current_target(null)
	
	var result = select_weapon_action.execute_wcs_action(0.1)
	
	assert_that(result).is_equal(0)  # FAILURE

func test_weapon_selection_caching():
	# Setup scenario
	mock_target.set_position(Vector3(600, 0, 0))
	mock_target.set_ship_class("fighter")
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_weapon_group_available(0, true)
	mock_ai_agent.set_current_target(mock_target)
	
	# First execution
	var result1 = select_weapon_action.execute_wcs_action(0.1)
	var selection_time1 = select_weapon_action.last_selection_time
	
	# Second execution within cache duration
	var result2 = select_weapon_action.execute_wcs_action(0.1)
	var selection_time2 = select_weapon_action.last_selection_time
	
	assert_that(result1).is_equal(1)
	assert_that(result2).is_equal(1)
	assert_that(selection_time2).is_equal(selection_time1)  # Should use cache

func test_weapon_group_mapping():
	var test_cases = [
		{"weapon": SelectWeaponAction.WeaponType.PRIMARY_GUNS, "group": 0},
		{"weapon": SelectWeaponAction.WeaponType.SECONDARY_GUNS, "group": 1},
		{"weapon": SelectWeaponAction.WeaponType.MISSILES, "group": 2},
		{"weapon": SelectWeaponAction.WeaponType.TORPEDOES, "group": 3},
		{"weapon": SelectWeaponAction.WeaponType.SPECIAL_WEAPONS, "group": 4}
	]
	
	for test_case in test_cases:
		var group = select_weapon_action._get_weapon_group_for_type(test_case["weapon"])
		assert_that(group).is_equal(test_case["group"])

func test_force_weapon_selection():
	mock_ship_controller.set_weapon_group_available(2, true)
	mock_ai_agent.set_current_target(mock_target)
	
	var success = select_weapon_action.force_weapon_selection(SelectWeaponAction.WeaponType.MISSILES)
	
	assert_that(success).is_true()
	assert_that(select_weapon_action.current_weapon_selection).is_equal(SelectWeaponAction.WeaponType.MISSILES)

# Mock classes for testing

class MockShipController:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var energy_level: float = 1.0
	var weapon_groups: Dictionary = {}
	var weapon_ammo: Dictionary = {}
	
	func set_position(pos: Vector3):
		position = pos
	
	func set_velocity(vel: Vector3):
		velocity = vel
	
	func set_energy_level(level: float):
		energy_level = level
	
	func set_weapon_group_available(group: int, available: bool):
		weapon_groups[group] = available
	
	func set_weapon_ammo(group: int, ammo: int):
		weapon_ammo[group] = ammo
	
	func get_position() -> Vector3:
		return position
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_energy_level() -> float:
		return energy_level
	
	func has_weapon_group(group: int) -> bool:
		return weapon_groups.get(group, false)
	
	func get_weapon_ammo(group: int) -> int:
		return weapon_ammo.get(group, 10)
	
	func set_active_weapon_group(group: int):
		pass
	
	func set_targeting_mode(mode: String):
		pass

class MockAIAgent:
	var current_target: Node3D
	
	func set_current_target(target: Node3D):
		current_target = target
	
	func get_current_target() -> Node3D:
		return current_target
	
	func get_target_mission_priority(target: Node3D) -> float:
		return 0.5

class MockTarget extends Node3D:
	var ship_class: String = "fighter"
	var velocity: Vector3 = Vector3.ZERO
	var mass: float = 100.0
	
	func set_ship_class(cls: String):
		ship_class = cls
	
	func set_velocity(vel: Vector3):
		velocity = vel
	
	func set_mass(m: float):
		mass = m
	
	func get_ship_class() -> String:
		return ship_class
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_mass() -> float:
		return mass
	
	func get_threat_rating() -> float:
		return 0.5
	
	func get_shield_percentage() -> float:
		return 0.5
	
	func get_armor_rating() -> float:
		return 1.0