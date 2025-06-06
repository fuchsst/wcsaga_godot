# Collision Detection and Shape Management System

## Package Purpose
High-performance collision detection system for WCS-Godot conversion that provides multi-layer collision handling, dynamic shape generation, and intelligent filtering. Implements WCS-style collision pair management with Godot physics integration for optimal performance and accuracy.

## Original C++ Analysis
**WCS Source**: `source/code/object/objcollide.cpp`, `source/code/model/modelcollide.cpp`

**Key WCS Features Analyzed**:
- Object pair management system for efficient collision tracking
- Collision type filtering based on object type combinations (ships, weapons, debris, asteroids)
- Parent-child collision rejection to prevent inappropriate collisions
- Collision group system using bitwise operations for filtering
- Multi-level collision with bounding box tests followed by detailed mesh collision
- Performance optimization through collision pair timestamping and pooling

**WCS Collision Types Identified**:
- Ship-Weapon, Ship-Ship, Ship-Debris, Ship-Asteroid collisions
- Weapon-Debris, Weapon-Asteroid interactions
- Beam-Ship special collision handling
- Parent-child relationship filtering for debris created by ships

## Key Classes

### CollisionDetector
**Purpose**: Main collision detection coordinator with multi-layer support
**Key Methods**:
- `register_collision_object(object, layer)` - Register object for collision detection
- `generate_collision_shape(object, type)` - Create optimized collision shapes
- `_process_collision_pairs()` - Process active collision pairs for detection
- `_check_collision_pair(pair)` - Multi-level collision checking (broad/narrow phase)

**Features**:
- WCS-inspired collision pair management with pooling
- Multi-layer collision system (ships, weapons, debris, triggers)
- Performance optimization with collision timestamping
- Integration with Godot physics for broad phase detection

### CollisionFilter
**Purpose**: Intelligent collision filtering system based on WCS logic
**Key Methods**:
- `should_create_collision_pair(obj_a, obj_b)` - Main filtering logic
- `set_parent_child_relationship(child, parent)` - WCS-style parent tracking
- `set_object_collision_group(obj, group_id)` - Collision group management
- `_types_can_collide(obj_a, obj_b)` - Object type compatibility checking

**WCS Features**:
- Parent-child collision rejection (`reject_obj_pair_on_parent`)
- Collision group filtering (`reject_due_collision_groups`)
- Distance-based filtering for performance
- Object type matrix for collision compatibility

### ShapeGenerator
**Purpose**: Dynamic collision shape generation with caching optimization
**Key Methods**:
- `generate_collision_shape(object, type, use_cache)` - Main shape generation
- `generate_multi_level_shapes(object)` - Broad/narrow phase shapes
- `_generate_sphere_shape(object)` - Simple sphere collision
- `_generate_convex_hull_shape(object)` - Complex mesh-based collision

**Shape Types**:
- SPHERE: Simple broad phase collision
- BOX: Basic bounding box collision
- CAPSULE: Elongated objects (weapons, beams)
- CONVEX_HULL: Complex accurate collision from mesh
- TRIMESH: Exact mesh collision (expensive)
- COMPOUND: Multiple combined shapes

## Usage Examples

### Basic Object Registration
```gdscript
# Register objects for collision detection
var collision_detector = get_node("/root/CollisionDetector")
collision_detector.register_collision_object(ship_node, "ships")
collision_detector.register_collision_object(weapon_node, "weapons")
collision_detector.register_collision_object(debris_node, "debris")
```

### Multi-Level Shape Generation
```gdscript
# Generate shapes for different collision phases
var shape_generator = collision_detector.get_node("ShapeGenerator")
var shapes = shape_generator.generate_multi_level_shapes(ship_object)

# shapes.broad_phase - Simple sphere for fast initial checks
# shapes.narrow_phase - Detailed convex hull for accurate collision
# shapes.primary - Balanced shape for general use
```

### Collision Filtering Setup
```gdscript
# Set up parent-child relationships (WCS-style)
var collision_filter = collision_detector.get_node("CollisionFilter")
collision_filter.set_parent_child_relationship(debris_piece, parent_ship)

# Configure collision groups
collision_filter.set_object_collision_group(friendly_ship, 1)
collision_filter.set_object_collision_group(enemy_ship, 2)
```

### Performance Monitoring
```gdscript
# Monitor collision performance
var stats = collision_detector.get_collision_statistics()
print("Active collision pairs: ", stats.collision_pairs_active)
print("Checks this frame: ", stats.collision_checks_this_frame)

var shape_stats = shape_generator.get_shape_generation_statistics()
print("Cache hit rate: ", shape_stats.cache_hits / shape_stats.shapes_generated)
```

## Architecture Notes

### WCS to Godot Mapping
- **WCS obj_pair system** → **CollisionPair class** with Godot integration
- **WCS collision types** → **Type-specific collision functions** 
- **WCS parent signatures** → **Parent-child relationship tracking**
- **WCS collision groups** → **Bitwise collision group filtering**
- **WCS bounding tests** → **Multi-level broad/narrow phase detection**

### Performance Optimization
- **Collision Pair Pooling**: Reuse collision pair objects to minimize memory allocation
- **Shape Caching**: Cache generated collision shapes with LRU eviction
- **Timestamped Checking**: Only check collision pairs at appropriate intervals
- **Multi-Level Detection**: Use simple shapes for broad phase, complex for narrow phase
- **Distance Culling**: Skip collision checks for objects beyond interaction range

### Godot Integration
- Uses Godot's `PhysicsDirectSpaceState3D` for collision queries
- Integrates with collision layers and masks system
- Supports all Godot collision shape types
- Compatible with RigidBody3D, CharacterBody3D, and Area3D

## Integration Points

### EPIC-001 Foundation
- **PhysicsManager**: Receives collision detection events via `physics_step_completed` signal
- **ObjectManager**: Provides object lifecycle management for collision objects
- **WCSObject**: Base class extended by space objects requiring collision

### EPIC-002 Asset Core
- **ObjectTypes**: Centralized object type definitions for collision filtering
- **CollisionLayers**: Standardized collision layer constants
- **PhysicsProfile**: Physics behavior profiles for different object types

### EPIC-008 Graphics Engine
- **Model Loading**: Collision shapes generated from 3D model mesh data
- **LOD System**: Collision complexity scales with visual level of detail
- **Debug Visualization**: Collision shape visualization for development

## Performance Considerations

### Critical Performance Targets
- **Collision Detection**: <1ms per frame for 200 objects (AC4)
- **Shape Generation**: <0.1ms per shape generation operation (AC2)
- **Cache Performance**: 80%+ cache hit rate for shape generation (AC5)
- **Memory Usage**: Efficient collision pair pooling and shape caching

### Optimization Strategies
1. **Broad Phase Filtering**: Use simple bounding spheres to eliminate impossible collisions
2. **Narrow Phase Accuracy**: Use detailed shapes only when broad phase indicates collision
3. **Temporal Coherence**: Skip collision checks for pairs that rarely interact
4. **Spatial Partitioning**: Future integration with spatial hash for object queries
5. **Dynamic LOD**: Reduce collision complexity for distant or unimportant objects

## Testing Notes

### Test Coverage
- **Unit Tests**: `test_collision_detector.gd` covers all 6 acceptance criteria
- **Performance Tests**: Validates performance targets with 50+ test objects
- **Integration Tests**: Verifies Godot physics engine compatibility
- **Filter Tests**: Validates WCS-style collision filtering behavior

### Test Object Structure
```gdscript
class MockSpaceObject extends Node3D:
    # Implements required collision interface
    func get_object_type() -> int
    func has_collision_enabled() -> bool
    func get_collision_radius() -> float
    func get_parent_signature() -> int
```

### Running Tests
```bash
# Run collision system tests
cd target && bash addons/gdUnit4/runtest.sh -a tests/systems/objects/collision/
```

## Implementation Deviations

### WCS to Godot Adaptations
1. **Collision Pair Storage**: Uses GDScript Arrays instead of C linked lists for better Godot integration
2. **Shape Generation**: Leverages Godot's built-in collision shapes instead of custom mesh collision
3. **Physics Integration**: Uses Godot's PhysicsServer3D for collision queries instead of custom collision detection
4. **Memory Management**: Relies on Godot's garbage collection with object pooling for performance

### Enhanced Features Beyond WCS
1. **Multi-Level Shapes**: Broad/narrow phase shapes for better performance scaling
2. **Dynamic Shape Caching**: Intelligent caching system with performance monitoring
3. **Collision Layer Integration**: Full integration with Godot's collision layer system
4. **Debug Visualization**: Built-in collision visualization tools for development

The collision system successfully translates WCS's sophisticated collision detection to Godot while leveraging the engine's strengths for improved performance and maintainability.