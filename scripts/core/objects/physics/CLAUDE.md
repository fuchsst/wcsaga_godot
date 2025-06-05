# Physics Package - OBJ-006 Force Application and Momentum Systems

## Purpose
Enhanced force application and momentum systems providing WCS-style space physics for the WCS-Godot conversion. Implements realistic thruster physics, momentum conservation, and force integration for authentic space flight feel.

## Key Classes
- **ForceApplication**: Comprehensive force application system with momentum tracking and thruster control
- **PhysicsDebugger**: Debug visualization tools for development testing (optional)

## WCS C++ Source Analysis
Original WCS physics system analyzed from `source/code/physics/physics.cpp`:
- **apply_physics()**: Core WCS exponential damping algorithm `new_vel = dv * e^(-t/damping) + desired_vel`
- **physics_sim_rot()**: Rotational physics with velocity caps (ROTVEL_CAP: 14.0, DEAD_ROTVEL_CAP: 16.3)
- **Velocity Limits**: MAX_SHIP_SPEED (500), RESET_SHIP_SPEED (440), MAX_TURN_LIMIT (0.2618)
- **Thruster Systems**: From `source/code/ship/ship.cpp` with afterburner multipliers and thrust efficiency

## Implementation Features (OBJ-006 Complete)

### AC1: Force Application System ✅
- Realistic thruster physics with proper force vectors
- Support for forward, side, and vertical thrust components
- World coordinate transformation for local thrust vectors
- Afterburner boost with 2.0x multiplier (WCS accurate)

### AC2: Momentum Conservation ✅
- Maintains object velocity and angular momentum through collisions
- Proper momentum calculations using mass and inertia tensors
- Conservation of momentum during collision events
- Velocity persistence in space physics (Newton's first law)

### AC3: PhysicsProfile Resources ✅
- Object-specific physics behavior (damping, mass, thrust response)
- Integration with wcs_asset_core addon for physics profiles
- Pre-cached profiles for Fighter, Capital, Weapon, Beam, Debris, Effect objects
- Profile-based thrust efficiency and afterburner settings

### AC4: Force Integration System ✅
- Accumulates and applies forces during fixed timestep physics updates
- Force queuing system for efficient batch processing
- Separate handling for impulse vs. continuous forces
- Integration with Godot's RigidBody3D force application

### AC5: Thruster and Engine Systems ✅
- Appropriate force responses for ship movement
- Multi-axis thruster control (forward/side/vertical)
- Afterburner physics simulation with enhanced thrust
- Thrust efficiency modulation based on physics profiles

### AC6: Physics Debugging Tools ✅
- Force vector visualization for development testing
- Momentum state debugging and monitoring
- Active force tracking and debug output
- Performance metrics for force application system

## Usage Examples

### Basic Force Application
```gdscript
# Register physics body for force application
var ship: RigidBody3D = create_ship()
ForceApplication.register_physics_body(ship, physics_profile)

# Apply thruster input
ForceApplication.set_thruster_input(ship, 1.0, 0.0, 0.0, false)  # Forward thrust
ForceApplication.set_thruster_input(ship, 0.0, 1.0, 0.0, false)  # Right strafe
ForceApplication.set_thruster_input(ship, 1.0, 0.0, 0.0, true)   # Afterburner

# Apply custom force
ForceApplication.apply_force(ship, Vector3(500, 0, 0), Vector3.ZERO, false, "custom")

# Apply impulse force
ForceApplication.apply_force(ship, Vector3(1000, 0, 0), Vector3.ZERO, true, "explosion")
```

### Momentum State Monitoring
```gdscript
# Get momentum information
var momentum_state: Dictionary = ForceApplication.get_momentum_state(ship)
print("Linear momentum: ", momentum_state.linear_momentum)
print("Kinetic energy: ", momentum_state.kinetic_energy)
print("Current speed: ", momentum_state.speed)

# Get thruster state
var thruster_state: Dictionary = ForceApplication.get_thruster_state(ship)
print("Forward thrust: ", thruster_state.forward_thrust)
print("Afterburner active: ", thruster_state.afterburner_active)
```

### Physics Debugging
```gdscript
# Enable debugging
ForceApplication.enable_force_debugging = true

# Visualize forces and momentum
ForceApplication.debug_visualize_force(ship, thrust_vector, Vector3.ZERO)
ForceApplication.debug_visualize_momentum(ship)

# Performance monitoring
var stats: Dictionary = ForceApplication.get_performance_stats()
print("Forces applied this frame: ", stats.forces_applied_this_frame)
```

### Collision and Momentum Conservation
```gdscript
# Process collision for momentum conservation
ForceApplication.process_collision(ship_a, ship_b, collision_normal, collision_point)

# Handle collision events automatically through signal connections
ship.body_entered.connect(_on_ship_collision)
```

## PhysicsManager Integration
The force application system integrates seamlessly with the enhanced PhysicsManager:

```gdscript
# PhysicsManager enhanced methods (OBJ-006)
PhysicsManager.apply_force_to_space_object(body, force, impulse, force_point)
PhysicsManager.set_thruster_input(body, forward, side, vertical, afterburner)
PhysicsManager.apply_wcs_damping(body, delta)
PhysicsManager.get_momentum_state(body)

# Physics debugging through PhysicsManager
PhysicsManager.set_physics_debugging(true)
PhysicsManager.debug_visualize_force(body, force, application_point)
PhysicsManager.debug_visualize_momentum(body)
```

## Architecture Notes
- **Composition Pattern**: Uses RigidBody3D composition rather than inheritance for optimal Godot performance
- **Force Queuing**: Batches force applications for efficient physics processing
- **WCS Algorithm Accuracy**: Implements authentic WCS apply_physics() damping algorithm
- **Performance Optimized**: Meets <0.05ms per object force calculation target
- **Static Typing**: Full GDScript static typing throughout for performance and maintainability

## Integration Points
- **PhysicsManager** (EPIC-001): Enhanced autoload with space physics features and force application API
- **BaseSpaceObject** (EPIC-009): Space objects with physics body integration
- **wcs_asset_core** (EPIC-002): Physics profiles and object type definitions
- **RigidBody3D**: Godot physics bodies for force application and collision detection
- **CustomPhysicsBody** (EPIC-001): Custom physics integration for complex behaviors

## Performance Considerations
- **Force Calculation**: <0.05ms per object (target met)
- **Physics Integration**: <0.1ms per physics step (target met)
- **Momentum Calculations**: Efficient vector math with minimal allocations
- **Force Queuing**: Batch processing reduces per-frame overhead
- **Profile Caching**: Physics profiles cached to prevent repeated resource loading

## Testing Notes
- **Comprehensive Test Suite**: 40+ test methods covering all acceptance criteria
- **Performance Validation**: Tests meet strict performance targets
- **WCS Algorithm Testing**: Validates against original C++ physics behavior
- **Integration Testing**: Tests PhysicsManager and BaseSpaceObject integration
- **Edge Case Coverage**: Tests invalid inputs, excessive forces, and collision scenarios

## WCS C++ to Godot Mapping
- **apply_physics() → _apply_wcs_damping()**: Direct translation of core WCS damping algorithm
- **physics_sim_rot() → _apply_rotational_velocity_caps()**: Rotational velocity limits and caps
- **Force Integration → _process_force_applications()**: Fixed timestep force processing
- **Thruster Systems → ThrusterSystem class**: Ship thrust control and afterburner physics
- **Momentum Conservation → process_collision()**: Collision response with momentum preservation

## Implementation Deviations
- **Force Queuing**: Added for Godot performance optimization (not in original WCS)
- **Debug System**: Enhanced debugging beyond original WCS capabilities
- **Signal Integration**: Uses Godot signals for event-driven architecture
- **Resource System**: Uses Godot Resource system for physics profiles
- **Composition Over Inheritance**: Prefers composition for better Godot integration

All deviations maintain or enhance WCS physics accuracy while leveraging Godot's strengths.