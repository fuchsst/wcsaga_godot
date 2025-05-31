@tool
class_name WaypointPathEditorPanel
extends Control

## Waypoint path editor for GFRED2-010 Mission Component Editors.
## Scene-based UI controller for creating and editing waypoint paths with 3D visualization.
## Scene: addons/gfred2/scenes/dialogs/component_editors/waypoint_path_editor_panel.tscn

signal waypoint_path_updated(path_data: WaypointPath)
signal validation_changed(is_valid: bool, errors: Array[String])
signal waypoint_selected(waypoint_index: int)
signal path_selected(path_id: String)

# Current mission and waypoint data
var current_mission_data: MissionData = null
var waypoint_paths: Array[WaypointPath] = []
var selected_path: WaypointPath = null
var selected_waypoint_index: int = -1

# Scene node references
@onready var paths_tree: Tree = $VBoxContainer/PathsList/PathsTree
@onready var add_path_button: Button = $VBoxContainer/PathsList/ButtonContainer/AddPathButton
@onready var remove_path_button: Button = $VBoxContainer/PathsList/ButtonContainer/RemovePathButton
@onready var duplicate_path_button: Button = $VBoxContainer/PathsList/ButtonContainer/DuplicatePathButton

@onready var waypoints_list: ItemList = $VBoxContainer/WaypointsContainer/WaypointsList
@onready var add_waypoint_button: Button = $VBoxContainer/WaypointsContainer/ButtonContainer/AddWaypointButton
@onready var remove_waypoint_button: Button = $VBoxContainer/WaypointsContainer/ButtonContainer/RemoveWaypointButton
@onready var insert_waypoint_button: Button = $VBoxContainer/WaypointsContainer/ButtonContainer/InsertWaypointButton

@onready var properties_container: VBoxContainer = $VBoxContainer/PropertiesContainer
@onready var path_name_edit: LineEdit = $VBoxContainer/PropertiesContainer/PathNameContainer/PathNameEdit
@onready var position_container: HBoxContainer = $VBoxContainer/PropertiesContainer/PositionContainer
@onready var pos_x_spin: SpinBox = $VBoxContainer/PropertiesContainer/PositionContainer/PosXSpin
@onready var pos_y_spin: SpinBox = $VBoxContainer/PropertiesContainer/PositionContainer/PosYSpin
@onready var pos_z_spin: SpinBox = $VBoxContainer/PropertiesContainer/PositionContainer/PosZSpin

@onready var preview_3d: WaypointPreview3D = $VBoxContainer/PreviewContainer/WaypointPreview3D
@onready var preview_controls: HBoxContainer = $VBoxContainer/PreviewContainer/PreviewControls
@onready var show_path_lines_check: CheckBox = $VBoxContainer/PreviewContainer/PreviewControls/ShowPathLinesCheck
@onready var show_waypoint_spheres_check: CheckBox = $VBoxContainer/PreviewContainer/PreviewControls/ShowWaypointSpheresCheck
@onready var auto_center_check: CheckBox = $VBoxContainer/PreviewContainer/PreviewControls/AutoCenterCheck

# Ship assignment
@onready var assigned_ships_list: ItemList = $VBoxContainer/AssignmentContainer/AssignedShipsList
@onready var available_ships_list: ItemList = $VBoxContainer/AssignmentContainer/AvailableShipsList
@onready var assign_ship_button: Button = $VBoxContainer/AssignmentContainer/ButtonContainer/AssignShipButton
@onready var unassign_ship_button: Button = $VBoxContainer/AssignmentContainer/ButtonContainer/UnassignShipButton

func _ready() -> void:
	name = "WaypointPathEditorPanel"
	
	# Setup UI components
	_setup_paths_tree()
	_setup_waypoints_list()
	_setup_property_editors()
	_setup_preview_3d()
	_setup_ship_assignment()
	_connect_signals()
	
	# Initialize empty state
	_update_properties_display()
	
	print("WaypointPathEditorPanel: Waypoint path editor initialized")

## Initializes the editor with mission data
func initialize_with_mission(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	current_mission_data = mission_data
	
	# Load existing waypoint paths from mission data
	if mission_data.has_method("get_waypoint_paths"):
		waypoint_paths = mission_data.get_waypoint_paths()
	else:
		waypoint_paths = []
	
	# Populate paths tree
	_populate_paths_tree()
	
	# Update ship lists
	_update_ship_lists()
	
	print("WaypointPathEditorPanel: Initialized with %d waypoint paths" % waypoint_paths.size())

## Sets up the paths tree
func _setup_paths_tree() -> void:
	if not paths_tree:
		return
	
	paths_tree.columns = 3
	paths_tree.set_column_title(0, "Path Name")
	paths_tree.set_column_title(1, "Waypoints")
	paths_tree.set_column_title(2, "Assigned Ships")
	
	paths_tree.set_column_expand(0, true)
	paths_tree.set_column_expand(1, false)
	paths_tree.set_column_expand(2, false)
	
	paths_tree.item_selected.connect(_on_path_selected)

func _setup_waypoints_list() -> void:
	if not waypoints_list:
		return
	
	waypoints_list.item_selected.connect(_on_waypoint_selected)

func _setup_property_editors() -> void:
	# Setup path name editor
	if path_name_edit:
		path_name_edit.text_changed.connect(_on_path_name_changed)
	
	# Setup position editors
	for spin in [pos_x_spin, pos_y_spin, pos_z_spin]:
		if spin:
			spin.min_value = -50000.0
			spin.max_value = 50000.0
			spin.step = 1.0
	
	if pos_x_spin:
		pos_x_spin.value_changed.connect(_on_position_x_changed)
	if pos_y_spin:
		pos_y_spin.value_changed.connect(_on_position_y_changed)
	if pos_z_spin:
		pos_z_spin.value_changed.connect(_on_position_z_changed)

func _setup_preview_3d() -> void:
	if not preview_3d:
		return
	
	# Connect preview signals
	preview_3d.waypoint_clicked.connect(_on_preview_waypoint_clicked)
	preview_3d.waypoint_moved.connect(_on_preview_waypoint_moved)
	
	# Setup preview controls
	if show_path_lines_check:
		show_path_lines_check.button_pressed = true
		show_path_lines_check.toggled.connect(_on_show_path_lines_toggled)
	
	if show_waypoint_spheres_check:
		show_waypoint_spheres_check.button_pressed = true
		show_waypoint_spheres_check.toggled.connect(_on_show_waypoint_spheres_toggled)
	
	if auto_center_check:
		auto_center_check.button_pressed = true
		auto_center_check.toggled.connect(_on_auto_center_toggled)

func _setup_ship_assignment() -> void:
	if assign_ship_button:
		assign_ship_button.pressed.connect(_on_assign_ship_pressed)
	
	if unassign_ship_button:
		unassign_ship_button.pressed.connect(_on_unassign_ship_pressed)

func _connect_signals() -> void:
	if add_path_button:
		add_path_button.pressed.connect(_on_add_path_pressed)
	
	if remove_path_button:
		remove_path_button.pressed.connect(_on_remove_path_pressed)
	
	if duplicate_path_button:
		duplicate_path_button.pressed.connect(_on_duplicate_path_pressed)
	
	if add_waypoint_button:
		add_waypoint_button.pressed.connect(_on_add_waypoint_pressed)
	
	if remove_waypoint_button:
		remove_waypoint_button.pressed.connect(_on_remove_waypoint_pressed)
	
	if insert_waypoint_button:
		insert_waypoint_button.pressed.connect(_on_insert_waypoint_pressed)

## Populates the paths tree with current data
func _populate_paths_tree() -> void:
	if not paths_tree:
		return
	
	paths_tree.clear()
	var root: TreeItem = paths_tree.create_item()
	
	for i in range(waypoint_paths.size()):
		var path: WaypointPath = waypoint_paths[i]
		var item: TreeItem = paths_tree.create_item(root)
		
		item.set_text(0, path.path_name)
		item.set_text(1, str(path.waypoints.size()))
		item.set_text(2, str(path.assigned_ships.size()))
		item.set_metadata(0, i)  # Store index for selection

func _populate_waypoints_list() -> void:
	if not waypoints_list or not selected_path:
		waypoints_list.clear() if waypoints_list else null
		return
	
	waypoints_list.clear()
	
	for i in range(selected_path.waypoints.size()):
		var waypoint: Vector3 = selected_path.waypoints[i]
		var display_text: String = "Waypoint %d: (%.1f, %.1f, %.1f)" % [i + 1, waypoint.x, waypoint.y, waypoint.z]
		waypoints_list.add_item(display_text)

func _update_ship_lists() -> void:
	if not current_mission_data:
		return
	
	# Update available ships list
	if available_ships_list:
		available_ships_list.clear()
		
		# Get all ships from mission data
		if current_mission_data.has_method("get_all_ships"):
			var all_ships: Array = current_mission_data.get_all_ships()
			for ship in all_ships:
				available_ships_list.add_item(ship.name if ship.has_method("get") else str(ship))
	
	# Update assigned ships list
	if assigned_ships_list and selected_path:
		assigned_ships_list.clear()
		for ship_name in selected_path.assigned_ships:
			assigned_ships_list.add_item(ship_name)

func _update_properties_display() -> void:
	var has_path_selection: bool = selected_path != null
	var has_waypoint_selection: bool = selected_waypoint_index >= 0
	
	# Enable/disable property controls
	properties_container.modulate = Color.WHITE if has_path_selection else Color(0.5, 0.5, 0.5)
	position_container.modulate = Color.WHITE if has_waypoint_selection else Color(0.5, 0.5, 0.5)
	
	if not has_path_selection:
		# Clear path-level inputs
		if path_name_edit:
			path_name_edit.text = ""
		return
	
	# Update path-level inputs
	if path_name_edit:
		path_name_edit.text = selected_path.path_name
	
	if not has_waypoint_selection:
		# Clear waypoint-level inputs
		if pos_x_spin:
			pos_x_spin.value = 0.0
		if pos_y_spin:
			pos_y_spin.value = 0.0
		if pos_z_spin:
			pos_z_spin.value = 0.0
		return
	
	# Update waypoint-level inputs
	if selected_waypoint_index < selected_path.waypoints.size():
		var waypoint: Vector3 = selected_path.waypoints[selected_waypoint_index]
		if pos_x_spin:
			pos_x_spin.value = waypoint.x
		if pos_y_spin:
			pos_y_spin.value = waypoint.y
		if pos_z_spin:
			pos_z_spin.value = waypoint.z

## Signal handlers

func _on_path_selected() -> void:
	var selected_item: TreeItem = paths_tree.get_selected()
	if not selected_item:
		selected_path = null
		selected_waypoint_index = -1
		_update_properties_display()
		_populate_waypoints_list()
		_update_ship_lists()
		return
	
	var path_index: int = selected_item.get_metadata(0)
	if path_index >= 0 and path_index < waypoint_paths.size():
		selected_path = waypoint_paths[path_index]
		selected_waypoint_index = -1  # Clear waypoint selection
		_update_properties_display()
		_populate_waypoints_list()
		_update_ship_lists()
		
		# Update 3D preview
		if preview_3d:
			preview_3d.update_waypoint_path(selected_path)
		
		path_selected.emit(selected_path.path_id if selected_path else "")

func _on_waypoint_selected(index: int) -> void:
	selected_waypoint_index = index
	_update_properties_display()
	
	# Highlight waypoint in 3D preview
	if preview_3d:
		preview_3d.highlight_waypoint(index)
	
	waypoint_selected.emit(index)

func _on_add_path_pressed() -> void:
	var new_path: WaypointPath = WaypointPath.new()
	new_path.path_name = "Waypoint Path %d" % (waypoint_paths.size() + 1)
	new_path.path_id = "path_%d" % (waypoint_paths.size() + 1)
	
	# Add initial waypoint at origin
	new_path.waypoints.append(Vector3.ZERO)
	
	waypoint_paths.append(new_path)
	_populate_paths_tree()
	
	# Select the new path
	var root: TreeItem = paths_tree.get_root()
	if root:
		var last_item: TreeItem = root.get_child(waypoint_paths.size() - 1)
		if last_item:
			last_item.select(0)
			_on_path_selected()
	
	waypoint_path_updated.emit(new_path)

func _on_remove_path_pressed() -> void:
	if not selected_path:
		return
	
	var selected_item: TreeItem = paths_tree.get_selected()
	if not selected_item:
		return
	
	var path_index: int = selected_item.get_metadata(0)
	if path_index >= 0 and path_index < waypoint_paths.size():
		waypoint_paths.remove_at(path_index)
		selected_path = null
		selected_waypoint_index = -1
		_populate_paths_tree()
		_populate_waypoints_list()
		_update_properties_display()
		_update_ship_lists()
		
		# Clear 3D preview
		if preview_3d:
			preview_3d.clear_preview()

func _on_duplicate_path_pressed() -> void:
	if not selected_path:
		return
	
	var duplicated: WaypointPath = selected_path.duplicate()
	duplicated.path_name += " Copy"
	duplicated.path_id += "_copy"
	
	waypoint_paths.append(duplicated)
	_populate_paths_tree()
	
	waypoint_path_updated.emit(duplicated)

func _on_add_waypoint_pressed() -> void:
	if not selected_path:
		return
	
	# Add waypoint at a position slightly offset from the last waypoint
	var new_position: Vector3 = Vector3.ZERO
	if selected_path.waypoints.size() > 0:
		new_position = selected_path.waypoints[-1] + Vector3(100, 0, 0)
	
	selected_path.waypoints.append(new_position)
	_populate_waypoints_list()
	_populate_paths_tree()  # Update waypoint count
	
	# Update 3D preview
	if preview_3d:
		preview_3d.update_waypoint_path(selected_path)
	
	waypoint_path_updated.emit(selected_path)

func _on_remove_waypoint_pressed() -> void:
	if not selected_path or selected_waypoint_index < 0 or selected_waypoint_index >= selected_path.waypoints.size():
		return
	
	selected_path.waypoints.remove_at(selected_waypoint_index)
	selected_waypoint_index = -1  # Clear selection
	_populate_waypoints_list()
	_populate_paths_tree()  # Update waypoint count
	_update_properties_display()
	
	# Update 3D preview
	if preview_3d:
		preview_3d.update_waypoint_path(selected_path)
	
	waypoint_path_updated.emit(selected_path)

func _on_insert_waypoint_pressed() -> void:
	if not selected_path or selected_waypoint_index < 0:
		return
	
	# Insert waypoint after the selected one
	var insert_index: int = selected_waypoint_index + 1
	var new_position: Vector3 = Vector3.ZERO
	
	if selected_waypoint_index < selected_path.waypoints.size():
		var current_waypoint: Vector3 = selected_path.waypoints[selected_waypoint_index]
		# If there's a next waypoint, place new one halfway between
		if insert_index < selected_path.waypoints.size():
			var next_waypoint: Vector3 = selected_path.waypoints[insert_index]
			new_position = (current_waypoint + next_waypoint) * 0.5
		else:
			# Otherwise, offset from current waypoint
			new_position = current_waypoint + Vector3(100, 0, 0)
	
	selected_path.waypoints.insert(insert_index, new_position)
	selected_waypoint_index = insert_index  # Select the new waypoint
	_populate_waypoints_list()
	_populate_paths_tree()
	_update_properties_display()
	
	# Update 3D preview
	if preview_3d:
		preview_3d.update_waypoint_path(selected_path)
	
	waypoint_path_updated.emit(selected_path)

func _on_path_name_changed(new_text: String) -> void:
	if selected_path:
		selected_path.path_name = new_text
		_populate_paths_tree()  # Refresh display
		waypoint_path_updated.emit(selected_path)

func _on_position_x_changed(value: float) -> void:
	_update_waypoint_position(0, value)

func _on_position_y_changed(value: float) -> void:
	_update_waypoint_position(1, value)

func _on_position_z_changed(value: float) -> void:
	_update_waypoint_position(2, value)

func _update_waypoint_position(component: int, value: float) -> void:
	if not selected_path or selected_waypoint_index < 0 or selected_waypoint_index >= selected_path.waypoints.size():
		return
	
	var waypoint: Vector3 = selected_path.waypoints[selected_waypoint_index]
	match component:
		0: waypoint.x = value
		1: waypoint.y = value
		2: waypoint.z = value
	
	selected_path.waypoints[selected_waypoint_index] = waypoint
	_populate_waypoints_list()  # Refresh display
	
	# Update 3D preview
	if preview_3d:
		preview_3d.update_waypoint_position(selected_waypoint_index, waypoint)
	
	waypoint_path_updated.emit(selected_path)

# Preview control handlers
func _on_show_path_lines_toggled(enabled: bool) -> void:
	if preview_3d:
		preview_3d.set_show_path_lines(enabled)

func _on_show_waypoint_spheres_toggled(enabled: bool) -> void:
	if preview_3d:
		preview_3d.set_show_waypoint_spheres(enabled)

func _on_auto_center_toggled(enabled: bool) -> void:
	if preview_3d:
		preview_3d.set_auto_center(enabled)

# Preview interaction handlers
func _on_preview_waypoint_clicked(waypoint_index: int) -> void:
	if waypoints_list and waypoint_index >= 0 and waypoint_index < waypoints_list.get_item_count():
		waypoints_list.select(waypoint_index)
		_on_waypoint_selected(waypoint_index)

func _on_preview_waypoint_moved(waypoint_index: int, new_position: Vector3) -> void:
	if selected_path and waypoint_index >= 0 and waypoint_index < selected_path.waypoints.size():
		selected_path.waypoints[waypoint_index] = new_position
		
		# Update UI if this is the selected waypoint
		if waypoint_index == selected_waypoint_index:
			_update_properties_display()
		
		_populate_waypoints_list()
		waypoint_path_updated.emit(selected_path)

# Ship assignment handlers
func _on_assign_ship_pressed() -> void:
	if not selected_path or not available_ships_list:
		return
	
	var selected_items: PackedInt32Array = available_ships_list.get_selected_items()
	for item_index in selected_items:
		var ship_name: String = available_ships_list.get_item_text(item_index)
		if not ship_name in selected_path.assigned_ships:
			selected_path.assigned_ships.append(ship_name)
	
	_update_ship_lists()
	_populate_paths_tree()  # Update assigned ship count
	waypoint_path_updated.emit(selected_path)

func _on_unassign_ship_pressed() -> void:
	if not selected_path or not assigned_ships_list:
		return
	
	var selected_items: PackedInt32Array = assigned_ships_list.get_selected_items()
	# Process in reverse order to avoid index issues
	for i in range(selected_items.size() - 1, -1, -1):
		var item_index: int = selected_items[i]
		if item_index >= 0 and item_index < selected_path.assigned_ships.size():
			selected_path.assigned_ships.remove_at(item_index)
	
	_update_ship_lists()
	_populate_paths_tree()  # Update assigned ship count
	waypoint_path_updated.emit(selected_path)

## Validation and export methods

func validate_component() -> Dictionary:
	var errors: Array[String] = []
	
	# Validate each path
	for i in range(waypoint_paths.size()):
		var path: WaypointPath = waypoint_paths[i]
		
		if path.path_name.is_empty():
			errors.append("Waypoint path %d: Name cannot be empty" % (i + 1))
		
		if path.waypoints.size() < 2:
			errors.append("Waypoint path %d: Must have at least 2 waypoints" % (i + 1))
		
		# Check for duplicate waypoints
		for j in range(path.waypoints.size()):
			for k in range(j + 1, path.waypoints.size()):
				if path.waypoints[j].distance_to(path.waypoints[k]) < 1.0:
					errors.append("Waypoint path %d: Waypoints %d and %d are too close" % [i + 1, j + 1, k + 1])
	
	var is_valid: bool = errors.is_empty()
	validation_changed.emit(is_valid, errors)
	
	return {"is_valid": is_valid, "errors": errors}

func apply_changes(mission_data: MissionData) -> void:
	if not mission_data:
		return
	
	# Apply waypoint paths to mission data
	if mission_data.has_method("set_waypoint_paths"):
		mission_data.set_waypoint_paths(waypoint_paths)
	
	print("WaypointPathEditorPanel: Applied %d waypoint paths to mission" % waypoint_paths.size())

func export_component() -> Dictionary:
	return {
		"waypoint_paths": waypoint_paths,
		"count": waypoint_paths.size(),
		"total_waypoints": waypoint_paths.reduce(func(acc, path): return acc + path.waypoints.size(), 0)
	}

## Gets current waypoint paths
func get_waypoint_paths() -> Array[WaypointPath]:
	return waypoint_paths

## Gets selected path
func get_selected_path() -> WaypointPath:
	return selected_path

## Gets selected waypoint index
func get_selected_waypoint_index() -> int:
	return selected_waypoint_index