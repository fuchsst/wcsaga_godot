class_name SubsystemDisplay
extends Control

## EPIC-012 HUD-005: Subsystem Status Display Component
## Shows individual subsystem health and targeting interface

signal subsystem_selected(subsystem_name: String)
signal subsystem_targeted(subsystem_name: String)
signal subsystem_critical(subsystem_name: String, health: float)

# Subsystem data structure
class SubsystemInfo:
	var name: String
	var health: float
	var operational: bool
	var critical: bool
	var targetable: bool

# UI Components
@onready var subsystem_grid: GridContainer
@onready var targeting_cursor: Control
@onready var subsystem_labels: Dictionary = {}
@onready var subsystem_bars: Dictionary = {}

# Current subsystem data
var current_subsystems: Dictionary = {}
var selected_subsystem: String = ""
var targetable_subsystems: Array[String] = []

# Standard WCS subsystems
var standard_subsystems: Array[String] = [
	"engines",
	"weapons",
	"sensors",
	"communication",
	"navigation",
	"turret_base",
	"cargo_bay",
	"fighter_bay"
]

# Subsystem display configuration
@export var show_health_bars: bool = true
@export var show_percentages: bool = true
@export var allow_targeting: bool = true
@export var highlight_critical: bool = true

# Colors
var subsystem_colors: Dictionary = {
	"operational": Color.GREEN,
	"damaged": Color.YELLOW,
	"critical": Color.ORANGE,
	"destroyed": Color.RED,
	"unknown": Color.GRAY
}

func _init() -> void:
	name = "SubsystemDisplay"
	custom_minimum_size = Vector2(300, 80)

func _ready() -> void:
	_setup_subsystem_display()
	_configure_styling()
	print("SubsystemDisplay: Initialized")

## Setup subsystem display
func _setup_subsystem_display() -> void:
	# Create main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	# Subsystem header
	var header = Label.new()
	header.text = "Subsystems"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(header)
	
	# Subsystem grid
	subsystem_grid = GridContainer.new()
	subsystem_grid.columns = 2
	subsystem_grid.custom_minimum_size = Vector2(280, 60)
	vbox.add_child(subsystem_grid)
	
	# Initialize standard subsystems
	_initialize_standard_subsystems()
	
	# Targeting cursor (initially hidden)
	targeting_cursor = Control.new()
	targeting_cursor.custom_minimum_size = Vector2(4, 4)
	targeting_cursor.visible = false
	add_child(targeting_cursor)
	
	_configure_targeting_cursor()

## Initialize standard subsystem displays
func _initialize_standard_subsystems() -> void:
	# Create display elements for standard subsystems
	for subsystem_name in standard_subsystems:
		_create_subsystem_display(subsystem_name)

## Create display for a specific subsystem
func _create_subsystem_display(subsystem_name: String) -> void:
	# Subsystem container
	var subsystem_container = HBoxContainer.new()
	subsystem_container.custom_minimum_size = Vector2(130, 20)
	subsystem_grid.add_child(subsystem_container)
	
	# Subsystem label
	var label = Label.new()
	label.text = subsystem_name.capitalize()
	label.custom_minimum_size = Vector2(70, 20)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	subsystem_container.add_child(label)
	subsystem_labels[subsystem_name] = label
	
	# Health bar (if enabled)
	if show_health_bars:
		var health_bar = ProgressBar.new()
		health_bar.min_value = 0.0
		health_bar.max_value = 100.0
		health_bar.value = 100.0
		health_bar.custom_minimum_size = Vector2(50, 16)
		health_bar.show_percentage = show_percentages
		subsystem_container.add_child(health_bar)
		subsystem_bars[subsystem_name] = health_bar
		
		# Configure health bar styling
		_configure_subsystem_bar_styling(health_bar)
		
		# Make clickable for targeting
		if allow_targeting:
			_make_subsystem_targetable(subsystem_container, subsystem_name)

## Configure subsystem bar styling
func _configure_subsystem_bar_styling(bar: ProgressBar) -> void:
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	bar.add_theme_stylebox_override("background", bg_style)
	
	# Fill style (will be updated based on health)
	_update_subsystem_bar_color(bar, 100.0)

## Make subsystem targetable
func _make_subsystem_targetable(container: Control, subsystem_name: String) -> void:
	# Add click detection
	container.gui_input.connect(_on_subsystem_clicked.bind(subsystem_name))
	container.mouse_entered.connect(_on_subsystem_mouse_entered.bind(subsystem_name))
	container.mouse_exited.connect(_on_subsystem_mouse_exited.bind(subsystem_name))
	
	# Add to targetable list
	if not targetable_subsystems.has(subsystem_name):
		targetable_subsystems.append(subsystem_name)

## Configure targeting cursor
func _configure_targeting_cursor() -> void:
	# Create cursor visual
	targeting_cursor.draw.connect(_draw_targeting_cursor)
	
	# Cursor style
	var cursor_style = StyleBoxFlat.new()
	cursor_style.bg_color = Color.YELLOW
	cursor_style.border_width_left = 2
	cursor_style.border_width_right = 2
	cursor_style.border_width_top = 2
	cursor_style.border_width_bottom = 2
	cursor_style.border_color = Color.RED
	targeting_cursor.add_theme_stylebox_override("panel", cursor_style)

## Configure overall styling
func _configure_styling() -> void:
	# Panel background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style_box.corner_radius_top_left = 3
	style_box.corner_radius_top_right = 3
	style_box.corner_radius_bottom_left = 3
	style_box.corner_radius_bottom_right = 3
	
	add_theme_stylebox_override("panel", style_box)

## Update subsystem status
func update_subsystem_status(subsystems: Dictionary) -> void:
	current_subsystems = subsystems.duplicate()
	
	# Update each subsystem display
	for subsystem_name in subsystems:
		var subsystem_data = subsystems[subsystem_name]
		_update_subsystem_display(subsystem_name, subsystem_data)
	
	# Hide subsystems not in current data
	for subsystem_name in subsystem_labels:
		if not subsystems.has(subsystem_name):
			_hide_subsystem_display(subsystem_name)
	
	print("SubsystemDisplay: Updated %d subsystems" % subsystems.size())

## Update individual subsystem display
func _update_subsystem_display(subsystem_name: String, data: Dictionary) -> void:
	var health = data.get("health", 0.0)
	var operational = data.get("operational", false)
	var critical = data.get("critical", false)
	
	# Update label color
	if subsystem_labels.has(subsystem_name):
		var label = subsystem_labels[subsystem_name]
		label.visible = true
		
		if not operational:
			label.add_theme_color_override("font_color", subsystem_colors["destroyed"])
		elif critical:
			label.add_theme_color_override("font_color", subsystem_colors["critical"])
		elif health > 75.0:
			label.add_theme_color_override("font_color", subsystem_colors["operational"])
		elif health > 50.0:
			label.add_theme_color_override("font_color", subsystem_colors["damaged"])
		else:
			label.add_theme_color_override("font_color", subsystem_colors["critical"])
	
	# Update health bar
	if subsystem_bars.has(subsystem_name):
		var bar = subsystem_bars[subsystem_name]
		bar.visible = true
		bar.value = health
		_update_subsystem_bar_color(bar, health)
		
		# Flash if critical
		if critical and highlight_critical:
			_flash_critical_subsystem(bar)
	
	# Check for critical damage
	if health <= 25.0 or critical:
		subsystem_critical.emit(subsystem_name, health)
	
	print("SubsystemDisplay: Updated %s - Health: %.1f%%, Operational: %s" % [subsystem_name, health, operational])

## Hide subsystem display
func _hide_subsystem_display(subsystem_name: String) -> void:
	if subsystem_labels.has(subsystem_name):
		subsystem_labels[subsystem_name].visible = false
	
	if subsystem_bars.has(subsystem_name):
		subsystem_bars[subsystem_name].visible = false

## Update subsystem bar color
func _update_subsystem_bar_color(bar: ProgressBar, health: float) -> void:
	var fill_style = StyleBoxFlat.new()
	
	if health > 75.0:
		fill_style.bg_color = subsystem_colors["operational"]
	elif health > 50.0:
		fill_style.bg_color = subsystem_colors["damaged"]
	elif health > 25.0:
		fill_style.bg_color = subsystem_colors["critical"]
	else:
		fill_style.bg_color = subsystem_colors["destroyed"]
	
	bar.add_theme_stylebox_override("fill", fill_style)

## Select subsystem for targeting
func select_subsystem(subsystem_name: String) -> void:
	if not targetable_subsystems.has(subsystem_name):
		print("SubsystemDisplay: Warning - Subsystem not targetable: %s" % subsystem_name)
		return
	
	selected_subsystem = subsystem_name
	_position_targeting_cursor(subsystem_name)
	targeting_cursor.visible = true
	
	subsystem_selected.emit(subsystem_name)
	print("SubsystemDisplay: Selected subsystem: %s" % subsystem_name)

## Clear subsystem selection
func clear_selection() -> void:
	selected_subsystem = ""
	targeting_cursor.visible = false
	print("SubsystemDisplay: Selection cleared")

## Position targeting cursor
func _position_targeting_cursor(subsystem_name: String) -> void:
	if not subsystem_bars.has(subsystem_name):
		return
	
	var bar = subsystem_bars[subsystem_name]
	var bar_pos = bar.global_position - global_position
	targeting_cursor.position = bar_pos - Vector2(2, 2)
	targeting_cursor.size = bar.size + Vector2(4, 4)

## Clear all displays
func clear_display() -> void:
	current_subsystems.clear()
	selected_subsystem = ""
	targeting_cursor.visible = false
	
	# Hide all subsystem displays
	for subsystem_name in subsystem_labels:
		_hide_subsystem_display(subsystem_name)
	
	print("SubsystemDisplay: Display cleared")

## Visual effects
func _flash_critical_subsystem(bar: ProgressBar) -> void:
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(bar, "modulate", Color.RED, 0.2)
	tween.tween_property(bar, "modulate", Color.WHITE, 0.2)

## Draw targeting cursor
func _draw_targeting_cursor() -> void:
	if not targeting_cursor.visible:
		return
	
	var rect = Rect2(Vector2.ZERO, targeting_cursor.size)
	targeting_cursor.draw_rect(rect, Color.YELLOW, false, 2.0)
	
	# Draw corner indicators
	var corner_size = 4
	targeting_cursor.draw_line(Vector2(0, 0), Vector2(corner_size, 0), Color.RED, 2.0)
	targeting_cursor.draw_line(Vector2(0, 0), Vector2(0, corner_size), Color.RED, 2.0)
	
	targeting_cursor.draw_line(Vector2(rect.size.x, 0), Vector2(rect.size.x - corner_size, 0), Color.RED, 2.0)
	targeting_cursor.draw_line(Vector2(rect.size.x, 0), Vector2(rect.size.x, corner_size), Color.RED, 2.0)
	
	targeting_cursor.draw_line(Vector2(0, rect.size.y), Vector2(corner_size, rect.size.y), Color.RED, 2.0)
	targeting_cursor.draw_line(Vector2(0, rect.size.y), Vector2(0, rect.size.y - corner_size), Color.RED, 2.0)
	
	targeting_cursor.draw_line(Vector2(rect.size.x, rect.size.y), Vector2(rect.size.x - corner_size, rect.size.y), Color.RED, 2.0)
	targeting_cursor.draw_line(Vector2(rect.size.x, rect.size.y), Vector2(rect.size.x, rect.size.y - corner_size), Color.RED, 2.0)

## Input handlers
func _on_subsystem_clicked(subsystem_name: String, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_subsystem(subsystem_name)
		subsystem_targeted.emit(subsystem_name)

func _on_subsystem_mouse_entered(subsystem_name: String) -> void:
	# Highlight subsystem on hover
	if subsystem_bars.has(subsystem_name):
		var bar = subsystem_bars[subsystem_name]
		bar.modulate = Color(1.2, 1.2, 1.0, 1.0)

func _on_subsystem_mouse_exited(subsystem_name: String) -> void:
	# Remove highlight
	if subsystem_bars.has(subsystem_name):
		var bar = subsystem_bars[subsystem_name]
		bar.modulate = Color.WHITE

## Configuration methods
func set_show_health_bars(show: bool) -> void:
	show_health_bars = show
	for bar in subsystem_bars.values():
		bar.visible = show

func set_show_percentages(show: bool) -> void:
	show_percentages = show
	for bar in subsystem_bars.values():
		bar.show_percentage = show

func set_allow_targeting(allow: bool) -> void:
	allow_targeting = allow
	if not allow:
		clear_selection()

func set_highlight_critical(highlight: bool) -> void:
	highlight_critical = highlight

## Get current data
func get_current_subsystems() -> Dictionary:
	return current_subsystems.duplicate()

func get_selected_subsystem() -> String:
	return selected_subsystem

func get_targetable_subsystems() -> Array[String]:
	return targetable_subsystems.duplicate()

## Validate component
func validate_component() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	if not subsystem_grid:
		result.errors.append("Missing subsystem grid")
		result.is_valid = false
	
	if not targeting_cursor:
		result.errors.append("Missing targeting cursor")
		result.is_valid = false
	
	if subsystem_labels.is_empty():
		result.warnings.append("No subsystem labels created")
	
	if subsystem_bars.is_empty() and show_health_bars:
		result.warnings.append("No subsystem bars created but health bars enabled")
	
	return result