"""
POF-specific binary data handling.
Builds on binary_data.py to provide POF format specific operations.
"""

from __future__ import annotations
from typing import BinaryIO, Optional, List, Tuple, Any
from dataclasses import dataclass
import struct
from .binary_data import BinaryReader, BinaryWriter, ChunkHeader
from .vector3d import Vector3D

class POFReader(BinaryReader):
    """
    POF-specific binary reader.
    Extends BinaryReader with POF format specific operations.
    """
    
    def __init__(self, stream: BinaryIO, endian: str = '<'):
        """
        Initialize POF reader.
        
        Args:
            stream: Binary stream to read from
            endian: Endianness ('<' for little-endian, '>' for big-endian)
        """
        super().__init__(stream, endian)
        self.chunk_size: int = 0  # Current chunk size
        
    def read_pof_string(self) -> str:
        """
        Read POF format string (length-prefixed).
        Returns empty string if length is 0.
        """
        length = self.read_int32()
        if length <= 0:
            return ""
        return self.read_string(length)
    
    def read_chunk_header(self) -> ChunkHeader:
        """Read POF chunk header."""
        chunk_id_bytes = self.read_bytes(4)
        # Validate chunk ID contains only printable ASCII
        if not all(32 <= b <= 126 for b in chunk_id_bytes):
            raise EOFError("Invalid chunk ID")
            
        # Check against known chunk IDs
        chunk_id = chunk_id_bytes.decode('ascii')
        valid_chunks = {'HDR2', 'TXTR', 'OBJ2', 'PINF', 'EYE ', 'SPCL', 
                       'GPNT', 'MPNT', 'TGUN', 'TMIS', 'DOCK', 'FUEL',
                       'SHLD', 'INSG', 'PATH', 'GLOW', 'SLDC', 'ACEN'}
        if chunk_id not in valid_chunks:
            raise EOFError(f"Unknown chunk ID: {chunk_id}")
            
        self.chunk_size = self.read_uint32()
        return ChunkHeader(chunk_id, self.chunk_size)
    
    def read_vector3d(self) -> Vector3D:
        """Read POF Vector3D."""
        x = self.read_float32()
        y = self.read_float32()
        z = self.read_float32()
        return Vector3D(x, y, z)
    
    def read_vertex_data(self) -> Tuple[Vector3D, List[Vector3D]]:
        """
        Read POF vertex data (position and normals).
        Returns tuple of (vertex position, list of normals).
        """
        position = self.read_vector3d()
        num_norms = self.read_uint8()
        normals = [self.read_vector3d() for _ in range(num_norms)]
        return position, normals

    def read_color_bytes(self) -> Tuple[int, int, int]:
        """Read RGB color bytes."""
        r = self.read_uint8()
        g = self.read_uint8()
        b = self.read_uint8()
        return r, g, b

    def read_uv_coords(self) -> Tuple[float, float]:
        """Read UV texture coordinates."""
        u = self.read_float32()
        v = self.read_float32()
        return u, v

    def read_vertex_indices(self) -> Tuple[int, int]:
        """Read vertex and normal indices."""
        vert_idx = self.read_uint16()
        norm_idx = self.read_uint16()
        return vert_idx, norm_idx

    def read_bsp_node_offsets(self) -> Tuple[int, int, int, int, int]:
        """Read BSP node offsets."""
        front = self.read_int32()
        back = self.read_int32()
        prelist = self.read_int32()
        postlist = self.read_int32()
        online = self.read_int32()
        return front, back, prelist, postlist, online

    def read_bounding_box(self) -> Tuple[Vector3D, Vector3D]:
        """Read bounding box min/max points."""
        min_point = self.read_vector3d()
        max_point = self.read_vector3d()
        return min_point, max_point

class POFWriter(BinaryWriter):
    """
    POF-specific binary writer.
    Extends BinaryWriter with POF format specific operations.
    """
    
    def __init__(self, stream: BinaryIO, endian: str = '<'):
        """
        Initialize POF writer.
        
        Args:
            stream: Binary stream to write to
            endian: Endianness ('<' for little-endian, '>' for big-endian)
        """
        super().__init__(stream, endian)
        
    def write_pof_string(self, text: str) -> None:
        """Write POF format string (length-prefixed)."""
        data = text.encode('ascii')
        self.write_int32(len(data))
        self.write_bytes(data)
        
    def write_chunk_header(self, header: ChunkHeader) -> None:
        """Write POF chunk header."""
        self.write_bytes(header.id.encode('ascii'))
        self.write_uint32(header.size)
        
    def write_vector3d(self, vec: Vector3D) -> None:
        """Write POF Vector3D."""
        self.write_float32(vec.x)
        self.write_float32(vec.y)
        self.write_float32(vec.z)
        
    def write_vertex_data(self, position: Vector3D, normals: List[Vector3D]) -> None:
        """Write POF vertex data (position and normals)."""
        self.write_vector3d(position)
        self.write_uint8(len(normals))
        for normal in normals:
            self.write_vector3d(normal)

    def write_color_bytes(self, r: int, g: int, b: int) -> None:
        """Write RGB color bytes."""
        self.write_uint8(r)
        self.write_uint8(g)
        self.write_uint8(b)

    def write_uv_coords(self, u: float, v: float) -> None:
        """Write UV texture coordinates."""
        self.write_float32(u)
        self.write_float32(v)

    def write_vertex_indices(self, vert_idx: int, norm_idx: int) -> None:
        """Write vertex and normal indices."""
        self.write_uint16(vert_idx)
        self.write_uint16(norm_idx)

    def write_bsp_node_offsets(self, front: int, back: int, prelist: int, 
                             postlist: int, online: int) -> None:
        """Write BSP node offsets."""
        self.write_int32(front)
        self.write_int32(back)
        self.write_int32(prelist)
        self.write_int32(postlist)
        self.write_int32(online)

    def write_bounding_box(self, min_point: Vector3D, max_point: Vector3D) -> None:
        """Write bounding box min/max points."""
        self.write_vector3d(min_point)
        self.write_vector3d(max_point)

# POF Binary Format Constants
POF_SIGNATURE = b'PSPO'  # POF file signature
POF_VERSION = 2117       # POF version number

# POF Chunk IDs
CHUNK_HDR2 = b'HDR2'  # Header chunk
CHUNK_OBJ2 = b'OBJ2'  # Object/geometry chunk  
CHUNK_TXTR = b'TXTR'  # Texture chunk
CHUNK_SPCL = b'SPCL'  # Special chunk
CHUNK_GPNT = b'GPNT'  # Gun points chunk
CHUNK_MPNT = b'MPNT'  # Missile points chunk
CHUNK_TGUN = b'TGUN'  # Turret guns chunk
CHUNK_TMIS = b'TMIS'  # Turret missiles chunk
CHUNK_DOCK = b'DOCK'  # Docking chunk
CHUNK_FUEL = b'FUEL'  # Thruster chunk
CHUNK_GLOW = b'GLOW'  # Glow points chunk
CHUNK_SLDC = b'SLDC'  # Shield collision chunk
CHUNK_PINF = b'PINF'  # POF info chunk
CHUNK_EYE  = b'EYE '  # Eye points chunk
CHUNK_ACEN = b'ACEN'  # Autocentering chunk
CHUNK_INSG = b'INSG'  # Insignia chunk
CHUNK_PATH = b'PATH'  # Path chunk
CHUNK_SHLD = b'SHLD'  # Shield chunk

def read_pof_header(reader: POFReader) -> Tuple[bytes, int]:
    """
    Read POF file header.
    Returns tuple of (signature, version).
    """
    sig = reader.read_bytes(4)
    if sig != POF_SIGNATURE:
        raise ValueError(f"Invalid POF signature: {sig}")
    version = reader.read_int32()
    if version < 2116:
        raise ValueError(f"Unsupported POF version: {version}")
    return sig, version

def write_pof_header(writer: POFWriter, version: int = POF_VERSION) -> None:
    """Write POF file header."""
    writer.write_bytes(POF_SIGNATURE)
    writer.write_int32(version)

def read_chunk_data(reader: POFReader, size: int) -> bytes:
    """Read raw chunk data of specified size."""
    return reader.read_bytes(size)

def write_chunk_data(writer: POFWriter, chunk_id: bytes, data: bytes) -> None:
    """Write chunk with ID and data."""
    writer.write_bytes(chunk_id)
    writer.write_uint32(len(data))
    writer.write_bytes(data)
