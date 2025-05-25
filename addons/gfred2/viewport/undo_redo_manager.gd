@tool
class_name UndoRedoManager
extends RefCounted

## Undo/Redo manager for viewport transformations.
## Manages transformation history and provides undo/redo functionality
## with proper state management and signal integration.

signal undo_performed(action_name: String)
signal redo_performed(action_name: String)
signal history_changed(can_undo: bool, can_redo: bool)

class TransformAction:
	var action_name: String
	var objects: Array[MissionObjectNode3D]
	var old_transforms: Array[Transform3D]
	var new_transforms: Array[Transform3D]
	var timestamp: float
	
	func _init(name: String = "Transform") -> void:
		action_name = name
		objects = []
		old_transforms = []
		new_transforms = []
		timestamp = Time.get_time_dict_from_system()["unix"]

# Undo/Redo state
var undo_stack: Array[TransformAction] = []
var redo_stack: Array[TransformAction] = []
var max_history_size: int = 100
var current_action: TransformAction = null

# Batch operation state
var is_batch_active: bool = false
var batch_action: TransformAction = null

## Begin a transformation action
func begin_action(action_name: String = "Transform") -> void:
	current_action = TransformAction.new(action_name)
	redo_stack.clear()  # Clear redo stack when new action begins

## Add object's current state to the current action
func capture_object_state(object: MissionObjectNode3D) -> void:
	if not current_action:
		push_warning("No active action to capture state for")
		return
	
	# Check if object is already in the action
	var index: int = current_action.objects.find(object)
	if index >= 0:
		# Update existing entry
		current_action.new_transforms[index] = object.transform
	else:
		# Add new entry
		current_action.objects.append(object)
		current_action.old_transforms.append(object.transform)
		current_action.new_transforms.append(object.transform)

## Update object's final state in the current action
func update_object_state(object: MissionObjectNode3D) -> void:
	if not current_action:
		return
	
	var index: int = current_action.objects.find(object)
	if index >= 0:
		current_action.new_transforms[index] = object.transform

## Commit the current action to the undo stack
func commit_action() -> void:
	if not current_action:
		return
	
	# Only add to stack if there are actual changes
	var has_changes: bool = false
	for i in range(current_action.objects.size()):
		if not current_action.old_transforms[i].is_equal_approx(current_action.new_transforms[i]):
			has_changes = true
			break
	
	if has_changes:
		undo_stack.append(current_action)
		
		# Limit history size
		while undo_stack.size() > max_history_size:
			undo_stack.pop_front()
		
		emit_history_changed()
	
	current_action = null

## Cancel the current action without committing
func cancel_action() -> void:
	if not current_action:
		return
	
	# Restore objects to their original transforms
	for i in range(current_action.objects.size()):
		var object: MissionObjectNode3D = current_action.objects[i]
		if is_instance_valid(object):
			object.transform = current_action.old_transforms[i]
	
	current_action = null

## Begin a batch operation that groups multiple actions
func begin_batch(batch_name: String = "Batch Transform") -> void:
	if is_batch_active:
		push_warning("Batch already active")
		return
	
	is_batch_active = true
	batch_action = TransformAction.new(batch_name)
	redo_stack.clear()

## End the current batch operation
func end_batch() -> void:
	if not is_batch_active:
		return
	
	is_batch_active = false
	
	# Commit batch if it has changes
	if batch_action and not batch_action.objects.is_empty():
		var has_changes: bool = false
		for i in range(batch_action.objects.size()):
			if not batch_action.old_transforms[i].is_equal_approx(batch_action.new_transforms[i]):
				has_changes = true
				break
		
		if has_changes:
			undo_stack.append(batch_action)
			
			# Limit history size
			while undo_stack.size() > max_history_size:
				undo_stack.pop_front()
			
			emit_history_changed()
	
	batch_action = null

## Add object to current batch
func add_to_batch(object: MissionObjectNode3D, old_transform: Transform3D) -> void:
	if not is_batch_active or not batch_action:
		return
	
	batch_action.objects.append(object)
	batch_action.old_transforms.append(old_transform)
	batch_action.new_transforms.append(object.transform)

## Update object in current batch
func update_batch_object(object: MissionObjectNode3D) -> void:
	if not is_batch_active or not batch_action:
		return
	
	var index: int = batch_action.objects.find(object)
	if index >= 0:
		batch_action.new_transforms[index] = object.transform

## Perform undo operation
func undo() -> bool:
	if undo_stack.is_empty():
		return false
	
	var action: TransformAction = undo_stack.pop_back()
	
	# Apply old transforms
	for i in range(action.objects.size()):
		var object: MissionObjectNode3D = action.objects[i]
		if is_instance_valid(object):
			object.transform = action.old_transforms[i]
			# Update mission data
			object.sync_to_mission_data()
	
	# Move to redo stack
	redo_stack.append(action)
	
	emit_history_changed()
	undo_performed.emit(action.action_name)
	
	return true

## Perform redo operation
func redo() -> bool:
	if redo_stack.is_empty():
		return false
	
	var action: TransformAction = redo_stack.pop_back()
	
	# Apply new transforms
	for i in range(action.objects.size()):
		var object: MissionObjectNode3D = action.objects[i]
		if is_instance_valid(object):
			object.transform = action.new_transforms[i]
			# Update mission data
			object.sync_to_mission_data()
	
	# Move back to undo stack
	undo_stack.append(action)
	
	emit_history_changed()
	redo_performed.emit(action.action_name)
	
	return true

## Check if undo is available
func can_undo() -> bool:
	return not undo_stack.is_empty()

## Check if redo is available
func can_redo() -> bool:
	return not redo_stack.is_empty()

## Get the name of the next undo action
func get_undo_action_name() -> String:
	if undo_stack.is_empty():
		return ""
	return undo_stack.back().action_name

## Get the name of the next redo action
func get_redo_action_name() -> String:
	if redo_stack.is_empty():
		return ""
	return redo_stack.back().action_name

## Clear all history
func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	current_action = null
	is_batch_active = false
	batch_action = null
	emit_history_changed()

## Get total number of actions in history
func get_history_size() -> int:
	return undo_stack.size() + redo_stack.size()

## Set maximum history size
func set_max_history_size(size: int) -> void:
	max_history_size = max(1, size)
	
	# Trim existing history if needed
	while undo_stack.size() > max_history_size:
		undo_stack.pop_front()

## Emit history changed signal
func emit_history_changed() -> void:
	history_changed.emit(can_undo(), can_redo())

## Get summary of current undo stack
func get_undo_summary() -> Array[String]:
	var summary: Array[String] = []
	for action in undo_stack:
		summary.append("%s (%d objects)" % [action.action_name, action.objects.size()])
	return summary

## Get summary of current redo stack
func get_redo_summary() -> Array[String]:
	var summary: Array[String] = []
	for action in redo_stack:
		summary.append("%s (%d objects)" % [action.action_name, action.objects.size()])
	return summary