class_name TestHUDManager
extends GdUnitTestSuite

## EPIC-012 HUD-001: Comprehensive tests for HUD Manager and Element Framework
## Tests element registration, lifecycle management, performance monitoring, and integration

var hud_manager: HUDManager
var test_element: HUDElementBase
var mock_viewport: SubViewport

func before_test() -> void:
	# Create test viewport
	mock_viewport = SubViewport.new()
	mock_viewport.size = Vector2(1920, 1080)
	get_tree().root.add_child(mock_viewport)
	
	# Create HUD manager instance
	hud_manager = HUDManager.new()
	mock_viewport.add_child(hud_manager)
	
	# Wait for initialization
	await get_tree().process_frame
	await get_tree().process_frame

func after_test() -> void:
	if hud_manager:
		hud_manager.queue_free()
	if mock_viewport:
		mock_viewport.queue_free()
	await get_tree().process_frame

func test_hud_manager_initialization() -> void:
	# Test singleton setup
	assert_that(HUDManager.get_instance()).is_not_null()
	assert_that(HUDManager.is_ready()).is_true()
	
	# Test core systems initialization
	assert_that(hud_manager.data_provider).is_not_null()
	assert_that(hud_manager.performance_monitor).is_not_null()
	assert_that(hud_manager.layout_manager).is_not_null()
	
	# Test initialization state
	assert_that(hud_manager.initialization_complete).is_true()
	assert_that(hud_manager.hud_enabled).is_true()

func test_element_registration() -> void:
	# Create test element
	var element = _create_test_element("test_element_001", 10)
	
	# Test registration
	var success = hud_manager.register_element(element)
	assert_that(success).is_true()
	
	# Test element is registered
	var retrieved_element = hud_manager.get_element("test_element_001")
	assert_that(retrieved_element).is_same(element)
	
	# Test element is in active elements
	var all_elements = hud_manager.get_all_elements()
	assert_that(all_elements).contains([element])

func test_element_registration_validation() -> void:
	# Test null element registration
	var success = hud_manager.register_element(null)
	assert_that(success).is_false()
	
	# Test element without ID
	var element_no_id = HUDElementBase.new()
	element_no_id.element_id = ""
	success = hud_manager.register_element(element_no_id)
	assert_that(success).is_false()
	
	# Test duplicate registration
	var element1 = _create_test_element("duplicate_test", 5)
	var element2 = _create_test_element("duplicate_test", 5)
	
	hud_manager.register_element(element1)
	success = hud_manager.register_element(element2)
	assert_that(success).is_false()

func test_element_unregistration() -> void:
	# Register element
	var element = _create_test_element("unregister_test", 5)
	hud_manager.register_element(element)
	
	# Test unregistration
	var success = hud_manager.unregister_element("unregister_test")
	assert_that(success).is_true()
	
	# Test element is no longer available
	var retrieved_element = hud_manager.get_element("unregister_test")
	assert_that(retrieved_element).is_null()
	
	# Test unregistering non-existent element
	success = hud_manager.unregister_element("non_existent")
	assert_that(success).is_false()

func test_element_priority_ordering() -> void:
	# Create elements with different priorities
	var low_priority = _create_test_element("low_priority", 1)
	var high_priority = _create_test_element("high_priority", 10)
	var medium_priority = _create_test_element("medium_priority", 5)
	
	# Register in random order
	hud_manager.register_element(medium_priority)
	hud_manager.register_element(low_priority)
	hud_manager.register_element(high_priority)
	
	# Test update order is by priority (high to low)
	var update_order = hud_manager._get_update_order()
	assert_that(update_order[0]).is_equal("high_priority")
	assert_that(update_order[1]).is_equal("medium_priority")
	assert_that(update_order[2]).is_equal("low_priority")

func test_hud_enabled_state() -> void:
	# Test initial state
	assert_that(hud_manager.hud_enabled).is_true()
	
	# Register test element
	var element = _create_test_element("visibility_test", 5)
	hud_manager.register_element(element)
	
	# Test disabling HUD
	hud_manager.set_hud_enabled(false)
	assert_that(hud_manager.hud_enabled).is_false()
	
	# Test enabling HUD
	hud_manager.set_hud_enabled(true)
	assert_that(hud_manager.hud_enabled).is_true()

func test_screen_size_handling() -> void:
	# Test initial screen size
	assert_that(hud_manager.screen_size).is_not_null()
	
	# Register element to test screen size propagation
	var element = _create_test_element("screen_test", 5)
	hud_manager.register_element(element)
	
	# Simulate screen size change
	var new_size = Vector2(2560, 1440)
	hud_manager._on_viewport_size_changed()
	
	# Test that elements are notified (would need mock verification)

func test_performance_integration() -> void:
	# Test performance monitor integration
	assert_that(hud_manager.performance_monitor).is_not_null()
	
	# Test performance statistics access
	var stats = hud_manager.get_performance_statistics()
	assert_that(stats).is_not_null()
	
	# Test HUD status includes performance data
	var status = hud_manager.get_hud_status()
	assert_that(status).contains_keys(["performance"])

func test_data_provider_integration() -> void:
	# Test data provider access
	var data_provider = hud_manager.get_data_provider()
	assert_that(data_provider).is_not_null()
	assert_that(data_provider).is_same(hud_manager.data_provider)

func test_layout_manager_integration() -> void:
	# Test layout manager access
	var layout_manager = hud_manager.get_layout_manager()
	assert_that(layout_manager).is_not_null()
	assert_that(layout_manager).is_same(hud_manager.layout_manager)

func test_element_containers() -> void:
	# Test that containers are created
	assert_that(hud_manager.element_containers).is_not_empty()
	
	# Test required containers exist
	var required_containers = ["core", "targeting", "status", "radar", "communication", "navigation", "debug"]
	for container_name in required_containers:
		assert_that(hud_manager.element_containers).contains_keys([container_name])

func test_debug_mode() -> void:
	# Test initial debug mode state
	assert_that(hud_manager.debug_mode).is_false()
	
	# Test enabling debug mode
	hud_manager.set_debug_mode(true)
	assert_that(hud_manager.debug_mode).is_true()
	
	# Test debug container visibility
	if hud_manager.element_containers.has("debug"):
		assert_that(hud_manager.element_containers["debug"].visible).is_true()
	
	# Test disabling debug mode
	hud_manager.set_debug_mode(false)
	assert_that(hud_manager.debug_mode).is_false()

func test_element_update_cycle() -> void:
	# Create mock element that tracks updates
	var mock_element = MockHUDElement.new()
	mock_element.element_id = "update_test"
	mock_element.element_priority = 5
	mock_element.is_active = true
	
	hud_manager.register_element(mock_element)
	
	# Process a few frames to trigger updates
	for i in range(5):
		hud_manager._process(0.016)  # ~60 FPS
		await get_tree().process_frame
	
	# Test that element received updates
	assert_that(mock_element.update_count).is_greater(0)

func test_element_container_assignment() -> void:
	# Test elements get assigned to correct containers
	var targeting_element = _create_test_element("targeting_test", 5)
	targeting_element.container_type = "targeting"
	
	hud_manager.register_element(targeting_element)
	
	# Test element is in targeting container
	var targeting_container = hud_manager.element_containers["targeting"]
	assert_that(targeting_element.get_parent()).is_same(targeting_container)

func test_configuration_system() -> void:
	# Test configuration loading
	var success = hud_manager.load_configuration("test_config_path")
	assert_that(success).is_true()
	
	# Test configuration saving
	success = hud_manager.save_configuration("test_save_path")
	assert_that(success).is_true()

func test_legacy_hud_integration() -> void:
	# Test that legacy HUD detection doesn't crash
	# This would be expanded with proper legacy system mocks
	assert_that(hud_manager.legacy_hud_manager).is_null()  # No legacy system in test

func test_signal_connections() -> void:
	# Test that required signals are properly connected
	# This verifies the signal setup doesn't crash and connections exist
	
	# Create signal tracker
	var signal_tracker = SignalTracker.new()
	
	# Connect to HUD manager signals
	hud_manager.hud_element_registered.connect(signal_tracker._on_element_registered)
	hud_manager.hud_element_unregistered.connect(signal_tracker._on_element_unregistered)
	hud_manager.hud_visibility_changed.connect(signal_tracker._on_visibility_changed)
	
	# Register element to trigger signal
	var element = _create_test_element("signal_test", 5)
	hud_manager.register_element(element)
	
	# Test signal was emitted
	assert_that(signal_tracker.element_registered_count).is_equal(1)
	
	# Unregister to trigger another signal
	hud_manager.unregister_element("signal_test")
	assert_that(signal_tracker.element_unregistered_count).is_equal(1)

func test_cleanup_and_shutdown() -> void:
	# Register elements
	var element1 = _create_test_element("cleanup_test_1", 5)
	var element2 = _create_test_element("cleanup_test_2", 3)
	
	hud_manager.register_element(element1)
	hud_manager.register_element(element2)
	
	# Test elements are registered
	assert_that(hud_manager.get_all_elements().size()).is_equal(2)
	
	# Trigger cleanup
	hud_manager._exit_tree()
	
	# Test cleanup completed
	assert_that(hud_manager.registered_elements).is_empty()
	assert_that(hud_manager.active_elements).is_empty()

## Helper methods

func _create_test_element(id: String, priority: int) -> HUDElementBase:
	var element = HUDElementBase.new()
	element.element_id = id
	element.element_priority = priority
	element.container_type = "core"
	element.is_active = true
	return element

## Mock classes for testing

class MockHUDElement extends HUDElementBase:
	var update_count: int = 0
	
	func _element_update(delta: float) -> void:
		super._element_update(delta)
		update_count += 1

class SignalTracker extends RefCounted:
	var element_registered_count: int = 0
	var element_unregistered_count: int = 0
	var visibility_changed_count: int = 0
	
	func _on_element_registered(element_id: String, element: HUDElementBase) -> void:
		element_registered_count += 1
	
	func _on_element_unregistered(element_id: String) -> void:
		element_unregistered_count += 1
	
	func _on_visibility_changed(enabled: bool) -> void:
		visibility_changed_count += 1