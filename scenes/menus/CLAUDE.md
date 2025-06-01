# Menu System Package - EPIC-006 Implementation

## Package Purpose
Modern menu and navigation system for WCS-Godot following EPIC-006 architecture. Replaces legacy main hall system with Godot-native scene-based navigation integrated with existing autoload systems.

## Key Classes

### MainMenuController (scenes/menus/main_menu/)
- **Purpose**: Primary menu navigation controller
- **Responsibilities**: Menu option handling, state transitions, performance monitoring
- **Integration**: GameStateManager, SceneManager, ConfigurationManager
- **Key Methods**:
  - `_on_menu_option_selected(option: MenuOption)` - Handle menu selections
  - `_request_state_transition(target_state: GameStateManager.GameState)` - Request state changes
  - `is_menu_ready() -> bool` - Check system readiness

### Legacy MainHallController (scenes/main/)
- **Status**: DEPRECATED - Use MainMenuController instead
- **Purpose**: Maintains compatibility while transitioning to new system
- **Migration**: Replace with MainMenuController for new implementations

## Usage Examples

### Basic Menu Navigation
```gdscript
# Initialize menu system
var main_menu: MainMenuController = preload("res://scenes/menus/main_menu/main_menu_controller.gd").new()

# Connect to menu events
main_menu.menu_option_selected.connect(_on_menu_option_selected)
main_menu.menu_transition_requested.connect(_on_menu_transition_requested)

# Check menu readiness
if main_menu.is_menu_ready():
    main_menu.force_menu_option(MainMenuController.MenuOption.PILOT_MANAGEMENT)
```

### State Management Integration
```gdscript
# Menu system automatically integrates with GameStateManager
func _on_menu_transition_requested(target_state: GameStateManager.GameState) -> void:
    print("Menu requesting transition to: %s" % GameStateManager.GameState.keys()[target_state])
    
# Listen for state changes
GameStateManager.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(old_state: GameStateManager.GameState, new_state: GameStateManager.GameState) -> void:
    print("State changed from %s to %s" % [old_state, new_state])
```

## Architecture Notes

### Integration with Existing Systems
- **GameStateManager**: Handles all state transitions and game flow
- **SceneManager**: Manages scene loading and transition effects  
- **ConfigurationManager**: Persists menu settings and preferences
- **WCS Asset Core**: Loads menu assets (backgrounds, audio, UI elements)

### Performance Requirements
- **Target FPS**: 60fps consistent
- **Transition Time**: <100ms for menu transitions
- **Memory Usage**: Minimal allocation during menu operations
- **Load Times**: <2 seconds for menu initialization

### Signal Architecture
```gdscript
# Main menu signals
signal menu_option_selected(option: MenuOption)
signal menu_transition_requested(target_state: GameStateManager.GameState)
signal menu_initialized()
signal menu_error(error_message: String)

# Integration signals (from autoloads)
GameStateManager.state_changed(old_state, new_state)
GameStateManager.state_transition_started(target_state)
GameStateManager.state_transition_completed(final_state)
```

## Integration Points

### With EPIC-001 (Core Foundation)
- Uses GameStateManager for state coordination
- Integrates ConfigurationManager for settings persistence
- Leverages existing autoload initialization order

### With EPIC-002 (Asset Structures)  
- Loads menu assets through WCS Asset Core
- Uses defined asset types: MENU_BACKGROUND, MENU_AUDIO, TEXTURE
- Follows established asset loading patterns

### With EPIC-004 (SEXP System)
- Conditional menu options based on SEXP evaluation
- Mission/campaign availability through SEXP conditions
- Integration with mission briefing system

### With EPIC-005 (GFRED2 Plugin)
- Editor menu integration for GFRED2 workflow
- Scene organization matching GFRED2 patterns
- Development tool menu options

## Performance Considerations

### Optimization Strategies
- **Lazy Loading**: Menu scenes loaded on-demand
- **Asset Preloading**: Critical assets preloaded at startup
- **Signal Efficiency**: Minimal signal connections, proper disconnection
- **Memory Management**: Proper node cleanup, avoid memory leaks

### Monitoring and Validation
- Built-in performance monitoring when enabled
- Automatic FPS and transition time tracking
- Warning system for performance degradation
- Debug mode for detailed performance analysis

## Testing Notes

### Test Coverage Areas
- Menu navigation and option selection
- State transition handling
- Integration with autoload systems
- Performance under load
- Error handling and recovery
- Keyboard and mouse input handling

### Test Files
- `tests/test_main_menu_controller.gd` - Comprehensive menu controller testing
- `tests/mocks/mock_game_state_manager.gd` - Mock autoload for testing
- Manual testing guide in scene structure documentation

### Testing Requirements
- Unit tests for all public methods
- Integration tests for autoload system interaction
- Performance tests for FPS and transition timing
- Accessibility tests for keyboard navigation

## Migration Guide

### From Legacy MainHallController
1. Replace `MainHallController` references with `MainMenuController`
2. Update signal connections to new signal names
3. Use `MenuOption` enum instead of direct scene transitions
4. Integrate with GameStateManager instead of direct SceneManager calls
5. Update button mapping to match new architecture

### Scene Structure Updates
1. Create new scene structure following `main_menu_scene_structure.md`
2. Import WCS assets using WCS Asset Core patterns
3. Configure UI themes and styling
4. Test integration with existing autoload systems
5. Validate performance requirements

## Development Guidelines

### Code Standards
- All variables and methods must use static typing
- Comprehensive docstrings for all public methods
- Error handling with proper push_error/push_warning usage
- Signal-based communication, avoid direct method calls
- Performance monitoring integration for critical paths

### Scene Organization
- Follow established GFRED2 scene organization patterns
- Use composition over inheritance for menu components
- Consistent naming conventions across all menu scenes
- Proper node hierarchy with clear responsibilities

### Integration Requirements
- Must integrate with all existing autoload systems
- Cannot create new autoload dependencies
- Must use established asset loading patterns
- Follow EPIC-006 architecture specifications exactly

This menu system provides the foundation for all user interaction in WCS-Godot while maintaining compatibility with existing systems and enabling future expansion.