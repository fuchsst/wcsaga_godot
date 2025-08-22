#!/usr/bin/env python3
"""
POF to OBJ Converter - EPIC-003 DM-005 Implementation

Converts parsed POF model data to intermediate OBJ format with proper vertex ordering,
UV mapping, and normal preservation for subsequent GLB conversion via Blender.

Based on WCS C++ analysis from source/code/model/modelinterp.cpp
"""

import logging
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, BinaryIO, Dict, List, Optional, Set, Tuple

from .pof_data_extractor import POFDataExtractor
from .pof_misc_parser import parse_bsp_data
from .vector3d import Vector3D

logger = logging.getLogger(__name__)

@dataclass
class OBJVertex:
    """Represents a vertex in OBJ format."""
    position: Tuple[float, float, float]
    normal: Tuple[float, float, float]
    uv: Tuple[float, float]
    
    def __hash__(self) -> int:
        return hash((self.position, self.normal, self.uv))

@dataclass
class OBJFace:
    """Represents a face in OBJ format with material reference."""
    vertex_indices: List[int]  # 1-based indices for OBJ format
    material_name: str
    
@dataclass
class OBJMaterial:
    """Material definition for MTL file."""
    name: str
    diffuse_texture: Optional[str] = None
    ambient_color: Tuple[float, float, float] = (0.2, 0.2, 0.2)
    diffuse_color: Tuple[float, float, float] = (0.8, 0.8, 0.8)
    specular_color: Tuple[float, float, float] = (1.0, 1.0, 1.0)
    specular_exponent: float = 30.0
    transparency: float = 1.0  # 1.0 = opaque, 0.0 = transparent

@dataclass 
class OBJConversionResult:
    """Results of POF to OBJ conversion."""
    vertices: List[OBJVertex]
    faces: List[OBJFace]
    materials: List[OBJMaterial]
    groups: Dict[str, List[int]]  # Group name -> face indices
    conversion_stats: Dict[str, Any]

class POFOBJConverter:
    """
    POF to OBJ converter implementing EPIC-003 DM-005 requirements.
    
    Converts parsed POF geometry data to intermediate OBJ format with materials,
    maintaining proper vertex ordering and UV mapping for Blender conversion.
    """
    
    def __init__(self):
        """Initialize POF to OBJ converter."""
        self.data_extractor = POFDataExtractor()
        self.coordinate_scale = 0.01  # POF uses cm, Godot uses m
        self.texture_extensions = {'.dds', '.tga', '.pcx', '.jpg', '.png'}
        
    def convert_pof_to_obj(self, pof_path: Path, obj_path: Path, 
                          texture_dir: Optional[Path] = None) -> bool:
        """
        Convert POF file to OBJ format with materials.
        
        Args:
            pof_path: Path to source POF file
            obj_path: Path to output OBJ file
            texture_dir: Directory containing texture files
            
        Returns:
            True if conversion successful, False otherwise
        """
        logger.info(f"Converting POF to OBJ: {pof_path} -> {obj_path}")
        
        try:
            # Extract POF data using the existing data extractor
            model_data = self.data_extractor.extract_model_data(pof_path)
            if not model_data:
                logger.error(f"Failed to extract model data from: {pof_path}")
                return False
            
            # Get Godot-optimized conversion data
            godot_data = self.data_extractor.extract_for_godot_conversion(pof_path)
            if not godot_data:
                logger.error(f"Failed to extract Godot data from: {pof_path}")
                return False
            
            # Convert to OBJ format
            conversion_result = self._convert_data_to_obj(model_data, godot_data, texture_dir)
            if not conversion_result:
                logger.error("Failed to convert POF data to OBJ format")
                return False
            
            # Write OBJ file
            if not self._write_obj_file(conversion_result, obj_path):
                logger.error(f"Failed to write OBJ file: {obj_path}")
                return False
            
            # Write MTL file
            mtl_path = obj_path.with_suffix('.mtl')
            if not self._write_mtl_file(conversion_result.materials, mtl_path, texture_dir):
                logger.error(f"Failed to write MTL file: {mtl_path}")
                return False
            
            # Log conversion statistics
            stats = conversion_result.conversion_stats
            logger.info(f"Conversion complete - Vertices: {stats['vertex_count']}, "
                       f"Faces: {stats['face_count']}, Materials: {stats['material_count']}")
            
            return True
            
        except Exception as e:
            logger.error(f"POF to OBJ conversion failed: {e}", exc_info=True)
            return False
    
    def _convert_data_to_obj(self, model_data: Any, godot_data: Dict[str, Any], 
                           texture_dir: Optional[Path]) -> Optional[OBJConversionResult]:
        """Convert extracted POF data to OBJ format structures."""
        try:
            vertices: List[OBJVertex] = []
            faces: List[OBJFace] = []
            materials: List[OBJMaterial] = []
            groups: Dict[str, List[int]] = {}
            vertex_map: Dict[OBJVertex, int] = {}  # Deduplicate vertices
            
            # Create materials from texture list
            material_map = self._create_materials(model_data.textures, texture_dir)
            materials = list(material_map.values())
            
            # Process each subobject for geometry
            face_index = 0
            
            for subobj in model_data.subobjects:
                subobj_name = subobj.get('name', f'subobject_{subobj.get("number", 0)}')
                group_faces: List[int] = []
                
                # Extract BSP geometry data
                bsp_geometry = self._extract_bsp_geometry(model_data.filename, subobj)
                if not bsp_geometry:
                    logger.warning(f"No geometry found for subobject: {subobj_name}")
                    continue
                
                # Process polygons
                for polygon in bsp_geometry['polygons']:
                    material_name = self._get_material_name(polygon['texture_index'], model_data.textures)
                    
                    # Convert polygon to triangles (POF polygons can be quads or triangles)
                    triangles = self._triangulate_polygon(polygon['indices'])
                    
                    for triangle_indices in triangles:
                        face_vertices = []
                        
                        # Create vertices for this face
                        for vertex_idx in triangle_indices:
                            if vertex_idx >= len(bsp_geometry['vertices']):
                                logger.warning(f"Invalid vertex index {vertex_idx} in {subobj_name}")
                                continue
                            
                            # Get vertex data
                            pos = bsp_geometry['vertices'][vertex_idx]
                            normal = bsp_geometry['normals'][vertex_idx] if vertex_idx < len(bsp_geometry['normals']) else (0.0, 0.0, 1.0)
                            uv = bsp_geometry['uvs'][vertex_idx] if vertex_idx < len(bsp_geometry['uvs']) else (0.0, 0.0)
                            
                            # Convert coordinates (POF: +Z forward, Godot: -Z forward)
                            vertex = OBJVertex(
                                position=self._convert_position(pos),
                                normal=self._convert_normal(normal),
                                uv=self._convert_uv(uv)
                            )
                            
                            # Deduplicate vertices
                            if vertex not in vertex_map:
                                vertex_map[vertex] = len(vertices)
                                vertices.append(vertex)
                            
                            face_vertices.append(vertex_map[vertex] + 1)  # OBJ uses 1-based indexing
                        
                        if len(face_vertices) == 3:  # Valid triangle
                            face = OBJFace(vertex_indices=face_vertices, material_name=material_name)
                            faces.append(face)
                            group_faces.append(face_index)
                            face_index += 1
                
                if group_faces:
                    groups[subobj_name] = group_faces
            
            # Compile conversion statistics
            conversion_stats = {
                'vertex_count': len(vertices),
                'face_count': len(faces),
                'material_count': len(materials),
                'group_count': len(groups),
                'subobject_count': len(model_data.subobjects)
            }
            
            return OBJConversionResult(
                vertices=vertices,
                faces=faces,
                materials=materials,
                groups=groups,
                conversion_stats=conversion_stats
            )
            
        except Exception as e:
            logger.error(f"Failed to convert POF data to OBJ format: {e}", exc_info=True)
            return None
    
    def _extract_bsp_geometry(self, filename: str, subobj: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Extract BSP geometry data from subobject."""
        try:
            # Get BSP data offset and size
            bsp_offset = subobj.get('bsp_data_offset', -1)
            bsp_size = subobj.get('bsp_data_size', 0)
            
            if bsp_offset < 0 or bsp_size <= 0:
                logger.warning(f"No BSP data for subobject {subobj.get('number', '?')}")
                return None
            
            # Read BSP data from original POF file
            # Note: In production, this would read from the actual POF file
            # For now, we'll use the parsed data from the data extractor
            return {
                'vertices': subobj.get('vertices', []),
                'normals': subobj.get('normals', []),
                'uvs': subobj.get('uvs', []),
                'polygons': subobj.get('polygons', [])
            }
            
        except Exception as e:
            logger.error(f"Failed to extract BSP geometry: {e}")
            return None
    
    def _create_materials(self, textures: List[str], texture_dir: Optional[Path]) -> Dict[str, OBJMaterial]:
        """Create material definitions from texture list."""
        material_map: Dict[str, OBJMaterial] = {}
        
        for idx, texture_name in enumerate(textures):
            if not texture_name or texture_name.lower() in ('none', ''):
                material_name = f"material_{idx:03d}_default"
                material_map[material_name] = OBJMaterial(
                    name=material_name,
                    diffuse_color=(0.7, 0.7, 0.7)
                )
                continue
            
            # Find actual texture file
            texture_file = self._find_texture_file(texture_name, texture_dir)
            material_name = Path(texture_name).stem
            
            material_map[material_name] = OBJMaterial(
                name=material_name,
                diffuse_texture=texture_file,
                diffuse_color=(1.0, 1.0, 1.0) if texture_file else (0.7, 0.7, 0.7)
            )
        
        # Ensure default material exists
        if 'default' not in material_map:
            material_map['default'] = OBJMaterial(
                name='default',
                diffuse_color=(0.5, 0.5, 0.5)
            )
        
        return material_map
    
    def _find_texture_file(self, texture_name: str, texture_dir: Optional[Path]) -> Optional[str]:
        """Find actual texture file with proper extension."""
        if not texture_dir or not texture_dir.exists():
            return texture_name  # Return original name if no directory provided
        
        base_name = Path(texture_name).stem
        
        # Try different extensions
        for ext in self.texture_extensions:
            texture_path = texture_dir / f"{base_name}{ext}"
            if texture_path.exists():
                return texture_path.name
        
        # Return original name if not found
        return texture_name
    
    def _get_material_name(self, texture_index: int, textures: List[str]) -> str:
        """Get material name for texture index."""
        if texture_index < 0 or texture_index >= len(textures):
            return 'default'
        
        texture_name = textures[texture_index]
        if not texture_name or texture_name.lower() in ('none', ''):
            return 'default'
        
        return Path(texture_name).stem
    
    def _triangulate_polygon(self, indices: List[int]) -> List[List[int]]:
        """Triangulate polygon indices (convert quads to triangles)."""
        if len(indices) < 3:
            return []
        elif len(indices) == 3:
            return [indices]
        elif len(indices) == 4:
            # Convert quad to two triangles
            return [
                [indices[0], indices[1], indices[2]],
                [indices[0], indices[2], indices[3]]
            ]
        else:
            # Fan triangulation for polygons with >4 vertices
            triangles = []
            for i in range(1, len(indices) - 1):
                triangles.append([indices[0], indices[i], indices[i + 1]])
            return triangles
    
    def _convert_position(self, pos: Tuple[float, float, float]) -> Tuple[float, float, float]:
        """Convert POF position to Godot coordinates with proper scaling."""
        x, y, z = pos
        return (
            x * self.coordinate_scale,      # X unchanged
            y * self.coordinate_scale,      # Y unchanged  
            -z * self.coordinate_scale      # Z inverted (POF: +Z forward, Godot: -Z forward)
        )
    
    def _convert_normal(self, normal: Tuple[float, float, float]) -> Tuple[float, float, float]:
        """Convert POF normal to Godot coordinates (no scaling, just axis conversion)."""
        x, y, z = normal
        return (x, y, -z)  # Z inverted for coordinate system conversion
    
    def _convert_uv(self, uv: Tuple[float, float]) -> Tuple[float, float]:
        """Convert POF UV coordinates to OBJ format."""
        u, v = uv
        return (u, 1.0 - v)  # Flip V coordinate (POF: V=0 at bottom, OBJ: V=0 at top)
    
    def _write_obj_file(self, result: OBJConversionResult, obj_path: Path) -> bool:
        """Write OBJ file with vertices, faces, and groups."""
        try:
            with open(obj_path, 'w', encoding='utf-8') as f:
                # Write header
                f.write(f"# OBJ file generated from POF model\n")
                f.write(f"# Vertices: {len(result.vertices)}, Faces: {len(result.faces)}\n")
                f.write(f"mtllib {obj_path.with_suffix('.mtl').name}\n\n")
                
                # Write vertices
                f.write("# Vertices\n")
                for vertex in result.vertices:
                    f.write(f"v {vertex.position[0]:.6f} {vertex.position[1]:.6f} {vertex.position[2]:.6f}\n")
                
                f.write("\n# Normals\n")
                for vertex in result.vertices:
                    f.write(f"vn {vertex.normal[0]:.6f} {vertex.normal[1]:.6f} {vertex.normal[2]:.6f}\n")
                
                f.write("\n# Texture coordinates\n")
                for vertex in result.vertices:
                    f.write(f"vt {vertex.uv[0]:.6f} {vertex.uv[1]:.6f}\n")
                
                # Write faces by material
                f.write("\n# Faces\n")
                current_material = None
                current_group = None
                
                for face_idx, face in enumerate(result.faces):
                    # Switch material if needed
                    if face.material_name != current_material:
                        current_material = face.material_name
                        f.write(f"\nusemtl {current_material}\n")
                    
                    # Switch group if needed
                    face_group = self._get_face_group(face_idx, result.groups)
                    if face_group != current_group:
                        current_group = face_group
                        f.write(f"g {current_group}\n")
                    
                    # Write face (vertex/texture/normal indices)
                    face_line = "f"
                    for v_idx in face.vertex_indices:
                        face_line += f" {v_idx}/{v_idx}/{v_idx}"
                    f.write(f"{face_line}\n")
            
            logger.info(f"Successfully wrote OBJ file: {obj_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to write OBJ file {obj_path}: {e}", exc_info=True)
            return False
    
    def _write_mtl_file(self, materials: List[OBJMaterial], mtl_path: Path, 
                       texture_dir: Optional[Path]) -> bool:
        """Write MTL material file."""
        try:
            with open(mtl_path, 'w', encoding='utf-8') as f:
                f.write("# MTL file generated from POF model\n")
                f.write(f"# Materials: {len(materials)}\n\n")
                
                for material in materials:
                    f.write(f"newmtl {material.name}\n")
                    f.write(f"Ka {material.ambient_color[0]:.3f} {material.ambient_color[1]:.3f} {material.ambient_color[2]:.3f}\n")
                    f.write(f"Kd {material.diffuse_color[0]:.3f} {material.diffuse_color[1]:.3f} {material.diffuse_color[2]:.3f}\n")
                    f.write(f"Ks {material.specular_color[0]:.3f} {material.specular_color[1]:.3f} {material.specular_color[2]:.3f}\n")
                    f.write(f"Ns {material.specular_exponent:.1f}\n")
                    f.write(f"d {material.transparency:.3f}\n")
                    
                    if material.diffuse_texture:
                        f.write(f"map_Kd {material.diffuse_texture}\n")
                    
                    f.write("\n")
            
            logger.info(f"Successfully wrote MTL file: {mtl_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to write MTL file {mtl_path}: {e}", exc_info=True)
            return False
    
    def _get_face_group(self, face_idx: int, groups: Dict[str, List[int]]) -> str:
        """Get group name for face index."""
        for group_name, face_indices in groups.items():
            if face_idx in face_indices:
                return group_name
        return "default"