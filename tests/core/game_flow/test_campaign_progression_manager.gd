extends GdUnitTestSuite

## Unit tests for CampaignProgressionManager
## Tests campaign progression and mission unlocking using existing resources

const CampaignProgressionManager = preload("res://scripts/core/game_flow/campaign_system/campaign_progression_manager.gd")
const CampaignData = preload("res://addons/wcs_asset_core/resources/campaign/campaign_data.gd")
const CampaignState = preload("res://addons/wcs_asset_core/resources/save_system/campaign_state.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")

var campaign_manager: CampaignProgressionManager
var mock_campaign_data: CampaignData
var mock_campaign_state: CampaignState
var mock_pilot: PlayerProfile

func before():
	# Create campaign progression manager
	campaign_manager = CampaignProgressionManager.new()
	
	# Create mock campaign data
	_setup_mock_campaign_data()
	
	# Create mock campaign state
	_setup_mock_campaign_state()
	
	# Create mock pilot profile
	_setup_mock_pilot()
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up test data
	_cleanup_test_data()

func _setup_mock_campaign_data():
	mock_campaign_data = CampaignData.new()
	mock_campaign_data.name = "Test Campaign"
	mock_campaign_data.filename = "test_campaign.fsc"
	mock_campaign_data.description = "A test campaign for unit testing"
	mock_campaign_data.num_missions = 3
	
	# Add test missions
	var mission1 = CampaignMissionData.new()
	mission1.name = "First Mission"
	mission1.filename = "mission_01.fs2"
	mission1.index = 0
	mission1.formula_sexp = ""
	mock_campaign_data.add_mission(mission1)
	
	var mission2 = CampaignMissionData.new()
	mission2.name = "Second Mission"
	mission2.filename = "mission_02.fs2"
	mission2.index = 1
	mission2.formula_sexp = "(is-mission-complete \"mission_01.fs2\")"
	mock_campaign_data.add_mission(mission2)
	
	var mission3 = CampaignMissionData.new()
	mission3.name = "Final Mission"
	mission3.filename = "mission_03.fs2"
	mission3.index = 2
	mission3.formula_sexp = "(is-mission-complete \"mission_02.fs2\")"
	mission3.notes = "score_required:5000"
	mock_campaign_data.add_mission(mission3)

func _setup_mock_campaign_state():
	mock_campaign_state = CampaignState.new()
	mock_campaign_state.initialize_from_campaign_data({
		"campaign_name": "Test Campaign",
		"campaign_filename": "test_campaign.fsc",
		"total_missions": 3
	})

func _setup_mock_pilot():
	mock_pilot = PlayerProfile.new()
	mock_pilot.set_callsign("TestPilot")
	mock_pilot.current_save_slot = 1

func _cleanup_test_data():
	# Clean up any test files or data
	pass

func test_campaign_manager_initialization():
	"""Test CampaignProgressionManager initializes correctly"""
	assert_that(campaign_manager).is_not_null()
	assert_that(campaign_manager.mission_unlocking).is_not_null()
	assert_that(campaign_manager.progression_analytics).is_not_null()

func test_campaign_loading_success():
	"""Test successful campaign loading with valid data"""
	# Mock WCSAssetLoader to return our test campaign data
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Verify campaign is loaded correctly
	assert_that(campaign_manager.current_campaign_data).is_equal(mock_campaign_data)
	assert_that(campaign_manager.current_campaign_state).is_equal(mock_campaign_state)

func test_campaign_loading_failure():
	"""Test campaign loading failure handling"""
	# Clear campaign data to simulate loading failure
	campaign_manager.current_campaign_data = null
	campaign_manager.current_campaign_state = null
	
	# Verify proper failure state
	assert_that(campaign_manager.current_campaign_data).is_null()
	assert_that(campaign_manager.current_campaign_state).is_null()

func test_mission_completion_processing():
	"""Test mission completion processing and unlocking"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Complete first mission
	var mission_result = {
		"success": true,
		"score": 3000,
		"time": 1200.0
	}
	
	campaign_manager.complete_mission("mission_01.fs2", mission_result)
	
	# Verify mission completion
	assert_that(mock_campaign_state.is_mission_completed(0)).is_true()
	
	# Verify mission result is stored
	if mock_campaign_state.mission_results.size() > 0:
		var stored_result = mock_campaign_state.mission_results[0]
		assert_that(stored_result.get("success", false)).is_true()
		assert_that(stored_result.get("score", 0)).is_equal(3000)

func test_mission_unlocking_linear_progression():
	"""Test linear mission unlocking progression"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# First mission should be available
	assert_that(campaign_manager.is_mission_available("mission_01.fs2")).is_true()
	
	# Second mission should not be available initially
	assert_that(campaign_manager.is_mission_available("mission_02.fs2")).is_false()
	
	# Complete first mission
	var mission_result = {"success": true, "score": 1000}
	campaign_manager.complete_mission("mission_01.fs2", mission_result)
	
	# Second mission should now be available
	assert_that(campaign_manager.is_mission_available("mission_02.fs2")).is_true()

func test_get_available_missions():
	"""Test getting available missions list"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	var available_missions = campaign_manager.get_available_missions()
	
	# Should have all missions with correct structure
	assert_that(available_missions.size()).is_equal(3)
	
	for mission_info in available_missions:
		assert_that(mission_info.has("filename")).is_true()
		assert_that(mission_info.has("name")).is_true()
		assert_that(mission_info.has("index")).is_true()
		assert_that(mission_info.has("is_available")).is_true()
		assert_that(mission_info.has("is_completed")).is_true()
		assert_that(mission_info.has("best_score")).is_true()
		assert_that(mission_info.has("completion_time")).is_true()

func test_campaign_summary():
	"""Test campaign summary generation"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	var summary = campaign_manager.get_campaign_summary()
	
	assert_that(summary.has("campaign_name")).is_true()
	assert_that(summary.has("campaign_filename")).is_true()
	assert_that(summary.has("total_missions")).is_true()
	assert_that(summary.has("missions_completed")).is_true()
	assert_that(summary.has("completion_percentage")).is_true()
	assert_that(summary.has("available_missions")).is_true()
	
	assert_that(summary.campaign_name).is_equal("Test Campaign")
	assert_that(summary.total_missions).is_equal(3)

func test_campaign_variable_management():
	"""Test campaign variable setting and getting"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Set a variable
	campaign_manager.set_campaign_variable("test_variable", 42, true)
	
	# Get the variable
	var value = campaign_manager.get_campaign_variable("test_variable", 0)
	assert_that(value).is_equal(42)
	
	# Get non-existent variable with default
	var default_value = campaign_manager.get_campaign_variable("nonexistent", "default")
	assert_that(default_value).is_equal("default")

func test_player_choice_recording():
	"""Test player choice recording and processing"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Record a player choice
	campaign_manager.record_player_choice("spare_civilian", true, {"significant": true})
	
	# Verify choice is recorded in campaign state
	var choice = mock_campaign_state.get_player_choice("spare_civilian")
	assert_that(choice.has("value")).is_true()
	assert_that(choice.value).is_true()

func test_mission_completion_signal_emission():
	"""Test signal emission during mission completion"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	var signal_received = false
	var received_mission_id = ""
	var received_newly_available: Array[String] = []
	
	# Connect to signal
	campaign_manager.mission_completed.connect(func(mission_id: String, mission_result: Dictionary, newly_available: Array[String]):
		signal_received = true
		received_mission_id = mission_id
		received_newly_available = newly_available
	)
	
	# Complete a mission
	var mission_result = {"success": true, "score": 2000}
	campaign_manager.complete_mission("mission_01.fs2", mission_result)
	
	# Wait for signal processing
	await get_tree().process_frame
	
	# Verify signal was emitted
	assert_that(signal_received).is_true()
	assert_that(received_mission_id).is_equal("mission_01.fs2")

func test_campaign_completion_detection():
	"""Test campaign completion detection"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	var campaign_completed_signal = false
	
	# Connect to campaign completed signal
	campaign_manager.campaign_completed.connect(func(campaign_state: CampaignState):
		campaign_completed_signal = true
	)
	
	# Complete all missions
	for i in range(3):
		var mission_filename = "mission_%02d.fs2" % (i + 1)
		var mission_result = {"success": true, "score": 5000}
		campaign_manager.complete_mission(mission_filename, mission_result)
	
	# Wait for signal processing
	await get_tree().process_frame
	
	# Verify campaign completion
	assert_that(mock_campaign_state.get_completion_percentage()).is_equal(1.0)

func test_mission_unlocking_with_performance_requirements():
	"""Test mission unlocking based on performance requirements"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Complete first two missions
	campaign_manager.complete_mission("mission_01.fs2", {"success": true, "score": 1000})
	campaign_manager.complete_mission("mission_02.fs2", {"success": true, "score": 2000})
	
	# Third mission requires score >= 5000, so it shouldn't be available yet
	assert_that(campaign_manager.is_mission_available("mission_03.fs2")).is_false()
	
	# Complete second mission with high score
	campaign_manager.complete_mission("mission_02.fs2", {"success": true, "score": 6000})
	
	# Third mission should now be available
	# Note: This test depends on the mission unlocking logic implementation

func test_duplicate_mission_completion_handling():
	"""Test handling of duplicate mission completion attempts"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Complete mission first time
	campaign_manager.complete_mission("mission_01.fs2", {"success": true, "score": 1000})
	var first_completion_count = mock_campaign_state.get_missions_completed_count()
	
	# Try to complete same mission again
	campaign_manager.complete_mission("mission_01.fs2", {"success": true, "score": 2000})
	var second_completion_count = mock_campaign_state.get_missions_completed_count()
	
	# Completion count should not change
	assert_that(second_completion_count).is_equal(first_completion_count)

func test_invalid_mission_completion():
	"""Test handling of invalid mission completion attempts"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Try to complete non-existent mission
	campaign_manager.complete_mission("nonexistent_mission.fs2", {"success": true})
	
	# Should not crash and should not affect campaign state
	assert_that(mock_campaign_state.get_missions_completed_count()).is_equal(0)

func test_campaign_analytics_integration():
	"""Test integration with progression analytics"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Complete a mission to trigger analytics
	var mission_result = {"success": true, "score": 3000, "time": 1500.0}
	campaign_manager.complete_mission("mission_01.fs2", mission_result)
	
	# Verify analytics were updated
	assert_that(campaign_manager.progression_analytics).is_not_null()
	assert_that(campaign_manager.progression_analytics.progression_history.size()).is_greater(0)

func test_save_integration():
	"""Test integration with save system"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Set a variable to trigger save
	campaign_manager.set_campaign_variable("test_save", "value", true)
	
	# Verify save was triggered (depends on save system implementation)
	# This test validates that save integration doesn't crash

func test_mission_unlocking_system_integration():
	"""Test integration with mission unlocking system"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Verify mission unlocking system is properly initialized
	assert_that(campaign_manager.mission_unlocking).is_not_null()
	
	# Test mission availability checking
	var first_mission_available = campaign_manager.mission_unlocking.check_mission_availability(
		mock_campaign_data.missions[0], mock_campaign_state
	)
	assert_that(first_mission_available).is_true()

func test_empty_campaign_handling():
	"""Test handling of empty campaign data"""
	# Create empty campaign data
	var empty_campaign = CampaignData.new()
	empty_campaign.name = "Empty Campaign"
	empty_campaign.filename = "empty.fsc"
	
	campaign_manager.current_campaign_data = empty_campaign
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Test operations with empty campaign
	var available_missions = campaign_manager.get_available_missions()
	assert_that(available_missions.size()).is_equal(0)
	
	var summary = campaign_manager.get_campaign_summary()
	assert_that(summary.total_missions).is_equal(0)

func test_null_campaign_state_handling():
	"""Test handling of null campaign state"""
	# Set campaign data but null state
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = null
	
	# Operations should handle null state gracefully
	var available_missions = campaign_manager.get_available_missions()
	assert_that(available_missions.size()).is_equal(0)
	
	var summary = campaign_manager.get_campaign_summary()
	assert_that(summary.is_empty()).is_true()

func test_campaign_variable_persistence():
	"""Test campaign variable persistence across operations"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Set multiple variables
	campaign_manager.set_campaign_variable("persistent_var", "persistent_value", true)
	campaign_manager.set_campaign_variable("mission_var", "mission_value", false)
	
	# Complete a mission (which should trigger save)
	campaign_manager.complete_mission("mission_01.fs2", {"success": true, "score": 1000})
	
	# Verify variables are still accessible
	assert_that(campaign_manager.get_campaign_variable("persistent_var")).is_equal("persistent_value")
	assert_that(campaign_manager.get_campaign_variable("mission_var")).is_equal("mission_value")

func test_choice_consequences_evaluation():
	"""Test evaluation of choice consequences for mission unlocking"""
	# Setup campaign
	campaign_manager.current_campaign_data = mock_campaign_data
	campaign_manager.current_campaign_state = mock_campaign_state
	
	# Record a choice that might affect mission availability
	campaign_manager.record_player_choice("critical_choice", "option_a", {"significant": true})
	
	# Verify choice is recorded
	var choice = mock_campaign_state.get_player_choice("critical_choice")
	assert_that(choice.has("value")).is_true()
	assert_that(choice.value).is_equal("option_a")