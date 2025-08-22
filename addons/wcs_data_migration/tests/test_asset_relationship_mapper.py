#!/usr/bin/env python3
"""
Test suite for AssetRelationshipMapper functionality.

Tests DM-013: Automated Asset Mapping from Table Data
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Mock problematic imports but preserve enums
from enum import Enum


class MockTableType(Enum):
    SHIPS = "ships"
    WEAPONS = "weapons" 
    ARMOR = "armor"
    SPECIES = "species_defs"
    IFF = "iff_defs"
    UNKNOWN = "unknown"

mock_table_converter = Mock()
mock_table_converter.TableType = MockTableType
sys.modules['table_data_converter'] = mock_table_converter

from asset_relationship_mapper import (AssetMapping, AssetRelationship,
                                       AssetRelationshipMapper,
                                       HardcodedAssetMappings)


class TestAssetRelationshipMapper(unittest.TestCase):
    """Test asset relationship mapping functionality"""

    def setUp(self):
        """Set up test environment"""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.source_dir = Path(self.temp_dir.name) / "source"
        self.source_dir.mkdir(parents=True)
        
        self.target_structure = {
            "campaigns": "campaigns/wing_commander_saga",
            "common": "common",
            "ships": "ships",
            "weapons": "weapons"
        }
        
        # Mock the table converter to avoid dependency issues
        with patch('asset_relationship_mapper.TableDataConverter'):
            self.mapper = AssetRelationshipMapper(self.source_dir, self.target_structure)

    def tearDown(self):
        """Clean up test environment"""
        self.temp_dir.cleanup()

    def _create_ships_table(self, ships_data: list) -> Path:
        """Create a test ships.tbl file"""
        ships_table = self.source_dir / "ships.tbl"
        
        content = "#Ship Classes\n\n"
        for ship in ships_data:
            content += f"$Name: {ship['name']}\n"
            if 'model' in ship:
                content += f"$Model File: {ship['model']}\n"
            if 'textures' in ship:
                for texture in ship['textures']:
                    content += f"$Texture Replace: {texture}\n"
            content += "$end_multi_text\n\n"
        
        with open(ships_table, 'w') as f:
            f.write(content)
        
        return ships_table

    def _create_weapons_table(self, weapons_data: list) -> Path:
        """Create a test weapons.tbl file"""
        weapons_table = self.source_dir / "weapons.tbl"
        
        content = "#Weapon Classes\n\n"
        for weapon in weapons_data:
            content += f"$Name: {weapon['name']}\n"
            if 'model' in weapon:
                content += f"$Model File: {weapon['model']}\n"
            if 'sound' in weapon:
                content += f"$LaunchSnd: {weapon['sound']}\n"
            content += "$end_multi_text\n\n"
        
        with open(weapons_table, 'w') as f:
            f.write(content)
        
        return weapons_table

    def test_table_type_detection(self):
        """Test determination of table file types"""
        ships_table = self.source_dir / "ships.tbl"
        weapons_table = self.source_dir / "weapons.tbl"
        unknown_table = self.source_dir / "misc.tbl"
        
        ships_table.touch()
        weapons_table.touch()
        unknown_table.touch()
        
        self.assertEqual(self.mapper._determine_table_type(ships_table).value, "ships")
        self.assertEqual(self.mapper._determine_table_type(weapons_table).value, "weapons")
        self.assertEqual(self.mapper._determine_table_type(unknown_table).value, "unknown")

    def test_ship_relationship_extraction(self):
        """Test extraction of ship asset relationships"""
        ships_data = [
            {
                'name': 'Hornet',
                'model': 'hornet.pof',
                'textures': ['hornet_glow.dds']
            },
            {
                'name': 'Rapier II',
                'model': 'rapier2.pof'
            }
        ]
        
        ships_table = self._create_ships_table(ships_data)
        relationships = self.mapper._extract_ship_relationships(ships_table)
        
        # Check Hornet relationships
        self.assertIn('Hornet', relationships)
        hornet_rels = relationships['Hornet']
        
        # Should have model relationship
        model_rels = [r for r in hornet_rels if r.relationship_type == 'primary_model']
        self.assertEqual(len(model_rels), 1)
        self.assertEqual(model_rels[0].source_path, 'models/hornet.pof')
        self.assertEqual(model_rels[0].parent_entity, 'Hornet')
        
        # Should have generated texture relationships
        texture_rels = [r for r in hornet_rels if r.asset_type == 'texture']
        self.assertGreater(len(texture_rels), 0)

    def test_weapon_relationship_extraction(self):
        """Test extraction of weapon asset relationships"""
        weapons_data = [
            {
                'name': 'Laser Cannon',
                'model': 'laser.pof',
                'sound': 'laser_fire.wav'
            },
            {
                'name': 'Missile',
                'model': 'missile.pof'
            }
        ]
        
        weapons_table = self._create_weapons_table(weapons_data)
        relationships = self.mapper._extract_weapon_relationships(weapons_table)
        
        # Check Laser Cannon relationships
        self.assertIn('Laser Cannon', relationships)
        laser_rels = relationships['Laser Cannon']
        
        # Should have model and sound relationships
        model_rels = [r for r in laser_rels if r.relationship_type == 'primary_model']
        sound_rels = [r for r in laser_rels if r.relationship_type == 'fire_sound']
        
        self.assertEqual(len(model_rels), 1)
        self.assertEqual(len(sound_rels), 1)
        
        self.assertEqual(model_rels[0].source_path, 'models/laser.pof')
        self.assertEqual(sound_rels[0].source_path, 'sounds/laser_fire.wav')

    def test_hardcoded_texture_generation(self):
        """Test generation of hardcoded texture relationships"""
        ship_name = "Hornet"
        model_file = "hornet.pof"
        
        texture_rels = self.mapper._generate_ship_texture_relationships(ship_name, model_file)
        
        # Should generate multiple texture variants
        self.assertGreater(len(texture_rels), 0)
        
        # Check for expected texture types
        rel_types = {rel.relationship_type for rel in texture_rels}
        expected_types = {'glow', 'normal', 'specular', 'reflect', 'shine', 'thruster'}
        self.assertTrue(rel_types.intersection(expected_types))
        
        # All should be optional (not required)
        self.assertTrue(all(not rel.required for rel in texture_rels))

    def test_weapon_effect_generation(self):
        """Test generation of weapon effect relationships"""
        laser_effects = self.mapper._generate_weapon_effect_relationships("Laser Cannon")
        missile_effects = self.mapper._generate_weapon_effect_relationships("Missile")
        
        # Should generate effects for both weapon types
        self.assertGreater(len(laser_effects), 0)
        self.assertGreater(len(missile_effects), 0)
        
        # Check that different weapon types get different effects
        laser_types = {rel.relationship_type for rel in laser_effects}
        missile_types = {rel.relationship_type for rel in missile_effects}
        
        # Both should have some effect types, but they may differ
        self.assertTrue(any('sound_' in t for t in laser_types))
        self.assertTrue(any('sound_' in t for t in missile_types))

    def test_faction_determination(self):
        """Test faction determination from ship names"""
        terran_ships = ["Hornet", "Rapier", "Scimitar"]
        kilrathi_ships = ["Dralthi", "Salthi", "Fralthi Cruiser"]
        
        for ship in terran_ships:
            self.assertEqual(self.mapper._determine_faction(ship), "terran")
        
        for ship in kilrathi_ships:
            self.assertEqual(self.mapper._determine_faction(ship), "kilrathi")

    def test_ship_class_determination(self):
        """Test ship class determination from ship names"""
        fighters = ["Hornet", "Rapier", "Dralthi"]
        capital_ships = ["Bengal Carrier", "Fralthi Cruiser", "Destroyer"]
        
        for ship in fighters:
            self.assertEqual(self.mapper._determine_ship_class(ship), "fighters")
        
        for ship in capital_ships:
            self.assertEqual(self.mapper._determine_ship_class(ship), "capital_ships")

    def test_target_path_generation(self):
        """Test target path generation following target structure"""
        # Ship model path
        ship_path = self.mapper._get_target_path("ship_model", "Hornet", "hornet.pof")
        expected = "campaigns/wing_commander_saga/ships/terran/fighters/hornet/hornet.pof"
        self.assertEqual(ship_path, expected)
        
        # Weapon model path
        weapon_path = self.mapper._get_target_path("weapon_model", "Laser Cannon", "laser.pof")
        expected = "campaigns/wing_commander_saga/weapons/laser_cannon/laser.pof"
        self.assertEqual(weapon_path, expected)
        
        # Common texture path
        texture_path = self.mapper._get_target_path("texture", "Hornet", "metal.dds")
        expected = "common/materials/metal.dds"
        self.assertEqual(texture_path, expected)

    def test_asset_mapping_creation(self):
        """Test creation of complete asset mappings"""
        # Create sample relationships
        relationships = {
            "Hornet": [
                AssetRelationship(
                    source_path="models/hornet.pof",
                    target_path="campaigns/wing_commander_saga/ships/terran/fighters/hornet/hornet.pof",
                    asset_type="model",
                    parent_entity="Hornet",
                    relationship_type="primary_model"
                ),
                AssetRelationship(
                    source_path="textures/hornet_glow.dds",
                    target_path="campaigns/wing_commander_saga/ships/terran/fighters/hornet/hornet_glow.dds",
                    asset_type="texture",
                    parent_entity="Hornet",
                    relationship_type="glow",
                    required=False
                )
            ]
        }
        
        mappings = self.mapper.apply_hardcoded_mappings(relationships)
        
        self.assertIn("Hornet", mappings)
        hornet_mapping = mappings["Hornet"]
        
        self.assertEqual(hornet_mapping.entity_type, "ship")
        self.assertIsNotNone(hornet_mapping.primary_asset)
        self.assertEqual(len(hornet_mapping.related_assets), 2)

    def test_project_mapping_structure(self):
        """Test complete project mapping generation structure"""
        # Create test table files
        ships_data = [{'name': 'Hornet', 'model': 'hornet.pof'}]
        weapons_data = [{'name': 'Laser', 'model': 'laser.pof'}]
        
        self._create_ships_table(ships_data)
        self._create_weapons_table(weapons_data)
        
        # Mock the table relationship extraction to avoid dependency issues
        with patch.object(self.mapper, 'analyze_table_relationships') as mock_analyze:
            mock_analyze.return_value = {
                "Hornet": [
                    AssetRelationship(
                        source_path="models/hornet.pof",
                        target_path="ships/hornet/hornet.pof",
                        asset_type="model",
                        parent_entity="Hornet",
                        relationship_type="primary_model"
                    )
                ]
            }
            
            project_mapping = self.mapper.generate_project_mapping()
        
        # Verify structure
        required_keys = ['metadata', 'target_structure', 'entity_mappings', 'asset_index', 'statistics']
        for key in required_keys:
            self.assertIn(key, project_mapping)
        
        # Verify metadata
        metadata = project_mapping['metadata']
        self.assertEqual(metadata['generator'], 'AssetRelationshipMapper')
        self.assertGreater(metadata['total_entities'], 0)
        
        # Verify entity mappings
        self.assertIn('Hornet', project_mapping['entity_mappings'])

    def test_json_serialization(self):
        """Test that project mapping can be serialized to JSON"""
        # Create minimal mapping
        mapping = {
            'metadata': {'generator': 'test', 'version': '1.0'},
            'entity_mappings': {
                'TestEntity': {
                    'entity_type': 'ship',
                    'primary_asset': {
                        'source_path': 'test.pof',
                        'target_path': 'ships/test.pof',
                        'asset_type': 'model',
                        'parent_entity': 'TestEntity',
                        'relationship_type': 'primary_model',
                        'required': True
                    },
                    'related_assets': [],
                    'metadata': {}
                }
            }
        }
        
        # Should serialize without errors
        json_str = json.dumps(mapping)
        self.assertIsInstance(json_str, str)
        
        # Should deserialize back to same structure
        restored = json.loads(json_str)
        self.assertEqual(restored['metadata']['generator'], 'test')

    def test_hardcoded_mappings_constants(self):
        """Test that hardcoded mappings contain expected constants"""
        mappings = HardcodedAssetMappings()
        
        # Test texture extensions
        self.assertIn('dds', mappings.TEXTURE_EXTENSIONS)
        self.assertIn('png', mappings.TEXTURE_EXTENSIONS)
        
        # Test texture suffixes
        self.assertIn('glow', mappings.TEXTURE_SUFFIXES)
        self.assertIn('normal', mappings.TEXTURE_SUFFIXES)
        
        # Test weapon effects
        self.assertIn('laser', mappings.WEAPON_EFFECTS)
        self.assertIn('missile', mappings.WEAPON_EFFECTS)
        
        # Test ship subsystems
        self.assertIn('engine', mappings.SHIP_SUBSYSTEMS)
        self.assertIn('turret', mappings.SHIP_SUBSYSTEMS)


if __name__ == '__main__':
    unittest.main()