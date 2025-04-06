#!/usr/bin/env python3
import os
from pathlib import Path
import logging
from abc import ABC, abstractmethod
from typing import Optional

# Setup logging
logger = logging.getLogger(__name__)

class AsyncProgress:
    """Simple progress reporting class"""

    def __init__(self):
        self.target: int = 0
        self.current: int = 0
        self.message: str = ""

    def setTarget(self, target: int) -> None:
        """Set the target number of steps"""
        self.target = target
        self.current = 0

    def setMessage(self, message: str) -> None:
        """Set the current progress message"""
        self.message = message

    def incrementProgress(self) -> None:
        """Increment progress by one step"""
        self.current += 1

    def incrementWithMessage(self, message: str) -> None:
        """Increment progress and set message"""
        self.message = message
        self.current += 1

    def Notify(self) -> None:
        """Notify progress update"""
        # In a real async scenario, this would update a UI or log progress.
        # For this context, we can just log it.
        if self.target > 0:
            percent = (self.current / self.target) * 100
            logger.info(f"Progress: {self.current}/{self.target} ({percent:.1f}%) - {self.message}")
        else:
            logger.info(f"Progress: {self.message}")


class BaseConverter(ABC):
    """Base class for file format converters"""

    def __init__(self, input_dir: str = "extracted", output_dir: str = "converted", force: bool = False):
        """
        Initialize converter with input and output directories

        Args:
            input_dir: Root directory containing extracted files
            output_dir: Root directory for converted files
            force: If True, overwrite existing files. If False, skip them.
        """
        # Use absolute paths based on the project root (assuming script runs from project root)
        # Adjust this logic if the script execution context is different.
        project_root = Path(__file__).parent.parent.parent # Go up three levels from migration_tools/converters
        self.input_dir = project_root / input_dir
        self.output_dir = project_root / output_dir
        self.force = force

        if not self.input_dir.exists():
            logger.warning(f"Input directory does not exist: {self.input_dir}")
            # Don't raise error, allow creation later if needed by specific converters

        # Create output directory if it doesn't exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Converter initialized: Input='{self.input_dir}', Output='{self.output_dir}', Force={self.force}")


    @property
    @abstractmethod
    def source_extension(self) -> str:
        """File extension this converter handles (e.g. '.dds')"""
        pass

    @property
    @abstractmethod
    def target_extension(self) -> str:
        """File extension to convert to (e.g. '.png')"""
        pass

    def get_output_path(self, input_path: Path) -> Path:
        """
        Get the output path for a given input path, maintaining directory structure
        relative to the converter's input/output base directories.

        Args:
            input_path: Path to input file

        Returns:
            Path: Corresponding output path with new extension
        """
        try:
            # Get relative path from input root
            rel_path = input_path.relative_to(self.input_dir)
        except ValueError:
            # If input_path is not inside self.input_dir, handle appropriately
            # For now, let's assume it's a direct file path and place output relative to self.output_dir
            logger.warning(f"Input path {input_path} is not relative to {self.input_dir}. Placing output directly in {self.output_dir}.")
            rel_path = input_path.name # Use only the filename

        # Create output path with new extension
        # Ensure rel_path is treated as relative before joining
        output_path = self.output_dir / rel_path.parent / (rel_path.stem + self.target_extension)

        # Ensure output directory exists
        output_path.parent.mkdir(parents=True, exist_ok=True)

        return output_path

    @abstractmethod
    def convert_file(self, input_path: Path, output_path: Path) -> bool:
        """
        Convert a single file

        Args:
            input_path: Path to input file
            output_path: Path to write converted file

        Returns:
            bool: True if conversion successful, False otherwise
        """
        pass

    def convert_all(self) -> bool:
        """
        Convert all files with matching extension in input directory

        Returns:
            bool: True if all conversions successful, False if any failed
        """
        success = True
        files_to_convert = list(self.input_dir.rglob(f"*{self.source_extension}"))
        total_files = len(files_to_convert)
        logger.info(f"Found {total_files} files with extension '{self.source_extension}' in '{self.input_dir}'")

        progress = AsyncProgress()
        progress.setTarget(total_files)

        for i, input_path in enumerate(files_to_convert):
            output_path = self.get_output_path(input_path)
            progress.setMessage(f"Processing {input_path.name}")
            progress.current = i + 1

            try:
                # Skip if output exists and not forcing
                if output_path.exists() and not self.force:
                    logger.debug(f"Skipping {input_path} (output exists)")
                    continue

                if self.convert_file(input_path, output_path):
                    logger.debug(f"Converted {input_path} -> {output_path}")
                else:
                    logger.error(f"Failed to convert {input_path}")
                    success = False
            except Exception as e:
                logger.error(f"Error converting {input_path}: {e}", exc_info=True)
                success = False

            progress.Notify() # Log progress

        logger.info(f"Conversion process finished for '{self.source_extension}'. Success: {success}")
        return success
