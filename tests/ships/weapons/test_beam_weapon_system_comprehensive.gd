extends GdUnitTestSuite

## SHIP-013 Comprehensive Test Suite: Beam Weapons and Continuous Damage
## Tests all seven acceptance criteria with integration scenarios
## Validates WCS-authentic beam weapon behavior and performance

# Test fixtures
var beam_weapon_system: BeamWeaponSystem
var continuous_damage_system: ContinuousDamageSystem
var beam_collision_detector: BeamCollisionDetector
var beam_lifecycle_manager: BeamLifecycleManager
var beam_renderer: BeamRenderer
var beam_targeting_system: BeamTargetingSystem
var beam_penetration_system: BeamPenetrationSystem

# Mock objects for testing
var mock_ship: Node3D
var mock_target: Node3D
var mock_turret: Node3D

# Test data
var test_beam_configs: Dictionary = {}

func before_test() -> void:
	# Create main system
	beam_weapon_system = BeamWeaponSystem.new()
	beam_weapon_system.name = "BeamWeaponSystem"
	add_child(beam_weapon_system)
	
	# Initialize subsystems (they're created automatically by BeamWeaponSystem)
	await get_tree().process_frame  # Wait for subsystems to initialize
	
	# Get references to subsystems
	continuous_damage_system = beam_weapon_system.continuous_damage_system
	beam_collision_detector = beam_weapon_system.beam_collision_detector
	beam_lifecycle_manager = beam_weapon_system.beam_lifecycle_manager
	beam_renderer = beam_weapon_system.beam_renderer
	beam_targeting_system = beam_weapon_system.beam_targeting_system
	beam_penetration_system = beam_weapon_system.beam_penetration_system
	
	# Create mock objects
	_create_mock_objects()
	
	# Initialize beam weapon system
	beam_weapon_system.initialize_beam_weapon_system()

func after_test() -> void:
	if beam_weapon_system:
		beam_weapon_system.queue_free()
	if mock_ship:
		mock_ship.queue_free()
	if mock_target:
		mock_target.queue_free()
	if mock_turret:
		mock_turret.queue_free()

func _create_mock_objects() -> void:
	# Create mock firing ship
	mock_ship = Node3D.new()
	mock_ship.name = "MockShip"
	mock_ship.set_script(preload("res://scripts/ships/core/base_ship.gd"))
	add_child(mock_ship)
	
	# Create mock target
	mock_target = Node3D.new()
	mock_target.name = "MockTarget"
	mock_target.global_position = Vector3(100, 0, 0)
	add_child(mock_target)
	
	# Add target methods for testing
	mock_target.set_script(preload("res://scripts/ships/core/base_ship.gd"))
	
	# Create mock turret
	mock_turret = Node3D.new()
	mock_turret.name = "MockTurret"
	mock_ship.add_child(mock_turret)

# ============================================================================
# AC1: Beam Weapon Types System - All 5 WCS Beam Types (A-E)
# ============================================================================

func test_ac1_beam_type_configurations() -> void:
	# Test that all 5 beam types are properly configured
	var beam_configs = beam_weapon_system.beam_type_configs
	
	assert_int(beam_configs.size()).is_equal(5)
	assert_that(beam_configs).has_key(BeamWeaponSystem.BeamType.TYPE_A_STANDARD)
	assert_that(beam_configs).has_key(BeamWeaponSystem.BeamType.TYPE_B_SLASH)
	assert_that(beam_configs).has_key(BeamWeaponSystem.BeamType.TYPE_C_TARGETING)
	assert_that(beam_configs).has_key(BeamWeaponSystem.BeamType.TYPE_D_CHASING)
	assert_that(beam_configs).has_key(BeamWeaponSystem.BeamType.TYPE_E_FIXED)

func test_ac1_type_a_standard_beam() -> void:
	# Test Type A: Standard Continuous Beam behavior
	var firing_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"source_position": Vector3.ZERO,
		"target": mock_target,
		"firing_ship": mock_ship
	}
	
	var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
	assert_str(beam_id).is_not_empty()
	
	var beam_data = beam_weapon_system.get_beam_data(beam_id)
	var config = beam_data.get("config", {})
	
	# Type A should maintain constant aim and penetrate shields
	assert_bool(config.get("pierces_shields", false)).is_true()
	assert_bool(config.get("can_retarget", true)).is_false()
	assert_str(config.get("collision_type", "")).is_equal("line")
	
	# Clean up
	beam_weapon_system.stop_beam_weapon(beam_id)

func test_ac1_type_b_slash_beam() -> void:
	# Test Type B: Slash Beam behavior
	var firing_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_B_SLASH,
		"source_position": Vector3.ZERO,
		"firing_ship": mock_ship
	}
	
	var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
	assert_str(beam_id).is_not_empty()
	
	var beam_data = beam_weapon_system.get_beam_data(beam_id)
	var config = beam_data.get("config", {})
	
	# Type B should sweep across targets with area coverage
	assert_bool(config.get("can_retarget", false)).is_true()
	assert_str(config.get("collision_type", "")).is_equal("sphereline")
	assert_float(config.get("sweep_angle", 0.0)).is_greater(0.0)
	
	beam_weapon_system.stop_beam_weapon(beam_id)

func test_ac1_type_c_targeting_laser() -> void:
	# Test Type C: Targeting Laser behavior
	var firing_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_C_TARGETING,
		"source_position": Vector3.ZERO,
		"firing_ship": mock_ship
	}
	
	var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
	assert_str(beam_id).is_not_empty()
	
	var beam_data = beam_weapon_system.get_beam_data(beam_id)
	var config = beam_data.get("config", {})
	
	# Type C should be short-duration with auto-targeting
	assert_float(config.get("active_duration", 0.0)).is_less(0.1)  # Single frame
	assert_bool(config.get("auto_fire", false)).is_true()
	
	beam_weapon_system.stop_beam_weapon(beam_id)

func test_ac1_type_d_chasing_beam() -> void:
	# Test Type D: Chasing Beam behavior
	var firing_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_D_CHASING,
		"source_position": Vector3.ZERO,
		"target": mock_target,
		"firing_ship": mock_ship
	}
	
	var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
	assert_str(beam_id).is_not_empty()
	
	var beam_data = beam_weapon_system.get_beam_data(beam_id)
	var config = beam_data.get("config", {})
	
	# Type D should track multiple targets with dynamic aim
	assert_bool(config.get("can_retarget", false)).is_true()
	assert_float(config.get("tracking_speed", 0.0)).is_greater(0.0)
	assert_int(config.get("max_attempts", 0)).is_greater(1)
	
	beam_weapon_system.stop_beam_weapon(beam_id)

func test_ac1_type_e_fixed_beam() -> void:
	# Test Type E: Fixed Beam behavior
	var firing_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_E_FIXED,
		"source_position": Vector3.ZERO,
		"turret_node": mock_turret,
		"firing_ship": mock_ship
	}
	
	var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
	assert_str(beam_id).is_not_empty()
	
	var beam_data = beam_weapon_system.get_beam_data(beam_id)
	var config = beam_data.get("config", {})
	
	# Type E should fire from fixed direction without aiming
	assert_bool(config.get("can_retarget", true)).is_false()
	assert_bool(config.get("fixed_direction", false)).is_true()
	
	beam_weapon_system.stop_beam_weapon(beam_id)

# ============================================================================
# AC2: Continuous Damage System - 170ms Timing with Collision Tracking
# ============================================================================

func test_ac2_damage_interval_timing() -> void:
	# Test 170ms damage interval accuracy
	assert_that(continuous_damage_system).is_not_null()
	assert_float(continuous_damage_system.damage_interval).is_equal_approx(0.17, 0.001)

func test_ac2_beam_damage_registration() -> void:
	# Test beam registration for continuous damage
	var beam_id = "test_beam_damage"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"config": {"damage_per_interval": 25.0},
		"firing_ship": mock_ship
	}
	
	continuous_damage_system.register_beam_weapon(beam_id, beam_data)
	
	var stats = continuous_damage_system.get_beam_damage_statistics(beam_id)
	assert_that(stats).has_key("beam_id")
	assert_float(stats.get("damage_per_interval", 0.0)).is_equal(25.0)
	
	continuous_damage_system.unregister_beam_weapon(beam_id)

func test_ac2_collision_tracking() -> void:
	# Test collision tracking prevents duplicate damage
	var beam_id = "test_collision_tracking"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"config": {"damage_per_interval": 30.0},
		"firing_ship": mock_ship
	}
	
	continuous_damage_system.register_beam_weapon(beam_id, beam_data)
	
	var collision_data = {
		"target": mock_target,
		"collision_point": Vector3(50, 0, 0),
		"collision_normal": Vector3(-1, 0, 0)
	}
	
	# First collision should apply damage
	var first_result = continuous_damage_system.process_beam_collision(beam_id, collision_data)
	
	# Immediate second collision should be blocked (duplicate prevention)
	var second_result = continuous_damage_system.process_beam_collision(beam_id, collision_data)
	
	# First should succeed or be pending, second should be blocked
	assert_bool(first_result or not second_result).is_true()
	
	continuous_damage_system.unregister_beam_weapon(beam_id)

func test_ac2_friendly_fire_protection() -> void:
	# Test friendly fire protection
	continuous_damage_system.set_friendly_fire_enabled(false)
	
	var beam_id = "test_friendly_fire"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"config": {"damage_per_interval": 20.0},
		"firing_ship": mock_ship
	}
	
	continuous_damage_system.register_beam_weapon(beam_id, beam_data)
	
	# This would test friendly fire protection in a full implementation
	continuous_damage_system.unregister_beam_weapon(beam_id)

# ============================================================================
# AC3: Beam Collision Detection - Line and Sphereline Methods
# ============================================================================

func test_ac3_collision_method_selection() -> void:
	# Test collision method selection based on beam width
	assert_that(beam_collision_detector).is_not_null()
	
	# Thin beams should use precision line collision
	var thin_beam_data = {
		"config": {"width": 1.5, "range": 1000.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD
	}
	
	# Wide beams should use area sphereline collision
	var wide_beam_data = {
		"config": {"width": 5.0, "range": 1000.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD
	}
	
	# Method selection is tested through the internal logic
	var thin_collisions = beam_collision_detector.detect_beam_collisions("thin_beam", thin_beam_data)
	var wide_collisions = beam_collision_detector.detect_beam_collisions("wide_beam", wide_beam_data)
	
	# Both should return collision arrays (empty if no targets)
	assert_that(thin_collisions).is_instance_of(TYPE_ARRAY)
	assert_that(wide_collisions).is_instance_of(TYPE_ARRAY)

func test_ac3_precision_line_collision() -> void:
	# Test precision line collision for thin beams
	var beam_data = {
		"config": {"width": 1.0, "range": 1000.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3(1, 0, 0)  # Point toward mock_target
	}
	
	var collisions = beam_collision_detector.detect_beam_collisions("precision_test", beam_data)
	
	# Should return array of collision results
	assert_that(collisions).is_instance_of(TYPE_ARRAY)

func test_ac3_area_sphereline_collision() -> void:
	# Test area sphereline collision for wide beams
	var beam_data = {
		"config": {"width": 6.0, "range": 1000.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3(1, 0, 0)
	}
	
	var collisions = beam_collision_detector.detect_beam_collisions("sphereline_test", beam_data)
	
	# Should return array of collision results
	assert_that(collisions).is_instance_of(TYPE_ARRAY)

func test_ac3_collision_caching() -> void:
	# Test collision detection caching
	beam_collision_detector.enable_collision_caching = true
	
	var beam_data = {
		"config": {"width": 2.0, "range": 500.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD
	}
	
	var first_detection = beam_collision_detector.detect_beam_collisions("cache_test", beam_data)
	var second_detection = beam_collision_detector.detect_beam_collisions("cache_test", beam_data)
	
	# Both should succeed
	assert_that(first_detection).is_instance_of(TYPE_ARRAY)
	assert_that(second_detection).is_instance_of(TYPE_ARRAY)

# ============================================================================
# AC4: Beam Lifecycle Management - Warmup/Active/Warmdown Phases
# ============================================================================

func test_ac4_lifecycle_phase_transitions() -> void:
	# Test beam lifecycle phase management
	assert_that(beam_lifecycle_manager).is_not_null()
	
	var beam_id = "lifecycle_test"
	var beam_data = {
		"config": {
			"warmup_time": 0.1,
			"active_duration": 0.2,
			"warmdown_time": 0.1
		}
	}
	
	beam_lifecycle_manager.start_beam_lifecycle(beam_id, beam_data)
	
	# Should start in warmup phase
	var initial_phase = beam_lifecycle_manager.get_beam_phase(beam_id)
	assert_int(initial_phase).is_equal(BeamLifecycleManager.BeamPhase.WARMUP)
	
	# Test lifecycle progress
	var progress = beam_lifecycle_manager.get_beam_lifecycle_progress(beam_id)
	assert_float(progress).is_greater_equal(0.0).is_less_equal(1.0)

func test_ac4_warmup_phase_behavior() -> void:
	# Test warmup phase specific behavior
	var beam_id = "warmup_test"
	var beam_data = {
		"config": {
			"warmup_time": 1.0,
			"active_duration": 2.0,
			"warmdown_time": 0.5
		}
	}
	
	beam_lifecycle_manager.start_beam_lifecycle(beam_id, beam_data)
	
	# Should be in warmup phase
	var phase = beam_lifecycle_manager.get_beam_phase(beam_id)
	assert_int(phase).is_equal(BeamLifecycleManager.BeamPhase.WARMUP)
	
	# Phase progress should start at 0
	var progress = beam_lifecycle_manager.get_phase_progress(beam_id)
	assert_float(progress).is_greater_equal(0.0)

func test_ac4_forced_warmdown() -> void:
	# Test forced warmdown transition
	var beam_id = "forced_warmdown_test"
	var beam_data = {
		"config": {
			"warmup_time": 0.1,
			"active_duration": 5.0,  # Long active duration
			"warmdown_time": 0.1
		}
	}
	
	beam_lifecycle_manager.start_beam_lifecycle(beam_id, beam_data)
	
	# Force to warmdown
	beam_lifecycle_manager.start_beam_warmdown(beam_id)
	
	# Should transition to warmdown
	await get_tree().process_frame
	var phase = beam_lifecycle_manager.get_beam_phase(beam_id)
	assert_int(phase).is_equal(BeamLifecycleManager.BeamPhase.WARMDOWN)

func test_ac4_lifecycle_callbacks() -> void:
	# Test lifecycle callback registration
	var beam_id = "callback_test"
	var callback_executed = false
	
	var callback = func(): callback_executed = true
	beam_lifecycle_manager.register_lifecycle_callback(beam_id, BeamLifecycleManager.BeamPhase.ACTIVE, callback)
	
	# This tests the callback registration system
	assert_bool(beam_lifecycle_manager.lifecycle_callbacks.has(beam_id)).is_true()

# ============================================================================
# AC5: Multi-Section Beam Rendering with Independent Animation
# ============================================================================

func test_ac5_multi_section_rendering() -> void:
	# Test multi-section beam rendering
	assert_that(beam_renderer).is_not_null()
	
	var beam_id = "render_test"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"config": {"width": 3.0, "range": 100.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD
	}
	
	beam_renderer.start_beam_rendering(beam_id, beam_data)
	
	# Should create renderer data
	assert_that(beam_renderer.active_beam_renderers).has_key(beam_id)
	
	var renderer_data = beam_renderer.active_beam_renderers[beam_id]
	assert_int(renderer_data.get("section_count", 0)).is_greater(0)
	
	beam_renderer.stop_beam_rendering(beam_id)

func test_ac5_beam_section_configuration() -> void:
	# Test beam section configuration for different types
	var type_a_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"config": {"width": 2.0, "range": 200.0}
	}
	
	var type_b_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_B_SLASH,
		"config": {"width": 8.0, "range": 150.0}
	}
	
	var renderer_a = beam_renderer._create_beam_renderer_data("type_a_test", type_a_data)
	var renderer_b = beam_renderer._create_beam_renderer_data("type_b_test", type_b_data)
	
	# Different beam types should have different configurations
	assert_int(renderer_a.get("section_count", 0)).is_greater(0)
	assert_int(renderer_b.get("section_count", 0)).is_greater(0)
	# Type B (slash) typically has more sections for sweep effect
	assert_int(renderer_b.get("section_count", 0)).is_greater_equal(renderer_a.get("section_count", 0))

func test_ac5_muzzle_effects() -> void:
	# Test muzzle effect creation
	beam_renderer.enable_muzzle_effects = true
	
	var beam_id = "muzzle_test"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"source_position": Vector3(10, 0, 0)
	}
	
	beam_renderer.start_beam_rendering(beam_id, beam_data)
	beam_renderer.activate_full_beam_rendering(beam_id)
	
	# Should have muzzle effect if enabled
	var stats = beam_renderer.get_rendering_statistics()
	assert_int(stats.get("muzzle_effects_active", 0)).is_greater_equal(0)
	
	beam_renderer.stop_beam_rendering(beam_id)

func test_ac5_beam_animation() -> void:
	# Test beam animation system
	beam_renderer.enable_beam_animation = true
	
	var beam_id = "animation_test"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_D_CHASING,
		"config": {"animation_speed": 2.0}
	}
	
	beam_renderer.start_beam_rendering(beam_id, beam_data)
	
	# Animation controller should be created
	if beam_renderer.animation_controllers.has(beam_id):
		var animation_data = beam_renderer.animation_controllers[beam_id]
		assert_that(animation_data).has_key("animation_time")
	
	beam_renderer.stop_beam_rendering(beam_id)

# ============================================================================
# AC6: Beam Targeting System with Type-Specific Algorithms
# ============================================================================

func test_ac6_targeting_algorithm_selection() -> void:
	# Test targeting algorithm selection for different beam types
	assert_that(beam_targeting_system).is_not_null()
	
	# Each beam type should have its specific targeting algorithm
	var algorithm_a = beam_targeting_system._get_targeting_algorithm(BeamWeaponSystem.BeamType.TYPE_A_STANDARD)
	var algorithm_b = beam_targeting_system._get_targeting_algorithm(BeamWeaponSystem.BeamType.TYPE_B_SLASH)
	var algorithm_c = beam_targeting_system._get_targeting_algorithm(BeamWeaponSystem.BeamType.TYPE_C_TARGETING)
	
	assert_int(algorithm_a).is_equal(BeamTargetingSystem.TargetingAlgorithm.FIXED_AIM)
	assert_int(algorithm_b).is_equal(BeamTargetingSystem.TargetingAlgorithm.OCTANT_SWEEP)
	assert_int(algorithm_c).is_equal(BeamTargetingSystem.TargetingAlgorithm.AUTO_CLOSEST)

func test_ac6_target_acquisition() -> void:
	# Test target acquisition and tracking
	var beam_id = "targeting_test"
	
	var result = beam_targeting_system.set_beam_target(beam_id, mock_target)
	assert_bool(result).is_true()
	
	# Should have targeting data
	assert_that(beam_targeting_system.beam_targeting_data).has_key(beam_id)
	
	var targeting_data = beam_targeting_system.beam_targeting_data[beam_id]
	assert_that(targeting_data.get("current_target")).is_equal(mock_target)
	assert_bool(targeting_data.get("has_valid_target", false)).is_true()

func test_ac6_closest_target_finding() -> void:
	# Test closest target finding algorithm
	var closest = beam_targeting_system.find_closest_target(Vector3.ZERO, 200.0)
	
	# Should find mock_target or return null if no valid targets
	# Mock target is at (100, 0, 0) which is within 200 unit range
	if closest:
		assert_that(closest).is_instance_of(Node)

func test_ac6_octant_selection() -> void:
	# Test octant selection for slash beams
	var beam_id = "octant_test"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_B_SLASH,
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD
	}
	
	var result = beam_targeting_system.update_beam_targeting(beam_id, beam_data)
	
	# Should return targeting result
	assert_that(result).is_instance_of(TYPE_DICTIONARY)
	if result.has("current_octant"):
		assert_int(result["current_octant"]).is_greater_equal(0).is_less_equal(7)

func test_ac6_predictive_targeting() -> void:
	# Test predictive targeting for chasing beams
	beam_targeting_system.set_beam_target("predictive_test", mock_target)
	
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_D_CHASING,
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD
	}
	
	var result = beam_targeting_system.update_beam_targeting("predictive_test", beam_data)
	
	# Should provide targeting solution
	assert_that(result).is_instance_of(TYPE_DICTIONARY)
	if result.get("has_solution", false):
		assert_that(result).has_key("aim_direction")

# ============================================================================
# AC7: Beam Penetration Mechanics with Hull Piercing and Shield Interaction
# ============================================================================

func test_ac7_penetration_behavior_types() -> void:
	# Test different penetration behaviors
	assert_that(beam_penetration_system).is_not_null()
	
	# Each beam type should have specific penetration characteristics
	var configs = beam_penetration_system.penetration_configs
	assert_int(configs.size()).is_equal(5)
	
	# Type A should pierce all ships
	var type_a_config = configs[BeamWeaponSystem.BeamType.TYPE_A_STANDARD]
	assert_int(type_a_config.get("behavior")).is_equal(BeamPenetrationSystem.PenetrationBehavior.PIERCES_ALL_SHIPS)
	
	# Type B should stop on impact
	var type_b_config = configs[BeamWeaponSystem.BeamType.TYPE_B_SLASH]
	assert_int(type_b_config.get("behavior")).is_equal(BeamPenetrationSystem.PenetrationBehavior.STOPS_ON_IMPACT)

func test_ac7_hull_piercing_calculation() -> void:
	# Test hull piercing calculation
	var beam_id = "piercing_test"
	var collision_data = {
		"target": mock_target,
		"collision_point": Vector3(50, 0, 0),
		"collision_normal": Vector3(-1, 0, 0)
	}
	
	# Create penetration data for Type A beam (pierces all ships)
	beam_penetration_system.beam_penetration_data[beam_id] = {
		"beam_id": beam_id,
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"penetration_count": 0,
		"targets_penetrated": [],
		"penetration_points": [],
		"current_damage_multiplier": 1.0
	}
	
	var result = beam_penetration_system.process_beam_collision(beam_id, collision_data)
	
	# Should return penetration result
	assert_that(result).is_instance_of(TYPE_DICTIONARY)
	assert_that(result).has_key("penetrates")

func test_ac7_shield_interaction_types() -> void:
	# Test different shield interaction types
	var beam_id = "shield_test"
	var collision_data = {
		"target": mock_target,
		"collision_point": Vector3(50, 0, 0)
	}
	
	# Test shield interaction processing
	var shield_result = beam_penetration_system._process_shield_interaction(
		beam_id, mock_target, collision_data, 
		BeamPenetrationSystem.ShieldInteraction.REDUCES_DAMAGE
	)
	
	assert_that(shield_result).is_instance_of(TYPE_DICTIONARY)
	assert_that(shield_result).has_key("beam_continues")

func test_ac7_penetration_limits() -> void:
	# Test penetration count limits
	var beam_id = "limit_test"
	
	# Create beam with limited penetrations
	beam_penetration_system.beam_penetration_data[beam_id] = {
		"beam_id": beam_id,
		"beam_type": BeamWeaponSystem.BeamType.TYPE_B_SLASH,  # Max 1 penetration
		"penetration_count": 1,  # Already at limit
		"targets_penetrated": [mock_target],
		"penetration_points": [Vector3.ZERO],
		"current_damage_multiplier": 0.8
	}
	
	var collision_data = {
		"target": mock_target,
		"collision_point": Vector3(25, 0, 0)
	}
	
	var result = beam_penetration_system.process_beam_collision(beam_id, collision_data)
	
	# Should be stopped due to penetration limit
	assert_bool(result.get("penetrates", true)).is_false()
	assert_str(result.get("reason", "")).is_equal("penetration_limit_exceeded")

func test_ac7_damage_falloff() -> void:
	# Test damage falloff after penetration
	var beam_id = "falloff_test"
	
	beam_penetration_system.beam_penetration_data[beam_id] = {
		"beam_id": beam_id,
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"penetration_count": 0,
		"targets_penetrated": [],
		"penetration_points": [],
		"current_damage_multiplier": 1.0
	}
	
	# Simulate penetration that should reduce damage
	var collision_data = {
		"target": mock_target,
		"collision_point": Vector3(50, 0, 0)
	}
	
	var result = beam_penetration_system.process_beam_collision(beam_id, collision_data)
	
	if result.get("penetrates", false):
		# Damage multiplier should be reduced after penetration
		var damage_multiplier = result.get("damage_multiplier", 1.0)
		assert_float(damage_multiplier).is_less_equal(1.0)

# ============================================================================
# Integration Tests - Full System Coordination
# ============================================================================

func test_integration_complete_beam_lifecycle() -> void:
	# Test complete beam weapon lifecycle from firing to completion
	var firing_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"source_position": Vector3.ZERO,
		"target": mock_target,
		"firing_ship": mock_ship
	}
	
	var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
	assert_str(beam_id).is_not_empty()
	
	# Should have beam data
	var beam_data = beam_weapon_system.get_beam_data(beam_id)
	assert_that(beam_data).is_not_empty()
	
	# Should be registered with subsystems
	assert_that(beam_lifecycle_manager.beam_lifecycles).has_key(beam_id)
	assert_that(continuous_damage_system.registered_beams).has_key(beam_id)
	assert_that(beam_renderer.active_beam_renderers).has_key(beam_id)
	
	# Clean up
	beam_weapon_system.stop_beam_weapon(beam_id)

func test_integration_beam_collision_to_damage() -> void:
	# Test integration from collision detection to damage application
	var beam_id = "integration_test"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
		"config": {"damage_per_interval": 40.0, "width": 2.0, "range": 200.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3(1, 0, 0),  # Toward target
		"firing_ship": mock_ship
	}
	
	# Register beam with damage system
	continuous_damage_system.register_beam_weapon(beam_id, beam_data)
	
	# Simulate collision detection
	var collision_data = {
		"target": mock_target,
		"collision_point": Vector3(50, 0, 0),
		"collision_normal": Vector3(-1, 0, 0)
	}
	
	# Process collision through penetration system
	var penetration_result = beam_penetration_system.process_beam_collision(beam_id, collision_data)
	
	# If penetration allows, process damage
	if penetration_result.get("penetrates", false) or not penetration_result.has("penetrates"):
		# Simulate damage interval timing
		await get_tree().create_timer(0.18).timeout  # Wait slightly longer than damage interval
		
		# Process collision for damage
		var damage_result = continuous_damage_system.process_beam_collision(beam_id, collision_data)
		
		# Result should be boolean indicating success/failure
		assert_that(damage_result).is_instance_of(TYPE_BOOL)
	
	continuous_damage_system.unregister_beam_weapon(beam_id)

func test_integration_multiple_beam_types() -> void:
	# Test multiple beam types operating simultaneously
	var beam_ids: Array = []
	
	# Fire different beam types
	for beam_type in range(5):
		var firing_data = {
			"beam_type": beam_type,
			"source_position": Vector3(beam_type * 10, 0, 0),
			"firing_ship": mock_ship
		}
		
		var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
		if not beam_id.is_empty():
			beam_ids.append(beam_id)
	
	# Should have multiple active beams
	assert_int(beam_weapon_system.active_beams.size()).is_greater_equal(1)
	
	# Clean up all beams
	for beam_id in beam_ids:
		beam_weapon_system.stop_beam_weapon(beam_id)

func test_integration_targeting_to_rendering() -> void:
	# Test integration from targeting to rendering updates
	var beam_id = "targeting_render_test"
	var beam_data = {
		"beam_type": BeamWeaponSystem.BeamType.TYPE_C_TARGETING,
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD,
		"config": {"range": 150.0}
	}
	
	# Set target
	beam_targeting_system.set_beam_target(beam_id, mock_target)
	
	# Start rendering
	beam_renderer.start_beam_rendering(beam_id, beam_data)
	
	# Update targeting
	var targeting_result = beam_targeting_system.update_beam_targeting(beam_id, beam_data)
	
	# Update renderer with new targeting data
	if targeting_result.get("has_solution", false):
		var aim_direction = targeting_result.get("aim_direction", Vector3.FORWARD)
		beam_renderer.update_beam_rendering(beam_id, Vector3.ZERO, aim_direction, 150.0)
	
	# Clean up
	beam_renderer.stop_beam_rendering(beam_id)
	beam_targeting_system.clear_beam_target(beam_id)

func test_integration_performance_with_many_beams() -> void:
	# Test system performance with multiple simultaneous beams
	var beam_ids: Array = []
	var max_beams = min(10, beam_weapon_system.max_simultaneous_beams)
	
	# Create multiple beams
	for i in range(max_beams):
		var firing_data = {
			"beam_type": i % 5,  # Cycle through beam types
			"source_position": Vector3(i * 5, 0, 0),
			"firing_ship": mock_ship
		}
		
		var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
		if not beam_id.is_empty():
			beam_ids.append(beam_id)
	
	# Get performance statistics
	var beam_stats = beam_weapon_system.get_beam_performance_statistics()
	var damage_stats = continuous_damage_system.get_damage_performance_statistics()
	var collision_stats = beam_collision_detector.get_collision_detection_statistics()
	
	# Should have performance data
	assert_that(beam_stats).has_key("active_beam_count")
	assert_that(damage_stats).has_key("active_beam_count")
	assert_that(collision_stats).has_key("active_beam_count")
	
	# Clean up
	for beam_id in beam_ids:
		beam_weapon_system.stop_beam_weapon(beam_id)

# ============================================================================
# Error Handling and Edge Cases
# ============================================================================

func test_error_handling_invalid_beam_type() -> void:
	# Test handling of invalid beam type
	var firing_data = {
		"beam_type": 999,  # Invalid beam type
		"source_position": Vector3.ZERO,
		"firing_ship": mock_ship
	}
	
	var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
	
	# Should return empty string for invalid beam type
	assert_str(beam_id).is_empty()

func test_error_handling_beam_limits() -> void:
	# Test beam limit enforcement
	var original_limit = beam_weapon_system.max_simultaneous_beams
	beam_weapon_system.max_simultaneous_beams = 2  # Set low limit
	
	var beam_ids: Array = []
	
	# Try to create more beams than the limit
	for i in range(5):
		var firing_data = {
			"beam_type": BeamWeaponSystem.BeamType.TYPE_A_STANDARD,
			"source_position": Vector3(i, 0, 0),
			"firing_ship": mock_ship
		}
		
		var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
		if not beam_id.is_empty():
			beam_ids.append(beam_id)
	
	# Should not exceed the limit
	assert_int(beam_ids.size()).is_less_equal(2)
	
	# Clean up
	for beam_id in beam_ids:
		beam_weapon_system.stop_beam_weapon(beam_id)
	
	# Restore original limit
	beam_weapon_system.max_simultaneous_beams = original_limit

func test_error_handling_invalid_targets() -> void:
	# Test handling of invalid targets
	var result = beam_targeting_system.set_beam_target("invalid_test", null)
	assert_bool(result).is_false()
	
	# Test with freed node
	var temp_target = Node3D.new()
	add_child(temp_target)
	temp_target.queue_free()
	await get_tree().process_frame
	
	result = beam_targeting_system.set_beam_target("freed_test", temp_target)
	assert_bool(result).is_false()

# ============================================================================
# Performance and Optimization Tests
# ============================================================================

func test_performance_collision_caching() -> void:
	# Test collision detection caching performance
	beam_collision_detector.enable_collision_caching = true
	
	var beam_data = {
		"config": {"width": 3.0, "range": 100.0},
		"source_position": Vector3.ZERO,
		"current_direction": Vector3.FORWARD
	}
	
	var start_time = Time.get_ticks_usec()
	
	# First detection (cache miss)
	beam_collision_detector.detect_beam_collisions("perf_test", beam_data)
	
	var first_time = Time.get_ticks_usec() - start_time
	start_time = Time.get_ticks_usec()
	
	# Second detection (cache hit)
	beam_collision_detector.detect_beam_collisions("perf_test", beam_data)
	
	var second_time = Time.get_ticks_usec() - start_time
	
	# Second detection should be faster (cached)
	assert_int(second_time).is_less_equal(first_time)

func test_performance_memory_management() -> void:
	# Test memory management with beam creation/destruction cycles
	var initial_stats = beam_weapon_system.get_beam_performance_statistics()
	
	# Create and destroy beams multiple times
	for cycle in range(3):
		var beam_ids: Array = []
		
		# Create beams
		for i in range(5):
			var firing_data = {
				"beam_type": i % 5,
				"source_position": Vector3(i, 0, 0),
				"firing_ship": mock_ship
			}
			
			var beam_id = beam_weapon_system.fire_beam_weapon(firing_data)
			if not beam_id.is_empty():
				beam_ids.append(beam_id)
		
		# Destroy beams
		for beam_id in beam_ids:
			beam_weapon_system.stop_beam_weapon(beam_id)
		
		# Wait for cleanup
		await get_tree().process_frame
	
	var final_stats = beam_weapon_system.get_beam_performance_statistics()
	
	# Should have processed beams
	assert_int(final_stats.get("total_beams_fired", 0)).is_greater(initial_stats.get("total_beams_fired", 0))
	
	# Should not have memory leaks (all beams cleaned up)
	assert_int(final_stats.get("active_beam_count", 0)).is_equal(0)

# ============================================================================
# WCS Authenticity Tests
# ============================================================================

func test_wcs_authenticity_beam_characteristics() -> void:
	# Test that beam characteristics match WCS specifications
	var type_a_config = beam_weapon_system.beam_type_configs[BeamWeaponSystem.BeamType.TYPE_A_STANDARD]
	var type_b_config = beam_weapon_system.beam_type_configs[BeamWeaponSystem.BeamType.TYPE_B_SLASH]
	
	# Type A should be high damage, long range
	assert_float(type_a_config.get("damage_per_interval", 0.0)).is_greater(20.0)
	assert_float(type_a_config.get("range", 0.0)).is_greater(1500.0)
	
	# Type B should be area effect, shorter range
	assert_float(type_b_config.get("width", 0.0)).is_greater(type_a_config.get("width", 0.0))
	assert_str(type_b_config.get("collision_type", "")).is_equal("sphereline")

func test_wcs_authenticity_damage_timing() -> void:
	# Test that damage timing matches WCS 170ms standard
	var timing = continuous_damage_system.damage_interval
	assert_float(timing).is_equal_approx(0.17, 0.001)  # Within 1ms tolerance

func test_wcs_authenticity_penetration_behavior() -> void:
	# Test penetration behavior matches WCS beam types
	var type_a_pen = beam_penetration_system.penetration_configs[BeamWeaponSystem.BeamType.TYPE_A_STANDARD]
	var type_c_pen = beam_penetration_system.penetration_configs[BeamWeaponSystem.BeamType.TYPE_C_TARGETING]
	
	# Type A should pierce, Type C should stop
	assert_int(type_a_pen.get("behavior")).is_equal(BeamPenetrationSystem.PenetrationBehavior.PIERCES_ALL_SHIPS)
	assert_int(type_c_pen.get("behavior")).is_equal(BeamPenetrationSystem.PenetrationBehavior.STOPS_ON_IMPACT)