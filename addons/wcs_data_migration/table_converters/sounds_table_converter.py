#!/usr/bin/env python3
"""
Sounds Table Converter

Single Responsibility: Sound definitions parsing and conversion only.
Handles sounds.tbl files for audio system configuration.
"""

import re
from typing import Dict, List, Optional, Any
from .base_table_converter import BaseTableConverter, ParseState, TableType

class SoundsTableConverter(BaseTableConverter):
    """Converts WCS sounds.tbl files to Godot audio resources"""
    
    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for sounds table parsing"""
        return {
            'sound_start': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'filename': re.compile(r'^\+Filename:\s*(.+)$', re.IGNORECASE),
            'default_volume': re.compile(r'^\+Default Volume:\s*([\d\.]+)$', re.IGNORECASE),
            'preload': re.compile(r'^\+Preload:\s*(YES|NO)$', re.IGNORECASE),
            'hardware': re.compile(r'^\+Hardware:\s*(YES|NO)$', re.IGNORECASE),
            'loop_start': re.compile(r'^\+Loop Start:\s*(\d+)$', re.IGNORECASE),
            'loop_end': re.compile(r'^\+Loop End:\s*(\d+)$', re.IGNORECASE),
            'range': re.compile(r'^\+Range:\s*([\d\.]+)$', re.IGNORECASE),
            'ducking': re.compile(r'^\+Ducking:\s*([\d\.]+)$', re.IGNORECASE),
            'priority': re.compile(r'^\+Priority:\s*(\d+)$', re.IGNORECASE),
            'section_end': re.compile(r'^\\$end$', re.IGNORECASE),
        }
    
    def get_table_type(self) -> TableType:
        return TableType.SOUNDS
    
    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single sound entry from the table"""
        sound_data = {}
        
        while state.has_more_lines():
            line = state.next_line()
            if not line:
                continue
                
            line = line.strip()
            if not line or self._should_skip_line(line, state):
                continue
            
            # Check for sound start
            match = self._parse_patterns['sound_start'].match(line)
            if match:
                sound_data['name'] = match.group(1).strip()
                continue
            
            # Parse sound properties
            if 'name' in sound_data:
                if self._parse_sound_property(line, sound_data):
                    continue
                
                # Check for next sound entry or end
                if (self._parse_patterns['sound_start'].match(line) or 
                    self._parse_patterns['section_end'].match(line)):
                    # Put line back for next iteration
                    state.current_line -= 1
                    return sound_data if sound_data else None
        
        return sound_data if sound_data else None
    
    def _parse_sound_property(self, line: str, sound_data: Dict[str, Any]) -> bool:
        """Parse a single sound property line"""
        for property_name, pattern in self._parse_patterns.items():
            if property_name in ['sound_start', 'section_end']:
                continue
                
            match = pattern.match(line)
            if match:
                value = match.group(1).strip()
                
                # Handle different property types
                if property_name in ['preload', 'hardware']:
                    sound_data[property_name] = value.upper() == 'YES'
                elif property_name in ['loop_start', 'loop_end', 'priority']:
                    sound_data[property_name] = self.parse_value(value, int)
                elif property_name in ['default_volume', 'range', 'ducking']:
                    sound_data[property_name] = self.parse_value(value, float)
                else:
                    sound_data[property_name] = value
                
                return True
        
        return False
    
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed sound entry"""
        required_fields = ['name']
        
        for field in required_fields:
            if field not in entry:
                self.logger.warning(f"Sound entry missing required field: {field}")
                return False
        
        # Validate filename exists if specified
        if 'filename' in entry and not entry['filename']:
            self.logger.warning(f"Sound {entry['name']}: Empty filename")
            return False
        
        # Validate numeric ranges
        if 'default_volume' in entry:
            volume = entry['default_volume']
            if not isinstance(volume, (int, float)) or volume < 0.0:
                self.logger.warning(f"Sound {entry['name']}: Invalid volume: {volume}")
                return False
        
        return True
    
    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed sound entries to Godot resource format"""
        return {
            'resource_type': 'WCSSoundDatabase',
            'sounds': {entry['name']: self._convert_sound_entry(entry) for entry in entries},
            'sound_count': len(entries)
        }
    
    def _convert_sound_entry(self, sound: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single sound entry to Godot format"""
        return {
            'display_name': sound.get('name', ''),
            'filename': sound.get('filename', ''),
            'default_volume': sound.get('default_volume', 1.0),
            'preload': sound.get('preload', False),
            'hardware_accelerated': sound.get('hardware', False),
            'loop_start': sound.get('loop_start', 0),
            'loop_end': sound.get('loop_end', -1),
            'range': sound.get('range', 1000.0),
            'ducking': sound.get('ducking', 0.0),
            'priority': sound.get('priority', 0)
        }