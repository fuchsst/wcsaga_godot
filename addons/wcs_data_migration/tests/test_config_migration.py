#!/usr/bin/env python3
"""
Unit tests for Configuration Migration (DM-009)

Tests the config_migrator.py module for converting WCS configuration files,
player settings, and control bindings to Godot-compatible format.

Author: Dev (GDScript Developer)  
Date: January 29, 2025
Story: DM-009 - Configuration Migration
Epic: EPIC-003 - Data Migration & Conversion Tools
"""

import json
import os
# Import the module under test
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.append(str(Path(__file__).parent.parent))
from config_migrator import (AudioSettings, ConfigMigrator, ConfigType,
                             ControlBinding, ControlType, GameplaySettings,
                             GraphicsSettings, PilotProfile)


class TestConfigurationMigration(unittest.TestCase):
    """Test suite for configuration migration functionality."""
    
    def setUp(self):
        """Set up test environment."""
        self.temp_dir = tempfile.mkdtemp()
        self.wcs_source_dir = Path(self.temp_dir) / "wcs_source"
        self.godot_target_dir = Path(self.temp_dir) / "godot_target"
        
        # Create directories
        self.wcs_source_dir.mkdir(parents=True)
        self.godot_target_dir.mkdir(parents=True)
        
        # Create test migrator
        self.migrator = ConfigMigrator()
        
        # Create mock WCS configuration files
        self._create_mock_wcs_files()
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.temp_dir)
    
    def _create_mock_wcs_files(self):
        """Create mock WCS configuration files for testing."""
        # Create mock WCS INI file
        wcs_ini_content = """[Graphics]
ScreenWidth=1920
ScreenHeight=1080
Fullscreen=true
VSync=true
Gamma=1.2
DetailLevel=3
AntiAlias=2

[Audio]
MasterVolume=0.8
MusicVolume=0.6
SFXVolume=0.9
VoiceVolume=0.7
SoundEnabled=true
MusicEnabled=true

[Game]
Difficulty=2
AutoTargeting=true
AutoSpeedMatching=false
ShowSubtitles=true
AutoAim=false
LandingHelp=true
"""
        
        with open(self.wcs_source_dir / "wcsaga.ini", 'w') as f:
            f.write(wcs_ini_content)
        
        # Create mock control config file
        control_config_content = """TARGET_NEXT=20
TARGET_PREV=21
FIRE_PRIMARY=57
FIRE_SECONDARY=28
FORWARD_THRUST=17
REVERSE_THRUST=31
BANK_LEFT=30
BANK_RIGHT=32
AFTERBURNER=15
"""
        
        with open(self.wcs_source_dir / "controls.cfg", 'w') as f:
            f.write(control_config_content)
        
        # Create mock pilot file (simplified JSON for testing)
        pilot_data = {
            "callsign": "TestPilot",
            "campaign_progress": 5,
            "total_kills": 42,
            "total_missions": 15,
            "skill_level": 2
        }
        
        with open(self.wcs_source_dir / "testpilot.pl2", 'w') as f:
            json.dump(pilot_data, f)

    def test_control_binding_creation(self):
        """Test ControlBinding data structure and Godot conversion."""
        binding = ControlBinding(
            action_name="TARGET_NEXT",
            action_id=0,
            key_binding=20,  # T key
            joy_binding=0,   # Joy button 0
            shift_key=False,
            ctrl_key=False,
            alt_key=False,
            description="Target Next Ship",
            category="targeting"
        )
        
        # Test basic properties
        self.assertEqual(binding.action_name, "TARGET_NEXT")
        self.assertEqual(binding.key_binding, 20)
        self.assertEqual(binding.joy_binding, 0)
        self.assertEqual(binding.category, "targeting")
        
        # Test Godot input event conversion
        events = binding.to_godot_input_event()
        self.assertIsInstance(events, list)
        self.assertGreater(len(events), 0)
        
        # Should have both keyboard and joystick events
        keyboard_events = [e for e in events if e["class"] == "InputEventKey"]
        joystick_events = [e for e in events if e["class"] == "InputEventJoypadButton"]
        
        self.assertEqual(len(keyboard_events), 1)
        self.assertEqual(len(joystick_events), 1)
        
        # Test keyboard event properties
        keyboard_event = keyboard_events[0]
        self.assertIn("keycode", keyboard_event)
        self.assertEqual(keyboard_event["shift_pressed"], False)
        self.assertEqual(keyboard_event["ctrl_pressed"], False)
        self.assertEqual(keyboard_event["alt_pressed"], False)
        
        # Test joystick event properties
        joystick_event = joystick_events[0]
        self.assertEqual(joystick_event["button_index"], 0)

    def test_graphics_settings_structure(self):
        """Test GraphicsSettings data structure and Godot conversion."""
        graphics = GraphicsSettings(
            resolution_width=1920,
            resolution_height=1080,
            fullscreen=True,
            vsync=True,
            gamma=1.2,
            detail_level=3,
            anti_aliasing=2
        )
        
        # Test basic properties
        self.assertEqual(graphics.resolution_width, 1920)
        self.assertEqual(graphics.resolution_height, 1080)
        self.assertTrue(graphics.fullscreen)
        self.assertTrue(graphics.vsync)
        self.assertEqual(graphics.gamma, 1.2)
        self.assertEqual(graphics.detail_level, 3)
        self.assertEqual(graphics.anti_aliasing, 2)
        
        # Test Godot settings conversion
        godot_settings = graphics.to_godot_settings()
        self.assertIsInstance(godot_settings, dict)
        
        # Check specific mappings
        self.assertEqual(godot_settings["display/window/size/viewport_width"], 1920)
        self.assertEqual(godot_settings["display/window/size/viewport_height"], 1080)
        self.assertEqual(godot_settings["display/window/size/mode"], 3)  # Fullscreen
        self.assertEqual(godot_settings["display/window/vsync/vsync_mode"], 1)  # VSync on
        self.assertEqual(godot_settings["rendering/anti_aliasing/quality/msaa_3d"], 2)

    def test_audio_settings_structure(self):
        """Test AudioSettings data structure and Godot conversion."""
        audio = AudioSettings(
            master_volume=0.8,
            music_volume=0.6,
            sfx_volume=0.9,
            voice_volume=0.7,
            sound_enabled=True,
            music_enabled=True,
            sample_rate=44100
        )
        
        # Test basic properties
        self.assertEqual(audio.master_volume, 0.8)
        self.assertEqual(audio.music_volume, 0.6)
        self.assertEqual(audio.sfx_volume, 0.9)
        self.assertEqual(audio.voice_volume, 0.7)
        self.assertTrue(audio.sound_enabled)
        self.assertTrue(audio.music_enabled)
        self.assertEqual(audio.sample_rate, 44100)
        
        # Test Godot settings conversion
        godot_settings = audio.to_godot_settings()
        self.assertIsInstance(godot_settings, dict)
        self.assertEqual(godot_settings["audio/driver/mix_rate"], 44100)

    def test_gameplay_settings_structure(self):
        """Test GameplaySettings data structure and Godot conversion."""
        gameplay = GameplaySettings(
            difficulty=2,
            auto_targeting=True,
            auto_speed_matching=False,
            show_subtitles=True,
            auto_aim=False,
            landing_help=True
        )
        
        # Test basic properties
        self.assertEqual(gameplay.difficulty, 2)
        self.assertTrue(gameplay.auto_targeting)
        self.assertFalse(gameplay.auto_speed_matching)
        self.assertTrue(gameplay.show_subtitles)
        self.assertFalse(gameplay.auto_aim)
        self.assertTrue(gameplay.landing_help)
        
        # Test Godot settings conversion
        godot_settings = gameplay.to_godot_settings()
        self.assertIsInstance(godot_settings, dict)
        self.assertEqual(godot_settings["game/difficulty_level"], 2)
        self.assertEqual(godot_settings["game/auto_targeting"], True)
        self.assertEqual(godot_settings["game/show_subtitles"], True)

    def test_pilot_profile_structure(self):
        """Test PilotProfile data structure and Godot save conversion."""
        pilot = PilotProfile(
            callsign="TestPilot",
            campaign_progress=8,
            total_kills=156,
            total_missions=25,
            skill_level=3,
            medals=["Distinguished Flying Cross", "Purple Heart"],
            stats={
                "primary_shots_fired": 15420,
                "primary_shots_hit": 8934,
                "flight_time_seconds": 14580
            }
        )
        
        # Test basic properties
        self.assertEqual(pilot.callsign, "TestPilot")
        self.assertEqual(pilot.campaign_progress, 8)
        self.assertEqual(pilot.total_kills, 156)
        self.assertEqual(pilot.total_missions, 25)
        self.assertEqual(pilot.skill_level, 3)
        self.assertEqual(len(pilot.medals), 2)
        self.assertIn("Distinguished Flying Cross", pilot.medals)
        
        # Test Godot save data conversion
        save_data = pilot.to_godot_save_data()
        self.assertIsInstance(save_data, dict)
        self.assertIn("pilot_data", save_data)
        
        pilot_data = save_data["pilot_data"]
        self.assertEqual(pilot_data["callsign"], "TestPilot")
        self.assertEqual(pilot_data["total_kills"], 156)
        self.assertEqual(pilot_data["campaign_progress"], 8)
        self.assertIn("statistics", pilot_data)

    def test_config_migrator_initialization(self):
        """Test ConfigMigrator initialization and control action setup."""
        migrator = ConfigMigrator()
        
        # Test initialization
        self.assertIsInstance(migrator.control_bindings, list)
        self.assertIsInstance(migrator.graphics_settings, GraphicsSettings)
        self.assertIsInstance(migrator.audio_settings, AudioSettings)
        self.assertIsInstance(migrator.gameplay_settings, GameplaySettings)
        self.assertIsInstance(migrator.pilot_profiles, list)
        
        # Test WCS control actions are loaded
        self.assertIsInstance(migrator.wcs_control_actions, dict)
        self.assertGreater(len(migrator.wcs_control_actions), 0)
        
        # Test specific control actions
        self.assertIn(0, migrator.wcs_control_actions)  # TARGET_NEXT
        self.assertIn(15, migrator.wcs_control_actions)  # FIRE_PRIMARY
        
        # Test control action structure
        action_data = migrator.wcs_control_actions[0]
        self.assertEqual(len(action_data), 3)  # name, description, category
        self.assertEqual(action_data[0], "TARGET_NEXT")
        self.assertIn("Target", action_data[1])
        self.assertEqual(action_data[2], "targeting")

    def test_ini_file_parsing(self):
        """Test parsing of WCS INI configuration files."""
        migrator = ConfigMigrator()
        
        # Test INI file parsing
        success = migrator._parse_wcs_config_files(self.wcs_source_dir)
        self.assertTrue(success)
        
        # Check that settings were parsed correctly
        self.assertEqual(migrator.graphics_settings.resolution_width, 1920)
        self.assertEqual(migrator.graphics_settings.resolution_height, 1080)
        self.assertTrue(migrator.graphics_settings.fullscreen)
        self.assertTrue(migrator.graphics_settings.vsync)
        self.assertEqual(migrator.graphics_settings.gamma, 1.2)
        self.assertEqual(migrator.graphics_settings.detail_level, 3)
        self.assertEqual(migrator.graphics_settings.anti_aliasing, 2)
        
        self.assertEqual(migrator.audio_settings.master_volume, 0.8)
        self.assertEqual(migrator.audio_settings.music_volume, 0.6)
        self.assertEqual(migrator.audio_settings.sfx_volume, 0.9)
        self.assertEqual(migrator.audio_settings.voice_volume, 0.7)
        self.assertTrue(migrator.audio_settings.sound_enabled)
        self.assertTrue(migrator.audio_settings.music_enabled)
        
        self.assertEqual(migrator.gameplay_settings.difficulty, 2)
        self.assertTrue(migrator.gameplay_settings.auto_targeting)
        self.assertFalse(migrator.gameplay_settings.auto_speed_matching)
        self.assertTrue(migrator.gameplay_settings.show_subtitles)
        self.assertFalse(migrator.gameplay_settings.auto_aim)
        self.assertTrue(migrator.gameplay_settings.landing_help)

    def test_control_config_parsing(self):
        """Test parsing of WCS control configuration."""
        migrator = ConfigMigrator()
        
        # Test control config parsing
        success = migrator._parse_wcs_control_config(self.wcs_source_dir)
        self.assertTrue(success)
        
        # Check that control bindings were created
        self.assertGreater(len(migrator.control_bindings), 0)
        
        # Find specific control bindings
        target_next_binding = None
        fire_primary_binding = None
        
        for binding in migrator.control_bindings:
            if binding.action_name == "TARGET_NEXT":
                target_next_binding = binding
            elif binding.action_name == "FIRE_PRIMARY":
                fire_primary_binding = binding
        
        # Verify default bindings exist
        self.assertIsNotNone(target_next_binding)
        self.assertIsNotNone(fire_primary_binding)
        
        # Check default key bindings
        self.assertEqual(target_next_binding.key_binding, 20)  # T key
        self.assertEqual(fire_primary_binding.key_binding, 57)  # Space

    def test_pilot_file_parsing(self):
        """Test parsing of WCS pilot profile files."""
        migrator = ConfigMigrator()
        
        # Test pilot file parsing
        success = migrator._parse_wcs_pilot_files(self.wcs_source_dir)
        self.assertTrue(success)
        
        # Check that pilot profiles were created
        self.assertGreater(len(migrator.pilot_profiles), 0)
        
        # Check pilot data (using simplified JSON format for testing)
        pilot = migrator.pilot_profiles[0]
        self.assertEqual(pilot.callsign, "testpilot")  # From filename

    @patch('winreg.OpenKey')
    @patch('winreg.QueryValueEx')
    def test_registry_parsing_windows(self, mock_query, mock_open):
        """Test parsing of Windows Registry settings (mocked)."""
        # Mock registry data
        mock_query.side_effect = [
            (1920, None),  # ScreenWidth
            (1080, None),  # ScreenHeight
            (1, None),     # Fullscreen
            (1, None),     # VSync
            (1.2, None),   # Gamma
            (2, None),     # DetailLevel
            (1, None),     # AntiAlias
        ]
        
        migrator = ConfigMigrator()
        
        # Test registry parsing (only on Windows)
        if os.name == 'nt':
            success = migrator._parse_wcs_registry()
            self.assertTrue(success)
            
            # Check parsed values
            self.assertEqual(migrator.graphics_settings.resolution_width, 1920)
            self.assertEqual(migrator.graphics_settings.resolution_height, 1080)

    def test_godot_project_settings_generation(self):
        """Test generation of Godot project.godot file."""
        migrator = ConfigMigrator()
        
        # Set up test settings
        migrator.graphics_settings.resolution_width = 1920
        migrator.graphics_settings.resolution_height = 1080
        migrator.graphics_settings.fullscreen = True
        migrator.graphics_settings.vsync = True
        
        # Generate project settings
        success = migrator._generate_godot_project_settings(self.godot_target_dir)
        self.assertTrue(success)
        
        # Check that project.godot was created
        project_file = self.godot_target_dir / "project.godot"
        self.assertTrue(project_file.exists())
        
        # Check content
        with open(project_file, 'r') as f:
            content = f.read()
        
        self.assertIn("[wcs_migration]", content)
        self.assertIn("display/window/size/viewport_width=1920", content)
        self.assertIn("display/window/size/viewport_height=1080", content)

    def test_godot_input_map_generation(self):
        """Test generation of Godot input map."""
        migrator = ConfigMigrator()
        
        # Create test control bindings
        migrator.control_bindings = [
            ControlBinding(
                action_name="TARGET_NEXT",
                action_id=0,
                key_binding=20,
                joy_binding=0,
                description="Target Next Ship",
                category="targeting"
            ),
            ControlBinding(
                action_name="FIRE_PRIMARY", 
                action_id=15,
                key_binding=57,
                joy_binding=0,
                description="Fire Primary Weapons",
                category="weapons"
            )
        ]
        
        # Generate input map
        success = migrator._generate_godot_input_map(self.godot_target_dir)
        self.assertTrue(success)
        
        # Check that input_map.cfg was created
        input_map_file = self.godot_target_dir / "input_map.cfg"
        self.assertTrue(input_map_file.exists())
        
        # Check content
        with open(input_map_file, 'r') as f:
            content = f.read()
        
        self.assertIn("target_next=", content)
        self.assertIn("fire_primary=", content)
        self.assertIn("Targeting Controls", content)
        self.assertIn("Weapons Controls", content)

    def test_migration_report_generation(self):
        """Test generation of migration validation report."""
        migrator = ConfigMigrator()
        
        # Set up test data
        migrator.control_bindings = [
            ControlBinding("TARGET_NEXT", 0, 20, 0, description="Target Next", category="targeting"),
            ControlBinding("FIRE_PRIMARY", 15, 57, 0, description="Fire Primary", category="weapons")
        ]
        migrator.pilot_profiles = [
            PilotProfile("TestPilot", campaign_progress=5, total_kills=42)
        ]
        
        # Generate migration report
        success = migrator._generate_migration_report(self.godot_target_dir)
        self.assertTrue(success)
        
        # Check that report was created
        report_file = self.godot_target_dir / "migration_report.json"
        self.assertTrue(report_file.exists())
        
        # Check report content
        with open(report_file, 'r') as f:
            report_data = json.load(f)
        
        self.assertIn("migration_info", report_data)
        self.assertIn("settings_migrated", report_data)
        self.assertIn("control_bindings", report_data)
        self.assertIn("pilot_profiles", report_data)
        self.assertIn("validation_results", report_data)
        
        # Check specific values
        self.assertEqual(report_data["control_bindings"]["total_bindings"], 2)
        self.assertEqual(report_data["pilot_profiles"]["total_profiles"], 1)

    def test_complete_migration_process(self):
        """Test complete end-to-end migration process."""
        migrator = ConfigMigrator()
        
        # Execute complete migration
        success = migrator.migrate_wcs_configuration(
            wcs_source_dir=self.wcs_source_dir,
            godot_target_dir=self.godot_target_dir
        )
        
        self.assertTrue(success)
        
        # Check that all expected files were created
        expected_files = [
            "project.godot",
            "input_map.cfg",
            "resources/configuration/game_settings.tres",
            "resources/configuration/user_preferences.tres",
            "resources/configuration/system_configuration.tres",
            "saves/pilots/testpilot.save",
            "migration_report.json"
        ]
        
        for file_path in expected_files:
            full_path = self.godot_target_dir / file_path
            self.assertTrue(full_path.exists(), f"Missing file: {file_path}")

    def test_validation_functions(self):
        """Test configuration validation functions."""
        migrator = ConfigMigrator()
        
        # Test graphics validation
        graphics_validation = migrator._validate_graphics_settings()
        self.assertIn("resolution_valid", graphics_validation)
        self.assertIn("overall_valid", graphics_validation)
        
        # Test audio validation
        audio_validation = migrator._validate_audio_settings()
        self.assertIn("master_volume_valid", audio_validation)
        self.assertIn("overall_valid", audio_validation)
        
        # Test control validation
        migrator.control_bindings = [
            ControlBinding("TARGET_NEXT", 0, 20, 0, description="Target Next", category="targeting"),
            ControlBinding("FIRE_PRIMARY", 15, 57, 0, description="Fire Primary", category="weapons")
        ]
        control_validation = migrator._validate_control_bindings()
        self.assertIn("bindings_count", control_validation)
        self.assertIn("core_controls_present", control_validation)
        self.assertIn("overall_valid", control_validation)
        
        # Test pilot validation
        migrator.pilot_profiles = [PilotProfile("TestPilot")]
        pilot_validation = migrator._validate_pilot_data()
        self.assertIn("pilot_count", pilot_validation)
        self.assertIn("overall_valid", pilot_validation)


if __name__ == '__main__':
    unittest.main()