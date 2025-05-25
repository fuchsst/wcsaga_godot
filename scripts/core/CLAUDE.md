# Core Foundation Systems Package

## Overview
This package contains the four core manager singletons that form the foundation of the WCS-Godot conversion. These managers handle fundamental game systems including object lifecycle, game state management, custom physics simulation, and high-precision input processing.

## Architecture
The core managers follow a singleton pattern via Godot's autoload system, providing global access while maintaining proper encapsulation and static typing throughout.

## Key Classes

### ObjectManager
**Location**: `object_manager.gd`
**Purpose**: Central object lifecycle management with performance optimization through pooling
**Key Features**:
- Handles 1000+ concurrent objects with update frequency grouping
- Object pooling for common types (Bullet, Particle, Debris, Effect)
- Performance tracking and debug metrics
- Signal-based object lifecycle events

**Usage Example**:
```gdscript
# Register a new WCS object
var ship: WCSObject = MyShip.new()
ObjectManager.register_object(ship)

# Access debug statistics
var stats: Dictionary = ObjectManager.get_debug_stats()
print("Active objects: %d" % stats.active_count)
```

### GameStateManager  
**Location**: `game_state_manager.gd`
**Purpose**: Central game state controller for menu/mission/briefing flow
**Key Features**:
- State machine with validation for game flow transitions
- State stack for pause/resume functionality
- Scene loading and management with timeout protection
- Persistent data storage across state transitions

**Usage Example**:
```gdscript
# Request state change
GameStateManager.request_state_change(GameStateManager.GameState.BRIEFING)

# Push temporary state (like pause menu)
GameStateManager.push_state(GameStateManager.GameState.PAUSED)

# Return to previous state
GameStateManager.pop_state()
```

### PhysicsManager
**Location**: `physics_manager.gd`  
**Purpose**: Hybrid physics system preserving WCS feel while leveraging Godot performance
**Key Features**:
- Fixed 60Hz timestep for consistent physics simulation
- Custom physics bodies with WCS-specific properties
- Integration with Godot collision detection
- Performance-optimized update scheduling

**Usage Example**:
```gdscript
# Register object for custom physics
PhysicsManager.register_physics_body(my_ship)

# Apply forces in WCS style
PhysicsManager.apply_force(my_ship, Vector3(0, 0, -100))

# Query collision detection
var raycast_result: Dictionary = PhysicsManager.raycast(start_pos, end_pos)
```

### InputManager
**Location**: `input_manager.gd`
**Purpose**: High-precision input handling optimized for space flight controls  
**Key Features**:
- <16ms input latency target for responsive controls
- Analog deadzone and curve processing for space flight feel
- Auto-detection of control schemes (keyboard/mouse, gamepad, joystick)
- Device hot-swapping support

**Usage Example**:
```gdscript
# Get processed analog input with deadzone/curve applied
var pitch_input: float = InputManager.get_processed_analog("ship_pitch")

# Check current control scheme
if InputManager.current_scheme == InputManager.ControlScheme.JOYSTICK:
    # Enable joystick-specific UI elements
```

### WCSObject Base Class
**Location**: `wcs_object.gd`
**Purpose**: Base class for all WCS game objects providing common functionality
**Key Features**:
- Object lifecycle management with automatic cleanup
- Update frequency classification for performance optimization
- Performance tracking for frame time analysis
- Pooling support for frequently created/destroyed objects

## Integration Points

### With Existing WCS Systems
- Integrates with existing `GameState` global for gradual migration
- Maintains compatibility with existing scene management
- Preserves WCS-specific physics behaviors and constants

### With Godot Engine
- Leverages Godot's autoload system for singleton management
- Uses Godot's signal system for loose coupling
- Integrates with Godot's collision detection for performance
- Follows Godot's node lifecycle patterns

### Debug Monitoring
- All managers expose `get_debug_stats()` for real-time monitoring
- Debug overlay available via F12 key (`scenes/debug/manager_debug_overlay.tscn`)
- Performance metrics for frame times, object counts, and system health

## Performance Considerations

### Object Management
- Object pooling reduces GC pressure for frequently spawned objects
- Update frequency grouping reduces CPU overhead (60/30/15/5 FPS groups)
- Efficient object lookup via hash tables and arrays

### Physics Simulation
- Fixed timestep prevents physics inconsistencies
- Hybrid approach combines custom WCS physics with Godot collision detection
- Collision pair caching reduces redundant calculations

### Input Processing
- Low-latency input processing with <16ms target
- Efficient analog processing with deadzone/curve calculations
- Device state caching to avoid repeated API calls

## Testing Notes
- Unit tests available in `tests/test_core_managers.gd`
- Tests cover initialization, basic functionality, and integration
- Debug stats validation ensures monitoring works correctly
- Performance tests validate target benchmarks

## Future Enhancements
- **LimboAI Integration**: Consider integrating LimboAI state machines for AI behavior (as suggested)
- **Advanced Pooling**: Implement per-type pool size limits and overflow handling
- **Physics Optimization**: Add spatial partitioning for collision detection
- **Input Replay**: Add input recording/playback for testing and demos
- **Network Support**: Extend managers for multiplayer synchronization

## Dependencies
- Godot Engine 4.2+
- No external dependencies for core functionality
- Debug overlay requires RichTextLabel support

## Configuration
Managers can be configured via export variables:
- `ObjectManager.max_objects`: Maximum concurrent objects (default: 1000)
- `PhysicsManager.physics_frequency`: Physics update rate (default: 60Hz)  
- `InputManager.analog_deadzone`: Analog stick deadzone (default: 0.1)
- All managers support `enable_debug_logging` for development builds