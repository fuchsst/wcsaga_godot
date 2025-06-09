class_name CustomizationInterface
extends Control

## EPIC-012 HUD-016: Customization Interface System
## Provides dedicated customization mode with editing tools and assistance

signal customization_mode_toggled(enabled: bool)
signal element_selected_for_editing(element_id: String)
signal customization_tool_changed(tool_name: String)
signal undo_redo_action_performed(action_type: String)

# Core interface components
var customization_panel: Control
var tool_palette: Control
var property_panel: Control
var preview_panel: Control
var element_hierarchy: Control

# Customization tools
var active_tool: String = "select"
var available_tools: Dictionary = {}
var tool_buttons: Dictionary = {}

# Interface state
var customization_active: bool = false
var selected_element: HUDElementBase = null
var editing_mode: String = "layout"  # layout, styling, behavior
var preview_mode: bool = false

# Undo/redo system
var undo_stack: Array[CustomizationAction] = []
var redo_stack: Array[CustomizationAction] = []
var max_undo_actions: int = 50
var action_grouping: bool = true

# Property editing
var property_editors: Dictionary = {}  # property_type -> PropertyEditor
var pending_changes: Dictionary = {}
var auto_apply_changes: bool = false
var change_debounce_time: float = 0.5
var last_change_time: float = 0.0

# Grid and alignment
var grid_overlay: Control
var alignment_guides: Array[Control] = []
var snap_indicators: Array[Control] = []
var measurement_lines: Array[Control] = []

# Interface settings
var interface_scale: float = 1.0
var panel_transparency: float = 0.9
var auto_hide_panels: bool = false
var compact_mode: bool = false

# Tutorial and help
var tutorial_overlay: Control
var help_tooltips: Dictionary = {}
var context_sensitive_help: bool = true

func _init():
	name = "CustomizationInterface"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_initialize_interface_components()
	_setup_customization_tools()
	_initialize_property_editors()
	_setup_keyboard_shortcuts()
	
	# Start hidden
	visible = false

## Initialize all interface components
func _initialize_interface_components() -> void:
	_create_customization_panel()
	_create_tool_palette()
	_create_property_panel()
	_create_preview_panel()
	_create_element_hierarchy()
	_create_grid_overlay()
	
	print("CustomizationInterface: Initialized all interface components")

## Enter customization mode
func enter_customization_mode() -> void:
	if customization_active:
		return
	
	customization_active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Show interface panels
	_show_customization_panels()
	
	# Initialize grid and guides
	if grid_overlay:
		grid_overlay.visible = true
		grid_overlay.queue_redraw()
	
	# Clear selection
	_deselect_current_element()
	
	# Reset tools to default
	_select_tool("select")
	
	customization_mode_toggled.emit(true)
	print("CustomizationInterface: Entered customization mode")

## Exit customization mode
func exit_customization_mode(save_changes: bool = true) -> void:
	if not customization_active:
		return
	
	# Apply or discard pending changes
	if save_changes and not pending_changes.is_empty():
		_apply_pending_changes()
	else:
		_discard_pending_changes()
	
	customization_active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Hide interface panels
	_hide_customization_panels()
	
	# Clear selection and guides
	_deselect_current_element()
	_clear_visual_guides()
	
	customization_mode_toggled.emit(false)
	print("CustomizationInterface: Exited customization mode (save_changes: %s)" % str(save_changes))

## Select tool for customization
func select_tool(tool_name: String) -> void:
	if not available_tools.has(tool_name):
		push_error("CustomizationInterface: Unknown tool '%s'" % tool_name)
		return
	
	_select_tool(tool_name)

## Select element for editing
func select_element_for_editing(element: HUDElementBase) -> void:
	if not customization_active:
		return
	
	# Deselect current element
	_deselect_current_element()
	
	# Select new element
	selected_element = element
	
	if element:
		# Update property panel
		_populate_property_panel(element)
		
		# Update hierarchy selection
		_update_hierarchy_selection(element.element_id)
		
		# Create visual guides
		_create_visual_guides_for_element(element)
		
		element_selected_for_editing.emit(element.element_id)
		print("CustomizationInterface: Selected element '%s' for editing" % element.element_id)

## Perform undo action
func perform_undo() -> void:
	if undo_stack.is_empty():
		return
	
	var action = undo_stack.pop_back()
	var inverse_action = action.get_inverse_action()
	
	if inverse_action:
		# Apply inverse action
		_execute_customization_action(inverse_action, false)  # Don't add to undo stack
		redo_stack.push_back(action)
		
		# Trim redo stack if needed
		while redo_stack.size() > max_undo_actions:
			redo_stack.pop_front()
		
		undo_redo_action_performed.emit("undo")
		print("CustomizationInterface: Performed undo: %s" % action.action_description)

## Perform redo action
func perform_redo() -> void:
	if redo_stack.is_empty():
		return
	
	var action = redo_stack.pop_back()
	_execute_customization_action(action, false)  # Don't add to undo stack
	undo_stack.push_back(action)
	
	# Trim undo stack if needed
	while undo_stack.size() > max_undo_actions:
		undo_stack.pop_front()
	
	undo_redo_action_performed.emit("redo")
	print("CustomizationInterface: Performed redo: %s" % action.action_description)

## Add customization action to undo stack
func add_customization_action(action: CustomizationAction) -> void:
	if not action:
		return
	
	# Clear redo stack when new action is added
	redo_stack.clear()
	
	# Try to merge with previous action if grouping is enabled
	if action_grouping and not undo_stack.is_empty():
		var last_action = undo_stack[-1]
		if last_action.can_merge_with(action):
			if last_action.merge_with(action):
				print("CustomizationInterface: Merged action with previous")
				return
	
	# Add new action to stack
	undo_stack.push_back(action)
	
	# Trim stack if needed
	while undo_stack.size() > max_undo_actions:
		undo_stack.pop_front()
	
	print("CustomizationInterface: Added customization action: %s" % action.action_description)

## Execute customization action
func _execute_customization_action(action: CustomizationAction, add_to_undo: bool = true) -> void:
	if not action:
		return
	
	# Apply action based on type
	match action.action_type:
		"position":
			if selected_element and selected_element.element_id == action.element_id:
				selected_element.position = action.new_value
		"size":
			if selected_element and selected_element.element_id == action.element_id:
				selected_element.size = action.new_value
		"rotation":
			if selected_element and selected_element.element_id == action.element_id:
				selected_element.rotation = action.new_value
		"scale":
			if selected_element and selected_element.element_id == action.element_id:
				selected_element.scale = Vector2(action.new_value, action.new_value)
		"visibility":
			if selected_element and selected_element.element_id == action.element_id:
				selected_element.visible = action.new_value
		"compound":
			for compound_action in action.compound_actions:
				_execute_customization_action(compound_action, false)
	
	# Add to undo stack if requested
	if add_to_undo:
		add_customization_action(action)
	
	# Update property panel if element is selected
	if selected_element:
		_update_property_panel(selected_element)

## Update property value
func update_property_value(property_name: String, value: Variant, apply_immediately: bool = false) -> void:
	if not selected_element:
		return
	
	# Store pending change
	pending_changes[property_name] = value
	last_change_time = Time.get_unix_time_from_system()
	
	if apply_immediately or auto_apply_changes:
		_apply_property_change(property_name, value)
	
	print("CustomizationInterface: Updated property '%s' to %s" % [property_name, str(value)])

## Apply pending changes
func _apply_pending_changes() -> void:
	if not selected_element or pending_changes.is_empty():
		return
	
	var compound_actions: Array[CustomizationAction] = []
	
	for property_name in pending_changes:
		var new_value = pending_changes[property_name]
		var old_value = _get_element_property_value(selected_element, property_name)
		
		var action = _create_action_for_property(property_name, old_value, new_value)
		if action:
			compound_actions.append(action)
			_apply_property_change(property_name, new_value)
	
	# Create compound action if multiple changes
	if compound_actions.size() > 1:
		var compound_action = CustomizationAction.create_compound_action(compound_actions, "Multiple property changes")
		add_customization_action(compound_action)
	elif compound_actions.size() == 1:
		add_customization_action(compound_actions[0])
	
	pending_changes.clear()
	print("CustomizationInterface: Applied %d pending changes" % compound_actions.size())

## Discard pending changes
func _discard_pending_changes() -> void:
	pending_changes.clear()
	print("CustomizationInterface: Discarded pending changes")

## Process input events
func _gui_input(event: InputEvent) -> void:
	if not customization_active:
		return
	
	# Handle tool-specific input
	match active_tool:
		"select":
			_handle_select_tool_input(event)
		"move":
			_handle_move_tool_input(event)
		"resize":
			_handle_resize_tool_input(event)
		"rotate":
			_handle_rotate_tool_input(event)

## Process regular updates
func _process(delta: float) -> void:
	if not customization_active:
		return
	
	# Apply pending changes if debounce time has passed
	if not pending_changes.is_empty() and auto_apply_changes:
		var current_time = Time.get_unix_time_from_system()
		if current_time - last_change_time >= change_debounce_time:
			_apply_pending_changes()

## Create customization panel
func _create_customization_panel() -> void:
	customization_panel = Control.new()
	customization_panel.name = "CustomizationPanel"
	customization_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	customization_panel.size.y = 80
	customization_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Add background
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, panel_transparency)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	customization_panel.add_child(bg)
	
	# Add title
	var title = Label.new()
	title.text = "HUD Customization Mode"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 16)
	customization_panel.add_child(title)
	
	# Add mode buttons
	_create_mode_buttons(customization_panel)
	
	add_child(customization_panel)

## Create tool palette
func _create_tool_palette() -> void:
	tool_palette = Control.new()
	tool_palette.name = "ToolPalette"
	tool_palette.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	tool_palette.size.x = 60
	tool_palette.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Add background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, panel_transparency)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tool_palette.add_child(bg)
	
	add_child(tool_palette)

## Create property panel
func _create_property_panel() -> void:
	property_panel = Control.new()
	property_panel.name = "PropertyPanel"
	property_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	property_panel.size.x = 250
	property_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Add background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, panel_transparency)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	property_panel.add_child(bg)
	
	# Add scroll container for properties
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.position = Vector2(10, 10)
	scroll.size -= Vector2(20, 20)
	property_panel.add_child(scroll)
	
	add_child(property_panel)

## Create preview panel
func _create_preview_panel() -> void:
	preview_panel = Control.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	preview_panel.size.y = 100
	preview_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Add background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, panel_transparency)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_panel.add_child(bg)
	
	add_child(preview_panel)

## Create element hierarchy
func _create_element_hierarchy() -> void:
	element_hierarchy = Control.new()
	element_hierarchy.name = "ElementHierarchy"
	element_hierarchy.position = Vector2(70, 90)
	element_hierarchy.size = Vector2(200, 300)
	element_hierarchy.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Add background
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, panel_transparency)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	element_hierarchy.add_child(bg)
	
	add_child(element_hierarchy)

## Create grid overlay
func _create_grid_overlay() -> void:
	grid_overlay = Control.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_overlay.draw.connect(_draw_grid_overlay)
	
	add_child(grid_overlay)

## Setup customization tools
func _setup_customization_tools() -> void:
	available_tools["select"] = {
		"name": "Select",
		"description": "Select and modify elements",
		"icon": "select",
		"cursor": Control.CURSOR_ARROW
	}
	
	available_tools["move"] = {
		"name": "Move",
		"description": "Move elements",
		"icon": "move",
		"cursor": Control.CURSOR_MOVE
	}
	
	available_tools["resize"] = {
		"name": "Resize",
		"description": "Resize elements",
		"icon": "resize",
		"cursor": Control.CURSOR_CROSS
	}
	
	available_tools["rotate"] = {
		"name": "Rotate",
		"description": "Rotate elements",
		"icon": "rotate",
		"cursor": Control.CURSOR_CROSS
	}
	
	# Create tool buttons in palette
	_create_tool_buttons()

## Create tool buttons
func _create_tool_buttons() -> void:
	var y_pos = 10
	
	for tool_name in available_tools:
		var tool_data = available_tools[tool_name]
		var button = Button.new()
		button.text = tool_data.name
		button.size = Vector2(50, 30)
		button.position = Vector2(5, y_pos)
		button.pressed.connect(_on_tool_button_pressed.bind(tool_name))
		
		tool_palette.add_child(button)
		tool_buttons[tool_name] = button
		
		y_pos += 35

## Initialize property editors
func _initialize_property_editors() -> void:
	# Property editors would be created for different property types
	# This is a simplified initialization
	pass

## Setup keyboard shortcuts
func _setup_keyboard_shortcuts() -> void:
	# Keyboard shortcuts would be implemented using InputMap
	pass

## Show customization panels
func _show_customization_panels() -> void:
	if customization_panel:
		customization_panel.visible = true
	if tool_palette:
		tool_palette.visible = true
	if property_panel:
		property_panel.visible = true
	if element_hierarchy:
		element_hierarchy.visible = true

## Hide customization panels
func _hide_customization_panels() -> void:
	if customization_panel:
		customization_panel.visible = false
	if tool_palette:
		tool_palette.visible = false
	if property_panel:
		property_panel.visible = false
	if preview_panel:
		preview_panel.visible = false
	if element_hierarchy:
		element_hierarchy.visible = false

## Select tool internal
func _select_tool(tool_name: String) -> void:
	active_tool = tool_name
	
	# Update tool button states
	for button_tool in tool_buttons:
		var button = tool_buttons[button_tool]
		button.button_pressed = (button_tool == tool_name)
	
	# Update cursor
	if available_tools.has(tool_name):
		mouse_default_cursor_shape = available_tools[tool_name].cursor
	
	customization_tool_changed.emit(tool_name)
	print("CustomizationInterface: Selected tool '%s'" % tool_name)

## Deselect current element
func _deselect_current_element() -> void:
	if selected_element:
		selected_element = null
		_clear_property_panel()
		_clear_visual_guides()

## Create mode buttons
func _create_mode_buttons(parent: Control) -> void:
	var modes = ["Layout", "Styling", "Behavior"]
	var x_pos = 200
	
	for mode in modes:
		var button = Button.new()
		button.text = mode
		button.size = Vector2(80, 25)
		button.position = Vector2(x_pos, 30)
		button.pressed.connect(_on_mode_button_pressed.bind(mode.to_lower()))
		parent.add_child(button)
		x_pos += 90

## Populate property panel with element properties
func _populate_property_panel(element: HUDElementBase) -> void:
	_clear_property_panel()
	
	# Add property editors based on element type
	# This would be a comprehensive property editing interface
	print("CustomizationInterface: Populated property panel for element '%s'" % element.element_id)

## Update property panel
func _update_property_panel(element: HUDElementBase) -> void:
	# Update property editor values
	pass

## Clear property panel
func _clear_property_panel() -> void:
	# Clear all property editors
	pass

## Update hierarchy selection
func _update_hierarchy_selection(element_id: String) -> void:
	# Update element hierarchy to show selection
	pass

## Create visual guides for element
func _create_visual_guides_for_element(element: HUDElementBase) -> void:
	_clear_visual_guides()
	
	# Create selection outline, resize handles, etc.
	# This would create comprehensive visual editing aids

## Clear visual guides
func _clear_visual_guides() -> void:
	for guide in alignment_guides:
		if is_instance_valid(guide):
			guide.queue_free()
	alignment_guides.clear()

## Draw grid overlay
func _draw_grid_overlay() -> void:
	if not grid_overlay:
		return
	
	# Draw grid lines for alignment assistance
	# This would draw a comprehensive grid system

## Handle tool-specific input events
func _handle_select_tool_input(event: InputEvent) -> void:
	# Handle selection tool input
	pass

func _handle_move_tool_input(event: InputEvent) -> void:
	# Handle move tool input
	pass

func _handle_resize_tool_input(event: InputEvent) -> void:
	# Handle resize tool input
	pass

func _handle_rotate_tool_input(event: InputEvent) -> void:
	# Handle rotate tool input
	pass

## Event handlers
func _on_tool_button_pressed(tool_name: String) -> void:
	_select_tool(tool_name)

func _on_mode_button_pressed(mode: String) -> void:
	editing_mode = mode
	print("CustomizationInterface: Switched to %s mode" % mode)

## Helper methods
func _get_element_property_value(element: HUDElementBase, property_name: String) -> Variant:
	match property_name:
		"position": return element.position
		"size": return element.size
		"rotation": return element.rotation
		"scale": return element.scale.x
		"visible": return element.visible
		_: return null

func _apply_property_change(property_name: String, value: Variant) -> void:
	if not selected_element:
		return
	
	match property_name:
		"position": selected_element.position = value
		"size": selected_element.size = value
		"rotation": selected_element.rotation = value
		"scale": selected_element.scale = Vector2(value, value)
		"visible": selected_element.visible = value

func _create_action_for_property(property_name: String, old_value: Variant, new_value: Variant) -> CustomizationAction:
	if not selected_element:
		return null
	
	match property_name:
		"position":
			return CustomizationAction.create_position_action(selected_element.element_id, old_value, new_value)
		"size":
			return CustomizationAction.create_size_action(selected_element.element_id, old_value, new_value)
		"rotation":
			return CustomizationAction.create_rotation_action(selected_element.element_id, old_value, new_value)
		"scale":
			return CustomizationAction.create_scale_action(selected_element.element_id, old_value, new_value)
		"visible":
			return CustomizationAction.create_visibility_action(selected_element.element_id, old_value, new_value)
		_:
			return CustomizationAction.create_property_action(selected_element.element_id, property_name, old_value, new_value)