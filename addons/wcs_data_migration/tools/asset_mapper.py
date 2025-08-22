#!/usr/bin/env python3
"""
Asset Mapper - Automated Asset Mapping from Table Data and File System Scanning

This module creates comprehensive asset dependency maps by combining:
1. Data-driven relationships from WCS table files (.tbl)
2. File system scanning to discover all assets for each entity.
3. Semantic classification and path resolution for a well-organized Godot project.

Author: Dev (GDScript Developer)
Date: June 10, 2025
Story: DM-013 - Automated Asset Mapping from Table Data
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import hashlib
import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

from core.asset_discovery import AssetDiscoveryEngine
from core.entity_classifier import EntityClassifier, EntityType, TableType
from core.path_resolver import TargetPathResolver
# Core addon imports
from data_structures import AssetMapping, AssetRelationship

logger = logging.getLogger(__name__)

class AssetMapper:
    """
    Creates comprehensive asset mappings by combining table data analysis
    with deep asset discovery and semantic organization.
    """
    
    def __init__(self, source_dir: Path, target_structure: Dict[str, str]):
        """
        Initialize the asset mapper.
        
        Args:
            source_dir: WCS source directory containing .tbl files
            target_structure: Target directory structure mapping
        """
        self.source_dir = Path(source_dir)
        self.target_structure = target_structure
        
        # Initialize core components
        self.asset_discovery = AssetDiscoveryEngine(self.source_dir)
        self.entity_classifier = EntityClassifier(self.source_dir)
        self.path_resolver = TargetPathResolver(self.target_structure, self.source_dir)
        
        # Asset relationship storage
        self.asset_mappings: Dict[str, AssetMapping] = {}
        self.missing_assets: Set[str] = set()
        self.unclassified_files: List[str] = []
        self.file_hash_cache: Dict[str, str] = {} # To track duplicates
        self.duplicates_found = 0

    def _get_file_hash(self, file_path: Path) -> Optional[str]:
        """Computes the SHA256 hash of a file's content."""
        try:
            sha256_hash = hashlib.sha256()
            with open(file_path, "rb") as f:
                # Read and update hash in chunks of 4K
                for byte_block in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(byte_block)
            return sha256_hash.hexdigest()
        except FileNotFoundError:
            logger.warning(f"Could not find file for hashing: {file_path}")
            return None
        except Exception as e:
            logger.error(f"Error hashing file {file_path}: {e}")
            return None

    def generate_mapping(self) -> Dict[str, Any]:
        """
        Generate complete project mapping JSON combining table data and file scanning.
        
        Returns:
            Complete project mapping dictionary ready for JSON serialization
        """
        logger.info("Generating complete project mapping...")
        
        # 1. Extract entities from primary table files
        table_files = self._find_table_files()
        logger.info(f"Found {len(table_files)} table files to process.")
        
        table_entities = self._extract_entities_from_tables(table_files)
        
        # 2. Create initial mappings from table entities
        logger.info(f"Processing {len(table_entities)} entities from tables...")
        for i, (entity_name, table_type) in enumerate(table_entities.items()):
            logger.info(f"  ({i+1}/{len(table_entities)}) Processing entity: {entity_name}")
            self._create_mapping_for_entity(entity_name, table_type)
            
        # 3. Scan for any unmapped files and create mappings for them
        self._scan_and_map_unmapped_files()
        
        # 4. Generate final mapping structure
        project_mapping = self._build_final_json()
        
        logger.info(f"Generated mapping for {len(self.asset_mappings)} entities with {project_mapping['metadata']['total_assets']} total assets.")
        return project_mapping

    def _find_table_files(self) -> List[Path]:
        """Find all relevant .tbl files in the source directory."""
        core_dir = self.source_dir / "hermes_core"
        if core_dir.exists():
            return list(core_dir.glob('*.tbl'))
        return []

    def _extract_entities_from_tables(self, table_files: List[Path]) -> Dict[str, TableType]:
        """Extract all entity names from the main table files."""
        entities = {}
        for table_file in table_files:
            table_type = self.entity_classifier.determine_table_type(table_file)
            if table_type in [TableType.SHIPS, TableType.WEAPONS, TableType.ASTEROID]:
                try:
                    with open(table_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    # Use regex to find all $Name: definitions
                    name_pattern = r'^\$Name:\s*([^\r\n]+)'
                    found_names = re.findall(name_pattern, content, re.MULTILINE)
                    
                    for name in found_names:
                        clean_name = name.strip()
                        if clean_name and not clean_name.startswith('#') and not clean_name.lower() in ['default', 'none']:
                            entities[clean_name] = table_type
                except Exception as e:
                    logger.error(f"Failed to parse {table_file}: {e}")
        
        logger.info(f"Extracted {len(entities)} primary entities from tables.")
        return entities

    def _create_mapping_for_entity(self, entity_name: str, table_type: TableType):
        """Discover assets and create a complete mapping for a single entity."""
        if entity_name in self.asset_mappings:
            return

        logger.debug(f"Creating mapping for entity: '{entity_name}' from table: {table_type.value}")
        
        entity_type = self.entity_classifier.classify_entity(entity_name, table_type)
        
        # Discover all related assets using the discovery engine
        primary_model_path = self._find_primary_model(entity_name, table_type)
        relationships = self.asset_discovery.discover_entity_assets(entity_name, entity_type.value, primary_model_path)
        
        # Resolve target paths and handle duplicates
        for rel in relationships:
            source_file_path = self.source_dir / rel.source_path
            file_hash = self._get_file_hash(source_file_path)

            if file_hash and file_hash in self.file_hash_cache:
                # This is a duplicate file
                rel.target_path = self.file_hash_cache[file_hash]
                self.duplicates_found += 1
                logger.debug(f"Duplicate found for {rel.source_path}, mapping to {rel.target_path}")
            else:
                # New file, resolve path and add to cache
                rel.target_path = self.path_resolver.resolve_semantic_faction_path(
                    entity_name, entity_type, rel.asset_type, rel.source_path, rel.relationship_type
                )
                if file_hash:
                    self.file_hash_cache[file_hash] = rel.target_path

        primary_asset = next((r for r in relationships if r.relationship_type == 'primary_model' or r.asset_type == 'model'), None)
        related_assets = [r for r in relationships if r != primary_asset]

        self.asset_mappings[entity_name] = AssetMapping(
            entity_name=entity_name,
            entity_type=entity_type.value,
            primary_asset=primary_asset,
            related_assets=related_assets,
            metadata={'source': 'table_scan'}
        )

    def _find_primary_model(self, entity_name: str, table_type: TableType) -> Optional[str]:
        """A simplified way to find a primary model path from table content."""
        # This is a simplified stand-in. A full implementation would parse tables more deeply.
        return None

    def _scan_and_map_unmapped_files(self):
        """Scan all source files and create mappings for any not already covered."""
        logger.info("Scanning all source directories for unmapped files...")
        
        mapped_sources = set()
        for mapping in self.asset_mappings.values():
            if mapping.primary_asset:
                mapped_sources.add(mapping.primary_asset.source_path)
            for rel in mapping.related_assets:
                mapped_sources.add(rel.source_path)

        all_source_files = []
        for ext_list in self.asset_discovery.asset_extensions.values():
            for ext in ext_list:
                all_source_files.extend(self.source_dir.rglob(f"**/*{ext}"))
        
        logger.info(f"Found {len(all_source_files)} total files. Checking for unmapped assets...")
        unmapped_count = 0
        for file_path in all_source_files:
            rel_path = str(file_path.relative_to(self.source_dir))
            if rel_path not in mapped_sources:
                unmapped_count += 1
                logger.debug(f"  Mapping unmapped file: {rel_path}")
                self._create_mapping_for_file(file_path)
        logger.info(f"Mapped {unmapped_count} new files from file scan.")

    def _create_mapping_for_file(self, file_path: Path):
        """Create a generic mapping for a single unmapped file."""
        entity_name = file_path.stem
        entity_type = self.entity_classifier.classify_by_file_extension(file_path)

        if entity_name in self.asset_mappings:
            return

        if entity_type == EntityType.UNKNOWN:
            logger.warning(f"Could not classify file, skipping: {file_path}")
            self.unclassified_files.append(str(file_path.relative_to(self.source_dir)))
            return

        logger.debug(f"Creating mapping for unmapped file: {file_path.name}")

        rel_path = str(file_path.relative_to(self.source_dir))
        
        # Handle duplicates for unmapped files
        file_hash = self._get_file_hash(file_path)
        if file_hash and file_hash in self.file_hash_cache:
            target_path = self.file_hash_cache[file_hash]
            is_duplicate = True
            self.duplicates_found += 1
        else:
            target_path = self.path_resolver.resolve_semantic_faction_path(
                entity_name, entity_type, entity_type.value, rel_path
            )
            if file_hash:
                self.file_hash_cache[file_hash] = target_path
            is_duplicate = False

        relationship = AssetRelationship(
            source_path=rel_path,
            target_path=target_path,
            asset_type=entity_type.value,
            parent_entity=entity_name,
            relationship_type='primary'
        )

        self.asset_mappings[entity_name] = AssetMapping(
            entity_name=entity_name,
            entity_type=entity_type.value,
            primary_asset=relationship,
            related_assets=[],
            metadata={'source': 'file_scan', 'is_duplicate': is_duplicate}
        )

    def _build_final_json(self) -> Dict[str, Any]:
        """Construct the final JSON output from the generated asset mappings."""
        total_assets = sum(len(m.related_assets) + (1 if m.primary_asset else 0) for m in self.asset_mappings.values())
        
        project_mapping = {
            'metadata': {
                'generator': 'AssetMapperV2',
                'version': '2.0',
                'source_dir': str(self.source_dir),
                'generated_date': datetime.now().isoformat(),
                'total_entities': len(self.asset_mappings),
                'total_assets': total_assets
            },
            'target_structure': self.target_structure,
            'entity_mappings': {},
            'asset_index': {},
            'missing_assets': list(self.missing_assets),
            'unclassified_files': self.unclassified_files,
            'statistics': {
                'ships': len([m for m in self.asset_mappings.values() if m.entity_type == 'ship']),
                'weapons': len([m for m in self.asset_mappings.values() if m.entity_type == 'weapon']),
                'asteroids': len([m for m in self.asset_mappings.values() if m.entity_type == 'asteroid']),
                'effects': len([m for m in self.asset_mappings.values() if m.entity_type == 'effect']),
                'total_relationships': total_assets,
                'duplicates_found': self.duplicates_found
            }
        }
        
        for entity_name, mapping in self.asset_mappings.items():
            project_mapping['entity_mappings'][entity_name] = {
                'entity_type': mapping.entity_type,
                'primary_asset': self._serialize_relationship(mapping.primary_asset),
                'related_assets': [self._serialize_relationship(rel) for rel in mapping.related_assets],
                'metadata': mapping.metadata
            }
            
            all_assets = ([mapping.primary_asset] if mapping.primary_asset else []) + mapping.related_assets
            for rel in all_assets:
                if rel.source_path not in project_mapping['asset_index']:
                    project_mapping['asset_index'][rel.source_path] = []
                project_mapping['asset_index'][rel.source_path].append({
                    'entity': entity_name,
                    'target_path': rel.target_path,
                    'relationship_type': rel.relationship_type
                })
        
        return project_mapping

    def _serialize_relationship(self, relationship: Optional[AssetRelationship]) -> Optional[Dict[str, Any]]:
        """Convert AssetRelationship to a serializable dictionary."""
        if not relationship:
            return None
        return {
            'source_path': relationship.source_path,
            'target_path': relationship.target_path,
            'asset_type': relationship.asset_type,
            'parent_entity': relationship.parent_entity,
            'relationship_type': relationship.relationship_type,
            'required': relationship.required
        }

    def save_mapping_json(self, project_mapping: Dict[str, Any], output_path: Path) -> bool:
        """Save project mapping to JSON file."""
        try:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(project_mapping, f, indent=2, ensure_ascii=False)
            logger.info(f"Project mapping saved to: {output_path}")
            return True
        except Exception as e:
            logger.error(f"Failed to save project mapping to {output_path}: {e}")
            return False

def main():
    """Command-line interface for the asset mapper."""
    import argparse
    from datetime import datetime
    
    parser = argparse.ArgumentParser(description='Generate asset relationship mapping from WCS source files.')
    parser.add_argument('--source', type=Path, required=True, help='WCS source directory')
    parser.add_argument('--output', type=Path, required=True, help='Output JSON file for the asset mapping')
    parser.add_argument('--target-structure', type=Path, help='Path to a JSON file describing the target directory structure')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format='%(asctime)s - %(levelname)s - %(message)s')
    
    target_structure = {}
    if args.target_structure and args.target_structure.exists():
        with open(args.target_structure) as f:
            target_structure = json.load(f)
    
    try:
        mapper = AssetMapper(args.source, target_structure)
        mapping = mapper.generate_mapping()
        
        if mapper.save_mapping_json(mapping, args.output):
            print("Asset mapping generation completed successfully!")
            print(f"  - Entities: {mapping['metadata']['total_entities']}")
            print(f"  - Assets: {mapping['metadata']['total_assets']}")
            print(f"  - Duplicates Found: {mapping['statistics']['duplicates_found']}")
            if mapping['unclassified_files']:
                print(f"  - Unclassified Files: {len(mapping['unclassified_files'])}")
        else:
            print("Failed to save asset mapping.")
            return 1
            
    except Exception as e:
        logger.error(f"Asset mapping generation failed: {e}", exc_info=args.verbose)
        return 1
    
    return 0

if __name__ == '__main__':
    # This allows the script to be run from the command line
    # For it to work, you need to be in the 'wcs_data_migration' directory
    # and run it as a module: python -m tools.asset_mapper --source ...
    from datetime import datetime
    exit(main())
