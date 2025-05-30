# Scenes Directory

## Purpose
Game scenes and UI components for WCS-Godot.

## Structure
- **core/**: Foundation scene templates (WCSObject, PhysicsBody, InputReceiver)
- **main/**: EPIC-006 - Main menu system (bootstrap, start screen, main hall, barracks)
- **missions/**: EPIC-005 - Mission flow scenes
  - **briefing/**: Mission briefing interface with components
  - **debriefing/**: Post-mission debriefing with stats
  - **ship_select/**: Ship selection interface
  - **weapon_select/**: Weapon loadout interface
  - **red_alert/**: Emergency mission start
- **ui/**: EPIC-006 - User interface components and options
  - **components/**: Reusable UI components (buttons, dialogs, lists)
  - Complete options system (controls, HUD, details)
- **in_flight/**: EPIC-012 - In-mission HUD interface
- **effects/**: Visual effect templates (beams, explosions)
- **utility/**: Development tools (observer viewpoint)

## Key Guidelines
- Use scene composition over inheritance
- Signal-based communication between scenes
- Bootstrap scene initializes core managers
- All scenes must be compatible with GameStateManager

## Implementation Notes
- Bootstrap scene initializes core managers and tests system startup
- Scene transitions managed by SceneManager addon
- Mission scenes implement complete WCS-style briefing/debriefing flow
- UI scenes integrate with ConfigurationManager for persistent settings
- HUD system implemented as scenes with gauge components
- Foundation templates provide consistent object patterns