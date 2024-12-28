"""POF to GLTF converter"""

import logging
import json
from pathlib import Path
from typing import Dict, Any, Optional

from .base_converter import BaseConverter, AsyncProgress
from .pof.pof_file import POFFile
from .pof.pof_to_gltf import convert_pof_to_gltf
from .pof.vector3d import Vector3D

logger = logging.getLogger(__name__)

class POFConverter(BaseConverter):
    """Converter for POF (Parallax Object Format) files used in Wing Commander Saga"""
    
    def __init__(self, input_dir: str, output_dir: str, force: bool = False):
        super().__init__(input_dir, output_dir, force)
        self.coordinate_scale = 0.01  # Convert from cm to m
        
        # Configure logging
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.DEBUG)
        
        # Add file handler
        fh = logging.FileHandler('pof_converter.log')
        fh.setLevel(logging.DEBUG)
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        fh.setFormatter(formatter)
        self.logger.addHandler(fh)
        
    def convert_vector(self, v: Vector3D, is_normal: bool = False) -> list:
        """Convert POF vector to Godot coordinates
        
        POF uses right-handed coordinates:
        - X right
        - Y up
        - Z forward
        
        Godot uses left-handed coordinates:
        - X right
        - Y up
        - Z forward
        
        We need to:
        1. Negate X to flip handedness
        2. Scale position vectors (not normals) from cm to m
        """
        scale = self.coordinate_scale if not is_normal else 1.0
        return [-v.x * scale, v.y * scale, v.z * scale]
    
    @property
    def source_extension(self) -> str:
        return '.pof'
        
    @property
    def target_extension(self) -> str:
        return '.glb'  # Using binary GLTF format
    
    def write_metadata(self, pof_file: POFFile, output_path: Path) -> None:
        """Write POF metadata to JSON file"""
        metadata = {
            'version': pof_file.version,
            'textures': pof_file.textures,
            'header': {
                'max_radius': pof_file.header.max_radius * self.coordinate_scale,
                'obj_flags': pof_file.header.obj_flags,
                'num_subobjects': pof_file.header.num_subobjects,
                'mass': pof_file.header.mass,
                'mass_center': self.convert_vector(pof_file.header.mass_center),
                'moment_inertia': pof_file.header.moment_inertia,
                'bounding': {
                    'min': self.convert_vector(pof_file.header.min_bounding),
                    'max': self.convert_vector(pof_file.header.max_bounding)
                },
                'detail_levels': pof_file.header.detail_levels,
                'debris_pieces': pof_file.header.debris_pieces,
                'cross_sections': [
                    {
                        'depth': cs[0] * self.coordinate_scale,
                        'radius': cs[1] * self.coordinate_scale
                    }
                    for cs in pof_file.header.cross_sections
                ]
            },
            'subobjects': [
                {
                    'name': obj.name,
                    'number': obj.number,
                    'parent': obj.parent,
                    'properties': obj.properties,
                    'movement': {
                        'type': obj.movement_type,
                        'axis': obj.movement_axis
                    },
                    'bounds': {
                        'min': self.convert_vector(obj.bounding_min),
                        'max': self.convert_vector(obj.bounding_max),
                        'radius': obj.radius * self.coordinate_scale
                    },
                    'offset': self.convert_vector(obj.offset),
                    'center': self.convert_vector(obj.geometric_center)
                }
                for obj in pof_file.objects
            ],
            'special_points': [
                {
                    'name': point[0],
                    'properties': point[1],
                    'position': self.convert_vector(point[2]),
                    'radius': point[3] * self.coordinate_scale
                }
                for point in pof_file.specials
            ],
            'docking': [
                {
                    'properties': dock[0],
                    'paths': dock[1],
                    'points': [
                        {
                            'position': self.convert_vector(p[0]),
                            'normal': self.convert_vector(p[1], True)
                        }
                        for p in dock[2]
                    ]
                }
                for dock in pof_file.docking_points
            ],
            'turrets': [
                {
                    'type': turret.weapon_type,
                    'parent': turret.sobj_parent,
                    'parent_phys': turret.sobj_par_phys,
                    'normal': self.convert_vector(turret.normal, True),
                    'fire_points': [
                        self.convert_vector(p)
                        for p in turret.fire_points
                    ]
                }
                for turret in pof_file.gun_turrets + pof_file.missile_turrets
            ],
            'thrusters': [
                {
                    'properties': thruster.properties,
                    'points': [
                        {
                            'position': self.convert_vector(p.position),
                            'normal': self.convert_vector(p.normal, True),
                            'radius': p.radius * self.coordinate_scale
                        }
                        for p in thruster.points
                    ]
                }
                for thruster in pof_file.thrusters
            ],
            'glow_arrays': [
                {
                    'display_time': array.disp_time,
                    'on_time': array.on_time,
                    'off_time': array.off_time,
                    'obj_parent': array.obj_parent,
                    'LOD': array.LOD,
                    'type': array.type,
                    'properties': array.properties,
                    'points': [
                        {
                            'position': self.convert_vector(p.position),
                            'normal': self.convert_vector(p.normal, True),
                            'radius': p.radius * self.coordinate_scale
                        }
                        for p in array.points
                    ]
                }
                for array in pof_file.glow_banks
            ],
            'shield': {
                'faces': [
                    {
                        'normal': self.convert_vector(face[0], True),
                        'vertices': [
                            self.convert_vector(v)
                            for v in face[1]
                        ],
                        'neighbors': face[2]
                    }
                    for face in pof_file.shield_mesh
                ]
            },
            'eye_points': [
                {
                    'subobj_num': eye[0],
                    'offset': self.convert_vector(eye[1]),
                    'normal': self.convert_vector(eye[2], True)
                }
                for eye in pof_file.eyes
            ],
            'insignia': [
                {
                    'detail_level': ins.lod,
                    'offset': self.convert_vector(ins.offset),
                    'faces': [
                        {
                            'vertices': [
                                self.convert_vector(v.position)
                                for v in face.vertices
                            ],
                            'uvs': [
                                [v.u, v.v]
                                for v in face.vertices
                            ]
                        }
                        for face in ins.faces
                    ]
                }
                for ins in pof_file.insignias
            ],
            'paths': [
                {
                    'name': path[0],
                    'parent': path[1],
                    'points': [
                        {
                            'position': self.convert_vector(p[0]),
                            'radius': p[1] * self.coordinate_scale,
                            'turret_ids': p[2]
                        }
                        for p in path[2]
                    ]
                }
                for path in pof_file.paths
            ]
        }
        
        metadata_path = output_path.with_suffix('.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
            
    def process_textures(self, pof_file: POFFile, output_dir: Path) -> None:
        """Process and convert textures if needed"""
        from .dds_converter import DDSConverter
        from .pcx_converter import PCXConverter
        
        dds_converter = DDSConverter()
        pcx_converter = PCXConverter()
        
        for i, texture in enumerate(pof_file.textures):
            texture_path = Path(texture)
            if not texture_path.is_absolute():
                texture_path = output_dir / texture_path.name
                
            # Convert DDS textures to PNG
            if texture_path.suffix.lower() == '.dds':
                png_path = texture_path.with_suffix('.png')
                if dds_converter.convert_file(texture_path, png_path):
                    # Update texture path in POF data
                    pof_file.textures[i] = png_path.name
                    
            # Convert PCX textures to PNG
            elif texture_path.suffix.lower() == '.pcx':
                png_path = texture_path.with_suffix('.png')
                if pcx_converter.convert_file(texture_path, png_path):
                    # Update texture path in POF data
                    pof_file.textures[i] = png_path.name
    
    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert a POF file to GLTF format with metadata"""
        try:
            self.logger.info(f"Starting conversion of {input_path}")
            
            # Create output directory if needed
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Parse POF file
            pof_file = POFFile()
            with open(input_path, 'rb') as f:
                pof_file.read(f)
            
            # Validate POF data
            if pof_file.version < 2116:
                self.logger.error(f"Unsupported POF version: {pof_file.version}")
                return False
                
            # Process textures
            self.process_textures(pof_file, output_path.parent)
            
            # Convert to GLTF
            progress = AsyncProgress()
            convert_pof_to_gltf(pof_file, str(output_path), progress)
            
            # Write metadata
            self.write_metadata(pof_file, output_path)
            
            self.logger.info(f"Successfully converted {input_path} to {output_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error converting {input_path}: {e}", exc_info=True)
            # Clean up any partially written files
            self.cleanup_failed_conversion(output_path)
            return False
            
    def cleanup_failed_conversion(self, output_path: Path) -> None:
        """Clean up files from failed conversion"""
        # Remove GLTF file
        if output_path.exists():
            output_path.unlink()
            
        # Remove metadata file
        metadata_path = output_path.with_suffix('.json')
        if metadata_path.exists():
            metadata_path.unlink()
            
        # Remove buffer file
        buffer_path = output_path.parent / "buffer0.bin"
        if buffer_path.exists():
            buffer_path.unlink()
            
        # Remove converted textures
        for ext in ['.png']:
            for texture in output_path.parent.glob(f"*{ext}"):
                if texture.exists():
                    texture.unlink()
