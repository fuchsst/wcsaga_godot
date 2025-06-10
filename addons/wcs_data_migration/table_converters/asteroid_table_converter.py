#!/usr/bin/env python3
"""
Asteroid Table Converter

Single Responsibility: Asteroid and debris definitions parsing and conversion only.
"""

import re
from typing import Dict, List, Optional, Any

from .base_table_converter import BaseTableConverter, ParseState, TableType

class AsteroidTableConverter(BaseTableConverter):
    """Converts WCS asteroid.tbl files to Godot asteroid resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for asteroid.tbl parsing"""
        return {
            'name': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'pof_file1': re.compile(r'^\$POF file1:\s*(.+)$', re.IGNORECASE),
            'pof_file2': re.compile(r'^\$POF file2:\s*(.+)$', re.IGNORECASE),
            'pof_file3': re.compile(r'^\$POF file3:\s*(.+)$', re.IGNORECASE),
            'detail_distance': re.compile(r'^\$Detail distance:\s*\(([\d\s,]+)\)$', re.IGNORECASE),
            'max_speed': re.compile(r'^\$Max Speed:\s*([\d\.]+)$', re.IGNORECASE),
            'expl_inner_rad': re.compile(r'^\$Expl inner rad:\s*([\d\.]+)$', re.IGNORECASE),
            'expl_outer_rad': re.compile(r'^\$Expl outer rad:\s*([\d\.]+)$', re.IGNORECASE),
            'expl_damage': re.compile(r'^\$Expl damage:\s*([\d\.]+)$', re.IGNORECASE),
            'expl_blast': re.compile(r'^\$Expl blast:\s*([\d\.]+)$', re.IGNORECASE),
            'hitpoints': re.compile(r'^\$Hitpoints:\s*(\d+)', re.IGNORECASE),
            'impact_explosion': re.compile(r'^\$Impact Explosion:\s*(.+)$', re.IGNORECASE),
            'impact_explosion_radius': re.compile(r'^\$Impact Explosion Radius:\s*([\d\.]+)$', re.IGNORECASE),
            'section_end': re.compile(r'^#End$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.ASTEROID

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire asteroid.tbl file."""
        entries = []
        # Skip to the start of asteroid definitions
        while state.has_more_lines():
            line = state.peek_line()
            if line and '#Asteroid Types' in line:
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
        
        # Parse impact explosion data
        impact_data = self.parse_impact_data(state)
        if impact_data:
            entries.append(impact_data)

        return entries

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single asteroid entry."""
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

            for key, pattern in self._init_parse_patterns().items():
                match = pattern.match(line)
                if match:
                    if key == 'detail_distance':
                        entry_data[key] = [int(d.strip()) for d in match.group(1).split(',')]
                    elif key in ['max_speed', 'expl_inner_rad', 'expl_outer_rad', 'expl_damage', 'expl_blast', 'impact_explosion_radius']:
                        entry_data[key] = float(match.group(1))
                    elif key == 'hitpoints':
                        entry_data[key] = int(match.group(1))
                    elif key != 'name':
                         entry_data[key] = match.group(1).strip()
                    else:
                        entry_data['name'] = match.group(1).strip()
                    break
        
        entry_data['type'] = 'asteroid'
        return self.validate_entry(entry_data) and entry_data or None

    def parse_impact_data(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse the impact explosion data at the end of the file."""
        impact_data = {}
        while state.has_more_lines():
            line = state.next_line()
            if line is None:
                break
            line = line.strip()
            if not line or self._should_skip_line(line, state):
                continue

            match = self._parse_patterns['impact_explosion'].match(line)
            if match:
                impact_data['impact_explosion'] = match.group(1).strip()
                continue

            match = self._parse_patterns['impact_explosion_radius'].match(line)
            if match:
                impact_data['impact_explosion_radius'] = float(match.group(1))
                continue
        
        if impact_data:
            impact_data['type'] = 'impact_data'
            impact_data['name'] = 'impact_data'
        return impact_data if impact_data else None


    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed asteroid entry."""
        return 'name' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed asteroid entries to a Godot resource dictionary."""
        asteroids = [e for e in entries if e.get('type') == 'asteroid']
        impact_data = next((e for e in entries if e.get('type') == 'impact_data'), None)

        return {
            'resource_type': 'WCSAsteroidDatabase',
            'asteroids': {a['name']: self._convert_asteroid_entry(a) for a in asteroids},
            'impact_data': self._convert_impact_data(impact_data) if impact_data else {},
        }

    def _convert_asteroid_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single asteroid entry to the target Godot format."""
        return entry

    def _convert_impact_data(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert the impact data to the target Godot format."""
        return entry
