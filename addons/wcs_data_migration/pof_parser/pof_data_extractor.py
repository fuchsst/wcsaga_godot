#!/usr/bin/env python3
"""
POF Data Extractor - EPIC-003 DM-004 Implementation

This module extracts structured data from POF files for conversion to Godot-compatible formats.
Focuses on geometry, materials, textures, and gameplay-relevant metadata.

Based on WCS C++ analysis from source/code/model/modelread.cpp
"""

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .pof_parser import POFParser
from .vector3d import Vector3D

logger = logging.getLogger(__name__)

@dataclass
class GeometryData:
    """Extracted geometry data from POF subobjects."""
    vertices: List[Tuple[float, float, float]] = field(default_factory=list)
    normals: List[Tuple[float, float, float]] = field(default_factory=list)
    texture_coordinates: List[Tuple[float, float]] = field(default_factory=list)
    faces: List[List[int]] = field(default_factory=list)  # Vertex indices per face
    materials: List[int] = field(default_factory=list)    # Material indices per face

@dataclass
class MaterialData:
    """Material information for POF models."""
    name: str
    texture_path: str
    diffuse_color: Tuple[float, float, float] = (1.0, 1.0, 1.0)
    specular_color: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    ambient_color: Tuple[float, float, float] = (0.2, 0.2, 0.2)
    shininess: float = 0.0

@dataclass
class SubsystemData:
    """Subsystem information for gameplay features."""
    name: str
    subobject_number: int
    hit_points: float
    position: Tuple[float, float, float]
    radius: float
    subsystem_type: str  # engine, turret, sensor, etc.

@dataclass
class WeaponPointData:
    """Weapon hardpoint information."""
    name: str
    position: Tuple[float, float, float]
    normal: Tuple[float, float, float]
    weapon_type: str  # gun, missile
    bank_number: int

@dataclass
class DockingPointData:
    """Docking point information."""
    name: str
    position: Tuple[float, float, float]
    normal: Tuple[float, float, float]
    dock_type: str

@dataclass
class ThrusterData:
    """Thruster/engine information."""
    position: Tuple[float, float, float]
    normal: Tuple[float, float, float]
    radius: float

@dataclass
class POFModelData:
    """Complete extracted POF model data."""
    filename: str
    version: int
    
    # Basic model properties
    max_radius: float
    bounding_box_min: Tuple[float, float, float]
    bounding_box_max: Tuple[float, float, float]
    mass: float = 0.0
    center_of_mass: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    
    # Geometry and materials
    geometry: Dict[int, GeometryData] = field(default_factory=dict)  # subobject_id -> geometry
    materials: List[MaterialData] = field(default_factory=list)
    textures: List[str] = field(default_factory=list)
    
    # Subobject hierarchy
    subobjects: Dict[int, Dict[str, Any]] = field(default_factory=dict)
    
    # Gameplay elements
    subsystems: List[SubsystemData] = field(default_factory=list)
    weapon_points: List[WeaponPointData] = field(default_factory=list)
    docking_points: List[DockingPointData] = field(default_factory=list)
    thrusters: List[ThrusterData] = field(default_factory=list)
    
    # Special points and paths
    special_points: List[Dict[str, Any]] = field(default_factory=list)
    paths: List[Dict[str, Any]] = field(default_factory=list)
    
    # Shield mesh
    shield_mesh: Optional[Dict[str, Any]] = None
    
    # Metadata
    detail_levels: List[int] = field(default_factory=list)
    debris_objects: List[int] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            'filename': self.filename,
            'version': self.version,
            'max_radius': self.max_radius,
            'bounding_box_min': self.bounding_box_min,
            'bounding_box_max': self.bounding_box_max,
            'mass': self.mass,
            'center_of_mass': self.center_of_mass,
            'textures': self.textures,
            'subobjects': self.subobjects,
            'subsystems': [
                {
                    'name': s.name,
                    'subobject_number': s.subobject_number,
                    'hit_points': s.hit_points,
                    'position': s.position,
                    'radius': s.radius,
                    'subsystem_type': s.subsystem_type
                }
                for s in self.subsystems
            ],
            'weapon_points': [
                {
                    'name': w.name,
                    'position': w.position,
                    'normal': w.normal,
                    'weapon_type': w.weapon_type,
                    'bank_number': w.bank_number
                }
                for w in self.weapon_points
            ],
            'docking_points': [
                {
                    'name': d.name,
                    'position': d.position,
                    'normal': d.normal,
                    'dock_type': d.dock_type
                }
                for d in self.docking_points
            ],
            'thrusters': [
                {
                    'position': t.position,
                    'normal': t.normal,
                    'radius': t.radius
                }
                for t in self.thrusters
            ],
            'special_points': self.special_points,
            'paths': self.paths,
            'shield_mesh': self.shield_mesh,
            'detail_levels': self.detail_levels,
            'debris_objects': self.debris_objects
        }

class POFDataExtractor:
    """
    POF Data Extractor for converting POF files to structured data.
    
    Implements EPIC-003 DM-004 requirements for comprehensive POF data extraction
    suitable for conversion to Godot-compatible formats.
    """
    
    def __init__(self):
        """Initialize POF data extractor."""
        self.parser = POFParser()
    
    def extract_model_data(self, file_path: Path) -> Optional[POFModelData]:
        """
        Extract comprehensive model data from POF file.
        
        Args:
            file_path: Path to POF file
            
        Returns:
            POFModelData object with extracted data, or None if parsing failed
        """
        logger.info(f"Extracting model data from: {file_path}")
        
        # Parse POF file
        parsed_data = self.parser.parse(file_path)
        if not parsed_data:
            logger.error(f"Failed to parse POF file: {file_path}")
            return None
        
        try:
            # Create model data structure
            model_data = POFModelData(
                filename=file_path.name,
                version=parsed_data.get('version', 0)
            )
            
            # Extract header information
            self._extract_header_data(parsed_data, model_data)
            
            # Extract textures
            self._extract_texture_data(parsed_data, model_data)
            
            # Extract subobjects and geometry
            self._extract_subobject_data(parsed_data, model_data)
            
            # Extract gameplay elements
            self._extract_weapon_points(parsed_data, model_data)
            self._extract_docking_points(parsed_data, model_data)
            self._extract_thrusters(parsed_data, model_data)
            self._extract_special_points(parsed_data, model_data)
            self._extract_paths(parsed_data, model_data)
            
            # Extract shield mesh
            self._extract_shield_data(parsed_data, model_data)
            
            logger.info(f"Successfully extracted model data: {len(model_data.subobjects)} subobjects, "
                       f"{len(model_data.textures)} textures, {len(model_data.weapon_points)} weapon points")
            
            return model_data
            
        except Exception as e:
            logger.error(f"Error extracting model data from {file_path}: {e}", exc_info=True)
            return None
    
    def _extract_header_data(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract header information."""
        header = parsed_data.get('header', {})
        
        model_data.max_radius = header.get('max_radius', 0.0)
        model_data.bounding_box_min = tuple(header.get('min_bounding', [0.0, 0.0, 0.0]))
        model_data.bounding_box_max = tuple(header.get('max_bounding', [0.0, 0.0, 0.0]))
        model_data.mass = header.get('mass', 0.0)
        model_data.center_of_mass = tuple(header.get('mass_center', [0.0, 0.0, 0.0]))
        model_data.detail_levels = header.get('detail_levels', [])
        model_data.debris_objects = header.get('debris_pieces', [])
    
    def _extract_texture_data(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract texture information."""
        textures = parsed_data.get('textures', [])
        model_data.textures = textures
        
        # Create basic materials from textures
        for i, texture_path in enumerate(textures):
            material = MaterialData(
                name=f"material_{i}",
                texture_path=texture_path
            )
            model_data.materials.append(material)
    
    def _extract_subobject_data(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract subobject hierarchy and geometry."""
        objects = parsed_data.get('objects', [])
        
        for obj in objects:
            subobj_id = obj.get('number', -1)
            if subobj_id < 0:
                continue
            
            # Store subobject information
            model_data.subobjects[subobj_id] = {
                'name': obj.get('name', f'subobject_{subobj_id}'),
                'parent': obj.get('parent', -1),
                'offset': obj.get('offset', [0.0, 0.0, 0.0]),
                'radius': obj.get('radius', 0.0),
                'bounding_box_min': obj.get('min', [0.0, 0.0, 0.0]),
                'bounding_box_max': obj.get('max', [0.0, 0.0, 0.0]),
                'movement_type': obj.get('movement_type', 0),
                'movement_axis': obj.get('movement_axis', 0)
            }
            
            # Extract geometry if available
            # Note: Geometry extraction from BSP data would require additional parsing
            # This is a placeholder for the structure
            geometry = GeometryData()
            model_data.geometry[subobj_id] = geometry
    
    def _extract_weapon_points(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract weapon hardpoints."""
        # Gun points
        gun_points = parsed_data.get('gun_points', [])
        for bank_idx, bank in enumerate(gun_points):
            for slot_idx, slot in enumerate(bank):
                weapon_point = WeaponPointData(
                    name=f"gun_bank_{bank_idx}_slot_{slot_idx}",
                    position=tuple(slot.get('position', [0.0, 0.0, 0.0])),
                    normal=tuple(slot.get('normal', [0.0, 0.0, 1.0])),
                    weapon_type='gun',
                    bank_number=bank_idx
                )
                model_data.weapon_points.append(weapon_point)
        
        # Missile points
        missile_points = parsed_data.get('missile_points', [])
        for bank_idx, bank in enumerate(missile_points):
            for slot_idx, slot in enumerate(bank):
                weapon_point = WeaponPointData(
                    name=f"missile_bank_{bank_idx}_slot_{slot_idx}",
                    position=tuple(slot.get('position', [0.0, 0.0, 0.0])),
                    normal=tuple(slot.get('normal', [0.0, 0.0, 1.0])),
                    weapon_type='missile',
                    bank_number=bank_idx
                )
                model_data.weapon_points.append(weapon_point)
    
    def _extract_docking_points(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract docking points."""
        docking_points = parsed_data.get('docking_points', [])
        for i, dock in enumerate(docking_points):
            dock_point = DockingPointData(
                name=dock.get('name', f'dock_{i}'),
                position=tuple(dock.get('position', [0.0, 0.0, 0.0])),
                normal=tuple(dock.get('normal', [0.0, 0.0, 1.0])),
                dock_type=dock.get('type', 'generic')
            )
            model_data.docking_points.append(dock_point)
    
    def _extract_thrusters(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract thruster information."""
        thrusters = parsed_data.get('thrusters', [])
        for thruster in thrusters:
            thruster_data = ThrusterData(
                position=tuple(thruster.get('position', [0.0, 0.0, 0.0])),
                normal=tuple(thruster.get('normal', [0.0, 0.0, -1.0])),
                radius=thruster.get('radius', 0.1)
            )
            model_data.thrusters.append(thruster_data)
    
    def _extract_special_points(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract special points."""
        model_data.special_points = parsed_data.get('special_points', [])
    
    def _extract_paths(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract path information."""
        model_data.paths = parsed_data.get('paths', [])
    
    def _extract_shield_data(self, parsed_data: Dict[str, Any], model_data: POFModelData) -> None:
        """Extract shield mesh data."""
        shield_mesh = parsed_data.get('shield_mesh', {})
        if shield_mesh:
            model_data.shield_mesh = shield_mesh
    
    def extract_for_godot_conversion(self, file_path: Path) -> Optional[Dict[str, Any]]:
        """
        Extract POF data specifically formatted for Godot conversion.
        
        Args:
            file_path: Path to POF file
            
        Returns:
            Dictionary with Godot-optimized data structure
        """
        model_data = self.extract_model_data(file_path)
        if not model_data:
            return None
        
        # Convert to Godot-friendly format
        godot_data = {
            'metadata': {
                'source_file': model_data.filename,
                'pof_version': model_data.version,
                'max_radius': model_data.max_radius,
                'mass': model_data.mass,
                'center_of_mass': model_data.center_of_mass
            },
            'scene_tree': self._create_godot_scene_tree(model_data),
            'materials': self._create_godot_materials(model_data),
            'collision_shapes': self._create_collision_data(model_data),
            'gameplay_nodes': self._create_gameplay_nodes(model_data)
        }
        
        return godot_data
    
    def _create_godot_scene_tree(self, model_data: POFModelData) -> Dict[str, Any]:
        """Create Godot scene tree structure from subobjects."""
        scene_tree = {
            'root': {
                'name': Path(model_data.filename).stem,
                'type': 'Node3D',
                'children': []
            }
        }
        
        # Process subobjects in hierarchy order
        root_objects = [
            subobj_id for subobj_id, subobj in model_data.subobjects.items()
            if subobj.get('parent', -1) == -1
        ]
        
        for subobj_id in root_objects:
            node = self._create_subobject_node(subobj_id, model_data)
            scene_tree['root']['children'].append(node)
        
        return scene_tree
    
    def _create_subobject_node(self, subobj_id: int, model_data: POFModelData) -> Dict[str, Any]:
        """Create Godot node for a subobject."""
        subobj = model_data.subobjects[subobj_id]
        
        node = {
            'name': subobj['name'],
            'type': 'MeshInstance3D',
            'transform': {
                'position': subobj['offset'],
                'rotation': [0.0, 0.0, 0.0],
                'scale': [1.0, 1.0, 1.0]
            },
            'mesh_data': {
                'subobject_id': subobj_id,
                'geometry': model_data.geometry.get(subobj_id)
            },
            'children': []
        }
        
        # Add child subobjects
        children = [
            child_id for child_id, child_subobj in model_data.subobjects.items()
            if child_subobj.get('parent', -1) == subobj_id
        ]
        
        for child_id in children:
            child_node = self._create_subobject_node(child_id, model_data)
            node['children'].append(child_node)
        
        return node
    
    def _create_godot_materials(self, model_data: POFModelData) -> List[Dict[str, Any]]:
        """Create Godot material definitions."""
        godot_materials = []
        
        for material in model_data.materials:
            godot_material = {
                'name': material.name,
                'type': 'StandardMaterial3D',
                'properties': {
                    'albedo_texture': material.texture_path,
                    'albedo_color': material.diffuse_color,
                    'metallic': 0.0,
                    'roughness': 0.5
                }
            }
            godot_materials.append(godot_material)
        
        return godot_materials
    
    def _create_collision_data(self, model_data: POFModelData) -> Dict[str, Any]:
        """Create collision shape data for Godot."""
        return {
            'hull_shape': {
                'type': 'ConvexPolygonShape3D',
                'points': []  # Would be populated from geometry
            },
            'detail_shapes': []  # Per-subobject collision shapes
        }
    
    def _create_gameplay_nodes(self, model_data: POFModelData) -> Dict[str, Any]:
        """Create gameplay-specific node data."""
        return {
            'weapon_hardpoints': [
                {
                    'name': wp.name,
                    'position': wp.position,
                    'normal': wp.normal,
                    'type': wp.weapon_type,
                    'bank': wp.bank_number
                }
                for wp in model_data.weapon_points
            ],
            'docking_bays': [
                {
                    'name': dp.name,
                    'position': dp.position,
                    'normal': dp.normal,
                    'type': dp.dock_type
                }
                for dp in model_data.docking_points
            ],
            'engine_points': [
                {
                    'position': t.position,
                    'normal': t.normal,
                    'radius': t.radius
                }
                for t in model_data.thrusters
            ]
        }