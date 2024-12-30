"""FS2 file format parsers"""
from converters.fs2.parsers.reinforcements_parser import ReinforcementsParser
from .base_parser import BaseParser
from .parser_factory import ParserFactory
from .mission_parser import MissionParser
from .campaign_parser import CampaignParser
from .briefing_parser import BriefingParser
from .command_briefing_parser import CommandBriefingParser
from .events_parser import EventsParser
from .goals_parser import GoalsParser
from .flags_parser import FlagsParser
from .asteroid_parser import AsteroidParser
from .sexp_parser import SexpParser
from .fiction_parser import FictionParser
from .players_parser import PlayersParser
from .objects_parser import ObjectsParser
from .wings_parser import WingsParser
from .messages_parser import MessagesParser
from .background_parser import BackgroundParser
from .music_parser import MusicParser
from .cutscenes_parser import CutscenesParser
from .variables_parser import VariablesParser
from .callsigns_parser import CallsignsParser
from .waypoints_parser import WaypointsParser
from .debriefing_parser import DebriefingParser

# Register all parsers with the factory using exact section names
ParserFactory.register_parser('mission_info', MissionParser)
ParserFactory.register_parser('command_briefing', CommandBriefingParser)
ParserFactory.register_parser('fiction_viewer', FictionParser)
ParserFactory.register_parser('briefing', BriefingParser)
ParserFactory.register_parser('debriefing_info', DebriefingParser)
ParserFactory.register_parser('players', PlayersParser)
ParserFactory.register_parser('objects', ObjectsParser)
ParserFactory.register_parser('wings', WingsParser)
ParserFactory.register_parser('messages', MessagesParser)
ParserFactory.register_parser('events', EventsParser)
ParserFactory.register_parser('goals', GoalsParser)
ParserFactory.register_parser('waypoints', WaypointsParser)
ParserFactory.register_parser('asteroid_fields', AsteroidParser)
ParserFactory.register_parser('background_bitmaps', BackgroundParser)
ParserFactory.register_parser('music', MusicParser)
ParserFactory.register_parser('cutscenes', CutscenesParser)
ParserFactory.register_parser('sexp_variables', VariablesParser)
ParserFactory.register_parser('callsigns', CallsignsParser)
ParserFactory.register_parser('reinforcements', ReinforcementsParser)

# Utility parsers that don't correspond to sections
ParserFactory.register_parser('flags', FlagsParser)
ParserFactory.register_parser('sexp', SexpParser)

__all__ = [
    'BaseParser',
    'ParserFactory',
    'MissionParser',
    'CampaignParser', 
    'BriefingParser',
    'CommandBriefingParser',
    'EventsParser',
    'GoalsParser',
    'FlagsParser',
    'AsteroidParser',
    'SexpParser',
    'FictionParser',
    'PlayersParser',
    'ObjectsParser',
    'WingsParser',
    'MessagesParser',
    'BackgroundParser',
    'MusicParser',
    'CutscenesParser',
    'VariablesParser',
    'CallsignsParser',
    'WaypointsParser',
    'DebriefingParser',
    'ReinforcementsParser'
]
