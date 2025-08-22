#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import (MAX_DOCK_SLOTS, MAX_PROP_LEN, read_int,
                         read_string_len, read_vector)

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_dock_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Docking Points (DOCK) chunk."""
    logger.debug("Reading DOCK chunk...")
    num_docks = read_int(f)
    docking_points = []
    for _ in range(num_docks):
        dock_data = {'points': []}
        dock_data['properties'] = read_string_len(f, MAX_PROP_LEN)
        num_spline_paths = read_int(f)
        dock_data['spline_paths'] = [read_int(f) for _ in range(num_spline_paths)]
        num_slots = read_int(f)
        dock_data['num_slots'] = num_slots
        # Ensure we read exactly MAX_DOCK_SLOTS (2) points, even if num_slots differs
        for slot_idx in range(MAX_DOCK_SLOTS):
            pos = read_vector(f)
            norm = read_vector(f)
            if slot_idx < num_slots: # Only store valid slots read
                dock_data['points'].append({'position': pos.to_list(), 'normal': norm.to_list()})
            else:
                 logger.warning(f"Dock point expected {num_slots} slots but reading fixed {MAX_DOCK_SLOTS}. Discarding extra read for slot {slot_idx+1}.")
        # If num_slots was less than MAX_DOCK_SLOTS, fill remaining with defaults? Or log error?
        if num_slots < MAX_DOCK_SLOTS:
             logger.warning(f"Dock point only defined {num_slots} slots, expected {MAX_DOCK_SLOTS}.")
             # Optionally fill remaining slots with default values if required downstream
             # for _ in range(MAX_DOCK_SLOTS - num_slots):
             #     dock_data['points'].append({'position': [0,0,0], 'normal': [0,0,1]})

        docking_points.append(dock_data)
    return docking_points
