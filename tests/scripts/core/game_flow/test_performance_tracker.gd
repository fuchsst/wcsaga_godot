extends GdUnitTestSuite

## Unit tests for PerformanceTracker system
## Tests detailed combat effectiveness and mission performance metrics

# Test fixtures
var performance_tracker: PerformanceTracker

func before_test() -> void:
	performance_tracker = PerformanceTracker.new()

func after_test() -> void:
	performance_tracker = null

## Test weapon fire recording
func test_record_weapon_fire_basic() -> void:
	performance_tracker.record_weapon_fire("primary_laser", true, 15.0)
	performance_tracker.record_weapon_fire("primary_laser", false, 0.0)
	performance_tracker.record_weapon_fire("secondary_missile", true, 45.0)
	
	var summary = performance_tracker.get_performance_summary()
	assert_int(summary["shots_fired"]).is_equal(3)
	assert_int(summary["shots_hit"]).is_equal(2)
	assert_float(summary["accuracy"]).is_equal(66.666666666666666)  # 2/3 * 100

func test_weapon_usage_tracking() -> void:
	# Record weapon usage for different weapons
	performance_tracker.record_weapon_fire("primary_laser", true, 10.0)
	performance_tracker.record_weapon_fire("primary_laser", true, 12.0)
	performance_tracker.record_weapon_fire("primary_laser", false, 0.0)
	performance_tracker.record_weapon_fire("secondary_missile", true, 50.0)
	
	# Check weapon usage stats
	var weapon_usage = performance_tracker._weapon_usage
	assert_that(weapon_usage.has("primary_laser")).is_true()
	assert_that(weapon_usage.has("secondary_missile")).is_true()
	
	var laser_stats = weapon_usage["primary_laser"]
	assert_int(laser_stats["shots_fired"]).is_equal(3)
	assert_int(laser_stats["shots_hit"]).is_equal(2)
	assert_float(laser_stats["total_damage"]).is_equal(22.0)
	
	var missile_stats = weapon_usage["secondary_missile"]
	assert_int(missile_stats["shots_fired"]).is_equal(1)
	assert_int(missile_stats["shots_hit"]).is_equal(1)
	assert_float(missile_stats["total_damage"]).is_equal(50.0)

## Test kill recording
func test_record_kill() -> void:
	var kill_data = KillData.new()
	kill_data.target_type = "fighter"
	kill_data.target_class = "light"
	kill_data.weapon_used = "primary_laser"
	kill_data.kill_method = "normal"
	kill_data.score_value = 50
	kill_data.timestamp = Time.get_unix_time_from_system()
	
	# First record weapon usage for the weapon
	performance_tracker.record_weapon_fire("primary_laser", true, 15.0)
	
	# Then record the kill
	performance_tracker.record_kill(kill_data)
	
	var summary = performance_tracker.get_performance_summary()
	assert_int(summary["kills"]).is_equal(1)
	
	# Check that weapon kill count is updated
	var weapon_usage = performance_tracker._weapon_usage
	assert_int(weapon_usage["primary_laser"]["kills"]).is_equal(1)

func test_multiple_kills() -> void:
	# Create multiple kill data entries
	var kills = [
		_create_kill_data("fighter", "light", "primary_laser", "normal"),
		_create_kill_data("bomber", "heavy", "secondary_missile", "critical_hit"),
		_create_kill_data("capital", "frigate", "secondary_torpedo", "long_range")
	]
	
	# Record weapon usage first
	performance_tracker.record_weapon_fire("primary_laser", true, 15.0)
	performance_tracker.record_weapon_fire("secondary_missile", true, 45.0)
	performance_tracker.record_weapon_fire("secondary_torpedo", true, 120.0)
	
	# Record kills
	for kill_data in kills:
		performance_tracker.record_kill(kill_data)
	
	var summary = performance_tracker.get_performance_summary()
	assert_int(summary["kills"]).is_equal(3)
	assert_int(summary["weapon_count"]).is_equal(3)

## Test damage recording
func test_record_damage() -> void:
	var damage_event = DamageEvent.new()
	damage_event.damage_type = "laser"
	damage_event.damage_amount = 25.5
	damage_event.source = "enemy_fighter"
	damage_event.timestamp = Time.get_unix_time_from_system()
	damage_event.is_critical = false
	
	performance_tracker.record_damage(damage_event)
	
	assert_int(performance_tracker._damage_taken_events.size()).is_equal(1)
	
	var recorded_event = performance_tracker._damage_taken_events[0]
	assert_float(recorded_event.damage_amount).is_equal(25.5)
	assert_str(recorded_event.damage_type).is_equal("laser")

## Test tactical event recording
func test_record_tactical_event() -> void:
	performance_tracker.record_tactical_event("formation_maintained", {"duration": 60})
	performance_tracker.record_tactical_event("wingman_assisted", {"target": "bomber_01"})
	
	assert_int(performance_tracker._tactical_events.size()).is_equal(2)
	
	var first_event = performance_tracker._tactical_events[0]
	assert_str(first_event.event_type).is_equal("formation_maintained")
	assert_that(first_event.event_data.has("duration")).is_true()
	assert_that(first_event.timestamp).is_greater(0)

## Test accuracy calculation
func test_calculate_accuracy_percentage() -> void:
	# Test with no shots fired
	assert_float(performance_tracker._calculate_accuracy_percentage()).is_equal(0.0)
	
	# Test with shots fired
	performance_tracker._shots_fired = 10
	performance_tracker._shots_hit = 7
	
	assert_float(performance_tracker._calculate_accuracy_percentage()).is_equal(70.0)

## Test kill efficiency calculation
func test_calculate_kill_efficiency() -> void:
	# Test with no shots fired
	assert_float(performance_tracker._calculate_kill_efficiency()).is_equal(0.0)
	
	# Test with shots and kills
	performance_tracker._shots_fired = 20
	performance_tracker._kills = [
		_create_kill_data("fighter", "light", "primary_laser", "normal"),
		_create_kill_data("bomber", "heavy", "secondary_missile", "normal")
	]
	
	assert_float(performance_tracker._calculate_kill_efficiency()).is_equal(10.0)  # 2/20 * 100

## Test damage efficiency calculation
func test_calculate_damage_efficiency() -> void:
	# Setup weapon usage with damage dealt
	performance_tracker._weapon_usage = {
		"primary_laser": {
			"total_damage": 100.0
		},
		"secondary_missile": {
			"total_damage": 200.0
		}
	}
	
	# Setup damage taken
	var damage_event = DamageEvent.new()
	damage_event.damage_amount = 50.0
	performance_tracker._damage_taken_events = [damage_event]
	
	var efficiency = performance_tracker._calculate_damage_efficiency()
	assert_float(efficiency).is_equal(6.0)  # (100 + 200) / 50

func test_calculate_damage_efficiency_perfect() -> void:
	# Test perfect efficiency (no damage taken)
	performance_tracker._weapon_usage = {
		"primary_laser": {
			"total_damage": 100.0
		}
	}
	performance_tracker._damage_taken_events = []
	
	var efficiency = performance_tracker._calculate_damage_efficiency()
	assert_float(efficiency).is_equal(999.0)  # Perfect efficiency

## Test weapon proficiency calculation
func test_calculate_weapon_proficiency() -> void:
	# Setup weapon usage stats
	performance_tracker._weapon_usage = {
		"primary_laser": {
			"shots_fired": 10,
			"shots_hit": 8,
			"total_damage": 120.0,
			"kills": 2
		},
		"secondary_missile": {
			"shots_fired": 5,
			"shots_hit": 4,
			"total_damage": 200.0,
			"kills": 3
		}
	}
	
	var proficiency = performance_tracker._calculate_weapon_proficiency()
	
	assert_that(proficiency.has("primary_laser")).is_true()
	assert_that(proficiency.has("secondary_missile")).is_true()
	
	var laser_prof = proficiency["primary_laser"]
	assert_float(laser_prof["accuracy"]).is_equal(80.0)  # 8/10 * 100
	assert_float(laser_prof["damage_per_shot"]).is_equal(12.0)  # 120/10
	assert_float(laser_prof["kill_ratio"]).is_equal(20.0)  # 2/10 * 100

## Test damage avoidance rating calculation
func test_calculate_damage_avoidance_rating() -> void:
	# Setup mission timing
	performance_tracker._mission_start_time = 1000
	performance_tracker._mission_end_time = 1060  # 1 minute mission
	
	# Test with no damage
	var rating = performance_tracker._calculate_damage_avoidance_rating()
	assert_float(rating).is_equal(100.0)
	
	# Test with damage
	var damage_event = DamageEvent.new()
	damage_event.damage_amount = 30.0
	performance_tracker._damage_taken_events = [damage_event]
	
	rating = performance_tracker._calculate_damage_avoidance_rating()
	assert_that(rating).is_less_than(100.0)

## Test close calls counting
func test_count_close_calls() -> void:
	# Add various damage events
	var damage_events = [
		_create_damage_event("laser", 10.0),    # Not a close call
		_create_damage_event("missile", 35.0),  # Close call
		_create_damage_event("laser", 50.0),    # Close call
		_create_damage_event("collision", 15.0) # Not a close call
	]
	
	performance_tracker._damage_taken_events = damage_events
	
	var close_calls = performance_tracker._count_close_calls()
	assert_int(close_calls).is_equal(2)  # Only 35.0 and 50.0 > 30.0

## Test tactical score calculation
func test_calculate_tactical_score() -> void:
	# Test base score
	var score = performance_tracker._calculate_tactical_score()
	assert_float(score).is_equal(50.0)  # Base score
	
	# Add tactical events
	performance_tracker._tactical_events = [
		_create_tactical_event("formation_maintained", {}),
		_create_tactical_event("wingman_assisted", {}),
		_create_tactical_event("defensive_maneuver", {}),
		_create_tactical_event("team_coordination", {})
	]
	
	score = performance_tracker._calculate_tactical_score()
	assert_that(score).is_greater(50.0)  # Should be improved
	assert_that(score).is_less_equal(100.0)  # Capped at 100

## Test improvement areas identification
func test_identify_improvement_areas() -> void:
	# Setup poor performance metrics
	performance_tracker._shots_fired = 100
	performance_tracker._shots_hit = 20  # 20% accuracy (poor)
	performance_tracker._kills = []     # No kills (poor efficiency)
	
	# Add many close calls
	for i in range(8):
		performance_tracker._damage_taken_events.append(_create_damage_event("laser", 35.0))
	
	var areas = performance_tracker._identify_improvement_areas()
	
	assert_that(areas).contains("weapon_accuracy")
	assert_that(areas).contains("target_acquisition")
	assert_that(areas).contains("defensive_flying")
	assert_that(areas).contains("weapon_conservation")

## Test strengths identification
func test_identify_strengths() -> void:
	# Setup excellent performance metrics
	performance_tracker._shots_fired = 100
	performance_tracker._shots_hit = 85  # 85% accuracy (excellent)
	performance_tracker._kills = Array(range(25), TYPE_OBJECT, "", null)  # 25% kill efficiency (excellent)
	
	# Setup weapon usage for damage efficiency
	performance_tracker._weapon_usage = {
		"primary_laser": {
			"total_damage": 1000.0
		}
	}
	performance_tracker._damage_taken_events = [_create_damage_event("laser", 50.0)]  # 20:1 ratio (excellent)
	
	# No close calls (excellent survival)
	# (damage events above don't count as close calls since they're exactly 30.0 threshold)
	
	var strengths = performance_tracker._identify_strengths()
	
	assert_that(strengths).contains("excellent_accuracy")
	assert_that(strengths).contains("lethal_effectiveness")
	assert_that(strengths).contains("combat_dominance")

## Test performance analysis generation
func test_generate_analysis() -> void:
	# Setup some performance data
	performance_tracker.record_weapon_fire("primary_laser", true, 15.0)
	performance_tracker.record_weapon_fire("primary_laser", true, 12.0)
	performance_tracker.record_weapon_fire("primary_laser", false, 0.0)
	
	performance_tracker.record_kill(_create_kill_data("fighter", "light", "primary_laser", "normal"))
	performance_tracker.record_damage(_create_damage_event("laser", 25.0))
	performance_tracker.record_tactical_event("formation_maintained", {"duration": 30})
	
	var analysis = performance_tracker.generate_analysis()
	
	assert_that(analysis).is_not_null()
	assert_that(analysis.accuracy_percentage).is_greater(0.0)
	assert_that(analysis.kill_efficiency).is_greater(0.0)
	assert_that(analysis.damage_efficiency).is_greater(0.0)
	assert_that(analysis.weapon_proficiency).is_not_null()
	assert_that(analysis.damage_avoidance_rating).is_greater(0.0)
	assert_that(analysis.tactical_score).is_greater(0.0)
	assert_that(analysis.improvement_areas).is_not_null()
	assert_that(analysis.strengths).is_not_null()

## Test performance analysis grading
func test_performance_analysis_grading() -> void:
	var analysis = PerformanceAnalysis.new()
	
	# Test excellent performance
	analysis.accuracy_percentage = 95.0
	analysis.damage_efficiency = 10.0
	analysis.tactical_score = 90.0
	analysis.damage_avoidance_rating = 95.0
	analysis.kill_efficiency = 25.0
	
	var rating = analysis.get_overall_performance_rating()
	var grade = analysis.get_performance_grade()
	
	assert_that(rating).is_greater(90.0)
	assert_str(grade).is_equal("S")

func test_performance_analysis_poor_grading() -> void:
	var analysis = PerformanceAnalysis.new()
	
	# Test poor performance
	analysis.accuracy_percentage = 30.0
	analysis.damage_efficiency = 1.0
	analysis.tactical_score = 40.0
	analysis.damage_avoidance_rating = 30.0
	analysis.kill_efficiency = 5.0
	
	var rating = analysis.get_overall_performance_rating()
	var grade = analysis.get_performance_grade()
	
	assert_that(rating).is_less(50.0)
	assert_str(grade).is_equal("F")

## Helper functions
func _create_kill_data(target_type: String, target_class: String, weapon_used: String, kill_method: String) -> KillData:
	var kill_data = KillData.new()
	kill_data.target_type = target_type
	kill_data.target_class = target_class
	kill_data.weapon_used = weapon_used
	kill_data.kill_method = kill_method
	kill_data.score_value = 50
	kill_data.timestamp = Time.get_unix_time_from_system()
	return kill_data

func _create_damage_event(damage_type: String, damage_amount: float) -> DamageEvent:
	var damage_event = DamageEvent.new()
	damage_event.damage_type = damage_type
	damage_event.damage_amount = damage_amount
	damage_event.source = "test_source"
	damage_event.timestamp = Time.get_unix_time_from_system()
	damage_event.is_critical = damage_amount > 50.0
	return damage_event

func _create_tactical_event(event_type: String, event_data: Dictionary) -> TacticalEvent:
	var tactical_event = TacticalEvent.new()
	tactical_event.event_type = event_type
	tactical_event.event_data = event_data
	tactical_event.timestamp = Time.get_unix_time_from_system()
	return tactical_event