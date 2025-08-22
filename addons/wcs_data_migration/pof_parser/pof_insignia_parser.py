#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions from pof_chunks
from .pof_chunks import read_float, read_int, read_vector

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_insg_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Insignia (INSG) chunk."""
    logger.debug("Reading INSG chunk...")
    num_insignia = read_int(f)
    insignias = []
    for _ in range(num_insignia):
        ins_data = {'faces': []}
        ins_data['lod'] = read_int(f)
        num_faces = read_int(f)
        num_verts = read_int(f) # Total verts for this insignia's geometry
        verts = [read_vector(f) for _ in range(num_verts)] # Read Vector3D objects
        ins_data['offset'] = read_vector(f).to_list()
        for _ in range(num_faces):
            face_verts_with_uvs = []
            indices = [read_int(f) for _ in range(3)]
            uvs = [(read_float(f), read_float(f)) for _ in range(3)]
            valid_indices = True
            for k in range(3):
                 idx = indices[k]
                 if idx < 0 or idx >= num_verts:
                      logger.error(f"Invalid vertex index {idx} in INSG face (max: {num_verts-1}). Skipping face.")
                      valid_indices = False
                      break
                 face_verts_with_uvs.append({'position': verts[idx].to_list(), 'u': uvs[k][0], 'v': uvs[k][1]})
            if valid_indices:
                ins_data['faces'].append({'vertices': face_verts_with_uvs})
        insignias.append(ins_data)
    return insignias
