#!/usr/bin/env python3
import math
import struct


class Vector3D:
    """Represents a 3D vector with x, y, z components."""
    def __init__(self, x: float = 0.0, y: float = 0.0, z: float = 0.0):
        self.x = x
        self.y = y
        self.z = z

    @classmethod
    def from_bytes(cls, data: bytes, offset: int = 0) -> 'Vector3D':
        """Creates a Vector3D by reading 3 floats (12 bytes) from byte data."""
        if offset + 12 > len(data):
            raise ValueError("Not enough data to read Vector3D")
        x, y, z = struct.unpack_from('<fff', data, offset)
        return cls(x, y, z)

    def to_list(self) -> list[float]:
        """Returns the vector components as a list [x, y, z]."""
        return [self.x, self.y, self.z]

    def __repr__(self) -> str:
        return f"Vector3D(x={self.x:.4f}, y={self.y:.4f}, z={self.z:.4f})"

    def __add__(self, other: 'Vector3D') -> 'Vector3D':
        if isinstance(other, Vector3D):
            return Vector3D(self.x + other.x, self.y + other.y, self.z + other.z)
        return NotImplemented

    def __sub__(self, other: 'Vector3D') -> 'Vector3D':
        if isinstance(other, Vector3D):
            return Vector3D(self.x - other.x, self.y - other.y, self.z - other.z)
        return NotImplemented

    def __mul__(self, scalar: float) -> 'Vector3D':
        if isinstance(scalar, (int, float)):
            return Vector3D(self.x * scalar, self.y * scalar, self.z * scalar)
        return NotImplemented

    def __truediv__(self, scalar: float) -> 'Vector3D':
        if isinstance(scalar, (int, float)) and scalar != 0:
            return Vector3D(self.x / scalar, self.y / scalar, self.z / scalar)
        elif scalar == 0:
             raise ZeroDivisionError("Cannot divide Vector3D by zero")
        return NotImplemented

    def magnitude_squared(self) -> float:
        """Returns the squared magnitude (length) of the vector."""
        return self.x**2 + self.y**2 + self.z**2

    def magnitude(self) -> float:
        """Returns the magnitude (length) of the vector."""
        return math.sqrt(self.magnitude_squared())

    def normalize(self) -> 'Vector3D':
        """Returns a normalized version of the vector (unit vector)."""
        mag = self.magnitude()
        if mag == 0:
            return Vector3D(0.0, 0.0, 0.0) # Or raise error? For now, return zero vector.
        return self / mag

    def dot(self, other: 'Vector3D') -> float:
        """Calculates the dot product with another Vector3D."""
        if isinstance(other, Vector3D):
            return self.x * other.x + self.y * other.y + self.z * other.z
        raise TypeError("Operand must be a Vector3D")

    def cross(self, other: 'Vector3D') -> 'Vector3D':
        """Calculates the cross product with another Vector3D."""
        if isinstance(other, Vector3D):
            return Vector3D(
                self.y * other.z - self.z * other.y,
                self.z * other.x - self.x * other.z,
                self.x * other.y - self.y * other.x
            )
        raise TypeError("Operand must be a Vector3D")

# Define Zero Vector constant
ZERO_VECTOR = Vector3D(0.0, 0.0, 0.0)
