@tool
class_name DependencyGraphView
extends Control

## Dependency graph visualization for GFRED2 mission editor
## Scene: addons/gfred2/scenes/components/dependency_graph_view.tscn
## Displays mission object dependencies and asset relationships with interactive graph
## Integrates with MissionValidationController for real-time dependency tracking

signal node_selected(node_id: String, dependency_info: MissionValidationController.DependencyInfo)
signal dependency_highlighted(from_id: String, to_id: String)
signal graph_layout_changed()

## Scene node references (from scene)
@onready var refresh_button: Button = $VBoxContainer/ToolbarPanel/RefreshButton
@onready var layout_button: OptionButton = $VBoxContainer/ToolbarPanel/LayoutButton
@onready var filter_edit: LineEdit = $VBoxContainer/ToolbarPanel/FilterContainer/FilterLineEdit
@onready var errors_only_check: CheckBox = $VBoxContainer/ToolbarPanel/ShowErrorsOnly
@onready var graph_canvas: Control = $VBoxContainer/GraphContainer/GraphViewport/GraphCanvas
@onready var status_label: Label = $VBoxContainer/StatusBar/StatusLabel
@onready var count_label: Label = $VBoxContainer/StatusBar/DependencyCount

## Graph configuration
@export var auto_layout: bool = true
@export var show_asset_nodes: bool = true
@export var show_sexp_nodes: bool = true
@export var highlight_errors: bool = true
@export var animate_layout: bool = true

## Visual styling
@export var node_spacing: Vector2 = Vector2(200, 150)
@export var error_color: Color = Color.RED
@export var warning_color: Color = Color.YELLOW
@export var valid_color: Color = Color.GREEN
@export var dependency_color: Color = Color.CYAN

## Performance configuration
@export var max_nodes: int = 100  # Limit for performance
@export var layout_timeout_ms: int = 1000

## Core data
var dependency_graph: MissionValidationController.DependencyGraph
var mission_data: MissionData
var node_registry: Dictionary = {}  # node_id -> GraphNode
var connection_registry: Dictionary = {}  # connection_id -> connection_info

## Layout management
var layout_algorithm: GraphLayoutAlgorithm
var layout_tween: Tween

## Node types
enum NodeType {
	MISSION_OBJECT,
	ASSET_REFERENCE,
	SEXP_REFERENCE,
	MISSION_ROOT
}

class GraphLayoutAlgorithm:
	extends RefCounted
	
	var graph_view: DependencyGraphView
	var nodes: Array[GraphNode] = []
	var connections: Array[Dictionary] = []
	
	func _init(view: DependencyGraphView) -> void:
		graph_view = view
	
	func calculate_layout() -> Dictionary:
		"""Calculate optimal layout for graph nodes.
		Returns:
			Dictionary mapping node_id -> Vector2 position"""
		
		var positions: Dictionary = {}
		
		if nodes.is_empty():
			return positions
		
		# Use simple force-directed layout for now
		# TODO: Implement more sophisticated algorithms for larger graphs
		
		# Start with circular layout
		var center: Vector2 = Vector2(400, 300)
		var radius: float = 200.0
		
		for i in range(nodes.size()):
			var node: GraphNode = nodes[i]
			var angle: float = (i * 2.0 * PI) / nodes.size()
			var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			positions[node.name] = pos
		
		# Apply force-directed adjustments
		positions = _apply_force_directed_layout(positions, 5)  # 5 iterations
		
		return positions
	
	func _apply_force_directed_layout(initial_positions: Dictionary, iterations: int) -> Dictionary:
		"""Apply force-directed layout algorithm.
		Args:
			initial_positions: Starting positions
			iterations: Number of iterations to run
		Returns:
			Optimized positions"""
		
		var positions: Dictionary = initial_positions.duplicate()
		var repulsion_strength: float = 50000.0
		var attraction_strength: float = 100.0
		var damping: float = 0.8
		
		for iteration in range(iterations):
			var forces: Dictionary = {}
			
			# Initialize forces
			for node_id in positions.keys():
				forces[node_id] = Vector2.ZERO
			
			# Repulsion forces between all nodes
			var node_ids: Array = positions.keys()
			for i in range(node_ids.size()):
				for j in range(i + 1, node_ids.size()):
					var id1: String = node_ids[i]
					var id2: String = node_ids[j]
					var pos1: Vector2 = positions[id1]
					var pos2: Vector2 = positions[id2]
					
					var diff: Vector2 = pos1 - pos2
					var distance: float = diff.length()
					
					if distance > 0:
						var force: Vector2 = diff.normalized() * (repulsion_strength / (distance * distance))
						forces[id1] += force
						forces[id2] -= force
			
			# Attraction forces for connected nodes
			for connection in connections:
				var from_id: String = connection.from
				var to_id: String = connection.to
				
				if positions.has(from_id) and positions.has(to_id):
					var pos1: Vector2 = positions[from_id]
					var pos2: Vector2 = positions[to_id]
					var diff: Vector2 = pos2 - pos1
					var distance: float = diff.length()
					
					if distance > 0:
						var force: Vector2 = diff.normalized() * (attraction_strength * distance * 0.01)
						forces[from_id] += force
						forces[to_id] -= force
			
			# Apply forces with damping
			for node_id in positions.keys():
				var force: Vector2 = forces[node_id] * damping
				positions[node_id] += force
			
			damping *= 0.95  # Gradually reduce damping
		
		return positions

func _ready() -> void:
	name = "DependencyGraphView"
	
	# Initialize layout algorithm
	layout_algorithm = GraphLayoutAlgorithm.new(self)
	
	# Create layout tween for animations
	if animate_layout:
		layout_tween = Tween.new()
		add_child(layout_tween)
	
	# Connect UI signals
	refresh_button.pressed.connect(_on_refresh_pressed)
	layout_button.item_selected.connect(_on_layout_changed)
	filter_edit.text_changed.connect(_on_filter_changed)
	errors_only_check.toggled.connect(_on_errors_only_toggled)
	
	# Setup layout options
	layout_button.add_item("Tree Layout")
	layout_button.add_item("Force-Directed")
	layout_button.add_item("Circular")
	
	# Initialize status
	_update_status_display()

func set_dependency_graph(graph: MissionValidationController.DependencyGraph, mission: MissionData) -> void:
	"""Set dependency graph data and rebuild visualization.
	Args:
		graph: Dependency graph to visualize
		mission: Mission data for context"""
	
	dependency_graph = graph
	mission_data = mission
	
	_rebuild_graph()

func _rebuild_graph() -> void:
	"""Rebuild the entire graph visualization."""
	
	if not dependency_graph or not mission_data:
		return
	
	# Clear existing graph
	_clear_graph()
	
	# Performance check
	var total_nodes: int = _count_total_nodes()
	if total_nodes > max_nodes:
		_show_performance_warning(total_nodes)
		return
	
	# Create nodes
	_create_mission_root_node()
	_create_mission_object_nodes()
	
	if show_asset_nodes:
		_create_asset_nodes()
	
	if show_sexp_nodes:
		_create_sexp_nodes()
	
	# Create connections
	_create_connections()
	
	# Apply layout
	if auto_layout:
		_apply_automatic_layout()

func _clear_graph() -> void:
	"""Remove all nodes and connections from the graph."""
	
	# Remove all graph nodes
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
	
	# Clear registries
	node_registry.clear()
	connection_registry.clear()
	
	# Clear connections
	clear_connections()

func _count_total_nodes() -> int:
	"""Count total nodes that would be created.
	Returns:
		Total node count for performance checking"""
	
	var count: int = 1  # Mission root
	
	if mission_data.objects:
		count += mission_data.objects.size()
	
	if show_asset_nodes and dependency_graph.nodes:
		for dep_info in dependency_graph.nodes.values():
			var info: MissionValidationController.DependencyInfo = dep_info as MissionValidationController.DependencyInfo
			if info.dependency_type == "asset":
				count += 1
	
	if show_sexp_nodes and dependency_graph.nodes:
		for dep_info in dependency_graph.nodes.values():
			var info: MissionValidationController.DependencyInfo = dep_info as MissionValidationController.DependencyInfo
			if info.dependency_type == "sexp_reference":
				count += 1
	
	return count

func _show_performance_warning(node_count: int) -> void:
	"""Show performance warning for large graphs.
	Args:
		node_count: Number of nodes that would be created"""
	
	# Create warning node
	var warning_node: GraphNode = _create_graph_node("performance_warning", "Performance Warning")
	warning_node.position_offset = Vector2(200, 100)
	
	var warning_label: Label = Label.new()
	warning_label.text = "Graph too large to display efficiently (%d nodes)\nMax nodes: %d\nConsider filtering the view." % [node_count, max_nodes]
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color", warning_color)
	warning_node.add_child(warning_label)

func _create_mission_root_node() -> void:
	"""Create the root mission node."""
	
	var root_node: GraphNode = _create_graph_node("mission_root", "Mission")
	root_node.position_offset = Vector2(400, 50)
	
	# Mission info
	var info_label: Label = Label.new()
	if mission_data.mission_info:
		info_label.text = mission_data.mission_info.name
	else:
		info_label.text = "Unnamed Mission"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_node.add_child(info_label)
	
	# Set node styling
	_style_node_by_type(root_node, NodeType.MISSION_ROOT)

func _create_mission_object_nodes() -> void:
	"""Create nodes for mission objects."""
	
	if not mission_data.objects:
		return
	
	for i in range(mission_data.objects.size()):
		var obj: MissionObjectData = mission_data.objects[i]
		if not obj:
			continue
		
		var object_id: String = obj.object_id if not obj.object_id.is_empty() else "object_%d" % i
		var display_name: String = obj.object_name if not obj.object_name.is_empty() else object_id
		
		var node: GraphNode = _create_graph_node(object_id, display_name)
		
		# Object details
		var details_label: Label = Label.new()
		details_label.text = "Type: %s\nClass: %s" % [_get_object_type_name(obj), obj.ship_class]
		details_label.add_theme_font_size_override("font_size", 8)
		node.add_child(details_label)
		
		# Validation indicator
		var indicator: ValidationIndicator = ValidationIndicator.new()
		indicator.show_text_label = false
		indicator.indicator_size = Vector2(12, 12)
		
		# Get validation result if available  
		# TODO: Connect to actual validation results
		indicator.set_unknown()
		
		node.add_child(indicator)
		
		_style_node_by_type(node, NodeType.MISSION_OBJECT)

func _create_asset_nodes() -> void:
	"""Create nodes for asset dependencies."""
	
	if not dependency_graph.nodes:
		return
	
	for dep_info_variant in dependency_graph.nodes.values():
		var dep_info: MissionValidationController.DependencyInfo = dep_info_variant as MissionValidationController.DependencyInfo
		
		if dep_info.dependency_type != "asset":
			continue
		
		var asset_id: String = "asset_" + dep_info.dependency_path.get_file().get_basename()
		var display_name: String = dep_info.dependency_path.get_file()
		
		if node_registry.has(asset_id):
			continue  # Already created
		
		var node: GraphNode = _create_graph_node(asset_id, display_name)
		
		# Asset details
		var details_label: Label = Label.new()
		details_label.text = "Asset: %s" % dep_info.dependency_path
		details_label.add_theme_font_size_override("font_size", 8)
		node.add_child(details_label)
		
		# Validation indicator
		var indicator: ValidationIndicator = ValidationIndicator.new()
		indicator.show_text_label = false
		indicator.indicator_size = Vector2(12, 12)
		
		if dep_info.is_valid:
			indicator.set_valid()
		else:
			indicator.set_error(null)  # TODO: Pass actual ValidationResult
		
		node.add_child(indicator)
		
		_style_node_by_type(node, NodeType.ASSET_REFERENCE)

func _create_sexp_nodes() -> void:
	"""Create nodes for SEXP references."""
	
	if not dependency_graph.nodes:
		return
	
	for dep_info_variant in dependency_graph.nodes.values():
		var dep_info: MissionValidationController.DependencyInfo = dep_info_variant as MissionValidationController.DependencyInfo
		
		if dep_info.dependency_type != "sexp_reference":
			continue
		
		var sexp_id: String = "sexp_%d" % dep_info.dependency_path.hash()
		var display_name: String = "SEXP Expression"
		
		if node_registry.has(sexp_id):
			continue  # Already created
		
		var node: GraphNode = _create_graph_node(sexp_id, display_name)
		
		# SEXP details  
		var details_label: Label = Label.new()
		var sexp_preview: String = dep_info.dependency_path
		if sexp_preview.length() > 30:
			sexp_preview = sexp_preview.substr(0, 30) + "..."
		details_label.text = "SEXP: %s" % sexp_preview
		details_label.add_theme_font_size_override("font_size", 8)
		node.add_child(details_label)
		
		# Validation indicator
		var indicator: ValidationIndicator = ValidationIndicator.new()
		indicator.show_text_label = false
		indicator.indicator_size = Vector2(12, 12)
		
		if dep_info.is_valid:
			indicator.set_valid()
		else:
			indicator.set_error(null)  # TODO: Pass actual ValidationResult
		
		node.add_child(indicator)
		
		_style_node_by_type(node, NodeType.SEXP_REFERENCE)

func _create_graph_node(node_id: String, title: String) -> GraphNode:
	"""Create a new graph node with standard configuration.
	Args:
		node_id: Unique identifier for the node
		title: Display title for the node
	Returns:
		Configured GraphNode"""
	
	var node: GraphNode = GraphNode.new()
	node.name = node_id
	node.title = title
	node.resizable = false
	node.selectable = true
	
	# Set default size
	node.custom_minimum_size = Vector2(150, 80)
	
	add_child(node)
	node_registry[node_id] = node
	
	return node

func _style_node_by_type(node: GraphNode, type: NodeType) -> void:
	"""Apply styling based on node type.
	Args:
		node: GraphNode to style
		type: Type of node for styling"""
	
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	
	match type:
		NodeType.MISSION_ROOT:
			style_box.bg_color = Color(0.3, 0.3, 0.8, 0.8)  # Blue
			style_box.border_color = Color(0.2, 0.2, 0.6)
		NodeType.MISSION_OBJECT:
			style_box.bg_color = Color(0.3, 0.8, 0.3, 0.8)  # Green
			style_box.border_color = Color(0.2, 0.6, 0.2)
		NodeType.ASSET_REFERENCE:
			style_box.bg_color = Color(0.8, 0.6, 0.3, 0.8)  # Orange
			style_box.border_color = Color(0.6, 0.4, 0.2)
		NodeType.SEXP_REFERENCE:
			style_box.bg_color = Color(0.8, 0.3, 0.8, 0.8)  # Purple
			style_box.border_color = Color(0.6, 0.2, 0.6)
	
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	
	node.add_theme_stylebox_override("frame", style_box)

func _create_connections() -> void:
	"""Create connections between nodes based on dependencies."""
	
	if not dependency_graph.edges:
		return
	
	for from_id in dependency_graph.edges.keys():
		var dependencies: Array[String] = dependency_graph.edges[from_id]
		
		for dep_path in dependencies:
			if dependency_graph.nodes.has(dep_path):
				var dep_info: MissionValidationController.DependencyInfo = dependency_graph.nodes[dep_path]
				
				var to_id: String
				match dep_info.dependency_type:
					"asset":
						to_id = "asset_" + dep_path.get_file().get_basename()
					"sexp_reference":
						to_id = "sexp_%d" % dep_path.hash()
					_:
						continue
				
				if node_registry.has(from_id) and node_registry.has(to_id):
					_create_connection(from_id, to_id, dep_info)

func _create_connection(from_id: String, to_id: String, dep_info: MissionValidationController.DependencyInfo) -> void:
	"""Create a connection between two nodes.
	Args:
		from_id: Source node ID
		to_id: Target node ID  
		dep_info: Dependency information for styling"""
	
	var connection_id: String = "%s -> %s" % [from_id, to_id]
	
	# Skip if connection already exists
	if connection_registry.has(connection_id):
		return
	
	# Create connection in GraphEdit
	var from_node: GraphNode = node_registry.get(from_id)
	var to_node: GraphNode = node_registry.get(to_id)
	
	if from_node and to_node:
		# Add output slot to from_node if needed
		if from_node.get_connection_output_count() == 0:
			from_node.set_slot_enabled_right(0, true)
			from_node.set_slot_type_right(0, 0)
		
		# Add input slot to to_node if needed
		if to_node.get_connection_input_count() == 0:
			to_node.set_slot_enabled_left(0, true)
			to_node.set_slot_type_left(0, 0)
		
		# Create the connection
		connect_node(from_id, 0, to_id, 0)
		
		# Store connection info
		connection_registry[connection_id] = {
			"from": from_id,
			"to": to_id,
			"dependency_info": dep_info
		}
		
		# Style connection based on validity
		if highlight_errors and not dep_info.is_valid:
			_highlight_connection_error(from_id, to_id)

func _highlight_connection_error(from_id: String, to_id: String) -> void:
	"""Highlight a connection that has errors.
	Args:
		from_id: Source node ID
		to_id: Target node ID"""
	
	# TODO: Implement connection highlighting when Godot supports it
	# For now, we can style the nodes
	var from_node: GraphNode = node_registry.get(from_id)
	var to_node: GraphNode = node_registry.get(to_id)
	
	if from_node:
		from_node.modulate = Color(1.0, 0.8, 0.8)  # Light red tint
	if to_node:
		to_node.modulate = Color(1.0, 0.8, 0.8)

func _apply_automatic_layout() -> void:
	"""Apply automatic layout to arrange nodes optimally."""
	
	if not layout_algorithm:
		return
	
	# Prepare data for layout algorithm
	layout_algorithm.nodes.clear()
	layout_algorithm.connections.clear()
	
	for node in node_registry.values():
		layout_algorithm.nodes.append(node as GraphNode)
	
	for connection_info in connection_registry.values():
		layout_algorithm.connections.append(connection_info)
	
	# Calculate optimal positions
	var positions: Dictionary = layout_algorithm.calculate_layout()
	
	# Apply positions with animation
	if animate_layout and layout_tween:
		_animate_to_positions(positions)
	else:
		_apply_positions_immediately(positions)

func _animate_to_positions(positions: Dictionary) -> void:
	"""Animate nodes to their new positions.
	Args:
		positions: Dictionary mapping node_id -> Vector2 position"""
	
	for node_id in positions.keys():
		var node: GraphNode = node_registry.get(node_id)
		var target_pos: Vector2 = positions[node_id]
		
		if node:
			layout_tween.tween_property(node, "position_offset", target_pos, 0.5)

func _apply_positions_immediately(positions: Dictionary) -> void:
	"""Apply node positions immediately without animation.
	Args:
		positions: Dictionary mapping node_id -> Vector2 position"""
	
	for node_id in positions.keys():
		var node: GraphNode = node_registry.get(node_id)
		var target_pos: Vector2 = positions[node_id]
		
		if node:
			node.position_offset = target_pos

func _get_object_type_name(obj: MissionObjectData) -> String:
	"""Get human-readable object type name.
	Args:
		obj: Mission object to get type for
	Returns:
		Type name string"""
	
	# TODO: Implement when MissionObjectData.ObjectType is available
	return "Ship"  # Placeholder

## Signal handlers

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	"""Handle connection request from user."""
	# Prevent user-created connections in dependency view
	pass

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	"""Handle disconnection request from user."""
	# Prevent user disconnections in dependency view
	pass

func _on_graph_node_selected(node: Node) -> void:
	"""Handle node selection.
	Args:
		node: Selected GraphNode"""
	
	if node is GraphNode:
		var graph_node: GraphNode = node as GraphNode
		var node_id: String = graph_node.name
		
		# Find associated dependency info
		var dep_info: MissionValidationController.DependencyInfo = null
		for dep_info_variant in dependency_graph.nodes.values():
			var info: MissionValidationController.DependencyInfo = dep_info_variant as MissionValidationController.DependencyInfo
			if info.object_id == node_id:
				dep_info = info
				break
		
		node_selected.emit(node_id, dep_info)

## Public API

func refresh_graph() -> void:
	"""Refresh the graph display."""
	_rebuild_graph()

func highlight_dependency_path(from_id: String, to_id: String) -> void:
	"""Highlight a dependency path in the graph.
	Args:
		from_id: Source node ID
		to_id: Target node ID"""
	
	dependency_highlighted.emit(from_id, to_id)
	
	# Visual highlighting
	var from_node: GraphNode = node_registry.get(from_id)
	var to_node: GraphNode = node_registry.get(to_id)
	
	if from_node:
		from_node.modulate = Color(1.2, 1.2, 1.0)  # Bright highlight
	if to_node:
		to_node.modulate = Color(1.2, 1.2, 1.0)

func clear_highlights() -> void:
	"""Clear all visual highlights."""
	
	for node in node_registry.values():
		var graph_node: GraphNode = node as GraphNode
		graph_node.modulate = Color.WHITE

func filter_by_type(types: Array[NodeType]) -> void:
	"""Filter nodes by type.
	Args:
		types: Array of node types to show"""
	
	# TODO: Implement node filtering
	# For now, just update the show flags
	show_asset_nodes = types.has(NodeType.ASSET_REFERENCE)
	show_sexp_nodes = types.has(NodeType.SEXP_REFERENCE)
	
	_rebuild_graph()

func export_graph_image() -> Image:
	"""Export the current graph as an image.
	Returns:
		Image of the current graph"""
	
	# TODO: Implement graph export
	return null

func get_node_count() -> int:
	"""Get the current number of nodes.
	Returns:
		Number of nodes in the graph"""
	
	return node_registry.size()

func get_connection_count() -> int:
	"""Get the current number of connections.
	Returns:
		Number of connections in the graph"""
	
	return connection_registry.size()

func _update_status_display() -> void:
	"""Update status bar display."""
	
	if not dependency_graph:
		status_label.text = "No dependencies"
		count_label.text = "0 items"
		return
	
	var node_count: int = dependency_graph.nodes.size()
	var edge_count: int = 0
	for edges in dependency_graph.edges.values():
		edge_count += edges.size()
	
	status_label.text = "Dependency graph loaded"
	count_label.text = "%d nodes, %d connections" % [node_count, edge_count]

## Signal handlers

func _on_refresh_pressed() -> void:
	"""Handle refresh button press."""
	refresh_graph()

func _on_layout_changed(index: int) -> void:
	"""Handle layout algorithm selection change."""
	if auto_layout:
		_apply_automatic_layout()
	graph_layout_changed.emit()

func _on_filter_changed(text: String) -> void:
	"""Handle filter text change."""
	# TODO: Implement filtering
	refresh_graph()

func _on_errors_only_toggled(pressed: bool) -> void:
	"""Handle errors-only filter toggle."""
	# TODO: Implement error filtering
	refresh_graph()