extends GdUnitTestSuite

## Tests for WCS Lighting Controller functionality
## Tests lighting profiles, dynamic light creation, and space environment setup

var lighting_controller: WCSLightingController

func before_test():
	lighting_controller = WCSLightingController.new()
	add_child(lighting_controller)

func after_test():
	if lighting_controller:
		lighting_controller.queue_free()

func test_lighting_controller_initialization():
	assert_that(lighting_controller).is_not_null()
	assert_that(lighting_controller.main_star_light).is_not_null()
	assert_that(lighting_controller.ambient_environment).is_not_null()
	assert_that(lighting_controller.dynamic_light_pool).is_not_null()

func test_lighting_profiles_exist():
	# Check that all expected lighting profiles are configured
	assert_that(lighting_controller.lighting_profiles).contains_keys([
		WCSLightingController.LightingProfile.DEEP_SPACE,
		WCSLightingController.LightingProfile.NEBULA,
		WCSLightingController.LightingProfile.PLANET_PROXIMITY,
		WCSLightingController.LightingProfile.ASTEROID_FIELD
	])

func test_apply_lighting_profile():
	# Test applying deep space profile
	lighting_controller.apply_lighting_profile(WCSLightingController.LightingProfile.DEEP_SPACE)
	
	var star_light = lighting_controller.main_star_light
	assert_that(star_light.light_color).is_equal(Color(1.0, 0.95, 0.8))
	assert_that(star_light.light_energy).is_equal(1.2)
	assert_that(star_light.shadow_enabled).is_true()

func test_apply_nebula_profile():
	# Test applying nebula profile
	lighting_controller.apply_lighting_profile(WCSLightingController.LightingProfile.NEBULA)
	
	var environment = lighting_controller.ambient_environment
	assert_that(environment.ambient_light_color).is_equal(Color(0.3, 0.1, 0.4))
	assert_that(environment.ambient_light_energy).is_equal(0.35)
	assert_that(environment.fog_enabled).is_true()

func test_create_weapon_muzzle_flash():
	var position = Vector3(10, 5, 0)
	var color = Color.RED
	var intensity = 3.0
	
	var light_id = lighting_controller.create_weapon_muzzle_flash(position, color, intensity)
	
	assert_that(light_id).is_not_empty()
	assert_that(lighting_controller.active_dynamic_lights).contains_key(light_id)
	
	var light_data = lighting_controller.active_dynamic_lights[light_id]
	assert_that(light_data["type"]).is_equal(WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH)

func test_create_explosion_light():
	var position = Vector3(0, 0, 0)
	
	var light_id = lighting_controller.create_explosion_light(position, "large", 2.0, 3.0)
	
	assert_that(light_id).is_not_empty()
	assert_that(lighting_controller.active_dynamic_lights).contains_key(light_id)
	
	var light_data = lighting_controller.active_dynamic_lights[light_id]
	assert_that(light_data["type"]).is_equal(WCSLightingController.DynamicLightType.EXPLOSION)

func test_create_engine_glow_lights():
	var ship_node = Node3D.new()
	add_child(ship_node)
	
	var engine_positions = [Vector3(0, 0, -2), Vector3(1, 0, -2)]
	var color = Color.CYAN
	
	var light_ids = lighting_controller.create_engine_glow_lights(ship_node, engine_positions, color)
	
	assert_that(light_ids.size()).is_equal(2)
	for light_id in light_ids:
		assert_that(light_id).is_not_empty()
		assert_that(lighting_controller.active_dynamic_lights).contains_key(light_id)
	
	ship_node.queue_free()

func test_destroy_dynamic_light():
	var position = Vector3(5, 5, 5)
	var light_id = lighting_controller.create_weapon_muzzle_flash(position)
	
	assert_that(lighting_controller.active_dynamic_lights).contains_key(light_id)
	
	lighting_controller.destroy_dynamic_light(light_id)
	
	assert_that(lighting_controller.active_dynamic_lights).not_contains_key(light_id)

func test_set_lighting_quality():
	# Test low quality
	lighting_controller.set_lighting_quality(1)
	assert_that(lighting_controller.quality_level).is_equal(1)
	assert_that(lighting_controller.max_dynamic_lights).is_equal(16)
	assert_that(lighting_controller.main_star_light.shadow_enabled).is_false()
	
	# Test high quality
	lighting_controller.set_lighting_quality(3)
	assert_that(lighting_controller.quality_level).is_equal(3)
	assert_that(lighting_controller.max_dynamic_lights).is_equal(32)
	assert_that(lighting_controller.main_star_light.shadow_enabled).is_true()

func test_get_lighting_statistics():
	var stats = lighting_controller.get_lighting_statistics()
	
	assert_that(stats).is_not_null()
	assert_that(stats).contains_keys([
		"current_profile",
		"active_dynamic_lights", 
		"max_dynamic_lights",
		"quality_level",
		"ambient_intensity",
		"star_intensity",
		"shadows_enabled"
	])

func test_light_pool_integration():
	# Test that light pool is properly integrated
	var pool = lighting_controller.dynamic_light_pool
	assert_that(pool).is_not_null()
	
	var pool_stats = pool.get_pool_statistics()
	assert_that(pool_stats).contains_key("max_capacity")
	assert_that(pool_stats["max_capacity"]).is_greater(0)

func test_lighting_signals():
	var signal_received = false
	var received_profile = ""
	
	lighting_controller.lighting_profile_changed.connect(func(profile_name: String):
		signal_received = true
		received_profile = profile_name
	)
	
	lighting_controller.apply_lighting_profile(WCSLightingController.LightingProfile.NEBULA)
	
	# Give signal time to propagate
	await get_tree().process_frame
	
	assert_that(signal_received).is_true()
	assert_that(received_profile).is_equal("Nebula Environment")

func test_dynamic_light_automatic_cleanup():
	# Create a light with short lifetime
	var position = Vector3(0, 0, 0)
	var properties = {
		"color": Color.RED,
		"intensity": 2.0,
		"range": 30.0,
		"lifetime": 0.1,  # Very short lifetime
		"priority": 5
	}
	
	var light_id = lighting_controller.create_dynamic_light(
		WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH,
		position,
		properties
	)
	
	assert_that(light_id).is_not_empty()
	assert_that(lighting_controller.active_dynamic_lights).contains_key(light_id)
	
	# Wait for automatic cleanup
	await get_tree().create_timer(0.2).timeout
	
	assert_that(lighting_controller.active_dynamic_lights).not_contains_key(light_id)

func test_profile_performance_characteristics():
	# Test that different profiles have appropriate performance characteristics
	
	# Deep space should allow more lights
	lighting_controller.apply_lighting_profile(WCSLightingController.LightingProfile.DEEP_SPACE)
	var deep_space_max = lighting_controller.max_dynamic_lights
	
	# Asteroid field should reduce lights for performance
	lighting_controller.apply_lighting_profile(WCSLightingController.LightingProfile.ASTEROID_FIELD)
	var asteroid_max = lighting_controller.max_dynamic_lights
	
	# Performance considerations should be reflected
	# (This test may need adjustment based on actual implementation)
	assert_that(asteroid_max).is_less_equal(deep_space_max)

func test_environment_configuration():
	var environment = lighting_controller.get_environment()
	
	assert_that(environment).is_not_null()
	assert_that(environment.background_mode).is_equal(Environment.BG_COLOR)
	assert_that(environment.background_color).is_equal(Color.BLACK)
	assert_that(environment.ambient_light_source).is_equal(Environment.AMBIENT_SOURCE_COLOR)

func test_light_id_generation():
	# Test that light IDs are unique
	var position = Vector3(0, 0, 0)
	var light_id1 = lighting_controller.create_weapon_muzzle_flash(position)
	var light_id2 = lighting_controller.create_weapon_muzzle_flash(position)
	
	assert_that(light_id1).is_not_equal(light_id2)
	assert_that(light_id1).is_not_empty()
	assert_that(light_id2).is_not_empty()
	
	# Clean up
	lighting_controller.destroy_dynamic_light(light_id1)
	lighting_controller.destroy_dynamic_light(light_id2)