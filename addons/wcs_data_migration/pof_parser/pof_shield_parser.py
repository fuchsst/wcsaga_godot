#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import read_int, read_vector

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_shld_chunk(f: BinaryIO, length: int) -> Dict[str, Any]:
    """Parses the Shield Mesh (SHLD) chunk."""
    logger.debug("Reading SHLD chunk...")
    shield_data = {'vertices': [], 'faces': []}
    num_verts = read_int(f)
    # Read vertices first, store them in a temporary list
    temp_verts = [read_vector(f) for _ in range(num_verts)]
    shield_data['vertices'] = [v.to_list() for v in temp_verts] # Store as lists

    num_tris = read_int(f)
    for _ in range(num_tris):
        norm = read_vector(f).to_list()
        vert_indices = [read_int(f) for _ in range(3)]
        neighbor_indices = [read_int(f) for _ in range(3)]
        # Validate indices
        valid_indices = True
        for idx in vert_indices:
            if idx < 0 or idx >= num_verts:
                logger.error(f"Invalid vertex index {idx} in SHLD chunk (max: {num_verts-1}). Skipping face.")
                valid_indices = False
                break
        if not valid_indices:
            continue # Skip this face

        valid_neighbors = True
        for idx in neighbor_indices:
             # Neighbor index can be -1 if there's no neighbor
            if idx < -1 or idx >= num_tris:
                logger.error(f"Invalid neighbor index {idx} in SHLD chunk (max: {num_tris-1}). Skipping face.")
                valid_neighbors = False
                break
        if not valid_neighbors:
            continue # Skip this face

        shield_data['faces'].append({
            'normal': norm,
            'vertex_indices': vert_indices,
            'neighbor_indices': neighbor_indices
        })
    return shield_data

def read_sldc_chunk(f: BinaryIO, length: int) -> bytes:
    """Reads the Shield Collision Tree (SLDC) chunk as raw bytes."""
    logger.debug("Reading SLDC chunk (raw bytes)...")
    return f.read(length)
