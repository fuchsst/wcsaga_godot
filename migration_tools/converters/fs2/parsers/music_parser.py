"""Parser for FS2 mission music section"""
from dataclasses import dataclass
from typing import Iterator, Optional
from .base_parser import BaseParser

@dataclass
class MissionMusic:
    """Represents mission music settings"""
    event_music: Optional[str] = None
    briefing_music: Optional[str] = None
    debriefing_success_music: Optional[str] = None
    debriefing_average_music: Optional[str] = None
    debriefing_fail_music: Optional[str] = None

class MusicParser(BaseParser):
    """Parser for FS2 mission music section"""
    
    def parse(self, lines: Iterator[str]) -> MissionMusic:
        """Parse music section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            MissionMusic: Parsed music data
        """
        music = MissionMusic()
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Event Music:'):
                music.event_music = line.split(':', 1)[1].strip()
                
            elif line.startswith('$Briefing Music:'):
                music.briefing_music = line.split(':', 1)[1].strip()
                
            elif line.startswith('$Debriefing Success Music:'):
                music.debriefing_success_music = line.split(':', 1)[1].strip()
                
            elif line.startswith('$Debriefing Average Music:'):
                music.debriefing_average_music = line.split(':', 1)[1].strip()
                
            elif line.startswith('$Debriefing Fail Music:'):
                music.debriefing_fail_music = line.split(':', 1)[1].strip()
                
        return music
