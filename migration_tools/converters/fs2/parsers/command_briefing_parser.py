"""Parser for FS2 command briefing sections"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class CommandBriefingStage:
    """Represents a stage in a command briefing"""
    text: List[dict] = field(default_factory=list)  # XSTR entries
    ani_filename: str = ""
    wave_filename: str = ""

@dataclass
class CommandBriefing:
    """Represents a mission command briefing"""
    stages: List[CommandBriefingStage] = field(default_factory=list)

class CommandBriefingParser(BaseParser):
    """Parser for FS2 command briefing sections"""
        
    def parse(self, lines: Iterator[str]) -> CommandBriefing:
        """Parse command briefing content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            CommandBriefing: Parsed command briefing data
        """
        briefing = CommandBriefing()
        current_stage = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Stage Text:'):
                # Start new stage
                if current_stage:
                    briefing.stages.append(current_stage)
                current_stage = CommandBriefingStage()
                
                # Parse multi-line text
                text_lines = []
                line = next(lines).strip()  # Skip first line
                while not line.startswith('$end_multi_text'):
                    text_lines.append(line)
                    line = next(lines).strip()
                current_stage.text = '\n'.join(text_lines)
                
            elif current_stage:
                if line.startswith('$Ani Filename:'):
                    current_stage.ani_filename = self._get_value(line)
                    
                elif line.startswith('+Wave Filename:'):
                    current_stage.wave_filename = self._get_value(line)
                    
        # Add final stage if exists
        if current_stage:
            briefing.stages.append(current_stage)
            
        return briefing
