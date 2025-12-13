# AIController - Per-Ship AI Component
# Manages Behavior Tree execution for individual ships
# Bridge between ship entity, mission goals, and LimboAI

class_name AIController
extends Node

## AI State
@export var behavior_tree: BehaviorTree = null ## Currently active behavior tree
@export var ai_class: AIClassResource = null ## AI class configuration

## References
var ship: Node = null ## Parent ship entity
var bt_player: BTPlayer = null ## LimboAI Behavior Tree player
var blackboard: Blackboard = null ## Shared data for BT

## Goal system (mirrors WCS ai_goal structure)
var active_goals: Array = [] ## Array of goal dictionaries
var current_goal_index: int = 0

## Combat state
var target_entity: Node = null
var guard_entity: Node = null
var waypoint_list: Array[Vector3] = []
var waypoint_index: int = 0

## Timing
var next_think_time: float = 0.0
var think_interval: float = 0.1 ## How often AI makes decisions


func _get_mission_manager() -> Node:
	"""Get MissionManager autoload safely"""
	return (
		Engine.get_singleton("MissionManager") if Engine.has_singleton("MissionManager") else null
	)


func _ready() -> void:
	# Find parent ship
	ship = get_parent()
	if not ship:
		push_error("AIController: No parent ship found")
		return

	# Create blackboard
	blackboard = Blackboard.new()
	_populate_blackboard()

	# Create BTPlayer if we have a behavior tree
	if behavior_tree:
		_setup_bt_player()


func _process(delta: float) -> void:
	if not ship or not is_instance_valid(ship):
		return

	# Update blackboard with current state
	_update_blackboard()

	# Process think cycle
	next_think_time -= delta
	if next_think_time <= 0:
		next_think_time = think_interval
		_think()


# === PUBLIC API ===


func set_behavior_tree(bt: BehaviorTree) -> void:
	"""Assign a new behavior tree"""
	behavior_tree = bt
	if bt_player:
		bt_player.queue_free()
	_setup_bt_player()


func add_goal(goal_type: int, target_name: String, priority: int = 50) -> void:
	"""Add an AI goal (from mission events)"""
	var goal = {
		"type": goal_type, "target_name": target_name, "priority": priority, "completed": false
	}

	# Insert sorted by priority
	var inserted = false
	for i in range(active_goals.size()):
		if active_goals[i].priority < priority:
			active_goals.insert(i, goal)
			inserted = true
			break

	if not inserted:
		active_goals.append(goal)

	# Re-evaluate current goal
	_evaluate_goal_priority()


func clear_goals() -> void:
	"""Clear all AI goals"""
	active_goals.clear()
	current_goal_index = 0


func set_target(entity: Node) -> void:
	"""Set current combat target"""
	target_entity = entity
	if blackboard:
		blackboard.set_var("target", entity)


func set_guard_target(entity: Node) -> void:
	"""Set entity to guard"""
	guard_entity = entity
	if blackboard:
		blackboard.set_var("guard_target", entity)


func set_waypoints(points: Array[Vector3]) -> void:
	"""Set waypoint list to fly"""
	waypoint_list = points
	waypoint_index = 0
	if blackboard:
		blackboard.set_var("waypoints", points)
		blackboard.set_var("waypoint_index", 0)


func set_wing_leader(leader: Node, slot: int = 1) -> void:
	"""Set wing leader for formation flying"""
	if blackboard:
		blackboard.set_var("wing_leader", leader)
		blackboard.set_var("formation_slot", slot)


func set_dock_target(target: Node, dock_point: int = 0) -> void:
	"""Set target for docking operations"""
	if blackboard:
		blackboard.set_var("dock_target", target)
		blackboard.set_var("dock_point", dock_point)


func set_carrier(carrier_ship: Node, bay_idx: int = 0) -> void:
	"""Set carrier for bay emerge/depart operations"""
	if blackboard:
		blackboard.set_var("carrier", carrier_ship)
		blackboard.set_var("bay_index", bay_idx)


func set_path_nodes(path: Array[Vector3]) -> void:
	"""Set path nodes for path following"""
	if blackboard:
		blackboard.set_var("path_nodes", path)
		blackboard.set_var("path_index", 0)


func notify_under_attack(attacker: Node) -> void:
	"""Called when ship is taking fire"""
	if blackboard:
		blackboard.set_var("under_attack", true)
		blackboard.set_var("threat_source", attacker)


# === PRIVATE HELPERS ===


func _setup_bt_player() -> void:
	"""Create and configure BTPlayer"""
	if not behavior_tree:
		return

	bt_player = BTPlayer.new()
	bt_player.name = "BTPlayer"
	bt_player.behavior_tree = behavior_tree
	bt_player.blackboard = blackboard
	add_child(bt_player)


func _populate_blackboard() -> void:
	"""Initialize blackboard with ship data"""
	if not blackboard or not ship:
		return

	# Ship reference
	blackboard.set_var("ship", ship)
	blackboard.set_var("ship_name", ship.name if ship else "")

	# AI class resource reference (for tasks to access all params)
	blackboard.set_var("ai_class", ai_class)

	# Core AI parameters
	if ai_class:
		blackboard.set_var("accuracy", ai_class.accuracy)
		blackboard.set_var("evasion", ai_class.evasion)
		blackboard.set_var("courage", ai_class.courage)
		blackboard.set_var("patience", ai_class.patience)

		# Combat timing
		blackboard.set_var("ai_turn_time_scale", ai_class.ai_turn_time_scale)
		blackboard.set_var("ai_fire_delay_scale", ai_class.hostile_ai_fire_delay_scale)

		# Attack tactics
		blackboard.set_var("ai_glide_attack_percent", ai_class.ai_glide_attack_percent)
		blackboard.set_var("ai_circle_strafe_percent", ai_class.ai_circle_strafe_percent)

	# Combat state
	blackboard.set_var("target", null)
	blackboard.set_var("target_valid", false)
	blackboard.set_var("guard_target", null)
	blackboard.set_var("waypoints", [])
	blackboard.set_var("waypoint_index", 0)

	# Ship status
	blackboard.set_var("hull_percent", 1.0)
	blackboard.set_var("weapon_energy_percent", 1.0)
	blackboard.set_var("under_attack", false)
	blackboard.set_var("firing", false)

	# Formation/wing
	blackboard.set_var("wing_leader", null)
	blackboard.set_var("formation_slot", 0)

	# Docking/bay
	blackboard.set_var("dock_target", null)
	blackboard.set_var("carrier", null)
	blackboard.set_var("bay_index", 0)
	blackboard.set_var("is_docked", false)
	blackboard.set_var("in_bay", false)

	# Navigation
	blackboard.set_var("path_nodes", [])
	blackboard.set_var("path_index", 0)

	# Mission manager reference
	var mm = _get_mission_manager()
	if mm:
		blackboard.set_var("mission_manager", mm)


func _update_blackboard() -> void:
	"""Update blackboard with current ship state"""
	if not blackboard or not ship:
		return

	# Position and velocity
	if "global_position" in ship:
		blackboard.set_var("position", ship.global_position)

	if "velocity" in ship:
		blackboard.set_var("velocity", ship.velocity)
	elif "state" in ship and ship.state and "velocity" in ship.state:
		blackboard.set_var("velocity", ship.state.velocity)

	# Combat status
	if "current_hull" in ship:
		blackboard.set_var(
			"hull_percent", ship.get_hull_percent() if ship.has_method("get_hull_percent") else 1.0
		)

	if "weapon_energy" in ship:
		blackboard.set_var(
			"weapon_energy_percent",
			(
				ship.get_weapon_energy_percent()
				if ship.has_method("get_weapon_energy_percent")
				else 1.0
			)
		)

	# Target data
	if target_entity and is_instance_valid(target_entity):
		blackboard.set_var("target_valid", true)
		blackboard.set_var(
			"target_position",
			target_entity.global_position if "global_position" in target_entity else Vector3.ZERO
		)
		if ship and "global_position" in ship:
			blackboard.set_var(
				"target_distance", ship.global_position.distance_to(target_entity.global_position)
			)
	else:
		blackboard.set_var("target_valid", false)
		target_entity = null
		blackboard.set_var("target", null)


func _think() -> void:
	"""AI think cycle - evaluate goals and update state"""
	# Check if current target is still valid
	if target_entity and not is_instance_valid(target_entity):
		target_entity = null
		if blackboard:
			blackboard.set_var("target", null)

	# Process current goal
	if current_goal_index < active_goals.size():
		var goal = active_goals[current_goal_index]
		_process_goal(goal)


func _evaluate_goal_priority() -> void:
	"""Re-evaluate which goal should be active"""
	# For now just use highest priority uncompleted goal
	for i in range(active_goals.size()):
		if not active_goals[i].get("completed", false):
			current_goal_index = i
			return
	current_goal_index = 0


func _process_goal(goal: Dictionary) -> void:
	"""Process a single goal"""
	var goal_type = goal.get("type", 0)
	var target_name = goal.get("target_name", "")

	# Resolve target if needed
	if target_name and not target_entity:
		var mm = _get_mission_manager()
		if mm:
			var entity = mm.get_entity(target_name)
			if entity:
				set_target(entity)
