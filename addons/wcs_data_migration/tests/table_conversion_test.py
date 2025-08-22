#!/usr/bin/env python3
"""
pytest validation tests for TableDataConverter
Tests the core parsing functionality without Godot dependencies

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-008 - Asset Table Processing
"""

import shutil
import sys
import tempfile
from pathlib import Path

import pytest
# Import from same directory
from table_data_converter import (ArmorTypeData, ParseState, ShipClassData,
                                  TableDataConverter, WeaponData)


def test_parse_state():
    """Test ParseState functionality"""
    print("Testing ParseState...")
    
    lines = ["line1", "line2", "line3"]
    state = ParseState(lines=lines, filename="test.tbl")
    
    assert state.get_current_line_text() == "line1"
    assert state.advance_line() == True
    assert state.get_current_line_text() == "line2"
    assert state.peek_line() == "line3"
    
    print("✓ ParseState tests passed")

def test_ship_parsing():
    """Test ship class parsing"""
    print("Testing ship class parsing...")
    
    # Create test table content
    table_content = """#Ship Classes

$Name: Test Fighter
$Alt name: TF
$Short name: Fighter
$Species: Terran
+Type: Fighter
+Manufacturer: Terran Fleet
+Description: A fast interceptor designed for dogfighting

$POF file: testfighter.pof
$Detail distance: 0, 100, 500, 1000

$Max Velocity: 100, 100, 100
$Rotation Time: 2, 2, 2
$Forward accel: 150
$Forward decel: 120

$Shields: 100
$Hull: 150
$Armor Type: Light Hull

$Primary Weapons: 2
$Secondary Weapons: 1
$Primary Banks: (Laser Cannon, Pulse Cannon)
$Secondary Banks: (Harpoon)

$Flags: (Player Ship, Default Player Ship)

#End
"""
    
    # Test converter initialization
    with tempfile.TemporaryDirectory() as temp_dir:
        source_dir = Path(temp_dir) / "source"
        target_dir = Path(temp_dir) / "target"
        source_dir.mkdir()
        target_dir.mkdir()
        
        converter = TableDataConverter(source_dir, target_dir)
        
        # Create test file
        test_file = source_dir / "ships.tbl"
        with open(test_file, 'w') as f:
            f.write(table_content)
        
        # Test conversion
        success = converter.convert_table_file(test_file)
        assert success, "Ship table conversion should succeed"
        
        # Verify output files were created
        ship_output_dir = target_dir / "assets" / "tables" / "ships"
        assert ship_output_dir.exists(), "Ship output directory should be created"
        
        ship_files = list(ship_output_dir.glob("*.tres"))
        assert len(ship_files) >= 1, "At least one ship resource should be created"
        
        # Test conversion stats
        stats = converter.conversion_stats
        assert stats["ships_processed"] >= 1, "Should have processed at least one ship"
        
    print("✓ Ship parsing tests passed")

def test_weapon_parsing():
    """Test weapon parsing"""
    print("Testing weapon parsing...")
    
    table_content = """#Primary Weapons

$Name: Test Laser
+Title: Test Laser Cannon
+Description: A basic energy weapon for testing

$Model file: testlaser.pof
$Velocity: 450
$Mass: 0.1
$Damage: 15
$Damage Type: Laser
$Fire Wait: 0.25
$Lifetime: 3.0
$Energy Consumed: 5

$Flags: (Player Allowed)

#End
"""
    
    with tempfile.TemporaryDirectory() as temp_dir:
        source_dir = Path(temp_dir) / "source"
        target_dir = Path(temp_dir) / "target"
        source_dir.mkdir()
        target_dir.mkdir()
        
        converter = TableDataConverter(source_dir, target_dir)
        
        # Create test file
        test_file = source_dir / "weapons.tbl"
        with open(test_file, 'w') as f:
            f.write(table_content)
        
        # Test conversion
        success = converter.convert_table_file(test_file)
        assert success, "Weapon table conversion should succeed"
        
        # Verify output
        weapon_output_dir = target_dir / "assets" / "tables" / "weapons"
        assert weapon_output_dir.exists(), "Weapon output directory should be created"
        
        weapon_files = list(weapon_output_dir.glob("*.tres"))
        assert len(weapon_files) >= 1, "At least one weapon resource should be created"
        
        stats = converter.conversion_stats
        assert stats["weapons_processed"] >= 1, "Should have processed at least one weapon"
        
    print("✓ Weapon parsing tests passed")

def test_armor_parsing():
    """Test armor type parsing"""
    print("Testing armor type parsing...")
    
    table_content = """#Armor Type

$Name: Light Hull
$Damage Type: Laser, 1.0
$Damage Type: Impact, 0.8
$Damage Type: Piercing, 1.2
$Flags: (Hull Armor)

#End
"""
    
    with tempfile.TemporaryDirectory() as temp_dir:
        source_dir = Path(temp_dir) / "source"
        target_dir = Path(temp_dir) / "target"
        source_dir.mkdir()
        target_dir.mkdir()
        
        converter = TableDataConverter(source_dir, target_dir)
        
        # Create test file
        test_file = source_dir / "armor.tbl"
        with open(test_file, 'w') as f:
            f.write(table_content)
        
        # Test conversion
        success = converter.convert_table_file(test_file)
        assert success, "Armor table conversion should succeed"
        
        # Verify output
        armor_output_dir = target_dir / "assets" / "tables" / "armor"
        assert armor_output_dir.exists(), "Armor output directory should be created"
        
        armor_files = list(armor_output_dir.glob("*.tres"))
        assert len(armor_files) >= 1, "At least one armor resource should be created"
        
        stats = converter.conversion_stats
        assert stats["armor_types_processed"] >= 1, "Should have processed at least one armor type"
        
    print("✓ Armor parsing tests passed")

def test_data_structures():
    """Test data structure validation"""
    print("Testing data structures...")
    
    # Test ShipClassData
    ship = ShipClassData()
    ship.name = "Test Ship"
    ship.max_velocity = (100.0, 100.0, 100.0)
    ship.shields = 150.0
    ship.hull = 200.0
    
    assert ship.name == "Test Ship"
    assert ship.max_velocity[0] == 100.0
    assert ship.shields == 150.0
    
    # Test WeaponData
    weapon = WeaponData()
    weapon.name = "Test Weapon"
    weapon.damage = 25.0
    weapon.velocity = 500.0
    weapon.fire_wait = 0.5
    
    assert weapon.name == "Test Weapon"
    assert weapon.damage == 25.0
    assert weapon.velocity == 500.0
    
    # Test ArmorTypeData
    armor = ArmorTypeData()
    armor.name = "Test Armor"
    armor.damage_type_modifiers["laser"] = 0.8
    armor.damage_type_modifiers["kinetic"] = 1.2
    
    assert armor.name == "Test Armor"
    assert armor.damage_type_modifiers["laser"] == 0.8
    assert armor.damage_type_modifiers["kinetic"] == 1.2
    
    print("✓ Data structure tests passed")

def test_conversion_summary():
    """Test conversion summary generation"""
    print("Testing conversion summary...")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        source_dir = Path(temp_dir) / "source"
        target_dir = Path(temp_dir) / "target"
        source_dir.mkdir()
        target_dir.mkdir()
        
        converter = TableDataConverter(source_dir, target_dir)
        
        # Generate summary
        summary = converter.generate_conversion_summary()
        
        assert "conversion_statistics" in summary
        assert "asset_relationships" in summary
        assert "output_directories" in summary
        assert "validation_summary" in summary
        
        # Test structure
        stats = summary["conversion_statistics"]
        assert "ships_processed" in stats
        assert "weapons_processed" in stats
        assert "armor_types_processed" in stats
        
        relationships = summary["asset_relationships"]
        assert "ship_weapon_compatibility" in relationships
        assert "damage_type_registry" in relationships
        assert "armor_type_registry" in relationships
        
    print("✓ Conversion summary tests passed")
