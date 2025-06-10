#!/usr/bin/env python3
"""
Test suite for HermesCampaignConverter functionality.

Tests DM-015: Convert Hermes Campaign Assets via Automated Mapping
"""

import tempfile
import unittest
import json
from pathlib import Path
import sys
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from hermes_campaign_converter import HermesCampaignConverter

class TestHermesCampaignConverter(unittest.TestCase):
    """Test Hermes campaign conversion functionality"""

    def setUp(self):
        """Set up test environment"""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.source_dir = Path(self.temp_dir.name) / "hermes_source"
        self.target_dir = Path(self.temp_dir.name) / "godot_target"
        
        # Create directory structure
        self.source_dir.mkdir(parents=True)
        self.target_dir.mkdir(parents=True)
        
        # Create minimal Hermes campaign structure
        hermes_core = self.source_dir / "hermes_core"
        hermes_core.mkdir()
        
        # Create sample table files
        ships_table = hermes_core / "ships.tbl"
        ships_table.write_text("""#Ship Classes

$Name: Hornet
$POF file: hornet.pof
$end_multi_text

$Name: Rapier
$POF file: rapier.pof
$end_multi_text
""")
        
        weapons_table = hermes_core / "weapons.tbl" 
        weapons_table.write_text("""#Primary Weapons

$Name: Laser Cannon
$Model file: laser.pof
$Damage: 10.0
$end_multi_text

$Name: Mass Driver
$Model file: mass_driver.pof
$Damage: 25.0
$end_multi_text
""")

    def tearDown(self):
        """Clean up test environment"""
        self.temp_dir.cleanup()

    def test_initialization(self):
        """Test converter initialization"""
        # Mock the ConversionManager to avoid dependency issues
        with patch('hermes_campaign_converter.ConversionManager'):
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            
            self.assertEqual(converter.hermes_source_dir, self.source_dir)
            self.assertEqual(converter.godot_target_dir, self.target_dir)
            self.assertIn('campaigns', converter.target_structure)
            self.assertIn('common', converter.target_structure)

    def test_initialization_missing_source(self):
        """Test initialization with missing source directory"""
        missing_dir = Path(self.temp_dir.name) / "missing"
        
        with self.assertRaises(FileNotFoundError):
            HermesCampaignConverter(missing_dir, self.target_dir)

    def test_generate_asset_mapping_success(self):
        """Test successful asset mapping generation"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            # Mock the conversion manager instance
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock successful mapping generation
            mock_mapping_data = {
                'metadata': {
                    'total_entities': 4,
                    'total_assets': 12
                },
                'statistics': {
                    'ships': 2,
                    'weapons': 2
                }
            }
            mock_cm.generate_asset_mapping.return_value = mock_mapping_data
            
            # Mock file creation
            def mock_generate_mapping(output_path):
                output_path.parent.mkdir(parents=True, exist_ok=True)
                output_path.write_text(json.dumps(mock_mapping_data))
                return mock_mapping_data
            
            mock_cm.generate_asset_mapping.side_effect = mock_generate_mapping
            
            # Test mapping generation
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            mapping_file = converter.generate_asset_mapping()
            
            # Verify results
            self.assertIsNotNone(mapping_file)
            self.assertTrue(mapping_file.exists())
            self.assertTrue(converter.conversion_results['mapping_generated'])
            self.assertEqual(converter.conversion_results['mapping_file'], str(mapping_file))

    def test_generate_asset_mapping_failure(self):
        """Test asset mapping generation failure"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock failed mapping generation
            mock_cm.generate_asset_mapping.return_value = None
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            mapping_file = converter.generate_asset_mapping()
            
            # Verify failure handling
            self.assertIsNone(mapping_file)
            self.assertFalse(converter.conversion_results['mapping_generated'])
            self.assertGreater(len(converter.conversion_results['errors']), 0)

    def test_execute_full_conversion_success(self):
        """Test successful full conversion execution"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock asset scanning
            mock_assets = {
                'pof_models': [Path('hornet.pof'), Path('rapier.pof')],
                'textures_dds': [Path('hornet.dds'), Path('rapier.dds')],
                'tables': [Path('ships.tbl'), Path('weapons.tbl')]
            }
            mock_cm.scan_wcs_assets.return_value = mock_assets
            
            # Mock conversion plan creation
            mock_jobs = [Mock() for _ in range(6)]  # 6 mock jobs
            mock_cm.create_conversion_plan.return_value = mock_jobs
            
            # Mock successful conversion execution (98%+ success rate)
            mock_cm.execute_conversion_plan.return_value = (6, 0, 1, 7)  # completed, failed, skipped, total
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            success = converter.execute_full_conversion()
            
            # Verify results
            self.assertTrue(success)
            self.assertTrue(converter.conversion_results['conversion_completed'])
            self.assertEqual(converter.conversion_results['assets_processed'], 6)
            self.assertEqual(converter.conversion_results['assets_failed'], 0)
            self.assertEqual(converter.conversion_results['duplicates_found'], 1)
            self.assertEqual(converter.conversion_results['success_rate'], 1.0)

    def test_execute_full_conversion_low_success_rate(self):
        """Test conversion with low success rate"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock asset scanning
            mock_assets = {
                'pof_models': [Path('hornet.pof')]
            }
            mock_cm.scan_wcs_assets.return_value = mock_assets
            mock_cm.create_conversion_plan.return_value = [Mock()]
            
            # Mock conversion with low success rate (below 98%)
            mock_cm.execute_conversion_plan.return_value = (5, 5, 0, 10)  # 50% success rate
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            success = converter.execute_full_conversion()
            
            # Should still return True but log warning
            self.assertTrue(success)
            self.assertEqual(converter.conversion_results['success_rate'], 0.5)
            self.assertGreater(len(converter.conversion_results['errors']), 0)

    def test_execute_full_conversion_no_assets(self):
        """Test conversion with no assets found"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock no assets found
            mock_cm.scan_wcs_assets.return_value = {}
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            success = converter.execute_full_conversion()
            
            # Verify failure handling
            self.assertFalse(success)
            self.assertFalse(converter.conversion_results['conversion_completed'])
            self.assertGreater(len(converter.conversion_results['errors']), 0)

    def test_catalog_converted_assets_success(self):
        """Test successful asset cataloging"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock catalog operations
            mock_cm.catalog_converted_assets.return_value = None
            
            # Mock conversion report
            mock_report = {
                'conversion_summary': {
                    'total_jobs': 10,
                    'completed': 9,
                    'failed': 1,
                    'success_rate': 0.9
                },
                'duplicate_detection': {
                    'duplicates_found': 2
                },
                'failed_conversions': []
            }
            mock_cm.generate_conversion_report.return_value = mock_report
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            success = converter.catalog_converted_assets()
            
            # Verify results
            self.assertTrue(success)
            self.assertTrue(converter.conversion_results['validation_passed'])
            
            # Check report was saved
            report_path = self.target_dir / "hermes_conversion_report.json"
            self.assertTrue(report_path.exists())

    def test_catalog_converted_assets_no_processing(self):
        """Test cataloging when no assets were processed"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            mock_cm.catalog_converted_assets.return_value = None
            
            # Mock report with no processed assets
            mock_report = {
                'conversion_summary': {
                    'total_jobs': 0,
                    'completed': 0,
                    'failed': 0,
                    'success_rate': 0.0
                },
                'duplicate_detection': {
                    'duplicates_found': 0
                },
                'failed_conversions': []
            }
            mock_cm.generate_conversion_report.return_value = mock_report
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            success = converter.catalog_converted_assets()
            
            # Verify failure handling
            self.assertFalse(success)
            self.assertFalse(converter.conversion_results['validation_passed'])
            self.assertGreater(len(converter.conversion_results['errors']), 0)

    def test_run_full_conversion_pipeline_success(self):
        """Test complete successful conversion pipeline"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock all operations to succeed
            mock_mapping_data = {
                'metadata': {'total_entities': 2, 'total_assets': 4},
                'statistics': {'ships': 1, 'weapons': 1}
            }
            
            def mock_generate_mapping(output_path):
                output_path.parent.mkdir(parents=True, exist_ok=True)
                output_path.write_text(json.dumps(mock_mapping_data))
                return mock_mapping_data
            
            mock_cm.generate_asset_mapping.side_effect = mock_generate_mapping
            mock_cm.scan_wcs_assets.return_value = {'pof_models': [Path('test.pof')]}
            mock_cm.create_conversion_plan.return_value = [Mock()]
            mock_cm.execute_conversion_plan.return_value = (1, 0, 0, 1)
            mock_cm.catalog_converted_assets.return_value = None
            mock_cm.generate_conversion_report.return_value = {
                'conversion_summary': {
                    'total_jobs': 1,
                    'completed': 1,
                    'failed': 0,
                    'success_rate': 1.0
                },
                'duplicate_detection': {'duplicates_found': 0},
                'failed_conversions': []
            }
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            success = converter.run_full_conversion_pipeline()
            
            # Verify overall success
            self.assertTrue(success)
            self.assertTrue(converter.conversion_results['mapping_generated'])
            self.assertTrue(converter.conversion_results['conversion_completed'])
            self.assertTrue(converter.conversion_results['validation_passed'])
            self.assertIsNotNone(converter.conversion_results['start_time'])
            self.assertIsNotNone(converter.conversion_results['end_time'])

    def test_run_full_conversion_pipeline_partial_failure(self):
        """Test pipeline with some phase failures"""
        with patch('hermes_campaign_converter.ConversionManager') as mock_cm_class:
            mock_cm = Mock()
            mock_cm_class.return_value = mock_cm
            
            # Mock mapping generation failure
            mock_cm.generate_asset_mapping.return_value = None
            
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            success = converter.run_full_conversion_pipeline()
            
            # Should fail if mapping generation fails
            self.assertFalse(success)
            self.assertFalse(converter.conversion_results['mapping_generated'])
            self.assertGreater(len(converter.conversion_results['errors']), 0)

    def test_save_final_report(self):
        """Test final report generation"""
        with patch('hermes_campaign_converter.ConversionManager'):
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            
            # Set up some conversion results
            converter.conversion_results.update({
                'start_time': '2025-06-10T10:00:00',
                'end_time': '2025-06-10T10:30:00',
                'mapping_generated': True,
                'conversion_completed': True,
                'validation_passed': True,
                'assets_processed': 10,
                'success_rate': 0.95
            })
            
            report_path = converter.save_final_report()
            
            # Verify report was created
            self.assertTrue(report_path.exists())
            self.assertEqual(report_path.name, "hermes_campaign_final_report.json")
            
            # Verify report content
            with open(report_path, 'r') as f:
                report_data = json.load(f)
            
            self.assertEqual(report_data['conversion_metadata']['campaign'], 'Hermes')
            self.assertTrue(report_data['success_criteria']['mapping_generation'])
            self.assertTrue(report_data['success_criteria']['conversion_completion'])
            self.assertTrue(report_data['success_criteria']['validation_completion'])
            self.assertFalse(report_data['success_criteria']['success_rate_98_percent'])  # 95% < 98%

    def test_target_structure_definition(self):
        """Test target structure follows expected format"""
        with patch('hermes_campaign_converter.ConversionManager'):
            converter = HermesCampaignConverter(self.source_dir, self.target_dir)
            
            expected_keys = {'campaigns', 'common', 'ships', 'weapons'}
            self.assertEqual(set(converter.target_structure.keys()), expected_keys)
            
            # Verify campaign structure
            self.assertEqual(converter.target_structure['campaigns'], 'campaigns/wing_commander_saga')


if __name__ == '__main__':
    unittest.main()