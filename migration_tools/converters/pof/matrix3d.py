"""
Matrix classes for POF file processing.
Provides 3x3 and 4x4 matrix operations needed for geometry transformations.
"""

from __future__ import annotations
import math
import numpy as np
from typing import List, Tuple, Union, Optional
from .vector3d import Vector3D

class Matrix3D:
    """
    3x3 matrix class for 3D transformations.
    Represents rotation and scale transformations in 3D space.
    """
    
    def __init__(self, data: Optional[Union[List[List[float]], np.ndarray]] = None):
        """
        Initialize a 3x3 matrix.
        
        Args:
            data: Optional 3x3 array of values. If None, creates identity matrix.
        """
        if data is None:
            # Create identity matrix
            self.data = np.eye(3, dtype=np.float32)
        else:
            # Convert input to numpy array
            self.data = np.array(data, dtype=np.float32)
            if self.data.shape != (3, 3):
                raise ValueError("Matrix3D must be 3x3")

    @classmethod
    def from_rows(cls, row1: List[float], row2: List[float], row3: List[float]) -> 'Matrix3D':
        """Create matrix from three row vectors."""
        return cls([row1, row2, row3])

    @classmethod
    def from_columns(cls, col1: List[float], col2: List[float], col3: List[float]) -> 'Matrix3D':
        """Create matrix from three column vectors."""
        return cls(np.column_stack([col1, col2, col3]))

    @classmethod
    def from_basis_vectors(cls, right: Vector3D, up: Vector3D, forward: Vector3D) -> 'Matrix3D':
        """Create matrix from three basis vectors."""
        return cls([
            [right.x, right.y, right.z],
            [up.x, up.y, up.z],
            [forward.x, forward.y, forward.z]
        ])

    @classmethod
    def rotation_x(cls, angle: float) -> 'Matrix3D':
        """Create rotation matrix around X axis."""
        c = math.cos(angle)
        s = math.sin(angle)
        return cls([
            [1.0, 0.0, 0.0],
            [0.0, c, -s],
            [0.0, s, c]
        ])

    @classmethod
    def rotation_y(cls, angle: float) -> 'Matrix3D':
        """Create rotation matrix around Y axis."""
        c = math.cos(angle)
        s = math.sin(angle)
        return cls([
            [c, 0.0, s],
            [0.0, 1.0, 0.0],
            [-s, 0.0, c]
        ])

    @classmethod
    def rotation_z(cls, angle: float) -> 'Matrix3D':
        """Create rotation matrix around Z axis."""
        c = math.cos(angle)
        s = math.sin(angle)
        return cls([
            [c, -s, 0.0],
            [s, c, 0.0],
            [0.0, 0.0, 1.0]
        ])

    @classmethod
    def scale(cls, sx: float, sy: float, sz: float) -> 'Matrix3D':
        """Create scale matrix."""
        return cls([
            [sx, 0.0, 0.0],
            [0.0, sy, 0.0],
            [0.0, 0.0, sz]
        ])

    def __str__(self) -> str:
        """String representation."""
        return f"Matrix3D:\n{self.data}"

    def __repr__(self) -> str:
        """Detailed string representation."""
        return self.__str__()

    def __eq__(self, other: object) -> bool:
        """Test equality with another matrix."""
        if not isinstance(other, Matrix3D):
            return NotImplemented
        return np.allclose(self.data, other.data)

    def __mul__(self, other: Union[Matrix3D, Vector3D, float]) -> Union[Matrix3D, Vector3D]:
        """Matrix multiplication with another matrix, vector, or scalar."""
        if isinstance(other, Matrix3D):
            return Matrix3D(np.dot(self.data, other.data))
        elif isinstance(other, Vector3D):
            result = np.dot(self.data, other.to_numpy())
            return Vector3D.from_numpy(result)
        else:
            return Matrix3D(self.data * float(other))

    def __rmul__(self, scalar: float) -> Matrix3D:
        """Right scalar multiplication."""
        return Matrix3D(self.data * float(scalar))

    def __add__(self, other: Matrix3D) -> Matrix3D:
        """Add two matrices."""
        if not isinstance(other, Matrix3D):
            return NotImplemented
        return Matrix3D(self.data + other.data)

    def determinant(self) -> float:
        """Calculate matrix determinant."""
        return float(np.linalg.det(self.data))

    def inverse(self) -> Matrix3D:
        """Calculate matrix inverse."""
        try:
            return Matrix3D(np.linalg.inv(self.data))
        except np.linalg.LinAlgError:
            raise ValueError("Matrix is not invertible")

    def transpose(self) -> Matrix3D:
        """Calculate matrix transpose."""
        return Matrix3D(self.data.T)

    def to_numpy(self) -> np.ndarray:
        """Convert to numpy array."""
        return self.data.copy()

class Matrix4D:
    """
    4x4 matrix class for 3D transformations including translation.
    Represents full affine transformations in 3D space.
    """
    
    def __init__(self, data: Optional[Union[List[List[float]], np.ndarray]] = None):
        """
        Initialize a 4x4 matrix.
        
        Args:
            data: Optional 4x4 array of values. If None, creates identity matrix.
        """
        if data is None:
            # Create identity matrix
            self.data = np.eye(4, dtype=np.float32)
        else:
            # Convert input to numpy array
            self.data = np.array(data, dtype=np.float32)
            if self.data.shape != (4, 4):
                raise ValueError("Matrix4D must be 4x4")

    @classmethod
    def from_3x3(cls, mat3: Matrix3D, translation: Optional[Vector3D] = None) -> 'Matrix4D':
        """Create 4x4 matrix from 3x3 matrix and optional translation."""
        mat4 = np.eye(4, dtype=np.float32)
        mat4[:3, :3] = mat3.data
        if translation is not None:
            mat4[:3, 3] = [translation.x, translation.y, translation.z]
        return cls(mat4)

    @classmethod
    def translation(cls, x: float, y: float, z: float) -> 'Matrix4D':
        """Create translation matrix."""
        mat = cls()
        mat.data[:3, 3] = [x, y, z]
        return mat

    def get_translation(self) -> Vector3D:
        """Get translation component."""
        return Vector3D(self.data[0, 3], self.data[1, 3], self.data[2, 3])

    def get_rotation(self) -> Matrix3D:
        """Get rotation/scale component as 3x3 matrix."""
        return Matrix3D(self.data[:3, :3])

    def __mul__(self, other: Union[Matrix4D, Vector3D, float]) -> Union[Matrix4D, Vector3D]:
        """Matrix multiplication with another matrix, vector, or scalar."""
        if isinstance(other, Matrix4D):
            return Matrix4D(np.dot(self.data, other.data))
        elif isinstance(other, Vector3D):
            # Convert to homogeneous coordinates
            vec4 = np.array([other.x, other.y, other.z, 1.0])
            result = np.dot(self.data, vec4)
            # Convert back to 3D
            w = result[3]
            if abs(w) > 1e-7:
                result = result / w
            return Vector3D(result[0], result[1], result[2])
        else:
            return Matrix4D(self.data * float(other))

    def __str__(self) -> str:
        """String representation."""
        return f"Matrix4D:\n{self.data}"

    def inverse(self) -> Matrix4D:
        """Calculate matrix inverse."""
        try:
            return Matrix4D(np.linalg.inv(self.data))
        except np.linalg.LinAlgError:
            raise ValueError("Matrix is not invertible")

    def determinant(self) -> float:
        """Calculate matrix determinant."""
        return float(np.linalg.det(self.data))

# Utility functions to match C++ interface

def make_rotation_matrix(angle: float, axis: str) -> Matrix3D:
    """Create rotation matrix around specified axis."""
    if axis.lower() == 'x':
        return Matrix3D.rotation_x(angle)
    elif axis.lower() == 'y':
        return Matrix3D.rotation_y(angle)
    elif axis.lower() == 'z':
        return Matrix3D.rotation_z(angle)
    else:
        raise ValueError("Axis must be 'x', 'y', or 'z'")

def make_scale_matrix(sx: float, sy: float, sz: float) -> Matrix3D:
    """Create scale matrix."""
    return Matrix3D.scale(sx, sy, sz)

def make_translation_matrix(tx: float, ty: float, tz: float) -> Matrix4D:
    """Create translation matrix."""
    return Matrix4D.translation(tx, ty, tz)
