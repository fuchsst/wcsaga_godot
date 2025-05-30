class_name SexpExpressionTreeVisualizer
extends RefCounted

## SEXP Expression Tree Visualizer for SEXP-010
##
## Provides visual representation of SEXP expression trees for debugging
## complex nested expressions. Supports interactive tree display with
## highlighting, collapsing, and detailed node information.

signal tree_node_selected(node_data: Dictionary)
signal tree_visualization_updated(tree_data: Dictionary)
signal tree_export_completed(format: String, data: String)

const SexpExpression = preload("res://addons/sexp/core/sexp_expression.gd")
const SexpResult = preload("res://addons/sexp/core/sexp_result.gd")

enum VisualizationMode {
	TREE,           # Traditional tree view
	HORIZONTAL,     # Horizontal flow diagram
	COMPACT,        # Compact nested view
	GRAPH          # Graph-based representation
}

enum NodeType {
	ROOT,
	FUNCTION,
	OPERATOR,
	LITERAL,
	VARIABLE,
	RESULT,
	ERROR
}

enum ExportFormat {
	JSON,
	DOT_GRAPH,
	SVG,
	TEXT_TREE,
	MARKDOWN
}

# Visualization configuration
var visualization_mode: VisualizationMode = VisualizationMode.TREE
var show_types: bool = true
var show_values: bool = true
var show_positions: bool = false
var show_evaluation_order: bool = false
var max_depth_display: int = 10
var compact_literals: bool = true

# Tree structure and data
var _current_tree: SexpTreeNode = null
var _node_id_counter: int = 0
var _evaluation_results: Dictionary = {}
var _highlight_nodes: Array[String] = []
var _collapsed_nodes: Array[String] = []

# Visual styling
var _node_styles: Dictionary = {}
var _color_scheme: Dictionary = {}

func _init() -> void:
	_initialize_styles()
	_initialize_color_scheme()
	print("SexpExpressionTreeVisualizer: Initialized with tree visualization")

func _initialize_styles() -> void:
	"""Initialize node visual styles"""
	_node_styles = {
		NodeType.ROOT: {
			"shape": "ellipse",
			"color": "#4CAF50",
			"border_width": 2,
			"font_size": 14,
			"font_weight": "bold"
		},
		NodeType.FUNCTION: {
			"shape": "rectangle",
			"color": "#2196F3",
			"border_width": 1,
			"font_size": 12,
			"font_weight": "normal"
		},
		NodeType.OPERATOR: {
			"shape": "diamond",
			"color": "#FF9800",
			"border_width": 1,
			"font_size": 12,
			"font_weight": "bold"
		},
		NodeType.LITERAL: {
			"shape": "oval",
			"color": "#9C27B0",
			"border_width": 1,
			"font_size": 10,
			"font_weight": "normal"
		},
		NodeType.VARIABLE: {
			"shape": "hexagon",
			"color": "#00BCD4",
			"border_width": 1,
			"font_size": 10,
			"font_weight": "italic"
		},
		NodeType.RESULT: {
			"shape": "octagon",
			"color": "#4CAF50",
			"border_width": 2,
			"font_size": 10,
			"font_weight": "normal"
		},
		NodeType.ERROR: {
			"shape": "rectangle",
			"color": "#F44336",
			"border_width": 2,
			"font_size": 10,
			"font_weight": "bold"
		}
	}

func _initialize_color_scheme() -> void:
	"""Initialize color scheme for different elements"""
	_color_scheme = {
		"background": "#FFFFFF",
		"grid": "#E0E0E0",
		"text": "#212121",
		"highlight": "#FFEB3B",
		"selection": "#3F51B5",
		"error": "#F44336",
		"warning": "#FF9800",
		"success": "#4CAF50"
	}

## Main visualization methods

func visualize_expression(expression: SexpExpression, evaluation_results: Dictionary = {}) -> Dictionary:
	"""Create visual representation of SEXP expression"""
	if not expression:
		return {}
	
	_evaluation_results = evaluation_results
	_node_id_counter = 0
	_highlight_nodes.clear()
	
	# Build tree structure
	_current_tree = _build_tree_node(expression, null, 0)
	
	# Generate visualization data
	var tree_data = _generate_tree_data()
	
	tree_visualization_updated.emit(tree_data)
	return tree_data

func visualize_expression_with_debugging(expression: SexpExpression, debug_info: Dictionary) -> Dictionary:
	"""Visualize expression with debugging information"""
	var tree_data = visualize_expression(expression, debug_info.get("evaluation_results", {}))
	
	# Add debugging information
	if debug_info.has("breakpoints"):
		_add_breakpoint_markers(tree_data, debug_info["breakpoints"])
	
	if debug_info.has("execution_path"):
		_add_execution_path(tree_data, debug_info["execution_path"])
	
	if debug_info.has("variable_watches"):
		_add_variable_highlights(tree_data, debug_info["variable_watches"])
	
	return tree_data

func update_visualization_mode(mode: VisualizationMode) -> Dictionary:
	"""Update visualization mode and regenerate display"""
	visualization_mode = mode
	
	if _current_tree:
		return _generate_tree_data()
	
	return {}

## Tree building methods

func _build_tree_node(expression: SexpExpression, parent: SexpTreeNode, depth: int) -> SexpTreeNode:
	"""Build tree node from expression"""
	var node = SexpTreeNode.new()
	node.id = "node_%d" % _node_id_counter
	_node_id_counter += 1
	node.parent = parent
	node.depth = depth
	node.expression = expression
	
	# Determine node type and content
	_analyze_node_type(node, expression)
	_set_node_content(node, expression)
	
	# Add evaluation result if available
	if expression and _evaluation_results.has(expression.to_sexp_string()):
		node.result = _evaluation_results[expression.to_sexp_string()]
		node.has_result = true
	
	# Build child nodes
	if expression and expression.arguments:
		for i in range(expression.arguments.size()):
			var child_expr = expression.arguments[i]
			var child_node = _build_tree_node(child_expr, node, depth + 1)
			child_node.argument_index = i
			node.children.append(child_node)
	
	return node

func _analyze_node_type(node: SexpTreeNode, expression: SexpExpression) -> void:
	"""Analyze and set node type"""
	if not expression:
		node.type = NodeType.ERROR
		return
	
	match expression.expression_type:
		SexpExpression.ExpressionType.LITERAL_NUMBER, \
		SexpExpression.ExpressionType.LITERAL_STRING, \
		SexpExpression.ExpressionType.LITERAL_BOOLEAN:
			node.type = NodeType.LITERAL
		
		SexpExpression.ExpressionType.VARIABLE_REFERENCE:
			node.type = NodeType.VARIABLE
		
		SexpExpression.ExpressionType.FUNCTION_CALL:
			if _is_operator(expression.function_name):
				node.type = NodeType.OPERATOR
			else:
				node.type = NodeType.FUNCTION
		
		SexpExpression.ExpressionType.OPERATOR_CALL:
			node.type = NodeType.OPERATOR
		
		_:
			node.type = NodeType.FUNCTION

func _set_node_content(node: SexpTreeNode, expression: SexpExpression) -> void:
	"""Set node display content"""
	if not expression:
		node.label = "ERROR"
		node.description = "Invalid expression"
		return
	
	match expression.expression_type:
		SexpExpression.ExpressionType.LITERAL_NUMBER:
			node.label = str(expression.literal_value)
			node.description = "Number: %s" % expression.literal_value
			node.value_type = "number"
		
		SexpExpression.ExpressionType.LITERAL_STRING:
			node.label = "\"%s\"" % expression.literal_value
			node.description = "String: %s" % expression.literal_value
			node.value_type = "string"
		
		SexpExpression.ExpressionType.LITERAL_BOOLEAN:
			node.label = str(expression.literal_value).to_lower()
			node.description = "Boolean: %s" % expression.literal_value
			node.value_type = "boolean"
		
		SexpExpression.ExpressionType.VARIABLE_REFERENCE:
			node.label = expression.variable_name
			node.description = "Variable: %s" % expression.variable_name
			node.value_type = "variable"
		
		SexpExpression.ExpressionType.FUNCTION_CALL, \
		SexpExpression.ExpressionType.OPERATOR_CALL:
			node.label = expression.function_name
			node.description = "Function: %s (%d args)" % [expression.function_name, expression.arguments.size()]
			node.value_type = "function"
		
		_:
			node.label = "UNKNOWN"
			node.description = "Unknown expression type"
			node.value_type = "unknown"
	
	# Add additional information
	if show_types:
		node.type_info = SexpExpression.ExpressionType.keys()[expression.expression_type]
	
	if node.has_result and show_values:
		if node.result:
			node.result_info = node.result.to_string()

func _is_operator(function_name: String) -> bool:
	"""Check if function name is an operator"""
	var operators = ["+", "-", "*", "/", "mod", "=", "<", ">", "<=", ">=", "!=", "and", "or", "not"]
	return function_name in operators

## Tree data generation

func _generate_tree_data() -> Dictionary:
	"""Generate tree data for visualization"""
	if not _current_tree:
		return {}
	
	var tree_data = {
		"mode": VisualizationMode.keys()[visualization_mode],
		"nodes": [],
		"edges": [],
		"layout": {},
		"metadata": _get_tree_metadata()
	}
	
	# Generate nodes and edges based on visualization mode
	match visualization_mode:
		VisualizationMode.TREE:
			_generate_tree_layout(tree_data)
		VisualizationMode.HORIZONTAL:
			_generate_horizontal_layout(tree_data)
		VisualizationMode.COMPACT:
			_generate_compact_layout(tree_data)
		VisualizationMode.GRAPH:
			_generate_graph_layout(tree_data)
	
	return tree_data

func _generate_tree_layout(tree_data: Dictionary) -> void:
	"""Generate traditional tree layout"""
	var nodes: Array = []
	var edges: Array = []
	
	_traverse_tree_for_layout(_current_tree, nodes, edges, 0, 0)
	
	tree_data["nodes"] = nodes
	tree_data["edges"] = edges
	tree_data["layout"] = {
		"type": "tree",
		"direction": "top_down",
		"node_spacing": 80,
		"level_spacing": 100
	}

func _generate_horizontal_layout(tree_data: Dictionary) -> void:
	"""Generate horizontal flow layout"""
	var nodes: Array = []
	var edges: Array = []
	
	_traverse_tree_for_horizontal(_current_tree, nodes, edges, 0, 0)
	
	tree_data["nodes"] = nodes
	tree_data["edges"] = edges
	tree_data["layout"] = {
		"type": "horizontal",
		"direction": "left_right",
		"node_spacing": 120,
		"level_spacing": 60
	}

func _generate_compact_layout(tree_data: Dictionary) -> void:
	"""Generate compact nested layout"""
	var nodes: Array = []
	var edges: Array = []
	
	_traverse_tree_for_compact(_current_tree, nodes, edges)
	
	tree_data["nodes"] = nodes
	tree_data["edges"] = edges
	tree_data["layout"] = {
		"type": "compact",
		"direction": "nested",
		"min_spacing": 40,
		"indent_size": 20
	}

func _generate_graph_layout(tree_data: Dictionary) -> void:
	"""Generate graph-based layout"""
	var nodes: Array = []
	var edges: Array = []
	
	_traverse_tree_for_graph(_current_tree, nodes, edges)
	
	tree_data["nodes"] = nodes
	tree_data["edges"] = edges
	tree_data["layout"] = {
		"type": "force_directed",
		"iterations": 100,
		"attraction": 0.8,
		"repulsion": 1.2
	}

## Layout generation methods

func _traverse_tree_for_layout(node: SexpTreeNode, nodes: Array, edges: Array, x: float, y: float) -> void:
	"""Traverse tree for standard tree layout"""
	if not node or node.depth > max_depth_display:
		return
	
	# Add current node
	var node_data = _create_node_data(node, x, y)
	nodes.append(node_data)
	
	# Calculate child positions
	var child_count = node.children.size()
	if child_count > 0:
		var child_spacing = 80
		var start_x = x - (child_count - 1) * child_spacing / 2.0
		
		for i in range(child_count):
			var child = node.children[i]
			var child_x = start_x + i * child_spacing
			var child_y = y + 100
			
			# Add edge
			edges.append(_create_edge_data(node.id, child.id))
			
			# Recursively add child
			_traverse_tree_for_layout(child, nodes, edges, child_x, child_y)

func _traverse_tree_for_horizontal(node: SexpTreeNode, nodes: Array, edges: Array, x: float, y: float) -> void:
	"""Traverse tree for horizontal layout"""
	if not node or node.depth > max_depth_display:
		return
	
	var node_data = _create_node_data(node, x, y)
	nodes.append(node_data)
	
	var child_count = node.children.size()
	if child_count > 0:
		var child_spacing = 60
		var start_y = y - (child_count - 1) * child_spacing / 2.0
		
		for i in range(child_count):
			var child = node.children[i]
			var child_x = x + 120
			var child_y = start_y + i * child_spacing
			
			edges.append(_create_edge_data(node.id, child.id))
			_traverse_tree_for_horizontal(child, nodes, edges, child_x, child_y)

func _traverse_tree_for_compact(node: SexpTreeNode, nodes: Array, edges: Array) -> void:
	"""Traverse tree for compact layout"""
	if not node:
		return
	
	var node_data = _create_node_data(node, node.depth * 20, 0)
	node_data["compact_level"] = node.depth
	node_data["has_children"] = not node.children.is_empty()
	
	# Check if node should be collapsed
	if node.id in _collapsed_nodes:
		node_data["collapsed"] = true
		return
	
	nodes.append(node_data)
	
	for child in node.children:
		edges.append(_create_edge_data(node.id, child.id))
		_traverse_tree_for_compact(child, nodes, edges)

func _traverse_tree_for_graph(node: SexpTreeNode, nodes: Array, edges: Array) -> void:
	"""Traverse tree for graph layout"""
	if not node:
		return
	
	var node_data = _create_node_data(node, 0, 0)  # Position calculated by layout algorithm
	node_data["weight"] = _calculate_node_weight(node)
	nodes.append(node_data)
	
	for child in node.children:
		var edge_data = _create_edge_data(node.id, child.id)
		edge_data["weight"] = 1.0
		edges.append(edge_data)
		_traverse_tree_for_graph(child, nodes, edges)

## Node and edge data creation

func _create_node_data(node: SexpTreeNode, x: float, y: float) -> Dictionary:
	"""Create node data for visualization"""
	var style = _node_styles.get(node.type, _node_styles[NodeType.FUNCTION])
	
	var node_data = {
		"id": node.id,
		"label": node.label,
		"description": node.description,
		"type": NodeType.keys()[node.type],
		"position": {"x": x, "y": y},
		"style": style.duplicate(),
		"metadata": {
			"depth": node.depth,
			"value_type": node.value_type,
			"has_result": node.has_result,
			"child_count": node.children.size()
		}
	}
	
	# Add type information if enabled
	if show_types and node.type_info:
		node_data["type_info"] = node.type_info
	
	# Add result information if enabled
	if show_values and node.has_result and node.result_info:
		node_data["result_info"] = node.result_info
		node_data["label"] += " → %s" % node.result_info
	
	# Add evaluation order if enabled
	if show_evaluation_order:
		node_data["evaluation_order"] = node.evaluation_order
	
	# Apply highlighting
	if node.id in _highlight_nodes:
		node_data["style"]["color"] = _color_scheme["highlight"]
		node_data["highlighted"] = true
	
	# Apply collapsing
	if node.id in _collapsed_nodes:
		node_data["collapsed"] = true
		node_data["label"] = node.label + " [+%d]" % node.children.size()
	
	return node_data

func _create_edge_data(from_id: String, to_id: String) -> Dictionary:
	"""Create edge data for visualization"""
	return {
		"id": "%s_%s" % [from_id, to_id],
		"from": from_id,
		"to": to_id,
		"style": {
			"color": "#757575",
			"width": 1,
			"arrow": true
		}
	}

func _calculate_node_weight(node: SexpTreeNode) -> float:
	"""Calculate node weight for graph layout"""
	var weight = 1.0
	
	# Function nodes are heavier
	if node.type == NodeType.FUNCTION or node.type == NodeType.OPERATOR:
		weight += 0.5
	
	# Nodes with more children are heavier
	weight += node.children.size() * 0.1
	
	# Root node is heaviest
	if node.parent == null:
		weight += 1.0
	
	return weight

func _get_tree_metadata() -> Dictionary:
	"""Get tree metadata information"""
	if not _current_tree:
		return {}
	
	var metadata = {
		"total_nodes": _count_total_nodes(_current_tree),
		"max_depth": _calculate_max_depth(_current_tree),
		"function_count": _count_nodes_by_type(_current_tree, NodeType.FUNCTION),
		"operator_count": _count_nodes_by_type(_current_tree, NodeType.OPERATOR),
		"literal_count": _count_nodes_by_type(_current_tree, NodeType.LITERAL),
		"variable_count": _count_nodes_by_type(_current_tree, NodeType.VARIABLE),
		"has_evaluation_results": not _evaluation_results.is_empty(),
		"visualization_mode": VisualizationMode.keys()[visualization_mode]
	}
	
	return metadata

## Tree manipulation methods

func highlight_nodes(node_ids: Array[String]) -> void:
	"""Highlight specific nodes"""
	_highlight_nodes = node_ids.duplicate()
	
	if _current_tree:
		var tree_data = _generate_tree_data()
		tree_visualization_updated.emit(tree_data)

func collapse_node(node_id: String) -> void:
	"""Collapse a node and its children"""
	if node_id not in _collapsed_nodes:
		_collapsed_nodes.append(node_id)
	
	if _current_tree:
		var tree_data = _generate_tree_data()
		tree_visualization_updated.emit(tree_data)

func expand_node(node_id: String) -> void:
	"""Expand a collapsed node"""
	if node_id in _collapsed_nodes:
		_collapsed_nodes.erase(node_id)
	
	if _current_tree:
		var tree_data = _generate_tree_data()
		tree_visualization_updated.emit(tree_data)

func select_node(node_id: String) -> Dictionary:
	"""Select a node and return its detailed information"""
	var node = _find_node_by_id(_current_tree, node_id)
	if not node:
		return {}
	
	var node_data = {
		"id": node.id,
		"label": node.label,
		"description": node.description,
		"type": NodeType.keys()[node.type],
		"depth": node.depth,
		"parent_id": node.parent.id if node.parent else "",
		"child_ids": node.children.map(func(child): return child.id),
		"expression": node.expression.to_sexp_string() if node.expression else "",
		"has_result": node.has_result,
		"result": node.result.to_string() if node.result else "",
		"metadata": {
			"value_type": node.value_type,
			"type_info": node.type_info,
			"argument_index": node.argument_index
		}
	}
	
	tree_node_selected.emit(node_data)
	return node_data

## Debug information integration

func _add_breakpoint_markers(tree_data: Dictionary, breakpoints: Array) -> void:
	"""Add breakpoint markers to tree visualization"""
	for node_data in tree_data["nodes"]:
		for breakpoint in breakpoints:
			if _node_matches_breakpoint(node_data, breakpoint):
				node_data["style"]["border_color"] = "#F44336"
				node_data["style"]["border_width"] = 3
				node_data["has_breakpoint"] = true

func _add_execution_path(tree_data: Dictionary, execution_path: Array) -> void:
	"""Add execution path highlighting"""
	for i in range(execution_path.size()):
		var step = execution_path[i]
		for node_data in tree_data["nodes"]:
			if node_data["id"] == step:
				node_data["execution_step"] = i
				node_data["style"]["color"] = _color_scheme["success"]

func _add_variable_highlights(tree_data: Dictionary, watched_variables: Array) -> void:
	"""Add highlighting for watched variables"""
	for node_data in tree_data["nodes"]:
		if node_data["type"] == "VARIABLE":
			for var_name in watched_variables:
				if node_data["label"] == var_name:
					node_data["style"]["border_color"] = _color_scheme["warning"]
					node_data["is_watched"] = true

func _node_matches_breakpoint(node_data: Dictionary, breakpoint) -> bool:
	"""Check if node matches breakpoint criteria"""
	# This would integrate with the breakpoint system
	# For now, simple pattern matching
	return false

## Export functionality

func export_tree(format: ExportFormat) -> String:
	"""Export tree visualization in specified format"""
	if not _current_tree:
		return ""
	
	var exported_data = ""
	
	match format:
		ExportFormat.JSON:
			exported_data = _export_as_json()
		ExportFormat.DOT_GRAPH:
			exported_data = _export_as_dot_graph()
		ExportFormat.SVG:
			exported_data = _export_as_svg()
		ExportFormat.TEXT_TREE:
			exported_data = _export_as_text_tree()
		ExportFormat.MARKDOWN:
			exported_data = _export_as_markdown()
	
	tree_export_completed.emit(ExportFormat.keys()[format], exported_data)
	return exported_data

func _export_as_json() -> String:
	"""Export as JSON format"""
	var tree_data = _generate_tree_data()
	return JSON.stringify(tree_data, "\t")

func _export_as_dot_graph() -> String:
	"""Export as DOT graph format"""
	var dot = "digraph SexpTree {\n"
	dot += "  rankdir=TB;\n"
	dot += "  node [shape=rectangle];\n"
	
	_export_dot_recursive(_current_tree, dot)
	
	dot += "}\n"
	return dot

func _export_dot_recursive(node: SexpTreeNode, dot: String) -> void:
	"""Recursively export nodes to DOT format"""
	if not node:
		return
	
	var style = _node_styles[node.type]
	dot += "  \"%s\" [label=\"%s\", color=\"%s\"];\n" % [node.id, node.label, style["color"]]
	
	for child in node.children:
		dot += "  \"%s\" -> \"%s\";\n" % [node.id, child.id]
		_export_dot_recursive(child, dot)

func _export_as_svg() -> String:
	"""Export as SVG format (simplified)"""
	return "<svg><!-- SVG export not fully implemented --></svg>"

func _export_as_text_tree() -> String:
	"""Export as text tree format"""
	var text = ""
	_export_text_recursive(_current_tree, text, "", true)
	return text

func _export_text_recursive(node: SexpTreeNode, text: String, prefix: String, is_last: bool) -> void:
	"""Recursively export nodes to text format"""
	if not node:
		return
	
	var connector = "└── " if is_last else "├── "
	text += prefix + connector + node.label
	
	if node.has_result and node.result_info:
		text += " → " + node.result_info
	
	text += "\n"
	
	var new_prefix = prefix + ("    " if is_last else "│   ")
	for i in range(node.children.size()):
		var child = node.children[i]
		var child_is_last = i == node.children.size() - 1
		_export_text_recursive(child, text, new_prefix, child_is_last)

func _export_as_markdown() -> String:
	"""Export as Markdown format"""
	var md = "# SEXP Expression Tree\n\n"
	md += "Generated on: %s\n\n" % Time.get_datetime_string_from_system()
	
	if _current_tree:
		md += "## Tree Structure\n\n"
		md += "```\n"
		md += _export_as_text_tree()
		md += "```\n\n"
		
		md += "## Metadata\n\n"
		var metadata = _get_tree_metadata()
		for key in metadata:
			md += "- **%s**: %s\n" % [key.capitalize().replace("_", " "), metadata[key]]
	
	return md

## Utility methods

func _count_total_nodes(node: SexpTreeNode) -> int:
	"""Count total nodes in tree"""
	if not node:
		return 0
	
	var count = 1
	for child in node.children:
		count += _count_total_nodes(child)
	
	return count

func _calculate_max_depth(node: SexpTreeNode) -> int:
	"""Calculate maximum depth of tree"""
	if not node:
		return 0
	
	var max_depth = node.depth
	for child in node.children:
		max_depth = max(max_depth, _calculate_max_depth(child))
	
	return max_depth

func _count_nodes_by_type(node: SexpTreeNode, node_type: NodeType) -> int:
	"""Count nodes of specific type"""
	if not node:
		return 0
	
	var count = 1 if node.type == node_type else 0
	for child in node.children:
		count += _count_nodes_by_type(child, node_type)
	
	return count

func _find_node_by_id(node: SexpTreeNode, node_id: String) -> SexpTreeNode:
	"""Find node by ID"""
	if not node:
		return null
	
	if node.id == node_id:
		return node
	
	for child in node.children:
		var found = _find_node_by_id(child, node_id)
		if found:
			return found
	
	return null

## Configuration methods

func configure_display(show_types_enabled: bool = true, show_values_enabled: bool = true, 
					  show_positions_enabled: bool = false, compact_literals_enabled: bool = true) -> void:
	"""Configure display options"""
	show_types = show_types_enabled
	show_values = show_values_enabled
	show_positions = show_positions_enabled
	compact_literals = compact_literals_enabled

func set_color_scheme(scheme: Dictionary) -> void:
	"""Set custom color scheme"""
	for key in scheme:
		if key in _color_scheme:
			_color_scheme[key] = scheme[key]

func set_max_depth(depth: int) -> void:
	"""Set maximum display depth"""
	max_depth_display = max(1, depth)

## Tree node data class

class SexpTreeNode:
	extends RefCounted
	
	var id: String = ""
	var label: String = ""
	var description: String = ""
	var type: NodeType = NodeType.FUNCTION
	var value_type: String = ""
	var type_info: String = ""
	
	var parent: SexpTreeNode = null
	var children: Array[SexpTreeNode] = []
	var depth: int = 0
	var argument_index: int = -1
	
	var expression: SexpExpression = null
	var result: SexpResult = null
	var has_result: bool = false
	var result_info: String = ""
	
	var evaluation_order: int = -1
	var is_highlighted: bool = false
	var is_collapsed: bool = false
	
	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"label": label,
			"description": description,
			"type": NodeType.keys()[type],
			"value_type": value_type,
			"depth": depth,
			"child_count": children.size(),
			"has_result": has_result,
			"result_info": result_info
		}