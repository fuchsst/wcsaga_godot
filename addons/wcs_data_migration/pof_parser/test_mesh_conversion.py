#!/usr/bin/env python3
"""
Test POF Mesh Conversion - EPIC-003 DM-005 Implementation

Test suite for POF to Godot mesh conversion functionality.
Tests the complete pipeline from POF to GLB with validation.
"""

import json
import tempfile
import unittest
from pathlib import Path
from typing import Any, Dict

from .godot_import_generator import GodotImportGenerator
from .pof_mesh_converter import ConversionReport, POFMeshConverter
from .pof_obj_converter import OBJConversionResult, POFOBJConverter


class TestPOFOBJConverter(unittest.TestCase):
    """Test POF to OBJ conversion functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.converter = POFOBJConverter()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def test_obj_converter_initialization(self):
        """Test OBJ converter initializes correctly."""
        self.assertIsNotNone(self.converter)
        self.assertIsNotNone(self.converter.data_extractor)
        self.assertEqual(self.converter.coordinate_scale, 0.01)
    
    def test_coordinate_conversion(self):
        """Test coordinate system conversion."""
        # Test position conversion (POF cm to Godot m, Z-axis flip)
        pos = (100.0, 200.0, 300.0)  # POF coordinates
        converted = self.converter._convert_position(pos)
        expected = (1.0, 2.0, -3.0)  # Godot coordinates
        
        self.assertEqual(converted, expected)
    
    def test_normal_conversion(self):
        """Test normal vector conversion."""
        # Test normal conversion (no scaling, Z-axis flip)
        normal = (0.0, 1.0, 0.0)  # POF normal
        converted = self.converter._convert_normal(normal)
        expected = (0.0, 1.0, 0.0)  # Godot normal (Y-up unchanged)
        
        self.assertEqual(converted, expected)
        
        # Test Z-axis flip
        normal_z = (0.0, 0.0, 1.0)  # POF +Z forward
        converted_z = self.converter._convert_normal(normal_z)
        expected_z = (0.0, 0.0, -1.0)  # Godot -Z forward
        
        self.assertEqual(converted_z, expected_z)
    
    def test_uv_conversion(self):
        """Test UV coordinate conversion."""
        # Test UV flip (POF V=0 at bottom, OBJ V=0 at top)
        uv = (0.5, 0.25)  # POF UV
        converted = self.converter._convert_uv(uv)
        expected = (0.5, 0.75)  # OBJ UV (V flipped)
        
        self.assertEqual(converted, expected)
    
    def test_triangulation(self):
        """Test polygon triangulation."""
        # Test triangle (should pass through unchanged)
        triangle = [0, 1, 2]
        result = self.converter._triangulate_polygon(triangle)
        self.assertEqual(result, [triangle])
        
        # Test quad (should split into two triangles)
        quad = [0, 1, 2, 3]
        result = self.converter._triangulate_polygon(quad)
        expected = [[0, 1, 2], [0, 2, 3]]
        self.assertEqual(result, expected)
        
        # Test polygon with 5 vertices (fan triangulation)
        pentagon = [0, 1, 2, 3, 4]
        result = self.converter._triangulate_polygon(pentagon)
        expected = [[0, 1, 2], [0, 2, 3], [0, 3, 4]]
        self.assertEqual(result, expected)

class TestGodotImportGenerator(unittest.TestCase):
    """Test Godot import file generation."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.generator = GodotImportGenerator()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def test_import_generator_initialization(self):
        """Test import generator initializes correctly."""
        self.assertIsNotNone(self.generator)
        self.assertIsNotNone(self.generator.default_ship_settings)
        self.assertIsNotNone(self.generator.default_station_settings)
        self.assertIsNotNone(self.generator.default_debris_settings)
    
    def test_model_type_detection(self):
        """Test model type detection from filename."""
        # Test ship detection
        ship_names = ['fighter_mk1.pof', 'bomber_heavy.pof', 'ship_test.pof']
        for name in ship_names:
            detected = self.generator._detect_model_type(name)
            self.assertEqual(detected, 'ship')
        
        # Test station detection
        station_names = ['station_alpha.pof', 'base_mining.pof', 'platform_01.pof']
        for name in station_names:
            detected = self.generator._detect_model_type(name)
            self.assertEqual(detected, 'station')
        
        # Test debris detection
        debris_names = ['debris_fighter.pof', 'wreck_cruiser.pof', 'hulk_large.pof']
        for name in debris_names:
            detected = self.generator._detect_model_type(name)
            self.assertEqual(detected, 'debris')
    
    def test_import_file_generation(self):
        """Test import file generation."""
        # Create a dummy GLB file
        glb_file = self.temp_path / 'test_ship.glb'
        glb_file.write_bytes(b'dummy_glb_data')
        
        # Generate import file
        success = self.generator.generate_import_file(glb_file, 'ship')
        self.assertTrue(success)
        
        # Check import file was created
        import_file = glb_file.with_suffix('.glb.import')
        self.assertTrue(import_file.exists())
        
        # Verify import file content
        content = import_file.read_text()
        self.assertIn('[remap]', content)
        self.assertIn('importer=scene', content)
        self.assertIn('[params]', content)

class TestPOFMeshConverter(unittest.TestCase):
    """Test complete POF mesh conversion pipeline."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
        
        # Initialize converter without Blender (for testing structure)
        self.converter = POFMeshConverter(
            blender_executable=None,  # Skip Blender for unit tests
            temp_dir=self.temp_path,
            cleanup_temp=False
        )
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def test_converter_initialization(self):
        """Test converter initializes correctly."""
        self.assertIsNotNone(self.converter)
        self.assertIsNotNone(self.converter.obj_converter)
        self.assertIsNotNone(self.converter.import_generator)
        self.assertIsNotNone(self.converter.analyzer)
        self.assertIsNotNone(self.converter.extractor)
    
    def test_model_type_detection(self):
        """Test model type detection from filename."""
        # Test various ship types
        test_cases = [
            ('fighter_mk1.pof', 'ship'),
            ('station_alpha.pof', 'station'),
            ('debris_large.pof', 'debris'),
            ('unknown_model.pof', None)
        ]
        
        for filename, expected in test_cases:
            result = self.converter._detect_model_type(filename)
            self.assertEqual(result, expected)
    
    def test_ship_class_extraction(self):
        """Test ship class extraction for WCS configuration."""
        test_cases = [
            ('gtf_fighter.pof', 'fighter'),
            ('gtb_bomber.pof', 'bomber'),
            ('gtc_cruiser.pof', 'cruiser'),
            ('gtd_destroyer.pof', 'destroyer'),
            ('unknown_ship.pof', 'fighter')  # Default
        ]
        
        for filename, expected in test_cases:
            result = self.converter._extract_ship_class(filename)
            self.assertEqual(result, expected)
    
    def test_conversion_report_structure(self):
        """Test conversion report data structure."""
        report = ConversionReport(
            source_file='test.pof',
            output_file='test.glb',
            conversion_time=1.5,
            success=True
        )
        
        # Test basic properties
        self.assertEqual(report.source_file, 'test.pof')
        self.assertEqual(report.output_file, 'test.glb')
        self.assertEqual(report.conversion_time, 1.5)
        self.assertTrue(report.success)
        
        # Test to_dict conversion
        report_dict = report.to_dict()
        self.assertIsInstance(report_dict, dict)
        self.assertIn('source_file', report_dict)
        self.assertIn('validation', report_dict)
        self.assertIn('source_analysis', report_dict)

class TestIntegration(unittest.TestCase):
    """Integration tests for the complete conversion pipeline."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def test_pipeline_integration(self):
        """Test that all components integrate correctly."""
        # Test that we can create all the major components
        obj_converter = POFOBJConverter()
        import_generator = GodotImportGenerator()
        
        # Test that they have expected interfaces
        self.assertTrue(hasattr(obj_converter, 'convert_pof_to_obj'))
        self.assertTrue(hasattr(import_generator, 'generate_import_file'))
        
        # Test coordinate conversion consistency
        test_pos = (100.0, 200.0, 300.0)
        converted_pos = obj_converter._convert_position(test_pos)
        
        # Verify conversion follows POF->Godot coordinate mapping
        self.assertEqual(converted_pos[0], 1.0)  # X unchanged, scaled
        self.assertEqual(converted_pos[1], 2.0)  # Y unchanged, scaled
        self.assertEqual(converted_pos[2], -3.0) # Z flipped, scaled
    
    def test_error_handling(self):
        """Test error handling throughout the pipeline."""
        # Test with non-existent file
        obj_converter = POFOBJConverter()
        fake_path = Path('nonexistent.pof')
        
        # Should handle gracefully without crashing
        result = obj_converter.convert_pof_to_obj(fake_path, Path('output.obj'))
        self.assertFalse(result)

def run_tests():
    """Run all mesh conversion tests."""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestPOFOBJConverter))
    suite.addTests(loader.loadTestsFromTestCase(TestGodotImportGenerator))
    suite.addTests(loader.loadTestsFromTestCase(TestPOFMeshConverter))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegration))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()

if __name__ == '__main__':
    import sys
    success = run_tests()
    print("\n" + "="*60)
    if success:
        print("SUCCESS: All POF mesh conversion tests passed!")
    else:
        print("FAILURE: Some tests failed!")
    print("="*60)
    sys.exit(0 if success else 1)