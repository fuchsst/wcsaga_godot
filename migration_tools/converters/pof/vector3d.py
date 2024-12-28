"""
Vector3D implementation for POF file processing.
Provides 3D vector math operations needed for geometry processing.
"""

from __future__ import annotations
import math
import numpy as np
from typing import Union, List, Tuple

class Vector3D:
    """
    3D vector class with math operations.
    Represents a point or direction in 3D space using x,y,z coordinates.
    """
    
    def __init__(self, x: float = 0.0, y: float = 0.0, z: float = 0.0):
        """Initialize a Vector3D with x,y,z coordinates."""
        self.x = float(x)
        self.y = float(y) 
        self.z = float(z)

    @classmethod
    def from_tuple(cls, xyz: Tuple[float, float, float]) -> 'Vector3D':
        """Create a Vector3D from a tuple of (x,y,z) values."""
        return cls(xyz[0], xyz[1], xyz[2])

    @classmethod
    def from_numpy(cls, array: np.ndarray) -> 'Vector3D':
        """Create a Vector3D from a numpy array."""
        return cls(array[0], array[1], array[2])

    def to_numpy(self) -> np.ndarray:
        """Convert to numpy array."""
        return np.array([self.x, self.y, self.z], dtype=np.float32)

    def __str__(self) -> str:
        """String representation."""
        return f"Vector3D({self.x:.6f}, {self.y:.6f}, {self.z:.6f})"

    def __repr__(self) -> str:
        """Detailed string representation."""
        return self.__str__()

    def __eq__(self, other: object) -> bool:
        """Test equality with another vector."""
        if not isinstance(other, Vector3D):
            return NotImplemented
        return (abs(self.x - other.x) < 1e-6 and 
                abs(self.y - other.y) < 1e-6 and 
                abs(self.z - other.z) < 1e-6)

    def __add__(self, other: Union[Vector3D, float]) -> Vector3D:
        """Add two vectors or add scalar to all components."""
        if isinstance(other, Vector3D):
            return Vector3D(self.x + other.x, 
                          self.y + other.y,
                          self.z + other.z)
        return Vector3D(self.x + other,
                       self.y + other,
                       self.z + other)

    def __sub__(self, other: Union[Vector3D, float]) -> Vector3D:
        """Subtract two vectors or subtract scalar from all components."""
        if isinstance(other, Vector3D):
            return Vector3D(self.x - other.x,
                          self.y - other.y,
                          self.z - other.z)
        return Vector3D(self.x - other,
                       self.y - other,
                       self.z - other)

    def __mul__(self, scalar: float) -> Vector3D:
        """Multiply vector by scalar."""
        return Vector3D(self.x * scalar,
                       self.y * scalar,
                       self.z * scalar)

    def __rmul__(self, scalar: float) -> Vector3D:
        """Right multiply by scalar."""
        return self.__mul__(scalar)

    def __truediv__(self, scalar: float) -> Vector3D:
        """Divide vector by scalar."""
        if abs(scalar) < 1e-6:
            raise ValueError("Division by zero or near-zero")
        return Vector3D(self.x / scalar,
                       self.y / scalar,
                       self.z / scalar)

    def __getitem__(self, index: int) -> float:
        """Access components by index [0,1,2]."""
        if index == 0:
            return self.x
        elif index == 1:
            return self.y
        elif index == 2:
            return self.z
        raise IndexError("Vector3D index out of range")

    def __setitem__(self, index: int, value: float) -> None:
        """Set components by index [0,1,2]."""
        if index == 0:
            self.x = float(value)
        elif index == 1:
            self.y = float(value)
        elif index == 2:
            self.z = float(value)
        else:
            raise IndexError("Vector3D index out of range")

    def magnitude(self) -> float:
        """Calculate vector magnitude/length."""
        return math.sqrt(self.x * self.x + 
                        self.y * self.y + 
                        self.z * self.z)

    def normalize(self) -> Vector3D:
        """Return normalized (unit) vector."""
        mag = self.magnitude()
        if mag < 1e-6:
            raise ValueError("Cannot normalize zero or near-zero vector")
        return self / mag

    def dot(self, other: Vector3D) -> float:
        """Calculate dot product with another vector."""
        return (self.x * other.x + 
                self.y * other.y + 
                self.z * other.z)

    def cross(self, other: Vector3D) -> Vector3D:
        """Calculate cross product with another vector."""
        return Vector3D(
            self.y * other.z - self.z * other.y,
            self.z * other.x - self.x * other.z,
            self.x * other.y - self.y * other.x
        )

    def distance_to(self, other: Vector3D) -> float:
        """Calculate distance to another vector."""
        return (self - other).magnitude()

    def angle_to(self, other: Vector3D) -> float:
        """Calculate angle to another vector in radians."""
        if self.magnitude() < 1e-6 or other.magnitude() < 1e-6:
            raise ValueError("Cannot calculate angle with zero vector")
            
        # Use dot product formula: cos(θ) = (a·b)/(|a||b|)
        cos_theta = self.dot(other) / (self.magnitude() * other.magnitude())
        
        # Handle floating point errors that could make cos_theta slightly outside [-1,1]
        cos_theta = max(-1.0, min(1.0, cos_theta))
        
        return math.acos(cos_theta)

    @staticmethod
    def average(vectors: List[Vector3D]) -> Vector3D:
        """Calculate average (centroid) of multiple vectors."""
        if not vectors:
            raise ValueError("Cannot average empty vector list")
            
        sum_vec = Vector3D()
        for vec in vectors:
            sum_vec += vec
        return sum_vec / len(vectors)

    def is_zero(self, tolerance: float = 1e-6) -> bool:
        """Check if this is a zero vector within tolerance."""
        return (abs(self.x) < tolerance and 
                abs(self.y) < tolerance and 
                abs(self.z) < tolerance)

    def abs(self) -> Vector3D:
        """Return vector with absolute values of components."""
        return Vector3D(abs(self.x), abs(self.y), abs(self.z))

# Utility Functions

def make_vector(x: float, y: float, z: float) -> Vector3D:
    """Create a new Vector3D - convenience function matching C++ version."""
    return Vector3D(x, y, z)

def make_unit_vector(vec: Vector3D) -> Vector3D:
    """Create a normalized unit vector - convenience function matching C++ version."""
    return vec.normalize()

def cross_product(a: Vector3D, b: Vector3D) -> Vector3D:
    """Calculate cross product - convenience function matching C++ version."""
    return a.cross(b)

def dot_product(a: Vector3D, b: Vector3D) -> float:
    """Calculate dot product - convenience function matching C++ version."""
    return a.dot(b)

def distance(a: Vector3D, b: Vector3D) -> float:
    """Calculate distance between vectors - convenience function matching C++ version."""
    return a.distance_to(b)

def angle(a: Vector3D, b: Vector3D) -> float:
    """Calculate angle between vectors - convenience function matching C++ version."""
    return a.angle_to(b)
