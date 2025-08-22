#!/usr/bin/env python3
"""
Godot Import File Generator - EPIC-003 DM-005 Implementation

Generates optimized .import files for GLB models to ensure proper Godot integration
with ship-specific settings, collision generation, and material configuration.

Based on EPIC-003 architecture and Godot import pipeline requirements.
"""

import configparser
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

class GodotImportGenerator:
    """
    Generator for Godot .import files with optimized settings for WCS ship models.
    
    Creates import configurations that preserve model fidelity while optimizing
    for gameplay performance and Godot engine compatibility.
    """
    
    def __init__(self):
        """Initialize Godot import generator."""
        self.default_ship_settings = self._create_default_ship_settings()
        self.default_station_settings = self._create_default_station_settings()
        self.default_debris_settings = self._create_default_debris_settings()
    
    def generate_import_file(self, glb_path: Path, model_type: str = "ship", 
                           custom_settings: Optional[Dict[str, Any]] = None) -> bool:
        """
        Generate .import file for GLB model.
        
        Args:
            glb_path: Path to GLB file
            model_type: Type of model ("ship", "station", "debris", "custom")
            custom_settings: Custom import settings to override defaults
            
        Returns:
            True if import file generated successfully, False otherwise
        """
        import_path = glb_path.with_suffix('.glb.import')
        
        logger.info(f"Generating Godot import file: {import_path}")
        
        try:
            # Get base settings for model type
            settings = self._get_base_settings(model_type)
            
            # Apply custom settings if provided
            if custom_settings:
                settings.update(custom_settings)
            
            # Write import file
            if self._write_import_file(import_path, glb_path, settings):
                logger.info(f"Successfully generated import file: {import_path}")
                return True
            else:
                logger.error(f"Failed to write import file: {import_path}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to generate import file for {glb_path}: {e}", exc_info=True)
            return False
    
    def generate_batch_import_files(self, directory: Path, model_type: str = "ship", 
                                   pattern: str = "*.glb") -> Dict[str, bool]:
        """
        Generate import files for all GLB files in directory.
        
        Args:
            directory: Directory containing GLB files
            model_type: Default model type for all files
            pattern: File pattern to match
            
        Returns:
            Dictionary mapping file paths to generation success status
        """
        results: Dict[str, bool] = {}
        glb_files = list(directory.glob(pattern))
        
        logger.info(f"Generating import files for {len(glb_files)} GLB files")
        
        for glb_file in glb_files:
            # Detect model type from filename if possible
            detected_type = self._detect_model_type(glb_file.name)
            final_type = detected_type if detected_type else model_type
            
            success = self.generate_import_file(glb_file, final_type)
            results[str(glb_file)] = success
            
            if success:
                logger.info(f"✓ Generated import for: {glb_file.name} (type: {final_type})")
            else:
                logger.error(f"✗ Failed import for: {glb_file.name}")
        
        successful = sum(1 for success in results.values() if success)
        logger.info(f"Import generation complete: {successful}/{len(glb_files)} successful")
        
        return results
    
    def _get_base_settings(self, model_type: str) -> Dict[str, Any]:
        """Get base import settings for model type."""
        settings_map = {
            "ship": self.default_ship_settings,
            "station": self.default_station_settings,
            "debris": self.default_debris_settings,
            "custom": self.default_ship_settings  # Default to ship settings
        }
        
        return settings_map.get(model_type, self.default_ship_settings).copy()
    
    def _detect_model_type(self, filename: str) -> Optional[str]:
        """Detect model type from filename patterns."""
        filename_lower = filename.lower()
        
        # Station indicators
        if any(indicator in filename_lower for indicator in ['station', 'base', 'platform', 'installation']):
            return "station"
        
        # Debris indicators
        if any(indicator in filename_lower for indicator in ['debris', 'wreck', 'hulk', 'fragment']):
            return "debris"
        
        # Default to ship for fighters, bombers, cruisers, etc.
        if any(indicator in filename_lower for indicator in ['fighter', 'bomber', 'cruiser', 'destroyer', 'ship']):
            return "ship"
        
        return None  # Unknown type
    
    def _create_default_ship_settings(self) -> Dict[str, Any]:
        """Create default import settings for ship models."""
        return {
            # Scene settings
            "nodes/root_type": "StaticBody3D",
            "nodes/root_name": "Ship",
            
            # Mesh settings
            "meshes/ensure_tangents": True,
            "meshes/create_shadow_meshes": True,
            "meshes/light_baking": 0,  # Disabled
            "meshes/lightmap_texel_size": 0.2,
            "meshes/force_disable_compression": False,
            
            # Material settings  
            "materials/location": 1,  # Storage: Files (.material)
            "materials/storage": 1,   # Built-in
            "materials/keep_on_reimport": True,
            
            # Animation settings
            "animation/import": True,
            "animation/fps": 30,
            "animation/trimming": False,
            "animation/remove_immutable_tracks": True,
            
            # Physics/Collision
            "physics/create_physics_body": True,
            "physics/body_type": 0,   # StaticBody3D
            "physics/shape_type": 1,  # Trimesh (precise collision)
            
            # Optimization
            "optimize/use_batching": True,
            "optimize/merge_surfaces": False,  # Keep subsystems separate
            "optimize/simplify_meshes": False,  # Preserve detail
            
            # WCS-specific
            "wcs/preserve_subsystems": True,
            "wcs/generate_weapon_points": True,
            "wcs/generate_engine_points": True,
            "wcs/model_scale": 0.01  # POF to Godot scale factor
        }
    
    def _create_default_station_settings(self) -> Dict[str, Any]:
        """Create default import settings for station models."""
        settings = self._create_default_ship_settings().copy()
        
        # Override station-specific settings
        settings.update({
            "nodes/root_name": "Station",
            "physics/shape_type": 2,  # Convex decomposition for large structures
            "optimize/simplify_meshes": True,  # Stations can be simplified
            "meshes/light_baking": 2,  # Enable for stations (they're static)
            "wcs/generate_weapon_points": False,  # Stations typically don't move/fight
            "wcs/generate_engine_points": False,
        })
        
        return settings
    
    def _create_default_debris_settings(self) -> Dict[str, Any]:
        """Create default import settings for debris models."""
        settings = self._create_default_ship_settings().copy()
        
        # Override debris-specific settings
        settings.update({
            "nodes/root_type": "RigidBody3D",
            "nodes/root_name": "Debris",
            "physics/body_type": 1,  # RigidBody3D for physics simulation
            "physics/shape_type": 0,  # Convex hull (simpler, faster)
            "optimize/simplify_meshes": True,  # Debris can be lower detail
            "optimize/merge_surfaces": True,   # Combine for performance
            "wcs/generate_weapon_points": False,
            "wcs/generate_engine_points": False,
        })
        
        return settings
    
    def _write_import_file(self, import_path: Path, glb_path: Path, 
                          settings: Dict[str, Any]) -> bool:
        """Write Godot .import file with specified settings."""
        try:
            config = configparser.ConfigParser()
            config.optionxform = str  # Preserve case sensitivity
            
            # Required header section
            config.add_section('remap')
            config.set('remap', 'importer', 'scene')
            config.set('remap', 'type', 'PackedScene')
            config.set('remap', 'uid', f'uid://b{hash(str(glb_path)) & 0x7FFFFFFF:08x}')  # Generate UID
            config.set('remap', 'path', f"{glb_path.stem}.scn")
            
            # Dependencies section
            config.add_section('deps')
            config.set('deps', 'source_file', f'res://{glb_path.name}')
            
            # Parameters section
            config.add_section('params')
            
            # Convert settings to Godot import format
            for key, value in settings.items():
                if isinstance(value, bool):
                    config.set('params', key, str(value).lower())
                elif isinstance(value, (int, float)):
                    config.set('params', key, str(value))
                elif isinstance(value, str):
                    config.set('params', key, f'"{value}"')
                else:
                    config.set('params', key, str(value))
            
            # Write to file
            with open(import_path, 'w', encoding='utf-8') as f:
                config.write(f, space_around_delimiters=False)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to write import file {import_path}: {e}", exc_info=True)
            return False

class WCSImportConfigGenerator:
    """Generates import configurations specific to WCS model requirements."""
    
    def __init__(self):
        """Initialize WCS import config generator."""
        self.ship_class_configs = self._create_ship_class_configs()
    
    def generate_config_for_ship_class(self, ship_class: str) -> Dict[str, Any]:
        """Generate import configuration for specific WCS ship class."""
        ship_class_lower = ship_class.lower()
        
        # Check for known ship classes
        for class_pattern, config in self.ship_class_configs.items():
            if class_pattern in ship_class_lower:
                return config.copy()
        
        # Default configuration
        return self._get_default_fighter_config()
    
    def _create_ship_class_configs(self) -> Dict[str, Dict[str, Any]]:
        """Create ship class specific configurations."""
        return {
            "fighter": {
                "physics/shape_type": 0,  # Convex hull for speed
                "optimize/simplify_meshes": False,
                "wcs/collision_priority": "speed",
                "wcs/lod_levels": 3,
            },
            "bomber": {
                "physics/shape_type": 1,  # Trimesh for accuracy
                "optimize/simplify_meshes": False,
                "wcs/collision_priority": "accuracy",
                "wcs/lod_levels": 2,
            },
            "cruiser": {
                "physics/shape_type": 2,  # Convex decomposition
                "optimize/simplify_meshes": True,
                "wcs/collision_priority": "balanced",
                "wcs/lod_levels": 4,
            },
            "destroyer": {
                "physics/shape_type": 2,  # Convex decomposition
                "optimize/simplify_meshes": True,
                "wcs/collision_priority": "accuracy",
                "wcs/lod_levels": 4,
            },
            "capital": {
                "physics/shape_type": 2,  # Convex decomposition
                "optimize/simplify_meshes": True,
                "meshes/light_baking": 2,  # Enable baking for large ships
                "wcs/collision_priority": "accuracy",
                "wcs/lod_levels": 5,
            }
        }
    
    def _get_default_fighter_config(self) -> Dict[str, Any]:
        """Get default fighter configuration."""
        return self.ship_class_configs["fighter"].copy()

# Example usage and testing
if __name__ == '__main__':
    import sys
    
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    
    generator = GodotImportGenerator()
    
    if len(sys.argv) < 2:
        print("Usage: python godot_import_generator.py <glb_file> [model_type]")
        print("Model types: ship, station, debris, custom")
        sys.exit(1)
    
    glb_path = Path(sys.argv[1])
    model_type = sys.argv[2] if len(sys.argv) > 2 else "ship"
    
    if generator.generate_import_file(glb_path, model_type):
        print(f"Successfully generated import file for {glb_path}")
    else:
        print(f"Failed to generate import file for {glb_path}")
        sys.exit(1)