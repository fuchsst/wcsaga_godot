#!/usr/bin/env python3
"""
IFF Table Converter

Single Responsibility: IFF (Identification Friend or Foe) definitions parsing only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class IFFTableConverter(BaseTableConverter):
    """Converts WCS iff_defs.tbl files to Godot IFF resources"""
    
    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        return {
            'iff_start': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE)
        }
    
    def get_table_type(self) -> TableType:
        return TableType.IFF
    
    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        return None
    
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        return True
    
    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        return {'resource_type': 'WCSIFFDatabase', 'iff_data': {}}