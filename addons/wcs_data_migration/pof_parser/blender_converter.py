#!/usr/bin/env python3
"""
Blender Automation for OBJ to GLB Conversion - EPIC-003 DM-005 Implementation

Provides automated Blender pipeline for converting OBJ+MTL files to GLB format
with proper material preservation, optimization, and Godot compatibility.

Based on EPIC-003 architecture requirements for mesh conversion pipeline.
"""

import json
import logging
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

class BlenderOBJConverter:
    """
    Automated Blender converter for OBJ to GLB conversion.
    
    Handles Blender automation with proper material preservation,
    mesh optimization, and Godot-specific export settings.
    """
    
    def __init__(self, blender_executable: Optional[Path] = None):
        """
        Initialize Blender converter.
        
        Args:
            blender_executable: Path to Blender executable (auto-detected if None)
        """
        self.blender_executable = blender_executable or self._find_blender_executable()
        self.conversion_script = self._create_conversion_script()
        
        if not self.blender_executable:
            logger.warning("Blender executable not found - GLB conversion will be unavailable")
    
    def convert_obj_to_glb(self, obj_path: Path, glb_path: Path, 
                          optimize_for_godot: bool = True) -> bool:
        """
        Convert OBJ file to GLB using Blender automation.
        
        Args:
            obj_path: Path to input OBJ file (with corresponding MTL)
            glb_path: Path to output GLB file
            optimize_for_godot: Apply Godot-specific optimizations
            
        Returns:
            True if conversion successful, False otherwise
        """
        if not self.blender_executable:
            logger.error("Blender executable not available for GLB conversion")
            return False
        
        logger.info(f"Converting OBJ to GLB: {obj_path} -> {glb_path}")
        
        try:
            # Create temporary script file with conversion parameters
            script_content = self._generate_conversion_script(obj_path, glb_path, optimize_for_godot)
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False, encoding='utf-8') as script_file:
                script_file.write(script_content)
                script_path = Path(script_file.name)
            
            try:
                # Execute Blender with conversion script
                result = self._execute_blender_conversion(script_path)
                
                if result and glb_path.exists():
                    logger.info(f"Successfully converted to GLB: {glb_path}")
                    return True
                else:
                    logger.error(f"GLB conversion failed - output file not created: {glb_path}")
                    return False
                    
            finally:
                # Clean up temporary script
                script_path.unlink(missing_ok=True)
                
        except Exception as e:
            logger.error(f"OBJ to GLB conversion failed: {e}", exc_info=True)
            return False
    
    def _find_blender_executable(self) -> Optional[Path]:
        """Find Blender executable on the system."""
        common_paths = [
            # Windows
            Path("C:/Program Files/Blender Foundation/Blender 4.0/blender.exe"),
            Path("C:/Program Files/Blender Foundation/Blender 3.6/blender.exe"),
            Path("C:/Program Files/Blender Foundation/Blender 3.3/blender.exe"),
            # Linux
            Path("/usr/bin/blender"),
            Path("/opt/blender/blender"),
            Path("/snap/bin/blender"),
            # macOS
            Path("/Applications/Blender.app/Contents/MacOS/Blender"),
        ]
        
        # Check common installation paths
        for path in common_paths:
            if path.exists():
                logger.info(f"Found Blender executable: {path}")
                return path
        
        # Try to find in PATH
        try:
            result = subprocess.run(['which', 'blender'], capture_output=True, text=True)
            if result.returncode == 0:
                blender_path = Path(result.stdout.strip())
                if blender_path.exists():
                    logger.info(f"Found Blender in PATH: {blender_path}")
                    return blender_path
        except (subprocess.SubprocessError, FileNotFoundError):
            pass
        
        # Try Windows where command
        try:
            result = subprocess.run(['where', 'blender'], capture_output=True, text=True, shell=True)
            if result.returncode == 0:
                blender_path = Path(result.stdout.strip().split('\n')[0])
                if blender_path.exists():
                    logger.info(f"Found Blender via where: {blender_path}")
                    return blender_path
        except (subprocess.SubprocessError, FileNotFoundError):
            pass
        
        logger.warning("Blender executable not found - please install Blender or specify path")
        return None
    
    def _generate_conversion_script(self, obj_path: Path, glb_path: Path, 
                                   optimize_for_godot: bool) -> str:
        """Generate Blender Python script for OBJ to GLB conversion."""
        return f'''
import bpy
import bmesh
import os
import sys
from pathlib import Path

def clear_scene():
    """Clear default scene objects."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def import_obj_with_materials(obj_file):
    """Import OBJ file with materials."""
    try:
        bpy.ops.import_scene.obj(
            filepath=str(obj_file),
            use_edges=True,
            use_smooth_groups=True,
            use_split_objects=True,
            use_split_groups=True,
            use_groups_as_vgroups=False,
            use_image_search=True,
            split_mode='ON',
            global_clamp_size=0.0
        )
        print(f"Successfully imported OBJ: {{obj_file}}")
        return True
    except Exception as e:
        print(f"Failed to import OBJ {{obj_file}}: {{e}}")
        return False

def optimize_for_godot():
    """Apply Godot-specific optimizations."""
    # Select all mesh objects
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    
    for obj in mesh_objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        
        # Enter edit mode and select all
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        
        # Remove doubles and clean up geometry
        bpy.ops.mesh.remove_doubles(threshold=0.0001)
        bpy.ops.mesh.dissolve_degenerate()
        bpy.ops.mesh.normals_make_consistent(inside=False)
        
        # Triangulate (important for consistent Godot import)
        bpy.ops.mesh.quads_convert_to_tris(quad_method='BEAUTY', ngon_method='BEAUTY')
        
        # Return to object mode
        bpy.ops.object.mode_set(mode='OBJECT')
        
        obj.select_set(False)
    
    print("Applied Godot optimizations")

def setup_materials_for_gltf():
    """Ensure materials are properly configured for GLTF export."""
    for material in bpy.data.materials:
        if material.use_nodes:
            # Ensure proper GLTF material setup
            nodes = material.node_tree.nodes
            links = material.node_tree.links
            
            # Find principled BSDF
            principled = None
            for node in nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    principled = node
                    break
            
            if not principled:
                # Create principled BSDF if missing
                principled = nodes.new(type='ShaderNodeBsdfPrincipled')
                output = nodes.get('Material Output')
                if output:
                    links.new(principled.outputs[0], output.inputs[0])
    
    print("Configured materials for GLTF export")

def export_glb(output_file):
    """Export scene as GLB."""
    try:
        bpy.ops.export_scene.gltf(
            filepath=str(output_file),
            export_format='GLB',
            export_image_format='JPEG',
            export_texture_dir='',
            export_keep_originals=False,
            export_texcoords=True,
            export_normals=True,
            export_tangents=True,
            export_materials='EXPORT',
            export_colors=True,
            use_mesh_edges=False,
            use_mesh_vertices=False,
            export_cameras=False,
            export_lights=False,
            export_apply=True,
            export_yup=True  # Important for Godot compatibility
        )
        print(f"Successfully exported GLB: {{output_file}}")
        return True
    except Exception as e:
        print(f"Failed to export GLB {{output_file}}: {{e}}")
        return False

def main():
    """Main conversion function."""
    obj_file = Path(r"{obj_path}")
    glb_file = Path(r"{glb_path}")
    optimize = {str(optimize_for_godot).lower()}
    
    print(f"Starting OBJ to GLB conversion")
    print(f"Input: {{obj_file}}")
    print(f"Output: {{glb_file}}")
    print(f"Optimize for Godot: {{optimize}}")
    
    # Ensure output directory exists
    glb_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Clear default scene
    clear_scene()
    
    # Import OBJ file
    if not import_obj_with_materials(obj_file):
        print("Failed to import OBJ file")
        sys.exit(1)
    
    # Apply optimizations if requested
    if optimize == "true":
        optimize_for_godot()
        setup_materials_for_gltf()
    
    # Export GLB
    if not export_glb(glb_file):
        print("Failed to export GLB file")
        sys.exit(1)
    
    print("Conversion completed successfully")

if __name__ == "__main__":
    main()
'''
    
    def _execute_blender_conversion(self, script_path: Path) -> bool:
        """Execute Blender with conversion script."""
        try:
            cmd = [
                str(self.blender_executable),
                '--background',  # Run without GUI
                '--python', str(script_path)
            ]
            
            logger.debug(f"Executing Blender command: {' '.join(cmd)}")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            if result.returncode == 0:
                logger.debug("Blender conversion completed successfully")
                if result.stdout:
                    logger.debug(f"Blender stdout: {result.stdout}")
                return True
            else:
                logger.error(f"Blender conversion failed with code {result.returncode}")
                if result.stderr:
                    logger.error(f"Blender stderr: {result.stderr}")
                if result.stdout:
                    logger.error(f"Blender stdout: {result.stdout}")
                return False
                
        except subprocess.TimeoutExpired:
            logger.error("Blender conversion timed out")
            return False
        except Exception as e:
            logger.error(f"Failed to execute Blender: {e}", exc_info=True)
            return False
    
    def _create_conversion_script(self) -> str:
        """Create base Blender Python script template."""
        return """
# Base Blender conversion script template
# This will be customized for each conversion job
"""

class BlenderBatchConverter:
    """Batch converter for multiple OBJ files."""
    
    def __init__(self, blender_executable: Optional[Path] = None):
        """Initialize batch converter."""
        self.converter = BlenderOBJConverter(blender_executable)
    
    def convert_directory(self, input_dir: Path, output_dir: Path, 
                         pattern: str = "*.obj") -> Dict[str, bool]:
        """
        Convert all OBJ files in directory to GLB.
        
        Args:
            input_dir: Directory containing OBJ files
            output_dir: Directory for GLB output
            pattern: File pattern to match
            
        Returns:
            Dictionary mapping input files to conversion success status
        """
        if not self.converter.blender_executable:
            logger.error("Blender not available for batch conversion")
            return {}
        
        results: Dict[str, bool] = {}
        obj_files = list(input_dir.glob(pattern))
        
        logger.info(f"Starting batch conversion of {len(obj_files)} files")
        
        for obj_file in obj_files:
            glb_file = output_dir / obj_file.with_suffix('.glb').name
            success = self.converter.convert_obj_to_glb(obj_file, glb_file)
            results[str(obj_file)] = success
            
            if success:
                logger.info(f"✓ Converted: {obj_file.name}")
            else:
                logger.error(f"✗ Failed: {obj_file.name}")
        
        successful = sum(1 for success in results.values() if success)
        logger.info(f"Batch conversion complete: {successful}/{len(obj_files)} successful")
        
        return results

# Example usage and testing
if __name__ == '__main__':
    import sys
    
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    
    if len(sys.argv) < 3:
        print("Usage: python blender_converter.py <input.obj> <output.glb>")
        sys.exit(1)
    
    obj_path = Path(sys.argv[1])
    glb_path = Path(sys.argv[2])
    
    converter = BlenderOBJConverter()
    if converter.convert_obj_to_glb(obj_path, glb_path):
        print(f"Successfully converted {obj_path} to {glb_path}")
    else:
        print(f"Failed to convert {obj_path}")
        sys.exit(1)