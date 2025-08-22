#!/usr/bin/env python3
"""
Sounds Table Converter

Single Responsibility: Sound definitions parsing and conversion only.
Handles sounds.tbl files for audio system configuration, including
parsing different sections and formats, inspired by the robust parsing
logic of other converters.
"""

import re
from typing import Any, Dict, List, Optional

from core.path_resolver import TargetPathResolver

from .base_table_converter import BaseTableConverter, ParseState, TableType


class SoundsTableConverter(BaseTableConverter):
    """Converts WCS sounds.tbl files to Godot audio resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for sounds table parsing"""
        return {
            'section_start': re.compile(r'^#\s*(\w+)\s+Sounds\s+Start', re.IGNORECASE),
            'section_end': re.compile(r'^#\s*(\w+)\s+Sounds\s+End', re.IGNORECASE),
            'sound_entry': re.compile(r'^\$Name:\s*(\d+)\s+([^;]+)(?:;\s*(.*))?', re.IGNORECASE),
            'flyby_entry': re.compile(r'^\$(\w+):\s*(\d+)\s+([^;]+)(?:;\s*(.*))?', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.SOUNDS

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """
        Parse the entire sounds.tbl file, handling different sections and formats.
        """
        entries = []
        current_section = "unknown"

        while state.has_more_lines():
            line = state.next_line()
            if not line or self._should_skip_line(line, state):
                continue

            # Update current section
            start_match = self._parse_patterns['section_start'].match(line)
            if start_match:
                current_section = start_match.group(1).lower()
                self.logger.info(f"Parsing sound section: '{current_section}'")
                continue

            end_match = self._parse_patterns['section_end'].match(line)
            if end_match:
                self.logger.info(f"Finished parsing sound section: '{current_section}'")
                current_section = "unknown"
                continue

            # Parse entry based on current section
            entry = None
            if current_section == 'flyby':
                entry = self._parse_flyby_sound(line, current_section)
            elif current_section in ['game', 'interface']:
                entry = self._parse_standard_sound(line, current_section)
            
            if entry and self.validate_entry(entry):
                entries.append(entry)
        
        return entries

    def _parse_standard_sound(self, line: str, section: str) -> Optional[Dict[str, Any]]:
        """Parse a standard game or interface sound line."""
        match = self._parse_patterns['sound_entry'].match(line)
        if not match:
            return None
        
        sound_id, params_str, comment = match.groups()
        unique_name = f"{section}_{sound_id}"
        
        return self._create_sound_data(unique_name, params_str, comment)

    def _parse_flyby_sound(self, line: str, section: str) -> Optional[Dict[str, Any]]:
        """Parse a flyby sound line with faction information."""
        match = self._parse_patterns['flyby_entry'].match(line)
        if not match:
            return None
            
        faction, sound_id, params_str, comment = match.groups()
        unique_name = f"{section}_{faction.lower()}_{sound_id}"
        
        return self._create_sound_data(unique_name, params_str, comment)

    def _create_sound_data(self, name: str, params_str: str, comment: Optional[str]) -> Optional[Dict[str, Any]]:
        """Create a sound data dictionary from the parsed parameter string."""
        parts = [p.strip() for p in params_str.split(',') if p.strip()]
        if not parts or parts[0].lower() == 'none.wav':
            return None

        sound_data = {'name': name, 'filename': parts[0], 'comment': comment.strip() if comment else ''}
        
        try:
            if len(parts) > 1: sound_data['preload'] = self.parse_value(parts[1], int) > 0
            if len(parts) > 2: sound_data['default_volume'] = self.parse_value(parts[2], float)
            if len(parts) > 3: sound_data['is_3d'] = self.parse_value(parts[3], int) > 0
            if len(parts) > 4: sound_data['min_distance'] = self.parse_value(parts[4], float)
            if len(parts) > 5: sound_data['max_distance'] = self.parse_value(parts[5], float)
        except (ValueError, IndexError) as e:
            self.logger.warning(f"Could not parse all parameters for sound '{name}': {e}")

        return sound_data

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed sound entry."""
        if not entry.get('name') or not entry.get('filename'):
            return False
        
        if 'default_volume' in entry and not (0.0 <= entry['default_volume'] <= 1.0):
            self.logger.warning(f"Sound '{entry['name']}' has invalid volume: {entry['default_volume']}")
            return False
            
        return True

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed sound entries to a Godot resource dictionary."""
        return {
            'resource_type': 'WCSSoundDatabase',
            'sounds': {entry['name']: self._convert_sound_entry(entry) for entry in entries},
            'sound_count': len(entries)
        }

    def _convert_sound_entry(self, sound: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single sound entry to the target Godot format."""
        return {
            'display_name': sound.get('name', 'Unknown Sound'),
            'filename': sound.get('filename'),
            'description': sound.get('comment', ''),
            'default_volume': sound.get('default_volume', 0.8),
            'preload': sound.get('preload', False),
            'is_3d': sound.get('is_3d', False),
            'min_distance': sound.get('min_distance', 100.0),
            'max_distance': sound.get('max_distance', 1000.0),
        }

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Not used when parse_table is overridden."""
        return None
