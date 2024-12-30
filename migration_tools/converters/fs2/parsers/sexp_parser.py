"""Parser for FS2 SEXP (S-Expression) formulas"""
from dataclasses import dataclass, field
from typing import List, Dict, Iterator, Optional, Union, Any
from .base_parser import BaseParser

@dataclass
class SexpNode:
    """Represents a node in a SEXP expression tree"""
    type: str = ""  # Command/operator type
    args: List[Any] = field(default_factory=list)  # Arguments (can be strings, numbers, or nested SexpNodes)
    raw: str = ""  # Raw SEXP string

@dataclass
class SexpFormula:
    """Represents a complete SEXP formula"""
    root: Optional[SexpNode] = None  # Root node of the expression tree
    raw: str = ""  # Raw formula string

class SexpParser(BaseParser):
    """Parser for FS2 SEXP formulas"""
    
    def parse(self, lines: Union[Iterator[str], List[str]]) -> Union[SexpFormula, List[SexpFormula]]:
        """Parse SEXP formula from lines
        
        Args:
            lines: Iterator or list of formula lines
            
        Returns:
            Union[SexpFormula, List[SexpFormula]]: Parsed formula(s)
        """
        if isinstance(lines, list):
            lines = iter(lines)
        
        formulas = []
        current_formula = []
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
                
            if line.startswith('('):
                # Start collecting formula lines
                current_formula.append(line)
                
                # Track nested parentheses
                depth = line.count('(') - line.count(')')
                
                # Keep collecting until we close all parentheses
                while depth > 0:
                    try:
                        line = next(lines).strip()
                        if line:
                            current_formula.append(line)
                            depth += line.count('(') - line.count(')')
                    except StopIteration:
                        break
                        
                # Parse completed formula
                if current_formula:
                    formula = self._parse_formula(current_formula)
                    formulas.append(formula)
                    current_formula = []
                    
        # Return single formula or list depending on input
        return formulas[0] if len(formulas) == 1 else formulas
    
    def _parse_formula(self, lines: List[str]) -> SexpFormula:
        """Parse a single SEXP formula
        
        Args:
            lines: List of formula lines
            
        Returns:
            SexpFormula: Parsed formula
        """
        formula = SexpFormula()
        formula.raw = ' '.join(lines)
        
        # Join lines and clean up whitespace
        expr = ' '.join(line.strip() for line in lines)
        
        # Parse the expression tree
        formula.root = self._parse_expr(expr)
        
        return formula
    
    def _parse_expr(self, expr: str) -> Optional[SexpNode]:
        """Parse a SEXP expression into a node tree
        
        Args:
            expr: Expression string
            
        Returns:
            Optional[SexpNode]: Root node of parsed expression, or None if invalid
        """
        expr = expr.strip()
        if not expr or not expr.startswith('('):
            return None
            
        # Remove outer parentheses
        expr = expr[1:-1].strip()
        
        # Split into command and arguments
        parts = self._split_expr(expr)
        if not parts:
            return None
            
        node = SexpNode()
        node.type = parts[0].strip()
        node.raw = f"({expr})"
        
        # Parse each argument
        for arg in parts[1:]:
            arg = arg.strip()
            if arg.startswith('('):
                # Nested expression
                child_node = self._parse_expr(arg)
                if child_node:
                    node.args.append(child_node)
            elif arg.startswith('"'):
                # String literal
                node.args.append(arg.strip('"'))
            else:
                # Number or identifier
                try:
                    num = float(arg)
                    node.args.append(num)
                except ValueError:
                    node.args.append(arg)
                    
        return node
    
    def _split_expr(self, expr: str) -> List[str]:
        """Split a SEXP expression into its parts, handling nested parentheses
        
        Args:
            expr: Expression string without outer parentheses
            
        Returns:
            list: List of expression parts
        """
        parts = []
        current = []
        depth = 0
        in_string = False
        
        for c in expr:
            if c == '"':
                in_string = not in_string
                current.append(c)
            elif c == '(' and not in_string:
                depth += 1
                current.append(c)
            elif c == ')' and not in_string:
                depth -= 1
                current.append(c)
            elif c.isspace() and depth == 0 and not in_string:
                if current:
                    parts.append(''.join(current))
                    current = []
            else:
                current.append(c)
                
        if current:
            parts.append(''.join(current))
            
        return parts
