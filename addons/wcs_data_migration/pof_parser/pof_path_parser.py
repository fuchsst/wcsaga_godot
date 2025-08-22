#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import (MAX_NAME_LEN, read_float, read_int, read_string_len,
                         read_vector)

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_path_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Paths (PATH) chunk."""
    logger.debug("Reading PATH chunk...")
    num_paths = read_int(f)
    paths = []
    for _ in range(num_paths):
        path_data = {'verts': []}
        path_data['name'] = read_string_len(f, MAX_NAME_LEN)
        path_data['parent_name'] = read_string_len(f, MAX_NAME_LEN) # POF v2002+
        num_verts = read_int(f)
        path_data['nverts'] = num_verts
        for _ in range(num_verts):
            pos = read_vector(f)
            radius = read_float(f)
            num_turrets = read_int(f)
            turret_ids = [read_int(f) for _ in range(num_turrets)]
            path_data['verts'].append({'position': pos.to_list(), 'radius': radius, 'turret_ids': turret_ids})
        paths.append(path_data)
    return paths
