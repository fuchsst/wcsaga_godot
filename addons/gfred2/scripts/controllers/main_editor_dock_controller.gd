@tool
class_name MainEditorDockController
extends Control

## Main editor dock controller for GFRED2-011 UI Refactoring.
## Scene-based UI controller implementing mandatory scene-based architecture.
## Scene: addons/gfred2/scenes/docks/main_editor_dock.tscn

signal object_selected(object_data: MissionObjectData)
signal property_changed(object_data: MissionObjectData, property_name: String, new_value: Variant)
signal view_mode_changed(mode: String)

# Mission data and management
var current_mission_data: MissionData = null
var selected_objects: Array[MissionObjectData] = []

# Scene node references
@onready var main_container: HSplitContainer = $MainContainer
@onready var viewport_container: VBoxContainer = $MainContainer/ViewportContainer
@onready var toolbar_container: HBoxContainer = $MainContainer/ViewportContainer/ToolbarContainer
@onready var viewport_wrapper: SubViewportContainer = $MainContainer/ViewportContainer/ViewportWrapper
@onready var mission_viewport: SubViewport = $MainContainer/ViewportContainer/ViewportWrapper/MissionViewport

@onready var right_panel: VBoxContainer = $MainContainer/RightPanel
@onready var hierarchy_tree: Tree = $MainContainer/RightPanel/ObjectHierarchy/HierarchyTree
@onready var properties_container: VBoxContainer = $MainContainer/RightPanel/PropertyInspector/PropertyScroll/PropertiesContainer

@onready var view_mode_options: OptionButton = $MainContainer/ViewportContainer/ToolbarContainer/ViewModeOptions
@onready var grid_toggle: CheckBox = $MainContainer/ViewportContainer/ToolbarContainer/GridToggle
@onready var snap_toggle: CheckBox = $MainContainer/ViewportContainer/ToolbarContainer/SnapToggle

# State management
var current_view_mode: String = "wireframe"

func _ready() -> void:
	name = "MainEditorDock"
	_setup_view_mode_options()
	_connect_signals()
	print("MainEditorDockController: Scene-based main editor dock initialized")

## Initializes the editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	_populate_object_hierarchy()
	print("MainEditorDockController: Initialized with mission: %s" % mission_data.mission_name)

func _setup_view_mode_options() -> void:
	if not view_mode_options:
		return
	
	view_mode_options.clear()
	view_mode_options.add_item("Wireframe")
	view_mode_options.add_item("Solid")
	view_mode_options.add_item("Textured")
	view_mode_options.selected = 0

func _connect_signals() -> void:
	if view_mode_options:
		view_mode_options.item_selected.connect(_on_view_mode_selected)
	
	if grid_toggle:
		grid_toggle.toggled.connect(_on_grid_toggled)
	
	if snap_toggle:
		snap_toggle.toggled.connect(_on_snap_toggled)
	
	if hierarchy_tree:
		hierarchy_tree.item_selected.connect(_on_hierarchy_item_selected)

func _populate_object_hierarchy() -> void:
	if not hierarchy_tree or not current_mission_data:
		return
	
	hierarchy_tree.clear()
	var root: TreeItem = hierarchy_tree.create_item()
	root.set_text(0, "Mission Objects")
	
	# Add ships
	if current_mission_data.has_method("get_ships"):
		var ships_node: TreeItem = hierarchy_tree.create_item(root)
		ships_node.set_text(0, "Ships")
		
		for ship in current_mission_data.get_ships():
			var ship_item: TreeItem = hierarchy_tree.create_item(ships_node)
			ship_item.set_text(0, ship.name if ship.has_method("get_name") else "Ship")
			ship_item.set_metadata(0, ship)
	
	# Add waypoints
	if current_mission_data.has_method("get_waypoint_paths"):
		var waypoints_node: TreeItem = hierarchy_tree.create_item(root)
		waypoints_node.set_text(0, "Waypoint Paths")
		
		for waypoint_path in current_mission_data.get_waypoint_paths():
			var waypoint_item: TreeItem = hierarchy_tree.create_item(waypoints_node)
			waypoint_item.set_text(0, waypoint_path.path_name if waypoint_path.has_method("get_path_name") else "Waypoint Path")
			waypoint_item.set_metadata(0, waypoint_path)

func _clear_property_editor() -> void:
	if not properties_container:
		return
	
	for child in properties_container.get_children():
		child.queue_free()

func _populate_property_editor(object_data: MissionObjectData) -> void:
	_clear_property_editor()
	
	if not object_data or not properties_container:
		return
	
	# Create property editors based on object type
	# This would be expanded to use proper property editor scenes
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	properties_container.add_child(name_label)
	
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = object_data.name if object_data.has_method("get_name") else "Object"
	name_edit.text_changed.connect(_on_object_name_changed.bind(object_data))
	properties_container.add_child(name_edit)

## Signal handlers

func _on_view_mode_selected(index: int) -> void:
	var modes: Array[String] = ["wireframe", "solid", "textured"]
	if index >= 0 and index < modes.size():
		current_view_mode = modes[index]
		view_mode_changed.emit(current_view_mode)

func _on_grid_toggled(enabled: bool) -> void:
	# TODO: Implement grid toggle functionality
	print("MainEditorDockController: Grid toggled: %s" % enabled)

func _on_snap_toggled(enabled: bool) -> void:
	# TODO: Implement snap toggle functionality
	print("MainEditorDockController: Snap toggled: %s" % enabled)

func _on_hierarchy_item_selected() -> void:
	var selected_item: TreeItem = hierarchy_tree.get_selected()
	if not selected_item:
		return
	
	var object_data: MissionObjectData = selected_item.get_metadata(0) as MissionObjectData
	if object_data:
		selected_objects = [object_data]
		_populate_property_editor(object_data)
		object_selected.emit(object_data)

func _on_object_name_changed(object_data: MissionObjectData, new_name: String) -> void:
	if object_data and object_data.has_method("set_name"):
		object_data.set_name(new_name)
		property_changed.emit(object_data, "name", new_name)
		_populate_object_hierarchy()  # Refresh hierarchy

## Public API methods

func get_selected_objects() -> Array[MissionObjectData]:
	return selected_objects

func get_current_view_mode() -> String:
	return current_view_mode

func refresh_hierarchy() -> void:
	_populate_object_hierarchy()

func select_object(object_data: MissionObjectData) -> void:
	if not object_data or not hierarchy_tree:
		return
	
	# Find and select the object in hierarchy
	var root: TreeItem = hierarchy_tree.get_root()
	if root:
		_find_and_select_item(root, object_data)

func _find_and_select_item(item: TreeItem, target_object: MissionObjectData) -> bool:
	if item.get_metadata(0) == target_object:
		item.select(0)
		return true
	
	var child: TreeItem = item.get_first_child()
	while child:
		if _find_and_select_item(child, target_object):
			return true
		child = child.get_next()
	
	return false