# Ship Subsystems Package - SHIP-002

## Purpose
The Ship Subsystems package provides comprehensive subsystem management, damage modeling, and performance effects for the WCS-Godot conversion. This package implements SHIP-002 to deliver authentic WCS subsystem behavior with proximity-based damage, performance degradation, turret AI, and SEXP integration.

## Implementation Status
**✅ SHIP-002 COMPLETED**: Subsystem Management and Configuration implemented with full WCS-authentic behavior.

## Package Overview

### Core Classes

#### SubsystemDefinition (Resource)
**Purpose**: Definition resource for subsystem configuration and properties.
**Location**: `addons/wcs_asset_core/resources/ship/subsystem_definition.gd`

**Key Features**:
- Complete subsystem properties (health, radius, position, behavior flags)
- Turret-specific configuration (FOV, range, turn rate, weapons)
- Performance degradation curves with WCS-authentic thresholds
- Dependency relationships and repair priorities
- Validation and factory methods for default configurations

**Usage**:
```gdscript
# Create subsystem definitions
var engine_def = SubsystemDefinition.create_default_engine()
var turret_def = SubsystemDefinition.create_default_turret("Main Turret")

# Configure custom properties
engine_def.max_hits = 75.0
engine_def.is_critical = true
turret_def.turret_fov = 120.0
turret_def.turret_range = 1200.0

# Validate configuration
if engine_def.is_valid():
    print("Engine definition valid")
else:
    for error in engine_def.get_validation_errors():
        print("Error: %s" % error)
```

#### Subsystem (Node)
**Purpose**: Active subsystem instance managing runtime state and behavior.
**Location**: `scripts/ships/subsystems/subsystem.gd`

**Key Features**:
- WCS-authentic health tracking and performance degradation (AC2, AC3)
- Proximity-based damage allocation with falloff calculations (AC4)
- Turret AI with multi-criteria target selection and tracking (AC5)
- Repair mechanisms with priority-based recovery (AC6)
- Signal-based communication for ship integration (AC7)

**Usage**:
```gdscript
# Subsystem is typically created by SubsystemManager
var subsystem = Subsystem.new()
subsystem.initialize_subsystem(engine_definition, parent_ship, manager)

# Apply damage with proximity calculation
var damage_applied = subsystem.apply_damage(50.0, impact_position)

# Start repair process
if subsystem.start_repair():
    print("Repair started for %s" % subsystem.name)

# Check subsystem status
var status = subsystem.get_status_info()
print("Health: %.1f%%" % status.health_percent)
print("Performance: %.2f" % status.performance_modifier)
```

#### SubsystemManager (Node)
**Purpose**: Coordinator for all ship subsystems with lifecycle and performance management.
**Location**: `scripts/ships/subsystems/subsystem_manager.gd`

**Key Features**:
- Subsystem creation from ship class definitions (AC1)
- Proximity-based damage allocation across subsystems (AC4)
- Performance tracking and ship integration (AC2)
- Repair queue management with priority ordering (AC6)
- SEXP integration for mission scripting queries (AC7)

**Usage**:
```gdscript
# SubsystemManager is created by BaseShip
var manager = ship.subsystem_manager

# Query subsystem status (SEXP integration)
var engine_health = manager.get_subsystem_health("Engine")
var is_functional = manager.is_subsystem_functional("Weapons")
var turret_count = manager.get_subsystem_count_by_type(SubsystemTypes.Type.TURRET)

# Apply area damage with proximity allocation
var total_damage_applied = manager.allocate_damage_to_subsystems(100.0, impact_position)

# Repair management
manager.queue_subsystem_repair(damaged_subsystem)
var repair_status = manager.get_subsystem_status()
```

## WCS Reference Implementation

### Subsystem Types and Behavior
Based on WCS `subsysdamage.h` and `ship.h` subsystem definitions:

**Engine Subsystems** (Type.ENGINE):
- Critical for ship movement and afterburner functionality
- Performance directly affects `current_max_speed` and maneuverability
- Repair priority: 10 (highest)
- Linear performance degradation: 100% health = 100% performance

**Weapon Subsystems** (Type.WEAPONS):
- Affects weapon firing rate, accuracy, and energy regeneration
- Performance never drops below 10% (even when heavily damaged)
- Repair priority: 8 (high)
- Multiple weapon subsystems possible on larger ships

**Turret Subsystems** (Type.TURRET):
- Independent AI targeting with multi-criteria selection
- Field of view, range, and turn rate constraints
- Priority targeting: Bombers > Fighters > Capitals
- Accuracy builds over time when locked on target

**Sensor Subsystems** (Type.RADAR, Type.SENSORS):
- Affects shield efficiency and targeting accuracy
- Performance never drops below 20% minimum
- Critical for turret targeting effectiveness
- Repair priority: 7 (high)

### Performance Degradation Curves (AC3)
Authentic WCS performance characteristics:

```gdscript
# Engine performance (linear degradation)
func get_engine_performance(health_percent: float) -> float:
    return max(0.0, health_percent / 100.0)

# Weapon performance (minimum 10%)
func get_weapon_performance(health_percent: float) -> float:
    return max(0.1, health_percent / 100.0)

# Sensor performance (minimum 20%)
func get_sensor_performance(health_percent: float) -> float:
    return max(0.2, health_percent / 100.0)
```

### Proximity Damage Allocation (AC4)
WCS-style damage distribution based on impact location:

```gdscript
# Proximity damage calculation
func calculate_proximity_modifier(subsystem_pos: Vector3, impact_pos: Vector3, radius: float) -> float:
    var distance = subsystem_pos.distance_to(impact_pos)
    
    if distance <= radius:
        return 1.0  # Full damage within subsystem radius
    
    var max_distance = radius * 3.0  # Damage drops to zero at 3x radius
    if distance >= max_distance:
        return 0.0
    
    # Linear falloff between radius and max_distance
    return (max_distance - distance) / (max_distance - radius)
```

### Turret AI Implementation (AC5)
Multi-criteria target selection matching WCS behavior:

**Target Priority Factors**:
1. **Distance**: Closer targets preferred (40 points max)
2. **Ship Type**: Bombers (35) > Fighters (30) > Transports (20) > Capitals (15)
3. **Health**: Damaged targets preferred (20 points max)
4. **Facing**: Targets in current facing direction (10 points max)

**FOV and Range Constraints**:
- Turrets cannot engage targets outside field of view
- Range limits strictly enforced (typically 800-1200 units)
- Turn rate limits realistic rotation speed (typically 90 degrees/second)

### Repair System (AC6)
Priority-based repair with WCS-style recovery rates:

**Repair Priorities** (higher = repaired first):
- Engine: 10 (critical for movement)
- Weapons: 8 (critical for combat)
- Radar: 7 (critical for targeting)
- Turrets: 6 (defensive systems)
- Other: 3-5 (non-critical systems)

**Repair Rates** (hits per second):
- Engines: 3.0 hits/sec (1.5x base rate)
- Weapons: 2.4 hits/sec (1.2x base rate)
- Electronics: 1.6 hits/sec (0.8x base rate)
- Communication: 1.2 hits/sec (0.6x base rate)

## BaseShip Integration

### Subsystem Manager Integration
BaseShip creates and manages SubsystemManager automatically:

```gdscript
# BaseShip automatically creates subsystem manager
func _initialize_subsystem_manager() -> void:
    subsystem_manager = SubsystemManager.new()
    add_child(subsystem_manager)
    subsystem_manager.initialize_manager(self)

# Ship initialization creates subsystems from ship class
func initialize_ship(ship_class: ShipClass, ship_name: String) -> bool:
    # ... other initialization ...
    if subsystem_manager:
        subsystem_manager.create_subsystems_from_ship_class(ship_class)
```

### Performance Effects Integration
Subsystem performance directly affects ship capabilities:

```gdscript
# Engine damage reduces max speed
ship.current_max_speed = ship.max_velocity * engine_performance * engine_power_rate

# Weapon damage affects firing and energy regeneration
weapon_energy_regen = weapon_recharge_rate * weapon_performance * delta * 30.0

# Sensor damage affects shield efficiency
shield_regen = shield_recharge_rate * shield_performance * delta * 20.0
```

### API Methods for External Systems
BaseShip provides comprehensive subsystem API:

```gdscript
# Damage specific subsystem
var damage_applied = ship.apply_subsystem_damage("Engine", 50.0, impact_position)

# Query subsystem status
var engine_health = ship.get_subsystem_health("Engine")
var is_functional = ship.is_subsystem_functional("Weapons")

# Repair subsystems
var repair_queued = ship.repair_subsystem("Radar")

# Get performance by category
var engine_perf = ship.get_subsystem_performance("engine")
```

## SEXP Integration (AC7)

### Mission Scripting Queries
Complete SEXP integration for mission scripting:

```gdscript
# Check subsystem functionality
(is-subsystem-functional "Player" "Engine")  # Returns true/false

# Get subsystem health percentage
(subsystem-health "Alpha 1" "Weapons")  # Returns 0-100

# Count functional subsystems
(functional-subsystem-count "Capital Ship" "Turret")  # Returns integer

# Check for critical failures
(has-critical-subsystem-failure "Player")  # Returns true/false
```

### Query Caching for Performance
SEXP queries are cached for 1 second to optimize mission script performance:

```gdscript
# Cached query system
var cache_key = "health_" + subsystem_name
if sexp_query_cache.has(cache_key) and current_time < sexp_cache_expiry:
    return sexp_query_cache[cache_key]

# Calculate and cache result
var health = calculate_subsystem_health(subsystem_name)
sexp_query_cache[cache_key] = health
sexp_cache_expiry = current_time + 1.0
```

## Testing Coverage

### Comprehensive Test Suite
**Location**: `tests/test_ship_002_subsystem_management.gd`

**Test Coverage**:
- **AC1**: All subsystem types created with WCS-authentic properties
- **AC2**: Performance effects correctly applied to ship systems
- **AC3**: Performance degradation follows WCS curves and minimums
- **AC4**: Proximity damage allocation with distance falloff
- **AC5**: Turret AI targeting with FOV and priority constraints
- **AC6**: Repair mechanisms with priority ordering and rates
- **AC7**: SEXP integration with query caching and validation

**Test Categories**:
- Unit tests for individual subsystem behavior
- Integration tests for ship-subsystem coordination
- Performance tests for damage allocation efficiency
- Error handling tests for edge cases and invalid input

## Performance Considerations

### Efficient Damage Processing
- Proximity calculations use squared distances where possible
- Damage allocation sorts subsystems only when needed
- Frame processing limited to functional subsystems only

### Memory Management
- Subsystem instances reuse definitions via Resource references
- Signal connections managed automatically by Godot
- Query caching prevents redundant SEXP calculations

### Turret AI Optimization
- Target updates limited to 0.5-second intervals
- Physics queries use collision layers for filtering
- FOV calculations use dot products for efficiency

## Debugging and Diagnostics

### Debug Information
```gdscript
# Ship debug info includes subsystem status
print(ship.debug_info())
# Output: [Ship:TestShip Hull:100.0/100.0 Shield:100.0/100.0 ETS:(0.33,0.33,0.33)] [SubsystemMgr: 3/3 functional, Perf(E:1.00 W:1.00 S:1.00)]

# Detailed subsystem status
var status = ship.subsystem_manager.get_subsystem_status()
print("Total subsystems: %d" % status.total_subsystems)
print("Functional: %d" % status.functional_subsystems)
print("Repairing: %d" % status.repairing_subsystems)

# Individual subsystem info
for subsystem_name in status.subsystems:
    var sub_info = status.subsystems[subsystem_name]
    print("%s: %.1f%% health, %.2f performance" % [sub_info.name, sub_info.health_percent, sub_info.performance_modifier])
```

### Signal Monitoring
```gdscript
# Monitor subsystem events
ship.subsystem_damaged.connect(func(name: String, damage: float):
    print("Subsystem %s damaged: %.1f%%" % [name, damage])
)

subsystem_manager.critical_subsystem_destroyed.connect(func(name: String):
    print("CRITICAL FAILURE: %s destroyed!" % name)
)

subsystem_manager.turret_target_acquired.connect(func(turret: String, target: Node3D):
    print("Turret %s targeting %s" % [turret, target.name])
)
```

## Architecture Notes

### Design Principles
1. **WCS Authenticity**: All subsystem behavior matches original WCS mechanics exactly
2. **Modular Design**: Each subsystem is independent with clear interfaces
3. **Performance Focus**: Efficient processing for large fleet battles
4. **Signal Integration**: Event-driven communication with ship systems
5. **SEXP Compatibility**: Mission scripting access matches original capabilities

### Integration Points
- **BaseShip**: Automatic subsystem creation and performance integration
- **Damage System**: Proximity-based allocation and armor interaction (future)
- **AI Systems**: Turret AI and ship behavior modification (future)
- **Mission System**: SEXP queries for mission logic and objectives
- **HUD Systems**: Subsystem status display and repair progress (future)

### Future Extensions
The subsystem architecture supports future enhancements:
- Advanced turret weapon integration with firing solutions
- Complex dependency chains with cascading failures
- Dynamic subsystem configuration based on ship modifications
- Enhanced repair systems with crew efficiency and resource costs
- Advanced damage modeling with component-specific effects

This comprehensive implementation successfully delivers SHIP-002 with full WCS compatibility while leveraging Godot's strengths for optimal performance and maintainability.