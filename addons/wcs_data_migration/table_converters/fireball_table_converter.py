#!/usr/bin/env python3
"""
Fireball Table Converter

Single Responsibility: Fireball/explosion effects definitions parsing and conversion only.
Handles fireball.tbl files for visual effects configuration.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class FireballTableConverter(BaseTableConverter):
    """Converts WCS fireball.tbl files to Godot explosion effect resources"""
    
    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for fireball table parsing"""
        return {
            'fireball_start': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'bitmap': re.compile(r'^\+Bitmap:\s*(.+)$', re.IGNORECASE),
            'bitmap_low': re.compile(r'^\+Bitmap Low:\s*(.+)$', re.IGNORECASE),
            'frames': re.compile(r'^\+Frames:\s*(\d+)$', re.IGNORECASE),
            'fps': re.compile(r'^\+FPS:\s*([\d\.]+)$', re.IGNORECASE),
            'lifetime': re.compile(r'^\+Lifetime:\s*([\d\.]+)$', re.IGNORECASE),
            'radius': re.compile(r'^\+Radius:\s*([\d\.]+)$', re.IGNORECASE),
            'light': re.compile(r'^\+Light:\s*([\d\.]+)$', re.IGNORECASE),
            'shockwave': re.compile(r'^\+Shockwave:\s*(YES|NO)$', re.IGNORECASE),
            'shockwave_speed': re.compile(r'^\+Shockwave Speed:\s*([\d\.]+)$', re.IGNORECASE),
            'sound': re.compile(r'^\+Sound:\s*(.+)$', re.IGNORECASE),
            'sound_low': re.compile(r'^\+Sound Low:\s*(.+)$', re.IGNORECASE),
            'section_end': re.compile(r'^\\$end$', re.IGNORECASE),
        }
    
    def get_table_type(self) -> TableType:
        return TableType.FIREBALL
    
    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single fireball entry from the table"""
        fireball_data = {}
        
        while state.has_more_lines():
            line = state.next_line()
            if not line:
                continue
                
            line = line.strip()
            if not line or self._should_skip_line(line, state):
                continue
            
            # Check for fireball start
            match = self._parse_patterns['fireball_start'].match(line)
            if match:
                fireball_data['name'] = match.group(1).strip()
                continue
            
            # Parse fireball properties
            if 'name' in fireball_data:
                if self._parse_fireball_property(line, fireball_data):
                    continue
                
                # Check for next fireball entry or end
                if (self._parse_patterns['fireball_start'].match(line) or 
                    self._parse_patterns['section_end'].match(line)):
                    # Put line back for next iteration
                    state.current_line -= 1
                    return fireball_data if fireball_data else None
        
        return fireball_data if fireball_data else None
    
    def _parse_fireball_property(self, line: str, fireball_data: Dict[str, Any]) -> bool:
        """Parse a single fireball property line"""
        for property_name, pattern in self._parse_patterns.items():
            if property_name in ['fireball_start', 'section_end']:
                continue
                
            match = pattern.match(line)
            if match:
                value = match.group(1).strip()
                
                # Handle different property types
                if property_name == 'shockwave':
                    fireball_data[property_name] = value.upper() == 'YES'
                elif property_name == 'frames':
                    fireball_data[property_name] = self.parse_value(value, int)
                elif property_name in ['fps', 'lifetime', 'radius', 'light', 'shockwave_speed']:
                    fireball_data[property_name] = self.parse_value(value, float)
                else:
                    fireball_data[property_name] = value
                
                return True
        
        return False
    
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed fireball entry"""
        required_fields = ['name']
        
        for field in required_fields:
            if field not in entry:
                self.logger.warning(f"Fireball entry missing required field: {field}")
                return False
        
        # Validate numeric properties
        numeric_fields = {
            'frames': (1, 1000),
            'fps': (0.1, 120.0),
            'lifetime': (0.1, 60.0),
            'radius': (1.0, 10000.0),
            'light': (0.0, 10.0),
            'shockwave_speed': (1.0, 10000.0)
        }
        
        for field, (min_val, max_val) in numeric_fields.items():
            if field in entry:
                value = entry[field]
                if not isinstance(value, (int, float)) or not (min_val <= value <= max_val):
                    self.logger.warning(f"Fireball {entry['name']}: Invalid {field} value: {value}")
                    return False
        
        return True
    
    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed fireball entries to Godot resource format"""
        return {
            'resource_type': 'WCSFireballDatabase',
            'fireballs': {entry['name']: self._convert_fireball_entry(entry) for entry in entries},
            'fireball_count': len(entries)
        }
    
    def _convert_fireball_entry(self, fireball: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single fireball entry to Godot format"""
        return {
            'display_name': fireball.get('name', ''),
            'bitmap': fireball.get('bitmap', ''),
            'bitmap_low': fireball.get('bitmap_low', ''),
            'frames': fireball.get('frames', 1),
            'fps': fireball.get('fps', 30.0),
            'lifetime': fireball.get('lifetime', 1.0),
            'radius': fireball.get('radius', 50.0),
            'light_intensity': fireball.get('light', 1.0),
            'has_shockwave': fireball.get('shockwave', False),
            'shockwave_speed': fireball.get('shockwave_speed', 300.0),
            'sound': fireball.get('sound', ''),
            'sound_low': fireball.get('sound_low', '')
        }