#!/usr/bin/env python3
import logging
import json
from pathlib import Path
from typing import Dict, Any, Optional

from .base_converter import BaseConverter, AsyncProgress
from .pof.pof_parser import POFParser # Import the POF parser
from .pof.pof_to_gltf import convert_pof_to_gltf # Import the GLTF converter

logger = logging.getLogger(__name__)

class POFConverter(BaseConverter):
    """Converter for POF (Parallax Object Format) files used in Wing Commander Saga"""

    def __init__(self, input_dir: str = "extracted/wcsaga_models", output_dir: str = "assets/models", force: bool = False):
        # Override default input/output directories specifically for POF
        super().__init__(input_dir, output_dir, force)
        self.coordinate_scale = 1.0 # POF units seem to be meters already based on analysis? Adjust if needed.
        self.logger = logging.getLogger(__name__)

    @property
    def source_extension(self) -> str:
        return '.pof'

    @property
    def target_extension(self) -> str:
        # Primary output is GLB
        return '.glb'

    def convert_vector(self, v: list, is_normal: bool = False) -> list:
        """
        Convert POF vector (list [x, y, z]) to Godot coordinates.
        POF: +X Right, +Y Up, +Z Forward (Right-Handed)
        Godot: +X Right, +Y Up, -Z Forward (Left-Handed)

        Transformation: Negate Z. Apply scale if not a normal.
        """
        scale = self.coordinate_scale if not is_normal else 1.0
        # Check if v is a list or tuple with 3 elements
        if not isinstance(v, (list, tuple)) or len(v) != 3:
             # Handle potential Vector3D objects if pof_parser returns them
            if hasattr(v, 'x') and hasattr(v, 'y') and hasattr(v, 'z'):
                 return [v.x * scale, v.y * scale, -v.z * scale]
            else:
                logger.warning(f"Invalid vector format received: {v}. Returning [0,0,0].")
                return [0.0, 0.0, 0.0]

        return [v[0] * scale, v[1] * scale, -v[2] * scale]


    def write_metadata(self, pof_data: Dict[str, Any], output_path: Path) -> bool:
        """Write POF metadata to JSON file, converting coordinates."""
        metadata = {
            'version': pof_data.get('version', 0),
            'textures': pof_data.get('textures', []),
            'header': {},
            'subobjects': [],
            'special_points': [],
            'docking_points': [],
            'turrets': [],
            'thrusters': [],
            'glow_arrays': [],
            'shield': {},
            'eye_points': [],
            'insignia': [],
            'paths': []
        }

        try:
            # --- Populate Header ---
            header_in = pof_data.get('header', {})
            metadata['header'] = {
                'max_radius': header_in.get('max_radius', 0.0) * self.coordinate_scale,
                'obj_flags': header_in.get('obj_flags', 0),
                'num_subobjects': header_in.get('num_subobjects', 0),
                'mass': header_in.get('mass', 0.0),
                'mass_center': self.convert_vector(header_in.get('mass_center', [0,0,0])),
                'moment_inertia': header_in.get('moment_inertia', []), # Assuming this is already a list/matrix
                'bounding_box': {
                    'min': self.convert_vector(header_in.get('min_bounding', [0,0,0])),
                    'max': self.convert_vector(header_in.get('max_bounding', [0,0,0]))
                },
                'detail_levels': header_in.get('detail_levels', []),
                'debris_pieces': header_in.get('debris_pieces', []),
                'cross_sections': [
                    {'depth': cs[0] * self.coordinate_scale, 'radius': cs[1] * self.coordinate_scale}
                    for cs in header_in.get('cross_sections', []) if isinstance(cs, (list, tuple)) and len(cs) == 2
                ]
            }

            # --- Populate Subobjects ---
            for obj_in in pof_data.get('objects', []):
                metadata['subobjects'].append({
                    'name': obj_in.get('name', ''),
                    'parent': obj_in.get('parent', -1),
                    'properties': obj_in.get('properties', ''),
                    'movement_type': obj_in.get('movement_type', -1),
                    'movement_axis': obj_in.get('movement_axis', -1),
                    'bounding_box': {
                        'min': self.convert_vector(obj_in.get('bounding_min', [0,0,0])),
                        'max': self.convert_vector(obj_in.get('bounding_max', [0,0,0]))
                    },
                    'radius': obj_in.get('radius', 0.0) * self.coordinate_scale,
                    'offset': self.convert_vector(obj_in.get('offset', [0,0,0])),
                    'geometric_center': self.convert_vector(obj_in.get('geometric_center', [0,0,0]))
                })

            # --- Populate Special Points ---
            for sp_in in pof_data.get('specials', []):
                if isinstance(sp_in, (list, tuple)) and len(sp_in) == 4:
                    metadata['special_points'].append({
                        'name': sp_in[0],
                        'properties': sp_in[1],
                        'position': self.convert_vector(sp_in[2]),
                        'radius': sp_in[3] * self.coordinate_scale
                    })
                else:
                    logger.warning(f"Skipping malformed special point data: {sp_in}")


            # --- Populate Docking Points ---
            for dock_in in pof_data.get('docking_points', []):
                 if isinstance(dock_in, (list, tuple)) and len(dock_in) == 3:
                    metadata['docking_points'].append({
                        'properties': dock_in[0],
                        'paths': dock_in[1], # Path indices, no conversion needed
                        'points': [
                            {'position': self.convert_vector(p[0]), 'normal': self.convert_vector(p[1], True)}
                            for p in dock_in[2] if isinstance(p, (list, tuple)) and len(p) == 2
                        ]
                    })
                 else:
                    logger.warning(f"Skipping malformed docking point data: {dock_in}")

            # --- Populate Turrets ---
            for turret_in in pof_data.get('gun_turrets', []) + pof_data.get('missile_turrets', []):
                if isinstance(turret_in, dict):
                    metadata['turrets'].append({
                        'parent': turret_in.get('sobj_parent', -1),
                        'normal': self.convert_vector(turret_in.get('normal', [0,0,1]), True),
                        'fire_points': [self.convert_vector(p) for p in turret_in.get('fire_points', [])]
                    })
                else:
                    logger.warning(f"Skipping malformed turret data: {turret_in}")

            # --- Populate Thrusters ---
            for thruster_in in pof_data.get('thrusters', []):
                if isinstance(thruster_in, dict):
                    metadata['thrusters'].append({
                        'properties': thruster_in.get('properties', ''),
                        'points': [
                            {'position': self.convert_vector(p.get('position', [0,0,0])),
                            'normal': self.convert_vector(p.get('normal', [0,0,1]), True),
                            'radius': p.get('radius', 0.0) * self.coordinate_scale}
                            for p in thruster_in.get('points', []) if isinstance(p, dict)
                        ]
                    })
                else:
                    logger.warning(f"Skipping malformed thruster data: {thruster_in}")

            # --- Populate Glow Banks ---
            for glow_in in pof_data.get('glow_banks', []):
                if isinstance(glow_in, dict):
                    metadata['glow_arrays'].append({
                        'disp_time': glow_in.get('disp_time', 0),
                        'on_time': glow_in.get('on_time', 0),
                        'off_time': glow_in.get('off_time', 0),
                        'parent': glow_in.get('obj_parent', -1),
                        'lod': glow_in.get('LOD', 0),
                        'type': glow_in.get('type', 0),
                        'properties': glow_in.get('properties', ''),
                        'points': [
                            {'position': self.convert_vector(p.get('position', [0,0,0])),
                            'normal': self.convert_vector(p.get('normal', [0,0,1]), True),
                            'radius': p.get('radius', 0.0) * self.coordinate_scale}
                            for p in glow_in.get('points', []) if isinstance(p, dict)
                        ]
                    })
                else:
                    logger.warning(f"Skipping malformed glow bank data: {glow_in}")

            # --- Populate Shield Mesh ---
            shield_in = pof_data.get('shield_mesh', [])
            metadata['shield'] = {
                'faces': [
                    {'normal': self.convert_vector(face[0], True),
                    'vertices': [self.convert_vector(v) for v in face[1]],
                    'neighbors': face[2]} # Indices, no conversion
                    for face in shield_in if isinstance(face, (list, tuple)) and len(face) == 3
                ]
            }

            # --- Populate Eye Points ---
            for eye_in in pof_data.get('eyes', []):
                if isinstance(eye_in, (list, tuple)) and len(eye_in) == 3:
                    metadata['eye_points'].append({
                        'parent': eye_in[0],
                        'position': self.convert_vector(eye_in[1]),
                        'normal': self.convert_vector(eye_in[2], True)
                    })
                else:
                    logger.warning(f"Skipping malformed eye point data: {eye_in}")

            # --- Populate Insignia ---
            for ins_in in pof_data.get('insignias', []):
                if isinstance(ins_in, dict):
                    metadata['insignia'].append({
                        'lod': ins_in.get('lod', 0),
                        'offset': self.convert_vector(ins_in.get('offset', [0,0,0])),
                        'faces': [
                            {'vertices': [self.convert_vector(v.get('position', [0,0,0])) for v in face.get('vertices', []) if isinstance(v, dict)],
                            'uvs': [[v.get('u', 0.0), v.get('v', 0.0)] for v in face.get('vertices', []) if isinstance(v, dict)]}
                            for face in ins_in.get('faces', []) if isinstance(face, dict)
                        ]
                    })
                else:
                    logger.warning(f"Skipping malformed insignia data: {ins_in}")

            # --- Populate Paths ---
            for path_in in pof_data.get('paths', []):
                if isinstance(path_in, (list, tuple)) and len(path_in) == 3:
                    metadata['paths'].append({
                        'name': path_in[0],
                        'parent': path_in[1],
                        'points': [
                            {'position': self.convert_vector(p[0]),
                            'radius': p[1] * self.coordinate_scale,
                            'turret_ids': p[2]} # Indices, no conversion
                            for p in path_in[2] if isinstance(p, (list, tuple)) and len(p) == 3
                        ]
                    })
                else:
                    logger.warning(f"Skipping malformed path data: {path_in}")


            # --- Write JSON ---
            metadata_path = output_path.with_suffix('.json')
            with open(metadata_path, 'w') as f:
                json.dump(metadata, f, indent=2)
            logger.info(f"Wrote metadata to {metadata_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to write metadata for {output_path}: {e}", exc_info=True)
            return False


    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert a POF file to GLTF format with metadata"""
        try:
            self.logger.info(f"Starting conversion of {input_path}")

            # Create output directory if needed
            output_path.parent.mkdir(parents=True, exist_ok=True)

            # --- Parse POF ---
            pof_parser = POFParser()
            pof_data = pof_parser.parse(input_path)
            if not pof_data:
                self.logger.error(f"Failed to parse POF file: {input_path}")
                return False
            self.logger.debug(f"Successfully parsed POF: {input_path}")

            # --- Convert to GLTF ---
            progress = AsyncProgress() # Assuming AsyncProgress is defined elsewhere
            success = convert_pof_to_gltf(pof_data, str(output_path), progress, self.coordinate_scale)
            if not success:
                self.logger.error(f"Failed to convert POF to GLTF: {input_path}")
                self.cleanup_failed_conversion(output_path) # Clean up GLB if metadata fails
                return False
            self.logger.info(f"Successfully converted POF to GLB: {output_path}")

            # --- Write Metadata ---
            if not self.write_metadata(pof_data, output_path):
                 self.logger.error(f"Failed to write metadata for {input_path}")
                 self.cleanup_failed_conversion(output_path) # Clean up GLB if metadata fails
                 return False

            self.logger.info(f"Successfully converted {input_path} to {output_path} and metadata")
            return True

        except Exception as e:
            self.logger.error(f"Error converting {input_path}: {e}", exc_info=True)
            # Clean up any partially written files
            self.cleanup_failed_conversion(output_path)
            return False

    def cleanup_failed_conversion(self, output_path: Path) -> None:
        """Clean up files from failed conversion"""
        # Remove GLB file
        glb_path = output_path.with_suffix('.glb')
        if glb_path.exists():
            try:
                glb_path.unlink()
                logger.info(f"Cleaned up {glb_path}")
            except OSError as e:
                logger.error(f"Error removing {glb_path}: {e}")

        # Remove metadata file
        metadata_path = output_path.with_suffix('.json')
        if metadata_path.exists():
             try:
                metadata_path.unlink()
                logger.info(f"Cleaned up {metadata_path}")
             except OSError as e:
                logger.error(f"Error removing {metadata_path}: {e}")
