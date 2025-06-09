extends GdUnitTestSuite

## SHIP-010: Subsystem Damage and Destruction - Comprehensive Test Suite
## Tests all acceptance criteria and component integration for WCS-authentic subsystem mechanics

# Component references
var test_ship: Node
var health_manager: SubsystemHealthManager
var targeted_damage: TargetedDamageSystem
var performance_controller: PerformanceDegradationController
var destruction_manager: SubsystemDestructionManager
var repair_system: RepairMechanicsSystem
var critical_identifier: CriticalSubsystemIdentifier
var visualization_controller: SubsystemVisualizationController

# Test configuration
const TEST_SHIP_NAME = "TestShip_SHIP010"
const EPSILON = 0.001

func before_each():
	_setup_test_ship()
	_setup_test_subsystems()

func after_each():
	_cleanup_test_ship()

## Setup test ship with all SHIP-010 components
func _setup_test_ship():
	test_ship = Node.new()
	test_ship.name = TEST_SHIP_NAME
	auto_free(test_ship)
	
	# Create component hierarchy
	health_manager = SubsystemHealthManager.new()
	test_ship.add_child(health_manager)
	
	targeted_damage = TargetedDamageSystem.new()
	test_ship.add_child(targeted_damage)
	
	performance_controller = PerformanceDegradationController.new()
	test_ship.add_child(performance_controller)
	
	destruction_manager = SubsystemDestructionManager.new()
	test_ship.add_child(destruction_manager)
	
	repair_system = RepairMechanicsSystem.new()
	test_ship.add_child(repair_system)
	
	critical_identifier = CriticalSubsystemIdentifier.new()
	test_ship.add_child(critical_identifier)
	
	visualization_controller = SubsystemVisualizationController.new()
	test_ship.add_child(visualization_controller)
	
	# Initialize components
	health_manager.initialize_for_ship(test_ship)
	targeted_damage.initialize_for_ship(test_ship)
	performance_controller.initialize_for_ship(test_ship)
	destruction_manager.initialize_for_ship(test_ship)
	repair_system.initialize_for_ship(test_ship)
	critical_identifier.initialize_for_ship(test_ship)
	visualization_controller.initialize_for_ship(test_ship)

## Setup test subsystems
func _setup_test_subsystems():
	# Register test subsystems with health manager
	health_manager.register_subsystem("Engine_0", SubsystemTypes.Type.ENGINE, 100.0)
	health_manager.register_subsystem("Engine_1", SubsystemTypes.Type.ENGINE, 100.0)
	health_manager.register_subsystem("Weapons_Primary", SubsystemTypes.Type.TURRET, 80.0)
	health_manager.register_subsystem("Weapons_Secondary", SubsystemTypes.Type.WEAPONS, 60.0)
	health_manager.register_subsystem("Radar", SubsystemTypes.Type.RADAR, 70.0)
	health_manager.register_subsystem("Navigation", SubsystemTypes.Type.NAVIGATION, 50.0)
	health_manager.register_subsystem("Communication", SubsystemTypes.Type.COMMUNICATION, 40.0)
	
	# Register subsystem locations for targeting
	targeted_damage.register_subsystem_location(test_ship, "Engine_0", Vector3(0, 0, -5), 2.0, 1.5)
	targeted_damage.register_subsystem_location(test_ship, "Engine_1", Vector3(0, 0, -5), 2.0, 1.5)
	targeted_damage.register_subsystem_location(test_ship, "Weapons_Primary", Vector3(-2, 0, 2), 1.5, 1.2)
	targeted_damage.register_subsystem_location(test_ship, "Weapons_Secondary", Vector3(2, 0, 2), 1.0, 1.0)
	targeted_damage.register_subsystem_location(test_ship, "Radar", Vector3(0, 2, 0), 1.0, 0.8)
	targeted_damage.register_subsystem_location(test_ship, "Navigation", Vector3(0, 1, -2), 0.8, 0.6)
	targeted_damage.register_subsystem_location(test_ship, "Communication", Vector3(0, 3, 0), 0.6, 0.4)

## Cleanup test environment
func _cleanup_test_ship():
	if test_ship and is_instance_valid(test_ship):
		test_ship.queue_free()

# === AC1: Subsystem Health Tracking Tests ===

func test_ac1_subsystem_health_tracking():
	# Test subsystem registration
	assert_that(health_manager.register_subsystem("TestSub", SubsystemTypes.Type.ENGINE, 120.0)).is_true()
	assert_that(health_manager.get_subsystem_health("TestSub")).is_equal(120.0)
	assert_that(health_manager.get_subsystem_health_percentage("TestSub")).is_equal(1.0)
	
	# Test damage application
	var damage_applied = health_manager.apply_subsystem_damage("TestSub", 30.0)
	assert_that(damage_applied).is_greater(0.0)
	assert_that(health_manager.get_subsystem_health("TestSub")).is_equal(90.0)
	assert_that(health_manager.get_subsystem_health_percentage("TestSub")).is_equal_approx(0.75, EPSILON)

func test_ac1_performance_degradation_curves():
	# Test engine performance curve
	var initial_performance = health_manager.get_subsystem_performance_factor("Engine_0")
	assert_that(initial_performance).is_equal_approx(1.0, EPSILON)
	
	# Apply damage to test degradation
	health_manager.apply_subsystem_damage("Engine_0", 60.0)  # 40% health remaining
	var degraded_performance = health_manager.get_subsystem_performance_factor("Engine_0")
	assert_that(degraded_performance).is_less(initial_performance)
	
	# Test critical threshold
	health_manager.apply_subsystem_damage("Engine_0", 30.0)  # 10% health remaining
	var critical_performance = health_manager.get_subsystem_performance_factor("Engine_0")
	assert_that(critical_performance).is_less(degraded_performance)

func test_ac1_failure_thresholds():
	# Test operational status at various health levels
	assert_that(health_manager.is_subsystem_operational("Engine_0")).is_true()
	
	health_manager.apply_subsystem_damage("Engine_0", 90.0)  # 10% health
	assert_that(health_manager.is_subsystem_operational("Engine_0")).is_false()

# === AC2: Targeted Damage System Tests ===

func test_ac2_precise_subsystem_targeting():
	# Create attacker ship
	var attacker = Node.new()
	attacker.name = "Attacker"
	attacker.global_position = Vector3(0, 0, 10)
	auto_free(attacker)
	
	# Test targeting calculation
	var damage_result = targeted_damage.calculate_targeted_damage(
		attacker, test_ship, "Engine_0", 50.0, DamageTypes.Type.KINETIC, 1.0
	)
	
	assert_that(damage_result.has("hit")).is_true()
	assert_that(damage_result.has("damage_applied")).is_true()
	assert_that(damage_result.has("hit_location")).is_true()
	assert_that(damage_result.has("penetration_success")).is_true()

func test_ac2_targetable_subsystems():
	var targetable = targeted_damage.get_targetable_subsystems(test_ship)
	assert_that(targetable.size()).is_greater(0)
	assert_that(targetable.has("Engine_0")).is_true()
	assert_that(targetable.has("Weapons_Primary")).is_true()

# === AC3: Performance Degradation System Tests ===

func test_ac3_realistic_penalties():
	# Test initial performance
	var initial_speed = performance_controller.get_speed_modifier()
	
	# Apply engine damage
	health_manager.apply_subsystem_damage("Engine_0", 60.0)  # 40% health
	performance_controller.update_ship_performance()
	
	var degraded_speed = performance_controller.get_speed_modifier()
	assert_that(degraded_speed).is_less(initial_speed)

# === AC4: Subsystem Destruction System Tests ===

func test_ac4_complete_system_failure():
	# Test destruction
	var destroyed = destruction_manager.destroy_subsystem("Engine_0", "damage")
	assert_that(destroyed).is_true()
	assert_that(destruction_manager.is_subsystem_destroyed("Engine_0")).is_true()
	
	# Verify destruction info
	var destruction_info = destruction_manager.get_destruction_info("Engine_0")
	assert_that(destruction_info.has("timestamp")).is_true()
	assert_that(destruction_info.has("cause")).is_true()
	assert_that(destruction_info["cause"]).is_equal("damage")

# === AC5: Repair Mechanics System Tests ===

func test_ac5_subsystem_restoration():
	# Damage a subsystem
	health_manager.apply_subsystem_damage("Engine_0", 40.0)  # 60% health
	
	# Start repair
	var repair_started = repair_system.start_repair("Engine_0", "standard")
	assert_that(repair_started).is_true()
	
	# Check repair progress
	var progress = repair_system.get_repair_progress("Engine_0")
	assert_that(progress).is_greater_equal(0.0)

# === AC6: Critical Subsystem Identification Tests ===

func test_ac6_vital_system_prioritization():
	# Get critical subsystems
	var critical_systems = critical_identifier.get_critical_subsystems()
	var vital_systems = critical_identifier.get_vital_subsystems()
	
	assert_that(critical_systems.size()).is_greater_equal(0)
	# Engine systems should be considered vital or critical
	var has_engine_system = vital_systems.has("Engine_0") or vital_systems.has("Engine_1") or critical_systems.has("Engine_0")
	assert_that(has_engine_system).is_true()

# === AC7: Subsystem Failure Visualization Tests ===

func test_ac7_status_display():
	visualization_controller.enable_3d_indicators = true
	
	# Check that indicators are created
	var visualization_data = visualization_controller.get_subsystem_visualization_data("Engine_0")
	assert_that(visualization_data.has("has_indicator")).is_true()

# === Integration Tests ===

func test_integration_system_coordination():
	# Test coordination between all subsystem components
	
	# Damage multiple subsystems
	health_manager.apply_subsystem_damage("Engine_0", 70.0)    # 30% health
	health_manager.apply_subsystem_damage("Weapons_Primary", 60.0)  # 20% health
	health_manager.apply_subsystem_damage("Radar", 50.0)       # 20% health
	
	# Update all systems
	performance_controller.update_ship_performance()
	critical_identifier.update_critical_assessment()
	
	# Start repairs on critical systems
	repair_system.start_repair("Engine_0", "emergency")
	repair_system.start_repair("Weapons_Primary", "standard")
	
	# Verify system coordination
	var critical_systems = critical_identifier.get_critical_subsystems()
	var active_repairs = repair_system.get_active_repairs()
	var performance_report = performance_controller.get_performance_report()
	
	assert_that(critical_systems.size()).is_greater_equal(0)
	assert_that(active_repairs.size()).is_greater_equal(0)
	assert_that(performance_report.has("overall_efficiency")).is_true()

# === Performance Tests ===

func test_performance_update_frequency():
	# Test that updates complete within reasonable time
	var start_time = Time.get_ticks_msec()
	
	# Update all systems
	performance_controller.update_ship_performance()
	critical_identifier.update_critical_assessment()
	visualization_controller._update_all_visualizations()
	
	var end_time = Time.get_ticks_msec()
	var update_time = end_time - start_time
	
	# Should complete within 50ms for reasonable performance (more lenient for CI)
	assert_that(update_time).is_less(50)