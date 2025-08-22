#!/usr/bin/env python3
"""
Weapon Table Converter

Focused converter for WCS weapons.tbl files.
Single Responsibility: Weapon table parsing and conversion only.
"""

import re
from typing import Any, Dict, List, Optional

from .base_table_converter import BaseTableConverter, ParseState, TableType


class WeaponTableConverter(BaseTableConverter):
    """Converts WCS weapons.tbl files to Godot weapon resources"""
    
    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for weapon table parsing with comprehensive asset fields"""
        return {
            # Basic weapon identification
            'weapon_start': re.compile(r'^\$Name:\s*(.+)$', re.IGNORECASE),
            'title': re.compile(r'^\$Title:\s*(.+)$', re.IGNORECASE),
            'alt_name': re.compile(r'^\$Alt name:\s*(.+)$', re.IGNORECASE),
            'description': re.compile(r'^\$Description:\s*(.+)$', re.IGNORECASE),
            'tech_title': re.compile(r'^\$Tech Title:\s*(.+)$', re.IGNORECASE),
            'tech_description': re.compile(r'^\$Tech Description:\s*(.+)$', re.IGNORECASE),
            
            # Physics and combat properties
            'damage': re.compile(r'^\$Damage:\s*([\d\.]+)$', re.IGNORECASE),
            'mass': re.compile(r'^\$Mass:\s*([\d\.]+)$', re.IGNORECASE),
            'velocity': re.compile(r'^\$Velocity:\s*([\d\.]+)$', re.IGNORECASE),
            'fire_wait': re.compile(r'^\$Fire Wait:\s*([\d\.]+)$', re.IGNORECASE),
            'weapon_range': re.compile(r'^\$Range:\s*([\d\.]+)$', re.IGNORECASE),
            'lifetime': re.compile(r'^\$Lifetime:\s*([\d\.]+)$', re.IGNORECASE),
            'energy_consumed': re.compile(r'^\$Energy Consumed:\s*([\d\.]+)$', re.IGNORECASE),
            'cargo_size': re.compile(r'^\$Cargo Size:\s*([\d\.]+)$', re.IGNORECASE),
            
            # 3D Models and geometry
            'model_file': re.compile(r'^\$Model file:\s*(.+)$', re.IGNORECASE),
            'pof_file': re.compile(r'^\$POF file:\s*(.+)$', re.IGNORECASE),
            'external_model_file': re.compile(r'^\$External Model File:\s*(.+)$', re.IGNORECASE),
            'submodel': re.compile(r'^\$Submodel:\s*(.+)$', re.IGNORECASE),
            
            # Laser/beam visual properties
            'laser_bitmap': re.compile(r'^\$Laser Bitmap:\s*(.+)$', re.IGNORECASE),
            'laser_glow': re.compile(r'^\$Laser Glow:\s*(.+)$', re.IGNORECASE),
            'laser_length': re.compile(r'^\$Laser Length:\s*([\d\.]+)$', re.IGNORECASE),
            'laser_head_radius': re.compile(r'^\$Laser Head Radius:\s*([\d\.]+)$', re.IGNORECASE),
            'laser_tail_radius': re.compile(r'^\$Laser Tail Radius:\s*([\d\.]+)$', re.IGNORECASE),
            'trail_bitmap': re.compile(r'^\$Trail Bitmap:\s*(.+)$', re.IGNORECASE),
            'impact_bitmap': re.compile(r'^\$Impact Bitmap:\s*(.+)$', re.IGNORECASE),
            
            # Audio assets
            'launch_sound': re.compile(r'^\$Launch Snd:\s*(.+)$', re.IGNORECASE),
            'impact_sound': re.compile(r'^\$Impact Snd:\s*(.+)$', re.IGNORECASE),
            'disarmed_sound': re.compile(r'^\$Disarmed Snd:\s*(.+)$', re.IGNORECASE),
            'armed_sound': re.compile(r'^\$Armed Snd:\s*(.+)$', re.IGNORECASE),
            'flyby_sound': re.compile(r'^\$Flyby Snd:\s*(.+)$', re.IGNORECASE),
            
            # Visual effects
            'muzzleflash': re.compile(r'^\$Muzzleflash:\s*(.+)$', re.IGNORECASE),
            'impact_effect': re.compile(r'^\$Impact Effect:\s*(.+)$', re.IGNORECASE),
            'particle_spew': re.compile(r'^\$Particle Spew:\s*(.+)$', re.IGNORECASE),
            'trails': re.compile(r'^\$Trails:\s*(.+)$', re.IGNORECASE),
            'shockwave_anim': re.compile(r'^\$Shockwave Anim:\s*(.+)$', re.IGNORECASE),
            
            # Tech database assets
            'tech_model': re.compile(r'^\$Tech Model:\s*(.+)$', re.IGNORECASE),
            'tech_anim': re.compile(r'^\$Tech Anim:\s*(.+)$', re.IGNORECASE),
            'tech_image': re.compile(r'^\$Tech Image:\s*(.+)$', re.IGNORECASE),
            
            # Thruster effects
            'thruster_flame': re.compile(r'^\$Thruster flame:\s*(.+)$', re.IGNORECASE),
            'thruster_glow': re.compile(r'^\$Thruster glow:\s*(.+)$', re.IGNORECASE),
            
            # Homing properties
            'homing_type': re.compile(r'^\$Homing:\s*(.+)$', re.IGNORECASE),
            'turn_time': re.compile(r'^\$Turn Time:\s*([\d\.]+)$', re.IGNORECASE),
            'fov': re.compile(r'^\$FOV:\s*([\d\.]+)$', re.IGNORECASE),
            'seeker_strength': re.compile(r'^\$Seeker Strength:\s*([\d\.]+)$', re.IGNORECASE),
            
            # Special weapon properties
            'swarm_count': re.compile(r'^\$Swarm:\s*([\d]+)$', re.IGNORECASE),
            'swarm_wait': re.compile(r'^\$SwarmWait:\s*([\d]+)$', re.IGNORECASE),
            
            # Section termination
            'section_end': re.compile(r'^\$end_multi_text\s*$', re.IGNORECASE),
        }
    
    def get_table_type(self) -> TableType:
        return TableType.WEAPONS
    
    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single weapon entry from the table"""
        weapon_data = {}
        
        while state.has_more_lines():
            line = state.next_line()
            if not line:
                continue
                
            line = line.strip()
            if not line or self._should_skip_line(line, state):
                continue
            
            # Check for weapon start
            match = self._parse_patterns['weapon_start'].match(line)
            if match:
                weapon_data['name'] = match.group(1).strip()
                continue
            
            # Parse weapon properties
            if 'name' in weapon_data:
                if self._parse_weapon_property(line, weapon_data):
                    continue
                
                # Check for section end
                if self._parse_patterns['section_end'].match(line):
                    return weapon_data if weapon_data else None
        
        return weapon_data if weapon_data else None
    
    def _parse_weapon_property(self, line: str, weapon_data: Dict[str, Any]) -> bool:
        """Parse a single weapon property line"""
        for property_name, pattern in self._parse_patterns.items():
            if property_name in ['weapon_start', 'section_end']:
                continue
                
            match = pattern.match(line)
            if match:
                value = match.group(1).strip()
                
                # Handle special parsing for numeric properties
                # Handle numeric properties
                numeric_props = ['damage', 'mass', 'velocity', 'fire_wait', 'weapon_range', 'lifetime', 
                               'energy_consumed', 'cargo_size', 'laser_length', 'laser_head_radius', 
                               'laser_tail_radius', 'turn_time', 'fov', 'seeker_strength']
                integer_props = ['swarm_count', 'swarm_wait']
                
                if property_name in numeric_props:
                    weapon_data[property_name] = self.parse_value(value, float)
                elif property_name in integer_props:
                    weapon_data[property_name] = self.parse_value(value, int)
                else:
                    weapon_data[property_name] = value
                
                return True
        
        return False
    
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed weapon entry"""
        required_fields = ['name']
        
        for field in required_fields:
            if field not in entry:
                self.logger.warning(f"Weapon entry missing required field: {field}")
                return False
        
        # Validate numeric fields
        numeric_fields = ['damage', 'mass', 'velocity', 'fire_wait', 'weapon_range']
        for field in numeric_fields:
            if field in entry and not isinstance(entry[field], (int, float)):
                self.logger.warning(f"Weapon {entry['name']}: Invalid {field} value")
                return False
        
        return True
    
    def convert_to_godot_resources(self, entries: List[Dict[str, Any]], output_dir: str) -> Dict[str, Any]:
        """Convert parsed weapon entries to Godot .tres resource files"""
        from ..resource_generators.weapon_resource_generator import \
            WeaponResourceGenerator

        # Create resource generator
        generator = WeaponResourceGenerator(output_dir)
        
        # Generate weapon resources
        resource_files = generator.generate_weapon_resources(entries)
        
        return {
            'conversion_type': 'weapon_resources',
            'resource_files': resource_files,
            'weapon_count': len(entries),
            'output_directory': output_dir
        }
    
    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Legacy method - now redirects to resource generation"""
        # For compatibility - generate resources in default location
        import tempfile
        with tempfile.TemporaryDirectory() as temp_dir:
            return self.convert_to_godot_resources(entries, temp_dir)