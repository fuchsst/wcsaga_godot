"""Parser for FS2 mission messages section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class MissionMessage:
    """Represents a mission message/dialog"""
    name: str = ""
    team: int = -1
    message: List[dict] = field(default_factory=list)  # XSTR entries
    avi_name: Optional[str] = None
    wave_name: Optional[str] = None
    persona: Optional[str] = None
    multi_team: bool = False

class MessagesParser(BaseParser):
    """Parser for FS2 mission messages section"""
    
    def parse(self, lines: Iterator[str]) -> List[MissionMessage]:
        """Parse messages section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed MissionMessage objects
        """
        messages = []
        current_message = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Name:'):
                # Start new message
                if current_message:
                    messages.append(current_message)
                current_message = MissionMessage(
                    name=self._get_value(line)
                )
                
            elif current_message:
                if line.startswith('$Team:'):
                    current_message.team = int(self._get_value(line))
                    
                elif line.startswith('$MessageNew:'):
                    # Parse multi-line message text
                    msg_lines = []
                    line = next(lines).strip()  # Skip first line
                    while not line.startswith('$end_multi_text'):
                        msg_lines.append(line)
                        line = next(lines).strip()
                    current_message.message = '\n'.join(msg_lines)
                    
                elif line.startswith('+AVI Name:'):
                    current_message.avi_name = self._get_value(line)
                    
                elif line.startswith('+Wave Name:'):
                    current_message.wave_name = self._get_value(line)
                    
                elif line.startswith('+Persona:'):
                    current_message.persona = self._get_value(line)
                    
                elif line.startswith('+Multi team:'):
                    current_message.multi_team = bool(int(self._get_value(line)))
                    
        # Add final message if exists
        if current_message:
            messages.append(current_message)
            
        return messages

    def get_team_name(self, team: int) -> str:
        """Get human-readable name for team number
        
        Args:
            team: Team number
            
        Returns:
            str: Team name
        """
        teams = {
            -1: "All",
            0: "Friendly",
            1: "Hostile", 
            2: "Neutral",
            3: "Unknown",
            4: "Traitor"
        }
        return teams.get(team, f"Team {team}")

    def get_persona_name(self, persona: str) -> str:
        """Get human-readable name for persona
        
        Args:
            persona: Persona identifier
            
        Returns:
            str: Persona name
        """
        personas = {
            "None": "None",
            "Terran": "Terran Command",
            "Wingman": "Wingman",
            "Support": "Support",
            "Large": "Large Ship",
            "Instructor": "Training Instructor",
            "Command": "Command",
            "Computer": "Computer"
        }
        return personas.get(persona, persona)
