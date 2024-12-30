"""Wing Commander Saga FS2 file format handling

This package provides tools for parsing and converting Wing Commander Saga
.fs2 campaign and mission files to JSON format.

The main components are:
- FS2Converter: Main converter class for .fs2 files
- Parsers: Collection of specialized parsers for different file sections

Example:
    >>> from converters.fs2 import FS2Converter
    >>> converter = FS2Converter()
    >>> converter.convert_file('mission.fs2', 'mission.json')

For direct access to parsers:
    >>> from converters.fs2.parsers import ParserFactory
    >>> parser = ParserFactory.create_parser('mission')
"""
from .fs2_converter import FS2Converter
from .parsers import (
    BaseParser,
    ParserFactory,
    MissionParser,
    CampaignParser,
    BriefingParser,
    EventsParser,
    GoalsParser,
    FlagsParser,
    AsteroidParser,
    SexpParser
)

__all__ = [
    'FS2Converter',
    'BaseParser',
    'ParserFactory',
    'MissionParser',
    'CampaignParser',
    'BriefingParser',
    'EventsParser',
    'GoalsParser',
    'FlagsParser',
    'AsteroidParser',
    'SexpParser'
]

# Version info
__version__ = '0.1.0'
__author__ = 'Cline'
__description__ = 'Wing Commander Saga FS2 file format converter'

# Initialize parser factory
factory = ParserFactory()
