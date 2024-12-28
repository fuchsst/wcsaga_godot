#!/usr/bin/env python3
import logging
from pathlib import Path
from PIL import Image
from .base_converter import BaseConverter

try:
    from wand.image import Image as WandImage
except ImportError:
    WandImage = None

logger = logging.getLogger(__name__)

class DDSConverter(BaseConverter):
    """Converter for DDS texture files"""
    
    @property
    def source_extension(self) -> str:
        return ".dds"
        
    @property
    def target_extension(self) -> str:
        return ".png"
    
    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """
        Convert DDS file to PNG using either Wand or Pillow
        
        Args:
            input_path: Path to input DDS file
            output_path: Path to write PNG file
            
        Returns:
            bool: True if conversion successful, False otherwise
        """
        try:
            # Try using Wand first if available
            if WandImage is not None:
                with WandImage(filename=str(input_path)) as img:
                    img.format = 'png'
                    img.save(filename=str(output_path))
                return True
                
            # Fallback to Pillow
            with Image.open(input_path) as img:
                # Convert to RGBA if needed
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                img.save(output_path, 'PNG')
            return True
            
        except Exception as e:
            logger.error(f"Failed to convert {input_path}: {e}")
            return False
