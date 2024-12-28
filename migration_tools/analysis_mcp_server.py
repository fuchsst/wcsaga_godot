#!/usr/bin/env python3
"""
MCP (Module Communication Protocol) server for C++ project analysis.
Can work with both direct analysis and preprocessed analysis files.
"""

import os
import re
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
from functools import lru_cache
from package_analyzer import PackageAnalyzer
import clang.cindex
from clang.cindex import CursorKind, Index
import anyio
import mcp.types as types
from mcp.server import Server, NotificationOptions
from mcp.server.models import InitializationOptions

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

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

@dataclass
class ClassInfo:
    """Represents a C++ class definition."""
    name: str
    functions: List[FunctionSignature]
    base_classes: List[str]

@dataclass
class FileInfo:
    """Represents a source file and its contents."""
    path: str
    classes: List[ClassInfo]
    global_functions: List[FunctionSignature]

@dataclass
class FileStructure:
    """Represents the structure of a file or directory."""
    name: str
    type: str  # 'file' or 'dir'
    path: str
    children: Optional[List['FileStructure']] = None

def strip_cpp_comments(code: str) -> str:
    """Strip C++ comments from code while preserving line numbers."""
    # Remove multi-line comments
    code = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group().count('\n'), code, flags=re.DOTALL)
    # Remove single-line comments
    code = re.sub(r'//.*$', '', code, flags=re.MULTILINE)
    return code

class PreprocessedAnalyzer:
    """Handles analysis using preprocessed JSON files."""
    
    def __init__(self, analysis_dir: str, package_analysis_dir: str, project_root: str):
        self.analysis_dir = Path(analysis_dir)
        self.project_root = Path(project_root)
        self.package_analysis_dir = Path(package_analysis_dir) if package_analysis_dir else None
        
        # Cache for analysis data
        self.folder_data: Dict[str, Dict] = {}  # folder path -> analysis data
        self.file_data: Dict[str, Dict] = {}    # file path -> file analysis data
        self.class_data: Dict[str, Dict] = {}   # class name -> class info
        self.method_data: Dict[str, Dict] = {}  # class::method -> method info
        self.package_data: Dict[str, Dict] = {} # package path -> package info
        self.source_cache: Dict[str, str] = {}  # file path -> source content
        self.structure_cache: Optional[FileStructure] = None  # cached file structure
        
        # Load all analysis data on startup
        self._load_all_analysis_data()
        if package_analysis_dir:
            self._load_all_package_data()
            
    def _load_all_analysis_data(self):
        """Load all analysis JSON files into memory."""
        logger.info(f"Loading analysis data from {self.analysis_dir}...")
        logger.debug(f"Analysis directory exists: {self.analysis_dir.exists()}")
        logger.debug(f"Analysis directory absolute path: {self.analysis_dir.absolute()}")
        
        json_files = list(self.analysis_dir.glob('*.json'))
        logger.info(f"Found {len(json_files)} JSON files")
        logger.debug(f"JSON files: {[str(f) for f in json_files]}")
        
        for json_file in json_files:
            logger.info(f"Processing {json_file}")
            try:
                with open(json_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    if 'folder' in data and 'files' in data:
                        folder_path = data['folder']
                        logger.debug(f"Loading folder: {folder_path}")
                        self.folder_data[folder_path] = data
                        
                        # Index all files in this folder
                        for file_info in data['files']:
                            file_path = file_info['path']
                            logger.debug(f"Indexing file: {file_path}")
                            self.file_data[file_path] = file_info
                            
                            # Index classes and their methods
                            for class_info in file_info.get('classes', []):
                                class_name = class_info['name']
                                logger.debug(f"Indexing class: {class_name}")
                                self.class_data[class_name] = {
                                    'info': class_info,
                                    'file': file_path
                                }
                                
                                # Index class methods
                                for method in class_info.get('functions', []):
                                    method_key = f"{class_name}::{method['name']}"
                                    logger.debug(f"Indexing method: {method_key}")
                                    self.method_data[method_key] = {
                                        'info': method,
                                        'class': class_name,
                                        'file': file_path
                                    }
                            
                            # Index global functions
                            for func in file_info.get('global_functions', []):
                                logger.debug(f"Indexing global function: {func['name']}")
                                self.method_data[func['name']] = {
                                    'info': func,
                                    'file': file_path
                                }
            except Exception as e:
                logger.error(f"Error loading analysis file {json_file}: {e}", exc_info=True)
                
        logger.info(f"Loaded {len(self.folder_data)} folders, {len(self.file_data)} files, "
                   f"{len(self.class_data)} classes, {len(self.method_data)} methods")
        logger.debug("Folder data keys: " + str(list(self.folder_data.keys())))
        logger.debug("File data keys: " + str(list(self.file_data.keys())))
        logger.debug("Class data keys: " + str(list(self.class_data.keys())))
        logger.debug("Method data keys: " + str(list(self.method_data.keys())))
                   
    def _load_all_package_data(self):
        """Load all package analysis JSON files into memory."""
        if not self.package_analysis_dir:
            logger.error("Package analysis directory not provided")
            return
        if not self.package_analysis_dir.exists():
            logger.error(f"Package analysis directory does not exist: {self.package_analysis_dir}")
            return
            
        logger.info(f"Loading package analysis data from {self.package_analysis_dir}...")
        try:
            json_files = list(self.package_analysis_dir.glob('*.json'))
            logger.info(f"Found {len(json_files)} JSON files")
            
            for json_file in json_files:
                logger.info(f"Processing {json_file}")
                try:
                    with open(json_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        if 'path' in data:
                            logger.info(f"Loaded package data for path: {data['path']}")
                            self.package_data[data['path']] = data
                        else:
                            logger.warning(f"File {json_file} missing 'path' field")
                except Exception as e:
                    logger.error(f"Error loading package analysis file {json_file}: {str(e)}", exc_info=True)
                    
            logger.info(f"Successfully loaded {len(self.package_data)} package analyses")
            logger.debug(f"Available package paths: {list(self.package_data.keys())}")
        except Exception as e:
            logger.error(f"Error during package data loading: {str(e)}", exc_info=True)

    def load_structure(self) -> Optional[FileStructure]:
        """Build the file structure from loaded folder data."""
        if self.structure_cache:
            return self.structure_cache
            
        try:
            # Create root structure
            root = FileStructure(
                name="root",
                type="dir",
                path="",
                children=[]
            )
            
            # Build tree from folder data
            for folder_path, folder_data in self.folder_data.items():
                # Create folder structure
                current_path = Path(folder_path)
                folder_struct = FileStructure(
                    name=current_path.name or folder_path,
                    type="dir",
                    path=folder_path,
                    children=[]
                )
                
                # Add files from this folder
                for file_info in folder_data.get('files', []):
                    file_path = file_info['path']
                    file_struct = FileStructure(
                        name=Path(file_path).name,
                        type="file",
                        path=file_path,
                        children=None
                    )
                    folder_struct.children.append(file_struct)
                
                root.children.append(folder_struct)
            
            self.structure_cache = root
            logger.info(f"Built file structure with {len(root.children)} top-level folders")
            return root
            
        except Exception as e:
            logger.error(f"Error building file structure: {e}")
            return None

    def load_folder_analysis(self, folder_path: str) -> Optional[Dict]:
        """Load analysis data for a specific folder."""
        # Normalize path separators
        folder_path = folder_path.replace('/', '\\')
        
        # First check if it's already loaded
        if folder_path in self.folder_data:
            return self.folder_data[folder_path]
            
        # Try to load from file
        try:
            json_path = self.analysis_dir / f"{folder_path}.json"
            if json_path.exists():
                with open(json_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    if 'folder' in data and 'files' in data:
                        self.folder_data[folder_path] = data
                        return data
            return None
        except Exception as e:
            logger.error(f"Error loading folder analysis for {folder_path}: {e}")
            return None

    def _read_source_file(self, file_path: str) -> Optional[str]:
        """Read and cache source file content."""
        if file_path in self.source_cache:
            return self.source_cache[file_path]
            
        try:
            full_path = self.project_root / file_path
            if not full_path.exists():
                logger.error(f"Source file not found: {full_path}")
                return None
                
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
                self.source_cache[file_path] = content
                return content
        except Exception as e:
            logger.error(f"Error reading source file {file_path}: {e}")
            return None

    def get_method_implementation(self, file_path: str, class_name: str, method_name: str) -> Optional[str]:
        """Get the C++ implementation code of a method."""
        try:
            # Find the folder containing this file
            folder = str(Path(file_path).parent)
            folder_data = self.load_folder_analysis(folder)
            
            if folder_data:
                for file_data in folder_data['files']:
                    if file_data['path'] == file_path:
                        for class_data in file_data['classes']:
                            if class_data['name'] == class_name:
                                for method in class_data['functions']:
                                    if method['name'] == method_name:
                                        # Get implementation from source file
                                        source_file = method.get('source_file')
                                        if not source_file:
                                            return None
                                            
                                        source_content = self._read_source_file(source_file)
                                        if not source_content:
                                            return None
                                            
                                        # Extract the implementation using line numbers
                                        start_line = method.get('start_line', 0)
                                        end_line = method.get('end_line', 0)
                                        if start_line and end_line:
                                            lines = source_content.splitlines()
                                            if 0 < start_line <= len(lines) and 0 < end_line <= len(lines):
                                                impl_lines = lines[start_line - 1:end_line]
                                                impl = '\n'.join(impl_lines)
                                                # Strip comments while preserving line numbers
                                                return strip_cpp_comments(impl)
            return None
        except Exception as e:
            logger.error(f"Error getting method implementation: {e}")
            return None

    def get_file_info(self, file_path: str) -> Optional[FileInfo]:
        """Get analysis information for a specific file."""
        # Normalize path separators
        file_path = file_path.replace('/', '\\')
        file_data = self.file_data.get(file_path)
        
        if file_data:
            return FileInfo(
                path=file_data['path'],
                classes=[ClassInfo(**c) for c in file_data.get('classes', [])],
                global_functions=[FunctionSignature(**f) for f in file_data.get('global_functions', [])]
            )
        return None

    def search_symbol(self, query: str) -> List[Dict]:
        """Search for symbols matching the query."""
        results = []
        query = query.lower()
        
        # Helper function for fuzzy matching
        def matches_query(text: str) -> bool:
            text = text.lower()
            # Split query into words for partial matching
            query_words = query.split()
            # Match if any word is a substring of the text
            return any(word in text for word in query_words)
        
        # Search in classes and their methods
        for class_name, class_data in self.class_data.items():
            if matches_query(class_name):
                results.append({
                    'type': 'class',
                    'name': class_name,
                    'file': class_data['file'],
                    'details': {
                        'base_classes': class_data['info'].get('base_classes', []),
                        'method_count': len(class_data['info'].get('functions', []))
                    }
                })
                
                # Include methods of matching classes
                for method in class_data['info'].get('functions', []):
                    method_name = method['name']
                    results.append({
                        'type': 'method',
                        'name': f"{class_name}::{method_name}",
                        'file': class_data['file'],
                        'details': {
                            'return_type': method.get('return_type', 'void'),
                            'access': method.get('access', 'public')
                        }
                    })
        
        # Search in all methods (both class methods and global functions)
        for method_key, method_data in self.method_data.items():
            if matches_query(method_key):
                results.append({
                    'type': 'method' if '::' in method_key else 'function',
                    'name': method_key,
                    'file': method_data['file'],
                    'details': {
                        'return_type': method_data['info'].get('return_type', 'void'),
                        'access': method_data['info'].get('access', 'public')
                    }
                })
        
        # Search in global functions from file data
        for file_path, file_data in self.file_data.items():
            for func in file_data.get('global_functions', []):
                if matches_query(func['name']):
                    results.append({
                        'type': 'function',
                        'name': func['name'],
                        'file': file_path,
                        'details': {
                            'return_type': func.get('return_type', 'void'),
                            'parameters': func.get('parameters', [])
                        }
                    })
        
        return results

def format_function(func: FunctionSignature) -> str:
    """Format a function signature for display."""
    access = f"{func.access} " if func.access != 'public' else ""
    virtual = "virtual " if func.is_virtual else ""
    static = "static " if func.is_static else ""
    const = " const" if func.is_const else ""
    params = ", ".join(func.parameters)
    return f"{access}{virtual}{static}{func.return_type} {func.name}({params}){const}"

def format_markdown(data: Dict) -> str:
    """Format analysis data as markdown."""
    lines = []
    
    def format_structure(structure: Dict, indent: int = 0) -> None:
        """Helper function to format file structure recursively."""
        prefix = "  " * indent
        if structure['type'] == 'dir':
            lines.append(f"{prefix}📁 {structure['name']}")
            if structure.get('children'):
                for child in structure['children']:
                    format_structure(child, indent + 1)
        else:
            lines.append(f"{prefix}📄 {structure['name']}")
    
    if 'structure' in data:
        if not data['structure']:
            lines.append("No structure data found")
        else:
            lines.append("# Project Structure\n")
            format_structure(data['structure'])
            lines.append("")
            
    elif 'results' in data:
        if not data['results']:
            lines.append("No matches found")
        else:
            lines.append("# Search Results\n")
            for result in data['results']:
                lines.append(f"## {result['type'].title()}: {result['name']}")
                lines.append(f"File: {result['file']}")
                if 'details' in result:
                    for key, value in result['details'].items():
                        lines.append(f"- {key}: {value}")
                lines.append("")
    
    elif 'class_info' in data:
        class_info = data['class_info']
        if not class_info:
            lines.append("Class not found")
        else:
            if class_info.get('base_classes'):
                bases = " : " + ", ".join(class_info['base_classes'])
            else:
                bases = ""
            lines.append(f"## class {class_info['name']}{bases}")
            lines.append("")
            
            if class_info.get('functions'):
                lines.append("### Methods")
                for func in class_info['functions']:
                    lines.append(f"- {format_function(FunctionSignature(**func))}")
                lines.append("")
            
    elif 'function_info' in data:
        func = data['function_info']
        if not func:
            lines.append("Function not found")
        else:
            lines.append("## Function")
            lines.append(f"```cpp\n{format_function(FunctionSignature(**func))}\n```")
    
    elif 'implementation' in data:
        if data['implementation']:
            lines.append("## Implementation")
            lines.append(data['implementation']['formatted'])
        else:
            lines.append("Implementation not found")
            
    return "\n".join(lines)

def main():
    """Main entry point for the script."""
    import argparse
    
    # Set logging to DEBUG level for more detailed output
    logger.setLevel(logging.DEBUG)
    
    parser = argparse.ArgumentParser(description='Start MCP server for C++ analysis')
    parser.add_argument('analysis_dir', help='Directory containing preprocessed analysis files')
    parser.add_argument('package_dir', help='Directory containing package analysis files')
    parser.add_argument('project_root', help='Root directory of the C++ project')    
    args = parser.parse_args()
    
    logger.info(f"Starting server with:")
    logger.info(f"  Analysis dir: {args.analysis_dir}")
    logger.info(f"  Package dir: {args.package_dir}")
    logger.info(f"  Project root: {args.project_root}")

    analyzer = PreprocessedAnalyzer(args.analysis_dir, args.package_dir, args.project_root)
    app = Server("wcsaga-cpp-analysis")
    logger.info("MCP server initialized")

    @app.list_tools()
    async def handle_list_tools() -> list[types.Tool]:
        return [
            types.Tool(
                name="get_project_structure",
                description="Get the project file structure",
                inputSchema={
                    "type": "object",
                    "properties": {},
                },
            ),
            types.Tool(
                name="get_folder_files",
                description="Get files in a folder",
                inputSchema={
                    "type": "object",
                    "required": ["folder"],
                    "properties": {
                        "folder": {
                            "type": "string",
                            "description": "Folder path",
                        }
                    },
                },
            ),
            types.Tool(
                name="get_file_info",
                description="Get analysis information for a file",
                inputSchema={
                    "type": "object",
                    "required": ["file_path"],
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "File path",
                        }
                    },
                },
            ),
            types.Tool(
                name="get_class_info",
                description="Get information about a class",
                inputSchema={
                    "type": "object",
                    "required": ["file_path", "class_name"],
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "File path",
                        },
                        "class_name": {
                            "type": "string",
                            "description": "Class name",
                        }
                    },
                },
            ),
            types.Tool(
                name="get_function_info",
                description="Get information about a function",
                inputSchema={
                    "type": "object",
                    "required": ["file_path", "class_name", "function_name"],
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "File path",
                        },
                        "class_name": {
                            "type": "string",
                            "description": "Class name",
                        },
                        "function_name": {
                            "type": "string",
                            "description": "Function name",
                        }
                    },
                },
            ),
            types.Tool(
                name="search_symbol",
                description="Search for symbols",
                inputSchema={
                    "type": "object",
                    "required": ["query"],
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "Search query",
                        }
                    },
                },
            ),
            types.Tool(
                name="get_method_implementation",
                description="Get the C++ implementation code of a method",
                inputSchema={
                    "type": "object",
                    "required": ["file_path", "class_name", "method_name"],
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "File path",
                        },
                        "class_name": {
                            "type": "string",
                            "description": "Class name",
                        },
                        "method_name": {
                            "type": "string",
                            "description": "Method name",
                        }
                    },
                },
            ),
            types.Tool(
                name="get_package_info",
                description="Get analysis information for a package",
                inputSchema={
                    "type": "object",
                    "required": ["package_path"],
                    "properties": {
                        "package_path": {
                            "type": "string",
                            "description": "Package path (folder)",
                        },
                        "force": {
                            "type": "boolean",
                            "description": "Force reanalysis",
                            "default": False
                        }
                    },
                },
            ),
            types.Tool(
                name="analyze_package",
                description="Analyze a C++ package and generate structured documentation",
                inputSchema={
                    "type": "object",
                    "required": ["package_path"],
                    "properties": {
                        "package_path": {
                            "type": "string",
                            "description": "Package path (folder)",
                        },
                        "force": {
                            "type": "boolean",
                            "description": "Force reanalysis",
                            "default": False
                        }
                    },
                },
            ),
        ]

    @app.call_tool()
    async def handle_call_tool(
        name: str, arguments: dict
    ) -> list[types.TextContent | types.ImageContent | types.EmbeddedResource]:
        logger.info(f"Tool call received: {name}")
        logger.debug(f"Arguments: {arguments}")
        try:
            response_data = None
            
            if name == 'get_project_structure':
                structure = analyzer.load_structure()
                response_data = {'structure': asdict(structure) if structure else None}
                
            elif name == 'get_folder_files':
                folder_data = analyzer.load_folder_analysis(arguments['folder'])
                response_data = {'files': [f['path'] for f in folder_data['files']] if folder_data else []}
                
            elif name == 'get_file_info':
                file_info = analyzer.get_file_info(arguments['file_path'])
                response_data = {'file_info': asdict(file_info) if file_info else None}
                
            elif name == 'get_class_info':
                file_info = analyzer.get_file_info(arguments['file_path'])
                if file_info:
                    for class_info in file_info.classes:
                        if class_info.name == arguments['class_name']:
                            response_data = {'class_info': asdict(class_info)}
                            break
                if not response_data:
                    response_data = {'class_info': None}
                
            elif name == 'get_function_info':
                file_info = analyzer.get_file_info(arguments['file_path'])
                if file_info:
                    for class_info in file_info.classes:
                        if class_info.name == arguments['class_name']:
                            for func in class_info.functions:
                                if func.name == arguments['function_name']:
                                    response_data = {
                                        'function_info': asdict(func),
                                        'formatted': format_function(func)
                                    }
                                    break
                if not response_data:
                    response_data = {'function_info': None}
                
            elif name == 'search_symbol':
                results = analyzer.search_symbol(arguments['query'])
                response_data = {'results': results}
                
            elif name == 'get_method_implementation':
                implementation = analyzer.get_method_implementation(
                    arguments['file_path'],
                    arguments['class_name'],
                    arguments['method_name']
                )
                if implementation:
                    response_data = {
                        'implementation': {
                            'code': implementation,
                            'formatted': f"```cpp\n{implementation}\n```"
                        }
                    }
                else:
                    response_data = {'implementation': None}
                
            elif name == 'get_package_info':
                package_info = analyzer.package_data.get(arguments['package_path'])
                if package_info:
                    response_data = {'package_info': package_info}
                else:
                    response_data = {'package_info': None}
                    
            elif name == 'analyze_package':
                package_info = analyzer.package_data.get(arguments['package_path'])
                if package_info:
                    # Format package info as markdown
                    lines = []
                    lines.append(f"# Package: {package_info['name']}\n")
                    
                    # Files
                    if package_info.get('direct_files'):
                        lines.append("## Direct Files")
                        for file in package_info['direct_files']:
                            lines.append(f"- {file}")
                        lines.append("")
                        
                    if package_info.get('direct_folders'):
                        lines.append("## Subfolders")
                        for folder in package_info['direct_folders']:
                            lines.append(f"- {folder}")
                        lines.append("")
                    
                    # Purpose
                    if package_info.get('purpose'):
                        lines.append("## Purpose")
                        lines.append(package_info['purpose'])
                        lines.append("")
                    
                    # Interface
                    lines.append("## Main Interface")
                    interface = package_info.get('interface', {})
                    
                    if interface.get('classes'):
                        lines.append("\n### Key Classes")
                        for cls in interface['classes']:
                            lines.append(f"- **{cls['name']}**")
                            if 'description' in cls:
                                lines.append(f"  - {cls['description']}")
                            if 'methods' in cls:
                                lines.append("  - Methods:")
                                for method in cls['methods']:
                                    lines.append(f"    - {method}")
                    
                    if interface.get('functions'):
                        lines.append("\n### Key Functions")
                        for func in interface['functions']:
                            lines.append(f"- **{func['name']}**")
                            if 'description' in func:
                                lines.append(f"  - {func['description']}")
                    
                    # Dependencies
                    if package_info.get('dependencies'):
                        lines.append("\n## Dependencies")
                        for dep in package_info['dependencies']:
                            lines.append(f"- {dep}")
                    
                    response_data = {'analysis': '\n'.join(lines)}
                else:
                    response_data = {'analysis': 'Package not found'}
            else:
                raise ValueError(f"Unknown tool: {name}")

            # Format response as markdown
            formatted_response = format_markdown(response_data)
            logger.debug(f"Formatted response: {formatted_response}")
            return [types.TextContent(type="text", text=formatted_response)]
                
        except Exception as e:
            logger.error(f"Error handling {name}: {str(e)}", exc_info=True)
            return [types.TextContent(type="text", text=str(e))]

    async def run():
        from mcp.server.stdio import stdio_server
        async with stdio_server() as (read_stream, write_stream):
            await app.run(
                read_stream,
                write_stream,
                InitializationOptions(
                    server_name="wcsaga-cpp-analysis",
                    server_version="0.1.0",
                    capabilities=app.get_capabilities(
                        notification_options=NotificationOptions(),
                        experimental_capabilities={},
                    ),
                ),
            )

    anyio.run(run)

if __name__ == '__main__':
    main()
