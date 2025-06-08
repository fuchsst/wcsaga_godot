# Ship Systems Package - EPIC-011

## Purpose
The Ship Systems package provides comprehensive ship behavior, combat mechanics, and control systems for the WCS-Godot conversion. This package implements all EPIC-011 user stories to deliver authentic WCS ship gameplay.

## Implementation Status
**✅ SHIP-001 COMPLETED**: Ship Controller and Base Ship Systems implemented with full WCS-authentic behavior.

## Package Overview

### SHIP-001: Ship Controller and Base Ship Systems
**Status**: ✅ COMPLETED  
**Location**: `scripts/ships/core/base_ship.gd`

**Key Features**:
- BaseSpaceObject extension with WCS ship properties (hull, shields, mass, velocity)
- Complete ETS (Energy Transfer System) implementation with 13-level WCS allocation
- Authentic WCS physics integration (afterburner, velocity limits, damping)
- Ship lifecycle management (creation, configuration, destruction)
- Frame-by-frame processing with pre/post phases
- Subsystem state monitoring and performance effects

**ETS Implementation**: Full WCS compatibility with F5-F8 energy transfer controls matching original behavior.

**Physics Integration**: Maintains WCS movement characteristics while leveraging Godot RigidBody3D for optimal performance.

## Key Classes

### BaseShip
**Purpose**: Foundation class for all ships in WCS-Godot, extending BaseSpaceObject with ship-specific behavior.

**Location**: `scripts/ships/core/base_ship.gd`

**Key Features**:
- WCS-authentic ship properties and physics (SHIP-001 AC1, AC5)
- Complete ETS power management system (SHIP-001 AC6)
- Ship initialization from ShipClass resources (SHIP-001 AC2)
- Lifecycle management and destruction sequences (SHIP-001 AC3)
- Core ship state management with flags and team alignment (SHIP-001 AC4)
- Subsystem coordination and performance effects (SHIP-001 AC7)

**Usage**:
```gdscript
# Create and initialize ship
var ship = BaseShip.new()
add_child(ship)

var ship_class = ShipClass.create_default_fighter()
ship.initialize_ship(ship_class, "Player Fighter")

# ETS management (WCS F5-F8 controls)
ship.transfer_energy_to_shields()    # F5
ship.transfer_energy_to_weapons()    # F6
ship.transfer_energy_to_engines()    # F7
ship.balance_energy_systems()        # F8

# Ship control
ship.apply_ship_thrust(1.0, 0.0, 0.0, true)  # Forward thrust with afterburner
ship.set_afterburner_active(true)

# Damage system
ship.apply_hull_damage(25.0)
ship.apply_shield_damage(50.0)
```

### ShipClass (Resource)
**Purpose**: Ship class definition resource containing all WCS ship properties and configuration.

**Location**: `addons/wcs_asset_core/resources/ship/ship_class.gd`

**Key Features**:
- Complete ship specifications (physics, structure, energy systems)
- Combat properties (weapon banks, subsystem configuration)
- Model and visual asset references
- Factory methods for default ship types (fighter, bomber, capital)

**Usage**:
```gdscript
# Create ship classes
var fighter = ShipClass.create_default_fighter()
var bomber = ShipClass.create_default_bomber()
var capital = ShipClass.create_default_capital()

# Custom ship class
var custom_ship = ShipClass.new()
custom_ship.class_name = "Custom Fighter"
custom_ship.max_velocity = 85.0
custom_ship.max_hull_strength = 120.0
```

## WCS Reference Implementation

### ETS (Energy Transfer System)
The implementation precisely matches WCS ETS behavior:

**Energy Levels Array**: Exactly matches WCS `hudets.cpp` energy levels:
```gdscript
const ENERGY_LEVELS: Array[float] = [
    0.0, 0.0833, 0.167, 0.25, 0.333, 0.417, 0.5,
    0.583, 0.667, 0.75, 0.833, 0.9167, 1.0
]
```

**Default Allocation**: Ships start with 1/3 allocation to each system (index 4 = 0.333).

**Energy Transfer**: F5-F8 controls transfer energy in discrete steps matching WCS behavior:
- F5: Transfer weapons → shields (decrease weapon index, increase shield index)
- F6: Transfer shields → weapons (decrease shield index, increase weapon index)
- F7: Transfer weapons → engines (decrease weapon index, increase engine index)
- F8: Reset all to balanced (index 4 each)

### Physics Characteristics
Ships maintain authentic WCS movement feel:

**Velocity Limiting**: Ships cannot exceed `max_velocity` or `max_afterburner_velocity`
**Space Physics**: Zero gravity with custom damping for authentic space flight
**Performance Effects**: Engine damage directly affects `current_max_speed`
**Afterburner System**: Fuel consumption with performance requirements

### Ship Properties
All ships have WCS-authentic properties:

**Structural**: `max_hull_strength`, `max_shield_strength` with current values
**Physics**: `mass`, `acceleration`, `max_velocity`, `max_afterburner_velocity`
**Energy**: `max_weapon_energy`, `afterburner_fuel_capacity` with regeneration
**State**: Team alignment, ship flags, performance modifiers

## C++ to Godot Mapping

### Ship Structure
- **C++ ship struct** → **BaseShip class with ShipClass resource**
- **ship_info index** → **ShipClass resource references**
- **ship flags/flags2** → **ship_flags/ship_flags2 properties**
- **ship weapon struct** → **Future weapon subsystem integration**

### ETS System
- **C++ Energy_levels array** → **ENERGY_LEVELS constant array**
- **shield/weapon/engine_recharge_index** → **Identical index-based system**
- **ETS processing** → **_process_ets_system() method**
- **Energy transfer functions** → **transfer_energy_to_*() methods**

### Physics Integration
- **C++ ship physics** → **Godot RigidBody3D with custom constraints**
- **afterburner mechanics** → **fuel consumption with performance checks**
- **velocity limiting** → **_apply_velocity_constraints() method**
- **ship movement** → **apply_ship_thrust() with force application**

### Subsystem Management
- **C++ subsys_list** → **subsystems Dictionary and subsystem_list Array**
- **subsystem performance** → **engine/weapon/shield_performance tracking**
- **damage effects** → **_update_performance_effects() method**

## Integration Points

### BaseSpaceObject Integration
```gdscript
# Ships extend BaseSpaceObject for physics and object management
var ship = BaseShip.new()  # Automatically inherits space object behavior
ship.physics_body  # Access to RigidBody3D from BaseSpaceObject
ship.collision_detected.connect(_on_ship_collision)  # Space object signals
```

### Asset Core Integration  
```gdscript
# Ships use asset core constants and resources
var ship_type = ShipTypes.Type.FIGHTER
var object_type = ObjectTypes.Type.SHIP
var collision_layer = CollisionLayers.Layer.SHIPS

# Ship class resources from asset core
var ship_class: ShipClass = load("res://addons/wcs_asset_core/resources/ship/fighter_class.tres")
```

### Physics Manager Integration
```gdscript
# Ships integrate with PhysicsManager for enhanced physics
ship.apply_force(thrust_vector)  # Uses PhysicsManager if available
ship.set_thruster_input(1.0, 0.0, 0.0, true)  # Enhanced thruster physics
```

## Testing Coverage

### SHIP-001 Test Suite
**Location**: `tests/test_ship_001_base_ship_systems.gd`

**Coverage**: All 7 acceptance criteria with comprehensive test scenarios:
- **AC1**: BaseSpaceObject extension and WCS properties
- **AC2**: Ship initialization from ShipClass resources
- **AC3**: Lifecycle management and destruction sequences
- **AC4**: State management and frame processing
- **AC5**: Physics integration and movement characteristics
- **AC6**: Complete ETS implementation and energy management
- **AC7**: Subsystem state processing and performance effects

**Test Types**:
- Unit tests for all public methods and properties
- Integration tests for physics and asset core coordination
- Performance tests for frame processing efficiency
- Error handling tests for edge cases and invalid input

## Performance Considerations

### Frame Processing
- Efficient frame-by-frame updates with minimal allocations
- Pre/post processing phases for organized update flow
- Performance modifier calculations cached and updated only when needed

### ETS Processing
- Direct array access for energy level lookups
- Minimal calculations per frame for regeneration
- Signal emission only on actual state changes

### Physics Integration
- Leverages Godot's optimized RigidBody3D system
- Custom velocity constraints applied efficiently
- Afterburner checks optimized for common case (inactive)

### Memory Management
- Resource-based ship classes shared across instances
- Minimal per-ship memory overhead
- Signal connections managed automatically by Godot

## Debugging and Diagnostics

### Debug Information
```gdscript
# Get comprehensive ship status
var status = ship.get_ship_status()
print("Hull: %.1f%% Shield: %.1f%%" % [status.hull_percent, status.shield_percent])

# Performance information
var perf = ship.get_performance_info()
print("Engine: %.2f Weapons: %.2f" % [perf.engine_performance, perf.weapon_performance])

# Debug output
print(ship.debug_info())  # Includes space object and ship-specific info
```

### Signal Monitoring
```gdscript
# Monitor ship events
ship.ship_destroyed.connect(func(s): print("Ship destroyed: %s" % s.ship_name))
ship.shields_depleted.connect(func(): print("Shields down!"))
ship.energy_transfer_changed.connect(func(s, w, e): print("ETS: %.2f/%.2f/%.2f" % [s, w, e]))
```

## Next Steps

### Upcoming Stories
With SHIP-001 complete, the foundation is ready for:
- **SHIP-002**: Subsystem Management and Configuration
- **SHIP-003**: Ship Class Definitions and Factory System
- **SHIP-004**: Ship Lifecycle and State Management
- **SHIP-005**: Weapon Manager and Firing System

### Architecture Evolution
The BaseShip foundation will be extended with:
- Comprehensive subsystem hierarchy and damage modeling
- Weapon mounting and firing coordination
- Advanced ship AI integration
- Performance optimization for large fleet battles

### Integration Planning
BaseShip will coordinate with:
- **EPIC-010 AI Systems**: AI ship controllers using BaseShip interface
- **EPIC-012 HUD Systems**: Ship status display and ETS gauges
- **EPIC-008 Graphics**: Ship model integration and visual effects
- **EPIC-004 SEXP**: Mission scripting access to ship properties

The BaseShip implementation successfully provides the foundation for all WCS ship behavior while maintaining authentic gameplay feel and leveraging Godot's strengths for optimal performance.