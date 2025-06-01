extends GdUnitTestSuite

## Test suite for ProgressionTracker
## Validates progression tracking, medal requirements, rank advancement, and milestone detection
## Tests achievement progress calculation and performance insights generation

# Test objects
var progression_tracker: ProgressionTracker = null
var test_pilot_stats: PilotStatistics = null
var test_earned_medals: Array[String] = []

func before_test() -> void:
	"""Setup before each test."""
	# Create progression tracker
	progression_tracker = ProgressionTracker.create_progression_tracker()
	
	# Create test pilot statistics
	test_pilot_stats = PilotStatistics.new()
	_setup_test_pilot_statistics()
	
	# Setup test earned medals
	test_earned_medals = ["Bronze Cluster"]

func after_test() -> void:
	"""Cleanup after each test."""
	if progression_tracker:
		progression_tracker.queue_free()
	
	progression_tracker = null
	test_pilot_stats = null
	test_earned_medals.clear()

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_progression_tracker_initializes_correctly() -> void:
	"""Test that ProgressionTracker initializes properly."""
	# Assert
	assert_object(progression_tracker).is_not_null()
	assert_array(progression_tracker.available_ranks).is_not_empty()
	assert_array(progression_tracker.available_medals).is_not_empty()
	assert_dict(progression_tracker.milestone_tracking).is_not_empty()

func test_rank_data_initialization() -> void:
	"""Test that rank data is initialized correctly."""
	# Assert
	assert_array(progression_tracker.available_ranks).is_not_empty()
	assert_int(progression_tracker.available_ranks.size()).is_equal(10)  # Standard WCS ranks
	
	# Check first and last ranks
	var first_rank: RankData = progression_tracker.available_ranks[0]
	var last_rank: RankData = progression_tracker.available_ranks[-1]
	
	assert_str(first_rank.name).is_equal("Ensign")
	assert_int(first_rank.points_required).is_equal(0)
	assert_str(last_rank.name).is_equal("Admiral")
	assert_bool(last_rank.is_final_rank()).is_true()

func test_medal_data_initialization() -> void:
	"""Test that medal data is initialized correctly."""
	# Assert
	assert_array(progression_tracker.available_medals).is_not_empty()
	
	# Check for expected medals
	var medal_names: Array[String] = []
	for medal in progression_tracker.available_medals:
		medal_names.append(medal.name)
	
	assert_array(medal_names).contains(["Bronze Cluster", "Silver Cluster", "Gold Cluster"])
	assert_array(medal_names).contains(["Marksman Medal", "Expert Marksman", "Sharpshooter Cross"])

func test_milestone_tracking_initialization() -> void:
	"""Test that milestone tracking is initialized correctly."""
	# Assert
	assert_dict(progression_tracker.milestone_tracking).is_not_empty()
	assert_dict(progression_tracker.milestone_tracking).contains_keys([
		"first_kill", "ace_status", "veteran_status", "marksman_level"
	])

# ============================================================================
# PROGRESSION UPDATE TESTS
# ============================================================================

func test_update_pilot_progress() -> void:
	"""Test updating pilot progress."""
	# Act
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Assert
	assert_array(progression_tracker.earned_medals).is_equal(test_earned_medals)
	assert_int(progression_tracker.current_rank).is_equal(test_pilot_stats.rank)

func test_progress_calculation_performance() -> void:
	"""Test that progress calculation completes within reasonable time."""
	# Arrange
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Act
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Assert
	var calculation_time: float = progression_tracker.progress_calculation_time
	assert_float(calculation_time).is_less(1.0)  # Should complete in under 1 second

# ============================================================================
# RANK PROGRESSION TESTS
# ============================================================================

func test_get_next_rank_progress() -> void:
	"""Test getting progress toward next rank."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var rank_progress: Dictionary = progression_tracker.get_next_rank_progress(test_pilot_stats)
	
	# Assert
	assert_dict(rank_progress).is_not_empty()
	assert_float(rank_progress.get("progress", 0.0)).is_between(0.0, 1.0)
	assert_dict(rank_progress).contains_keys(["progress", "requirements_met"])

func test_rank_progress_calculation() -> void:
	"""Test rank progress calculation accuracy."""
	# Arrange
	test_pilot_stats.rank = 1  # Lieutenant JG
	test_pilot_stats.score = 3000  # Halfway to Lieutenant (5000 required)
	test_pilot_stats.kill_count_ok = 7  # Partway to 10 required
	test_pilot_stats.missions_flown = 5  # Partway to 7 required
	
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var rank_progress: Dictionary = progression_tracker.get_next_rank_progress(test_pilot_stats)
	
	# Assert
	var requirements: Dictionary = rank_progress.get("requirements_met", {})
	assert_dict(requirements).contains_keys(["points", "kills", "missions"])
	
	# Check individual requirement progress
	var points_req: Dictionary = requirements.get("points", {})
	assert_float(points_req.get("progress", 0.0)).is_equal(0.6)  # 3000/5000

func test_max_rank_handling() -> void:
	"""Test handling when pilot is at maximum rank."""
	# Arrange
	test_pilot_stats.rank = 9  # Admiral (max rank)
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var rank_progress: Dictionary = progression_tracker.get_next_rank_progress(test_pilot_stats)
	
	# Assert
	assert_bool(rank_progress.get("is_max_rank", false)).is_true()

# ============================================================================
# MEDAL PROGRESSION TESTS
# ============================================================================

func test_get_medal_progress() -> void:
	"""Test getting medal progress."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var medal_progress: Array[Dictionary] = progression_tracker.get_medal_progress(test_pilot_stats)
	
	# Assert
	assert_array(medal_progress).is_not_empty()
	
	# Check first medal progress entry
	var first_medal: Dictionary = medal_progress[0]
	assert_dict(first_medal).contains_keys(["medal", "progress"])
	assert_object(first_medal.get("medal")).is_not_null()
	assert_dict(first_medal.get("progress")).is_not_empty()

func test_medal_progress_sorting() -> void:
	"""Test that medal progress is sorted by completion."""
	# Arrange
	test_pilot_stats.kill_count_ok = 12  # Close to Silver Cluster (25 kills)
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var medal_progress: Array[Dictionary] = progression_tracker.get_medal_progress(test_pilot_stats)
	
	# Assert - Should be sorted by progress (highest first)
	assert_array(medal_progress).is_not_empty()
	
	if medal_progress.size() > 1:
		var first_progress: float = medal_progress[0].progress.get("progress", 0.0)
		var second_progress: float = medal_progress[1].progress.get("progress", 0.0)
		assert_float(first_progress).is_greater_equal(second_progress)

func test_earned_medal_exclusion() -> void:
	"""Test that earned medals are excluded from progress tracking."""
	# Arrange
	test_earned_medals.append("Silver Cluster")  # Add another earned medal
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var medal_progress: Array[Dictionary] = progression_tracker.get_medal_progress(test_pilot_stats)
	
	# Assert - Earned medals should not appear in progress
	for medal_data in medal_progress:
		var medal: MedalData = medal_data.medal
		assert_array(test_earned_medals).not_contains([medal.name])

# ============================================================================
# MILESTONE TRACKING TESTS
# ============================================================================

func test_milestone_achievement_detection() -> void:
	"""Test milestone achievement detection."""
	# Arrange - Set stats to trigger milestones
	test_pilot_stats.kill_count_ok = 5  # Should trigger ace_status
	test_pilot_stats.missions_flown = 20  # Should trigger veteran_status
	
	var signal_monitor: SignalWatcher = watch_signals(progression_tracker)
	
	# Act
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Assert
	assert_signal(signal_monitor).is_emitted("milestone_reached")

func test_first_kill_milestone() -> void:
	"""Test first kill milestone detection."""
	# Arrange
	test_pilot_stats.kill_count_ok = 1
	var signal_monitor: SignalWatcher = watch_signals(progression_tracker)
	
	# Act
	progression_tracker._check_milestone_achievements(test_pilot_stats)
	
	# Assert
	var milestone: Dictionary = progression_tracker.milestone_tracking.get("first_kill", {})
	assert_bool(milestone.get("achieved", false)).is_true()

func test_accuracy_milestone() -> void:
	"""Test accuracy milestone detection."""
	# Arrange
	test_pilot_stats.primary_shots_fired = 1000
	test_pilot_stats.primary_shots_hit = 600
	test_pilot_stats.secondary_shots_fired = 100
	test_pilot_stats.secondary_shots_hit = 80
	test_pilot_stats._update_calculated_stats()  # Should give 68% total accuracy
	
	# Act
	progression_tracker._check_milestone_achievements(test_pilot_stats)
	
	# Assert
	var milestone: Dictionary = progression_tracker.milestone_tracking.get("marksman_level", {})
	assert_bool(milestone.get("achieved", false)).is_true()

func test_milestone_no_duplicate_achievements() -> void:
	"""Test that milestones are not achieved multiple times."""
	# Arrange
	test_pilot_stats.kill_count_ok = 5
	progression_tracker._check_milestone_achievements(test_pilot_stats)
	var signal_monitor: SignalWatcher = watch_signals(progression_tracker)
	
	# Act - Check again with same stats
	progression_tracker._check_milestone_achievements(test_pilot_stats)
	
	# Assert - Should not emit signal again
	assert_signal(signal_monitor).is_not_emitted("milestone_reached")

# ============================================================================
# ACHIEVEMENT SUMMARY TESTS
# ============================================================================

func test_get_achievement_summary() -> void:
	"""Test getting comprehensive achievement summary."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var summary: Dictionary = progression_tracker.get_achievement_summary(test_pilot_stats)
	
	# Assert
	assert_dict(summary).is_not_empty()
	assert_dict(summary).contains_keys(["rank_info", "medal_info", "milestone_info"])

func test_achievement_summary_rank_info() -> void:
	"""Test rank information in achievement summary."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var summary: Dictionary = progression_tracker.get_achievement_summary(test_pilot_stats)
	var rank_info: Dictionary = summary.get("rank_info", {})
	
	# Assert
	assert_dict(rank_info).contains_keys(["current_rank", "current_rank_name", "next_rank_progress", "is_max_rank"])
	assert_int(rank_info.get("current_rank", -1)).is_equal(test_pilot_stats.rank)

func test_achievement_summary_medal_info() -> void:
	"""Test medal information in achievement summary."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var summary: Dictionary = progression_tracker.get_achievement_summary(test_pilot_stats)
	var medal_info: Dictionary = summary.get("medal_info", {})
	
	# Assert
	assert_dict(medal_info).contains_keys(["earned_count", "total_available", "completion_rate", "next_medals"])
	assert_int(medal_info.get("earned_count", 0)).is_equal(test_earned_medals.size())

# ============================================================================
# PERFORMANCE INSIGHTS TESTS
# ============================================================================

func test_get_performance_insights() -> void:
	"""Test getting performance insights."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var insights: Dictionary = progression_tracker.get_performance_insights(test_pilot_stats)
	
	# Assert
	assert_dict(insights).is_not_empty()
	assert_dict(insights).contains_keys(["strengths", "improvement_areas", "recommendations", "achievements_within_reach"])

func test_performance_insights_strengths() -> void:
	"""Test performance insights strength identification."""
	# Arrange - Set high accuracy
	test_pilot_stats.primary_shots_fired = 1000
	test_pilot_stats.primary_shots_hit = 850
	test_pilot_stats.secondary_shots_fired = 100
	test_pilot_stats.secondary_shots_hit = 85
	test_pilot_stats._update_calculated_stats()  # Should give 85% total accuracy
	
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var insights: Dictionary = progression_tracker.get_performance_insights(test_pilot_stats)
	var strengths: Array = insights.get("strengths", [])
	
	# Assert
	assert_array(strengths).contains(["Excellent weapon accuracy"])

func test_performance_insights_improvement_areas() -> void:
	"""Test performance insights improvement area identification."""
	# Arrange - Set low accuracy and friendly fire
	test_pilot_stats.primary_shots_fired = 1000
	test_pilot_stats.primary_shots_hit = 400  # 40% accuracy
	test_pilot_stats.friendly_kills = 1
	test_pilot_stats._update_calculated_stats()
	
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var insights: Dictionary = progression_tracker.get_performance_insights(test_pilot_stats)
	var improvement_areas: Array = insights.get("improvement_areas", [])
	
	# Assert
	assert_array(improvement_areas).contains(["Weapon accuracy needs improvement"])
	assert_array(improvement_areas).contains(["Friendly fire incidents"])

func test_achievements_within_reach() -> void:
	"""Test identification of achievements within reach."""
	# Arrange - Set stats close to medal requirement
	test_pilot_stats.kill_count_ok = 22  # Close to Silver Cluster (25 kills)
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var insights: Dictionary = progression_tracker.get_performance_insights(test_pilot_stats)
	var within_reach: Array = insights.get("achievements_within_reach", [])
	
	# Assert
	assert_array(within_reach).is_not_empty()
	
	# Check if any achievement is close to completion
	for achievement in within_reach:
		assert_float(achievement.get("progress", 0.0)).is_greater(0.7)

# ============================================================================
# PROGRESSION STATISTICS TESTS
# ============================================================================

func test_get_progression_statistics() -> void:
	"""Test getting progression tracking statistics."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var stats: Dictionary = progression_tracker.get_progression_statistics()
	
	# Assert
	assert_dict(stats).is_not_empty()
	assert_dict(stats).contains_keys([
		"available_ranks", "available_medals", "earned_medals", "current_rank",
		"milestones_total", "milestones_achieved", "last_check_time", "calculation_time"
	])

func test_progression_statistics_accuracy() -> void:
	"""Test accuracy of progression statistics."""
	# Arrange
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	# Act
	var stats: Dictionary = progression_tracker.get_progression_statistics()
	
	# Assert
	assert_int(stats.get("earned_medals", 0)).is_equal(test_earned_medals.size())
	assert_int(stats.get("current_rank", -1)).is_equal(test_pilot_stats.rank)
	assert_int(stats.get("available_ranks", 0)).is_greater(0)
	assert_int(stats.get("available_medals", 0)).is_greater(0)

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_handles_null_pilot_stats() -> void:
	"""Test handling of null pilot statistics."""
	# Act & Assert - Should not crash
	progression_tracker.update_pilot_progress(null, test_earned_medals)
	
	var rank_progress: Dictionary = progression_tracker.get_next_rank_progress(null)
	assert_dict(rank_progress).is_empty()
	
	var medal_progress: Array[Dictionary] = progression_tracker.get_medal_progress(null)
	assert_array(medal_progress).is_empty()

func test_handles_empty_earned_medals() -> void:
	"""Test handling of empty earned medals array."""
	# Act & Assert - Should not crash
	progression_tracker.update_pilot_progress(test_pilot_stats, [])
	
	var summary: Dictionary = progression_tracker.get_achievement_summary(test_pilot_stats)
	assert_dict(summary).is_not_empty()

func test_handles_invalid_rank() -> void:
	"""Test handling of invalid rank values."""
	# Arrange
	test_pilot_stats.rank = -1  # Invalid rank
	
	# Act & Assert - Should handle gracefully
	progression_tracker.update_pilot_progress(test_pilot_stats, test_earned_medals)
	
	var rank_progress: Dictionary = progression_tracker.get_next_rank_progress(test_pilot_stats)
	# Should either handle gracefully or return appropriate error state

# ============================================================================
# HELPER METHODS
# ============================================================================

func _setup_test_pilot_statistics() -> void:
	"""Setup test pilot statistics with realistic values."""
	test_pilot_stats.score = 12000
	test_pilot_stats.rank = 2  # Lieutenant
	test_pilot_stats.missions_flown = 10
	test_pilot_stats.flight_time = 7200  # 2 hours
	test_pilot_stats.kill_count = 22
	test_pilot_stats.kill_count_ok = 20
	test_pilot_stats.assists = 8
	test_pilot_stats.primary_shots_fired = 3000
	test_pilot_stats.primary_shots_hit = 2100
	test_pilot_stats.secondary_shots_fired = 120
	test_pilot_stats.secondary_shots_hit = 96
	test_pilot_stats.primary_friendly_hits = 15
	test_pilot_stats.secondary_friendly_hits = 2
	test_pilot_stats.friendly_kills = 0
	test_pilot_stats.last_flown = Time.get_unix_time_from_system()
	test_pilot_stats._update_calculated_stats()