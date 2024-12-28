"""
POF file format data structures.
Provides classes for POF-specific data structures like BSP nodes and geometry.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Optional
from .vector3d import Vector3D
from .binary_data import BinaryReader, BinaryWriter

@dataclass
class BSPBlockHeader:
    """POF BSP block header structure."""
    id: int = 0  # Block identifier
    size: int = 0  # Block size in bytes
    
    def read(self, buffer: bytes) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.id = reader.read_int32()
        self.size = reader.read_int32()
        return 8  # Size of header
        
    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        writer.write_int32(self.id)
        writer.write_int32(self.size)
        return 8

@dataclass 
class BSPVertexData:
    """POF BSP vertex data structure."""
    vertex: Vector3D = field(default_factory=Vector3D)
    norms: List[Vector3D] = field(default_factory=list)

@dataclass
class BSPDefPoints:
    """POF BSP vertex definitions chunk."""
    head: BSPBlockHeader = field(default_factory=BSPBlockHeader)
    n_verts: int = 0
    n_norms: int = 0
    offset: int = 0
    norm_counts: List[int] = field(default_factory=list)
    vertex_data: List[BSPVertexData] = field(default_factory=list)
    normals: List[Vector3D] = field(default_factory=list)

    def read(self, buffer: bytes, header: BSPBlockHeader) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.head = header
        self.n_verts = reader.read_int32()
        self.n_norms = reader.read_int32()
        self.offset = reader.read_int32()
        
        # Read norm counts
        self.norm_counts = [reader.read_uint8() for _ in range(self.n_verts)]
        
        # Read vertex data
        self.vertex_data = []
        for i in range(self.n_verts):
            vdata = BSPVertexData()
            vdata.vertex = reader.read_vector3d()
            
            if self.norm_counts[i] > 0:
                vdata.norms = [reader.read_vector3d() for _ in range(self.norm_counts[i])]
                
                # Store normals in flat list too
                norm_offset = len(self.normals)
                self.normals.extend(vdata.norms)
                
            self.vertex_data.append(vdata)
            
        return self.get_size()

    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        
        # Update size
        self.head.size = self.get_size()
        bytes_written = self.head.write(buffer)
        
        writer.write_int32(self.n_verts)
        writer.write_int32(self.n_norms)
        writer.write_int32(self.offset)
        
        # Write norm counts
        for count in self.norm_counts:
            writer.write_uint8(count)
            
        # Write vertex data
        for i, vdata in enumerate(self.vertex_data):
            writer.write_vector3d(vdata.vertex)
            
            if self.norm_counts[i] > 0:
                for norm in vdata.norms:
                    writer.write_vector3d(norm)
                    
        return bytes_written

    def get_size(self) -> int:
        """Calculate total size in bytes."""
        size = 20  # Header + n_verts + n_norms + offset
        size += len(self.norm_counts)  # norm_counts array
        
        # Vertex data
        for i, vdata in enumerate(self.vertex_data):
            size += 12  # Vector3D vertex
            size += 12 * len(vdata.norms)  # Vector3D normals
            
        return size

@dataclass
class BSPFlatVertex:
    """POF BSP flat vertex structure."""
    vertnum: int = 0  # Vertex number
    normnum: int = 0  # Normal number
    
    def read(self, buffer: bytes) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.vertnum = reader.read_uint16()
        self.normnum = reader.read_uint16() 
        return 4
        
    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        writer.write_uint16(self.vertnum)
        writer.write_uint16(self.normnum)
        return 4

@dataclass
class BSPFlatPoly:
    """POF BSP flat polygon structure."""
    head: BSPBlockHeader = field(default_factory=BSPBlockHeader)
    normal: Vector3D = field(default_factory=Vector3D)
    center: Vector3D = field(default_factory=Vector3D)
    radius: float = 0.0
    nverts: int = 0
    red: int = 0
    green: int = 0  
    blue: int = 0
    pad: int = 0
    verts: List[BSPFlatVertex] = field(default_factory=list)

    def read(self, buffer: bytes, header: BSPBlockHeader) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.head = header
        
        self.normal = reader.read_vector3d()
        self.center = reader.read_vector3d()
        self.radius = reader.read_float32()
        self.nverts = reader.read_int32()
        
        self.red = reader.read_uint8()
        self.green = reader.read_uint8()
        self.blue = reader.read_uint8()
        self.pad = reader.read_uint8()
        
        self.verts = []
        for _ in range(self.nverts):
            vert = BSPFlatVertex()
            vert.read(buffer[reader.get_position():])
            reader.set_position(reader.get_position() + 4)
            self.verts.append(vert)
            
        return self.get_size()

    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        
        self.head.size = self.get_size()
        bytes_written = self.head.write(buffer)
        
        writer.write_vector3d(self.normal)
        writer.write_vector3d(self.center)
        writer.write_float32(self.radius)
        writer.write_int32(self.nverts)
        
        writer.write_uint8(self.red)
        writer.write_uint8(self.green)
        writer.write_uint8(self.blue)
        writer.write_uint8(self.pad)
        
        for vert in self.verts:
            bytes_written += vert.write(buffer[writer.get_position():])
            writer.set_position(writer.get_position() + 4)
            
        return bytes_written

    def get_size(self) -> int:
        """Calculate total size in bytes."""
        return 44 + (4 * len(self.verts))

@dataclass
class BSPTmapVertex:
    """POF BSP textured vertex structure."""
    vertnum: int = 0
    normnum: int = 0
    u: float = 0.0
    v: float = 0.0
    
    def read(self, buffer: bytes) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.vertnum = reader.read_uint16()
        self.normnum = reader.read_uint16()
        self.u = reader.read_float32()
        self.v = reader.read_float32()
        return 12
        
    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        writer.write_uint16(self.vertnum)
        writer.write_uint16(self.normnum)
        writer.write_float32(self.u)
        writer.write_float32(self.v)
        return 12

@dataclass
class BSPTmapPoly:
    """POF BSP textured polygon structure."""
    head: BSPBlockHeader = field(default_factory=BSPBlockHeader)
    normal: Vector3D = field(default_factory=Vector3D)
    center: Vector3D = field(default_factory=Vector3D)
    radius: float = 0.0
    nverts: int = 0
    tmap_num: int = 0
    verts: List[BSPTmapVertex] = field(default_factory=list)

    def read(self, buffer: bytes, header: BSPBlockHeader) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.head = header
        
        self.normal = reader.read_vector3d()
        self.center = reader.read_vector3d()
        self.radius = reader.read_float32()
        self.nverts = reader.read_int32()
        self.tmap_num = reader.read_int32()
        
        self.verts = []
        for _ in range(self.nverts):
            vert = BSPTmapVertex()
            vert.read(buffer[reader.get_position():])
            reader.set_position(reader.get_position() + 12)
            self.verts.append(vert)
            
        return self.get_size()

    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        
        self.head.size = self.get_size()
        bytes_written = self.head.write(buffer)
        
        writer.write_vector3d(self.normal)
        writer.write_vector3d(self.center)
        writer.write_float32(self.radius)
        writer.write_int32(self.nverts)
        writer.write_int32(self.tmap_num)
        
        for vert in self.verts:
            bytes_written += vert.write(buffer[writer.get_position():])
            writer.set_position(writer.get_position() + 12)
            
        return bytes_written

    def get_size(self) -> int:
        """Calculate total size in bytes."""
        return 44 + (12 * len(self.verts))

@dataclass
class BSPSortNorm:
    """POF BSP sort normal structure."""
    head: BSPBlockHeader = field(default_factory=BSPBlockHeader)
    plane_normal: Vector3D = field(default_factory=Vector3D)
    plane_point: Vector3D = field(default_factory=Vector3D)
    reserved: int = 0
    front_offset: int = 0
    back_offset: int = 0
    prelist_offset: int = 0
    postlist_offset: int = 0
    online_offset: int = 0
    min_bounding_box_point: Vector3D = field(default_factory=Vector3D)
    max_bounding_box_point: Vector3D = field(default_factory=Vector3D)

    def read(self, buffer: bytes, header: BSPBlockHeader) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.head = header
        
        self.plane_normal = reader.read_vector3d()
        self.plane_point = reader.read_vector3d()
        self.reserved = reader.read_int32()
        self.front_offset = reader.read_int32()
        self.back_offset = reader.read_int32()
        self.prelist_offset = reader.read_int32()
        self.postlist_offset = reader.read_int32()
        self.online_offset = reader.read_int32()
        self.min_bounding_box_point = reader.read_vector3d()
        self.max_bounding_box_point = reader.read_vector3d()
        
        return self.get_size()

    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        
        self.head.size = self.get_size()
        bytes_written = self.head.write(buffer)
        
        writer.write_vector3d(self.plane_normal)
        writer.write_vector3d(self.plane_point)
        writer.write_int32(self.reserved)
        writer.write_int32(self.front_offset)
        writer.write_int32(self.back_offset)
        writer.write_int32(self.prelist_offset)
        writer.write_int32(self.postlist_offset)
        writer.write_int32(self.online_offset)
        writer.write_vector3d(self.min_bounding_box_point)
        writer.write_vector3d(self.max_bounding_box_point)
        
        return bytes_written

    def get_size(self) -> int:
        """Calculate total size in bytes."""
        return 72

@dataclass
class BSPBoundBox:
    """POF BSP bounding box structure."""
    head: BSPBlockHeader = field(default_factory=BSPBlockHeader)
    min_point: Vector3D = field(default_factory=Vector3D)
    max_point: Vector3D = field(default_factory=Vector3D)

    def read(self, buffer: bytes, header: BSPBlockHeader) -> int:
        """Read from bytes buffer. Returns bytes read."""
        reader = BinaryReader(buffer)
        self.head = header
        
        self.min_point = reader.read_vector3d()
        self.max_point = reader.read_vector3d()
        
        return self.get_size()

    def write(self, buffer: bytearray) -> int:
        """Write to bytes buffer. Returns bytes written."""
        writer = BinaryWriter(buffer)
        
        self.head.size = self.get_size()
        bytes_written = self.head.write(buffer)
        
        writer.write_vector3d(self.min_point)
        writer.write_vector3d(self.max_point)
        
        return bytes_written

    def get_size(self) -> int:
        """Calculate total size in bytes."""
        return 32
