#!/usr/bin/env python3
"""
Mission File Converter - EPIC-003 DM-007 Implementation

Main orchestrator for converting FS2 mission files into Godot scene format
with proper object placement and event system integration.
"""

import json
import logging
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .fs2_mission_parser import FS2MissionParser, MissionData
from .godot_scene_generator import GodotSceneGenerator
from .mission_event_converter import ConvertedEvent, MissionEventConverter
from .mission_resources import MissionResourceGenerator


@dataclass
class ConversionResult:
    """Result of mission file conversion."""
    success: bool
    mission_name: str
    source_file: str
    output_files: List[str]
    errors: List[str]
    warnings: List[str]
    conversion_time: float
    statistics: Dict[str, Any]


class MissionFileConverter:
    """Converts WCS .fs2 mission files to Godot scene format."""
    
    def __init__(self, asset_base_path: str = "res://") -> None:
        """Initialize mission file converter."""
        self.logger = logging.getLogger(__name__)
        self.asset_base_path = asset_base_path
        
        # Initialize sub-converters
        self.fs2_parser = FS2MissionParser()
        self.scene_generator = GodotSceneGenerator()
        self.event_converter = MissionEventConverter()
        self.resource_generator = MissionResourceGenerator()
    
    def convert_mission_file(self, fs2_path: Path, output_dir: Path, 
                           validate_output: bool = True) -> ConversionResult:
        """Convert FS2 mission file to Godot format."""
        import time
        start_time = time.time()
        
        result = ConversionResult(
            success=False,
            mission_name="",
            source_file=str(fs2_path),
            output_files=[],
            errors=[],
            warnings=[],
            conversion_time=0.0,
            statistics={}
        )
        
        try:
            self.logger.info(f"Converting mission file: {fs2_path}")
            
            # Step 1: Parse FS2 mission file
            mission_data = self._parse_mission_file(fs2_path, result)
            if not mission_data:
                return result
            
            result.mission_name = mission_data.mission_info.name or fs2_path.stem
            
            # Step 2: Convert events and goals
            converted_events = self._convert_mission_events(mission_data, result)
            
            # Step 3: Generate Godot scene
            scene_files = self._generate_godot_scene(mission_data, output_dir, result)
            
            # Step 4: Generate mission resources (data-driven approach)
            resource_files = self._generate_mission_resources(mission_data, converted_events, output_dir, result)
            
            # Step 4.5: Generate resource script files
            script_files = self._generate_resource_scripts(output_dir, result)
            
            # Step 5: Generate SEXP mapping documentation
            sexp_docs = self._generate_sexp_documentation(mission_data, converted_events, output_dir, result)
            
            # Step 6: Validate conversion if requested
            if validate_output:
                self._validate_conversion_output(result)
            
            # Calculate statistics
            result.statistics = self._calculate_conversion_statistics(mission_data, converted_events)
            
            # Mark as successful if no critical errors
            if not any("CRITICAL" in error for error in result.errors):
                result.success = True
                self.logger.info(f"Successfully converted mission: {result.mission_name}")
            else:
                self.logger.error(f"Mission conversion failed with critical errors")
            
            result.conversion_time = time.time() - start_time
            return result
            
        except Exception as e:
            result.errors.append(f"CRITICAL: Conversion failed: {e}")
            result.conversion_time = time.time() - start_time
            self.logger.error(f"Mission conversion failed: {e}")
            return result
    
    def convert_mission_directory(self, input_dir: Path, output_dir: Path) -> List[ConversionResult]:
        """Convert all FS2 mission files in a directory."""
        results = []
        
        # Find all .fs2 files
        mission_files = list(input_dir.glob("*.fs2"))
        self.logger.info(f"Found {len(mission_files)} mission files to convert")
        
        for mission_file in mission_files:
            self.logger.info(f"Converting {mission_file.name}")
            result = self.convert_mission_file(mission_file, output_dir)
            results.append(result)
            
            # Log result
            if result.success:
                self.logger.info(f"✓ {mission_file.name} converted successfully")
            else:
                self.logger.error(f"✗ {mission_file.name} conversion failed")
                for error in result.errors:
                    self.logger.error(f"  {error}")
        
        # Generate summary
        successful = sum(1 for r in results if r.success)
        self.logger.info(f"Conversion complete: {successful}/{len(results)} successful")
        
        return results
    
    def _parse_mission_file(self, fs2_path: Path, result: ConversionResult) -> Optional[MissionData]:
        """Parse FS2 mission file."""
        try:
            mission_data = self.fs2_parser.parse_mission_file(fs2_path)
            if not mission_data:
                result.errors.append("CRITICAL: Failed to parse mission file")
                return None
            
            # Add parser warnings/errors to result
            result.warnings.extend(mission_data.parse_warnings)
            result.errors.extend([f"PARSE: {e}" for e in mission_data.parse_errors])
            
            return mission_data
            
        except Exception as e:
            result.errors.append(f"CRITICAL: Mission parsing failed: {e}")
            return None
    
    def _convert_mission_events(self, mission_data: MissionData, 
                               result: ConversionResult) -> Dict[str, ConvertedEvent]:
        """Convert mission events and goals."""
        try:
            converted_events = self.event_converter.convert_mission_events(mission_data)
            
            if not converted_events:
                result.warnings.append("No events/goals were converted")
            
            return converted_events
            
        except Exception as e:
            result.errors.append(f"EVENT: Event conversion failed: {e}")
            return {}
    
    def _generate_godot_scene(self, mission_data: MissionData, output_dir: Path, 
                             result: ConversionResult) -> List[str]:
        """Generate Godot scene files."""
        try:
            # Create output paths
            mission_name = self._sanitize_filename(mission_data.mission_info.name or "mission")
            scene_path = output_dir / "scenes" / "missions" / f"{mission_name}.tscn"
            script_path = output_dir / "scripts" / "missions" / f"{mission_name}.gd"
            
            # Generate scene
            success = self.scene_generator.generate_mission_scene(
                mission_data, scene_path, self.asset_base_path
            )
            
            if success:
                result.output_files.extend([str(scene_path), str(script_path)])
                return [str(scene_path), str(script_path)]
            else:
                result.errors.append("SCENE: Failed to generate Godot scene")
                return []
                
        except Exception as e:
            result.errors.append(f"SCENE: Scene generation failed: {e}")
            return []
    
    def _generate_mission_resources(self, mission_data: MissionData, 
                                   converted_events: Dict[str, ConvertedEvent],
                                   output_dir: Path, result: ConversionResult) -> List[str]:
        """Generate mission resource files using data-driven approach."""
        try:
            # Use the new resource generator
            resource_files = self.resource_generator.generate_mission_resources(
                mission_data, converted_events, output_dir
            )
            
            result.output_files.extend(resource_files)
            return resource_files
            
        except Exception as e:
            result.errors.append(f"RESOURCE: Resource generation failed: {e}")
            return []
    
    def _generate_resource_scripts(self, output_dir: Path, result: ConversionResult) -> List[str]:
        """Generate resource script files."""
        try:
            script_files = self.resource_generator.generate_mission_script_resources(output_dir)
            result.output_files.extend(script_files)
            return script_files
            
        except Exception as e:
            result.errors.append(f"SCRIPTS: Resource script generation failed: {e}")
            return []
    
    def _generate_sexp_documentation(self, mission_data: MissionData,
                                    converted_events: Dict[str, ConvertedEvent],
                                    output_dir: Path, result: ConversionResult) -> List[str]:
        """Generate SEXP expression mapping documentation."""
        try:
            mission_name = self._sanitize_filename(mission_data.mission_info.name or "mission")
            docs_path = output_dir / "docs" / "missions" / f"{mission_name}_sexp_mapping.md"
            
            # Generate documentation content
            docs_content = self._create_sexp_documentation_content(mission_data, converted_events)
            
            # Ensure directory exists
            docs_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write documentation
            with open(docs_path, 'w', encoding='utf-8') as f:
                f.write(docs_content)
            
            result.output_files.append(str(docs_path))
            return [str(docs_path)]
            
        except Exception as e:
            result.errors.append(f"DOCS: Documentation generation failed: {e}")
            return []
    
    def _create_mission_resource_content(self, mission_data: MissionData,
                                        converted_events: Dict[str, ConvertedEvent]) -> str:
        """Create Godot .tres resource file content."""
        resource_template = f'''[gd_resource type="Resource" script_class="MissionResource" format=3]

[resource]

mission_name = "{mission_data.mission_info.name or 'Unknown Mission'}"
mission_author = "{mission_data.mission_info.author or 'Unknown'}"
mission_description = "{mission_data.mission_info.description or 'No description'}"
mission_version = {mission_data.mission_info.version}
created_date = "{mission_data.mission_info.created}"
modified_date = "{mission_data.mission_info.modified}"
notes = "{mission_data.mission_info.notes}"

# Mission statistics
num_objects = {len(mission_data.objects)}
num_wings = {len(mission_data.wings)}
num_waypoints = {len(mission_data.waypoints)}
num_events = {len(mission_data.events)}
num_goals = {len(mission_data.goals)}
num_variables = {len(mission_data.variables)}

# Teams involved
teams = {json.dumps(list(set(obj.team for obj in mission_data.objects)))}

# Ship classes used
ship_classes = {json.dumps(list(set(obj.class_name for obj in mission_data.objects if obj.class_name)))}

# Event names
event_names = {json.dumps(list(converted_events.keys()))}

# Objective list
objectives = {json.dumps([{"name": goal.name, "type": goal.type, "message": goal.message} for goal in mission_data.goals])}
'''
        
        return resource_template
    
    def _create_mission_metadata(self, mission_data: MissionData,
                                 converted_events: Dict[str, ConvertedEvent]) -> Dict[str, Any]:
        """Create mission metadata dictionary."""
        metadata = {
            "mission_info": asdict(mission_data.mission_info),
            "statistics": {
                "total_objects": len(mission_data.objects),
                "total_wings": len(mission_data.wings),
                "total_waypoints": len(mission_data.waypoints),
                "total_events": len(mission_data.events),
                "total_goals": len(mission_data.goals),
                "total_variables": len(mission_data.variables)
            },
            "object_summary": [
                {
                    "name": obj.name,
                    "class": obj.class_name,
                    "team": obj.team,
                    "position": obj.position
                }
                for obj in mission_data.objects
            ],
            "wing_summary": [
                {
                    "name": wing.name,
                    "ships": wing.ships,
                    "num_waves": wing.num_waves
                }
                for wing in mission_data.wings
            ],
            "goal_summary": [
                {
                    "name": goal.name,
                    "type": goal.type,
                    "message": goal.message,
                    "converted": goal.name in converted_events or f"goal_{goal.name}" in converted_events
                }
                for goal in mission_data.goals
            ],
            "event_summary": [
                {
                    "name": event.name,
                    "repeat_count": event.repeat_count,
                    "converted": event.name in converted_events
                }
                for event in mission_data.events
            ],
            "conversion_info": {
                "converted_events": len(converted_events),
                "total_functions_generated": len(converted_events) * 2,  # Each event gets check + action function
                "sexp_formulas_processed": len([e for e in mission_data.events if e.formula]) + len([g for g in mission_data.goals if g.formula])
            }
        }
        
        return metadata
    
    def _create_sexp_documentation_content(self, mission_data: MissionData,
                                          converted_events: Dict[str, ConvertedEvent]) -> str:
        """Create SEXP mapping documentation."""
        docs_content = f'''# SEXP Expression Mapping Documentation

**Mission**: {mission_data.mission_info.name or 'Unknown Mission'}  
**Author**: {mission_data.mission_info.author or 'Unknown'}  
**Converted**: {mission_data.mission_info.modified}  

## Overview

This document provides a mapping of SEXP expressions from the original FS2 mission file to their GDScript equivalents in the Godot conversion.

## Mission Events

'''
        
        # Document events
        for i, event in enumerate(mission_data.events):
            event_name = event.name or f"event_{i}"
            docs_content += f'''### Event: {event_name}

**Original SEXP Formula:**
```
{event.formula or 'No formula'}
```

**Converted GDScript:**
'''
            if event_name in converted_events:
                converted_event = converted_events[event_name]
                docs_content += f'''```gdscript
{converted_event.gdscript_function}
```

**Trigger Conditions:**
'''
                for condition in converted_event.trigger_conditions:
                    docs_content += f'- `{condition}`\n'
                
                docs_content += '\n**Actions:**\n'
                for action in converted_event.actions:
                    docs_content += f'- `{action}`\n'
            else:
                docs_content += '```\n(Not converted)\n```\n'
            
            docs_content += '\n---\n\n'
        
        # Document goals
        docs_content += '## Mission Goals\n\n'
        
        for i, goal in enumerate(mission_data.goals):
            goal_name = goal.name or f"goal_{i}"
            docs_content += f'''### Goal: {goal_name}

**Type**: {goal.type}  
**Message**: {goal.message}  

**Original SEXP Formula:**
```
{goal.formula or 'No formula'}
```

**Converted GDScript:**
'''
            
            goal_key = f"goal_{goal_name}"
            if goal_key in converted_events:
                converted_goal = converted_events[goal_key]
                docs_content += f'''```gdscript
{converted_goal.gdscript_function}
```
'''
            else:
                docs_content += '```\n(Not converted)\n```\n'
            
            docs_content += '\n---\n\n'
        
        # Add conversion statistics
        docs_content += f'''## Conversion Statistics

- **Total Events**: {len(mission_data.events)}
- **Total Goals**: {len(mission_data.goals)}
- **Successfully Converted**: {len(converted_events)}
- **Conversion Rate**: {len(converted_events) / max(len(mission_data.events) + len(mission_data.goals), 1) * 100:.1f}%

## SEXP to GDScript Operator Mapping

| SEXP Operator | GDScript Equivalent | Description |
|---------------|-------------------|-------------|
| `and` | `and` | Logical AND |
| `or` | `or` | Logical OR |
| `not` | `not` | Logical NOT |
| `=` | `==` | Equality comparison |
| `is-destroyed` | `is_ship_destroyed()` | Check if ship is destroyed |
| `time-elapsed` | `get_mission_time() >=` | Check mission time |
| `send-message` | `send_message()` | Send in-game message |
| `warp-in` | `warp_in_ship()` | Warp ship into mission |
| `end-mission` | `end_mission()` | End the mission |

For a complete list of supported operators, see the mission event converter source code.

## Notes

- SEXP expressions are converted to GDScript on a best-effort basis
- Complex nested expressions may require manual review
- Some WCS-specific operators may not have direct Godot equivalents
- Event timing and trigger conditions are preserved where possible

## Validation

To validate the conversion accuracy:

1. Compare original mission objectives with converted goals
2. Test event triggers in Godot to ensure proper timing
3. Verify ship spawning and mission flow matches original
4. Check that all critical mission events are functional

'''
        
        return docs_content
    
    def _validate_conversion_output(self, result: ConversionResult) -> None:
        """Validate conversion output files and data integrity."""
        # 1. File existence validation
        for file_path in result.output_files:
            path = Path(file_path)
            if not path.exists():
                result.errors.append(f"VALIDATION: Output file missing: {file_path}")
            elif path.stat().st_size == 0:
                result.warnings.append(f"VALIDATION: Output file is empty: {file_path}")
        
        # 2. Resource file validation
        self._validate_resource_files(result)
        
        # 3. Scene file validation  
        self._validate_scene_files(result)
        
        # 4. Data consistency validation
        self._validate_data_consistency(result)
    
    def _validate_resource_files(self, result: ConversionResult) -> None:
        """Validate generated resource files."""
        resource_files = [f for f in result.output_files if f.endswith('.tres')]
        
        for resource_file in resource_files:
            try:
                path = Path(resource_file)
                if not path.exists():
                    continue
                
                # Read and validate resource file format
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Basic format validation
                if not content.startswith('[gd_resource'):
                    result.errors.append(f"VALIDATION: Invalid resource format: {resource_file}")
                    continue
                
                # Check for required resource properties
                if 'script =' not in content:
                    result.warnings.append(f"VALIDATION: Resource missing script reference: {resource_file}")
                
                # Validate resource-specific content
                if '/mission_data.gd' in content:
                    self._validate_mission_data_resource(content, resource_file, result)
                elif '/ship_instance_data.gd' in content:
                    self._validate_ship_instance_resource(content, resource_file, result)
                elif '/mission_event_data.gd' in content:
                    self._validate_event_resource(content, resource_file, result)
                
            except Exception as e:
                result.errors.append(f"VALIDATION: Failed to validate resource {resource_file}: {e}")
    
    def _validate_mission_data_resource(self, content: str, file_path: str, result: ConversionResult) -> None:
        """Validate mission data resource content."""
        required_fields = [
            'mission_name =', 'total_objects =', 'total_wings =', 
            'ship_resources =', 'wing_resources =', 'event_resources ='
        ]
        
        for field in required_fields:
            if field not in content:
                result.errors.append(f"VALIDATION: Mission resource missing {field}: {file_path}")
    
    def _validate_ship_instance_resource(self, content: str, file_path: str, result: ConversionResult) -> None:
        """Validate ship instance resource content."""
        required_fields = [
            'ship_name =', 'ship_class =', 'team =', 'position =', 'initial_hull ='
        ]
        
        for field in required_fields:
            if field not in content:
                result.errors.append(f"VALIDATION: Ship resource missing {field}: {file_path}")
    
    def _validate_event_resource(self, content: str, file_path: str, result: ConversionResult) -> None:
        """Validate event resource content."""
        required_fields = [
            'event_name =', 'trigger_conditions =', 'actions ='
        ]
        
        for field in required_fields:
            if field not in content:
                result.errors.append(f"VALIDATION: Event resource missing {field}: {file_path}")
    
    def _validate_scene_files(self, result: ConversionResult) -> None:
        """Validate generated scene files."""
        scene_files = [f for f in result.output_files if f.endswith('.tscn')]
        
        for scene_file in scene_files:
            try:
                path = Path(scene_file)
                if not path.exists():
                    continue
                
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Basic scene format validation
                if not content.startswith('[gd_scene'):
                    result.errors.append(f"VALIDATION: Invalid scene format: {scene_file}")
                    continue
                
                # Check for required scene structure
                if 'type="MissionController"' not in content:
                    result.errors.append(f"VALIDATION: Scene missing MissionController: {scene_file}")
                
                # Check for required containers
                required_containers = ['Ships', 'Wings', 'Waypoints']
                for container in required_containers:
                    if f'name="{container}"' not in content:
                        result.warnings.append(f"VALIDATION: Scene missing {container} container: {scene_file}")
                
            except Exception as e:
                result.errors.append(f"VALIDATION: Failed to validate scene {scene_file}: {e}")
    
    def _validate_data_consistency(self, result: ConversionResult) -> None:
        """Validate data consistency across generated files."""
        try:
            # Parse mission name from result for cross-file validation
            mission_name = result.mission_name
            if not mission_name:
                result.warnings.append("VALIDATION: Mission name not set for consistency check")
                return
            
            # Check that resource references match generated files
            main_resource_files = [f for f in result.output_files if f.endswith(f"{self._sanitize_filename(mission_name)}.tres")]
            
            if not main_resource_files:
                result.errors.append("VALIDATION: Main mission resource file not found")
                return
            
            # Validate resource reference consistency
            main_resource_path = main_resource_files[0]
            self._validate_resource_references(main_resource_path, result)
            
        except Exception as e:
            result.errors.append(f"VALIDATION: Data consistency check failed: {e}")
    
    def _validate_resource_references(self, main_resource_path: str, result: ConversionResult) -> None:
        """Validate that resource references point to existing files."""
        try:
            with open(main_resource_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Extract resource arrays from content
            import re

            # Find ship resources array
            ship_match = re.search(r'ship_resources = \[(.*?)\]', content, re.DOTALL)
            if ship_match:
                ship_refs = re.findall(r'"([^"]*)"', ship_match.group(1))
                for ship_ref in ship_refs:
                    if ship_ref.startswith('res://'):
                        # Convert to file path and check existence
                        file_path = ship_ref.replace('res://', str(Path(main_resource_path).parent.parent.parent) + '/')
                        if not Path(file_path).exists():
                            result.warnings.append(f"VALIDATION: Referenced ship resource not found: {ship_ref}")
            
            # Find wing resources array
            wing_match = re.search(r'wing_resources = \[(.*?)\]', content, re.DOTALL)
            if wing_match:
                wing_refs = re.findall(r'"([^"]*)"', wing_match.group(1))
                for wing_ref in wing_refs:
                    if wing_ref.startswith('res://'):
                        file_path = wing_ref.replace('res://', str(Path(main_resource_path).parent.parent.parent) + '/')
                        if not Path(file_path).exists():
                            result.warnings.append(f"VALIDATION: Referenced wing resource not found: {wing_ref}")
            
            # Find event resources array
            event_match = re.search(r'event_resources = \[(.*?)\]', content, re.DOTALL)
            if event_match:
                event_refs = re.findall(r'"([^"]*)"', event_match.group(1))
                for event_ref in event_refs:
                    if event_ref.startswith('res://'):
                        file_path = event_ref.replace('res://', str(Path(main_resource_path).parent.parent.parent) + '/')
                        if not Path(file_path).exists():
                            result.warnings.append(f"VALIDATION: Referenced event resource not found: {event_ref}")
                            
        except Exception as e:
            result.errors.append(f"VALIDATION: Resource reference validation failed: {e}")
    
    def _calculate_conversion_statistics(self, mission_data: MissionData,
                                       converted_events: Dict[str, ConvertedEvent]) -> Dict[str, Any]:
        """Calculate conversion statistics."""
        total_sexp_formulas = (
            len([e for e in mission_data.events if e.formula]) +
            len([g for g in mission_data.goals if g.formula])
        )
        
        ship_classes = set(obj.class_name for obj in mission_data.objects if obj.class_name)
        teams = set(obj.team for obj in mission_data.objects if obj.team)
        
        return {
            "mission_complexity": {
                "objects": len(mission_data.objects),
                "wings": len(mission_data.wings),
                "waypoints": len(mission_data.waypoints),
                "events": len(mission_data.events),
                "goals": len(mission_data.goals),
                "variables": len(mission_data.variables),
                "unique_ship_classes": len(ship_classes),
                "teams_involved": len(teams)
            },
            "conversion_success": {
                "total_events_goals": len(mission_data.events) + len(mission_data.goals),
                "converted_events": len(converted_events),
                "conversion_rate": len(converted_events) / max(len(mission_data.events) + len(mission_data.goals), 1),
                "sexp_formulas_processed": total_sexp_formulas,
                "functions_generated": len(converted_events) * 2
            },
            "data_preservation": {
                "ship_data_preserved": all(obj.name and obj.class_name for obj in mission_data.objects),
                "wing_data_preserved": all(wing.name for wing in mission_data.wings),
                "objective_data_preserved": all(goal.name or goal.message for goal in mission_data.goals)
            }
        }
    
    def _sanitize_filename(self, filename: str) -> str:
        """Sanitize filename for filesystem compatibility."""
        import re

        # Replace invalid characters
        sanitized = re.sub(r'[<>:"/\\|?*]', '_', filename)
        # Remove extra spaces and make lowercase
        sanitized = re.sub(r'\s+', '_', sanitized.strip()).lower()
        # Ensure not empty
        if not sanitized:
            sanitized = "mission"
        return sanitized


# Example usage and CLI interface
if __name__ == "__main__":
    import argparse
    
    def main():
        parser = argparse.ArgumentParser(description='Convert FS2 mission files to Godot format')
        parser.add_argument('input', type=Path, help='Input FS2 mission file or directory')
        parser.add_argument('--output', '-o', type=Path, required=True,
                          help='Output directory for Godot files')
        parser.add_argument('--asset-path', default='res://',
                          help='Base asset path for Godot resources')
        parser.add_argument('--validate', action='store_true',
                          help='Validate conversion output')
        parser.add_argument('--verbose', '-v', action='store_true',
                          help='Verbose logging')
        
        args = parser.parse_args()
        
        # Setup logging
        log_level = logging.DEBUG if args.verbose else logging.INFO
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        
        # Initialize converter
        converter = MissionFileConverter(args.asset_path)
        
        # Convert mission(s)
        if args.input.is_file():
            # Single file conversion
            result = converter.convert_mission_file(args.input, args.output, args.validate)
            
            print(f"\nConversion Result:")
            print(f"Success: {result.success}")
            print(f"Mission: {result.mission_name}")
            print(f"Time: {result.conversion_time:.2f}s")
            print(f"Output Files: {len(result.output_files)}")
            
            if result.warnings:
                print(f"\nWarnings ({len(result.warnings)}):")
                for warning in result.warnings[:5]:  # Show first 5
                    print(f"  {warning}")
            
            if result.errors:
                print(f"\nErrors ({len(result.errors)}):")
                for error in result.errors[:5]:  # Show first 5
                    print(f"  {error}")
            
            print(f"\nStatistics:")
            for category, stats in result.statistics.items():
                print(f"  {category}: {stats}")
        
        elif args.input.is_dir():
            # Directory conversion
            results = converter.convert_mission_directory(args.input, args.output)
            
            successful = sum(1 for r in results if r.success)
            total_time = sum(r.conversion_time for r in results)
            
            print(f"\nBatch Conversion Results:")
            print(f"Total Files: {len(results)}")
            print(f"Successful: {successful}")
            print(f"Failed: {len(results) - successful}")
            print(f"Total Time: {total_time:.2f}s")
            print(f"Average Time: {total_time / len(results):.2f}s per mission")
            
            # Show failed conversions
            failed = [r for r in results if not r.success]
            if failed:
                print(f"\nFailed Conversions:")
                for result in failed:
                    print(f"  {result.mission_name}: {result.errors[0] if result.errors else 'Unknown error'}")
        
        else:
            print(f"Error: Input path {args.input} is not a file or directory")
    
    if __name__ == "__main__":
        main()