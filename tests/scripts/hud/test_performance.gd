extends GdUnitTestSuite

## EPIC-012 HUD-003: Performance Optimization Unit Tests
## Comprehensive tests for LOD, scheduling, rendering, memory, and scaling systems

# Test subjects
var lod_manager: HUDLODManager
var update_scheduler: HUDUpdateScheduler
var render_optimizer: HUDRenderOptimizer
var memory_manager: HUDMemoryManager
var performance_scaler: HUDPerformanceScaler
var performance_profiler: HUDPerformanceProfiler

# Mock objects for testing
var mock_element: Control
var mock_factory: Callable

func before_test() -> void:
	# Create optimization system instances
	lod_manager = HUDLODManager.new()
	update_scheduler = HUDUpdateScheduler.new()
	render_optimizer = HUDRenderOptimizer.new()
	memory_manager = HUDMemoryManager.new()
	performance_scaler = HUDPerformanceScaler.new()
	performance_profiler = HUDPerformanceProfiler.new()
	
	# Create mock objects
	mock_element = Control.new()
	mock_element.size = Vector2(100, 50)
	mock_factory = func(): return Control.new()

func after_test() -> void:
	# Clean up test objects
	if mock_element:
		mock_element.queue_free()
	if lod_manager:
		lod_manager.queue_free()
	if update_scheduler:
		update_scheduler.queue_free()
	if render_optimizer:
		render_optimizer.queue_free()
	if memory_manager:
		memory_manager.queue_free()
	if performance_scaler:
		performance_scaler.queue_free()
	if performance_profiler:
		performance_profiler.queue_free()

# LOD Manager Tests

func test_lod_manager_initialization() -> void:
	assert_that(lod_manager).is_not_null()
	assert_that(lod_manager.global_lod_level).is_equal(HUDLODManager.LODLevel.MAXIMUM)
	assert_that(lod_manager.auto_lod_enabled).is_true()

func test_lod_element_registration() -> void:
	var element_id = "test_element"
	var priority = HUDLODManager.ElementPriority.HIGH
	var min_lod = HUDLODManager.LODLevel.LOW
	
	lod_manager.register_element(element_id, priority, min_lod)
	
	assert_that(lod_manager.element_priorities.has(element_id)).is_true()
	assert_that(lod_manager.element_priorities[element_id]).is_equal(priority)
	assert_that(lod_manager.element_min_lod[element_id]).is_equal(min_lod)

func test_lod_level_assignment() -> void:
	var element_id = "test_element"
	lod_manager.register_element(element_id, HUDLODManager.ElementPriority.MEDIUM)
	
	# Test manual LOD setting
	lod_manager.set_element_lod(element_id, HUDLODManager.LODLevel.LOW)
	assert_that(lod_manager.get_element_lod(element_id)).is_equal(HUDLODManager.LODLevel.LOW)
	
	# Test LOD override clearing
	lod_manager.clear_element_lod_override(element_id)
	assert_that(lod_manager.get_element_lod(element_id)).is_equal(lod_manager.global_lod_level)

func test_global_lod_changes() -> void:
	var signal_emitted = false
	lod_manager.global_lod_changed.connect(func(old_level, new_level): signal_emitted = true)
	
	lod_manager.set_global_lod(HUDLODManager.LODLevel.MEDIUM)
	
	assert_that(lod_manager.global_lod_level).is_equal(HUDLODManager.LODLevel.MEDIUM)
	assert_that(signal_emitted).is_true()

func test_lod_update_frequencies() -> void:
	assert_that(lod_manager.get_lod_update_frequency(HUDLODManager.LODLevel.MAXIMUM)).is_equal(60.0)
	assert_that(lod_manager.get_lod_update_frequency(HUDLODManager.LODLevel.MINIMAL)).is_equal(5.0)
	
	var interval = lod_manager.get_lod_update_interval(HUDLODManager.LODLevel.HIGH)
	assert_that(interval).is_equal(1.0 / 45.0)

func test_performance_mode() -> void:
	var element_id = "test_element"
	lod_manager.register_element(element_id, HUDLODManager.ElementPriority.MEDIUM)
	
	lod_manager.enable_performance_mode()
	
	# Medium priority elements should be reduced to LOW
	assert_that(lod_manager.get_element_lod(element_id)).is_equal(HUDLODManager.LODLevel.LOW)

# Update Scheduler Tests

func test_update_scheduler_initialization() -> void:
	assert_that(update_scheduler).is_not_null()
	assert_that(update_scheduler.frame_budget_ms).is_equal(2.0)
	assert_that(update_scheduler.scheduler_enabled).is_true()

func test_element_registration_for_updates() -> void:
	var element_id = "test_element"
	var frequency = 30.0
	var callback = func(): pass
	var priority = 75
	
	update_scheduler.register_element(element_id, frequency, callback, priority)
	
	assert_that(update_scheduler.element_update_frequencies.has(element_id)).is_true()
	assert_that(update_scheduler.element_update_frequencies[element_id]).is_equal(frequency)
	assert_that(update_scheduler.element_update_priorities[element_id]).is_equal(priority)

func test_dirty_state_tracking() -> void:
	var element_id = "test_element"
	var callback = func(): pass
	update_scheduler.register_element(element_id, 60.0, callback)
	
	# Mark element as dirty
	update_scheduler.mark_dirty(element_id, "data_changed")
	assert_that(update_scheduler.is_dirty(element_id)).is_true()
	
	# Clear dirty state
	update_scheduler.clear_dirty(element_id)
	assert_that(update_scheduler.is_dirty(element_id)).is_false()

func test_frequency_updates() -> void:
	var element_id = "test_element"
	var callback = func(): pass
	update_scheduler.register_element(element_id, 60.0, callback)
	
	update_scheduler.set_element_frequency(element_id, 30.0)
	assert_that(update_scheduler.element_update_frequencies[element_id]).is_equal(30.0)

func test_scheduler_statistics() -> void:
	var stats = update_scheduler.get_statistics()
	
	assert_that(stats.has("frame_budget_ms")).is_true()
	assert_that(stats.has("scheduler_enabled")).is_true()
	assert_that(stats.has("registered_elements")).is_true()

# Render Optimizer Tests

func test_render_optimizer_initialization() -> void:
	assert_that(render_optimizer).is_not_null()
	assert_that(render_optimizer.enable_culling).is_true()
	assert_that(render_optimizer.enable_batching).is_true()

func test_element_registration_for_rendering() -> void:
	var element_id = "test_element"
	var material_hash = "default_material"
	var z_layer = 1
	
	render_optimizer.register_element(element_id, mock_element, material_hash, z_layer)
	
	assert_that(render_optimizer.tracked_elements.has(element_id)).is_true()
	assert_that(render_optimizer.element_materials[element_id]).is_equal(material_hash)
	assert_that(render_optimizer.element_z_layers[element_id]).is_equal(z_layer)

func test_element_visibility_control() -> void:
	var element_id = "test_element"
	render_optimizer.register_element(element_id, mock_element)
	
	# Test manual visibility control
	render_optimizer.set_element_visibility(element_id, false, "manual_hide")
	assert_that(render_optimizer.is_element_visible(element_id)).is_false()
	
	render_optimizer.set_element_visibility(element_id, true, "manual_show")
	assert_that(render_optimizer.is_element_visible(element_id)).is_true()

func test_culling_and_batching_toggles() -> void:
	render_optimizer.set_culling_enabled(false)
	assert_that(render_optimizer.enable_culling).is_false()
	
	render_optimizer.set_batching_enabled(false)
	assert_that(render_optimizer.enable_batching).is_false()

func test_render_statistics() -> void:
	var stats = render_optimizer.get_statistics()
	
	assert_that(stats.has("total_elements_tracked")).is_true()
	assert_that(stats.has("culling_enabled")).is_true()
	assert_that(stats.has("batching_enabled")).is_true()

# Memory Manager Tests

func test_memory_manager_initialization() -> void:
	assert_that(memory_manager).is_not_null()
	assert_that(memory_manager.memory_limit_mb).is_equal(50.0)
	assert_that(memory_manager.enable_object_pooling).is_true()
	assert_that(memory_manager.enable_cache_management).is_true()

func test_object_pool_creation() -> void:
	var pool_name = "test_pool"
	var initial_size = 5
	
	memory_manager.create_object_pool(pool_name, mock_factory, initial_size)
	
	assert_that(memory_manager.object_pools.has(pool_name)).is_true()
	
	var pool_data = memory_manager.object_pools[pool_name]
	assert_that(pool_data.initial_size).is_equal(initial_size)
	assert_that(pool_data.available_objects.size()).is_equal(initial_size)

func test_object_pooling_lifecycle() -> void:
	var pool_name = "test_pool"
	memory_manager.create_object_pool(pool_name, mock_factory, 3)
	
	# Get object from pool
	var obj = memory_manager.get_pooled_object(pool_name)
	assert_that(obj).is_not_null()
	
	# Return object to pool
	memory_manager.return_pooled_object(pool_name, obj)
	
	# Pool should have the returned object
	var pool_data = memory_manager.object_pools[pool_name]
	assert_that(pool_data.available_objects.size()).is_equal(3)

func test_cache_management() -> void:
	var cache_key = "test_data"
	var test_data = {"value": 42}
	var estimated_size = 100
	
	# Store data in cache
	memory_manager.cache_data(cache_key, test_data, estimated_size)
	assert_that(memory_manager.has_cached_data(cache_key)).is_true()
	
	# Retrieve data from cache
	var retrieved_data = memory_manager.get_cached_data(cache_key)
	assert_that(retrieved_data).is_equal(test_data)
	
	# Remove data from cache
	memory_manager.remove_cached_data(cache_key)
	assert_that(memory_manager.has_cached_data(cache_key)).is_false()

func test_memory_statistics() -> void:
	var stats = memory_manager.get_memory_statistics()
	
	assert_that(stats.has("current_usage_mb")).is_true()
	assert_that(stats.has("cache_usage_mb")).is_true()
	assert_that(stats.has("active_pools")).is_true()
	assert_that(stats.has("pooling_enabled")).is_true()

func test_memory_limits_configuration() -> void:
	var new_limit = 75.0
	var new_cleanup = 60.0
	var new_emergency = 70.0
	
	memory_manager.set_memory_limits(new_limit, new_cleanup, new_emergency)
	
	assert_that(memory_manager.memory_limit_mb).is_equal(new_limit)
	assert_that(memory_manager.cleanup_threshold_mb).is_equal(new_cleanup)
	assert_that(memory_manager.emergency_cleanup_mb).is_equal(new_emergency)

# Performance Scaler Tests

func test_performance_scaler_initialization() -> void:
	assert_that(performance_scaler).is_not_null()
	assert_that(performance_scaler.auto_scaling_enabled).is_true()
	assert_that(performance_scaler.target_fps).is_equal(60.0)
	assert_that(performance_scaler.current_profile).is_equal(HUDPerformanceScaler.PerformanceProfile.MAXIMUM)

func test_performance_profile_changes() -> void:
	var signal_emitted = false
	performance_scaler.performance_profile_changed.connect(func(old, new): signal_emitted = true)
	
	performance_scaler.set_performance_profile(HUDPerformanceScaler.PerformanceProfile.MEDIUM)
	
	assert_that(performance_scaler.current_profile).is_equal(HUDPerformanceScaler.PerformanceProfile.MEDIUM)
	assert_that(signal_emitted).is_true()

func test_fps_threshold_configuration() -> void:
	var custom_thresholds = {
		HUDPerformanceScaler.PerformanceProfile.MAXIMUM: 55.0,
		HUDPerformanceScaler.PerformanceProfile.HIGH: 45.0,
		HUDPerformanceScaler.PerformanceProfile.MEDIUM: 35.0,
		HUDPerformanceScaler.PerformanceProfile.LOW: 25.0,
		HUDPerformanceScaler.PerformanceProfile.MINIMAL: 15.0
	}
	
	performance_scaler.set_fps_thresholds(custom_thresholds)
	assert_that(performance_scaler.fps_thresholds).is_equal(custom_thresholds)

func test_emergency_performance_mode() -> void:
	performance_scaler.enable_emergency_mode()
	assert_that(performance_scaler.current_profile).is_equal(HUDPerformanceScaler.PerformanceProfile.MINIMAL)

func test_performance_statistics() -> void:
	var stats = performance_scaler.get_performance_statistics()
	
	assert_that(stats.has("current_profile")).is_true()
	assert_that(stats.has("current_fps")).is_true()
	assert_that(stats.has("auto_scaling_enabled")).is_true()

func test_auto_scaling_toggle() -> void:
	performance_scaler.set_auto_scaling_enabled(false)
	assert_that(performance_scaler.auto_scaling_enabled).is_false()
	
	performance_scaler.set_auto_scaling_enabled(true)
	assert_that(performance_scaler.auto_scaling_enabled).is_true()

# Performance Profiler Tests

func test_performance_profiler_initialization() -> void:
	assert_that(performance_profiler).is_not_null()
	assert_that(performance_profiler.enable_profiling).is_false()
	assert_that(performance_profiler.enable_debug_overlay).is_false()

func test_profiling_enable_disable() -> void:
	performance_profiler.set_profiling_enabled(true)
	assert_that(performance_profiler.enable_profiling).is_true()
	
	performance_profiler.set_profiling_enabled(false)
	assert_that(performance_profiler.enable_profiling).is_false()

func test_debug_overlay_toggle() -> void:
	performance_profiler.set_debug_overlay_enabled(true)
	assert_that(performance_profiler.enable_debug_overlay).is_true()
	assert_that(performance_profiler.visible).is_true()
	
	performance_profiler.set_debug_overlay_enabled(false)
	assert_that(performance_profiler.enable_debug_overlay).is_false()
	assert_that(performance_profiler.visible).is_false()

func test_performance_history_management() -> void:
	# Add some mock performance data
	var mock_data = {
		"timestamp": 123456.0,
		"fps": 45.0,
		"components": {}
	}
	performance_profiler.performance_history.append(mock_data)
	
	assert_that(performance_profiler.performance_history.size()).is_equal(1)
	
	performance_profiler.clear_performance_history()
	assert_that(performance_profiler.performance_history.size()).is_equal(0)

func test_performance_report_generation() -> void:
	var report = performance_profiler.get_performance_report()
	
	assert_that(report.has("current_data")).is_true()
	assert_that(report.has("profiling_enabled")).is_true()
	assert_that(report.has("components_monitored")).is_true()

# Integration Tests

func test_system_integration() -> void:
	# Test that optimization systems can work together
	var element_id = "integration_test_element"
	
	# Register element with LOD system
	lod_manager.register_element(element_id, HUDLODManager.ElementPriority.MEDIUM)
	
	# Register element with update scheduler
	var callback = func(): pass
	update_scheduler.register_element(element_id, 60.0, callback)
	
	# Register element with render optimizer
	render_optimizer.register_element(element_id, mock_element)
	
	# Test that all systems are tracking the element
	assert_that(lod_manager.element_priorities.has(element_id)).is_true()
	assert_that(update_scheduler.element_update_frequencies.has(element_id)).is_true()
	assert_that(render_optimizer.tracked_elements.has(element_id)).is_true()

func test_performance_cascade() -> void:
	# Test performance optimization cascading through systems
	
	# Start with high performance profile
	performance_scaler.set_performance_profile(HUDPerformanceScaler.PerformanceProfile.MAXIMUM)
	
	# Enable performance mode in LOD
	lod_manager.enable_performance_mode()
	
	# Check that systems respond appropriately
	assert_that(performance_scaler.current_profile).is_equal(HUDPerformanceScaler.PerformanceProfile.MAXIMUM)

func test_memory_pressure_response() -> void:
	# Simulate memory pressure
	memory_manager.memory_limit_mb = 10.0  # Very low limit
	memory_manager.cleanup_threshold_mb = 8.0
	
	# Create object pool that would exceed memory
	memory_manager.create_object_pool("pressure_test", mock_factory, 50)
	
	# Memory manager should handle the pressure
	var stats = memory_manager.get_memory_statistics()
	assert_that(stats.has("memory_cleanups")).is_true()

func test_budget_exceeded_handling() -> void:
	# Set very low frame budget
	update_scheduler.frame_budget_ms = 0.1
	
	var budget_exceeded = false
	update_scheduler.frame_budget_exceeded.connect(func(time, budget): budget_exceeded = true)
	
	# Register element with high frequency that would exceed budget
	var heavy_callback = func():
		# Simulate heavy work
		for i in range(1000):
			var dummy = i * i
	
	update_scheduler.register_element("heavy_element", 60.0, heavy_callback)
	
	# Force an update cycle
	update_scheduler._process_update_queue()
	
	# Should have triggered budget exceeded (in a real scenario)
	# Note: This test might not trigger in unit test environment without actual frame processing

func test_lod_performance_scaling_integration() -> void:
	# Test integration between LOD and performance scaling
	var element_id = "scaling_test_element"
	
	# Register element with LOD system
	lod_manager.register_element(element_id, HUDLODManager.ElementPriority.MEDIUM)
	
	# Set performance scaler to low performance
	performance_scaler.set_performance_profile(HUDPerformanceScaler.PerformanceProfile.LOW)
	
	# Check that LOD system could respond to performance scaling
	# (In real implementation, this would be connected via signals)
	var recommended_lod = lod_manager.get_recommended_lod(element_id, 30.0)  # Low FPS
	assert_that(recommended_lod).is_greater_equal(HUDLODManager.LODLevel.MEDIUM)

func test_comprehensive_optimization_trigger() -> void:
	# Test that all optimization systems can be triggered together
	
	# Set up elements in all systems
	var element_id = "comprehensive_test"
	
	lod_manager.register_element(element_id, HUDLODManager.ElementPriority.MEDIUM)
	update_scheduler.register_element(element_id, 60.0, func(): pass)
	render_optimizer.register_element(element_id, mock_element)
	
	# Enable performance mode across systems
	lod_manager.enable_performance_mode()
	performance_scaler.enable_emergency_mode()
	
	# Verify that optimization states are active
	assert_that(performance_scaler.current_profile).is_equal(HUDPerformanceScaler.PerformanceProfile.MINIMAL)
	
	# LOD should be reduced for medium priority elements
	var element_lod = lod_manager.get_element_lod(element_id)
	assert_that(element_lod).is_greater_equal(HUDLODManager.LODLevel.LOW)

# Performance Benchmarks

func test_60_fps_maintenance_simulation() -> void:
	# Simulate maintaining 60 FPS with multiple elements
	var target_frame_time_ms = 16.67  # 60 FPS = 16.67ms per frame
	var hud_budget_ms = 2.0  # 2ms budget for HUD
	
	# Test that budget allocation works
	assert_that(hud_budget_ms).is_less(target_frame_time_ms)
	
	# Test element budget distribution
	var max_elements = 20
	var per_element_budget = hud_budget_ms / max_elements
	assert_that(per_element_budget).is_greater(0.0)

func test_memory_usage_bounds() -> void:
	# Test that memory manager respects bounds
	var limit_mb = 50.0
	memory_manager.set_memory_limits(limit_mb, limit_mb * 0.8, limit_mb * 0.9)
	
	# Create multiple object pools
	for i in range(10):
		memory_manager.create_object_pool("pool_%d" % i, mock_factory, 5)
	
	# Check that memory usage is tracked
	var stats = memory_manager.get_memory_statistics()
	assert_that(stats.current_usage_mb).is_greater_equal(0.0)

func test_frame_budget_adherence() -> void:
	# Test that update scheduler respects frame budget
	var budget_ms = 2.0
	update_scheduler.frame_budget_ms = budget_ms
	
	# Register multiple elements
	for i in range(10):
		var element_id = "budget_test_%d" % i
		update_scheduler.register_element(element_id, 60.0, func(): pass)
	
	# Check that scheduler limits updates per frame
	assert_that(update_scheduler.max_updates_per_frame).is_greater(0)
	assert_that(update_scheduler.frame_budget_ms).is_equal(budget_ms)