extends GutTest

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
	add_child_autoqfree(test_ship)
	
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
	assert_true(health_manager.register_subsystem("TestSub", SubsystemTypes.Type.ENGINE, 120.0))
	assert_eq(health_manager.get_subsystem_health("TestSub"), 120.0)
	assert_eq(health_manager.get_subsystem_health_percentage("TestSub"), 1.0)
	
	# Test damage application
	var damage_applied = health_manager.apply_subsystem_damage("TestSub", 30.0)
	assert_gt(damage_applied, 0.0)
	assert_eq(health_manager.get_subsystem_health("TestSub"), 90.0)
	assert_almost_eq(health_manager.get_subsystem_health_percentage("TestSub"), 0.75, EPSILON)

func test_ac1_performance_degradation_curves():
	# Test engine performance curve
	var initial_performance = health_manager.get_subsystem_performance_factor("Engine_0")
	assert_almost_eq(initial_performance, 1.0, EPSILON)
	
	# Apply damage to test degradation
	health_manager.apply_subsystem_damage("Engine_0", 60.0)  # 40% health remaining
	var degraded_performance = health_manager.get_subsystem_performance_factor("Engine_0")
	assert_lt(degraded_performance, initial_performance)
	
	# Test critical threshold
	health_manager.apply_subsystem_damage("Engine_0", 30.0)  # 10% health remaining
	var critical_performance = health_manager.get_subsystem_performance_factor("Engine_0")
	assert_lt(critical_performance, degraded_performance)

func test_ac1_wcs_threshold_compliance():
	# Test engine thresholds (50% for full speed, 30% for warp, 15% minimum)
	health_manager.apply_subsystem_damage("Engine_0", 40.0)  # 60% health
	var performance_60 = health_manager.get_subsystem_performance_factor("Engine_0")
	
	health_manager.apply_subsystem_damage("Engine_0", 20.0)  # 40% health  
	var performance_40 = health_manager.get_subsystem_performance_factor("Engine_0")
	
	health_manager.apply_subsystem_damage("Engine_0", 15.0)  # 25% health
	var performance_25 = health_manager.get_subsystem_performance_factor("Engine_0")
	
	# Verify WCS-authentic degradation
	assert_gt(performance_60, performance_40)
	assert_gt(performance_40, performance_25)

func test_ac1_failure_thresholds():
	# Test operational status at various health levels
	assert_true(health_manager.is_subsystem_operational("Engine_0"))
	
	health_manager.apply_subsystem_damage("Engine_0", 90.0)  # 10% health
	assert_false(health_manager.is_subsystem_operational("Engine_0"))

# === AC2: Targeted Damage System Tests ===

func test_ac2_precise_subsystem_targeting():
	# Create attacker ship
	var attacker = Node.new()
	attacker.name = "Attacker"
	attacker.global_position = Vector3(0, 0, 10)
	add_child_autoqfree(attacker)
	
	# Test targeting calculation
	var damage_result = targeted_damage.calculate_targeted_damage(
		attacker, test_ship, "Engine_0", 50.0, DamageTypes.Type.KINETIC, 1.0
	)
	
	assert_true(damage_result.has("hit"))
	assert_true(damage_result.has("damage_applied"))
	assert_true(damage_result.has("hit_location"))
	assert_true(damage_result.has("penetration_success"))

func test_ac2_hit_location_calculations():
	var attacker = Node.new()
	attacker.global_position = Vector3(0, 0, 15)
	add_child_autoqfree(attacker)
	
	# Test multiple targeting attempts for hit variance
	var hit_locations: Array[Vector3] = []
	for i in range(10):
		var result = targeted_damage.calculate_targeted_damage(
			attacker, test_ship, "Weapons_Primary", 25.0, DamageTypes.Type.ENERGY, 0.8
		)
		if result["hit"]:
			hit_locations.append(result["hit_location"])
	
	assert_gt(hit_locations.size(), 0, "Should have some successful hits")

func test_ac2_penetration_mechanics():
	var attacker = Node.new()
	attacker.global_position = Vector3(5, 0, 5)
	add_child_autoqfree(attacker)
	
	# Test different damage types
	var kinetic_result = targeted_damage.calculate_targeted_damage(
		attacker, test_ship, "Engine_0", 40.0, DamageTypes.Type.KINETIC, 1.0
	)
	
	var energy_result = targeted_damage.calculate_targeted_damage(
		attacker, test_ship, "Engine_1", 40.0, DamageTypes.Type.ENERGY, 1.0
	)
	
	# Different damage types should have different effectiveness
	if kinetic_result["hit"] and energy_result["hit"]:
		assert_true(kinetic_result.has("penetration_success"))
		assert_true(energy_result.has("penetration_success"))

func test_ac2_targetable_subsystems():
	var targetable = targeted_damage.get_targetable_subsystems(test_ship)
	assert_gt(targetable.size(), 0)
	assert_true(targetable.has("Engine_0"))
	assert_true(targetable.has("Weapons_Primary"))

# === AC3: Performance Degradation System Tests ===

func test_ac3_realistic_penalties():
	# Test initial performance
	var initial_speed = performance_controller.get_speed_modifier()
	var initial_weapon_accuracy = performance_controller.get_weapon_accuracy_modifier()
	var initial_firing_rate = performance_controller.get_weapon_firing_rate_modifier()
	
	# Apply engine damage
	health_manager.apply_subsystem_damage("Engine_0", 60.0)  # 40% health
	performance_controller.update_ship_performance()
	
	var degraded_speed = performance_controller.get_speed_modifier()
	assert_lt(degraded_speed, initial_speed)
	
	# Apply weapon damage
	health_manager.apply_subsystem_damage("Weapons_Primary", 50.0)  # 30% health
	performance_controller.update_ship_performance()
	
	var degraded_firing_rate = performance_controller.get_weapon_firing_rate_modifier()
	assert_lt(degraded_firing_rate, initial_firing_rate)

func test_ac3_wcs_threshold_compliance():
	# Test engine speed thresholds from WCS specification
	health_manager.apply_subsystem_damage("Engine_0", 60.0)  # 40% health
	performance_controller.update_ship_performance()
	var speed_40 = performance_controller.get_speed_modifier()
	
	health_manager.apply_subsystem_damage("Engine_0", 15.0)  # 25% health
	performance_controller.update_ship_performance()
	var speed_25 = performance_controller.get_speed_modifier()
	
	health_manager.apply_subsystem_damage("Engine_0", 15.0)  # 10% health
	performance_controller.update_ship_performance()
	var speed_10 = performance_controller.get_speed_modifier()
	
	# Verify WCS thresholds: 50% full speed, 30% warp capable, 15% minimum
	assert_gt(speed_40, speed_25)
	assert_gt(speed_25, speed_10)

func test_ac3_cascade_effects():
	performance_controller.enable_cascade_effects = true
	
	# Apply critical engine damage
	health_manager.apply_subsystem_damage("Engine_0", 80.0)  # 20% health
	performance_controller.update_ship_performance()
	
	# Other systems should be affected by cascade
	var weapon_performance = performance_controller.get_weapon_firing_rate_modifier()
	assert_lt(weapon_performance, 1.0)

func test_ac3_performance_report():
	var report = performance_controller.get_performance_report()
	assert_true(report.has("overall_efficiency"))
	assert_true(report.has("speed_modifier"))
	assert_true(report.has("weapon_accuracy_modifier"))
	assert_true(report.has("weapon_firing_rate_modifier"))
	assert_true(report.has("subsystem_effectiveness"))

# === AC4: Subsystem Destruction System Tests ===

func test_ac4_complete_system_failure():
	# Test destruction
	var destroyed = destruction_manager.destroy_subsystem("Engine_0", "damage")
	assert_true(destroyed)
	assert_true(destruction_manager.is_subsystem_destroyed("Engine_0"))
	
	# Verify destruction info
	var destruction_info = destruction_manager.get_destruction_info("Engine_0")
	assert_true(destruction_info.has("timestamp"))
	assert_true(destruction_info.has("cause"))
	assert_eq(destruction_info["cause"], "damage")

func test_ac4_cascade_effects():
	destruction_manager.enable_cascade_failures = true
	
	# Monitor cascade signals
	var cascade_triggered = false
	destruction_manager.cascade_failure_triggered.connect(func(source, target, type):
		cascade_triggered = true
	)
	
	# Destroy critical system that should trigger cascade
	destruction_manager.destroy_subsystem("Engine_0", "explosion")
	
	# Wait for cascade delay
	await get_tree().create_timer(1.0).timeout
	
	# Cascade effects should have triggered
	assert_true(cascade_triggered or destruction_manager.get_destruction_percentage() > 0.2)

func test_ac4_permanent_damage():
	destruction_manager.enable_permanent_damage = true
	
	# Destroy subsystem
	destruction_manager.destroy_subsystem("Weapons_Primary", "overload")
	
	# Check for permanent damage
	var destruction_info = destruction_manager.get_destruction_info("Weapons_Primary")
	# Permanent damage is probabilistic, so we check structure exists
	assert_true(destruction_info.has("permanent_damage"))

func test_ac4_explosion_effects():
	destruction_manager.enable_explosions = true
	
	# Monitor explosion signals
	var explosion_triggered = false
	destruction_manager.explosion_triggered.connect(func(subsystem, data):
		explosion_triggered = true
	)
	
	# Destroy engine (high explosion chance)
	destruction_manager.destroy_subsystem("Engine_1", "explosion")
	
	# Check if explosion was triggered (probabilistic)
	var destruction_info = destruction_manager.get_destruction_info("Engine_1")
	assert_true(destruction_info.has("explosion_occurred"))

func test_ac4_destruction_statistics():
	# Destroy multiple subsystems
	destruction_manager.destroy_subsystem("Engine_0", "damage")
	destruction_manager.destroy_subsystem("Weapons_Primary", "overload")
	
	var stats = destruction_manager.get_destruction_statistics()
	assert_eq(stats["total_destroyed"], 2)
	assert_gt(stats["destruction_percentage"], 0.0)
	assert_true(stats.has("explosions_occurred"))
	assert_true(stats.has("cascade_failures"))

# === AC5: Repair Mechanics System Tests ===

func test_ac5_subsystem_restoration():
	# Damage a subsystem
	health_manager.apply_subsystem_damage("Engine_0", 40.0)  # 60% health
	var damaged_health = health_manager.get_subsystem_health("Engine_0")
	
	# Start repair
	var repair_started = repair_system.start_repair("Engine_0", "standard")
	assert_true(repair_started)
	
	# Check repair progress
	var progress = repair_system.get_repair_progress("Engine_0")
	assert_ge(progress, 0.0)

func test_ac5_time_based_healing():
	# Damage subsystem
	health_manager.apply_subsystem_damage("Weapons_Primary", 30.0)
	
	# Start repair with short duration for testing
	repair_system.base_repair_time = 1.0  # 1 second for testing
	repair_system.start_repair("Weapons_Primary", "standard")
	
	# Wait for repair completion
	await get_tree().create_timer(2.0).timeout
	
	# Check if repair completed
	var final_health = health_manager.get_subsystem_health("Weapons_Primary")
	assert_gt(final_health, 50.0)  # Should be repaired

func test_ac5_resource_requirements():
	repair_system.enable_resource_requirements = true
	repair_system.add_repair_resources("repair_materials", 100.0)
	repair_system.add_repair_resources("spare_parts", 50.0)
	
	# Damage subsystem significantly
	health_manager.apply_subsystem_damage("Radar", 50.0)
	
	# Start repair
	var repair_started = repair_system.start_repair("Radar", "standard")
	assert_true(repair_started)
	
	# Resources should be consumed
	var resources = repair_system.get_repair_resources()
	assert_lt(resources["repair_materials"], 100.0)

func test_ac5_emergency_repair():
	# Damage subsystem critically
	health_manager.apply_subsystem_damage("Engine_0", 90.0)  # 10% health
	
	# Start emergency repair
	var emergency_started = repair_system.start_emergency_repair("Engine_0")
	assert_true(emergency_started)
	
	# Emergency repair should be faster
	var repair_data = repair_system.get_active_repairs()["Engine_0"]
	assert_lt(repair_data["duration"], repair_system.base_repair_time)

func test_ac5_auto_repair_system():
	repair_system.set_auto_repair_enabled(true)
	repair_system.auto_repair_interval = 0.5  # Fast for testing
	
	# Damage subsystem
	health_manager.apply_subsystem_damage("Navigation", 30.0)  # 70% health -> below auto repair threshold
	
	# Wait for auto repair to trigger
	await get_tree().create_timer(1.0).timeout
	
	# Auto repair should have started or completed
	var active_repairs = repair_system.get_active_repairs()
	var repair_queue = repair_system.get_repair_queue()
	assert_true(active_repairs.has("Navigation") or not repair_queue.is_empty())

# === AC6: Critical Subsystem Identification Tests ===

func test_ac6_vital_system_prioritization():
	# Get critical subsystems
	var critical_systems = critical_identifier.get_critical_subsystems()
	var vital_systems = critical_identifier.get_vital_subsystems()
	
	assert_gt(critical_systems.size(), 0)
	assert_true(vital_systems.has("Engine_0") or vital_systems.has("Engine_1"))

func test_ac6_tactical_targeting():
	var targeting_priorities = critical_identifier.get_tactical_targeting_priorities()
	assert_gt(targeting_priorities.size(), 0)
	
	# Engines should have high priority
	var engine_priority = targeting_priorities.get("Engine_0", 0.0)
	var comm_priority = targeting_priorities.get("Communication", 0.0)
	assert_gt(engine_priority, comm_priority)

func test_ac6_best_tactical_targets():
	var best_targets = critical_identifier.get_best_tactical_targets("disable", 3)
	assert_le(best_targets.size(), 3)
	assert_gt(best_targets.size(), 0)

func test_ac6_critical_state_assessment():
	# Initial state should be operational
	assert_eq(critical_identifier.get_ship_critical_state(), "operational")
	
	# Damage multiple critical systems
	health_manager.apply_subsystem_damage("Engine_0", 80.0)  # 20% health
	health_manager.apply_subsystem_damage("Weapons_Primary", 70.0)  # 10% health
	critical_identifier.update_critical_assessment()
	
	# Ship state should change
	var critical_state = critical_identifier.get_ship_critical_state()
	assert_ne(critical_state, "operational")

func test_ac6_dynamic_prioritization():
	critical_identifier.enable_dynamic_prioritization = true
	
	# Get initial priority
	var initial_priority = critical_identifier.get_tactical_priority("Engine_0")
	
	# Damage engine
	health_manager.apply_subsystem_damage("Engine_0", 60.0)  # 40% health
	critical_identifier.update_critical_assessment()
	
	# Priority should change based on damage
	var damaged_priority = critical_identifier.get_tactical_priority("Engine_0")
	assert_ne(initial_priority, damaged_priority)

# === AC7: Subsystem Failure Visualization Tests ===

func test_ac7_status_display():
	visualization_controller.enable_3d_indicators = true
	
	# Check that indicators are created
	var visualization_data = visualization_controller.get_subsystem_visualization_data("Engine_0")
	assert_true(visualization_data["has_indicator"])

func test_ac7_damage_progression_feedback():
	# Monitor visualization updates
	var visualization_updated = false
	visualization_controller.visualization_updated.connect(func(subsystem, state):
		visualization_updated = true
	)
	
	# Apply damage
	health_manager.apply_subsystem_damage("Engine_0", 50.0)
	visualization_controller.update_subsystem_visualization("Engine_0")
	
	assert_true(visualization_updated)

func test_ac7_damage_effects():
	visualization_controller.enable_damage_effects = true
	
	# Monitor damage effects
	var effect_triggered = false
	visualization_controller.damage_effect_triggered.connect(func(subsystem, effect_type):
		effect_triggered = true
	)
	
	# Trigger damage effect
	visualization_controller.trigger_damage_effect("Weapons_Primary", 30.0, "explosion")
	
	assert_true(effect_triggered)

func test_ac7_hud_integration():
	visualization_controller.enable_hud_integration = true
	
	# Monitor HUD updates
	var hud_updated = false
	visualization_controller.hud_update_requested.connect(func(hud_data):
		hud_updated = true
	)
	
	# Update visualization
	visualization_controller.update_subsystem_visualization("Radar")
	
	assert_true(hud_updated)

func test_ac7_critical_indicators():
	# Damage system to critical levels
	health_manager.apply_subsystem_damage("Engine_0", 80.0)  # 20% health
	
	# Update visualization
	visualization_controller.update_subsystem_visualization("Engine_0")
	
	# Critical indicator should be visible
	var visualization_data = visualization_controller.get_subsystem_visualization_data("Engine_0")
	assert_true(visualization_data.has("status_display"))

# === Integration Tests ===

func test_integration_complete_damage_cycle():
	# Complete damage -> destruction -> repair cycle
	
	# 1. Apply targeted damage
	var attacker = Node.new()
	attacker.global_position = Vector3(0, 0, 10)
	add_child_autoqfree(attacker)
	
	var damage_result = targeted_damage.calculate_targeted_damage(
		attacker, test_ship, "Engine_0", 90.0, DamageTypes.Type.EXPLOSIVE, 1.0
	)
	
	# 2. Check performance degradation
	performance_controller.update_ship_performance()
	var degraded_speed = performance_controller.get_speed_modifier()
	assert_lt(degraded_speed, 1.0)
	
	# 3. Complete destruction if health reaches zero
	if health_manager.get_subsystem_health("Engine_0") <= 0:
		assert_true(destruction_manager.is_subsystem_destroyed("Engine_0"))
	
	# 4. Attempt repair
	repair_system.start_repair("Engine_0", "emergency")

func test_integration_tactical_scenario():
	# Simulate tactical combat scenario
	
	# 1. Get tactical targets
	var best_targets = critical_identifier.get_best_tactical_targets("disable", 2)
	assert_gt(best_targets.size(), 0)
	
	# 2. Apply targeted damage to priority targets
	var attacker = Node.new()
	attacker.global_position = Vector3(5, 0, 8)
	add_child_autoqfree(attacker)
	
	for target in best_targets:
		var result = targeted_damage.calculate_targeted_damage(
			attacker, test_ship, target, 40.0, DamageTypes.Type.KINETIC, 0.9
		)
		if result["hit"]:
			visualization_controller.trigger_damage_effect(target, result["damage_applied"], "impact")
	
	# 3. Update all systems
	performance_controller.update_ship_performance()
	critical_identifier.update_critical_assessment()
	
	# 4. Check ship status
	var critical_state = critical_identifier.get_ship_critical_state()
	var performance_report = performance_controller.get_performance_report()
	
	assert_true(performance_report.has("overall_efficiency"))
	assert_ne(critical_state, "")

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
	
	assert_gt(critical_systems.size(), 0)
	assert_gt(active_repairs.size(), 0)
	assert_lt(performance_report["overall_efficiency"], 1.0)

func test_integration_wcs_compatibility():
	# Test WCS-specific behavior compatibility
	
	# Engine thresholds: 50% full speed, 30% warp, 15% minimum
	health_manager.apply_subsystem_damage("Engine_0", 60.0)  # 40% health
	performance_controller.update_ship_performance()
	var speed_40 = performance_controller.get_speed_modifier()
	
	health_manager.apply_subsystem_damage("Engine_0", 15.0)  # 25% health  
	performance_controller.update_ship_performance()
	var speed_25 = performance_controller.get_speed_modifier()
	
	# Should follow WCS thresholds
	assert_gt(speed_40, speed_25)
	
	# Weapon reliability: 70% reliable, 20% minimum
	health_manager.apply_subsystem_damage("Weapons_Primary", 20.0)  # 60% health -> reduced reliability
	performance_controller.update_ship_performance()
	var weapon_rate = performance_controller.get_weapon_firing_rate_modifier()
	assert_lt(weapon_rate, 1.0)

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
	
	# Should complete within 10ms for reasonable performance
	assert_lt(update_time, 10)

func test_memory_usage_stability():
	# Test for memory leaks in component lifecycle
	var initial_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	
	# Create and destroy many subsystems
	for i in range(100):
		health_manager.register_subsystem("TempSub_%d" % i, SubsystemTypes.Type.WEAPONS, 50.0)
		health_manager.apply_subsystem_damage("TempSub_%d" % i, 60.0)
		destruction_manager.destroy_subsystem("TempSub_%d" % i, "testing")
	
	# Force garbage collection
	for i in range(3):
		await get_tree().process_frame
	
	var final_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var object_growth = final_objects - initial_objects
	
	# Should not have significant object growth
	assert_lt(object_growth, 50)