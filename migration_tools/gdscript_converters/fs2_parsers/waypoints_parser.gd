# migration_tools/gdscript_converters/fs2_parsers/waypoints_parser.gd
extends BaseFS2Parser
class_name WaypointsParser

# --- Dependencies ---
const JumpNodeData = preload("res://scripts/resources/mission/jump_node_data.gd")
const WaypointListData = preload("res://scripts/resources/mission/waypoint_list_data.gd")

# --- Parser State ---
# Inherited: _lines, _current_line_num

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing lists of parsed jump nodes and waypoint lists ('jump_nodes', 'waypoint_lists')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var jump_nodes_array: Array[JumpNodeData] = []
	var waypoint_lists_array: Array[WaypointListData] = []

	print("Parsing #Waypoints section...")

	# Loop through jump nodes and waypoint lists
	while _peek_line() != null:
		var line = _peek_line()
		if line.begins_with("$Jump Node:"):
			var jump_node_data: JumpNodeData = _parse_single_jump_node()
			if jump_node_data:
				jump_nodes_array.append(jump_node_data)
		elif line.begins_with("$Name:"): # Start of a waypoint list
			var waypoint_list_data: WaypointListData = _parse_single_waypoint_list()
			if waypoint_list_data:
				waypoint_lists_array.append(waypoint_list_data)
		elif line.begins_with("#"): # Start of the next section
			break
		else:
			# Unexpected line, consume and warn
			printerr(f"Warning: Unexpected line in #Waypoints section: '{line}' at line {_current_line_num + 1}")
			_read_line()

	print(f"Finished parsing #Waypoints section. Found {jump_nodes_array.size()} jump nodes and {waypoint_lists_array.size()} waypoint lists.")
	return { "jump_nodes": jump_nodes_array, "waypoint_lists": waypoint_lists_array, "next_line": _current_line_num }


# --- Jump Node Parsing Helper ---
func _parse_single_jump_node() -> JumpNodeData:
	"""Parses one $Jump Node: block."""
	var jump_node_data = JumpNodeData.new()

	var pos_str = _parse_required_token("$Jump Node:")
	if pos_str == null: return null
	jump_node_data.position = _parse_vector(pos_str)

	# Optional fields for Jump Node
	var name_str = _parse_optional_token("$Jump Node Name:") or _parse_optional_token("+Jump Node Name:")
	if name_str != null: jump_node_data.node_name = name_str

	var model_str = _parse_optional_token("+Model File:")
	if model_str != null and model_str.to_lower() != "none":
		# Assuming model is GLB
		jump_node_data.model_filename = "res://assets/models/" + model_str.get_basename() + ".glb"
	else:
		jump_node_data.model_filename = ""


	var color_str = _parse_optional_token("+Alphacolor:")
	if color_str != null:
		var parts = color_str.split(" ", false)
		if parts.size() == 4:
			# Convert 0-255 to 0.0-1.0 for Godot Color
			var r = float(parts[0].to_int()) / 255.0
			var g = float(parts[1].to_int()) / 255.0
			var b = float(parts[2].to_int()) / 255.0
			var a = float(parts[3].to_int()) / 255.0
			jump_node_data.color = Color(r, g, b, a)
		else:
			printerr(f"Error parsing Alphacolor: '{color_str}'")

	var hidden_str = _parse_optional_token("+Hidden:")
	if hidden_str != null: jump_node_data.hidden = hidden_str.to_int() > 0

	return jump_node_data

# --- Waypoint List Parsing Helper ---
func _parse_single_waypoint_list() -> WaypointListData:
	"""Parses one $Name: block for a waypoint list."""
	var waypoint_list_data = WaypointListData.new()

	var name_str = _parse_required_token("$Name:")
	if name_str == null: return null
	waypoint_list_data.name = name_str

	var list_content = _parse_required_token("$List:")
	if list_content == null: return null

	# Parse the list of vectors, format is likely '(x,y,z),(x,y,z),...'
	var points_str = list_content.strip_edges().split("),(", false) # Split carefully
	var waypoints_array : Array[Vector3] = [] # Use Array[Vector3] directly
	for point_str in points_str:
		var clean_point_str = point_str.trim_prefix("(").trim_suffix(")")
		var coords = clean_point_str.split(",", false)
		if coords.size() == 3:
			waypoints_array.append(Vector3(coords[0].to_float(), coords[1].to_float(), coords[2].to_float()))
		else:
			printerr(f"Error parsing waypoint vector: '{point_str}' in list '{waypoint_list_data.name}'")
	waypoint_list_data.waypoints = waypoints_array

	return waypoint_list_data
