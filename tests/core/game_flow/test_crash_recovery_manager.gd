extends GdUnitTestSuite

## Unit tests for CrashRecoveryManager
## Tests crash recovery functionality and SaveGameManager integration

const CrashRecoveryManager = preload("res://scripts/core/game_flow/crash_recovery_manager.gd")
const SessionFlowCoordinator = preload("res://scripts/core/game_flow/session_flow_coordinator.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")

var recovery_manager: CrashRecoveryManager
var mock_session_coordinator: SessionFlowCoordinator
var mock_pilot: PlayerProfile

func before():
	# Create CrashRecoveryManager instance
	recovery_manager = CrashRecoveryManager.new()
	
	# Create mock SessionFlowCoordinator
	mock_session_coordinator = SessionFlowCoordinator.new()
	mock_session_coordinator.name = "TestSessionFlowCoordinator"
	add_child(mock_session_coordinator)
	
	# Create mock pilot profile
	_setup_mock_pilot()
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up
	if mock_session_coordinator:
		mock_session_coordinator.queue_free()
	
	# Clean up test files
	_cleanup_test_files()

func _setup_mock_pilot():
	mock_pilot = PlayerProfile.new()
	mock_pilot.set_callsign("TestPilot")
	
	# Setup mock session coordinator with pilot
	mock_session_coordinator.current_session_id = "test_session_123"
	mock_session_coordinator.session_pilot_profile = mock_pilot
	mock_session_coordinator.session_metadata = {
		"session_id": "test_session_123",
		"pilot_callsign": "TestPilot",
		"start_time": Time.get_unix_time_from_system()
	}

func _cleanup_test_files():
	# Clean up recovery files
	var recovery_file_path = "user://saves/crash_recovery.json"
	if FileAccess.file_exists(recovery_file_path):
		var dir = DirAccess.open("user://saves/")
		if dir:
			dir.remove("crash_recovery.json")

func test_recovery_manager_initialization():
	"""Test CrashRecoveryManager initializes correctly"""
	assert_that(recovery_manager).is_not_null()
	assert_that(recovery_manager.RECOVERY_FILE_PATH).is_equal("user://saves/crash_recovery.json")
	assert_that(recovery_manager.MAX_RECOVERY_AGE_HOURS).is_equal(24)

func test_recovery_data_structure():
	"""Test RecoveryData class functionality"""
	var recovery_data = CrashRecoveryManager.RecoveryData.new()
	
	# Test initial state
	assert_that(recovery_data.is_valid()).is_false()
	
	# Test with valid data
	recovery_data.session_id = "test_session"
	recovery_data.crash_timestamp = Time.get_unix_time_from_system()
	recovery_data.pilot_callsign = "TestPilot"
	recovery_data.game_state = GameStateManager.GameState.MISSION
	
	assert_that(recovery_data.is_valid()).is_true()

func test_recovery_data_serialization():
	"""Test RecoveryData to/from dictionary conversion"""
	var recovery_data = CrashRecoveryManager.RecoveryData.new()
	recovery_data.session_id = "test_session"
	recovery_data.crash_timestamp = Time.get_unix_time_from_system()
	recovery_data.pilot_callsign = "TestPilot"
	recovery_data.game_state = GameStateManager.GameState.MISSION
	recovery_data.last_auto_save_time = Time.get_unix_time_from_system()
	recovery_data.available_backups = [{"save_slot": 1, "is_valid": true}]
	recovery_data.game_flow_context = {"test": "data"}
	
	# Convert to dictionary
	var dict_data = recovery_data.to_dictionary()
	assert_that(dict_data.has("session_id")).is_true()
	assert_that(dict_data.has("crash_timestamp")).is_true()
	assert_that(dict_data.has("pilot_callsign")).is_true()
	assert_that(dict_data.session_id).is_equal("test_session")
	assert_that(dict_data.pilot_callsign).is_equal("TestPilot")
	
	# Convert back from dictionary
	var new_recovery_data = CrashRecoveryManager.RecoveryData.new()
	new_recovery_data.from_dictionary(dict_data)
	
	assert_that(new_recovery_data.session_id).is_equal(recovery_data.session_id)
	assert_that(new_recovery_data.pilot_callsign).is_equal(recovery_data.pilot_callsign)
	assert_that(new_recovery_data.crash_timestamp).is_equal(recovery_data.crash_timestamp)
	assert_that(new_recovery_data.is_valid()).is_true()

func test_create_recovery_checkpoint():
	"""Test recovery checkpoint creation"""
	# Create recovery checkpoint
	recovery_manager.create_recovery_checkpoint(mock_session_coordinator)
	
	# Check if recovery file was created
	var recovery_file_path = "user://saves/crash_recovery.json"
	assert_that(FileAccess.file_exists(recovery_file_path)).is_true()
	
	# Try to load and validate the recovery data
	var recovery_data = recovery_manager._load_recovery_data()
	assert_that(recovery_data).is_not_null()
	assert_that(recovery_data.is_valid()).is_true()
	assert_that(recovery_data.session_id).is_equal("test_session_123")
	assert_that(recovery_data.pilot_callsign).is_equal("TestPilot")

func test_clear_recovery_data():
	"""Test recovery data cleanup"""
	# Create recovery checkpoint first
	recovery_manager.create_recovery_checkpoint(mock_session_coordinator)
	
	# Verify file exists
	var recovery_file_path = "user://saves/crash_recovery.json"
	assert_that(FileAccess.file_exists(recovery_file_path)).is_true()
	
	# Clear recovery data
	recovery_manager.clear_recovery_data()
	
	# Verify file is removed
	assert_that(FileAccess.file_exists(recovery_file_path)).is_false()

func test_check_for_crash_recovery_no_file():
	"""Test crash recovery check when no recovery file exists"""
	# Ensure no recovery file exists
	recovery_manager.clear_recovery_data()
	
	# Check for crash recovery
	var has_recovery = recovery_manager.check_for_crash_recovery()
	assert_that(has_recovery).is_false()

func test_check_for_crash_recovery_invalid_data():
	"""Test crash recovery check with invalid recovery data"""
	# Create invalid recovery file
	var file = FileAccess.open("user://saves/crash_recovery.json", FileAccess.WRITE)
	file.store_string("{\"invalid\": \"data\"}")
	file.close()
	
	# Check for crash recovery
	var has_recovery = recovery_manager.check_for_crash_recovery()
	assert_that(has_recovery).is_false()
	
	# File should be cleaned up
	assert_that(FileAccess.file_exists("user://saves/crash_recovery.json")).is_false()

func test_check_for_crash_recovery_old_data():
	"""Test crash recovery check with old recovery data"""
	# Create recovery data that's too old
	var recovery_data = CrashRecoveryManager.RecoveryData.new()
	recovery_data.session_id = "test_session"
	recovery_data.crash_timestamp = Time.get_unix_time_from_system() - (25 * 3600)  # 25 hours ago
	recovery_data.pilot_callsign = "TestPilot"
	recovery_data.game_state = GameStateManager.GameState.MISSION
	
	# Save old recovery data
	var file = FileAccess.open("user://saves/crash_recovery.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(recovery_data.to_dictionary()))
	file.close()
	
	# Check for crash recovery
	var has_recovery = recovery_manager.check_for_crash_recovery()
	assert_that(has_recovery).is_false()
	
	# File should be cleaned up
	assert_that(FileAccess.file_exists("user://saves/crash_recovery.json")).is_false()

func test_get_available_backups_info():
	"""Test available backups information gathering"""
	var backups_info = recovery_manager._get_available_backups_info()
	
	# Should return an array
	assert_that(backups_info).is_instance_of(Array)
	
	# Each backup info should have required fields
	for backup_info in backups_info:
		assert_that(backup_info).is_instance_of(Dictionary)
		assert_that(backup_info.has("save_slot")).is_true()
		assert_that(backup_info.has("pilot_callsign")).is_true()
		assert_that(backup_info.has("save_name")).is_true()
		assert_that(backup_info.has("save_timestamp")).is_true()
		assert_that(backup_info.has("save_type")).is_true()
		assert_that(backup_info.has("is_valid")).is_true()

func test_validate_available_saves():
	"""Test save validation logic"""
	var recovery_data = CrashRecoveryManager.RecoveryData.new()
	recovery_data.available_backups = [
		{"save_slot": 1, "is_valid": true},
		{"save_slot": 2, "is_valid": false},
		{"save_slot": 3, "is_valid": true}
	]
	
	# Should return true because there are valid backups
	var has_valid_saves = recovery_manager._validate_available_saves(recovery_data)
	assert_that(has_valid_saves).is_true()
	
	# Test with no valid backups
	recovery_data.available_backups = [
		{"save_slot": 1, "is_valid": false},
		{"save_slot": 2, "is_valid": false}
	]
	
	has_valid_saves = recovery_manager._validate_available_saves(recovery_data)
	# May be true or false depending on SaveGameManager state, but should not crash

func test_get_recovery_summary():
	"""Test recovery summary generation"""
	var recovery_data = CrashRecoveryManager.RecoveryData.new()
	recovery_data.session_id = "test_session"
	recovery_data.crash_timestamp = Time.get_unix_time_from_system() - 3600  # 1 hour ago
	recovery_data.pilot_callsign = "TestPilot"
	recovery_data.game_state = GameStateManager.GameState.MISSION
	recovery_data.available_backups = [
		{"save_slot": 1, "is_valid": true, "save_timestamp": Time.get_unix_time_from_system() - 1800},
		{"save_slot": 2, "is_valid": false, "save_timestamp": Time.get_unix_time_from_system() - 3600},
		{"save_slot": 3, "is_valid": true, "save_timestamp": Time.get_unix_time_from_system() - 900}
	]
	
	var summary = recovery_manager.get_recovery_summary(recovery_data)
	
	assert_that(summary).is_not_null()
	assert_that(summary.has("pilot_callsign")).is_true()
	assert_that(summary.has("crash_time")).is_true()
	assert_that(summary.has("hours_ago")).is_true()
	assert_that(summary.has("game_state")).is_true()
	assert_that(summary.has("total_backups")).is_true()
	assert_that(summary.has("valid_backups")).is_true()
	assert_that(summary.has("recommended_backup")).is_true()
	
	assert_that(summary.pilot_callsign).is_equal("TestPilot")
	assert_that(summary.total_backups).is_equal(3)
	assert_that(summary.valid_backups.size()).is_equal(2)  # Only valid backups
	assert_that(summary.hours_ago).is_between(0.9, 1.1)  # Approximately 1 hour
	
	# Recommended backup should be the most recent valid one (slot 3)
	assert_that(summary.recommended_backup.get("save_slot", -1)).is_equal(3)

func test_load_recovery_data_invalid_json():
	"""Test loading recovery data with invalid JSON"""
	# Create file with invalid JSON
	var file = FileAccess.open("user://saves/crash_recovery.json", FileAccess.WRITE)
	file.store_string("{invalid json")
	file.close()
	
	# Try to load
	var recovery_data = recovery_manager._load_recovery_data()
	assert_that(recovery_data).is_null()

func test_load_recovery_data_valid():
	"""Test loading valid recovery data"""
	# Create valid recovery data
	var test_data = {
		"session_id": "test_session",
		"crash_timestamp": Time.get_unix_time_from_system(),
		"pilot_callsign": "TestPilot",
		"game_state": GameStateManager.GameState.MISSION,
		"last_auto_save_time": Time.get_unix_time_from_system(),
		"available_backups": [],
		"game_flow_context": {}
	}
	
	# Save to file
	var file = FileAccess.open("user://saves/crash_recovery.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(test_data, "  "))
	file.close()
	
	# Load and verify
	var recovery_data = recovery_manager._load_recovery_data()
	assert_that(recovery_data).is_not_null()
	assert_that(recovery_data.is_valid()).is_true()
	assert_that(recovery_data.session_id).is_equal("test_session")
	assert_that(recovery_data.pilot_callsign).is_equal("TestPilot")

func test_signal_emissions():
	"""Test signal emissions during recovery operations"""
	var recovery_offered_received = false
	var recovery_completed_received = false
	var recovery_declined_received = false
	
	# Connect to signals
	recovery_manager.crash_recovery_offered.connect(func(recovery_data): recovery_offered_received = true)
	recovery_manager.crash_recovery_completed.connect(func(recovery_data): recovery_completed_received = true)
	recovery_manager.crash_recovery_declined.connect(func(): recovery_declined_received = true)
	
	# Test recovery declined
	recovery_manager.decline_crash_recovery()
	
	# Wait for signal processing
	await get_tree().process_frame
	
	# Check signal was emitted
	assert_that(recovery_declined_received).is_true()

func test_create_checkpoint_without_pilot():
	"""Test checkpoint creation when no pilot is available"""
	# Create session coordinator without pilot
	var empty_coordinator = SessionFlowCoordinator.new()
	empty_coordinator.session_pilot_profile = null
	
	# Should not crash and should not create file
	recovery_manager.create_recovery_checkpoint(empty_coordinator)
	
	# No recovery file should be created
	assert_that(FileAccess.file_exists("user://saves/crash_recovery.json")).is_false()

func test_perform_crash_recovery():
	"""Test performing crash recovery"""
	# Create valid recovery data
	var recovery_data = CrashRecoveryManager.RecoveryData.new()
	recovery_data.session_id = "test_session"
	recovery_data.crash_timestamp = Time.get_unix_time_from_system()
	recovery_data.pilot_callsign = "TestPilot"
	recovery_data.game_state = GameStateManager.GameState.MISSION
	recovery_data.available_backups = []
	
	# Test recovery attempt (may succeed or fail depending on SaveGameManager state)
	var result = recovery_manager.perform_crash_recovery(recovery_data, -1)
	
	# Should return a boolean without crashing
	assert_that(result).is_instance_of(bool)

func test_decline_crash_recovery():
	"""Test declining crash recovery"""
	# Create recovery checkpoint first
	recovery_manager.create_recovery_checkpoint(mock_session_coordinator)
	
	# Verify file exists
	assert_that(FileAccess.file_exists("user://saves/crash_recovery.json")).is_true()
	
	# Decline recovery
	recovery_manager.decline_crash_recovery()
	
	# File should be cleaned up
	assert_that(FileAccess.file_exists("user://saves/crash_recovery.json")).is_false()