#!/usr/bin/env python3
"""
Tool for analyzing C++ packages and storing results in structured JSON format.
Creates analysis files per package with information about files, purpose,
and main interface functions.
Uses Claude AI to generate summaries of package purpose and interface.
"""

import json
import logging
import time
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
import litellm

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

# Configure LLM logging
llm_logger = logging.getLogger("llm_calls")
llm_logger.setLevel(logging.INFO)
# Create a file handler
llm_handler = logging.FileHandler('llm_calls.log')
llm_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
llm_logger.addHandler(llm_handler)

@dataclass
class PackageInterface:
    """Represents the main interface of a package."""
    functions: List[Dict]  # Key functions that form the package's API
    classes: List[Dict]    # Key classes that form the package's API

@dataclass
class PackageAnalysis:
    """Represents the analysis results for a package."""
    name: str             # Package name (folder name)
    path: str             # Relative path to package
    files: List[str]      # List of all files in package (recursive)
    direct_files: List[str]  # List of files directly in this package (not in subfolders)
    direct_folders: List[str]  # List of immediate child folders
    purpose: str          # Inferred purpose of the package
    interface: PackageInterface  # Main interface elements
    dependencies: List[str]  # Other packages this package depends on

class PackageAnalyzer:
    """Analyzes C++ packages and generates structured analysis results."""

    def __init__(self, analysis_dir: str, output_dir: str):
        """Initialize the analyzer.
        
        Args:
            analysis_dir: Directory containing analysis JSON files
            output_dir: Directory to store package analysis results
        """
        self.analysis_dir = Path(analysis_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Build file structure from JSON files
        self.file_structure = self._build_file_structure()

    def _build_file_structure(self) -> Dict:
        """Build file structure from JSON analysis files.
        
        Returns:
            Dict representing the file structure
        """
        structure = {
            'type': 'dir',
            'name': '',
            'children': []
        }
        
        # Get all JSON files in analysis directory
        json_files = list(self.analysis_dir.rglob('*.json'))
        
        for json_path in json_files:
            try:
                with open(json_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    
                # Skip empty files
                if not data.get('files'):
                    continue
                    
                # Get folder path relative to analysis dir
                rel_path = json_path.relative_to(self.analysis_dir).with_suffix('')
                path_parts = list(rel_path.parts)
                
                # Add folder to structure
                current = structure
                for part in path_parts:
                    # Find or create child node
                    child = next((c for c in current['children'] if c['name'] == part), None)
                    if not child:
                        child = {
                            'type': 'dir',
                            'name': part,
                            'children': []
                        }
                        current['children'].append(child)
                    current = child
                    
                # Add files from JSON data
                for file_info in data['files']:
                    file_path = Path(file_info['path'])
                    current['children'].append({
                        'type': 'file',
                        'name': file_path.name,
                        'path': str(file_path)
                    })
                    
            except Exception as e:
                logger.error(f"Error processing {json_path}: {e}")
                
        return structure

    def _find_package_node(self, package_path: str) -> Optional[Dict]:
        """Find a package node in the file structure.
        
        Args:
            package_path: Path to the package (e.g. 'wcsaga/zlib/win32')
            
        Returns:
            Dict representing the package node if found, None otherwise
        """
        def find_node(node: Dict, target_path: List[str]) -> Optional[Dict]:
            if not target_path:
                return node
            current = target_path[0]
            if node['type'] == 'dir' and 'children' in node:
                for child in node['children']:
                    if child['name'] == current:
                        result = find_node(child, target_path[1:])
                        if result:
                            return result
            return None
        
        package_parts = package_path.split('/')
        return find_node(self.file_structure, package_parts)

    def _should_analyze_directory(self, package_path: str) -> bool:
        """Determine if a directory should be analyzed as a separate package.
        
        A directory should not be analyzed separately if it only contains one analysis JSON file.
        
        Args:
            package_path: Path to the package directory
            
        Returns:
            bool: True if directory should be analyzed separately, False otherwise
        """
        analysis_dir = self.analysis_dir / package_path
        if not analysis_dir.exists() or not analysis_dir.is_dir():
            return True
            
        json_files = list(analysis_dir.glob('*.json'))
        return len(json_files) != 1

    def _get_package_files(self, package_path: str, folder_data: Dict) -> List[str]:
        """Get all files in a package from the file structure.
        
        Args:
            package_path: Path to the package (e.g. 'wcsaga/zlib/win32')
            folder_data: Analysis data for the current folder
            
        Returns:
            List of file paths relative to the package
        """
        files = []
        
        def traverse_structure(node: Dict, current_path: str):
            """Recursively traverse the file structure collecting files."""
            if node['type'] == 'file':
                files.append(current_path + '/' + node['name'])
            elif node['type'] == 'dir' and 'children' in node:
                # Check if this directory should be treated as a separate package
                dir_path = (current_path + '/' + node['name']).lstrip('/')
                if not self._should_analyze_directory(dir_path):
                    # If directory has single JSON, include its files in parent
                    analysis_file = self.analysis_dir / Path(dir_path).with_suffix('.json')
                    if analysis_file.exists():
                        with open(analysis_file, 'r', encoding='utf-8') as f:
                            subdir_data = json.load(f)
                            # Merge the analysis data into the parent folder's data
                            folder_data['files'].extend(subdir_data.get('files', []))
                    
                    # Continue traversing this directory's children
                    for child in node['children']:
                        new_path = current_path + '/' + node['name'] if current_path else node['name']
                        traverse_structure(child, new_path)
                else:
                    # Skip this directory as it will be analyzed separately
                    return
        
        package_node = self._find_package_node(package_path)
        if package_node:
            traverse_structure(package_node, "")
            logger.debug(f"Found {len(files)} files in package {package_path}")
        else:
            logger.warning(f"Package node not found in file structure: {package_path}")
            
        return [f.lstrip('/') for f in files]

    def _get_child_packages(self, package_path: str) -> List[str]:
        """Get direct child packages of the given package.
        
        Args:
            package_path: Path to the parent package
            
        Returns:
            List of child package paths that should be analyzed separately
        """
        children = []
        package_node = self._find_package_node(package_path)
        
        # Get direct child directories that should be analyzed separately
        if package_node and package_node['type'] == 'dir' and 'children' in package_node:
            for child in package_node['children']:
                if child['type'] == 'dir':
                    child_path = f"{package_path}/{child['name']}"
                    # Only include directories that should be analyzed separately
                    if self._should_analyze_directory(child_path):
                        children.append(child_path)
        
        return children

    def _format_folder_data_as_markdown(self, folder_data: Dict, child_analyses: List[PackageAnalysis] = None) -> str:
        """Format folder analysis data as markdown for LLM input.
        
        Args:
            folder_data: Analysis data for the current folder
            child_analyses: Optional list of PackageAnalysis objects for child packages
        """
        lines = ["# Package Analysis\n"]
        
        # Add child package information if available
        if child_analyses:
            lines.append("## Child Packages\n")
            for child in child_analyses:
                lines.append(f"### {child.name}\n")
                lines.append(f"Purpose: {child.purpose}\n")
                if child.interface.classes:
                    lines.append("Key Classes:")
                    for cls in child.interface.classes:
                        lines.append(f"- {cls['name']}: {cls.get('description', 'No description')}")
                if child.interface.functions:
                    lines.append("Key Functions:")
                    for func in child.interface.functions:
                        lines.append(f"- {func['name']}: {func.get('description', 'No description')}")
                lines.append("")
        
        # Add current package files
        lines.append("## Files\n")
        for file_data in folder_data['files']:
            lines.append(f"### {file_data['path']}\n")
            
            # Add classes
            if file_data['classes']:
                lines.append("#### Classes\n")
                for class_info in file_data['classes']:
                    lines.append(f"- **{class_info['name']}**")
                    if class_info['base_classes']:
                        lines.append(f"  - Inherits from: {', '.join(class_info['base_classes'])}")
                    if class_info['functions']:
                        lines.append("  - Methods:")
                        for func in class_info['functions']:
                            access = f"{func['access']} " if func['access'] != 'public' else ""
                            virtual = "virtual " if func['is_virtual'] else ""
                            static = "static " if func['is_static'] else ""
                            const = " const" if func['is_const'] else ""
                            params = ", ".join(func['parameters'])
                            lines.append(f"    - {access}{virtual}{static}{func['return_type']} {func['name']}({params}){const}")
                lines.append("")
            
            # Add global functions
            if file_data['global_functions']:
                lines.append("#### Global Functions\n")
                for func in file_data['global_functions']:
                    params = ", ".join(func['parameters'])
                    lines.append(f"- {func['return_type']} {func['name']}({params})")
                lines.append("")
        
        return "\n".join(lines)

    def _make_llm_call(self, messages: List[Dict], temp: float, max_tokens: int, json_format: bool = False) -> litellm.ModelResponse:
        """Make an LLM API call with retry logic for rate limits and overloads.
        
        Args:
            messages: List of message dictionaries for the conversation
            temp: Temperature parameter for response randomness
            max_tokens: Maximum tokens in the response
            json_format: Whether to request JSON formatted response
            
        Returns:
            LiteLLM response object
            
        Raises:
            Exception: If the API call fails for reasons other than rate limits
        """
        while True:
            try:
                response = litellm.completion(
                    model="anthropic/claude-3-5-haiku-20241022",
                    messages=messages,
                    temperature=temp,
                    max_tokens=max_tokens,
                    response_format={"type": "json_object"} if json_format else None
                )
                return response
            except litellm.RateLimitError:
                llm_logger.warning("Rate limit reached, sleeping for 60 seconds...")
                time.sleep(60)
            except litellm.ServiceUnavailableError:
                llm_logger.warning("Service overloaded, sleeping for 5 seconds...")
                time.sleep(5)

    def _analyze_with_llm(self, folder_data: Dict, child_analyses: List[PackageAnalysis] = None) -> tuple[str, PackageInterface]:
        """Use Claude to analyze package purpose and interface.
        
        Args:
            folder_data: Analysis data for the current folder
            child_analyses: Optional list of PackageAnalysis objects for child packages
        """
        # Format data as markdown including child package information
        markdown_content = self._format_folder_data_as_markdown(folder_data, child_analyses)
        
        try:
            # Get package purpose
            purpose_prompt = [
                {"role": "system", "content": "You are an expert C++ code analyzer and you worked on 3D space fighter computer games in the past using the boost c++ library.  Your task is to analyze C++ package contents and determine its primary purpose. The code is a part of the Wing Commander Saga codebase. The package may contain classes, functions, and other elements that provide specific functionality to the game or low level helper functions to implement the graphics engine, input handling etc."},  
                {"role": "user", "content": f"Based on the following package contents and its child packages, determine its primary purpose in 1-2 sentences. Focus on what functionality this package provides and how it relates to its child packages. Note that we want to migrate the code to Godot at the end, so explicitly note if the code has an equivalent in Godot standard features (e.g. read media files, render 3d graphics, play audio, user input, math utils):\n\n{markdown_content}"}
            ]
            
            llm_logger.info(f"Requesting package purpose analysis for {folder_data.get('folder', 'unknown folder')}")
            llm_logger.debug(f"Purpose prompt: {purpose_prompt}")
            
            # Get package purpose
            purpose_response = self._make_llm_call(purpose_prompt, 0.1, 4*1024)
            purpose = purpose_response.choices[0].message.content
            llm_logger.info(f"Successfully received purpose analysis: {purpose[:100]}...")
            
            # Get main interface elements
            interface_prompt = [
                {"role": "system", "content": "You are an expert C++ code analyzer and you worked on 3D space fighter computer games in the past using the boost c++ library. Your task is to identify the main interface elements (key classes and functions) that form the public API of a package. The code is a part of the Wing Commander Saga codebase. The package may contain classes, functions, and other elements that provide specific functionality to the game or low level helper functions to implement the graphics engine, input handling etc."},
                {"role": "user", "content": f"Based on the following package contents and its child packages, identify the main interface elements (key classes and functions) that other code would use to interact with this package. Consider how the package's interface relates to and integrates with its child packages. We know the purpose of the package is in general:\n{purpose}\n\nReturn the response as a JSON object with 'classes' and 'functions' arrays containing the names and brief descriptions of key elements:\n\n{markdown_content}"}
            ]
            
            llm_logger.info(f"Requesting interface analysis for {folder_data.get('folder', 'unknown folder')}")
            llm_logger.debug(f"Interface prompt: {interface_prompt}")
            interface_response = self._make_llm_call(interface_prompt, 0.2, 4*1024, json_format=True)
            interface_data = json.loads(interface_response.choices[0].message.content)
            interface = PackageInterface(
                classes=interface_data.get('classes', []),
                functions=interface_data.get('functions', [])
            )
            llm_logger.info(f"Successfully received interface analysis with {len(interface_data.get('classes', []))} classes and {len(interface_data.get('functions', []))} functions")
            
            return purpose, interface
            
        except Exception as e:
            llm_logger.error(f"Error during LLM analysis: {str(e)}")
            raise

    def _find_dependencies(self, folder_data: Dict) -> List[str]:
        """Find package dependencies based on includes."""
        dependencies = set()
        
        for file_data in folder_data['files']:
            if 'includes' in file_data:
                for include in file_data['includes']:
                    if not include['is_system']:
                        # Extract package name from include path
                        include_parts = Path(include['path']).parts
                        if include_parts:
                            dependencies.add(include_parts[0])
        
        return sorted(list(dependencies))

    def analyze_package(self, package_path: str, force: bool = False, analyzed_packages: Dict[str, PackageAnalysis] = None) -> Optional[PackageAnalysis]:
        """Analyze a package and store results.
        
        Args:
            package_path: Path to the package (folder)
            force: Force reanalysis even if results exist
            analyzed_packages: Dict of already analyzed packages (path -> PackageAnalysis)
        
        Returns:
            PackageAnalysis object if successful, None otherwise
        """
        # Skip empty or invalid paths
        if not package_path or package_path == '.':
            logger.debug("Skipping empty package path")
            return None
            
        # Check if this directory should be analyzed
        if not self._should_analyze_directory(package_path):
            logger.info(f"Skipping {package_path} as it only contains one analysis file")
            return None
            
        try:
            # Use package path structure for output file
            output_file = self.output_dir / Path(package_path).with_suffix('.json')
            # Ensure parent directories exist
            output_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Check if analysis exists
            if not force and output_file.exists():
                try:
                    with open(output_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        logger.info(f"Analysis exists for {package_path}, skipping")
                        return PackageAnalysis(**data)
                except Exception as e:
                    logger.warning(f"Failed to load existing analysis for {package_path}: {e}")
                    # Continue with reanalysis
            
            logger.info(f"Analyzing package: {package_path}")
            
            # Load folder analysis using the same path structure
            folder_data = None
            
            # Use the package path directly for analysis file
            analysis_file = self.analysis_dir / Path(package_path).with_suffix('.json')
            if analysis_file.exists():
                try:
                    with open(analysis_file, 'r', encoding='utf-8') as f:
                        folder_data = json.load(f)
                except Exception as e:
                    logger.warning(f"Failed to load analysis data for {package_path}: {e}")
            
            if not folder_data:
                logger.info(f"No analysis data found for {package_path} (tried {analysis_file})")
                return None
            
            # Get all files recursively and merge analysis data
            files = self._get_package_files(package_path, folder_data)
            
            # Get direct children (files and folders)
            package_node = self._find_package_node(package_path)
            direct_files = []
            direct_folders = []
            
            if not package_node:
                logger.error(f"Package node not found: {package_path}")
                return None
                
            if package_node['type'] != 'dir':
                logger.error(f"Package node {package_path} is not a directory")
                return None
                
            if 'children' in package_node:
                for child in package_node['children']:
                    if child['type'] == 'file':
                        direct_files.append(child['name'])
                    elif child['type'] == 'dir':
                        child_path = f"{package_path}/{child['name']}"
                        # Only include directories that should be analyzed separately
                        if self._should_analyze_directory(child_path):
                            direct_folders.append(child['name'])
            else:
                logger.debug(f"Package node {package_path} has no children")
                # Initialize empty lists to avoid TypeError
                direct_files = []
                direct_folders = []
            
            # Sort for consistent output
            direct_files.sort()
            direct_folders.sort()
            
            logger.debug(f"Found {len(direct_files)} direct files and {len(direct_folders)} direct folders in {package_path}")
            
            # Get child package analyses
            child_packages = self._get_child_packages(package_path)
            child_analyses = []
            if analyzed_packages:
                for child in child_packages:
                    if child in analyzed_packages:
                        child_analyses.append(analyzed_packages[child])
            
            # Use LLM to analyze purpose and interface with child package context
            try:
                llm_logger.info(f"Starting LLM analysis for package: {package_path}")
                purpose, interface = self._analyze_with_llm(folder_data, child_analyses)
                llm_logger.info(f"Completed LLM analysis for package: {package_path}")
            except Exception as e:
                llm_logger.error(f"LLM analysis failed for package {package_path}: {str(e)}")
                raise
            
            # Find dependencies
            dependencies = self._find_dependencies(folder_data)
            
            # Create package analysis
            analysis = PackageAnalysis(
                name=Path(package_path).name,
                path=package_path,
                files=files,
                direct_files=direct_files,
                direct_folders=direct_folders,
                purpose=purpose,
                interface=interface,
                dependencies=dependencies
            )
            
            # Save results
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(asdict(analysis), f, indent=2)
            
            logger.info(f"Saved analysis for {package_path} to {output_file}")
            return analysis
            
        except Exception as e:
            logger.error(f"Error analyzing package {package_path}: {e}")
            return None

def main():
    """Main entry point for the script."""
    import argparse
    parser = argparse.ArgumentParser(
        description='Analyze C++ packages and generate structured analysis'
    )
    parser.add_argument('analysis_dir',
                       help='Directory containing analysis JSON files')
    parser.add_argument('--output-dir', '-o', default='package_analysis_results',
                       help='Output directory for package analysis files')
    parser.add_argument('--force', '-f', action='store_true',
                       help='Force reanalysis of all packages')
    args = parser.parse_args()

    analyzer = PackageAnalyzer(args.analysis_dir, args.output_dir)
    
    # Get all package folders from file structure
    def get_packages(node: Dict, current_path: str = "") -> List[str]:
        packages = []
        if node['type'] == 'dir' and 'boost' not in node['name']:
            path = current_path + '/' + node['name'] if current_path else node['name']
            # Check if this directory should be analyzed
            if analyzer._should_analyze_directory(path):
                packages.append(path)
                if 'children' in node:
                    for child in node['children']:
                        packages.extend(get_packages(child, path))
        return packages
    
    packages = get_packages(analyzer.file_structure)
    
    # Sort packages by depth (descending) to process deeper packages first
    packages.sort(key=lambda x: x.count('/'), reverse=True)
    
    # Keep track of analyzed packages to provide context
    analyzed_packages = {}
    
    logger.info("Processing packages in bottom-up order:")
    for package in packages:
        logger.info(f"  {package}")
        analysis = analyzer.analyze_package(package, args.force, analyzed_packages)
        if analysis:
            analyzed_packages[package] = analysis

if __name__ == '__main__':
    main()
