class_name TestPlayerShipControls
extends GdUnitTestSuite

## Comprehensive unit tests for SHIP-015: Player Ship Controls and Flight Assistance.
## Tests input processing, flight dynamics, and assistance features for responsive control.

const PlayerInputProcessor = preload(\"res://scripts/player/player_input_processor.gd\")
const FlightDynamicsController = preload(\"res://scripts/player/flight_dynamics_controller.gd\")
const FlightAssistanceManager = preload(\"res://scripts/player/flight_assistance_manager.gd\")

var input_processor: PlayerInputProcessor
var flight_dynamics: FlightDynamicsController
var assistance_manager: FlightAssistanceManager
var mock_physics_body: RigidBody3D
var mock_ship_controller: ShipBase

func before_test() -> void:
	# Create mock physics body
	mock_physics_body = RigidBody3D.new()
	mock_physics_body.name = \"MockShip\"
	mock_physics_body.mass = 100.0
	mock_physics_body.gravity_scale = 0.0
	add_child(mock_physics_body)
	
	# Create mock ship controller
	mock_ship_controller = ShipBase.new()
	mock_ship_controller.name = \"MockShipController\"
	mock_physics_body.add_child(mock_ship_controller)
	
	# Create input processor
	input_processor = PlayerInputProcessor.new()
	input_processor.name = \"InputProcessor\"
	mock_physics_body.add_child(input_processor)
	
	# Create flight dynamics controller
	flight_dynamics = FlightDynamicsController.new()
	flight_dynamics.name = \"FlightDynamicsController\"
	flight_dynamics.physics_body = mock_physics_body
	mock_physics_body.add_child(flight_dynamics)
	
	# Create flight assistance manager
	assistance_manager = FlightAssistanceManager.new()
	assistance_manager.name = \"FlightAssistanceManager\"
	assistance_manager.flight_dynamics = flight_dynamics
	assistance_manager.physics_body = mock_physics_body
	assistance_manager.ship_controller = mock_ship_controller
	mock_physics_body.add_child(assistance_manager)

func after_test() -> void:
	if mock_physics_body:
		mock_physics_body.queue_free()

## PlayerInputProcessor Tests

func test_input_processor_initialization() -> void:
	# Test processor initializes correctly
	assert_that(input_processor).is_not_null()
	assert_that(input_processor.is_input_processing_enabled()).is_true()
	
	# Test default sensitivities
	assert_that(input_processor.get_sensitivity(\"pitch\")).is_equal(1.0)
	assert_that(input_processor.get_sensitivity(\"yaw\")).is_equal(1.0)
	assert_that(input_processor.get_sensitivity(\"roll\")).is_equal(1.0)
	assert_that(input_processor.get_sensitivity(\"throttle\")).is_equal(2.0)

func test_input_sensitivity_adjustment() -> void:
	# Test sensitivity setting
	input_processor.set_sensitivity(\"pitch\", 1.5)
	assert_that(input_processor.get_sensitivity(\"pitch\")).is_equal(1.5)
	
	input_processor.set_sensitivity(\"yaw\", 0.8)
	assert_that(input_processor.get_sensitivity(\"yaw\")).is_equal(0.8)
	
	# Test sensitivity clamping
	input_processor.set_sensitivity(\"roll\", 0.05)  # Below minimum
	assert_that(input_processor.get_sensitivity(\"roll\")).is_equal(0.1)

func test_input_deadzone_configuration() -> void:
	# Test deadzone configuration for different device types
	var keyboard_deadzone: float = input_processor.get_deadzone(InputManager.ControlScheme.KEYBOARD_MOUSE)
	var gamepad_deadzone: float = input_processor.get_deadzone(InputManager.ControlScheme.GAMEPAD)
	
	assert_that(keyboard_deadzone).is_equal(0.0)
	assert_that(gamepad_deadzone).is_equal(0.15)
	
	# Test deadzone adjustment
	input_processor.configure_deadzone(InputManager.ControlScheme.GAMEPAD, 0.2)
	assert_that(input_processor.get_deadzone(InputManager.ControlScheme.GAMEPAD)).is_equal(0.2)

func test_input_processing_enable_disable() -> void:
	# Test input processing can be disabled
	input_processor.set_input_processing_enabled(false)
	assert_that(input_processor.is_input_processing_enabled()).is_false()
	
	# Test all inputs are cleared when disabled
	var pitch_input: float = input_processor.get_input_value(\"pitch\")
	var yaw_input: float = input_processor.get_input_value(\"yaw\")
	var roll_input: float = input_processor.get_input_value(\"roll\")
	
	assert_that(pitch_input).is_equal(0.0)
	assert_that(yaw_input).is_equal(0.0)
	assert_that(roll_input).is_equal(0.0)
	
	# Re-enable for other tests
	input_processor.set_input_processing_enabled(true)
	assert_that(input_processor.is_input_processing_enabled()).is_true()

func test_key_binding_configuration() -> void:
	# Test key binding retrieval
	var pitch_up_key: int = input_processor.get_key_binding(\"pitch_up\")
	assert_that(pitch_up_key).is_equal(KEY_S)
	
	# Test key binding modification
	input_processor.set_key_binding(\"pitch_up\", KEY_DOWN)
	assert_that(input_processor.get_key_binding(\"pitch_up\")).is_equal(KEY_DOWN)
	
	# Test invalid action
	assert_that(input_processor.get_key_binding(\"invalid_action\")).is_equal(KEY_NONE)

func test_input_configuration_save_load() -> void:
	# Modify configuration
	input_processor.set_sensitivity(\"pitch\", 1.3)
	input_processor.set_sensitivity(\"yaw\", 0.9)
	input_processor.configure_deadzone(InputManager.ControlScheme.GAMEPAD, 0.25)
	
	# Save configuration
	var config: Dictionary = input_processor.save_configuration()
	assert_that(config).has_key(\"sensitivities\")
	assert_that(config).has_key(\"device_configs\")
	
	# Reset to defaults
	input_processor.set_sensitivity(\"pitch\", 1.0)
	input_processor.set_sensitivity(\"yaw\", 1.0)
	
	# Load configuration
	input_processor.load_configuration(config)
	assert_that(input_processor.get_sensitivity(\"pitch\")).is_equal(1.3)
	assert_that(input_processor.get_sensitivity(\"yaw\")).is_equal(0.9)

## FlightDynamicsController Tests

func test_flight_dynamics_initialization() -> void:
	# Test flight dynamics initializes correctly
	assert_that(flight_dynamics).is_not_null()
	assert_that(flight_dynamics.physics_body).is_not_null()
	assert_that(flight_dynamics.ship_mass).is_equal(100.0)
	
	# Test physics body configuration
	assert_that(mock_physics_body.gravity_scale).is_equal(0.0)
	assert_that(mock_physics_body.linear_damp).is_equal(0.0)
	assert_that(mock_physics_body.angular_damp).is_equal(0.0)

func test_flight_input_processing() -> void:
	# Test input setting
	flight_dynamics.set_pitch_input(0.5)
	flight_dynamics.set_yaw_input(-0.3)
	flight_dynamics.set_roll_input(0.8)
	flight_dynamics.set_throttle_input(0.7)
	
	assert_that(flight_dynamics.pitch_input).is_equal(0.5)
	assert_that(flight_dynamics.yaw_input).is_equal(-0.3)
	assert_that(flight_dynamics.roll_input).is_equal(0.8)
	assert_that(flight_dynamics.throttle_input).is_equal(0.7)
	
	# Test input clamping
	flight_dynamics.set_pitch_input(1.5)  # Above maximum
	assert_that(flight_dynamics.pitch_input).is_equal(1.0)
	
	flight_dynamics.set_yaw_input(-1.5)  # Below minimum
	assert_that(flight_dynamics.yaw_input).is_equal(-1.0)

func test_angular_input_vector() -> void:
	# Test angular input vector setting
	var angular_input: Vector3 = Vector3(0.4, -0.6, 0.2)
	flight_dynamics.set_angular_input(angular_input)
	
	assert_that(flight_dynamics.pitch_input).is_equal(0.4)
	assert_that(flight_dynamics.yaw_input).is_equal(-0.6)
	assert_that(flight_dynamics.roll_input).is_equal(0.2)

func test_strafe_input_processing() -> void:
	# Test strafe input setting
	var strafe_vector: Vector3 = Vector3(0.3, -0.4, 0.1)
	flight_dynamics.set_strafe_input(strafe_vector)
	
	assert_that(flight_dynamics.strafe_input.x).is_equal(0.3)
	assert_that(flight_dynamics.strafe_input.y).is_equal(-0.4)
	assert_that(flight_dynamics.strafe_input.z).is_equal(0.1)
	
	# Test strafe input clamping
	flight_dynamics.set_strafe_input(Vector3(1.5, -1.5, 2.0))
	assert_that(flight_dynamics.strafe_input.x).is_equal(1.0)
	assert_that(flight_dynamics.strafe_input.y).is_equal(-1.0)
	assert_that(flight_dynamics.strafe_input.z).is_equal(1.0)

func test_ship_mass_configuration() -> void:
	# Test mass setting
	flight_dynamics.set_ship_mass(150.0)
	assert_that(flight_dynamics.ship_mass).is_equal(150.0)
	assert_that(mock_physics_body.mass).is_equal(150.0)
	
	# Test mass minimum
	flight_dynamics.set_ship_mass(-10.0)
	assert_that(flight_dynamics.ship_mass).is_equal(1.0)

func test_efficiency_modifiers() -> void:
	# Test engine efficiency
	flight_dynamics.set_engine_efficiency(0.8)
	assert_that(flight_dynamics.engine_efficiency).is_equal(0.8)
	
	# Test thruster efficiency
	flight_dynamics.set_thruster_efficiency(0.6)
	assert_that(flight_dynamics.thruster_efficiency).is_equal(0.6)
	
	# Test gyro efficiency
	flight_dynamics.set_gyro_efficiency(0.9)
	assert_that(flight_dynamics.gyro_efficiency).is_equal(0.9)
	
	# Test subsystem damage modifier
	flight_dynamics.set_subsystem_damage_modifier(0.7)
	assert_that(flight_dynamics.subsystem_damage_modifier).is_equal(0.7)

func test_flight_assistance_integration() -> void:
	# Test inertia dampening
	flight_dynamics.set_inertia_dampening(true, 0.2)
	assert_that(flight_dynamics.is_inertia_dampening_enabled()).is_true()
	assert_that(flight_dynamics.inertia_dampening_factor).is_equal(0.2)
	
	# Test auto-level
	flight_dynamics.set_auto_level(true)
	assert_that(flight_dynamics.is_auto_level_enabled()).is_true()
	
	# Test velocity limiter
	flight_dynamics.set_velocity_limiter(true, 250.0)
	assert_that(flight_dynamics.is_velocity_limiter_enabled()).is_true()
	assert_that(flight_dynamics.max_velocity_limit).is_equal(250.0)

func test_state_queries() -> void:
	# Set up some state
	mock_physics_body.linear_velocity = Vector3(10.0, 5.0, 20.0)
	mock_physics_body.angular_velocity = Vector3(0.1, 0.2, 0.05)
	flight_dynamics.current_thrust_vector = Vector3(0.0, 0.0, 500.0)
	
	# Test state queries
	assert_that(flight_dynamics.get_current_velocity()).is_equal(Vector3(10.0, 5.0, 20.0))
	assert_that(flight_dynamics.get_current_speed()).is_equal_approx(22.36, 0.1)
	assert_that(flight_dynamics.get_current_angular_velocity()).is_equal(Vector3(0.1, 0.2, 0.05))
	assert_that(flight_dynamics.get_thrust_vector()).is_equal(Vector3(0.0, 0.0, 500.0))

func test_emergency_stop() -> void:
	# Set up some inputs
	flight_dynamics.set_pitch_input(0.5)
	flight_dynamics.set_throttle_input(0.8)
	flight_dynamics.set_strafe_input(Vector3(0.3, 0.2, 0.1))
	
	# Trigger emergency stop
	flight_dynamics.emergency_stop()
	
	# Verify all inputs are cleared
	assert_that(flight_dynamics.pitch_input).is_equal(0.0)
	assert_that(flight_dynamics.yaw_input).is_equal(0.0)
	assert_that(flight_dynamics.roll_input).is_equal(0.0)
	assert_that(flight_dynamics.throttle_input).is_equal(0.0)
	assert_that(flight_dynamics.strafe_input).is_equal(Vector3.ZERO)

func test_performance_stats() -> void:
	# Test performance statistics retrieval
	var stats: Dictionary = flight_dynamics.get_performance_stats()
	
	assert_that(stats).has_key(\"ship_mass\")
	assert_that(stats).has_key(\"current_speed\")
	assert_that(stats).has_key(\"engine_efficiency\")
	assert_that(stats).has_key(\"inertia_dampening_enabled\")
	assert_that(stats).has_key(\"thrust_percentage\")
	
	assert_that(stats[\"ship_mass\"]).is_equal(100.0)
	assert_that(stats[\"engine_efficiency\"]).is_equal(1.0)

## FlightAssistanceManager Tests

func test_assistance_manager_initialization() -> void:
	# Test assistance manager initializes correctly
	assert_that(assistance_manager).is_not_null()
	assert_that(assistance_manager.flight_dynamics).is_not_null()
	assert_that(assistance_manager.physics_body).is_not_null()
	
	# Test all assistance modes start disabled
	for mode in FlightAssistanceManager.AssistanceMode.values():
		assert_that(assistance_manager.is_assistance_mode_active(mode)).is_false()

func test_assistance_mode_control() -> void:
	# Test enabling assistance mode
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	assert_that(assistance_manager.is_assistance_mode_active(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)).is_true()
	
	# Test disabling assistance mode
	assistance_manager.disable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	assert_that(assistance_manager.is_assistance_mode_active(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)).is_false()
	
	# Test toggling assistance mode
	assistance_manager.toggle_assistance_mode(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	assert_that(assistance_manager.is_assistance_mode_active(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)).is_true()
	
	assistance_manager.toggle_assistance_mode(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	assert_that(assistance_manager.is_assistance_mode_active(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)).is_false()

func test_auto_level_assistance() -> void:
	# Enable auto-level
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	assert_that(assistance_manager.auto_level_active).is_true()
	
	# Test auto-level strength setting
	assistance_manager.set_auto_level_strength(0.5)
	assert_that(assistance_manager.auto_level_strength).is_equal(0.5)
	
	# Test reference up vector setting
	var new_up: Vector3 = Vector3(0.1, 1.0, 0.0).normalized()
	assistance_manager.set_reference_up_vector(new_up)
	assert_that(assistance_manager.reference_up_vector).is_equal_approx(new_up, Vector3(0.01, 0.01, 0.01))

func test_collision_avoidance_assistance() -> void:
	# Enable collision avoidance
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	assert_that(assistance_manager.collision_detector.monitoring).is_true()
	
	# Test collision avoidance range setting
	assistance_manager.set_collision_avoidance_range(600.0)
	assert_that(assistance_manager.collision_avoidance_range).is_equal(600.0)
	
	# Test that collision detector is not overriding initially
	assert_that(assistance_manager.is_collision_override_active()).is_false()

func test_velocity_matching_assistance() -> void:
	# Create mock target
	var mock_target: RigidBody3D = RigidBody3D.new()
	mock_target.linear_velocity = Vector3(50.0, 10.0, 30.0)
	add_child(mock_target)
	
	# Enable velocity matching
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.VELOCITY_MATCHING)
	assistance_manager.set_velocity_match_target(mock_target)
	
	assert_that(assistance_manager.velocity_match_target).is_same(mock_target)
	assert_that(assistance_manager.velocity_match_active).is_true()
	
	mock_target.queue_free()

func test_glide_mode_assistance() -> void:
	# Set initial velocity
	mock_physics_body.linear_velocity = Vector3(20.0, 5.0, 15.0)
	
	# Enable glide mode
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.GLIDE_MODE)
	assert_that(assistance_manager.glide_mode_active).is_true()
	
	# Wait for glide velocity to be set
	await wait_frames(2)
	
	# Glide velocity should be captured
	assert_that(assistance_manager.glide_velocity.length()).is_greater(0.0)

func test_formation_assistance() -> void:
	# Create mock formation leader
	var mock_leader: Node3D = Node3D.new()
	mock_leader.global_position = Vector3(100.0, 50.0, 200.0)
	add_child(mock_leader)
	
	# Enable formation assistance
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.FORMATION_ASSIST)
	assistance_manager.set_formation_leader(mock_leader, Vector3(10.0, 0.0, -20.0))
	
	assert_that(assistance_manager.formation_leader).is_same(mock_leader)
	assert_that(assistance_manager.formation_offset).is_equal(Vector3(10.0, 0.0, -20.0))
	assert_that(assistance_manager.formation_assist_active).is_true()
	
	mock_leader.queue_free()

func test_approach_assistance() -> void:
	# Create mock approach target
	var mock_target: Node3D = Node3D.new()
	mock_target.global_position = Vector3(500.0, 100.0, 300.0)
	add_child(mock_target)
	
	# Enable approach assistance
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.APPROACH_ASSIST)
	assistance_manager.set_approach_target(mock_target, 150.0)
	
	assert_that(assistance_manager.approach_target).is_same(mock_target)
	assert_that(assistance_manager.approach_distance).is_equal(150.0)
	assert_that(assistance_manager.approach_assist_active).is_true()
	
	mock_target.queue_free()

func test_assistance_mode_priorities() -> void:
	# Test that collision avoidance has highest priority
	var priorities: Array = assistance_manager.assistance_priorities
	assert_that(priorities[0]).is_equal(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	
	# Test that auto-level has lower priority
	var auto_level_index: int = priorities.find(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	var collision_index: int = priorities.find(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	assert_that(auto_level_index).is_greater(collision_index)

func test_active_assistance_modes_query() -> void:
	# Enable multiple assistance modes
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.GLIDE_MODE)
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	
	# Get active modes
	var active_modes: Array = assistance_manager.get_active_assistance_modes()
	assert_that(active_modes.size()).is_equal(3)
	assert_that(active_modes.has(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)).is_true()
	assert_that(active_modes.has(FlightAssistanceManager.AssistanceMode.GLIDE_MODE)).is_true()
	assert_that(active_modes.has(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)).is_true()

func test_assistance_performance_stats() -> void:
	# Enable some assistance modes
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	
	# Get performance stats
	var stats: Dictionary = assistance_manager.get_performance_stats()
	
	assert_that(stats).has_key(\"active_modes\")
	assert_that(stats).has_key(\"collision_threats\")
	assert_that(stats).has_key(\"collision_override_active\")
	assert_that(stats).has_key(\"computations_per_frame\")
	
	assert_that(stats[\"active_modes\"]).is_equal(2)
	assert_that(stats[\"collision_override_active\"]).is_false()

## Integration Tests

func test_input_to_flight_dynamics_integration() -> void:
	# Set input processor values
	input_processor.current_inputs[\"pitch\"] = 0.5
	input_processor.current_inputs[\"yaw\"] = -0.3
	input_processor.current_inputs[\"roll\"] = 0.2
	input_processor.current_inputs[\"throttle\"] = 0.8
	
	# Apply inputs to flight dynamics
	flight_dynamics.set_pitch_input(input_processor.get_input_value(\"pitch\"))
	flight_dynamics.set_yaw_input(input_processor.get_input_value(\"yaw\"))
	flight_dynamics.set_roll_input(input_processor.get_input_value(\"roll\"))
	flight_dynamics.set_throttle_input(input_processor.get_input_value(\"throttle\"))
	
	# Verify integration
	assert_that(flight_dynamics.pitch_input).is_equal(0.5)
	assert_that(flight_dynamics.yaw_input).is_equal(-0.3)
	assert_that(flight_dynamics.roll_input).is_equal(0.2)
	assert_that(flight_dynamics.throttle_input).is_equal(0.8)

func test_flight_assistance_to_dynamics_integration() -> void:
	# Enable auto-level assistance
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	
	# Simulate tilted ship orientation
	mock_physics_body.global_transform.basis = Basis.from_euler(Vector3(0.0, 0.0, 0.5))  # Roll 0.5 radians
	
	# Process assistance (would normally happen in _process)
	await wait_frames(2)
	
	# Verify assistance is affecting flight dynamics
	assert_that(assistance_manager.auto_level_active).is_true()

func test_multiple_assistance_modes_interaction() -> void:
	# Enable multiple assistance modes
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.GLIDE_MODE)
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)
	
	# Verify all modes are active
	assert_that(assistance_manager.auto_level_active).is_true()
	assert_that(assistance_manager.glide_mode_active).is_true()
	assert_that(assistance_manager.collision_detector.monitoring).is_true()
	
	# Test that they can coexist
	var active_modes: Array = assistance_manager.get_active_assistance_modes()
	assert_that(active_modes.size()).is_equal(3)

func test_control_responsiveness() -> void:
	# Test input latency is within acceptable range
	var start_time: float = Time.get_ticks_usec() / 1000000.0
	
	# Process input
	input_processor.current_inputs[\"pitch\"] = 0.7
	
	# Apply to flight dynamics
	flight_dynamics.set_pitch_input(input_processor.get_input_value(\"pitch\"))
	
	var end_time: float = Time.get_ticks_usec() / 1000000.0
	var latency_ms: float = (end_time - start_time) * 1000.0
	
	# Verify low latency (should be well under 1ms for simple operations)
	assert_that(latency_ms).is_less(1.0)

func test_emergency_procedures() -> void:
	# Set up active inputs and assistance
	flight_dynamics.set_throttle_input(0.9)
	flight_dynamics.set_pitch_input(0.5)
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
	assistance_manager.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.GLIDE_MODE)
	
	# Trigger emergency stop
	flight_dynamics.emergency_stop()
	
	# Verify all inputs are cleared
	assert_that(flight_dynamics.throttle_input).is_equal(0.0)
	assert_that(flight_dynamics.pitch_input).is_equal(0.0)
	
	# Verify assistance modes are still available (not disabled by emergency stop)
	assert_that(assistance_manager.is_assistance_mode_active(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)).is_true()

func test_configuration_persistence() -> void:
	# Configure input processor
	input_processor.set_sensitivity(\"pitch\", 1.4)
	input_processor.configure_deadzone(InputManager.ControlScheme.GAMEPAD, 0.18)
	
	# Configure flight assistance
	assistance_manager.set_auto_level_strength(0.4)
	assistance_manager.set_collision_avoidance_range(750.0)
	
	# Save and verify input processor configuration
	var input_config: Dictionary = input_processor.save_configuration()
	assert_that(input_config[\"sensitivities\"][\"pitch\"]).is_equal(1.4)
	
	# Reset and reload
	input_processor.set_sensitivity(\"pitch\", 1.0)
	input_processor.load_configuration(input_config)
	assert_that(input_processor.get_sensitivity(\"pitch\")).is_equal(1.4)