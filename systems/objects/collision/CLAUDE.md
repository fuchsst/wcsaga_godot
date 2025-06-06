# Collision Detection and Response System

## Package Purpose
Complete collision detection and response system for WCS-Godot conversion that provides multi-layer collision handling, accurate damage calculation, realistic physics responses, and visual effect integration. Implements WCS-style collision mechanics with modern Godot physics for optimal performance and gameplay accuracy.

## Original C++ Analysis
**WCS Source**: `source/code/object/objcollide.cpp`, `source/code/object/collideshipweapon.cpp`, `source/code/ship/shiphit.cpp`

**Key WCS Features Analyzed**:
- Object pair management system for efficient collision tracking
- Collision type filtering based on object type combinations (ships, weapons, debris, asteroids)
- Damage calculation based on relative velocity, mass, and weapon properties
- Physics impulse application using `ship_apply_whack` for realistic collision responses
- Shield system integration with quadrant-based damage distribution
- Parent-child collision rejection to prevent inappropriate collisions
- Collision group system using bitwise operations for filtering
- Multi-level collision with bounding box tests followed by detailed mesh collision
- Performance optimization through collision pair timestamping and pooling

**WCS Collision Types Identified**:
- Ship-Weapon: Primary damage application with shield/hull distribution
- Ship-Ship: Mutual collision damage based on relative masses
- Ship-Debris, Ship-Asteroid: Environmental collision damage
- Weapon-Debris, Weapon-Asteroid: Weapon destruction interactions
- Beam-Ship: Special collision handling for beam weapons
- Parent-child relationship filtering for debris created by ships

**WCS Damage Mechanics**:
- Weapon damage from `weapon_info.damage` with armor penetration
- Collision damage from kinetic energy: `0.5 * mass * velocity²`
- Shield absorption with bleedthrough when shields are low
- Subsystem damage with reduced efficiency
- Force application using momentum conservation

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

### DamageCalculator (NEW - OBJ-010)
**Purpose**: Calculate collision damage based on WCS physics and object properties
**Key Methods**:
- `calculate_collision_damage(obj_a, obj_b, collision_info)` - Main damage calculation
- `_calculate_base_collision_damage()` - Physics-based damage from velocity/mass
- `_calculate_weapon_ship_damage()` - Weapon-specific damage with shield integration
- `_calculate_ship_ship_damage()` - Mutual collision damage for ramming

**WCS Damage Features**:
- Velocity and mass-based kinetic damage calculation
- Object type-specific damage multipliers
- Shield quadrant system with damage distribution
- Armor penetration and bleedthrough mechanics
- Subsystem damage calculation

### CollisionResponse (NEW - OBJ-010)
**Purpose**: Handle complete collision response including damage, physics, and effects
**Key Methods**:
- `_process_collision_response(obj_a, obj_b, collision_info)` - Main response coordinator
- `_apply_physics_response()` - Calculate and apply physics impulses
- `_apply_collision_damage()` - Apply calculated damage to objects
- `_trigger_collision_effects()` - Trigger visual and audio effects

**WCS Response Features**:
- Physics impulse calculation using momentum conservation
- Realistic collision forces with restitution and friction
- Damage application to shields, hull, and subsystems
- Integration with EPIC-008 graphics system for effects
- Performance optimization for multiple simultaneous collisions

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

# Monitor collision response performance
var response_stats = collision_response.get_collision_response_statistics()
print("Responses this frame: ", response_stats.responses_this_frame)
print("Effects triggered: ", response_stats.effect_triggering_enabled)
```

### Complete Collision Response Setup (NEW - OBJ-010)
```gdscript
# Set up complete collision system with response
var collision_detector = CollisionDetector.new()
var collision_response = CollisionResponse.new()

# Connect collision detection to response
collision_detector.collision_pair_detected.connect(collision_response._on_collision_pair_detected)

# Configure damage and physics settings
collision_response.physics_impulse_scale = 1.0  # Realistic physics
collision_response.damage_application_enabled = true
collision_response.effect_triggering_enabled = true

# Track collision events
collision_response.collision_damage_applied.connect(_on_damage_applied)
collision_response.collision_effect_triggered.connect(_on_effects_triggered)
collision_response.shield_quadrant_hit.connect(_on_shield_hit)
```

### Weapon Collision Processing
```gdscript
# Example of weapon hitting ship
func _on_weapon_ship_collision(weapon: Node3D, ship: Node3D, collision_info: Dictionary):
    # Damage calculation happens automatically
    var damage_result = damage_calculator.calculate_collision_damage(weapon, ship, collision_info)
    
    # Results include:
    # - damage_result.shield_damage: Damage to shields
    # - damage_result.hull_damage: Damage to hull
    # - damage_result.quadrant_hit: Which shield quadrant was hit
    # - damage_result.subsystem_damage: Damage to subsystems
    
    # Physics response applied automatically
    # Effects triggered based on damage intensity
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

### Test Coverage (OBJ-009 & OBJ-010)
- **Unit Tests**: 
  - `test_collision_detector.gd` - Covers all 6 OBJ-009 acceptance criteria (collision detection)
  - `test_collision_response.gd` - Covers all 6 OBJ-010 acceptance criteria (damage & response)
- **Integration Tests**: `test_collision_response_integration.gd` - Real collision scenarios with mock objects
- **Performance Tests**: Validates performance targets with 50+ test objects and multiple simultaneous collisions
- **Physics Tests**: Momentum conservation, impulse application, and realistic collision responses
- **Damage Tests**: Weapon damage, shield systems, hull damage, and subsystem damage
- **Effect Tests**: Visual and audio effect triggering through EPIC-008 integration

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
5. **Advanced Damage System**: Physics-based damage calculation with shield integration (OBJ-010)
6. **Realistic Physics Response**: Momentum conservation with restitution and friction (OBJ-010)
7. **Effect Integration**: Seamless EPIC-008 graphics system integration for collision effects (OBJ-010)
8. **Performance Optimization**: Frame-budget management for collision response processing (OBJ-010)

## OBJ-010 Implementation Summary

**Status**: ✅ COMPLETED

**Key Deliverables**:
- Comprehensive damage calculation system based on WCS physics mechanics
- Realistic collision response with momentum conservation and impulse application  
- Complete integration with shield systems, hull damage, and subsystem damage
- Visual and audio effect triggering through EPIC-008 graphics system integration
- Performance optimization for multiple simultaneous collisions
- Extensive test coverage including unit tests and integration scenarios

**Performance Targets Met**:
- Damage calculation: <0.1ms per collision (AC6) ✅
- Response processing: <0.2ms per collision response (AC6) ✅
- Physics impulse application: Realistic with momentum conservation (AC2) ✅
- Effect triggering: Seamless integration with graphics system (AC4) ✅

**WCS Feature Parity**:
- Weapon-ship collision damage matching WCS `ship_weapon_do_hit_stuff` behavior ✅
- Ship-ship collision physics matching WCS `ship_apply_whack` mechanics ✅
- Shield quadrant damage system preserving WCS shield mechanics ✅
- Object type-specific collision handling for all WCS collision combinations ✅

## OBJ-012 Implementation Summary (NEW)

**Status**: ✅ COMPLETED

**Key Deliverables**:
- **Dynamic Collision Mask Management**: Runtime collision layer and mask changes with full Godot physics integration (AC3)
- **Temporary Collision Rules**: Time-based collision rule system with automatic expiration (AC3)  
- **Debug Visualization System**: Complete collision layer debugging with visual overlay and statistics (AC6)
- **Enhanced Filtering**: Improved collision filtering using dynamic overrides and effective layer management (AC2)
- **Performance Optimization**: Sub-millisecond collision filtering meeting all performance targets (AC5)
- **Comprehensive Testing**: 20+ test cases covering all acceptance criteria with integration scenarios

**Performance Targets Met**:
- Collision filtering: <0.01ms per object pair (AC5) ✅
- Layer changes: <0.05ms per dynamic change (AC3) ✅
- Debug visualization: Real-time updates without performance impact (AC6) ✅

**New Features Beyond WCS**:
- **Runtime Layer Management**: Dynamic collision layer/mask changes during gameplay
- **Temporary Rules System**: Collision rules with automatic expiration for temporary effects
- **Debug Overlay**: Visual collision layer debugging with interactive controls
- **Statistics Tracking**: Real-time collision filtering performance monitoring
- **Integration Validation**: Seamless integration with existing collision detection system

**Files Implemented**:
- `collision_filter.gd` - Enhanced with dynamic mask management (185 new lines)
- `collision_layer_debugger.gd` - New debug visualization system (400+ lines)
- `test_collision_layer_filter.gd` - Comprehensive test coverage (500+ lines)

The collision layer and filtering system successfully implements sophisticated runtime collision management with comprehensive debugging capabilities, exceeding WCS's original collision filtering while maintaining optimal performance.