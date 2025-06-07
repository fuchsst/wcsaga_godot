class_name WCSAIAgent
extends Node

## WCS-specific AI agent with behavior tree integration
## Extends LimboAI for modern behavior tree functionality while maintaining WCS AI behavior patterns

signal behavior_changed(new_behavior: String)
signal target_acquired(target: Node3D)
signal target_lost(previous_target: Node3D)
signal formation_position_updated(position: Vector3, rotation: Vector3)
signal ai_state_changed(old_state: String, new_state: String)
signal formation_disrupted(formation_id: String)
signal formation_assigned(formation_id: String, position: int)
signal formation_leadership_assigned(formation_id: String)

@export var ai_personality: Resource ## AIPersonality resource
@export var skill_level: float = 0.5
@export var aggression_level: float = 0.5
@export var behavior_tree: Resource

var current_target: Node3D
var formation_leader: Node3D
var formation_position_index: int = -1
var formation_manager_ref: FormationManager
var formation_id: String = ""
var is_formation_leader: bool = false
var last_decision_time: float
var decision_frequency: float = 0.1
var performance_monitor: Node
var ship_controller: Node
var current_ai_state: String = "idle"
var accuracy_modifier: float = 1.0
var firing_rate_modifier: float = 1.0
var evasion_skill: float = 1.0
var maneuver_speed: float = 1.0
var formation_precision: float = 1.0
var blackboard: AIBlackboard

func _ready() -> void:
	if not behavior_tree:
		push_warning("WCSAIAgent: No behavior tree assigned")
	
	# Initialize blackboard
	blackboard = AIBlackboard.new()
	
	# Initialize performance monitoring
	performance_monitor = get_node_or_null("PerformanceMonitor")
	if not performance_monitor:
		performance_monitor = preload("res://scripts/ai/core/ai_performance_monitor.gd").new()
		add_child(performance_monitor)
	
	# Create and setup AI ship controller
	var ship_controller_script = preload("res://scripts/ai/core/ai_ship_controller.gd")
	ship_controller = ship_controller_script.new()
	add_child(ship_controller)
	
	# Apply personality if available
	if ai_personality:
		apply_personality()
	
	# Initialize behavior tree
	if behavior_tree:
		pass  # Would set behavior tree when LimboAI is available
	
	# Connect signals
	if has_signal("update_task"):
		connect("update_task", _on_behavior_tree_update)
	
	# Register with AI Manager
	call_deferred("_register_with_ai_manager")

func _process(delta: float) -> void:
	# Update AI at specified frequency
	if Time.get_time_dict_from_system()["unix"] >= last_decision_time + decision_frequency:
		update_ai_decision(delta)
		last_decision_time = Time.get_time_dict_from_system()["unix"]

func apply_personality() -> void:
	if not ai_personality:
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
		"formation_position": formation_position_index,
		"formation_id": formation_id,
		"is_formation_leader": is_formation_leader
	}

func is_formation_leader() -> bool:
	return is_formation_leader

func set_formation_leader(leader: Node3D, position: int = -1) -> void:
	var old_leader: Node3D = formation_leader
	formation_leader = leader
	formation_position_index = position
	is_formation_leader = false
	
	if old_leader != leader:
		formation_position_updated.emit(Vector3.ZERO, Vector3.ZERO)

func set_formation_position_index(index: int) -> void:
	formation_position_index = index

func set_formation_manager(manager: FormationManager) -> void:
	formation_manager_ref = manager

func set_as_formation_leader(formation_id_val: String, manager: FormationManager) -> void:
	formation_id = formation_id_val
	formation_manager_ref = manager
	is_formation_leader = true
	formation_leader = null
	formation_leadership_assigned.emit(formation_id)

func clear_formation_assignment() -> void:
	var old_formation_id: String = formation_id
	formation_leader = null
	formation_position_index = -1
	formation_manager_ref = null
	formation_id = ""
	is_formation_leader = false
	
	if not old_formation_id.is_empty():
		formation_disrupted.emit(old_formation_id)

func clear_formation_leadership() -> void:
	formation_id = ""
	formation_manager_ref = null
	is_formation_leader = false

func get_formation_leader() -> Node3D:
	return formation_leader

func get_formation_position() -> Vector3:
	if formation_manager_ref and not formation_id.is_empty():
		var ship: Node3D = ship_controller.get_physics_body() if ship_controller else get_parent()
		return formation_manager_ref.get_ship_formation_position(ship)
	return Vector3.ZERO

func get_formation_offset() -> Vector3:
	# Calculate relative offset from leader
	if formation_leader and formation_manager_ref:
		var my_pos: Vector3 = get_position()
		var leader_pos: Vector3 = formation_leader.global_position
		return my_pos - leader_pos
	return Vector3.ZERO

func get_formation_id() -> String:
	return formation_id

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
		var my_position: Vector3 = get_position()
		var distance: float = my_position.distance_to(current_target.global_position)
		return max(0.0, 1.0 - (distance / 2000.0))  # Threat decreases with distance
	return 0.0

func get_position() -> Vector3:
	if ship_controller and ship_controller.has_method("get_ship_position"):
		return ship_controller.get_ship_position()
	elif get_parent() and get_parent().has_method("global_position"):
		return get_parent().global_position
	else:
		return Vector3.ZERO

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
	if ship_controller and ship_controller.has_method("get_ship_velocity"):
		return ship_controller.get_ship_velocity()
	return Vector3.ZERO

func get_forward_vector() -> Vector3:
	if ship_controller and ship_controller.has_method("get_ship_forward_vector"):
		return ship_controller.get_ship_forward_vector()
	return Vector3.FORWARD

# Personality integration methods
func set_accuracy_modifier(modifier: float) -> void:
	accuracy_modifier = modifier

func set_firing_rate_modifier(modifier: float) -> void:
	firing_rate_modifier = modifier

func set_evasion_skill(skill: float) -> void:
	evasion_skill = skill

func set_maneuver_speed(speed: float) -> void:
	maneuver_speed = speed

func set_formation_precision(precision: float) -> void:
	formation_precision = precision

func get_accuracy_modifier() -> float:
	return accuracy_modifier

func get_firing_rate_modifier() -> float:
	return firing_rate_modifier

func get_evasion_skill() -> float:
	return evasion_skill

func get_maneuver_speed() -> float:
	return maneuver_speed

func get_formation_precision() -> float:
	return formation_precision

# AI Ship Controller integration
func move_to_position(position: Vector3) -> void:
	if ship_controller:
		ship_controller.set_movement_target(position)

func face_target(target: Node3D) -> void:
	if ship_controller:
		ship_controller.face_target(target)

func fire_weapons(weapon_type: int = 0) -> bool:
	if ship_controller:
		return ship_controller.fire_weapons(weapon_type, current_target)
	return false

func execute_evasive_maneuvers(threat_direction: Vector3 = Vector3.ZERO) -> void:
	if ship_controller:
		var pattern: String = "random"
		if ai_personality:
			pattern = ai_personality.get_maneuver_preference()
		ship_controller.execute_evasive_maneuvers(threat_direction, pattern)

func get_health_percentage() -> float:
	if ship_controller:
		return ship_controller.get_ship_health_percentage()
	return 1.0

func get_mass() -> float:
	if ship_controller:
		return ship_controller.get_ship_mass()
	return 100.0

func is_destroyed() -> bool:
	if ship_controller:
		return ship_controller.is_ship_destroyed()
	return false

func _register_with_ai_manager() -> void:
	var ai_manager: Node = get_node("/root/AIManager")
	if ai_manager and ai_manager.has_method("register_ai_agent"):
		ai_manager.register_ai_agent(self)