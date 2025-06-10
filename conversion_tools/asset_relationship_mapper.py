#!/usr/bin/env python3
"""
Asset Relationship Mapper - Automated Asset Mapping from Table Data

This module creates comprehensive asset dependency maps by combining:
1. Data-driven relationships from WCS table files (.tbl)
2. Hardcoded asset mappings discovered through manual C++ source analysis

Implementation for DM-013: Automated Asset Mapping from Table Data

Author: Dev (GDScript Developer)
Date: June 10, 2025
Story: DM-013 - Automated Asset Mapping from Table Data
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import json
import logging
import re
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple, Any
from dataclasses import dataclass, field

try:
    from table_data_converter import TableDataConverter, TableType, ParseError
except ImportError:
    # Fallback for testing - define minimal required classes
    from enum import Enum
    
    class TableType(Enum):
        SHIPS = "ships"
        WEAPONS = "weapons"
        ARMOR = "armor"
        SPECIES = "species_defs"
        IFF = "iff_defs"
        UNKNOWN = "unknown"
    
    class ParseError(Exception):
        pass
    
    class TableDataConverter:
        def __init__(self, source_dir, target_dir):
            pass

logger = logging.getLogger(__name__)

@dataclass
class AssetRelationship:
    """Represents a relationship between source asset and target conversion"""
    source_path: str
    target_path: str
    asset_type: str
    parent_entity: Optional[str] = None
    relationship_type: str = "reference"  # reference, texture, model, sound, etc.
    required: bool = True
    
@dataclass 
class AssetMapping:
    """Complete asset mapping with all relationships"""
    entity_name: str
    entity_type: str  # ship, weapon, mission, etc.
    primary_asset: Optional[AssetRelationship] = None
    related_assets: List[AssetRelationship] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)

class HardcodedAssetMappings:
    """
    Hardcoded asset mappings discovered through manual C++ source analysis.
    
    These mappings capture asset relationships that are not defined in table files
    but are hardcoded in the C++ source code through string literals, lookup tables,
    enums, and other mechanisms.
    
    Based on analysis of WCS source files:
    - bmpman/bmpman.cpp: Texture loading and format mappings
    - model/modelread.cpp: POF model loading and texture associations
    - weapon/weapons.cpp: Weapon effects and sound mappings
    - ship/ship.cpp: Ship subsystem and effect mappings
    - game_snd/gamesnd.cpp: Sound file mappings
    """
    
    # Texture format mappings (from bmpman.cpp analysis)
    TEXTURE_EXTENSIONS = {
        'dds', 'pcx', 'tga', 'png', 'jpg', 'jpeg'
    }
    
    # Standard texture suffixes (from model loading code)
    TEXTURE_SUFFIXES = {
        'glow': '_glow',
        'normal': '_normal', 
        'specular': '_spec',
        'reflect': '_reflect',
        'shine': '_shine',
        'thruster': '_thruster'
    }
    
    # Weapon effect mappings (from weapons.cpp)
    WEAPON_EFFECTS = {
        'laser': {
            'muzzle_flash': 'muzzleflash',
            'impact_effect': 'impact', 
            'beam_effect': 'beam',
            'sound_fire': 'wpn_',
            'sound_impact': 'impact_'
        },
        'missile': {
            'trail_effect': 'trail',
            'exhaust_effect': 'exhaust',
            'sound_fire': 'missile_',
            'sound_impact': 'explosion_'
        }
    }
    
    # Ship subsystem mappings (from ship.cpp)
    SHIP_SUBSYSTEMS = {
        'engine': {
            'glow_texture': '_engineglow',
            'trail_effect': '_trail',
            'sound_engine': 'engine_'
        },
        'turret': {
            'barrel_model': '_barrel',
            'base_model': '_base',
            'fire_sound': 'turret_'
        }
    }
    
    # Common asset naming patterns (from various .cpp files)
    ASSET_PATTERNS = {
        'ship_textures': [
            '{ship_name}',
            '{ship_name}_glow',
            '{ship_name}_normal', 
            '{ship_name}_spec'
        ],
        'weapon_sounds': [
            'wpn_{weapon_name}',
            '{weapon_name}_fire',
            '{weapon_name}_loop'
        ],
        'explosion_effects': [
            'exp_{size}_{type}',
            'debris_{ship_class}'
        ]
    }
    
    # Campaign-specific asset overrides (from campaign table analysis)
    CAMPAIGN_OVERRIDES = {
        'hermes': {
            'ship_prefix': 'h_',
            'weapon_prefix': 'hw_',
            'mission_prefix': 'hm_'
        }
    }

class AssetRelationshipMapper:
    """
    Creates comprehensive asset mappings by combining table data with hardcoded mappings.
    
    This class extends the functionality of TableDataConverter to build complete
    asset dependency maps that include both data-driven relationships (from .tbl files)
    and hardcoded relationships (discovered through C++ source analysis).
    """
    
    def __init__(self, source_dir: Path, target_structure: Dict[str, str]):
        """
        Initialize the asset relationship mapper.
        
        Args:
            source_dir: WCS source directory containing .tbl files
            target_structure: Target directory structure mapping (from target/assets/CLAUDE.md)
        """
        self.source_dir = Path(source_dir)
        self.target_structure = target_structure
        self.table_converter = TableDataConverter(source_dir, source_dir)
        self.hardcoded_mappings = HardcodedAssetMappings()
        
        # Asset relationship storage
        self.asset_mappings: Dict[str, AssetMapping] = {}
        self.discovered_assets: Set[str] = set()
        self.missing_assets: Set[str] = set()
        
    def analyze_table_relationships(self, table_files: List[Path]) -> Dict[str, List[AssetRelationship]]:
        """
        Extract asset relationships from table files.
        
        Args:
            table_files: List of .tbl files to analyze
            
        Returns:
            Dictionary mapping entity names to their asset relationships
        """
        logger.info(f"Analyzing asset relationships in {len(table_files)} table files")
        relationships = {}
        
        for table_file in table_files:
            try:
                table_type = self._determine_table_type(table_file)
                if table_type == TableType.UNKNOWN:
                    continue
                    
                logger.debug(f"Processing {table_type.value} table: {table_file.name}")
                
                if table_type == TableType.SHIPS:
                    ship_relationships = self._extract_ship_relationships(table_file)
                    relationships.update(ship_relationships)
                elif table_type == TableType.WEAPONS:
                    weapon_relationships = self._extract_weapon_relationships(table_file)
                    relationships.update(weapon_relationships)
                # Add other table types as needed
                    
            except Exception as e:
                logger.error(f"Failed to process table file {table_file}: {e}")
                continue
                
        logger.info(f"Extracted relationships for {len(relationships)} entities")
        return relationships
    
    def _determine_table_type(self, table_file: Path) -> TableType:
        """Determine the type of table file based on filename and content"""
        filename = table_file.name.lower()
        
        if 'ship' in filename:
            return TableType.SHIPS
        elif 'weapon' in filename:
            return TableType.WEAPONS
        elif 'armor' in filename:
            return TableType.ARMOR
        elif 'species' in filename:
            return TableType.SPECIES
        elif 'iff' in filename:
            return TableType.IFF
        else:
            return TableType.UNKNOWN
    
    def _extract_ship_relationships(self, ships_table: Path) -> Dict[str, List[AssetRelationship]]:
        """Extract asset relationships from ships.tbl"""
        relationships = {}
        
        try:
            # Parse ship table using existing converter
            with open(ships_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Extract ship definitions using regex patterns
            ship_pattern = r'\$Name:\s*([^\r\n]+)'
            model_pattern = r'\$Model\s+File:\s*([^\r\n]+)'
            texture_pattern = r'\$Texture\s+Replace:\s*([^\r\n]+)'
            
            current_ship = None
            
            for line_num, line in enumerate(content.split('\n'), 1):
                line = line.strip()
                
                # Ship name
                ship_match = re.match(ship_pattern, line)
                if ship_match:
                    current_ship = ship_match.group(1).strip()
                    relationships[current_ship] = []
                    continue
                
                if not current_ship:
                    continue
                
                # Model file
                model_match = re.match(model_pattern, line)
                if model_match:
                    model_file = model_match.group(1).strip()
                    # Create primary model relationship
                    model_rel = AssetRelationship(
                        source_path=f"models/{model_file}",
                        target_path=self._get_target_path('ship_model', current_ship, model_file),
                        asset_type='model',
                        parent_entity=current_ship,
                        relationship_type='primary_model'
                    )
                    relationships[current_ship].append(model_rel)
                    
                    # Add related texture relationships using hardcoded patterns
                    texture_rels = self._generate_ship_texture_relationships(current_ship, model_file)
                    relationships[current_ship].extend(texture_rels)
                
                # Explicit texture replacements
                texture_match = re.match(texture_pattern, line)
                if texture_match:
                    texture_spec = texture_match.group(1).strip()
                    texture_rel = self._parse_texture_replacement(current_ship, texture_spec)
                    if texture_rel:
                        relationships[current_ship].append(texture_rel)
        
        except Exception as e:
            logger.error(f"Failed to extract ship relationships from {ships_table}: {e}")
        
        return relationships
    
    def _extract_weapon_relationships(self, weapons_table: Path) -> Dict[str, List[AssetRelationship]]:
        """Extract asset relationships from weapons.tbl"""
        relationships = {}
        
        try:
            with open(weapons_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            weapon_pattern = r'\$Name:\s*([^\r\n]+)'
            model_pattern = r'\$Model\s+File:\s*([^\r\n]+)'
            sound_pattern = r'\$LaunchSnd:\s*([^\r\n]+)'
            
            current_weapon = None
            
            for line in content.split('\n'):
                line = line.strip()
                
                weapon_match = re.match(weapon_pattern, line)
                if weapon_match:
                    current_weapon = weapon_match.group(1).strip()
                    relationships[current_weapon] = []
                    continue
                
                if not current_weapon:
                    continue
                
                # Weapon model
                model_match = re.match(model_pattern, line)
                if model_match:
                    model_file = model_match.group(1).strip()
                    model_rel = AssetRelationship(
                        source_path=f"models/{model_file}",
                        target_path=self._get_target_path('weapon_model', current_weapon, model_file),
                        asset_type='model',
                        parent_entity=current_weapon,
                        relationship_type='primary_model'
                    )
                    relationships[current_weapon].append(model_rel)
                
                # Weapon sounds
                sound_match = re.match(sound_pattern, line)
                if sound_match:
                    sound_file = sound_match.group(1).strip()
                    sound_rel = AssetRelationship(
                        source_path=f"sounds/{sound_file}",
                        target_path=self._get_target_path('weapon_sound', current_weapon, sound_file),
                        asset_type='audio',
                        parent_entity=current_weapon,
                        relationship_type='fire_sound'
                    )
                    relationships[current_weapon].append(sound_rel)
                    
                    # Add related weapon effect sounds using hardcoded patterns
                    effect_rels = self._generate_weapon_effect_relationships(current_weapon)
                    relationships[current_weapon].extend(effect_rels)
        
        except Exception as e:
            logger.error(f"Failed to extract weapon relationships from {weapons_table}: {e}")
        
        return relationships
    
    def _generate_ship_texture_relationships(self, ship_name: str, model_file: str) -> List[AssetRelationship]:
        """Generate texture relationships for a ship using hardcoded patterns"""
        relationships = []
        base_name = Path(model_file).stem
        
        for suffix_type, suffix in self.hardcoded_mappings.TEXTURE_SUFFIXES.items():
            for ext in self.hardcoded_mappings.TEXTURE_EXTENSIONS:
                texture_file = f"{base_name}{suffix}.{ext}"
                
                texture_rel = AssetRelationship(
                    source_path=f"textures/{texture_file}",
                    target_path=self._get_target_path('ship_texture', ship_name, texture_file),
                    asset_type='texture',
                    parent_entity=ship_name,
                    relationship_type=suffix_type,
                    required=False  # Texture variants are optional
                )
                relationships.append(texture_rel)
        
        return relationships
    
    def _generate_weapon_effect_relationships(self, weapon_name: str) -> List[AssetRelationship]:
        """Generate weapon effect relationships using hardcoded patterns"""
        relationships = []
        
        # Determine weapon type from name patterns
        weapon_type = 'laser'
        if any(keyword in weapon_name.lower() for keyword in ['missile', 'torpedo', 'bomb']):
            weapon_type = 'missile'
        
        effect_mappings = self.hardcoded_mappings.WEAPON_EFFECTS.get(weapon_type, {})
        
        for effect_type, prefix in effect_mappings.items():
            if effect_type.startswith('sound_'):
                asset_type = 'audio'
                ext = 'wav'
            else:
                asset_type = 'effect'
                ext = 'tscn'
            
            effect_file = f"{prefix}{weapon_name.lower().replace(' ', '_')}.{ext}"
            
            effect_rel = AssetRelationship(
                source_path=f"effects/{effect_file}",
                target_path=self._get_target_path(f'weapon_{asset_type}', weapon_name, effect_file),
                asset_type=asset_type,
                parent_entity=weapon_name,
                relationship_type=effect_type,
                required=False
            )
            relationships.append(effect_rel)
        
        return relationships
    
    def _parse_texture_replacement(self, entity_name: str, texture_spec: str) -> Optional[AssetRelationship]:
        """Parse explicit texture replacement specification"""
        try:
            # Format: "old_texture new_texture" or just "texture_name"
            parts = texture_spec.split()
            if len(parts) >= 1:
                texture_file = parts[-1]  # Use the last part as the texture name
                
                return AssetRelationship(
                    source_path=f"textures/{texture_file}",
                    target_path=self._get_target_path('texture', entity_name, texture_file),
                    asset_type='texture',
                    parent_entity=entity_name,
                    relationship_type='replacement'
                )
        except Exception as e:
            logger.debug(f"Could not parse texture spec '{texture_spec}': {e}")
        
        return None
    
    def _get_target_path(self, asset_category: str, entity_name: str, source_file: str) -> str:
        """
        Generate target path following the structure defined in target/assets/CLAUDE.md
        """
        clean_entity = entity_name.lower().replace(' ', '_').replace('-', '_')
        file_name = Path(source_file).name.lower()
        
        # Map to target directory structure based on asset category
        if asset_category in ['ship_model', 'ship_texture']:
            # Determine faction from entity name or default to common
            faction = self._determine_faction(entity_name)
            ship_class = self._determine_ship_class(entity_name)
            return f"campaigns/wing_commander_saga/ships/{faction}/{ship_class}/{clean_entity}/{file_name}"
        
        elif asset_category in ['weapon_model', 'weapon_sound', 'weapon_audio']:
            return f"campaigns/wing_commander_saga/weapons/{clean_entity}/{file_name}"
        
        elif asset_category == 'texture':
            return f"common/materials/{file_name}"
        
        else:
            # Default to common directory
            type_dir = 'audio' if asset_category.endswith('_sound') or asset_category.endswith('_audio') else 'effects'
            return f"common/{type_dir}/{file_name}"
    
    def _determine_faction(self, entity_name: str) -> str:
        """Determine faction from entity name using hardcoded patterns"""
        name_lower = entity_name.lower()
        
        # Kilrathi patterns
        if any(pattern in name_lower for pattern in ['dralthi', 'salthi', 'gratha', 'jalthi', 'fralthi']):
            return 'kilrathi'
        
        # Terran by default
        return 'terran'
    
    def _determine_ship_class(self, entity_name: str) -> str:
        """Determine ship class from entity name using hardcoded patterns"""
        name_lower = entity_name.lower()
        
        # Capital ship patterns
        if any(pattern in name_lower for pattern in ['carrier', 'cruiser', 'destroyer', 'dreadnought', 'corvette']):
            return 'capital_ships'
        
        # Fighter by default
        return 'fighters'
    
    def apply_hardcoded_mappings(self, table_relationships: Dict[str, List[AssetRelationship]]) -> Dict[str, AssetMapping]:
        """
        Apply hardcoded asset mappings to enhance table-derived relationships.
        
        Args:
            table_relationships: Relationships extracted from table files
            
        Returns:
            Enhanced asset mappings with hardcoded relationships applied
        """
        logger.info("Applying hardcoded asset mappings")
        enhanced_mappings = {}
        
        for entity_name, relationships in table_relationships.items():
            # Create base asset mapping
            asset_mapping = AssetMapping(
                entity_name=entity_name,
                entity_type=self._determine_entity_type(relationships),
                related_assets=relationships.copy()
            )
            
            # Set primary asset (usually the first model)
            for rel in relationships:
                if rel.relationship_type == 'primary_model':
                    asset_mapping.primary_asset = rel
                    break
            
            # Apply campaign-specific overrides
            if 'hermes' in str(self.source_dir).lower():
                self._apply_campaign_overrides(asset_mapping, 'hermes')
            
            enhanced_mappings[entity_name] = asset_mapping
        
        return enhanced_mappings
    
    def _determine_entity_type(self, relationships: List[AssetRelationship]) -> str:
        """Determine entity type from its relationships"""
        if any(rel.relationship_type in ['fire_sound', 'weapon_effect'] for rel in relationships):
            return 'weapon'
        elif any(rel.relationship_type in ['primary_model', 'ship_texture'] for rel in relationships):
            return 'ship'
        else:
            return 'unknown'
    
    def _apply_campaign_overrides(self, asset_mapping: AssetMapping, campaign: str) -> None:
        """Apply campaign-specific asset path overrides"""
        overrides = self.hardcoded_mappings.CAMPAIGN_OVERRIDES.get(campaign, {})
        
        for rel in asset_mapping.related_assets:
            # Apply prefix overrides to target paths
            for override_type, prefix in overrides.items():
                if override_type in rel.relationship_type:
                    # Modify target path to include campaign prefix
                    path_parts = rel.target_path.split('/')
                    filename = path_parts[-1]
                    if not filename.startswith(prefix):
                        path_parts[-1] = f"{prefix}{filename}"
                        rel.target_path = '/'.join(path_parts)
    
    def generate_project_mapping(self) -> Dict[str, Any]:
        """
        Generate complete project mapping JSON combining table data and hardcoded mappings.
        
        Returns:
            Complete project mapping dictionary ready for JSON serialization
        """
        logger.info("Generating complete project mapping")
        
        # Find all table files
        table_files = list(self.source_dir.rglob('*.tbl'))
        logger.info(f"Found {len(table_files)} table files to process")
        
        # Extract relationships from table files
        table_relationships = self.analyze_table_relationships(table_files)
        
        # Apply hardcoded mappings
        asset_mappings = self.apply_hardcoded_mappings(table_relationships)
        
        # Generate final mapping structure
        project_mapping = {
            'metadata': {
                'generator': 'AssetRelationshipMapper',
                'version': '1.0',
                'source_dir': str(self.source_dir),
                'generated_date': None,  # Will be set by caller
                'total_entities': len(asset_mappings),
                'total_assets': sum(len(mapping.related_assets) for mapping in asset_mappings.values())
            },
            'target_structure': self.target_structure,
            'entity_mappings': {},
            'asset_index': {},
            'missing_assets': list(self.missing_assets),
            'statistics': {
                'ships': len([m for m in asset_mappings.values() if m.entity_type == 'ship']),
                'weapons': len([m for m in asset_mappings.values() if m.entity_type == 'weapon']),
                'total_relationships': sum(len(m.related_assets) for m in asset_mappings.values())
            }
        }
        
        # Convert asset mappings to serializable format
        for entity_name, mapping in asset_mappings.items():
            entity_data = {
                'entity_type': mapping.entity_type,
                'primary_asset': self._serialize_relationship(mapping.primary_asset) if mapping.primary_asset else None,
                'related_assets': [self._serialize_relationship(rel) for rel in mapping.related_assets],
                'metadata': mapping.metadata
            }
            project_mapping['entity_mappings'][entity_name] = entity_data
            
            # Build asset index for quick lookups
            for rel in mapping.related_assets:
                source_path = rel.source_path
                if source_path not in project_mapping['asset_index']:
                    project_mapping['asset_index'][source_path] = []
                
                project_mapping['asset_index'][source_path].append({
                    'entity': entity_name,
                    'target_path': rel.target_path,
                    'relationship_type': rel.relationship_type
                })
        
        logger.info(f"Generated mapping for {len(asset_mappings)} entities with {project_mapping['metadata']['total_assets']} total assets")
        return project_mapping
    
    def _serialize_relationship(self, relationship: AssetRelationship) -> Dict[str, Any]:
        """Convert AssetRelationship to serializable dictionary"""
        return {
            'source_path': relationship.source_path,
            'target_path': relationship.target_path,
            'asset_type': relationship.asset_type,
            'parent_entity': relationship.parent_entity,
            'relationship_type': relationship.relationship_type,
            'required': relationship.required
        }
    
    def save_mapping_json(self, project_mapping: Dict[str, Any], output_path: Path) -> bool:
        """
        Save project mapping to JSON file.
        
        Args:
            project_mapping: Complete project mapping dictionary
            output_path: Path where to save the JSON file
            
        Returns:
            True if saved successfully, False otherwise
        """
        try:
            # Add generation timestamp
            from datetime import datetime
            project_mapping['metadata']['generated_date'] = datetime.now().isoformat()
            
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(project_mapping, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Project mapping saved to: {output_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save project mapping to {output_path}: {e}")
            return False

def main():
    """Command-line interface for asset relationship mapping"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate asset relationship mapping from WCS table files')
    parser.add_argument('--source', type=Path, required=True, help='WCS source directory')
    parser.add_argument('--output', type=Path, required=True, help='Output JSON file path')
    parser.add_argument('--target-structure', type=Path, help='Target structure JSON file')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')
    
    # Load target structure
    target_structure = {}
    if args.target_structure and args.target_structure.exists():
        with open(args.target_structure) as f:
            target_structure = json.load(f)
    
    try:
        # Create mapper and generate mapping
        mapper = AssetRelationshipMapper(args.source, target_structure)
        project_mapping = mapper.generate_project_mapping()
        
        # Save mapping
        success = mapper.save_mapping_json(project_mapping, args.output)
        
        if success:
            print(f"Asset mapping generated successfully!")
            print(f"Entities: {project_mapping['metadata']['total_entities']}")
            print(f"Assets: {project_mapping['metadata']['total_assets']}")
            print(f"Ships: {project_mapping['statistics']['ships']}")
            print(f"Weapons: {project_mapping['statistics']['weapons']}")
        else:
            print("Failed to generate asset mapping")
            return 1
    
    except Exception as e:
        logger.error(f"Asset mapping generation failed: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main())