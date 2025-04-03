# migration_tools/gdscript_converters/fs2_parsers/parser_factory.gd
# Factory class to create the appropriate parser based on the FS2 section name.
class_name ParserFactory
extends RefCounted

# --- Preload all specific parser scripts ---
const MissionInfoParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/mission_info_parser.gd")
const ObjectsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/objects_parser.gd")
const WingsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/wings_parser.gd")
const EventsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/events_parser.gd")
const GoalsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/goals_parser.gd")
const WaypointsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/waypoints_parser.gd")
const MessagesParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/messages_parser.gd")
const ReinforcementsParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/reinforcements_parser.gd")
const BackgroundParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/background_parser.gd")
const AsteroidParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/asteroid_parser.gd")
const BriefingParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/briefing_parser.gd")
const DebriefingParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/debriefing_parser.gd")
const VariablesParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/variables_parser.gd")
const MusicParser = preload("res://migration_tools/gdscript_converters/fs2_parsers/music_parser.gd")
# TODO: Add preloads for other parsers as they are created (Players, Cutscenes, etc.)


# --- Mapping from section names to parser classes ---
# Note: Keys should match the section names *after* normalization (lowercase, no '#')
const PARSER_MAP: Dictionary = {
	"mission_info": MissionInfoParser,
	"objects": ObjectsParser,
	"wings": WingsParser,
	"events": EventsParser,
	"goals": GoalsParser,
	"waypoints": WaypointsParser,
	"messages": MessagesParser,
	"reinforcements": ReinforcementsParser,
	"background_bitmaps": BackgroundParser,
	"asteroid_fields": AsteroidParser,
	"briefing": BriefingParser, # Assumes main converter handles multiple team briefings
	"debriefing_info": DebriefingParser, # Assumes main converter handles multiple team debriefings
	"sexp_variables": VariablesParser, # Maps #Variables to sexp_variables
	"music": MusicParser,
	# TODO: Add mappings for other sections
	# "players": PlayersParser,
	# "cutscenes": CutscenesParser,
	# "command_briefing": CommandBriefingParser,
	# ... etc ...
}

# --- Factory Method ---
static func create_parser(normalized_section_name: String): # -> BaseFS2Parser (or Variant if base class not used yet)
	"""
	Creates and returns an instance of the appropriate parser for the given section name.

	Args:
		normalized_section_name: The section name (lowercase, no '#', spaces replaced with '_').

	Returns:
		An instance of the parser class, or null if no parser is found.
	"""
	if normalized_section_name in PARSER_MAP:
		var ParserClass = PARSER_MAP[normalized_section_name]
		if ParserClass:
			# Check if it's a script path to preload or already a class reference
			if ParserClass is GDScript:
				# If it's a script, instantiate it
				return ParserClass.new()
			elif typeof(ParserClass) == TYPE_OBJECT and ParserClass.has_method("new"):
				# If it's already a class reference (like from preload)
				return ParserClass.new()
			else:
				printerr(f"Error: Invalid parser class definition for section '{normalized_section_name}' in PARSER_MAP.")
				return null
		else:
			printerr(f"Error: Null parser class found for section '{normalized_section_name}' in PARSER_MAP.")
			return null
	else:
		#print(f"Warning: No specific parser found for section '{normalized_section_name}'.")
		return null # Return null if no parser is defined for this section
