class_name AutopilotUIIntegration
extends Control

## UI integration for autopilot system
## Provides status display, manual controls, and visual feedback

signal autopilot_engage_requested()
signal autopilot_disengage_requested()
signal autopilot_assist_toggled()
signal destination_set_requested(destination: Vector3)
signal squadron_autopilot_requested()

# UI Components (to be connected in scene)
@export var autopilot_status_panel: Control
@export var engage_button: Button
@export var disengage_button: Button
@export var assist_button: Button
@export var status_label: Label
@export var destination_display: Label
@export var eta_display: Label
@export var speed_slider: HSlider
@export var threat_indicator: Control
@export var formation_status_panel: Control
@export var squadron_panel: Control

# System references
var autopilot_manager: AutopilotManager
var safety_monitor: AutopilotSafetyMonitor
var squadron_coordinator: SquadronAutopilotCoordinator
var input_integration: PlayerInputIntegration

# UI State
var ui_enabled: bool = true
var status_update_frequency: float = 0.2  # 5 times per second
var last_status_update: float = 0.0
var current_destination: Vector3 = Vector3.ZERO

# Visual elements
var status_colors: Dictionary = {
	"disengaged": Color.WHITE,
	"engaged": Color.GREEN,
	"engaging": Color.YELLOW,
	"disengaging": Color.ORANGE,
	"interrupted": Color.RED,
	"error": Color.RED
}

var threat_colors: Dictionary = {
	AutopilotSafetyMonitor.ThreatLevel.NONE: Color.GREEN,
	AutopilotSafetyMonitor.ThreatLevel.LOW: Color.YELLOW,
	AutopilotSafetyMonitor.ThreatLevel.MEDIUM: Color.ORANGE,
	AutopilotSafetyMonitor.ThreatLevel.HIGH: Color.RED,
	AutopilotSafetyMonitor.ThreatLevel.CRITICAL: Color.PURPLE
}

# Animation and feedback
var status_blink_enabled: bool = false
var blink_timer: float = 0.0
var blink_frequency: float = 2.0  # Blinks per second

func _ready() -> void:
	_initialize_ui_integration()
	_connect_ui_signals()
	set_process(true)

func _process(delta: float) -> void:
	_update_ui_status(delta)
	_update_visual_feedback(delta)

# Public interface

func initialize_with_autopilot_systems(autopilot: AutopilotManager, safety: AutopilotSafetyMonitor, squadron: SquadronAutopilotCoordinator, input_int: PlayerInputIntegration) -> void:
	"""Initialize UI with autopilot system references"""
	autopilot_manager = autopilot
	safety_monitor = safety
	squadron_coordinator = squadron
	input_integration = input_int
	
	# Connect to system signals
	_connect_system_signals()
	
	# Initial UI update
	_force_ui_update()

func show_autopilot_panel() -> void:
	"""Show the autopilot control panel"""
	if autopilot_status_panel:
		autopilot_status_panel.visible = true
	visible = true

func hide_autopilot_panel() -> void:
	"""Hide the autopilot control panel"""
	if autopilot_status_panel:
		autopilot_status_panel.visible = false
	visible = false

func set_ui_enabled(enabled: bool) -> void:
	"""Enable/disable UI interaction"""
	ui_enabled = enabled
	_update_button_states()

func set_destination_display(destination: Vector3) -> void:
	"""Set destination for UI display"""
	current_destination = destination
	_update_destination_display()

func show_threat_warning(threat_level: AutopilotSafetyMonitor.ThreatLevel, message: String = "") -> void:
	"""Show threat warning in UI"""
	if threat_indicator:
		threat_indicator.visible = true
		threat_indicator.modulate = threat_colors.get(threat_level, Color.RED)
		
		# Enable blinking for high threat levels
		if threat_level >= AutopilotSafetyMonitor.ThreatLevel.HIGH:
			status_blink_enabled = true

func hide_threat_warning() -> void:
	"""Hide threat warning"""
	if threat_indicator:
		threat_indicator.visible = false
	status_blink_enabled = false

func show_squadron_controls(show: bool = true) -> void:
	"""Show/hide squadron autopilot controls"""
	if squadron_panel:
		squadron_panel.visible = show

func update_formation_status(formation_data: Dictionary) -> void:
	"""Update formation status display"""
	if formation_status_panel:
		formation_status_panel.visible = not formation_data.is_empty()
		# Update formation-specific UI elements here

# Private implementation

func _initialize_ui_integration() -> void:
	"""Initialize UI components and layout"""
	# Create UI elements if not assigned
	if not autopilot_status_panel:
		_create_default_ui_layout()
	
	# Initialize button states
	_update_button_states()
	
	# Set initial visibility
	show_autopilot_panel()

func _create_default_ui_layout() -> void:
	"""Create default UI layout if components not assigned"""
	autopilot_status_panel = Control.new()
	autopilot_status_panel.name = "AutopilotStatusPanel"
	add_child(autopilot_status_panel)
	
	# Main status container
	var main_container: VBoxContainer = VBoxContainer.new()
	main_container.name = "MainContainer"
	autopilot_status_panel.add_child(main_container)
	
	# Status display section
	var status_section: HBoxContainer = HBoxContainer.new()
	main_container.add_child(status_section)
	
	status_label = Label.new()
	status_label.text = "Autopilot: Disengaged"
	status_label.name = "StatusLabel"
	status_section.add_child(status_label)
	
	threat_indicator = Control.new()
	threat_indicator.name = "ThreatIndicator"
	threat_indicator.custom_minimum_size = Vector2(20, 20)
	threat_indicator.visible = false
	status_section.add_child(threat_indicator)
	
	# Destination and ETA display
	var info_section: VBoxContainer = VBoxContainer.new()
	main_container.add_child(info_section)
	
	destination_display = Label.new()
	destination_display.text = "Destination: None"
	destination_display.name = "DestinationDisplay"
	info_section.add_child(destination_display)
	
	eta_display = Label.new()
	eta_display.text = "ETA: --"
	eta_display.name = "ETADisplay"
	info_section.add_child(eta_display)
	
	# Control buttons section
	var button_section: HBoxContainer = HBoxContainer.new()
	main_container.add_child(button_section)
	
	engage_button = Button.new()
	engage_button.text = "Engage"
	engage_button.name = "EngageButton"
	button_section.add_child(engage_button)
	
	disengage_button = Button.new()
	disengage_button.text = "Disengage"
	disengage_button.name = "DisengageButton"
	button_section.add_child(disengage_button)
	
	assist_button = Button.new()
	assist_button.text = "Assist"
	assist_button.name = "AssistButton"
	button_section.add_child(assist_button)
	
	# Speed control
	var speed_section: HBoxContainer = HBoxContainer.new()
	main_container.add_child(speed_section)
	
	var speed_label: Label = Label.new()
	speed_label.text = "Speed:"
	speed_section.add_child(speed_label)
	
	speed_slider = HSlider.new()
	speed_slider.min_value = 0.1
	speed_slider.max_value = 1.0
	speed_slider.value = 0.8
	speed_slider.step = 0.1
	speed_slider.name = "SpeedSlider"
	speed_section.add_child(speed_slider)
	
	# Formation status panel
	formation_status_panel = Control.new()
	formation_status_panel.name = "FormationStatusPanel"
	formation_status_panel.visible = false
	main_container.add_child(formation_status_panel)
	
	# Squadron panel
	squadron_panel = Control.new()
	squadron_panel.name = "SquadronPanel"
	squadron_panel.visible = false
	main_container.add_child(squadron_panel)

func _connect_ui_signals() -> void:
	"""Connect UI element signals"""
	if engage_button:
		engage_button.pressed.connect(_on_engage_button_pressed)
	
	if disengage_button:
		disengage_button.pressed.connect(_on_disengage_button_pressed)
	
	if assist_button:
		assist_button.pressed.connect(_on_assist_button_pressed)
	
	if speed_slider:
		speed_slider.value_changed.connect(_on_speed_slider_changed)

func _connect_system_signals() -> void:
	"""Connect to autopilot system signals"""
	if autopilot_manager:
		autopilot_manager.autopilot_engaged.connect(_on_autopilot_engaged)
		autopilot_manager.autopilot_disengaged.connect(_on_autopilot_disengaged)
		autopilot_manager.autopilot_destination_reached.connect(_on_destination_reached)
		autopilot_manager.autopilot_interrupted.connect(_on_autopilot_interrupted)
	
	if safety_monitor:
		safety_monitor.threat_detected.connect(_on_threat_detected)
		safety_monitor.emergency_situation_detected.connect(_on_emergency_situation)
	
	if input_integration:
		input_integration.control_taken_by_player.connect(_on_control_taken_by_player)
		input_integration.control_returned_to_autopilot.connect(_on_control_returned_to_autopilot)
		input_integration.input_conflict_detected.connect(_on_input_conflict)

func _update_ui_status(delta: float) -> void:
	"""Update UI status displays"""
	var current_time: float = Time.get_time_from_start()
	if current_time - last_status_update < status_update_frequency:
		return
	
	last_status_update = current_time
	
	# Update autopilot status
	_update_autopilot_status_display()
	
	# Update destination and ETA
	_update_destination_display()
	_update_eta_display()
	
	# Update button states
	_update_button_states()
	
	# Update threat status
	_update_threat_display()

func _update_autopilot_status_display() -> void:
	"""Update autopilot status label"""
	if not autopilot_manager or not status_label:
		return
	
	var status: Dictionary = autopilot_manager.get_autopilot_status()
	var mode: String = status.get("mode", "DISABLED")
	var state: String = status.get("state", "DISENGAGED")
	
	var status_text: String = "Autopilot: "
	match state:
		"DISENGAGED":
			status_text += "Disengaged"
			status_label.modulate = status_colors.disengaged
		"ENGAGING":
			status_text += "Engaging (" + mode + ")"
			status_label.modulate = status_colors.engaging
		"ENGAGED":
			status_text += "Engaged (" + mode + ")"
			status_label.modulate = status_colors.engaged
		"DISENGAGING":
			status_text += "Disengaging"
			status_label.modulate = status_colors.disengaging
		"EMERGENCY_STOP":
			status_text += "EMERGENCY STOP"
			status_label.modulate = status_colors.error
		_:
			status_text += "Unknown State"
			status_label.modulate = status_colors.error
	
	status_label.text = status_text

func _update_destination_display() -> void:
	"""Update destination display"""
	if not destination_display:
		return
	
	if current_destination == Vector3.ZERO:
		destination_display.text = "Destination: None"
	else:
		destination_display.text = "Destination: (%.0f, %.0f, %.0f)" % [current_destination.x, current_destination.y, current_destination.z]

func _update_eta_display() -> void:
	"""Update ETA display"""
	if not autopilot_manager or not eta_display:
		return
	
	var status: Dictionary = autopilot_manager.get_autopilot_status()
	var eta: float = status.get("estimated_arrival_time", -1.0)
	
	if eta > 0:
		eta_display.text = "ETA: " + _format_time(eta)
	else:
		eta_display.text = "ETA: --"

func _update_button_states() -> void:
	"""Update button enabled/disabled states"""
	if not autopilot_manager:
		return
	
	var can_engage: bool = autopilot_manager.can_engage_autopilot()
	var is_engaged: bool = autopilot_manager.is_autopilot_engaged()
	
	if engage_button:
		engage_button.disabled = not ui_enabled or is_engaged or not can_engage
	
	if disengage_button:
		disengage_button.disabled = not ui_enabled or not is_engaged
	
	if assist_button:
		assist_button.disabled = not ui_enabled

func _update_threat_display() -> void:
	"""Update threat indicator display"""
	if not safety_monitor or not threat_indicator:
		return
	
	var threat_level: AutopilotSafetyMonitor.ThreatLevel = safety_monitor.get_highest_threat_level()
	
	if threat_level == AutopilotSafetyMonitor.ThreatLevel.NONE:
		hide_threat_warning()
	else:
		show_threat_warning(threat_level)

func _update_visual_feedback(delta: float) -> void:
	"""Update visual feedback effects"""
	if status_blink_enabled:
		blink_timer += delta
		var blink_cycle: float = 1.0 / blink_frequency
		var alpha: float = (sin(blink_timer * TAU * blink_frequency) + 1.0) / 2.0
		
		if threat_indicator:
			threat_indicator.modulate.a = alpha

func _force_ui_update() -> void:
	"""Force immediate UI update"""
	last_status_update = 0.0
	_update_ui_status(0.0)

func _format_time(seconds: float) -> String:
	"""Format time for display"""
	if seconds < 60:
		return "%.0fs" % seconds
	elif seconds < 3600:
		var minutes: int = int(seconds / 60)
		var secs: int = int(seconds) % 60
		return "%dm %ds" % [minutes, secs]
	else:
		var hours: int = int(seconds / 3600)
		var minutes: int = int(seconds / 60) % 60
		return "%dh %dm" % [hours, minutes]

# Signal handlers - UI events

func _on_engage_button_pressed() -> void:
	"""Handle engage button press"""
	autopilot_engage_requested.emit()

func _on_disengage_button_pressed() -> void:
	"""Handle disengage button press"""
	autopilot_disengage_requested.emit()

func _on_assist_button_pressed() -> void:
	"""Handle assist button press"""
	autopilot_assist_toggled.emit()

func _on_speed_slider_changed(value: float) -> void:
	"""Handle speed slider change"""
	if autopilot_manager:
		autopilot_manager.set_navigation_speed(value)

# Signal handlers - System events

func _on_autopilot_engaged(destination: Vector3, mode: AutopilotManager.AutopilotMode) -> void:
	"""Handle autopilot engagement"""
	current_destination = destination
	_force_ui_update()

func _on_autopilot_disengaged(reason: String) -> void:
	"""Handle autopilot disengagement"""
	current_destination = Vector3.ZERO
	hide_threat_warning()
	_force_ui_update()

func _on_destination_reached(final_position: Vector3) -> void:
	"""Handle destination reached"""
	current_destination = Vector3.ZERO
	_force_ui_update()

func _on_autopilot_interrupted(threat: Node3D, reason: String) -> void:
	"""Handle autopilot interruption"""
	status_blink_enabled = true
	_force_ui_update()

func _on_threat_detected(threat: Node3D, threat_level: float) -> void:
	"""Handle threat detection"""
	var level: AutopilotSafetyMonitor.ThreatLevel = int(threat_level)
	show_threat_warning(level, "Threat Detected")

func _on_emergency_situation(situation: String, severity: float) -> void:
	"""Handle emergency situation"""
	status_blink_enabled = true
	show_threat_warning(AutopilotSafetyMonitor.ThreatLevel.CRITICAL, "Emergency: " + situation)

func _on_control_taken_by_player() -> void:
	"""Handle player taking control"""
	_force_ui_update()

func _on_control_returned_to_autopilot() -> void:
	"""Handle control returning to autopilot"""
	_force_ui_update()

func _on_input_conflict(input_type: String) -> void:
	"""Handle input conflict detection"""
	status_blink_enabled = true

# Public utility methods

func flash_status(color: Color, duration: float = 1.0) -> void:
	"""Flash status display with specified color"""
	if status_label:
		var original_color: Color = status_label.modulate
		status_label.modulate = color
		
		var tween: Tween = create_tween()
		tween.tween_property(status_label, "modulate", original_color, duration)

func show_message(message: String, duration: float = 3.0) -> void:
	"""Show temporary message (could create a popup or overlay)"""
	print("Autopilot Message: ", message)  # Placeholder implementation

func get_ui_state() -> Dictionary:
	"""Get current UI state for debugging"""
	return {
		"ui_enabled": ui_enabled,
		"panel_visible": visible,
		"current_destination": current_destination,
		"threat_warning_visible": threat_indicator.visible if threat_indicator else false,
		"status_blink_enabled": status_blink_enabled,
		"engage_button_disabled": engage_button.disabled if engage_button else false,
		"disengage_button_disabled": disengage_button.disabled if disengage_button else false
	}

# Configuration methods

func set_status_update_frequency(frequency: float) -> void:
	"""Set UI status update frequency"""
	status_update_frequency = max(0.05, frequency)  # Minimum 20 FPS

func set_blink_frequency(frequency: float) -> void:
	"""Set blink frequency for status indicators"""
	blink_frequency = clamp(frequency, 0.5, 10.0)

func customize_status_colors(colors: Dictionary) -> void:
	"""Customize status display colors"""
	for key in colors.keys():
		if status_colors.has(key):
			status_colors[key] = colors[key]

func customize_threat_colors(colors: Dictionary) -> void:
	"""Customize threat level colors"""
	for key in colors.keys():
		if threat_colors.has(key):
			threat_colors[key] = colors[key]