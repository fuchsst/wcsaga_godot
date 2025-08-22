#!/usr/bin/env python3
"""
AI Table Converter

Single Responsibility: AI behavior definitions parsing and conversion only.
Handles ai.tbl files for AI ship behavior configuration.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class AITableConverter(BaseTableConverter):
    """Converts WCS ai.tbl files to Godot AI behavior resources"""
    
    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for AI table parsing"""
        return {
            'ai_class_start': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'ai_class_end': re.compile(r'^\$end$', re.IGNORECASE),
            'accuracy': re.compile(r'^\+Accuracy:\s*([\d\.]+)$', re.IGNORECASE),
            'evasion': re.compile(r'^\+Evasion:\s*([\d\.]+)$', re.IGNORECASE),
            'courage': re.compile(r'^\+Courage:\s*([\d\.]+)$', re.IGNORECASE),
            'patience': re.compile(r'^\+Patience:\s*([\d\.]+)$', re.IGNORECASE),
            'intercept': re.compile(r'^\+Intercept:\s*([\d\.]+)$', re.IGNORECASE),
            'sidethrust': re.compile(r'^\+Sidethrust:\s*([\d\.]+)$', re.IGNORECASE),
            'pursuit': re.compile(r'^\+Pursuit:\s*([\d\.]+)$', re.IGNORECASE),
            'afterburner_use': re.compile(r'^\+Afterburner Use:\s*([\d\.]+)$', re.IGNORECASE),
            'shockwave_evade': re.compile(r'^\+Shockwave Evade:\s*([\d\.]+)$', re.IGNORECASE),
            'get_away_chance': re.compile(r'^\+Get-away Chance:\s*([\d\.]+)$', re.IGNORECASE),
            'max_attackers': re.compile(r'^\+Max Attackers:\s*(\d+)$', re.IGNORECASE),
        }
    
    def get_table_type(self) -> TableType:
        return TableType.AI
    
    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single AI class entry from the table"""
        ai_class_data = {}
        
        while state.has_more_lines():
            line = state.next_line()
            if not line:
                continue
                
            line = line.strip()
            if not line or self._should_skip_line(line, state):
                continue
            
            # Check for AI class start
            match = self._parse_patterns['ai_class_start'].match(line)
            if match:
                ai_class_data['name'] = match.group(1).strip()
                continue
            
            # Parse AI properties
            if 'name' in ai_class_data:
                if self._parse_ai_property(line, ai_class_data):
                    continue
                
                # Check for section end
                if self._parse_patterns['ai_class_end'].match(line):
                    return ai_class_data if ai_class_data else None
        
        return ai_class_data if ai_class_data else None
    
    def _parse_ai_property(self, line: str, ai_data: Dict[str, Any]) -> bool:
        """Parse a single AI property line"""
        for property_name, pattern in self._parse_patterns.items():
            if property_name in ['ai_class_start', 'ai_class_end']:
                continue
                
            match = pattern.match(line)
            if match:
                value = match.group(1).strip()
                
                # Handle numeric properties
                if property_name in ['max_attackers']:
                    ai_data[property_name] = self.parse_value(value, int)
                else:
                    ai_data[property_name] = self.parse_value(value, float)
                
                return True
        
        return False
    
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed AI class entry"""
        required_fields = ['name']
        
        for field in required_fields:
            if field not in entry:
                self.logger.warning(f"AI class entry missing required field: {field}")
                return False
        
        # Validate numeric ranges for AI properties
        float_fields = {
            'accuracy': (0.0, 1.0),
            'evasion': (0.0, 1.0), 
            'courage': (0.0, 1.0),
            'patience': (0.0, 10.0),
            'intercept': (0.0, 1.0),
            'sidethrust': (0.0, 1.0),
            'pursuit': (0.0, 1.0),
            'afterburner_use': (0.0, 1.0),
            'shockwave_evade': (0.0, 1.0),
            'get_away_chance': (0.0, 1.0)
        }
        
        for field, (min_val, max_val) in float_fields.items():
            if field in entry:
                value = entry[field]
                if not isinstance(value, (int, float)) or not (min_val <= value <= max_val):
                    self.logger.warning(f"AI class {entry['name']}: Invalid {field} value: {value}")
                    return False
        
        return True
    
    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed AI class entries to Godot resource format"""
        return {
            'resource_type': 'WCSAIDatabase',
            'ai_classes': {entry['name']: self._convert_ai_class_entry(entry) for entry in entries},
            'ai_class_count': len(entries)
        }
    
    def _convert_ai_class_entry(self, ai_class: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single AI class entry to Godot format"""
        return {
            'display_name': ai_class.get('name', ''),
            'accuracy': ai_class.get('accuracy', 0.7),
            'evasion': ai_class.get('evasion', 0.4),
            'courage': ai_class.get('courage', 1.0),
            'patience': ai_class.get('patience', 3.0),
            'intercept': ai_class.get('intercept', 1.0),
            'sidethrust': ai_class.get('sidethrust', 0.1),
            'pursuit': ai_class.get('pursuit', 1.0),
            'afterburner_use': ai_class.get('afterburner_use', 0.7),
            'shockwave_evade': ai_class.get('shockwave_evade', 0.0),
            'get_away_chance': ai_class.get('get_away_chance', 0.1),
            'max_attackers': ai_class.get('max_attackers', 1)
        }