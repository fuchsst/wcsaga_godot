#!/usr/bin/env python3
"""
Lightning Table Converter

Single Responsibility: Lightning and storm definitions parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class LightningTableConverter(BaseTableConverter):
    """Converts WCS lightning.tbl files to Godot lightning effect resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for lightning.tbl parsing"""
        return {
            'bolts_start': re.compile(r'^#Bolts begin', re.IGNORECASE),
            'bolt_start': re.compile(r'^\$Bolt:\s*(.+)$', re.IGNORECASE),
            'bolt_scale': re.compile(r'^\+b_scale:\s*([\d\.]+)$', re.IGNORECASE),
            'bolt_shrink': re.compile(r'^\+b_shrink:\s*([\d\.]+)$', re.IGNORECASE),
            'bolt_poly_pct': re.compile(r'^\+b_poly_pct:\s*([\d\.]+)$', re.IGNORECASE),
            'bolt_rand': re.compile(r'^\+b_rand:\s*([\d\.]+)$', re.IGNORECASE),
            'bolt_add': re.compile(r'^\+b_add:\s*([\d\.]+)$', re.IGNORECASE),
            'bolt_strikes': re.compile(r'^\+b_strikes:\s*(\d+)$', re.IGNORECASE),
            'bolt_lifetime': re.compile(r'^\+b_lifetime:\s*(\d+)$', re.IGNORECASE),
            'bolt_noise': re.compile(r'^\+b_noise:\s*([\d\.]+)$', re.IGNORECASE),
            'bolt_emp': re.compile(r'^\+b_emp:\s*([\d\.]+)\s+([\d\.]+)$', re.IGNORECASE),
            'bolt_texture': re.compile(r'^\+b_texture:\s*(.+)$', re.IGNORECASE),
            'bolt_glow': re.compile(r'^\+b_glow:\s*(.+)$', re.IGNORECASE),
            'bolt_bright': re.compile(r'^\+b_bright:\s*([\d\.]+)$', re.IGNORECASE),
            'bolts_end': re.compile(r'^#Bolts end', re.IGNORECASE),
            'storms_start': re.compile(r'^#Storms begin', re.IGNORECASE),
            'storm_start': re.compile(r'^\$Storm:\s*(.+)$', re.IGNORECASE),
            'storm_bolt': re.compile(r'^\+bolt:\s*(.+)$', re.IGNORECASE),
            'storm_flavor': re.compile(r'^\+flavor:\s*([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)$', re.IGNORECASE),
            'storm_random_freq': re.compile(r'^\+random_freq:\s*(\d+)\s+(\d+)$', re.IGNORECASE),
            'storm_random_count': re.compile(r'^\+random_count:\s*(\d+)\s+(\d+)$', re.IGNORECASE),
            'storms_end': re.compile(r'^#Storms end', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.LIGHTNING

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse the entire lightning.tbl file."""
        entries = {'bolts': [], 'storms': []}
        in_bolts = False
        in_storms = False
        current_bolt = None
        current_storm = None

        while state.has_more_lines():
            line = state.next_line()
            if not line or self._should_skip_line(line, state):
                continue
            
            line = line.strip()

            if self._parse_patterns['bolts_start'].match(line):
                in_bolts = True
                continue
            if self._parse_patterns['bolts_end'].match(line):
                if current_bolt:
                    entries['bolts'].append(current_bolt)
                in_bolts = False
                current_bolt = None
                continue
            
            if self._parse_patterns['storms_start'].match(line):
                in_storms = True
                continue
            if self._parse_patterns['storms_end'].match(line):
                if current_storm:
                    entries['storms'].append(current_storm)
                in_storms = False
                current_storm = None
                continue

            if in_bolts:
                match = self._parse_patterns['bolt_start'].match(line)
                if match:
                    if current_bolt:
                        entries['bolts'].append(current_bolt)
                    current_bolt = {'name': match.group(1).strip()}
                elif current_bolt:
                    self.parse_bolt_property(line, current_bolt)
            
            if in_storms:
                match = self._parse_patterns['storm_start'].match(line)
                if match:
                    if current_storm:
                        entries['storms'].append(current_storm)
                    current_storm = {'name': match.group(1).strip(), 'bolts': []}
                elif current_storm:
                    self.parse_storm_property(line, current_storm)

        all_entries = []
        all_entries.extend(entries['bolts'])
        all_entries.extend(entries['storms'])
        return all_entries

    def parse_bolt_property(self, line: str, bolt: Dict[str, Any]):
        """Parse a single bolt property line."""
        for prop, pattern in self._init_parse_patterns().items():
            if not prop.startswith('bolt_'):
                continue
            match = pattern.match(line)
            if match:
                key = prop.replace('bolt_', '')
                if key in ['scale', 'shrink', 'poly_pct', 'rand', 'add', 'noise', 'bright']:
                    bolt[key] = float(match.group(1))
                elif key in ['strikes', 'lifetime']:
                    bolt[key] = int(match.group(1))
                elif key == 'emp':
                    bolt[key] = [float(g) for g in match.groups()]
                else:
                    bolt[key] = match.group(1).strip()
                return

    def parse_storm_property(self, line: str, storm: Dict[str, Any]):
        """Parse a single storm property line."""
        match = self._parse_patterns['storm_bolt'].match(line)
        if match:
            storm['bolts'].append(match.group(1).strip())
            return
        
        match = self._parse_patterns['storm_flavor'].match(line)
        if match:
            storm['flavor'] = [float(g) for g in match.groups()]
            return
            
        match = self._parse_patterns['storm_random_freq'].match(line)
        if match:
            storm['random_freq'] = [int(g) for g in match.groups()]
            return

        match = self._parse_patterns['storm_random_count'].match(line)
        if match:
            storm['random_count'] = [int(g) for g in match.groups()]
            return

    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Not used when parse_table is overridden."""
        return None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed entry."""
        return 'name' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed entries to a Godot resource dictionary."""
        bolts = [e for e in entries if 'scale' in e] # Simple way to identify bolts
        storms = [e for e in entries if 'bolts' in e] # Simple way to identify storms

        return {
            'resource_type': 'WCSLightningDatabase',
            'bolts': {b['name']: self._convert_bolt_entry(b) for b in bolts},
            'storms': {s['name']: self._convert_storm_entry(s) for s in storms},
        }

    def _convert_bolt_entry(self, bolt: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single bolt entry to the target Godot format."""
        return bolt

    def _convert_storm_entry(self, storm: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single storm entry to the target Godot format."""
        return storm
