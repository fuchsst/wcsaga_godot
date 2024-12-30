"""Parser for FS2 mission cutscenes section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator
from .base_parser import BaseParser
from .parser_factory import ParserFactory

@dataclass
class Cutscene:
    """Represents a mission cutscene"""
    name: str = ""  # e.g. "Briefing Cutscene"
    filename: str = ""
    formula: str = ""  # SEXP formula
    position: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    orientation: List[List[float]] = field(default_factory=lambda: [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
    ])

class CutscenesParser(BaseParser):
    """Parser for FS2 mission cutscenes section"""
    
    def __init__(self):
        self.sexp_parser = ParserFactory.create_parser('sexp')
    
    def parse(self, lines: Iterator[str]) -> List[Cutscene]:
        """Parse cutscenes section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed Cutscene objects
        """
        cutscenes = []
        current_cutscene = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$'):
                # Start new cutscene
                if current_cutscene:
                    cutscenes.append(current_cutscene)
                    
                name = line[1:].split(':', 1)[0].strip()  # Remove $ and get name
                filename = line.split(':', 1)[1].strip()
                current_cutscene = Cutscene(name=name, filename=filename)
                
            elif current_cutscene:
                if line.startswith('+formula:'):
                    # Parse SEXP formula
                    formula_str = line.split(':', 1)[1].strip()
                    if formula_str:
                        current_cutscene.formula = self.sexp_parser.parse([formula_str])
                        
                elif line.startswith('+position:'):
                    pos = line.split(':', 1)[1].strip().split(',')
                    current_cutscene.position = [float(x.strip()) for x in pos]
                    
                elif line.startswith('+orientation:'):
                    # Parse 3x3 orientation matrix
                    matrix = []
                    for _ in range(3):
                        line = next(lines).strip().strip(',')
                        row = [float(x.strip()) for x in line.split(',')]
                        matrix.append(row)
                    current_cutscene.orientation = matrix
                    
        # Add final cutscene if exists
        if current_cutscene:
            cutscenes.append(current_cutscene)
            
        return cutscenes
