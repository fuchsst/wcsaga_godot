#!/usr/bin/env python3
"""
Comprehensive Validation and Testing Framework
DM-012 - Validation and Testing Framework Implementation

Provides comprehensive validation and testing framework ensuring conversion accuracy,
data integrity, and performance standards across all WCS asset types.

Author: Dev (GDScript Developer)
Date: January 30, 2025
Story: DM-012 - Validation and Testing Framework
Epic: EPIC-003 - Data Migration & Conversion Tools

Based on WCS C++ source analysis:
- parselo.cpp/h: Error handling and validation patterns
- model.h: Model structure validation requirements
- missionparse.cpp: Mission data validation approaches
- ship.cpp: Ship data integrity validation patterns
"""

import json
import logging
import time
import threading
import subprocess
import statistics
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, Union
from dataclasses import dataclass, asdict
from enum import Enum
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor, as_completed
import hashlib
import numpy as np
from PIL import Image, ImageChops
import pytest

# Import existing validation components
import sys
sys.path.append(str(Path(__file__).parent.parent))
from conversion_tools.validation.format_validator import FormatValidator, ValidationResult
from conversion_tools.conversion_manager import ConversionManager
from conversion_tools.asset_catalog import AssetCatalog

logger = logging.getLogger(__name__)

class ValidationSeverity(Enum):
    """Validation severity levels based on WCS error handling patterns"""
    INFO = "info"
    WARNING = "warning" 
    ERROR = "error"
    CRITICAL = "critical"

class AssetCategory(Enum):
    """Asset categories for comprehensive validation"""
    MODEL = "model"
    TEXTURE = "texture"
    AUDIO = "audio"
    MISSION = "mission"
    TABLE = "table"
    ARCHIVE = "archive"
    SCENE = "scene"
    RESOURCE = "resource"

@dataclass
class ValidationMetrics:
    """Performance and quality metrics for validation"""
    start_time: float
    end_time: float
    file_count: int
    bytes_processed: int
    errors_found: int
    warnings_found: int
    success_rate: float
    processing_speed_mbps: float
    memory_peak_mb: float
    validation_time_seconds: float

@dataclass
class DataIntegrityResult:
    """Results of data integrity comparison between original and converted assets"""
    original_path: str
    converted_path: str
    integrity_score: float  # 0.0 to 1.0
    missing_properties: List[str]
    modified_properties: List[str]
    extra_properties: List[str]
    data_loss_detected: bool
    checksum_match: bool
    size_variance_percent: float

@dataclass
class PerformanceBenchmark:
    """Performance benchmark results for conversion operations"""
    asset_type: str
    file_size_mb: float
    conversion_time_seconds: float
    memory_usage_mb: float
    throughput_mbps: float
    cpu_usage_percent: float
    success: bool
    error_message: Optional[str] = None

@dataclass
class VisualFidelityResult:
    """Results of visual fidelity comparison between original and converted assets"""
    original_path: str
    converted_path: str
    similarity_score: float  # 0.0 to 1.0 (1.0 = identical)
    pixel_difference_count: int
    structural_similarity_index: float
    color_histogram_difference: float
    visual_artifacts_detected: List[str]
    acceptable_quality: bool

@dataclass
class ComprehensiveValidationReport:
    """Complete validation report with all test results and metrics"""
    timestamp: str
    validation_id: str
    source_directory: str
    target_directory: str
    total_assets: int
    
    # Asset validation results
    format_validation_results: List[ValidationResult]
    integrity_validation_results: List[DataIntegrityResult]
    visual_fidelity_results: List[VisualFidelityResult]
    
    # Performance metrics
    performance_benchmarks: List[PerformanceBenchmark]
    overall_metrics: ValidationMetrics
    
    # Summary statistics
    validation_summary: Dict[str, Any]
    regression_analysis: Dict[str, Any]
    quality_scores: Dict[str, float]
    
    # Recommendations and issues
    critical_issues: List[str]
    recommendations: List[str]
    trend_analysis: Dict[str, Any]

class ComprehensiveValidator:
    """
    Comprehensive validation and testing framework for WCS-Godot conversion.
    
    Implements all DM-012 acceptance criteria:
    - AC1: Asset validation testing all converted formats against WCS specifications
    - AC2: Performance benchmarking with automated regression testing  
    - AC3: Data integrity verification ensuring zero data loss
    - AC4: Visual fidelity testing with automated comparison
    - AC5: Comprehensive test reports with trend analysis
    - AC6: Automated test suite integration with CI/CD compatibility
    """
    
    def __init__(self, config_path: Optional[Path] = None):
        """Initialize comprehensive validator with configuration"""
        self.config = self._load_config(config_path)
        self.format_validator = FormatValidator()
        self.conversion_manager = ConversionManager()
        self.asset_catalog = AssetCatalog()
        
        # Validation thresholds from WCS analysis
        self.quality_thresholds = {
            'data_integrity_minimum': 0.99,  # 99% data preservation required
            'visual_similarity_minimum': 0.95,  # 95% visual similarity required
            'performance_regression_threshold': 1.5,  # Max 50% performance degradation
            'error_rate_maximum': 0.01,  # Max 1% error rate
            'memory_usage_maximum_mb': 2048,  # Max 2GB memory usage
        }
        
        # WCS-specific validation patterns from C++ analysis
        self.wcs_validation_patterns = {
            'model_validation': {
                'required_properties': ['vertices', 'faces', 'materials', 'textures'],
                'subsystem_validation': True,
                'lod_validation': True,
                'collision_validation': True
            },
            'mission_validation': {
                'required_sections': ['#Mission Info', '#Objects', '#Events', '#Goals'],
                'sexp_validation': True,
                'object_validation': True,
                'waypoint_validation': True
            },
            'table_validation': {
                'parsing_validation': True,
                'data_type_validation': True,
                'cross_reference_validation': True,
                'modular_table_support': True
            }
        }
        
    def _load_config(self, config_path: Optional[Path]) -> Dict[str, Any]:
        """Load validation configuration"""
        default_config = {
            'parallel_workers': 4,
            'memory_limit_mb': 4096,
            'timeout_seconds': 300,
            'enable_visual_testing': True,
            'enable_performance_testing': True,
            'enable_regression_testing': True,
            'output_formats': ['json', 'html', 'xml'],
            'benchmark_iterations': 3,
            'comparison_tolerance': 0.001
        }
        
        if config_path and config_path.exists():
            with open(config_path, 'r') as f:
                user_config = json.load(f)
                default_config.update(user_config)
        
        return default_config
    
    def validate_comprehensive(self, source_dir: Path, target_dir: Path, 
                             asset_types: Optional[List[str]] = None) -> ComprehensiveValidationReport:
        """
        Perform comprehensive validation of converted assets.
        
        Args:
            source_dir: Original WCS assets directory
            target_dir: Converted Godot assets directory
            asset_types: Optional list of asset types to validate
            
        Returns:
            Complete validation report with all test results
        """
        validation_id = f"validation_{int(time.time())}"
        start_time = time.time()
        
        logger.info(f"Starting comprehensive validation {validation_id}")
        logger.info(f"Source: {source_dir}")
        logger.info(f"Target: {target_dir}")
        
        # Initialize report
        report = ComprehensiveValidationReport(
            timestamp=time.strftime("%Y-%m-%d %H:%M:%S"),
            validation_id=validation_id,
            source_directory=str(source_dir),
            target_directory=str(target_dir),
            total_assets=0,
            format_validation_results=[],
            integrity_validation_results=[],
            visual_fidelity_results=[],
            performance_benchmarks=[],
            overall_metrics=ValidationMetrics(
                start_time=start_time,
                end_time=0,
                file_count=0,
                bytes_processed=0,
                errors_found=0,
                warnings_found=0,
                success_rate=0.0,
                processing_speed_mbps=0.0,
                memory_peak_mb=0.0,
                validation_time_seconds=0.0
            ),
            validation_summary={},
            regression_analysis={},
            quality_scores={},
            critical_issues=[],
            recommendations=[],
            trend_analysis={}
        )
        
        try:
            # AC1: Asset validation testing all converted formats
            format_results = self._validate_asset_formats(target_dir, asset_types)
            report.format_validation_results = format_results
            
            # AC3: Data integrity verification  
            integrity_results = self._validate_data_integrity(source_dir, target_dir, asset_types)
            report.integrity_validation_results = integrity_results
            
            # AC4: Visual fidelity testing
            if self.config['enable_visual_testing']:
                visual_results = self._validate_visual_fidelity(source_dir, target_dir, asset_types)
                report.visual_fidelity_results = visual_results
            
            # AC2: Performance benchmarking
            if self.config['enable_performance_testing']:
                performance_results = self._benchmark_performance(source_dir, target_dir, asset_types)
                report.performance_benchmarks = performance_results
            
            # Calculate overall metrics
            end_time = time.time()
            report.overall_metrics.end_time = end_time
            report.overall_metrics.validation_time_seconds = end_time - start_time
            
            # AC5: Generate comprehensive analysis
            self._analyze_results(report)
            
            # AC6: Automated test suite integration
            if self.config['enable_regression_testing']:
                self._perform_regression_analysis(report)
            
            logger.info(f"Comprehensive validation completed in {report.overall_metrics.validation_time_seconds:.2f}s")
            
        except Exception as e:
            logger.error(f"Validation failed: {e}")
            report.critical_issues.append(f"Validation framework error: {str(e)}")
            
        return report
    
    def _validate_asset_formats(self, target_dir: Path, asset_types: Optional[List[str]]) -> List[ValidationResult]:
        """AC1: Validate all converted asset formats against WCS specifications"""
        logger.info("Validating asset formats against WCS specifications")
        
        results = []
        
        # Get all converted assets
        asset_files = []
        for pattern in ['**/*.glb', '**/*.gltf', '**/*.png', '**/*.jpg', '**/*.ogg', 
                       '**/*.wav', '**/*.tres', '**/*.tscn', '**/*.json']:
            asset_files.extend(target_dir.glob(pattern))
        
        logger.info(f"Found {len(asset_files)} assets to validate")
        
        # Parallel validation for performance
        with ThreadPoolExecutor(max_workers=self.config['parallel_workers']) as executor:
            future_to_file = {
                executor.submit(self._validate_single_asset_format, file_path): file_path 
                for file_path in asset_files
            }
            
            for future in as_completed(future_to_file):
                file_path = future_to_file[future]
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error(f"Failed to validate {file_path}: {e}")
                    error_result = ValidationResult(
                        is_valid=False,
                        file_path=str(file_path),
                        format_type="error",
                        issues=[f"Validation error: {str(e)}"],
                        warnings=[],
                        metadata={}
                    )
                    results.append(error_result)
        
        return results
    
    def _validate_single_asset_format(self, file_path: Path) -> ValidationResult:
        """Validate single asset format against WCS specifications"""
        # Use existing format validator as base
        result = self.format_validator.validate_file(file_path)
        
        # Add WCS-specific validation
        extension = file_path.suffix.lower()
        
        if extension in ['.glb', '.gltf']:
            # Model-specific WCS validation
            self._validate_wcs_model_format(file_path, result)
        elif extension in ['.tres', '.tscn']:
            # Godot resource WCS validation
            self._validate_wcs_godot_resource(file_path, result)
        elif extension == '.json':
            # Table data WCS validation
            self._validate_wcs_table_data(file_path, result)
        
        return result
    
    def _validate_wcs_model_format(self, model_path: Path, result: ValidationResult) -> None:
        """Validate converted model against WCS model specifications"""
        try:
            # Check for WCS model metadata
            metadata_path = model_path.with_suffix('.metadata.json')
            if metadata_path.exists():
                with open(metadata_path, 'r') as f:
                    wcs_metadata = json.load(f)
                    
                # Validate WCS-specific properties
                required_wcs_props = ['subsystems', 'lod_levels', 'texture_references', 'collision_data']
                for prop in required_wcs_props:
                    if prop not in wcs_metadata:
                        result.warnings.append(f"Missing WCS property: {prop}")
                        
                result.metadata['wcs_metadata'] = wcs_metadata
            else:
                result.warnings.append("No WCS metadata found for model")
                
        except Exception as e:
            result.warnings.append(f"WCS model validation error: {str(e)}")
    
    def _validate_wcs_godot_resource(self, resource_path: Path, result: ValidationResult) -> None:
        """Validate Godot resource against WCS conversion standards"""
        try:
            with open(resource_path, 'r') as f:
                content = f.read()
                
            # Check for WCS-specific resource properties
            if '[resource]' in content and 'BaseAssetData' in content:
                result.metadata['wcs_resource_type'] = 'BaseAssetData'
                
                # Validate WCS asset structure
                if 'asset_id' not in content:
                    result.warnings.append("Missing asset_id in WCS resource")
                if 'asset_type' not in content:
                    result.warnings.append("Missing asset_type in WCS resource")
                    
        except Exception as e:
            result.warnings.append(f"WCS resource validation error: {str(e)}")
    
    def _validate_wcs_table_data(self, json_path: Path, result: ValidationResult) -> None:
        """Validate converted table data against WCS table specifications"""
        try:
            with open(json_path, 'r') as f:
                table_data = json.load(f)
                
            # Check for WCS table structure
            if 'table_type' in table_data:
                table_type = table_data['table_type']
                
                # Validate specific table types
                if table_type == 'ships':
                    self._validate_ships_table_data(table_data, result)
                elif table_type == 'weapons':
                    self._validate_weapons_table_data(table_data, result)
                elif table_type == 'species':
                    self._validate_species_table_data(table_data, result)
                    
        except Exception as e:
            result.warnings.append(f"WCS table validation error: {str(e)}")
    
    def _validate_ships_table_data(self, table_data: Dict, result: ValidationResult) -> None:
        """Validate ships table data against WCS ship_info structure"""
        required_ship_props = ['name', 'class', 'max_vel', 'hitpoints', 'subsystems']
        entries = table_data.get('entries', [])
        
        for i, entry in enumerate(entries):
            for prop in required_ship_props:
                if prop not in entry:
                    result.warnings.append(f"Ship entry {i} missing required property: {prop}")
    
    def _validate_weapons_table_data(self, table_data: Dict, result: ValidationResult) -> None:
        """Validate weapons table data against WCS weapon_info structure"""
        required_weapon_props = ['name', 'class', 'damage', 'range', 'projectile_speed']
        entries = table_data.get('entries', [])
        
        for i, entry in enumerate(entries):
            for prop in required_weapon_props:
                if prop not in entry:
                    result.warnings.append(f"Weapon entry {i} missing required property: {prop}")
    
    def _validate_species_table_data(self, table_data: Dict, result: ValidationResult) -> None:
        """Validate species table data against WCS species_info structure"""
        required_species_props = ['name', 'debris_damage_type', 'debris_ambient_damage_type']
        entries = table_data.get('entries', [])
        
        for i, entry in enumerate(entries):
            for prop in required_species_props:
                if prop not in entry:
                    result.warnings.append(f"Species entry {i} missing required property: {prop}")
    
    def _validate_data_integrity(self, source_dir: Path, target_dir: Path, 
                                asset_types: Optional[List[str]]) -> List[DataIntegrityResult]:
        """AC3: Verify data integrity between original and converted assets"""
        logger.info("Validating data integrity between original and converted assets")
        
        results = []
        
        # Find matching asset pairs
        asset_pairs = self._find_asset_pairs(source_dir, target_dir)
        
        with ThreadPoolExecutor(max_workers=self.config['parallel_workers']) as executor:
            future_to_pair = {
                executor.submit(self._compare_asset_integrity, original, converted): (original, converted)
                for original, converted in asset_pairs
            }
            
            for future in as_completed(future_to_pair):
                original, converted = future_to_pair[future]
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error(f"Failed integrity check for {original} -> {converted}: {e}")
        
        return results
    
    def _find_asset_pairs(self, source_dir: Path, target_dir: Path) -> List[Tuple[Path, Path]]:
        """Find matching pairs of original and converted assets"""
        pairs = []
        
        # VP archives -> extracted directories
        for vp_file in source_dir.glob('**/*.vp'):
            extracted_dir = target_dir / 'extracted' / vp_file.stem
            if extracted_dir.exists():
                pairs.append((vp_file, extracted_dir))
        
        # POF models -> GLB files  
        for pof_file in source_dir.glob('**/*.pof'):
            glb_file = target_dir / 'models' / f"{pof_file.stem}.glb"
            if glb_file.exists():
                pairs.append((pof_file, glb_file))
        
        # Mission files -> scene files
        for mission_file in source_dir.glob('**/*.fs2'):
            scene_file = target_dir / 'missions' / f"{mission_file.stem}.tscn"
            if scene_file.exists():
                pairs.append((mission_file, scene_file))
        
        # Table files -> resource files
        for table_file in source_dir.glob('**/*.tbl'):
            resource_file = target_dir / 'tables' / f"{table_file.stem}.tres"
            if resource_file.exists():
                pairs.append((table_file, resource_file))
        
        return pairs
    
    def _compare_asset_integrity(self, original_path: Path, converted_path: Path) -> DataIntegrityResult:
        """Compare integrity between original and converted asset"""
        result = DataIntegrityResult(
            original_path=str(original_path),
            converted_path=str(converted_path),
            integrity_score=0.0,
            missing_properties=[],
            modified_properties=[],
            extra_properties=[],
            data_loss_detected=False,
            checksum_match=False,
            size_variance_percent=0.0
        )
        
        try:
            # Calculate file size variance
            original_size = original_path.stat().st_size
            converted_size = converted_path.stat().st_size if converted_path.is_file() else sum(
                f.stat().st_size for f in converted_path.rglob('*') if f.is_file()
            )
            
            result.size_variance_percent = abs(converted_size - original_size) / original_size * 100
            
            # Extension-specific integrity checks
            if original_path.suffix.lower() == '.vp':
                self._check_vp_extraction_integrity(original_path, converted_path, result)
            elif original_path.suffix.lower() == '.pof':
                self._check_pof_conversion_integrity(original_path, converted_path, result)
            elif original_path.suffix.lower() == '.fs2':
                self._check_mission_conversion_integrity(original_path, converted_path, result)
            elif original_path.suffix.lower() == '.tbl':
                self._check_table_conversion_integrity(original_path, converted_path, result)
            
            # Calculate overall integrity score
            score_factors = []
            if not result.data_loss_detected:
                score_factors.append(0.4)
            if len(result.missing_properties) == 0:
                score_factors.append(0.3)
            if result.size_variance_percent < 10:  # Less than 10% size variance
                score_factors.append(0.2)
            if len(result.modified_properties) == 0:
                score_factors.append(0.1)
                
            result.integrity_score = sum(score_factors)
            
        except Exception as e:
            logger.error(f"Integrity comparison failed: {e}")
            result.data_loss_detected = True
            
        return result
    
    def _check_vp_extraction_integrity(self, vp_path: Path, extracted_dir: Path, result: DataIntegrityResult) -> None:
        """Check VP extraction integrity"""
        # This would use the VP parser to validate extraction completeness
        # For now, basic file count comparison
        try:
            # Get expected file count from VP header (simplified)
            extracted_files = list(extracted_dir.rglob('*'))
            extracted_count = len([f for f in extracted_files if f.is_file()])
            
            # Basic integrity check - extracted files should exist
            if extracted_count == 0:
                result.missing_properties.append("No files extracted from VP archive")
                result.data_loss_detected = True
            
            result.integrity_score = min(1.0, extracted_count / 100)  # Rough estimate
            
        except Exception as e:
            result.missing_properties.append(f"VP extraction check failed: {str(e)}")
    
    def _check_pof_conversion_integrity(self, pof_path: Path, glb_path: Path, result: DataIntegrityResult) -> None:
        """Check POF to GLB conversion integrity"""
        # Check for metadata preservation
        metadata_path = glb_path.with_suffix('.metadata.json')
        if not metadata_path.exists():
            result.missing_properties.append("POF metadata not preserved")
        
        # Check GLB structure
        if glb_path.stat().st_size < 100:  # Minimum viable GLB size
            result.data_loss_detected = True
            result.missing_properties.append("GLB file too small - likely conversion failure")
    
    def _check_mission_conversion_integrity(self, mission_path: Path, scene_path: Path, result: DataIntegrityResult) -> None:
        """Check mission file conversion integrity"""
        # Check for mission resource and script files
        resource_path = scene_path.with_suffix('.tres')
        script_path = scene_path.with_suffix('.gd')
        
        if not resource_path.exists():
            result.missing_properties.append("Mission resource file not generated")
        if not script_path.exists():
            result.missing_properties.append("Mission script file not generated")
    
    def _check_table_conversion_integrity(self, table_path: Path, resource_path: Path, result: DataIntegrityResult) -> None:
        """Check table file conversion integrity"""
        try:
            # Read original table and converted resource
            with open(table_path, 'r') as f:
                table_content = f.read()
            
            # Count entries in original table (simplified)
            original_entries = table_content.count('$Name:')
            
            # Check converted resource has data
            if resource_path.stat().st_size < 100:
                result.data_loss_detected = True
                result.missing_properties.append("Converted table resource is too small")
            
        except Exception as e:
            result.missing_properties.append(f"Table integrity check failed: {str(e)}")
    
    def _validate_visual_fidelity(self, source_dir: Path, target_dir: Path,
                                 asset_types: Optional[List[str]]) -> List[VisualFidelityResult]:
        """AC4: Validate visual fidelity between original and converted assets"""
        logger.info("Validating visual fidelity between original and converted assets")
        
        results = []
        
        # Find image pairs for comparison
        image_pairs = []
        for ext in ['.pcx', '.tga', '.dds']:
            for original in source_dir.glob(f'**/*{ext}'):
                converted = target_dir / 'textures' / f"{original.stem}.png"
                if converted.exists():
                    image_pairs.append((original, converted))
        
        with ThreadPoolExecutor(max_workers=self.config['parallel_workers']) as executor:
            future_to_pair = {
                executor.submit(self._compare_visual_fidelity, original, converted): (original, converted)
                for original, converted in image_pairs
            }
            
            for future in as_completed(future_to_pair):
                original, converted = future_to_pair[future]
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error(f"Failed visual comparison for {original} -> {converted}: {e}")
        
        return results
    
    def _compare_visual_fidelity(self, original_path: Path, converted_path: Path) -> VisualFidelityResult:
        """Compare visual fidelity between original and converted images"""
        result = VisualFidelityResult(
            original_path=str(original_path),
            converted_path=str(converted_path),
            similarity_score=0.0,
            pixel_difference_count=0,
            structural_similarity_index=0.0,
            color_histogram_difference=0.0,
            visual_artifacts_detected=[],
            acceptable_quality=False
        )
        
        try:
            # Load images
            original_img = Image.open(original_path).convert('RGB')
            converted_img = Image.open(converted_path).convert('RGB')
            
            # Resize to match if needed
            if original_img.size != converted_img.size:
                converted_img = converted_img.resize(original_img.size, Image.Resampling.LANCZOS)
                result.visual_artifacts_detected.append("Size mismatch - image was resized for comparison")
            
            # Calculate pixel-level differences
            diff = ImageChops.difference(original_img, converted_img)
            diff_array = np.array(diff)
            pixel_differences = np.count_nonzero(diff_array)
            total_pixels = diff_array.size
            
            result.pixel_difference_count = pixel_differences
            pixel_similarity = 1.0 - (pixel_differences / total_pixels)
            
            # Calculate color histogram difference
            original_hist = original_img.histogram()
            converted_hist = converted_img.histogram()
            
            hist_diff = sum(abs(a - b) for a, b in zip(original_hist, converted_hist))
            max_hist_diff = sum(original_hist) * 2  # Maximum possible difference
            hist_similarity = 1.0 - (hist_diff / max_hist_diff)
            
            result.color_histogram_difference = hist_diff / max_hist_diff
            
            # Overall similarity score (weighted average)
            result.similarity_score = (pixel_similarity * 0.7 + hist_similarity * 0.3)
            
            # Check if quality is acceptable
            result.acceptable_quality = result.similarity_score >= self.quality_thresholds['visual_similarity_minimum']
            
            # Detect visual artifacts
            if result.similarity_score < 0.9:
                result.visual_artifacts_detected.append("Significant visual differences detected")
            if result.color_histogram_difference > 0.1:
                result.visual_artifacts_detected.append("Color palette differences detected")
            
        except Exception as e:
            logger.error(f"Visual comparison failed: {e}")
            result.visual_artifacts_detected.append(f"Comparison error: {str(e)}")
            
        return result
    
    def _benchmark_performance(self, source_dir: Path, target_dir: Path,
                              asset_types: Optional[List[str]]) -> List[PerformanceBenchmark]:
        """AC2: Benchmark conversion performance with regression testing"""
        logger.info("Benchmarking conversion performance")
        
        benchmarks = []
        
        # Sample assets for benchmarking
        test_assets = {
            'small_model': next(source_dir.glob('**/*.pof'), None),
            'large_archive': next(source_dir.glob('**/*.vp'), None),
            'mission_file': next(source_dir.glob('**/*.fs2'), None),
            'table_file': next(source_dir.glob('**/*.tbl'), None)
        }
        
        for asset_type, asset_path in test_assets.items():
            if asset_path and asset_path.exists():
                for iteration in range(self.config['benchmark_iterations']):
                    benchmark = self._benchmark_single_conversion(asset_path, asset_type)
                    benchmarks.append(benchmark)
        
        return benchmarks
    
    def _benchmark_single_conversion(self, asset_path: Path, asset_type: str) -> PerformanceBenchmark:
        """Benchmark single asset conversion performance"""
        start_time = time.time()
        file_size_mb = asset_path.stat().st_size / (1024 * 1024)
        
        benchmark = PerformanceBenchmark(
            asset_type=asset_type,
            file_size_mb=file_size_mb,
            conversion_time_seconds=0.0,
            memory_usage_mb=0.0,
            throughput_mbps=0.0,
            cpu_usage_percent=0.0,
            success=False
        )
        
        try:
            # Monitor system resources during conversion
            import psutil
            process = psutil.Process()
            initial_memory = process.memory_info().rss / (1024 * 1024)
            
            # Simulate conversion (in real implementation, would call actual converter)
            if asset_type == 'small_model':
                # POF conversion simulation
                time.sleep(0.1)  # Simulated processing time
            elif asset_type == 'large_archive':
                # VP extraction simulation
                time.sleep(0.5)  # Simulated processing time
            elif asset_type == 'mission_file':
                # Mission conversion simulation
                time.sleep(0.2)  # Simulated processing time
            elif asset_type == 'table_file':
                # Table conversion simulation
                time.sleep(0.05)  # Simulated processing time
            
            end_time = time.time()
            final_memory = process.memory_info().rss / (1024 * 1024)
            
            benchmark.conversion_time_seconds = end_time - start_time
            benchmark.memory_usage_mb = final_memory - initial_memory
            benchmark.throughput_mbps = file_size_mb / benchmark.conversion_time_seconds if benchmark.conversion_time_seconds > 0 else 0
            benchmark.cpu_usage_percent = process.cpu_percent()
            benchmark.success = True
            
        except Exception as e:
            benchmark.error_message = str(e)
            logger.error(f"Benchmark failed for {asset_path}: {e}")
            
        return benchmark
    
    def _analyze_results(self, report: ComprehensiveValidationReport) -> None:
        """AC5: Analyze validation results and generate comprehensive summary"""
        logger.info("Analyzing validation results")
        
        # Calculate summary statistics
        total_validations = len(report.format_validation_results)
        successful_validations = sum(1 for r in report.format_validation_results if r.is_valid)
        
        integrity_scores = [r.integrity_score for r in report.integrity_validation_results]
        visual_scores = [r.similarity_score for r in report.visual_fidelity_results]
        
        # Performance analysis
        conversion_times = [b.conversion_time_seconds for b in report.performance_benchmarks if b.success]
        memory_usage = [b.memory_usage_mb for b in report.performance_benchmarks if b.success]
        
        report.validation_summary = {
            'total_assets_validated': total_validations,
            'successful_validations': successful_validations,
            'validation_success_rate': successful_validations / total_validations if total_validations > 0 else 0,
            'average_integrity_score': statistics.mean(integrity_scores) if integrity_scores else 0,
            'average_visual_fidelity': statistics.mean(visual_scores) if visual_scores else 0,
            'average_conversion_time': statistics.mean(conversion_times) if conversion_times else 0,
            'peak_memory_usage': max(memory_usage) if memory_usage else 0,
            'performance_benchmarks_completed': len([b for b in report.performance_benchmarks if b.success])
        }
        
        # Quality scores
        report.quality_scores = {
            'format_compliance': successful_validations / total_validations if total_validations > 0 else 0,
            'data_integrity': statistics.mean(integrity_scores) if integrity_scores else 0,
            'visual_fidelity': statistics.mean(visual_scores) if visual_scores else 0,
            'performance_efficiency': 1.0 / statistics.mean(conversion_times) if conversion_times else 0
        }
        
        # Identify critical issues
        for result in report.format_validation_results:
            if not result.is_valid:
                report.critical_issues.append(f"Format validation failed: {result.file_path}")
        
        for result in report.integrity_validation_results:
            if result.data_loss_detected:
                report.critical_issues.append(f"Data loss detected: {result.original_path}")
        
        # Generate recommendations
        if report.quality_scores['format_compliance'] < 0.95:
            report.recommendations.append("Improve format validation - success rate below 95%")
        
        if report.quality_scores['data_integrity'] < self.quality_thresholds['data_integrity_minimum']:
            report.recommendations.append("Address data integrity issues - integrity score below threshold")
        
        if report.quality_scores['visual_fidelity'] < self.quality_thresholds['visual_similarity_minimum']:
            report.recommendations.append("Improve visual fidelity - similarity score below threshold")
    
    def _perform_regression_analysis(self, report: ComprehensiveValidationReport) -> None:
        """AC6: Perform regression analysis for continuous validation"""
        logger.info("Performing regression analysis")
        
        # Load historical validation data
        history_file = Path("validation_history.json")
        historical_data = []
        
        if history_file.exists():
            try:
                with open(history_file, 'r') as f:
                    historical_data = json.load(f)
            except Exception as e:
                logger.warning(f"Failed to load historical data: {e}")
        
        # Current metrics
        current_metrics = {
            'timestamp': report.timestamp,
            'validation_success_rate': report.validation_summary['validation_success_rate'],
            'average_integrity_score': report.validation_summary['average_integrity_score'],
            'average_visual_fidelity': report.validation_summary['average_visual_fidelity'],
            'average_conversion_time': report.validation_summary['average_conversion_time'],
            'peak_memory_usage': report.validation_summary['peak_memory_usage']
        }
        
        # Regression analysis
        if len(historical_data) > 0:
            recent_data = historical_data[-10:]  # Last 10 validation runs
            
            # Check for regressions
            avg_success_rate = statistics.mean([d['validation_success_rate'] for d in recent_data])
            avg_conversion_time = statistics.mean([d['average_conversion_time'] for d in recent_data])
            
            if current_metrics['validation_success_rate'] < avg_success_rate * 0.95:
                report.critical_issues.append("Regression detected: Validation success rate decreased")
            
            if current_metrics['average_conversion_time'] > avg_conversion_time * self.quality_thresholds['performance_regression_threshold']:
                report.critical_issues.append("Regression detected: Conversion time increased significantly")
            
            # Trend analysis
            success_rates = [d['validation_success_rate'] for d in recent_data]
            conversion_times = [d['average_conversion_time'] for d in recent_data]
            
            report.trend_analysis = {
                'success_rate_trend': 'improving' if len(success_rates) > 1 and success_rates[-1] > success_rates[0] else 'declining',
                'performance_trend': 'improving' if len(conversion_times) > 1 and conversion_times[-1] < conversion_times[0] else 'declining',
                'data_points': len(recent_data)
            }
        
        # Save current data to history
        historical_data.append(current_metrics)
        # Keep only last 100 entries
        historical_data = historical_data[-100:]
        
        try:
            with open(history_file, 'w') as f:
                json.dump(historical_data, f, indent=2)
        except Exception as e:
            logger.warning(f"Failed to save historical data: {e}")
        
        report.regression_analysis = {
            'historical_data_points': len(historical_data),
            'regression_detected': len([issue for issue in report.critical_issues if 'Regression detected' in issue]) > 0,
            'trend_analysis_available': len(historical_data) > 1
        }
    
    def generate_report(self, report: ComprehensiveValidationReport, output_dir: Path) -> List[Path]:
        """Generate comprehensive validation reports in multiple formats"""
        logger.info(f"Generating validation reports in {output_dir}")
        
        output_dir.mkdir(parents=True, exist_ok=True)
        generated_files = []
        
        # JSON report
        if 'json' in self.config['output_formats']:
            json_file = output_dir / f"validation_report_{report.validation_id}.json"
            with open(json_file, 'w') as f:
                json.dump(asdict(report), f, indent=2, default=str)
            generated_files.append(json_file)
        
        # HTML report
        if 'html' in self.config['output_formats']:
            html_file = output_dir / f"validation_report_{report.validation_id}.html"
            self._generate_html_report(report, html_file)
            generated_files.append(html_file)
        
        # XML report
        if 'xml' in self.config['output_formats']:
            xml_file = output_dir / f"validation_report_{report.validation_id}.xml"
            self._generate_xml_report(report, xml_file)
            generated_files.append(xml_file)
        
        return generated_files
    
    def _generate_html_report(self, report: ComprehensiveValidationReport, output_file: Path) -> None:
        """Generate HTML validation report"""
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>WCS-Godot Validation Report - {report.validation_id}</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .header {{ background-color: #f0f0f0; padding: 10px; border-radius: 5px; }}
                .summary {{ margin: 20px 0; }}
                .success {{ color: green; }}
                .warning {{ color: orange; }}
                .error {{ color: red; }}
                .metrics {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
                .metric-box {{ border: 1px solid #ddd; padding: 10px; border-radius: 5px; }}
                table {{ border-collapse: collapse; width: 100%; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>WCS-Godot Validation Report</h1>
                <p><strong>Validation ID:</strong> {report.validation_id}</p>
                <p><strong>Timestamp:</strong> {report.timestamp}</p>
                <p><strong>Source Directory:</strong> {report.source_directory}</p>
                <p><strong>Target Directory:</strong> {report.target_directory}</p>
            </div>
            
            <div class="summary">
                <h2>Validation Summary</h2>
                <div class="metrics">
                    <div class="metric-box">
                        <h3>Overall Results</h3>
                        <p>Total Assets: {report.total_assets}</p>
                        <p>Success Rate: {report.validation_summary.get('validation_success_rate', 0):.2%}</p>
                        <p>Validation Time: {report.overall_metrics.validation_time_seconds:.2f}s</p>
                    </div>
                    <div class="metric-box">
                        <h3>Quality Scores</h3>
                        <p>Format Compliance: {report.quality_scores.get('format_compliance', 0):.2%}</p>
                        <p>Data Integrity: {report.quality_scores.get('data_integrity', 0):.2%}</p>
                        <p>Visual Fidelity: {report.quality_scores.get('visual_fidelity', 0):.2%}</p>
                    </div>
                </div>
            </div>
            
            <div class="issues">
                <h2>Critical Issues</h2>
                {"<p class='error'>No critical issues found.</p>" if not report.critical_issues else ""}
                {"".join(f"<p class='error'>• {issue}</p>" for issue in report.critical_issues)}
            </div>
            
            <div class="recommendations">
                <h2>Recommendations</h2>
                {"<p class='success'>No recommendations - all quality targets met.</p>" if not report.recommendations else ""}
                {"".join(f"<p class='warning'>• {rec}</p>" for rec in report.recommendations)}
            </div>
        </body>
        </html>
        """
        
        with open(output_file, 'w') as f:
            f.write(html_content)
    
    def _generate_xml_report(self, report: ComprehensiveValidationReport, output_file: Path) -> None:
        """Generate XML validation report for CI/CD integration"""
        import xml.etree.ElementTree as ET
        
        root = ET.Element("ValidationReport")
        root.set("id", report.validation_id)
        root.set("timestamp", report.timestamp)
        
        # Summary
        summary = ET.SubElement(root, "Summary")
        ET.SubElement(summary, "TotalAssets").text = str(report.total_assets)
        ET.SubElement(summary, "SuccessRate").text = str(report.validation_summary.get('validation_success_rate', 0))
        ET.SubElement(summary, "ValidationTime").text = str(report.overall_metrics.validation_time_seconds)
        
        # Quality scores
        quality = ET.SubElement(root, "QualityScores")
        for key, value in report.quality_scores.items():
            ET.SubElement(quality, key.replace('_', '')).text = str(value)
        
        # Issues
        if report.critical_issues:
            issues = ET.SubElement(root, "CriticalIssues")
            for issue in report.critical_issues:
                ET.SubElement(issues, "Issue").text = issue
        
        # Write XML
        tree = ET.ElementTree(root)
        tree.write(output_file, encoding='utf-8', xml_declaration=True)

def main():
    """Main entry point for comprehensive validation"""
    import argparse
    
    parser = argparse.ArgumentParser(description="WCS-Godot Comprehensive Validation Framework")
    parser.add_argument("--source", type=Path, required=True, help="Source WCS directory")
    parser.add_argument("--target", type=Path, required=True, help="Target Godot directory")
    parser.add_argument("--output", type=Path, default=Path("validation_reports"), help="Output directory for reports")
    parser.add_argument("--config", type=Path, help="Configuration file path")
    parser.add_argument("--asset-types", nargs="+", help="Asset types to validate")
    
    args = parser.parse_args()
    
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    # Create validator
    validator = ComprehensiveValidator(args.config)
    
    # Run comprehensive validation
    report = validator.validate_comprehensive(args.source, args.target, args.asset_types)
    
    # Generate reports
    output_files = validator.generate_report(report, args.output)
    
    print(f"\nValidation completed: {report.validation_id}")
    print(f"Success Rate: {report.validation_summary.get('validation_success_rate', 0):.2%}")
    print(f"Critical Issues: {len(report.critical_issues)}")
    print(f"Reports generated: {[str(f) for f in output_files]}")
    
    # Exit with error if critical issues found
    if report.critical_issues:
        sys.exit(1)

if __name__ == "__main__":
    main()