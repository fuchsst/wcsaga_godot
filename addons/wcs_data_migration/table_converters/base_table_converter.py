#!/usr/bin/env python3
"""
Base Table Converter

Provides common functionality for all WCS table converters.
Implements the Template Method pattern for consistent parsing behavior.

SOLID Principles Applied:
- Single Responsibility: Base parsing framework only
- Open/Closed: Open for extension via inheritance, closed for modification
- Liskov Substitution: All table converters can be used interchangeably
- Interface Segregation: Focused interface for table parsing
- Dependency Inversion: Depends on abstractions, not concrete implementations
"""

import logging
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Protocol, Tuple, Union

logger = logging.getLogger(__name__)

class ParseError(Exception):
    """Custom exception for table parsing errors"""
    def __init__(self, message: str, line_number: int = -1, filename: str = ""):
        self.message = message
        self.line_number = line_number
        self.filename = filename
        super().__init__(f"{filename}:{line_number}: {message}" if line_number > 0 else message)

class TableType(Enum):
    """Table file types supported by the converter"""
    AI = "ai"
    AI_PROFILES = "ai_profiles"
    ARMOR = "armor"
    ASTEROID = "asteroid"
    CUTSCENES = "cutscenes"
    FIREBALL = "fireball"
    HUD_GAUGES = "hud_gauges"
    IFF = "iff_defs"
    LIGHTNING = "lightning"
    MEDALS = "medals"
    MUSIC = "music"
    RANK = "rank"
    SCRIPTING = "scripting"
    SHIPS = "ships"
    SOUNDS = "sounds"
    SPECIES = "species_defs"
    SPECIES_ENTRIES = "species"
    STARS = "stars"
    STRINGS = "strings"
    UNKNOWN = "unknown"
    WEAPONS = "weapons"

@dataclass
class ParseState:
    """Maintains state during table parsing"""
    lines: List[str] = field(default_factory=list)
    current_line: int = 0
    filename: str = ""
    in_multiline_comment: bool = False
    current_section: str = ""
    
    def has_more_lines(self) -> bool:
        return self.current_line < len(self.lines)
    
    def peek_line(self) -> Optional[str]:
        if self.has_more_lines():
            return self.lines[self.current_line]
        return None
    
    def next_line(self) -> Optional[str]:
        if self.has_more_lines():
            line = self.lines[self.current_line]
            self.current_line += 1
            return line
        return None
    
    def skip_line(self) -> None:
        if self.has_more_lines():
            self.current_line += 1

class TableParser(Protocol):
    """Protocol defining the interface for table parsers"""
    
    def parse_line(self, line: str, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single line and return data if complete entry found"""
        ...
    
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed table entry"""
        ...

class BaseTableConverter(ABC):
    """
    Abstract base class for all table converters.
    
    Implements Template Method pattern for consistent parsing workflow.
    Subclasses implement specific parsing logic for their table type.
    """
    
    def __init__(self):
        self.logger = logging.getLogger(self.__class__.__name__)
        self._parse_patterns = self._init_parse_patterns()
    
    @abstractmethod
    def _init_parse_patterns(self) -> Dict[str, re.Pattern]:
        """Initialize regex patterns for parsing this table type"""
        pass
    
    @abstractmethod
    def get_table_type(self) -> TableType:
        """Return the table type this converter handles"""
        pass
    
    @abstractmethod
    def parse_entry(self, state: ParseState) -> Optional[Dict[str, Any]]:
        """Parse a single table entry from the current position"""
        pass
    
    @abstractmethod
    def validate_entry(self, entry: Dict[str, Any]) -> bool:
        """Validate a parsed table entry"""
        pass
    
    @abstractmethod
    def convert_to_godot_resource(self, entries: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert parsed entries to Godot resource format"""
        pass
    
    def convert_table_file(self, table_path: Path, output_path: Path) -> bool:
        """
        Main conversion method (Template Method pattern).
        Defines the algorithm for converting any table file.
        """
        try:
            # Step 1: Load and prepare file
            content = self._load_file(table_path)
            state = self._prepare_parse_state(content, str(table_path))
            
            # Step 2: Parse all entries
            entries = self._parse_all_entries(state)
            
            # Step 3: Validate entries
            valid_entries = self._validate_all_entries(entries)
            
            # Step 4: Convert to Godot format
            godot_resource = self.convert_to_godot_resource(valid_entries)
            
            # Step 5: Save result
            return self._save_resource(godot_resource, output_path)
            
        except Exception as e:
            self.logger.error(f"Failed to convert {table_path}: {e}")
            return False
    
    def _load_file(self, table_path: Path) -> str:
        """Load table file content"""
        try:
            with open(table_path, 'r', encoding='utf-8') as f:
                return f.read()
        except UnicodeDecodeError:
            # Fallback to latin-1 for older files
            with open(table_path, 'r', encoding='latin-1') as f:
                return f.read()
    
    def _prepare_parse_state(self, content: str, filename: str) -> ParseState:
        """Prepare parsing state from file content"""
        lines = content.split('\n')
        return ParseState(lines=lines, filename=filename)
    
    def _parse_all_entries(self, state: ParseState) -> List[Dict[str, Any]]:
        """Parse all entries from the table file"""
        entries = []
        
        while state.has_more_lines():
            line = state.peek_line()
            if line is None:
                break
                
            # Skip comments and empty lines
            if self._should_skip_line(line, state):
                state.skip_line()
                continue
            
            # Try to parse entry
            entry = self.parse_entry(state)
            if entry:
                entries.append(entry)
        
        return entries
    
    def _validate_all_entries(self, entries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Validate all parsed entries"""
        valid_entries = []
        
        for entry in entries:
            if self.validate_entry(entry):
                valid_entries.append(entry)
            else:
                self.logger.warning(f"Invalid entry skipped: {entry.get('name', 'Unknown')}")
        
        return valid_entries
    
    def _save_resource(self, resource: Dict[str, Any], output_path: Path) -> bool:
        """Save Godot resource to file"""
        try:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                if output_path.suffix == '.json':
                    import json
                    json.dump(resource, f, indent=2)
                else:
                    # Save as .tres format
                    self._write_tres_format(resource, f)
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to save resource to {output_path}: {e}")
            return False
    
    def _write_tres_format(self, resource: Dict[str, Any], file) -> None:
        """Write resource in Godot .tres format"""
        file.write('[gd_resource type="Resource"]\n\n')
        file.write('[resource]\n')
        
        for key, value in resource.items():
            file.write(f'{key} = {self._format_tres_value(value)}\n')
    
    def _format_tres_value(self, value: Any) -> str:
        """Format a value for .tres file format"""
        if isinstance(value, str):
            return f'"{value}"'
        elif isinstance(value, (int, float)):
            return str(value)
        elif isinstance(value, bool):
            return str(value).lower()
        elif isinstance(value, list):
            formatted_items = [self._format_tres_value(item) for item in value]
            return f"[{', '.join(formatted_items)}]"
        elif isinstance(value, dict):
            # For complex objects, convert to JSON string
            import json
            return f'"{json.dumps(value)}"'
        else:
            return f'"{str(value)}"'
    
    def _should_skip_line(self, line: str, state: ParseState) -> bool:
        """Check if line should be skipped (comments, empty lines)"""
        line = line.strip()
        
        # Empty line
        if not line:
            return True
        
        # Handle multi-line comments
        if '/*' in line:
            state.in_multiline_comment = True
        if '*/' in line:
            state.in_multiline_comment = False
            return True
        if state.in_multiline_comment:
            return True
        
        # Single-line comments
        if line.startswith('//') or line.startswith(';'):
            return True
        
        return False
    
    def parse_value(self, value_str: str, expected_type: type = str) -> Any:
        """Parse a value string to the expected type"""
        value_str = value_str.strip()
        
        # Remove quotes if present
        if value_str.startswith('"') and value_str.endswith('"'):
            value_str = value_str[1:-1]
        
        try:
            if expected_type == str:
                return value_str
            elif expected_type == int:
                return int(float(value_str))  # Handle decimal strings
            elif expected_type == float:
                return float(value_str)
            elif expected_type == bool:
                return value_str.lower() in ('true', '1', 'yes', 'on')
            else:
                return value_str
                
        except (ValueError, TypeError):
            self.logger.warning(f"Failed to parse '{value_str}' as {expected_type.__name__}")
            return value_str if expected_type == str else None
