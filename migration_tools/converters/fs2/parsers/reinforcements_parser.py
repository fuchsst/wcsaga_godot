"""Parser for FS2 mission reinforcements section"""
from dataclasses import dataclass
from typing import List, Iterator, Optional
from .base_parser import BaseParser

@dataclass
class Reinforcement:
    """Data structure for a single reinforcement"""
    name: str
    type: str
    num_times: int
    arrival_delay: int
    no_messages: List[str]
    yes_messages: List[str]

class ReinforcementsParser(BaseParser):
    """Parser for FS2 mission reinforcements section"""
    
    def parse(self, lines: Iterator[str]) -> List[Reinforcement]:
        """Parse reinforcements section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            List[Reinforcement]: List of parsed reinforcement data
        """
        reinforcements = []
        current_reinforcement = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Name:'):
                # Start new reinforcement
                if current_reinforcement:
                    reinforcements.append(current_reinforcement)
                current_reinforcement = Reinforcement(
                    name='',
                    type='',
                    num_times=1,
                    arrival_delay=0,
                    no_messages=[],
                    yes_messages=[]
                )
                current_reinforcement.name = self._get_value(line)
                
            elif line.startswith('$Type:') and current_reinforcement:
                current_reinforcement.type = self._get_value(line)
                
            elif line.startswith('$Num times:') and current_reinforcement:
                current_reinforcement.num_times = int(self._get_value(line))
                
            elif line.startswith('+Arrival Delay:') and current_reinforcement:
                current_reinforcement.arrival_delay = int(self._get_value(line))
                
            elif line.startswith('+No Messages:') and current_reinforcement:
                messages = self._get_value(line)
                if messages.startswith('(') and messages.endswith(')'):
                    messages = messages[1:-1].strip()  # Remove parentheses
                    if messages:  # Only split if not empty
                        current_reinforcement.no_messages = [msg.strip() for msg in messages.split(',')]
                
            elif line.startswith('+Yes Messages:') and current_reinforcement:
                messages = self._get_value(line)
                if messages.startswith('(') and messages.endswith(')'):
                    messages = messages[1:-1].strip()  # Remove parentheses
                    if messages:  # Only split if not empty
                        current_reinforcement.yes_messages = [msg.strip() for msg in messages.split(',')]
                        
            elif line.startswith('#'):  # Break on new section marker
                break
        
        # Add final reinforcement if exists
        if current_reinforcement:
            reinforcements.append(current_reinforcement)
            
        return reinforcements
