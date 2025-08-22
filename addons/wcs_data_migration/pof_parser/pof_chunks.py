#!/usr/bin/env python3
import logging
import struct
from typing import Any, BinaryIO, Dict, List, Tuple

from .vector3d import Vector3D

logger = logging.getLogger(__name__)

# POF Chunk IDs (from modelsinc.h)
# POF Header ID and Version constants
POF_HEADER_ID = 0x4f505350  # 'OPSP'
PM_COMPATIBLE_VERSION = 1900
PM_OBJFILE_MAJOR_VERSION = 30

ID_OHDR = 0x32524448  # HDR2
ID_SOBJ = 0x324a424f  # OBJ2
ID_TXTR = 0x52545854  # TXTR
ID_INFO = 0x464e4950  # PINF
ID_GRID = 0x44495247  # GRID (Unused?)
ID_SPCL = 0x4c435053  # SPCL
ID_PATH = 0x48544150  # PATH
ID_GPNT = 0x544e5047  # GPNT (Gun points)
ID_MPNT = 0x544e504d  # MPNT (Missile points)
ID_DOCK = 0x4b434f44  # DOCK
ID_TGUN = 0x4e554754  # TGUN (Turret Gun?) - Deprecated? Handled in SOBJ?
ID_TMIS = 0x53494d54  # TMIS (Turret Missile?) - Deprecated? Handled in SOBJ?
ID_FUEL = 0x4c455546  # FUEL (Thrusters)
ID_SHLD = 0x444c4853  # SHLD (Shield mesh)
ID_EYE  = 0x20455945  # EYE (Eye points)
ID_INSG = 0x47534e49  # INSG (Insignia)
ID_ACEN = 0x4e454341  # ACEN (Autocenter)
ID_GLOW = 0x574f4c47  # GLOW (Glow points)
# ID_GLOX = 0x584f4c47 # GLOX (Seems unused in FS2 source?)
ID_SLDC = 0x43444c53  # SLDC (Shield Collision Tree)

# BSP Chunk IDs (from modelinterp.cpp and modelsinc.h)
OP_EOF = 0
OP_DEFPOINTS = 1
OP_FLATPOLY = 2
OP_TMAPPOLY = 3
OP_SORTNORM = 4
OP_BOUNDBOX = 5

# Constants
MAX_NAME_LEN = 32
MAX_PROP_LEN = 256
MAX_DEBRIS_OBJECTS = 32
MAX_MODEL_DETAIL_LEVELS = 8
MAX_MODEL_TEXTURES = 35 # From model.h, adjust if needed
MAX_SLOTS = 25 # Max gun/missile slots per bank
MAX_DOCK_SLOTS = 2
MAX_TFP = 10 # Max turret firing points
MAX_EYES = 10
MAX_SPLIT_PLANE = 5
MAX_REPLACEMENT_TEXTURES = MAX_MODEL_TEXTURES * 5 # From model.h TM_NUM_TYPES

# Helper functions for reading binary data
def read_int(f: BinaryIO) -> int:
    """Reads a 4-byte signed integer."""
    try:
        return struct.unpack('<i', f.read(4))[0]
    except struct.error:
        logger.error("Failed to read int (EOF?)")
        raise EOFError("Could not read 4 bytes for int.")

def read_uint(f: BinaryIO) -> int:
    """Reads a 4-byte unsigned integer."""
    try:
        return struct.unpack('<I', f.read(4))[0]
    except struct.error:
        logger.error("Failed to read uint (EOF?)")
        raise EOFError("Could not read 4 bytes for uint.")

def read_short(f: BinaryIO) -> int:
    """Reads a 2-byte signed short."""
    try:
        return struct.unpack('<h', f.read(2))[0]
    except struct.error:
        logger.error("Failed to read short (EOF?)")
        raise EOFError("Could not read 2 bytes for short.")

def read_ushort(f: BinaryIO) -> int:
    """Reads a 2-byte unsigned short."""
    try:
        return struct.unpack('<H', f.read(2))[0]
    except struct.error:
        logger.error("Failed to read ushort (EOF?)")
        raise EOFError("Could not read 2 bytes for ushort.")

def read_float(f: BinaryIO) -> float:
    """Reads a 4-byte float."""
    try:
        return struct.unpack('<f', f.read(4))[0]
    except struct.error:
        logger.error("Failed to read float (EOF?)")
        raise EOFError("Could not read 4 bytes for float.")

def read_byte(f: BinaryIO) -> int:
    """Reads a 1-byte signed byte."""
    try:
        return struct.unpack('<b', f.read(1))[0]
    except struct.error:
        logger.error("Failed to read byte (EOF?)")
        raise EOFError("Could not read 1 byte for byte.")

def read_ubyte(f: BinaryIO) -> int:
    """Reads a 1-byte unsigned byte."""
    try:
        return struct.unpack('<B', f.read(1))[0]
    except struct.error:
        logger.error("Failed to read ubyte (EOF?)")
        raise EOFError("Could not read 1 byte for ubyte.")

def read_vector(f: BinaryIO) -> Vector3D:
    """Reads a 12-byte vector."""
    try:
        x, y, z = struct.unpack('<fff', f.read(12))
        return Vector3D(x, y, z)
    except struct.error:
        logger.error("Failed to read vector (EOF?)")
        raise EOFError("Could not read 12 bytes for vector.")

def read_matrix(f: BinaryIO) -> List[List[float]]:
    """Reads a 36-byte 3x3 matrix."""
    try:
        m = []
        for _ in range(3):
            m.append(list(struct.unpack('<fff', f.read(12))))
        return m
    except struct.error:
        logger.error("Failed to read matrix (EOF?)")
        raise EOFError("Could not read 36 bytes for matrix.")

def read_string(f: BinaryIO, max_len: int) -> str:
    """Reads a null-terminated string, ensuring max length."""
    chars = []
    count = 0
    try:
        while count < max_len:
            byte = f.read(1)
            if not byte or byte == b'\x00':
                break
            chars.append(byte)
            count += 1
        # Read and discard remaining bytes if max_len was hit before null terminator
        if count == max_len:
            while True:
                byte = f.read(1)
                if not byte or byte == b'\x00':
                    break
        return b"".join(chars).decode('utf-8', errors='replace')
    except EOFError:
        logger.warning(f"EOF reached while reading string (max_len={max_len}). Returning partial string.")
        return b"".join(chars).decode('utf-8', errors='replace')


def read_string_len(f: BinaryIO, max_len: int) -> str:
    """Reads a length-prefixed string."""
    try:
        length = read_int(f)
        if length <= 0:
            return ""
        if length >= max_len:
            logger.warning(f"String length {length} exceeds max {max_len}, truncating.")
            data = f.read(max_len - 1)
            f.seek(length - (max_len - 1), 1) # Skip remaining bytes
            return data.decode('utf-8', errors='replace') + '\0' # Ensure null termination conceptually
        else:
            data = f.read(length)
            # POF strings might not be null-terminated in the file after the length prefix
            return data.decode('utf-8', errors='replace')
    except EOFError:
        logger.error("EOF reached while reading length-prefixed string.")
        raise # Re-raise EOFError

# --- Chunk Header Reading ---

def read_chunk_header(f: BinaryIO) -> Tuple[int, int]:
    """Reads the 8-byte chunk header (ID and Length)."""
    chunk_id = read_uint(f)
    chunk_len = read_int(f)
    return chunk_id, chunk_len

# --- Unknown Chunk Handling ---
def read_unknown_chunk(f: BinaryIO, length: int, chunk_id: int) -> None:
    """Skips an unknown chunk."""
    try:
        # Attempt to decode the chunk ID as ASCII for logging
        chunk_id_str = struct.pack('<I', chunk_id).decode('ascii', errors='replace')
    except:
        chunk_id_str = "Invalid ID"
    logger.warning(f"Skipping unknown chunk '{chunk_id_str}' (ID: {chunk_id:08X}) of length {length}")
    try:
        f.seek(length, 1)
    except Exception as e:
         logger.error(f"Error seeking past unknown chunk {chunk_id_str}: {e}")
         raise EOFError(f"Could not seek past unknown chunk {chunk_id_str}")


# --- BSP Parsing ---
# Moved to pof_misc_parser.py
def parse_bsp_data(bsp_bytes: bytes, pof_version: int) -> Dict[str, Any]:
     """Placeholder - Actual implementation is in pof_misc_parser.py"""
     logger.warning("parse_bsp_data called from pof_chunks.py - should be called from pof_misc_parser.py")
     return {'vertices': [], 'normals': [], 'uvs': [], 'polygons': []}
