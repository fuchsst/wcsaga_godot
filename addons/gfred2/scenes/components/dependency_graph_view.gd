@tool
class_name DependencyGraphView
extends Control

## Visual dependency graph visualization for GFRED2 mission editor
## Shows asset dependencies, object relationships, and validation status
## Part of mandatory scene-based UI architecture (EPIC-005)

signal node_selected(node_id: String, node_data: Dictionary)
signal dependency_selected(from_id: String, to_id: String)
signal graph_zoom_changed(zoom_level: float)

## Graph configuration
@export var auto_layout: bool = true
@export var show_validation_status: bool = true
@export var animate_layout: bool = true
@export var max_nodes_displayed: int = 100
@export var zoom_limits: Vector2 = Vector2(0.1, 3.0)

## UI nodes - configured in scene, accessed via onready
@onready var graph_edit: GraphEdit = $VBoxContainer/GraphEdit
@onready var toolbar: HBoxContainer = $VBoxContainer/Toolbar
@onready var layout_button: Button = $VBoxContainer/Toolbar/LayoutButton
@onready var filter_option: OptionButton = $VBoxContainer/Toolbar/FilterOption
@onready var search_box: LineEdit = $VBoxContainer/Toolbar/SearchBox
@onready var info_panel: Panel = $VBoxContainer/InfoPanel
@onready var info_label: RichTextLabel = $VBoxContainer/InfoPanel/InfoLabel

## Graph state
var dependency_graph: MissionValidationController.DependencyGraph
var graph_nodes: Dictionary = {}  # String -> GraphNode
var validation_results: Dictionary = {}  # String -> ValidationResult
var current_filter: FilterType = FilterType.ALL
var search_query: String = ""

## Graph visualization data
var node_positions: Dictionary = {}  # String -> Vector2
var layout_in_progress: bool = false

## Node types and colors
enum NodeType {
	MISSION_OBJECT,
	ASSET_REFERENCE,
	SEXP_REFERENCE,
	VALIDATION_ISSUE
}

enum FilterType {
	ALL,
	OBJECTS_ONLY,
	ASSETS_ONLY,
	ERRORS_ONLY,
	WARNINGS_ONLY
}

var node_type_colors: Dictionary = {
	NodeType.MISSION_OBJECT: Color.LIGHT_BLUE,
	NodeType.ASSET_REFERENCE: Color.LIGHT_GREEN,
	NodeType.SEXP_REFERENCE: Color.LIGHT_CORAL,
	NodeType.VALIDATION_ISSUE: Color.ORANGE_RED
}

func _ready() -> void:
	name = "DependencyGraphView"
	
	# Setup graph edit
	if graph_edit:
		graph_edit.connection_request.connect(_on_connection_request)
		graph_edit.disconnection_request.connect(_on_disconnection_request)
		graph_edit.node_selected.connect(_on_node_selected)
		graph_edit.scroll_offset_changed.connect(_on_scroll_changed)
		graph_edit.zoom_changed.connect(_on_zoom_changed)
	
	# Setup toolbar controls
	if layout_button:
		layout_button.pressed.connect(_auto_layout_graph)
		layout_button.text = "Auto Layout"
	
	if filter_option:
		_setup_filter_options()
		filter_option.item_selected.connect(_on_filter_changed)
	
	if search_box:
		search_box.text_changed.connect(_on_search_changed)
		search_box.placeholder_text = "Search nodes..."
	
	# Initialize info panel
	if info_panel:
		info_panel.visible = false

func _setup_filter_options() -> void:
	"""Setup filter dropdown options."""
	
	if not filter_option:
		return
	
	filter_option.clear()
	filter_option.add_item("All", FilterType.ALL)
	filter_option.add_item("Objects Only", FilterType.OBJECTS_ONLY)
	filter_option.add_item("Assets Only", FilterType.ASSETS_ONLY)
	filter_option.add_item("Errors Only", FilterType.ERRORS_ONLY)
	filter_option.add_item("Warnings Only", FilterType.WARNINGS_ONLY)

func set_dependency_graph(graph: MissionValidationController.DependencyGraph) -> void:
	"""Update dependency graph visualization.
	Args:
		graph: Dependency graph to display"""
	
	dependency_graph = graph
	_rebuild_graph_visualization()

func set_validation_results(results: Dictionary) -> void:
	"""Update validation results for graph nodes.
	Args:
		results: Dictionary mapping node IDs to ValidationResult objects"""
	
	validation_results = results
	_update_validation_indicators()

func _rebuild_graph_visualization() -> void:
	"""Rebuild entire graph visualization from dependency data."""
	
	if not graph_edit or not dependency_graph:
		return
	
	# Clear existing graph
	_clear_graph()
	
	# Check node limit
	var total_nodes: int = dependency_graph.nodes.size()
	if total_nodes > max_nodes_displayed:
		_show_node_limit_warning(total_nodes)
		return
	
	# Create nodes for dependencies
	for dependency_path in dependency_graph.nodes.keys():
		var dependency_info: MissionValidationController.DependencyInfo = dependency_graph.nodes[dependency_path]
		_create_dependency_node(dependency_info)
	
	# Create nodes for objects that have dependencies
	for object_id in dependency_graph.edges.keys():
		if not graph_nodes.has(object_id):
			_create_object_node(object_id)
	
	# Create connections
	_create_graph_connections()
	
	# Apply layout
	if auto_layout:
		_auto_layout_graph()
	
	# Apply current filter
	_apply_current_filter()

func _clear_graph() -> void:
	"""Clear all nodes and connections from graph."""
	
	if not graph_edit:
		return
	
	graph_edit.clear_connections()
	
	for node in graph_nodes.values():
		if node and is_instance_valid(node):
			node.queue_free()
	
	graph_nodes.clear()
	node_positions.clear()

func _create_dependency_node(dependency_info: MissionValidationController.DependencyInfo) -> GraphNode:
	"""Create a graph node for a dependency.
	Args:
		dependency_info: Dependency information
	Returns:
		Created GraphNode"""
	
	var node: GraphNode = GraphNode.new()
	var node_id: String = dependency_info.dependency_path
	
	# Configure node appearance
	node.title = _get_display_name(dependency_info.dependency_path)
	node.name = "DependencyNode_" + node_id.replace("/", "_").replace(":", "_")
	
	# Set node type color
	var node_type: NodeType = _get_dependency_node_type(dependency_info)
	var base_color: Color = node_type_colors.get(node_type, Color.WHITE)
	
	# Create node content
	var content: VBoxContainer = VBoxContainer.new()
	
	# Type label
	var type_label: Label = Label.new()
	type_label.text = dependency_info.dependency_type.capitalize()
	type_label.add_theme_color_override("font_color", base_color.darkened(0.3))
	content.add_child(type_label)
	
	# Path label
	var path_label: Label = Label.new()
	path_label.text = dependency_info.dependency_path
	path_label.clip_contents = true
	path_label.custom_minimum_size.x = 150
	content.add_child(path_label)
	
	# Validation indicator
	if show_validation_status:
		var validation_indicator: ValidationIndicator = preload("res://addons/gfred2/scenes/components/validation_indicator.tscn").instantiate()
		_configure_node_validation_indicator(validation_indicator, dependency_info)
		content.add_child(validation_indicator)
	
	node.add_child(content)
	
	# Configure node properties
	node.position_offset = _calculate_node_position(node_id)
	node.resizable = false
	node.selected = false
	
	# Add to graph
	graph_edit.add_child(node)
	graph_nodes[node_id] = node
	
	return node

func _create_object_node(object_id: String) -> GraphNode:
	"""Create a graph node for a mission object.
	Args:
		object_id: Object identifier
	Returns:
		Created GraphNode"""
	
	var node: GraphNode = GraphNode.new()
	
	# Configure node appearance
	node.title = object_id
	node.name = "ObjectNode_" + object_id.replace(" ", "_")
	
	# Create node content
	var content: VBoxContainer = VBoxContainer.new()
	
	# Object type label
	var type_label: Label = Label.new()
	type_label.text = "Mission Object"
	type_label.add_theme_color_override("font_color", node_type_colors[NodeType.MISSION_OBJECT].darkened(0.3))
	content.add_child(type_label)
	
	# Dependencies count
	var dependencies: Array[MissionValidationController.DependencyInfo] = dependency_graph.get_dependencies(object_id)
	var dep_label: Label = Label.new()
	dep_label.text = "%d dependencies" % dependencies.size()
	content.add_child(dep_label)
	
	# Validation indicator
	if show_validation_status and validation_results.has(object_id):
		var validation_indicator: ValidationIndicator = preload("res://addons/gfred2/scenes/components/validation_indicator.tscn").instantiate()
		validation_indicator.set_validation_result(validation_results[object_id])
		content.add_child(validation_indicator)
	
	node.add_child(content)
	
	# Configure node properties
	node.position_offset = _calculate_node_position(object_id)
	node.resizable = false
	node.selected = false
	
	# Add to graph
	graph_edit.add_child(node)
	graph_nodes[object_id] = node
	
	return node

func _create_graph_connections() -> void:
	"""Create connections between graph nodes based on dependencies."""
	
	if not graph_edit or not dependency_graph:
		return
	
	for object_id in dependency_graph.edges.keys():
		if not graph_nodes.has(object_id):
			continue
		
		var object_node: GraphNode = graph_nodes[object_id]
		var dependencies: Array[String] = dependency_graph.edges[object_id]
		
		for dependency_path in dependencies:
			if graph_nodes.has(dependency_path):
				var dependency_node: GraphNode = graph_nodes[dependency_path]
				
				# Create connection from object to dependency
				var error: Error = graph_edit.connect_node(object_node.name, 0, dependency_node.name, 0)
				if error != OK:
					push_warning("Failed to connect nodes: %s -> %s" % [object_id, dependency_path])

func _get_dependency_node_type(dependency_info: MissionValidationController.DependencyInfo) -> NodeType:
	"""Determine node type based on dependency information.
	Args:
		dependency_info: Dependency information
	Returns:
		NodeType for visualization"""
	
	match dependency_info.dependency_type:
		"asset":
			return NodeType.ASSET_REFERENCE
		"sexp_reference":
			return NodeType.SEXP_REFERENCE
		_:
			return NodeType.MISSION_OBJECT

func _configure_node_validation_indicator(indicator: ValidationIndicator, dependency_info: MissionValidationController.DependencyInfo) -> void:
	"""Configure validation indicator for dependency node.
	Args:
		indicator: ValidationIndicator to configure
		dependency_info: Dependency information"""
	
	if not dependency_info.is_valid:
		# Create validation result for error display
		var result: ValidationResult = ValidationResult.new()
		result.add_error(dependency_info.error_message)
		indicator.set_validation_result(result)
	else:
		indicator.set_validation_status(ValidationIndicator.ValidationStatus.VALID)

func _calculate_node_position(node_id: String) -> Vector2:
	"""Calculate initial position for a graph node.
	Args:
		node_id: Node identifier
	Returns:
		Position for the node"""
	
	# Check for cached position
	if node_positions.has(node_id):
		return node_positions[node_id]
	
	# Simple grid layout as fallback
	var grid_size: int = int(sqrt(graph_nodes.size() + 1))
	var grid_index: int = graph_nodes.size()
	var grid_x: int = grid_index % grid_size
	var grid_y: int = grid_index / grid_size
	
	var position: Vector2 = Vector2(grid_x * 200 + 50, grid_y * 150 + 50)
	node_positions[node_id] = position
	
	return position

func _auto_layout_graph() -> void:
	"""Automatically layout graph nodes using force-directed algorithm."""
	
	if layout_in_progress or graph_nodes.is_empty():
		return
	
	layout_in_progress = true
	
	# Simple circular layout for now - can be enhanced with force-directed later
	var center: Vector2 = Vector2(200, 200)
	var radius: float = 150.0
	var node_count: int = graph_nodes.size()
	
	var i: int = 0
	for node_id in graph_nodes.keys():
		var angle: float = (float(i) / float(node_count)) * 2.0 * PI
		var position: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		
		var node: GraphNode = graph_nodes[node_id]
		if node:
			if animate_layout:
				var tween: Tween = create_tween()
				tween.tween_property(node, "position_offset", position, 0.5)
			else:
				node.position_offset = position
		
		node_positions[node_id] = position
		i += 1
	
	layout_in_progress = false

func _update_validation_indicators() -> void:
	"""Update validation indicators on all graph nodes."""
	
	if not show_validation_status:
		return
	
	for node_id in graph_nodes.keys():
		var node: GraphNode = graph_nodes[node_id]
		if not node:
			continue
		
		# Find validation indicator in node
		var validation_indicator: ValidationIndicator = _find_validation_indicator_in_node(node)
		if not validation_indicator:
			continue
		
		# Update with validation result if available
		if validation_results.has(node_id):
			validation_indicator.set_validation_result(validation_results[node_id])

func _find_validation_indicator_in_node(node: GraphNode) -> ValidationIndicator:
	"""Find ValidationIndicator component in a graph node.
	Args:
		node: GraphNode to search
	Returns:
		ValidationIndicator if found, null otherwise"""
	
	for child in node.get_children():
		if child is ValidationIndicator:
			return child as ValidationIndicator
		# Recursively search in containers
		if child is Container:
			var indicator: ValidationIndicator = _find_validation_indicator_recursive(child)
			if indicator:
				return indicator
	
	return null

func _find_validation_indicator_recursive(container: Container) -> ValidationIndicator:
	"""Recursively search for ValidationIndicator in container.
	Args:
		container: Container to search
	Returns:
		ValidationIndicator if found, null otherwise"""
	
	for child in container.get_children():
		if child is ValidationIndicator:
			return child as ValidationIndicator
		if child is Container:
			var indicator: ValidationIndicator = _find_validation_indicator_recursive(child)
			if indicator:
				return indicator
	
	return null

func _apply_current_filter() -> void:
	"""Apply current filter to graph nodes."""
	
	for node_id in graph_nodes.keys():
		var node: GraphNode = graph_nodes[node_id]
		if not node:
			continue
		
		var should_show: bool = _should_show_node(node_id, node)
		node.visible = should_show

func _should_show_node(node_id: String, node: GraphNode) -> bool:
	"""Determine if node should be visible based on current filter.
	Args:
		node_id: Node identifier
		node: GraphNode instance
	Returns:
		True if node should be visible"""
	
	# Apply search filter
	if not search_query.is_empty():
		if not node_id.to_lower().contains(search_query.to_lower()) and not node.title.to_lower().contains(search_query.to_lower()):
			return false
	
	# Apply type filter
	match current_filter:
		FilterType.ALL:
			return true
		FilterType.OBJECTS_ONLY:
			return dependency_graph.edges.has(node_id)
		FilterType.ASSETS_ONLY:
			return dependency_graph.nodes.has(node_id)
		FilterType.ERRORS_ONLY:
			return _node_has_errors(node_id)
		FilterType.WARNINGS_ONLY:
			return _node_has_warnings(node_id)
	
	return true

func _node_has_errors(node_id: String) -> bool:
	"""Check if node has validation errors.
	Args:
		node_id: Node identifier
	Returns:
		True if node has errors"""
	
	if validation_results.has(node_id):
		var result = validation_results[node_id]
		if result.has_method("get_error_count"):
			return result.get_error_count() > 0
	
	# Check dependency info for errors
	if dependency_graph.nodes.has(node_id):
		var dependency_info: MissionValidationController.DependencyInfo = dependency_graph.nodes[node_id]
		return not dependency_info.is_valid
	
	return false

func _node_has_warnings(node_id: String) -> bool:
	"""Check if node has validation warnings.
	Args:
		node_id: Node identifier
	Returns:
		True if node has warnings"""
	
	if validation_results.has(node_id):
		var result = validation_results[node_id]
		if result.has_method("get_warning_count"):
			return result.get_warning_count() > 0
	
	return false

func _show_node_limit_warning(total_nodes: int) -> void:
	"""Show warning about too many nodes to display.
	Args:
		total_nodes: Total number of nodes in graph"""
	
	if info_panel and info_label:
		info_panel.visible = true
		info_label.text = "[color=orange]Too many nodes to display (%d). Limit is %d. Use filters to reduce the view.[/color]" % [total_nodes, max_nodes_displayed]

func _get_display_name(path: String) -> String:
	"""Get display name for a path.
	Args:
		path: Full path
	Returns:
		Shortened display name"""
	
	if path.contains("/"):
		return path.get_file()
	return path

## Event handlers

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	"""Handle connection request between nodes.
	Args:
		from_node: Source node name
		from_port: Source port index
		to_node: Target node name
		to_port: Target port index"""
	
	# Connections are read-only in dependency graph
	pass

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	"""Handle disconnection request between nodes.
	Args:
		from_node: Source node name
		from_port: Source port index
		to_node: Target node name
		to_port: Target port index"""
	
	# Connections are read-only in dependency graph
	pass

func _on_node_selected(node: Node) -> void:
	"""Handle node selection.
	Args:
		node: Selected GraphNode"""
	
	if not node is GraphNode:
		return
	
	var graph_node: GraphNode = node as GraphNode
	var node_id: String = _get_node_id_from_graph_node(graph_node)
	
	if not node_id.is_empty():
		var node_data: Dictionary = _get_node_data(node_id)
		node_selected.emit(node_id, node_data)

func _get_node_id_from_graph_node(graph_node: GraphNode) -> String:
	"""Get node ID from GraphNode instance.
	Args:
		graph_node: GraphNode to identify
	Returns:
		Node ID string"""
	
	for node_id in graph_nodes.keys():
		if graph_nodes[node_id] == graph_node:
			return node_id
	
	return ""

func _get_node_data(node_id: String) -> Dictionary:
	"""Get comprehensive data for a node.
	Args:
		node_id: Node identifier
	Returns:
		Dictionary with node information"""
	
	var data: Dictionary = {"id": node_id}
	
	# Add dependency information if available
	if dependency_graph.nodes.has(node_id):
		var dependency_info: MissionValidationController.DependencyInfo = dependency_graph.nodes[node_id]
		data["type"] = "dependency"
		data["dependency_type"] = dependency_info.dependency_type
		data["dependency_path"] = dependency_info.dependency_path
		data["is_valid"] = dependency_info.is_valid
		data["error_message"] = dependency_info.error_message
		data["dependent_objects"] = dependency_info.dependent_objects
	
	# Add object information if available
	if dependency_graph.edges.has(node_id):
		data["type"] = "object"
		data["dependencies"] = dependency_graph.edges[node_id]
	
	# Add validation information if available
	if validation_results.has(node_id):
		var result = validation_results[node_id]
		data["validation_result"] = result
		if result.has_method("is_valid"):
			data["validation_valid"] = result.is_valid()
		if result.has_method("get_error_count"):
			data["error_count"] = result.get_error_count()
		if result.has_method("get_warning_count"):
			data["warning_count"] = result.get_warning_count()
	
	return data

func _on_scroll_changed(offset: Vector2) -> void:
	"""Handle graph scroll change.
	Args:
		offset: New scroll offset"""
	
	# Update any overlays or indicators that need to track scroll
	pass

func _on_zoom_changed(zoom: float) -> void:
	"""Handle graph zoom change.
	Args:
		zoom: New zoom level"""
	
	graph_zoom_changed.emit(zoom)

func _on_filter_changed(index: int) -> void:
	"""Handle filter option change.
	Args:
		index: Selected filter index"""
	
	current_filter = index as FilterType
	_apply_current_filter()

func _on_search_changed(new_text: String) -> void:
	"""Handle search query change.
	Args:
		new_text: New search query"""
	
	search_query = new_text
	_apply_current_filter()

## Public API

func refresh_graph() -> void:
	"""Refresh the entire graph visualization."""
	
	_rebuild_graph_visualization()

func focus_on_node(node_id: String) -> void:
	"""Focus graph view on specific node.
	Args:
		node_id: Node to focus on"""
	
	if graph_nodes.has(node_id):
		var node: GraphNode = graph_nodes[node_id]
		if node:
			# Center graph on node
			var graph_center: Vector2 = graph_edit.size * 0.5
			var target_offset: Vector2 = node.position_offset - graph_center
			graph_edit.scroll_offset = target_offset
			
			# Select node
			node.selected = true

func set_max_nodes(max_nodes: int) -> void:
	"""Set maximum number of nodes to display.
	Args:
		max_nodes: Maximum node count"""
	
	max_nodes_displayed = max_nodes
	if dependency_graph:
		_rebuild_graph_visualization()

func export_graph_image() -> Image:
	"""Export current graph view as image.
	Returns:
		Image of current graph view"""
	
	if not graph_edit:
		return null
	
	var image: Image = graph_edit.get_viewport().get_texture().get_image()
	return image

func get_graph_statistics() -> Dictionary:
	"""Get statistics about current graph.
	Returns:
		Dictionary with graph statistics"""
	
	var stats: Dictionary = {}
	
	if dependency_graph:
		stats["total_nodes"] = dependency_graph.nodes.size()
		stats["total_edges"] = 0
		for edges in dependency_graph.edges.values():
			stats["total_edges"] += edges.size()
	
	stats["displayed_nodes"] = graph_nodes.size()
	stats["current_filter"] = current_filter
	stats["search_active"] = not search_query.is_empty()
	
	return stats