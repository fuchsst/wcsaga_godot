class_name SexpGraph
extends GraphEdit

## Visual SEXP expression graph container.
## Manages the visual representation of SEXP expressions using Godot's GraphEdit.

signal expression_changed(sexp_code: String)
signal validation_status_changed(is_valid: bool, errors: Array[String])
signal node_selection_changed(selected_nodes: Array[SexpOperatorNode])

var expression_nodes: Array[SexpOperatorNode] = []
var connections_data: Array[Dictionary] = []
var next_node_id: int = 0

# Undo/redo support
var undo_redo: EditorUndoRedoManager

func _ready() -> void:
	name = "SexpGraph"
	
	# Configure GraphEdit appearance and behavior
	scroll_ofs = Vector2.ZERO
	zoom = 1.0
	minimap_enabled = true
	show_zoom_label = true
	
	# Connect GraphEdit signals
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	connection_to_empty.connect(_on_connection_to_empty)
	connection_from_empty.connect(_on_connection_from_empty)
	node_selected.connect(_on_node_selected)
	node_deselected.connect(_on_node_deselected)
	delete_nodes_request.connect(_on_delete_nodes_request)
	duplicate_nodes_request.connect(_on_duplicate_nodes_request)
	copy_nodes_request.connect(_on_copy_nodes_request)
	paste_nodes_request.connect(_on_paste_nodes_request)
	
	# Enable context menu
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_show_context_menu(mouse_event.global_position)
			get_viewport().set_input_as_handled()

func add_operator_node(operator_type: String, position: Vector2 = Vector2.ZERO) -> SexpOperatorNode:
	"""Add a new operator node to the graph."""
	var node: SexpOperatorNode = _create_operator_node(operator_type)
	if not node:
		push_error("Failed to create operator node: " + operator_type)
		return null
	
	# Set position and add to graph
	node.position_offset = position
	node.name = "Node_" + str(next_node_id)
	next_node_id += 1
	
	add_child(node)
	expression_nodes.append(node)
	
	# Connect node signals
	node.value_changed.connect(_on_node_value_changed)
	node.connection_changed.connect(_on_node_connection_changed)
	
	# Update expression
	_update_expression()
	
	return node

func remove_operator_node(node: SexpOperatorNode) -> void:
	"""Remove an operator node from the graph."""
	if not node or node not in expression_nodes:
		return
	
	# Remove all connections to/from this node
	_remove_node_connections(node)
	
	# Remove from tracking
	expression_nodes.erase(node)
	
	# Remove from scene
	node.queue_free()
	
	# Update expression
	_update_expression()

func _create_operator_node(operator_type: String) -> SexpOperatorNode:
	"""Create a specific type of operator node."""
	match operator_type:
		"add":
			return _create_arithmetic_node("+", "Add", "Addition operator", 
				[SexpTypeSystem.SexpDataType.NUMBER, SexpTypeSystem.SexpDataType.NUMBER], 
				SexpTypeSystem.SexpDataType.NUMBER)
		"subtract":
			return _create_arithmetic_node("-", "Subtract", "Subtraction operator",
				[SexpTypeSystem.SexpDataType.NUMBER, SexpTypeSystem.SexpDataType.NUMBER],
				SexpTypeSystem.SexpDataType.NUMBER)
		"multiply":
			return _create_arithmetic_node("*", "Multiply", "Multiplication operator",
				[SexpTypeSystem.SexpDataType.NUMBER, SexpTypeSystem.SexpDataType.NUMBER],
				SexpTypeSystem.SexpDataType.NUMBER)
		"divide":
			return _create_arithmetic_node("/", "Divide", "Division operator",
				[SexpTypeSystem.SexpDataType.NUMBER, SexpTypeSystem.SexpDataType.NUMBER],
				SexpTypeSystem.SexpDataType.NUMBER)
		"modulo":
			return _create_arithmetic_node("mod", "Modulo", "Modulo operator",
				[SexpTypeSystem.SexpDataType.NUMBER, SexpTypeSystem.SexpDataType.NUMBER],
				SexpTypeSystem.SexpDataType.NUMBER)
		"and":
			return _create_logic_node("and", "And", "Logical AND operator",
				[SexpTypeSystem.SexpDataType.BOOLEAN, SexpTypeSystem.SexpDataType.BOOLEAN],
				SexpTypeSystem.SexpDataType.BOOLEAN)
		"or":
			return _create_logic_node("or", "Or", "Logical OR operator",
				[SexpTypeSystem.SexpDataType.BOOLEAN, SexpTypeSystem.SexpDataType.BOOLEAN],
				SexpTypeSystem.SexpDataType.BOOLEAN)
		"not":
			return _create_logic_node("not", "Not", "Logical NOT operator",
				[SexpTypeSystem.SexpDataType.BOOLEAN],
				SexpTypeSystem.SexpDataType.BOOLEAN)
		"equals":
			return _create_comparison_node("=", "Equals", "Equality comparison",
				[SexpTypeSystem.SexpDataType.ANY, SexpTypeSystem.SexpDataType.ANY],
				SexpTypeSystem.SexpDataType.BOOLEAN)
		"less_than":
			return _create_comparison_node("<", "Less Than", "Less than comparison",
				[SexpTypeSystem.SexpDataType.NUMBER, SexpTypeSystem.SexpDataType.NUMBER],
				SexpTypeSystem.SexpDataType.BOOLEAN)
		"greater_than":
			return _create_comparison_node(">", "Greater Than", "Greater than comparison",
				[SexpTypeSystem.SexpDataType.NUMBER, SexpTypeSystem.SexpDataType.NUMBER],
				SexpTypeSystem.SexpDataType.BOOLEAN)
		"true":
			return _create_constant_node("true", "True", "Boolean true constant", true, SexpTypeSystem.SexpDataType.BOOLEAN)
		"false":
			return _create_constant_node("false", "False", "Boolean false constant", false, SexpTypeSystem.SexpDataType.BOOLEAN)
		"number":
			return _create_constant_node("number", "Number", "Numeric constant", 0.0, SexpTypeSystem.SexpDataType.NUMBER)
		"string":
			return _create_constant_node("string", "String", "String constant", "", SexpTypeSystem.SexpDataType.STRING)
		_:
			push_error("Unknown operator type: " + operator_type)
			return null

func _create_arithmetic_node(op: String, display_name: String, description: String, input_types: Array[SexpTypeSystem.SexpDataType], output_type: SexpTypeSystem.SexpDataType) -> SexpOperatorNode:
	"""Create an arithmetic operator node."""
	var node: SexpOperatorNode = SexpOperatorNode.new()
	node.operator_name = op
	node.operator_display_name = display_name
	node.operator_description = description
	node.input_types = input_types
	node.output_type = output_type
	return node

func _create_logic_node(op: String, display_name: String, description: String, input_types: Array[SexpTypeSystem.SexpDataType], output_type: SexpTypeSystem.SexpDataType) -> SexpOperatorNode:
	"""Create a logic operator node."""
	var node: SexpOperatorNode = SexpOperatorNode.new()
	node.operator_name = op
	node.operator_display_name = display_name
	node.operator_description = description
	node.input_types = input_types
	node.output_type = output_type
	return node

func _create_comparison_node(op: String, display_name: String, description: String, input_types: Array[SexpTypeSystem.SexpDataType], output_type: SexpTypeSystem.SexpDataType) -> SexpOperatorNode:
	"""Create a comparison operator node."""
	var node: SexpOperatorNode = SexpOperatorNode.new()
	node.operator_name = op
	node.operator_display_name = display_name
	node.operator_description = description
	node.input_types = input_types
	node.output_type = output_type
	return node

func _create_constant_node(op: String, display_name: String, description: String, value: Variant, output_type: SexpTypeSystem.SexpDataType) -> SexpOperatorNode:
	"""Create a constant value node."""
	var node: SexpOperatorNode = SexpOperatorNode.new()
	node.operator_name = op
	node.operator_display_name = display_name
	node.operator_description = description
	node.input_types = []
	node.output_type = output_type
	node.computed_output = value
	return node

func _show_context_menu(position: Vector2) -> void:
	"""Show context menu for adding new nodes."""
	var popup: PopupMenu = PopupMenu.new()
	add_child(popup)
	
	# Arithmetic operators
	popup.add_item("Add (+)", 0)
	popup.add_item("Subtract (-)", 1)
	popup.add_item("Multiply (*)", 2)
	popup.add_item("Divide (/)", 3)
	popup.add_item("Modulo (mod)", 4)
	popup.add_separator()
	
	# Logic operators
	popup.add_item("And", 10)
	popup.add_item("Or", 11)
	popup.add_item("Not", 12)
	popup.add_separator()
	
	# Comparison operators
	popup.add_item("Equals (=)", 20)
	popup.add_item("Less Than (<)", 21)
	popup.add_item("Greater Than (>)", 22)
	popup.add_separator()
	
	# Constants
	popup.add_item("True", 30)
	popup.add_item("False", 31)
	popup.add_item("Number", 32)
	popup.add_item("String", 33)
	
	popup.id_pressed.connect(_on_context_menu_selected.bind(popup, position))
	popup.popup_at_position(position)

func _on_context_menu_selected(popup: PopupMenu, position: Vector2, id: int) -> void:
	"""Handle context menu selection."""
	var operator_type: String = ""
	
	match id:
		0: operator_type = "add"
		1: operator_type = "subtract"
		2: operator_type = "multiply"
		3: operator_type = "divide"
		4: operator_type = "modulo"
		10: operator_type = "and"
		11: operator_type = "or"
		12: operator_type = "not"
		20: operator_type = "equals"
		21: operator_type = "less_than"
		22: operator_type = "greater_than"
		30: operator_type = "true"
		31: operator_type = "false"
		32: operator_type = "number"
		33: operator_type = "string"
	
	if operator_type:
		var graph_position: Vector2 = (position - global_position) / zoom + scroll_ofs
		add_operator_node(operator_type, graph_position)
	
	popup.queue_free()

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	"""Handle connection request between nodes."""
	var from_graph_node: GraphNode = get_node(from_node)
	var to_graph_node: GraphNode = get_node(to_node)
	
	if not from_graph_node is SexpOperatorNode or not to_graph_node is SexpOperatorNode:
		return
	
	var from_sexp_node: SexpOperatorNode = from_graph_node as SexpOperatorNode
	var to_sexp_node: SexpOperatorNode = to_graph_node as SexpOperatorNode
	
	# Validate type compatibility
	var from_type: SexpTypeSystem.SexpDataType = from_sexp_node.output_type
	var to_type: SexpTypeSystem.SexpDataType = to_sexp_node.input_types[to_port] if to_port < to_sexp_node.input_types.size() else SexpTypeSystem.SexpDataType.UNKNOWN
	
	if not SexpTypeSystem.are_types_compatible(from_type, to_type):
		push_warning("Cannot connect %s to %s - incompatible types" % [SexpTypeSystem.get_type_name(from_type), SexpTypeSystem.get_type_name(to_type)])
		return
	
	# Remove any existing connection to the target port
	_disconnect_input_port(to_node, to_port)
	
	# Create the connection
	connect_node(from_node, from_port, to_node, to_port)
	
	# Update the target node's input value
	to_sexp_node.set_input_value(to_port, from_sexp_node.get_output_value())
	
	# Store connection data
	connections_data.append({
		"from_node": from_node,
		"from_port": from_port,
		"to_node": to_node,
		"to_port": to_port
	})
	
	_update_expression()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	"""Handle disconnection request."""
	disconnect_node(from_node, from_port, to_node, to_port)
	
	# Remove from connection data
	connections_data = connections_data.filter(func(conn): 
		return not (conn.from_node == from_node and conn.from_port == from_port and 
					conn.to_node == to_node and conn.to_port == to_port))
	
	# Reset target node input to default
	var to_graph_node: GraphNode = get_node(to_node)
	if to_graph_node is SexpOperatorNode:
		var to_sexp_node: SexpOperatorNode = to_graph_node as SexpOperatorNode
		var default_value: Variant = to_sexp_node._get_default_value(to_sexp_node.input_types[to_port])
		to_sexp_node.set_input_value(to_port, default_value)
	
	_update_expression()

func _disconnect_input_port(node_name: StringName, port: int) -> void:
	"""Disconnect any existing connection to an input port."""
	for conn in connections_data:
		if conn.to_node == node_name and conn.to_port == port:
			disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
			connections_data.erase(conn)
			break

func _remove_node_connections(node: SexpOperatorNode) -> void:
	"""Remove all connections to and from a node."""
	var node_name: StringName = node.name
	var connections_to_remove: Array[Dictionary] = []
	
	for conn in connections_data:
		if conn.from_node == node_name or conn.to_node == node_name:
			disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
			connections_to_remove.append(conn)
	
	for conn in connections_to_remove:
		connections_data.erase(conn)

func _update_expression() -> void:
	"""Update the SEXP expression and emit change signal."""
	var sexp_code: String = generate_sexp_code()
	var validation: Dictionary = validate_expression()
	
	expression_changed.emit(sexp_code)
	validation_status_changed.emit(validation.is_valid, validation.errors)

func generate_sexp_code() -> String:
	"""Generate SEXP code from the current graph."""
	# Find output nodes (nodes with no outgoing connections)
	var output_nodes: Array[SexpOperatorNode] = []
	
	for node in expression_nodes:
		var has_output_connection: bool = false
		for conn in connections_data:
			if conn.from_node == node.name:
				has_output_connection = true
				break
		
		if not has_output_connection and node.output_type != SexpTypeSystem.SexpDataType.UNKNOWN:
			output_nodes.append(node)
	
	if output_nodes.is_empty():
		return ""
	elif output_nodes.size() == 1:
		return _generate_node_sexp(output_nodes[0])
	else:
		# Multiple outputs - wrap in 'and' operator
		var expressions: Array[String] = []
		for node in output_nodes:
			expressions.append(_generate_node_sexp(node))
		return "(and " + " ".join(expressions) + ")"

func _generate_node_sexp(node: SexpOperatorNode) -> String:
	"""Generate SEXP code for a specific node and its inputs."""
	if node.input_types.is_empty():
		# Constant node
		if node.output_type == SexpTypeSystem.SexpDataType.STRING:
			return "\"" + str(node.computed_output) + "\""
		else:
			return str(node.computed_output)
	
	# Operator node
	var args: Array[String] = []
	
	for i in range(node.input_types.size()):
		# Find connected input
		var input_node: SexpOperatorNode = _get_connected_input_node(node, i)
		if input_node:
			args.append(_generate_node_sexp(input_node))
		else:
			# Use literal value
			var value: Variant = node.get_input_value(i)
			if node.input_types[i] == SexpTypeSystem.SexpDataType.STRING:
				args.append("\"" + str(value) + "\"")
			else:
				args.append(str(value))
	
	return "(" + node.operator_name + " " + " ".join(args) + ")"

func _get_connected_input_node(node: SexpOperatorNode, port: int) -> SexpOperatorNode:
	"""Get the node connected to a specific input port."""
	for conn in connections_data:
		if conn.to_node == node.name and conn.to_port == port:
			var from_node: GraphNode = get_node(conn.from_node)
			if from_node is SexpOperatorNode:
				return from_node as SexpOperatorNode
	return null

func validate_expression() -> Dictionary:
	"""Validate the current expression."""
	var result: Dictionary = {
		"is_valid": true,
		"errors": []
	}
	
	# Check each node
	for node in expression_nodes:
		var node_validation: Dictionary = node.validate_inputs()
		if not node_validation.is_valid:
			result.is_valid = false
			result.errors.append_array(node_validation.errors)
	
	return result

func clear_graph() -> void:
	"""Clear all nodes and connections."""
	for node in expression_nodes:
		node.queue_free()
	
	expression_nodes.clear()
	connections_data.clear()
	clear_connections()
	
	_update_expression()

# Signal handlers
func _on_connection_to_empty(_from_node: StringName, _from_port: int, _release_position: Vector2) -> void:
	pass

func _on_connection_from_empty(_to_node: StringName, _to_port: int, _release_position: Vector2) -> void:
	pass

func _on_node_selected(node: Node) -> void:
	if node is SexpOperatorNode:
		var selected_nodes: Array[SexpOperatorNode] = [node as SexpOperatorNode]
		node_selection_changed.emit(selected_nodes)

func _on_node_deselected(_node: Node) -> void:
	node_selection_changed.emit([])

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var node: GraphNode = get_node(node_name)
		if node is SexpOperatorNode:
			remove_operator_node(node as SexpOperatorNode)

func _on_duplicate_nodes_request() -> void:
	# TODO: Implement node duplication
	pass

func _on_copy_nodes_request() -> void:
	# TODO: Implement node copying
	pass

func _on_paste_nodes_request() -> void:
	# TODO: Implement node pasting
	pass

func _on_node_value_changed(_node: SexpOperatorNode, _port_index: int, _new_value: Variant) -> void:
	_update_expression()

func _on_node_connection_changed(_node: SexpOperatorNode) -> void:
	_update_expression()