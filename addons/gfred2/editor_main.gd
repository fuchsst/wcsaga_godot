@tool
extends Control

# Input manager
var input_manager: Node

# Selection manager
var selection_manager: Node

# Editor state
var show_grid := true
var movement_speed := 1.0
var rotation_speed := 1.0
var show_ships := true 
var show_waypoints := true
var show_coordinates := true
var show_distances := false
var show_outlines := true

# Gizmo state
var active_gizmo: Node = null
var gizmo_mode := preload("res://addons/gfred2/object_gizmo.gd").GizmoMode.TRANSLATE
var gizmo_space := preload("res://addons/gfred2/object_gizmo.gd").GizmoSpace.WORLD
var snap_enabled := false
var snap_translate := 1.0
var snap_rotate := 15.0
var snap_scale := 0.1

# Editor objects
var viewport: SubViewport
var camera: Camera3D
var grid: Node3D

# Mission data
var mission: MissionData = null
var modified := false
var current_filename := ""

# Editor dialogs
var mission_specs_editor: Window
var asteroid_field_editor: Window
var save_dialog: Window
var open_dialog: Window

# Grid manager
var grid_manager: Node

func _ready():
	# Setup input manager
	input_manager = preload("res://addons/gfred2/input_manager.gd").new()
	add_child(input_manager)
	input_manager.shortcut_triggered.connect(_on_shortcut_triggered)
	
	# Setup selection manager
	selection_manager = preload("res://addons/gfred2/selection_manager.gd").new()
	add_child(selection_manager)
	selection_manager.selection_changed.connect(_on_selection_changed)
	
	_setup_viewport()
	_setup_camera()
	_setup_grid()
	_setup_editor_ui()
	_setup_dialogs()
	_setup_menus()

func _setup_viewport():
	viewport = $SubViewportContainer/SubViewport
	viewport.handle_input_locally = true
	viewport.physics_object_picking = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _setup_camera():
	camera = preload("res://addons/gfred2/editor_camera.gd").new()
	camera.name = "EditorCamera"
	camera.current = true
	viewport.add_child(camera)

func _setup_grid():
	# Create grid manager
	grid_manager = preload("res://addons/gfred2/grid_manager.gd").new()
	grid_manager.name = "GridManager"
	viewport.add_child(grid_manager)
	
	# Connect signals
	grid_manager.grid_updated.connect(_on_grid_updated)
	
	# Set initial state
	grid_manager.set_enabled(show_grid)

func _setup_editor_ui():
	# Get menu references
	var menu_bar = $HSplitContainer/MainArea/TopBar/MenuBar
	
	# Setup File menu
	var file_menu = menu_bar.get_node("FileMenu")
	var file_popup = PopupMenu.new()
	file_menu.set_popup(file_popup)
	
	file_popup.add_item("New Mission", 0)
	file_popup.add_item("Open Mission...", 1)
	file_popup.add_separator()
	file_popup.add_item("Save", 2)
	file_popup.add_item("Save As...", 3)
	file_popup.add_separator()
	file_popup.add_item("Import Mission...", 4)
	file_popup.add_item("Export Mission...", 5)
	file_popup.add_separator()
	file_popup.add_item("Exit", 6)
	
	file_popup.id_pressed.connect(_on_file_menu_item_selected)
	
	# Setup Edit menu
	var edit_menu = menu_bar.get_node("EditMenu")
	var edit_popup = PopupMenu.new()
	edit_menu.set_popup(edit_popup)
	
	edit_popup.add_item("Undo", 0)
	edit_popup.add_item("Redo", 1)
	edit_popup.add_separator()
	edit_popup.add_item("Cut", 2)
	edit_popup.add_item("Copy", 3)
	edit_popup.add_item("Paste", 4)
	edit_popup.add_item("Delete", 5)
	edit_popup.add_separator()
	edit_popup.add_item("Select All", 6)
	edit_popup.add_item("Deselect All", 7)
	
	edit_popup.id_pressed.connect(_on_edit_menu_item_selected)
	
	# Setup View menu
	var view_menu = menu_bar.get_node("ViewMenu")
	var view_popup = PopupMenu.new()
	view_menu.set_popup(view_popup)
	
	view_popup.add_check_item("Show Grid", 0)
	view_popup.add_check_item("Show Ships", 1)
	view_popup.add_check_item("Show Waypoints", 2)
	view_popup.add_check_item("Show Coordinates", 3)
	view_popup.add_check_item("Show Distances", 4)
	view_popup.add_check_item("Show Outlines", 5)
	view_popup.add_separator()
	view_popup.add_item("Reset Camera", 6)
	
	view_popup.set_item_checked(0, show_grid)
	view_popup.set_item_checked(1, show_ships)
	view_popup.set_item_checked(2, show_waypoints)
	view_popup.set_item_checked(3, show_coordinates)
	view_popup.set_item_checked(4, show_distances)
	view_popup.set_item_checked(5, show_outlines)
	
	view_popup.id_pressed.connect(_on_view_menu_item_selected)
	
	# Setup Editors menu
	var editors_menu = menu_bar.get_node("EditorsMenu")
	var editors_popup = PopupMenu.new()
	editors_menu.set_popup(editors_popup)
	
	editors_popup.add_item("Mission Specs", 0)
	editors_popup.add_item("Asteroid Field", 1)
	editors_popup.add_item("Background", 2)
	editors_popup.add_item("Briefing", 3)
	editors_popup.add_item("Command Briefing", 4)
	editors_popup.add_item("Debriefing", 5)
	editors_popup.add_item("Fiction Viewer", 6)
	editors_popup.add_item("Ship Selection", 7)
	editors_popup.add_item("Mission Goals", 8)
	editors_popup.add_item("Mission Events", 9)
	editors_popup.add_item("Mission Messages", 10)
	editors_popup.add_item("Mission Notes", 11)
	editors_popup.add_item("Mission Reinforcements", 12)
	
	editors_popup.id_pressed.connect(_on_editors_menu_item_selected)

func _setup_dialogs():
	# Create dialog instances
	mission_specs_editor = preload("res://addons/gfred2/dialogs/mission_specs_editor.gd").new()
	add_child(mission_specs_editor)
	
	asteroid_field_editor = preload("res://addons/gfred2/dialogs/asteroid_field_editor.gd").new()
	add_child(asteroid_field_editor)
	
	# File dialogs
	save_dialog = preload("res://addons/gfred2/dialogs/save_mission_dialog.gd").new()
	save_dialog.confirmed.connect(_on_save_dialog_confirmed)
	add_child(save_dialog)
	
	open_dialog = preload("res://addons/gfred2/dialogs/open_mission_dialog.gd").new()
	open_dialog.confirmed.connect(_on_open_dialog_confirmed)
	add_child(open_dialog)

func _update_grid() -> void:
	if grid_manager:
		grid_manager.set_enabled(show_grid)
		grid_manager.set_show_coordinates(show_coordinates)

func _on_grid_updated() -> void:
	# Called when grid manager updates the grid
	# Can be used to refresh viewport or update UI
	pass

func _setup_menus():
	# Get menu references
	var editors_menu = $HSplitContainer/MainArea/TopBar/MenuBar/EditorsMenu
	
	# Setup menu items
	editors_menu.get_popup().add_item("Asteroid Field", 0)
	editors_menu.get_popup().id_pressed.connect(_on_editors_menu_item_selected)

func _on_editors_menu_item_selected(id: int):
	match id:
		0: # Mission Specs
			mission_specs_editor.show_dialog()
		1: # Asteroid Field
			asteroid_field_editor.show_dialog()

func _on_shortcut_triggered(shortcut_name: String):
	match shortcut_name:
		# View toggles
		"view_show_grid":
			show_grid = !show_grid
			grid_manager.set_enabled(show_grid)
		"view_show_models":
			show_ships = !show_ships
		"view_show_outlines":
			show_outlines = !show_outlines
		"view_show_coordinates":
			show_coordinates = !show_coordinates
			_update_grid()
		"view_show_distances":
			show_distances = !show_distances
			
		# Camera modes
		"camera_free":
			camera.set_mode(camera.CameraMode.FREE)
		"camera_orbit":
			if selection_manager.selected_objects.size() > 0:
				camera.set_mode(camera.CameraMode.ORBIT)
				camera.set_target_position(selection_manager.get_selection_center())
		"camera_flyby":
			if selection_manager.selected_objects.size() > 0:
				camera.set_mode(camera.CameraMode.FREE)
				camera.look_at_point(selection_manager.get_selection_center())
		"camera_ship":
			if selection_manager.selected_objects.size() > 0:
				camera.set_mode(camera.CameraMode.LOCKED)
				var ship = selection_manager.selected_objects[0]
				camera.set_target_node(ship)
				
		# Camera controls
		"camera_save":
			camera.save_transform()
		"camera_restore":
			camera.restore_transform()
		"camera_focus":
			if selection_manager.selected_objects.size() > 0:
				camera.focus_on_point(selection_manager.get_selection_center())
		"camera_snap_angles":
			camera.set_angle_snap(!camera.angle_snap_enabled)
			
		# Camera speeds
		"camera_speed_1":
			camera.set_movement_speed(1.0)
		"camera_speed_2":
			camera.set_movement_speed(2.0)
		"camera_speed_5":
			camera.set_movement_speed(5.0)
		"camera_speed_10":
			camera.set_movement_speed(10.0)
		"camera_speed_20":
			camera.set_movement_speed(20.0)
		"camera_speed_50":
			camera.set_movement_speed(50.0)
			
		# Camera operations
		"camera_save_pos":
			_save_camera_position()
		"camera_restore_pos":
			_restore_camera_position()
			
		# Transform modes
		"mode_translate":
			gizmo_mode = preload("res://addons/gfred2/object_gizmo.gd").GizmoMode.TRANSLATE
			if active_gizmo:
				active_gizmo.set_mode(gizmo_mode)
		"mode_rotate":
			gizmo_mode = preload("res://addons/gfred2/object_gizmo.gd").GizmoMode.ROTATE
			if active_gizmo:
				active_gizmo.set_mode(gizmo_mode)
		"mode_scale":
			gizmo_mode = preload("res://addons/gfred2/object_gizmo.gd").GizmoMode.SCALE
			if active_gizmo:
				active_gizmo.set_mode(gizmo_mode)
		"toggle_space":
			gizmo_space = (gizmo_space + 1) % 2 # Toggle between LOCAL and WORLD
			if active_gizmo:
				active_gizmo.set_space(gizmo_space)
				
		# Snapping
		"toggle_snap":
			snap_enabled = !snap_enabled
			if active_gizmo:
				active_gizmo.snap_enabled = snap_enabled
		"increase_snap":
			_adjust_snap_values(1.0)
		"decrease_snap":
			_adjust_snap_values(-1.0)
			
		# Selection groups
		"select_group_1": _handle_selection_group(0)
		"select_group_2": _handle_selection_group(1)
		"select_group_3": _handle_selection_group(2)
		"select_group_4": _handle_selection_group(3)
		"select_group_5": _handle_selection_group(4)
		"select_group_6": _handle_selection_group(5)
		"select_group_7": _handle_selection_group(6)
		"select_group_8": _handle_selection_group(7)
		"select_group_9": _handle_selection_group(8)
			
		# Movement speeds
		"speed_movement_1": movement_speed = 1.0
		"speed_movement_2": movement_speed = 2.0
		"speed_movement_3": movement_speed = 3.0
		"speed_movement_5": movement_speed = 5.0
		"speed_movement_8": movement_speed = 8.0
		"speed_movement_10": movement_speed = 10.0
		"speed_movement_50": movement_speed = 50.0
		"speed_movement_100": movement_speed = 100.0
		
		# Rotation speeds
		"speed_rotation_1": rotation_speed = 1.0
		"speed_rotation_5": rotation_speed = 5.0
		"speed_rotation_12": rotation_speed = 12.0
		"speed_rotation_25": rotation_speed = 25.0
		"speed_rotation_50": rotation_speed = 50.0

func _input(event):
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			# Pan camera
			var speed = 0.05
			camera.translate(Vector3(-event.relative.x * speed * movement_speed, 0, -event.relative.y * speed * movement_speed))
			
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if selection_manager.box_selecting:
				selection_manager.update_box_selection(event.position)
			elif active_gizmo:
				active_gizmo.update_drag(camera, event.position)
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			camera.translate(Vector3(0, 0, -1))
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out 
			camera.translate(Vector3(0, 0, 1))
			
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if active_gizmo:
					# Try start gizmo drag
					var result = _raycast_gizmo(event.position)
					if result.hit:
						active_gizmo.start_drag(camera, event.position, result.axis)
						selection_manager.store_initial_transforms()
				else:
					# Start box selection
					selection_manager.start_box_selection(event.position)
			else:
				# End box selection or gizmo drag
				if selection_manager.box_selecting:
					selection_manager.end_box_selection(camera, Input.is_key_pressed(KEY_SHIFT))
				elif active_gizmo:
					active_gizmo.end_drag()

func _raycast_gizmo(screen_pos: Vector2) -> Dictionary:
	# Cast ray from camera
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	
	# Check intersection with gizmo handles
	var space_state = viewport.world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * 1000)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_object = result.collider
		if hit_object.is_in_group("gizmo_handle"):
			# Determine axis from handle name
			var axis = Vector3.ZERO
			if "XHandle" in hit_object.name:
				axis = Vector3.RIGHT
			elif "YHandle" in hit_object.name:
				axis = Vector3.UP
			elif "ZHandle" in hit_object.name:
				axis = Vector3.FORWARD
			
			return {
				"hit": true,
				"axis": axis
			}
	
	return {
		"hit": false,
		"axis": Vector3.ZERO
	}

func _handle_selection_group(group_index: int):
	if Input.is_key_pressed(KEY_CTRL):
		# Store selection group
		selection_manager.store_selection_group(group_index)
	else:
		# Recall selection group
		selection_manager.recall_selection_group(group_index)

func _adjust_snap_values(factor: float):
	if !active_gizmo:
		return
		
	match gizmo_mode:
		preload("res://addons/gfred2/object_gizmo.gd").GizmoMode.TRANSLATE:
			snap_translate = clamp(snap_translate + factor, 0.1, 10.0)
			active_gizmo.snap_translate = snap_translate
		preload("res://addons/gfred2/object_gizmo.gd").GizmoMode.ROTATE:
			snap_rotate = clamp(snap_rotate + factor * 5.0, 1.0, 90.0)
			active_gizmo.snap_rotate = snap_rotate
		preload("res://addons/gfred2/object_gizmo.gd").GizmoMode.SCALE:
			snap_scale = clamp(snap_scale + factor * 0.1, 0.01, 1.0)
			active_gizmo.snap_scale = snap_scale

func _on_selection_changed():
	# Remove existing gizmo
	if active_gizmo:
		active_gizmo.queue_free()
		active_gizmo = null
	
	# Create gizmo at selection center
	if !selection_manager.selected_objects.is_empty():
		var gizmo = preload("res://addons/gfred2/object_gizmo.gd").new()
		gizmo.name = "Gizmo"
		viewport.add_child(gizmo)
		
		# Position at selection center
		gizmo.global_position = selection_manager.get_selection_center()
		
		# Configure gizmo
		gizmo.set_mode(gizmo_mode)
		gizmo.set_space(gizmo_space)
		gizmo.snap_enabled = snap_enabled
		gizmo.snap_translate = snap_translate
		gizmo.snap_rotate = snap_rotate
		gizmo.snap_scale = snap_scale
		
		# Connect signals
		gizmo.transform_changed.connect(_on_gizmo_transform_changed)
		
		active_gizmo = gizmo

func _on_gizmo_transform_changed(transform: Transform3D):
	selection_manager.apply_transform_to_selection(transform)

func _on_edit_menu_item_selected(id: int):
	match id:
		0: # Undo
			# TODO: Implement undo system
			pass
			
		1: # Redo
			# TODO: Implement redo system
			pass
			
		2: # Cut
			# TODO: Implement cut
			pass
			
		3: # Copy
			# TODO: Implement copy
			pass
			
		4: # Paste
			# TODO: Implement paste
			pass
			
		5: # Delete
			if !selection_manager.selected_objects.is_empty():
				for object in selection_manager.selected_objects:
					object.queue_free()
				selection_manager.clear_selection()
				modified = true
			
		6: # Select All
			# TODO: Implement select all
			pass
			
		7: # Deselect All
			selection_manager.clear_selection()

func _on_view_menu_item_selected(id: int):
	match id:
		0: # Show Grid
			show_grid = !show_grid
			_update_grid()
			
		1: # Show Ships
			show_ships = !show_ships
			# TODO: Update ship visibility
			
		2: # Show Waypoints
			show_waypoints = !show_waypoints
			# TODO: Update waypoint visibility
			
		3: # Show Coordinates
			show_coordinates = !show_coordinates
			_update_grid()
			
		4: # Show Distances
			show_distances = !show_distances
			# TODO: Update distance measurements
			
		5: # Show Outlines
			show_outlines = !show_outlines
			# TODO: Update object outlines
			
		6: # Reset Camera
			camera.position = Vector3(0, 10, 10)
			camera.look_at(Vector3.ZERO)

# Camera state
var saved_camera_pos: Vector3
var saved_camera_rot: Vector3

func _save_camera_position():
	saved_camera_pos = camera.position
	saved_camera_rot = camera.rotation

func _restore_camera_position():
	if saved_camera_pos:
		camera.position = saved_camera_pos
		camera.rotation = saved_camera_rot

func _on_file_menu_item_selected(id: int):
	match id:
		0: # New Mission
			if modified:
				var dialog = ConfirmationDialog.new()
				dialog.dialog_text = "There are unsaved changes. Do you want to continue?"
				dialog.confirmed.connect(func(): _new_mission())
				add_child(dialog)
				dialog.popup_centered()
			else:
				_new_mission()
			
		1: # Open Mission
			if modified:
				var dialog = ConfirmationDialog.new()
				dialog.dialog_text = "There are unsaved changes. Do you want to continue?"
				dialog.confirmed.connect(func(): open_dialog.show_dialog())
				add_child(dialog)
				dialog.popup_centered()
			else:
				open_dialog.show_dialog()
			
		2: # Save
			if current_filename.is_empty():
				save_dialog.show_dialog_with_mission(mission)
			else:
				_save_mission(current_filename)
				
		3: # Save As
			save_dialog.show_dialog_with_mission(mission)
			
		6: # Exit
			if modified:
				var dialog = ConfirmationDialog.new()
				dialog.dialog_text = "There are unsaved changes. Do you want to exit?"
				dialog.confirmed.connect(func(): get_tree().quit())
				add_child(dialog)
				dialog.popup_centered()
			else:
				get_tree().quit()

func _new_mission():
	# Create new mission
	mission = MissionData.new()
	current_filename = ""
	modified = false
	
	# Clear viewport objects
	for child in viewport.get_children():
		if child != camera and child != grid_manager:
			child.queue_free()
	
	# Reset camera
	camera.position = Vector3(0, 10, 10)
	camera.look_at(Vector3.ZERO)
	
	# Reset selection
	selection_manager.clear_selection()

func _open_mission(path: String):
	var result = mission.load_fs2(path)
	if result == OK:
		current_filename = path
		modified = false
		
		# Clear viewport objects
		for child in viewport.get_children():
			if child != camera and child != grid_manager:
				child.queue_free()
		
		# Create mission objects
		for object in mission.root_objects:
			_create_mission_object(object)
		
		# Reset camera
		camera.position = Vector3(0, 10, 10)
		camera.look_at(Vector3.ZERO)
		
		# Reset selection
		selection_manager.clear_selection()
	else:
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Failed to open mission file: " + path
		add_child(dialog)
		dialog.popup_centered()

func _save_mission(path: String):
	var result = mission.save_fs2(path)
	if result == OK:
		current_filename = path
		modified = false
	else:
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Failed to save mission file: " + path
		add_child(dialog)
		dialog.popup_centered()

const MISSION_OBJECTS_PATH = "res://addons/gfred2/objects/"

func _create_mission_object(object: MissionObject) -> Node3D:
	# Create 3D representation of mission object
	var node: Node3D
	var scene_path := ""
	
	match object.type:
		MissionObject.Type.SHIP:
			scene_path = MISSION_OBJECTS_PATH + "mission_ship.tscn"
		MissionObject.Type.WING:
			scene_path = MISSION_OBJECTS_PATH + "mission_wing.tscn"
		MissionObject.Type.WAYPOINT:
			scene_path = MISSION_OBJECTS_PATH + "mission_waypoint.tscn"
		_:
			push_error("Unknown mission object type")
			return null
	
	# Load and instantiate scene
	var scene = load(scene_path)
	if !scene:
		push_error("Failed to load mission object scene: " + scene_path)
		return null
		
	node = scene.instantiate()
	if !node:
		push_error("Failed to instantiate mission object scene: " + scene_path)
		return null
	
	# Setup node
	viewport.add_child(node)
	node.mission_object = object
	node.owner = viewport
	
	# Create children recursively
	for child in object.get_children():
		var child_node = _create_mission_object(child)
		if child_node:
			child_node.position = child.position
			child_node.rotation = child.rotation
	
	return node

func _on_save_dialog_confirmed():
	if current_filename.is_empty():
		# Show file picker for new file
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = ["*.fs2 ; FreeSpace 2 Mission"]
		dialog.file_selected.connect(_save_mission)
		add_child(dialog)
		dialog.popup_centered(Vector2(800, 600))
	else:
		_save_mission(current_filename)

func _on_open_dialog_confirmed():
	var path = open_dialog.get_selected_file()
	if path:
		_open_mission(path)
