# Scenes Directory

## Purpose
Game scenes and UI components for WCS-Godot.

## Structure
- **core/**: Foundation scene templates (WCSObject, PhysicsBody, InputReceiver)
- **main/**: EPIC-006 - Main menu system (bootstrap, start screen, main hall, intro, user management)
- **menus/**: EPIC-006 - Organized menu system with modern architecture
  - **briefing/**: Mission briefing interface with tactical map
  - **campaign/**: Campaign selection and progress display
  - **components/**: Shared UI components (buttons, dialogs, themes)
  - **debriefing/**: Post-mission debriefing with comprehensive results
  - **main_menu/**: Main menu navigation and scene structure
  - **options/**: Complete options system (graphics, audio, controls)
  - **pilot/**: Pilot creation, selection, and statistics management
  - **ship_selection/**: Ship and weapon loadout selection
  - **statistics/**: Statistics tracking and progression display
- **ui/**: Legacy UI components (being migrated to menus/)
  - **components/**: Reusable UI components (buttons, dialogs, lists)
  - Control mapping and options system (legacy implementations preserved as reference)
- **in_flight/**: EPIC-012 - In-mission HUD interface
- **effects/**: Visual effect templates (beams, explosions)
- **utility/**: Development tools (observer viewpoint)

## Cleanup Status (2025-01-06)
✅ **Completed**: Removed duplicate/stub mission scenes (missions/ folder)
✅ **Completed**: Moved legacy options code to menus/options/legacy_reference/
✅ **Completed**: Moved barracks implementation to menus/pilot/legacy_reference_barracks.gd
✅ **Completed**: Cleaned up stub UI scenes (barracks, campaign, tech_room)
✅ **Completed**: Removed obsolete UI options files (controls_options, hud_options, options)
✅ **Completed**: Removed obsolete control_line component (replaced by MENU-011)
✅ **Completed**: Removed obsolete details_options (replaced by MENU-010)
✅ **Completed**: Removed obsolete barracks scene from main/ (moved to menus/pilot/)
✅ **Completed**: Preserved legitimate UI components (axis_line, components/, etc.)

## Key Guidelines
- Use scene composition over inheritance
- Signal-based communication between scenes
- Bootstrap scene initializes core managers
- All scenes must be compatible with GameStateManager
- New implementations use menus/ structure following EPIC-006 patterns

## Implementation Notes
- Bootstrap scene initializes core managers and tests system startup
- Scene transitions managed by SceneManager addon
- Mission scenes consolidated into menus/ with proper MVC architecture
- UI scenes integrate with ConfigurationManager for persistent settings
- HUD system implemented as scenes with gauge components
- Foundation templates provide consistent object patterns
- Legacy implementations preserved as reference for conversion patterns

## Migration Status
- **missions/** → **menus/**: ✅ Complete (stub scenes removed, functionality in menus/)
- **ui/options** → **menus/options/**: ✅ Complete (legacy preserved as reference)
- **main/barracks** → **menus/pilot/**: ✅ Complete (legacy preserved as reference)
- **ui/controls** → **menus/options/**: 🚧 In Progress (MENU-011 implementation)