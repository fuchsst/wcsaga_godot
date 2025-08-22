#!/usr/bin/env python3
"""
WCS Shader Mapper - EPIC-003 DM-006 Implementation

Shader mapper for WCS-specific effects (glow, transparency, special modes).
Maps WCS rendering effects to appropriate Godot shader equivalents and custom shaders.
"""

import json
import logging
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

from .godot_material_converter import WCSMaterialProperties, WCSRenderMode


class WCSShaderEffect(Enum):
    """WCS-specific shader effects that need custom mapping."""
    GLOW_TEXTURE = "glow_texture"
    ANIMATED_TEXTURE = "animated_texture"
    ENVIRONMENT_MAP = "environment_map"
    CLOAK_EFFECT = "cloak_effect"
    SHIELD_IMPACT = "shield_impact"
    THRUSTER_FLAME = "thruster_flame"
    ENGINE_GLOW = "engine_glow"
    WEAPON_FLASH = "weapon_flash"
    DAMAGE_DECALS = "damage_decals"
    SELF_ILLUMINATION = "self_illumination"


class GodotShaderType(Enum):
    """Godot shader types for WCS effects."""
    STANDARD_MATERIAL = "standard_material"  # Built-in StandardMaterial3D
    CUSTOM_SHADER = "custom_shader"  # Custom shader material
    CANVAS_SHADER = "canvas_shader"  # 2D/UI shader
    COMPUTE_SHADER = "compute_shader"  # Compute shader for effects


@dataclass
class ShaderMapping:
    """Maps WCS effect to Godot shader implementation."""
    
    wcs_effect: WCSShaderEffect
    godot_shader_type: GodotShaderType
    shader_path: Optional[str] = None  # Path to custom shader file
    parameters: Dict[str, Any] = None  # Shader parameters
    fallback_material: Optional[str] = None  # Fallback to standard material
    
    def __post_init__(self) -> None:
        """Initialize default values."""
        if self.parameters is None:
            self.parameters = {}


@dataclass
class WCSShaderConfiguration:
    """Configuration for WCS-specific shader effects."""
    
    # Glow effects
    glow_intensity_multiplier: float = 2.0
    glow_bloom_threshold: float = 0.8
    glow_animation_speed: float = 1.0
    
    # Transparency effects
    alpha_test_threshold: float = 0.5
    transparency_fade_distance: float = 100.0
    
    # Animation settings
    texture_animation_fps: float = 15.0
    thruster_flicker_frequency: float = 30.0
    
    # Cloak effects
    cloak_distortion_strength: float = 0.1
    cloak_noise_scale: float = 4.0
    cloak_animation_speed: float = 0.5
    
    # Performance settings
    use_simplified_shaders: bool = False
    max_shader_complexity: int = 3  # 1=basic, 2=medium, 3=high
    enable_dynamic_lod: bool = True


class WCSShaderMapper:
    """Maps WCS shader effects to Godot shader implementations."""
    
    def __init__(self, config: Optional[WCSShaderConfiguration] = None) -> None:
        """Initialize shader mapper with configuration."""
        self.config = config or WCSShaderConfiguration()
        self.logger = logging.getLogger(__name__)
        
        # Initialize shader mappings
        self.shader_mappings = self._create_shader_mappings()
        
        # Built-in shader templates
        self.shader_templates = self._load_shader_templates()
    
    def _create_shader_mappings(self) -> Dict[WCSShaderEffect, ShaderMapping]:
        """Create mapping from WCS effects to Godot shaders."""
        mappings = {
            WCSShaderEffect.GLOW_TEXTURE: ShaderMapping(
                wcs_effect=WCSShaderEffect.GLOW_TEXTURE,
                godot_shader_type=GodotShaderType.STANDARD_MATERIAL,
                parameters={
                    'emission_enabled': True,
                    'emission_energy': self.config.glow_intensity_multiplier
                },
                fallback_material="emission_material"
            ),
            
            WCSShaderEffect.ANIMATED_TEXTURE: ShaderMapping(
                wcs_effect=WCSShaderEffect.ANIMATED_TEXTURE,
                godot_shader_type=GodotShaderType.CUSTOM_SHADER,
                shader_path="res://shaders/wcs_animated_texture.gdshader",
                parameters={
                    'animation_speed': self.config.texture_animation_fps,
                    'frame_count': 4  # Default frame count
                }
            ),
            
            WCSShaderEffect.CLOAK_EFFECT: ShaderMapping(
                wcs_effect=WCSShaderEffect.CLOAK_EFFECT,
                godot_shader_type=GodotShaderType.CUSTOM_SHADER,
                shader_path="res://shaders/wcs_cloak_effect.gdshader",
                parameters={
                    'distortion_strength': self.config.cloak_distortion_strength,
                    'noise_scale': self.config.cloak_noise_scale,
                    'animation_speed': self.config.cloak_animation_speed
                }
            ),
            
            WCSShaderEffect.SHIELD_IMPACT: ShaderMapping(
                wcs_effect=WCSShaderEffect.SHIELD_IMPACT,
                godot_shader_type=GodotShaderType.CUSTOM_SHADER,
                shader_path="res://shaders/wcs_shield_impact.gdshader",
                parameters={
                    'impact_radius': 2.0,
                    'impact_strength': 1.0,
                    'fade_time': 0.5
                }
            ),
            
            WCSShaderEffect.THRUSTER_FLAME: ShaderMapping(
                wcs_effect=WCSShaderEffect.THRUSTER_FLAME,
                godot_shader_type=GodotShaderType.CUSTOM_SHADER,
                shader_path="res://shaders/wcs_thruster_flame.gdshader",
                parameters={
                    'flame_intensity': 1.0,
                    'flicker_frequency': self.config.thruster_flicker_frequency,
                    'color_temperature': 3000.0  # Kelvin
                }
            ),
            
            WCSShaderEffect.ENGINE_GLOW: ShaderMapping(
                wcs_effect=WCSShaderEffect.ENGINE_GLOW,
                godot_shader_type=GodotShaderType.STANDARD_MATERIAL,
                parameters={
                    'emission_enabled': True,
                    'emission_energy': 3.0,
                    'transparency': 1,  # Alpha blend
                    'blend_mode': 1  # Additive
                },
                fallback_material="additive_glow_material"
            ),
            
            WCSShaderEffect.WEAPON_FLASH: ShaderMapping(
                wcs_effect=WCSShaderEffect.WEAPON_FLASH,
                godot_shader_type=GodotShaderType.CUSTOM_SHADER,
                shader_path="res://shaders/wcs_weapon_flash.gdshader",
                parameters={
                    'flash_duration': 0.1,
                    'flash_intensity': 5.0,
                    'flash_color': [1.0, 0.8, 0.4]  # Warm white
                }
            ),
            
            WCSShaderEffect.DAMAGE_DECALS: ShaderMapping(
                wcs_effect=WCSShaderEffect.DAMAGE_DECALS,
                godot_shader_type=GodotShaderType.CUSTOM_SHADER,
                shader_path="res://shaders/wcs_damage_decals.gdshader",
                parameters={
                    'decal_strength': 1.0,
                    'burn_color': [0.2, 0.1, 0.05],  # Dark brown
                    'spark_intensity': 0.5
                }
            ),
            
            WCSShaderEffect.SELF_ILLUMINATION: ShaderMapping(
                wcs_effect=WCSShaderEffect.SELF_ILLUMINATION,
                godot_shader_type=GodotShaderType.STANDARD_MATERIAL,
                parameters={
                    'shading_mode': 0,  # Unshaded
                    'emission_enabled': True,
                    'emission_energy': 1.0
                },
                fallback_material="unshaded_material"
            ),
            
            WCSShaderEffect.ENVIRONMENT_MAP: ShaderMapping(
                wcs_effect=WCSShaderEffect.ENVIRONMENT_MAP,
                godot_shader_type=GodotShaderType.CUSTOM_SHADER,
                shader_path="res://shaders/wcs_environment_map.gdshader",
                parameters={
                    'reflection_strength': 0.3,
                    'environment_texture': "res://textures/space_environment.hdr"
                }
            )
        }
        
        return mappings
    
    def _load_shader_templates(self) -> Dict[str, str]:
        """Load built-in shader templates for WCS effects."""
        templates = {
            'animated_texture': '''
shader_type canvas_item;

uniform float animation_speed : hint_range(0.1, 30.0) = 15.0;
uniform int frame_count : hint_range(1, 64) = 4;
uniform sampler2D texture_atlas;

void fragment() {
    float frame = floor(TIME * animation_speed);
    float frame_index = mod(frame, float(frame_count));
    
    vec2 frame_size = vec2(1.0 / float(frame_count), 1.0);
    vec2 frame_offset = vec2(frame_index * frame_size.x, 0.0);
    
    vec2 animated_uv = UV * frame_size + frame_offset;
    COLOR = texture(texture_atlas, animated_uv);
}
''',
            
            'cloak_effect': '''
shader_type spatial;
render_mode transparency = alpha, cull_disabled;

uniform float distortion_strength : hint_range(0.0, 1.0) = 0.1;
uniform float noise_scale : hint_range(1.0, 10.0) = 4.0;
uniform float animation_speed : hint_range(0.1, 2.0) = 0.5;
uniform float alpha : hint_range(0.0, 1.0) = 0.3;

vec2 random(vec2 st) {
    st = vec2(dot(st, vec2(127.1, 311.7)), dot(st, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(random(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(random(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(random(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(random(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec2 distorted_uv = UV;
    distorted_uv += noise(UV * noise_scale + TIME * animation_speed) * distortion_strength;
    
    ALBEDO = vec3(0.5, 0.7, 1.0); // Slight blue tint
    ALPHA = alpha * (0.5 + 0.5 * noise(distorted_uv * 2.0));
}
''',
            
            'thruster_flame': '''
shader_type spatial;
render_mode transparency = alpha, cull_disabled, unshaded;

uniform float flame_intensity : hint_range(0.0, 5.0) = 1.0;
uniform float flicker_frequency : hint_range(1.0, 60.0) = 30.0;
uniform float color_temperature : hint_range(1000.0, 10000.0) = 3000.0;
uniform sampler2D noise_texture;

vec3 blackbody_color(float temperature) {
    // Simplified blackbody radiation color
    temperature = clamp(temperature, 1000.0, 10000.0);
    float t = temperature / 1000.0;
    
    vec3 color;
    if (t < 3.0) {
        color = vec3(1.0, 0.3 + 0.3 * (t - 1.0) / 2.0, 0.0);
    } else {
        color = vec3(1.0, 0.6 + 0.4 * (3.0 - t) / 7.0, (t - 3.0) / 7.0);
    }
    
    return color;
}

void fragment() {
    vec2 centered_uv = UV - vec2(0.5);
    float distance_from_center = length(centered_uv);
    
    // Create flame shape (wider at base, narrower at tip)
    float flame_shape = 1.0 - smoothstep(0.0, 0.5, distance_from_center);
    flame_shape *= (1.0 - UV.y); // Fade towards tip
    
    // Add noise for flickering
    float flicker = texture(noise_texture, UV + TIME * 0.1).r;
    flicker = 0.5 + 0.5 * sin(TIME * flicker_frequency) * flicker;
    
    // Calculate final intensity
    float intensity = flame_intensity * flame_shape * flicker;
    
    // Get flame color based on temperature
    vec3 flame_color = blackbody_color(color_temperature);
    
    ALBEDO = flame_color;
    EMISSION = flame_color * intensity;
    ALPHA = intensity;
}
''',
            
            'shield_impact': '''
shader_type spatial;
render_mode transparency = alpha, cull_disabled;

uniform float impact_radius : hint_range(0.1, 10.0) = 2.0;
uniform float impact_strength : hint_range(0.0, 2.0) = 1.0;
uniform float fade_time : hint_range(0.1, 2.0) = 0.5;
uniform vec3 impact_position;
uniform float impact_time;
uniform vec3 shield_color : hint_color = vec3(0.2, 0.6, 1.0);

void fragment() {
    vec3 world_pos = VERTEX;
    float distance_to_impact = length(world_pos - impact_position);
    
    // Calculate impact effect based on time and distance
    float time_factor = 1.0 - clamp((TIME - impact_time) / fade_time, 0.0, 1.0);
    float distance_factor = 1.0 - clamp(distance_to_impact / impact_radius, 0.0, 1.0);
    
    float impact_intensity = impact_strength * time_factor * distance_factor;
    
    // Create ripple effect
    float ripple = sin(distance_to_impact * 10.0 - TIME * 20.0) * 0.5 + 0.5;
    impact_intensity *= ripple;
    
    ALBEDO = shield_color;
    EMISSION = shield_color * impact_intensity;
    ALPHA = impact_intensity * 0.7;
}
'''
        }
        
        return templates
    
    def map_wcs_effect_to_shader(self, wcs_material: WCSMaterialProperties) -> Optional[ShaderMapping]:
        """Map WCS material to appropriate shader implementation."""
        try:
            # Determine primary WCS effect for this material
            effect = self._identify_primary_effect(wcs_material)
            
            if effect in self.shader_mappings:
                mapping = self.shader_mappings[effect]
                
                # Customize parameters based on material properties
                customized_mapping = self._customize_shader_parameters(mapping, wcs_material)
                
                self.logger.debug(f"Mapped material {wcs_material.name} to {effect.value}")
                return customized_mapping
            else:
                self.logger.warning(f"No shader mapping for effect: {effect}")
                return None
                
        except Exception as e:
            self.logger.error(f"Failed to map shader for material {wcs_material.name}: {e}")
            return None
    
    def _identify_primary_effect(self, wcs_material: WCSMaterialProperties) -> WCSShaderEffect:
        """Identify the primary WCS effect for a material."""
        # Check for specific render modes first
        if wcs_material.render_mode == WCSRenderMode.CLOAK:
            return WCSShaderEffect.CLOAK_EFFECT
        elif wcs_material.render_mode == WCSRenderMode.SELFILLUM:
            return WCSShaderEffect.SELF_ILLUMINATION
        elif wcs_material.render_mode == WCSRenderMode.ADDITIVE:
            # Could be thruster or weapon effect
            if 'thruster' in wcs_material.name.lower() or 'engine' in wcs_material.name.lower():
                return WCSShaderEffect.THRUSTER_FLAME
            else:
                return WCSShaderEffect.ENGINE_GLOW
        
        # Check for animated textures
        if wcs_material.is_animated and wcs_material.frame_count > 1:
            return WCSShaderEffect.ANIMATED_TEXTURE
        
        # Check for glow effects
        if (wcs_material.glow_texture or 
            wcs_material.glow_intensity > 0.0 or 
            wcs_material.render_mode == WCSRenderMode.GLOW):
            return WCSShaderEffect.GLOW_TEXTURE
        
        # Check material name for specific effects
        name_lower = wcs_material.name.lower()
        if 'shield' in name_lower:
            return WCSShaderEffect.SHIELD_IMPACT
        elif 'weapon' in name_lower or 'flash' in name_lower:
            return WCSShaderEffect.WEAPON_FLASH
        elif 'damage' in name_lower or 'burn' in name_lower:
            return WCSShaderEffect.DAMAGE_DECALS
        elif 'reflect' in name_lower or 'chrome' in name_lower:
            return WCSShaderEffect.ENVIRONMENT_MAP
        
        # Default to glow texture for any emission
        return WCSShaderEffect.GLOW_TEXTURE
    
    def _customize_shader_parameters(self, mapping: ShaderMapping, 
                                   wcs_material: WCSMaterialProperties) -> ShaderMapping:
        """Customize shader parameters based on WCS material properties."""
        customized_mapping = ShaderMapping(
            wcs_effect=mapping.wcs_effect,
            godot_shader_type=mapping.godot_shader_type,
            shader_path=mapping.shader_path,
            parameters=mapping.parameters.copy(),
            fallback_material=mapping.fallback_material
        )
        
        # Customize based on WCS material properties
        if mapping.wcs_effect == WCSShaderEffect.GLOW_TEXTURE:
            if wcs_material.glow_intensity > 0.0:
                customized_mapping.parameters['emission_energy'] = wcs_material.glow_intensity
        
        elif mapping.wcs_effect == WCSShaderEffect.ANIMATED_TEXTURE:
            if wcs_material.frame_count > 1:
                customized_mapping.parameters['frame_count'] = wcs_material.frame_count
        
        elif mapping.wcs_effect == WCSShaderEffect.CLOAK_EFFECT:
            # Adjust cloak alpha based on material transparency
            customized_mapping.parameters['alpha'] = wcs_material.transparency * 0.5
        
        elif mapping.wcs_effect == WCSShaderEffect.THRUSTER_FLAME:
            # Adjust flame color based on material color
            if wcs_material.diffuse_color:
                avg_color = sum(wcs_material.diffuse_color) / 3.0
                if avg_color > 0.8:  # Bright colors = hot flame
                    customized_mapping.parameters['color_temperature'] = 4000.0
                elif avg_color < 0.3:  # Dark colors = cool flame
                    customized_mapping.parameters['color_temperature'] = 2500.0
        
        return customized_mapping
    
    def generate_custom_shader(self, mapping: ShaderMapping, output_path: Path) -> bool:
        """Generate custom shader file for WCS effect."""
        try:
            if mapping.godot_shader_type != GodotShaderType.CUSTOM_SHADER:
                return False
            
            effect_name = mapping.wcs_effect.value
            if effect_name not in self.shader_templates:
                self.logger.error(f"No shader template for effect: {effect_name}")
                return False
            
            # Get base shader template
            shader_code = self.shader_templates[effect_name]
            
            # Customize shader parameters if needed
            customized_shader = self._customize_shader_code(shader_code, mapping.parameters)
            
            # Ensure output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write shader file
            with open(output_path, 'w') as f:
                f.write(customized_shader)
            
            self.logger.info(f"Generated custom shader: {output_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to generate custom shader: {e}")
            return False
    
    def _customize_shader_code(self, base_shader: str, parameters: Dict[str, Any]) -> str:
        """Customize shader code with specific parameters."""
        # For now, return base shader
        # In a full implementation, this would substitute parameter values
        # into the shader template based on the parameters dict
        
        customized = base_shader
        
        # Example customization: replace default values with parameter values
        for param_name, param_value in parameters.items():
            if isinstance(param_value, (int, float)):
                # Look for uniform declarations and update default values
                import re
                pattern = rf'uniform\s+\w+\s+{param_name}\s*:[^=]*=\s*[\d.]+;'
                replacement = f'uniform float {param_name} = {param_value};'
                customized = re.sub(pattern, replacement, customized)
        
        return customized
    
    def create_material_with_shader(self, wcs_material: WCSMaterialProperties,
                                  shader_mapping: ShaderMapping) -> Dict[str, Any]:
        """Create Godot material configuration with custom shader."""
        material_config = {
            'resource_type': 'ShaderMaterial' if shader_mapping.godot_shader_type == GodotShaderType.CUSTOM_SHADER else 'StandardMaterial3D',
            'resource_name': f"{wcs_material.name}_shader",
            'wcs_effect': shader_mapping.wcs_effect.value
        }
        
        if shader_mapping.godot_shader_type == GodotShaderType.CUSTOM_SHADER:
            material_config['shader_path'] = shader_mapping.shader_path
            material_config['shader_parameters'] = shader_mapping.parameters
        else:
            # Use StandardMaterial3D properties
            material_config['material_properties'] = shader_mapping.parameters
        
        return material_config
    
    def generate_shader_report(self, materials: List[WCSMaterialProperties]) -> Dict[str, Any]:
        """Generate report of shader usage and effects."""
        report = {
            'total_materials': len(materials),
            'shader_effect_distribution': {},
            'custom_shaders_needed': 0,
            'standard_materials': 0,
            'complex_effects': [],
            'performance_analysis': {
                'transparent_shaders': 0,
                'animated_shaders': 0,
                'compute_intensive_shaders': 0
            }
        }
        
        for material in materials:
            mapping = self.map_wcs_effect_to_shader(material)
            if mapping:
                effect_name = mapping.wcs_effect.value
                report['shader_effect_distribution'][effect_name] = \
                    report['shader_effect_distribution'].get(effect_name, 0) + 1
                
                if mapping.godot_shader_type == GodotShaderType.CUSTOM_SHADER:
                    report['custom_shaders_needed'] += 1
                    
                    # Check for complex effects
                    if mapping.wcs_effect in [WCSShaderEffect.CLOAK_EFFECT, 
                                            WCSShaderEffect.SHIELD_IMPACT,
                                            WCSShaderEffect.THRUSTER_FLAME]:
                        report['complex_effects'].append({
                            'material': material.name,
                            'effect': effect_name,
                            'complexity': 'high'
                        })
                        report['performance_analysis']['compute_intensive_shaders'] += 1
                    
                    if material.is_animated:
                        report['performance_analysis']['animated_shaders'] += 1
                    
                    if material.transparency < 1.0:
                        report['performance_analysis']['transparent_shaders'] += 1
                
                else:
                    report['standard_materials'] += 1
        
        return report
    
    def save_shader_mapping_config(self, output_path: Path) -> None:
        """Save shader mapping configuration to file."""
        try:
            config_data = {
                'wcs_shader_configuration': {
                    'glow_intensity_multiplier': self.config.glow_intensity_multiplier,
                    'glow_bloom_threshold': self.config.glow_bloom_threshold,
                    'texture_animation_fps': self.config.texture_animation_fps,
                    'use_simplified_shaders': self.config.use_simplified_shaders,
                    'max_shader_complexity': self.config.max_shader_complexity
                },
                'shader_mappings': {}
            }
            
            # Convert shader mappings to serializable format
            for effect, mapping in self.shader_mappings.items():
                config_data['shader_mappings'][effect.value] = {
                    'godot_shader_type': mapping.godot_shader_type.value,
                    'shader_path': mapping.shader_path,
                    'parameters': mapping.parameters,
                    'fallback_material': mapping.fallback_material
                }
            
            # Ensure output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write configuration
            with open(output_path, 'w') as f:
                json.dump(config_data, f, indent=2)
            
            self.logger.info(f"Saved shader mapping configuration: {output_path}")
            
        except Exception as e:
            self.logger.error(f"Failed to save shader configuration: {e}")
            raise


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Create shader mapper with custom configuration
    config = WCSShaderConfiguration(
        glow_intensity_multiplier=1.5,
        use_simplified_shaders=False,
        max_shader_complexity=3
    )
    
    mapper = WCSShaderMapper(config)
    
    # Create example WCS materials
    from .godot_material_converter import create_example_wcs_materials
    materials = create_example_wcs_materials()
    
    # Add some shader-specific materials
    materials.extend([
        WCSMaterialProperties(
            name="cloak_material",
            render_mode=WCSRenderMode.CLOAK,
            transparency=0.2
        ),
        WCSMaterialProperties(
            name="animated_display",
            diffuse_texture="display_anim.png",
            is_animated=True,
            frame_count=8
        ),
        WCSMaterialProperties(
            name="thruster_flame",
            diffuse_color=[1.0, 0.3, 0.1],
            render_mode=WCSRenderMode.ADDITIVE,
            glow_intensity=2.0
        )
    ])
    
    # Map materials to shaders
    print("Shader Mapping Results:")
    for material in materials:
        mapping = mapper.map_wcs_effect_to_shader(material)
        if mapping:
            print(f"  {material.name}: {mapping.wcs_effect.value} "
                  f"({mapping.godot_shader_type.value})")
        else:
            print(f"  {material.name}: No mapping found")
    
    # Generate shader report
    report = mapper.generate_shader_report(materials)
    print(f"\nShader Report:")
    print(f"  Total materials: {report['total_materials']}")
    print(f"  Custom shaders needed: {report['custom_shaders_needed']}")
    print(f"  Standard materials: {report['standard_materials']}")
    print(f"  Complex effects: {len(report['complex_effects'])}")
    
    # Save configuration
    config_path = Path("wcs_shader_config.json")
    mapper.save_shader_mapping_config(config_path)
    print(f"\nSaved configuration to: {config_path}")