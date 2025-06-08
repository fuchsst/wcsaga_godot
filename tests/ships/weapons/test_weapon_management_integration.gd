extends GdUnitTestSuite

## Integration tests for AI-012 weapon management and firing solutions
## Tests complete weapon management workflow with multiple components working together

class_name TestWeaponManagementIntegration

var weapon_selector: SelectWeaponAction
var weapon_firer: FireWeaponAction
var ammo_conserver: ConserveAmmoAction
var special_weapon: SpecialWeaponAction
var mock_ship_controller: MockShipController
var mock_ai_agent: MockAIAgent
var mock_target_fighter: MockTarget
var mock_target_capital: MockTarget

func before_test():
	# Create all weapon management components
	weapon_selector = SelectWeaponAction.new()
	weapon_firer = FireWeaponAction.new()
	ammo_conserver = ConserveAmmoAction.new()
	special_weapon = SpecialWeaponAction.new()
	
	# Create comprehensive mocks
	mock_ship_controller = MockShipController.new()
	mock_ai_agent = MockAIAgent.new()
	mock_target_fighter = MockTarget.new()
	mock_target_capital = MockTarget.new()
	
	# Setup targets
	mock_target_fighter.set_ship_class("fighter")
	mock_target_fighter.set_position(Vector3(800, 0, 0))
	mock_target_fighter.set_velocity(Vector3(150, 0, 0))
	mock_target_fighter.set_mass(500.0)
	mock_target_fighter.set_heat_signature(0.7)
	mock_target_fighter.set_shield_percentage(0.6)
	
	mock_target_capital.set_ship_class("destroyer")
	mock_target_capital.set_position(Vector3(3000, 0, 0))
	mock_target_capital.set_velocity(Vector3(50, 0, 0))
	mock_target_capital.set_mass(15000.0)
	mock_target_capital.set_heat_signature(0.9)
	mock_target_capital.set_shield_percentage(0.8)
	
	# Setup ship controller with full weapon loadout
	mock_ship_controller.set_position(Vector3.ZERO)
	mock_ship_controller.set_velocity(Vector3(75, 0, 0))
	mock_ship_controller.set_energy_level(0.9)
	mock_ship_controller.set_weapon_group_available(0, true)  # Primary guns
	mock_ship_controller.set_weapon_group_available(1, true)  # Secondary guns
	mock_ship_controller.set_weapon_group_available(2, true)  # Missiles
	mock_ship_controller.set_weapon_group_available(3, true)  # Torpedoes
	mock_ship_controller.set_weapon_ammo(2, 15)  # Missiles
	mock_ship_controller.set_weapon_max_ammo(2, 20)
	mock_ship_controller.set_weapon_ammo(3, 6)   # Torpedoes
	mock_ship_controller.set_weapon_max_ammo(3, 8)
	mock_ship_controller.set_weapon_heat(0, 25.0)
	mock_ship_controller.set_weapon_heat(1, 15.0)
	
	# Setup AI agent
	mock_ai_agent.set_skill_level(0.7)
	mock_ai_agent.set_target_priority(mock_target_fighter, 0.6)
	mock_ai_agent.set_target_priority(mock_target_capital, 0.9)
	
	# Connect all components to mocks
	_setup_component(weapon_selector)
	_setup_component(weapon_firer)
	_setup_component(ammo_conserver)
	_setup_component(special_weapon)

func after_test():
	weapon_selector = null
	weapon_firer = null
	ammo_conserver = null
	special_weapon = null
	mock_ship_controller = null
	mock_ai_agent = null
	mock_target_fighter = null
	mock_target_capital = null

func _setup_component(component):
	component.ship_controller = mock_ship_controller
	component.ai_agent = mock_ai_agent
	component._setup()

func test_complete_fighter_engagement_workflow():
	"""Test complete weapon management workflow against fighter target"""
	
	# Set fighter as current target
	mock_ai_agent.set_current_target(mock_target_fighter)
	
	# Step 1: Weapon selection
	var selection_result = weapon_selector.execute_wcs_action(0.1)
	assert_that(selection_result).is_equal(1)  # SUCCESS
	
	var selected_weapon = weapon_selector.get_current_weapon_selection()
	# Should select primary guns or missiles for fighter
	assert_that(selected_weapon).is_in([SelectWeaponAction.WeaponType.PRIMARY_GUNS, SelectWeaponAction.WeaponType.MISSILES])
	
	# Step 2: Ammunition conservation check
	var conservation_result = ammo_conserver.execute_wcs_action(0.1)
	assert_that(conservation_result).is_equal(1)  # SUCCESS
	
	var conservation_recs = ammo_conserver.get_conservation_recommendations()
	assert_that(conservation_recs).is_not_empty()
	
	# Step 3: Weapon firing
	weapon_firer.fire_discipline = FireWeaponAction.FireDiscipline.STANDARD
	weapon_firer.min_hit_probability = 0.3
	var firing_result = weapon_firer.execute_wcs_action(0.1)
	
	# Should either fire successfully or continue tracking
	assert_that(firing_result).is_in([1, 2])  # SUCCESS or RUNNING
	
	if firing_result == 1:
		var firing_stats = weapon_firer.get_firing_statistics()
		assert_that(firing_stats["shots_fired"]).is_greater(0)

func test_complete_capital_ship_engagement_workflow():
	"""Test complete weapon management workflow against capital ship target"""
	
	# Set capital ship as current target
	mock_ai_agent.set_current_target(mock_target_capital)
	
	# Step 1: Weapon selection should prefer torpedoes for capital ship
	var selection_result = weapon_selector.execute_wcs_action(0.1)
	assert_that(selection_result).is_equal(1)  # SUCCESS
	
	var selected_weapon = weapon_selector.get_current_weapon_selection()
	# Should prefer torpedoes or secondary guns for capital ship
	assert_that(selected_weapon).is_in([SelectWeaponAction.WeaponType.TORPEDOES, SelectWeaponAction.WeaponType.SECONDARY_GUNS])
	
	# Step 2: Special weapon usage (if torpedo selected)
	if selected_weapon == SelectWeaponAction.WeaponType.TORPEDOES:
		special_weapon.weapon_type = SpecialWeaponAction.SpecialWeaponType.HEAVY_TORPEDO
		special_weapon.target_priority_threshold = 0.8
		
		var special_result = special_weapon.execute_wcs_action(0.1)
		# Should start lock acquisition process
		assert_that(special_result).is_in([1, 2])  # SUCCESS or RUNNING (lock in progress)
		
		# Continue lock acquisition
		var lock_result = special_weapon.execute_wcs_action(2.0)  # Allow time for lock
		var lock_status = special_weapon.get_lock_status()
		
		if lock_status["lock_established"]:
			assert_that(lock_status["lock_quality"]).is_greater(0.5)
	
	# Step 3: Conservation should be more lenient for high-priority capital ship
	ammo_conserver.conservation_mode = ConserveAmmoAction.ConservationMode.OPTIMAL_USAGE
	var conservation_result = ammo_conserver.execute_wcs_action(0.1)
	assert_that(conservation_result).is_equal(1)
	
	var torpedo_conservation = ammo_conserver._should_conserve_weapon(3, {
		"target_priority": ConserveAmmoAction.TargetPriority.CRITICAL_PRIORITY,
		"threat_level": 0.9,
		"resource_sufficiency": 0.6
	})
	# Should not conserve torpedoes for critical capital ship target
	assert_that(torpedo_conservation).is_false()

func test_resource_depletion_scenario():
	"""Test weapon management when resources are depleted"""
	
	# Setup low resource scenario
	mock_ship_controller.set_energy_level(0.2)  # Low energy
	mock_ship_controller.set_weapon_ammo(2, 2)  # Very low missiles
	mock_ship_controller.set_weapon_ammo(3, 1)  # Very low torpedoes
	mock_ai_agent.set_current_target(mock_target_fighter)
	
	# Conservation should trigger emergency mode
	ammo_conserver.auto_conservation_adjustment = true
	var conservation_result = ammo_conserver.execute_wcs_action(0.1)
	assert_that(conservation_result).is_equal(1)
	
	# Should switch to emergency conservation
	assert_that(ammo_conserver.conservation_mode).is_equal(ConserveAmmoAction.ConservationMode.EMERGENCY_RESERVE)
	
	# Weapon selection should avoid limited ammo weapons
	weapon_selector.selection_criteria = SelectWeaponAction.SelectionCriteria.AMMUNITION_EFFICIENCY
	var selection_result = weapon_selector.execute_wcs_action(0.1)
	assert_that(selection_result).is_equal(1)
	
	var selected_weapon = weapon_selector.get_current_weapon_selection()
	# Should prefer energy weapons when ammo is low
	assert_that(selected_weapon).is_equal(SelectWeaponAction.WeaponType.PRIMARY_GUNS)

func test_multi_target_engagement_coordination():
	"""Test weapon management with multiple targets requiring coordination"""
	
	# Create additional targets
	var mock_target_bomber = MockTarget.new()
	mock_target_bomber.set_ship_class("bomber")
	mock_target_bomber.set_position(Vector3(1200, 0, 0))
	mock_target_bomber.set_velocity(Vector3(80, 0, 0))
	mock_target_bomber.set_mass(2000.0)
	
	# Setup AI agent with multiple detected enemies
	mock_ai_agent.set_detected_enemies([mock_target_fighter, mock_target_bomber, mock_target_capital])
	mock_ai_agent.set_target_priority(mock_target_bomber, 0.7)
	
	# Test target switching logic with weapon considerations
	var engagement_results = []
	
	# Engage fighter first (close range)
	mock_ai_agent.set_current_target(mock_target_fighter)
	var fighter_selection = weapon_selector.execute_wcs_action(0.1)
	engagement_results.append({"target": "fighter", "weapon": weapon_selector.get_current_weapon_selection()})
	
	# Switch to bomber (medium range)
	mock_ai_agent.set_current_target(mock_target_bomber)
	weapon_selector.last_selection_time = 0.0  # Reset cache
	var bomber_selection = weapon_selector.execute_wcs_action(0.1)
	engagement_results.append({"target": "bomber", "weapon": weapon_selector.get_current_weapon_selection()})
	
	# Switch to capital ship (long range)
	mock_ai_agent.set_current_target(mock_target_capital)
	weapon_selector.last_selection_time = 0.0  # Reset cache
	var capital_selection = weapon_selector.execute_wcs_action(0.1)
	engagement_results.append({"target": "capital", "weapon": weapon_selector.get_current_weapon_selection()})
	
	assert_that(engagement_results).has_size(3)
	
	# Verify weapon selection adapts to target types
	var fighter_weapon = engagement_results[0]["weapon"]
	var capital_weapon = engagement_results[2]["weapon"]
	
	# Capital ship should get different weapon selection than fighter
	if capital_weapon == SelectWeaponAction.WeaponType.TORPEDOES:
		assert_that(fighter_weapon).is_not_equal(SelectWeaponAction.WeaponType.TORPEDOES)

func test_firing_solution_accuracy_with_weapon_selection():
	"""Test firing solution calculation accuracy across different weapon types"""
	
	mock_ai_agent.set_current_target(mock_target_fighter)
	
	# Test primary gun firing solution
	weapon_selector.force_weapon_selection(SelectWeaponAction.WeaponType.PRIMARY_GUNS)
	weapon_firer.current_weapon_group = 0
	
	var primary_solution = weapon_firer._calculate_firing_solution(mock_target_fighter, 0.1)
	assert_that(primary_solution).contains_key("hit_probability")
	assert_that(primary_solution).contains_key("weapon_group")
	assert_that(primary_solution["weapon_group"]).is_equal(0)
	
	var primary_hit_prob = primary_solution["hit_probability"]
	
	# Test missile firing solution (should be different)
	weapon_selector.force_weapon_selection(SelectWeaponAction.WeaponType.MISSILES)
	weapon_firer.current_weapon_group = 2
	
	var missile_solution = weapon_firer._calculate_firing_solution(mock_target_fighter, 0.1)
	assert_that(missile_solution["weapon_group"]).is_equal(2)
	
	# Firing solutions should account for weapon characteristics
	assert_that(primary_solution).is_not_equal(missile_solution)

func test_advanced_firing_solution_integration():
	"""Test integration with AdvancedFiringSolutions for complex scenarios"""
	
	mock_ai_agent.set_current_target(mock_target_capital)
	
	# Test torpedo firing solution calculation
	var torpedo_solution = AdvancedFiringSolutions.calculate_firing_solution(
		mock_ship_controller.get_position(),
		mock_ship_controller.get_velocity(),
		mock_target_capital.global_position,
		mock_target_capital.get_velocity(),
		AdvancedFiringSolutions.WeaponClass.TORPEDO,
		{
			"projectile_speed": 600.0,
			"lock_time": 3.0,
			"guidance_accuracy": 0.7
		},
		{
			"velocity": mock_target_capital.get_velocity(),
			"size_factor": mock_target_capital.get_mass() / 1000.0,
			"evasion_capability": 0.2
		}
	)
	
	assert_that(torpedo_solution).contains_key("has_solution")
	assert_that(torpedo_solution).contains_key("hit_probability")
	assert_that(torpedo_solution).contains_key("effectiveness_rating")
	assert_that(torpedo_solution).contains_key("weapon_class")
	assert_that(torpedo_solution["weapon_class"]).is_equal("torpedo")
	
	# Should have reasonable hit probability for large, slow target
	assert_that(torpedo_solution["hit_probability"]).is_greater(0.4)

func test_weapon_heat_management_integration():
	"""Test weapon heat management across firing and conservation systems"""
	
	mock_ai_agent.set_current_target(mock_target_fighter)
	
	# Simulate sustained fire causing heat buildup
	mock_ship_controller.set_weapon_heat(0, 85.0)  # High heat
	weapon_firer.heat_threshold = 0.8
	weapon_firer.current_weapon_group = 0
	
	# Conservation should recognize thermal constraints
	var conservation_result = ammo_conserver.execute_wcs_action(0.1)
	assert_that(conservation_result).is_equal(1)
	
	# Firing should be constrained by heat
	weapon_firer.fire_discipline = FireWeaponAction.FireDiscipline.STANDARD
	var firing_solution = weapon_firer._calculate_firing_solution(mock_target_fighter, 0.1)
	var should_fire = weapon_firer._evaluate_firing_decision(mock_target_fighter, firing_solution)
	
	# Should not fire due to heat constraints
	assert_that(should_fire).is_false()
	
	# Weapon selection should consider heat when selecting weapons
	weapon_selector.force_weapon_selection(SelectWeaponAction.WeaponType.SECONDARY_GUNS)  # Switch to cooler weapon
	var selection_valid = weapon_selector._validate_weapon_selection(SelectWeaponAction.WeaponType.SECONDARY_GUNS, mock_target_fighter)
	assert_that(selection_valid).is_true()

func test_emergency_combat_scenario():
	"""Test weapon management under emergency combat conditions"""
	
	# Setup emergency scenario
	mock_ship_controller.set_energy_level(0.15)  # Critical energy
	mock_ship_controller.set_weapon_ammo(2, 1)   # Critical missiles
	mock_ship_controller.set_weapon_ammo(3, 0)   # No torpedoes
	mock_ship_controller.set_weapon_heat(0, 90.0)  # Overheated primary
	
	# High threat target
	mock_target_fighter.set_threat_rating(0.9)
	mock_ai_agent.set_current_target(mock_target_fighter)
	mock_ai_agent.set_target_priority(mock_target_fighter, 0.95)
	
	# Conservation should go to emergency mode
	ammo_conserver.auto_conservation_adjustment = true
	var conservation_result = ammo_conserver.execute_wcs_action(0.1)
	assert_that(conservation_result).is_equal(1)
	
	# Should trigger emergency conservation
	assert_that(ammo_conserver.conservation_mode).is_equal(ConserveAmmoAction.ConservationMode.EMERGENCY_RESERVE)
	
	# Weapon selection should adapt to constraints
	weapon_selector.selection_criteria = SelectWeaponAction.SelectionCriteria.ENERGY_MANAGEMENT
	var selection_result = weapon_selector.execute_wcs_action(0.1)
	assert_that(selection_result).is_equal(1)
	
	# Should still be able to select viable weapon despite constraints
	var selected_weapon = weapon_selector.get_current_weapon_selection()
	assert_that(selected_weapon).is_not_null()
	
	# Validate emergency engagement capability
	var weapon_valid = weapon_selector._validate_weapon_selection(selected_weapon, mock_target_fighter)
	assert_that(weapon_valid).is_true()

func test_weapon_effectiveness_learning():
	"""Test weapon effectiveness tracking and learning across components"""
	
	mock_ai_agent.set_current_target(mock_target_fighter)
	
	# Record some weapon effectiveness data
	weapon_selector.record_weapon_effectiveness(SelectWeaponAction.WeaponType.PRIMARY_GUNS, 0.8)
	weapon_selector.record_weapon_effectiveness(SelectWeaponAction.WeaponType.MISSILES, 0.6)
	weapon_selector.record_weapon_effectiveness(SelectWeaponAction.WeaponType.PRIMARY_GUNS, 0.9)
	
	# Selection should consider historical effectiveness
	weapon_selector.auto_weapon_selection = true
	var selection_result = weapon_selector.execute_wcs_action(0.1)
	assert_that(selection_result).is_equal(1)
	
	# Check that historical data is being used
	var weapon_info = weapon_selector.get_weapon_selection_info()
	assert_that(weapon_info).contains_key("effectiveness_history")
	
	var primary_history = weapon_info["effectiveness_history"][SelectWeaponAction.WeaponType.PRIMARY_GUNS]
	assert_that(primary_history).has_size(2)
	assert_that(primary_history).contains(0.8)
	assert_that(primary_history).contains(0.9)

func test_complete_mission_scenario():
	"""Test complete weapon management through a simulated mission scenario"""
	
	var mission_log = []
	
	# Phase 1: Long-range intercept with missiles
	mock_ai_agent.set_current_target(mock_target_fighter)
	mock_target_fighter.set_position(Vector3(2500, 0, 0))  # Long range
	
	weapon_selector.execute_wcs_action(0.1)
	var phase1_weapon = weapon_selector.get_current_weapon_selection()
	mission_log.append({"phase": "intercept", "weapon": phase1_weapon, "range": "long"})
	
	# Phase 2: Close combat with energy weapons
	mock_target_fighter.set_position(Vector3(400, 0, 0))  # Close range
	weapon_selector.last_selection_time = 0.0  # Force reselection
	weapon_selector.execute_wcs_action(0.1)
	var phase2_weapon = weapon_selector.get_current_weapon_selection()
	mission_log.append({"phase": "dogfight", "weapon": phase2_weapon, "range": "close"})
	
	# Phase 3: Capital ship assault with special weapons
	mock_ai_agent.set_current_target(mock_target_capital)
	weapon_selector.last_selection_time = 0.0  # Force reselection
	weapon_selector.execute_wcs_action(0.1)
	var phase3_weapon = weapon_selector.get_current_weapon_selection()
	mission_log.append({"phase": "assault", "weapon": phase3_weapon, "range": "long"})
	
	# Verify mission adaptation
	assert_that(mission_log).has_size(3)
	
	# Weapons should adapt to engagement phases
	assert_that(phase1_weapon).is_not_equal(phase2_weapon)  # Different weapons for different ranges
	
	# Resource usage should be tracked throughout
	var resource_status = ammo_conserver.get_resource_status()
	assert_that(resource_status["resource_levels"]).is_not_empty()

# Mock classes with enhanced functionality for integration testing

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
	var launch_special_weapon_success: bool = true
	var fire_calls: Array = []
	var launch_calls: Array = []
	var active_weapon_group: int = 0
	
	func set_position(pos: Vector3): position = pos
	func set_velocity(vel: Vector3): velocity = vel
	func set_forward_vector(forward: Vector3): forward_vector = forward
	func set_energy_level(level: float): energy_level = level
	func set_weapon_group_available(group: int, available: bool): weapon_groups[group] = available
	func set_weapon_heat(group: int, heat: float): weapon_heat[group] = heat
	func set_weapon_ammo(group: int, ammo: int): weapon_ammo[group] = ammo
	func set_weapon_max_ammo(group: int, max_ammo: int): weapon_max_ammo[group] = max_ammo
	func set_fire_weapon_success(success: bool): fire_weapon_success = success
	func set_launch_special_weapon_success(success: bool): launch_special_weapon_success = success
	
	func get_position() -> Vector3: return position
	func get_velocity() -> Vector3: return velocity
	func get_forward_vector() -> Vector3: return forward_vector
	func get_energy_level() -> float: return energy_level
	func has_weapon_group(group: int) -> bool: return weapon_groups.get(group, true)
	func get_weapon_heat(group: int) -> float: return weapon_heat.get(group, 0.0)
	func get_weapon_ammo(group: int) -> int: return weapon_ammo.get(group, 10)
	func get_weapon_max_ammo(group: int) -> int: return weapon_max_ammo.get(group, 20)
	func get_active_weapon_group() -> int: return active_weapon_group
	func is_weapon_system_operational(group: int) -> bool: return true
	func get_countermeasure_count(type: String) -> int: return 10
	
	func set_active_weapon_group(group: int): active_weapon_group = group
	func set_targeting_mode(mode: String): pass
	
	func fire_weapon_at_point(group: int, point: Vector3, shots: int) -> bool:
		fire_calls.append({"group": group, "point": point, "shots": shots})
		return fire_weapon_success
	
	func fire_weapons(target: Node3D) -> bool:
		fire_calls.append({"target": target})
		return fire_weapon_success
	
	func launch_special_weapon(group: int, target: Node3D, params: Dictionary) -> bool:
		launch_calls.append({"group": group, "target": target, "params": params})
		return launch_special_weapon_success

class MockAIAgent:
	var current_target: Node3D
	var skill_level: float = 0.7
	var target_priorities: Dictionary = {}
	var detected_enemies: Array = []
	var nearby_allies: Array = []
	var selected_weapon_group: int = 0
	
	func set_current_target(target: Node3D): current_target = target
	func set_skill_level(level: float): skill_level = level
	func set_target_priority(target: Node3D, priority: float): target_priorities[target] = priority
	func set_detected_enemies(enemies: Array): detected_enemies = enemies
	func set_nearby_allies(allies: Array): nearby_allies = allies
	func set_selected_weapon_group(group: int): selected_weapon_group = group
	
	func get_current_target() -> Node3D: return current_target
	func get_skill_level() -> float: return skill_level
	func get_target_priority(target: Node3D) -> float: return target_priorities.get(target, 0.5)
	func get_target_mission_priority(target: Node3D) -> float: return target_priorities.get(target, 0.5)
	func get_detected_enemies() -> Array: return detected_enemies
	func get_nearby_allies() -> Array: return nearby_allies
	func get_selected_weapon_group() -> int: return selected_weapon_group
	func get_energy_level() -> float: return 0.8
	func get_mission_phase() -> String: return "combat"

class MockTarget extends Node3D:
	var ship_class: String = "fighter"
	var velocity: Vector3 = Vector3.ZERO
	var mass: float = 1000.0
	var heat_signature: float = 0.5
	var radar_signature: float = 0.5
	var shield_percentage: float = 1.0
	var damage_level: float = 0.0
	var threat_rating: float = 0.5
	var armor_rating: float = 1.0
	var health_percentage: float = 1.0
	
	func set_ship_class(cls: String): ship_class = cls
	func set_velocity(vel: Vector3): velocity = vel
	func set_mass(m: float): mass = m
	func set_heat_signature(sig: float): heat_signature = sig
	func set_radar_signature(sig: float): radar_signature = sig
	func set_shield_percentage(shields: float): shield_percentage = shields
	func set_damage_level(damage: float): damage_level = damage
	func set_threat_rating(rating: float): threat_rating = rating
	func set_armor_rating(armor: float): armor_rating = armor
	func set_health_percentage(health: float): health_percentage = health
	
	func get_ship_class() -> String: return ship_class
	func get_velocity() -> Vector3: return velocity
	func get_mass() -> float: return mass
	func get_heat_signature() -> float: return heat_signature
	func get_radar_signature() -> float: return radar_signature
	func get_shield_percentage() -> float: return shield_percentage
	func get_damage_level() -> float: return damage_level
	func get_threat_rating() -> float: return threat_rating
	func get_armor_rating() -> float: return armor_rating
	func get_health_percentage() -> float: return health_percentage