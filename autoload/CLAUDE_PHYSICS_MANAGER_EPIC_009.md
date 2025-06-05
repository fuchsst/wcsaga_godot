# PhysicsManager EPIC-009 Enhancement Package Documentation

## Package Purpose

Enhanced PhysicsManager autoload with space physics integration for WCS-Godot conversion. Builds on EPIC-001 foundation with EPIC-009 space physics features including WCS-style physics simulation, physics profiles, force application, and SEXP integration.

## Original C++ Analysis

### Key C++ Components Analyzed

**WCS Physics System (`source/code/physics/physics.cpp`, `physics.h`)**:
- Core `apply_physics()` function using exponential damping with time constants
- Rotational physics with velocity caps (ROTVEL_CAP: 14.0, DEAD_ROTVEL_CAP: 16.3)
- Speed limits (MAX_SHIP_SPEED: 500.0, RESET_SHIP_SPEED: 440.0)
- Momentum conservation and 6 degrees of freedom movement
- Shockwave physics and special effects integration

**Physics Constants Analysis**:
- MAX_TURN_LIMIT: 0.2618 (~15 degrees maximum turn rate)
- Physics timestep fixed at 60Hz with accumulator pattern
- Space damping with time constants for realistic space flight feel
- Force application with proper Newtonian physics

### Key Findings
- **Damping Algorithm**: WCS uses exponential damping: `new_vel = dv * e^(-t/damping) + desired_vel`
- **Performance Focus**: WCS handles hundreds of objects with optimized collision detection
- **Space Physics**: Proper momentum conservation essential for authentic space flight feel
- **Fixed Timestep**: Critical for consistent physics simulation across frame rates

## Key Classes

### Enhanced PhysicsManager
**Purpose**: Core physics simulation manager with space physics integration.

**Responsibilities**:
- Manages hybrid Godot+WCS physics simulation
- Provides physics profiles for different object types
- Handles force application and momentum conservation
- Integrates with SEXP system for mission scripting
- Manages collision layers using wcs_asset_core constants

**Usage**:
```gdscript
# Register space object for enhanced physics
var fighter_profile: PhysicsProfile = PhysicsProfile.create_fighter_profile()
var success: bool = PhysicsManager.register_space_physics_body(space_ship, fighter_profile)

# Apply forces to space objects
PhysicsManager.apply_force_to_space_object(space_ship, Vector3(100, 0, 0), false)

# SEXP physics queries for mission scripting
var ship_speed: float = PhysicsManager.sexp_get_object_speed(ship_id)
var is_moving: bool = PhysicsManager.sexp_is_object_moving(ship_id, 1.0)
```

**EPIC-009 Enhanced Features**:
- Space physics configuration (6DOF, momentum conservation, Newtonian physics)
- Physics profiles cache with 7 pre-cached WCS object types
- WCS damping algorithm implementation (`_apply_wcs_damping()`)
- Force application queuing system for proper physics integration
- SEXP integration for mission script physics queries
- Enhanced performance stats with space physics metrics

## Architecture Notes

### EPIC-002 Asset Core Integration
The enhanced PhysicsManager mandatory uses wcs_asset_core addon for:
- **Collision Layers**: `CollisionLayers.Layer.SHIPS`, `CollisionLayers.Layer.WEAPONS`, etc.
- **Object Types**: `ObjectTypes.Type.FIGHTER`, `ObjectTypes.Type.CAPITAL`, etc.
- **Physics Profiles**: `PhysicsProfile` resources loaded from addon

### Hybrid Physics Architecture
- **Godot Physics**: Used for collision detection and basic simulation
- **WCS Physics**: Applied for damping, velocity caps, and space-specific behaviors
- **Coordination**: Seamless integration between both systems for optimal performance

### Performance Optimization
- **Physics Profiles Cache**: Pre-cached profiles for common object types
- **Force Application Queue**: Batched force processing during physics steps
- **Collision Layer Optimization**: Efficient bit mask operations using addon constants

## C++ to Godot Mapping

### Physics Algorithm Translation
- **C++ apply_physics()** → **GDScript _apply_wcs_damping()**
- **C++ physics timestep** → **Godot fixed timestep with accumulator**
- **C++ velocity caps** → **_apply_velocity_caps() with WCS constants**
- **C++ force application** → **Queued force system with RigidBody3D**

### Physics Constants Mapping
- **C++ MAX_TURN_LIMIT** → **PhysicsManager.MAX_TURN_LIMIT: 0.2618**
- **C++ ROTVEL_CAP** → **PhysicsManager.ROTVEL_CAP: 14.0**
- **C++ MAX_SHIP_SPEED** → **PhysicsManager.MAX_SHIP_SPEED: 500.0**
- **C++ physics frequency** → **60Hz fixed timestep in Godot**

### Integration Approach
- **WCS object_info** → **Godot RigidBody3D with PhysicsProfile**
- **WCS force application** → **Godot force/impulse queuing system**
- **WCS collision layers** → **wcs_asset_core CollisionLayers enum**

## Integration Points

### EPIC-001 Foundation Integration
```gdscript
# Enhanced existing PhysicsManager autoload
# Builds on: custom_bodies, collision_layers, physics_materials
# Adds: space_physics_bodies, physics_profiles_cache, force_applications
```

### EPIC-002 Asset Core Integration
```gdscript
# Mandatory addon usage for type definitions
const PhysicsProfile = preload("res://addons/wcs_asset_core/resources/object/physics_profile.gd")
const ObjectTypes = preload("res://addons/wcs_asset_core/constants/object_types.gd")
const CollisionLayers = preload("res://addons/wcs_asset_core/constants/collision_layers.gd")
```

### EPIC-004 SEXP Integration
```gdscript
# Physics queries for mission scripting
func sexp_get_object_speed(object_id: int) -> float
func sexp_is_object_moving(object_id: int, threshold: float = 1.0) -> bool
func sexp_apply_physics_impulse(object_id: int, impulse: Vector3) -> bool
```

## Performance Considerations

### Physics Step Performance
- **Target**: < 2ms per frame for 200 objects
- **Optimization**: Physics profiles cache prevents repeated resource loading
- **Batching**: Force applications processed in batches during physics steps

### Memory Management
- **Physics Profiles Cache**: 7 pre-cached profiles for common object types
- **Force Queue**: Efficient dictionary-based force application storage
- **Collision Optimization**: Bit mask operations using addon constants

### Monitoring
Enhanced performance stats include:
- `space_physics_bodies`: Number of space objects with enhanced physics
- `space_physics_objects_processed`: Objects processed per frame
- `force_applications_processed`: Forces applied per frame
- `cached_physics_profiles`: Number of cached physics profiles

## Testing Notes

### Unit Testing
Comprehensive test suite covers:
- **WCS Physics Constants**: Validation of C++ constant translation
- **Asset Core Integration**: Collision layers and object types from addon
- **Physics Profiles**: Cache initialization and profile validation
- **Force Application**: Queuing system and physics integration
- **SEXP Integration**: Physics queries for mission scripting

### Integration Testing
- **PhysicsManager Initialization**: Validates enhanced features activate correctly
- **Performance Stats**: Verifies enhanced metrics are available
- **Error Handling**: Tests invalid object and profile handling

### Test Execution
```bash
# Run EPIC-009 specific tests
export GODOT_BIN="/path/to/godot"
bash addons/gdUnit4/runtest.sh -a tests/autoload/test_physics_manager_epic_009.gd
```

## Implementation Deviations

### Intentional Changes from C++ Original

1. **Queued Force Application**: Instead of immediate force application, uses queued system for better Godot integration and performance.

2. **Hybrid Physics Mode**: Combines Godot's optimized collision detection with WCS damping algorithms for best of both worlds.

3. **Resource-Based Profiles**: Uses Godot Resource system for physics profiles instead of C++ structs for better editor integration.

4. **Enhanced Debug Information**: Adds comprehensive debug output and performance monitoring not present in original.

### Justifications

- **Performance**: Leverages Godot's optimized physics while maintaining WCS authenticity
- **Integration**: Resource-based approach integrates better with Godot editor and asset system
- **Debugging**: Enhanced monitoring helps track performance and debug physics issues
- **Maintainability**: Clear separation between Godot and WCS physics for easier maintenance

## Usage Examples

### Basic Space Object Physics
```gdscript
# Create space object with fighter physics
var space_ship: RigidBody3D = RigidBody3D.new()
var fighter_profile: PhysicsProfile = PhysicsManager.get_physics_profile_for_object_type(ObjectTypes.Type.FIGHTER)

# Register for enhanced physics
PhysicsManager.register_space_physics_body(space_ship, fighter_profile)

# Apply thrust force
PhysicsManager.apply_force_to_space_object(space_ship, Vector3(50, 0, 0))
```

### Mission Scripting Integration
```gdscript
# SEXP physics queries for mission logic
if PhysicsManager.sexp_is_object_moving(player_ship_id, 10.0):
    print("Player is moving fast!")

var current_speed: float = PhysicsManager.sexp_get_object_speed(enemy_ship_id)
if current_speed < 5.0:
    # Apply engine boost
    PhysicsManager.sexp_apply_physics_impulse(enemy_ship_id, Vector3(20, 0, 0))
```

### Performance Monitoring
```gdscript
# Monitor physics performance
var stats: Dictionary = PhysicsManager.get_performance_stats()
print("Space objects: %d" % stats["space_physics_bodies"])
print("Physics step time: %.2fms" % stats["physics_step_time_ms"])
print("Objects processed: %d" % stats["space_physics_objects_processed"])
```

This enhanced PhysicsManager provides the foundation for authentic WCS space physics while leveraging Godot's performance and maintaining clean integration with the rest of the WCS-Godot conversion project.