#!/usr/bin/env python3
"""
POF Parser Test Suite - EPIC-003 DM-004 Implementation

Comprehensive test suite for POF format analysis and parsing functionality.
Tests format validation, chunk parsing, and data extraction capabilities.
"""

import struct
import tempfile
import unittest
from pathlib import Path
from typing import BinaryIO

from .pof_chunks import ID_OHDR, ID_TXTR, POF_HEADER_ID
from .pof_data_extractor import POFDataExtractor
from .pof_format_analyzer import POFFormatAnalyzer, POFFormatInfo
from .pof_parser import POFParser


class TestPOFFormatAnalyzer(unittest.TestCase):
    """Test POF format analysis functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.analyzer = POFFormatAnalyzer()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def create_test_pof(self, filename: str, valid_header: bool = True, 
                       version: int = 2100, chunks: list = None) -> Path:
        """Create a test POF file."""
        test_file = self.temp_path / filename
        
        with open(test_file, 'wb') as f:
            # Write header
            if valid_header:
                f.write(struct.pack('<I', POF_HEADER_ID))  # Header ID
                f.write(struct.pack('<i', version))        # Version
            else:
                f.write(struct.pack('<I', 0x12345678))     # Invalid header
                f.write(struct.pack('<i', version))
            
            # Write chunks
            if chunks:
                for chunk_id, chunk_data in chunks:
                    f.write(struct.pack('<I', chunk_id))           # Chunk ID
                    f.write(struct.pack('<i', len(chunk_data)))    # Chunk length
                    f.write(chunk_data)                            # Chunk data
        
        return test_file
    
    def test_analyze_valid_pof(self):
        """Test analysis of valid POF file."""
        # Create test POF with OHDR chunk
        ohdr_data = struct.pack('<fIi', 100.0, 0x1, 1)  # radius, flags, num_subobjects
        ohdr_data += struct.pack('<fff', -50.0, -50.0, -50.0)  # min bounds
        ohdr_data += struct.pack('<fff', 50.0, 50.0, 50.0)     # max bounds
        
        test_file = self.create_test_pof('valid.pof', chunks=[(ID_OHDR, ohdr_data)])
        
        analysis = self.analyzer.analyze_format(test_file)
        
        self.assertIsInstance(analysis, POFFormatInfo)
        self.assertTrue(analysis.valid_header)
        self.assertTrue(analysis.compatible_version)
        self.assertEqual(analysis.version, 2100)
        self.assertEqual(analysis.total_chunks, 1)
        self.assertIn('HDR2', analysis.chunk_count_by_type)
    
    def test_analyze_invalid_header(self):
        """Test analysis of POF file with invalid header."""
        test_file = self.create_test_pof('invalid.pof', valid_header=False)
        
        analysis = self.analyzer.analyze_format(test_file)
        
        self.assertFalse(analysis.valid_header)
        self.assertGreater(len(analysis.parsing_errors), 0)
    
    def test_analyze_old_version(self):
        """Test analysis of POF file with old version."""
        test_file = self.create_test_pof('old.pof', version=1800)
        
        analysis = self.analyzer.analyze_format(test_file)
        
        self.assertTrue(analysis.valid_header)
        self.assertFalse(analysis.compatible_version)
        self.assertGreater(len(analysis.warnings), 0)
    
    def test_format_compliance_validation(self):
        """Test format compliance validation."""
        # Test missing required chunks
        test_file = self.create_test_pof('incomplete.pof', chunks=[])
        analysis = self.analyzer.analyze_format(test_file)
        
        issues = self.analyzer.validate_format_compliance(analysis)
        
        self.assertGreater(len(issues), 0)
        self.assertTrue(any('OHDR' in issue for issue in issues))
    
    def test_chunk_metadata_extraction(self):
        """Test chunk metadata extraction."""
        # Create OHDR chunk with metadata
        ohdr_data = struct.pack('<fIi', 100.0, 0x1, 2)  # radius, flags, num_subobjects
        ohdr_data += struct.pack('<fff', -50.0, -50.0, -50.0)  # min bounds
        ohdr_data += struct.pack('<fff', 50.0, 50.0, 50.0)     # max bounds
        
        test_file = self.create_test_pof('metadata.pof', chunks=[(ID_OHDR, ohdr_data)])
        
        analysis = self.analyzer.analyze_format(test_file)
        
        self.assertEqual(len(analysis.chunks), 1)
        chunk = analysis.chunks[0]
        self.assertEqual(chunk.chunk_id, ID_OHDR)
        self.assertTrue(chunk.parsed_successfully)
        self.assertIn('max_radius', chunk.metadata)
        self.assertEqual(chunk.metadata['max_radius'], 100.0)
        self.assertEqual(chunk.metadata['num_subobjects'], 2)


class TestPOFDataExtractor(unittest.TestCase):
    """Test POF data extraction functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.extractor = POFDataExtractor()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def create_minimal_pof(self, filename: str) -> Path:
        """Create a minimal valid POF file for testing."""
        test_file = self.temp_path / filename
        
        with open(test_file, 'wb') as f:
            # Header
            f.write(struct.pack('<I', POF_HEADER_ID))
            f.write(struct.pack('<i', 2100))
            
            # OHDR chunk
            ohdr_data = struct.pack('<fIi', 50.0, 0x0, 1)  # radius, flags, num_subobjects
            ohdr_data += struct.pack('<fff', -25.0, -25.0, -25.0)  # min bounds
            ohdr_data += struct.pack('<fff', 25.0, 25.0, 25.0)     # max bounds
            # Detail levels (8 ints)
            ohdr_data += struct.pack('<' + 'i' * 8, 0, -1, -1, -1, -1, -1, -1, -1)
            # Debris objects (32 ints) 
            ohdr_data += struct.pack('<' + 'i' * 32, *[-1] * 32)
            # Mass, center of mass, moment of inertia
            ohdr_data += struct.pack('<f', 100.0)  # mass
            ohdr_data += struct.pack('<fff', 0.0, 0.0, 0.0)  # center of mass
            ohdr_data += struct.pack('<fff', 1.0, 0.0, 0.0)  # moment of inertia row 1
            ohdr_data += struct.pack('<fff', 0.0, 1.0, 0.0)  # moment of inertia row 2  
            ohdr_data += struct.pack('<fff', 0.0, 0.0, 1.0)  # moment of inertia row 3
            
            f.write(struct.pack('<I', ID_OHDR))
            f.write(struct.pack('<i', len(ohdr_data)))
            f.write(ohdr_data)
            
            # TXTR chunk with test texture
            texture_data = b'test_texture.dds\x00'
            f.write(struct.pack('<I', ID_TXTR))
            f.write(struct.pack('<i', len(texture_data)))
            f.write(texture_data)
        
        return test_file
    
    def test_extract_model_data(self):
        """Test basic model data extraction."""
        test_file = self.create_minimal_pof('test_model.pof')
        
        model_data = self.extractor.extract_model_data(test_file)
        
        self.assertIsNotNone(model_data)
        self.assertEqual(model_data.filename, 'test_model.pof')
        self.assertEqual(model_data.version, 2100)
        self.assertEqual(model_data.max_radius, 50.0)
        self.assertEqual(model_data.mass, 100.0)
        self.assertGreater(len(model_data.textures), 0)
    
    def test_extract_for_godot_conversion(self):
        """Test Godot-specific data extraction."""
        test_file = self.create_minimal_pof('godot_test.pof')
        
        godot_data = self.extractor.extract_for_godot_conversion(test_file)
        
        self.assertIsNotNone(godot_data)
        self.assertIn('metadata', godot_data)
        self.assertIn('scene_tree', godot_data)
        self.assertIn('materials', godot_data)
        self.assertIn('gameplay_nodes', godot_data)
        
        metadata = godot_data['metadata']
        self.assertEqual(metadata['source_file'], 'godot_test.pof')
        self.assertEqual(metadata['pof_version'], 2100)
        self.assertEqual(metadata['max_radius'], 50.0)
    
    def test_model_data_serialization(self):
        """Test model data to dictionary conversion."""
        test_file = self.create_minimal_pof('serialize_test.pof')
        
        model_data = self.extractor.extract_model_data(test_file)
        data_dict = model_data.to_dict()
        
        self.assertIsInstance(data_dict, dict)
        self.assertIn('filename', data_dict)
        self.assertIn('version', data_dict)
        self.assertIn('max_radius', data_dict)
        self.assertIn('textures', data_dict)
        self.assertIn('subobjects', data_dict)


class TestPOFParser(unittest.TestCase):
    """Test POF parser functionality."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.parser = POFParser()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def test_parse_nonexistent_file(self):
        """Test parsing non-existent file."""
        fake_file = self.temp_path / 'nonexistent.pof'
        
        result = self.parser.parse(fake_file)
        
        self.assertIsNone(result)
    
    def test_parse_invalid_file(self):
        """Test parsing invalid POF file."""
        invalid_file = self.temp_path / 'invalid.pof'
        with open(invalid_file, 'wb') as f:
            f.write(b'This is not a POF file')
        
        result = self.parser.parse(invalid_file)
        
        self.assertIsNone(result)


class TestIntegration(unittest.TestCase):
    """Integration tests for POF parser components."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        self.temp_dir.cleanup()
    
    def test_analyzer_extractor_consistency(self):
        """Test consistency between analyzer and extractor."""
        # Create a test POF file
        test_file = self.temp_path / 'consistency_test.pof'
        
        with open(test_file, 'wb') as f:
            # Header
            f.write(struct.pack('<I', POF_HEADER_ID))
            f.write(struct.pack('<i', 2100))
            
            # Simple OHDR chunk
            ohdr_data = struct.pack('<fIi', 75.0, 0x1, 0)
            ohdr_data += struct.pack('<fff', -37.5, -37.5, -37.5)
            ohdr_data += struct.pack('<fff', 37.5, 37.5, 37.5)
            
            f.write(struct.pack('<I', ID_OHDR))
            f.write(struct.pack('<i', len(ohdr_data)))
            f.write(ohdr_data)
        
        # Analyze with analyzer
        analyzer = POFFormatAnalyzer()
        analysis = analyzer.analyze_format(test_file)
        
        # Extract with extractor
        extractor = POFDataExtractor()
        model_data = extractor.extract_model_data(test_file)
        
        # Verify consistency
        self.assertEqual(analysis.version, model_data.version)
        self.assertEqual(analysis.filename, model_data.filename)
        
        # Find OHDR chunk in analysis
        ohdr_chunk = next((c for c in analysis.chunks if c.chunk_id == ID_OHDR), None)
        self.assertIsNotNone(ohdr_chunk)
        self.assertEqual(ohdr_chunk.metadata['max_radius'], model_data.max_radius)


def run_tests():
    """Run all POF parser tests."""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestPOFFormatAnalyzer))
    suite.addTests(loader.loadTestsFromTestCase(TestPOFDataExtractor))
    suite.addTests(loader.loadTestsFromTestCase(TestPOFParser))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegration))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


if __name__ == '__main__':
    success = run_tests()
    exit(0 if success else 1)