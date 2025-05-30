class_name SexpEventFunctionRegistration
extends RefCounted

## Event Function Registration for SEXP-007: Mission Event Integration
##
## Registers all event and objective management functions with the SEXP function registry.

const SexpFunctionRegistry = preload("res://addons/sexp/functions/sexp_function_registry.gd")
const SexpMissionTimeFunction = preload("res://addons/sexp/functions/events/mission_time_function.gd")

# Import objective functions
const ObjectiveFunctions = preload("res://addons/sexp/functions/events/objective_functions.gd")
const SexpCompleteObjectiveFunction = ObjectiveFunctions.SexpCompleteObjectiveFunction
const SexpFailObjectiveFunction = ObjectiveFunctions.SexpFailObjectiveFunction
const SexpIsObjectiveCompleteFunction = ObjectiveFunctions.SexpIsObjectiveCompleteFunction
const SexpIsObjectiveActiveFunction = ObjectiveFunctions.SexpIsObjectiveActiveFunction
const SexpActivateObjectiveFunction = ObjectiveFunctions.SexpActivateObjectiveFunction
const SexpSetObjectiveProgressFunction = ObjectiveFunctions.SexpSetObjectiveProgressFunction

# Import event functions
const EventFunctions = preload("res://addons/sexp/functions/events/event_functions.gd")
const SexpFireEventFunction = EventFunctions.SexpFireEventFunction
const SexpEnableTriggerFunction = EventFunctions.SexpEnableTriggerFunction
const SexpDisableTriggerFunction = EventFunctions.SexpDisableTriggerFunction
const SexpIsTriggerActiveFunction = EventFunctions.SexpIsTriggerActiveFunction
const SexpDelayFunction = EventFunctions.SexpDelayFunction
const SexpWhenFunction = EventFunctions.SexpWhenFunction
const SexpEveryTimeFunction = EventFunctions.SexpEveryTimeFunction

## Register all event and objective functions
static func register_all_event_functions(registry: SexpFunctionRegistry) -> bool:
	var success: bool = true
	
	# Mission timing functions
	success = registry.register_function(SexpMissionTimeFunction.new()) and success
	
	# Objective management functions
	success = registry.register_function(SexpCompleteObjectiveFunction.new()) and success
	success = registry.register_function(SexpFailObjectiveFunction.new()) and success
	success = registry.register_function(SexpIsObjectiveCompleteFunction.new()) and success
	success = registry.register_function(SexpIsObjectiveActiveFunction.new()) and success
	success = registry.register_function(SexpActivateObjectiveFunction.new()) and success
	success = registry.register_function(SexpSetObjectiveProgressFunction.new()) and success
	
	# Event management functions
	success = registry.register_function(SexpFireEventFunction.new()) and success
	success = registry.register_function(SexpEnableTriggerFunction.new()) and success
	success = registry.register_function(SexpDisableTriggerFunction.new()) and success
	success = registry.register_function(SexpIsTriggerActiveFunction.new()) and success
	
	# Event timing and conditional functions
	success = registry.register_function(SexpDelayFunction.new()) and success
	success = registry.register_function(SexpWhenFunction.new()) and success
	success = registry.register_function(SexpEveryTimeFunction.new()) and success
	
	if success:
		print("[EventFunctionRegistration] Successfully registered %d event functions" % get_registered_function_count())
	else:
		push_error("[EventFunctionRegistration] Failed to register some event functions")
	
	return success

## Get the number of functions this module registers
static func get_registered_function_count() -> int:
	return 13  # Total number of event/objective functions

## Get list of all event function names
static func get_event_function_names() -> Array[String]:
	return [
		# Mission timing
		"mission-time",
		
		# Objective management
		"complete-objective",
		"fail-objective",
		"is-objective-complete",
		"is-objective-active",
		"activate-objective",
		"set-objective-progress",
		
		# Event management
		"fire-event",
		"enable-trigger",
		"disable-trigger",
		"is-trigger-active",
		
		# Event timing and conditionals
		"delay",
		"when",
		"every-time"
	]

## Get function categories for documentation
static func get_function_categories() -> Dictionary:
	return {
		"Mission Timing": [
			"mission-time"
		],
		"Objective Management": [
			"complete-objective",
			"fail-objective",
			"is-objective-complete", 
			"is-objective-active",
			"activate-objective",
			"set-objective-progress"
		],
		"Event Management": [
			"fire-event",
			"enable-trigger",
			"disable-trigger",
			"is-trigger-active"
		],
		"Event Timing & Conditionals": [
			"delay",
			"when",
			"every-time"
		]
	}

## Get function descriptions for help system
static func get_function_descriptions() -> Dictionary:
	return {
		"mission-time": "Returns the current mission time in seconds since mission start",
		"complete-objective": "Mark a mission objective as completed",
		"fail-objective": "Mark a mission objective as failed",
		"is-objective-complete": "Check if a mission objective is completed",
		"is-objective-active": "Check if a mission objective is currently active",
		"activate-objective": "Activate a mission objective to begin tracking",
		"set-objective-progress": "Set progress for a progressive objective",
		"fire-event": "Fire a custom mission event with optional data",
		"enable-trigger": "Enable/activate a mission trigger",
		"disable-trigger": "Disable/deactivate a mission trigger", 
		"is-trigger-active": "Check if a mission trigger is currently active",
		"delay": "Execute an action after a specified delay in seconds",
		"when": "Execute an action when a condition becomes true",
		"every-time": "Execute an action every time a condition becomes true"
	}