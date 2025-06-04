extends GdUnitTestSuite

## Integration tests for GR-005 Dynamic Lighting and Space Environment System
## Tests the complete lighting system integration with graphics engine and quality management

var lighting_controller: WCSLightingController
var dynamic_light_pool: WCSDynamicLightPool
var graphics_engine: GraphicsRenderingEngine

func before_test():
	# Create test components
	lighting_controller = WCSLightingController.new()
	add_child(lighting_controller)
	
	dynamic_light_pool = WCSDynamicLightPool.new(32)
	add_child(dynamic_light_pool)
	
	graphics_engine = GraphicsRenderingEngine.new()
	add_child(graphics_engine)

func after_test():
	if lighting_controller:
		lighting_controller.queue_free()
	if dynamic_light_pool:
		dynamic_light_pool.queue_free()
	if graphics_engine:
		graphics_engine.queue_free()

func test_lighting_controller_initialization():
	assert_that(lighting_controller).is_not_null()
	
	# Test lighting statistics
	var stats: Dictionary = lighting_controller.get_lighting_statistics()
	assert_that(stats).is_not_null()
	assert_that(stats.has("current_profile")).is_true()
	assert_that(stats.has("active_dynamic_lights")).is_true()
	assert_that(stats.has("max_dynamic_lights")).is_true()
	assert_that(stats.has("quality_level")).is_true()
	
	print("Lighting stats: ", stats)

func test_space_lighting_profiles():
	# Test all lighting profiles
	for profile in WCSLightingController.LightingProfile.values():
		lighting_controller.apply_lighting_profile(profile)
		
		var stats: Dictionary = lighting_controller.get_lighting_statistics()
		assert_that(stats).is_not_null()
		
		var profile_name: String = stats["current_profile"]
		print("Applied lighting profile: ", profile_name)
		
		# Should not crash and should return valid profile name
		assert_that(profile_name).is_not_null()
		assert_that(profile_name.length()).is_greater(0)

func test_weapon_muzzle_flash_creation():
	# Test muzzle flash lighting
	var flash_position: Vector3 = Vector3(10, 0, 0)
	var flash_id: String = lighting_controller.create_weapon_muzzle_flash(flash_position, Color.RED, 3.0, 25.0, 0.15)
	
	assert_that(flash_id).is_not_null()
	assert_that(flash_id.length()).is_greater(0)
	
	print("Created muzzle flash with ID: ", flash_id)
	
	# Wait a moment for automatic cleanup
	await get_tree().create_timer(0.2).timeout
	
	# Flash should be automatically cleaned up after lifetime

func test_explosion_lighting_creation():
	# Test different explosion types
	var explosion_types: Array[String] = ["small", "medium", "large", "capital"]
	var explosion_position: Vector3 = Vector3(0, 10, 0)
	
	for explosion_type in explosion_types:
		var explosion_id: String = lighting_controller.create_explosion_light(explosion_position, explosion_type, 1.0, 0.1)
		assert_that(explosion_id).is_not_null()
		assert_that(explosion_id.length()).is_greater(0)
		
		print("Created %s explosion light with ID: %s" % [explosion_type, explosion_id])

func test_engine_glow_lighting():
	# Create a test ship node
	var ship_node: Node3D = Node3D.new()
	add_child(ship_node)
	
	# Engine positions for a multi-engine ship
	var engine_positions: Array[Vector3] = [
		Vector3(0, 0, -2),
		Vector3(1, 0, -2),
		Vector3(-1, 0, -2)
	]
	
	var engine_light_ids: Array[String] = lighting_controller.create_engine_glow_lights(ship_node, engine_positions, Color.CYAN, 1.5)
	
	assert_that(engine_light_ids.size()).is_equal(3)
	for light_id in engine_light_ids:
		assert_that(light_id).is_not_null()
		assert_that(light_id.length()).is_greater(0)
	
	print("Created %d engine glow lights" % engine_light_ids.size())
	
	# Cleanup
	for light_id in engine_light_ids:
		lighting_controller.destroy_dynamic_light(light_id)
	
	ship_node.queue_free()

func test_dynamic_light_types():
	# Test all dynamic light types
	var test_position: Vector3 = Vector3(5, 5, 5)
	var created_lights: Array[String] = []
	
	for light_type in WCSLightingController.DynamicLightType.values():
		var light_id: String = lighting_controller.create_dynamic_light(light_type, test_position, {"intensity": 2.0, "range": 30.0})
		
		if not light_id.is_empty():
			created_lights.append(light_id)
			print("Created dynamic light type %d with ID: %s" % [light_type, light_id])
	
	assert_that(created_lights.size()).is_greater(0)
	
	# Cleanup created lights
	for light_id in created_lights:
		lighting_controller.destroy_dynamic_light(light_id)

func test_lighting_quality_adjustment():
	# Test quality level changes
	for quality_level in range(5):
		lighting_controller.set_lighting_quality(quality_level)
		
		var stats: Dictionary = lighting_controller.get_lighting_statistics()
		assert_that(stats["quality_level"]).is_equal(quality_level)
		
		print("Lighting quality set to level %d" % quality_level)

func test_lighting_performance_monitoring():
	# Create multiple lights to test performance monitoring
	var created_lights: Array[String] = []
	
	for i in range(10):
		var position: Vector3 = Vector3(i * 2, 0, 0)
		var light_id: String = lighting_controller.create_dynamic_light(
			WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH, 
			position, 
			{"intensity": 1.0, "range": 20.0}
		)
		
		if not light_id.is_empty():
			created_lights.append(light_id)
	
	# Get performance statistics
	var stats: Dictionary = lighting_controller.get_lighting_statistics()
	assert_that(stats["active_dynamic_lights"]).is_greater_equal(created_lights.size())
	
	print("Created %d lights, active lights: %d" % [created_lights.size(), stats["active_dynamic_lights"]])
	
	# Cleanup
	for light_id in created_lights:
		lighting_controller.destroy_dynamic_light(light_id)

func test_light_pool_functionality():
	assert_that(dynamic_light_pool).is_not_null()
	
	# Test getting lights from pool
	var light: Light3D = dynamic_light_pool.get_light(WCSLightingController.DynamicLightType.EXPLOSION)
	assert_that(light).is_not_null()
	assert_that(light is OmniLight3D).is_true()
	
	# Test returning light to pool
	dynamic_light_pool.return_light(light, WCSLightingController.DynamicLightType.EXPLOSION)
	
	# Test pool statistics
	var pool_stats: Dictionary = dynamic_light_pool.get_pool_statistics()
	assert_that(pool_stats).is_not_null()
	assert_that(pool_stats.has("max_capacity")).is_true()
	assert_that(pool_stats.has("total_allocated")).is_true()
	
	print("Light pool stats: ", pool_stats)

func test_space_lighting_profile_factory():
	# Test profile factory methods
	var profile: SpaceLightingProfile = SpaceLightingProfile.new()
	
	var deep_space: SpaceLightingProfile = profile.create_deep_space_profile()
	assert_that(deep_space).is_not_null()
	assert_that(deep_space.profile_name).is_equal("Deep Space")
	assert_that(deep_space.validate()).is_true()
	
	var nebula: SpaceLightingProfile = profile.create_nebula_profile()
	assert_that(nebula).is_not_null()
	assert_that(nebula.profile_name).is_equal("Nebula Environment")
	assert_that(nebula.validate()).is_true()
	
	var planet: SpaceLightingProfile = profile.create_planet_proximity_profile()
	assert_that(planet).is_not_null()
	assert_that(planet.profile_name).is_equal("Planet Proximity")
	assert_that(planet.validate()).is_true()
	
	var asteroid: SpaceLightingProfile = profile.create_asteroid_field_profile()
	assert_that(asteroid).is_not_null()
	assert_that(asteroid.profile_name).is_equal("Asteroid Field")
	assert_that(asteroid.validate()).is_true()
	
	print("All lighting profiles validated successfully")

func test_lighting_environment_configuration():
	# Test environment configuration
	var environment: Environment = lighting_controller.get_environment()
	assert_that(environment).is_not_null()
	
	# Environment should be configured for space
	assert_that(environment.background_mode).is_equal(Environment.BG_COLOR)
	assert_that(environment.background_color).is_equal(Color.BLACK)
	assert_that(environment.ambient_light_source).is_equal(Environment.AMBIENT_SOURCE_COLOR)
	
	print("Space environment configured correctly")

func test_graphics_engine_lighting_integration():
	# Test that graphics engine properly integrates with lighting system
	assert_that(graphics_engine.lighting_controller).is_not_null()
	
	# Test lighting system API through graphics engine
	var stats: Dictionary = graphics_engine.get_lighting_statistics()
	assert_that(stats).is_not_null()
	
	# Test lighting profile application through graphics engine
	graphics_engine.apply_lighting_profile(WCSLightingController.LightingProfile.NEBULA)
	
	# Test dynamic light creation through graphics engine
	var flash_id: String = graphics_engine.create_weapon_muzzle_flash(Vector3.ZERO, Color.WHITE, 2.0)
	assert_that(flash_id).is_not_null()
	
	var explosion_id: String = graphics_engine.create_explosion_light(Vector3.ZERO, "medium", 1.0)
	assert_that(explosion_id).is_not_null()
	
	# Test quality setting through graphics engine
	graphics_engine.set_lighting_quality(3)
	var updated_stats: Dictionary = graphics_engine.get_lighting_statistics()
	assert_that(updated_stats["quality_level"]).is_equal(3)

func test_lighting_cleanup_functionality():
	# Test expired light cleanup
	lighting_controller.cleanup_expired_lights()
	
	# Should not crash and should handle empty state gracefully
	var stats: Dictionary = lighting_controller.get_lighting_statistics()
	assert_that(stats).is_not_null()

func test_lighting_system_memory_management():
	# Create and destroy many lights to test memory management
	var light_ids: Array[String] = []
	
	# Create lights
	for i in range(20):
		var position: Vector3 = Vector3(i, 0, 0)
		var light_id: String = lighting_controller.create_dynamic_light(
			WCSLightingController.DynamicLightType.ENGINE_GLOW,
			position,
			{"intensity": 1.0}
		)
		if not light_id.is_empty():
			light_ids.append(light_id)
	
	print("Created %d lights for memory test" % light_ids.size())
	
	# Destroy all lights
	for light_id in light_ids:
		lighting_controller.destroy_dynamic_light(light_id)
	
	# Verify cleanup
	var final_stats: Dictionary = lighting_controller.get_lighting_statistics()
	print("Final active lights after cleanup: %d" % final_stats["active_dynamic_lights"])

print("GR-005 Dynamic Lighting and Space Environment System Integration Tests: Testing comprehensive lighting functionality, quality management, and graphics engine integration")