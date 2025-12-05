extends Node

# Centralized Input Management
# Handles input mapping, device detection, and event dispatching

signal input_device_changed(device_id: int, device_name: String)

func _ready() -> void:
	print("InputManager Initialized")
	_setup_default_mappings()

func _setup_default_mappings() -> void:
	# Define default input actions if not already present in InputMap
	# This ensures the game is playable out of the box
	if not InputMap.has_action("ship_thrust_forward"):
		InputMap.add_action("ship_thrust_forward")
		var key = InputEventKey.new()
		key.keycode = KEY_W
		InputMap.action_add_event("ship_thrust_forward", key)
		
	if not InputMap.has_action("ship_thrust_backward"):
		InputMap.add_action("ship_thrust_backward")
		var key = InputEventKey.new()
		key.keycode = KEY_S
		InputMap.action_add_event("ship_thrust_backward", key)

	if not InputMap.has_action("ship_yaw_left"):
		InputMap.add_action("ship_yaw_left")
		var key = InputEventKey.new()
		key.keycode = KEY_A
		InputMap.action_add_event("ship_yaw_left", key)

	if not InputMap.has_action("ship_yaw_right"):
		InputMap.add_action("ship_yaw_right")
		var key = InputEventKey.new()
		key.keycode = KEY_D
		InputMap.action_add_event("ship_yaw_right", key)
		
	if not InputMap.has_action("ship_pitch_up"):
		InputMap.add_action("ship_pitch_up")
		var key = InputEventKey.new()
		key.keycode = KEY_UP
		InputMap.action_add_event("ship_pitch_up", key)
		
	if not InputMap.has_action("ship_pitch_down"):
		InputMap.add_action("ship_pitch_down")
		var key = InputEventKey.new()
		key.keycode = KEY_DOWN
		InputMap.action_add_event("ship_pitch_down", key)
		
	if not InputMap.has_action("ship_roll_left"):
		InputMap.add_action("ship_roll_left")
		var key = InputEventKey.new()
		key.keycode = KEY_Q
		InputMap.action_add_event("ship_roll_left", key)
		
	if not InputMap.has_action("ship_roll_right"):
		InputMap.add_action("ship_roll_right")
		var key = InputEventKey.new()
		key.keycode = KEY_E
		InputMap.action_add_event("ship_roll_right", key)
		
	if not InputMap.has_action("ship_fire_primary"):
		InputMap.add_action("ship_fire_primary")
		var key = InputEventKey.new()
		key.keycode = KEY_SPACE
		InputMap.action_add_event("ship_fire_primary", key)
		
	if not InputMap.has_action("ship_fire_secondary"):
		InputMap.add_action("ship_fire_secondary")
		var key = InputEventKey.new()
		key.keycode = KEY_CTRL
		InputMap.action_add_event("ship_fire_secondary", key)

func get_thrust_input() -> float:
	return Input.get_axis("ship_thrust_backward", "ship_thrust_forward")

func get_yaw_input() -> float:
	return Input.get_axis("ship_yaw_right", "ship_yaw_left") # Left is positive yaw usually

func get_pitch_input() -> float:
	return Input.get_axis("ship_pitch_down", "ship_pitch_up") # Up is positive pitch usually

func get_roll_input() -> float:
	return Input.get_axis("ship_roll_right", "ship_roll_left") # Left is positive roll usually
