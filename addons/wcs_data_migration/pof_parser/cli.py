#!/usr/bin/env python3
"""
POF Parser CLI - EPIC-003 DM-004 & DM-005 Implementation

Command-line interface for POF format analysis, parsing, data extraction,
and mesh conversion to Godot GLB format.
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import List, Optional

from .pof_data_extractor import POFDataExtractor
from .pof_format_analyzer import POFFormatAnalyzer
from .pof_mesh_converter import POFMeshConverter
from .pof_parser import POFParser

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def analyze_pof_format(file_path: Path, output_file: Optional[Path] = None) -> bool:
    """
    Analyze POF file format and optionally save results.
    
    Args:
        file_path: Path to POF file
        output_file: Optional output file for analysis results
        
    Returns:
        True if analysis succeeded, False otherwise
    """
    analyzer = POFFormatAnalyzer()
    
    try:
        analysis = analyzer.analyze_format(file_path)
        
        # Print summary
        print(f"\n=== POF Format Analysis: {file_path.name} ===")
        print(f"File Size: {analysis.file_size:,} bytes")
        print(f"POF Version: {analysis.version}")
        print(f"Valid Header: {analysis.valid_header}")
        print(f"Compatible Version: {analysis.compatible_version}")
        print(f"Total Chunks: {analysis.total_chunks}")
        
        if analysis.chunk_count_by_type:
            print(f"\nChunk Types:")
            for chunk_type, count in sorted(analysis.chunk_count_by_type.items()):
                print(f"  {chunk_type}: {count}")
        
        if analysis.warnings:
            print(f"\nWarnings:")
            for warning in analysis.warnings:
                print(f"  - {warning}")
        
        if analysis.parsing_errors:
            print(f"\nErrors:")
            for error in analysis.parsing_errors:
                print(f"  - {error}")
        
        # Validate format compliance
        compliance_issues = analyzer.validate_format_compliance(analysis)
        if compliance_issues:
            print(f"\nFormat Compliance Issues:")
            for issue in compliance_issues:
                print(f"  - {issue}")
        else:
            print(f"\nFormat Compliance: ✓ PASSED")
        
        # Save detailed analysis if requested
        if output_file:
            analysis_data = analysis.to_dict()
            with open(output_file, 'w') as f:
                json.dump(analysis_data, f, indent=2)
            print(f"\nDetailed analysis saved to: {output_file}")
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to analyze POF file {file_path}: {e}")
        return False

def extract_pof_data(file_path: Path, output_file: Optional[Path] = None, 
                    godot_format: bool = False) -> bool:
    """
    Extract POF data for conversion.
    
    Args:
        file_path: Path to POF file
        output_file: Optional output file for extracted data
        godot_format: Extract in Godot-optimized format
        
    Returns:
        True if extraction succeeded, False otherwise
    """
    extractor = POFDataExtractor()
    
    try:
        if godot_format:
            data = extractor.extract_for_godot_conversion(file_path)
        else:
            model_data = extractor.extract_model_data(file_path)
            data = model_data.to_dict() if model_data else None
        
        if not data:
            print(f"Failed to extract data from {file_path}")
            return False
        
        # Print summary
        print(f"\n=== POF Data Extraction: {file_path.name} ===")
        
        if godot_format:
            metadata = data.get('metadata', {})
            print(f"Source File: {metadata.get('source_file', 'Unknown')}")
            print(f"POF Version: {metadata.get('pof_version', 'Unknown')}")
            print(f"Max Radius: {metadata.get('max_radius', 0.0):.2f}")
            print(f"Mass: {metadata.get('mass', 0.0):.2f}")
            
            scene_tree = data.get('scene_tree', {})
            if 'root' in scene_tree:
                root = scene_tree['root']
                child_count = len(root.get('children', []))
                print(f"Root Node: {root.get('name', 'Unknown')} ({child_count} children)")
            
            materials = data.get('materials', [])
            print(f"Materials: {len(materials)}")
            
            gameplay = data.get('gameplay_nodes', {})
            weapon_count = len(gameplay.get('weapon_hardpoints', []))
            dock_count = len(gameplay.get('docking_bays', []))
            engine_count = len(gameplay.get('engine_points', []))
            print(f"Gameplay Elements: {weapon_count} weapons, {dock_count} docks, {engine_count} engines")
        else:
            print(f"Filename: {data.get('filename', 'Unknown')}")
            print(f"Version: {data.get('version', 'Unknown')}")
            print(f"Max Radius: {data.get('max_radius', 0.0):.2f}")
            print(f"Subobjects: {len(data.get('subobjects', {}))}")
            print(f"Textures: {len(data.get('textures', []))}")
            print(f"Weapon Points: {len(data.get('weapon_points', []))}")
            print(f"Docking Points: {len(data.get('docking_points', []))}")
            print(f"Thrusters: {len(data.get('thrusters', []))}")
        
        # Save extracted data if requested
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(data, f, indent=2)
            print(f"\nExtracted data saved to: {output_file}")
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to extract data from POF file {file_path}: {e}")
        return False

def parse_pof_file(file_path: Path, output_file: Optional[Path] = None) -> bool:
    """
    Parse POF file and output raw parsed data.
    
    Args:
        file_path: Path to POF file
        output_file: Optional output file for parsed data
        
    Returns:
        True if parsing succeeded, False otherwise
    """
    parser = POFParser()
    
    try:
        parsed_data = parser.parse(file_path)
        
        if not parsed_data:
            print(f"Failed to parse {file_path}")
            return False
        
        # Print summary
        print(f"\n=== POF Parsing Results: {file_path.name} ===")
        print(f"Filename: {parsed_data.get('filename', 'Unknown')}")
        print(f"Version: {parsed_data.get('version', 'Unknown')}")
        
        header = parsed_data.get('header', {})
        print(f"Max Radius: {header.get('max_radius', 0.0):.2f}")
        print(f"Subobjects: {header.get('num_subobjects', 0)}")
        
        print(f"Parsed Chunks:")
        print(f"  Textures: {len(parsed_data.get('textures', []))}")
        print(f"  Objects: {len(parsed_data.get('objects', []))}")
        print(f"  Special Points: {len(parsed_data.get('special_points', []))}")
        print(f"  Paths: {len(parsed_data.get('paths', []))}")
        print(f"  Gun Points: {len(parsed_data.get('gun_points', []))}")
        print(f"  Missile Points: {len(parsed_data.get('missile_points', []))}")
        print(f"  Docking Points: {len(parsed_data.get('docking_points', []))}")
        print(f"  Thrusters: {len(parsed_data.get('thrusters', []))}")
        print(f"  Eye Points: {len(parsed_data.get('eye_points', []))}")
        print(f"  Insignia: {len(parsed_data.get('insignia', []))}")
        print(f"  Glow Banks: {len(parsed_data.get('glow_banks', []))}")
        
        # Save parsed data if requested
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(parsed_data, f, indent=2, default=str)
            print(f"\nParsed data saved to: {output_file}")
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to parse POF file {file_path}: {e}")
        return False

def process_directory(directory: Path, operation: str, output_dir: Optional[Path] = None,
                     godot_format: bool = False, textures_dir: Optional[Path] = None,
                     model_type: str = 'ship', blender_path: Optional[Path] = None,
                     keep_temp: bool = False) -> None:
    """
    Process all POF files in a directory.
    
    Args:
        directory: Directory containing POF files
        operation: Operation to perform ('analyze', 'extract', 'parse')
        output_dir: Optional output directory for results
        godot_format: Use Godot-optimized format for extraction
    """
    pof_files = list(directory.glob('*.pof')) + list(directory.glob('*.POF'))
    
    if not pof_files:
        print(f"No POF files found in {directory}")
        return
    
    print(f"Found {len(pof_files)} POF files in {directory}")
    
    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)
    
    success_count = 0
    
    for pof_file in pof_files:
        print(f"\nProcessing: {pof_file.name}")
        
        output_file = None
        if output_dir:
            output_name = f"{pof_file.stem}_{operation}.json"
            output_file = output_dir / output_name
        
        try:
            if operation == 'analyze':
                success = analyze_pof_format(pof_file, output_file)
            elif operation == 'extract':
                success = extract_pof_data(pof_file, output_file, godot_format)
            elif operation == 'parse':
                success = parse_pof_file(pof_file, output_file)
            elif operation == 'convert':
                if output_dir:
                    output_file = output_dir / pof_file.with_suffix('.glb').name
                success = convert_pof_to_glb(pof_file, output_file, textures_dir, 
                                           model_type, blender_path, keep_temp)
            else:
                print(f"Unknown operation: {operation}")
                continue
            
            if success:
                success_count += 1
                print(f"✓ {operation.capitalize()} completed successfully")
            else:
                print(f"✗ {operation.capitalize()} failed")
                
        except KeyboardInterrupt:
            print(f"\nOperation cancelled by user")
            break
        except Exception as e:
            logger.error(f"Error processing {pof_file}: {e}")
            print(f"✗ Error processing file: {e}")
    
    print(f"\n=== Summary ===")
    print(f"Processed: {success_count}/{len(pof_files)} files successfully")

def convert_pof_to_glb(file_path: Path, output_file: Optional[Path] = None,
                      textures_dir: Optional[Path] = None, model_type: str = 'ship',
                      blender_path: Optional[Path] = None, keep_temp: bool = False) -> bool:
    """
    Convert POF file to Godot GLB format.
    
    Args:
        file_path: Path to POF file
        output_file: Path to output GLB file (auto-generated if None)
        textures_dir: Directory containing texture files
        model_type: Type of model for optimization
        blender_path: Path to Blender executable
        keep_temp: Keep temporary files after conversion
        
    Returns:
        True if conversion successful, False otherwise
    """
    try:
        print(f"Converting POF to GLB: {file_path}")
        
        # Generate output path if not provided
        if not output_file:
            output_file = file_path.with_suffix('.glb')
        
        # Initialize converter
        converter = POFMeshConverter(
            blender_executable=blender_path,
            cleanup_temp=not keep_temp
        )
        
        # Perform conversion
        report = converter.convert_pof_to_glb(
            file_path, output_file, textures_dir, model_type
        )
        
        if report.success:
            print(f"✓ Conversion successful: {output_file}")
            print(f"  Time: {report.conversion_time:.2f}s")
            print(f"  Vertices: {report.obj_vertices:,}")
            print(f"  Faces: {report.obj_faces:,}")
            print(f"  Materials: {report.obj_materials}")
            print(f"  GLB Size: {report.glb_file_size:,} bytes")
            return True
        else:
            print(f"✗ Conversion failed")
            for error in report.errors:
                print(f"  Error: {error}")
            return False
        
    except Exception as e:
        logger.error(f"Failed to convert POF file {file_path}: {e}")
        return False

def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description='POF (Parallax Object Format) Parser and Analyzer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Analyze POF format
  python -m pof_parser.cli analyze ship.pof
  
  # Extract data for Godot conversion
  python -m pof_parser.cli extract ship.pof --godot-format
  
  # Parse POF file and save raw data
  python -m pof_parser.cli parse ship.pof --output ship_parsed.json
  
  # Convert POF to Godot GLB format
  python -m pof_parser.cli convert ship.pof --output ship.glb --textures textures/
  
  # Process all POF files in directory
  python -m pof_parser.cli analyze models/ --output-dir analysis_results/
  
  # Batch convert POF models to GLB
  python -m pof_parser.cli convert models/ --output-dir glb_models/ --textures textures/
        """
    )
    
    parser.add_argument(
        'operation', 
        choices=['analyze', 'extract', 'parse', 'convert'],
        help='Operation to perform'
    )
    
    parser.add_argument(
        'input',
        type=Path,
        help='POF file or directory to process'
    )
    
    parser.add_argument(
        '--output', '-o',
        type=Path,
        help='Output file for results (for single file operations)'
    )
    
    parser.add_argument(
        '--output-dir', '-d',
        type=Path,
        help='Output directory for results (for directory operations)'
    )
    
    parser.add_argument(
        '--godot-format',
        action='store_true',
        help='Extract data in Godot-optimized format (extract operation only)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose logging'
    )
    
    # Convert-specific arguments
    parser.add_argument(
        '--textures', '-t',
        type=Path,
        help='Directory containing texture files (for convert operation)'
    )
    
    parser.add_argument(
        '--model-type', '-m',
        choices=['ship', 'station', 'debris', 'custom'],
        default='ship',
        help='Model type for optimization (for convert operation, default: ship)'
    )
    
    parser.add_argument(
        '--blender',
        type=Path,
        help='Path to Blender executable (for convert operation, auto-detected if not specified)'
    )
    
    parser.add_argument(
        '--keep-temp',
        action='store_true',
        help='Keep temporary OBJ files after conversion (for convert operation)'
    )
    
    args = parser.parse_args()
    
    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Validate input
    if not args.input.exists():
        print(f"Error: Input path does not exist: {args.input}")
        sys.exit(1)
    
    try:
        if args.input.is_file():
            # Process single file
            if args.operation == 'analyze':
                success = analyze_pof_format(args.input, args.output)
            elif args.operation == 'extract':
                success = extract_pof_data(args.input, args.output, args.godot_format)
            elif args.operation == 'parse':
                success = parse_pof_file(args.input, args.output)
            elif args.operation == 'convert':
                success = convert_pof_to_glb(args.input, args.output, args.textures,
                                           args.model_type, args.blender, args.keep_temp)
            else:
                success = False
                print(f"Error: operation must one of 'analyze', 'extract', 'parse', 'convert', but was '{args.operation}'")
            
            sys.exit(0 if success else 1)
        
        elif args.input.is_dir():
            # Process directory
            process_directory(args.input, args.operation, args.output_dir, args.godot_format,
                            args.textures, args.model_type, args.blender, args.keep_temp)
            sys.exit(0)
        
        else:
            print(f"Error: Input must be a file or directory: {args.input}")
            sys.exit(1)
    
    except KeyboardInterrupt:
        print(f"\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()