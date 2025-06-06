# Spatial Query System Package Documentation

## Package Purpose

The spatial query system provides high-performance spatial partitioning and object proximity detection for the WCS-Godot conversion project. This package replaces WCS's linear O(n) object iteration with modern spatial hash algorithms achieving O(1) average case performance for spatial queries.

## Original C++ Analysis

### WCS Spatial Limitations
**Source**: `source/code/object/object.cpp` and `objcollide.cpp`
- **Linear Iteration**: All spatial queries use `GET_FIRST()` and `GET_NEXT()` macros to iterate through entire object lists
- **O(n²) Collision Detection**: Every object checked against every other object for collisions
- **No Spatial Optimization**: Objects stored in simple linked lists without spatial organization
- **Brute Force Proximity**: Functions like `get_nearest_objnum()` search all objects linearly

### Performance Analysis
- **Query Complexity**: O(n) for proximity searches, O(n²) for collision detection
- **Memory Access**: Poor cache locality due to linked list traversal
- **Scalability Issues**: Performance degrades rapidly with object count >100
- **No Caching**: Repeated queries recalculate from scratch every time

## Key Classes

### SpatialHash
**Purpose**: Core spatial partitioning system using grid-based hash for fast object queries.

**Responsibilities**:
- Grid-based spatial partitioning with configurable cell size
- Object tracking across multiple grid cells for large objects
- Efficient proximity queries with radius and type filtering
- Dynamic grid optimization based on object density
- Query result caching with intelligent invalidation

**Usage**:
```gdscript
var spatial_hash: SpatialHash = SpatialHash.new(1000.0)  # 1000-unit grid cells

# Add objects to spatial system
spatial_hash.add_object(ship_node, ship_bounds)
spatial_hash.add_object(weapon_node)

# Query objects within radius
var nearby_objects: Array[Node3D] = spatial_hash.get_objects_in_radius(
    Vector3(500, 0, 500), 
    300.0, 
    ObjectTypes.Type.SHIP
)

# Update object position when it moves
spatial_hash.update_object_position(moving_ship)

# Get collision candidates for an object
var collision_targets: Array[Node3D] = spatial_hash.get_collision_candidates(weapon, 50.0)
```

### SpatialQuery
**Purpose**: High-level spatial query interface providing advanced search capabilities.

**Responsibilities**:
- Complex spatial queries (cone search, line-of-sight, formation finding)
- Performance-optimized query patterns for common gameplay scenarios
- Query options and filtering systems
- Performance monitoring and optimization suggestions

**Usage**:
```gdscript
var spatial_query: SpatialQuery = SpatialQuery.new(spatial_hash)

# Advanced radius query with options
var options: Dictionary = {
    "type_filter": ObjectTypes.Type.WEAPON,
    "max_results": 10,
    "exclude_objects": [player_ship]
}
var weapons: Array[Node3D] = spatial_query.get_objects_in_radius(center, 500.0, options)

# Cone search for weapon targeting
var targets: Array[Node3D] = spatial_query.get_objects_in_cone(
    weapon_position, 
    weapon_direction, 
    1000.0,  # max distance
    30.0     # cone angle degrees
)

# Find objects by threat level
var threats: Array[Node3D] = spatial_query.get_objects_by_threat_level(
    player_position, 
    2000.0,  # search radius
    0.5      # minimum threat level
)

# Line of sight queries
var visible_objects: Array[Node3D] = spatial_query.get_line_of_sight_objects(
    start_pos, 
    end_pos, 
    ObjectTypes.Type.SHIP
)
```

### QueryCache
**Purpose**: Intelligent caching system for expensive spatial query results.

**Responsibilities**:
- LRU cache with memory limits and timeout management
- Spatial and type-based cache invalidation
- Performance tracking and cache hit ratio monitoring
- Automatic cleanup and optimization

**Usage**:
```gdscript
var query_cache: QueryCache = QueryCache.new()

# Cache configuration
query_cache.max_memory_mb = 50.0
query_cache.default_timeout_ms = 100.0

# Cache query results
query_cache.cache_query_result(
    "radius_search_500_1000", 
    query_results, 
    100.0,  # timeout
    search_area,  # AABB region
    [ObjectTypes.Type.SHIP]  # types
)

# Retrieve cached results
var cached_results: Array[Node3D] = query_cache.get_cached_result("radius_search_500_1000")

# Invalidate cache when objects change
query_cache.invalidate_by_region(changed_area, "object_spawned")
query_cache.invalidate_by_object_type(ObjectTypes.Type.WEAPON, "weapon_destroyed")
```

### CollisionOptimizer
**Purpose**: Spatial partitioning optimization for collision detection systems.

**Responsibilities**:
- Collision matrix management for type-based filtering
- Temporal coherence optimization with check intervals
- Performance monitoring and frame budget management
- Integration with spatial hash for efficient broad-phase collision

**Usage**:
```gdscript
var collision_optimizer: CollisionOptimizer = CollisionOptimizer.new(spatial_hash)

# Get collision candidates for an object
var candidates: Array[Node3D] = collision_optimizer.get_collision_candidates(projectile, 25.0)

# Update collision pairs with performance limits
collision_optimizer.max_collision_checks_per_frame = 200
var pairs_processed: int = collision_optimizer.update_collision_pairs(active_objects)

# Get optimization settings for object type
var optimization: Dictionary = collision_optimizer.optimize_collision_detection_for_object(ship)
print("Recommended check interval: %dms" % optimization["check_interval_ms"])
```

## Architecture Notes

### Grid-Based Spatial Hash
- **Grid Size**: Default 1000 units, automatically optimized based on object density
- **Multi-Cell Objects**: Large objects occupy multiple grid cells for accurate queries
- **Dynamic Resizing**: Grid automatically adapts size when object distribution changes
- **Memory Efficiency**: Weak references and automatic cleanup prevent memory leaks

### Performance Optimization
- **Query Caching**: Frequently requested queries cached for 100ms by default
- **Temporal Coherence**: Collision pairs use timestamps to skip unnecessary rechecks
- **Frame Budget**: Collision system respects frame time limits (200 checks/frame max)
- **Distance Culling**: Objects beyond interaction range excluded from expensive calculations

### WCS Integration
- **Object Type Mapping**: Uses `wcs_asset_core` object type constants for compatibility
- **Signal Integration**: Connects to object movement and lifecycle events
- **Performance Profiles**: Integrates with `UpdateFrequencies` for LOD systems
- **Legacy Compatibility**: Maintains WCS collision matrix rules and behaviors

## C++ to Godot Mapping

### Query Performance
- **WCS Linear Search** → **Godot Spatial Hash O(1) average case**
- **WCS Collision O(n²)** → **Godot Optimized Broad Phase + Narrow Phase**
- **WCS No Caching** → **Godot Intelligent Query Caching**
- **WCS Fixed Performance** → **Godot Adaptive Performance Management**

### Memory Management
- **WCS Manual Lists** → **Godot Automatic Weak Reference Cleanup**
- **WCS Fixed Arrays** → **Godot Dynamic Dictionary-Based Grid**
- **WCS No Optimization** → **Godot Automatic Memory Limits and Cleanup**

### Collision Detection
- **WCS obj_pair Lists** → **Godot Spatial Hash Collision Candidates**
- **WCS Linear Pair Generation** → **Godot Spatial Query-Based Pair Generation**
- **WCS Fixed Check Intervals** → **Godot Adaptive Temporal Coherence**

## Integration Points

### ObjectManager Integration
```gdscript
# ObjectManager enhancement for spatial queries
func find_objects_near_position(position: Vector3, radius: float, type_filter: ObjectTypes.Type = ObjectTypes.Type.NONE) -> Array[Node3D]:
    return spatial_query.get_objects_in_radius(position, radius, {"type_filter": type_filter})

func get_collision_candidates_for_object(object: Node3D) -> Array[Node3D]:
    return collision_optimizer.get_collision_candidates(object)
```

### CollisionDetector Integration
```gdscript
# Enhanced collision detection with spatial optimization
func update_collision_pairs() -> void:
    var active_objects: Array[Node3D] = object_manager.get_active_objects()
    collision_optimizer.update_collision_pairs(active_objects)

func get_broad_phase_candidates(object: Node3D) -> Array[Node3D]:
    return spatial_hash.get_collision_candidates(object, object.get_collision_radius())
```

### PhysicsManager Integration
```gdscript
# Physics system enhanced with spatial queries
func apply_area_effect(center: Vector3, radius: float, force: Vector3) -> void:
    var affected_objects: Array[Node3D] = spatial_query.get_objects_in_radius(center, radius)
    for obj: Node3D in affected_objects:
        if obj.has_method("apply_force"):
            obj.apply_force(force)
```

## Performance Considerations

### Scalability Targets
- **Objects**: Handles 1000+ objects efficiently
- **Query Time**: <0.5ms average for radius queries
- **Update Time**: <0.1ms for object position updates
- **Memory Usage**: <50MB cache with automatic cleanup
- **Collision Performance**: 200 collision checks/frame budget

### Optimization Techniques
- **Spatial Locality**: Grid cells provide excellent cache locality
- **Query Batching**: Multiple queries processed together for efficiency
- **Lazy Evaluation**: Grid cells created only when objects occupy them
- **Smart Invalidation**: Cache invalidation based on spatial regions and object types

### Memory Management
- **Weak References**: Objects automatically removed when freed
- **LRU Cache**: Least recently used queries evicted first
- **Grid Cleanup**: Empty grid cells automatically removed
- **Memory Limits**: Configurable memory usage limits with automatic cleanup

## Testing Notes

### Unit Testing
Comprehensive test coverage using mock objects:
- **Grid Partitioning**: Objects correctly assigned to grid cells
- **Query Accuracy**: Radius and proximity queries return correct results
- **Performance**: Query times meet target thresholds
- **Cache Behavior**: Cache hit/miss ratios and invalidation work correctly
- **Memory Management**: No leaks or excessive memory usage

### Integration Testing
- **ObjectManager Integration**: Spatial queries work with object lifecycle
- **Collision System Integration**: Broad-phase optimization reduces collision checks
- **Physics Integration**: Area effects and proximity queries work correctly
- **Performance Under Load**: System maintains performance with high object counts

### Performance Testing
```gdscript
# Test with varying object counts
for object_count in [100, 500, 1000, 2000]:
    measure_query_performance(object_count)
    measure_collision_optimization(object_count)
    measure_memory_usage(object_count)
```

## Implementation Deviations

### Intentional Changes from WCS

1. **Spatial Hash Instead of Linear Lists**: Replaces O(n) linear searches with O(1) hash lookups for dramatic performance improvement.

2. **Query Caching System**: Adds intelligent caching not present in original WCS to avoid repeated expensive calculations.

3. **Dynamic Grid Optimization**: Automatically adapts grid size based on object distribution, unlike WCS's fixed data structures.

4. **Temporal Coherence**: Adds collision check timing optimization not present in original WCS collision system.

5. **Memory Management**: Uses Godot's automatic memory management instead of manual C++ memory handling.

### Justifications

- **Performance**: Modern spatial algorithms provide orders of magnitude better performance
- **Scalability**: System scales to much larger object counts than original WCS
- **Memory Safety**: Automatic cleanup prevents memory leaks common in C++ code
- **Maintainability**: Higher-level Godot APIs easier to understand and maintain
- **Extensibility**: Modular design makes adding new query types straightforward

## Future Extensibility

### Easy Extensions
```gdscript
# Add new query types
func get_objects_in_cylinder(center: Vector3, radius: float, height: float) -> Array[Node3D]:
    # Use spatial hash broad phase + cylinder intersection narrow phase
    pass

# Add new cache strategies
class PerformanceBasedCache extends QueryCache:
    func cache_query_result(key: String, result: Array[Node3D], timeout_ms: float = -1.0):
        # Adaptive timeout based on query performance
        pass

# Add new collision optimizations
func optimize_for_specific_scenario(scenario: String) -> void:
    match scenario:
        "dogfight": _configure_for_high_density_combat()
        "capital_battle": _configure_for_large_ships()
        "exploration": _configure_for_low_density()
```

This spatial query system provides the foundation for all spatial operations in the WCS-Godot conversion, dramatically improving performance while maintaining compatibility with WCS gameplay patterns.