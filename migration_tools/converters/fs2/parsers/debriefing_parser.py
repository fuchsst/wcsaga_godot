"""Parser for FS2 mission debriefing sections"""
from dataclasses import dataclass, field
from typing import Any, List, Dict, Iterator, Optional
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class DebriefingStage:
    """Represents a stage in a debriefing"""
    formula: Optional[Dict[str, Any]] = None  # Parsed SEXP formula
    text: str = ""  # Multi-line text content
    voice: str = ""
    recommendation_text: str = ""  # Multi-line recommendation text

@dataclass
class Debriefing:
    """Represents a mission debriefing"""
    num_stages: int = 0
    stages: List[DebriefingStage] = field(default_factory=list)

class DebriefingParser(BaseParser):
    """Parser for FS2 mission debriefing sections"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
    
    def parse(self, lines: Iterator[str]) -> Debriefing:
        """Parse debriefing content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Debriefing: Parsed debriefing data
        """
        debriefing = Debriefing()
        current_stage = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Num stages:'):
                debriefing.num_stages = int(self._get_value(line))
                
            elif line.startswith('$Formula:'):
                # Start new stage
                if current_stage:
                    debriefing.stages.append(current_stage)
                current_stage = DebriefingStage()
                
                # Parse multiline SEXP formula
                formula_str = self._get_value(line)
                if formula_str:
                    sexp_lines = self._get_sexp_lines(formula_str, lines)
                    current_stage.formula = self.sexp_parser.parse(sexp_lines)
                
            elif current_stage:
                if line.startswith('$Multi text'):
                    # Collect multi-line text
                    text_lines = []
                    line = next(lines).strip()  # Skip first line
                    while not line.startswith('$end_multi_text'):
                        text_lines.append(line)
                        line = next(lines).strip()
                    current_stage.text = '\n'.join(text_lines)
                    
                elif line.startswith('$Voice:'):
                    current_stage.voice = self._get_value(line)
                    
                elif line.startswith('$Recommendation text:'):
                    # Collect multi-line recommendation text
                    rec_lines = []
                    line = next(lines).strip()  # Skip first line
                    while not line.startswith('$end_multi_text'):
                        rec_lines.append(line)
                        line = next(lines).strip()
                    current_stage.recommendation_text = '\n'.join(rec_lines)
                    
        # Add final stage if exists
        if current_stage:
            debriefing.stages.append(current_stage)
            
        return debriefing
