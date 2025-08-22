#!/usr/bin/env python3
"""
POF to Godot Mesh Converter - EPIC-003 DM-005 Implementation

Main converter orchestrating the complete POF to Godot GLB conversion pipeline
with validation, optimization, and hierarchy preservation.

Implements all DM-005 acceptance criteria:
- AC1: Convert POF geometry to OBJ format
- AC2: Generate material files (MTL) with texture mapping
- AC3: Use Blender automation for OBJ to GLB conversion
- AC4: Create Godot .import files with optimized settings
- AC5: Preserve subsystem hierarchy as Godot node structure
- AC6: Generate conversion validation reports
"""

import json
import logging
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .blender_converter import BlenderOBJConverter
from .godot_import_generator import (GodotImportGenerator,
                                     WCSImportConfigGenerator)
from .pof_data_extractor import POFDataExtractor
from .pof_format_analyzer import POFFormatAnalyzer
from .pof_obj_converter import POFOBJConverter

logger = logging.getLogger(__name__)

@dataclass
class ConversionReport:
    """Comprehensive conversion validation report."""
    source_file: str
    output_file: str
    conversion_time: float
    success: bool
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    
    # Source POF analysis
    pof_version: int = 0
    pof_chunks: int = 0
    pof_subobjects: int = 0
    pof_textures: int = 0
    
    # Intermediate OBJ data
    obj_vertices: int = 0
    obj_faces: int = 0
    obj_materials: int = 0
    obj_groups: int = 0
    
    # Final GLB data
    glb_file_size: int = 0
    glb_exists: bool = False
    import_file_exists: bool = False
    
    # Validation results
    geometry_preserved: bool = False
    materials_preserved: bool = False
    hierarchy_preserved: bool = False
    textures_mapped: bool = False
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert report to dictionary for JSON serialization."""
        return {
            'source_file': self.source_file,
            'output_file': self.output_file,
            'conversion_time': self.conversion_time,
            'success': self.success,
            'errors': self.errors,
            'warnings': self.warnings,
            'source_analysis': {
                'pof_version': self.pof_version,
                'pof_chunks': self.pof_chunks,
                'pof_subobjects': self.pof_subobjects,
                'pof_textures': self.pof_textures
            },
            'intermediate_data': {
                'obj_vertices': self.obj_vertices,
                'obj_faces': self.obj_faces,
                'obj_materials': self.obj_materials,
                'obj_groups': self.obj_groups
            },
            'output_files': {
                'glb_file_size': self.glb_file_size,
                'glb_exists': self.glb_exists,
                'import_file_exists': self.import_file_exists
            },
            'validation': {
                'geometry_preserved': self.geometry_preserved,
                'materials_preserved': self.materials_preserved,
                'hierarchy_preserved': self.hierarchy_preserved,
                'textures_mapped': self.textures_mapped
            }
        }

class POFMeshConverter:
    """
    Complete POF to Godot mesh conversion pipeline.
    
    Orchestrates the conversion from POF format through OBJ/MTL intermediate
    format to final GLB with Godot import settings and validation.
    """
    
    def __init__(self, blender_executable: Optional[Path] = None,
                 temp_dir: Optional[Path] = None, cleanup_temp: bool = True):
        """
        Initialize POF mesh converter.
        
        Args:
            blender_executable: Path to Blender executable (auto-detected if None)
            temp_dir: Directory for temporary files (system temp if None)
            cleanup_temp: Whether to clean up temporary files after conversion
        """
        self.obj_converter = POFOBJConverter()
        self.blender_converter = BlenderOBJConverter(blender_executable)
        self.import_generator = GodotImportGenerator()
        self.wcs_config_generator = WCSImportConfigGenerator()
        self.analyzer = POFFormatAnalyzer()
        self.extractor = POFDataExtractor()
        
        self.temp_dir = temp_dir or Path.cwd() / "temp"
        self.cleanup_temp = cleanup_temp
        
        # Ensure temp directory exists
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        
    def convert_pof_to_glb(self, pof_path: Path, glb_path: Path,
                          texture_dir: Optional[Path] = None,
                          model_type: str = "ship") -> ConversionReport:
        """
        Convert POF file to Godot GLB with full pipeline.
        
        Args:
            pof_path: Path to source POF file
            glb_path: Path to output GLB file
            texture_dir: Directory containing texture files
            model_type: Type of model for optimization ("ship", "station", "debris")
            
        Returns:
            ConversionReport with detailed conversion results and validation
        """
        start_time = time.time()
        report = ConversionReport(
            source_file=str(pof_path),
            output_file=str(glb_path),
            conversion_time=0.0,
            success=False
        )
        
        logger.info(f"Starting POF to GLB conversion: {pof_path} -> {glb_path}")
        
        try:
            # Step 1: Analyze source POF file
            if not self._analyze_source_pof(pof_path, report):
                return report
            
            # Step 2: Convert POF to OBJ+MTL
            obj_path = self._get_temp_obj_path(pof_path)
            if not self._convert_pof_to_obj(pof_path, obj_path, texture_dir, report):
                return report
            
            # Step 3: Convert OBJ to GLB using Blender
            if not self._convert_obj_to_glb(obj_path, glb_path, report):
                return report
            
            # Step 4: Generate Godot import file
            if not self._generate_import_file(glb_path, model_type, report):
                return report
            
            # Step 5: Validate conversion results
            self._validate_conversion(pof_path, glb_path, report)
            
            # Mark as successful if we got this far
            report.success = True
            logger.info(f"Conversion completed successfully: {glb_path}")
            
        except Exception as e:
            error_msg = f"Conversion failed with exception: {e}"
            logger.error(error_msg, exc_info=True)
            report.errors.append(error_msg)
        
        finally:
            # Clean up temporary files if requested
            if self.cleanup_temp:
                self._cleanup_temp_files(pof_path)
            
            # Record total conversion time
            report.conversion_time = time.time() - start_time
        
        return report
    
    def convert_directory(self, input_dir: Path, output_dir: Path,
                         texture_dir: Optional[Path] = None,
                         pattern: str = "*.pof",
                         model_type: str = "ship") -> List[ConversionReport]:
        """
        Convert all POF files in directory to GLB format.
        
        Args:
            input_dir: Directory containing POF files
            output_dir: Directory for GLB output
            texture_dir: Directory containing texture files
            pattern: File pattern to match
            model_type: Default model type for all files
            
        Returns:
            List of ConversionReport objects for each conversion
        """
        pof_files = list(input_dir.glob(pattern))
        reports: List[ConversionReport] = []
        
        logger.info(f"Starting batch conversion: {len(pof_files)} POF files")
        
        # Ensure output directory exists
        output_dir.mkdir(parents=True, exist_ok=True)
        
        for pof_file in pof_files:
            glb_file = output_dir / pof_file.with_suffix('.glb').name
            
            # Detect model type from filename if possible
            detected_type = self._detect_model_type(pof_file.name)
            final_type = detected_type if detected_type else model_type
            
            logger.info(f"Converting {pof_file.name} (type: {final_type})")
            
            report = self.convert_pof_to_glb(pof_file, glb_file, texture_dir, final_type)
            reports.append(report)
            
            if report.success:
                logger.info(f"✓ Converted: {pof_file.name}")
            else:
                logger.error(f"✗ Failed: {pof_file.name} - {'; '.join(report.errors)}")
        
        # Generate batch summary
        successful = sum(1 for r in reports if r.success)
        logger.info(f"Batch conversion complete: {successful}/{len(reports)} successful")
        
        return reports
    
    def _analyze_source_pof(self, pof_path: Path, report: ConversionReport) -> bool:
        """Analyze source POF file and update report."""
        try:
            logger.debug(f"Analyzing POF file: {pof_path}")
            
            analysis = self.analyzer.analyze_format(pof_path)
            if not analysis.valid_header:
                report.errors.append("Invalid POF header")
                return False
            
            # Update report with analysis data
            report.pof_version = analysis.version
            report.pof_chunks = analysis.total_chunks
            
            # Get additional data from extractor
            model_data = self.extractor.extract_model_data(pof_path)
            if model_data:
                report.pof_subobjects = len(model_data.subobjects)
                report.pof_textures = len(model_data.textures)
            
            # Check for format issues
            if analysis.parsing_errors:
                report.warnings.extend(analysis.parsing_errors)
            
            logger.debug(f"POF analysis complete: version {analysis.version}, "
                        f"{analysis.total_chunks} chunks")
            return True
            
        except Exception as e:
            error_msg = f"Failed to analyze POF file: {e}"
            logger.error(error_msg)
            report.errors.append(error_msg)
            return False
    
    def _convert_pof_to_obj(self, pof_path: Path, obj_path: Path, 
                           texture_dir: Optional[Path], report: ConversionReport) -> bool:
        """Convert POF to OBJ format and update report."""
        try:
            logger.debug(f"Converting POF to OBJ: {obj_path}")
            
            if not self.obj_converter.convert_pof_to_obj(pof_path, obj_path, texture_dir):
                report.errors.append("Failed to convert POF to OBJ")
                return False
            
            # Read OBJ file to get statistics
            if obj_path.exists():
                self._analyze_obj_file(obj_path, report)
            
            logger.debug(f"OBJ conversion complete: {obj_path}")
            return True
            
        except Exception as e:
            error_msg = f"Failed POF to OBJ conversion: {e}"
            logger.error(error_msg)
            report.errors.append(error_msg)
            return False
    
    def _convert_obj_to_glb(self, obj_path: Path, glb_path: Path, 
                           report: ConversionReport) -> bool:
        """Convert OBJ to GLB using Blender and update report."""
        try:
            logger.debug(f"Converting OBJ to GLB: {glb_path}")
            
            if not self.blender_converter.blender_executable:
                report.errors.append("Blender executable not found")
                return False
            
            if not self.blender_converter.convert_obj_to_glb(obj_path, glb_path):
                report.errors.append("Failed to convert OBJ to GLB")
                return False
            
            # Check GLB file was created
            if glb_path.exists():
                report.glb_exists = True
                report.glb_file_size = glb_path.stat().st_size
            else:
                report.errors.append("GLB file not created")
                return False
            
            logger.debug(f"GLB conversion complete: {glb_path}")
            return True
            
        except Exception as e:
            error_msg = f"Failed OBJ to GLB conversion: {e}"
            logger.error(error_msg)
            report.errors.append(error_msg)
            return False
    
    def _generate_import_file(self, glb_path: Path, model_type: str, 
                             report: ConversionReport) -> bool:
        """Generate Godot import file and update report."""
        try:
            logger.debug(f"Generating import file for: {glb_path}")
            
            # Get WCS-specific configuration
            ship_class = self._extract_ship_class(glb_path.stem)
            custom_settings = self.wcs_config_generator.generate_config_for_ship_class(ship_class)
            
            if not self.import_generator.generate_import_file(glb_path, model_type, custom_settings):
                report.errors.append("Failed to generate import file")
                return False
            
            # Check import file was created
            import_path = glb_path.with_suffix('.glb.import')
            report.import_file_exists = import_path.exists()
            
            logger.debug(f"Import file generation complete: {import_path}")
            return True
            
        except Exception as e:
            error_msg = f"Failed to generate import file: {e}"
            logger.error(error_msg)
            report.errors.append(error_msg)
            return False
    
    def _validate_conversion(self, pof_path: Path, glb_path: Path, 
                           report: ConversionReport) -> None:
        """Validate conversion results and update report."""
        try:
            logger.debug(f"Validating conversion: {pof_path} -> {glb_path}")
            
            # Basic file existence checks
            report.glb_exists = glb_path.exists()
            report.import_file_exists = glb_path.with_suffix('.glb.import').exists()
            
            if report.glb_exists:
                report.glb_file_size = glb_path.stat().st_size
            
            # Validation logic (placeholder - would need GLB analysis)
            report.geometry_preserved = report.obj_vertices > 0 and report.glb_exists
            report.materials_preserved = report.obj_materials > 0 and report.glb_exists
            report.hierarchy_preserved = report.obj_groups > 0 and report.glb_exists
            report.textures_mapped = report.pof_textures > 0 and report.obj_materials > 0
            
            logger.debug("Conversion validation complete")
            
        except Exception as e:
            warning_msg = f"Failed to validate conversion: {e}"
            logger.warning(warning_msg)
            report.warnings.append(warning_msg)
    
    def _analyze_obj_file(self, obj_path: Path, report: ConversionReport) -> None:
        """Analyze OBJ file and extract statistics."""
        try:
            vertices = 0
            faces = 0
            materials = set()
            groups = set()
            
            with open(obj_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('v '):
                        vertices += 1
                    elif line.startswith('f '):
                        faces += 1
                    elif line.startswith('usemtl '):
                        materials.add(line.split()[1])
                    elif line.startswith('g '):
                        groups.add(line.split()[1])
            
            report.obj_vertices = vertices
            report.obj_faces = faces
            report.obj_materials = len(materials)
            report.obj_groups = len(groups)
            
        except Exception as e:
            logger.warning(f"Failed to analyze OBJ file: {e}")
    
    def _detect_model_type(self, filename: str) -> Optional[str]:
        """Detect model type from filename."""
        filename_lower = filename.lower()
        
        if any(indicator in filename_lower for indicator in ['station', 'base', 'platform']):
            return "station"
        elif any(indicator in filename_lower for indicator in ['debris', 'wreck', 'hulk']):
            return "debris"
        elif any(indicator in filename_lower for indicator in ['fighter', 'bomber', 'ship']):
            return "ship"
        
        return None
    
    def _extract_ship_class(self, filename: str) -> str:
        """Extract ship class from filename for WCS-specific configuration."""
        filename_lower = filename.lower()
        
        # WCS ship class patterns
        if 'fighter' in filename_lower:
            return 'fighter'
        elif 'bomber' in filename_lower:
            return 'bomber'
        elif 'cruiser' in filename_lower:
            return 'cruiser'
        elif 'destroyer' in filename_lower:
            return 'destroyer'
        elif any(cap in filename_lower for cap in ['dreadnought', 'carrier', 'battleship']):
            return 'capital'
        
        return 'fighter'  # Default
    
    def _get_temp_obj_path(self, pof_path: Path) -> Path:
        """Get temporary OBJ file path."""
        return self.temp_dir / f"{pof_path.stem}_temp.obj"
    
    def _cleanup_temp_files(self, pof_path: Path) -> None:
        """Clean up temporary files for POF conversion."""
        try:
            obj_path = self._get_temp_obj_path(pof_path)
            mtl_path = obj_path.with_suffix('.mtl')
            
            for temp_file in [obj_path, mtl_path]:
                if temp_file.exists():
                    temp_file.unlink()
                    
        except Exception as e:
            logger.warning(f"Failed to clean up temp files: {e}")

# Example usage and testing
if __name__ == '__main__':
    import sys
    
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    
    if len(sys.argv) < 3:
        print("Usage: python pof_mesh_converter.py <input.pof> <output.glb> [texture_dir]")
        print("       python pof_mesh_converter.py --batch <input_dir> <output_dir> [texture_dir]")
        sys.exit(1)
    
    converter = POFMeshConverter()
    
    if sys.argv[1] == '--batch':
        # Batch conversion
        input_dir = Path(sys.argv[2])
        output_dir = Path(sys.argv[3])
        texture_dir = Path(sys.argv[4]) if len(sys.argv) > 4 else None
        
        reports = converter.convert_directory(input_dir, output_dir, texture_dir)
        
        # Save batch report
        batch_report = {
            'total_files': len(reports),
            'successful': sum(1 for r in reports if r.success),
            'reports': [r.to_dict() for r in reports]
        }
        
        report_file = output_dir / 'conversion_report.json'
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(batch_report, f, indent=2)
        
        print(f"Batch conversion complete. Report saved: {report_file}")
        
    else:
        # Single file conversion
        pof_path = Path(sys.argv[1])
        glb_path = Path(sys.argv[2])
        texture_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else None
        
        report = converter.convert_pof_to_glb(pof_path, glb_path, texture_dir)
        
        if report.success:
            print(f"Successfully converted {pof_path} to {glb_path}")
            print(f"Conversion time: {report.conversion_time:.2f}s")
        else:
            print(f"Failed to convert {pof_path}")
            for error in report.errors:
                print(f"Error: {error}")
            sys.exit(1)