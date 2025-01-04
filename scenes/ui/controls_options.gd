extends Control

# Sound effects
@export var sounds: GameSounds

# Sound indices from game_sounds.tres
const HOVER_SOUND = 17  # snd_user_over
const CLICK_SOUND = 18  # snd_user_select
const ERROR_SOUND = 10  # snd_general_fail
const ACCEPT_SOUND = 7  # snd_commit_pressed
const CANCEL_SOUND = 8  # snd_prev_next_pressed

# Current state
var current_tab := "target"
var binding_mode := false
var binding_control: Control = null
var binding_type := "" # "key" or "joy" or "mouse" or "axis"
var conflicts := {}
var current_pilot: PilotData = null

# Control configuration data
var target_control_config := {}
var ship_control_config := {}
var weapon_control_config := {}
var computer_control_config := {}
var axis_config := {}

# Backup configs for cancel operation
var target_control_config_backup := {}
var ship_control_config_backup := {}
var weapon_control_config_backup := {}
var computer_control_config_backup := {}
var axis_config_backup := {}
var undo_stack: Array[Dictionary] = []

# UI references
@onready var tab_panels := {
	"Targeting": $TabPanels/TargetControls,
	"Ship": $TabPanels/ShipControls,
	"Weapons": $TabPanels/WeaponControls,
	"Misc": $TabPanels/ComputerControls
}

func _ready() -> void:
	# Get current pilot
	current_pilot = GameState.active_pilot
	if current_pilot == null:
		push_error("No pilot selected")
		return

	load_control_config()
	connect_signals()
	switch_to_tab("Targeting")
	populate_controls()

func connect_signals() -> void:
	# Connect tab button signals
	for tab in tab_panels:
		var button = get_node("TabButtons/" + tab)
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
	# Get control configs from pilot or defaults
	target_control_config = current_pilot.target_control_config if !current_pilot.target_control_config.is_empty() else PilotData.DEFAULT_TARGET_CONTROLS.duplicate(true)
	ship_control_config = current_pilot.ship_control_config if !current_pilot.ship_control_config.is_empty() else PilotData.DEFAULT_SHIP_CONTROLS.duplicate(true)
	weapon_control_config = current_pilot.weapon_control_config if !current_pilot.weapon_control_config.is_empty() else PilotData.DEFAULT_WEAPON_CONTROLS.duplicate(true)
	computer_control_config = current_pilot.computer_control_config if !current_pilot.computer_control_config.is_empty() else PilotData.DEFAULT_COMPUTER_CONTROLS.duplicate(true)
	axis_config = current_pilot.axis_config if !current_pilot.axis_config.is_empty() else PilotData.DEFAULT_AXIS_CONFIG.duplicate(true)
	
	# Clear existing controls
	for tab in tab_panels:
		var container = tab_panels[tab].get_node("ScrollContainer/VBoxContainer")
		for child in container.get_children():
			child.queue_free()
	
	# Target Controls
	var target_container = tab_panels["Targeting"].get_node("ScrollContainer/VBoxContainer")
	for action in target_control_config:
		add_control_line(target_container, action, target_control_config[action])
	
	# Ship Controls
	var ship_container = tab_panels["Ship"].get_node("ScrollContainer/VBoxContainer")
	for action in ship_control_config:
		add_control_line(ship_container, action, ship_control_config[action])
	
	# Add axis controls to ship tab
	for axis in axis_config:
		add_axis_line(ship_container, axis, axis_config[axis])
	
	# Weapon Controls
	var weapon_container = tab_panels["Weapons"].get_node("ScrollContainer/VBoxContainer")
	for action in weapon_control_config:
		add_control_line(weapon_container, action, weapon_control_config[action])
	
	# Computer Controls
	var computer_container = tab_panels["Misc"].get_node("ScrollContainer/VBoxContainer")
	for action in computer_control_config:
		add_control_line(computer_container, action, computer_control_config[action])

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
	
	# Set joy binding
	if binding.joy >= 0:
		line.joy_button = binding.joy
		
	# Set mouse binding
	if binding.mouse >= 0:
		line.mouse_button = binding.mouse
	
	# Set name for identification
	line.name = action
	
	# Connect signals
	line.get_node("KeyButton").pressed.connect(func(): start_key_binding(line))
	line.get_node("JoyButton").pressed.connect(func(): start_joy_binding(line))
	line.get_node("MouseButton").pressed.connect(func(): start_mouse_binding(line))

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
	# Store backups for cancel operation
	target_control_config_backup = target_control_config.duplicate(true)
	ship_control_config_backup = ship_control_config.duplicate(true)
	weapon_control_config_backup = weapon_control_config.duplicate(true)
	computer_control_config_backup = computer_control_config.duplicate(true)
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

func get_mouse_name(button: int) -> String:
	if button < 0:
		return ""
		
	match button:
		MOUSE_BUTTON_LEFT: return "Left Click"
		MOUSE_BUTTON_RIGHT: return "Right Click"
		MOUSE_BUTTON_MIDDLE: return "Middle Click"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT: return "Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT: return "Wheel Right"
		MOUSE_BUTTON_XBUTTON1: return "X-Button 1"
		MOUSE_BUTTON_XBUTTON2: return "X-Button 2"
		_: return "Button " + str(button)

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
				
				# Get shift and alt modifiers
				var mod := 0
				if Input.is_key_pressed(KEY_SHIFT):
					mod |= KEY_SHIFT
				if Input.is_key_pressed(KEY_ALT):
					mod |= KEY_ALT
				
				# Get action and config from control line
				var action = binding_control.get_parent().name
				var config = _get_config_for_action(action)
				
				if config:
					config[action].key = event.keycode
					config[action].mod = mod
				
				# Update control line
				binding_control.get_parent().key = event.keycode
				binding_control.get_parent().alt_modifier = (mod & KEY_ALT) != 0
				binding_control.get_parent().shift_modifier = (mod & KEY_SHIFT) != 0
				
				# Exit binding mode
				binding_mode = false
				binding_control.get_parent().modulate = Color(1, 1, 1, 1)
				binding_control = null
				check_conflicts()
				
		"joy":
			if event is InputEventJoypadButton and event.pressed:
				# Save current state for undo
				save_undo_state()
				
				# Get action and config from control line
				var action = binding_control.get_parent().name
				var config = _get_config_for_action(action)
				
				if config:
					config[action].joy = event.button_index
				
				# Update control line
				binding_control.get_parent().joy_button = event.button_index
				
				# Exit binding mode
				binding_mode = false
				binding_control.get_parent().modulate = Color(1, 1, 1, 1)
				binding_control = null
				check_conflicts()
				
		"mouse":
			if event is InputEventMouseButton and event.pressed:
				# Save current state for undo
				save_undo_state()
				
				# Get action and config from control line
				var action = binding_control.get_parent().name
				var config = _get_config_for_action(action)
				
				if config:
					config[action].mouse = event.button_index
				
				# Update control line
				binding_control.get_parent().mouse_button = event.button_index
				
				# Exit binding mode
				binding_mode = false
				binding_control.get_parent().modulate = Color(1, 1, 1, 1)
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
				
				# Exit binding mode
				binding_mode = false
				binding_control.get_parent().modulate = Color(1, 1, 1, 1)
				binding_control = null
				check_conflicts()

func start_key_binding(line: ControlLine) -> void:
	binding_mode = true
	binding_type = "key"
	binding_control = line.get_node("KeyButton")
	
	# Add visual feedback for current edited key
	for tab in tab_panels:
		var container = tab_panels[tab].get_node("ScrollContainer/VBoxContainer")
		for control_line in container.get_children():
			if control_line == line:
				line.modulate = Color(0.75, 0.6, 0.6, 0.8) # Highlight yellow
			elif control_line is ControlLine:
				control_line.modulate = Color(1, 1, 1, 1)

func start_joy_binding(line: ControlLine) -> void:
	binding_mode = true
	binding_type = "joy"
	binding_control = line.get_node("JoyButton")
	
	# Add visual feedback for current edited key
	for tab in tab_panels:
		var container = tab_panels[tab].get_node("ScrollContainer/VBoxContainer")
		for control_line in container.get_children():
			if control_line == line:
				line.modulate = Color(0.75, 0.6, 0.6, 0.8) # Highlight yellow
			elif control_line is ControlLine:
				control_line.modulate = Color(1, 1, 1, 1)

func start_mouse_binding(line: ControlLine) -> void:
	binding_mode = true
	binding_type = "mouse"
	binding_control = line.get_node("MouseButton")
	
	# Add visual feedback for current edited key
	for tab in tab_panels:
		var container = tab_panels[tab].get_node("ScrollContainer/VBoxContainer")
		for control_line in container.get_children():
			if control_line == line:
				line.modulate = Color(0.75, 0.6, 0.6, 0.8) # Highlight yellow
			elif control_line is ControlLine:
				control_line.modulate = Color(1, 1, 1, 1)

func start_axis_binding(line: Control) -> void:
	binding_mode = true
	binding_type = "axis"
	binding_control = line.get_node("AxisButton")
	
	# Add visual feedback for current edited key
	for tab in tab_panels:
		var container = tab_panels[tab].get_node("ScrollContainer/VBoxContainer")
		for control_line in container.get_children():
			if control_line == line:
				line.modulate = Color(0.75, 0.6, 0.6, 0.8) # Highlight yellow
			elif control_line is ControlLine:
				control_line.modulate = Color(1, 1, 1, 1)

func clear_selected_binding() -> void:
	if binding_control == null:
		return
		
	save_undo_state()
	
	var line = binding_control.get_parent()
	var action = line.name
	var config = _get_config_for_action(action)
	
	match binding_type:
		"key":
			if config:
				config[action].key = -1
				config[action].mod = 0
				line.key = -1
				line.alt_modifier = false
				line.shift_modifier = false
		"joy":
			if config:
				config[action].joy = -1
				line.joy_button = -1
		"mouse":
			if config:
				config[action].mouse = -1
				line.mouse_button = -1
		"axis":
			if action in axis_config:
				axis_config[action].axis = -1
				line.get_node("AxisButton/AxisLabel").text = "None"
	
	# Reset visual feedback
	line.modulate = Color(1, 1, 1, 1)
	binding_mode = false
	binding_control = null
	
	check_conflicts()
	play_click_sound()

func clear_all_bindings() -> void:
	save_undo_state()
	
	for action in target_control_config:
		target_control_config[action].key = -1
		target_control_config[action].joy = -1
		target_control_config[action].mouse = -1
		target_control_config[action].mod = 0
		
	for action in ship_control_config:
		ship_control_config[action].key = -1
		ship_control_config[action].joy = -1
		ship_control_config[action].mouse = -1
		ship_control_config[action].mod = 0
		
	for action in weapon_control_config:
		weapon_control_config[action].key = -1
		weapon_control_config[action].joy = -1
		weapon_control_config[action].mouse = -1
		weapon_control_config[action].mod = 0
		
	for action in computer_control_config:
		computer_control_config[action].key = -1
		computer_control_config[action].joy = -1
		computer_control_config[action].mouse = -1
		computer_control_config[action].mod = 0
		
	for axis in axis_config:
		axis_config[axis].axis = -1
		
	update_control_texts()
	check_conflicts()

func check_conflicts() -> void:
	conflicts.clear()
	
	# Check for duplicate key bindings across all configs
	var used_keys := {}
	var used_joys := {}
	var used_mice := {}
	var used_axes := {}
	
	var all_configs = {}
	all_configs.merge(target_control_config)
	all_configs.merge(ship_control_config)
	all_configs.merge(weapon_control_config)
	all_configs.merge(computer_control_config)

	for action in all_configs:
		var binding = all_configs[action]
		var key = binding.key
		var mod = binding.mod
		var joy = binding.joy
		var mouse = binding.mouse
		
		if key >= 0:
			var key_id = str(key) + "_" + str(mod)
			if key_id in used_keys:
				conflicts[action] = {"key": used_keys[key_id], "joy": -1, "mouse": -1}
				conflicts[used_keys[key_id]] = {"key": action, "joy": -1, "mouse": -1}
			else:
				used_keys[key_id] = action
				
		if joy >= 0:
			if joy in used_joys:
				conflicts[action] = {"key": -1, "joy": used_joys[joy], "mouse": -1}
				conflicts[used_joys[joy]] = {"key": -1, "joy": action, "mouse": -1}
			else:
				used_joys[joy] = action
				
		if mouse >= 0:
			if mouse in used_mice:
				conflicts[action] = {"key": -1, "joy": -1, "mouse": used_mice[mouse]}
				conflicts[used_mice[mouse]] = {"key": -1, "joy": -1, "mouse": action}
			else:
				used_mice[mouse] = action
				
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
		
	pilot_data.target_control_config = target_control_config.duplicate(true)
	pilot_data.ship_control_config = ship_control_config.duplicate(true)
	pilot_data.weapon_control_config = weapon_control_config.duplicate(true)
	pilot_data.computer_control_config = computer_control_config.duplicate(true)
	pilot_data.axis_config = axis_config.duplicate(true)
	
	play_accept_sound()
	get_tree().change_scene_to_file("res://scenes/ui/options.tscn")

func cancel_changes() -> void:
	target_control_config = target_control_config_backup.duplicate(true)
	ship_control_config = ship_control_config_backup.duplicate(true)
	weapon_control_config = weapon_control_config_backup.duplicate(true)
	computer_control_config = computer_control_config_backup.duplicate(true)
	axis_config = axis_config_backup.duplicate(true)
	play_cancel_sound()
	get_tree().change_scene_to_file("res://scenes/ui/options.tscn")

func reset_to_defaults() -> void:
	save_undo_state()
	target_control_config.clear()
	ship_control_config.clear()
	weapon_control_config.clear()
	computer_control_config.clear()
	axis_config.clear()
	load_control_config()
	update_control_texts()
	check_conflicts()

func save_undo_state() -> void:
	var state := {
		"target_control_config": target_control_config.duplicate(true),
		"ship_control_config": ship_control_config.duplicate(true),
		"weapon_control_config": weapon_control_config.duplicate(true),
		"computer_control_config": computer_control_config.duplicate(true),
		"axis_config": axis_config.duplicate(true)
	}
	undo_stack.push_back(state)

func undo_last_change() -> void:
	if undo_stack.is_empty():
		return
		
	var state = undo_stack.pop_back()
	target_control_config = state.target_control_config.duplicate(true)
	ship_control_config = state.ship_control_config.duplicate(true)
	weapon_control_config = state.weapon_control_config.duplicate(true)
	computer_control_config = state.computer_control_config.duplicate(true)
	axis_config = state.axis_config.duplicate(true)
	update_control_texts()
	check_conflicts()

# Helper function to get the appropriate config for an action
func _get_config_for_action(action: String) -> Dictionary:
	if action in target_control_config:
		return target_control_config
	elif action in ship_control_config:
		return ship_control_config
	elif action in weapon_control_config:
		return weapon_control_config
	elif action in computer_control_config:
		return computer_control_config
	return {}

func update_control_line(line: Control, action: String) -> void:
	var config = _get_config_for_action(action)
	if not config:
		return
		
	# Update key binding text
	var key_label = line.get_node("KeyButton/KeyLabel")
	key_label.text = get_key_name(config[action].key, config[action].mod)
	
	# Update joy binding text
	var joy_label = line.get_node("JoyButton/JoyLabel")
	joy_label.text = get_joy_name(config[action].joy)
	
	# Update mouse binding text
	var mouse_label = line.get_node("MouseButton/MouseLabel")
	mouse_label.text = get_mouse_name(config[action].mouse)
	
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
			
		if conflicts[action].mouse >= 0:
			mouse_label.modulate = Color.RED
		else:
			mouse_label.modulate = Color.WHITE
	else:
		key_label.modulate = Color.WHITE
		joy_label.modulate = Color.WHITE
		mouse_label.modulate = Color.WHITE

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
		var config = _get_config_for_action(action)
		if config:
			if conflicts[action].key >= 0:
				config[action].key = -1
				config[action].mod = 0
			if conflicts[action].joy >= 0:
				config[action].joy = -1
			if conflicts[action].mouse >= 0:
				config[action].mouse = -1
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
			
		if conflict.mouse >= 0:
			var label = template.duplicate()
			label.text = "%s conflicts with %s (Mouse binding)" % [action, conflict.mouse]
			label.visible = true
			list.add_child(label)
			shown_conflicts[action] = true
			shown_conflicts[conflict.mouse] = true
			
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
