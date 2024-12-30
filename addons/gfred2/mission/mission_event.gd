@tool
extends Resource
class_name MissionEvent

enum Operator {
	AND,
	OR,
	NOT
}

# Event properties
@export var id := ""  # Unique identifier
@export var name := ""
@export var repeat_count := 0
@export var interval := 0.0
@export var score := 0
@export var team := 0
@export var chained := false
@export var chain_delay := 0.0

# Event conditions
var condition_tree := {}  # Tree structure for boolean operators
var conditions := []  # List of all conditions

# Event directives
@export var directive_text := ""
@export var directive_keypress := ""

# Event chain
var next_event: MissionEvent = null
var prev_event: MissionEvent = null

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

func add_operator(operator: Operator, parent_id := "") -> String:
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

func chain_to(event: MissionEvent) -> void:
	next_event = event
	event.prev_event = self
	chained = true

func unchain() -> void:
	if next_event:
		next_event.prev_event = null
		next_event = null
	chained = false

func validate() -> Array:
	var errors := []
	
	# Check required fields
	if name.is_empty():
		errors.append("Event requires a name")
	
	# Check conditions
	if conditions.is_empty():
		errors.append("Event '%s' requires at least one condition" % name)
	
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
		errors.append("Event '%s' must have exactly one root condition" % name)
	
	# Check chain consistency
	if chained and !next_event:
		errors.append("Event '%s' is marked as chained but has no next event" % name)
	if next_event and !chained:
		errors.append("Event '%s' has next event but is not marked as chained" % name)
	
	return errors
