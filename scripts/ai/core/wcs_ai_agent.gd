class_name WCSAIAgent
extends Node

## WCS-specific AI agent with behavior tree integration
## Extends LimboAI for modern behavior tree functionality while maintaining WCS AI behavior patterns

signal behavior_changed(new_behavior: String)
signal target_acquired(target: Node3D)
signal target_lost(previous_target: Node3D)
signal formation_position_updated(position: Vector3, rotation: Vector3)
signal ai_state_changed(old_state: String, new_state: String)

@export var ai_personality: Resource ## AIPersonality resource
@export var skill_level: float = 0.5
@export var aggression_level: float = 0.5
@export var behavior_tree: Resource

var current_target: Node3D
var formation_leader: WCSAIAgent
var formation_position: int = -1
var last_decision_time: float
var decision_frequency: float = 0.1
var performance_monitor: Node
var ship_controller: Node
var current_ai_state: String = "idle"

func _ready() -> void:
	if not behavior_tree:
		push_warning("WCSAIAgent: No behavior tree assigned")
		return
	
	# Initialize performance monitoring
	performance_monitor = get_node_or_null("PerformanceMonitor")
	if not performance_monitor:
		performance_monitor = preload("res://scripts/ai/core/ai_performance_monitor.gd").new()
		add_child(performance_monitor)
	
	# Find ship controller
	ship_controller = get_parent()
	if not ship_controller:
		push_error("WCSAIAgent: Must be child of ship controller")
		return
	
	# Apply personality if available
	if ai_personality:
		apply_personality()
	
	# Initialize behavior tree
	if behavior_tree:
		pass  # Would set behavior tree when LimboAI is available
	
	# Connect signals
	if has_signal("update_task"):
		connect("update_task", _on_behavior_tree_update)

func _process(delta: float) -> void:
	# Update AI at specified frequency
	if Time.get_time_dict_from_system()["unix"] >= last_decision_time + decision_frequency:
		update_ai_decision(delta)
		last_decision_time = Time.get_time_dict_from_system()["unix"]

func apply_personality() -> void:
	if not ai_personality or not ai_personality.has_method("apply_to_agent"):
		return
	
	ai_personality.apply_to_agent(self)

func update_ai_decision(delta: float) -> void:
	# Record performance
	var start_time: int = Time.get_ticks_usec()
	
	# Would let LimboAI handle behavior tree updates when available
	pass
	
	# Record execution time
	if performance_monitor:
		var execution_time: int = Time.get_ticks_usec() - start_time
		performance_monitor.record_ai_frame_time(execution_time)

func get_ship_controller() -> Node:
	return ship_controller

func get_current_target() -> Node3D:
	return current_target

func set_current_target(target: Node3D) -> void:
	var previous_target: Node3D = current_target
	current_target = target
	
	if previous_target != current_target:
		if previous_target:
			target_lost.emit(previous_target)
		if current_target:
			target_acquired.emit(current_target)

func get_formation_status() -> Dictionary:
	return {
		"is_in_formation": formation_leader != null,
		"formation_leader": formation_leader,
		"formation_position": formation_position
	}

func is_formation_leader() -> bool:
	return formation_leader == null or formation_leader == self

func set_formation_leader(leader: WCSAIAgent, position: int = -1) -> void:
	formation_leader = leader
	formation_position = position

func get_skill_level() -> float:
	return skill_level

func set_skill_level(level: float) -> void:
	skill_level = clamp(level, 0.0, 2.0)

func get_aggression_level() -> float:
	return aggression_level

func set_aggression_level(level: float) -> void:
	aggression_level = clamp(level, 0.0, 2.0)

func get_perceived_threat_level() -> float:
	# Placeholder implementation - would integrate with threat assessment system
	if current_target and is_enemy(current_target):
		var distance: float = global_position.distance_to(current_target.global_position)
		return max(0.0, 1.0 - (distance / 2000.0))  # Threat decreases with distance
	return 0.0

func is_enemy(target: Node) -> bool:
	if not target or not target.has_method("get_team"):
		return false
	
	if not ship_controller or not ship_controller.has_method("get_team"):
		return false
	
	return target.get_team() != ship_controller.get_team()

func set_ai_state(new_state: String) -> void:
	var old_state: String = current_ai_state
	current_ai_state = new_state
	
	if old_state != new_state:
		ai_state_changed.emit(old_state, new_state)

func get_ai_state() -> String:
	return current_ai_state

func _on_behavior_tree_update(task: Node, previous_status: int) -> void:
	# Handle behavior tree updates for debugging and monitoring
	if performance_monitor:
		performance_monitor.record_task_execution(task, previous_status)

## Debug and utility functions

func get_debug_info() -> Dictionary:
	return {
		"ai_state": current_ai_state,
		"current_target": current_target.name if current_target else "None",
		"formation_status": get_formation_status(),
		"skill_level": skill_level,
		"aggression_level": aggression_level,
		"threat_level": get_perceived_threat_level(),
		"behavior_tree": behavior_tree.resource_path if behavior_tree else "None"
	}

func get_performance_stats() -> Dictionary:
	if performance_monitor and performance_monitor.has_method("get_stats"):
		return performance_monitor.get_stats()
	return {}

## Placeholder methods for integration with ship systems

func get_team() -> int:
	if ship_controller and ship_controller.has_method("get_team"):
		return ship_controller.get_team()
	return 0

func get_velocity() -> Vector3:
	if ship_controller and ship_controller.has_method("get_velocity"):
		return ship_controller.get_velocity()
	return Vector3.ZERO

func get_forward_vector() -> Vector3:
	if ship_controller and ship_controller.has_method("get_forward_vector"):
		return ship_controller.get_forward_vector()
	return Vector3.FORWARD