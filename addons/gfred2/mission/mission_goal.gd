@tool
extends Resource
class_name MissionGoal

enum Type {
	PRIMARY,
	SECONDARY,
	HIDDEN
}

enum Status {
	INCOMPLETE,
	COMPLETE,
	FAILED,
	INVALID
}

# Goal properties
@export var id := ""  # Unique identifier
@export var name := ""
@export var type: Type
@export var text := ""
@export var score := 0
@export var team := 0

# Goal conditions
var condition_tree := {}  # Tree structure for boolean operators
var conditions := []  # List of all conditions

# Goal status
var status := Status.INCOMPLETE
var invalid_reason := ""

# Goal dependencies
var required_goals: Array[MissionGoal] = []
var dependent_goals: Array[MissionGoal] = []

# Goal messages
@export var complete_message := ""
@export var failed_message := ""
@export var invalid_message := ""

func _init():
	# Generate unique ID if not set
	if id.is_empty():
		id = str(Time.get_unix_time_from_system()) + "_" + str(randi())

func add_condition(condition: Dictionary, parent_id := "") -> String:
	# Generate unique ID for condition
	var id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
	# Add condition to list
	conditions.append({
		"id": id,
		"type": condition.type,
		"params": condition.params
	})
	
	# Add to condition tree
	if parent_id.is_empty():
		condition_tree[id] = []
	else:
		if !condition_tree.has(parent_id):
			condition_tree[parent_id] = []
		condition_tree[parent_id].append(id)
	
	return id

func add_operator(operator: MissionEvent.Operator, parent_id := "") -> String:
	# Generate unique ID for operator
	var id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
	# Add operator to conditions list
	conditions.append({
		"id": id,
		"type": "operator",
		"operator": operator
	})
	
	# Add to condition tree
	if parent_id.is_empty():
		condition_tree[id] = []
	else:
		if !condition_tree.has(parent_id):
			condition_tree[parent_id] = []
		condition_tree[parent_id].append(id)
	
	return id

func remove_condition(id: String) -> void:
	# Remove from conditions list
	for i in range(conditions.size()):
		if conditions[i].id == id:
			conditions.remove_at(i)
			break
	
	# Remove from condition tree
	condition_tree.erase(id)
	for parent_id in condition_tree:
		condition_tree[parent_id].erase(id)

func add_required_goal(goal: MissionGoal) -> void:
	if !required_goals.has(goal):
		required_goals.append(goal)
		goal.dependent_goals.append(self)

func remove_required_goal(goal: MissionGoal) -> void:
	required_goals.erase(goal)
	goal.dependent_goals.erase(self)

func set_status(new_status: Status, reason := "") -> void:
	status = new_status
	
	match status:
		Status.COMPLETE:
			# Notify dependent goals
			for goal in dependent_goals:
				goal.on_required_goal_complete(self)
		Status.FAILED:
			invalid_reason = reason
			# Invalidate dependent goals
			for goal in dependent_goals:
				goal.on_required_goal_failed(self)
		Status.INVALID:
			invalid_reason = reason
			# Invalidate dependent goals
			for goal in dependent_goals:
				goal.invalidate("Required goal '%s' is invalid: %s" % [name, reason])

func on_required_goal_complete(goal: MissionGoal) -> void:
	# Check if all required goals are complete
	for req_goal in required_goals:
		if req_goal.status != Status.COMPLETE:
			return
	
	# All required goals complete, this goal can now be completed
	if status == Status.INCOMPLETE:
		set_status(Status.COMPLETE)

func on_required_goal_failed(goal: MissionGoal) -> void:
	# If any required goal fails, this goal fails
	if status == Status.INCOMPLETE:
		set_status(Status.FAILED, "Required goal '%s' failed" % goal.name)

func invalidate(reason: String) -> void:
	set_status(Status.INVALID, reason)

func _get_goal_path_string(path: Array) -> String:
	var names := []
	for goal in path:
		names.append(goal.name)
	return " -> ".join(names)

func _check_dependency_cycle(current: MissionGoal, visited: Dictionary, path: Array, errors: Array) -> bool:
	if current in path:
		errors.append("Goal dependency cycle detected: %s" % _get_goal_path_string(path))
		return true
	if current in visited:
		return false
		
	visited[current] = true
	path.append(current)
	
	for goal in current.required_goals:
		if _check_dependency_cycle(goal, visited, path, errors):
			return true
	
	path.pop_back()
	return false

func validate() -> Array:
	var errors := []
	
	# Check required fields
	if name.is_empty():
		errors.append("Goal requires a name")
	if text.is_empty():
		errors.append("Goal '%s' requires text" % name)
	
	# Check conditions
	if conditions.is_empty():
		errors.append("Goal '%s' requires at least one condition" % name)
	
	# Check condition tree structure
	var root_conditions := []
	for id in condition_tree:
		var found = false
		for parent_id in condition_tree:
			if condition_tree[parent_id].has(id):
				found = true
				break
		if !found:
			root_conditions.append(id)
	
	if root_conditions.size() != 1:
		errors.append("Goal '%s' must have exactly one root condition" % name)
	
	# Check goal dependencies
	for goal in required_goals:
		if !goal.dependent_goals.has(self):
			errors.append("Goal '%s' has inconsistent dependency with '%s'" % [name, goal.name])
	
	for goal in dependent_goals:
		if !goal.required_goals.has(self):
			errors.append("Goal '%s' has inconsistent dependency with '%s'" % [name, goal.name])
	
	# Check for dependency cycles
	_check_dependency_cycle(self, {}, [], errors)
	
	return errors
