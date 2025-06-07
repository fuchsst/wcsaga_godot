@tool
class_name CampaignFlowDiagram
extends Control

## Visual campaign flow diagram component for GFRED2-008 Campaign Editor Integration.
## Provides interactive mission flow visualization with drag-drop organization.

signal mission_selected(mission_id: String)
signal mission_moved(mission_id: String, new_position: Vector2)
signal connection_created(from_mission_id: String, to_mission_id: String)
signal connection_removed(from_mission_id: String, to_mission_id: String)
signal layout_changed()

# Campaign data and state
var campaign_data: CampaignData = null
var mission_nodes: Dictionary = {}  # mission_id -> CampaignMissionDataNode
var connection_lines: Array[CampaignConnectionLine] = []
var selected_mission_id: String = ""

# Interaction state
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var dragging_mission: CampaignMissionDataNode = null
var is_connecting: bool = false
var connection_start_mission: CampaignMissionDataNode = null

# Visual settings
var node_size: Vector2 = Vector2(120, 80)
var node_spacing: Vector2 = Vector2(180, 120)
var grid_size: int = 20
var show_grid: bool = true
var zoom_level: float = 1.0
var min_zoom: float = 0.25
var max_zoom: float = 2.0

# Colors and styles
var node_normal_color: Color = Color(0.3, 0.4, 0.5, 1)
var node_selected_color: Color = Color(0.5, 0.7, 0.9, 1)
var node_required_color: Color = Color(0.6, 0.5, 0.3, 1)
var connection_color: Color = Color(0.7, 0.7, 0.8, 1)
var grid_color: Color = Color(0.2, 0.2, 0.25, 0.3)

# Transform and viewport
var viewport_offset: Vector2 = Vector2.ZERO
var viewport_size: Vector2 = Vector2(1000, 800)

func _ready() -> void:
	name = "CampaignFlowDiagram"
	
	# Setup control properties
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect input handling
	gui_input.connect(_on_gui_input)
	
	# Set initial viewport size
	custom_minimum_size = Vector2(800, 600)
	
	print("CampaignFlowDiagram: Flow diagram initialized")

func _draw() -> void:
	# Draw grid if enabled
	if show_grid:
		_draw_grid()
	
	# Draw connections
	_draw_connections()
	
	# Draw mission nodes
	_draw_mission_nodes()
	
	# Draw connection preview if connecting
	if is_connecting and connection_start_mission:
		_draw_connection_preview()

## Sets up the campaign flow diagram with data
func setup_campaign_flow(target_campaign: CampaignData) -> void:
	campaign_data = target_campaign
	
	# Clear existing nodes and connections
	_clear_flow_diagram()
	
	# Create mission nodes
	_create_mission_nodes()
	
	# Create connection lines
	_create_connection_lines()
	
	# Fit diagram to view
	_auto_fit_diagram()

## Clears the flow diagram
func _clear_flow_diagram() -> void:
	mission_nodes.clear()
	connection_lines.clear()
	selected_mission_id = ""

## Creates mission nodes from campaign data
func _create_mission_nodes() -> void:
	if not campaign_data:
		return
	
	for mission in campaign_data.missions:
		var node: CampaignMissionDataNode = CampaignMissionDataNode.new()
		node.setup_mission_node(mission)
		node.size = node_size
		node.position = mission.position
		
		# Connect node signals
		node.mission_selected.connect(_on_mission_node_selected)
		node.mission_dragged.connect(_on_mission_node_dragged)
		node.connection_requested.connect(_on_connection_requested)
		
		mission_nodes[mission.mission_id] = node
		add_child(node)

## Creates connection lines from mission prerequisites
func _create_connection_lines() -> void:
	if not campaign_data:
		return
	
	for mission in campaign_data.missions:
		for prerequisite_id in mission.prerequisite_missions:
			var from_node: CampaignMissionDataNode = mission_nodes.get(prerequisite_id)
			var to_node: CampaignMissionDataNode = mission_nodes.get(mission.mission_id)
			
			if from_node and to_node:
				var connection: CampaignConnectionLine = CampaignConnectionLine.new()
				connection.setup_connection(from_node, to_node, prerequisite_id, mission.mission_id)
				connection_lines.append(connection)
		
		# Create connections for mission branches
		for branch in mission.mission_branches:
			if not branch.target_mission_id.is_empty():
				var from_node: CampaignMissionDataNode = mission_nodes.get(mission.mission_id)
				var to_node: CampaignMissionDataNode = mission_nodes.get(branch.target_mission_id)
				
				if from_node and to_node:
					var connection: CampaignConnectionLine = CampaignConnectionLine.new()
					connection.setup_connection(from_node, to_node, mission.mission_id, branch.target_mission_id)
					connection.connection_type = CampaignConnectionLine.ConnectionType.BRANCH
					connection.branch_info = branch
					connection_lines.append(connection)

## Draws the background grid
func _draw_grid() -> void:
	var grid_spacing: float = grid_size * zoom_level
	var start_x: int = int(-viewport_offset.x / grid_spacing) * int(grid_spacing)
	var start_y: int = int(-viewport_offset.y / grid_spacing) * int(grid_spacing)
	
	# Vertical lines
	var x: float = start_x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += grid_spacing
	
	# Horizontal lines
	var y: float = start_y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += grid_spacing

## Draws mission nodes
func _draw_mission_nodes() -> void:
	for mission_id in mission_nodes:
		var node: CampaignMissionDataNode = mission_nodes[mission_id]
		var is_selected: bool = mission_id == selected_mission_id
		
		# Transform node position
		var screen_pos: Vector2 = _world_to_screen(node.position)
		var screen_size: Vector2 = node_size * zoom_level
		
		# Skip if outside viewport
		if not _is_rect_visible(screen_pos, screen_size):
			continue
		
		# Draw node background
		var node_color: Color = node_selected_color if is_selected else node_normal_color
		if node.mission_data and node.mission_data.is_required:
			node_color = node_required_color
		
		var rect: Rect2 = Rect2(screen_pos, screen_size)
		draw_rect(rect, node_color)
		draw_rect(rect, Color.WHITE, false, 2.0)
		
		# Draw node text
		var font: Font = ThemeDB.fallback_font
		var font_size: int = int(12 * zoom_level)
		var text: String = node.mission_data.mission_name if node.mission_data else "Unknown"
		var text_pos: Vector2 = screen_pos + Vector2(8, 20) * zoom_level
		
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, screen_size.x - 16, font_size, Color.WHITE)

## Draws connection lines
func _draw_connections() -> void:
	for connection in connection_lines:
		if not connection.from_node or not connection.to_node:
			continue
		
		var from_pos: Vector2 = _world_to_screen(connection.from_node.position + node_size * 0.5)
		var to_pos: Vector2 = _world_to_screen(connection.to_node.position + node_size * 0.5)
		
		# Draw connection line
		var line_color: Color = connection_color
		if connection.connection_type == CampaignConnectionLine.ConnectionType.BRANCH:
			line_color = Color.YELLOW
		
		_draw_bezier_connection(from_pos, to_pos, line_color)
		
		# Draw arrow head
		_draw_arrow_head(from_pos, to_pos, line_color)

## Draws a bezier curve connection
func _draw_bezier_connection(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var control_offset: float = 100.0 * zoom_level
	var control1: Vector2 = from_pos + Vector2(control_offset, 0)
	var control2: Vector2 = to_pos - Vector2(control_offset, 0)
	
	# Draw bezier curve with line segments
	var segments: int = 20
	var prev_point: Vector2 = from_pos
	
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var point: Vector2 = _bezier_point(from_pos, control1, control2, to_pos, t)
		draw_line(prev_point, point, color, 2.0)
		prev_point = point

## Calculates bezier curve point
func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	var tt: float = t * t
	var uu: float = u * u
	var uuu: float = uu * u
	var ttt: float = tt * t
	
	return uuu * p0 + 3 * uu * t * p1 + 3 * u * tt * p2 + ttt * p3

## Draws arrow head at connection end
func _draw_arrow_head(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var direction: Vector2 = (to_pos - from_pos).normalized()
	var arrow_size: float = 10.0 * zoom_level
	var arrow_angle: float = PI / 6.0  # 30 degrees
	
	var arrow_p1: Vector2 = to_pos - direction.rotated(arrow_angle) * arrow_size
	var arrow_p2: Vector2 = to_pos - direction.rotated(-arrow_angle) * arrow_size
	
	draw_line(to_pos, arrow_p1, color, 2.0)
	draw_line(to_pos, arrow_p2, color, 2.0)

## Draws connection preview while connecting
func _draw_connection_preview() -> void:
	if not connection_start_mission:
		return
	
	var from_pos: Vector2 = _world_to_screen(connection_start_mission.position + node_size * 0.5)
	var to_pos: Vector2 = get_local_mouse_position()
	
	draw_line(from_pos, to_pos, Color.WHITE, 2.0)

## Converts world coordinates to screen coordinates
func _world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos + viewport_offset) * zoom_level

## Converts screen coordinates to world coordinates
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return screen_pos / zoom_level - viewport_offset

## Checks if a rectangle is visible in the viewport
func _is_rect_visible(pos: Vector2, rect_size: Vector2) -> bool:
	return pos.x < size.x and pos.y < size.y and pos.x + rect_size.x > 0 and pos.y + rect_size.y > 0

## Handles input events
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key_input(event)

## Handles mouse button events
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_left_click(event.position)
		else:
			_handle_left_release(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click(event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at_position(event.position, 1.1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_at_position(event.position, 0.9)

## Handles left mouse click
func _handle_left_click(position: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(position)
	var clicked_mission: CampaignMissionDataNode = _get_mission_at_position(world_pos)
	
	if clicked_mission:
		if is_connecting:
			# Complete connection
			if connection_start_mission and clicked_mission != connection_start_mission:
				connection_created.emit(connection_start_mission.mission_data.mission_id, clicked_mission.mission_data.mission_id)
			_stop_connecting()
		else:
			# Start dragging mission
			_start_dragging_mission(clicked_mission, position)
			_select_mission_node(clicked_mission)
	else:
		if is_connecting:
			_stop_connecting()
		else:
			# Clear selection
			_clear_selection()

## Handles left mouse release
func _handle_left_release(position: Vector2) -> void:
	if is_dragging and dragging_mission:
		_stop_dragging_mission()

## Handles right mouse click
func _handle_right_click(position: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(position)
	var clicked_mission: CampaignMissionDataNode = _get_mission_at_position(world_pos)
	
	if clicked_mission:
		# Start connecting mode
		_start_connecting(clicked_mission)

## Handles mouse motion
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if is_dragging and dragging_mission:
		var world_delta: Vector2 = event.relative / zoom_level
		dragging_mission.position += world_delta
		_snap_to_grid(dragging_mission)
		queue_redraw()
		mission_moved.emit(dragging_mission.mission_data.mission_id, dragging_mission.position)
	elif is_connecting:
		queue_redraw()  # Update connection preview

## Handles key input
func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed:
		return
	
	match event.keycode:
		KEY_ESCAPE:
			if is_connecting:
				_stop_connecting()
			elif is_dragging:
				_stop_dragging_mission()
		KEY_DELETE:
			if not selected_mission_id.is_empty():
				# TODO: Delete selected mission or connection
				pass

## Gets mission node at world position
func _get_mission_at_position(world_pos: Vector2) -> CampaignMissionDataNode:
	for mission_id in mission_nodes:
		var node: CampaignMissionDataNode = mission_nodes[mission_id]
		var rect: Rect2 = Rect2(node.position, node_size)
		if rect.has_point(world_pos):
			return node
	return null

## Starts dragging a mission node
func _start_dragging_mission(mission_node: CampaignMissionDataNode, mouse_pos: Vector2) -> void:
	is_dragging = true
	dragging_mission = mission_node
	drag_start_position = mouse_pos

## Stops dragging mission node
func _stop_dragging_mission() -> void:
	is_dragging = false
	dragging_mission = null
	drag_start_position = Vector2.ZERO

## Starts connecting mode
func _start_connecting(mission_node: CampaignMissionDataNode) -> void:
	is_connecting = true
	connection_start_mission = mission_node

## Stops connecting mode
func _stop_connecting() -> void:
	is_connecting = false
	connection_start_mission = null
	queue_redraw()

## Selects a mission node
func _select_mission_node(mission_node: CampaignMissionDataNode) -> void:
	selected_mission_id = mission_node.mission_data.mission_id
	queue_redraw()
	mission_selected.emit(selected_mission_id)

## Clears mission selection
func _clear_selection() -> void:
	selected_mission_id = ""
	queue_redraw()

## Snaps mission position to grid
func _snap_to_grid(mission_node: CampaignMissionDataNode) -> void:
	if show_grid:
		mission_node.position.x = round(mission_node.position.x / grid_size) * grid_size
		mission_node.position.y = round(mission_node.position.y / grid_size) * grid_size

## Zooms at specific position
func _zoom_at_position(position: Vector2, zoom_factor: float) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clamp(zoom_level * zoom_factor, min_zoom, max_zoom)
	
	if zoom_level != old_zoom:
		# Adjust viewport offset to zoom at mouse position
		var world_pos_before: Vector2 = _screen_to_world(position)
		var world_pos_after: Vector2 = position / zoom_level - viewport_offset
		viewport_offset += world_pos_after - world_pos_before
		
		queue_redraw()

## Auto-fits diagram to viewport
func _auto_fit_diagram() -> void:
	if mission_nodes.is_empty():
		return
	
	# Calculate bounding box of all missions
	var min_pos: Vector2 = Vector2(INF, INF)
	var max_pos: Vector2 = Vector2(-INF, -INF)
	
	for mission_id in mission_nodes:
		var node: CampaignMissionDataNode = mission_nodes[mission_id]
		min_pos = min_pos.min(node.position)
		max_pos = max_pos.max(node.position + node_size)
	
	# Calculate zoom to fit
	var content_size: Vector2 = max_pos - min_pos
	var zoom_x: float = size.x / (content_size.x + 100)  # Add padding
	var zoom_y: float = size.y / (content_size.y + 100)
	zoom_level = clamp(min(zoom_x, zoom_y), min_zoom, max_zoom)
	
	# Center content
	var content_center: Vector2 = (min_pos + max_pos) * 0.5
	var screen_center: Vector2 = size * 0.5
	viewport_offset = screen_center / zoom_level - content_center
	
	queue_redraw()

## Signal Handlers

func _on_mission_node_selected(mission_node: CampaignMissionDataNode) -> void:
	_select_mission_node(mission_node)

func _on_mission_node_dragged(mission_node: CampaignMissionDataNode, delta: Vector2) -> void:
	mission_node.position += delta / zoom_level
	_snap_to_grid(mission_node)
	queue_redraw()
	mission_moved.emit(mission_node.mission_data.mission_id, mission_node.position)

func _on_connection_requested(mission_node: CampaignMissionDataNode) -> void:
	_start_connecting(mission_node)

## Public API

## Selects a mission by ID
func select_mission(mission_id: String) -> void:
	selected_mission_id = mission_id
	queue_redraw()

## Zooms in
func zoom_in() -> void:
	_zoom_at_position(size * 0.5, 1.2)

## Zooms out
func zoom_out() -> void:
	_zoom_at_position(size * 0.5, 0.8)

## Zooms to fit all content
func zoom_to_fit() -> void:
	_auto_fit_diagram()

## Auto-layouts missions
func auto_layout_missions() -> void:
	if not campaign_data or mission_nodes.is_empty():
		return
	
	# Simple hierarchical layout
	var starting_missions: Array[CampaignMissionData] = campaign_data.get_starting_missions()
	var positioned: Dictionary = {}
	var current_y: float = 0.0
	
	for start_mission in starting_missions:
		_layout_mission_tree(start_mission, Vector2(0, current_y), positioned, 0)
		current_y += node_spacing.y * 3  # Space between different trees
	
	queue_redraw()
	layout_changed.emit()

## Recursively layouts mission tree
func _layout_mission_tree(mission: CampaignMissionData, position: Vector2, positioned: Dictionary, depth: int) -> void:
	if positioned.has(mission.mission_id):
		return
	
	# Position this mission
	mission.position = position
	if mission_nodes.has(mission.mission_id):
		mission_nodes[mission.mission_id].position = position
	positioned[mission.mission_id] = true
	
	# Layout dependent missions
	var dependents: Array[CampaignMissionData] = campaign_data.get_dependent_missions(mission.mission_id)
	var child_y: float = position.y
	
	for dependent in dependents:
		if not positioned.has(dependent.mission_id):
			var child_pos: Vector2 = Vector2(position.x + node_spacing.x, child_y)
			_layout_mission_tree(dependent, child_pos, positioned, depth + 1)
			child_y += node_spacing.y

class_name CampaignMissionDataNode
extends Control

## Individual mission node in the campaign flow diagram.

signal mission_selected(mission_node: CampaignMissionDataNode)
signal mission_dragged(mission_node: CampaignMissionDataNode, delta: Vector2)
signal connection_requested(mission_node: CampaignMissionDataNode)

var mission_data: CampaignMissionData = null

func setup_mission_node(mission: CampaignMissionData) -> void:
	mission_data = mission
	name = "MissionNode_%s" % mission.mission_id

class_name CampaignConnectionLine
extends RefCounted

## Connection line between missions in the campaign flow.

enum ConnectionType {
	PREREQUISITE,
	BRANCH
}

var connection_type: ConnectionType = ConnectionType.PREREQUISITE
var from_node: CampaignMissionDataNode = null
var to_node: CampaignMissionDataNode = null
var from_mission_id: String = ""
var to_mission_id: String = ""
var branch_info: CampaignMissionDataBranch = null

func setup_connection(from: CampaignMissionDataNode, to: CampaignMissionDataNode, from_id: String, to_id: String) -> void:
	from_node = from
	to_node = to
	from_mission_id = from_id
	to_mission_id = to_id