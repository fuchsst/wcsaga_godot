#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

from .pof_chunks import (MAX_DEBRIS_OBJECTS, MAX_MODEL_DETAIL_LEVELS,
                         read_float, read_int, read_uint, read_vector)

# Import Vector3D if needed for type hinting or direct use, though read_vector returns it
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_ohdr_chunk(f: BinaryIO, length: int) -> Dict[str, Any]:
    """Parses the Object Header (OHDR/HDR2) chunk."""
    start_pos = f.tell()
    header_data = {}
    header_data['max_radius'] = read_float(f)
    header_data['obj_flags'] = read_uint(f)
    header_data['num_subobjects'] = read_int(f)

    min_bounding = read_vector(f)
    max_bounding = read_vector(f)
    header_data['min_bounding'] = min_bounding.to_list()
    header_data['max_bounding'] = max_bounding.to_list()

    header_data['detail_levels'] = [read_int(f) for _ in range(MAX_MODEL_DETAIL_LEVELS)]
    header_data['debris_pieces'] = [read_int(f) for _ in range(MAX_DEBRIS_OBJECTS)]

    # Mass, Center of Mass, Moment of Inertia (Added in later POF versions)
    # Check remaining length to determine if these fields exist
    bytes_read = f.tell() - start_pos
    if bytes_read < length:
        header_data['mass'] = read_float(f); bytes_read += 4
    else:
        header_data['mass'] = 0.0

    if bytes_read < length:
        mass_center = read_vector(f); bytes_read += 12
        header_data['mass_center'] = mass_center.to_list()
    else:
        header_data['mass_center'] = [0.0, 0.0, 0.0]

    if bytes_read < length:
         # Moment of inertia (3x3 matrix stored as 3 vectors)
        rvec = read_vector(f); bytes_read += 12
        uvec = read_vector(f); bytes_read += 12
        fvec = read_vector(f); bytes_read += 12
        # Store as list of lists (rows)
        header_data['moment_inertia'] = [rvec.to_list(), uvec.to_list(), fvec.to_list()]
    else:
        header_data['moment_inertia'] = [[1,0,0],[0,1,0],[0,0,1]] # Identity matrix

    # Cross Sections (Added later)
    header_data['cross_sections'] = []
    if bytes_read < length:
        num_cross_sections = read_int(f); bytes_read += 4
        for _ in range(num_cross_sections):
            depth = read_float(f); bytes_read += 4
            radius = read_float(f); bytes_read += 4
            header_data['cross_sections'].append((depth, radius))

    # Lights (Added later)
    header_data['lights'] = []
    if bytes_read < length:
        num_lights = read_int(f); bytes_read += 4
        for _ in range(num_lights):
            pos = read_vector(f); bytes_read += 12
            light_type = read_int(f); bytes_read += 4
            header_data['lights'].append({'position': pos.to_list(), 'type': light_type})

    # Skip any remaining unknown data in the chunk
    remaining = length - bytes_read
    if remaining > 0:
        logger.warning(f"Skipping {remaining} unknown bytes in OHDR chunk.")
        f.seek(remaining, 1)
    elif remaining < 0:
         logger.error(f"Read past end of OHDR chunk by {-remaining} bytes!")

    return header_data
