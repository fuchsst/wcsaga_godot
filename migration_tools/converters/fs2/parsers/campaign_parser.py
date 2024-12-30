"""Parser for FS2 campaign files"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional, Any
from .base_parser import BaseParser
from .parser_factory import ParserFactory
import logging
import re

logger = logging.getLogger(__name__)

@dataclass
class CampaignMission:
    """Represents a mission in a campaign"""
    filename: str = ""
    flags: int = 0
    main_hall: int = 0
    debriefing_persona: int = 0
    formula: Dict[str, Any] = field(default_factory=dict)  # Parsed SEXP formula
    level: int = 0
    position: int = 0
    mission_loop: bool = False
    mission_loop_text: List[dict] = field(default_factory=list)  # XSTR entries
    mission_loop_anim: str = ""
    mission_loop_sound: str = ""
    mission_loop_formula: Dict[str, Any] = field(default_factory=dict)  # Parsed SEXP formula

@dataclass
class Campaign:
    """Represents an FS2 campaign"""
    name: str = ""
    type: str = ""  # single, multi-coop, etc
    description: List[dict] = field(default_factory=list)  # XSTR entries
    flags: int = 0
    intro_cutscene: str = ""
    end_cutscene: str = ""
    starting_ships: List[str] = field(default_factory=list)
    starting_weapons: List[str] = field(default_factory=list)
    missions: List[CampaignMission] = field(default_factory=list)

class CampaignParser(BaseParser):
    """Parser for FS2 campaign files"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
        
    def _parse_list(self, line: str) -> List[str]:
        """Parse parenthesized list of quoted strings
        
        Args:
            line: Line containing the list
            
        Returns:
            List[str]: Parsed string values
        """
        # Remove parentheses and split by whitespace preserving quotes
        content = line.strip()
        if content.startswith('(') and content.endswith(')'):
            content = content[1:-1].strip()
            
        # Split by whitespace but preserve quoted strings
        pattern = r'"[^"]*"|\S+'
        return [item.strip('" ') for item in re.findall(pattern, content)]
    
    def parse(self, lines: Iterator[str]) -> Campaign:
        """Parse campaign file content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Campaign: Parsed campaign data
        """
        campaign = Campaign()
        current_mission = None
        found_name = False
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            # Validate file starts with $Name
            if not found_name and not line.startswith('$Name:'):
                if not line.startswith(';') and line.strip():  # Ignore comments and blank lines
                    logger.error("Campaign file must start with $Name:")
                    raise ValueError("Invalid campaign file format - must start with $Name:")
                continue
                
            if line.startswith('$Name:'):
                found_name = True
                campaign.name = self._get_value(line)
                
            elif line.startswith('$Type:'):
                campaign.type = self._get_value(line)
                
            elif line.startswith('+Description:'):
                desc_text = []
                while True:
                    try:
                        line = next(lines).strip()
                        if line.startswith('$'):
                            break
                        desc_text.append(line)
                    except StopIteration:
                        break
                
                # Parse XSTR entries from collected text
                campaign.description = '\n'.join(desc_text).strip()
                
            elif line.startswith('$Flags:'):
                campaign.flags = int(self._get_value(line))
                
            elif line.startswith('+Campaign Intro Cutscene:'):
                campaign.intro_cutscene = self._get_value(line)
                
            elif line.startswith('+Campaign End Cutscene:'):
                campaign.end_cutscene = self._get_value(line)
                
            elif line.startswith('+Starting Ships:'):
                campaign.starting_ships = self._parse_list(self._get_value(line))
                
            elif line.startswith('+Starting Weapons:'):
                campaign.starting_weapons = self._parse_list(self._get_value(line))
                
            elif line.startswith('$Mission:'):
                # Start new mission
                if current_mission:
                    campaign.missions.append(current_mission)
                current_mission = CampaignMission(
                    filename=self._get_value(line)
                )
                
            elif line.startswith('#End'):
                # Add final mission if exists
                if current_mission:
                    campaign.missions.append(current_mission)
                break
                
            elif current_mission:
                if line.startswith('+Flags:'):
                    current_mission.flags = int(self._get_value(line))
                    
                elif line.startswith('+Main Hall:'):
                    current_mission.main_hall = int(self._get_value(line))
                    
                elif line.startswith('+Debriefing Persona Index:'):
                    current_mission.debriefing_persona = int(self._get_value(line))
                    
                elif line.startswith('+Formula:'):
                    first_line = self._get_value(line)
                    sexp = self._get_sexp_lines(first_line, lines)
                    current_mission.formula = self.sexp_parser.parse(sexp)
                    
                elif line.startswith('+Level:'):
                    current_mission.level = int(self._get_value(line))
                    
                elif line.startswith('+Position:'):
                    current_mission.position = int(self._get_value(line))
                    
                elif line.startswith('+Mission Loop:'):
                    current_mission.mission_loop = True
                    
                elif line.startswith('+Mission Loop Text:'):
                    text_lines = []
                    while True:
                        try:
                            line = next(lines).strip()
                            if line.startswith('$') or line.startswith('+'):
                                break
                            text_lines.append(line)
                        except StopIteration:
                            break
                    
                    current_mission.mission_loop_text ='\n'.join(text_lines)
                    
                elif line.startswith('+Mission Loop Brief Anim:'):
                    current_mission.mission_loop_anim = self._get_value(line)
                    
                elif line.startswith('+Mission Loop Brief Sound:'):
                    current_mission.mission_loop_sound = self._get_value(line)
                    
                elif line.startswith('+Mission Loop Formula:'):
                    first_line = self._get_value(line)
                    sexp = self._get_sexp_lines(first_line, lines)
                    current_mission.mission_loop_formula = self.sexp_parser.parse(sexp)
        
        if not found_name:
            logger.error("Campaign file must contain $Name:")
            raise ValueError("Invalid campaign file - missing $Name:")
            
        return campaign

    def get_campaign_type_name(self, campaign_type: str) -> str:
        """Get standardized name for campaign type
        
        Args:
            campaign_type: Raw campaign type string
            
        Returns:
            str: Standardized campaign type name
        """
        type_map = {
            "single": "Single Player",
            "multi": "Multiplayer",
            "multi-coop": "Cooperative",
            "training": "Training"
        }
        return type_map.get(campaign_type.lower(), campaign_type)
