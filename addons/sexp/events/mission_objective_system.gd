class_name MissionObjectiveSystem
extends RefCounted

## Mission Objective System for SEXP-007: Mission Event Integration
##
## Manages mission objectives using the event trigger system. Provides WCS-compatible
## objective tracking, completion handling, and integration with the SEXP evaluation system.

const EventTrigger = preload("res://addons/sexp/events/event_trigger.gd")
const MissionEventManager = preload("res://addons/sexp/events/mission_event_manager.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Objective states matching WCS objective system
enum ObjectiveState {
	INACTIVE = 0,     # Objective not yet active
	ACTIVE = 1,       # Objective active and trackable
	COMPLETED = 2,    # Objective successfully completed
	FAILED = 3,       # Objective failed
	UNKNOWN = 4       # Invalid/unknown objective
}

## Objective types for different mission goals
enum ObjectiveType {
	PRIMARY = 0,      # Primary mission objective
	SECONDARY = 1,    # Secondary mission objective
	BONUS = 2,        # Bonus/optional objective
	HIDDEN = 3        # Hidden objective (not shown to player)
}

## Objective completion behavior
enum CompletionBehavior {
	NORMAL = 0,       # Complete when condition is met
	MANUAL = 1,       # Requires manual completion call
	PROGRESSIVE = 2,  # Progressive completion with multiple stages
	CONDITIONAL = 3   # Completion depends on other objectives
}

## Core objective management
var event_manager: MissionEventManager
var objectives: Dictionary = {}  # String -> ObjectiveData
var objective_states: Dictionary = {}  # String -> ObjectiveState
var objective_types: Dictionary = {}   # String -> ObjectiveType

## Objective tracking
var active_objectives: Array[String] = []
var completed_objectives: Array[String] = []
var failed_objectives: Array[String] = []

## Statistics and metrics
var objectives_completed_count: int = 0
var objectives_failed_count: int = 0
var total_objectives_registered: int = 0

## Internal objective data structure
class ObjectiveData:
	var objective_id: String
	var display_name: String
	var description: String
	var completion_text: String
	var failure_text: String
	var objective_type: ObjectiveType
	var completion_behavior: CompletionBehavior
	var condition_expression: String
	var completion_actions: Array[String]
	var failure_actions: Array[String]
	var prerequisite_objectives: Array[String]
	var blocks_objectives: Array[String]
	var priority: int
	var hidden: bool
	var optional: bool
	var progress_max: int  # For progressive objectives
	var progress_current: int
	var created_time: float
	var activated_time: float
	var completed_time: float

	func _init():
		created_time = Time.get_time_dict_from_system()["unix"]
		progress_max = 1
		progress_current = 0
		priority = 100

## Initialization

func _init(mission_event_manager: MissionEventManager = null):
	event_manager = mission_event_manager

func setup(mission_event_manager: MissionEventManager) -> void:
	## Set up the objective system with the event manager
	event_manager = mission_event_manager
	
	# Connect to event manager signals
	if event_manager:
		event_manager.objective_completed.connect(_on_objective_completed)
		event_manager.objective_failed.connect(_on_objective_failed)

## Objective registration and management

func register_objective(
	objective_id: String,
	display_name: String,
	description: String,
	condition_expr: String,
	obj_type: ObjectiveType = ObjectiveType.PRIMARY,
	completion_behavior: CompletionBehavior = CompletionBehavior.NORMAL
) -> bool:
	## Register a new mission objective
	
	if objective_id.is_empty():
		push_error("Cannot register objective with empty ID")
		return false
	
	if objectives.has(objective_id):
		push_warning("Objective already registered, replacing: %s" % objective_id)
		unregister_objective(objective_id)
	
	# Create objective data
	var objective_data = ObjectiveData.new()
	objective_data.objective_id = objective_id
	objective_data.display_name = display_name
	objective_data.description = description
	objective_data.condition_expression = condition_expr
	objective_data.objective_type = obj_type
	objective_data.completion_behavior = completion_behavior
	objective_data.hidden = (obj_type == ObjectiveType.HIDDEN)
	objective_data.optional = (obj_type == ObjectiveType.BONUS)
	
	# Store objective data
	objectives[objective_id] = objective_data
	objective_states[objective_id] = ObjectiveState.INACTIVE
	objective_types[objective_id] = obj_type
	total_objectives_registered += 1
	
	# Register with event manager if available
	if event_manager and not condition_expr.is_empty():
		var completion_action = "(complete-objective \"%s\")" % objective_id
		if not event_manager.register_objective(objective_id, condition_expr, [completion_action]):
			push_error("Failed to register objective trigger: %s" % objective_id)
			return false
	
	print("[ObjectiveSystem] Registered objective: %s (%s)" % [objective_id, ObjectiveType.keys()[obj_type]])
	return true

func unregister_objective(objective_id: String) -> bool:
	## Unregister and remove an objective
	if not objectives.has(objective_id):
		push_warning("Cannot unregister unknown objective: %s" % objective_id)
		return false
	
	# Remove from tracking lists
	_remove_from_lists(objective_id)
	
	# Unregister from event manager
	if event_manager:
		event_manager.unregister_trigger(objective_id)
	
	# Clean up data
	objectives.erase(objective_id)
	objective_states.erase(objective_id)
	objective_types.erase(objective_id)
	
	print("[ObjectiveSystem] Unregistered objective: %s" % objective_id)
	return true

func activate_objective(objective_id: String) -> bool:
	## Activate an objective to begin tracking
	if not objectives.has(objective_id):
		push_error("Cannot activate unknown objective: %s" % objective_id)
		return false
	
	var current_state = objective_states.get(objective_id, ObjectiveState.INACTIVE)
	if current_state != ObjectiveState.INACTIVE:
		push_warning("Objective not in inactive state: %s (state: %s)" % [objective_id, ObjectiveState.keys()[current_state]])
		return false
	
	var objective_data: ObjectiveData = objectives[objective_id]
	
	# Check prerequisites
	if not _check_prerequisites(objective_data):
		push_error("Prerequisites not met for objective: %s" % objective_id)
		return false
	
	# Activate the objective
	objective_states[objective_id] = ObjectiveState.ACTIVE
	active_objectives.append(objective_id)
	objective_data.activated_time = Time.get_time_dict_from_system()["unix"]
	
	# Activate trigger in event manager
	if event_manager:
		event_manager.activate_trigger(objective_id)
	
	print("[ObjectiveSystem] Activated objective: %s" % objective_id)
	return true

func complete_objective(objective_id: String, completion_data: Dictionary = {}) -> bool:
	## Manually complete an objective
	if not objectives.has(objective_id):
		push_error("Cannot complete unknown objective: %s" % objective_id)
		return false
	
	var current_state = objective_states.get(objective_id, ObjectiveState.INACTIVE)
	if current_state != ObjectiveState.ACTIVE:
		push_warning("Objective not active for completion: %s" % objective_id)
		return false
	
	var objective_data: ObjectiveData = objectives[objective_id]
	
	# Mark as completed
	objective_states[objective_id] = ObjectiveState.COMPLETED
	_remove_from_lists(objective_id)
	completed_objectives.append(objective_id)
	objectives_completed_count += 1
	objective_data.completed_time = Time.get_time_dict_from_system()["unix"]
	
	# Execute completion actions
	_execute_objective_actions(objective_data.completion_actions)
	
	# Handle objective blocking
	_handle_objective_blocks(objective_data)
	
	# Complete in event manager
	if event_manager:
		event_manager.complete_objective(objective_id, completion_data)
	
	print("[ObjectiveSystem] Completed objective: %s" % objective_id)
	return true

func fail_objective(objective_id: String, failure_data: Dictionary = {}) -> bool:
	## Mark an objective as failed
	if not objectives.has(objective_id):
		push_error("Cannot fail unknown objective: %s" % objective_id)
		return false
	
	var current_state = objective_states.get(objective_id, ObjectiveState.INACTIVE)
	if current_state != ObjectiveState.ACTIVE:
		push_warning("Objective not active for failure: %s" % objective_id)
		return false
	
	var objective_data: ObjectiveData = objectives[objective_id]
	
	# Mark as failed
	objective_states[objective_id] = ObjectiveState.FAILED
	_remove_from_lists(objective_id)
	failed_objectives.append(objective_id)
	objectives_failed_count += 1
	
	# Execute failure actions
	_execute_objective_actions(objective_data.failure_actions)
	
	# Fail in event manager
	if event_manager:
		event_manager.fail_objective(objective_id, failure_data)
	
	print("[ObjectiveSystem] Failed objective: %s" % objective_id)
	return true

## Objective state queries

func get_objective_state(objective_id: String) -> ObjectiveState:
	## Get the current state of an objective
	return objective_states.get(objective_id, ObjectiveState.UNKNOWN)

func is_objective_active(objective_id: String) -> bool:
	## Check if an objective is currently active
	return get_objective_state(objective_id) == ObjectiveState.ACTIVE

func is_objective_completed(objective_id: String) -> bool:
	## Check if an objective is completed
	return get_objective_state(objective_id) == ObjectiveState.COMPLETED

func is_objective_failed(objective_id: String) -> bool:
	## Check if an objective is failed
	return get_objective_state(objective_id) == ObjectiveState.FAILED

func get_active_objectives() -> Array[String]:
	## Get list of currently active objectives
	return active_objectives.duplicate()

func get_completed_objectives() -> Array[String]:
	## Get list of completed objectives
	return completed_objectives.duplicate()

func get_failed_objectives() -> Array[String]:
	## Get list of failed objectives
	return failed_objectives.duplicate()

## Progressive objectives

func set_objective_progress(objective_id: String, progress: int) -> bool:
	## Set progress for a progressive objective
	if not objectives.has(objective_id):
		push_error("Cannot set progress for unknown objective: %s" % objective_id)
		return false
	
	var objective_data: ObjectiveData = objectives[objective_id]
	if objective_data.completion_behavior != CompletionBehavior.PROGRESSIVE:
		push_error("Objective is not progressive: %s" % objective_id)
		return false
	
	objective_data.progress_current = clamp(progress, 0, objective_data.progress_max)
	
	# Check for auto-completion
	if objective_data.progress_current >= objective_data.progress_max:
		complete_objective(objective_id)
	
	return true

func advance_objective_progress(objective_id: String, amount: int = 1) -> bool:
	## Advance progress for a progressive objective
	if not objectives.has(objective_id):
		return false
	
	var objective_data: ObjectiveData = objectives[objective_id]
	return set_objective_progress(objective_id, objective_data.progress_current + amount)

func get_objective_progress(objective_id: String) -> Dictionary:
	## Get progress information for an objective
	if not objectives.has(objective_id):
		return {"current": 0, "max": 1, "percent": 0.0}
	
	var objective_data: ObjectiveData = objectives[objective_id]
	return {
		"current": objective_data.progress_current,
		"max": objective_data.progress_max,
		"percent": (float(objective_data.progress_current) / float(objective_data.progress_max)) * 100.0
	}

## Objective information and display

func get_objective_info(objective_id: String) -> Dictionary:
	## Get comprehensive information about an objective
	if not objectives.has(objective_id):
		return {}
	
	var objective_data: ObjectiveData = objectives[objective_id]
	var state = get_objective_state(objective_id)
	
	return {
		"objective_id": objective_id,
		"display_name": objective_data.display_name,
		"description": objective_data.description,
		"completion_text": objective_data.completion_text,
		"failure_text": objective_data.failure_text,
		"state": ObjectiveState.keys()[state],
		"type": ObjectiveType.keys()[objective_data.objective_type],
		"completion_behavior": CompletionBehavior.keys()[objective_data.completion_behavior],
		"priority": objective_data.priority,
		"hidden": objective_data.hidden,
		"optional": objective_data.optional,
		"progress": get_objective_progress(objective_id),
		"prerequisite_objectives": objective_data.prerequisite_objectives,
		"blocks_objectives": objective_data.blocks_objectives,
		"created_time": objective_data.created_time,
		"activated_time": objective_data.activated_time,
		"completed_time": objective_data.completed_time
	}

func get_display_objectives() -> Array[Dictionary]:
	## Get list of objectives suitable for UI display
	var display_list: Array[Dictionary] = []
	
	for objective_id in objectives:
		var objective_data: ObjectiveData = objectives[objective_id]
		if not objective_data.hidden:
			display_list.append(get_objective_info(objective_id))
	
	# Sort by priority and state
	display_list.sort_custom(func(a, b): 
		# Active objectives first
		if a.state == "ACTIVE" and b.state != "ACTIVE":
			return true
		if b.state == "ACTIVE" and a.state != "ACTIVE":
			return false
		
		# Then by priority
		return a.priority < b.priority
	)
	
	return display_list

## Statistics and monitoring

func get_objective_statistics() -> Dictionary:
	## Get comprehensive objective statistics
	return {
		"total_registered": total_objectives_registered,
		"total_active": active_objectives.size(),
		"total_completed": objectives_completed_count,
		"total_failed": objectives_failed_count,
		"completion_rate": _calculate_completion_rate(),
		"objectives_by_type": _get_objectives_by_type(),
		"objectives_by_state": _get_objectives_by_state()
	}

func _calculate_completion_rate() -> float:
	var total_finished = objectives_completed_count + objectives_failed_count
	if total_finished == 0:
		return 0.0
	return (float(objectives_completed_count) / float(total_finished)) * 100.0

func _get_objectives_by_type() -> Dictionary:
	var counts = {}
	for type in ObjectiveType.values():
		counts[ObjectiveType.keys()[type]] = 0
	
	for obj_type in objective_types.values():
		counts[ObjectiveType.keys()[obj_type]] += 1
	
	return counts

func _get_objectives_by_state() -> Dictionary:
	var counts = {}
	for state in ObjectiveState.values():
		counts[ObjectiveState.keys()[state]] = 0
	
	for obj_state in objective_states.values():
		counts[ObjectiveState.keys()[obj_state]] += 1
	
	return counts

## Internal helpers

func _check_prerequisites(objective_data: ObjectiveData) -> bool:
	## Check if all prerequisite objectives are completed
	for prereq_id in objective_data.prerequisite_objectives:
		if not is_objective_completed(prereq_id):
			return false
	return true

func _execute_objective_actions(actions: Array[String]) -> void:
	## Execute a list of SEXP action expressions
	if not event_manager or not event_manager.evaluator:
		return
	
	for action in actions:
		if not action.is_empty():
			var result = event_manager.evaluator.evaluate(action)
			if result.is_error():
				push_error("Failed to execute objective action: %s" % result.error_message)

func _handle_objective_blocks(objective_data: ObjectiveData) -> void:
	## Handle objectives that are blocked by this completion
	for blocked_id in objective_data.blocks_objectives:
		if is_objective_active(blocked_id):
			fail_objective(blocked_id, {"reason": "blocked_by_completion", "blocker": objective_data.objective_id})

func _remove_from_lists(objective_id: String) -> void:
	## Remove objective from all tracking lists
	var index = active_objectives.find(objective_id)
	if index >= 0:
		active_objectives.remove_at(index)
	
	index = completed_objectives.find(objective_id)
	if index >= 0:
		completed_objectives.remove_at(index)
	
	index = failed_objectives.find(objective_id)
	if index >= 0:
		failed_objectives.remove_at(index)

## Signal handlers

func _on_objective_completed(objective_id: String, completion_data: Dictionary) -> void:
	## Handle objective completion from event manager
	if objectives.has(objective_id):
		complete_objective(objective_id, completion_data)

func _on_objective_failed(objective_id: String, failure_data: Dictionary) -> void:
	## Handle objective failure from event manager
	if objectives.has(objective_id):
		fail_objective(objective_id, failure_data)