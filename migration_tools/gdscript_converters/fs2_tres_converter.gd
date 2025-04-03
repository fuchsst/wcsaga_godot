@tool # Allows running from editor/command line potentially, and helps with resource loading
extends SceneTree

# Preload necessary resource scripts
const MissionData = preload("res://scripts/resources/mission/mission_data.gd")
const ShipInstanceData = preload("res://scripts/resources/mission/ship_instance_data.gd")
const WingInstanceData = preload("res://scripts/resources/mission/wing_instance_data.gd")
const MissionObjectiveData = preload("res://scripts/resources/mission/mission_objective_data.gd")
const MissionEventData = preload("res://scripts/resources/mission/mission_event_data.gd")
const SexpNode = preload("res://scripts/scripting/sexp/sexp_node.gd")
const ParserFactory = preload("res://migration_tools/gdscript_converters/fs2_parsers/parser_factory.gd")
const PlayerStartData = preload("res://scripts/resources/mission/player_start_data.gd")
const WaypointListData = preload("res://scripts/resources/mission/waypoint_list_data.gd")
const JumpNodeData = preload("res://scripts/resources/mission/jump_node_data.gd")
const MessageData = preload("res://scripts/resources/mission/message_data.gd"
const ReinforcementData = preload("res://scripts/resources/mission/reinforcement_data.gd")
const AsteroidFieldData = preload("res://scripts/resources/mission/asteroid_field_data.gd")
const BriefingData = preload("res://scripts/resources/mission/briefing_data.gd")
const DebriefingData = preload("res://scripts/resources/mission/debriefing_data.gd")
const SexpVariableData = preload("res://scripts/resources/mission/sexp_variable_data.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For flags etc.


# --- Configuration ---
var input_dir: String = "res://migration_tools/extracted_missions" # Default input relative to project
var output_dir: String = "res://resources/missions" # Default output relative to project
var force_overwrite: bool = false

# --- Parser State ---
var current_mission_data: MissionData
var current_line_num: int = 0
var lines: PackedStringArray = []
var current_section: String = ""

# --- SEXP Operator Mapping (Placeholder - Load from constants or define fully) ---
# TODO: Populate this properly from SexpConstants.gd or FS2 source analysis
const OPERATOR_MAP: Dictionary = {
	"true": SexpNode.SexpOperator.OP_TRUE, "false": SexpNode.SexpOperator.OP_FALSE,
	"and": SexpNode.SexpOperator.OP_AND, "or": SexpNode.SexpOperator.OP_OR, "not": SexpNode.SexpOperator.OP_NOT,
	"event-true": SexpNode.SexpOperator.OP_EVENT_TRUE, "goal-true": SexpNode.SexpOperator.OP_GOAL_TRUE,
	"is-destroyed": SexpNode.SexpOperator.OP_IS_DESTROYED,
	# ... add all others ...
}

# --- Main Entry Point (e.g., for command-line execution) ---
func _init():
	# This function is called when the script is run.
	# We'll use command-line arguments to specify input/output.
	print("FS2 to TRES Converter Initializing...")
	var args = OS.get_cmdline_args()

	var input_file_arg = "--input="
	var output_dir_arg = "--output_dir="
	var force_arg = "--force"

	var input_file_path = ""

	for arg in args:
		if arg.begins_with(input_file_arg):
			input_file_path = arg.substr(input_file_arg.length())
		elif arg.begins_with(output_dir_arg):
			output_dir = arg.substr(output_dir_arg.length())
		elif arg == force_arg:
			force_overwrite = true

	if not input_file_path:
		printerr("Error: No input file specified. Use --input=<path_to_fs2_file>")
		quit(1)
		return

	var input_path := Path.new(input_file_path)
	var output_path := Path.new(output_dir).join(input_path.stem + ".tres")

	print(f"Input: {input_file_path}")
	print(f"Output: {output_path.path}")
	print(f"Force Overwrite: {force_overwrite}")

	if convert_file(input_path, output_path):
		print("Conversion successful.")
		quit(0)
	else:
		printerr("Conversion failed.")
		quit(1)


# --- Core Conversion Logic ---

func convert_file(input_path: Path, output_path: Path) -> bool:
	"""Converts a single FS2 file to a Godot TRES file."""
	_reset_parser_state()
	print(f"Converting {input_path.path} to {output_path.path}...")

	var file = FileAccess.open(input_path.path, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {input_path.path}")
		return false

	# Read all lines (handle potential encoding issues if necessary)
	var content = file.get_as_text()
	file.close()
	lines = content.split("\n")
	print(f"Read {lines.size()} lines.")

	# Create the main resource instance
	current_mission_data = MissionData.new()

	# Main parsing loop
	while current_line_num < lines.size():
		_skip_whitespace_and_comments()
		var line = _peek_line()

		if line == null:
			break # End of file

		if line.begins_with("#"):
			current_section = line.strip_edges()
			print(f"Entering section: {current_section}")
			_read_line() # Consume the section header line

			# --- Section Dispatch using Factory ---
			var normalized_section = current_section.trim_prefix("#").strip_edges().to_lower().replace(" ", "_")
			var parser = ParserFactory.create_parser(normalized_section)

			if parser:
				# Pass the necessary state (lines array and current index)
				# The parser's parse method should return a dictionary:
				# { "data": parsed_data_for_section, "next_line": updated_line_index }
				var result = parser.parse(lines, current_line_num)

				if result and result.has("data") and result.has("next_line"):
					# Assign parsed data to the correct field in current_mission_data
					# This requires mapping normalized_section name to MissionData field name
					match normalized_section:
						"mission_info":
							for key in result.data:
								if current_mission_data.has(key):
									current_mission_data.set(key, result.data[key])
								else:
									print(f"Warning: Parsed key '{key}' not found in MissionData resource.")
							# Set boolean flags after parsing the main flags integer
							current_mission_data.full_nebula = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_FULLNEB) != 0
							current_mission_data.red_alert = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_RED_ALERT) != 0
							current_mission_data.scramble = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_SCRAMBLE) != 0
							current_mission_data.all_teams_attack = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_ALL_ATTACK) != 0
							# ... potentially others ...
						"objects":
							current_mission_data.ships = result.data # Expects Array[ShipInstanceData]
						"wings":
							current_mission_data.wings = result.data # Expects Array[WingInstanceData]
						"events":
							current_mission_data.events = result.data # Expects Array[MissionEventData]
						"goals":
							current_mission_data.goals = result.data # Expects Array[MissionObjectiveData]
						"waypoints":
							# Waypoint parser returns dict with 'jump_nodes' and 'waypoint_lists'
							current_mission_data.jump_nodes = result.data.get("jump_nodes", [])
							current_mission_data.waypoint_lists = result.data.get("waypoint_lists", [])
						"messages":
							# Messages parser returns dict with sender, persona, and messages list
							current_mission_data.command_sender = result.data.get("command_sender", "Command")
							current_mission_data.command_persona_name = result.data.get("command_persona_name", "")
							current_mission_data.messages = result.data.get("messages", [])
						"reinforcements":
							current_mission_data.reinforcements = result.data # Expects Array[ReinforcementData]
						"background_bitmaps":
							# Background parser returns dict of settings
							for key in result.data:
								if current_mission_data.has(key):
									current_mission_data.set(key, result.data[key])
								else:
									print(f"Warning: Parsed background key '{key}' not found in MissionData.")
						"asteroid_fields":
							# FS2 only has one field, parser returns an array, take the first if exists
							var fields = result.data # Expects Array[Dictionary]
							if fields and fields.size() > 0:
								# TODO: Convert Dictionary to AsteroidFieldData resource
								# current_mission_data.asteroid_field = _create_asteroid_field_resource(fields[0])
								print("TODO: Convert parsed asteroid field dict to resource")
							else:
								# current_mission_data.asteroid_field = null
								pass
						"briefing":
							# Assumes parser returns one BriefingData, handle multiple teams if needed
							# TODO: Convert Dictionary to BriefingData resource
							# current_mission_data.briefings.append(_create_briefing_resource(result.data))
							print("TODO: Convert parsed briefing dict to resource")
						"debriefing_info":
							# Assumes parser returns one DebriefingData
							# TODO: Convert Dictionary to DebriefingData resource
							# current_mission_data.debriefings.append(_create_debriefing_resource(result.data))
							print("TODO: Convert parsed debriefing dict to resource")
						"sexp_variables": # Maps from #Variables
							# TODO: Convert Array[Dictionary] to Array[SexpVariableData]
							# current_mission_data.variables = _create_sexp_variable_resources(result.data)
							print("TODO: Convert parsed variables dict array to resource array")
						"music":
							# Music parser returns dict of settings
							for key in result.data:
								if current_mission_data.has(key):
									current_mission_data.set(key, result.data[key])
								else:
									print(f"Warning: Parsed music key '{key}' not found in MissionData.")
						"players":
							# TODO: Convert Array[Dictionary] to Array[PlayerStartData]
							# current_mission_data.player_starts = _create_player_start_resources(result.data)
							print("TODO: Convert parsed player starts dict array to resource array")
						"cutscenes":
							# TODO: Convert Array[Dictionary] to Array[MissionCutsceneData]
							# current_mission_data.cutscenes = _create_cutscene_resources(result.data)
							print("TODO: Convert parsed cutscenes dict array to resource array")
						"fiction_viewer":
							# Fiction parser returns dict with 'file' and 'font'
							current_mission_data.fiction_file = result.data.get("file", "")
							current_mission_data.fiction_font = result.data.get("font", "")
						"command_briefing":
							# TODO: Convert Dictionary to CommandBriefingData resource
							# current_mission_data.command_briefings.append(_create_cmd_briefing_resource(result.data))
							print("TODO: Convert parsed command briefing dict to resource")
						# Add cases for other sections like #Plot Info, #Briefing Info (old) etc.
						_:
							print(f"Warning: No assignment logic for parsed section '{normalized_section}'.")

					# Update the main line counter
					current_line_num = result.next_line
				else:
					printerr(f"Error: Parser for section '{current_section}' failed or returned invalid data.")
					# Decide how to handle parser failure - skip section or abort?
					_skip_section() # Skip rest of section on failure
			else:
				print(f"Warning: Skipping unknown or unhandled section: {current_section}")
				_skip_section() # Skip lines until next section or EOF
		else:
			# Line doesn't start with #, might be unexpected content or end of file
			printerr(f"Warning: Unexpected line outside section: '{line}' at line {current_line_num + 1}. Stopping parse.")
			break # Stop parsing if structure is unexpected

	# After parsing, save the .tres file
	# Ensure output directory exists
	var dir_path = output_path.path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	print(f"Saving resource to {output_path.path}")
	# Use ResourceSaver flags for better compatibility and readability if needed
	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	var save_result = ResourceSaver.save(current_mission_data, output_path.path, save_flags)
	if save_result != OK:
		printerr(f"Error saving resource '{output_path.path}': {save_result}")
		return false

	print(f"Successfully converted {input_path.path}")
	return true

# --- Helper Functions (Main converter needs its own set for flow control) ---

func _reset_parser_state():
	"""Resets state for parsing a new file."""
	current_mission_data = null # Will be created in convert_file
	current_line_num = 0
	lines.clear()
	current_section = ""

func _peek_line() -> String:
	"""Returns the next line without advancing the pointer."""
	if current_line_num < lines.size():
		return lines[current_line_num].strip_edges()
	return null

func _read_line() -> String:
	"""Reads and returns the next line, advancing the pointer."""
	var line = _peek_line()
	if line != null:
		current_line_num += 1
	return line

func _skip_whitespace_and_comments():
	"""Advances the line pointer past empty lines and comments."""
	while true:
		var line = _peek_line()
		if line == null:
			break
		# Check if line is not null AND not empty AND does not start with ';'
		if line and not line.is_empty() and not line.begins_with(';'):
			break
		current_line_num += 1 # Consume the empty/comment line

func _skip_section():
	"""Skips lines until the next section marker or EOF."""
	while true:
		var line = _peek_line()
		if line == null or line.begins_with("#"):
			break
		_read_line()


