class_name VisibilityRule
extends Resource

## EPIC-012 HUD-016: Visibility Rule Data Structure
## Defines conditional visibility rules for HUD elements based on game state

# Rule identification
var rule_name: String = ""
var rule_description: String = ""
var rule_priority: int = 0  # Higher priority rules override lower priority ones

# Rule conditions
var condition_type: String = ""  # game_state, player_state, mission_state, time_based, etc.
var condition_operator: String = ""  # equals, not_equals, greater_than, less_than, contains, etc.
var condition_value: Variant
var condition_property: String = ""

# Target elements
var target_elements: Array[String] = []  # Element IDs affected by this rule
var element_group: String = ""  # Predefined group of elements

# Rule actions
var action_type: String = "visibility"  # visibility, opacity, scale, color_scheme
var action_value: Variant = true
var animation_duration: float = 0.3

# Rule state
var is_active: bool = true
var is_conditional: bool = true
var last_evaluation: bool = false
var evaluation_count: int = 0

# Metadata
var creation_date: String = ""
var last_modified: String = ""

func _init():
	creation_date = Time.get_datetime_string_from_system()
	last_modified = creation_date

## Create a game state visibility rule
static func create_game_state_rule(rule_name: String, game_state: String, target_elements: Array[String], visible: bool) -> VisibilityRule:
	var rule = VisibilityRule.new()
	rule.rule_name = rule_name
	rule.rule_description = "Show/hide elements based on game state: " + game_state
	rule.condition_type = "game_state"
	rule.condition_operator = "equals"
	rule.condition_value = game_state
	rule.condition_property = "current_state"
	rule.target_elements = target_elements
	rule.action_type = "visibility"
	rule.action_value = visible
	return rule

## Create a mission phase visibility rule
static func create_mission_phase_rule(rule_name: String, mission_phase: String, target_elements: Array[String], visible: bool) -> VisibilityRule:
	var rule = VisibilityRule.new()
	rule.rule_name = rule_name
	rule.rule_description = "Show/hide elements based on mission phase: " + mission_phase
	rule.condition_type = "mission_state"
	rule.condition_operator = "equals"
	rule.condition_value = mission_phase
	rule.condition_property = "current_phase"
	rule.target_elements = target_elements
	rule.action_type = "visibility"
	rule.action_value = visible
	return rule

## Create a combat state visibility rule
static func create_combat_state_rule(rule_name: String, in_combat: bool, target_elements: Array[String], visible: bool) -> VisibilityRule:
	var rule = VisibilityRule.new()
	rule.rule_name = rule_name
	rule.rule_description = "Show/hide elements based on combat state"
	rule.condition_type = "player_state"
	rule.condition_operator = "equals"
	rule.condition_value = in_combat
	rule.condition_property = "in_combat"
	rule.target_elements = target_elements
	rule.action_type = "visibility"
	rule.action_value = visible
	return rule

## Create a ship system visibility rule
static func create_ship_system_rule(rule_name: String, system_name: String, system_active: bool, target_elements: Array[String], visible: bool) -> VisibilityRule:
	var rule = VisibilityRule.new()
	rule.rule_name = rule_name
	rule.rule_description = "Show/hide elements based on ship system: " + system_name
	rule.condition_type = "ship_system"
	rule.condition_operator = "equals"
	rule.condition_value = system_active
	rule.condition_property = system_name + "_active"
	rule.target_elements = target_elements
	rule.action_type = "visibility"
	rule.action_value = visible
	return rule

## Create a time-based visibility rule
static func create_time_based_rule(rule_name: String, start_time: float, end_time: float, target_elements: Array[String], visible: bool) -> VisibilityRule:
	var rule = VisibilityRule.new()
	rule.rule_name = rule_name
	rule.rule_description = "Show/hide elements based on time range"
	rule.condition_type = "time_based"
	rule.condition_operator = "between"
	rule.condition_value = {"start": start_time, "end": end_time}
	rule.condition_property = "mission_time"
	rule.target_elements = target_elements
	rule.action_type = "visibility"
	rule.action_value = visible
	return rule

## Create an information density rule
static func create_density_rule(rule_name: String, density_level: String, target_elements: Array[String], visible: bool) -> VisibilityRule:
	var rule = VisibilityRule.new()
	rule.rule_name = rule_name
	rule.rule_description = "Show/hide elements based on information density: " + density_level
	rule.condition_type = "ui_state"
	rule.condition_operator = "equals"
	rule.condition_value = density_level
	rule.condition_property = "information_density"
	rule.target_elements = target_elements
	rule.action_type = "visibility"
	rule.action_value = visible
	return rule

## Evaluate the rule condition
func evaluate_condition(context: Dictionary) -> bool:
	if not is_active or not is_conditional:
		return false
	
	var current_value = _get_context_value(context)
	if current_value == null:
		return false
	
	var result = _compare_values(current_value, condition_value, condition_operator)
	
	# Update evaluation statistics
	evaluation_count += 1
	last_evaluation = result
	
	return result

## Get value from context based on condition type and property
func _get_context_value(context: Dictionary) -> Variant:
	match condition_type:
		"game_state":
			return context.get("game_state", {}).get(condition_property)
		"player_state":
			return context.get("player_state", {}).get(condition_property)
		"mission_state":
			return context.get("mission_state", {}).get(condition_property)
		"ship_system":
			return context.get("ship_systems", {}).get(condition_property)
		"ui_state":
			return context.get("ui_state", {}).get(condition_property)
		"time_based":
			return context.get("time", {}).get(condition_property)
		_:
			return context.get(condition_property)

## Compare values based on operator
func _compare_values(current: Variant, expected: Variant, operator: String) -> bool:
	match operator:
		"equals":
			return current == expected
		"not_equals":
			return current != expected
		"greater_than":
			return current > expected
		"less_than":
			return current < expected
		"greater_equals":
			return current >= expected
		"less_equals":
			return current <= expected
		"contains":
			if current is String and expected is String:
				return current.contains(expected)
			elif current is Array:
				return current.has(expected)
			return false
		"not_contains":
			if current is String and expected is String:
				return not current.contains(expected)
			elif current is Array:
				return not current.has(expected)
			return true
		"between":
			if expected is Dictionary and expected.has("start") and expected.has("end"):
				return current >= expected.start and current <= expected.end
			return false
		"in_list":
			if expected is Array:
				return expected.has(current)
			return false
		"not_in_list":
			if expected is Array:
				return not expected.has(current)
			return true
		_:
			return false

## Apply rule action to elements
func apply_rule(elements: Dictionary, context: Dictionary) -> bool:
	if not evaluate_condition(context):
		return false
	
	var applied = false
	
	for element_id in target_elements:
		var element = elements.get(element_id)
		if not element:
			continue
		
		match action_type:
			"visibility":
				_apply_visibility_action(element, action_value)
				applied = true
			"opacity":
				_apply_opacity_action(element, action_value)
				applied = true
			"scale":
				_apply_scale_action(element, action_value)
				applied = true
			"color_scheme":
				_apply_color_scheme_action(element, action_value)
				applied = true
	
	return applied

## Apply visibility action to element
func _apply_visibility_action(element: Node, visible: bool) -> void:
	if element.has_method("set_visible"):
		element.set_visible(visible)
	elif element.has_property("visible"):
		element.visible = visible

## Apply opacity action to element
func _apply_opacity_action(element: Node, opacity: float) -> void:
	if element.has_method("set_modulate"):
		var current_modulate = element.get_modulate() if element.has_method("get_modulate") else Color.WHITE
		element.set_modulate(Color(current_modulate.r, current_modulate.g, current_modulate.b, opacity))
	elif element.has_property("modulate"):
		var current_modulate = element.modulate
		element.modulate = Color(current_modulate.r, current_modulate.g, current_modulate.b, opacity)

## Apply scale action to element
func _apply_scale_action(element: Node, scale_factor: float) -> void:
	if element.has_method("set_scale"):
		element.set_scale(Vector2(scale_factor, scale_factor))
	elif element.has_property("scale"):
		element.scale = Vector2(scale_factor, scale_factor)

## Apply color scheme action to element
func _apply_color_scheme_action(element: Node, scheme: String) -> void:
	if element.has_method("set_color_scheme"):
		element.set_color_scheme(scheme)

## Check if rule targets specific element
func targets_element(element_id: String) -> bool:
	return target_elements.has(element_id)

## Add target element
func add_target_element(element_id: String) -> void:
	if not target_elements.has(element_id):
		target_elements.append(element_id)
		_mark_modified()

## Remove target element
func remove_target_element(element_id: String) -> void:
	var index = target_elements.find(element_id)
	if index >= 0:
		target_elements.remove_at(index)
		_mark_modified()

## Create a duplicate of this rule
func duplicate_rule() -> VisibilityRule:
	var new_rule = VisibilityRule.new()
	
	new_rule.rule_name = rule_name + "_copy"
	new_rule.rule_description = rule_description
	new_rule.rule_priority = rule_priority
	new_rule.condition_type = condition_type
	new_rule.condition_operator = condition_operator
	new_rule.condition_value = condition_value
	new_rule.condition_property = condition_property
	new_rule.target_elements = target_elements.duplicate()
	new_rule.element_group = element_group
	new_rule.action_type = action_type
	new_rule.action_value = action_value
	new_rule.animation_duration = animation_duration
	new_rule.is_active = is_active
	new_rule.is_conditional = is_conditional
	
	return new_rule

## Validate rule integrity
func validate_rule() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Check required fields
	if rule_name.is_empty():
		result.errors.append("Rule name cannot be empty")
		result.is_valid = false
	
	if condition_type.is_empty():
		result.errors.append("Condition type cannot be empty")
		result.is_valid = false
	
	if condition_operator.is_empty():
		result.errors.append("Condition operator cannot be empty")
		result.is_valid = false
	
	if target_elements.is_empty() and element_group.is_empty():
		result.errors.append("Rule must have target elements or element group")
		result.is_valid = false
	
	# Validate condition operator
	var valid_operators = [
		"equals", "not_equals", "greater_than", "less_than", 
		"greater_equals", "less_equals", "contains", "not_contains",
		"between", "in_list", "not_in_list"
	]
	
	if not valid_operators.has(condition_operator):
		result.errors.append("Invalid condition operator: " + condition_operator)
		result.is_valid = false
	
	# Validate action type
	var valid_actions = ["visibility", "opacity", "scale", "color_scheme"]
	if not valid_actions.has(action_type):
		result.errors.append("Invalid action type: " + action_type)
		result.is_valid = false
	
	# Validate animation duration
	if animation_duration < 0.0 or animation_duration > 5.0:
		result.warnings.append("Animation duration outside normal range: " + str(animation_duration))
	
	return result

## Mark rule as modified
func _mark_modified() -> void:
	last_modified = Time.get_datetime_string_from_system()

## Get rule summary
func get_rule_summary() -> Dictionary:
	return {
		"name": rule_name,
		"description": rule_description,
		"condition": condition_type + " " + condition_operator + " " + str(condition_value),
		"targets": target_elements.size(),
		"action": action_type + " = " + str(action_value),
		"active": is_active,
		"priority": rule_priority,
		"evaluations": evaluation_count,
		"last_result": last_evaluation
	}