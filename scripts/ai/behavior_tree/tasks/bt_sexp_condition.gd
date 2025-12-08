@tool
extends BTCondition
class_name BTSexpCondition

## Evaluates a SEXP condition operator at runtime
## Uses MissionManager and entity state to determine truth value

## The SEXP operator ID (e.g. "is-destroyed", "has-arrived")
@export var operator_id: String = ""

## Arguments for the operator (can be literals or SexpNode references)
@export var arguments: Array = []


func _get_mission_manager() -> Node:
	"""Get MissionManager autoload safely for @tool scripts"""
	if Engine.is_editor_hint():
		return null
	return (
		Engine.get_singleton("MissionManager") if Engine.has_singleton("MissionManager") else null
	)


func _tick(_delta: float) -> Status:
	match operator_id:
		# Boolean atoms
		"true":
			return SUCCESS
		"false":
			return FAILURE

		# Ship state conditions
		"is-destroyed":
			return _check_is_destroyed()
		"has-arrived":
			return _check_has_arrived()
		"has-arrived-delay":
			return _check_has_arrived_delay()
		"has-departed":
			return _check_has_departed()
		"is-disabled":
			return _check_is_disabled()
		"is-disarmed":
			return _check_is_disarmed()

		# Event/goal conditions
		"is-event-true", "is-event-true-delay":
			return _check_event_status(true)
		"is-event-false", "is-event-false-delay":
			return _check_event_status(false)

		# Comparisons
		"=":
			return _check_equals()
		"<":
			return _check_less_than()
		">":
			return _check_greater_than()

		# Time conditions
		"time-elapsed":
			return _check_time_elapsed()

		# Numeric queries (return success for now - should integrate with ship queries)
		"hits-left", "shields-left", "distance", "speed":
			return _check_numeric_condition()

		_:
			# Unknown operator - log and return success to not block
			push_warning("BTSexpCondition: Unknown operator: " + operator_id)
			return SUCCESS


func _generate_name() -> String:
	if arguments.size() > 0:
		return operator_id + " (" + str(_get_arg(0)) + ")"
	return operator_id


# === CONDITION IMPLEMENTATIONS ===


func _check_is_destroyed() -> Status:
	var ship_name = _get_arg(0)
	if ship_name.is_empty():
		return FAILURE

	var mm = _get_mission_manager()
	if mm and mm.is_entity_destroyed(ship_name):
		return SUCCESS
	return FAILURE


func _check_has_arrived() -> Status:
	var ship_name = _get_arg(0)
	if ship_name.is_empty():
		return FAILURE

	var mm = _get_mission_manager()
	if mm and mm.is_entity_arrived(ship_name):
		return SUCCESS
	return FAILURE


func _check_has_arrived_delay() -> Status:
	var ship_name = _get_arg(0)
	var _delay = _get_arg_float(1, 0.0)

	if ship_name.is_empty():
		return FAILURE

	var mm = _get_mission_manager()
	if mm and mm.is_entity_arrived(ship_name):
		# TODO: Check delay since arrival
		return SUCCESS
	return FAILURE


func _check_has_departed() -> Status:
	var ship_name = _get_arg(0)
	if ship_name.is_empty():
		return FAILURE

	# Check if entity arrived previously but no longer exists
	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		# If we had it but it's gone (and not destroyed), it departed
		if entity == null and mm.entity_registry.has(ship_name):
			return SUCCESS
	return FAILURE


func _check_is_disabled() -> Status:
	var ship_name = _get_arg(0)
	if ship_name.is_empty():
		return FAILURE

	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity and entity.has_method("is_disabled") and entity.is_disabled():
			return SUCCESS
	return FAILURE


func _check_is_disarmed() -> Status:
	var ship_name = _get_arg(0)
	if ship_name.is_empty():
		return FAILURE

	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity and entity.has_method("is_disarmed") and entity.is_disarmed():
			return SUCCESS
	return FAILURE


func _check_event_status(expect_true: bool) -> Status:
	var event_name = _get_arg(0)
	if event_name.is_empty():
		return FAILURE

	var mm = _get_mission_manager()
	if mm:
		var fire_count = mm.get_event_fire_count(event_name)
		if expect_true and fire_count > 0:
			return SUCCESS
		elif not expect_true and fire_count == 0:
			return SUCCESS
	return FAILURE


func _check_equals() -> Status:
	var left = _get_arg(0)
	var right = _get_arg(1)
	if str(left) == str(right):
		return SUCCESS
	return FAILURE


func _check_less_than() -> Status:
	var left = _get_arg_float(0, 0.0)
	var right = _get_arg_float(1, 0.0)
	if left < right:
		return SUCCESS
	return FAILURE


func _check_greater_than() -> Status:
	var left = _get_arg_float(0, 0.0)
	var right = _get_arg_float(1, 0.0)
	if left > right:
		return SUCCESS
	return FAILURE


func _check_time_elapsed() -> Status:
	var seconds = _get_arg_float(0, 0.0)
	var mm = _get_mission_manager()
	if mm and mm.mission_time >= seconds:
		return SUCCESS
	return FAILURE


func _check_numeric_condition() -> Status:
	# Placeholder for numeric conditions that need entity queries
	# For now, delegate to blackboard if we have values there
	return SUCCESS


# === ARGUMENT HELPERS ===


func _get_arg(index: int) -> Variant:
	if index < arguments.size():
		var arg = arguments[index]
		# If it's a SexpNode, extract value
		if arg is Resource and "value" in arg:
			return arg.value
		return arg
	return ""


func _get_arg_float(index: int, default: float = 0.0) -> float:
	var val = _get_arg(index)
	if val is float or val is int:
		return float(val)
	if val is String and val.is_valid_float():
		return val.to_float()
	return default
