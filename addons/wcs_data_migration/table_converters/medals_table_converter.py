#!/usr/bin/env python3
"""
Medals Table Converter

Single Responsibility: Medal definitions parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class MedalsTableConverter(BaseTableConverter):
    """Converts WCS medals.tbl files to Godot medal resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for medals.tbl parsing"""
        return {
            'name': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'bitmap': re.compile(r'^\$Bitmap:\s*(.+)$', re.IGNORECASE),
            'num_levels': re.compile(r'^\$Num Levels:\s*(\d+)$', re.IGNORECASE),
            'section_end': re.compile(r'^#End$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.MEDALS

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire medals.tbl file."""
        entries = []
        while state.has_more_lines():
            line = state.peek_line()
            if not line or self._should_skip_line(line, state):
                state.skip_line()
                continue
            
            if self._parse_patterns['name'].match(line.strip()):
                entry = self.parse_entry(state)
                if entry:
                    entries.append(entry)
            elif self._parse_patterns['section_end'].match(line.strip()):
                break
            else:
                state.skip_line()
        return entries

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single medal entry."""
        entry_data = {}

        while state.has_more_lines():
            line = state.next_line()
            if line is None:
                break
            
            line = line.strip()
            if not line:
                continue

            if self._parse_patterns['name'].match(line) and 'name' in entry_data:
                state.current_line -= 1
                break
            
            if self._parse_patterns['section_end'].match(line):
                state.current_line -=1
                break

            match = self._parse_patterns['name'].match(line)
            if match:
                entry_data['name'] = match.group(1).strip()
                continue

            match = self._parse_patterns['bitmap'].match(line)
            if match:
                entry_data['bitmap'] = match.group(1).strip()
                continue

            match = self._parse_patterns['num_levels'].match(line)
            if match:
                entry_data['num_levels'] = int(match.group(1))
                continue

        return self.validate_entry(entry_data) and entry_data or None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed medal entry."""
        return 'name' in entry and 'bitmap' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed medal entries to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSMedalDatabase',
            'medals': {entry['name']: self._convert_medal_entry(entry) for entry in entries},
            'medal_count': len(entries)
        }

    def _convert_medal_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single medal entry to the target Godot format."""
        return {
            'name': entry.get('name'),
            'bitmap': entry.get('bitmap'),
            'num_levels': entry.get('num_levels', 1),
        }
