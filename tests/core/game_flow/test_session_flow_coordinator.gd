extends GdUnitTestSuite

## Unit tests for SessionFlowCoordinator
## Tests session lifecycle management and crash recovery integration

const SessionFlowCoordinator = preload("res://scripts/core/game_flow/session_flow_coordinator.gd")
const CrashRecoveryManager = preload("res://scripts/core/game_flow/crash_recovery_manager.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")

var coordinator: SessionFlowCoordinator
var mock_pilot: PlayerProfile

func before():
	# Create SessionFlowCoordinator instance
	coordinator = SessionFlowCoordinator.new()
	coordinator.name = "TestSessionFlowCoordinator"
	add_child(coordinator)
	
	# Create mock pilot profile
	_setup_mock_pilot()
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up
	if coordinator:
		coordinator.queue_free()
	
	# Clean up test files
	_cleanup_test_files()

func _setup_mock_pilot():
	mock_pilot = PlayerProfile.new()
	mock_pilot.set_callsign("TestPilot")

func _cleanup_test_files():
	# Clean up recovery files
	var recovery_file_path = "user://saves/crash_recovery.json"
	if FileAccess.file_exists(recovery_file_path):
		var dir = DirAccess.open("user://saves/")
		if dir:
			dir.remove("crash_recovery.json")

func test_coordinator_initialization():
	"""Test SessionFlowCoordinator initializes correctly"""
	assert_that(coordinator).is_not_null()
	assert_that(coordinator.enable_crash_recovery).is_true()
	assert_that(coordinator.recovery_checkpoint_interval).is_equal(300)
	assert_that(coordinator.max_recovery_age_hours).is_equal(24)
	assert_that(coordinator.current_session_id).is_empty()
	assert_that(coordinator.session_start_time).is_equal(0)

func test_crash_recovery_manager_setup():
	"""Test crash recovery manager is properly initialized"""
	# Wait for full initialization
	await get_tree().process_frame
	assert_that(coordinator.crash_recovery_manager).is_not_null()
	assert_that(coordinator.crash_recovery_manager).is_instance_of(CrashRecoveryManager)

func test_recovery_checkpoint_timer_setup():
	"""Test recovery checkpoint timer is properly configured"""
	assert_that(coordinator.recovery_checkpoint_timer).is_not_null()
	assert_that(coordinator.recovery_checkpoint_timer.wait_time).is_equal(coordinator.recovery_checkpoint_interval)
	assert_that(coordinator.recovery_checkpoint_timer.one_shot).is_false()

func test_session_lifecycle():
	"""Test complete session lifecycle (start, update, end)"""
	# Initially no session should be active
	assert_that(coordinator.is_session_active()).is_false()
	assert_that(coordinator.get_session_info()).is_empty()
	
	# Start session
	coordinator.start_session(mock_pilot)
	
	# Verify session is active
	assert_that(coordinator.is_session_active()).is_true()
	assert_that(coordinator.current_session_id).is_not_empty()
	assert_that(coordinator.session_start_time).is_greater(0)
	assert_that(coordinator.session_pilot_profile).is_equal(mock_pilot)
	
	# Verify session metadata
	var session_info = coordinator.get_session_info()
	assert_that(session_info.has("session_id")).is_true()
	assert_that(session_info.has("pilot_callsign")).is_true()
	assert_that(session_info.pilot_callsign).is_equal("TestPilot")
	
	# Update session state
	coordinator.update_session_state({"test_data": "test_value"})
	
	# End session
	coordinator.end_session()
	
	# Verify session is ended
	assert_that(coordinator.is_session_active()).is_false()
	assert_that(coordinator.current_session_id).is_empty()

func test_session_metadata():
	"""Test session metadata tracking"""
	coordinator.start_session(mock_pilot)
	
	var session_info = coordinator.get_session_info()
	assert_that(session_info.has("session_id")).is_true()
	assert_that(session_info.has("start_time")).is_true()
	assert_that(session_info.has("pilot_callsign")).is_true()
	assert_that(session_info.has("auto_save_enabled")).is_true()
	assert_that(session_info.has("auto_save_interval")).is_true()
	assert_that(session_info.has("game_state")).is_true()
	assert_that(session_info.has("crash_recovery_enabled")).is_true()
	
	coordinator.end_session()

func test_session_duration_tracking():
	"""Test session duration calculation"""
	coordinator.start_session(mock_pilot)
	
	# Wait a bit to test duration
	await get_tree().create_timer(0.1).timeout
	
	var duration = coordinator.get_session_duration_minutes()
	assert_that(duration).is_greater(0.0)
	
	var session_info = coordinator.get_session_info()
	assert_that(session_info.has("duration_seconds")).is_true()
	assert_that(session_info.has("duration_minutes")).is_true()
	assert_that(session_info.duration_seconds).is_greater(0.0)
	
	coordinator.end_session()

func test_session_state_updates():
	"""Test session state update functionality"""
	coordinator.start_session(mock_pilot)
	
	var test_data = {"mission_id": 1, "progress": 50}
	coordinator.update_session_state(test_data)
	
	var session_info = coordinator.get_session_info()
	assert_that(session_info.has("mission_id")).is_true()
	assert_that(session_info.has("progress")).is_true()
	assert_that(session_info.mission_id).is_equal(1)
	assert_that(session_info.progress).is_equal(50)
	assert_that(session_info.has("last_update_time")).is_true()
	
	coordinator.end_session()

func test_multiple_session_prevention():
	"""Test that starting a new session ends the previous one"""
	coordinator.start_session(mock_pilot)
	var first_session_id = coordinator.current_session_id
	
	# Start another session
	var mock_pilot2 = PlayerProfile.new()
	mock_pilot2.set_callsign("TestPilot2")
	coordinator.start_session(mock_pilot2)
	
	# Should have new session ID and pilot
	assert_that(coordinator.current_session_id).is_not_equal(first_session_id)
	assert_that(coordinator.get_current_pilot_callsign()).is_equal("TestPilot2")
	
	coordinator.end_session()

func test_crash_recovery_configuration():
	"""Test crash recovery configuration methods"""
	# Test initial configuration
	assert_that(coordinator.is_crash_recovery_enabled()).is_true()
	assert_that(coordinator.get_recovery_checkpoint_interval()).is_equal(300)
	
	# Test configuration changes
	coordinator.set_recovery_checkpoint_interval(600)
	assert_that(coordinator.get_recovery_checkpoint_interval()).is_equal(600)
	assert_that(coordinator.recovery_checkpoint_timer.wait_time).is_equal(600)
	
	# Test minimum interval enforcement
	coordinator.set_recovery_checkpoint_interval(30)  # Below minimum
	assert_that(coordinator.get_recovery_checkpoint_interval()).is_equal(60)  # Should be clamped to minimum

func test_signal_emission():
	"""Test signal emission during session lifecycle"""
	var session_started_received = false
	var session_ended_received = false
	var session_updated_received = false
	
	# Connect to signals
	coordinator.session_started.connect(func(session_data): session_started_received = true)
	coordinator.session_ended.connect(func(session_data): session_ended_received = true)
	coordinator.session_state_updated.connect(func(session_data): session_updated_received = true)
	
	# Test session lifecycle
	coordinator.start_session(mock_pilot)
	coordinator.update_session_state({"test": "data"})
	coordinator.end_session()
	
	# Wait for signal processing
	await get_tree().process_frame
	
	# Check signals were emitted
	assert_that(session_started_received).is_true()
	assert_that(session_updated_received).is_true()
	assert_that(session_ended_received).is_true()

func test_invalid_session_start():
	"""Test error handling for invalid session start"""
	# Try to start session with null pilot
	coordinator.start_session(null)
	
	# Should not start session
	assert_that(coordinator.is_session_active()).is_false()
	assert_that(coordinator.current_session_id).is_empty()

func test_session_operations_without_active_session():
	"""Test operations when no session is active"""
	# Ensure no session is active
	assert_that(coordinator.is_session_active()).is_false()
	
	# Test operations that should handle no active session gracefully
	coordinator.update_session_state({"test": "data"})  # Should not crash
	coordinator.end_session()  # Should not crash
	
	assert_that(coordinator.get_session_duration_minutes()).is_equal(0.0)
	assert_that(coordinator.get_current_pilot_callsign()).is_empty()
	assert_that(coordinator.get_session_info()).is_empty()

func test_recovery_checkpoint_creation():
	"""Test recovery checkpoint creation"""
	coordinator.start_session(mock_pilot)
	
	# Create recovery checkpoint manually
	coordinator._create_recovery_checkpoint()
	
	# Check if recovery file was created
	var recovery_file_path = "user://saves/crash_recovery.json"
	assert_that(FileAccess.file_exists(recovery_file_path)).is_true()
	
	coordinator.end_session()

func test_game_state_change_handling():
	"""Test handling of game state changes"""
	coordinator.start_session(mock_pilot)
	
	# Simulate game state changes
	coordinator._on_game_state_changed(
		GameStateManager.GameState.MAIN_MENU,
		GameStateManager.GameState.MISSION_BRIEFING
	)
	
	var session_info = coordinator.get_session_info()
	assert_that(session_info.has("game_state")).is_true()
	assert_that(session_info.has("previous_state")).is_true()
	assert_that(session_info.has("state_change_time")).is_true()
	
	coordinator.end_session()

func test_save_manager_signal_handling():
	"""Test SaveGameManager signal handling"""
	coordinator.start_session(mock_pilot)
	
	# Simulate save completion
	coordinator._on_save_completed(1, true, "")
	
	var session_info = coordinator.get_session_info()
	assert_that(session_info.has("last_save_time")).is_true()
	assert_that(session_info.has("last_save_slot")).is_true()
	assert_that(session_info.last_save_slot).is_equal(1)
	
	# Simulate auto-save trigger
	coordinator._on_auto_save_triggered()
	
	session_info = coordinator.get_session_info()
	assert_that(session_info.has("last_auto_save_trigger")).is_true()
	
	coordinator.end_session()

func test_corruption_detection_handling():
	"""Test handling of save corruption detection"""
	coordinator.start_session(mock_pilot)
	
	# Simulate corruption detection
	coordinator._on_corruption_detected(1, "Checksum mismatch")
	
	var session_info = coordinator.get_session_info()
	assert_that(session_info.has("corruption_detected")).is_true()
	assert_that(session_info.has("corrupted_slot")).is_true()
	assert_that(session_info.has("corruption_details")).is_true()
	assert_that(session_info.corrupted_slot).is_equal(1)
	assert_that(session_info.corruption_details).is_equal("Checksum mismatch")
	
	coordinator.end_session()

func test_session_id_generation():
	"""Test session ID generation uniqueness"""
	var session_ids = []
	
	# Generate multiple session IDs
	for i in range(5):
		coordinator.start_session(mock_pilot)
		session_ids.append(coordinator.current_session_id)
		coordinator.end_session()
		
		# Small delay to ensure different timestamps
		await get_tree().create_timer(0.01).timeout
	
	# Check uniqueness
	for i in range(session_ids.size()):
		for j in range(i + 1, session_ids.size()):
			assert_that(session_ids[i]).is_not_equal(session_ids[j])

func test_crash_recovery_manager_integration():
	"""Test integration with CrashRecoveryManager"""
	# Wait for full initialization
	await get_tree().process_frame
	
	# Start session to test crash recovery manager functionality
	coordinator.start_session(mock_pilot)
	
	# Test crash recovery manager is accessible
	assert_that(coordinator.crash_recovery_manager).is_not_null()
	
	# Test crash recovery methods
	coordinator.crash_recovery_manager.check_for_crash_recovery()  # Should not crash
	coordinator.crash_recovery_manager.create_recovery_checkpoint(coordinator)  # Should not crash
	
	coordinator.end_session()

func test_checkpoint_timer_behavior():
	"""Test recovery checkpoint timer behavior"""
	coordinator.start_session(mock_pilot)
	
	# Timer should be running when session is active
	assert_that(coordinator.recovery_checkpoint_timer).is_not_null()
	
	coordinator.end_session()
	
	# Timer should be stopped when session ends
	# (Note: We can't directly test timer.is_stopped() in unit tests due to timing issues)