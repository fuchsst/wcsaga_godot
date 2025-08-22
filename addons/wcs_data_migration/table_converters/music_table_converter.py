#!/usr/bin/env python3
"""
Music Table Converter

Single Responsibility: Music definitions parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class MusicTableConverter(BaseTableConverter):
    """Converts WCS music.tbl files to Godot music resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for music.tbl parsing"""
        return {
            'soundtrack_start': re.compile(r'^#SoundTrack Start', re.IGNORECASE),
            'soundtrack_name': re.compile(r'^\$Soundtrack Name:\s*(.+)$', re.IGNORECASE),
            'overlay': re.compile(r'^\+Allied Arrival Overlay:\s*(YES|NO)$', re.IGNORECASE),
            'lock_ambient': re.compile(r'^\+Lock in Ambient:\s*(YES|NO)$', re.IGNORECASE),
            'music_entry': re.compile(r'^\$Name:\s*([^\s]+)\s+([\d\.]+)\s+([\d\.]+)\s*;\s*\*\s*(.+)$', re.IGNORECASE),
            'soundtrack_end': re.compile(r'^#SoundTrack End', re.IGNORECASE),
            'menu_music_start': re.compile(r'^#Menu Music Start', re.IGNORECASE),
            'menu_music_entry': re.compile(r'^\$Name:\s*(\w+)\s+\$Filename:\s*([^;]+)\s*;\s*(.+)$', re.IGNORECASE),
            'menu_music_end': re.compile(r'^#Menu Music End', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.MUSIC

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire music.tbl file."""
        entries = []
        in_soundtrack = False
        in_menu_music = False
        current_soundtrack = None

        while state.has_more_lines():
            line = state.next_line()
            if not line or self._should_skip_line(line, state):
                continue
            
            line = line.strip()

            if self._parse_patterns['soundtrack_start'].match(line):
                in_soundtrack = True
                current_soundtrack = {'tracks': [], 'type': 'soundtrack'}
                continue
            
            if self._parse_patterns['soundtrack_end'].match(line):
                if current_soundtrack:
                    entries.append(current_soundtrack)
                in_soundtrack = False
                current_soundtrack = None
                continue

            if self._parse_patterns['menu_music_start'].match(line):
                in_menu_music = True
                continue

            if self._parse_patterns['menu_music_end'].match(line):
                in_menu_music = False
                continue

            if in_soundtrack and current_soundtrack is not None:
                self.parse_soundtrack_entry(line, current_soundtrack)
            
            if in_menu_music:
                entry = self.parse_menu_music_entry(line)
                if entry:
                    entries.append(entry)

        return entries

    def parse_soundtrack_entry(self, line: str, soundtrack: Dict[str, Any]):
        """Parse a single soundtrack entry line."""
        match = self._parse_patterns['soundtrack_name'].match(line)
        if match:
            soundtrack['name'] = match.group(1).strip()
            return

        match = self._parse_patterns['overlay'].match(line)
        if match:
            soundtrack['overlay'] = match.group(1).upper() == 'YES'
            return

        match = self._parse_patterns['lock_ambient'].match(line)
        if match:
            soundtrack['lock_ambient'] = match.group(1).upper() == 'YES'
            return

        match = self._parse_patterns['music_entry'].match(line)
        if match:
            filename, val1, val2, description = match.groups()
            soundtrack['tracks'].append({
                'filename': filename.strip(),
                'val1': float(val1),
                'val2': float(val2),
                'description': description.strip()
            })

    def parse_menu_music_entry(self, line: str) -> Optional[Dict[str, Any]]:
        """Parse a single menu music entry line."""
        match = self._parse_patterns['menu_music_entry'].match(line)
        if not match:
            return None
        
        name, filename, description = match.groups()
        return {
            'type': 'menu_music',
            'name': name.strip(),
            'filename': filename.strip(),
            'description': description.strip()
        }

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Not used when parse_table is overridden."""
        return None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed music entry."""
        return 'name' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed music entries to a Godot resource dictionary."""
        soundtracks = [e for e in entries if e.get('type') == 'soundtrack']
        menu_music = [e for e in entries if e.get('type') == 'menu_music']

        return {
            'resource_type': 'WCSMusicDatabase',
            'soundtracks': {s['name']: self._convert_soundtrack_entry(s) for s in soundtracks},
            'menu_music': {m['name']: self._convert_menu_music_entry(m) for m in menu_music},
        }

    def _convert_soundtrack_entry(self, soundtrack: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single soundtrack entry to the target Godot format."""
        return {
            'name': soundtrack.get('name'),
            'overlay': soundtrack.get('overlay', False),
            'lock_ambient': soundtrack.get('lock_ambient', False),
            'tracks': soundtrack.get('tracks', [])
        }
    
    def _convert_menu_music_entry(self, menu_music: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single menu music entry to the target Godot format."""
        return {
            'name': menu_music.get('name'),
            'filename': menu_music.get('filename'),
            'description': menu_music.get('description')
        }
