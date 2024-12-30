"""Parser for FS2 mission wings section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class MissionWing:
    """Represents a mission wing"""
    name: str = ""
    waves: int = 1
    wave_threshold: int = 0
    special_ship: int = 0
    arrival_location: str = ""
    arrival_cue: str = ""
    arrival_distance: Optional[float] = None
    arrival_anchor: Optional[str] = None
    arrival_paths: List[str] = field(default_factory=list)
    departure_location: str = ""
    departure_cue: str = ""
    departure_anchor: Optional[str] = None
    departure_paths: List[str] = field(default_factory=list)
    ships: List[str] = field(default_factory=list)
    ai_goals: List[Dict] = field(default_factory=list)
    hotkey: Optional[int] = None
    flags: List[str] = field(default_factory=list)

class WingsParser(BaseParser):
    """Parser for FS2 mission wings section"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
    
    def parse(self, lines: Iterator[str]) -> List[MissionWing]:
        """Parse wings section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed MissionWing objects
        """
        wings = []
        current_wing = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Name:'):
                # Start new wing
                if current_wing:
                    wings.append(current_wing)
                current_wing = MissionWing(
                    name=self._get_value(line)
                )
                
            elif current_wing:
                if line.startswith('$Waves:'):
                    current_wing.waves = int(self._get_value(line))
                    
                elif line.startswith('$Wave Threshold:'):
                    current_wing.wave_threshold = int(self._get_value(line))
                    
                elif line.startswith('$Special Ship:'):
                    current_wing.special_ship = int(self._get_value(line))
                    
                elif line.startswith('$Arrival Location:'):
                    current_wing.arrival_location = self._get_value(line)
                    
                elif line.startswith('+Arrival Distance:'):
                    current_wing.arrival_distance = float(self._get_value(line))
                    
                elif line.startswith('$Arrival Anchor:'):
                    current_wing.arrival_anchor = self._get_value(line)
                    
                elif line.startswith('+Arrival Paths:'):
                    # Parse path list
                    paths_str = line.split(':', 1)[1].strip()
                    if paths_str.startswith('(') and paths_str.endswith(')'):
                        paths_str = paths_str[1:-1].strip()
                        if paths_str:
                            current_wing.arrival_paths = [
                                p.strip(' "') for p in paths_str.split()
                            ]
                    
                elif line.startswith('$Arrival Cue:'):
                    # Parse multiline SEXP
                    cue_str = self._get_value(line)
                    if cue_str:
                        sexp_lines = self._get_sexp_lines(cue_str, lines)
                        current_wing.arrival_cue = self.sexp_parser.parse(sexp_lines)

                elif line.startswith('$Departure Location:'):
                    current_wing.departure_location = self._get_value(line)
                    
                elif line.startswith('$Departure Anchor:'):
                    current_wing.departure_anchor = self._get_value(line)
                    
                elif line.startswith('+Departure Paths:'):
                    # Parse path list
                    paths_str = line.split(':', 1)[1].strip()
                    if paths_str.startswith('(') and paths_str.endswith(')'):
                        paths_str = paths_str[1:-1].strip()
                        if paths_str:
                            current_wing.departure_paths = [
                                p.strip(' "') for p in paths_str.split()
                            ]
                    
                elif line.startswith('$Departure Cue:'):
                    # Parse multiline SEXP
                    cue_str = self._get_value(line)
                    if cue_str:
                        sexp_lines = self._get_sexp_lines(cue_str, lines)
                        current_wing.departure_cue = self.sexp_parser.parse(sexp_lines)

                elif line.startswith('$Ships:'):
                    # Parse ship list
                    ships_str = self._get_value(line)
                    if ships_str.startswith('(') and ships_str.endswith(')'):
                        ships_str = ships_str[1:-1].strip()
                        if ships_str:
                            current_wing.ships = [
                                s.strip(' "') for s in ships_str.split()
                            ]
                            
                elif line.startswith('$AI Goals:'):
                    # Parse multiline SEXP
                    goals_str = self._get_value(line)
                    if goals_str:
                        sexp_lines = self._get_sexp_lines(goals_str, lines)
                        current_wing.ai_goals = self.sexp_parser.parse(sexp_lines)

                elif line.startswith('+Hotkey:'):
                    current_wing.hotkey = int(line.split(':', 1)[1].strip())
                    
                elif line.startswith('+Flags:'):
                    flags_str = self._get_value(line)
                    if flags_str.startswith('(') and flags_str.endswith(')'):
                        flags_str = flags_str[1:-1].strip()
                        current_wing.flags = [f.strip(' "') for f in flags_str.split()]
                    
        # Add final wing if exists
        if current_wing:
            wings.append(current_wing)
            
        return wings

    def get_wing_flag_names(self, flags: List[str]) -> List[str]:
        """Get human-readable names for wing flags
        
        Args:
            flags: List of flag strings
            
        Returns:
            list: List of standardized flag names
        """
        flag_map = {
            "no-arrival-music": "No Arrival Music",
            "no-arrival-message": "No Arrival Message",
            "no-arrival-warp": "No Arrival Warp",
            "no-departure-warp": "No Departure Warp",
            "no-dynamic": "No Dynamic",
            "no-arrival-log": "No Arrival Log",
            "no-departure-log": "No Departure Log"
        }
        return [flag_map.get(f, f) for f in flags]
