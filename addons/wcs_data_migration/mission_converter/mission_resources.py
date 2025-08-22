#!/usr/bin/env python3
"""
Mission Resources Generator - EPIC-003 DM-007 Implementation

Creates Godot Resource files (.tres) containing mission metadata, objectives,
and configuration data for runtime use. Follows EPIC-001/002 data-driven approach.
"""

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .fs2_mission_parser import (MissionData, MissionEvent, MissionGoal,
                                 MissionObject, MissionWaypoint, MissionWing)
from .mission_event_converter import ConvertedEvent


class MissionResourceGenerator:
    """Generates Godot Resource files for mission data."""
    
    def __init__(self) -> None:
        """Initialize resource generator."""
        self.logger = logging.getLogger(__name__)
    
    def generate_mission_resources(self, mission_data: MissionData, 
                                 converted_events: Dict[str, ConvertedEvent],
                                 output_dir: Path) -> List[str]:
        """Generate all mission resource files."""
        try:
            mission_name = self._sanitize_filename(mission_data.mission_info.name or "mission")
            resource_files = []
            
            # 1. Main Mission Resource
            mission_resource_path = output_dir / "resources" / "missions" / f"{mission_name}.tres"
            if self._generate_mission_resource(mission_data, converted_events, mission_resource_path):
                resource_files.append(str(mission_resource_path))
            
            # 2. Ship Configuration Resources
            ships_dir = output_dir / "resources" / "missions" / mission_name / "ships"
            ship_resources = self._generate_ship_resources(mission_data.objects, ships_dir)
            resource_files.extend(ship_resources)
            
            # 3. Wing Configuration Resources
            wings_dir = output_dir / "resources" / "missions" / mission_name / "wings"
            wing_resources = self._generate_wing_resources(mission_data.wings, wings_dir)
            resource_files.extend(wing_resources)
            
            # 4. Event Configuration Resources
            events_dir = output_dir / "resources" / "missions" / mission_name / "events"
            event_resources = self._generate_event_resources(converted_events, events_dir)
            resource_files.extend(event_resources)
            
            # 5. Waypoint Resources
            waypoints_dir = output_dir / "resources" / "missions" / mission_name / "waypoints"
            waypoint_resources = self._generate_waypoint_resources(mission_data.waypoints, waypoints_dir)
            resource_files.extend(waypoint_resources)
            
            self.logger.info(f"Generated {len(resource_files)} mission resource files")
            return resource_files
            
        except Exception as e:
            self.logger.error(f"Failed to generate mission resources: {e}")
            return []
    
    def _generate_mission_resource(self, mission_data: MissionData,
                                  converted_events: Dict[str, ConvertedEvent],
                                  output_path: Path) -> bool:
        """Generate main mission resource file."""
        try:
            # Ensure directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            mission_name = mission_data.mission_info.name or "Unknown Mission"
            
            # Create main mission resource
            resource_content = f'''[gd_resource type="MissionData" script_class="MissionData" load_steps=1 format=3]

[ext_resource type="Script" path="res://addons/wcs_asset_core/resources/mission/mission_data.gd" id="1"]

[resource]
script = ExtResource("1")

# Mission Information (matching MissionData structure)
mission_title = "{mission_name}"
mission_desc = "{self._escape_string(mission_data.mission_info.description or 'No description')}"
mission_notes = "{self._escape_string(mission_data.mission_info.notes)}"

# Mission Metadata (QA REMEDIATION - C++ mission struct fields)
author = "{self._escape_string(mission_data.mission_info.author or '')}"
version = {mission_data.mission_info.version}
created_date = "{self._escape_string(mission_data.mission_info.created or '')}"
modified_date = "{self._escape_string(mission_data.mission_info.modified or '')}"
envmap_name = ""  # Not parsed from FS2 files - would need to be added to parser
contrail_threshold = {mission_data.mission_info.contrail_threshold}

game_type = {mission_data.mission_info.game_type}
flags = {mission_data.mission_info.flags}
num_players = 1

# Ships - use ships array instead of ship_resources
ships = {self._format_resource_array([f"res://resources/missions/{self._sanitize_filename(mission_name)}/ships/{self._sanitize_filename(obj.name)}.tres" for obj in mission_data.objects])}

# Wings - use wings array instead of wing_resources  
wings = {self._format_resource_array([f"res://resources/missions/{self._sanitize_filename(mission_name)}/wings/{self._sanitize_filename(wing.name)}.tres" for wing in mission_data.wings])}

# Events - use events array instead of event_resources
events = {self._format_resource_array([f"res://resources/missions/{self._sanitize_filename(mission_name)}/events/{self._sanitize_filename(event_name)}.tres" for event_name in converted_events.keys()])}

# Waypoint Lists - use waypoint_lists array
waypoint_lists = {self._format_resource_array([f"res://resources/missions/{self._sanitize_filename(mission_name)}/waypoints/{self._sanitize_filename(wp.list_name)}.tres" for wp in self._group_waypoints_by_list(mission_data.waypoints)])}

# Goals - use goals array for objectives
goals = {self._format_resource_array([f"res://resources/missions/{self._sanitize_filename(mission_name)}/goals/{self._sanitize_filename(goal.name or f'goal_{i}')}.tres" for i, goal in enumerate(mission_data.goals)])}

# Variables - use variables array for SEXP variables
variables = {self._format_resource_array([f"res://resources/missions/{self._sanitize_filename(mission_name)}/variables/{self._sanitize_filename(var.name)}.tres" for var in mission_data.variables if hasattr(var, 'name')])}
'''
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(resource_content)
            
            self.logger.info(f"Generated main mission resource: {output_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to generate mission resource: {e}")
            return False
    
    def _generate_ship_resources(self, objects: List[MissionObject], output_dir: Path) -> List[str]:
        """Generate ship configuration resources."""
        resource_files = []
        output_dir.mkdir(parents=True, exist_ok=True)
        
        for obj in objects:
            try:
                ship_name = self._sanitize_filename(obj.name)
                ship_resource_path = output_dir / f"{ship_name}.tres"
                
                # Create ship resource
                resource_content = f'''[gd_resource type="ShipInstanceData" script_class="ShipInstanceData" load_steps=1 format=3]

[ext_resource type="Script" path="res://addons/wcs_asset_core/resources/mission/ship_instance_data.gd" id="1"]

[resource]
script = ExtResource("1")

# Ship Identity (matching ShipInstanceData structure)
ship_name = "{obj.name}"
ship_class_name = "{obj.class_name}"
team = {self._get_team_index(obj.team)}
position = Vector3({obj.position[0]}, {obj.position[1]}, {obj.position[2]})
orientation = {self._format_basis(obj.orientation)}

# AI and Status Configuration
initial_velocity_percent = {obj.initial_velocity}
initial_hull_percent = {obj.initial_hull}
initial_shields_percent = {obj.initial_shields}
ai_behavior = 0
ai_class_name = "{obj.ai_class}"
cargo1_name = "{obj.cargo or 'Nothing'}"
flags = 0
flags2 = 0

# Arrival/Departure Configuration
arrival_location = {self._get_arrival_location_enum(obj.arrival_location)}
arrival_distance = {obj.arrival_distance}
arrival_anchor_name = "{obj.arrival_anchor}"
departure_location = {self._get_departure_location_enum(obj.departure_location)}
departure_anchor_name = "{obj.departure_anchor}"

# Object Status System (QA REMEDIATION - from C++ p_object struct)
# NOTE: Object status data not available in FS2 mission files - would be populated at runtime
# Based on C++ status_type[], status[], target[] arrays for mission object state tracking
object_status_entries = []
'''
                
                with open(ship_resource_path, 'w', encoding='utf-8') as f:
                    f.write(resource_content)
                
                resource_files.append(str(ship_resource_path))
                
            except Exception as e:
                self.logger.error(f"Failed to generate ship resource for {obj.name}: {e}")
        
        return resource_files
    
    def _generate_wing_resources(self, wings: List[MissionWing], output_dir: Path) -> List[str]:
        """Generate wing configuration resources."""
        resource_files = []
        output_dir.mkdir(parents=True, exist_ok=True)
        
        for wing in wings:
            try:
                wing_name = self._sanitize_filename(wing.name)
                wing_resource_path = output_dir / f"{wing_name}.tres"
                
                resource_content = f'''[gd_resource type="WingInstanceData" script_class="WingInstanceData" load_steps=1 format=3]

[ext_resource type="Script" path="res://addons/wcs_asset_core/resources/mission/wing_instance_data.gd" id="1"]

[resource]
script = ExtResource("1")

# Wing Identity (matching WingInstanceData structure)
wing_name = "{wing.name}"
num_waves = {wing.num_waves}
wave_threshold = {wing.threshold}
flags = 0

# Wing Ships
ship_names = {self._format_string_array(wing.ships)}

# Arrival Configuration
arrival_location = {self._get_arrival_location_enum(wing.arrival_location)}
arrival_distance = {wing.arrival_distance}
arrival_anchor_name = "{wing.arrival_anchor}"
arrival_delay_ms = 0

# Departure Configuration
departure_location = {self._get_departure_location_enum(wing.departure_location)}
departure_anchor_name = "{wing.departure_anchor}"
departure_delay_ms = 0

# Wave timing
wave_delay_min = 0
wave_delay_max = 10000
'''
                
                with open(wing_resource_path, 'w', encoding='utf-8') as f:
                    f.write(resource_content)
                
                resource_files.append(str(wing_resource_path))
                
            except Exception as e:
                self.logger.error(f"Failed to generate wing resource for {wing.name}: {e}")
        
        return resource_files
    
    def _generate_event_resources(self, converted_events: Dict[str, ConvertedEvent], 
                                 output_dir: Path) -> List[str]:
        """Generate event configuration resources."""
        resource_files = []
        output_dir.mkdir(parents=True, exist_ok=True)
        
        for event_name, event_data in converted_events.items():
            try:
                event_filename = self._sanitize_filename(event_name)
                event_resource_path = output_dir / f"{event_filename}.tres"
                
                resource_content = f'''[gd_resource type="MissionEventData" script_class="MissionEventData" load_steps=1 format=3]

[ext_resource type="Script" path="res://addons/wcs_asset_core/resources/mission/mission_event_data.gd" id="1"]

[resource]
script = ExtResource("1")

# Event Identity (matching MissionEventData structure)
event_name = "{event_data.original_name}"
repeat_count = {event_data.repeat_count}
trigger_count = 1
interval_ms = {int(event_data.interval * 1000)}
score = 0
team = -1

# Formula as null (would need proper SEXP conversion for SexpNode)
formula = null

# Additional text fields
objective_text = ""
objective_key_text = ""
'''
                
                with open(event_resource_path, 'w', encoding='utf-8') as f:
                    f.write(resource_content)
                
                resource_files.append(str(event_resource_path))
                
            except Exception as e:
                self.logger.error(f"Failed to generate event resource for {event_name}: {e}")
        
        return resource_files
    
    def _generate_waypoint_resources(self, waypoints: List[MissionWaypoint], 
                                   output_dir: Path) -> List[str]:
        """Generate waypoint resources grouped by list."""
        resource_files = []
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Group waypoints by list
        waypoint_lists = {}
        for waypoint in waypoints:
            list_name = waypoint.list_name or "default"
            if list_name not in waypoint_lists:
                waypoint_lists[list_name] = []
            waypoint_lists[list_name].append(waypoint)
        
        # Generate resource for each waypoint list
        for list_name, waypoint_list in waypoint_lists.items():
            try:
                list_filename = self._sanitize_filename(list_name)
                waypoint_resource_path = output_dir / f"{list_filename}.tres"
                
                # Format waypoint positions
                waypoint_positions = []
                for wp in waypoint_list:
                    waypoint_positions.append(f"Vector3({wp.position[0]}, {wp.position[1]}, {wp.position[2]})")
                
                resource_content = f'''[gd_resource type="WaypointListData" script_class="WaypointListData" load_steps=1 format=3]

[ext_resource type="Script" path="res://addons/wcs_asset_core/resources/mission/waypoint_list_data.gd" id="1"]

[resource]
script = ExtResource("1")

# Waypoint List Identity (matching WaypointListData structure)
name = "{list_name}"

# Waypoint Data
waypoints = [{", ".join(waypoint_positions)}]
'''
                
                with open(waypoint_resource_path, 'w', encoding='utf-8') as f:
                    f.write(resource_content)
                
                resource_files.append(str(waypoint_resource_path))
                
            except Exception as e:
                self.logger.error(f"Failed to generate waypoint resource for {list_name}: {e}")
        
        return resource_files
    
    def generate_mission_script_resources(self, output_dir: Path) -> List[str]:
        """Generate the GDScript Resource classes for mission data.
        Note: Using existing mission resource definitions in target/addons/wcs_asset_core/resources/mission/
        This method is kept for backward compatibility but doesn't generate duplicate scripts."""
        script_files = []
        
        # Instead of generating new scripts, reference existing ones
        existing_scripts = [
            "target/addons/wcs_asset_core/resources/mission/mission_data.gd",
            "target/addons/wcs_asset_core/resources/mission/ship_instance_data.gd", 
            "target/addons/wcs_asset_core/resources/mission/wing_instance_data.gd",
            "target/addons/wcs_asset_core/resources/mission/mission_event_data.gd",
            "target/addons/wcs_asset_core/resources/mission/waypoint_list_data.gd"
        ]
        
        # Convert to full paths and add to return list
        base_path = Path(output_dir).parent.parent
        for script_path in existing_scripts:
            full_path = base_path / script_path
            if full_path.exists():
                script_files.append(str(full_path))
        
        self.logger.info(f"Using existing mission resource scripts: {len(script_files)} files found")
        return script_files
    
    def _format_string_array(self, strings: List[str]) -> str:
        """Format array of strings for Godot resource."""
        if not strings:
            return "[]"
        escaped_strings = [f'"{self._escape_string(s)}"' for s in strings]
        return f"[{', '.join(escaped_strings)}]"
    
    def _format_goal_array(self, goals: List) -> str:
        """Format array of goals for Godot resource."""
        if not goals:
            return "[]"
        
        goal_dicts = []
        for goal in goals:
            goal_dict = f'{{"name": "{goal.name or ''}", "type": "{goal.type}", "message": "{self._escape_string(goal.message or '')}"}}'
            goal_dicts.append(goal_dict)
        
        return f"[{', '.join(goal_dicts)}]"
    
    def _format_variable_array(self, variables: List) -> str:
        """Format array of variables for Godot resource."""
        if not variables:
            return "[]"
        
        var_dicts = []
        for var in variables:
            var_dict = f'{{"name": "{var.name}", "type": "{var.type}", "default_value": "{var.default_value}"}}'
            var_dicts.append(var_dict)
        
        return f"[{', '.join(var_dicts)}]"
    
    def _format_dict(self, data: Dict[str, Any]) -> str:
        """Format dictionary for Godot resource."""
        if not data:
            return "{}"
        
        items = []
        for key, value in data.items():
            if isinstance(value, str):
                items.append(f'"{key}": "{self._escape_string(value)}"')
            else:
                items.append(f'"{key}": {value}')
        
        return f"{{{', '.join(items)}}}"
    
    def _escape_string(self, text: str) -> str:
        """Escape string for Godot resource format."""
        if not text:
            return ""
        # Escape quotes and newlines
        return text.replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r')
    
    def _sanitize_filename(self, filename: str) -> str:
        """Sanitize filename for filesystem compatibility."""
        import re

        # Replace invalid characters
        sanitized = re.sub(r'[<>:"/\\|?*]', '_', filename)
        # Remove extra spaces and make lowercase
        sanitized = re.sub(r'\s+', '_', sanitized.strip()).lower()
        # Ensure not empty
        if not sanitized:
            sanitized = "resource"
        return sanitized
    
    def _format_resource_array(self, resource_paths: List[str]) -> str:
        """Format array of resource paths for Godot resource array."""
        if not resource_paths:
            return "[]"
        # Use preload() for resource paths
        resource_refs = [f'preload("{path}")' for path in resource_paths]
        return f"[{', '.join(resource_refs)}]"
    
    def _get_team_index(self, team_name: str) -> int:
        """Convert team name to team index."""
        team_mapping = {
            "friendly": 0,
            "hostile": 1, 
            "neutral": 2,
            "unknown": 3,
            "traitor": 4
        }
        return team_mapping.get(team_name.lower(), 0)
    
    def _format_basis(self, orientation: Tuple[float, float, float]) -> str:
        """Format orientation tuple as Basis."""
        if not orientation or len(orientation) != 3:
            return "Basis.IDENTITY"
        x, y, z = orientation
        # Simple rotation - in full implementation would use proper matrix conversion
        return f"Basis.from_euler(Vector3({x}, {y}, {z}))"
    
    def _get_arrival_location_enum(self, location: str) -> int:
        """Convert arrival location string to enum value."""
        location_mapping = {
            "hyperspace": 0,
            "near_ship": 1,
            "in_front_of_ship": 2,
            "docking_bay": 3
        }
        return location_mapping.get(location.lower(), 0)
    
    def _get_departure_location_enum(self, location: str) -> int:
        """Convert departure location string to enum value."""
        location_mapping = {
            "hyperspace": 0,
            "docking_bay": 1
        }
        return location_mapping.get(location.lower(), 0)
    
    def _group_waypoints_by_list(self, waypoints: List) -> List[str]:
        """Group waypoints by list name and return unique list names."""
        if not waypoints:
            return []
        list_names = set()
        for wp in waypoints:
            if hasattr(wp, 'list_name') and wp.list_name:
                list_names.add(wp.list_name)
        return list(list_names)


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Test resource generation
    generator = MissionResourceGenerator()
    
    # Create test output directory
    test_output = Path("test_output")
    
    # Generate resource scripts
    script_files = generator.generate_mission_script_resources(test_output)
    print(f"Generated {len(script_files)} resource scripts:")
    for script_file in script_files:
        print(f"  {script_file}")