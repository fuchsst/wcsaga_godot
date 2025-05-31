@tool
class_name PatternInsertionManager
extends RefCounted

## Pattern insertion manager for GFRED2 Template Library.
## Handles insertion of templates and patterns into existing missions.

signal pattern_inserted(pattern_type: String, pattern_id: String, success: bool)
signal template_applied(template: MissionTemplate, success: bool)
signal validation_completed(success: bool, errors: Array[String])

# Core managers
var template_manager: TemplateLibraryManager
var sexp_manager: SexpManager

# Integration points
var mission_data: MissionData
var visual_sexp_editor: VisualSexpEditor

func _init(target_mission: MissionData = null, sexp_editor: VisualSexpEditor = null) -> void:
	mission_data = target_mission
	visual_sexp_editor = sexp_editor
	template_manager = TemplateLibraryManager.new()
	sexp_manager = SexpManager

## Sets the target mission for pattern insertion
func set_target_mission(target_mission: MissionData) -> void:
	mission_data = target_mission

## Sets the SEXP editor for pattern insertion
func set_sexp_editor(editor: VisualSexpEditor) -> void:
	visual_sexp_editor = editor

## Inserts a SEXP pattern into the current mission
func insert_sexp_pattern(pattern: SexpPattern, parameters: Dictionary, insertion_context: Dictionary = {}) -> bool:
	if not pattern or not mission_data:
		push_error("Pattern or mission data is null")
		return false
	
	# Validate pattern before insertion
	var validation_errors: Array[String] = pattern.validate_pattern()
	if not validation_errors.is_empty():
		push_error("Pattern validation failed: " + str(validation_errors))
		validation_completed.emit(false, validation_errors)
		return false
	
	# Apply pattern with parameters
	var applied_expression: String = pattern.apply_pattern(parameters)
	
	# Validate applied expression
	var syntax_valid: bool = sexp_manager.validate_syntax(applied_expression)
	if not syntax_valid:
		var syntax_errors: Array[String] = sexp_manager.get_validation_errors(applied_expression)
		push_error("Applied pattern syntax invalid: " + str(syntax_errors))
		validation_completed.emit(false, syntax_errors)
		return false
	
	# Insert pattern based on category and context
	var success: bool = false
	match pattern.category:
		SexpPattern.PatternCategory.TRIGGER:
			success = _insert_trigger_pattern(applied_expression, insertion_context)
		SexpPattern.PatternCategory.ACTION:
			success = _insert_action_pattern(applied_expression, insertion_context)
		SexpPattern.PatternCategory.CONDITION:
			success = _insert_condition_pattern(applied_expression, insertion_context)
		SexpPattern.PatternCategory.OBJECTIVE:
			success = _insert_objective_pattern(applied_expression, insertion_context)
		SexpPattern.PatternCategory.EVENT_SEQUENCE:
			success = _insert_event_pattern(applied_expression, insertion_context)
		_:
			success = _insert_generic_pattern(applied_expression, insertion_context)
	
	if success:
		print("Successfully inserted SEXP pattern: " + pattern.pattern_name)
		validation_completed.emit(true, [])
	
	pattern_inserted.emit("sexp", pattern.pattern_id, success)
	return success

## Inserts trigger pattern as mission event
func _insert_trigger_pattern(expression: String, context: Dictionary) -> bool:
	var event: MissionEvent = MissionEvent.new()
	event.event_name = context.get("event_name", "Pattern Event " + str(mission_data.events.size() + 1))
	event.condition_sexp = expression
	event.action_sexp = context.get("action", "(true)") # Default action
	event.repeat_count = context.get("repeat_count", 1)
	event.interval = context.get("interval", 1.0)
	
	mission_data.add_event(event)
	return true

## Inserts action pattern into existing event or creates new event
func _insert_action_pattern(expression: String, context: Dictionary) -> bool:
	var target_event_name: String = context.get("target_event", "")
	var target_event: MissionEvent = null
	
	# Find target event if specified
	if not target_event_name.is_empty():
		for event in mission_data.events:
			if event.event_name == target_event_name:
				target_event = event
				break
	
	if target_event:
		# Append to existing event action
		if target_event.action_sexp.is_empty() or target_event.action_sexp == "(true)":
			target_event.action_sexp = expression
		else:
			target_event.action_sexp = "(when-sequence\n  %s\n  %s\n)" % [target_event.action_sexp, expression]
	else:
		# Create new event with this action
		var event: MissionEvent = MissionEvent.new()
		event.event_name = context.get("event_name", "Action Event " + str(mission_data.events.size() + 1))
		event.condition_sexp = context.get("condition", "(true)")
		event.action_sexp = expression
		mission_data.add_event(event)
	
	return true

## Inserts condition pattern into existing event
func _insert_condition_pattern(expression: String, context: Dictionary) -> bool:
	var target_event_name: String = context.get("target_event", "")
	var target_event: MissionEvent = null
	
	# Find target event
	if not target_event_name.is_empty():
		for event in mission_data.events:
			if event.event_name == target_event_name:
				target_event = event
				break
	
	if target_event:
		# Combine with existing condition
		if target_event.condition_sexp.is_empty() or target_event.condition_sexp == "(true)":
			target_event.condition_sexp = expression
		else:
			var combine_type: String = context.get("combine_type", "and")
			target_event.condition_sexp = "(%s\n  %s\n  %s\n)" % [combine_type, target_event.condition_sexp, expression]
		return true
	else:
		# Create new event with this condition
		return _insert_trigger_pattern(expression, context)

## Inserts objective pattern as mission goal
func _insert_objective_pattern(expression: String, context: Dictionary) -> bool:
	var goal: MissionGoal = MissionGoal.new()
	goal.goal_name = context.get("goal_name", "Pattern Goal " + str(mission_data.primary_goals.size() + 1))
	goal.description = context.get("goal_description", "Goal created from pattern")
	goal.type = context.get("goal_type", MissionGoal.Type.PRIMARY)
	
	# Use expression as goal condition
	goal.condition_sexp = expression
	
	mission_data.add_goal(goal)
	return true

## Inserts event sequence pattern as multiple linked events
func _insert_event_pattern(expression: String, context: Dictionary) -> bool:
	# For event sequences, try to parse and create multiple events
	var base_name: String = context.get("sequence_name", "Event Sequence " + str(mission_data.events.size() + 1))
	
	# Create the main event
	var event: MissionEvent = MissionEvent.new()
	event.event_name = base_name
	event.condition_sexp = expression
	event.action_sexp = context.get("action", "(true)")
	
	mission_data.add_event(event)
	
	# If context specifies follow-up events, create them
	if context.has("follow_up_events"):
		var follow_ups: Array = context.follow_up_events
		for i in follow_ups.size():
			var follow_up: Dictionary = follow_ups[i]
			var follow_up_event: MissionEvent = MissionEvent.new()
			follow_up_event.event_name = base_name + " Step " + str(i + 2)
			follow_up_event.condition_sexp = follow_up.get("condition", "(true)")
			follow_up_event.action_sexp = follow_up.get("action", "(true)")
			mission_data.add_event(follow_up_event)
	
	return true

## Inserts generic pattern based on context hints
func _insert_generic_pattern(expression: String, context: Dictionary) -> bool:
	var insertion_type: String = context.get("insertion_type", "event")
	
	match insertion_type:
		"event":
			return _insert_trigger_pattern(expression, context)
		"goal":
			return _insert_objective_pattern(expression, context)
		"variable":
			return _insert_variable_pattern(expression, context)
		_:
			# Default to event insertion
			return _insert_trigger_pattern(expression, context)

## Inserts variable management pattern
func _insert_variable_pattern(expression: String, context: Dictionary) -> bool:
	var variable_name: String = context.get("variable_name", "pattern_var_" + str(mission_data.variables.size() + 1))
	var variable_value = context.get("variable_value", 0)
	
	# Set variable in mission data
	mission_data.set_variable(variable_name, variable_value)
	
	# Create event to manage the variable
	var event: MissionEvent = MissionEvent.new()
	event.event_name = "Manage Variable: " + variable_name
	event.condition_sexp = context.get("condition", "(true)")
	event.action_sexp = expression
	
	mission_data.add_event(event)
	return true

## Inserts asset pattern into mission
func insert_asset_pattern(pattern: AssetPattern, parameters: Dictionary, insertion_context: Dictionary = {}) -> bool:
	if not pattern or not mission_data:
		push_error("Pattern or mission data is null")
		return false
	
	# Validate pattern before insertion
	var validation_errors: Array[String] = pattern.validate_pattern()
	if not validation_errors.is_empty():
		push_error("Asset pattern validation failed: " + str(validation_errors))
		validation_completed.emit(false, validation_errors)
		return false
	
	# Create mission objects from pattern
	var created_objects: Array[MissionObject] = pattern.create_mission_objects(parameters)
	var success: bool = false
	
	if created_objects.size() > 0:
		# Add objects to mission
		for obj in created_objects:
			# Apply any position/placement parameters
			_apply_object_positioning(obj, insertion_context)
			mission_data.add_object(obj)
		
		success = true
		print("Successfully inserted asset pattern: " + pattern.pattern_name + " (%d objects)" % created_objects.size())
		validation_completed.emit(true, [])
	else:
		push_error("Asset pattern did not create any objects")
		validation_completed.emit(false, ["No objects created from pattern"])
	
	pattern_inserted.emit("asset", pattern.pattern_id, success)
	return success

## Applies object positioning from insertion context
func _apply_object_positioning(obj: MissionObject, context: Dictionary) -> void:
	# Apply position if specified
	if context.has("position"):
		var position: Vector3 = context.position
		obj.set_property("position", position)
	
	# Apply orientation if specified
	if context.has("orientation"):
		var orientation: Vector3 = context.orientation
		obj.set_property("orientation", orientation)
	
	# Apply arrival location if specified
	if context.has("arrival_location"):
		obj.arrival_location = context.arrival_location
	
	# Apply team if specified
	if context.has("team"):
		obj.team = context.team

## Applies mission template to current mission (replaces mission data)
func apply_mission_template(template: MissionTemplate, parameters: Dictionary) -> bool:
	if not template:
		push_error("Template is null")
		return false
	
	# Validate template
	var validation_errors: Array[String] = template.validate_template()
	if not validation_errors.is_empty():
		push_error("Template validation failed: " + str(validation_errors))
		validation_completed.emit(false, validation_errors)
		return false
	
	# Create mission from template
	var new_mission: MissionData = template.create_mission(parameters)
	if not new_mission:
		push_error("Failed to create mission from template")
		validation_completed.emit(false, ["Failed to create mission from template"])
		return false
	
	# Replace current mission data (this is destructive)
	if mission_data:
		# Copy new mission data to current mission
		mission_data.title = new_mission.title
		mission_data.description = new_mission.description
		mission_data.designer = new_mission.designer
		mission_data.mission_type = new_mission.mission_type
		
		# Clear and replace objects
		mission_data.objects.clear()
		mission_data.root_objects.clear()
		for obj in new_mission.objects.values():
			mission_data.add_object(obj)
		
		# Clear and replace events
		mission_data.events.clear()
		for event in new_mission.events:
			mission_data.add_event(event)
		
		# Clear and replace goals
		mission_data.primary_goals.clear()
		mission_data.secondary_goals.clear()
		mission_data.hidden_goals.clear()
		for goal in new_mission.primary_goals + new_mission.secondary_goals + new_mission.hidden_goals:
			mission_data.add_goal(goal)
		
		# Copy variables
		mission_data.variables = new_mission.variables.duplicate()
		
		print("Successfully applied mission template: " + template.template_name)
		validation_completed.emit(true, [])
		template_applied.emit(template, true)
		return true
	
	template_applied.emit(template, false)
	return false

## Merges mission template content with current mission (non-destructive)
func merge_mission_template(template: MissionTemplate, parameters: Dictionary, merge_options: Dictionary = {}) -> bool:
	if not template or not mission_data:
		push_error("Template or mission data is null")
		return false
	
	# Create mission from template
	var template_mission: MissionData = template.create_mission(parameters)
	if not template_mission:
		push_error("Failed to create mission from template")
		return false
	
	var success: bool = true
	
	# Merge objects (with prefix to avoid conflicts)
	var object_prefix: String = merge_options.get("object_prefix", "template_")
	for obj in template_mission.objects.values():
		var new_obj: MissionObject = obj.duplicate(true)
		new_obj.id = object_prefix + new_obj.id
		new_obj.name = object_prefix + new_obj.name
		
		# Apply positioning offset if specified
		if merge_options.has("position_offset"):
			var offset: Vector3 = merge_options.position_offset
			var current_pos: Vector3 = new_obj.get_property("position", Vector3.ZERO)
			new_obj.set_property("position", current_pos + offset)
		
		mission_data.add_object(new_obj)
	
	# Merge events (with prefix)
	var event_prefix: String = merge_options.get("event_prefix", "template_")
	for event in template_mission.events:
		var new_event: MissionEvent = event.duplicate(true)
		new_event.event_name = event_prefix + new_event.event_name
		mission_data.add_event(new_event)
	
	# Merge goals (with prefix)
	var goal_prefix: String = merge_options.get("goal_prefix", "template_")
	for goal in template_mission.primary_goals + template_mission.secondary_goals + template_mission.hidden_goals:
		var new_goal: MissionGoal = goal.duplicate(true)
		new_goal.goal_name = goal_prefix + new_goal.goal_name
		mission_data.add_goal(new_goal)
	
	# Merge variables (with prefix to avoid conflicts)
	var var_prefix: String = merge_options.get("variable_prefix", "template_")
	for var_name in template_mission.variables.keys():
		var new_var_name: String = var_prefix + var_name
		mission_data.set_variable(new_var_name, template_mission.variables[var_name])
	
	if success:
		print("Successfully merged mission template: " + template.template_name)
		validation_completed.emit(true, [])
		template_applied.emit(template, true)
	
	return success

## Validates mission after pattern insertion
func validate_mission_after_insertion() -> Dictionary:
	if not mission_data:
		return {"valid": false, "errors": ["No mission data"]}
	
	var validation_result: Dictionary = {"valid": true, "errors": [], "warnings": []}
	
	# Validate mission data
	var mission_errors: Array[String] = mission_data.validate()
	if not mission_errors.is_empty():
		validation_result.valid = false
		validation_result.errors.append_array(mission_errors)
	
	# Validate all SEXP expressions in events
	for event in mission_data.events:
		if not event.condition_sexp.is_empty():
			var condition_valid: bool = sexp_manager.validate_syntax(event.condition_sexp)
			if not condition_valid:
				validation_result.valid = false
				var errors: Array[String] = sexp_manager.get_validation_errors(event.condition_sexp)
				validation_result.errors.append("Event '%s' condition invalid: %s" % [event.event_name, str(errors)])
		
		if not event.action_sexp.is_empty():
			var action_valid: bool = sexp_manager.validate_syntax(event.action_sexp)
			if not action_valid:
				validation_result.valid = false
				var errors: Array[String] = sexp_manager.get_validation_errors(event.action_sexp)
				validation_result.errors.append("Event '%s' action invalid: %s" % [event.event_name, str(errors)])
	
	# Validate goal conditions
	for goal in mission_data.primary_goals + mission_data.secondary_goals + mission_data.hidden_goals:
		if goal.has_method("get_condition_sexp") and not goal.get_condition_sexp().is_empty():
			var condition: String = goal.get_condition_sexp()
			var condition_valid: bool = sexp_manager.validate_syntax(condition)
			if not condition_valid:
				validation_result.valid = false
				var errors: Array[String] = sexp_manager.get_validation_errors(condition)
				validation_result.errors.append("Goal '%s' condition invalid: %s" % [goal.goal_name, str(errors)])
	
	# Check for common issues
	if mission_data.primary_goals.is_empty():
		validation_result.warnings.append("Mission has no primary goals")
	
	if mission_data.events.is_empty():
		validation_result.warnings.append("Mission has no events")
	
	return validation_result

## Gets insertion context suggestions for a pattern
func get_insertion_context_suggestions(pattern: SexpPattern) -> Dictionary:
	var suggestions: Dictionary = {}
	
	match pattern.category:
		SexpPattern.PatternCategory.TRIGGER:
			suggestions = {
				"event_name": "Trigger Event " + str(mission_data.events.size() + 1),
				"action": "(send-message \"Command\" \"Trigger activated\" \"normal\" \"none\")",
				"repeat_count": 1,
				"interval": 1.0
			}
		
		SexpPattern.PatternCategory.ACTION:
			suggestions = {
				"target_event": mission_data.events[-1].event_name if mission_data.events.size() > 0 else "",
				"condition": "(true)"
			}
		
		SexpPattern.PatternCategory.OBJECTIVE:
			suggestions = {
				"goal_name": "Pattern Goal " + str(mission_data.primary_goals.size() + 1),
				"goal_description": "Goal created from " + pattern.pattern_name,
				"goal_type": MissionGoal.Type.PRIMARY
			}
		
		SexpPattern.PatternCategory.EVENT_SEQUENCE:
			suggestions = {
				"sequence_name": "Event Sequence " + str(mission_data.events.size() + 1),
				"follow_up_events": []
			}
	
	return suggestions

## Gets asset pattern placement suggestions
func get_asset_placement_suggestions(pattern: AssetPattern) -> Dictionary:
	var suggestions: Dictionary = {}
	
	# Suggest placement based on existing objects
	var existing_objects: Array = mission_data.objects.values()
	if existing_objects.size() > 0:
		# Place near existing objects but offset
		var avg_position: Vector3 = Vector3.ZERO
		for obj in existing_objects:
			if obj.has_method("get_property"):
				avg_position += obj.get_property("position", Vector3.ZERO)
		
		if existing_objects.size() > 0:
			avg_position /= existing_objects.size()
			suggestions["position"] = avg_position + Vector3(1000, 0, 1000) # Offset
	else:
		# Default position
		suggestions["position"] = Vector3.ZERO
	
	suggestions["orientation"] = Vector3.ZERO
	suggestions["team"] = 1 # Default to player team
	
	return suggestions