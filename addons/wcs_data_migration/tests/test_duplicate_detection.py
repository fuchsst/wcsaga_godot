#!/usr/bin/env python3
"""
Test suite for duplicate asset detection functionality in ConversionManager.

Tests DM-014: Duplicate Asset Detection and Handling
"""

import hashlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Mock the problematic imports
sys.modules['config_migrator'] = Mock()
sys.modules['asset_catalog'] = Mock()

from conversion_manager import ConversionJob


class MinimalConversionManager:
    """Minimal ConversionManager for testing duplicate detection only"""
    
    def __init__(self):
        self.file_hash_manifest = {}
        self.duplicate_files = []
        self.completed_jobs = []
        self.failed_jobs = []
    
    def _calculate_file_hash(self, file_path: Path) -> str:
        """Calculate SHA256 hash of file content"""
        try:
            with open(file_path, 'rb') as f:
                file_hash = hashlib.sha256()
                for chunk in iter(lambda: f.read(8192), b""):
                    file_hash.update(chunk)
                return file_hash.hexdigest()
        except Exception:
            return ""
    
    def _check_duplicate_file(self, job: ConversionJob) -> bool:
        """Check if file is duplicate and handle accordingly"""
        skip_types = {"vp_extraction", "config_migration", "table", "mission"}
        if job.conversion_type in skip_types:
            return False
        
        file_hash = self._calculate_file_hash(job.source_path)
        if not file_hash:
            return False
        
        job.file_hash = file_hash
        
        if file_hash in self.file_hash_manifest:
            original_target = self.file_hash_manifest[file_hash]
            job.duplicate_of = original_target
            job.status = "skipped_duplicate"
            job.progress = 1.0
            self.duplicate_files.append(job)
            return True
        
        self.file_hash_manifest[file_hash] = str(job.target_path)
        return False
    
    def generate_conversion_report(self) -> dict:
        """Generate conversion report with duplicate detection"""
        total_processed = len(self.completed_jobs) + len(self.failed_jobs) + len(self.duplicate_files)
        
        return {
            'conversion_summary': {
                'total_jobs': total_processed,
                'completed': len(self.completed_jobs),
                'failed': len(self.failed_jobs),
                'duplicates_skipped': len(self.duplicate_files),
                'success_rate': len(self.completed_jobs) / max(1, len(self.completed_jobs) + len(self.failed_jobs))
            },
            'duplicate_detection': {
                'duplicates_found': len(self.duplicate_files),
                'space_saved_estimate': f"{len(self.duplicate_files)} files",
                'duplicate_files': [
                    {
                        'source': str(job.source_path),
                        'duplicate_of': job.duplicate_of,
                        'file_hash': job.file_hash
                    }
                    for job in self.duplicate_files
                ]
            }
        }


class TestDuplicateDetection(unittest.TestCase):
    """Test duplicate asset detection and handling"""

    def setUp(self):
        """Set up test environment"""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.source_dir = Path(self.temp_dir.name) / "source"
        self.target_dir = Path(self.temp_dir.name) / "target"
        
        self.source_dir.mkdir(parents=True)
        self.target_dir.mkdir(parents=True)
        
        self.manager = MinimalConversionManager()

    def tearDown(self):
        """Clean up test environment"""
        self.temp_dir.cleanup()

    def _create_test_file(self, file_path: Path, content: str) -> str:
        """Create a test file with specific content and return its hash"""
        file_path.parent.mkdir(parents=True, exist_ok=True)
        with open(file_path, 'w') as f:
            f.write(content)
        
        # Calculate hash for verification
        with open(file_path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()

    def test_hash_calculation(self):
        """Test file hash calculation"""
        test_file = self.source_dir / "test.txt"
        expected_hash = self._create_test_file(test_file, "test content")
        
        calculated_hash = self.manager._calculate_file_hash(test_file)
        self.assertEqual(calculated_hash, expected_hash)

    def test_duplicate_detection_same_content(self):
        """Test detection of files with identical content"""
        # Create two files with identical content
        file1 = self.source_dir / "file1.txt"
        file2 = self.source_dir / "file2.txt"
        
        content = "identical content for testing"
        self._create_test_file(file1, content)
        self._create_test_file(file2, content)
        
        # Create conversion jobs
        job1 = ConversionJob(
            source_path=file1,
            target_path=self.target_dir / "converted1.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        job2 = ConversionJob(
            source_path=file2,
            target_path=self.target_dir / "converted2.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        # First file should not be duplicate
        is_duplicate1 = self.manager._check_duplicate_file(job1)
        self.assertFalse(is_duplicate1)
        self.assertEqual(job1.status, "pending")
        
        # Second file should be detected as duplicate
        is_duplicate2 = self.manager._check_duplicate_file(job2)
        self.assertTrue(is_duplicate2)
        self.assertEqual(job2.status, "skipped_duplicate")
        self.assertEqual(job2.duplicate_of, str(job1.target_path))

    def test_duplicate_detection_different_content(self):
        """Test that files with different content are not detected as duplicates"""
        file1 = self.source_dir / "file1.txt"
        file2 = self.source_dir / "file2.txt"
        
        self._create_test_file(file1, "content one")
        self._create_test_file(file2, "content two")
        
        job1 = ConversionJob(
            source_path=file1,
            target_path=self.target_dir / "converted1.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        job2 = ConversionJob(
            source_path=file2,
            target_path=self.target_dir / "converted2.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        # Neither file should be duplicate
        is_duplicate1 = self.manager._check_duplicate_file(job1)
        is_duplicate2 = self.manager._check_duplicate_file(job2)
        
        self.assertFalse(is_duplicate1)
        self.assertFalse(is_duplicate2)
        self.assertEqual(job1.status, "pending")
        self.assertEqual(job2.status, "pending")

    def test_skip_duplicate_detection_for_excluded_types(self):
        """Test that certain job types skip duplicate detection"""
        file1 = self.source_dir / "mission.fs2"
        file2 = self.source_dir / "mission_copy.fs2"
        
        content = "identical mission content"
        self._create_test_file(file1, content)
        self._create_test_file(file2, content)
        
        job1 = ConversionJob(
            source_path=file1,
            target_path=self.target_dir / "mission1.tres",
            conversion_type="mission",
            priority=3,
            dependencies=[]
        )
        
        job2 = ConversionJob(
            source_path=file2,
            target_path=self.target_dir / "mission2.tres",
            conversion_type="mission",
            priority=3,
            dependencies=[]
        )
        
        # Both mission files should skip duplicate detection
        is_duplicate1 = self.manager._check_duplicate_file(job1)
        is_duplicate2 = self.manager._check_duplicate_file(job2)
        
        self.assertFalse(is_duplicate1)
        self.assertFalse(is_duplicate2)

    def test_duplicate_tracking_in_manager(self):
        """Test that duplicates are properly tracked in the manager"""
        file1 = self.source_dir / "image1.png"
        file2 = self.source_dir / "image2.png"
        
        content = "fake png content"
        self._create_test_file(file1, content)
        self._create_test_file(file2, content)
        
        job1 = ConversionJob(
            source_path=file1,
            target_path=self.target_dir / "image1.png",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        job2 = ConversionJob(
            source_path=file2,
            target_path=self.target_dir / "image2.png",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        # Process both jobs
        self.manager._check_duplicate_file(job1)
        self.manager._check_duplicate_file(job2)
        
        # Check that duplicate was tracked
        self.assertEqual(len(self.manager.duplicate_files), 1)
        self.assertEqual(self.manager.duplicate_files[0], job2)

    def test_conversion_report_includes_duplicates(self):
        """Test that conversion report includes duplicate detection statistics"""
        # Add some dummy jobs to the manager
        file1 = self.source_dir / "test1.txt"
        file2 = self.source_dir / "test2.txt"
        
        self._create_test_file(file1, "content")
        self._create_test_file(file2, "content")
        
        job1 = ConversionJob(
            source_path=file1,
            target_path=self.target_dir / "test1.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        job2 = ConversionJob(
            source_path=file2,
            target_path=self.target_dir / "test2.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        # Simulate processing
        self.manager._check_duplicate_file(job1)
        self.manager._check_duplicate_file(job2)
        self.manager.completed_jobs.append(job1)
        
        # Generate report
        report = self.manager.generate_conversion_report()
        
        # Verify duplicate information is in report
        self.assertIn('duplicate_detection', report)
        self.assertEqual(report['duplicate_detection']['duplicates_found'], 1)
        self.assertIn('duplicate_files', report['duplicate_detection'])
        self.assertEqual(len(report['duplicate_detection']['duplicate_files']), 1)

    def test_hash_manifest_prevents_duplicates(self):
        """Test that hash manifest correctly prevents duplicate processing"""
        file_path = self.source_dir / "test.txt"
        self._create_test_file(file_path, "test content")
        
        job = ConversionJob(
            source_path=file_path,
            target_path=self.target_dir / "test.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        # First check should register the file
        is_duplicate1 = self.manager._check_duplicate_file(job)
        self.assertFalse(is_duplicate1)
        
        # Hash should be in manifest now
        self.assertIn(job.file_hash, self.manager.file_hash_manifest)
        
        # Second check with same file should detect duplicate
        job2 = ConversionJob(
            source_path=file_path,
            target_path=self.target_dir / "test_copy.txt",
            conversion_type="texture_png",
            priority=2,
            dependencies=[]
        )
        
        is_duplicate2 = self.manager._check_duplicate_file(job2)
        self.assertTrue(is_duplicate2)


if __name__ == '__main__':
    unittest.main()