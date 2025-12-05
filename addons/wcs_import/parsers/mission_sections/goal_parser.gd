class_name GoalParser
extends "res://addons/wcs_import/parsers/mission_sections/base_section_parser.gd"

## Parses the Goals section (#Goals)
## Handles mission goals (primary, secondary, bonus) and their SEXP formulas

const MissionGoal = preload("res://scripts/resources/missions/mission_goal.gd")
const SexpParser = preload("res://addons/wcs_import/sexp/sexp_parser.gd")
const SexpCompiler = preload("res://addons/wcs_import/sexp/sexp_compiler.gd")


func parse_section(start_index: int, manifest: Resource) -> int:
	# Goals are parsed one at a time, each starting with $Type:
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next section
		if line.begins_with("#"):
			break
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			_get_next_line()
			continue
		
		# Each goal starts with $Type:
		if line.begins_with("$Type:"):
			_parse_single_goal(manifest)
		else:
			_get_next_line() # Skip unexpected lines
	
	return _base_parser._current_line_index


func _parse_single_goal(manifest: Resource):
	var goal = MissionGoal.new()
	
	# First line is the Type
	var type_line = _get_next_line()
	var type_str = _extract_string_value(type_line, "$Type:")
	goal.type = _map_goal_type(type_str)
	
	# Parse goal properties until we hit the next $Type: or section
	while _has_more_lines():
		var line = _peek_next_line()
		
		# Stop at next goal or section
		if line.begins_with("$Type:") or line.begins_with("#"):
			break
		
		_get_next_line() # Consume line
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";") or line.begins_with("//"):
			continue
		
		# Parse each field
		_parse_goal_field(line, goal)
	
	# Compile behavior tree if formula exists
	if not goal.formula.is_empty():
		var ast = SexpParser.parse(goal.formula)
		if ast:
			goal.behavior_tree = SexpCompiler.compile(ast)
		else:
			push_warning("Failed to parse SEXP for goal: " + goal.formula.substr(0, 50) + "...")
			
	# Add to manifest
	manifest.goals.append(goal)


func _parse_goal_field(line: String, goal: MissionGoal):
	if line.begins_with("+Name:"):
		goal.name = _extract_string_value(line, "+Name:")
	
	elif line.begins_with("$Message:"):
		goal.message = _extract_string_value(line, "$Message:")
		
	elif line.begins_with("$MessageNew:"):
		goal.message = _extract_multiline_string(line, "$MessageNew:")

	elif line.begins_with("+Formula:"):
		goal.formula = _extract_sexp_formula(line, "+Formula:")
	
	elif line.begins_with("+Score:"):
		goal.score = _extract_int_value(line, "+Score:")
	
	elif line.begins_with("+Invalid"):
		goal.is_invalid = true
	
	elif line.begins_with("+Team:"):
		goal.team = _extract_int_value(line, "+Team:")


func _map_goal_type(type_str: String) -> MissionGoal.Type:
	match type_str.to_lower():
		"primary": return MissionGoal.Type.PRIMARY
		"secondary": return MissionGoal.Type.SECONDARY
		"bonus": return MissionGoal.Type.BONUS
	return MissionGoal.Type.PRIMARY
