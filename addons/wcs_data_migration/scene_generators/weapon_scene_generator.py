#!/usr/bin/env python3
"""
Weapon Scene Generator

Generates .tscn scene files for weapons with exported vars populated from weapons.tbl data.
Follows scene-based asset architecture instead of .tres resources.
"""

import os
from pathlib import Path
from typing import Any, Dict, List


class WeaponSceneGenerator:
    """Generates weapon scene files from parsed weapon table data"""
    
    def __init__(self, template_path: str, output_dir: str):
        self.template_path = template_path
        self.output_dir = output_dir
        self.scene_template = self._load_template()
    
    def _load_template(self) -> str:
        """Load the weapon scene template"""
        try:
            with open(self.template_path, 'r') as f:
                return f.read()
        except Exception as e:
            print(f"Error loading template: {e}")
            return self._get_default_template()
    
    def _get_default_template(self) -> str:
        """Fallback template if file not found"""
        return '''[gd_scene load_steps=2 format=3]

[sub_resource type="SphereMesh" id="SphereMesh_1"]

[node name="WeaponProjectile" type="RigidBody3D"]
script = preload("res://scripts/weapons/weapon_projectile_controller.gd")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("SphereMesh_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
'''
    
    def generate_weapon_scenes(self, weapon_entries: List[Dict[str, Any]]) -> List[str]:
        """Generate scene files for all weapon entries"""
        generated_files = []
        
        for weapon in weapon_entries:
            scene_file = self._generate_single_weapon_scene(weapon)
            if scene_file:
                generated_files.append(scene_file)
        
        return generated_files
    
    def _generate_single_weapon_scene(self, weapon: Dict[str, Any]) -> str:
        """Generate a single weapon scene file"""
        weapon_name = weapon.get('name', 'unknown_weapon')
        safe_name = self._sanitize_filename(weapon_name)
        
        # Create scene content with populated exported vars
        scene_content = self._create_scene_content(weapon)
        
        # Write scene file
        output_path = os.path.join(self.output_dir, f"{safe_name}.tscn")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        try:
            with open(output_path, 'w') as f:
                f.write(scene_content)
            print(f"Generated weapon scene: {output_path}")
            return output_path
        except Exception as e:
            print(f"Error writing scene file {output_path}: {e}")
            return ""
    
    def _create_scene_content(self, weapon: Dict[str, Any]) -> str:
        """Create scene content with weapon properties as exported vars"""
        
        # Extract weapon properties with defaults
        weapon_name = weapon.get('name', 'Unknown Weapon')
        damage = weapon.get('damage', 100.0)
        velocity = weapon.get('velocity', 500.0)
        mass = weapon.get('mass', 1.0)
        fire_wait = weapon.get('fire_wait', 0.5)
        weapon_range = weapon.get('weapon_range', 1000.0)
        
        # Determine weapon type and properties
        is_homing = 'homing' in weapon_name.lower() or 'missile' in weapon_name.lower()
        pierces_shields = 'piercing' in weapon_name.lower() or 'anti-shield' in weapon_name.lower()
        
        # Create scene file content
        scene_content = f'''[gd_scene load_steps=4 format=3 uid="uid://weapon_{self._sanitize_filename(weapon_name)}"]

[sub_resource type="SphereMesh" id="SphereMesh_1"]
radius = 0.1
height = 0.2

[sub_resource type="SphereShape3D" id="SphereShape3D_1"]
radius = 0.1

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_1"]
albedo_color = Color({self._get_weapon_color(weapon_name)})
emission_enabled = true
emission = Color({self._get_weapon_color(weapon_name)})

[node name="{self._sanitize_filename(weapon_name)}" type="RigidBody3D"]
collision_layer = 4
collision_mask = 3
script = preload("res://scripts/weapons/weapon_projectile_controller.gd")
weapon_name = "{weapon_name}"
damage = {damage}
velocity = {velocity}
mass = {mass}
fire_wait = {fire_wait}
weapon_range = {weapon_range}
is_homing = {str(is_homing).lower()}
pierces_shields = {str(pierces_shields).lower()}

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("SphereMesh_1")
surface_material_override/0 = SubResource("StandardMaterial3D_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("SphereShape3D_1")

[node name="AudioStreamPlayer3D" type="AudioStreamPlayer3D" parent="."]

[node name="TrailSystem" type="Node3D" parent="."]

[node name="ImpactEffects" type="Node3D" parent="."]
'''
        return scene_content
    
    def _sanitize_filename(self, name: str) -> str:
        """Convert weapon name to valid filename"""
        # Remove invalid characters and spaces
        safe_name = ''.join(c if c.isalnum() or c in '-_' else '_' for c in name)
        safe_name = safe_name.lower().strip('_')
        return safe_name or 'unnamed_weapon'
    
    def _get_weapon_color(self, weapon_name: str) -> str:
        """Determine weapon color based on name/type"""
        name_lower = weapon_name.lower()
        
        if 'laser' in name_lower or 'beam' in name_lower:
            return "1.0, 0.2, 0.2, 1.0"  # Red for lasers
        elif 'plasma' in name_lower:
            return "0.2, 0.8, 1.0, 1.0"  # Blue for plasma
        elif 'missile' in name_lower or 'torpedo' in name_lower:
            return "1.0, 0.8, 0.2, 1.0"  # Orange for missiles
        elif 'ion' in name_lower:
            return "0.8, 0.2, 1.0, 1.0"  # Purple for ion
        else:
            return "1.0, 1.0, 1.0, 1.0"  # White default
    
    def generate_weapon_registry(self, weapon_entries: List[Dict[str, Any]]) -> str:
        """Generate a weapon registry scene for easy access"""
        registry_content = '''[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_1"]
script/source = "class_name WeaponRegistry
extends Node

## Central registry for all weapon scene paths
## Auto-generated from weapons.tbl

const WEAPONS: Dictionary = {
'''
        
        # Add all weapon entries
        for weapon in weapon_entries:
            weapon_name = weapon.get('name', 'unknown')
            safe_name = self._sanitize_filename(weapon_name)
            scene_path = f"res://assets/weapons/{safe_name}.tscn"
            registry_content += f'    "{weapon_name}": "{scene_path}",\n'
        
        registry_content += '''}

func get_weapon_scene(weapon_name: String) -> PackedScene:
    if weapon_name in WEAPONS:
        return load(WEAPONS[weapon_name])
    return null

func get_all_weapon_names() -> Array[String]:
    return WEAPONS.keys()

func get_weapon_scene_path(weapon_name: String) -> String:
    return WEAPONS.get(weapon_name, "")
"

[node name="WeaponRegistry" type="Node"]
script = SubResource("GDScript_1")
'''
        
        # Write registry file
        registry_path = os.path.join(self.output_dir, "weapon_registry.tscn")
        try:
            with open(registry_path, 'w') as f:
                f.write(registry_content)
            print(f"Generated weapon registry: {registry_path}")
            return registry_path
        except Exception as e:
            print(f"Error writing registry file: {e}")
            return ""