#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict

# Import necessary helper functions and constants from pof_chunks
# We need read_int, read_float, read_vector, read_string_len
# and constants MAX_NAME_LEN, MAX_PROP_LEN
from .pof_chunks import (MAX_NAME_LEN, MAX_PROP_LEN, read_float, read_int,
                         read_string_len, read_vector)

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_sobj_chunk(f: BinaryIO, length: int) -> Dict[str, Any]:
    """Parses a Subobject (SOBJ/OBJ2) chunk."""
    start_pos = f.tell()
    subobj_data = {}
    subobj_data['number'] = read_int(f); bytes_read = 4
    subobj_data['radius'] = read_float(f); bytes_read += 4
    subobj_data['parent'] = read_int(f); bytes_read += 4
    subobj_data['offset'] = read_vector(f).to_list(); bytes_read += 12
    subobj_data['geometric_center'] = read_vector(f).to_list(); bytes_read += 12
    min_bb = read_vector(f); bytes_read += 12
    max_bb = read_vector(f); bytes_read += 12
    subobj_data['bounding_min'] = min_bb.to_list()
    subobj_data['bounding_max'] = max_bb.to_list()

    name_start_pos = f.tell()
    subobj_data['name'] = read_string_len(f, MAX_NAME_LEN)
    bytes_read += (f.tell() - name_start_pos) # Add length prefix + string bytes

    props_start_pos = f.tell()
    subobj_data['properties'] = read_string_len(f, MAX_PROP_LEN)
    bytes_read += (f.tell() - props_start_pos) # Add length prefix + string bytes

    subobj_data['movement_type'] = read_int(f); bytes_read += 4
    subobj_data['movement_axis'] = read_int(f); bytes_read += 4

    # Reserved/Padding - Calculate how much to skip before BSP size
    # Total known fixed size before strings = 4+4+4+12+12+12+12+4+4 = 68
    # Total known fixed size after strings = 4 (BSP size)
    # Variable size = 4+len(name) + 4+len(props)
    # Need to know the *exact* structure or total chunk length to reliably skip reserved data.
    # Assuming the next int is BSP data size based on modelread.cpp structure.

    bsp_data_size = read_int(f); bytes_read += 4
    subobj_data['bsp_data_size'] = bsp_data_size
    if bsp_data_size > 0:
        subobj_data['bsp_data_offset'] = f.tell()
        f.seek(bsp_data_size, 1); bytes_read += bsp_data_size
    else:
        subobj_data['bsp_data_offset'] = -1

    # Check if we read exactly the chunk length
    if bytes_read != length:
         logger.warning(f"SOBJ chunk length mismatch for subobject {subobj_data.get('number', -1)} ('{subobj_data.get('name', 'N/A')}'). Expected {length}, read {bytes_read}. There might be extra reserved data.")
         # Attempt to seek to the expected end of the chunk if we read less
         if bytes_read < length:
              f.seek(start_pos + 8 + length) # Seek from start of chunk + header size

    return subobj_data
