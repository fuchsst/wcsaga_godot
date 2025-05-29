#!/usr/bin/env python3
"""
Basic integration test for DM-009 Configuration Migration functionality

Simple verification that the configuration migration system works without
dependencies on the broader project compilation issues.

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-009 - Configuration Migration
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import sys
import tempfile
import json
import pytest
from pathlib import Path

# Import the module under test
sys.path.append(str(Path(__file__).parent.parent))
from config_migrator import (
    ConfigMigrator, GraphicsSettings, AudioSettings, GameplaySettings
)


class TestDM009BasicFunctionality:
    """Basic functionality tests for DM-009 Configuration Migration"""
    
    def test_basic_config_migration(self):
        """Test basic configuration migration functionality."""
        # Test basic initialization
        migrator = ConfigMigrator()
        assert migrator is not None
        
        # Test graphics settings
        graphics = GraphicsSettings(
            resolution_width=1920,
            resolution_height=1080,
            fullscreen=True,
            vsync=True
        )
        
        godot_settings = graphics.to_godot_settings()
        assert godot_settings["display/window/size/viewport_width"] == 1920
        assert godot_settings["display/window/size/viewport_height"] == 1080
        
    def test_audio_settings_conversion(self):
        """Test audio settings conversion to Godot format."""
        audio = AudioSettings(
            master_volume=0.8,
            music_volume=0.6,
            sfx_volume=0.9
        )
        
        audio_godot = audio.to_godot_settings()
        assert audio_godot["audio/driver/mix_rate"] == 44100
        
    def test_gameplay_settings_conversion(self):
        """Test gameplay settings conversion to Godot format."""
        gameplay = GameplaySettings(
            difficulty=2,
            auto_targeting=True,
            show_subtitles=True
        )
        
        gameplay_godot = gameplay.to_godot_settings()
        assert gameplay_godot["game/difficulty_level"] == 2
        assert gameplay_godot["game/auto_targeting"] == True
        
    def test_wcs_control_actions_loaded(self):
        """Test that WCS control actions are properly loaded."""
        migrator = ConfigMigrator()
        assert len(migrator.wcs_control_actions) > 0
        assert 0 in migrator.wcs_control_actions  # TARGET_NEXT
        assert 15 in migrator.wcs_control_actions  # FIRE_PRIMARY
        
    def test_ini_file_parsing_and_integration(self):
        """Test INI file parsing and full integration workflow."""
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            wcs_source = temp_path / "wcs_source"
            godot_target = temp_path / "godot_target"
            
            wcs_source.mkdir()
            godot_target.mkdir()
            
            # Create a simple test configuration
            test_config = """[Graphics]
ScreenWidth=1024
ScreenHeight=768
Fullscreen=false

[Audio]
MasterVolume=1.0
MusicVolume=0.7

[Game]
Difficulty=1
AutoTargeting=true
"""
            
            with open(wcs_source / "test.ini", 'w') as f:
                f.write(test_config)
            
            # Test INI parsing
            migrator = ConfigMigrator()
            migrator._parse_ini_file(wcs_source / "test.ini")
            
            # Verify settings were parsed
            assert migrator.graphics_settings.resolution_width == 1024
            assert migrator.graphics_settings.resolution_height == 768
            assert migrator.graphics_settings.fullscreen == False
            assert migrator.audio_settings.master_volume == 1.0
            assert migrator.audio_settings.music_volume == 0.7
            assert migrator.gameplay_settings.difficulty == 1
            assert migrator.gameplay_settings.auto_targeting == True
            
            # Test project settings generation
            success = migrator._generate_godot_project_settings(godot_target)
            assert success
            assert (godot_target / "project.godot").exists()
            
            # Test input map generation
            migrator._create_default_control_bindings()
            success = migrator._generate_godot_input_map(godot_target)
            assert success
            assert (godot_target / "input_map.cfg").exists()
            
            # Test report generation
            success = migrator._generate_migration_report(godot_target)
            assert success
            assert (godot_target / "migration_report.json").exists()
            
            # Verify report content
            with open(godot_target / "migration_report.json", 'r') as f:
                report = json.load(f)
            
            assert "migration_info" in report
            assert "settings_migrated" in report
            assert "control_bindings" in report
            assert "validation_results" in report

    def test_cli_import(self):
        """Test that the CLI tool can be imported."""
        from migrate_config import main
        # If import succeeds, that's sufficient for this test
        assert main is not None