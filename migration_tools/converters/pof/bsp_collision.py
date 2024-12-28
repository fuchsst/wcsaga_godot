"""
BSP collision detection and ray intersection testing.
"""

from __future__ import annotations
from typing import Optional, List
from .vector3d import Vector3D
from .bsp_types import BSPNode, BSPPolygon, BSP_POLY

def traverse_bsp_tree(node: BSPNode, ray_origin: Vector3D, ray_dir: Vector3D) -> Optional[Vector3D]:
    """
    Traverse BSP tree for ray intersection testing.
    Returns intersection point if found, None otherwise.
    
    Args:
        node: BSP tree node to traverse
        ray_origin: Ray origin point
        ray_dir: Ray direction vector
        
    Returns:
        Vector3D intersection point or None if no intersection
    """
    if not node:
        return None
        
    if node.node_type == BSP_POLY:
        # Test polygons in leaf node
        closest_hit = None
        min_dist = float('inf')
        
        for poly_idx in node.polygons:
            hit = intersect_polygon(ray_origin, ray_dir, poly_idx)
            if hit:
                dist = (hit - ray_origin).magnitude()
                if dist < min_dist:
                    min_dist = dist
                    closest_hit = hit
                    
        return closest_hit
        
    # Test split plane
    d = node.plane_normal.dot(ray_origin - node.plane_point)
    denom = node.plane_normal.dot(ray_dir)
    
    if abs(denom) < 1e-6:
        # Ray parallel to plane
        if d > 0:
            return traverse_bsp_tree(node.front, ray_origin, ray_dir)
        else:
            return traverse_bsp_tree(node.back, ray_origin, ray_dir)
            
    t = -d / denom
    if t < 0:
        # Ray points away from plane
        if d > 0:
            return traverse_bsp_tree(node.front, ray_origin, ray_dir)
        else:
            return traverse_bsp_tree(node.back, ray_origin, ray_dir)
            
    # Test both sides
    if d > 0:
        hit = traverse_bsp_tree(node.front, ray_origin, ray_dir)
        if hit:
            return hit
        return traverse_bsp_tree(node.back, ray_origin, ray_dir)
    else:
        hit = traverse_bsp_tree(node.back, ray_origin, ray_dir)
        if hit:
            return hit
        return traverse_bsp_tree(node.front, ray_origin, ray_dir)

def intersect_polygon(ray_origin: Vector3D, ray_dir: Vector3D, 
                     polygon: BSPPolygon) -> Optional[Vector3D]:
    """
    Test ray intersection with polygon.
    Returns intersection point if found, None otherwise.
    
    Args:
        ray_origin: Ray origin point
        ray_dir: Ray direction vector
        polygon: Polygon to test intersection with
        
    Returns:
        Vector3D intersection point or None if no intersection
    """
    # Get polygon normal and point
    normal = polygon.normal
    point = polygon.vertices[0]
    
    # Check if ray is parallel to polygon
    denom = normal.dot(ray_dir)
    if abs(denom) < 1e-6:
        return None
        
    # Get intersection point with polygon plane
    d = normal.dot(point)
    t = (d - normal.dot(ray_origin)) / denom
    if t < 0:
        return None
        
    hit = ray_origin + ray_dir * t
    
    # Test if point is inside polygon
    if point_in_polygon(hit, polygon):
        return hit
        
    return None

def point_in_polygon(point: Vector3D, polygon: BSPPolygon) -> bool:
    """
    Test if point lies inside polygon using winding number algorithm.
    
    Args:
        point: Point to test
        polygon: Polygon to test against
        
    Returns:
        True if point is inside polygon, False otherwise
    """
    winding = 0
    vertices = polygon.vertices
    
    for i in range(len(vertices)):
        j = (i + 1) % len(vertices)
        if vertices[i].y <= point.y:
            if vertices[j].y > point.y:
                if is_left(vertices[i], vertices[j], point) > 0:
                    winding += 1
        else:
            if vertices[j].y <= point.y:
                if is_left(vertices[i], vertices[j], point) < 0:
                    winding -= 1
                    
    return winding != 0

def is_left(p0: Vector3D, p1: Vector3D, point: Vector3D) -> float:
    """
    Test if point is left/right/on line segment p0p1.
    >0 for point left of line
    =0 for point on line
    <0 for point right of line
    """
    return ((p1.x - p0.x) * (point.y - p0.y) - 
            (point.x - p0.x) * (p1.y - p0.y))
