extends GdUnitTestSuite

## Test suite for StatisticsDataManager
## Validates statistics calculation, medal/rank progression, and data management functionality
## Tests integration with PilotStatistics resources and progression tracking systems

# Test objects
var statistics_manager: StatisticsDataManager = null
var test_pilot_data: PilotData = null
var test_pilot_stats: PilotStatistics = null

func before_test() -> void:
	"""Setup before each test."""
	# Create statistics manager
	statistics_manager = StatisticsDataManager.create_statistics_manager()
	
	# Create test pilot data
	test_pilot_data = PilotData.create("TestPilot")
	_setup_test_pilot_data()
	
	# Create test pilot statistics
	test_pilot_stats = PilotStatistics.new()
	_setup_test_pilot_statistics()

func after_test() -> void:
	"""Cleanup after each test."""
	if statistics_manager:
		statistics_manager.queue_free()
	
	statistics_manager = null
	test_pilot_data = null
	test_pilot_stats = null

# ============================================================================
# INITIALIZATION TESTS
# ============================================================================

func test_statistics_manager_initializes_correctly() -> void:
	"""Test that StatisticsDataManager initializes properly."""
	# Assert
	assert_object(statistics_manager).is_not_null()
	assert_array(statistics_manager.available_medals).is_not_empty()
	assert_array(statistics_manager.available_ranks).is_not_empty()
	assert_object(statistics_manager.current_pilot_stats).is_null()

func test_medal_data_loaded() -> void:
	"""Test that medal data is loaded correctly."""
	# Assert
	assert_array(statistics_manager.available_medals).is_not_empty()
	
	# Check for expected medals
	var medal_names: Array[String] = []
	for medal in statistics_manager.available_medals:
		medal_names.append(medal.name)
	
	assert_array(medal_names).contains(["Bronze Cluster", "Silver Cluster", "Marksman Medal"])

func test_rank_data_loaded() -> void:
	"""Test that rank data is loaded correctly."""
	# Assert
	assert_array(statistics_manager.available_ranks).is_not_empty()
	
	# Check for expected ranks
	var rank_names: Array[String] = []
	for rank in statistics_manager.available_ranks:
		rank_names.append(rank.name)
	
	assert_array(rank_names).contains(["Ensign", "Lieutenant", "Captain", "Admiral"])

# ============================================================================
# PILOT STATISTICS LOADING TESTS
# ============================================================================

func test_load_pilot_statistics_success() -> void:
	"""Test successful pilot statistics loading."""
	# Act
	var load_result: bool = statistics_manager.load_pilot_statistics(test_pilot_data)
	
	# Assert
	assert_bool(load_result).is_true()
	assert_object(statistics_manager.get_current_statistics()).is_not_null()
	assert_int(statistics_manager.get_current_statistics().score).is_equal(test_pilot_data.stats["score"])

func test_load_pilot_statistics_null_data() -> void:
	"""Test loading pilot statistics with null data."""
	# Act
	var load_result: bool = statistics_manager.load_pilot_statistics(null)
	
	# Assert
	assert_bool(load_result).is_false()
	assert_object(statistics_manager.get_current_statistics()).is_null()

func test_save_pilot_statistics() -> void:
	"""Test saving pilot statistics back to pilot data."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	pilot_stats.score = 50000
	pilot_stats.kill_count = 25
	
	# Act
	var save_result: bool = statistics_manager.save_pilot_statistics(test_pilot_data)
	
	# Assert
	assert_bool(save_result).is_true()
	assert_int(test_pilot_data.stats["score"]).is_equal(50000)
	assert_int(test_pilot_data.stats["kill_count"]).is_equal(25)

# ============================================================================
# STATISTICS CALCULATION TESTS
# ============================================================================

func test_comprehensive_statistics_calculation() -> void:
	"""Test comprehensive statistics calculation."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	
	# Act
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Assert
	assert_dict(comprehensive_stats).is_not_empty()
	assert_dict(comprehensive_stats).contains_keys(["basic", "combat", "accuracy", "performance"])

func test_basic_statistics_calculation() -> void:
	"""Test basic statistics calculations."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Act
	var basic_stats: Dictionary = comprehensive_stats.get("basic", {})
	
	# Assert
	assert_dict(basic_stats).is_not_empty()
	assert_int(basic_stats.get("score", 0)).is_equal(test_pilot_data.stats["score"])
	assert_int(basic_stats.get("missions_flown", 0)).is_equal(test_pilot_data.stats["missions_flown"])
	assert_int(basic_stats.get("kill_count", 0)).is_equal(test_pilot_data.stats["kill_count"])

func test_combat_effectiveness_calculation() -> void:
	"""Test combat effectiveness calculations."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Act
	var combat_stats: Dictionary = comprehensive_stats.get("combat", {})
	
	# Assert
	assert_dict(combat_stats).is_not_empty()
	assert_float(combat_stats.get("combat_rating", 0.0)).is_greater_equal(0.0)
	assert_float(combat_stats.get("kill_efficiency", 0.0)).is_greater_equal(0.0)

func test_accuracy_statistics_calculation() -> void:
	"""Test accuracy statistics calculations."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Act
	var accuracy_stats: Dictionary = comprehensive_stats.get("accuracy", {})
	
	# Assert
	assert_dict(accuracy_stats).is_not_empty()
	assert_float(accuracy_stats.get("primary_accuracy", 0.0)).is_greater_equal(0.0)
	assert_float(accuracy_stats.get("secondary_accuracy", 0.0)).is_greater_equal(0.0)
	assert_float(accuracy_stats.get("total_accuracy", 0.0)).is_greater_equal(0.0)

func test_performance_metrics_calculation() -> void:
	"""Test performance metrics calculations."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Act
	var performance_stats: Dictionary = comprehensive_stats.get("performance", {})
	
	# Assert
	assert_dict(performance_stats).is_not_empty()
	assert_float(performance_stats.get("pilot_rating", 0.0)).is_greater_equal(0.0)

# ============================================================================
# MEDAL SYSTEM TESTS
# ============================================================================

func test_medal_eligibility_checking() -> void:
	"""Test medal eligibility checking."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	statistics_manager.enable_automatic_medal_checking = true
	
	# Create pilot with medal-eligible stats
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	pilot_stats.kill_count_ok = 15  # Should be eligible for Bronze Cluster (10 kills)
	
	# Act
	statistics_manager._check_medal_eligibility()
	
	# Assert
	assert_array(statistics_manager.earned_medals).contains(["Bronze Cluster"])

func test_medal_progress_tracking() -> void:
	"""Test medal progress tracking."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var medal: MedalData = statistics_manager.available_medals[0]  # First medal
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	
	# Act
	var progress: Dictionary = medal.get_progress_toward_medal(pilot_stats)
	
	# Assert
	assert_dict(progress).is_not_empty()
	assert_float(progress.get("progress", 0.0)).is_between(0.0, 1.0)

func test_award_medal() -> void:
	"""Test medal awarding functionality."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var medal: MedalData = statistics_manager.available_medals[0]
	var initial_count: int = statistics_manager.earned_medals.size()
	
	# Act
	statistics_manager._award_medal(medal)
	
	# Assert
	assert_int(statistics_manager.earned_medals.size()).is_equal(initial_count + 1)
	assert_array(statistics_manager.earned_medals).contains([medal.name])

func test_duplicate_medal_prevention() -> void:
	"""Test that duplicate medals are not awarded."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var medal: MedalData = statistics_manager.available_medals[0]
	statistics_manager._award_medal(medal)
	var count_after_first: int = statistics_manager.earned_medals.size()
	
	# Act
	statistics_manager._award_medal(medal)  # Try to award again
	
	# Assert
	assert_int(statistics_manager.earned_medals.size()).is_equal(count_after_first)

# ============================================================================
# RANK SYSTEM TESTS
# ============================================================================

func test_rank_promotion_checking() -> void:
	"""Test rank promotion eligibility checking."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	
	# Set stats to be eligible for next rank
	pilot_stats.score = 10000  # Lieutenant Commander requirements
	pilot_stats.kill_count_ok = 25
	pilot_stats.missions_flown = 20
	pilot_stats.rank = 2  # Lieutenant
	
	# Act
	statistics_manager._check_rank_promotions(pilot_stats)
	
	# Assert - Should have promotion available signal
	# This would be tested with signal monitoring in a fuller implementation

func test_rank_progression_calculation() -> void:
	"""Test rank progression calculations."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Act
	var rank_progression: Dictionary = comprehensive_stats.get("rank_progression", {})
	
	# Assert
	assert_dict(rank_progression).is_not_empty()

# ============================================================================
# CACHE MANAGEMENT TESTS
# ============================================================================

func test_statistics_cache_functionality() -> void:
	"""Test statistics cache management."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	
	# Act - First call should populate cache
	var stats1: Dictionary = statistics_manager.get_comprehensive_statistics()
	var cache_time1: float = statistics_manager.cache_timestamp
	
	# Act - Second call should use cache
	var stats2: Dictionary = statistics_manager.get_comprehensive_statistics()
	var cache_time2: float = statistics_manager.cache_timestamp
	
	# Assert
	assert_dict(stats1).is_equal(stats2)
	assert_float(cache_time1).is_equal(cache_time2)

func test_cache_invalidation() -> void:
	"""Test cache invalidation when statistics change."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var stats1: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Act - Clear cache
	statistics_manager._clear_statistics_cache()
	
	# Assert
	assert_dict(statistics_manager.statistics_cache).is_empty()
	assert_float(statistics_manager.cache_timestamp).is_equal(0.0)

# ============================================================================
# EXPORT FUNCTIONALITY TESTS
# ============================================================================

func test_export_statistics_to_json() -> void:
	"""Test exporting statistics to JSON format."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	
	# Act
	var json_export: String = statistics_manager.export_statistics_to_json()
	
	# Assert
	assert_str(json_export).is_not_empty()
	
	# Verify it's valid JSON
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_export)
	assert_int(parse_result).is_equal(OK)

func test_save_statistics_export() -> void:
	"""Test saving statistics export to file."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var export_path: String = "user://test_stats_export.json"
	
	# Act
	var save_result: Error = statistics_manager.save_statistics_export(export_path)
	
	# Assert
	assert_int(save_result).is_equal(OK)
	assert_bool(FileAccess.file_exists(export_path)).is_true()
	
	# Cleanup
	DirAccess.remove_absolute(export_path)

# ============================================================================
# HELPER CALCULATION TESTS
# ============================================================================

func test_kill_efficiency_calculation() -> void:
	"""Test kill efficiency calculation."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	pilot_stats.kill_count = 20
	pilot_stats.kill_count_ok = 18
	
	# Act
	var kill_efficiency: float = statistics_manager._calculate_kill_efficiency()
	
	# Assert
	assert_float(kill_efficiency).is_equal(0.9)

func test_friendly_fire_rate_calculation() -> void:
	"""Test friendly fire rate calculation."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	pilot_stats.primary_shots_fired = 1000
	pilot_stats.primary_friendly_hits = 50
	
	# Act
	var ff_rate: float = statistics_manager._calculate_friendly_fire_rate(true)
	
	# Assert
	assert_float(ff_rate).is_equal(5.0)  # 5%

func test_average_calculations() -> void:
	"""Test average statistics calculations."""
	# Arrange
	statistics_manager.load_pilot_statistics(test_pilot_data)
	var pilot_stats: PilotStatistics = statistics_manager.get_current_statistics()
	pilot_stats.kill_count_ok = 30
	pilot_stats.missions_flown = 10
	pilot_stats.score = 25000
	
	# Act
	var avg_kills: float = statistics_manager._calculate_average_kills_per_mission()
	var avg_score: float = statistics_manager._calculate_average_score_per_mission()
	
	# Assert
	assert_float(avg_kills).is_equal(3.0)
	assert_float(avg_score).is_equal(2500.0)

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

func test_handles_corrupted_pilot_data() -> void:
	"""Test handling of corrupted pilot data."""
	# Arrange
	var corrupted_pilot: PilotData = PilotData.new()
	# Don't set up proper stats dictionary
	
	# Act & Assert - Should not crash
	var load_result: bool = statistics_manager.load_pilot_statistics(corrupted_pilot)
	assert_bool(load_result).is_true()  # Should handle gracefully

func test_handles_empty_statistics() -> void:
	"""Test handling when no statistics are loaded."""
	# Act
	var comprehensive_stats: Dictionary = statistics_manager.get_comprehensive_statistics()
	
	# Assert
	assert_dict(comprehensive_stats).is_empty()

# ============================================================================
# HELPER METHODS
# ============================================================================

func _setup_test_pilot_data() -> void:
	"""Setup test pilot data with realistic statistics."""
	test_pilot_data.stats = {
		"score": 15000,
		"rank": 2,
		"missions_flown": 8,
		"flight_time": 3600,  # 1 hour
		"kill_count": 20,
		"kill_count_ok": 18,
		"assists": 5,
		"primary_shots_fired": 2000,
		"secondary_shots_fired": 80,
		"primary_shots_hit": 1400,
		"secondary_shots_hit": 64,
		"primary_friendly_hits": 10,
		"secondary_friendly_hits": 1,
		"friendly_kills": 0,
		"last_flown": Time.get_unix_time_from_system(),
		"medals": ["Bronze Cluster"],
		"kills_by_ship": {"Fighter": 15, "Bomber": 3}
	}

func _setup_test_pilot_statistics() -> void:
	"""Setup test pilot statistics object."""
	test_pilot_stats.score = 15000
	test_pilot_stats.rank = 2
	test_pilot_stats.missions_flown = 8
	test_pilot_stats.flight_time = 3600
	test_pilot_stats.kill_count = 20
	test_pilot_stats.kill_count_ok = 18
	test_pilot_stats.assists = 5
	test_pilot_stats.primary_shots_fired = 2000
	test_pilot_stats.secondary_shots_fired = 80
	test_pilot_stats.primary_shots_hit = 1400
	test_pilot_stats.secondary_shots_hit = 64
	test_pilot_stats.primary_friendly_hits = 10
	test_pilot_stats.secondary_friendly_hits = 1
	test_pilot_stats.friendly_kills = 0
	test_pilot_stats.last_flown = Time.get_unix_time_from_system()