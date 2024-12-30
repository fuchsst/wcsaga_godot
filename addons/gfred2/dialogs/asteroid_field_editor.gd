@tool
extends "res://addons/gfred2/dialogs/base_dialog.gd"

# Field properties
var enabled := false
var is_active_field := true
var is_asteroid := true
var field_colors := {
	"brown": false,
	"blue": false,
	"orange": false
}
var ship_types := ["", "", ""]
var number := 10
var avg_speed := 100.0

# Box dimensions
var outer_box := {
	"min_x": -1000.0,
	"max_x": 1000.0,
	"min_y": -1000.0,
	"max_y": 1000.0,
	"min_z": -1000.0,
	"max_z": 1000.0
}

var inner_box := {
	"enabled": false,
	"min_x": -500.0,
	"max_x": 500.0,
	"min_y": -500.0,
	"max_y": 500.0,
	"min_z": -500.0,
	"max_z": 500.0
}

# UI Controls
var enabled_check: CheckBox
var active_field_btn: CheckBox
var passive_field_btn: CheckBox
var asteroid_btn: CheckBox
var ship_btn: CheckBox
var color_checks := {}
var ship_type_options := []
var number_spin: SpinBox
var speed_edit: LineEdit
var inner_enabled_check: CheckBox

# Box dimension edits
var outer_box_edits := {}
var inner_box_edits := {}

func _ready():
	super._ready()
	title = "Asteroid Field Editor"
	
	var content = get_content_container()
	
	# Create main layout with spacing
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	content.add_child(hbox)
	
	# Left side - Field properties
	var left_panel = VBoxContainer.new()
	left_panel.add_theme_constant_override("separation", 10)
	hbox.add_child(left_panel)
	
	enabled_check = CheckBox.new()
	enabled_check.text = "Enabled"
	enabled_check.toggled.connect(_on_enabled_toggled)
	left_panel.add_child(enabled_check)
	
	# Field type group
	var type_group = VBoxContainer.new()
	type_group.add_theme_constant_override("separation", 5)
	left_panel.add_child(type_group)
	
	active_field_btn = CheckBox.new()
	active_field_btn.text = "Active Field"
	active_field_btn.button_group = ButtonGroup.new()
	active_field_btn.toggled.connect(_on_field_type_changed)
	type_group.add_child(active_field_btn)
	
	passive_field_btn = CheckBox.new()
	passive_field_btn.text = "Passive Field"
	passive_field_btn.button_group = active_field_btn.button_group
	type_group.add_child(passive_field_btn)
	
	# Object type group
	var obj_group = VBoxContainer.new()
	obj_group.add_theme_constant_override("separation", 5)
	left_panel.add_child(obj_group)
	
	asteroid_btn = CheckBox.new()
	asteroid_btn.text = "Asteroid"
	asteroid_btn.button_group = ButtonGroup.new()
	asteroid_btn.toggled.connect(_on_object_type_changed)
	obj_group.add_child(asteroid_btn)
	
	ship_btn = CheckBox.new()
	ship_btn.text = "Ship"
	ship_btn.button_group = asteroid_btn.button_group
	obj_group.add_child(ship_btn)
	
	# Color/ship type grid
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	left_panel.add_child(grid)
	
	for color in ["Brown", "Blue", "Orange"]:
		var check = CheckBox.new()
		check.text = color
		check.toggled.connect(_on_color_toggled.bind(color.to_lower()))
		grid.add_child(check)
		color_checks[color.to_lower()] = check
		
		var option = OptionButton.new()
		option.visible = false
		grid.add_child(option)
		ship_type_options.append(option)
	
	# Number and speed
	var num_box = HBoxContainer.new()
	num_box.add_theme_constant_override("separation", 10)
	left_panel.add_child(num_box)
	
	num_box.add_child(_create_label("Number:"))
	number_spin = SpinBox.new()
	number_spin.min_value = 0
	number_spin.max_value = 100
	number_spin.value = number
	number_spin.value_changed.connect(_on_number_changed)
	num_box.add_child(number_spin)
	
	var speed_box = HBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 10)
	left_panel.add_child(speed_box)
	
	speed_box.add_child(_create_label("Avg. Speed:"))
	speed_edit = LineEdit.new()
	speed_edit.text = str(avg_speed)
	speed_edit.text_submitted.connect(_on_speed_changed)
	speed_box.add_child(speed_edit)
	
	# Right side - Box dimensions
	var right_panel = VBoxContainer.new()
	right_panel.add_theme_constant_override("separation", 20)
	hbox.add_child(right_panel)
	
	# Outer box
	var outer_box_panel = VBoxContainer.new()
	outer_box_panel.add_theme_constant_override("separation", 10)
	right_panel.add_child(outer_box_panel)
	outer_box_panel.add_child(_create_label("Outer Box"))
	
	var outer_grid = GridContainer.new()
	outer_grid.columns = 2
	outer_grid.add_theme_constant_override("h_separation", 10)
	outer_grid.add_theme_constant_override("v_separation", 5)
	outer_box_panel.add_child(outer_grid)
	
	for axis in ["x", "y", "z"]:
		for minmax in ["min", "max"]:
			outer_grid.add_child(_create_label(minmax.capitalize() + " " + axis.to_upper() + ":"))
			
			var edit = LineEdit.new()
			edit.text = str(outer_box[minmax + "_" + axis])
			edit.text_submitted.connect(_on_outer_box_changed.bind(minmax + "_" + axis))
			outer_grid.add_child(edit)
			outer_box_edits[minmax + "_" + axis] = edit
	
	# Inner box
	var inner_box_panel = VBoxContainer.new()
	inner_box_panel.add_theme_constant_override("separation", 10)
	right_panel.add_child(inner_box_panel)
	
	inner_enabled_check = CheckBox.new()
	inner_enabled_check.text = "Enable Inner Box"
	inner_enabled_check.toggled.connect(_on_inner_enabled_toggled)
	inner_box_panel.add_child(inner_enabled_check)
	
	var inner_grid = GridContainer.new()
	inner_grid.columns = 2
	inner_grid.add_theme_constant_override("h_separation", 10)
	inner_grid.add_theme_constant_override("v_separation", 5)
	inner_box_panel.add_child(inner_grid)
	
	for axis in ["x", "y", "z"]:
		for minmax in ["min", "max"]:
			inner_grid.add_child(_create_label(minmax.capitalize() + " " + axis.to_upper() + ":"))
			
			var edit = LineEdit.new()
			edit.text = str(inner_box[minmax + "_" + axis])
			edit.text_submitted.connect(_on_inner_box_changed.bind(minmax + "_" + axis))
			inner_grid.add_child(edit)
			inner_box_edits[minmax + "_" + axis] = edit
	
	# Set initial state
	_update_ui()
	
	# Set dialog size
	size = Vector2(600, 400)
	show_dialog(Vector2(600, 400))

func _update_ui():
	enabled_check.button_pressed = enabled
	active_field_btn.button_pressed = is_active_field
	passive_field_btn.button_pressed = !is_active_field
	asteroid_btn.button_pressed = is_asteroid
	ship_btn.button_pressed = !is_asteroid
	
	for color in field_colors:
		color_checks[color].button_pressed = field_colors[color]
	
	for i in range(3):
		ship_type_options[i].visible = !is_asteroid
	
	number_spin.value = number
	speed_edit.text = str(avg_speed)
	
	inner_enabled_check.button_pressed = inner_box.enabled
	
	# Update box dimension edits
	for key in outer_box:
		if outer_box_edits.has(key):
			outer_box_edits[key].text = str(outer_box[key])
			
	for key in inner_box:
		if key != "enabled" and inner_box_edits.has(key):
			inner_box_edits[key].text = str(inner_box[key])
			inner_box_edits[key].editable = inner_box.enabled

func _on_enabled_toggled(pressed: bool):
	enabled = pressed

func _on_field_type_changed(pressed: bool):
	is_active_field = active_field_btn.button_pressed

func _on_object_type_changed(pressed: bool):
	is_asteroid = asteroid_btn.button_pressed
	_update_ui()

func _on_color_toggled(pressed: bool, color: String):
	field_colors[color] = pressed

func _on_number_changed(value: float):
	number = int(value)

func _on_speed_changed(value: String):
	avg_speed = float(value)

func _on_inner_enabled_toggled(pressed: bool):
	inner_box.enabled = pressed
	_update_ui()

func _on_outer_box_changed(value: String, key: String):
	outer_box[key] = float(value)

func _on_inner_box_changed(value: String, key: String):
	inner_box[key] = float(value)
