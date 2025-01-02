extends Control

# Sound effects
@export var sounds: GameSounds

# Sound indices from tbl file
const HOVER_SOUND = 36  # Using HOTSPOT_ON_SOUND from original code
const CLICK_SOUND = 37  # Using HOTSPOT_OFF_SOUND from original code
const ERROR_SOUND = 38  # Using AMBIENT_LOOP_SOUND from original code
const ACCEPT_SOUND = 39  # Using next available index
const CANCEL_SOUND = 40  # Using next available index

# Current state
var current_tab := "target"
var binding_mode := false
var binding_control: Control = null
var binding_type := "" # "key" or "joy" or "axis"
var conflicts := {}
var current_pilot: PilotData = null

# Control configuration data
var control_config := {}
var control_config_backup := {}
var axis_config := {}
var axis_config_backup := {}
var undo_stack: Array[Dictionary] = []

# UI references
@onready var tab_panels := {
	"target": $TabPanels/TargetControls,
	"ship": $TabPanels/ShipControls,
	"weapon": $TabPanels/WeaponControls,
	"computer": $TabPanels/ComputerControls
}

func _ready() -> void:
	# Get current pilot
	current_pilot = GameState.current_pilot
	if current_pilot == null:
		push_error("No pilot selected")
		return
		
	# Load current control configuration
	load_control_config()
	
	# Connect signals
	connect_signals()
	
	# Show initial tab
	switch_to_tab("target")
	
	# Populate controls
	populate_controls()

func connect_signals() -> void:
	# Connect tab button signals
	for tab in tab_panels:
		var button = get_node("TabButtons/" + tab.capitalize())
		button.pressed.connect(func(): switch_to_tab(tab))
		button.mouse_entered.connect(func(): play_hover_sound())

	for button in $ActionButtons.get_children():
		button.mouse_entered.connect(func(): play_hover_sound())
	
	# Connect popup signals
	$ConflictWarning/VBoxContainer/HBoxContainer/OkButton.pressed.connect(func(): 
		$ConflictWarning.hide()
		play_click_sound()
	)
	$ConflictWarning/VBoxContainer/HBoxContainer/ClearConflictsButton.pressed.connect(func():
		clear_conflicts()
		play_click_sound()
	)
	$ControlsHelp/VBoxContainer/HBoxContainer/CloseButton.pressed.connect(func(): 
		$ControlsHelp.hide()
		play_click_sound()
	)
	
	# Connect popup button hover sounds
	$ConflictWarning/VBoxContainer/HBoxContainer/OkButton.mouse_entered.connect(func(): play_hover_sound())
	$ConflictWarning/VBoxContainer/HBoxContainer/ClearConflictsButton.mouse_entered.connect(func(): play_hover_sound())
	$ControlsHelp/VBoxContainer/HBoxContainer/CloseButton.mouse_entered.connect(func(): play_hover_sound())

func populate_controls() -> void:
	# Get control config from pilot or defaults
	var config = current_pilot.control_config if !current_pilot.control_config.is_empty() else PilotData.DEFAULT_CONTROL_CONFIG
	var axis_cfg = current_pilot.axis_config if !current_pilot.axis_config.is_empty() else PilotData.DEFAULT_AXIS_CONFIG
	
	# Clear existing controls
	for tab in tab_panels:
		var container = tab_panels[tab].get_node("ScrollContainer/VBoxContainer")
		for child in container.get_children():
			child.queue_free()
	
	# Target Controls
	var target_container = tab_panels["target"].get_node("ScrollContainer/VBoxContainer")
	for action in ["target_next", "target_prev", "target_nearest_hostile", "target_prev_hostile",
				  "target_nearest_friendly", "target_prev_friendly", "target_in_reticle",
				  "target_attacking_target", "target_last_sender", "clear_target",
				  "target_subsystem", "next_subsystem", "prev_subsystem", "clear_subsystem"]:
		add_control_line(target_container, action, config[action])
	
	# Ship Controls
	var ship_container = tab_panels["ship"].get_node("ScrollContainer/VBoxContainer")
	for action in ["pitch_forward", "pitch_back", "yaw_left", "yaw_right", "roll_left", "roll_right",
				  "throttle_up", "throttle_down", "throttle_zero", "throttle_full",
				  "throttle_one_third", "throttle_two_thirds", "throttle_plus_5", "throttle_minus_5",
				  "afterburner", "glide_when_pressed", "toggle_glide"]:
		add_control_line(ship_container, action, config[action])
	
	# Add axis controls to ship tab
	for axis in ["pitch", "yaw", "roll", "throttle_abs", "throttle_rel"]:
		add_axis_line(ship_container, axis, axis_cfg[axis])
	
	# Weapon Controls
	var weapon_container = tab_panels["weapon"].get_node("ScrollContainer/VBoxContainer")
	for action in ["fire_primary", "fire_secondary", "next_primary", "prev_primary",
				  "cycle_secondary", "cycle_secondary_bank", "launch_countermeasure"]:
		add_control_line(weapon_container, action, config[action])
	
	# Computer Controls
	var computer_container = tab_panels["computer"].get_node("ScrollContainer/VBoxContainer")
	for action in ["match_target_speed", "toggle_auto_match", "view_chase", "view_external",
				  "view_target", "view_dist_in", "view_dist_out", "view_center",
				  "comm_menu", "show_objectives", "end_mission"]:
		add_control_line(computer_container, action, config[action])

func add_control_line(container: Node, action: String, binding: Dictionary) -> void:
	var line = preload("res://scenes/ui/control_line.tscn").instantiate()
	container.add_child(line)
	
	# Set label
	line.label_text = action.capitalize().replace("_", " ")
	
	# Set key binding
	if binding.key >= 0:
		line.key = binding.key
		line.alt_modifier = (binding.mod & KEY_ALT) != 0
		line.shift_modifier = (binding.mod & KEY_SHIFT) != 0
		line.ctrl_modifier = (binding.mod & KEY_CTRL) != 0
	
	# Set joy binding
	if binding.joy >= 0:
		line.joy_button = binding.joy
	
	# Set name for identification
	line.name = action
	
	# Connect signals
	line.get_node("KeyButton").pressed.connect(func(): start_key_binding(line))
	line.get_node("JoyButton").pressed.connect(func(): start_joy_binding(line))

func add_axis_line(container: Node, axis: String, config: Dictionary) -> void:
	var line = preload("res://scenes/ui/axis_line.tscn").instantiate()
	container.add_child(line)
	
	# Set label
	line.get_node("Label").text = axis.capitalize().replace("_", " ") + " Axis"
	
	# Set axis binding
	if config.axis >= 0:
		line.get_node("AxisButton/AxisLabel").text = "Axis " + str(config.axis)
	
	# Set invert state
	line.get_node("InvertButton/InvertLabel").text = "Inverted" if config.invert else "Normal"
	
	# Set name for identification
	line.name = axis
	
	# Connect signals
	line.get_node("AxisButton").pressed.connect(func(): start_axis_binding(line))
	line.get_node("InvertButton").pressed.connect(func(): toggle_axis_invert(line))

func load_control_config() -> void:
	if current_pilot.control_config.is_empty():
		current_pilot.control_config = PilotData.DEFAULT_CONTROL_CONFIG
		current_pilot.axis_config = PilotData.DEFAULT_AXIS_CONFIG
	
	# Store backups for cancel operation
	control_config = current_pilot.control_config.duplicate(true)
	control_config_backup = control_config.duplicate(true)
	axis_config = current_pilot.axis_config.duplicate(true)
	axis_config_backup = axis_config.duplicate(true)

func switch_to_tab(tab: String) -> void:
	# Hide all panels
	for t in tab_panels:
		tab_panels[t].hide()
	
	# Show selected panel
	tab_panels[tab].show()
	
	# Update tab button states
	for t in tab_panels:
		var button = get_node("TabButtons/" + t.capitalize())
		button.button_pressed = (t == tab)

func update_control_texts() -> void:
	# Update all control lines
	for tab in tab_panels:
		var container = tab_panels[tab].get_node("ScrollContainer/VBoxContainer")
		for line in container.get_children():
			if line is ControlLine:
				update_control_line(line, line.name)
			else:
				update_axis_line(line, line.name)

func get_key_name(key: int, mod: int = 0) -> String:
	if key < 0:
		return "None"
		
	var text := ""
	
	# Add modifiers
	if mod & KEY_SHIFT:
		text += "Shift+"
	if mod & KEY_ALT:
		text += "Alt+"
		
	# Add main key
	text += OS.get_keycode_string(key)
	return text

func get_joy_name(joy: int) -> String:
	if joy < 0:
		return "None"
	return "Button " + str(joy)

func get_axis_name(axis: int) -> String:
	if axis < 0:
		return "None"
	return "Axis " + str(axis)

func _input(event: InputEvent) -> void:
	if binding_mode:
		handle_binding_input(event)

func handle_binding_input(event: InputEvent) -> void:
	if !binding_mode or binding_control == null:
		return
		
	match binding_type:
		"key":
			if event is InputEventKey and event.pressed:
				# Check if this is a modifier key
				if event.keycode in [KEY_SHIFT, KEY_ALT]:
					return
					
				# Save current state for undo
				save_undo_state()
				
				# Get modifiers
				var mod := 0
				if Input.is_key_pressed(KEY_SHIFT):
					mod |= KEY_SHIFT
				if Input.is_key_pressed(KEY_ALT):
					mod |= KEY_ALT
					
				# Get action from control line
				var action = binding_control.get_parent().name
				
				# Update control config
				control_config[action].key = event.keycode
				control_config[action].mod = mod
				
				# Update control line
				binding_control.get_parent().key = event.keycode
				binding_control.get_parent().alt_modifier = (mod & KEY_ALT) != 0
				binding_control.get_parent().shift_modifier = (mod & KEY_SHIFT) != 0
				binding_control.get_parent().ctrl_modifier = (mod & KEY_CTRL) != 0
				
				binding_mode = false
				binding_control = null
				check_conflicts()
				
		"joy":
			if event is InputEventJoypadButton and event.pressed:
				# Save current state for undo
				save_undo_state()
				
				# Get action from control line
				var action = binding_control.get_parent().name
				
				# Update control config
				control_config[action].joy = event.button_index
				
				# Update control line
				binding_control.get_parent().joy_button = event.button_index
				
				binding_mode = false
				binding_control = null
				check_conflicts()
				
		"axis":
			if event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
				# Save current state for undo
				save_undo_state()
				
				# Get axis from control line
				var axis = binding_control.get_parent().name
				
				# Update axis config
				axis_config[axis].axis = event.axis
				
				# Update axis line
				binding_control.get_parent().get_node("AxisButton/AxisLabel").text = "Axis " + str(event.axis)
				
				binding_mode = false
				binding_control = null
				check_conflicts()

func start_key_binding(line: ControlLine) -> void:
	binding_mode = true
	binding_type = "key"
	binding_control = line.get_node("KeyButton")

func start_joy_binding(line: ControlLine) -> void:
	binding_mode = true
	binding_type = "joy"
	binding_control = line.get_node("JoyButton")

func start_axis_binding(line: Control) -> void:
	binding_mode = true
	binding_type = "axis"
	binding_control = line.get_node("AxisButton")

func clear_selected_binding() -> void:
	if binding_control == null:
		return
		
	save_undo_state()
	
	var line = binding_control.get_parent()
	var action = line.name
	
	match binding_type:
		"key":
			control_config[action].key = -1
			control_config[action].mod = 0
			line.key = -1
			line.alt_modifier = false
			line.shift_modifier = false
			line.ctrl_modifier = false
		"joy":
			control_config[action].joy = -1
			line.joy_button = -1
		"axis":
			axis_config[action].axis = -1
			line.get_node("AxisButton/AxisLabel").text = "None"
	
	check_conflicts()

func clear_all_bindings() -> void:
	save_undo_state()
	
	for action in control_config:
		control_config[action].key = -1
		control_config[action].joy = -1
		control_config[action].mod = 0
		
	for axis in axis_config:
		axis_config[axis].axis = -1
		
	update_control_texts()
	check_conflicts()

func check_conflicts() -> void:
	conflicts.clear()
	
	# Check for duplicate key bindings
	var used_keys := {}
	var used_joys := {}
	var used_axes := {}
	
	for action in control_config:
		var binding = control_config[action]
		var key = binding.key
		var mod = binding.mod
		var joy = binding.joy
		
		if key >= 0:
			var key_id = str(key) + "_" + str(mod)
			if key_id in used_keys:
				conflicts[action] = {"key": used_keys[key_id], "joy": -1}
				conflicts[used_keys[key_id]] = {"key": action, "joy": -1}
			else:
				used_keys[key_id] = action
				
		if joy >= 0:
			if joy in used_joys:
				conflicts[action] = {"key": -1, "joy": used_joys[joy]}
				conflicts[used_joys[joy]] = {"key": -1, "joy": action}
			else:
				used_joys[joy] = action
				
	# Check for duplicate axis bindings
	for axis in axis_config:
		var axis_num = axis_config[axis].axis
		if axis_num >= 0:
			if axis_num in used_axes:
				conflicts[axis] = {"axis": used_axes[axis_num]}
				conflicts[used_axes[axis_num]] = {"axis": axis}
			else:
				used_axes[axis_num] = axis

func accept_changes() -> void:
	if !conflicts.is_empty():
		# Show conflict warning
		$ConflictWarning.popup_centered()
		play_error_sound()
		return
		
	# Save to current pilot
	var pilot_data = GameState.current_pilot
	if pilot_data == null:
		push_error("No pilot selected")
		return
		
	pilot_data.control_config = control_config.duplicate(true)
	pilot_data.axis_config = axis_config.duplicate(true)
	
	# Also update GameSettings for defaults
	var settings := GameSettings.load_or_create()
	settings.control_config = control_config.duplicate(true)
	settings.save()
	
	play_accept_sound()
	get_tree().change_scene_to_file("res://scenes/ui/options.tscn")

func cancel_changes() -> void:
	control_config = control_config_backup.duplicate(true)
	axis_config = axis_config_backup.duplicate(true)
	play_cancel_sound()
	get_tree().change_scene_to_file("res://scenes/ui/options.tscn")

func reset_to_defaults() -> void:
	save_undo_state()
	control_config.clear()
	axis_config.clear()
	load_control_config()
	update_control_texts()
	check_conflicts()

func save_undo_state() -> void:
	var state := {
		"control_config": control_config.duplicate(true),
		"axis_config": axis_config.duplicate(true)
	}
	undo_stack.push_back(state)

func undo_last_change() -> void:
	if undo_stack.is_empty():
		return
		
	var state = undo_stack.pop_back()
	control_config = state.control_config.duplicate(true)
	axis_config = state.axis_config.duplicate(true)
	update_control_texts()
	check_conflicts()

func update_control_line(line: Control, action: String) -> void:
	# Update key binding text
	var key_label = line.get_node("KeyButton/KeyLabel")
	key_label.text = get_key_name(control_config[action].key, control_config[action].mod)
	
	# Update joy binding text
	var joy_label = line.get_node("JoyButton/JoyLabel")
	joy_label.text = get_joy_name(control_config[action].joy)
	
	# Update colors based on conflicts
	if action in conflicts:
		if conflicts[action].key >= 0:
			key_label.modulate = Color.RED
		else:
			key_label.modulate = Color.WHITE
			
		if conflicts[action].joy >= 0:
			joy_label.modulate = Color.RED
		else:
			joy_label.modulate = Color.WHITE
	else:
		key_label.modulate = Color.WHITE
		joy_label.modulate = Color.WHITE

func update_axis_line(line: Control, axis: String) -> void:
	# Update axis binding text
	var axis_label = line.get_node("AxisButton/AxisLabel")
	axis_label.text = get_axis_name(axis_config[axis].axis)
	
	# Update invert button text
	var invert_label = line.get_node("InvertButton/InvertLabel")
	invert_label.text = "Inverted" if axis_config[axis].invert else "Normal"
	
	# Update colors based on conflicts
	if axis in conflicts:
		axis_label.modulate = Color.RED
	else:
		axis_label.modulate = Color.WHITE

func toggle_axis_invert(line: Control) -> void:
	save_undo_state()
	
	# Get axis name from control line
	var axis = line.name
	
	# Toggle invert state
	axis_config[axis].invert = !axis_config[axis].invert
	
	# Update UI
	update_axis_line(line, axis)

func clear_conflicts() -> void:
	save_undo_state()
	
	# Clear key conflicts
	for action in conflicts:
		if conflicts[action].key >= 0:
			control_config[action].key = -1
			control_config[action].mod = 0
		if conflicts[action].joy >= 0:
			control_config[action].joy = -1
		if "axis" in conflicts[action]:
			axis_config[action].axis = -1
	
	# Update UI
	update_control_texts()
	check_conflicts()
	$ConflictWarning.hide()

func show_conflicts() -> void:
	if conflicts.is_empty():
		return
		
	# Clear conflict list
	var list = $ConflictWarning/VBoxContainer/ConflictList
	var template = list.get_node("ConflictTemplate")
	
	for child in list.get_children():
		if child != template:
			child.queue_free()
	
	# Add conflict entries
	var shown_conflicts := {}
	for action in conflicts:
		if action in shown_conflicts:
			continue
			
		var conflict = conflicts[action]
		if conflict.key >= 0:
			var label = template.duplicate()
			label.text = "%s conflicts with %s (Key binding)" % [action, conflict.key]
			label.visible = true
			list.add_child(label)
			shown_conflicts[action] = true
			shown_conflicts[conflict.key] = true
			
		if conflict.joy >= 0:
			var label = template.duplicate()
			label.text = "%s conflicts with %s (Joy binding)" % [action, conflict.joy]
			label.visible = true
			list.add_child(label)
			shown_conflicts[action] = true
			shown_conflicts[conflict.joy] = true
			
		if "axis" in conflict:
			var label = template.duplicate()
			label.text = "%s axis conflicts with %s" % [action, conflict.axis]
			label.visible = true
			list.add_child(label)
			shown_conflicts[action] = true
			shown_conflicts[conflict.axis] = true
	
	$ConflictWarning.popup_centered()

func _play_interface_sound(index: int) -> void:
	var entry = sounds.interface_sounds[index]
	if not entry:
		return
		
	var stream = entry.audio_file
	if not stream:
		return
		
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.volume_db = linear_to_db(entry.volume)
	player.finished.connect(func(): player.queue_free())
	player.play()

func play_hover_sound() -> void:
	_play_interface_sound(HOVER_SOUND)

func play_click_sound() -> void:
	_play_interface_sound(CLICK_SOUND)

func play_error_sound() -> void:
	_play_interface_sound(ERROR_SOUND)

func play_accept_sound() -> void:
	_play_interface_sound(ACCEPT_SOUND)

func play_cancel_sound() -> void:
	_play_interface_sound(CANCEL_SOUND)

func show_help() -> void:
	$ControlsHelp.popup_centered()
	play_click_sound()


func _on_bind_button_pressed() -> void:
	if binding_control != null:
		clear_selected_binding()
		play_click_sound()

func _on_clear_pressed() -> void:
	clear_conflicts()
	play_click_sound()

func _on_clear_all_pressed() -> void:
	clear_all_bindings()
	play_click_sound()

func _on_clear_selected_pressed() -> void:
	clear_selected_binding()
	play_click_sound()

func _on_undo_pressed() -> void:
	undo_last_change()
	play_click_sound()

func _on_cancel_button_pressed() -> void:
	cancel_changes()

func _on_search_button_pressed() -> void:
	# TODO: Implement search functionality
	play_click_sound()

func _on_reset_button_pressed() -> void:
	reset_to_defaults()
	play_click_sound()

func _on_help_pressed() -> void:
	show_help()

func _on_accept_pressed() -> void:
	accept_changes()
