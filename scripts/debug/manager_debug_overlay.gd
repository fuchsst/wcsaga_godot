class_name ManagerDebugOverlay
extends Control

## Debug overlay for monitoring WCS core manager performance and status.
## Provides real-time metrics, performance tracking, and system diagnostics.

@onready var object_stats: RichTextLabel = $Panel/VBoxContainer/ObjectManager/Stats
@onready var gamestate_stats: RichTextLabel = $Panel/VBoxContainer/GameStateManager/Stats
@onready var physics_stats: RichTextLabel = $Panel/VBoxContainer/PhysicsManager/Stats
@onready var input_stats: RichTextLabel = $Panel/VBoxContainer/InputManager/Stats
@onready var toggle_button: Button = $Panel/VBoxContainer/Controls/ToggleButton
@onready var panel: Panel = $Panel

var update_timer: float = 0.0
var update_interval: float = 0.1  # Update 10 times per second
var is_visible: bool = true

func _ready() -> void:
	# Start hidden in release builds
	if OS.is_debug_build():
		show()
	else:
		hide()
	
	_update_display()

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= update_interval:
		_update_display()
		update_timer = 0.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):  # F12 by default
		toggle_overlay()

func toggle_overlay() -> void:
	is_visible = !is_visible
	panel.visible = is_visible
	toggle_button.text = "Show (F12)" if not is_visible else "Hide (F12)"

func _update_display() -> void:
	if not is_visible:
		return
	
	_update_object_manager_stats()
	_update_gamestate_manager_stats()
	_update_physics_manager_stats()
	_update_input_manager_stats()

func _update_object_manager_stats() -> void:
	if not ObjectManager:
		object_stats.text = "[color=red]ObjectManager not available[/color]"
		return
	
	var stats: Dictionary = ObjectManager.get_debug_stats()
	var text: String = ""
	
	text += "[color=cyan]Active Objects:[/color] %d / %d\n" % [stats.active_count, stats.max_objects]
	text += "[color=cyan]Pool Usage:[/color] %d pools, %d pooled objects\n" % [stats.pool_count, stats.pooled_count]
	text += "[color=cyan]Update Groups:[/color]\n"
	text += "  • Every Frame: %d objects\n" % stats.update_groups.get("EVERY_FRAME", 0)
	text += "  • High (30fps): %d objects\n" % stats.update_groups.get("HIGH", 0)
	text += "  • Medium (15fps): %d objects\n" % stats.update_groups.get("MEDIUM", 0)
	text += "  • Low (5fps): %d objects\n" % stats.update_groups.get("LOW", 0)
	
	var avg_frame_time: float = stats.get("average_frame_time", 0.0)
	var color: String = "green" if avg_frame_time < 0.001 else ("yellow" if avg_frame_time < 0.002 else "red")
	text += "[color=%s]Avg Frame Time:[/color] %.3fms\n" % [color, avg_frame_time * 1000.0]
	
	object_stats.text = text

func _update_gamestate_manager_stats() -> void:
	if not GameStateManager:
		gamestate_stats.text = "[color=red]GameStateManager not available[/color]"
		return
	
	var stats: Dictionary = GameStateManager.get_debug_stats()
	var text: String = ""
	
	text += "[color=cyan]Current State:[/color] %s\n" % stats.current_state
	text += "[color=cyan]Previous State:[/color] %s\n" % stats.previous_state
	text += "[color=cyan]State Stack:[/color] %d levels\n" % stats.state_stack_size
	text += "[color=cyan]Transition Time:[/color] %.2fs\n" % stats.state_duration
	
	if stats.has("transition_in_progress") and stats.transition_in_progress:
		text += "[color=yellow]⚠ State transition in progress[/color]\n"
	
	gamestate_stats.text = text

func _update_physics_manager_stats() -> void:
	if not PhysicsManager:
		physics_stats.text = "[color=red]PhysicsManager not available[/color]"
		return
	
	var stats: Dictionary = PhysicsManager.get_debug_stats()
	var text: String = ""
	
	text += "[color=cyan]Physics Bodies:[/color] %d active\n" % stats.active_bodies
	text += "[color=cyan]Update Rate:[/color] %.1f Hz (target: 60Hz)\n" % stats.actual_update_rate
	
	var frame_time: float = stats.get("average_physics_frame_time", 0.0)
	var color: String = "green" if frame_time < 0.008 else ("yellow" if frame_time < 0.016 else "red")
	text += "[color=%s]Physics Frame:[/color] %.3fms\n" % [color, frame_time * 1000.0]
	
	text += "[color=cyan]Collision Checks:[/color] %d/frame\n" % stats.collision_checks_per_frame
	text += "[color=cyan]Time Scale:[/color] %.2fx\n" % stats.time_scale
	
	if stats.get("physics_lag", false):
		text += "[color=red]⚠ Physics lag detected[/color]\n"
	
	physics_stats.text = text

func _update_input_manager_stats() -> void:
	if not InputManager:
		input_stats.text = "[color=red]InputManager not available[/color]"
		return
	
	var stats: Dictionary = InputManager.get_debug_stats()
	var text: String = ""
	
	text += "[color=cyan]Control Scheme:[/color] %s\n" % stats.active_control_scheme
	text += "[color=cyan]Connected Devices:[/color] %d\n" % stats.connected_devices
	
	var latency: float = stats.get("average_input_latency", 0.0)
	var color: String = "green" if latency < 0.008 else ("yellow" if latency < 0.016 else "red")
	text += "[color=%s]Input Latency:[/color] %.1fms\n" % [color, latency * 1000.0]
	
	text += "[color=cyan]Analog Values:[/color]\n"
	var analog: Dictionary = stats.get("analog_inputs", {})
	for key in analog.keys():
		text += "  • %s: %.2f\n" % [key, analog[key]]
	
	if stats.get("calibration_required", false):
		text += "[color=yellow]⚠ Joystick calibration needed[/color]\n"
	
	input_stats.text = text

func _on_toggle_button_pressed() -> void:
	toggle_overlay()

func _on_refresh_button_pressed() -> void:
	_update_display()