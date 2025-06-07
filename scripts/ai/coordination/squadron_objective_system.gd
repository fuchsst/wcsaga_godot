class_name SquadronObjectiveSystem
extends Node

## Squadron objective system for goal distribution and task assignment.
## Manages squadron-level objectives and distributes tactical goals across multiple ships.

signal objective_assigned(objective_id: String, assigned_ships: Array[Node3D])
signal objective_completed(objective_id: String, success: bool, completion_time: float)
signal objective_failed(objective_id: String, failure_reason: String)
signal task_assigned(task_id: String, ship: Node3D, task_type: String)
signal task_completed(task_id: String, ship: Node3D, success: bool)
signal objective_priority_changed(objective_id: String, old_priority: int, new_priority: int)

## Objective types for squadron missions
enum ObjectiveType {
	DESTROY_TARGET,       ## Destroy specific target(s)
	PROTECT_ASSET,        ## Protect friendly asset(s)
	ESCORT_MISSION,       ## Escort specific ship/convoy
	PATROL_AREA,          ## Patrol designated area
	RECONNAISSANCE,       ## Gather intelligence on area/targets
	INTERCEPT_MISSION,    ## Intercept incoming threats
	STRIKE_MISSION,       ## Strike enemy installation/fleet
	DEFENSIVE_SCREEN,     ## Maintain defensive screen
	SEARCH_AND_DESTROY,   ## Hunt and destroy enemy forces
	AREA_DENIAL          ## Deny enemy access to area
}

## Task types for individual ships
enum TaskType {
	ATTACK_PRIMARY,       ## Attack primary target
	ATTACK_SECONDARY,     ## Attack secondary target
	PROVIDE_COVER,        ## Provide covering fire
	SCOUT_AHEAD,          ## Reconnaissance ahead
	MAINTAIN_POSITION,    ## Hold specific position
	ESCORT_TARGET,        ## Close escort of asset
	INTERCEPT_THREAT,     ## Intercept specific threat
	SUPPRESS_DEFENSES,    ## Suppress enemy defenses
	MARK_TARGETS,         ## Target designation and marking
	EMERGENCY_RESPONSE   ## Respond to emergency situation
}

## Objective priority levels
enum ObjectivePriority {
	CRITICAL,    ## Mission-critical objectives
	HIGH,        ## High priority objectives
	MEDIUM,      ## Standard priority objectives
	LOW,         ## Optional objectives
	SECONDARY    ## Secondary objectives
}

## Objective status tracking
enum ObjectiveStatus {
	PENDING,     ## Assigned but not started
	ACTIVE,      ## Currently being executed
	COMPLETED,   ## Successfully completed
	FAILED,      ## Failed to complete
	CANCELLED,   ## Cancelled or superseded
	ON_HOLD     ## Temporarily suspended
}

## Squadron objective structure
class SquadronObjective:
	var objective_id: String
	var objective_type: ObjectiveType
	var priority: ObjectivePriority
	var status: ObjectiveStatus
	var assigned_ships: Array[Node3D] = []
	var target_entities: Array[Node3D] = []
	var objective_area: Vector3
	var objective_radius: float = 1000.0
	var time_limit: float = -1.0  # -1 = no time limit
	var creation_time: float
	var completion_time: float = -1.0
	var success_criteria: Dictionary = {}
	var failure_conditions: Dictionary = {}
	var context_data: Dictionary = {}
	var subtasks: Array[SquadronTask] = []
	
	func _init(id: String, type: ObjectiveType, obj_priority: ObjectivePriority) -> void:
		objective_id = id
		objective_type = type
		priority = obj_priority
		status = ObjectiveStatus.PENDING
		creation_time = Time.get_time_dict_from_system()["unix"]

## Individual task structure
class SquadronTask:
	var task_id: String
	var task_type: TaskType
	var assigned_ship: Node3D
	var target: Node3D
	var task_position: Vector3
	var task_status: ObjectiveStatus
	var parent_objective_id: String
	var task_parameters: Dictionary = {}
	var creation_time: float
	var completion_time: float = -1.0
	
	func _init(id: String, type: TaskType, objective_id: String) -> void:
		task_id = id
		task_type = type
		parent_objective_id = objective_id
		task_status = ObjectiveStatus.PENDING
		creation_time = Time.get_time_dict_from_system()["unix"]

# Objective management
var active_objectives: Dictionary = {}
var objective_history: Array[SquadronObjective] = []
var objective_counter: int = 0
var task_counter: int = 0

# Task assignment and tracking
var active_tasks: Dictionary = {}
var ship_assignments: Dictionary = {}  # Ship -> Array of task IDs
var task_performance_tracking: Dictionary = {}

# Dependencies
var wing_coordination_manager: WingCoordinationManager
var tactical_communication_system: TacticalCommunicationSystem
var dynamic_role_assignment: DynamicRoleAssignment

# Configuration
@export var max_active_objectives: int = 10
@export var objective_timeout_check_interval: float = 5.0
@export var task_reassignment_cooldown: float = 15.0

func _ready() -> void:
	_initialize_objective_system()
	_setup_performance_tracking()

func _initialize_objective_system() -> void:
	# Get necessary systems
	wing_coordination_manager = get_node("/root/AIManager/WingCoordinationManager") as WingCoordinationManager
	tactical_communication_system = get_node("TacticalCommunicationSystem") as TacticalCommunicationSystem
	dynamic_role_assignment = get_node("DynamicRoleAssignment") as DynamicRoleAssignment
	
	# Initialize tracking
	active_objectives.clear()
	objective_history.clear()
	active_tasks.clear()
	ship_assignments.clear()

func _setup_performance_tracking() -> void:
	# Setup performance tracking
	task_performance_tracking = {
		"objectives_completed": 0,
		"objectives_failed": 0,
		"average_completion_time": 0.0,
		"task_success_rate": {},
		"ship_performance": {}
	}

func _process(delta: float) -> void:
	_update_active_objectives(delta)
	_check_objective_timeouts()
	_monitor_task_progress()
	_handle_dynamic_reassignments()

## Creates a new squadron objective
func create_objective(objective_type: ObjectiveType, priority: ObjectivePriority, targets: Array[Node3D] = [], area: Vector3 = Vector3.ZERO, parameters: Dictionary = {}) -> String:
	var objective_id: String = "obj_" + str(objective_counter)
	objective_counter += 1
	
	var objective: SquadronObjective = SquadronObjective.new(objective_id, objective_type, priority)
	objective.target_entities = targets
	objective.objective_area = area
	objective.objective_radius = parameters.get("radius", 1000.0)
	objective.time_limit = parameters.get("time_limit", -1.0)
	objective.success_criteria = parameters.get("success_criteria", {})
	objective.failure_conditions = parameters.get("failure_conditions", {})
	objective.context_data = parameters
	
	active_objectives[objective_id] = objective
	
	return objective_id

## Assigns ships to an objective
func assign_ships_to_objective(objective_id: String, ships: Array[Node3D]) -> bool:
	if not active_objectives.has(objective_id):
		return false
	
	var objective: SquadronObjective = active_objectives[objective_id]
	objective.assigned_ships = ships
	
	# Generate and assign tasks for the ships
	_generate_tasks_for_objective(objective)
	
	objective_assigned.emit(objective_id, ships)
	return true

## Activates an objective and begins execution
func activate_objective(objective_id: String) -> bool:
	if not active_objectives.has(objective_id):
		return false
	
	var objective: SquadronObjective = active_objectives[objective_id]
	if objective.status != ObjectiveStatus.PENDING:
		return false
	
	objective.status = ObjectiveStatus.ACTIVE
	
	# Activate all subtasks
	for task in objective.subtasks:
		_activate_task(task)
	
	# Communicate objective to assigned ships
	_communicate_objective_to_ships(objective)
	
	return true

## Completes an objective
func complete_objective(objective_id: String, success: bool, reason: String = "") -> bool:
	if not active_objectives.has(objective_id):
		return false
	
	var objective: SquadronObjective = active_objectives[objective_id]
	objective.status = ObjectiveStatus.COMPLETED if success else ObjectiveStatus.FAILED
	objective.completion_time = Time.get_time_dict_from_system()["unix"]
	
	# Complete all associated tasks
	for task in objective.subtasks:
		_complete_task(task.task_id, success)
	
	# Move to history
	objective_history.append(objective)
	active_objectives.erase(objective_id)
	
	# Update performance tracking
	_update_objective_performance_tracking(objective, success)
	
	# Emit completion signal
	if success:
		objective_completed.emit(objective_id, success, objective.completion_time - objective.creation_time)
	else:
		objective_failed.emit(objective_id, reason)
	
	return true

## Changes objective priority
func change_objective_priority(objective_id: String, new_priority: ObjectivePriority) -> bool:
	if not active_objectives.has(objective_id):
		return false
	
	var objective: SquadronObjective = active_objectives[objective_id]
	var old_priority: ObjectivePriority = objective.priority
	objective.priority = new_priority
	
	# Reorder task priorities
	_reorder_task_priorities(objective)
	
	objective_priority_changed.emit(objective_id, old_priority, new_priority)
	return true

## Assigns individual task to a ship
func assign_task_to_ship(ship: Node3D, task_type: TaskType, target: Node3D = null, position: Vector3 = Vector3.ZERO, parameters: Dictionary = {}) -> String:
	var task_id: String = "task_" + str(task_counter)
	task_counter += 1
	
	var task: SquadronTask = SquadronTask.new(task_id, task_type, "")
	task.assigned_ship = ship
	task.target = target
	task.task_position = position
	task.task_parameters = parameters
	
	active_tasks[task_id] = task
	
	# Track ship assignment
	if not ship_assignments.has(ship):
		ship_assignments[ship] = []
	ship_assignments[ship].append(task_id)
	
	# Activate task
	_activate_task(task)
	
	task_assigned.emit(task_id, ship, TaskType.keys()[task_type])
	return task_id

## Gets current objectives for a ship
func get_ship_objectives(ship: Node3D) -> Array[Dictionary]:
	var ship_objectives: Array[Dictionary] = []
	
	# Find objectives that include this ship
	for objective_id in active_objectives:
		var objective: SquadronObjective = active_objectives[objective_id]
		if ship in objective.assigned_ships:
			ship_objectives.append(_get_objective_summary(objective))
	
	return ship_objectives

## Gets current tasks for a ship
func get_ship_tasks(ship: Node3D) -> Array[Dictionary]:
	var ship_tasks: Array[Dictionary] = []
	var task_ids: Array = ship_assignments.get(ship, [])
	
	for task_id in task_ids:
		if active_tasks.has(task_id):
			var task: SquadronTask = active_tasks[task_id]
			ship_tasks.append(_get_task_summary(task))
	
	return ship_tasks

## Gets objective status and progress
func get_objective_status(objective_id: String) -> Dictionary:
	if not active_objectives.has(objective_id):
		return {}
	
	var objective: SquadronObjective = active_objectives[objective_id]
	return _get_objective_summary(objective)

## Cancels an objective
func cancel_objective(objective_id: String, reason: String = "cancelled") -> bool:
	if not active_objectives.has(objective_id):
		return false
	
	var objective: SquadronObjective = active_objectives[objective_id]
	objective.status = ObjectiveStatus.CANCELLED
	
	# Cancel all subtasks
	for task in objective.subtasks:
		_cancel_task(task.task_id)
	
	# Move to history
	objective_history.append(objective)
	active_objectives.erase(objective_id)
	
	return true

func _generate_tasks_for_objective(objective: SquadronObjective) -> void:
	# Generate specific tasks based on objective type
	match objective.objective_type:
		ObjectiveType.DESTROY_TARGET:
			_generate_destroy_target_tasks(objective)
		ObjectiveType.PROTECT_ASSET:
			_generate_protect_asset_tasks(objective)
		ObjectiveType.ESCORT_MISSION:
			_generate_escort_mission_tasks(objective)
		ObjectiveType.PATROL_AREA:
			_generate_patrol_area_tasks(objective)
		ObjectiveType.RECONNAISSANCE:
			_generate_reconnaissance_tasks(objective)
		ObjectiveType.INTERCEPT_MISSION:
			_generate_intercept_mission_tasks(objective)
		ObjectiveType.STRIKE_MISSION:
			_generate_strike_mission_tasks(objective)
		ObjectiveType.DEFENSIVE_SCREEN:
			_generate_defensive_screen_tasks(objective)
		ObjectiveType.SEARCH_AND_DESTROY:
			_generate_search_destroy_tasks(objective)
		ObjectiveType.AREA_DENIAL:
			_generate_area_denial_tasks(objective)

func _generate_destroy_target_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for destroy target objective
	var ship_count: int = objective.assigned_ships.size()
	var target_count: int = objective.target_entities.size()
	
	if target_count == 0 or ship_count == 0:
		return
	
	# Assign primary attack roles
	var attack_ships: int = min(ship_count, target_count * 2)  # 2 ships per target max
	
	for i in range(attack_ships):
		var ship: Node3D = objective.assigned_ships[i]
		var target_index: int = i % target_count
		var target: Node3D = objective.target_entities[target_index]
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.ATTACK_PRIMARY, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		task.target = target
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task
	
	# Assign remaining ships to support roles
	for i in range(attack_ships, ship_count):
		var ship: Node3D = objective.assigned_ships[i]
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.PROVIDE_COVER, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task

func _generate_protect_asset_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for protect asset objective
	var ship_count: int = objective.assigned_ships.size()
	var asset_count: int = objective.target_entities.size()
	
	if asset_count == 0 or ship_count == 0:
		return
	
	# Distribute ships around assets for protection
	var ships_per_asset: int = ship_count / asset_count
	var ship_index: int = 0
	
	for asset in objective.target_entities:
		for i in range(ships_per_asset):
			if ship_index >= ship_count:
				break
			
			var ship: Node3D = objective.assigned_ships[ship_index]
			ship_index += 1
			
			var task: SquadronTask = SquadronTask.new(
				"task_" + str(task_counter), 
				TaskType.ESCORT_TARGET, 
				objective.objective_id
			)
			task_counter += 1
			
			task.assigned_ship = ship
			task.target = asset
			objective.subtasks.append(task)
			active_tasks[task.task_id] = task

func _generate_escort_mission_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for escort mission
	_generate_protect_asset_tasks(objective)  # Similar to protection

func _generate_patrol_area_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for area patrol
	var ship_count: int = objective.assigned_ships.size()
	
	# Divide area into patrol sectors
	var patrol_positions: Array[Vector3] = _calculate_patrol_positions(objective.objective_area, objective.objective_radius, ship_count)
	
	for i in range(ship_count):
		var ship: Node3D = objective.assigned_ships[i]
		var patrol_pos: Vector3 = patrol_positions[i] if i < patrol_positions.size() else objective.objective_area
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.MAINTAIN_POSITION, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		task.task_position = patrol_pos
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task

func _generate_reconnaissance_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for reconnaissance mission
	var ship_count: int = objective.assigned_ships.size()
	
	# Assign scouts and support
	var scout_count: int = min(ship_count, 2)  # Max 2 scouts
	
	for i in range(scout_count):
		var ship: Node3D = objective.assigned_ships[i]
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.SCOUT_AHEAD, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		task.task_position = objective.objective_area
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task
	
	# Assign remaining ships to cover
	for i in range(scout_count, ship_count):
		var ship: Node3D = objective.assigned_ships[i]
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.PROVIDE_COVER, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task

func _generate_intercept_mission_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for intercept mission
	var ship_count: int = objective.assigned_ships.size()
	var target_count: int = objective.target_entities.size()
	
	# All ships get intercept tasks
	for i in range(ship_count):
		var ship: Node3D = objective.assigned_ships[i]
		var target: Node3D = objective.target_entities[i % target_count] if target_count > 0 else null
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.INTERCEPT_THREAT, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		task.target = target
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task

func _generate_strike_mission_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for strike mission
	_generate_destroy_target_tasks(objective)  # Similar to destroy target

func _generate_defensive_screen_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for defensive screen
	_generate_protect_asset_tasks(objective)  # Similar to protection

func _generate_search_destroy_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for search and destroy
	var ship_count: int = objective.assigned_ships.size()
	
	# Split between searchers and attackers
	var search_count: int = ship_count / 3  # 1/3 search
	var attack_count: int = ship_count - search_count
	
	for i in range(search_count):
		var ship: Node3D = objective.assigned_ships[i]
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.SCOUT_AHEAD, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task
	
	for i in range(search_count, ship_count):
		var ship: Node3D = objective.assigned_ships[i]
		
		var task: SquadronTask = SquadronTask.new(
			"task_" + str(task_counter), 
			TaskType.ATTACK_PRIMARY, 
			objective.objective_id
		)
		task_counter += 1
		
		task.assigned_ship = ship
		objective.subtasks.append(task)
		active_tasks[task.task_id] = task

func _generate_area_denial_tasks(objective: SquadronObjective) -> void:
	# Generate tasks for area denial
	_generate_patrol_area_tasks(objective)  # Similar to patrol

func _activate_task(task: SquadronTask) -> void:
	# Activate an individual task
	task.task_status = ObjectiveStatus.ACTIVE
	
	# Track ship assignment
	if not ship_assignments.has(task.assigned_ship):
		ship_assignments[task.assigned_ship] = []
	ship_assignments[task.assigned_ship].append(task.task_id)
	
	# Communicate task to ship
	_communicate_task_to_ship(task)

func _complete_task(task_id: String, success: bool) -> void:
	# Complete a task
	if not active_tasks.has(task_id):
		return
	
	var task: SquadronTask = active_tasks[task_id]
	task.task_status = ObjectiveStatus.COMPLETED if success else ObjectiveStatus.FAILED
	task.completion_time = Time.get_time_dict_from_system()["unix"]
	
	# Remove from active tracking
	active_tasks.erase(task_id)
	
	if ship_assignments.has(task.assigned_ship):
		ship_assignments[task.assigned_ship].erase(task_id)
	
	task_completed.emit(task_id, task.assigned_ship, success)

func _cancel_task(task_id: String) -> void:
	# Cancel a task
	if not active_tasks.has(task_id):
		return
	
	var task: SquadronTask = active_tasks[task_id]
	task.task_status = ObjectiveStatus.CANCELLED
	
	# Remove from active tracking
	active_tasks.erase(task_id)
	
	if ship_assignments.has(task.assigned_ship):
		ship_assignments[task.assigned_ship].erase(task_id)

func _communicate_objective_to_ships(objective: SquadronObjective) -> void:
	# Communicate objective to assigned ships
	if not tactical_communication_system:
		return
	
	var objective_description: String = _format_objective_description(objective)
	
	for ship in objective.assigned_ships:
		tactical_communication_system.send_message(
			null,  # System message
			[ship],
			TacticalCommunicationSystem.MessageType.MISSION_UPDATE,
			objective_description,
			TacticalCommunicationSystem.Priority.HIGH
		)

func _communicate_task_to_ship(task: SquadronTask) -> void:
	# Communicate specific task to ship
	if not tactical_communication_system:
		return
	
	var task_description: String = _format_task_description(task)
	
	tactical_communication_system.send_message(
		null,  # System message
		[task.assigned_ship],
		TacticalCommunicationSystem.MessageType.TACTICAL_ORDER,
		task_description,
		TacticalCommunicationSystem.Priority.HIGH
	)

func _update_active_objectives(delta: float) -> void:
	# Update all active objectives
	for objective_id in active_objectives:
		var objective: SquadronObjective = active_objectives[objective_id]
		_update_objective_progress(objective)

func _update_objective_progress(objective: SquadronObjective) -> void:
	# Update progress of an objective
	var completed_tasks: int = 0
	var total_tasks: int = objective.subtasks.size()
	
	for task in objective.subtasks:
		if task.task_status == ObjectiveStatus.COMPLETED:
			completed_tasks += 1
	
	# Check completion criteria
	if _check_objective_completion_criteria(objective):
		complete_objective(objective.objective_id, true)
	elif _check_objective_failure_criteria(objective):
		complete_objective(objective.objective_id, false, "failure_criteria_met")

func _check_objective_completion_criteria(objective: SquadronObjective) -> bool:
	# Check if objective completion criteria are met
	match objective.objective_type:
		ObjectiveType.DESTROY_TARGET:
			return _all_targets_destroyed(objective.target_entities)
		ObjectiveType.PATROL_AREA:
			return _patrol_time_completed(objective)
		_:
			# Default: all tasks completed
			return _all_tasks_completed(objective)

func _check_objective_failure_criteria(objective: SquadronObjective) -> bool:
	# Check if objective has failed
	if objective.time_limit > 0:
		var elapsed_time: float = Time.get_time_dict_from_system()["unix"] - objective.creation_time
		if elapsed_time > objective.time_limit:
			return true
	
	# Check if too many ships lost
	var active_ships: int = 0
	for ship in objective.assigned_ships:
		if is_instance_valid(ship):
			active_ships += 1
	
	if active_ships < objective.assigned_ships.size() / 2:  # More than half lost
		return true
	
	return false

func _check_objective_timeouts() -> void:
	# Check for objective timeouts
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	for objective_id in active_objectives:
		var objective: SquadronObjective = active_objectives[objective_id]
		if objective.time_limit > 0:
			var elapsed_time: float = current_time - objective.creation_time
			if elapsed_time > objective.time_limit:
				complete_objective(objective_id, false, "timeout")

func _monitor_task_progress() -> void:
	# Monitor progress of individual tasks
	for task_id in active_tasks:
		var task: SquadronTask = active_tasks[task_id]
		_update_task_progress(task)

func _update_task_progress(task: SquadronTask) -> void:
	# Update progress of individual task
	# This would interface with ship AI to check task status
	pass

func _handle_dynamic_reassignments() -> void:
	# Handle dynamic task reassignments based on changing conditions
	for objective_id in active_objectives:
		var objective: SquadronObjective = active_objectives[objective_id]
		_evaluate_reassignment_needs(objective)

func _evaluate_reassignment_needs(objective: SquadronObjective) -> void:
	# Evaluate if tasks need reassignment
	for task in objective.subtasks:
		if not is_instance_valid(task.assigned_ship):
			_reassign_orphaned_task(task)

func _reassign_orphaned_task(task: SquadronTask) -> void:
	# Reassign task from lost/invalid ship
	var parent_objective: SquadronObjective = active_objectives.get(task.parent_objective_id)
	if not parent_objective:
		return
	
	# Find available ship
	for ship in parent_objective.assigned_ships:
		if is_instance_valid(ship) and _ship_can_take_additional_task(ship):
			task.assigned_ship = ship
			_activate_task(task)
			return

func _ship_can_take_additional_task(ship: Node3D) -> bool:
	# Check if ship can take additional task
	var current_tasks: Array = ship_assignments.get(ship, [])
	return current_tasks.size() < 3  # Max 3 tasks per ship

# Helper functions
func _calculate_patrol_positions(center: Vector3, radius: float, ship_count: int) -> Array[Vector3]:
	# Calculate patrol positions around area
	var positions: Array[Vector3] = []
	
	for i in range(ship_count):
		var angle: float = (i * 2.0 * PI) / ship_count
		var position: Vector3 = center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		positions.append(position)
	
	return positions

func _format_objective_description(objective: SquadronObjective) -> String:
	# Format objective description for communication
	var type_name: String = ObjectiveType.keys()[objective.objective_type]
	return "New objective: %s priority %s" % [type_name, ObjectivePriority.keys()[objective.priority]]

func _format_task_description(task: SquadronTask) -> String:
	# Format task description for communication
	var type_name: String = TaskType.keys()[task.task_type]
	return "Task assigned: %s" % [type_name]

func _get_objective_summary(objective: SquadronObjective) -> Dictionary:
	# Get objective summary dictionary
	return {
		"objective_id": objective.objective_id,
		"type": ObjectiveType.keys()[objective.objective_type],
		"priority": ObjectivePriority.keys()[objective.priority],
		"status": ObjectiveStatus.keys()[objective.status],
		"assigned_ships": objective.assigned_ships.size(),
		"targets": objective.target_entities.size(),
		"creation_time": objective.creation_time,
		"time_limit": objective.time_limit
	}

func _get_task_summary(task: SquadronTask) -> Dictionary:
	# Get task summary dictionary
	return {
		"task_id": task.task_id,
		"type": TaskType.keys()[task.task_type],
		"status": ObjectiveStatus.keys()[task.task_status],
		"assigned_ship": task.assigned_ship,
		"target": task.target,
		"creation_time": task.creation_time
	}

func _all_targets_destroyed(targets: Array[Node3D]) -> bool:
	# Check if all targets are destroyed
	for target in targets:
		if is_instance_valid(target):
			return false
	return true

func _patrol_time_completed(objective: SquadronObjective) -> bool:
	# Check if patrol time is completed
	var elapsed_time: float = Time.get_time_dict_from_system()["unix"] - objective.creation_time
	var required_time: float = objective.context_data.get("patrol_duration", 300.0)  # 5 minutes default
	return elapsed_time >= required_time

func _all_tasks_completed(objective: SquadronObjective) -> bool:
	# Check if all tasks are completed
	for task in objective.subtasks:
		if task.task_status != ObjectiveStatus.COMPLETED:
			return false
	return true

func _reorder_task_priorities(objective: SquadronObjective) -> void:
	# Reorder task priorities based on objective priority
	pass

func _update_objective_performance_tracking(objective: SquadronObjective, success: bool) -> void:
	# Update performance tracking
	if success:
		task_performance_tracking["objectives_completed"] += 1
	else:
		task_performance_tracking["objectives_failed"] += 1

## Gets system performance statistics
func get_system_statistics() -> Dictionary:
	return {
		"active_objectives": active_objectives.size(),
		"active_tasks": active_tasks.size(),
		"objectives_completed": task_performance_tracking.get("objectives_completed", 0),
		"objectives_failed": task_performance_tracking.get("objectives_failed", 0),
		"ships_with_assignments": ship_assignments.size()
	}