#!/usr/bin/env python3
"""
Scripting Table Converter

Single Responsibility: Lua script parsing from scripting.tbl.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class ScriptingTableConverter(BaseTableConverter):
    """Converts WCS scripting.tbl files to Godot script resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for scripting.tbl parsing"""
        return {
            'hook_start': re.compile(r'^\$(\w+):\s*$', re.IGNORECASE),
            'script_start': re.compile(r'^\[\s*$', re.IGNORECASE),
            'script_end': re.compile(r'^\]\s*$', re.IGNORECASE),
            'section_end': re.compile(r'^#End$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.SCRIPTING

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire scripting.tbl file."""
        entries = []
        while state.has_more_lines():
            line = state.peek_line()
            if not line or self._should_skip_line(line, state):
                state.skip_line()
                continue
            
            if self._parse_patterns['hook_start'].match(line.strip()):
                entry = self.parse_entry(state)
                if entry:
                    entries.append(entry)
            else:
                state.skip_line()
        return entries

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single script hook entry."""
        entry_data = {}
        
        line = state.next_line()
        if line is None:
            return None
        line = line.strip()
        match = self._parse_patterns['hook_start'].match(line)
        if not match:
            return None
        
        entry_data['hook'] = match.group(1)
        
        # Find script block
        script_lines = []
        in_script = False
        while state.has_more_lines():
            line = state.next_line()
            if line is None:
                break
            
            line_strip = line.strip()

            if self._parse_patterns['script_start'].match(line_strip):
                in_script = True
                continue
            
            if self._parse_patterns['script_end'].match(line_strip):
                in_script = False
                break

            if in_script:
                script_lines.append(line)

        entry_data['script'] = "".join(script_lines)
        
        return self.validate_entry(entry_data) and entry_data or None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed script hook entry."""
        return 'hook' in entry and 'script' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed script hooks to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSScriptingDatabase',
            'hooks': {entry['hook']: entry['script'] for entry in entries},
            'hook_count': len(entries)
        }
