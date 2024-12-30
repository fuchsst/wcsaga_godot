"""Base interface for FS2 file parsers"""
from abc import ABC, abstractmethod
from typing import Iterator, Any

class BaseParser(ABC):
    """Abstract base class for FS2 file section parsers"""
    
    @abstractmethod
    def parse(self, lines: Iterator[str]) -> Any:
        """Parse section content from lines
        
        Args:
            lines: Iterator over file lines
            
        Returns:
            Parsed section data
        """
        pass

    def _get_value(self, line):
        left_part = line.split(':', 1)[1]
        if left_part.rfind(';') != -1:
            left_part = left_part[:left_part.rfind(';')]
        return left_part.strip()

    def _get_sexp_lines(self, first_line: str, lines: Iterator[str]) -> list[str]:
        """Extract all lines of a SEXP expression, handling multiline expressions
        
        Args:
            first_line: First line containing the SEXP expression
            lines: Iterator over remaining lines
            
        Returns:
            list: All lines of the SEXP expression
        """
        sexp_lines = [first_line]
        if first_line.startswith('(') and not first_line.endswith(')'):
            depth = first_line.count('(') - first_line.count(')')
            while depth > 0:
                try:
                    next_line = next(lines).strip()
                    if not next_line or next_line.startswith(';'):
                        continue
                    if next_line.startswith('$') or next_line.startswith('#'):
                        break
                    sexp_lines.append(next_line)
                    depth += next_line.count('(') - next_line.count(')')
                except StopIteration:
                    break
        return sexp_lines
