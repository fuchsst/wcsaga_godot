# Wing Commander Saga: Godot Conversion Analysis

This document outlines the approach and guidelines for analyzing the original Wing Commander Saga C++ codebase to facilitate its conversion to the Godot Engine (v4.x). The primary goal is to reuse existing assets while reimplementing game logic in GDScript, leveraging Godot's native features effectively.

## I. Project Overview

The project aims to migrate Wing Commander Saga from its C++ origins to Godot. This involves:

*   **Asset Extraction and Conversion:** Processing original models, textures, sounds, music, videos, and data tables into Godot-compatible formats. (See `03_asset_conversion_pipeline.md`)
*   **Code Analysis and Translation:** Deeply understanding the C++ codebase for each game system and translating its core logic and functionality into GDScript.
*   **Engine Utilization:** Maximizing the use of Godot's built-in nodes, resources, and systems (Physics, Rendering, UI, Audio, Navigation, etc.) while maintaining the original game's feel and mechanics.

## II. Conversion Workflow

```mermaid
graph TD
    A[Wing Commander Saga C++] --> B[Asset Extraction];
    A --> C[Code Analysis (Per Component)];
    B --> D[Asset Conversion Pipeline];
    C --> E[Architecture Design (Godot)];
    D --> F[Godot Project Implementation];
    E --> F;
    F --> G[Testing & Optimization];
```

## III. Codebase Analysis

The original codebase is broken down into the following core components for analysis. Each component will have a dedicated analysis document (`tasks/XX_component_name.md`).

1.  **AI:** Ship AI (fighters, capital ships, turrets), wingman logic, targeting (IFF, priorities), pathfinding, goals, profiles, countermeasures, stealth, docking/bay ops, guard behavior, repair/rearm logic. (Dirs: `ai`, `autopilot`, `iff_defs`, `cmeasure`)
2.  **Mission Editor (FRED):** Analysis of the original editor's features, data structures, and workflow to inform the development of a compatible Godot editor plugin (GFRED). (Dirs: `fred2`, `wxfred2`)
3.  **Asset Conversion Pipeline:** Strategy and tooling for converting models (POF), textures (DDS, PCX, etc.), animations (ANI, EFF), sounds (WAV), music, videos (MVE), mission files (FS2), and tables (TBL) to Godot formats (glTF, PNG/WebP, SpriteFrames, OGG/WAV, WebM/OGV, JSON/Resource). (Tooling effort, analyzes formats)
4.  **Core Systems:** Game loop, time management, object management (creation, deletion, tracking, signatures), core data structures, game sequence/state management, player profiles, statistics, rank/medals, global variables/constants, error handling. (Dirs: `freespace2`, `object`, `gamesequence`, `globalincs`, `playerman`, `scoring`, `stats`, `medals`, `rank`)
5.  **Ship & Weapon Systems:** Player/AI ship logic (physics integration, shields, subsystems, damage model, afterburners), weapon types (lasers, missiles, beams, flak, EMP, swarm), weapon firing logic, ammo/energy management, weapon effects (muzzle flash, trails, impacts). (Dirs: `ship`, `weapon`, `beam`, `corkscrew`, `emp`, `flak`, `muzzleflash`, `shockwave`, `swarm`, `trails`, `afterburner`, `awacs`, `shield`)
6.  **HUD System:** Heads-Up Display rendering, gauge management (shields, weapons, throttle, energy, target info, wingman status, messages, objectives, etc.), radar (standard/orb), reticle, threat warnings, offscreen indicators, target brackets, HUD configuration (`hud_gauges.tbl`). (Dirs: `hud`, `radar`)
7.  **Mission System:** Mission loading/parsing (`.fs2` format), objective tracking, event triggering (SEXP evaluation), dynamic spawning (waves, reinforcements), mission flow control, briefing/debriefing logic, campaign progression. (Dirs: `mission`, `missionui` parts like `missionbrief`, `missiondebrief`)
8.  **Scripting:** Table parsing (`.tbl`), S-Expression (SEXP) parsing and evaluation, variable handling (mission, campaign, player persistent), Lua integration (hooks, conditions), localization (`tstrings.tbl`, XSTR). (Dirs: `parse`, `variables`, `localization`)
9.  **Menu & UI:** Main menus, options screens, pilot management, tech room, ready room, popups, context help, low-level UI widgets (buttons, lists, sliders, etc.), "snazzy" UI system. (Dirs: `menuui`, `missionui`, `ui`, `popup`, `gamehelp`)
10. **Physics & Space:** Flight model implementation (Newtonian adjustments, damping), collision detection/response (ship-ship, ship-weapon, ship-asteroid, ship-debris), space environment elements (asteroids, debris, jump nodes), background rendering (starfield, nebula, suns, skyboxes), lighting. (Dirs: `physics`, `asteroid`, `debris`, `jumpnode`, `lighting`, `nebula`, `starfield`, `supernova`)
11. **Model System:** 3D model format (POF) parsing, data structures (`polymodel`, `bsp_info`, `model_subsystem`), submodel hierarchy/animation, docking points, weapon points, thruster points, shield mesh, AI paths, texture/material handling. (Dirs: `model`)
12. **Controls & Camera:** Input handling (keyboard, mouse, joystick), control configuration/rebinding, camera management (views, transitions, cinematic autopilot camera, observer views), subtitle system. (Dirs: `io`, `controlconfig`, `camera`, `observer`, `autopilot` camera parts)
13. **Sound & Animation:** Sound effect playback (2D/3D), event-driven music system, voice playback, cutscene playback (MVE/OGG), sprite animation playback (ANI/EFF), audio management (loading, channels, volume, 3D positioning). (Dirs: `sound`, `gamesnd`, `eventmusic`, `cutscene`, `anim`)
14. **Graphics:** Core 3D rendering pipeline (OpenGL abstraction), 2D drawing primitives, texture management (caching, formats, filtering), lighting application, shader system (custom GLSL), post-processing effects (bloom), vertex buffer management (VBOs). (Dirs: `graphics`, `render`)

*(Note: Low-level file I/O (`cfile`), OS specifics (`osapi`), networking (`network`), and specific image format utilities (`bmpman`, `ddsutils`, etc.) are generally replaced by Godot's built-in functionalities or asset pipeline.)*

### A. Key Component Mapping to Godot

| C++ Component Group      | Godot Equivalent Areas                                                                                                | Conversion Approach                                                                                                                               | Relevant C++ Dirs (Examples)        |
| :----------------------- | :-------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------------- |
| **AI**                   | GDScript, State Machines, Behavior Trees (e.g., LimboAI addon), `NavigationAgent3D`, Custom Resources (`AIProfile`)     | Implement AI logic using scripts attached to ship nodes. Use Resources for profiles. Leverage BT/State Machine patterns.                            | `ai`, `autopilot`, `iff_defs`       |
| **Mission Editor**       | `EditorPlugin`, `Control` nodes, `SubViewport`, `UndoRedo`, Custom Resources, GDScript                                  | Develop a Godot editor plugin (GFRED) mirroring FRED2 functionality for mission creation/editing.                                                 | `fred2`, `wxfred2`                  |
| **Asset Pipeline**       | Python Scripts, Godot Importers, `Texture2D`, `AudioStream`, `VideoStream`, `SpriteFrames`, `Mesh`, `glTF`, JSON/Resource | Develop/use tools to convert assets. Define import settings in Godot.                                                                             | `bmpman`, `ddsutils`, `model`       |
| **Core Systems**         | SceneTree, Nodes, Custom Resources (`PlayerData`, `RankInfo`, `MedalInfo`), Singletons/Autoloads, `ConfigFile`          | Reimplement core object/state management, game loop, stats/rank/medals using Godot's scene structure and custom resources/singletons.             | `object`, `freespace2`, `gamesequence`, `playerman`, `scoring`, `stats`, `medals`, `rank` |
| **Ship & Weapon Systems**| `Node3D` hierarchy (`RigidBody3D`/`CharacterBody3D`), GDScript Components, Resources (`ShipData`, `WeaponData`), `GPUParticles3D` | Represent ships/weapons as scenes with scripts for logic, physics integration, and effects. Use Resources for stats.                            | `ship`, `weapon`, `fireball`, `beam`, `shield`, `afterburner` |
| **HUD System**           | `CanvasLayer`, `Control` Nodes, `Theme`, `SubViewport`, GDScript, Custom Resources (`HUDConfig`)                        | Create HUD as a distinct scene using UI nodes, manage via script. Use `SubViewport` for target model display. Use Resources for configuration. | `hud`, `radar`                      |
| **Mission System**       | Custom Resources (`MissionData`, `MissionObjective`, `WaveData`), GDScript, `ConfigFile`/JSON, Singletons (`MissionManager`) | Define mission data in resources (converted from `.fs2`). Parse/execute mission logic via scripts and the SEXP system.                           | `mission`, `missionparse`           |
| **Scripting**            | `ConfigFile`, JSON, `FileAccess`, GDScript, `Expression`, Custom SEXP Parser/Evaluator, Godot Localization System       | Parse table files (`.tbl` -> JSON/Resource). Reimplement SEXP evaluation. Use Godot's localization (`.po`). Replace Lua with GDScript hooks. | `parse`, `variables`, `localization`|
| **Menu & UI**            | `Control` Nodes, `Theme`, Scene Management, GDScript, Custom UI Scenes                                                | Build menu scenes and other UI elements using Godot's UI system, potentially custom controls for specific widgets.                              | `menuui`, `missionui`, `ui`, `popup`, `gamehelp` |
| **Physics & Space**      | `RigidBody3D`, `CollisionShape3D`, Custom Integrator (`_integrate_forces`), `WorldEnvironment`, `GPUParticles3D`         | Utilize Godot's physics engine, with custom integration for flight model. Use `WorldEnvironment` for space effects.                           | `physics`, `asteroid`, `debris`, `jumpnode` |
| **Model System**         | `MeshInstance3D`, Godot Importers (glTF), `Node3D` hierarchy, `Marker3D`, `AnimationPlayer`, Custom Resources (`ModelMetadata`) | Convert models (POF->glTF), load via Godot's import system. Store metadata (points, subsystems) in Resources. Use scene hierarchy for submodels. | `model`                             |
| **Controls & Camera**    | `Input`, `InputMap`, `Camera3D`, GDScript, `Tween`, `AnimationPlayer`, Custom Resources (`NavPointData`)                 | Map C++ controls to Godot's Input system. Manage cameras via script, using `Tween`/`AnimationPlayer` for transitions. Use Resources for NavPoints. | `io`, `controlconfig`, `camera`, `autopilot`, `observer` |
| **Sound & Animation**    | `AudioStreamPlayer`/`3D`, `AudioServer`, `VideoStreamPlayer`, `AnimatedSprite2D`, `SpriteFrames`, `AnimationPlayer`       | Use Godot's nodes for audio/video playback. Convert ANI to `SpriteFrames`. Use `AnimationPlayer` for model animations.                      | `sound`, `gamesnd`, `eventmusic`, `cutscene`, `anim` |
| **Graphics**             | `WorldEnvironment`, `ShaderMaterial` (`.gdshader`), `BaseMaterial3D`, `GPUParticles3D`, `RenderingServer`, `Viewport`     | Leverage Godot's rendering features. Reimplement custom C++ shaders in Godot Shading Language. Use `WorldEnvironment` for PPFX.                | `graphics`, `render`, `starfield`, `nebula`, `particle`, `decal`, `lighting` |

### B. Detailed Code Analysis Guidelines

For each component analysis document (`tasks/XX_component_name.md`):

1.  **Identify Key Features:**
    *   List primary functions and capabilities.
    *   Describe core algorithms and data flows.
    *   Mention specific gameplay mechanics handled by this component.
    *   *Guideline:* Be specific. Instead of "Handles AI", list "Fighter Attack Patterns", "Capital Ship Targeting Logic", "Wingman Formation Flying", "IFF Determination", "Pathfinding Algorithm Used", etc.
2.  **List Potential Godot Solutions:**
    *   Map *each key feature* to specific Godot nodes, resources, classes, or design patterns.
    *   Specify *which* Godot nodes are most suitable (e.g., `RigidBody3D` vs. `CharacterBody3D`, `GPUParticles3D` vs. `CPUParticles3D`).
    *   Identify where custom GDScript logic is needed versus using built-in node properties/methods.
    *   Suggest relevant Godot addons if applicable (e.g., LimboAI).
    *   Propose custom `Resource` types (`.tres` files with associated `.gd` scripts) for storing complex data (e.g., `ShipData`, `WeaponData`, `AIProfile`, `MissionData`).
    *   *Guideline:* Justify choices. Explain *why* a specific Godot node or pattern is suitable.
3.  **Outline Target Code Structure:**
    *   Propose a specific directory structure within `scripts/`, `scenes/`, and `resources/` for this component.
    *   List key GDScript files (`.gd`) and scene files (`.tscn`) with brief descriptions of their roles.
    *   List key custom `Resource` files (`.tres`) and their associated scripts (`.gd`).
    *   *Guideline:* Ensure consistency with the overall project structure (Section IV). Use clear and consistent naming conventions (e.g., `ship_data.gd` for the script defining the `ShipData` resource, `ship_data_hercules.tres` for an instance).
4.  **Identify Important Methods, Classes, and Data Structures:**
    *   List the most critical C++ classes, structs, functions, and global variables.
    *   Describe their purpose in the original system.
    *   Explicitly state how each will be mapped or replaced in the Godot implementation (e.g., "struct `ship_info` -> `ShipData` Resource (`ship_data.gd`)", "function `snd_play_3d` -> `SoundManager.play_sound_3d()` method using `AudioStreamPlayer3D`").
    *   *Guideline:* Focus on elements crucial for understanding the logic and data flow. Include constants or enums if they define important states or types.
5.  **Identify Relations:**
    *   Describe dependencies: Which other C++ components does this one interact with? Which Godot systems/components will the new implementation interact with?
    *   Use text descriptions or Mermaid diagrams (`graph TD` or `classDiagram`) to visualize interactions (e.g., function calls, data access, signals).
    *   *Guideline:* Show how data flows between components (e.g., `MissionParser` creates `MissionData`, `MissionManager` uses `MissionData`, `HUD` reads state from `MissionManager`). Mention specific signals that might be used for communication.

## IV. Godot Project Structure

The target project structure is detailed in `tasks/project_structure.md`. Please refer to that document for the complete layout including directory purposes and component mapping.

## V. Conversion Strategy

The conversion strategy involves a phased approach:

1. **Analysis Phase**  
   * **Code Analysis:**  
     * Perform a detailed analysis of the C++ codebase, focusing on the components listed in Section III.  
     * For *each* component, follow the guidelines in Section III.B.  
     * Document dependencies *between* the components. This will inform the order of implementation.  
   * Map C++ classes/concepts to specific Godot nodes, scenes, resources, and GDScript classes.  
   * Identify core systems and inter-component dependencies.  
   * Document asset formats and conversion requirements.  
2. **Asset Conversion**  
   * Develop tools and scripts to extract and convert game assets to formats compatible with Godot.  
   * This may involve custom scripting or the use of existing conversion tools.  
3. **Core Systems Implementation**  
   * Implement the fundamental systems that the rest of the game relies on.  
   * This includes:  
     * Core Systems (game loop, object management)  
     * Controls & Camera (input handling, camera control)  
     * Menu & UI (basic framework)  
     * Physics & Space (basic setup)  
4. **Gameplay Systems Implementation**  
   * Implement the gameplay-specific components, building upon the core systems.  
   * This includes:  
     * AI  
     * Ship & Weapon Systems  
     * Mission System  
     * HUD System  
     * Graphics  
     * Sound & Animation  
5. **Testing and Optimization**  
   * Thoroughly test each component and the game as a whole.  
   * Optimize performance as needed.  
   * Address any platform-specific issues.

## VI. Task List

A detailed breakdown of the migration tasks, organized by phase and component, can be found in `tasks/todo.md`.
