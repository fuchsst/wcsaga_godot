# Wing Commander Saga Godot - Migration TODO List

This list details the tasks required for migrating Wing Commander Saga to Godot, organized by phase and referencing the relevant analysis documents (`tasks/XX_component_name.md`).

## Phase I: Project Setup, Tooling & Initial Analysis

**1. Project Setup & Configuration:**
    *   [Core] Create initial Godot project (`project.godot`).
    *   [Core] Define project structure (`tasks/project_structure.md`). **DONE**
    *   [Core] Set up Git repository & LFS.
    *   [Core] Configure Godot Project Settings:
        *   Rendering Backend (Forward+, Mobile, Compatibility).
        *   Display Settings (Resolution, Aspect Ratio).
        *   Physics Layers/Masks (Define layers for ships, weapons, asteroids, etc.). (See `10_physics_and_space.md`)
        *   Input Map Placeholders (Define core actions like `move_forward`, `fire_primary`, `target_next`). (See `12_controls_and_camera.md`)
    *   [Tools] Set up Python environment for conversion tools (`migration_tools/requirements.txt`).
    *   [Tools] Install Godot Addons: LimboAI. (See `01_ai.md`)

**2. Conversion Tooling (`migration_tools/`):** (See `03_asset_conversion_pipeline.md`)
    *   [Assets] Develop base converter framework (`convert.py`).
    *   [Assets] Implement VP archive extractor (`vp_extractor.py`).
    *   [Assets] Implement POF to GLTF + `ModelMetadata.tres` converter (`converters/pof_converter.py`). (See `11_model.md`)
        *   Sub-task: Parse geometry, UVs, hierarchy.
        *   Sub-task: Extract points (weapon, dock, thruster, glow), paths, insignias.
        *   Sub-task: Extract shield mesh.
        *   Sub-task: Extract subsystem definitions (`$props`).
        *   Sub-task: Create `ModelMetadata.tres` writer.
    *   [Assets] Implement ANI/EFF to `SpriteFrames.tres` + PNG converter (`converters/ani_converter.py`). (See `13_sound_and_animation.md`)
        *   Sub-task: Handle RLE decompression.
        *   Sub-task: Extract timing, keyframes, flags.
        *   Sub-task: Create `SpriteFrames.tres` writer.
    *   [Assets] Implement FS2 to `MissionData.tres` converter (`converters/fs2_converter.py`). (See `07_mission_system.md`)
        *   Sub-task: Implement SEXP parser (text to structure).
        *   Sub-task: Parse all FS2 sections.
        *   Sub-task: Map data to `MissionData` & related resources.
        *   Sub-task: Create `MissionData.tres` writer.
    *   [Assets] Implement TBL to Godot Resource/JSON converter (`converters/tbl_converter.py`). (See `08_scripting.md`)
        *   Sub-task: Generic TBL parser.
        *   Sub-task: Specific converters for `ships.tbl`, `weapons.tbl`, `ai_profiles.tbl`, `sounds.tbl`, `music.tbl`, `iff_defs.tbl`, `species_defs.tbl`, `rank.tbl`, `medals.tbl`, `hud_gauges.tbl`, `messages.tbl`, `cutscenes.tbl`, `asteroid.tbl`, `nebula.tbl`, `stars.tbl`, `scripting.tbl`, `help.tbl`.
        *   Sub-task: Convert `tstrings.tbl` to `.po` or `.csv`.
    *   [Assets] Implement Image Converter (DDS/PCX/TGA -> PNG/WebP) (`converters/image_converter.py`). (See `14_graphics.md`).
    *   [Assets] Implement Audio Converter (WAV/OGG) (`converters/audio_converter.py`). (See `13_sound_and_animation.md`).
    *   [Assets] Implement Video Converter (MVE/OGG -> OGV/WebM) (`converters/video_converter.py`). (See `13_sound_and_animation.md`).
    *   [Assets] Implement FNT Font Converter (if needed). (See `09_menu_ui.md`).
    *   [Tools] Develop asset validation framework/scripts.

**3. Initial Analysis & Design:**
    *   [All] Review and refine all `tasks/*.md` analysis documents. **DONE** (Implicitly via this task)
    *   [All] Finalize Godot project structure (`tasks/project_structure.md`). **DONE**
    *   [All] Finalize package diagram (`tasks/package_diagram.md`). **DONE**
    *   [All] Define and implement base `.gd` scripts for all custom Resource types (`scripts/resources/*.gd`).
    *   [Scripting] Finalize SEXP strategy (Hybrid). Define `SexpNode`. Implement parser. (See `08_scripting.md`).
    *   [Scripting] Finalize Hook system strategy (Signals). Define core signals. (See `08_scripting.md`).

## Phase II: Asset Conversion

*   [Assets] Extract assets from VP archives.
*   [Assets] Run all conversion scripts.
*   [Assets] Organize converted assets (`assets/`) and resources (`resources/`).
*   [Assets] Configure Godot import settings (textures, models, audio).
*   [Assets] Validate converted assets (scripts, manual checks).

## Phase III: Core Systems & Foundation Implementation

*   **Core Systems (`scripts/core_systems/`)** (See `04_core_systems.md`)
    *   [Core] Implement `GameManager.gd` (loop, time, pause).
    *   [Core] Implement `ObjectManager.gd` (tracking, lookup).
    *   [Core] Implement `BaseObject.gd`.
    *   [Core] Implement `GameSequenceManager.gd` (state stack, transitions).
    *   [Core] Implement `PlayerData.gd` resource; create default; implement load/save.
    *   [Core] Implement `ScoringManager.gd` (stat tracking). Load Rank/Medal resources.
    *   [Core] Implement `SpeciesManager.gd`; load `SpeciesInfo.tres`.
    *   [Core] Implement `GlobalConstants.gd`, `GameSettings.gd`.
    *   [Core] Implement `AutopilotManager.gd` (basic state). (See `12_controls_and_camera.md`).
    *   [Core] Implement `CameraManager.gd` (basic switching). (See `12_controls_and_camera.md`).
    *   [Core] Implement `SubtitleManager.gd` (queueing, basic display). (See `12_controls_and_camera.md`).
*   **Physics & Space (`scripts/physics_space/`)** (See `10_physics_and_space.md`)
    *   [Physics] Implement `SpacePhysics.gd` custom integrator.
    *   [Physics] Implement `AsteroidField.gd` & `Asteroid.gd`.
    *   [Physics] Implement `DebrisManager.gd` & `Debris*.gd`.
    *   [Physics] Implement `JumpNodeManager.gd` & `JumpNode.gd`.
*   **Scripting (`scripts/scripting/`)** (See `08_scripting.md`)
    *   [Scripting] Implement `SexpNode.gd`.
    *   [Scripting] Implement `sexp_parser.gd`.
    *   [Scripting] Implement `sexp_variables.gd`.
    *   [Scripting] Implement `sexp_evaluator.gd` & core `sexp_operators.gd`.
    *   [Scripting] Implement `script_system.gd` (Signal-based hooks).
    *   [Scripting] Implement `script_encryption.gd`.
*   **Model System (`scripts/model_systems/`)** (See `11_model.md`)
    *   [Model] Validate GLTF import.
    *   [Model] Implement `ModelMetadata.tres` loading/access.
    *   [Model] Set up `base_ship.tscn` linking resources.
*   **Sound & Animation (`scripts/sound_animation/`)** (See `13_sound_and_animation.md`)
    *   [Sound] Implement `SoundManager.gd` (basic playback).
    *   [Sound] Implement `MusicManager.gd` (basic playback).
    *   [Sound] Implement `GameSounds.gd` Autoload.
    *   [Sound] Implement `MusicData.gd` Autoload.
    *   [Animation] Implement `ani_player_2d.gd`.
*   **Controls & Camera (`scripts/controls_camera/`)** (See `12_controls_and_camera.md`)
    *   [Controls] Set up initial `InputMap`.
    *   [Controls] Implement `PlayerShipController.gd` (basic input reading).
    *   [Camera] Implement `BaseCameraController.gd`.
    *   [Camera] Set up basic player follow camera.
*   **Graphics (`scripts/graphics/`, `shaders/`)** (See `14_graphics.md`)
    *   [Graphics] Set up default `WorldEnvironment`.
    *   [Graphics] Implement `model_base.gdshader`.
    *   [Graphics] Implement `StarfieldManager.gd` (basic sky).
    *   [Graphics] Implement `NebulaManager.gd` (basic fog).
*   **UI System (`scripts/menu_ui/`, `scripts/hud/`)** (See `09_menu_ui.md`, `06_hud_system.md`)
    *   [UI] Implement base `wcsaga_theme.tres`.
    *   [UI] Implement `ui_element.gd` base script (if needed).
    *   [UI] Create placeholder `main_menu.tscn`.
    *   [HUD] Implement `HUDManager.gd` (config loading).
    *   [HUD] Implement basic `hud.tscn` & `hud.gd`.

## Phase IV: Gameplay Systems Implementation

*   **Ship & Weapon Systems (`scripts/ship_weapon_systems/`)** (See `05_ship_weapon_systems.md`)
    *   [Ship] Implement `ShipBase.gd` fully (state, energy).
    *   [Ship] Implement `ShieldSystem.gd` (quadrants, recharge, math).
    *   [Ship] Implement `DamageSystem.gd` (damage application, armor).
    *   [Ship] Implement `EngineSystem.gd` (afterburner).
    *   [Ship] Implement `TurretSubsystem.gd` aiming.
    *   [Weapon] Implement `WeaponSystem.gd` (banks, ammo, cycle, link).
    *   [Weapon] Implement `Weapon.gd` types (Laser, Missile, Beam, Flak, EMP).
    *   [Weapon] Implement `ProjectileBase.gd` types (Laser, Missile).
    *   [Weapon] Implement Beam logic.
    *   [Weapon] Implement Flak logic.
    *   [Weapon] Implement EMP logic.
    *   [Weapon] Implement Missile homing.
    *   [Weapon] Implement Swarm/Corkscrew missiles.
*   **AI System (`scripts/ai/`)** (See `01_ai.md`)
    *   [AI] Implement `AIController.gd` fully (state, flags).
    *   [AI] Integrate LimboAI (`BTPlayer`, `Blackboard`).
    *   [AI] Implement `TargetingSystem.gd` (find enemy, threat, aspect lock).
    *   [AI] Implement `Navigation` components (PathFollower, CollisionAvoidance).
    *   [AI] Implement `GoalManager.gd` integration.
    *   [AI] Create Behavior Trees for core modes (Chase, Evade, Waypoints, Guard, Dock, Strafe). Implement custom BT nodes.
    *   [AI] Implement `turret_ai.gd` logic.
    *   [AI] Implement Big Ship AI behaviors.
    *   [AI] Implement Countermeasure logic.
    *   [AI] Implement Docking/Guard/Repair/Rearm behaviors.
*   **Mission System (`scripts/mission_system/`)** (See `07_mission_system.md`)
    *   [Mission] Implement `MissionManager.gd` fully (evaluation loop).
    *   [Mission] Implement `ArrivalDepartureSystem.gd`.
    *   [Mission] Implement `SpawnManager.gd`.
    *   [Mission] Implement `MessageManager.gd` (queue, voice/anim, tokens).
    *   [Mission] Implement `MissionLogManager.gd`.
    *   [Mission] Implement `TrainingManager.gd`.
    *   [Mission] Implement Briefing system (`BriefingScreen.gd`, map, icons, camera).
    *   [Mission] Implement Debriefing system (`DebriefingScreen.gd`, stats, awards).
    *   [Mission] Implement Command Briefing system.
    *   [Mission] Integrate SEXP evaluation fully. Implement remaining operators.
*   **Campaign System (`scripts/campaign/`)** (See `07_mission_system.md`)
    *   [Campaign] Implement `CampaignManager.gd` (progression, branching).
    *   [Campaign] Implement `CampaignSaveData` saving/loading.
    *   [Campaign] Implement ship/weapon pool logic.
*   **Graphics (`scripts/graphics/`, `shaders/`)** (See `14_graphics.md`, `10_physics_and_space.md`)
    *   [Graphics] Implement Effect Managers (Explosion, Decal, Shockwave, Trail, MuzzleFlash, Warp, Spark).
    *   [Graphics] Create effect scenes (`explosion.tscn`, etc.).
    *   [Graphics] Implement shield impact shader/effect.
    *   [Graphics] Implement warp effect shader/scene.
    *   [Graphics] Implement cloak effect shader.
    *   [Graphics] Implement engine wash/contrail effects.
    *   [Graphics] Refine lighting/environment per mission type.
*   **Sound & Animation (`scripts/sound_animation/`)** (See `13_sound_and_animation.md`)
    *   [Sound] Implement channel limiting/prioritization in `SoundManager`.
    *   [Sound] Implement 3D audio parameter mapping.
    *   [Sound] Implement event music state machine fully in `MusicManager`. Connect signals.
    *   [Animation] Ensure `ani_player_2d.gd` handles all modes.
*   **Controls & Camera (`scripts/controls_camera/`)** (See `12_controls_and_camera.md`)
    *   [Controls] Implement full player control in `PlayerShipController.gd`.
    *   [Camera] Implement all camera modes in `CameraController` scripts.
    *   [Camera] Implement smooth camera transitions (`Tween`).
    *   [Camera] Implement cinematic autopilot camera (`AutopilotCameraController.gd`).
    *   [Camera] Implement subtitle display (`SubtitleDisplay.gd`).
    *   [Autopilot] Implement Autopilot logic fully (`AutopilotManager.gd`).
    *   [Autopilot] Implement NavPoint selection UI/logic.
*   **UI System (`scripts/menu_ui/`, `scripts/hud/`)** (See `09_menu_ui.md`, `06_hud_system.md`)
    *   [UI] Implement all core UI components (`WCSagaButton`, etc.).
    *   [UI] Implement Main Menu, Options, Pilot Management screens.
    *   [UI] Implement Ready Room, Tech Room, Lab Viewer screens.
    *   [UI] Implement Control Config screen.
    *   [UI] Implement Ship/Weapon selection screens.
    *   [UI] Implement Popup system.
    *   [UI] Implement Context Help system.
    *   [HUD] Implement all HUD gauges (Radar, Shield, Target Box, etc.).
    *   [HUD] Implement Squad Message system.
    *   [HUD] Implement HUD configuration screen.

## Phase V: Testing and Optimization

*   [Testing] Implement unit tests (Physics, SEXP, Damage, Scoring).
*   [Testing] Perform integration tests (Combat, Mission, Navigation).
*   [Testing] Test mission loading/execution with diverse missions.
*   [Testing] Test campaign progression, branching, save/load.
*   [Testing] Test UI navigation, functionality, data accuracy.
*   [Testing] Validate asset appearance/behavior vs original.
*   [Optimization] Profile performance (CPU, GPU, Memory).
*   [Optimization] Optimize rendering (Shaders, LODs, Culling, MultiMesh).
*   [Optimization] Optimize physics (Layers, Integrator).
*   [Optimization] Optimize GDScript (Algorithms, Built-ins).
*   [Bug Fixing] Address testing issues.
*   [Platform] Test on Windows, Linux.

## Phase VI: Polish & Release Prep

*   [Polish] Refine effects, animations, UI transitions.
*   [Polish] Balance gameplay (Stats, Damage, AI, Difficulty).
*   [Polish] Refine audio mix (Volumes, Spatialization, Effects).
*   [Polish] Improve UI/UX based on feedback.
*   [Docs] Finalize documentation.
*   [Build] Prepare release builds.
