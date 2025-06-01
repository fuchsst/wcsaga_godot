class_name ProgressionTracker
extends Node

## Progression tracking system for rank advancement and medal requirements.
## Monitors pilot statistics and automatically tracks progress toward goals.
## Provides real-time feedback on advancement opportunities and requirements.

signal rank_promotion_earned(new_rank: RankData, pilot_stats: PilotStatistics)
signal medal_earned(medal: MedalData, pilot_stats: PilotStatistics)
signal achievement_progress_updated(achievement_name: String, progress: float)
signal milestone_reached(milestone_name: String, milestone_data: Dictionary)

# Data management
var available_ranks: Array[RankData] = []
var available_medals: Array[MedalData] = []
var earned_medals: Array[String] = []
var current_rank: int = 0

# Progress tracking
var rank_progress_cache: Dictionary = {}
var medal_progress_cache: Dictionary = {}
var milestone_tracking: Dictionary = {}

# Configuration
@export var enable_automatic_tracking: bool = true
@export var progress_check_interval: float = 1.0
@export var milestone_sensitivity: float = 0.1  # Minimum progress change to trigger update
@export var cache_expiry_time: float = 30.0

# Performance tracking
var last_progress_check: float = 0.0
var progress_calculation_time: float = 0.0

func _ready() -> void:
	"""Initialize progression tracker."""
	_load_progression_data()
	_setup_milestone_tracking()
	
	if enable_automatic_tracking:
		_setup_automatic_tracking()

func _setup_automatic_tracking() -> void:
	"""Setup automatic progress tracking."""
	var timer: Timer = Timer.new()
	timer.wait_time = progress_check_interval
	timer.timeout.connect(_check_progression_updates)
	timer.autostart = true
	add_child(timer)

func _load_progression_data() -> void:
	"""Load rank and medal progression data."""
	_load_rank_data()
	_load_medal_data()

func _load_rank_data() -> void:
	"""Load available ranks for progression tracking."""
	available_ranks.clear()
	
	# Create standard WCS ranks
	var rank_definitions: Array[Dictionary] = [
		{"name": "Ensign", "points": 0, "kills": 0, "missions": 0, "index": 0},
		{"name": "Lieutenant JG", "points": 2000, "kills": 4, "missions": 3, "index": 1},
		{"name": "Lieutenant", "points": 5000, "kills": 10, "missions": 7, "index": 2},
		{"name": "Lt. Commander", "points": 10000, "kills": 20, "missions": 15, "index": 3},
		{"name": "Commander", "points": 20000, "kills": 35, "missions": 25, "index": 4},
		{"name": "Captain", "points": 35000, "kills": 50, "missions": 40, "index": 5},
		{"name": "Commodore", "points": 50000, "kills": 75, "missions": 60, "index": 6},
		{"name": "Rear Admiral", "points": 75000, "kills": 100, "missions": 80, "index": 7},
		{"name": "Vice Admiral", "points": 100000, "kills": 150, "missions": 100, "index": 8},
		{"name": "Admiral", "points": 150000, "kills": 200, "missions": 120, "index": 9}
	]
	
	for rank_def in rank_definitions:
		var rank: RankData = RankData.new()
		rank.name = rank_def.name
		rank.rank_index = rank_def.index
		rank.points_required = rank_def.points
		rank.kills_required = rank_def.kills
		rank.missions_required = rank_def.missions
		rank.description = "Military rank of " + rank_def.name
		
		# Set category based on rank level
		if rank_def.index <= 1:
			rank.category = RankData.RankCategory.ENLISTED
		elif rank_def.index <= 4:
			rank.category = RankData.RankCategory.OFFICER
		elif rank_def.index <= 6:
			rank.category = RankData.RankCategory.SENIOR_OFFICER
		else:
			rank.category = RankData.RankCategory.FLAG_OFFICER
		
		if rank_def.index == 9:
			rank.flags |= RankData.RankFlags.FINAL_RANK
		
		available_ranks.append(rank)

func _load_medal_data() -> void:
	"""Load available medals for progression tracking."""
	available_medals.clear()
	
	# Create standard WCS medals and badges
	var medal_definitions: Array[Dictionary] = [
		# Kill-based badges
		{"name": "Bronze Cluster", "desc": "10 confirmed kills", "kills": 10, "category": MedalData.MedalCategory.ACHIEVEMENT_BADGE},
		{"name": "Silver Cluster", "desc": "25 confirmed kills", "kills": 25, "category": MedalData.MedalCategory.ACHIEVEMENT_BADGE},
		{"name": "Gold Cluster", "desc": "50 confirmed kills", "kills": 50, "category": MedalData.MedalCategory.ACHIEVEMENT_BADGE},
		{"name": "Ace Badge", "desc": "100 confirmed kills", "kills": 100, "category": MedalData.MedalCategory.ACHIEVEMENT_BADGE},
		
		# Accuracy-based medals
		{"name": "Marksman Medal", "desc": "75% weapon accuracy", "accuracy": 75.0, "category": MedalData.MedalCategory.COMBAT_DECORATION},
		{"name": "Expert Marksman", "desc": "85% weapon accuracy", "accuracy": 85.0, "category": MedalData.MedalCategory.COMBAT_DECORATION},
		{"name": "Sharpshooter Cross", "desc": "90% weapon accuracy", "accuracy": 90.0, "category": MedalData.MedalCategory.COMBAT_DECORATION},
		
		# Service medals
		{"name": "Service Ribbon", "desc": "Complete 10 missions", "missions": 10, "category": MedalData.MedalCategory.GENERAL_SERVICE},
		{"name": "Meritorious Service", "desc": "Complete 25 missions", "missions": 25, "category": MedalData.MedalCategory.GENERAL_SERVICE},
		{"name": "Distinguished Service", "desc": "Complete 50 missions", "missions": 50, "category": MedalData.MedalCategory.GENERAL_SERVICE},
		
		# Performance medals
		{"name": "Legion of Honor", "desc": "Score 50,000 points", "points": 50000, "category": MedalData.MedalCategory.COMBAT_DECORATION},
		{"name": "Order of Galatea", "desc": "Score 100,000 points", "points": 100000, "category": MedalData.MedalCategory.COMBAT_DECORATION},
		{"name": "Distinguished Flying Cross", "desc": "Score 200,000 points", "points": 200000, "category": MedalData.MedalCategory.COMBAT_DECORATION}
	]
	
	for medal_def in medal_definitions:
		var medal: MedalData = MedalData.new()
		medal.name = medal_def.name
		medal.description = medal_def.desc
		medal.category = medal_def.category
		medal.kills_needed = medal_def.get("kills", 0)
		medal.accuracy_required = medal_def.get("accuracy", 0.0)
		medal.missions_required = medal_def.get("missions", 0)
		medal.points_required = medal_def.get("points", 0)
		
		if medal.kills_needed > 0:
			medal.flags |= MedalData.MedalFlags.KILLBOARD_MEDAL
		
		available_medals.append(medal)

func _setup_milestone_tracking() -> void:
	"""Setup milestone tracking for significant achievements."""
	milestone_tracking = {
		"first_kill": {"threshold": 1, "achieved": false, "description": "First confirmed kill"},
		"ace_status": {"threshold": 5, "achieved": false, "description": "Ace pilot status (5 kills)"},
		"veteran_status": {"threshold": 20, "achieved": false, "description": "Veteran pilot status (20 missions)"},
		"marksman_level": {"threshold": 50.0, "achieved": false, "description": "Marksman level accuracy"},
		"elite_pilot": {"threshold": 50, "achieved": false, "description": "Elite pilot status (50 kills)"},
		"mission_veteran": {"threshold": 50, "achieved": false, "description": "Mission veteran (50 missions)"},
		"score_milestone_10k": {"threshold": 10000, "achieved": false, "description": "10,000 point milestone"},
		"score_milestone_50k": {"threshold": 50000, "achieved": false, "description": "50,000 point milestone"},
		"score_milestone_100k": {"threshold": 100000, "achieved": false, "description": "100,000 point milestone"}
	}

# ============================================================================
# PROGRESSION TRACKING
# ============================================================================

func update_pilot_progress(pilot_stats: PilotStatistics, pilot_earned_medals: Array[String]) -> void:
	"""Update progression tracking for pilot statistics."""
	if not pilot_stats:
		return
	
	earned_medals = pilot_earned_medals.duplicate()
	current_rank = pilot_stats.rank
	
	var start_time: float = Time.get_time_dict_from_system()["unix"]
	
	# Check for new rank promotions
	_check_rank_promotions(pilot_stats)
	
	# Check for new medals
	_check_medal_awards(pilot_stats)
	
	# Check milestone achievements
	_check_milestone_achievements(pilot_stats)
	
	# Update progress cache
	_update_progress_cache(pilot_stats)
	
	var end_time: float = Time.get_time_dict_from_system()["unix"]
	progress_calculation_time = end_time - start_time
	last_progress_check = end_time

func get_next_rank_progress(pilot_stats: PilotStatistics) -> Dictionary:
	"""Get progress toward next rank promotion."""
	if not pilot_stats or current_rank >= available_ranks.size() - 1:
		return {"is_max_rank": true}
	
	var next_rank: RankData = available_ranks[current_rank + 1]
	return next_rank.get_promotion_progress(pilot_stats, earned_medals)

func get_medal_progress(pilot_stats: PilotStatistics) -> Array[Dictionary]:
	"""Get progress toward available medals."""
	var medal_progress: Array[Dictionary] = []
	
	for medal in available_medals:
		if not earned_medals.has(medal.name):
			var progress: Dictionary = medal.get_progress_toward_medal(pilot_stats)
			if progress.progress > 0.0:  # Only include medals with some progress
				medal_progress.append({
					"medal": medal,
					"progress": progress
				})
	
	# Sort by progress (closest to completion first)
	medal_progress.sort_custom(func(a, b): return a.progress.progress > b.progress.progress)
	
	return medal_progress

func get_achievement_summary(pilot_stats: PilotStatistics) -> Dictionary:
	"""Get comprehensive achievement summary."""
	var summary: Dictionary = {}
	
	# Rank information
	summary["rank_info"] = {
		"current_rank": current_rank,
		"current_rank_name": available_ranks[current_rank].name if current_rank < available_ranks.size() else "Unknown",
		"next_rank_progress": get_next_rank_progress(pilot_stats),
		"is_max_rank": current_rank >= available_ranks.size() - 1
	}
	
	# Medal information
	summary["medal_info"] = {
		"earned_count": earned_medals.size(),
		"total_available": available_medals.size(),
		"completion_rate": float(earned_medals.size()) / float(available_medals.size()) if available_medals.size() > 0 else 0.0,
		"next_medals": get_medal_progress(pilot_stats).slice(0, 5)  # Top 5 closest medals
	}
	
	# Milestone information
	summary["milestone_info"] = {
		"total_milestones": milestone_tracking.size(),
		"achieved_milestones": _count_achieved_milestones(),
		"recent_milestones": _get_recent_milestones(pilot_stats),
		"next_milestones": _get_next_milestones(pilot_stats)
	}
	
	return summary

func get_performance_insights(pilot_stats: PilotStatistics) -> Dictionary:
	"""Get performance insights and recommendations."""
	var insights: Dictionary = {
		"strengths": [],
		"improvement_areas": [],
		"recommendations": [],
		"achievements_within_reach": []
	}
	
	# Analyze strengths
	if pilot_stats.get_total_accuracy() > 80.0:
		insights.strengths.append("Excellent weapon accuracy")
	
	if pilot_stats.friendly_kills == 0:
		insights.strengths.append("Perfect friendly fire discipline")
	
	var avg_kills_per_mission: float = float(pilot_stats.kill_count_ok) / float(pilot_stats.missions_flown) if pilot_stats.missions_flown > 0 else 0.0
	if avg_kills_per_mission > 3.0:
		insights.strengths.append("High combat effectiveness")
	
	# Analyze improvement areas
	if pilot_stats.get_total_accuracy() < 50.0:
		insights.improvement_areas.append("Weapon accuracy needs improvement")
		insights.recommendations.append("Practice target tracking in training missions")
	
	if pilot_stats.friendly_kills > 0:
		insights.improvement_areas.append("Friendly fire incidents")
		insights.recommendations.append("Focus on target identification before firing")
	
	# Find achievements within reach
	var medal_progress: Array[Dictionary] = get_medal_progress(pilot_stats)
	for medal_data in medal_progress.slice(0, 3):  # Top 3 closest
		if medal_data.progress.progress > 0.7:  # Within 30% of completion
			insights.achievements_within_reach.append({
				"type": "medal",
				"name": medal_data.medal.name,
				"progress": medal_data.progress.progress,
				"next_requirement": medal_data.progress.next_requirement
			})
	
	var rank_progress: Dictionary = get_next_rank_progress(pilot_stats)
	if not rank_progress.get("is_max_rank", false) and rank_progress.get("progress", 0.0) > 0.7:
		insights.achievements_within_reach.append({
			"type": "rank",
			"name": "Next rank promotion",
			"progress": rank_progress.progress,
			"next_requirement": rank_progress.next_requirement
		})
	
	return insights

# ============================================================================
# AUTOMATIC CHECKING
# ============================================================================

func _check_progression_updates() -> void:
	"""Check for progression updates automatically."""
	# This would be called by timer if automatic tracking is enabled
	# For now, it's a placeholder for future integration
	pass

func _check_rank_promotions(pilot_stats: PilotStatistics) -> void:
	"""Check if pilot is eligible for rank promotions."""
	if current_rank >= available_ranks.size() - 1:
		return  # Already at max rank
	
	var next_rank: RankData = available_ranks[current_rank + 1]
	if next_rank.check_promotion_eligibility(pilot_stats, earned_medals):
		rank_promotion_earned.emit(next_rank, pilot_stats)

func _check_medal_awards(pilot_stats: PilotStatistics) -> void:
	"""Check if pilot is eligible for any medal awards."""
	for medal in available_medals:
		if not earned_medals.has(medal.name) and medal.check_eligibility(pilot_stats):
			earned_medals.append(medal.name)
			medal_earned.emit(medal, pilot_stats)

func _check_milestone_achievements(pilot_stats: PilotStatistics) -> void:
	"""Check for milestone achievements."""
	# Check each milestone
	if _check_milestone("first_kill", pilot_stats.kill_count_ok):
		pass
	
	if _check_milestone("ace_status", pilot_stats.kill_count_ok):
		pass
	
	if _check_milestone("veteran_status", pilot_stats.missions_flown):
		pass
	
	if _check_milestone("marksman_level", pilot_stats.get_total_accuracy()):
		pass
	
	if _check_milestone("elite_pilot", pilot_stats.kill_count_ok):
		pass
	
	if _check_milestone("mission_veteran", pilot_stats.missions_flown):
		pass
	
	if _check_milestone("score_milestone_10k", pilot_stats.score):
		pass
	
	if _check_milestone("score_milestone_50k", pilot_stats.score):
		pass
	
	if _check_milestone("score_milestone_100k", pilot_stats.score):
		pass

func _check_milestone(milestone_name: String, current_value: float) -> bool:
	"""Check if a specific milestone has been achieved."""
	var milestone: Dictionary = milestone_tracking.get(milestone_name, {})
	if milestone.is_empty() or milestone.get("achieved", false):
		return false
	
	var threshold: float = milestone.get("threshold", 0.0)
	if current_value >= threshold:
		milestone.achieved = true
		milestone_reached.emit(milestone_name, milestone)
		return true
	
	return false

func _update_progress_cache(pilot_stats: PilotStatistics) -> void:
	"""Update progress calculation cache."""
	rank_progress_cache = get_next_rank_progress(pilot_stats)
	medal_progress_cache.clear()
	
	var medal_progress: Array[Dictionary] = get_medal_progress(pilot_stats)
	for medal_data in medal_progress:
		medal_progress_cache[medal_data.medal.name] = medal_data.progress

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _count_achieved_milestones() -> int:
	"""Count how many milestones have been achieved."""
	var count: int = 0
	for milestone in milestone_tracking.values():
		if milestone.get("achieved", false):
			count += 1
	return count

func _get_recent_milestones(pilot_stats: PilotStatistics) -> Array[Dictionary]:
	"""Get recently achieved milestones."""
	var recent: Array[Dictionary] = []
	
	for milestone_name in milestone_tracking:
		var milestone: Dictionary = milestone_tracking[milestone_name]
		if milestone.get("achieved", false):
			recent.append({
				"name": milestone_name,
				"description": milestone.get("description", ""),
				"threshold": milestone.get("threshold", 0)
			})
	
	return recent

func _get_next_milestones(pilot_stats: PilotStatistics) -> Array[Dictionary]:
	"""Get upcoming milestones within reach."""
	var upcoming: Array[Dictionary] = []
	
	for milestone_name in milestone_tracking:
		var milestone: Dictionary = milestone_tracking[milestone_name]
		if not milestone.get("achieved", false):
			var current_value: float = _get_milestone_current_value(milestone_name, pilot_stats)
			var threshold: float = milestone.get("threshold", 0.0)
			var progress: float = current_value / threshold if threshold > 0 else 0.0
			
			if progress > 0.5:  # Within 50% of completion
				upcoming.append({
					"name": milestone_name,
					"description": milestone.get("description", ""),
					"threshold": threshold,
					"current_value": current_value,
					"progress": progress
				})
	
	# Sort by progress (closest first)
	upcoming.sort_custom(func(a, b): return a.progress > b.progress)
	
	return upcoming.slice(0, 3)  # Top 3 upcoming

func _get_milestone_current_value(milestone_name: String, pilot_stats: PilotStatistics) -> float:
	"""Get current value for milestone tracking."""
	match milestone_name:
		"first_kill", "ace_status", "elite_pilot":
			return float(pilot_stats.kill_count_ok)
		"veteran_status", "mission_veteran":
			return float(pilot_stats.missions_flown)
		"marksman_level":
			return pilot_stats.get_total_accuracy()
		"score_milestone_10k", "score_milestone_50k", "score_milestone_100k":
			return float(pilot_stats.score)
		_:
			return 0.0

func get_progression_statistics() -> Dictionary:
	"""Get progression tracking statistics."""
	return {
		"available_ranks": available_ranks.size(),
		"available_medals": available_medals.size(),
		"earned_medals": earned_medals.size(),
		"current_rank": current_rank,
		"milestones_total": milestone_tracking.size(),
		"milestones_achieved": _count_achieved_milestones(),
		"last_check_time": last_progress_check,
		"calculation_time": progress_calculation_time
	}

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_progression_tracker() -> ProgressionTracker:
	"""Create a new progression tracker instance."""
	var tracker: ProgressionTracker = ProgressionTracker.new()
	tracker.name = "ProgressionTracker"
	return tracker