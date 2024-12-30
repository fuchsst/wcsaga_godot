#!/usr/bin/env python3

import logging
import os
import json
from pathlib import Path
from typing import Dict, Any, List, Iterator, Optional
from dataclasses import dataclass, field
from ..base_converter import BaseConverter
from .parsers.campaign_parser import CampaignParser, Campaign

logger = logging.getLogger(__name__)

@dataclass
class FC2File:
    """Container for FC2 campaign file data"""
    name: str = ""
    type: str = ""  # single, multi-coop, etc
    description: List[dict] = field(default_factory=list)  # XSTR entries
    flags: int = 0
    intro_cutscene: str = ""
    end_cutscene: str = ""
    starting_ships: List[str] = field(default_factory=list)
    starting_weapons: List[str] = field(default_factory=list)
    missions: List[Dict[str, Any]] = field(default_factory=list)

class FC2Converter(BaseConverter):
    """Converter for Wing Commander Saga .fc2 campaign files"""
    
    def __init__(self, input_dir="extracted", output_dir="converted", force=False):
        super().__init__(input_dir, output_dir, force)
        logger.debug("Initialized FC2Converter with input_dir=%s, output_dir=%s, force=%s", 
                    input_dir, output_dir, force)
        self.campaign_parser = CampaignParser()
        
    @property
    def source_extension(self) -> str:
        """File extension this converter handles"""
        return ".fc2"
        
    @property
    def target_extension(self) -> str:
        """File extension to convert to"""
        return ".json"
    
    def _convert_sexp_formula(self, formula: Any) -> Dict:
        """Convert SexpFormula object to dictionary
        
        Args:
            formula: SexpFormula object or dictionary
            
        Returns:
            dict: Dictionary representation
        """
        if hasattr(formula, '__dict__'):
            return {k: self._convert_sexp_formula(v) for k, v in formula.__dict__.items()}
        elif isinstance(formula, dict):
            return {k: self._convert_sexp_formula(v) for k, v in formula.items()}
        elif isinstance(formula, list):
            return [self._convert_sexp_formula(item) for item in formula]
        else:
            return formula

    def _campaign_to_fc2file(self, campaign: Campaign) -> FC2File:
        """Convert Campaign object to FC2File
        
        Args:
            campaign: Parsed Campaign object
            
        Returns:
            FC2File: Converted file data
        """
        return FC2File(
            name=campaign.name,
            type=self.campaign_parser.get_campaign_type_name(campaign.type),
            description=campaign.description,
            flags=campaign.flags,
            intro_cutscene=campaign.intro_cutscene,
            end_cutscene=campaign.end_cutscene,
            starting_ships=campaign.starting_ships,
            starting_weapons=campaign.starting_weapons,
            missions=[{
                'filename': mission.filename,
                'flags': mission.flags,
                'main_hall': mission.main_hall,
                'debriefing_persona': mission.debriefing_persona,
                'formula': self._convert_sexp_formula(mission.formula),
                'level': mission.level,
                'position': mission.position,
                'mission_loop': mission.mission_loop,
                'mission_loop_text': mission.mission_loop_text,
                'mission_loop_anim': mission.mission_loop_anim,
                'mission_loop_sound': mission.mission_loop_sound,
                'mission_loop_formula': self._convert_sexp_formula(mission.mission_loop_formula)
            } for mission in campaign.missions]
        )
    
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
        """Convert a .fc2 file to JSON format
        
        Args:
            input_path: Path to input .fc2 file
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
            
            # Parse content using campaign parser
            logger.debug("Starting parsing of campaign file content")
            parsed_campaign = self.campaign_parser.parse(iter(content.splitlines()))
            logger.debug("Successfully parsed campaign file content")
            
            # Convert Campaign to FC2File
            fc2_data = self._campaign_to_fc2file(parsed_campaign)
            
            # Convert dataclass to dictionary for JSON serialization
            logger.debug("Converting parsed data to JSON-compatible format")
            json_data = self._dataclass_to_dict(fc2_data)
            
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
