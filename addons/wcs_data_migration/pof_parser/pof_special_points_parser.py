#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import (MAX_NAME_LEN, MAX_PROP_LEN, read_float, read_int,
                         read_string_len, read_vector)

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_spcl_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Special Points (SPCL) chunk."""
    logger.debug("Reading SPCL chunk...")
    num_specials = read_int(f)
    specials = []
    for _ in range(num_specials):
        name = read_string_len(f, MAX_NAME_LEN)
        props = read_string_len(f, MAX_PROP_LEN)
        pos = read_vector(f)
        radius = read_float(f)
        specials.append({
            'name': name,
            'properties': props,
            'position': pos.to_list(),
            'radius': radius
        })
    return specials
