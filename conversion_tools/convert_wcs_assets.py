#!/usr/bin/env python3
"""
WCS to Godot Conversion Tool

Main CLI interface for converting WCS assets to Godot format following
the EPIC-003 architecture design.

Usage: python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-003 - Asset Organization and Cataloging
Architecture: EPIC-003 - Data Migration & Conversion Tools
"""

import argparse
import json
import logging
import sys
from pathlib import Path

# Add conversion_tools to path
sys.path.insert(0, str(Path(__file__).parent))

from conversion_manager import ConversionManager
from validation.format_validator import FormatValidator
from utilities.path_utils import ensure_directory, create_godot_directory_structure

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
    """Main conversion function"""
    parser = argparse.ArgumentParser(
        description='Convert WCS assets to Godot format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert all WCS assets
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project
  
  # Dry run to see what would be converted
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project --dry-run
  
  # Only catalog existing converted assets
  python convert_wcs_assets.py --target /path/to/godot/project --catalog-only
  
  # Convert with validation and custom job count
  python convert_wcs_assets.py --source /path/to/wcs --target /path/to/godot/project --jobs 8 --validate
        """
    )
    
    parser.add_argument('--source', type=Path, 
                       help='Path to WCS source directory')
    parser.add_argument('--target', type=Path, required=True,
                       help='Path to Godot project directory')
    parser.add_argument('--jobs', type=int, default=4,
                       help='Number of parallel conversion jobs (default: 4)')
    parser.add_argument('--validate', action='store_true',
                       help='Run validation after conversion')
    parser.add_argument('--catalog-only', action='store_true',
                       help='Only catalog existing assets without conversion')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show conversion plan without executing')
    parser.add_argument('--config', type=Path, 
                       help='Path to conversion configuration file')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose output')
    parser.add_argument('--resume', type=Path,
                       help='Resume from previous conversion state file (not implemented)')
    
    args = parser.parse_args()
    
    # Validate arguments
    if not args.catalog_only and not args.source:
        parser.error("--source is required unless using --catalog-only")
    
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