"""Parser for FS2 mission goals"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class MissionGoal:
    """Represents a mission goal/objective"""
    name: str = ""
    type: str = ""  # Primary, Secondary, or Bonus
    text: List[dict] = field(default_factory=list)  # XSTR entries
    formula: Dict = field(default_factory=dict)  # Parsed SEXP formula
    score: int = 0
    team: int = 0
    invalid: bool = False
    flags: int = 0
    message: str = ""

class GoalsParser(BaseParser):
    """Parser for FS2 mission goals"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
        
    def parse(self, lines: Iterator[str]) -> List[MissionGoal]:
        """Parse mission goals
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed MissionGoal objects
        """
        goals = []
        current_goal = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Type:'):
                # Start new goal
                if current_goal:
                    goals.append(current_goal)
                current_goal = MissionGoal(
                    type=self._get_value(line)
                )
                
            elif current_goal:
                if line.startswith('+Name:'):
                    current_goal.name = self._get_value(line)
                    
                elif line.startswith('+MessageNew:'):
                    # Parse multi-line message text
                    msg_lines = []
                    line = next(lines).strip()  # Skip first line
                    while not line.startswith('$end_multi_text'):
                        msg_lines.append(line)
                        line = next(lines).strip()
                    current_goal.text = self.xstr_parser.parse(iter(msg_lines))
                    
                elif line.startswith('+Formula:'):
                    # Parse multiline SEXP formula
                    formula_str = self._get_value(line)
                    if formula_str:
                        sexp_lines = self._get_sexp_lines(formula_str, lines)
                        current_goal.formula = self.sexp_parser.parse(sexp_lines)
                    
                elif line.startswith('+Score:'):
                    current_goal.score = int(self._get_value(line))
                    
                elif line.startswith('+Team:'):
                    current_goal.team = int(self._get_value(line))
                    
                elif line.startswith('+Invalid:'):
                    current_goal.invalid = bool(int(self._get_value(line)))
                    
                elif line.startswith('+Flags:'):
                    current_goal.flags = int(self._get_value(line))
                    
                elif line.startswith('+Message:'):
                    current_goal.message = self._get_value(line)
                    
        # Add final goal if exists
        if current_goal:
            goals.append(current_goal)
            
        return goals

    def get_goal_type_name(self, goal_type: str) -> str:
        """Get standardized name for goal type
        
        Args:
            goal_type: Raw goal type string
            
        Returns:
            str: Standardized goal type name
        """
        type_map = {
            "primary": "Primary",
            "secondary": "Secondary", 
            "bonus": "Bonus"
        }
        return type_map.get(goal_type.lower(), goal_type)

    def get_goal_flag_names(self, flags: int) -> List[str]:
        """Get human-readable names for goal flags
        
        Args:
            flags: Goal flags value
            
        Returns:
            list: List of flag names that are set
        """
        flag_names = {
            0: "valid",
            1: "invalid",
            2: "no-music",
            3: "no-scoring",
            4: "hidden",
            5: "failed"
        }
        
        active_flags = []
        for bit, name in flag_names.items():
            if flags & (1 << bit):
                active_flags.append(name)
                
        return active_flags

    def get_team_name(self, team: int) -> str:
        """Get human-readable name for team number
        
        Args:
            team: Team number
            
        Returns:
            str: Team name
        """
        teams = {
            0: "Friendly",
            1: "Hostile",
            2: "Neutral",
            3: "Unknown",
            4: "Traitor"
        }
        return teams.get(team, f"Team {team}")
