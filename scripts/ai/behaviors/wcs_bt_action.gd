class_name WCSBTAction
extends Node

## Base class for WCS-specific behavior tree actions
## Provides common functionality for all WCS AI behavior tree nodes

signal action_started()
signal action_completed(result: int)
signal action_failed(reason: String)

var ai_agent: WCSAIAgent
var ship_controller: Node
var performance_start_time: int

func _setup() -> void:
	if has_method("get_agent"):
		ai_agent = get_agent() as WCSAIAgent
	else:
		# Fallback for testing or non-LimboAI contexts
		ai_agent = get_parent() as WCSAIAgent
	
	if ai_agent == null:
		push_error("WCSBTAction requires WCSAIAgent as agent")
		return
	
	ship_controller = ai_agent.get_ship_controller()
	if ship_controller == null:
		push_warning("WCSBTAction: Ship controller not found for agent " + str(ai_agent))

func _enter() -> void:
	performance_start_time = Time.get_ticks_usec()
	action_started.emit()

func _exit() -> void:
	var execution_time: int = Time.get_ticks_usec() - performance_start_time
	if ai_agent and ai_agent.performance_monitor:
		ai_agent.performance_monitor.record_action_time(get_script().get_path(), execution_time)

func _tick(delta: float) -> int:
	if ai_agent == null or ship_controller == null:
		action_failed.emit("Missing required components")
		return 0  # FAILURE
	
	var result: int = execute_wcs_action(delta)
	
	if result == 1:  # SUCCESS
		action_completed.emit(result)
	elif result == 0:  # FAILURE
		action_failed.emit("Action execution failed")
	
	return result

## Override this method in derived classes to implement specific WCS behavior
func execute_wcs_action(delta: float) -> int:
	push_error("execute_wcs_action must be overridden in derived class")
	return 0  # FAILURE

## Helper functions for common WCS AI operations

func get_ship_position() -> Vector3:
	if ship_controller and ship_controller.has_method("get_global_position"):
		return ship_controller.get_global_position()
	return Vector3.ZERO

func get_ship_velocity() -> Vector3:
	if ship_controller and ship_controller.has_method("get_velocity"):
		return ship_controller.get_velocity()
	return Vector3.ZERO

func get_ship_forward() -> Vector3:
	if ship_controller and ship_controller.has_method("get_forward_vector"):
		return ship_controller.get_forward_vector()
	return Vector3.FORWARD

func set_ship_target_position(target: Vector3) -> void:
	if ship_controller and ship_controller.has_method("set_target_position"):
		ship_controller.set_target_position(target)

func set_ship_target_rotation(target: Vector3) -> void:
	if ship_controller and ship_controller.has_method("set_target_rotation"):
		ship_controller.set_target_rotation(target)

func get_current_target() -> Node:
	if ai_agent and ai_agent.has_method("get_current_target"):
		return ai_agent.get_current_target()
	return null

func distance_to_target(target: Node) -> float:
	if target == null:
		return INF
	
	var target_pos: Vector3 = Vector3.ZERO
	if target.has_method("get_global_position"):
		target_pos = target.get_global_position()
	elif target.has_method("global_position"):
		target_pos = target.global_position
	
	return get_ship_position().distance_to(target_pos)

func is_facing_target(target: Node, tolerance: float = 0.1) -> bool:
	if target == null:
		return false
	
	var to_target: Vector3 = target.global_position - get_ship_position()
	var forward: Vector3 = get_ship_forward()
	
	return forward.dot(to_target.normalized()) > (1.0 - tolerance)

func get_skill_modifier() -> float:
	if ai_agent and ai_agent.has_method("get_skill_level"):
		return ai_agent.get_skill_level()
	return 1.0