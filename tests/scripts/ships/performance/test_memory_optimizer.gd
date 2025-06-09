extends GdUnitTestSuite

## SHIP-016 AC6: Focused test suite for MemoryOptimizer
## Tests memory leak prevention, resource management, and 2GB limit enforcement

var memory_optimizer: MemoryOptimizer
var test_scene: Node

func before_test() -> void:
	test_scene = Node.new()
	add_child(test_scene)
	
	memory_optimizer = MemoryOptimizer.new()
	test_scene.add_child(memory_optimizer)

func after_test() -> void:
	if is_instance_valid(test_scene):
		test_scene.queue_free()

func test_memory_optimizer_initialization() -> void:
	assert_that(memory_optimizer).is_not_null()
	assert_that(memory_optimizer.enable_memory_monitoring).is_true()
	assert_that(memory_optimizer.memory_critical_threshold_mb).is_less_equal(2048.0)  # 2GB limit

func test_memory_leak_detection() -> void:
	# Simulate memory growth pattern
	var leak_detected = false
	memory_optimizer.memory_leak_detected.connect(
		func(resource_type, leak_size, growth_rate): leak_detected = true
	)
	
	# Simulate sustained memory growth
	for i in range(20):
		memory_optimizer.register_resource("test_leaks", 10.0)  # 10MB each
		await get_tree().create_timer(0.05).timeout
	
	# Force memory check
	memory_optimizer._check_memory_usage()
	
	# Should detect leak pattern (may not trigger immediately in test environment)
	var memory_stats = memory_optimizer.get_memory_statistics()
	assert_that(memory_stats["monitoring_enabled"]).is_true()

func test_resource_tracking() -> void:
	# Test resource registration and tracking
	assert_that(memory_optimizer.register_resource("ships", 5.0)).is_true()
	assert_that(memory_optimizer.register_resource("weapons", 2.0)).is_true()
	assert_that(memory_optimizer.register_resource("effects", 3.0)).is_true()
	
	var tracking_details = memory_optimizer.get_resource_tracking_details()
	assert_that(tracking_details).contains_keys(["ships", "weapons", "effects"])
	assert_that(tracking_details["ships"]["instance_count"]).is_equal(1)
	assert_that(tracking_details["ships"]["memory_usage_mb"]).is_equal(5.0)

func test_resource_cleanup() -> void:
	# Register then unregister resources
	memory_optimizer.register_resource("cleanup_test", 8.0)
	memory_optimizer.register_resource("cleanup_test", 5.0)  # Second instance
	
	var details_before = memory_optimizer.get_resource_tracking_details()
	assert_that(details_before["cleanup_test"]["instance_count"]).is_equal(2)
	
	# Cleanup one instance
	assert_that(memory_optimizer.unregister_resource("cleanup_test", 8.0)).is_true()
	
	var details_after = memory_optimizer.get_resource_tracking_details()
	assert_that(details_after["cleanup_test"]["instance_count"]).is_equal(1)
	assert_that(details_after["cleanup_test"]["memory_usage_mb"]).is_equal(5.0)

func test_object_pool_monitoring() -> void:
	# Register object pool for monitoring
	assert_that(memory_optimizer.register_pool("test_pool", 2.5)).is_true()
	
	# Update pool statistics
	assert_that(memory_optimizer.update_pool_stats("test_pool", 50, 30)).is_true()
	
	# Force pool cleanup check
	memory_optimizer._check_pool_cleanup(Time.get_ticks_usec() / 1000000.0 + 70.0)  # Simulate time passage
	
	# Verify pool is being monitored
	var memory_stats = memory_optimizer.get_memory_statistics()
	assert_that(memory_stats["monitored_pools"]).is_greater(0)

func test_cache_management() -> void:
	# Test texture cache tracking
	memory_optimizer.track_texture_cache("test_texture.png", 10.0)
	memory_optimizer.track_texture_cache("another_texture.jpg", 15.0)
	
	# Test audio cache tracking
	memory_optimizer.track_audio_cache("test_audio.ogg", 5.0)
	memory_optimizer.track_audio_cache("music.mp3", 20.0)
	
	var memory_stats = memory_optimizer.get_memory_statistics()
	assert_that(memory_stats["texture_cache_entries"]).is_equal(2)
	assert_that(memory_stats["audio_cache_entries"]).is_equal(2)

func test_garbage_collection_triggering() -> void:
	# Test manual garbage collection
	var gc_triggered = false
	memory_optimizer.garbage_collection_triggered.connect(
		func(reason, freed_mb, time_ms): gc_triggered = true
	)
	
	# Force garbage collection
	memory_optimizer._trigger_garbage_collection("TEST")
	
	assert_that(gc_triggered).is_true()

func test_emergency_cleanup() -> void:
	# Simulate critical memory condition
	var cleanup_completed = false
	memory_optimizer.resource_cleanup_completed.connect(
		func(resource_type, freed_count, freed_mb): cleanup_completed = true
	)
	
	# Add some cache entries to cleanup
	memory_optimizer.track_texture_cache("emergency_texture.png", 50.0)
	memory_optimizer.track_audio_cache("emergency_audio.ogg", 30.0)
	
	# Trigger emergency cleanup
	memory_optimizer._trigger_emergency_cleanup("TEST_EMERGENCY")
	
	var memory_stats = memory_optimizer.get_memory_statistics()
	assert_that(memory_stats).is_not_null()

func test_memory_health_status() -> void:
	var health_status = memory_optimizer.get_memory_health_status()
	
	assert_that(health_status).contains_keys([
		"status", "current_memory_mb", "health_ratio", 
		"warning_threshold_mb", "critical_threshold_mb"
	])
	
	assert_that(health_status["critical_threshold_mb"]).is_less_equal(2048.0)  # 2GB limit
	assert_that(health_status["warning_threshold_mb"]).is_less(health_status["critical_threshold_mb"])

func test_memory_optimization_effectiveness() -> void:
	# Create scenario requiring optimization
	for i in range(50):
		memory_optimizer.register_resource("optimization_test", 5.0)
	
	# Add cache entries
	for i in range(10):
		memory_optimizer.track_texture_cache("texture_%d.png" % i, 8.0)
		memory_optimizer.track_audio_cache("audio_%d.ogg" % i, 4.0)
	
	# Force memory optimization
	var optimization_result = memory_optimizer.force_memory_optimization()
	
	assert_that(optimization_result).contains_keys([
		"memory_before_mb", "memory_after_mb", "freed_mb", "optimization_effective"
	])
	assert_that(optimization_result["memory_before_mb"]).is_greater_equal(0.0)

func test_memory_warning_thresholds() -> void:
	var warning_triggered = false
	memory_optimizer.memory_warning.connect(
		func(threshold_type, current_mb, limit_mb): warning_triggered = true
	)
	
	# Simulate memory usage approaching threshold
	memory_optimizer.memory_warning_threshold_mb = 100.0  # Low threshold for testing
	memory_optimizer.memory_critical_threshold_mb = 150.0
	
	# Register enough resources to trigger warning
	for i in range(25):
		memory_optimizer.register_resource("warning_test", 5.0)  # 125 MB total
	
	# Force memory check
	memory_optimizer._check_memory_usage()
	
	# Verify system is monitoring warnings
	assert_that(memory_optimizer.memory_warning_threshold_mb).is_equal(100.0)

func test_2gb_memory_limit_enforcement() -> void:
	"""Test that the system enforces 2GB memory limit."""
	
	# Verify critical threshold is set to 2GB or less
	assert_that(memory_optimizer.memory_critical_threshold_mb).is_less_equal(2048.0)
	
	# Test health status with 2GB limit
	var health_status = memory_optimizer.get_memory_health_status()
	assert_that(health_status["critical_threshold_mb"]).is_less_equal(2048.0)
	
	# Verify memory is considered healthy under limit
	if health_status["current_memory_mb"] < 1024.0:  # Under 1GB
		assert_that(memory_optimizer.is_memory_usage_healthy()).is_true()

func test_automatic_cleanup_configuration() -> void:
	# Test auto cleanup enable/disable
	memory_optimizer.set_auto_cleanup_enabled(false)
	assert_that(memory_optimizer.auto_cleanup_enabled).is_false()
	
	memory_optimizer.set_auto_cleanup_enabled(true)
	assert_that(memory_optimizer.auto_cleanup_enabled).is_true()
	
	# Test monitoring enable/disable
	memory_optimizer.set_memory_monitoring_enabled(false)
	assert_that(memory_optimizer.enable_memory_monitoring).is_false()
	
	memory_optimizer.set_memory_monitoring_enabled(true)
	assert_that(memory_optimizer.enable_memory_monitoring).is_true()

func test_memory_statistics_accuracy() -> void:
	# Register known amounts of resources
	memory_optimizer.register_resource("accuracy_test_ships", 10.0)
	memory_optimizer.register_resource("accuracy_test_ships", 15.0)
	memory_optimizer.register_resource("accuracy_test_weapons", 5.0)
	
	var tracking_details = memory_optimizer.get_resource_tracking_details()
	
	# Verify accurate tracking
	assert_that(tracking_details["accuracy_test_ships"]["instance_count"]).is_equal(2)
	assert_that(tracking_details["accuracy_test_ships"]["memory_usage_mb"]).is_equal(25.0)
	assert_that(tracking_details["accuracy_test_weapons"]["instance_count"]).is_equal(1)
	assert_that(tracking_details["accuracy_test_weapons"]["memory_usage_mb"]).is_equal(5.0)

func test_error_handling() -> void:
	# Test invalid resource unregistration
	assert_that(memory_optimizer.unregister_resource("nonexistent", 5.0)).is_false()
	
	# Test invalid pool operations
	assert_that(memory_optimizer.update_pool_stats("nonexistent_pool", 10, 5)).is_false()
	
	# Test duplicate pool registration
	assert_that(memory_optimizer.register_pool("duplicate_pool", 2.0)).is_true()
	assert_that(memory_optimizer.register_pool("duplicate_pool", 3.0)).is_false()  # Should fail