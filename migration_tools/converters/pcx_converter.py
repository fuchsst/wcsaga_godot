#!/usr/bin/env python3
import logging
from pathlib import Path
from PIL import Image
from .base_converter import BaseConverter

logger = logging.getLogger(__name__)

class PCXConverter(BaseConverter):
    """Converter for PCX image files"""
    
    @property
    def source_extension(self) -> str:
        return ".pcx"
        
    @property
    def target_extension(self) -> str:
        return ".png"
    
    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """
        Convert PCX file to PNG using Pillow
        
        Args:
            input_path: Path to input PCX file
            output_path: Path to write PNG file
            
        Returns:
            bool: True if conversion successful, False otherwise
        """
        try:
            with Image.open(input_path) as img:
                # Convert to RGBA if needed
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                img.save(output_path, 'PNG')
            return True
            
        except Exception as e:
            logger.error(f"Failed to convert {input_path}: {e}")
            return False
