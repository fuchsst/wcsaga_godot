# Wing Commander Saga: Godot Conversion Analysis - Component 11: Model System

This document analyzes the "Model System" component of the original Wing Commander Saga C++ codebase, based on the code snippets provided, and outlines its conversion strategy for Godot. This component is tightly coupled with Core Systems (Object Management), Physics (Collision), Ship Systems (Docking, Subsystems), and Graphics (Rendering).

## III.B. Detailed Code Analysis (Model System & Related Object Logic)

Based on the provided code snippets in `migration_tools/wcsaga_code/11_model/object.md` and `migration_tools/wcsaga_code/11_model/model.md`.

**1. Identify Key Features:**

*   **Object Representation:** Defines the core `object` structure containing position, orientation, physics info, type, instance data, parent linkage, flags, shield/hull strength, sound handles, and docking information. (From `object.md`)
*   **Object Lifecycle Management:** Handles creation (`obj_create`), deletion (`obj_delete`), tracking used/free objects (`obj_used_list`, `obj_free_list`), and signature management. (From `object.md`)
*   **Model Data Structure (`polymodel`):**
    *   Core structure holding all model data (`model.h`).
    *   Contains version, filename, flags (`PM_FLAG_ALLOW_TILING`, `PM_FLAG_AUTOCEN`).
    *   Manages multiple detail levels (`n_detail_levels`, `detail`, `detail_depth`).
    *   Stores debris object information (`num_debris_objects`, `debris_objects`).
    *   Holds submodel data (`n_models`, `bsp_info* submodel`).
    *   Defines bounding boxes (`mins`, `maxs`, `bounding_box`) and radius (`rad`, `core_radius`).
    *   Manages textures (`n_textures`, `texture_map maps[]`), including base, glow, specular, normal, height maps (`texture_info`, `texture_map`). Texture animation support (`num_frames`, `total_time`).
    *   Stores lighting information (`num_lights`, `bsp_light* lights`).
    *   Defines viewpoints (`n_view_positions`, `eye view_positions`).
    *   Contains weapon mount points (`n_guns`, `n_missiles`, `w_bank* gun_banks`, `missile_banks`).
    *   Defines docking points (`n_docks`, `dock_bay* docking_bays`).
    *   Stores thruster information (`n_thrusters`, `thruster_bank* thrusters`).
    *   Includes shield mesh data (`shield_info shield`, `shield_collision_tree`).
    *   Defines paths for AI/scripting (`n_paths`, `model_path* paths`).
    *   Stores physical properties (`mass`, `center_of_mass`, `moment_of_inertia`).
    *   Uses octants for spatial partitioning (`model_octant octants[8]`).
    *   Stores cross-section data (`num_xc`, `cross_section* xc`).
    *   Manages insignias (`num_ins`, `insignia ins[]`).
    *   Includes glow point banks (`n_glow_point_banks`, `glow_point_bank* glow_point_banks`).
*   **Submodel Data Structure (`bsp_info`):**
    *   Represents individual parts of a model (`model.h`).
    *   Contains name, movement type/axis, offset, orientation, BSP data (`bsp_data`), geometric center, radius, bounding box.
    *   Tracks state (`blown_off`, `is_damaged`).
    *   Manages parent/child relationships (`parent`, `num_children`, `first_child`, `next_sibling`).
    *   Links to detail levels (`num_details`, `details`).
    *   Defines electrical arc effects (`num_arcs`, `arc_pts`, `arc_type`).
    *   Stores rendering buffer information (`indexed_vertex_buffer`, `buffer`).
    *   Flags for collision behavior (`no_collisions`, `nocollide_this_only`, `collide_invisible`).
    *   Flags for rendering/behavior (`is_thruster`, `gun_rotation`, `force_turret_normal`).
*   **Subsystem Data Structure (`model_subsystem`):**
    *   Defines functional parts attached to submodels (`model.h`).
    *   Contains name, associated subobject name/number, type (`SUBSYSTEM_ENGINE`, `SUBSYSTEM_TURRET`, etc.).
    *   Stores position (`pnt`), radius, strength (`max_subsys_strength`).
    *   Defines turret properties (FOV, firing points, turn rate, sounds, associated gun subobject).
    *   Holds engine wash info (`engine_wash_pointer`).
    *   Manages rotation behavior (flags like `MSS_FLAG_ROTATES`, `MSS_FLAG_STEPPED_ROTATE`, `MSS_FLAG_TRIGGERED`).
    *   Stores AWACS properties (`awacs_intensity`, `awacs_radius`).
    *   Links to weapon banks (`primary_banks`, `secondary_banks`).
    *   Contains path information (`path_num`).
    *   Manages triggered animations (`n_triggers`, `queued_animation* triggers`).
*   **Model Loading & Management (`modelread.cpp`):**
    *   `model_load()`: Top-level function to load a model by filename. Checks for existing loaded models (unless `duplicate` flag is set). Manages a global array `Polygon_models`. Assigns a unique `id`. Handles reference counting (`used_this_mission`).
    *   `read_model_file()`: Parses the POF file chunk by chunk (`ID_OHDR`, `ID_SOBJ`, `ID_TXTR`, etc.). Reads header info, submodel data, textures, paths, docking points, weapon points, shield mesh, etc. Handles different POF versions.
    *   `model_unload()`: Frees model data, including submodels, paths, shield data, docking bays, thrusters, glow points, etc. Decrements reference count.
    *   `model_free_all()`: Unloads all models.
    *   `model_init()`: Initializes the model system.
    *   `model_page_in_start()` / `model_page_in_stop()`: Used to manage which models stay loaded between missions based on usage (`used_this_mission` flag).
    *   `model_load_texture()`: Loads textures based on filename conventions (`-glow`, `-shine`, `-normal`, `-height`, `-trans`, `-amb`). Stores texture IDs in `texture_map`.
    *   **POF Chunk IDs:** Defines IDs for different data sections within the POF file (e.g., `ID_OHDR`, `ID_SOBJ`, `ID_TXTR`, `ID_GPNT`, `ID_MPNT`, `ID_DOCK`, `ID_FUEL`, `ID_SHLD`, `ID_PATH`, `ID_EYE`, `ID_INSG`, `ID_GLOW`, `ID_SPCL`, `ID_TGUN`, `ID_TMIS`, `ID_SLDC`, `ID_ACEN`). (From `modelsinc.h`)
    *   **IBX/TSB Caching:** Optional system (`Cmdline_noibx`, `Cmdline_normal`) to read/write pre-processed index buffer (`.ibx`) and tangent space (`.tsb`) data for faster loading, based on POF checksums.
*   **Model Rendering (`modelinterp.cpp`):**
    *   `model_render()` / `submodel_render()`: Core rendering functions.
    *   Handles detail level selection based on distance/settings.
    *   Applies lighting (`model_light`, `light_apply_rgb`, `light_apply_specular`).
    *   Applies textures, including animated textures and glow maps.
    *   Supports various rendering flags (`MR_SHOW_OUTLINE`, `MR_NO_LIGHTING`, `MR_NO_TEXTURING`, `MR_ALL_XPARENT`, etc.).
    *   Renders thruster effects (`model_render_thrusters`, `glow_point_bank`).
    *   Renders insignias (`model_render_insignias`).
    *   Handles shield rendering (`MR_SHOW_SHIELDS`).
    *   Supports warping effects (`model_set_warp_globals`).
    *   Supports cloaking effects (`model_setup_cloak`, `model_finish_cloak`).
    *   Uses vertex buffers (`generate_vertex_buffers`, `model_render_buffers`). Vertex buffer generation happens during `read_model_file` if not disabled (`Cmdline_nohtl`).
*   **Submodel Animation & Rotation (`modelanim.cpp`, `modelread.cpp`):**
    *   Handles triggered rotations (`triggered_rotation`, `queued_animation`) (from `modelanim.cpp`).
    *   Supports different animation types (`TRIGGER_TYPE_INITIAL`, `TRIGGER_TYPE_DOCKING`, `TRIGGER_TYPE_PRIMARY_BANK`, etc.) (from `modelanim.cpp`).
    *   Manages animation queueing, timing, and sounds (from `modelanim.cpp`).
    *   `model_anim_start_type()`: Initiates animations (from `modelanim.cpp`).
    *   `model_anim_submodel_trigger_rotate()`: Processes rotation updates (from `modelanim.cpp`).
    *   `submodel_stepped_rotate()`: Implements stepped rotation logic based on properties parsed from `$stepped` tag (`$steps`, `$t_paused`, `$t_transit`, `$fraction_accel`) (from `modelread.cpp`).
    *   `submodel_rotate()`: Implements continuous rotation based on desired turn rate and acceleration (from `modelread.cpp`).
    *   `model_rotate_gun()`: Calculates desired turret angles based on target position (`dst`) and applies rotation limits/speed. Uses `vm_interp_angle` (from `modelread.cpp`).
    *   `model_make_turret_matrix()`: Calculates the base orientation matrix for a turret subsystem (from `modelread.cpp`).
    *   `model_do_dumb_rotation()`: Handles simple, continuous rotation based on `$dumb_rotate` property (from `modelread.cpp`).
*   **Collision Detection (`modelcollide.cpp`, `object.md`):**
    *   Uses model data (radius, bounding boxes, submodels) for collision checks (`model_collide`, `ship_ship_check_collision`, `asteroid_check_collision`, `debris_check_collision`, `ship_weapon_check_collision`).
    *   `mc_info` structure holds collision query parameters and results.
    *   Supports different check types (`MC_CHECK_MODEL`, `MC_CHECK_SHIELD`, `MC_CHECK_RAY`, `MC_CHECK_SPHERELINE`).
    *   Checks against bounding boxes (`mc_ray_boundingbox`) and polygon faces (`mc_check_face`, `mc_check_sphereline_face`).
    *   Handles shield collision checks (`mc_check_shield`, `mc_check_sldc`).
    *   Manages collision pairs (`obj_pair`, `obj_add_pair`, `obj_remove_pairs`, `obj_check_all_collisions`). (From `object.md`)
    *   Handles different collision types (Ship-Ship, Ship-Weapon, Debris-Ship, etc.) with specific logic. (From `object.md`)
    *   Calculates collision physics (impulse, damage) based on object properties (`calculate_ship_ship_collision_physics`). (From `object.md`)
    *   Supports collision groups (`reject_due_collision_groups`). (From `object.md`)
*   **Shield Management:** Tracks shield strength per quadrant (`shield_quadrant`), applies damage, checks shield status (`shield_get_strength`, `shield_apply_damage`, `ship_is_shield_up`). Shield geometry (`pm->shield.ntris`) is used in collision checks. (From `object.md` and `model.h`)
*   **Docking System:** Manages docking relationships between objects (`dock_instance`, `dock_dock_objects`, `dock_undock_objects`, `dock_move_docked_objects`). Includes logic for both active and "dead" (marked for deletion) objects. Relies on dock points (`dock_bay`) defined within the model data. (From `object.md` and `model.h`)
*   **Object Rendering:** Sorts objects based on distance for rendering (`objectsort.cpp`) and calls specific rendering functions based on object type (`obj_render`). (Rendering details are in the Graphics component analysis, but `model_render` is the core). (From `object.md`)
*   **Object Sounds:** Associates sounds with objects and specific locations/subsystems (`obj_snd`, `obj_snd_assign`, `obj_snd_do_frame`). (From `object.md`)
*   **Spatial Partitioning (`modeloctant.cpp`):** Divides model space into octants to optimize collision detection or rendering queries (`model_octant`, `model_which_octant`).
*   **Subsystem Property Parsing (`modelread.cpp`):**
    *   `set_subsystem_info()`: Parses properties from `$props` string associated with a submodel tagged as `$special=subsystem` or special names like `$enginelarge`.
    *   Extracts `$name`, `$fov`, `$crewspot`, `$rotate` (turn time), `$triggered`, `$stepped` (with `$steps`, `$t_paused`, `$t_transit`, `$fraction_accel`), `$pbank`.
    *   Determines `subsystemp->type` based on common names ("engine", "radar", "turret", etc.).
    *   `do_new_subsystem()`: Associates parsed properties with the correct `model_subsystem` entry based on name matching.
*   **Coordinate Transformations (`modelread.cpp`):**
    *   `model_find_world_point()`: Converts a point from submodel space to world space, accounting for parent transforms and rotations.
    *   `world_find_model_point()`: Converts a point from world space to submodel space.
    *   `model_find_obj_dir()`: Converts a direction vector from submodel space to world space.
    *   `model_rot_sub_into_obj()`: Transforms a point from submodel space into the parent object's space (before applying object orientation).
    *   `model_get_rotating_submodel_axis()`: Gets the rotation axis of a submodel in world space.
*   **Instance Management (`modelread.cpp`):**
    *   `model_clear_instance()`: Resets instance-specific data (submodel angles, blown-off status, texture animation state) for a model.
    *   `model_set_instance()`: Applies instance-specific data (angles, blown-off status from `submodel_instance_info`) to a model's submodels.
    *   `model_clear_instance_info()` / `model_set_instance_info()`: Manage the `submodel_instance_info` struct which likely holds per-object submodel state.
*   **Hierarchy & Structure (`modelread.cpp`):**
    *   `create_family_tree()`: Builds the parent/child/sibling relationships between submodels after loading.
    *   Identifies replacement submodels (`-destroyed` suffix, `my_replacement`, `i_replace`).
    *   Identifies live debris submodels (`debris-` prefix, `is_live_debris`).
    *   Links detail levels based on naming conventions (e.g., `submodel_a` vs `submodel_b`).
*   **Docking/Path Utilities (`modelread.cpp`):**
    *   `model_find_dock_index()` / `model_find_dock_name_index()`: Find dock bay index by type or name.
    *   `model_get_dock_name()` / `model_get_num_dock_points()` / `model_get_dock_index_type()`: Access dock point info.
    *   `model_set_subsys_path_nums()` / `model_set_bay_path_nums()`: Links paths defined in the model to subsystems and docking bays based on naming conventions (`$bayN`).
    *   `model_maybe_fixup_subsys_path()`: Adjusts path start points relative to subsystem origin.
*   **Bounding Box Calculation (`modelread.cpp`):**
    *   `model_calc_bound_box()`: Calculates the 8 corner points of a bounding box from min/max vectors.
    *   `maybe_swap_mins_maxs()`: Corrects inverted min/max values read from the file.
    *   `model_find_2d_bound_min()` / `submodel_find_2d_bound_min()`: Calculates the 2D screen bounding box of a model/submodel using its 3D bounding box corners.

**2. List Potential Godot Solutions:**

*   **Object Representation:**
    *   Implemented: Base `Node3D` for spatial properties.
    *   Implemented: `scripts/core_systems/base_object.gd` attached to root node holds common properties (type, signature, flags, parent references). Uses Godot physics layers/masks.
    *   Implemented: Derived classes `scripts/ship/ship_base.gd`, `scripts/object/weapon_base.gd`, `scripts/object/asteroid.gd`, `scripts/object/debris.gd` inherit from `BaseObject.gd`.
    *   Implemented: Godot's built-in object lifecycle (`instantiate()`, `queue_free()`).
    *   Implemented: `scripts/core_systems/object_manager.gd` (Autoload) manages object lookup by ID and signature (using meta), and uses Groups (`GROUP_SHIP`, etc.).
*   **Model Data Structure (`polymodel` equivalent):**
    *   Implemented: Godot scene structure (`.tscn`) used as primary container.
    *   Implemented: `MeshInstance3D` nodes for visuals.
    *   Implemented: Custom `Resource` (`.tres`) files used for static data (`scripts/resources/ship_weapon/ship_data.gd`, `scripts/resources/ship_weapon/weapon_data.gd`). `scripts/resources/object/model_metadata.gd` is planned for POF metadata.
    *   Implemented: `Marker3D` nodes used in scenes for weapon/dock/thruster points, referenced by scripts/resources.
    *   Implemented: Physics properties (mass, inertia) handled by `RigidBody3D` (`ShipBase`, `AsteroidObject`, `DebrisObject`).
    *   Implemented: Subsystem definitions stored within `ShipData.gd`.
*   **Submodel Data Structure (`bsp_info` equivalent):**
    *   Implemented: Submodels represented as child `Node3D` nodes within the main object scene.
    *   Implemented: `MeshInstance3D`, `CollisionShape3D` attached as needed.
    *   Implemented: `AnimationPlayer` node exists in `ShipBase` for handling rotations/movements.
    *   Implemented: State (`blown_off`, `is_damaged`) managed in attached scripts (`scripts/ship/subsystems/ship_subsystem.gd`).
    *   Implemented: Parent/child relationships handled by the scene tree.
    *   Planned: Electrical arc effects via custom shader or `GPUParticles3D`.
    *   Implemented: Collision flags set via physics layers/masks on `CollisionShape3D`.
*   **Subsystem Data Structure (`model_subsystem` equivalent):**
    *   Implemented: Subsystems defined within `ShipData.gd` resource (`scripts/resources/ship_weapon/subsystem_definition.gd`).
    *   Implemented: Subsystems linked to `Marker3D` nodes in the scene.
    *   Implemented: Subsystem logic implemented in `scripts/ship/subsystems/ship_subsystem.gd` and derived classes like `scripts/ship/subsystems/turret_subsystem.gd`.
    *   Implemented: Turret properties stored in resource, aiming logic in `TurretSubsystem.gd`. `AnimationPlayer` available for rotation.
    *   Planned: Engine wash via `GPUParticles3D` or custom shader.
    *   Planned: AWACS via `Area3D` and GDScript.
    *   Implemented: Triggered animations handled via `AnimationPlayer` controlled by GDScript (`ShipBase.play_submodel_animation`).
*   **Model Loading & Management:**
    *   Implemented: Godot handles scene/resource loading (`load()`, `preload()`).
    *   Implemented: Texture memory management handled by Godot.
*   **Model Rendering:**
    *   Implemented: Godot's rendering engine handles most aspects.
    *   Planned: LOD via `VisibleOnScreenNotifier3D` or distance checks.
    *   Implemented: Lighting via Godot's light nodes and `WorldEnvironment`.
    *   Implemented: Texturing via `StandardMaterial3D` / `ShaderMaterial`.
    *   Planned: Rendering Flags mapped to material properties, `WorldEnvironment`, or rendering layers.
    *   Planned: Thruster Effects via `GPUParticles3D` / shaders. Glow points via `PointLight3D` / `GPUParticles3D` / emissive materials.
    *   Planned: Insignias via `Decal` nodes or custom shaders.
    *   Implemented: Shield Rendering via dedicated `MeshInstance3D` with shield shader (controlled by `ShieldSystem.gd`).
    *   Planned: Warping/Cloaking via shaders. `ShipBase.gd` has cloak/warp state variables and function stubs.
*   **Submodel Animation:**
    *   Implemented: `AnimationPlayer` used for animations.
    *   Implemented: `ShipBase.play_submodel_animation` triggers animations from GDScript.
*   **Collision Detection:**
    *   Implemented: `RigidBody3D` (`ShipBase`, `AsteroidObject`, `DebrisObject`), `Area3D` (`WeaponBase`).
    *   Implemented: `CollisionShape3D` used with primitives or generated meshes.
    *   Implemented: Godot physics layers/masks used for collision groups.
    *   Implemented: Collision handling logic in `_on_body_entered` signal callbacks within object scripts (`ShipBase`, `AsteroidObject`, `DebrisObject`, `WeaponBase`).
    *   Implemented: Ray/Shape casts available via `PhysicsDirectSpaceState3D`.
*   **Shield Management:**
    *   Implemented: Shield quadrant strengths stored and managed in `scripts/ship/shield_system.gd`.
    *   Implemented: Shield visuals/collision handled by separate `MeshInstance3D` and `CollisionShape3D` (likely on shield layer).
*   **Docking System:**
    *   Implemented: `Marker3D` nodes used for dock points.
    *   Implemented: `scripts/core_systems/docking_manager.gd` (Autoload) manages docking relationships using dictionaries.
    *   Implemented: `DockingManager.move_docked_objects` handles transform updates. `BaseObject.gd` has `dock_list` placeholders.
*   **Object Sounds:**
    *   Implemented: `AudioStreamPlayer3D` nodes used.
    *   Implemented: Playback managed via GDScript (e.g., `BaseObject.gd` placeholders).
*   **Spatial Partitioning:** Handled by Godot's engine. Manual octants unnecessary.

**3. Outline Target Code Structure:**

*   `scenes/core/base_object.tscn`: (Optional) Base scene if common nodes are needed.
*   `scripts/core_systems/base_object.gd`: Base script class for all game objects.
*   `scripts/core_systems/object_manager.gd`: (Singleton/Autoload) Manages object lookup, potentially lists of active objects by type.
*   `scripts/physics_space/collision_handler.gd`: (Optional) Centralized collision logic or handled within object scripts via signals.
*   `scripts/ship_weapon_systems/ship_base.gd`: Inherits `BaseObject.gd`, handles ship-specific logic, references `ShipData.tres`, manages subsystems, shield, docking.
*   `scripts/ship_weapon_systems/weapon_base.gd`: Inherits `BaseObject.gd`, handles weapon logic, references `WeaponData.tres`.
*   `scripts/ship_weapon_systems/debris.gd`: Inherits `BaseObject.gd`.
*   `scripts/ship_weapon_systems/asteroid.gd`: Inherits `BaseObject.gd`.
*   `scripts/model_systems/model_data_loader.gd`: (Optional) Script to load/process custom model metadata if needed beyond standard resource loading.
*   `resources/model_metadata/`: `.tres` files containing extracted/converted model metadata (subsystem defs, dock points, thrusters, glow points, etc.).
*   `resources/ships/`: `.tres` files defining ship stats, linking to scenes and `ModelMetadata`.
*   `scenes/ships_weapons/`: Contains individual scenes for each ship/weapon type, including `MeshInstance3D`, `CollisionShape3D`, `AudioStreamPlayer3D`, `Marker3D` (dock/weapon/thruster points), `AnimationPlayer`, `GPUParticles3D`, etc., with appropriate scripts attached.
*   `shaders/`: Contains custom shaders for effects like shields, thrusters, warp, cloak.

**4. Identify Important Methods, Classes, and Data Structures:**

*   **C++:**
    *   `struct object`: Core data container. (Mapped to Godot Nodes + GDScript classes).
    *   `struct polymodel`: Central model data. (Mapped to Godot Scene + custom `Resource`).
    *   `struct bsp_info`: Submodel data. (Mapped to `Node3D` hierarchy within a scene + `AnimationPlayer`).
    *   `struct model_subsystem`: Functional component data. (Mapped to data within custom `Resource` + GDScript logic).
    *   `struct texture_info`, `struct texture_map`: Texture management. (Replaced by Godot `Material`, `Texture2D`, `AnimatedTexture`).
    *   `struct shield_info`, `struct shield_tri`: Shield mesh data. (Mapped to `Mesh` resource + `CollisionShape3D`).
    *   `struct dock_bay`, `struct w_bank`, `struct thruster_bank`, `struct glow_point_bank`: Point definitions. (Mapped to `Marker3D` nodes + data in `Resource`).
    *   `struct model_path`: AI/Scripting paths. (Mapped to `Path3D` nodes).
    *   `struct queued_animation`, `class triggered_rotation`: Submodel animation logic. (Mapped to `AnimationPlayer` + GDScript).
    *   `struct mc_info`: Collision query structure. (Replaced by Godot physics query parameters/results).
    *   `model_load()`: Model loading. (Replaced by `load()`).
    *   `model_render()` / `submodel_render()`: Rendering. (Replaced by Godot rendering engine).
    *   `model_collide()`: Collision checking. (Replaced by Godot physics engine queries/signals).
    *   `model_anim_start_type()` / `model_anim_submodel_trigger_rotate()`: Animation control. (Replaced by `AnimationPlayer.play()` and GDScript).
    *   `generate_vertex_buffers()`: Vertex buffer creation. (Handled by Godot importer/rendering engine).
    *   `obj_create()` / `obj_delete()`: Object lifecycle. (Mapped to `instantiate()` / `queue_free()`).
    *   `obj_move_all()`: Main update loop. (Mapped to `_process` / `_physics_process`).
    *   `physics_sim()`: Physics update. (Replaced by Godot physics engine).
    *   `shield_*()` functions: Shield logic. (Implemented in `ShipBase.gd`).
    *   `dock_*()` functions: Docking logic. (Implemented in GDScript, potentially using `Marker3D`).
    *   `model_unload()` / `model_free_all()`: Model memory management. (Replaced by Godot's reference counting / `queue_free()`).
    *   `read_model_file()`: Core POF parsing logic. (Replaced by Godot importer + custom resource loading).
    *   `model_load_texture()`: Texture loading based on naming conventions. (Replaced by Godot material system).
    *   `set_subsystem_info()` / `do_new_subsystem()`: Parsing subsystem properties from POF `$props`. (Logic moved to importer/resource loader).
    *   `create_family_tree()`: Building submodel hierarchy. (Handled by Godot scene tree structure).
    *   `model_calc_bound_box()` / `maybe_swap_mins_maxs()`: Bounding box calculations. (Handled by Godot `MeshInstance3D`/`GeometryInstance3D`).
    *   `model_find_world_point()` / `world_find_model_point()` / `model_find_obj_dir()` / `model_rot_sub_into_obj()`: Coordinate transformations between model/submodel/world space. (Replaced by Godot `Node3D` transform methods: `to_global`, `to_local`, `basis`, `global_transform`).
    *   `submodel_stepped_rotate()` / `submodel_rotate()` / `model_rotate_gun()` / `model_make_turret_matrix()` / `model_do_dumb_rotation()`: Submodel rotation logic. (Mapped to `AnimationPlayer` and GDScript).
    *   `model_clear_instance()` / `model_set_instance()` / `model_clear_instance_info()` / `model_set_instance_info()`: Managing per-object instance state for submodels. (Handled by GDScript attached to object instances).
    *   `model_find_dock_index()` / `model_find_dock_name_index()` / `model_get_dock_name()` / `model_get_num_dock_points()` / `model_get_dock_index_type()`: Docking point queries. (Handled by accessing data in custom `Resource`).
    *   `model_set_subsys_path_nums()` / `model_set_bay_path_nums()` / `model_maybe_fixup_subsys_path()`: Linking paths to subsystems/bays. (Handled during resource creation/loading).
    *   `model_get_radius()` / `model_get_core_radius()` / `submodel_get_radius()`: Accessing radius data. (Stored in custom `Resource`).
    *   `model_find_2d_bound_min()` / `submodel_find_2d_bound_min()`: Calculating 2D screen bounds. (Potentially `Camera3D.unproject_position` on 3D bounds or `Control.get_rect`).
    *   `POF Chunk IDs` (`ID_OHDR`, `ID_SOBJ`, etc.): Define structure of POF file. (Used by importer).
    *   `struct submodel_instance_info`: Holds per-instance state for a submodel (angles, turn rates, etc.). (Mapped to properties in GDScript instance).
*   **Godot:**
    *   `Node3D`: Base for all spatial objects.
    *   `MeshInstance3D`: Displays the 3D model.
    *   `CollisionShape3D`: Defines the physics collision boundary.
    *   `RigidBody3D`/`CharacterBody3D`/`Area3D`: Physics interaction nodes.
    *   `GDScript Classes` (`BaseObject.gd`, `ShipBase.gd`, etc.): Hold game logic and state.
    *   `Resource` (`.tres`): Store shared data (ship stats, weapon stats, model metadata).
    *   `Marker3D`: Represent points in space (docking, weapons, thrusters, subsystems).
    *   `AnimationPlayer`: Handle submodel rotations, glow effects, etc.
    *   `GPUParticles3D`: Thruster effects, explosions, sparks.
    *   `PointLight3D` / `SpotLight3D`: Glow points, potentially weapon flashes.
    *   `AudioStreamPlayer3D`: Play positional audio.
    *   `ShaderMaterial`: Custom visual effects (shields, warp, cloak, thrusters).
    *   `Decal`: Apply insignias or damage effects.
    *   `Path3D`: Define AI or docking paths.
    *   `PhysicsDirectSpaceState3D`: For direct ray/shape casts.
    *   `Signal`: Handle collision events, docking events, animation finished.
    *   `Group`: Organize objects for easy lookup.
    *   `Singleton/Autoload`: Global managers (`ObjectManager`, `SoundManager`, `DockingManager`).

**5. Identify Relations:**

*   **ObjectManager (`scripts/core_systems/object_manager.gd`)** (Autoload) registers (`register_object`) and unregisters (`unregister_object`) objects (like `ShipBase`, `WeaponBase`) when they enter/exit the tree. Tracks objects by ID and signature (meta). Provides lookup functions (`get_object_by_id`, `get_object_by_signature`) and group-based access (`get_all_ships`).
*   **Game Object Scenes** (`scenes/ships_weapons/*.tscn`) contain the `Node3D` hierarchy: `MeshInstance3D`, `CollisionShape3D`, `Marker3D`s (for hardpoints, dock points), `AnimationPlayer`, `GPUParticles3D`, `AudioStreamPlayer3D`, and component nodes (`WeaponSystem`, `ShieldSystem`, `DamageSystem`, `EngineSystem`, `EnergyTransferSystem`, `AIController`).
*   **BaseObject (`scripts/core_systems/base_object.gd`)** is attached to the root of object scenes. It registers/unregisters with `ObjectManager`, holds common flags, type, signature (meta), parent info, and collision layer/mask settings. Defines virtual methods like `apply_damage`, `get_team`, `is_destroyed`.
*   **ShipBase (`scripts/ship/ship_base.gd`)** inherits `BaseObject`. It holds references to component nodes (`WeaponSystem`, `ShieldSystem`, etc.), `ShipData` resource, manages hull strength, weapon energy, ETS indices, cloak/warp state, and destruction sequence. It receives damage via `take_damage` (delegating to `DamageSystem`) and handles collisions via `_on_body_entered`. It triggers animations via `play_submodel_animation`.
*   **WeaponBase (`scripts/object/weapon_base.gd`)** inherits `BaseObject`. It holds `WeaponData`, owner reference, lifetime, velocity. It handles collisions via `_on_body_entered` / `_on_area_entered` and applies damage to hit objects (`ShipBase.take_damage`, `AsteroidObject.hit`, `DebrisObject.hit`).
*   **AsteroidObject/DebrisObject (`scripts/object/asteroid.gd`, `scripts/object/debris.gd`)** inherit `BaseObject` (via `RigidBody3D`). They handle their own health (`hull_strength`), destruction, and collision responses via `hit()` and `_on_body_entered`.
*   **Physics Engine** uses `CollisionShape3D` attached to `RigidBody3D` (`ShipBase`, `AsteroidObject`, `DebrisObject`) or `Area3D` (`WeaponBase`) to detect collisions.
*   **Collision Handling Logic** is implemented within the `_on_body_entered` methods of the respective object scripts (`ShipBase`, `AsteroidObject`, `DebrisObject`, `WeaponBase`), reacting to physics signals.
*   **DamageSystem (`scripts/ship/damage_system.gd`)** (Node within `ShipBase`) receives damage via `apply_local_damage` or `apply_global_damage`. It interacts with `ShieldSystem` to check/apply shield absorption and distributes remaining damage to subsystems (`ShipSubsystem.take_damage`) and the ship's hull (`ShipBase.hull_strength`). Emits signals for hull/subsystem damage/destruction. Tracks damage sources.
*   **ShieldSystem (`scripts/ship/shield_system.gd`)** (Node within `ShipBase`) manages shield quadrant strengths (`shield_quadrants`), absorbs damage (`absorb_damage`), and handles recharge (`recharge` called by `EnergyTransferSystem`). Emits signals for shield hits/changes.
*   **EnergyTransferSystem (`scripts/ship/energy_transfer_system.gd`)** (Node within `ShipBase`) manages power distribution (`_manage_ets`) based on `ShipBase` recharge indices, calling `recharge` methods on `ShieldSystem` and `EngineSystem`, and updating `ShipBase.weapon_energy`.
*   **EngineSystem (`scripts/ship/engine_system.gd`)** (Node within `ShipBase`) manages afterburner state (`afterburner_on`, `afterburner_fuel`), fuel consumption, and recharge (`recharge` called by `EnergyTransferSystem`).
*   **WeaponSystem (`scripts/ship/weapon_system.gd`)** (Node within `ShipBase`) manages weapon banks, ammo (`primary_bank_ammo`, `secondary_bank_ammo`), energy (`ShipBase.weapon_energy`), cooldowns (`next_primary_fire_stamp`, etc.), linking (`primary_linked`), and firing logic (`fire_primary`, `fire_secondary`). It instantiates projectile scenes (`WeaponBase` derived) and calls their `setup` method. It interacts with `TurretSubsystem` via `turret_bank_map`.
*   **ShipSubsystem (`scripts/ship/subsystems/ship_subsystem.gd`)** (Node within `ShipBase`) holds runtime state for a subsystem (health, disruption timer), references its static definition (`SubsystemDefinition` within `ShipData`), and handles taking damage (`take_damage`).
*   **TurretSubsystem (`scripts/ship/subsystems/turret_subsystem.gd`)** inherits `ShipSubsystem`. It handles turret aiming (`aim_at_target`) and firing (`fire_turret`, interacting with `WeaponSystem`).
*   **DockingManager (`scripts/core_systems/docking_manager.gd`)** (Autoload) manages docking state (`live_docks`). `dock_objects`/`undock_objects` update the state. `move_docked_objects` (called by `ShipBase._physics_process`) updates transforms based on `Marker3D` positions (`_get_dock_point_transform`).
*   **Rendering System (Graphics)** uses `MeshInstance3D` and associated `Material`/`ShaderMaterial` resources. `WorldEnvironment` controls global effects.
*   **AnimationPlayer** (Node within `ShipBase`) manipulates `Node3D` transforms (for submodels), material properties, particle emission, and calls methods. Triggered by `ShipBase.play_submodel_animation`.

## IV. Godot Project Structure (Relevant Parts)

*   `resources/ships/`: `.tres` files defining ship stats (linking to scenes, `ModelMetadata`).
*   `resources/model_metadata/`: `.tres` files containing model-specific info (dock points, subsystems, thrusters, glow points, paths, etc.).
*   `scenes/ships_weapons/`: `.tscn` files for each ship/weapon, containing `MeshInstance3D`, `CollisionShape3D`, `Marker3D`s, `AnimationPlayer`, `GPUParticles3D`, `AudioStreamPlayer3D`, etc.
*   `scripts/core_systems/base_object.gd`: Base script.
*   `scripts/ship_weapon_systems/ship_base.gd`: Ship logic, shield, docking interaction, subsystem management.
*   `scripts/model_systems/`: Potentially scripts related to complex model interactions if needed.
*   `shaders/`: `.gdshader` files for custom visual effects.

## V. Conversion Strategy Notes

*   Prioritize converting the core `object` structure and lifecycle management into a `BaseObject.gd` script and potentially an `ObjectManager` singleton.
*   Define the structure for `ModelMetadata.tres` and `ShipData.tres` resources early.
*   Implement collision detection using Godot's physics nodes and layers/masks. Collision response logic (damage, effects) will be in GDScript.
*   Shield logic should be encapsulated within the `ShipBase.gd` script, potentially interacting with a dedicated shield node/shader.
*   Docking logic needs careful design: using `Marker3D`s for points and GDScript (possibly via a `DockingManager`) to manage state and transforms seems appropriate.
*   Subsystem animations (`modelanim.cpp`) should be mapped to `AnimationPlayer` tracks controlled by GDScript.
*   Thruster effects (`thruster_bank`, `glow_point_bank`) likely require `GPUParticles3D` and potentially custom shaders, controlled by `AnimationPlayer` or script based on ship state.
*   Object sounds should leverage `AudioStreamPlayer3D` attached appropriately.
*   The rendering sort (`objectsort.cpp`) is likely unnecessary. Focus on material properties (render priority, transparency flags) for sorting.
*   Vertex buffer generation (`generate_vertex_buffers`) is handled by Godot's import process and rendering backend.
*   Spatial partitioning (`modeloctant.cpp`) is handled internally by Godot.
