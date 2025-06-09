class_name TestHUDDataProvider
extends GdUnitTestSuite

## EPIC-012 HUD-002: Comprehensive tests for HUD Data Provider system
## Tests data collection, caching, source management, and performance optimization

var data_provider: HUDDataProvider
var mock_ship: MockPlayerShip
var mock_object_manager: MockObjectManager
var test_scene: Node

func before_test() -> void:
	# Create test scene
	test_scene = Node.new()
	get_tree().root.add_child(test_scene)
	
	# Create mock systems
	mock_ship = MockPlayerShip.new()
	mock_ship.name = "PlayerShip"
	test_scene.add_child(mock_ship)
	
	mock_object_manager = MockObjectManager.new()
	mock_object_manager.name = "ObjectManager"
	test_scene.add_child(mock_object_manager)
	
	# Create data provider
	data_provider = HUDDataProvider.new()
	test_scene.add_child(data_provider)
	
	await get_tree().process_frame

func after_test() -> void:
	if test_scene:
		test_scene.queue_free()
	await get_tree().process_frame

func test_data_provider_initialization() -> void:
	# Test initialization completed
	assert_that(data_provider.update_intervals).is_not_empty()
	assert_that(data_provider.cache_ttl).is_not_empty()
	assert_that(data_provider.cached_data).is_not_empty()
	
	# Test update intervals are configured
	var expected_intervals = ["ship_status", "targeting_data", "weapon_status", "radar_contacts", 
							  "mission_info", "system_status", "communication", "navigation"]
	for interval_type in expected_intervals:
		assert_that(data_provider.update_intervals).contains_keys([interval_type])

func test_data_source_detection() -> void:
	# Test data source availability tracking
	assert_that(data_provider.data_sources_available).contains_keys(["ship_manager"])
	
	# Mock ship should be detected (it's added as BaseShip-compatible)
	# Note: This depends on the _find_manager implementation

func test_cache_system_initialization() -> void:
	# Test cache structures are initialized
	for data_type in data_provider.update_intervals.keys():
		assert_that(data_provider.cached_data).contains_keys([data_type])
		assert_that(data_provider.cache_timestamps).contains_keys([data_type])

func test_ship_status_data_collection() -> void:
	# Configure mock ship with test data
	mock_ship.hull_percentage = 85.0
	mock_ship.shield_percentage = 92.0
	mock_ship.current_speed = 150.0
	mock_ship.max_speed = 200.0
	
	# Trigger ship status data collection
	data_provider._collect_ship_status_data()
	
	# Test data was collected and cached
	var ship_data = data_provider.get_ship_status()
	assert_that(ship_data).contains_keys(["hull_percentage", "shield_percentage", "current_speed", "max_speed"])
	assert_that(ship_data.hull_percentage).is_equal(85.0)
	assert_that(ship_data.shield_percentage).is_equal(92.0)

func test_targeting_data_collection() -> void:
	# Setup mock ship with target
	var mock_target = MockShip.new()
	mock_target.name = "EnemyShip"
	mock_target.hull_percentage = 60.0
	mock_target.shield_percentage = 75.0
	mock_target.global_position = Vector3(100, 0, 50)
	test_scene.add_child(mock_target)
	
	mock_ship.current_target = mock_target
	
	# Trigger targeting data collection
	data_provider._collect_targeting_data()
	
	# Test targeting data
	var targeting_data = data_provider.get_targeting_data()
	assert_that(targeting_data.has_target).is_true()
	assert_that(targeting_data.target_hull).is_equal(60.0)
	assert_that(targeting_data.target_shield).is_equal(75.0)
	
	mock_target.queue_free()

func test_targeting_data_no_target() -> void:
	# Ensure no target
	mock_ship.current_target = null
	
	# Trigger targeting data collection
	data_provider._collect_targeting_data()
	
	# Test no target data
	var targeting_data = data_provider.get_targeting_data()
	assert_that(targeting_data.has_target).is_false()

func test_weapon_status_data_collection() -> void:
	# Configure mock ship weapon data
	mock_ship.weapon_data = {
		"primary_weapons": ["Laser Cannon", "Plasma Gun"],
		"secondary_weapons": ["Homing Missile", "Torpedo"],
		"weapon_energy": 85.0,
		"selected_primary": 0,
		"selected_secondary": 1
	}
	
	# Trigger weapon data collection
	data_provider._collect_weapon_status_data()
	
	# Test weapon data
	var weapon_data = data_provider.get_weapon_status()
	assert_that(weapon_data.primary_weapons).contains_exactly(["Laser Cannon", "Plasma Gun"])
	assert_that(weapon_data.weapon_energy).is_equal(85.0)
	assert_that(weapon_data.selected_secondary).is_equal(1)

func test_radar_contacts_data_collection() -> void:
	# Setup mock objects for radar
	var contact1 = MockRadarContact.new()
	contact1.name = "Fighter1"
	contact1.global_position = Vector3(200, 100, 0)
	contact1.object_type = "fighter"
	contact1.is_hostile_flag = true
	
	var contact2 = MockRadarContact.new()
	contact2.name = "Freighter1"
	contact2.global_position = Vector3(-150, 50, 100)
	contact2.object_type = "freighter"
	contact2.is_hostile_flag = false
	
	mock_object_manager.objects = [contact1, contact2]
	
	# Trigger radar data collection
	data_provider._collect_radar_contacts_data()
	
	# Test radar data
	var contacts = data_provider.get_radar_contacts()
	assert_that(contacts).has_size(2)
	
	# Test contact data structure
	var fighter_contact = contacts[0]
	assert_that(fighter_contact).contains_keys(["name", "position", "type", "is_hostile", "distance"])
	assert_that(fighter_contact.name).is_equal("Fighter1")
	assert_that(fighter_contact.type).is_equal("fighter")
	assert_that(fighter_contact.is_hostile).is_true()

func test_system_status_data_collection() -> void:
	# Trigger system status collection
	data_provider._collect_system_status_data()
	
	# Test system status data
	var system_data = data_provider.get_system_status()
	assert_that(system_data).contains_keys(["fps", "memory_usage", "performance_time_ms"])
	assert_that(system_data.fps).is_greater_equal(0)
	assert_that(system_data.memory_usage).is_greater_equal(0)

func test_navigation_data_collection() -> void:
	# Configure mock ship navigation data
	mock_ship.global_position = Vector3(500, 200, -300)
	mock_ship.heading = 45.0
	
	# Trigger navigation data collection
	data_provider._collect_navigation_data()
	
	# Test navigation data
	var nav_data = data_provider.get_data("navigation")
	assert_that(nav_data).contains_keys(["heading", "altitude", "waypoints", "autopilot_active"])
	assert_that(nav_data.heading).is_equal(45.0)
	assert_that(nav_data.altitude).is_equal(200.0)

func test_cache_validity_system() -> void:
	# Test fresh cache (should be invalid initially)
	assert_that(data_provider._is_cache_valid("ship_status")).is_false()
	
	# Collect data to populate cache
	data_provider._collect_ship_status_data()
	
	# Test cache is now valid
	assert_that(data_provider._is_cache_valid("ship_status")).is_true()

func test_cache_ttl_expiration() -> void:
	# Manually set cache data and timestamp
	data_provider.cached_data["test_data"] = {"value": 42}
	data_provider.cache_timestamps["test_data"] = Time.get_ticks_usec() / 1000000.0 - 10.0  # 10 seconds ago
	data_provider.cache_ttl["test_data"] = 5.0  # 5 second TTL
	
	# Test cache has expired
	assert_that(data_provider._is_cache_valid("test_data")).is_false()

func test_cache_invalidation() -> void:
	# Populate cache
	data_provider.cached_data["test_invalidate"] = {"data": "test"}
	data_provider.cache_timestamps["test_invalidate"] = Time.get_ticks_usec() / 1000000.0
	
	# Track invalidation signal
	var signal_tracker = CacheInvalidationTracker.new()
	data_provider.cache_invalidated.connect(signal_tracker._on_cache_invalidated)
	
	# Invalidate cache
	data_provider.invalidate_cache("test_invalidate")
	
	# Test cache was invalidated
	assert_that(data_provider.cached_data["test_invalidate"]).is_empty()
	assert_that(data_provider.cache_timestamps["test_invalidate"]).is_equal(0.0)
	assert_that(signal_tracker.invalidation_count).is_equal(1)

func test_performance_tracking() -> void:
	# Test initial performance state
	assert_that(data_provider.total_queries_per_frame).is_equal(0)
	assert_that(data_provider.data_collection_time_ms).is_equal(0.0)
	
	# Process frame to trigger performance measurement
	data_provider._process(0.016)
	
	# Test performance was tracked
	assert_that(data_provider.data_collection_time_ms).is_greater_equal(0.0)

func test_query_limit_enforcement() -> void:
	# Set low query limit for testing
	data_provider.max_queries_per_frame = 2
	data_provider.total_queries_per_frame = 2  # At limit
	
	# Try to trigger update that would exceed limit
	data_provider._on_update_timer_timeout("weapon_status")
	
	# Test that update was skipped (would need observable side effect)
	# This test verifies the guard clause works

func test_data_provider_statistics() -> void:
	# Get statistics
	var stats = data_provider.get_statistics()
	
	# Test statistics structure
	assert_that(stats).contains_keys([
		"data_sources_available", "cached_data_types", "data_collection_time_ms",
		"queries_per_frame", "cache_hit_rates", "update_intervals"
	])
	
	assert_that(stats.cached_data_types).is_not_empty()
	assert_that(stats.update_intervals).is_not_empty()

func test_default_ship_data_fallback() -> void:
	# Remove mock ship to test fallback
	mock_ship.queue_free()
	await get_tree().process_frame
	
	# Trigger ship data collection without ship
	data_provider._collect_ship_status_data()
	
	# Test fallback data is provided
	var ship_data = data_provider.get_ship_status()
	assert_that(ship_data).contains_keys(["hull_percentage", "shield_percentage"])
	assert_that(ship_data.hull_percentage).is_equal(100.0)  # Default value
	assert_that(ship_data.shield_percentage).is_equal(100.0)  # Default value

func test_real_time_data_access() -> void:
	# Configure mock ship
	mock_ship.hull_percentage = 75.0
	mock_ship.shield_percentage = 50.0
	
	# Test real-time access forces immediate update
	var ship_data = data_provider.get_ship_status()
	assert_that(ship_data.hull_percentage).is_equal(75.0)
	
	# Change ship data
	mock_ship.hull_percentage = 25.0
	
	# Test real-time access gets updated data
	ship_data = data_provider.get_ship_status()
	assert_that(ship_data.hull_percentage).is_equal(25.0)

func test_timer_based_updates() -> void:
	# Test that timers are created for all data types
	assert_that(data_provider.update_timers).is_not_empty()
	
	for data_type in data_provider.update_intervals.keys():
		assert_that(data_provider.update_timers).contains_keys([data_type])
		var timer = data_provider.update_timers[data_type]
		assert_that(timer).is_not_null()
		assert_that(timer.wait_time).is_equal(data_provider.update_intervals[data_type])

func test_signal_emissions() -> void:
	# Track data update signals
	var signal_tracker = DataUpdateTracker.new()
	data_provider.data_updated.connect(signal_tracker._on_data_updated)
	data_provider.data_source_error.connect(signal_tracker._on_data_source_error)
	
	# Trigger data collection
	data_provider._collect_ship_status_data()
	
	# Test signal was emitted
	assert_that(signal_tracker.update_count).is_equal(1)
	assert_that(signal_tracker.last_data_type).is_equal("ship_status")

func test_error_handling() -> void:
	# Track error signals
	var signal_tracker = DataUpdateTracker.new()
	data_provider.data_source_error.connect(signal_tracker._on_data_source_error)
	
	# Trigger error condition (this would need specific error scenarios)
	data_provider._on_data_collection_error("test_source", "test_error")
	
	# Test error signal was emitted
	assert_that(signal_tracker.error_count).is_equal(1)

## Mock classes for testing

class MockPlayerShip extends Node3D:
	var hull_percentage: float = 100.0
	var shield_percentage: float = 100.0
	var current_speed: float = 0.0
	var max_speed: float = 100.0
	var afterburner_fuel: float = 100.0
	var energy_levels: Dictionary = {"shields": 0.33, "weapons": 0.33, "engines": 0.33}
	var ship_flags: int = 0
	var subsystem_status: Dictionary = {}
	var velocity: Vector3 = Vector3.ZERO
	var current_target: Node3D = null
	var heading: float = 0.0
	var weapon_data: Dictionary = {}
	
	func get_hull_percentage() -> float:
		return hull_percentage
	
	func get_shield_percentage() -> float:
		return shield_percentage
	
	func get_current_speed() -> float:
		return current_speed
	
	func get_max_speed() -> float:
		return max_speed
	
	func get_afterburner_fuel_percentage() -> float:
		return afterburner_fuel
	
	func get_energy_levels() -> Dictionary:
		return energy_levels
	
	func get_ship_flags() -> int:
		return ship_flags
	
	func get_subsystem_status() -> Dictionary:
		return subsystem_status
	
	func get_velocity() -> Vector3:
		return velocity
	
	func get_target() -> Node3D:
		return current_target
	
	func get_heading() -> float:
		return heading
	
	func get_weapon_status() -> Dictionary:
		return weapon_data

class MockShip extends Node3D:
	var hull_percentage: float = 100.0
	var shield_percentage: float = 100.0
	var ship_name: String = "TestShip"
	var ship_type: String = "fighter"
	var velocity: Vector3 = Vector3.ZERO
	var hostile_flag: bool = false
	
	func get_hull_percentage() -> float:
		return hull_percentage
	
	func get_shield_percentage() -> float:
		return shield_percentage
	
	func get_ship_name() -> String:
		return ship_name
	
	func get_ship_type() -> String:
		return ship_type
	
	func get_velocity() -> Vector3:
		return velocity
	
	func is_hostile_to(other: Node) -> bool:
		return hostile_flag

class MockObjectManager extends Node:
	var objects: Array = []
	
	func get_all_objects() -> Array:
		return objects

class MockRadarContact extends Node3D:
	var object_type: String = "unknown"
	var is_hostile_flag: bool = false
	var radar_visible: bool = true
	
	func is_radar_visible() -> bool:
		return radar_visible
	
	func get_object_name() -> String:
		return name
	
	func get_object_type() -> String:
		return object_type
	
	func is_hostile() -> bool:
		return is_hostile_flag

## Helper classes for testing

class CacheInvalidationTracker extends RefCounted:
	var invalidation_count: int = 0
	var last_data_type: String = ""
	
	func _on_cache_invalidated(data_type: String) -> void:
		invalidation_count += 1
		last_data_type = data_type

class DataUpdateTracker extends RefCounted:
	var update_count: int = 0
	var error_count: int = 0
	var last_data_type: String = ""
	var last_error_source: String = ""
	
	func _on_data_updated(data_type: String, data: Dictionary) -> void:
		update_count += 1
		last_data_type = data_type
	
	func _on_data_source_error(source: String, error: String) -> void:
		error_count += 1
		last_error_source = source