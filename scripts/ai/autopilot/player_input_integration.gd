class_name PlayerInputIntegration
extends Node

## Manages seamless transitions between player control and autopilot
## Handles input override, control blending, and smooth handoffs

signal control_taken_by_player()
signal control_returned_to_autopilot()
signal input_conflict_detected(input_type: String)
signal control_handoff_completed(from_mode: String, to_mode: String)

enum ControlMode {
	PLAYER_MANUAL,          # Full player control
	AUTOPILOT_ENGAGED,      # Full autopilot control
	BLENDED_CONTROL,        # Mixed player/autopilot control
	TRANSITION_TO_PLAYER,   # Transitioning from autopilot to player
	TRANSITION_TO_AUTOPILOT # Transitioning from player to autopilot
}

# Input monitoring settings
@export var input_sensitivity_threshold: float = 0.1
@export var control_override_timeout: float = 0.5
@export var smooth_transition_duration: float = 1.0
@export var input_monitoring_enabled: bool = true

# System references
var autopilot_manager: AutopilotManager
var player_ship: Node3D
var input_manager: Node
var ship_controller: Node

# Control state
var current_control_mode: ControlMode = ControlMode.PLAYER_MANUAL
var transition_start_time: float = 0.0
var last_player_input_time: float = 0.0
var pending_handoff: bool = false

# Input monitoring
var monitored_inputs: Array[String] = [
	"ship_thrust_forward",
	"ship_thrust_backward", 
	"ship_turn_left",
	"ship_turn_right",
	"ship_turn_up",
	"ship_turn_down",
	"ship_roll_left",
	"ship_roll_right"
]

var input_deadzone: float = 0.05
var input_states: Dictionary = {}
var input_history: Array[Dictionary] = []
var max_history_length: int = 60  # 1 second at 60 FPS

# Control blending parameters
var player_control_weight: float = 1.0
var autopilot_control_weight: float = 0.0
var blending_enabled: bool = false

# Override detection
var override_threshold_translation: float = 5.0  # Minimum movement delta
var override_threshold_rotation: float = 0.1     # Minimum rotation delta in radians
var consecutive_override_frames: int = 0
var override_frame_threshold: int = 5

func _ready() -> void:
	_initialize_input_integration()
	set_process(true)

func _process(delta: float) -> void:
	if not input_monitoring_enabled:
		return
	
	_monitor_player_input(delta)
	_update_control_transitions(delta)
	_update_control_blending(delta)
	_detect_input_overrides(delta)

# Public interface

func initialize_with_autopilot(autopilot: AutopilotManager) -> void:
	"""Initialize integration with autopilot manager"""
	autopilot_manager = autopilot
	player_ship = autopilot.player_ship
	
	# Connect autopilot signals
	if autopilot_manager:
		autopilot_manager.autopilot_engaged.connect(_on_autopilot_engaged)
		autopilot_manager.autopilot_disengaged.connect(_on_autopilot_disengaged)
		autopilot_manager.control_handoff_requested.connect(_on_control_handoff_requested)

func request_player_control_override() -> bool:
	"""Request immediate player control override of autopilot"""
	if current_control_mode == ControlMode.PLAYER_MANUAL:
		return true
	
	if autopilot_manager and autopilot_manager.is_autopilot_engaged():
		autopilot_manager.disengage_autopilot(AutopilotManager.DisengagementReason.MANUAL_REQUEST)
		return _transition_to_player_control()
	
	return false

func request_autopilot_engagement() -> bool:
	"""Request transition to autopilot control"""
	if current_control_mode == ControlMode.AUTOPILOT_ENGAGED:
		return true
	
	return _transition_to_autopilot_control()

func enable_blended_control(enable: bool = true) -> void:
	"""Enable/disable blended control mode"""
	blended_control = enable
	if enable and current_control_mode == ControlMode.PLAYER_MANUAL:
		_set_control_mode(ControlMode.BLENDED_CONTROL)

func set_control_blending_weights(player_weight: float, autopilot_weight: float) -> void:
	"""Set control blending weights (should sum to 1.0)"""
	var total_weight: float = player_weight + autopilot_weight
	if total_weight > 0:
		player_control_weight = player_weight / total_weight
		autopilot_control_weight = autopilot_weight / total_weight
	else:
		player_control_weight = 1.0
		autopilot_control_weight = 0.0

func get_control_status() -> Dictionary:
	"""Get current control integration status"""
	return {
		"control_mode": ControlMode.keys()[current_control_mode],
		"player_control_weight": player_control_weight,
		"autopilot_control_weight": autopilot_control_weight,
		"blended_control_enabled": blended_control,
		"last_player_input_time": last_player_input_time,
		"time_since_last_input": Time.get_time_from_start() - last_player_input_time,
		"transition_in_progress": _is_transitioning(),
		"pending_handoff": pending_handoff
	}

func is_player_in_control() -> bool:
	"""Check if player has control (manual or blended)"""
	return current_control_mode in [ControlMode.PLAYER_MANUAL, ControlMode.BLENDED_CONTROL]

func is_autopilot_in_control() -> bool:
	"""Check if autopilot has control"""
	return current_control_mode == ControlMode.AUTOPILOT_ENGAGED

func is_control_transition_active() -> bool:
	"""Check if control transition is in progress"""
	return _is_transitioning()

# Private implementation

func _initialize_input_integration() -> void:
	"""Initialize input integration system"""
	# Find input manager
	input_manager = get_node_or_null("/root/InputManager")
	
	# Initialize input state tracking
	for input_name in monitored_inputs:
		input_states[input_name] = 0.0
	
	# Find ship controller
	if player_ship:
		ship_controller = player_ship.get_node_or_null("ShipController")
		if not ship_controller:
			ship_controller = player_ship.get_node_or_null("AIShipController")

func _monitor_player_input(delta: float) -> void:
	"""Monitor player input for control override detection"""
	var has_input: bool = false
	var current_frame_inputs: Dictionary = {}
	
	# Check all monitored inputs
	for input_name in monitored_inputs:
		var input_strength: float = Input.get_action_strength(input_name)
		
		# Apply deadzone
		if abs(input_strength) < input_deadzone:
			input_strength = 0.0
		
		current_frame_inputs[input_name] = input_strength
		
		# Check if input has changed significantly
		var previous_strength: float = input_states.get(input_name, 0.0)
		if abs(input_strength - previous_strength) > input_sensitivity_threshold:
			has_input = true
		
		input_states[input_name] = input_strength
	
	# Record input activity
	if has_input:
		last_player_input_time = Time.get_time_from_start()
	
	# Add to input history
	current_frame_inputs["timestamp"] = Time.get_time_from_start()
	current_frame_inputs["has_input"] = has_input
	input_history.append(current_frame_inputs)
	
	# Limit history length
	if input_history.size() > max_history_length:
		input_history.remove_at(0)

func _detect_input_overrides(delta: float) -> void:
	"""Detect when player input should override autopilot"""
	if current_control_mode != ControlMode.AUTOPILOT_ENGAGED:
		return
	
	var has_significant_input: bool = false
	
	# Check for significant input in any monitored action
	for input_name in monitored_inputs:
		var input_strength: float = input_states.get(input_name, 0.0)
		if abs(input_strength) > input_sensitivity_threshold:
			has_significant_input = true
			break
	
	# Count consecutive frames with significant input
	if has_significant_input:
		consecutive_override_frames += 1
	else:
		consecutive_override_frames = 0
	
	# Trigger override if threshold met
	if consecutive_override_frames >= override_frame_threshold:
		input_conflict_detected.emit("player_override")
		request_player_control_override()
		consecutive_override_frames = 0

func _update_control_transitions(delta: float) -> void:
	"""Update control transition states"""
	match current_control_mode:
		ControlMode.TRANSITION_TO_PLAYER:
			_update_transition_to_player(delta)
		ControlMode.TRANSITION_TO_AUTOPILOT:
			_update_transition_to_autopilot(delta)

func _update_transition_to_player(delta: float) -> void:
	"""Update transition from autopilot to player control"""
	var transition_time: float = Time.get_time_from_start() - transition_start_time
	var progress: float = clamp(transition_time / smooth_transition_duration, 0.0, 1.0)
	
	# Blend control weights during transition
	player_control_weight = progress
	autopilot_control_weight = 1.0 - progress
	
	# Complete transition
	if progress >= 1.0:
		_set_control_mode(ControlMode.PLAYER_MANUAL)
		control_handoff_completed.emit("autopilot", "player")
		pending_handoff = false

func _update_transition_to_autopilot(delta: float) -> void:
	"""Update transition from player to autopilot control"""
	var transition_time: float = Time.get_time_from_start() - transition_start_time
	var progress: float = clamp(transition_time / smooth_transition_duration, 0.0, 1.0)
	
	# Blend control weights during transition
	player_control_weight = 1.0 - progress
	autopilot_control_weight = progress
	
	# Complete transition
	if progress >= 1.0:
		_set_control_mode(ControlMode.AUTOPILOT_ENGAGED)
		control_handoff_completed.emit("player", "autopilot")
		pending_handoff = false

func _update_control_blending(delta: float) -> void:
	"""Update blended control between player and autopilot"""
	if current_control_mode != ControlMode.BLENDED_CONTROL:
		return
	
	# Adjust blending weights based on player input activity
	var time_since_input: float = Time.get_time_from_start() - last_player_input_time
	
	if time_since_input < control_override_timeout:
		# Recent player input - favor player control
		player_control_weight = 0.8
		autopilot_control_weight = 0.2
	else:
		# No recent input - favor autopilot
		player_control_weight = 0.3
		autopilot_control_weight = 0.7

func _transition_to_player_control() -> bool:
	"""Start transition to player control"""
	if current_control_mode == ControlMode.PLAYER_MANUAL:
		return true
	
	_set_control_mode(ControlMode.TRANSITION_TO_PLAYER)
	control_taken_by_player.emit()
	
	# Disable AI control on ship controller
	if ship_controller and ship_controller.has_method("disable_ai_control"):
		ship_controller.disable_ai_control()
	
	return true

func _transition_to_autopilot_control() -> bool:
	"""Start transition to autopilot control"""
	if current_control_mode == ControlMode.AUTOPILOT_ENGAGED:
		return true
	
	_set_control_mode(ControlMode.TRANSITION_TO_AUTOPILOT)
	control_returned_to_autopilot.emit()
	
	# Enable AI control on ship controller
	if ship_controller and ship_controller.has_method("enable_ai_control"):
		ship_controller.enable_ai_control()
	
	return true

func _set_control_mode(new_mode: ControlMode) -> void:
	"""Set control mode and handle transitions"""
	var old_mode: ControlMode = current_control_mode
	current_control_mode = new_mode
	
	# Handle mode-specific setup
	match new_mode:
		ControlMode.TRANSITION_TO_PLAYER, ControlMode.TRANSITION_TO_AUTOPILOT:
			transition_start_time = Time.get_time_from_start()
			pending_handoff = true
		
		ControlMode.PLAYER_MANUAL:
			player_control_weight = 1.0
			autopilot_control_weight = 0.0
		
		ControlMode.AUTOPILOT_ENGAGED:
			player_control_weight = 0.0
			autopilot_control_weight = 1.0
		
		ControlMode.BLENDED_CONTROL:
			# Weights managed by blending logic
			pass

func _is_transitioning() -> bool:
	"""Check if currently in a transition state"""
	return current_control_mode in [ControlMode.TRANSITION_TO_PLAYER, ControlMode.TRANSITION_TO_AUTOPILOT]

func _get_input_activity_level() -> float:
	"""Calculate current input activity level (0.0 to 1.0)"""
	if input_history.is_empty():
		return 0.0
	
	var recent_frames: int = min(30, input_history.size())  # Last 0.5 seconds
	var active_frames: int = 0
	
	for i in range(input_history.size() - recent_frames, input_history.size()):
		if input_history[i].get("has_input", false):
			active_frames += 1
	
	return float(active_frames) / float(recent_frames)

func _calculate_control_blend_ratio() -> float:
	"""Calculate optimal control blend ratio based on context"""
	var activity_level: float = _get_input_activity_level()
	var time_since_input: float = Time.get_time_from_start() - last_player_input_time
	
	# High activity = more player control
	var activity_factor: float = activity_level
	
	# Recent input = more player control  
	var recency_factor: float = 1.0 - clamp(time_since_input / 5.0, 0.0, 1.0)
	
	# Combine factors
	var player_preference: float = (activity_factor + recency_factor) / 2.0
	
	return clamp(player_preference, 0.0, 1.0)

# Signal handlers

func _on_autopilot_engaged(destination: Vector3, mode: AutopilotManager.AutopilotMode) -> void:
	"""Handle autopilot engagement"""
	if current_control_mode == ControlMode.PLAYER_MANUAL:
		_transition_to_autopilot_control()
	elif current_control_mode == ControlMode.BLENDED_CONTROL:
		# In blended mode, just adjust weights
		player_control_weight = 0.2
		autopilot_control_weight = 0.8

func _on_autopilot_disengaged(reason: String) -> void:
	"""Handle autopilot disengagement"""
	if current_control_mode in [ControlMode.AUTOPILOT_ENGAGED, ControlMode.BLENDED_CONTROL]:
		_transition_to_player_control()

func _on_control_handoff_requested(from_mode: String, to_mode: String) -> void:
	"""Handle control handoff requests"""
	pending_handoff = true
	
	if to_mode == "autopilot":
		_transition_to_autopilot_control()
	elif to_mode == "manual":
		_transition_to_player_control()

# Debug and utilities

func get_input_debug_info() -> Dictionary:
	"""Get debug information about input state"""
	return {
		"control_mode": ControlMode.keys()[current_control_mode],
		"input_states": input_states,
		"last_input_time": last_player_input_time,
		"time_since_input": Time.get_time_from_start() - last_player_input_time,
		"activity_level": _get_input_activity_level(),
		"consecutive_override_frames": consecutive_override_frames,
		"player_weight": player_control_weight,
		"autopilot_weight": autopilot_control_weight,
		"transition_in_progress": _is_transitioning(),
		"input_history_length": input_history.size()
	}

func clear_input_history() -> void:
	"""Clear input history (useful for testing)"""
	input_history.clear()
	input_states.clear()
	for input_name in monitored_inputs:
		input_states[input_name] = 0.0

func simulate_player_input(input_name: String, strength: float) -> void:
	"""Simulate player input (for testing)"""
	if input_name in monitored_inputs:
		input_states[input_name] = strength
		if abs(strength) > input_sensitivity_threshold:
			last_player_input_time = Time.get_time_from_start()

# Configuration interface

func add_monitored_input(input_name: String) -> void:
	"""Add an input action to monitor"""
	if input_name not in monitored_inputs:
		monitored_inputs.append(input_name)
		input_states[input_name] = 0.0

func remove_monitored_input(input_name: String) -> void:
	"""Remove an input action from monitoring"""
	var index: int = monitored_inputs.find(input_name)
	if index >= 0:
		monitored_inputs.remove_at(index)
		input_states.erase(input_name)

func set_sensitivity_threshold(threshold: float) -> void:
	"""Set input sensitivity threshold"""
	input_sensitivity_threshold = clamp(threshold, 0.01, 1.0)

func set_override_frame_threshold(frames: int) -> void:
	"""Set number of consecutive frames needed for override"""
	override_frame_threshold = max(1, frames)

func set_transition_duration(duration: float) -> void:
	"""Set smooth transition duration"""
	smooth_transition_duration = max(0.1, duration)