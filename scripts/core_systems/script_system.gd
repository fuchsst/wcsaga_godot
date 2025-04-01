# script_system.gd
# Autoload Singleton responsible for managing the overall scripting hook system.
# It holds the ScriptState, connects to game signals, and triggers hook checks.
extends Node

# Import dependencies
const ScriptState = preload("res://scripts/scripting/hook_system/script_state.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd")

# --- State ---
var _script_state: ScriptState = ScriptState.new()

# --- Godot Lifecycle ---
func _ready() -> void:
	print("ScriptSystem Initialized.")
	# TODO: Connect to relevant global signals here
	# Example: GameManager.game_state_changed.connect(_on_game_state_changed)
	# Example: GameManager.mission_started.connect(_on_mission_started)
	# Example: GameManager.mission_ended.connect(_on_mission_ended)
	# Example: get_tree().process_frame.connect(_on_process_frame) # If needed for CHA_ONFRAME
	# Example: Input.input_event.connect(_on_input_event) # For key/mouse press/release

	# Connect to MissionManager signals (assuming it exists and emits these)
	if Engine.has_singleton("MissionManager"):
		var mission_manager = Engine.get_singleton("MissionManager")
		if mission_manager.has_signal("mission_started"):
			mission_manager.mission_started.connect(_on_mission_started)
		else:
			push_warning("ScriptSystem: MissionManager does not have signal 'mission_started'.")
		if mission_manager.has_signal("mission_ended"):
			mission_manager.mission_ended.connect(_on_mission_ended)
		else:
			push_warning("ScriptSystem: MissionManager does not have signal 'mission_ended'.")
	else:
		push_warning("ScriptSystem: MissionManager Autoload not found for signal connection.")

	# TODO: Connect to other signals (GameState changes, Ship events, Input, etc.)

	# Placeholder: Load hook data (replace with actual loading later)
	_script_state.load_hooks_from_data(null)


# --- Public API ---

## Returns the managed ScriptState instance.
func get_script_state() -> ScriptState:
	return _script_state

## Loads hook definitions from data (e.g., parsed from tables).
func load_script_hooks(hook_data) -> void:
	_script_state.load_hooks_from_data(hook_data)


# --- Signal Handlers (Placeholders) ---
# These functions will be connected to signals emitted by other game systems.

func _on_game_state_changed(new_state_id: int, old_state_id: int) -> void:
	var context_start = {"current_state_id": new_state_id, "previous_state_id": old_state_id}
	var context_end = {"current_state_id": old_state_id, "next_state_id": new_state_id} # Context for the ending state

	# Trigger hooks for the state that just ended
	if old_state_id != GlobalConstants.GameState.NONE:
		_script_state.run_condition(GlobalConstants.HookActionType.ONSTATEEND, context_end)

	# Trigger hooks for the state that is starting
	_script_state.run_condition(GlobalConstants.HookActionType.ONSTATESTART, context_start)


func _on_mission_started(mission_name: String, campaign_name: String) -> void:
	# Clear mission-specific SEXP variables
	if Engine.has_singleton("SexpVariableManager"):
		Engine.get_singleton("SexpVariableManager").clear_mission_variables()

	# TODO: Load mission-specific hooks if necessary, or ensure global hooks are loaded
	# _script_state.load_hooks_from_data(...)

	var context = {"mission_name": mission_name, "campaign_name": campaign_name}
	_script_state.run_condition(GlobalConstants.HookActionType.MISSIONSTART, context)


func _on_mission_ended(mission_name: String, campaign_name: String) -> void:
	var context = {"mission_name": mission_name, "campaign_name": campaign_name}
	_script_state.run_condition(GlobalConstants.HookActionType.MISSIONEND, context)
	# Optionally clear mission hooks here if they were loaded specifically for the mission
	# _script_state.clear_all_hooks()


func _on_process_frame(delta: float) -> void:
	# This could potentially be called very often. Ensure performance is acceptable.
	# Consider if a different signal or timer is more appropriate for frame-based hooks.
	var context = {"delta": delta}
	# Add other relevant frame context if needed (e.g., current game time)
	# context["mission_time"] = GameManager.get_mission_time()
	_script_state.run_condition(GlobalConstants.HookActionType.ONFRAME, context)


func _on_input_event(event: InputEvent) -> void:
	var context = {"event": event}
	if event is InputEventKey:
		if event.is_pressed() and not event.is_echo():
			context["key_event"] = event # Add specific key event for easier access
			_script_state.run_condition(GlobalConstants.HookActionType.KEYPRESSED, context)
		elif not event.is_pressed():
			context["key_event"] = event
			_script_state.run_condition(GlobalConstants.HookActionType.KEYRELEASED, context)
	elif event is InputEventMouseButton:
		if event.is_pressed():
			context["mouse_button_event"] = event
			_script_state.run_condition(GlobalConstants.HookActionType.MOUSEPRESSED, context)
		else:
			context["mouse_button_event"] = event
			_script_state.run_condition(GlobalConstants.HookActionType.MOUSERELEASED, context)
	elif event is InputEventMouseMotion:
		context["mouse_motion_event"] = event
		_script_state.run_condition(GlobalConstants.HookActionType.MOUSEMOVED, context)


func _on_ship_died(ship_node, killer_node = null) -> void:
	var context = {"ship_node": ship_node, "killer_node": killer_node}
	# Add more context if needed (e.g., ship name, class)
	# context["ship_name"] = ship_node.get_ship_name() if is_instance_valid(ship_node) else ""
	_script_state.run_condition(GlobalConstants.HookActionType.DEATH, context)


func _on_ship_warpin_complete(ship_node) -> void:
	var context = {"ship_node": ship_node}
	_script_state.run_condition(GlobalConstants.HookActionType.WARPIN, context)


func _on_ship_warpout_started(ship_node) -> void:
	var context = {"ship_node": ship_node}
	_script_state.run_condition(GlobalConstants.HookActionType.WARPOUT, context)


func _on_hud_draw() -> void:
	# Called from HUD script's _draw() or _process()
	var context = {} # Add HUD specific context if needed
	_script_state.run_condition(GlobalConstants.HookActionType.HUDDRAW, context)


func _on_object_render(object_node) -> void:
	# Called from BaseObject's _process or a dedicated render callback?
	# Performance sensitive!
	var context = {"object_node": object_node}
	_script_state.run_condition(GlobalConstants.HookActionType.OBJECTRENDER, context)


func _on_collision(collider, collided_with, collision_point, collision_normal) -> void:
	# This needs a more robust collision handling system.
	# A central system should detect collisions and emit signals with context.
	var context = {
		"collider": collider,
		"collided_with": collided_with,
		"collision_point": collision_point,
		"collision_normal": collision_normal
	}
	var action_type = GlobalConstants.HookActionType.NONE

	# Determine action type based on collider/collided_with types
	# Example:
	# if collider is ShipBase and collided_with is ShipBase:
	#	 action_type = GlobalConstants.HookActionType.COLLIDESHIP
	# elif collider is ShipBase and collided_with is WeaponProjectile:
	#	 action_type = GlobalConstants.HookActionType.COLLIDEWEAPON # Or COLLIDESHIP?
	# ... etc.

	if action_type != GlobalConstants.HookActionType.NONE:
		_script_state.run_condition(action_type, context)

# --- Override Check ---
## Convenience function to check for overrides from other systems.
func check_override(action_type: GlobalConstants.HookActionType, context: Dictionary) -> bool:
	return _script_state.is_condition_override(action_type, context)
