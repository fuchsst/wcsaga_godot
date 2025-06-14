# Objects Scenes Directory

## Purpose
Reusable scene templates for game objects with behavior and visual components.

## Structure
- **asteroid.tscn**: Asteroid scene template with LOD model management
  - Uses AsteroidData resource for configuration
  - Handles physics, collision, and destruction
  - Automatically loads appropriate LOD models based on camera distance

## Key Components

### Asteroid Scene (asteroid.tscn)
- **RigidBody3D**: Physics simulation with space-appropriate settings
- **CollisionShape3D**: Physical collision detection
- **ModelContainer**: Container for dynamically loaded GLB models
- **Area3D**: Detection area for collision events
- **DebugInfo**: Debug label for development

## Usage Patterns

### Method 1: Direct .tres file loading
```gdscript
# Load asteroid scene
var asteroid_scene = preload("res://scenes/objects/asteroid.tscn")
var asteroid = asteroid_scene.instantiate()

# Load from .tres file
var success = asteroid.load_asteroid_from_file("res://assets/campaigns/wing_commander_saga/environments/objects/asteroids/large_asteroid.tres")
if success:
    add_child(asteroid)
```

### Method 2: Manual data assignment
```gdscript
# Load asteroid scene and data separately
var asteroid_scene = preload("res://scenes/objects/asteroid.tscn")
var asteroid = asteroid_scene.instantiate()
var asteroid_data = load("res://assets/campaigns/.../asteroids/large_asteroid.tres")

# Set data and initialize
asteroid.set_asteroid_data(asteroid_data)
add_child(asteroid)
```

### Method 3: Quick setup with positioning
```gdscript
# Load and setup in one call
var asteroid_scene = preload("res://scenes/objects/asteroid.tscn")
var asteroid = asteroid_scene.instantiate()
var asteroid_data = load("res://assets/campaigns/.../asteroids/large_asteroid.tres")

# Setup with position and rotation
asteroid.setup_asteroid(asteroid_data, Vector3(100, 0, 200), Vector3(0, PI/4, 0))
add_child(asteroid)
```

### Method 4: Editor assignment (via inspector)
```gdscript
# In the editor, assign the AsteroidData resource to the asteroid_data property
# The asteroid will automatically initialize when the scene starts
```

## Integration
- Works with AsteroidData resources from wcs_asset_core addon
- Follows semantic asset organization (DM-018)
- Compatible with WCS physics and damage systems
- Supports LOD model switching for performance