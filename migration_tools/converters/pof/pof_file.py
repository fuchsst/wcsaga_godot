"""
POF file format handler.
Main class for reading and writing POF files.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Dict, Optional, BinaryIO, Tuple
import struct
import io

from .vector3d import Vector3D
from .binary_data import BinaryReader, BinaryWriter, ChunkHeader
from .pof_binary import POFReader, POFWriter, POF_SIGNATURE, POF_VERSION
from .pof_data_structures import (
    BSPBlockHeader, BSPDefPoints, BSPFlatPoly, BSPTmapPoly,
    BSPSortNorm, BSPBoundBox
)
from .pof_chunks import (
    read_textures, write_textures,
    read_model_info, write_model_info,
    read_eyes, write_eyes,
    read_specials, write_specials,
    read_weapons, write_weapons
)
from .pof_effects import (
    POFGlowBank, POFThruster, POFInsignia,
    read_glow_banks, write_glow_banks,
    read_thrusters, write_thrusters,
    read_insignia, write_insignia
)
from .pof_weapons import (
    POFWeaponBank, POFTurret,
    read_weapon_banks, write_weapon_banks,
    read_turrets, write_turrets
)

# POF Version constants
POF_MIN_VERSION = 2116
POF_MAX_VERSION = POF_VERSION

@dataclass
class POFHeader:
    """POF file header data."""
    max_radius: float = 0.0
    obj_flags: int = 0
    num_subobjects: int = 0
    min_bounding: Vector3D = field(default_factory=Vector3D)
    max_bounding: Vector3D = field(default_factory=Vector3D)
    detail_levels: List[int] = field(default_factory=list)
    debris_pieces: List[int] = field(default_factory=list)
    mass: float = 0.0
    mass_center: Vector3D = field(default_factory=Vector3D)
    moment_inertia: List[List[float]] = field(default_factory=lambda: [[0.0]*3 for _ in range(3)])
    cross_sections: List[Tuple[float, float]] = field(default_factory=list)
    lights: List[Tuple[Vector3D, int]] = field(default_factory=list)

@dataclass
class POFObject:
    """POF object/submodel data."""
    number: int = 0
    radius: float = 0.0
    parent: int = -1
    offset: Vector3D = field(default_factory=Vector3D)
    geometric_center: Vector3D = field(default_factory=Vector3D)
    bounding_min: Vector3D = field(default_factory=Vector3D)
    bounding_max: Vector3D = field(default_factory=Vector3D)
    name: str = ""
    properties: str = ""
    movement_type: int = -1
    movement_axis: int = -1
    bsp_data: bytes = b''

class POFFile:
    """
    POF file format handler.
    Provides methods to read and write POF files.
    """
    
    def __init__(self):
        """Initialize POF file handler."""
        self.version = POF_VERSION
        self.header = POFHeader()
        self.textures: List[str] = []
        self.objects: List[POFObject] = []
        self.model_info: List[str] = []
        self.eyes: List[Tuple[int, Vector3D, Vector3D]] = []
        self.specials: List[Tuple[str, str, Vector3D, float]] = []
        self.gun_banks: List[POFWeaponBank] = []
        self.missile_banks: List[POFWeaponBank] = []
        self.gun_turrets: List[POFTurret] = []
        self.missile_turrets: List[POFTurret] = []
        self.docking_points: List[Tuple[str, List[int], List[Tuple[Vector3D, Vector3D]]]] = []
        self.thrusters: List[POFThruster] = []
        self.shield_mesh: List[Tuple[Vector3D, List[int], List[int]]] = []
        self.insignias: List[POFInsignia] = []
        self.paths: List[Tuple[str, str, List[Tuple[Vector3D, float, List[int]]]]] = []
        self.glow_banks: List[POFGlowBank] = []
        self.shield_collision_tree: bytes = b''

    def read(self, filename: str) -> None:
        """
        Read POF file.
        
        Args:
            filename: Path to POF file
            
        Raises:
            ValueError: If file format is invalid
            IOError: If file cannot be read
        """
        with open(filename, 'rb') as f:
            # Read header
            reader = POFReader(f)
            
            # Check signature
            sig = reader.read_bytes(4)
            if sig != POF_SIGNATURE:
                raise ValueError(f"Invalid POF signature: {sig}")
                
            # Check version
            self.version = reader.read_int32()
            if self.version < POF_MIN_VERSION:
                raise ValueError(f"Unsupported POF version: {self.version}")
                
            # Read chunks
            while True:
                try:
                    chunk = reader.read_chunk_header()
                except EOFError:
                    break
                    
                if chunk.id == 'HDR2':
                    self._read_header(reader)
                elif chunk.id == 'TXTR':
                    self.textures = read_textures(reader)
                elif chunk.id == 'OBJ2':
                    self._read_object(reader)
                elif chunk.id == 'PINF':
                    self.model_info = read_model_info(reader)
                elif chunk.id == 'EYE ':
                    self.eyes = read_eyes(reader)
                elif chunk.id == 'SPCL':
                    self.specials = read_specials(reader)
                elif chunk.id == 'GPNT':
                    self.gun_banks = read_weapon_banks(reader, 0)
                elif chunk.id == 'MPNT':
                    self.missile_banks = read_weapon_banks(reader, 1)
                elif chunk.id == 'TGUN':
                    self.gun_turrets = read_turrets(reader, 0)
                elif chunk.id == 'TMIS':
                    self.missile_turrets = read_turrets(reader, 1)
                elif chunk.id == 'DOCK':
                    self._read_docking(reader)
                elif chunk.id == 'FUEL':
                    self.thrusters = read_thrusters(reader)
                elif chunk.id == 'SHLD':
                    self._read_shield(reader)
                elif chunk.id == 'INSG':
                    self.insignias = read_insignia(reader)
                elif chunk.id == 'PATH':
                    self._read_paths(reader)
                elif chunk.id == 'GLOW':
                    self.glow_banks = read_glow_banks(reader)
                elif chunk.id == 'SLDC':
                    self._read_shield_collision(reader)
                else:
                    # Skip unknown chunk
                    reader.read_bytes(chunk.size)

    def write(self, filename: str) -> None:
        """
        Write POF file.
        
        Args:
            filename: Path to write POF file to
            
        Raises:
            IOError: If file cannot be written
        """
        with open(filename, 'wb') as f:
            writer = POFWriter(f)
            
            # Write header
            writer.write_bytes(POF_SIGNATURE)
            writer.write_int32(self.version)
            
            # Write chunks
            if self.textures:
                write_textures(writer, self.textures)
                
            self._write_header(writer)
            
            for obj in self.objects:
                self._write_object(writer, obj)
                
            if self.model_info:
                write_model_info(writer, self.model_info)
                
            if self.eyes:
                write_eyes(writer, self.eyes)
                
            if self.specials:
                write_specials(writer, self.specials)
                
            if self.gun_banks:
                write_weapon_banks(writer, self.gun_banks)
                
            if self.missile_banks:
                write_weapon_banks(writer, self.missile_banks)
                
            if self.gun_turrets:
                write_turrets(writer, self.gun_turrets)
                
            if self.missile_turrets:
                write_turrets(writer, self.missile_turrets)
                
            if self.docking_points:
                self._write_docking(writer)
                
            if self.thrusters:
                write_thrusters(writer, self.thrusters)
                
            if self.shield_mesh:
                self._write_shield(writer)
                
            if self.insignias:
                write_insignia(writer, self.insignias)
                
            if self.paths:
                self._write_paths(writer)
                
            if self.glow_banks:
                write_glow_banks(writer, self.glow_banks)
                
            if self.shield_collision_tree:
                self._write_shield_collision(writer)

    def _read_header(self, reader: POFReader) -> None:
        """Read POF header chunk."""
        self.header.max_radius = reader.read_float32()
        self.header.obj_flags = reader.read_int32()
        self.header.num_subobjects = reader.read_int32()
        self.header.min_bounding = reader.read_vector3d()
        self.header.max_bounding = reader.read_vector3d()
        
        # Read detail levels
        num_detail = reader.read_int32()
        self.header.detail_levels = [reader.read_int32() for _ in range(num_detail)]
        
        # Read debris pieces
        num_debris = reader.read_int32()
        self.header.debris_pieces = [reader.read_int32() for _ in range(num_debris)]
        
        self.header.mass = reader.read_float32()
        self.header.mass_center = reader.read_vector3d()
        
        # Read moment of inertia
        for i in range(3):
            for j in range(3):
                self.header.moment_inertia[i][j] = reader.read_float32()
                
        # Read cross sections
        num_cross = reader.read_int32()
        if num_cross >= 0:
            for _ in range(num_cross):
                depth = reader.read_float32()
                radius = reader.read_float32()
                self.header.cross_sections.append((depth, radius))
                
        # Read lights
        num_lights = reader.read_int32()
        for _ in range(num_lights):
            pos = reader.read_vector3d()
            light_type = reader.read_int32()
            self.header.lights.append((pos, light_type))

    def _write_header(self, writer: POFWriter) -> None:
        """Write POF header chunk."""
        writer.write_bytes(b'HDR2')
        pos = writer.get_position()
        writer.write_int32(0)  # Placeholder for chunk size
        
        writer.write_float32(self.header.max_radius)
        writer.write_int32(self.header.obj_flags)
        writer.write_int32(self.header.num_subobjects)
        writer.write_vector3d(self.header.min_bounding)
        writer.write_vector3d(self.header.max_bounding)
        
        writer.write_int32(len(self.header.detail_levels))
        for level in self.header.detail_levels:
            writer.write_int32(level)
            
        writer.write_int32(len(self.header.debris_pieces))
        for debris in self.header.debris_pieces:
            writer.write_int32(debris)
            
        writer.write_float32(self.header.mass)
        writer.write_vector3d(self.header.mass_center)
        
        for row in self.header.moment_inertia:
            for val in row:
                writer.write_float32(val)
                
        writer.write_int32(len(self.header.cross_sections))
        for depth, radius in self.header.cross_sections:
            writer.write_float32(depth)
            writer.write_float32(radius)
            
        writer.write_int32(len(self.header.lights))
        for pos, light_type in self.header.lights:
            writer.write_vector3d(pos)
            writer.write_int32(light_type)
            
        size = writer.get_position() - pos - 4
        writer.set_position(pos)
        writer.write_int32(size)
        writer.set_position(pos + size + 4)

    def _read_object(self, reader: POFReader) -> None:
        """Read POF object/submodel chunk."""
        obj = POFObject()
        
        obj.number = reader.read_int32()
        obj.radius = reader.read_float32()
        obj.parent = reader.read_int32()
        obj.offset = reader.read_vector3d()
        obj.geometric_center = reader.read_vector3d()
        obj.bounding_min = reader.read_vector3d()
        obj.bounding_max = reader.read_vector3d()
        
        obj.name = reader.read_pof_string()
        obj.properties = reader.read_pof_string()
        
        obj.movement_type = reader.read_int32()
        obj.movement_axis = reader.read_int32()
        reader.read_int32()  # reserved
        
        bsp_size = reader.read_int32()
        if bsp_size > 0:
            obj.bsp_data = reader.read_bytes(bsp_size)
            
        self.objects.append(obj)

    def _write_object(self, writer: POFWriter, obj: POFObject) -> None:
        """Write POF object/submodel chunk."""
        writer.write_bytes(b'OBJ2')
        pos = writer.get_position()
        writer.write_int32(0)  # Placeholder for chunk size
        
        writer.write_int32(obj.number)
        writer.write_float32(obj.radius)
        writer.write_int32(obj.parent)
        writer.write_vector3d(obj.offset)
        writer.write_vector3d(obj.geometric_center)
        writer.write_vector3d(obj.bounding_min)
        writer.write_vector3d(obj.bounding_max)
        
        writer.write_pof_string(obj.name)
        writer.write_pof_string(obj.properties)
        
        writer.write_int32(obj.movement_type)
        writer.write_int32(obj.movement_axis)
        writer.write_int32(0)  # reserved
        
        writer.write_int32(len(obj.bsp_data))
        if obj.bsp_data:
            writer.write_bytes(obj.bsp_data)
            
        size = writer.get_position() - pos - 4
        writer.set_position(pos)
        writer.write_int32(size)
        writer.set_position(pos + size + 4)

    def _read_docking(self, reader: POFReader) -> None:
        """Read POF docking points chunk."""
        num_points = reader.read_int32()
        for _ in range(num_points):
            properties = reader.read_pof_string()
            
            num_paths = reader.read_int32()
            paths = [reader.read_int32() for _ in range(num_paths)]
            
            num_points = reader.read_int32()
            points = []
            for _ in range(num_points):
                pos = reader.read_vector3d()
                normal = reader.read_vector3d()
                points.append((pos, normal))
                
            self.docking_points.append((properties, paths, points))

    def _write_docking(self, writer: POFWriter) -> None:
        """Write POF docking points chunk."""
        writer.write_bytes(b'DOCK')
        pos = writer.get_position()
        writer.write_int32(0)  # Placeholder for chunk size
        
        writer.write_int32(len(self.docking_points))
        for properties, paths, points in self.docking_points:
            writer.write_pof_string(properties)
            
            writer.write_int32(len(paths))
            for path in paths:
                writer.write_int32(path)
                
            writer.write_int32(len(points))
            for point_pos, point_normal in points:
                writer.write_vector3d(point_pos)
                writer.write_vector3d(point_normal)
                
        size = writer.get_position() - pos - 4
        writer.set_position(pos)
        writer.write_int32(size)
        writer.set_position(pos + size + 4)

    def _read_shield(self, reader: POFReader) -> None:
        """Read POF shield mesh chunk."""
        num_verts = reader.read_int32()
        vertices = [reader.read_vector3d() for _ in range(num_verts)]
        
        num_faces = reader.read_int32()
        for _ in range(num_faces):
            normal = reader.read_vector3d()
            face_verts = [reader.read_int32() for _ in range(3)]
            neighbors = [reader.read_int32() for _ in range(3)]
            self.shield_mesh.append((normal, face_verts, neighbors))

    def _write_shield(self, writer: POFWriter) -> None:
        """Write POF shield mesh chunk."""
        writer.write_bytes(b'SHLD')
        pos = writer.get_position()
        writer.write_int32(0)  # Placeholder for chunk size
        
        # Collect unique vertices
        vertices = []
        vertex_map = {}
        for _, face_verts, _ in self.shield_mesh:
            for vert in face_verts:
                if vert not in vertex_map:
                    vertex_map[vert] = len(vertices)
                    vertices.append(vert)
                    
        writer.write_int32(len(vertices))
        for vertex in vertices:
            writer.write_vector3d(vertex)
            
        writer.write_int32(len(self.shield_mesh))
        for normal, face_verts, neighbors in self.shield_mesh:
            writer.write_vector3d(normal)
            for vert in face_verts:
                writer.write_int32(vertex_map[vert])
            for neighbor in neighbors:
                writer.write_int32(neighbor)
                
        size = writer.get_position() - pos - 4
        writer.set_position(pos)
        writer.write_int32(size)
        writer.set_position(pos + size + 4)

    def _read_paths(self, reader: POFReader) -> None:
        """Read POF paths chunk."""
        num_paths = reader.read_int32()
        for _ in range(num_paths):
            name = reader.read_pof_string()
            parent = reader.read_pof_string()
            
            num_verts = reader.read_int32()
            verts = []
            for _ in range(num_verts):
                pos = reader.read_vector3d()
                radius = reader.read_float32()
                
                num_turrets = reader.read_int32()
                turrets = [reader.read_int32() for _ in range(num_turrets)]
                
                verts.append((pos, radius, turrets))
                
            self.paths.append((name, parent, verts))

    def _write_paths(self, writer: POFWriter) -> None:
        """Write POF paths chunk."""
        writer.write_bytes(b'PATH')
        pos = writer.get_position()
        writer.write_int32(0)  # Placeholder for chunk size
        
        writer.write_int32(len(self.paths))
        for name, parent, verts in self.paths:
            writer.write_pof_string(name)
            writer.write_pof_string(parent)
            
            writer.write_int32(len(verts))
            for vert_pos, radius, turrets in verts:
                writer.write_vector3d(vert_pos)
                writer.write_float32(radius)
                
                writer.write_int32(len(turrets))
                for turret in turrets:
                    writer.write_int32(turret)
                    
        size = writer.get_position() - pos - 4
        writer.set_position(pos)
        writer.write_int32(size)
        writer.set_position(pos + size + 4)

    def _read_shield_collision(self, reader: POFReader) -> None:
        """Read POF shield collision tree chunk."""
        size = reader.read_int32()
        if size > 0:
            self.shield_collision_tree = reader.read_bytes(size)

    def _write_shield_collision(self, writer: POFWriter) -> None:
        """Write POF shield collision tree chunk."""
        writer.write_bytes(b'SLDC')
        pos = writer.get_position()
        writer.write_int32(0)  # Placeholder for chunk size
        
        writer.write_int32(len(self.shield_collision_tree))
        if self.shield_collision_tree:
            writer.write_bytes(self.shield_collision_tree)
            
        size = writer.get_position() - pos - 4
        writer.set_position(pos)
        writer.write_int32(size)
        writer.set_position(pos + size + 4)
