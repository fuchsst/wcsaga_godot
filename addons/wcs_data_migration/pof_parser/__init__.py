#!/usr/bin/env python3
"""
POF (Parallax Object Format) Parser for WCS-Godot Conversion

This module provides comprehensive parsing of WCS POF model files, extracting
geometry, materials, textures, and metadata for conversion to Godot-compatible formats.

Follows EPIC-003 architecture for data migration and conversion tools.
"""

from .pof_chunks import (  # Constants needed by other modules; Chunk IDs
    ID_ACEN, ID_DOCK, ID_EYE, ID_FUEL, ID_GLOW, ID_GPNT, ID_INSG, ID_MPNT,
    ID_OHDR, ID_PATH, ID_SHLD, ID_SLDC, ID_SOBJ, ID_SPCL, ID_TXTR,
    MAX_DEBRIS_OBJECTS, MAX_DOCK_SLOTS, MAX_EYES, MAX_MODEL_DETAIL_LEVELS,
    MAX_NAME_LEN, MAX_PROP_LEN, MAX_SLOTS, MAX_SPLIT_PLANE, MAX_TFP,
    parse_bsp_data, read_byte, read_chunk_header, read_float, read_int,
    read_matrix, read_short, read_string, read_string_len, read_ubyte,
    read_uint, read_unknown_chunk, read_ushort, read_vector)
from .pof_data_extractor import POFDataExtractor
from .pof_docking_parser import read_dock_chunk
from .pof_eye_parser import read_eye_chunk
from .pof_format_analyzer import POFFormatAnalyzer
from .pof_header_parser import read_ohdr_chunk
from .pof_insignia_parser import read_insg_chunk
from .pof_misc_parser import (  # read_unknown_chunk is in pof_chunks
    read_acen_chunk, read_glow_chunk)
from .pof_parser import POFParser
from .pof_path_parser import read_path_chunk
from .pof_shield_parser import read_shld_chunk, read_sldc_chunk
from .pof_special_points_parser import read_spcl_chunk
from .pof_subobject_parser import read_sobj_chunk
from .pof_texture_parser import read_txtr_chunk
from .pof_thruster_parser import read_fuel_chunk
from .pof_to_gltf import convert_pof_to_gltf
from .pof_weapon_points_parser import read_gpnt_chunk, read_mpnt_chunk
from .vector3d import Vector3D

__all__ = [
    # Core classes/functions
    "Vector3D",
    "POFParser",
    "POFFormatAnalyzer", 
    "POFDataExtractor",
    "convert_pof_to_gltf",
    # Chunk reading functions
    "read_chunk_header",
    "read_ohdr_chunk",
    "read_sobj_chunk",
    "read_txtr_chunk",
    "read_spcl_chunk",
    "read_path_chunk",
    "read_gpnt_chunk",
    "read_mpnt_chunk",
    "read_dock_chunk",
    "read_fuel_chunk",
    "read_shld_chunk",
    "read_eye_chunk",
    "read_insg_chunk",
    "read_acen_chunk",
    "read_glow_chunk",
    "read_sldc_chunk",
    "read_unknown_chunk",
    "parse_bsp_data",
    # Helper reading functions (if needed externally, though maybe not)
    "read_int", "read_uint", "read_short", "read_ushort",
    "read_float", "read_byte", "read_ubyte", "read_vector", "read_matrix",
    "read_string", "read_string_len",
    # Constants
    "MAX_NAME_LEN", "MAX_PROP_LEN", "MAX_MODEL_DETAIL_LEVELS", "MAX_DEBRIS_OBJECTS",
    "MAX_SLOTS", "MAX_DOCK_SLOTS", "MAX_TFP", "MAX_EYES", "MAX_SPLIT_PLANE",
    # Chunk IDs
    "ID_OHDR", "ID_SOBJ", "ID_TXTR", "ID_SPCL", "ID_PATH", "ID_GPNT", "ID_MPNT",
    "ID_DOCK", "ID_FUEL", "ID_SHLD", "ID_EYE", "ID_INSG", "ID_ACEN", "ID_GLOW", "ID_SLDC"
]
