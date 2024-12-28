"""
POF visual effects chunk handlers.
Handles effects-related chunks (GLOW, FUEL, INSG).
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Tuple, Optional
from .pof_binary import POFReader, POFWriter
from .vector3d import Vector3D

@dataclass
class POFGlowPoint:
    """POF glow point data."""
    position: Vector3D = field(default_factory=Vector3D)
    normal: Vector3D = field(default_factory=Vector3D)
    radius: float = 0.0

@dataclass
class POFGlowBank:
    """POF glow bank data."""
    disp_time: int = 0
    on_time: int = 0
    off_time: int = 0
    obj_parent: int = 0
    lod: int = 0
    glow_type: int = 0
    properties: str = ""
    points: List[POFGlowPoint] = field(default_factory=list)

@dataclass
class POFThrusterPoint:
    """POF thruster point data."""
    position: Vector3D = field(default_factory=Vector3D)
    normal: Vector3D = field(default_factory=Vector3D)
    radius: float = 0.0

@dataclass
class POFThruster:
    """POF thruster data."""
    properties: str = ""
    points: List[POFThrusterPoint] = field(default_factory=list)

@dataclass
class POFInsigniaPoint:
    """POF insignia vertex with UV coordinates."""
    position: Vector3D = field(default_factory=Vector3D)
    u: float = 0.0
    v: float = 0.0

@dataclass
class POFInsigniaFace:
    """POF insignia face data."""
    vertices: List[POFInsigniaPoint] = field(default_factory=list)

@dataclass
class POFInsignia:
    """POF insignia data."""
    lod: int = 0
    offset: Vector3D = field(default_factory=Vector3D)
    faces: List[POFInsigniaFace] = field(default_factory=list)

def read_glow_bank(reader: POFReader) -> POFGlowBank:
    """Read glow bank (GLOW chunk)."""
    bank = POFGlowBank()
    
    bank.disp_time = reader.read_int32()
    bank.on_time = reader.read_int32()
    bank.off_time = reader.read_int32()
    bank.obj_parent = reader.read_int32()
    bank.lod = reader.read_int32()
    bank.glow_type = reader.read_int32()
    
    num_points = reader.read_int32()
    bank.properties = reader.read_pof_string()
    
    for _ in range(num_points):
        point = POFGlowPoint()
        point.position = reader.read_vector3d()
        point.normal = reader.read_vector3d()
        point.radius = reader.read_float32()
        bank.points.append(point)
        
    return bank

def write_glow_bank(writer: POFWriter, bank: POFGlowBank) -> None:
    """Write glow bank (GLOW chunk)."""
    writer.write_bytes(b'GLOW')
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(bank.disp_time)
    writer.write_int32(bank.on_time)
    writer.write_int32(bank.off_time)
    writer.write_int32(bank.obj_parent)
    writer.write_int32(bank.lod)
    writer.write_int32(bank.glow_type)
    
    writer.write_int32(len(bank.points))
    writer.write_pof_string(bank.properties)
    
    for point in bank.points:
        writer.write_vector3d(point.position)
        writer.write_vector3d(point.normal)
        writer.write_float32(point.radius)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_thruster(reader: POFReader) -> POFThruster:
    """Read thruster (FUEL chunk)."""
    thruster = POFThruster()
    
    num_points = reader.read_int32()
    thruster.properties = reader.read_pof_string()
    
    for _ in range(num_points):
        point = POFThrusterPoint()
        point.position = reader.read_vector3d()
        point.normal = reader.read_vector3d()
        point.radius = reader.read_float32()
        thruster.points.append(point)
        
    return thruster

def write_thruster(writer: POFWriter, thruster: POFThruster) -> None:
    """Write thruster (FUEL chunk)."""
    writer.write_bytes(b'FUEL')
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(thruster.points))
    writer.write_pof_string(thruster.properties)
    
    for point in thruster.points:
        writer.write_vector3d(point.position)
        writer.write_vector3d(point.normal)
        writer.write_float32(point.radius)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_insignia(reader: POFReader) -> POFInsignia:
    """Read insignia (INSG chunk)."""
    insignia = POFInsignia()
    
    insignia.lod = reader.read_int32()
    num_faces = reader.read_int32()
    num_vertices = reader.read_int32()
    
    # Read vertex positions
    vertices = []
    for _ in range(num_vertices):
        pos = reader.read_vector3d()
        vertices.append(pos)
        
    # Read offset
    insignia.offset = reader.read_vector3d()
    
    # Read faces
    for _ in range(num_faces):
        face = POFInsigniaFace()
        for _ in range(3):  # Triangles
            point = POFInsigniaPoint()
            vert_idx = reader.read_int32()
            point.position = vertices[vert_idx]
            point.u = reader.read_float32()
            point.v = reader.read_float32()
            face.vertices.append(point)
        insignia.faces.append(face)
        
    return insignia

def write_insignia(writer: POFWriter, insignia: POFInsignia) -> None:
    """Write insignia (INSG chunk)."""
    writer.write_bytes(b'INSG')
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(insignia.lod)
    writer.write_int32(len(insignia.faces))
    
    # Collect unique vertices
    vertex_map = {}  # position -> index
    vertices = []
    for face in insignia.faces:
        for point in face.vertices:
            pos_tuple = (point.position.x, point.position.y, point.position.z)
            if pos_tuple not in vertex_map:
                vertex_map[pos_tuple] = len(vertices)
                vertices.append(point.position)
                
    writer.write_int32(len(vertices))
    
    # Write vertex positions
    for vertex in vertices:
        writer.write_vector3d(vertex)
        
    # Write offset
    writer.write_vector3d(insignia.offset)
    
    # Write faces
    for face in insignia.faces:
        for point in face.vertices:
            pos_tuple = (point.position.x, point.position.y, point.position.z)
            vert_idx = vertex_map[pos_tuple]
            writer.write_int32(vert_idx)
            writer.write_float32(point.u)
            writer.write_float32(point.v)
            
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_glow_banks(reader: POFReader) -> List[POFGlowBank]:
    """Read all glow banks."""
    num_banks = reader.read_int32()
    banks = []
    
    for _ in range(num_banks):
        banks.append(read_glow_bank(reader))
        
    return banks

def write_glow_banks(writer: POFWriter, banks: List[POFGlowBank]) -> None:
    """Write all glow banks."""
    writer.write_bytes(b'GLOW')
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(banks))
    for bank in banks:
        write_glow_bank(writer, bank)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_thrusters(reader: POFReader) -> List[POFThruster]:
    """Read all thrusters."""
    num_thrusters = reader.read_int32()
    thrusters = []
    
    for _ in range(num_thrusters):
        thrusters.append(read_thruster(reader))
        
    return thrusters

def write_thrusters(writer: POFWriter, thrusters: List[POFThruster]) -> None:
    """Write all thrusters."""
    writer.write_bytes(b'FUEL')
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(thrusters))
    for thruster in thrusters:
        write_thruster(writer, thruster)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)
