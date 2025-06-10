#!/usr/bin/env python3
"""
WCS Configuration Migration CLI Tool

Standalone tool for migrating WCS configuration files, player settings, and 
control bindings to Godot-compatible format.

Usage:
    python migrate_config.py --wcs-source /path/to/wcs --godot-target /path/to/godot
    python migrate_config.py --validate-only --godot-target /path/to/godot

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-009 - Configuration Migration
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import argparse
import logging
import sys
from pathlib import Path
from config_migrator import ConfigMigrator


def setup_logging(verbose: bool = False, log_file: Path = None) -> None:
    """Setup logging configuration."""
    log_level = logging.DEBUG if verbose else logging.INFO
    
    # Create formatters
    console_formatter = logging.Formatter(
        '%(levelname)s: %(message)s'
    )
    file_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Setup root logger
    logger = logging.getLogger()
    logger.setLevel(log_level)
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(log_level)
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)
    
    # File handler
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)


def validate_migration(godot_target_dir: Path) -> bool:
    """Validate existing configuration migration."""
    print("Validating existing configuration migration...")
    
    # Check for required configuration files
    required_files = [
        "project.godot",
        "resources/configuration/game_settings.tres",
        "resources/configuration/user_preferences.tres", 
        "resources/configuration/system_configuration.tres",
        "input_map.cfg",
        "migration_report.json"
    ]
    
    missing_files = []
    for file_path in required_files:
        full_path = godot_target_dir / file_path
        if not full_path.exists():
            missing_files.append(file_path)
    
    if missing_files:
        print(f"Missing configuration files:")
        for file_path in missing_files:
            print(f"  - {file_path}")
        return False
    
    # Validate migration report
    report_path = godot_target_dir / "migration_report.json"
    try:
        import json
        with open(report_path, 'r') as f:
            report_data = json.load(f)
        
        validation_results = report_data.get("validation_results", {})
        overall_valid = all(validation_results.values())
        
        if overall_valid:
            print("✓ Configuration migration validation passed")
            
            # Print summary
            settings_migrated = report_data.get("settings_migrated", {})
            control_bindings = report_data.get("control_bindings", {})
            pilot_profiles = report_data.get("pilot_profiles", {})
            
            print(f"✓ Graphics settings: {len(settings_migrated.get('graphics_settings', {}))}")
            print(f"✓ Audio settings: {len(settings_migrated.get('audio_settings', {}))}")
            print(f"✓ Gameplay settings: {len(settings_migrated.get('gameplay_settings', {}))}")
            print(f"✓ Control bindings: {control_bindings.get('total_bindings', 0)}")
            print(f"✓ Pilot profiles: {pilot_profiles.get('total_profiles', 0)}")
            
            return True
        else:
            print("✗ Configuration migration validation failed")
            for check, result in validation_results.items():
                status = "✓" if result else "✗"
                print(f"  {status} {check}")
            return False
            
    except Exception as e:
        print(f"✗ Failed to validate migration report: {e}")
        return False


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='WCS Configuration Migration Tool',
        epilog="""
Examples:
  # Migrate WCS configuration to Godot
  python migrate_config.py --wcs-source /path/to/wcs --godot-target /path/to/godot
  
  # Validate existing migration
  python migrate_config.py --validate-only --godot-target /path/to/godot
  
  # Migrate with verbose output and logging
  python migrate_config.py --wcs-source /path/to/wcs --godot-target /path/to/godot -v --log-file migration.log
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        '--wcs-source',
        type=Path,
        help='Path to WCS source directory'
    )
    parser.add_argument(
        '--godot-target',
        type=Path,
        required=True,
        help='Path to Godot project directory'
    )
    parser.add_argument(
        '--validate-only',
        action='store_true',
        help='Only validate existing migration, do not migrate'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Force migration even if target files exist'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    parser.add_argument(
        '--log-file',
        type=Path,
        help='Path to log file'
    )
    
    args = parser.parse_args()
    
    # Validate arguments
    if not args.validate_only and not args.wcs_source:
        parser.error("--wcs-source is required unless --validate-only is specified")
    
    if args.wcs_source and not args.wcs_source.exists():
        parser.error(f"WCS source directory does not exist: {args.wcs_source}")
    
    if not args.godot_target.exists():
        parser.error(f"Godot target directory does not exist: {args.godot_target}")
    
    # Setup logging
    log_file = args.log_file or (args.godot_target / "config_migration.log")
    setup_logging(args.verbose, log_file)
    
    logger = logging.getLogger(__name__)
    
    try:
        if args.validate_only:
            # Validation mode
            success = validate_migration(args.godot_target)
            return 0 if success else 1
        
        # Migration mode
        print(f"Migrating WCS configuration:")
        print(f"  Source: {args.wcs_source}")
        print(f"  Target: {args.godot_target}")
        print(f"  Log file: {log_file}")
        print()
        
        # Check for existing migration
        if not args.force:
            existing_report = args.godot_target / "migration_report.json"
            if existing_report.exists():
                print("Warning: Existing configuration migration found.")
                response = input("Continue and overwrite existing migration? [y/N]: ")
                if response.lower() != 'y':
                    print("Migration cancelled.")
                    return 0
        
        # Initialize migration tool
        migrator = ConfigMigrator()
        
        # Perform migration
        logger.info(f"Starting configuration migration")
        success = migrator.migrate_wcs_configuration(
            wcs_source_dir=args.wcs_source,
            godot_target_dir=args.godot_target
        )
        
        if success:
            print("\n✓ Configuration migration completed successfully!")
            
            # Run validation
            print("\nValidating migration...")
            if validate_migration(args.godot_target):
                print("\n✓ Migration validation passed!")
                print(f"\nConfiguration files created in: {args.godot_target}")
                print(f"Migration report: {args.godot_target / 'migration_report.json'}")
                return 0
            else:
                print("\n✗ Migration validation failed!")
                return 1
        else:
            print("\n✗ Configuration migration failed!")
            print(f"Check log file for details: {log_file}")
            return 1
            
    except KeyboardInterrupt:
        print("\nMigration cancelled by user.")
        return 1
    except Exception as e:
        logger.error(f"Migration failed with exception: {e}")
        print(f"\n✗ Migration failed: {e}")
        print(f"Check log file for details: {log_file}")
        return 1


if __name__ == "__main__":
    sys.exit(main())