#!/usr/bin/env python3
"""
Species Table Converter

Single Responsibility: Species and intel definitions parsing and conversion only.
Handles Species.tbl files for in-game encyclopedia entries.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class SpeciesTableConverter(BaseTableConverter):
    """Converts WCS Species.tbl files to Godot intel database resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for Species.tbl parsing"""
        return {
            'entry_start': re.compile(r'^\$Entry:$', re.IGNORECASE),
            'name': re.compile(r'^\$Name:\s*XSTR\("([^"]+)",-1\)$', re.IGNORECASE),
            'anim': re.compile(r'^\$Anim:\s*(.+)$', re.IGNORECASE),
            'tech_room': re.compile(r'^\$AlwaysInTechRoom:\s*(\d+)$', re.IGNORECASE),
            'description_start': re.compile(r'^\$Description:$', re.IGNORECASE),
            'description_line': re.compile(r'^XSTR\("(.+)",\s*-1\)$', re.IGNORECASE),
            'description_end': re.compile(r'^\$end_multi_text$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.SPECIES_ENTRIES

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire Species.tbl file."""
        entries = []
        while state.has_more_lines():
            line = state.peek_line()
            if not line or self._should_skip_line(line, state):
                state.skip_line()
                continue
            
            if self._parse_patterns['entry_start'].match(line.strip()):
                entry = self.parse_entry(state)
                if entry:
                    entries.append(entry)
            else:
                state.skip_line()
        return entries

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single intel entry from the table."""
        entry_data = {}
        in_description = False
        description_lines = []

        # Consume the $Entry: line
        state.next_line()

        while state.has_more_lines():
            line = state.next_line()
            if not line:
                continue
            
            line = line.strip()
            if not line or self._should_skip_line(line, state):
                continue

            if self._parse_patterns['entry_start'].match(line):
                # We've hit the next entry, so we're done with the current one.
                # We need to put the line back for the next call to parse_entry.
                state.current_line -= 1
                break

            if in_description:
                if self._parse_patterns['description_end'].match(line):
                    in_description = False
                    entry_data['description'] = "\n".join(description_lines)
                    # This is the end of an entry
                    return self.validate_entry(entry_data) and entry_data or None
                else:
                    match = self._parse_patterns['description_line'].match(line)
                    if match:
                        description_lines.append(match.group(1))
                continue

            match = self._parse_patterns['name'].match(line)
            if match:
                entry_data['name'] = match.group(1).strip()
                continue

            match = self._parse_patterns['anim'].match(line)
            if match:
                entry_data['anim'] = match.group(1).strip()
                continue

            match = self._parse_patterns['tech_room'].match(line)
            if match:
                entry_data['always_in_tech_room'] = bool(int(match.group(1)))
                continue

            if self._parse_patterns['description_start'].match(line):
                in_description = True
                continue

        if description_lines:
            entry_data['description'] = "\n".join(description_lines)

        return self.validate_entry(entry_data) and entry_data or None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed intel entry."""
        return 'name' in entry and 'description' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed intel entries to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSIntelDatabase',
            'entries': {entry['name']: self._convert_intel_entry(entry) for entry in entries},
            'entry_count': len(entries)
        }

    def _convert_intel_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single intel entry to the target Godot format."""
        return {
            'name': entry.get('name'),
            'anim': entry.get('anim'),
            'always_in_tech_room': entry.get('always_in_tech_room', False),
            'description': entry.get('description'),
        }
