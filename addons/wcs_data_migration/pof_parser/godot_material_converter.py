#!/usr/bin/env python3
"""
Godot Material Converter - EPIC-003 DM-006 Implementation

Material property converter that maps WCS materials to Godot equivalents.
Generates Godot-optimized materials with proper shader assignment, texture mapping,
and rendering properties based on WCS material specifications.
"""

import json
import logging
from dataclasses import asdict, dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Union


class WCSRenderMode(Enum):
    """WCS rendering modes for materials."""
    NORMAL = "normal"
    GLOW = "glow"
    TRANSPARENT = "transparent"  
    ADDITIVE = "additive"
    GLASS = "glass"
    SPECULAR = "specular"
    SELFILLUM = "selfillum"
    CLOAK = "cloak"


class GodotBlendMode(Enum):
    """Godot blend modes for materials."""
    MIX = 0
    ADD = 1
    SUB = 2
    MUL = 3
    ALPHA_BLEND = 0  # Default transparent blend


@dataclass
class WCSMaterialProperties:
    """WCS material properties extracted from POF."""
    
    name: str
    diffuse_texture: Optional[str] = None
    glow_texture: Optional[str] = None
    specular_texture: Optional[str] = None
    normal_texture: Optional[str] = None
    height_texture: Optional[str] = None
    
    # Color properties
    diffuse_color: List[float] = None  # RGB [0-1]
    specular_color: List[float] = None  # RGB [0-1]
    ambient_color: List[float] = None  # RGB [0-1]
    
    # Material properties
    shininess: float = 32.0
    transparency: float = 1.0  # 0=transparent, 1=opaque
    glow_intensity: float = 0.0  # Self-illumination strength
    
    # WCS-specific flags
    render_mode: WCSRenderMode = WCSRenderMode.NORMAL
    is_animated: bool = False
    frame_count: int = 1
    
    def __post_init__(self) -> None:
        """Initialize default values."""
        if self.diffuse_color is None:
            self.diffuse_color = [1.0, 1.0, 1.0]
        if self.specular_color is None:
            self.specular_color = [1.0, 1.0, 1.0]
        if self.ambient_color is None:
            self.ambient_color = [0.1, 0.1, 0.1]


@dataclass 
class GodotMaterialProperties:
    """Godot StandardMaterial3D properties."""
    
    # Resource properties
    resource_type: str = "StandardMaterial3D"
    resource_name: str = ""
    
    # Albedo properties
    albedo_color: List[float] = None  # RGBA [0-1]
    albedo_texture: Optional[str] = None
    
    # Metallic/Roughness
    metallic: float = 0.0
    metallic_texture: Optional[str] = None
    roughness: float = 1.0
    roughness_texture: Optional[str] = None
    
    # Normal mapping
    normal_enabled: bool = False
    normal_texture: Optional[str] = None
    normal_scale: float = 1.0
    
    # Emission (glow)
    emission_enabled: bool = False
    emission_color: List[float] = None  # RGB [0-1]
    emission_texture: Optional[str] = None
    emission_energy: float = 1.0
    
    # Transparency
    transparency: int = 0  # 0=opaque, 1=alpha, 2=alpha_scissor
    alpha_scissor_threshold: float = 0.5
    
    # Special effects
    billboard_mode: int = 0  # 0=disabled
    blend_mode: int = 0  # GodotBlendMode
    
    # Performance settings
    shading_mode: int = 1  # 0=unshaded, 1=per_pixel, 2=per_vertex
    specular_mode: int = 0  # 0=schlick_ggx, 1=blinn, 2=phong, 3=toon, 4=disabled
    
    # Texture filtering
    texture_filter: int = 3  # 0=nearest, 3=linear_mipmap
    
    def __post_init__(self) -> None:
        """Initialize default values."""
        if self.albedo_color is None:
            self.albedo_color = [1.0, 1.0, 1.0, 1.0]
        if self.emission_color is None:
            self.emission_color = [0.0, 0.0, 0.0]


class GodotMaterialConverter:
    """Converts WCS materials to Godot StandardMaterial3D format."""
    
    def __init__(self) -> None:
        """Initialize material converter."""
        self.logger = logging.getLogger(__name__)
        
        # WCS to Godot render mode mapping
        self.render_mode_mapping = {
            WCSRenderMode.NORMAL: {
                'transparency': 0,  # Opaque
                'blend_mode': GodotBlendMode.MIX.value,
                'shading_mode': 1,  # Per-pixel
                'specular_mode': 0  # Schlick GGX
            },
            WCSRenderMode.GLOW: {
                'transparency': 0,
                'blend_mode': GodotBlendMode.MIX.value,
                'emission_enabled': True,
                'shading_mode': 1,
                'specular_mode': 0
            },
            WCSRenderMode.TRANSPARENT: {
                'transparency': 1,  # Alpha blend
                'blend_mode': GodotBlendMode.ALPHA_BLEND.value,
                'shading_mode': 1,
                'specular_mode': 0
            },
            WCSRenderMode.ADDITIVE: {
                'transparency': 1,
                'blend_mode': GodotBlendMode.ADD.value,
                'shading_mode': 1,
                'specular_mode': 4  # Disabled for additive
            },
            WCSRenderMode.GLASS: {
                'transparency': 1,
                'blend_mode': GodotBlendMode.ALPHA_BLEND.value,
                'shading_mode': 1,
                'specular_mode': 0,
                'metallic': 0.1,
                'roughness': 0.0
            },
            WCSRenderMode.SPECULAR: {
                'transparency': 0,
                'blend_mode': GodotBlendMode.MIX.value,
                'shading_mode': 1,
                'specular_mode': 0,
                'metallic': 0.8,
                'roughness': 0.2
            },
            WCSRenderMode.SELFILLUM: {
                'transparency': 0,
                'blend_mode': GodotBlendMode.MIX.value,
                'emission_enabled': True,
                'shading_mode': 0,  # Unshaded for full self-illumination
                'specular_mode': 4  # Disabled
            },
            WCSRenderMode.CLOAK: {
                'transparency': 1,
                'blend_mode': GodotBlendMode.ALPHA_BLEND.value,
                'shading_mode': 1,
                'specular_mode': 4  # Disabled
            }
        }
    
    def convert_material(self, wcs_material: WCSMaterialProperties,
                        texture_dir: Optional[Path] = None) -> GodotMaterialProperties:
        """Convert WCS material to Godot StandardMaterial3D."""
        try:
            # Create base Godot material
            godot_material = GodotMaterialProperties()
            godot_material.resource_name = wcs_material.name
            
            # Map basic color properties
            self._map_color_properties(wcs_material, godot_material)
            
            # Map texture properties
            self._map_texture_properties(wcs_material, godot_material, texture_dir)
            
            # Map render mode and special effects
            self._map_render_mode(wcs_material, godot_material)
            
            # Map material properties (roughness, metallic, etc.)
            self._map_material_properties(wcs_material, godot_material)
            
            # Handle transparency
            self._map_transparency(wcs_material, godot_material)
            
            # Handle glow/emission
            self._map_emission_properties(wcs_material, godot_material)
            
            # Optimize for performance based on usage
            self._optimize_material_performance(godot_material)
            
            self.logger.debug(f"Converted material: {wcs_material.name}")
            return godot_material
            
        except Exception as e:
            self.logger.error(f"Failed to convert material {wcs_material.name}: {e}")
            raise
    
    def _map_color_properties(self, wcs: WCSMaterialProperties, 
                             godot: GodotMaterialProperties) -> None:
        """Map color properties from WCS to Godot."""
        # Convert diffuse color to albedo
        godot.albedo_color = wcs.diffuse_color + [wcs.transparency]
        
        # Convert specular properties to metallic/roughness workflow
        # WCS shininess to Godot roughness (inverse relationship)
        # Shininess 0-128 maps to roughness 1.0-0.0
        shininess_normalized = min(wcs.shininess / 128.0, 1.0)
        godot.roughness = 1.0 - shininess_normalized
        
        # Estimate metallic value from specular color intensity
        if wcs.specular_color:
            specular_intensity = sum(wcs.specular_color) / 3.0
            # Higher specular intensity suggests more metallic
            godot.metallic = min(specular_intensity * 0.5, 1.0)
    
    def _map_texture_properties(self, wcs: WCSMaterialProperties,
                               godot: GodotMaterialProperties,
                               texture_dir: Optional[Path]) -> None:
        """Map texture properties from WCS to Godot."""
        # Map diffuse texture to albedo
        if wcs.diffuse_texture:
            godot.albedo_texture = self._convert_texture_path(wcs.diffuse_texture, texture_dir)
        
        # Map glow texture to emission
        if wcs.glow_texture:
            godot.emission_enabled = True
            godot.emission_texture = self._convert_texture_path(wcs.glow_texture, texture_dir)
        
        # Map specular texture to roughness (inverted)
        if wcs.specular_texture:
            godot.roughness_texture = self._convert_texture_path(wcs.specular_texture, texture_dir)
        
        # Map normal texture
        if wcs.normal_texture:
            godot.normal_enabled = True
            godot.normal_texture = self._convert_texture_path(wcs.normal_texture, texture_dir)
            godot.normal_scale = 1.0
    
    def _convert_texture_path(self, wcs_texture: str, texture_dir: Optional[Path]) -> str:
        """Convert WCS texture path to Godot resource path."""
        # Remove file extension and convert to Godot path format
        base_name = Path(wcs_texture).stem
        
        if texture_dir:
            # Relative path from project root
            godot_path = f"res://{texture_dir.name}/{base_name}.png"
        else:
            # Default texture location
            godot_path = f"res://textures/{base_name}.png"
        
        return godot_path
    
    def _map_render_mode(self, wcs: WCSMaterialProperties,
                        godot: GodotMaterialProperties) -> None:
        """Map WCS render mode to Godot material settings."""
        if wcs.render_mode in self.render_mode_mapping:
            mode_settings = self.render_mode_mapping[wcs.render_mode]
            
            # Apply all settings for this render mode
            for property_name, value in mode_settings.items():
                if hasattr(godot, property_name):
                    setattr(godot, property_name, value)
    
    def _map_material_properties(self, wcs: WCSMaterialProperties,
                                godot: GodotMaterialProperties) -> None:
        """Map additional material properties."""
        # Handle animated textures
        if wcs.is_animated and wcs.frame_count > 1:
            # Note: Godot handles animated textures differently
            # This would require custom shader or AnimationPlayer
            self.logger.warning(
                f"Material {wcs.name} has animated texture "
                f"({wcs.frame_count} frames) - requires custom shader"
            )
    
    def _map_transparency(self, wcs: WCSMaterialProperties,
                         godot: GodotMaterialProperties) -> None:
        """Map transparency settings."""
        if wcs.transparency < 1.0:
            godot.transparency = 1  # Alpha blend
            godot.albedo_color[3] = wcs.transparency  # Set alpha channel
        
        # Handle special transparency modes
        if wcs.render_mode in [WCSRenderMode.TRANSPARENT, WCSRenderMode.ADDITIVE, 
                              WCSRenderMode.GLASS, WCSRenderMode.CLOAK]:
            godot.transparency = 1
    
    def _map_emission_properties(self, wcs: WCSMaterialProperties,
                                godot: GodotMaterialProperties) -> None:
        """Map emission/glow properties."""
        if wcs.glow_intensity > 0.0 or wcs.render_mode == WCSRenderMode.GLOW:
            godot.emission_enabled = True
            godot.emission_energy = max(wcs.glow_intensity, 1.0)
            
            # Use glow color or diffuse color for emission
            if wcs.glow_texture:
                # Emission texture will be mapped separately
                godot.emission_color = [1.0, 1.0, 1.0]
            else:
                # Use material color for emission
                godot.emission_color = wcs.diffuse_color.copy()
    
    def _optimize_material_performance(self, godot: GodotMaterialProperties) -> None:
        """Optimize material for performance."""
        # Disable unnecessary features for better performance
        
        # If no normal texture, disable normal mapping
        if not godot.normal_texture:
            godot.normal_enabled = False
        
        # If fully opaque, use opaque mode
        if godot.albedo_color[3] >= 0.99:
            godot.transparency = 0
            godot.albedo_color[3] = 1.0
        
        # Use vertex shading for very simple materials
        if (not godot.normal_enabled and 
            not godot.emission_enabled and 
            godot.metallic == 0.0 and 
            godot.roughness == 1.0):
            godot.shading_mode = 2  # Per-vertex for performance
    
    def convert_material_batch(self, wcs_materials: List[WCSMaterialProperties],
                              texture_dir: Optional[Path] = None) -> List[GodotMaterialProperties]:
        """Convert multiple WCS materials to Godot format."""
        converted_materials = []
        
        for wcs_material in wcs_materials:
            try:
                godot_material = self.convert_material(wcs_material, texture_dir)
                converted_materials.append(godot_material)
            except Exception as e:
                self.logger.error(f"Failed to convert material {wcs_material.name}: {e}")
                # Continue with other materials
                continue
        
        self.logger.info(f"Converted {len(converted_materials)}/{len(wcs_materials)} materials")
        return converted_materials
    
    def save_godot_material(self, material: GodotMaterialProperties, 
                           output_path: Path) -> None:
        """Save Godot material to .tres resource file."""
        try:
            # Create Godot .tres resource format
            tres_content = self._generate_tres_content(material)
            
            # Ensure output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write .tres file
            with open(output_path, 'w') as f:
                f.write(tres_content)
            
            self.logger.debug(f"Saved Godot material: {output_path}")
            
        except Exception as e:
            self.logger.error(f"Failed to save material {material.resource_name}: {e}")
            raise
    
    def _generate_tres_content(self, material: GodotMaterialProperties) -> str:
        """Generate Godot .tres resource file content."""
        lines = [
            f"[gd_resource type=\"StandardMaterial3D\" format=3]",
            "",
            "[resource]"
        ]
        
        # Add non-default properties
        if material.albedo_color != [1.0, 1.0, 1.0, 1.0]:
            color_str = f"Color({material.albedo_color[0]}, {material.albedo_color[1]}, {material.albedo_color[2]}, {material.albedo_color[3]})"
            lines.append(f"albedo_color = {color_str}")
        
        if material.albedo_texture:
            lines.append(f"albedo_texture = preload(\"{material.albedo_texture}\")")
        
        if material.metallic != 0.0:
            lines.append(f"metallic = {material.metallic}")
        
        if material.metallic_texture:
            lines.append(f"metallic_texture = preload(\"{material.metallic_texture}\")")
        
        if material.roughness != 1.0:
            lines.append(f"roughness = {material.roughness}")
        
        if material.roughness_texture:
            lines.append(f"roughness_texture = preload(\"{material.roughness_texture}\")")
        
        if material.normal_enabled:
            lines.append(f"normal_enabled = true")
            if material.normal_texture:
                lines.append(f"normal_texture = preload(\"{material.normal_texture}\")")
            if material.normal_scale != 1.0:
                lines.append(f"normal_scale = {material.normal_scale}")
        
        if material.emission_enabled:
            lines.append(f"emission_enabled = true")
            if material.emission_color != [0.0, 0.0, 0.0]:
                color_str = f"Color({material.emission_color[0]}, {material.emission_color[1]}, {material.emission_color[2]})"
                lines.append(f"emission = {color_str}")
            if material.emission_texture:
                lines.append(f"emission_texture = preload(\"{material.emission_texture}\")")
            if material.emission_energy != 1.0:
                lines.append(f"emission_energy = {material.emission_energy}")
        
        if material.transparency != 0:
            lines.append(f"transparency = {material.transparency}")
            if material.transparency == 2:  # Alpha scissor
                lines.append(f"alpha_scissor_threshold = {material.alpha_scissor_threshold}")
        
        if material.shading_mode != 1:
            lines.append(f"shading_mode = {material.shading_mode}")
        
        if material.specular_mode != 0:
            lines.append(f"specular_mode = {material.specular_mode}")
        
        if material.blend_mode != 0:
            lines.append(f"blend_mode = {material.blend_mode}")
        
        return "\n".join(lines)
    
    def generate_material_report(self, wcs_materials: List[WCSMaterialProperties],
                               godot_materials: List[GodotMaterialProperties]) -> Dict[str, Any]:
        """Generate material conversion report."""
        report = {
            'conversion_summary': {
                'total_wcs_materials': len(wcs_materials),
                'total_godot_materials': len(godot_materials),
                'conversion_success_rate': len(godot_materials) / max(len(wcs_materials), 1)
            },
            'render_mode_distribution': {},
            'texture_usage': {
                'diffuse_textures': 0,
                'normal_textures': 0,
                'emission_textures': 0,
                'roughness_textures': 0
            },
            'performance_analysis': {
                'transparent_materials': 0,
                'emissive_materials': 0,
                'normal_mapped_materials': 0,
                'vertex_shaded_materials': 0
            }
        }
        
        # Analyze WCS materials
        for wcs_mat in wcs_materials:
            mode_str = wcs_mat.render_mode.value
            report['render_mode_distribution'][mode_str] = \
                report['render_mode_distribution'].get(mode_str, 0) + 1
        
        # Analyze Godot materials
        for godot_mat in godot_materials:
            if godot_mat.albedo_texture:
                report['texture_usage']['diffuse_textures'] += 1
            if godot_mat.normal_enabled and godot_mat.normal_texture:
                report['texture_usage']['normal_textures'] += 1
            if godot_mat.emission_enabled and godot_mat.emission_texture:
                report['texture_usage']['emission_textures'] += 1
            if godot_mat.roughness_texture:
                report['texture_usage']['roughness_textures'] += 1
            
            if godot_mat.transparency > 0:
                report['performance_analysis']['transparent_materials'] += 1
            if godot_mat.emission_enabled:
                report['performance_analysis']['emissive_materials'] += 1
            if godot_mat.normal_enabled:
                report['performance_analysis']['normal_mapped_materials'] += 1
            if godot_mat.shading_mode == 2:
                report['performance_analysis']['vertex_shaded_materials'] += 1
        
        return report


# Example WCS material creation for testing
def create_example_wcs_materials() -> List[WCSMaterialProperties]:
    """Create example WCS materials for testing."""
    materials = [
        WCSMaterialProperties(
            name="hull_material",
            diffuse_texture="hull_diff.png",
            normal_texture="hull_norm.png",
            specular_texture="hull_spec.png",
            diffuse_color=[0.7, 0.7, 0.8],
            shininess=64.0,
            render_mode=WCSRenderMode.NORMAL
        ),
        WCSMaterialProperties(
            name="engine_glow",
            diffuse_texture="engine_diff.png",
            glow_texture="engine_glow.png",
            diffuse_color=[0.2, 0.6, 1.0],
            glow_intensity=2.0,
            render_mode=WCSRenderMode.GLOW
        ),
        WCSMaterialProperties(
            name="glass_cockpit",
            diffuse_texture="glass_diff.png",
            diffuse_color=[0.9, 0.9, 1.0],
            transparency=0.3,
            shininess=128.0,
            render_mode=WCSRenderMode.GLASS
        ),
        WCSMaterialProperties(
            name="thruster_flame",
            diffuse_texture="flame_diff.png",
            diffuse_color=[1.0, 0.5, 0.1],
            transparency=0.7,
            render_mode=WCSRenderMode.ADDITIVE
        )
    ]
    
    return materials


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Create converter
    converter = GodotMaterialConverter()
    
    # Create example materials
    wcs_materials = create_example_wcs_materials()
    
    # Convert materials
    godot_materials = converter.convert_material_batch(wcs_materials)
    
    # Generate report
    report = converter.generate_material_report(wcs_materials, godot_materials)
    
    print("Material Conversion Report:")
    print(json.dumps(report, indent=2))
    
    # Save example material
    if godot_materials:
        example_path = Path("example_material.tres")
        converter.save_godot_material(godot_materials[0], example_path)
        print(f"\nSaved example material to: {example_path}")