class_name WCSBTCondition
extends Node

## Base class for WCS-specific behavior tree conditions
## Provides common functionality for all WCS AI condition nodes

signal condition_evaluated(result: bool)

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
		push_error("WCSBTCondition requires WCSAIAgent as agent")
		return
	
	ship_controller = ai_agent.get_ship_controller()
	if ship_controller == null:
		push_warning("WCSBTCondition: Ship controller not found for agent " + str(ai_agent))

func _tick(delta: float) -> int:
	if ai_agent == null:
		return 0  # FAILURE
	
	performance_start_time = Time.get_ticks_usec()
	
	var result: bool = evaluate_wcs_condition(delta)
	
	var execution_time: int = Time.get_ticks_usec() - performance_start_time
	if ai_agent.performance_monitor:
		ai_agent.performance_monitor.record_condition_time(get_script().get_path(), execution_time)
	
	condition_evaluated.emit(result)
	return 1 if result else 0  # SUCCESS if result else FAILURE

## Override this method in derived classes to implement specific WCS condition
func evaluate_wcs_condition(delta: float) -> bool:
	push_error("evaluate_wcs_condition must be overridden in derived class")
	return false

## Helper functions for common WCS AI condition checks

func has_current_target() -> bool:
	return get_current_target() != null

func get_current_target() -> Node:
	if ai_agent and ai_agent.has_method("get_current_target"):
		return ai_agent.get_current_target()
	return null

func is_in_formation() -> bool:
	if ai_agent and ai_agent.has_method("get_formation_status"):
		return ai_agent.get_formation_status() != null
	return false

func get_ship_position() -> Vector3:
	if ship_controller and ship_controller.has_method("get_global_position"):
		return ship_controller.get_global_position()
	return Vector3.ZERO

func get_ship_velocity() -> Vector3:
	if ship_controller and ship_controller.has_method("get_velocity"):
		return ship_controller.get_velocity()
	return Vector3.ZERO

func get_ship_health_percentage() -> float:
	if ship_controller and ship_controller.has_method("get_health_percentage"):
		return ship_controller.get_health_percentage()
	return 1.0

func distance_to_target(target: Node) -> float:
	if target == null:
		return INF
	
	var target_pos: Vector3 = Vector3.ZERO
	if target.has_method("get_global_position"):
		target_pos = target.get_global_position()
	elif target.has_method("global_position"):
		target_pos = target.global_position
	
	return get_ship_position().distance_to(target_pos)

func is_enemy(target: Node) -> bool:
	if target == null or ai_agent == null:
		return false
	
	if target.has_method("get_team") and ai_agent.has_method("get_team"):
		return target.get_team() != ai_agent.get_team()
	
	return false

func has_line_of_sight(target: Node) -> bool:
	if target == null:
		return false
	
	var from: Vector3 = get_ship_position()
	var to: Vector3 = target.global_position if target.has_method("global_position") else Vector3.ZERO
	
	# Simple line of sight check - could be enhanced with physics raycast
	var space_state: PhysicsDirectSpaceState3D = ship_controller.get_world_3d().direct_space_state
	if space_state:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		var result: Dictionary = space_state.intersect_ray(query)
		return result.is_empty() or result.get("collider") == target
	
	return true

func is_weapon_in_range(target: Node, weapon_range: float = 1000.0) -> bool:
	if target == null:
		return false
	
	return distance_to_target(target) <= weapon_range

func threat_level_exceeded(threshold: float = 0.5) -> bool:
	if ai_agent and ai_agent.has_method("get_perceived_threat_level"):
		return ai_agent.get_perceived_threat_level() > threshold
	return false

func is_formation_leader() -> bool:
	if ai_agent and ai_agent.has_method("is_formation_leader"):
		return ai_agent.is_formation_leader()
	return false