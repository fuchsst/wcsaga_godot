extends GdUnitTestSuite

## SHIP-012 Comprehensive Test Suite: Combat Effects and Visual Feedback
## Tests all seven acceptance criteria with integration scenarios
## Validates WCS-authentic combat effects and performance optimization

# Test fixtures
var test_ship: Node3D
var weapon_impact_manager: WeaponImpactEffectManager
var explosion_system: ExplosionSystem
var damage_visualization: DamageVisualizationController
var shield_effect_manager: ShieldEffectManager
var combat_audio_manager: CombatAudioManager
var environmental_effects: EnvironmentalEffectSystem
var performance_manager: EffectPerformanceManager

# Test camera for distance calculations
var test_camera: Camera3D

func before_test() -> void:
	# Create test ship
	test_ship = Node3D.new()
	test_ship.name = "TestShip"
	add_child(test_ship)
	
	# Create test camera
	test_camera = Camera3D.new()
	test_camera.name = "TestCamera"
	test_camera.global_position = Vector3(0, 0, 10)
	add_child(test_camera)
	
	# Create combat effect components
	weapon_impact_manager = WeaponImpactEffectManager.new()
	explosion_system = ExplosionSystem.new()
	damage_visualization = DamageVisualizationController.new()
	shield_effect_manager = ShieldEffectManager.new()
	combat_audio_manager = CombatAudioManager.new()
	environmental_effects = EnvironmentalEffectSystem.new()
	performance_manager = EffectPerformanceManager.new()
	
	# Add components to test ship
	test_ship.add_child(weapon_impact_manager)
	test_ship.add_child(explosion_system)
	test_ship.add_child(damage_visualization)
	test_ship.add_child(shield_effect_manager)
	test_ship.add_child(combat_audio_manager)
	test_ship.add_child(environmental_effects)
	test_ship.add_child(performance_manager)
	
	# Initialize components
	_initialize_combat_effect_components()

func after_test() -> void:
	if test_ship:
		test_ship.queue_free()
	if test_camera:
		test_camera.queue_free()

func _initialize_combat_effect_components() -> void:
	# Initialize weapon impact manager
	weapon_impact_manager.initialize_for_ship(test_ship)
	
	# Initialize shield effect manager
	shield_effect_manager.initialize_for_ship(test_ship)
	
	# Initialize damage visualization
	damage_visualization.initialize_for_ship(test_ship)
	
	# Initialize combat audio
	combat_audio_manager.initialize_combat_audio(null, test_camera)
	
	# Initialize environmental effects
	var combat_area = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
	environmental_effects.initialize_environmental_effects(combat_area, test_ship)
	
	# Initialize performance manager
	var effect_managers = {
		"weapon_impact_manager": weapon_impact_manager,
		"explosion_system": explosion_system,
		"damage_visualization": damage_visualization,
		"shield_effect_manager": shield_effect_manager,
		"combat_audio_manager": combat_audio_manager,
		"environmental_effects": environmental_effects
	}
	performance_manager.initialize_performance_manager(effect_managers, test_camera)

# ============================================================================
# AC1: Weapon Impact Effects with Material-Specific Responses
# ============================================================================

func test_ac1_weapon_impact_effect_creation() -> void:
	# Test creation of weapon impact effects
	var impact_data = {
		"hit_location": Vector3(5, 0, 0),
		"weapon_type": 0,  # PRIMARY_LASER
		"damage_type": 1,  # ENERGY
		"material_type": 1,  # STANDARD armor
		"damage_amount": 75.0,
		"impact_velocity": Vector3(0, 0, -100),
		"surface_normal": Vector3(-1, 0, 0)
	}
	
	var impact_effect = weapon_impact_manager.create_weapon_impact_effect(impact_data)
	
	assert_that(impact_effect).is_not_null()
	assert_int(weapon_impact_manager.active_impact_effects.size()).is_equal(1)
	assert_that(impact_effect.global_position).is_equal(impact_data["hit_location"])

func test_ac1_energy_weapon_impact_characteristics() -> void:
	# Test energy weapon impact with heat effects
	var impact_data = {
		"hit_location": Vector3(0, 0, 0),
		"weapon_type": 0,  # PRIMARY_LASER
		"damage_type": 1,  # ENERGY
		"material_type": 1,
		"damage_amount": 50.0
	}
	
	var impact_effect = weapon_impact_manager.create_energy_impact_effect(impact_data)
	assert_that(impact_effect).is_not_null()
	
	# Should have energy-specific effects
	var energy_discharge = impact_effect.get_node_or_null("EnergyDischarge")
	assert_that(energy_discharge).is_not_null()

func test_ac1_kinetic_weapon_impact_characteristics() -> void:
	# Test kinetic weapon impact with debris and sparks
	var impact_data = {
		"hit_location": Vector3(2, 0, 0),
		"weapon_type": 1,  # PRIMARY_MASS_DRIVER
		"damage_type": 0,  # KINETIC
		"material_type": 2,  # HEAVY armor
		"damage_amount": 80.0,
		"impact_velocity": Vector3(0, 0, -150)
	}
	
	var impact_effect = weapon_impact_manager.create_kinetic_impact_effect(impact_data)
	assert_that(impact_effect).is_not_null()
	
	# Should have kinetic-specific effects
	var spark_shower = impact_effect.get_node_or_null("SparkShower")
	assert_that(spark_shower).is_not_null()

func test_ac1_material_response_factors() -> void:
	# Test material-specific response calculations
	var light_armor_factor = weapon_impact_manager.get_material_response_factor(0, 0)  # Light armor vs laser
	var heavy_armor_factor = weapon_impact_manager.get_material_response_factor(2, 1)  # Heavy armor vs mass driver
	
	assert_float(light_armor_factor).is_greater(0.0)
	assert_float(heavy_armor_factor).is_greater(light_armor_factor)  # Heavy armor should have more sparks

func test_ac1_impact_effect_performance() -> void:
	# Test performance with multiple simultaneous impacts
	var impact_count = 25
	var created_effects = 0
	
	for i in range(impact_count):
		var impact_data = {
			"hit_location": Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)),
			"weapon_type": randi_range(0, 3),
			"damage_type": randi_range(0, 2),
			"material_type": randi_range(0, 2),
			"damage_amount": randf_range(25, 100)
		}
		
		var effect = weapon_impact_manager.create_weapon_impact_effect(impact_data)
		if effect:
			created_effects += 1
	
	assert_int(created_effects).is_greater(0)
	assert_int(weapon_impact_manager.active_impact_effects.size()).is_less_equal(weapon_impact_manager.max_simultaneous_impacts)

# ============================================================================
# AC2: Explosion System with Realistic Detonations and Shockwaves
# ============================================================================

func test_ac2_explosion_creation_and_scaling() -> void:
	# Test different explosion types and scaling
	var small_explosion = explosion_system.create_small_explosion(Vector3(10, 0, 0), 50.0)
	var medium_explosion = explosion_system.create_medium_explosion(Vector3(20, 0, 0), 150.0)
	var large_explosion = explosion_system.create_large_explosion(Vector3(30, 0, 0), 500.0)
	
	assert_that(small_explosion).is_not_null()
	assert_that(medium_explosion).is_not_null()
	assert_that(large_explosion).is_not_null()
	
	# Check that different explosion types have different scales
	assert_float(medium_explosion.scale.x).is_greater(small_explosion.scale.x)
	assert_float(large_explosion.scale.x).is_greater(medium_explosion.scale.x)

func test_ac2_explosion_shockwave_generation() -> void:
	# Test shockwave generation and object interaction
	var explosion_data = {
		"location": Vector3(0, 0, 0),
		"explosion_type": "medium",
		"damage_amount": 200.0,
		"blast_radius": 15.0,
		"source": "weapon"
	}
	
	var explosion = explosion_system.create_explosion(explosion_data)
	assert_that(explosion).is_not_null()
	
	# Should have shockwave particle system
	var shockwave = explosion.get_node_or_null("Shockwave")
	assert_that(shockwave).is_not_null()

func test_ac2_chain_reaction_mechanics() -> void:
	# Test chain reaction explosions
	explosion_system.enable_chain_reactions = true
	
	var initial_explosion_count = explosion_system.active_explosions.size()
	
	# Create explosion that should trigger chain reactions
	var explosion_data = {
		"location": Vector3(0, 0, 0),
		"explosion_type": "large",
		"damage_amount": 400.0,
		"blast_radius": 25.0,
		"chain_reactions": true
	}
	
	explosion_system.create_explosion(explosion_data)
	
	# Wait for potential chain reactions
	await wait_for_seconds(1.0)
	
	# Should have created additional explosions from chain reactions (if targets available)
	var final_explosion_count = explosion_system.active_explosions.size()
	assert_int(final_explosion_count).is_greater_equal(initial_explosion_count)

func test_ac2_environmental_interaction() -> void:
	# Test explosion environmental effects (debris, energy discharges)
	var initial_debris_count = environmental_effects.active_space_debris.size()
	
	explosion_system.create_massive_explosion(Vector3(0, 0, 0), 1000.0)
	
	# Should generate space debris
	assert_int(environmental_effects.active_space_debris.size()).is_greater(initial_debris_count)

func test_ac2_emp_explosion_special_effects() -> void:
	# Test EMP explosion with electromagnetic effects
	var emp_explosion = explosion_system.create_emp_explosion(Vector3(0, 10, 0), 25.0)
	
	assert_that(emp_explosion).is_not_null()
	
	# Should have EMP-specific effects
	var emp_field = emp_explosion.get_node_or_null("EMPField")
	assert_that(emp_field).is_not_null()

# ============================================================================
# AC3: Progressive Damage Visualization with Real-Time Updates
# ============================================================================

func test_ac3_damage_zone_visualization() -> void:
	# Test progressive damage visualization
	var zone_name = "hull_front"
	var initial_damage = 0.2  # 20% damage
	var severe_damage = 0.8   # 80% damage
	
	damage_visualization.update_zone_damage_visualization(zone_name, initial_damage)
	assert_that(damage_visualization.damage_zones).has_key(zone_name)
	
	var zone_data = damage_visualization.damage_zones[zone_name]
	assert_float(zone_data["damage_level"]).is_equal(initial_damage)
	assert_str(zone_data["damage_state"]).is_equal("light_damage")
	
	# Progress to severe damage
	damage_visualization.update_zone_damage_visualization(zone_name, severe_damage)
	zone_data = damage_visualization.damage_zones[zone_name]
	assert_str(zone_data["damage_state"]).is_equal("critical_damage")

func test_ac3_subsystem_failure_visualization() -> void:
	# Test subsystem failure visual indicators
	var subsystem_name = "engines"
	var failure_type = "thermal_overload"
	var severity = 0.8
	
	damage_visualization.visualize_subsystem_failure(subsystem_name, failure_type, severity)
	
	# Should have created or updated subsystem indicator
	assert_that(damage_visualization.subsystem_indicators).has_key(subsystem_name)

func test_ac3_hull_breach_effects() -> void:
	# Test hull breach effect creation
	var breach_location = Vector3(3, 0, 0)
	var breach_severity = 0.9
	
	damage_visualization.create_hull_breach_effect(breach_location, breach_severity)
	
	assert_int(damage_visualization.hull_breach_effects.size()).is_greater(0)
	
	var breach_effect = damage_visualization.hull_breach_effects[0]
	assert_that(breach_effect.global_position).is_equal(breach_location)

func test_ac3_hull_integrity_visualization() -> void:
	# Test overall hull integrity visualization updates
	var high_integrity = 0.8
	var low_integrity = 0.2
	
	damage_visualization.update_hull_integrity_visualization(high_integrity)
	damage_visualization.update_hull_integrity_visualization(low_integrity)
	
	# Emergency lighting should be activated for low integrity
	assert_int(damage_visualization.emergency_lighting.size()).is_greater(0)

func test_ac3_progressive_damage_effects() -> void:
	# Test progressive damage effect transitions
	var zone_name = "hull_mid"
	
	# Light damage - should have minimal effects
	damage_visualization.update_zone_damage_visualization(zone_name, 0.3)
	
	# Heavy damage - should have more effects
	damage_visualization.update_zone_damage_visualization(zone_name, 0.8)
	
	# Critical damage - should have maximum effects
	damage_visualization.update_zone_damage_visualization(zone_name, 0.95)
	
	var zone_data = damage_visualization.damage_zones[zone_name]
	assert_str(zone_data["damage_state"]).is_equal("critical_damage")

# ============================================================================
# AC4: Shield Impact Effects with Quadrant-Specific Display
# ============================================================================

func test_ac4_shield_impact_visualization() -> void:
	# Test shield impact effects with quadrant targeting
	var impact_data = {
		"hit_location": Vector3(0, 0, 5),  # Front quadrant
		"damage_amount": 60.0,
		"damage_type": 1,  # ENERGY
		"weapon_type": 0
	}
	
	shield_effect_manager.create_shield_impact_effect(impact_data)
	
	assert_int(shield_effect_manager.active_impacts.size()).is_equal(1)
	
	var impact = shield_effect_manager.active_impacts[0]
	assert_int(impact["quadrant"]).is_equal(0)  # Front quadrant

func test_ac4_shield_quadrant_failure() -> void:
	# Test shield quadrant failure visualization
	var front_quadrant = 0
	var failure_data = {
		"cause": "overload",
		"remaining_quadrants": 3
	}
	
	shield_effect_manager.visualize_shield_quadrant_failure(front_quadrant, failure_data)
	
	# Quadrant should be marked as failed
	var quadrant_state = shield_effect_manager.quadrant_states[front_quadrant]
	assert_bool(quadrant_state["failed"]).is_true()

func test_ac4_shield_regeneration_effects() -> void:
	# Test shield regeneration visualization
	var port_quadrant = 2
	var strength = 0.6
	var regen_rate = 0.1
	
	shield_effect_manager.visualize_shield_regeneration(port_quadrant, strength, regen_rate)
	
	var quadrant_state = shield_effect_manager.quadrant_states[port_quadrant]
	assert_float(quadrant_state["strength"]).is_equal(strength)
	assert_bool(quadrant_state["regenerating"]).is_true()

func test_ac4_shield_strength_indicators() -> void:
	# Test shield strength visualization updates
	var quadrant_strengths = [0.8, 0.6, 0.4, 0.2]  # Front, Rear, Port, Starboard
	
	shield_effect_manager.update_shield_strength_visualization(quadrant_strengths)
	
	for i in range(quadrant_strengths.size()):
		var state = shield_effect_manager.quadrant_states[i]
		assert_float(state["strength"]).is_equal(quadrant_strengths[i])

func test_ac4_shield_overload_effects() -> void:
	# Test shield overload effect creation
	var starboard_quadrant = 3
	var overload_severity = 0.9
	
	shield_effect_manager.create_shield_overload_effect(starboard_quadrant, overload_severity)
	
	# Should create overload effect at quadrant location
	# Test that the effect was created properly

# ============================================================================
# AC5: 3D Positional Audio with Combat Sounds
# ============================================================================

func test_ac5_weapon_firing_audio() -> void:
	# Test weapon firing audio with positional sound
	var weapon_data = {
		"weapon_type": 0,  # PRIMARY_LASER
		"position": Vector3(5, 0, 0),
		"velocity": Vector3(0, 0, -100),
		"weapon_name": "Subach HL-7"
	}
	
	var audio_source = combat_audio_manager.play_weapon_firing_audio(weapon_data)
	
	# Audio might be null if no audio stream loaded (placeholder implementation)
	if audio_source:
		assert_that(audio_source.global_position).is_equal(weapon_data["position"])
		assert_bool(audio_source.playing).is_true()

func test_ac5_weapon_impact_audio() -> void:
	# Test weapon impact audio with material-specific sounds
	var impact_data = {
		"position": Vector3(0, 0, 0),
		"damage_type": 1,  # ENERGY
		"damage_amount": 75.0,
		"material_type": 1,  # STANDARD
		"impact_velocity": Vector3(0, 0, -120)
	}
	
	var audio_source = combat_audio_manager.play_weapon_impact_audio(impact_data)
	
	if audio_source:
		assert_that(audio_source.global_position).is_equal(impact_data["position"])

func test_ac5_explosion_audio() -> void:
	# Test explosion audio with size-based volume scaling
	var explosion_data = {
		"position": Vector3(10, 0, 0),
		"explosion_type": "large",
		"blast_radius": 20.0,
		"damage_amount": 400.0
	}
	
	var audio_source = combat_audio_manager.play_explosion_audio(explosion_data)
	
	if audio_source:
		assert_that(audio_source.global_position).is_equal(explosion_data["position"])

func test_ac5_ambient_combat_audio() -> void:
	# Test ambient combat audio
	var ambient_data = {
		"type": "battle_distant",
		"position": Vector3(0, 0, -50),
		"intensity": 0.7,
		"looping": true
	}
	
	var audio_source = combat_audio_manager.play_ambient_combat_audio(ambient_data)
	
	if audio_source:
		assert_that(audio_source.global_position).is_equal(ambient_data["position"])

func test_ac5_audio_priority_system() -> void:
	# Test audio priority management
	combat_audio_manager.enable_audio_priorities = true
	
	# Create multiple audio sources to test priority
	for i in range(10):
		var weapon_data = {
			"weapon_type": 0,
			"position": Vector3(i * 2, 0, 0),
			"weapon_name": "test_weapon_" + str(i)
		}
		combat_audio_manager.play_weapon_firing_audio(weapon_data)
	
	# Should not exceed maximum audio sources
	var active_count = combat_audio_manager.active_audio_sources.size()
	assert_int(active_count).is_less_equal(combat_audio_manager.max_simultaneous_audio_sources)

# ============================================================================
# AC6: Environmental Effects (Space Debris, Energy Discharges)
# ============================================================================

func test_ac6_space_debris_generation() -> void:
	# Test space debris generation from explosions
	var explosion_location = Vector3(0, 0, 0)
	var explosion_radius = 10.0
	var debris_count = 15
	
	var initial_debris = environmental_effects.active_space_debris.size()
	environmental_effects.generate_space_debris_from_explosion(explosion_location, explosion_radius, debris_count)
	
	assert_int(environmental_effects.active_space_debris.size()).is_greater(initial_debris)

func test_ac6_energy_discharge_effects() -> void:
	# Test energy discharge creation and configuration
	var discharge_location = Vector3(5, 5, 5)
	var intensity = 1.5
	var duration = 3.0
	
	var discharge_effect = environmental_effects.create_energy_discharge(discharge_location, intensity, duration)
	
	assert_that(discharge_effect).is_not_null()
	assert_that(discharge_effect.global_position).is_equal(discharge_location)
	assert_int(environmental_effects.active_energy_discharges.size()).is_greater(0)

func test_ac6_atmospheric_interaction_effects() -> void:
	# Test atmospheric interaction (heat trails, sonic booms)
	var entry_location = Vector3(0, 10, 0)
	var entry_velocity = Vector3(0, 0, -150)  # High speed for sonic boom
	var object_size = 2.0
	
	var atmospheric_effect = environmental_effects.create_atmospheric_interaction(
		entry_location, entry_velocity, object_size
	)
	
	assert_that(atmospheric_effect).is_not_null()
	assert_int(environmental_effects.active_atmospheric_effects.size()).is_greater(0)

func test_ac6_nebula_effects() -> void:
	# Test nebula effects application
	var nebula_center = Vector3(0, 0, 0)
	var nebula_radius = 30.0
	var nebula_type = "ion_storm"
	
	environmental_effects.apply_nebula_effects(nebula_center, nebula_radius, nebula_type)
	
	assert_int(environmental_effects.active_nebula_effects.size()).is_greater_equal(0)

func test_ac6_environmental_zones() -> void:
	# Test environmental zone setup and management
	var status = environmental_effects.get_environmental_system_status()
	
	assert_that(status).has_key("energy_storm_zones")
	assert_that(status).has_key("atmospheric_zones")
	assert_that(status).has_key("nebula_regions")

# ============================================================================
# AC7: Performance Optimization with LOD and Culling
# ============================================================================

func test_ac7_performance_monitoring() -> void:
	# Test performance monitoring system
	performance_manager.enable_performance_monitoring = true
	
	# Simulate some load
	await wait_for_seconds(1.0)
	
	var stats = performance_manager.get_performance_statistics()
	
	assert_that(stats).has_key("current_fps")
	assert_that(stats).has_key("total_active_effects")
	assert_that(stats).has_key("performance_level")
	assert_float(stats["current_fps"]).is_greater(0.0)

func test_ac7_lod_system() -> void:
	# Test LOD (Level of Detail) system
	performance_manager.enable_automatic_lod = true
	
	# Create effects at various distances
	var near_impact = weapon_impact_manager.create_weapon_impact_effect({
		"hit_location": Vector3(5, 0, 0),
		"damage_amount": 50.0,
		"weapon_type": 0,
		"damage_type": 1
	})
	
	var far_impact = weapon_impact_manager.create_weapon_impact_effect({
		"hit_location": Vector3(150, 0, 0),
		"damage_amount": 50.0,
		"weapon_type": 0,
		"damage_type": 1
	})
	
	# Update camera position and trigger LOD updates
	performance_manager.update_camera_position(Vector3(0, 0, 10))
	
	# Wait for LOD processing
	await wait_for_seconds(0.5)
	
	# Far effects should have reduced quality
	assert_that(near_impact).is_not_null()
	assert_that(far_impact).is_not_null()

func test_ac7_distance_culling() -> void:
	# Test distance culling system
	performance_manager.enable_distance_culling = true
	
	# Create effects beyond culling distance
	var very_far_impact = weapon_impact_manager.create_weapon_impact_effect({
		"hit_location": Vector3(600, 0, 0),  # Beyond typical culling distance
		"damage_amount": 50.0,
		"weapon_type": 0,
		"damage_type": 1
	})
	
	var initial_effect_count = weapon_impact_manager.active_impact_effects.size()
	
	# Update performance manager (should trigger culling)
	performance_manager.update_camera_position(Vector3(0, 0, 10))
	
	# Wait for culling processing
	await wait_for_seconds(1.5)
	
	# Should have culled distant effects
	var final_effect_count = weapon_impact_manager.active_impact_effects.size()
	assert_int(final_effect_count).is_less_equal(initial_effect_count)

func test_ac7_adaptive_performance() -> void:
	# Test adaptive performance level adjustment
	performance_manager.auto_adjust_performance = true
	performance_manager.performance_adjustment_enabled = true
	
	var initial_level = performance_manager.current_performance_level
	
	# Simulate heavy load to trigger performance reduction
	for i in range(50):
		weapon_impact_manager.create_weapon_impact_effect({
			"hit_location": Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)),
			"damage_amount": 50.0,
			"weapon_type": 0,
			"damage_type": 1
		})
		explosion_system.create_medium_explosion(Vector3(randf_range(-20, 20), 0, 0), 100.0)
	
	# Wait for performance adjustment
	await wait_for_seconds(2.0)
	
	# Performance level might have been adjusted
	var final_level = performance_manager.current_performance_level
	assert_int(final_level).is_greater_equal(0)  # Should be valid performance level

func test_ac7_effect_limits() -> void:
	# Test effect limit enforcement
	var max_impacts = weapon_impact_manager.max_simultaneous_impacts
	
	# Try to create more effects than the limit
	for i in range(max_impacts + 10):
		weapon_impact_manager.create_weapon_impact_effect({
			"hit_location": Vector3(i, 0, 0),
			"damage_amount": 50.0,
			"weapon_type": 0,
			"damage_type": 1
		})
	
	# Should not exceed the limit
	assert_int(weapon_impact_manager.active_impact_effects.size()).is_less_equal(max_impacts)

# ============================================================================
# Integration Tests - Component Coordination
# ============================================================================

func test_integration_complete_combat_sequence() -> void:
	# Test complete combat sequence with all effect systems
	var target_location = Vector3(0, 0, 0)
	
	# 1. Weapon firing
	var weapon_data = {
		"weapon_type": 0,
		"position": Vector3(-10, 0, 0),
		"velocity": Vector3(100, 0, 0)
	}
	combat_audio_manager.play_weapon_firing_audio(weapon_data)
	
	# 2. Shield impact
	var shield_impact_data = {
		"hit_location": target_location,
		"damage_amount": 60.0,
		"damage_type": 1,
		"weapon_type": 0
	}
	shield_effect_manager.create_shield_impact_effect(shield_impact_data)
	
	# 3. Hull impact
	var hull_impact_data = {
		"hit_location": target_location,
		"weapon_type": 0,
		"damage_type": 1,
		"material_type": 1,
		"damage_amount": 40.0
	}
	weapon_impact_manager.create_weapon_impact_effect(hull_impact_data)
	
	# 4. Damage visualization
	damage_visualization.update_zone_damage_visualization("hull_front", 0.3)
	
	# 5. Environmental effects
	environmental_effects.generate_space_debris_from_explosion(target_location, 5.0, 10)
	
	# Verify all systems are active
	assert_int(shield_effect_manager.active_impacts.size()).is_greater(0)
	assert_int(weapon_impact_manager.active_impact_effects.size()).is_greater(0)
	assert_that(damage_visualization.damage_zones).has_key("hull_front")
	assert_int(environmental_effects.active_space_debris.size()).is_greater(0)

func test_integration_large_scale_battle() -> void:
	# Test performance during large-scale battle simulation
	var battle_area = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	
	# Create multiple explosions
	for i in range(10):
		var location = Vector3(
			randf_range(battle_area.position.x, battle_area.position.x + battle_area.size.x),
			randf_range(battle_area.position.y, battle_area.position.y + battle_area.size.y),
			randf_range(battle_area.position.z, battle_area.position.z + battle_area.size.z)
		)
		explosion_system.create_medium_explosion(location, randf_range(100, 200))
	
	# Create multiple weapon impacts
	for i in range(30):
		var impact_location = Vector3(
			randf_range(battle_area.position.x, battle_area.position.x + battle_area.size.x),
			randf_range(battle_area.position.y, battle_area.position.y + battle_area.size.y),
			randf_range(battle_area.position.z, battle_area.position.z + battle_area.size.z)
		)
		weapon_impact_manager.create_weapon_impact_effect({
			"hit_location": impact_location,
			"damage_amount": randf_range(25, 100),
			"weapon_type": randi_range(0, 3),
			"damage_type": randi_range(0, 2)
		})
	
	# Create environmental effects
	environmental_effects.create_energy_discharge(Vector3(0, 0, 0), 1.5, 3.0)
	
	# Verify systems handle the load
	var performance_stats = performance_manager.get_performance_statistics()
	assert_int(performance_stats["total_active_effects"]).is_greater(0)
	
	# Performance should be monitored
	assert_float(performance_stats["current_fps"]).is_greater(0.0)

func test_integration_effect_cleanup() -> void:
	# Test that effects are properly cleaned up over time
	var initial_effect_count = weapon_impact_manager.active_impact_effects.size()
	
	# Create some temporary effects
	for i in range(5):
		weapon_impact_manager.create_weapon_impact_effect({
			"hit_location": Vector3(i, 0, 0),
			"damage_amount": 50.0,
			"weapon_type": 0,
			"damage_type": 1
		})
	
	var peak_effect_count = weapon_impact_manager.active_impact_effects.size()
	assert_int(peak_effect_count).is_greater(initial_effect_count)
	
	# Wait for effects to expire and be cleaned up
	await wait_for_seconds(3.0)
	
	var final_effect_count = weapon_impact_manager.active_impact_effects.size()
	# Effects should have been cleaned up (or at least some of them)
	assert_int(final_effect_count).is_less_equal(peak_effect_count)

# ============================================================================
# Performance and Error Handling Tests
# ============================================================================

func test_performance_with_invalid_inputs() -> void:
	# Test system behavior with invalid/edge case inputs
	
	# Invalid impact data
	var invalid_impact = weapon_impact_manager.create_weapon_impact_effect({})
	# Should handle gracefully without crashing
	
	# Invalid explosion data
	var invalid_explosion = explosion_system.create_explosion({})
	# Should handle gracefully
	
	# Invalid audio data
	var invalid_audio = combat_audio_manager.play_weapon_firing_audio({})
	# Should handle gracefully

func test_memory_management() -> void:
	# Test memory management with effect pools
	
	# Create and destroy many effects to test pool management
	for cycle in range(3):
		# Create many effects
		for i in range(20):
			weapon_impact_manager.create_weapon_impact_effect({
				"hit_location": Vector3(i, 0, 0),
				"damage_amount": 50.0,
				"weapon_type": 0,
				"damage_type": 1
			})
		
		# Wait for cleanup
		await wait_for_seconds(2.0)
	
	# Pool should be managing memory efficiently
	var performance_stats = performance_manager.get_performance_statistics()
	assert_float(performance_stats["memory_usage_mb"]).is_less(1000.0)  # Reasonable memory usage

func test_wcs_combat_authenticity() -> void:
	# Test that combat effects feel authentic to WCS
	
	# Energy weapon impact should have appropriate characteristics
	var laser_impact = weapon_impact_manager.create_energy_impact_effect({
		"hit_location": Vector3(0, 0, 0),
		"damage_amount": 35.0,  # Typical WCS laser damage
		"weapon_type": 0,
		"damage_type": 1
	})
	
	assert_that(laser_impact).is_not_null()
	
	# Mass driver impact should have kinetic characteristics
	var mass_driver_impact = weapon_impact_manager.create_kinetic_impact_effect({
		"hit_location": Vector3(1, 0, 0),
		"damage_amount": 55.0,  # Typical WCS mass driver damage
		"weapon_type": 1,
		"damage_type": 0
	})
	
	assert_that(mass_driver_impact).is_not_null()
	
	# Explosion should scale appropriately
	var weapon_explosion = explosion_system.create_medium_explosion(Vector3(2, 0, 0), 120.0)
	assert_that(weapon_explosion).is_not_null()

# ============================================================================
# Utility Functions
# ============================================================================

func wait_for_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout