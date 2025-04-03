# migration_tools/gdscript_converters/fs2_parsers/base_parser.gd
class_name BaseFS2Parser
extends RefCounted

# --- Shared References (Set by the main converter) ---
var _lines: PackedStringArray # Reference to all lines in the file
var _current_line_num_ref: int # Reference to the main converter's line counter (pass by value, need wrapper object or signal?)
# NOTE: Passing line number by reference directly isn't straightforward in GDScript.
# The main converter might need to manage the line iterator and pass relevant chunks/lines
# to the specific parser, or the parser needs a way to signal back how many lines it consumed.
# For now, let's assume the main converter handles line advancement based on parser needs.

# --- Common Parsing Utilities (Can be moved here from main converter later) ---

# Placeholder for the main parse method required by all section parsers.
# Subclasses will override this.
# It should parse the relevant lines for its section and return the structured data
# (e.g., a Dictionary, a specific Resource instance, or an Array of Resources).
func parse(lines_iterator) -> Variant:
	push_error("BaseFS2Parser.parse() must be overridden by subclasses!")
	return null

# --- Helper methods (potentially moved from main converter) ---

func _parse_vector(line_content: String) -> Vector3:
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 3:
		return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	else:
		printerr(f"Error parsing Vector3: '{line_content}'")
		return Vector3.ZERO

func _parse_basis(line_content: String) -> Basis:
	var content = line_content.trim_prefix("(").trim_suffix(")").strip_edges()
	var parts = content.split(",", false)
	if parts.size() == 9:
		var x = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
		var y = Vector3(parts[3].to_float(), parts[4].to_float(), parts[5].to_float())
		var z = Vector3(parts[6].to_float(), parts[7].to_float(), parts[8].to_float())
		return Basis(x, y, z)
	else:
		printerr(f"Error parsing Basis: '{line_content}'")
		return Basis.IDENTITY

# Add other common helpers like _parse_sexp, _parse_multitext, token parsers etc.
# if they are shared across multiple section parsers.
