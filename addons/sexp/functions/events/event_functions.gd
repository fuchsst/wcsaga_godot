## SEXP Event Functions for SEXP-007: Mission Event Integration
##
## Provides event management and trigger control functions for mission scripting.

const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Fire event function
class SexpFireEventFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "fire-event"
		argument_count = 1
		argument_count_max = 2
		description = "Fire a custom mission event with optional data"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var event_id_arg = args[0]
		if not event_id_arg.is_string():
			return SexpResult.create_error("Event ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var event_id = event_id_arg.get_string_value()
		if event_id.is_empty():
			return SexpResult.create_error("Event ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var event_data = {}
		if args.size() > 1:
			var data_arg = args[1]
			if data_arg.is_string():
				event_data["message"] = data_arg.get_string_value()
			elif data_arg.is_number():
				event_data["value"] = data_arg.get_number_value()
			elif data_arg.is_boolean():
				event_data["flag"] = data_arg.get_boolean_value()
		
		var event_manager = _get_event_manager()
		if not event_manager:
			return SexpResult.create_error("Event manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		event_manager.mission_event_fired.emit(event_id, event_data)
		return SexpResult.create_boolean(true)
	
	func _get_event_manager():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			return tree.get_first_node_in_group("mission_event_manager")
		return null

## Enable trigger function
class SexpEnableTriggerFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "enable-trigger"
		argument_count = 1
		description = "Enable/activate a mission trigger"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var trigger_id_arg = args[0]
		if not trigger_id_arg.is_string():
			return SexpResult.create_error("Trigger ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var trigger_id = trigger_id_arg.get_string_value()
		if trigger_id.is_empty():
			return SexpResult.create_error("Trigger ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var event_manager = _get_event_manager()
		if not event_manager:
			return SexpResult.create_error("Event manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var success = event_manager.activate_trigger(trigger_id)
		return SexpResult.create_boolean(success)
	
	func _get_event_manager():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			return tree.get_first_node_in_group("mission_event_manager")
		return null

## Disable trigger function
class SexpDisableTriggerFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "disable-trigger"
		argument_count = 1
		description = "Disable/deactivate a mission trigger"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var trigger_id_arg = args[0]
		if not trigger_id_arg.is_string():
			return SexpResult.create_error("Trigger ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var trigger_id = trigger_id_arg.get_string_value()
		if trigger_id.is_empty():
			return SexpResult.create_error("Trigger ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var event_manager = _get_event_manager()
		if not event_manager:
			return SexpResult.create_error("Event manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var success = event_manager.deactivate_trigger(trigger_id)
		return SexpResult.create_boolean(success)
	
	func _get_event_manager():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			return tree.get_first_node_in_group("mission_event_manager")
		return null

## Check trigger state function
class SexpIsTriggerActiveFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "is-trigger-active"
		argument_count = 1
		description = "Check if a mission trigger is currently active"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var trigger_id_arg = args[0]
		if not trigger_id_arg.is_string():
			return SexpResult.create_error("Trigger ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var trigger_id = trigger_id_arg.get_string_value()
		if trigger_id.is_empty():
			return SexpResult.create_error("Trigger ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var event_manager = _get_event_manager()
		if not event_manager:
			return SexpResult.create_error("Event manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var trigger = event_manager.get_trigger(trigger_id)
		if not trigger:
			return SexpResult.create_boolean(false)
		
		var state = event_manager.get_trigger_state(trigger_id)
		var is_active = (state == event_manager.TriggerState.ACTIVE)
		return SexpResult.create_boolean(is_active)
	
	func _get_event_manager():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			return tree.get_first_node_in_group("mission_event_manager")
		return null

## Delay function
class SexpDelayFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "delay"
		argument_count = 2
		description = "Execute an action after a specified delay in seconds"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var delay_arg = args[0]
		var action_arg = args[1]
		
		if not delay_arg.is_number():
			return SexpResult.create_error("Delay must be a number", SexpResult.ErrorType.TYPE_MISMATCH)
		
		if not action_arg.is_string():
			return SexpResult.create_error("Action must be a string expression", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var delay_seconds = delay_arg.get_number_value()
		var action_expr = action_arg.get_string_value()
		
		if delay_seconds < 0:
			return SexpResult.create_error("Delay cannot be negative", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var event_manager = _get_event_manager()
		if not event_manager:
			return SexpResult.create_error("Event manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		# Create a timer trigger for the delay
		var EventTrigger = preload("res://addons/sexp/events/event_trigger.gd")
		var timer_trigger = EventTrigger.create_timer_trigger(
			"delay_" + str(Time.get_time_dict_from_system()["unix"]),
			delay_seconds,
			action_expr
		)
		
		var trigger_id = timer_trigger.trigger_id
		var success = event_manager.register_trigger(trigger_id, timer_trigger)
		
		return SexpResult.create_boolean(success)
	
	func _get_event_manager():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			return tree.get_first_node_in_group("mission_event_manager")
		return null

## When function (condition-based event)
class SexpWhenFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "when"
		argument_count = 2
		argument_count_max = 3
		description = "Execute an action when a condition becomes true"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var condition_arg = args[0]
		var action_arg = args[1]
		
		if not condition_arg.is_string():
			return SexpResult.create_error("Condition must be a string expression", SexpResult.ErrorType.TYPE_MISMATCH)
		
		if not action_arg.is_string():
			return SexpResult.create_error("Action must be a string expression", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var condition_expr = condition_arg.get_string_value()
		var action_expr = action_arg.get_string_value()
		
		# Check for optional repeat count
		var repeat_count = 1
		if args.size() > 2:
			var repeat_arg = args[2]
			if not repeat_arg.is_number():
				return SexpResult.create_error("Repeat count must be a number", SexpResult.ErrorType.TYPE_MISMATCH)
			repeat_count = int(repeat_arg.get_number_value())
		
		var event_manager = _get_event_manager()
		if not event_manager:
			return SexpResult.create_error("Event manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		# Create a conditional trigger
		var EventTrigger = preload("res://addons/sexp/events/event_trigger.gd")
		var conditional_trigger = EventTrigger.new()
		conditional_trigger.trigger_id = "when_" + str(Time.get_time_dict_from_system()["unix"])
		conditional_trigger.trigger_type = EventTrigger.TriggerType.CONDITIONAL
		conditional_trigger.timing_mode = EventTrigger.TimingMode.FRAME_BASED
		conditional_trigger.condition_expression = condition_expr
		conditional_trigger.action_expression = action_expr
		conditional_trigger.repeat_count = repeat_count
		conditional_trigger.auto_start = true
		conditional_trigger.debug_name = "When: %s" % condition_expr[:30]
		
		var success = event_manager.register_trigger(conditional_trigger.trigger_id, conditional_trigger)
		return SexpResult.create_boolean(success)
	
	func _get_event_manager():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			return tree.get_first_node_in_group("mission_event_manager")
		return null

## Every-time function (repeating condition)
class SexpEveryTimeFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "every-time"
		argument_count = 2
		description = "Execute an action every time a condition becomes true"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var condition_arg = args[0]
		var action_arg = args[1]
		
		if not condition_arg.is_string():
			return SexpResult.create_error("Condition must be a string expression", SexpResult.ErrorType.TYPE_MISMATCH)
		
		if not action_arg.is_string():
			return SexpResult.create_error("Action must be a string expression", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var condition_expr = condition_arg.get_string_value()
		var action_expr = action_arg.get_string_value()
		
		var event_manager = _get_event_manager()
		if not event_manager:
			return SexpResult.create_error("Event manager not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		# Create a repeating conditional trigger
		var EventTrigger = preload("res://addons/sexp/events/event_trigger.gd")
		var repeating_trigger = EventTrigger.new()
		repeating_trigger.trigger_id = "every_time_" + str(Time.get_time_dict_from_system()["unix"])
		repeating_trigger.trigger_type = EventTrigger.TriggerType.CONDITIONAL
		repeating_trigger.timing_mode = EventTrigger.TimingMode.FRAME_BASED
		repeating_trigger.condition_expression = condition_expr
		repeating_trigger.action_expression = action_expr
		repeating_trigger.repeat_count = -1  # Infinite repeats
		repeating_trigger.auto_start = true
		repeating_trigger.debug_name = "EveryTime: %s" % condition_expr[:30]
		
		var success = event_manager.register_trigger(repeating_trigger.trigger_id, repeating_trigger)
		return SexpResult.create_boolean(success)
	
	func _get_event_manager():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			return tree.get_first_node_in_group("mission_event_manager")
		return null