class_name AILODManager
extends Node

## AI Level-of-Detail manager for performance optimization
## Controls AI update frequencies based on distance, importance, and performance budgets

signal lod_level_changed(agent: WCSAIAgent, old_level: AIUpdateFrequency, new_level: AIUpdateFrequency)
signal performance_budget_adjusted(new_budget_ms: float)

enum AIUpdateFrequency {
	CRITICAL = 0,    # 60 FPS - Player's target, immediate threats
	HIGH = 1,        # 30 FPS - Nearby combatants, active formation members  
	MEDIUM = 2,      # 15 FPS - Medium distance units
	LOW = 3,         # 5 FPS  - Background/distant units
	MINIMAL = 4      # 1 FPS  - Very distant or inactive units
}

# LOD Configuration
var player_reference: Node3D
var lod_update_interval: float = 0.1  # Update LOD every 100ms
var lod_timer: float = 0.0

# Distance thresholds for LOD levels
var distance_thresholds: Dictionary = {
	AIUpdateFrequency.CRITICAL: 0.0,      # Always critical for special cases
	AIUpdateFrequency.HIGH: 2000.0,       # Within 2km
	AIUpdateFrequency.MEDIUM: 5000.0,     # Within 5km
	AIUpdateFrequency.LOW: 10000.0,       # Within 10km
	AIUpdateFrequency.MINIMAL: 99999.0    # Beyond 10km
}

# Update frequency mapping to frame intervals
var update_intervals: Dictionary = {
	AIUpdateFrequency.CRITICAL: 1,       # Every frame (60 FPS)
	AIUpdateFrequency.HIGH: 2,           # Every 2 frames (30 FPS)
	AIUpdateFrequency.MEDIUM: 4,         # Every 4 frames (15 FPS)
	AIUpdateFrequency.LOW: 12,           # Every 12 frames (5 FPS)
	AIUpdateFrequency.MINIMAL: 60        # Every 60 frames (1 FPS)
}

# Performance management
var total_ai_budget_ms: float = 5.0  # 5ms total budget for all AI per frame
var current_frame_usage_ms: float = 0.0
var agent_lod_levels: Dictionary = {}
var registered_agents: Array[WCSAIAgent] = []
var frame_counter: int = 0

# LOD Statistics
var lod_changes_this_frame: int = 0
var total_lod_changes: int = 0
var performance_adjustments: int = 0

func _ready() -> void:
	set_process(true)
	_find_player_reference()

func _process(delta: float) -> void:
	frame_counter += 1
	lod_timer += delta
	current_frame_usage_ms = 0.0
	lod_changes_this_frame = 0
	
	# Update LOD levels periodically
	if lod_timer >= lod_update_interval:
		_update_all_lod_levels()
		lod_timer = 0.0

func register_ai_agent(agent: WCSAIAgent) -> void:
	if agent in registered_agents:
		return
	
	registered_agents.append(agent)
	agent_lod_levels[agent] = AIUpdateFrequency.MEDIUM  # Default to medium
	
	# Connect to agent removal
	if agent.tree_exiting.is_connected(_on_agent_removed):
		agent.tree_exiting.disconnect(_on_agent_removed)
	agent.tree_exiting.connect(_on_agent_removed.bind(agent))

func unregister_ai_agent(agent: WCSAIAgent) -> void:
	if agent in registered_agents:
		registered_agents.erase(agent)
	
	if agent in agent_lod_levels:
		agent_lod_levels.erase(agent)

func determine_ai_update_frequency(agent: WCSAIAgent) -> AIUpdateFrequency:
	if not player_reference:
		return AIUpdateFrequency.MEDIUM
	
	# Special cases that always get high priority
	if _is_critical_agent(agent):
		return AIUpdateFrequency.CRITICAL
	
	# Calculate distance-based LOD
	var distance_to_player: float = agent.global_position.distance_to(player_reference.global_position)
	var base_lod: AIUpdateFrequency = _get_distance_based_lod(distance_to_player)
	
	# Factor in importance modifiers
	var importance_boost: int = _calculate_importance_boost(agent)
	var final_lod: int = max(0, int(base_lod) - importance_boost)
	
	return AIUpdateFrequency.values()[final_lod]

func should_update_ai_this_frame(agent: WCSAIAgent) -> bool:
	var lod_level: AIUpdateFrequency = get_agent_lod_level(agent)
	var update_interval: int = update_intervals[lod_level]
	
	return (frame_counter % update_interval) == 0

func get_agent_lod_level(agent: WCSAIAgent) -> AIUpdateFrequency:
	return agent_lod_levels.get(agent, AIUpdateFrequency.MEDIUM)

func set_agent_lod_level(agent: WCSAIAgent, level: AIUpdateFrequency) -> void:
	var old_level: AIUpdateFrequency = get_agent_lod_level(agent)
	
	if old_level != level:
		agent_lod_levels[agent] = level
		lod_level_changed.emit(agent, old_level, level)
		lod_changes_this_frame += 1
		total_lod_changes += 1

func allocate_frame_time(agent: WCSAIAgent, requested_ms: float) -> float:
	var lod_level: AIUpdateFrequency = get_agent_lod_level(agent)
	var base_budget: float = _get_lod_budget(lod_level)
	
	# Adjust based on current frame usage
	var available_budget: float = total_ai_budget_ms - current_frame_usage_ms
	var allocated_time: float = min(requested_ms, min(base_budget, available_budget))
	
	current_frame_usage_ms += allocated_time
	return allocated_time

func report_frame_usage(agent: WCSAIAgent, actual_ms: float) -> void:
	# Update performance metrics
	# This will be called by AI agents after their update
	pass

func get_lod_statistics() -> Dictionary:
	var lod_counts: Dictionary = {}
	for freq in AIUpdateFrequency.values():
		lod_counts[AIUpdateFrequency.keys()[freq]] = 0
	
	for agent in registered_agents:
		var level: AIUpdateFrequency = get_agent_lod_level(agent)
		var key: String = AIUpdateFrequency.keys()[level]
		lod_counts[key] += 1
	
	return {
		"total_agents": registered_agents.size(),
		"lod_distribution": lod_counts,
		"frame_budget_ms": total_ai_budget_ms,
		"current_usage_ms": current_frame_usage_ms,
		"budget_utilization": current_frame_usage_ms / total_ai_budget_ms if total_ai_budget_ms > 0 else 0.0,
		"lod_changes_this_frame": lod_changes_this_frame,
		"total_lod_changes": total_lod_changes,
		"performance_adjustments": performance_adjustments
	}

func set_total_ai_budget(budget_ms: float) -> void:
	total_ai_budget_ms = clamp(budget_ms, 1.0, 50.0)  # Between 1ms and 50ms
	performance_budget_adjusted.emit(total_ai_budget_ms)
	performance_adjustments += 1

func force_lod_update() -> void:
	_update_all_lod_levels()

# Private Methods

func _find_player_reference() -> void:
	# Try to find player ship reference
	# For now, use a simple approach - this can be enhanced later
	var player_ships: Array = get_tree().get_nodes_in_group("player_ships")
	if player_ships.size() > 0:
		player_reference = player_ships[0]
	else:
		# Fallback to origin if no player found
		player_reference = Node3D.new()
		player_reference.global_position = Vector3.ZERO
		add_child(player_reference)

func _update_all_lod_levels() -> void:
	for agent in registered_agents:
		if not is_instance_valid(agent):
			continue
		
		var new_lod: AIUpdateFrequency = determine_ai_update_frequency(agent)
		set_agent_lod_level(agent, new_lod)

func _is_critical_agent(agent: WCSAIAgent) -> bool:
	# Determine if agent should always be critical priority
	
	# Player's current target
	if agent.is_player_target:
		return true
	
	# Ships in active combat with player
	if agent.current_target and agent.current_target.is_in_group("player_ships"):
		return true
	
	# Formation leaders
	if agent.is_formation_leader:
		return true
	
	# Mission-critical ships
	if agent.is_mission_critical:
		return true
	
	return false

func _get_distance_based_lod(distance: float) -> AIUpdateFrequency:
	for freq in [AIUpdateFrequency.HIGH, AIUpdateFrequency.MEDIUM, AIUpdateFrequency.LOW]:
		if distance <= distance_thresholds[freq]:
			return freq
	
	return AIUpdateFrequency.MINIMAL

func _calculate_importance_boost(agent: WCSAIAgent) -> int:
	var boost: int = 0
	
	# Combat status boost
	if agent.combat_status == agent.CombatStatus.ACTIVE:
		boost += 1
	
	# Formation member boost
	if agent.formation_status == agent.FormationStatus.ACTIVE:
		boost += 1
	
	# Player interaction boost
	if agent.has_recent_player_interaction():
		boost += 1
	
	# Skill level boost (high-skill pilots get more attention)
	if agent.skill_level > 0.8:
		boost += 1
	
	return boost

func _get_lod_budget(level: AIUpdateFrequency) -> float:
	var base_budgets: Dictionary = {
		AIUpdateFrequency.CRITICAL: 2.0,   # 2ms for critical agents
		AIUpdateFrequency.HIGH: 1.0,       # 1ms for high priority
		AIUpdateFrequency.MEDIUM: 0.5,     # 0.5ms for medium priority
		AIUpdateFrequency.LOW: 0.2,        # 0.2ms for low priority
		AIUpdateFrequency.MINIMAL: 0.1     # 0.1ms for minimal priority
	}
	
	return base_budgets.get(level, 0.5)

func _on_agent_removed(agent: WCSAIAgent) -> void:
	unregister_ai_agent(agent)

# Configuration methods

func set_distance_threshold(level: AIUpdateFrequency, distance: float) -> void:
	distance_thresholds[level] = distance

func set_update_interval(level: AIUpdateFrequency, frames: int) -> void:
	update_intervals[level] = max(1, frames)

func set_lod_update_frequency(interval_seconds: float) -> void:
	lod_update_interval = clamp(interval_seconds, 0.01, 1.0)