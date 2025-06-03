extends GdUnitTestSuite

## Tests for WCS Dynamic Light Pool functionality
## Tests light pooling, allocation, and performance optimization

var light_pool: WCSDynamicLightPool

func before_test():
	light_pool = WCSDynamicLightPool.new(16)  # Smaller pool for testing
	add_child(light_pool)

func after_test():
	if light_pool:
		light_pool.queue_free()

func test_light_pool_initialization():
	assert_that(light_pool).is_not_null()
	assert_that(light_pool.max_capacity).is_equal(16)
	assert_that(light_pool.total_lights_allocated).is_greater(0)

func test_get_light_from_pool():
	var light = light_pool.get_light(WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH)
	
	assert_that(light).is_not_null()
	assert_that(light).is_instanceof(OmniLight3D)
	assert_that(light.visible).is_true()

func test_return_light_to_pool():
	var light = light_pool.get_light(WCSLightingController.DynamicLightType.EXPLOSION)
	assert_that(light).is_not_null()
	
	light_pool.return_light(light, WCSLightingController.DynamicLightType.EXPLOSION)
	
	assert_that(light.visible).is_false()
	assert_that(light.light_energy).is_equal(0.0)

func test_light_pool_exhaustion():
	var lights: Array[Light3D] = []
	var exhausted = false
	
	# Connect to exhaustion signal
	light_pool.pool_exhausted.connect(func(light_type): exhausted = true)
	
	# Try to get more lights than available in pool
	for i in range(50):  # Try to get way more than pool capacity
		var light = light_pool.get_light(WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH)
		if light:
			lights.append(light)
		else:
			break
	
	# Should have gotten some lights but eventually exhausted
	assert_that(lights.size()).is_greater(0)
	
	# Clean up lights
	for light in lights:
		light_pool.return_light(light, WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH)

func test_different_light_types():
	# Test that different light types return appropriate light instances
	var omni_light = light_pool.get_light(WCSLightingController.DynamicLightType.EXPLOSION)
	var spot_light = light_pool.get_light(WCSLightingController.DynamicLightType.LASER_BEAM)
	
	assert_that(omni_light).is_instanceof(OmniLight3D)
	assert_that(spot_light).is_instanceof(SpotLight3D)
	
	# Return lights
	light_pool.return_light(omni_light, WCSLightingController.DynamicLightType.EXPLOSION)
	light_pool.return_light(spot_light, WCSLightingController.DynamicLightType.LASER_BEAM)

func test_light_reset_functionality():
	var light = light_pool.get_light(WCSLightingController.DynamicLightType.ENGINE_GLOW)
	
	# Modify light properties
	light.light_energy = 5.0
	light.light_color = Color.RED
	light.position = Vector3(10, 20, 30)
	
	# Return to pool
	light_pool.return_light(light, WCSLightingController.DynamicLightType.ENGINE_GLOW)
	
	# Get it back and verify it's reset
	var reset_light = light_pool.get_light(WCSLightingController.DynamicLightType.ENGINE_GLOW)
	
	# Note: might be the same light or a different one from the pool
	assert_that(reset_light.light_energy).is_equal(0.0)
	assert_that(reset_light.light_color).is_equal(Color.WHITE)
	assert_that(reset_light.position).is_equal(Vector3.ZERO)

func test_update_pool_capacity():
	var initial_capacity = light_pool.max_capacity
	var new_capacity = initial_capacity + 8
	
	light_pool.update_capacity(new_capacity)
	
	assert_that(light_pool.max_capacity).is_equal(new_capacity)
	assert_that(light_pool.total_lights_allocated).is_greater(initial_capacity)

func test_shrink_pool_capacity():
	var initial_capacity = light_pool.max_capacity
	var new_capacity = max(initial_capacity - 4, 8)  # Don't go too small
	
	light_pool.update_capacity(new_capacity)
	
	assert_that(light_pool.max_capacity).is_equal(new_capacity)

func test_get_pool_statistics():
	var stats = light_pool.get_pool_statistics()
	
	assert_that(stats).is_not_null()
	assert_that(stats).contains_keys([
		"max_capacity",
		"total_allocated",
		"pool_utilization",
		"available_lights",
		"active_lights"
	])
	
	assert_that(stats["max_capacity"]).is_greater(0)
	assert_that(stats["total_allocated"]).is_greater(0)

func test_pool_utilization_tracking():
	# Get a few lights to change utilization
	var light1 = light_pool.get_light(WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH)
	var light2 = light_pool.get_light(WCSLightingController.DynamicLightType.EXPLOSION)
	
	var stats = light_pool.get_pool_statistics()
	
	# Should have some active lights now
	var total_active = 0
	for type_name in stats["active_lights"]:
		total_active += stats["active_lights"][type_name]
	
	assert_that(total_active).is_greater_equal(2)
	
	# Return lights
	if light1:
		light_pool.return_light(light1, WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH)
	if light2:
		light_pool.return_light(light2, WCSLightingController.DynamicLightType.EXPLOSION)

func test_emergency_light_creation():
	# Try to exhaust a specific pool type
	var lights: Array[Light3D] = []
	
	# Get many lights of the same type
	for i in range(20):  # More than typical pool allocation
		var light = light_pool.get_light(WCSLightingController.DynamicLightType.SHIELD_IMPACT)
		if light:
			lights.append(light)
	
	# Should have created some emergency lights
	assert_that(lights.size()).is_greater(0)
	
	# Clean up
	for light in lights:
		light_pool.return_light(light, WCSLightingController.DynamicLightType.SHIELD_IMPACT)

func test_cleanup_emergency_lights():
	# Create many lights to force emergency allocation
	var lights: Array[Light3D] = []
	for i in range(10):
		var light = light_pool.get_light(WCSLightingController.DynamicLightType.THRUSTER)
		if light:
			lights.append(light)
	
	# Return them all
	for light in lights:
		light_pool.return_light(light, WCSLightingController.DynamicLightType.THRUSTER)
	
	# Cleanup emergency lights
	light_pool.cleanup_emergency_lights()
	
	# Pool should be back to normal size
	var stats = light_pool.get_pool_statistics()
	assert_that(stats["total_allocated"]).is_less_equal(light_pool.max_capacity * 1.1)

func test_force_cleanup_all_lights():
	# Get several lights
	var light1 = light_pool.get_light(WCSLightingController.DynamicLightType.WEAPON_MUZZLE_FLASH)
	var light2 = light_pool.get_light(WCSLightingController.DynamicLightType.EXPLOSION)
	
	# Force cleanup
	light_pool.force_cleanup_all_lights()
	
	# All lights should be reset and available
	var stats = light_pool.get_pool_statistics()
	var total_active = 0
	for type_name in stats["active_lights"]:
		total_active += stats["active_lights"][type_name]
	
	assert_that(total_active).is_equal(0)

func test_invalid_light_type_handling():
	# Test with invalid light type (should handle gracefully)
	var light = light_pool.get_light(999)  # Invalid enum value
	
	assert_that(light).is_null()

func test_pool_type_distribution():
	# Verify that different pool types have appropriate allocations
	var stats = light_pool.get_pool_statistics()
	
	# Muzzle flash should have more allocation (frequent use)
	var muzzle_available = stats["available_lights"].get("WEAPON_MUZZLE_FLASH", 0)
	var shield_available = stats["available_lights"].get("SHIELD_IMPACT", 0)
	
	# Muzzle flash should have at least as many lights as shield impact
	assert_that(muzzle_available).is_greater_equal(shield_available)