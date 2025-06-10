#!/usr/bin/env python3
"""
WCS to Godot Asset Conversion Manager (Refactored)

Refactored conversion manager following SOLID principles.
Uses focused components with single responsibilities.

Author: Claude (Dev)
Date: June 10, 2025
Refactoring: Applied SOLID principles to improve maintainability
"""

import logging
from pathlib import Path
from typing import Dict, List, Optional, Any

from core.conversion.conversion_orchestrator import ConversionOrchestrator
from core.conversion.progress_tracker import ProgressStats

logger = logging.getLogger(__name__)

class ConversionManager:
    """
    Main entry point for WCS to Godot asset conversion.
    
    This class now follows the Single Responsibility Principle by delegating
    specific concerns to focused components:
    - ConversionOrchestrator: Overall workflow coordination
    - JobManager: Job lifecycle management  
    - ProgressTracker: Progress monitoring
    - AssetCatalog: Asset organization
    
    Responsibilities:
    - Provide simple interface for conversion operations
    - Configure and coordinate component interactions
    - Handle high-level error management
    """
    
    def __init__(self, wcs_source_dir: Path, godot_target_dir: Path):
        self.wcs_source_dir = Path(wcs_source_dir)
        self.godot_target_dir = Path(godot_target_dir)
        
        # Initialize the orchestrator (Dependency Injection)
        self.orchestrator = ConversionOrchestrator(wcs_source_dir, godot_target_dir)
        
        # Setup progress monitoring
        self.orchestrator.progress_tracker.add_progress_callback(self._on_progress_update)
        
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def convert_all_assets(self, dry_run: bool = False, validate: bool = True) -> bool:
        """
        Convert all WCS assets to Godot format.
        
        Args:
            dry_run: If True, show conversion plan without executing
            validate: If True, validate results after conversion
            
        Returns:
            True if conversion succeeded, False otherwise
        """
        try:
            self.logger.info("Starting WCS to Godot conversion")
            self.logger.info(f"Source: {self.wcs_source_dir}")
            self.logger.info(f"Target: {self.godot_target_dir}")
            
            # Validate inputs
            if not self._validate_directories():
                return False
            
            # Execute conversion
            success = self.orchestrator.convert_all_assets(dry_run=dry_run)
            
            if success and not dry_run:
                self.logger.info("✅ Conversion completed successfully")
            elif not success:
                self.logger.error("❌ Conversion failed")
            
            return success
            
        except Exception as e:
            self.logger.error(f"Conversion manager error: {e}")
            return False
    
    def get_conversion_status(self) -> Dict[str, Any]:
        """Get current conversion status and progress"""
        return self.orchestrator.get_conversion_status()
    
    def add_progress_callback(self, callback) -> None:
        """Add a callback for progress updates"""
        self.orchestrator.progress_tracker.add_progress_callback(callback)
    
    def _validate_directories(self) -> bool:
        """Validate source and target directories"""
        if not self.wcs_source_dir.exists():
            self.logger.error(f"WCS source directory not found: {self.wcs_source_dir}")
            return False
        
        if not self.wcs_source_dir.is_dir():
            self.logger.error(f"WCS source path is not a directory: {self.wcs_source_dir}")
            return False
        
        # Create target directory if it doesn't exist
        try:
            self.godot_target_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            self.logger.error(f"Failed to create target directory: {e}")
            return False
        
        return True
    
    def _on_progress_update(self, stats: ProgressStats) -> None:
        """Handle progress updates from orchestrator"""
        if stats.overall_progress > 0:
            self.logger.info(f"Conversion progress: {stats.overall_progress:.1f}% "
                           f"({stats.completed_jobs}/{stats.total_jobs} jobs)")


# Backward compatibility wrapper
class LegacyConversionManager(ConversionManager):
    """
    Backward compatibility wrapper for existing code.
    
    Provides the same interface as the original ConversionManager
    while using the new refactored implementation.
    """
    
    def __init__(self, wcs_source_dir: Path, godot_target_dir: Path):
        super().__init__(wcs_source_dir, godot_target_dir)
        self.logger.info("Using refactored conversion manager with SOLID principles")
    
    # Add any legacy method signatures here if needed for compatibility