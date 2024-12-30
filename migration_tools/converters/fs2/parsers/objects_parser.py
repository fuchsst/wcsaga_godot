"""Parser for FS2 mission objects section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class ObjectSubsystem:
    """Represents a ship subsystem"""
    name: str = ""
    health: float = 100.0

@dataclass
class ObjectTexture:
    """Represents a texture replacement"""
    old: str = ""
    new: str = ""

@dataclass
class ObjectOrientation:
    """Represents an object's orientation matrix"""
    matrix: List[List[float]] = field(default_factory=lambda: [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
    ])

@dataclass
class MissionObject:
    """Represents a mission object (ship, weapon, etc)"""
    name: str = ""
    class_name: str = ""
    team: str = ""
    callsign: str = ""
    location: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    orientation: ObjectOrientation = field(default_factory=ObjectOrientation)
    ai_behavior: str = ""
    ai_class: str = ""
    ai_goals: List[Dict] = field(default_factory=list)
    cargo: str = ""
    initial_velocity: float = 0.0
    initial_hull: float = 100.0
    initial_shields: float = 100.0
    subsystems: List[ObjectSubsystem] = field(default_factory=list)
    textures: List[ObjectTexture] = field(default_factory=list)
    arrival_location: str = ""
    arrival_cue: str = ""
    arrival_distance: Optional[float] = None
    arrival_anchor: Optional[str] = None
    arrival_paths: List[str] = field(default_factory=list)
    departure_location: str = ""
    departure_cue: str = ""
    departure_anchor: Optional[str] = None
    departure_paths: List[str] = field(default_factory=list)
    determination: int = 10
    flags: List[str] = field(default_factory=list)
    flags2: List[str] = field(default_factory=list)
    respawn_priority: int = 0
    orders_accepted: int = 0
    group: int = 0
    score: int = 0
    persona_index: Optional[int] = None

class ObjectsParser(BaseParser):
    """Parser for FS2 mission objects section"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
    
    def parse(self, lines: Iterator[str]) -> List[MissionObject]:
        """Parse objects section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed MissionObject objects
        """
        objects = []
        current_object = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Name:'):
                # Start new object
                if current_object:
                    objects.append(current_object)
                current_object = MissionObject(
                    name=self._get_value(line)
                )
                
            elif current_object:
                if line.startswith('$Class:'):
                    current_object.class_name = self._get_value(line)
                    
                elif line.startswith('$Team:'):
                    current_object.team = self._get_value(line)
                    
                elif line.startswith('$Callsign:'):
                    current_object.callsign = self._get_value(line)
                    
                elif line.startswith('$Location:'):
                    pos = self._get_value(line).split(',')
                    current_object.location = [float(x.strip()) for x in pos]
                    
                elif line.startswith('$Orientation:'):
                    # Parse 3x3 orientation matrix
                    matrix = []
                    for _ in range(3):
                        line = next(lines).strip().strip(',')
                        row = [float(x.strip()) for x in line.split(',')]
                        matrix.append(row)
                    current_object.orientation.matrix = matrix
                    
                elif line.startswith('$AI Behavior:'):
                    current_object.ai_behavior = self._get_value(line)
                    
                elif line.startswith('+AI Class:'):
                    current_object.ai_class = self._get_value(line)
                    
                elif line.startswith('$AI Goals:'):
                    # Parse multiline SEXP
                    goals_str = self._get_value(line)
                    if goals_str:
                        sexp_lines = self._get_sexp_lines(goals_str, lines)
                        current_object.ai_goals = self.sexp_parser.parse(sexp_lines)
                        
                elif line.startswith('$Cargo 1:'):
                    cargo_text = self._get_value(line)
                    current_object.cargo = cargo_text
                    
                elif line.startswith('+Initial Velocity:'):
                    current_object.initial_velocity = float(self._get_value(line))
                    
                elif line.startswith('+Initial Hull:'):
                    current_object.initial_hull = float(self._get_value(line))
                    
                elif line.startswith('+Initial Shields:'):
                    current_object.initial_shields = float(self._get_value(line))
                    
                elif line.startswith('+Subsystem:'):
                    subsys = ObjectSubsystem(name=self._get_value(line))
                    current_object.subsystems.append(subsys)
                    
                elif line.startswith('+old:'):
                    texture = ObjectTexture(old=self._get_value(line))
                    current_object.textures.append(texture)
                    
                elif line.startswith('+new:'):
                    if current_object.textures:
                        current_object.textures[-1].new = self._get_value(line)
                        
                elif line.startswith('$Arrival Location:'):
                    current_object.arrival_location = self._get_value(line)
                    
                elif line.startswith('+Arrival Distance:'):
                    current_object.arrival_distance = float(self._get_value(line))
                    
                elif line.startswith('$Arrival Anchor:'):
                    current_object.arrival_anchor = self._get_value(line)
                    
                elif line.startswith('+Arrival Paths:'):
                    # Parse path list
                    paths_str = self._get_value(line)
                    if paths_str.startswith('(') and paths_str.endswith(')'):
                        paths_str = paths_str[1:-1].strip()
                        if paths_str:
                            current_object.arrival_paths = [
                                p.strip(' "') for p in paths_str.split()
                            ]
                    
                elif line.startswith('$Arrival Cue:'):
                    # Parse multiline SEXP
                    cue_str = self._get_value(line)
                    if cue_str:
                        sexp_lines = self._get_sexp_lines(cue_str, lines)
                        current_object.arrival_cue = self.sexp_parser.parse(sexp_lines)
                        
                elif line.startswith('$Departure Location:'):
                    current_object.departure_location = self._get_value(line)
                    
                elif line.startswith('$Departure Anchor:'):
                    current_object.departure_anchor = self._get_value(line)
                    
                elif line.startswith('+Departure Paths:'):
                    # Parse path list
                    paths_str = self._get_value(line)
                    if paths_str.startswith('(') and paths_str.endswith(')'):
                        paths_str = paths_str[1:-1].strip()
                        if paths_str:
                            current_object.departure_paths = [
                                p.strip(' "') for p in paths_str.split()
                            ]
                    
                elif line.startswith('$Departure Cue:'):
                    # Parse multiline SEXP
                    cue_str = self._get_value(line)
                    if cue_str:
                        sexp_lines = self._get_sexp_lines(cue_str, lines)
                        current_object.departure_cue = self.sexp_parser.parse(sexp_lines)
                        
                elif line.startswith('$Determination:'):
                    current_object.determination = int(self._get_value(line))
                    
                elif line.startswith('+Flags:'):
                    flags_str = self._get_value(line)
                    if flags_str.startswith('(') and flags_str.endswith(')'):
                        flags_str = flags_str[1:-1].strip()
                        current_object.flags = [f.strip(' "') for f in flags_str.split()]
                        
                elif line.startswith('+Flags2:'):
                    flags_str = self._get_value(line)
                    if flags_str.startswith('(') and flags_str.endswith(')'):
                        flags_str = flags_str[1:-1].strip()
                        current_object.flags2 = [f.strip(' "') for f in flags_str.split()]
                        
                elif line.startswith('+Respawn priority:'):
                    current_object.respawn_priority = int(self._get_value(line))
                    
                elif line.startswith('+Orders Accepted:'):
                    current_object.orders_accepted = int(self._get_value(line))
                    
                elif line.startswith('+Group:'):
                    current_object.group = int(self._get_value(line))
                    
                elif line.startswith('+Score:'):
                    current_object.score = int(self._get_value(line))
                    
                elif line.startswith('+Persona Index:'):
                    current_object.persona_index = int(self._get_value(line))
                    
        # Add final object if exists
        if current_object:
            objects.append(current_object)
            
        return objects
