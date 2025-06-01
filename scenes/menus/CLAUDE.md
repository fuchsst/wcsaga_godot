# Menu System Package - EPIC-006

## Purpose
Modern menu and navigation system for WCS-Godot. Replaces legacy main hall system with Godot-native scene-based navigation integrated with existing autoload systems.

## Architecture
- **Signal-driven navigation** using GameStateManager for state transitions
- **Scene composition** over inheritance for menu components
- **Performance targets**: 60fps, <100ms transitions, <2s load times
- **Integration**: GameStateManager, SceneManager, ConfigurationManager, WCS Asset Core

## Key Components

### Main Menu Navigation
- `main_menu/` - Primary navigation controller
- `components/` - Shared UI components (buttons, dialogs, themes)

### Content Systems
- `briefing/` - Mission briefing with tactical map
- `campaign/` - Campaign selection and progress
- `debriefing/` - Post-mission results
- `pilot/` - Pilot creation and management
- `ship_selection/` - Ship and weapon loadout
- `statistics/` - Statistics tracking

### Options System
- `options/` - Complete settings management
  - Graphics options (MENU-010) ✅
  - Audio and control mapping (MENU-011) ✅  
  - Settings persistence and validation (MENU-012) ✅

## Usage Pattern
```gdscript
# Standard menu integration
var main_menu: MainMenuController = preload("res://scenes/menus/main_menu/main_menu_controller.gd").new()
main_menu.menu_option_selected.connect(_on_menu_option_selected)

# State transitions via GameStateManager
func _on_menu_transition_requested(target_state: GameStateManager.GameState) -> void:
    GameStateManager.request_state_transition(target_state)
```

## Development Guidelines
- **Static typing required** for all variables and methods
- **Signal-based communication** - avoid direct method calls
- **Scene composition** - use Control nodes with proper hierarchy
- **Integration compliance** - must use existing autoloads, no new autoload dependencies
- **Performance monitoring** - built-in FPS and transition time tracking

## Implementation Status
**Phase 4 Complete**: Graphics, Audio, and Settings systems ✅  
**Next**: Phase 1 Core Menu Framework (MENU-001, MENU-002, MENU-003)

This system provides the foundation for all user interaction in WCS-Godot while maintaining compatibility with existing systems and enabling future expansion.