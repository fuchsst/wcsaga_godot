#!/usr/bin/env python3
"""
Collision Mesh Generator - EPIC-003 DM-006 Implementation

Collision mesh generator that creates optimized physics geometry for POF models.
Preserves gameplay accuracy while providing efficient collision detection for Godot physics.
"""

import logging
import math
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from .pof_data_extractor import POFDataExtractor
from .pof_parser import POFParser


class CollisionType(Enum):
    """Types of collision shapes for different use cases."""
    CONVEX_HULL = "convex_hull"  # Single convex hull - fast, less accurate
    CONVEX_DECOMPOSITION = "convex_decomposition"  # Multiple convex hulls - slower, more accurate
    TRIMESH = "trimesh"  # Exact triangle mesh - slowest, most accurate (static only)
    SPHERE = "sphere"  # Bounding sphere - fastest, least accurate
    BOX = "box"  # Bounding box - fast, good for rectangular objects
    CAPSULE = "capsule"  # Capsule shape - good for elongated objects


@dataclass
class CollisionMeshSettings:
    """Settings for collision mesh generation."""
    
    collision_type: CollisionType = CollisionType.CONVEX_HULL
    max_vertices: int = 255  # Godot limit for convex shapes
    simplification_factor: float = 0.1  # Vertex reduction (0.0-1.0)
    merge_distance: float = 0.01  # Distance to merge nearby vertices
    
    # Convex decomposition settings
    max_convex_hulls: int = 8  # Maximum number of convex hulls
    voxel_resolution: int = 64  # Resolution for voxelization
    
    # Gameplay-specific settings
    preserve_subsystems: bool = True  # Keep important subsystem shapes
    generate_shield_mesh: bool = True  # Generate separate shield collision
    
    # Performance optimization
    use_lod_for_distance: bool = True  # Use simpler collision at distance
    min_feature_size: float = 0.5  # Minimum feature size to preserve
    
    def validate(self) -> List[str]:
        """Validate settings and return any issues."""
        issues = []
        
        if not 0.0 <= self.simplification_factor <= 1.0:
            issues.append("Simplification factor must be between 0.0 and 1.0")
        
        if self.max_vertices < 4:
            issues.append("Max vertices must be at least 4 for convex shapes")
        elif self.max_vertices > 255:
            issues.append("Max vertices cannot exceed 255 (Godot limit)")
        
        if self.max_convex_hulls < 1:
            issues.append("Max convex hulls must be at least 1")
        elif self.max_convex_hulls > 32:
            issues.append("Max convex hulls should not exceed 32 for performance")
        
        return issues


@dataclass
class CollisionMeshData:
    """Generated collision mesh data."""
    
    collision_type: CollisionType
    vertices: List[Tuple[float, float, float]]
    indices: List[int]  # Triangle indices for trimesh, face indices for convex
    
    # Multiple convex hulls (for decomposition)
    convex_hulls: List[Dict[str, Any]] = None
    
    # Simplified shape data
    sphere_center: Optional[Tuple[float, float, float]] = None
    sphere_radius: Optional[float] = None
    box_center: Optional[Tuple[float, float, float]] = None
    box_extents: Optional[Tuple[float, float, float]] = None
    
    # Subsystem collision data
    subsystem_collisions: Dict[str, Any] = None
    shield_collision: Optional[Dict[str, Any]] = None
    
    # Metadata
    original_vertex_count: int = 0
    optimized_vertex_count: int = 0
    optimization_ratio: float = 0.0
    
    def __post_init__(self) -> None:
        """Calculate optimization metrics."""
        if self.vertices:
            self.optimized_vertex_count = len(self.vertices)
            if self.original_vertex_count > 0:
                self.optimization_ratio = self.optimized_vertex_count / self.original_vertex_count


class CollisionMeshGenerator:
    """Generates optimized collision meshes from POF model data."""
    
    def __init__(self) -> None:
        """Initialize collision mesh generator."""
        self.parser = POFParser()
        self.extractor = POFDataExtractor()
        self.logger = logging.getLogger(__name__)
    
    def generate_collision_mesh(self, pof_path: Path, 
                              settings: CollisionMeshSettings) -> CollisionMeshData:
        """Generate collision mesh from POF model."""
        try:
            # Validate settings
            issues = settings.validate()
            if issues:
                raise ValueError(f"Invalid settings: {'; '.join(issues)}")
            
            # Extract model data
            model_data = self.extractor.extract_model_data(pof_path)
            if not model_data:
                raise ValueError(f"Failed to extract model data from {pof_path}")
            
            # Get geometry data
            geometry = model_data.geometry
            original_vertex_count = len(geometry.get('vertices', []))
            
            self.logger.info(
                f"Generating {settings.collision_type.value} collision mesh "
                f"for {pof_path.name} ({original_vertex_count} vertices)"
            )
            
            # Generate collision mesh based on type
            if settings.collision_type == CollisionType.SPHERE:
                collision_data = self._generate_sphere_collision(geometry, settings)
            elif settings.collision_type == CollisionType.BOX:
                collision_data = self._generate_box_collision(geometry, settings)
            elif settings.collision_type == CollisionType.CAPSULE:
                collision_data = self._generate_capsule_collision(geometry, settings)
            elif settings.collision_type == CollisionType.CONVEX_HULL:
                collision_data = self._generate_convex_hull_collision(geometry, settings)
            elif settings.collision_type == CollisionType.CONVEX_DECOMPOSITION:
                collision_data = self._generate_convex_decomposition_collision(geometry, settings)
            elif settings.collision_type == CollisionType.TRIMESH:
                collision_data = self._generate_trimesh_collision(geometry, settings)
            else:
                raise ValueError(f"Unsupported collision type: {settings.collision_type}")
            
            # Set metadata
            collision_data.original_vertex_count = original_vertex_count
            
            # Generate subsystem collisions if requested
            if settings.preserve_subsystems:
                collision_data.subsystem_collisions = self._generate_subsystem_collisions(
                    model_data, settings
                )
            
            # Generate shield collision if requested
            if settings.generate_shield_mesh and hasattr(model_data, 'shield_data'):
                collision_data.shield_collision = self._generate_shield_collision(
                    model_data.shield_data, settings
                )
            
            self.logger.info(
                f"Generated collision mesh: {collision_data.optimized_vertex_count} vertices "
                f"({collision_data.optimization_ratio:.1%} of original)"
            )
            
            return collision_data
            
        except Exception as e:
            self.logger.error(f"Failed to generate collision mesh for {pof_path}: {e}")
            raise
    
    def _generate_sphere_collision(self, geometry: Dict[str, Any], 
                                 settings: CollisionMeshSettings) -> CollisionMeshData:
        """Generate sphere collision shape."""
        vertices = geometry.get('vertices', [])
        if not vertices:
            raise ValueError("No vertices in geometry data")
        
        # Calculate bounding sphere
        center, radius = self._calculate_bounding_sphere(vertices)
        
        return CollisionMeshData(
            collision_type=CollisionType.SPHERE,
            vertices=[],  # No vertices needed for sphere
            indices=[],
            sphere_center=center,
            sphere_radius=radius
        )
    
    def _generate_box_collision(self, geometry: Dict[str, Any],
                              settings: CollisionMeshSettings) -> CollisionMeshData:
        """Generate box collision shape."""
        vertices = geometry.get('vertices', [])
        if not vertices:
            raise ValueError("No vertices in geometry data")
        
        # Calculate axis-aligned bounding box
        min_bounds, max_bounds = self._calculate_aabb(vertices)
        center = tuple((min_bounds[i] + max_bounds[i]) / 2.0 for i in range(3))
        extents = tuple((max_bounds[i] - min_bounds[i]) / 2.0 for i in range(3))
        
        return CollisionMeshData(
            collision_type=CollisionType.BOX,
            vertices=[],  # No vertices needed for box
            indices=[],
            box_center=center,
            box_extents=extents
        )
    
    def _generate_capsule_collision(self, geometry: Dict[str, Any],
                                  settings: CollisionMeshSettings) -> CollisionMeshData:
        """Generate capsule collision shape."""
        vertices = geometry.get('vertices', [])
        if not vertices:
            raise ValueError("No vertices in geometry data")
        
        # Find the longest axis for capsule orientation
        min_bounds, max_bounds = self._calculate_aabb(vertices)
        extents = [max_bounds[i] - min_bounds[i] for i in range(3)]
        
        # Use longest axis as capsule height direction
        height_axis = extents.index(max(extents))
        radius = min(extents[(height_axis + 1) % 3], extents[(height_axis + 2) % 3]) / 2.0
        height = extents[height_axis]
        
        center = tuple((min_bounds[i] + max_bounds[i]) / 2.0 for i in range(3))
        
        # Store capsule data in vertices (center, radius, height, axis)
        capsule_data = [
            center[0], center[1], center[2],  # Center
            radius, height, float(height_axis)  # Radius, height, axis
        ]
        
        return CollisionMeshData(
            collision_type=CollisionType.CAPSULE,
            vertices=[(capsule_data[i], capsule_data[i+1], capsule_data[i+2]) 
                     for i in range(0, len(capsule_data), 3)],
            indices=[]
        )
    
    def _generate_convex_hull_collision(self, geometry: Dict[str, Any],
                                      settings: CollisionMeshSettings) -> CollisionMeshData:
        """Generate single convex hull collision shape."""
        vertices = geometry.get('vertices', [])
        if not vertices:
            raise ValueError("No vertices in geometry data")
        
        # Simplify vertex set for convex hull
        simplified_vertices = self._simplify_vertices(vertices, settings)
        
        # Calculate convex hull
        hull_vertices, hull_indices = self._calculate_convex_hull(simplified_vertices)
        
        return CollisionMeshData(
            collision_type=CollisionType.CONVEX_HULL,
            vertices=hull_vertices,
            indices=hull_indices
        )
    
    def _generate_convex_decomposition_collision(self, geometry: Dict[str, Any],
                                               settings: CollisionMeshSettings) -> CollisionMeshData:
        """Generate multiple convex hull collision shapes (convex decomposition)."""
        vertices = geometry.get('vertices', [])
        faces = geometry.get('faces', [])
        
        if not vertices or not faces:
            raise ValueError("No vertices or faces in geometry data")
        
        # Perform convex decomposition
        convex_hulls = self._decompose_into_convex_hulls(vertices, faces, settings)
        
        # Combine all hull vertices for storage
        all_vertices = []
        all_indices = []
        current_offset = 0
        
        for hull in convex_hulls:
            hull_vertices = hull['vertices']
            hull_indices = hull['indices']
            
            all_vertices.extend(hull_vertices)
            
            # Offset indices for combined mesh
            offset_indices = [idx + current_offset for idx in hull_indices]
            all_indices.extend(offset_indices)
            
            current_offset += len(hull_vertices)
        
        return CollisionMeshData(
            collision_type=CollisionType.CONVEX_DECOMPOSITION,
            vertices=all_vertices,
            indices=all_indices,
            convex_hulls=convex_hulls
        )
    
    def _generate_trimesh_collision(self, geometry: Dict[str, Any],
                                  settings: CollisionMeshSettings) -> CollisionMeshData:
        """Generate triangle mesh collision shape (exact geometry)."""
        vertices = geometry.get('vertices', [])
        faces = geometry.get('faces', [])
        
        if not vertices or not faces:
            raise ValueError("No vertices or faces in geometry data")
        
        # Simplify mesh if requested
        if settings.simplification_factor < 1.0:
            simplified_vertices, simplified_faces = self._simplify_mesh(
                vertices, faces, settings
            )
        else:
            simplified_vertices = vertices
            simplified_faces = faces
        
        # Convert faces to triangle indices
        triangle_indices = []
        for face in simplified_faces:
            if 'vertices' in face and len(face['vertices']) >= 3:
                face_vertices = face['vertices']
                # Triangulate polygon if necessary
                for i in range(1, len(face_vertices) - 1):
                    triangle_indices.extend([
                        face_vertices[0],
                        face_vertices[i],
                        face_vertices[i + 1]
                    ])
        
        return CollisionMeshData(
            collision_type=CollisionType.TRIMESH,
            vertices=simplified_vertices,
            indices=triangle_indices
        )
    
    def _simplify_vertices(self, vertices: List[Tuple[float, float, float]],
                          settings: CollisionMeshSettings) -> List[Tuple[float, float, float]]:
        """Simplify vertex set by removing nearby vertices and reducing count."""
        if not vertices:
            return []
        
        # Remove duplicate and nearby vertices
        simplified = []
        for vertex in vertices:
            is_duplicate = False
            for existing in simplified:
                distance = math.sqrt(sum((vertex[i] - existing[i])**2 for i in range(3)))
                if distance < settings.merge_distance:
                    is_duplicate = True
                    break
            
            if not is_duplicate:
                simplified.append(vertex)
        
        # Reduce vertex count if needed
        target_count = min(
            len(simplified),
            max(int(len(simplified) * settings.simplification_factor), 4)
        )
        
        if target_count < len(simplified):
            # Use simple uniform sampling
            step = len(simplified) // target_count
            simplified = [simplified[i * step] for i in range(target_count)]
        
        # Ensure we don't exceed Godot's convex shape limit
        if len(simplified) > settings.max_vertices:
            step = len(simplified) // settings.max_vertices
            simplified = [simplified[i * step] for i in range(settings.max_vertices)]
        
        return simplified
    
    def _calculate_bounding_sphere(self, vertices: List[Tuple[float, float, float]]) -> Tuple[Tuple[float, float, float], float]:
        """Calculate bounding sphere for vertices."""
        if not vertices:
            return (0.0, 0.0, 0.0), 0.0
        
        # Calculate center as centroid
        center = tuple(sum(v[i] for v in vertices) / len(vertices) for i in range(3))
        
        # Calculate radius as maximum distance from center
        max_distance = 0.0
        for vertex in vertices:
            distance = math.sqrt(sum((vertex[i] - center[i])**2 for i in range(3)))
            max_distance = max(max_distance, distance)
        
        return center, max_distance
    
    def _calculate_aabb(self, vertices: List[Tuple[float, float, float]]) -> Tuple[Tuple[float, float, float], Tuple[float, float, float]]:
        """Calculate axis-aligned bounding box."""
        if not vertices:
            return (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)
        
        min_bounds = [float('inf')] * 3
        max_bounds = [float('-inf')] * 3
        
        for vertex in vertices:
            for i in range(3):
                min_bounds[i] = min(min_bounds[i], vertex[i])
                max_bounds[i] = max(max_bounds[i], vertex[i])
        
        return tuple(min_bounds), tuple(max_bounds)
    
    def _calculate_convex_hull(self, vertices: List[Tuple[float, float, float]]) -> Tuple[List[Tuple[float, float, float]], List[int]]:
        """Calculate convex hull of vertices."""
        # Simplified convex hull implementation
        # In production, would use proper algorithm like QuickHull
        
        if len(vertices) < 4:
            # Not enough vertices for 3D convex hull
            return vertices, list(range(len(vertices)))
        
        # For now, return simplified vertex set
        # Real implementation would compute actual convex hull
        hull_vertices = vertices
        hull_indices = list(range(len(vertices)))
        
        return hull_vertices, hull_indices
    
    def _decompose_into_convex_hulls(self, vertices: List[Tuple[float, float, float]],
                                   faces: List[Dict[str, Any]],
                                   settings: CollisionMeshSettings) -> List[Dict[str, Any]]:
        """Decompose mesh into multiple convex hulls."""
        # Simplified convex decomposition
        # Real implementation would use algorithms like HACD or V-HACD
        
        # For now, create single hull
        hull_vertices, hull_indices = self._calculate_convex_hull(vertices)
        
        convex_hulls = [{
            'vertices': hull_vertices,
            'indices': hull_indices,
            'volume': self._calculate_hull_volume(hull_vertices, hull_indices)
        }]
        
        return convex_hulls[:settings.max_convex_hulls]  # Limit number of hulls
    
    def _simplify_mesh(self, vertices: List[Tuple[float, float, float]],
                      faces: List[Dict[str, Any]],
                      settings: CollisionMeshSettings) -> Tuple[List[Tuple[float, float, float]], List[Dict[str, Any]]]:
        """Simplify mesh by reducing vertex and face count."""
        # Simplified mesh decimation
        # Real implementation would use proper decimation algorithms
        
        simplified_vertices = self._simplify_vertices(vertices, settings)
        
        # Filter faces to only include those with remaining vertices
        vertex_mapping = {id(v): i for i, v in enumerate(simplified_vertices)}
        simplified_faces = []
        
        for face in faces:
            if 'vertices' in face:
                # Map face vertices to simplified set
                new_face_vertices = []
                for vertex_idx in face['vertices']:
                    if vertex_idx < len(vertices):
                        original_vertex = vertices[vertex_idx]
                        # Find closest vertex in simplified set
                        closest_idx = 0
                        min_distance = float('inf')
                        for i, simplified_vertex in enumerate(simplified_vertices):
                            distance = sum((original_vertex[j] - simplified_vertex[j])**2 for j in range(3))
                            if distance < min_distance:
                                min_distance = distance
                                closest_idx = i
                        new_face_vertices.append(closest_idx)
                
                if len(new_face_vertices) >= 3:
                    new_face = face.copy()
                    new_face['vertices'] = new_face_vertices
                    simplified_faces.append(new_face)
        
        return simplified_vertices, simplified_faces
    
    def _calculate_hull_volume(self, vertices: List[Tuple[float, float, float]],
                             indices: List[int]) -> float:
        """Calculate volume of convex hull."""
        # Simplified volume calculation
        if len(vertices) < 4:
            return 0.0
        
        # Use bounding box volume as approximation
        min_bounds, max_bounds = self._calculate_aabb(vertices)
        volume = 1.0
        for i in range(3):
            volume *= (max_bounds[i] - min_bounds[i])
        
        return volume
    
    def _generate_subsystem_collisions(self, model_data: Any,
                                     settings: CollisionMeshSettings) -> Dict[str, Any]:
        """Generate collision shapes for important subsystems."""
        subsystem_collisions = {}
        
        # Check if model has subsystem data
        if not hasattr(model_data, 'subsystems') or not model_data.subsystems:
            return subsystem_collisions
        
        for subsystem in model_data.subsystems:
            subsystem_name = subsystem.get('name', 'unknown')
            subsystem_type = subsystem.get('type', 'generic')
            
            # Generate appropriate collision for subsystem type
            if subsystem_type in ['turret', 'weapon']:
                # Use box collision for weapon systems
                collision_type = CollisionType.BOX
            elif subsystem_type in ['engine', 'thruster']:
                # Use capsule collision for engines
                collision_type = CollisionType.CAPSULE
            else:
                # Use convex hull for generic subsystems
                collision_type = CollisionType.CONVEX_HULL
            
            # Create subsystem collision settings
            subsystem_settings = CollisionMeshSettings(
                collision_type=collision_type,
                simplification_factor=0.5,  # More aggressive simplification
                max_vertices=32  # Fewer vertices for subsystems
            )
            
            # Generate collision data for subsystem
            if 'geometry' in subsystem:
                try:
                    if collision_type == CollisionType.BOX:
                        collision_data = self._generate_box_collision(
                            subsystem['geometry'], subsystem_settings
                        )
                    elif collision_type == CollisionType.CAPSULE:
                        collision_data = self._generate_capsule_collision(
                            subsystem['geometry'], subsystem_settings
                        )
                    else:
                        collision_data = self._generate_convex_hull_collision(
                            subsystem['geometry'], subsystem_settings
                        )
                    
                    subsystem_collisions[subsystem_name] = {
                        'type': collision_type.value,
                        'data': collision_data,
                        'subsystem_type': subsystem_type
                    }
                    
                except Exception as e:
                    self.logger.warning(
                        f"Failed to generate collision for subsystem {subsystem_name}: {e}"
                    )
        
        return subsystem_collisions
    
    def _generate_shield_collision(self, shield_data: Dict[str, Any],
                                 settings: CollisionMeshSettings) -> Dict[str, Any]:
        """Generate collision shape for shield mesh."""
        if not shield_data or 'vertices' not in shield_data:
            return None
        
        try:
            # Use simplified convex hull for shield collision
            shield_settings = CollisionMeshSettings(
                collision_type=CollisionType.CONVEX_HULL,
                simplification_factor=0.3,  # Aggressive simplification for shields
                max_vertices=64
            )
            
            collision_data = self._generate_convex_hull_collision(
                shield_data, shield_settings
            )
            
            return {
                'type': CollisionType.CONVEX_HULL.value,
                'data': collision_data,
                'purpose': 'shield_collision'
            }
            
        except Exception as e:
            self.logger.warning(f"Failed to generate shield collision: {e}")
            return None
    
    def save_collision_mesh(self, collision_data: CollisionMeshData,
                          output_path: Path) -> None:
        """Save collision mesh data to file."""
        try:
            import json

            # Convert collision data to serializable format
            collision_dict = {
                'collision_type': collision_data.collision_type.value,
                'vertices': collision_data.vertices,
                'indices': collision_data.indices,
                'metadata': {
                    'original_vertex_count': collision_data.original_vertex_count,
                    'optimized_vertex_count': collision_data.optimized_vertex_count,
                    'optimization_ratio': collision_data.optimization_ratio
                }
            }
            
            # Add shape-specific data
            if collision_data.sphere_center:
                collision_dict['sphere'] = {
                    'center': collision_data.sphere_center,
                    'radius': collision_data.sphere_radius
                }
            
            if collision_data.box_center:
                collision_dict['box'] = {
                    'center': collision_data.box_center,
                    'extents': collision_data.box_extents
                }
            
            if collision_data.convex_hulls:
                collision_dict['convex_hulls'] = collision_data.convex_hulls
            
            if collision_data.subsystem_collisions:
                collision_dict['subsystems'] = collision_data.subsystem_collisions
            
            if collision_data.shield_collision:
                collision_dict['shield'] = collision_data.shield_collision
            
            # Ensure output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write collision data
            with open(output_path, 'w') as f:
                json.dump(collision_dict, f, indent=2, default=str)
            
            self.logger.info(f"Saved collision mesh: {output_path}")
            
        except Exception as e:
            self.logger.error(f"Failed to save collision mesh: {e}")
            raise


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Create test collision settings
    settings = CollisionMeshSettings(
        collision_type=CollisionType.CONVEX_HULL,
        max_vertices=128,
        simplification_factor=0.2,
        preserve_subsystems=True
    )
    
    # Validate settings
    issues = settings.validate()
    if issues:
        print(f"Settings issues: {issues}")
    else:
        print("Settings validated successfully")
    
    # Create example collision data
    test_vertices = [
        (0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
        (0.0, 0.0, 1.0), (1.0, 1.0, 1.0)
    ]
    
    generator = CollisionMeshGenerator()
    
    # Test bounding sphere calculation
    center, radius = generator._calculate_bounding_sphere(test_vertices)
    print(f"Bounding sphere: center={center}, radius={radius:.3f}")
    
    # Test AABB calculation
    min_bounds, max_bounds = generator._calculate_aabb(test_vertices)
    print(f"AABB: min={min_bounds}, max={max_bounds}")
    
    print("\nCollision mesh generator ready for POF processing")