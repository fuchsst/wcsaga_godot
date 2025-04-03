# Wing Commander Saga: Godot Conversion Analysis - 12. Controls & Camera

This document analyzes the C++ components related to player controls, input handling, camera management, autopilot, and observer viewpoints, following the structure outlined in `tasks/00_analysis_setup.md`.

## III. Codebase Analysis: Controls & Camera

This component group covers player input (keyboard, mouse, joystick), control configuration, camera logic (including cinematic cameras and subtitles), and the autopilot system.

### A. Key Component Mapping to Godot

| C++ Component Group    | Godot Equivalent Areas                                      | Conversion Approach                                                                                                | Relevant C++ Files (Examples)                     |
| :--------------------- | :---------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------- | :------------------------------------------------ |
| **Input Handling**     | `Input`, `InputMap`, `InputEvent`                           | Map C++ input actions to Godot's `InputMap`. Handle events in relevant scripts (Player Ship, UI).                  | `io/`, `controlconfig/` (Not provided, inferred) |
| **Control Config**   | `ConfigFile`, `InputMap`, Custom Resources, UI Scenes       | Store keybindings in `ConfigFile` or custom resources. Provide UI for rebinding using `InputMap` functions.        | `controlconfig/` (Not provided, inferred)        |
| **Camera Management**  | `Camera3D`, `Node3D`, GDScript, `AnimationPlayer`           | Use `Camera3D` nodes. Implement camera logic (following, cinematic transitions, targeting) in GDScript. Use `AnimationPlayer` for smooth transitions. | `camera/camera.cpp`, `camera/camera.h`            |
| **Autopilot System** | `NavigationAgent3D`, Custom Resources, State Machines, GDScript | Define NavPoints as resources. Use `NavigationAgent3D` for pathfinding. Manage state (engaged, cinematic) via script. Control player ship AI during autopilot. | `autopilot/autopilot.cpp`, `autopilot/autopilot.h` |
| **Subtitles**        | `CanvasLayer`, `Label`, `TextureRect`, `Timer`, GDScript    | Display subtitles using `Label` and optional `TextureRect` on a `CanvasLayer`. Manage timing and fading via script/`Timer`. | `camera/camera.cpp` (subtitle class)              |
| **Observer View**    | `Node3D`, `Camera3D` (potentially), GDScript                | Implement as a specific `Node3D` or `Camera3D` setup, likely for debug or specific views. Manage via script.        | `observer/observer.cpp`, `observer/observer.h`    |

### B. Detailed Code Analysis (Based on Provided Files)

#### 1. Autopilot (`autopilot/autopilot.cpp`, `autopilot/autopilot.h`)

*   **Identify Key Features:**
    *   **NavPoint System:** Defines navigation points (ships or waypoints) with properties (name, flags, target). Max `MAX_NAVPOINTS` (8). Flags include `NP_HIDDEN`, `NP_NOACCESS`, `NP_VISITED`.
    *   **NavPoint Selection:** Allows selecting the current `CurrentNav`. Can cycle through available nav points (`Sel_NextNav`).
    *   **Autopilot Engagement:** `StartAutopilot()` engages the system if conditions are met (`CanAutopilot`). Conditions check for selected nav, distance, nearby hostiles/hazards, gliding status.
    *   **AI Control:** Sets `Player_use_ai = 1` when engaged, assigning AI goals (`AI_GOAL_WAYPOINTS_ONCE` or `AI_GOAL_FLY_TO_SHIP`) to the player and potentially carried wingmen/ships (`SF2_NAVPOINT_CARRY`, `WF_NAV_CARRY`).
    *   **Time Compression:** Manages time compression (`set_time_compression`, `lock_time_compression`) during autopilot, potentially adjusting based on distance.
    *   **Cinematic Autopilot:** Optional mode (`MISSION_FLAG_USE_AP_CINEMATICS`) with custom camera positioning (`cameraPos`, `cameraTarget`), movement (`MoveCamera`, `camMovingTime`), and potentially different ship formations. Uses a dedicated camera (`nav_get_set_camera`). Shows cutscene bars (`UseCutsceneBars`).
    *   **Warping:** `nav_warp()` function repositions player and carried ships closer to the destination, used in cinematic mode or potentially at the end.
    *   **Autopilot Disengagement:** `EndAutoPilot()` reverts player control, resets time compression, clears AI goals, and potentially resets the camera. Can be triggered manually or automatically (`Autopilot_AutoDiable`).
    *   **Messaging:** Sends messages and audio cues (`send_autopilot_msgID`, `send_autopilot_msg`) for various events (e.g., engagement failure reasons, linking). Messages configured in `autopilot.tbl`.
    *   **Linking:** Ships marked `SF2_NAVPOINT_NEEDSLINK` can become `SF2_NAVPOINT_CARRY` when close enough to the player (`NavLinkDistance`).
    *   **Configuration:** Parses `autopilot.tbl` for settings like `NavLinkDistance`, messages, sounds, and flags (`UseCutsceneBars`, `No_Autopilot_Interrupt`).

*   **List Potential Godot Solutions:**
    *   **NavPoints:** Custom `Resource` defined by `scripts/resources/autopilot/nav_point_data.gd` (`NavPointData`), stored as `.tres` files (e.g., `resources/autopilot/nav_points/mission_x_nav_alpha.tres`). Managed by `AutopilotManager`.
    *   **Selection:** State variable `current_nav_index` and `nav_points` array within `AutopilotManager.gd` (Singleton). UI elements call `AutopilotManager.select_next_nav()`.
    *   **Engagement Logic:** Implemented in `AutopilotManager.can_autopilot()`, checking distance, gliding status (via `PlayerShip.physics_controller`), nearby hostiles/hazards (via `ObjectManager` queries).
    *   **AI Control:** `AutopilotManager` disables `PlayerShipController` and enables `PlayerAutopilotController.gd` (attached to player ship). `PlayerAutopilotController` uses `NavigationAgent3D` for pathfinding based on `NavPointData` target. `AutopilotManager` sets/clears AI goals via `AIGoalManager`.
    *   **Time Compression:** `AutopilotManager` calls `GameManager.set_time_compression()` and `GameManager.lock_time_compression()`. Ramping logic in `AutopilotManager._update_standard_autopilot()`.
    *   **Cinematic Autopilot:** `AutopilotManager` manages state (`is_cinematic_active`), controls a dedicated `Camera3D` via `AutopilotCameraController.gd`, calculates camera positions/targets (`_setup_cinematic_autopilot`), and signals `UIManager` to show/hide cutscene bars (using `AutopilotConfig.use_cutscene_bars`).
    *   **Warping:** Implemented in `AutopilotManager._warp_ships()`, directly manipulating `global_position` of player and carried ships (identified via `ObjectManager`). Calls `ObjectManager.retime_all_collisions()`.
    *   **Messaging:** `AutopilotManager` emits `autopilot_message` signal with text/sound path from `AutopilotConfig`. A `UIManager` (to be implemented) listens to this signal to display messages (e.g., using `scenes/ui/autopilot_message.tscn`).
    *   **Linking:** Periodic check (`_check_for_linking_ships`) in `AutopilotManager` uses `ObjectManager` to find nearby ships needing link, checks distance against `AutopilotConfig.link_distance`, updates ship flags (`SF2_NAVPOINT_NEEDSLINK`, `SF2_NAVPOINT_CARRY`), and sends link message.
    *   **Configuration:** Settings loaded into `AutopilotConfig` resource (`scripts/resources/autopilot/autopilot_config.gd`) from `resources/autopilot/autopilot_config.tres`. `AutopilotManager` uses this resource.

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── resources/
    │   ├── autopilot/
    │   │   ├── autopilot_config.tres # Stores LinkDistance, messages, etc. (Defined by autopilot_config.gd)
    │   │   └── nav_points/           # Folder for mission-specific NavPointData resources
    │   │       └── mission_x_nav_alpha.tres # Example NavPointData resource instance
    │   └── ...
    ├── scenes/
    │   ├── core/
    │   │   # AutopilotManager is an Autoload Singleton, no scene needed
    │   └── ui/
    │       └── autopilot_message.tscn # Scene for displaying messages (TODO)
    │       └── cutscene_bars.tscn     # Scene for cinematic bars (TODO)
    │   └── gameplay/ # Or utility/cameras
    │       └── autopilot_camera.tscn # Dedicated Camera3D node with AutopilotCameraController script (TODO)
    │   └── ...
    ├── scripts/
    │   ├── core_systems/
    │   │   └── autopilot_manager.gd # Autoload: Manages state, engagement, disengagement, NavPoints, cinematics, linking, time compression.
    │   │       # - func start_autopilot()
    │   │       # - func end_autopilot()
    │   │       # - func can_autopilot(send_msg: bool = false) -> bool
    │   │       # - func select_next_nav() -> bool
    │   │       # - func toggle_autopilot()
    │   │       # - func load_mission_nav_points(...)
    │   │       # - func _process(delta) # Handles checks, updates
    │   │       # - func _send_message(...)
    │   │       # - func _check_autopilot_conditions()
    │   │       # - func _update_standard_autopilot(delta)
    │   │       # - func _update_cinematic_autopilot(delta)
    │   │       # - func _setup_cinematic_autopilot()
    │   │       # - func _warp_ships(prewarp: bool = false)
    │   │       # - func _check_for_linking_ships()
    │   │       # - func _check_nearby_objects(...)
    │   │       # - func _set_autopilot_ai_goals(engage: bool)
    │   ├── player/
    │   │   └── player_autopilot_controller.gd # Attached to Player Ship: AI controller used during autopilot.
    │   │       # - func set_active(active: bool)
    │   │       # - func set_target_nav_point(nav_point: NavPointData)
    │   │       # - func set_speed_cap(cap: float)
    │   │       # - func _physics_process(delta) # Uses NavigationAgent3D
    │   ├── controls_camera/
    │   │   └── autopilot_camera_controller.gd # Attached to Autopilot Camera: Logic for cinematic camera movement.
    │   │       # - func set_instant_pose(pos: Vector3, look_at_target: Vector3)
    │   │       # - func move_to_pose(target_pos: Vector3, target_look_at: Vector3, duration: float)
    │   │       # - func look_at_target(target_pos: Vector3)
    │   ├── resources/
    │   │   └── autopilot/
    │   │       ├── autopilot_config.gd # Defines AutopilotConfig resource structure
    │   │       │   # - func get_message(msg_id: MessageID) -> String
    │   │       │   # - func get_sound(msg_id: MessageID) -> String
    │   │       └── nav_point_data.gd # Defines NavPointData resource structure
    │   │           # - func get_target_position() -> Vector3
    │   │           # - func can_select() -> bool
    │   │           # - func is_hidden() -> bool
    │   │           # - func is_no_access() -> bool
    │   │           # - func is_visited() -> bool
    │   │           # - func set_visited(visited: bool)
    │   └── ...
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   `struct NavPoint`: Core data structure for navigation targets. (Mapped to `NavPointData` resource defined by `scripts/resources/autopilot/nav_point_data.gd`).
    *   `struct NavMessage`: Stores message text and sound file names. (Mapped to exported vars within `AutopilotConfig` resource defined by `scripts/resources/autopilot/autopilot_config.gd`).
    *   `StartAutopilot()`: Logic for initiating autopilot. (Mapped to `AutopilotManager.start_autopilot()`).
    *   `EndAutoPilot()`: Logic for terminating autopilot. (Mapped to `AutopilotManager.end_autopilot()`).
    *   `CanAutopilot()`: Checks conditions for engagement. (Mapped to `AutopilotManager.can_autopilot()`).
    *   `NavSystem_Do()`: Main update loop for autopilot logic (time compression, cinematic camera updates, distance checks, linking). (Logic integrated into `AutopilotManager._process()`).
    *   `nav_warp()`: Ship repositioning logic. (Mapped to `AutopilotManager._warp_ships()`).
    *   `parse_autopilot_table()`: Loading configuration. (Replaced by loading `resources/autopilot/autopilot_config.tres` into `AutopilotManager.config`).
    *   `AddNav_Ship()`, `AddNav_Waypoint()`: Creating NavPoints. (Handled by mission loading process, which creates `NavPointData` resources and passes them to `AutopilotManager.load_mission_nav_points()`).
    *   `DistanceTo()`: Calculating distance to a nav point. (Uses Godot's vector math: `player_ship.global_position.distance_to(target_pos)` within `AutopilotManager`).
    *   Global variables: `AutoPilotEngaged`, `CurrentNav`, `Navs`, `LockAPConv`, `CinematicStarted`. (Mapped to state variables within `AutopilotManager`: `is_engaged`, `current_nav_index`, `nav_points`, `_lock_ap_conv_timer`, `is_cinematic_active`).

*   **Identify Relations:**
    *   `AutopilotManager` (Singleton) interacts with:
        *   `PlayerShip` (`ShipBase` node): Reads position, gliding status.
        *   `PlayerShipController` (Node script): Disables/enables via `set_active()`.
        *   `PlayerAutopilotController` (Node script): Enables/disables via `set_active()`, sets target nav point.
        *   `GameManager` (Autoload): Calls `lock_time_compression()`, `set_time_compression()`.
        *   `CameraManager` (Autoload): Calls `set_active_camera()`, `reset_to_default_camera()` for cinematics.
        *   `AutopilotCameraController` (Node script): Calls `set_instant_pose()`, `move_to_pose()`, `look_at_target()`.
        *   `UIManager` (Autoload/Node - TBD): Emits `autopilot_message` signal, calls hypothetical `show_cutscene_bars()`.
        *   `ObjectManager` (Autoload): Calls hypothetical `get_ships_in_radius()`, `get_objects_in_radius()`, `get_ships_with_flags()`, `retime_all_collisions()`. Reads ship flags/radius. Sets ship flags.
        *   `AIGoalManager` (Autoload): Calls hypothetical `add_goal()`, `remove_goal_by_flag()`.
        *   `MissionManager` (Autoload - TBD): Reads mission flags (e.g., `USE_AP_CINEMATICS`). Receives `NavPointData` array via `load_mission_nav_points()`.
        *   `AutopilotConfig` (Resource): Reads `link_distance`, `use_cutscene_bars`, messages, etc.
        *   `NavPointData` (Resource): Reads `target_type`, `target_identifier`, `waypoint_node_index`, flags. Calls `get_target_position()`.
        *   `Engine`: Modifies `time_scale`.
    *   `PlayerAutopilotController` interacts with:
        *   `ShipBase` (Parent Node): Reads `get_max_speed()`, `get_turn_rate()`. Accesses `physics_controller`.
        *   `NavigationAgent3D` (Sibling Node): Sets `target_position`, calls `is_navigation_finished()`, `get_next_path_position()`.
        *   `NavPointData` (Resource): Calls `get_target_position()`.
    *   `AutopilotCameraController` interacts with:
        *   `Camera3D` (Parent Node): Modifies `global_position`, `global_basis`, calls `look_at()`.

#### 2. Camera (`camera/camera.cpp`, `camera/camera.h`)

*   **Identify Key Features:**
    *   **Camera Class:** Manages individual camera instances (`camera`). Each has a name, signature (`sig`), position (`c_pos`), orientation (`c_ori`), zoom (`c_zoom`), flags (`flags`), host/target objects (`object_host`, `object_target`) with optional submodel focus.
    *   **Camera ID (`camid`):** Handle to safely reference camera instances using index (`idx`) and signature (`sig`).
    *   **Camera Management:** Global list (`Cameras`) stores camera instances. Functions to create (`cam_create`), delete (`cam_delete`), lookup (`cam_lookup`), set current (`cam_set_camera`), reset (`cam_reset_camera`), get info (`get_info`).
    *   **Smooth Transitions:** Uses `avd_movement` class (likely stands for Acceleration/Velocity/Deceleration) to smoothly interpolate zoom, position (x, y, z), and orientation matrix elements over time. Allows setting target values with timing/acceleration parameters.
    *   **Targeting:** Can automatically orient towards a target object (`object_target`) or follow a host object (`object_host`).
    *   **Custom Logic:** Supports custom functions (`func_custom_position`, `func_custom_orientation`) for complex camera behaviors.
    *   **Warp Camera (`warp_camera`):** Specialized camera for warp effect, simulating physics-based movement (`apply_physics`).
    *   **Subtitles (`subtitle`):** Class to manage displaying text and/or images on screen with timing (display time, fade time), positioning (absolute, centered), color, and optional background shading (`post_shaded`). Managed globally (`Subtitles`).
    *   **Zoom Control:** Manages camera Field of View (FOV) or zoom level. Can be set directly or interpolated. Influenced by `Sexp_zoom`.

*   **List Potential Godot Solutions:**
    *   **Camera Class:** Use Godot's built-in `Camera3D` node. Attach `BaseCameraController.gd` (or derived like `CinematicCameraController`, `WarpCameraController`) script to handle logic, host/target references, and transitions.
    *   **Camera ID:** Use Godot node references (`Camera3D`) managed by `CameraManager`. Check validity using `is_instance_valid()`.
    *   **Camera Management:** `CameraManager.gd` (Autoload Singleton) manages a dictionary (`cameras`) of registered `Camera3D` nodes. Provides `register_camera()`, `unregister_camera()`, `get_camera_by_name()`, `set_active_camera()`, `reset_to_default_camera()`.
    *   **Smooth Transitions:** `BaseCameraController.gd` uses `Tween` for interpolating `fov`, `global_position`, and rotation (via quaternion slerp in `_interpolate_rotation` callback). Accepts duration and potentially accel/decel parameters (TODO). `AnimationPlayer` can be used by `CinematicCameraController` for complex paths.
    *   **Targeting/Following:** Implemented in `BaseCameraController._physics_process()`. Updates `camera.global_transform` based on `host_object` transform + offset, or uses `Basis.looking_at()` towards `target_object` position (with prediction).
    *   **Custom Logic:** Implement custom behaviors by extending `BaseCameraController` or adding logic directly within derived controllers (e.g., `WarpCameraController`).
    *   **Warp Camera:** Implemented as a `Camera3D` node with `WarpCameraController.gd` attached, handling physics-based movement in `_physics_process()`. Activated via `start_warp_effect()`.
    *   **Subtitles:** `SubtitleManager.gd` (Autoload Singleton) manages a queue (`subtitle_queue`) of `SubtitleData` resources. It instances/controls `scenes/ui/subtitle_display.tscn` (a `CanvasLayer` with `Label`/`TextureRect`) via `scripts/ui/subtitle_display.gd` to handle rendering, positioning, and alpha fading in `_process()`.
    *   **Zoom Control:** `BaseCameraController.set_zoom()` modifies `Camera3D.fov`, using `Tween` for smooth transitions. SEXP influence would likely come via mission script calls to `CameraManager.set_camera_zoom()`.

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── resources/
    │   ├── subtitles/
    │   │   └── mission_x_sub_1.tres # Example SubtitleData resource instance
    │   └── ...
    ├── scenes/
    │   ├── core/
    │   │   # CameraManager and SubtitleManager are Autoloads, no scenes needed
    │   └── ui/
    │   │   └── subtitle_display.tscn # Scene (CanvasLayer > MarginContainer > VBox > TextureRect + Label) for rendering a single subtitle.
    │   └── gameplay/ # Or utility/cameras
    │       └── warp_camera.tscn # Specific Camera3D node with WarpCameraController script (TODO)
    │       └── cinematic_camera_template.tscn # Template Camera3D with CinematicCameraController (TODO)
    │   └── ...
    ├── scripts/
    │   ├── core_systems/
    │   │   └── camera_manager.gd # Autoload: Manages camera registration, switching, lookup.
    │   │       # - func register_camera(...)
    │   │       # - func set_active_camera(...)
    │   │       # - func reset_to_default_camera()
    │   │       # - func get_camera_by_name(...)
    │   │       # - func set_camera_zoom(...) # Helper calling BaseCameraController
    │   │       # - func set_camera_position(...) # Helper
    │   │       # - func set_camera_rotation(...) # Helper
    │   │       # - func set_camera_look_at(...) # Helper
    │   │       # - func set_camera_host(...) # Helper
    │   │       # - func set_camera_target(...) # Helper
    │   │   └── subtitle_manager.gd # Autoload: Manages subtitle queue and display.
    │   │       # - func queue_subtitle(subtitle_res: SubtitleData)
    │   │       # - func queue_subtitle_params(...)
    │   │       # - func clear_all()
    │   │       # - func _process(delta) # Updates current subtitle display/timing
    │   │       # - func _show_next_subtitle()
    │   │       # - func _clear_current_subtitle()
    │   ├── controls_camera/
    │   │   └── base_camera_controller.gd # Attached to Camera3D: Base script for following, targeting, transitions.
    │   │       # - func set_active(active: bool)
    │   │       # - func set_object_host(...)
    │   │       # - func set_object_target(...)
    │   │       # - func set_zoom(...)
    │   │       # - func set_position(...)
    │   │       # - func set_rotation(...)
    │   │       # - func set_rotation_facing(...)
    │   │       # - func _physics_process(delta) # Handles following/targeting
    │   │       # - func _interpolate_rotation(quat: Quaternion) # Tween callback
    │   │   └── cinematic_camera_controller.gd # Attached to Camera3D: Specific logic for cutscenes, AnimationPlayer interaction.
    │   │       # - func play_animation(animation_name: String)
    │   │       # - func stop_animation()
    │   │   └── warp_camera_controller.gd # Attached to Camera3D: Logic for warp effect camera.
    │   │       # - func start_warp_effect(player_obj: Node3D)
    │   │       # - func stop_warp_effect()
    │   │       # - func _physics_process(delta) # Custom physics movement
    │   ├── resources/
    │   │   └── subtitles/
    │   │       └── subtitle_data.gd # Defines the SubtitleData resource structure.
    │   │           # - func calculate_duration() -> float
    │   └── ui/
    │       └── subtitle_display.gd # Attached to subtitle_display.tscn: Script for the subtitle UI scene.
    │           # - func set_subtitle_data(subtitle: SubtitleData)
    │           # - func update_display(subtitle: SubtitleData, alpha: float)
    │           # - func clear_display()
    │           # - func _apply_positioning()
    │   └── ...
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   `class camera`: Represents a single camera view. (Mapped to `Camera3D` node with attached `BaseCameraController.gd` or derived script).
    *   `class camid`: Safe handle for cameras. (Replaced by direct `Camera3D` node references managed by `CameraManager`, using `is_instance_valid()` for safety checks).
    *   `class warp_camera`: Physics-based camera for warp effect. (Mapped to `WarpCameraController.gd` script attached to a dedicated `Camera3D`).
    *   `class subtitle`: Data and logic for displaying subtitles. (Mapped to `SubtitleData` resource defined by `scripts/resources/subtitles/subtitle_data.gd`. Display logic handled by `SubtitleManager.gd` and `scripts/ui/subtitle_display.gd`).
    *   `avd_movement`: Class for smooth interpolation. (Replaced by Godot's `Tween` node, managed within `BaseCameraController.gd`).
    *   `cam_create()`: Creates a camera instance. (Replaced by instancing camera scenes and registering them with `CameraManager.register_camera()`).
    *   `cam_set_camera()`: Sets the active camera, potentially hiding HUD. (Mapped to `CameraManager.set_active_camera()`, which sets `Camera3D.current = true` and emits `hud_visibility_changed` signal).
    *   `cam_reset_camera()`: Reverts to default view, restoring HUD. (Mapped to `CameraManager.reset_to_default_camera()`).
    *   `camera::set_position()`, `camera::set_rotation()`, `camera::set_zoom()`: Methods for controlling camera properties, often with timing. (Mapped to `set_position()`, `set_rotation()`, `set_zoom()` methods in `BaseCameraController.gd`, which use `Tween` for timed transitions).
    *   `camera::get_info()`: Retrieves the current calculated position and orientation. (Directly access `Camera3D.global_transform`).
    *   `subtitles_do_frame()`: Updates and draws subtitles. (Logic distributed between `SubtitleManager._process()` for timing/alpha and `SubtitleDisplay.update_display()` for rendering).

*   **Identify Relations:**
    *   `CameraManager` (Autoload) interacts with:
        *   `Camera3D` nodes and their attached controllers (`BaseCameraController`, etc.): Calls methods like `set_active()`.
        *   `UIManager` (Autoload/Node - TBD): Emits `hud_visibility_changed` signal.
        *   Other systems (e.g., `AutopilotManager`, Mission Scripts): Call `set_active_camera()`, `reset_to_default_camera()`, and helper methods (`set_camera_zoom`, etc.).
    *   `BaseCameraController` (and derived) interacts with:
        *   `Camera3D` (Parent Node): Reads/writes `global_transform`, `fov`.
        *   `Tween` (Created dynamically): Used for smooth transitions.
        *   Host/Target `Node3D`s: Reads `global_transform`, potentially `get_velocity()`.
    *   `SubtitleManager` (Autoload) interacts with:
        *   `SubtitleDisplay` (Instanced Scene/Node): Calls `set_subtitle_data()`, `update_display()`, `clear_display()`. Manages its visibility.
        *   `SubtitleData` (Resource): Reads properties like `text`, `display_time`, `fade_time`.
        *   Other systems (e.g., `MessageManager`, Mission Scripts): Call `queue_subtitle()`.
        *   `Time` singleton: Reads `get_ticks_msec()`.
    *   `SubtitleDisplay` interacts with:
        *   Internal `Label`, `TextureRect`, `MarginContainer`, `VBoxContainer` nodes.
        *   `ResourceLoader`: Loads images specified in `SubtitleData`.

#### 3. Observer (`observer/observer.cpp`, `observer/observer.h`)

*   **Identify Key Features:**
    *   **Observer Object:** A distinct object type (`OBJ_OBSERVER`) used for viewpoints. Limited number (`MAX_OBSERVER_OBS`).
    *   **Creation/Deletion:** `observer_create()` creates an observer object with physics properties (max velocity, acceleration enabled). `observer_delete()` removes it.
    *   **Eye Position:** `observer_get_eye()` retrieves the position and orientation of the observer object.
    *   **Physics:** Observer objects have basic physics (`physics_info`), allowing them to move.

*   **List Potential Godot Solutions:**
    *   **Observer Node:** Implemented as `scenes/utility/observer_viewpoint.tscn` (a `Node3D` scene) with `scripts/controls_camera/observer_viewpoint.gd` attached. A `Camera3D` can be added as a child if needed for viewing.
    *   **Management:** No dedicated manager created yet. Observers can be instanced directly or managed by systems that use them (e.g., Debug tools, potentially `CameraManager` if needed).
    *   **Physics:** The C++ version had basic physics. If movement is needed in Godot, a `CharacterBody3D` could be added to the scene, or its position managed directly via script by the controlling system. The current script is minimal.
    *   **Eye Position:** Access `ObserverViewpoint.global_transform` or use `ObserverViewpoint.get_eye_transform()`.

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── scenes/
    │   └── utility/
    │       └── observer_viewpoint.tscn # Node3D scene, potentially with Camera3D child.
    ├── scripts/
    │   └── controls_camera/
    │       └── observer_viewpoint.gd # Attached to observer_viewpoint.tscn. Minimal logic currently.
    │           # - func get_eye_transform() -> Transform3D
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   `struct observer`: Stores observer state (object index, target, flags). (Mapped to optional properties `target_obj_id`, `observer_flags` in `ObserverViewpoint.gd`).
    *   `observer_create()`: Creates the observer object. (Mapped to instancing `scenes/utility/observer_viewpoint.tscn`).
    *   `observer_delete()`: Deletes the observer. (Mapped to calling `queue_free()` on the `ObserverViewpoint` node).
    *   `observer_get_eye()`: Gets position/orientation. (Mapped to `ObserverViewpoint.get_eye_transform()` which returns `global_transform`).

*   **Identify Relations:**
    *   `ObserverViewpoint` nodes exist within the `SceneTree`.
    *   They are likely instanced and managed by debug systems or potentially `CameraManager` if used for specific non-player views.
    *   They provide transform data (`get_eye_transform()`) to whatever system uses them.

#### 4. General Input Handling (Inferred - Not in provided code)

*   **Identify Key Features:**
    *   Mapping physical inputs (keyboard keys, mouse axes/buttons, joystick axes/buttons) to game actions (pitch, roll, yaw, fire, target, etc.).
    *   Reading input states (pressed, released, axis value).
    *   Allowing user configuration/rebinding of controls.
    *   Handling different input device types.

*   **List Potential Godot Solutions:**
    *   **InputMap:** Actions (e.g., "pitch_up", "fire_primary", "target_next", "autopilot_toggle", "nav_cycle") defined in `project.godot` under `[input]`. Default keys/buttons assigned there.
    *   **Input Handling:** `scripts/player/player_ship_controller.gd` uses `Input.get_axis()` in `_physics_process()` for movement axes and `Input.is_action_pressed()` within `_unhandled_input()` for button/key actions.
    *   **Configuration:** A UI scene (`scenes/ui/control_options_menu.tscn` - TBD) with associated script (`scripts/menu_ui/control_options_menu.gd` - TBD) will allow users to remap actions using `InputMap` functions. Mappings can be saved/loaded using `InputMap.save_to_file()` / `InputMap.load_from_file()`.
    *   **Device Handling:** Godot's `Input` singleton and `InputMap` handle device abstraction.

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── project.godot # Contains [input] definitions
    ├── scenes/
    │   └── ui/
    │       └── control_options_menu.tscn # UI for rebinding controls (TODO)
    ├── scripts/
    │   ├── player/
    │   │   └── player_ship_controller.gd # Handles ship movement/actions based on Input.
    │   │       # - func _physics_process(delta) # Reads axes
    │   │       # - func _unhandled_input(event) # Reads actions
    │   │       # - func set_active(active: bool)
    │   ├── menu_ui/
    │   │   └── control_options_menu.gd # Logic for the rebinding UI (TODO)
    │   └── globals/
    │       # No specific input_manager.gd created yet, using Input singleton directly.
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   C++ Input handling functions/classes (e.g., `read_keyboard`, `read_mouse`, `read_joystick`, `joy_get_pos`, `key_down_count`). (Replaced by Godot `Input` singleton methods like `get_axis`, `is_action_pressed`, etc., used within `PlayerShipController.gd`).
    *   Control configuration data structures/files. (Replaced by Godot's `InputMap` system, managed via Project Settings and the planned `control_options_menu` UI).

*   **Identify Relations:**
    *   `PlayerShipController` reads from `Input` singleton.
    *   `PlayerShipController` calls methods on `ShipBase` (parent node) and its components (e.g., `physics_controller`, `weapon_system`).
    *   `PlayerShipController` interacts with `AutopilotManager` (Autoload) to toggle autopilot.
    *   UI scenes (like `control_options_menu` - TBD) interact with the `InputMap` singleton.
    *   General UI elements process input via their own `_input` or `_gui_input` methods.
