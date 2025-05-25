class_name Fred2MainUI
extends Control

## Main UI controller for the FRED2 mission editor plugin.
## Coordinates between viewport, property editor, and object hierarchy.

signal mission_loaded(mission_data: MissionData)
signal mission_saved(file_path: String)
signal object_selection_changed(selected_objects: Array[MissionObjectData])

@export var viewport_scene: PackedScene
@export var property_editor_scene: PackedScene
@export var hierarchy_scene: PackedScene

var mission_data: MissionData
var mission_object_manager: MissionObjectManager

# UI Components
var main_hsplit: HSplitContainer
var left_vsplit: VSplitContainer
var right_panel: VBoxContainer

var viewport_container: SubViewport
var property_editor: ObjectPropertyEditor
var object_hierarchy: ObjectHierarchy

# Menu and toolbar
var menu_bar: MenuBar
var toolbar: HBoxContainer

func _ready() -> void:
	name = "Fred2MainUI"
	_setup_ui()
	_setup_mission_manager()
	_connect_signals()

func _setup_ui() -> void:
	"""Setup the main UI layout."""
	# Main horizontal split (viewport | panels)
	main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_hsplit)
	
	# Viewport container (left side)
	_setup_viewport()
	
	# Right panel setup
	_setup_right_panel()
	
	# Menu and toolbar
	_setup_menu_toolbar()

func _setup_viewport() -> void:
	"""Setup the 3D viewport container."""
	var viewport_panel: Panel = Panel.new()
	viewport_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(viewport_panel)
	
	# SubViewport for 3D scene
	viewport_container = SubViewport.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_panel.add_child(viewport_container)
	
	# Load viewport scene or create basic 3D scene
	if viewport_scene:
		var viewport_instance: Node = viewport_scene.instantiate()
		viewport_container.add_child(viewport_instance)
	else:
		_create_basic_viewport()

func _create_basic_viewport() -> void:
	"""Create a basic 3D viewport scene."""
	var camera_3d: Camera3D = Camera3D.new()
	camera_3d.position = Vector3(0, 0, 5)
	viewport_container.add_child(camera_3d)
	
	# Add some basic lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.position = Vector3(0, 2, 2)
	light.rotation_degrees = Vector3(-45, 0, 0)
	viewport_container.add_child(light)

func _setup_right_panel() -> void:
	"""Setup the right panel with hierarchy and properties."""
	# Right side vertical split (hierarchy | properties)
	left_vsplit = VSplitContainer.new()
	left_vsplit.custom_minimum_size.x = 300
	left_vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.add_child(left_vsplit)
	
	# Object hierarchy (top)
	_setup_object_hierarchy()
	
	# Property editor (bottom)
	_setup_property_editor()

func _setup_object_hierarchy() -> void:
	"""Setup the object hierarchy panel."""
	var hierarchy_panel: Panel = Panel.new()
	hierarchy_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vsplit.add_child(hierarchy_panel)
	
	var hierarchy_vbox: VBoxContainer = VBoxContainer.new()
	hierarchy_panel.add_child(hierarchy_vbox)
	
	# Header
	var hierarchy_header: Label = Label.new()
	hierarchy_header.text = "Mission Objects"
	hierarchy_header.add_theme_font_size_override("font_size", 14)
	hierarchy_vbox.add_child(hierarchy_header)
	
	# Hierarchy component
	if hierarchy_scene:
		object_hierarchy = hierarchy_scene.instantiate()
	else:
		object_hierarchy = ObjectHierarchy.new()
	
	object_hierarchy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hierarchy_vbox.add_child(object_hierarchy)

func _setup_property_editor() -> void:
	"""Setup the property editor panel."""
	var property_panel: Panel = Panel.new()
	property_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vsplit.add_child(property_panel)
	
	var property_vbox: VBoxContainer = VBoxContainer.new()
	property_panel.add_child(property_vbox)
	
	# Header
	var property_header: Label = Label.new()
	property_header.text = "Object Properties"
	property_header.add_theme_font_size_override("font_size", 14)
	property_vbox.add_child(property_header)
	
	# Property editor component
	if property_editor_scene:
		property_editor = property_editor_scene.instantiate()
	else:
		property_editor = ObjectPropertyEditor.new()
	
	property_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_vbox.add_child(property_editor)

func _setup_menu_toolbar() -> void:
	"""Setup menu bar and toolbar."""
	var top_container: VBoxContainer = VBoxContainer.new()
	move_child(top_container, 0)  # Move to top
	
	# Menu bar
	menu_bar = MenuBar.new()
	top_container.add_child(menu_bar)
	
	_setup_file_menu()
	_setup_edit_menu()
	_setup_view_menu()
	_setup_tools_menu()
	
	# Toolbar
	toolbar = HBoxContainer.new()
	top_container.add_child(toolbar)
	
	_setup_toolbar_buttons()

func _setup_file_menu() -> void:
	"""Setup File menu."""
	var file_menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(file_menu)
	menu_bar.set_menu_title(0, "File")
	
	file_menu.add_item("New Mission", 1)
	file_menu.add_item("Open Mission...", 2)
	file_menu.add_separator()
	file_menu.add_item("Save Mission", 3)
	file_menu.add_item("Save Mission As...", 4)
	file_menu.add_separator()
	file_menu.add_item("Import...", 5)
	file_menu.add_item("Export...", 6)
	
	file_menu.id_pressed.connect(_on_file_menu_selected)

func _setup_edit_menu() -> void:
	"""Setup Edit menu."""
	var edit_menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(edit_menu)
	menu_bar.set_menu_title(1, "Edit")
	
	edit_menu.add_item("Undo", 1)
	edit_menu.add_item("Redo", 2)
	edit_menu.add_separator()
	edit_menu.add_item("Cut", 3)
	edit_menu.add_item("Copy", 4)
	edit_menu.add_item("Paste", 5)
	edit_menu.add_item("Delete", 6)
	edit_menu.add_separator()
	edit_menu.add_item("Select All", 7)
	edit_menu.add_item("Deselect All", 8)
	
	edit_menu.id_pressed.connect(_on_edit_menu_selected)

func _setup_view_menu() -> void:
	"""Setup View menu."""
	var view_menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(view_menu)
	menu_bar.set_menu_title(2, "View")
	
	view_menu.add_item("Reset Camera", 1)
	view_menu.add_item("Focus Selection", 2)
	view_menu.add_separator()
	view_menu.add_checkable_item("Show Grid", 3)
	view_menu.add_checkable_item("Show Gizmos", 4)
	view_menu.add_checkable_item("Wireframe Mode", 5)
	
	# Set default states
	view_menu.set_item_checked(2, true)  # Show Grid
	view_menu.set_item_checked(3, true)  # Show Gizmos
	
	view_menu.id_pressed.connect(_on_view_menu_selected)

func _setup_tools_menu() -> void:
	"""Setup Tools menu."""
	var tools_menu: PopupMenu = PopupMenu.new()
	menu_bar.add_child(tools_menu)
	menu_bar.set_menu_title(3, "Tools")
	
	tools_menu.add_item("Validate Mission", 1)
	tools_menu.add_item("Mission Statistics", 2)
	tools_menu.add_separator()
	tools_menu.add_item("Preferences...", 3)
	
	tools_menu.id_pressed.connect(_on_tools_menu_selected)

func _setup_toolbar_buttons() -> void:
	"""Setup toolbar buttons."""
	# File operations
	var new_button: Button = Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_new_mission)
	toolbar.add_child(new_button)
	
	var open_button: Button = Button.new()
	open_button.text = "Open"
	open_button.pressed.connect(_open_mission)
	toolbar.add_child(open_button)
	
	var save_button: Button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_mission)
	toolbar.add_child(save_button)
	
	toolbar.add_child(VSeparator.new())
	
	# Edit operations
	var undo_button: Button = Button.new()
	undo_button.text = "Undo"
	undo_button.pressed.connect(_undo)
	toolbar.add_child(undo_button)
	
	var redo_button: Button = Button.new()
	redo_button.text = "Redo"
	redo_button.pressed.connect(_redo)
	toolbar.add_child(redo_button)

func _setup_mission_manager() -> void:
	"""Setup the mission object manager."""
	mission_object_manager = MissionObjectManager.new()
	add_child(mission_object_manager)

func _connect_signals() -> void:
	"""Connect all UI signals."""
	# Object hierarchy signals
	if object_hierarchy:
		object_hierarchy.object_selected.connect(_on_object_selected)
		object_hierarchy.selection_changed.connect(_on_selection_changed)
		object_hierarchy.object_visibility_changed.connect(_on_object_visibility_changed)
	
	# Property editor signals
	if property_editor:
		property_editor.property_changed.connect(_on_property_changed)
		property_editor.validation_error.connect(_on_validation_error)
	
	# Mission manager signals
	if mission_object_manager:
		mission_object_manager.object_created.connect(_on_object_created)
		mission_object_manager.object_deleted.connect(_on_object_deleted)
		mission_object_manager.object_modified.connect(_on_object_modified)
		mission_object_manager.selection_changed.connect(_on_manager_selection_changed)

# Menu handlers
func _on_file_menu_selected(id: int) -> void:
	match id:
		1: _new_mission()
		2: _open_mission()
		3: _save_mission()
		4: _save_mission_as()
		5: _import_mission()
		6: _export_mission()

func _on_edit_menu_selected(id: int) -> void:
	match id:
		1: _undo()
		2: _redo()
		3: _cut()
		4: _copy()
		5: _paste()
		6: _delete_selected()
		7: _select_all()
		8: _deselect_all()

func _on_view_menu_selected(id: int) -> void:
	match id:
		1: _reset_camera()
		2: _focus_selection()
		3: _toggle_grid()
		4: _toggle_gizmos()
		5: _toggle_wireframe()

func _on_tools_menu_selected(id: int) -> void:
	match id:
		1: _validate_mission()
		2: _show_mission_stats()
		3: _show_preferences()

# File operations
func _new_mission() -> void:
	"""Create a new mission."""
	mission_data = MissionData.new()
	_update_ui_for_mission()

func _open_mission() -> void:
	"""Open an existing mission."""
	var file_dialog: FileDialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.fmis", "FRED2 Mission Files")
	file_dialog.file_selected.connect(_on_mission_file_selected.bind(file_dialog))
	file_dialog.popup_centered_ratio(0.7)

func _save_mission() -> void:
	"""Save current mission."""
	if not mission_data:
		return
	
	if mission_data.file_path:
		_save_mission_to_file(mission_data.file_path)
	else:
		_save_mission_as()

func _save_mission_as() -> void:
	"""Save mission with file dialog."""
	var file_dialog: FileDialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.fmis", "FRED2 Mission Files")
	file_dialog.file_selected.connect(_on_save_file_selected.bind(file_dialog))
	file_dialog.popup_centered_ratio(0.7)

func _import_mission() -> void:
	"""Import mission from different format."""
	print("Import mission - TODO: Implement")

func _export_mission() -> void:
	"""Export mission to different format."""
	print("Export mission - TODO: Implement")

func _on_mission_file_selected(file_dialog: FileDialog, path: String) -> void:
	"""Handle mission file selection."""
	file_dialog.queue_free()
	
	# TODO: Load mission file
	mission_data = MissionData.new()
	mission_data.file_path = path
	_update_ui_for_mission()
	
	mission_loaded.emit(mission_data)

func _on_save_file_selected(file_dialog: FileDialog, path: String) -> void:
	"""Handle save file selection."""
	file_dialog.queue_free()
	_save_mission_to_file(path)

func _save_mission_to_file(path: String) -> void:
	"""Save mission data to file."""
	if not mission_data:
		return
	
	mission_data.file_path = path
	# TODO: Implement actual file saving
	print("Saving mission to: ", path)
	
	mission_saved.emit(path)

func _update_ui_for_mission() -> void:
	"""Update UI components for loaded mission."""
	if mission_object_manager:
		mission_object_manager.set_mission_data(mission_data)
	
	if object_hierarchy:
		object_hierarchy.set_mission_data(mission_data)
	
	if property_editor:
		property_editor.edit_object(null)  # Clear current selection

# Edit operations
func _undo() -> void:
	if mission_object_manager:
		mission_object_manager.undo()

func _redo() -> void:
	if mission_object_manager:
		mission_object_manager.redo()

func _cut() -> void:
	_copy()
	_delete_selected()

func _copy() -> void:
	if mission_object_manager:
		mission_object_manager.copy_selected()

func _paste() -> void:
	if mission_object_manager:
		mission_object_manager.paste()

func _delete_selected() -> void:
	if mission_object_manager:
		mission_object_manager.delete_selected()

func _select_all() -> void:
	if mission_object_manager:
		mission_object_manager.select_all()

func _deselect_all() -> void:
	if mission_object_manager:
		mission_object_manager.clear_selection()

# View operations
func _reset_camera() -> void:
	print("Reset camera - TODO: Implement")

func _focus_selection() -> void:
	print("Focus selection - TODO: Implement")

func _toggle_grid() -> void:
	print("Toggle grid - TODO: Implement")

func _toggle_gizmos() -> void:
	print("Toggle gizmos - TODO: Implement")

func _toggle_wireframe() -> void:
	print("Toggle wireframe - TODO: Implement")

# Tools operations
func _validate_mission() -> void:
	print("Validate mission - TODO: Implement")

func _show_mission_stats() -> void:
	print("Show mission statistics - TODO: Implement")

func _show_preferences() -> void:
	print("Show preferences - TODO: Implement")

# Signal handlers
func _on_object_selected(object_data: MissionObjectData) -> void:
	"""Handle object selection from hierarchy."""
	if property_editor:
		property_editor.edit_object(object_data)
	
	if mission_object_manager:
		mission_object_manager.set_selection([object_data])

func _on_selection_changed(selected_objects: Array[MissionObjectData]) -> void:
	"""Handle selection changes from hierarchy."""
	if mission_object_manager:
		mission_object_manager.set_selection(selected_objects)
	
	object_selection_changed.emit(selected_objects)

func _on_object_visibility_changed(object_data: MissionObjectData, visible: bool) -> void:
	"""Handle object visibility changes."""
	# TODO: Update 3D viewport visibility
	print("Object visibility changed: ", object_data.object_name, " -> ", visible)

func _on_property_changed(property_name: String, new_value: Variant) -> void:
	"""Handle property changes from editor."""
	if mission_object_manager:
		mission_object_manager.update_object_property(property_name, new_value)

func _on_validation_error(property_name: String, error_message: String) -> void:
	"""Handle validation errors from property editor."""
	print("Validation error in ", property_name, ": ", error_message)

func _on_object_created(object_data: MissionObjectData) -> void:
	"""Handle object creation from manager."""
	if object_hierarchy:
		object_hierarchy.refresh_hierarchy()

func _on_object_deleted(object_data: MissionObjectData) -> void:
	"""Handle object deletion from manager."""
	if object_hierarchy:
		object_hierarchy.refresh_hierarchy()
	
	if property_editor:
		property_editor.edit_object(null)

func _on_object_modified(object_data: MissionObjectData) -> void:
	"""Handle object modifications from manager."""
	if property_editor and property_editor.current_object == object_data:
		property_editor.refresh_properties()

func _on_manager_selection_changed(selected_objects: Array[MissionObjectData]) -> void:
	"""Handle selection changes from manager."""
	if object_hierarchy:
		object_hierarchy.select_objects(selected_objects)
	
	# Update property editor for single selection
	if selected_objects.size() == 1:
		if property_editor:
			property_editor.edit_object(selected_objects[0])
	else:
		if property_editor:
			property_editor.edit_object(null)

func get_mission_data() -> MissionData:
	"""Get current mission data."""
	return mission_data

func get_selected_objects() -> Array[MissionObjectData]:
	"""Get currently selected objects."""
	if mission_object_manager:
		return mission_object_manager.get_selected_objects()
	return []