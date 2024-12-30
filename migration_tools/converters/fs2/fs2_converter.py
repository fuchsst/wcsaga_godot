#!/usr/bin/env python3

import logging
import os
import json
from pathlib import Path
from typing import Dict, Any, List, Iterator, Optional
from dataclasses import dataclass, field
from ..base_converter import BaseConverter
from .parsers.parser_factory import ParserFactory

logger = logging.getLogger(__name__)

@dataclass
class FS2File:
    """Container for all FS2 file sections"""
    mission_info: Dict[str, Any] = field(default_factory=dict)
    command_briefing: Dict[str, Any] = field(default_factory=dict)
    fiction_viewer: Dict[str, Any] = field(default_factory=dict)
    briefing: Dict[str, Any] = field(default_factory=dict)
    debriefing_info: Dict[str, Any] = field(default_factory=dict)
    players: Dict[str, Any] = field(default_factory=dict)
    objects: List[Dict[str, Any]] = field(default_factory=list)
    wings: List[Dict[str, Any]] = field(default_factory=list)
    messages: List[Dict[str, Any]] = field(default_factory=list)
    events: List[Dict[str, Any]] = field(default_factory=list)
    goals: List[Dict[str, Any]] = field(default_factory=list)
    waypoints: List[Dict[str, Any]] = field(default_factory=list)
    asteroid_fields: List[Dict[str, Any]] = field(default_factory=list)
    background_bitmaps: Dict[str, Any] = field(default_factory=dict)
    music: Dict[str, Any] = field(default_factory=dict)
    cutscenes: List[Dict[str, Any]] = field(default_factory=list)
    sexp_variables: List[Dict[str, Any]] = field(default_factory=list)
    callsigns: List[str] = field(default_factory=list)
    reinforcements: List[Dict[str, Any]] = field(default_factory=list)

class FS2Converter(BaseConverter):
    """Converter for Wing Commander Saga .fs2 files"""
    
    def __init__(self, input_dir="extracted", output_dir="converted", force=False):
        super().__init__(input_dir, output_dir, force)
        logger.debug("Initialized FS2Converter with input_dir=%s, output_dir=%s, force=%s", 
                    input_dir, output_dir, force)
        
    @property
    def source_extension(self) -> str:
        """File extension this converter handles"""
        return ".fs2"
        
    @property
    def target_extension(self) -> str:
        """File extension to convert to"""
        return ".json"
    
    def _normalize_section_name(self, section: str) -> str:
        """Normalize section name to match FS2File field names
        
        Args:
            section: Raw section name
            
        Returns:
            str: Normalized section name
        """
        # Remove any comments (starting with semicolon)
        if ';' in section:
            section = section.split(';')[0]
            
        # Convert to lowercase and replace spaces with underscores
        section = section.replace(':', '').strip().lower().replace(' ', '_')
        
        return section
    
    def _parse_fs2_file(self, content: str) -> FS2File:
        """Parse complete FS2 file content
        
        Args:
            content: Raw file content
            
        Returns:
            FS2File: Parsed file data
        """
        fs2_data = FS2File()
        lines = iter(content.splitlines())
        current_section = None
        section_lines = []
        
        for line in lines:
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith(';'):
                continue
                
            if line.startswith('#'):
                # Process previous section
                if current_section and section_lines:
                    logger.debug("Processing section '%s' with %d lines", 
                               current_section, len(section_lines))
                    self._parse_section(fs2_data, current_section, section_lines)
                
                # Start new section
                raw_section = line[1:].strip()  # Remove #
                current_section = self._normalize_section_name(raw_section)
                section_lines = []
                logger.debug("Found section marker: '%s' -> normalized to '%s'", 
                           raw_section, current_section)
                continue
                
            # Collect lines for current section
            section_lines.append(line)
            
        # Parse final section
        if current_section and section_lines:
            self._parse_section(fs2_data, current_section, section_lines)
            
        return fs2_data
    
    def _parse_section(self, fs2_data: FS2File, section: str, lines: List[str]) -> None:
        """Parse a mission file section
        
        Args:
            fs2_data: FS2File object to update
            section: Section name
            lines: Section lines to parse
        """
        logger.debug("Parsing section: %s", section)
        
        try:
            # Get parser for section
            parser = ParserFactory.create_parser(section)
            
            # Convert lines to list to allow multiple iterations
            lines_list = list(lines)
            
            # Parse section
            result = parser.parse(iter(lines_list))
                
            # Set the result
            setattr(fs2_data, section, result)
            logger.debug("Successfully parsed section: %s with result: %s", 
                        section, str(result)[:200])  # Truncate long results
            
        except Exception as e:
            logger.error("Error parsing section %s: %s", section, str(e), exc_info=True)
            # Log the full section content for debugging
            logger.error("Section content that failed to parse:\n%s", 
                        '\n'.join(list(lines)))
    
    def _dataclass_to_dict(self, obj: Any) -> Dict:
        """Convert a dataclass instance to a dictionary
        
        Args:
            obj: Object to convert
            
        Returns:
            dict: Dictionary representation
        """
        if hasattr(obj, '__dataclass_fields__'):
            # Convert dataclass to dict
            result = {}
            for field in obj.__dataclass_fields__:
                value = getattr(obj, field)
                if value is not None:  # Only include non-None values
                    if isinstance(value, list):
                        # Handle lists of dataclass objects
                        result[field] = [
                            self._dataclass_to_dict(item) if hasattr(item, '__dataclass_fields__') else item
                            for item in value
                        ]
                    else:
                        result[field] = self._dataclass_to_dict(value)
            return result
        elif isinstance(obj, list):
            # Convert list elements
            result = [
                self._dataclass_to_dict(item) if hasattr(item, '__dataclass_fields__') else item
                for item in obj
            ]
            return result
        elif isinstance(obj, dict):
            # Convert dict values
            result = {
                key: self._dataclass_to_dict(value) if hasattr(value, '__dataclass_fields__') else value
                for key, value in obj.items()
            }
            return result
        else:
            # Return primitive types as-is
            return obj
    
    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """Convert a .fs2 file to JSON format
        
        Args:
            input_path: Path to input .fs2 file
            output_path: Path to write converted JSON file
            
        Returns:
            bool: True if conversion successful, False otherwise
        """
        logger.info("Starting conversion of %s", input_path)
        try:
            # Read input file
            logger.debug("Reading input file %s", input_path)
            with open(input_path, 'r', encoding='utf-8') as f:
                content = f.read()
            logger.debug("Successfully read %d bytes", len(content))
            
            # Parse content
            logger.debug("Starting parsing of file content")
            parsed_data = self._parse_fs2_file(content)
            logger.debug("Successfully parsed file content")
            
            # Convert dataclass to dictionary for JSON serialization
            logger.debug("Converting parsed data to JSON-compatible format")
            json_data = self._dataclass_to_dict(parsed_data)
            
            # Write converted JSON
            output_path = output_path.with_suffix('.json')
            logger.debug("Writing output to %s", output_path)
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(json_data, f, indent=2)
            
            logger.info("Successfully converted %s to %s", input_path, output_path)    
            return True
            
        except Exception as e:
            logger.error("Error converting %s: %s", input_path, str(e), exc_info=True)
            return False
