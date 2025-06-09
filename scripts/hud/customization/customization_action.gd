class_name CustomizationAction
extends RefCounted

## EPIC-012 HUD-016: Customization Action Data Structure
## Stores information about a single customization action for undo/redo functionality

# Action identification
var action_type: String = ""  # position, size, rotation, scale, visibility, color, etc.
var element_id: String = ""
var action_description: String = ""

# Action data
var old_value: Variant
var new_value: Variant
var affected_properties: Array[String] = []

# Metadata
var timestamp: float = 0.0
var user_initiated: bool = true
var reversible: bool = true

# Grouping for compound actions
var group_id: String = ""
var is_compound: bool = false
var compound_actions: Array[CustomizationAction] = []

func _init():
	timestamp = Time.get_unix_time_from_system()

## Create a position change action
static func create_position_action(element_id: String, old_pos: Vector2, new_pos: Vector2) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = "position"
	action.element_id = element_id
	action.old_value = old_pos
	action.new_value = new_pos
	action.action_description = "Move element '%s'" % element_id
	action.affected_properties = ["position"]
	return action

## Create a size change action
static func create_size_action(element_id: String, old_size: Vector2, new_size: Vector2) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = "size"
	action.element_id = element_id
	action.old_value = old_size
	action.new_value = new_size
	action.action_description = "Resize element '%s'" % element_id
	action.affected_properties = ["size"]
	return action

## Create a rotation change action
static func create_rotation_action(element_id: String, old_rotation: float, new_rotation: float) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = "rotation"
	action.element_id = element_id
	action.old_value = old_rotation
	action.new_value = new_rotation
	action.action_description = "Rotate element '%s'" % element_id
	action.affected_properties = ["rotation"]
	return action

## Create a scale change action
static func create_scale_action(element_id: String, old_scale: float, new_scale: float) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = "scale"
	action.element_id = element_id
	action.old_value = old_scale
	action.new_value = new_scale
	action.action_description = "Scale element '%s'" % element_id
	action.affected_properties = ["scale"]
	return action

## Create a visibility change action
static func create_visibility_action(element_id: String, old_visible: bool, new_visible: bool) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = "visibility"
	action.element_id = element_id
	action.old_value = old_visible
	action.new_value = new_visible
	action.action_description = "%s element '%s'" % ["Show" if new_visible else "Hide", element_id]
	action.affected_properties = ["visible"]
	return action

## Create a color change action
static func create_color_action(element_id: String, color_name: String, old_color: Color, new_color: Color) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = "color"
	action.element_id = element_id
	action.old_value = {color_name: old_color}
	action.new_value = {color_name: new_color}
	action.action_description = "Change %s color of element '%s'" % [color_name, element_id]
	action.affected_properties = ["custom_colors"]
	return action

## Create a property change action
static func create_property_action(element_id: String, property_name: String, old_value: Variant, new_value: Variant) -> CustomizationAction:
	var action = CustomizationAction.new()
	action.action_type = "property"
	action.element_id = element_id
	action.old_value = {property_name: old_value}
	action.new_value = {property_name: new_value}
	action.action_description = "Change %s of element '%s'" % [property_name, element_id]
	action.affected_properties = [property_name]
	return action

## Create a compound action from multiple actions
static func create_compound_action(actions: Array[CustomizationAction], description: String = "") -> CustomizationAction:
	var compound = CustomizationAction.new()
	compound.action_type = "compound"
	compound.is_compound = true
	compound.compound_actions = actions
	compound.action_description = description if not description.is_empty() else "Multiple changes"
	compound.group_id = "compound_" + str(compound.timestamp)
	
	# Set group ID for all child actions
	for action in actions:
		action.group_id = compound.group_id
	
	# Determine if compound action is reversible
	compound.reversible = true
	for action in actions:
		if not action.reversible:
			compound.reversible = false
			break
	
	return compound

## Get the inverse action for undo
func get_inverse_action() -> CustomizationAction:
	if not reversible:
		return null
	
	if is_compound:
		# Create inverse compound action
		var inverse_actions: Array[CustomizationAction] = []
		for i in range(compound_actions.size() - 1, -1, -1):  # Reverse order
			var inverse = compound_actions[i].get_inverse_action()
			if inverse:
				inverse_actions.append(inverse)
		
		return CustomizationAction.create_compound_action(inverse_actions, "Undo: " + action_description)
	
	# Create inverse single action
	var inverse = CustomizationAction.new()
	inverse.action_type = action_type
	inverse.element_id = element_id
	inverse.old_value = new_value  # Swap old and new
	inverse.new_value = old_value
	inverse.action_description = "Undo: " + action_description
	inverse.affected_properties = affected_properties.duplicate()
	inverse.timestamp = Time.get_unix_time_from_system()
	inverse.user_initiated = false  # This is a system-generated action
	inverse.reversible = true
	inverse.group_id = group_id
	
	return inverse

## Check if this action affects the same element and property as another
func conflicts_with(other: CustomizationAction) -> bool:
	if element_id != other.element_id:
		return false
	
	if action_type != other.action_type:
		return false
	
	# Check if any affected properties overlap
	for prop in affected_properties:
		if other.affected_properties.has(prop):
			return true
	
	return false

## Merge this action with another compatible action
func merge_with(other: CustomizationAction) -> bool:
	if not can_merge_with(other):
		return false
	
	# Update the new value and description
	new_value = other.new_value
	action_description = action_description + " + " + other.action_description
	
	# Update affected properties
	for prop in other.affected_properties:
		if not affected_properties.has(prop):
			affected_properties.append(prop)
	
	return true

## Check if this action can be merged with another
func can_merge_with(other: CustomizationAction) -> bool:
	if not conflicts_with(other):
		return false
	
	# Check if actions are close in time (within 1 second)
	if abs(other.timestamp - timestamp) > 1.0:
		return false
	
	# Don't merge compound actions
	if is_compound or other.is_compound:
		return false
	
	return true

## Get action data for serialization
func serialize() -> Dictionary:
	var data = {
		"action_type": action_type,
		"element_id": element_id,
		"action_description": action_description,
		"old_value": var_to_str(old_value),
		"new_value": var_to_str(new_value),
		"affected_properties": affected_properties,
		"timestamp": timestamp,
		"user_initiated": user_initiated,
		"reversible": reversible,
		"group_id": group_id,
		"is_compound": is_compound
	}
	
	if is_compound:
		data["compound_actions"] = []
		for action in compound_actions:
			data.compound_actions.append(action.serialize())
	
	return data

## Create action from serialized data
static func deserialize(data: Dictionary) -> CustomizationAction:
	var action = CustomizationAction.new()
	
	action.action_type = data.get("action_type", "")
	action.element_id = data.get("element_id", "")
	action.action_description = data.get("action_description", "")
	action.old_value = str_to_var(data.get("old_value", ""))
	action.new_value = str_to_var(data.get("new_value", ""))
	action.affected_properties = data.get("affected_properties", [])
	action.timestamp = data.get("timestamp", 0.0)
	action.user_initiated = data.get("user_initiated", true)
	action.reversible = data.get("reversible", true)
	action.group_id = data.get("group_id", "")
	action.is_compound = data.get("is_compound", false)
	
	if action.is_compound and data.has("compound_actions"):
		for compound_data in data.compound_actions:
			var compound_action = deserialize(compound_data)
			if compound_action:
				action.compound_actions.append(compound_action)
	
	return action

## Get formatted timestamp
func get_formatted_timestamp() -> String:
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d:%02d:%02d" % [datetime.hour, datetime.minute, datetime.second]

## Get action summary for display
func get_action_summary() -> Dictionary:
	return {
		"type": action_type,
		"element": element_id,
		"description": action_description,
		"timestamp": get_formatted_timestamp(),
		"user_initiated": user_initiated,
		"reversible": reversible,
		"is_compound": is_compound,
		"compound_count": compound_actions.size() if is_compound else 0
	}