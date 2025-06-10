#!/usr/bin/env python3
"""
WCS to Godot Asset Conversion Manager

This module orchestrates the conversion of all WCS assets to Godot-compatible formats
following the EPIC-003 architecture design.

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-003 - Asset Organization and Cataloging
Architecture: EPIC-003 - Data Migration & Conversion Tools
"""

import argparse
import hashlib
import json
import logging
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
from asset_catalog import AssetCatalog
from config_migrator import ConfigMigrator

logger = logging.getLogger(__name__)

@dataclass
class ConversionJob:
    """Represents a single conversion task"""
    source_path: Path
    target_path: Path
    conversion_type: str
    priority: int
    dependencies: List[str]
    status: str = "pending"
    progress: float = 0.0
    error_message: Optional[str] = None
    file_hash: Optional[str] = None
    duplicate_of: Optional[str] = None

class ConversionManager:
    """
    Main conversion orchestrator following EPIC-003 architecture.
    
    Manages the complete WCS to Godot conversion pipeline with proper
    dependency resolution, progress tracking, and validation.
    """
    
    def __init__(self, wcs_source_dir: Path, godot_target_dir: Path):
        """
        Initialize conversion manager.
        
        Args:
            wcs_source_dir: Path to WCS source directory
            godot_target_dir: Path to Godot project directory
        """
        self.wcs_source_dir = Path(wcs_source_dir)
        self.godot_target_dir = Path(godot_target_dir)
        self.conversion_queue: List[ConversionJob] = []
        self.completed_jobs: List[ConversionJob] = []
        self.failed_jobs: List[ConversionJob] = []
        
        # Initialize duplicate detection
        self.file_hash_manifest: Dict[str, str] = {}  # hash -> target_path
        self.duplicate_files: List[ConversionJob] = []
        
        # Initialize asset catalog
        catalog_path = self.godot_target_dir / "asset_catalog.json"
        self.asset_catalog = AssetCatalog(str(catalog_path))
        
        # Initialize configuration migrator
        self.config_migrator = ConfigMigrator()
        
        # Initialize asset relationship mapper
        self.asset_mapper = None
        self._init_asset_mapper()
        
        # Initialize converters (will be imported dynamically)
        self.converters = {}
        self._load_converters()
    
    def _load_converters(self) -> None:
        """Load all available converters"""
        try:
            # Import converters from migration_tools (existing)
            sys.path.append(str(self.godot_target_dir / "migration_tools"))
            
            from vp_extractor import VPIndex
            from converters.dds_converter import DDSConverter
            from converters.pcx_converter import PCXConverter
            from converters.pof_converter import POFConverter
            
            self.converters = {
                'vp_extraction': VPIndex,
                'texture_dds': DDSConverter,
                'texture_pcx': PCXConverter,
                'pof_model': POFConverter
            }
            
            logger.info(f"Loaded {len(self.converters)} converters")
            
        except ImportError as e:
            logger.warning(f"Could not load some converters: {e}")
    
    def _init_asset_mapper(self) -> None:
        """Initialize asset relationship mapper"""
        try:
            from asset_relationship_mapper import AssetRelationshipMapper
            
            # Load target structure from assets/CLAUDE.md definition
            target_structure = {
                'campaigns': 'campaigns/wing_commander_saga',
                'common': 'common',
                'ships': 'ships', 
                'weapons': 'weapons'
            }
            
            self.asset_mapper = AssetRelationshipMapper(self.wcs_source_dir, target_structure)
            logger.info("Asset relationship mapper initialized")
            
        except ImportError as e:
            logger.warning(f"Could not load asset relationship mapper: {e}")
    
    def scan_wcs_assets(self) -> Dict[str, List[Path]]:
        """
        Scan WCS directory for convertible assets.
        
        Returns:
            Dictionary mapping asset types to file lists
        """
        logger.info(f"Scanning WCS assets in: {self.wcs_source_dir}")
        
        if not self.wcs_source_dir.exists():
            logger.error(f"WCS source directory does not exist: {self.wcs_source_dir}")
            return {}
        
        assets = {
            'vp_archives': list(self.wcs_source_dir.rglob('*.vp')),
            'pof_models': list(self.wcs_source_dir.rglob('*.pof')),
            'missions': list(self.wcs_source_dir.rglob('*.fs2')),
            'textures_dds': list(self.wcs_source_dir.rglob('*.dds')),
            'textures_pcx': list(self.wcs_source_dir.rglob('*.pcx')),
            'textures_tga': list(self.wcs_source_dir.rglob('*.tga')),
            'textures_png': list(self.wcs_source_dir.rglob('*.png')),
            'textures_jpg': list(self.wcs_source_dir.rglob('*.jpg')),
            'audio_wav': list(self.wcs_source_dir.rglob('*.wav')),
            'audio_ogg': list(self.wcs_source_dir.rglob('*.ogg')),
            'video_mve': list(self.wcs_source_dir.rglob('*.mve')),
            'video_avi': list(self.wcs_source_dir.rglob('*.avi')),
            'tables': list(self.wcs_source_dir.rglob('*.tbl')),
            'scripts': list(self.wcs_source_dir.rglob('*.lua'))
        }
        
        # Log findings
        total_assets = sum(len(asset_list) for asset_list in assets.values())
        logger.info(f"Found {total_assets} assets to convert:")
        for asset_type, asset_list in assets.items():
            if asset_list:
                logger.info(f"  {asset_type}: {len(asset_list)} files")
        
        return assets
    
    def create_conversion_plan(self, assets: Dict[str, List[Path]]) -> List[ConversionJob]:
        """
        Create ordered conversion plan with proper dependencies.
        
        Args:
            assets: Dictionary of asset types to file lists
            
        Returns:
            Ordered list of conversion jobs
        """
        logger.info("Creating conversion plan...")
        jobs = []
        
        # Phase 1: Extract VP archives (highest priority - enables other conversions)
        logger.debug("Phase 1: VP Archive Extraction")
        for vp_file in assets.get('vp_archives', []):
            job = ConversionJob(
                source_path=vp_file,
                target_path=self.godot_target_dir / "extracted" / vp_file.stem,
                conversion_type="vp_extraction",
                priority=1,
                dependencies=[]
            )
            jobs.append(job)
        
        # Phase 2: Convert core assets (depends on VP extraction)
        logger.debug("Phase 2: Core Asset Conversion")
        vp_deps = [f"vp_extraction:{vp.stem}" for vp in assets.get('vp_archives', [])]
        
        # Textures (various formats)
        texture_types = ['textures_dds', 'textures_pcx', 'textures_tga', 'textures_png', 'textures_jpg']
        for texture_type in texture_types:
            for texture_file in assets.get(texture_type, []):
                target_format = 'png'  # Standard conversion target
                job = ConversionJob(
                    source_path=texture_file,
                    target_path=self.godot_target_dir / "assets" / "textures" / f"{texture_file.stem}.{target_format}",
                    conversion_type=f"texture_{texture_file.suffix[1:]}",
                    priority=2,
                    dependencies=vp_deps if any(vp_file.name in str(texture_file) for vp_file in assets.get('vp_archives', [])) else []
                )
                jobs.append(job)
        
        # POF models
        for pof_file in assets.get('pof_models', []):
            job = ConversionJob(
                source_path=pof_file,
                target_path=self.godot_target_dir / "assets" / "models" / f"{pof_file.stem}.glb",
                conversion_type="pof_model",
                priority=2,
                dependencies=vp_deps
            )
            jobs.append(job)
        
        # Audio files
        audio_types = ['audio_wav', 'audio_ogg']
        for audio_type in audio_types:
            for audio_file in assets.get(audio_type, []):
                job = ConversionJob(
                    source_path=audio_file,
                    target_path=self.godot_target_dir / "assets" / "audio" / audio_file.name,
                    conversion_type=f"audio_{audio_file.suffix[1:]}",
                    priority=2,
                    dependencies=vp_deps if any(vp_file.name in str(audio_file) for vp_file in assets.get('vp_archives', [])) else []
                )
                jobs.append(job)
        
        # Phase 3: Convert content that depends on models/textures
        logger.debug("Phase 3: Dependent Asset Conversion")
        asset_deps = vp_deps + [f"pof_model:{pof.stem}" for pof in assets.get('pof_models', [])]
        
        # Configuration migration (early in phase 3, independent)
        config_job = ConversionJob(
            source_path=self.wcs_source_dir,
            target_path=self.godot_target_dir,
            conversion_type="config_migration",
            priority=3,
            dependencies=[]  # Configuration is independent
        )
        jobs.append(config_job)
        
        # Mission files
        for mission_file in assets.get('missions', []):
            job = ConversionJob(
                source_path=mission_file,
                target_path=self.godot_target_dir / "assets" / "missions" / f"{mission_file.stem}.tres",
                conversion_type="mission",
                priority=3,
                dependencies=asset_deps
            )
            jobs.append(job)
        
        # Table files
        for table_file in assets.get('tables', []):
            job = ConversionJob(
                source_path=table_file,
                target_path=self.godot_target_dir / "assets" / "tables" / f"{table_file.stem}.tres",
                conversion_type="table",
                priority=3,
                dependencies=[]  # Tables are generally independent
            )
            jobs.append(job)
        
        # Sort by priority and name for consistent ordering
        jobs.sort(key=lambda x: (x.priority, x.source_path.name))
        
        logger.info(f"Created conversion plan with {len(jobs)} jobs across 3 phases")
        return jobs
    
    def generate_asset_mapping(self, output_path: Optional[Path] = None) -> Optional[Dict[str, Any]]:
        """
        Generate comprehensive asset mapping using AssetRelationshipMapper.
        
        Args:
            output_path: Optional path to save the mapping JSON file
            
        Returns:
            Project mapping dictionary if successful, None otherwise
        """
        if not self.asset_mapper:
            logger.error("Asset relationship mapper not available")
            return None
        
        try:
            logger.info("Generating comprehensive asset mapping...")
            project_mapping = self.asset_mapper.generate_project_mapping()
            
            if output_path:
                success = self.asset_mapper.save_mapping_json(project_mapping, output_path)
                if success:
                    logger.info(f"Asset mapping saved to: {output_path}")
                else:
                    logger.error(f"Failed to save asset mapping to: {output_path}")
            
            return project_mapping
            
        except Exception as e:
            logger.error(f"Failed to generate asset mapping: {e}")
            return None
    
    def _check_dependencies_satisfied(self, job: ConversionJob) -> bool:
        """Check if job dependencies are satisfied"""
        if not job.dependencies:
            return True
        
        for dep in job.dependencies:
            # Check if dependency job is completed
            dep_found = False
            for completed_job in self.completed_jobs:
                dep_key = f"{completed_job.conversion_type}:{completed_job.source_path.stem}"
                if dep_key == dep:
                    dep_found = True
                    break
            
            if not dep_found:
                return False
        
        return True
    
    def _calculate_file_hash(self, file_path: Path) -> str:
        """Calculate SHA256 hash of file content"""
        try:
            with open(file_path, 'rb') as f:
                file_hash = hashlib.sha256()
                # Read file in chunks to handle large files efficiently
                for chunk in iter(lambda: f.read(8192), b""):
                    file_hash.update(chunk)
                return file_hash.hexdigest()
        except Exception as e:
            logger.warning(f"Failed to calculate hash for {file_path}: {e}")
            return ""
    
    def _check_duplicate_file(self, job: ConversionJob) -> bool:
        """
        Check if file is duplicate and handle accordingly.
        
        Returns:
            True if file should be skipped (is duplicate), False if should be processed
        """
        # Skip duplicate detection for certain job types
        skip_types = {"vp_extraction", "config_migration", "table", "mission"}
        if job.conversion_type in skip_types:
            return False
        
        # Calculate file hash
        file_hash = self._calculate_file_hash(job.source_path)
        if not file_hash:
            return False  # Process file if hash calculation failed
        
        job.file_hash = file_hash
        
        # Check if we've seen this hash before
        if file_hash in self.file_hash_manifest:
            original_target = self.file_hash_manifest[file_hash]
            job.duplicate_of = original_target
            job.status = "skipped_duplicate"
            job.progress = 1.0
            
            # Log duplicate detection
            logger.info(f"SKIPPED: Duplicate of '{original_target}': {job.source_path.name}")
            self.duplicate_files.append(job)
            return True
        
        # Register this file hash
        self.file_hash_manifest[file_hash] = str(job.target_path)
        return False
    
    def _execute_single_job(self, job: ConversionJob) -> bool:
        """Execute a single conversion job"""
        try:
            # Check for duplicate files before processing
            if self._check_duplicate_file(job):
                return True  # File was skipped as duplicate
            
            logger.info(f"Starting conversion: {job.source_path.name} -> {job.conversion_type}")
            job.status = "in_progress"
            
            # Create target directory
            job.target_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Execute conversion based on type
            success = False
            
            if job.conversion_type == "vp_extraction":
                success = self._execute_vp_extraction(job)
            elif job.conversion_type.startswith("texture_"):
                success = self._execute_texture_conversion(job)
            elif job.conversion_type == "pof_model":
                success = self._execute_pof_conversion(job)
            elif job.conversion_type.startswith("audio_"):
                success = self._execute_audio_conversion(job)
            elif job.conversion_type == "mission":
                success = self._execute_mission_conversion(job)
            elif job.conversion_type == "table":
                success = self._execute_table_conversion(job)
            elif job.conversion_type == "config_migration":
                success = self._execute_config_migration(job)
            else:
                logger.warning(f"Unknown conversion type: {job.conversion_type}")
                success = False
            
            if success:
                job.status = "completed"
                job.progress = 1.0
                logger.info(f"Completed conversion: {job.source_path.name}")
            else:
                job.status = "failed"
                job.error_message = f"Conversion failed for type: {job.conversion_type}"
                logger.error(f"Failed conversion: {job.source_path.name}")
            
            return success
            
        except Exception as e:
            job.status = "failed"
            job.error_message = str(e)
            logger.error(f"Error converting {job.source_path.name}: {e}")
            return False
    
    def _execute_vp_extraction(self, job: ConversionJob) -> bool:
        """Execute VP archive extraction"""
        try:
            if 'vp_extraction' in self.converters:
                with self.converters['vp_extraction']() as vp:
                    if vp.parse(str(job.source_path)):
                        return vp.extract_all(str(job.target_path.parent))
            return False
        except Exception as e:
            logger.error(f"VP extraction failed: {e}")
            return False
    
    def _execute_texture_conversion(self, job: ConversionJob) -> bool:
        """Execute texture conversion"""
        try:
            # Copy file for now (proper conversion would use specific converters)
            import shutil
            shutil.copy2(job.source_path, job.target_path)
            return True
        except Exception as e:
            logger.error(f"Texture conversion failed: {e}")
            return False
    
    def _execute_pof_conversion(self, job: ConversionJob) -> bool:
        """Execute POF model conversion"""
        try:
            # Placeholder - would use POF converter
            logger.warning(f"POF conversion not yet implemented: {job.source_path}")
            return False
        except Exception as e:
            logger.error(f"POF conversion failed: {e}")
            return False
    
    def _execute_audio_conversion(self, job: ConversionJob) -> bool:
        """Execute audio conversion"""
        try:
            # Copy file for now (audio files often don't need conversion)
            import shutil
            shutil.copy2(job.source_path, job.target_path)
            return True
        except Exception as e:
            logger.error(f"Audio conversion failed: {e}")
            return False
    
    def _execute_mission_conversion(self, job: ConversionJob) -> bool:
        """Execute mission file conversion"""
        try:
            # Placeholder - would use mission converter
            logger.warning(f"Mission conversion not yet implemented: {job.source_path}")
            return False
        except Exception as e:
            logger.error(f"Mission conversion failed: {e}")
            return False
    
    def _execute_table_conversion(self, job: ConversionJob) -> bool:
        """Execute table file conversion using TableDataConverter"""
        try:
            from table_data_converter import TableDataConverter
            
            # Initialize table converter
            converter = TableDataConverter(
                source_dir=self.wcs_source_dir,
                target_dir=self.godot_target_dir
            )
            
            # Convert the specific table file
            success = converter.convert_table_file(job.source_path)
            
            if success:
                logger.info(f"Successfully converted table file: {job.source_path}")
                return True
            else:
                logger.error(f"Failed to convert table file: {job.source_path}")
                return False
                
        except Exception as e:
            logger.error(f"Table conversion failed for {job.source_path}: {e}")
            return False
    
    def _execute_config_migration(self, job: ConversionJob) -> bool:
        """Execute WCS configuration migration to Godot format"""
        try:
            logger.info(f"Starting WCS configuration migration from {job.source_path} to {job.target_path}")
            
            # Execute configuration migration
            success = self.config_migrator.migrate_wcs_configuration(
                wcs_source_dir=job.source_path,
                godot_target_dir=job.target_path
            )
            
            if success:
                logger.info("Configuration migration completed successfully")
                return True
            else:
                logger.error("Configuration migration failed")
                return False
                
        except Exception as e:
            logger.error(f"Configuration migration failed: {e}")
            return False
    
    def execute_conversion_plan(self, jobs: List[ConversionJob], 
                              max_workers: int = 4) -> Tuple[int, int, int, int]:
        """
        Execute conversion plan with parallel processing.
        
        Args:
            jobs: List of conversion jobs to execute
            max_workers: Maximum number of parallel workers
            
        Returns:
            Tuple of (completed_count, failed_count, skipped_count, total_count)
        """
        logger.info(f"Starting conversion with {max_workers} parallel workers")
        completed_count = 0
        failed_count = 0
        skipped_count = 0
        total_count = len(jobs)
        
        # Group jobs by priority for sequential execution of phases
        priority_groups = {}
        for job in jobs:
            if job.priority not in priority_groups:
                priority_groups[job.priority] = []
            priority_groups[job.priority].append(job)
        
        # Execute each priority group sequentially
        for priority in sorted(priority_groups.keys()):
            group_jobs = priority_groups[priority]
            logger.info(f"Executing priority {priority} jobs: {len(group_jobs)} jobs")
            
            # For VP extraction (priority 1), run sequentially
            if priority == 1:
                for job in group_jobs:
                    if self._check_dependencies_satisfied(job):
                        success = self._execute_single_job(job)
                        if success:
                            if job.status == "skipped_duplicate":
                                skipped_count += 1
                            else:
                                completed_count += 1
                                self.completed_jobs.append(job)
                        else:
                            failed_count += 1
                            self.failed_jobs.append(job)
            else:
                # For other priorities, use thread pool
                with ThreadPoolExecutor(max_workers=max_workers) as executor:
                    futures = []
                    for job in group_jobs:
                        if self._check_dependencies_satisfied(job):
                            future = executor.submit(self._execute_single_job, job)
                            futures.append((future, job))
                    
                    # Wait for all jobs in this priority group
                    for future, job in futures:
                        try:
                            result = future.result()
                            if result:
                                if job.status == "skipped_duplicate":
                                    skipped_count += 1
                                else:
                                    completed_count += 1
                                    self.completed_jobs.append(job)
                            else:
                                failed_count += 1
                                self.failed_jobs.append(job)
                        except Exception as e:
                            failed_count += 1
                            job.status = "failed"
                            job.error_message = str(e)
                            self.failed_jobs.append(job)
                            logger.error(f"Job execution error: {e}")
        
        logger.info(f"Conversion completed: {completed_count}/{total_count} successful, {failed_count} failed, {skipped_count} duplicates skipped")
        return completed_count, failed_count, skipped_count, total_count
    
    def catalog_converted_assets(self) -> None:
        """Catalog all converted assets using the asset catalog system"""
        logger.info("Cataloging converted assets...")
        
        # Scan the assets directory
        assets_dir = self.godot_target_dir / "assets"
        if assets_dir.exists():
            count = self.asset_catalog.scan_directory(assets_dir)
            logger.info(f"Cataloged {count} converted assets")
            
            # Validate assets
            issues = self.asset_catalog.validate_assets()
            logger.info(f"Found {len(issues)} validation issues")
            
            # Save catalog
            self.asset_catalog.save_catalog()
            logger.info("Asset catalog saved")
        else:
            logger.warning(f"Assets directory not found: {assets_dir}")
    
    def generate_conversion_report(self) -> Dict:
        """Generate comprehensive conversion report"""
        total_processed = len(self.completed_jobs) + len(self.failed_jobs) + len(self.duplicate_files)
        
        report = {
            'conversion_summary': {
                'total_jobs': total_processed,
                'completed': len(self.completed_jobs),
                'failed': len(self.failed_jobs),
                'duplicates_skipped': len(self.duplicate_files),
                'success_rate': len(self.completed_jobs) / max(1, len(self.completed_jobs) + len(self.failed_jobs))
            },
            'duplicate_detection': {
                'duplicates_found': len(self.duplicate_files),
                'space_saved_estimate': f"{len(self.duplicate_files)} files",
                'duplicate_files': [
                    {
                        'source': str(job.source_path),
                        'duplicate_of': job.duplicate_of,
                        'file_hash': job.file_hash
                    }
                    for job in self.duplicate_files
                ]
            },
            'asset_catalog_summary': self.asset_catalog.generate_manifest(),
            'failed_conversions': [
                {
                    'source': str(job.source_path),
                    'target': str(job.target_path),
                    'type': job.conversion_type,
                    'error': job.error_message
                }
                for job in self.failed_jobs
            ]
        }
        
        return report

def main():
    """Main function for command-line usage"""
    parser = argparse.ArgumentParser(description='Convert WCS assets to Godot format')
    parser.add_argument('--source', type=Path, required=True, 
                       help='Path to WCS source directory')
    parser.add_argument('--target', type=Path, required=True,
                       help='Path to Godot project directory')
    parser.add_argument('--jobs', type=int, default=4,
                       help='Number of parallel conversion jobs')
    parser.add_argument('--validate', action='store_true',
                       help='Run validation after conversion')
    parser.add_argument('--catalog-only', action='store_true',
                       help='Only catalog existing assets without conversion')
    parser.add_argument('--mapping-only', action='store_true',
                       help='Only generate asset mapping without conversion')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show conversion plan without executing')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose output')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(args.target / 'wcs_conversion.log'),
            logging.StreamHandler()
        ]
    )
    
    try:
        # Initialize conversion manager
        converter = ConversionManager(args.source, args.target)
        
        if args.catalog_only:
            # Only catalog existing assets
            converter.catalog_converted_assets()
            print("Asset cataloging completed")
            return 0
        
        if args.mapping_only:
            # Only generate asset mapping
            mapping_path = args.target / "project_mapping.json"
            print("Generating asset relationship mapping...")
            mapping = converter.generate_asset_mapping(mapping_path)
            if mapping:
                print(f"Asset mapping generated successfully!")
                print(f"Entities: {mapping['metadata']['total_entities']}")
                print(f"Assets: {mapping['metadata']['total_assets']}")
                print(f"Ships: {mapping['statistics']['ships']}")
                print(f"Weapons: {mapping['statistics']['weapons']}")
                print(f"Mapping saved to: {mapping_path}")
            else:
                print("Failed to generate asset mapping")
                return 1
            return 0
        
        # Scan for assets
        print("Scanning WCS assets...")
        assets = converter.scan_wcs_assets()
        
        total_assets = sum(len(asset_list) for asset_list in assets.values())
        print(f"Found {total_assets} assets to convert:")
        for asset_type, asset_list in assets.items():
            if asset_list:
                print(f"  {asset_type}: {len(asset_list)} files")
        
        # Create conversion plan
        print("\nCreating conversion plan...")
        conversion_jobs = converter.create_conversion_plan(assets)
        
        if args.dry_run:
            print(f"\nConversion plan ({len(conversion_jobs)} jobs):")
            for i, job in enumerate(conversion_jobs[:10]):  # Show first 10
                print(f"  {i+1}. {job.conversion_type}: {job.source_path.name} -> {job.target_path.name}")
            if len(conversion_jobs) > 10:
                print(f"  ... and {len(conversion_jobs) - 10} more jobs")
            return 0
        
        # Execute conversion
        print(f"\nStarting conversion with {args.jobs} parallel jobs...")
        completed, failed, skipped, total = converter.execute_conversion_plan(conversion_jobs, args.jobs)
        
        print(f"\nConversion completed: {completed}/{total} successful, {failed} failed, {skipped} duplicates skipped")
        
        # Catalog converted assets
        print("\nCataloging converted assets...")
        converter.catalog_converted_assets()
        
        # Generate report
        report = converter.generate_conversion_report()
        report_path = args.target / "conversion_report.json"
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"Conversion report saved to: {report_path}")
        print("\nConversion process finished!")
        
        return 0 if failed == 0 else 1
        
    except Exception as e:
        logger.error(f"Conversion failed: {e}")
        return 1

if __name__ == '__main__':
    exit(main())