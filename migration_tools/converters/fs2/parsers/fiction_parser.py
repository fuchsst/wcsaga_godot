"""Parser for FS2 fiction viewer sections"""
from dataclasses import dataclass
from typing import Iterator
from .base_parser import BaseParser

@dataclass
class FictionViewer:
    """Represents a fiction viewer entry"""
    filename: str = ""

class FictionParser(BaseParser):
    """Parser for FS2 fiction viewer sections"""
    
    def parse(self, lines: Iterator[str]) -> FictionViewer:
        """Parse fiction viewer content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            FictionViewer: Parsed fiction viewer data
        """
        fiction = FictionViewer()
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$File:'):
                fiction.filename = line.split(':', 1)[1].strip()
                break
                
        return fiction
