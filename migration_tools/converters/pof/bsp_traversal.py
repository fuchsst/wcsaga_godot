"""
BSP tree traversal and geometry extraction.
Provides functions for extracting geometry from POF BSP data.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple, Set
import math
from .vector3d import Vector3D
from .pof_data_structures import (
    BSPBlockHeader, BSPDefPoints, BSPFlatPoly,
    BSPTmapPoly, BSPSortNorm, BSPBoundBox
)
from .binary_data import BinaryReader
from .matrix3d import Matrix3D

# BSP compilation constants
BSP_MAX_DEPTH = 0
BSP_CUR_DEPTH = 0
BSP_NODE_POLYS = 1
BSP_COMPILE_ERROR = False
BSP_TREE_TIME = 0

# BSP node types
BSP_SPLIT = 0
BSP_POLY = 1
BSP_INVALID = 2

@dataclass
class BSPNode:
    """BSP tree node."""
    node_type: int = BSP_INVALID
    
    # Split plane data
    plane_normal: Vector3D = field(default_factory=Vector3D)
    plane_point: Vector3D = field(default_factory=Vector3D)
    
    # Polygon data
    polygons: List[int] = field(default_factory=list)
    
    # Bounding box
    bound_min: Vector3D = field(default_factory=Vector3D)
    bound_max: Vector3D = field(default_factory=Vector3D)
    
    # Child nodes
    front: Optional[BSPNode] = None
    back: Optional[BSPNode] = None
    
    # Tree building flags
    used: bool = False
    counted: bool = False

@dataclass
class BSPVertex:
    """BSP vertex with position, normal and UV coordinates."""
    position: Vector3D = field(default_factory=Vector3D)
    normal: Vector3D = field(default_factory=Vector3D)
    u: float = 0.0
    v: float = 0.0

@dataclass 
class BSPPolygon:
    """BSP polygon with vertices and material."""
    vertices: List[BSPVertex] = field(default_factory=list)
    texture_id: int = -1
    normal: Vector3D = field(default_factory=Vector3D)

@dataclass
class BSPGeometry:
    """Extracted BSP geometry data."""
    vertices: List[BSPVertex] = field(default_factory=list)
    polygons: List[BSPPolygon] = field(default_factory=list)

def make_bounding_box(polygons: List[BSPPolygon]) -> Tuple[Vector3D, Vector3D]:
    """Calculate bounding box for polygons."""
    if not polygons:
        return Vector3D(), Vector3D()
        
    min_point = Vector3D(float('inf'), float('inf'), float('inf'))
    max_point = Vector3D(float('-inf'), float('-inf'), float('-inf'))
    
    for poly in polygons:
        for vert in poly.vertices:
            # Expand bounds
            min_point.x = min(min_point.x, vert.position.x)
            min_point.y = min(min_point.y, vert.position.y)
            min_point.z = min(min_point.z, vert.position.z)
            
            max_point.x = max(max_point.x, vert.position.x)
            max_point.y = max(max_point.y, vert.position.y)
            max_point.z = max(max_point.z, vert.position.z)
            
    # Add small buffer
    buffer = Vector3D(0.01, 0.01, 0.01)
    min_point = min_point - buffer
    max_point = max_point + buffer
    
    return min_point, max_point

def calculate_polygon_center(polygon: BSPPolygon) -> Vector3D:
    """Calculate polygon center using weighted average."""
    if len(polygon.vertices) < 3:
        return Vector3D()
        
    total_area = 0.0
    centroid = Vector3D()
    
    # Use triangle fan triangulation
    v0 = polygon.vertices[0].position
    for i in range(1, len(polygon.vertices) - 1):
        v1 = polygon.vertices[i].position
        v2 = polygon.vertices[i + 1].position
        
        # Calculate triangle midpoint
        midpoint = (v0 + v1 + v2) / 3.0
        
        # Calculate triangle area
        tri_area = (v1 - v0).cross(v2 - v0).magnitude()
        
        # Add weighted contribution
        centroid += midpoint * tri_area
        total_area += tri_area
        
    if total_area > 0.0:
        centroid = centroid / total_area
        
    return centroid

def split_polygon(polygon: BSPPolygon, plane_point: Vector3D, 
                 plane_normal: Vector3D) -> Tuple[Optional[BSPPolygon], Optional[BSPPolygon]]:
    """Split polygon by plane."""
    front_verts = []
    back_verts = []
    
    # Classify vertices
    for i in range(len(polygon.vertices)):
        v1 = polygon.vertices[i]
        v2 = polygon.vertices[(i + 1) % len(polygon.vertices)]
        
        # Calculate distances to plane
        d1 = plane_normal.dot(v1.position - plane_point)
        d2 = plane_normal.dot(v2.position - plane_point)
        
        # Add v1
        if d1 >= 0:
            front_verts.append(v1)
        if d1 <= 0:
            back_verts.append(v1)
            
        # Check if edge crosses plane
        if (d1 * d2) < 0:
            # Calculate intersection point
            t = d1 / (d1 - d2)
            pos = v1.position + (v2.position - v1.position) * t
            norm = v1.normal + (v2.normal - v1.normal) * t
            u = v1.u + (v2.u - v1.u) * t
            v = v1.v + (v2.v - v1.v) * t
            
            vert = BSPVertex(pos, norm, u, v)
            front_verts.append(vert)
            back_verts.append(vert)
            
    # Create split polygons if we have enough vertices
    front_poly = None
    if len(front_verts) >= 3:
        front_poly = BSPPolygon(
            vertices=front_verts,
            texture_id=polygon.texture_id,
            normal=polygon.normal
        )
        
    back_poly = None    
    if len(back_verts) >= 3:
        back_poly = BSPPolygon(
            vertices=back_verts,
            texture_id=polygon.texture_id,
            normal=polygon.normal
        )
        
    return front_poly, back_poly

def build_bsp_tree(polygons: List[BSPPolygon]) -> Optional[BSPNode]:
    """Build BSP tree from polygons."""
    global BSP_CUR_DEPTH, BSP_MAX_DEPTH
    
    if not polygons:
        return None
        
    # Track recursion depth
    BSP_CUR_DEPTH += 1
    if BSP_MAX_DEPTH < BSP_CUR_DEPTH:
        BSP_MAX_DEPTH = BSP_CUR_DEPTH
        
    # Check max depth
    if BSP_CUR_DEPTH > 500:
        BSP_COMPILE_ERROR = True
        return None
        
    node = BSPNode()
    
    # Calculate bounding box
    node.bound_min, node.bound_max = make_bounding_box(polygons)
    
    # Create leaf node if few polygons
    if len(polygons) <= BSP_NODE_POLYS:
        node.node_type = BSP_POLY
        node.polygons = list(range(len(polygons)))
        return node
        
    # Choose split plane
    split_success = choose_split_plane(polygons, node)
    if not split_success:
        node.node_type = BSP_POLY
        node.polygons = list(range(len(polygons)))
        return node
        
    # Split polygons
    front_polys = []
    back_polys = []
    
    for poly in polygons:
        front, back = split_polygon(poly, node.plane_point, node.plane_normal)
        if front:
            front_polys.append(front)
        if back:
            back_polys.append(back)
            
    # Create child nodes
    node.node_type = BSP_SPLIT
    node.front = build_bsp_tree(front_polys)
    node.back = build_bsp_tree(back_polys)
    
    BSP_CUR_DEPTH -= 1
    return node

def choose_split_plane(polygons: List[BSPPolygon], node: BSPNode) -> bool:
    """Choose best split plane for BSP node."""
    if not polygons:
        return False
        
    # Get bounds of polygon centers
    centers = [calculate_polygon_center(p) for p in polygons]
    
    center_min = Vector3D(float('inf'), float('inf'), float('inf'))
    center_max = Vector3D(float('-inf'), float('-inf'), float('-inf'))
    
    for center in centers:
        center_min.x = min(center_min.x, center.x)
        center_min.y = min(center_min.y, center.y)
        center_min.z = min(center_min.z, center.z)
        
        center_max.x = max(center_max.x, center.x)
        center_max.y = max(center_max.y, center.y)
        center_max.z = max(center_max.z, center.z)
        
    # Find longest axis
    dx = abs(center_max.x - center_min.x)
    dy = abs(center_max.y - center_min.y)
    dz = abs(center_max.z - center_min.z)
    
    if dx >= dy and dx >= dz:
        node.plane_normal = Vector3D(1, 0, 0)
        node.plane_point = Vector3D((center_min.x + center_max.x) / 2, 0, 0)
    elif dy >= dz:
        node.plane_normal = Vector3D(0, 1, 0)
        node.plane_point = Vector3D(0, (center_min.y + center_max.y) / 2, 0)
    else:
        node.plane_normal = Vector3D(0, 0, 1)
        node.plane_point = Vector3D(0, 0, (center_min.z + center_max.z) / 2)
        
    return True

def extract_bsp_geometry(bsp_data: bytes) -> BSPGeometry:
    """
    Extract geometry from BSP data.
    
    Args:
        bsp_data: Raw BSP chunk data
        
    Returns:
        Extracted geometry
    """
    geometry = BSPGeometry()
    reader = BinaryReader(bsp_data)
    
    # First block should be vertex definitions
    header = BSPBlockHeader()
    header.read(reader)
    
    if header.id == 1:  # BSP_DEFPOINTS
        defpoints = BSPDefPoints()
        defpoints.read(reader, header)
        
        # Store vertices and normals
        for i, vdata in enumerate(defpoints.vertex_data):
            vertex = BSPVertex(
                position=vdata.vertex,
                normal=vdata.norms[0] if vdata.norms else Vector3D(0, 0, 1)
            )
            geometry.vertices.append(vertex)
            
    # Process remaining blocks
    while True:
        try:
            header = BSPBlockHeader()
            header.read(reader)
        except EOFError:
            break
            
        if header.id == 0:  # End of data
            break
            
        elif header.id == 2:  # BSP_FLATPOLY
            poly = BSPFlatPoly()
            poly.read(reader, header)
            
            bsp_poly = BSPPolygon(
                texture_id=-1,
                normal=poly.normal
            )
            
            # Add vertices
            for vert in poly.verts:
                vertex = geometry.vertices[vert.vertnum]
                vertex.normal = geometry.vertices[vert.normnum].normal
                bsp_poly.vertices.append(vertex)
                
            geometry.polygons.append(bsp_poly)
            
        elif header.id == 3:  # BSP_TMAPPOLY
            poly = BSPTmapPoly()
            poly.read(reader, header)
            
            bsp_poly = BSPPolygon(
                texture_id=poly.tmap_num,
                normal=poly.normal
            )
            
            # Add vertices with UVs
            for vert in poly.verts:
                vertex = BSPVertex(
                    position=geometry.vertices[vert.vertnum].position,
                    normal=geometry.vertices[vert.normnum].normal,
                    u=vert.u,
                    v=vert.v
                )
                bsp_poly.vertices.append(vertex)
                
            geometry.polygons.append(bsp_poly)
            
        elif header.id == 4:  # BSP_SORTNORM
            # Skip sort nodes - we just want geometry
            reader.read_bytes(header.size - 8)
            
        elif header.id == 5:  # BSP_BOUNDBOX
            # Skip bounding boxes
            reader.read_bytes(header.size - 8)
            
    return geometry

def triangulate_polygon(indices: List[int]) -> List[int]:
    """
    Convert polygon indices to triangle indices.
    Uses simple fan triangulation.
    
    Args:
        indices: Polygon vertex indices
        
    Returns:
        Triangle indices
    """
    if len(indices) < 3:
        return []
        
    triangles = []
    for i in range(1, len(indices) - 1):
        triangles.extend([indices[0], indices[i], indices[i + 1]])
        
    return triangles

def convert_coordinate_system(vertex: BSPVertex) -> BSPVertex:
    """
    Convert vertex from POF to GLTF coordinate system.
    POF uses +X right, +Y up, +Z forward
    GLTF uses +X right, +Y up, +Z back
    
    Args:
        vertex: Vertex to convert
        
    Returns:
        Converted vertex
    """
    # Create new vertex to avoid modifying original
    converted = BSPVertex(
        position=Vector3D(
            vertex.position.x,
            vertex.position.y,
            -vertex.position.z  # Flip Z
        ),
        normal=Vector3D(
            vertex.normal.x,
            vertex.normal.y,
            -vertex.normal.z  # Flip Z
        ),
        u=vertex.u,
        v=vertex.v
    )
    
    return converted
