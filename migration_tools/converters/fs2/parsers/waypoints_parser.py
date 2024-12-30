"""Parser for FS2 mission waypoints section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator
from .base_parser import BaseParser

@dataclass
class Waypoint:
    """Represents a single waypoint position"""
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0

@dataclass
class WaypointList:
    """Represents a list of waypoints"""
    name: str = ""
    points: List[Waypoint] = field(default_factory=list)

class WaypointsParser(BaseParser):
    """Parser for FS2 mission waypoints section"""
    
    def parse(self, lines: Iterator[str]) -> List[WaypointList]:
        """Parse waypoints section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed WaypointList objects
        """
        waypoint_lists = []
        current_list = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Name:'):
                # Start new waypoint list
                if current_list:
                    waypoint_lists.append(current_list)
                current_list = WaypointList(
                    name=line.split(':', 1)[1].strip()
                )
                
            elif current_list and line.startswith('$List:'):
                # Parse waypoint list
                # Skip the opening parenthesis line
                try:
                    line = next(lines).strip()
                    while line and not line.startswith(')'):
                        if line.startswith('('):
                            # Parse waypoint coordinates
                            coords = line.strip('( )').split(',')
                            if len(coords) >= 3:
                                waypoint = Waypoint(
                                    x=float(coords[0].strip()),
                                    y=float(coords[1].strip()),
                                    z=float(coords[2].strip())
                                )
                                current_list.points.append(waypoint)
                        line = next(lines).strip()
                except (StopIteration, ValueError):
                    pass
                    
        # Add final list if exists
        if current_list:
            waypoint_lists.append(current_list)
            
        return waypoint_lists
