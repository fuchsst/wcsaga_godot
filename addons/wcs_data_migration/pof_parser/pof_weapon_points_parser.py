#!/usr/bin/env python3
import logging
from typing import Any, BinaryIO, Dict, List

# Import necessary helper functions and constants from pof_chunks
from .pof_chunks import read_int, read_vector

# Import Vector3D if needed for type hinting or direct use
# from .vector3d import Vector3D

logger = logging.getLogger(__name__)

def read_gpnt_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Gun Points (GPNT) chunk."""
    logger.debug("Reading GPNT chunk...")
    num_banks = read_int(f)
    gun_banks = []
    for _ in range(num_banks):
        bank = {'points': []}
        num_slots = read_int(f)
        bank['num_slots'] = num_slots
        for _ in range(num_slots):
            pos = read_vector(f)
            norm = read_vector(f)
            bank['points'].append({'position': pos.to_list(), 'normal': norm.to_list()})
        gun_banks.append(bank)
    return gun_banks

def read_mpnt_chunk(f: BinaryIO, length: int) -> List[Dict[str, Any]]:
    """Parses the Missile Points (MPNT) chunk."""
    logger.debug("Reading MPNT chunk...")
    num_banks = read_int(f)
    missile_banks = []
    for _ in range(num_banks):
        bank = {'points': []}
        num_slots = read_int(f)
        bank['num_slots'] = num_slots
        for _ in range(num_slots):
            pos = read_vector(f)
            norm = read_vector(f)
            bank['points'].append({'position': pos.to_list(), 'normal': norm.to_list()})
        missile_banks.append(bank)
    return missile_banks
