"""
Table Converters Package

Modular table conversion system following SOLID principles.
Each table type (ships, weapons, armor, etc.) has its own focused converter.
"""

from .base_table_converter import BaseTableConverter, ParseState, ParseError, TableType
from .ship_table_converter import ShipTableConverter
from .weapon_table_converter import WeaponTableConverter
from .armor_table_converter import ArmorTableConverter
from .species_table_converter import SpeciesTableConverter
from .iff_table_converter import IFFTableConverter

__all__ = [
    'BaseTableConverter',
    'ParseState', 
    'ParseError',
    'TableType',
    'ShipTableConverter',
    'WeaponTableConverter', 
    'ArmorTableConverter',
    'SpeciesTableConverter',
    'IFFTableConverter'
]