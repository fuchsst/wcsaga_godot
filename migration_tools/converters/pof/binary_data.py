"""
Binary data handling utilities for POF file format.
Provides classes and functions for reading/writing binary data with proper endianness.
"""

from __future__ import annotations
import struct
import io
from typing import BinaryIO, Union, Optional, List, Tuple
from dataclasses import dataclass
from .vector3d import Vector3D

class BinaryReader:
    """
    Binary data reader with endianness handling.
    Provides methods to read various data types from a binary stream.
    """
    
    def __init__(self, stream: BinaryIO, endian: str = '<'):
        """
        Initialize binary reader.
        
        Args:
            stream: Binary stream to read from
            endian: Endianness ('<' for little-endian, '>' for big-endian)
        """
        self.stream = stream
        self.endian = endian

    def read_bytes(self, size: int) -> bytes:
        """Read raw bytes."""
        data = self.stream.read(size)
        if len(data) < size:
            raise EOFError(f"Attempted to read {size} bytes but only got {len(data)}")
        return data

    def read_int8(self) -> int:
        """Read signed 8-bit integer."""
        return struct.unpack(f"{self.endian}b", self.read_bytes(1))[0]
    
    def read_uint8(self) -> int:
        """Read unsigned 8-bit integer."""
        return struct.unpack(f"{self.endian}B", self.read_bytes(1))[0]

    def read_int16(self) -> int:
        """Read signed 16-bit integer."""
        return struct.unpack(f"{self.endian}h", self.read_bytes(2))[0]
    
    def read_uint16(self) -> int:
        """Read unsigned 16-bit integer."""
        return struct.unpack(f"{self.endian}H", self.read_bytes(2))[0]

    def read_int32(self) -> int:
        """Read signed 32-bit integer."""
        return struct.unpack(f"{self.endian}i", self.read_bytes(4))[0]
    
    def read_uint32(self) -> int:
        """Read unsigned 32-bit integer."""
        return struct.unpack(f"{self.endian}I", self.read_bytes(4))[0]

    def read_float32(self) -> float:
        """Read 32-bit float."""
        return struct.unpack(f"{self.endian}f", self.read_bytes(4))[0]

    def read_vector3d(self) -> Vector3D:
        """Read Vector3D (3 x 32-bit floats)."""
        x = self.read_float32()
        y = self.read_float32()
        z = self.read_float32()
        return Vector3D(x, y, z)

    def read_string(self, size: Optional[int] = None, encoding: str = 'utf-8') -> str:
        """
        Read string with optional size.
        If size is None, reads null-terminated string.
        """
        if size is not None:
            data = self.read_bytes(size)
            # Remove null terminator if present
            if data and data[-1] == 0:
                data = data[:-1]
        else:
            # Read until null terminator
            chunks = []
            while True:
                byte = self.read_bytes(1)
                if byte == b'\0':
                    break
                chunks.append(byte)
            data = b''.join(chunks)
        
        return data.decode(encoding)

    def read_length_prefixed_string(self, encoding: str = 'utf-8') -> str:
        """Read string prefixed with 32-bit length."""
        length = self.read_int32()
        return self.read_string(length, encoding)

    def read_array(self, count: int, element_size: int, format_char: str) -> List[Union[int, float]]:
        """Read array of elements with specified format."""
        format_str = f"{self.endian}{count}{format_char}"
        data = self.read_bytes(count * element_size)
        return list(struct.unpack(format_str, data))

    def align(self, alignment: int) -> None:
        """Align stream to specified byte boundary."""
        pos = self.stream.tell()
        padding = (alignment - (pos % alignment)) % alignment
        if padding:
            self.stream.seek(padding, io.SEEK_CUR)

    def peek_bytes(self, size: int) -> bytes:
        """Peek at upcoming bytes without advancing stream position."""
        pos = self.stream.tell()
        data = self.read_bytes(size)
        self.stream.seek(pos)
        return data

    def peek_uint32(self) -> int:
        """Peek at next 32-bit unsigned integer."""
        pos = self.stream.tell()
        value = self.read_uint32()
        self.stream.seek(pos)
        return value

class BinaryWriter:
    """
    Binary data writer with endianness handling.
    Provides methods to write various data types to a binary stream.
    """
    
    def __init__(self, stream: BinaryIO, endian: str = '<'):
        """
        Initialize binary writer.
        
        Args:
            stream: Binary stream to write to
            endian: Endianness ('<' for little-endian, '>' for big-endian)
        """
        self.stream = stream
        self.endian = endian

    def write_bytes(self, data: bytes) -> None:
        """Write raw bytes."""
        self.stream.write(data)

    def write_int8(self, value: int) -> None:
        """Write signed 8-bit integer."""
        self.write_bytes(struct.pack(f"{self.endian}b", value))
    
    def write_uint8(self, value: int) -> None:
        """Write unsigned 8-bit integer."""
        self.write_bytes(struct.pack(f"{self.endian}B", value))

    def write_int16(self, value: int) -> None:
        """Write signed 16-bit integer."""
        self.write_bytes(struct.pack(f"{self.endian}h", value))
    
    def write_uint16(self, value: int) -> None:
        """Write unsigned 16-bit integer."""
        self.write_bytes(struct.pack(f"{self.endian}H", value))

    def write_int32(self, value: int) -> None:
        """Write signed 32-bit integer."""
        self.write_bytes(struct.pack(f"{self.endian}i", value))
    
    def write_uint32(self, value: int) -> None:
        """Write unsigned 32-bit integer."""
        self.write_bytes(struct.pack(f"{self.endian}I", value))

    def write_float32(self, value: float) -> None:
        """Write 32-bit float."""
        self.write_bytes(struct.pack(f"{self.endian}f", value))

    def write_vector3d(self, vec: Vector3D) -> None:
        """Write Vector3D (3 x 32-bit floats)."""
        self.write_float32(vec.x)
        self.write_float32(vec.y)
        self.write_float32(vec.z)

    def write_string(self, text: str, size: Optional[int] = None, 
                    encoding: str = 'utf-8', pad: bool = True) -> None:
        """
        Write string with optional fixed size.
        If size is specified, pads or truncates to that size.
        If pad is True, adds null terminator.
        """
        data = text.encode(encoding)
        if pad:
            data += b'\0'
            
        if size is not None:
            if len(data) > size:
                data = data[:size]
            else:
                data = data.ljust(size, b'\0')
                
        self.write_bytes(data)

    def write_length_prefixed_string(self, text: str, encoding: str = 'utf-8') -> None:
        """Write string prefixed with 32-bit length."""
        data = text.encode(encoding)
        self.write_int32(len(data))
        self.write_bytes(data)

    def write_array(self, values: List[Union[int, float]], format_char: str) -> None:
        """Write array of elements with specified format."""
        format_str = f"{self.endian}{len(values)}{format_char}"
        self.write_bytes(struct.pack(format_str, *values))

    def align(self, alignment: int) -> None:
        """Align stream to specified byte boundary."""
        pos = self.stream.tell()
        padding = (alignment - (pos % alignment)) % alignment
        if padding:
            self.write_bytes(b'\0' * padding)

    def get_position(self) -> int:
        """Get current stream position."""
        return self.stream.tell()

    def set_position(self, pos: int) -> None:
        """Set stream position."""
        self.stream.seek(pos)

@dataclass
class ChunkHeader:
    """POF chunk header structure."""
    id: str  # 4-char chunk identifier
    size: int  # Size of chunk data in bytes

    @classmethod
    def read(cls, reader: BinaryReader) -> 'ChunkHeader':
        """Read chunk header from binary stream."""
        chunk_id = reader.read_bytes(4).decode('ascii')
        chunk_size = reader.read_uint32()
        return cls(chunk_id, chunk_size)

    def write(self, writer: BinaryWriter) -> None:
        """Write chunk header to binary stream."""
        writer.write_bytes(self.id.encode('ascii'))
        writer.write_uint32(self.size)

def read_pof_string(reader: BinaryReader) -> str:
    """
    Read POF format string (length-prefixed).
    Used in various POF chunks for names and properties.
    """
    length = reader.read_int32()
    return reader.read_string(length)

def write_pof_string(writer: BinaryWriter, text: str) -> None:
    """
    Write POF format string (length-prefixed).
    Used in various POF chunks for names and properties.
    """
    data = text.encode('ascii')
    writer.write_int32(len(data))
    writer.write_bytes(data)
