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
    *   **NavPoints:** Custom `Resource` (`NavPointData.tres`) storing name, target type (Ship/Waypoint path), target identifier (ship name/waypoint path), node index (for waypoints), flags. Manage a global array or dictionary of these resources.
    *   **Selection:** Global state variable (`current_nav_index`) managed by a Singleton or dedicated node. UI elements trigger selection functions.
    *   **Engagement Logic:** GDScript function (`can_autopilot()`) checking conditions (distance, nearby hostiles via Area3D or physics queries, player state).
    *   **AI Control:** Temporarily assign a specific AI state/controller script to the player ship node when autopilot is engaged. Use `NavigationAgent3D` for pathfinding towards the `NavPointData` target position.
    *   **Time Compression:** Use `Engine.time_scale`.
    *   **Cinematic Autopilot:** Use a separate `Camera3D` node, potentially animated with `AnimationPlayer` or controlled via script (`_physics_process` or `_process`) for smooth movement between calculated points. Use `CanvasLayer` for cutscene bars. Ship formation logic implemented in GDScript.
    *   **Warping:** Directly set the `global_transform.origin` of the player and relevant ships.
    *   **Messaging:** Use UI scenes (`Label`, potentially `AudioStreamPlayer`) managed by a global UI manager or the Autopilot controller. Load messages from a `ConfigFile` or custom resource equivalent to `autopilot.tbl`.
    *   **Linking:** Use `Area3D` around the player to detect ships needing linking or periodic distance checks. Update ship state flags/properties.
    *   **Configuration:** Load settings from a `ConfigFile` (`autopilot.cfg`).

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── resources/
    │   ├── autopilot/
    │   │   ├── autopilot_config.tres # Stores LinkDistance, messages, etc.
    │   │   └── nav_points/
    │   │       └── nav_point_data.gd # Script for NavPointData resource
    │   │       └── mission_x_nav_alpha.tres # Example NavPointData resource
    │   └── ...
    ├── scenes/
    │   ├── core/
    │   │   └── autopilot_manager.tscn # Node managing autopilot state
    │   └── ui/
    │       └── autopilot_message.tscn # Scene for displaying messages
    │       └── cutscene_bars.tscn     # Scene for cinematic bars
    │   └── gameplay/
    │       └── autopilot_camera.tscn # Dedicated camera for cinematics
    │   └── ...
    ├── scripts/
    │   ├── core_systems/
    │   │   └── autopilot_manager.gd # Manages state, engagement, disengagement, NavPoints
    │   ├── player/
    │   │   └── player_autopilot_controller.gd # AI controller used during autopilot
    │   ├── controls_camera/
    │   │   └── autopilot_camera_controller.gd # Logic for cinematic camera movement
    │   ├── resources/
    │   │   └── nav_point_data.gd # Defines the NavPointData resource
    │   └── ...
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   `struct NavPoint`: Core data structure for navigation targets. (Map to `NavPointData.tres`).
    *   `struct NavMessage`: Stores message text and sound file names. (Map to data within `autopilot_config.tres`).
    *   `StartAutopilot()`: Logic for initiating autopilot. (Map to `AutopilotManager.start_autopilot()`).
    *   `EndAutoPilot()`: Logic for terminating autopilot. (Map to `AutopilotManager.end_autopilot()`).
    *   `CanAutopilot()`: Checks conditions for engagement. (Map to `AutopilotManager.can_autopilot()`).
    *   `NavSystem_Do()`: Main update loop for autopilot logic (time compression, cinematic camera updates, distance checks, linking). (Integrate into `AutopilotManager._process` or `_physics_process`).
    *   `nav_warp()`: Ship repositioning logic. (Map to a helper function in `AutopilotManager`).
    *   `parse_autopilot_table()`: Loading configuration. (Replace with Godot `ConfigFile` or resource loading).
    *   `AddNav_Ship()`, `AddNav_Waypoint()`: Creating NavPoints (likely done via mission loading/parsing in Godot).
    *   `DistanceTo()`: Calculating distance to a nav point. (Use Godot's vector math: `player.global_position.distance_to(nav_point_position)`).
    *   Global variables: `AutoPilotEngaged`, `CurrentNav`, `Navs`, `LockAPConv`, `CinematicStarted`. (Manage state within `AutopilotManager`).

*   **Identify Relations:**
    *   Autopilot Manager interacts heavily with the Player Ship (reading state, setting AI controller, position).
    *   Interacts with the AI System (assigning goals).
    *   Interacts with the Camera System (controlling cinematic camera).
    *   Interacts with the Mission System (reading flags like `MISSION_FLAG_USE_AP_CINEMATICS`, potentially loading NavPoints).
    *   Interacts with the UI System (displaying messages, cutscene bars).
    *   Reads configuration data (equivalent of `autopilot.tbl`).
    *   Modifies `Engine.time_scale`.

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
    *   **Camera Class:** Use Godot's built-in `Camera3D` node. Store additional metadata (name, host/target references, custom logic flags) in an attached GDScript.
    *   **Camera ID:** Use Godot's node paths or instance IDs. For safety, could wrap node references in a custom class or check `is_instance_valid`.
    *   **Camera Management:** A Singleton (`CameraManager.gd`) or a dedicated node in the main scene can manage a dictionary or array of active `Camera3D` nodes/scripts. Provide functions like `create_camera`, `set_active_camera`, `get_camera_by_name`.
    *   **Smooth Transitions:** Use `Tween` node for interpolating position, rotation, and FOV (`camera.fov`). `AnimationPlayer` can also be used for more complex, pre-defined camera animations.
    *   **Targeting/Following:** Set `Camera3D.look_at(target_node.global_position)` in `_process` or `_physics_process`. For following, update the camera's `global_transform` relative to the host node's transform.
    *   **Custom Logic:** Implement custom behaviors directly in the camera's attached GDScript (`_process` or `_physics_process`).
    *   **Warp Camera:** Could be a specific `Camera3D` with a script implementing the physics-based movement described, likely using `_physics_process`.
    *   **Subtitles:** Create a UI scene (`SubtitleDisplay.tscn`) with `Label` and `TextureRect` nodes on a `CanvasLayer`. A manager script (`SubtitleManager.gd`, possibly autoloaded) queues subtitles (perhaps as custom `Resource` objects containing text, image path, timing) and controls their display, fading (using `Tween` on modulate alpha), and removal.
    *   **Zoom Control:** Modify the `Camera3D.fov` property, potentially using `Tween` for smooth changes.

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── resources/
    │   ├── subtitles/
    │   │   └── subtitle_data.gd # Script for SubtitleData resource
    │   │   └── mission_x_sub_1.tres # Example SubtitleData resource
    │   └── ...
    ├── scenes/
    │   ├── core/
    │   │   └── camera_manager.tscn # Node managing cameras
    │   │   └── subtitle_manager.tscn # Node managing subtitles
    │   └── ui/
    │   │   └── subtitle_display.tscn # Scene for rendering a single subtitle
    │   └── gameplay/
    │       └── warp_camera.tscn # Specific camera setup for warp
    │   └── ...
    ├── scripts/
    │   ├── core_systems/
    │   │   └── camera_manager.gd # Manages camera creation, switching, lookup
    │   │   └── subtitle_manager.gd # Manages subtitle queue and display
    │   ├── controls_camera/
    │   │   └── base_camera_controller.gd # Base script for Camera3D nodes
    │   │   └── cinematic_camera_controller.gd # Specific logic for cutscenes
    │   │   └── warp_camera_controller.gd # Logic for warp effect camera
    │   ├── resources/
    │   │   └── subtitle_data.gd # Defines the SubtitleData resource
    │   └── ui/
    │       └── subtitle_display.gd # Script for the subtitle UI scene
    │   └── ...
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   `class camera`: Represents a single camera view. (Map to `Camera3D` + `BaseCameraController.gd`).
    *   `class camid`: Safe handle for cameras. (Use Godot node references/paths + `is_instance_valid`).
    *   `class warp_camera`: Physics-based camera for warp effect. (Map to `WarpCameraController.gd` on a `Camera3D`).
    *   `class subtitle`: Data and logic for displaying subtitles. (Map to `SubtitleData.tres` resource + `SubtitleDisplay.tscn/gd` + `SubtitleManager.gd`).
    *   `avd_movement`: Class for smooth interpolation. (Replace with `Tween` or manual interpolation in `_process`).
    *   `cam_create()`: Creates a camera instance. (Map to `CameraManager.create_camera()`).
    *   `cam_set_camera()`: Sets the active camera, potentially hiding HUD. (Map to `CameraManager.set_active_camera()`, which sets `Camera3D.current = true` and signals HUD manager).
    *   `cam_reset_camera()`: Reverts to default view, restoring HUD. (Map to `CameraManager.reset_to_default_camera()`).
    *   `camera::set_position()`, `camera::set_rotation()`, `camera::set_zoom()`: Methods for controlling camera properties, often with timing. (Map to functions in `BaseCameraController.gd` using `Tween`).
    *   `camera::get_info()`: Retrieves the current calculated position and orientation. (Access `Camera3D.global_transform`).
    *   `subtitles_do_frame()`: Updates and draws subtitles. (Logic within `SubtitleManager.gd` and `SubtitleDisplay.gd`).

*   **Identify Relations:**
    *   Camera Manager interacts with Game Objects (for hosting/targeting).
    *   Interacts with the UI System (Subtitles, potentially hiding/showing HUD).
    *   Interacts with the Autopilot System (for cinematic camera control).
    *   Cameras are controlled by various systems (Player, Cutscenes, Autopilot).
    *   Subtitle system displays text/images provided by other systems (Mission events, AI chatter).

#### 3. Observer (`observer/observer.cpp`, `observer/observer.h`)

*   **Identify Key Features:**
    *   **Observer Object:** A distinct object type (`OBJ_OBSERVER`) used for viewpoints. Limited number (`MAX_OBSERVER_OBS`).
    *   **Creation/Deletion:** `observer_create()` creates an observer object with physics properties (max velocity, acceleration enabled). `observer_delete()` removes it.
    *   **Eye Position:** `observer_get_eye()` retrieves the position and orientation of the observer object.
    *   **Physics:** Observer objects have basic physics (`physics_info`), allowing them to move.

*   **List Potential Godot Solutions:**
    *   **Observer Node:** Represent observers as simple `Node3D` nodes. If a visual representation or camera view is needed, add a `Camera3D` as a child.
    *   **Management:** A manager script (perhaps `DebugManager.gd` or part of `CameraManager.gd`) could track these observer nodes if needed.
    *   **Physics:** If movement is required, add a `CharacterBody3D` or `RigidBody3D` component, or simply manage position via script.
    *   **Eye Position:** Access the `global_transform` of the observer `Node3D`.

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── scenes/
    │   └── utility/ # Or debug/
    │       └── observer_viewpoint.tscn # Node3D, potentially with Camera3D child
    ├── scripts/
    │   └── controls_camera/ # Or utility/debug
    │       └── observer_viewpoint.gd # Script attached to the scene if logic is needed
    │       └── observer_manager.gd # Optional: If central management is required
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   `struct observer`: Stores observer state (object index, target, flags). (Map to properties in `ObserverViewpoint.gd`).
    *   `observer_create()`: Creates the observer object. (Instantiate `observer_viewpoint.tscn`).
    *   `observer_delete()`: Deletes the observer. (Call `queue_free()` on the node).
    *   `observer_get_eye()`: Gets position/orientation. (Access `ObserverViewpointNode.global_transform`).

*   **Identify Relations:**
    *   Observer objects are part of the general Object management system in C++. In Godot, they would be nodes in the `SceneTree`.
    *   Their purpose seems internal, possibly for debug views or specific non-player camera perspectives. They don't seem directly tied to core gameplay loops like player control or autopilot in the provided code.

#### 4. General Input Handling (Inferred - Not in provided code)

*   **Identify Key Features:**
    *   Mapping physical inputs (keyboard keys, mouse axes/buttons, joystick axes/buttons) to game actions (pitch, roll, yaw, fire, target, etc.).
    *   Reading input states (pressed, released, axis value).
    *   Allowing user configuration/rebinding of controls.
    *   Handling different input device types.

*   **List Potential Godot Solutions:**
    *   **InputMap:** Define abstract actions (e.g., "pitch_up", "fire_primary", "target_next") in Godot's Project Settings -> Input Map. Assign default keyboard, mouse, and joystick inputs to these actions.
    *   **Input Handling:** In scripts (e.g., `PlayerShipController.gd`), use `Input.get_axis()`, `Input.get_vector()`, `Input.is_action_pressed()`, `Input.is_action_just_pressed()` in `_physics_process` or `_unhandled_input` to react to defined actions.
    *   **Configuration:** Create a UI scene allowing users to remap actions using `InputMap.action_erase_events()` and `InputMap.action_add_event()`. Save/load custom mappings using `InputMap.save_to_file()` / `InputMap.load_from_file()` or store in a `ConfigFile`.
    *   **Device Handling:** Godot handles multiple device types automatically through the `InputEvent` system and `InputMap`.

*   **Outline Target Code Structure:**
    ```
    wcsaga_godot/
    ├── scenes/
    │   └── ui/
    │       └── control_options_menu.tscn # UI for rebinding controls
    ├── scripts/
    │   ├── player/
    │   │   └── player_ship_controller.gd # Handles ship movement/actions based on Input
    │   ├── menu_ui/
    │   │   └── control_options_menu.gd # Logic for the rebinding UI
    │   └── globals/
    │       └── input_manager.gd # Optional: Central place for input constants or complex handling
    ```

*   **Identify Important Methods, Classes, and Data Structures:**
    *   C++ Input handling functions/classes (e.g., `read_keyboard`, `read_mouse`, `read_joystick`). (Replace with Godot `Input` singleton methods).
    *   Control configuration data structures/files. (Replace with `InputMap` and potentially `ConfigFile`).

*   **Identify Relations:**
    *   Input handling directly affects the Player Ship's movement and actions.
    *   Input events are processed by UI elements (for menu navigation, button clicks).
    *   The Control Configuration UI modifies the `InputMap`.
