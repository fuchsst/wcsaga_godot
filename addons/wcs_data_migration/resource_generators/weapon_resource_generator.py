#!/usr/bin/env python3
"""
Weapon Resource Generator

Generates .tres WeaponData resource files from weapons.tbl data.
Uses existing weapon system architecture - no custom logic.
"""

import os
from pathlib import Path
from typing import Any, Dict, List


class WeaponResourceGenerator:
    """Generates WeaponData .tres resource files from parsed weapon table data"""
    
    def __init__(self, output_dir: str):
        self.output_dir = output_dir
        self.weapons_dir = os.path.join(output_dir, "weapons")
        os.makedirs(self.weapons_dir, exist_ok=True)
    
    def generate_weapon_resources(self, weapon_entries: List[Dict[str, Any]]) -> List[str]:
        """Generate .tres resource files for all weapon entries"""
        generated_files = []
        
        # Organize weapons by type
        weapons_by_type = self._organize_weapons_by_type(weapon_entries)
        
        for weapon_type, weapons in weapons_by_type.items():
            type_dir = os.path.join(self.weapons_dir, weapon_type)
            os.makedirs(type_dir, exist_ok=True)
            
            for weapon in weapons:
                resource_file = self._generate_single_weapon_resource(weapon, weapon_type)
                if resource_file:
                    generated_files.append(resource_file)
        
        # Generate weapon registry
        registry_file = self._generate_weapon_registry(weapon_entries)
        if registry_file:
            generated_files.append(registry_file)
        
        return generated_files
    
    def _organize_weapons_by_type(self, weapon_entries: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
        """Organize weapons by type (primary, secondary, beam, etc.)"""
        weapons_by_type = {
            "primary": [],
            "secondary": [],
            "beam": [],
            "special": []
        }
        
        for weapon in weapon_entries:
            weapon_type = self._determine_weapon_type(weapon.get('name', ''))
            weapons_by_type[weapon_type].append(weapon)
        
        return weapons_by_type
    
    def _determine_weapon_type(self, weapon_name: str) -> str:
        """Determine weapon type from name"""
        name_lower = weapon_name.lower()
        
        if any(word in name_lower for word in ['beam', 'laser']):
            return "beam"
        elif any(word in name_lower for word in ['missile', 'torpedo', 'bomb', 'rocket']):
            return "secondary"
        elif any(word in name_lower for word in ['emp', 'flak', 'swarm']):
            return "special"
        else:
            return "primary"  # Default for guns, cannons, etc.
    
    def _generate_single_weapon_resource(self, weapon: Dict[str, Any], weapon_type: str) -> str:
        """Generate a single WeaponData .tres resource file"""
        weapon_name = weapon.get('name', 'unknown_weapon')
        safe_name = self._sanitize_filename(weapon_name)
        
        # Create .tres resource content
        resource_content = self._create_weapon_resource_content(weapon, weapon_type)
        
        # Write resource file
        output_path = os.path.join(self.weapons_dir, weapon_type, f"{safe_name}.tres")
        
        try:
            with open(output_path, 'w') as f:
                f.write(resource_content)
            print(f"Generated weapon resource: {output_path}")
            return output_path
        except Exception as e:
            print(f"Error writing weapon resource {output_path}: {e}")
            return ""
    
    def _create_weapon_resource_content(self, weapon: Dict[str, Any], weapon_type: str) -> str:
        """Create .tres resource content for WeaponData"""
        
        # Extract weapon properties with defaults
        weapon_name = weapon.get('name', 'Unknown Weapon')
        damage = weapon.get('damage', 100.0)
        velocity = weapon.get('velocity', 500.0)
        mass = weapon.get('mass', 1.0)
        fire_wait = weapon.get('fire_wait', 0.5)
        weapon_range = weapon.get('weapon_range', 1000.0)
        
        # Determine weapon characteristics
        is_homing = self._is_homing_weapon(weapon_name)
        pierces_shields = self._pierces_shields(weapon_name)
        weapon_class = self._get_weapon_class(weapon_type)
        
        # Asset paths
        safe_name = self._sanitize_filename(weapon_name)
        projectile_scene = f"res://scenes/weapons/{weapon_type}/{safe_name}_projectile.tscn"
        firing_sound = f"res://assets/audio/weapons/{safe_name}_fire.ogg"
        impact_sound = f"res://assets/audio/weapons/{safe_name}_impact.ogg"
        
        # Create .tres content using existing WeaponData structure
        resource_content = self._create_comprehensive_weapon_resource(weapon, weapon_type)
        
        # Create comprehensive WeaponData .tres content
        resource_content = f'''[gd_resource type="WeaponData" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/wcs_asset_core/structures/weapon_data.gd" id="1"]

[resource]
script = ExtResource("1")

# General Information
weapon_name = "{weapon_name}"
alt_name = "{alt_name}"
title = "{title}"
weapon_description = "{description}"
tech_title = "{tech_title}"
tech_description = "{tech_description}"
tech_anim_filename = "{tech_anim}"
tech_model = "{tech_model}"
hud_filename = ""
icon_filename = ""
anim_filename = ""

# Type and Rendering
subtype = {self._get_weapon_subtype(weapon_type)}
render_type = {self._get_render_type(weapon, weapon_type)}

# Model and Visuals
pof_file = "{pof_file}"
projectile_scene_path = "{projectile_scene}"

# Laser Properties
laser_bitmap = "{laser_bitmap}"
laser_glow_bitmap = "{laser_glow_bitmap}"
laser_color_1 = Color(1,1,1)
laser_color_2 = Color(0,0,0)
laser_length = {weapon.get('laser_length', 10.0)}
laser_head_radius = {weapon.get('laser_head_radius', 1.0)}
laser_tail_radius = {weapon.get('laser_tail_radius', 1.0)}

# Physics and Movement
mass = {mass}
max_speed = {max_speed}
lifetime = {lifetime}
weapon_range = {weapon_range}
weapon_min_range = {weapon_min_range}

# Firing Properties
fire_wait = {fire_wait}
energy_consumed = {energy_consumed}
rearm_rate = {weapon.get('rearm_rate', 1.0)}
shots = {weapon.get('shots', 1)}
burst_shots = {weapon.get('burst_shots', 0)}
burst_delay = {weapon.get('burst_delay', 0.1)}

# Damage Properties
damage = {damage}
damage_type_idx = {weapon.get('damage_type_idx', -1)}
armor_factor = {weapon.get('armor_factor', 1.0)}
shield_factor = {weapon.get('shield_factor', 1.0)}
subsystem_factor = {weapon.get('subsystem_factor', 1.0)}

# Homing Properties
homing_type = {weapon.get('homing_type', 0)}
free_flight_time = {weapon.get('free_flight_time', 0.25)}
turn_time = {weapon.get('turn_time', 1.0)}
fov = {weapon.get('fov', 0.5)}
min_lock_time = {weapon.get('min_lock_time', 0.0)}
seeker_strength = {weapon.get('seeker_strength', 1.0)}

# Sound Effects (use extracted sound indices/paths)
launch_snd = -1  # TODO: Map to sound index
impact_snd = -1  # TODO: Map to sound index
flyby_snd = -1   # TODO: Map to sound index

# Sound paths for resource loading
firing_sound_path = "{firing_sound_path}"
impact_sound_path = "{impact_sound_path}"

# Visual Effects
muzzle_flash_effect_path = "{self._get_effect_path(muzzle_effect, 'muzzle', weapon_type)}"
impact_effect_path = "{self._get_effect_path(impact_effect, 'impact', weapon_type)}"
trail_effect_path = "res://effects/weapons/trail_{weapon_type}.tscn"

# Thruster Properties
thruster_flame_anim = "{thruster_flame}"
thruster_glow_anim = "{thruster_glow}"

# Tech Database Assets
tech_image_path = "{f'res://assets/images/tech/{tech_image}' if tech_image else ''}"
tech_model_path = "{f'res://assets/models/tech/{tech_model}' if tech_model else ''}"

# Weapon Flags
flags = 0  # TODO: Parse weapon flags from table
flags2 = 0

# Miscellaneous
cargo_size = {weapon.get('cargo_size', 1.0)}
'''
        return resource_content
    
    def _is_homing_weapon(self, weapon_name: str) -> bool:
        """Determine if weapon has homing capability"""
        name_lower = weapon_name.lower()
        return any(word in name_lower for word in ['homing', 'missile', 'torpedo', 'aspect'])
    
    def _pierces_shields(self, weapon_name: str) -> bool:
        """Determine if weapon pierces shields"""
        name_lower = weapon_name.lower()
        return any(word in name_lower for word in ['piercing', 'anti-shield', 'phaser'])
    
    def _get_weapon_subtype(self, weapon_type: str) -> int:
        """Get weapon subtype constant"""
        type_mapping = {
            "primary": 1,    # WP_PRIMARY
            "secondary": 2,  # WP_SECONDARY
            "beam": 3,       # WP_BEAM
            "special": 4     # WP_SPECIAL
        }
        return type_mapping.get(weapon_type, 1)
    
    def _get_render_type(self, weapon: Dict[str, Any], weapon_type: str) -> int:
        """Determine render type from weapon data"""
        # Check for POF model
        if weapon.get('model_file') or weapon.get('pof_file'):
            return 1  # WRT_POF
        # Check for laser properties
        elif weapon.get('laser_bitmap') or weapon_type == 'beam':
            return 2  # WRT_LASER
        else:
            return 1  # Default to POF
    
    def _get_effect_path(self, effect_name: str, effect_type: str, weapon_type: str) -> str:
        """Get effect path from extracted data or fallback"""
        if effect_name:
            return f"res://effects/weapons/{effect_name}.tscn"
        else:
            return f"res://effects/weapons/{effect_type}_{weapon_type}.tscn"
    
    def _sanitize_filename(self, name: str) -> str:
        """Convert weapon name to valid filename"""
        # Remove invalid characters and spaces
        safe_name = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name)
        safe_name = safe_name.lower().strip('_')
        return safe_name or 'unnamed_weapon'
    
    def _generate_weapon_registry(self, weapon_entries: List[Dict[str, Any]]) -> str:
        """Generate weapon registry resource file"""
        registry_content = '''[gd_resource type="Resource" script_class="WeaponRegistryData" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/weapons/weapon_registry_data.gd" id="1"]

[resource]
script = ExtResource("1")
weapons_by_type = {
'''
        
        # Organize weapons by type
        weapons_by_type = self._organize_weapons_by_type(weapon_entries)
        
        for weapon_type, weapons in weapons_by_type.items():
            if weapons:  # Only include types that have weapons
                registry_content += f'    "{weapon_type}": [\n'
                for weapon in weapons:
                    weapon_name = weapon.get('name', 'unknown')
                    safe_name = self._sanitize_filename(weapon_name)
                    resource_path = f"res://resources/weapons/{weapon_type}/{safe_name}.tres"
                    registry_content += f'        "{resource_path}",\n'
                registry_content += '    ],\n'
        
        registry_content += f'''}}
total_weapons = {len(weapon_entries)}
'''
        
        # Write registry file
        registry_path = os.path.join(self.output_dir, "weapon_registry.tres")
        try:
            with open(registry_path, 'w') as f:
                f.write(registry_content)
            print(f"Generated weapon registry: {registry_path}")
            return registry_path
        except Exception as e:
            print(f"Error writing weapon registry: {e}")
            return ""