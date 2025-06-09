class_name TargetInfoPanel
extends Control

## EPIC-012 HUD-005: Target Information Panel Component
## Displays basic target information: name, class, hull, shields, distance, hostility

signal target_info_updated(target_data: Dictionary)

# UI Components
@onready var target_name_label: Label
@onready var target_class_label: Label
@onready var hull_label: Label
@onready var shield_label: Label
@onready var distance_label: Label
@onready var velocity_label: Label
@onready var hostility_indicator: ColorRect
@onready var target_type_icon: TextureRect

# Current data
var current_target_data: Dictionary = {}

# Display configuration
@export var show_precise_distance: bool = true
@export var show_velocity_info: bool = true
@export var distance_unit: String = "m"  # "m", "km", "au"

# Hostility colors
var hostility_colors: Dictionary = {
	"friendly": Color.GREEN,
	"neutral": Color.YELLOW,
	"hostile": Color.RED,
	"unknown": Color.GRAY
}

func _init() -> void:
	name = "TargetInfoPanel"
	custom_minimum_size = Vector2(300, 120)

func _ready() -> void:
	_setup_ui_components()
	_configure_styling()
	print("TargetInfoPanel: Initialized")

## Setup UI components
func _setup_ui_components() -> void:
	# Create main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	# Target identification row
	var id_row = HBoxContainer.new()
	vbox.add_child(id_row)
	
	target_name_label = Label.new()
	target_name_label.text = "No Target"
	target_name_label.add_theme_font_size_override("font_size", 16)
	target_name_label.add_theme_color_override("font_color", Color.WHITE)
	id_row.add_child(target_name_label)
	
	id_row.add_child(VSeparator.new())
	
	target_class_label = Label.new()
	target_class_label.text = ""
	target_class_label.add_theme_font_size_override("font_size", 12)
	target_class_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	id_row.add_child(target_class_label)
	
	# Status row
	var status_row = HBoxContainer.new()
	vbox.add_child(status_row)
	
	hull_label = Label.new()
	hull_label.text = "Hull: ---%"
	hull_label.add_theme_font_size_override("font_size", 12)
	status_row.add_child(hull_label)
	
	status_row.add_child(VSeparator.new())
	
	shield_label = Label.new()
	shield_label.text = "Shields: ---%"
	shield_label.add_theme_font_size_override("font_size", 12)
	status_row.add_child(shield_label)
	
	# Info row
	var info_row = HBoxContainer.new()
	vbox.add_child(info_row)
	
	distance_label = Label.new()
	distance_label.text = "Distance: ---"
	distance_label.add_theme_font_size_override("font_size", 11)
	info_row.add_child(distance_label)
	
	info_row.add_child(VSeparator.new())
	
	velocity_label = Label.new()
	velocity_label.text = "Velocity: ---"
	velocity_label.add_theme_font_size_override("font_size", 11)
	info_row.add_child(velocity_label)
	
	# Hostility indicator row
	var hostility_row = HBoxContainer.new()
	vbox.add_child(hostility_row)
	
	var hostility_label = Label.new()
	hostility_label.text = "Status:"
	hostility_label.add_theme_font_size_override("font_size", 11)
	hostility_row.add_child(hostility_label)
	
	hostility_indicator = ColorRect.new()
	hostility_indicator.custom_minimum_size = Vector2(60, 16)
	hostility_indicator.color = hostility_colors["unknown"]
	hostility_row.add_child(hostility_indicator)
	
	# Target type icon (placeholder)
	target_type_icon = TextureRect.new()
	target_type_icon.custom_minimum_size = Vector2(32, 32)
	target_type_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Position in top-right corner
	target_type_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	add_child(target_type_icon)

## Configure styling
func _configure_styling() -> void:
	# Panel background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.4, 0.4, 0.4, 1.0)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", style_box)

## Update target information display
func update_target_info(target_data: Dictionary) -> void:
	current_target_data = target_data
	
	# Update target identification
	var target_name = target_data.get("name", "Unknown Target")
	var target_class = target_data.get("class", "Unknown Class")
	var target_type = target_data.get("type", "Unknown Type")
	
	target_name_label.text = target_name
	target_class_label.text = "%s (%s)" % [target_class, target_type]
	
	# Update status information
	var hull_percentage = target_data.get("hull_percentage", 0.0)
	var shield_percentage = target_data.get("shield_percentage", 0.0)
	
	hull_label.text = "Hull: %d%%" % hull_percentage
	shield_label.text = "Shields: %d%%" % shield_percentage
	
	# Color code hull status
	if hull_percentage > 75.0:
		hull_label.add_theme_color_override("font_color", Color.GREEN)
	elif hull_percentage > 50.0:
		hull_label.add_theme_color_override("font_color", Color.YELLOW)
	elif hull_percentage > 25.0:
		hull_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		hull_label.add_theme_color_override("font_color", Color.RED)
	
	# Color code shield status
	if shield_percentage > 50.0:
		shield_label.add_theme_color_override("font_color", Color.CYAN)
	elif shield_percentage > 25.0:
		shield_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		shield_label.add_theme_color_override("font_color", Color.ORANGE)
	
	# Update distance and velocity
	var distance = target_data.get("distance", 0.0)
	var velocity = target_data.get("velocity", Vector3.ZERO)
	
	distance_label.text = "Distance: %s" % _format_distance(distance)
	
	if show_velocity_info:
		var speed = velocity.length()
		velocity_label.text = "Velocity: %d m/s" % speed
	else:
		velocity_label.text = ""
	
	# Update hostility indicator
	var hostility = target_data.get("hostility", "unknown")
	var hostility_color = hostility_colors.get(hostility, hostility_colors["unknown"])
	hostility_indicator.color = hostility_color
	
	# Add hostility text
	var hostility_text = Label.new()
	hostility_text.text = hostility.capitalize()
	hostility_text.add_theme_font_size_override("font_size", 10)
	hostility_text.add_theme_color_override("font_color", hostility_color)
	
	target_info_updated.emit(target_data)
	print("TargetInfoPanel: Updated target info for %s" % target_name)

## Format distance for display
func _format_distance(distance: float) -> String:
	if not show_precise_distance:
		if distance < 1000.0:
			return "Close"
		elif distance < 5000.0:
			return "Medium"
		else:
			return "Long"
	
	match distance_unit:
		"km":
			if distance >= 1000.0:
				return "%.1f km" % (distance / 1000.0)
			else:
				return "%d m" % distance
		"au":
			if distance >= 149597870.7:  # 1 AU in meters
				return "%.3f AU" % (distance / 149597870.7)
			elif distance >= 1000000.0:
				return "%.1f Mkm" % (distance / 1000000.0)
			elif distance >= 1000.0:
				return "%.1f km" % (distance / 1000.0)
			else:
				return "%d m" % distance
		_:  # meters
			if distance >= 1000.0:
				return "%.1f km" % (distance / 1000.0)
			else:
				return "%d m" % distance

## Clear target information display
func clear_display() -> void:
	current_target_data.clear()
	
	target_name_label.text = "No Target"
	target_class_label.text = ""
	hull_label.text = "Hull: ---%"
	shield_label.text = "Shields: ---%"
	distance_label.text = "Distance: ---"
	velocity_label.text = "Velocity: ---"
	hostility_indicator.color = hostility_colors["unknown"]
	
	# Reset label colors
	hull_label.add_theme_color_override("font_color", Color.WHITE)
	shield_label.add_theme_color_override("font_color", Color.WHITE)
	
	print("TargetInfoPanel: Display cleared")

## Set display configuration
func set_distance_precision(precise: bool) -> void:
	show_precise_distance = precise
	if current_target_data.has("distance"):
		distance_label.text = "Distance: %s" % _format_distance(current_target_data["distance"])

func set_distance_unit(unit: String) -> void:
	if unit in ["m", "km", "au"]:
		distance_unit = unit
		if current_target_data.has("distance"):
			distance_label.text = "Distance: %s" % _format_distance(current_target_data["distance"])

func set_velocity_display(show: bool) -> void:
	show_velocity_info = show
	if not show:
		velocity_label.visible = false
	else:
		velocity_label.visible = true
		if current_target_data.has("velocity"):
			var velocity = current_target_data["velocity"]
			var speed = velocity.length() if velocity is Vector3 else 0.0
			velocity_label.text = "Velocity: %d m/s" % speed

## Get current target data
func get_target_data() -> Dictionary:
	return current_target_data.duplicate()

## Validate panel state
func validate_panel() -> Dictionary:
	var result = {
		"is_valid": true,
		"errors": [],
		"warnings": []
	}
	
	if not target_name_label:
		result.errors.append("Missing target name label")
		result.is_valid = false
	
	if not target_class_label:
		result.errors.append("Missing target class label")
		result.is_valid = false
	
	if not hull_label:
		result.errors.append("Missing hull label")
		result.is_valid = false
	
	if not shield_label:
		result.errors.append("Missing shield label")
		result.is_valid = false
	
	if not distance_label:
		result.errors.append("Missing distance label")
		result.is_valid = false
	
	if not hostility_indicator:
		result.errors.append("Missing hostility indicator")
		result.is_valid = false
	
	return result