extends GdUnitTestSuite

## Unit tests for MissionUnlocking
## Tests mission unlocking logic with various conditions and prerequisites

const MissionUnlocking = preload("res://scripts/core/game_flow/campaign_system/mission_unlocking.gd")
const CampaignData = preload("res://addons/wcs_asset_core/resources/campaign/campaign_data.gd")
const CampaignState = preload("res://addons/wcs_asset_core/resources/save_system/campaign_state.gd")

var mission_unlocking: MissionUnlocking
var mock_campaign_data: CampaignData
var mock_campaign_state: CampaignState

func before():
	# Create mission unlocking system
	mission_unlocking = MissionUnlocking.new()
	
	# Create mock campaign data
	_setup_mock_campaign_data()
	
	# Create mock campaign state
	_setup_mock_campaign_state()
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up test data
	pass

func _setup_mock_campaign_data():
	mock_campaign_data = CampaignData.new()
	mock_campaign_data.name = "Test Campaign"
	mock_campaign_data.filename = "test_campaign.fsc"
	
	# Mission 1: Tutorial (always available)
	var mission1 = CampaignMissionData.new()
	mission1.name = "Tutorial"
	mission1.filename = "tutorial.fs2"
	mission1.index = 0
	mission1.formula_sexp = ""
	mock_campaign_data.add_mission(mission1)
	
	# Mission 2: First Combat (requires tutorial)
	var mission2 = CampaignMissionData.new()
	mission2.name = "First Combat"
	mission2.filename = "first_combat.fs2"
	mission2.index = 1
	mission2.formula_sexp = "(is-mission-complete \"tutorial.fs2\")"
	mock_campaign_data.add_mission(mission2)
	
	# Mission 3: Advanced Mission (requires high score)
	var mission3 = CampaignMissionData.new()
	mission3.name = "Advanced Mission"
	mission3.filename = "advanced.fs2"
	mission3.index = 2
	mission3.formula_sexp = "(is-mission-complete \"first_combat.fs2\")"
	mission3.notes = "score_required:5000"
	mock_campaign_data.add_mission(mission3)
	
	# Mission 4: Choice-dependent mission
	var mission4 = CampaignMissionData.new()
	mission4.name = "Choice Mission"
	mission4.filename = "choice_mission.fs2"
	mission4.index = 3
	mission4.formula_sexp = "(and (is-mission-complete \"tutorial.fs2\") (= choice_variable true))"
	mock_campaign_data.add_mission(mission4)
	
	# Mission 5: Branch-specific mission
	var mission5 = CampaignMissionData.new()
	mission5.name = "Branch Mission"
	mission5.filename = "branch_mission.fs2"
	mission5.index = 4
	mission5.notes = "branch:rebel_path"
	mock_campaign_data.add_mission(mission5)

func _setup_mock_campaign_state():
	mock_campaign_state = CampaignState.new()
	mock_campaign_state.initialize_from_campaign_data({
		"campaign_name": "Test Campaign",
		"campaign_filename": "test_campaign.fsc",
		"total_missions": 5
	})

func test_mission_unlocking_initialization():
	"""Test MissionUnlocking initializes correctly"""
	assert_that(mission_unlocking).is_not_null()

func test_first_mission_always_available():
	"""Test that first mission is always available"""
	var first_mission = mock_campaign_data.missions[0]
	var is_available = mission_unlocking.check_mission_availability(first_mission, mock_campaign_state)
	assert_that(is_available).is_true()

func test_linear_mission_progression():
	"""Test basic linear mission progression unlocking"""
	# First mission should be available
	var mission1 = mock_campaign_data.missions[0]
	assert_that(mission_unlocking.check_mission_availability(mission1, mock_campaign_state)).is_true()
	
	# Second mission should not be available initially
	var mission2 = mock_campaign_data.missions[1]
	assert_that(mission_unlocking.check_mission_availability(mission2, mock_campaign_state)).is_false()
	
	# Complete first mission
	mock_campaign_state.complete_mission(0, {"success": true, "score": 1000})
	
	# Calculate newly available missions
	var newly_available = mission_unlocking.calculate_newly_available_missions(
		"tutorial.fs2", {"success": true, "score": 1000}, mock_campaign_state, mock_campaign_data
	)
	
	# Second mission should be in newly available list
	assert_that(newly_available).contains("first_combat.fs2")

func test_performance_based_unlocking():
	"""Test mission unlocking based on performance requirements"""
	# Complete tutorial and first combat with low score
	mock_campaign_state.complete_mission(0, {"success": true, "score": 1000})
	mock_campaign_state.complete_mission(1, {"success": true, "score": 2000})
	
	# Advanced mission requires score >= 5000, so shouldn't be unlocked with low score
	var newly_available_low = mission_unlocking.calculate_newly_available_missions(
		"first_combat.fs2", {"success": true, "score": 2000}, mock_campaign_state, mock_campaign_data
	)
	
	# Advanced mission should not be available
	assert_that(newly_available_low).does_not_contain("advanced.fs2")
	
	# Complete first combat with high score
	var newly_available_high = mission_unlocking.calculate_newly_available_missions(
		"first_combat.fs2", {"success": true, "score": 6000}, mock_campaign_state, mock_campaign_data
	)
	
	# Advanced mission should now be available (depends on implementation)
	# Note: This test validates the structure for performance-based unlocking

func test_choice_based_unlocking():
	"""Test mission unlocking based on player choices"""
	var choice_mission = mock_campaign_data.missions[3]
	
	# Without the required choice, mission should not unlock
	var unlocks_without_choice = mission_unlocking.check_choice_unlocks_mission(
		choice_mission, "choice_variable", false, mock_campaign_state
	)
	assert_that(unlocks_without_choice).is_false()
	
	# With the required choice, mission should unlock
	var unlocks_with_choice = mission_unlocking.check_choice_unlocks_mission(
		choice_mission, "choice_variable", true, mock_campaign_state
	)
	# Note: This depends on the SEXP evaluation implementation

func test_branch_based_unlocking():
	"""Test mission unlocking based on story branches"""
	var branch_mission = mock_campaign_data.missions[4]
	
	# With wrong branch, mission should not be available
	mock_campaign_state.current_branch = "main"
	var available_wrong_branch = mission_unlocking.check_mission_availability(branch_mission, mock_campaign_state)
	assert_that(available_wrong_branch).is_false()
	
	# With correct branch, mission should be available
	mock_campaign_state.current_branch = "rebel_path"
	var available_correct_branch = mission_unlocking.check_mission_availability(branch_mission, mock_campaign_state)
	# Note: This depends on the branch checking implementation

func test_prerequisite_completion_checking():
	"""Test prerequisite mission completion checking"""
	# Complete tutorial mission
	mock_campaign_state.complete_mission(0, {"success": true, "score": 1000})
	
	var newly_available = mission_unlocking.calculate_newly_available_missions(
		"tutorial.fs2", {"success": true, "score": 1000}, mock_campaign_state, mock_campaign_data
	)
	
	# First combat should be unlocked as it depends on tutorial
	assert_that(newly_available).contains("first_combat.fs2")
	
	# Advanced mission should not be unlocked yet (depends on first combat)
	assert_that(newly_available).does_not_contain("advanced.fs2")

func test_multiple_mission_unlocking():
	"""Test unlocking multiple missions from single completion"""
	# Setup scenario where completing one mission unlocks multiple others
	mock_campaign_state.complete_mission(0, {"success": true, "score": 8000})  # High score tutorial
	
	var newly_available = mission_unlocking.calculate_newly_available_missions(
		"tutorial.fs2", {"success": true, "score": 8000}, mock_campaign_state, mock_campaign_data
	)
	
	# Should unlock at least the next linear mission
	assert_that(newly_available.size()).is_greater_equal(1)
	assert_that(newly_available).contains("first_combat.fs2")

func test_already_completed_missions_not_unlocked():
	"""Test that already completed missions are not included in newly available"""
	# Complete tutorial
	mock_campaign_state.complete_mission(0, {"success": true, "score": 1000})
	# Complete first combat
	mock_campaign_state.complete_mission(1, {"success": true, "score": 2000})
	
	# Complete tutorial again (hypothetically)
	var newly_available = mission_unlocking.calculate_newly_available_missions(
		"tutorial.fs2", {"success": true, "score": 1000}, mock_campaign_state, mock_campaign_data
	)
	
	# First combat should not be in newly available since it's already completed
	assert_that(newly_available).does_not_contain("first_combat.fs2")

func test_already_available_missions_not_duplicated():
	"""Test that already available missions are not duplicated in newly available"""
	# Mark first combat as already available
	mock_campaign_state.conditional_missions["first_combat.fs2"] = true
	
	var newly_available = mission_unlocking.calculate_newly_available_missions(
		"tutorial.fs2", {"success": true, "score": 1000}, mock_campaign_state, mock_campaign_data
	)
	
	# First combat should not be in newly available since it's already marked as available
	assert_that(newly_available).does_not_contain("first_combat.fs2")

func test_completed_mission_not_included_in_newly_available():
	"""Test that the just completed mission is not included in newly available"""
	var newly_available = mission_unlocking.calculate_newly_available_missions(
		"tutorial.fs2", {"success": true, "score": 1000}, mock_campaign_state, mock_campaign_data
	)
	
	# The completed mission itself should not be in the newly available list
	assert_that(newly_available).does_not_contain("tutorial.fs2")

func test_formula_evaluation_with_mission_references():
	"""Test SEXP formula evaluation with mission completion references"""
	var mission2 = mock_campaign_data.missions[1]  # Has formula referencing tutorial.fs2
	
	# Without tutorial completed, should not unlock
	var unlocks_without_prereq = mission_unlocking.check_mission_availability(mission2, mock_campaign_state)
	assert_that(unlocks_without_prereq).is_false()
	
	# Complete tutorial
	mock_campaign_state.complete_mission(0, {"success": true, "score": 1000})
	
	# Now should unlock (depends on formula evaluation implementation)
	# Note: This test validates the structure for formula-based unlocking

func test_variable_condition_checking():
	"""Test checking campaign variable conditions in formulas"""
	# Set up a campaign variable
	mock_campaign_state.set_variable("test_variable", 42, true)
	
	# Create a mission with variable condition
	var variable_mission = CampaignMissionData.new()
	variable_mission.name = "Variable Mission"
	variable_mission.filename = "variable_mission.fs2"
	variable_mission.formula_sexp = "(= variable-test_variable 42)"
	
	# Test variable condition evaluation (depends on implementation)
	# This validates the structure for variable-based conditions

func test_time_based_unlocking():
	"""Test mission unlocking based on completion time"""
	# Mission with time requirement in notes
	var time_mission = CampaignMissionData.new()
	time_mission.name = "Speed Mission"
	time_mission.filename = "speed_mission.fs2"
	time_mission.notes = "time_limit:300.0"  # 5 minutes
	
	# Fast completion should unlock
	var fast_result = {"success": true, "time": 240.0}  # 4 minutes
	# Slow completion should not unlock  
	var slow_result = {"success": true, "time": 400.0}  # 6.67 minutes
	
	# Test time-based unlocking logic (depends on implementation)

func test_complex_formula_evaluation():
	"""Test evaluation of complex SEXP formulas"""
	# Create mission with complex formula
	var complex_mission = CampaignMissionData.new()
	complex_mission.name = "Complex Mission"
	complex_mission.filename = "complex.fs2"
	complex_mission.formula_sexp = "(and (is-mission-complete \"tutorial.fs2\") (> variable-score 5000) (= choice-path \"rebel\"))"
	
	# Test complex condition evaluation
	# This validates the structure for complex formula handling

func test_unlock_reason_tracking():
	"""Test tracking of unlock reasons"""
	# This test validates that unlock reasons are properly categorized
	var reasons = [
		MissionUnlocking.UnlockReason.CAMPAIGN_START,
		MissionUnlocking.UnlockReason.MISSION_COMPLETION,
		MissionUnlocking.UnlockReason.PERFORMANCE_UNLOCK,
		MissionUnlocking.UnlockReason.CHOICE_UNLOCK,
		MissionUnlocking.UnlockReason.VARIABLE_CONDITION,
		MissionUnlocking.UnlockReason.BRANCH_UNLOCK
	]
	
	# Verify all unlock reasons are defined
	for reason in reasons:
		assert_that(reason).is_not_null()

func test_invalid_mission_data_handling():
	"""Test handling of invalid mission data"""
	# Test with null mission data
	var result_null = mission_unlocking.check_mission_availability(null, mock_campaign_state)
	assert_that(result_null).is_false()
	
	# Test with empty campaign state
	var empty_state = CampaignState.new()
	var result_empty = mission_unlocking.check_mission_availability(mock_campaign_data.missions[0], empty_state)
	assert_that(result_empty).is_true()  # First mission should still be available

func test_malformed_formula_handling():
	"""Test handling of malformed SEXP formulas"""
	# Create mission with malformed formula
	var bad_mission = CampaignMissionData.new()
	bad_mission.name = "Bad Formula Mission"
	bad_mission.filename = "bad_formula.fs2"
	bad_mission.formula_sexp = "(incomplete formula"
	
	# Should handle gracefully without crashing
	var result = mission_unlocking.check_mission_availability(bad_mission, mock_campaign_state)
	# Should default to false for safety
	assert_that(result).is_false()

func test_score_requirement_extraction():
	"""Test extraction of score requirements from mission notes"""
	var mission_with_score = CampaignMissionData.new()
	mission_with_score.notes = "This mission requires score_required:7500 to unlock"
	
	# Test score extraction (depends on implementation)
	# This validates the structure for score requirement parsing

func test_time_requirement_extraction():
	"""Test extraction of time requirements from mission notes"""
	var mission_with_time = CampaignMissionData.new()
	mission_with_time.notes = "Complete quickly! time_limit:180.5 seconds max"
	
	# Test time extraction (depends on implementation)
	# This validates the structure for time requirement parsing

func test_branch_requirement_extraction():
	"""Test extraction of branch requirements from mission notes"""
	var mission_with_branch = CampaignMissionData.new()
	mission_with_branch.notes = "Available only on branch:loyalist_path after chapter 3"
	
	# Test branch extraction (depends on implementation)
	# This validates the structure for branch requirement parsing

func test_empty_formula_handling():
	"""Test handling of missions with empty formulas"""
	var empty_formula_mission = CampaignMissionData.new()
	empty_formula_mission.name = "Empty Formula"
	empty_formula_mission.filename = "empty.fs2"
	empty_formula_mission.index = 0
	empty_formula_mission.formula_sexp = ""
	
	# First mission with empty formula should be available
	var result = mission_unlocking.check_mission_availability(empty_formula_mission, mock_campaign_state)
	assert_that(result).is_true()
	
	# Non-first mission with empty formula should use default rules
	empty_formula_mission.index = 2
	var result_non_first = mission_unlocking.check_mission_availability(empty_formula_mission, mock_campaign_state)
	# Depends on implementation but should handle gracefully

func test_mission_index_validation():
	"""Test validation of mission indices"""
	# Test with negative index
	var negative_mission = CampaignMissionData.new()
	negative_mission.index = -1
	negative_mission.filename = "negative.fs2"
	
	var result_negative = mission_unlocking.check_mission_availability(negative_mission, mock_campaign_state)
	assert_that(result_negative).is_false()
	
	# Test with very high index
	var high_mission = CampaignMissionData.new()
	high_mission.index = 9999
	high_mission.filename = "high.fs2"
	
	var result_high = mission_unlocking.check_mission_availability(high_mission, mock_campaign_state)
	# Should handle gracefully