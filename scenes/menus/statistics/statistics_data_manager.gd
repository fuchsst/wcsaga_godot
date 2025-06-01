class_name StatisticsDataManager
extends Node

## Statistics data management system for pilot statistics, medals, and rank progression.
## Provides comprehensive tracking and calculation of pilot performance metrics.
## Integrates with PilotStatistics resources and medal/rank systems.

signal statistics_updated(pilot_stats: PilotStatistics)
signal medal_awarded(medal_name: String, medal_data: MedalData)
signal rank_promotion_available(new_rank: RankData)
signal achievement_unlocked(achievement_name: String, achievement_data: Dictionary)

# Data management
var current_pilot_stats: PilotStatistics = null
var available_medals: Array[MedalData] = []
var available_ranks: Array[RankData] = []
var earned_medals: Array[String] = []

# Statistics calculation cache
var statistics_cache: Dictionary = {}
var cache_timestamp: float = 0.0
var cache_expiry_time: float = 5.0

# Configuration
@export var statistics_directory: String = "user://statistics/"
@export var enable_automatic_medal_checking: bool = true
@export var enable_achievement_tracking: bool = true
@export var performance_tracking_enabled: bool = true

# Medal and rank data paths
var medal_data_path: String = "res://data/medals/"
var rank_data_path: String = "res://data/ranks/"

func _ready() -> void:
	"""Initialize statistics data manager."""
	_ensure_statistics_directory()
	_load_medal_data()
	_load_rank_data()

func _ensure_statistics_directory() -> void:
	"""Ensure statistics directory exists."""
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("statistics"):
		dir.make_dir("statistics")

# ============================================================================
# PILOT STATISTICS MANAGEMENT
# ============================================================================

func load_pilot_statistics(pilot_data: PilotData) -> bool:
	"""Load pilot statistics from pilot data."""
	if not pilot_data:
		push_error("StatisticsDataManager: Cannot load statistics from null pilot data")
		return false
	
	# Extract statistics from pilot data
	var pilot_stats: PilotStatistics = PilotStatistics.new()
	
	# Load basic statistics
	pilot_stats.score = pilot_data.stats.get("score", 0)
	pilot_stats.missions_flown = pilot_data.stats.get("missions_flown", 0)
	pilot_stats.flight_time = pilot_data.stats.get("flight_time", 0)
	pilot_stats.kill_count = pilot_data.stats.get("kill_count", 0)
	pilot_stats.kill_count_ok = pilot_data.stats.get("kill_count_ok", 0)
	pilot_stats.assists = pilot_data.stats.get("assists", 0)
	pilot_stats.primary_shots_fired = pilot_data.stats.get("primary_shots_fired", 0)
	pilot_stats.secondary_shots_fired = pilot_data.stats.get("secondary_shots_fired", 0)
	pilot_stats.primary_shots_hit = pilot_data.stats.get("primary_shots_hit", 0)
	pilot_stats.secondary_shots_hit = pilot_data.stats.get("secondary_shots_hit", 0)
	pilot_stats.primary_friendly_hits = pilot_data.stats.get("primary_friendly_hits", 0)
	pilot_stats.secondary_friendly_hits = pilot_data.stats.get("secondary_friendly_hits", 0)
	pilot_stats.friendly_kills = pilot_data.stats.get("friendly_kills", 0)
	pilot_stats.last_flown = pilot_data.stats.get("last_flown", 0)
	
	# Load earned medals
	earned_medals = pilot_data.stats.get("medals", []).duplicate()
	
	# Load kill arrays
	var kills_by_ship: Dictionary = pilot_data.stats.get("kills_by_ship", {})
	for ship_class in kills_by_ship:
		var ship_index: int = _get_ship_class_index(ship_class)
		if ship_index >= 0 and ship_index < pilot_stats.kills.size():
			pilot_stats.kills[ship_index] = kills_by_ship[ship_class]
	
	current_pilot_stats = pilot_stats
	_clear_statistics_cache()
	
	# Check for new medals and promotions
	if enable_automatic_medal_checking:
		_check_medal_eligibility()
		_check_rank_promotion()
	
	statistics_updated.emit(current_pilot_stats)
	return true

func save_pilot_statistics(pilot_data: PilotData) -> bool:
	"""Save current pilot statistics back to pilot data."""
	if not pilot_data or not current_pilot_stats:
		return false
	
	# Update pilot data statistics
	pilot_data.stats["score"] = current_pilot_stats.score
	pilot_data.stats["missions_flown"] = current_pilot_stats.missions_flown
	pilot_data.stats["flight_time"] = current_pilot_stats.flight_time
	pilot_data.stats["kill_count"] = current_pilot_stats.kill_count
	pilot_data.stats["kill_count_ok"] = current_pilot_stats.kill_count_ok
	pilot_data.stats["assists"] = current_pilot_stats.assists
	pilot_data.stats["primary_shots_fired"] = current_pilot_stats.primary_shots_fired
	pilot_data.stats["secondary_shots_fired"] = current_pilot_stats.secondary_shots_fired
	pilot_data.stats["primary_shots_hit"] = current_pilot_stats.primary_shots_hit
	pilot_data.stats["secondary_shots_hit"] = current_pilot_stats.secondary_shots_hit
	pilot_data.stats["primary_friendly_hits"] = current_pilot_stats.primary_friendly_hits
	pilot_data.stats["secondary_friendly_hits"] = current_pilot_stats.secondary_friendly_hits
	pilot_data.stats["friendly_kills"] = current_pilot_stats.friendly_kills
	pilot_data.stats["last_flown"] = current_pilot_stats.last_flown
	pilot_data.stats["medals"] = earned_medals.duplicate()
	
	# Update kills by ship
	var kills_by_ship: Dictionary = {}
	for i in range(current_pilot_stats.kills.size()):
		if current_pilot_stats.kills[i] > 0:
			var ship_class: String = _get_ship_class_name(i)
			if not ship_class.is_empty():
				kills_by_ship[ship_class] = current_pilot_stats.kills[i]
	pilot_data.stats["kills_by_ship"] = kills_by_ship
	
	return true

func get_current_statistics() -> PilotStatistics:
	"""Get current pilot statistics."""
	return current_pilot_stats

# ============================================================================
# STATISTICS CALCULATIONS
# ============================================================================

func get_comprehensive_statistics() -> Dictionary:
	"""Get comprehensive statistics with calculated metrics."""
	if not current_pilot_stats:
		return {}
	
	# Check cache first
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	if current_time - cache_timestamp < cache_expiry_time and not statistics_cache.is_empty():
		return statistics_cache
	
	var stats: Dictionary = {}
	
	# Basic statistics
	stats["basic"] = {
		"score": current_pilot_stats.score,
		"rank": current_pilot_stats.rank,
		"missions_flown": current_pilot_stats.missions_flown,
		"flight_time_seconds": current_pilot_stats.flight_time,
		"flight_time_hours": float(current_pilot_stats.flight_time) / 3600.0,
		"kill_count": current_pilot_stats.kill_count,
		"kill_count_ok": current_pilot_stats.kill_count_ok,
		"assists": current_pilot_stats.assists,
		"friendly_kills": current_pilot_stats.friendly_kills,
		"last_flown": current_pilot_stats.last_flown
	}
	
	# Combat effectiveness
	stats["combat"] = _calculate_combat_effectiveness()
	
	# Accuracy statistics
	stats["accuracy"] = _calculate_accuracy_statistics()
	
	# Performance metrics
	stats["performance"] = _calculate_performance_metrics()
	
	# Historical trends
	stats["trends"] = _calculate_historical_trends()
	
	# Medal and achievement progress
	stats["achievements"] = _calculate_achievement_progress()
	
	# Rank progression
	stats["rank_progression"] = _calculate_rank_progression()
	
	# Update cache
	statistics_cache = stats
	cache_timestamp = current_time
	
	return stats

func _calculate_combat_effectiveness() -> Dictionary:
	"""Calculate combat effectiveness metrics."""
	if not current_pilot_stats:
		return {}
	
	var combat: Dictionary = {}
	
	# Kill/Death metrics
	combat["kill_efficiency"] = _calculate_kill_efficiency()
	combat["survival_rate"] = _calculate_survival_rate()
	combat["combat_rating"] = _calculate_combat_rating()
	
	# Weapon effectiveness
	combat["primary_effectiveness"] = _calculate_weapon_effectiveness(true)
	combat["secondary_effectiveness"] = _calculate_weapon_effectiveness(false)
	
	# Mission performance
	combat["average_kills_per_mission"] = _calculate_average_kills_per_mission()
	combat["average_score_per_mission"] = _calculate_average_score_per_mission()
	
	return combat

func _calculate_accuracy_statistics() -> Dictionary:
	"""Calculate detailed accuracy statistics."""
	if not current_pilot_stats:
		return {}
	
	var accuracy: Dictionary = {}
	
	# Primary weapon accuracy
	accuracy["primary_accuracy"] = current_pilot_stats.primary_accuracy
	accuracy["primary_shots_fired"] = current_pilot_stats.primary_shots_fired
	accuracy["primary_shots_hit"] = current_pilot_stats.primary_shots_hit
	accuracy["primary_friendly_fire_rate"] = _calculate_friendly_fire_rate(true)
	
	# Secondary weapon accuracy
	accuracy["secondary_accuracy"] = current_pilot_stats.secondary_accuracy
	accuracy["secondary_shots_fired"] = current_pilot_stats.secondary_shots_fired
	accuracy["secondary_shots_hit"] = current_pilot_stats.secondary_shots_hit
	accuracy["secondary_friendly_fire_rate"] = _calculate_friendly_fire_rate(false)
	
	# Combined accuracy
	accuracy["total_accuracy"] = current_pilot_stats.get_total_accuracy()
	accuracy["total_shots_fired"] = current_pilot_stats.primary_shots_fired + current_pilot_stats.secondary_shots_fired
	accuracy["total_shots_hit"] = current_pilot_stats.primary_shots_hit + current_pilot_stats.secondary_shots_hit
	
	return accuracy

func _calculate_performance_metrics() -> Dictionary:
	"""Calculate advanced performance metrics."""
	if not current_pilot_stats:
		return {}
	
	var performance: Dictionary = {}
	
	# Efficiency metrics
	performance["score_per_hour"] = _calculate_score_per_hour()
	performance["kills_per_hour"] = _calculate_kills_per_hour()
	performance["mission_completion_rate"] = _calculate_mission_completion_rate()
	
	# Performance ratings
	performance["pilot_rating"] = _calculate_pilot_rating()
	performance["combat_effectiveness_rating"] = _calculate_combat_effectiveness_rating()
	performance["accuracy_rating"] = _calculate_accuracy_rating()
	
	return performance

func _calculate_historical_trends() -> Dictionary:
	"""Calculate historical performance trends."""
	var trends: Dictionary = {}
	
	# This would be enhanced with mission-by-mission tracking
	# For now, provide basic trend information
	trends["recent_performance"] = "Stable"  # Would calculate from recent missions
	trends["improvement_areas"] = _identify_improvement_areas()
	trends["strength_areas"] = _identify_strength_areas()
	
	return trends

func _calculate_achievement_progress() -> Dictionary:
	"""Calculate medal and achievement progress."""
	var achievements: Dictionary = {}
	
	# Medal progress
	achievements["earned_medals"] = earned_medals.size()
	achievements["available_medals"] = available_medals.size()
	achievements["medal_completion_rate"] = float(earned_medals.size()) / float(available_medals.size()) if available_medals.size() > 0 else 0.0
	
	# Next available medals
	achievements["next_medals"] = _get_next_available_medals(3)
	
	return achievements

func _calculate_rank_progression() -> Dictionary:
	"""Calculate rank progression information."""
	var rank_info: Dictionary = {}
	
	if current_pilot_stats.rank < available_ranks.size():
		var current_rank: RankData = available_ranks[current_pilot_stats.rank]
		rank_info["current_rank"] = current_rank.get_rank_info()
		
		# Next rank information
		if current_pilot_stats.rank + 1 < available_ranks.size():
			var next_rank: RankData = available_ranks[current_pilot_stats.rank + 1]
			rank_info["next_rank"] = next_rank.get_rank_info()
			rank_info["promotion_progress"] = next_rank.get_promotion_progress(current_pilot_stats, earned_medals)
	
	return rank_info

# ============================================================================
# HELPER CALCULATIONS
# ============================================================================

func _calculate_kill_efficiency() -> float:
	"""Calculate kill efficiency (valid kills / total kills)."""
	if current_pilot_stats.kill_count == 0:
		return 1.0
	return float(current_pilot_stats.kill_count_ok) / float(current_pilot_stats.kill_count)

func _calculate_survival_rate() -> float:
	"""Calculate survival rate based on missions flown."""
	# This would need death tracking data
	return 100.0  # Placeholder

func _calculate_combat_rating() -> float:
	"""Calculate overall combat rating."""
	var rating: float = 0.0
	
	# Factor in accuracy
	rating += current_pilot_stats.get_total_accuracy() * 0.3
	
	# Factor in kill efficiency
	rating += _calculate_kill_efficiency() * 100.0 * 0.3
	
	# Factor in score per mission
	rating += _calculate_average_score_per_mission() * 0.0001
	
	# Factor in survival rate
	rating += _calculate_survival_rate() * 0.4
	
	return min(rating, 100.0)

func _calculate_weapon_effectiveness(is_primary: bool) -> Dictionary:
	"""Calculate weapon effectiveness for primary or secondary weapons."""
	var effectiveness: Dictionary = {}
	
	if is_primary:
		effectiveness["accuracy"] = current_pilot_stats.primary_accuracy
		effectiveness["shots_fired"] = current_pilot_stats.primary_shots_fired
		effectiveness["shots_hit"] = current_pilot_stats.primary_shots_hit
		effectiveness["friendly_fire_rate"] = _calculate_friendly_fire_rate(true)
	else:
		effectiveness["accuracy"] = current_pilot_stats.secondary_accuracy
		effectiveness["shots_fired"] = current_pilot_stats.secondary_shots_fired
		effectiveness["shots_hit"] = current_pilot_stats.secondary_shots_hit
		effectiveness["friendly_fire_rate"] = _calculate_friendly_fire_rate(false)
	
	return effectiveness

func _calculate_friendly_fire_rate(is_primary: bool) -> float:
	"""Calculate friendly fire rate for weapon type."""
	if is_primary:
		if current_pilot_stats.primary_shots_fired == 0:
			return 0.0
		return float(current_pilot_stats.primary_friendly_hits) / float(current_pilot_stats.primary_shots_fired) * 100.0
	else:
		if current_pilot_stats.secondary_shots_fired == 0:
			return 0.0
		return float(current_pilot_stats.secondary_friendly_hits) / float(current_pilot_stats.secondary_shots_fired) * 100.0

func _calculate_average_kills_per_mission() -> float:
	"""Calculate average kills per mission."""
	if current_pilot_stats.missions_flown == 0:
		return 0.0
	return float(current_pilot_stats.kill_count_ok) / float(current_pilot_stats.missions_flown)

func _calculate_average_score_per_mission() -> float:
	"""Calculate average score per mission."""
	if current_pilot_stats.missions_flown == 0:
		return 0.0
	return float(current_pilot_stats.score) / float(current_pilot_stats.missions_flown)

func _calculate_score_per_hour() -> float:
	"""Calculate score per hour of flight time."""
	if current_pilot_stats.flight_time == 0:
		return 0.0
	return float(current_pilot_stats.score) / (float(current_pilot_stats.flight_time) / 3600.0)

func _calculate_kills_per_hour() -> float:
	"""Calculate kills per hour of flight time."""
	if current_pilot_stats.flight_time == 0:
		return 0.0
	return float(current_pilot_stats.kill_count_ok) / (float(current_pilot_stats.flight_time) / 3600.0)

func _calculate_mission_completion_rate() -> float:
	"""Calculate mission completion rate."""
	# This would need mission failure tracking
	return 100.0  # Placeholder

func _calculate_pilot_rating() -> float:
	"""Calculate overall pilot rating."""
	return _calculate_combat_rating()  # For now, same as combat rating

func _calculate_combat_effectiveness_rating() -> float:
	"""Calculate combat effectiveness rating."""
	return _calculate_combat_rating()

func _calculate_accuracy_rating() -> float:
	"""Calculate accuracy-based rating."""
	return current_pilot_stats.get_total_accuracy()

func _identify_improvement_areas() -> Array[String]:
	"""Identify areas where pilot can improve."""
	var areas: Array[String] = []
	
	if current_pilot_stats.get_total_accuracy() < 50.0:
		areas.append("Weapon accuracy")
	
	if current_pilot_stats.friendly_kills > 0:
		areas.append("Friendly fire discipline")
	
	if _calculate_friendly_fire_rate(true) > 5.0 or _calculate_friendly_fire_rate(false) > 5.0:
		areas.append("Target identification")
	
	return areas

func _identify_strength_areas() -> Array[String]:
	"""Identify pilot's strength areas."""
	var areas: Array[String] = []
	
	if current_pilot_stats.get_total_accuracy() > 80.0:
		areas.append("Excellent accuracy")
	
	if _calculate_average_kills_per_mission() > 3.0:
		areas.append("High combat effectiveness")
	
	if current_pilot_stats.friendly_kills == 0:
		areas.append("Perfect friendly fire discipline")
	
	return areas

# ============================================================================
# MEDAL AND RANK SYSTEM
# ============================================================================

func _load_medal_data() -> void:
	"""Load medal data from resources."""
	available_medals.clear()
	
	# This would load from actual medal data files
	# For now, create some example medals
	_create_example_medals()

func _load_rank_data() -> void:
	"""Load rank data from resources."""
	available_ranks.clear()
	
	# This would load from actual rank data files
	# For now, create some example ranks
	_create_example_ranks()

func _check_medal_eligibility() -> void:
	"""Check if pilot is eligible for any new medals."""
	if not current_pilot_stats:
		return
	
	for medal in available_medals:
		if medal.check_eligibility(current_pilot_stats) and not earned_medals.has(medal.name):
			_award_medal(medal)

func _check_rank_promotion() -> void:
	"""Check if pilot is eligible for rank promotion."""
	if not current_pilot_stats or current_pilot_stats.rank >= available_ranks.size() - 1:
		return
	
	var next_rank: RankData = available_ranks[current_pilot_stats.rank + 1]
	if next_rank.check_promotion_eligibility(current_pilot_stats, earned_medals):
		rank_promotion_available.emit(next_rank)

func _award_medal(medal: MedalData) -> void:
	"""Award a medal to the pilot."""
	if not earned_medals.has(medal.name):
		earned_medals.append(medal.name)
		medal_awarded.emit(medal.name, medal)

func _get_next_available_medals(count: int) -> Array[Dictionary]:
	"""Get the next available medals the pilot can earn."""
	var next_medals: Array[Dictionary] = []
	
	for medal in available_medals:
		if not earned_medals.has(medal.name):
			var progress: Dictionary = medal.get_progress_toward_medal(current_pilot_stats)
			if progress.progress > 0.0:  # Some progress toward medal
				next_medals.append({
					"medal": medal,
					"progress": progress
				})
	
	# Sort by progress (closest to completion first)
	next_medals.sort_custom(func(a, b): return a.progress.progress > b.progress.progress)
	
	# Return top 'count' medals
	return next_medals.slice(0, count)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _clear_statistics_cache() -> void:
	"""Clear the statistics calculation cache."""
	statistics_cache.clear()
	cache_timestamp = 0.0

func _get_ship_class_index(ship_class_name: String) -> int:
	"""Get ship class index from name."""
	# This would use actual ship class data
	return 0  # Placeholder

func _get_ship_class_name(index: int) -> String:
	"""Get ship class name from index."""
	# This would use actual ship class data
	return "Unknown"  # Placeholder

func _create_example_medals() -> void:
	"""Create example medals for testing."""
	var medal1: MedalData = MedalData.new()
	medal1.name = "Bronze Cluster"
	medal1.description = "Awarded for 10 confirmed kills"
	medal1.kills_needed = 10
	medal1.category = MedalData.MedalCategory.ACHIEVEMENT_BADGE
	available_medals.append(medal1)
	
	var medal2: MedalData = MedalData.new()
	medal2.name = "Silver Cluster"
	medal2.description = "Awarded for 25 confirmed kills"
	medal2.kills_needed = 25
	medal2.category = MedalData.MedalCategory.ACHIEVEMENT_BADGE
	available_medals.append(medal2)
	
	var medal3: MedalData = MedalData.new()
	medal3.name = "Marksman Medal"
	medal3.description = "Awarded for 75% weapon accuracy"
	medal3.accuracy_required = 75.0
	medal3.category = MedalData.MedalCategory.COMBAT_DECORATION
	available_medals.append(medal3)

func _create_example_ranks() -> void:
	"""Create example ranks for testing."""
	var ranks_data: Array[Dictionary] = [
		{"name": "Ensign", "points": 0, "index": 0},
		{"name": "Lieutenant JG", "points": 2000, "index": 1},
		{"name": "Lieutenant", "points": 5000, "index": 2},
		{"name": "Lt. Commander", "points": 10000, "index": 3},
		{"name": "Commander", "points": 20000, "index": 4},
		{"name": "Captain", "points": 35000, "index": 5},
		{"name": "Commodore", "points": 50000, "index": 6},
		{"name": "Rear Admiral", "points": 75000, "index": 7},
		{"name": "Vice Admiral", "points": 100000, "index": 8},
		{"name": "Admiral", "points": 150000, "index": 9}
	]
	
	for rank_dict in ranks_data:
		var rank: RankData = RankData.new()
		rank.name = rank_dict.name
		rank.rank_index = rank_dict.index
		rank.points_required = rank_dict.points
		rank.description = "Military rank: " + rank_dict.name
		
		# Set category based on rank
		if rank_dict.index <= 1:
			rank.category = RankData.RankCategory.ENLISTED
		elif rank_dict.index <= 4:
			rank.category = RankData.RankCategory.OFFICER
		elif rank_dict.index <= 6:
			rank.category = RankData.RankCategory.SENIOR_OFFICER
		else:
			rank.category = RankData.RankCategory.FLAG_OFFICER
		
		if rank_dict.index == 9:
			rank.flags |= RankData.RankFlags.FINAL_RANK
		
		available_ranks.append(rank)

# ============================================================================
# EXPORT/IMPORT FUNCTIONALITY
# ============================================================================

func export_statistics_to_json() -> String:
	"""Export current statistics to JSON format."""
	if not current_pilot_stats:
		return "{}"
	
	var export_data: Dictionary = {
		"pilot_statistics": {
			"score": current_pilot_stats.score,
			"rank": current_pilot_stats.rank,
			"missions_flown": current_pilot_stats.missions_flown,
			"flight_time": current_pilot_stats.flight_time,
			"kill_count": current_pilot_stats.kill_count,
			"kill_count_ok": current_pilot_stats.kill_count_ok,
			"assists": current_pilot_stats.assists,
			"accuracy_stats": {
				"primary_accuracy": current_pilot_stats.primary_accuracy,
				"secondary_accuracy": current_pilot_stats.secondary_accuracy,
				"total_accuracy": current_pilot_stats.get_total_accuracy()
			},
			"weapon_stats": {
				"primary_shots_fired": current_pilot_stats.primary_shots_fired,
				"primary_shots_hit": current_pilot_stats.primary_shots_hit,
				"secondary_shots_fired": current_pilot_stats.secondary_shots_fired,
				"secondary_shots_hit": current_pilot_stats.secondary_shots_hit
			}
		},
		"earned_medals": earned_medals,
		"comprehensive_stats": get_comprehensive_statistics(),
		"export_timestamp": Time.get_unix_time_from_system()
	}
	
	return JSON.stringify(export_data, "\t")

func save_statistics_export(file_path: String) -> Error:
	"""Save statistics export to file."""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	
	file.store_string(export_statistics_to_json())
	file.close()
	return OK

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_statistics_manager() -> StatisticsDataManager:
	"""Create a new statistics data manager instance."""
	var manager: StatisticsDataManager = StatisticsDataManager.new()
	manager.name = "StatisticsDataManager"
	return manager