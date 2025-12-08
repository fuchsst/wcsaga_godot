@tool
extends BTAction
class_name BTSexpAction

## Executes a SEXP action operator at runtime
## Uses MissionManager to affect mission state

## The SEXP operator ID (e.g. "send-message", "add-goal")
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
		# No-op
		"do-nothing":
			return SUCCESS

		# Mission control
		"end-mission":
			return _action_end_mission()
		"next-mission":
			return _action_next_mission()
		"end-campaign", "end-of-campaign":
			return _action_end_campaign()

		# Messages
		"send-message":
			return _action_send_message()
		"training-msg":
			return _action_training_message()

		# Goal management
		"add-goal", "add-ship-goal":
			return _action_add_goal()
		"add-wing-goal":
			return _action_add_wing_goal()
		"clear-goals", "clear-ship-goals":
			return _action_clear_goals()
		"validate-goal":
			return _action_validate_goal()
		"invalidate-goal":
			return _action_invalidate_goal()

		# Ship state manipulation
		"make-invulnerable", "ship-invulnerable":
			return _action_set_invulnerable(true)
		"make-vulnerable", "ship-vulnerable":
			return _action_set_invulnerable(false)
		"protect-ship":
			return _action_protect_ship(true)
		"unprotect-ship":
			return _action_protect_ship(false)
		"shields-on":
			return _action_shields(true)
		"shields-off":
			return _action_shields(false)
		"ship-stealthy":
			return _action_stealth(true)
		"ship-unstealthy":
			return _action_stealth(false)

		# Variables
		"set-variable":
			return _action_set_variable()
		"modify-variable":
			return _action_modify_variable()

		# Spawn/despawn
		"warp-in":
			return _action_warp_in()
		"warp-out":
			return _action_warp_out()
		"ship-vanish":
			return _action_ship_vanish()

		# Audio/Music
		"change-music":
			return _action_change_music()

		# Scoring
		"grant-promotion":
			return _action_grant_promotion()
		"grant-medal":
			return _action_grant_medal()

		_:
			# Unknown operator - log but succeed
			push_warning("BTSexpAction: Unknown operator: " + operator_id)
			return SUCCESS


func _generate_name() -> String:
	if arguments.size() > 0:
		return operator_id + " (" + str(_get_arg(0)) + ")"
	return operator_id


# === ACTION IMPLEMENTATIONS ===


func _action_end_mission() -> Status:
	var success = _get_arg(0) != "false"
	var mm = _get_mission_manager()
	if mm:
		mm.end_mission(success)
	return SUCCESS


func _action_next_mission() -> Status:
	var mission_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		mm.set_variable("next_mission", mission_name)
	return SUCCESS


func _action_end_campaign() -> Status:
	var mm = _get_mission_manager()
	if mm:
		mm.set_variable("campaign_complete", true)
		mm.end_mission(true)
	return SUCCESS


func _action_send_message() -> Status:
	var sender = _get_arg(0)
	var _priority = _get_arg(1)
	var message_name = _get_arg(2)

	# TODO: Route to message display system
	print("[MESSAGE] " + str(sender) + ": " + str(message_name))
	return SUCCESS


func _action_training_message() -> Status:
	var message = _get_arg(0)
	# TODO: Display training message
	print("[TRAINING] " + str(message))
	return SUCCESS


func _action_add_goal() -> Status:
	var ship_name = _get_arg(0)
	var goal_type = _get_arg(1)
	var priority = _get_arg_int(2, 50)

	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity:
			var ai_controller = entity.get_node_or_null("AIController")
			if ai_controller and ai_controller.has_method("add_goal"):
				ai_controller.add_goal(goal_type, "", priority)
	return SUCCESS


func _action_add_wing_goal() -> Status:
	var wing_name = _get_arg(0)
	var goal_type = _get_arg(1)
	var priority = _get_arg_int(2, 50)

	var mm = _get_mission_manager()
	if mm:
		var entities = mm.get_wing_entities(wing_name)
		for entity in entities:
			var ai_controller = entity.get_node_or_null("AIController")
			if ai_controller and ai_controller.has_method("add_goal"):
				ai_controller.add_goal(goal_type, "", priority)
	return SUCCESS


func _action_clear_goals() -> Status:
	var ship_name = _get_arg(0)

	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity:
			var ai_controller = entity.get_node_or_null("AIController")
			if ai_controller and ai_controller.has_method("clear_goals"):
				ai_controller.clear_goals()
	return SUCCESS


func _action_validate_goal() -> Status:
	var goal_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		mm.set_goal_status(goal_name, 1)  # Complete
	return SUCCESS


func _action_invalidate_goal() -> Status:
	var goal_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		mm.set_goal_status(goal_name, 2)  # Failed
	return SUCCESS


func _action_set_invulnerable(invulnerable: bool) -> Status:
	var ship_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity and "invulnerable" in entity:
			entity.invulnerable = invulnerable
	return SUCCESS


func _action_protect_ship(protect: bool) -> Status:
	var ship_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity and "protected" in entity:
			entity.protected = protect
	return SUCCESS


func _action_shields(enabled: bool) -> Status:
	var ship_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity and "shields_enabled" in entity:
			entity.shields_enabled = enabled
	return SUCCESS


func _action_stealth(stealthy: bool) -> Status:
	var ship_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity and "stealthy" in entity:
			entity.stealthy = stealthy
	return SUCCESS


func _action_set_variable() -> Status:
	var var_name = _get_arg(0)
	var value = _get_arg(1)
	var mm = _get_mission_manager()
	if mm:
		mm.set_variable(var_name, value)
	return SUCCESS


func _action_modify_variable() -> Status:
	var var_name = _get_arg(0)
	var delta = _get_arg_float(1, 0.0)
	var mm = _get_mission_manager()
	if mm:
		var current = mm.get_variable(var_name, 0.0)
		if current is float or current is int:
			mm.set_variable(var_name, float(current) + delta)
	return SUCCESS


func _action_warp_in() -> Status:
	var ship_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm and mm.current_mission:
		for obj in mm.current_mission.objects:
			if obj.object_name == ship_name:
				mm.spawn_entity(obj)
				break
	return SUCCESS


func _action_warp_out() -> Status:
	var ship_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity and entity.has_method("warp_out"):
			entity.warp_out()
		elif entity:
			entity.queue_free()
	return SUCCESS


func _action_ship_vanish() -> Status:
	var ship_name = _get_arg(0)
	var mm = _get_mission_manager()
	if mm:
		var entity = mm.get_entity(ship_name)
		if entity:
			entity.queue_free()
	return SUCCESS


func _action_change_music() -> Status:
	var _music_type = _get_arg(0)
	# TODO: Route to AudioManager
	return SUCCESS


func _action_grant_promotion() -> Status:
	# TODO: Route to ProfileManager
	return SUCCESS


func _action_grant_medal() -> Status:
	var _medal_name = _get_arg(0)
	# TODO: Route to ProfileManager
	return SUCCESS


# === ARGUMENT HELPERS ===


func _get_arg(index: int) -> Variant:
	if index < arguments.size():
		var arg = arguments[index]
		if arg is Resource and "value" in arg:
			return arg.value
		return arg
	return ""


func _get_arg_int(index: int, default: int = 0) -> int:
	var val = _get_arg(index)
	if val is int:
		return val
	if val is float:
		return int(val)
	if val is String and val.is_valid_int():
		return val.to_int()
	return default


func _get_arg_float(index: int, default: float = 0.0) -> float:
	var val = _get_arg(index)
	if val is float or val is int:
		return float(val)
	if val is String and val.is_valid_float():
		return val.to_float()
	return default
