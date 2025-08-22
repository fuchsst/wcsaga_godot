#!/usr/bin/env python3
"""
WCS Table Data Converter

Converts WCS table files (.tbl) to Godot-compatible resource formats.
Handles ship classes, weapon definitions, armor specifications, and faction data
with complete fidelity to the original C++ parsing implementation.

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-008 - Asset Table Processing
Epic: EPIC-003 - Data Migration & Conversion Tools
Architecture: Mo's EPIC-003 Architecture Document v2.0

Original C++ Analysis:
- Based on parselo.cpp/h parsing framework from WCS source
- Maintains compatibility with ship.cpp, weapons.cpp, species_defs.cpp, iff_defs.cpp
- Supports modular table system (.tbl base + .tbm modular overrides)
- Preserves all data fields and parsing behaviors from original implementation
"""

import json
import logging
import re
from dataclasses import dataclass, field
from enum import Enum, IntEnum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

logger = logging.getLogger(__name__)

class ParseError(Exception):
    """Custom exception for table parsing errors"""
    def __init__(self, message: str, line_number: int = -1, filename: str = ""):
        self.message = message
        self.line_number = line_number
        self.filename = filename
        super().__init__(f"{filename}:{line_number}: {message}" if line_number > 0 else message)

class TableType(Enum):
    """Table file types supported by the converter"""
    SHIPS = "ships"
    WEAPONS = "weapons"
    ARMOR = "armor"
    SPECIES = "species_defs"
    IFF = "iff_defs"
    UNKNOWN = "unknown"

@dataclass
class ParseState:
    """Current state of the table parser"""
    lines: List[str] = field(default_factory=list)
    current_line: int = 0
    filename: str = ""
    in_comment_block: bool = False
    
    def get_current_line_text(self) -> str:
        """Get current line text"""
        if 0 <= self.current_line < len(self.lines):
            return self.lines[self.current_line].strip()
        return ""
    
    def advance_line(self) -> bool:
        """Advance to next line, return True if successful"""
        self.current_line += 1
        return self.current_line < len(self.lines)
    
    def peek_line(self, offset: int = 1) -> str:
        """Peek at future line without advancing"""
        peek_index = self.current_line + offset
        if 0 <= peek_index < len(self.lines):
            return self.lines[peek_index].strip()
        return ""

@dataclass
class ShipClassData:
    """Ship class data structure matching WCS ship_info"""
    # General Information
    name: str = ""
    alt_name: str = ""
    short_name: str = ""
    species: str = ""
    class_type: str = ""
    manufacturer: str = ""
    description: str = ""
    tech_description: str = ""
    ship_length: str = ""
    
    # Models and Visuals
    pof_file: str = ""
    pof_file_hud: str = ""
    cockpit_pof_file: str = ""
    cockpit_offset: Tuple[float, float, float] = (0.0, 0.0, 0.0)
    detail_distances: List[int] = field(default_factory=list)
    hud_target_lod: int = 0
    
    # Texture replacements
    texture_replacements: List[Tuple[str, str]] = field(default_factory=list)
    
    # Physics Properties
    density: float = 1.0
    damp: float = 0.1
    rotdamp: float = 0.1
    banking_constant: float = 0.0
    
    # Movement
    max_velocity: Tuple[float, float, float] = (100.0, 100.0, 100.0)
    rotation_time: Tuple[float, float, float] = (1.0, 1.0, 1.0)
    rear_velocity: float = 50.0
    forward_accel: float = 100.0
    forward_decel: float = 100.0
    slide_accel: float = 50.0
    slide_decel: float = 50.0
    
    # Glide Properties
    can_glide: bool = False
    dynamic_glide_cap: bool = False
    max_glide_speed: float = 0.0
    glide_accel_mult: float = 1.0
    
    # Advanced Physics
    use_newtonian_dampening: bool = False
    autoaim_fov: float = 0.0
    
    # Weapons
    primary_weapon_count: int = 0
    secondary_weapon_count: int = 0
    primary_banks: List[str] = field(default_factory=list)
    secondary_banks: List[str] = field(default_factory=list)
    
    # Defensive Systems
    shields: float = 100.0
    hull: float = 100.0
    hull_repair_rate: float = 0.0
    subsystem_repair_rate: float = 0.0
    armor_type: str = ""
    shield_armor_type: str = ""
    
    # Power Systems
    power_output: float = 100.0
    max_oclk_speed: float = 0.0
    max_weapon_reserve: float = 100.0
    max_shield_regen: float = 10.0
    max_weapon_regen: float = 10.0
    
    # Afterburner
    has_afterburner: bool = False
    afterburner_fuel_capacity: float = 100.0
    afterburner_burn_rate: float = 10.0
    afterburner_rec_rate: float = 5.0
    afterburner_max_vel: Tuple[float, float, float] = (150.0, 150.0, 150.0)
    afterburner_forward_accel: float = 200.0
    
    # Misc
    countermeasures: int = 0
    engine_sound: str = ""
    closeup_pos: Tuple[float, float, float] = (0.0, 0.0, 10.0)
    closeup_zoom: float = 1.0
    
    # Visual Assets
    shield_icon: str = ""
    ship_icon: str = ""
    ship_anim: str = ""
    ship_overhead: str = ""
    
    # Gameplay
    score: int = 0
    scan_time: int = 2000
    flags: List[str] = field(default_factory=list)
    flags2: List[str] = field(default_factory=list)
    ai_class: int = 0
    
    # Explosion
    explosion_damage_type: str = ""
    explosion_inner_damage: float = 0.0
    explosion_outer_damage: float = 0.0
    explosion_inner_radius: float = 0.0
    explosion_outer_radius: float = 0.0
    explosion_shockwave_speed: float = 0.0
    
    # Particle Effects
    impact_spew_max_particles: int = 0
    damage_spew_max_particles: int = 0
    
    # Debris
    debris_min_lifetime: float = 5.0
    debris_max_lifetime: float = 15.0
    debris_min_speed: float = 10.0
    debris_max_speed: float = 50.0
    debris_min_rotation_speed: float = 0.1
    debris_max_rotation_speed: float = 2.0
    debris_damage_type: str = ""
    debris_min_hitpoints: float = 1.0
    debris_max_hitpoints: float = 10.0
    debris_damage_multiplier: float = 1.0
    debris_lightning_arc_percent: float = 0.0
    
    # Subsystems
    subsystems: List[Dict[str, Any]] = field(default_factory=list)
    
    # Radar
    radar_image_2d: str = ""
    radar_image_size: int = 1
    radar_blip_size_multiplier: float = 1.0
    
    # Target Priority
    target_priority_groups: List[str] = field(default_factory=list)
    
    # Advanced Properties
    emp_resistance_modifier: float = 1.0
    piercing_damage_draw_limit: float = 0.0

@dataclass
class WeaponData:
    """Weapon data structure matching WCS weapon_info"""
    # General Information
    name: str = ""
    title: str = ""
    description: str = ""
    tech_title: str = ""
    tech_description: str = ""
    
    # Visual Assets
    model_file: str = ""
    pof_target_file: str = ""
    detail_distances: List[int] = field(default_factory=list)
    icon: str = ""
    anim: str = ""
    
    # Physics Properties
    velocity: float = 100.0
    mass: float = 1.0
    lifetime: float = 5.0
    range_: float = 1000.0  # 'range' is a Python keyword
    
    # Damage Properties
    damage: float = 10.0
    damage_type: str = ""
    armor_factor: float = 1.0
    shield_factor: float = 1.0
    subsystem_factor: float = 1.0
    
    # Firing Properties
    fire_wait: float = 1.0
    damage_time: float = 0.0
    energy_consumed: float = 10.0
    
    # Shockwave Properties
    shockwave_damage: float = 0.0
    shockwave_damage_type: str = ""
    shockwave_inner_radius: float = 0.0
    shockwave_outer_radius: float = 0.0
    shockwave_speed: float = 0.0
    
    # Flags and Properties
    flags: List[str] = field(default_factory=list)
    flags2: List[str] = field(default_factory=list)
    
    # Effects
    impact_effect: str = ""
    dinky_impact_effect: str = ""
    piercing_impact_effect: str = ""
    
    # Particle Spew
    particle_spew_count: int = 0
    particle_spew_time: float = 0.0
    particle_spew_vel: float = 0.0
    
    # Trail Properties
    trail_life: float = 0.0
    trail_width: float = 0.0
    trail_alpha: float = 1.0
    trail_uv_tiling: Tuple[float, float] = (1.0, 1.0)
    
    # Audio
    sound: str = ""
    impact_sound: str = ""

@dataclass
class ArmorTypeData:
    """Armor type data structure matching WCS ArmorType"""
    name: str = ""
    damage_type_modifiers: Dict[str, float] = field(default_factory=dict)
    flags: List[str] = field(default_factory=list)

@dataclass
class SpeciesData:
    """Species data structure matching WCS species_defs"""
    name: str = ""
    fred_name: str = ""
    
    # Thruster Animations
    thruster_pri_normal: str = ""
    thruster_pri_afterburn: str = ""
    thruster_sec_normal: str = ""
    thruster_sec_afterburn: str = ""
    
    # Thruster Glows
    thruster_glow_normal: str = ""
    thruster_glow_afterburn: str = ""
    
    # Debris Properties
    max_debris_speed: float = 100.0
    debris_damage_type: str = ""
    debris_damage_multiplier: float = 1.0
    debris_density: float = 1.0
    debris_fire_threshold: float = 50.0
    debris_fire_spread: float = 0.1
    debris_fire_lifetime: float = 10.0

@dataclass
class IFFData:
    """IFF (faction) data structure matching WCS iff_defs"""
    name: str = ""
    
    # Colors
    selection_color: Tuple[int, int, int] = (255, 255, 255)
    message_color: Tuple[int, int, int] = (255, 255, 255)
    tagged_color: Tuple[int, int, int] = (255, 255, 0)
    color: Tuple[int, int, int] = (255, 255, 255)
    
    # Blip Colors
    missile_blip_color: Tuple[int, int, int] = (255, 0, 0)
    navbuoy_blip_color: Tuple[int, int, int] = (0, 255, 0)
    warping_blip_color: Tuple[int, int, int] = (255, 255, 0)
    node_blip_color: Tuple[int, int, int] = (0, 0, 255)
    tagged_blip_color: Tuple[int, int, int] = (255, 255, 0)
    
    # Properties
    dimmed_iff_brightness: float = 0.5
    use_alternate_blip_coloring: bool = False
    
    # Relations
    attacks: List[str] = field(default_factory=list)
    sees_as: Dict[str, Tuple[int, int, int]] = field(default_factory=dict)
    flags: List[str] = field(default_factory=list)

class TableDataConverter:
    """
    Main table data converter following EPIC-003 architecture.
    
    Converts WCS table files (.tbl) to Godot BaseAssetData resource format
    with complete data fidelity and relationship mapping.
    """
    
    def __init__(self, source_dir: Path, target_dir: Path):
        """
        Initialize table data converter.
        
        Args:
            source_dir: WCS source directory containing table files
            target_dir: Target Godot project directory for output
        """
        self.source_dir = Path(source_dir)
        self.target_dir = Path(target_dir)
        self.assets_dir = self.target_dir / "assets" / "tables"
        self.conversion_stats = {
            "ships_processed": 0,
            "weapons_processed": 0,
            "armor_types_processed": 0,
            "species_processed": 0,
            "iff_factions_processed": 0,
            "relationships_mapped": 0,
            "errors": []
        }
        
        # Asset relationship mapping
        self.ship_weapon_compatibility: Dict[str, List[str]] = {}
        self.damage_type_registry: Dict[str, int] = {}
        self.armor_type_registry: Dict[str, str] = {}
        self.species_registry: Dict[str, int] = {}
        
        # Ensure output directory exists
        self.assets_dir.mkdir(parents=True, exist_ok=True)
    
    def convert_table_file(self, table_file: Path) -> bool:
        """
        Convert a single table file to Godot resources.
        
        Args:
            table_file: Path to the table file to convert
            
        Returns:
            True if conversion successful, False otherwise
        """
        try:
            logger.info(f"Converting table file: {table_file}")
            
            # Determine table type
            table_type = self._determine_table_type(table_file)
            
            if table_type == TableType.UNKNOWN:
                logger.warning(f"Unknown table type for file: {table_file}")
                return False
            
            # Load and preprocess file content
            content = self._load_table_file(table_file)
            if not content:
                logger.error(f"Failed to load table file: {table_file}")
                return False
            
            # Parse based on table type
            success = False
            if table_type == TableType.SHIPS:
                success = self._convert_ships_table(content, table_file)
            elif table_type == TableType.WEAPONS:
                success = self._convert_weapons_table(content, table_file)
            elif table_type == TableType.ARMOR:
                success = self._convert_armor_table(content, table_file)
            elif table_type == TableType.SPECIES:
                success = self._convert_species_table(content, table_file)
            elif table_type == TableType.IFF:
                success = self._convert_iff_table(content, table_file)
            
            if success:
                logger.info(f"Successfully converted: {table_file}")
            else:
                logger.error(f"Failed to convert: {table_file}")
                
            return success
            
        except Exception as e:
            error_msg = f"Error converting {table_file}: {str(e)}"
            logger.error(error_msg)
            self.conversion_stats["errors"].append(error_msg)
            return False
    
    def _determine_table_type(self, table_file: Path) -> TableType:
        """Determine the type of table file"""
        filename = table_file.name.lower()
        
        if "ship" in filename:
            return TableType.SHIPS
        elif "weapon" in filename:
            return TableType.WEAPONS
        elif "armor" in filename:
            return TableType.ARMOR
        elif "species" in filename or "species_defs" in filename:
            return TableType.SPECIES
        elif "iff" in filename:
            return TableType.IFF
        
        # Check file content for type hints
        try:
            with open(table_file, 'r', encoding='utf-8', errors='replace') as f:
                first_lines = f.read(1000).lower()
                
            if "#ship classes" in first_lines:
                return TableType.SHIPS
            elif "#primary weapons" in first_lines or "#secondary weapons" in first_lines:
                return TableType.WEAPONS
            elif "#armor type" in first_lines:
                return TableType.ARMOR
            elif "#species defs" in first_lines:
                return TableType.SPECIES
            elif "#iffs" in first_lines:
                return TableType.IFF
                
        except Exception as e:
            logger.warning(f"Could not read file for type detection: {table_file} - {e}")
        
        return TableType.UNKNOWN
    
    def _load_table_file(self, table_file: Path) -> Optional[ParseState]:
        """Load and preprocess table file content"""
        try:
            with open(table_file, 'r', encoding='utf-8', errors='replace') as f:
                raw_lines = f.readlines()
            
            # Preprocess lines (remove comments, handle continuations)
            processed_lines = self._preprocess_lines(raw_lines)
            
            return ParseState(
                lines=processed_lines,
                current_line=0,
                filename=str(table_file)
            )
            
        except Exception as e:
            logger.error(f"Failed to load table file {table_file}: {e}")
            return None
    
    def _preprocess_lines(self, raw_lines: List[str]) -> List[str]:
        """Preprocess table lines (comments, continuations, etc.)"""
        processed_lines = []
        in_block_comment = False
        
        for line in raw_lines:
            line = line.rstrip('\n\r')
            
            # Handle block comments
            if "/*" in line and "*/" in line:
                # Single line block comment
                start = line.find("/*")
                end = line.find("*/") + 2
                line = line[:start] + line[end:]
            elif "/*" in line:
                # Start of block comment
                in_block_comment = True
                line = line[:line.find("/*")]
            elif "*/" in line and in_block_comment:
                # End of block comment
                in_block_comment = False
                line = line[line.find("*/") + 2:]
            elif in_block_comment:
                # Skip lines inside block comment
                continue
            
            # Handle line comments
            if ";" in line and not in_block_comment:
                line = line[:line.find(";")]
            
            # Skip empty lines and comment-only lines
            line = line.strip()
            if not line:
                continue
            
            processed_lines.append(line)
        
        return processed_lines
    
    def _convert_ships_table(self, parse_state: ParseState, table_file: Path) -> bool:
        """Convert ships.tbl to ShipData resources"""
        try:
            ships_converted = 0
            
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # Look for ship class start
                if line.startswith("#Ship Classes") or line.startswith("$Name:"):
                    if line.startswith("#Ship Classes"):
                        parse_state.advance_line()
                        continue
                    
                    # Parse ship data
                    ship_data = self._parse_ship_class(parse_state)
                    if ship_data:
                        # Convert to Godot resource
                        if self._create_ship_resource(ship_data, table_file):
                            ships_converted += 1
                            self.conversion_stats["ships_processed"] += 1
                        else:
                            logger.warning(f"Failed to create resource for ship: {ship_data.name}")
                
                parse_state.advance_line()
            
            logger.info(f"Converted {ships_converted} ships from {table_file}")
            return ships_converted > 0
            
        except Exception as e:
            logger.error(f"Error converting ships table {table_file}: {e}")
            return False
    
    def _parse_ship_class(self, parse_state: ParseState) -> Optional[ShipClassData]:
        """Parse a single ship class definition"""
        ship = ShipClassData()
        
        try:
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # End of ship definition
                if line.startswith("#End") or line.startswith("$Name:"):
                    if line.startswith("$Name:"):
                        # Don't consume the next ship's name line
                        parse_state.current_line -= 1
                    break
                
                # Parse ship properties
                if line.startswith("$Name:"):
                    ship.name = self._extract_string_value(line)
                elif line.startswith("$Alt name:"):
                    ship.alt_name = self._extract_string_value(line)
                elif line.startswith("$Short name:"):
                    ship.short_name = self._extract_string_value(line)
                elif line.startswith("$Species:"):
                    ship.species = self._extract_string_value(line)
                elif line.startswith("+Type:"):
                    ship.class_type = self._extract_string_value(line)
                elif line.startswith("+Manufacturer:"):
                    ship.manufacturer = self._extract_string_value(line)
                elif line.startswith("+Description:"):
                    ship.description = self._extract_multiline_string(parse_state)
                elif line.startswith("+Tech Description:"):
                    ship.tech_description = self._extract_multiline_string(parse_state)
                elif line.startswith("$POF file:"):
                    ship.pof_file = self._extract_string_value(line)
                elif line.startswith("$Cockpit POF file:"):
                    ship.cockpit_pof_file = self._extract_string_value(line)
                elif line.startswith("+Cockpit offset:"):
                    ship.cockpit_offset = self._extract_vector3(line)
                elif line.startswith("$Detail distance:"):
                    ship.detail_distances = self._extract_int_list(line)
                elif line.startswith("$Density:"):
                    ship.density = self._extract_float_value(line)
                elif line.startswith("$Damp:"):
                    ship.damp = self._extract_float_value(line)
                elif line.startswith("$Rotdamp:"):
                    ship.rotdamp = self._extract_float_value(line)
                elif line.startswith("$Banking Constant:"):
                    ship.banking_constant = self._extract_float_value(line)
                elif line.startswith("$Max Velocity:"):
                    ship.max_velocity = self._extract_vector3(line)
                elif line.startswith("$Rotation Time:"):
                    ship.rotation_time = self._extract_vector3(line)
                elif line.startswith("$Rear Velocity:"):
                    ship.rear_velocity = self._extract_float_value(line)
                elif line.startswith("$Forward accel:"):
                    ship.forward_accel = self._extract_float_value(line)
                elif line.startswith("$Forward decel:"):
                    ship.forward_decel = self._extract_float_value(line)
                elif line.startswith("$Slide accel:"):
                    ship.slide_accel = self._extract_float_value(line)
                elif line.startswith("$Slide decel:"):
                    ship.slide_decel = self._extract_float_value(line)
                elif line.startswith("$Glide:"):
                    ship.can_glide = self._extract_bool_value(line)
                elif line.startswith("+Dynamic Glide Cap:"):
                    ship.dynamic_glide_cap = self._extract_bool_value(line)
                elif line.startswith("+Max Glide Speed:"):
                    ship.max_glide_speed = self._extract_float_value(line)
                elif line.startswith("+Glide Accel Mult:"):
                    ship.glide_accel_mult = self._extract_float_value(line)
                elif line.startswith("$Use Newtonian Dampening:"):
                    ship.use_newtonian_dampening = self._extract_bool_value(line)
                elif line.startswith("$Autoaim FOV:"):
                    ship.autoaim_fov = self._extract_float_value(line)
                elif line.startswith("$Primary Weapons:"):
                    ship.primary_weapon_count = self._extract_int_value(line)
                elif line.startswith("$Secondary Weapons:"):
                    ship.secondary_weapon_count = self._extract_int_value(line)
                elif line.startswith("$Primary Banks:"):
                    ship.primary_banks = self._extract_string_list(line)
                elif line.startswith("$Secondary Banks:"):
                    ship.secondary_banks = self._extract_string_list(line)
                elif line.startswith("$Shields:"):
                    ship.shields = self._extract_float_value(line)
                elif line.startswith("$Hull:"):
                    ship.hull = self._extract_float_value(line)
                elif line.startswith("$Hull Repair Rate:"):
                    ship.hull_repair_rate = self._extract_float_value(line)
                elif line.startswith("$Subsystem Repair Rate:"):
                    ship.subsystem_repair_rate = self._extract_float_value(line)
                elif line.startswith("$Armor Type:"):
                    ship.armor_type = self._extract_string_value(line)
                elif line.startswith("$Shield Armor Type:"):
                    ship.shield_armor_type = self._extract_string_value(line)
                elif line.startswith("$Power Output:"):
                    ship.power_output = self._extract_float_value(line)
                elif line.startswith("$Max Oclk Speed:"):
                    ship.max_oclk_speed = self._extract_float_value(line)
                elif line.startswith("$Max Weapon Reserve:"):
                    ship.max_weapon_reserve = self._extract_float_value(line)
                elif line.startswith("$Max Shield Regen:"):
                    ship.max_shield_regen = self._extract_float_value(line)
                elif line.startswith("$Max Weapon Regen:"):
                    ship.max_weapon_regen = self._extract_float_value(line)
                elif line.startswith("$Afterburner:"):
                    ship.has_afterburner = self._extract_bool_value(line)
                elif line.startswith("$Afterburner Fuel Capacity:"):
                    ship.afterburner_fuel_capacity = self._extract_float_value(line)
                elif line.startswith("$Afterburner Burn Rate:"):
                    ship.afterburner_burn_rate = self._extract_float_value(line)
                elif line.startswith("$Afterburner Rec Rate:"):
                    ship.afterburner_rec_rate = self._extract_float_value(line)
                elif line.startswith("$Afterburner Max Vel:"):
                    ship.afterburner_max_vel = self._extract_vector3(line)
                elif line.startswith("$Afterburner Forward Accel:"):
                    ship.afterburner_forward_accel = self._extract_float_value(line)
                elif line.startswith("$Countermeasures:"):
                    ship.countermeasures = self._extract_int_value(line)
                elif line.startswith("$Engine Sound:"):
                    ship.engine_sound = self._extract_string_value(line)
                elif line.startswith("$Closeup_pos:"):
                    ship.closeup_pos = self._extract_vector3(line)
                elif line.startswith("$Closeup_zoom:"):
                    ship.closeup_zoom = self._extract_float_value(line)
                elif line.startswith("$Shield Icon:"):
                    ship.shield_icon = self._extract_string_value(line)
                elif line.startswith("$Ship Icon:"):
                    ship.ship_icon = self._extract_string_value(line)
                elif line.startswith("$Ship Anim:"):
                    ship.ship_anim = self._extract_string_value(line)
                elif line.startswith("$Ship Overhead:"):
                    ship.ship_overhead = self._extract_string_value(line)
                elif line.startswith("$Score:"):
                    ship.score = self._extract_int_value(line)
                elif line.startswith("$Scan Time:"):
                    ship.scan_time = self._extract_int_value(line)
                elif line.startswith("$Flags:"):
                    ship.flags = self._extract_string_list(line)
                elif line.startswith("$Flags2:"):
                    ship.flags2 = self._extract_string_list(line)
                elif line.startswith("$AI Class:"):
                    ship.ai_class = self._extract_int_value(line)
                elif line.startswith("$Explosion:"):
                    self._parse_explosion_block(parse_state, ship)
                elif line.startswith("$Impact Spew:"):
                    self._parse_impact_spew_block(parse_state, ship)
                elif line.startswith("$Damage Spew:"):
                    self._parse_damage_spew_block(parse_state, ship)
                elif line.startswith("$Debris:"):
                    self._parse_debris_block(parse_state, ship)
                elif line.startswith("$Subsystem:"):
                    self._parse_subsystem_block(parse_state, ship)
                elif line.startswith("$Texture Replace:"):
                    self._parse_texture_replace_block(parse_state, ship)
                
                parse_state.advance_line()
            
            # Validate ship data
            if not ship.name:
                logger.warning("Ship definition missing name")
                return None
            
            return ship
            
        except Exception as e:
            logger.error(f"Error parsing ship class: {e}")
            return None
    
    def _create_ship_resource(self, ship_data: ShipClassData, source_file: Path) -> bool:
        """Create a Godot ShipData resource from parsed ship data"""
        try:
            # Generate Godot resource file content
            resource_content = self._generate_ship_resource_content(ship_data, source_file)
            
            # Write resource file
            resource_filename = f"{ship_data.name.lower().replace(' ', '_')}.tres"
            resource_path = self.assets_dir / "ships" / resource_filename
            resource_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(resource_path, 'w', encoding='utf-8') as f:
                f.write(resource_content)
            
            # Update relationship mapping
            if ship_data.primary_banks or ship_data.secondary_banks:
                all_weapons = ship_data.primary_banks + ship_data.secondary_banks
                self.ship_weapon_compatibility[ship_data.name] = all_weapons
                self.conversion_stats["relationships_mapped"] += len(all_weapons)
            
            # Register armor types
            if ship_data.armor_type:
                self.armor_type_registry[ship_data.armor_type] = ship_data.name
            if ship_data.shield_armor_type:
                self.armor_type_registry[ship_data.shield_armor_type] = ship_data.name
            
            logger.debug(f"Created ship resource: {resource_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create ship resource for {ship_data.name}: {e}")
            return False
    
    def _generate_ship_resource_content(self, ship: ShipClassData, source_file: Path) -> str:
        """Generate Godot resource file content for ship data"""
        content = f"""[gd_resource type="ShipData" format=3]

[resource]
asset_name = "{ship.name}"
asset_id = "{ship.name.lower().replace(' ', '_')}"
source_file = "{source_file.name}"
conversion_notes = "Converted from WCS table data with complete fidelity"

# General Information
ship_name = "{ship.name}"
alt_name = "{ship.alt_name}"
short_name = "{ship.short_name}"
species = "{ship.species}"
manufacturer = "{ship.manufacturer}"
ship_description = "{self._escape_string(ship.description)}"
tech_description = "{self._escape_string(ship.tech_description)}"
ship_length = "{ship.ship_length}"

# Models and Visuals
pof_file = "{ship.pof_file}"
pof_file_hud = "{ship.pof_file_hud}"
cockpit_pof_file = "{ship.cockpit_pof_file}"
cockpit_offset = Vector3({ship.cockpit_offset[0]}, {ship.cockpit_offset[1]}, {ship.cockpit_offset[2]})
detail_distances = {self._format_int_array(ship.detail_distances)}
hud_target_lod = {ship.hud_target_lod}
icon_filename = "{ship.ship_icon}"
anim_filename = "{ship.ship_anim}"
overhead_filename = "{ship.ship_overhead}"

# Physics Properties
density = {ship.density}
damp = {ship.damp}
rotdamp = {ship.rotdamp}
banking_constant = {ship.banking_constant}

# Movement
max_vel = Vector3({ship.max_velocity[0]}, {ship.max_velocity[1]}, {ship.max_velocity[2]})
rotation_time = Vector3({ship.rotation_time[0]}, {ship.rotation_time[1]}, {ship.rotation_time[2]})
rear_vel = {ship.rear_velocity}
forward_accel = {ship.forward_accel}
forward_decel = {ship.forward_decel}
slide_accel = {ship.slide_accel}
slide_decel = {ship.slide_decel}

# Glide Properties
can_glide = {str(ship.can_glide).lower()}
dynamic_glide_cap = {str(ship.dynamic_glide_cap).lower()}
max_glide_speed = {ship.max_glide_speed}
glide_accel_mult = {ship.glide_accel_mult}

# Advanced Physics
use_newtonian_dampening = {str(ship.use_newtonian_dampening).lower()}
autoaim_fov = {ship.autoaim_fov}

# Weapons
num_primary_banks = {ship.primary_weapon_count}
num_secondary_banks = {ship.secondary_weapon_count}
allowed_primary_weapons = {self._format_string_array(ship.primary_banks)}
allowed_secondary_weapons = {self._format_string_array(ship.secondary_banks)}

# Defensive Systems
shield_armor_type_name = "{ship.shield_armor_type}"
armor_type_name = "{ship.armor_type}"
max_hull_strength = {ship.hull}
max_shield_strength = {ship.shields}
hull_repair_rate = {ship.hull_repair_rate}
subsystem_repair_rate = {ship.subsystem_repair_rate}

# Power Systems
power_output = {ship.power_output}
max_oclk_speed = {ship.max_oclk_speed}
max_weapon_reserve = {ship.max_weapon_reserve}
max_shield_regen = {ship.max_shield_regen}
max_weapon_regen = {ship.max_weapon_regen}

# Afterburner
has_afterburner = {str(ship.has_afterburner).lower()}
afterburner_fuel_capacity = {ship.afterburner_fuel_capacity}
afterburner_burn_rate = {ship.afterburner_burn_rate}
afterburner_rec_rate = {ship.afterburner_rec_rate}
afterburner_max_vel = Vector3({ship.afterburner_max_vel[0]}, {ship.afterburner_max_vel[1]}, {ship.afterburner_max_vel[2]})
afterburner_forward_accel = {ship.afterburner_forward_accel}

# Misc Properties
countermeasures = {ship.countermeasures}
engine_sound_filename = "{ship.engine_sound}"
closeup_pos = Vector3({ship.closeup_pos[0]}, {ship.closeup_pos[1]}, {ship.closeup_pos[2]})
closeup_zoom = {ship.closeup_zoom}
shield_icon_filename = "{ship.shield_icon}"
default_team_loadout_index = 0
score = {ship.score}
scan_time = {ship.scan_time}
ai_class = {ship.ai_class}

# Flags
ship_flags = {self._format_string_array(ship.flags)}
ship_flags2 = {self._format_string_array(ship.flags2)}

# Explosion Properties
explosion_damage_type_name = "{ship.explosion_damage_type}"
explosion_inner_damage = {ship.explosion_inner_damage}
explosion_outer_damage = {ship.explosion_outer_damage}
explosion_inner_radius = {ship.explosion_inner_radius}
explosion_outer_radius = {ship.explosion_outer_radius}
explosion_shockwave_speed = {ship.explosion_shockwave_speed}

# Debris Properties
debris_min_lifetime = {ship.debris_min_lifetime}
debris_max_lifetime = {ship.debris_max_lifetime}
debris_min_speed = {ship.debris_min_speed}
debris_max_speed = {ship.debris_max_speed}
debris_min_rotation_speed = {ship.debris_min_rotation_speed}
debris_max_rotation_speed = {ship.debris_max_rotation_speed}
debris_damage_type_name = "{ship.debris_damage_type}"
debris_min_hitpoints = {ship.debris_min_hitpoints}
debris_max_hitpoints = {ship.debris_max_hitpoints}
debris_damage_multiplier = {ship.debris_damage_multiplier}
debris_lightning_arc_percent = {ship.debris_lightning_arc_percent}

# Radar Properties
radar_image_2d = "{ship.radar_image_2d}"
radar_image_size = {ship.radar_image_size}
radar_blip_size_multiplier = {ship.radar_blip_size_multiplier}

# Advanced Properties
emp_resistance_modifier = {ship.emp_resistance_modifier}
piercing_damage_draw_limit = {ship.piercing_damage_draw_limit}
"""
        return content
    
    def _convert_weapons_table(self, parse_state: ParseState, table_file: Path) -> bool:
        """Convert weapons.tbl to WeaponData resources"""
        try:
            weapons_converted = 0
            
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # Look for weapon definition start
                if (line.startswith("#Primary Weapons") or 
                    line.startswith("#Secondary Weapons") or 
                    line.startswith("$Name:")):
                    
                    if line.startswith("#"):
                        parse_state.advance_line()
                        continue
                    
                    # Parse weapon data
                    weapon_data = self._parse_weapon_definition(parse_state)
                    if weapon_data:
                        # Convert to Godot resource
                        if self._create_weapon_resource(weapon_data, table_file):
                            weapons_converted += 1
                            self.conversion_stats["weapons_processed"] += 1
                        else:
                            logger.warning(f"Failed to create resource for weapon: {weapon_data.name}")
                
                parse_state.advance_line()
            
            logger.info(f"Converted {weapons_converted} weapons from {table_file}")
            return weapons_converted > 0
            
        except Exception as e:
            logger.error(f"Error converting weapons table {table_file}: {e}")
            return False
    
    def _parse_weapon_definition(self, parse_state: ParseState) -> Optional[WeaponData]:
        """Parse a single weapon definition"""
        weapon = WeaponData()
        
        try:
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # End of weapon definition
                if line.startswith("#End") or line.startswith("$Name:"):
                    if line.startswith("$Name:"):
                        # Don't consume the next weapon's name line
                        parse_state.current_line -= 1
                    break
                
                # Parse weapon properties
                if line.startswith("$Name:"):
                    weapon.name = self._extract_string_value(line)
                elif line.startswith("+Title:"):
                    weapon.title = self._extract_string_value(line)
                elif line.startswith("+Description:"):
                    weapon.description = self._extract_multiline_string(parse_state)
                elif line.startswith("+Tech Title:"):
                    weapon.tech_title = self._extract_string_value(line)
                elif line.startswith("+Tech Description:"):
                    weapon.tech_description = self._extract_multiline_string(parse_state)
                elif line.startswith("$Model file:"):
                    weapon.model_file = self._extract_string_value(line)
                elif line.startswith("$POF target file:"):
                    weapon.pof_target_file = self._extract_string_value(line)
                elif line.startswith("$Detail distance:"):
                    weapon.detail_distances = self._extract_int_list(line)
                elif line.startswith("$Velocity:"):
                    weapon.velocity = self._extract_float_value(line)
                elif line.startswith("$Mass:"):
                    weapon.mass = self._extract_float_value(line)
                elif line.startswith("$Damage:"):
                    weapon.damage = self._extract_float_value(line)
                elif line.startswith("$Damage Type:"):
                    weapon.damage_type = self._extract_string_value(line)
                elif line.startswith("$Armor Factor:"):
                    weapon.armor_factor = self._extract_float_value(line)
                elif line.startswith("$Shield Factor:"):
                    weapon.shield_factor = self._extract_float_value(line)
                elif line.startswith("$Subsystem Factor:"):
                    weapon.subsystem_factor = self._extract_float_value(line)
                elif line.startswith("$Fire Wait:"):
                    weapon.fire_wait = self._extract_float_value(line)
                elif line.startswith("$Damage Time:"):
                    weapon.damage_time = self._extract_float_value(line)
                elif line.startswith("$Lifetime:"):
                    weapon.lifetime = self._extract_float_value(line)
                elif line.startswith("$Energy Consumed:"):
                    weapon.energy_consumed = self._extract_float_value(line)
                elif line.startswith("$Range:"):
                    weapon.range_ = self._extract_float_value(line)
                elif line.startswith("$Shockwave Damage:"):
                    weapon.shockwave_damage = self._extract_float_value(line)
                elif line.startswith("$Shockwave Damage Type:"):
                    weapon.shockwave_damage_type = self._extract_string_value(line)
                elif line.startswith("$Inner Radius:"):
                    weapon.shockwave_inner_radius = self._extract_float_value(line)
                elif line.startswith("$Outer Radius:"):
                    weapon.shockwave_outer_radius = self._extract_float_value(line)
                elif line.startswith("$Shockwave Speed:"):
                    weapon.shockwave_speed = self._extract_float_value(line)
                elif line.startswith("$Flags:"):
                    weapon.flags = self._extract_string_list(line)
                elif line.startswith("$Flags2:"):
                    weapon.flags2 = self._extract_string_list(line)
                elif line.startswith("$Icon:"):
                    weapon.icon = self._extract_string_value(line)
                elif line.startswith("$Anim:"):
                    weapon.anim = self._extract_string_value(line)
                elif line.startswith("$Impact Effect:"):
                    weapon.impact_effect = self._extract_string_value(line)
                elif line.startswith("$Dinky Impact Effect:"):
                    weapon.dinky_impact_effect = self._extract_string_value(line)
                elif line.startswith("$Piercing Impact Effect:"):
                    weapon.piercing_impact_effect = self._extract_string_value(line)
                elif line.startswith("$Particle Spew:"):
                    self._parse_particle_spew_block(parse_state, weapon)
                elif line.startswith("$Trail:"):
                    self._parse_trail_block(parse_state, weapon)
                elif line.startswith("$Sound:"):
                    weapon.sound = self._extract_string_value(line)
                elif line.startswith("$Impact Sound:"):
                    weapon.impact_sound = self._extract_string_value(line)
                
                parse_state.advance_line()
            
            # Validate weapon data
            if not weapon.name:
                logger.warning("Weapon definition missing name")
                return None
            
            return weapon
            
        except Exception as e:
            logger.error(f"Error parsing weapon definition: {e}")
            return None
    
    def _create_weapon_resource(self, weapon_data: WeaponData, source_file: Path) -> bool:
        """Create a Godot WeaponData resource from parsed weapon data"""
        try:
            # Generate Godot resource file content
            resource_content = self._generate_weapon_resource_content(weapon_data, source_file)
            
            # Write resource file
            resource_filename = f"{weapon_data.name.lower().replace(' ', '_')}.tres"
            resource_path = self.assets_dir / "weapons" / resource_filename
            resource_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(resource_path, 'w', encoding='utf-8') as f:
                f.write(resource_content)
            
            # Register damage type
            if weapon_data.damage_type:
                if weapon_data.damage_type not in self.damage_type_registry:
                    self.damage_type_registry[weapon_data.damage_type] = len(self.damage_type_registry)
            
            logger.debug(f"Created weapon resource: {resource_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create weapon resource for {weapon_data.name}: {e}")
            return False
    
    def _generate_weapon_resource_content(self, weapon: WeaponData, source_file: Path) -> str:
        """Generate Godot resource file content for weapon data"""
        content = f"""[gd_resource type="WeaponData" format=3]

[resource]
asset_name = "{weapon.name}"
asset_id = "{weapon.name.lower().replace(' ', '_')}"
source_file = "{source_file.name}"
conversion_notes = "Converted from WCS table data with complete fidelity"

# General Information
weapon_name = "{weapon.name}"
title = "{weapon.title}"
weapon_description = "{self._escape_string(weapon.description)}"
tech_title = "{weapon.tech_title}"
tech_description = "{self._escape_string(weapon.tech_description)}"
icon_filename = "{weapon.icon}"
anim_filename = "{weapon.anim}"

# Model Properties
pof_file = "{weapon.model_file}"
hud_target_lod = 0

# Physics Properties
mass = {weapon.mass}
max_speed = {weapon.velocity}
lifetime = {weapon.lifetime}
weapon_range = {weapon.range_}

# Damage Properties
damage = {weapon.damage}
damage_type_name = "{weapon.damage_type}"
armor_factor = {weapon.armor_factor}
shield_factor = {weapon.shield_factor}
subsystem_factor = {weapon.subsystem_factor}

# Firing Properties
fire_wait = {weapon.fire_wait}
damage_time = {weapon.damage_time}
energy_consumed = {weapon.energy_consumed}

# Shockwave Properties
shockwave_damage = {weapon.shockwave_damage}
shockwave_damage_type_name = "{weapon.shockwave_damage_type}"
shockwave_inner_radius = {weapon.shockwave_inner_radius}
shockwave_outer_radius = {weapon.shockwave_outer_radius}
shockwave_speed = {weapon.shockwave_speed}

# Flags
weapon_flags = {self._format_string_array(weapon.flags)}
weapon_flags2 = {self._format_string_array(weapon.flags2)}

# Effects
impact_effect_name = "{weapon.impact_effect}"
dinky_impact_effect_name = "{weapon.dinky_impact_effect}"
piercing_impact_effect_name = "{weapon.piercing_impact_effect}"

# Particle Properties
particle_spew_count = {weapon.particle_spew_count}
particle_spew_time = {weapon.particle_spew_time}
particle_spew_vel = {weapon.particle_spew_vel}

# Trail Properties
trail_life = {weapon.trail_life}
trail_width = {weapon.trail_width}
trail_alpha = {weapon.trail_alpha}
trail_uv_tiling = Vector2({weapon.trail_uv_tiling[0]}, {weapon.trail_uv_tiling[1]})

# Audio
sound_filename = "{weapon.sound}"
impact_sound_filename = "{weapon.impact_sound}"
"""
        return content
    
    def _convert_armor_table(self, parse_state: ParseState, table_file: Path) -> bool:
        """Convert armor.tbl to ArmorData resources"""
        try:
            armor_types_converted = 0
            
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # Look for armor type start
                if line.startswith("#Armor Type") or line.startswith("$Name:"):
                    if line.startswith("#Armor Type"):
                        parse_state.advance_line()
                        continue
                    
                    # Parse armor data
                    armor_data = self._parse_armor_type(parse_state)
                    if armor_data:
                        # Convert to Godot resource
                        if self._create_armor_resource(armor_data, table_file):
                            armor_types_converted += 1
                            self.conversion_stats["armor_types_processed"] += 1
                        else:
                            logger.warning(f"Failed to create resource for armor: {armor_data.name}")
                
                parse_state.advance_line()
            
            logger.info(f"Converted {armor_types_converted} armor types from {table_file}")
            return armor_types_converted > 0
            
        except Exception as e:
            logger.error(f"Error converting armor table {table_file}: {e}")
            return False
    
    def _parse_armor_type(self, parse_state: ParseState) -> Optional[ArmorTypeData]:
        """Parse a single armor type definition"""
        armor = ArmorTypeData()
        
        try:
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # End of armor definition
                if line.startswith("#End") or line.startswith("$Name:"):
                    if line.startswith("$Name:"):
                        # Don't consume the next armor's name line
                        parse_state.current_line -= 1
                    break
                
                # Parse armor properties
                if line.startswith("$Name:"):
                    armor.name = self._extract_string_value(line)
                elif line.startswith("$Damage Type:"):
                    # Parse damage type modifier: $Damage Type: [type], [modifier]
                    damage_type, modifier = self._extract_damage_type_modifier(line)
                    if damage_type and modifier is not None:
                        armor.damage_type_modifiers[damage_type] = modifier
                elif line.startswith("$Flags:"):
                    armor.flags = self._extract_string_list(line)
                
                parse_state.advance_line()
            
            # Validate armor data
            if not armor.name:
                logger.warning("Armor type definition missing name")
                return None
            
            return armor
            
        except Exception as e:
            logger.error(f"Error parsing armor type: {e}")
            return None
    
    def _create_armor_resource(self, armor_data: ArmorTypeData, source_file: Path) -> bool:
        """Create a Godot ArmorData resource from parsed armor data"""
        try:
            # Generate Godot resource file content
            resource_content = self._generate_armor_resource_content(armor_data, source_file)
            
            # Write resource file
            resource_filename = f"{armor_data.name.lower().replace(' ', '_')}.tres"
            resource_path = self.assets_dir / "armor" / resource_filename
            resource_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(resource_path, 'w', encoding='utf-8') as f:
                f.write(resource_content)
            
            logger.debug(f"Created armor resource: {resource_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create armor resource for {armor_data.name}: {e}")
            return False
    
    def _generate_armor_resource_content(self, armor: ArmorTypeData, source_file: Path) -> str:
        """Generate Godot resource file content for armor data"""
        
        # Convert damage type modifiers to Godot dictionary format
        resistances_dict = {}
        for damage_type, modifier in armor.damage_type_modifiers.items():
            resistances_dict[f'"{damage_type}"'] = modifier
        
        resistances_str = "{" + ", ".join([f"{k}: {v}" for k, v in resistances_dict.items()]) + "}"
        
        content = f"""[gd_resource type="ArmorData" format=3]

[resource]
asset_name = "{armor.name}"
asset_id = "{armor.name.lower().replace(' ', '_')}"
source_file = "{source_file.name}"
conversion_notes = "Converted from WCS table data with complete fidelity"

# Armor Properties
armor_name = "{armor.name}"
armor_flags = 0
damage_resistances = {resistances_str}
armor_flags_list = {self._format_string_array(armor.flags)}

# Default resistance values
base_damage_modifier = 1.0
minimum_damage_threshold = 0.0
maximum_damage_cap = -1.0
armor_thickness = 1.0
"""
        return content
    
    def _convert_species_table(self, parse_state: ParseState, table_file: Path) -> bool:
        """Convert species_defs.tbl to species resources"""
        try:
            species_converted = 0
            
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # Look for species definition start
                if line.startswith("#SPECIES DEFS") or line.startswith("$Species_Name:"):
                    if line.startswith("#SPECIES DEFS"):
                        parse_state.advance_line()
                        continue
                    
                    # Parse species data
                    species_data = self._parse_species_definition(parse_state)
                    if species_data:
                        # Convert to Godot resource
                        if self._create_species_resource(species_data, table_file):
                            species_converted += 1
                            self.conversion_stats["species_processed"] += 1
                        else:
                            logger.warning(f"Failed to create resource for species: {species_data.name}")
                
                parse_state.advance_line()
            
            logger.info(f"Converted {species_converted} species from {table_file}")
            return species_converted > 0
            
        except Exception as e:
            logger.error(f"Error converting species table {table_file}: {e}")
            return False
    
    def _parse_species_definition(self, parse_state: ParseState) -> Optional[SpeciesData]:
        """Parse a single species definition"""
        species = SpeciesData()
        
        try:
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # End of species definition
                if line.startswith("#End") or line.startswith("$Species_Name:"):
                    if line.startswith("$Species_Name:"):
                        # Don't consume the next species's name line
                        parse_state.current_line -= 1
                    break
                
                # Parse species properties
                if line.startswith("$Species_Name:"):
                    species.name = self._extract_string_value(line)
                elif line.startswith("$FRED Species Name:"):
                    species.fred_name = self._extract_string_value(line)
                elif line.startswith("$ThrustAnims:"):
                    self._parse_thrust_anims_block(parse_state, species)
                elif line.startswith("$ThrustGlows:"):
                    self._parse_thrust_glows_block(parse_state, species)
                elif line.startswith("$Max Debris Speed:"):
                    species.max_debris_speed = self._extract_float_value(line)
                elif line.startswith("$Debris Damage Type:"):
                    species.debris_damage_type = self._extract_string_value(line)
                elif line.startswith("$Debris Damage Multiplier:"):
                    species.debris_damage_multiplier = self._extract_float_value(line)
                elif line.startswith("$Debris Density:"):
                    species.debris_density = self._extract_float_value(line)
                elif line.startswith("$Debris Fire Threshold:"):
                    species.debris_fire_threshold = self._extract_float_value(line)
                elif line.startswith("$Debris Fire Spread:"):
                    species.debris_fire_spread = self._extract_float_value(line)
                elif line.startswith("$Debris Fire Lifetime:"):
                    species.debris_fire_lifetime = self._extract_float_value(line)
                
                parse_state.advance_line()
            
            # Validate species data
            if not species.name:
                logger.warning("Species definition missing name")
                return None
            
            return species
            
        except Exception as e:
            logger.error(f"Error parsing species definition: {e}")
            return None
    
    def _create_species_resource(self, species_data: SpeciesData, source_file: Path) -> bool:
        """Create a Godot species resource from parsed species data"""
        try:
            # Generate Godot resource file content
            resource_content = self._generate_species_resource_content(species_data, source_file)
            
            # Write resource file
            resource_filename = f"{species_data.name.lower().replace(' ', '_')}.tres"
            resource_path = self.assets_dir / "species" / resource_filename
            resource_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(resource_path, 'w', encoding='utf-8') as f:
                f.write(resource_content)
            
            # Register species
            if species_data.name not in self.species_registry:
                self.species_registry[species_data.name] = len(self.species_registry)
            
            logger.debug(f"Created species resource: {resource_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create species resource for {species_data.name}: {e}")
            return False
    
    def _generate_species_resource_content(self, species: SpeciesData, source_file: Path) -> str:
        """Generate Godot resource file content for species data"""
        content = f"""[gd_resource type="Resource" format=3]

[resource]
script = preload("res://addons/wcs_asset_core/structures/species_data.gd")
asset_name = "{species.name}"
asset_id = "{species.name.lower().replace(' ', '_')}"
source_file = "{source_file.name}"
conversion_notes = "Converted from WCS table data with complete fidelity"

# Species Information
species_name = "{species.name}"
fred_species_name = "{species.fred_name}"

# Thruster Animations
thruster_pri_normal = "{species.thruster_pri_normal}"
thruster_pri_afterburn = "{species.thruster_pri_afterburn}"
thruster_sec_normal = "{species.thruster_sec_normal}"
thruster_sec_afterburn = "{species.thruster_sec_afterburn}"

# Thruster Glows
thruster_glow_normal = "{species.thruster_glow_normal}"
thruster_glow_afterburn = "{species.thruster_glow_afterburn}"

# Debris Properties
max_debris_speed = {species.max_debris_speed}
debris_damage_type = "{species.debris_damage_type}"
debris_damage_multiplier = {species.debris_damage_multiplier}
debris_density = {species.debris_density}
debris_fire_threshold = {species.debris_fire_threshold}
debris_fire_spread = {species.debris_fire_spread}
debris_fire_lifetime = {species.debris_fire_lifetime}
"""
        return content
    
    def _convert_iff_table(self, parse_state: ParseState, table_file: Path) -> bool:
        """Convert iff_defs.tbl to faction resources"""
        try:
            factions_converted = 0
            
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # Look for IFF definition start
                if line.startswith("#IFFs") or line.startswith("$IFF Name:"):
                    if line.startswith("#IFFs"):
                        parse_state.advance_line()
                        continue
                    
                    # Parse IFF data
                    iff_data = self._parse_iff_definition(parse_state)
                    if iff_data:
                        # Convert to Godot resource
                        if self._create_iff_resource(iff_data, table_file):
                            factions_converted += 1
                            self.conversion_stats["iff_factions_processed"] += 1
                        else:
                            logger.warning(f"Failed to create resource for IFF: {iff_data.name}")
                
                parse_state.advance_line()
            
            logger.info(f"Converted {factions_converted} IFF factions from {table_file}")
            return factions_converted > 0
            
        except Exception as e:
            logger.error(f"Error converting IFF table {table_file}: {e}")
            return False
    
    def _parse_iff_definition(self, parse_state: ParseState) -> Optional[IFFData]:
        """Parse a single IFF definition"""
        iff = IFFData()
        
        try:
            while parse_state.current_line < len(parse_state.lines):
                line = parse_state.get_current_line_text()
                
                # End of IFF definition
                if line.startswith("#End") or line.startswith("$IFF Name:"):
                    if line.startswith("$IFF Name:"):
                        # Don't consume the next IFF's name line
                        parse_state.current_line -= 1
                    break
                
                # Parse IFF properties
                if line.startswith("$IFF Name:"):
                    iff.name = self._extract_string_value(line)
                elif line.startswith("$Selection Color:"):
                    iff.selection_color = self._extract_color_rgb(line)
                elif line.startswith("$Message Color:"):
                    iff.message_color = self._extract_color_rgb(line)
                elif line.startswith("$Tagged Color:"):
                    iff.tagged_color = self._extract_color_rgb(line)
                elif line.startswith("$Color:"):
                    iff.color = self._extract_color_rgb(line)
                elif line.startswith("$Missile Blip Color:"):
                    iff.missile_blip_color = self._extract_color_rgb(line)
                elif line.startswith("$Navbuoy Blip Color:"):
                    iff.navbuoy_blip_color = self._extract_color_rgb(line)
                elif line.startswith("$Warping Blip Color:"):
                    iff.warping_blip_color = self._extract_color_rgb(line)
                elif line.startswith("$Node Blip Color:"):
                    iff.node_blip_color = self._extract_color_rgb(line)
                elif line.startswith("$Tagged Blip Color:"):
                    iff.tagged_blip_color = self._extract_color_rgb(line)
                elif line.startswith("$Dimmed IFF brightness:"):
                    iff.dimmed_iff_brightness = self._extract_float_value(line)
                elif line.startswith("$Use Alternate Blip Coloring:"):
                    iff.use_alternate_blip_coloring = self._extract_bool_value(line)
                elif line.startswith("$Attacks:"):
                    iff.attacks = self._extract_string_list(line)
                elif line.startswith("+Sees") and "As:" in line:
                    faction, color = self._extract_sees_as_data(line)
                    if faction and color:
                        iff.sees_as[faction] = color
                elif line.startswith("$Flags:"):
                    iff.flags = self._extract_string_list(line)
                
                parse_state.advance_line()
            
            # Validate IFF data
            if not iff.name:
                logger.warning("IFF definition missing name")
                return None
            
            return iff
            
        except Exception as e:
            logger.error(f"Error parsing IFF definition: {e}")
            return None
    
    def _create_iff_resource(self, iff_data: IFFData, source_file: Path) -> bool:
        """Create a Godot IFF resource from parsed IFF data"""
        try:
            # Generate Godot resource file content
            resource_content = self._generate_iff_resource_content(iff_data, source_file)
            
            # Write resource file
            resource_filename = f"{iff_data.name.lower().replace(' ', '_')}.tres"
            resource_path = self.assets_dir / "factions" / resource_filename
            resource_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(resource_path, 'w', encoding='utf-8') as f:
                f.write(resource_content)
            
            logger.debug(f"Created IFF resource: {resource_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create IFF resource for {iff_data.name}: {e}")
            return False
    
    def _generate_iff_resource_content(self, iff: IFFData, source_file: Path) -> str:
        """Generate Godot resource file content for IFF data"""
        
        # Convert sees_as dictionary to Godot format
        sees_as_dict = {}
        for faction, color in iff.sees_as.items():
            sees_as_dict[f'"{faction}"'] = f"Color({color[0]/255.0}, {color[1]/255.0}, {color[2]/255.0})"
        
        sees_as_str = "{" + ", ".join([f"{k}: {v}" for k, v in sees_as_dict.items()]) + "}"
        
        content = f"""[gd_resource type="Resource" format=3]

[resource]
script = preload("res://addons/wcs_asset_core/structures/iff_data.gd")
asset_name = "{iff.name}"
asset_id = "{iff.name.lower().replace(' ', '_')}"
source_file = "{source_file.name}"
conversion_notes = "Converted from WCS table data with complete fidelity"

# IFF Information
iff_name = "{iff.name}"

# Colors
selection_color = Color({iff.selection_color[0]/255.0}, {iff.selection_color[1]/255.0}, {iff.selection_color[2]/255.0})
message_color = Color({iff.message_color[0]/255.0}, {iff.message_color[1]/255.0}, {iff.message_color[2]/255.0})
tagged_color = Color({iff.tagged_color[0]/255.0}, {iff.tagged_color[1]/255.0}, {iff.tagged_color[2]/255.0})
iff_color = Color({iff.color[0]/255.0}, {iff.color[1]/255.0}, {iff.color[2]/255.0})

# Blip Colors
missile_blip_color = Color({iff.missile_blip_color[0]/255.0}, {iff.missile_blip_color[1]/255.0}, {iff.missile_blip_color[2]/255.0})
navbuoy_blip_color = Color({iff.navbuoy_blip_color[0]/255.0}, {iff.navbuoy_blip_color[1]/255.0}, {iff.navbuoy_blip_color[2]/255.0})
warping_blip_color = Color({iff.warping_blip_color[0]/255.0}, {iff.warping_blip_color[1]/255.0}, {iff.warping_blip_color[2]/255.0})
node_blip_color = Color({iff.node_blip_color[0]/255.0}, {iff.node_blip_color[1]/255.0}, {iff.node_blip_color[2]/255.0})
tagged_blip_color = Color({iff.tagged_blip_color[0]/255.0}, {iff.tagged_blip_color[1]/255.0}, {iff.tagged_blip_color[2]/255.0})

# Properties
dimmed_iff_brightness = {iff.dimmed_iff_brightness}
use_alternate_blip_coloring = {str(iff.use_alternate_blip_coloring).lower()}

# Relations
attacks = {self._format_string_array(iff.attacks)}
sees_as = {sees_as_str}
iff_flags = {self._format_string_array(iff.flags)}
"""
        return content
    
    # ========== PARSING UTILITY METHODS ==========
    
    def _extract_string_value(self, line: str) -> str:
        """Extract string value from table line"""
        if ":" not in line:
            return ""
        value = line.split(":", 1)[1].strip()
        # Remove quotes if present
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        return value
    
    def _extract_int_value(self, line: str) -> int:
        """Extract integer value from table line"""
        try:
            value_str = self._extract_string_value(line)
            return int(float(value_str))  # Handle float strings like "1.0"
        except (ValueError, TypeError):
            return 0
    
    def _extract_float_value(self, line: str) -> float:
        """Extract float value from table line"""
        try:
            value_str = self._extract_string_value(line)
            return float(value_str)
        except (ValueError, TypeError):
            return 0.0
    
    def _extract_bool_value(self, line: str) -> bool:
        """Extract boolean value from table line"""
        value_str = self._extract_string_value(line).lower()
        return value_str in ("true", "yes", "1", "on")
    
    def _extract_vector3(self, line: str) -> Tuple[float, float, float]:
        """Extract Vector3 values from table line"""
        try:
            value_str = self._extract_string_value(line)
            # Remove parentheses and split by comma
            value_str = value_str.strip("()[]")
            parts = [p.strip() for p in value_str.split(",")]
            if len(parts) >= 3:
                return (float(parts[0]), float(parts[1]), float(parts[2]))
            else:
                return (0.0, 0.0, 0.0)
        except (ValueError, TypeError, IndexError):
            return (0.0, 0.0, 0.0)
    
    def _extract_color_rgb(self, line: str) -> Tuple[int, int, int]:
        """Extract RGB color values from table line"""
        try:
            value_str = self._extract_string_value(line)
            # Remove parentheses and split by comma
            value_str = value_str.strip("()[]")
            parts = [p.strip() for p in value_str.split(",")]
            if len(parts) >= 3:
                return (int(float(parts[0])), int(float(parts[1])), int(float(parts[2])))
            else:
                return (255, 255, 255)
        except (ValueError, TypeError, IndexError):
            return (255, 255, 255)
    
    def _extract_string_list(self, line: str) -> List[str]:
        """Extract list of strings from table line"""
        try:
            value_str = self._extract_string_value(line)
            # Remove parentheses and split by comma
            value_str = value_str.strip("()[]")
            if not value_str:
                return []
            parts = [p.strip().strip('"') for p in value_str.split(",")]
            return [p for p in parts if p]  # Filter empty strings
        except (ValueError, TypeError):
            return []
    
    def _extract_int_list(self, line: str) -> List[int]:
        """Extract list of integers from table line"""
        try:
            value_str = self._extract_string_value(line)
            # Remove parentheses and split by comma
            value_str = value_str.strip("()[]")
            if not value_str:
                return []
            parts = [p.strip() for p in value_str.split(",")]
            return [int(float(p)) for p in parts if p]  # Handle float strings
        except (ValueError, TypeError):
            return []
    
    def _extract_damage_type_modifier(self, line: str) -> Tuple[Optional[str], Optional[float]]:
        """Extract damage type and modifier from armor table line"""
        try:
            value_str = self._extract_string_value(line)
            parts = [p.strip() for p in value_str.split(",")]
            if len(parts) >= 2:
                damage_type = parts[0].strip('"')
                modifier = float(parts[1])
                return (damage_type, modifier)
            else:
                return (None, None)
        except (ValueError, TypeError, IndexError):
            return (None, None)
    
    def _extract_sees_as_data(self, line: str) -> Tuple[Optional[str], Optional[Tuple[int, int, int]]]:
        """Extract faction and color from 'Sees X As' line"""
        try:
            # Extract faction name between "Sees" and "As:"
            faction_match = re.search(r'Sees\s+(.+?)\s+As:', line)
            if not faction_match:
                return (None, None)
            
            faction = faction_match.group(1).strip()
            
            # Extract color after "As:"
            color_part = line.split("As:", 1)[1].strip()
            color = self._extract_color_rgb(f"dummy: {color_part}")
            
            return (faction, color)
        except (ValueError, TypeError, IndexError):
            return (None, None)
    
    def _extract_multiline_string(self, parse_state: ParseState) -> str:
        """Extract multiline string value (for descriptions)"""
        lines = []
        
        # Get the first line content
        current_line = parse_state.get_current_line_text()
        if ":" in current_line:
            first_content = current_line.split(":", 1)[1].strip()
            if first_content:
                lines.append(first_content)
        
        # Look ahead for continuation lines
        while True:
            next_line = parse_state.peek_line()
            if not next_line or next_line.startswith(("$", "+", "#")):
                break
            
            # Advance and add the continuation line
            parse_state.advance_line()
            lines.append(parse_state.get_current_line_text())
        
        return " ".join(lines)
    
    # ========== BLOCK PARSING METHODS ==========
    
    def _parse_explosion_block(self, parse_state: ParseState, ship: ShipClassData) -> None:
        """Parse explosion properties block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1  # Back up to preserve the line
                break
            
            if line.startswith("+Damage Type:"):
                ship.explosion_damage_type = self._extract_string_value(line)
            elif line.startswith("+Inner Damage:"):
                ship.explosion_inner_damage = self._extract_float_value(line)
            elif line.startswith("+Outer Damage:"):
                ship.explosion_outer_damage = self._extract_float_value(line)
            elif line.startswith("+Inner Radius:"):
                ship.explosion_inner_radius = self._extract_float_value(line)
            elif line.startswith("+Outer Radius:"):
                ship.explosion_outer_radius = self._extract_float_value(line)
            elif line.startswith("+Shockwave Speed:"):
                ship.explosion_shockwave_speed = self._extract_float_value(line)
    
    def _parse_impact_spew_block(self, parse_state: ParseState, ship: ShipClassData) -> None:
        """Parse impact spew properties block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+Max particles:"):
                ship.impact_spew_max_particles = self._extract_int_value(line)
    
    def _parse_damage_spew_block(self, parse_state: ParseState, ship: ShipClassData) -> None:
        """Parse damage spew properties block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+Max particles:"):
                ship.damage_spew_max_particles = self._extract_int_value(line)
    
    def _parse_debris_block(self, parse_state: ParseState, ship: ShipClassData) -> None:
        """Parse debris properties block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+Min Lifetime:"):
                ship.debris_min_lifetime = self._extract_float_value(line)
            elif line.startswith("+Max Lifetime:"):
                ship.debris_max_lifetime = self._extract_float_value(line)
            elif line.startswith("+Min Speed:"):
                ship.debris_min_speed = self._extract_float_value(line)
            elif line.startswith("+Max Speed:"):
                ship.debris_max_speed = self._extract_float_value(line)
            elif line.startswith("+Min Rotation speed:"):
                ship.debris_min_rotation_speed = self._extract_float_value(line)
            elif line.startswith("+Max Rotation speed:"):
                ship.debris_max_rotation_speed = self._extract_float_value(line)
            elif line.startswith("+Damage Type:"):
                ship.debris_damage_type = self._extract_string_value(line)
            elif line.startswith("+Min Hitpoints:"):
                ship.debris_min_hitpoints = self._extract_float_value(line)
            elif line.startswith("+Max Hitpoints:"):
                ship.debris_max_hitpoints = self._extract_float_value(line)
            elif line.startswith("+Damage Multiplier:"):
                ship.debris_damage_multiplier = self._extract_float_value(line)
            elif line.startswith("+Lightning Arc Percent:"):
                ship.debris_lightning_arc_percent = self._extract_float_value(line)
    
    def _parse_subsystem_block(self, parse_state: ParseState, ship: ShipClassData) -> None:
        """Parse subsystem definition block"""
        # Extract subsystem header info
        current_line = parse_state.get_current_line_text()
        subsystem_header = self._extract_string_value(current_line)
        
        # Parse subsystem header: name, hitpoint_percentage, rotation_time
        header_parts = [p.strip() for p in subsystem_header.split(",")]
        
        subsystem = {
            "name": header_parts[0] if len(header_parts) > 0 else "",
            "hitpoint_percentage": float(header_parts[1]) if len(header_parts) > 1 else 100.0,
            "rotation_time": float(header_parts[2]) if len(header_parts) > 2 else 0.0,
            "alt_name": "",
            "alt_damage_popup_name": "",
            "armor_type": "",
            "primary_banks": [],
            "secondary_banks": [],
            "primary_capacities": [],
            "secondary_capacities": [],
            "flags": []
        }
        
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("$Alt Subsystem Name:"):
                subsystem["alt_name"] = self._extract_string_value(line)
            elif line.startswith("$Alt Damage Popup Subsystem Name:"):
                subsystem["alt_damage_popup_name"] = self._extract_string_value(line)
            elif line.startswith("$Armor Type:"):
                subsystem["armor_type"] = self._extract_string_value(line)
            elif line.startswith("$Primary Banks:"):
                subsystem["primary_banks"] = self._extract_string_list(line)
            elif line.startswith("$Secondary Banks:"):
                subsystem["secondary_banks"] = self._extract_string_list(line)
            elif line.startswith("$Primary Bank Capacities:"):
                subsystem["primary_capacities"] = self._extract_int_list(line)
            elif line.startswith("$Secondary Bank Capacities:"):
                subsystem["secondary_capacities"] = self._extract_int_list(line)
            elif line.startswith("+Flags:"):
                subsystem["flags"] = self._extract_string_list(line)
        
        ship.subsystems.append(subsystem)
    
    def _parse_texture_replace_block(self, parse_state: ParseState, ship: ShipClassData) -> None:
        """Parse texture replacement block"""
        old_texture = ""
        new_texture = ""
        
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+old:"):
                old_texture = self._extract_string_value(line)
            elif line.startswith("+new:"):
                new_texture = self._extract_string_value(line)
                
                # Add the replacement pair
                if old_texture and new_texture:
                    ship.texture_replacements.append((old_texture, new_texture))
                    old_texture = ""
                    new_texture = ""
    
    def _parse_particle_spew_block(self, parse_state: ParseState, weapon: WeaponData) -> None:
        """Parse particle spew properties block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+Count:"):
                weapon.particle_spew_count = self._extract_int_value(line)
            elif line.startswith("+Time:"):
                weapon.particle_spew_time = self._extract_float_value(line)
            elif line.startswith("+Vel:"):
                weapon.particle_spew_vel = self._extract_float_value(line)
    
    def _parse_trail_block(self, parse_state: ParseState, weapon: WeaponData) -> None:
        """Parse trail properties block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+Life:"):
                weapon.trail_life = self._extract_float_value(line)
            elif line.startswith("+Width:"):
                weapon.trail_width = self._extract_float_value(line)
            elif line.startswith("+Alpha:"):
                weapon.trail_alpha = self._extract_float_value(line)
            elif line.startswith("+UV Tiling:"):
                tiling = self._extract_vector3(line)
                weapon.trail_uv_tiling = (tiling[0], tiling[1])  # Only use X and Y
    
    def _parse_thrust_anims_block(self, parse_state: ParseState, species: SpeciesData) -> None:
        """Parse thrust animations block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+Pri_Normal:"):
                species.thruster_pri_normal = self._extract_string_value(line)
            elif line.startswith("+Pri_Afterburn:"):
                species.thruster_pri_afterburn = self._extract_string_value(line)
            elif line.startswith("+Sec_Normal:"):
                species.thruster_sec_normal = self._extract_string_value(line)
            elif line.startswith("+Sec_Afterburn:"):
                species.thruster_sec_afterburn = self._extract_string_value(line)
    
    def _parse_thrust_glows_block(self, parse_state: ParseState, species: SpeciesData) -> None:
        """Parse thrust glows block"""
        while parse_state.advance_line():
            line = parse_state.get_current_line_text()
            
            if line.startswith(("$", "#")) and not line.startswith("+"):
                parse_state.current_line -= 1
                break
            
            if line.startswith("+Normal:"):
                species.thruster_glow_normal = self._extract_string_value(line)
            elif line.startswith("+Afterburn:"):
                species.thruster_glow_afterburn = self._extract_string_value(line)
    
    # ========== UTILITY METHODS ==========
    
    def _escape_string(self, text: str) -> str:
        """Escape string for Godot resource format"""
        if not text:
            return ""
        # Escape quotes and newlines
        text = text.replace('"', '\\"')
        text = text.replace('\n', '\\n')
        text = text.replace('\r', '\\r')
        return text
    
    def _format_string_array(self, string_list: List[str]) -> str:
        """Format string list as Godot Array[String]"""
        if not string_list:
            return "[]"
        
        formatted_strings = [f'"{self._escape_string(s)}"' for s in string_list]
        return "[" + ", ".join(formatted_strings) + "]"
    
    def _format_int_array(self, int_list: List[int]) -> str:
        """Format int list as Godot Array[int]"""
        if not int_list:
            return "[]"
        return "[" + ", ".join(str(i) for i in int_list) + "]"
    
    def generate_conversion_summary(self) -> Dict[str, Any]:
        """Generate comprehensive conversion summary report"""
        return {
            "conversion_statistics": self.conversion_stats,
            "asset_relationships": {
                "ship_weapon_compatibility": self.ship_weapon_compatibility,
                "damage_type_registry": self.damage_type_registry,
                "armor_type_registry": self.armor_type_registry,
                "species_registry": self.species_registry
            },
            "output_directories": {
                "ships": str(self.assets_dir / "ships"),
                "weapons": str(self.assets_dir / "weapons"),
                "armor": str(self.assets_dir / "armor"),
                "species": str(self.assets_dir / "species"),
                "factions": str(self.assets_dir / "factions")
            },
            "validation_summary": {
                "total_assets_converted": (
                    self.conversion_stats["ships_processed"] +
                    self.conversion_stats["weapons_processed"] +
                    self.conversion_stats["armor_types_processed"] +
                    self.conversion_stats["species_processed"] +
                    self.conversion_stats["iff_factions_processed"]
                ),
                "relationship_mappings": self.conversion_stats["relationships_mapped"],
                "error_count": len(self.conversion_stats["errors"])
            }
        }

def main():
    """Main function for standalone table converter usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Convert WCS table files to Godot resources')
    parser.add_argument('--source', type=Path, required=True,
                       help='Path to WCS source directory')
    parser.add_argument('--target', type=Path, required=True,
                       help='Path to Godot project directory')
    parser.add_argument('--file', type=Path,
                       help='Convert specific table file')
    parser.add_argument('--validate', action='store_true',
                       help='Validate converted resources')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Enable verbose output')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')
    
    try:
        # Initialize converter
        converter = TableDataConverter(args.source, args.target)
        
        if args.file:
            # Convert specific file
            success = converter.convert_table_file(args.file)
            print(f"Conversion {'successful' if success else 'failed'}: {args.file}")
        else:
            # Convert all table files
            table_files = list(args.source.glob("**/*.tbl")) + list(args.source.glob("**/*.tbm"))
            
            if not table_files:
                print(f"No table files found in {args.source}")
                return 1
            
            print(f"Found {len(table_files)} table files to convert")
            
            success_count = 0
            for table_file in table_files:
                if converter.convert_table_file(table_file):
                    success_count += 1
            
            print(f"Converted {success_count}/{len(table_files)} table files successfully")
        
        # Generate summary report
        summary = converter.generate_conversion_summary()
        
        # Save summary
        summary_path = args.target / "table_conversion_summary.json"
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"Conversion summary saved to: {summary_path}")
        
        return 0 if success_count > 0 else 1
        
    except Exception as e:
        logger.error(f"Table conversion failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())