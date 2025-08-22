#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions from pof_chunks
from .pof_chunks import read_int, read_vector

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_eye_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Eye Points (EYE) chunk."""
    logger.debug("Reading EYE chunk...")
    num_eyes = read_int(f)
    eyes = []
    for _ in range(num_eyes):
        parent = read_int(f)
        pos = read_vector(f)
        norm = read_vector(f)
        eyes.append({'parent': parent, 'position': pos.to_list(), 'normal': norm.to_list()})
    return eyes
