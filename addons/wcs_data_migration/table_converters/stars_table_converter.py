#!/usr/bin/env python3
"""
Stars Table Converter

Single Responsibility: Star, planet, and background definitions parsing and conversion only.
Handles stars.tbl files for environment and celestial body configuration.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class StarsTableConverter(BaseTableConverter):
    """Converts WCS stars.tbl files to Godot environment resources"""

    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for stars table parsing"""
        return {
            'bitmap': re.compile(r'^\$Bitmap:\s*(.+)$', re.IGNORECASE),
            'sun_start': re.compile(r'^\$Sun:\s*(.+)$', re.IGNORECASE),
            'sunglow': re.compile(r'^\$Sunglow:\s*(.+)$', re.IGNORECASE),
            'sun_rgbi': re.compile(r'^\$SunRGBI:\s*([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)$', re.IGNORECASE),
            'flare_start': re.compile(r'^\$Flare:$', re.IGNORECASE),
            'flare_count': re.compile(r'^\+FlareCount:\s*(\d+)$', re.IGNORECASE),
            'flare_texture': re.compile(r'^\$FlareTexture(\d+):\s*(.+)$', re.IGNORECASE),
            'flare_glow_start': re.compile(r'^\$FlareGlow(\d+):$', re.IGNORECASE),
            'flare_texture_ref': re.compile(r'^\+FlareTexture:\s*(\d+)$', re.IGNORECASE),
            'flare_pos': re.compile(r'^\+FlarePos:\s*([\d\.]+)$', re.IGNORECASE),
            'flare_scale': re.compile(r'^\+FlareScale:\s*([\d\.]+)$', re.IGNORECASE),
            'debris': re.compile(r'^\$Debris:\s*(.+)$', re.IGNORECASE),
            'debris_neb': re.compile(r'^\$DebrisNeb:\s*(.+)$', re.IGNORECASE),
            'section_end': re.compile(r'^#end$', re.IGNORECASE),
        }

    def get_table_type(self) -> TableType:
        return TableType.STARS

    def parse_table(self, state: ParseState) -> List[Dict[str, Any]]:
        """
        Parse the entire stars.tbl file, handling different sections.
        """
        entries = {
            'bitmaps': [],
            'suns': [],
            'debris': [],
            'debris_neb': [],
        }
        current_sun = None
        in_flare = False
        current_flare_glow = {}

        while state.has_more_lines():
            line = state.next_line()
            if not line or self._should_skip_line(line, state):
                continue

            line = line.strip()

            if self._parse_patterns['section_end'].match(line):
                if current_sun:
                    if current_flare_glow:
                        current_sun['flare_glows'].append(current_flare_glow)
                        current_flare_glow = {}
                    entries['suns'].append(current_sun)
                    current_sun = None
                in_flare = False
                continue

            # Bitmaps
            match = self._parse_patterns['bitmap'].match(line)
            if match:
                entries['bitmaps'].append({'name': match.group(1).strip(), 'type': 'background'})
                continue

            # Debris
            match = self._parse_patterns['debris'].match(line)
            if match:
                entries['debris'].append({'name': match.group(1).strip(), 'type': 'debris'})
                continue

            # Nebula Debris
            match = self._parse_patterns['debris_neb'].match(line)
            if match:
                entries['debris_neb'].append({'name': match.group(1).strip(), 'type': 'debris_nebula'})
                continue

            # Sun
            match = self._parse_patterns['sun_start'].match(line)
            if match:
                if current_sun:
                    if current_flare_glow:
                        current_sun['flare_glows'].append(current_flare_glow)
                        current_flare_glow = {}
                    entries['suns'].append(current_sun)
                current_sun = {'name': match.group(1).strip(), 'flares': {}}
                in_flare = False
                continue

            if current_sun:
                # Sunglow
                match = self._parse_patterns['sunglow'].match(line)
                if match:
                    current_sun['sunglow'] = match.group(1).strip()
                    continue

                # SunRGBI
                match = self._parse_patterns['sun_rgbi'].match(line)
                if match:
                    current_sun['rgbi'] = [float(g) for g in match.groups()]
                    continue

                # Flare section
                if self._parse_patterns['flare_start'].match(line):
                    in_flare = True
                    current_sun['flare_textures'] = {}
                    current_sun['flare_glows'] = []
                    continue
                
                if in_flare:
                    # Flare Count
                    match = self._parse_patterns['flare_count'].match(line)
                    if match:
                        current_sun['flare_count'] = int(match.group(1))
                        continue
                    
                    # Flare Textures
                    match = self._parse_patterns['flare_texture'].match(line)
                    if match:
                        tex_num, tex_name = match.groups()
                        current_sun['flare_textures'][int(tex_num)] = tex_name.strip()
                        continue

                    # Flare Glow
                    match = self._parse_patterns['flare_glow_start'].match(line)
                    if match:
                        if current_flare_glow:
                            current_sun['flare_glows'].append(current_flare_glow)
                        current_flare_glow: Dict[str, Any] = {'id': int(match.group(1))}
                        continue
                    
                    if current_flare_glow:
                        match = self._parse_patterns['flare_texture_ref'].match(line)
                        if match:
                            current_flare_glow['texture_ref'] = int(match.group(1))
                            continue
                        match = self._parse_patterns['flare_pos'].match(line)
                        if match:
                            current_flare_glow['pos'] = float(match.group(1))
                            continue
                        match = self._parse_patterns['flare_scale'].match(line)
                        if match:
                            current_flare_glow['scale'] = float(match.group(1))
                            continue

        if current_sun:
            if current_flare_glow:
                current_sun['flare_glows'].append(current_flare_glow)
            entries['suns'].append(current_sun)

        # Flatten the structure for the final list of entries
        all_entries = []
        all_entries.extend(entries['bitmaps'])
        all_entries.extend(entries['suns'])
        all_entries.extend(entries['debris'])
        all_entries.extend(entries['debris_neb'])
        return all_entries


    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Not used when parse_table is overridden."""
        return None

    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed entry."""
        return 'name' in entry

    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed entries to a Godot resource dictionary."""
        bitmaps = [e for e in entries if e.get('type') == 'background']
        suns = [e for e in entries if 'sunglow' in e] # Simple way to identify suns
        debris = [e for e in entries if e.get('type') == 'debris']
        debris_neb = [e for e in entries if e.get('type') == 'debris_nebula']

        return {
            'resource_type': 'WCSStarsDatabase',
            'bitmaps': {b['name']: {'type': 'Texture', 'path': f"res://assets/bitmaps/{b['name']}.png"} for b in bitmaps},
            'suns': {s['name']: self._convert_sun_entry(s) for s in suns},
            'debris': [d['name'] for d in debris],
            'debris_nebula': [dn['name'] for dn in debris_neb],
        }

    def _convert_sun_entry(self, sun: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single sun entry to the target Godot format."""
        flare_glows = []
        for glow in sun.get('flare_glows', []):
            tex_ref = glow.get('texture_ref')
            texture_name = sun.get('flare_textures', {}).get(tex_ref)
            flare_glows.append({
                'texture': texture_name,
                'pos': glow.get('pos'),
                'scale': glow.get('scale'),
            })

        return {
            'name': sun.get('name'),
            'sunglow': sun.get('sunglow'),
            'color': sun.get('rgbi'),
            'flare': {
                'count': sun.get('flare_count'),
                'textures': list(sun.get('flare_textures', {}).values()),
                'glows': flare_glows,
            }
        }
