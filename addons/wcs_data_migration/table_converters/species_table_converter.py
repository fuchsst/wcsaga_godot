#!/usr/bin/env python3
"""
Species Table Converter

Single Responsibility: Species definitions parsing and conversion only.
"""

import re
from typing import Dict, List, Optional, Any
from .base_table_converter import BaseTableConverter, ParseState, TableType

class SpeciesTableConverter(BaseTableConverter):
    """Converts WCS species_defs.tbl files to Godot species resources"""
    
    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        return {
            'species_start': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE)
        }
    
    def get_table_type(self) -> TableType:
        return TableType.SPECIES
    
    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        return None
    
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        return True
    
    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        return {'resource_type': 'WCSSpeciesDatabase', 'species': {}}