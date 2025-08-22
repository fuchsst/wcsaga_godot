#!/usr/bin/env python3
"""
POF Format Analyzer - EPIC-003 DM-004 Implementation

This module provides comprehensive analysis of POF file format structure,
extracting detailed information about chunks, data organization, and format compliance.

Based on WCS C++ analysis from source/code/model/modelread.cpp
"""

import logging
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, BinaryIO, Dict, List, Optional, Tuple

from .pof_chunks import (ID_ACEN, ID_DOCK, ID_EYE, ID_FUEL, ID_GLOW, ID_GPNT,
                         ID_INSG, ID_MPNT, ID_OHDR, ID_PATH, ID_SHLD, ID_SLDC,
                         ID_SOBJ, ID_SPCL, ID_TXTR, PM_COMPATIBLE_VERSION,
                         PM_OBJFILE_MAJOR_VERSION, POF_HEADER_ID,
                         read_chunk_header, read_float, read_int, read_uint)

logger = logging.getLogger(__name__)

# POF format constants imported from pof_chunks

@dataclass
class ChunkInfo:
    """Information about a single POF chunk."""
    chunk_id: int
    chunk_id_str: str
    offset: int
    length: int
    parsed_successfully: bool = False
    error_message: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

@dataclass 
class POFFormatInfo:
    """Comprehensive POF file format analysis."""
    filename: str
    file_size: int
    version: int
    valid_header: bool
    compatible_version: bool
    chunks: List[ChunkInfo] = field(default_factory=list)
    chunk_count_by_type: Dict[str, int] = field(default_factory=dict)
    total_chunks: int = 0
    parsing_errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            'filename': self.filename,
            'file_size': self.file_size,
            'version': self.version,
            'valid_header': self.valid_header,
            'compatible_version': self.compatible_version,
            'total_chunks': self.total_chunks,
            'chunk_count_by_type': self.chunk_count_by_type,
            'chunks': [
                {
                    'chunk_id': chunk.chunk_id,
                    'chunk_id_str': chunk.chunk_id_str,
                    'offset': chunk.offset,
                    'length': chunk.length,
                    'parsed_successfully': chunk.parsed_successfully,
                    'error_message': chunk.error_message,
                    'metadata': chunk.metadata
                }
                for chunk in self.chunks
            ],
            'parsing_errors': self.parsing_errors,
            'warnings': self.warnings
        }

class POFFormatAnalyzer:
    """
    POF Format Analyzer for comprehensive file format analysis.
    
    Implements EPIC-003 DM-004 requirements for POF format analysis and validation.
    Based on WCS C++ source code analysis from modelread.cpp.
    """
    
    def __init__(self):
        """Initialize POF format analyzer."""
        self.chunk_names = {
            ID_OHDR: 'HDR2', ID_SOBJ: 'OBJ2', ID_TXTR: 'TXTR',
            ID_SPCL: 'SPCL', ID_PATH: 'PATH', ID_GPNT: 'GPNT',
            ID_MPNT: 'MPNT', ID_DOCK: 'DOCK', ID_FUEL: 'FUEL',
            ID_SHLD: 'SHLD', ID_EYE: 'EYE', ID_INSG: 'INSG',
            ID_ACEN: 'ACEN', ID_GLOW: 'GLOW', ID_SLDC: 'SLDC'
        }
        
    def analyze_format(self, file_path: Path) -> POFFormatInfo:
        """
        Analyze POF file format structure and return comprehensive information.
        
        Args:
            file_path: Path to POF file to analyze
            
        Returns:
            POFFormatInfo object with complete analysis results
        """
        logger.info(f"Analyzing POF format: {file_path}")
        
        # Initialize analysis result
        analysis = POFFormatInfo(
            filename=file_path.name,
            file_size=file_path.stat().st_size,
            version=0,
            valid_header=False,
            compatible_version=False
        )
        
        try:
            with open(file_path, 'rb') as f:
                # Analyze header
                if not self._analyze_header(f, analysis):
                    return analysis
                
                # Analyze all chunks
                self._analyze_chunks(f, analysis)
                
                # Generate summary statistics
                self._generate_statistics(analysis)
                
        except FileNotFoundError:
            analysis.parsing_errors.append(f"POF file not found: {file_path}")
        except Exception as e:
            analysis.parsing_errors.append(f"Error analyzing POF file: {e}")
            logger.error(f"Error analyzing POF file {file_path}: {e}", exc_info=True)
            
        return analysis
    
    def _analyze_header(self, f: BinaryIO, analysis: POFFormatInfo) -> bool:
        """
        Analyze POF file header for validity and version compatibility.
        
        Args:
            f: File handle positioned at start
            analysis: Analysis object to update
            
        Returns:
            True if header is valid, False otherwise
        """
        try:
            # Read POF header ID
            pof_id = struct.unpack('<I', f.read(4))[0]
            pof_version = struct.unpack('<i', f.read(4))[0]
            
            analysis.version = pof_version
            
            # Validate header ID
            if pof_id != POF_HEADER_ID:
                analysis.parsing_errors.append(
                    f"Invalid POF header ID. Expected {POF_HEADER_ID:08X}, got {pof_id:08X}"
                )
                return False
                
            analysis.valid_header = True
            
            # Check version compatibility (from C++ analysis)
            if pof_version < PM_COMPATIBLE_VERSION:
                analysis.warnings.append(
                    f"POF version {pof_version} is below minimum compatible version {PM_COMPATIBLE_VERSION}"
                )
            elif (pof_version // 100) > PM_OBJFILE_MAJOR_VERSION:
                analysis.warnings.append(
                    f"POF version {pof_version} major version exceeds maximum supported {PM_OBJFILE_MAJOR_VERSION}"
                )
            else:
                analysis.compatible_version = True
                
            logger.debug(f"POF header valid: ID={pof_id:08X}, Version={pof_version}")
            return True
            
        except (struct.error, EOFError) as e:
            analysis.parsing_errors.append(f"Failed to read POF header: {e}")
            return False
    
    def _analyze_chunks(self, f: BinaryIO, analysis: POFFormatInfo) -> None:
        """
        Analyze all chunks in the POF file.
        
        Args:
            f: File handle positioned after header
            analysis: Analysis object to update
        """
        chunk_index = 0
        
        while True:
            chunk_start_pos = f.tell()
            
            try:
                # Check if there's enough data for a chunk header
                header_bytes = f.peek(8)
                if not header_bytes or len(header_bytes) < 8:
                    logger.debug("Reached end of file (insufficient data for header)")
                    break
                    
                chunk_id, chunk_len = read_chunk_header(f)
                
                # Create chunk info
                chunk_info = ChunkInfo(
                    chunk_id=chunk_id,
                    chunk_id_str=self._get_chunk_name(chunk_id),
                    offset=chunk_start_pos,
                    length=chunk_len
                )
                
                # Validate chunk length
                if chunk_len < 0:
                    chunk_info.error_message = f"Invalid negative chunk length: {chunk_len}"
                    analysis.parsing_errors.append(
                        f"Chunk {chunk_index} at offset {chunk_start_pos}: {chunk_info.error_message}"
                    )
                    break
                
                # Analyze chunk-specific metadata
                self._analyze_chunk_metadata(f, chunk_info, analysis)
                
                # Skip to next chunk
                next_chunk_pos = chunk_start_pos + 8 + chunk_len
                f.seek(next_chunk_pos)
                
                # Add to analysis
                analysis.chunks.append(chunk_info)
                chunk_index += 1
                
                logger.debug(f"Analyzed chunk {chunk_index}: {chunk_info.chunk_id_str} "
                           f"at offset {chunk_start_pos}, length {chunk_len}")
                
            except (struct.error, EOFError):
                logger.debug("Reached end of file or failed to read chunk header")
                break
            except Exception as e:
                error_msg = f"Error analyzing chunk {chunk_index} at offset {chunk_start_pos}: {e}"
                analysis.parsing_errors.append(error_msg)
                logger.error(error_msg)
                break
    
    def _analyze_chunk_metadata(self, f: BinaryIO, chunk_info: ChunkInfo, analysis: POFFormatInfo) -> None:
        """
        Analyze metadata for specific chunk types.
        
        Args:
            f: File handle positioned at chunk data start
            chunk_info: Chunk information to update
            analysis: Analysis object for context
        """
        current_pos = f.tell()
        
        try:
            # Analyze specific chunk types for metadata
            if chunk_info.chunk_id == ID_OHDR:
                self._analyze_ohdr_metadata(f, chunk_info)
            elif chunk_info.chunk_id == ID_SOBJ:
                self._analyze_sobj_metadata(f, chunk_info)
            elif chunk_info.chunk_id == ID_TXTR:
                self._analyze_txtr_metadata(f, chunk_info)
            
            chunk_info.parsed_successfully = True
            
        except Exception as e:
            chunk_info.error_message = f"Metadata analysis failed: {e}"
            logger.warning(f"Failed to analyze metadata for chunk {chunk_info.chunk_id_str}: {e}")
        finally:
            # Always return to original position
            f.seek(current_pos)
    
    def _analyze_ohdr_metadata(self, f: BinaryIO, chunk_info: ChunkInfo) -> None:
        """Analyze OHDR chunk metadata."""
        max_radius = read_float(f)
        obj_flags = read_uint(f)
        num_subobjects = read_int(f)
        
        chunk_info.metadata = {
            'max_radius': max_radius,
            'obj_flags': obj_flags,
            'num_subobjects': num_subobjects
        }
    
    def _analyze_sobj_metadata(self, f: BinaryIO, chunk_info: ChunkInfo) -> None:
        """Analyze SOBJ chunk metadata."""
        subobject_number = read_int(f)
        radius = read_float(f)
        parent = read_int(f)
        
        chunk_info.metadata = {
            'subobject_number': subobject_number,
            'radius': radius,
            'parent': parent
        }
    
    def _analyze_txtr_metadata(self, f: BinaryIO, chunk_info: ChunkInfo) -> None:
        """Analyze TXTR chunk metadata."""
        # TXTR chunk contains null-terminated texture filenames
        # Count approximate number of textures by scanning for null bytes
        data = f.read(min(chunk_info.length, 1024))  # Read first 1KB for analysis
        texture_count = data.count(b'\x00')
        
        chunk_info.metadata = {
            'estimated_texture_count': texture_count
        }
    
    def _generate_statistics(self, analysis: POFFormatInfo) -> None:
        """Generate summary statistics for the analysis."""
        analysis.total_chunks = len(analysis.chunks)
        
        # Count chunks by type
        for chunk in analysis.chunks:
            chunk_type = chunk.chunk_id_str
            analysis.chunk_count_by_type[chunk_type] = analysis.chunk_count_by_type.get(chunk_type, 0) + 1
    
    def _get_chunk_name(self, chunk_id: int) -> str:
        """Get human-readable name for chunk ID."""
        if chunk_id in self.chunk_names:
            return self.chunk_names[chunk_id]
        
        # Try to decode as ASCII
        try:
            chunk_str = struct.pack('<I', chunk_id).decode('ascii', errors='replace')
            # Remove non-printable characters
            chunk_str = ''.join(c if c.isprintable() else '?' for c in chunk_str)
            return chunk_str
        except:
            return f"UNK_{chunk_id:08X}"
    
    def validate_format_compliance(self, analysis: POFFormatInfo) -> List[str]:
        """
        Validate POF format compliance against WCS specifications.
        
        Args:
            analysis: POF format analysis results
            
        Returns:
            List of compliance validation issues
        """
        issues = []
        
        # Check for required chunks
        chunk_types = {chunk.chunk_id for chunk in analysis.chunks}
        
        if ID_OHDR not in chunk_types:
            issues.append("Missing required OHDR (Object Header) chunk")
        
        if ID_SOBJ not in chunk_types:
            issues.append("Missing required SOBJ (Subobject) chunk")
        
        # Check for multiple OHDR chunks (should only have one)
        ohdr_count = analysis.chunk_count_by_type.get('HDR2', 0)
        if ohdr_count > 1:
            issues.append(f"Multiple OHDR chunks found ({ohdr_count}), should only have one")
        
        # Validate version compatibility
        if not analysis.compatible_version:
            issues.append(f"POF version {analysis.version} may not be fully compatible")
        
        # Check for parsing errors
        if analysis.parsing_errors:
            issues.extend([f"Parsing error: {error}" for error in analysis.parsing_errors])
        
        return issues