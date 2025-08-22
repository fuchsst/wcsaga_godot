#!/usr/bin/env python3
"""
Species Definitions Table Converter

Single Responsibility: Species definitions parsing and conversion only.
Handles Species_defs.tbl files for species properties.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class SpeciesDefsTableConverter(BaseTableConverter):
    """Converts WCS Species_defs.tbl files to Godot species definition resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for Species_defs.tbl parsing"""
        return {
            'species_start': re.compile(r'^\$Species_Name:\s*(.+)$', re.IGNORECASE),
            'default_iff': re.compile(r'^\$Default IFF:\s*(.+)$', re.IGNORECASE),
            'fred_color': re.compile(r'^\$FRED Color:\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$', re.IGNORECASE),
            'debris_texture': re.compile(r'^\+Debris_Texture:\s*(.+)$', re.IGNORECASE),
            'shield_hit_ani': re.compile(r'^\+Shield_Hit_ani:\s*(.+)$', re.IGNORECASE),
            'thrust_anim': re.compile(r'^\+(Pri|Sec|Ter)_(Normal|Afterburn):\s*(.+)$', re.IGNORECASE),
            'thrust_glow': re.compile(r'^\+(Normal|Afterburn):\s*(.+)$', re.IGNORECASE),
            'awacs_multiplier': re.compile(r'^\$AwacsMultiplier:\s*([\d\.]+)$', re.IGNORECASE),
            'section_end': re.compile(r'^#END$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.SPECIES

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire Species_defs.tbl file."""
        entries = []
        # Skip to the start of species definitions
        while state.has_more_lines():
            line = state.peek_line()
            if line and '$NumSpecies:' in line:
                state.skip_line()
                break
            state.skip_line()

        while state.has_more_lines():
            line = state.peek_line()
            if not line or self._should_skip_line(line, state):
                state.skip_line()
                continue
            
            if self._parse_patterns['species_start'].match(line.strip()):
                entry = self.parse_entry(state)
                if entry:
                    entries.append(entry)
            else:
                state.skip_line()
        return entries

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single species definition entry."""
        entry_data: Dict[str, Any] = {'thrust_anims': {}, 'thrust_glows': {}}
        
        while state.has_more_lines():
            line = state.next_line()
            if not line:
                continue
            
            line = line.strip()
            if not line or self._should_skip_line(line, state):
                continue

            if self._parse_patterns['section_end'].match(line):
                break
            
            if self._parse_patterns['species_start'].match(line) and 'name' in entry_data:
                 state.current_line -= 1
                 break

            match = self._parse_patterns['species_start'].match(line)
            if match:
                entry_data['name'] = match.group(1).strip()
                continue

            match = self._parse_patterns['default_iff'].match(line)
            if match:
                entry_data['default_iff'] = match.group(1).strip()
                continue

            match = self._parse_patterns['fred_color'].match(line)
            if match:
                entry_data['fred_color'] = [int(c) for c in match.groups()]
                continue

            match = self._parse_patterns['debris_texture'].match(line)
            if match:
                entry_data['debris_texture'] = match.group(1).strip()
                continue

            match = self._parse_patterns['shield_hit_ani'].match(line)
            if match:
                entry_data['shield_hit_ani'] = match.group(1).strip()
                continue

            match = self._parse_patterns['thrust_anim'].match(line)
            if match:
                anim_type, anim_state, anim_name = match.groups()
                entry_data['thrust_anims'][f"{anim_type.lower()}_{anim_state.lower()}"] = anim_name.strip()
                continue

            match = self._parse_patterns['thrust_glow'].match(line)
            if match:
                glow_state, glow_name = match.groups()
                entry_data['thrust_glows'][glow_state.lower()] = glow_name.strip()
                continue

            match = self._parse_patterns['awacs_multiplier'].match(line)
            if match:
                entry_data['awacs_multiplier'] = float(match.group(1))
                continue

        return self.validate_entry(entry_data) and entry_data or None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed species definition entry."""
        return 'name' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed species definitions to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSSpeciesDefsDatabase',
            'species': {entry['name']: self._convert_species_entry(entry) for entry in entries},
            'species_count': len(entries)
        }

    def _convert_species_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single species definition entry to the target Godot format."""
        return {
            'name': entry.get('name'),
            'default_iff': entry.get('default_iff'),
            'fred_color': entry.get('fred_color'),
            'debris_texture': entry.get('debris_texture'),
            'shield_hit_ani': entry.get('shield_hit_ani'),
            'thrust_anims': entry.get('thrust_anims'),
            'thrust_glows': entry.get('thrust_glows'),
            'awacs_multiplier': entry.get('awacs_multiplier'),
        }
