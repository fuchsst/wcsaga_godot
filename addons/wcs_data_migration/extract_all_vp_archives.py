#!/usr/bin/env python3
"""
VP Archive Batch Extractor

Extracts all VP archive files from Wing Commander Saga installation
to organized directory structure for asset conversion.

Author: Dev (GDScript Developer)
Date: June 10, 2025
"""

import argparse
import logging
import sys
from pathlib import Path
from typing import List
from vp_extractor import VPIndex

logger = logging.getLogger(__name__)

class VPBatchExtractor:
    """Batch extractor for multiple VP archive files"""
    
    def __init__(self, source_dir: Path, output_dir: Path):
        """
        Initialize batch extractor.
        
        Args:
            source_dir: Directory containing VP archive files (WCS installation)
            output_dir: Output directory for extracted assets
        """
        # Convert to Path (don't resolve to avoid WSL path issues)
        self.source_dir = Path(source_dir)
        self.output_dir = Path(output_dir)
        
        # Validate source directory
        if not self.source_dir.exists():
            raise FileNotFoundError(f"Source directory not found: {self.source_dir}")
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.extraction_results = {
            'success': [],
            'failed': [],
            'skipped': []
        }
    
    def find_vp_files(self) -> List[Path]:
        """
        Find all VP archive files in the source directory.
        
        Returns:
            List of VP file paths
        """
        logger.info(f"Scanning for VP files in: {self.source_dir}")
        
        vp_files = []
        
        # Search for .vp files recursively
        for vp_file in self.source_dir.rglob("*.vp"):
            vp_files.append(vp_file)
        
        # Sort by name for consistent processing order
        vp_files.sort(key=lambda x: x.name.lower())
        
        logger.info(f"Found {len(vp_files)} VP archive files")
        return vp_files
    
    def extract_vp_file(self, vp_file: Path) -> bool:
        """
        Extract a single VP file.
        
        Args:
            vp_file: Path to VP archive file
            
        Returns:
            True if extraction successful, False otherwise
        """
        try:
            logger.info(f"Extracting VP archive: {vp_file.name}")
            
            # Create output subdirectory for this VP file
            vp_output_dir = self.output_dir / vp_file.stem
            
            # Check if already extracted (and skip if not forced)
            if vp_output_dir.exists() and any(vp_output_dir.iterdir()):
                logger.info(f"VP archive already extracted, skipping: {vp_file.name}")
                self.extraction_results['skipped'].append(str(vp_file))
                return True
            
            # Extract using VPIndex
            with VPIndex() as vp:
                if not vp.parse(str(vp_file)):
                    logger.error(f"Failed to parse VP file: {vp_file}")
                    self.extraction_results['failed'].append(str(vp_file))
                    return False
                
                # Get file count for progress
                file_count = len(vp.list_files())
                logger.info(f"Extracting {file_count} files from {vp_file.name}")
                
                # Extract all files
                if vp.extract_all(str(self.output_dir)):
                    logger.info(f"Successfully extracted {vp_file.name}")
                    self.extraction_results['success'].append(str(vp_file))
                    return True
                else:
                    logger.error(f"Failed to extract files from: {vp_file}")
                    self.extraction_results['failed'].append(str(vp_file))
                    return False
                    
        except Exception as e:
            logger.error(f"Error extracting {vp_file}: {e}")
            self.extraction_results['failed'].append(str(vp_file))
            return False
    
    def extract_all_vp_files(self, force: bool = False) -> bool:
        """
        Extract all VP files found in the source directory.
        
        Args:
            force: If True, re-extract even if output directories exist
            
        Returns:
            True if all extractions successful, False if any failed
        """
        vp_files = self.find_vp_files()
        
        if not vp_files:
            logger.warning("No VP files found in source directory")
            return True
        
        logger.info(f"Starting batch extraction of {len(vp_files)} VP files")
        
        success_count = 0
        
        for i, vp_file in enumerate(vp_files, 1):
            logger.info(f"Processing {i}/{len(vp_files)}: {vp_file.name}")
            
            # Skip if already extracted and not forcing
            if not force:
                vp_output_dir = self.output_dir / vp_file.stem
                if vp_output_dir.exists() and any(vp_output_dir.iterdir()):
                    logger.info(f"Already extracted, skipping: {vp_file.name}")
                    self.extraction_results['skipped'].append(str(vp_file))
                    success_count += 1
                    continue
            
            if self.extract_vp_file(vp_file):
                success_count += 1
        
        # Print summary
        total_files = len(vp_files)
        logger.info(f"\nExtraction Summary:")
        logger.info(f"Total VP files: {total_files}")
        logger.info(f"Successfully extracted: {len(self.extraction_results['success'])}")
        logger.info(f"Skipped (already extracted): {len(self.extraction_results['skipped'])}")
        logger.info(f"Failed: {len(self.extraction_results['failed'])}")
        
        if self.extraction_results['failed']:
            logger.warning("Failed extractions:")
            for failed_file in self.extraction_results['failed']:
                logger.warning(f"  - {Path(failed_file).name}")
        
        return len(self.extraction_results['failed']) == 0
    
    def list_vp_contents(self, vp_file: Path) -> None:
        """
        List contents of a specific VP file without extracting.
        
        Args:
            vp_file: Path to VP archive file
        """
        try:
            logger.info(f"Listing contents of: {vp_file.name}")
            
            with VPIndex() as vp:
                if not vp.parse(str(vp_file)):
                    logger.error(f"Failed to parse VP file: {vp_file}")
                    return
                
                files = vp.list_files()
                logger.info(f"Contents of {vp_file.name} ({len(files)} files):")
                
                for file_path in files:
                    print(f"  {file_path}")
                    
        except Exception as e:
            logger.error(f"Error listing {vp_file}: {e}")

def main():
    """Main function for VP batch extraction"""
    parser = argparse.ArgumentParser(description='Extract all VP archives from WCS installation')
    parser.add_argument('--source', type=Path, 
                       default=Path("/mnt/d/Games/Wing Commander Saga/"),
                       help='Path to WCS installation directory (default: /mnt/d/Games/Wing Commander Saga/)')
    parser.add_argument('--output', type=Path,
                       default=Path("source_assets/wcs_hermes_campaign"),
                       help='Output directory for extracted assets (default: source_assets/wcs_hermes_campaign)')
    parser.add_argument('--force', action='store_true',
                       help='Force re-extraction even if output directories exist')
    parser.add_argument('--list-only', action='store_true',
                       help='Only list VP files found, do not extract')
    parser.add_argument('--list-contents', type=str,
                       help='List contents of specific VP file (by name) without extracting')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose output')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )
    
    try:
        # Initialize extractor
        extractor = VPBatchExtractor(args.source, args.output)
        
        if args.list_contents:
            # List contents of specific VP file
            vp_files = extractor.find_vp_files()
            target_vp = None
            for vp_file in vp_files:
                if args.list_contents.lower() in vp_file.name.lower():
                    target_vp = vp_file
                    break
            
            if target_vp:
                extractor.list_vp_contents(target_vp)
            else:
                logger.error(f"VP file not found: {args.list_contents}")
                return 1
        
        elif args.list_only:
            # Just list VP files found
            vp_files = extractor.find_vp_files()
            print(f"\nFound {len(vp_files)} VP files:")
            for vp_file in vp_files:
                print(f"  {vp_file.name}")
                
        else:
            # Extract all VP files
            print(f"Extracting VP archives from: {args.source}")
            print(f"Output directory: {args.output}")
            
            if extractor.extract_all_vp_files(args.force):
                print("\n✓ All VP extractions completed successfully!")
                return 0
            else:
                print("\n✗ Some VP extractions failed. Check logs for details.")
                return 1
        
        return 0
        
    except Exception as e:
        logger.error(f"VP extraction failed: {e}")
        return 1

if __name__ == '__main__':
    exit(main())