class_name EventParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Events section (#Events)
## Handles mission events, SEXP formulas, and objectives

const MissionEnums = preload("res://scripts/resources/missions/mission_enums.gd")
const MissionEvent = preload("res://scripts/resources/missions/mission_event.gd")
const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpCompiler = preload("res://addons/wcs_import/sexp/sexp_compiler.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Events are parsed one at a time, each starting with $Formula:
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_get_next_line()
			continue
		
		# Each event starts with $Formula:
		if line.begins_with("$Formula:"):
			_parse_single_event(manifest)
		else:
			_get_next_line() # Skip unexpected lines
	
	return _base_parser._current_line_index


func _parse_single_event(manifest: Resource):
	var event = MissionEvent.new()
	
	# First line is the formula
	var formula_line = _get_next_line()
	event.formula = _extract_sexp_formula(formula_line, "$Formula:")
	
	# Compile SEXP to BehaviorTree
	if not event.formula.is_empty():
		var ast = SexpParser.parse(event.formula)
		if ast:
			event.behavior_tree = SexpCompiler.compile(ast)
		else:
			push_warning("Failed to parse SEXP for event: " + event.formula.substr(0, 50) + "...")
	
	# Parse event properties until we hit the next $Formula: or section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next event or section
		if line.begins_with("$Formula:") or line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse each field
		_parse_event_field(line, event)
	
	# Add to manifest
	manifest.events.append(event)


func _parse_event_field(line: String, event: MissionEvent):
	if line.begins_with("+Name:"):
		event.event_name = _extract_string_value(line, "+Name:")
	
	elif line.begins_with("+Repeat Count:"):
		event.repeat_count = _extract_int_value(line, "+Repeat Count:")
	
	elif line.begins_with("+Interval:"):
		event.interval = _extract_int_value(line, "+Interval:")
	
	elif line.begins_with("+Team:"):
		var team_int = _extract_int_value(line, "+Team:")
		# Map int to enum (0=Friendly, 1=Hostile, etc.)
		# Wait, +Team in events is an integer, usually 0.
		# Let's assume standard mapping or check if it uses string names elsewhere.
		# In FS2, it's usually an int index.
		event.team = team_int as MissionEnums.Team
	
	elif line.begins_with("+Chained:"):
		event.chain_delay = _extract_int_value(line, "+Chained:")
	
	elif line.begins_with("+Score:"):
		event.score = _extract_int_value(line, "+Score:")
	
	elif line.begins_with("+Objective:"):
		event.objective = _extract_string_value(line, "+Objective:")
	
	elif line.begins_with("+Objective Text:"):
		event.objective_desc = _clean_xstr(_extract_string_value(line, "+Objective Text:"))
