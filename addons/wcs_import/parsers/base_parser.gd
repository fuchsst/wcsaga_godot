class_name WCSBaseParser
extends RefCounted

## Base class for Wing Commander Saga file parsers.
## Provides common utility functions for parsing text-based formats.

var _content: String = ""
var _lines: PackedStringArray = []
var _current_line_index: int = 0

func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + path)
		return false
		
	_content = file.get_as_text()
	# Split by newline and filter empty lines if needed, 
	# but keeping indices aligned might be better.
	# For now, just split.
	_lines = _content.split("\n")
	_current_line_index = 0
	return true

func parse(path: String) -> Variant:
	if not load_file(path):
		return null
	return _parse_content()

func _parse_content() -> Variant:
	push_error("_parse_content must be implemented by subclass")
	return null

# --- Helper Functions ---

func _get_next_line() -> String:
	if _current_line_index >= _lines.size():
		return ""
	var line = _lines[_current_line_index].strip_edges()
	_current_line_index += 1
	return line

func _peek_next_line() -> String:
	if _current_line_index >= _lines.size():
		return ""
	return _lines[_current_line_index].strip_edges()

func _has_more_lines() -> bool:
	return _current_line_index < _lines.size()

func _skip_empty_lines():
	while _has_more_lines():
		var line = _lines[_current_line_index].strip_edges()
		if line.is_empty() or line.begins_with(";"): # Skip comments too
			_current_line_index += 1
		else:
			break

func _parse_vector3(line: String) -> Vector3:
	# Expected format: x, y, z or x y z
	# Remove parens if present
	var clean = line.replace("(", "").replace(")", "").replace(",", " ")
	var parts = clean.split(" ", false)
	if parts.size() >= 3:
		return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	return Vector3.ZERO

func _parse_color(line: String) -> Color:
	# Expected format: r, g, b, [a]
	var clean = line.replace("(", "").replace(")", "").replace(",", " ")
	var parts = clean.split(" ", false)
	if parts.size() >= 3:
		var r = parts[0].to_float() / 255.0 if parts[0].contains(".") == false else parts[0].to_float()
		var g = parts[1].to_float() / 255.0 if parts[1].contains(".") == false else parts[1].to_float()
		var b = parts[2].to_float() / 255.0 if parts[2].contains(".") == false else parts[2].to_float()
		var a = 1.0
		if parts.size() > 3:
			a = parts[3].to_float() / 255.0 if parts[3].contains(".") == false else parts[3].to_float()
		return Color(r, g, b, a)
	return Color.WHITE

func _extract_string_value(line: String, prefix: String) -> String:
	if line.begins_with(prefix):
		return line.substr(prefix.length()).strip_edges()
	return ""

func _extract_int_value(line: String, prefix: String) -> int:
	var s = _extract_string_value(line, prefix)
	if s.is_valid_int():
		return s.to_int()
	return 0

func _extract_float_value(line: String, prefix: String) -> float:
	var s = _extract_string_value(line, prefix)
	if s.is_valid_float():
		return s.to_float()
	return 0.0
