"""
BSP binary data handling for POF file format.
Provides BSP-specific binary reading/writing operations.
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import List, Tuple, Optional
from .binary_data import BinaryReader, BinaryWriter
from .vector3d import Vector3D

# BSP Block IDs
BSP_DEFPOINTS = 1    # Vertex definitions
BSP_FLATPOLY = 2     # Flat-shaded polygon
BSP_TMAPPOLY = 3     # Texture-mapped polygon  
BSP_SORTNORM = 4     # Sorting plane
BSP_BOUNDBOX = 5     # Bounding box

# BSP Error Codes
BSP_NOERRORS = 0
BSP_PACK_PREOVERFLOW = 0x00000001
BSP_PACK_DOUBLEUSE = 0x00000002
BSP_PACK_UNCOUNTED = 0x00000004
BSP_PACK_POLYOVERFLOW = 0x00000008
BSP_PACK_SPLITOVERFLOW = 0x00000010
BSP_PACK_PREPOLYOVERFLOW = 0x00000020
BSP_PACK_PRESPLITOVERFLOW = 0x00000040

@dataclass
class BSPBlockHeader:
    """POF BSP block header."""
    id: int = 0
    size: int = 0
    
    def read(self, reader: BinaryReader) -> None:
        """Read BSP block header."""
        self.id = reader.read_int32()
        self.size = reader.read_int32()
        
    def write(self, writer: BinaryWriter) -> None:
        """Write BSP block header."""
        writer.write_int32(self.id)
        writer.write_int32(self.size)
        
    def get_size(self) -> int:
        """Get header size in bytes."""
        return 8  # 4 bytes each for id and size

class BSPReader(BinaryReader):
    """
    BSP-specific binary reader.
    Extends BinaryReader with BSP format specific operations.
    """
    
    def read_block_header(self) -> BSPBlockHeader:
        """Read BSP block header."""
        header = BSPBlockHeader()
        header.read(self)
        return header
    
    def read_vertex_counts(self) -> Tuple[int, int, int]:
        """Read BSP vertex counts."""
        n_verts = self.read_int32()
        n_norms = self.read_int32()
        offset = self.read_int32()
        return n_verts, n_norms, offset
    
    def read_norm_counts(self, count: int) -> List[int]:
        """Read normal counts array."""
        return [self.read_uint8() for _ in range(count)]
    
    def read_flat_poly_header(self) -> Tuple[Vector3D, Vector3D, float, int]:
        """Read flat polygon header data."""
        normal = self.read_vector3d()
        center = self.read_vector3d()
        radius = self.read_float32()
        nverts = self.read_int32()
        return normal, center, radius, nverts
    
    def read_tmap_poly_header(self) -> Tuple[Vector3D, Vector3D, float, int, int]:
        """Read textured polygon header data."""
        normal = self.read_vector3d()
        center = self.read_vector3d()
        radius = self.read_float32()
        nverts = self.read_int32()
        tmap_num = self.read_int32()
        return normal, center, radius, nverts, tmap_num
    
    def read_sort_norm_data(self) -> Tuple[Vector3D, Vector3D, int]:
        """Read BSP sort normal data."""
        plane_normal = self.read_vector3d()
        plane_point = self.read_vector3d()
        reserved = self.read_int32()
        return plane_normal, plane_point, reserved
    
    def read_bounding_box(self) -> Tuple[Vector3D, Vector3D]:
        """Read BSP bounding box."""
        min_point = self.read_vector3d()
        max_point = self.read_vector3d()
        return min_point, max_point

class BSPWriter(BinaryWriter):
    """
    BSP-specific binary writer.
    Extends BinaryWriter with BSP format specific operations.
    """
    
    def write_block_header(self, header: BSPBlockHeader) -> None:
        """Write BSP block header."""
        header.write(self)
    
    def write_vertex_counts(self, n_verts: int, n_norms: int, offset: int) -> None:
        """Write BSP vertex counts."""
        self.write_int32(n_verts)
        self.write_int32(n_norms)
        self.write_int32(offset)
    
    def write_norm_counts(self, counts: List[int]) -> None:
        """Write normal counts array."""
        for count in counts:
            self.write_uint8(count)
    
    def write_flat_poly_header(self, normal: Vector3D, center: Vector3D,
                             radius: float, nverts: int) -> None:
        """Write flat polygon header data."""
        self.write_vector3d(normal)
        self.write_vector3d(center)
        self.write_float32(radius)
        self.write_int32(nverts)
    
    def write_tmap_poly_header(self, normal: Vector3D, center: Vector3D,
                              radius: float, nverts: int, tmap_num: int) -> None:
        """Write textured polygon header data."""
        self.write_vector3d(normal)
        self.write_vector3d(center)
        self.write_float32(radius)
        self.write_int32(nverts)
        self.write_int32(tmap_num)
    
    def write_sort_norm_data(self, plane_normal: Vector3D, plane_point: Vector3D,
                            reserved: int = 0) -> None:
        """Write BSP sort normal data."""
        self.write_vector3d(plane_normal)
        self.write_vector3d(plane_point)
        self.write_int32(reserved)
        
    def write_bounding_box(self, min_point: Vector3D, max_point: Vector3D) -> None:
        """Write BSP bounding box."""
        self.write_vector3d(min_point)
        self.write_vector3d(max_point)

# Helper functions for BSP data handling

def calculate_bsp_block_size(header: BSPBlockHeader, data_size: int) -> int:
    """Calculate total BSP block size including header."""
    return header.get_size() + data_size

def validate_bsp_block(header: BSPBlockHeader, data_size: int) -> bool:
    """Validate BSP block size matches data."""
    return header.size == calculate_bsp_block_size(header, data_size)
