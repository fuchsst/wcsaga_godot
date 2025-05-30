## SEXP Objective Functions for SEXP-007: Mission Event Integration
##
## Provides WCS-compatible objective management functions for mission scripting.

const BaseSexpFunction = preload("res://addons/sexp/functions/base_sexp_function.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

## Complete objective function
class SexpCompleteObjectiveFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "complete-objective"
		argument_count = 1
		description = "Mark a mission objective as completed"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var objective_id_arg = args[0]
		if not objective_id_arg.is_string():
			return SexpResult.create_error("Objective ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var objective_id = objective_id_arg.get_string_value()
		if objective_id.is_empty():
			return SexpResult.create_error("Objective ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var objective_system = _get_objective_system()
		if not objective_system:
			return SexpResult.create_error("Objective system not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var success = objective_system.complete_objective(objective_id)
		return SexpResult.create_boolean(success)
	
	func _get_objective_system():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var event_manager = tree.get_first_node_in_group("mission_event_manager")
			if event_manager and event_manager.has_method("get_objective_system"):
				return event_manager.get_objective_system()
		return null

## Fail objective function
class SexpFailObjectiveFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "fail-objective"
		argument_count = 1
		description = "Mark a mission objective as failed"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var objective_id_arg = args[0]
		if not objective_id_arg.is_string():
			return SexpResult.create_error("Objective ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var objective_id = objective_id_arg.get_string_value()
		if objective_id.is_empty():
			return SexpResult.create_error("Objective ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var objective_system = _get_objective_system()
		if not objective_system:
			return SexpResult.create_error("Objective system not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var success = objective_system.fail_objective(objective_id)
		return SexpResult.create_boolean(success)
	
	func _get_objective_system():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var event_manager = tree.get_first_node_in_group("mission_event_manager")
			if event_manager and event_manager.has_method("get_objective_system"):
				return event_manager.get_objective_system()
		return null

## Check objective state function
class SexpIsObjectiveCompleteFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "is-objective-complete"
		argument_count = 1
		description = "Check if a mission objective is completed"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var objective_id_arg = args[0]
		if not objective_id_arg.is_string():
			return SexpResult.create_error("Objective ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var objective_id = objective_id_arg.get_string_value()
		if objective_id.is_empty():
			return SexpResult.create_error("Objective ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var objective_system = _get_objective_system()
		if not objective_system:
			return SexpResult.create_error("Objective system not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var is_complete = objective_system.is_objective_completed(objective_id)
		return SexpResult.create_boolean(is_complete)
	
	func _get_objective_system():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var event_manager = tree.get_first_node_in_group("mission_event_manager")
			if event_manager and event_manager.has_method("get_objective_system"):
				return event_manager.get_objective_system()
		return null

## Check if objective is active
class SexpIsObjectiveActiveFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "is-objective-active"
		argument_count = 1
		description = "Check if a mission objective is currently active"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var objective_id_arg = args[0]
		if not objective_id_arg.is_string():
			return SexpResult.create_error("Objective ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var objective_id = objective_id_arg.get_string_value()
		if objective_id.is_empty():
			return SexpResult.create_error("Objective ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var objective_system = _get_objective_system()
		if not objective_system:
			return SexpResult.create_error("Objective system not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var is_active = objective_system.is_objective_active(objective_id)
		return SexpResult.create_boolean(is_active)
	
	func _get_objective_system():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var event_manager = tree.get_first_node_in_group("mission_event_manager")
			if event_manager and event_manager.has_method("get_objective_system"):
				return event_manager.get_objective_system()
		return null

## Activate objective function
class SexpActivateObjectiveFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "activate-objective"
		argument_count = 1
		description = "Activate a mission objective to begin tracking"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var objective_id_arg = args[0]
		if not objective_id_arg.is_string():
			return SexpResult.create_error("Objective ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var objective_id = objective_id_arg.get_string_value()
		if objective_id.is_empty():
			return SexpResult.create_error("Objective ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var objective_system = _get_objective_system()
		if not objective_system:
			return SexpResult.create_error("Objective system not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var success = objective_system.activate_objective(objective_id)
		return SexpResult.create_boolean(success)
	
	func _get_objective_system():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var event_manager = tree.get_first_node_in_group("mission_event_manager")
			if event_manager and event_manager.has_method("get_objective_system"):
				return event_manager.get_objective_system()
		return null

## Set objective progress function
class SexpSetObjectiveProgressFunction extends BaseSexpFunction:
	func _init():
		super._init()
		function_name = "set-objective-progress"
		argument_count = 2
		description = "Set progress for a progressive objective"
	
	func _execute_implementation(args: Array[SexpResult]) -> SexpResult:
		var objective_id_arg = args[0]
		var progress_arg = args[1]
		
		if not objective_id_arg.is_string():
			return SexpResult.create_error("Objective ID must be a string", SexpResult.ErrorType.TYPE_MISMATCH)
		
		if not progress_arg.is_number():
			return SexpResult.create_error("Progress must be a number", SexpResult.ErrorType.TYPE_MISMATCH)
		
		var objective_id = objective_id_arg.get_string_value()
		var progress = int(progress_arg.get_number_value())
		
		if objective_id.is_empty():
			return SexpResult.create_error("Objective ID cannot be empty", SexpResult.ErrorType.VALIDATION_ERROR)
		
		var objective_system = _get_objective_system()
		if not objective_system:
			return SexpResult.create_error("Objective system not available", SexpResult.ErrorType.RUNTIME_ERROR)
		
		var success = objective_system.set_objective_progress(objective_id, progress)
		return SexpResult.create_boolean(success)
	
	func _get_objective_system():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var event_manager = tree.get_first_node_in_group("mission_event_manager")
			if event_manager and event_manager.has_method("get_objective_system"):
				return event_manager.get_objective_system()
		return null