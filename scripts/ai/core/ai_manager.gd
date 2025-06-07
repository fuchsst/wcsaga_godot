extends Node

## AI Manager singleton for WCS-Godot AI coordination
## Manages all AI agents and provides central coordination

signal ai_agent_registered(agent: Node)
signal ai_agent_unregistered(agent: Node)
signal ai_performance_warning(agent: Node, issue: String)

var active_agents: Array[Node] = []
var performance_budget_ms: float = 5.0  # 5ms per frame for AI processing
var debug_mode: bool = false

func _ready() -> void:
	set_process(true)
	
	# Set up performance monitoring
	if debug_mode:
		print("AIManager: Debug mode enabled")

func _process(delta: float) -> void:
	# Monitor overall AI performance
	var start_time: int = Time.get_ticks_usec()
	
	# Clean up invalid agents
	active_agents = active_agents.filter(func(agent): return is_instance_valid(agent))
	
	var processing_time: float = (Time.get_ticks_usec() - start_time) / 1000.0
	
	if processing_time > performance_budget_ms:
		if debug_mode:
			print("AIManager: Performance budget exceeded: ", processing_time, "ms")

func register_ai_agent(agent: Node) -> void:
	if agent in active_agents:
		return
	
	active_agents.append(agent)
	ai_agent_registered.emit(agent)
	
	if debug_mode:
		print("AIManager: Registered AI agent: ", agent.name)

func unregister_ai_agent(agent: Node) -> void:
	var index: int = active_agents.find(agent)
	if index >= 0:
		active_agents.remove_at(index)
		ai_agent_unregistered.emit(agent)
		
		if debug_mode:
			print("AIManager: Unregistered AI agent: ", agent.name)

func get_active_agent_count() -> int:
	return active_agents.size()

func get_agents_by_team(team: int) -> Array[Node]:
	return active_agents.filter(func(agent): return agent.has_method("get_team") and agent.get_team() == team)

func get_agents_in_radius(position: Vector3, radius: float) -> Array[Node]:
	return active_agents.filter(func(agent): return agent.has_method("global_position") and agent.global_position.distance_to(position) <= radius)

func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	
	if debug_mode:
		print("AIManager: Debug mode ", "enabled" if enabled else "disabled")

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
	
	return {
		"active_agents": active_agents.size(),
		"total_execution_time_ms": total_execution_time,
		"performance_budget_ms": performance_budget_ms,
		"budget_utilization": total_execution_time / performance_budget_ms,
		"agent_stats": agent_stats
	}

func create_test_behavior_tree() -> Resource:
	## Creates a simple test behavior tree for integration testing
	var tree: Resource = Resource.new()
	
	# This is a placeholder - would need actual LimboAI behavior tree setup
	# For now, just return an empty resource
	return tree