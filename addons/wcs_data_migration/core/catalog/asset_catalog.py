#!/usr/bin/env python3
"""
Asset Organization and Cataloging System

This module provides comprehensive asset cataloging and organization functionality
for the WCS-Godot conversion pipeline. It creates searchable databases of all
converted assets with metadata, relationships, and validation.

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-003 - Asset Organization and Cataloging
"""

import hashlib
import json
import logging
import re
import sqlite3
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union

logger = logging.getLogger(__name__)

@dataclass
class AssetMetadata:
    """Comprehensive asset metadata structure"""
    # Core identification
    asset_id: str
    name: str
    file_path: str
    asset_type: str
    category: str
    subcategory: str
    
    # File properties
    file_size: int
    file_hash: str
    creation_date: str
    modification_date: str
    
    # WCS-specific properties
    wcs_source_file: Optional[str] = None
    wcs_format: Optional[str] = None
    wcs_version: Optional[str] = None
    
    # Asset-specific metadata
    dimensions: Optional[Tuple[int, int]] = None  # For textures/images
    duration: Optional[float] = None  # For audio/video
    polygon_count: Optional[int] = None  # For 3D models
    texture_format: Optional[str] = None  # For textures
    
    # Relationships
    dependencies: List[str] = None
    dependents: List[str] = None
    related_assets: List[str] = None
    
    # Tags and properties
    tags: List[str] = None
    properties: Dict[str, Any] = None
    
    def __post_init__(self):
        """Initialize lists and dictionaries if None"""
        if self.dependencies is None:
            self.dependencies = []
        if self.dependents is None:
            self.dependents = []
        if self.related_assets is None:
            self.related_assets = []
        if self.tags is None:
            self.tags = []
        if self.properties is None:
            self.properties = {}

@dataclass 
class AssetRelationship:
    """Asset relationship mapping"""
    source_asset: str
    target_asset: str
    relationship_type: str  # dependency, texture_map, weapon_mount, etc.
    strength: float = 1.0  # Relationship strength (0.0 to 1.0)
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}

@dataclass
class ValidationIssue:
    """Asset validation issue"""
    asset_id: str
    issue_type: str  # missing_dependency, broken_reference, format_error, etc.
    severity: str    # error, warning, info
    message: str
    recommendation: Optional[str] = None

class AssetCatalog:
    """
    Comprehensive asset catalog and organization system.
    
    Manages asset metadata, relationships, search indexing, and validation
    for the WCS-Godot conversion pipeline.
    """
    
    def __init__(self, catalog_path: str = "asset_catalog.json", db_path: str = "asset_catalog.db"):
        """
        Initialize the asset catalog.
        
        Args:
            catalog_path: Path to JSON catalog file
            db_path: Path to SQLite database file
        """
        self.catalog_path = Path(catalog_path)
        self.db_path = Path(db_path)
        self.assets: Dict[str, AssetMetadata] = {}
        self.relationships: List[AssetRelationship] = []
        self.validation_issues: List[ValidationIssue] = []
        
        # Asset type mappings
        self.asset_type_map = {
            '.png': 'texture',
            '.jpg': 'texture', 
            '.jpeg': 'texture',
            '.json': 'metadata',  # Animation metadata
            '.tres': 'resource',
            '.gltf': 'model',
            '.glb': 'model',
            '.wav': 'audio',
            '.ogg': 'audio',
            '.tscn': 'scene',
            '.fs2': 'mission',
            '.tbl': 'table'
        }
        
        # Category mappings based on directory structure
        self.category_map = {
            'ships': {
                'terran': 'Ships/Terran',
                'vassudan': 'Ships/Vassudan', 
                'shivan': 'Ships/Shivan',
                'kilrathi': 'Ships/Kilrathi'
            },
            'weapons': {
                'primary': 'Weapons/Primary',
                'secondary': 'Weapons/Secondary',
                'beam': 'Weapons/Beam'
            },
            'textures': {
                'ship': 'Textures/Ship',
                'interface': 'Textures/Interface',
                'effect': 'Textures/Effect',
                'background': 'Textures/Background'
            },
            'audio': {
                'music': 'Audio/Music',
                'sound': 'Audio/Sound',
                'voice': 'Audio/Voice'
            },
            'missions': {
                'campaign': 'Missions/Campaign',
                'single': 'Missions/Single'
            }
        }
        
        self._init_database()
    
    def _init_database(self) -> None:
        """Initialize SQLite database for complex queries"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Assets table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS assets (
                        asset_id TEXT PRIMARY KEY,
                        name TEXT NOT NULL,
                        file_path TEXT NOT NULL,
                        asset_type TEXT NOT NULL,
                        category TEXT NOT NULL,
                        subcategory TEXT,
                        file_size INTEGER,
                        file_hash TEXT,
                        creation_date TEXT,
                        modification_date TEXT,
                        wcs_source_file TEXT,
                        wcs_format TEXT,
                        metadata_json TEXT
                    )
                ''')
                
                # Relationships table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS relationships (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        source_asset TEXT NOT NULL,
                        target_asset TEXT NOT NULL,
                        relationship_type TEXT NOT NULL,
                        strength REAL DEFAULT 1.0,
                        metadata_json TEXT,
                        FOREIGN KEY (source_asset) REFERENCES assets (asset_id),
                        FOREIGN KEY (target_asset) REFERENCES assets (asset_id)
                    )
                ''')
                
                # Tags table (many-to-many)
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS asset_tags (
                        asset_id TEXT NOT NULL,
                        tag TEXT NOT NULL,
                        PRIMARY KEY (asset_id, tag),
                        FOREIGN KEY (asset_id) REFERENCES assets (asset_id)
                    )
                ''')
                
                # Validation issues table
                cursor.execute('''
                    CREATE TABLE IF NOT EXISTS validation_issues (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        asset_id TEXT NOT NULL,
                        issue_type TEXT NOT NULL,
                        severity TEXT NOT NULL,
                        message TEXT NOT NULL,
                        recommendation TEXT,
                        created_date TEXT DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (asset_id) REFERENCES assets (asset_id)
                    )
                ''')
                
                # Create indexes for performance
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_assets_type ON assets (asset_type)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_assets_category ON assets (category)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_relationships_source ON relationships (source_asset)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_relationships_target ON relationships (target_asset)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_tags_asset ON asset_tags (asset_id)')
                cursor.execute('CREATE INDEX IF NOT EXISTS idx_tags_tag ON asset_tags (tag)')
                
                conn.commit()
                logger.info(f"Initialized asset catalog database: {self.db_path}")
                
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")
            raise
    
    def _calculate_file_hash(self, file_path: Path) -> str:
        """Calculate SHA-256 hash of file"""
        try:
            hash_sha256 = hashlib.sha256()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_sha256.update(chunk)
            return hash_sha256.hexdigest()
        except Exception as e:
            logger.warning(f"Failed to calculate hash for {file_path}: {e}")
            return ""
    
    def _extract_metadata(self, file_path: Path) -> AssetMetadata:
        """Extract comprehensive metadata from file"""
        try:
            stat = file_path.stat()
            file_hash = self._calculate_file_hash(file_path)
            
            # Determine asset type
            asset_type = self.asset_type_map.get(file_path.suffix.lower(), 'unknown')
            
            # Determine category and subcategory from path
            category, subcategory = self._categorize_asset(file_path)
            
            # Generate unique asset ID
            asset_id = self._generate_asset_id(file_path)
            
            metadata = AssetMetadata(
                asset_id=asset_id,
                name=file_path.stem,
                file_path=str(file_path),
                asset_type=asset_type,
                category=category,
                subcategory=subcategory,
                file_size=stat.st_size,
                file_hash=file_hash,
                creation_date=datetime.fromtimestamp(stat.st_ctime).isoformat(),
                modification_date=datetime.fromtimestamp(stat.st_mtime).isoformat()
            )
            
            # Extract format-specific metadata
            self._extract_format_metadata(file_path, metadata)
            
            return metadata
            
        except Exception as e:
            logger.error(f"Failed to extract metadata from {file_path}: {e}")
            raise
    
    def _generate_asset_id(self, file_path: Path) -> str:
        """Generate unique asset ID based on file path"""
        # Use relative path from project root and create a hash-based ID
        path_str = str(file_path).replace('\\', '/')
        path_hash = hashlib.md5(path_str.encode()).hexdigest()[:8]
        clean_name = re.sub(r'[^a-zA-Z0-9_-]', '_', file_path.stem)
        return f"{clean_name}_{path_hash}"
    
    def _categorize_asset(self, file_path: Path) -> Tuple[str, str]:
        """Determine asset category and subcategory from file path"""
        path_parts = file_path.parts
        
        # Look for known category patterns in path
        for i, part in enumerate(path_parts):
            part_lower = part.lower()
            if part_lower in self.category_map:
                category_info = self.category_map[part_lower]
                # Try to find subcategory
                if i + 1 < len(path_parts):
                    next_part = path_parts[i + 1].lower()
                    if isinstance(category_info, dict) and next_part in category_info:
                        return category_info[next_part].split('/')
                return part_lower.title(), ""
        
        # Default categorization based on asset type
        if 'texture' in str(file_path).lower() or file_path.suffix in ['.png', '.jpg', '.jpeg']:
            return "Textures", "General"
        elif 'audio' in str(file_path).lower() or file_path.suffix in ['.wav', '.ogg']:
            return "Audio", "General"
        elif 'model' in str(file_path).lower() or file_path.suffix in ['.gltf', '.glb']:
            return "Models", "General"
        elif 'mission' in str(file_path).lower() or file_path.suffix == '.fs2':
            return "Missions", "General"
        
        return "General", ""
    
    def _extract_format_metadata(self, file_path: Path, metadata: AssetMetadata) -> None:
        """Extract format-specific metadata"""
        try:
            if metadata.asset_type == 'texture':
                self._extract_texture_metadata(file_path, metadata)
            elif metadata.asset_type == 'model':
                self._extract_model_metadata(file_path, metadata)
            elif metadata.asset_type == 'audio':
                self._extract_audio_metadata(file_path, metadata)
            elif metadata.asset_type == 'metadata':
                self._extract_animation_metadata(file_path, metadata)
                
        except Exception as e:
            logger.warning(f"Failed to extract format-specific metadata for {file_path}: {e}")
    
    def _extract_texture_metadata(self, file_path: Path, metadata: AssetMetadata) -> None:
        """Extract texture-specific metadata"""
        try:
            from PIL import Image
            with Image.open(file_path) as img:
                metadata.dimensions = img.size
                metadata.texture_format = img.format
                metadata.properties['color_mode'] = img.mode
                if hasattr(img, 'is_animated'):
                    metadata.properties['animated'] = img.is_animated
        except ImportError:
            logger.warning("PIL not available for texture metadata extraction")
        except Exception as e:
            logger.warning(f"Failed to extract texture metadata: {e}")
    
    def _extract_model_metadata(self, file_path: Path, metadata: AssetMetadata) -> None:
        """Extract 3D model metadata"""
        # For now, we'll extract basic info and estimate polygon count from file size
        # In the future, this could use a GLTF parser
        metadata.properties['estimated_complexity'] = 'high' if metadata.file_size > 1000000 else 'medium' if metadata.file_size > 100000 else 'low'
    
    def _extract_audio_metadata(self, file_path: Path, metadata: AssetMetadata) -> None:
        """Extract audio metadata"""
        # Basic audio metadata - could be enhanced with librosa or similar
        metadata.properties['format'] = file_path.suffix[1:].upper()
    
    def _extract_animation_metadata(self, file_path: Path, metadata: AssetMetadata) -> None:
        """Extract animation metadata from JSON files"""
        try:
            with open(file_path, 'r') as f:
                anim_data = json.load(f)
                if 'frames' in anim_data:
                    metadata.properties['frame_count'] = anim_data['frames']
                if 'frame_delay' in anim_data:
                    metadata.duration = anim_data['frame_delay'] * anim_data.get('frames', 1)
                if 'frame_width' in anim_data and 'frame_height' in anim_data:
                    metadata.dimensions = (anim_data['frame_width'], anim_data['frame_height'])
        except Exception as e:
            logger.warning(f"Failed to extract animation metadata: {e}")
    
    def scan_directory(self, directory: Path, recursive: bool = True) -> int:
        """
        Scan directory and catalog all assets.
        
        Args:
            directory: Directory to scan
            recursive: Whether to scan subdirectories
            
        Returns:
            Number of assets cataloged
        """
        logger.info(f"Scanning directory: {directory}")
        assets_found = 0
        
        try:
            if recursive:
                file_pattern = "**/*"
            else:
                file_pattern = "*"
                
            for file_path in directory.glob(file_pattern):
                if file_path.is_file() and not file_path.name.startswith('.'):
                    try:
                        metadata = self._extract_metadata(file_path)
                        self.assets[metadata.asset_id] = metadata
                        assets_found += 1
                        
                        if assets_found % 100 == 0:
                            logger.info(f"Cataloged {assets_found} assets...")
                            
                    except Exception as e:
                        logger.error(f"Failed to catalog {file_path}: {e}")
                        continue
                        
            logger.info(f"Cataloged {assets_found} assets from {directory}")
            return assets_found
            
        except Exception as e:
            logger.error(f"Failed to scan directory {directory}: {e}")
            return assets_found
    
    def add_relationship(self, source_id: str, target_id: str, relationship_type: str, 
                        strength: float = 1.0, metadata: Optional[Dict[str, Any]] = None) -> None:
        """Add asset relationship"""
        relationship = AssetRelationship(
            source_asset=source_id,
            target_asset=target_id,
            relationship_type=relationship_type,
            strength=strength,
            metadata=metadata or {}
        )
        self.relationships.append(relationship)
        
        # Update asset dependencies
        if source_id in self.assets:
            self.assets[source_id].dependencies.append(target_id)
        if target_id in self.assets:
            self.assets[target_id].dependents.append(source_id)
    
    def search_assets(self, query: str = "", asset_type: str = "", category: str = "", 
                     tags: List[str] = None, limit: int = 100) -> List[AssetMetadata]:
        """
        Search assets with various filters.
        
        Args:
            query: Text search in name
            asset_type: Filter by asset type
            category: Filter by category
            tags: Filter by tags
            limit: Maximum results to return
            
        Returns:
            List of matching assets
        """
        results = []
        
        for asset in self.assets.values():
            # Text search
            if query and query.lower() not in asset.name.lower():
                continue
                
            # Type filter
            if asset_type and asset.asset_type != asset_type:
                continue
                
            # Category filter  
            if category and not asset.category.lower().startswith(category.lower()):
                continue
                
            # Tags filter
            if tags:
                if not any(tag in asset.tags for tag in tags):
                    continue
                    
            results.append(asset)
            
            if len(results) >= limit:
                break
                
        return results
    
    def validate_assets(self) -> List[ValidationIssue]:
        """Validate all assets and return issues"""
        self.validation_issues = []
        
        logger.info(f"Validating {len(self.assets)} assets...")
        
        for asset_id, asset in self.assets.items():
            # Check file existence
            if not Path(asset.file_path).exists():
                self.validation_issues.append(ValidationIssue(
                    asset_id=asset_id,
                    issue_type="missing_file",
                    severity="error", 
                    message=f"Asset file does not exist: {asset.file_path}",
                    recommendation="Re-extract or convert the asset"
                ))
            
            # Check dependencies
            for dep_id in asset.dependencies:
                if dep_id not in self.assets:
                    self.validation_issues.append(ValidationIssue(
                        asset_id=asset_id,
                        issue_type="missing_dependency",
                        severity="warning",
                        message=f"Dependency not found: {dep_id}",
                        recommendation="Check if dependency was converted or update reference"
                    ))
            
            # Format-specific validation
            if asset.asset_type == 'texture' and asset.dimensions:
                width, height = asset.dimensions
                if width > 4096 or height > 4096:
                    self.validation_issues.append(ValidationIssue(
                        asset_id=asset_id,
                        issue_type="oversized_texture",
                        severity="warning",
                        message=f"Large texture dimensions: {width}x{height}",
                        recommendation="Consider texture compression or optimization"
                    ))
        
        logger.info(f"Found {len(self.validation_issues)} validation issues")
        return self.validation_issues
    
    def generate_manifest(self) -> Dict[str, Any]:
        """Generate comprehensive conversion manifest"""
        manifest = {
            'catalog_info': {
                'generated_date': datetime.now().isoformat(),
                'total_assets': len(self.assets),
                'total_relationships': len(self.relationships),
                'validation_issues': len(self.validation_issues)
            },
            'asset_summary': {
                'by_type': {},
                'by_category': {},
                'total_size': 0
            },
            'conversion_statistics': {
                'successful_conversions': 0,
                'failed_conversions': 0,
                'conversion_rate': 0.0
            },
            'quality_metrics': {
                'assets_with_metadata': 0,
                'assets_with_relationships': 0,
                'validation_pass_rate': 0.0
            }
        }
        
        # Calculate summary statistics
        for asset in self.assets.values():
            # By type
            asset_type = asset.asset_type
            if asset_type not in manifest['asset_summary']['by_type']:
                manifest['asset_summary']['by_type'][asset_type] = 0
            manifest['asset_summary']['by_type'][asset_type] += 1
            
            # By category
            category = asset.category
            if category not in manifest['asset_summary']['by_category']:
                manifest['asset_summary']['by_category'][category] = 0
            manifest['asset_summary']['by_category'][category] += 1
            
            # Total size
            manifest['asset_summary']['total_size'] += asset.file_size
            
            # Quality metrics
            if asset.properties or asset.dimensions:
                manifest['quality_metrics']['assets_with_metadata'] += 1
            if asset.dependencies or asset.dependents:
                manifest['quality_metrics']['assets_with_relationships'] += 1
        
        # Calculate rates
        total_assets = len(self.assets)
        if total_assets > 0:
            manifest['quality_metrics']['validation_pass_rate'] = (
                total_assets - len([issue for issue in self.validation_issues if issue.severity == 'error'])
            ) / total_assets
        
        return manifest
    
    def save_catalog(self) -> None:
        """Save catalog to JSON and database"""
        try:
            # Save to JSON
            catalog_data = {
                'assets': {asset_id: asdict(asset) for asset_id, asset in self.assets.items()},
                'relationships': [asdict(rel) for rel in self.relationships],
                'validation_issues': [asdict(issue) for issue in self.validation_issues],
                'manifest': self.generate_manifest()
            }
            
            with open(self.catalog_path, 'w') as f:
                json.dump(catalog_data, f, indent=2)
            
            logger.info(f"Saved catalog to {self.catalog_path}")
            
            # Save to database
            self._save_to_database()
            
        except Exception as e:
            logger.error(f"Failed to save catalog: {e}")
            raise
    
    def _save_to_database(self) -> None:
        """Save catalog data to SQLite database"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                # Clear existing data
                cursor.execute("DELETE FROM validation_issues")
                cursor.execute("DELETE FROM asset_tags")
                cursor.execute("DELETE FROM relationships")
                cursor.execute("DELETE FROM assets")
                
                # Insert assets
                for asset in self.assets.values():
                    cursor.execute('''
                        INSERT INTO assets (
                            asset_id, name, file_path, asset_type, category, subcategory,
                            file_size, file_hash, creation_date, modification_date,
                            wcs_source_file, wcs_format, metadata_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        asset.asset_id, asset.name, asset.file_path, asset.asset_type,
                        asset.category, asset.subcategory, asset.file_size, asset.file_hash,
                        asset.creation_date, asset.modification_date, asset.wcs_source_file,
                        asset.wcs_format, json.dumps(asset.properties)
                    ))
                    
                    # Insert tags
                    for tag in asset.tags:
                        cursor.execute("INSERT INTO asset_tags (asset_id, tag) VALUES (?, ?)", 
                                     (asset.asset_id, tag))
                
                # Insert relationships
                for rel in self.relationships:
                    cursor.execute('''
                        INSERT INTO relationships (
                            source_asset, target_asset, relationship_type, strength, metadata_json
                        ) VALUES (?, ?, ?, ?, ?)
                    ''', (
                        rel.source_asset, rel.target_asset, rel.relationship_type,
                        rel.strength, json.dumps(rel.metadata)
                    ))
                
                # Insert validation issues
                for issue in self.validation_issues:
                    cursor.execute('''
                        INSERT INTO validation_issues (
                            asset_id, issue_type, severity, message, recommendation
                        ) VALUES (?, ?, ?, ?, ?)
                    ''', (
                        issue.asset_id, issue.issue_type, issue.severity,
                        issue.message, issue.recommendation
                    ))
                
                conn.commit()
                logger.info(f"Saved catalog to database: {self.db_path}")
                
        except Exception as e:
            logger.error(f"Failed to save to database: {e}")
            raise
    
    def load_catalog(self) -> bool:
        """Load catalog from JSON file"""
        try:
            if not self.catalog_path.exists():
                logger.warning(f"Catalog file not found: {self.catalog_path}")
                return False
                
            with open(self.catalog_path, 'r') as f:
                catalog_data = json.load(f)
            
            # Load assets
            self.assets = {}
            for asset_id, asset_dict in catalog_data.get('assets', {}).items():
                # Convert lists back to proper types
                asset_dict['dependencies'] = asset_dict.get('dependencies', [])
                asset_dict['dependents'] = asset_dict.get('dependents', [])
                asset_dict['related_assets'] = asset_dict.get('related_assets', [])
                asset_dict['tags'] = asset_dict.get('tags', [])
                asset_dict['properties'] = asset_dict.get('properties', {})
                
                # Convert dimensions tuple if present
                if asset_dict.get('dimensions'):
                    asset_dict['dimensions'] = tuple(asset_dict['dimensions'])
                
                self.assets[asset_id] = AssetMetadata(**asset_dict)
            
            # Load relationships
            self.relationships = []
            for rel_dict in catalog_data.get('relationships', []):
                self.relationships.append(AssetRelationship(**rel_dict))
            
            # Load validation issues
            self.validation_issues = []
            for issue_dict in catalog_data.get('validation_issues', []):
                self.validation_issues.append(ValidationIssue(**issue_dict))
            
            logger.info(f"Loaded catalog with {len(self.assets)} assets")
            return True
            
        except Exception as e:
            logger.error(f"Failed to load catalog: {e}")
            return False

def main():
    """Main function for command-line usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Asset catalog and organization tool')
    parser.add_argument('command', choices=['scan', 'validate', 'search', 'manifest'],
                       help='Command to execute')
    parser.add_argument('-d', '--directory', default='converted',
                       help='Directory to scan for assets')
    parser.add_argument('-o', '--output', default='asset_catalog.json',
                       help='Output catalog file')
    parser.add_argument('-q', '--query', help='Search query')
    parser.add_argument('-t', '--type', help='Filter by asset type')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose output')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format='%(levelname)s: %(message)s')
    
    # Initialize catalog
    catalog = AssetCatalog(args.output)
    
    try:
        if args.command == 'scan':
            directory = Path(args.directory)
            if not directory.exists():
                logger.error(f"Directory not found: {directory}")
                return 1
            
            count = catalog.scan_directory(directory)
            catalog.save_catalog()
            print(f"Cataloged {count} assets")
            
        elif args.command == 'validate':
            catalog.load_catalog()
            issues = catalog.validate_assets()
            catalog.save_catalog()
            
            print(f"Found {len(issues)} validation issues:")
            for issue in issues:
                print(f"  {issue.severity.upper()}: {issue.message}")
            
        elif args.command == 'search':
            catalog.load_catalog()
            results = catalog.search_assets(
                query=args.query or "",
                asset_type=args.type or ""
            )
            
            print(f"Found {len(results)} assets:")
            for asset in results:
                print(f"  {asset.name} ({asset.asset_type}) - {asset.file_path}")
                
        elif args.command == 'manifest':
            catalog.load_catalog()
            manifest = catalog.generate_manifest()
            print(json.dumps(manifest, indent=2))
            
        return 0
        
    except Exception as e:
        logger.error(f"Command failed: {e}")
        return 1

if __name__ == '__main__':
    exit(main())