#!/usr/bin/env python3
"""
Core functionality tests for WCS Configuration Migration

Tests the essential configuration migration features including settings conversion,
INI file parsing, Godot project generation, and integration workflows.

Author: Dev (GDScript Developer)
Date: January 29, 2025
Story: DM-009 - Configuration Migration
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import json
import sys
import tempfile
from pathlib import Path

import pytest

# Import the module under test
sys.path.append(str(Path(__file__).parent.parent))
from config_migrator import (AudioSettings, ConfigMigrator, GameplaySettings,
                             GraphicsSettings)


class TestConfigMigrationCore:
    """Core functionality tests for WCS Configuration Migration"""
    
    def test_config_migrator_initialization_and_graphics_conversion(self):
        """Test ConfigMigrator initialization and graphics settings conversion."""
        # Test basic initialization
        migrator = ConfigMigrator()
        assert migrator is not None
        
        # Test graphics settings conversion to Godot format
        graphics = GraphicsSettings(
            resolution_width=1920,
            resolution_height=1080,
            fullscreen=True,
            vsync=True
        )
        
        godot_settings = graphics.to_godot_settings()
        assert godot_settings["display/window/size/viewport_width"] == 1920
        assert godot_settings["display/window/size/viewport_height"] == 1080
        
    def test_audio_settings_to_godot_conversion(self):
        """Test WCS audio settings conversion to Godot project format."""
        audio = AudioSettings(
            master_volume=0.8,
            music_volume=0.6,
            sfx_volume=0.9
        )
        
        audio_godot = audio.to_godot_settings()
        assert audio_godot["audio/driver/mix_rate"] == 44100
        
    def test_gameplay_settings_to_godot_conversion(self):
        """Test WCS gameplay settings conversion to Godot project format."""
        gameplay = GameplaySettings(
            difficulty=2,
            auto_targeting=True,
            show_subtitles=True
        )
        
        gameplay_godot = gameplay.to_godot_settings()
        assert gameplay_godot["game/difficulty_level"] == 2
        assert gameplay_godot["game/auto_targeting"] == True
        
    def test_wcs_control_actions_database_loaded(self):
        """Test that WCS control actions database is properly loaded and accessible."""
        migrator = ConfigMigrator()
        assert len(migrator.wcs_control_actions) > 0
        assert 0 in migrator.wcs_control_actions  # TARGET_NEXT
        assert 15 in migrator.wcs_control_actions  # FIRE_PRIMARY
        
    def test_complete_wcs_to_godot_migration_workflow(self):
        """Test complete WCS configuration migration including INI parsing, Godot generation, and validation."""
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

    def test_migrate_config_cli_tool_import(self):
        """Test that the migrate_config CLI tool can be imported successfully."""
        from migrate_config import main

        # If import succeeds, that's sufficient for this test
        assert main is not None