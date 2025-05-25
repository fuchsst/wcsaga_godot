# Utility Scripts Package

## Overview
This package contains general utility classes and helper functions used throughout the WCS-Godot conversion project. These utilities provide common functionality for mathematical operations, debugging, data conversion, and other support functions.

## Core Utilities

### WCSObject Base Class
**Location**: `wcs_object.gd`
**Purpose**: Base class for all WCS game objects providing common functionality
**Key Features**:
- Object lifecycle management with automatic cleanup
- Update frequency classification for performance optimization
- Performance tracking for frame time analysis
- Pooling support for frequently created/destroyed objects
- Integration with ObjectManager for centralized management

**Usage Example**:
```gdscript
# Extend WCSObject for game entities
class_name MyShip
extends WCSObject

func _ready() -> void:
    super._ready()  # Registers with ObjectManager
    object_type = ObjectType.SHIP
    update_frequency = UpdateFrequency.EVERY_FRAME

func _update_object(delta: float) -> void:
    # Custom update logic for this object
    position += velocity * delta
```

## Integration with Core Systems

### ObjectManager Integration
WCSObject automatically integrates with the ObjectManager autoload:
- Self-registration on `_ready()`
- Automatic cleanup on destruction
- Performance tracking and monitoring
- Update frequency optimization

### Performance Features
- **Update Frequency Groups**: Objects classified by update needs (60/30/15/5 FPS)
- **Lifecycle Management**: Automatic registration, activation, deactivation, cleanup
- **Performance Tracking**: Frame time monitoring and debugging support
- **Pooling Support**: Reset functionality for object reuse

## Utility Functions

### Object Management
```gdscript
# Get object performance metrics
var avg_time: float = my_object.get_average_frame_time()

# Check object age and status
var age: float = my_object.get_age()
var active: bool = my_object.is_active

# Object pooling
my_object.reset_for_pooling()  # Prepare for reuse
```

### Debug Information
```gdscript
# Get comprehensive debug info
var debug_info: Dictionary = my_object.get_debug_info()
# Returns: id, type, update_frequency, age, active, pooled, performance metrics
```

## Architecture Notes

### Design Patterns
- **Component Pattern**: WCSObject serves as base for composition
- **Observer Pattern**: Signals for lifecycle events
- **Object Pool Pattern**: Built-in support for pooling
- **Factory Pattern**: Compatible with object creation systems

### Memory Management
- Automatic cleanup prevention through lifecycle management
- Optional auto-cleanup with configurable lifetime limits
- Performance tracking to identify memory-intensive objects
- Integration with Godot's garbage collection

## Project Structure Integration

### Moved from Core
This utility package was reorganized from the original core foundation:
- Core managers moved to `autoload/` (ObjectManager, GameStateManager, etc.)
- Asset pipeline moved to `migration_tools/asset_pipeline/`
- General utilities remain here for project-wide use

### Current Location
```
scripts/utils/
├── CLAUDE.md          # This documentation
└── wcs_object.gd      # Base object class for all WCS entities
```

## Performance Considerations

### Update Optimization
- Objects grouped by update frequency to reduce CPU overhead
- Distance-based LOD system can adjust update frequency dynamically
- Performance tracking helps identify bottlenecks

### Memory Efficiency
- Object pooling reduces garbage collection pressure
- Lifecycle management prevents memory leaks
- Configurable cleanup timers for temporary objects

## Testing and Validation

### Unit Testing
WCSObject functionality is tested in:
- `tests/unit/test_core_managers.gd` - Integration with ObjectManager
- Object lifecycle and performance tracking validation
- Memory management and cleanup verification

### Debug Support
- Comprehensive debug information for troubleshooting
- Performance metrics for optimization
- Integration with debug overlay system

## Usage Best Practices

### Extending WCSObject
```gdscript
class_name GameEntity
extends WCSObject

# Set object properties in _ready()
func _ready() -> void:
    super._ready()
    object_type = ObjectType.SHIP  # Or appropriate type
    update_frequency = UpdateFrequency.HIGH  # Based on needs
    max_lifetime = 300.0  # Optional cleanup timer

# Implement custom update logic
func _update_object(delta: float) -> void:
    # Your game logic here
    handle_movement(delta)
    update_animations(delta)

# Override for pooling support
func _reset_object_state() -> void:
    # Reset to initial state for reuse
    velocity = Vector3.ZERO
    health = max_health
```

### Performance Optimization
- Choose appropriate update frequency based on object importance
- Use object pooling for frequently created/destroyed objects
- Monitor performance metrics in debug builds
- Implement distance-based LOD for optimization

## Dependencies
- Godot Engine 4.4+
- ObjectManager autoload (for registration and management)
- No external dependencies

This utility package provides the foundation for all game objects in the WCS-Godot conversion while maintaining performance and clean architecture.