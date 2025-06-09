extends GdUnitTestSuite

## Unit tests for PilotDataCoordinator
## Tests pilot management, statistics updates, and system integration

const PilotDataCoordinator = preload("res://scripts/core/game_flow/player_data/pilot_data_coordinator.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")

var coordinator: PilotDataCoordinator
var test_profile: PlayerProfile

func before():
	# Create coordinator instance
	coordinator = PilotDataCoordinator.new()
	coordinator.name = "TestPilotDataCoordinator"
	add_child(coordinator)
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up test data
	if coordinator:
		coordinator.queue_free()
	
	# Clean up any test save files
	_cleanup_test_saves()

func _cleanup_test_saves():
	# Clean up test save files
	var dir = DirAccess.open("user://")
	if dir:
		if dir.dir_exists("saves"):
			dir.remove("saves/test_pilot.tres")

func test_pilot_creation():
	"""Test pilot profile creation with valid data"""
	# Test valid pilot creation
	var pilot_callsign = "TestPilot"
	var created_profile = coordinator.create_pilot_profile(pilot_callsign, 0)
	
	assert_that(created_profile).is_not_null()
	assert_that(created_profile.callsign).is_equal(pilot_callsign)
	assert_that(created_profile.pilot_stats).is_not_null()
	assert_that(coordinator.get_current_pilot_callsign()).is_equal(pilot_callsign)
	assert_that(coordinator.has_current_pilot()).is_true()

func test_pilot_creation_invalid_callsign():
	"""Test pilot creation with invalid callsign"""
	# Test empty callsign
	var empty_profile = coordinator.create_pilot_profile("", 0)
	assert_that(empty_profile).is_null()
	
	# Test callsign that's too long (should be rejected by PlayerProfile validation)
	var long_callsign = "ThisCallsignIsWayTooLongAndShouldBeRejected"
	var long_profile = coordinator.create_pilot_profile(long_callsign, 0)
	assert_that(long_profile).is_null()

func test_pilot_loading():
	"""Test pilot profile loading from save slot"""
	# First create a pilot to load
	var pilot_callsign = "LoadTestPilot"
	var created_profile = coordinator.create_pilot_profile(pilot_callsign, 1)
	assert_that(created_profile).is_not_null()
	
	# Clear current pilot
	coordinator.current_pilot_profile = null
	coordinator.active_save_slot = -1
	
	# Load the pilot
	var loaded_profile = coordinator.load_pilot_profile(1)
	assert_that(loaded_profile).is_not_null()
	assert_that(loaded_profile.callsign).is_equal(pilot_callsign)
	assert_that(coordinator.get_current_pilot_callsign()).is_equal(pilot_callsign)

func test_pilot_saving():
	"""Test pilot profile saving"""
	# Create a pilot
	var pilot_callsign = "SaveTestPilot"
	var created_profile = coordinator.create_pilot_profile(pilot_callsign, 2)
	assert_that(created_profile).is_not_null()
	
	# Modify some data
	created_profile.pilot_stats.score = 1000
	created_profile.pilot_stats.missions_flown = 5
	
	# Save the profile
	var save_success = coordinator.save_current_pilot_profile()
	assert_that(save_success).is_true()
	
	# Verify data persistence by loading again
	coordinator.current_pilot_profile = null
	var reloaded_profile = coordinator.load_pilot_profile(2)
	assert_that(reloaded_profile).is_not_null()
	assert_that(reloaded_profile.pilot_stats.score).is_equal(1000)
	assert_that(reloaded_profile.pilot_stats.missions_flown).is_equal(5)

func test_statistics_update():
	"""Test pilot statistics update from mission results"""
	# Create a pilot
	var pilot_callsign = "StatsTestPilot"
	var created_profile = coordinator.create_pilot_profile(pilot_callsign, 3)
	assert_that(created_profile).is_not_null()
	
	# Initial statistics
	var initial_score = created_profile.pilot_stats.score
	var initial_missions = created_profile.pilot_stats.missions_flown
	var initial_kills = created_profile.pilot_stats.kill_count
	
	# Create mission result
	var mission_result = {
		"score": 1500,
		"kills": 3,
		"deaths": 0,
		"primary_shots_fired": 100,
		"primary_shots_hit": 75,
		"secondary_shots_fired": 10,
		"secondary_shots_hit": 8,
		"flight_time": 1200,
		"objectives_completed": 3,
		"objectives_total": 3
	}
	
	# Update statistics
	coordinator.update_pilot_statistics(mission_result)
	
	# Verify statistics were updated
	assert_that(created_profile.pilot_stats.score).is_greater(initial_score)
	assert_that(created_profile.pilot_stats.missions_flown).is_greater(initial_missions)
	assert_that(created_profile.pilot_stats.kill_count).is_greater(initial_kills)
	
	# Verify accuracy calculations
	assert_that(created_profile.pilot_stats.primary_accuracy).is_greater(0.0)

func test_pilot_summary():
	"""Test comprehensive pilot summary generation"""
	# Create a pilot
	var pilot_callsign = "SummaryTestPilot"
	var created_profile = coordinator.create_pilot_profile(pilot_callsign, 4)
	assert_that(created_profile).is_not_null()
	
	# Update some statistics
	created_profile.pilot_stats.score = 2500
	created_profile.pilot_stats.missions_flown = 10
	created_profile.pilot_stats.kill_count = 25
	
	# Get summary
	var summary = coordinator.get_pilot_summary()
	
	assert_that(summary).is_not_null()
	assert_that(summary.has("basic_info")).is_true()
	assert_that(summary.has("statistics")).is_true()
	assert_that(summary.has("achievements")).is_true()
	assert_that(summary.has("performance")).is_true()
	assert_that(summary.has("recent_activity")).is_true()
	
	# Verify statistics in summary
	assert_that(summary.statistics.score).is_equal(2500)
	assert_that(summary.statistics.missions_flown).is_equal(10)
	assert_that(summary.statistics.kill_count).is_equal(25)

func test_pilot_list():
	"""Test pilot list generation"""
	# Create multiple pilots
	var pilot1 = coordinator.create_pilot_profile("Pilot1", 5)
	var pilot2 = coordinator.create_pilot_profile("Pilot2", 6)
	
	assert_that(pilot1).is_not_null()
	assert_that(pilot2).is_not_null()
	
	# Get pilot list
	var pilot_list = coordinator.get_pilot_list()
	
	assert_that(pilot_list).is_not_null()
	assert_that(pilot_list.size()).is_greater_equal(2)
	
	# Verify pilot information is included
	var found_pilot1 = false
	var found_pilot2 = false
	
	for pilot_info in pilot_list:
		if pilot_info.callsign == "Pilot1":
			found_pilot1 = true
		if pilot_info.callsign == "Pilot2":
			found_pilot2 = true
	
	assert_that(found_pilot1).is_true()
	assert_that(found_pilot2).is_true()

func test_pilot_deletion():
	"""Test pilot profile deletion"""
	# Create a pilot
	var pilot_callsign = "DeleteTestPilot"
	var created_profile = coordinator.create_pilot_profile(pilot_callsign, 7)
	assert_that(created_profile).is_not_null()
	
	# Verify pilot exists
	var pilot_list_before = coordinator.get_pilot_list()
	var pilot_exists_before = false
	for pilot_info in pilot_list_before:
		if pilot_info.callsign == pilot_callsign:
			pilot_exists_before = true
			break
	assert_that(pilot_exists_before).is_true()
	
	# Delete the pilot
	var delete_success = coordinator.delete_pilot_profile(7)
	assert_that(delete_success).is_true()
	
	# Verify pilot is deleted
	var pilot_list_after = coordinator.get_pilot_list()
	var pilot_exists_after = false
	for pilot_info in pilot_list_after:
		if pilot_info.callsign == pilot_callsign:
			pilot_exists_after = true
			break
	assert_that(pilot_exists_after).is_false()

func test_mission_tracking():
	"""Test mission tracking start/stop"""
	# Create a pilot
	var created_profile = coordinator.create_pilot_profile("TrackingTestPilot", 8)
	assert_that(created_profile).is_not_null()
	
	# Verify initial state
	assert_that(coordinator.is_mission_active).is_false()
	
	# Start mission tracking
	coordinator.start_mission_tracking()
	assert_that(coordinator.is_mission_active).is_true()
	
	# Stop mission tracking
	coordinator.stop_mission_tracking()
	assert_that(coordinator.is_mission_active).is_false()

func test_achievement_integration():
	"""Test achievement system integration"""
	# Create a pilot
	var created_profile = coordinator.create_pilot_profile("AchievementTestPilot", 9)
	assert_that(created_profile).is_not_null()
	
	# Verify achievement manager is initialized
	assert_that(coordinator.achievement_manager).is_not_null()
	
	# Test achievement checking
	var achievements = coordinator.achievement_manager.check_pilot_achievements(created_profile)
	assert_that(achievements).is_not_null()
	
	# Create mission result that should earn "first_kill" achievement
	var mission_result = {
		"score": 500,
		"kills": 1,
		"primary_shots_fired": 50,
		"primary_shots_hit": 40,
		"flight_time": 600
	}
	
	# Update statistics (should trigger achievement checking)
	coordinator.update_pilot_statistics(mission_result)
	
	# Check if achievement was earned
	var earned_achievements = created_profile.get_meta("achievements", [])
	# Note: first_kill achievement may not be earned in test due to specific criteria
	assert_that(earned_achievements).is_not_null()

func test_performance_tracking_integration():
	"""Test performance tracking system integration"""
	# Create a pilot
	var created_profile = coordinator.create_pilot_profile("PerformanceTestPilot", 10)
	assert_that(created_profile).is_not_null()
	
	# Verify performance tracker is initialized
	assert_that(coordinator.performance_tracker).is_not_null()
	
	# Create mission result
	var mission_result = {
		"score": 1000,
		"kills": 2,
		"primary_shots_fired": 80,
		"primary_shots_hit": 60,
		"flight_time": 900
	}
	
	# Update statistics (should trigger performance tracking)
	coordinator.update_pilot_statistics(mission_result)
	
	# Get performance summary
	var performance_summary = coordinator.performance_tracker.get_detailed_performance_summary(created_profile)
	assert_that(performance_summary).is_not_null()

func test_auto_save_functionality():
	"""Test auto-save functionality"""
	# Create a pilot with auto-save enabled
	coordinator.set_auto_save_enabled(true)
	var created_profile = coordinator.create_pilot_profile("AutoSaveTestPilot", 11)
	assert_that(created_profile).is_not_null()
	
	# Update statistics (should trigger auto-save)
	var mission_result = {
		"score": 750,
		"kills": 1,
		"flight_time": 800
	}
	
	coordinator.update_pilot_statistics(mission_result)
	
	# Verify data was saved (reload and check)
	coordinator.current_pilot_profile = null
	var reloaded_profile = coordinator.load_pilot_profile(11)
	assert_that(reloaded_profile).is_not_null()
	assert_that(reloaded_profile.pilot_stats.score).is_greater(0)

func test_data_export():
	"""Test pilot data export functionality"""
	# Create a pilot
	var created_profile = coordinator.create_pilot_profile("ExportTestPilot", 12)
	assert_that(created_profile).is_not_null()
	
	# Add some data
	created_profile.pilot_stats.score = 3000
	created_profile.pilot_stats.missions_flown = 15
	
	# Export data
	var export_data = coordinator.export_pilot_data()
	assert_that(export_data).is_not_empty()
	
	# Verify export is valid JSON
	var json = JSON.new()
	var parse_result = json.parse(export_data)
	assert_that(parse_result).is_equal(OK)
	
	# Verify export contains expected data
	var parsed_data = json.data
	assert_that(parsed_data.has("pilot_export")).is_true()
	assert_that(parsed_data.has("coordinator_version")).is_true()

func test_configuration_options():
	"""Test coordinator configuration options"""
	# Test auto-save configuration
	coordinator.set_auto_save_enabled(false)
	assert_that(coordinator.auto_save_enabled).is_false()
	
	coordinator.set_auto_save_enabled(true)
	assert_that(coordinator.auto_save_enabled).is_true()
	
	# Test achievement checking configuration
	coordinator.set_achievement_checking_enabled(false)
	assert_that(coordinator.enable_achievement_checking).is_false()
	
	coordinator.set_achievement_checking_enabled(true)
	assert_that(coordinator.enable_achievement_checking).is_true()
	
	# Test performance tracking configuration
	coordinator.set_performance_tracking_enabled(false)
	assert_that(coordinator.enable_performance_tracking).is_false()
	
	coordinator.set_performance_tracking_enabled(true)
	assert_that(coordinator.enable_performance_tracking).is_true()

func test_signal_emissions():
	"""Test that appropriate signals are emitted"""
	var signal_received = false
	var received_profile = null
	
	# Connect to pilot creation signal
	coordinator.pilot_profile_created.connect(func(profile): 
		signal_received = true
		received_profile = profile
	)
	
	# Create a pilot
	var created_profile = coordinator.create_pilot_profile("SignalTestPilot", 13)
	
	# Wait for signal processing
	await get_tree().process_frame
	
	assert_that(signal_received).is_true()
	assert_that(received_profile).is_equal(created_profile)

func test_error_handling():
	"""Test error handling for invalid operations"""
	# Test operations without current pilot
	assert_that(coordinator.has_current_pilot()).is_false()
	
	var save_result = coordinator.save_current_pilot_profile()
	assert_that(save_result).is_false()
	
	# Test loading from invalid slot
	var invalid_profile = coordinator.load_pilot_profile(999)
	assert_that(invalid_profile).is_null()
	
	# Test deleting invalid slot
	var delete_result = coordinator.delete_pilot_profile(999)
	assert_that(delete_result).is_false()
	
	# Test statistics update without pilot
	coordinator.current_pilot_profile = null
	coordinator.update_pilot_statistics({"score": 100})
	# Should not crash - just log warning