#!/usr/bin/env python3
"""
Format Validator for WCS-Godot Conversion

Provides validation functionality for converted assets ensuring
they meet quality standards and format requirements.

Author: Dev (GDScript Developer)  
Date: January 29, 2025
Story: DM-003 - Asset Organization and Cataloging
"""

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

@dataclass
class ValidationResult:
    """Result of asset validation"""
    is_valid: bool
    file_path: str
    format_type: str
    issues: List[str]
    warnings: List[str]
    metadata: Dict[str, Any]

class FormatValidator:
    """
    Validates converted assets for format correctness and quality.
    
    Based on EPIC-003 architecture design with lightweight validation
    since WCS parsers are robust and provide reliable output.
    """
    
    def __init__(self):
        """Initialize format validator"""
        self.supported_formats = {
            '.png': self._validate_png,
            '.jpg': self._validate_jpg,
            '.jpeg': self._validate_jpg, 
            '.glb': self._validate_glb,
            '.gltf': self._validate_gltf,
            '.ogg': self._validate_ogg,
            '.wav': self._validate_wav,
            '.tres': self._validate_tres,
            '.tscn': self._validate_tscn,
            '.json': self._validate_json
        }
    
    def validate_file(self, file_path: Path) -> ValidationResult:
        """
        Validate a single file.
        
        Args:
            file_path: Path to file to validate
            
        Returns:
            ValidationResult with validation status and details
        """
        result = ValidationResult(
            is_valid=False,
            file_path=str(file_path),
            format_type="unknown",
            issues=[],
            warnings=[],
            metadata={}
        )
        
        try:
            if not file_path.exists():
                result.issues.append("File does not exist")
                return result
            
            if not file_path.is_file():
                result.issues.append("Path is not a file")
                return result
            
            # Check file size
            file_size = file_path.stat().st_size
            if file_size == 0:
                result.issues.append("File is empty")
                return result
            
            result.metadata['file_size'] = file_size
            
            # Get file extension
            extension = file_path.suffix.lower()
            result.format_type = extension[1:] if extension else "unknown"
            
            # Validate based on format
            if extension in self.supported_formats:
                validator_func = self.supported_formats[extension]
                format_result = validator_func(file_path)
                
                result.is_valid = format_result['valid']
                result.issues.extend(format_result.get('issues', []))
                result.warnings.extend(format_result.get('warnings', []))
                result.metadata.update(format_result.get('metadata', {}))
            else:
                # Unknown format - basic validation only
                result.is_valid = True
                result.warnings.append(f"Unknown format: {extension}")
                
        except Exception as e:
            result.issues.append(f"Validation error: {str(e)}")
            logger.error(f"Error validating {file_path}: {e}")
        
        return result
    
    def _validate_png(self, file_path: Path) -> Dict[str, Any]:
        """Validate PNG image file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            # Try to import PIL for image validation
            from PIL import Image
            
            with Image.open(file_path) as img:
                result['metadata']['dimensions'] = img.size
                result['metadata']['mode'] = img.mode
                result['metadata']['format'] = img.format
                
                # Check for reasonable dimensions
                width, height = img.size
                if width > 8192 or height > 8192:
                    result['warnings'].append(f"Very large image: {width}x{height}")
                elif width < 1 or height < 1:
                    result['issues'].append(f"Invalid dimensions: {width}x{height}")
                
                # Check mode
                if img.mode not in ['RGB', 'RGBA', 'L', 'LA', 'P']:
                    result['warnings'].append(f"Unusual color mode: {img.mode}")
                
                result['valid'] = True
                
        except ImportError:
            # PIL not available - basic validation
            result['valid'] = True
            result['warnings'].append("PIL not available for detailed image validation")
        except Exception as e:
            result['issues'].append(f"Invalid PNG file: {str(e)}")
        
        return result
    
    def _validate_jpg(self, file_path: Path) -> Dict[str, Any]:
        """Validate JPEG image file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            from PIL import Image
            
            with Image.open(file_path) as img:
                result['metadata']['dimensions'] = img.size
                result['metadata']['mode'] = img.mode
                result['metadata']['format'] = img.format
                
                # Check dimensions
                width, height = img.size
                if width > 8192 or height > 8192:
                    result['warnings'].append(f"Very large image: {width}x{height}")
                elif width < 1 or height < 1:
                    result['issues'].append(f"Invalid dimensions: {width}x{height}")
                
                result['valid'] = True
                
        except ImportError:
            result['valid'] = True
            result['warnings'].append("PIL not available for detailed image validation")
        except Exception as e:
            result['issues'].append(f"Invalid JPEG file: {str(e)}")
        
        return result
    
    def _validate_glb(self, file_path: Path) -> Dict[str, Any]:
        """Validate GLB 3D model file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            # Basic GLB validation - check magic number
            with open(file_path, 'rb') as f:
                magic = f.read(4)
                if magic == b'glTF':
                    result['valid'] = True
                    result['metadata']['format'] = 'GLB'
                    
                    # Try to read more header info
                    version = int.from_bytes(f.read(4), 'little')
                    length = int.from_bytes(f.read(4), 'little')
                    
                    result['metadata']['version'] = version
                    result['metadata']['total_length'] = length
                    
                    if version != 2:
                        result['warnings'].append(f"GLB version {version} (expected 2)")
                else:
                    result['issues'].append("Invalid GLB magic number")
                    
        except Exception as e:
            result['issues'].append(f"Invalid GLB file: {str(e)}")
        
        return result
    
    def _validate_gltf(self, file_path: Path) -> Dict[str, Any]:
        """Validate glTF JSON file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            with open(file_path, 'r') as f:
                gltf_data = json.load(f)
                
                # Check required fields
                if 'asset' not in gltf_data:
                    result['issues'].append("Missing required 'asset' field")
                else:
                    asset = gltf_data['asset']
                    result['metadata']['version'] = asset.get('version', 'unknown')
                    result['metadata']['generator'] = asset.get('generator', 'unknown')
                
                # Check for scenes
                if 'scenes' in gltf_data:
                    result['metadata']['scene_count'] = len(gltf_data['scenes'])
                
                # Check for nodes
                if 'nodes' in gltf_data:
                    result['metadata']['node_count'] = len(gltf_data['nodes'])
                
                result['valid'] = True
                
        except json.JSONDecodeError as e:
            result['issues'].append(f"Invalid JSON: {str(e)}")
        except Exception as e:
            result['issues'].append(f"Invalid glTF file: {str(e)}")
        
        return result
    
    def _validate_ogg(self, file_path: Path) -> Dict[str, Any]:
        """Validate OGG audio file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            # Basic OGG validation - check magic number
            with open(file_path, 'rb') as f:
                magic = f.read(4)
                if magic == b'OggS':
                    result['valid'] = True
                    result['metadata']['format'] = 'OGG'
                else:
                    result['issues'].append("Invalid OGG magic number")
                    
        except Exception as e:
            result['issues'].append(f"Invalid OGG file: {str(e)}")
        
        return result
    
    def _validate_wav(self, file_path: Path) -> Dict[str, Any]:
        """Validate WAV audio file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            # Basic WAV validation - check RIFF header
            with open(file_path, 'rb') as f:
                riff = f.read(4)
                if riff == b'RIFF':
                    f.read(4)  # Skip file size
                    wave = f.read(4)
                    if wave == b'WAVE':
                        result['valid'] = True
                        result['metadata']['format'] = 'WAV'
                    else:
                        result['issues'].append("Invalid WAVE header")
                else:
                    result['issues'].append("Invalid RIFF header")
                    
        except Exception as e:
            result['issues'].append(f"Invalid WAV file: {str(e)}")
        
        return result
    
    def _validate_tres(self, file_path: Path) -> Dict[str, Any]:
        """Validate Godot resource (.tres) file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
                # Check for Godot resource header
                if content.startswith('[gd_resource'):
                    result['valid'] = True
                    result['metadata']['format'] = 'Godot Resource'
                    
                    # Try to extract resource type
                    lines = content.split('\n')
                    for line in lines:
                        if line.startswith('[resource]'):
                            break
                        if 'type=' in line:
                            # Extract type from header
                            type_match = line.split('type=')[1].split('"')[1]
                            result['metadata']['resource_type'] = type_match
                            break
                else:
                    result['issues'].append("Not a valid Godot resource file")
                    
        except UnicodeDecodeError:
            result['issues'].append("File encoding error")
        except Exception as e:
            result['issues'].append(f"Invalid .tres file: {str(e)}")
        
        return result
    
    def _validate_tscn(self, file_path: Path) -> Dict[str, Any]:
        """Validate Godot scene (.tscn) file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
                # Check for Godot scene header
                if content.startswith('[gd_scene'):
                    result['valid'] = True
                    result['metadata']['format'] = 'Godot Scene'
                    
                    # Count nodes
                    node_count = content.count('[node ')
                    result['metadata']['node_count'] = node_count
                    
                    # Check for external resources
                    ext_resource_count = content.count('[ext_resource ')
                    result['metadata']['external_resource_count'] = ext_resource_count
                else:
                    result['issues'].append("Not a valid Godot scene file")
                    
        except UnicodeDecodeError:
            result['issues'].append("File encoding error")
        except Exception as e:
            result['issues'].append(f"Invalid .tscn file: {str(e)}")
        
        return result
    
    def _validate_json(self, file_path: Path) -> Dict[str, Any]:
        """Validate JSON file"""
        result = {'valid': False, 'issues': [], 'warnings': [], 'metadata': {}}
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                
                result['valid'] = True
                result['metadata']['format'] = 'JSON'
                result['metadata']['data_type'] = type(data).__name__
                
                # Count top-level keys if it's an object
                if isinstance(data, dict):
                    result['metadata']['key_count'] = len(data)
                elif isinstance(data, list):
                    result['metadata']['item_count'] = len(data)
                    
        except json.JSONDecodeError as e:
            result['issues'].append(f"Invalid JSON: {str(e)}")
        except UnicodeDecodeError:
            result['issues'].append("File encoding error")
        except Exception as e:
            result['issues'].append(f"JSON validation error: {str(e)}")
        
        return result
    
    def validate_directory(self, directory: Path, recursive: bool = True) -> List[ValidationResult]:
        """
        Validate all supported files in a directory.
        
        Args:
            directory: Directory to validate
            recursive: Whether to validate subdirectories
            
        Returns:
            List of validation results
        """
        results = []
        
        if not directory.exists():
            logger.error(f"Directory does not exist: {directory}")
            return results
        
        # Get all files
        pattern = "**/*" if recursive else "*"
        for file_path in directory.glob(pattern):
            if file_path.is_file():
                extension = file_path.suffix.lower()
                if extension in self.supported_formats:
                    result = self.validate_file(file_path)
                    results.append(result)
        
        return results
    
    def generate_validation_report(self, results: List[ValidationResult]) -> Dict[str, Any]:
        """
        Generate comprehensive validation report.
        
        Args:
            results: List of validation results
            
        Returns:
            Dictionary containing validation statistics and details
        """
        report = {
            'summary': {
                'total_files': len(results),
                'valid_files': 0,
                'invalid_files': 0,
                'files_with_warnings': 0
            },
            'by_format': {},
            'issues': [],
            'warnings': []
        }
        
        for result in results:
            # Update summary
            if result.is_valid:
                report['summary']['valid_files'] += 1
            else:
                report['summary']['invalid_files'] += 1
            
            if result.warnings:
                report['summary']['files_with_warnings'] += 1
            
            # Update by format
            format_type = result.format_type
            if format_type not in report['by_format']:
                report['by_format'][format_type] = {
                    'total': 0,
                    'valid': 0,
                    'invalid': 0
                }
            
            report['by_format'][format_type]['total'] += 1
            if result.is_valid:
                report['by_format'][format_type]['valid'] += 1
            else:
                report['by_format'][format_type]['invalid'] += 1
            
            # Collect issues and warnings
            for issue in result.issues:
                report['issues'].append({
                    'file': result.file_path,
                    'format': result.format_type,
                    'issue': issue
                })
            
            for warning in result.warnings:
                report['warnings'].append({
                    'file': result.file_path,
                    'format': result.format_type,
                    'warning': warning
                })
        
        # Calculate success rate
        if report['summary']['total_files'] > 0:
            report['summary']['success_rate'] = report['summary']['valid_files'] / report['summary']['total_files']
        else:
            report['summary']['success_rate'] = 0.0
        
        return report