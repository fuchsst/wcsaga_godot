#!/usr/bin/env python3
"""
Ship Class Resource Generator

Generates .tres ShipClass resource files from ships.tbl data.
Uses existing BaseShip and ShipClass architecture - no custom logic.
"""

import os
from pathlib import Path
from typing import Any, Dict, List


class ShipClassGenerator:
    """Generates ShipClass .tres resource files from parsed ship table data"""
    
    def __init__(self, output_dir: str):
        self.output_dir = output_dir
        self.ships_dir = os.path.join(output_dir, "ships")
        os.makedirs(self.ships_dir, exist_ok=True)
    
    def generate_ship_resources(self, ship_entries: List[Dict[str, Any]]) -> List[str]:
        """Generate .tres resource files for all ship entries"""
        generated_files = []
        
        for ship in ship_entries:
            resource_file = self._generate_single_ship_resource(ship)
            if resource_file:
                generated_files.append(resource_file)
        
        # Generate ship registry file
        registry_file = self._generate_ship_registry(ship_entries)
        if registry_file:
            generated_files.append(registry_file)
        
        return generated_files
    
    def _generate_single_ship_resource(self, ship: Dict[str, Any]) -> str:
        """Generate a single ShipClass .tres resource file"""
        ship_name = ship.get('name', 'unknown_ship')
        safe_name = self._sanitize_filename(ship_name)
        
        # Determine faction folder
        faction = self._determine_faction(ship_name)
        faction_dir = os.path.join(self.ships_dir, faction)
        os.makedirs(faction_dir, exist_ok=True)
        
        # Create .tres resource content
        resource_content = self._create_ship_resource_content(ship)
        
        # Write resource file
        output_path = os.path.join(faction_dir, f"{safe_name}.tres")
        
        try:
            with open(output_path, 'w') as f:
                f.write(resource_content)
            print(f"Generated ship resource: {output_path}")
            return output_path
        except Exception as e:
            print(f"Error writing ship resource {output_path}: {e}")
            return ""
    
    def _create_ship_resource_content(self, ship: Dict[str, Any]) -> str:
        """Create .tres resource content for ShipClass"""
        
        # Extract ship properties with defaults
        ship_name = ship.get('name', 'Unknown Ship')
        max_velocity = ship.get('max_velocity', 75.0)
        max_hull_strength = ship.get('max_hull', 100.0)
        max_shield_strength = ship.get('max_shield', 50.0)
        mass = ship.get('mass', 1000.0)
        
        # Determine ship type
        ship_type = self._determine_ship_type(ship_name)
        
        # Extract actual asset paths from ship data
        pof_file = ship.get('pof_file', ship.get('model_file', ''))
        pof_target_file = ship.get('pof_target_file', '')
        cockpit_pof_file = ship.get('cockpit_pof_file', '')
        ship_icon = ship.get('ship_icon', '')
        ship_anim = ship.get('ship_anim', '')
        ship_overhead = ship.get('ship_overhead', '')
        tech_model = ship.get('tech_model', '')
        tech_anim = ship.get('tech_anim', '')
        tech_image = ship.get('tech_image', '')
        thruster_flame = ship.get('thruster_flame', '')
        thruster_glow = ship.get('thruster_glow', '')
        
        # Convert to Godot resource paths with fallbacks
        safe_name = self._sanitize_filename(ship_name)
        faction = self._determine_faction(ship_name)
        
        # Use actual POF file path when available
        if pof_file:
            model_path = f"res://assets/models/ships/{pof_file}"
        else:
            model_path = f"res://assets/models/ships/{faction}/{safe_name}.glb"
            
        # Use ship icon when available
        if ship_icon:
            icon_path = f"res://assets/ui/ships/{ship_icon}"
        else:
            icon_path = f"res://assets/ui/ships/{safe_name}_icon.png"
            
        # Generate texture path (fallback only)
        texture_path = f"res://assets/textures/ships/{faction}/{safe_name}_diffuse.png"
        
        # Create .tres content
        resource_content = f'''[gd_resource type="ShipClass" script_class="ShipClass" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/wcs_asset_core/resources/ship/ship_class.gd" id="1"]

[resource]
script = ExtResource("1")
class_name = "{ship_name}"
display_name = "{ship_name}"
ship_type = {ship_type}
mass = {mass}
max_velocity = {max_velocity}
max_afterburner_velocity = {max_velocity * 1.5}
max_hull_strength = {max_hull_strength}
max_shield_strength = {max_shield_strength}
max_weapon_energy = {ship.get('max_weapon_energy', 100.0)}
afterburner_fuel_capacity = {ship.get('afterburner_fuel', 500.0)}
model_path = "{model_path}"
texture_path = "{texture_path}"
ship_scene_path = "res://scenes/ships/{faction}/{safe_name}.tscn"
hardpoint_configuration = {self._format_hardpoints(ship)}
subsystem_definitions = {self._format_subsystems(ship)}

# Asset paths from extracted table data
icon_path = "{icon_path}"
pof_target_file_path = "{f'res://assets/models/ships/{pof_target_file}' if pof_target_file else ''}"
cockpit_pof_file_path = "{f'res://assets/models/ships/{cockpit_pof_file}' if cockpit_pof_file else ''}"
ship_anim_path = "{f'res://assets/animations/ships/{ship_anim}' if ship_anim else ''}"
ship_overhead_path = "{f'res://assets/ui/ships/{ship_overhead}' if ship_overhead else ''}"
tech_model_path = "{f'res://assets/models/tech/{tech_model}' if tech_model else ''}"
tech_anim_path = "{f'res://assets/animations/tech/{tech_anim}' if tech_anim else ''}"
tech_image_path = "{f'res://assets/images/tech/{tech_image}' if tech_image else ''}"
thruster_flame_effect_path = "{f'res://effects/ships/{thruster_flame}' if thruster_flame else ''}"
thruster_glow_effect_path = "{f'res://effects/ships/{thruster_glow}' if thruster_glow else ''}"
'''
        return resource_content
    
    def _determine_ship_type(self, ship_name: str) -> str:
        """Determine ship type constant from name"""
        name_lower = ship_name.lower()
        
        if any(word in name_lower for word in ['fighter', 'interceptor', 'stealth']):
            return "ShipTypes.Type.FIGHTER"
        elif any(word in name_lower for word in ['bomber', 'assault']):
            return "ShipTypes.Type.BOMBER"
        elif any(word in name_lower for word in ['corvette', 'gunboat']):
            return "ShipTypes.Type.CORVETTE"
        elif any(word in name_lower for word in ['cruiser', 'destroyer']):
            return "ShipTypes.Type.CRUISER"
        elif any(word in name_lower for word in ['capital', 'dreadnought', 'carrier']):
            return "ShipTypes.Type.CAPITAL"
        elif any(word in name_lower for word in ['transport', 'cargo', 'freighter']):
            return "ShipTypes.Type.TRANSPORT"
        else:
            return "ShipTypes.Type.FIGHTER"  # Default
    
    def _determine_faction(self, ship_name: str) -> str:
        """Determine faction folder from ship name"""
        name_lower = ship_name.lower()
        
        # Terran prefixes
        if any(prefix in name_lower for prefix in ['gtf', 'gtb', 'gtc', 'gtd', 'gtt', 'gta']):
            return "terran"
        # Vasudan prefixes  
        elif any(prefix in name_lower for prefix in ['pva', 'pvf', 'pvb', 'pvc', 'pvd']):
            return "vasudan"
        # Shivan prefixes
        elif any(prefix in name_lower for prefix in ['sf', 'sb', 'sc', 'sd', 'sj']):
            return "shivan"
        # Generic/Other
        else:
            return "other"
    
    def _format_hardpoints(self, ship: Dict[str, Any]) -> str:
        """Format hardpoint configuration dictionary"""
        # Default hardpoints based on ship type
        hardpoints = {}
        
        ship_name = ship.get('name', '').lower()
        if 'fighter' in ship_name or 'interceptor' in ship_name:
            hardpoints = {
                "primary_gun_01": "Vector3(1.2, 0.1, 2.1)",
                "primary_gun_02": "Vector3(-1.2, 0.1, 2.1)",
                "missile_launcher_01": "Vector3(2.0, -0.5, 1.0)",
                "missile_launcher_02": "Vector3(-2.0, -0.5, 1.0)"
            }
        elif 'bomber' in ship_name:
            hardpoints = {
                "primary_gun_01": "Vector3(1.5, 0.2, 2.5)",
                "primary_gun_02": "Vector3(-1.5, 0.2, 2.5)",
                "missile_launcher_01": "Vector3(3.0, -0.8, 0.5)",
                "missile_launcher_02": "Vector3(-3.0, -0.8, 0.5)",
                "torpedo_launcher": "Vector3(0.0, -1.0, 1.5)"
            }
        
        # Format as Godot dictionary
        formatted_items = [f'"{k}": {v}' for k, v in hardpoints.items()]
        return "{" + ", ".join(formatted_items) + "}"
    
    def _format_subsystems(self, ship: Dict[str, Any]) -> str:
        """Format subsystem definition paths array"""
        # Default subsystems based on ship type
        ship_name = ship.get('name', '').lower()
        
        subsystems = [
            '"res://resources/subsystems/engine_standard.tres"',
            '"res://resources/subsystems/weapons_standard.tres"',
            '"res://resources/subsystems/shields_standard.tres"'
        ]
        
        if 'fighter' in ship_name:
            subsystems.append('"res://resources/subsystems/navigation_fighter.tres"')
        elif 'bomber' in ship_name:
            subsystems.extend([
                '"res://resources/subsystems/navigation_bomber.tres"',
                '"res://resources/subsystems/sensors_enhanced.tres"'
            ])
        elif any(word in ship_name for word in ['capital', 'cruiser', 'destroyer']):
            subsystems.extend([
                '"res://resources/subsystems/navigation_capital.tres"',
                '"res://resources/subsystems/sensors_capital.tres"',
                '"res://resources/subsystems/communications.tres"'
            ])
        
        return "[" + ", ".join(subsystems) + "]"
    
    def _sanitize_filename(self, name: str) -> str:
        """Convert ship name to valid filename"""
        # Remove invalid characters and spaces
        safe_name = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name)
        safe_name = safe_name.lower().strip('_')
        return safe_name or 'unnamed_ship'
    
    def _generate_ship_registry(self, ship_entries: List[Dict[str, Any]]) -> str:
        """Generate ship registry resource file"""
        registry_content = '''[gd_resource type="Resource" script_class="ShipRegistryData" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/ships/ship_registry_data.gd" id="1"]

[resource]
script = ExtResource("1")
ship_classes = {
'''
        
        # Add all ship entries organized by faction
        ships_by_faction = {}
        for ship in ship_entries:
            faction = self._determine_faction(ship.get('name', ''))
            if faction not in ships_by_faction:
                ships_by_faction[faction] = []
            ships_by_faction[faction].append(ship)
        
        for faction, ships in ships_by_faction.items():
            registry_content += f'    "{faction}": [\n'
            for ship in ships:
                ship_name = ship.get('name', 'unknown')
                safe_name = self._sanitize_filename(ship_name)
                resource_path = f"res://resources/ships/{faction}/{safe_name}.tres"
                registry_content += f'        "{resource_path}",\n'
            registry_content += '    ],\n'
        
        registry_content += '''}
ship_count = {len(ship_entries)}
'''
        
        # Write registry file
        registry_path = os.path.join(self.output_dir, "ship_registry.tres")
        try:
            with open(registry_path, 'w') as f:
                f.write(registry_content)
            print(f"Generated ship registry: {registry_path}")
            return registry_path
        except Exception as e:
            print(f"Error writing ship registry: {e}")
            return ""