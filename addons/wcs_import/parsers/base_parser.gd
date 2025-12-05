class_name WCSBaseParser
extends RefCounted

## Base class for Wing Commander Saga file parsers.
## Provides common utility functions for parsing text-based formats.

var _content: String = ""
var _lines: PackedStringArray = []
var _current_line_index: int = 0
var _file_path: String = ""


func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + path)
		return false

	_file_path = path
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
	var line = _lines[_current_line_index]
	# Strip comments
	var comment_idx = line.find(";")
	if comment_idx != -1:
		line = line.substr(0, comment_idx)
	
	line = line.strip_edges()
	_current_line_index += 1
	return line


func _peek_next_line() -> String:
	if _current_line_index >= _lines.size():
		return ""
	var line = _lines[_current_line_index]
	# Strip comments
	var comment_idx = line.find(";")
	if comment_idx != -1:
		line = line.substr(0, comment_idx)
		
	return line.strip_edges()


func _get_current_line() -> String:
	if _current_line_index > 0 and _current_line_index <= _lines.size():
		return _lines[_current_line_index - 1]
	return ""


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
		var r = (
			parts[0].to_float() / 255.0 if parts[0].contains(".") == false else parts[0].to_float()
		)
		var g = (
			parts[1].to_float() / 255.0 if parts[1].contains(".") == false else parts[1].to_float()
		)
		var b = (
			parts[2].to_float() / 255.0 if parts[2].contains(".") == false else parts[2].to_float()
		)
		var a = 1.0
		if parts.size() > 3:
			a = (
				parts[3].to_float() / 255.0
				if parts[3].contains(".") == false
				else parts[3].to_float()
			)
		return Color(r, g, b, a)
	return Color.WHITE


func _extract_string_value(line: String, prefix: String) -> String:
	if line.begins_with(prefix):
		var val = line.substr(prefix.length()).strip_edges()
		return _clean_xstr_block(val)
	return ""


func _clean_xstr_block(text: String) -> String:
	var clean = text.strip_edges()
	# Check for XSTR( "...", ... ) wrapper
	if clean.begins_with("XSTR(\""):
		# Find the last closing quote followed by comma or just closing part
		var last_comma = clean.rfind("\",")
		if last_comma != -1:
			return clean.substr(6, last_comma - 6)
		# Sometimes might be just space separator? 
		# Or if it fails to find ", try last quote
		var last_quote = clean.rfind("\"")
		if last_quote > 6:
			return clean.substr(6, last_quote - 6)
			
	# Also strip simple quotes if it's just "Text"
	if clean.begins_with("\"") and clean.ends_with("\""):
		return clean.substr(1, clean.length() - 2)
		
	return text


func _extract_multiline_text(first_line: String, prefix: String) -> String:
	var text = _extract_string_value(first_line, prefix)

	# If we didn't find the end on the same line (if it was even possible)
	# FC2 descriptions usually end with $end_multi_text on a new line

	while _has_more_lines():
		var line = _peek_next_line()
		if line.begins_with("$end_multi_text"):
			_get_next_line() # Consume terminator
			break

		if line.begins_with("$"): # Safety break for new section
			break

		var next_line = _get_next_line()
		
		# Explicitly clean XSTR tags from every line
		# BaseParser _extract_string_value does this for values with prefix, 
		# but here we pass empty prefix.
		var cleaned_line = _extract_string_value(next_line, "")
		
		text += "\n" + cleaned_line

	return _clean_xstr_block(text)


func _extract_sexp(first_line: String, prefix: String) -> String:
	var expr = first_line.substr(prefix.length()).strip_edges()
	var open_count = expr.count("(")
	var close_count = expr.count(")")

	while open_count > close_count and _has_more_lines():
		var line = _get_next_line()
		expr += "\n" + line
		open_count += line.count("(")
		close_count += line.count(")")

	return expr


## Helper: Extract SEXP formula (alias for _extract_sexp to match other parsers)
func _extract_sexp_formula(line: String, prefix: String) -> String:
	return _extract_sexp(line, prefix)


## Helper: Extract multiline string (reads until next section/token)
func _extract_multiline_string(first_line: String, prefix: String) -> String:
	var text = _extract_string_value(first_line, prefix)
	
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at new token or section
		if line.begins_with("$") or line.begins_with("#") or line.begins_with("+"):
			break
			
		var next_line = _get_next_line()
		
		# Skip comments/empty lines within text or treat as newline?
		# Usually we just append.
		text += "\n" + next_line.strip_edges()
		
	return text.strip_edges()


func _extract_int_value(line: String, prefix: String, alt_prefix: String = "") -> int:
	var s = ""
	if line.begins_with(prefix):
		s = _extract_string_value(line, prefix)
	elif alt_prefix != "" and line.begins_with(alt_prefix):
		s = _extract_string_value(line, alt_prefix)

	if s.is_valid_int():
		return s.to_int()
	return 0


func _extract_float_value(line: String, prefix: String, alt_prefix: String = "") -> float:
	var s = ""
	if line.begins_with(prefix):
		s = _extract_string_value(line, prefix)
	elif alt_prefix != "" and line.begins_with(alt_prefix):
		s = _extract_string_value(line, alt_prefix)

	if s.is_valid_float():
		return s.to_float()
	return 0.0


func _extract_boolean_value(line: String, prefix: String) -> bool:
	var s = _extract_string_value(line, prefix).to_upper()
	return s == "YES" or s == "TRUE" or s == "1"


func _extract_list_value(line: String) -> Array[String]:
	# Expected format: $Key: ( "Item1" "Item2" )
	var start_idx = line.find("(")
	var end_idx = line.rfind(")")

	if start_idx == -1 or end_idx == -1 or end_idx <= start_idx:
		return []

	var content = line.substr(start_idx + 1, end_idx - start_idx - 1).strip_edges()
	var items: Array[String] = []
	var current_item = ""
	var in_quote = false

	for i in range(content.length()):
		var char = content[i]
		if char == '"':
			if in_quote:
				items.append(current_item)
				current_item = ""
				in_quote = false
			else:
				in_quote = true
		elif in_quote:
			current_item += char

	return items
