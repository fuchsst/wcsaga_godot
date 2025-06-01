class_name DebriefingDataManager
extends Node

## Core mission debriefing data management for WCS-Godot conversion.
## Handles mission results processing, statistics calculation, and award determination.
## Integrates with SaveGameManager and PilotProfileData for persistent updates.

signal debrief_data_loaded(mission_results: Dictionary)
signal statistics_calculated(stats: Dictionary)
signal awards_determined(awards: Array[Dictionary])
signal pilot_data_updated(pilot_data: PlayerProfile)
signal progression_updated(progression_data: Dictionary)

# Mission result data
var current_mission_data: MissionData = null
var mission_result_data: Dictionary = {}
var mission_statistics: Dictionary = {}
var calculated_awards: Array[Dictionary] = []
var progression_updates: Dictionary = {}

# Integration components
var save_game_manager: SaveGameManager = null
var pilot_data_manager: PilotDataManager = null
var statistics_manager: StatisticsDataManager = null

# Configuration
@export var enable_medal_calculations: bool = true
@export var enable_promotion_checks: bool = true
@export var enable_statistics_tracking: bool = true
@export var enable_story_progression: bool = true

func _ready() -> void:
	"""Initialize debriefing data manager."""
	_setup_dependencies()

func _setup_dependencies() -> void:
	"""Setup required dependencies."""
	# Find save game manager
	var save_managers: Array[Node] = get_tree().get_nodes_in_group("save_game_manager")
	if not save_managers.is_empty():
		save_game_manager = save_managers[0] as SaveGameManager
	
	# Find pilot data manager
	var pilot_managers: Array[Node] = get_tree().get_nodes_in_group("pilot_data_manager")
	if not pilot_managers.is_empty():
		pilot_data_manager = pilot_managers[0] as PilotDataManager
	
	# Find statistics manager
	var stat_managers: Array[Node] = get_tree().get_nodes_in_group("statistics_data_manager")
	if not stat_managers.is_empty():
		statistics_manager = stat_managers[0] as StatisticsDataManager

# ============================================================================
# PUBLIC API
# ============================================================================

func process_mission_completion(mission_data: MissionData, mission_result: Dictionary, pilot_data: PlayerProfile) -> bool:
	"""Process mission completion data and calculate all debriefing information."""
	if not mission_data or mission_result.is_empty() or not pilot_data:
		push_error("Missing required data for mission completion processing")
		return false
	
	current_mission_data = mission_data
	
	# Process mission results
	if not _process_mission_results(mission_result):
		return false
	
	# Calculate statistics
	if enable_statistics_tracking:
		_calculate_mission_statistics(mission_result, pilot_data)
	
	# Determine awards
	if enable_medal_calculations or enable_promotion_checks:
		_determine_awards(pilot_data)
	
	# Calculate story progression
	if enable_story_progression:
		_calculate_story_progression(mission_result)
	
	# Update pilot data
	_update_pilot_data(pilot_data)
	
	# Emit completion signals
	debrief_data_loaded.emit(mission_result_data)
	
	return true

func get_mission_results() -> Dictionary:
	"""Get processed mission results."""
	return mission_result_data.duplicate(true)

func get_mission_statistics() -> Dictionary:
	"""Get calculated mission statistics."""
	return mission_statistics.duplicate(true)

func get_calculated_awards() -> Array[Dictionary]:
	"""Get calculated awards and promotions."""
	return calculated_awards.duplicate(true)

func get_progression_updates() -> Dictionary:
	"""Get story progression updates."""
	return progression_updates.duplicate(true)

func apply_pilot_updates(pilot_data: PlayerProfile) -> bool:
	"""Apply calculated updates to pilot data."""
	if not pilot_data:
		return false
	
	# Apply statistics updates
	if mission_statistics.has("pilot_updates"):
		var updates: Dictionary = mission_statistics.pilot_updates
		_apply_statistics_to_pilot(pilot_data, updates)
	
	# Apply awards
	for award in calculated_awards:
		_apply_award_to_pilot(pilot_data, award)
	
	# Save updated pilot data
	if pilot_data_manager:
		pilot_data_manager.save_pilot_data(pilot_data)
	
	pilot_data_updated.emit(pilot_data)
	return true

func save_mission_results() -> bool:
	"""Save mission results to campaign data."""
	if not save_game_manager or not current_mission_data:
		return false
	
	# Save mission completion status
	var campaign_data: Dictionary = save_game_manager.get_campaign_data()
	if campaign_data.is_empty():
		campaign_data = {"completed_missions": [], "mission_results": {}}
	
	# Add mission completion
	var mission_id: String = current_mission_data.mission_filename
	if not campaign_data.completed_missions.has(mission_id):
		campaign_data.completed_missions.append(mission_id)
	
	# Store detailed results
	campaign_data.mission_results[mission_id] = mission_result_data.duplicate(true)
	
	# Save campaign data
	save_game_manager.save_campaign_data(campaign_data)
	
	return true

# ============================================================================
# MISSION RESULT PROCESSING
# ============================================================================

func _process_mission_results(mission_result: Dictionary) -> bool:
	"""Process raw mission results into structured data."""
	mission_result_data = {
		"mission_success": mission_result.get("success", false),
		"completion_time": mission_result.get("completion_time", 0.0),
		"objectives": _process_objectives(mission_result.get("objectives", [])),
		"performance": _process_performance_data(mission_result.get("performance", {})),
		"casualties": _process_casualty_data(mission_result.get("casualties", {})),
		"mission_score": _calculate_mission_score(mission_result),
		"difficulty_modifier": mission_result.get("difficulty_modifier", 1.0)
	}
	
	return true

func _process_objectives(objectives: Array) -> Array[Dictionary]:
	"""Process mission objectives completion status."""
	var processed_objectives: Array[Dictionary] = []
	
	for objective in objectives:
		var obj_dict: Dictionary = objective as Dictionary
		if obj_dict:
			var processed_obj: Dictionary = {
				"objective_id": obj_dict.get("id", ""),
				"description": obj_dict.get("description", ""),
				"completed": obj_dict.get("completed", false),
				"failed": obj_dict.get("failed", false),
				"is_primary": obj_dict.get("is_primary", true),
				"completion_time": obj_dict.get("completion_time", 0.0),
				"score_value": obj_dict.get("score_value", 0)
			}
			processed_objectives.append(processed_obj)
	
	return processed_objectives

func _process_performance_data(performance: Dictionary) -> Dictionary:
	"""Process performance metrics from mission."""
	return {
		"kills": {
			"fighters": performance.get("fighter_kills", 0),
			"bombers": performance.get("bomber_kills", 0),
			"capital_ships": performance.get("capital_kills", 0),
			"total": performance.get("total_kills", 0)
		},
		"accuracy": {
			"primary_accuracy": performance.get("primary_accuracy", 0.0),
			"secondary_accuracy": performance.get("secondary_accuracy", 0.0),
			"overall_accuracy": performance.get("overall_accuracy", 0.0)
		},
		"damage": {
			"damage_dealt": performance.get("damage_dealt", 0.0),
			"damage_taken": performance.get("damage_taken", 0.0),
			"hull_damage_taken": performance.get("hull_damage_taken", 0.0),
			"shield_damage_taken": performance.get("shield_damage_taken", 0.0)
		},
		"flight_performance": {
			"time_on_afterburner": performance.get("afterburner_time", 0.0),
			"collisions": performance.get("collisions", 0),
			"warnings_issued": performance.get("warnings", 0)
		}
	}

func _process_casualty_data(casualties: Dictionary) -> Dictionary:
	"""Process casualty and loss data."""
	return {
		"friendly_losses": {
			"fighters": casualties.get("friendly_fighters_lost", 0),
			"bombers": casualties.get("friendly_bombers_lost", 0),
			"capital_ships": casualties.get("friendly_capitals_lost", 0),
			"total": casualties.get("total_friendly_losses", 0)
		},
		"enemy_losses": {
			"fighters": casualties.get("enemy_fighters_lost", 0),
			"bombers": casualties.get("enemy_bombers_lost", 0),
			"capital_ships": casualties.get("enemy_capitals_lost", 0),
			"total": casualties.get("total_enemy_losses", 0)
		},
		"pilot_ejections": casualties.get("pilot_ejections", 0),
		"civilian_casualties": casualties.get("civilian_casualties", 0)
	}

func _calculate_mission_score(mission_result: Dictionary) -> int:
	"""Calculate overall mission score based on performance."""
	var base_score: int = 100
	var score_modifiers: int = 0
	
	# Success/failure modifier
	if mission_result.get("success", false):
		score_modifiers += 50
	else:
		score_modifiers -= 25
	
	# Objective completion bonuses
	var objectives: Array = mission_result.get("objectives", [])
	for objective in objectives:
		var obj_dict: Dictionary = objective as Dictionary
		if obj_dict and obj_dict.get("completed", false):
			if obj_dict.get("is_primary", true):
				score_modifiers += 15
			else:
				score_modifiers += 10
	
	# Performance bonuses
	var performance: Dictionary = mission_result.get("performance", {})
	var accuracy: float = performance.get("overall_accuracy", 0.0)
	if accuracy > 0.8:
		score_modifiers += 20
	elif accuracy > 0.6:
		score_modifiers += 10
	
	# Kill bonuses
	var total_kills: int = performance.get("total_kills", 0)
	score_modifiers += min(total_kills * 2, 30)  # Cap at 30 points
	
	# Damage penalty
	var damage_taken: float = performance.get("damage_taken", 0.0)
	if damage_taken > 75.0:  # Heavy damage penalty
		score_modifiers -= 15
	elif damage_taken > 50.0:  # Moderate damage penalty
		score_modifiers -= 10
	
	return max(base_score + score_modifiers, 0)

# ============================================================================
# STATISTICS CALCULATION
# ============================================================================

func _calculate_mission_statistics(mission_result: Dictionary, pilot_data: PlayerProfile) -> void:
	"""Calculate detailed mission statistics."""
	mission_statistics = {
		"mission_data": _extract_mission_stats(mission_result),
		"pilot_updates": _calculate_pilot_stat_updates(mission_result, pilot_data),
		"comparative_stats": _calculate_comparative_stats(mission_result, pilot_data),
		"achievements": _check_achievements(mission_result, pilot_data)
	}
	
	statistics_calculated.emit(mission_statistics)

func _extract_mission_stats(mission_result: Dictionary) -> Dictionary:
	"""Extract mission-specific statistics."""
	var performance: Dictionary = mission_result.get("performance", {})
	var completion_time: float = mission_result.get("completion_time", 0.0)
	
	return {
		"flight_time": completion_time,
		"shots_fired": {
			"primary": performance.get("primary_shots_fired", 0),
			"secondary": performance.get("secondary_shots_fired", 0),
			"total": performance.get("total_shots_fired", 0)
		},
		"shots_hit": {
			"primary": performance.get("primary_shots_hit", 0),
			"secondary": performance.get("secondary_shots_hit", 0),
			"total": performance.get("total_shots_hit", 0)
		},
		"missiles_fired": performance.get("missiles_fired", 0),
		"missiles_hit": performance.get("missiles_hit", 0),
		"kills_by_type": performance.get("kills", {}),
		"assists": performance.get("assists", 0),
		"bonuses_earned": performance.get("bonuses", [])
	}

func _calculate_pilot_stat_updates(mission_result: Dictionary, pilot_data: PlayerProfile) -> Dictionary:
	"""Calculate updates to pilot's permanent statistics."""
	var performance: Dictionary = mission_result.get("performance", {})
	var mission_time: float = mission_result.get("completion_time", 0.0)
	
	return {
		"missions_flown": 1,
		"total_kills": performance.get("total_kills", 0),
		"fighter_kills": performance.get("fighter_kills", 0),
		"bomber_kills": performance.get("bomber_kills", 0),
		"capital_kills": performance.get("capital_kills", 0),
		"assists": performance.get("assists", 0),
		"total_score": mission_result_data.get("mission_score", 0),
		"flight_time": mission_time,
		"shots_fired": performance.get("total_shots_fired", 0),
		"shots_hit": performance.get("total_shots_hit", 0),
		"secondary_shots_fired": performance.get("secondary_shots_fired", 0),
		"secondary_shots_hit": performance.get("secondary_shots_hit", 0)
	}

func _calculate_comparative_stats(mission_result: Dictionary, pilot_data: PlayerProfile) -> Dictionary:
	"""Calculate comparative statistics against pilot's history."""
	var current_stats: Dictionary = _extract_mission_stats(mission_result)
	
	# This would compare against pilot_data historical statistics
	# For now, return basic comparisons
	return {
		"best_accuracy_mission": current_stats.shots_hit.total > 0,
		"highest_kill_mission": current_stats.kills_by_type.size() > 0,
		"fastest_completion": current_stats.flight_time > 0,
		"highest_score_mission": mission_result_data.get("mission_score", 0) > 0
	}

func _check_achievements(mission_result: Dictionary, pilot_data: PlayerProfile) -> Array[String]:
	"""Check for special achievements earned this mission."""
	var achievements: Array[String] = []
	var performance: Dictionary = mission_result.get("performance", {})
	
	# Perfect accuracy achievement
	var overall_accuracy: float = performance.get("overall_accuracy", 0.0)
	if overall_accuracy >= 1.0:
		achievements.append("Perfect Accuracy")
	
	# No damage taken
	var damage_taken: float = performance.get("damage_taken", 0.0)
	if damage_taken <= 0.0:
		achievements.append("Untouchable")
	
	# High kill count
	var total_kills: int = performance.get("total_kills", 0)
	if total_kills >= 10:
		achievements.append("Ace Performance")
	elif total_kills >= 5:
		achievements.append("Top Gun")
	
	# Mission completion bonuses
	if mission_result.get("success", false):
		var completion_time: float = mission_result.get("completion_time", 0.0)
		if completion_time > 0 and completion_time < 300:  # Under 5 minutes
			achievements.append("Speed Demon")
	
	return achievements

# ============================================================================
# AWARD SYSTEM
# ============================================================================

func _determine_awards(pilot_data: PlayerProfile) -> void:
	"""Determine medals, promotions, and other awards."""
	calculated_awards.clear()
	
	if enable_medal_calculations:
		_check_mission_medals()
		_check_campaign_medals(pilot_data)
	
	if enable_promotion_checks:
		_check_promotions(pilot_data)
	
	awards_determined.emit(calculated_awards)

func _check_mission_medals() -> void:
	"""Check for mission-specific medals."""
	var mission_success: bool = mission_result_data.get("mission_success", false)
	var mission_score: int = mission_result_data.get("mission_score", 0)
	
	# Distinguished Flying Cross - high performance
	if mission_success and mission_score >= 150:
		var medal: Dictionary = {
			"type": "medal",
			"medal_id": "distinguished_flying_cross",
			"name": "Distinguished Flying Cross",
			"description": "Awarded for exceptional performance in combat operations",
			"reason": "Outstanding mission performance with score: %d" % mission_score,
			"mission_earned": current_mission_data.mission_title if current_mission_data else ""
		}
		calculated_awards.append(medal)
	
	# Purple Heart - damage taken
	var damage_taken: float = mission_result_data.get("performance", {}).get("damage", {}).get("damage_taken", 0.0)
	if damage_taken >= 75.0 and mission_success:
		var medal: Dictionary = {
			"type": "medal",
			"medal_id": "purple_heart",
			"name": "Purple Heart",
			"description": "Awarded for wounds received in action against an enemy",
			"reason": "Sustained heavy damage (%.1f%%) but completed mission" % damage_taken,
			"mission_earned": current_mission_data.mission_title if current_mission_data else ""
		}
		calculated_awards.append(medal)

func _check_campaign_medals(pilot_data: PlayerProfile) -> void:
	"""Check for campaign progression medals."""
	# This would check pilot's overall campaign statistics
	# For now, implement basic logic
	
	# Example: Mission completion medals
	var missions_completed: int = _get_pilot_missions_completed(pilot_data)
	
	if missions_completed == 10:
		var medal: Dictionary = {
			"type": "medal",
			"medal_id": "campaign_veteran",
			"name": "Campaign Veteran",
			"description": "Awarded for completing 10 campaign missions",
			"reason": "Completed %d campaign missions" % missions_completed,
			"mission_earned": current_mission_data.mission_title if current_mission_data else ""
		}
		calculated_awards.append(medal)

func _check_promotions(pilot_data: PlayerProfile) -> void:
	"""Check for rank promotions."""
	# This would check pilot's statistics against promotion requirements
	var current_rank: int = _get_pilot_rank(pilot_data)
	var total_score: int = _get_pilot_total_score(pilot_data)
	var total_kills: int = _get_pilot_total_kills(pilot_data)
	
	# Example promotion logic
	if current_rank == 0 and total_score >= 500 and total_kills >= 5:
		var promotion: Dictionary = {
			"type": "promotion",
			"new_rank": 1,
			"rank_name": "Lieutenant",
			"description": "Promoted to Lieutenant for distinguished service",
			"reason": "Total score: %d, Total kills: %d" % [total_score, total_kills],
			"mission_earned": current_mission_data.mission_title if current_mission_data else ""
		}
		calculated_awards.append(promotion)

# ============================================================================
# STORY PROGRESSION
# ============================================================================

func _calculate_story_progression(mission_result: Dictionary) -> void:
	"""Calculate story and campaign progression updates."""
	progression_updates = {
		"campaign_variables": _calculate_campaign_variable_updates(mission_result),
		"story_branches": _check_story_branch_changes(mission_result),
		"unlocked_content": _check_unlocked_content(mission_result)
	}
	
	progression_updated.emit(progression_updates)

func _calculate_campaign_variable_updates(mission_result: Dictionary) -> Dictionary:
	"""Calculate updates to campaign variables."""
	var variable_updates: Dictionary = {}
	
	# Example: Mission success affects story variables
	if mission_result.get("success", false):
		variable_updates["missions_successful"] = 1
	else:
		variable_updates["missions_failed"] = 1
	
	# Casualties affect war status
	var casualties: Dictionary = mission_result_data.get("casualties", {})
	var friendly_losses: int = casualties.get("friendly_losses", {}).get("total", 0)
	if friendly_losses > 5:
		variable_updates["heavy_casualties_missions"] = 1
	
	return variable_updates

func _check_story_branch_changes(mission_result: Dictionary) -> Array[String]:
	"""Check for story branch changes based on mission results."""
	var branch_changes: Array[String] = []
	
	# Example story branch logic
	if mission_result.get("success", false):
		var objectives: Array = mission_result_data.get("objectives", [])
		for objective in objectives:
			var obj_dict: Dictionary = objective as Dictionary
			if obj_dict and obj_dict.get("completed", false):
				var obj_id: String = obj_dict.get("objective_id", "")
				if obj_id.contains("civilian_rescue"):
					branch_changes.append("humanitarian_branch_open")
	
	return branch_changes

func _check_unlocked_content(mission_result: Dictionary) -> Array[String]:
	"""Check for newly unlocked ships, weapons, or missions."""
	var unlocked: Array[String] = []
	
	# Example unlock logic based on performance
	var mission_score: int = mission_result_data.get("mission_score", 0)
	if mission_score >= 150:
		unlocked.append("advanced_weapons_available")
	
	var total_kills: int = mission_result_data.get("performance", {}).get("kills", {}).get("total", 0)
	if total_kills >= 10:
		unlocked.append("ace_pilot_ships_available")
	
	return unlocked

# ============================================================================
# PILOT DATA UPDATES
# ============================================================================

func _update_pilot_data(pilot_data: PlayerProfile) -> void:
	"""Update pilot data with mission results."""
	if not pilot_data:
		return
	
	# Apply statistical updates
	if mission_statistics.has("pilot_updates"):
		_apply_statistics_to_pilot(pilot_data, mission_statistics.pilot_updates)

func _apply_statistics_to_pilot(pilot_data: PlayerProfile, stat_updates: Dictionary) -> void:
	"""Apply statistical updates to pilot profile."""
	# This would integrate with pilot_data's statistics system
	# For now, basic implementation
	for stat_name in stat_updates:
		var value: int = stat_updates[stat_name]
		if pilot_data.has_method("add_to_statistic"):
			pilot_data.add_to_statistic(stat_name, value)

func _apply_award_to_pilot(pilot_data: PlayerProfile, award: Dictionary) -> void:
	"""Apply medal or promotion to pilot profile."""
	var award_type: String = award.get("type", "")
	
	if award_type == "medal":
		if pilot_data.has_method("add_medal"):
			pilot_data.add_medal(award.get("medal_id", ""), award.get("mission_earned", ""))
	elif award_type == "promotion":
		if pilot_data.has_method("set_rank"):
			pilot_data.set_rank(award.get("new_rank", 0))

# ============================================================================
# HELPER METHODS
# ============================================================================

func _get_pilot_missions_completed(pilot_data: PlayerProfile) -> int:
	"""Get number of missions completed by pilot."""
	if pilot_data.has_method("get_missions_completed"):
		return pilot_data.get_missions_completed()
	return 0

func _get_pilot_rank(pilot_data: PlayerProfile) -> int:
	"""Get pilot's current rank."""
	if pilot_data.has_method("get_rank"):
		return pilot_data.get_rank()
	return 0

func _get_pilot_total_score(pilot_data: PlayerProfile) -> int:
	"""Get pilot's total score."""
	if pilot_data.has_method("get_total_score"):
		return pilot_data.get_total_score()
	return 0

func _get_pilot_total_kills(pilot_data: PlayerProfile) -> int:
	"""Get pilot's total kills."""
	if pilot_data.has_method("get_total_kills"):
		return pilot_data.get_total_kills()
	return 0

# ============================================================================
# STATIC FACTORY METHODS
# ============================================================================

static func create_debriefing_data_manager() -> DebriefingDataManager:
	"""Create a new debriefing data manager instance."""
	var manager: DebriefingDataManager = DebriefingDataManager.new()
	manager.name = "DebriefingDataManager"
	return manager