#!/usr/bin/env python3
"""
Entity Classifier - Enhanced Entity Type Classification

This module provides sophisticated entity classification logic that properly
distinguishes between ships, weapons, effects, and other WCS entities based on
table structure analysis and naming patterns.

Author: Dev (GDScript Developer)
Date: June 10, 2025
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import logging
import re
from enum import Enum
from pathlib import Path
from typing import Dict, Optional, Set, Tuple

logger = logging.getLogger(__name__)

class EntityType(Enum):
    """Enhanced entity type classification"""
    SHIP = "ship"
    WEAPON = "weapon"
    ARMOR = "armor"
    EFFECT = "effect"
    ASTEROID = "asteroid"
    DEBRIS = "debris"
    INSTALLATION = "installation"
    MISSION = "mission"
    CAMPAIGN = "campaign"
    SPECIES = "species"
    IFF = "iff"
    FIREBALL = "fireball"
    MUSIC = "music"
    SOUND = "sound"
    UI_ELEMENT = "ui_element"
    TABLE_MOD = "table_mod"
    ENVIRONMENT = "environment"
    MISC = "misc"
    UNKNOWN = "unknown"

class TableType(Enum):
    """WCS table file types"""
    SHIPS = "ships"
    WEAPONS = "weapons"
    ARMOR = "armor"
    SPECIES = "species"
    SPECIES_DEFS = "species_defs"
    IFF_DEFS = "iff_defs"
    FIREBALL = "fireball"
    ASTEROID = "asteroid"
    MUSIC = "music"
    SOUNDS = "sounds"
    LIGHTNING = "lightning"
    NEBULA = "nebula"
    STARS = "stars"
    AI = "ai"
    AI_PROFILES = "ai_profiles"
    AUTOPILOT = "autopilot"
    CREDITS = "credits"
    CUTSCENES = "cutscenes"
    FONTS = "fonts"
    HELP = "help"
    HUD_GAUGES = "hud_gauges"
    ICONS = "icons"
    LAUNCH_HELP = "launchhelp"
    MAIN_HALL = "mainhall"
    MEDALS = "medals"
    MENU = "menu"
    MESSAGES = "messages"
    MFLASH = "mflash"
    PIXELS = "pixels"
    RANK = "rank"
    SCRIPTING = "scripting"
    SSM = "ssm"
    STRINGS = "strings"
    TIPS = "tips"
    TRAITOR = "traitor"
    TSTRINGS = "tstrings"
    WEAPON_EXPL = "weapon_expl"
    UNKNOWN = "unknown"

class EntityClassifier:
    """
    Enhanced entity classifier that properly categorizes WCS entities
    based on table context, naming patterns, and file structure analysis.
    """
    
    def __init__(self, source_dir: Path):
        """
        Initialize the entity classifier.
        
        Args:
            source_dir: WCS source directory containing table files
        """
        # Normalize path for WSL compatibility
        self.source_dir = Path(str(source_dir).replace('\\', '/'))
        
        # Known weapon names (missiles, projectiles) that might appear in ships.tbl
        self.known_weapons = {
            'dart', 'pilum', 'javelin', 'spiculum', 'porcupine', 'lance', 
            'warhammer', 'torpedo', 'missile', 'paw', 'fang', 'stalker', 
            'claw', 'scratch', 'spear', 'predator'
        }
        
        # Known ship name patterns
        self.ship_name_patterns = {
            # Terran ships
            'hornet', 'rapier', 'excalibur', 'thunderbolt', 'sabre', 'broadsword',
            'epee', 'gladius', 'stiletto', 'centurion', 'orion', 'demon',
            # Kilrathi ships  
            'dralthi', 'salthi', 'sartha', 'gothri', 'jalthi', 'gratha',
            'fralthi', 'ralari', 'kamrani', 'snakeir', 'bloodfang',
            # Capital ships
            'carrier', 'destroyer', 'cruiser', 'corvette', 'frigate',
            'dreadnought', 'transport', 'tanker', 'bengal', 'tiger'
        }
        
        # Enhanced faction prefixes from comprehensive campaign analysis
        self.faction_prefixes = {
            'tcf_': 'terran',       # Terran Confederation Fighters
            'tcb_': 'terran',       # Terran Confederation Bombers  
            'tcs_': 'terran',       # Terran Confederation Ships
            'tcm_': 'terran',       # Terran Confederation Missiles
            'tci_': 'terran',       # Terran Confederation Installations
            'tc_': 'terran',        # General Terran
            'confed_': 'terran',    # Confederation
            'kif_': 'kilrathi',     # Kilrathi Imperial Fighters
            'kib_': 'kilrathi',     # Kilrathi Imperial Bombers
            'kis_': 'kilrathi',     # Kilrathi Imperial Ships
            'kim_': 'kilrathi',     # Kilrathi Imperial Missiles
            'kii_': 'kilrathi',     # Kilrathi Imperial Installations
            'ki_': 'kilrathi',      # General Kilrathi Imperial
            'kb_': 'kilrathi',      # Kilrathi Base
            'kil_': 'kilrathi',     # Kilrathi
            'prf_': 'pirate',       # Pirate Republic Fighters
            'prs_': 'pirate',       # Pirate Republic Ships
            'pr_': 'pirate',        # General Pirate
            'bwf_': 'border_worlds', # Border Worlds Fighters
            'bws_': 'border_worlds', # Border Worlds Ships
            'bw_': 'border_worlds',  # General Border Worlds
            'misc_': 'misc'         # Miscellaneous
        }
        
        # Effect/explosion indicators
        self.effect_indicators = {
            'explosion', 'blast', 'flash', 'spark', 'trail', 'exhaust',
            'muzzle', 'impact', 'debris', 'shockwave', 'fireball'
        }
        
        # Table parsing cache
        self._table_cache: Dict[str, Set[str]] = {}
    
    def classify_entity(self, entity_name: str, table_type: TableType, 
                       source_context: Optional[str] = None) -> EntityType:
        """
        Classify an entity based on its name, table context, and additional context.
        
        Args:
            entity_name: Name of the entity to classify
            table_type: Which table file the entity came from
            source_context: Additional context (file path, section, etc.)
            
        Returns:
            Classified entity type
        """
        entity_lower = entity_name.lower()
        
        # Primary classification based on table type
        primary_type = self._classify_by_table_type(table_type)
        if primary_type != EntityType.UNKNOWN:
            # Secondary validation for ships.tbl which contains weapons
            if table_type == TableType.SHIPS:
                return self._validate_ship_classification(entity_name, entity_lower)
            return primary_type
        
        # Fallback classification based on naming patterns
        return self._classify_by_naming_patterns(entity_name, entity_lower, source_context)
    
    def _classify_by_table_type(self, table_type: TableType) -> EntityType:
        """Primary classification based on table file type"""
        table_mapping = {
            TableType.SHIPS: EntityType.SHIP,
            TableType.WEAPONS: EntityType.WEAPON,
            TableType.WEAPON_EXPL: EntityType.WEAPON,
            TableType.ARMOR: EntityType.ARMOR,
            TableType.FIREBALL: EntityType.EFFECT,
            TableType.ASTEROID: EntityType.ASTEROID,
            TableType.SPECIES: EntityType.SPECIES,
            TableType.SPECIES_DEFS: EntityType.SPECIES,
            TableType.IFF_DEFS: EntityType.IFF,
            TableType.MUSIC: EntityType.MUSIC,
            TableType.SOUNDS: EntityType.SOUND,
            TableType.LIGHTNING: EntityType.EFFECT,
            TableType.NEBULA: EntityType.EFFECT,
            TableType.ICONS: EntityType.UI_ELEMENT,
            TableType.HUD_GAUGES: EntityType.UI_ELEMENT,
            TableType.MENU: EntityType.UI_ELEMENT,
        }
        
        return table_mapping.get(table_type, EntityType.UNKNOWN)
    
    def _validate_ship_classification(self, entity_name: str, entity_lower: str) -> EntityType:
        """
        Validate ship classification since ships.tbl sometimes contains weapons.
        This is the critical fix for the current mapping issues.
        """
        # Check if entity name matches known weapon patterns
        for weapon_name in self.known_weapons:
            if weapon_name in entity_lower:
                logger.debug(f"Entity '{entity_name}' reclassified as weapon (found in ships.tbl)")
                return EntityType.WEAPON
        
        # Check for weapon-like suffixes/indicators
        weapon_indicators = ['missile', 'torpedo', 'rocket', 'dart', 'child']
        if any(indicator in entity_lower for indicator in weapon_indicators):
            logger.debug(f"Entity '{entity_name}' reclassified as weapon (weapon indicator)")
            return EntityType.WEAPON
        
        # Check for model file patterns that indicate weapons
        if '#' in entity_name:  # Weapon variants often have # suffix
            base_name = entity_name.split('#')[0].lower()
            if any(weapon in base_name for weapon in self.known_weapons):
                logger.debug(f"Entity '{entity_name}' reclassified as weapon (variant)")
                return EntityType.WEAPON
        
        # Check faction prefixes - some indicate ship models
        for prefix, faction in self.faction_prefixes.items():
            if entity_lower.startswith(prefix):
                # If it has a ship prefix and matches ship patterns, it's likely a ship
                for ship_pattern in self.ship_name_patterns:
                    if ship_pattern in entity_lower:
                        return EntityType.SHIP
        
        # Default to ship if found in ships.tbl and no weapon indicators
        return EntityType.SHIP
    
    def _classify_by_naming_patterns(self, entity_name: str, entity_lower: str, 
                                   source_context: Optional[str] = None) -> EntityType:
        """Fallback classification using naming patterns and context"""
        
        # Check for ship patterns
        if any(pattern in entity_lower for pattern in self.ship_name_patterns):
            return EntityType.SHIP
        
        # Check for weapon patterns
        if any(weapon in entity_lower for weapon in self.known_weapons):
            return EntityType.WEAPON
        
        # Check for effect patterns
        if any(effect in entity_lower for effect in self.effect_indicators):
            return EntityType.EFFECT
        
        # Check file context if provided
        if source_context:
            context_lower = source_context.lower()
            if 'mission' in context_lower:
                return EntityType.MISSION
            elif 'campaign' in context_lower:
                return EntityType.CAMPAIGN
            elif 'debris' in context_lower:
                return EntityType.DEBRIS
            elif 'asteroid' in context_lower:
                return EntityType.ASTEROID
        
        return EntityType.UNKNOWN
    
    # DM-017: Enhanced Semantic Classification Methods
    
    def detect_faction(self, entity_name: str) -> str:
        """
        Detect faction from entity name using comprehensive pattern analysis.
        
        Args:
            entity_name: Name of the entity
            
        Returns:
            Faction name (terran, kilrathi, pirate, border_worlds, misc, unknown)
        """
        entity_lower = entity_name.lower()
        
        # Check faction prefixes (longest first to avoid conflicts)
        sorted_prefixes = sorted(self.faction_prefixes.items(), key=lambda x: len(x[0]), reverse=True)
        
        for prefix, faction in sorted_prefixes:
            if entity_lower.startswith(prefix):
                logger.debug(f"Entity '{entity_name}' classified as {faction} faction (prefix: {prefix})")
                return faction
        
        return 'unknown'
    
    def classify_entity_subcategory(self, entity_name: str, faction: str) -> str:
        """
        Classify entity subcategory within faction based on prefix patterns.
        
        Args:
            entity_name: Name of the entity
            faction: Detected faction
            
        Returns:
            Subcategory string (fighters, bombers, ships, missiles, installations, misc)
        """
        entity_lower = entity_name.lower()
        
        # Map prefixes to subcategories
        prefix_to_subcategory = {
            'tcf_': 'fighters',
            'tcb_': 'bombers', 
            'tcs_': 'ships',
            'tcm_': 'missiles',
            'tci_': 'installations',
            'kif_': 'fighters',
            'kib_': 'bombers',
            'kis_': 'ships', 
            'kim_': 'missiles',
            'kii_': 'installations',
            'prf_': 'fighters',
            'prs_': 'ships',
            'bwf_': 'fighters',
            'bws_': 'ships'
        }
        
        # Check for specific prefix match
        for prefix, subcategory in prefix_to_subcategory.items():
            if entity_lower.startswith(prefix):
                return subcategory
        
        # Fallback to pattern-based classification
        if any(pattern in entity_lower for pattern in ['fighter', 'f-', 'interceptor']):
            return 'fighters'
        elif any(pattern in entity_lower for pattern in ['bomber', 'b-', 'torpedo']):
            return 'bombers'
        elif any(pattern in entity_lower for pattern in ['missile', 'rocket', 'torpedo']):
            return 'missiles'
        elif any(pattern in entity_lower for pattern in ['destroyer', 'cruiser', 'carrier', 'corvette', 'frigate']):
            return 'capital_ships'
        elif any(pattern in entity_lower for pattern in ['installation', 'station', 'base', 'platform']):
            return 'installations'
        else:
            return 'misc'
    
    def get_classification_confidence(self, entity_name: str, table_type: TableType) -> float:
        """
        Calculate confidence score for entity classification.
        
        Args:
            entity_name: Name of the entity
            table_type: Table type context
            
        Returns:
            Confidence score between 0.0 and 1.0
        """
        confidence = 0.0
        entity_lower = entity_name.lower()
        
        # High confidence for table-based classification
        if table_type in [TableType.SHIPS, TableType.WEAPONS, TableType.ARMOR]:
            confidence += 0.7
        
        # Medium confidence for faction prefix match
        faction = self.detect_faction(entity_name)
        if faction != 'unknown':
            confidence += 0.2
        
        # Low confidence for name pattern match
        if any(pattern in entity_lower for pattern in self.ship_name_patterns):
            confidence += 0.1
        
        return min(confidence, 1.0)
    
    def classify_by_file_extension(self, file_path: Path) -> EntityType:
        """Classify entity based on file extension and location"""
        suffix = file_path.suffix.lower()
        parent_dir = file_path.parent.name.lower()
        
        extension_mapping = {
            '.pof': self._classify_pof_file(file_path),
            '.dds': EntityType.UI_ELEMENT if 'interface' in parent_dir else EntityType.EFFECT,
            '.pcx': EntityType.UI_ELEMENT if 'interface' in parent_dir else EntityType.EFFECT,
            '.eff': EntityType.EFFECT,
            '.wav': EntityType.SOUND,
            '.ogg': EntityType.SOUND,
            '.fs2': EntityType.MISSION,
            '.fc2': EntityType.CAMPAIGN,
            '.tbl': EntityType.UNKNOWN,  # Requires content analysis
            '.tbm': EntityType.TABLE_MOD,
            '.vf': EntityType.UI_ELEMENT,
            '.frc': EntityType.EFFECT,
            '.hcf': EntityType.UI_ELEMENT
        }
        
        return extension_mapping.get(suffix, EntityType.UNKNOWN)
    
    def _classify_pof_file(self, pof_path: Path) -> EntityType:
        """Classify POF model files based on naming patterns"""
        stem = pof_path.stem.lower()
        
        # New heuristics from user feedback
        if stem.startswith('ast'):
            return EntityType.ASTEROID
        if stem.startswith('sky_'):
            return EntityType.ENVIRONMENT
            
        # Check for weapon model patterns
        if any(weapon in stem for weapon in self.known_weapons):
            return EntityType.WEAPON
        
        # Check for ship model patterns
        if any(ship in stem for ship in self.ship_name_patterns):
            return EntityType.SHIP
        
        # Check prefixes
        for prefix, faction in self.faction_prefixes.items():
            if stem.startswith(prefix):
                # Analyze the rest of the name
                name_part = stem[len(prefix):]
                if any(weapon in name_part for weapon in self.known_weapons):
                    return EntityType.WEAPON
                else:
                    return EntityType.SHIP
        
        # Special cases
        if any(indicator in stem for indicator in ['debris', 'rock']):
            return EntityType.DEBRIS
        elif any(indicator in stem for indicator in ['base', 'station', 'platform']):
            return EntityType.INSTALLATION
        elif any(indicator in stem for indicator in ['shockwave', 'warp', 'subspace', 'jump']):
            return EntityType.EFFECT

        # Fallback for other pof files in hermes_models
        if pof_path.parent.name == 'hermes_models':
            return EntityType.MISC

        return EntityType.UNKNOWN
    
    def determine_table_type(self, table_file: Path) -> TableType:
        """Determine table type from filename"""
        filename = table_file.name.lower()
        
        # Direct mappings
        direct_mappings = {
            'ships.tbl': TableType.SHIPS,
            'weapons.tbl': TableType.WEAPONS,
            'weapon_expl.tbl': TableType.WEAPON_EXPL,
            'armor.tbl': TableType.ARMOR,
            'species.tbl': TableType.SPECIES,
            'species_defs.tbl': TableType.SPECIES_DEFS,
            'iff_defs.tbl': TableType.IFF_DEFS,
            'fireball.tbl': TableType.FIREBALL,
            'asteroid.tbl': TableType.ASTEROID,
            'music.tbl': TableType.MUSIC,
            'sounds.tbl': TableType.SOUNDS,
            'lightning.tbl': TableType.LIGHTNING,
            'nebula.tbl': TableType.NEBULA,
            'stars.tbl': TableType.STARS,
            'ai.tbl': TableType.AI,
            'ai_profiles.tbl': TableType.AI_PROFILES,
            'autopilot.tbl': TableType.AUTOPILOT,
            'credits.tbl': TableType.CREDITS,
            'cutscenes.tbl': TableType.CUTSCENES,
            'fonts.tbl': TableType.FONTS,
            'help.tbl': TableType.HELP,
            'hud_gauges.tbl': TableType.HUD_GAUGES,
            'icons.tbl': TableType.ICONS,
            'launchhelp.tbl': TableType.LAUNCH_HELP,
            'mainhall.tbl': TableType.MAIN_HALL,
            'medals.tbl': TableType.MEDALS,
            'menu.tbl': TableType.MENU,
            'messages.tbl': TableType.MESSAGES,
            'mflash.tbl': TableType.MFLASH,
            'pixels.tbl': TableType.PIXELS,
            'rank.tbl': TableType.RANK,
            'scripting.tbl': TableType.SCRIPTING,
            'ssm.tbl': TableType.SSM,
            'strings.tbl': TableType.STRINGS,
            'tips.tbl': TableType.TIPS,
            'traitor.tbl': TableType.TRAITOR,
            'tstrings.tbl': TableType.TSTRINGS,
        }
        
        if filename in direct_mappings:
            return direct_mappings[filename]
        
        # Pattern-based detection
        if 'ship' in filename:
            return TableType.SHIPS
        elif 'weapon' in filename:
            return TableType.WEAPONS
        elif 'armor' in filename:
            return TableType.ARMOR
        elif 'species' in filename:
            return TableType.SPECIES_DEFS
        elif 'iff' in filename:
            return TableType.IFF_DEFS
        
        return TableType.UNKNOWN
    
    def get_entity_faction(self, entity_name: str) -> str:
        """Determine entity faction from name patterns"""
        entity_lower = entity_name.lower()
        
        # Check prefixes
        for prefix, faction in self.faction_prefixes.items():
            if entity_lower.startswith(prefix):
                return faction
        
        # Check naming patterns
        terran_patterns = ['tc', 'terran', 'confed', 'arrow', 'hellcat', 'excalibur']
        kilrathi_patterns = ['kib', 'kim', 'kilrathi', 'dralthi', 'salthi', 'gratha']
        
        if any(pattern in entity_lower for pattern in terran_patterns):
            return 'terran'
        elif any(pattern in entity_lower for pattern in kilrathi_patterns):
            return 'kilrathi'
        
        return 'unknown'
    
    def get_ship_class(self, ship_name: str) -> str:
        """Determine ship class from name patterns"""
        name_lower = ship_name.lower()
        
        # Capital ship indicators
        capital_patterns = ['carrier', 'cruiser', 'destroyer', 'dreadnought', 'corvette', 
                          'bengal', 'tiger', 'fralthi', 'ralari']
        if any(pattern in name_lower for pattern in capital_patterns):
            return 'capital_ships'
        
        # Transport indicators
        transport_patterns = ['transport', 'freighter', 'tanker', 'supply']
        if any(pattern in name_lower for pattern in transport_patterns):
            return 'transports'
        
        # Installation indicators
        installation_patterns = ['base', 'station', 'platform', 'starbase', 'drydock']
        if any(pattern in name_lower for pattern in installation_patterns):
            return 'installations'
        
        # Default to fighters
        return 'fighters'
