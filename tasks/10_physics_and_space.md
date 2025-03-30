# Physics and Space Environment Systems

This document outlines the physics and space environment systems from the original Wing Commander Saga codebase and how they should be implemented in Godot.

## Overview

The physics and space environment systems in Wing Commander Saga include:

1. **Asteroid Field System** - Generation and management of asteroid fields
2. **Debris System** - Creation and management of ship debris after destruction
3. **Fireball/Explosion System** - Visual effects for explosions and weapon impacts
4. **Decal System** - Visual effects applied to ship surfaces (impacts, damage)
5. **Warp Effects** - Visual effects for ship warping in/out of a scene
6. **Jump Node System** - Interstellar travel points for mission transitions
7. **Lighting System** - Dynamic lighting for space environments
8. **Nebula System** - Volumetric fog and environmental effects
9. **Physics Engine** - Ship movement and collision physics
10. **Particle System** - General-purpose particle effects
11. **Starfield System** - Background star rendering and management
12. **Supernova Effects** - Special effects for supernova events

These systems are primarily visual but also have gameplay implications through collision detection and damage application.

## 1. Asteroid Field System

### Original Implementation

The asteroid system in the original codebase:
- Manages asteroid fields with configurable density, size, and movement
- Supports different asteroid types and models
- Handles asteroid collisions with ships and weapons
- Includes asteroid wrapping within defined boundaries
- Supports asteroid breaking into smaller pieces when destroyed

### Godot Implementation

```gdscript
class_name AsteroidField extends Node3D

signal asteroid_destroyed(asteroid: Asteroid, position: Vector3)

@export var field_size: Vector3 = Vector3(10000, 5000, 10000)
@export var inner_bound_size: Vector3 = Vector3.ZERO  # If non-zero, creates a hollow center
@export var num_asteroids: int = 100
@export var asteroid_types: Array[AsteroidType] = []
@export var field_speed: float = 10.0
@export var field_direction: Vector3 = Vector3.FORWARD
@export var wrap_asteroids: bool = true

# Asteroid field generation
func generate_field() -> void:
    # Create asteroid instances based on field parameters
    # Position them randomly within field boundaries
    # Apply initial velocities
    pass

# Asteroid wrapping logic
func _process(delta: float) -> void:
    # Check if asteroids have left the field boundaries
    # Wrap them to the opposite side if needed
    pass
```

```gdscript
class_name Asteroid extends RigidBody3D

signal asteroid_hit(damage: float, hit_position: Vector3)

@export var asteroid_type: AsteroidType
@export var size_class: int  # 0=small, 1=medium, 2=large
@export var health: float = 100.0
@export var debris_on_destroy: bool = true

# Handle collision with ships and weapons
func _on_body_entered(body: Node) -> void:
    if body is Ship or body is Projectile:
        apply_damage(body.get_impact_damage(), body.global_position)

# Apply damage and potentially break apart
func apply_damage(damage: float, hit_position: Vector3) -> void:
    health -= damage
    if health <= 0:
        destroy(hit_position)
    
# Break into smaller pieces when destroyed
func destroy(hit_position: Vector3) -> void:
    if size_class > 0 and debris_on_destroy:
        spawn_smaller_asteroids(hit_position)
    
    # Create explosion effect
    var explosion = ExplosionManager.create_explosion(
        global_position, 
        "asteroid", 
        size_class
    )
    
    queue_free()
```

## 2. Debris System

### Original Implementation

The debris system in the original codebase:
- Creates debris pieces when ships are destroyed
- Supports hull debris (large pieces) and small debris
- Applies physics to debris (rotation, velocity)
- Manages debris lifetime and cleanup
- Handles debris collisions with ships

### Godot Implementation

```gdscript
class_name DebrisManager extends Node

# Configuration
var max_debris_pieces: int = 200
var max_debris_distance: float = 10000.0
var debris_check_interval: float = 10.0  # seconds

# Create debris from destroyed ship
func create_ship_debris(ship: Ship, explosion_center: Vector3, explosion_force: float) -> void:
    var ship_model = ship.get_model()
    var ship_size = ship.get_size_class()
    
    # Create hull debris (large pieces)
    var num_hull_pieces = min(ship_size * 2, 8)
    for i in range(num_hull_pieces):
        create_hull_debris(ship, ship_model, explosion_center, explosion_force)
    
    # Create small debris
    var num_small_pieces = min(ship_size * 10, 30)
    for i in range(num_small_pieces):
        create_small_debris(ship, explosion_center, explosion_force)

# Create a large hull piece
func create_hull_debris(ship: Ship, model: ShipModel, explosion_center: Vector3, explosion_force: float) -> DebrisHull:
    var debris = DebrisHull.new()
    # Set up debris properties based on ship model
    # Apply physics (velocity, rotation)
    # Set lifetime based on ship size
    return debris

# Create small generic debris
func create_small_debris(ship: Ship, explosion_center: Vector3, explosion_force: float) -> DebrisSmall:
    var debris = DebrisSmall.new()
    # Set up debris properties
    # Apply physics (velocity, rotation)
    # Set shorter lifetime
    return debris
    
# Clean up distant debris
func _on_cleanup_timer_timeout() -> void:
    # Check distance of all debris from player
    # Remove debris that is too far away
    pass
```

```gdscript
class_name DebrisBase extends RigidBody3D

var source_ship_type: String
var lifetime: float = 10.0
var time_elapsed: float = 0.0
var must_survive_until: float = 0.0  # Minimum survival time

func _process(delta: float) -> void:
    time_elapsed += delta
    if time_elapsed > lifetime and time_elapsed > must_survive_until:
        queue_free()
```

```gdscript
class_name DebrisHull extends DebrisBase

var ship_model_part: MeshInstance3D
var can_damage_ships: bool = true
var damage_multiplier: float = 1.0

func _on_body_entered(body: Node) -> void:
    if body is Ship and can_damage_ships:
        var impact_velocity = linear_velocity.length()
        var damage = impact_velocity * mass * 0.01 * damage_multiplier
        body.apply_damage(damage, global_position)
```

## 3. Fireball/Explosion System

### Original Implementation

The fireball system in the original codebase:
- Manages different types of explosion effects
- Supports various sizes and visual styles
- Handles animation playback and timing
- Includes specialized effects like warp-in/out explosions
- Manages sound effects for explosions

### Godot Implementation

```gdscript
class_name ExplosionManager extends Node

# Explosion type constants
enum ExplosionType {
    SMALL,
    MEDIUM,
    LARGE,
    ASTEROID,
    WARP,
    KNOSSOS
}

# Create an explosion at a position
func create_explosion(position: Vector3, type: ExplosionType, parent_obj = null, size_scale: float = 1.0) -> Explosion:
    var explosion = Explosion.new()
    explosion.explosion_type = type
    explosion.global_position = position
    explosion.scale = Vector3.ONE * size_scale
    
    # Set up appropriate animation, sound, and light effects
    setup_explosion_effects(explosion, type)
    
    add_child(explosion)
    return explosion

# Set up explosion effects based on type
func setup_explosion_effects(explosion: Explosion, type: ExplosionType) -> void:
    match type:
        ExplosionType.SMALL:
            explosion.animation = load("res://assets/effects/explosion_small.tscn")
            explosion.sound = load("res://assets/sounds/explosion_small.wav")
            explosion.light_energy = 2.0
            explosion.lifetime = 1.0
        ExplosionType.MEDIUM:
            # Similar setup for medium explosion
            pass
        ExplosionType.LARGE:
            # Similar setup for large explosion
            pass
        ExplosionType.WARP:
            # Special setup for warp effect
            pass
```

```gdscript
class_name Explosion extends Node3D

var explosion_type: ExplosionType
var lifetime: float = 2.0
var time_elapsed: float = 0.0
var animation_player: AnimationPlayer
var light: OmniLight3D
var particles: GPUParticles3D
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
    # Set up components
    animation_player = $AnimationPlayer
    light = $OmniLight3D
    particles = $GPUParticles3D
    audio_player = $AudioStreamPlayer3D
    
    # Start animation and sound
    animation_player.play("explosion")
    audio_player.play()

func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Fade out light over time
    if light:
        light.light_energy = lerp(light.light_energy, 0.0, delta * 2.0)
    
    # Remove explosion when complete
    if time_elapsed >= lifetime:
        queue_free()
```

## 4. Decal System

### Original Implementation

The decal system in the original codebase:
- Applies visual effects to ship surfaces (damage marks, weapon impacts)
- Manages decal lifetime and fading
- Handles decal positioning and orientation on 3D models
- Supports different decal types (burn marks, weapon impacts, etc.)

### Godot Implementation

In Godot, we can use the built-in decal system with some custom management:

```gdscript
class_name DecalManager extends Node

# Decal type constants
enum DecalType {
    WEAPON_IMPACT,
    BURN_MARK,
    SCRATCH,
    EXPLOSION_MARK
}

# Maximum decals per ship
var max_decals_per_ship: int = 20

# Create a decal on a ship surface
func create_decal(position: Vector3, normal: Vector3, size: float, type: DecalType, target_object: Node3D) -> Decal:
    # Check if target has a decal container
    var decal_container = get_decal_container(target_object)
    
    # If too many decals, remove oldest
    if decal_container.get_child_count() >= max_decals_per_ship:
        var oldest_decal = decal_container.get_child(0)
        oldest_decal.queue_free()
    
    # Create new decal
    var decal = Decal.new()
    decal.decal_type = type
    
    # Set up decal properties based on type
    setup_decal_properties(decal, type)
    
    # Position and orient decal
    position_decal(decal, position, normal, size, target_object)
    
    # Add to container
    decal_container.add_child(decal)
    return decal

# Get or create decal container on target
func get_decal_container(target_object: Node3D) -> Node3D:
    if target_object.has_node("DecalContainer"):
        return target_object.get_node("DecalContainer")
    
    var container = Node3D.new()
    container.name = "DecalContainer"
    target_object.add_child(container)
    return container

# Set up decal properties based on type
func setup_decal_properties(decal: Decal, type: DecalType) -> void:
    match type:
        DecalType.WEAPON_IMPACT:
            decal.texture = load("res://assets/decals/weapon_impact.png")
            decal.lifetime = 10.0
        DecalType.BURN_MARK:
            decal.texture = load("res://assets/decals/burn_mark.png")
            decal.lifetime = 30.0
        # Other types...
```

```gdscript
class_name Decal extends Node3D

var decal_type: DecalType
var lifetime: float = 10.0
var time_elapsed: float = 0.0
var fade_time: float = 2.0
var decal_mesh: MeshInstance3D

func _ready() -> void:
    decal_mesh = $DecalMesh
    
func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Fade out decal when nearing end of lifetime
    if time_elapsed > lifetime - fade_time:
        var alpha = (lifetime - time_elapsed) / fade_time
        decal_mesh.material.albedo_color.a = alpha
    
    # Remove when lifetime is over
    if time_elapsed >= lifetime:
        queue_free()
```

## 5. Warp Effects

### Original Implementation

The warp effect system in the original codebase:
- Creates visual effects for ships entering/exiting a scene via warp
- Manages warp-in and warp-out animations
- Handles sound effects for warp events
- Scales effects based on ship size

### Godot Implementation

```gdscript
class_name WarpEffectManager extends Node

# Create a warp-in effect
func create_warp_in(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    var warp = WarpEffect.new()
    warp.global_position = position
    warp.global_transform.basis = orientation
    warp.is_warp_in = true
    warp.ship_size = ship_size
    warp.ship_class = ship_class
    
    # Set up warp effect based on ship class
    setup_warp_effect(warp)
    
    add_child(warp)
    return warp

# Create a warp-out effect
func create_warp_out(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    var warp = WarpEffect.new()
    warp.global_position = position
    warp.global_transform.basis = orientation
    warp.is_warp_in = false
    warp.ship_size = ship_size
    warp.ship_class = ship_class
    
    # Set up warp effect based on ship class
    setup_warp_effect(warp)
    
    add_child(warp)
    return warp

# Set up warp effect properties
func setup_warp_effect(warp: WarpEffect) -> void:
    # Scale effect based on ship size
    warp.scale = Vector3.ONE * warp.ship_size * 0.01
    
    # Set appropriate sound effect
    if warp.is_warp_in:
        if warp.ship_size > 100:  # Capital ship
            warp.sound = load("res://assets/sounds/warp_in_capital.wav")
        else:
            warp.sound = load("res://assets/sounds/warp_in.wav")
    else:
        if warp.ship_size > 100:  # Capital ship
            warp.sound = load("res://assets/sounds/warp_out_capital.wav")
        else:
            warp.sound = load("res://assets/sounds/warp_out.wav")
```

```gdscript
class_name WarpEffect extends Node3D

var is_warp_in: bool = true
var ship_size: float = 10.0
var ship_class: String = ""
var lifetime: float = 2.35  # WARPHOLE_GROW_TIME from original code
var time_elapsed: float = 0.0
var warp_model: MeshInstance3D
var warp_particles: GPUParticles3D
var warp_light: OmniLight3D
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
    # Set up components
    warp_model = $WarpModel
    warp_particles = $WarpParticles
    warp_light = $WarpLight
    audio_player = $AudioStreamPlayer3D
    
    # Start animation and sound
    if is_warp_in:
        $AnimationPlayer.play("warp_in")
    else:
        $AnimationPlayer.play("warp_out")
    
    audio_player.play()

func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Update effect size based on time
    var t = time_elapsed
    var radius = ship_size
    
    if is_warp_in:
        if t < lifetime:
            radius = pow(t / lifetime, 0.4) * ship_size
        else:
            radius = ship_size
    else:
        if t < lifetime:
            radius = ship_size
        else:
            radius = pow((2 * lifetime - t) / lifetime, 0.4) * ship_size
    
    warp_model.scale = Vector3.ONE * radius / ship_size
    
    # Remove effect when complete
    if time_elapsed >= 2 * lifetime:
        queue_free()
```

## 6. Jump Node System

### Original Implementation

The jump node system in the original codebase:
- Represents interstellar travel points in missions
- Manages visual representation of jump nodes
- Handles ship entry/exit through jump nodes
- Supports different jump node models and effects
- Provides detection for when ships enter jump nodes
- Uses a linked list structure to track all jump nodes in a mission
- Supports customizable display colors and visibility settings
- Includes methods to find jump nodes by name or check if a ship is inside a node
- Implements rendering with optional wireframe mode (show_polys flag)
- Allows for custom model assignment with set_model() function

### Godot Implementation

```gdscript
class_name JumpNode extends Node3D

signal ship_entered(ship: Ship)

@export var node_name: String = "Jump Node"
@export var model_path: String = "res://assets/models/subspacenode.glb"
@export var display_color: Color = Color(0, 1, 0, 1)  # Default green
@export var show_polys: bool = false
@export var hidden: bool = false
@export_flags("Use Display Color", "Show Polys", "Hide", "Special Model") var flags: int = 0

var _model: MeshInstance3D
var _collision_shape: CollisionShape3D
var _area: Area3D

func _ready() -> void:
    # Load model
    var model_scene = load(model_path)
    if model_scene:
        _model = model_scene.instantiate()
        add_child(_model)
        
        # Set up collision area
        _area = Area3D.new()
        _area.collision_layer = 0
        _area.collision_mask = 1  # Ship layer
        add_child(_area)
        
        _collision_shape = CollisionShape3D.new()
        var shape = SphereShape3D.new()
        shape.radius = _calculate_model_radius()
        _collision_shape.shape = shape
        _area.add_child(_collision_shape)
        
        # Connect signals
        _area.connect("body_entered", _on_body_entered)
    
    # Apply visibility settings
    set_hidden(hidden)
    set_display_properties(display_color, show_polys)

func set_model(new_model_path: String, show_model_polys: bool = false) -> void:
    # Remove old model
    if _model:
        _model.queue_free()
    
    # Load new model
    model_path = new_model_path
    show_polys = show_model_polys
    
    var model_scene = load(model_path)
    if model_scene:
        _model = model_scene.instantiate()
        add_child(_model)
        
        # Update collision shape
        var shape = SphereShape3D.new()
        shape.radius = _calculate_model_radius()
        _collision_shape.shape = shape
        
        # Apply visibility settings
        set_display_properties(display_color, show_polys)

func set_display_properties(color: Color, show_model_polys: bool) -> void:
    display_color = color
    show_polys = show_model_polys
    
    if _model:
        # Apply color to model materials
        for i in range(_model.get_surface_override_material_count()):
            var material = _model.get_surface_override_material(i)
            if material:
                material = material.duplicate()
                material.albedo_color = display_color
                _model.set_surface_override_material(i, material)
        
        # Set wireframe mode if not showing polys
        if not show_polys:
            for i in range(_model.get_surface_override_material_count()):
                var material = _model.get_surface_override_material(i)
                if material:
                    material = material.duplicate()
                    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    material.albedo_color.a = 0.7
                    _model.set_surface_override_material(i, material)

func set_hidden(is_hidden: bool) -> void:
    hidden = is_hidden
    visible = !hidden

func _calculate_model_radius() -> float:
    # Calculate radius from model's AABB
    if _model:
        var aabb = _model.get_aabb()
        return aabb.size.length() / 2.0
    return 50.0  # Default radius

func _on_body_entered(body: Node3D) -> void:
    if body is Ship:
        emit_signal("ship_entered", body)
```

```gdscript
class_name JumpNodeManager extends Node

var jump_nodes: Dictionary = {}  # name -> JumpNode

func register_jump_node(node: JumpNode) -> void:
    jump_nodes[node.node_name] = node

func unregister_jump_node(node: JumpNode) -> void:
    if jump_nodes.has(node.node_name):
        jump_nodes.erase(node.node_name)

func get_jump_node_by_name(name: String) -> JumpNode:
    if jump_nodes.has(name):
        return jump_nodes[name]
    return null

func get_jump_node_for_ship(ship: Ship) -> JumpNode:
    # Check if ship is inside any jump node
    for node_name in jump_nodes:
        var node = jump_nodes[node_name]
        var distance = ship.global_position.distance_to(node.global_position)
        var radius = node._calculate_model_radius()
        
        if distance <= radius:
            return node
    
    return null
```

## 7. Lighting System

### Original Implementation

The lighting system in the original codebase:
- Manages different types of light sources (directional, point, tube)
- Supports dynamic lighting with intensity and color
- Handles light attenuation and falloff
- Provides ambient and reflective lighting
- Supports specular highlights
- Includes light filtering for performance optimization
- Uses two lighting modes: LM_BRIGHTEN (additive) and LM_DARKEN (subtractive)
- Defines default ambient light (0.15) and reflective light (0.75) values
- Implements a light rotation system for proper orientation in the game world
- Supports special light effects for shockwaves and weapon impacts
- Includes performance optimizations like light filtering by distance and relevance
- Provides RGB and specular color control for all light types
- Implements light attenuation with inner and outer radius parameters

### Godot Implementation

```gdscript
class_name SpaceLightingManager extends Node

# Lighting constants
const AMBIENT_LIGHT_DEFAULT: float = 0.15
const REFLECTIVE_LIGHT_DEFAULT: float = 0.75
const LM_BRIGHTEN: int = 0
const LM_DARKEN: int = 1

# Lighting properties
var ambient_light: float = AMBIENT_LIGHT_DEFAULT
var reflective_light: float = REFLECTIVE_LIGHT_DEFAULT
var lighting_enabled: bool = true
var dynamic_lighting_enabled: bool = true

# Light arrays
var directional_lights: Array[SpaceDirectionalLight] = []
var point_lights: Array[SpacePointLight] = []
var tube_lights: Array[SpaceTubeLight] = []

# Environment
var environment: Environment

func _ready() -> void:
    # Create default environment
    environment = Environment.new()
    environment.ambient_light_color = Color(ambient_light, ambient_light, ambient_light)
    environment.ambient_light_energy = 1.0
    
    # Set up default directional light (sun)
    add_directional_light(Vector3(0.5, -0.7, 0.2), 1.0, Color(1.0, 0.9, 0.7))

func add_directional_light(direction: Vector3, intensity: float, color: Color, specular_color: Color = Color.WHITE) -> SpaceDirectionalLight:
    var light = SpaceDirectionalLight.new()
    light.direction = direction.normalized()
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    
    # Create Godot DirectionalLight3D
    var godot_light = DirectionalLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.light_specular = 0.5
    godot_light.global_transform.basis = Basis(Quaternion.from_euler(Vector3(0, 0, 0)).looking_at(direction))
    
    light.godot_light = godot_light
    add_child(godot_light)
    
    directional_lights.append(light)
    return light

func add_point_light(position: Vector3, inner_radius: float, outer_radius: float, 
                    intensity: float, color: Color, ignore_object_id: int = -1,
                    specular_color: Color = Color.WHITE) -> SpacePointLight:
    var light = SpacePointLight.new()
    light.position = position
    light.inner_radius = inner_radius
    light.outer_radius = outer_radius
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    light.ignore_object_id = ignore_object_id
    
    # Create Godot OmniLight3D
    var godot_light = OmniLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.omni_range = outer_radius
    godot_light.omni_attenuation = 1.0
    godot_light.global_position = position
    
    light.godot_light = godot_light
    add_child(godot_light)
    
    point_lights.append(light)
    return light

func add_tube_light(start_pos: Vector3, end_pos: Vector3, inner_radius: float, outer_radius: float,
                   intensity: float, color: Color, affected_object_id: int = -1,
                   specular_color: Color = Color.WHITE) -> SpaceTubeLight:
    var light = SpaceTubeLight.new()
    light.start_position = start_pos
    light.end_position = end_pos
    light.inner_radius = inner_radius
    light.outer_radius = outer_radius
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    light.affected_object_id = affected_object_id
    
    # Create multiple Godot OmniLight3D to simulate tube
    var center_pos = (start_pos + end_pos) / 2.0
    var length = start_pos.distance_to(end_pos)
    var num_segments = max(1, floor(length / (inner_radius * 2)))
    
    for i in range(num_segments):
        var t = float(i) / float(num_segments - 1 if num_segments > 1 else 1)
        var pos = start_pos.lerp(end_pos, t)
        
        var godot_light = OmniLight3D.new()
        godot_light.light_color = color
        godot_light.light_energy = intensity / num_segments
        godot_light.omni_range = outer_radius
        godot_light.omni_attenuation = 1.0
        godot_light.global_position = pos
        
        add_child(godot_light)
        light.godot_lights.append(godot_light)
    
    tube_lights.append(light)
    return light

func set_ambient_light(value: float) -> void:
    ambient_light = clamp(value, 0.0, 1.0)
    environment.ambient_light_color = Color(ambient_light, ambient_light, ambient_light)

func set_reflective_light(value: float) -> void:
    reflective_light = clamp(value, 0.0, 1.0)
    # Update all materials to use new reflective light value
    # This would affect the specular intensity of materials

func set_lighting_enabled(enabled: bool) -> void:
    lighting_enabled = enabled
    for light in directional_lights:
        if light.godot_light:
            light.godot_light.visible = enabled
    
    for light in point_lights:
        if light.godot_light:
            light.godot_light.visible = enabled
    
    for light in tube_lights:
        for godot_light in light.godot_lights:
            godot_light.visible = enabled

func reset_to_defaults() -> void:
    set_ambient_light(AMBIENT_LIGHT_DEFAULT)
    set_reflective_light(REFLECTIVE_LIGHT_DEFAULT)
    lighting_enabled = true
    dynamic_lighting_enabled = true
```

```gdscript
class_name SpaceDirectionalLight extends Resource

var direction: Vector3
var intensity: float
var light_color: Color
var specular_color: Color
var godot_light: DirectionalLight3D

func _init() -> void:
    direction = Vector3(0, -1, 0)
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    godot_light = null
```

```gdscript
class_name SpacePointLight extends Resource

var position: Vector3
var inner_radius: float
var outer_radius: float
var intensity: float
var light_color: Color
var specular_color: Color
var ignore_object_id: int
var godot_light: OmniLight3D

func _init() -> void:
    position = Vector3.ZERO
    inner_radius = 10.0
    outer_radius = 50.0
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    ignore_object_id = -1
    godot_light = null
```

```gdscript
class_name SpaceTubeLight extends Resource

var start_position: Vector3
var end_position: Vector3
var inner_radius: float
var outer_radius: float
var intensity: float
var light_color: Color
var specular_color: Color
var affected_object_id: int
var godot_lights: Array[OmniLight3D]

func _init() -> void:
    start_position = Vector3.ZERO
    end_position = Vector3(0, 0, 10)
    inner_radius = 10.0
    outer_radius = 50.0
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    affected_object_id = -1
    godot_lights = []
```

## 8. Nebula System

### Original Implementation

The nebula system in the original codebase:
- Creates volumetric fog effects for space environments
- Supports different nebula types and densities
- Handles dynamic fog color and intensity
- Includes lightning effects within nebulae
- Manages performance optimization for nebula rendering
- Supports AWACS gameplay mechanics (radar interference)
- Uses a cube-based system for nebula rendering with configurable slices
- Implements a "poof" system for nebula cloud elements with rotation and alpha effects
- Supports multiple nebula bitmap types loaded from nebula.tbl
- Includes dynamic fog color calculation based on texture analysis
- Features a detail level system with configurable parameters for different performance levels
- Implements special rendering for HTL (Hardware Transform & Lighting) mode
- Provides fog distance calculations for different ship types
- Includes a lightning storm system with configurable parameters
- Uses a cube-based system for nebula rendering with configurable slices
- Implements a "poof" system for nebula cloud elements with rotation and alpha effects
- Supports multiple nebula bitmap types loaded from nebula.tbl
- Includes dynamic fog color calculation based on texture analysis
- Features a detail level system with configurable parameters for different performance levels
- Implements special rendering for HTL (Hardware Transform & Lighting) mode
- Provides fog distance calculations for different ship types
- Includes a lightning storm system with configurable parameters

### Godot Implementation

```gdscript
class_name NebulaManager extends Node3D

signal lightning_created(position: Vector3, target: Vector3)

# Nebula properties
@export var enabled: bool = false
@export var fog_color: Color = Color(0.12, 0.2, 0.61)  # Default blue nebula
@export var fog_density: float = 0.02
@export var fog_height: float = 1000.0
@export var fog_falloff: float = 1.0
@export var slices: int = 5
@export var render_mode: int = 0  # 0=None, 1=Poly, 2=POF, 3=Lame, 4=HTL
@export var awacs_factor: float = -1.0  # -1.0 means disabled
@export_range(0, 5) var detail_level: int = 3

# Nebula detail settings
var detail_settings: Array[Dictionary] = [
    {
        "max_alpha": 0.575,
        "break_alpha": 0.13,
        "break_x": 150.0,
        "break_y": 112.5,
        "cube_dim": 510.0,
        "cube_inner": 50.0,
        "cube_outer": 250.0,
        "prad": 120.0
    },
    # Additional detail levels would be defined here
]

# Nebula storm system
class_name NebulaStorm extends Resource
var name: String = ""
var bolt_types: Array[int] = []
var flavor: Vector3 = Vector3.ZERO
var min_time: int = 750
var max_time: int = 10000
var min_count: int = 1
var max_count: int = 3

# Add a new section for Physics Engine before "Integration with Other Systems"

## 9. Physics Engine

### Original Implementation

The physics engine in the original codebase:
- Implements Newtonian physics for ship movement and rotation
- Supports different physics modes including normal flight, glide, and special warp
- Handles ship rotation with damping and maximum rotation limits
- Implements velocity ramping for smooth acceleration and deceleration
- Provides functions for applying external forces (whack, shock)
- Supports special physics flags for different movement states
- Includes reduced damping system for impacts and weapon hits
- Implements afterburner and booster physics
- Provides functions for physics prediction and simulation
- Includes a control system for translating player input to physics forces
- Supports special movement modes like dead-drift and slide

### Godot Implementation

```gdscript
class_name SpacePhysics extends Node

# Physics constants
const MAX_TURN_LIMIT: float = 0.2618
const ROTVEL_TOL: float = 0.1
const ROTVEL_CAP: float = 14.0
const DEAD_ROTVEL_CAP: float = 16.3
const MAX_SHIP_SPEED: float = 500.0
const RESET_SHIP_SPEED: float = 440.0
const SW_ROT_FACTOR: float = 5.0
const SW_BLAST_DURATION: int = 2000
const REDUCED_DAMP_FACTOR: float = 10.0
const REDUCED_DAMP_VEL: float = 30.0
const REDUCED_DAMP_TIME: int = 2000
const WEAPON_SHAKE_TIME: int = 500
const SPECIAL_WARP_T_CONST: float = 0.651

# Physics flags
enum PhysicsFlags {
    ACCELERATES = 1 << 1,
    USE_VEL = 1 << 2,
    AFTERBURNER_ON = 1 << 3,
    SLIDE_ENABLED = 1 << 4,
    REDUCED_DAMP = 1 << 5,
    IN_SHOCKWAVE = 1 << 6,
    DEAD_DAMP = 1 << 7,
    AFTERBURNER_WAIT = 1 << 8,
    CONST_VEL = 1 << 9,
    WARP_IN = 1 << 10,
    SPECIAL_WARP_IN = 1 << 11,
    WARP_OUT = 1 << 12,
    SPECIAL_WARP_OUT = 1 << 13,
    BOOSTER_ON = 1 << 14,
    GLIDING = 1 << 15
}

# Apply physics to a ship
func simulate_physics(ship: ShipBase, delta: float) -> void:
    # Skip if physics is paused
    if physics_paused:
        return
        
    # Apply velocity changes
    simulate_velocity(ship, delta)
    
    # Apply rotation changes
    simulate_rotation(ship, delta)
    
    # Update ship speed values
    ship.physics.speed = ship.physics.velocity.length()
    ship.physics.forward_speed = ship.physics.velocity.dot(ship.global_transform.basis.z)

# Apply velocity changes
func simulate_velocity(ship: ShipBase, delta: float) -> void:
    var local_velocity = ship.global_transform.basis.inverse() * ship.physics.velocity
    var local_desired_velocity = ship.global_transform.basis.inverse() * ship.physics.desired_velocity
    var damping = Vector3(
        ship.physics.side_slip_time_const,
        ship.physics.side_slip_time_const,
        ship.physics.side_slip_time_const if ship.physics.use_newtonian_damp else 0.0
    )
    
    # Apply reduced damping if active
    if ship.physics.flags & PhysicsFlags.REDUCED_DAMP:
        # Calculate reduced damping factor based on time remaining
        pass
        
    # Apply physics to each axis
    var local_displacement = Vector3.ZERO
    var local_new_velocity = Vector3.ZERO
    
    # X-axis
    apply_physics(
        damping.x, 
        local_desired_velocity.x, 
        local_velocity.x, 
        delta, 
        local_new_velocity.x, 
        local_displacement.x
    )
    
    # Y-axis
    apply_physics(
        damping.y, 
        local_desired_velocity.y, 
        local_velocity.y, 
        delta, 
        local_new_velocity.y, 
        local_displacement.y
    )
    
    # Z-axis (with special warp handling)
    if ship.physics.flags & PhysicsFlags.SPECIAL_WARP_IN:
        # Special warp-in physics
        pass
    elif ship.physics.flags & PhysicsFlags.SPECIAL_WARP_OUT:
        # Special warp-out physics
        pass
    else:
        apply_physics(
            damping.z, 
            local_desired_velocity.z, 
            local_velocity.z, 
            delta, 
            local_new_velocity.z, 
            local_displacement.z
        )
    
    # Convert local displacement to world space
    var world_displacement = ship.global_transform.basis * local_displacement
    
    # Apply displacement to ship position
    ship.global_position += world_displacement
    
    # Update ship velocity
    ship.physics.velocity = ship.global_transform.basis * local_new_velocity

# Apply rotation changes
func simulate_rotation(ship: ShipBase, delta: float) -> void:
    var new_rotational_velocity = Vector3.ZERO
    var rotational_damping = ship.physics.rotational_damping
    
    # Apply shockwave effects if active
    if ship.physics.flags & PhysicsFlags.IN_SHOCKWAVE:
        # Calculate shock fraction and adjust damping
        pass
    
    # Apply physics to each rotation axis
    apply_physics(
        rotational_damping,
        ship.physics.desired_rotational_velocity.x,
        ship.physics.rotational_velocity.x,
        delta,
        new_rotational_velocity.x,
        null
    )
    
    apply_physics(
        rotational_damping,
        ship.physics.desired_rotational_velocity.y,
        ship.physics.rotational_velocity.y,
        delta,
        new_rotational_velocity.y,
        null
    )
    
    apply_physics(
        rotational_damping,
        ship.physics.desired_rotational_velocity.z,
        ship.physics.rotational_velocity.z,
        delta,
        new_rotational_velocity.z,
        null
    )
    
    # Update ship rotational velocity
    ship.physics.rotational_velocity = new_rotational_velocity
    
    # Calculate rotation angles
    var angles = Vector3(
        ship.physics.rotational_velocity.x * delta,
        ship.physics.rotational_velocity.y * delta,
        ship.physics.rotational_velocity.z * delta
    )
    
    # Apply rotation to ship
    ship.rotate_object_local(Vector3.RIGHT, angles.x)
    ship.rotate_object_local(Vector3.UP, angles.y)
    ship.rotate_object_local(Vector3.FORWARD, angles.z)
    
    # Ensure the basis stays orthogonal
    ship.global_transform.basis = ship.global_transform.basis.orthonormalized()

# Apply physics formula to calculate new velocity and displacement
func apply_physics(damping: float, desired_vel: float, initial_vel: float, 
                  delta: float, new_vel: float, delta_pos: float) -> void:
    if damping < 0.0001:
        if delta_pos != null:
            delta_pos = desired_vel * delta
        if new_vel != null:
            new_vel = desired_vel
    else:
        var dv = initial_vel - desired_vel
        var e = exp(-delta / damping)
        if delta_pos != null:
            delta_pos = (1.0 - e) * dv * damping + desired_vel * delta
        if new_vel != null:
            new_vel = dv * e + desired_vel
```

## 10. Particle System

### Original Implementation

The particle system in the original codebase:
- Provides a general-purpose particle effect framework
- Supports different particle types (bitmap, fire, smoke, debug, etc.)
- Manages particle creation, movement, and rendering
- Handles particle lifetime and aging
- Supports particle attachment to objects
- Includes particle emitters for continuous effects
- Implements performance optimizations like culling and batching
- Provides particle animation through frame sequences
- Supports different rendering modes and alpha blending
- Includes tracer effects for projectiles

### Godot Implementation

```gdscript
class_name ParticleManager extends Node

# Particle type constants
enum ParticleType {
    DEBUG,
    BITMAP,
    FIRE,
    SMOKE,
    SMOKE2,
    BITMAP_PERSISTENT,
    BITMAP_3D
}

# Particle system configuration
var particles_enabled: bool = true
var max_particles: int = 2000
var particles: Array[Particle] = []

# Preloaded particle resources
var fire_animation: AnimatedTexture
var smoke_animation: AnimatedTexture
var smoke2_animation: AnimatedTexture

func _ready() -> void:
    # Load particle animations
    fire_animation = load("res://assets/effects/particleexp01.tres")
    smoke_animation = load("res://assets/effects/particlesmoke01.tres")
    smoke2_animation = load("res://assets/effects/particlesmoke02.tres")

# Create a particle with detailed parameters
func create_particle(info: ParticleInfo) -> void:
    if not particles_enabled or particles.size() >= max_particles:
        return
        
    var particle = Particle.new()
    particle.position = info.position
    particle.normal = info.normal
    particle.velocity = info.velocity
    particle.age = 0.0
    particle.max_life = info.lifetime
    particle.radius = info.radius
    particle.type = info.type
    particle.optional_data = info.optional_data
    particle.color = info.color
    particle.tracer_length = info.tracer_length
    particle.attached_objnum = info.attached_objnum
    particle.attached_sig = info.attached_sig
    particle.reverse = info.reverse
    
    # Set up animation frames based on type
    match info.type:
        ParticleType.FIRE:
            particle.optional_data = fire_animation.get_instance_id()
            particle.nframes = fire_animation.frames
        ParticleType.SMOKE:
            particle.optional_data = smoke_animation.get_instance_id()
            particle.nframes = smoke_animation.frames
        ParticleType.SMOKE2:
            particle.optional_data = smoke2_animation.get_instance_id()
            particle.nframes = smoke2_animation.frames
        ParticleType.BITMAP, ParticleType.BITMAP_PERSISTENT, ParticleType.BITMAP_3D:
            if info.optional_data >= 0:
                var texture = instance_from_id(info.optional_data)
                if texture is AnimatedTexture:
                    particle.nframes = texture.frames
                    if particle.nframes > 1:
                        particle.max_life = float(particle.nframes) / 30.0  # Assuming 30fps
    
    particles.append(particle)

# Create a particle with simplified parameters
func create_particle_simple(position: Vector3, velocity: Vector3, lifetime: float, 
                           radius: float, type: int, optional_data: int = -1,
                           tracer_length: float = -1.0, attached_obj = null, 
                           reverse: bool = false) -> void:
    var info = ParticleInfo.new()
    info.position = position
    info.normal = Vector3.FORWARD  # Default normal
    info.velocity = velocity
    info.lifetime = lifetime
    info.radius = radius
    info.type = type
    info.optional_data = optional_data
    info.color = Color(1, 1, 1)  # Default white
    info.tracer_length = tracer_length
    
    if attached_obj:
        info.attached_objnum = attached_obj.get_instance_id()
        info.attached_sig = attached_obj.signature
    else:
        info.attached_objnum = -1
        info.attached_sig = -1
        
    info.reverse = reverse
    
    create_particle(info)

# Update all particles
func _process(delta: float) -> void:
    if not particles_enabled:
        return
        
    # Process particles in reverse to safely remove them
    for i in range(particles.size() - 1, -1, -1):
        var p = particles[i]
        
        # Age the particle
        if p.age == 0.0:
            p.age = 0.00001
        else:
            p.age += delta
            
        # Check if particle has expired
        if p.age > p.max_life:
            particles.remove_at(i)
            continue
            
        # Check if attached object still exists
        if p.attached_objnum >= 0:
            var obj = instance_from_id(p.attached_objnum)
            if not is_instance_valid(obj) or obj.signature != p.attached_sig:
                particles.remove_at(i)
                continue
        else:
            # Move unattached particles
            p.position += p.velocity * delta

# Render all particles
func _render_particles() -> void:
    if not particles_enabled or particles.empty():
        return
        
    # Set up rendering batch
    var render_batch = false
    
    for p in particles:
        var position = p.position
        
        # If attached to an object, transform position
        if p.attached_objnum >= 0:
            var obj = instance_from_id(p.attached_objnum)
            if is_instance_valid(obj):
                # Transform position based on object
                pass
                
        # Calculate alpha based on distance and age
        var alpha = calculate_particle_alpha(position, p.age / p.max_life)
        
        # Skip if not visible
        if alpha <= 0.0:
            continue
            
        # Calculate current frame for animated particles
        var frame = 0
        if p.nframes > 1:
            var pct_complete = p.age / p.max_life
            frame = int(pct_complete * p.nframes + 0.5)
            frame = clamp(frame, 0, p.nframes - 1)
            if p.reverse:
                frame = p.nframes - frame - 1
                
        # Render based on particle type
        match p.type:
            ParticleType.DEBUG:
                # Debug rendering
                pass
            ParticleType.BITMAP_3D:
                # 3D billboard with normal
                pass
            _:  # Standard particles
                # Add to batch for efficient rendering
                render_batch = true
                
    # Render batched particles
    if render_batch:
        # Batch rendering code
        pass

# Create a particle emitter
class_name ParticleEmitter extends Node3D

@export var num_low: int = 1
@export var num_high: int = 5
@export var min_life: float = 1.0
@export var max_life: float = 3.0
@export var normal: Vector3 = Vector3.UP
@export var normal_variance: float = 0.5
@export var min_velocity: float = 1.0
@export var max_velocity: float = 5.0
@export var min_radius: float = 0.5
@export var max_radius: float = 2.0

# Emit particles
func emit(type: int, optional_data: int, range: float = 1.0) -> void:
    if not ParticleManager.particles_enabled:
        return
        
    # Calculate number of particles based on detail level
    var percent = get_detail_percent()
    
    # Adjust based on distance from camera
    var min_dist = 125.0
    var dist = global_position.distance_to(get_viewport().get_camera_3d().global_position) / range
    if dist > min_dist:
        percent = int(float(percent) * min_dist / dist)
        if percent < 1:
            return
            
    var n1 = (num_low * percent) / 100
    var n2 = (num_high * percent) / 100
    var n = (randi() % (n2 - n1 + 1)) + n1
    
    if n < 1:
        return
        
    # Create particles
    for i in range(n):
        var particle_normal = Vector3(
            normal.x + (randf() * 2.0 - 1.0) * normal_variance,
            normal.y + (randf() * 2.0 - 1.0) * normal_variance,
            normal.z + (randf() * 2.0 - 1.0) * normal_variance
        ).normalized()
        
        var radius = ((max_radius - min_radius) * randf()) + min_radius
        var speed = ((max_velocity - min_velocity) * randf()) + min_velocity
        var life = ((max_life - min_life) * randf()) + min_life
        
        var velocity = velocity + particle_normal * speed
        
        ParticleManager.create_particle_simple(
            global_position,
            velocity,
            life,
            radius,
            type,
            optional_data
        )
```

## 11. Starfield System

### Original Implementation

The starfield system in the original codebase:
- Renders a dynamic starfield background with thousands of stars (`MAX_STARS`).
- Supports star movement with tail effects based on camera movement (`Star_flags & STAR_FLAG_TAIL`).
- Manages star colors, brightness, and density (`star_colors`, `star_aacolors`, `Star_dim`, `Star_cap`).
- Includes a bitmap-based starfield for more detailed backgrounds (`Starfield_bitmaps`, `Starfield_bitmap_instances`).
- Supports multiple background layers with parallax effects (implied by bitmap system).
- Handles loading and management of sun bitmaps with glow effects (`Sun_bitmaps`, `Suns`, `glow_bitmap`).
- Implements lens flare effects for suns (`flare`, `flare_infos`, `flare_bitmaps`).
- Provides a system for loading and managing starfield bitmaps from tables (`parse_startbl`, `stars.tbl`).
- Supports different star rendering modes (points, tails, anti-aliased - `Star_flags`).
- Includes configurable star parameters (amount, dimming, cap, length - `Star_amount`, `Star_dim`, `Star_cap`, `Star_max_length`).
- Manages star movement and camera cuts (`stars_camera_cut`, `last_star_pos`).
- Implements background model rendering for skyboxes (`Nmodel_num`, `Nmodel_bitmap`, `stars_set_background_model`).
- Supports dynamic environment changes (`Dynamic_environment`).
- Includes a separate nebula rendering system (`nebula.cpp`, `nebula_render`) which can be layered with the starfield.
- Manages small debris particles (`odebris`, `Debris_vclips`) moving in the background.
- Supports subspace warp visual effects (`subspace_render`, `Subspace_model_inner`, `Subspace_model_outer`).
- Handles supernova effects (`supernova.cpp`, `supernova_process`).
- Uses perspective projection for background bitmaps (`g3_draw_perspective_bitmap`, `starfield_create_perspective_bitmap_buffer`).
- Optimizes bitmap rendering using vertex buffers (`perspective_bitmap_buffer`).

### Godot Implementation

```gdscript
class_name StarfieldManager extends Node3D

# Starfield configuration
@export var num_stars: int = 500
@export var star_amount: float = 0.75  # Tail effect amount
@export var star_dim: float = 7800.0   # Dimming rate
@export var star_cap: float = 75.0     # Minimum brightness
@export var star_max_length: float = 0.04
@export_flags("Tail", "Dim", "Antialias") var star_flags: int = 3  # Default: Tail + Dim

# Star arrays
var stars: Array[Star] = []
var star_colors: Array[Color] = []
var star_aa_colors: Array[Color] = []  # Anti-aliased colors

# Background bitmaps
var starfield_bitmaps: Array[StarfieldBitmap] = []
var starfield_instances: Array[StarfieldBitmapInstance] = []
var sun_bitmaps: Array[StarfieldBitmap] = []
var suns: Array[StarfieldBitmapInstance] = []

# Background model
var background_model: MeshInstance3D
var background_texture: Texture

func _ready() -> void:
    # Initialize star colors
    for i in range(8):
        var intensity = (i + 1) * 24
        star_colors.append(Color(intensity/255.0, intensity/255.0, intensity/255.0))
        star_aa_colors.append(Color(1.0, 1.0, 1.0, intensity/255.0))
    
    # Generate stars
    generate_stars()
    
    # Load starfield bitmaps from configuration
    load_starfield_bitmaps()
    
    # Set up background model if specified
    setup_background_model()

func generate_stars() -> void:
    stars.clear()
    
    for i in range(num_stars):
        var star = Star.new()
        
        # Generate random position on unit sphere
        var v = Vector3(
            randf_range(-1.0, 1.0),
            randf_range(-1.0, 1.0),
            randf_range(-1.0, 1.0)
        )
        while v.length_squared() >= 1.0:
            v = Vector3(
                randf_range(-1.0, 1.0),
                randf_range(-1.0, 1.0),
                randf_range(-1.0, 1.0)
            )
        
        star.position = v.normalized() * 1000.0
        star.last_position = star.position
        
        # Random color
        var red = randf_range(192, 255)
        var green = randf_range(192, 255)
        var blue = randf_range(192, 255)
        var alpha = randf_range(24, 216)
        star.color = Color(red/255.0, green/255.0, blue/255.0, alpha/255.0)
        
        stars.append(star)

func _process(delta: float) -> void:
    # Update star positions based on camera movement
    update_stars()
    
    # Update sun positions and lens flares
    update_suns()

func update_stars() -> void:
    var camera = get_viewport().get_camera_3d()
    if not camera:
        return
    
    # Transform stars to camera space
    for star in stars:
        var p = camera.global_transform.basis.inverse() * (star.position - camera.global_position)
        
        # Skip stars behind the camera
        if p.z <= 0:
            continue
        
        # Project to screen space
        var screen_pos = camera.unproject_position(star.position)
        
        # Calculate tail effect if enabled
        if star_flags & 1:  # STAR_FLAG_TAIL
            var last_p = camera.global_transform.basis.inverse() * (star.last_position - camera.global_position)
            if last_p.z > 0:
                var last_screen_pos = camera.unproject_position(star.last_position)
                var dist = screen_pos.distance_to(last_screen_pos)
                
                # Apply tail effect
                if dist > 0:
                    # Draw line from last position to current
                    if dist > star_max_length:
                        var ratio = star_max_length / dist
                        dist = star_max_length
                        last_screen_pos = screen_pos.lerp(last_screen_pos, ratio * star_amount)
                    
                    # Apply dimming if enabled
                    if star_flags & 2:  # STAR_FLAG_DIM
                        var color_factor = 255.0 - dist * star_dim
                        if color_factor < star_cap:
                            color_factor = star_cap
                        
                        # Draw star with appropriate color
                        if star_flags & 4:  # STAR_FLAG_ANTIALIAS
                            draw_line(Vector2(screen_pos.x, screen_pos.y),
                                     Vector2(last_screen_pos.x, last_screen_pos.y),
                                     star.color.lerp(Color(0,0,0,0), 1.0 - color_factor/255.0))
                        else:
                            draw_line(Vector2(screen_pos.x, screen_pos.y),
                                     Vector2(last_screen_pos.x, last_screen_pos.y),
                                     star.color)
                    else:
                        # Draw without dimming
                        draw_line(Vector2(screen_pos.x, screen_pos.y),
                                 Vector2(last_screen_pos.x, last_screen_pos.y),
                                 star.color)
            }
        else:
            # Just draw the star as a point
            draw_rect(Rect2(screen_pos.x-1, screen_pos.y-1, 2, 2), star.color)
        
        # Update last position
        star.last_position = star.position

func camera_cut() -> void:
    # Reset star last positions on camera cut
    for star in stars:
        star.last_position = star.position

func draw_suns(show_suns: bool) -> void:
    if not show_suns:
        return
    
    var camera = get_viewport().get_camera_3d()
    if not camera:
        return
    
    for i in range(suns.size()):
        var sun_bitmap = sun_bitmaps[suns[i].star_bitmap_index]
        if sun_bitmap.bitmap_id < 0:
            continue
        
        # Get sun position
        var sun_pos = Vector3(0, 0, 1)
        var rot_matrix = Basis()
        rot_matrix = rot_matrix.rotated(Vector3(1, 0, 0), suns[i].ang.x)
        rot_matrix = rot_matrix.rotated(Vector3(0, 1, 0), suns[i].ang.y)
        rot_matrix = rot_matrix.rotated(Vector3(0, 0, 1), suns[i].ang.z)
        sun_pos = rot_matrix * sun_pos * 1000.0
        
        # Project to screen
        var screen_pos = camera.unproject_position(sun_pos)
        
        # Draw sun bitmap
        var texture = ImageTexture.create_from_image(sun_bitmap.bitmap_id)
        var size = texture.get_size() * suns[i].scale_x * 0.05
        draw_texture_rect(texture,
                         Rect2(screen_pos.x - size.x/2, screen_pos.y - size.y/2, size.x, size.y),
                         false)
        
        # Draw sun glow
        if sun_bitmap.glow_bitmap >= 0:
            var glow_texture = ImageTexture.create_from_image(sun_bitmap.glow_bitmap)
            var glow_size = glow_texture.get_size() * suns[i].scale_x * 0.1
            draw_texture_rect(glow_texture,
                             Rect2(screen_pos.x - glow_size.x/2, screen_pos.y - glow_size.y/2,
                                  glow_size.x, glow_size.y),
                             false,
                             Color(1, 1, 1, 0.5))
        
        # Draw lens flare if enabled
        if sun_bitmap.flare:
            draw_lens_flare(screen_pos, i)

func draw_lens_flare(screen_pos: Vector2, sun_index: int) -> void:
    var sun_bitmap = sun_bitmaps[suns[sun_index].star_bitmap_index]
    if not sun_bitmap.flare:
        return
    
    # Calculate screen center
    var screen_center = Vector2(get_viewport().size) / 2.0
    
    # Calculate displacement from center
    var dx = 2.0 * (screen_center.x - screen_pos.x)
    var dy = 2.0 * (screen_center.y - screen_pos.y)
    
    # Draw flare elements
    for j in range(sun_bitmap.n_flare_bitmaps):
        if sun_bitmap.flare_bitmaps[j].bitmap_id < 0:
            continue
        
        var texture = ImageTexture.create_from_image(sun_bitmap.flare_bitmaps[j].bitmap_id)
        
        for i in range(sun_bitmap.n_flares):
            if sun_bitmap.flare_infos[i].tex_num == j:
                var flare_pos = Vector2(
                    screen_pos.x + dx * sun_bitmap.flare_infos[i].pos,
                    screen_pos.y + dy * sun_bitmap.flare_infos[i].pos
                )
                
                var size = texture.get_size() * sun_bitmap.flare_infos[i].scale * 0.05
                draw_texture_rect(texture,
                                 Rect2(flare_pos.x - size.x/2, flare_pos.y - size.y/2,
                                      size.x, size.y),
                                 false,
                                 Color(1, 1, 1, 0.5))

func setup_background_model(model_path: String = "", texture_path: String = "") -> void:
    # Clear existing model
    if background_model:
        background_model.queue_free()
        background_model = null
    
    if model_path.is_empty():
        return
    
    # Load model
    var model_scene = load(model_path)
    if not model_scene:
        return
    
    background_model = model_scene.instantiate()
    add_child(background_model)
    
    # Load texture if specified
    if not texture_path.is_empty():
        background_texture = load(texture_path)
        if background_texture:
            var material = StandardMaterial3D.new()
            material.albedo_texture = background_texture
            material.flags_unshaded = true
            material.flags_do_not_receive_shadows = true
            material.params_cull_mode = StandardMaterial3D.CULL_DISABLED
            
            # Apply to all meshes
            for child in background_model.get_children():
                if child is MeshInstance3D:
                    child.material_override = material

func load_starfield_bitmaps() -> void:
    # Load starfield bitmaps from a configuration file (e.g., stars.tbl)
    pass
```

```gdscript
class_name Star extends Resource

var position: Vector3
var last_position: Vector3
var color: Color

func _init() -> void:
    position = Vector3.ZERO
    last_position = Vector3.ZERO
    color = Color.WHITE
```

```gdscript
class_name StarfieldBitmap extends Resource

var filename: String = ""
var glow_filename: String = ""
var bitmap_id: int = -1
var glow_bitmap: int = -1
var n_frames: int = 1
var fps: int = 0
var glow_n_frames: int = 1
var glow_fps: int = 0
var xparent: bool = true
var r: float = 1.0
var g: float = 1.0
var b: float = 1.0
var i: float = 1.0
var spec_r: float = 1.0
var spec_g: float = 1.0
var spec_b: float = 1.0
var glare: bool = true
var flare: bool = false
var flare_infos: Array = []
var flare_bitmaps: Array = []
var n_flares: int = 0
var n_flare_bitmaps: int = 0
var used_this_level: bool = false
var preload: bool = false
```

```gdscript
class_name StarfieldBitmapInstance extends Resource

var scale_x: float = 1.0
var scale_y: float = 1.0
var div_x: int = 1
var div_y: int = 1
var ang: Vector3 = Vector3.ZERO
var star_bitmap_index: int = -1
var buffer: Array = []
```
# Physics and Space Environment Systems

This document outlines the physics and space environment systems from the original Wing Commander Saga codebase and how they should be implemented in Godot.

## Overview

The physics and space environment systems in Wing Commander Saga include:

1. **Asteroid Field System** - Generation and management of asteroid fields
2. **Debris System** - Creation and management of ship debris after destruction
3. **Fireball/Explosion System** - Visual effects for explosions and weapon impacts
4. **Decal System** - Visual effects applied to ship surfaces (impacts, damage)
5. **Warp Effects** - Visual effects for ship warping in/out of a scene
6. **Jump Node System** - Interstellar travel points for mission transitions
7. **Lighting System** - Dynamic lighting for space environments
8. **Nebula System** - Volumetric fog and environmental effects
9. **Physics Engine** - Ship movement and collision physics
10. **Particle System** - General-purpose particle effects
11. **Starfield System** - Background star rendering and management
12. **Supernova Effects** - Special effects for supernova events

These systems are primarily visual but also have gameplay implications through collision detection and damage application.

## 1. Asteroid Field System

### Original Implementation

The asteroid system in the original codebase:
- Manages asteroid fields with configurable density, size, and movement
- Supports different asteroid types and models
- Handles asteroid collisions with ships and weapons
- Includes asteroid wrapping within defined boundaries
- Supports asteroid breaking into smaller pieces when destroyed

### Godot Implementation

```gdscript
class_name AsteroidField extends Node3D

signal asteroid_destroyed(asteroid: Asteroid, position: Vector3)

@export var field_size: Vector3 = Vector3(10000, 5000, 10000)
@export var inner_bound_size: Vector3 = Vector3.ZERO  # If non-zero, creates a hollow center
@export var num_asteroids: int = 100
@export var asteroid_types: Array[AsteroidType] = []
@export var field_speed: float = 10.0
@export var field_direction: Vector3 = Vector3.FORWARD
@export var wrap_asteroids: bool = true

# Asteroid field generation
func generate_field() -> void:
    # Create asteroid instances based on field parameters
    # Position them randomly within field boundaries
    # Apply initial velocities
    pass

# Asteroid wrapping logic
func _process(delta: float) -> void:
    # Check if asteroids have left the field boundaries
    # Wrap them to the opposite side if needed
    pass
```

```gdscript
class_name Asteroid extends RigidBody3D

signal asteroid_hit(damage: float, hit_position: Vector3)

@export var asteroid_type: AsteroidType
@export var size_class: int  # 0=small, 1=medium, 2=large
@export var health: float = 100.0
@export var debris_on_destroy: bool = true

# Handle collision with ships and weapons
func _on_body_entered(body: Node) -> void:
    if body is Ship or body is Projectile:
        apply_damage(body.get_impact_damage(), body.global_position)

# Apply damage and potentially break apart
func apply_damage(damage: float, hit_position: Vector3) -> void:
    health -= damage
    if health <= 0:
        destroy(hit_position)
    
# Break into smaller pieces when destroyed
func destroy(hit_position: Vector3) -> void:
    if size_class > 0 and debris_on_destroy:
        spawn_smaller_asteroids(hit_position)
    
    # Create explosion effect
    var explosion = ExplosionManager.create_explosion(
        global_position, 
        "asteroid", 
        size_class
    )
    
    queue_free()
```

## 2. Debris System

### Original Implementation

The debris system in the original codebase:
- Creates debris pieces when ships are destroyed
- Supports hull debris (large pieces) and small debris
- Applies physics to debris (rotation, velocity)
- Manages debris lifetime and cleanup
- Handles debris collisions with ships

### Godot Implementation

```gdscript
class_name DebrisManager extends Node

# Configuration
var max_debris_pieces: int = 200
var max_debris_distance: float = 10000.0
var debris_check_interval: float = 10.0  # seconds

# Create debris from destroyed ship
func create_ship_debris(ship: Ship, explosion_center: Vector3, explosion_force: float) -> void:
    var ship_model = ship.get_model()
    var ship_size = ship.get_size_class()
    
    # Create hull debris (large pieces)
    var num_hull_pieces = min(ship_size * 2, 8)
    for i in range(num_hull_pieces):
        create_hull_debris(ship, ship_model, explosion_center, explosion_force)
    
    # Create small debris
    var num_small_pieces = min(ship_size * 10, 30)
    for i in range(num_small_pieces):
        create_small_debris(ship, explosion_center, explosion_force)

# Create a large hull piece
func create_hull_debris(ship: Ship, model: ShipModel, explosion_center: Vector3, explosion_force: float) -> DebrisHull:
    var debris = DebrisHull.new()
    # Set up debris properties based on ship model
    # Apply physics (velocity, rotation)
    # Set lifetime based on ship size
    return debris

# Create small generic debris
func create_small_debris(ship: Ship, explosion_center: Vector3, explosion_force: float) -> DebrisSmall:
    var debris = DebrisSmall.new()
    # Set up debris properties
    # Apply physics (velocity, rotation)
    # Set shorter lifetime
    return debris
    
# Clean up distant debris
func _on_cleanup_timer_timeout() -> void:
    # Check distance of all debris from player
    # Remove debris that is too far away
    pass
```

```gdscript
class_name DebrisBase extends RigidBody3D

var source_ship_type: String
var lifetime: float = 10.0
var time_elapsed: float = 0.0
var must_survive_until: float = 0.0  # Minimum survival time

func _process(delta: float) -> void:
    time_elapsed += delta
    if time_elapsed > lifetime and time_elapsed > must_survive_until:
        queue_free()
```

```gdscript
class_name DebrisHull extends DebrisBase

var ship_model_part: MeshInstance3D
var can_damage_ships: bool = true
var damage_multiplier: float = 1.0

func _on_body_entered(body: Node) -> void:
    if body is Ship and can_damage_ships:
        var impact_velocity = linear_velocity.length()
        var damage = impact_velocity * mass * 0.01 * damage_multiplier
        body.apply_damage(damage, global_position)
```

## 3. Fireball/Explosion System

### Original Implementation

The fireball system in the original codebase:
- Manages different types of explosion effects
- Supports various sizes and visual styles
- Handles animation playback and timing
- Includes specialized effects like warp-in/out explosions
- Manages sound effects for explosions

### Godot Implementation

```gdscript
class_name ExplosionManager extends Node

# Explosion type constants
enum ExplosionType {
    SMALL,
    MEDIUM,
    LARGE,
    ASTEROID,
    WARP,
    KNOSSOS
}

# Create an explosion at a position
func create_explosion(position: Vector3, type: ExplosionType, parent_obj = null, size_scale: float = 1.0) -> Explosion:
    var explosion = Explosion.new()
    explosion.explosion_type = type
    explosion.global_position = position
    explosion.scale = Vector3.ONE * size_scale
    
    # Set up appropriate animation, sound, and light effects
    setup_explosion_effects(explosion, type)
    
    add_child(explosion)
    return explosion

# Set up explosion effects based on type
func setup_explosion_effects(explosion: Explosion, type: ExplosionType) -> void:
    match type:
        ExplosionType.SMALL:
            explosion.animation = load("res://assets/effects/explosion_small.tscn")
            explosion.sound = load("res://assets/sounds/explosion_small.wav")
            explosion.light_energy = 2.0
            explosion.lifetime = 1.0
        ExplosionType.MEDIUM:
            # Similar setup for medium explosion
            pass
        ExplosionType.LARGE:
            # Similar setup for large explosion
            pass
        ExplosionType.WARP:
            # Special setup for warp effect
            pass
```

```gdscript
class_name Explosion extends Node3D

var explosion_type: ExplosionType
var lifetime: float = 2.0
var time_elapsed: float = 0.0
var animation_player: AnimationPlayer
var light: OmniLight3D
var particles: GPUParticles3D
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
    # Set up components
    animation_player = $AnimationPlayer
    light = $OmniLight3D
    particles = $GPUParticles3D
    audio_player = $AudioStreamPlayer3D
    
    # Start animation and sound
    animation_player.play("explosion")
    audio_player.play()

func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Fade out light over time
    if light:
        light.light_energy = lerp(light.light_energy, 0.0, delta * 2.0)
    
    # Remove explosion when complete
    if time_elapsed >= lifetime:
        queue_free()
```

## 4. Decal System

### Original Implementation

The decal system in the original codebase:
- Applies visual effects to ship surfaces (damage marks, weapon impacts)
- Manages decal lifetime and fading
- Handles decal positioning and orientation on 3D models
- Supports different decal types (burn marks, weapon impacts, etc.)

### Godot Implementation

In Godot, we can use the built-in decal system with some custom management:

```gdscript
class_name DecalManager extends Node

# Decal type constants
enum DecalType {
    WEAPON_IMPACT,
    BURN_MARK,
    SCRATCH,
    EXPLOSION_MARK
}

# Maximum decals per ship
var max_decals_per_ship: int = 20

# Create a decal on a ship surface
func create_decal(position: Vector3, normal: Vector3, size: float, type: DecalType, target_object: Node3D) -> Decal:
    # Check if target has a decal container
    var decal_container = get_decal_container(target_object)
    
    # If too many decals, remove oldest
    if decal_container.get_child_count() >= max_decals_per_ship:
        var oldest_decal = decal_container.get_child(0)
        oldest_decal.queue_free()
    
    # Create new decal
    var decal = Decal.new()
    decal.decal_type = type
    
    # Set up decal properties based on type
    setup_decal_properties(decal, type)
    
    # Position and orient decal
    position_decal(decal, position, normal, size, target_object)
    
    # Add to container
    decal_container.add_child(decal)
    return decal

# Get or create decal container on target
func get_decal_container(target_object: Node3D) -> Node3D:
    if target_object.has_node("DecalContainer"):
        return target_object.get_node("DecalContainer")
    
    var container = Node3D.new()
    container.name = "DecalContainer"
    target_object.add_child(container)
    return container

# Set up decal properties based on type
func setup_decal_properties(decal: Decal, type: DecalType) -> void:
    match type:
        DecalType.WEAPON_IMPACT:
            decal.texture = load("res://assets/decals/weapon_impact.png")
            decal.lifetime = 10.0
        DecalType.BURN_MARK:
            decal.texture = load("res://assets/decals/burn_mark.png")
            decal.lifetime = 30.0
        # Other types...
```

```gdscript
class_name Decal extends Node3D

var decal_type: DecalType
var lifetime: float = 10.0
var time_elapsed: float = 0.0
var fade_time: float = 2.0
var decal_mesh: MeshInstance3D

func _ready() -> void:
    decal_mesh = $DecalMesh
    
func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Fade out decal when nearing end of lifetime
    if time_elapsed > lifetime - fade_time:
        var alpha = (lifetime - time_elapsed) / fade_time
        decal_mesh.material.albedo_color.a = alpha
    
    # Remove when lifetime is over
    if time_elapsed >= lifetime:
        queue_free()
```

## 5. Warp Effects

### Original Implementation

The warp effect system in the original codebase:
- Creates visual effects for ships entering/exiting a scene via warp
- Manages warp-in and warp-out animations
- Handles sound effects for warp events
- Scales effects based on ship size

### Godot Implementation

```gdscript
class_name WarpEffectManager extends Node

# Create a warp-in effect
func create_warp_in(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    var warp = WarpEffect.new()
    warp.global_position = position
    warp.global_transform.basis = orientation
    warp.is_warp_in = true
    warp.ship_size = ship_size
    warp.ship_class = ship_class
    
    # Set up warp effect based on ship class
    setup_warp_effect(warp)
    
    add_child(warp)
    return warp

# Create a warp-out effect
func create_warp_out(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    var warp = WarpEffect.new()
    warp.global_position = position
    warp.global_transform.basis = orientation
    warp.is_warp_in = false
    warp.ship_size = ship_size
    warp.ship_class = ship_class
    
    # Set up warp effect based on ship class
    setup_warp_effect(warp)
    
    add_child(warp)
    return warp

# Set up warp effect properties
func setup_warp_effect(warp: WarpEffect) -> void:
    # Scale effect based on ship size
    warp.scale = Vector3.ONE * warp.ship_size * 0.01
    
    # Set appropriate sound effect
    if warp.is_warp_in:
        if warp.ship_size > 100:  # Capital ship
            warp.sound = load("res://assets/sounds/warp_in_capital.wav")
        else:
            warp.sound = load("res://assets/sounds/warp_in.wav")
    else:
        if warp.ship_size > 100:  # Capital ship
            warp.sound = load("res://assets/sounds/warp_out_capital.wav")
        else:
            warp.sound = load("res://assets/sounds/warp_out.wav")
```

```gdscript
class_name WarpEffect extends Node3D

var is_warp_in: bool = true
var ship_size: float = 10.0
var ship_class: String = ""
var lifetime: float = 2.35  # WARPHOLE_GROW_TIME from original code
var time_elapsed: float = 0.0
var warp_model: MeshInstance3D
var warp_particles: GPUParticles3D
var warp_light: OmniLight3D
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
    # Set up components
    warp_model = $WarpModel
    warp_particles = $WarpParticles
    warp_light = $WarpLight
    audio_player = $AudioStreamPlayer3D
    
    # Start animation and sound
    if is_warp_in:
        $AnimationPlayer.play("warp_in")
    else:
        $AnimationPlayer.play("warp_out")
    
    audio_player.play()

func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Update effect size based on time
    var t = time_elapsed
    var radius = ship_size
    
    if is_warp_in:
        if t < lifetime:
            radius = pow(t / lifetime, 0.4) * ship_size
        else:
            radius = ship_size
    else:
        if t < lifetime:
            radius = ship_size
        else:
            radius = pow((2 * lifetime - t) / lifetime, 0.4) * ship_size
    
    warp_model.scale = Vector3.ONE * radius / ship_size
    
    # Remove effect when complete
    if time_elapsed >= 2 * lifetime:
        queue_free()
```

## 6. Jump Node System

### Original Implementation

The jump node system in the original codebase:
- Represents interstellar travel points in missions
- Manages visual representation of jump nodes
- Handles ship entry/exit through jump nodes
- Supports different jump node models and effects
- Provides detection for when ships enter jump nodes
- Uses a linked list structure to track all jump nodes in a mission
- Supports customizable display colors and visibility settings
- Includes methods to find jump nodes by name or check if a ship is inside a node
- Implements rendering with optional wireframe mode (show_polys flag)
- Allows for custom model assignment with set_model() function

### Godot Implementation

```gdscript
class_name JumpNode extends Node3D

signal ship_entered(ship: Ship)

@export var node_name: String = "Jump Node"
@export var model_path: String = "res://assets/models/subspacenode.glb"
@export var display_color: Color = Color(0, 1, 0, 1)  # Default green
@export var show_polys: bool = false
@export var hidden: bool = false
@export_flags("Use Display Color", "Show Polys", "Hide", "Special Model") var flags: int = 0

var _model: MeshInstance3D
var _collision_shape: CollisionShape3D
var _area: Area3D

func _ready() -> void:
    # Load model
    var model_scene = load(model_path)
    if model_scene:
        _model = model_scene.instantiate()
        add_child(_model)
        
        # Set up collision area
        _area = Area3D.new()
        _area.collision_layer = 0
        _area.collision_mask = 1  # Ship layer
        add_child(_area)
        
        _collision_shape = CollisionShape3D.new()
        var shape = SphereShape3D.new()
        shape.radius = _calculate_model_radius()
        _collision_shape.shape = shape
        _area.add_child(_collision_shape)
        
        # Connect signals
        _area.connect("body_entered", _on_body_entered)
    
    # Apply visibility settings
    set_hidden(hidden)
    set_display_properties(display_color, show_polys)

func set_model(new_model_path: String, show_model_polys: bool = false) -> void:
    # Remove old model
    if _model:
        _model.queue_free()
    
    # Load new model
    model_path = new_model_path
    show_polys = show_model_polys
    
    var model_scene = load(model_path)
    if model_scene:
        _model = model_scene.instantiate()
        add_child(_model)
        
        # Update collision shape
        var shape = SphereShape3D.new()
        shape.radius = _calculate_model_radius()
        _collision_shape.shape = shape
        
        # Apply visibility settings
        set_display_properties(display_color, show_polys)

func set_display_properties(color: Color, show_model_polys: bool) -> void:
    display_color = color
    show_polys = show_model_polys
    
    if _model:
        # Apply color to model materials
        for i in range(_model.get_surface_override_material_count()):
            var material = _model.get_surface_override_material(i)
            if material:
                material = material.duplicate()
                material.albedo_color = display_color
                _model.set_surface_override_material(i, material)
        
        # Set wireframe mode if not showing polys
        if not show_polys:
            for i in range(_model.get_surface_override_material_count()):
                var material = _model.get_surface_override_material(i)
                if material:
                    material = material.duplicate()
                    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    material.albedo_color.a = 0.7
                    _model.set_surface_override_material(i, material)

func set_hidden(is_hidden: bool) -> void:
    hidden = is_hidden
    visible = !hidden

func _calculate_model_radius() -> float:
    # Calculate radius from model's AABB
    if _model:
        var aabb = _model.get_aabb()
        return aabb.size.length() / 2.0
    return 50.0  # Default radius

func _on_body_entered(body: Node3D) -> void:
    if body is Ship:
        emit_signal("ship_entered", body)
```

```gdscript
class_name JumpNodeManager extends Node

var jump_nodes: Dictionary = {}  # name -> JumpNode

func register_jump_node(node: JumpNode) -> void:
    jump_nodes[node.node_name] = node

func unregister_jump_node(node: JumpNode) -> void:
    if jump_nodes.has(node.node_name):
        jump_nodes.erase(node.node_name)

func get_jump_node_by_name(name: String) -> JumpNode:
    if jump_nodes.has(name):
        return jump_nodes[name]
    return null

func get_jump_node_for_ship(ship: Ship) -> JumpNode:
    # Check if ship is inside any jump node
    for node_name in jump_nodes:
        var node = jump_nodes[node_name]
        var distance = ship.global_position.distance_to(node.global_position)
        var radius = node._calculate_model_radius()
        
        if distance <= radius:
            return node
    
    return null
```

## 7. Lighting System

### Original Implementation

The lighting system in the original codebase:
- Manages different types of light sources (directional, point, tube)
- Supports dynamic lighting with intensity and color
- Handles light attenuation and falloff
- Provides ambient and reflective lighting
- Supports specular highlights
- Includes light filtering for performance optimization
- Uses two lighting modes: LM_BRIGHTEN (additive) and LM_DARKEN (subtractive)
- Defines default ambient light (0.15) and reflective light (0.75) values
- Implements a light rotation system for proper orientation in the game world
- Supports special light effects for shockwaves and weapon impacts
- Includes performance optimizations like light filtering by distance and relevance
- Provides RGB and specular color control for all light types
- Implements light attenuation with inner and outer radius parameters

### Godot Implementation

```gdscript
class_name SpaceLightingManager extends Node

# Lighting constants
const AMBIENT_LIGHT_DEFAULT: float = 0.15
const REFLECTIVE_LIGHT_DEFAULT: float = 0.75
const LM_BRIGHTEN: int = 0
const LM_DARKEN: int = 1

# Lighting properties
var ambient_light: float = AMBIENT_LIGHT_DEFAULT
var reflective_light: float = REFLECTIVE_LIGHT_DEFAULT
var lighting_enabled: bool = true
var dynamic_lighting_enabled: bool = true

# Light arrays
var directional_lights: Array[SpaceDirectionalLight] = []
var point_lights: Array[SpacePointLight] = []
var tube_lights: Array[SpaceTubeLight] = []

# Environment
var environment: Environment

func _ready() -> void:
    # Create default environment
    environment = Environment.new()
    environment.ambient_light_color = Color(ambient_light, ambient_light, ambient_light)
    environment.ambient_light_energy = 1.0
    
    # Set up default directional light (sun)
    add_directional_light(Vector3(0.5, -0.7, 0.2), 1.0, Color(1.0, 0.9, 0.7))

func add_directional_light(direction: Vector3, intensity: float, color: Color, specular_color: Color = Color.WHITE) -> SpaceDirectionalLight:
    var light = SpaceDirectionalLight.new()
    light.direction = direction.normalized()
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    
    # Create Godot DirectionalLight3D
    var godot_light = DirectionalLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.light_specular = 0.5
    godot_light.global_transform.basis = Basis(Quaternion.from_euler(Vector3(0, 0, 0)).looking_at(direction))
    
    light.godot_light = godot_light
    add_child(godot_light)
    
    directional_lights.append(light)
    return light

func add_point_light(position: Vector3, inner_radius: float, outer_radius: float, 
                    intensity: float, color: Color, ignore_object_id: int = -1,
                    specular_color: Color = Color.WHITE) -> SpacePointLight:
    var light = SpacePointLight.new()
    light.position = position
    light.inner_radius = inner_radius
    light.outer_radius = outer_radius
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    light.ignore_object_id = ignore_object_id
    
    # Create Godot OmniLight3D
    var godot_light = OmniLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.omni_range = outer_radius
    godot_light.omni_attenuation = 1.0
    godot_light.global_position = position
    
    light.godot_light = godot_light
    add_child(godot_light)
    
    point_lights.append(light)
    return light

func add_tube_light(start_pos: Vector3, end_pos: Vector3, inner_radius: float, outer_radius: float,
                   intensity: float, color: Color, affected_object_id: int = -1,
                   specular_color: Color = Color.WHITE) -> SpaceTubeLight:
    var light = SpaceTubeLight.new()
    light.start_position = start_pos
    light.end_position = end_pos
    light.inner_radius = inner_radius
    light.outer_radius = outer_radius
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    light.affected_object_id = affected_object_id
    
    # Create multiple Godot OmniLight3D to simulate tube
    var center_pos = (start_pos + end_pos) / 2.0
    var length = start_pos.distance_to(end_pos)
    var num_segments = max(1, floor(length / (inner_radius * 2)))
    
    for i in range(num_segments):
        var t = float(i) / float(num_segments - 1 if num_segments > 1 else 1)
        var pos = start_pos.lerp(end_pos, t)
        
        var godot_light = OmniLight3D.new()
        godot_light.light_color = color
        godot_light.light_energy = intensity / num_segments
        godot_light.omni_range = outer_radius
        godot_light.omni_attenuation = 1.0
        godot_light.global_position = pos
        
        add_child(godot_light)
        light.godot_lights.append(godot_light)
    
    tube_lights.append(light)
    return light

func set_ambient_light(value: float) -> void:
    ambient_light = clamp(value, 0.0, 1.0)
    environment.ambient_light_color = Color(ambient_light, ambient_light, ambient_light)

func set_reflective_light(value: float) -> void:
    reflective_light = clamp(value, 0.0, 1.0)
    # Update all materials to use new reflective light value
    # This would affect the specular intensity of materials

func set_lighting_enabled(enabled: bool) -> void:
    lighting_enabled = enabled
    for light in directional_lights:
        if light.godot_light:
            light.godot_light.visible = enabled
    
    for light in point_lights:
        if light.godot_light:
            light.godot_light.visible = enabled
    
    for light in tube_lights:
        for godot_light in light.godot_lights:
            godot_light.visible = enabled

func reset_to_defaults() -> void:
    set_ambient_light(AMBIENT_LIGHT_DEFAULT)
    set_reflective_light(REFLECTIVE_LIGHT_DEFAULT)
    lighting_enabled = true
    dynamic_lighting_enabled = true
```

```gdscript
class_name SpaceDirectionalLight extends Resource

var direction: Vector3
var intensity: float
var light_color: Color
var specular_color: Color
var godot_light: DirectionalLight3D

func _init() -> void:
    direction = Vector3(0, -1, 0)
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    godot_light = null
```

```gdscript
class_name SpacePointLight extends Resource

var position: Vector3
var inner_radius: float
var outer_radius: float
var intensity: float
var light_color: Color
var specular_color: Color
var ignore_object_id: int
var godot_light: OmniLight3D

func _init() -> void:
    position = Vector3.ZERO
    inner_radius = 10.0
    outer_radius = 50.0
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    ignore_object_id = -1
    godot_light = null
```

```gdscript
class_name SpaceTubeLight extends Resource

var start_position: Vector3
var end_position: Vector3
var inner_radius: float
var outer_radius: float
var intensity: float
var light_color: Color
var specular_color: Color
var affected_object_id: int
var godot_lights: Array[OmniLight3D]

func _init() -> void:
    start_position = Vector3.ZERO
    end_position = Vector3(0, 0, 10)
    inner_radius = 10.0
    outer_radius = 50.0
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    affected_object_id = -1
    godot_lights = []
```

## 8. Nebula System

### Original Implementation

The nebula system in the original codebase:
- Creates volumetric fog effects for space environments
- Supports different nebula types and densities
- Handles dynamic fog color and intensity
- Includes lightning effects within nebulae
- Manages performance optimization for nebula rendering
- Supports AWACS gameplay mechanics (radar interference)
- Uses a cube-based system for nebula rendering with configurable slices
- Implements a "poof" system for nebula cloud elements with rotation and alpha effects
- Supports multiple nebula bitmap types loaded from nebula.tbl
- Includes dynamic fog color calculation based on texture analysis
- Features a detail level system with configurable parameters for different performance levels
- Implements special rendering for HTL (Hardware Transform & Lighting) mode
- Provides fog distance calculations for different ship types
- Includes a lightning storm system with configurable parameters
- Uses a cube-based system for nebula rendering with configurable slices
- Implements a "poof" system for nebula cloud elements with rotation and alpha effects
- Supports multiple nebula bitmap types loaded from nebula.tbl
- Includes dynamic fog color calculation based on texture analysis
- Features a detail level system with configurable parameters for different performance levels
- Implements special rendering for HTL (Hardware Transform & Lighting) mode
- Provides fog distance calculations for different ship types
- Includes a lightning storm system with configurable parameters

### Godot Implementation

```gdscript
class_name NebulaManager extends Node3D

signal lightning_created(position: Vector3, target: Vector3)

# Nebula properties
@export var enabled: bool = false
@export var fog_color: Color = Color(0.12, 0.2, 0.61)  # Default blue nebula
@export var fog_density: float = 0.02
@export var fog_height: float = 1000.0
@export var fog_falloff: float = 1.0
@export var slices: int = 5
@export var render_mode: int = 0  # 0=None, 1=Poly, 2=POF, 3=Lame, 4=HTL
@export var awacs_factor: float = -1.0  # -1.0 means disabled
@export_range(0, 5) var detail_level: int = 3

# Nebula detail settings
var detail_settings: Array[Dictionary] = [
    {
        "max_alpha": 0.575,
        "break_alpha": 0.13,
        "break_x": 150.0,
        "break_y": 112.5,
        "cube_dim": 510.0,
        "cube_inner": 50.0,
        "cube_outer": 250.0,
        "prad": 120.0
    },
    # Additional detail levels would be defined here
]

# Nebula storm system
class_name NebulaStorm extends Resource
var name: String = ""
var bolt_types: Array[int] = []
var flavor: Vector3 = Vector3.ZERO
var min_time: int = 750
var max_time: int = 10000
var min_count: int = 1
var max_count: int = 3

# Add a new section for Physics Engine before "Integration with Other Systems"

## 9. Physics Engine

### Original Implementation

The physics engine in the original codebase:
- Implements Newtonian physics for ship movement and rotation
- Supports different physics modes including normal flight, glide, and special warp
- Handles ship rotation with damping and maximum rotation limits
- Implements velocity ramping for smooth acceleration and deceleration
- Provides functions for applying external forces (whack, shock)
- Supports special physics flags for different movement states
- Includes reduced damping system for impacts and weapon hits
- Implements afterburner and booster physics
- Provides functions for physics prediction and simulation
- Includes a control system for translating player input to physics forces
- Supports special movement modes like dead-drift and slide

### Godot Implementation

```gdscript
class_name SpacePhysics extends Node

# Physics constants
const MAX_TURN_LIMIT: float = 0.2618
const ROTVEL_TOL: float = 0.1
const ROTVEL_CAP: float = 14.0
const DEAD_ROTVEL_CAP: float = 16.3
const MAX_SHIP_SPEED: float = 500.0
const RESET_SHIP_SPEED: float = 440.0
const SW_ROT_FACTOR: float = 5.0
const SW_BLAST_DURATION: int = 2000
const REDUCED_DAMP_FACTOR: float = 10.0
const REDUCED_DAMP_VEL: float = 30.0
const REDUCED_DAMP_TIME: int = 2000
const WEAPON_SHAKE_TIME: int = 500
const SPECIAL_WARP_T_CONST: float = 0.651

# Physics flags
enum PhysicsFlags {
    ACCELERATES = 1 << 1,
    USE_VEL = 1 << 2,
    AFTERBURNER_ON = 1 << 3,
    SLIDE_ENABLED = 1 << 4,
    REDUCED_DAMP = 1 << 5,
    IN_SHOCKWAVE = 1 << 6,
    DEAD_DAMP = 1 << 7,
    AFTERBURNER_WAIT = 1 << 8,
    CONST_VEL = 1 << 9,
    WARP_IN = 1 << 10,
    SPECIAL_WARP_IN = 1 << 11,
    WARP_OUT = 1 << 12,
    SPECIAL_WARP_OUT = 1 << 13,
    BOOSTER_ON = 1 << 14,
    GLIDING = 1 << 15
}

# Apply physics to a ship
func simulate_physics(ship: ShipBase, delta: float) -> void:
    # Skip if physics is paused
    if physics_paused:
        return
        
    # Apply velocity changes
    simulate_velocity(ship, delta)
    
    # Apply rotation changes
    simulate_rotation(ship, delta)
    
    # Update ship speed values
    ship.physics.speed = ship.physics.velocity.length()
    ship.physics.forward_speed = ship.physics.velocity.dot(ship.global_transform.basis.z)

# Apply velocity changes
func simulate_velocity(ship: ShipBase, delta: float) -> void:
    var local_velocity = ship.global_transform.basis.inverse() * ship.physics.velocity
    var local_desired_velocity = ship.global_transform.basis.inverse() * ship.physics.desired_velocity
    var damping = Vector3(
        ship.physics.side_slip_time_const,
        ship.physics.side_slip_time_const,
        ship.physics.side_slip_time_const if ship.physics.use_newtonian_damp else 0.0
    )
    
    # Apply reduced damping if active
    if ship.physics.flags & PhysicsFlags.REDUCED_DAMP:
        # Calculate reduced damping factor based on time remaining
        pass
        
    # Apply physics to each axis
    var local_displacement = Vector3.ZERO
    var local_new_velocity = Vector3.ZERO
    
    # X-axis
    apply_physics(
        damping.x, 
        local_desired_velocity.x, 
        local_velocity.x, 
        delta, 
        local_new_velocity.x, 
        local_displacement.x
    )
    
    # Y-axis
    apply_physics(
        damping.y, 
        local_desired_velocity.y, 
        local_velocity.y, 
        delta, 
        local_new_velocity.y, 
        local_displacement.y
    )
    
    # Z-axis (with special warp handling)
    if ship.physics.flags & PhysicsFlags.SPECIAL_WARP_IN:
        # Special warp-in physics
        pass
    elif ship.physics.flags & PhysicsFlags.SPECIAL_WARP_OUT:
        # Special warp-out physics
        pass
    else:
        apply_physics(
            damping.z, 
            local_desired_velocity.z, 
            local_velocity.z, 
            delta, 
            local_new_velocity.z, 
            local_displacement.z
        )
    
    # Convert local displacement to world space
    var world_displacement = ship.global_transform.basis * local_displacement
    
    # Apply displacement to ship position
    ship.global_position += world_displacement
    
    # Update ship velocity
    ship.physics.velocity = ship.global_transform.basis * local_new_velocity

# Apply rotation changes
func simulate_rotation(ship: ShipBase, delta: float) -> void:
    var new_rotational_velocity = Vector3.ZERO
    var rotational_damping = ship.physics.rotational_damping
    
    # Apply shockwave effects if active
    if ship.physics.flags & PhysicsFlags.IN_SHOCKWAVE:
        # Calculate shock fraction and adjust damping
        pass
    
    # Apply physics to each rotation axis
    apply_physics(
        rotational_damping,
        ship.physics.desired_rotational_velocity.x,
        ship.physics.rotational_velocity.x,
        delta,
        new_rotational_velocity.x,
        null
    )
    
    apply_physics(
        rotational_damping,
        ship.physics.desired_rotational_velocity.y,
        ship.physics.rotational_velocity.y,
        delta,
        new_rotational_velocity.y,
        null
    )
    
    apply_physics(
        rotational_damping,
        ship.physics.desired_rotational_velocity.z,
        ship.physics.rotational_velocity.z,
        delta,
        new_rotational_velocity.z,
        null
    )
    
    # Update ship rotational velocity
    ship.physics.rotational_velocity = new_rotational_velocity
    
    # Calculate rotation angles
    var angles = Vector3(
        ship.physics.rotational_velocity.x * delta,
        ship.physics.rotational_velocity.y * delta,
        ship.physics.rotational_velocity.z * delta
    )
    
    # Apply rotation to ship
    ship.rotate_object_local(Vector3.RIGHT, angles.x)
    ship.rotate_object_local(Vector3.UP, angles.y)
    ship.rotate_object_local(Vector3.FORWARD, angles.z)
    
    # Ensure the basis stays orthogonal
    ship.global_transform.basis = ship.global_transform.basis.orthonormalized()

# Apply physics formula to calculate new velocity and displacement
func apply_physics(damping: float, desired_vel: float, initial_vel: float, 
                  delta: float, new_vel: float, delta_pos: float) -> void:
    if damping < 0.0001:
        if delta_pos != null:
            delta_pos = desired_vel * delta
        if new_vel != null:
            new_vel = desired_vel
    else:
        var dv = initial_vel - desired_vel
        var e = exp(-delta / damping)
        if delta_pos != null:
            delta_pos = (1.0 - e) * dv * damping + desired_vel * delta
        if new_vel != null:
            new_vel = dv * e + desired_vel
```

## 10. Particle System

### Original Implementation

The particle system in the original codebase:
- Provides a general-purpose particle effect framework
- Supports different particle types (bitmap, fire, smoke, debug, etc.)
- Manages particle creation, movement, and rendering
- Handles particle lifetime and aging
- Supports particle attachment to objects
- Includes particle emitters for continuous effects
- Implements performance optimizations like culling and batching
- Provides particle animation through frame sequences
- Supports different rendering modes and alpha blending
- Includes tracer effects for projectiles

### Godot Implementation

```gdscript
class_name ParticleManager extends Node

# Particle type constants
enum ParticleType {
    DEBUG,
    BITMAP,
    FIRE,
    SMOKE,
    SMOKE2,
    BITMAP_PERSISTENT,
    BITMAP_3D
}

# Particle system configuration
var particles_enabled: bool = true
var max_particles: int = 2000
var particles: Array[Particle] = []

# Preloaded particle resources
var fire_animation: AnimatedTexture
var smoke_animation: AnimatedTexture
var smoke2_animation: AnimatedTexture

func _ready() -> void:
    # Load particle animations
    fire_animation = load("res://assets/effects/particleexp01.tres")
    smoke_animation = load("res://assets/effects/particlesmoke01.tres")
    smoke2_animation = load("res://assets/effects/particlesmoke02.tres")

# Create a particle with detailed parameters
func create_particle(info: ParticleInfo) -> void:
    if not particles_enabled or particles.size() >= max_particles:
        return
        
    var particle = Particle.new()
    particle.position = info.position
    particle.normal = info.normal
    particle.velocity = info.velocity
    particle.age = 0.0
    particle.max_life = info.lifetime
    particle.radius = info.radius
    particle.type = info.type
    particle.optional_data = info.optional_data
    particle.color = info.color
    particle.tracer_length = info.tracer_length
    particle.attached_objnum = info.attached_objnum
    particle.attached_sig = info.attached_sig
    particle.reverse = info.reverse
    
    # Set up animation frames based on type
    match info.type:
        ParticleType.FIRE:
            particle.optional_data = fire_animation.get_instance_id()
            particle.nframes = fire_animation.frames
        ParticleType.SMOKE:
            particle.optional_data = smoke_animation.get_instance_id()
            particle.nframes = smoke_animation.frames
        ParticleType.SMOKE2:
            particle.optional_data = smoke2_animation.get_instance_id()
            particle.nframes = smoke2_animation.frames
        ParticleType.BITMAP, ParticleType.BITMAP_PERSISTENT, ParticleType.BITMAP_3D:
            if info.optional_data >= 0:
                var texture = instance_from_id(info.optional_data)
                if texture is AnimatedTexture:
                    particle.nframes = texture.frames
                    if particle.nframes > 1:
                        particle.max_life = float(particle.nframes) / 30.0  # Assuming 30fps
    
    particles.append(particle)

# Create a particle with simplified parameters
func create_particle_simple(position: Vector3, velocity: Vector3, lifetime: float, 
                           radius: float, type: int, optional_data: int = -1,
                           tracer_length: float = -1.0, attached_obj = null, 
                           reverse: bool = false) -> void:
    var info = ParticleInfo.new()
    info.position = position
    info.normal = Vector3.FORWARD  # Default normal
    info.velocity = velocity
    info.lifetime = lifetime
    info.radius = radius
    info.type = type
    info.optional_data = optional_data
    info.color = Color(1, 1, 1)  # Default white
    info.tracer_length = tracer_length
    
    if attached_obj:
        info.attached_objnum = attached_obj.get_instance_id()
        info.attached_sig = attached_obj.signature
    else:
        info.attached_objnum = -1
        info.attached_sig = -1
        
    info.reverse = reverse
    
    create_particle(info)

# Update all particles
func _process(delta: float) -> void:
    if not particles_enabled:
        return
        
    # Process particles in reverse to safely remove them
    for i in range(particles.size() - 1, -1, -1):
        var p = particles[i]
        
        # Age the particle
        if p.age == 0.0:
            p.age = 0.00001
        else:
            p.age += delta
            
        # Check if particle has expired
        if p.age > p.max_life:
            particles.remove_at(i)
            continue
            
        # Check if attached object still exists
        if p.attached_objnum >= 0:
            var obj = instance_from_id(p.attached_objnum)
            if not is_instance_valid(obj) or obj.signature != p.attached_sig:
                particles.remove_at(i)
                continue
        else:
            # Move unattached particles
            p.position += p.velocity * delta

# Render all particles
func _render_particles() -> void:
    if not particles_enabled or particles.empty():
        return
        
    # Set up rendering batch
    var render_batch = false
    
    for p in particles:
        var position = p.position
        
        # If attached to an object, transform position
        if p.attached_objnum >= 0:
            var obj = instance_from_id(p.attached_objnum)
            if is_instance_valid(obj):
                # Transform position based on object
                pass
                
        # Calculate alpha based on distance and age
        var alpha = calculate_particle_alpha(position, p.age / p.max_life)
        
        # Skip if not visible
        if alpha <= 0.0:
            continue
            
        # Calculate current frame for animated particles
        var frame = 0
        if p.nframes > 1:
            var pct_complete = p.age / p.max_life
            frame = int(pct_complete * p.nframes + 0.5)
            frame = clamp(frame, 0, p.nframes - 1)
            if p.reverse:
                frame = p.nframes - frame - 1
                
        # Render based on particle type
        match p.type:
            ParticleType.DEBUG:
                # Debug rendering
                pass
            ParticleType.BITMAP_3D:
                # 3D billboard with normal
                pass
            _:  # Standard particles
                # Add to batch for efficient rendering
                render_batch = true
                
    # Render batched particles
    if render_batch:
        # Batch rendering code
        pass

# Create a particle emitter
class_name ParticleEmitter extends Node3D

@export var num_low: int = 1
@export var num_high: int = 5
@export var min_life: float = 1.0
@export var max_life: float = 3.0
@export var normal: Vector3 = Vector3.UP
@export var normal_variance: float = 0.5
@export var min_velocity: float = 1.0
@export var max_velocity: float = 5.0
@export var min_radius: float = 0.5
@export var max_radius: float = 2.0

# Emit particles
func emit(type: int, optional_data: int, range: float = 1.0) -> void:
    if not ParticleManager.particles_enabled:
        return
        
    # Calculate number of particles based on detail level
    var percent = get_detail_percent()
    
    # Adjust based on distance from camera
    var min_dist = 125.0
    var dist = global_position.distance_to(get_viewport().get_camera_3d().global_position) / range
    if dist > min_dist:
        percent = int(float(percent) * min_dist / dist)
        if percent < 1:
            return
            
    var n1 = (num_low * percent) / 100
    var n2 = (num_high * percent) / 100
    var n = (randi() % (n2 - n1 + 1)) + n1
    
    if n < 1:
        return
        
    # Create particles
    for i in range(n):
        var particle_normal = Vector3(
            normal.x + (randf() * 2.0 - 1.0) * normal_variance,
            normal.y + (randf() * 2.0 - 1.0) * normal_variance,
            normal.z + (randf() * 2.0 - 1.0) * normal_variance
        ).normalized()
        
        var radius = ((max_radius - min_radius) * randf()) + min_radius
        var speed = ((max_velocity - min_velocity) * randf()) + min_velocity
        var life = ((max_life - min_life) * randf()) + min_life
        
        var velocity = velocity + particle_normal * speed
        
        ParticleManager.create_particle_simple(
            global_position,
            velocity,
            life,
            radius,
            type,
            optional_data
        )
```

## 11. Starfield System

### Original Implementation

The starfield system in the original codebase:
- Renders a dynamic starfield background with thousands of stars
- Supports star movement with tail effects based on camera movement
- Manages star colors, brightness, and density
- Includes a bitmap-based starfield for more detailed backgrounds
- Supports multiple background layers with parallax effects
- Handles loading and management of sun bitmaps with glow effects
- Implements lens flare effects for suns
- Provides a system for loading and managing starfield bitmaps from tables
- Supports different star rendering modes (points, tails, anti-aliased)
- Includes configurable star parameters (amount, dimming, cap, length)
- Manages star movement and camera cuts
- Implements background model rendering for skyboxes
- Supports dynamic environment changes

### Godot Implementation

```gdscript
class_name StarfieldManager extends Node3D

# Starfield configuration
@export var num_stars: int = 500
@export var star_amount: float = 0.75  # Tail effect amount
@export var star_dim: float = 7800.0   # Dimming rate
@export var star_cap: float = 75.0     # Minimum brightness
@export var star_max_length: float = 0.04
@export_flags("Tail", "Dim", "Antialias") var star_flags: int = 3  # Default: Tail + Dim
@export var background_model_path: String = ""
@export var background_texture_path: String = ""

# Star arrays
var stars: Array[Star] = []
var star_colors: Array[Color] = []
var star_aa_colors: Array[Color] = []  # Anti-aliased colors

# Background bitmaps
var starfield_bitmaps: Array[StarfieldBitmap] = []
var starfield_instances: Array[StarfieldBitmapInstance] = []
var sun_bitmaps: Array[StarfieldBitmap] = []
var suns: Array[StarfieldBitmapInstance] = []

func _ready() -> void:
    # Initialize star colors
    for i in range(8):
        var intensity = (i + 1) * 24
        star_colors.append(Color(intensity/255.0, intensity/255.0, intensity/255.0))
        star_aa_colors.append(Color(1.0, 1.0, 1.0, intensity/255.0))
    
    # Generate stars
    generate_stars()
    
    # Load starfield bitmaps from configuration
    load_starfield_bitmaps("res://resources/stars.tbl") # Path to your starfield table file
    
    # Set up background model if specified
    setup_background_model(background_model_path, background_texture_path)

func generate_stars() -> void:
    stars.clear()
    
    for i in range(num_stars):
        var star = Star.new()
        
        # Generate random position on unit sphere
        var v = Vector3(
            randf_range(-1.0, 1.0),
            randf_range(-1.0, 1.0),
            randf_range(-1.0, 1.0)
        )
        while v.length_squared() >= 1.0:
            v = Vector3(
                randf_range(-1.0, 1.0),
                randf_range(-1.0, 1.0),
                randf_range(-1.0, 1.0)
            )
        
        star.position = v.normalized() * 1000.0
        star.last_position = star.position
        
        # Random color
        var red = randf_range(192, 255)
        var green = randf_range(192, 255)
        var blue = randf_range(192, 255)
        var alpha = randf_range(24, 216)
        star.color = Color(red/255.0, green/255.0, blue/255.0, alpha/255.0)
        
        stars.append(star)

func _process(delta: float) -> void:
    # Update star positions based on camera movement
    update_stars()
    
    # Update sun positions and lens flares
    update_suns()

func update_stars() -> void:
    var camera = get_viewport().get_camera_3d()
    if not camera:
        return
    
    # Transform stars to camera space
    for star in stars:
        var p = camera.global_transform.basis.inverse() * (star.position - camera.global_position)
        
        # Skip stars behind the camera
        if p.z <= 0:
            continue
        
        # Project to screen space
        var screen_pos = camera.unproject_position(star.position)
        
        # Calculate tail effect if enabled
        if star_flags & 1:  # STAR_FLAG_TAIL
            var last_p = camera.global_transform.basis.inverse() * (star.last_position - camera.global_position)
            if last_p.z > 0:
                var last_screen_pos = camera.unproject_position(star.last_position)
                var dist = screen_pos.distance_to(last_screen_pos)
                
                # Apply tail effect
                if dist > 0:
                    # Draw line from last position to current
                    if dist > star_max_length:
                        var ratio = star_max_length / dist
                        dist = star_max_length
                        last_screen_pos = screen_pos.lerp(last_screen_pos, ratio * star_amount)
                    
                    # Apply dimming if enabled
                    if star_flags & 2:  # STAR_FLAG_DIM
                        var color_factor = 255.0 - dist * star_dim
                        if color_factor < star_cap:
                            color_factor = star_cap
                        
                        # Draw star with appropriate
# Physics and Space Environment Systems

This document outlines the physics and space environment systems from the original Wing Commander Saga codebase and how they should be implemented in Godot.

## Overview

The physics and space environment systems in Wing Commander Saga include:

1. **Asteroid Field System** - Generation and management of asteroid fields
2. **Debris System** - Creation and management of ship debris after destruction
3. **Fireball/Explosion System** - Visual effects for explosions and weapon impacts
4. **Decal System** - Visual effects applied to ship surfaces (impacts, damage)
5. **Warp Effects** - Visual effects for ship warping in/out of a scene
6. **Jump Node System** - Interstellar travel points for mission transitions
7. **Lighting System** - Dynamic lighting for space environments
8. **Nebula System** - Volumetric fog and environmental effects
9. **Physics Engine** - Ship movement and collision physics
10. **Particle System** - General-purpose particle effects
11. **Starfield System** - Background star rendering and management
12. **Supernova Effects** - Special effects for supernova events

These systems are primarily visual but also have gameplay implications through collision detection and damage application.

## 1. Asteroid Field System

### Original Implementation

The asteroid system in the original codebase:
- Manages asteroid fields with configurable density, size, and movement
- Supports different asteroid types and models
- Handles asteroid collisions with ships and weapons
- Includes asteroid wrapping within defined boundaries
- Supports asteroid breaking into smaller pieces when destroyed

### Godot Implementation

```gdscript
class_name AsteroidField extends Node3D

signal asteroid_destroyed(asteroid: Asteroid, position: Vector3)

@export var field_size: Vector3 = Vector3(10000, 5000, 10000)
@export var inner_bound_size: Vector3 = Vector3.ZERO  # If non-zero, creates a hollow center
@export var num_asteroids: int = 100
@export var asteroid_types: Array[AsteroidType] = []
@export var field_speed: float = 10.0
@export var field_direction: Vector3 = Vector3.FORWARD
@export var wrap_asteroids: bool = true

# Asteroid field generation
func generate_field() -> void:
    # Create asteroid instances based on field parameters
    # Position them randomly within field boundaries
    # Apply initial velocities
    pass

# Asteroid wrapping logic
func _process(delta: float) -> void:
    # Check if asteroids have left the field boundaries
    # Wrap them to the opposite side if needed
    pass
```

```gdscript
class_name Asteroid extends RigidBody3D

signal asteroid_hit(damage: float, hit_position: Vector3)

@export var asteroid_type: AsteroidType
@export var size_class: int  # 0=small, 1=medium, 2=large
@export var health: float = 100.0
@export var debris_on_destroy: bool = true

# Handle collision with ships and weapons
func _on_body_entered(body: Node) -> void:
    if body is Ship or body is Projectile:
        apply_damage(body.get_impact_damage(), body.global_position)

# Apply damage and potentially break apart
func apply_damage(damage: float, hit_position: Vector3) -> void:
    health -= damage
    if health <= 0:
        destroy(hit_position)
    
# Break into smaller pieces when destroyed
func destroy(hit_position: Vector3) -> void:
    if size_class > 0 and debris_on_destroy:
        spawn_smaller_asteroids(hit_position)
    
    # Create explosion effect
    var explosion = ExplosionManager.create_explosion(
        global_position, 
        "asteroid", 
        size_class
    )
    
    queue_free()
```

## 2. Debris System

### Original Implementation

The debris system in the original codebase:
- Creates debris pieces when ships are destroyed
- Supports hull debris (large pieces) and small debris
- Applies physics to debris (rotation, velocity)
- Manages debris lifetime and cleanup
- Handles debris collisions with ships

### Godot Implementation

```gdscript
class_name DebrisManager extends Node

# Configuration
var max_debris_pieces: int = 200
var max_debris_distance: float = 10000.0
var debris_check_interval: float = 10.0  # seconds

# Create debris from destroyed ship
func create_ship_debris(ship: Ship, explosion_center: Vector3, explosion_force: float) -> void:
    var ship_model = ship.get_model()
    var ship_size = ship.get_size_class()
    
    # Create hull debris (large pieces)
    var num_hull_pieces = min(ship_size * 2, 8)
    for i in range(num_hull_pieces):
        create_hull_debris(ship, ship_model, explosion_center, explosion_force)
    
    # Create small debris
    var num_small_pieces = min(ship_size * 10, 30)
    for i in range(num_small_pieces):
        create_small_debris(ship, explosion_center, explosion_force)

# Create a large hull piece
func create_hull_debris(ship: Ship, model: ShipModel, explosion_center: Vector3, explosion_force: float) -> DebrisHull:
    var debris = DebrisHull.new()
    # Set up debris properties based on ship model
    # Apply physics (velocity, rotation)
    # Set lifetime based on ship size
    return debris

# Create small generic debris
func create_small_debris(ship: Ship, explosion_center: Vector3, explosion_force: float) -> DebrisSmall:
    var debris = DebrisSmall.new()
    # Set up debris properties
    # Apply physics (velocity, rotation)
    # Set shorter lifetime
    return debris
    
# Clean up distant debris
func _on_cleanup_timer_timeout() -> void:
    # Check distance of all debris from player
    # Remove debris that is too far away
    pass
```

```gdscript
class_name DebrisBase extends RigidBody3D

var source_ship_type: String
var lifetime: float = 10.0
var time_elapsed: float = 0.0
var must_survive_until: float = 0.0  # Minimum survival time

func _process(delta: float) -> void:
    time_elapsed += delta
    if time_elapsed > lifetime and time_elapsed > must_survive_until:
        queue_free()
```

```gdscript
class_name DebrisHull extends DebrisBase

var ship_model_part: MeshInstance3D
var can_damage_ships: bool = true
var damage_multiplier: float = 1.0

func _on_body_entered(body: Node) -> void:
    if body is Ship and can_damage_ships:
        var impact_velocity = linear_velocity.length()
        var damage = impact_velocity * mass * 0.01 * damage_multiplier
        body.apply_damage(damage, global_position)
```

## 3. Fireball/Explosion System

### Original Implementation

The fireball system in the original codebase:
- Manages different types of explosion effects
- Supports various sizes and visual styles
- Handles animation playback and timing
- Includes specialized effects like warp-in/out explosions
- Manages sound effects for explosions

### Godot Implementation

```gdscript
class_name ExplosionManager extends Node

# Explosion type constants
enum ExplosionType {
    SMALL,
    MEDIUM,
    LARGE,
    ASTEROID,
    WARP,
    KNOSSOS
}

# Create an explosion at a position
func create_explosion(position: Vector3, type: ExplosionType, parent_obj = null, size_scale: float = 1.0) -> Explosion:
    var explosion = Explosion.new()
    explosion.explosion_type = type
    explosion.global_position = position
    explosion.scale = Vector3.ONE * size_scale
    
    # Set up appropriate animation, sound, and light effects
    setup_explosion_effects(explosion, type)
    
    add_child(explosion)
    return explosion

# Set up explosion effects based on type
func setup_explosion_effects(explosion: Explosion, type: ExplosionType) -> void:
    match type:
        ExplosionType.SMALL:
            explosion.animation = load("res://assets/effects/explosion_small.tscn")
            explosion.sound = load("res://assets/sounds/explosion_small.wav")
            explosion.light_energy = 2.0
            explosion.lifetime = 1.0
        ExplosionType.MEDIUM:
            # Similar setup for medium explosion
            pass
        ExplosionType.LARGE:
            # Similar setup for large explosion
            pass
        ExplosionType.WARP:
            # Special setup for warp effect
            pass
```

```gdscript
class_name Explosion extends Node3D

var explosion_type: ExplosionType
var lifetime: float = 2.0
var time_elapsed: float = 0.0
var animation_player: AnimationPlayer
var light: OmniLight3D
var particles: GPUParticles3D
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
    # Set up components
    animation_player = $AnimationPlayer
    light = $OmniLight3D
    particles = $GPUParticles3D
    audio_player = $AudioStreamPlayer3D
    
    # Start animation and sound
    animation_player.play("explosion")
    audio_player.play()

func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Fade out light over time
    if light:
        light.light_energy = lerp(light.light_energy, 0.0, delta * 2.0)
    
    # Remove explosion when complete
    if time_elapsed >= lifetime:
        queue_free()
```

## 4. Decal System

### Original Implementation

The decal system in the original codebase:
- Applies visual effects to ship surfaces (damage marks, weapon impacts)
- Manages decal lifetime and fading
- Handles decal positioning and orientation on 3D models
- Supports different decal types (burn marks, weapon impacts, etc.)

### Godot Implementation

In Godot, we can use the built-in decal system with some custom management:

```gdscript
class_name DecalManager extends Node

# Decal type constants
enum DecalType {
    WEAPON_IMPACT,
    BURN_MARK,
    SCRATCH,
    EXPLOSION_MARK
}

# Maximum decals per ship
var max_decals_per_ship: int = 20

# Create a decal on a ship surface
func create_decal(position: Vector3, normal: Vector3, size: float, type: DecalType, target_object: Node3D) -> Decal:
    # Check if target has a decal container
    var decal_container = get_decal_container(target_object)
    
    # If too many decals, remove oldest
    if decal_container.get_child_count() >= max_decals_per_ship:
        var oldest_decal = decal_container.get_child(0)
        oldest_decal.queue_free()
    
    # Create new decal
    var decal = Decal.new()
    decal.decal_type = type
    
    # Set up decal properties based on type
    setup_decal_properties(decal, type)
    
    # Position and orient decal
    position_decal(decal, position, normal, size, target_object)
    
    # Add to container
    decal_container.add_child(decal)
    return decal

# Get or create decal container on target
func get_decal_container(target_object: Node3D) -> Node3D:
    if target_object.has_node("DecalContainer"):
        return target_object.get_node("DecalContainer")
    
    var container = Node3D.new()
    container.name = "DecalContainer"
    target_object.add_child(container)
    return container

# Set up decal properties based on type
func setup_decal_properties(decal: Decal, type: DecalType) -> void:
    match type:
        DecalType.WEAPON_IMPACT:
            decal.texture = load("res://assets/decals/weapon_impact.png")
            decal.lifetime = 10.0
        DecalType.BURN_MARK:
            decal.texture = load("res://assets/decals/burn_mark.png")
            decal.lifetime = 30.0
        # Other types...
```

```gdscript
class_name Decal extends Node3D

var decal_type: DecalType
var lifetime: float = 10.0
var time_elapsed: float = 0.0
var fade_time: float = 2.0
var decal_mesh: MeshInstance3D

func _ready() -> void:
    decal_mesh = $DecalMesh
    
func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Fade out decal when nearing end of lifetime
    if time_elapsed > lifetime - fade_time:
        var alpha = (lifetime - time_elapsed) / fade_time
        decal_mesh.material.albedo_color.a = alpha
    
    # Remove when lifetime is over
    if time_elapsed >= lifetime:
        queue_free()
```

## 5. Warp Effects

### Original Implementation

The warp effect system in the original codebase:
- Creates visual effects for ships entering/exiting a scene via warp
- Manages warp-in and warp-out animations
- Handles sound effects for warp events
- Scales effects based on ship size

### Godot Implementation

```gdscript
class_name WarpEffectManager extends Node

# Create a warp-in effect
func create_warp_in(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    var warp = WarpEffect.new()
    warp.global_position = position
    warp.global_transform.basis = orientation
    warp.is_warp_in = true
    warp.ship_size = ship_size
    warp.ship_class = ship_class
    
    # Set up warp effect based on ship class
    setup_warp_effect(warp)
    
    add_child(warp)
    return warp

# Create a warp-out effect
func create_warp_out(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    var warp = WarpEffect.new()
    warp.global_position = position
    warp.global_transform.basis = orientation
    warp.is_warp_in = false
    warp.ship_size = ship_size
    warp.ship_class = ship_class
    
    # Set up warp effect based on ship class
    setup_warp_effect(warp)
    
    add_child(warp)
    return warp

# Set up warp effect properties
func setup_warp_effect(warp: WarpEffect) -> void:
    # Scale effect based on ship size
    warp.scale = Vector3.ONE * warp.ship_size * 0.01
    
    # Set appropriate sound effect
    if warp.is_warp_in:
        if warp.ship_size > 100:  # Capital ship
            warp.sound = load("res://assets/sounds/warp_in_capital.wav")
        else:
            warp.sound = load("res://assets/sounds/warp_in.wav")
    else:
        if warp.ship_size > 100:  # Capital ship
            warp.sound = load("res://assets/sounds/warp_out_capital.wav")
        else:
            warp.sound = load("res://assets/sounds/warp_out.wav")
```

```gdscript
class_name WarpEffect extends Node3D

var is_warp_in: bool = true
var ship_size: float = 10.0
var ship_class: String = ""
var lifetime: float = 2.35  # WARPHOLE_GROW_TIME from original code
var time_elapsed: float = 0.0
var warp_model: MeshInstance3D
var warp_particles: GPUParticles3D
var warp_light: OmniLight3D
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
    # Set up components
    warp_model = $WarpModel
    warp_particles = $WarpParticles
    warp_light = $WarpLight
    audio_player = $AudioStreamPlayer3D
    
    # Start animation and sound
    if is_warp_in:
        $AnimationPlayer.play("warp_in")
    else:
        $AnimationPlayer.play("warp_out")
    
    audio_player.play()

func _process(delta: float) -> void:
    time_elapsed += delta
    
    # Update effect size based on time
    var t = time_elapsed
    var radius = ship_size
    
    if is_warp_in:
        if t < lifetime:
            radius = pow(t / lifetime, 0.4) * ship_size
        else:
            radius = ship_size
    else:
        if t < lifetime:
            radius = ship_size
        else:
            radius = pow((2 * lifetime - t) / lifetime, 0.4) * ship_size
    
    warp_model.scale = Vector3.ONE * radius / ship_size
    
    # Remove effect when complete
    if time_elapsed >= 2 * lifetime:
        queue_free()
```

## 6. Jump Node System

### Original Implementation

The jump node system in the original codebase:
- Represents interstellar travel points in missions
- Manages visual representation of jump nodes
- Handles ship entry/exit through jump nodes
- Supports different jump node models and effects
- Provides detection for when ships enter jump nodes
- Uses a linked list structure to track all jump nodes in a mission
- Supports customizable display colors and visibility settings
- Includes methods to find jump nodes by name or check if a ship is inside a node
- Implements rendering with optional wireframe mode (show_polys flag)
- Allows for custom model assignment with set_model() function

### Godot Implementation

```gdscript
class_name JumpNode extends Node3D

signal ship_entered(ship: Ship)

@export var node_name: String = "Jump Node"
@export var model_path: String = "res://assets/models/subspacenode.glb"
@export var display_color: Color = Color(0, 1, 0, 1)  # Default green
@export var show_polys: bool = false
@export var hidden: bool = false
@export_flags("Use Display Color", "Show Polys", "Hide", "Special Model") var flags: int = 0

var _model: MeshInstance3D
var _collision_shape: CollisionShape3D
var _area: Area3D

func _ready() -> void:
    # Load model
    var model_scene = load(model_path)
    if model_scene:
        _model = model_scene.instantiate()
        add_child(_model)
        
        # Set up collision area
        _area = Area3D.new()
        _area.collision_layer = 0
        _area.collision_mask = 1  # Ship layer
        add_child(_area)
        
        _collision_shape = CollisionShape3D.new()
        var shape = SphereShape3D.new()
        shape.radius = _calculate_model_radius()
        _collision_shape.shape = shape
        _area.add_child(_collision_shape)
        
        # Connect signals
        _area.connect("body_entered", _on_body_entered)
    
    # Apply visibility settings
    set_hidden(hidden)
    set_display_properties(display_color, show_polys)

func set_model(new_model_path: String, show_model_polys: bool = false) -> void:
    # Remove old model
    if _model:
        _model.queue_free()
    
    # Load new model
    model_path = new_model_path
    show_polys = show_model_polys
    
    var model_scene = load(model_path)
    if model_scene:
        _model = model_scene.instantiate()
        add_child(_model)
        
        # Update collision shape
        var shape = SphereShape3D.new()
        shape.radius = _calculate_model_radius()
        _collision_shape.shape = shape
        
        # Apply visibility settings
        set_display_properties(display_color, show_polys)

func set_display_properties(color: Color, show_model_polys: bool) -> void:
    display_color = color
    show_polys = show_model_polys
    
    if _model:
        # Apply color to model materials
        for i in range(_model.get_surface_override_material_count()):
            var material = _model.get_surface_override_material(i)
            if material:
                material = material.duplicate()
                material.albedo_color = display_color
                _model.set_surface_override_material(i, material)
        
        # Set wireframe mode if not showing polys
        if not show_polys:
            for i in range(_model.get_surface_override_material_count()):
                var material = _model.get_surface_override_material(i)
                if material:
                    material = material.duplicate()
                    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    material.albedo_color.a = 0.7
                    _model.set_surface_override_material(i, material)

func set_hidden(is_hidden: bool) -> void:
    hidden = is_hidden
    visible = !hidden

func _calculate_model_radius() -> float:
    # Calculate radius from model's AABB
    if _model:
        var aabb = _model.get_aabb()
        return aabb.size.length() / 2.0
    return 50.0  # Default radius

func _on_body_entered(body: Node3D) -> void:
    if body is Ship:
        emit_signal("ship_entered", body)
```

```gdscript
class_name JumpNodeManager extends Node

var jump_nodes: Dictionary = {}  # name -> JumpNode

func register_jump_node(node: JumpNode) -> void:
    jump_nodes[node.node_name] = node

func unregister_jump_node(node: JumpNode) -> void:
    if jump_nodes.has(node.node_name):
        jump_nodes.erase(node.node_name)

func get_jump_node_by_name(name: String) -> JumpNode:
    if jump_nodes.has(name):
        return jump_nodes[name]
    return null

func get_jump_node_for_ship(ship: Ship) -> JumpNode:
    # Check if ship is inside any jump node
    for node_name in jump_nodes:
        var node = jump_nodes[node_name]
        var distance = ship.global_position.distance_to(node.global_position)
        var radius = node._calculate_model_radius()
        
        if distance <= radius:
            return node
    
    return null
```

## 7. Lighting System

### Original Implementation

The lighting system in the original codebase:
- Manages different types of light sources (directional, point, tube)
- Supports dynamic lighting with intensity and color
- Handles light attenuation and falloff
- Provides ambient and reflective lighting
- Supports specular highlights
- Includes light filtering for performance optimization
- Uses two lighting modes: LM_BRIGHTEN (additive) and LM_DARKEN (subtractive)
- Defines default ambient light (0.15) and reflective light (0.75) values
- Implements a light rotation system for proper orientation in the game world
- Supports special light effects for shockwaves and weapon impacts
- Includes performance optimizations like light filtering by distance and relevance
- Provides RGB and specular color control for all light types
- Implements light attenuation with inner and outer radius parameters

### Godot Implementation

```gdscript
class_name SpaceLightingManager extends Node

# Lighting constants
const AMBIENT_LIGHT_DEFAULT: float = 0.15
const REFLECTIVE_LIGHT_DEFAULT: float = 0.75
const LM_BRIGHTEN: int = 0
const LM_DARKEN: int = 1

# Lighting properties
var ambient_light: float = AMBIENT_LIGHT_DEFAULT
var reflective_light: float = REFLECTIVE_LIGHT_DEFAULT
var lighting_enabled: bool = true
var dynamic_lighting_enabled: bool = true

# Light arrays
var directional_lights: Array[SpaceDirectionalLight] = []
var point_lights: Array[SpacePointLight] = []
var tube_lights: Array[SpaceTubeLight] = []

# Environment
var environment: Environment

func _ready() -> void:
    # Create default environment
    environment = Environment.new()
    environment.ambient_light_color = Color(ambient_light, ambient_light, ambient_light)
    environment.ambient_light_energy = 1.0
    
    # Set up default directional light (sun)
    add_directional_light(Vector3(0.5, -0.7, 0.2), 1.0, Color(1.0, 0.9, 0.7))

func add_directional_light(direction: Vector3, intensity: float, color: Color, specular_color: Color = Color.WHITE) -> SpaceDirectionalLight:
    var light = SpaceDirectionalLight.new()
    light.direction = direction.normalized()
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    
    # Create Godot DirectionalLight3D
    var godot_light = DirectionalLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.light_specular = 0.5
    godot_light.global_transform.basis = Basis(Quaternion.from_euler(Vector3(0, 0, 0)).looking_at(direction))
    
    light.godot_light = godot_light
    add_child(godot_light)
    
    directional_lights.append(light)
    return light

func add_point_light(position: Vector3, inner_radius: float, outer_radius: float, 
                    intensity: float, color: Color, ignore_object_id: int = -1,
                    specular_color: Color = Color.WHITE) -> SpacePointLight:
    var light = SpacePointLight.new()
    light.position = position
    light.inner_radius = inner_radius
    light.outer_radius = outer_radius
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    light.ignore_object_id = ignore_object_id
    
    # Create Godot OmniLight3D
    var godot_light = OmniLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.omni_range = outer_radius
    godot_light.omni_attenuation = 1.0
    godot_light.global_position = position
    
    light.godot_light = godot_light
    add_child(godot_light)
    
    point_lights.append(light)
    return light

func add_tube_light(start_pos: Vector3, end_pos: Vector3, inner_radius: float, outer_radius: float,
                   intensity: float, color: Color, affected_object_id: int = -1,
                   specular_color: Color = Color.WHITE) -> SpaceTubeLight:
    var light = SpaceTubeLight.new()
    light.start_position = start_pos
    light.end_position = end_pos
    light.inner_radius = inner_radius
    light.outer_radius = outer_radius
    light.intensity = intensity
    light.light_color = color
    light.specular_color = specular_color
    light.affected_object_id = affected_object_id
    
    # Create multiple Godot OmniLight3D to simulate tube
    var center_pos = (start_pos + end_pos) / 2.0
    var length = start_pos.distance_to(end_pos)
    var num_segments = max(1, floor(length / (inner_radius * 2)))
    
    for i in range(num_segments):
        var t = float(i) / float(num_segments - 1 if num_segments > 1 else 1)
        var pos = start_pos.lerp(end_pos, t)
        
        var godot_light = OmniLight3D.new()
        godot_light.light_color = color
        godot_light.light_energy = intensity / num_segments
        godot_light.omni_range = outer_radius
        godot_light.omni_attenuation = 1.0
        godot_light.global_position = pos
        
        add_child(godot_light)
        light.godot_lights.append(godot_light)
    
    tube_lights.append(light)
    return light

func set_ambient_light(value: float) -> void:
    ambient_light = clamp(value, 0.0, 1.0)
    environment.ambient_light_color = Color(ambient_light, ambient_light, ambient_light)

func set_reflective_light(value: float) -> void:
    reflective_light = clamp(value, 0.0, 1.0)
    # Update all materials to use new reflective light value
    # This would affect the specular intensity of materials

func set_lighting_enabled(enabled: bool) -> void:
    lighting_enabled = enabled
    for light in directional_lights:
        if light.godot_light:
            light.godot_light.visible = enabled
    
    for light in point_lights:
        if light.godot_light:
            light.godot_light.visible = enabled
    
    for light in tube_lights:
        for godot_light in light.godot_lights:
            godot_light.visible = enabled

func reset_to_defaults() -> void:
    set_ambient_light(AMBIENT_LIGHT_DEFAULT)
    set_reflective_light(REFLECTIVE_LIGHT_DEFAULT)
    lighting_enabled = true
    dynamic_lighting_enabled = true
```

```gdscript
class_name SpaceDirectionalLight extends Resource

var direction: Vector3
var intensity: float
var light_color: Color
var specular_color: Color
var godot_light: DirectionalLight3D

func _init() -> void:
    direction = Vector3(0, -1, 0)
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    godot_light = null
```

```gdscript
class_name SpacePointLight extends Resource

var position: Vector3
var inner_radius: float
var outer_radius: float
var intensity: float
var light_color: Color
var specular_color: Color
var ignore_object_id: int
var godot_light: OmniLight3D

func _init() -> void:
    position = Vector3.ZERO
    inner_radius = 10.0
    outer_radius = 50.0
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    ignore_object_id = -1
    godot_light = null
```

```gdscript
class_name SpaceTubeLight extends Resource

var start_position: Vector3
var end_position: Vector3
var inner_radius: float
var outer_radius: float
var intensity: float
var light_color: Color
var specular_color: Color
var affected_object_id: int
var godot_lights: Array[OmniLight3D]

func _init() -> void:
    start_position = Vector3.ZERO
    end_position = Vector3(0, 0, 10)
    inner_radius = 10.0
    outer_radius = 50.0
    intensity = 1.0
    light_color = Color.WHITE
    specular_color = Color.WHITE
    affected_object_id = -1
    godot_lights = []
```

## 8. Nebula System

### Original Implementation

The nebula system in the original codebase:
- Creates volumetric fog effects for space environments
- Supports different nebula types and densities
- Handles dynamic fog color and intensity
- Includes lightning effects within nebulae
- Manages performance optimization for nebula rendering
- Supports AWACS gameplay mechanics (radar interference)
- Uses a cube-based system for nebula rendering with configurable slices
- Implements a "poof" system for nebula cloud elements with rotation and alpha effects
- Supports multiple nebula bitmap types loaded from nebula.tbl
- Includes dynamic fog color calculation based on texture analysis
- Features a detail level system with configurable parameters for different performance levels
- Implements special rendering for HTL (Hardware Transform & Lighting) mode
- Provides fog distance calculations for different ship types
- Includes a lightning storm system with configurable parameters
- Uses a cube-based system for nebula rendering with configurable slices
- Implements a "poof" system for nebula cloud elements with rotation and alpha effects
- Supports multiple nebula bitmap types loaded from nebula.tbl
- Includes dynamic fog color calculation based on texture analysis
- Features a detail level system with configurable parameters for different performance levels
- Implements special rendering for HTL (Hardware Transform & Lighting) mode
- Provides fog distance calculations for different ship types
- Includes a lightning storm system with configurable parameters

### Godot Implementation

```gdscript
class_name NebulaManager extends Node3D

signal lightning_created(position: Vector3, target: Vector3)

# Nebula properties
@export var enabled: bool = false
@export var fog_color: Color = Color(0.12, 0.2, 0.61)  # Default blue nebula
@export var fog_density: float = 0.02
@export var fog_height: float = 1000.0
@export var fog_falloff: float = 1.0
@export var slices: int = 5
@export var render_mode: int = 0  # 0=None, 1=Poly, 2=POF, 3=Lame, 4=HTL
@export var awacs_factor: float = -1.0  # -1.0 means disabled
@export_range(0, 5) var detail_level: int = 3

# Nebula detail settings
var detail_settings: Array[Dictionary] = [
    {
        "max_alpha": 0.575,
        "break_alpha": 0.13,
        "break_x": 150.0,
        "break_y": 112.5,
        "cube_dim": 510.0,
        "cube_inner": 50.0,
        "cube_outer": 250.0,
        "prad": 120.0
    },
    # Additional detail levels would be defined here
]

# Nebula storm system
class_name NebulaStorm extends Resource
var name: String = ""
var bolt_types: Array[int] = []
var flavor: Vector3 = Vector3.ZERO
var min_time: int = 750
var max_time: int = 10000
var min_count: int = 1
var max_count: int = 3

# Add a new section for Physics Engine before "Integration with Other Systems"

## 9. Physics Engine

### Original Implementation

The physics engine in the original codebase:
- Implements Newtonian physics for ship movement and rotation
- Supports different physics modes including normal flight, glide, and special warp
- Handles ship rotation with damping and maximum rotation limits
- Implements velocity ramping for smooth acceleration and deceleration
- Provides functions for applying external forces (whack, shock)
- Supports special physics flags for different movement states
- Includes reduced damping system for impacts and weapon hits
- Implements afterburner and booster physics
- Provides functions for physics prediction and simulation
- Includes a control system for translating player input to physics forces
- Supports special movement modes like dead-drift and slide

### Godot Implementation
