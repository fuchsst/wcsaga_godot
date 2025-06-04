# Core Objects Package - EPIC-009

## Purpose
Enhanced space object system providing physics-integrated entities for WCS-Godot conversion. Builds on EPIC-001 foundation to provide space-specific object management with Godot physics integration.

## Key Classes
- **BaseSpaceObject**: Main space entity class extending WCSObject with RigidBody3D physics (OBJ-001 ✅)
- **SpaceObjectFactory**: Enhanced factory for creating configured space objects with asset core integration (OBJ-003 ✅)
- **PhysicsProfile**: Resource defining physics behavior for different object types

## Implementation Status
- ✅ **OBJ-000**: Asset Core Integration Prerequisites - Complete with wcs_asset_core addon
- ✅ **OBJ-001**: Base Game Object System and Node Integration - Complete with BaseSpaceObject
- ✅ **OBJ-002**: Object Manager and Lifecycle Management Enhancement - Complete with enhanced ObjectManager
- ✅ **OBJ-003**: Enhanced Object Factory and Type Registration System - Complete with comprehensive factory

## Architecture
```
BaseSpaceObject (extends WCSObject)
├── Composition: RigidBody3D + CollisionShape3D + MeshInstance3D  
├── Categories: Ship, Weapon, Debris, Asteroid, Cargo, Waypoint, etc.
├── Physics Integration: Space physics with 6DOF movement
└── Health System: Damage and destruction with debris creation
```

## Usage Examples

### Basic Object Creation
```gdscript
# Create a ship using factory
var ship: BaseSpaceObject = SpaceObjectFactory.create_ship_object(ship_data)
ship.activate()
ship.global_position = Vector3(100, 0, 0)

# Create a weapon projectile  
var weapon: BaseSpaceObject = SpaceObjectFactory.create_weapon_object(weapon_data)
weapon.set_physics_velocity(Vector3(0, 0, 500))  # Forward velocity
```

### Physics Manipulation
```gdscript
# Apply thrust to object
space_object.apply_force(Vector3(0, 0, 1000))  # Forward thrust

# Apply damage and handle destruction
space_object.take_damage(50.0)
space_object.object_destroyed.connect(_on_object_destroyed)
```

### Enhanced Factory Usage (OBJ-003)
```gdscript
# Initialize factory with default types
SpaceObjectFactory.initialize_factory()

# Create objects using ObjectTypes enum (AC2)
var ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.FIGHTER)
var weapon: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.WEAPON)

# Create with configuration data (AC5)
var creation_data: Dictionary = {
    "max_health": 150.0,
    "collision_radius": 3.0,
    "position": Vector3(10, 0, 0),
    "asset_path": "ships/heavy_fighter.tres"
}
var heavy_fighter: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.FIGHTER, creation_data)

# Create with deferred initialization (AC6)
var deferred_data: Dictionary = {"deferred_init": true}
var deferred_ship: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP, deferred_data)

# SEXP integration for mission scripting (AC8)
SpaceObjectFactory.enable_sexp_integration()
var sexp_data: Dictionary = {
    "type": "capital",
    "position": Vector3(100, 50, 200),
    "ship_class": "cruiser"
}
var mission_ship: BaseSpaceObject = SpaceObjectFactory.create_object_from_sexp(sexp_data)
```

### Type Registration System (AC4)
```gdscript
# Register custom object types with templates
var template_data: Dictionary = {
    "max_health": 2000.0,
    "collision_radius": 25.0,
    "physics_enabled": true
}
SpaceObjectFactory.register_object_type(ObjectTypes.Type.CAPITAL, template_data)

# Check registration status
if SpaceObjectFactory.is_object_type_registered(ObjectTypes.Type.CAPITAL):
    print("Capital ships can be created")

# Get all registered types
var registered_types: Array[ObjectTypes.Type] = SpaceObjectFactory.get_registered_object_types()
```

### Asset Core Integration (AC2, AC3)
```gdscript
# Factory automatically uses wcs_asset_core constants
var ship_type: ObjectTypes.Type = ObjectTypes.Type.SHIP
var ship_name: String = ObjectTypes.get_type_name(ship_type)  # "Ship"

# Asset loading through factory
var ship_with_data: BaseSpaceObject = SpaceObjectFactory.create_ship_object(null, "heavy_fighter")
var weapon_with_data: BaseSpaceObject = SpaceObjectFactory.create_weapon_object(null, "laser_cannon")
```

### Custom Physics Profiles (AC5)
```gdscript
# Register custom physics profile for object type
var custom_profile: PhysicsProfile = PhysicsProfile.new()
custom_profile.mass = 5.0
custom_profile.linear_damping = 0.05
SpaceObjectFactory.register_physics_profile(ObjectTypes.Type.CARGO, custom_profile)
```

## Integration Points
- **ObjectManager** (EPIC-001): Object lifecycle and pooling coordination
- **PhysicsManager** (EPIC-001): Physics step integration via _physics_update()
- **WCSObject** (EPIC-001): Inherits identification and data management
- **wcs_asset_core** (EPIC-002): Asset data integration for object creation
- **Future EPIC-008**: Graphics system integration for 3D model rendering
- **Future EPIC-010**: AI system integration for entity targeting

## Performance Considerations
- Uses object pooling through ObjectManager for efficient memory usage
- Collision layers optimize collision detection performance
- Physics profiles cached to prevent repeated resource creation
- Component composition avoids deep inheritance hierarchies

## Testing Notes
- Objects require ObjectManager autoload to be active
- Physics body creation happens in _ready(), test after add_child()
- Collision detection requires both objects to have physics_enabled = true
- Health system validates max_health > 0 for proper damage calculation

## Signals
- `object_destroyed(object)`: Emitted when object health reaches zero
- `collision_detected(other, info)`: Emitted on collision with another BaseSpaceObject  
- `physics_state_changed()`: Emitted when physics body state changes
- `lifecycle_event(type, data)`: Emitted for activation, deactivation, destruction

## Dependencies
- Extends: WCSObject (target/scripts/core/wcs_object.gd)
- Requires: ObjectManager autoload (target/autoload/object_manager.gd)
- Uses: PhysicsProfile resource for physics configuration
- Scene Template: scenes/core/objects/BaseSpaceObject.tscn