# migration_tools/gdscript_converters/fs2_parsers/waypoints_parser.gd
extends RefCounted # Or BaseFS2Parser
class_name WaypointsParser

# --- Dependencies ---
# TODO: Preload JumpNodeData and WaypointListData if they are defined resource scripts
# const JumpNodeData = preload("res://scripts/resources/mission/jump_node_data.gd")
# const WaypointListData = preload("res://scripts/resources/mission/waypoint_list_data.gd")

# --- Parser State ---
var _lines: PackedStringArray
var _current_line_num: int = 0 # Local counter

# --- Main Parse Function ---
# Takes the full list of lines and the starting index for this section.
# Returns a dictionary containing lists of parsed jump nodes and waypoint lists ('jump_nodes', 'waypoint_lists')
# and the index of the line *after* the last one consumed.
func parse(lines_array: PackedStringArray, start_line_index: int) -> Dictionary:
	_lines = lines_array
	_current_line_num = start_line_index
	var jump_nodes_array: Array = [] # Array[JumpNodeData] or Dictionary
	var waypoint_lists_array: Array = [] # Array[WaypointListData] or Dictionary

	print("Parsing #Waypoints section...")

	# Loop through jump nodes and waypoint lists
	while _peek_line() != null:
		var line = _peek_line()
		if line.begins_with("$Jump Node:"):
			var jump_node_data = _parse_single_jump_node()
			if jump_node_data:
				jump_nodes_array.append(jump_node_data)
		elif line.begins_with("$Name:"): # Start of a waypoint list
			var waypoint_list_data = _parse_single_waypoint_list()
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
func _parse_single_jump_node() -> Dictionary:
	"""Parses one $Jump Node: block."""
	var jump_node_data: Dictionary = {} # Use Dictionary for now

	var pos_str = _parse_required_token("$Jump Node:")
	jump_node_data["position"] = _parse_vector(pos_str)

	# Optional fields for Jump Node
	var name_str = _parse_optional_token("$Jump Node Name:") or _parse_optional_token("+Jump Node Name:")
	if name_str != null: jump_node_data["node_name"] = name_str

	var model_str = _parse_optional_token("+Model File:")
	if model_str != null: jump_node_data["model_filename"] = model_str

	var color_str = _parse_optional_token("+Alphacolor:")
	if color_str != null:
		var parts = color_str.split(" ", false)
		if parts.size() == 4:
			# Assuming order is R G B A (0-255)
			jump_node_data["color"] = Color8(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
		else:
			printerr(f"Error parsing Alphacolor: '{color_str}'")

	var hidden_str = _parse_optional_token("+Hidden:")
	if hidden_str != null: jump_node_data["hidden"] = hidden_str.to_int() > 0

	return jump_node_data

# --- Waypoint List Parsing Helper ---
func _parse_single_waypoint_list() -> Dictionary:
	"""Parses one $Name: block for a waypoint list."""
	var waypoint_list_data: Dictionary = {} # Use Dictionary for now

	waypoint_list_data["list_name"] = _parse_required_token("$Name:")

	var list_content = _parse_required_token("$List:")
	# Parse the list of vectors, format is likely '(x,y,z),(x,y,z),...'
	var points_str = list_content.strip_edges().split("),(", false) # Split carefully
	var waypoints_array : PackedVector3Array = []
	for point_str in points_str:
		var clean_point_str = point_str.trim_prefix("(").trim_suffix(")")
		var coords = clean_point_str.split(",", false)
		if coords.size() == 3:
			waypoints_array.append(Vector3(coords[0].to_float(), coords[1].to_float(), coords[2].to_float()))
		else:
			printerr(f"Error parsing waypoint vector: '{point_str}' in list '{waypoint_list_data.get('list_name', 'Unknown')}'")
	waypoint_list_data["waypoints"] = waypoints_array

	return waypoint_list_data


# --- Helper Functions (Duplicated for now, move to Base later) ---

func _peek_line() -> String:
	if _current_line_num < _lines.size():
		return _lines[_current_line_num].strip_edges()
	return null

func _read_line() -> String:
	var line = _peek_line()
	if line != null:
		_current_line_num += 1
	return line

func _skip_whitespace_and_comments():
	while true:
		var line = _peek_line()
		if line == null: break
		if line and not line.begins_with(';'): break
		_current_line_num += 1

func _parse_required_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _read_line()
	if line == null or not line.begins_with(expected_token):
		printerr(f"Error: Expected '{expected_token}' but found '{line}' at line {_current_line_num}")
		return ""
	return line.substr(expected_token.length()).strip_edges()

func _parse_optional_token(expected_token: String) -> String:
	_skip_whitespace_and_comments()
	var line = _peek_line()
	if line != null and line.begins_with(expected_token):
		_read_line()
		return line.substr(expected_token.length()).strip_edges()
	return null

func _parse_vector(line_content: String) -> Vector3:
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 3:
		return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	else:
		printerr(f"Error parsing Vector3: '{line_content}'")
		return Vector3.ZERO
