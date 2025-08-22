"""
Table Converters Package

Modular table conversion system following SOLID principles.
Each table type (ships, weapons, armor, etc.) has its own focused converter.
"""

from .ai_profiles_table_converter import AIProfilesTableConverter
from .armor_table_converter import ArmorTableConverter
from .asteroid_table_converter import AsteroidTableConverter
from .base_table_converter import (BaseTableConverter, ParseError, ParseState,
                                   TableType)
from .cutscenes_table_converter import CutscenesTableConverter
from .iff_table_converter import IFFTableConverter
from .lightning_table_converter import LightningTableConverter
from .medals_table_converter import MedalsTableConverter
from .music_table_converter import MusicTableConverter
from .rank_table_converter import RankTableConverter
from .scripting_table_converter import ScriptingTableConverter
from .ship_table_converter import ShipTableConverter
from .species_defs_table_converter import SpeciesDefsTableConverter
from .species_table_converter import SpeciesTableConverter
from .stars_table_converter import StarsTableConverter
from .weapon_table_converter import WeaponTableConverter

__all__ = [
    'AIProfilesTableConverter',
    'ArmorTableConverter',
    'AsteroidTableConverter',
    'BaseTableConverter',
    'CutscenesTableConverter',
    'IFFTableConverter',
    'LightningTableConverter',
    'MedalsTableConverter',
    'MusicTableConverter',
    'ParseError',
    'ParseState',
    'RankTableConverter',
    'ScriptingTableConverter',
    'ShipTableConverter',
    'SpeciesDefsTableConverter',
    'SpeciesTableConverter',
    'StarsTableConverter',
    'TableType',
    'WeaponTableConverter',
]
