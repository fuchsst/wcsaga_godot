@tool
extends AcceptDialog

## Shortcut Configuration Dialog for GFRED2
## Provides UI for customizing keyboard shortcuts with accessibility support.

signal shortcuts_changed()

# UI components
var category_tree: Tree
var shortcut_list: Tree
var current_shortcut_label: Label
var new_shortcut_input: LineEdit
var conflict_label: Label
var reset_button: Button
var reset_all_button: Button

# Accessibility UI
var accessibility_panel: Panel
var sticky_keys_checkbox: CheckBox
var slow_keys_checkbox: CheckBox
var slow_keys_spinbox: SpinBox
var bounce_keys_checkbox: CheckBox
var bounce_keys_spinbox: SpinBox

# Manager reference
var shortcut_manager: GFRED2ShortcutManager
var theme_manager: GFRED2ThemeManager

# Current state
var selected_action: String = ""
var waiting_for_input: bool = false

func _init() -> void:
	title = "Keyboard Shortcuts"
	size = Vector2i(800, 600)
	_setup_ui()

func set_managers(shortcut_mgr: GFRED2ShortcutManager, theme_mgr: GFRED2ThemeManager) -> void:
	"""Set the manager references."""
	shortcut_manager = shortcut_mgr
	theme_manager = theme_mgr
	
	if theme_manager:
		theme_manager.apply_theme_to_control(self)
	
	if shortcut_manager:
		shortcut_manager.shortcut_changed.connect(_on_shortcut_changed)
		shortcut_manager.conflict_detected.connect(_on_conflict_detected)
		_populate_categories()

func _setup_ui() -> void:
	"""Setup the dialog UI."""
	# Main container
	var main_container = VBoxContainer.new()
	add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 8)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Select an action and press a key combination to assign a new shortcut. Use accessibility options below for adaptive input."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_container.add_child(instructions)
	
	# Main content splitter
	var main_splitter = HSplitContainer.new()
	main_splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(main_splitter)
	
	# Left panel (categories)
	var left_panel = _create_left_panel()
	main_splitter.add_child(left_panel)
	
	# Right panel (shortcuts and settings)
	var right_panel = _create_right_panel()
	main_splitter.add_child(right_panel)
	
	# Set initial split
	main_splitter.split_offset = 200
	
	# Button bar
	var button_bar = _create_button_bar()
	main_container.add_child(button_bar)

func _create_left_panel() -> Control:
	"""Create the category selection panel."""
	var panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(180, 0)
	
	# Category label
	var category_label = Label.new()
	category_label.text = "Categories"
	category_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(category_label)
	
	# Category tree
	category_tree = Tree.new()
	category_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_tree.hide_root = true
	category_tree.focus_mode = Control.FOCUS_ALL
	category_tree.item_selected.connect(_on_category_selected)
	panel.add_child(category_tree)
	
	return panel

func _create_right_panel() -> Control:
	"""Create the shortcuts and settings panel."""
	var splitter = VSplitContainer.new()
	splitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Shortcuts panel
	var shortcuts_panel = _create_shortcuts_panel()
	splitter.add_child(shortcuts_panel)
	
	# Accessibility panel
	accessibility_panel = _create_accessibility_panel()
	splitter.add_child(accessibility_panel)
	
	# Set initial split
	splitter.split_offset = 350
	
	return splitter

func _create_shortcuts_panel() -> Control:
	"""Create the shortcuts list panel."""
	var panel = VBoxContainer.new()
	
	# Shortcuts label
	var shortcuts_label = Label.new()
	shortcuts_label.text = "Shortcuts"
	shortcuts_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(shortcuts_label)
	
	# Shortcut list
	shortcut_list = Tree.new()
	shortcut_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shortcut_list.columns = 2
	shortcut_list.set_column_title(0, "Action")
	shortcut_list.set_column_title(1, "Shortcut")
	shortcut_list.set_column_expand(0, true)
	shortcut_list.set_column_expand(1, false)
	shortcut_list.set_column_custom_minimum_width(1, 120)
	shortcut_list.column_titles_visible = true
	shortcut_list.hide_root = true
	shortcut_list.focus_mode = Control.FOCUS_ALL
	shortcut_list.item_selected.connect(_on_shortcut_selected)
	panel.add_child(shortcut_list)
	
	# Shortcut editing area
	var edit_area = _create_shortcut_edit_area()
	panel.add_child(edit_area)
	
	return panel

func _create_shortcut_edit_area() -> Control:
	"""Create the shortcut editing controls."""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	
	# Current shortcut display
	var current_container = HBoxContainer.new()
	var current_label_text = Label.new()
	current_label_text.text = "Current:"
	current_label_text.custom_minimum_size = Vector2(80, 0)
	current_container.add_child(current_label_text)
	
	current_shortcut_label = Label.new()
	current_shortcut_label.text = "None"
	current_shortcut_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current_container.add_child(current_shortcut_label)
	container.add_child(current_container)
	
	# New shortcut input
	var input_container = HBoxContainer.new()
	var input_label = Label.new()
	input_label.text = "New:"
	input_label.custom_minimum_size = Vector2(80, 0)
	input_container.add_child(input_label)
	
	new_shortcut_input = LineEdit.new()
	new_shortcut_input.placeholder_text = "Press keys to assign shortcut..."
	new_shortcut_input.editable = false
	new_shortcut_input.focus_mode = Control.FOCUS_ALL
	new_shortcut_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_shortcut_input.gui_input.connect(_on_shortcut_input)
	input_container.add_child(new_shortcut_input)
	
	var clear_button = Button.new()
	clear_button.text = "Clear"
	clear_button.focus_mode = Control.FOCUS_ALL
	clear_button.pressed.connect(_clear_shortcut_input)
	input_container.add_child(clear_button)
	container.add_child(input_container)
	
	# Conflict warning
	conflict_label = Label.new()
	conflict_label.text = ""
	conflict_label.modulate = Color.YELLOW
	conflict_label.visible = false
	container.add_child(conflict_label)
	
	# Action buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 8)
	
	var assign_button = Button.new()
	assign_button.text = "Assign"
	assign_button.focus_mode = Control.FOCUS_ALL
	assign_button.pressed.connect(_assign_shortcut)
	button_container.add_child(assign_button)
	
	reset_button = Button.new()
	reset_button.text = "Reset to Default"
	reset_button.focus_mode = Control.FOCUS_ALL
	reset_button.pressed.connect(_reset_shortcut)
	button_container.add_child(reset_button)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(spacer)
	container.add_child(button_container)
	
	return container

func _create_accessibility_panel() -> Control:
	"""Create the accessibility settings panel."""
	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	
	# Accessibility label
	var accessibility_label = Label.new()
	accessibility_label.text = "Accessibility Options"
	accessibility_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(accessibility_label)
	
	# Sticky keys
	sticky_keys_checkbox = CheckBox.new()
	sticky_keys_checkbox.text = "Sticky Keys - Hold modifier keys without keeping them pressed"
	sticky_keys_checkbox.focus_mode = Control.FOCUS_ALL
	sticky_keys_checkbox.toggled.connect(_on_sticky_keys_toggled)
	panel.add_child(sticky_keys_checkbox)
	
	# Slow keys
	var slow_keys_container = HBoxContainer.new()
	slow_keys_checkbox = CheckBox.new()
	slow_keys_checkbox.text = "Slow Keys - Delay before accepting keypresses:"
	slow_keys_checkbox.focus_mode = Control.FOCUS_ALL
	slow_keys_checkbox.toggled.connect(_on_slow_keys_toggled)
	slow_keys_container.add_child(slow_keys_checkbox)
	
	slow_keys_spinbox = SpinBox.new()
	slow_keys_spinbox.min_value = 0.1
	slow_keys_spinbox.max_value = 2.0
	slow_keys_spinbox.step = 0.1
	slow_keys_spinbox.value = 0.5
	slow_keys_spinbox.suffix = "s"
	slow_keys_spinbox.focus_mode = Control.FOCUS_ALL
	slow_keys_spinbox.value_changed.connect(_on_slow_keys_delay_changed)
	slow_keys_container.add_child(slow_keys_spinbox)
	panel.add_child(slow_keys_container)
	
	# Bounce keys
	var bounce_keys_container = HBoxContainer.new()
	bounce_keys_checkbox = CheckBox.new()
	bounce_keys_checkbox.text = "Bounce Keys - Ignore rapid keypresses:"
	bounce_keys_checkbox.focus_mode = Control.FOCUS_ALL
	bounce_keys_checkbox.toggled.connect(_on_bounce_keys_toggled)
	bounce_keys_container.add_child(bounce_keys_checkbox)
	
	bounce_keys_spinbox = SpinBox.new()
	bounce_keys_spinbox.min_value = 0.1
	bounce_keys_spinbox.max_value = 1.0
	bounce_keys_spinbox.step = 0.1
	bounce_keys_spinbox.value = 0.5
	bounce_keys_spinbox.suffix = "s"
	bounce_keys_spinbox.focus_mode = Control.FOCUS_ALL
	bounce_keys_spinbox.value_changed.connect(_on_bounce_keys_delay_changed)
	bounce_keys_container.add_child(bounce_keys_spinbox)
	panel.add_child(bounce_keys_container)
	
	# Help text
	var help_text = Label.new()
	help_text.text = "These options help users with motor impairments use keyboard shortcuts more easily."
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.add_theme_font_size_override("font_size", 11)
	help_text.modulate = Color(0.8, 0.8, 0.8)
	panel.add_child(help_text)
	
	return panel

func _create_button_bar() -> Control:
	"""Create the dialog button bar."""
	var button_bar = HBoxContainer.new()
	button_bar.add_theme_constant_override("separation", 8)
	
	reset_all_button = Button.new()
	reset_all_button.text = "Reset All to Defaults"
	reset_all_button.focus_mode = Control.FOCUS_ALL
	reset_all_button.pressed.connect(_reset_all_shortcuts)
	button_bar.add_child(reset_all_button)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_bar.add_child(spacer)
	
	var apply_button = Button.new()
	apply_button.text = "Apply"
	apply_button.focus_mode = Control.FOCUS_ALL
	apply_button.pressed.connect(_apply_changes)
	button_bar.add_child(apply_button)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(hide)
	button_bar.add_child(close_button)
	
	return button_bar

func _populate_categories() -> void:
	"""Populate the category tree."""
	if not category_tree or not shortcut_manager:
		return
	
	category_tree.clear()
	var root = category_tree.create_item()
	
	# Add categories
	for category in GFRED2ShortcutManager.Category.values():
		var actions = shortcut_manager.get_actions_by_category(category)
		if actions.size() > 0:
			var item = category_tree.create_item(root)
			item.set_text(0, shortcut_manager.get_category_display_name(category))
			item.set_meta("category", category)

func _populate_shortcuts(category: GFRED2ShortcutManager.Category) -> void:
	"""Populate the shortcuts list for a category."""
	if not shortcut_list or not shortcut_manager:
		return
	
	shortcut_list.clear()
	var root = shortcut_list.create_item()
	
	var actions = shortcut_manager.get_actions_by_category(category)
	for action_name in actions:
		var item = shortcut_list.create_item(root)
		item.set_text(0, shortcut_manager.get_action_display_name(action_name))
		item.set_text(1, shortcut_manager.get_shortcut_display_string(action_name))
		item.set_meta("action", action_name)
		item.set_tooltip_text(0, shortcut_manager.get_action_description(action_name))

func _on_category_selected() -> void:
	"""Handle category selection."""
	var selected = category_tree.get_selected()
	if not selected:
		return
	
	var category = selected.get_meta("category")
	_populate_shortcuts(category)

func _on_shortcut_selected() -> void:
	"""Handle shortcut selection."""
	var selected = shortcut_list.get_selected()
	if not selected:
		return
	
	selected_action = selected.get_meta("action", "")
	_update_shortcut_display()

func _update_shortcut_display() -> void:
	"""Update the current shortcut display."""
	if selected_action.is_empty() or not shortcut_manager:
		current_shortcut_label.text = "None"
		return
	
	current_shortcut_label.text = shortcut_manager.get_shortcut_display_string(selected_action)
	new_shortcut_input.text = ""
	conflict_label.visible = false

func _on_shortcut_input(event: InputEvent) -> void:
	"""Handle shortcut input events."""
	if not event is InputEventKey:
		return
	
	var key_event = event as InputEventKey
	if not key_event.pressed:
		return
	
	# Ignore pure modifier keys
	if key_event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
		return
	
	# Update display
	var display_string = _get_event_display_string(key_event)
	new_shortcut_input.text = display_string
	
	# Check for conflicts
	if not selected_action.is_empty():
		var conflicting_action = shortcut_manager._find_conflicting_action(key_event, selected_action)
		if not conflicting_action.is_empty():
			conflict_label.text = "Conflicts with: " + shortcut_manager.get_action_display_name(conflicting_action)
			conflict_label.visible = true
		else:
			conflict_label.visible = false

func _get_event_display_string(event: InputEventKey) -> String:
	"""Get display string for an input event."""
	var parts: Array[String] = []
	
	if event.ctrl_pressed:
		parts.append("Ctrl")
	if event.shift_pressed:
		parts.append("Shift")
	if event.alt_pressed:
		parts.append("Alt")
	if event.meta_pressed:
		parts.append("Meta")
	
	parts.append(OS.get_keycode_string(event.keycode))
	
	return "+".join(parts)

func _clear_shortcut_input() -> void:
	"""Clear the shortcut input field."""
	new_shortcut_input.text = ""
	conflict_label.visible = false

func _assign_shortcut() -> void:
	"""Assign the new shortcut to the selected action."""
	if selected_action.is_empty() or new_shortcut_input.text.is_empty():
		return
	
	# This is a simplified assignment - in practice, you'd need to parse the input
	# For now, we'll show a placeholder
	push_warning("Shortcut assignment not fully implemented in this demo")

func _reset_shortcut() -> void:
	"""Reset the selected shortcut to default."""
	if selected_action.is_empty() or not shortcut_manager:
		return
	
	shortcut_manager.reset_shortcut(selected_action)
	_update_shortcut_display()
	_refresh_shortcut_list()

func _reset_all_shortcuts() -> void:
	"""Reset all shortcuts to defaults."""
	if not shortcut_manager:
		return
	
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Reset all shortcuts to their default values? This cannot be undone."
	dialog.confirmed.connect(_confirm_reset_all)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_reset_all() -> void:
	"""Confirm reset all shortcuts."""
	if shortcut_manager:
		shortcut_manager.reset_all_shortcuts()
		_refresh_shortcut_list()

func _refresh_shortcut_list() -> void:
	"""Refresh the shortcuts list display."""
	var selected_category = category_tree.get_selected()
	if selected_category:
		var category = selected_category.get_meta("category")
		_populate_shortcuts(category)

func _apply_changes() -> void:
	"""Apply and save changes."""
	if shortcut_manager:
		shortcut_manager.save_shortcuts()
	shortcuts_changed.emit()

func _on_shortcut_changed(action_name: String, old_shortcut: InputEventKey, new_shortcut: InputEventKey) -> void:
	"""Handle shortcut change events."""
	_refresh_shortcut_list()
	if selected_action == action_name:
		_update_shortcut_display()

func _on_conflict_detected(action_name: String, conflicting_action: String) -> void:
	"""Handle shortcut conflict detection."""
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Shortcut conflicts with: " + shortcut_manager.get_action_display_name(conflicting_action)
	add_child(dialog)
	dialog.popup_centered()

func _on_sticky_keys_toggled(enabled: bool) -> void:
	"""Handle sticky keys toggle."""
	if shortcut_manager:
		shortcut_manager.enable_accessibility_feature("sticky_keys", enabled)

func _on_slow_keys_toggled(enabled: bool) -> void:
	"""Handle slow keys toggle."""
	if shortcut_manager:
		shortcut_manager.enable_accessibility_feature("slow_keys", enabled)

func _on_slow_keys_delay_changed(value: float) -> void:
	"""Handle slow keys delay change."""
	if shortcut_manager:
		shortcut_manager.set_accessibility_timing("slow_keys", value)

func _on_bounce_keys_toggled(enabled: bool) -> void:
	"""Handle bounce keys toggle."""
	if shortcut_manager:
		shortcut_manager.enable_accessibility_feature("bounce_keys", enabled)

func _on_bounce_keys_delay_changed(value: float) -> void:
	"""Handle bounce keys delay change."""
	if shortcut_manager:
		shortcut_manager.set_accessibility_timing("bounce_keys", value)

func show_dialog() -> void:
	"""Show the shortcut configuration dialog."""
	popup_centered()
	
	# Load current accessibility settings
	if shortcut_manager:
		sticky_keys_checkbox.button_pressed = shortcut_manager.enable_sticky_keys
		slow_keys_checkbox.button_pressed = shortcut_manager.enable_slow_keys
		slow_keys_spinbox.value = shortcut_manager.slow_keys_delay
		bounce_keys_checkbox.button_pressed = shortcut_manager.enable_bounce_keys
		bounce_keys_spinbox.value = shortcut_manager.bounce_keys_delay