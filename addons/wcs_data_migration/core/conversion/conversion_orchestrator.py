#!/usr/bin/env python3
"""
Conversion Orchestrator

Single Responsibility: Orchestrate the overall conversion workflow
Coordinates between different converters following SOLID principles.
"""

import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

from ..catalog.asset_catalog import AssetCatalog
from .job_manager import ConversionJob, JobManager
from .progress_tracker import ProgressTracker

logger = logging.getLogger(__name__)

class ConversionOrchestrator:
    """
    Main conversion orchestrator following Single Responsibility Principle.
    
    Responsibilities:
    - Coordinate overall conversion workflow
    - Manage conversion phases (VP extraction → core assets → dependent assets)
    - Provide unified interface for conversion operations
    """
    
    def __init__(self, wcs_source_dir: Path, godot_target_dir: Path):
        self.wcs_source_dir = Path(wcs_source_dir)
        self.godot_target_dir = Path(godot_target_dir)
        
        # Initialize components (Dependency Injection)
        self.job_manager = JobManager()
        self.progress_tracker = ProgressTracker()
        self.asset_catalog = AssetCatalog(godot_target_dir / "asset_catalog.db")
        
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def convert_all_assets(self, dry_run: bool = False) -> bool:
        """
        Convert all WCS assets to Godot format.
        
        Template Method pattern implementation:
        1. Scan assets
        2. Create conversion plan
        3. Execute conversion phases
        4. Validate results
        """
        try:
            self.logger.info("Starting WCS to Godot asset conversion")
            
            # Phase 1: Scan and plan
            assets = self._scan_wcs_assets()
            jobs = self._create_conversion_plan(assets)
            
            if dry_run:
                return self._show_conversion_plan(jobs)
            
            # Phase 2: Execute conversion
            self.progress_tracker.start_conversion(len(jobs))
            success = self._execute_conversion_phases(jobs)
            
            # Phase 3: Validate and catalog
            if success:
                success = self._validate_and_catalog_results()
            
            self.progress_tracker.complete_conversion(success)
            return success
            
        except Exception as e:
            self.logger.error(f"Conversion failed: {e}")
            return False
    
    def _scan_wcs_assets(self) -> Dict[str, List[Path]]:
        """Scan WCS directory for convertible assets"""
        self.logger.info("Scanning WCS assets...")
        
        assets = {
            'vp_archives': list(self.wcs_source_dir.glob("*.vp")),
            'pof_models': list(self.wcs_source_dir.rglob("*.pof")),
            'mission_files': list(self.wcs_source_dir.rglob("*.fs2")) + 
                           list(self.wcs_source_dir.rglob("*.fc2")),
            'table_files': list(self.wcs_source_dir.rglob("*.tbl")),
            'config_files': list(self.wcs_source_dir.rglob("*.cfg"))
        }
        
        total_assets = sum(len(files) for files in assets.values())
        self.logger.info(f"Found {total_assets} assets to convert")
        
        return assets
    
    def _create_conversion_plan(self, assets: Dict[str, List[Path]]) -> List[ConversionJob]:
        """Create prioritized conversion plan with dependencies"""
        return self.job_manager.create_conversion_plan(assets, self.godot_target_dir)
    
    def _execute_conversion_phases(self, jobs: List[ConversionJob]) -> bool:
        """Execute conversion in phases based on dependencies"""
        return self.job_manager.execute_jobs(jobs, self.progress_tracker)
    
    def _validate_and_catalog_results(self) -> bool:
        """Validate conversion results and update asset catalog"""
        self.logger.info("Validating conversion results...")
        
        # Update asset catalog with converted assets
        self.asset_catalog.scan_directory(self.godot_target_dir)
        
        # TODO: Add validation logic
        return True
    
    def _show_conversion_plan(self, jobs: List[ConversionJob]) -> bool:
        """Show conversion plan for dry run"""
        self.logger.info("Conversion Plan (Dry Run):")
        self.logger.info("=" * 50)
        
        for job in jobs:
            self.logger.info(f"  {job.conversion_type}: {job.source_path.name}")
            self.logger.info(f"    → {job.target_path}")
            self.logger.info(f"    Priority: {job.priority}")
            if job.dependencies:
                self.logger.info(f"    Dependencies: {', '.join(job.dependencies)}")
            self.logger.info("")
        
        total_jobs = len(jobs)
        self.logger.info(f"Total conversion jobs: {total_jobs}")
        
        return True
    
    def get_conversion_status(self) -> Dict[str, Any]:
        """Get current conversion status"""
        return {
            'progress': self.progress_tracker.get_progress(),
            'active_jobs': self.job_manager.get_active_jobs(),
            'completed_jobs': self.job_manager.get_completed_jobs(),
            'failed_jobs': self.job_manager.get_failed_jobs()
        }