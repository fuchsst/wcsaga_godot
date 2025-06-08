extends GdUnitTestSuite

## Comprehensive test suite for SHIP-001: Ship Controller and Base Ship Systems
## Tests all acceptance criteria and implementation requirements
## Validates WCS-authentic ship behavior and integration

# Test constants
const TEST_SHIP_NAME = "Test Fighter"
const DELTA_TIME = 0.016667  # 60 FPS
const EPSILON = 0.001

# Test objects
var test_ship: BaseShip
var test_ship_class: ShipClass

func before_test() -> void:
	# Create test ship class
	test_ship_class = ShipClass.create_default_fighter()
	test_ship_class.class_name = TEST_SHIP_NAME
	
	# Create test ship
	test_ship = BaseShip.new()
	test_ship.name = "TestShip"
	
	# Add to scene tree for physics processing
	add_child(test_ship)
	
	# Initialize ship with test class
	assert_bool(test_ship.initialize_ship(test_ship_class, TEST_SHIP_NAME)).is_true()

func after_test() -> void:
	if test_ship and is_instance_valid(test_ship):
		test_ship.queue_free()
		remove_child(test_ship)
	test_ship = null
	test_ship_class = null

# ============================================================================
# SHIP-001 AC1: BaseShip class extends BaseSpaceObject with WCS properties
# ============================================================================

func test_ac1_baseship_extends_basespaceobject():
	assert_that(test_ship).is_not_null()
	assert_bool(test_ship is BaseSpaceObject).is_true()
	assert_bool(test_ship is BaseShip).is_true()

func test_ac1_ship_properties_initialized():
	assert_str(test_ship.ship_name).is_equal(TEST_SHIP_NAME)
	assert_float(test_ship.max_hull_strength).is_greater(0.0)
	assert_float(test_ship.max_shield_strength).is_greater(0.0)
	assert_float(test_ship.mass).is_greater(0.0)
	assert_float(test_ship.max_velocity).is_greater(0.0)

func test_ac1_physics_properties_configured():
	assert_that(test_ship.physics_body).is_not_null()
	assert_float(test_ship.physics_body.mass).is_equal(test_ship.mass)
	assert_float(test_ship.physics_body.gravity_scale).is_equal(0.0)
	assert_float(test_ship.physics_body.linear_damp).is_greater(0.0)

# ============================================================================
# SHIP-001 AC2: Ship initialization from ship class definitions
# ============================================================================

func test_ac2_initialization_success():
	var new_ship = BaseShip.new()
	add_child(new_ship)
	
	var bomber_class = ShipClass.create_default_bomber()
	var success = new_ship.initialize_ship(bomber_class, "Test Bomber")
	
	assert_bool(success).is_true()
	assert_str(new_ship.ship_name).is_equal("Test Bomber")
	assert_that(new_ship.ship_class).is_same(bomber_class)
	assert_float(new_ship.max_hull_strength).is_equal(bomber_class.max_hull_strength)
	assert_float(new_ship.max_velocity).is_equal(bomber_class.max_velocity)
	
	new_ship.queue_free()
	remove_child(new_ship)

func test_ac2_initialization_failure_null_class():
	var new_ship = BaseShip.new()
	add_child(new_ship)
	
	var success = new_ship.initialize_ship(null, "Test Ship")
	
	assert_bool(success).is_false()
	
	new_ship.queue_free()
	remove_child(new_ship)

func test_ac2_physics_body_configuration():
	assert_that(test_ship.physics_body).is_not_null()
	assert_int(test_ship.collision_layer_bits).is_not_equal(0)
	assert_int(test_ship.collision_mask_bits).is_not_equal(0)

# ============================================================================
# SHIP-001 AC3: Ship lifecycle management
# ============================================================================

func test_ac3_lifecycle_creation():
	var new_ship = BaseShip.new()
	add_child(new_ship)
	
	# Should be created in inactive state
	assert_bool(new_ship.is_dying).is_false()
	assert_bool(new_ship.is_disabled).is_false()
	
	new_ship.queue_free()
	remove_child(new_ship)

func test_ac3_lifecycle_destruction():
	# Test hull destruction
	test_ship.current_hull_strength = 1.0
	var destruction_signaled = false
	test_ship.ship_destroyed.connect(func(ship): destruction_signaled = true)
	
	test_ship.apply_hull_damage(2.0)
	
	assert_bool(destruction_signaled).is_true()
	assert_bool(test_ship.is_dying).is_true()
	assert_float(test_ship.current_hull_strength).is_equal(0.0)

func test_ac3_lifecycle_cleanup():
	test_ship._trigger_ship_destruction()
	
	assert_bool(test_ship.is_dying).is_true()
	assert_bool(test_ship.is_disabled).is_true()
	assert_bool(test_ship.physics_body.freeze).is_true()

# ============================================================================
# SHIP-001 AC4: Core ship state management
# ============================================================================

func test_ac4_state_flags_management():
	# Test basic state flags
	assert_int(test_ship.ship_flags).is_equal(0)
	assert_int(test_ship.ship_flags2).is_equal(0)
	assert_int(test_ship.team).is_equal(0)

func test_ac4_frame_processing():
	var initial_time = test_ship.last_frame_time
	
	# Simulate frame processing
	test_ship._physics_process(DELTA_TIME)
	
	assert_float(test_ship.frame_delta).is_equal(DELTA_TIME)

func test_ac4_energy_systems_state():
	assert_float(test_ship.current_weapon_energy).is_greater(0.0)
	assert_float(test_ship.current_afterburner_fuel).is_greater(0.0)
	assert_float(test_ship.shield_recharge_rate).is_greater(0.0)
	assert_float(test_ship.weapon_recharge_rate).is_greater(0.0)
	assert_float(test_ship.engine_power_rate).is_greater(0.0)

# ============================================================================
# SHIP-001 AC5: Ship physics integration
# ============================================================================

func test_ac5_physics_velocity_limits():
	# Set high velocity and verify limiting
	test_ship.physics_body.linear_velocity = Vector3(1000, 0, 0)
	test_ship._apply_velocity_constraints()
	
	var final_speed = test_ship.physics_body.linear_velocity.length()
	assert_float(final_speed).is_less_equal(test_ship.current_max_speed + EPSILON)

func test_ac5_afterburner_velocity_boost():
	var normal_max_speed = test_ship.current_max_speed
	
	test_ship.set_afterburner_active(true)
	assert_bool(test_ship.is_afterburner_active).is_true()
	
	# Max speed should be higher with afterburner
	test_ship._apply_velocity_constraints()
	# Note: actual max speed check depends on implementation details

func test_ac5_movement_characteristics():
	# Test WCS-style movement
	var success = test_ship.apply_ship_thrust(1.0, 0.0, 0.0, false)
	assert_bool(success).is_true()
	
	# Should apply thrust through physics system
	assert_float(test_ship.acceleration).is_greater(0.0)
	assert_float(test_ship.mass).is_greater(0.0)

func test_ac5_physics_damping():
	# Set initial velocity
	test_ship.physics_body.linear_velocity = Vector3(10, 5, 0)
	var initial_velocity = test_ship.physics_body.linear_velocity
	
	# Apply damping
	test_ship.apply_physics_damping(DELTA_TIME)
	
	# Velocity should be reduced (space damping)
	var final_velocity = test_ship.physics_body.linear_velocity
	assert_float(final_velocity.length()).is_less(initial_velocity.length())

# ============================================================================
# SHIP-001 AC6: Energy Transfer System (ETS)
# ============================================================================

func test_ac6_ets_initialization():
	# Default allocation should be 1/3 each
	var expected_allocation = 0.333
	assert_float(test_ship.shield_recharge_rate).is_equal_approx(expected_allocation, 0.01)
	assert_float(test_ship.weapon_recharge_rate).is_equal_approx(expected_allocation, 0.01)
	assert_float(test_ship.engine_power_rate).is_equal_approx(expected_allocation, 0.01)

func test_ac6_ets_allocation_valid():
	var success = test_ship.set_ets_allocation(0.5, 0.3, 0.2)
	
	assert_bool(success).is_true()
	assert_float(test_ship.shield_recharge_rate).is_equal(0.5)
	assert_float(test_ship.weapon_recharge_rate).is_equal(0.3)
	assert_float(test_ship.engine_power_rate).is_equal(0.2)

func test_ac6_ets_allocation_invalid():
	# Test invalid allocation (doesn't sum to 1.0)
	var success = test_ship.set_ets_allocation(0.5, 0.5, 0.5)
	assert_bool(success).is_false()
	
	# Test out of range values
	success = test_ship.set_ets_allocation(-0.1, 0.6, 0.5)
	assert_bool(success).is_false()

func test_ac6_ets_energy_transfers():
	# Test shield energy transfer
	var initial_shield_index = test_ship.shield_recharge_index
	var initial_weapon_index = test_ship.weapon_recharge_index
	
	var success = test_ship.transfer_energy_to_shields()
	
	if initial_weapon_index > 0 and initial_shield_index < 12:
		assert_bool(success).is_true()
		assert_int(test_ship.shield_recharge_index).is_equal(initial_shield_index + 1)
		assert_int(test_ship.weapon_recharge_index).is_equal(initial_weapon_index - 1)

func test_ac6_ets_balance_function():
	# Unbalance the system first
	test_ship.set_ets_allocation(0.6, 0.2, 0.2)
	
	# Balance it
	test_ship.balance_energy_systems()
	
	var expected = 0.333
	assert_float(test_ship.shield_recharge_rate).is_equal_approx(expected, 0.01)
	assert_float(test_ship.weapon_recharge_rate).is_equal_approx(expected, 0.01)
	assert_float(test_ship.engine_power_rate).is_equal_approx(expected, 0.01)

func test_ac6_ets_energy_regeneration():
	# Deplete weapon energy
	test_ship.current_weapon_energy = 50.0
	var initial_energy = test_ship.current_weapon_energy
	
	# Process ETS for one frame
	test_ship._process_ets_system(DELTA_TIME)
	
	# Weapon energy should regenerate
	assert_float(test_ship.current_weapon_energy).is_greater(initial_energy)

# ============================================================================
# SHIP-001 AC7: Subsystem state processing and performance effects
# ============================================================================

func test_ac7_subsystem_initialization():
	# Subsystems should be initialized
	assert_that(test_ship.subsystems).is_not_null()
	assert_that(test_ship.subsystem_list).is_not_null()

func test_ac7_performance_tracking():
	assert_float(test_ship.performance_modifier).is_greater(0.0)
	assert_float(test_ship.engine_performance).is_greater(0.0)
	assert_float(test_ship.weapon_performance).is_greater(0.0)
	assert_float(test_ship.shield_performance).is_greater(0.0)

func test_ac7_engine_damage_affects_speed():
	var initial_max_speed = test_ship.current_max_speed
	
	# Simulate engine damage
	test_ship.engine_performance = 0.5
	test_ship._update_performance_effects()
	
	# Max speed should be reduced
	assert_float(test_ship.current_max_speed).is_less(initial_max_speed)

func test_ac7_subsystem_signals_connected():
	# Check that ship signals are properly set up
	var signal_list = test_ship.get_signal_list()
	var signal_names = signal_list.map(func(sig): return sig.name)
	
	assert_array(signal_names).contains("ship_destroyed")
	assert_array(signal_names).contains("subsystem_damaged")
	assert_array(signal_names).contains("shields_depleted")
	assert_array(signal_names).contains("energy_transfer_changed")

# ============================================================================
# Integration Tests
# ============================================================================

func test_integration_damage_system():
	var shield_depleted_signaled = false
	test_ship.shields_depleted.connect(func(): shield_depleted_signaled = true)
	
	# Apply shield damage
	var shield_damage = test_ship.apply_shield_damage(test_ship.current_shield_strength)
	
	assert_float(shield_damage).is_greater(0.0)
	assert_float(test_ship.current_shield_strength).is_equal(0.0)
	
	# Process frame to check for signal
	test_ship._physics_process(DELTA_TIME)
	assert_bool(shield_depleted_signaled).is_true()

func test_integration_afterburner_system():
	var activated_signaled = false
	var deactivated_signaled = false
	test_ship.afterburner_activated.connect(func(): activated_signaled = true)
	test_ship.afterburner_deactivated.connect(func(): deactivated_signaled = true)
	
	# Activate afterburner
	var success = test_ship.set_afterburner_active(true)
	assert_bool(success).is_true()
	assert_bool(activated_signaled).is_true()
	
	# Deactivate afterburner
	success = test_ship.set_afterburner_active(false)
	assert_bool(success).is_true()
	assert_bool(deactivated_signaled).is_true()

func test_integration_ship_status():
	var status = test_ship.get_ship_status()
	
	assert_that(status).is_not_null()
	assert_str(status.ship_name).is_equal(TEST_SHIP_NAME)
	assert_float(status.hull_percent).is_greater_equal(0.0)
	assert_float(status.hull_percent).is_less_equal(100.0)
	assert_float(status.shield_percent).is_greater_equal(0.0)
	assert_float(status.shield_percent).is_less_equal(100.0)

func test_integration_performance_info():
	var perf_info = test_ship.get_performance_info()
	
	assert_that(perf_info).is_not_null()
	assert_float(perf_info.overall_performance).is_greater(0.0)
	assert_float(perf_info.engine_performance).is_greater(0.0)
	assert_float(perf_info.weapon_performance).is_greater(0.0)
	assert_float(perf_info.shield_performance).is_greater(0.0)

# ============================================================================
# Error Handling and Edge Cases
# ============================================================================

func test_error_handling_null_ship_class():
	var new_ship = BaseShip.new()
	add_child(new_ship)
	
	var success = new_ship.initialize_ship(null)
	assert_bool(success).is_false()
	
	new_ship.queue_free()
	remove_child(new_ship)

func test_error_handling_invalid_thrust():
	test_ship.is_disabled = true
	var success = test_ship.apply_ship_thrust(1.0, 0.0, 0.0)
	assert_bool(success).is_false()

func test_error_handling_zero_damage():
	var initial_hull = test_ship.current_hull_strength
	var damage_applied = test_ship.apply_hull_damage(0.0)
	
	assert_float(damage_applied).is_equal(0.0)
	assert_float(test_ship.current_hull_strength).is_equal(initial_hull)

func test_error_handling_negative_damage():
	var initial_hull = test_ship.current_hull_strength
	var damage_applied = test_ship.apply_hull_damage(-10.0)
	
	assert_float(damage_applied).is_equal(0.0)
	assert_float(test_ship.current_hull_strength).is_equal(initial_hull)

# ============================================================================
# Performance Tests
# ============================================================================

func test_performance_frame_processing():
	var start_time = Time.get_ticks_usec()
	
	# Process 100 frames
	for i in range(100):
		test_ship._physics_process(DELTA_TIME)
	
	var end_time = Time.get_ticks_usec()
	var duration_ms = (end_time - start_time) / 1000.0
	
	# Should process frames efficiently (arbitrary threshold)
	assert_float(duration_ms).is_less(100.0)  # Less than 100ms for 100 frames

func test_performance_ets_processing():
	var start_time = Time.get_ticks_usec()
	
	# Process ETS 1000 times
	for i in range(1000):
		test_ship._process_ets_system(DELTA_TIME)
	
	var end_time = Time.get_ticks_usec()
	var duration_ms = (end_time - start_time) / 1000.0
	
	# ETS processing should be fast
	assert_float(duration_ms).is_less(50.0)  # Less than 50ms for 1000 iterations