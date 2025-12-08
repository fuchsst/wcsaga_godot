class_name PlayerShipController
extends Node

# Player Ship Controller
# Bridges InputManager (Layer 2) and ShipEntity (Layer 4)
# Translates user input into ship control commands

@export var ship: ShipEntity

# Input sensitivity curves could go here
@export var pitch_sensitivity: float = 1.0
@export var yaw_sensitivity: float = 1.0
@export var roll_sensitivity: float = 1.0

# State tracking for toggle inputs
var _was_afterburner_pressed: bool = false


func _ready() -> void:
	if not ship:
		# Try to find parent ship if not assigned
		var parent = get_parent()
		if parent is ShipEntity:
			ship = parent

	if not ship:
		push_warning("PlayerShipController: No ShipEntity assigned!")
		set_physics_process(false)
		return

	print("PlayerShipController initialized for: " + ship.name)


func _physics_process(delta: float) -> void:
	if not ship or not ship.is_alive():
		return

	_handle_flight_controls(delta)
	_handle_weapons(delta)
	_handle_systems(delta)


func _handle_flight_controls(_delta: float) -> void:
	# Get raw axis inputs from InputManager
	# These are typically -1.0 to 1.0
	var pitch = InputManager.get_pitch_input()
	var yaw = InputManager.get_yaw_input()
	var roll = InputManager.get_roll_input()
	var thrust = InputManager.get_thrust_input()

	# Apply sensitivity curves (linear for now)
	pitch *= pitch_sensitivity
	yaw *= yaw_sensitivity
	roll *= roll_sensitivity

	# Throttle Logic
	# WCS often uses a set throttle + temporary thrust override
	# For now, we'll map forward/back directly to the "forward" control input
	# which WCSPhysicsBody interprets as desired velocity fraction or acceleration

	# Pass inputs to ShipEntity (WCSPhysicsBody)
	# set_control_input(pitch, yaw, roll, forward, sideways, vertical)
	# Sideways (Slide/Strafe) and Vertical not mapped yet in InputManager default
	ship.set_control_input(pitch, yaw, roll, thrust, 0.0, 0.0)


func _handle_weapons(_delta: float) -> void:
	# Primary Fire
	if Input.is_action_pressed("ship_fire_primary"):
		ship.fire_weapon(0)
	elif Input.is_action_just_released("ship_fire_primary"):
		ship.stop_firing_weapon(0)

	# Secondary Fire
	if Input.is_action_pressed("ship_fire_secondary"):
		ship.fire_weapon(1)
	elif Input.is_action_just_released("ship_fire_secondary"):
		ship.stop_firing_weapon(1)


func _handle_systems(_delta: float) -> void:
	# Afterburner (Hold to boost)
	# Assuming Shift/Tab is mapped to 'ship_afterburner' in InputMap
	# We added 'ship_afterburner' (TAB) to InputManager default mappings explicitly.
	if Input.is_action_pressed("ship_afterburner"):
		if not _was_afterburner_pressed:
			ship.set_afterburner_enabled(true)
			_was_afterburner_pressed = true
	else:
		if _was_afterburner_pressed:
			ship.set_afterburner_enabled(false)
			_was_afterburner_pressed = false

	# Match speed / other systems can be added here
