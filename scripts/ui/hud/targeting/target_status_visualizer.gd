class_name TargetStatusVisualizer
extends Control

## EPIC-012 HUD-005: Target Status Visualization Component
## Graphical representation of target hull, shields, and status indicators

signal critical_damage()
signal hull_critical(percentage: float)
signal shields_down()
signal status_changed(status_type: String, value: float)

# Visual components
@onready var hull_bar: ProgressBar
@onready var shield_display: Control
@onready var damage_indicator: TextureRect
@onready var threat_level_icon: TextureRect
@onready var status_effect_container: Control

# Shield quadrant displays
var shield_quadrants: Array[ProgressBar] = []

# Current status data
var current_hull_percentage: float = 100.0
var current_shield_quadrants: Array[float] = [100.0, 100.0, 100.0, 100.0]
var current_threat_level: int = 0
var damage_effects_active: bool = false

# Status colors
var status_colors: Dictionary = {
	"critical": Color.RED,
	"damaged": Color.YELLOW,
	"operational": Color.GREEN,
	"unknown": Color.GRAY,
	"shields_up": Color.CYAN,
	"shields_down": Color.ORANGE
}

# Visual configuration
@export var animate_damage: bool = true
@export var flash_critical: bool = true
@export var show_percentages: bool = true

func _init() -> void:
	name = "TargetStatusVisualizer"
	custom_minimum_size = Vector2(300, 100)

func _ready() -> void:
	_setup_status_display()
	_configure_styling()
	print("TargetStatusVisualizer: Initialized")

## Setup status display components
func _setup_status_display() -> void:
	# Create main layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	# Hull status section
	var hull_section = _create_hull_section()
	vbox.add_child(hull_section)
	
	# Shield status section
	var shield_section = _create_shield_section()
	vbox.add_child(shield_section)
	
	# Status indicators section
	var status_section = _create_status_section()
	vbox.add_child(status_section)

## Create hull status display
func _create_hull_section() -> Control:
	var hull_container = HBoxContainer.new()
	
	var hull_label = Label.new()
	hull_label.text = "Hull:"
	hull_label.custom_minimum_size = Vector2(50, 0)
	hull_label.add_theme_font_size_override("font_size", 12)
	hull_container.add_child(hull_label)
	
	hull_bar = ProgressBar.new()
	hull_bar.min_value = 0.0
	hull_bar.max_value = 100.0
	hull_bar.value = 100.0
	hull_bar.custom_minimum_size = Vector2(200, 20)
	hull_bar.show_percentage = show_percentages
	hull_container.add_child(hull_bar)
	
	# Configure hull bar styling
	_configure_hull_bar_styling()
	
	return hull_container

## Create shield status display
func _create_shield_section() -> Control:
	var shield_container = VBoxContainer.new()
	
	var shield_label = Label.new()
	shield_label.text = "Shields:"
	shield_label.add_theme_font_size_override("font_size", 12)
	shield_container.add_child(shield_label)
	
	# Create shield quadrant display
	shield_display = Control.new()
	shield_display.custom_minimum_size = Vector2(100, 50)
	shield_container.add_child(shield_display)
	
	_create_shield_quadrants()
	
	return shield_container

## Create status indicators section
func _create_status_section() -> Control:
	var status_container = HBoxContainer.new()
	
	# Damage indicator
	damage_indicator = TextureRect.new()
	damage_indicator.custom_minimum_size = Vector2(24, 24)
	damage_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_container.add_child(damage_indicator)
	
	# Threat level icon
	threat_level_icon = TextureRect.new()
	threat_level_icon.custom_minimum_size = Vector2(24, 24)
	threat_level_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_container.add_child(threat_level_icon)
	
	# Status effects container
	status_effect_container = Control.new()
	status_effect_container.custom_minimum_size = Vector2(100, 24)
	status_container.add_child(status_effect_container)
	
	return status_container

## Create shield quadrant displays
func _create_shield_quadrants() -> void:
	shield_quadrants.clear()
	
	# Create 4 shield quadrant indicators in cross pattern
	var quadrant_positions = [
		Vector2(25, 0),   # Top
		Vector2(50, 25),  # Right
		Vector2(25, 50),  # Bottom
		Vector2(0, 25)    # Left
	]
	
	for i in range(4):
		var quadrant = ProgressBar.new()
		quadrant.min_value = 0.0
		quadrant.max_value = 100.0
		quadrant.value = 100.0
		quadrant.size = Vector2(20, 20)
		quadrant.position = quadrant_positions[i]
		quadrant.show_percentage = false
		
		# Configure quadrant styling
		_configure_shield_quadrant_styling(quadrant)
		
		shield_display.add_child(quadrant)
		shield_quadrants.append(quadrant)

## Configure hull bar styling
func _configure_hull_bar_styling() -> void:
	if not hull_bar:
		return
	
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.0, 0.0, 0.8)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	hull_bar.add_theme_stylebox_override("background", bg_style)
	
	# Fill style (will be updated based on hull percentage)
	_update_hull_bar_color(100.0)

## Configure shield quadrant styling
func _configure_shield_quadrant_styling(quadrant: ProgressBar) -> void:
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.2, 0.8)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.3, 0.3, 0.5, 1.0)
	quadrant.add_theme_stylebox_override("background", bg_style)
	
	# Fill style
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = status_colors["shields_up"]
	quadrant.add_theme_stylebox_override("fill", fill_style)

## Configure overall styling
func _configure_styling() -> void:
	# Panel background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.05, 0.1, 0.8)
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

## Update hull display
func update_hull_display(percentage: float) -> void:
	current_hull_percentage = clampf(percentage, 0.0, 100.0)
	
	if hull_bar:
		hull_bar.value = current_hull_percentage
		_update_hull_bar_color(current_hull_percentage)
	
	# Check for critical hull damage
	if current_hull_percentage <= 25.0:
		hull_critical.emit(current_hull_percentage)
		if flash_critical:
			_flash_critical_hull()
	
	if current_hull_percentage <= 10.0:
		critical_damage.emit()
	
	status_changed.emit("hull", current_hull_percentage)
	print("TargetStatusVisualizer: Hull updated to %.1f%%" % current_hull_percentage)

## Update shield display
func update_shield_display(quadrants: Array[float]) -> void:
	if quadrants.size() != 4:
		print("TargetStatusVisualizer: Warning - Invalid shield quadrant data")
		return
	
	current_shield_quadrants = quadrants.duplicate()
	
	# Update individual quadrant displays
	for i in range(min(4, shield_quadrants.size())):
		var quadrant_value = clampf(quadrants[i], 0.0, 100.0)
		shield_quadrants[i].value = quadrant_value
		_update_shield_quadrant_color(shield_quadrants[i], quadrant_value)
	
	# Check if all shields are down
	var all_shields_down = true
	for value in quadrants:
		if value > 0.0:
			all_shields_down = false
			break
	
	if all_shields_down:
		shields_down.emit()
		if flash_critical:
			_flash_shields_down()
	
	var total_shields = 0.0
	for value in quadrants:
		total_shields += value
	var average_shields = total_shields / 4.0
	
	status_changed.emit("shields", average_shields)
	print("TargetStatusVisualizer: Shields updated - Average: %.1f%%" % average_shields)

## Update threat display
func update_threat_display(assessment: Dictionary) -> void:
	if assessment.is_empty():
		return
	
	var threat_level = assessment.get("threat_level", 0)
	current_threat_level = threat_level
	
	# Update threat level icon (placeholder - would use actual threat icons)
	if threat_level_icon:
		var threat_color = _get_threat_color(threat_level)
		threat_level_icon.modulate = threat_color
	
	status_changed.emit("threat", float(threat_level))
	print("TargetStatusVisualizer: Threat level updated to %d" % threat_level)

## Show damage effects
func show_damage_effects(damage_level: float) -> void:
	damage_effects_active = true
	
	if damage_indicator:
		# Show damage indicator with intensity based on damage level
		var damage_alpha = clampf(damage_level / 100.0, 0.0, 1.0)
		damage_indicator.modulate = Color(1.0, 0.3, 0.0, damage_alpha)
	
	if animate_damage and damage_level > 50.0:
		_animate_damage_effect()

## Clear all displays
func clear_display() -> void:
	current_hull_percentage = 0.0
	current_shield_quadrants = [0.0, 0.0, 0.0, 0.0]
	current_threat_level = 0
	damage_effects_active = false
	
	if hull_bar:
		hull_bar.value = 0.0
		_update_hull_bar_color(0.0)
	
	for quadrant in shield_quadrants:
		quadrant.value = 0.0
		_update_shield_quadrant_color(quadrant, 0.0)
	
	if damage_indicator:
		damage_indicator.modulate = Color.TRANSPARENT
	
	if threat_level_icon:
		threat_level_icon.modulate = Color.GRAY
	
	print("TargetStatusVisualizer: Display cleared")

## Update hull bar color based on percentage
func _update_hull_bar_color(percentage: float) -> void:
	if not hull_bar:
		return
	
	var fill_style = StyleBoxFlat.new()
	
	if percentage > 75.0:
		fill_style.bg_color = status_colors["operational"]
	elif percentage > 50.0:
		fill_style.bg_color = status_colors["damaged"]
	elif percentage > 25.0:
		fill_style.bg_color = Color.ORANGE
	else:
		fill_style.bg_color = status_colors["critical"]
	
	hull_bar.add_theme_stylebox_override("fill", fill_style)

## Update shield quadrant color
func _update_shield_quadrant_color(quadrant: ProgressBar, percentage: float) -> void:
	var fill_style = StyleBoxFlat.new()
	
	if percentage > 50.0:
		fill_style.bg_color = status_colors["shields_up"]
	elif percentage > 0.0:
		fill_style.bg_color = status_colors["shields_down"]
	else:
		fill_style.bg_color = Color.TRANSPARENT
	
	quadrant.add_theme_stylebox_override("fill", fill_style)

## Get threat color
func _get_threat_color(threat_level: int) -> Color:
	match threat_level:
		0: return Color.GREEN
		1: return Color.YELLOW
		2: return Color.ORANGE
		3: return Color.RED
		4: return Color.MAGENTA
		_: return Color.GRAY

## Visual effects
func _flash_critical_hull() -> void:
	if not hull_bar:
		return
	
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(hull_bar, "modulate", Color.RED, 0.15)
	tween.tween_property(hull_bar, "modulate", Color.WHITE, 0.15)

func _flash_shields_down() -> void:
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(shield_display, "modulate", Color.ORANGE, 0.2)
	tween.tween_property(shield_display, "modulate", Color.WHITE, 0.2)

func _animate_damage_effect() -> void:
	if not damage_indicator:
		return
	
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(damage_indicator, "modulate:a", 1.0, 0.1)
	tween.tween_property(damage_indicator, "modulate:a", 0.3, 0.1)

## Configuration methods
func set_animation_enabled(enabled: bool) -> void:
	animate_damage = enabled

func set_critical_flash_enabled(enabled: bool) -> void:
	flash_critical = enabled

func set_show_percentages(show: bool) -> void:
	show_percentages = show
	if hull_bar:
		hull_bar.show_percentage = show

## Get current status
func get_current_status() -> Dictionary:
	return {
		"hull_percentage": current_hull_percentage,
		"shield_quadrants": current_shield_quadrants.duplicate(),
		"threat_level": current_threat_level,
		"damage_effects_active": damage_effects_active
	}

## Validate component
func validate_component() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	if not hull_bar:
		result.errors.append("Missing hull bar component")
		result.is_valid = false
	
	if shield_quadrants.size() != 4:
		result.errors.append("Invalid shield quadrant count: %d (expected 4)" % shield_quadrants.size())
		result.is_valid = false
	
	if not shield_display:
		result.errors.append("Missing shield display component")
		result.is_valid = false
	
	return result