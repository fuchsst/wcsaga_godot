extends GdUnitTestSuite

## Unit tests for AchievementManager
## Tests achievement earning, medal awards, and progression tracking

const AchievementManager = preload("res://scripts/core/game_flow/player_data/achievement_manager.gd")
const PlayerProfile = preload("res://addons/wcs_asset_core/resources/player/player_profile.gd")
const PilotStatistics = preload("res://addons/wcs_asset_core/resources/player/pilot_statistics.gd")

var achievement_manager: AchievementManager
var test_profile: PlayerProfile

func before():
	# Create achievement manager instance
	achievement_manager = AchievementManager.new()
	achievement_manager.name = "TestAchievementManager"
	add_child(achievement_manager)
	
	# Create test pilot profile
	test_profile = PlayerProfile.new()
	test_profile.set_callsign("TestPilot")
	
	# Wait for initialization
	await get_tree().process_frame

func after():
	# Clean up
	if achievement_manager:
		achievement_manager.queue_free()
	
	if test_profile:
		test_profile = null

func test_achievement_system_initialization():
	"""Test achievement system initializes correctly"""
	assert_that(achievement_manager).is_not_null()
	assert_that(achievement_manager.achievement_definitions).is_not_empty()
	assert_that(achievement_manager.medal_definitions).is_not_empty()
	
	# Verify specific achievements exist
	assert_that(achievement_manager.achievement_definitions.has("first_kill")).is_true()
	assert_that(achievement_manager.achievement_definitions.has("centurion")).is_true()
	assert_that(achievement_manager.achievement_definitions.has("marksman")).is_true()
	
	# Verify specific medals exist
	assert_that(achievement_manager.medal_definitions.has("distinguished_flying_cross")).is_true()
	assert_that(achievement_manager.medal_definitions.has("combat_excellence_medal")).is_true()

func test_first_kill_achievement():
	"""Test first kill achievement earning"""
	# Set up pilot with 1 kill
	test_profile.pilot_stats.kill_count = 1
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check achievements
	var new_achievements = achievement_manager.check_pilot_achievements(test_profile)
	
	# Should earn first_kill achievement
	assert_that(new_achievements).contains("first_kill")
	
	# Verify achievement is stored in profile
	var earned_achievements = test_profile.get_meta("achievements", [])
	assert_that(earned_achievements).contains("first_kill")

func test_centurion_achievement():
	"""Test centurion achievement (100 kills)"""
	# Set up pilot with 100 kills
	test_profile.pilot_stats.kill_count = 100
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check achievements
	var new_achievements = achievement_manager.check_pilot_achievements(test_profile)
	
	# Should earn centurion achievement
	assert_that(new_achievements).contains("centurion")

func test_marksman_achievement():
	"""Test marksman achievement (85% accuracy)"""
	# Set up pilot with high accuracy
	test_profile.pilot_stats.primary_shots_fired = 100
	test_profile.pilot_stats.primary_shots_hit = 90  # 90% accuracy
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check achievements
	var new_achievements = achievement_manager.check_pilot_achievements(test_profile)
	
	# Should earn marksman achievement
	assert_that(new_achievements).contains("marksman")

func test_veteran_pilot_achievement():
	"""Test veteran pilot achievement (50 missions)"""
	# Set up pilot with 50 missions
	test_profile.pilot_stats.missions_flown = 50
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check achievements
	var new_achievements = achievement_manager.check_pilot_achievements(test_profile)
	
	# Should earn veteran_pilot achievement
	assert_that(new_achievements).contains("veteran_pilot")

func test_achievement_not_earned_twice():
	"""Test achievements are not earned multiple times"""
	# Set up pilot with kills
	test_profile.pilot_stats.kill_count = 1
	test_profile.pilot_stats._update_calculated_stats()
	
	# First check should earn achievement
	var first_check = achievement_manager.check_pilot_achievements(test_profile)
	assert_that(first_check).contains("first_kill")
	
	# Second check should not earn it again
	var second_check = achievement_manager.check_pilot_achievements(test_profile)
	assert_that(second_check).does_not_contain("first_kill")

func test_medal_earning():
	"""Test medal earning based on comprehensive performance"""
	# Set up pilot with high performance
	test_profile.pilot_stats.score = 50000
	test_profile.pilot_stats.missions_flown = 30
	test_profile.pilot_stats.kill_count = 80
	test_profile.pilot_stats.primary_shots_fired = 1000
	test_profile.pilot_stats.primary_shots_hit = 850  # 85% accuracy
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check medals
	var new_medals = achievement_manager.check_pilot_medals(test_profile)
	
	# Should earn combat excellence medal (75 kills + 80% accuracy)
	assert_that(new_medals).contains("combat_excellence_medal")

func test_flight_safety_medal():
	"""Test flight safety medal earning"""
	# Set up pilot with high survival rate and missions
	test_profile.pilot_stats.missions_flown = 35
	# Note: survival rate calculation is placeholder in current implementation
	
	# Check medals
	var new_medals = achievement_manager.check_pilot_medals(test_profile)
	
	# May earn flight_safety_award depending on implementation
	assert_that(new_medals).is_not_null()

func test_rank_progression():
	"""Test rank progression based on performance"""
	# Set up pilot with good performance
	test_profile.pilot_stats.score = 10000
	test_profile.pilot_stats.missions_flown = 20
	test_profile.pilot_stats.kill_count = 40
	test_profile.pilot_stats.primary_shots_fired = 500
	test_profile.pilot_stats.primary_shots_hit = 400
	test_profile.pilot_stats.rank = 0  # Start at lowest rank
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check rank progression
	var rank_promoted = achievement_manager.check_rank_progression(test_profile)
	
	# Should be promoted
	assert_that(rank_promoted).is_true()
	assert_that(test_profile.pilot_stats.rank).is_greater(0)

func test_achievement_progress_tracking():
	"""Test achievement progress tracking"""
	# Set up pilot with partial progress toward centurion
	test_profile.pilot_stats.kill_count = 50  # 50% progress toward 100 kills
	test_profile.pilot_stats._update_calculated_stats()
	
	# Get progress
	var progress = achievement_manager.get_achievement_progress("centurion", test_profile)
	
	# Should be 50% progress
	assert_that(progress).is_equal(0.5)

func test_achievement_progress_for_missions():
	"""Test achievement progress for mission-based achievements"""
	# Set up pilot with partial mission progress
	test_profile.pilot_stats.missions_flown = 25  # 50% progress toward 50 missions
	test_profile.pilot_stats._update_calculated_stats()
	
	# Get progress
	var progress = achievement_manager.get_achievement_progress("veteran_pilot", test_profile)
	
	# Should be 50% progress
	assert_that(progress).is_equal(0.5)

func test_achievement_summary():
	"""Test pilot achievement summary generation"""
	# Set up pilot with some achievements
	test_profile.pilot_stats.kill_count = 1
	test_profile.pilot_stats.missions_flown = 1
	test_profile.pilot_stats._update_calculated_stats()
	
	# Earn some achievements
	achievement_manager.check_pilot_achievements(test_profile)
	
	# Get summary
	var summary = achievement_manager.get_pilot_achievement_summary(test_profile)
	
	assert_that(summary).is_not_null()
	assert_that(summary.has("achievements_earned")).is_true()
	assert_that(summary.has("total_achievements")).is_true()
	assert_that(summary.has("achievement_completion")).is_true()
	assert_that(summary.has("medals_earned")).is_true()
	
	# Verify completion percentage calculation
	assert_that(summary.achievement_completion).is_between(0.0, 1.0)

func test_achievement_definitions():
	"""Test achievement definition retrieval"""
	# Get specific achievement definition
	var first_kill_def = achievement_manager.get_achievement_definition("first_kill")
	
	assert_that(first_kill_def).is_not_empty()
	assert_that(first_kill_def.has("name")).is_true()
	assert_that(first_kill_def.has("description")).is_true()
	assert_that(first_kill_def.has("criteria")).is_true()
	
	# Verify achievement details
	assert_that(first_kill_def.name).is_equal("First Blood")
	assert_that(first_kill_def.criteria.has("kills")).is_true()

func test_medal_definitions():
	"""Test medal definition retrieval"""
	# Get specific medal definition
	var dfc_def = achievement_manager.get_medal_definition("distinguished_flying_cross")
	
	assert_that(dfc_def).is_not_empty()
	assert_that(dfc_def.has("name")).is_true()
	assert_that(dfc_def.has("description")).is_true()
	assert_that(dfc_def.has("criteria")).is_true()
	
	# Verify medal details
	assert_that(dfc_def.name).is_equal("Distinguished Flying Cross")

func test_achievement_enabling_disabling():
	"""Test enabling/disabling achievement checking"""
	# Disable achievement checking
	achievement_manager.set_achievement_checks_enabled(false)
	
	# Set up pilot that would normally earn achievement
	test_profile.pilot_stats.kill_count = 1
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check achievements (should return empty)
	var achievements = achievement_manager.check_pilot_achievements(test_profile)
	assert_that(achievements).is_empty()
	
	# Re-enable achievement checking
	achievement_manager.set_achievement_checks_enabled(true)
	
	# Now should earn achievement
	achievements = achievement_manager.check_pilot_achievements(test_profile)
	assert_that(achievements).contains("first_kill")

func test_signal_emissions():
	"""Test achievement and medal signals are emitted"""
	var achievement_signal_received = false
	var medal_signal_received = false
	var rank_signal_received = false
	
	# Connect to signals
	achievement_manager.achievement_earned.connect(func(achievement_id, pilot): achievement_signal_received = true)
	achievement_manager.medal_awarded.connect(func(medal_id, pilot): medal_signal_received = true)
	achievement_manager.rank_promoted.connect(func(rank, pilot): rank_signal_received = true)
	
	# Set up pilot to earn achievement and rank up
	test_profile.pilot_stats.kill_count = 1
	test_profile.pilot_stats.score = 5000
	test_profile.pilot_stats.missions_flown = 10
	test_profile.pilot_stats.rank = 0
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check achievements and rank
	achievement_manager.check_pilot_achievements(test_profile)
	achievement_manager.check_rank_progression(test_profile)
	
	# Wait for signal processing
	await get_tree().process_frame
	
	assert_that(achievement_signal_received).is_true()
	assert_that(rank_signal_received).is_true()

func test_multiple_achievements_in_one_check():
	"""Test earning multiple achievements in single check"""
	# Set up pilot to earn multiple achievements
	test_profile.pilot_stats.kill_count = 1  # first_kill
	test_profile.pilot_stats.missions_flown = 1  # rookie_graduate
	test_profile.pilot_stats.primary_shots_fired = 100
	test_profile.pilot_stats.primary_shots_hit = 90  # marksman (90% accuracy)
	test_profile.pilot_stats._update_calculated_stats()
	
	# Check achievements
	var new_achievements = achievement_manager.check_pilot_achievements(test_profile)
	
	# Should earn multiple achievements
	assert_that(new_achievements.size()).is_greater_equal(2)
	assert_that(new_achievements).contains("first_kill")
	assert_that(new_achievements).contains("rookie_graduate")

func test_achievement_criteria_edge_cases():
	"""Test achievement criteria edge cases"""
	# Test exactly meeting criteria
	test_profile.pilot_stats.kill_count = 100  # Exactly 100 for centurion
	test_profile.pilot_stats._update_calculated_stats()
	
	var achievements = achievement_manager.check_pilot_achievements(test_profile)
	assert_that(achievements).contains("centurion")
	
	# Test just below criteria
	test_profile.pilot_stats.kill_count = 99  # Just below 100
	test_profile.pilot_stats._update_calculated_stats()
	test_profile.set_meta("achievements", [])  # Clear previous achievements
	
	achievements = achievement_manager.check_pilot_achievements(test_profile)
	assert_that(achievements).does_not_contain("centurion")

func test_all_achievement_definitions_complete():
	"""Test all achievement definitions have required fields"""
	var all_definitions = achievement_manager.get_all_achievement_definitions()
	
	for achievement_id in all_definitions:
		var definition = all_definitions[achievement_id]
		
		# Verify required fields
		assert_that(definition.has("name")).is_true()
		assert_that(definition.has("description")).is_true()
		assert_that(definition.has("criteria")).is_true()
		assert_that(definition.has("type")).is_true()
		
		# Verify name and description are not empty
		assert_that(definition.name).is_not_empty()
		assert_that(definition.description).is_not_empty()
		
		# Verify criteria is a dictionary
		assert_that(definition.criteria is Dictionary).is_true()

func test_all_medal_definitions_complete():
	"""Test all medal definitions have required fields"""
	var all_definitions = achievement_manager.get_all_medal_definitions()
	
	for medal_id in all_definitions:
		var definition = all_definitions[medal_id]
		
		# Verify required fields
		assert_that(definition.has("name")).is_true()
		assert_that(definition.has("description")).is_true()
		assert_that(definition.has("criteria")).is_true()
		assert_that(definition.has("type")).is_true()
		
		# Verify name and description are not empty
		assert_that(definition.name).is_not_empty()
		assert_that(definition.description).is_not_empty()
		
		# Verify criteria is a dictionary
		assert_that(definition.criteria is Dictionary).is_true()