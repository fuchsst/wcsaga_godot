extends GdUnitTestSuite

## Test suite for SHIP-002: Subsystem Management and Configuration
## Validates subsystem management, damage allocation, performance effects, and SEXP integration
## Ensures WCS-authentic subsystem behavior and ship integration

# Required classes
const BaseShip = preload("res://scripts/ships/core/base_ship.gd")
const ShipClass = preload("res://addons/wcs_asset_core/resources/ship/ship_class.gd")
const SubsystemManager = preload("res://scripts/ships/subsystems/subsystem_manager.gd")
const Subsystem = preload("res://scripts/ships/subsystems/subsystem.gd")
const SubsystemDefinition = preload("res://addons/wcs_asset_core/resources/ship/subsystem_definition.gd")
const SubsystemTypes = preload("res://addons/wcs_asset_core/constants/subsystem_types.gd")

# Test objects
var test_ship: BaseShip
var test_subsystem_manager: SubsystemManager
var test_ship_class: ShipClass

func before_test() -> void:
	# Create test ship with subsystem manager
	test_ship = BaseShip.new()
	test_ship_class = ShipClass.create_default_fighter()
	
	# Initialize ship
	test_ship.initialize_ship(test_ship_class, "Test Ship")
	
	# Get subsystem manager reference
	test_subsystem_manager = test_ship.subsystem_manager

func after_test() -> void:
	if is_instance_valid(test_ship):
		test_ship.queue_free()
	test_ship = null
	test_subsystem_manager = null
	test_ship_class = null

# ============================================================================
# AC1: SubsystemManager handles engine, weapon, shield, sensor, communication, 
#      and navigation subsystems with WCS-authentic types
# ============================================================================

func test_ac1_subsystem_manager_handles_wcs_types():
	assert_that(test_subsystem_manager).is_not_null()
	
	# Verify subsystem manager was created and initialized
	var engine_subsystems = test_subsystem_manager.get_subsystems_by_type(SubsystemTypes.Type.ENGINE)
	var weapon_subsystems = test_subsystem_manager.get_subsystems_by_type(SubsystemTypes.Type.WEAPONS)
	var radar_subsystems = test_subsystem_manager.get_subsystems_by_type(SubsystemTypes.Type.RADAR)
	
	# Fighter should have basic subsystems
	assert_that(engine_subsystems.size()).is_greater_than(0)
	assert_that(weapon_subsystems.size()).is_greater_than(0)
	assert_that(radar_subsystems.size()).is_greater_than(0)

func test_ac1_subsystem_types_authentic():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	assert_that(engine_subsystem).is_not_null()
	assert_that(engine_subsystem.subsystem_definition.subsystem_type).is_equal(SubsystemTypes.Type.ENGINE)
	
	var weapon_subsystem = test_subsystem_manager.get_subsystem_by_name("Weapons")
	assert_that(weapon_subsystem).is_not_null()
	assert_that(weapon_subsystem.subsystem_definition.subsystem_type).is_equal(SubsystemTypes.Type.WEAPONS)
	
	var radar_subsystem = test_subsystem_manager.get_subsystem_by_name("Radar")
	assert_that(radar_subsystem).is_not_null()
	assert_that(radar_subsystem.subsystem_definition.subsystem_type).is_equal(SubsystemTypes.Type.RADAR)

func test_ac1_capital_ship_additional_subsystems():
	# Create capital ship to test additional subsystems
	var capital_ship_class = ShipClass.create_default_capital()
	var capital_ship = BaseShip.new()
	capital_ship.initialize_ship(capital_ship_class, "Test Capital")
	
	var capital_manager = capital_ship.subsystem_manager
	
	# Capital ships should have turrets
	var turret_subsystems = capital_manager.get_subsystems_by_type(SubsystemTypes.Type.TURRET)
	assert_that(turret_subsystems.size()).is_greater_than(0)
	
	# Should have navigation and communication
	var nav_subsystems = capital_manager.get_subsystems_by_type(SubsystemTypes.Type.NAVIGATION)
	var comm_subsystems = capital_manager.get_subsystems_by_type(SubsystemTypes.Type.COMMUNICATION)
	assert_that(nav_subsystems.size()).is_greater_than(0)
	assert_that(comm_subsystems.size()).is_greater_than(0)
	
	capital_ship.queue_free()

# ============================================================================
# AC2: Subsystem health tracking affects ship performance realistically
# ============================================================================

func test_ac2_engine_damage_affects_performance():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	assert_that(engine_subsystem).is_not_null()
	
	# Initial performance should be 100%
	assert_that(test_ship.engine_performance).is_equal(1.0)
	
	# Damage engine to 50% health
	var initial_health = engine_subsystem.current_hits
	engine_subsystem.apply_damage(initial_health * 0.5)
	
	# Allow frame processing to update performance
	await Engine.get_main_loop().process_frame
	
	# Engine performance should be reduced
	assert_that(test_ship.engine_performance).is_less_than(1.0)
	assert_that(test_ship.engine_performance).is_greater_than(0.0)

func test_ac2_weapon_damage_affects_performance():
	var weapon_subsystem = test_subsystem_manager.get_subsystem_by_name("Weapons")
	assert_that(weapon_subsystem).is_not_null()
	
	# Initial performance should be 100%
	assert_that(test_ship.weapon_performance).is_equal(1.0)
	
	# Damage weapons to 30% health
	var initial_health = weapon_subsystem.current_hits
	weapon_subsystem.apply_damage(initial_health * 0.7)
	
	# Allow frame processing to update performance
	await Engine.get_main_loop().process_frame
	
	# Weapon performance should be reduced
	assert_that(test_ship.weapon_performance).is_less_than(1.0)
	assert_that(test_ship.weapon_performance).is_greater_than(0.0)

func test_ac2_shield_sensor_damage_affects_performance():
	var radar_subsystem = test_subsystem_manager.get_subsystem_by_name("Radar")
	assert_that(radar_subsystem).is_not_null()
	
	# Initial performance should be 100%
	assert_that(test_ship.shield_performance).is_equal(1.0)
	
	# Damage radar (affects shield performance)
	var initial_health = radar_subsystem.current_hits
	radar_subsystem.apply_damage(initial_health * 0.6)
	
	# Allow frame processing to update performance
	await Engine.get_main_loop().process_frame
	
	# Shield performance should be reduced due to sensor damage
	assert_that(test_ship.shield_performance).is_less_than(1.0)

# ============================================================================
# AC3: Performance degradation follows WCS curves
# ============================================================================

func test_ac3_engine_performance_curve():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var initial_health = engine_subsystem.current_hits
	
	# Test performance at different damage levels
	# 75% health
	engine_subsystem.current_hits = initial_health * 0.75
	engine_subsystem._update_performance_modifier()
	assert_that(engine_subsystem.performance_modifier).is_equal(0.75)
	
	# 50% health  
	engine_subsystem.current_hits = initial_health * 0.50
	engine_subsystem._update_performance_modifier()
	assert_that(engine_subsystem.performance_modifier).is_equal(0.50)
	
	# 25% health
	engine_subsystem.current_hits = initial_health * 0.25
	engine_subsystem._update_performance_modifier()
	assert_that(engine_subsystem.performance_modifier).is_equal(0.25)
	
	# 0% health (destroyed)
	engine_subsystem.current_hits = 0.0
	engine_subsystem._update_performance_modifier()
	assert_that(engine_subsystem.performance_modifier).is_equal(0.0)

func test_ac3_weapon_performance_minimum():
	var weapon_subsystem = test_subsystem_manager.get_subsystem_by_name("Weapons")
	var weapon_def = weapon_subsystem.subsystem_definition
	
	# Weapons should never go below 10% performance (from SubsystemTypes)
	var min_performance = SubsystemTypes.get_performance_modifier(5.0, SubsystemTypes.Type.WEAPONS)
	assert_that(min_performance).is_greater_or_equal(0.1)

func test_ac3_sensor_performance_minimum():
	var radar_subsystem = test_subsystem_manager.get_subsystem_by_name("Radar")
	
	# Sensors should never go below 20% performance (from SubsystemTypes)
	var min_performance = SubsystemTypes.get_performance_modifier(5.0, SubsystemTypes.Type.RADAR)
	assert_that(min_performance).is_greater_or_equal(0.2)

# ============================================================================
# AC4: Subsystem damage allocation uses proximity-based damage distribution
# ============================================================================

func test_ac4_proximity_damage_allocation():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var weapon_subsystem = test_subsystem_manager.get_subsystem_by_name("Weapons")
	
	var initial_engine_health = engine_subsystem.current_hits
	var initial_weapon_health = weapon_subsystem.current_hits
	
	# Apply damage at engine position (should damage engine more)
	var engine_position = engine_subsystem.global_position
	test_subsystem_manager.allocate_damage_to_subsystems(50.0, engine_position)
	
	# Engine should take more damage than weapons due to proximity
	var engine_damage = initial_engine_health - engine_subsystem.current_hits
	var weapon_damage = initial_weapon_health - weapon_subsystem.current_hits
	
	# Engine should take more damage (closer to impact)
	assert_that(engine_damage).is_greater_than(weapon_damage)

func test_ac4_proximity_falloff():
	var test_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var initial_health = test_subsystem.current_hits
	
	# Test damage at exact subsystem position (100% modifier)
	var close_damage = test_subsystem.apply_damage(10.0, test_subsystem.global_position)
	assert_that(close_damage).is_equal(10.0)
	
	# Reset health
	test_subsystem.current_hits = initial_health
	
	# Test damage far from subsystem (reduced modifier)
	var far_position = test_subsystem.global_position + Vector3(100, 100, 100)
	var far_damage = test_subsystem.apply_damage(10.0, far_position)
	assert_that(far_damage).is_less_than(10.0)

func test_ac4_damage_allocation_enabled():
	# Test that damage allocation can be enabled/disabled
	assert_that(test_subsystem_manager.damage_allocation_enabled).is_true()
	
	# Disable allocation
	test_subsystem_manager.damage_allocation_enabled = false
	var damage_applied = test_subsystem_manager.allocate_damage_to_subsystems(50.0, Vector3.ZERO)
	assert_that(damage_applied).is_equal(0.0)
	
	# Re-enable allocation
	test_subsystem_manager.damage_allocation_enabled = true
	damage_applied = test_subsystem_manager.allocate_damage_to_subsystems(50.0, Vector3.ZERO)
	assert_that(damage_applied).is_greater_than(0.0)

# ============================================================================
# AC5: Turret subsystems implement independent AI targeting
# ============================================================================

func test_ac5_turret_ai_targeting():
	# Create capital ship with turrets
	var capital_ship_class = ShipClass.create_default_capital()
	var capital_ship = BaseShip.new()
	capital_ship.initialize_ship(capital_ship_class, "Test Capital")
	
	var turret_subsystems = capital_ship.subsystem_manager.get_subsystems_by_type(SubsystemTypes.Type.TURRET)
	
	if turret_subsystems.size() > 0:
		var turret = turret_subsystems[0] as Subsystem
		assert_that(turret).is_not_null()
		assert_that(turret.subsystem_definition.is_turret()).is_true()
		
		# Turret should have targeting properties
		assert_that(turret.subsystem_definition.turret_fov).is_greater_than(0.0)
		assert_that(turret.subsystem_definition.turret_range).is_greater_than(0.0)
		assert_that(turret.subsystem_definition.turret_turn_rate).is_greater_than(0.0)
	
	capital_ship.queue_free()

func test_ac5_turret_target_prioritization():
	# Create capital ship with turrets
	var capital_ship_class = ShipClass.create_default_capital()
	var capital_ship = BaseShip.new()
	capital_ship.initialize_ship(capital_ship_class, "Test Capital")
	
	var turret_subsystems = capital_ship.subsystem_manager.get_subsystems_by_type(SubsystemTypes.Type.TURRET)
	
	if turret_subsystems.size() > 0:
		var turret = turret_subsystems[0] as Subsystem
		
		# Test target priority calculation
		var target_ship = BaseShip.new()
		target_ship.initialize_ship(ShipClass.create_default_fighter(), "Target")
		
		# Priority should be calculated based on distance, type, health
		var priority_score = turret._calculate_target_priority_score(target_ship)
		assert_that(priority_score).is_greater_than(0.0)
		
		target_ship.queue_free()
	
	capital_ship.queue_free()

func test_ac5_turret_fov_constraints():
	# Test turret field of view constraints
	var turret_def = SubsystemDefinition.create_default_turret()
	turret_def.turret_fov = 90.0  # 90 degree FOV
	
	# Create test turret
	var turret = Subsystem.new()
	turret.subsystem_definition = turret_def
	turret.turret_current_facing = Vector3.FORWARD
	
	# Target directly in front should be in FOV
	var front_target_pos = turret.global_position + Vector3.FORWARD * 10.0
	var mock_target = Node3D.new()
	mock_target.global_position = front_target_pos
	
	var in_fov = turret._is_target_in_fov(mock_target)
	assert_that(in_fov).is_true()
	
	# Target to the side (outside 90 degree FOV) should not be in FOV
	var side_target_pos = turret.global_position + Vector3.RIGHT * 10.0
	mock_target.global_position = side_target_pos
	
	in_fov = turret._is_target_in_fov(mock_target)
	assert_that(in_fov).is_false()
	
	mock_target.queue_free()
	turret.queue_free()

# ============================================================================
# AC6: Subsystem repair and recovery mechanisms restore functionality
# ============================================================================

func test_ac6_subsystem_repair_mechanism():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var initial_health = engine_subsystem.current_hits
	
	# Damage the subsystem
	engine_subsystem.apply_damage(initial_health * 0.5)
	var damaged_health = engine_subsystem.current_hits
	
	# Start repair
	var repair_started = engine_subsystem.start_repair()
	assert_that(repair_started).is_true()
	assert_that(engine_subsystem.is_repairing).is_true()
	
	# Simulate repair process
	for i in range(10):
		engine_subsystem._process_repair(0.1)  # 0.1 second intervals
	
	# Health should have improved
	assert_that(engine_subsystem.current_hits).is_greater_than(damaged_health)

func test_ac6_repair_queue_priority():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var weapon_subsystem = test_subsystem_manager.get_subsystem_by_name("Weapons")
	
	# Damage both subsystems
	engine_subsystem.apply_damage(engine_subsystem.max_hits * 0.5)
	weapon_subsystem.apply_damage(weapon_subsystem.max_hits * 0.5)
	
	# Add both to repair queue
	test_subsystem_manager.queue_subsystem_repair(weapon_subsystem)
	test_subsystem_manager.queue_subsystem_repair(engine_subsystem)
	
	# Engine should be first in queue (higher priority)
	assert_that(test_subsystem_manager.repair_queue[0]).is_equal(engine_subsystem)

func test_ac6_repair_rate_calculation():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var weapon_subsystem = test_subsystem_manager.get_subsystem_by_name("Weapons")
	
	# Engine should have faster repair rate than weapons
	var engine_rate = engine_subsystem._calculate_base_repair_rate()
	var weapon_rate = weapon_subsystem._calculate_base_repair_rate()
	
	assert_that(engine_rate).is_greater_than(weapon_rate)

func test_ac6_repair_completion():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var initial_health = engine_subsystem.current_hits
	
	# Damage and repair
	engine_subsystem.apply_damage(initial_health * 0.3)
	engine_subsystem.start_repair()
	
	# Repair to full health
	engine_subsystem.current_hits = engine_subsystem.max_hits
	engine_subsystem._process_repair(0.1)
	
	# Should no longer be repairing
	assert_that(engine_subsystem.is_repairing).is_false()
	assert_that(engine_subsystem.is_functional).is_true()

# ============================================================================
# AC7: SEXP integration enables mission scripting
# ============================================================================

func test_ac7_sexp_subsystem_functional_query():
	# Test SEXP query for subsystem functionality
	var is_functional = test_subsystem_manager.is_subsystem_functional("Engine")
	assert_that(is_functional).is_true()
	
	# Destroy engine
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	engine_subsystem.apply_damage(engine_subsystem.max_hits)
	
	# Should now be non-functional
	is_functional = test_subsystem_manager.is_subsystem_functional("Engine")
	assert_that(is_functional).is_false()

func test_ac7_sexp_subsystem_health_query():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	var initial_health = engine_subsystem.current_hits
	
	# Initial health should be 100%
	var health_percent = test_subsystem_manager.get_subsystem_health("Engine")
	assert_that(health_percent).is_equal(100.0)
	
	# Damage to 50%
	engine_subsystem.apply_damage(initial_health * 0.5)
	health_percent = test_subsystem_manager.get_subsystem_health("Engine")
	assert_that(health_percent).is_between(49.0, 51.0)  # Allow for small rounding

func test_ac7_sexp_subsystem_count_query():
	# Test counting subsystems by type
	var engine_count = test_subsystem_manager.get_subsystem_count_by_type(SubsystemTypes.Type.ENGINE)
	assert_that(engine_count).is_greater_than(0)
	
	var functional_engine_count = test_subsystem_manager.get_subsystem_count_by_type(SubsystemTypes.Type.ENGINE, true)
	assert_that(functional_engine_count).is_equal(engine_count)
	
	# Destroy an engine
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	engine_subsystem.apply_damage(engine_subsystem.max_hits)
	
	# Total count should be same, functional count should be less
	var new_total_count = test_subsystem_manager.get_subsystem_count_by_type(SubsystemTypes.Type.ENGINE)
	var new_functional_count = test_subsystem_manager.get_subsystem_count_by_type(SubsystemTypes.Type.ENGINE, true)
	
	assert_that(new_total_count).is_equal(engine_count)
	assert_that(new_functional_count).is_less_than(functional_engine_count)

func test_ac7_sexp_critical_failure_detection():
	# Initially no critical failures
	assert_that(test_subsystem_manager.has_critical_subsystem_failure()).is_false()
	
	# Destroy critical subsystem (engine)
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	engine_subsystem.apply_damage(engine_subsystem.max_hits)
	
	# Should now have critical failure
	assert_that(test_subsystem_manager.has_critical_subsystem_failure()).is_true()

func test_ac7_sexp_query_caching():
	# Test that SEXP queries are cached for performance
	var health1 = test_subsystem_manager.get_subsystem_health("Engine")
	var health2 = test_subsystem_manager.get_subsystem_health("Engine")
	
	# Should return same cached value
	assert_that(health1).is_equal(health2)
	
	# Cache should contain the query
	assert_that(test_subsystem_manager.sexp_query_cache.has("health_Engine")).is_true()

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_ship_integration_subsystem_creation():
	# Test that ship properly creates and integrates subsystems
	assert_that(test_ship.subsystem_manager).is_not_null()
	
	# Should have basic subsystems
	var subsystem_status = test_ship.subsystem_manager.get_subsystem_status()
	assert_that(subsystem_status.total_subsystems).is_greater_than(0)
	assert_that(subsystem_status.functional_subsystems).is_equal(subsystem_status.total_subsystems)

func test_ship_integration_performance_effects():
	# Test that subsystem damage affects ship performance
	var initial_engine_performance = test_ship.engine_performance
	
	# Damage engine subsystem
	test_ship.apply_subsystem_damage("Engine", 25.0)
	
	# Allow frame processing
	await Engine.get_main_loop().process_frame
	
	# Ship engine performance should be reduced
	assert_that(test_ship.engine_performance).is_less_than(initial_engine_performance)

func test_ship_integration_api_methods():
	# Test ship API methods for subsystem interaction
	var engine_health = test_ship.get_subsystem_health("Engine")
	assert_that(engine_health).is_equal(100.0)
	
	var is_functional = test_ship.is_subsystem_functional("Engine")
	assert_that(is_functional).is_true()
	
	var repair_queued = test_ship.repair_subsystem("Engine")
	assert_that(repair_queued).is_false()  # Already at full health
	
	# Damage and try repair
	test_ship.apply_subsystem_damage("Engine", 20.0)
	repair_queued = test_ship.repair_subsystem("Engine")
	assert_that(repair_queued).is_true()

func test_ship_integration_signals():
	var signal_received = false
	var received_subsystem_name = ""
	var received_damage_percent = 0.0
	
	# Connect to subsystem damage signal
	test_ship.subsystem_damaged.connect(func(name: String, damage: float):
		signal_received = true
		received_subsystem_name = name
		received_damage_percent = damage
	)
	
	# Damage a subsystem
	test_ship.apply_subsystem_damage("Engine", 25.0)
	
	# Allow signal processing
	await Engine.get_main_loop().process_frame
	
	# Should have received signal
	assert_that(signal_received).is_true()
	assert_that(received_subsystem_name).is_equal("Engine")
	assert_that(received_damage_percent).is_greater_than(0.0)

func test_ship_integration_critical_failure():
	var signal_received = false
	
	# Connect to ship disabled signal
	test_ship.ship_disabled.connect(func():
		signal_received = true
	)
	
	# Destroy critical subsystem
	test_ship.apply_subsystem_damage("Engine", 1000.0)  # Massive damage
	
	# Allow signal processing
	await Engine.get_main_loop().process_frame
	
	# Ship should be disabled
	assert_that(test_ship.is_disabled).is_true()
	assert_that(signal_received).is_true()

# ============================================================================
# ERROR HANDLING AND EDGE CASES
# ============================================================================

func test_error_handling_invalid_subsystem():
	# Test operations on non-existent subsystem
	var health = test_ship.get_subsystem_health("NonExistent")
	assert_that(health).is_equal(0.0)
	
	var is_functional = test_ship.is_subsystem_functional("NonExistent")
	assert_that(is_functional).is_false()
	
	var damage_applied = test_ship.apply_subsystem_damage("NonExistent", 50.0)
	assert_that(damage_applied).is_equal(0.0)

func test_error_handling_null_ship_class():
	# Test subsystem creation with null ship class
	var empty_ship = BaseShip.new()
	var result = empty_ship.initialize_ship(null, "Empty Ship")
	assert_that(result).is_false()
	
	empty_ship.queue_free()

func test_error_handling_destroyed_subsystem_repair():
	var engine_subsystem = test_subsystem_manager.get_subsystem_by_name("Engine")
	
	# Completely destroy subsystem
	engine_subsystem.apply_damage(engine_subsystem.max_hits)
	
	# Cannot repair completely destroyed subsystem
	var repair_started = engine_subsystem.start_repair()
	assert_that(repair_started).is_false()

func test_performance_damage_allocation():
	# Test performance with many subsystems and damage events
	var start_time = Time.get_ticks_msec()
	
	# Apply many damage events
	for i in range(100):
		test_subsystem_manager.allocate_damage_to_subsystems(1.0, Vector3(i, i, i))
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	# Should complete within reasonable time (less than 100ms)
	assert_that(duration).is_less_than(100)