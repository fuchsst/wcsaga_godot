#!/usr/bin/env python3
"""
Asset Discovery Engine - Comprehensive Asset File Discovery

This module implements sophisticated file discovery algorithms that scan the
WCS Hermes campaign structure to find all related assets for each entity.

Author: Dev (GDScript Developer)
Date: June 10, 2025
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import logging
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from data_structures import AssetMapping, AssetRelationship

logger = logging.getLogger(__name__)

@dataclass
class DiscoveryPattern:
    """Represents a pattern for discovering related assets"""
    pattern: str
    asset_type: str
    relationship_type: str
    required: bool = False
    priority: int = 1

class AssetDiscoveryEngine:
    """
    Comprehensive asset discovery engine that finds all related assets
    for WCS entities using multiple discovery strategies.
    """
    
    def __init__(self, source_dir: Path):
        """
        Initialize the asset discovery engine.
        
        Args:
            source_dir: WCS source directory containing Hermes campaign
        """
        # Normalize path for WSL compatibility
        self.source_dir = Path(str(source_dir).replace('\\', '/'))
        
        # WCS Hermes directory structure
        self.asset_directories = {
            'models': self.source_dir / "hermes_models",
            'textures': self.source_dir / "hermes_maps", 
            'sounds': self.source_dir / "hermes_sounds",
            'animations': self.source_dir / "hermes_cbanims",
            'interface': self.source_dir / "hermes_interface",
            'core': self.source_dir / "hermes_core",
            'missions': self.source_dir / "hermes_core",  # Mission files are in core
        }
        
        # Enhanced faction patterns from campaign analysis
        self.faction_patterns = {
            'terran': {
                'fighters': ['tcf_'],
                'bombers': ['tcb_'],
                'ships': ['tcs_'],
                'missiles': ['tcm_'],
                'installations': ['tci_'],
                'general': ['tc_', 'confed_']
            },
            'kilrathi': {
                'fighters': ['kif_'],
                'bombers': ['kib_'],
                'ships': ['kis_'],
                'missiles': ['kim_'],
                'installations': ['kii_'],
                'general': ['ki_', 'kb_', 'kil_']
            },
            'pirate': {
                'fighters': ['prf_'],
                'ships': ['prs_'],
                'general': ['pr_']
            },
            'border_worlds': {
                'fighters': ['bwf_'],
                'ships': ['bws_'],
                'general': ['bw_']
            }
        }
        
        # Enhanced audio categorization patterns from sounds.tbl analysis
        self.audio_categories = {
            'pilot_voice': [
                '_greywolf_', '_kettle_', '_sandman_', '_phalanx_', '_little_john_',
                '_bandit_', '_angel_', '_hawk_', '_blade_', '_viper_'
            ],
            'control_tower': [
                '_control_', '_command_', 'hermes_control_', 'bradshaw_control_',
                'tower_', 'flight_control_'
            ],
            'engine_sounds': [
                'engine_', 'aburn_', 'throttle_', 'afterburner_', 'thrust_',
                'idle_', 'startup_', 'shutdown_'
            ],
            'weapon_sounds': [
                'missile_', 'laser_', 'ion_', 'cannon_', 'gun_', 'fire_',
                'launch_', 'impact_', 'hit_', 'beam_'
            ],
            'shield_sounds': [
                'shield_', 'hull_', 'armor_', 'damage_', 'impact_on_'
            ],
            'ui_sounds': [
                'button_', 'menu_', 'alert_', 'warning_', 'beep_', 'click_',
                'confirm_', 'cancel_', 'select_'
            ],
            'ambient_sounds': [
                'ambient_', 'background_', 'env_', 'atmosphere_'
            ],
            'explosion_sounds': [
                'explosion_', 'blast_', 'boom_', 'explode_', 'detonate_'
            ]
        }
        
        # Asset file extensions by type
        self.asset_extensions = {
            'model': ['.pof'],
            'texture': ['.dds', '.pcx', '.tga', '.png', '.jpg'],
            'audio': ['.wav', '.ogg'],
            'animation': ['.eff'],
            'mission': ['.fs2'],
            'campaign': ['.fc2'],
            'table': ['.tbl'],
            'font': ['.vf'],
            'config': ['.frc', '.hcf']
        }
        
        # Initialize discovery pattern cache
        self._discovery_cache: Dict[str, List[AssetRelationship]] = {}
        
        # Cache for material completeness analysis
        self._material_cache: Dict[str, Dict[str, List[str]]] = {}
        
        # Cache for mission audio analysis  
        self._mission_audio_cache: Dict[str, List[str]] = {}
    
    def discover_entity_assets(self, entity_name: str, entity_type: str, 
                             primary_model_path: Optional[str] = None) -> List[AssetRelationship]:
        """
        Discover all assets related to a specific entity.
        
        Args:
            entity_name: Name of the entity (ship, weapon, etc.)
            entity_type: Type of entity (ship, weapon, effect, etc.)
            primary_model_path: Path to primary model file if known
            
        Returns:
            List of discovered asset relationships
        """
        logger.debug(f"Discovering assets for {entity_type} '{entity_name}'")
        
        # Check cache first
        cache_key = f"{entity_type}:{entity_name}"
        if cache_key in self._discovery_cache:
            return self._discovery_cache[cache_key]
        
        relationships = []
        
        # Discover by entity type
        if entity_type == 'ship':
            relationships.extend(self._discover_ship_assets(entity_name, primary_model_path))
        elif entity_type == 'weapon':
            relationships.extend(self._discover_weapon_assets(entity_name, primary_model_path))
        elif entity_type == 'effect':
            relationships.extend(self._discover_effect_assets(entity_name))
        
        # Universal discovery for all entity types
        relationships.extend(self._discover_textures(entity_name, primary_model_path))
        relationships.extend(self._discover_sounds(entity_name))
        relationships.extend(self._discover_animations(entity_name))
        relationships.extend(self._discover_mission_references(entity_name))
        
        # Cache results
        self._discovery_cache[cache_key] = relationships
        
        logger.debug(f"Discovered {len(relationships)} assets for '{entity_name}'")
        return relationships
    
    def _discover_ship_assets(self, ship_name: str, model_path: Optional[str] = None) -> List[AssetRelationship]:
        """Discover assets specific to ships"""
        relationships = []
        
        # Ship-specific texture patterns
        ship_texture_patterns = [
            f"*{ship_name.lower()}*",
            f"*{ship_name.replace(' ', '_').lower()}*",
            f"tcf_{ship_name.lower()}*",  # Terran prefix
            f"kib_{ship_name.lower()}*",  # Kilrathi prefix
        ]
        
        if model_path:
            model_stem = Path(model_path).stem
            ship_texture_patterns.extend([
                f"{model_stem}*",
                f"{model_stem}_*",
                f"{model_stem}-*"
            ])
        
        # Find ship textures with material suffixes
        textures_dir = self.asset_directories['textures']
        if textures_dir.exists():
            for pattern in ship_texture_patterns:
                for texture_file in textures_dir.glob(pattern):
                    if texture_file.suffix.lower() in self.asset_extensions['texture']:
                        rel_type = self._determine_texture_relationship_type(texture_file.stem)
                        relationships.append(AssetRelationship(
                            source_path=str(texture_file.relative_to(self.source_dir)),
                            target_path="",  # Will be set by path resolver
                            asset_type='texture',
                            parent_entity=ship_name,
                            relationship_type=rel_type,
                            required=(rel_type == 'diffuse')
                        ))
        return relationships
    
    def _discover_weapon_assets(self, weapon_name: str, model_path: Optional[str] = None) -> List[AssetRelationship]:
        """Discover assets specific to weapons"""
        relationships = []
        
        # Weapon effect patterns
        weapon_effect_patterns = [
            f"*{weapon_name.lower()}*",
            f"*{weapon_name.replace(' ', '_').lower()}*",
            f"wpn_{weapon_name.lower()}*",
            f"missile_{weapon_name.lower()}*"
        ]
        
        # Find weapon effects in animations directory
        animations_dir = self.asset_directories['animations']
        if animations_dir.exists():
            for pattern in weapon_effect_patterns:
                for effect_file in animations_dir.glob(f"{pattern}.eff"):
                    relationships.extend(self._create_effect_relationships(effect_file, weapon_name))
        
        return relationships
    
    def _discover_effect_assets(self, effect_name: str) -> List[AssetRelationship]:
        """Discover assets for effect entities"""
        relationships = []
        
        animations_dir = self.asset_directories['animations']
        if animations_dir.exists():
            # Look for .eff file and associated frame sequences
            eff_pattern = f"*{effect_name.lower()}*"
            for eff_file in animations_dir.glob(f"{eff_pattern}.eff"):
                relationships.extend(self._create_effect_relationships(eff_file, effect_name))
        
        return relationships
    
    def _discover_textures(self, entity_name: str, model_path: Optional[str] = None) -> List[AssetRelationship]:
        """Discover textures related to any entity"""
        relationships = []
        
        textures_dir = self.asset_directories['textures']
        if not textures_dir.exists():
            return relationships
        
        # Generate search patterns
        search_patterns = [
            f"*{entity_name.lower()}*",
            f"*{entity_name.replace(' ', '_').lower()}*",
            f"*{entity_name.replace(' ', '-').lower()}*"
        ]
        
        if model_path:
            model_stem = Path(model_path).stem
            search_patterns.extend([
                f"{model_stem}*",
                f"{model_stem}_*", 
                f"{model_stem}-*"
            ])
        
        # Search for texture files
        for pattern in search_patterns:
            for texture_file in textures_dir.glob(pattern):
                if texture_file.suffix.lower() in self.asset_extensions['texture']:
                    rel_type = self._determine_texture_relationship_type(texture_file.stem)
                    relationships.append(AssetRelationship(
                        source_path=str(texture_file.relative_to(self.source_dir)),
                        target_path="",  # Will be set by path resolver
                        asset_type='texture',
                        parent_entity=entity_name,
                        relationship_type=rel_type,
                        required=(rel_type == 'diffuse')
                    ))
        
        return relationships
    
    def _discover_sounds(self, entity_name: str) -> List[AssetRelationship]:
        """Discover sound files related to entity with proper audio type classification"""
        relationships = []
        
        sounds_dir = self.asset_directories['sounds']
        if not sounds_dir.exists():
            return relationships
        
        # Sound search patterns with context
        sound_patterns = [
            (f"*{entity_name.lower()}*", "entity_sound"),
            (f"*{entity_name.replace(' ', '_').lower()}*", "entity_sound"),
            (f"wpn_{entity_name.lower()}*", "weapon_sound"),   # Weapon sounds
            (f"engine_{entity_name.lower()}*", "engine_sound"),  # Engine sounds
            (f"impact_{entity_name.lower()}*", "impact_sound"),   # Impact sounds
            (f"music_{entity_name.lower()}*", "music"),  # Music tracks
            (f"voice_{entity_name.lower()}*", "voice"),  # Voice lines
            (f"ui_{entity_name.lower()}*", "ui_sound"),  # UI feedback
        ]
        
        for pattern, base_type in sound_patterns:
            for sound_file in sounds_dir.glob(pattern):
                if sound_file.suffix.lower() in self.asset_extensions['audio']:
                    # Classify audio type from filename and context
                    audio_type = self._classify_audio_type(sound_file, base_type)
                    
                    relationships.append(AssetRelationship(
                        source_path=str(sound_file.relative_to(self.source_dir)),
                        target_path="",  # Will be set by path resolver
                        asset_type='audio',
                        parent_entity=entity_name,
                        relationship_type=audio_type,
                        required=False
                    ))
        
        return relationships
    
    def _discover_animations(self, entity_name: str) -> List[AssetRelationship]:
        """Discover animation effects related to entity"""
        relationships = []
        
        animations_dir = self.asset_directories['animations']
        if not animations_dir.exists():
            return relationships
        
        # Animation search patterns
        animation_patterns = [
            f"*{entity_name.lower()}*",
            f"*{entity_name.replace(' ', '_').lower()}*"
        ]
        
        for pattern in animation_patterns:
            for eff_file in animations_dir.glob(f"{pattern}.eff"):
                relationships.extend(self._create_effect_relationships(eff_file, entity_name))
        
        return relationships
    
    def _discover_mission_references(self, entity_name: str) -> List[AssetRelationship]:
        """Find mission files that reference this entity"""
        relationships = []
        
        missions_dir = self.asset_directories['missions']
        if not missions_dir.exists():
            return relationships
        
        # Search .fs2 mission files for entity references
        for mission_file in missions_dir.glob("*.fs2"):
            if self._mission_contains_entity(mission_file, entity_name):
                relationships.append(AssetRelationship(
                    source_path=str(mission_file.relative_to(self.source_dir)),
                    target_path="",  # Will be set by path resolver
                    asset_type='mission',
                    parent_entity=entity_name,
                    relationship_type='mission_reference',
                    required=False
                ))
        
        return relationships
    
    def _determine_texture_relationship_type(self, texture_stem: str) -> str:
        """Determine texture type from filename patterns"""
        stem_lower = texture_stem.lower()
        
        if any(suffix in stem_lower for suffix in ['_normal', '-normal']):
            return 'normal'
        elif any(suffix in stem_lower for suffix in ['_spec', '-spec', '_shine', '-shine']):
            return 'specular'
        elif any(suffix in stem_lower for suffix in ['_glow', '-glow', '_emit', '-emit']):
            return 'emission'
        elif any(suffix in stem_lower for suffix in ['_bump', '-bump']):
            return 'bump'
        else:
            return 'diffuse'
    
    def _create_effect_relationships(self, eff_file: Path, entity_name: str) -> List[AssetRelationship]:
        """Create relationships for .eff files and their frame sequences"""
        relationships = []
        rel_path = eff_file.relative_to(self.source_dir)
        file_stem = eff_file.stem
        
        # Main .eff file
        relationships.append(AssetRelationship(
            source_path=str(rel_path),
            target_path="",  # Will be set by path resolver
            asset_type='effect',
            parent_entity=entity_name,
            relationship_type='effect_definition',
            required=True
        ))
        
        # Find associated numbered .dds frame files
        parent_dir = eff_file.parent
        frame_files = list(parent_dir.glob(f"{file_stem}_*.dds"))
        
        if frame_files:
            # Sort frame files numerically
            frame_files.sort(key=lambda x: self._extract_frame_number(x.stem))
            
            # Add each frame file as a related asset
            for frame_file in frame_files:
                frame_rel_path = frame_file.relative_to(self.source_dir)
                relationships.append(AssetRelationship(
                    source_path=str(frame_rel_path),
                    target_path="",  # Will be set by path resolver
                    asset_type='effect_frame',
                    parent_entity=entity_name,
                    relationship_type='frame_texture',
                    required=False
                ))
        
        return relationships
    
    def _extract_frame_number(self, filename: str) -> int:
        """Extract frame number from animation frame filename"""
        match = re.search(r'_(\d+)$', filename)
        return int(match.group(1)) if match else 0
        
    def detect_faction(self, entity_name: str) -> str:
        """
        Detect faction from entity name using comprehensive pattern analysis.
        
        Args:
            entity_name: Name of the entity
            
        Returns:
            Faction name (terran, kilrathi, pirate, border_worlds, unknown)
        """
        entity_lower = entity_name.lower()
        
        # Check each faction's patterns
        for faction, categories in self.faction_patterns.items():
            for category, prefixes in categories.items():
                for prefix in prefixes:
                    if entity_lower.startswith(prefix):
                        logger.debug(f"Entity '{entity_name}' classified as {faction} ({category})")
                        return faction
        
        return 'unknown'
    
    def classify_entity_subcategory(self, entity_name: str, faction: str) -> str:
        """
        Classify entity subcategory within faction (fighters, bombers, ships, missiles).
        
        Args:
            entity_name: Name of the entity
            faction: Detected faction
            
        Returns:
            Subcategory string
        """
        if faction == 'unknown':
            return 'misc'
            
        entity_lower = entity_name.lower()
        faction_patterns = self.faction_patterns.get(faction, {})
        
        for category, prefixes in faction_patterns.items():
            if category == 'general':
                continue
            for prefix in prefixes:
                if entity_lower.startswith(prefix):
                    return category
        
        # Fallback to general classification based on naming patterns
        if any(pattern in entity_lower for pattern in ['fighter', 'f-', 'interceptor']):
            return 'fighters'
        elif any(pattern in entity_lower for pattern in ['bomber', 'b-', 'torpedo']):
            return 'bombers'
        elif any(pattern in entity_lower for pattern in ['missile', 'rocket', 'torpedo']):
            return 'missiles'
        elif any(pattern in entity_lower for pattern in ['destroyer', 'cruiser', 'carrier', 'corvette']):
            return 'capital_ships'
        else:
            return 'misc'
    
    def _classify_audio_type(self, sound_file: Path, base_type: str) -> str:
        """
        Enhanced audio classification based on filename patterns and WCS sounds.tbl analysis.
        
        Args:
            sound_file: Path to the sound file
            base_type: Base audio type
            
        Returns:
            Specific audio type classification
        """
        filename = sound_file.name.lower()
        
        # Check each audio category
        for category, patterns in self.audio_categories.items():
            for pattern in patterns:
                if pattern in filename:
                    logger.debug(f"Audio '{filename}' classified as {category}")
                    return category
        
        # Mission-specific voice pattern detection
        mission_voice_pattern = re.compile(r'\d{2}_\w+_\d{2}\.wav')
        if mission_voice_pattern.match(filename):
            return 'pilot_voice'
        
        # Music file patterns  
        music_patterns = ['music', 'theme', 'ambient', 'background', 'score', 'soundtrack']
        if any(pattern in filename for pattern in music_patterns):
            return 'music'
        
        # Default to base type
        return base_type
    
    def validate_material_completeness(self, base_texture: str) -> Dict[str, any]:
        """
        Validate that material maps form complete sets (diffuse, normal, specular, glow).
        
        Args:
            base_texture: Base texture name without suffix
            
        Returns:
            Material completeness report
        """
        if base_texture in self._material_cache:
            return self._material_cache[base_texture]
        
        textures_dir = self.asset_directories['textures']
        if not textures_dir.exists():
            return {'complete': False, 'missing': ['textures directory not found']}
        
        material_types = {
            'diffuse': ['', '_diffuse', '_d', '_col', '_color'],
            'normal': ['_normal', '_n', '_nrm', '_bump'],
            'specular': ['_specular', '_spec', '_s', '_shine'],
            'glow': ['_glow', '_g', '_emissive', '_emit']
        }
        
        found_materials = {}
        missing_materials = []
        
        for material_type, suffixes in material_types.items():
            found = False
            for suffix in suffixes:
                for ext in self.asset_extensions['texture']:
                    material_file = textures_dir / f"{base_texture}{suffix}{ext}"
                    if material_file.exists():
                        found_materials[material_type] = str(material_file.relative_to(self.source_dir))
                        found = True
                        break
                if found:
                    break
            
            if not found:
                missing_materials.append(material_type)
        
        completeness_report = {
            'complete': len(missing_materials) == 0,
            'found_materials': found_materials,
            'missing_materials': missing_materials,
            'completeness_score': len(found_materials) / len(material_types)
        }
        
        self._material_cache[base_texture] = completeness_report
        return completeness_report
    
    def discover_effect_sequences(self, effect_name: str) -> List[AssetRelationship]:
        """
        Discover complete effect sequences (e.g., fire_0000.dds through fire_0149.dds).
        
        Args:
            effect_name: Base effect name
            
        Returns:
            List of effect frame relationships
        """
        relationships = []
        textures_dir = self.asset_directories['textures']
        
        if not textures_dir.exists():
            return relationships
        
        # Look for numbered sequences
        sequence_pattern = re.compile(rf"{re.escape(effect_name)}_(\d{{4}})\.dds$", re.IGNORECASE)
        sequence_frames = []
        
        for texture_file in textures_dir.iterdir():
            if texture_file.is_file():
                match = sequence_pattern.match(texture_file.name)
                if match:
                    frame_number = int(match.group(1))
                    sequence_frames.append((frame_number, texture_file))
        
        # Sort by frame number
        sequence_frames.sort(key=lambda x: x[0])
        
        for frame_number, texture_file in sequence_frames:
            relationships.append(AssetRelationship(
                source_path=str(texture_file.relative_to(self.source_dir)),
                target_path="",  # Will be set by path resolver
                asset_type='texture',
                parent_entity=effect_name,
                relationship_type=f'effect_frame_{frame_number:04d}',
                required=True
            ))
        
        if sequence_frames:
            logger.debug(f"Found {len(sequence_frames)} effect frames for '{effect_name}'")
        
        return relationships
    
    def extract_mission_number(self, audio_filename: str) -> Optional[int]:
        """
        Extract mission number from pilot voice audio filename.
        
        Args:
            audio_filename: Voice audio filename
            
        Returns:
            Mission number or None if not found
        """
        # Pattern: 01_greywolf_01.wav, 02_sandman_03.wav, etc.
        mission_pattern = re.compile(r'^(\d{2})_\w+_\d{2}\.(wav|ogg)$')
        match = mission_pattern.match(audio_filename)
        
        if match:
            return int(match.group(1))
        
        return None
    
    def analyze_faction_distribution(self) -> Dict[str, Any]:
        """
        Analyze asset distribution across factions and detect sharing patterns.
        
        Returns:
            Faction distribution analysis report
        """
        faction_stats = {
            'terran': {'ships': 0, 'weapons': 0, 'assets': 0},
            'kilrathi': {'ships': 0, 'weapons': 0, 'assets': 0},
            'pirate': {'ships': 0, 'weapons': 0, 'assets': 0},
            'border_worlds': {'ships': 0, 'weapons': 0, 'assets': 0},
            'unknown': {'ships': 0, 'weapons': 0, 'assets': 0}
        }
        
        shared_assets = []
        
        # This would be called with entity data from the main mapper
        # For now, return the structure
        return {
            'faction_distribution': faction_stats,
            'shared_assets': shared_assets,
            'total_factions': len([f for f, stats in faction_stats.items() 
                                 if sum(stats.values()) > 0])
        }
    
    def _mission_contains_entity(self, mission_file: Path, entity_name: str) -> bool:
        """Check if mission file references the entity"""
        try:
            with open(mission_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Search for entity name in mission file
            # This is a simple text search - could be enhanced with proper FS2 parsing
            return entity_name.lower() in content.lower()
            
        except Exception as e:
            logger.debug(f"Could not search mission file {mission_file}: {e}")
            return False
