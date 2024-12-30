"""Parser for FS2 mission events"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class MissionEvent:
    """Represents a mission event"""
    name: str = ""
    formula: str = ""  # SEXP formula
    repeat_count: int = 0
    interval: int = 1
    score: int = 0
    chain_delay: int = 0
    objective_text: List[dict] = field(default_factory=list)  # XSTR entries
    objective_key_text: List[dict] = field(default_factory=list)  # XSTR entries
    flags: int = 0
    team: int = 0

class EventsParser(BaseParser):
    """Parser for FS2 mission events"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
        
    def parse(self, lines: Iterator[str]) -> List[MissionEvent]:
        """Parse mission events
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed MissionEvent objects
        """
        events = []
        current_event = None

        if isinstance(lines, list):
            lines = iter(lines)
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            # Check for section end or new section
            if line.startswith('#'):
                break
                
            if line.startswith('$Formula:'):
                # Start new event
                if current_event:
                    events.append(current_event)
                current_event = MissionEvent()
                
                # Parse multiline SEXP formula
                formula_str = self._get_value(line)
                if formula_str:
                    sexp_lines = self._get_sexp_lines(formula_str, lines)
                    current_event.formula = self.sexp_parser.parse(sexp_lines)
                
            elif current_event:
                if line.startswith('+Name:'):
                    current_event.name = self._get_value(line)
                    
                elif line.startswith('+Repeat Count:'):
                    current_event.repeat_count = int(self._get_value(line))
                    
                elif line.startswith('+Interval:'):
                    current_event.interval = int(self._get_value(line))
                    
                elif line.startswith('+Score:'):
                    current_event.score = int(self._get_value(line))
                    
                elif line.startswith('+Chain Delay:'):
                    current_event.chain_delay = int(self._get_value(line))
                    
                elif line.startswith('+Team:'):
                    current_event.team = int(self._get_value(line))
                    
                elif line.startswith('+Flags:'):
                    current_event.flags = int(self._get_value(line))
                    
                elif line.startswith('+Objective:'):
                    current_event.objective_text = self._get_value(line)
                    
        # Add final event if exists
        if current_event:
            events.append(current_event)
            
        return events

    def get_event_flag_names(self, flags: int) -> List[str]:
        """Get human-readable names for event flags
        
        Args:
            flags: Event flags value
            
        Returns:
            list: List of flag names that are set
        """
        flag_names = {
            0: "repeat",
            1: "chain",
            2: "no-repeat",
            3: "always-repeat",
            4: "use-msecs",
            5: "use-usecs",
            6: "use-animation"
        }
        
        active_flags = []
        for bit, name in flag_names.items():
            if flags & (1 << bit):
                active_flags.append(name)
                
        return active_flags
