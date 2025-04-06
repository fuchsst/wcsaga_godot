#!/usr/bin/env python3
import logging
from pathlib import Path
from PIL import Image, UnidentifiedImageError
from .base_converter import BaseConverter

logger = logging.getLogger(__name__)

class PCXConverter(BaseConverter):
    """Converter for PCX image files"""

    def __init__(self, input_dir: str = "extracted", output_dir: str = "assets/textures", force: bool = False):
        # Default output to assets/textures
        super().__init__(input_dir, output_dir, force)
        self.logger = logging.getLogger(__name__)

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
                # Convert to RGBA to ensure consistency and handle potential palette transparency
                # Pillow usually handles PCX palettes well during conversion.
                # If specific transparency handling is needed (e.g., based on a color index),
                # it would need to be added here after loading the palette.
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')

                # Save as PNG
                img.save(output_path, 'PNG')
                self.logger.debug(f"Converted {input_path} to {output_path}")
            return True
        except UnidentifiedImageError:
             self.logger.error(f"Failed to identify or open PCX file: {input_path}. It might be corrupted or not a valid PCX.")
             return False
        except Exception as e:
            self.logger.error(f"Failed to convert {input_path}: {e}", exc_info=True)
            # Attempt to remove potentially corrupted output file
            if output_path.exists():
                try:
                    output_path.unlink()
                except OSError:
                    pass # Ignore if removal fails
            return False
