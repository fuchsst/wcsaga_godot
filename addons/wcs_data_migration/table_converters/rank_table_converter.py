#!/usr/bin/env python3
"""
Rank Table Converter

Single Responsibility: Player rank definitions parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class RankTableConverter(BaseTableConverter):
    """Converts WCS rank.tbl files to Godot rank resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for rank.tbl parsing"""
        return {
            'name': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'points': re.compile(r'^\$Points:\s*(\d+)$', re.IGNORECASE),
            'bitmap': re.compile(r'^\$Bitmap:\s*(.+)$', re.IGNORECASE),
            'promo_voice': re.compile(r'^\$Promotion Voice Base:\s*(.+)$', re.IGNORECASE),
            'promo_text_start': re.compile(r'^\$Promotion Text:$', re.IGNORECASE),
            'promo_text_line': re.compile(r'^XSTR\("(.+)",\s*-1\)$', re.IGNORECASE),
            'promo_text_end': re.compile(r'^\$end_multi_text$', re.IGNORECASE),
            'section_end': re.compile(r'^#End$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.RANK

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire rank.tbl file."""
        entries = []
        # Skip to the start of rank definitions
        while state.has_more_lines():
            line = state.peek_line()
            if line and '[RANK NAMES]' in line:
                state.skip_line()
                break
            state.skip_line()

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
        """Parse a single rank entry."""
        entry_data = {}
        in_promo_text = False
        promo_text_lines = []

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

            if in_promo_text:
                if self._parse_patterns['promo_text_end'].match(line):
                    in_promo_text = False
                    entry_data['promo_text'] = "\n".join(promo_text_lines)
                else:
                    match = self._parse_patterns['promo_text_line'].match(line)
                    if match:
                        promo_text_lines.append(match.group(1))
                continue

            match = self._parse_patterns['name'].match(line)
            if match:
                entry_data['name'] = match.group(1).strip()
                continue

            match = self._parse_patterns['points'].match(line)
            if match:
                entry_data['points'] = int(match.group(1))
                continue

            match = self._parse_patterns['bitmap'].match(line)
            if match:
                entry_data['bitmap'] = match.group(1).strip()
                continue

            match = self._parse_patterns['promo_voice'].match(line)
            if match:
                entry_data['promo_voice'] = match.group(1).strip()
                continue

            if self._parse_patterns['promo_text_start'].match(line):
                in_promo_text = True
                continue

        if promo_text_lines:
            entry_data['promo_text'] = "\n".join(promo_text_lines)

        return self.validate_entry(entry_data) and entry_data or None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed rank entry."""
        return 'name' in entry and 'points' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed rank entries to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSRankDatabase',
            'ranks': {entry['name']: self._convert_rank_entry(entry) for entry in entries},
            'rank_count': len(entries)
        }

    def _convert_rank_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single rank entry to the target Godot format."""
        return {
            'name': entry.get('name'),
            'points': entry.get('points'),
            'bitmap': entry.get('bitmap'),
            'promo_voice': entry.get('promo_voice'),
            'promo_text': entry.get('promo_text'),
        }
