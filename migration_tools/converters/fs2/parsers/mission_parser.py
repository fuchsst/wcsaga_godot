"""Parser for FS2 mission files"""
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Iterator
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class ViewerOrientation:
    """Represents viewer orientation matrix"""
    matrix: List[List[float]] = field(default_factory=lambda: [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
    ])

@dataclass
class Mission:
    """Mission info section data"""
    # Basic info
    version: str = ""
    name: str = ""
    designer: str = ""  # Author field
    created: str = ""
    modified: str = ""
    notes: str = ""
    description: List[dict] = field(default_factory=list)  # Mission Desc field
    
    # Game settings
    game_type_flags: int = 0
    flags: int = 0
    disallow_support: int = 0
    hull_repair_ceiling: float = 0.0
    subsystem_repair_ceiling: float = 0.0
    
    # Viewer settings
    viewer_pos: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    viewer_orient: ViewerOrientation = field(default_factory=ViewerOrientation)
    
    # Squad settings
    squad_reassign_name: Optional[str] = None
    squad_reassign_logo: Optional[str] = None
    
    # Wing settings
    starting_wing_names: List[str] = field(default_factory=list)
    squadron_wing_names: List[str] = field(default_factory=list)
    team_vs_team_wing_names: List[str] = field(default_factory=list)
    
    # Loading screens
    load_screen_640: Optional[str] = None
    load_screen_1024: Optional[str] = None
    
    # Skybox settings
    skybox_model: Optional[str] = None
    skybox_flags: Optional[int] = None
    
    # AI settings
    ai_profile: Optional[str] = None

class MissionParser(BaseParser):
    """Parser for FS2 mission files"""
    
    def parse(self, lines: Iterator[str]) -> Mission:
        """Parse mission info section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Mission: Parsed mission info data
        """
        mission = Mission()
        self._parse_mission_info(mission, lines)
        return mission
            
    def _parse_mission_info(self, mission: Mission, lines: Iterator[str]):
        """Parse mission info section
        
        Args:
            mission: Mission object to update
            lines: Iterator over lines to parse
            xstr_parser: Parser for XSTR strings
        """
        for line in lines:
            line = line.strip()
            if line.startswith('$Version:'):
                mission.version = self._get_value(line)
            elif line.startswith('$Name:'):
                # Parse XSTR format: XSTR("string", id)
                xstr_text = line.split(':', 1)[1].strip()
                parsed = xstr_text
                if isinstance(parsed, dict):
                    mission.name = parsed['string']
                elif isinstance(parsed, list) and parsed:
                    mission.name = parsed[0]['string']
            elif line.startswith('$Author:'):
                mission.designer = self._get_value(line)
            elif line.startswith('$Created:'):
                mission.created = self._get_value(line)
            elif line.startswith('$Modified:'):
                mission.modified = self._get_value(line)
            elif line.startswith('$Notes:'):
                # Parse multi-line notes until $End Notes:
                notes_lines = []
                line = next(lines).strip()
                while not line.startswith('$End Notes:'):
                    if line.endswith('$End Notes:'):
                        notes_lines.append(line[:-11].strip())
                        break
                    notes_lines.append(line)
                    line = next(lines).strip()
                mission.notes = ' '.join(notes_lines)
            elif line.startswith('$Mission Desc:'):
                # Parse multi-line description with XSTR
                desc_text = ""
                line = next(lines).strip()  # Skip first line
                while not line.startswith('$end_multi_text'):
                    if line:  # Only add non-empty lines
                        if desc_text:
                            desc_text += " "  # Add space between lines
                        desc_text += line
                    line = next(lines).strip()
                
                # Parse the complete XSTR string
                if desc_text:
                    parsed = desc_text
                    if isinstance(parsed, dict):
                        mission.description = [parsed]
                    elif isinstance(parsed, list):
                        mission.description = parsed
            elif line.startswith('+Game Type Flags:'):
                mission.game_type_flags = int(self._get_value(line))
            elif line.startswith('+Flags:'):
                mission.flags = int(self._get_value(line))
            elif line.startswith('+Disallow Support:'):
                mission.disallow_support = int(self._get_value(line))
            elif line.startswith('+Hull Repair Ceiling:'):
                mission.hull_repair_ceiling = float(self._get_value(line))
            elif line.startswith('+Subsystem Repair Ceiling:'):
                mission.subsystem_repair_ceiling = float(self._get_value(line))
            elif line.startswith('+Viewer pos:'):
                # Parse comma-separated coordinates
                pos_str = self._get_value(line)
                pos = [float(x.strip()) for x in pos_str.split(',')]
                mission.viewer_pos = pos
            elif line.startswith('+Viewer orient:'):
                # Parse 3x3 orientation matrix
                matrix = []
                for _ in range(3):
                    line = next(lines).strip().strip(',')
                    row = [float(x.strip()) for x in line.split(',')]
                    matrix.append(row)
                mission.viewer_orient.matrix = matrix
            elif line.startswith('+SquadReassignName:'):
                mission.squad_reassign_name = self._get_value(line)
            elif line.startswith('+SquadReassignLogo:'):
                mission.squad_reassign_logo = self._get_value(line)
            elif line.startswith('$Starting wing names:'):
                # Parse wing list: ( "Wing1" "Wing2" "Wing3" )
                wings_str = line.split(':', 1)[1].strip()
                if wings_str.startswith('(') and wings_str.endswith(')'):
                    wings_str = wings_str[1:-1].strip()
                    mission.starting_wing_names = [
                        w.strip(' "') for w in wings_str.split()
                    ]
            elif line.startswith('$Squadron wing names:'):
                wings_str = line.split(':', 1)[1].strip()
                if wings_str.startswith('(') and wings_str.endswith(')'):
                    wings_str = wings_str[1:-1].strip()
                    mission.squadron_wing_names = [
                        w.strip(' "') for w in wings_str.split()
                    ]
            elif line.startswith('$Team-versus-team wing names:'):
                wings_str = line.split(':', 1)[1].strip()
                if wings_str.startswith('(') and wings_str.endswith(')'):
                    wings_str = wings_str[1:-1].strip()
                    mission.team_vs_team_wing_names = [
                        w.strip(' "') for w in wings_str.split()
                    ]
            elif line.startswith('$Load Screen 640:'):
                mission.load_screen_640 = self._get_value(line)
            elif line.startswith('$Load Screen 1024:'):
                mission.load_screen_1024 = self._get_value(line)
            elif line.startswith('$Skybox Model:'):
                mission.skybox_model = self._get_value(line)
            elif line.startswith('+Skybox Flags:'):
                mission.skybox_flags = int(self._get_value(line))
            elif line.startswith('$AI Profile:'):
                mission.ai_profile = self._get_value(line)
