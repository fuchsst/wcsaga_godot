# Physics and Space Environment Systems

This document outlines the physics and space environment systems from the original Wing Commander Saga codebase and how they should be implemented in Godot.

## Overview

The physics and space environment systems in Wing Commander Saga include:

1.  **Asteroid Field System** - Generation and management of asteroid fields
2.  **Debris System** - Creation and management of ship debris after destruction
3.  **Fireball/Explosion System** - Visual effects for explosions and weapon impacts
4.  **Decal System** - Visual effects applied to ship surfaces (impacts, damage)
5.  **Warp Effects** - Visual effects for ship warping in/out of a scene
6.  **Jump Node System** - Interstellar travel points for mission transitions
7.  **Lighting System** - Dynamic lighting for space environments
8.  **Nebula System** - Volumetric fog and environmental effects
9.  **Physics Engine** - Ship movement and collision physics
10. **Particle System** - General-purpose particle effects
11. **Starfield System** - Background star rendering and management
12. **Supernova Effects** - Special effects for supernova events

These systems are primarily visual but also have gameplay implications through collision detection and damage application.

## 1. Asteroid Field System

### Original Implementation

The asteroid system in the original codebase (`asteroid.cpp`):
- Manages asteroid fields with configurable density, size, and movement (`asteroid_field` struct).
- Supports different asteroid types and models (`asteroid_info` struct, `NUM_DEBRIS_SIZES`, `NUM_DEBRIS_POFS`).
- Handles asteroid creation (`asteroid_create`) and positioning within field boundaries, including inner bounds (`inner_bound_pos_fixup`).
- Applies initial velocity and rotational velocity (`asteroid_cap_speed`).
- Manages asteroid collisions with ships and weapons (`asteroid_check_collision`, `asteroid_hit`).
- Includes asteroid wrapping logic within defined boundaries (`asteroid_should_wrap`, `asteroid_wrap_pos`).
- Supports asteroid breaking into smaller pieces when destroyed (`asteroid_sub_create`).
- Manages asteroid lifetime and cleanup (`asteroid_delete`).
- Includes logic for targeted asteroids and throwing asteroids at specific targets (`asteroid_aim_at_target`, `maybe_throw_asteroid`).
- Loads asteroid data from `asteroid.tbl`.
- Creates explosion effects upon destruction (`asteroid_create_explosion`, `asteriod_explode_sound`).
- Handles area damage effects for certain asteroid types (`asteroid_do_area_effect`).
- Uses a linked list (`Asteroid_obj_list`) to track active asteroid objects.

### Godot Implementation

```gdscript
class_name AsteroidField extends Node3D

signal asteroid_destroyed(asteroid: Asteroid, position: Vector3)

@export var field_size: Vector3 = Vector3(10000, 5000, 10000)
@export var inner_bound_size: Vector3 = Vector3.ZERO  # If non-zero, creates a hollow center
@export var num_asteroids: int = 100
@export var asteroid_types: Array[AsteroidType] = [] # Resource defining model, health, debris, etc.
@export var field_speed: float = 10.0
@export var field_direction: Vector3 = Vector3.FORWARD
@export var wrap_asteroids: bool = true
@export var field_type: int = 0 # 0=Passive, 1=Active (throws asteroids)
@export var debris_genre: int = 0 # 0=Asteroid, 1=Ship debris models

# Asteroid field generation
func generate_field() -> void:
    # Create asteroid instances based on field parameters
    # Position them randomly within field boundaries, avoiding inner bounds
    # Apply initial velocities based on field_speed and random variation
    pass

# Asteroid wrapping logic
func _process(delta: float) -> void:
    # Check if asteroids have left the field boundaries
    # Wrap them to the opposite side if needed and wrap_asteroids is true
    # Handle active field logic (throwing asteroids) if applicable
    pass
```

```gdscript
class_name Asteroid extends RigidBody3D

signal asteroid_hit(damage: float, hit_position: Vector3)

@export var asteroid_type: AsteroidType # Resource defining model, health, debris, etc.
@export var size_class: int  # 0=small, 1=medium, 2=large (derived from AsteroidType)
@export var health: float = 100.0 # Initial health from AsteroidType
@export var debris_on_destroy: bool = true # From AsteroidType
@export var area_damage: float = 0.0 # From AsteroidType
@export var area_blast: float = 0.0 # From AsteroidType
@export var area_inner_rad: float = 0.0 # From AsteroidType
@export var area_outer_rad: float = 0.0 # From AsteroidType

var target_object: Node3D = null # For active fields

# Handle collision with ships and weapons
func _on_body_entered(body: Node) -> void:
    if body is ShipBase or body is Projectile: # Assuming ShipBase and Projectile base classes
        # Consider using signals or direct method calls for damage application
        # Need a way to get impact damage from the colliding body
        var impact_damage = 10.0 # Placeholder
        if body.has_method("get_impact_damage"):
             impact_damage = body.get_impact_damage()
        apply_damage(impact_damage, global_position)

# Apply damage and potentially break apart
func apply_damage(damage: float, hit_position: Vector3) -> void:
    health -= damage
    emit_signal("asteroid_hit", damage, hit_position)
    if health <= 0:
        destroy(hit_position)

# Break into smaller pieces when destroyed
func destroy(hit_position: Vector3) -> void:
    # Trigger area effect if applicable
    if area_damage > 0.0:
        # Implement area damage logic (e.g., using Area3D or physics queries)
        pass

    # Spawn smaller asteroids if applicable
    if size_class > 0 and debris_on_destroy:
        spawn_smaller_asteroids(hit_position)

    # Create explosion effect using a manager singleton/autoload
    var explosion = ExplosionManager.create_explosion(
        global_position,
        ExplosionManager.ExplosionType.ASTEROID, # Use enum
        null, # parent_obj
        asteroid_type.explosion_scale_multiplier if asteroid_type else 1.0 # Scale based on type
    )

    queue_free()

func spawn_smaller_asteroids(hit_position: Vector3):
    # Logic to spawn smaller asteroid instances based on asteroid_type rules
    # Example: A large asteroid might spawn 2 medium ones
    pass

```

## 2. Debris System

### Original Implementation

The debris system in the original codebase (`debris.cpp`):
- Creates debris pieces when ships are destroyed (`debris_create`).
- Supports hull debris (large pieces, `is_hull = true`) and small debris (`is_hull = false`).
- Applies physics to debris (rotation, velocity) based on explosion force and parent object's rotation (`calc_debris_physics_properties`, `DEBRIS_ROTVEL_SCALE`).
- Manages debris lifetime (`lifeleft`) and cleanup based on distance and minimum survival time (`maybe_delete_debris`, `must_survive_until`).
- Handles debris collisions with ships, applying damage based on velocity and mass (`debris_check_collision`, `debris_hit`).
- Uses different models for normal debris (`debris01.pof`) and vaporized debris (`debris02.pof`).
- Associates debris with the species of the source ship for texturing (`species`, `Species_info.debris_texture`).
- Includes electrical arcing effects on hull debris (`arc_timestamp`, `arc_pts`, `arc_frequency`).
- Limits the maximum number of hull pieces (`MAX_HULL_PIECES`) and removes the oldest if the limit is reached (`debris_find_oldest`).
- Plays sounds associated with debris (`SND_DEBRIS`, `SND_DEBRIS_ARC_*`).
- Uses a linked list (`Hull_debris_list`) for hull pieces.

### Godot Implementation

```gdscript
# debris_manager.gd
class_name DebrisManager extends Node

# Configuration
@export var max_debris_pieces: int = 200
@export var max_hull_pieces: int = 64 # From MAX_HULL_PIECES
@export var max_debris_distance: float = 10000.0 # From MAX_DEBRIS_DIST
@export var debris_check_interval: float = 10.0  # seconds, From DEBRIS_DISTANCE_CHECK_TIME

var hull_debris_nodes: Array[Node] = []
var small_debris_nodes: Array[Node] = []

# Create debris from destroyed ship
func create_ship_debris(ship: ShipBase, explosion_center: Vector3, explosion_force: float) -> void:
    var ship_model = ship.get_model() # Assuming ShipBase has this method
    var ship_info = ship.ship_info # Assuming ShipBase has ship_info resource
    var ship_size_class = ship_info.size_class # Assuming ShipInfo has size_class

    # Determine number of pieces based on ship size/info
    var num_hull_pieces = min(ship_size_class * 2, 8) # Example logic
    var num_small_pieces = min(ship_size_class * 10, 30) # Example logic

    # Check hull debris limit
    while hull_debris_nodes.size() + num_hull_pieces > max_hull_pieces:
        if hull_debris_nodes.is_empty():
            break # Cannot create more hull debris
        var oldest_debris = hull_debris_nodes.pop_front() as DebrisBase
        if is_instance_valid(oldest_debris):
            oldest_debris.queue_free() # Or trigger a death roll effect

    # Create hull debris (large pieces)
    for i in range(num_hull_pieces):
        # Need logic to select submodels from the ship model
        var submodel_index = i # Placeholder
        create_hull_debris(ship, ship_model, submodel_index, explosion_center, explosion_force)

    # Create small debris
    for i in range(num_small_pieces):
        create_small_debris(ship, explosion_center, explosion_force)

# Create a large hull piece
func create_hull_debris(ship: ShipBase, model: ModelResource, submodel_index: int, explosion_center: Vector3, explosion_force: float) -> DebrisHull:
    var debris_scene = load("res://scenes/effects/debris_hull.tscn") # Example path
    var debris = debris_scene.instantiate() as DebrisHull
    add_child(debris)

    debris.setup_hull_piece(ship, model, submodel_index, explosion_center, explosion_force)
    hull_debris_nodes.append(debris)
    return debris

# Create small generic debris
func create_small_debris(ship: ShipBase, explosion_center: Vector3, explosion_force: float) -> DebrisSmall:
    var debris_scene = load("res://scenes/effects/debris_small.tscn") # Example path
    var debris = debris_scene.instantiate() as DebrisSmall
    add_child(debris)

    debris.setup_small_piece(ship, explosion_center, explosion_force)
    small_debris_nodes.append(debris)
    return debris

# Clean up distant debris
func _on_cleanup_timer_timeout() -> void:
    var player_pos = PlayerShip.global_position # Assuming a global PlayerShip reference
    # Check distance of all debris from player
    for i in range(hull_debris_nodes.size() - 1, -1, -1):
        var debris_node = hull_debris_nodes[i] as DebrisBase
        if not is_instance_valid(debris_node):
            hull_debris_nodes.remove_at(i)
            continue
        if debris_node.global_position.distance_to(player_pos) > max_debris_distance and debris_node.can_expire():
            debris_node.queue_free() # Or trigger death roll
            hull_debris_nodes.remove_at(i)

    for i in range(small_debris_nodes.size() - 1, -1, -1):
        var debris_node = small_debris_nodes[i] as DebrisBase
        if not is_instance_valid(debris_node):
            small_debris_nodes.remove_at(i)
            continue
        if debris_node.global_position.distance_to(player_pos) > max_debris_distance and debris_node.can_expire():
            debris_node.queue_free()
            small_debris_nodes.remove_at(i)

func _notification(what):
     if what == NOTIFICATION_CHILD_EXITED_TREE:
         # Clean up arrays when a debris node is freed elsewhere
         # Find the child that exited - this requires iterating or a signal connection
         pass # Implement robust cleanup
```

```gdscript
# debris_base.gd
class_name DebrisBase extends RigidBody3D

var source_ship_info: ShipInfo # Reference to the ShipInfo resource
var lifetime: float = 10.0
var time_elapsed: float = 0.0
var must_survive_until: float = 0.0  # Minimum survival time (absolute game time)
var start_time: float = 0.0

func _integrate_forces(state):
    time_elapsed += state.step
    if time_elapsed > lifetime and Time.get_ticks_msec() / 1000.0 > must_survive_until:
        # Optionally trigger a death roll effect instead of immediate free
        queue_free()

func can_expire() -> bool:
    return Time.get_ticks_msec() / 1000.0 > must_survive_until

func setup_common(ship: ShipBase, explosion_center: Vector3, explosion_force: float):
    source_ship_info = ship.ship_info
    start_time = Time.get_ticks_msec() / 1000.0
    global_position = ship.global_position # Start at ship's position initially

    # Apply initial physics based on explosion
    var direction = (global_position - explosion_center).normalized()
    if direction == Vector3.ZERO:
        direction = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()

    var base_velocity = ship.linear_velocity # Inherit some velocity
    var explosion_impulse = direction * explosion_force * (1.0 + randf() * 0.5) # Add randomness

    # Apply rotational impulse based on position relative to explosion center
    var torque_impulse = (global_position - explosion_center).cross(explosion_impulse) * 0.1 # Adjust multiplier

    linear_velocity = base_velocity + explosion_impulse / mass
    angular_velocity = torque_impulse / mass # Simplified inertia

    # Set lifetime based on ship info (if defined)
    if source_ship_info.debris_min_lifetime >= 0.0 and source_ship_info.debris_max_lifetime >= 0.0:
        lifetime = randf_range(source_ship_info.debris_min_lifetime, source_ship_info.debris_max_lifetime)
        must_survive_until = start_time + source_ship_info.debris_min_lifetime
    elif source_ship_info.debris_min_lifetime >= 0.0:
        lifetime = max(lifetime, source_ship_info.debris_min_lifetime) # Ensure it lives at least min time
        must_survive_until = start_time + source_ship_info.debris_min_lifetime
    elif source_ship_info.debris_max_lifetime >= 0.0:
        lifetime = min(lifetime, source_ship_info.debris_max_lifetime) # Ensure it lives at most max time
        must_survive_until = start_time # No minimum survival

    # Set initial health based on ship info (if defined)
    if source_ship_info.debris_min_hitpoints >= 0.0 and source_ship_info.debris_max_hitpoints >= 0.0:
        # Assuming DebrisBase has a health property or similar damage handling
        # health = randf_range(source_ship_info.debris_min_hitpoints, source_ship_info.debris_max_hitpoints)
        pass
    elif source_ship_info.debris_min_hitpoints >= 0.0:
        # health = max(health, source_ship_info.debris_min_hitpoints)
        pass
    elif source_ship_info.debris_max_hitpoints >= 0.0:
        # health = min(health, source_ship_info.debris_max_hitpoints)
        pass

```

```gdscript
# debris_hull.gd
class_name DebrisHull extends DebrisBase

@export var ship_model_part: MeshInstance3D # Assign the specific mesh part in the editor
@export var can_damage_ships: bool = true
@export var damage_multiplier: float = 1.0

# Electrical arc effect properties
@export var arc_frequency_min: float = 1.0 # seconds
@export var arc_frequency_max: float = 2.0 # seconds
@export var arc_chance: float = 0.5 # Chance per interval
@export var arc_lifetime_min: float = 0.1
@export var arc_lifetime_max: float = 0.75
@export var arc_effect_scene: PackedScene # Scene for the arc visual

var next_arc_check_time: float = 0.0

func _ready():
    if ship_model_part == null:
        printerr("DebrisHull needs ship_model_part assigned!")
    damage_multiplier = source_ship_info.debris_damage_mult if source_ship_info else 1.0
    next_arc_check_time = start_time + randf_range(arc_frequency_min, arc_frequency_max)

func _integrate_forces(state):
    super._integrate_forces(state) # Call parent method

    # Handle arcing effects
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time >= next_arc_check_time:
        if randf() < arc_chance:
            spawn_arc_effect()
        next_arc_check_time = current_time + randf_range(arc_frequency_min, arc_frequency_max)


func setup_hull_piece(ship: ShipBase, model: ModelResource, submodel_index: int, explosion_center: Vector3, explosion_force: float):
    # TODO: Logic to extract or assign the correct mesh/submodel to ship_model_part
    # This might involve instantiating a part of the ship's model scene or having pre-made debris parts
    # For now, assume ship_model_part is set up in the scene

    setup_common(ship, explosion_center, explosion_force)

    # Apply species-specific texture if available
    if source_ship_info and source_ship_info.species >= 0:
        var species_info = SpeciesManager.get_species_info(source_ship_info.species) # Assuming SpeciesManager
        if species_info and species_info.debris_texture:
             if ship_model_part and ship_model_part.mesh:
                 var mat = StandardMaterial3D.new()
                 mat.albedo_texture = species_info.debris_texture
                 ship_model_part.material_override = mat


    # Hull-specific physics adjustments (e.g., mass based on submodel size)
    # mass = calculate_mass_from_submodel(model, submodel_index) # Placeholder

func _on_body_entered(body: Node) -> void:
    if body is ShipBase and can_damage_ships:
        var impact_velocity = linear_velocity.length()
        # Original mass calculation was complex, using a simpler approach here
        var damage = impact_velocity * mass * 0.05 * damage_multiplier # Adjust multiplier as needed
        body.apply_damage(damage, global_position, self) # Pass self as damage source

func spawn_arc_effect():
    if arc_effect_scene == null: return

    # Find two random points on the surface of the mesh
    var mesh_tool = MeshDataTool.new()
    if ship_model_part and ship_model_part.mesh:
        mesh_tool.create_from_surface(ship_model_part.mesh, 0)
        if mesh_tool.get_vertex_count() >= 2:
            var v1_idx = randi() % mesh_tool.get_vertex_count()
            var v2_idx = randi() % mesh_tool.get_vertex_count()
            while v1_idx == v2_idx: # Ensure different points
                 v2_idx = randi() % mesh_tool.get_vertex_count()

            var p1_local = mesh_tool.get_vertex(v1_idx)
            var p2_local = mesh_tool.get_vertex(v2_idx)

            var arc_instance = arc_effect_scene.instantiate() # Assuming arc scene handles its own visuals/lifetime
            add_child(arc_instance)
            # Position/orient the arc effect between p1 and p2 in global space
            if arc_instance.has_method("setup_arc"):
                arc_instance.setup_arc(global_transform * p1_local, global_transform * p2_local, randf_range(arc_lifetime_min, arc_lifetime_max))
        # No need to commit if not modifying mesh data
        # mesh_tool.commit_to_surface(ship_model_part.mesh)

```

```gdscript
# debris_small.gd
class_name DebrisSmall extends DebrisBase

@export var model_mesh: MeshInstance3D # Assign the generic small debris mesh

func _ready():
    if model_mesh == null:
        printerr("DebrisSmall needs model_mesh assigned!")

func setup_small_piece(ship: ShipBase, explosion_center: Vector3, explosion_force: float):
    setup_common(ship, explosion_center, explosion_force)

    # Apply species-specific texture if available
    if source_ship_info and source_ship_info.species >= 0:
        var species_info = SpeciesManager.get_species_info(source_ship_info.species) # Assuming SpeciesManager
        if species_info and species_info.debris_texture:
             if model_mesh and model_mesh.mesh:
                 var mat = StandardMaterial3D.new()
                 mat.albedo_texture = species_info.debris_texture
                 model_mesh.material_override = mat

    # Small debris might have shorter default lifetime
    lifetime = randf_range(0.5, 3.0)
    # Small debris usually doesn't damage ships
    # can_damage_ships = false # Inherited from DebrisBase, might need explicit setting if base changes
    # Adjust mass for small debris
    mass = randf_range(0.5, 2.0)

```

## 3. Fireball/Explosion System

### Original Implementation

The fireball system in the original codebase (`fireballs.cpp`):
- Manages different types of explosion effects (`fireball_info`, `MAX_FIREBALL_TYPES`).
- Supports various sizes and visual styles through animated bitmaps (`bm_load_animation`).
- Handles animation playback and timing (`time_elapsed`, `total_time`, `fps`).
- Includes specialized effects like warp-in/out explosions (`FIREBALL_WARP_EFFECT`, `warpin_render`).
- Manages sound effects for explosions and warps (`fireball_play_warphole_open_sound`, `fireball_play_warphole_close_sound`).
- Loads fireball data from `fireball.tbl`.
- Supports LODs for fireballs (`lod_count`, `fireball_get_lod`).
- Handles lighting associated with explosions (`exp_color`).
- Manages a pool of active fireballs (`Fireballs`, `MAX_FIREBALLS`, `Num_fireballs`).
- Includes logic for Knossos device warp effect (`FIREBALL_KNOSSOS`).
- Uses specific bitmaps for warp glow and ball (`Warp_glow_bitmap`, `Warp_ball_bitmap`).
- Can render warp effects as 2D billboards or 3D models (`Warp_model`, `Cmdline_3dwarp`).

### Godot Implementation

```gdscript
# explosion_manager.gd
class_name ExplosionManager extends Node

# Explosion type constants matching original where possible
enum ExplosionType {
    EXPLOSION_MEDIUM, # FIREBALL_EXPLOSION_MEDIUM
    WARP,             # FIREBALL_WARP
    KNOSSOS,          # FIREBALL_KNOSSOS
    ASTEROID,         # FIREBALL_ASTEROID
    EXPLOSION_LARGE1, # FIREBALL_EXPLOSION_LARGE1
    EXPLOSION_LARGE2, # FIREBALL_EXPLOSION_LARGE2
    # Add custom types as needed
    SMALL # Example custom type
}

# Preload explosion scenes/resources based on type
@export var explosion_scenes: Dictionary = {
    ExplosionType.SMALL: preload("res://scenes/effects/explosion_small.tscn"),
    ExplosionType.MEDIUM: preload("res://scenes/effects/explosion_medium.tscn"),
    ExplosionType.LARGE1: preload("res://scenes/effects/explosion_large1.tscn"),
    ExplosionType.LARGE2: preload("res://scenes/effects/explosion_large2.tscn"),
    ExplosionType.ASTEROID: preload("res://scenes/effects/explosion_asteroid.tscn"),
    ExplosionType.WARP: preload("res://scenes/effects/warp_effect.tscn"), # Use WarpEffect scene
    ExplosionType.KNOSSOS: preload("res://scenes/effects/knossos_effect.tscn") # Example
}

# Store explosion definitions (maybe in a Resource)
# var explosion_definitions: Dictionary = load_explosion_definitions("res://resources/explosions.tres")

# Create an explosion at a position
func create_explosion(position: Vector3, type: ExplosionType, parent_obj = null, size_scale: float = 1.0, velocity: Vector3 = Vector3.ZERO, ship_class_index: int = -1, orient_override: Basis = Basis()) -> Node3D:
    if not explosion_scenes.has(type):
        printerr("Explosion type not found in explosion_scenes: ", type)
        return null

    var explosion_scene = explosion_scenes[type]
    var explosion_node = explosion_scene.instantiate()
    add_child(explosion_node) # Add to the manager node

    explosion_node.global_position = position
    explosion_node.scale = Vector3.ONE * size_scale

    # Pass additional parameters if the explosion node script expects them
    if explosion_node.has_method("setup_explosion"):
        explosion_node.setup_explosion(type, parent_obj, velocity, ship_class_index, orient_override)
    elif type == ExplosionType.WARP and explosion_node is WarpEffect:
         # WarpEffect might have its own setup
         # Need ship size for warp scaling
         var ship_size = 10.0 # Default or get from parent_obj if possible
         if parent_obj and parent_obj.has_method("get_ship_radius"):
             ship_size = parent_obj.get_ship_radius()
         # Assuming WarpEffect has a setup_warp method
         # explosion_node.setup_warp(true, ship_size, "", orient_override) # Assuming warp-in by default here
         pass # WarpEffect handles its own setup

    return explosion_node

# Function to load definitions from a resource file (example)
#func load_explosion_definitions(path: String) -> Dictionary:
#    var resource = load(path)
#    if resource and resource is Dictionary: # Or your custom resource type
#        return resource
#    else:
#        printerr("Failed to load explosion definitions from: ", path)
#        return {}

```

```gdscript
# explosion.gd - Base script for explosion scenes
class_name Explosion extends Node3D

var explosion_type: ExplosionManager.ExplosionType
var lifetime: float = 2.0 # Default lifetime
var time_elapsed: float = 0.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer # Assuming node named AnimationPlayer
@onready var light: OmniLight3D = $OmniLight3D # Assuming node named OmniLight3D
@onready var particles: GPUParticles3D = $GPUParticles3D # Assuming node named GPUParticles3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D # Assuming node named AudioStreamPlayer3D

# Optional setup function called by ExplosionManager
func setup_explosion(type: ExplosionManager.ExplosionType, parent_obj = null, initial_velocity: Vector3 = Vector3.ZERO, ship_class_index: int = -1, orient_override: Basis = Basis()):
    self.explosion_type = type
    # Apply initial velocity if needed (e.g., for physics-based explosions)
    if self is RigidBody3D:
        linear_velocity = initial_velocity
    # Use ship_class_index or orient_override if necessary for specific effects

    # Load specific resources based on type if not handled by scene preloading
    # Example: audio_player.stream = load(get_sound_path(type))
    # Example: light.light_energy = get_light_energy(type)
    # Example: lifetime = get_lifetime(type)

    # Start effects
    if animation_player:
        animation_player.play("explode") # Assuming an animation named "explode"
    if audio_player and audio_player.stream:
        audio_player.play()
    if particles:
        particles.emitting = true

func _process(delta: float):
    time_elapsed += delta

    # Fade out light over time (example)
    if light:
        # Adjust fade logic based on desired effect and lifetime
        var fade_start_time = lifetime * 0.5
        if time_elapsed > fade_start_time:
             var fade_duration = lifetime - fade_start_time
             light.light_energy = lerp(light.light_energy, 0.0, delta / fade_duration if fade_duration > 0 else 1.0)
        elif time_elapsed < 0.1: # Initial flash
             light.light_energy = lerp(0.0, light.light_energy, time_elapsed / 0.1)


    # Remove explosion when complete
    if time_elapsed >= lifetime:
        queue_free()

# --- Helper functions to get type-specific properties (replace with Resource loading) ---
#func get_sound_path(type: ExplosionManager.ExplosionType) -> String:
#    match type:
#        ExplosionManager.ExplosionType.SMALL: return "res://assets/sounds/explosion_small.wav"
#        # ... other types
#    return ""
#
#func get_light_energy(type: ExplosionManager.ExplosionType) -> float:
#     match type:
#        ExplosionManager.ExplosionType.SMALL: return 2.0
#        # ... other types
#     return 5.0
#
#func get_lifetime(type: ExplosionManager.ExplosionType) -> float:
#     match type:
#        ExplosionManager.ExplosionType.SMALL: return 1.0
#        # ... other types
#     return 2.0

```

## 4. Decal System

### Original Implementation

The decal system in the original codebase (`decals.cpp`):
- Applies visual effects to ship surfaces (damage marks, weapon impacts) using projected textures.
- Manages decal lifetime and fading (`decal::timestamp`, `decal::burn_time`).
- Handles decal positioning and orientation on 3D models (`decal_create`, `decal_point`).
- Supports different decal types implicitly through texture selection (`decal_find_next`).
- Clips decal geometry against the target model's polygons (`decal_create_sub`, `decal_create_tmappoly`).
- Uses a cube projection method (`setup_decal_cube`, `decal_plane_clip_tri`) to determine affected polygons.
- Manages decal polygons using a custom memory pool (`big_ol_decal_poly_array`, `get_open_poly`, `free_poly`).
- Organizes decals per ship/subsystem using `decal_system` and `decal_list_controle`.
- Limits the number of decals per object (`decal_list_controle::trim`).
- Supports back-faced decals (`backfaced_texture`).
- Includes support for glow and burn textures associated with decals (`glow_texture`, `burn_texture`).
- Rebuilds vertex buffers when decals are modified (`rebuild_decal_buffer`).

### Godot Implementation

In Godot, we can use the built-in Decal node system with some custom management:

```gdscript
# decal_manager.gd
class_name DecalManager extends Node

# Decal type definitions (could be a Resource)
enum DecalType {
    WEAPON_IMPACT,
    BURN_MARK,
    SCRATCH,
    EXPLOSION_MARK
}

@export var decal_definitions: Dictionary = {
    DecalType.WEAPON_IMPACT: {
        "texture": preload("res://assets/decals/weapon_impact.png"),
        "normal_texture": preload("res://assets/decals/weapon_impact_normal.png"), # Optional
        "size": Vector3(1, 1, 2), # Width, Height, Depth/Projection Distance
        "lifetime": 10.0,
        "fade_time": 2.0
    },
    DecalType.BURN_MARK: {
        "texture": preload("res://assets/decals/burn_mark.png"),
        "size": Vector3(2, 2, 1),
        "lifetime": 30.0,
        "fade_time": 5.0
    }
    # Add other types...
}

# Maximum decals per ship (managed per target object)
@export var max_decals_per_target: int = 20

# Dictionary to track decals per target object instance ID
var target_decals: Dictionary = {}

# Create a decal on a target surface
func create_decal(position: Vector3, normal: Vector3, type: DecalType, target_object: Node3D) -> Decal:
    if not target_object or not decal_definitions.has(type):
        printerr("Invalid target or decal type for create_decal")
        return null

    var target_id = target_object.get_instance_id()
    var definition = decal_definitions[type]

    # Get or create decal list for the target
    if not target_decals.has(target_id):
        target_decals[target_id] = []

    var decal_list: Array = target_decals[target_id]

    # If too many decals, remove the oldest one
    if decal_list.size() >= max_decals_per_target:
        var oldest_decal = decal_list.pop_front() as Decal
        if is_instance_valid(oldest_decal):
            oldest_decal.queue_free()

    # Create new Godot Decal node
    var decal = Decal.new()
    target_object.add_child(decal) # Attach to the target object
    decal_list.append(decal)

    # Configure the Decal node
    decal.texture_albedo = definition.texture
    if definition.has("normal_texture"):
        decal.texture_normal = definition.normal_texture
    decal.size = definition.size
    decal.global_position = position
    # Align decal's -Z with the normal
    decal.look_at(position - normal, Vector3.UP)

    # Add custom script for lifetime management
    var decal_script = load("res://scripts/effects/decal_lifetime.gd").new() # Example path
    decal_script.lifetime = definition.get("lifetime", 10.0)
    decal_script.fade_time = definition.get("fade_time", 2.0)
    decal.add_child(decal_script) # Add as a child node to manage the Decal parent

    return decal

func _notification(what):
    if what == NOTIFICATION_CHILD_EXITED_TREE:
        # Clean up target_decals dictionary when a target object is removed
        # This requires knowing which child exited. A signal from the target object might be better.
        pass # Implement robust cleanup
```

```gdscript
# decal_lifetime.gd - Attach this script as a child to a Decal node
class_name DecalLifetime extends Node

@export var lifetime: float = 10.0
@export var fade_time: float = 2.0

var time_elapsed: float = 0.0
var decal_node: Decal

func _ready():
    decal_node = get_parent() as Decal
    if not decal_node:
        printerr("DecalLifetime script must be a child of a Decal node.")
        queue_free()

func _process(delta: float):
    time_elapsed += delta

    # Fade out decal when nearing end of lifetime
    if time_elapsed > lifetime - fade_time:
        var alpha = clamp((lifetime - time_elapsed) / fade_time, 0.0, 1.0)
        decal_node.modulate.a = alpha # Fade the decal's alpha

    # Remove when lifetime is over
    if time_elapsed >= lifetime:
        if is_instance_valid(decal_node):
            decal_node.queue_free() # Remove the parent Decal node
        queue_free() # Remove self
```

## 5. Warp Effects

### Original Implementation

The warp effect system in the original codebase (`fireballs.cpp`, `warpineffect.cpp`):
- Creates visual effects for ships entering/exiting a scene via warp (`FIREBALL_WARP_EFFECT`).
- Manages warp-in and warp-out animations using animated bitmaps or a 3D model (`Warp_model`).
- Handles sound effects for warp events, differentiating between fighter and capital ship sizes (`fireball_play_warphole_open_sound`, `fireball_play_warphole_close_sound`).
- Scales effects based on ship size (`radius`, `max_radius`).
- Uses specific glow and ball bitmaps (`Warp_glow_bitmap`, `Warp_ball_bitmap`).
- Implements a specific growth/shrink timing (`WARPHOLE_GROW_TIME`).
- Renders the effect using either billboards (`g3_draw_rotated_bitmap`) or a dedicated 3D model (`model_render` with warp globals).
- Includes noise/flash effects (`Noise`, `Cmdline_warp_flash`).
- Can render subspace tunnel effects (`subspace_render` in `starfield.cpp`).

### Godot Implementation

```gdscript
# warp_effect_manager.gd (Autoload/Singleton)
class_name WarpEffectManager extends Node

@export var warp_effect_scene: PackedScene = preload("res://scenes/effects/warp_effect.tscn")

# Create a warp-in effect
func create_warp_in(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    if warp_effect_scene == null:
        printerr("Warp effect scene not set in WarpEffectManager")
        return null

    var warp_node = warp_effect_scene.instantiate() as WarpEffect
    get_tree().current_scene.add_child(warp_node) # Add to current scene root

    warp_node.global_position = position
    warp_node.global_transform.basis = orientation
    warp_node.setup_warp(true, ship_size, ship_class, orientation) # Pass is_warp_in = true

    return warp_node

# Create a warp-out effect
func create_warp_out(position: Vector3, orientation: Basis, ship_size: float, ship_class: String) -> WarpEffect:
    if warp_effect_scene == null:
        printerr("Warp effect scene not set in WarpEffectManager")
        return null

    var warp_node = warp_effect_scene.instantiate() as WarpEffect
    get_tree().current_scene.add_child(warp_node) # Add to current scene root

    warp_node.global_position = position
    warp_node.global_transform.basis = orientation
    warp_node.setup_warp(false, ship_size, ship_class, orientation) # Pass is_warp_in = false

    return warp_node
```

```gdscript
# warp_effect.gd - Script for the warp effect scene
class_name WarpEffect extends Node3D

var is_warp_in: bool = true
var ship_size: float = 10.0
var ship_class: String = ""
var lifetime: float = 2.35 * 2.0 # Total duration including fade out (WARPHOLE_GROW_TIME * 2)
var grow_time: float = 2.35 # WARPHOLE_GROW_TIME
var time_elapsed: float = 0.0

# References to nodes within the warp effect scene (set up in editor)
@onready var warp_model: MeshInstance3D = $WarpModel # Example node name
@onready var warp_particles: GPUParticles3D = $WarpParticles # Example node name
@onready var warp_light: OmniLight3D = $WarpLight # Example node name
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D # Example node name
@onready var animation_player: AnimationPlayer = $AnimationPlayer # Example node name

# Sound resources (set in editor or loaded here)
@export var sound_warp_in: AudioStream
@export var sound_warp_out: AudioStream
@export var sound_warp_in_capital: AudioStream
@export var sound_warp_out_capital: AudioStream

func setup_warp(p_is_warp_in: bool, p_ship_size: float, p_ship_class: String, p_orientation: Basis):
    is_warp_in = p_is_warp_in
    ship_size = p_ship_size
    ship_class = p_ship_class
    global_transform.basis = p_orientation # Ensure correct orientation

    # Scale the entire effect node initially based on ship size (adjust multiplier as needed)
    scale = Vector3.ONE * ship_size * 0.05 # Example scaling factor

    # Select and play appropriate sound
    var sound_to_play = null
    var is_capital = ship_size > 100 # Example threshold for capital ship

    if is_warp_in:
        sound_to_play = sound_warp_in_capital if is_capital else sound_warp_in
        if animation_player: animation_player.play("warp_in") # Play warp-in animation
    else:
        sound_to_play = sound_warp_out_capital if is_capital else sound_warp_out
        if animation_player: animation_player.play("warp_out") # Play warp-out animation

    if audio_player and sound_to_play:
        audio_player.stream = sound_to_play
        audio_player.play()

    # Start particles if they aren't set to autoplay
    if warp_particles:
        warp_particles.emitting = true

    # Initial light setup (can be animated)
    if warp_light:
        warp_light.light_energy = 10.0 # Example initial energy

func _process(delta: float):
    time_elapsed += delta

    # Update effect size/visuals based on time using AnimationPlayer or code
    # Example scaling logic based on original code:
    var current_radius_factor = 1.0
    if is_warp_in:
        if time_elapsed < grow_time:
            current_radius_factor = pow(time_elapsed / grow_time, 0.4)
        else:
            current_radius_factor = 1.0 # Fully grown
    else: # Warp out
        if time_elapsed < grow_time: # First half (stable)
             current_radius_factor = 1.0
        elif time_elapsed < lifetime: # Second half (shrinking)
             var shrink_t = time_elapsed - grow_time
             var shrink_duration = lifetime - grow_time
             current_radius_factor = pow((shrink_duration - shrink_t) / shrink_duration, 0.4)
        else:
             current_radius_factor = 0.0 # Fully shrunk

    # Apply scaling to relevant visual nodes (e.g., the model)
    if warp_model:
        # Assuming base scale handles ship_size, now apply time-based factor
        warp_model.scale = Vector3.ONE * current_radius_factor

    # Fade out light (can also be done with AnimationPlayer)
    if warp_light:
        warp_light.light_energy = lerp(warp_light.light_energy, 0.0, delta * 1.0) # Example fade

    # Remove effect when complete
    if time_elapsed >= lifetime:
        queue_free()

```

## 6. Jump Node System

### Original Implementation

The jump node system in the original codebase (`jumpnode.cpp`):
- Represents interstellar travel points in missions (`jump_node` class).
- Manages visual representation using a 3D model (`m_modelnum`, default `subspacenode.pof`).
- Handles ship entry/exit detection using object collision (`jumpnode_get_which_in`, based on model radius).
- Supports different jump node models and effects (`set_model`).
- Provides detection for when ships enter jump nodes.
- Uses a linked list (`Jump_nodes`) to track all jump nodes in a mission.
- Supports customizable display colors (`m_display_color`, `set_alphacolor`) and visibility settings (`m_flags`, `JN_HIDE`, `JN_USE_DISPLAY_COLOR`).
- Includes methods to find jump nodes by name (`jumpnode_get_by_name`).
- Implements rendering with optional wireframe mode (`JN_SHOW_POLYS` flag affecting `MR_NO_POLYS`).
- Allows for custom model assignment with `set_model()` function.
- Associates jump nodes with standard Godot objects (`m_objnum`).

### Godot Implementation

```gdscript
# jump_node.gd
class_name JumpNode extends Node3D

signal ship_entered(ship: ShipBase)

@export var node_name: String = "Jump Node" : set = set_node_name
@export var model_path: String = "res://assets/models/subspacenode.glb" : set = set_model_path
@export var display_color: Color = Color(0, 1, 0, 1) : set = set_display_color # Default green
@export var show_polys: bool = false : set = set_show_polys
@export var hidden: bool = false : set = set_hidden
# Export flags for easier editor tweaking, mirroring original flags somewhat
@export_flags("Use Display Color", "Show Polys", "Hide", "Special Model") var flags: int = 0 : set = set_flags

@onready var model_instance: Node3D = $ModelInstance # Assign in editor
@onready var collision_area: Area3D = $CollisionArea # Assign in editor
@onready var collision_shape: CollisionShape3D = $CollisionArea/CollisionShape3D # Assign in editor

var _model_radius: float = 50.0 # Default/calculated radius

func _ready() -> void:
    _update_model()
    _update_collision_shape()
    _update_display_properties()
    _update_visibility()

    # Connect signal from Area3D
    if collision_area:
        collision_area.body_entered.connect(_on_body_entered)

    # Register with a manager if needed
    JumpNodeManager.register_jump_node(self)

func _exit_tree():
    # Unregister from manager
    JumpNodeManager.unregister_jump_node(self)

# --- Setters for exported properties to update visuals ---

func set_node_name(new_name: String):
    if node_name != new_name:
        JumpNodeManager.unregister_jump_node(self) # Unregister old name
        node_name = new_name
        JumpNodeManager.register_jump_node(self) # Register new name

func set_model_path(new_path: String):
    if model_path != new_path:
        model_path = new_path
        flags |= 8 # Set "Special Model" flag implicitly
        _update_model()
        _update_collision_shape()
        _update_display_properties() # Reapply color/wireframe

func set_display_color(new_color: Color):
    if display_color != new_color:
        display_color = new_color
        flags |= 1 # Set "Use Display Color" flag implicitly
        _update_display_properties()

func set_show_polys(new_show_polys: bool):
     if show_polys != new_show_polys:
        show_polys = new_show_polys
        flags = (flags | 2) if show_polys else (flags & ~2)
        _update_display_properties()

func set_hidden(new_hidden: bool):
    if hidden != new_hidden:
        hidden = new_hidden
        flags = (flags | 4) if hidden else (flags & ~4)
        _update_visibility()

func set_flags(new_flags: int):
    if flags != new_flags:
        flags = new_flags
        # Update properties based on flags
        hidden = (flags & 4) != 0
        show_polys = (flags & 2) != 0
        # Use display color flag is handled in _update_display_properties
        _update_visibility()
        _update_display_properties()

# --- Internal update functions ---

func _update_model():
    # Remove old model if it exists and is a child
    if is_instance_valid(model_instance) and model_instance.get_parent() == self:
        model_instance.queue_free()
        model_instance = null

    if model_path.is_empty(): return

    var loaded_scene = load(model_path)
    if loaded_scene and loaded_scene is PackedScene:
        model_instance = loaded_scene.instantiate()
        add_child(model_instance)
    else:
        printerr("Failed to load jump node model: ", model_path)

func _update_collision_shape():
    if not is_instance_valid(model_instance) or not is_instance_valid(collision_shape):
        _model_radius = 50.0 # Default if no model
        if is_instance_valid(collision_shape) and collision_shape.shape is SphereShape3D:
             (collision_shape.shape as SphereShape3D).radius = _model_radius
        return

    # Calculate radius from model's AABB
    var aabb = model_instance.get_aabb() # This gets the AABB in local space of the model
    _model_radius = aabb.get_longest_axis_size() / 2.0 * max(scale.x, max(scale.y, scale.z)) # Approximate radius

    if collision_shape.shape is SphereShape3D:
        (collision_shape.shape as SphereShape3D).radius = _model_radius
    else:
        # Create a new sphere shape if the current one isn't
        var sphere_shape = SphereShape3D.new()
        sphere_shape.radius = _model_radius
        collision_shape.shape = sphere_shape

func _update_display_properties():
    if not is_instance_valid(model_instance): return

    var use_color = (flags & 1) != 0
    var wireframe = not show_polys

    # Iterate through mesh instances within the loaded model scene
    for child in model_instance.find_children("*", "MeshInstance3D", true):
        var mesh_instance = child as MeshInstance3D
        for i in range(mesh_instance.get_surface_override_material_count()):
            var base_material = mesh_instance.get_surface_override_material(i)
            var material = null

            # Duplicate material to avoid modifying shared resources
            if base_material:
                material = base_material.duplicate() as StandardMaterial3D
            else:
                material = StandardMaterial3D.new() # Create new if none exists

            if use_color:
                material.albedo_color = display_color
            else:
                 # Reset to white or default texture color if needed
                 # This might require knowing the original material color
                 material.albedo_color = Color(1,1,1,1) # Default to white

            if wireframe:
                material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                material.albedo_color.a = 0.7 # Make slightly transparent
                # For actual wireframe, need a specific shader or different material setup
                # material.flags_wireframe = true # Not available in StandardMaterial3D
            else:
                material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL # Default shading
                material.albedo_color.a = 1.0 # Fully opaque

            mesh_instance.set_surface_override_material(i, material)


func _update_visibility():
    visible = not hidden

func get_radius() -> float:
    return _model_radius

func _on_body_entered(body: Node3D) -> void:
    if body is ShipBase:
        emit_signal("ship_entered", body)

```

```gdscript
# jump_node_manager.gd (Autoload/Singleton)
class_name JumpNodeManager extends Node

var jump_nodes: Dictionary = {}  # name -> JumpNode instance

func register_jump_node(node: JumpNode) -> void:
    if node == null or node.node_name.is_empty(): return
    if jump_nodes.has(node.node_name):
        printerr("Jump node name collision: ", node.node_name)
        # Handle collision? Overwrite or ignore?
    jump_nodes[node.node_name] = node

func unregister_jump_node(node: JumpNode) -> void:
    if node == null or node.node_name.is_empty(): return
    if jump_nodes.has(node.node_name) and jump_nodes[node.node_name] == node:
        jump_nodes.erase(node.node_name)

func get_jump_node_by_name(name: String) -> JumpNode:
    if jump_nodes.has(name):
        return jump_nodes[name]
    return null

func get_jump_node_for_ship(ship: ShipBase) -> JumpNode:
    if ship == null: return null
    # Check if ship is inside any jump node's collision area
    # This is now handled by the Area3D signal in jump_node.gd
    # This function might still be useful for querying without relying on signals
    for node in jump_nodes.values():
        if not is_instance_valid(node): continue
        var distance_sq = ship.global_position.distance_squared_to(node.global_position)
        var radius_sq = node.get_radius() * node.get_radius()
        if distance_sq <= radius_sq:
            return node
    return null

func get_all_jump_nodes() -> Array[JumpNode]:
    var nodes: Array[JumpNode] = []
    for node in jump_nodes.values():
        if is_instance_valid(node):
            nodes.append(node)
    return nodes

```

## 7. Lighting System

### Original Implementation

The lighting system in the original codebase (`lighting.cpp`):
- Manages different types of light sources: directional (`LT_DIRECTIONAL`), point (`LT_POINT`), and tube (`LT_TUBE`).
- Supports dynamic lighting with intensity and color (`light` struct).
- Handles light attenuation for point/tube lights using inner and outer radii (`rada`, `radb`).
- Provides global ambient (`Ambient_light`) and reflective (`Reflective_light`) lighting components.
- Supports specular highlights with separate RGB control (`spec_r`, `spec_g`, `spec_b`).
- Includes light filtering for performance optimization based on relevance to objects/areas (`light_filter_push`, `light_filter_push_box`, `light_filter_pop`).
- Uses two lighting modes: `LM_BRIGHTEN` (additive) and `LM_DARKEN` (subtractive, less common).
- Defines default ambient (0.15) and reflective (0.75) light values.
- Implements a light rotation system (`light_rotate`) to transform lights into the current view space (`Light_matrix`, `Light_base`).
- Supports special light effects for shockwaves and weapon impacts (implied, handled elsewhere but uses lighting functions).
- Includes performance optimizations like light filtering by distance and relevance.
- Allows lights to ignore specific objects (`light_ignore_objnum`) or only affect specific objects (`affected_objnum`).

### Godot Implementation

Godot handles most lighting via its built-in light nodes (DirectionalLight3D, OmniLight3D, SpotLight3D) and the WorldEnvironment node.

```gdscript
# space_lighting_manager.gd (Autoload/Singleton or added to main scene)
class_name SpaceLightingManager extends Node

# Default values mirroring original code
const AMBIENT_LIGHT_DEFAULT: float = 0.15
const REFLECTIVE_LIGHT_DEFAULT: float = 0.75 # Maps roughly to specular intensity/reflection probe energy

@export var environment_node: WorldEnvironment # Assign the main WorldEnvironment node in the editor

func _ready():
    if not environment_node:
        printerr("SpaceLightingManager requires a WorldEnvironment node assigned!")
        # Optionally create a default one if needed
        # environment_node = WorldEnvironment.new()
        # add_child(environment_node)
        # environment_node.environment = Environment.new()
        # set_ambient_light(AMBIENT_LIGHT_DEFAULT)
    else:
        # Ensure environment resource exists
        if environment_node.environment == null:
            environment_node.environment = Environment.new()
        set_ambient_light(AMBIENT_LIGHT_DEFAULT) # Set initial ambient light

# --- Functions to manipulate standard Godot lights ---

func add_directional_light(direction: Vector3, intensity: float, color: Color, shadow_enabled: bool = false) -> DirectionalLight3D:
    var godot_light = DirectionalLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.shadow_enabled = shadow_enabled
    # Set direction by rotating the light node
    godot_light.look_at(godot_light.global_position - direction, Vector3.UP)

    get_tree().current_scene.add_child(godot_light) # Add to scene root or appropriate parent
    return godot_light

func add_point_light(position: Vector3, range: float, intensity: float, color: Color, shadow_enabled: bool = false) -> OmniLight3D:
    # Note: Godot OmniLight uses range and attenuation curve, not separate inner/outer radii directly
    var godot_light = OmniLight3D.new()
    godot_light.light_color = color
    godot_light.light_energy = intensity
    godot_light.omni_range = range
    godot_light.omni_attenuation = 1.0 # Linear falloff, adjust curve as needed
    godot_light.global_position = position
    godot_light.shadow_enabled = shadow_enabled

    get_tree().current_scene.add_child(godot_light)
    return godot_light

func add_tube_light_simulated(start_pos: Vector3, end_pos: Vector3, range: float, intensity: float, color: Color, num_segments: int = 5) -> Array[OmniLight3D]:
    # Simulate tube light with multiple OmniLights
    var lights: Array[OmniLight3D] = []
    if num_segments <= 0: num_segments = 1

    for i in range(num_segments):
        var t = float(i) / float(num_segments - 1 if num_segments > 1 else 1)
        var pos = start_pos.lerp(end_pos, t)
        var light = add_point_light(pos, range, intensity / float(num_segments), color)
        lights.append(light)

    return lights

# --- Functions to control environment settings ---

func set_ambient_light(value: float) -> void:
    if environment_node and environment_node.environment:
        var clamped_value = clamp(value, 0.0, 1.0)
        environment_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        environment_node.environment.ambient_light_color = Color(clamped_value, clamped_value, clamped_value)
        environment_node.environment.ambient_light_energy = 1.0 # Control brightness via color here

func set_reflective_light(value: float) -> void:
    # This is less direct. Affects reflection probes, SSR, SDFGI, etc.
    # Might adjust reflection probe intensity or SSR settings.
    if environment_node and environment_node.environment:
         # Example: Adjust sky contribution or reflection intensity if using Sky/ReflectionProbe
         # environment_node.environment.ssr_enabled = value > 0.1
         # environment_node.environment.sky_contribution = value
         pass # Requires specific setup

func set_lighting_enabled(enabled: bool) -> void:
    # Iterate through all lights in the scene and toggle visibility
    for light in get_tree().get_nodes_in_group("space_lights"): # Add lights to a group
        if light is Light3D:
            light.visible = enabled

func reset_to_defaults() -> void:
    set_ambient_light(AMBIENT_LIGHT_DEFAULT)
    set_reflective_light(REFLECTIVE_LIGHT_DEFAULT) # Adjust based on how reflection is handled
    set_lighting_enabled(true)

```

## 8. Nebula System

### Original Implementation

The nebula system in the original codebase (`neb.cpp`, `neblightning.cpp`):
- Creates volumetric fog effects (`Neb2_render_mode`, `Neb2_fog_color_*`).
- Supports different nebula types implicitly through texture/poof selection.
- Handles dynamic fog color and intensity based on distance and settings.
- Includes lightning effects within nebulae (`neblightning.cpp`, `storm_type`, `bolt_type`).
- Manages performance optimization using detail levels (`Neb2_detail`, `Nd`) and culling.
- Supports AWACS gameplay mechanics (radar interference) via `Neb2_awacs` factor.
- Uses a cube-based system (`Neb2_cubes`, `Neb2_slices`) for rendering nebula "poofs" (`cube_poof`).
- Implements poof rotation (`rot`, `rot_speed`) and alpha blending based on distance and view angle (`neb2_get_alpha_2shell`, `neb2_get_alpha_offscreen`).
- Supports multiple poof bitmap types loaded from `nebula.tbl` (`Neb2_poof_filenames`, `Neb2_poofs`).
- Includes dynamic fog color calculation based on texture analysis (in HTL mode).
- Features a detail level system (`neb2_set_detail_level`).
- Implements special rendering for HTL (Hardware Transform & Lighting) mode using fog parameters.
- Provides fog distance calculations affecting object visibility (`neb2_get_fog_values`, `neb2_get_fog_intensity`).
- Includes a lightning storm system (`nebl_set_storm`, `nebl_process`) with configurable bolt types, frequency, and intensity (`Storm_types`, `Bolt_types`).
- Lightning bolts are generated procedurally (`nebl_gen`) and rendered as textured geometry (`nebl_render`).
- Lightning can cause EMP effects (`emp_intensity`, `emp_time`).

### Godot Implementation

Godot's WorldEnvironment node handles volumetric fog. Lightning can be implemented using custom particle systems, shaders, or procedurally generated meshes.

```gdscript
# nebula_manager.gd (Autoload/Singleton or added to main scene)
class_name NebulaManager extends Node

@export var environment_node: WorldEnvironment # Assign the main WorldEnvironment node

# Nebula properties (can be loaded from resources)
var enabled: bool = false
var fog_color: Color = Color(0.12, 0.2, 0.61)
var fog_density: float = 0.02
var fog_height: float = 1000.0 # For height fog
var fog_height_density: float = 0.1 # For height fog falloff
var fog_aerial_perspective: float = 0.1 # Controls color blending with distance

# AWACS effect properties
var awacs_factor: float = -1.0 # -1.0 means disabled

# Lightning storm properties
var storm_active: bool = false
var current_storm_type: Resource = null # Custom resource defining storm params
var next_lightning_time: float = 0.0
@export var lightning_bolt_scene: PackedScene # Scene for a single lightning bolt effect

func _ready():
    if not environment_node:
        printerr("NebulaManager requires a WorldEnvironment node assigned!")
        return
    if environment_node.environment == null:
        environment_node.environment = Environment.new()

    # Initial setup based on mission data or defaults
    update_fog_settings()

func set_nebula_properties(p_enabled: bool, p_color: Color, p_density: float, p_height: float = 1000.0, p_height_density: float = 0.1, p_aerial_perspective: float = 0.1, p_awacs: float = -1.0):
    enabled = p_enabled
    fog_color = p_color
    fog_density = p_density
    fog_height = p_height
    fog_height_density = p_height_density
    fog_aerial_perspective = p_aerial_perspective
    awacs_factor = p_awacs
    update_fog_settings()

func update_fog_settings():
    if not environment_node or not environment_node.environment: return

    var env = environment_node.environment
    env.volumetric_fog_enabled = enabled
    if enabled:
        env.volumetric_fog_density = fog_density
        env.volumetric_fog_albedo = fog_color # Albedo influences fog color
        env.volumetric_fog_emission = Color(0,0,0) # Can add glow
        env.volumetric_fog_emission_energy = 1.0
        # Adjust other volumetric fog params like anisotropy, detail spread, etc. as needed

        # Godot doesn't have direct height fog like the original,
        # but volumetric fog density can be controlled with FogVolume nodes
        # or a global shader. We can simulate height fog approximately.
        # env.fog_enabled = true # Standard fog (alternative or supplement)
        # env.fog_light_color = fog_color
        # env.fog_density = fog_density # Standard fog density
        # env.fog_height_enabled = true
        # env.fog_height_min = -fog_height / 2.0 # Example mapping
        # env.fog_height_max = fog_height / 2.0
        # env.fog_height_density = fog_height_density # Controls falloff

        env.adjustment_enabled = true # Needed for fog color influence
        env.adjustment_color_correction = null # Or use a correction curve

    # Update radar interference based on awacs_factor
    # This would likely involve signaling a RadarManager or similar system
    # RadarManager.set_interference(awacs_factor if enabled else 0.0)


func set_lightning_storm(storm_resource: Resource):
    if storm_resource == null:
        storm_active = false
        current_storm_type = null
        return

    current_storm_type = storm_resource # Assuming a custom StormType resource
    storm_active = true
    schedule_next_lightning()

func _process(delta: float):
    if storm_active and Time.get_ticks_msec() / 1000.0 >= next_lightning_time:
        trigger_lightning()
        schedule_next_lightning()

func schedule_next_lightning():
     if current_storm_type and current_storm_type.has_method("get_next_interval"):
        var interval = current_storm_type.get_next_interval() # Method in StormType resource
        next_lightning_time = Time.get_ticks_msec() / 1000.0 + interval
     else: # Default timing if resource method missing
         next_lightning_time = Time.get_ticks_msec() / 1000.0 + randf_range(5.0, 15.0)


func trigger_lightning():
    if not lightning_bolt_scene or not current_storm_type: return

    var num_bolts = 1
    if current_storm_type.has_method("get_bolt_count"):
        num_bolts = current_storm_type.get_bolt_count()

    for i in range(num_bolts):
        var bolt_instance = lightning_bolt_scene.instantiate()
        # Position the bolt randomly within the nebula bounds or based on storm logic
        var start_pos = Vector3(randf_range(-5000, 5000), randf_range(-2000, 2000), randf_range(-5000, 5000))
        var end_pos = start_pos + Vector3(randf_range(-1000, 1000), randf_range(-1000, 1000), randf_range(-1000, 1000))
        bolt_instance.global_position = start_pos # Or midpoint

        if bolt_instance.has_method("setup_bolt"):
             var bolt_type_index = 0 # Get from storm type resource
             if current_storm_type.has_method("get_random_bolt_type_index"):
                 bolt_type_index = current_storm_type.get_random_bolt_type_index()
             # Pass necessary parameters (start, end, type, etc.)
             bolt_instance.setup_bolt(start_pos, end_pos, bolt_type_index)

        get_tree().current_scene.add_child(bolt_instance)

        # Trigger EMP effect if applicable (needs EMP system)
        # var emp_intensity = get_bolt_emp_intensity(bolt_type_index)
        # if emp_intensity > 0:
        #    EmpManager.create_emp(start_pos.lerp(end_pos, 0.5), end_pos.distance_to(start_pos), emp_intensity, ...)

```

## 9. Physics Engine

### Original Implementation

The physics engine in the original codebase (`physics.cpp`):
- Implements Newtonian physics for ship movement (`physics_sim_vel`) and rotation (`physics_sim_rot`).
- Uses damping constants (`side_slip_time_const`, `rotdamp`) to control responsiveness.
- Supports different physics modes:
    - Normal flight: Standard damping and acceleration.
    - Glide (`PF_GLIDING`): Thrust disabled, velocity changes based on `glide_ramp`.
    - Afterburner (`PF_AFTERBURNER_ON`): Uses separate max velocities and acceleration constants.
    - Booster (`PF_BOOSTER_ON`): Similar to afterburner.
    - Special Warp (`PF_SPECIAL_WARP_IN`, `PF_SPECIAL_WARP_OUT`): Uses exponential velocity change.
    - Dead Drift (`PF_DEAD_DAMP`): High rotational damping, no velocity damping.
    - Constant Velocity (`PF_CONST_VEL`): No physics simulation, just moves along velocity vector.
- Handles ship rotation with damping and maximum rotation limits (`max_rotvel`).
- Implements velocity ramping (`velocity_ramp`) for smooth acceleration and deceleration based on time constants (`forward_accel_time_const`, `forward_decel_time_const`, etc.).
- Provides functions for applying external forces like impacts (`physics_apply_whack`) and shockwaves (`physics_apply_shock`).
- Supports special physics flags (`physics_info::flags`) for different movement states (sliding, reduced damping, shockwave).
- Includes a reduced damping system (`PF_REDUCED_DAMP`) triggered by impacts, increasing slide and reducing damping temporarily.
- Implements afterburner and booster physics with specific parameters.
- Provides functions for physics prediction (`physics_predict_pos`, `physics_predict_vel`).
- Includes a control system (`physics_read_flying_controls`) for translating player/AI input (`control_info`) to desired velocities and rotational velocities.
- Supports special movement modes like dead-drift and slide (`PF_SLIDE_ENABLED`).

### Godot Implementation

Godot's `RigidBody3D` with custom integration (`_integrate_forces`) is the primary tool.

```gdscript
# space_physics.gd - Attached to ShipBase (which inherits RigidBody3D)
class_name SpacePhysics extends RigidBody3D

# --- Exported Physics Properties (map from physics_info) ---
@export_group("Basic Movement")
@export var mass_override: float = 10.0 # Overrides RigidBody mass if needed
@export var linear_damp_override: float = 0.1 # Overrides RigidBody linear damp
@export var angular_damp_override: float = 0.5 # Overrides RigidBody angular damp

@export_group("Max Velocities")
@export var max_linear_velocity: Vector3 = Vector3(100, 100, 100)
@export var max_rear_velocity: float = 50.0
@export var max_angular_velocity: Vector3 = Vector3(2.0, 1.0, 2.0) # Radians/sec

@export_group("Acceleration & Damping")
@export var forward_accel_time: float = 1.0 # Time to reach max forward speed
@export var forward_decel_time: float = 1.5 # Time to stop from max forward speed
@export var slide_accel_time: float = 0.5  # Time to reach max side/vert speed
@export var slide_decel_time: float = 0.8  # Time to stop from max side/vert speed
@export var rotational_accel_time: float = 0.5 # Time to reach max rot speed
@export var rotational_damp_time: float = 0.3 # Time to stop rotating (like rotdamp)
@export var use_newtonian_damping: bool = false # If true, damping applies forward too

@export_group("Afterburner")
@export var ab_max_linear_velocity: Vector3 = Vector3(150, 150, 250)
@export var ab_max_rear_velocity: float = 0.0 # Usually no reverse AB
@export var ab_forward_accel_time: float = 0.5
@export var ab_forward_decel_time: float = 2.0 # Decel when AB turns off
@export var ab_slide_accel_time: float = 0.7
@export var ab_slide_decel_time: float = 1.0

# Add Booster properties similarly if needed...

@export_group("Special Modes")
@export var glide_accel_multiplier: float = 0.1 # How much control input affects glide
@export var glide_cap_speed: float = -1.0 # Max speed in glide, -1 uses normal max

# --- Internal State ---
var desired_linear_velocity: Vector3 = Vector3.ZERO
var desired_angular_velocity: Vector3 = Vector3.ZERO
var current_controls: Dictionary = {"forward": 0.0, "sideways": 0.0, "vertical": 0.0, "pitch": 0.0, "yaw": 0.0, "roll": 0.0}

var is_afterburner_on: bool = false
var is_gliding: bool = false
# Add flags for shockwave, reduced damp, etc. as needed

# Reduced Damping state
var reduced_damp_active: bool = false
var reduced_damp_end_time: float = 0.0
const REDUCED_DAMP_DURATION: float = 2.0 # Corresponds to REDUCED_DAMP_TIME
const REDUCED_DAMP_FACTOR: float = 5.0 # Multiplier for damping times

func _ready():
    # Apply overrides if set
    if mass_override > 0: mass = mass_override
    if linear_damp_override >= 0: linear_damp = linear_damp_override
    if angular_damp_override >= 0: angular_damp = angular_damp_override
    # Set physics process to true if not already
    set_physics_process(true)
    # Use custom integrator
    custom_integrator = true

func set_controls(controls: Dictionary):
    current_controls = controls
    # Example: current_controls = {"forward": 1.0, "pitch": -0.5, ...}

func set_afterburner(active: bool):
    is_afterburner_on = active

func set_gliding(active: bool):
    is_gliding = active

func apply_whack(impulse: Vector3, position_local: Vector3):
    apply_impulse(impulse, position_local)
    # Trigger reduced damping
    reduced_damp_active = true
    reduced_damp_end_time = Time.get_ticks_msec() / 1000.0 + REDUCED_DAMP_DURATION # Simple duration for now
    # Original code scaled duration by impulse magnitude, could add that

func _integrate_forces(state: PhysicsDirectBodyState3D):
    # 1. Calculate Target Velocities based on Controls and Mode
    var target_lin_vel_local = Vector3.ZERO
    var target_ang_vel_local = Vector3.ZERO

    var current_max_lin_vel = ab_max_linear_velocity if is_afterburner_on else max_linear_velocity
    var current_max_rear_vel = ab_max_rear_velocity if is_afterburner_on else max_rear_velocity
    var current_forward_accel = ab_forward_accel_time if is_afterburner_on else forward_accel_time
    var current_forward_decel = ab_forward_decel_time if is_afterburner_on else forward_decel_time
    var current_slide_accel = ab_slide_accel_time if is_afterburner_on else slide_accel_time
    var current_slide_decel = ab_slide_decel_time if is_afterburner_on else slide_decel_time

    target_lin_vel_local.x = current_controls.sideways * current_max_lin_vel.x
    target_lin_vel_local.y = current_controls.vertical * current_max_lin_vel.y
    target_lin_vel_local.z = current_controls.forward * (current_max_lin_vel.z if current_controls.forward >= 0 else current_max_rear_vel)

    target_ang_vel_local.x = -current_controls.pitch * max_angular_velocity.x # Invert pitch for Godot convention
    target_ang_vel_local.y = -current_controls.yaw * max_angular_velocity.y   # Invert yaw
    target_ang_vel_local.z = -current_controls.roll * max_angular_velocity.z  # Invert roll

    # 2. Get Current Velocities (in local space)
    var current_lin_vel_local = state.transform.basis.inverse() * state.linear_velocity
    var current_ang_vel_local = state.transform.basis.inverse() * state.angular_velocity

    # 3. Calculate Acceleration/Damping Times based on state
    var lin_accel_times = Vector3(slide_accel_time, slide_accel_time, forward_accel_time)
    var lin_decel_times = Vector3(slide_decel_time, slide_decel_time, forward_decel_time)
    if is_afterburner_on:
        lin_accel_times = Vector3(ab_slide_accel_time, ab_slide_accel_time, ab_forward_accel_time)
        lin_decel_times = Vector3(ab_slide_decel_time, ab_slide_decel_time, ab_forward_decel_time)

    var ang_accel_time = rotational_accel_time
    var ang_damp_time = rotational_damp_time

    # Apply reduced damping if active
    if reduced_damp_active:
        var time_now = Time.get_ticks_msec() / 1000.0
        if time_now >= reduced_damp_end_time:
            reduced_damp_active = false
        else:
            var factor = REDUCED_DAMP_FACTOR # Simplified for now
            lin_accel_times *= factor
            lin_decel_times *= factor
            ang_accel_time *= factor
            ang_damp_time *= factor


    # 4. Calculate desired velocity change using interpolation (like apply_physics)
    var final_lin_vel_local = Vector3.ZERO
    var final_ang_vel_local = Vector3.ZERO

    for i in range(3):
        var accel_t = lin_accel_times[i]
        var decel_t = lin_decel_times[i]
        var target_v = target_lin_vel_local[i]
        var current_v = current_lin_vel_local[i]
        var time_const = 0.0

        if abs(target_v) > 0.001: # Accelerating towards a target
            time_const = accel_t if (abs(target_v) >= abs(current_v)) else decel_t
        else: # Decelerating to zero
            time_const = decel_t

        if is_gliding and i < 2: # Side/Vert glide
             final_lin_vel_local[i] = current_v + (target_v * glide_accel_multiplier * state.step) # Simplified glide impulse
        elif time_const > 0.001:
            final_lin_vel_local[i] = lerp(current_v, target_v, 1.0 - exp(-state.step / time_const))
        else:
            final_lin_vel_local[i] = target_v # Instant change if time const is near zero

        # Angular velocity
        target_v = target_ang_vel_local[i]
        current_v = current_ang_vel_local[i]
        time_const = ang_accel_time if abs(target_v) >= abs(current_v) else ang_damp_time

        if time_const > 0.001:
            final_ang_vel_local[i] = lerp(current_v, target_v, 1.0 - exp(-state.step / time_const))
        else:
            final_ang_vel_local[i] = target_v


    # Special handling for forward velocity in glide mode
    if is_gliding:
        var target_forward = target_lin_vel_local.z
        var current_forward = current_lin_vel_local.z
        var forward_impulse = target_forward * glide_accel_multiplier * state.step
        final_lin_vel_local.z = current_forward + forward_impulse
        # Apply glide cap
        var cap = glide_cap_speed if glide_cap_speed >= 0 else current_max_lin_vel.z
        if final_lin_vel_local.z > cap:
            final_lin_vel_local.z = cap


    # 5. Convert local velocities back to world space and apply
    state.linear_velocity = state.transform.basis * final_lin_vel_local
    state.angular_velocity = state.transform.basis * final_ang_vel_local

    # Clamp velocities (optional, Godot might handle this)
    # state.linear_velocity = state.linear_velocity.limit_length(current_max_lin_vel.z) # Example clamp
    # state.angular_velocity = state.angular_velocity.limit_length(max_angular_velocity.length())

```

## 10. Particle System

### Original Implementation

The particle system in the original codebase (`particle.cpp`):
- Provides a general-purpose particle effect framework (`particle` struct).
- Supports different particle types (`PARTICLE_DEBUG`, `PARTICLE_BITMAP`, `PARTICLE_FIRE`, `PARTICLE_SMOKE`, etc.).
- Manages particle creation (`particle_create`), movement (`particle_move_all`), and rendering (`particle_render_all`).
- Handles particle lifetime (`age`, `max_life`) and aging.
- Supports particle attachment to objects (`attached_objnum`, `attached_sig`).
- Includes particle emitters (`particle_emitter`, `particle_emit`) for continuous effects, adjusting particle count based on detail level and distance.
- Implements performance optimizations like culling (implicit through checks) and potentially batching (mentioned in comments, `batch_add_bitmap`).
- Provides particle animation through frame sequences using animated bitmaps (`bm_load_animation`, `nframes`).
- Supports different rendering modes (billboards, 3D billboards `PARTICLE_BITMAP_3D`) and alpha blending (`get_current_alpha`).
- Includes tracer effects for projectiles (`tracer_length`).
- Uses a dynamic vector (`Particles`) to store active particles.

### Godot Implementation

Godot's `GPUParticles3D` and `CPUParticles3D` nodes are the primary tools. Emitters can be separate nodes or managed by scripts.

```gdscript
# particle_manager.gd (Autoload/Singleton)
class_name ParticleManager extends Node

# Particle type constants (map to preloaded scenes or resources)
enum ParticleType {
    DEBUG, # Might not be needed, use Godot debug tools
    FIRE,
    SMOKE,
    SMOKE2,
    GENERIC_BITMAP, # For various bitmap effects
    TRACER,
    ATTACHED_EFFECT # Example for effects attached to ships
}

# Preload particle scenes
@export var particle_scenes: Dictionary = {
    ParticleType.FIRE: preload("res://scenes/effects/particles_fire.tscn"),
    ParticleType.SMOKE: preload("res://scenes/effects/particles_smoke.tscn"),
    ParticleType.SMOKE2: preload("res://scenes/effects/particles_smoke2.tscn"),
    ParticleType.GENERIC_BITMAP: preload("res://scenes/effects/particles_generic.tscn"),
    ParticleType.TRACER: preload("res://scenes/effects/particles_tracer.tscn"),
    ParticleType.ATTACHED_EFFECT: preload("res://scenes/effects/particles_attached.tscn")
}

# Configuration
var particles_enabled: bool = true # Can be toggled via GameSettings

# Create a particle effect instance
# Uses simplified parameters compared to original 'particle_create'
func create_particle_effect(position: Vector3, type: ParticleType, scale: float = 1.0, velocity: Vector3 = Vector3.ZERO, attached_node: Node3D = null, lifetime_override: float = -1.0):
    if not particles_enabled or not particle_scenes.has(type):
        return null

    var scene = particle_scenes[type]
    var particle_node = scene.instantiate() # Should be GPUParticles3D or CPUParticles3D

    # Add to the scene tree
    if attached_node and is_instance_valid(attached_node):
        attached_node.add_child(particle_node)
        particle_node.global_position = attached_node.global_position # Start at parent
        # If the particle system shouldn't inherit parent transform, set top_level = true
        # particle_node.top_level = true
        # particle_node.global_position = position # Then set global position
    else:
        get_tree().current_scene.add_child(particle_node) # Add to scene root
        particle_node.global_position = position

    # Configure the particle node
    particle_node.scale = Vector3.ONE * scale
    particle_node.emitting = true # Start emitting

    # Apply lifetime override if provided
    if lifetime_override > 0:
        particle_node.lifetime = lifetime_override

    # If it's a physics-based particle system (less common), apply velocity
    # if particle_node is RigidBody3D:
    #    particle_node.linear_velocity = velocity

    # Set one-shot if it's not a continuous effect
    if not particle_node.explosiveness > 0.99: # Check if it's likely a one-shot effect
         particle_node.one_shot = true
         # Optionally queue_free after lifetime (or use a timer)
         var timer = Timer.new()
         timer.wait_time = particle_node.lifetime * 1.2 # Add buffer
         timer.one_shot = true
         timer.timeout.connect(particle_node.queue_free)
         particle_node.add_child(timer)
         timer.start()


    return particle_node


# Create particles using an emitter definition (closer to original particle_emit)
func emit_particles(emitter_resource: ParticleEmitterResource, position: Vector3, normal: Vector3, base_velocity: Vector3 = Vector3.ZERO):
     if not particles_enabled or not emitter_resource: return

     # Calculate number based on detail level (from GameSettings) and distance
     var detail_level = GameSettings.get_particle_detail() # 0, 1, 2 etc.
     var percent = get_percent_from_detail(detail_level) # Map detail level to %

     var dist_sq = position.distance_squared_to(PlayerCamera.global_position) # Assuming global PlayerCamera
     var min_dist_sq = 125.0 * 125.0
     if dist_sq > min_dist_sq:
         percent = int(float(percent) * sqrt(min_dist_sq / dist_sq)) # Adjust by distance ratio
         if percent < 1: return

     var num_to_emit = randi_range(
         (emitter_resource.num_low * percent) / 100,
         (emitter_resource.num_high * percent) / 100
     )

     if num_to_emit < 1: return

     # Get the correct particle scene based on the emitter resource
     if not particle_scenes.has(emitter_resource.particle_type): return
     var scene = particle_scenes[emitter_resource.particle_type]

     for i in range(num_to_emit):
         var particle_node = scene.instantiate() # GPUParticles3D or CPUParticles3D
         get_tree().current_scene.add_child(particle_node)
         particle_node.global_position = position

         # Calculate individual particle properties based on emitter variance
         var particle_normal = normal.lerp(Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)).normalized(), emitter_resource.normal_variance).normalized()
         var radius = randf_range(emitter_resource.min_radius, emitter_resource.max_radius)
         var speed = randf_range(emitter_resource.min_velocity, emitter_resource.max_velocity)
         var life = randf_range(emitter_resource.min_life, emitter_resource.max_life)
         var velocity = base_velocity + particle_normal * speed

         # Configure the instance
         particle_node.scale = Vector3.ONE * radius # Might need adjustment based on how radius maps to scale
         particle_node.lifetime = life
         particle_node.emitting = true
         particle_node.one_shot = true # Emitters usually create one-shot particles

         # Apply initial velocity if the particle system uses it (less common for GPU particles)
         # if particle_node.process_material is ParticleProcessMaterial:
         #    particle_node.process_material.initial_velocity_min = velocity
         #    particle_node.process_material.initial_velocity_max = velocity

         # Auto-cleanup
         var timer = Timer.new()
         timer.wait_time = life * 1.2
         timer.one_shot = true
         timer.timeout.connect(particle_node.queue_free)
         particle_node.add_child(timer)
         timer.start()

# Helper to map detail level to percentage (adjust as needed)
func get_percent_from_detail(level: int) -> int:
    match level:
        0: return 25
        1: return 50
        2: return 75
        3: return 100
        _: return 100

```

```gdscript
# particle_emitter_resource.gd - Custom resource for emitter definitions
class_name ParticleEmitterResource extends Resource

@export var particle_type: ParticleManager.ParticleType = ParticleManager.ParticleType.GENERIC_BITMAP

@export_group("Emission Count")
@export var num_low: int = 1
@export var num_high: int = 5

@export_group("Lifetime")
@export var min_life: float = 1.0
@export var max_life: float = 3.0

@export_group("Velocity & Direction")
@export var normal_variance: float = 0.5 # 0 = no variance, 1 = full random deviation
@export var min_velocity: float = 1.0 # Speed along normal
@export var max_velocity: float = 5.0

@export_group("Size")
@export var min_radius: float = 0.5
@export var max_radius: float = 2.0

# Add other properties as needed (e.g., color variance)
```

## 11. Starfield System

### Original Implementation

The starfield system in the original codebase (`starfield.cpp`, `nebula.cpp` for background):
- Renders a dynamic starfield background with thousands of point stars (`Stars`, `MAX_STARS`).
- Supports star movement with tail effects based on camera movement (`Star_flags & STAR_FLAG_TAIL`, `Star_amount`, `Star_max_length`).
- Manages star colors, brightness, and density (`star_colors`, `star_aacolors`, `Star_dim`, `Star_cap`).
- Includes a bitmap-based starfield for more detailed backgrounds using potentially multiple layers with parallax (`Starfield_bitmaps`, `Starfield_bitmap_instances`).
- Handles loading and management of sun bitmaps (`Sun_bitmaps`, `Suns`) with glow effects (`glow_bitmap`).
- Implements lens flare effects for suns (`flare`, `flare_infos`, `flare_bitmaps`).
- Provides a system for loading and managing starfield bitmaps from tables (`parse_startbl`, `stars.tbl`).
- Supports different star rendering modes (points, tails, anti-aliased - `Star_flags`).
- Includes configurable star parameters (`Num_stars`, `Star_dim`, `Star_cap`, `Star_max_length`).
- Manages star movement relative to the camera and handles camera cuts (`stars_camera_cut`, `last_star_pos`).
- Implements background model rendering for skyboxes (`Nmodel_num`, `Nmodel_bitmap`, `stars_set_background_model`).
- Supports dynamic environment changes (`Dynamic_environment`).
- Includes a separate nebula rendering system (`nebula.cpp`, `nebula_render`) which can be layered with the starfield.
- Manages small debris particles (`odebris`, `Debris_vclips`) moving in the background.
- Supports subspace warp visual effects (`subspace_render`, `Subspace_model_inner`, `Subspace_model_outer`).
- Handles supernova effects (`supernova.cpp`, `supernova_process`).
- Uses perspective projection for background bitmaps (`g3_draw_perspective_bitmap`, `starfield_create_perspective_bitmap_buffer`).
- Optimizes bitmap rendering using vertex buffers (`perspective_bitmap_buffer`).

### Godot Implementation

Godot's WorldEnvironment with a PanoramaSkyMaterial or ProceduralSkyMaterial is suitable for backgrounds. Point stars can be particles or a custom shader. Background bitmaps can be layered quads or part of the sky material.

```gdscript
# starfield_manager.gd (Autoload/Singleton or attached to WorldEnvironment)
class_name StarfieldManager extends Node

@export var environment_node: WorldEnvironment # Assign the main WorldEnvironment

# Starfield configuration (can be loaded from resources)
@export var num_stars: int = 500
@export var star_tail_amount: float = 0.75  # Tail effect amount (if using custom shader/particles)
@export var star_dim_distance: float = 7800.0   # Distance for dimming (if using custom shader/particles)
@export var star_min_brightness: float = 0.3     # Minimum brightness (0-1)
@export var star_max_tail_length: float = 50.0 # Max tail length in pixels (if using custom shader/particles)
@export var enable_star_tails: bool = true
@export var enable_star_dimming: bool = true

# Background settings
@export var sky_material: PanoramaSkyMaterial = null # Assign in editor or load
@export var background_model_scene: PackedScene = null # For skybox model
var background_model_instance: Node3D = null

# Sun and bitmap instances (managed dynamically)
var sun_instances: Array[Node3D] = [] # Nodes representing suns (e.g., Sprite3D or MeshInstance)
var bitmap_instances: Array[Node3D] = [] # Nodes for background bitmaps

# Point star particles (optional, could be part of sky shader)
@export var star_particle_system: GPUParticles3D # Assign in editor if using particles

func _ready():
    if not environment_node:
        printerr("StarfieldManager needs WorldEnvironment assigned!")
        return
    if environment_node.environment == null:
        environment_node.environment = Environment.new()

    if sky_material:
        environment_node.environment.sky = Sky.new()
        environment_node.environment.sky.sky_material = sky_material
    elif background_model_scene:
        setup_background_model(background_model_scene)
    else:
        # Default procedural sky or solid color
        environment_node.environment.background_mode = Environment.BG_COLOR
        environment_node.environment.background_color = Color.BLACK

    # Initialize point stars if using particle system
    if star_particle_system:
        setup_point_stars()

    # Load initial background configuration (suns, bitmaps) based on mission data
    load_background_config(0) # Load default or first background

func setup_point_stars():
    if not star_particle_system: return
    # Configure star_particle_system properties based on exports
    # Example: Set amount, lifetime, draw passes (for tails), material shader params
    star_particle_system.amount = num_stars
    # Need a custom shader material on the particles for dimming/tails
    var mat = star_particle_system.process_material as ParticleProcessMaterial
    if mat and mat.shader:
         mat.set_shader_parameter("enable_tails", enable_star_tails)
         mat.set_shader_parameter("enable_dimming", enable_star_dimming)
         mat.set_shader_parameter("tail_amount", star_tail_amount)
         mat.set_shader_parameter("dim_distance", star_dim_distance)
         mat.set_shader_parameter("min_brightness", star_min_brightness)
         # The shader would need to calculate position based on camera movement for tails

func setup_background_model(scene: PackedScene, texture: Texture = null):
    if background_model_instance and is_instance_valid(background_model_instance):
        background_model_instance.queue_free()

    if scene == null:
        background_model_instance = null
        # Optionally revert to panorama sky or color background
        if environment_node and environment_node.environment:
            environment_node.environment.background_mode = Environment.BG_COLOR # Or BG_SKY
        return

    background_model_instance = scene.instantiate()
    # Add as child of camera or at origin, ensuring it doesn't move with player
    # Typically, make it a child of the WorldEnvironment node or scene root
    add_child(background_model_instance) # Or get_tree().current_scene.add_child()

    # Apply texture if provided
    if texture:
        for child in background_model_instance.find_children("*", "MeshInstance3D", true):
            var mesh_instance = child as MeshInstance3D
            var material = StandardMaterial3D.new()
            material.albedo_texture = texture
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            material.cull_mode = BaseMaterial3D.CULL_DISABLED # Render inside
            mesh_instance.material_override = material

    # Set environment background to clear/canvas to see the model
    if environment_node and environment_node.environment:
        environment_node.environment.background_mode = Environment.BG_CANVAS # Or BG_CLEAR_COLOR

func load_background_config(config_index: int):
    # Clear existing dynamic elements
    for sun in sun_instances: sun.queue_free()
    sun_instances.clear()
    for bm in bitmap_instances: bm.queue_free()
    bitmap_instances.clear()

    if config_index < 0 or config_index >= Backgrounds.size(): return # Assuming Backgrounds is loaded globally

    var config = Backgrounds[config_index]

    # Create suns
    for sun_data in config.suns:
        create_sun(sun_data)

    # Create background bitmaps
    for bitmap_data in config.bitmaps:
        create_background_bitmap(bitmap_data)

func create_sun(sun_data: Dictionary): # Assuming sun_data is a dictionary or resource
    var sun_scene = load("res://scenes/effects/sun_instance.tscn") # Example scene for a sun
    var sun_node = sun_scene.instantiate()
    add_child(sun_node) # Add to starfield manager or scene root
    sun_instances.append(sun_node)

    # Position and configure the sun based on sun_data (angles, texture, glow, flare)
    if sun_node.has_method("setup_sun"):
        sun_node.setup_sun(sun_data)

func create_background_bitmap(bitmap_data: Dictionary):
     var bitmap_node = MeshInstance3D.new() # Use a QuadMesh or Sprite3D
     var quad = QuadMesh.new()
     quad.size = Vector2(1000, 1000) # Adjust size as needed
     bitmap_node.mesh = quad

     var material = StandardMaterial3D.new()
     material.albedo_texture = load(bitmap_data.texture_path) # Assuming path in data
     material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if bitmap_data.get("transparent", true) else BaseMaterial3D.TRANSPARENCY_DISABLED
     material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
     material.cull_mode = BaseMaterial3D.CULL_DISABLED
     bitmap_node.material_override = material

     add_child(bitmap_node) # Add to starfield manager or scene root
     bitmap_instances.append(bitmap_node)

     # Position and orient based on bitmap_data (angles, scale, divisions)
     # This requires converting angles to rotation and applying scale
     # Divisions might imply using a subdivided mesh or shader for warping effects
     var basis = Basis.from_euler(Vector3(bitmap_data.ang_p, bitmap_data.ang_h, bitmap_data.ang_b))
     bitmap_node.global_transform.basis = basis
     bitmap_node.scale = Vector3(bitmap_data.scale_x, bitmap_data.scale_y, 1.0)
     # Position far away
     bitmap_node.global_position = -basis.z * 5000.0 # Example distance


func _process(delta: float):
    # Update star particle shader parameters if needed (e.g., camera velocity for tails)
    if star_particle_system and star_particle_system.process_material is ShaderMaterial:
        # Pass camera velocity or other relevant data to the shader
        # star_particle_system.process_material.set_shader_parameter("camera_velocity", PlayerCamera.get_velocity())
        pass

    # Update animated background bitmaps/suns
    # This might involve updating UV offsets or material parameters over time

func camera_cut():
    # Reset state for effects like star tails if needed
    if star_particle_system:
        star_particle_system.restart() # Restart particles to reset tails

```

## 12. Supernova Effects

### Original Implementation

The supernova system (`supernova.cpp`):
- Manages the timing and stages of a supernova event (`Supernova_time_total`, `Supernova_time`, `Supernova_status`).
- Triggers sounds at specific times (`SUPERNOVA_SOUND_1_TIME`, `SUPERNOVA_SOUND_2_TIME`).
- Controls camera behavior during the event (`supernova_camera_cut`, `supernova_get_eye`).
- Spawns particles on the player ship (`supernova_do_particles`).
- Fades the screen to white (`Supernova_fade_to_white`).
- Triggers end-of-mission popups or campaign end (`Supernova_popup`, `popupdead_start`, `gameseq_post_event`).
- Scales the sun's visual size (`SUPERNOVA_SUN_SCALE`).
- Includes screen shake effects (`sn_shudder`).

### Godot Implementation

This can be managed by a dedicated scene or script, likely triggered by mission events.

```gdscript
# supernova_manager.gd (Autoload/Singleton or scene added during mission)
class_name SupernovaManager extends Node

enum Status { NONE, STARTED, CAMERA_CUT, HIT, FADING, FINISHED }

var status: Status = Status.NONE
var time_total: float = -1.0
var time_left: float = -1.0
var fade_to_white_progress: float = 0.0
var popup_shown: bool = false
var particle_timer: Timer
var camera_cut_triggered: bool = false

# Sound flags
var sound1_played: bool = false
var sound2_played: bool = false

# Configurable times
const SOUND_1_TIME: float = 15.0
const SOUND_2_TIME: float = 5.0
const CUT_TIME: float = 5.0 # When camera focuses and particles start
const CAMERA_MOVE_TIME: float = 2.0 # Duration of camera move
const FADE_START_TIME: float = 0.0 # Time left when fade begins (end of countdown)
const FADE_DURATION: float = 1.0 # Duration of fade to white

# References (set externally or via get_node)
var player_ship: ShipBase = null
var sun_node: Node3D = null # The sun visual node
var fade_rect: ColorRect = null # A full-screen ColorRect for fading

func start_supernova(duration_seconds: float):
    if duration_seconds < CUT_TIME or status != Status.NONE:
        return

    print("Supernova started! Duration: ", duration_seconds)
    time_total = duration_seconds
    time_left = duration_seconds
    status = Status.STARTED
    popup_shown = false
    fade_to_white_progress = 0.0
    camera_cut_triggered = false
    sound1_played = false
    sound2_played = false

    # Find player and sun
    player_ship = get_tree().get_first_node_in_group("player_ship") as ShipBase
    # Find sun node (needs a reliable way, maybe group or name)
    # sun_node = get_tree().get_nodes_in_group("sun")[0] if get_tree().has_group("sun") else null

    # Setup particle timer
    if particle_timer == null:
        particle_timer = Timer.new()
        particle_timer.wait_time = 0.1 # Adjust frequency (original was 100ms)
        particle_timer.timeout.connect(_on_particle_timer_timeout)
        add_child(particle_timer)
    # Timer starts when status becomes HIT

    # Setup fade rect
    if fade_rect == null:
        fade_rect = ColorRect.new()
        fade_rect.color = Color(1, 1, 1, 0) # Start transparent white
        fade_rect.anchors_preset = Control.PRESET_FULL_RECT
        fade_rect.visible = false
        # Add to a high canvas layer
        var canvas = CanvasLayer.new()
        canvas.layer = 10 # Ensure it's on top
        canvas.add_child(fade_rect)
        add_child(canvas) # Add canvas layer to manager

    set_process(true)

func _process(delta: float):
    if status == Status.NONE or status == Status.FINISHED:
        set_process(false)
        return

    time_left -= delta

    # --- Update Status ---
    if time_left <= FADE_START_TIME and status < Status.FADING:
        status = Status.FADING
        if particle_timer.is_stopped(): # Ensure particles stop if timer was running
             particle_timer.stop()
        fade_rect.visible = true
        print("Supernova: Fading to white")
    elif time_left <= CUT_TIME and status < Status.HIT:
        status = Status.HIT
        if particle_timer.is_stopped(): # Start particles
             particle_timer.start()
        print("Supernova: Impact stage")
    elif time_left <= CUT_TIME + CAMERA_MOVE_TIME and status < Status.CAMERA_CUT:
         status = Status.CAMERA_CUT
         camera_cut_triggered = true # Signal camera manager
         print("Supernova: Camera cut stage")


    # --- Handle Effects based on Status ---
    match status:
        Status.STARTED:
            # Play sounds based on time left
            if time_left <= SOUND_1_TIME and not sound1_played:
                sound1_played = true
                SoundManager.play_sound("supernova_1") # Assuming SoundManager
                print("Supernova: Sound 1 played")
            if time_left <= SOUND_2_TIME and not sound2_played:
                sound2_played = true
                SoundManager.play_sound("supernova_2")
                print("Supernova: Sound 2 played")
            # Scale sun (needs reference to sun node and its original scale)
            if sun_node:
                 var pct = (time_total - time_left) / time_total
                 var scale_mult = 1.0 + (3.0 * pct) # SUPERNOVA_SUN_SCALE
                 # sun_node.scale = original_sun_scale * scale_mult
                 pass

        Status.CAMERA_CUT:
             # Camera manager should handle the move over CAMERA_MOVE_TIME
             # Continue scaling sun
             if sun_node:
                 var pct = (time_total - time_left) / time_total
                 var scale_mult = 1.0 + (3.0 * pct)
                 # sun_node.scale = original_sun_scale * scale_mult
                 pass

        Status.HIT:
            # Particles are handled by timer timeout
            # Screen shake (needs camera manager)
            # CameraManager.apply_shake(0.45) # sn_shudder
            pass

        Status.FADING:
            fade_to_white_progress += delta / FADE_DURATION
            fade_to_white_progress = clamp(fade_to_white_progress, 0.0, 1.0)
            if fade_rect:
                fade_rect.color.a = fade_to_white_progress
            if fade_to_white_progress >= 1.0 and not popup_shown:
                 show_end_popup()

        Status.FINISHED:
            # Handled by show_end_popup or external logic
            pass


func _on_particle_timer_timeout():
    if status != Status.HIT or not is_instance_valid(player_ship):
        particle_timer.stop()
        return

    # Simplified particle emission - replace with ParticleManager call
    var particle_count = randi_range(2, 5)
    var sun_pos = Vector3.FORWARD * 10000 # Get actual sun pos
    if sun_node: sun_pos = sun_node.global_position

    var direction_to_player = (player_ship.global_position - sun_pos).normalized()

    for i in range(particle_count):
        # Get random points on ship mesh (simplified)
        var offset = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
        var emit_pos = player_ship.global_position + offset

        ParticleManager.create_particle_effect(
            emit_pos,
            ParticleManager.ParticleType.FIRE,
            randf_range(0.5, 1.25), # radius/scale
            player_ship.linear_velocity + direction_to_player * randf_range(25.0, 50.0), # velocity
            null, # attached node
            randf_range(0.6, 1.0) # lifetime
        )


func show_end_popup():
    if popup_shown: return
    popup_shown = true
    status = Status.FINISHED
    set_process(false)
    if particle_timer.is_inside_tree() and not particle_timer.is_stopped():
        particle_timer.stop()
    print("Supernova: Finished, showing popup")

    # Check campaign status
    # if Campaign.is_campaign_active() and Campaign.should_end_in_mission():
    #    get_tree().change_scene_to_file("res://scenes/ui/campaign_end_screen.tscn") # Example
    # else:
    #    # Show standard mission failed/debriefing popup
    #    PopupManager.show_popup("Mission Failed", "Caught in supernova!") # Example
    #    # Or trigger mission end sequence
    #    MissionManager.end_mission(false) # Fail the mission
    pass # Replace with actual game sequence/popup logic

func is_active() -> bool:
    return status != Status.NONE and status != Status.FINISHED

func get_status() -> Status:
    return status

func get_fade_alpha() -> float:
    return fade_to_white_progress

func should_camera_cut() -> bool:
    return camera_cut_triggered

```

## Integration with Other Systems

- **Physics Engine:** Provides movement data for all space objects (ships, asteroids, debris, weapons). Collision detection is crucial.
- **Object System:** Manages the creation, deletion, and tracking of all game entities.
- **Ship System:** Interacts heavily with Physics (movement), Debris (creation), Fireball (explosions), Decals (damage), Warp Effects, Jump Nodes, Lighting, Particles (engine trails, damage).
- **Weapon System:** Uses Fireball (impacts), Particles (trails), Lighting (muzzle flash), Physics (projectile movement).
- **Mission System:** Triggers events related to these systems (spawning asteroids, jump node activation, supernova).
- **Graphics System:** Renders all visual elements, including starfields, nebulae, particles, fireballs, decals.

This refined structure provides a more detailed overview based on the original C++ implementation for each system.
