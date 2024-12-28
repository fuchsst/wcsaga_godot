#!/usr/bin/env python3
"""
Tool for analyzing Wing Commander Saga C++ project structure and extracting function signatures.
Outputs formatted data suitable for LLM analysis.
"""

import os
import re
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
from dataclasses import dataclass, asdict
import clang.cindex
from clang.cindex import CursorKind, Index, TranslationUnit

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

@dataclass
class IncludeInfo:
    """Represents an include directive."""
    path: str        # Path of included file
    line: int        # Line number of include directive
    is_system: bool  # True for <> includes, False for "" includes

@dataclass
class FunctionSignature:
    """Represents a C++ function signature."""
    name: str
    return_type: str
    parameters: List[str]
    access: str  # public, private, protected
    is_virtual: bool
    is_static: bool
    is_const: bool
    start_line: int  # Line number where the method definition starts
    end_line: int    # Line number where the method definition ends
    source_file: str # Path to the source file containing the implementation

@dataclass
class ClassInfo:
    """Represents a C++ class definition."""
    name: str
    functions: List[FunctionSignature]
    base_classes: List[str]
    namespace: str = ""  # Namespace containing the class

@dataclass
class FileInfo:
    """Represents a source file and its contents."""
    path: str
    includes: List[IncludeInfo]
    classes: List[ClassInfo]
    global_functions: List[FunctionSignature]
    namespaces: List[str]  # List of namespaces used in the file

@dataclass
class FileStructure:
    """Represents the structure of a file or directory."""
    name: str
    type: str  # 'file' or 'dir'
    path: str
    children: Optional[List['FileStructure']] = None

class ProjectAnalyzer:
    """Analyzes C++ project structure and extracts code information."""
    
    def __init__(self, project_root: str, compilation_db_path: Optional[str] = None):
        self.project_root = Path(project_root)
        logger.info(f"Initializing project analyzer for: {self.project_root}")
        self.index = Index.create()
        self.cpp_extensions = {'.cpp', '.cxx', '.cc', '.h', '.hpp', '.hxx'}
        
        # Find system include paths
        def find_windows_sdk():
            sdk_paths = [
                Path('C:/Program Files (x86)/Windows Kits/10/Include'),
                Path('C:/Program Files/Windows Kits/10/Include')
            ]
            for sdk_root in sdk_paths:
                if not sdk_root.exists():
                    continue
                # Find latest SDK version
                versions = [x for x in sdk_root.iterdir() if x.is_dir()]
                if not versions:
                    continue
                latest = max(versions)
                paths = []
                for subdir in ['ucrt', 'um', 'shared']:
                    path = latest / subdir
                    if path.exists():
                        paths.append(str(path))
                if paths:
                    return paths
            return []
            
        def find_msvc():
            vs_paths = [
                Path('C:/Program Files/Microsoft Visual Studio'),
                Path('C:/Program Files (x86)/Microsoft Visual Studio')
            ]
            for vs_root in vs_paths:
                if not vs_root.exists():
                    continue
                # Find latest VS version
                editions = ['Enterprise', 'Professional', 'Community']
                for year in ['2022', '2019', '2017']:
                    for edition in editions:
                        msvc_path = vs_root / year / edition / 'VC/Tools/MSVC'
                        if msvc_path.exists():
                            versions = [x for x in msvc_path.iterdir() if x.is_dir()]
                            if versions:
                                return str(max(versions) / 'include')
            return None
        
        # Build include paths
        include_paths = [str(self.project_root / 'code')]  # Project includes
        include_paths.extend(find_windows_sdk())  # SDK includes
        msvc_path = find_msvc()  # MSVC includes
        if msvc_path:
            include_paths.append(msvc_path)
            
        # Default compiler flags
        self.default_flags = ['-x', 'c++']  # Force C++ mode
        
        # Add include paths
        for path in include_paths:
            self.default_flags.extend(['-I', path])
            
        # Add defines
        self.default_flags.extend([
            '-std=c++14',  # C++14 standard
            '-D__cplusplus',
            '-DWIN32',
            '-D_WIN32',
            '-D_MSC_VER=1937',  # VS2022 version
            '-D_M_IX86',
            '-D_MSVC_LANG=201402L',  # C++14 mode
            '-D_MT',
            '-D_DLL',
            '-DWIN32_LEAN_AND_MEAN',
            '-DNOMINMAX',
            '-D_CRT_SECURE_NO_WARNINGS',
            '-D_HAS_EXCEPTIONS=1',
            '-DUNICODE',
            '-D_UNICODE'
        ])
        
        logger.info("Using include paths:")
        for path in include_paths:
            logger.info(f"  {path}")
        
        # Load compilation database if available
        self.compilation_db = None
        if compilation_db_path:
            try:
                self.compilation_db = clang.cindex.CompilationDatabase.fromDirectory(compilation_db_path)
                logger.info(f"Loaded compilation database from {compilation_db_path}")
            except:
                logger.warning(f"Failed to load compilation database from {compilation_db_path}")
        
    def get_source_files(self) -> List[Path]:
        """Returns all C++ source files in the project."""
        logger.info("Scanning for C++ source files...")
        source_files = []
        total_files = 0
        cpp_files = 0
        
        for path in self.project_root.rglob('*'):
            total_files += 1
            if path.suffix.lower() in self.cpp_extensions:
                source_files.append(path)
                cpp_files += 1
                if cpp_files % 10 == 0:
                    logger.info(f"Found {cpp_files} C++ files (scanned {total_files} total files)")
        
        logger.info(f"Scan complete. Found {cpp_files} C++ files out of {total_files} total files")
        return source_files

    def analyze_file_structure(self) -> FileStructure:
        """Analyzes and returns the project's file structure."""
        logger.info("Analyzing file structure...")

        def create_structure(path: Path) -> FileStructure:
            name = path.name
            rel_path = str(path.relative_to(self.project_root))
            
            if path.is_file():
                return FileStructure(name=name, type='file', path=rel_path)
            
            children = []
            for child in sorted(path.iterdir()):
                # Skip common ignore patterns
                if child.name.startswith('.') or child.name.startswith('__'):
                    continue
                children.append(create_structure(child))
            
            return FileStructure(
                name=name,
                type='dir',
                path=rel_path,
                children=children
            )

        structure = create_structure(self.project_root)
        logger.info("File structure analysis complete")
        return structure

    def _get_includes(self, tu: TranslationUnit) -> List[IncludeInfo]:
        """Extract include directives from translation unit."""
        includes = []
        for inc in tu.get_includes():
            # Only include files from our codebase
            include_path = Path(inc.include.name)
            try:
                # Try to make the path relative to project root
                rel_path = include_path.relative_to(self.project_root)
                includes.append(IncludeInfo(
                    path=str(rel_path),
                    line=inc.location.line,
                    is_system=inc.depth > 0  # System includes typically have depth > 0
                ))
            except ValueError:
                # Skip includes outside project root
                continue
        return includes

    def _get_namespace(self, cursor) -> str:
        """Get the full namespace of a cursor."""
        namespaces = []
        parent = cursor.semantic_parent
        while parent and parent.kind == CursorKind.NAMESPACE:
            namespaces.append(parent.spelling)
            parent = parent.semantic_parent
        return "::".join(reversed(namespaces))

    def _process_function(self, cursor, class_name: Optional[str] = None) -> FunctionSignature:
        """Processes a function declaration and extracts its signature."""
        # Find definition location
        definition_info = self._find_definition(cursor)
        if definition_info:
            source_file, start_line, end_line = definition_info
        else:
            # If no definition found, use declaration location
            source_file = str(Path(cursor.location.file.name).relative_to(self.project_root))
            start_line = cursor.extent.start.line
            end_line = cursor.extent.end.line

        return FunctionSignature(
            name=cursor.spelling,
            return_type=cursor.result_type.spelling,
            parameters=[param.type.spelling for param in cursor.get_arguments()],
            access=self._get_access_specifier(cursor),
            is_virtual=cursor.is_virtual_method(),
            is_static=cursor.is_static_method(),
            is_const=cursor.is_const_method(),
            start_line=start_line,
            end_line=end_line,
            source_file=source_file,
        )

    def _find_definition(self, cursor) -> Optional[Tuple[str, int, int]]:
        """Find the definition location of a function."""
        def_cursor = cursor.get_definition()
        if def_cursor:
            # Get the source range
            start = def_cursor.extent.start
            end = def_cursor.extent.end
            if start.file:
                return (
                    str(Path(start.file.name).relative_to(self.project_root)),
                    start.line,
                    end.line
                )
        return None

    def _process_class(self, cursor) -> ClassInfo:
        """Processes a class declaration and extracts its information."""
        logger.debug(f"Processing class: {cursor.spelling}")
        functions = []
        base_classes = []
        namespace = self._get_namespace(cursor)

        for c in cursor.get_children():
            if c.kind == CursorKind.CXX_BASE_SPECIFIER:
                base_classes.append(c.spelling)
                logger.debug(f"Found base class: {c.spelling}")
            elif c.kind == CursorKind.CXX_METHOD:
                func_sig = self._process_function(c, cursor.spelling)
                functions.append(func_sig)
                logger.debug(f"Found method: {func_sig.name}")

        return ClassInfo(
            name=cursor.spelling,
            functions=functions,
            base_classes=base_classes,
            namespace=namespace
        )

    def _get_access_specifier(self, cursor) -> str:
        """Gets the access specifier (public, private, protected) for a class member."""
        if cursor.access_specifier:
            return cursor.access_specifier.name.lower()
        return 'public'  # Default access specifier

    def _get_compile_args(self, file_path: Path) -> List[str]:
        """Get compilation arguments for a file."""
        if self.compilation_db:
            # Try to get commands from compilation database
            commands = self.compilation_db.getCompileCommands(str(file_path))
            if commands:
                cmd = commands[0]
                return [arg for arg in cmd.arguments if arg != cmd.filename]
        
        # Use default flags if no compilation database or no entry found
        return self.default_flags + [
            # Add include path relative to file
            '-I', str(file_path.parent)
        ]

    def parse_file(self, file_path: Path) -> Optional[FileInfo]:
        """Parses a C++ file and extracts class and function information."""
        logger.info(f"Parsing file: {file_path.relative_to(self.project_root)}")
        
        # Skip files with too many errors
        error_count = 0
        MAX_ERRORS = 1000  # Increased error tolerance
        try:
            # Get compilation arguments
            args = self._get_compile_args(file_path)
            
            # Parse with compilation arguments
            tu = self.index.parse(str(file_path), args)
            if not tu:
                logger.warning(f"Failed to parse {file_path}")
                return None
                
            # Check for parse errors
            ignorable_errors = [
                'functions that differ only in their return type cannot be overloaded',
                'conflicting types for',
                'redefinition of',
                '_Is_memfunptr'
            ]
            
            critical_error_count = 0
            for diag in tu.diagnostics:
                if diag.severity >= clang.cindex.Diagnostic.Error:
                    # Check if this is an ignorable error
                    is_ignorable = any(err in diag.spelling for err in ignorable_errors)
                    
                    if not is_ignorable:
                        critical_error_count += 1
                        if critical_error_count < MAX_ERRORS:
                            logger.warning(f"Critical parse error in {file_path}: {diag.spelling}")
                        elif critical_error_count == MAX_ERRORS:
                            logger.warning(f"Too many critical errors in {file_path}, suppressing further messages")
                    else:
                        logger.debug(f"Ignoring non-critical error in {file_path}: {diag.spelling}")
                        
            if critical_error_count >= MAX_ERRORS:
                logger.error(f"Skipping {file_path} due to too many critical errors")
                return None

            # Get includes and namespaces
            try:
                includes = self._get_includes(tu)
                namespaces = set()

                file_info = FileInfo(
                    path=str(file_path.relative_to(self.project_root)),
                    includes=includes,
                    classes=[],
                    global_functions=[],
                    namespaces=[]
                )

                for cursor in tu.cursor.walk_preorder():
                    try:
                        # Skip cursors without valid location
                        if not cursor.location or not cursor.location.file:
                            continue
                            
                        # Only process cursors from this file
                        if Path(cursor.location.file.name) == file_path:
                            if cursor.kind == CursorKind.NAMESPACE:
                                namespaces.add(cursor.spelling)
                            elif cursor.kind == CursorKind.CLASS_DECL:
                                try:
                                    class_info = self._process_class(cursor)
                                    if class_info:
                                        file_info.classes.append(class_info)
                                        logger.debug(f"Found class: {class_info.name}")
                                except Exception as e:
                                    logger.debug(f"Failed to process class in {file_path}: {e}")
                            elif cursor.kind == CursorKind.FUNCTION_DECL:
                                try:
                                    func_sig = self._process_function(cursor)
                                    if func_sig:
                                        file_info.global_functions.append(func_sig)
                                        logger.debug(f"Found global function: {func_sig.name}")
                                except Exception as e:
                                    logger.debug(f"Failed to process function in {file_path}: {e}")
                    except Exception as e:
                        logger.debug(f"Failed to process cursor in {file_path}: {e}")
                        continue

                file_info.namespaces = sorted(list(namespaces))
                logger.info(f"Successfully parsed {file_path.name}: "
                           f"{len(file_info.classes)} classes, "
                           f"{len(file_info.global_functions)} global functions")
                return file_info
            except Exception as e:
                logger.error(f"Failed to process file contents for {file_path}: {e}")
                return None
        except Exception as e:
            logger.error(f"Error parsing {file_path}: {e}")
            return None

    def analyze_project(self, output_dir: str, force_reanalyze: bool = False):
        """Analyzes the project and saves results in separate files.
        
        Args:
            output_dir: Directory to save analysis results
            force_reanalyze: Force reanalysis even if results exist
        """
        logger.info("Starting project analysis...")
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        # Save file structure
        structure = self.analyze_file_structure()
        structure_path = output_path / 'file_structure.json'
        with open(structure_path, 'w', encoding='utf-8') as f:
            json.dump(asdict(structure), f, indent=2)
        logger.info(f"Saved file structure to {structure_path}")

        # Analyze source files by folder
        files = self.get_source_files()
        folder_files: Dict[str, List[Path]] = {}
        
        # Group files by folder
        for file_path in files:
            folder = str(file_path.parent.relative_to(self.project_root))
            if folder not in folder_files:
                folder_files[folder] = []
            folder_files[folder].append(file_path)

        # First pass: Basic analysis
        total_folders = len(folder_files)
        
        for idx, (folder, folder_file_list) in enumerate(folder_files.items(), 1):
            # Use path from file structure for output file
            output_file = output_path / Path(folder).with_suffix('.json')
            
            # Check if we need to analyze this folder
            should_analyze = force_reanalyze or not output_file.exists()
            
            if should_analyze:
                logger.info(f"Processing folder {idx}/{total_folders}: {folder}")
                folder_data = []
                successful_files = 0
                failed_files = 0
                
                for file_path in folder_file_list:
                    try:
                        file_info = self.parse_file(file_path)
                        if file_info:
                            folder_data.append(asdict(file_info))
                            successful_files += 1
                        else:
                            failed_files += 1
                    except Exception as e:
                        logger.error(f"Failed to analyze {file_path}: {e}")
                        failed_files += 1

                if folder_data:
                    logger.info(f"Folder {folder}: Successfully analyzed {successful_files} files, {failed_files} failed")
                    # Ensure parent directories exist
                    output_file.parent.mkdir(parents=True, exist_ok=True)
                    with open(output_file, 'w', encoding='utf-8') as f:
                        json.dump({
                            'folder': folder,
                            'files': folder_data
                        }, f, indent=2)
                    logger.info(f"Saved analysis for {folder} to {output_file}")
            else:
                logger.info(f"Skipping folder {idx}/{total_folders}: {folder} (analysis exists)")

        logger.info(f"Project analysis complete. Results saved in {output_dir}/")

def main():
    """Main entry point for the script."""
    import argparse
    parser = argparse.ArgumentParser(description='Analyze C++ project structure')
    parser.add_argument('project_path', help='Path to the C++ project root')
    parser.add_argument('--output-dir', '-o', default='analysis_results',
                       help='Output directory for analysis files')
    parser.add_argument('--force', '-f', action='store_true',
                       help='Force reanalysis of all folders')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug logging')
    args = parser.parse_args()

    if args.debug:
        logger.setLevel(logging.DEBUG)

    logger.info("Starting C++ project analysis")
    analyzer = ProjectAnalyzer(args.project_path)
    analyzer.analyze_project(args.output_dir, force_reanalyze=args.force)
    logger.info("Analysis complete")

if __name__ == '__main__':
    main()
