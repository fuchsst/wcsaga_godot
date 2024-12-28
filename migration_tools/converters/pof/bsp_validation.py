"""
BSP tree validation and error checking.
"""

from __future__ import annotations
from typing import List, Set, Dict, Optional
from dataclasses import dataclass, field
from .vector3d import Vector3D
from .bsp_types import BSPNode, BSPPolygon, BSP_POLY, BSP_SPLIT

@dataclass
class ValidationError:
    """Validation error details."""
    error_type: str
    message: str
    node: Optional[BSPNode] = None
    polygon: Optional[BSPPolygon] = None

@dataclass 
class ValidationResult:
    """Results of BSP tree validation."""
    valid: bool
    errors: List[ValidationError] = field(default_factory=list)
    warnings: List[ValidationError] = field(default_factory=list)
    metrics: Dict[str, int] = field(default_factory=dict)

def validate_bsp_tree(root: BSPNode) -> ValidationResult:
    """
    Validate BSP tree structure and data.
    Performs comprehensive validation including:
    - Tree structure validation
    - Polygon validation
    - Bounds validation
    - Split plane validation
    
    Args:
        root: Root node of BSP tree to validate
        
    Returns:
        ValidationResult containing validation status and details
    """
    result = ValidationResult(valid=True)
    
    # Validate tree structure
    validate_tree_structure(root, result)
    
    # Validate node data
    validate_node_data(root, result)
    
    # Calculate metrics
    depth, nodes, polys = calculate_tree_metrics(root)
    result.metrics = {
        'depth': depth,
        'nodes': nodes,
        'polygons': polys
    }
    
    # Tree is invalid if there are any errors
    result.valid = len(result.errors) == 0
    
    return result

def validate_tree_structure(node: Optional[BSPNode], result: ValidationResult, 
                          depth: int = 0, max_depth: int = 100) -> None:
    """
    Validate BSP tree structure recursively.
    
    Args:
        node: Current node to validate
        result: ValidationResult to update
        depth: Current tree depth
        max_depth: Maximum allowed tree depth
    """
    if not node:
        return
        
    # Check max depth
    if depth > max_depth:
        result.errors.append(ValidationError(
            'MAX_DEPTH_EXCEEDED',
            f'Tree depth {depth} exceeds maximum {max_depth}',
            node
        ))
        return
        
    # Validate node type
    if node.node_type not in (BSP_POLY, BSP_SPLIT):
        result.errors.append(ValidationError(
            'INVALID_NODE_TYPE',
            f'Invalid node type: {node.node_type}',
            node
        ))
        
    # Validate split nodes
    if node.node_type == BSP_SPLIT:
        if not node.plane_normal or not node.plane_point:
            result.errors.append(ValidationError(
                'MISSING_SPLIT_PLANE',
                'Split node missing plane normal or point',
                node
            ))
        elif not node.front and not node.back:
            result.warnings.append(ValidationError(
                'EMPTY_SPLIT_NODE',
                'Split node has no children',
                node
            ))
            
        # Validate children
        validate_tree_structure(node.front, result, depth + 1, max_depth)
        validate_tree_structure(node.back, result, depth + 1, max_depth)
        
    # Validate leaf nodes
    elif node.node_type == BSP_POLY:
        if not node.polygons:
            result.warnings.append(ValidationError(
                'EMPTY_LEAF_NODE',
                'Leaf node has no polygons',
                node
            ))
        else:
            # Validate polygons
            validate_polygons(node.polygons, result, node)

def validate_node_data(node: Optional[BSPNode], result: ValidationResult) -> None:
    """
    Validate node data including bounds and polygon data.
    
    Args:
        node: Node to validate
        result: ValidationResult to update
    """
    if not node:
        return
        
    # Validate bounds
    if not node.bound_min or not node.bound_max:
        result.errors.append(ValidationError(
            'MISSING_BOUNDS',
            'Node missing bounding box',
            node
        ))
    elif not validate_bounds(node.bound_min, node.bound_max):
        result.errors.append(ValidationError(
            'INVALID_BOUNDS',
            'Invalid bounding box (min > max)',
            node
        ))
        
    # Validate contained geometry is within bounds
    if node.node_type == BSP_POLY:
        for poly in node.polygons:
            if not polygon_within_bounds(poly, node.bound_min, node.bound_max):
                result.warnings.append(ValidationError(
                    'POLY_OUTSIDE_BOUNDS',
                    'Polygon vertices outside node bounds',
                    node,
                    poly
                ))
                
    # Recurse on children
    validate_node_data(node.front, result)
    validate_node_data(node.back, result)

def validate_polygons(polygons: List[BSPPolygon], result: ValidationResult,
                     node: Optional[BSPNode] = None) -> None:
    """
    Validate polygon data.
    
    Args:
        polygons: List of polygons to validate
        result: ValidationResult to update
        node: Optional node containing polygons
    """
    for poly in polygons:
        # Check for minimum vertices
        if len(poly.vertices) < 3:
            result.errors.append(ValidationError(
                'DEGENERATE_POLYGON',
                f'Polygon has only {len(poly.vertices)} vertices',
                node,
                poly
            ))
            continue
            
        # Validate normal
        if not poly.normal:
            result.errors.append(ValidationError(
                'MISSING_NORMAL',
                'Polygon missing normal',
                node,
                poly
            ))
        elif abs(poly.normal.magnitude() - 1.0) > 0.001:
            result.warnings.append(ValidationError(
                'NON_UNIT_NORMAL',
                'Polygon normal not normalized',
                node,
                poly
            ))
            
        # Check for duplicate vertices
        verts = poly.vertices
        for i in range(len(verts)):
            for j in range(i + 1, len(verts)):
                if verts[i] == verts[j]:
                    result.warnings.append(ValidationError(
                        'DUPLICATE_VERTEX',
                        f'Duplicate vertex at indices {i} and {j}',
                        node,
                        poly
                    ))

def validate_bounds(min_point: Vector3D, max_point: Vector3D) -> bool:
    """
    Validate bounding box min/max points.
    
    Args:
        min_point: Minimum bound point
        max_point: Maximum bound point
        
    Returns:
        True if bounds are valid, False otherwise
    """
    return (min_point.x <= max_point.x and
            min_point.y <= max_point.y and
            min_point.z <= max_point.z)

def polygon_within_bounds(poly: BSPPolygon, min_point: Vector3D,
                         max_point: Vector3D) -> bool:
    """
    Check if polygon vertices are within bounds.
    
    Args:
        poly: Polygon to check
        min_point: Minimum bound point
        max_point: Maximum bound point
        
    Returns:
        True if polygon is within bounds, False otherwise
    """
    for vert in poly.vertices:
        if (vert.x < min_point.x or vert.x > max_point.x or
            vert.y < min_point.y or vert.y > max_point.y or
            vert.z < min_point.z or vert.z > max_point.z):
            return False
    return True

def calculate_tree_metrics(node: Optional[BSPNode]) -> Tuple[int, int, int]:
    """
    Calculate BSP tree metrics.
    
    Args:
        node: Root node of tree
        
    Returns:
        Tuple of (max_depth, total_nodes, total_polygons)
    """
    if not node:
        return (0, 0, 0)
        
    if node.node_type == BSP_POLY:
        return (1, 1, len(node.polygons))
        
    # Get metrics for children
    front_depth, front_nodes, front_polys = calculate_tree_metrics(node.front)
    back_depth, back_nodes, back_polys = calculate_tree_metrics(node.back)
    
    # Combine metrics
    depth = max(front_depth, back_depth) + 1
    nodes = front_nodes + back_nodes + 1
    polys = front_polys + back_polys
    
    return (depth, nodes, polys)
