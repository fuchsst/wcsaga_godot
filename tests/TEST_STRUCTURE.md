# Test Directory Structure

This document outlines the reorganized test directory structure that mirrors the scripts and scenes directory organization.

## Current Test Organization

### `/tests/` (Root Level)
- `run_core_manager_tests.gd` - Test runner for core managers
- `TEST_STRUCTURE.md` - This file

### `/tests/scenes/` (Scene-based Tests)
- `scenes/menus/briefing/`
  - `test_briefing_data_manager.gd`
  - `test_briefing_system_coordinator.gd`
- `scenes/menus/campaign/`
  - `test_campaign_data_manager.gd`
  - `test_campaign_selection_controller.gd`
  - `test_campaign_system_coordinator.gd`
- `scenes/menus/components/`
  - `test_menu_button.gd`
  - `test_menu_scene_helper.gd`
  - `test_ui_theme_manager.gd`
- `scenes/menus/main_menu/`
  - `test_main_menu_controller.gd`
- `scenes/menus/pilot/`
  - `test_pilot_creation_controller.gd`
  - `test_pilot_data_manager.gd`
  - `test_pilot_system_coordinator.gd`
- `scenes/menus/ship_selection/`
  - `test_loadout_manager.gd`
  - `test_ship_selection_data_manager.gd`
  - `test_ship_selection_system_coordinator.gd`
- `scenes/menus/statistics/`
  - `test_progression_tracker.gd`
  - `test_statistics_data_manager.gd`
  - `test_statistics_system_coordinator.gd`

### `/tests/scripts/` (Script-based Tests)
- `scripts/core/` - Core system tests (already organized)
- `scripts/debug/` - Debug system tests (ready for future tests)
- `scripts/effects/` - Effects system tests (ready for future tests)
- `scripts/graphics/` - Graphics system tests (ready for future tests)
- `scripts/hud/` - HUD system tests (ready for future tests)
- `scripts/mission_system/` - Mission system tests (ready for future tests)
- `scripts/missions/` - Mission tests (ready for future tests)
- `scripts/object/` - Object tests (ready for future tests)
- `scripts/player/` - Player tests (ready for future tests)
- `scripts/sound_animation/` - Sound/Animation tests (ready for future tests)

### `/tests/addons/` (Addon Tests)
- `addons/wcs_asset_core/`
  - `test_mission_data_validation.gd`

### `/tests/conversion_tools/` (Conversion Tool Tests)
- `test_config_migration.gd`
- `test_table_data_converter.gd`

### `/tests/unit/` (Unit Tests)
- Various unit tests for core components

### `/tests/integration/` (Integration Tests)
- Integration tests for complex workflows

### `/tests/mocks/` (Mock Objects)
- Mock implementations for testing

## Benefits of This Organization

1. **Mirror Structure**: Tests mirror the actual code organization
2. **Easy Navigation**: Find tests for specific components quickly
3. **Logical Grouping**: Related tests are grouped together
4. **Scalability**: Easy to add new tests in appropriate locations
5. **BMAD Compliance**: Follows established project patterns

## Test Naming Convention

Tests follow the pattern: `test_{component_name}.gd` where `{component_name}` matches the script being tested.

## Future Additions

When adding new scripts to the project:
1. Create corresponding test in the matching directory structure
2. Follow the naming convention
3. Include in the appropriate test suite runner
4. Document any special testing requirements

This structure ensures maintainability and clarity as the project grows.