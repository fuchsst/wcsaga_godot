#!/usr/bin/env python3
"""
AI Profiles Table Converter

Single Responsibility: AI profile definitions parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class AIProfilesTableConverter(BaseTableConverter):
    """Converts WCS ai_profiles.tbl files to Godot AI profile resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for ai_profiles.tbl parsing"""
        return {
            'profile_name': re.compile(r'^\$Profile Name:\s*(.+)$', re.IGNORECASE),
            'difficulty_scale': re.compile(r'^\$(.+):\s*([\d\.\s,]+)$', re.IGNORECASE),
            'boolean_flag': re.compile(r'^\$(.+):\s*(YES|NO)$', re.IGNORECASE),
            'section_end': re.compile(r'^#End$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.AI_PROFILES

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire ai_profiles.tbl file."""
        entries = []
        # Skip to the start of AI profile definitions
        while state.has_more_lines():
            line = state.peek_line()
            if line and '#AI Profiles' in line:
                state.skip_line()
                break
            state.skip_line()

        while state.has_more_lines():
            line = state.peek_line()
            if not line or self._should_skip_line(line, state):
                state.skip_line()
                continue
            
            if self._parse_patterns['profile_name'].match(line.strip()):
                entry = self.parse_entry(state)
                if entry:
                    entries.append(entry)
            elif self._parse_patterns['section_end'].match(line.strip()):
                break
            else:
                state.skip_line()
        return entries

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single AI profile entry."""
        entry_data: Dict[str, Any] = {'difficulty_scales': {}, 'flags': {}}

        while state.has_more_lines():
            line = state.next_line()
            if line is None:
                break
            
            line = line.strip()
            if not line:
                continue

            if self._parse_patterns['profile_name'].match(line) and 'name' in entry_data:
                state.current_line -= 1
                break
            
            if self._parse_patterns['section_end'].match(line):
                state.current_line -=1
                break

            match = self._parse_patterns['profile_name'].match(line)
            if match:
                entry_data['name'] = match.group(1).strip()
                continue

            match = self._parse_patterns['boolean_flag'].match(line)
            if match:
                key, value = match.groups()
                entry_data['flags'][key.strip()] = value.upper() == 'YES'
                continue

            match = self._parse_patterns['difficulty_scale'].match(line)
            if match:
                key, values = match.groups()
                entry_data['difficulty_scales'][key.strip()] = [float(v.strip()) for v in values.split(',')]
                continue

        return self.validate_entry(entry_data) and entry_data or None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed AI profile entry."""
        return 'name' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed AI profile entries to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSAIProfileDatabase',
            'profiles': {entry['name']: self._convert_profile_entry(entry) for entry in entries},
            'profile_count': len(entries)
        }

    def _convert_profile_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single AI profile entry to the target Godot format."""
        return {
            'name': entry.get('name'),
            'difficulty_scales': entry.get('difficulty_scales'),
            'flags': entry.get('flags'),
        }
