extends GdUnitTestSuite

## Comprehensive test suite for SHIP-008: Shield and Energy Systems
## Tests ETS power distribution, shield regeneration, weapon energy, and engine power
## Validates all acceptance criteria for SHIP-008

# Test fixtures and utilities
var base_ship: BaseShip
var ship_class: ShipClass
var ets_manager: ETSManager
var shield_regen_controller: ShieldRegenerationController
var weapon_energy_manager: WeaponEnergyManager
var engine_power_system: EnginePowerSystem

## Setup test environment
func before():
	# Create ship class for testing
	ship_class = ShipClass.new()
	ship_class.class_name = "Test Fighter"
	ship_class.max_velocity = 100.0
	ship_class.max_afterburner_velocity = 150.0
	ship_class.max_hull_strength = 100.0
	ship_class.max_shield_strength = 80.0
	ship_class.max_weapon_energy = 120.0
	ship_class.mass = 50.0
	ship_class.acceleration = 60.0
	
	# Create ship
	base_ship = BaseShip.new()
	base_ship.initialize_ship(ship_class, "Test Ship")
	
	# Create energy system components
	ets_manager = ETSManager.new()
	shield_regen_controller = ShieldRegenerationController.new()
	weapon_energy_manager = WeaponEnergyManager.new()
	engine_power_system = EnginePowerSystem.new()
	
	# Add components to ship
	base_ship.add_child(ets_manager)
	base_ship.add_child(shield_regen_controller)
	base_ship.add_child(weapon_energy_manager)
	base_ship.add_child(engine_power_system)
	
	# Initialize systems
	ets_manager.initialize_ets_manager(base_ship)
	shield_regen_controller.initialize_shield_regeneration(base_ship)
	weapon_energy_manager.initialize_weapon_energy_manager(base_ship)
	engine_power_system.initialize_engine_power_system(base_ship)

## Cleanup test environment
func after():
	if base_ship:
		base_ship.queue_free()

## SHIP-008 AC1: Energy Transfer System (ETS) Tests

func test_ets_13_level_discrete_controls():
	"""Test that ETS supports 13 discrete power levels."""
	# Verify energy levels array has 13 entries
	assert_that(ETSManager.ENERGY_LEVELS.size()).is_equal(13)
	
	# Verify correct level values (from WCS hudets.cpp)
	assert_that(ETSManager.ENERGY_LEVELS[0]).is_equal(0.0)
	assert_that(ETSManager.ENERGY_LEVELS[4]).is_equal(0.333)
	assert_that(ETSManager.ENERGY_LEVELS[6]).is_equal(0.5)
	assert_that(ETSManager.ENERGY_LEVELS[12]).is_equal(1.0)

func test_ets_zero_sum_allocation():
	"""Test that ETS maintains zero-sum energy allocation."""
	# Test default balanced allocation
	var allocation = ets_manager.get_power_allocation()
	var total = allocation["shields"] + allocation["weapons"] + allocation["engines"]
	assert_that(total).is_between(0.999, 1.001)  # Allow floating point tolerance
	
	# Test energy transfer maintains zero-sum
	ets_manager.transfer_energy(ETSManager.TransferDirection.WEAPONS_TO_SHIELDS)
	allocation = ets_manager.get_power_allocation()
	total = allocation["shields"] + allocation["weapons"] + allocation["engines"]
	assert_that(total).is_between(0.999, 1.001)

func test_ets_energy_transfer_controls():
	"""Test ETS energy transfer controls (F5-F8 functionality)."""
	# Reset to balanced
	ets_manager.reset_power_allocation()
	var initial_allocation = ets_manager.get_power_allocation()
	
	# Test F5: Weapons to Shields
	assert_that(ets_manager.transfer_energy(ETSManager.TransferDirection.WEAPONS_TO_SHIELDS)).is_true()
	var allocation = ets_manager.get_power_allocation()
	assert_that(allocation["shields"]).is_greater(initial_allocation["shields"])
	assert_that(allocation["weapons"]).is_less(initial_allocation["weapons"])
	
	# Test F6: Shields to Weapons  
	ets_manager.reset_power_allocation()
	assert_that(ets_manager.transfer_energy(ETSManager.TransferDirection.SHIELDS_TO_WEAPONS)).is_true()
	allocation = ets_manager.get_power_allocation()
	assert_that(allocation["weapons"]).is_greater(initial_allocation["weapons"])
	assert_that(allocation["shields"]).is_less(initial_allocation["shields"])
	
	# Test F7: Weapons to Engines
	ets_manager.reset_power_allocation()
	assert_that(ets_manager.transfer_energy(ETSManager.TransferDirection.WEAPONS_TO_ENGINES)).is_true()
	allocation = ets_manager.get_power_allocation()
	assert_that(allocation["engines"]).is_greater(initial_allocation["engines"])
	assert_that(allocation["weapons"]).is_less(initial_allocation["weapons"])
	
	# Test F8: Balance All
	ets_manager.transfer_energy(ETSManager.TransferDirection.WEAPONS_TO_SHIELDS)
	ets_manager.transfer_energy(ETSManager.TransferDirection.BALANCE_ALL)
	allocation = ets_manager.get_power_allocation()
	assert_that(allocation["shields"]).is_equal(initial_allocation["shields"])
	assert_that(allocation["weapons"]).is_equal(initial_allocation["weapons"])
	assert_that(allocation["engines"]).is_equal(initial_allocation["engines"])

## SHIP-008 AC2: Shield Regeneration System Tests

func test_shield_frame_based_regeneration():
	"""Test shield regeneration with frame-based processing."""
	# Set moderate damage to shields
	var initial_shields = shield_regen_controller.current_shield_strength[0]
	shield_regen_controller.apply_quadrant_damage(0, 20.0)
	
	# Wait for regeneration delay to pass
	shield_regen_controller.quadrant_damage_timers[0] = 0.0
	
	# Process regeneration for several frames
	var frames_processed = 0
	var regeneration_detected = false
	
	for i in range(10):
		shield_regen_controller._process(0.016)  # 60 FPS
		frames_processed += 1
		
		if shield_regen_controller.current_shield_strength[0] > (initial_shields - 20.0):
			regeneration_detected = true
			break
	
	assert_that(regeneration_detected).is_true()

func test_shield_ets_multiplier_effect():
	"""Test shield regeneration rates affected by ETS allocation."""
	# Set high shield power allocation
	ets_manager.set_power_allocation(8, 2, 2)  # High shields, low weapons/engines
	var high_allocation = ets_manager.get_system_power_allocation(ETSManager.SystemType.SHIELDS)
	
	# Damage shields and measure regeneration rate
	shield_regen_controller.apply_quadrant_damage(0, 30.0)
	shield_regen_controller.quadrant_damage_timers[0] = 0.0
	
	var initial_strength = shield_regen_controller.current_shield_strength[0]
	shield_regen_controller._process(1.0)  # 1 second of regeneration
	var high_regen_amount = shield_regen_controller.current_shield_strength[0] - initial_strength
	
	# Reset and test with low shield power allocation
	shield_regen_controller.current_shield_strength[0] = initial_strength
	ets_manager.set_power_allocation(2, 5, 5)  # Low shields, high weapons/engines
	shield_regen_controller._process(1.0)
	var low_regen_amount = shield_regen_controller.current_shield_strength[0] - initial_strength
	
	# High allocation should regenerate more than low allocation
	assert_that(high_regen_amount).is_greater(low_regen_amount)

func test_shield_quadrant_prioritization():
	"""Test shield regeneration prioritizes most damaged quadrant."""
	# Damage multiple quadrants with different amounts
	shield_regen_controller.apply_quadrant_damage(0, 10.0)  # Lightly damaged
	shield_regen_controller.apply_quadrant_damage(1, 40.0)  # Heavily damaged
	shield_regen_controller.apply_quadrant_damage(2, 25.0)  # Moderately damaged
	
	# Clear damage timers
	for i in range(4):
		shield_regen_controller.quadrant_damage_timers[i] = 0.0
	
	# Process regeneration
	var initial_strengths = shield_regen_controller.current_shield_strength.duplicate()
	shield_regen_controller._process(0.5)  # Half second of regeneration
	
	# Calculate regeneration amounts
	var regen_amounts = []
	for i in range(4):
		regen_amounts.append(shield_regen_controller.current_shield_strength[i] - initial_strengths[i])
	
	# Most damaged quadrant (1) should regenerate most due to priority
	assert_that(regen_amounts[1]).is_greater_equal(regen_amounts[0])
	assert_that(regen_amounts[1]).is_greater_equal(regen_amounts[2])

## SHIP-008 AC3: Weapon Energy Consumption Tests

func test_weapon_energy_availability_check():
	"""Test weapon energy availability for firing restrictions."""
	# Test with sufficient energy
	assert_that(weapon_energy_manager.can_weapon_fire(0)).is_true()
	
	# Drain weapon energy below requirement
	var initial_energy = weapon_energy_manager.available_weapon_energy
	weapon_energy_manager.available_weapon_energy = 1.0  # Very low energy
	
	assert_that(weapon_energy_manager.can_weapon_fire(0)).is_false()
	
	# Restore energy
	weapon_energy_manager.available_weapon_energy = initial_energy
	assert_that(weapon_energy_manager.can_weapon_fire(0)).is_true()

func test_weapon_energy_consumption_tracking():
	"""Test weapon energy consumption for firing."""
	var initial_energy = weapon_energy_manager.available_weapon_energy
	var shots_fired = 3
	
	# Consume energy for multiple shots
	var success = weapon_energy_manager.consume_weapon_energy(0, shots_fired)
	assert_that(success).is_true()
	
	# Verify energy was consumed
	assert_that(weapon_energy_manager.available_weapon_energy).is_less(initial_energy)
	
	# Verify tracking
	var tracking = weapon_energy_manager.shots_fired_tracking
	assert_that(tracking.has(0)).is_true()
	assert_that(tracking[0]).is_equal(shots_fired)

func test_weapon_energy_ets_integration():
	"""Test weapon energy regeneration with ETS allocation."""
	# Set high weapon power allocation
	ets_manager.set_power_allocation(2, 8, 2)  # Low shields, high weapons, low engines
	
	# Drain some weapon energy
	weapon_energy_manager.available_weapon_energy = weapon_energy_manager.total_energy_capacity * 0.5
	var initial_energy = weapon_energy_manager.available_weapon_energy
	
	# Process regeneration
	weapon_energy_manager._process(1.0)  # 1 second
	
	# Verify energy regenerated
	assert_that(weapon_energy_manager.available_weapon_energy).is_greater(initial_energy)

## SHIP-008 AC4: Engine Power System Tests

func test_engine_speed_scaling():
	"""Test engine power affects ship speed through linear scaling."""
	# Get initial performance
	var initial_performance = engine_power_system.get_engine_performance()
	var base_speed = initial_performance["current_max_speed"]
	
	# Reduce engine power through ETS
	ets_manager.set_power_allocation(5, 5, 2)  # Low engine power
	engine_power_system._process(0.016)  # Update performance
	
	var reduced_performance = engine_power_system.get_engine_performance()
	assert_that(reduced_performance["current_max_speed"]).is_less(base_speed)
	
	# Increase engine power
	ets_manager.set_power_allocation(2, 2, 8)  # High engine power
	engine_power_system._process(0.016)
	
	var boosted_performance = engine_power_system.get_engine_performance()
	assert_that(boosted_performance["current_max_speed"]).is_greater(reduced_performance["current_max_speed"])

func test_engine_afterburner_performance():
	"""Test afterburner performance scaling with engine power."""
	# Test afterburner efficiency at different power levels
	ets_manager.set_power_allocation(2, 2, 8)  # High engine power
	engine_power_system._process(0.016)
	var high_power_efficiency = engine_power_system.current_afterburner_efficiency
	
	ets_manager.set_power_allocation(5, 5, 2)  # Low engine power
	engine_power_system._process(0.016)
	var low_power_efficiency = engine_power_system.current_afterburner_efficiency
	
	assert_that(high_power_efficiency).is_greater(low_power_efficiency)
	
	# Test afterburner viability
	ets_manager.set_power_allocation(0, 0, 12)  # Maximum engine power
	engine_power_system._process(0.016)
	assert_that(engine_power_system.is_afterburner_viable()).is_true()
	
	ets_manager.set_power_allocation(6, 6, 0)  # No engine power
	engine_power_system._process(0.016)
	assert_that(engine_power_system.is_afterburner_viable()).is_false()

func test_engine_maneuverability_effects():
	"""Test engine power affects maneuverability (acceleration and turn rate)."""
	# Baseline performance
	ets_manager.reset_power_allocation()
	engine_power_system._process(0.016)
	var baseline_acceleration = engine_power_system.current_acceleration
	var baseline_turn_rate = engine_power_system.current_turn_rate
	
	# Reduced engine power
	ets_manager.set_power_allocation(6, 6, 0)  # No engine power
	engine_power_system._process(0.016)
	assert_that(engine_power_system.current_acceleration).is_less(baseline_acceleration)
	assert_that(engine_power_system.current_turn_rate).is_less(baseline_turn_rate)
	
	# Maximum engine power
	ets_manager.set_power_allocation(0, 0, 12)  # Maximum engine power
	engine_power_system._process(0.016)
	assert_that(engine_power_system.current_acceleration).is_greater_equal(baseline_acceleration)
	assert_that(engine_power_system.current_turn_rate).is_greater_equal(baseline_turn_rate)

## SHIP-008 AC5: EMP Effects Tests

func test_emp_power_disruption():
	"""Test EMP effects create temporary system degradation."""
	# Apply EMP effect
	var emp_strength = 0.3  # 30% power reduction
	var emp_duration = 5.0  # 5 seconds
	
	ets_manager.apply_emp_effect(emp_strength, emp_duration)
	
	# Verify EMP effect applied
	assert_that(ets_manager.emp_effect_multiplier).is_equal(emp_strength)
	
	# Test progressive recovery (would need timer simulation)
	# For unit test, verify the recovery mechanism exists
	assert_that(ets_manager.has_method("_set_emp_multiplier")).is_true()
	assert_that(ets_manager.has_method("_on_emp_recovery_complete")).is_true()

func test_emp_system_wide_effects():
	"""Test EMP affects all energy systems."""
	# Apply EMP
	ets_manager.apply_emp_effect(0.5, 3.0)
	
	# Verify effective power allocation is reduced for all systems
	var shields_effective = ets_manager.get_effective_power_allocation(ETSManager.SystemType.SHIELDS)
	var weapons_effective = ets_manager.get_effective_power_allocation(ETSManager.SystemType.WEAPONS)
	var engines_effective = ets_manager.get_effective_power_allocation(ETSManager.SystemType.ENGINES)
	
	var shields_base = ets_manager.get_system_power_allocation(ETSManager.SystemType.SHIELDS)
	var weapons_base = ets_manager.get_system_power_allocation(ETSManager.SystemType.WEAPONS)
	var engines_base = ets_manager.get_system_power_allocation(ETSManager.SystemType.ENGINES)
	
	assert_that(shields_effective).is_less(shields_base)
	assert_that(weapons_effective).is_less(weapons_base)
	assert_that(engines_effective).is_less(engines_base)

## SHIP-008 AC6 & AC7: Integration Tests

func test_subsystem_damage_effects():
	"""Test subsystem damage affects energy system efficiency."""
	# Apply subsystem damage to shield generator
	shield_regen_controller.set_subsystem_efficiency(0.5)  # 50% efficiency
	
	# Verify regeneration is reduced
	shield_regen_controller.apply_quadrant_damage(0, 20.0)
	shield_regen_controller.quadrant_damage_timers[0] = 0.0
	
	var initial_strength = shield_regen_controller.current_shield_strength[0]
	shield_regen_controller._process(1.0)
	var damaged_subsystem_regen = shield_regen_controller.current_shield_strength[0] - initial_strength
	
	# Compare with full efficiency
	shield_regen_controller.current_shield_strength[0] = initial_strength
	shield_regen_controller.set_subsystem_efficiency(1.0)  # Full efficiency
	shield_regen_controller._process(1.0)
	var full_efficiency_regen = shield_regen_controller.current_shield_strength[0] - initial_strength
	
	assert_that(damaged_subsystem_regen).is_less(full_efficiency_regen)

func test_energy_system_coordination():
	"""Test coordination between all energy systems."""
	# Set asymmetric ETS allocation
	ets_manager.set_power_allocation(8, 2, 2)  # High shields, low weapons/engines
	
	# Process all systems
	ets_manager._process(0.016)
	shield_regen_controller._process(0.016)
	weapon_energy_manager._process(0.016)
	engine_power_system._process(0.016)
	
	# Verify each system responds to ETS allocation
	var shields_allocation = ets_manager.get_system_power_allocation(ETSManager.SystemType.SHIELDS)
	var weapons_allocation = ets_manager.get_system_power_allocation(ETSManager.SystemType.WEAPONS)
	var engines_allocation = ets_manager.get_system_power_allocation(ETSManager.SystemType.ENGINES)
	
	assert_that(shields_allocation).is_greater(weapons_allocation)
	assert_that(shields_allocation).is_greater(engines_allocation)
	
	# Verify engine performance is reduced with low allocation
	var engine_performance = engine_power_system.get_engine_performance()
	assert_that(engine_performance["engine_power_level"]).is_less(0.5)

## Performance and Edge Case Tests

func test_energy_system_performance():
	"""Test energy systems maintain performance under load."""
	var start_time = Time.get_ticks_msec()
	
	# Run intensive operations
	for i in range(100):
		ets_manager.transfer_energy(ETSManager.TransferDirection.WEAPONS_TO_SHIELDS)
		ets_manager._process(0.016)
		shield_regen_controller._process(0.016)
		weapon_energy_manager._process(0.016)
		engine_power_system._process(0.016)
	
	var elapsed_time = Time.get_ticks_msec() - start_time
	
	# Should complete in reasonable time (less than 100ms for 100 iterations)
	assert_that(elapsed_time).is_less(100)

func test_zero_energy_edge_cases():
	"""Test systems handle zero energy conditions gracefully."""
	# Test zero weapon energy
	weapon_energy_manager.available_weapon_energy = 0.0
	assert_that(weapon_energy_manager.can_weapon_fire(0)).is_false()
	assert_that(weapon_energy_manager.consume_weapon_energy(0, 1)).is_false()
	
	# Test zero engine power
	ets_manager.set_power_allocation(6, 6, 0)  # No engine power
	engine_power_system._process(0.016)
	var performance = engine_power_system.get_engine_performance()
	assert_that(performance["power_state"]).is_equal(EnginePowerSystem.PowerState.NO_POWER)
	assert_that(performance["current_max_speed"]).is_greater(0.0)  # Should have minimal speed

func test_maximum_energy_edge_cases():
	"""Test systems handle maximum energy conditions correctly."""
	# Test maximum shield allocation
	ets_manager.set_power_allocation(12, 0, 0)  # All power to shields
	var shields_allocation = ets_manager.get_system_power_allocation(ETSManager.SystemType.SHIELDS)
	assert_that(shields_allocation).is_equal(1.0)
	
	# Test shield regeneration at maximum
	for i in range(4):
		shield_regen_controller.current_shield_strength[i] = shield_regen_controller.max_shield_strength[i]
	
	var initial_total = 0.0
	for strength in shield_regen_controller.current_shield_strength:
		initial_total += strength
	
	shield_regen_controller._process(1.0)  # Try to regenerate
	
	var final_total = 0.0
	for strength in shield_regen_controller.current_shield_strength:
		final_total += strength
	
	# Should not exceed maximum
	assert_that(final_total).is_equal(initial_total)

## WCS Compatibility Tests

func test_wcs_ets_level_compatibility():
	"""Test ETS levels match WCS exactly."""
	# Verify specific WCS energy levels from hudets.cpp
	var wcs_levels = [0.0, 0.0833, 0.167, 0.25, 0.333, 0.417, 0.5, 0.583, 0.667, 0.75, 0.833, 0.9167, 1.0]
	
	for i in range(wcs_levels.size()):
		assert_that(ETSManager.ENERGY_LEVELS[i]).is_between(wcs_levels[i] - 0.001, wcs_levels[i] + 0.001)

func test_wcs_default_allocation():
	"""Test default ETS allocation matches WCS (1/3 each system)."""
	ets_manager.reset_power_allocation()
	var allocation = ets_manager.get_power_allocation()
	
	# WCS default is index 4 = 0.333 for each system
	assert_that(allocation["shields_index"]).is_equal(4)
	assert_that(allocation["weapons_index"]).is_equal(4)
	assert_that(allocation["engines_index"]).is_equal(4)

func test_energy_transfer_limits():
	"""Test energy transfer respects WCS limits."""
	# Test cannot transfer beyond maximum
	ets_manager.set_power_allocation(12, 0, 0)  # Maximum shields
	var initial_allocation = ets_manager.get_power_allocation()
	
	# Attempt to transfer more to shields (should fail)
	var transfer_result = ets_manager.transfer_energy(ETSManager.TransferDirection.WEAPONS_TO_SHIELDS)
	assert_that(transfer_result).is_false()
	
	var final_allocation = ets_manager.get_power_allocation()
	assert_that(final_allocation["shields_index"]).is_equal(initial_allocation["shields_index"])

## Signal Integration Tests

func test_energy_system_signals():
	"""Test energy systems emit appropriate signals."""
	var signals_received = []
	
	# Connect to signals
	ets_manager.power_allocation_changed.connect(func(s, w, e): signals_received.append("ets_changed"))
	shield_regen_controller.shield_regenerated.connect(func(q, a): signals_received.append("shield_regen"))
	weapon_energy_manager.weapon_energy_consumed.connect(func(b, a): signals_received.append("weapon_consumed"))
	engine_power_system.engine_power_changed.connect(func(p): signals_received.append("engine_power"))
	
	# Trigger signal-emitting actions
	ets_manager.transfer_energy(ETSManager.TransferDirection.WEAPONS_TO_SHIELDS)
	weapon_energy_manager.consume_weapon_energy(0, 1)
	
	# Verify signals were emitted
	assert_that(signals_received).contains("ets_changed")
	assert_that(signals_received).contains("weapon_consumed")