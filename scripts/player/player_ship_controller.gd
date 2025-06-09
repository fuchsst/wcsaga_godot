# scripts/player/player_ship_controller.gd
extends Node
class_name PlayerShipController

## Enhanced player ship controller integrating SHIP-015 flight control systems.
## Provides responsive ship control with configurable assistance and authentic WCS flight feel.

signal control_state_changed(is_active: bool)
signal assistance_toggled(mode: String, enabled: bool)
signal emergency_stop_activated()

# --- Enhanced Component References ---
@onready var ship_base: BaseShip = get_parent() # Assuming this script is a child of the BaseShip node
@onready var input_processor: PlayerInputProcessor
@onready var flight_dynamics: FlightDynamicsController  
@onready var flight_assistance: FlightAssistanceManager

# --- Control State ---
var is_control_active: bool = true
var assistance_enabled: bool = true
var emergency_override: bool = false

# --- Input Processing ---
var input_update_rate: float = 60.0  # Hz
var last_input_update: float = 0.0

func _ready() -> void:
	if not ship_base:
		push_error("PlayerShipController: Parent node is not ShipBase!")
		return
	
	_initialize_control_systems()
	_connect_system_signals()
	
	set_process_input(true)
	set_physics_process(true)
	
	print("PlayerShipController: Enhanced control system initialized")

func _initialize_control_systems() -> void:
	##Initialize enhanced flight control components.##
	
	# Create input processor
	input_processor = PlayerInputProcessor.new()
	input_processor.name = "InputProcessor"
	add_child(input_processor)
	
	# Create flight dynamics controller
	flight_dynamics = FlightDynamicsController.new()
	flight_dynamics.name = "FlightDynamicsController"
	flight_dynamics.physics_body = ship_base as RigidBody3D
	add_child(flight_dynamics)
	
	# Create flight assistance manager
	flight_assistance = FlightAssistanceManager.new()
	flight_assistance.name = "FlightAssistanceManager"
	flight_assistance.flight_dynamics = flight_dynamics
	flight_assistance.physics_body = ship_base as RigidBody3D
	flight_assistance.ship_controller = ship_base
	add_child(flight_assistance)
	
	# Configure default assistance modes
	if assistance_enabled:
		flight_assistance.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.AUTO_LEVEL)
		flight_assistance.enable_assistance_mode(FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE)

func _connect_system_signals() -> void:
	##Connect signals from control system components.##
	
	if input_processor:
		input_processor.input_processed.connect(_on_input_processed)
		input_processor.control_scheme_changed.connect(_on_control_scheme_changed)
	
	if flight_dynamics:
		flight_dynamics.velocity_changed.connect(_on_velocity_changed)
		flight_dynamics.inertia_dampening_changed.connect(_on_inertia_dampening_changed)
	
	if flight_assistance:
		flight_assistance.assistance_mode_changed.connect(_on_assistance_mode_changed)
		flight_assistance.collision_warning.connect(_on_collision_warning)
		flight_assistance.assistance_override_activated.connect(_on_assistance_override)

func _physics_process(delta: float) -> void:
	if not is_control_active or not ship_base or emergency_override:
		return
	
	# Update input processing at configured rate
	var current_time: float = Time.get_ticks_usec() / 1000000.0
	if current_time - last_input_update >= (1.0 / input_update_rate):
		_update_flight_inputs(delta)
		last_input_update = current_time
	
	# Update flight dynamics with processed inputs
	_apply_inputs_to_flight_dynamics()
	
	# Update legacy physics controller if present
	if ship_base.has_method("get_physics_controller") and ship_base.get_physics_controller():
		_update_legacy_physics_controller()

func _update_flight_inputs(delta: float) -> void:
	##Update flight inputs using enhanced input processor.##
	
	if not input_processor:
		return
	
	# Input processor handles all input processing automatically
	# Results are available through get_input_value() calls

func _apply_inputs_to_flight_dynamics() -> void:
	##Apply processed inputs to flight dynamics controller.##
	
	if not flight_dynamics or not input_processor:
		return
	
	# Get processed inputs
	var pitch: float = input_processor.get_input_value("pitch")
	var yaw: float = input_processor.get_input_value("yaw")
	var roll: float = input_processor.get_input_value("roll")
	var throttle: float = input_processor.get_input_value("throttle")
	var strafe_x: float = input_processor.get_input_value("strafe_x")
	var strafe_y: float = input_processor.get_input_value("strafe_y")
	var strafe_z: float = input_processor.get_input_value("strafe_z")
	
	# Apply to flight dynamics
	flight_dynamics.set_angular_input(Vector3(pitch, yaw, roll))
	flight_dynamics.set_throttle_input(throttle)
	flight_dynamics.set_strafe_input(Vector3(strafe_x, strafe_y, strafe_z))

func _update_legacy_physics_controller() -> void:
	##Update legacy physics controller for backward compatibility.##
	
	if not flight_dynamics:
		return
	
	var physics_controller = ship_base.get_physics_controller()
	if physics_controller and physics_controller.has_method("set_angular_input"):
		# Convert enhanced inputs to legacy format
		var angular_input: Vector3 = Vector3(
			flight_dynamics.pitch_input,
			flight_dynamics.yaw_input,
			flight_dynamics.roll_input
		)
		physics_controller.set_angular_input(angular_input)
		
		if physics_controller.has_method("set_throttle"):
			physics_controller.set_throttle(flight_dynamics.throttle_input)

func _unhandled_input(event: InputEvent) -> void:
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
		if ship_base.has_method("get_weapon_system") and ship_base.get_weapon_system():
			ship_base.get_weapon_system().select_next_primary() # Example direct call
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("cycle_secondary"):
		# TODO: Call button_function_critical(CYCLE_SECONDARY) or similar logic
		if ship_base.has_method("get_weapon_system") and ship_base.get_weapon_system():
			ship_base.get_weapon_system().select_next_secondary() # Example direct call
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
		_toggle_assistance_mode("AUTO_LEVEL")
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("collision_avoidance_toggle"):
		_toggle_assistance_mode("COLLISION_AVOIDANCE")
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("velocity_match_toggle"):
		_toggle_assistance_mode("VELOCITY_MATCHING")
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("glide_mode_toggle"):
		_toggle_assistance_mode("GLIDE_MODE")
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("emergency_stop"):
		_trigger_emergency_stop()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("inertia_dampening_toggle"):
		_toggle_inertia_dampening()
		get_viewport().set_input_as_handled()
	
	# TODO: Add handling for other input actions (ETS, Shields, Comms, Views, etc.)

func set_active(active: bool) -> void:
	##Enable or disable player ship control.##
	is_control_active = active
	set_process_input(active)
	set_physics_process(active)
	
	if input_processor:
		input_processor.set_input_processing_enabled(active)
	
	if not active:
		# Clear all inputs when deactivated
		if flight_dynamics:
			flight_dynamics.set_angular_input(Vector3.ZERO)
			flight_dynamics.set_throttle_input(0.0)
			flight_dynamics.set_strafe_input(Vector3.ZERO)
		
		# Reset legacy physics controller
		if ship_base and ship_base.has_method("get_physics_controller") and ship_base.get_physics_controller():
			var physics_controller = ship_base.get_physics_controller()
			if physics_controller.has_method("set_angular_input"):
				physics_controller.set_angular_input(Vector3.ZERO)
	
	control_state_changed.emit(active)

func is_active() -> bool:
	##Check if player ship control is active.##
	return is_control_active

# Flight Assistance Control

func _toggle_assistance_mode(mode_name: String) -> void:
	##Toggle flight assistance mode by name.##
	
	if not flight_assistance:
		return
	
	var mode: FlightAssistanceManager.AssistanceMode
	match mode_name:
		"AUTO_LEVEL":
			mode = FlightAssistanceManager.AssistanceMode.AUTO_LEVEL
		"COLLISION_AVOIDANCE":
			mode = FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE
		"VELOCITY_MATCHING":
			mode = FlightAssistanceManager.AssistanceMode.VELOCITY_MATCHING
		"GLIDE_MODE":
			mode = FlightAssistanceManager.AssistanceMode.GLIDE_MODE
		"FORMATION_ASSIST":
			mode = FlightAssistanceManager.AssistanceMode.FORMATION_ASSIST
		"APPROACH_ASSIST":
			mode = FlightAssistanceManager.AssistanceMode.APPROACH_ASSIST
		"LANDING_ASSIST":
			mode = FlightAssistanceManager.AssistanceMode.LANDING_ASSIST
		_:
			push_warning("PlayerShipController: Unknown assistance mode: %s" % mode_name)
			return
	
	flight_assistance.toggle_assistance_mode(mode)

func _toggle_inertia_dampening() -> void:
	##Toggle inertia dampening on/off.##
	
	if not flight_dynamics:
		return
	
	var enabled: bool = flight_dynamics.is_inertia_dampening_enabled()
	flight_dynamics.set_inertia_dampening(not enabled)

func _trigger_emergency_stop() -> void:
	##Trigger emergency stop procedure.##
	
	emergency_override = true
	
	if flight_dynamics:
		flight_dynamics.emergency_stop()
	
	emergency_stop_activated.emit()
	print("PlayerShipController: Emergency stop activated")
	
	# Clear emergency override after short delay
	await get_tree().create_timer(0.5).timeout
	emergency_override = false

# Configuration and Settings

func configure_input_sensitivity(control_type: String, sensitivity: float) -> void:
	##Configure input sensitivity for specific control type.##
	
	if input_processor:
		input_processor.set_sensitivity(control_type, sensitivity)

func configure_assistance_strength(mode_name: String, strength: float) -> void:
	##Configure assistance strength for specific mode.##
	
	if not flight_assistance:
		return
	
	match mode_name:
		"AUTO_LEVEL":
			flight_assistance.set_auto_level_strength(strength)
		"COLLISION_AVOIDANCE":
			flight_assistance.set_collision_avoidance_range(strength * 1000.0)  # Scale to range
		_:
			push_warning("PlayerShipController: Unknown assistance mode for configuration: %s" % mode_name)

func get_control_performance_stats() -> Dictionary:
	##Get comprehensive control system performance statistics.##
	
	var stats: Dictionary = {
		"control_active": is_control_active,
		"assistance_enabled": assistance_enabled,
		"emergency_override": emergency_override,
		"input_update_rate": input_update_rate
	}
	
	if input_processor:
		stats["input_processor"] = input_processor.get_performance_stats()
	
	if flight_dynamics:
		stats["flight_dynamics"] = flight_dynamics.get_performance_stats()
	
	if flight_assistance:
		stats["flight_assistance"] = flight_assistance.get_performance_stats()
	
	return stats

# Signal Handlers

func _on_input_processed(control_type: String, value: float, delta_time: float) -> void:
	##Handle processed input from input processor.##
	# Input is automatically applied in _apply_inputs_to_flight_dynamics
	pass

func _on_control_scheme_changed(new_scheme: InputManager.ControlScheme) -> void:
	##Handle control scheme changes.##
	print("PlayerShipController: Control scheme changed to %s" % InputManager.ControlScheme.keys()[new_scheme])

func _on_velocity_changed(velocity: Vector3) -> void:
	##Handle velocity changes from flight dynamics.##
	# Could be used for audio feedback, HUD updates, etc.
	pass

func _on_inertia_dampening_changed(enabled: bool, factor: float) -> void:
	##Handle inertia dampening state changes.##
	print("PlayerShipController: Inertia dampening %s (factor: %.2f)" % ["enabled" if enabled else "disabled", factor])

func _on_assistance_mode_changed(mode: FlightAssistanceManager.AssistanceMode, enabled: bool) -> void:
	##Handle assistance mode changes.##
	var mode_name: String = FlightAssistanceManager.AssistanceMode.keys()[mode]
	print("PlayerShipController: %s assistance %s" % [mode_name, "enabled" if enabled else "disabled"])
	assistance_toggled.emit(mode_name, enabled)

func _on_collision_warning(threat_object: Node3D, distance: float, severity: float) -> void:
	##Handle collision warnings from assistance system.##
	# Could trigger HUD warnings, audio alerts, etc.
	if severity > 0.7:
		print("PlayerShipController: High collision threat detected at %.1fm" % distance)

func _on_assistance_override(reason: String) -> void:
	##Handle assistance system override of player input.##
	print("PlayerShipController: Assistance override activated - %s" % reason)

# Public API

func get_current_velocity() -> Vector3:
	##Get current ship velocity.##
	if flight_dynamics:
		return flight_dynamics.get_current_velocity()
	return Vector3.ZERO

func get_current_speed() -> float:
	##Get current ship speed.##
	if flight_dynamics:
		return flight_dynamics.get_current_speed()
	return 0.0

func get_thrust_percentage() -> float:
	##Get current thrust as percentage.##
	if flight_dynamics:
		return flight_dynamics.get_thrust_percentage()
	return 0.0

func is_assistance_mode_active(mode_name: String) -> bool:
	##Check if specific assistance mode is active.##
	
	if not flight_assistance:
		return false
	
	var mode: FlightAssistanceManager.AssistanceMode
	match mode_name:
		"AUTO_LEVEL":
			mode = FlightAssistanceManager.AssistanceMode.AUTO_LEVEL
		"COLLISION_AVOIDANCE":
			mode = FlightAssistanceManager.AssistanceMode.COLLISION_AVOIDANCE
		"VELOCITY_MATCHING":
			mode = FlightAssistanceManager.AssistanceMode.VELOCITY_MATCHING
		"GLIDE_MODE":
			mode = FlightAssistanceManager.AssistanceMode.GLIDE_MODE
		_:
			return false
	
	return flight_assistance.is_assistance_mode_active(mode)

func set_assistance_enabled(enabled: bool) -> void:
	##Enable or disable flight assistance system.##
	assistance_enabled = enabled
	
	if not enabled and flight_assistance:
		# Disable all assistance modes
		for mode in FlightAssistanceManager.AssistanceMode.values():
			flight_assistance.disable_assistance_mode(mode)