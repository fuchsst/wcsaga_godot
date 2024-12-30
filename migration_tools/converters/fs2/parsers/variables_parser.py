"""Parser for FS2 mission SEXP variables section"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator
from .base_parser import BaseParser

@dataclass
class SexpVariable:
    """Represents a SEXP variable"""
    index: int = 0
    name: str = ""
    value: str = ""
    type: str = ""  # number, string, etc.

class VariablesParser(BaseParser):
    """Parser for FS2 mission SEXP variables section"""
    
    def parse(self, lines: Iterator[str]) -> List[SexpVariable]:
        """Parse variables section content
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            list: List of parsed SexpVariable objects
        """
        variables = []
        in_variables = False
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('$Variables:'):
                in_variables = True
                continue
                
            if in_variables:
                if line.startswith('('):
                    # Start variables list
                    continue
                elif line.startswith(')'):
                    # End variables list
                    break
                else:
                    # Parse variable entry
                    # Format: index "name" "value" "type"
                    parts = line.strip().split('"')
                    if len(parts) >= 7:  # Should have 7 parts with quotes
                        try:
                            index = int(parts[0].strip())
                            name = parts[1].strip()
                            value = parts[3].strip()
                            var_type = parts[5].strip()
                            
                            variables.append(SexpVariable(
                                index=index,
                                name=name,
                                value=value,
                                type=var_type
                            ))
                        except (ValueError, IndexError):
                            continue
                    
        return variables
