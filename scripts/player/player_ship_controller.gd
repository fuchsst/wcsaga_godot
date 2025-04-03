# scripts/player/player_ship_controller.gd
extends Node
class_name PlayerShipController

## Handles player input and translates it into ship movement and actions.
## This node/script is typically enabled when the player has direct control.

# --- Node References ---
@onready var ship_base: ShipBase = get_parent() # Assuming this script is a child of the ShipBase node

# --- Input State ---
var _pitch_input: float = 0.0
var _yaw_input: float = 0.0
var _roll_input: float = 0.0
var _throttle_input: float = 0.0 # Represents the desired throttle percentage (0.0 to 1.0)

# --- Parameters ---
# TODO: Expose sensitivity/deadzone parameters if needed, or rely on InputMap settings

func _ready():
	if not ship_base:
		printerr("PlayerShipController: Parent node is not ShipBase!")
	# Initialize throttle based on ship's current state? Or default to 0?
	# _throttle_input = ship_base.get_current_throttle_percentage() # Example
	set_process_input(true)
	set_physics_process(true)


func _physics_process(delta: float):
	if not ship_base or not ship_base.physics_controller:
		return

	# --- Read Movement Inputs ---
	_pitch_input = Input.get_axis("pitch_down", "pitch_up")
	_yaw_input = Input.get_axis("yaw_left", "yaw_right")
	_roll_input = Input.get_axis("roll_left", "roll_right")

	# --- Read Throttle Inputs ---
	# Direct throttle setting (example, needs refinement based on desired control scheme)
	# Could use Input.get_axis for analog throttle if available
	var throttle_adjust = Input.get_axis("throttle_decrease", "throttle_increase")
	if throttle_adjust != 0.0:
		# Adjust throttle based on input - needs scaling and clamping
		# Example: _throttle_input = clamp(_throttle_input + throttle_adjust * delta * THROTTLE_SENSITIVITY, 0.0, 1.0)
		pass # Placeholder for throttle adjustment logic

	# --- Apply Inputs to Physics Controller ---
	# This depends heavily on the PhysicsController implementation
	ship_base.physics_controller.set_angular_input(Vector3(_pitch_input, _yaw_input, _roll_input))
	# ship_base.physics_controller.set_throttle(_throttle_input) # Example


func _unhandled_input(event: InputEvent):
	if not ship_base:
		return

	# --- Handle Action Inputs (Buttons/Keys) ---
	if event.is_action_pressed("fire_primary"):
		ship_base.fire_primary_weapons()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("fire_secondary"):
		ship_base.fire_secondary_weapons()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("cycle_primary"):
		# TODO: Call button_function_critical(CYCLE_NEXT_PRIMARY) or similar logic
		# Need to integrate with the button_info system or call directly
		ship_base.weapon_system.select_next_primary() # Example direct call
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("cycle_secondary"):
		# TODO: Call button_function_critical(CYCLE_SECONDARY) or similar logic
		ship_base.weapon_system.select_next_secondary() # Example direct call
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("target_next"):
		# TODO: Call hud_target_next() or integrate with targeting system
		print("Target Next Pressed") # Placeholder
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("target_prev"):
		# TODO: Call hud_target_prev()
		print("Target Prev Pressed") # Placeholder
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("target_closest_hostile"):
		# TODO: Call hud_target_next_list()
		print("Target Closest Hostile Pressed") # Placeholder
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("target_in_reticle"):
		# TODO: Call hud_target_in_reticle_new()
		print("Target In Reticle Pressed") # Placeholder
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("launch_countermeasure"):
		# TODO: Call ship_launch_countermeasure()
		print("Launch Countermeasure Pressed") # Placeholder
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("match_speed"):
		# TODO: Call player_match_target_speed()
		print("Match Speed Pressed") # Placeholder
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("autopilot_toggle"):
		if AutopilotManager: # Check if AutopilotManager Singleton exists
			AutopilotManager.toggle_autopilot()
		else:
			printerr("AutopilotManager not found!")
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("nav_cycle"):
		if AutopilotManager:
			if not AutopilotManager.select_next_nav():
				# TODO: Play failure sound (gamesnd_play_iface(SND_GENERAL_FAIL))
				pass
		else:
			printerr("AutopilotManager not found!")
		get_viewport().set_input_as_handled()

	# TODO: Add handling for other input actions (ETS, Shields, Comms, Views, etc.)


func set_active(active: bool):
	set_process_input(active)
	set_physics_process(active)
	if not active:
		# Reset inputs when deactivated
		_pitch_input = 0.0
		_yaw_input = 0.0
		_roll_input = 0.0
		# Reset physics controller inputs as well
		if ship_base and ship_base.physics_controller:
			ship_base.physics_controller.set_angular_input(Vector3.ZERO)
			# ship_base.physics_controller.set_throttle(0.0) # Or current throttle?
