extends GdUnitTestSuite

## GdUnit4 Test Suite for MultiTargetTracker (HUD-008 Component 1)
## Tests the central multi-target tracking and management system

# Test target scene and nodes
var tracker: MultiTargetTracker
var mock_targets: Array[Node] = []

func before_test():
	# Create tracker instance
	tracker = MultiTargetTracker.new()
	
	# Add to scene tree for proper initialization
	add_child(tracker)
	
	# Create mock targets for testing
	_create_mock_targets()

func after_test():
	# Clean up tracker
	if tracker:
		tracker.queue_free()
	
	# Clean up mock targets
	for target in mock_targets:
		if is_instance_valid(target):
			target.queue_free()
	mock_targets.clear()

func _create_mock_targets():
	# Create mock target nodes with required properties
	for i in range(5):
		var target = Node3D.new()
		target.name = "MockTarget_%d" % i
		target.global_position = Vector3(1000 * i, 0, 1000)
		
		# Add mock methods
		target.set_script(preload("res://tests/hud/multi_target_tracking/mock_target.gd"))
		target.setup_mock_target("fighter", "hostile", 0.5 + i * 0.1)
		
		add_child(target)
		mock_targets.append(target)

## Test tracker initialization
func test_tracker_initialization():
	assert_that(tracker).is_not_null()
	assert_that(tracker.is_tracking_active).is_true()
	assert_that(tracker.max_tracked_targets).is_equal(32)
	assert_that(tracker.active_tracks).is_empty()

## Test target addition
func test_add_target():
	var target = mock_targets[0]
	var track_id = tracker.add_target(target, 75)
	
	assert_that(track_id).is_greater(0)
	assert_that(tracker.active_tracks.has(track_id)).is_true()
	assert_that(tracker.active_tracks.size()).is_equal(1)
	
	var track = tracker.get_track(track_id)
	assert_that(track).is_not_null()
	assert_that(track.target_node).is_equal(target)
	assert_that(track.priority).is_equal(75)

## Test multiple target tracking
func test_multiple_target_tracking():
	var track_ids: Array[int] = []
	
	# Add multiple targets
	for i in range(3):
		var track_id = tracker.add_target(mock_targets[i], 50 + i * 10)
		track_ids.append(track_id)
	
	assert_that(tracker.active_tracks.size()).is_equal(3)
	
	# Verify all tracks exist
	for track_id in track_ids:
		assert_that(tracker.active_tracks.has(track_id)).is_true()

## Test tracking limit
func test_tracking_limit():
	# Set low limit for testing
	tracker.max_tracked_targets = 2
	
	# Add targets up to limit
	var track_id_1 = tracker.add_target(mock_targets[0], 50)
	var track_id_2 = tracker.add_target(mock_targets[1], 60)
	
	assert_that(track_id_1).is_greater(0)
	assert_that(track_id_2).is_greater(0)
	
	# Try to add beyond limit with low priority
	var track_id_3 = tracker.add_target(mock_targets[2], 40)
	assert_that(track_id_3).is_equal(-1)  # Should fail
	
	# Add beyond limit with high priority
	var track_id_4 = tracker.add_target(mock_targets[3], 80)
	assert_that(track_id_4).is_greater(0)  # Should succeed and replace lowest priority

## Test track removal
func test_remove_track():
	var track_id = tracker.add_target(mock_targets[0], 50)
	assert_that(tracker.active_tracks.has(track_id)).is_true()
	
	tracker.remove_track(track_id, "test_removal")
	assert_that(tracker.active_tracks.has(track_id)).is_false()

## Test track updates
func test_update_track():
	var target = mock_targets[0]
	var track_id = tracker.add_target(target, 50)
	
	var update_data = {
		"position": Vector3(2000, 0, 2000),
		"velocity": Vector3(100, 0, 50),
		"threat_level": 0.8
	}
	
	tracker.update_track(track_id, update_data)
	
	var track = tracker.get_track(track_id)
	assert_that(track.position).is_equal(Vector3(2000, 0, 2000))
	assert_that(track.threat_level).is_equal(0.8)

## Test priority management
func test_priority_management():
	# Add targets with different priorities
	var low_priority_id = tracker.add_target(mock_targets[0], 30)
	var high_priority_id = tracker.add_target(mock_targets[1], 80)
	var medium_priority_id = tracker.add_target(mock_targets[2], 55)
	
	var priority_tracks = tracker.get_priority_tracks(3)
	
	# Should be sorted by priority (highest first)
	assert_that(priority_tracks.size()).is_equal(3)
	assert_that(priority_tracks[0].priority).is_greater_equal(priority_tracks[1].priority)
	assert_that(priority_tracks[1].priority).is_greater_equal(priority_tracks[2].priority)

## Test filtered track retrieval
func test_get_filtered_tracks():
	# Add different types of targets
	var hostile_target = mock_targets[0]
	var friendly_target = mock_targets[1]
	
	# Set up target relationships
	hostile_target.relationship = "hostile"
	friendly_target.relationship = "friendly"
	
	tracker.add_target(hostile_target, 50)
	tracker.add_target(friendly_target, 50)
	
	var hostile_tracks = tracker.get_filtered_tracks(MultiTargetTracker.TrackingFilter.HOSTILE)
	var friendly_tracks = tracker.get_filtered_tracks(MultiTargetTracker.TrackingFilter.FRIENDLY)
	
	assert_that(hostile_tracks.size()).is_equal(1)
	assert_that(friendly_tracks.size()).is_equal(1)

## Test spatial partitioning
func test_spatial_partitioning():
	if not tracker.spatial_partitioning_enabled:
		return
	
	# Add targets at different positions
	var near_target = mock_targets[0]
	var far_target = mock_targets[1]
	
	near_target.global_position = Vector3(1000, 0, 1000)
	far_target.global_position = Vector3(20000, 0, 20000)
	
	tracker.add_target(near_target, 50)
	tracker.add_target(far_target, 50)
	
	# Test range-based retrieval
	var center_position = Vector3(0, 0, 0)
	var nearby_tracks = tracker.get_tracks_in_range(center_position, 5000.0)
	
	assert_that(nearby_tracks.size()).is_equal(1)
	assert_that(nearby_tracks[0].target_node).is_equal(near_target)

## Test tracking mode changes
func test_tracking_mode_changes():
	tracker.set_tracking_mode(MultiTargetTracker.TrackingMode.COMBAT)
	
	# Add target and verify combat mode effects
	var track_id = tracker.add_target(mock_targets[0], 50)
	var track = tracker.get_track(track_id)
	
	# Combat mode should have adjusted thresholds
	assert_that(tracker.tracking_config.quality_threshold).is_less_equal(0.3)

## Test performance under load
func test_performance_under_load():
	var start_time = Time.get_ticks_usec()
	
	# Add many targets quickly
	var track_ids: Array[int] = []
	for i in range(min(20, mock_targets.size())):
		if i < mock_targets.size():
			var track_id = tracker.add_target(mock_targets[i % mock_targets.size()], 50)
			if track_id > 0:
				track_ids.append(track_id)
	
	var end_time = Time.get_ticks_usec()
	var duration_ms = (end_time - start_time) / 1000.0
	
	# Should complete in reasonable time
	assert_that(duration_ms).is_less(100.0)  # Less than 100ms
	assert_that(track_ids.size()).is_greater(0)

## Test signal emissions
func test_signal_emissions():
	var signal_monitor = monitor_signals(tracker)
	
	# Add target and verify signals
	var track_id = tracker.add_target(mock_targets[0], 50)
	
	assert_signal(signal_monitor).signal_name("target_acquired").was_emitted()
	assert_signal(signal_monitor).signal_name("target_acquired").was_emitted_with_parameters(mock_targets[0], track_id)

## Test component integration
func test_component_integration():
	# Verify all components are initialized
	assert_that(tracker.target_priority_manager).is_not_null()
	assert_that(tracker.tracking_radar).is_not_null()
	assert_that(tracker.threat_assessment).is_not_null()
	assert_that(tracker.target_classification).is_not_null()
	assert_that(tracker.tracking_database).is_not_null()
	assert_that(tracker.situational_awareness).is_not_null()
	assert_that(tracker.target_handoff).is_not_null()

## Test track data retrieval
func test_get_all_track_data():
	# Add some targets
	tracker.add_target(mock_targets[0], 50)
	tracker.add_target(mock_targets[1], 60)
	
	var all_track_data = tracker.get_all_track_data()
	
	assert_that(all_track_data.size()).is_equal(2)
	
	for track_data in all_track_data:
		assert_that(track_data.has("track_id")).is_true()
		assert_that(track_data.has("target_name")).is_true()
		assert_that(track_data.has("threat_level")).is_true()
		assert_that(track_data.has("priority")).is_true()

## Test error handling
func test_error_handling():
	# Test null target
	var invalid_track_id = tracker.add_target(null, 50)
	assert_that(invalid_track_id).is_equal(-1)
	
	# Test invalid track update
	tracker.update_track(999, {})  # Should not crash
	
	# Test invalid track removal
	tracker.remove_track(999, "test")  # Should not crash

## Test tracking status
func test_tracking_status():
	var status = tracker.get_tracking_status()
	
	assert_that(status.has("is_active")).is_true()
	assert_that(status.has("tracking_mode")).is_true()
	assert_that(status.has("active_tracks")).is_true()
	assert_that(status.has("max_targets")).is_true()
	assert_that(status.has("tracking_range")).is_true()

## Test performance statistics
func test_performance_statistics():
	var stats = tracker.get_performance_stats()
	
	assert_that(stats.has("active_tracks")).is_true()
	assert_that(stats.has("tracks_per_frame_limit")).is_true()
	assert_that(stats.has("average_frame_time")).is_true()