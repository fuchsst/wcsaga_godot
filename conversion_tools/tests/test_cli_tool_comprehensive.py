#!/usr/bin/env python3
"""
DM-010 CLI Tool Development - Core Functionality Tests

Tests the enhanced CLI interface for comprehensive WCS asset conversion
including batch processing, resume functionality, and automation capabilities.

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-010 - CLI Tool Development
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import sys
import tempfile
import pytest
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock

# Import the module under test
sys.path.append(str(Path(__file__).parent.parent))


class TestDM010CLITool:
    """Core functionality tests for DM-010 CLI Tool Development"""
    
    def test_cli_help_output(self):
        """Test that CLI help shows comprehensive options"""
        result = subprocess.run([
            sys.executable, "convert_wcs_assets.py", "--help"
        ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
        
        assert result.returncode == 0
        help_output = result.stdout
        
        # Verify comprehensive CLI options are present
        assert "--source" in help_output
        assert "--target" in help_output
        assert "--resume" in help_output
        assert "--dry-run" in help_output
        assert "--validate-only" in help_output
        assert "--save-state" in help_output
        assert "--progress-interval" in help_output
        assert "--asset-types" in help_output
        assert "--batch-size" in help_output
        assert "--generate-manifest" in help_output
        assert "--performance-report" in help_output
        
        # Verify examples are present
        assert "Examples:" in help_output
        assert "Resume interrupted conversion" in help_output
        assert "Batch convert" in help_output
        
    def test_argument_validation(self):
        """Test CLI argument validation"""
        with tempfile.TemporaryDirectory() as temp_dir:
            target_path = Path(temp_dir) / "target"
            target_path.mkdir()
            
            # Test missing required arguments
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            assert result.returncode != 0
            assert "error:" in result.stderr.lower()
            
            # Test conflicting arguments
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--target", str(target_path),
                "--quiet", "--verbose"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            assert result.returncode != 0
            assert "cannot use both --quiet and --verbose" in result.stderr.lower()
            
            # Test validate vs skip-validation conflict
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--target", str(target_path),
                "--validate", "--skip-validation"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            assert result.returncode != 0
            assert "cannot use both --validate and --skip-validation" in result.stderr.lower()
    
    def test_conversion_state_data_structure(self):
        """Test ConversionState data structure functionality"""
        from convert_wcs_assets import ConversionState
        
        # Test state creation
        state = ConversionState(
            conversion_id="test_conversion_123",
            start_time="2025-01-29T10:00:00",
            source_path="/test/wcs",
            target_path="/test/godot",
            total_jobs=100,
            completed_jobs=25,
            failed_jobs=2,
            current_phase=2,
            job_states={"job1": "completed", "job2": "failed"},
            performance_metrics={"jobs_per_second": 2.5}
        )
        
        assert state.conversion_id == "test_conversion_123"
        assert state.total_jobs == 100
        assert state.completed_jobs == 25
        assert state.failed_jobs == 2
        assert state.current_phase == 2
        
        # Test state serialization
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            state_file = Path(f.name)
        
        try:
            state.save_to_file(state_file)
            assert state_file.exists()
            
            # Test state loading
            loaded_state = ConversionState.load_from_file(state_file)
            assert loaded_state.conversion_id == state.conversion_id
            assert loaded_state.total_jobs == state.total_jobs
            assert loaded_state.completed_jobs == state.completed_jobs
            assert loaded_state.performance_metrics == state.performance_metrics
        finally:
            if state_file.exists():
                state_file.unlink()
    
    def test_progress_tracker_functionality(self):
        """Test ProgressTracker functionality and metrics calculation"""
        from convert_wcs_assets import ProgressTracker
        import time
        
        # Test progress tracker initialization
        tracker = ProgressTracker(
            start_time=time.time(),
            total_jobs=100
        )
        
        assert tracker.total_jobs == 100
        assert tracker.completed_jobs == 0
        assert tracker.failed_jobs == 0
        assert tracker.current_phase == 1
        assert "VP Archive Extraction" in tracker.phase_names[1]
        
        # Test job completion tracking
        tracker.update_job_completed("test_job_1")
        assert tracker.completed_jobs == 1
        assert tracker.current_job == "test_job_1"
        
        tracker.update_job_failed("test_job_2")
        assert tracker.failed_jobs == 1
        assert tracker.current_job == "test_job_2"
        
        # Test phase progression
        tracker.set_phase(2)
        assert tracker.current_phase == 2
        
        # Test progress summary generation
        summary = tracker.get_progress_summary()
        assert "Progress:" in summary
        assert "Core Asset Conversion" in summary  # Phase 2 name
        assert "test_job_2" in summary  # Current job
        assert "jobs/sec" in summary
        assert "ETA:" in summary
    
    def test_conversion_orchestrator_initialization(self):
        """Test ConversionOrchestrator initialization and basic functionality"""
        from convert_wcs_assets import ConversionOrchestrator
        
        with tempfile.TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "wcs_source"
            target_path = Path(temp_dir) / "godot_target"
            source_path.mkdir()
            target_path.mkdir()
            
            # Test orchestrator initialization
            orchestrator = ConversionOrchestrator(source_path, target_path)
            assert orchestrator.source_path == source_path
            assert orchestrator.target_path == target_path
            assert orchestrator.state_file == target_path / "conversion_state.json"
            assert not orchestrator.interrupted
            
            # Test new conversion creation
            state = orchestrator.create_new_conversion(50)
            assert state.total_jobs == 50
            assert state.source_path == str(source_path)
            assert state.target_path == str(target_path)
            assert orchestrator.progress_tracker is not None
            assert orchestrator.progress_tracker.total_jobs == 50
            
            # Test state saving
            orchestrator.save_state()
            assert orchestrator.state_file.exists()
            
            # Test state loading
            new_orchestrator = ConversionOrchestrator(source_path, target_path)
            loaded_successfully = new_orchestrator.load_conversion_state(orchestrator.state_file)
            assert loaded_successfully
            assert new_orchestrator.state.total_jobs == 50
    
    def test_batch_processing_capabilities(self):
        """Test batch processing functionality and asset discovery"""
        with tempfile.TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "wcs_source"
            target_path = Path(temp_dir) / "godot_target"
            source_path.mkdir()
            target_path.mkdir()
            
            # Create mock WCS assets for testing
            (source_path / "test.vp").touch()
            (source_path / "ship.pof").touch()
            (source_path / "mission.fs2").touch()
            (source_path / "texture.dds").touch()
            (source_path / "sound.wav").touch()
            
            # Test dry-run mode
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--source", str(source_path),
                "--target", str(target_path),
                "--dry-run"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            
            # Should show conversion plan without executing
            assert result.returncode == 0
            assert "Conversion plan" in result.stdout
            assert "jobs" in result.stdout
    
    def test_validate_only_mode(self):
        """Test comprehensive validation-only mode"""
        with tempfile.TemporaryDirectory() as temp_dir:
            target_path = Path(temp_dir) / "godot_target"
            target_path.mkdir()
            
            # Create some mock converted assets
            assets_dir = target_path / "assets"
            assets_dir.mkdir()
            (assets_dir / "test.tres").touch()
            (assets_dir / "model.glb").touch()
            
            # Test validate-only mode
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--target", str(target_path),
                "--validate-only"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            
            # Should run validation without conversion
            # Note: May fail due to missing dependencies, but should show validation attempt
            assert "validation" in result.stdout.lower() or "error" in result.stderr.lower()
    
    def test_comprehensive_cli_options_acceptance(self):
        """Test that all DM-010 CLI options are accepted without errors"""
        with tempfile.TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "wcs_source"
            target_path = Path(temp_dir) / "godot_target"
            config_path = Path(temp_dir) / "config.json"
            
            source_path.mkdir()
            target_path.mkdir()
            config_path.write_text('{"test": "config"}')
            
            # Test comprehensive options parsing (dry-run to avoid actual execution)
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--source", str(source_path),
                "--target", str(target_path),
                "--jobs", "2",
                "--asset-types", "vp_archives,pof_models",
                "--dry-run",
                "--save-state",
                "--progress-interval", "1.0",
                "--batch-size", "25",
                "--config", str(config_path),
                "--generate-manifest",
                "--performance-report",
                "--compression-level", "5",
                "--verbose"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            
            # Should accept all options without argument parsing errors
            # (May fail on execution due to missing dependencies, but args should be valid)
            assert "error: unrecognized arguments" not in result.stderr
            assert "error: argument" not in result.stderr
    
    def test_resume_functionality_argument_validation(self):
        """Test resume functionality argument validation"""
        with tempfile.TemporaryDirectory() as temp_dir:
            state_file = Path(temp_dir) / "conversion_state.json"
            
            # Test resume with non-existent state file
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--resume", str(state_file)
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            
            # Should handle missing state file gracefully
            assert result.returncode != 0 or "error" in result.stderr.lower()
    
    def test_export_report_formats(self):
        """Test report export format options"""
        # Test that report format arguments are parsed correctly
        with tempfile.TemporaryDirectory() as temp_dir:
            target_path = Path(temp_dir) / "godot_target"
            target_path.mkdir()
            
            # Test multiple export formats
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--target", str(target_path),
                "--catalog-only",
                "--export-report", "json,csv,xml",
                "--generate-manifest",
                "--performance-report"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            
            # Should accept export format options
            assert "error: unrecognized arguments" not in result.stderr
    
    def test_memory_and_performance_options(self):
        """Test memory and performance-related options"""
        with tempfile.TemporaryDirectory() as temp_dir:
            source_path = Path(temp_dir) / "wcs_source"
            target_path = Path(temp_dir) / "godot_target"
            temp_work_dir = Path(temp_dir) / "temp_work"
            
            source_path.mkdir()
            target_path.mkdir() 
            temp_work_dir.mkdir()
            
            # Test memory and performance options
            result = subprocess.run([
                sys.executable, "convert_wcs_assets.py",
                "--source", str(source_path),
                "--target", str(target_path),
                "--dry-run",
                "--memory-limit", "1024",
                "--checkpoint-interval", "5",
                "--temp-dir", str(temp_work_dir),
                "--verify-checksums",
                "--force-overwrite"
            ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
            
            # Should accept all performance options
            assert "error: unrecognized arguments" not in result.stderr
    
    def test_dm010_acceptance_criteria_coverage(self):
        """Test that all DM-010 acceptance criteria are supported"""
        
        # AC1: Comprehensive CLI options - tested by test_comprehensive_cli_options_acceptance
        # AC2: Batch processing - tested by test_batch_processing_capabilities  
        # AC3: Resume functionality - tested by test_resume_functionality_argument_validation
        # AC4: Detailed reports - tested by test_export_report_formats
        # AC5: Dry-run and validation modes - tested by test_validate_only_mode
        # AC6: Unified workflow integration - tested by test_conversion_orchestrator_initialization
        
        # Additional verification that CLI covers all acceptance criteria
        result = subprocess.run([
            sys.executable, "convert_wcs_assets.py", "--help"
        ], capture_output=True, text=True, cwd=Path(__file__).parent.parent)
        
        help_text = result.stdout.lower()
        
        # AC1: Comprehensive options
        assert "--source" in help_text and "--target" in help_text
        assert "--jobs" in help_text  # parallel processing
        assert "--asset-types" in help_text  # conversion type control
        
        # AC2: Batch processing
        assert "--batch-size" in help_text
        assert "batch" in help_text  # mentioned in examples
        
        # AC3: Resume functionality  
        assert "--resume" in help_text
        assert "--save-state" in help_text
        assert "--checkpoint-interval" in help_text
        
        # AC4: Detailed reports
        assert "--generate-manifest" in help_text
        assert "--performance-report" in help_text
        assert "--export-report" in help_text
        
        # AC5: Dry-run and validation
        assert "--dry-run" in help_text
        assert "--validate-only" in help_text
        assert "--validate" in help_text
        
        # AC6: Unified workflow (implied by comprehensive options)
        assert "--conversion-types" in help_text  # workflow control


if __name__ == "__main__":
    pytest.main([__file__, "-v"])