"""
POF weapon chunk handlers.
Handles weapon-related chunks (GPNT, MPNT, TGUN, TMIS).
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Tuple, Optional
from .pof_binary import POFReader, POFWriter
from .vector3d import Vector3D

@dataclass
class POFWeaponPoint:
    """POF weapon point data."""
    position: Vector3D = field(default_factory=Vector3D)
    normal: Vector3D = field(default_factory=Vector3D)

@dataclass
class POFWeaponBank:
    """POF weapon bank data."""
    weapon_type: int = 0  # 0 = gun, 1 = missile
    points: List[POFWeaponPoint] = field(default_factory=list)

@dataclass
class POFTurret:
    """POF turret data."""
    weapon_type: int = 0  # 0 = gun, 1 = missile
    sobj_parent: int = -1
    sobj_par_phys: int = -1
    normal: Vector3D = field(default_factory=Vector3D)
    fire_points: List[Vector3D] = field(default_factory=list)

def read_weapon_bank(reader: POFReader, weapon_type: int) -> POFWeaponBank:
    """Read weapon bank (GPNT/MPNT chunk)."""
    bank = POFWeaponBank(weapon_type=weapon_type)
    
    num_points = reader.read_int32()
    for _ in range(num_points):
        point = POFWeaponPoint()
        point.position = reader.read_vector3d()
        point.normal = reader.read_vector3d()
        bank.points.append(point)
        
    return bank

def write_weapon_bank(writer: POFWriter, bank: POFWeaponBank) -> None:
    """Write weapon bank (GPNT/MPNT chunk)."""
    chunk_id = b'GPNT' if bank.weapon_type == 0 else b'MPNT'
    writer.write_bytes(chunk_id)
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(bank.points))
    for point in bank.points:
        writer.write_vector3d(point.position)
        writer.write_vector3d(point.normal)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_turret(reader: POFReader, weapon_type: int) -> POFTurret:
    """Read turret (TGUN/TMIS chunk)."""
    turret = POFTurret(weapon_type=weapon_type)
    
    turret.sobj_parent = reader.read_int32()
    turret.sobj_par_phys = reader.read_int32()
    turret.normal = reader.read_vector3d()
    
    num_points = reader.read_int32()
    for _ in range(num_points):
        point = reader.read_vector3d()
        turret.fire_points.append(point)
        
    return turret

def write_turret(writer: POFWriter, turret: POFTurret) -> None:
    """Write turret (TGUN/TMIS chunk)."""
    chunk_id = b'TGUN' if turret.weapon_type == 0 else b'TMIS'
    writer.write_bytes(chunk_id)
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(turret.sobj_parent)
    writer.write_int32(turret.sobj_par_phys)
    writer.write_vector3d(turret.normal)
    
    writer.write_int32(len(turret.fire_points))
    for point in turret.fire_points:
        writer.write_vector3d(point)
        
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_weapon_banks(reader: POFReader, weapon_type: int) -> List[POFWeaponBank]:
    """Read all weapon banks of a given type."""
    num_banks = reader.read_int32()
    banks = []
    
    for _ in range(num_banks):
        bank = POFWeaponBank(weapon_type=weapon_type)
        num_points = reader.read_int32()
        
        for _ in range(num_points):
            point = POFWeaponPoint()
            point.position = reader.read_vector3d()
            point.normal = reader.read_vector3d()
            bank.points.append(point)
            
        banks.append(bank)
        
    return banks

def write_weapon_banks(writer: POFWriter, banks: List[POFWeaponBank]) -> None:
    """Write all weapon banks of a given type."""
    if not banks:
        return
        
    weapon_type = banks[0].weapon_type
    chunk_id = b'GPNT' if weapon_type == 0 else b'MPNT'
    writer.write_bytes(chunk_id)
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(banks))
    for bank in banks:
        writer.write_int32(len(bank.points))
        for point in bank.points:
            writer.write_vector3d(point.position)
            writer.write_vector3d(point.normal)
            
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)

def read_turrets(reader: POFReader, weapon_type: int) -> List[POFTurret]:
    """Read all turrets of a given type."""
    num_turrets = reader.read_int32()
    turrets = []
    
    for _ in range(num_turrets):
        turret = POFTurret(weapon_type=weapon_type)
        turret.sobj_parent = reader.read_int32()
        turret.sobj_par_phys = reader.read_int32()
        turret.normal = reader.read_vector3d()
        
        num_points = reader.read_int32()
        for _ in range(num_points):
            point = reader.read_vector3d()
            turret.fire_points.append(point)
            
        turrets.append(turret)
        
    return turrets

def write_turrets(writer: POFWriter, turrets: List[POFTurret]) -> None:
    """Write all turrets of a given type."""
    if not turrets:
        return
        
    weapon_type = turrets[0].weapon_type
    chunk_id = b'TGUN' if weapon_type == 0 else b'TMIS'
    writer.write_bytes(chunk_id)
    pos = writer.get_position()
    writer.write_int32(0)  # Placeholder for chunk size
    
    writer.write_int32(len(turrets))
    for turret in turrets:
        writer.write_int32(turret.sobj_parent)
        writer.write_int32(turret.sobj_par_phys)
        writer.write_vector3d(turret.normal)
        
        writer.write_int32(len(turret.fire_points))
        for point in turret.fire_points:
            writer.write_vector3d(point)
            
    size = writer.get_position() - pos - 4
    writer.set_position(pos)
    writer.write_int32(size)
    writer.set_position(pos + size + 4)
