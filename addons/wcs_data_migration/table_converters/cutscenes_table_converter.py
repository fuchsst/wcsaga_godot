#!/usr/bin/env python3
"""
Cutscenes Table Converter

Single Responsibility: Cutscene definitions parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class CutscenesTableConverter(BaseTableConverter):
    """Converts WCS cutscenes.tbl files to Godot cutscene resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for cutscenes.tbl parsing"""
        return {
            'filename': re.compile(r'^\$Filename:\s*(.+)$', re.IGNORECASE),
            'name': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'description_start': re.compile(r'^\$Description:$', re.IGNORECASE),
            'description_line': re.compile(r'^XSTR\("(.+)",\s*-1\)$', re.IGNORECASE),
            'description_end': re.compile(r'^\$end_multi_text$', re.IGNORECASE),
            'cd': re.compile(r'^\$cd:\s*(\d+)$', re.IGNORECASE),
            'section_end': re.compile(r'^#End$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.CUTSCENES

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire cutscenes.tbl file."""
        entries = []
        # Skip to the start of cutscene definitions
        while state.has_more_lines():
            line = state.peek_line()
            if line and '#Cutscenes' in line:
                state.skip_line()
                break
            state.skip_line()

        while state.has_more_lines():
            line = state.peek_line()
            if not line or self._should_skip_line(line, state):
                state.skip_line()
                continue
            
            if self._parse_patterns['filename'].match(line.strip()):
                entry = self.parse_entry(state)
                if entry:
                    entries.append(entry)
            elif self._parse_patterns['section_end'].match(line.strip()):
                break
            else:
                state.skip_line()
        return entries

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single cutscene entry."""
        entry_data = {}
        in_description = False
        description_lines = []

        while state.has_more_lines():
            line = state.next_line()
            if line is None:
                break
            
            line = line.strip()
            if not line:
                continue

            if self._parse_patterns['filename'].match(line) and 'filename' in entry_data:
                state.current_line -= 1
                break
            
            if self._parse_patterns['section_end'].match(line):
                state.current_line -=1
                break

            if in_description:
                if self._parse_patterns['description_end'].match(line):
                    in_description = False
                    entry_data['description'] = "\n".join(description_lines)
                else:
                    match = self._parse_patterns['description_line'].match(line)
                    if match:
                        description_lines.append(match.group(1))
                continue

            match = self._parse_patterns['filename'].match(line)
            if match:
                entry_data['filename'] = match.group(1).strip()
                continue

            match = self._parse_patterns['name'].match(line)
            if match:
                entry_data['name'] = match.group(1).strip()
                continue

            match = self._parse_patterns['cd'].match(line)
            if match:
                entry_data['cd'] = int(match.group(1))
                continue

            if self._parse_patterns['description_start'].match(line):
                in_description = True
                continue

        if description_lines:
            entry_data['description'] = "\n".join(description_lines)

        return self.validate_entry(entry_data) and entry_data or None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed cutscene entry."""
        return 'filename' in entry and 'name' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed cutscene entries to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSCutsceneDatabase',
            'cutscenes': {entry['name']: self._convert_cutscene_entry(entry) for entry in entries},
            'cutscene_count': len(entries)
        }

    def _convert_cutscene_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single cutscene entry to the target Godot format."""
        return {
            'name': entry.get('name'),
            'filename': entry.get('filename'),
            'description': entry.get('description'),
            'cd': entry.get('cd'),
        }
