"""
POF chunk handlers.
Provides functions for reading and writing POF file chunks.
"""

from __future__ import annotations
from typing import List, Tuple, Dict, Optional
from dataclasses import dataclass, field
from .pof_binary import POFReader, POFWriter
from .vector3d import Vector3D
from .binary_data import ChunkHeader

# Chunk IDs
CHUNK_HDR2 = 'HDR2'  # Header chunk
CHUNK_TXTR = 'TXTR'  # Texture chunk
CHUNK_OBJ2 = 'OBJ2'  # Object/geometry chunk
CHUNK_PINF = 'PINF'  # Model info chunk
CHUNK_EYE  = 'EYE '  # Eye points chunk
CHUNK_SPCL = 'SPCL'  # Special points chunk
CHUNK_GPNT = 'GPNT'  # Gun points chunk
CHUNK_MPNT = 'MPNT'  # Missile points chunk
CHUNK_TGUN = 'TGUN'  # Turret guns chunk
CHUNK_TMIS = 'TMIS'  # Turret missiles chunk
CHUNK_DOCK = 'DOCK'  # Docking points chunk
CHUNK_FUEL = 'FUEL'  # Thruster chunk
CHUNK_SHLD = 'SHLD'  # Shield mesh chunk
CHUNK_INSG = 'INSG'  # Insignia chunk
CHUNK_PATH = 'PATH'  # Path chunk
CHUNK_GLOW = 'GLOW'  # Glow points chunk
CHUNK_SLDC = 'SLDC'  # Shield collision chunk

def read_textures(reader: POFReader) -> List[str]:
    """Read texture chunk."""
    num_textures = reader.read_int32()
    textures = []
    for _ in range(num_textures):
        textures.append(reader.read_pof_string())
    return textures

def write_textures(writer: POFWriter, textures: List[str]) -> None:
    """Write texture chunk."""
    writer.write_bytes(CHUNK_TXTR.encode('ascii'))
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(textures))
    for texture in textures:
        writer.write_pof_string(texture)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_model_info(reader: POFReader) -> List[str]:
    """Read model info strings."""
    model_info = []
    
    # Read raw data
    data = reader.read_bytes(reader.chunk_size)
    if not data:
        return []

    # Split into null-terminated strings
    current_str = bytearray()
    for byte in data:
        if byte == 0:
            if current_str:
                try:
                    model_info.append(current_str.decode('ascii'))
                except UnicodeDecodeError:
                    pass  # Skip invalid strings
                current_str = bytearray()
        else:
            current_str.append(byte)
            
    return model_info

def write_model_info(writer: POFWriter, model_info: List[str]) -> None:
    """Write model info strings."""
    writer.write_bytes(CHUNK_PINF.encode('ascii'))
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    # Write null-terminated strings
    for info in model_info:
        writer.write_bytes(info.encode('ascii') + b'\0')
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_eyes(reader: POFReader) -> List[Tuple[int, Vector3D, Vector3D]]:
    """Read eye points."""
    num_eyes = reader.read_int32()
    eyes = []
    for _ in range(num_eyes):
        sobj_num = reader.read_int32()
        offset = reader.read_vector3d()
        normal = reader.read_vector3d()
        eyes.append((sobj_num, offset, normal))
    return eyes

def write_eyes(writer: POFWriter, eyes: List[Tuple[int, Vector3D, Vector3D]]) -> None:
    """Write eye points."""
    writer.write_bytes(CHUNK_EYE.encode('ascii'))
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(eyes))
    for sobj_num, offset, normal in eyes:
        writer.write_int32(sobj_num)
        writer.write_vector3d(offset)
        writer.write_vector3d(normal)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_specials(reader: POFReader) -> List[Tuple[str, str, Vector3D, float]]:
    """Read special points."""
    num_specials = reader.read_int32()
    specials = []
    for _ in range(num_specials):
        name = reader.read_pof_string()
        properties = reader.read_pof_string()
        point = reader.read_vector3d()
        radius = reader.read_float32()
        specials.append((name, properties, point, radius))
    return specials

def write_specials(writer: POFWriter, 
                  specials: List[Tuple[str, str, Vector3D, float]]) -> None:
    """Write special points."""
    writer.write_bytes(CHUNK_SPCL.encode('ascii'))
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(specials))
    for name, properties, point, radius in specials:
        writer.write_pof_string(name)
        writer.write_pof_string(properties)
        writer.write_vector3d(point)
        writer.write_float32(radius)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_weapons(reader: POFReader, weapon_type: int) -> List[Tuple[Vector3D, Vector3D]]:
    """Read weapon points (guns or missiles)."""
    num_slots = reader.read_int32()
    weapons = []
    for _ in range(num_slots):
        num_points = reader.read_int32()
        points = []
        for _ in range(num_points):
            point = reader.read_vector3d()
            normal = reader.read_vector3d()
            points.append((point, normal))
        weapons.extend(points)
    return weapons

def write_weapons(writer: POFWriter, weapons: List[Tuple[Vector3D, Vector3D]], 
                 weapon_type: int) -> None:
    """Write weapon points (guns or missiles)."""
    chunk_id = CHUNK_GPNT if weapon_type == 0 else CHUNK_MPNT
    writer.write_bytes(chunk_id.encode('ascii'))
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    # Group weapons into slots of 8
    slot_size = 8
    num_slots = (len(weapons) + slot_size - 1) // slot_size
    writer.write_int32(num_slots)
    
    for slot in range(num_slots):
        start = slot * slot_size
        end = min(start + slot_size, len(weapons))
        slot_weapons = weapons[start:end]
        
        writer.write_int32(len(slot_weapons))
        for point, normal in slot_weapons:
            writer.write_vector3d(point)
            writer.write_vector3d(normal)
            
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

# TODO: Add remaining chunk handlers for:
# - TGUN/TMIS (turrets)
# - DOCK (docking points)
# - FUEL (thrusters)
# - SHLD (shield mesh)
# - INSG (insignias)
# - PATH (paths)
# - GLOW (glow points)
# - SLDC (shield collision)
