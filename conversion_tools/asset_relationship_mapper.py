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
            
            # Extract ship definitions using WCS-specific patterns
            ship_pattern = r'\$Name:\s*([^\r\n]+)'
            pof_pattern = r'\$POF\s+file:\s*([^\r\n]+)'  # Correct WCS format
            texture_pattern = r'\$Texture\s+Replace:\s*([^\r\n]+)'
            
            current_ship = None
            in_ship_section = False
            
            for line_num, line in enumerate(content.split('\n'), 1):
                line = line.strip()
                
                # Skip comments and empty lines
                if not line or line.startswith(';') or line.startswith('#'):
                    continue
                
                # Check if we're in the Ship Classes section
                if '#Ship Classes' in line:
                    in_ship_section = True
                    continue
                
                if not in_ship_section:
                    continue
                
                # Ship name
                ship_match = re.match(ship_pattern, line)
                if ship_match:
                    ship_name = ship_match.group(1).strip()
                    # Skip engine wash definitions and other non-ship entities
                    if not any(skip in ship_name.lower() for skip in ['default', 'none', 'engine']):
                        current_ship = ship_name
                        relationships[current_ship] = []
                    continue
                
                if not current_ship:
                    continue
                
                # POF Model file (correct WCS format)
                pof_match = re.match(pof_pattern, line)
                if pof_match:
                    pof_file = pof_match.group(1).strip()
                    
                    # Verify the POF file actually exists
                    actual_pof_path = self.source_dir / "hermes_models" / pof_file
                    if actual_pof_path.exists():
                        # Create primary model relationship
                        model_rel = AssetRelationship(
                            source_path=f"hermes_models/{pof_file}",
                            target_path=self._get_target_path('ship_model', current_ship, pof_file),
                            asset_type='model',
                            parent_entity=current_ship,
                            relationship_type='primary_model'
                        )
                        relationships[current_ship].append(model_rel)
                        
                        # Add related texture relationships using hardcoded patterns
                        texture_rels = self._generate_ship_texture_relationships(current_ship, pof_file)
                        relationships[current_ship].extend(texture_rels)
                    else:
                        logger.warning(f"POF file not found: {actual_pof_path}")
                
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
            
            # WCS weapon patterns
            weapon_pattern = r'\$Name:\s*@?([^\r\n]+)'  # @ prefix indicates weapon name
            model_pattern = r'\$Model\s+File:\s*([^\r\n]+)'
            sound_pattern = r'\$LaunchSnd:\s*([^\r\n]+)'
            
            current_weapon = None
            in_primary_section = False
            in_secondary_section = False
            
            for line in content.split('\n'):
                line = line.strip()
                
                # Skip comments and empty lines
                if not line or line.startswith(';'):
                    continue
                
                # Track weapon sections
                if '#Primary Weapons' in line:
                    in_primary_section = True
                    in_secondary_section = False
                    continue
                elif '#Secondary Weapons' in line:
                    in_primary_section = False
                    in_secondary_section = True
                    continue
                
                if not (in_primary_section or in_secondary_section):
                    continue
                
                weapon_match = re.match(weapon_pattern, line)
                if weapon_match:
                    weapon_name = weapon_match.group(1).strip()
                    # Skip if weapon name starts with @ (internal reference)
                    if not weapon_name.startswith('@'):
                        current_weapon = weapon_name
                        relationships[current_weapon] = []
                    continue
                
                if not current_weapon:
                    continue
                
                # Weapon model (most weapons use "none" for model)
                model_match = re.match(model_pattern, line)
                if model_match:
                    model_file = model_match.group(1).strip()
                    if model_file.lower() != 'none':
                        model_rel = AssetRelationship(
                            source_path=f"hermes_models/{model_file}",
                            target_path=self._get_target_path('weapon_model', current_weapon, model_file),
                            asset_type='model',
                            parent_entity=current_weapon,
                            relationship_type='primary_model'
                        )
                        relationships[current_weapon].append(model_rel)
                
                # Weapon sounds - only if we can find actual sound files
                sound_match = re.match(sound_pattern, line)
                if sound_match:
                    sound_id = sound_match.group(1).strip()
                    # Look for actual sound files that match this ID in sounds.tbl
                    actual_sound_file = self._find_actual_sound_file(sound_id)
                    if actual_sound_file:
                        sound_rel = AssetRelationship(
                            source_path=actual_sound_file,
                            target_path=self._get_target_path('weapon_sound', current_weapon, actual_sound_file),
                            asset_type='audio',
                            parent_entity=current_weapon,
                            relationship_type='fire_sound'
                        )
                        relationships[current_weapon].append(sound_rel)
        
        except Exception as e:
            logger.error(f"Failed to extract weapon relationships from {weapons_table}: {e}")
        
        return relationships
    
    def _generate_ship_texture_relationships(self, ship_name: str, model_file: str) -> List[AssetRelationship]:
        """Generate texture relationships for a ship using WCS naming patterns"""
        relationships = []
        base_name = Path(model_file).stem
        
        # WCS texture suffixes based on actual file analysis
        texture_suffixes = {
            'diffuse': '',           # base texture
            'normal': '-normal',     # normal map
            'shine': '-shine',       # specular/shine map
            'glow': '-glow',         # glow/emission map
            'bump': '-bump',         # bump map
        }
        
        # Check for actual texture files in hermes_maps directory
        maps_dir = self.source_dir / "hermes_maps"
        if maps_dir.exists():
            for suffix_type, suffix in texture_suffixes.items():
                # Try different numbering patterns (ship models can have multiple texture sets)
                for texture_variant in ['', '_2', '_a']:
                    texture_name = f"{base_name}{texture_variant}{suffix}"
                    
                    # Check for actual files with different extensions
                    for ext in ['.dds', '.pcx', '.tga']:
                        texture_file = f"{texture_name}{ext}"
                        actual_texture_path = maps_dir / texture_file
                        
                        if actual_texture_path.exists():
                            texture_rel = AssetRelationship(
                                source_path=f"hermes_maps/{texture_file}",
                                target_path=self._get_target_path('ship_texture', ship_name, texture_file),
                                asset_type='texture',
                                parent_entity=ship_name,
                                relationship_type=suffix_type,
                                required=(suffix_type == 'diffuse')  # Only base texture is required
                            )
                            relationships.append(texture_rel)
        
        return relationships
    
    def _find_actual_sound_file(self, sound_id: str) -> Optional[str]:
        """
        Find actual sound file by looking up sound ID in sounds.tbl.
        Only return paths to files that actually exist.
        """
        sounds_table = self.source_dir / "hermes_core" / "sounds.tbl"
        if not sounds_table.exists():
            return None
        
        try:
            with open(sounds_table, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Look for pattern: $Name: ID filename.wav
            pattern = rf'\$Name:\s*{re.escape(sound_id)}\s+([^\s,]+\.wav)'
            match = re.search(pattern, content)
            
            if match:
                sound_filename = match.group(1)
                # Only return if the actual sound file exists
                for sound_dir in ['hermes_sounds', 'sounds', 'hermes_core', '.']:
                    potential_path = self.source_dir / sound_dir / sound_filename
                    if potential_path.exists():
                        return str(potential_path.relative_to(self.source_dir))
                
                # Don't create fake sound mappings if file doesn't exist
                logger.debug(f"Sound file {sound_filename} (ID {sound_id}) referenced but not found")
        
        except Exception as e:
            logger.debug(f"Failed to lookup sound ID {sound_id}: {e}")
        
        return None
    
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
        Generate clean target path following the structure defined in target/assets/CLAUDE.md
        with proper format conversion (DDS→PNG, .tbl→.tres, etc.)
        """
        # Clean entity name - remove special characters that cause invalid paths
        clean_entity = re.sub(r'[^\w\-_]', '_', entity_name.lower())
        clean_entity = re.sub(r'_+', '_', clean_entity).strip('_')
        
        # Get file info and apply format conversion
        source_path = Path(source_file)
        file_stem = source_path.stem
        file_ext = source_path.suffix.lower()
        
        # Apply format conversion
        target_filename = self._convert_file_format(file_stem, file_ext)
        
        # Map to target directory structure based on asset category
        if asset_category in ['ship_model', 'ship_texture', 'ship_texture_diffuse', 'ship_texture_normal', 'ship_texture_shine', 'ship_texture_glow']:
            # Determine faction from entity name or default to common
            faction = self._determine_faction(entity_name)
            ship_class = self._determine_ship_class(entity_name)
            return f"campaigns/wing_commander_saga/ships/{faction}/{ship_class}/{clean_entity}/{target_filename}"
        
        elif asset_category in ['weapon_model', 'weapon_sound', 'weapon_audio']:
            return f"campaigns/wing_commander_saga/weapons/{clean_entity}/{target_filename}"
        
        elif asset_category == 'texture':
            return f"common/materials/{target_filename}"
        
        elif asset_category == 'animation_texture':
            return f"common/animations/{target_filename}"
        
        elif asset_category == 'ui_texture':
            return f"common/ui/{target_filename}"
        
        elif asset_category == 'audio':
            return f"common/audio/{target_filename}"
        
        elif asset_category == 'mission':
            return f"resources/missions/{target_filename}"
        
        elif asset_category == 'data':
            return f"resources/data/{target_filename}"
        
        elif asset_category == 'campaign':
            return f"resources/campaigns/{target_filename}"
        
        elif asset_category == 'font':
            return f"resources/fonts/{target_filename}"
        
        elif asset_category in ['config', 'hud_config', 'data_mod']:
            return f"resources/config/{target_filename}"
        
        elif asset_category == 'text':
            return f"resources/text/{target_filename}"
        
        else:
            # Default to common directory
            type_dir = 'audio' if asset_category.endswith('_sound') or asset_category.endswith('_audio') else 'effects'
            return f"common/{type_dir}/{target_filename}"
    
    def _convert_file_format(self, file_stem: str, file_ext: str) -> str:
        """
        Convert source file format to target format based on conversion rules
        """
        # Format conversion mappings
        format_conversions = {
            '.dds': '.png',      # DirectDraw Surface → PNG
            '.pcx': '.png',      # PCX → PNG  
            '.tga': '.png',      # Targa → PNG
            '.tbl': '.tres',     # Table → Godot Resource (based on wcs_asset_core)
            '.fs2': '.tres',     # Mission → Godot Resource
            '.fc2': '.tres',     # Campaign → Godot Resource
            '.pof': '.glb',      # POF Model → GLB
            '.eff': '.tres',     # Effects → Godot Resource
            '.vf': '.tres',      # Font → Godot Font Resource
            '.frc': '.tres',     # Force Config → Godot Resource
            '.hcf': '.tres',     # HUD Config → Godot Resource  
            '.txt': '.tres',     # Text/Fiction → Godot Resource
            '.tbm': '.tres',     # Table Mod → Godot Resource
            # Audio files stay the same format
            '.wav': '.wav',
            '.ogg': '.ogg',
        }
        
        # Special handling for .ani files - they become sprite sheets + AnimatedSprite2D
        if file_ext == '.ani':
            # Animation files generate both a sprite sheet and an AnimatedSprite2D resource
            # We'll return the sprite sheet path here, the AnimatedSprite2D will be handled separately
            return f"{file_stem}_spritesheet.png"
        
        # Get target extension with conversion
        target_ext = format_conversions.get(file_ext, file_ext)
        
        return f"{file_stem}{target_ext}"
    
    def _create_animation_relationships(self, ani_file: Path, entity_name: str) -> List[AssetRelationship]:
        """
        Create relationships for .ani files - both sprite sheet and AnimatedSprite2D resource
        """
        rel_path = ani_file.relative_to(self.source_dir)
        file_stem = ani_file.stem
        
        relationships = []
        
        # Sprite sheet (converted from .ani)
        sprite_sheet_rel = AssetRelationship(
            source_path=str(rel_path),
            target_path=self._get_target_path('animation', entity_name, str(ani_file)),
            asset_type='sprite_sheet',
            parent_entity=entity_name,
            relationship_type='sprite_sheet',
            required=True
        )
        relationships.append(sprite_sheet_rel)
        
        # AnimatedSprite2D resource 
        animated_sprite_rel = AssetRelationship(
            source_path=str(rel_path),
            target_path=f"resources/animations/{file_stem}_animated_sprite.tres",
            asset_type='animated_sprite_2d',
            parent_entity=entity_name,
            relationship_type='animated_sprite_resource',
            required=True
        )
        relationships.append(animated_sprite_rel)
        
        return relationships
    
    def _create_effect_relationships(self, eff_file: Path, entity_name: str) -> List[AssetRelationship]:
        """
        Create relationships for .eff files and their associated numbered .dds frame files
        """
        rel_path = eff_file.relative_to(self.source_dir)
        file_stem = eff_file.stem
        
        relationships = []
        
        # Main .eff file (converted to .tres effect resource)
        eff_rel = AssetRelationship(
            source_path=str(rel_path),
            target_path=self._get_target_path('effect', entity_name, str(eff_file)),
            asset_type='effect',
            parent_entity=entity_name,
            relationship_type='effect_definition',
            required=True
        )
        relationships.append(eff_rel)
        
        # Find associated numbered .dds frame files
        parent_dir = eff_file.parent
        frame_files = list(parent_dir.glob(f"{file_stem}_*.dds"))
        
        if frame_files:
            # Sort frame files numerically
            frame_files.sort(key=lambda x: int(x.stem.split('_')[-1]))
            
            # Create sprite sheet from all frames
            sprite_sheet_rel = AssetRelationship(
                source_path="",  # Generated from multiple frame files
                target_path=f"common/effects/{file_stem}_spritesheet.png",
                asset_type='sprite_sheet',
                parent_entity=entity_name,
                relationship_type='effect_frames',
                required=True
            )
            relationships.append(sprite_sheet_rel)
            
            # Add each frame file as a related asset
            for frame_file in frame_files[:10]:  # Limit to first 10 for brevity
                frame_rel_path = frame_file.relative_to(self.source_dir)
                frame_rel = AssetRelationship(
                    source_path=str(frame_rel_path),
                    target_path=f"common/effects/{frame_file.stem}.png",
                    asset_type='effect_frame',
                    parent_entity=entity_name,
                    relationship_type='frame_texture',
                    required=False
                )
                relationships.append(frame_rel)
                
        return relationships
    
    def _create_scene_relationship(self, entity_name: str, entity_type: str) -> Optional[AssetRelationship]:
        """
        Create scene file relationship for complete entities (ships, weapons, etc.)
        following wcs_asset_core architecture for combined asset scenes
        """
        if entity_type not in ['ship', 'weapon']:
            return None
        
        # Clean entity name for scene filename
        clean_name = re.sub(r'[^\w\-_]', '_', entity_name.lower())
        clean_name = re.sub(r'_+', '_', clean_name).strip('_')
        
        if entity_type == 'ship':
            # Ship scenes combine GLB model, textures, sounds, and ShipData resource
            faction = self._determine_faction(entity_name)
            ship_class = self._determine_ship_class(entity_name)
            scene_path = f"scenes/ships/{faction}/{ship_class}/{clean_name}.tscn"
        elif entity_type == 'weapon':
            # Weapon scenes combine effects, sounds, and WeaponData resource
            scene_path = f"scenes/weapons/{clean_name}.tscn"
        else:
            return None
        
        return AssetRelationship(
            source_path="",  # Scene is generated, not converted from source
            target_path=scene_path,
            asset_type='scene',
            parent_entity=entity_name,
            relationship_type='complete_scene',
            required=True
        )
    
    def _determine_faction(self, entity_name: str) -> str:
        """Determine faction from entity name using WCS naming conventions"""
        name_lower = entity_name.lower()
        
        # WCS faction prefixes from model analysis
        if any(prefix in name_lower for prefix in ['tcf_', 'confed', 'terran']):
            return 'terran'
        elif any(prefix in name_lower for prefix in ['kib_', 'kilrathi', 'kat']):
            return 'kilrathi'
        elif any(prefix in name_lower for prefix in ['bw_', 'border_world']):
            return 'border_worlds'
        
        # Kilrathi ship name patterns
        if any(pattern in name_lower for pattern in ['dralthi', 'salthi', 'gratha', 'jalthi', 'fralthi', 'paktahn']):
            return 'kilrathi'
        
        # Terran ship name patterns
        if any(pattern in name_lower for pattern in ['arrow', 'hellcat', 'excalibur', 'rapier', 'ferret', 'hornet']):
            return 'terran'
        
        # Default to terran
        return 'terran'
    
    def _determine_ship_class(self, entity_name: str) -> str:
        """Determine ship class from entity name using WCS patterns"""
        name_lower = entity_name.lower()
        
        # Capital ship patterns
        if any(pattern in name_lower for pattern in ['carrier', 'cruiser', 'destroyer', 'dreadnought', 'corvette', 'dreadnaught']):
            return 'capital_ships'
        elif any(pattern in name_lower for pattern in ['transport', 'freighter', 'tanker']):
            return 'transports'
        elif any(pattern in name_lower for pattern in ['base', 'station', 'platform', 'starbase', 'drydock']):
            return 'installations'
        
        # Fighter by default
        return 'fighters'
    
    def _determine_asset_type_from_file(self, file_path: Path) -> tuple[str, str]:
        """
        Determine asset type and entity name from file path using WCS naming patterns.
        Returns: (asset_type, entity_name)
        """
        file_name = file_path.name
        file_stem = file_path.stem
        file_ext = file_path.suffix.lower()
        parent_dir = file_path.parent.name
        
        # POF models - determine type from filename prefixes
        if file_ext == '.pof':
            if file_stem.startswith(('tcf_', 'kib_', 'bw_')):
                # Ship models
                ship_name = file_stem.replace('tcf_', '').replace('kib_', '').replace('bw_', '')
                ship_name = ship_name.replace('_', ' ').title()
                return 'ship_model', ship_name
            elif file_stem.startswith(('ast', 'debris')):
                # Asteroids and debris
                return 'environment_model', f"Asteroid_{file_stem}"
            elif file_stem.startswith('kb_'):
                # Kilrathi bases/installations
                installation_name = file_stem.replace('kb_', '').replace('_', ' ').title()
                return 'installation_model', installation_name
            elif file_stem.startswith('f_'):
                # Effects models
                return 'effect_model', f"Effect_{file_stem[2:]}"
            else:
                # Generic model
                return 'model', f"Model_{file_stem}"
        
        # Texture files - determine type from directory and suffixes
        elif file_ext in ['.dds', '.pcx', '.tga', '.png', '.jpg']:
            if parent_dir == 'hermes_maps':
                # Ship textures with material type suffixes
                if any(suffix in file_stem for suffix in ['-normal', '-shine', '-glow', '-bump']):
                    base_name = file_stem.split('-')[0]
                    material_type = file_stem.split('-')[1] if '-' in file_stem else 'diffuse'
                    
                    if base_name.startswith(('tcf_', 'kib_', 'bw_')):
                        ship_name = base_name.replace('tcf_', '').replace('kib_', '').replace('bw_', '')
                        ship_name = ship_name.replace('_', ' ').title()
                        return f'ship_texture_{material_type}', ship_name
                
                # Base texture without suffix
                if file_stem.startswith(('tcf_', 'kib_', 'bw_')):
                    ship_name = file_stem.replace('tcf_', '').replace('kib_', '').replace('bw_', '')
                    ship_name = ship_name.replace('_', ' ').title()
                    return 'ship_texture', ship_name
                
                return 'texture', f"Texture_{file_stem}"
            
            elif parent_dir == 'hermes_interface':
                # Interface textures
                return 'ui_texture', f"UI_{file_stem}"
            
            elif parent_dir == 'hermes_cbanims':
                # Animation frame textures
                return 'animation_texture', f"Animation_{file_stem}"
            
            else:
                return 'texture', f"Texture_{file_stem}"
        
        # Audio files
        elif file_ext in ['.wav', '.ogg']:
            return 'audio', f"Audio_{file_stem}"
        
        # Animation files - special handling for sprite sheets
        elif file_ext == '.ani':
            animation_name = file_stem.replace('_', ' ').title()
            return 'animation', animation_name
        
        # Effect files (.eff often has associated numbered .dds frame files)
        elif file_ext == '.eff':
            effect_name = file_stem.replace('_', ' ').title()
            return 'effect', effect_name
        
        # Mission files
        elif file_ext == '.fs2':
            mission_name = file_stem.replace('_', ' ').title()
            return 'mission', mission_name
        
        # Campaign files  
        elif file_ext == '.fc2':
            campaign_name = file_stem.replace('_', ' ').title()
            return 'campaign', campaign_name
        
        # Table files
        elif file_ext == '.tbl':
            table_type = file_stem.replace('_', ' ').title()
            return 'data', table_type
        
        # Table modification files
        elif file_ext == '.tbm':
            table_mod_type = file_stem.replace('_', ' ').title()
            return 'data_mod', table_mod_type
        
        # Font files
        elif file_ext == '.vf':
            font_name = file_stem.replace('font', 'Font ').title()
            return 'font', font_name
        
        # Force configuration files
        elif file_ext == '.frc':
            config_name = file_stem.replace('_', ' ').title()
            return 'config', config_name
        
        # HUD configuration files
        elif file_ext == '.hcf':
            hud_config_name = file_stem.replace('_', ' ').title()
            return 'hud_config', hud_config_name
        
        # Text/fiction files
        elif file_ext == '.txt':
            text_name = file_stem.replace('_', ' ').title()
            return 'text', text_name
        
        else:
            return 'other', f"Asset_{file_stem}"
    
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
            # Find primary asset (usually the first model)
            primary_asset = None
            for rel in relationships:
                if rel.relationship_type == 'primary_model':
                    primary_asset = rel
                    break
            
            # Create related assets list without the primary asset to avoid duplication
            related_assets = [rel for rel in relationships if rel != primary_asset]
            
            # Add scene generation for complete entities (ships, weapons, etc.)
            entity_type = self._determine_entity_type(relationships)
            scene_relationship = self._create_scene_relationship(entity_name, entity_type)
            if scene_relationship:
                related_assets.append(scene_relationship)
            
            # Create base asset mapping
            asset_mapping = AssetMapping(
                entity_name=entity_name,
                entity_type=entity_type,
                primary_asset=primary_asset,
                related_assets=related_assets
            )
            
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
    
    def _scan_and_map_all_source_files(self, existing_mappings: Dict[str, AssetMapping]) -> Dict[str, AssetMapping]:
        """
        Scan all actual source files and ensure they have mappings.
        Creates generic mappings for files not covered by table analysis.
        """
        logger.info("Scanning for unmapped source files...")
        
        # Get all currently mapped source paths
        mapped_sources = set()
        for mapping in existing_mappings.values():
            for rel in mapping.related_assets:
                mapped_sources.add(rel.source_path)
        
        # Scan all actual source files
        source_file_patterns = ['*.pof', '*.dds', '*.pcx', '*.tga', '*.png', '*.jpg', 
                               '*.wav', '*.ogg', '*.eff', '*.ani', '*.tbl', '*.fs2', '*.fc2',
                               '*.vf', '*.frc', '*.hcf', '*.txt', '*.tbm']
        
        unmapped_files = []
        for pattern in source_file_patterns:
            for file_path in self.source_dir.rglob(pattern):
                # Convert to relative path for comparison
                rel_path = file_path.relative_to(self.source_dir)
                if str(rel_path) not in mapped_sources:
                    unmapped_files.append(file_path)
        
        logger.info(f"Found {len(unmapped_files)} unmapped source files")
        
        # Create generic mappings for unmapped files
        updated_mappings = existing_mappings.copy()
        
        for file_path in unmapped_files:
            rel_path = file_path.relative_to(self.source_dir)
            
            # Use improved heuristics to determine asset type and entity name
            asset_type, entity_name = self._determine_asset_type_from_file(file_path)
            
            # Create asset relationship(s) for this file
            if asset_type == 'animation':
                # Special handling for animation files - create both sprite sheet and AnimatedSprite2D
                relationships = self._create_animation_relationships(file_path, entity_name)
            elif asset_type == 'effect':
                # Special handling for effect files - group with numbered .dds frame files
                relationships = self._create_effect_relationships(file_path, entity_name)
            else:
                # Single relationship for other file types using the new target path method
                relationships = [AssetRelationship(
                    source_path=str(rel_path),
                    target_path=self._get_target_path(asset_type, entity_name, str(file_path)),
                    asset_type=asset_type,
                    parent_entity=entity_name,
                    relationship_type='primary_asset',
                    required=True
                )]
            
            # Handle multiple relationships (e.g., for animations)
            for i, relationship in enumerate(relationships):
                if entity_name not in updated_mappings:
                    # First relationship becomes primary asset
                    updated_mappings[entity_name] = AssetMapping(
                        entity_name=entity_name,
                        entity_type=asset_type,
                        primary_asset=relationship if i == 0 else None,
                        related_assets=relationships[1:] if i == 0 else [relationship],
                        metadata={'source': 'file_scan', 'discovered': True}
                    )
                else:
                    # Add additional relationships to related_assets
                    existing_mapping = updated_mappings[entity_name]
                    if existing_mapping.primary_asset != relationship:
                        existing_mapping.related_assets.append(relationship)
        
        logger.info(f"Added mappings for {len(unmapped_files)} previously unmapped files")
        return updated_mappings
    
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
        
        # Scan for actual source files and ensure they're all mapped
        asset_mappings = self._scan_and_map_all_source_files(asset_mappings)
        
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