"""
BSP tree optimization and node merging.
"""

from __future__ import annotations
from typing import Optional, List, Tuple
from .vector3d import Vector3D
from .bsp_types import BSPNode, BSPPolygon, BSP_POLY, BSP_SPLIT

def optimize_bsp_tree(node: BSPNode) -> Optional[BSPNode]:
    """
    Optimize BSP tree by merging nodes and removing empty branches.
    
    Args:
        node: Root node of BSP tree to optimize
        
    Returns:
        Optimized BSP tree root node, or None if tree is empty
    """
    if not node:
        return None
        
    if node.node_type == BSP_POLY:
        if not node.polygons:
            return None
        return node
        
    # Optimize children
    node.front = optimize_bsp_tree(node.front)
    node.back = optimize_bsp_tree(node.back)
    
    # Remove empty branches
    if not node.front and not node.back:
        return None
        
    # Merge single child
    if node.front and not node.back:
        return node.front
    if node.back and not node.front:
        return node.back
        
    # Try to merge similar nodes
    if can_merge_nodes(node.front, node.back):
        return merge_nodes(node.front, node.back)
        
    return node

def can_merge_nodes(node1: Optional[BSPNode], 
                   node2: Optional[BSPNode]) -> bool:
    """
    Test if two nodes can be merged.
    Nodes can be merged if they have similar split planes
    and compatible polygon sets.
    
    Args:
        node1: First node to test
        node2: Second node to test
        
    Returns:
        True if nodes can be merged, False otherwise
    """
    if not node1 or not node2:
        return False
        
    if node1.node_type != node2.node_type:
        return False
        
    if node1.node_type == BSP_POLY:
        # Can merge leaf nodes if they share a boundary
        return nodes_share_boundary(node1, node2)
        
    # Can merge split nodes if planes are nearly parallel
    return planes_nearly_parallel(node1.plane_normal, node2.plane_normal)

def nodes_share_boundary(node1: BSPNode, node2: BSPNode) -> bool:
    """
    Test if two leaf nodes share a boundary polygon.
    
    Args:
        node1: First leaf node
        node2: Second leaf node
        
    Returns:
        True if nodes share boundary, False otherwise
    """
    for poly1 in node1.polygons:
        for poly2 in node2.polygons:
            if polygons_share_edge(poly1, poly2):
                return True
    return False

def polygons_share_edge(poly1: BSPPolygon, poly2: BSPPolygon) -> bool:
    """
    Test if two polygons share an edge.
    
    Args:
        poly1: First polygon
        poly2: Second polygon
        
    Returns:
        True if polygons share an edge, False otherwise
    """
    edges1 = get_polygon_edges(poly1)
    edges2 = get_polygon_edges(poly2)
    
    for edge1 in edges1:
        for edge2 in edges2:
            if edges_match(edge1, edge2):
                return True
    return False

def get_polygon_edges(poly: BSPPolygon) -> List[Tuple[Vector3D, Vector3D]]:
    """
    Get list of edges (vertex pairs) for polygon.
    
    Args:
        poly: Polygon to get edges from
        
    Returns:
        List of (start, end) vertex pairs representing edges
    """
    edges = []
    verts = poly.vertices
    for i in range(len(verts)):
        j = (i + 1) % len(verts)
        edges.append((verts[i], verts[j]))
    return edges

def edges_match(edge1: Tuple[Vector3D, Vector3D], 
                edge2: Tuple[Vector3D, Vector3D]) -> bool:
    """
    Test if two edges match (same vertices in either order).
    
    Args:
        edge1: First edge as (start, end) vertices
        edge2: Second edge as (start, end) vertices
        
    Returns:
        True if edges match, False otherwise
    """
    v1a, v1b = edge1
    v2a, v2b = edge2
    return ((v1a == v2a and v1b == v2b) or
            (v1a == v2b and v1b == v2a))

def planes_nearly_parallel(normal1: Vector3D, normal2: Vector3D) -> bool:
    """
    Test if two plane normals are nearly parallel.
    
    Args:
        normal1: First plane normal
        normal2: Second plane normal
        
    Returns:
        True if normals are nearly parallel, False otherwise
    """
    dot = abs(normal1.dot(normal2))
    return dot > 0.99  # Allow ~8 degree difference

def merge_nodes(node1: BSPNode, node2: BSPNode) -> BSPNode:
    """
    Merge two compatible nodes into a single node.
    
    Args:
        node1: First node to merge
        node2: Second node to merge
        
    Returns:
        New merged node
    """
    if node1.node_type == BSP_POLY:
        # Merge leaf nodes
        merged = BSPNode(BSP_POLY)
        merged.polygons = list(set(node1.polygons + node2.polygons))
        merged.bound_min = Vector3D(
            min(node1.bound_min.x, node2.bound_min.x),
            min(node1.bound_min.y, node2.bound_min.y),
            min(node1.bound_min.z, node2.bound_min.z)
        )
        merged.bound_max = Vector3D(
            max(node1.bound_max.x, node2.bound_max.x),
            max(node1.bound_max.y, node2.bound_max.y),
            max(node1.bound_max.z, node2.bound_max.z)
        )
        return merged
        
    # Merge split nodes
    merged = BSPNode(BSP_SPLIT)
    merged.plane_normal = (node1.plane_normal + node2.plane_normal).normalize()
    merged.plane_point = node1.plane_point  # Use either point
    
    # Recursively merge children
    merged.front = merge_nodes(node1.front, node2.front) if node1.front and node2.front else None
    merged.back = merge_nodes(node1.back, node2.back) if node1.back and node2.back else None
    
    # Update bounds
    merged.bound_min = Vector3D(
        min(node1.bound_min.x, node2.bound_min.x),
        min(node1.bound_min.y, node2.bound_min.y),
        min(node1.bound_min.z, node2.bound_min.z)
    )
    merged.bound_max = Vector3D(
        max(node1.bound_max.x, node2.bound_max.x),
        max(node1.bound_max.y, node2.bound_max.y),
        max(node1.bound_max.z, node2.bound_max.z)
    )
    
    return merged

def calculate_node_metrics(node: BSPNode) -> Tuple[int, int, int]:
    """
    Calculate metrics for BSP tree node.
    
    Args:
        node: Node to analyze
        
    Returns:
        Tuple of (depth, num_nodes, num_polygons)
    """
    if not node:
        return (0, 0, 0)
        
    if node.node_type == BSP_POLY:
        return (1, 1, len(node.polygons))
        
    front_depth, front_nodes, front_polys = calculate_node_metrics(node.front)
    back_depth, back_nodes, back_polys = calculate_node_metrics(node.back)
    
    depth = max(front_depth, back_depth) + 1
    nodes = front_nodes + back_nodes + 1
    polys = front_polys + back_polys
    
    return (depth, nodes, polys)

def optimize_tree_iterative(root: BSPNode, max_iterations: int = 10) -> BSPNode:
    """
    Iteratively optimize BSP tree until no more optimizations possible
    or max iterations reached.
    
    Args:
        root: Root node of tree to optimize
        max_iterations: Maximum optimization iterations
        
    Returns:
        Optimized BSP tree root node
    """
    prev_metrics = calculate_node_metrics(root)
    
    for _ in range(max_iterations):
        optimized = optimize_bsp_tree(root)
        new_metrics = calculate_node_metrics(optimized)
        
        if new_metrics == prev_metrics:
            # No more optimizations possible
            break
            
        prev_metrics = new_metrics
        root = optimized
        
    return root
