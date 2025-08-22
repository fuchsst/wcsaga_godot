#!/usr/bin/env python3
"""
Target Path Resolver - Enhanced Target Path Generation

This module generates proper target paths following the structure defined in
target/assets/CLAUDE.md, ensuring assets are organized correctly in the
Godot project structure.

Author: Dev (GDScript Developer)
Date: June 10, 2025
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import logging
import re
from pathlib import Path
from typing import Dict, Optional

from .entity_classifier import EntityClassifier, EntityType

logger = logging.getLogger(__name__)

class TargetPathResolver:
    """
    Generates clean target paths following the target/assets/CLAUDE.md structure
    with proper format conversion and organization.
    """
    
    def __init__(self, target_structure: Optional[Dict] = None, source_dir: Optional[Path] = None):
        """
        Initialize the target path resolver.
        
        Args:
            target_structure: Optional target directory structure configuration
            source_dir: Source directory for classifier initialization
        """
        self.target_structure = target_structure or {}
        
        # Initialize entity classifier for semantic organization
        if source_dir:
            self.entity_classifier = EntityClassifier(source_dir)
        else:
            self.entity_classifier = None
        
        # Format conversion mappings
        self.format_conversions = {
            '.dds': '.png',      # DirectDraw Surface → PNG
            '.pcx': '.png',      # PCX → PNG  
            '.tga': '.png',      # Targa → PNG
            '.tbl': '.tres',     # Table → Godot Resource
            '.fs2': '.tres',     # Mission → Godot Resource
            '.fc2': '.tres',     # Campaign → Godot Resource
            '.pof': '.glb',      # POF Model → GLB
            '.eff': '.tscn',     # Effects → SpriteSheet png + AnimatedSprite2D scene
            '.vf': '.tres',      # Font → Godot Font Resource
            '.frc': '.tres',     # Force Config → Godot Resource
            '.hcf': '.tres',     # HUD Config → Godot Resource  
            '.txt': '.tres',     # Text/Fiction → Godot Resource
            '.tbm': '.tres',     # Table Mod → Godot Resource
            # Audio files stay the same format
            '.wav': '.ogg',
            '.ogg': '.ogg',
        }
        
        # Special handling for animation files
        self.animation_conversions = {
            '.ani': '_spritesheet.png',  # Animation → sprite sheet
            '.eff': '.tscn'              # Effect definition → Godot resource
        }
    
    def resolve_scene_path(self, entity_name: str, entity_type: EntityType) -> str:
        """
        Generate scene file path for complete entities.
        
        Args:
            entity_name: Name of the entity
            entity_type: Type of the entity
            
        Returns:
            Target scene file path
        """
        clean_name = self._clean_entity_name(entity_name)
        
        if entity_type == EntityType.SHIP:
            faction = self._determine_faction(entity_name)
            ship_class = self._determine_ship_class(entity_name)
            return f"campaigns/wing_commander_saga/ships/{faction}/{ship_class}/{clean_name}.tscn"
        
        elif entity_type == EntityType.WEAPON:
            return f"campaigns/wing_commander_saga/weapons/{clean_name}.tscn"
        
        elif entity_type == EntityType.EFFECT:
            return f"campaigns/wing_commander_saga/effects/{clean_name}.tscn"
        
        elif entity_type == EntityType.INSTALLATION:
            return f"campaigns/wing_commander_saga/installations/{clean_name}.tscn"
        
        elif entity_type == EntityType.ASTEROID:
            return f"campaigns/wing_commander_saga/environment/asteroids/{clean_name}.tscn"
            
        elif entity_type == EntityType.DEBRIS:
            return f"campaigns/wing_commander_saga/environment/debris/{clean_name}.tscn"
            
        else:
            return f"scenes/misc/{clean_name}.tscn"
    
    def _convert_file_format(self, file_stem: str, file_ext: str) -> str:
        """Convert source file format to target format"""
        
        # Special handling for .ani files - they become sprite sheets
        if file_ext == '.ani':
            return f"{file_stem}_spritesheet.png"
        
        # Get target extension with conversion
        target_ext = self.format_conversions.get(file_ext, file_ext)
        return f"{file_stem}{target_ext}"
    
    def _clean_entity_name(self, entity_name: str) -> str:
        """Clean entity name for filesystem compatibility"""
        # Remove special characters and replace with underscores
        clean_name = re.sub(r'[^\w\-_]', '_', entity_name.lower())
        # Remove multiple consecutive underscores
        clean_name = re.sub(r'_+', '_', clean_name)
        # Remove leading/trailing underscores
        return clean_name.strip('_')
    
    def _determine_faction(self, entity_name: str) -> str:
        """Determine faction from entity name using WCS naming conventions"""
        name_lower = entity_name.lower()
        
        # WCS faction prefixes
        if any(prefix in name_lower for prefix in ['tcf_', 'confed', 'terran', 'tc_']):
            return 'terran'
        elif any(prefix in name_lower for prefix in ['kib_', 'kilrathi', 'kat', 'kim_']):
            return 'kilrathi'
        elif any(prefix in name_lower for prefix in ['bw_', 'border_world']):
            return 'border_worlds'
        
        # Ship name patterns
        kilrathi_patterns = ['dralthi', 'salthi', 'gratha', 'jalthi', 'fralthi', 
                           'paktahn', 'paw', 'fang', 'stalker', 'claw']
        if any(pattern in name_lower for pattern in kilrathi_patterns):
            return 'kilrathi'
        
        # Terran ship name patterns
        terran_patterns = ['arrow', 'hellcat', 'excalibur', 'rapier', 'ferret', 
                         'hornet', 'sabre', 'broadsword', 'thunderbolt']
        if any(pattern in name_lower for pattern in terran_patterns):
            return 'terran'
        
        # Default to terran for unknown
        return 'terran'
    
    def _determine_ship_class(self, entity_name: str) -> str:
        """Determine ship class from entity name using WCS patterns"""
        name_lower = entity_name.lower()
        
        # Capital ship patterns
        capital_patterns = ['carrier', 'cruiser', 'destroyer', 'dreadnought', 
                          'corvette', 'dreadnaught', 'bengal', 'tiger', 
                          'fralthi', 'ralari']
        if any(pattern in name_lower for pattern in capital_patterns):
            return 'capital_ships'
        
        # Transport patterns
        transport_patterns = ['transport', 'freighter', 'tanker', 'supply']
        if any(pattern in name_lower for pattern in transport_patterns):
            return 'transports'
        
        # Installation patterns
        installation_patterns = ['base', 'station', 'platform', 'starbase', 
                               'drydock', 'depot']
        if any(pattern in name_lower for pattern in installation_patterns):
            return 'installations'
        
        # Fighter by default
        return 'fighters'
    
    # DM-017: Enhanced Semantic Path Resolution Methods
    
    def resolve_semantic_faction_path(self, entity_name: str, entity_type: EntityType, 
                                    asset_type: str, source_file: str, 
                                    relationship_type: str = "primary") -> str:
        """
        Generate semantic faction-based target path following DM-017 organization.
        
        Args:
            entity_name: Name of the parent entity
            entity_type: Type of the parent entity  
            asset_type: Type of the asset (model, texture, audio, etc.)
            source_file: Original source file path
            relationship_type: Type of relationship (primary, texture, sound, etc.)
            
        Returns:
            Semantic target path following faction-based organization
        """
        if not self.entity_classifier:
            raise ValueError("Entity classifier not initialized. Provide a source directory.")
        
        # Detect faction and subcategory using enhanced classifier
        faction = self.entity_classifier.detect_faction(entity_name)
        subcategory = self.entity_classifier.classify_entity_subcategory(entity_name, faction)
        
        # Get file info and apply format conversion
        source_path = Path(source_file)
        target_filename = self._convert_file_format(source_path.stem, source_path.suffix.lower())
        
        # Clean entity name for filesystem
        clean_entity = self._clean_entity_name(entity_name)
        
        # Generate semantic paths based on asset type and faction
        if entity_type == EntityType.SHIP:
            return self._resolve_semantic_ship_path(clean_entity, faction, subcategory, 
                                                   asset_type, target_filename, relationship_type)
        
        elif entity_type == EntityType.WEAPON:
            return self._resolve_semantic_weapon_path(clean_entity, faction, 
                                                    asset_type, target_filename)
        
        elif entity_type == EntityType.SOUND and relationship_type in ['pilot_voice', 'control_tower']:
            return self._resolve_semantic_audio_path(clean_entity, source_file, 
                                                    target_filename, relationship_type)
        
        else:
            return f"campaigns/wing_commander_saga/misc/{target_filename}"
    
    def _resolve_semantic_ship_path(self, clean_entity: str, faction: str, subcategory: str,
                                  asset_type: str, target_filename: str, 
                                  relationship_type: str) -> str:
        """Resolve semantic ship paths with faction-based organization"""
        
        base_path = f"campaigns/wing_commander_saga/ships/{faction}/{subcategory}/{clean_entity}"
        
        if asset_type == 'model':
            return f"{base_path}/{clean_entity}.glb"
        
        elif asset_type == 'texture':
            material_type = self._detect_material_type(target_filename)
            return f"{base_path}/textures/{material_type}_{target_filename}"
        
        elif asset_type == 'audio':
            audio_category = self._classify_audio_type_from_filename(target_filename)
            if audio_category in ['engine_sounds', 'weapon_sounds']:
                return f"{base_path}/audio/{target_filename}"
            else:
                # Shared audio goes to common location
                return f"campaigns/wing_commander_saga/audio/sfx/{audio_category}/{target_filename}"
        
        elif asset_type == 'animation':
            return f"{base_path}/effects/{target_filename}"
        
        else:
            return f"{base_path}/misc/{target_filename}"
    
    def _resolve_semantic_weapon_path(self, clean_entity: str, faction: str,
                                    asset_type: str, target_filename: str) -> str:
        """Resolve semantic weapon paths with faction organization"""
        
        base_path = f"campaigns/wing_commander_saga/weapons/{faction}/{clean_entity}"
        
        if asset_type == 'model':
            return f"{base_path}/{clean_entity}.glb"
        
        elif asset_type == 'texture':
            material_type = self._detect_material_type(target_filename)
            return f"{base_path}/textures/{material_type}_{target_filename}"
        
        elif asset_type == 'audio':
            return f"{base_path}/audio/{target_filename}"
        
        elif asset_type == 'animation':
            return f"{base_path}/effects/{target_filename}"
        
        else:
            return f"{base_path}/misc/{target_filename}"
    
    def _resolve_semantic_audio_path(self, clean_entity: str, source_file: str,
                                   target_filename: str, audio_category: str) -> str:
        """Resolve semantic audio paths with mission-contextual organization"""
        
        if audio_category == 'pilot_voice':
            # Extract mission number for organization
            mission_num = self._extract_mission_number_from_filename(target_filename)
            if mission_num is not None:
                return f"campaigns/wing_commander_saga/audio/voice/mission_{mission_num:02d}/{target_filename}"
            else:
                return f"campaigns/wing_commander_saga/audio/voice/misc/{target_filename}"
        
        elif audio_category == 'control_tower':
            # Organize by location/ship
            location = self._extract_location_from_filename(target_filename)
            if location:
                return f"campaigns/wing_commander_saga/audio/voice/control/{location}/{target_filename}"
            else:
                return f"campaigns/wing_commander_saga/audio/voice/control/misc/{target_filename}"
        
        else:
            return f"campaigns/wing_commander_saga/audio/{audio_category}/{target_filename}"
    
    def _detect_material_type(self, filename: str) -> str:
        """Detect material type from filename"""
        name_lower = filename.lower()
        
        if any(suffix in name_lower for suffix in ['_normal', '_n', '_nrm', '_bump']):
            return 'normal'
        elif any(suffix in name_lower for suffix in ['_specular', '_spec', '_s', '_shine']):
            return 'specular'
        elif any(suffix in name_lower for suffix in ['_glow', '_g', '_emissive', '_emit']):
            return 'glow'
        else:
            return 'diffuse'
    
    def _classify_audio_type_from_filename(self, filename: str) -> str:
        """Classify audio type from filename"""
        name_lower = filename.lower()
        
        # Engine sounds
        if any(pattern in name_lower for pattern in ['engine', 'aburn', 'throttle', 'afterburner']):
            return 'engine_sounds'
        
        # Weapon sounds
        elif any(pattern in name_lower for pattern in ['missile', 'laser', 'ion', 'cannon', 'fire']):
            return 'weapon_sounds'
        
        # Shield sounds
        elif any(pattern in name_lower for pattern in ['shield', 'hull', 'damage']):
            return 'shield_sounds'
        
        # UI sounds
        elif any(pattern in name_lower for pattern in ['button', 'menu', 'alert', 'beep']):
            return 'ui_sounds'
        
        else:
            return 'misc'
    
    def _extract_mission_number_from_filename(self, filename: str) -> Optional[int]:
        """Extract mission number from pilot voice filename"""
        import re

        # Pattern: 01_greywolf_01.wav, 02_sandman_03.wav, etc.
        mission_pattern = re.compile(r'^(\d{2})_\w+_\d{2}\.')
        match = mission_pattern.match(filename)
        
        if match:
            return int(match.group(1))
        
        return None
    
    def _extract_location_from_filename(self, filename: str) -> Optional[str]:
        """Extract location/ship name from control tower audio filename"""
        name_lower = filename.lower()
        
        # Known locations from analysis
        locations = ['hermes', 'bradshaw', 'wellington', 'lexington']
        
        for location in locations:
            if location in name_lower:
                return location
        
        return None
