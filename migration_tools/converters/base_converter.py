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
        pass

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
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.force = force
        
        if not self.input_dir.exists():
            raise ValueError(f"Input directory does not exist: {self.input_dir}")
            
        # Create output directory if it doesn't exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
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
        
        Args:
            input_path: Path to input file
            
        Returns:
            Path: Corresponding output path with new extension
        """
        # Get relative path from input root
        rel_path = input_path.relative_to(self.input_dir)
        
        # Create output path with new extension
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
        
        # Find all files with matching extension
        for input_path in self.input_dir.rglob(f"*{self.source_extension}"):
            output_path = self.get_output_path(input_path)
            
            try:
                # Skip if output exists and not forcing
                if output_path.exists() and not self.force:
                    logger.info(f"Skipping {input_path} (output exists)")
                    continue
                    
                if self.convert_file(input_path, output_path):
                    logger.info(f"Converted {input_path} -> {output_path}")
                else:
                    logger.error(f"Failed to convert {input_path}")
                    success = False
            except Exception as e:
                logger.error(f"Error converting {input_path}: {e}")
                success = False
                
        return success
