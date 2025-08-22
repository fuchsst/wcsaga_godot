#!/usr/bin/env python3
"""
Asteroid Table Converter

Single Responsibility: Asteroid and debris definitions parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

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

            # Handle multi-line blast value continuation
            if line.startswith('$Expl blast:'):
                match = self._parse_patterns['expl_blast'].match(line)
                if match:
                    entry_data['expl_blast'] = float(match.group(1))
                else:
                    # Handle multi-line blast value (continuation on next line)
                    blast_line = state.next_line()
                    if blast_line:
                        try:
                            entry_data['expl_blast'] = float(blast_line.strip())
                        except ValueError:
                            entry_data['expl_blast'] = 0.0
                continue

            for key, pattern in self._init_parse_patterns().items():
                match = pattern.match(line)
                if match:
                    if key == 'detail_distance':
                        entry_data[key] = [int(d.strip()) for d in match.group(1).split(',')]
                    elif key in ['max_speed', 'expl_inner_rad', 'expl_outer_rad', 'expl_damage', 'expl_blast', 'impact_explosion_radius']:
                        entry_data[key] = float(match.group(1))
                    elif key == 'hitpoints':
                        entry_data[key] = int(match.group(1))
                    elif key in ['pof_file1', 'pof_file2', 'pof_file3']:
                        # Handle "none" POF files
                        pof_value = match.group(1).strip()
                        entry_data[key] = None if pof_value.lower() == 'none' else pof_value
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
        """Convert parsed asteroid entries to individual Godot resources."""
        asteroids = [e for e in entries if e.get('type') == 'asteroid']
        impact_data = next((e for e in entries if e.get('type') == 'impact_data'), None)

        # Return individual asteroid resources instead of a single database
        return {
            'individual_resources': [self._convert_asteroid_entry(a) for a in asteroids],
            'impact_data': self._convert_impact_data(impact_data) if impact_data else {},
        }

    def _convert_asteroid_entry(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert a single asteroid entry to the target Godot format."""
        converted = {
            'name': entry.get('name', ''),
            'display_name': entry.get('name', ''),
            'max_speed': entry.get('max_speed', 0.0),
            'hitpoints': entry.get('hitpoints', 1),
            'explosion_inner_radius': entry.get('expl_inner_rad', 0.0),
            'explosion_outer_radius': entry.get('expl_outer_rad', 0.0),
            'explosion_damage': entry.get('expl_damage', 0.0),
            'explosion_blast': entry.get('expl_blast', 0.0),
            'detail_distances': entry.get('detail_distance', []),
            'lod_0_model': self._convert_pof_to_glb_path(entry.get('pof_file1')) or "",
            'lod_1_model': self._convert_pof_to_glb_path(entry.get('pof_file2')) or "",
            'lod_2_model': self._convert_pof_to_glb_path(entry.get('pof_file3')) or ""
        }
        return converted

    def _convert_impact_data(self, entry: Dict[str, Any]) -> Dict[str, Any]:
        """Convert the impact data to the target Godot format."""
        # Clean up impact explosion reference and convert to Godot path
        impact_explosion = entry.get('impact_explosion', '')
        # Remove comments (everything after semicolon)
        if ';' in impact_explosion:
            impact_explosion = impact_explosion.split(';')[0].strip()
        
        # Convert animation reference to Godot path
        if impact_explosion:
            impact_explosion = f"campaigns/wing_commander_saga/effects/explosions/{impact_explosion.lower()}.tscn"
        
        return {
            'impact_explosion': impact_explosion,
            'impact_explosion_radius': entry.get('impact_explosion_radius', 20.0)
        }

    def _convert_pof_to_glb_path(self, pof_file: Optional[str]) -> Optional[str]:
        """Convert POF file reference to GLB path following semantic organization."""
        if not pof_file or pof_file.lower() == 'none':
            return None
        
        # Convert .pof extension to .glb
        base_name = pof_file.replace('.pof', '')
        
        # Follow semantic organization: asteroids and debris go to environment/objects
        if 'asteroid' in base_name.lower() or 'ast' in base_name.lower():
            return f"campaigns/wing_commander_saga/environments/objects/asteroids/{base_name}.glb"
        elif 'debris' in base_name.lower():
            # Organize debris by faction
            if 'cdebris' in base_name.lower() or 'terran' in base_name.lower():
                return f"campaigns/wing_commander_saga/environments/objects/debris/terran/{base_name}.glb"
            elif 'pdebris' in base_name.lower() or 'pirate' in base_name.lower():
                return f"campaigns/wing_commander_saga/environments/objects/debris/pirate/{base_name}.glb"
            elif 'kdebris' in base_name.lower() or 'kilrathi' in base_name.lower():
                return f"campaigns/wing_commander_saga/environments/objects/debris/kilrathi/{base_name}.glb"
            else:
                return f"campaigns/wing_commander_saga/environments/objects/debris/misc/{base_name}.glb"
        else:
            return f"campaigns/wing_commander_saga/environments/objects/misc/{base_name}.glb"
