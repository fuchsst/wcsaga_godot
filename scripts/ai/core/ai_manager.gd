extends Node

## Enhanced AI Manager singleton for WCS-Godot AI coordination
## Manages all AI agents, provides central coordination, and handles lifecycle management

signal ai_agent_registered(agent: Node)
signal ai_agent_unregistered(agent: Node)
signal ai_performance_warning(agent: Node, issue: String)
signal ai_system_state_changed(new_state: String)
signal formation_created(formation_id: String, leader: Node)
signal formation_disbanded(formation_id: String)

var active_agents: Array[Node] = []
var agents_by_team: Dictionary = {}  # team_id -> Array[Node]
var agents_by_state: Dictionary = {}  # state -> Array[Node]
var performance_budget_ms: float = 5.0  # 5ms per frame for AI processing
var debug_mode: bool = false
var ai_system_enabled: bool = true
var formation_counter: int = 0
var active_formations: Dictionary = {}  # formation_id -> Formation

# Performance monitoring
var frame_performance_stats: Dictionary = {}
var performance_history: Array[Dictionary] = []
var max_history_frames: int = 300  # 5 seconds at 60 FPS

# AI lifecycle states
enum AILifecycleState {
	SPAWNING,
	ACTIVE,
	DEACTIVATING,
	DESTROYING
}

class Formation:
	var formation_id: String
	var leader: Node
	var members: Array[Node] = []
	var formation_type: String = "diamond"
	var spacing: float = 100.0
	var created_time: float
	
	func _init(id: String, leader_agent: Node) -> void:
		formation_id = id
		leader = leader_agent
		var time_dict: Dictionary = Time.get_time_dict_from_system()
		created_time = time_dict.get("unix", 0)

func _ready() -> void:
	set_process(true)
	
	# Initialize tracking dictionaries
	agents_by_team.clear()
	agents_by_state.clear()
	frame_performance_stats.clear()
	
	# Set up performance monitoring
	if debug_mode:
		print("AIManager: Enhanced AI Manager initialized with debug mode enabled")

func _process(delta: float) -> void:
	if not ai_system_enabled:
		return
		
	# Monitor overall AI performance
	var start_time: int = Time.get_ticks_usec()
	
	# Clean up invalid agents and update tracking
	var before_count: int = active_agents.size()
	active_agents = active_agents.filter(func(agent): return is_instance_valid(agent))
	
	if active_agents.size() != before_count:
		_rebuild_agent_tracking()
	
	# Update performance monitoring
	var processing_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	_update_performance_stats(processing_time, delta)
	
	# Check performance budget
	if processing_time > performance_budget_ms:
		_handle_performance_warning(processing_time)

func register_ai_agent(agent: Node) -> void:
	if agent in active_agents:
		return
	
	active_agents.append(agent)
	
	# Track by team
	var team: int = agent.get_team() if agent.has_method("get_team") else 0
	if not agents_by_team.has(team):
		agents_by_team[team] = []
	agents_by_team[team].append(agent)
	
	# Track by state
	var state: String = agent.get_ai_state() if agent.has_method("get_ai_state") else "unknown"
	if not agents_by_state.has(state):
		agents_by_state[state] = []
	agents_by_state[state].append(agent)
	
	# Connect agent signals
	if agent.has_signal("ai_state_changed") and not agent.ai_state_changed.is_connected(_on_agent_state_changed):
		agent.ai_state_changed.connect(_on_agent_state_changed.bind(agent))
	
	ai_agent_registered.emit(agent)
	
	if debug_mode:
		print("AIManager: Registered AI agent: ", agent.name, " (Team: ", team, ", State: ", state, ")")

func unregister_ai_agent(agent: Node) -> void:
	var index: int = active_agents.find(agent)
	if index < 0:
		return
	
	active_agents.remove_at(index)
	
	# Remove from team tracking
	var team: int = agent.get_team()
	if agents_by_team.has(team):
		var team_agents: Array = agents_by_team[team]
		var team_index: int = team_agents.find(agent)
		if team_index >= 0:
			team_agents.remove_at(team_index)
			if team_agents.is_empty():
				agents_by_team.erase(team)
	
	# Remove from state tracking
	var state: String = agent.get_ai_state()
	if agents_by_state.has(state):
		var state_agents: Array = agents_by_state[state]
		var state_index: int = state_agents.find(agent)
		if state_index >= 0:
			state_agents.remove_at(state_index)
			if state_agents.is_empty():
				agents_by_state.erase(state)
	
	# Disconnect signals
	if agent.ai_state_changed.is_connected(_on_agent_state_changed):
		agent.ai_state_changed.disconnect(_on_agent_state_changed)
	
	# Remove from any formations
	_remove_agent_from_formations(agent)
	
	ai_agent_unregistered.emit(agent)
	
	if debug_mode:
		print("AIManager: Unregistered AI agent: ", agent.name)

func get_active_agent_count() -> int:
	return active_agents.size()

func get_agents_by_team(team: int) -> Array[Node]:
	if agents_by_team.has(team):
		return agents_by_team[team].duplicate()
	return []

func get_agents_by_state(state: String) -> Array[Node]:
	if agents_by_state.has(state):
		return agents_by_state[state].duplicate()
	return []

func get_agents_in_radius(position: Vector3, radius: float) -> Array[Node]:
	return active_agents.filter(func(agent): return agent.global_position.distance_to(position) <= radius)

func get_enemy_agents(friendly_team: int) -> Array[Node]:
	var enemies: Array[Node] = []
	for team in agents_by_team.keys():
		if team != friendly_team:
			enemies.append_array(agents_by_team[team])
	return enemies

func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	
	if debug_mode:
		print("AIManager: Debug mode ", "enabled" if enabled else "disabled")

func set_ai_system_enabled(enabled: bool) -> void:
	var old_state: String = "enabled" if ai_system_enabled else "disabled"
	ai_system_enabled = enabled
	var new_state: String = "enabled" if ai_system_enabled else "disabled"
	
	if old_state != new_state:
		ai_system_state_changed.emit(new_state)
		
		if debug_mode:
			print("AIManager: AI system ", new_state)

func get_performance_stats() -> Dictionary:
	var total_execution_time: float = 0.0
	var agent_stats: Array = []
	
	for agent in active_agents:
		var stats: Dictionary = agent.get_performance_stats()
		agent_stats.append({
			"agent_name": agent.name,
			"stats": stats
		})
		
		if stats.has("frame_time_ms"):
			total_execution_time += stats.frame_time_ms
	
	var current_stats: Dictionary = {
		"active_agents": active_agents.size(),
		"agents_by_team": _get_team_count_summary(),
		"agents_by_state": _get_state_count_summary(),
		"active_formations": active_formations.size(),
		"total_execution_time_ms": total_execution_time,
		"performance_budget_ms": performance_budget_ms,
		"budget_utilization": total_execution_time / performance_budget_ms if performance_budget_ms > 0 else 0.0,
		"agent_stats": agent_stats,
		"system_enabled": ai_system_enabled
	}
	
	return current_stats

# Formation Management
func create_formation(leader: Node, formation_type: String = "diamond") -> String:
	formation_counter += 1
	var formation_id: String = "formation_" + str(formation_counter)
	
	var formation: Formation = Formation.new(formation_id, leader)
	formation.formation_type = formation_type
	active_formations[formation_id] = formation
	
	formation_created.emit(formation_id, leader)
	
	if debug_mode:
		print("AIManager: Created formation ", formation_id, " with leader ", leader.name)
	
	return formation_id

func add_agent_to_formation(formation_id: String, agent: Node, position: int = -1) -> bool:
	if not active_formations.has(formation_id):
		return false
	
	var formation: Formation = active_formations[formation_id]
	if agent in formation.members or agent == formation.leader:
		return false
	
	formation.members.append(agent)
	if agent.has_method("set_formation_leader"):
		agent.set_formation_leader(formation.leader, position)
	
	if debug_mode:
		print("AIManager: Added ", agent.name, " to formation ", formation_id)
	
	return true

func remove_agent_from_formation(formation_id: String, agent: Node) -> bool:
	if not active_formations.has(formation_id):
		return false
	
	var formation: Formation = active_formations[formation_id]
	var index: int = formation.members.find(agent)
	
	if index >= 0:
		formation.members.remove_at(index)
		if agent.has_method("set_formation_leader"):
			agent.set_formation_leader(null, -1)
		
		if debug_mode:
			print("AIManager: Removed ", agent.name, " from formation ", formation_id)
		
		return true
	
	return false

func disband_formation(formation_id: String) -> bool:
	if not active_formations.has(formation_id):
		return false
	
	var formation: Formation = active_formations[formation_id]
	
	# Remove all members from formation
	for member in formation.members:
		if member.has_method("set_formation_leader"):
			member.set_formation_leader(null, -1)
	
	active_formations.erase(formation_id)
	formation_disbanded.emit(formation_id)
	
	if debug_mode:
		print("AIManager: Disbanded formation ", formation_id)
	
	return true

func get_formation_info(formation_id: String) -> Dictionary:
	if not active_formations.has(formation_id):
		return {}
	
	var formation: Formation = active_formations[formation_id]
	return {
		"formation_id": formation.formation_id,
		"leader": formation.leader,
		"members": formation.members,
		"formation_type": formation.formation_type,
		"spacing": formation.spacing,
		"created_time": formation.created_time,
		"member_count": formation.members.size()
	}

# AI Lifecycle Management
func spawn_ai_agent(ship_controller: Node, personality_resource: Resource = null) -> Node:
	var ai_agent_script = load("res://scripts/ai/core/wcs_ai_agent.gd")
	var ai_agent: Node = ai_agent_script.new()
	ship_controller.add_child(ai_agent)
	
	if personality_resource:
		ai_agent.ai_personality = personality_resource
		if ai_agent.has_method("apply_personality"):
			ai_agent.apply_personality()
	
	if ai_agent.has_method("set_ai_state"):
		ai_agent.set_ai_state("spawning")
	register_ai_agent(ai_agent)
	
	# Automatically transition to active after one frame
	call_deferred("_activate_spawned_agent", ai_agent)
	
	return ai_agent

func activate_ai_agent(agent: Node) -> void:
	if agent.has_method("set_ai_state"):
		agent.set_ai_state("active")
	
	if debug_mode:
		print("AIManager: Activated AI agent ", agent.name)

func deactivate_ai_agent(agent: Node) -> void:
	if agent.has_method("set_ai_state"):
		agent.set_ai_state("deactivating")
	
	# Remove from formations
	_remove_agent_from_formations(agent)
	
	if debug_mode:
		print("AIManager: Deactivated AI agent ", agent.name)

func destroy_ai_agent(agent: Node) -> void:
	if agent.has_method("set_ai_state"):
		agent.set_ai_state("destroying")
	unregister_ai_agent(agent)
	
	# Queue for deletion
	call_deferred("_destroy_agent_deferred", agent)

# Helper Methods
func create_test_behavior_tree() -> Resource:
	## Creates a simple test behavior tree for integration testing
	var tree: Resource = Resource.new()
	
	# This is a placeholder - would need actual LimboAI behavior tree setup
	# For now, just return an empty resource
	return tree

# Private Methods
func _rebuild_agent_tracking() -> void:
	agents_by_team.clear()
	agents_by_state.clear()
	
	for agent in active_agents:
		if not is_instance_valid(agent):
			continue
			
		var team: int = agent.get_team()
		if not agents_by_team.has(team):
			agents_by_team[team] = []
		agents_by_team[team].append(agent)
		
		var state: String = agent.get_ai_state()
		if not agents_by_state.has(state):
			agents_by_state[state] = []
		agents_by_state[state].append(agent)

func _update_performance_stats(processing_time: float, delta: float) -> void:
	var time_dict: Dictionary = Time.get_time_dict_from_system()
	frame_performance_stats = {
		"frame_time": delta,
		"ai_processing_time_ms": processing_time,
		"active_agents": active_agents.size(),
		"budget_utilization": processing_time / performance_budget_ms if performance_budget_ms > 0 else 0.0,
		"timestamp": time_dict.get("unix", 0)
	}
	
	performance_history.append(frame_performance_stats)
	
	# Keep history size manageable
	if performance_history.size() > max_history_frames:
		performance_history.pop_front()

func _handle_performance_warning(processing_time: float) -> void:
	if debug_mode:
		print("AIManager: Performance budget exceeded: ", processing_time, "ms (Budget: ", performance_budget_ms, "ms)")
	
	# Emit warning signal for worst performing agents
	for agent in active_agents:
		var stats: Dictionary = agent.get_performance_stats()
		if stats.has("frame_time_ms") and stats.frame_time_ms > 1.0:  # 1ms threshold
			ai_performance_warning.emit(agent, "High frame time: " + str(stats.frame_time_ms) + "ms")

func _on_agent_state_changed(agent: Node, old_state: String, new_state: String) -> void:
	# Update state tracking
	if agents_by_state.has(old_state):
		var old_state_agents: Array = agents_by_state[old_state]
		var index: int = old_state_agents.find(agent)
		if index >= 0:
			old_state_agents.remove_at(index)
			if old_state_agents.is_empty():
				agents_by_state.erase(old_state)
	
	if not agents_by_state.has(new_state):
		agents_by_state[new_state] = []
	agents_by_state[new_state].append(agent)

func _remove_agent_from_formations(agent: Node) -> void:
	var formations_to_remove: Array[String] = []
	
	for formation_id in active_formations.keys():
		var formation: Formation = active_formations[formation_id]
		
		# Remove as member
		var member_index: int = formation.members.find(agent)
		if member_index >= 0:
			formation.members.remove_at(member_index)
		
		# If leader, disband formation
		if formation.leader == agent:
			formations_to_remove.append(formation_id)
	
	# Disband formations where agent was leader
	for formation_id in formations_to_remove:
		disband_formation(formation_id)

func _get_team_count_summary() -> Dictionary:
	var summary: Dictionary = {}
	for team in agents_by_team.keys():
		summary[str(team)] = agents_by_team[team].size()
	return summary

func _get_state_count_summary() -> Dictionary:
	var summary: Dictionary = {}
	for state in agents_by_state.keys():
		summary[state] = agents_by_state[state].size()
	return summary

func _activate_spawned_agent(agent: Node) -> void:
	if is_instance_valid(agent) and agent.has_method("get_ai_state") and agent.get_ai_state() == "spawning":
		activate_ai_agent(agent)

func _destroy_agent_deferred(agent: Node) -> void:
	if is_instance_valid(agent):
		agent.queue_free()