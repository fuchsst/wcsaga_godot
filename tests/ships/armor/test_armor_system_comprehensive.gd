extends GdUnitTestSuite

## SHIP-011 Comprehensive Test Suite: Armor and Resistance Calculations
## Tests all seven acceptance criteria with integration scenarios
## Validates WCS-authentic armor mechanics and component coordination

# Test fixtures
var test_ship: Node
var armor_type_manager: ArmorTypeManager
var penetration_calculator: PenetrationCalculator
var weapon_penetration_system: WeaponPenetrationSystem
var ship_armor_configuration: ShipArmorConfiguration
var armor_degradation_tracker: ArmorDegradationTracker
var critical_hit_detector: CriticalHitDetector
var armor_visualization_controller: ArmorVisualizationController

func before_test() -> void:
	# Create test ship
	test_ship = Node3D.new()
	test_ship.name = "TestShip"
	add_child(test_ship)
	
	# Create armor system components
	armor_type_manager = ArmorTypeManager.new()
	penetration_calculator = PenetrationCalculator.new()
	weapon_penetration_system = WeaponPenetrationSystem.new()
	ship_armor_configuration = ShipArmorConfiguration.new()
	armor_degradation_tracker = ArmorDegradationTracker.new()
	critical_hit_detector = CriticalHitDetector.new()
	armor_visualization_controller = ArmorVisualizationController.new()
	
	# Add components to test ship
	test_ship.add_child(armor_type_manager)
	test_ship.add_child(penetration_calculator)
	test_ship.add_child(weapon_penetration_system)
	test_ship.add_child(ship_armor_configuration)
	test_ship.add_child(armor_degradation_tracker)
	test_ship.add_child(critical_hit_detector)
	test_ship.add_child(armor_visualization_controller)
	
	# Initialize components
	armor_type_manager.initialize_for_ship(test_ship)
	ship_armor_configuration.initialize_for_ship(test_ship)
	armor_degradation_tracker.initialize_for_ship(test_ship)
	critical_hit_detector.initialize_for_ship(test_ship)
	armor_visualization_controller.initialize_for_ship(test_ship)

func after_test() -> void:
	if test_ship:
		test_ship.queue_free()

# ============================================================================
# AC1: Material-Based Resistance Calculations
# ============================================================================

func test_ac1_armor_type_resistance_calculation() -> void:
	# Test WCS-authentic damage resistance calculations
	var kinetic_damage = 100.0
	var laser_damage = 100.0
	
	# Light armor - vulnerable to all damage types
	var light_resistance = armor_type_manager.calculate_damage_resistance(
		ArmorTypes.Class.LIGHT, DamageTypes.Type.KINETIC, kinetic_damage
	)
	assert_float(light_resistance.damage_reduction).is_between(5.0, 20.0)
	
	# Heavy armor - strong against kinetic
	var heavy_resistance = armor_type_manager.calculate_damage_resistance(
		ArmorTypes.Class.HEAVY, DamageTypes.Type.KINETIC, kinetic_damage
	)
	assert_float(heavy_resistance.damage_reduction).is_between(40.0, 60.0)
	
	# Energy-resistant armor vs laser
	var energy_resistance = armor_type_manager.calculate_damage_resistance(
		ArmorTypes.Class.ENERGY, DamageTypes.Type.ENERGY, laser_damage
	)
	assert_float(energy_resistance.damage_reduction).is_between(50.0, 70.0)

func test_ac1_material_effectiveness_matrix() -> void:
	# Test effectiveness matrix for weapon-armor combinations
	var effectiveness_matrix = armor_type_manager.get_effectiveness_matrix()
	
	# Matrix should contain all armor-damage type combinations
	assert_int(effectiveness_matrix.size()).is_greater(0)
	
	# Test specific combinations
	var kinetic_vs_heavy = effectiveness_matrix.get("kinetic_vs_heavy", {})
	assert_that(kinetic_vs_heavy).is_not_empty()
	assert_float(kinetic_vs_heavy.get("effectiveness", 0.0)).is_between(0.4, 0.7)

func test_ac1_resistance_modifier_calculation() -> void:
	# Test resistance modifier calculations with various factors
	var test_conditions: Dictionary = {
		"angle_of_impact": 45.0,
		"impact_velocity": 200.0,
		"armor_thickness": 2.0,
		"armor_degradation": 0.3
	}
	
	var modifier = armor_type_manager.calculate_resistance_modifier(
		ArmorTypes.Class.STANDARD, test_conditions
	)
	
	assert_float(modifier.angle_modifier).is_between(0.5, 1.0)
	assert_float(modifier.thickness_modifier).is_greater(1.0)
	assert_float(modifier.degradation_modifier).is_less(1.0)

# ============================================================================
# AC2: Impact Angle and Penetration Analysis
# ============================================================================

func test_ac2_penetration_angle_calculation() -> void:
	# Test angle-based penetration effectiveness
	var impact_location = Vector3(0, 0, 1)  # Front impact
	var impact_velocity = Vector3(0, 0, -100)  # Head-on
	
	# Perpendicular impact (90 degrees) - maximum effectiveness
	var perpendicular_result = penetration_calculator.calculate_penetration_effectiveness(
		impact_location, impact_velocity, 1.0, ArmorTypes.Class.STANDARD
	)
	assert_float(perpendicular_result.angle_effectiveness).is_greater(0.9)
	
	# Glancing impact (15 degrees) - reduced effectiveness
	var glancing_velocity = Vector3(50, 0, -100)  # Angled impact
	var glancing_result = penetration_calculator.calculate_penetration_effectiveness(
		impact_location, glancing_velocity, 1.0, ArmorTypes.Class.STANDARD
	)
	assert_float(glancing_result.angle_effectiveness).is_less(0.6)

func test_ac2_penetration_depth_modeling() -> void:
	# Test penetration depth calculations with different weapons
	var impact_location = Vector3(0, 0, 1)
	var impact_velocity = Vector3(0, 0, -200)
	
	# High-velocity kinetic projectile
	var kinetic_result = penetration_calculator.calculate_penetration_depth(
		impact_location, impact_velocity, 2.0, ArmorTypes.Class.LIGHT
	)
	assert_float(kinetic_result.penetration_depth).is_greater(1.5)
	
	# Energy weapon - different penetration characteristics
	var energy_result = penetration_calculator.calculate_penetration_depth(
		impact_location, impact_velocity, 1.0, ArmorTypes.Class.HEAVY
	)
	assert_float(energy_result.penetration_depth).is_less(1.0)

func test_ac2_ricochet_probability() -> void:
	# Test ricochet calculations for glancing impacts
	var shallow_angle_velocity = Vector3(90, 0, -10)  # Very shallow
	var impact_location = Vector3(0, 0, 1)
	
	var ricochet_result = penetration_calculator.calculate_ricochet_probability(
		impact_location, shallow_angle_velocity, ArmorTypes.Class.HEAVY
	)
	
	assert_float(ricochet_result.ricochet_probability).is_greater(0.7)
	assert_that(ricochet_result.ricochet_direction).is_not_null()

# ============================================================================
# AC3: Weapon-Specific Penetration Characteristics
# ============================================================================

func test_ac3_weapon_armor_interaction() -> void:
	# Test weapon-specific penetration against different armor types
	var impact_conditions: Dictionary = {
		"velocity": 150.0,
		"impact_angle": 0.0,
		"range_factor": 1.0
	}
	
	# Laser vs Energy-Resistant armor
	var laser_vs_energy = weapon_penetration_system.calculate_weapon_penetration_effectiveness(
		WeaponTypes.Type.PRIMARY_LASER, ArmorTypes.Class.ENERGY, impact_conditions
	)
	assert_float(laser_vs_energy.final_effectiveness).is_less(0.6)
	
	# Mass Driver vs Heavy armor
	var kinetic_vs_heavy = weapon_penetration_system.calculate_weapon_penetration_effectiveness(
		WeaponTypes.Type.PRIMARY_MASS_DRIVER, ArmorTypes.Class.HEAVY, impact_conditions
	)
	assert_float(kinetic_vs_heavy.final_effectiveness).is_between(0.6, 1.0)

func test_ac3_optimal_weapon_recommendations() -> void:
	# Test optimal weapon selection against specific armor
	var optimal_weapons = weapon_penetration_system.get_optimal_weapons_against_armor(
		ArmorTypes.Class.HEAVY
	)
	
	assert_int(optimal_weapons.size()).is_greater(0)
	
	# First weapon should be most effective
	var best_weapon = optimal_weapons[0]
	assert_float(best_weapon.effectiveness).is_greater(0.5)
	assert_that(best_weapon.weapon_name).is_not_empty()

func test_ac3_ammunition_type_modifiers() -> void:
	# Test different ammunition types against armor
	var base_conditions: Dictionary = {
		"velocity": 200.0,
		"impact_angle": 0.0
	}
	
	# Armor-piercing ammunition
	var ap_conditions = base_conditions.duplicate()
	ap_conditions["ammunition_type"] = "armor_piercing"
	
	var ap_result = weapon_penetration_system.calculate_weapon_penetration_effectiveness(
		WeaponTypes.Type.PRIMARY_MASS_DRIVER, ArmorTypes.Class.HEAVY, ap_conditions
	)
	
	# Standard ammunition
	var std_result = weapon_penetration_system.calculate_weapon_penetration_effectiveness(
		WeaponTypes.Type.PRIMARY_MASS_DRIVER, ArmorTypes.Class.HEAVY, base_conditions
	)
	
	# AP should be more effective
	assert_float(ap_result.final_effectiveness).is_greater(std_result.final_effectiveness)

# ============================================================================
# AC4: Ship-Specific Armor Configuration
# ============================================================================

func test_ac4_armor_zone_configuration() -> void:
	# Test ship-specific armor zone setup
	var coverage_analysis = ship_armor_configuration.get_armor_coverage_analysis()
	
	assert_int(coverage_analysis.armor_zone_count).is_greater(0)
	assert_float(coverage_analysis.coverage_percentage).is_between(80.0, 100.0)
	assert_float(coverage_analysis.average_thickness).is_greater(0.0)

func test_ac4_armor_data_at_location() -> void:
	# Test armor data retrieval for hit locations
	var front_hit = Vector3(0, 0, 2)
	var armor_data = ship_armor_configuration.get_armor_data_at_location(front_hit)
	
	assert_that(armor_data).is_not_empty()
	assert_that(armor_data.has("armor_type")).is_true()
	assert_that(armor_data.has("actual_thickness")).is_true()
	assert_that(armor_data.has("zone_name")).is_true()

func test_ac4_vulnerable_zone_identification() -> void:
	# Test identification of vulnerable zones
	var vulnerable_zones = ship_armor_configuration.get_vulnerable_zones()
	
	assert_int(vulnerable_zones.size()).is_greater(0)
	
	for zone in vulnerable_zones:
		assert_float(zone.vulnerability_factor).is_greater(0.3)
		assert_that(zone.zone_name).is_not_empty()
		assert_that(zone.location).is_not_null()

# ============================================================================
# AC5: Progressive Armor Degradation
# ============================================================================

func test_ac5_impact_degradation() -> void:
	# Test armor degradation from repeated impacts
	var zone_name = "hull"
	var initial_status = armor_degradation_tracker.get_degradation_status(zone_name)
	var initial_degradation = initial_status.get("total_degradation", 0.0)
	
	# Apply multiple impacts
	for i in range(5):
		armor_degradation_tracker.apply_impact_degradation(
			zone_name, 50.0, DamageTypes.Type.KINETIC
		)
	
	var final_status = armor_degradation_tracker.get_degradation_status(zone_name)
	var final_degradation = final_status.get("total_degradation", 0.0)
	
	assert_float(final_degradation).is_greater(initial_degradation)

func test_ac5_thermal_degradation() -> void:
	# Test thermal degradation from heat exposure
	var zone_name = "hull"
	var thermal_damage = armor_degradation_tracker.apply_thermal_degradation(
		zone_name, 200.0, 5.0  # 200°C for 5 seconds
	)
	
	assert_float(thermal_damage).is_greater(0.0)
	
	var status = armor_degradation_tracker.get_degradation_status(zone_name)
	assert_float(status.thermal_degradation).is_greater(0.0)

func test_ac5_fatigue_accumulation() -> void:
	# Test fatigue accumulation and stress concentration
	var zone_name = "wing_joint"
	
	# Apply repeated stress
	for i in range(10):
		armor_degradation_tracker.apply_impact_degradation(
			zone_name, 25.0, DamageTypes.Type.KINETIC
		)
	
	var status = armor_degradation_tracker.get_degradation_status(zone_name)
	assert_float(status.fatigue_level).is_greater(0.1)
	assert_float(status.structural_integrity).is_less(1.0)

# ============================================================================
# AC6: Critical Hit Detection and Weak Points
# ============================================================================

func test_ac6_weak_point_detection() -> void:
	# Test weak point identification
	var weak_points = critical_hit_detector.get_weak_points_analysis()
	
	assert_int(weak_points.size()).is_greater(0)
	
	for weak_point in weak_points:
		assert_that(weak_point.weak_point_name).is_not_empty()
		assert_float(weak_point.vulnerability_factor).is_greater(1.0)
		assert_float(weak_point.tactical_value).is_greater(0.0)

func test_ac6_critical_hit_analysis() -> void:
	# Test critical hit calculations
	var engine_location = Vector3(0, 0, -2)  # Engine location
	var hit_result = critical_hit_detector.analyze_hit_for_critical(
		engine_location, 100.0, DamageTypes.Type.KINETIC
	)
	
	assert_that(hit_result).is_not_empty()
	assert_float(hit_result.critical_chance).is_greater(0.05)  # Base + weak point bonus
	assert_that(hit_result.hit_classification).is_not_empty()

func test_ac6_targeting_recommendations() -> void:
	# Test optimal targeting recommendations
	var recommendations = critical_hit_detector.get_optimal_targeting_recommendations(
		WeaponTypes.Type.PRIMARY_MASS_DRIVER
	)
	
	assert_int(recommendations.size()).is_greater(0)
	
	var best_target = recommendations[0]
	assert_float(best_target.effectiveness_rating).is_greater(0.0)
	assert_that(best_target.tactical_recommendation).is_not_empty()

# ============================================================================
# AC7: Armor Status Visualization
# ============================================================================

func test_ac7_armor_visualization_initialization() -> void:
	# Test visualization system initialization
	var status = armor_visualization_controller.get_armor_visualization_status()
	
	assert_int(status.total_zones).is_greater_equal(0)
	assert_float(status.average_integrity).is_between(0.0, 1.0)
	assert_that(status.overall_condition).is_not_empty()

func test_ac7_damage_visualization() -> void:
	# Test damage visualization at specific locations
	var hit_location = Vector3(1, 0, 0)
	armor_visualization_controller.visualize_damage_at_location(
		hit_location, 75.0, DamageTypes.Type.EXPLOSIVE
	)
	
	var status = armor_visualization_controller.get_armor_visualization_status()
	assert_int(status.damage_indicators_active).is_greater(0)

func test_ac7_weak_point_highlighting() -> void:
	# Test weak point visualization
	armor_visualization_controller.highlight_weak_points(true)
	
	var status = armor_visualization_controller.get_armor_visualization_status()
	assert_bool(status.weak_points_visible).is_true()
	
	# Turn off highlighting
	armor_visualization_controller.highlight_weak_points(false)
	
	status = armor_visualization_controller.get_armor_visualization_status()
	assert_bool(status.weak_points_visible).is_false()

# ============================================================================
# Integration Tests - Component Coordination
# ============================================================================

func test_integration_complete_damage_sequence() -> void:
	# Test complete damage sequence through all components
	var hit_location = Vector3(0, 0, 1)  # Front armor
	var damage_amount = 100.0
	var damage_type = DamageTypes.Type.KINETIC
	
	# 1. Get armor configuration at hit location
	var armor_data = ship_armor_configuration.get_armor_data_at_location(hit_location)
	assert_that(armor_data).is_not_empty()
	
	# 2. Calculate armor resistance
	var resistance = armor_type_manager.calculate_damage_resistance(
		armor_data.armor_type, damage_type, damage_amount
	)
	assert_that(resistance).is_not_empty()
	
	# 3. Calculate penetration effectiveness
	var penetration = penetration_calculator.calculate_penetration_effectiveness(
		hit_location, Vector3(0, 0, -100), 1.0, armor_data.armor_type
	)
	assert_that(penetration).is_not_empty()
	
	# 4. Apply degradation
	armor_degradation_tracker.apply_impact_degradation(
		armor_data.zone_name, damage_amount, damage_type
	)
	
	# 5. Check for critical hits
	var critical_result = critical_hit_detector.analyze_hit_for_critical(
		hit_location, damage_amount, damage_type
	)
	assert_that(critical_result).is_not_empty()
	
	# 6. Update visualization
	armor_visualization_controller.update_armor_zone_visualization(armor_data.zone_name)
	
	var vis_status = armor_visualization_controller.get_armor_visualization_status()
	assert_int(vis_status.total_zones).is_greater(0)

func test_integration_weapon_effectiveness_analysis() -> void:
	# Test comprehensive weapon effectiveness analysis
	var analysis = weapon_penetration_system.analyze_weapon_armor_interaction(
		WeaponTypes.Type.PRIMARY_MASS_DRIVER, ArmorTypes.Class.HEAVY
	)
	
	assert_that(analysis).is_not_empty()
	assert_that(analysis.base_result).is_not_empty()
	assert_int(analysis.angle_sensitivity.size()).is_greater(0)
	assert_int(analysis.velocity_sensitivity.size()).is_greater(0)
	assert_that(analysis.tactical_recommendations).is_not_empty()

func test_integration_armor_system_performance() -> void:
	# Test system performance under load
	var start_time = Time.get_ticks_msec()
	
	# Simulate multiple simultaneous hits
	for i in range(50):
		var random_location = Vector3(
			randf_range(-2, 2),
			randf_range(-1, 1),
			randf_range(-2, 2)
		)
		
		# Complete damage processing
		var armor_data = ship_armor_configuration.get_armor_data_at_location(random_location)
		var resistance = armor_type_manager.calculate_damage_resistance(
			armor_data.get("armor_type", ArmorTypes.Class.STANDARD),
			DamageTypes.Type.KINETIC,
			randf_range(25, 100)
		)
		
		armor_degradation_tracker.apply_impact_degradation(
			armor_data.get("zone_name", "hull"),
			randf_range(25, 100),
			DamageTypes.Type.KINETIC
		)
	
	var end_time = Time.get_ticks_msec()
	var processing_time = end_time - start_time
	
	# Should process 50 hits in under 100ms
	assert_int(processing_time).is_less(100)

# ============================================================================
# Error Handling and Edge Cases
# ============================================================================

func test_error_handling_invalid_inputs() -> void:
	# Test system behavior with invalid inputs
	var result = armor_type_manager.calculate_damage_resistance(
		999, DamageTypes.Type.KINETIC, -50.0  # Invalid armor type, negative damage
	)
	assert_that(result).is_not_null()  # Should handle gracefully
	
	# Invalid hit location
	var armor_data = ship_armor_configuration.get_armor_data_at_location(
		Vector3(999, 999, 999)  # Far outside ship bounds
	)
	assert_that(armor_data).is_not_empty()  # Should return default data

func test_edge_case_zero_damage() -> void:
	# Test zero damage scenarios
	var result = armor_type_manager.calculate_damage_resistance(
		ArmorTypes.Class.STANDARD, DamageTypes.Type.KINETIC, 0.0
	)
	assert_float(result.get("damage_reduction", 0.0)).is_equal(0.0)

func test_edge_case_maximum_degradation() -> void:
	# Test behavior at maximum degradation
	var zone_name = "test_zone"
	
	# Apply excessive damage to reach maximum degradation
	for i in range(100):
		armor_degradation_tracker.apply_impact_degradation(
			zone_name, 100.0, DamageTypes.Type.KINETIC
		)
	
	var status = armor_degradation_tracker.get_degradation_status(zone_name)
	assert_float(status.total_degradation).is_less_equal(1.0)  # Should cap at 100%

# ============================================================================
# WCS Compatibility Tests
# ============================================================================

func test_wcs_compatibility_damage_values() -> void:
	# Test that damage values align with WCS expectations
	var standard_laser_damage = 35.0  # Typical WCS laser damage
	
	var resistance = armor_type_manager.calculate_damage_resistance(
		ArmorTypes.Class.LIGHT, DamageTypes.Type.ENERGY, standard_laser_damage
	)
	
	# Light armor should take significant damage from lasers
	var effective_damage = standard_laser_damage - resistance.damage_reduction
	assert_float(effective_damage).is_between(25.0, 35.0)

func test_wcs_compatibility_armor_thresholds() -> void:
	# Test that armor degradation thresholds match WCS behavior
	var status = armor_degradation_tracker.get_degradation_status("hull")
	
	# Check that condition ratings align with WCS expectations
	assert_that(status.condition_rating).is_in(["Excellent", "Good", "Fair", "Poor", "Critical"])

func test_wcs_compatibility_critical_hit_rates() -> void:
	# Test that critical hit rates are reasonable for WCS gameplay
	var hit_result = critical_hit_detector.analyze_hit_for_critical(
		Vector3.ZERO, 50.0, DamageTypes.Type.KINETIC
	)
	
	# Critical chance should be within reasonable WCS range (5-30%)
	assert_float(hit_result.critical_chance).is_between(0.05, 0.3)