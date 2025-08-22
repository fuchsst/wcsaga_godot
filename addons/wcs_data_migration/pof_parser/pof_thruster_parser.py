#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import (MAX_PROP_LEN, read_float, read_int, read_string_len,
                         read_vector)

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_fuel_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Thrusters (FUEL) chunk."""
    logger.debug("Reading FUEL chunk...")
    num_thrusters = read_int(f)
    thrusters = []
    for _ in range(num_thrusters):
        thruster_data = {'points': []}
        num_points = read_int(f)
        thruster_data['num_points'] = num_points
        thruster_data['properties'] = read_string_len(f, MAX_PROP_LEN) # Properties string
        for _ in range(num_points):
            pos = read_vector(f)
            norm = read_vector(f)
            radius = read_float(f)
            thruster_data['points'].append({'position': pos.to_list(), 'normal': norm.to_list(), 'radius': radius})
        thrusters.append(thruster_data)
    return thrusters
