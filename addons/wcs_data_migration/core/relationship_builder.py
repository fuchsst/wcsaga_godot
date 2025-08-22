#!/usr/bin/env python3
"""
Relationship Builder - Comprehensive Asset Relationship Construction

This module builds complete asset relationship maps by combining table analysis,
file discovery, and dependency resolution to create comprehensive mappings
for the WCS to Godot conversion pipeline.

Author: Dev (GDScript Developer)  
Date: June 10, 2025
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import logging
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set

from data_structures import AssetMapping, AssetRelationship
from table_converters.base_table_converter import ParseState
from table_converters.sounds_table_converter import SoundsTableConverter

from .asset_discovery import AssetDiscoveryEngine
from .entity_classifier import EntityClassifier, EntityType, TableType
from .path_resolver import TargetPathResolver

logger = logging.getLogger(__name__)

@dataclass
class TableParsingContext:
    """Context information for table parsing"""
    table_type: TableType
    current_section: Optional[str] = None
    entity_count: int = 0
    parsing_errors: List[str] = field(default_factory=list)

class RelationshipBuilder:
    """
    Builds comprehensive asset relationships by combining multiple data sources
    and analysis methods to create complete dependency maps.
    """
    
    def __init__(self, source_dir: Path, target_structure: Dict):
        """
        Initialize the relationship builder.
        
        Args:
            source_dir: WCS source directory containing Hermes campaign
            target_structure: Target directory structure configuration
        """
        self.source_dir = Path(source_dir)
        self.target_structure = target_structure
        
        # Initialize specialized components
        self.classifier = EntityClassifier(source_dir)
        self.discovery_engine = AssetDiscoveryEngine(source_dir)
        self.path_resolver = TargetPathResolver(target_structure)
        
        # Relationship storage
        self.relationships: Dict[str, List[AssetRelationship]] = {}
        self.discovered_assets: Set[str] = set()
        self.missing_assets: Set[str] = set()
        
        # Parsing context
        self.table_contexts: Dict[str, TableParsingContext] = {}
    
    def build_relationships_from_tables(self, table_files: List[Path]) -> Dict[str, List[AssetRelationship]]:
        """
        Build asset relationships from WCS table files.
        
        Args:
            table_files: List of .tbl files to analyze
            
        Returns:
            Dictionary mapping entity names to their asset relationships
        """
        logger.info(f"Building relationships from {len(table_files)} table files")
        
        all_relationships = {}
        
        for table_file in table_files:
            try:
                logger.info(f"Processing table file: {table_file}")
                table_type = self.classifier.determine_table_type(table_file)
                if table_type == TableType.UNKNOWN:
                    logger.warning(f"Unknown table type for file: {table_file.name}")
                    continue
                
                logger.info(f"Processing {table_type.value} table: {table_file.name}")
                
                # Initialize parsing context
                context = TableParsingContext(table_type=table_type)
                self.table_contexts[str(table_file)] = context
                
                # Parse based on table type
                if table_type == TableType.SHIPS:
                    relationships = self._parse_ships_table(table_file, context)
                elif table_type in [TableType.WEAPONS, TableType.WEAPON_EXPL]:
                    relationships = self._parse_weapons_table(table_file, context)
                elif table_type == TableType.FIREBALL:
                    relationships = self._parse_fireball_table(table_file, context)
                elif table_type == TableType.ASTEROID:
                    relationships = self._parse_asteroid_table(table_file, context)
                elif table_type == TableType.SOUNDS:
                    converter = SoundsTableConverter()
                    with open(table_file, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    parse_state = ParseState(content.splitlines())
                    sound_entries = converter.parse_table(parse_state)
                    
                    relationships = {}
                    for entry in sound_entries:
                        sound_rel = AssetRelationship(
                            source_path=entry['filename'],
                            target_path="",
                            asset_type='audio',
                            parent_entity='sound',
                            relationship_type='sound_file',
                            required=True
                        )
                        relationships[entry['name']] = [sound_rel]
                else:
                    # Generic table parsing for other types
                    relationships = self._parse_generic_table(table_file, context)
                
                all_relationships.update(relationships)
                context.entity_count = len(relationships)
                logger.info(f"Found {len(relationships)} relationships in {table_file.name}")
                
            except Exception as e:
                logger.error(f"Failed to process table file {table_file}: {e}")
                continue
        
        logger.info(f"Built relationships for {len(all_relationships)} entities")
        self.relationships = all_relationships
        return self.relationships
    
    def build_relationships_from_missions(self, mission_files: List[Path]) -> Dict[str, List[AssetRelationship]]:
        """
        Build asset relationships from FS2 mission files.
        
        Args:
            mission_files: List of .fs2 mission files to analyze
            
        Returns:
            Dictionary mapping mission names to their asset relationships
        """
        logger.info(f"Building relationships from {len(mission_files)} mission files")
        
        mission_relationships = {}
        
        for mission_file in mission_files:
            try:
                relationships = self._parse_mission_file(mission_file)
                if relationships:
                    mission_name = mission_file.stem
                    mission_relationships[mission_name] = relationships
                    
            except Exception as e:
                logger.error(f"Failed to process mission file {mission_file}: {e}")
                continue
        
        return mission_relationships
    
    def build_relationships_from_campaigns(self, campaign_files: List[Path]) -> Dict[str, List[AssetRelationship]]:
        """
        Build asset relationships from FC2 campaign files.
        
        Args:
            campaign_files: List of .fc2 campaign files to analyze
            
        Returns:
            Dictionary mapping campaign names to their asset relationships
        """
        logger.info(f"Building relationships from {len(campaign_files)} campaign files")
        
        campaign_relationships = {}
        
        for campaign_file in campaign_files:
            try:
                relationships = self._parse_campaign_file(campaign_file)
                if relationships:
                    campaign_name = campaign_file.stem
                    campaign_relationships[campaign_name] = relationships
                    
            except Exception as e:
                logger.error(f"Failed to process campaign file {campaign_file}: {e}")
                continue
        
        return campaign_relationships
    
    def enhance_with_discovery(self, entity_relationships: Dict[str, List[AssetRelationship]]) -> Dict[str, AssetMapping]:
        """
        Enhance table-derived relationships with comprehensive asset discovery.
        
        Args:
            entity_relationships: Basic relationships from table parsing
            
        Returns:
            Enhanced asset mappings with discovered relationships
        """
        logger.info("Enhancing relationships with asset discovery")
        
        enhanced_mappings = {}
        
        for entity_name, base_relationships in entity_relationships.items():
            # Determine entity type from relationships or classify
            entity_type = self._determine_entity_type_from_relationships(base_relationships, entity_name)
            
            # Find primary asset (usually the first model)
            primary_asset = self._find_primary_asset(base_relationships)
            
            # Discover additional assets
            primary_model_path = primary_asset.source_path if primary_asset else None
            discovered_assets = self.discovery_engine.discover_entity_assets(
                entity_name, entity_type.value, primary_model_path
            )
            
            # Resolve target paths for all assets
            all_relationships = base_relationships + discovered_assets
            for relationship in all_relationships:
                if not relationship.target_path:  # Only resolve if not already set
                    relationship.target_path = self.path_resolver.resolve_semantic_faction_path(
                        entity_name, entity_type, relationship.asset_type,
                        relationship.source_path, relationship.relationship_type
                    )
            
            # Create scene relationship for complete entities
            scene_relationship = self._create_scene_relationship(entity_name, entity_type)
            if scene_relationship:
                all_relationships.append(scene_relationship)
            
            # Create enhanced mapping
            enhanced_mappings[entity_name] = AssetMapping(
                entity_name=entity_name,
                entity_type=entity_type.value,
                primary_asset=primary_asset,
                related_assets=[rel for rel in all_relationships if rel != primary_asset],
                metadata={
                    'discovered_assets': len(discovered_assets),
                    'table_derived': len(base_relationships),
                    'faction': self.classifier.get_entity_faction(entity_name),
                    'ship_class': self.classifier.get_ship_class(entity_name) if entity_type == EntityType.SHIP else None
                }
            )
        
        return enhanced_mappings
    
    def _parse_ships_table(self, ships_table: Path, context: TableParsingContext) -> Dict[str, List[AssetRelationship]]:
        """Parse ships.tbl with enhanced entity classification"""
        relationships = {}
        
        try:
            with open(ships_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # WCS ships.tbl structure patterns
            ship_pattern = r'\\$Name:\\s+([^\\r\\n]+)'
            pof_pattern = r'\\$POF\\s+file:\\s+([^\\r\\n]+)'
            texture_pattern = r'\\$Texture\\s+Replace:\\s*([^\\r\\n]+)'
            
            current_ship = None
            in_ship_section = False
            
            for line_num, line in enumerate(content.split('\\n'), 1):
                line = line.strip()
                
                # Skip comments and empty lines
                if not line or line.startswith(';') or line.startswith('#'):
                    continue
                
                # Track sections
                if '#Ship Classes' in line:
                    in_ship_section = True
                    context.current_section = 'Ship Classes'
                    continue
                elif line.startswith('#') and 'Ship Classes' not in line:
                    in_ship_section = False
                    context.current_section = line
                    continue
                
                if not in_ship_section:
                    continue
                
                # Parse ship name
                ship_match = re.match(ship_pattern, line)
                if ship_match:
                    ship_name = ship_match.group(1).strip()
                    
                    if not ship_name or ship_name.isdigit() or len(ship_name) < 2:
                        logger.warning(f"Skipping invalid ship name '{ship_name}' in {ships_table.name} at line {line_num}")
                        current_ship = None
                        continue

                    # Classify entity to determine if it's actually a ship or weapon
                    entity_type = self.classifier.classify_entity(
                        ship_name, TableType.SHIPS, f"{ships_table.name}:{line_num}"
                    )
                    
                    # Only process actual ships, skip weapons
                    if entity_type == EntityType.SHIP:
                        current_ship = ship_name
                        relationships[current_ship] = []
                    else:
                        current_ship = None  # Skip weapons found in ships.tbl
                    continue
                
                if not current_ship:
                    continue
                
                # Parse POF model file
                pof_match = re.match(pof_pattern, line)
                if pof_match:
                    pof_file = pof_match.group(1).strip()
                    
                    # Verify the POF file exists
                    actual_pof_path = self.source_dir / "hermes_models" / pof_file
                    if actual_pof_path.exists():
                        model_rel = AssetRelationship(
                            source_path=f"hermes_models/{pof_file}",
                            target_path="",  # Will be resolved later
                            asset_type='model',
                            parent_entity='ship',
                            relationship_type='primary_model',
                            required=True
                        )
                        relationships[current_ship].append(model_rel)
                    else:
                        logger.warning(f"POF file not found: {actual_pof_path}")
                        context.parsing_errors.append(f"Missing POF: {pof_file}")
                
                # Parse texture replacements
                texture_match = re.match(texture_pattern, line)
                if texture_match:
                    texture_spec = texture_match.group(1).strip()
                    texture_rel = self._parse_texture_replacement(current_ship, texture_spec)
                    if texture_rel:
                        relationships[current_ship].append(texture_rel)
        
        except Exception as e:
            logger.error(f"Failed to parse ships table {ships_table}: {e}")
            context.parsing_errors.append(f"Parse error: {e}")
        
        return relationships
    
    def _parse_weapons_table(self, weapons_table: Path, context: TableParsingContext) -> Dict[str, List[AssetRelationship]]:
        """Parse weapons.tbl and weapon_expl.tbl"""
        relationships = {}
        
        try:
            with open(weapons_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # WCS weapon patterns
            weapon_pattern = r'\\$Name:\\s*@?([^\\r\\n]+)'
            model_pattern = r'\\$Model\\s+File:\\s*([^\\r\\n]+)'
            sound_pattern = r'\\$LaunchSnd:\\s*([^\\r\\n]+)'
            
            current_weapon = None
            in_primary_section = False
            in_secondary_section = False
            
            for line in content.split('\\n'):
                line = line.strip()
                
                # Track sections
                if '#Primary Weapons' in line:
                    in_primary_section = True
                    in_secondary_section = False
                    context.current_section = 'Primary Weapons'
                    continue
                elif '#Secondary Weapons' in line:
                    in_primary_section = False
                    in_secondary_section = True
                    context.current_section = 'Secondary Weapons'
                    continue
                elif line.startswith('#'):
                    in_primary_section = False
                    in_secondary_section = False
                    context.current_section = line
                    continue
                
                if not (in_primary_section or in_secondary_section):
                    continue
                
                # Parse weapon name
                weapon_match = re.match(weapon_pattern, line)
                if weapon_match:
                    weapon_name = weapon_match.group(1).strip()

                    if not weapon_name or weapon_name.isdigit() or len(weapon_name) < 2:
                        logger.warning(f"Skipping invalid weapon name '{weapon_name}' in {weapons_table.name}")
                        current_weapon = None
                        continue

                    if not weapon_name.startswith('@'):  # Skip internal references
                        current_weapon = weapon_name
                        relationships[current_weapon] = []
                    continue
                
                if not current_weapon:
                    continue
                
                # Parse weapon model
                model_match = re.match(model_pattern, line)
                if model_match:
                    model_file = model_match.group(1).strip()
                    if model_file.lower() != 'none':
                        model_rel = AssetRelationship(
                            source_path=f"hermes_models/{model_file}",
                            target_path="",  # Will be resolved later
                            asset_type='model',
                            parent_entity='weapon',
                            relationship_type='primary_model',
                            required=True
                        )
                        relationships[current_weapon].append(model_rel)
                
                # Parse weapon sounds
                sound_match = re.match(sound_pattern, line)
                if sound_match:
                    sound_id = sound_match.group(1).strip()
                    actual_sound_file = self._find_actual_sound_file(sound_id)
                    if actual_sound_file:
                        sound_rel = AssetRelationship(
                            source_path=actual_sound_file,
                            target_path="",  # Will be resolved later
                            asset_type='audio',
                            parent_entity='weapon',
                            relationship_type='fire_sound',
                            required=False
                        )
                        relationships[current_weapon].append(sound_rel)
        
        except Exception as e:
            logger.error(f"Failed to parse weapons table {weapons_table}: {e}")
            context.parsing_errors.append(f"Parse error: {e}")
        
        return relationships
    
    def _parse_mission_file(self, mission_file: Path) -> List[AssetRelationship]:
        """Parse FS2 mission file for asset references"""
        relationships = []
        
        try:
            with open(mission_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            mission_name = mission_file.stem
            
            # Parse common FS2 mission asset references
            asset_patterns = {
                r'\\+AVI Name:\\s*([^\\r\\n]+)': ('video', 'cutscene_video'),
                r'\\+Wave Name:\\s*([^\\r\\n]+)': ('audio', 'mission_audio'),
                r'\\+Music:\\s*([^\\r\\n]+)': ('audio', 'background_music'),
                r'\\+Skybox Model:\\s*([^\\r\\n]+)': ('model', 'skybox_model'),
                r'\\+Texture:\\s*([^\\r\\n]+)': ('texture', 'mission_texture'),
                r'\\+Background\\s+bitmap:\\s*([^\\r\\n]+)': ('texture', 'background_image'),
                r'\\+Sun\\s+bitmap:\\s*([^\\r\\n]+)': ('texture', 'sun_texture'),
            }
            
            for pattern, (asset_type, relationship_type) in asset_patterns.items():
                matches = re.findall(pattern, content, re.IGNORECASE)
                for match in matches:
                    asset_name = match.strip()
                    if asset_name and asset_name.lower() != 'none':
                        # Try to find the actual file
                        actual_path = self._find_mission_asset_file(asset_name, asset_type)
                        if actual_path:
                            relationships.append(AssetRelationship(
                                source_path=actual_path,
                                target_path="",  # Will be resolved later
                                asset_type=asset_type,
                                parent_entity=mission_name,
                                relationship_type=relationship_type,
                                required=False
                            ))
            
            # Parse ship/weapon references in mission
            ship_pattern = r'\\$Name:\\s*([^\\r\\n]+)'
            ship_matches = re.findall(ship_pattern, content)
            for ship_name in ship_matches:
                ship_name = ship_name.strip()
                if ship_name:
                    relationships.append(AssetRelationship(
                        source_path="",  # Reference only
                        target_path="",
                        asset_type='ship_reference',
                        parent_entity=mission_name,
                        relationship_type='mission_ship',
                        required=False
                    ))
        
        except Exception as e:
            logger.debug(f"Could not parse mission file {mission_file}: {e}")
        
        return relationships
    
    def _parse_campaign_file(self, campaign_file: Path) -> List[AssetRelationship]:
        """Parse FC2 campaign file for asset references"""
        relationships = []
        
        try:
            with open(campaign_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            campaign_name = campaign_file.stem
            
            # Parse FC2 campaign asset references
            asset_patterns = {
                r'\\+Intro\\s+Movie:\\s*([^\\r\\n]+)': ('video', 'intro_video'),
                r'\\+Briefing\\s+Audio:\\s*([^\\r\\n]+)': ('audio', 'briefing_audio'),
                r'\\+Mission\\s+File:\\s*([^\\r\\n]+)': ('mission', 'campaign_mission'),
                r'\\+Fiction:\\s*([^\\r\\n]+)': ('text', 'fiction_file'),
                r'\\+Mainhall:\\s*([^\\r\\n]+)': ('scene', 'mainhall_reference'),
            }
            
            for pattern, (asset_type, relationship_type) in asset_patterns.items():
                matches = re.findall(pattern, content, re.IGNORECASE)
                for match in matches:
                    asset_name = match.strip()
                    if asset_name and asset_name.lower() != 'none':
                        actual_path = self._find_campaign_asset_file(asset_name, asset_type)
                        if actual_path:
                            relationships.append(AssetRelationship(
                                source_path=actual_path,
                                target_path="",  # Will be resolved later
                                asset_type=asset_type,
                                parent_entity=campaign_name,
                                relationship_type=relationship_type,
                                required=False
                            ))
        
        except Exception as e:
            logger.debug(f"Could not parse campaign file {campaign_file}: {e}")
        
        return relationships
    
    # Additional helper methods...
    
    def _find_actual_sound_file(self, sound_id: str) -> Optional[str]:
        """Find actual sound file by looking up sound ID in sounds.tbl"""
        sounds_table = self.source_dir / "hermes_core" / "sounds.tbl"
        if not sounds_table.exists():
            return None
        
        try:
            with open(sounds_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            pattern = rf'\\$Name:\\s*{re.escape(sound_id)}\\s+([^\\s,]+\\.wav)'
            match = re.search(pattern, content)
            
            if match:
                sound_filename = match.group(1)
                # Look for the actual sound file
                for sound_dir in ['hermes_sounds', 'sounds', 'hermes_core']:
                    potential_path = self.source_dir / sound_dir / sound_filename
                    if potential_path.exists():
                        return str(potential_path.relative_to(self.source_dir))
        
        except Exception as e:
            logger.debug(f"Failed to lookup sound ID {sound_id}: {e}")
        
        return None
    
    def _find_mission_asset_file(self, asset_name: str, asset_type: str) -> Optional[str]:
        """Find mission asset file in appropriate directories"""
        search_dirs = {
            'video': ['hermes_movies', 'movies'],
            'audio': ['hermes_sounds', 'sounds', 'hermes_core'],
            'texture': ['hermes_maps', 'maps', 'hermes_interface'],
            'model': ['hermes_models', 'models']
        }
        
        dirs_to_search = search_dirs.get(asset_type, ['hermes_core'])
        
        for search_dir in dirs_to_search:
            dir_path = self.source_dir / search_dir
            if dir_path.exists():
                # Try different file extensions
                extensions = ['.avi', '.wav', '.ogg', '.dds', '.pcx', '.pof', '.tga']
                for ext in extensions:
                    file_path = dir_path / f"{asset_name}{ext}"
                    if file_path.exists():
                        return str(file_path.relative_to(self.source_dir))
        
        return None
    
    def _find_campaign_asset_file(self, asset_name: str, asset_type: str) -> Optional[str]:
        """Find campaign asset file"""
        if asset_type == 'mission':
            mission_path = self.source_dir / "hermes_core" / f"{asset_name}.fs2"
            if mission_path.exists():
                return str(mission_path.relative_to(self.source_dir))
        elif asset_type == 'text':
            text_path = self.source_dir / "hermes_core" / f"{asset_name}.txt"
            if text_path.exists():
                return str(text_path.relative_to(self.source_dir))
        
        return self._find_mission_asset_file(asset_name, asset_type)
    
    def _parse_fireball_table(self, fireball_table: Path, context: TableParsingContext) -> Dict[str, List[AssetRelationship]]:
        """Parse fireball.tbl for explosion/effect definitions"""
        relationships = {}
        
        try:
            with open(fireball_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Parse fireball entries
            name_pattern = r'\$Name:\s*([^\r\n]+)'
            texture_pattern = r'\$Texture:\s*([^\r\n]+)'
            
            current_fireball = None
            
            for line_num, line in enumerate(content.split('\n'), 1):
                line = line.strip()
                if not line or line.startswith(';'):
                    continue
                
                name_match = re.match(name_pattern, line)
                if name_match:
                    fireball_name = name_match.group(1).strip()
                    if not fireball_name or fireball_name.isdigit():
                        logger.warning(f"Skipping invalid fireball name '{fireball_name}' in {fireball_table.name} at line {line_num}")
                        current_fireball = None
                        continue
                    current_fireball = fireball_name
                    relationships[current_fireball] = []
                    continue
                
                if not current_fireball:
                    continue
                
                texture_match = re.match(texture_pattern, line)
                if texture_match:
                    texture_name = texture_match.group(1).strip()
                    texture_rel = AssetRelationship(
                        source_path=f"hermes_maps/{texture_name}",
                        target_path="",
                        asset_type='texture',
                        parent_entity=current_fireball,
                        relationship_type='fireball_texture',
                        required=True
                    )
                    relationships[current_fireball].append(texture_rel)
        
        except Exception as e:
            logger.error(f"Failed to parse fireball table {fireball_table}: {e}")
            context.parsing_errors.append(f"Parse error: {e}")
        
        return relationships
    
    def _parse_asteroid_table(self, asteroid_table: Path, context: TableParsingContext) -> Dict[str, List[AssetRelationship]]:
        """Parse asteroid.tbl for asteroid/debris definitions"""
        relationships = {}
        
        try:
            with open(asteroid_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Parse asteroid entries
            name_pattern = r'\$Name:\s*([^\r\n]+)'
            model_pattern = r'\$Model\s+file:\s*([^\r\n]+)'
            
            current_asteroid = None
            
            for line_num, line in enumerate(content.split('\n'), 1):
                line = line.strip()
                if not line or line.startswith(';'):
                    continue
                
                name_match = re.match(name_pattern, line)
                if name_match:
                    asteroid_name = name_match.group(1).strip()
                    if not asteroid_name or asteroid_name.isdigit():
                        logger.warning(f"Skipping invalid asteroid name '{asteroid_name}' in {asteroid_table.name} at line {line_num}")
                        current_asteroid = None
                        continue
                    current_asteroid = asteroid_name
                    relationships[current_asteroid] = []
                    continue
                
                if not current_asteroid:
                    continue
                
                model_match = re.match(model_pattern, line)
                if model_match:
                    model_file = model_match.group(1).strip()
                    if model_file.lower() != 'none':
                        model_rel = AssetRelationship(
                            source_path=f"hermes_models/{model_file}",
                            target_path="",
                            asset_type='model',
                            parent_entity=current_asteroid,
                            relationship_type='primary_model',
                            required=True
                        )
                        relationships[current_asteroid].append(model_rel)
        
        except Exception as e:
            logger.error(f"Failed to parse asteroid table {asteroid_table}: {e}")
            context.parsing_errors.append(f"Parse error: {e}")
        
        return relationships
    
    def _parse_generic_table(self, table_file: Path, context: TableParsingContext) -> Dict[str, List[AssetRelationship]]:
        """Generic parser for other table types"""
        relationships = {}
        
        try:
            with open(table_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Basic name extraction for any table
            name_pattern = r'\$Name:\s*([^\r\n]+)'
            
            for line in content.split('\n'):
                line = line.strip()
                if not line or line.startswith(';'):
                    continue
                
                name_match = re.match(name_pattern, line)
                if name_match:
                    entity_name = name_match.group(1).strip()
                    relationships[entity_name] = []
        
        except Exception as e:
            logger.debug(f"Generic parsing failed for {table_file}: {e}")
        
        return relationships
    
    def _parse_texture_replacement(self, entity_name: str, texture_spec: str) -> Optional[AssetRelationship]:
        """Parse texture replacement specification"""
        try:
            parts = texture_spec.split()
            if len(parts) >= 1:
                texture_file = parts[-1]
                return AssetRelationship(
                    source_path=f"hermes_maps/{texture_file}",
                    target_path="",
                    asset_type='texture',
                    parent_entity=entity_name,
                    relationship_type='texture_replacement',
                    required=False
                )
        except Exception as e:
            logger.debug(f"Could not parse texture spec '{texture_spec}': {e}")
        
        return None
    
    def _determine_entity_type_from_relationships(self, relationships: List[AssetRelationship], entity_name: str) -> EntityType:
        """Determine entity type from its relationships"""
        
        # Check relationship types for clues
        for rel in relationships:
            if rel.relationship_type in ['fire_sound', 'weapon_effect']:
                return EntityType.WEAPON
            elif rel.relationship_type in ['primary_model'] and 'missile' in entity_name.lower():
                return EntityType.WEAPON
            elif rel.relationship_type == 'fireball_texture':
                return EntityType.EFFECT
        
        # Check asset types
        has_model = any(rel.asset_type == 'model' for rel in relationships)
        if has_model:
            # Use classifier to determine if it's ship or weapon
            return EntityType.SHIP if self.classifier.classify_entity(
                entity_name, TableType.SHIPS
            ) == EntityType.SHIP else EntityType.WEAPON
        
        return EntityType.UNKNOWN
    
    def _find_primary_asset(self, relationships: List[AssetRelationship]) -> Optional[AssetRelationship]:
        """Find the primary asset from a list of relationships"""
        for rel in relationships:
            if rel.relationship_type == 'primary_model':
                return rel
        
        # Fallback to first model asset
        for rel in relationships:
            if rel.asset_type == 'model':
                return rel
        
        return None
    
    def _create_scene_relationship(self, entity_name: str, entity_type: EntityType) -> Optional[AssetRelationship]:
        """Create scene file relationship for complete entities"""
        if entity_type not in [EntityType.SHIP, EntityType.WEAPON, EntityType.EFFECT]:
            return None
        
        scene_path = self.path_resolver.resolve_scene_path(entity_name, entity_type)
        
        return AssetRelationship(
            source_path="",  # Generated scene
            target_path=scene_path,
            asset_type='scene',
            parent_entity=entity_name,
            relationship_type='complete_scene',
            required=True
        )
