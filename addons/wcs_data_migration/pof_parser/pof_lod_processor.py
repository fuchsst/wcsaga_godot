#!/usr/bin/env python3
"""
POF LOD Processor - EPIC-003 DM-006 Implementation

LOD (Level of Detail) hierarchy processor for WCS POF models.
Creates multiple mesh versions with appropriate detail levels for different viewing distances.
"""

import logging
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .pof_data_extractor import POFDataExtractor
from .pof_parser import POFParser


@dataclass
class LODLevel:
    """Represents a single LOD level with distance threshold and optimization settings."""
    
    level: int  # 0 = highest detail, higher = lower detail
    distance_threshold: float  # Distance at which this LOD becomes active
    vertex_reduction: float  # Percentage of vertices to keep (0.0-1.0)
    triangle_reduction: float  # Percentage of triangles to keep (0.0-1.0)
    texture_resolution: float  # Texture resolution multiplier (0.0-1.0)
    disable_specular: bool  # Whether to disable specular mapping at this level
    disable_normal: bool  # Whether to disable normal mapping at this level
    
    def __post_init__(self) -> None:
        """Validate LOD level parameters."""
        if not 0 <= self.level <= 7:  # MAX_MODEL_DETAIL_LEVELS = 8
            raise ValueError(f"LOD level {self.level} out of range [0, 7]")
        if not 0.0 <= self.vertex_reduction <= 1.0:
            raise ValueError(f"Vertex reduction {self.vertex_reduction} out of range [0.0, 1.0]")
        if not 0.0 <= self.triangle_reduction <= 1.0:
            raise ValueError(f"Triangle reduction {self.triangle_reduction} out of range [0.0, 1.0]")


@dataclass
class LODHierarchy:
    """Complete LOD hierarchy for a POF model."""
    
    base_model_name: str
    lod_levels: List[LODLevel]
    base_distance: float  # Base distance for LOD calculations
    model_radius: float  # Model bounding radius for distance scaling
    
    def get_lod_for_distance(self, distance: float) -> LODLevel:
        """Get appropriate LOD level for viewing distance."""
        # Scale distance by model radius (larger models visible from farther away)
        scaled_distance = distance / max(self.model_radius, 1.0)
        
        for lod in self.lod_levels:
            if scaled_distance <= lod.distance_threshold:
                return lod
        
        # Return lowest detail level if distance exceeds all thresholds
        return self.lod_levels[-1]


class POFLODProcessor:
    """Processes POF models to create LOD (Level of Detail) hierarchies."""
    
    def __init__(self) -> None:
        """Initialize LOD processor."""
        self.parser = POFParser()
        self.extractor = POFDataExtractor()
        self.logger = logging.getLogger(__name__)
        
        # WCS LOD distance thresholds (based on modelinterp.cpp analysis)
        self.default_lod_distances = [
            10.0,   # LOD 0: High detail (close viewing)
            25.0,   # LOD 1: Medium-high detail 
            50.0,   # LOD 2: Medium detail
            100.0,  # LOD 3: Medium-low detail
            200.0,  # LOD 4: Low detail
            400.0,  # LOD 5: Very low detail
            800.0,  # LOD 6: Minimal detail
            1600.0  # LOD 7: Ultra-low detail (far viewing)
        ]
    
    def create_lod_hierarchy(self, pof_path: Path, 
                           custom_distances: Optional[List[float]] = None) -> LODHierarchy:
        """Create LOD hierarchy for POF model."""
        try:
            # Parse POF to get model information
            parsed_data = self.parser.parse(pof_path)
            if not parsed_data:
                raise ValueError(f"Failed to parse POF file: {pof_path}")
            
            # Extract model data for analysis
            model_data = self.extractor.extract_model_data(pof_path)
            if not model_data:
                raise ValueError(f"Failed to extract model data: {pof_path}")
            
            # Get model radius for distance scaling
            model_radius = model_data.radius
            base_name = pof_path.stem
            
            # Use custom distances or defaults
            distances = custom_distances or self._calculate_lod_distances(model_radius)
            
            # Create LOD levels based on WCS detail system
            lod_levels = self._create_lod_levels(distances, model_radius)
            
            hierarchy = LODHierarchy(
                base_model_name=base_name,
                lod_levels=lod_levels,
                base_distance=distances[0],
                model_radius=model_radius
            )
            
            self.logger.info(f"Created LOD hierarchy for {base_name} with {len(lod_levels)} levels")
            return hierarchy
            
        except Exception as e:
            self.logger.error(f"Failed to create LOD hierarchy for {pof_path}: {e}")
            raise
    
    def _calculate_lod_distances(self, model_radius: float) -> List[float]:
        """Calculate LOD distances based on model radius."""
        # Scale default distances by model radius
        # Larger models should have LOD transitions at greater distances
        scale_factor = max(model_radius / 50.0, 0.1)  # Base scale for typical ship radius
        
        scaled_distances = []
        for base_distance in self.default_lod_distances:
            scaled_distance = base_distance * scale_factor
            scaled_distances.append(scaled_distance)
        
        return scaled_distances
    
    def _create_lod_levels(self, distances: List[float], model_radius: float) -> List[LODLevel]:
        """Create LOD levels with appropriate optimization settings."""
        lod_levels = []
        
        for i, distance in enumerate(distances):
            # Progressive reduction in detail as LOD level increases
            # Based on WCS detail level system (0=max, higher=lower)
            
            if i == 0:  # Highest detail level
                vertex_reduction = 1.0
                triangle_reduction = 1.0
                texture_resolution = 1.0
                disable_specular = False
                disable_normal = False
            elif i == 1:  # High detail
                vertex_reduction = 0.95
                triangle_reduction = 0.95
                texture_resolution = 1.0
                disable_specular = False
                disable_normal = False
            elif i == 2:  # Medium detail (WCS disables specular here)
                vertex_reduction = 0.85
                triangle_reduction = 0.85
                texture_resolution = 0.75
                disable_specular = True  # Based on "Interp_detail_level < 2" checks
                disable_normal = False
            elif i == 3:  # Medium-low detail
                vertex_reduction = 0.70
                triangle_reduction = 0.70
                texture_resolution = 0.5
                disable_specular = True
                disable_normal = True
            elif i == 4:  # Low detail
                vertex_reduction = 0.50
                triangle_reduction = 0.50
                texture_resolution = 0.25
                disable_specular = True
                disable_normal = True
            elif i == 5:  # Very low detail
                vertex_reduction = 0.30
                triangle_reduction = 0.30
                texture_resolution = 0.25
                disable_specular = True
                disable_normal = True
            elif i == 6:  # Minimal detail
                vertex_reduction = 0.15
                triangle_reduction = 0.15
                texture_resolution = 0.125
                disable_specular = True
                disable_normal = True
            else:  # Ultra-low detail (LOD 7+)
                vertex_reduction = 0.05
                triangle_reduction = 0.05
                texture_resolution = 0.125
                disable_specular = True
                disable_normal = True
            
            lod_level = LODLevel(
                level=i,
                distance_threshold=distance,
                vertex_reduction=vertex_reduction,
                triangle_reduction=triangle_reduction,
                texture_resolution=texture_resolution,
                disable_specular=disable_specular,
                disable_normal=disable_normal
            )
            
            lod_levels.append(lod_level)
        
        return lod_levels
    
    def generate_lod_variants(self, pof_path: Path, output_dir: Path,
                            hierarchy: LODHierarchy) -> Dict[int, Path]:
        """Generate LOD variants of POF model."""
        try:
            output_dir.mkdir(parents=True, exist_ok=True)
            lod_variants = {}
            
            # Extract base model data
            model_data = self.extractor.extract_model_data(pof_path)
            if not model_data:
                raise ValueError(f"Failed to extract model data: {pof_path}")
            
            for lod in hierarchy.lod_levels:
                # Create optimized model data for this LOD level
                lod_data = self._optimize_model_for_lod(model_data, lod)
                
                # Generate output filename
                lod_filename = f"{hierarchy.base_model_name}_lod{lod.level}.json"
                lod_path = output_dir / lod_filename
                
                # Save LOD variant data
                self._save_lod_data(lod_data, lod_path, lod)
                lod_variants[lod.level] = lod_path
                
                self.logger.info(
                    f"Generated LOD {lod.level} variant: {lod_path.name} "
                    f"(distance: {lod.distance_threshold:.1f}, "
                    f"vertices: {lod.vertex_reduction:.1%})"
                )
            
            return lod_variants
            
        except Exception as e:
            self.logger.error(f"Failed to generate LOD variants: {e}")
            raise
    
    def _optimize_model_for_lod(self, base_data: Any, lod: LODLevel) -> Dict[str, Any]:
        """Optimize model data for specific LOD level."""
        # Create optimized copy of model data
        lod_data = {
            'lod_level': lod.level,
            'distance_threshold': lod.distance_threshold,
            'optimization_settings': {
                'vertex_reduction': lod.vertex_reduction,
                'triangle_reduction': lod.triangle_reduction,
                'texture_resolution': lod.texture_resolution,
                'disable_specular': lod.disable_specular,
                'disable_normal': lod.disable_normal
            },
            'geometry': self._optimize_geometry(base_data.geometry, lod),
            'materials': self._optimize_materials(base_data.materials, lod),
            'textures': self._optimize_textures(base_data.textures, lod),
            'metadata': {
                'original_vertices': len(base_data.geometry.get('vertices', [])),
                'original_faces': len(base_data.geometry.get('faces', [])),
                'optimization_target': f"LOD {lod.level}"
            }
        }
        
        return lod_data
    
    def _optimize_geometry(self, geometry: Dict[str, Any], lod: LODLevel) -> Dict[str, Any]:
        """Optimize geometry for LOD level."""
        if not geometry:
            return {}
        
        # For simplicity, calculate target counts
        # Real implementation would use mesh decimation algorithms
        original_verts = len(geometry.get('vertices', []))
        original_faces = len(geometry.get('faces', []))
        
        target_verts = int(original_verts * lod.vertex_reduction)
        target_faces = int(original_faces * lod.triangle_reduction)
        
        # Placeholder optimization (real implementation would decimate mesh)
        optimized_geometry = geometry.copy()
        optimized_geometry['lod_info'] = {
            'target_vertices': target_verts,
            'target_faces': target_faces,
            'reduction_factor_vertices': lod.vertex_reduction,
            'reduction_factor_faces': lod.triangle_reduction
        }
        
        return optimized_geometry
    
    def _optimize_materials(self, materials: List[Dict[str, Any]], 
                          lod: LODLevel) -> List[Dict[str, Any]]:
        """Optimize materials for LOD level."""
        if not materials:
            return []
        
        optimized_materials = []
        for material in materials:
            opt_material = material.copy()
            
            # Remove expensive effects at lower LOD levels
            if lod.disable_specular:
                opt_material.pop('specular_map', None)
                opt_material.pop('roughness_map', None)
                opt_material['roughness'] = 1.0  # Fully rough
            
            if lod.disable_normal:
                opt_material.pop('normal_map', None)
                opt_material.pop('height_map', None)
            
            # Reduce texture resolution
            if 'diffuse_map' in opt_material:
                opt_material['diffuse_resolution_scale'] = lod.texture_resolution
            
            opt_material['lod_level'] = lod.level
            optimized_materials.append(opt_material)
        
        return optimized_materials
    
    def _optimize_textures(self, textures: List[str], lod: LODLevel) -> List[str]:
        """Optimize texture list for LOD level."""
        if not textures:
            return []
        
        # For higher LOD levels, we might reduce texture count
        # or suggest lower resolution variants
        optimized_textures = textures.copy()
        
        # Add LOD-specific texture resolution hints
        if lod.texture_resolution < 1.0:
            # In real implementation, this would generate/reference lower-res textures
            for i, texture in enumerate(optimized_textures):
                if isinstance(texture, str):
                    # Add resolution hint to filename
                    base_name = Path(texture).stem
                    ext = Path(texture).suffix
                    resolution_suffix = f"_lod{lod.level}"
                    optimized_textures[i] = f"{base_name}{resolution_suffix}{ext}"
        
        return optimized_textures
    
    def _save_lod_data(self, lod_data: Dict[str, Any], output_path: Path, 
                      lod: LODLevel) -> None:
        """Save LOD data to file."""
        import json
        
        with open(output_path, 'w') as f:
            json.dump(lod_data, f, indent=2, default=str)
    
    def validate_lod_hierarchy(self, hierarchy: LODHierarchy) -> List[str]:
        """Validate LOD hierarchy for consistency and performance."""
        issues = []
        
        # Check distance thresholds are monotonically increasing
        prev_distance = 0.0
        for lod in hierarchy.lod_levels:
            if lod.distance_threshold <= prev_distance:
                issues.append(
                    f"LOD {lod.level} distance {lod.distance_threshold} "
                    f"should be greater than previous distance {prev_distance}"
                )
            prev_distance = lod.distance_threshold
        
        # Check reduction factors are monotonically decreasing
        prev_vertex_reduction = 1.0
        prev_triangle_reduction = 1.0
        
        for lod in hierarchy.lod_levels:
            if lod.vertex_reduction > prev_vertex_reduction:
                issues.append(
                    f"LOD {lod.level} vertex reduction {lod.vertex_reduction} "
                    f"should not exceed previous level {prev_vertex_reduction}"
                )
            
            if lod.triangle_reduction > prev_triangle_reduction:
                issues.append(
                    f"LOD {lod.level} triangle reduction {lod.triangle_reduction} "
                    f"should not exceed previous level {prev_triangle_reduction}"
                )
            
            prev_vertex_reduction = lod.vertex_reduction
            prev_triangle_reduction = lod.triangle_reduction
        
        # Performance validation
        if len(hierarchy.lod_levels) < 3:
            issues.append(
                "LOD hierarchy should have at least 3 levels for effective optimization"
            )
        
        # Check for reasonable distance ranges
        max_distance = hierarchy.lod_levels[-1].distance_threshold
        min_distance = hierarchy.lod_levels[0].distance_threshold
        
        if max_distance / min_distance < 10:
            issues.append(
                f"Distance range too narrow: {min_distance:.1f} to {max_distance:.1f} "
                "(should span at least 10x for effective LOD)"
            )
        
        return issues


def create_default_lod_hierarchy(model_radius: float) -> LODHierarchy:
    """Create a default LOD hierarchy for a model with given radius."""
    processor = POFLODProcessor()
    distances = processor._calculate_lod_distances(model_radius)
    lod_levels = processor._create_lod_levels(distances, model_radius)
    
    return LODHierarchy(
        base_model_name="default",
        lod_levels=lod_levels,
        base_distance=distances[0],
        model_radius=model_radius
    )


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Create test LOD hierarchy
    test_radius = 100.0  # Typical ship radius
    hierarchy = create_default_lod_hierarchy(test_radius)
    
    print(f"LOD Hierarchy for model radius {test_radius}:")
    for lod in hierarchy.lod_levels:
        print(f"  LOD {lod.level}: distance≤{lod.distance_threshold:.1f}, "
              f"vertices={lod.vertex_reduction:.1%}, "
              f"triangles={lod.triangle_reduction:.1%}")
    
    # Test distance-based LOD selection
    test_distances = [5.0, 15.0, 30.0, 75.0, 150.0, 300.0, 600.0, 1200.0]
    print(f"\nLOD selection for test distances:")
    for distance in test_distances:
        selected_lod = hierarchy.get_lod_for_distance(distance)
        print(f"  Distance {distance:4.0f} → LOD {selected_lod.level}")