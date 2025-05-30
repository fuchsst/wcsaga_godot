extends CanvasLayer

## Debug overlay showing core manager status and performance metrics
## Provides real-time monitoring of ObjectManager, GameStateManager, PhysicsManager, and InputManager

@export var update_interval: float = 0.5  # Update every 500ms
@export var auto_hide_timer: float = 10.0  # Auto-hide after 10 seconds
@export var enable_performance_graphs: bool = false

# --- Core Classes ---
const ManagerCoordinator = preload("res://scripts/core/manager_coordinator.gd")

# UI components
var main_panel: Panel
var manager_labels: Dictionary = {}
var performance_labels: Dictionary = {}
var toggle_button: Button

# State
var is_visible: bool = false
var update_timer: float = 0.0
var auto_hide_countdown: float = 0.0
var manager_coordinator: ManagerCoordinator

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_create_debug_ui()
	_setup_manager_coordinator()
	
	# Start hidden
	set_overlay_visible(false)

func _create_debug_ui() -> void:
	# Create main panel
	main_panel = Panel.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	main_panel.size = Vector2(400, 300)
	main_panel.position = Vector2(10, 10)
	
	# Style the panel
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.5, 0.7, 1.0, 1.0)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	main_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create content container
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	main_panel.add_child(vbox)
	
	# Title label
	var title_label: Label = Label.new()
	title_label.text = "Core Manager Status"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_label)
	
	# Add separator
	var separator: HSeparator = HSeparator.new()
	vbox.add_child(separator)
	
	# Create manager status labels
	_create_manager_status_labels(vbox)
	
	# Add performance section
	var perf_separator: HSeparator = HSeparator.new()
	vbox.add_child(perf_separator)
	
	var perf_title: Label = Label.new()
	perf_title.text = "Performance Metrics"
	perf_title.add_theme_font_size_override("font_size", 14)
	perf_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(perf_title)
	
	_create_performance_labels(vbox)
	
	# Create toggle button
	toggle_button = Button.new()
	toggle_button.text = "Debug"
	toggle_button.size = Vector2(60, 30)
	toggle_button.position = Vector2(10, 320)
	toggle_button.pressed.connect(_on_toggle_pressed)
	
	# Add to canvas layer
	add_child(main_panel)
	add_child(toggle_button)

func _create_manager_status_labels(parent: VBoxContainer) -> void:
	var managers: Array[String] = ["ObjectManager", "GameStateManager", "PhysicsManager", "InputManager"]
	
	for manager_name in managers:
		var hbox: HBoxContainer = HBoxContainer.new()
		parent.add_child(hbox)
		
		# Manager name label
		var name_label: Label = Label.new()
		name_label.text = manager_name + ":"
		name_label.custom_minimum_size.x = 150
		name_label.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(name_label)
		
		# Status label
		var status_label: Label = Label.new()
		status_label.text = "Unknown"
		status_label.add_theme_color_override("font_color", Color.GRAY)
		hbox.add_child(status_label)
		
		manager_labels[manager_name] = status_label

func _create_performance_labels(parent: VBoxContainer) -> void:
	var metrics: Array[String] = [
		"Total Objects",
		"Physics Bodies", 
		"Input Actions",
		"Frame Time",
		"Memory Usage"
	]
	
	for metric_name in metrics:
		var hbox: HBoxContainer = HBoxContainer.new()
		parent.add_child(hbox)
		
		# Metric name label
		var name_label: Label = Label.new()
		name_label.text = metric_name + ":"
		name_label.custom_minimum_size.x = 120
		name_label.add_theme_color_override("font_color", Color.CYAN)
		hbox.add_child(name_label)
		
		# Value label
		var value_label: Label = Label.new()
		value_label.text = "0"
		value_label.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(value_label)
		
		performance_labels[metric_name] = value_label

func _setup_manager_coordinator() -> void:
	# Create and add manager coordinator
	manager_coordinator = ManagerCoordinator.new()
	add_child(manager_coordinator)
	
	# Connect to coordination signals
	manager_coordinator.all_managers_initialized.connect(_on_all_managers_ready)
	manager_coordinator.manager_coordination_complete.connect(_on_coordination_complete)

func _process(delta: float) -> void:
	if not is_visible:
		return
	
	# Update timer
	update_timer += delta
	auto_hide_countdown -= delta
	
	# Update display at intervals
	if update_timer >= update_interval:
		_update_debug_display()
		update_timer = 0.0
	
	# Auto-hide logic
	if auto_hide_countdown <= 0.0 and auto_hide_timer > 0.0:
		set_overlay_visible(false)

func _input(event: InputEvent) -> void:
	# Toggle debug overlay with F3 key
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_F3:
			toggle_overlay()

func toggle_overlay() -> void:
	set_overlay_visible(not is_visible)

func set_overlay_visible(visible: bool) -> void:
	is_visible = visible
	main_panel.visible = visible
	
	if visible:
		auto_hide_countdown = auto_hide_timer
		_update_debug_display()
	
	toggle_button.text = "Hide" if visible else "Debug"

func _update_debug_display() -> void:
	_update_manager_status()
	_update_performance_metrics()

func _update_manager_status() -> void:
	if not manager_coordinator:
		return
	
	var status: Dictionary = manager_coordinator.get_manager_status()
	
	for manager_name in manager_labels.keys():
		var label: Label = manager_labels[manager_name]
		var info: Dictionary = status.get(manager_name, {})
		
		if not info.get("exists", false):
			label.text = "Missing"
			label.add_theme_color_override("font_color", Color.RED)
		elif not info.get("initialized", false):
			label.text = "Initializing..."
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.text = "Ready"
			label.add_theme_color_override("font_color", Color.GREEN)

func _update_performance_metrics() -> void:
	# Update Total Objects
	if ObjectManager:
		var obj_stats: Dictionary = ObjectManager.get_performance_stats()
		_update_metric_label("Total Objects", str(obj_stats.get("active_objects", 0)))
	
	# Update Physics Bodies
	if PhysicsManager:
		var phys_stats: Dictionary = PhysicsManager.get_performance_stats()
		_update_metric_label("Physics Bodies", str(phys_stats.get("physics_bodies", 0)))
	
	# Update Input Actions
	if InputManager:
		var input_stats: Dictionary = InputManager.get_performance_stats()
		var active_actions: int = input_stats.get("active_actions", 0)
		var scheme: String = input_stats.get("current_scheme", "Unknown")
		_update_metric_label("Input Actions", "%d (%s)" % [active_actions, scheme])
	
	# Update Frame Time
	var frame_time: float = 1.0 / Engine.get_frames_per_second()
	var frame_color: Color = Color.GREEN if frame_time < 0.020 else (Color.YELLOW if frame_time < 0.033 else Color.RED)
	_update_metric_label("Frame Time", "%.1fms" % (frame_time * 1000.0), frame_color)
	
	# Update Memory Usage
	var memory_mb: float = OS.get_static_memory_usage() / 1024.0 / 1024.0
	_update_metric_label("Memory Usage", "%.1fMB" % memory_mb)

func _update_metric_label(metric_name: String, value: String, color: Color = Color.WHITE) -> void:
	if performance_labels.has(metric_name):
		var label: Label = performance_labels[metric_name]
		label.text = value
		label.add_theme_color_override("font_color", color)

func _on_toggle_pressed() -> void:
	toggle_overlay()

func _on_all_managers_ready() -> void:
	print("ManagerDebugOverlay: All managers are ready")

func _on_coordination_complete() -> void:
	print("ManagerDebugOverlay: Manager coordination complete")
	
	# Show overlay briefly to confirm initialization
	if not is_visible:
		set_overlay_visible(true)

# Debug commands

func debug_force_show() -> void:
	set_overlay_visible(true)
	auto_hide_countdown = 999999.0  # Disable auto-hide

func debug_print_full_status() -> void:
	print("=== Full Manager Debug Status ===")
	
	if manager_coordinator:
		manager_coordinator.debug_print_manager_status()
	
	if ObjectManager:
		ObjectManager.debug_print_active_objects()
	
	if GameStateManager:
		GameStateManager.debug_print_state_info()
	
	if PhysicsManager:
		PhysicsManager.debug_print_physics_info()
	
	if InputManager:
		InputManager.debug_print_input_state()
	
	print("===================================")

func debug_test_managers() -> void:
	print("ManagerDebugOverlay: Running manager tests...")
	
	# Test ObjectManager
	if ObjectManager:
		print("ObjectManager validation: %s" % ObjectManager.debug_validate_object_integrity())
	
	# Test GameStateManager
	if GameStateManager:
		print("GameStateManager current state: %s" % GameStateManager.GameState.keys()[GameStateManager.get_current_state()])
	
	# Test PhysicsManager
	if PhysicsManager:
		print("PhysicsManager body count: %d" % PhysicsManager.get_physics_body_count())
	
	# Test InputManager
	if InputManager:
		print("InputManager connected devices: %s" % InputManager.get_connected_devices())

# Cleanup

func _exit_tree() -> void:
	if manager_coordinator and is_instance_valid(manager_coordinator):
		manager_coordinator.queue_free()