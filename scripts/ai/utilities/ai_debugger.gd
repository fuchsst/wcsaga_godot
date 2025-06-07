class_name AIDebugger
extends Node

## AI debugging and visualization system for WCS behavior trees
## Provides real-time AI state monitoring, performance tracking, and visual debugging

signal debug_info_updated(agent: WCSAIAgent, debug_data: Dictionary)
signal performance_warning(agent: WCSAIAgent, warning: String)
signal behavior_tree_visualization_updated(agent: WCSAIAgent, tree_data: Dictionary)

@export var enable_debug_overlay: bool = false
@export var enable_performance_monitoring: bool = true
@export var enable_behavior_tree_visualization: bool = false
@export var debug_update_frequency: float = 0.1  # Updates per second

var monitored_agents: Array = []  # Array[WCSAIAgent] - avoiding circular type issues
var agent_debug_data: Dictionary = {}  # WCSAIAgent -> Dictionary
var behavior_tree_states: Dictionary = {}  # WCSAIAgent -> Dictionary
var performance_history: Dictionary = {}  # WCSAIAgent -> Array[Dictionary]

var debug_overlay: Control
var last_update_time: float = 0.0

func _ready() -> void:
	if enable_debug_overlay:
		_create_debug_overlay()
	
	set_process(enable_debug_overlay or enable_performance_monitoring)

func _process(delta: float) -> void:
	var current_time: float = Time.get_time_from_start()
	if current_time - last_update_time >= debug_update_frequency:
		_update_debug_monitoring()
		last_update_time = current_time

func register_agent(agent: WCSAIAgent) -> void:
	"""Register an AI agent for debugging and monitoring"""
	if not agent or agent in monitored_agents:
		return
	
	monitored_agents.append(agent)
	agent_debug_data[agent] = {}
	behavior_tree_states[agent] = {}
	performance_history[agent] = []
	
	# Connect to agent signals for real-time monitoring
	if agent.has_signal("behavior_changed"):
		agent.behavior_changed.connect(_on_agent_behavior_changed.bind(agent))
	
	if agent.has_signal("target_acquired"):
		agent.target_acquired.connect(_on_agent_target_acquired.bind(agent))
	
	if agent.has_signal("target_lost"):
		agent.target_lost.connect(_on_agent_target_lost.bind(agent))
	
	if agent.has_signal("formation_position_updated"):
		agent.formation_position_updated.connect(_on_agent_formation_updated.bind(agent))
	
	print("AIDebugger: Registered agent for monitoring: %s" % agent.name)

func unregister_agent(agent: WCSAIAgent) -> void:
	"""Remove an AI agent from debugging and monitoring"""
	if not agent or not agent in monitored_agents:
		return
	
	monitored_agents.erase(agent)
	agent_debug_data.erase(agent)
	behavior_tree_states.erase(agent)
	performance_history.erase(agent)
	
	# Disconnect signals
	if agent.has_signal("behavior_changed") and agent.behavior_changed.is_connected(_on_agent_behavior_changed):
		agent.behavior_changed.disconnect(_on_agent_behavior_changed)
	
	if agent.has_signal("target_acquired") and agent.target_acquired.is_connected(_on_agent_target_acquired):
		agent.target_acquired.disconnect(_on_agent_target_acquired)
	
	if agent.has_signal("target_lost") and agent.target_lost.is_connected(_on_agent_target_lost):
		agent.target_lost.disconnect(_on_agent_target_lost)
	
	if agent.has_signal("formation_position_updated") and agent.formation_position_updated.is_connected(_on_agent_formation_updated):
		agent.formation_position_updated.disconnect(_on_agent_formation_updated)

func get_agent_debug_info(agent: WCSAIAgent) -> Dictionary:
	"""Get current debug information for an agent"""
	if not agent in agent_debug_data:
		return {}
	
	return agent_debug_data[agent].duplicate()

func get_behavior_tree_state(agent: WCSAIAgent) -> Dictionary:
	"""Get current behavior tree state for an agent"""
	if not agent in behavior_tree_states:
		return {}
	
	return behavior_tree_states[agent].duplicate()

func get_performance_history(agent: WCSAIAgent, max_entries: int = 100) -> Array:
	"""Get performance history for an agent"""
	if not agent in performance_history:
		return []
	
	var history: Array = performance_history[agent]
	if history.size() <= max_entries:
		return history.duplicate()
	
	return history.slice(-max_entries).duplicate()

func set_debug_overlay_enabled(enabled: bool) -> void:
	"""Enable or disable debug overlay"""
	enable_debug_overlay = enabled
	
	if enabled and not debug_overlay:
		_create_debug_overlay()
	elif not enabled and debug_overlay:
		debug_overlay.queue_free()
		debug_overlay = null
	
	set_process(enable_debug_overlay or enable_performance_monitoring)

func _update_debug_monitoring() -> void:
	"""Update debug monitoring for all registered agents"""
	for agent in monitored_agents:
		if not is_instance_valid(agent):
			continue
		
		_update_agent_debug_data(agent)
		_update_behavior_tree_state(agent)
		_update_performance_data(agent)

func _update_agent_debug_data(agent: WCSAIAgent) -> void:
	"""Update debug data for a specific agent"""
	var debug_data: Dictionary = {
		"timestamp": Time.get_time_from_start(),
		"agent_name": agent.name,
		"position": Vector3.ZERO,
		"velocity": Vector3.ZERO,
		"target": null,
		"formation_status": {},
		"skill_level": 0.0,
		"aggression_level": 0.0,
		"current_behavior": "unknown",
		"health_percentage": 1.0,
		"threat_level": 0.0
	}
	
	# Get ship controller data
	var ship_controller: Node = agent.get_ship_controller() if agent.has_method("get_ship_controller") else null
	if ship_controller:
		if ship_controller.has_method("get_global_position"):
			debug_data["position"] = ship_controller.get_global_position()
		
		if ship_controller.has_method("get_velocity"):
			debug_data["velocity"] = ship_controller.get_velocity()
		
		if ship_controller.has_method("get_health_percentage"):
			debug_data["health_percentage"] = ship_controller.get_health_percentage()
	
	# Get AI agent data
	if agent.has_method("get_current_target"):
		var target: Node = agent.get_current_target()
		debug_data["target"] = target.name if target else null
	
	if agent.has_method("get_formation_status"):
		debug_data["formation_status"] = agent.get_formation_status()
	
	if agent.has_method("get_skill_level"):
		debug_data["skill_level"] = agent.get_skill_level()
	
	if agent.has_method("get_aggression_level"):
		debug_data["aggression_level"] = agent.get_aggression_level()
	
	if agent.has_method("get_perceived_threat_level"):
		debug_data["threat_level"] = agent.get_perceived_threat_level()
	
	# Get current behavior from behavior tree
	var bt_manager: BehaviorTreeManager = _get_behavior_tree_manager()
	if bt_manager:
		var current_tree: BehaviorTree = bt_manager.get_behavior_tree_for_agent(agent)
		if current_tree:
			debug_data["current_behavior"] = current_tree.resource_name
	
	agent_debug_data[agent] = debug_data
	debug_info_updated.emit(agent, debug_data)

func _update_behavior_tree_state(agent: WCSAIAgent) -> void:
	"""Update behavior tree state information for an agent"""
	if not enable_behavior_tree_visualization:
		return
	
	var tree_state: Dictionary = {
		"timestamp": Time.get_time_from_start(),
		"tree_name": "unknown",
		"root_status": "INACTIVE",
		"active_nodes": [],
		"failed_nodes": [],
		"completed_nodes": [],
		"execution_time": 0.0
	}
	
	var bt_manager: BehaviorTreeManager = _get_behavior_tree_manager()
	if bt_manager:
		var current_tree: BehaviorTree = bt_manager.get_behavior_tree_for_agent(agent)
		if current_tree:
			tree_state["tree_name"] = current_tree.resource_name
			
			# Get tree execution state (this would need LimboAI integration)
			_populate_tree_execution_state(current_tree, tree_state)
	
	behavior_tree_states[agent] = tree_state
	behavior_tree_visualization_updated.emit(agent, tree_state)

func _populate_tree_execution_state(tree: BehaviorTree, state: Dictionary) -> void:
	"""Populate behavior tree execution state (requires LimboAI integration)"""
	# This would integrate with LimboAI's debugging capabilities
	# For now, provide placeholder data
	state["root_status"] = "RUNNING"
	state["active_nodes"] = ["Root", "Selector", "AttackTarget"]
	state["execution_time"] = 2.5

func _update_performance_data(agent: WCSAIAgent) -> void:
	"""Update performance monitoring data for an agent"""
	if not enable_performance_monitoring:
		return
	
	var performance_data: Dictionary = {
		"timestamp": Time.get_time_from_start(),
		"frame_time": get_process_delta_time() * 1000.0,  # Convert to milliseconds
		"decision_time": 0.0,
		"action_execution_time": 0.0,
		"condition_evaluation_time": 0.0,
		"memory_usage": 0.0
	}
	
	# Get performance data from agent's performance monitor
	if agent.has_method("get_performance_monitor"):
		var perf_monitor = agent.get_performance_monitor()
		if perf_monitor:
			if perf_monitor.has_method("get_last_decision_time"):
				performance_data["decision_time"] = perf_monitor.get_last_decision_time()
			
			if perf_monitor.has_method("get_average_action_time"):
				performance_data["action_execution_time"] = perf_monitor.get_average_action_time()
			
			if perf_monitor.has_method("get_average_condition_time"):
				performance_data["condition_evaluation_time"] = perf_monitor.get_average_condition_time()
	
	# Check for performance warnings
	var total_ai_time: float = performance_data["decision_time"] + performance_data["action_execution_time"] + performance_data["condition_evaluation_time"]
	if total_ai_time > 5.0:  # 5ms threshold
		var warning: String = "AI performance warning: %s took %.2fms (threshold: 5.0ms)" % [agent.name, total_ai_time]
		performance_warning.emit(agent, warning)
	
	# Store performance history
	var history: Array = performance_history.get(agent, [])
	history.append(performance_data)
	
	# Limit history size
	var max_history_size: int = 1000
	if history.size() > max_history_size:
		history = history.slice(-max_history_size)
	
	performance_history[agent] = history

func _create_debug_overlay() -> void:
	"""Create the debug overlay UI"""
	debug_overlay = Control.new()
	debug_overlay.name = "AIDebugOverlay"
	debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add to scene tree
	get_tree().root.add_child(debug_overlay)
	
	# Create debug panels
	_create_agent_list_panel()
	_create_performance_panel()
	_create_behavior_tree_panel()

func _create_agent_list_panel() -> void:
	"""Create panel showing list of monitored agents"""
	var panel: Panel = Panel.new()
	panel.size = Vector2(300, 400)
	panel.position = Vector2(10, 10)
	debug_overlay.add_child(panel)
	
	var label: Label = Label.new()
	label.text = "Monitored AI Agents"
	label.position = Vector2(10, 10)
	panel.add_child(label)
	
	# This would be populated with actual agent data

func _create_performance_panel() -> void:
	"""Create panel showing performance metrics"""
	var panel: Panel = Panel.new()
	panel.size = Vector2(350, 200)
	panel.position = Vector2(320, 10)
	debug_overlay.add_child(panel)
	
	var label: Label = Label.new()
	label.text = "AI Performance Metrics"
	label.position = Vector2(10, 10)
	panel.add_child(label)

func _create_behavior_tree_panel() -> void:
	"""Create panel showing behavior tree visualization"""
	var panel: Panel = Panel.new()
	panel.size = Vector2(400, 300)
	panel.position = Vector2(10, 420)
	debug_overlay.add_child(panel)
	
	var label: Label = Label.new()
	label.text = "Behavior Tree Visualization"
	label.position = Vector2(10, 10)
	panel.add_child(label)

func _get_behavior_tree_manager() -> BehaviorTreeManager:
	"""Get the behavior tree manager singleton"""
	# This would get the actual behavior tree manager
	return BehaviorTreeManager.new()  # Placeholder

# Signal handlers for agent events
func _on_agent_behavior_changed(agent: WCSAIAgent, new_behavior: String) -> void:
	if agent in agent_debug_data:
		agent_debug_data[agent]["current_behavior"] = new_behavior

func _on_agent_target_acquired(agent: WCSAIAgent, target: Node3D) -> void:
	if agent in agent_debug_data:
		agent_debug_data[agent]["target"] = target.name if target else null

func _on_agent_target_lost(agent: WCSAIAgent, previous_target: Node3D) -> void:
	if agent in agent_debug_data:
		agent_debug_data[agent]["target"] = null

func _on_agent_formation_updated(agent: WCSAIAgent, position: Vector3, rotation: Vector3) -> void:
	if agent in agent_debug_data:
		agent_debug_data[agent]["formation_position"] = position

# Utility methods for external access
func get_all_monitored_agents() -> Array:
	"""Get list of all monitored agents"""
	return monitored_agents.duplicate()

func get_agent_count() -> int:
	"""Get number of monitored agents"""
	return monitored_agents.size()

func clear_all_debug_data() -> void:
	"""Clear all debug data"""
	agent_debug_data.clear()
	behavior_tree_states.clear()
	performance_history.clear()

func export_debug_data_to_file(file_path: String) -> bool:
	"""Export debug data to a file for analysis"""
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("AIDebugger: Failed to open file for writing: %s" % file_path)
		return false
	
	var export_data: Dictionary = {
		"timestamp": Time.get_time_from_start(),
		"agent_debug_data": agent_debug_data,
		"behavior_tree_states": behavior_tree_states,
		"performance_history": performance_history
	}
	
	file.store_string(JSON.stringify(export_data, "\t"))
	file.close()
	
	print("AIDebugger: Debug data exported to %s" % file_path)
	return true