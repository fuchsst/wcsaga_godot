extends GdUnitTestSuite

## Unit tests for AdvancedFiringSolutions firing calculations
## Tests weapon-specific firing solution algorithms and intercept mathematics

class_name TestAdvancedFiringSolutions

func test_basic_intercept_calculation_stationary_target():
	var shooter_pos = Vector3.ZERO
	var shooter_velocity = Vector3.ZERO
	var target_pos = Vector3(1000, 0, 0)
	var target_velocity = Vector3.ZERO
	var projectile_speed = 1500.0
	
	var solution = AdvancedFiringSolutions._calculate_basic_intercept(
		shooter_pos, shooter_velocity, target_pos, target_velocity, projectile_speed
	)
	
	assert_that(solution["has_solution"]).is_true()
	assert_that(solution["intercept_position"]).is_equal(target_pos)
	assert_that(solution["intercept_time"]).is_approximately(1000.0 / 1500.0, 0.01)

func test_basic_intercept_calculation_moving_target():
	var shooter_pos = Vector3.ZERO
	var shooter_velocity = Vector3.ZERO
	var target_pos = Vector3(500, 0, 0)
	var target_velocity = Vector3(0, 100, 0)  # Moving perpendicular
	var projectile_speed = 1000.0
	
	var solution = AdvancedFiringSolutions._calculate_basic_intercept(
		shooter_pos, shooter_velocity, target_pos, target_velocity, projectile_speed
	)
	
	assert_that(solution["has_solution"]).is_true()
	assert_that(solution["intercept_time"]).is_greater(0.0)
	
	# Intercept position should be ahead of current target position
	var intercept_pos = solution["intercept_position"]
	assert_that(intercept_pos.y).is_greater(0.0)  # Should lead the target

func test_basic_intercept_calculation_impossible_intercept():
	var shooter_pos = Vector3.ZERO
	var shooter_velocity = Vector3.ZERO
	var target_pos = Vector3(1000, 0, 0)
	var target_velocity = Vector3(200, 0, 0)  # Moving away fast
	var projectile_speed = 100.0  # Too slow to catch up
	
	var solution = AdvancedFiringSolutions._calculate_basic_intercept(
		shooter_pos, shooter_velocity, target_pos, target_velocity, projectile_speed
	)
	
	# Should either have no solution or fallback to current position
	if not solution["has_solution"]:
		assert_that(solution["intercept_position"]).is_equal(target_pos)
	else:
		# If solution exists, intercept time should be reasonable
		assert_that(solution["intercept_time"]).is_greater(0.0)

func test_energy_beam_solution_enhancement():
	var base_solution = {
		"distance_to_target": 800.0,
		"intercept_position": Vector3(800, 0, 0)
	}
	
	var weapon_data = {
		"projectile_speed": 10000.0,
		"convergence_distance": 600.0,
		"spread": 0.02
	}
	
	var target_analysis = {
		"velocity": Vector3(50, 0, 0)
	}
	
	var enhanced = AdvancedFiringSolutions._enhance_energy_beam_solution(
		base_solution, weapon_data, target_analysis
	)
	
	assert_that(enhanced["weapon_class"]).is_equal("energy_beam")
	assert_that(enhanced["beam_convergence"]).is_equal(600.0)
	assert_that(enhanced["convergence_accuracy"]).is_less_equal(1.0)
	assert_that(enhanced).contains_key("optimal_aim_point")

func test_projectile_solution_enhancement():
	var base_solution = {
		"distance_to_target": 1000.0,
		"intercept_time": 1.0,
		"intercept_position": Vector3(1000, 0, 0)
	}
	
	var weapon_data = {
		"spread": 0.04,
		"projectile_speed": 1200.0
	}
	
	var target_analysis = {
		"movement_pattern": AdvancedFiringSolutions.TargetMovementPattern.LINEAR,
		"velocity": Vector3(100, 0, 0)
	}
	
	var enhanced = AdvancedFiringSolutions._enhance_projectile_solution(
		base_solution, weapon_data, target_analysis
	)
	
	assert_that(enhanced["weapon_class"]).is_equal("projectile")
	assert_that(enhanced).contains_key("gravity_compensation")
	assert_that(enhanced).contains_key("projectile_spread")
	assert_that(enhanced).contains_key("burst_pattern")

func test_guided_missile_solution_enhancement():
	var base_solution = {
		"distance_to_target": 2500.0,
		"intercept_time": 3.0
	}
	
	var weapon_data = {
		"lock_time": 2.0,
		"guidance_accuracy": 0.9,
		"tracking_ability": 0.8,
		"projectile_speed": 800.0
	}
	
	var target_analysis = {
		"velocity": Vector3(150, 0, 0),
		"evasion_capability": 0.4
	}
	
	var enhanced = AdvancedFiringSolutions._enhance_guided_missile_solution(
		base_solution, weapon_data, target_analysis
	)
	
	assert_that(enhanced["weapon_class"]).is_equal("guided_missile")
	assert_that(enhanced["lock_time_required"]).is_equal(2.0)
	assert_that(enhanced["guidance_effectiveness"]).is_less_equal(0.8)
	assert_that(enhanced).contains_key("estimated_flight_time")
	assert_that(enhanced).contains_key("lock_quality")

func test_torpedo_solution_enhancement():
	var base_solution = {
		"distance_to_target": 3500.0,
		"intercept_time": 5.0
	}
	
	var weapon_data = {
		"lock_time": 3.0,
		"guidance_accuracy": 0.7,
		"projectile_speed": 600.0
	}
	
	var target_analysis = {
		"size_factor": 10.0,  # Large target
		"velocity": Vector3(80, 0, 0)
	}
	
	var enhanced = AdvancedFiringSolutions._enhance_torpedo_solution(
		base_solution, weapon_data, target_analysis
	)
	
	assert_that(enhanced["weapon_class"]).is_equal("torpedo")
	assert_that(enhanced["size_effectiveness"]).is_equal(2.0)  # Capped at 2.0
	assert_that(enhanced["torpedo_lock_time"]).is_equal(3.0)
	assert_that(enhanced).contains_key("vulnerability_window")

func test_area_weapon_solution_enhancement():
	var base_solution = {
		"intercept_position": Vector3(1000, 0, 0)
	}
	
	var weapon_data = {
		"area_radius": 150.0
	}
	
	var target_analysis = {
		"velocity": Vector3(120, 0, 0)
	}
	
	var enhanced = AdvancedFiringSolutions._enhance_area_weapon_solution(
		base_solution, weapon_data, target_analysis
	)
	
	assert_that(enhanced["weapon_class"]).is_equal("area_weapon")
	assert_that(enhanced["area_effect_radius"]).is_equal(150.0)
	assert_that(enhanced).contains_key("optimal_blast_center")
	assert_that(enhanced).contains_key("coverage_pattern")

func test_comprehensive_firing_solution_calculation():
	var shooter_pos = Vector3.ZERO
	var shooter_velocity = Vector3(50, 0, 0)
	var target_pos = Vector3(800, 0, 0)
	var target_velocity = Vector3(100, 0, 0)
	var weapon_class = AdvancedFiringSolutions.WeaponClass.PROJECTILE
	
	var weapon_specs = {
		"projectile_speed": 1200.0,
		"spread": 0.03,
		"optimal_range": 600.0
	}
	
	var target_analysis = {
		"velocity": target_velocity,
		"size_factor": 2.0,
		"evasion_capability": 0.3
	}
	
	var solution = AdvancedFiringSolutions.calculate_firing_solution(
		shooter_pos, shooter_velocity, target_pos, target_velocity,
		weapon_class, weapon_specs, target_analysis
	)
	
	assert_that(solution).contains_key("has_solution")
	assert_that(solution).contains_key("hit_probability")
	assert_that(solution).contains_key("effectiveness_rating")
	assert_that(solution).contains_key("confidence_level")
	assert_that(solution).contains_key("weapon_class")

func test_target_movement_prediction_linear():
	var base_solution = {
		"intercept_position": Vector3(1000, 0, 0),
		"intercept_time": 2.0
	}
	
	var target_analysis = {
		"velocity": Vector3(100, 0, 0)
	}
	
	var enhancement = AdvancedFiringSolutions._enhance_target_prediction(
		base_solution, 
		AdvancedFiringSolutions.TargetMovementPattern.LINEAR,
		target_analysis
	)
	
	assert_that(enhancement["prediction_accuracy"]).is_equal(0.85)
	assert_that(enhancement["enhanced_intercept"]).is_equal(base_solution["intercept_position"])

func test_target_movement_prediction_accelerating():
	var base_solution = {
		"intercept_position": Vector3(1000, 0, 0),
		"intercept_time": 2.0
	}
	
	var target_analysis = {
		"acceleration": Vector3(20, 0, 0)
	}
	
	var enhancement = AdvancedFiringSolutions._enhance_target_prediction(
		base_solution,
		AdvancedFiringSolutions.TargetMovementPattern.ACCELERATING,
		target_analysis
	)
	
	assert_that(enhancement["prediction_accuracy"]).is_equal(0.75)
	# Enhanced intercept should account for acceleration
	var enhanced_pos = enhancement["enhanced_intercept"]
	assert_that(enhanced_pos.x).is_greater(base_solution["intercept_position"].x)

func test_target_movement_prediction_evasive():
	var base_solution = {
		"intercept_position": Vector3(1000, 0, 0),
		"intercept_time": 3.0
	}
	
	var target_analysis = {
		"evasion_intensity": 0.7
	}
	
	var enhancement = AdvancedFiringSolutions._enhance_target_prediction(
		base_solution,
		AdvancedFiringSolutions.TargetMovementPattern.EVASIVE,
		target_analysis
	)
	
	assert_that(enhancement["prediction_accuracy"]).is_equal(0.4)
	assert_that(enhancement).contains_key("uncertainty_radius")
	assert_that(enhancement["uncertainty_radius"]).is_greater(0.0)

func test_circular_motion_prediction():
	var solution = {
		"intercept_time": 2.0
	}
	
	var target_analysis = {
		"circle_center": Vector3(500, 0, 0),
		"circle_radius": 300.0,
		"angular_velocity": 0.5,
		"current_angle": 0.0
	}
	
	var predicted_pos = AdvancedFiringSolutions._predict_circular_motion(solution, target_analysis)
	
	# Should be at new position after rotating for intercept time
	var expected_angle = 0.0 + 0.5 * 2.0  # 1 radian
	var expected_pos = target_analysis["circle_center"] + Vector3(cos(expected_angle), 0, sin(expected_angle)) * 300.0
	
	assert_that(predicted_pos.x).is_approximately(expected_pos.x, 0.1)
	assert_that(predicted_pos.z).is_approximately(expected_pos.z, 0.1)

func test_spiral_motion_prediction():
	var solution = {
		"intercept_time": 1.5
	}
	
	var target_analysis = {
		"spiral_center": Vector3.ZERO,
		"radial_velocity": 50.0,
		"angular_velocity": 0.3,
		"current_radius": 400.0,
		"current_angle": 0.0
	}
	
	var predicted_pos = AdvancedFiringSolutions._predict_spiral_motion(solution, target_analysis)
	
	# Should have moved outward and rotated
	var expected_radius = 400.0 + 50.0 * 1.5  # 475.0
	var expected_angle = 0.0 + 0.3 * 1.5      # 0.45
	
	var predicted_radius = predicted_pos.length()
	assert_that(predicted_radius).is_approximately(expected_radius, 1.0)

func test_hit_probability_calculation():
	var solution = {
		"distance_to_target": 600.0,
		"lead_angle": 0.2,
		"relative_velocity": Vector3(100, 0, 0),
		"weapon_spread": 0.03,
		"prediction_accuracy": 0.8
	}
	
	var weapon_data = {
		"optimal_range": 500.0,
		"max_range": 1200.0
	}
	
	var target_analysis = {}
	
	var hit_prob = AdvancedFiringSolutions._calculate_hit_probability(solution, weapon_data, target_analysis)
	
	assert_that(hit_prob).is_between(0.0, 1.0)
	assert_that(hit_prob).is_greater(0.3)  # Should be reasonable probability

func test_effectiveness_rating_calculation():
	var solution = {
		"hit_probability": 0.7
	}
	
	var weapon_data = {
		"damage_rating": 1.2
	}
	
	var target_analysis = {
		"vulnerability": 0.6,
		"tactical_value": 0.8
	}
	
	var effectiveness = AdvancedFiringSolutions._calculate_effectiveness_rating(solution, weapon_data, target_analysis)
	
	# Should be product of factors
	var expected = 0.7 * 1.2 * 0.6 * 0.8
	assert_that(effectiveness).is_approximately(expected, 0.01)

func test_confidence_level_calculation():
	var solution = {
		"has_solution": true,
		"prediction_accuracy": 0.8
	}
	
	var target_analysis = {
		"data_quality": 0.7,
		"solution_stability": 0.9
	}
	
	var confidence = AdvancedFiringSolutions._calculate_confidence_level(solution, target_analysis)
	
	# Should be product of accuracy factors
	var expected = 0.8 * 0.7 * 0.9
	assert_that(confidence).is_approximately(expected, 0.01)

func test_confidence_level_no_solution():
	var solution = {
		"has_solution": false
	}
	
	var target_analysis = {}
	
	var confidence = AdvancedFiringSolutions._calculate_confidence_level(solution, target_analysis)
	
	assert_that(confidence).is_equal(0.0)

func test_gravity_effect_calculation():
	var flight_time = 2.0
	var distance = 1000.0
	
	var gravity_effect = AdvancedFiringSolutions._calculate_gravity_effect(flight_time, distance)
	
	# Should be negative Y (downward)
	assert_that(gravity_effect.y).is_less(0.0)
	# Effect should increase with flight time squared
	assert_that(abs(gravity_effect.y)).is_approximately(0.5 * 9.81 * 4.0, 0.1)

func test_burst_pattern_calculation():
	var solution = {
		"intercept_position": Vector3(800, 0, 0),
		"distance_to_target": 800.0
	}
	
	var weapon_data = {
		"spread": 0.05
	}
	
	var target_analysis = {}
	
	var pattern = AdvancedFiringSolutions._calculate_burst_pattern(solution, weapon_data, target_analysis)
	
	assert_that(pattern).has_size(5)  # Center + 4 spread shots
	assert_that(pattern[0]).is_equal(solution["intercept_position"])  # Center shot
	
	# Other shots should be spread around center
	var spread_radius = 0.05 * 800.0
	for i in range(1, 5):
		var distance_from_center = pattern[i].distance_to(pattern[0])
		assert_that(distance_from_center).is_approximately(spread_radius, 1.0)

func test_missile_launch_window_calculation():
	var solution = {
		"distance_to_target": 2800.0
	}
	
	var weapon_data = {
		"lock_time": 2.5,
		"max_range": 4000.0
	}
	
	var target_analysis = {}
	
	var window = AdvancedFiringSolutions._calculate_missile_launch_window(solution, weapon_data, target_analysis)
	
	assert_that(window["lock_time_required"]).is_equal(2.5)
	assert_that(window["optimal_launch_distance"]).is_equal(2800.0)  # 70% of max range
	assert_that(window["window_open"]).is_true()

func test_missile_lock_quality_assessment():
	var solution = {
		"distance_to_target": 1500.0
	}
	
	var target_analysis = {
		"velocity": Vector3(200, 0, 0),
		"heat_signature": 0.7,
		"size_factor": 3.0
	}
	
	var lock_quality = AdvancedFiringSolutions._assess_missile_lock_quality(solution, target_analysis)
	
	assert_that(lock_quality).is_between(0.0, 1.0)
	assert_that(lock_quality).is_greater(0.4)  # Should be reasonable with good signature

func test_area_weapon_effectiveness():
	var solution = {
		"area_effect_radius": 120.0
	}
	
	var target_analysis = {
		"size_factor": 2.5,
		"velocity": Vector3(150, 0, 0)
	}
	
	var effectiveness = AdvancedFiringSolutions._calculate_area_weapon_effectiveness(solution, target_analysis)
	
	assert_that(effectiveness).is_greater(0.0)
	# Larger targets should be easier to hit with area weapons
	assert_that(effectiveness).is_greater(1.0)

func test_beam_weapon_tracking():
	var solution = {
		"relative_position": Vector3(1000, 0, 0)
	}
	
	var target_analysis = {
		"velocity": Vector3(0, 200, 0)
	}
	
	var angular_velocity = AdvancedFiringSolutions._calculate_target_angular_velocity(solution, target_analysis)
	
	# Angular velocity should be perpendicular velocity / distance
	var expected = 200.0 / 1000.0 * 180.0 / PI  # Convert to degrees
	assert_that(angular_velocity).is_approximately(expected, 1.0)

func test_special_ordnance_deployment_assessment():
	var solution = {}
	
	var weapon_data = {}
	
	var target_analysis = {
		"velocity": Vector3(150, 0, 0),  # Slow enough for deployment
		"movement_predictability": 0.8,
		"tactical_value": 0.7
	}
	
	var deployment = AdvancedFiringSolutions._assess_special_ordnance_deployment(solution, weapon_data, target_analysis)
	
	assert_that(deployment["deployment_feasible"]).is_true()
	assert_that(deployment["target_predictability"]).is_equal(0.8)
	assert_that(deployment["tactical_advantage"]).is_equal(0.7)

func test_weapon_characteristics_database():
	# Test that weapon characteristics are properly defined
	var energy_beam = AdvancedFiringSolutions.weapon_characteristics[AdvancedFiringSolutions.WeaponClass.ENERGY_BEAM]
	assert_that(energy_beam["projectile_speed"]).is_equal(10000.0)
	assert_that(energy_beam["optimal_range"]).is_equal(800.0)
	
	var missile = AdvancedFiringSolutions.weapon_characteristics[AdvancedFiringSolutions.WeaponClass.GUIDED_MISSILE]
	assert_that(missile["tracking_ability"]).is_equal(0.8)
	assert_that(missile["guidance_accuracy"]).is_equal(0.9)
	
	var torpedo = AdvancedFiringSolutions.weapon_characteristics[AdvancedFiringSolutions.WeaponClass.TORPEDO]
	assert_that(torpedo["projectile_speed"]).is_equal(600.0)
	assert_that(torpedo["lock_time"]).is_equal(2.5)

func test_weapon_specific_enhancements():
	# Test each weapon class gets appropriate enhancements
	var base_solution = {"distance_to_target": 1000.0}
	var weapon_data = {}
	var target_analysis = {"velocity": Vector3(100, 0, 0)}
	
	# Energy beam
	var beam_solution = AdvancedFiringSolutions.calculate_firing_solution(
		Vector3.ZERO, Vector3.ZERO, Vector3(1000, 0, 0), Vector3(100, 0, 0),
		AdvancedFiringSolutions.WeaponClass.ENERGY_BEAM, weapon_data, target_analysis
	)
	assert_that(beam_solution).contains_key("beam_convergence")
	
	# Guided missile
	var missile_solution = AdvancedFiringSolutions.calculate_firing_solution(
		Vector3.ZERO, Vector3.ZERO, Vector3(2000, 0, 0), Vector3(100, 0, 0),
		AdvancedFiringSolutions.WeaponClass.GUIDED_MISSILE, weapon_data, target_analysis
	)
	assert_that(missile_solution).contains_key("guidance_effectiveness")
	
	# Torpedo
	var torpedo_solution = AdvancedFiringSolutions.calculate_firing_solution(
		Vector3.ZERO, Vector3.ZERO, Vector3(3000, 0, 0), Vector3(50, 0, 0),
		AdvancedFiringSolutions.WeaponClass.TORPEDO, weapon_data, target_analysis
	)
	assert_that(torpedo_solution).contains_key("size_effectiveness")

func test_edge_case_zero_distance():
	var solution = AdvancedFiringSolutions.calculate_firing_solution(
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		AdvancedFiringSolutions.WeaponClass.PROJECTILE, {}, {}
	)
	
	# Should handle zero distance gracefully
	assert_that(solution).contains_key("has_solution")
	assert_that(solution["distance_to_target"]).is_equal(0.0)

func test_edge_case_very_fast_target():
	# Target moving faster than projectile
	var solution = AdvancedFiringSolutions.calculate_firing_solution(
		Vector3.ZERO, Vector3.ZERO, Vector3(1000, 0, 0), Vector3(2000, 0, 0),
		AdvancedFiringSolutions.WeaponClass.PROJECTILE, {"projectile_speed": 500.0}, {}
	)
	
	# Should either provide fallback solution or indicate no solution
	assert_that(solution).contains_key("has_solution")
	assert_that(solution).contains_key("intercept_position")