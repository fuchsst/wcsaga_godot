# Core Objects Package - EPIC-009

## Purpose
Enhanced space object system providing physics-integrated entities for WCS-Godot conversion. Builds on EPIC-001 foundation to provide space-specific object management with Godot physics integration.

## Key Classes
- **BaseSpaceObject**: Main space entity class extending WCSObject with RigidBody3D physics (OBJ-001 ✅)
- **SpaceObjectFactory**: Enhanced factory for creating configured space objects with asset core integration (OBJ-003 ✅)
- **ObjectSerialization**: Comprehensive serialization system for save/load operations (OBJ-004 ✅)
- **SpaceObjectSaveData**: Resource for efficient save game integration (OBJ-004 ✅)
- **PhysicsProfile**: Resource defining physics behavior for different object types

## Implementation Status
- ✅ **OBJ-000**: Asset Core Integration Prerequisites - Complete with wcs_asset_core addon
- ✅ **OBJ-001**: Base Game Object System and Node Integration - Complete with BaseSpaceObject
- ✅ **OBJ-002**: Object Manager and Lifecycle Management Enhancement - Complete with enhanced ObjectManager
- ✅ **OBJ-003**: Enhanced Object Factory and Type Registration System - Complete with comprehensive factory
- ✅ **OBJ-004**: Object Serialization and Persistence System - Complete with comprehensive save/load support

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

### Object Serialization and Persistence (OBJ-004)
```gdscript
# Basic object serialization
var space_object: BaseSpaceObject = SpaceObjectFactory.create_space_object(ObjectTypes.Type.SHIP)
var serialized_data: Dictionary = space_object.serialize_to_dictionary()

# Deserialization with scene tree integration
var restored_object: BaseSpaceObject = BaseSpaceObject.new()
var success: bool = restored_object.deserialize_from_dictionary(serialized_data)

# Save game integration
var save_data: SpaceObjectSaveData = space_object.create_save_data()
var validation_result: ValidationResult = save_data.validate_save_data()
if validation_result.is_valid:
    print("Save data is valid for persistence")

# Incremental saves for performance
var objects: Array[BaseSpaceObject] = [ship1, ship2, ship3]
var changed_objects: Array[BaseSpaceObject] = ObjectSerialization.get_changed_objects(objects, last_save_data)
var incremental_save: Dictionary = ObjectSerialization.serialize_object_collection(changed_objects)

# Collection serialization/deserialization
var objects_data: Dictionary = ObjectSerialization.serialize_object_collection(objects)
var restored_objects: Array[BaseSpaceObject] = ObjectSerialization.deserialize_object_collection(objects_data, parent_node)

# SaveGameManager integration
var save_game_data: Dictionary = space_object.get_save_game_data()
SaveGameManager.save_space_object_data(save_game_data, save_slot)

# State change detection for optimization
var state_hash: String = space_object.get_state_hash()
if space_object.has_state_changed(last_hash):
    # Object has changed, needs to be saved
    save_object_state(space_object)
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
- **SaveGameManager** (EPIC-001): Serialization integration for save game persistence
- **ValidationResult** (EPIC-002): Data integrity validation using asset core validation framework
- **Future EPIC-008**: Graphics system integration for 3D model rendering
- **Future EPIC-010**: AI system integration for entity targeting

## Performance Considerations
- Uses object pooling through ObjectManager for efficient memory usage
- Collision layers optimize collision detection performance
- Physics profiles cached to prevent repeated resource creation
- Component composition avoids deep inheritance hierarchies
- **Serialization Performance**: Meets strict performance targets (< 2ms serialization, < 5ms deserialization per object)
- **Incremental Saves**: Only serializes changed objects for optimal save game performance
- **State Hash Caching**: Efficient change detection using SHA-256 state hashes
- **Validation Caching**: Serialization validation results cached for improved performance
- **Memory Optimization**: Minimal memory overhead during serialization operations

## Testing Notes
- Objects require ObjectManager autoload to be active
- Physics body creation happens in _ready(), test after add_child()
- Collision detection requires both objects to have physics_enabled = true
- Health system validates max_health > 0 for proper damage calculation
- **Serialization Testing**: Comprehensive test suite covers all 6 acceptance criteria (AC1-AC6)
- **Performance Testing**: Validates serialization/deserialization time targets
- **Round-trip Testing**: Ensures perfect state preservation through serialize/deserialize cycles
- **Incremental Save Testing**: Validates change detection and incremental serialization
- **Integration Testing**: Tests SaveGameManager and SpaceObjectSaveData Resource integration
- **Error Handling Testing**: Validates graceful handling of corrupted or invalid serialization data

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