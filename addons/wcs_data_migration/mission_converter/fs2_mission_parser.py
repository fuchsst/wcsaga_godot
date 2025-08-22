#!/usr/bin/env python3
"""
FS2 Mission File Parser - EPIC-003 DM-007 Implementation

Parses FS2 mission files (.fs2) extracting mission info, ships, wings, waypoints,
events, goals, and briefing data with complete fidelity.

Based on WCS source code analysis: source/code/mission/missionparse.cpp
"""

import logging
import re
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union


class MissionGameType(Enum):
    """Mission game type flags."""
    SINGLE = 1
    MULTI = 2
    TRAINING = 4
    MULTI_COOP = 8
    MULTI_TEAM = 16
    MULTI_DOGFIGHT = 32


class ObjectType(Enum):
    """Mission object types."""
    SHIP = "ship"
    WING = "wing"
    WAYPOINT = "waypoint" 
    START = "start"
    JUMPNODE = "jumpnode"


@dataclass
class MissionInfo:
    """Mission header information."""
    version: float = 0.0
    name: str = ""
    author: str = ""
    created: str = ""
    modified: str = ""
    notes: str = ""
    description: str = ""
    game_type: int = MissionGameType.SINGLE.value
    flags: int = 0
    contrail_threshold: int = 20


@dataclass
class MissionObject:
    """Represents a mission object (ship, wing, etc.)."""
    name: str = ""
    class_name: str = ""
    object_type: ObjectType = ObjectType.SHIP
    position: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    orientation: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    team: str = "friendly"
    ai_class: str = ""
    cargo: str = ""
    initial_velocity: int = 0
    initial_hull: int = 100
    initial_shields: int = 100
    subsystem_status: Dict[str, int] = field(default_factory=dict)
    arrival_location: str = "Hyperspace"
    arrival_distance: int = 0
    arrival_anchor: str = ""
    departure_location: str = "Hyperspace"
    departure_anchor: str = ""
    orders: List[str] = field(default_factory=list)
    goals: List[str] = field(default_factory=list)


@dataclass
class MissionWing:
    """Represents a mission wing."""
    name: str = ""
    num_waves: int = 1
    threshold: int = 0
    arrival_location: str = "Hyperspace"
    arrival_distance: int = 0
    arrival_anchor: str = ""
    departure_location: str = "Hyperspace"  
    departure_anchor: str = ""
    ships: List[str] = field(default_factory=list)
    arrival_cue: str = "true"
    departure_cue: str = "false"
    orders: List[str] = field(default_factory=list)
    goals: List[str] = field(default_factory=list)


@dataclass
class MissionWaypoint:
    """Represents a mission waypoint."""
    name: str = ""
    list_name: str = ""
    position: Tuple[float, float, float] = (0.0, 0.0, 0.0)


@dataclass
class MissionEvent:
    """Represents a mission event."""
    name: str = ""
    repeat_count: int = 1
    interval: int = 1
    score: int = 0
    chained: bool = False
    objective_text: str = ""
    objective_key_text: str = ""
    team: int = -1
    log: bool = True
    end_mission: bool = False
    formula: str = ""  # SEXP expression


@dataclass
class MissionGoal:
    """Represents a mission goal."""
    type: str = "primary"
    name: str = ""
    message: str = ""
    invalid: bool = False
    no_music: bool = False
    team: int = 0
    formula: str = ""  # SEXP expression


@dataclass
class MissionVariable:
    """Represents a mission variable."""
    name: str = ""
    type: str = "number"
    default_value: str = "0"


@dataclass
class MissionData:
    """Complete mission data structure."""
    mission_info: MissionInfo = field(default_factory=MissionInfo)
    objects: List[MissionObject] = field(default_factory=list)
    wings: List[MissionWing] = field(default_factory=list)
    waypoints: List[MissionWaypoint] = field(default_factory=list)
    events: List[MissionEvent] = field(default_factory=list)
    goals: List[MissionGoal] = field(default_factory=list)
    variables: List[MissionVariable] = field(default_factory=list)
    messages: List[str] = field(default_factory=list)
    
    # Metadata
    source_file: str = ""
    parse_warnings: List[str] = field(default_factory=list)
    parse_errors: List[str] = field(default_factory=list)


class FS2MissionParser:
    """Parses FS2 mission files with complete fidelity."""
    
    def __init__(self) -> None:
        """Initialize parser with logging."""
        self.logger = logging.getLogger(__name__)
        self.current_line_number: int = 0
        self.current_section: str = ""
        self.parse_warnings: List[str] = []
        self.parse_errors: List[str] = []
    
    def parse_mission_file(self, mission_path: Path) -> Optional[MissionData]:
        """Parse complete FS2 mission file."""
        try:
            self.logger.info(f"Parsing mission file: {mission_path}")
            
            # Initialize mission data
            mission_data = MissionData()
            mission_data.source_file = str(mission_path)
            
            # Reset parser state
            self.current_line_number = 0
            self.current_section = ""
            self.parse_warnings.clear()
            self.parse_errors.clear()
            
            # Read mission file
            with open(mission_path, 'r', encoding='latin-1') as file:
                lines = file.readlines()
            
            # Parse mission sections in order following missionparse.cpp structure
            self._parse_mission_sections(lines, mission_data)
            
            # Store warnings and errors
            mission_data.parse_warnings = self.parse_warnings.copy()
            mission_data.parse_errors = self.parse_errors.copy()
            
            # Validate parsing results
            if self._validate_mission_data(mission_data):
                self.logger.info(f"Successfully parsed mission: {mission_data.mission_info.name}")
                return mission_data
            else:
                self.logger.error(f"Mission validation failed: {len(self.parse_errors)} errors")
                return None
                
        except Exception as e:
            self.logger.error(f"Failed to parse mission file {mission_path}: {e}")
            return None
    
    def _parse_mission_sections(self, lines: List[str], mission_data: MissionData) -> None:
        """Parse mission file sections following FS2 format."""
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            self.current_line_number = i + 1
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Parse section headers
            if line.startswith('#'):
                section_name = line[1:].lower()
                self.current_section = section_name
                
                if section_name == "mission info":
                    i = self._parse_mission_info_section(lines, i, mission_data)
                elif section_name == "objects":
                    i = self._parse_objects_section(lines, i, mission_data)
                elif section_name == "wings":
                    i = self._parse_wings_section(lines, i, mission_data)
                elif section_name == "events":
                    i = self._parse_events_section(lines, i, mission_data)
                elif section_name == "goals":
                    i = self._parse_goals_section(lines, i, mission_data)
                elif section_name == "waypoints":
                    i = self._parse_waypoints_section(lines, i, mission_data)
                elif section_name == "variables":
                    i = self._parse_variables_section(lines, i, mission_data)
                elif section_name == "messages":
                    i = self._parse_messages_section(lines, i, mission_data)
                else:
                    # Skip unknown sections
                    self._add_warning(f"Unknown section: {section_name}")
                    i += 1
            else:
                i += 1
    
    def _parse_mission_info_section(self, lines: List[str], start_index: int, 
                                   mission_data: MissionData) -> int:
        """Parse #Mission Info section."""
        i = start_index + 1  # Skip section header
        mission_info = MissionInfo()
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Parse mission info fields following missionparse.cpp structure
            if line.startswith('$Version:'):
                mission_info.version = self._extract_float_value(line)
            elif line.startswith('$Name:'):
                mission_info.name = self._extract_string_value(line)
            elif line.startswith('$Author:'):
                mission_info.author = self._extract_string_value(line)
            elif line.startswith('$Created:'):
                mission_info.created = self._extract_string_value(line)
            elif line.startswith('$Modified:'):
                mission_info.modified = self._extract_string_value(line)
            elif line.startswith('$Notes:'):
                mission_info.notes = self._extract_multiline_value(lines, i)
            elif line.startswith('$Mission Desc:'):
                mission_info.description = self._extract_multiline_value(lines, i)
            elif line.startswith('+Game Type Flags:'):
                mission_info.game_type = self._extract_int_value(line)
            elif line.startswith('+Flags:'):
                mission_info.flags = self._extract_int_value(line)
            elif line.startswith('$Contrail Speed Threshold:'):
                mission_info.contrail_threshold = self._extract_int_value(line)
            
            i += 1
        
        mission_data.mission_info = mission_info
        return i
    
    def _parse_objects_section(self, lines: List[str], start_index: int, 
                              mission_data: MissionData) -> int:
        """Parse #Objects section."""
        i = start_index + 1  # Skip section header
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Parse individual object
            if line.startswith('$Name:'):
                obj, i = self._parse_single_object(lines, i)
                if obj:
                    mission_data.objects.append(obj)
            else:
                i += 1
        
        return i
    
    def _parse_single_object(self, lines: List[str], start_index: int) -> Tuple[Optional[MissionObject], int]:
        """Parse a single mission object."""
        i = start_index
        obj = MissionObject()
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Stop at next object or section
            if line.startswith('$Name:') and i != start_index:
                break
            if line.startswith('#'):
                break
            
            # Parse object properties
            if line.startswith('$Name:'):
                obj.name = self._extract_string_value(line)
            elif line.startswith('$Class:'):
                obj.class_name = self._extract_string_value(line)
            elif line.startswith('$Team:'):
                obj.team = self._extract_string_value(line)
            elif line.startswith('$Location:'):
                coords = self._extract_coordinates(line)
                if coords:
                    obj.position = coords
            elif line.startswith('$Orientation:'):
                orientation = self._extract_orientation_matrix(lines, i)
                if orientation:
                    obj.orientation = orientation
            elif line.startswith('+AI Class:'):
                obj.ai_class = self._extract_string_value(line)
            elif line.startswith('+Cargo 1:'):
                obj.cargo = self._extract_string_value(line)
            elif line.startswith('+Initial Velocity:'):
                obj.initial_velocity = self._extract_int_value(line)
            elif line.startswith('+Initial Hull:'):
                obj.initial_hull = self._extract_int_value(line)
            elif line.startswith('+Initial Shields:'):
                obj.initial_shields = self._extract_int_value(line)
            elif line.startswith('+Arrival Location:'):
                obj.arrival_location = self._extract_string_value(line)
            elif line.startswith('+Arrival Distance:'):
                obj.arrival_distance = self._extract_int_value(line)
            elif line.startswith('+Arrival Anchor:'):
                obj.arrival_anchor = self._extract_string_value(line)
            elif line.startswith('+Departure Location:'):
                obj.departure_location = self._extract_string_value(line)
            elif line.startswith('+Departure Anchor:'):
                obj.departure_anchor = self._extract_string_value(line)
            
            i += 1
        
        return obj, i
    
    def _parse_wings_section(self, lines: List[str], start_index: int, 
                            mission_data: MissionData) -> int:
        """Parse #Wings section."""
        i = start_index + 1  # Skip section header
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Parse individual wing
            if line.startswith('$Name:'):
                wing, i = self._parse_single_wing(lines, i)
                if wing:
                    mission_data.wings.append(wing)
            else:
                i += 1
        
        return i
    
    def _parse_single_wing(self, lines: List[str], start_index: int) -> Tuple[Optional[MissionWing], int]:
        """Parse a single mission wing."""
        i = start_index
        wing = MissionWing()
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Stop at next wing or section
            if line.startswith('$Name:') and i != start_index:
                break
            if line.startswith('#'):
                break
            
            # Parse wing properties
            if line.startswith('$Name:'):
                wing.name = self._extract_string_value(line)
            elif line.startswith('$Num Waves:'):
                wing.num_waves = self._extract_int_value(line)
            elif line.startswith('$Threshold:'):
                wing.threshold = self._extract_int_value(line)
            elif line.startswith('$Arrival Location:'):
                wing.arrival_location = self._extract_string_value(line)
            elif line.startswith('$Arrival Distance:'):
                wing.arrival_distance = self._extract_int_value(line)
            elif line.startswith('$Arrival Anchor:'):
                wing.arrival_anchor = self._extract_string_value(line)
            elif line.startswith('$Departure Location:'):
                wing.departure_location = self._extract_string_value(line)
            elif line.startswith('$Departure Anchor:'):
                wing.departure_anchor = self._extract_string_value(line)
            elif line.startswith('$Arrival Cue:'):
                wing.arrival_cue = self._extract_sexp_value(lines, i)
            elif line.startswith('$Departure Cue:'):
                wing.departure_cue = self._extract_sexp_value(lines, i)
            elif line.startswith('$Ships:'):
                # Parse ship list
                i += 1
                while i < len(lines) and not lines[i].strip().startswith('$') and not lines[i].strip().startswith('#'):
                    ship_line = lines[i].strip()
                    if ship_line and not ship_line.startswith(';'):
                        wing.ships.append(ship_line.strip('"'))
                    i += 1
                continue  # Don't increment i again
            
            i += 1
        
        return wing, i
    
    def _parse_events_section(self, lines: List[str], start_index: int, 
                             mission_data: MissionData) -> int:
        """Parse #Events section."""
        i = start_index + 1  # Skip section header
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Parse individual event
            if line.startswith('$Formula:'):
                event, i = self._parse_single_event(lines, i)
                if event:
                    mission_data.events.append(event)
            else:
                i += 1
        
        return i
    
    def _parse_single_event(self, lines: List[str], start_index: int) -> Tuple[Optional[MissionEvent], int]:
        """Parse a single mission event."""
        i = start_index
        event = MissionEvent()
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Stop at next event or section
            if line.startswith('$Formula:') and i != start_index:
                break
            if line.startswith('#'):
                break
            
            # Parse event properties
            if line.startswith('$Formula:'):
                event.formula = self._extract_sexp_value(lines, i)
            elif line.startswith('+Name:'):
                event.name = self._extract_string_value(line)
            elif line.startswith('+Repeat Count:'):
                event.repeat_count = self._extract_int_value(line)
            elif line.startswith('+Interval:'):
                event.interval = self._extract_int_value(line)
            elif line.startswith('+Score:'):
                event.score = self._extract_int_value(line)
            elif line.startswith('+Chained:'):
                event.chained = self._extract_bool_value(line)
            elif line.startswith('+Objective Text:'):
                event.objective_text = self._extract_string_value(line)
            elif line.startswith('+Objective Key Text:'):
                event.objective_key_text = self._extract_string_value(line)
            elif line.startswith('+Team:'):
                event.team = self._extract_int_value(line)
            elif line.startswith('+Log:'):
                event.log = self._extract_bool_value(line)
            elif line.startswith('+End Mission:'):
                event.end_mission = self._extract_bool_value(line)
            
            i += 1
        
        return event, i
    
    def _parse_goals_section(self, lines: List[str], start_index: int, 
                            mission_data: MissionData) -> int:
        """Parse #Goals section."""
        i = start_index + 1  # Skip section header
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Parse individual goal
            if line.startswith('$Type:'):
                goal, i = self._parse_single_goal(lines, i)
                if goal:
                    mission_data.goals.append(goal)
            else:
                i += 1
        
        return i
    
    def _parse_single_goal(self, lines: List[str], start_index: int) -> Tuple[Optional[MissionGoal], int]:
        """Parse a single mission goal."""
        i = start_index
        goal = MissionGoal()
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Stop at next goal or section
            if line.startswith('$Type:') and i != start_index:
                break
            if line.startswith('#'):
                break
            
            # Parse goal properties
            if line.startswith('$Type:'):
                goal.type = self._extract_string_value(line).lower()
            elif line.startswith('$MessageNew:'):
                goal.name = self._extract_string_value(line)
            elif line.startswith('$Message:'):
                goal.message = self._extract_string_value(line)
            elif line.startswith('+Invalid:'):
                goal.invalid = self._extract_bool_value(line)
            elif line.startswith('+No Music:'):
                goal.no_music = self._extract_bool_value(line)
            elif line.startswith('+Team:'):
                goal.team = self._extract_int_value(line)
            elif line.startswith('$Formula:'):
                goal.formula = self._extract_sexp_value(lines, i)
            
            i += 1
        
        return goal, i
    
    def _parse_waypoints_section(self, lines: List[str], start_index: int, 
                                mission_data: MissionData) -> int:
        """Parse #Waypoints section."""
        i = start_index + 1  # Skip section header
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Parse waypoint list
            if line.startswith('$Name:'):
                list_name = self._extract_string_value(line)
                i += 1
                
                # Parse waypoints in this list
                while i < len(lines):
                    line = lines[i].strip()
                    if not line or line.startswith(';'):
                        i += 1
                        continue
                    
                    if line.startswith('$Name:') or line.startswith('#'):
                        break
                    
                    if line.startswith('$List:'):
                        i += 1
                        continue
                    
                    # Parse individual waypoint coordinates
                    coords = self._extract_coordinates(line)
                    if coords:
                        waypoint = MissionWaypoint()
                        waypoint.list_name = list_name
                        waypoint.name = f"{list_name}_{len(mission_data.waypoints)}"
                        waypoint.position = coords
                        mission_data.waypoints.append(waypoint)
                    
                    i += 1
            else:
                i += 1
        
        return i
    
    def _parse_variables_section(self, lines: List[str], start_index: int, 
                                mission_data: MissionData) -> int:
        """Parse #Variables section."""
        i = start_index + 1  # Skip section header
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Parse variable definition
            if line.startswith('$Name:'):
                var = MissionVariable()
                var.name = self._extract_string_value(line)
                i += 1
                
                # Parse variable properties
                while i < len(lines):
                    line = lines[i].strip()
                    if not line or line.startswith(';'):
                        i += 1
                        continue
                    
                    if line.startswith('$Name:') or line.startswith('#'):
                        break
                    
                    if line.startswith('$Type:'):
                        var.type = self._extract_string_value(line).lower()
                    elif line.startswith('$Value:'):
                        var.default_value = self._extract_string_value(line)
                    
                    i += 1
                
                mission_data.variables.append(var)
            else:
                i += 1
        
        return i
    
    def _parse_messages_section(self, lines: List[str], start_index: int, 
                               mission_data: MissionData) -> int:
        """Parse #Messages section."""
        i = start_index + 1  # Skip section header
        
        while i < len(lines):
            line = lines[i].strip()
            if not line or line.startswith(';'):
                i += 1
                continue
            
            # Check for next section
            if line.startswith('#'):
                break
            
            # Simple message parsing for now
            if line.startswith('$Name:'):
                message_name = self._extract_string_value(line)
                mission_data.messages.append(message_name)
            
            i += 1
        
        return i
    
    def _extract_string_value(self, line: str) -> str:
        """Extract string value from mission file line."""
        # Handle both quoted and unquoted strings
        if ':' in line:
            value = line.split(':', 1)[1].strip()
            if value.startswith('"') and value.endswith('"'):
                return value[1:-1]
            return value
        return ""
    
    def _extract_int_value(self, line: str) -> int:
        """Extract integer value from mission file line."""
        try:
            value_str = self._extract_string_value(line)
            return int(value_str)
        except ValueError:
            self._add_warning(f"Invalid integer value: {line}")
            return 0
    
    def _extract_float_value(self, line: str) -> float:
        """Extract float value from mission file line."""
        try:
            value_str = self._extract_string_value(line)
            return float(value_str)
        except ValueError:
            self._add_warning(f"Invalid float value: {line}")
            return 0.0
    
    def _extract_bool_value(self, line: str) -> bool:
        """Extract boolean value from mission file line."""
        value_str = self._extract_string_value(line).lower()
        return value_str in ('true', '1', 'yes')
    
    def _extract_coordinates(self, line: str) -> Optional[Tuple[float, float, float]]:
        """Extract 3D coordinates from mission file line."""
        try:
            # Remove any leading identifiers and extract coordinate part
            coord_part = line
            if ':' in line:
                coord_part = line.split(':', 1)[1].strip()
            
            # Parse coordinates (space or comma separated)
            coords = re.findall(r'-?\d+\.?\d*', coord_part)
            if len(coords) >= 3:
                return (float(coords[0]), float(coords[1]), float(coords[2]))
            return None
        except ValueError:
            self._add_warning(f"Invalid coordinates: {line}")
            return None
    
    def _extract_orientation_matrix(self, lines: List[str], start_index: int) -> Optional[Tuple[float, float, float]]:
        """Extract orientation matrix and convert to Euler angles."""
        try:
            # For now, extract just the first row as representative orientation
            # Full matrix parsing would require more complex math
            line = lines[start_index]
            coords = self._extract_coordinates(line)
            return coords
        except (IndexError, ValueError):
            self._add_warning(f"Invalid orientation matrix at line {start_index}")
            return None
    
    def _extract_multiline_value(self, lines: List[str], start_index: int) -> str:
        """Extract multiline string value."""
        result = []
        i = start_index
        
        # Get the first line value
        first_line = lines[i].strip()
        if ':' in first_line:
            first_value = first_line.split(':', 1)[1].strip()
            if first_value.startswith('"'):
                # Multiline quoted string
                first_value = first_value[1:]  # Remove opening quote
                result.append(first_value)
                
                i += 1
                while i < len(lines):
                    line = lines[i].strip()
                    if line.endswith('"'):
                        result.append(line[:-1])  # Remove closing quote
                        break
                    result.append(line)
                    i += 1
            else:
                result.append(first_value)
        
        return '\n'.join(result)
    
    def _extract_sexp_value(self, lines: List[str], start_index: int) -> str:
        """Extract SEXP expression value (can be multiline)."""
        result = []
        i = start_index
        paren_count = 0
        
        # Start with the formula line
        line = lines[i].strip()
        if ':' in line:
            formula_part = line.split(':', 1)[1].strip()
            result.append(formula_part)
            paren_count += formula_part.count('(') - formula_part.count(')')
        
        # Continue reading if we have unclosed parentheses
        i += 1
        while i < len(lines) and paren_count > 0:
            line = lines[i].strip()
            if line and not line.startswith('$') and not line.startswith('+') and not line.startswith('#'):
                result.append(line)
                paren_count += line.count('(') - line.count(')')
            else:
                break
            i += 1
        
        return ' '.join(result).strip()
    
    def _validate_mission_data(self, mission_data: MissionData) -> bool:
        """Validate parsed mission data for completeness."""
        is_valid = True
        
        # Check required mission info
        if not mission_data.mission_info.name:
            self._add_error("Mission name is required")
            is_valid = False
        
        if mission_data.mission_info.version <= 0:
            self._add_error("Mission version is required")
            is_valid = False
        
        # Validate objects
        for obj in mission_data.objects:
            if not obj.name:
                self._add_error("Object missing name")
                is_valid = False
            if not obj.class_name:
                self._add_error(f"Object '{obj.name}' missing class")
                is_valid = False
        
        # Validate wings
        for wing in mission_data.wings:
            if not wing.name:
                self._add_error("Wing missing name")
                is_valid = False
        
        # Check for circular references and other logical issues
        # TODO: Add more validation as needed
        
        return is_valid
    
    def _add_warning(self, message: str) -> None:
        """Add parsing warning."""
        warning = f"Line {self.current_line_number} ({self.current_section}): {message}"
        self.parse_warnings.append(warning)
        self.logger.warning(warning)
    
    def _add_error(self, message: str) -> None:
        """Add parsing error."""
        error = f"Line {self.current_line_number} ({self.current_section}): {message}"
        self.parse_errors.append(error)
        self.logger.error(error)


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Test parser
    parser = FS2MissionParser()
    
    # Example: parse a test mission file
    test_mission_path = Path("test_mission.fs2")
    if test_mission_path.exists():
        mission_data = parser.parse_mission_file(test_mission_path)
        if mission_data:
            print(f"Parsed mission: {mission_data.mission_info.name}")
            print(f"Objects: {len(mission_data.objects)}")
            print(f"Wings: {len(mission_data.wings)}")
            print(f"Events: {len(mission_data.events)}")
            print(f"Goals: {len(mission_data.goals)}")
            print(f"Warnings: {len(mission_data.parse_warnings)}")
            print(f"Errors: {len(mission_data.parse_errors)}")
    else:
        print("Test mission file not found")