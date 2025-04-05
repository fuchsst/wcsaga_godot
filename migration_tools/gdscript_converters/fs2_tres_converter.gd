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
const BriefingParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/briefing_parser.gd")
const DebriefingParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/debriefing_parser.gd")
const CommandBriefingParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/command_briefing_parser.gd")
const GoalsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/goals_parser.gd")
const EventsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/events_parser.gd")
const ObjectsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/objects_parser.gd")
const WingsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/wings_parser.gd")
const WaypointsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/waypoints_parser.gd")
const MessagesParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/messages_parser.gd")
const ReinforcementsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/reinforcements_parser.gd")
const PlayersParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/players_parser.gd")
const MissionInfoParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/mission_info_parser.gd")
const PlayerStartData = preload("res://scripts/resources/mission/player_start_data.gd")
const WaypointListData = preload("res://scripts/resources/mission/waypoint_list_data.gd")
const JumpNodeData = preload("res://scripts/resources/mission/jump_node_data.gd")
const MessageData = preload("res://scripts/resources/mission/message_data.gd")
const ReinforcementData = preload("res://scripts/resources/mission/reinforcement_data.gd")
const AsteroidFieldData = preload("res://scripts/resources/mission/asteroid_field_data.gd")
const BriefingData = preload("res://scripts/resources/mission/briefing_data.gd")
const DebriefingData = preload("res://scripts/resources/mission/debriefing_data.gd")
const PersonaData = preload("res://scripts/resources/mission/persona_data.gd")
const SexpVariableData = preload("res://scripts/resources/mission/sexp_variable_data.gd")
const MissionCutsceneData = preload("res://scripts/resources/mission/mission_cutscene_data.gd")
const GlobalConstants = preload("res://scripts/globals/global_constants.gd") # For flags etc.
const SexpConstants = preload("res://scripts/scripting/sexp/sexp_constants.gd") # For variable types


# --- Configuration ---
var input_dir: String = "res://migration_tools/extracted_missions" # Default input relative to project
var output_dir: String = "res://resources/missions" # Default output relative to project
var force_overwrite: bool = false

# --- Parser State ---
var current_mission_data: MissionData
var current_line_num: int = 0
var lines: PackedStringArray = []
var current_section: String = ""


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

	if convert_file(input_file_path, output_path):
		print("Conversion successful.")
		quit(0)
	else:
		printerr("Conversion failed.")
		quit(1)


# --- Core Conversion Logic ---

func convert_file(input_path_str: String, output_path_str: String) -> bool:
	"""Converts a single FS2 file to a Godot TRES file."""
	_reset_parser_state()
	print(f"Converting {input_path_str} to {output_path_str}...")

	var file = FileAccess.open(input_path_str, FileAccess.READ)
	if not file:
		printerr(f"Error: Could not open input file: {input_path_str}")
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
					# Handle sections that can appear multiple times (for multiplayer teams)
					var repeatable_sections = ["briefing", "debriefing_info", "command_briefing"]
					var is_repeatable = repeatable_sections.has(normalized_section)
					var first_parse = true

					while true: # Loop to handle potentially repeated sections
						if not first_parse:
							# If not the first time, check if the next line is the same section
							_skip_whitespace_and_comments()
							var next_line_peek = _peek_line()
							if next_line_peek == null or next_line_peek != current_section:
								break # Not the same section or EOF, exit loop
							_read_line() # Consume the repeated section header
							print(f"Parsing additional section: {current_section}")
							# Re-create the parser instance for the repeated section
							parser = ParserFactory.create_parser(normalized_section)
							if not parser:
								printerr(f"Error: Could not re-create parser for repeated section '{current_section}'")
								_skip_section() # Skip this unexpected repeated section
								break

						# Parse the section (first time or repeated time)
						var result = parser.parse(lines, current_line_num)

						if result and result.has("data") and result.has("next_line"):
							# Assign parsed data based on section type
							match normalized_section:
								"mission_info":
									# MissionInfoParser returns a Dictionary
									# (Should only appear once)
									if not first_parse: printerr("Error: Multiple #Mission Info sections found!")
							if result.data is Dictionary:
								for key in result.data:
									if current_mission_data.has(key):
										current_mission_data.set(key, result.data[key])
									else:
										# Handle specific mappings if names differ
										match key:
											"mission_title": current_mission_data.title = result.data[key]
											"mission_notes": current_mission_data.notes = result.data[key]
											"loading_screen_640": current_mission_data.loading_screen_640 = result.data[key]
											"loading_screen_1024": current_mission_data.loading_screen_1024 = result.data[key]
											"ai_profile_name": current_mission_data.ai_profile_name = result.data[key]
											# Add other specific mappings as needed
											_: print(f"Warning: Parsed key '{key}' from Mission Info not directly found or mapped in MissionData resource.")
								# Set boolean flags after parsing the main flags integer
								current_mission_data.full_nebula = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_FULLNEB) != 0
								current_mission_data.red_alert = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_RED_ALERT) != 0
								current_mission_data.scramble = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_SCRAMBLE) != 0
								current_mission_data.all_teams_attack = (current_mission_data.flags & GlobalConstants.MISSION_FLAG_ALL_ATTACK) != 0
								# Handle support ship settings conversion
								if result.data.has("disallow_support"):
									current_mission_data.support_ships_max = 0 if result.data["disallow_support"] else -1 # -1 means default/allowed
								if result.data.has("hull_repair_ceiling"):
									current_mission_data.support_ships_hull_repair_ceiling = result.data["hull_repair_ceiling"]
								if result.data.has("subsys_repair_ceiling"):
									current_mission_data.support_ships_subsys_repair_ceiling = result.data["subsys_repair_ceiling"]
								if result.data.has("player_entry_delay"):
									current_mission_data.player_entry_delay_seconds = result.data["player_entry_delay"]
								if result.data.has("squad_reassign_name"):
									current_mission_data.squad_reassign_name = result.data["squad_reassign_name"]
								if result.data.has("squad_reassign_logo"):
									current_mission_data.squad_reassign_logo = result.data["squad_reassign_logo"]
							else:
								printerr(f"MissionInfoParser did not return a Dictionary for section '{current_section}'")
						"objects":
							# Objects parser returns Array[ShipInstanceData]
							if result.data is Array:
								current_mission_data.ships = result.data
							else:
								printerr(f"ObjectsParser did not return an Array for section '{current_section}'")
						"wings":
							# Wings parser returns Array[WingInstanceData]
							if result.data is Array:
								current_mission_data.wings = result.data
							else:
								printerr(f"WingsParser did not return an Array for section '{current_section}'")
						"events":
							# Events parser returns Array[MissionEventData]
							if result.data is Array:
								current_mission_data.events = result.data
							else:
								printerr(f"EventsParser did not return an Array for section '{current_section}'")
						"goals":
							# Goals parser returns Array[MissionObjectiveData]
							if result.data is Array:
								current_mission_data.goals = result.data
							else:
								printerr(f"GoalsParser did not return an Array for section '{current_section}'")
						"waypoints":
							# Waypoint parser returns dict with 'jump_nodes' (Array[Dictionary])
							# and 'waypoint_lists' (Array[Dictionary])
							if result.data is Dictionary:
								var parsed_jump_nodes = result.data.get("jump_nodes", [])
								for jn_dict in parsed_jump_nodes:
									current_mission_data.jump_nodes.append(_create_jump_node_resource(jn_dict))

								var parsed_wp_lists = result.data.get("waypoint_lists", [])
								for wpl_dict in parsed_wp_lists:
									current_mission_data.waypoint_lists.append(_create_waypoint_list_resource(wpl_dict))
							else:
								printerr(f"WaypointsParser did not return a Dictionary for section '{current_section}'")
						"messages":
							# Messages parser returns dict with 'command_sender', 'command_persona_name', 'messages' (Array[Dictionary])
							if result.data is Dictionary:
								current_mission_data.command_sender = result.data.get("command_sender", "Command")
								current_mission_data.command_persona_name = result.data.get("command_persona_name", "")
								var parsed_messages = result.data.get("messages", [])
								for msg_dict in parsed_messages:
									current_mission_data.messages.append(_create_message_resource(msg_dict))
								# TODO: Handle personas if they are parsed here or globally
							else:
								printerr(f"MessagesParser did not return a Dictionary for section '{current_section}'")
						"reinforcements":
							# Reinforcements parser returns Array[Dictionary]
							if result.data is Array:
								for rf_dict in result.data:
									current_mission_data.reinforcements.append(_create_reinforcement_resource(rf_dict))
							else:
								printerr(f"ReinforcementsParser did not return an Array for section '{current_section}'")
						"background_bitmaps":
							# Background parser returns dict of settings
							if result.data is Dictionary:
								for key in result.data:
									if current_mission_data.has(key):
										current_mission_data.set(key, result.data[key])
									else:
										print(f"Warning: Parsed background key '{key}' not found in MissionData.")
							else:
								printerr(f"BackgroundParser did not return a Dictionary for section '{current_section}'")
						"asteroid_fields":
							# FS2 only has one field, parser returns an array of one dict
							if result.data is Array and result.data.size() > 0:
								if not current_mission_data.has("asteroid_fields"):
									printerr("MissionData resource script needs an '@export var asteroid_fields: Array[AsteroidFieldData]' field!")
								else:
									current_mission_data.asteroid_fields.append(_create_asteroid_field_resource(result.data[0]))
							elif result.data is Array and result.data.size() == 0:
								pass # No asteroid field defined
							else:
								printerr(f"AsteroidFieldParser did not return an Array for section '{current_section}'")
						"briefing":
							# Briefing parser returns a Dictionary representing one briefing
							if result.data is Dictionary:
								if not current_mission_data.has("briefings"):
									printerr("MissionData resource script needs an '@export var briefings: Array[BriefingData]' field!")
								else:
									# NOTE: FS2 can have multiple #Briefing sections for multiplayer.
									# The current setup parses one section per call.
									# If multiple briefings are needed, the main loop should detect
									# subsequent #Briefing sections and call the parser again,
									# appending results here. For now, we append the single result.
									current_mission_data.briefings.append(_create_briefing_resource(result.data))
									else:
										printerr(f"BriefingParser did not return a Dictionary for section '{current_section}'")
						"debriefing_info":
							# Debriefing parser returns a Dictionary representing one debriefing
							if result.data is Dictionary:
								if not current_mission_data.has("debriefings"):
									printerr("MissionData resource script needs an '@export var debriefings: Array[DebriefingData]' field!")
								else:
									# Append the parsed debriefing data
									current_mission_data.debriefings.append(_create_debriefing_resource(result.data))
							else:
								printerr(f"DebriefingParser did not return a Dictionary for section '{current_section}'")
						"sexp_variables": # Maps from #Variables
							# Variables parser returns Array[Dictionary]
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Variables sections found!")
							if result.data is Array:
								if not current_mission_data.has("variables"):
									printerr("MissionData resource script needs an '@export var variables: Array[SexpVariableData]' field!")
								else:
									current_mission_data.variables = _create_sexp_variable_resources(result.data)
							else:
									printerr(f"VariablesParser did not return an Array for section '{current_section}'")
						"music":
							# Music parser returns dict of settings
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Music sections found!")
							if result.data is Dictionary:
								for key in result.data:
									if current_mission_data.has(key):
										current_mission_data.set(key, result.data[key])
									else:
										print(f"Warning: Parsed music key '{key}' not found in MissionData.")
							else:
								printerr(f"MusicParser did not return a Dictionary for section '{current_section}'")
						"players":
							# Players parser returns Array[Dictionary]
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Players sections found!")
							if result.data is Array:
								if not current_mission_data.has("player_starts"):
									printerr("MissionData resource script needs an '@export var player_starts: Array[PlayerStartData]' field!")
								else:
									current_mission_data.player_starts = _create_player_start_resources(result.data)
							else:
									printerr(f"PlayersParser did not return an Array for section '{current_section}'")
						"cutscenes":
							# Cutscenes parser returns Array[Dictionary]
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Cutscenes sections found!")
							if result.data is Array:
								if not current_mission_data.has("cutscenes"):
									printerr("MissionData resource script needs an '@export var cutscenes: Array[MissionCutsceneData]' field!")
								else:
									current_mission_data.cutscenes = _create_cutscene_resources(result.data)
							else:
								printerr(f"CutscenesParser did not return an Array for section '{current_section}'")
						"fiction_viewer":
							# Fiction parser returns dict with 'file' and 'font'
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Fiction Viewer sections found!")
							if result.data is Dictionary:
								current_mission_data.fiction_file = result.data.get("file", "")
								current_mission_data.fiction_font = result.data.get("font", "")
							else:
									printerr(f"FictionParser did not return a Dictionary for section '{current_section}'")
						"command_briefing":
							# Command briefing parser returns a Dictionary representing one command briefing
							if result.data is Dictionary:
								if not current_mission_data.has("command_briefings"):
									printerr("MissionData resource script needs an '@export var command_briefings: Array[CommandBriefingData]' field!")
								else:
									# Append the parsed command briefing data
									current_mission_data.command_briefings.append(_create_cmd_briefing_resource(result.data))
							else:
								printerr(f"CommandBriefingParser did not return a Dictionary for section '{current_section}'")
						"texture_replacements":
							# Texture replacement parser returns Array[Dictionary]
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Texture Replacements sections found!")
							if result.data is Array:
								if not current_mission_data.has("texture_replacements"):
									printerr("MissionData resource script needs an '@export var texture_replacements: Array[TextureReplacementData]' field!")
								else:
									for tr_dict in result.data:
										current_mission_data.texture_replacements.append(_create_texture_replacement_resource(tr_dict))
							else:
									printerr(f"TextureReplacementParser did not return an Array for section '{current_section}'")
						"alternate_types": # Maps from #Alternate Types:
							# Alt names parser returns Array[String]
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Alternate Types sections found!")
							if result.data is Array:
								current_mission_data.alternate_type_names = result.data
							else:
								printerr(f"AltNamesParser did not return an Array for section '{current_section}'")
						"callsigns": # Maps from #Callsigns:
							# Callsigns parser returns Array[String]
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Callsigns sections found!")
							if result.data is Array:
								current_mission_data.callsigns = result.data
							else:
									printerr(f"CallsignsParser did not return an Array for section '{current_section}'")
						"personas": # Added case for personas
							# Persona parser returns Array[Dictionary]
							# (Should only appear once)
							if not first_parse: printerr("Error: Multiple #Personas sections found!")
							if result.data is Array:
								if not current_mission_data.has("personas"):
									printerr("MissionData resource script needs an '@export var personas: Array[PersonaData]' field!")
								else:
									for p_dict in result.data:
										current_mission_data.personas.append(_create_persona_resource(p_dict))
							else:
								printerr(f"PersonaParser did not return an Array for section '{current_section}'")
						# Add cases for other sections like #Plot Info, #Briefing Info (old) etc.
						_:
							print(f"Warning: No assignment logic for parsed section '{normalized_section}'.")

							# Update the main line counter
							current_line_num = result.next_line
						else:
							printerr(f"Error: Parser for section '{current_section}' failed or returned invalid data.")
							# Decide how to handle parser failure - skip section or abort?
							_skip_section() # Skip rest of section on failure
							break # Exit the inner while loop for this section

						first_parse = false # Mark that the first parse of this section type is done

						# If this section type is not repeatable, exit the inner while loop
						if not is_repeatable:
							break
			else:
				print(f"Warning: Skipping unknown or unhandled section: {current_section}")
				_skip_section() # Skip lines until next section or EOF
		else:
			# Line doesn't start with #, might be unexpected content or end of file
			printerr(f"Warning: Unexpected line outside section: '{line}' at line {current_line_num + 1}. Stopping parse.")
			break # Stop parsing if structure is unexpected

	# After parsing, save the .tres file
	# Ensure output directory exists
	var dir_path = output_path_str.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	print(f"Saving resource to {output_path_str}")
	# Use ResourceSaver flags for better compatibility and readability if needed
	var save_flags = ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
	var save_result = ResourceSaver.save(current_mission_data, output_path_str, save_flags)
	if save_result != OK:
		printerr(f"Error saving resource '{output_path_str}': {save_result}")
		return false

	print(f"Successfully converted {input_path_str}")
	return true


# --- Helper Functions to convert parsed Dictionaries/Arrays to Resources ---

# Helper function to convert parsed persona dictionary to resource
func _create_persona_resource(parsed_data: Dictionary) -> PersonaData:
	var persona = PersonaData.new()
	persona.name = parsed_data.get("name", "")
	persona.type_flags = parsed_data.get("type_flags", 0)
	# TODO: Resolve species_name to species_index if needed, or store name
	# For now, assuming PersonaData stores index and parser provides name
	var species_name = parsed_data.get("species_name", "")
	# Placeholder: Look up species index based on name if SpeciesManager is available
	# persona.species_index = SpeciesManager.find_species_index(species_name) if SpeciesManager else -1
	persona.species_index = -1 # Default until species lookup is implemented
	persona.auto_assign = parsed_data.get("auto_assign", false)
	return persona

# Helper function to convert parsed briefing dictionary to resource
func _create_briefing_resource(parsed_data: Dictionary) -> BriefingData:
	var briefing = BriefingData.new()
	# Assuming BriefingParser returns a Dictionary with a "stages" key containing an Array of Dictionaries
	var parsed_stages = parsed_data.get("stages", [])
	for stage_dict in parsed_stages:
		var stage_res = BriefingStageData.new()
		stage_res.text = stage_dict.get("text", "")
		stage_res.voice_filename = stage_dict.get("voice", "")
		stage_res.camera_pos = stage_dict.get("camera_pos", Vector3.ZERO)
		stage_res.camera_orient = stage_dict.get("camera_orient", Basis())
		stage_res.camera_time_ms = stage_dict.get("camera_time", 0)
		stage_res.flags = stage_dict.get("flags", 0)
		stage_res.formula_sexp = stage_dict.get("formula_sexp", null) # Assumes parser returns SexpNode

		# Process Icons
		var parsed_icons = stage_dict.get("icons", [])
		for icon_dict in parsed_icons:
			var icon_res = BriefingIconData.new()
			icon_res.type = icon_dict.get("type", 0)
			icon_res.team = icon_dict.get("team", 0)
			icon_res.ship_class_name = icon_dict.get("class_name", "") # Store name, resolve index later if needed
			icon_res.position = icon_dict.get("pos", Vector3.ZERO)
			icon_res.label = icon_dict.get("label", "")
			icon_res.id = icon_dict.get("id", -1)
			icon_res.flags = icon_dict.get("flags", 0)
			stage_res.icons.append(icon_res)

		# Process Lines
		var parsed_lines = stage_dict.get("lines", [])
		for line_dict in parsed_lines:
			var line_res = BriefingLineData.new()
			line_res.start_icon_index = line_dict.get("start_icon", -1)
			line_res.end_icon_index = line_dict.get("end_icon", -1)
			stage_res.lines.append(line_res)

		briefing.stages.append(stage_res)
	return briefing

# Helper function to convert parsed debriefing dictionary to resource
func _create_debriefing_resource(parsed_data: Dictionary) -> DebriefingData:
	var debriefing = DebriefingData.new()
	# Assuming DebriefingParser returns a Dictionary with a "stages" key containing an Array of Dictionaries
	var parsed_stages = parsed_data.get("stages", [])
	for stage_dict in parsed_stages:
		var stage_res = DebriefingStageData.new()
		stage_res.text = stage_dict.get("text", "")
		stage_res.voice_filename = stage_dict.get("voice", "")
		stage_res.recommendation_text = stage_dict.get("recommendation_text", "")
		stage_res.formula_sexp = stage_dict.get("formula_sexp", null) # Assumes parser returns SexpNode
		debriefing.stages.append(stage_res)
	return debriefing

# Helper function to convert parsed command briefing dictionary to resource
func _create_cmd_briefing_resource(parsed_data: Dictionary) -> CommandBriefingData:
	var cmd_briefing = CommandBriefingData.new()
	# Assuming CommandBriefingParser returns a Dictionary with a "stages" key containing an Array of Dictionaries
	var parsed_stages = parsed_data.get("stages", [])
	for stage_dict in parsed_stages:
		var stage_res = CommandBriefingStageData.new()
		stage_res.text = stage_dict.get("text", "")
		stage_res.ani_filename = stage_dict.get("ani_filename", "")
		stage_res.wave_filename = stage_dict.get("wave_filename", "")
		cmd_briefing.stages.append(stage_res)
	return cmd_briefing

# Helper function to convert parsed asteroid field dictionary to resource
func _create_asteroid_field_resource(parsed_data: Dictionary) -> AsteroidFieldData:
	var field = AsteroidFieldData.new()
	# FS2 only has one field, density is used for initial count
	field.initial_asteroids = parsed_data.get("density", 0)
	field.field_type = parsed_data.get("field_type", AsteroidFieldData.FieldType.ACTIVE)
	field.debris_genre = parsed_data.get("debris_genre", AsteroidFieldData.DebrisGenre.ASTEROID)
	field.field_debris_type_indices = parsed_data.get("field_debris_type_indices", [-1, -1, -1])
	field.average_speed = parsed_data.get("average_speed", 0.0)
	field.min_bound = parsed_data.get("min_bound", Vector3.ZERO)
	field.max_bound = parsed_data.get("max_bound", Vector3.ZERO)
	field.has_inner_bound = parsed_data.get("has_inner_bound", false)
	field.inner_min_bound = parsed_data.get("inner_min_bound", Vector3.ZERO)
	field.inner_max_bound = parsed_data.get("inner_max_bound", Vector3.ZERO)
	# Note: The velocity vector itself isn't stored, only the average speed.
	# Runtime logic will need to generate random velocities based on average_speed.
	return field

# Helper function to convert parsed variable dictionaries to resources
func _create_sexp_variable_resources(parsed_array: Array) -> Array[SexpVariableData]:
	var resources: Array[SexpVariableData] = []
	for var_dict in parsed_array:
		var var_res = SexpVariableData.new()
		var_res.variable_name = var_dict.get("name", "")
		var_res.text = var_dict.get("value", "") # Store value as text initially
		var_res.type = var_dict.get("type", SexpConstants.SEXP_VARIABLE_NUMBER) # Default to number? Check FS2 default
		# TODO: Parse persistence flags if the parser provides them
		resources.append(var_res)
	return resources

# Helper function to convert parsed player start dictionaries to resources
func _create_player_start_resources(parsed_array: Array) -> Array[PlayerStartData]:
	var resources: Array[PlayerStartData] = []
	for player_start_dict in parsed_array:
		var player_start_res = PlayerStartData.new()

		# Process Ship Choices
		var ship_choices_parsed = player_start_dict.get("ship_choices", [])
		for choice_dict in ship_choices_parsed:
			var ship_name = choice_dict.get("item_name", "")
			var ship_var_name = choice_dict.get("item_variable", "")
			var count = choice_dict.get("count", 0)
			var count_var_name = choice_dict.get("count_variable", "")

			# Store names for now, resolve indices later if needed or at runtime
			player_start_res.ship_choice_names.append(ship_name)
			player_start_res.ship_choice_variable_names.append(ship_var_name)
			player_start_res.ship_counts.append(count)
			player_start_res.ship_count_variable_names.append(count_var_name)

		# Set Default Ship Name
		player_start_res.default_ship_name = player_start_dict.get("default_ship_name", "")

		# Process Weapon Pool
		var weapon_pool_parsed = player_start_dict.get("weapon_pool", [])
		for choice_dict in weapon_pool_parsed:
			var weapon_name = choice_dict.get("item_name", "")
			var weapon_var_name = choice_dict.get("item_variable", "")
			var count = choice_dict.get("count", 0)
			var count_var_name = choice_dict.get("count_variable", "")

			player_start_res.weapon_pool_names.append(weapon_name)
			player_start_res.weapon_pool_variable_names.append(weapon_var_name)
			player_start_res.weapon_counts.append(count)
			player_start_res.weapon_count_variable_names.append(count_var_name)

		resources.append(player_start_res)

	return resources

# Helper function to convert parsed cutscene dictionaries to resources
func _create_cutscene_resources(parsed_array: Array) -> Array[MissionCutsceneData]:
	var resources: Array[MissionCutsceneData] = []
	for cutscene_dict in parsed_array:
		var cutscene_res = MissionCutsceneData.new()
		cutscene_res.type = cutscene_dict.get("type", MissionCutsceneData.CutsceneType.PRE_GAME)
		cutscene_res.cutscene_filename = cutscene_dict.get("filename", "")
		cutscene_res.is_campaign_only = cutscene_dict.get("campaign_only", false)
		cutscene_res.formula_sexp = cutscene_dict.get("formula_sexp", null) # Assumes parser returns SexpNode
		resources.append(cutscene_res)
	return resources

# Helper function to convert parsed waypoint list dictionary to resource
func _create_waypoint_list_resource(parsed_data: Dictionary) -> WaypointListData:
	var wpl = WaypointListData.new()
	wpl.name = parsed_data.get("name", "")
	wpl.waypoints = parsed_data.get("waypoints", PackedVector3Array())
	return wpl

# Helper function to convert parsed jump node dictionary to resource
func _create_jump_node_resource(parsed_data: Dictionary) -> JumpNodeData:
	var jn = JumpNodeData.new()
	jn.name = parsed_data.get("name", "")
	jn.position = parsed_data.get("position", Vector3.ZERO)
	jn.model_filename = parsed_data.get("model_filename", "")
	jn.alpha_color = parsed_data.get("alpha_color", Color(1,1,1,1))
	jn.is_hidden = parsed_data.get("is_hidden", false)
	return jn

# Helper function to convert parsed message dictionary to resource
func _create_message_resource(parsed_data: Dictionary) -> MessageData:
	var msg = MessageData.new()
	msg.name = parsed_data.get("name", "")
	msg.message_text = parsed_data.get("message_text", "")
	msg.persona_name = parsed_data.get("persona_name", "") # Store name, resolve later
	msg.avi_filename = parsed_data.get("avi_filename", "")
	msg.wave_filename = parsed_data.get("wave_filename", "")
	msg.multi_team = parsed_data.get("multi_team", -1)
	return msg

# Helper function to convert parsed reinforcement dictionary to resource
func _create_reinforcement_resource(parsed_data: Dictionary) -> ReinforcementData:
	var rf = ReinforcementData.new()
	rf.name = parsed_data.get("name", "")
	rf.type = parsed_data.get("type", "") # Store type name
	rf.uses = parsed_data.get("uses", 0)
	rf.arrival_delay = parsed_data.get("arrival_delay", 0)
	rf.no_messages = parsed_data.get("no_messages", PackedStringArray())
	rf.yes_messages = parsed_data.get("yes_messages", PackedStringArray())
	return rf

# Helper function to convert parsed texture replacement dictionary to resource
func _create_texture_replacement_resource(parsed_data: Dictionary) -> TextureReplacementData:
	var tr = TextureReplacementData.new()
	tr.ship_name = parsed_data.get("ship_name", "")
	tr.old_texture_name = parsed_data.get("old_texture", "")
	tr.new_texture_name = parsed_data.get("new_texture", "")
	return tr

# Helper to find the index of a SEXP variable by name
# This needs access to the parsed variables from the #Variables section
func _find_sexp_variable_index(var_name: String) -> int:
	if var_name.is_empty():
		return -1
	if current_mission_data == null or not current_mission_data.has("variables"):
		#print("Warning: MissionData or variables array not available for SEXP variable lookup.")
		return -1 # Cannot lookup yet

	for i in range(current_mission_data.variables.size()):
		if current_mission_data.variables[i].variable_name == var_name:
			return i

	#print(f"Warning: SEXP variable '{var_name}' not found in mission variables.")
	return -1


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
