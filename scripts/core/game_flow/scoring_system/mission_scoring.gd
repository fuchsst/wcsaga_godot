class_name MissionScoring
extends RefCounted

## Mission Scoring Engine
## Provides comprehensive mission performance evaluation and real-time scoring
## Integrates with existing PilotPerformanceTracker and mission systems

signal mission_scoring_initialized(mission_id: String, difficulty: int)
signal kill_scored(kill_data: KillData, total_kill_score: int)
signal objective_completed(objective_data: ObjectiveCompletion, total_objective_score: int)
signal mission_score_finalized(mission_score: MissionScore)

# Components
var _scoring_config: ScoringConfiguration
var _current_mission_score: MissionScore
var _performance_tracker: PerformanceTracker

# State tracking
var _is_scoring_active: bool = false

## Initialize mission scoring system
func initialize_mission_scoring(mission_data: MissionData, difficulty: int) -> void:
	_scoring_config = ScoringConfiguration.create_for_mission(mission_data, difficulty)
	_current_mission_score = MissionScore.new()
	_performance_tracker = PerformanceTracker.new()
	
	_current_mission_score.mission_id = mission_data.mission_id
	_current_mission_score.mission_title = mission_data.mission_name
	_current_mission_score.difficulty_level = difficulty
	_current_mission_score.start_time = Time.get_unix_time_from_system()
	
	# Initialize mission objectives count
	if mission_data.objectives:
		_current_mission_score.total_objectives = mission_data.objectives.size()
	
	_is_scoring_active = true
	mission_scoring_initialized.emit(mission_data.mission_id, difficulty)
	
	print("MissionScoring: Initialized scoring for mission %s (difficulty: %d)" % [mission_data.mission_id, difficulty])

## Record a kill event
func record_kill(target_type: String, target_class: String, weapon_used: String, kill_method: String = "normal") -> void:
	if not _current_mission_score or not _is_scoring_active:
		push_warning("MissionScoring: Attempted to record kill without active mission scoring")
		return
	
	# Calculate kill score based on target type and difficulty
	var kill_score: int = _calculate_kill_score(target_type, target_class, weapon_used, kill_method)
	
	# Record the kill
	var kill_data: KillData = KillData.new()
	kill_data.target_type = target_type
	kill_data.target_class = target_class
	kill_data.weapon_used = weapon_used
	kill_data.kill_method = kill_method
	kill_data.score_value = kill_score
	kill_data.timestamp = Time.get_unix_time_from_system()
	
	_current_mission_score.kills.append(kill_data)
	_current_mission_score.total_kills += 1
	_current_mission_score.kill_score += kill_score
	
	# Update combat effectiveness metrics
	_performance_tracker.record_kill(kill_data)
	
	kill_scored.emit(kill_data, _current_mission_score.kill_score)
	
	print("MissionScoring: Kill recorded - %s %s (%d points)" % [target_type, target_class, kill_score])

## Record objective completion
func record_objective_completion(objective_id: String, objective_name: String, completion_type: String = "normal", bonus_achieved: bool = false) -> void:
	if not _current_mission_score or not _is_scoring_active:
		push_warning("MissionScoring: Attempted to record objective without active mission scoring")
		return
	
	# Calculate objective score
	var objective_score: int = _calculate_objective_score(objective_id, completion_type, bonus_achieved)
	
	# Record objective completion
	var objective_data: ObjectiveCompletion = ObjectiveCompletion.new()
	objective_data.objective_id = objective_id
	objective_data.objective_name = objective_name
	objective_data.completion_type = completion_type
	objective_data.bonus_achieved = bonus_achieved
	objective_data.score_value = objective_score
	objective_data.completion_time = Time.get_unix_time_from_system()
	
	_current_mission_score.objectives_completed.append(objective_data)
	_current_mission_score.objective_score += objective_score
	
	if bonus_achieved:
		_current_mission_score.bonus_objectives_completed += 1
	
	objective_completed.emit(objective_data, _current_mission_score.objective_score)
	
	print("MissionScoring: Objective completed - %s (%d points)" % [objective_name, objective_score])

## Record damage event
func record_damage_event(damage_type: String, damage_amount: float, source: String) -> void:
	if not _current_mission_score or not _is_scoring_active:
		return
	
	# Record damage taken
	var damage_data: DamageEvent = DamageEvent.new()
	damage_data.damage_type = damage_type
	damage_data.damage_amount = damage_amount
	damage_data.source = source
	damage_data.timestamp = Time.get_unix_time_from_system()
	damage_data.is_critical = damage_amount > 50.0  # Consider critical if > 50 damage
	
	_current_mission_score.damage_events.append(damage_data)
	_current_mission_score.total_damage_taken += damage_amount
	
	# Check for close calls (high damage events)
	if damage_amount > 30.0:
		_current_mission_score.close_calls += 1
	
	# Update survival metrics
	_performance_tracker.record_damage(damage_data)

## Record weapon fire event
func record_weapon_fire(weapon_type: String, hit: bool, damage_dealt: float = 0.0) -> void:
	if not _performance_tracker:
		return
	
	_performance_tracker.record_weapon_fire(weapon_type, hit, damage_dealt)

## Record tactical event
func record_tactical_event(event_type: String, event_data: Dictionary) -> void:
	if not _performance_tracker:
		return
	
	_performance_tracker.record_tactical_event(event_type, event_data)

## Finalize mission score
func finalize_mission_score(mission_success: bool, completion_time: float, mission_completion_type: String = "normal") -> MissionScore:
	if not _current_mission_score or not _is_scoring_active:
		push_warning("MissionScoring: Attempted to finalize without active mission scoring")
		return null
	
	_current_mission_score.mission_success = mission_success
	_current_mission_score.completion_time = completion_time
	_current_mission_score.mission_completion_type = mission_completion_type
	_current_mission_score.end_time = Time.get_unix_time_from_system()
	
	# Calculate final score components
	_calculate_survival_score()
	_calculate_efficiency_score()
	_calculate_bonus_scores()
	
	# Calculate final score
	_current_mission_score.final_score = _calculate_final_score()
	
	# Generate performance analysis
	_current_mission_score.performance_analysis = _performance_tracker.generate_analysis()
	
	# Create score breakdown
	_create_score_breakdown()
	
	_is_scoring_active = false
	mission_score_finalized.emit(_current_mission_score)
	
	print("MissionScoring: Mission score finalized - %d points (success: %s)" % [_current_mission_score.final_score, str(mission_success)])
	
	var final_score: MissionScore = _current_mission_score
	_current_mission_score = null  # Clear for next mission
	
	return final_score

## Get current score
func get_current_score() -> int:
	if not _current_mission_score:
		return 0
	
	return (_current_mission_score.kill_score + 
			_current_mission_score.objective_score + 
			_current_mission_score.survival_score + 
			_current_mission_score.efficiency_score + 
			_current_mission_score.bonus_score)

## Get current mission score object
func get_current_mission_score() -> MissionScore:
	return _current_mission_score

## Check if scoring is active
func is_scoring_active() -> bool:
	return _is_scoring_active

## Calculate kill score
func _calculate_kill_score(target_type: String, target_class: String, weapon_used: String, kill_method: String) -> int:
	var base_score: int = _scoring_config.get_target_base_score(target_type, target_class)
	
	# Apply weapon multipliers
	var weapon_multiplier: float = _scoring_config.get_weapon_multiplier(weapon_used)
	
	# Apply method multipliers (headshot, stealth kill, etc.)
	var method_multiplier: float = _scoring_config.get_kill_method_multiplier(kill_method)
	
	# Apply difficulty multiplier
	var difficulty_multiplier: float = _scoring_config.difficulty_multiplier
	
	var final_score: int = int(base_score * weapon_multiplier * method_multiplier * difficulty_multiplier)
	
	return max(final_score, 1)  # Minimum 1 point per kill

## Calculate objective score
func _calculate_objective_score(objective_id: String, completion_type: String, bonus_achieved: bool) -> int:
	var base_score: int = _scoring_config.get_objective_base_score(objective_id)
	
	# Apply completion type multiplier
	var completion_multiplier: float = _scoring_config.get_completion_type_multiplier(completion_type)
	
	# Apply bonus multiplier
	var bonus_multiplier: float = 1.0
	if bonus_achieved:
		bonus_multiplier = _scoring_config.bonus_objective_multiplier
	
	var final_score: int = int(base_score * completion_multiplier * bonus_multiplier)
	
	return final_score

## Calculate survival score
func _calculate_survival_score() -> void:
	var max_survival_score: int = _scoring_config.max_survival_score
	var damage_penalty_rate: float = _scoring_config.damage_penalty_rate
	
	# Calculate survival score based on damage taken
	var damage_penalty: float = _current_mission_score.total_damage_taken * damage_penalty_rate
	var survival_score: int = max(0, max_survival_score - int(damage_penalty))
	
	# Apply death penalty
	if _current_mission_score.deaths > 0:
		survival_score = int(survival_score * _scoring_config.death_penalty_multiplier)
	
	_current_mission_score.survival_score = survival_score

## Calculate efficiency score
func _calculate_efficiency_score() -> void:
	var mission_duration: float = _current_mission_score.end_time - _current_mission_score.start_time
	var par_time: float = _scoring_config.par_time_seconds
	
	if mission_duration <= par_time:
		# Bonus for completing under par time
		var time_bonus_ratio: float = (par_time - mission_duration) / par_time
		_current_mission_score.efficiency_score = int(_scoring_config.max_efficiency_score * time_bonus_ratio)
	else:
		# Penalty for exceeding par time
		var time_penalty_ratio: float = min(1.0, (mission_duration - par_time) / par_time)
		_current_mission_score.efficiency_score = int(_scoring_config.max_efficiency_score * (1.0 - time_penalty_ratio))
	
	_current_mission_score.efficiency_score = max(0, _current_mission_score.efficiency_score)

## Calculate bonus scores
func _calculate_bonus_scores() -> void:
	var bonus_score: int = 0
	
	# Perfect mission bonus (no damage taken)
	if _current_mission_score.total_damage_taken == 0.0:
		bonus_score += _scoring_config.perfect_mission_bonus
	
	# All objectives bonus
	if _current_mission_score.objectives_completed.size() == _current_mission_score.total_objectives and _current_mission_score.total_objectives > 0:
		bonus_score += _scoring_config.all_objectives_bonus
	
	# Speed bonus (completing significantly under par time)
	var mission_duration: float = _current_mission_score.end_time - _current_mission_score.start_time
	if mission_duration < _scoring_config.par_time_seconds * 0.8:
		bonus_score += _scoring_config.speed_bonus
	
	# Accuracy bonus (calculated from performance tracker)
	if _performance_tracker:
		var accuracy: float = _performance_tracker._calculate_accuracy_percentage()
		if accuracy >= 90.0:
			bonus_score += _scoring_config.accuracy_bonus
	
	_current_mission_score.bonus_score = bonus_score

## Calculate final score
func _calculate_final_score() -> int:
	var total_score: int = (_current_mission_score.kill_score + 
							_current_mission_score.objective_score + 
							_current_mission_score.survival_score + 
							_current_mission_score.efficiency_score + 
							_current_mission_score.bonus_score)
	
	# Apply mission success multiplier
	if not _current_mission_score.mission_success:
		total_score = int(total_score * _scoring_config.failure_penalty_multiplier)
	
	# Apply difficulty multiplier to final score
	total_score = int(total_score * _scoring_config.difficulty_multiplier)
	
	return max(0, total_score)

## Create detailed score breakdown
func _create_score_breakdown() -> void:
	_current_mission_score.score_breakdown = {
		"kill_score": _current_mission_score.kill_score,
		"objective_score": _current_mission_score.objective_score,
		"survival_score": _current_mission_score.survival_score,
		"efficiency_score": _current_mission_score.efficiency_score,
		"bonus_score": _current_mission_score.bonus_score,
		"difficulty_multiplier": _scoring_config.difficulty_multiplier,
		"mission_success": _current_mission_score.mission_success,
		"failure_penalty": 1.0 if _current_mission_score.mission_success else _scoring_config.failure_penalty_multiplier
	}