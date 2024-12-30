"""Parser for FS2 mission callsigns section"""
from dataclasses import dataclass, field
from typing import List, Iterator
from .base_parser import BaseParser

class CallsignsParser(BaseParser):
    """Parser for FS2 mission callsigns section"""
    
    def parse(self, lines: Iterator[str]) -> List[str]:
        """Parse callsigns section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Callsigns: Parsed callsigns data
        """
        callsigns = []
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
            if line.startswith('$Callsign:'):
                callsign = line.split(':', 1)[1].strip()
                callsigns.append(callsign)
            elif line.startswith('#'):  # Only break on new section marker
                break
                
        return callsigns
