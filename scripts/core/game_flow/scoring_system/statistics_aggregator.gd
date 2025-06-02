class_name StatisticsAggregator
extends RefCounted

## Statistics Aggregator for Mission Performance
## Aggregates mission scoring data into pilot career statistics
## Integrates with existing PilotStatistics and PilotPerformanceTracker systems

signal statistics_aggregated(mission_score: MissionScore, pilot_stats: PilotStatistics)

## Aggregate mission statistics into pilot career data
func aggregate_mission_statistics(mission_score: MissionScore, pilot_profile: PlayerProfile) -> void:
	if not mission_score or not pilot_profile or not pilot_profile.pilot_stats:
		push_warning("StatisticsAggregator: Invalid mission score or pilot profile")
		return
	
	var pilot_stats: PilotStatistics = pilot_profile.pilot_stats
	
	# Update mission counts
	pilot_stats.missions_flown += 1
	if mission_score.mission_success:
		pilot_stats.missions_completed += 1
	else:
		pilot_stats.missions_failed += 1
	
	# Update score statistics
	pilot_stats.score += mission_score.final_score
	_update_mission_score_history(mission_score, pilot_stats)
	
	# Update kill statistics
	_update_kill_statistics(mission_score, pilot_stats)
	
	# Update weapon statistics
	_update_weapon_statistics(mission_score, pilot_stats)
	
	# Update damage and survival statistics
	_update_survival_statistics(mission_score, pilot_stats)
	
	# Update time statistics
	_update_time_statistics(mission_score, pilot_stats)
	
	# Update objective statistics
	_update_objective_statistics(mission_score, pilot_stats)
	
	# Recalculate derived statistics
	pilot_stats._update_calculated_stats()
	
	# Mark profile as modified
	pilot_profile.mark_as_played()
	
	statistics_aggregated.emit(mission_score, pilot_stats)
	
	print("StatisticsAggregator: Mission statistics aggregated for pilot %s" % pilot_profile.callsign)

## Update mission score history
func _update_mission_score_history(mission_score: MissionScore, pilot_stats: PilotStatistics) -> void:
	# Track highest score
	if mission_score.final_score > pilot_stats.highest_score:
		pilot_stats.highest_score = mission_score.final_score
	
	# Update score breakdown tracking
	var total_kills_score: int = pilot_stats.get_meta("total_kills_score", 0)
	var total_objectives_score: int = pilot_stats.get_meta("total_objectives_score", 0)
	var total_survival_score: int = pilot_stats.get_meta("total_survival_score", 0)
	var total_efficiency_score: int = pilot_stats.get_meta("total_efficiency_score", 0)
	var total_bonus_score: int = pilot_stats.get_meta("total_bonus_score", 0)
	
	pilot_stats.set_meta("total_kills_score", total_kills_score + mission_score.kill_score)
	pilot_stats.set_meta("total_objectives_score", total_objectives_score + mission_score.objective_score)
	pilot_stats.set_meta("total_survival_score", total_survival_score + mission_score.survival_score)
	pilot_stats.set_meta("total_efficiency_score", total_efficiency_score + mission_score.efficiency_score)
	pilot_stats.set_meta("total_bonus_score", total_bonus_score + mission_score.bonus_score)

## Update kill statistics
func _update_kill_statistics(mission_score: MissionScore, pilot_stats: PilotStatistics) -> void:
	pilot_stats.kill_count += mission_score.total_kills
	
	# Update kill type statistics
	for kill_data in mission_score.kills:
		_update_kill_type_statistics(kill_data, pilot_stats)
	
	# Track kill streaks and efficiency
	var mission_kill_efficiency: float = 0.0
	if mission_score.total_kills > 0:
		# Calculate kills per minute for this mission
		mission_kill_efficiency = float(mission_score.total_kills) / (mission_score.completion_time / 60.0)
	
	# Update best kill efficiency
	var best_kill_efficiency: float = pilot_stats.get_meta("best_kill_efficiency", 0.0)
	if mission_kill_efficiency > best_kill_efficiency:
		pilot_stats.set_meta("best_kill_efficiency", mission_kill_efficiency)

## Update kill type statistics
func _update_kill_type_statistics(kill_data: KillData, pilot_stats: PilotStatistics) -> void:
	# Update kill counts by target type
	var target_type_kills: Dictionary = pilot_stats.get_meta("kill_counts_by_type", {})
	
	if not target_type_kills.has(kill_data.target_type):
		target_type_kills[kill_data.target_type] = 0
	target_type_kills[kill_data.target_type] += 1
	
	pilot_stats.set_meta("kill_counts_by_type", target_type_kills)
	
	# Update kill counts by weapon
	var weapon_kills: Dictionary = pilot_stats.get_meta("kill_counts_by_weapon", {})
	
	if not weapon_kills.has(kill_data.weapon_used):
		weapon_kills[kill_data.weapon_used] = 0
	weapon_kills[kill_data.weapon_used] += 1
	
	pilot_stats.set_meta("kill_counts_by_weapon", weapon_kills)
	
	# Track special kill methods
	if kill_data.kill_method != "normal":
		var special_kills: Dictionary = pilot_stats.get_meta("special_kill_methods", {})
		
		if not special_kills.has(kill_data.kill_method):
			special_kills[kill_data.kill_method] = 0
		special_kills[kill_data.kill_method] += 1
		
		pilot_stats.set_meta("special_kill_methods", special_kills)

## Update weapon statistics
func _update_weapon_statistics(mission_score: MissionScore, pilot_stats: PilotStatistics) -> void:
	# Extract weapon usage from performance analysis
	var performance_analysis: PerformanceAnalysis = mission_score.performance_analysis as PerformanceAnalysis
	if not performance_analysis:
		return
	
	# Update weapon proficiency tracking
	var weapon_stats: Dictionary = pilot_stats.get_meta("weapon_proficiency_history", {})
	
	for weapon_type in performance_analysis.weapon_proficiency:
		if not weapon_stats.has(weapon_type):
			weapon_stats[weapon_type] = {
				"total_shots": 0,
				"total_hits": 0,
				"total_kills": 0,
				"total_damage": 0.0,
				"missions_used": 0
			}
		
		var weapon_prof: Dictionary = performance_analysis.weapon_proficiency[weapon_type]
		var current_stats: Dictionary = weapon_stats[weapon_type]
		
		# Estimate shots and hits from accuracy and efficiency data
		var estimated_shots: int = int(weapon_prof.get("kill_ratio", 0.0) * 100)  # Rough estimate
		var estimated_hits: int = int(estimated_shots * (weapon_prof.get("accuracy", 0.0) / 100.0))
		
		current_stats["total_shots"] += estimated_shots
		current_stats["total_hits"] += estimated_hits
		current_stats["total_damage"] += weapon_prof.get("damage_per_shot", 0.0) * estimated_shots
		current_stats["missions_used"] += 1
		
		# Count kills for this weapon in this mission
		for kill_data in mission_score.kills:
			if kill_data.weapon_used == weapon_type:
				current_stats["total_kills"] += 1
	
	pilot_stats.set_meta("weapon_proficiency_history", weapon_stats)

## Update survival statistics
func _update_survival_statistics(mission_score: MissionScore, pilot_stats: PilotStatistics) -> void:
	# Update damage taken
	var total_damage_taken: float = pilot_stats.get_meta("total_damage_taken", 0.0)
	pilot_stats.set_meta("total_damage_taken", total_damage_taken + mission_score.total_damage_taken)
	
	# Update close calls
	var total_close_calls: int = pilot_stats.get_meta("total_close_calls", 0)
	pilot_stats.set_meta("total_close_calls", total_close_calls + mission_score.close_calls)
	
	# Update death count
	var total_deaths: int = pilot_stats.get_meta("total_deaths", 0)
	pilot_stats.set_meta("total_deaths", total_deaths + mission_score.deaths)
	
	# Track survival streaks
	if mission_score.total_damage_taken == 0.0:
		var perfect_missions: int = pilot_stats.get_meta("perfect_survival_missions", 0)
		pilot_stats.set_meta("perfect_survival_missions", perfect_missions + 1)
	
	# Update best survival performance
	var performance_analysis: PerformanceAnalysis = mission_score.performance_analysis as PerformanceAnalysis
	if performance_analysis:
		var best_damage_avoidance: float = pilot_stats.get_meta("best_damage_avoidance_rating", 0.0)
		if performance_analysis.damage_avoidance_rating > best_damage_avoidance:
			pilot_stats.set_meta("best_damage_avoidance_rating", performance_analysis.damage_avoidance_rating)

## Update time statistics
func _update_time_statistics(mission_score: MissionScore, pilot_stats: PilotStatistics) -> void:
	# Update total flight time
	pilot_stats.flight_time += int(mission_score.completion_time)
	
	# Track mission time performance
	var mission_times: Array = pilot_stats.get_meta("mission_completion_times", [])
	mission_times.append(mission_score.completion_time)
	
	# Keep only recent mission times (limit to 50)
	if mission_times.size() > 50:
		mission_times.pop_front()
	
	pilot_stats.set_meta("mission_completion_times", mission_times)
	
	# Calculate and update average mission time
	var total_time: float = 0.0
	for time in mission_times:
		total_time += time
	
	var average_time: float = total_time / float(mission_times.size())
	pilot_stats.set_meta("average_mission_time", average_time)
	
	# Track best mission time
	var best_time: float = pilot_stats.get_meta("best_mission_time", 999999.0)
	if mission_score.completion_time < best_time:
		pilot_stats.set_meta("best_mission_time", mission_score.completion_time)

## Update objective statistics
func _update_objective_statistics(mission_score: MissionScore, pilot_stats: PilotStatistics) -> void:
	# Update objectives completed
	var total_objectives_completed: int = pilot_stats.get_meta("total_objectives_completed", 0)
	var total_objectives_attempted: int = pilot_stats.get_meta("total_objectives_attempted", 0)
	var total_bonus_objectives: int = pilot_stats.get_meta("total_bonus_objectives", 0)
	
	pilot_stats.set_meta("total_objectives_completed", total_objectives_completed + mission_score.objectives_completed.size())
	pilot_stats.set_meta("total_objectives_attempted", total_objectives_attempted + mission_score.total_objectives)
	pilot_stats.set_meta("total_bonus_objectives", total_bonus_objectives + mission_score.bonus_objectives_completed)
	
	# Calculate objective success rate
	var new_total_attempted: int = total_objectives_attempted + mission_score.total_objectives
	var new_total_completed: int = total_objectives_completed + mission_score.objectives_completed.size()
	
	if new_total_attempted > 0:
		var success_rate: float = float(new_total_completed) / float(new_total_attempted) * 100.0
		pilot_stats.set_meta("objective_success_rate", success_rate)
	
	# Track perfect objective missions
	if mission_score.objectives_completed.size() == mission_score.total_objectives and mission_score.total_objectives > 0:
		var perfect_objective_missions: int = pilot_stats.get_meta("perfect_objective_missions", 0)
		pilot_stats.set_meta("perfect_objective_missions", perfect_objective_missions + 1)

## Get career statistics summary
func get_career_statistics_summary(pilot_stats: PilotStatistics) -> Dictionary:
	var summary: Dictionary = {
		"basic_stats": {
			"missions_flown": pilot_stats.missions_flown,
			"missions_completed": pilot_stats.missions_completed,
			"total_score": pilot_stats.score,
			"total_kills": pilot_stats.kill_count,
			"flight_time_hours": float(pilot_stats.flight_time) / 3600.0
		},
		"efficiency_metrics": {
			"mission_success_rate": _calculate_mission_success_rate(pilot_stats),
			"average_score_per_mission": _calculate_average_score_per_mission(pilot_stats),
			"kills_per_mission": _calculate_kills_per_mission(pilot_stats),
			"objectives_success_rate": pilot_stats.get_meta("objective_success_rate", 0.0)
		},
		"performance_records": {
			"highest_score": pilot_stats.highest_score,
			"best_kill_efficiency": pilot_stats.get_meta("best_kill_efficiency", 0.0),
			"best_damage_avoidance": pilot_stats.get_meta("best_damage_avoidance_rating", 0.0),
			"best_mission_time": pilot_stats.get_meta("best_mission_time", 0.0),
			"perfect_missions": pilot_stats.get_meta("perfect_survival_missions", 0)
		},
		"specialized_stats": {
			"kill_counts_by_type": pilot_stats.get_meta("kill_counts_by_type", {}),
			"weapon_proficiency": _calculate_weapon_proficiency_summary(pilot_stats),
			"special_achievements": _calculate_special_achievements(pilot_stats)
		}
	}
	
	return summary

## Calculate mission success rate
func _calculate_mission_success_rate(pilot_stats: PilotStatistics) -> float:
	if pilot_stats.missions_flown == 0:
		return 0.0
	return float(pilot_stats.missions_completed) / float(pilot_stats.missions_flown) * 100.0

## Calculate average score per mission
func _calculate_average_score_per_mission(pilot_stats: PilotStatistics) -> float:
	if pilot_stats.missions_flown == 0:
		return 0.0
	return float(pilot_stats.score) / float(pilot_stats.missions_flown)

## Calculate kills per mission
func _calculate_kills_per_mission(pilot_stats: PilotStatistics) -> float:
	if pilot_stats.missions_flown == 0:
		return 0.0
	return float(pilot_stats.kill_count) / float(pilot_stats.missions_flown)

## Calculate weapon proficiency summary
func _calculate_weapon_proficiency_summary(pilot_stats: PilotStatistics) -> Dictionary:
	var weapon_history: Dictionary = pilot_stats.get_meta("weapon_proficiency_history", {})
	var summary: Dictionary = {}
	
	for weapon_type in weapon_history:
		var stats: Dictionary = weapon_history[weapon_type]
		var accuracy: float = 0.0
		
		if stats["total_shots"] > 0:
			accuracy = float(stats["total_hits"]) / float(stats["total_shots"]) * 100.0
		
		summary[weapon_type] = {
			"accuracy": accuracy,
			"total_kills": stats["total_kills"],
			"missions_used": stats["missions_used"],
			"effectiveness": _calculate_weapon_effectiveness_rating(stats)
		}
	
	return summary

## Calculate weapon effectiveness rating
func _calculate_weapon_effectiveness_rating(weapon_stats: Dictionary) -> float:
	var accuracy: float = 0.0
	if weapon_stats["total_shots"] > 0:
		accuracy = float(weapon_stats["total_hits"]) / float(weapon_stats["total_shots"])
	
	var kill_ratio: float = 0.0
	if weapon_stats["total_shots"] > 0:
		kill_ratio = float(weapon_stats["total_kills"]) / float(weapon_stats["total_shots"])
	
	var damage_per_shot: float = 0.0
	if weapon_stats["total_shots"] > 0:
		damage_per_shot = weapon_stats["total_damage"] / float(weapon_stats["total_shots"])
	
	# Composite effectiveness rating
	return (accuracy * 40.0) + (kill_ratio * 100.0) + (damage_per_shot * 0.1)

## Calculate special achievements
func _calculate_special_achievements(pilot_stats: PilotStatistics) -> Dictionary:
	return {
		"perfect_missions": pilot_stats.get_meta("perfect_survival_missions", 0),
		"perfect_objective_missions": pilot_stats.get_meta("perfect_objective_missions", 0),
		"total_bonus_objectives": pilot_stats.get_meta("total_bonus_objectives", 0),
		"special_kill_methods": pilot_stats.get_meta("special_kill_methods", {}),
		"total_close_calls": pilot_stats.get_meta("total_close_calls", 0),
		"total_deaths": pilot_stats.get_meta("total_deaths", 0)
	}