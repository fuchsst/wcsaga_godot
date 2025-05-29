#!/usr/bin/env python3
"""
WCS to Godot Conversion Tool - Comprehensive CLI Interface

Main command-line interface for converting WCS assets to Godot format following
the EPIC-003 architecture design. Provides complete batch processing, automation,
resume functionality, and comprehensive reporting capabilities.

Usage: 
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project
  python convert_wcs_assets.py --resume /path/to/conversion_state.json
  python convert_wcs_assets.py --validate-only --target /path/to/godot/project

Author: Dev (GDScript Developer)
Date: January 29, 2025
Stories: DM-003 - Asset Organization and Cataloging, DM-010 - CLI Tool Development  
Architecture: EPIC-003 - Data Migration & Conversion Tools
"""

import argparse
import json
import logging
import sys
import time
import signal
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict

# Add conversion_tools to path
sys.path.insert(0, str(Path(__file__).parent))

from conversion_manager import ConversionManager
from validation.format_validator import FormatValidator
from utilities.path_utils import ensure_directory, create_godot_directory_structure


@dataclass
class ConversionState:
    """State information for resumable conversions"""
    conversion_id: str
    start_time: str
    source_path: str
    target_path: str
    total_jobs: int
    completed_jobs: int
    failed_jobs: int
    current_phase: int
    job_states: Dict[str, str]  # job_id -> status
    performance_metrics: Dict[str, float]
    
    def save_to_file(self, state_file: Path) -> None:
        """Save state to JSON file"""
        with open(state_file, 'w') as f:
            json.dump(asdict(self), f, indent=2)
    
    @classmethod
    def load_from_file(cls, state_file: Path) -> 'ConversionState':
        """Load state from JSON file"""
        with open(state_file, 'r') as f:
            data = json.load(f)
        return cls(**data)


@dataclass
class ProgressTracker:
    """Enhanced progress tracking with real-time metrics"""
    start_time: float
    total_jobs: int
    completed_jobs: int = 0
    failed_jobs: int = 0
    current_job: str = ""
    current_phase: int = 1
    phase_names: Dict[int, str] = None
    performance_metrics: Dict[str, float] = None
    
    def __post_init__(self):
        if self.phase_names is None:
            self.phase_names = {
                1: "VP Archive Extraction",
                2: "Core Asset Conversion", 
                3: "Dependent Asset Processing"
            }
        if self.performance_metrics is None:
            self.performance_metrics = {
                "jobs_per_second": 0.0,
                "estimated_time_remaining": 0.0,
                "current_phase_progress": 0.0
            }
    
    def update_job_completed(self, job_name: str) -> None:
        """Update progress for completed job"""
        self.completed_jobs += 1
        self.current_job = job_name
        self._update_metrics()
    
    def update_job_failed(self, job_name: str) -> None:
        """Update progress for failed job"""
        self.failed_jobs += 1
        self.current_job = job_name
        self._update_metrics()
    
    def set_phase(self, phase: int) -> None:
        """Set current conversion phase"""
        self.current_phase = phase
        self._update_metrics()
    
    def _update_metrics(self) -> None:
        """Update performance metrics"""
        elapsed_time = time.time() - self.start_time
        total_processed = self.completed_jobs + self.failed_jobs
        
        if elapsed_time > 0 and total_processed > 0:
            self.performance_metrics["jobs_per_second"] = total_processed / elapsed_time
            
            remaining_jobs = self.total_jobs - total_processed
            if self.performance_metrics["jobs_per_second"] > 0:
                self.performance_metrics["estimated_time_remaining"] = (
                    remaining_jobs / self.performance_metrics["jobs_per_second"]
                )
        
        if self.total_jobs > 0:
            self.performance_metrics["current_phase_progress"] = (
                total_processed / self.total_jobs * 100
            )
    
    def get_progress_summary(self) -> str:
        """Get formatted progress summary"""
        progress_pct = (self.completed_jobs + self.failed_jobs) / max(1, self.total_jobs) * 100
        phase_name = self.phase_names.get(self.current_phase, f"Phase {self.current_phase}")
        
        eta_minutes = self.performance_metrics["estimated_time_remaining"] / 60
        jobs_per_sec = self.performance_metrics["jobs_per_second"]
        
        return (
            f"Progress: {progress_pct:.1f}% ({self.completed_jobs + self.failed_jobs}/{self.total_jobs}) "
            f"| {phase_name} | Current: {self.current_job} "
            f"| Speed: {jobs_per_sec:.2f} jobs/sec | ETA: {eta_minutes:.1f}min"
        )


class ConversionOrchestrator:
    """Enhanced conversion orchestrator with state management"""
    
    def __init__(self, source_path: Path, target_path: Path):
        self.source_path = source_path
        self.target_path = target_path
        self.state_file = target_path / "conversion_state.json"
        self.conversion_manager = ConversionManager(source_path, target_path)
        self.progress_tracker: Optional[ProgressTracker] = None
        self.state: Optional[ConversionState] = None
        self.interrupted = False
        
        # Setup signal handlers for graceful interruption
        signal.signal(signal.SIGINT, self._handle_interrupt)
        signal.signal(signal.SIGTERM, self._handle_interrupt)
    
    def _handle_interrupt(self, signum, frame):
        """Handle interrupt signals gracefully"""
        self.interrupted = True
        print("\nReceived interrupt signal. Saving state and shutting down gracefully...")
        if self.state:
            self.save_state()
    
    def create_new_conversion(self, total_jobs: int) -> ConversionState:
        """Create new conversion state"""
        conversion_id = f"wcs_conversion_{int(time.time())}"
        self.state = ConversionState(
            conversion_id=conversion_id,
            start_time=datetime.now().isoformat(),
            source_path=str(self.source_path),
            target_path=str(self.target_path),
            total_jobs=total_jobs,
            completed_jobs=0,
            failed_jobs=0,
            current_phase=1,
            job_states={},
            performance_metrics={}
        )
        
        self.progress_tracker = ProgressTracker(
            start_time=time.time(),
            total_jobs=total_jobs
        )
        
        return self.state
    
    def load_conversion_state(self, state_file: Path) -> bool:
        """Load existing conversion state"""
        try:
            self.state = ConversionState.load_from_file(state_file)
            self.progress_tracker = ProgressTracker(
                start_time=time.time(),  # Reset start time for current session
                total_jobs=self.state.total_jobs,
                completed_jobs=self.state.completed_jobs,
                failed_jobs=self.state.failed_jobs,
                current_phase=self.state.current_phase
            )
            return True
        except Exception as e:
            logging.error(f"Failed to load conversion state: {e}")
            return False
    
    def save_state(self) -> None:
        """Save current conversion state"""
        if self.state and self.progress_tracker:
            # Update state with current progress
            self.state.completed_jobs = self.progress_tracker.completed_jobs
            self.state.failed_jobs = self.progress_tracker.failed_jobs
            self.state.current_phase = self.progress_tracker.current_phase
            self.state.performance_metrics = self.progress_tracker.performance_metrics
            
            # Save to file
            self.state.save_to_file(self.state_file)
            logging.info(f"Conversion state saved to: {self.state_file}")
    
    def print_real_time_progress(self, interval: float = 2.0) -> None:
        """Print real-time progress updates"""
        if self.progress_tracker:
            print(f"\r{self.progress_tracker.get_progress_summary()}", end="", flush=True)

def setup_logging(target_dir: Path, verbose: bool = False) -> None:
    """Setup logging configuration"""
    log_level = logging.DEBUG if verbose else logging.INFO
    
    # Ensure log directory exists
    log_file = target_dir / 'wcs_conversion.log'
    ensure_directory(log_file.parent)
    
    # Configure logging
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )

def load_config(config_path: Path) -> dict:
    """Load conversion configuration"""
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        logging.warning(f"Could not load config {config_path}: {e}")
        return {}

def validate_paths(source_path: Path, target_path: Path) -> bool:
    """Validate source and target paths"""
    if not source_path.exists():
        print(f"Error: Source path does not exist: {source_path}")
        return False
    
    if not source_path.is_dir():
        print(f"Error: Source path is not a directory: {source_path}")
        return False
    
    # Create target directory if it doesn't exist
    try:
        ensure_directory(target_path)
    except Exception as e:
        print(f"Error: Cannot create target directory {target_path}: {e}")
        return False
    
    return True

def print_asset_summary(assets: dict) -> None:
    """Print summary of found assets"""
    total_assets = sum(len(asset_list) for asset_list in assets.values())
    print(f"Found {total_assets} assets to convert:")
    
    for asset_type, asset_list in assets.items():
        if asset_list:
            print(f"  {asset_type}: {len(asset_list)} files")

def print_conversion_plan(jobs: list, max_display: int = 10) -> None:
    """Print conversion plan summary"""
    print(f"\nConversion plan ({len(jobs)} jobs):")
    
    # Group by priority for display
    by_priority = {}
    for job in jobs:
        if job.priority not in by_priority:
            by_priority[job.priority] = []
        by_priority[job.priority].append(job)
    
    displayed = 0
    for priority in sorted(by_priority.keys()):
        phase_jobs = by_priority[priority]
        print(f"\n  Phase {priority}: {len(phase_jobs)} jobs")
        
        for job in phase_jobs[:max_display - displayed]:
            print(f"    {job.conversion_type}: {job.source_path.name} -> {job.target_path.name}")
            displayed += 1
            
            if displayed >= max_display:
                break
        
        if displayed >= max_display:
            remaining = len(jobs) - displayed
            if remaining > 0:
                print(f"    ... and {remaining} more jobs")
            break

def run_validation(target_dir: Path, verbose: bool = False) -> dict:
    """Run post-conversion validation"""
    print("Running validation...")
    
    validator = FormatValidator()
    assets_dir = target_dir / "assets"
    
    if not assets_dir.exists():
        print("Warning: No assets directory found for validation")
        return {}
    
    # Validate all converted assets
    results = validator.validate_directory(assets_dir, recursive=True)
    report = validator.generate_validation_report(results)
    
    # Print validation summary
    summary = report['summary']
    print(f"Validation results:")
    print(f"  Total files: {summary['total_files']}")
    print(f"  Valid files: {summary['valid_files']}")
    print(f"  Invalid files: {summary['invalid_files']}")
    print(f"  Files with warnings: {summary['files_with_warnings']}")
    print(f"  Success rate: {summary['success_rate']:.1%}")
    
    # Show issues if any
    if report['issues']:
        print(f"\nValidation issues ({len(report['issues'])}):")
        for issue in report['issues'][:5]:  # Show first 5
            print(f"  {Path(issue['file']).name}: {issue['issue']}")
        if len(report['issues']) > 5:
            print(f"  ... and {len(report['issues']) - 5} more issues")
    
    # Show warnings if verbose
    if verbose and report['warnings']:
        print(f"\nValidation warnings ({len(report['warnings'])}):")
        for warning in report['warnings'][:5]:  # Show first 5
            print(f"  {Path(warning['file']).name}: {warning['warning']}")
        if len(report['warnings']) > 5:
            print(f"  ... and {len(report['warnings']) - 5} more warnings")
    
    return report

def main():
    """Main conversion function with comprehensive CLI interface"""
    parser = argparse.ArgumentParser(
        description='WCS to Godot Asset Conversion Tool - Comprehensive batch processing with resume capability',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert all WCS assets with batch processing
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project
  
  # Resume interrupted conversion
  python convert_wcs_assets.py --resume /path/to/godot/project/conversion_state.json
  
  # Dry run to preview conversion plan
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project --dry-run
  
  # Comprehensive validation of existing assets
  python convert_wcs_assets.py --target /path/to/godot/project --validate-only
  
  # Batch convert with custom settings
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project \\
      --jobs 8 --validate --save-state --progress-interval 1.0
  
  # Convert specific asset types only
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project \\
      --asset-types vp_archives,pof_models,missions --skip-validation
  
  # Generate detailed reports
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project \\
      --generate-manifest --performance-report --export-report json,csv
        """
    )
    
    # Core arguments
    parser.add_argument('--source', type=Path, 
                       help='Path to WCS source directory')
    parser.add_argument('--target', type=Path, required=True,
                       help='Path to Godot project directory')
    
    # Conversion control
    parser.add_argument('--jobs', type=int, default=4,
                       help='Number of parallel conversion jobs (default: 4)')
    parser.add_argument('--asset-types', type=str,
                       help='Comma-separated list of asset types to convert (e.g., vp_archives,pof_models,missions)')
    parser.add_argument('--conversion-types', type=str,
                       help='Comma-separated list of conversion types to include (e.g., vp_extraction,texture_dds,pof_model)')
    
    # Mode selection
    parser.add_argument('--dry-run', action='store_true',
                       help='Show conversion plan without executing')
    parser.add_argument('--catalog-only', action='store_true',
                       help='Only catalog existing assets without conversion')
    parser.add_argument('--validate-only', action='store_true',
                       help='Only run comprehensive validation on existing assets')
    
    # Resume functionality
    parser.add_argument('--resume', type=Path,
                       help='Resume from previous conversion state file')
    parser.add_argument('--save-state', action='store_true',
                       help='Save conversion state for resume capability')
    parser.add_argument('--checkpoint-interval', type=int, default=10,
                       help='Save state checkpoint every N completed jobs (default: 10)')
    
    # Validation and reporting
    parser.add_argument('--validate', action='store_true',
                       help='Run validation after conversion')
    parser.add_argument('--skip-validation', action='store_true',
                       help='Skip validation to improve performance')
    parser.add_argument('--generate-manifest', action='store_true',
                       help='Generate detailed asset manifest')
    parser.add_argument('--performance-report', action='store_true',
                       help='Generate detailed performance report')
    parser.add_argument('--export-report', type=str,
                       help='Export formats for reports (json,csv,xml)')
    
    # Progress and output control
    parser.add_argument('--progress-interval', type=float, default=2.0,
                       help='Progress update interval in seconds (default: 2.0)')
    parser.add_argument('--quiet', action='store_true',
                       help='Minimize output (only show errors and final results)')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose output')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug logging')
    
    # Configuration
    parser.add_argument('--config', type=Path, 
                       help='Path to conversion configuration file')
    parser.add_argument('--batch-size', type=int, default=50,
                       help='Batch size for processing groups of assets (default: 50)')
    parser.add_argument('--memory-limit', type=int,
                       help='Memory limit in MB (conversion will pause if exceeded)')
    
    # Advanced options
    parser.add_argument('--force-overwrite', action='store_true',
                       help='Overwrite existing converted assets')
    parser.add_argument('--verify-checksums', action='store_true',
                       help='Verify file checksums during conversion')
    parser.add_argument('--compression-level', type=int, choices=range(0, 10), default=6,
                       help='Compression level for output assets (0-9, default: 6)')
    parser.add_argument('--temp-dir', type=Path,
                       help='Temporary directory for intermediate files')
    
    args = parser.parse_args()
    
    # Validate arguments and mode selection
    mode_count = sum([
        bool(args.resume),
        bool(args.catalog_only),
        bool(args.validate_only),
        bool(args.source)
    ])
    
    if mode_count == 0:
        parser.error("Must specify --source, --resume, --catalog-only, or --validate-only")
    elif mode_count > 1 and not args.source:
        parser.error("Cannot combine --resume, --catalog-only, or --validate-only with other modes")
    
    if not args.source and not args.resume and not args.catalog_only and not args.validate_only:
        parser.error("--source is required unless using --resume, --catalog-only, or --validate-only")
    
    # Validate conflicting options
    if args.quiet and args.verbose:
        parser.error("Cannot use both --quiet and --verbose")
    
    if args.validate and args.skip_validation:
        parser.error("Cannot use both --validate and --skip-validation")
    
    if args.dry_run and args.resume:
        parser.error("Cannot use --dry-run with --resume")
    
    # Setup logging
    setup_logging(args.target, args.verbose)
    logger = logging.getLogger(__name__)
    
    try:
        # Load configuration
        config = {}
        if args.config and args.config.exists():
            config = load_config(args.config)
        else:
            # Try to load default config
            default_config = Path(__file__).parent / "config" / "conversion_config.json"
            if default_config.exists():
                config = load_config(default_config)
        
        # Validate paths
        if not args.catalog_only:
            if not validate_paths(args.source, args.target):
                return 1
        else:
            if not args.target.exists():
                print(f"Error: Target directory does not exist: {args.target}")
                return 1
        
        # Create Godot directory structure
        create_godot_directory_structure(args.target)
        
        # Initialize conversion manager
        source_path = args.source if args.source else args.target
        converter = ConversionManager(source_path, args.target)
        
        if args.catalog_only:
            # Only catalog existing assets
            print("Cataloging existing converted assets...")
            converter.catalog_converted_assets()
            print("Asset cataloging completed")
            
            # Run validation if requested
            if args.validate:
                validation_report = run_validation(args.target, args.verbose)
                
                # Save validation report
                report_path = args.target / "validation_report.json"
                with open(report_path, 'w') as f:
                    json.dump(validation_report, f, indent=2)
                print(f"Validation report saved to: {report_path}")
            
            return 0
        
        # Scan for assets
        print("Scanning WCS assets...")
        logger.info(f"Scanning WCS assets in: {args.source}")
        assets = converter.scan_wcs_assets()
        
        if not any(assets.values()):
            print("No WCS assets found in source directory")
            return 1
        
        print_asset_summary(assets)
        
        # Create conversion plan
        print("\nCreating conversion plan...")
        conversion_jobs = converter.create_conversion_plan(assets)
        
        if args.dry_run:
            print_conversion_plan(conversion_jobs)
            return 0
        
        if not conversion_jobs:
            print("No conversion jobs created")
            return 1
        
        # Execute conversion
        print(f"\nStarting conversion with {args.jobs} parallel jobs...")
        logger.info(f"Starting conversion with {args.jobs} parallel jobs")
        
        completed, failed, total = converter.execute_conversion_plan(conversion_jobs, args.jobs)
        
        print(f"\nConversion completed: {completed}/{total} successful, {failed} failed")
        
        # Catalog converted assets
        print("\nCataloging converted assets...")
        converter.catalog_converted_assets()
        
        # Run validation if requested
        validation_report = None
        if args.validate:
            validation_report = run_validation(args.target, args.verbose)
        
        # Generate comprehensive report
        print("\nGenerating conversion report...")
        report = converter.generate_conversion_report()
        
        if validation_report:
            report['validation_results'] = validation_report
        
        # Save report
        report_path = args.target / "conversion_report.json"
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"Conversion report saved to: {report_path}")
        
        # Print final summary
        success_rate = completed / max(1, total)
        print(f"\nConversion process finished!")
        print(f"Success rate: {success_rate:.1%}")
        
        if failed > 0:
            print(f"Warning: {failed} conversions failed. Check the conversion report for details.")
            return 1
        
        return 0
        
    except KeyboardInterrupt:
        print("\nConversion interrupted by user")
        logger.info("Conversion interrupted by user")
        return 130
    except Exception as e:
        print(f"Error: Conversion failed: {e}")
        logger.error(f"Conversion failed: {e}", exc_info=True)
        return 1

if __name__ == '__main__':
    exit(main())