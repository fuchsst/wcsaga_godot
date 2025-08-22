#!/usr/bin/env python3
"""
Path Utilities for WCS-Godot Conversion

Provides common path manipulation and file system utilities
for the conversion pipeline.

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-003 - Asset Organization and Cataloging
"""

import os
from pathlib import Path
from typing import List, Optional, Union


def sanitize_filename(filename: str) -> str:
    """
    Sanitize filename for cross-platform compatibility.
    
    Args:
        filename: Original filename
        
    Returns:
        Sanitized filename safe for file system
    """
    # Remove or replace invalid characters
    invalid_chars = '<>:"/\\|?*'
    sanitized = filename
    
    for char in invalid_chars:
        sanitized = sanitized.replace(char, '_')
    
    # Remove leading/trailing dots and spaces
    sanitized = sanitized.strip('. ')
    
    # Ensure it's not empty
    if not sanitized:
        sanitized = "unnamed"
    
    return sanitized

def ensure_directory(path: Union[str, Path]) -> Path:
    """
    Ensure directory exists, creating it if necessary.
    
    Args:
        path: Directory path
        
    Returns:
        Path object for the directory
    """
    dir_path = Path(path)
    dir_path.mkdir(parents=True, exist_ok=True)
    return dir_path

def get_relative_path(file_path: Path, base_path: Path) -> Path:
    """
    Get relative path from base path.
    
    Args:
        file_path: Target file path
        base_path: Base directory path
        
    Returns:
        Relative path from base to file
    """
    try:
        return file_path.relative_to(base_path)
    except ValueError:
        # If paths are not related, return the file path as-is
        return file_path

def find_files_by_extension(directory: Path, extensions: List[str], 
                          recursive: bool = True) -> List[Path]:
    """
    Find all files with specific extensions in directory.
    
    Args:
        directory: Directory to search
        extensions: List of extensions (with or without dots)
        recursive: Whether to search subdirectories
        
    Returns:
        List of matching file paths
    """
    if not directory.exists():
        return []
    
    # Normalize extensions
    norm_extensions = []
    for ext in extensions:
        if not ext.startswith('.'):
            ext = '.' + ext
        norm_extensions.append(ext.lower())
    
    files = []
    pattern = "**/*" if recursive else "*"
    
    for file_path in directory.glob(pattern):
        if file_path.is_file() and file_path.suffix.lower() in norm_extensions:
            files.append(file_path)
    
    return sorted(files)

def create_godot_directory_structure(project_root: Path) -> None:
    """
    Create standard Godot project directory structure.
    
    Args:
        project_root: Root of Godot project
    """
    directories = [
        "assets",
        "assets/textures",
        "assets/models",
        "assets/audio",
        "assets/missions",
        "assets/tables",
        "scripts",
        "scenes",
        "resources",
        "converted"
    ]
    
    for directory in directories:
        ensure_directory(project_root / directory)

def get_file_size_human(file_path: Path) -> str:
    """
    Get human-readable file size.
    
    Args:
        file_path: Path to file
        
    Returns:
        Human-readable size string
    """
    try:
        size = file_path.stat().st_size
        
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024.0:
                return f"{size:.1f} {unit}"
            size /= 1024.0
        
        return f"{size:.1f} TB"
        
    except (OSError, FileNotFoundError):
        return "Unknown"

def is_same_file(path1: Path, path2: Path) -> bool:
    """
    Check if two paths refer to the same file.
    
    Args:
        path1: First file path
        path2: Second file path
        
    Returns:
        True if paths refer to same file
    """
    try:
        return path1.samefile(path2)
    except (OSError, FileNotFoundError):
        return False

def backup_file(file_path: Path, backup_suffix: str = ".backup") -> Optional[Path]:
    """
    Create backup of file.
    
    Args:
        file_path: File to backup
        backup_suffix: Suffix for backup file
        
    Returns:
        Path to backup file or None if failed
    """
    try:
        if not file_path.exists():
            return None
        
        backup_path = file_path.with_suffix(file_path.suffix + backup_suffix)
        
        # Find unique backup name if file exists
        counter = 1
        while backup_path.exists():
            backup_path = file_path.with_suffix(f"{file_path.suffix}{backup_suffix}.{counter}")
            counter += 1
        
        import shutil
        shutil.copy2(file_path, backup_path)
        return backup_path
        
    except Exception:
        return None

def clean_empty_directories(root_path: Path) -> int:
    """
    Remove empty directories recursively.
    
    Args:
        root_path: Root directory to clean
        
    Returns:
        Number of directories removed
    """
    removed_count = 0
    
    try:
        # Walk directories bottom-up to handle nested empty dirs
        for dirpath, dirnames, filenames in os.walk(root_path, topdown=False):
            dir_path = Path(dirpath)
            
            # Skip root directory
            if dir_path == root_path:
                continue
            
            # Check if directory is empty
            try:
                if not any(dir_path.iterdir()):
                    dir_path.rmdir()
                    removed_count += 1
            except OSError:
                # Directory not empty or permission error
                pass
    
    except Exception:
        pass
    
    return removed_count

def normalize_path_separators(path: str) -> str:
    """
    Normalize path separators for the current platform.
    
    Args:
        path: Path string with mixed separators
        
    Returns:
        Path with normalized separators
    """
    return str(Path(path))

def get_project_root() -> Path:
    """
    Get the Godot project root directory.
    
    Returns:
        Path to project root (where project.godot is located)
    """
    current = Path(__file__).resolve()
    
    # Look for project.godot file in parent directories
    for parent in current.parents:
        if (parent / "project.godot").exists():
            return parent
    
    # If not found, assume the target directory is project root
    return Path(__file__).resolve().parent.parent