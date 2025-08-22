#!/usr/bin/env python3
"""
Table Conversion CLI Tool

Unified CLI tool for converting WCS table files to Godot resources using
the specialized table converters in table_converters/ directory.

This tool acts as a proper CLI interface that:
1. Discovers all table files in source directory
2. Routes them to appropriate specialized converters
3. Writes converted resources in Godot format to target directories
4. Follows semantic asset organization paths

Author: Dev (GDScript Developer)
Date: June 14, 2025
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Type

# Import all specialized table converters
sys.path.append(str(Path(__file__).parent.parent))

from table_converters.ai_profiles_table_converter import \
    AIProfilesTableConverter
from table_converters.ai_table_converter import AITableConverter
from table_converters.armor_table_converter import ArmorTableConverter
from table_converters.asteroid_table_converter import AsteroidTableConverter
from table_converters.base_table_converter import (BaseTableConverter,
                                                   ParseState, TableType)
from table_converters.fireball_table_converter import FireballTableConverter
from table_converters.iff_table_converter import IFFTableConverter
from table_converters.lightning_table_converter import LightningTableConverter
from table_converters.medals_table_converter import MedalsTableConverter
from table_converters.music_table_converter import MusicTableConverter
from table_converters.rank_table_converter import RankTableConverter
from table_converters.scripting_table_converter import ScriptingTableConverter
from table_converters.ship_table_converter import ShipTableConverter
from table_converters.sounds_table_converter import SoundsTableConverter
from table_converters.species_defs_table_converter import \
    SpeciesDefsTableConverter
from table_converters.species_table_converter import SpeciesTableConverter
from table_converters.stars_table_converter import StarsTableConverter
from table_converters.weapon_table_converter import WeaponTableConverter

logger = logging.getLogger(__name__)

class TableConversionCLI:
    """
    CLI tool for converting WCS table files to Godot resources.
    Routes table files to appropriate specialized converters and handles output.
    """
    
    def __init__(self, source_dir: Path, target_dir: Path):
        """
        Initialize table conversion CLI.
        
        Args:
            source_dir: WCS source directory containing table files
            target_dir: Godot target directory for converted resources
        """
        self.source_dir = Path(source_dir)
        self.target_dir = Path(target_dir)
        
        # If target_dir already ends with 'assets', use it directly
        if self.target_dir.name == "assets":
            self.assets_dir = self.target_dir
        else:
            self.assets_dir = self.target_dir / "assets"
        
        # Conversion statistics
        self.stats = {
            "tables_processed": 0,
            "tables_success": 0,
            "tables_failed": 0,
            "resources_created": 0,
            "errors": []
        }
        
        # Initialize converter mapping
        self.converter_map: Dict[TableType, Type[BaseTableConverter]] = {
            TableType.ASTEROID: AsteroidTableConverter,
            TableType.SHIPS: ShipTableConverter,
            TableType.WEAPONS: WeaponTableConverter,
            TableType.ARMOR: ArmorTableConverter,
            TableType.AI: AITableConverter,
            TableType.AI_PROFILES: AIProfilesTableConverter,
            TableType.FIREBALL: FireballTableConverter,
            TableType.IFF: IFFTableConverter,
            TableType.LIGHTNING: LightningTableConverter,
            TableType.MEDALS: MedalsTableConverter,
            TableType.MUSIC: MusicTableConverter,
            TableType.RANK: RankTableConverter,
            TableType.SCRIPTING: ScriptingTableConverter,
            TableType.SOUNDS: SoundsTableConverter,
            TableType.SPECIES: SpeciesDefsTableConverter,
            TableType.SPECIES_ENTRIES: SpeciesTableConverter,
            TableType.STARS: StarsTableConverter,
        }
        
        # Ensure output directories exist
        self.assets_dir.mkdir(parents=True, exist_ok=True)
    
    def discover_table_files(self) -> List[Path]:
        """Discover all table files in source directory."""
        table_files = []
        
        # Look for .tbl files
        table_files.extend(self.source_dir.rglob("*.tbl"))
        
        # Look for .tbm files (table modifications)
        table_files.extend(self.source_dir.rglob("*.tbm"))
        
        logger.info(f"Discovered {len(table_files)} table files")
        
        return table_files
    
    def determine_table_type(self, table_file: Path) -> TableType:
        """Determine the type of table file."""
        filename = table_file.name.lower()
        
        # Direct filename matching
        type_mapping = {
            "asteroid.tbl": TableType.ASTEROID,
            "ships.tbl": TableType.SHIPS,
            "weapons.tbl": TableType.WEAPONS,
            "armor.tbl": TableType.ARMOR,
            "ai.tbl": TableType.AI,
            "ai_profiles.tbl": TableType.AI_PROFILES,
            "fireball.tbl": TableType.FIREBALL,
            "iff_defs.tbl": TableType.IFF,
            "lightning.tbl": TableType.LIGHTNING,
            "medals.tbl": TableType.MEDALS,
            "music.tbl": TableType.MUSIC,
            "rank.tbl": TableType.RANK,
            "scripting.tbl": TableType.SCRIPTING,
            "sounds.tbl": TableType.SOUNDS,
            "species_defs.tbl": TableType.SPECIES,
            "species.tbl": TableType.SPECIES_ENTRIES,
            "stars.tbl": TableType.STARS,
        }
        
        if filename in type_mapping:
            return type_mapping[filename]
        
        # Pattern-based matching
        if "asteroid" in filename:
            return TableType.ASTEROID
        elif "ship" in filename:
            return TableType.SHIPS
        elif "weapon" in filename:
            return TableType.WEAPONS
        elif "armor" in filename:
            return TableType.ARMOR
        elif "ai_profiles" in filename:
            return TableType.AI_PROFILES
        elif "ai" in filename:
            return TableType.AI
        elif "fireball" in filename:
            return TableType.FIREBALL
        elif "iff" in filename:
            return TableType.IFF
        elif "lightning" in filename:
            return TableType.LIGHTNING
        elif "medal" in filename:
            return TableType.MEDALS
        elif "music" in filename:
            return TableType.MUSIC
        elif "rank" in filename:
            return TableType.RANK
        elif "script" in filename:
            return TableType.SCRIPTING
        elif "sound" in filename:
            return TableType.SOUNDS
        elif "species_defs" in filename:
            return TableType.SPECIES
        elif "species" in filename:
            return TableType.SPECIES_ENTRIES
        elif "star" in filename:
            return TableType.STARS
        
        # Check file content for type hints
        try:
            with open(table_file, 'r', encoding='utf-8', errors='ignore') as f:
                first_lines = f.read(2000).lower()
            
            content_patterns = {
                "#asteroid types": TableType.ASTEROID,
                "#ship classes": TableType.SHIPS,
                "#primary weapons": TableType.WEAPONS,
                "#secondary weapons": TableType.WEAPONS,
                "#armor type": TableType.ARMOR,
                "#ai behavior": TableType.AI,
                "#ai profiles": TableType.AI_PROFILES,
                "#fireball": TableType.FIREBALL,
                "#iff": TableType.IFF,
                "#lightning": TableType.LIGHTNING,
                "#medal": TableType.MEDALS,
                "#music": TableType.MUSIC,
                "#rank": TableType.RANK,
                "#script": TableType.SCRIPTING,
                "#sound": TableType.SOUNDS,
                "#species defs": TableType.SPECIES,
                "#species": TableType.SPECIES_ENTRIES,
                "#star": TableType.STARS,
            }
            
            for pattern, table_type in content_patterns.items():
                if pattern in first_lines:
                    return table_type
                    
        except Exception as e:
            logger.warning(f"Could not read file for type detection: {table_file} - {e}")
        
        logger.warning(f"Unknown table type for file: {table_file}")
        return TableType.UNKNOWN
    
    def convert_table_file(self, table_file: Path) -> bool:
        """Convert a single table file using appropriate converter."""
        try:
            logger.info(f"Converting table file: {table_file}")
            
            # Determine table type
            table_type = self.determine_table_type(table_file)
            
            if table_type == TableType.UNKNOWN:
                logger.warning(f"Skipping unknown table type: {table_file}")
                return False
            
            if table_type not in self.converter_map:
                logger.warning(f"No converter available for table type {table_type}: {table_file}")
                return False
            
            # Get appropriate converter
            converter_class = self.converter_map[table_type]
            converter = converter_class()
            
            # Read and parse the table file
            with open(table_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Create parse state
            lines = content.splitlines()
            state = ParseState(lines)
            
            # Parse the table
            entries = converter.parse_table(state)
            
            if not entries:
                logger.warning(f"No entries parsed from {table_file}")
                return False
            
            # Convert to Godot resource format
            godot_resource = converter.convert_to_godot_resource(entries)
            
            # Create output directory
            output_dir = self._get_output_directory(table_type)
            output_dir.mkdir(parents=True, exist_ok=True)
            
            # Handle individual resources vs single database
            if 'individual_resources' in godot_resource:
                # Write individual .tres files for each asteroid/object
                individual_resources = godot_resource['individual_resources']
                files_created = []
                
                for resource_data in individual_resources:
                    # Create filename from object name
                    object_name = resource_data.get('name', 'unknown')
                    safe_name = self._make_safe_filename(object_name)
                    output_file = output_dir / f"{safe_name}.tres"
                    
                    # Write individual resource
                    self._write_individual_godot_resource(resource_data, output_file, table_type)
                    files_created.append(output_file)
                    self.stats["resources_created"] += 1
                
                # Write shared impact data if present
                if godot_resource.get('impact_data'):
                    impact_file = output_dir / "impact_data.tres"
                    self._write_individual_godot_resource(godot_resource['impact_data'], impact_file, table_type, "ImpactData")
                    files_created.append(impact_file)
                
                logger.info(f"Successfully converted {table_file} -> {len(files_created)} individual files")
                logger.info(f"  Created files: {[f.name for f in files_created]}")
            else:
                # Write single database file (legacy format)
                output_file = output_dir / f"{table_file.stem}.tres"
                self._write_godot_resource(godot_resource, output_file, table_type)
                self.stats["resources_created"] += len(entries)
                logger.info(f"Successfully converted {table_file} -> {output_file}")
                logger.info(f"  Created {len(entries)} resource entries")
            
            return True
            
        except Exception as e:
            error_msg = f"Failed to convert {table_file}: {str(e)}"
            logger.error(error_msg)
            self.stats["errors"].append(error_msg)
            return False
    
    def _get_output_directory(self, table_type: TableType) -> Path:
        """Get output directory for table type following campaign asset organization."""
        
        # Campaign-based asset organization following target/assets/CLAUDE.md
        campaign_base = "campaigns/wing_commander_saga"
        
        type_to_dir = {
            TableType.ASTEROID: f"{campaign_base}/environments/objects/asteroids",
            TableType.SHIPS: f"{campaign_base}/ships",
            TableType.WEAPONS: f"{campaign_base}/weapons", 
            TableType.ARMOR: f"{campaign_base}/armor",
            TableType.AI: f"{campaign_base}/ai",
            TableType.AI_PROFILES: f"{campaign_base}/ai",
            TableType.FIREBALL: f"{campaign_base}/effects/fireballs",
            TableType.IFF: f"{campaign_base}/factions",
            TableType.LIGHTNING: f"{campaign_base}/effects/lightning",
            TableType.MEDALS: f"{campaign_base}/ui/medals",
            TableType.MUSIC: f"{campaign_base}/audio/music",
            TableType.RANK: f"{campaign_base}/ui/ranks",
            TableType.SCRIPTING: f"{campaign_base}/missions/scripting",
            TableType.SOUNDS: f"{campaign_base}/audio/sounds",
            TableType.SPECIES: f"{campaign_base}/species",
            TableType.SPECIES_ENTRIES: f"{campaign_base}/species",
            TableType.STARS: f"{campaign_base}/environments/stars",
        }
        
        subdir = type_to_dir.get(table_type, f"{campaign_base}/misc")
        return self.assets_dir / subdir
    
    def _make_safe_filename(self, name: str) -> str:
        """Make a safe filename from object name."""
        import re

        # Replace spaces and special characters with underscores
        safe_name = re.sub(r'[^\w\-_]', '_', name.lower())
        # Remove multiple consecutive underscores
        safe_name = re.sub(r'_+', '_', safe_name)
        # Remove leading/trailing underscores
        return safe_name.strip('_')
    
    def _write_individual_godot_resource(self, resource_data: Dict[str, Any], output_file: Path, table_type: TableType, resource_class: str = None) -> None:
        """Write individual resource data as Godot .tres file."""
        
        # Determine resource class name
        if resource_class:
            godot_class = resource_class
        elif table_type == TableType.ASTEROID:
            godot_class = "AsteroidData"
        else:
            godot_class = "Resource"
        
        # Create Godot resource content
        content = f'[gd_resource type="{godot_class}" format=3]\n\n[resource]\n'
        
        # Add resource data with proper formatting
        for key, value in resource_data.items():
            if isinstance(value, dict):
                content += f'{key} = {self._format_godot_dict(value)}\n'
            elif isinstance(value, list):
                content += f'{key} = {self._format_godot_array(value)}\n'
            elif isinstance(value, str):
                content += f'{key} = "{self._escape_string(value)}"\n'
            elif isinstance(value, bool):
                content += f'{key} = {str(value).lower()}\n'
            elif value is None:
                content += f'{key} = null\n'
            else:
                content += f'{key} = {value}\n'
        
        # Write to file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
    
    def _write_godot_resource(self, resource_data: Dict[str, Any], output_file: Path, table_type: TableType) -> None:
        """Write resource data as Godot .tres file."""
        
        # Determine resource class name based on table type
        resource_class_map = {
            TableType.ASTEROID: "WCSAsteroidDatabase",
            TableType.SHIPS: "WCSShipDatabase", 
            TableType.WEAPONS: "WCSWeaponDatabase",
            TableType.ARMOR: "WCSArmorDatabase",
            TableType.AI: "WCSAIDatabase",
            TableType.AI_PROFILES: "WCSAIProfilesDatabase",
            TableType.FIREBALL: "WCSFireballDatabase",
            TableType.IFF: "WCSIFFDatabase",
            TableType.LIGHTNING: "WCSLightningDatabase",
            TableType.MEDALS: "WCSMedalsDatabase",
            TableType.MUSIC: "WCSMusicDatabase",
            TableType.RANK: "WCSRankDatabase",
            TableType.SCRIPTING: "WCSScriptingDatabase",
            TableType.SOUNDS: "WCSSoundsDatabase",
            TableType.SPECIES: "WCSSpeciesDefsDatabase", 
            TableType.SPECIES_ENTRIES: "WCSSpeciesDatabase",
            TableType.STARS: "WCSStarsDatabase",
        }
        
        resource_class = resource_class_map.get(table_type, "Resource")
        
        # Create Godot resource content
        content = f'[gd_resource type="{resource_class}" format=3]\n\n[resource]\n'
        
        # Add resource data
        for key, value in resource_data.items():
            if isinstance(value, dict):
                # Convert dictionary to Godot format
                content += f'{key} = {self._format_godot_dict(value)}\n'
            elif isinstance(value, list):
                # Convert list to Godot array format
                content += f'{key} = {self._format_godot_array(value)}\n'
            elif isinstance(value, str):
                content += f'{key} = "{self._escape_string(value)}"\n'
            elif isinstance(value, bool):
                content += f'{key} = {str(value).lower()}\n'
            else:
                content += f'{key} = {value}\n'
        
        # Write to file
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
    
    def _format_godot_dict(self, data: Dict[str, Any]) -> str:
        """Format dictionary as Godot dictionary."""
        if not data:
            return "{}"
        
        items = []
        for key, value in data.items():
            if isinstance(value, dict):
                formatted_value = self._format_godot_dict(value)
            elif isinstance(value, list):
                formatted_value = self._format_godot_array(value)
            elif isinstance(value, str):
                formatted_value = f'"{self._escape_string(value)}"'
            elif isinstance(value, bool):
                formatted_value = str(value).lower()
            else:
                formatted_value = str(value)
            
            items.append(f'"{key}": {formatted_value}')
        
        return "{" + ", ".join(items) + "}"
    
    def _format_godot_array(self, data: List[Any]) -> str:
        """Format list as Godot array."""
        if not data:
            return "[]"
        
        items = []
        for item in data:
            if isinstance(item, dict):
                items.append(self._format_godot_dict(item))
            elif isinstance(item, list):
                items.append(self._format_godot_array(item))
            elif isinstance(item, str):
                items.append(f'"{self._escape_string(item)}"')
            elif isinstance(item, bool):
                items.append(str(item).lower())
            else:
                items.append(str(item))
        
        return "[" + ", ".join(items) + "]"
    
    def _escape_string(self, text: str) -> str:
        """Escape string for Godot resource format."""
        if not text:
            return ""
        # Escape quotes and newlines
        text = text.replace('\\', '\\\\')
        text = text.replace('"', '\\"')
        text = text.replace('\n', '\\n')
        text = text.replace('\r', '\\r')
        return text
    
    def convert_all_tables(self) -> bool:
        """Convert all discovered table files."""
        table_files = self.discover_table_files()
        
        if not table_files:
            logger.error(f"No table files found in {self.source_dir}")
            return False
        
        logger.info(f"Converting {len(table_files)} table files...")
        
        for table_file in table_files:
            self.stats["tables_processed"] += 1
            
            if self.convert_table_file(table_file):
                self.stats["tables_success"] += 1
            else:
                self.stats["tables_failed"] += 1
        
        # Print summary
        logger.info(f"Conversion complete:")
        logger.info(f"  Tables processed: {self.stats['tables_processed']}")
        logger.info(f"  Successful: {self.stats['tables_success']}")
        logger.info(f"  Failed: {self.stats['tables_failed']}")
        logger.info(f"  Resources created: {self.stats['resources_created']}")
        
        if self.stats["errors"]:
            logger.warning(f"  Errors encountered: {len(self.stats['errors'])}")
            for error in self.stats["errors"]:
                logger.warning(f"    {error}")
        
        return self.stats["tables_success"] > 0
    
    def save_conversion_report(self, output_file: Path) -> None:
        """Save conversion statistics to JSON file."""
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(self.stats, f, indent=2)
        
        logger.info(f"Conversion report saved to: {output_file}")

def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Convert WCS table files to Godot resources',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert all tables from WCS source to Godot target
  python table_conversion_cli.py --source /path/to/wcs/source --target /path/to/godot/project
  
  # Convert specific table file
  python table_conversion_cli.py --source /path/to/wcs/source --target /path/to/godot/project --file asteroid.tbl
  
  # Enable verbose logging and save report
  python table_conversion_cli.py --source /path/to/wcs --target /path/to/godot --verbose --report conversion_report.json
        """
    )
    
    parser.add_argument('--source', type=Path, required=True,
                       help='WCS source directory containing table files')
    parser.add_argument('--target', type=Path, required=True, 
                       help='Godot target directory for converted resources')
    parser.add_argument('--file', type=Path,
                       help='Convert specific table file (relative to source)')
    parser.add_argument('--report', type=Path,
                       help='Save conversion report to JSON file')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Configure logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
        ]
    )
    
    try:
        # Validate arguments
        if not args.source.exists():
            logger.error(f"Source directory does not exist: {args.source}")
            return 1
        
        # Initialize CLI tool
        cli = TableConversionCLI(args.source, args.target)
        
        # Convert tables
        if args.file:
            # Convert specific file
            table_file = args.source / args.file
            if not table_file.exists():
                logger.error(f"Table file does not exist: {table_file}")
                return 1
            
            success = cli.convert_table_file(table_file)
            result_text = "successful" if success else "failed"
            logger.info(f"Conversion {result_text}: {table_file}")
        else:
            # Convert all tables
            success = cli.convert_all_tables()
        
        # Save report if requested
        if args.report:
            cli.save_conversion_report(args.report)
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        logger.info("Conversion interrupted by user")
        return 1
    except Exception as e:
        logger.error(f"Conversion failed: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())