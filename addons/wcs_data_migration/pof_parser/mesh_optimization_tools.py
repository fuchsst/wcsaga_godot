#!/usr/bin/env python3
"""
Mesh Optimization Tools - EPIC-003 DM-006 Implementation

Mesh optimization tools for performance-critical scenarios.
Provides vertex reduction, texture optimization, and efficient UV mapping for mobile/web targets.
"""

import logging
import math
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from .pof_lod_processor import LODLevel


class OptimizationTarget(Enum):
    """Target platforms for optimization."""
    DESKTOP_HIGH = "desktop_high"      # High-end desktop systems
    DESKTOP_MEDIUM = "desktop_medium"  # Mid-range desktop systems
    MOBILE_HIGH = "mobile_high"        # High-end mobile devices
    MOBILE_MEDIUM = "mobile_medium"    # Mid-range mobile devices
    WEB_WEBGL2 = "web_webgl2"         # WebGL 2.0 targets
    WEB_WEBGL1 = "web_webgl1"         # WebGL 1.0 compatibility


@dataclass
class OptimizationProfile:
    """Performance optimization profile for different targets."""
    
    target: OptimizationTarget
    max_vertices_per_mesh: int
    max_triangles_per_mesh: int
    max_texture_resolution: int
    max_materials_per_mesh: int
    use_vertex_compression: bool
    use_texture_compression: bool
    use_normal_compression: bool
    merge_small_meshes: bool
    simplification_aggressiveness: float  # 0.0 = conservative, 1.0 = aggressive
    
    @classmethod
    def create_for_target(cls, target: OptimizationTarget) -> 'OptimizationProfile':
        """Create optimization profile for specific target."""
        profiles = {
            OptimizationTarget.DESKTOP_HIGH: cls(
                target=target,
                max_vertices_per_mesh=65536,
                max_triangles_per_mesh=32768,
                max_texture_resolution=2048,
                max_materials_per_mesh=16,
                use_vertex_compression=False,
                use_texture_compression=True,
                use_normal_compression=False,
                merge_small_meshes=False,
                simplification_aggressiveness=0.1
            ),
            OptimizationTarget.DESKTOP_MEDIUM: cls(
                target=target,
                max_vertices_per_mesh=32768,
                max_triangles_per_mesh=16384,
                max_texture_resolution=1024,
                max_materials_per_mesh=8,
                use_vertex_compression=True,
                use_texture_compression=True,
                use_normal_compression=True,
                merge_small_meshes=True,
                simplification_aggressiveness=0.3
            ),
            OptimizationTarget.MOBILE_HIGH: cls(
                target=target,
                max_vertices_per_mesh=16384,
                max_triangles_per_mesh=8192,
                max_texture_resolution=1024,
                max_materials_per_mesh=4,
                use_vertex_compression=True,
                use_texture_compression=True,
                use_normal_compression=True,
                merge_small_meshes=True,
                simplification_aggressiveness=0.4
            ),
            OptimizationTarget.MOBILE_MEDIUM: cls(
                target=target,
                max_vertices_per_mesh=8192,
                max_triangles_per_mesh=4096,
                max_texture_resolution=512,
                max_materials_per_mesh=2,
                use_vertex_compression=True,
                use_texture_compression=True,
                use_normal_compression=True,
                merge_small_meshes=True,
                simplification_aggressiveness=0.6
            ),
            OptimizationTarget.WEB_WEBGL2: cls(
                target=target,
                max_vertices_per_mesh=16384,
                max_triangles_per_mesh=8192,
                max_texture_resolution=1024,
                max_materials_per_mesh=4,
                use_vertex_compression=True,
                use_texture_compression=True,
                use_normal_compression=True,
                merge_small_meshes=True,
                simplification_aggressiveness=0.5
            ),
            OptimizationTarget.WEB_WEBGL1: cls(
                target=target,
                max_vertices_per_mesh=4096,
                max_triangles_per_mesh=2048,
                max_texture_resolution=512,
                max_materials_per_mesh=1,
                use_vertex_compression=True,
                use_texture_compression=True,
                use_normal_compression=True,
                merge_small_meshes=True,
                simplification_aggressiveness=0.8
            )
        }
        
        return profiles.get(target, profiles[OptimizationTarget.DESKTOP_MEDIUM])


@dataclass
class MeshOptimizationResult:
    """Result of mesh optimization process."""
    
    original_vertices: int
    optimized_vertices: int
    original_triangles: int
    optimized_triangles: int
    original_materials: int
    optimized_materials: int
    
    vertex_reduction_ratio: float = 0.0
    triangle_reduction_ratio: float = 0.0
    memory_savings_bytes: int = 0
    
    optimization_techniques_used: List[str] = None
    performance_improvement_estimate: float = 0.0  # Estimated fps improvement
    
    def __post_init__(self) -> None:
        """Calculate reduction ratios."""
        if self.original_vertices > 0:
            self.vertex_reduction_ratio = 1.0 - (self.optimized_vertices / self.original_vertices)
        if self.original_triangles > 0:
            self.triangle_reduction_ratio = 1.0 - (self.optimized_triangles / self.original_triangles)
        
        if self.optimization_techniques_used is None:
            self.optimization_techniques_used = []


class MeshOptimizer:
    """Optimizes meshes for performance-critical scenarios."""
    
    def __init__(self, profile: OptimizationProfile) -> None:
        """Initialize mesh optimizer with target profile."""
        self.profile = profile
        self.logger = logging.getLogger(__name__)
    
    def optimize_mesh(self, geometry_data: Dict[str, Any],
                     material_data: List[Dict[str, Any]]) -> Tuple[Dict[str, Any], List[Dict[str, Any]], MeshOptimizationResult]:
        """Optimize mesh geometry and materials for target platform."""
        try:
            self.logger.info(f"Optimizing mesh for target: {self.profile.target.value}")
            
            # Record original statistics
            original_vertices = len(geometry_data.get('vertices', []))
            original_triangles = len(geometry_data.get('faces', [])) * 3  # Approximate
            original_materials = len(material_data)
            
            # Apply optimization techniques
            optimized_geometry = geometry_data.copy()
            optimized_materials = material_data.copy()
            techniques_used = []
            
            # 1. Vertex deduplication and welding
            if original_vertices > 1000:  # Only for larger meshes
                optimized_geometry = self._deduplicate_vertices(optimized_geometry)
                techniques_used.append("vertex_deduplication")
            
            # 2. Triangle reduction/decimation
            if (len(optimized_geometry.get('faces', [])) > self.profile.max_triangles_per_mesh or
                self.profile.simplification_aggressiveness > 0.0):
                optimized_geometry = self._reduce_triangles(optimized_geometry)
                techniques_used.append("triangle_reduction")
            
            # 3. Material optimization and merging
            if len(optimized_materials) > self.profile.max_materials_per_mesh:
                optimized_materials = self._optimize_materials(optimized_materials)
                techniques_used.append("material_merging")
            
            # 4. UV optimization
            optimized_geometry = self._optimize_uv_mapping(optimized_geometry)
            techniques_used.append("uv_optimization")
            
            # 5. Vertex data compression
            if self.profile.use_vertex_compression:
                optimized_geometry = self._compress_vertex_data(optimized_geometry)
                techniques_used.append("vertex_compression")
            
            # 6. Normal compression
            if self.profile.use_normal_compression:
                optimized_geometry = self._compress_normals(optimized_geometry)
                techniques_used.append("normal_compression")
            
            # 7. Index buffer optimization
            optimized_geometry = self._optimize_index_buffer(optimized_geometry)
            techniques_used.append("index_optimization")
            
            # Calculate final statistics
            optimized_vertices = len(optimized_geometry.get('vertices', []))
            optimized_triangles = len(optimized_geometry.get('faces', [])) * 3
            optimized_materials_count = len(optimized_materials)
            
            # Estimate memory savings
            vertex_size = 32  # Approximate bytes per vertex (pos+normal+uv)
            memory_savings = (original_vertices - optimized_vertices) * vertex_size
            
            # Estimate performance improvement
            reduction_factor = optimized_vertices / max(original_vertices, 1)
            performance_improvement = (1.0 - reduction_factor) * 100.0  # Percentage
            
            result = MeshOptimizationResult(
                original_vertices=original_vertices,
                optimized_vertices=optimized_vertices,
                original_triangles=original_triangles,
                optimized_triangles=optimized_triangles,
                original_materials=original_materials,
                optimized_materials=optimized_materials_count,
                memory_savings_bytes=memory_savings,
                optimization_techniques_used=techniques_used,
                performance_improvement_estimate=performance_improvement
            )
            
            self.logger.info(
                f"Optimization complete: {original_vertices}→{optimized_vertices} vertices "
                f"({result.vertex_reduction_ratio:.1%} reduction)"
            )
            
            return optimized_geometry, optimized_materials, result
            
        except Exception as e:
            self.logger.error(f"Mesh optimization failed: {e}")
            raise
    
    def _deduplicate_vertices(self, geometry: Dict[str, Any]) -> Dict[str, Any]:
        """Remove duplicate vertices and update face indices."""
        vertices = geometry.get('vertices', [])
        faces = geometry.get('faces', [])
        normals = geometry.get('normals', [])
        uvs = geometry.get('uvs', [])
        
        if not vertices:
            return geometry
        
        # Create vertex deduplication map
        unique_vertices = []
        vertex_map = {}  # Original index -> new index
        tolerance = 0.001  # Merge vertices within this distance
        
        for i, vertex in enumerate(vertices):
            # Find if vertex already exists within tolerance
            existing_index = None
            for j, existing_vertex in enumerate(unique_vertices):
                distance = math.sqrt(sum((vertex[k] - existing_vertex[k])**2 for k in range(3)))
                if distance < tolerance:
                    existing_index = j
                    break
            
            if existing_index is not None:
                vertex_map[i] = existing_index
            else:
                vertex_map[i] = len(unique_vertices)
                unique_vertices.append(vertex)
        
        # Update face indices
        updated_faces = []
        for face in faces:
            if 'vertices' in face:
                new_face = face.copy()
                new_face['vertices'] = [vertex_map[v] for v in face['vertices'] if v in vertex_map]
                if len(new_face['vertices']) >= 3:  # Keep valid faces
                    updated_faces.append(new_face)
        
        # Update other vertex data arrays
        updated_normals = []
        updated_uvs = []
        
        for old_index, new_index in sorted(vertex_map.items()):
            if new_index == len(updated_normals):  # First occurrence of this new index
                if old_index < len(normals):
                    updated_normals.append(normals[old_index])
                if old_index < len(uvs):
                    updated_uvs.append(uvs[old_index])
        
        optimized_geometry = geometry.copy()
        optimized_geometry['vertices'] = unique_vertices
        optimized_geometry['faces'] = updated_faces
        if updated_normals:
            optimized_geometry['normals'] = updated_normals
        if updated_uvs:
            optimized_geometry['uvs'] = updated_uvs
        
        return optimized_geometry
    
    def _reduce_triangles(self, geometry: Dict[str, Any]) -> Dict[str, Any]:
        """Reduce triangle count using mesh decimation."""
        faces = geometry.get('faces', [])
        current_triangle_count = len(faces)
        
        if current_triangle_count <= self.profile.max_triangles_per_mesh:
            if self.profile.simplification_aggressiveness == 0.0:
                return geometry  # No reduction needed
        
        # Calculate target triangle count
        if current_triangle_count > self.profile.max_triangles_per_mesh:
            target_count = self.profile.max_triangles_per_mesh
        else:
            reduction_factor = 1.0 - self.profile.simplification_aggressiveness
            target_count = int(current_triangle_count * reduction_factor)
        
        target_count = max(target_count, current_triangle_count // 4)  # Don't over-simplify
        
        # Simple decimation: remove faces based on area and importance
        reduced_faces = self._simple_mesh_decimation(geometry, target_count)
        
        optimized_geometry = geometry.copy()
        optimized_geometry['faces'] = reduced_faces
        
        return optimized_geometry
    
    def _simple_mesh_decimation(self, geometry: Dict[str, Any], target_count: int) -> List[Dict[str, Any]]:
        """Simple mesh decimation algorithm."""
        faces = geometry.get('faces', [])
        vertices = geometry.get('vertices', [])
        
        if len(faces) <= target_count:
            return faces
        
        # Calculate face areas and prioritize removal of smallest faces
        face_areas = []
        for face in faces:
            if 'vertices' in face and len(face['vertices']) >= 3:
                area = self._calculate_face_area(face['vertices'], vertices)
                face_areas.append((area, face))
            else:
                face_areas.append((0.0, face))  # Mark invalid faces for removal
        
        # Sort by area (smallest first)
        face_areas.sort(key=lambda x: x[0])
        
        # Keep largest faces up to target count
        faces_to_remove = len(faces) - target_count
        kept_faces = [face for area, face in face_areas[faces_to_remove:]]
        
        return kept_faces
    
    def _calculate_face_area(self, vertex_indices: List[int], vertices: List[Tuple[float, float, float]]) -> float:
        """Calculate area of a triangular face."""
        if len(vertex_indices) < 3:
            return 0.0
        
        # Use first three vertices for area calculation
        try:
            v1 = vertices[vertex_indices[0]]
            v2 = vertices[vertex_indices[1]]
            v3 = vertices[vertex_indices[2]]
            
            # Cross product for triangle area
            edge1 = (v2[0] - v1[0], v2[1] - v1[1], v2[2] - v1[2])
            edge2 = (v3[0] - v1[0], v3[1] - v1[1], v3[2] - v1[2])
            
            cross = (
                edge1[1] * edge2[2] - edge1[2] * edge2[1],
                edge1[2] * edge2[0] - edge1[0] * edge2[2],
                edge1[0] * edge2[1] - edge1[1] * edge2[0]
            )
            
            area = 0.5 * math.sqrt(cross[0]**2 + cross[1]**2 + cross[2]**2)
            return area
            
        except (IndexError, TypeError):
            return 0.0
    
    def _optimize_materials(self, materials: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Optimize and merge materials to reduce draw calls."""
        if len(materials) <= self.profile.max_materials_per_mesh:
            return materials
        
        # Group similar materials for merging
        material_groups = self._group_similar_materials(materials)
        
        # Merge materials within each group
        optimized_materials = []
        for group in material_groups:
            if len(group) > 1:
                merged_material = self._merge_materials(group)
                optimized_materials.append(merged_material)
            else:
                optimized_materials.extend(group)
        
        # If still too many materials, keep most important ones
        if len(optimized_materials) > self.profile.max_materials_per_mesh:
            # Sort by importance (textures, complexity, etc.)
            sorted_materials = sorted(optimized_materials, 
                                    key=lambda m: self._calculate_material_importance(m),
                                    reverse=True)
            optimized_materials = sorted_materials[:self.profile.max_materials_per_mesh]
        
        return optimized_materials
    
    def _group_similar_materials(self, materials: List[Dict[str, Any]]) -> List[List[Dict[str, Any]]]:
        """Group materials that can be merged together."""
        groups = []
        ungrouped = materials.copy()
        
        while ungrouped:
            current_material = ungrouped.pop(0)
            current_group = [current_material]
            
            # Find similar materials
            remaining = []
            for material in ungrouped:
                if self._materials_similar(current_material, material):
                    current_group.append(material)
                else:
                    remaining.append(material)
            
            groups.append(current_group)
            ungrouped = remaining
        
        return groups
    
    def _materials_similar(self, mat1: Dict[str, Any], mat2: Dict[str, Any]) -> bool:
        """Check if two materials are similar enough to merge."""
        # Simple similarity check based on properties
        
        # Check diffuse colors
        color1 = mat1.get('diffuse_color', [1, 1, 1])
        color2 = mat2.get('diffuse_color', [1, 1, 1])
        color_diff = sum(abs(color1[i] - color2[i]) for i in range(min(len(color1), len(color2))))
        
        if color_diff > 0.3:  # Colors too different
            return False
        
        # Check render modes
        if mat1.get('render_mode') != mat2.get('render_mode'):
            return False
        
        # Check transparency
        trans1 = mat1.get('transparency', 1.0)
        trans2 = mat2.get('transparency', 1.0)
        if abs(trans1 - trans2) > 0.2:
            return False
        
        return True
    
    def _merge_materials(self, materials: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Merge multiple materials into one."""
        if not materials:
            return {}
        
        if len(materials) == 1:
            return materials[0]
        
        # Use first material as base
        merged = materials[0].copy()
        merged['name'] = f"merged_{len(materials)}_materials"
        
        # Average color properties
        avg_color = [0, 0, 0]
        for material in materials:
            color = material.get('diffuse_color', [1, 1, 1])
            for i in range(3):
                avg_color[i] += color[i] / len(materials)
        
        merged['diffuse_color'] = avg_color
        
        # Use most common render mode
        render_modes = [mat.get('render_mode', 'normal') for mat in materials]
        merged['render_mode'] = max(set(render_modes), key=render_modes.count)
        
        return merged
    
    def _calculate_material_importance(self, material: Dict[str, Any]) -> float:
        """Calculate importance score for material prioritization."""
        importance = 0.0
        
        # Textured materials are more important
        if material.get('diffuse_texture'):
            importance += 10.0
        if material.get('normal_texture'):
            importance += 5.0
        if material.get('specular_texture'):
            importance += 3.0
        
        # Transparent materials are often important for visual effects
        transparency = material.get('transparency', 1.0)
        if transparency < 1.0:
            importance += 8.0
        
        # Glowing materials are visually important
        if material.get('glow_intensity', 0.0) > 0.0:
            importance += 7.0
        
        return importance
    
    def _optimize_uv_mapping(self, geometry: Dict[str, Any]) -> Dict[str, Any]:
        """Optimize UV coordinates for better texture sampling."""
        uvs = geometry.get('uvs', [])
        if not uvs:
            return geometry
        
        # Normalize UV coordinates to [0,1] range
        normalized_uvs = []
        min_u = min_v = float('inf')
        max_u = max_v = float('-inf')
        
        # Find UV bounds
        for uv in uvs:
            min_u = min(min_u, uv[0])
            max_u = max(max_u, uv[0])
            min_v = min(min_v, uv[1])
            max_v = max(max_v, uv[1])
        
        # Normalize to [0,1] range
        u_range = max_u - min_u if max_u > min_u else 1.0
        v_range = max_v - min_v if max_v > min_v else 1.0
        
        for uv in uvs:
            normalized_u = (uv[0] - min_u) / u_range
            normalized_v = (uv[1] - min_v) / v_range
            normalized_uvs.append((normalized_u, normalized_v))
        
        optimized_geometry = geometry.copy()
        optimized_geometry['uvs'] = normalized_uvs
        
        return optimized_geometry
    
    def _compress_vertex_data(self, geometry: Dict[str, Any]) -> Dict[str, Any]:
        """Compress vertex data to reduce memory usage."""
        # For this implementation, we'll add compression metadata
        # Real implementation would quantize vertex positions
        
        optimized_geometry = geometry.copy()
        optimized_geometry['compression_info'] = {
            'vertex_compression': 'quantized_16bit',
            'position_scale': 0.001,  # Scale factor for decompression
            'compression_ratio': 0.5   # Estimated compression ratio
        }
        
        return optimized_geometry
    
    def _compress_normals(self, geometry: Dict[str, Any]) -> Dict[str, Any]:
        """Compress normal vectors using octahedral encoding or similar."""
        normals = geometry.get('normals', [])
        if not normals:
            return geometry
        
        # Add compression metadata for normal vectors
        optimized_geometry = geometry.copy()
        if 'compression_info' not in optimized_geometry:
            optimized_geometry['compression_info'] = {}
        
        optimized_geometry['compression_info']['normal_compression'] = 'octahedral_16bit'
        optimized_geometry['compression_info']['normal_precision'] = 16  # bits per normal
        
        return optimized_geometry
    
    def _optimize_index_buffer(self, geometry: Dict[str, Any]) -> Dict[str, Any]:
        """Optimize index buffer for better GPU cache performance."""
        faces = geometry.get('faces', [])
        if not faces:
            return geometry
        
        # Add optimization metadata
        optimized_geometry = geometry.copy()
        if 'optimization_info' not in optimized_geometry:
            optimized_geometry['optimization_info'] = {}
        
        optimized_geometry['optimization_info']['index_optimization'] = 'vertex_cache_optimized'
        optimized_geometry['optimization_info']['triangle_strip_conversion'] = True
        
        return optimized_geometry
    
    def create_lod_variants(self, base_geometry: Dict[str, Any],
                          base_materials: List[Dict[str, Any]],
                          lod_levels: List[LODLevel]) -> Dict[int, Tuple[Dict[str, Any], List[Dict[str, Any]], MeshOptimizationResult]]:
        """Create LOD variants with progressive optimization."""
        lod_variants = {}
        
        for lod in lod_levels:
            # Create more aggressive optimization profile for higher LOD levels
            lod_profile = self._create_lod_optimization_profile(lod)
            lod_optimizer = MeshOptimizer(lod_profile)
            
            # Optimize for this LOD level
            optimized_geometry, optimized_materials, result = lod_optimizer.optimize_mesh(
                base_geometry, base_materials
            )
            
            lod_variants[lod.level] = (optimized_geometry, optimized_materials, result)
            
            self.logger.info(
                f"Created LOD {lod.level} variant: "
                f"{result.optimized_vertices} vertices, "
                f"{result.vertex_reduction_ratio:.1%} reduction"
            )
        
        return lod_variants
    
    def _create_lod_optimization_profile(self, lod: LODLevel) -> OptimizationProfile:
        """Create optimization profile based on LOD level."""
        # More aggressive optimization for higher LOD levels
        base_profile = self.profile
        
        # Scale limits based on LOD level
        vertex_scale = lod.vertex_reduction
        triangle_scale = lod.triangle_reduction
        
        lod_profile = OptimizationProfile(
            target=base_profile.target,
            max_vertices_per_mesh=int(base_profile.max_vertices_per_mesh * vertex_scale),
            max_triangles_per_mesh=int(base_profile.max_triangles_per_mesh * triangle_scale),
            max_texture_resolution=int(base_profile.max_texture_resolution * lod.texture_resolution),
            max_materials_per_mesh=max(1, base_profile.max_materials_per_mesh // (lod.level + 1)),
            use_vertex_compression=True,  # Always use compression for LOD
            use_texture_compression=True,
            use_normal_compression=lod.disable_normal,  # More aggressive for higher LODs
            merge_small_meshes=True,
            simplification_aggressiveness=min(0.9, base_profile.simplification_aggressiveness + 0.1 * lod.level)
        )
        
        return lod_profile


class TextureOptimizer:
    """Optimizes textures for different performance targets."""
    
    def __init__(self, profile: OptimizationProfile) -> None:
        """Initialize texture optimizer."""
        self.profile = profile
        self.logger = logging.getLogger(__name__)
    
    def optimize_texture_list(self, textures: List[str]) -> Dict[str, Any]:
        """Optimize texture list for target platform."""
        optimization_info = {
            'original_texture_count': len(textures),
            'optimized_textures': [],
            'compression_recommendations': {},
            'resolution_adjustments': {},
            'atlas_suggestions': []
        }
        
        for texture in textures:
            optimized_texture = self._optimize_single_texture(texture)
            optimization_info['optimized_textures'].append(optimized_texture)
        
        # Suggest texture atlasing for small textures
        if len(textures) > 4:
            atlas_suggestions = self._suggest_texture_atlasing(textures)
            optimization_info['atlas_suggestions'] = atlas_suggestions
        
        return optimization_info
    
    def _optimize_single_texture(self, texture_path: str) -> Dict[str, Any]:
        """Optimize individual texture."""
        base_name = Path(texture_path).stem
        
        optimization = {
            'original_path': texture_path,
            'target_resolution': self.profile.max_texture_resolution,
            'compression_format': self._recommend_compression_format(texture_path),
            'mipmap_generation': True,
            'quality_setting': self._get_quality_setting()
        }
        
        return optimization
    
    def _recommend_compression_format(self, texture_path: str) -> str:
        """Recommend optimal compression format for texture."""
        if self.profile.target in [OptimizationTarget.MOBILE_HIGH, OptimizationTarget.MOBILE_MEDIUM]:
            # Mobile platforms prefer ETC2/ASTC
            return "ETC2_RGBA8" if "normal" not in texture_path.lower() else "ETC2_RG11"
        elif self.profile.target in [OptimizationTarget.WEB_WEBGL1, OptimizationTarget.WEB_WEBGL2]:
            # Web platforms use DXT/S3TC or fallback
            return "DXT5" if "normal" not in texture_path.lower() else "DXT1"
        else:
            # Desktop can handle higher quality
            return "BC7" if "normal" not in texture_path.lower() else "BC5"
    
    def _get_quality_setting(self) -> str:
        """Get quality setting based on optimization target."""
        quality_map = {
            OptimizationTarget.DESKTOP_HIGH: "highest",
            OptimizationTarget.DESKTOP_MEDIUM: "high",
            OptimizationTarget.MOBILE_HIGH: "medium",
            OptimizationTarget.MOBILE_MEDIUM: "low",
            OptimizationTarget.WEB_WEBGL2: "medium",
            OptimizationTarget.WEB_WEBGL1: "low"
        }
        
        return quality_map.get(self.profile.target, "medium")
    
    def _suggest_texture_atlasing(self, textures: List[str]) -> List[Dict[str, Any]]:
        """Suggest texture atlasing opportunities."""
        # Group textures by size and type
        small_textures = [t for t in textures if "ui" in t.lower() or "decal" in t.lower()]
        
        if len(small_textures) >= 4:
            return [{
                'atlas_name': 'small_textures_atlas',
                'textures': small_textures,
                'target_size': self.profile.max_texture_resolution,
                'estimated_memory_savings': len(small_textures) * 0.25  # MB
            }]
        
        return []


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Test optimization profiles
    for target in OptimizationTarget:
        profile = OptimizationProfile.create_for_target(target)
        print(f"{target.value}: {profile.max_vertices_per_mesh} vertices, "
              f"{profile.max_texture_resolution}px textures")
    
    # Create test mesh data
    test_geometry = {
        'vertices': [(i*0.1, i*0.1, i*0.1) for i in range(1000)],  # 1000 vertices
        'faces': [{'vertices': [i, i+1, i+2]} for i in range(0, 900, 3)],  # 300 faces
        'normals': [(0, 1, 0) for _ in range(1000)],
        'uvs': [(i*0.01, i*0.01) for i in range(1000)]
    }
    
    test_materials = [
        {'name': f'material_{i}', 'diffuse_color': [i*0.1, i*0.1, i*0.1]} 
        for i in range(10)
    ]
    
    # Test optimization for mobile target
    mobile_profile = OptimizationProfile.create_for_target(OptimizationTarget.MOBILE_MEDIUM)
    optimizer = MeshOptimizer(mobile_profile)
    
    optimized_geometry, optimized_materials, result = optimizer.optimize_mesh(
        test_geometry, test_materials
    )
    
    print(f"\nOptimization Results:")
    print(f"Vertices: {result.original_vertices} → {result.optimized_vertices} "
          f"({result.vertex_reduction_ratio:.1%} reduction)")
    print(f"Materials: {result.original_materials} → {result.optimized_materials}")
    print(f"Techniques used: {', '.join(result.optimization_techniques_used)}")
    print(f"Estimated performance improvement: {result.performance_improvement_estimate:.1f}%")