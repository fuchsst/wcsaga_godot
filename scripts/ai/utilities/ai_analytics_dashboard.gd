class_name AIAnalyticsDashboard
extends Control

## Real-time AI performance analytics dashboard for development builds
## Provides visual monitoring of AI performance metrics and bottlenecks

signal dashboard_toggled(visible: bool)
signal performance_alert_acknowledged()

# UI Components
var main_panel: Panel
var stats_container: VBoxContainer
var performance_graph: Control
var alert_panel: Panel
var controls_panel: HBoxContainer

# Performance Data
var performance_data: Array[Dictionary] = []
var max_data_points: int = 120  # 2 seconds at 60 FPS
var update_interval: float = 0.1  # Update every 100ms
var update_timer: float = 0.0

# Graph Configuration
var graph_height: int = 200
var graph_width: int = 400
var graph_colors: Dictionary = {
	"frame_time": Color.GREEN,
	"budget_usage": Color.YELLOW,
	"violations": Color.RED,
	"lod_changes": Color.BLUE
}

# Dashboard State
var dashboard_visible: bool = false
var auto_scroll: bool = true
var pause_updates: bool = false
var selected_agent: WCSAIAgent

# Alert System
var active_alerts: Array[String] = []
var alert_history: Array[Dictionary] = []
var max_alert_history: int = 50

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	set_process(true)
	
	# Start hidden in non-debug builds
	visible = OS.is_debug_build()
	dashboard_visible = visible

func _process(delta: float) -> void:
	if not dashboard_visible or pause_updates:
		return
	
	update_timer += delta
	if update_timer >= update_interval:
		_update_performance_data()
		_update_displays()
		update_timer = 0.0

func _input(event: InputEvent) -> void:
	# Toggle dashboard with F1 key (development only)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1 and OS.is_debug_build():
			toggle_dashboard()

func toggle_dashboard() -> void:
	dashboard_visible = not dashboard_visible
	visible = dashboard_visible
	dashboard_toggled.emit(dashboard_visible)

func show_dashboard() -> void:
	dashboard_visible = true
	visible = true
	dashboard_toggled.emit(true)

func hide_dashboard() -> void:
	dashboard_visible = false
	visible = false
	dashboard_toggled.emit(false)

func add_performance_alert(message: String, severity: String = "WARNING") -> void:
	var alert: Dictionary = {
		"message": message,
		"severity": severity,
		"timestamp": Time.get_time_dict_from_system()["unix"],
		"acknowledged": false
	}
	
	active_alerts.append(message)
	alert_history.append(alert)
	
	if alert_history.size() > max_alert_history:
		alert_history.pop_front()
	
	_update_alert_display()

func acknowledge_alert(message: String) -> void:
	if message in active_alerts:
		active_alerts.erase(message)
	
	# Mark as acknowledged in history
	for alert in alert_history:
		if alert["message"] == message:
			alert["acknowledged"] = true
			break
	
	performance_alert_acknowledged.emit()
	_update_alert_display()

func clear_all_alerts() -> void:
	active_alerts.clear()
	_update_alert_display()

func set_selected_agent(agent: WCSAIAgent) -> void:
	selected_agent = agent
	_update_agent_specific_display()

func get_performance_summary() -> Dictionary:
	if performance_data.is_empty():
		return {}
	
	var latest: Dictionary = performance_data[-1]
	var budget_stats: Dictionary = AIManager.ai_frame_budget_manager.get_budget_statistics() if AIManager.ai_frame_budget_manager else {}
	var lod_stats: Dictionary = AIManager.ai_lod_manager.get_lod_statistics() if AIManager.ai_lod_manager else {}
	
	return {
		"ai_agents_total": lod_stats.get("total_agents", 0),
		"frame_budget_ms": budget_stats.get("frame_budget_ms", 0.0),
		"budget_utilization": budget_stats.get("budget_utilization", 0.0),
		"agents_processed": budget_stats.get("agents_processed", 0),
		"agents_skipped": budget_stats.get("agents_skipped", 0),
		"budget_violations": budget_stats.get("budget_violations", 0),
		"emergency_mode": budget_stats.get("emergency_mode", false),
		"active_alerts": active_alerts.size(),
		"lod_distribution": lod_stats.get("lod_distribution", {})
	}

# Private Methods

func _setup_ui() -> void:
	name = "AIAnalyticsDashboard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Main panel
	main_panel = Panel.new()
	main_panel.size = Vector2(600, 400)
	main_panel.position = Vector2(50, 50)
	add_child(main_panel)
	
	# Layout container
	var main_layout: VBoxContainer = VBoxContainer.new()
	main_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_layout.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_layout)
	
	# Title
	var title: Label = Label.new()
	title.text = "AI Performance Analytics Dashboard"
	title.add_theme_font_size_override("font_size", 18)
	main_layout.add_child(title)
	
	# Controls panel
	_setup_controls_panel(main_layout)
	
	# Stats container
	stats_container = VBoxContainer.new()
	main_layout.add_child(stats_container)
	
	# Performance graph
	performance_graph = Control.new()
	performance_graph.custom_minimum_size = Vector2(graph_width, graph_height)
	performance_graph.draw.connect(_draw_performance_graph)
	main_layout.add_child(performance_graph)
	
	# Alert panel
	_setup_alert_panel(main_layout)

func _setup_controls_panel(parent: Control) -> void:
	controls_panel = HBoxContainer.new()
	parent.add_child(controls_panel)
	
	# Pause/Resume button
	var pause_button: Button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	controls_panel.add_child(pause_button)
	
	# Clear alerts button
	var clear_alerts_button: Button = Button.new()
	clear_alerts_button.text = "Clear Alerts"
	clear_alerts_button.pressed.connect(clear_all_alerts)
	controls_panel.add_child(clear_alerts_button)
	
	# Auto-scroll toggle
	var autoscroll_check: CheckBox = CheckBox.new()
	autoscroll_check.text = "Auto Scroll"
	autoscroll_check.button_pressed = auto_scroll
	autoscroll_check.toggled.connect(_on_autoscroll_toggled)
	controls_panel.add_child(autoscroll_check)

func _setup_alert_panel(parent: Control) -> void:
	alert_panel = Panel.new()
	alert_panel.custom_minimum_size = Vector2(0, 100)
	parent.add_child(alert_panel)
	
	var alert_label: Label = Label.new()
	alert_label.text = "Performance Alerts"
	alert_label.position = Vector2(10, 5)
	alert_panel.add_child(alert_label)

func _connect_signals() -> void:
	# Connect to AI performance signals
	if AIManager and AIManager.ai_frame_budget_manager:
		var budget_manager = AIManager.ai_frame_budget_manager
		budget_manager.budget_exceeded.connect(_on_budget_exceeded)
		budget_manager.budget_critical.connect(_on_budget_critical)
		budget_manager.budget_exhausted.connect(_on_budget_exhausted)
	
	if AIManager and AIManager.ai_lod_manager:
		var lod_manager = AIManager.ai_lod_manager
		lod_manager.lod_level_changed.connect(_on_lod_level_changed)

func _update_performance_data() -> void:
	var frame_data: Dictionary = {}
	
	# Collect budget manager data
	if AIManager and AIManager.ai_frame_budget_manager:
		var budget_stats: Dictionary = AIManager.ai_frame_budget_manager.get_budget_statistics()
		frame_data.merge(budget_stats)
	
	# Collect LOD manager data
	if AIManager and AIManager.ai_lod_manager:
		var lod_stats: Dictionary = AIManager.ai_lod_manager.get_lod_statistics()
		frame_data.merge(lod_stats)
	
	# Add timestamp
	frame_data["timestamp"] = Time.get_time_dict_from_system()["unix"]
	
	performance_data.append(frame_data)
	
	if performance_data.size() > max_data_points:
		performance_data.pop_front()

func _update_displays() -> void:
	_update_stats_display()
	_update_graph_display()
	_update_agent_specific_display()

func _update_stats_display() -> void:
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()
	
	if performance_data.is_empty():
		return
	
	var latest: Dictionary = performance_data[-1]
	
	# Create stats labels
	var stats: Array[String] = [
		"Total AI Agents: " + str(latest.get("total_agents", 0)),
		"Frame Budget: " + str(latest.get("frame_budget_ms", 0.0)) + "ms",
		"Budget Utilization: " + str(latest.get("budget_utilization", 0.0) * 100.0) + "%",
		"Agents Processed: " + str(latest.get("agents_processed", 0)),
		"Agents Skipped: " + str(latest.get("agents_skipped", 0)),
		"Budget Violations: " + str(latest.get("budget_violations", 0)),
		"Emergency Mode: " + ("YES" if latest.get("emergency_mode", false) else "NO"),
		"LOD Changes: " + str(latest.get("lod_changes_this_frame", 0))
	]
	
	for stat in stats:
		var label: Label = Label.new()
		label.text = stat
		stats_container.add_child(label)

func _update_graph_display() -> void:
	if performance_graph:
		performance_graph.queue_redraw()

func _update_alert_display() -> void:
	# Update alert panel with current alerts
	for child in alert_panel.get_children():
		if child.name.begins_with("alert_"):
			child.queue_free()
	
	var y_offset: int = 25
	for i in range(min(3, active_alerts.size())):  # Show up to 3 alerts
		var alert_label: Label = Label.new()
		alert_label.name = "alert_" + str(i)
		alert_label.text = "⚠ " + active_alerts[i]
		alert_label.position = Vector2(10, y_offset)
		alert_label.add_theme_color_override("font_color", Color.RED)
		alert_panel.add_child(alert_label)
		y_offset += 20

func _update_agent_specific_display() -> void:
	if not selected_agent:
		return
	
	# Show specific stats for selected agent
	# This could be enhanced to show detailed agent behavior info

func _draw_performance_graph() -> void:
	if performance_data.is_empty():
		return
	
	var canvas: CanvasItem = performance_graph
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(graph_width, graph_height))
	
	# Draw background
	canvas.draw_rect(rect, Color(0.1, 0.1, 0.1, 0.8))
	
	# Draw budget utilization line
	_draw_metric_line(canvas, "budget_utilization", Color.YELLOW, 0.0, 2.0)
	
	# Draw emergency mode indicators
	_draw_emergency_indicators(canvas)
	
	# Draw grid lines
	_draw_grid(canvas)

func _draw_metric_line(canvas: CanvasItem, metric: String, color: Color, min_val: float, max_val: float) -> void:
	if performance_data.size() < 2:
		return
	
	var points: PackedVector2Array = PackedVector2Array()
	
	for i in range(performance_data.size()):
		var data: Dictionary = performance_data[i]
		var value: float = data.get(metric, 0.0)
		var normalized: float = (value - min_val) / (max_val - min_val)
		normalized = clamp(normalized, 0.0, 1.0)
		
		var x: float = (float(i) / float(performance_data.size() - 1)) * graph_width
		var y: float = graph_height - (normalized * graph_height)
		
		points.append(Vector2(x, y))
	
	# Draw the line
	for i in range(points.size() - 1):
		canvas.draw_line(points[i], points[i + 1], color, 2.0)

func _draw_emergency_indicators(canvas: CanvasItem) -> void:
	# Draw red background sections for emergency mode frames
	for i in range(performance_data.size()):
		var data: Dictionary = performance_data[i]
		if data.get("emergency_mode", false):
			var x: float = (float(i) / float(performance_data.size() - 1)) * graph_width
			var rect: Rect2 = Rect2(x - 2, 0, 4, graph_height)
			canvas.draw_rect(rect, Color(1.0, 0.0, 0.0, 0.3))

func _draw_grid(canvas: CanvasItem) -> void:
	var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)
	
	# Horizontal lines (0%, 50%, 100%, 150%, 200%)
	for i in range(5):
		var y: float = (float(i) / 4.0) * graph_height
		canvas.draw_line(Vector2(0, y), Vector2(graph_width, y), grid_color, 1.0)
	
	# Vertical lines (time markers)
	for i in range(5):
		var x: float = (float(i) / 4.0) * graph_width
		canvas.draw_line(Vector2(x, 0), Vector2(x, graph_height), grid_color, 1.0)

# Signal Handlers

func _on_pause_pressed() -> void:
	pause_updates = not pause_updates
	var button: Button = controls_panel.get_child(0) as Button
	button.text = "Resume" if pause_updates else "Pause"

func _on_autoscroll_toggled(pressed: bool) -> void:
	auto_scroll = pressed

func _on_budget_exceeded(agent: WCSAIAgent, budget_ms: float, actual_ms: float) -> void:
	var message: String = "Agent exceeded budget: " + str(actual_ms) + "ms (Budget: " + str(budget_ms) + "ms)"
	add_performance_alert(message, "WARNING")

func _on_budget_critical(usage_percent: float) -> void:
	var message: String = "Critical budget usage: " + str(usage_percent * 100.0) + "%"
	add_performance_alert(message, "CRITICAL")

func _on_budget_exhausted(remaining_agents: int) -> void:
	var message: String = "Frame budget exhausted! " + str(remaining_agents) + " agents skipped"
	add_performance_alert(message, "CRITICAL")

func _on_lod_level_changed(agent: WCSAIAgent, old_level: int, new_level: int) -> void:
	# Could add LOD change tracking here if needed
	pass