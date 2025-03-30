# Wing Commander Saga: Godot Conversion Analysis - Component 07: Mission System

This document analyzes the Mission System from the original Wing Commander Saga C++ codebase and proposes an implementation strategy for the Godot conversion project, following the guidelines in `tasks/00_analysis_setup.md`.

*Source Code Folders:* `mission/` (core logic, parsing, goals, events, log), `missionui/` (briefing, debriefing, campaign UI, hotkeys), `parse/` (SEXP evaluation, table parsing utilities), `variables/` (SEXP variables)

## 1. Original System Overview

The Mission System is the core component responsible for loading, parsing, executing, and managing the state of individual missions and their progression within a campaign. It orchestrates gameplay events, tracks objectives, handles dynamic ship spawning, manages communication, and interfaces with various UI screens (briefing, debriefing). Key C++ files include `missionparse.cpp`, `missiongoals.cpp`, `missioncampaign.cpp`, `missionbriefcommon.cpp`, `missionmessage.cpp`, `missionlog.cpp`, `missionhotkey.cpp`, and `missiontraining.cpp`.

```mermaid
graph TD
    MS[Mission System] --> MP[Mission Parsing (.fs2)];
    MS --> BS[Briefing System];
    MS --> MF[Mission Flow & Events];
    MS --> CS[Campaign System];
    MS --> DS[Debriefing System];
    MS --> TS[Training System];
    MS --> LS[Mission Log];
    MS --> HS[Mission Hotkeys];

    MP --> FS2[FS2 File Format];
    MP --> OBJ[Object/Wing Placement];
    MP --> WP[Waypoint Data];
    MP --> GOALS[Goals/Objectives];
    MP --> EVENTS[Events];
    MP --> VARS[Variables];
    MP --> REIN[Reinforcements];
    MP --> DOCK[Initial Docking];
    MP --> ENV[Environment Setup];

    BS --> BMAP[Briefing Map Display];
    BS --> BTEXT[Briefing Text/Voice];
    BS --> BICONS[Briefing Icons/Lines];
    BS --> BCAM[Briefing Camera];
    BS --> CBRIEF[Command Briefing];

    MF --> OT[Objective Tracking];
    MF --> ET[Event Triggering (SEXP)];
    MF --> SPAWN[Dynamic Spawning];
    MF --> SFC[Success/Failure Conditions];
    MF --> COMM[In-Mission Communication];
    MF --> ARRDEP[Arrival/Departure Logic];
    MF --> SUPP[Support Ship Logic];

    CS --> CPROG[Campaign Progression];
    CS --> CBRANCH[Branching Logic (SEXP)];
    CS --> CPERSIST[State Persistence];
    CS --> CPOOL[Ship/Weapon Pools];

    DS --> DRESULTS[Results Display];
    DS --> DPERF[Performance Evaluation];
    DS --> DAWARDS[Medal/Rank Awards];
    DS --> DSTAGES[Debriefing Stages (SEXP)];

    TS --> TDIR[Directive Display];
    TS --> TMSG[Training Messages];
    TS --> TFAIL[Failure Detection];

    LS --> LREC[Event Recording];
    LS --> LDISP[Log Display];

    HS --> HASSIGN[Hotkey Assignment];
    HS --> HPERSIST[Hotkey Persistence];

    MS --> SEXPSYSTEM[SEXP System];
    MS --> MSG SYSTEM[Message System];
    MS --> AI SYSTEM[AI System];
    MS --> SHIP SYSTEM[Ship System];
    MS --> HUD SYSTEM[HUD System];
    MS --> CORE SYSTEM[Core Systems];

    SEXPSYSTEM --> MF;
    SEXPSYSTEM --> BS;
    SEXPSYSTEM --> DS;
    SEXPSYSTEM --> CS;
    MSG SYSTEM --> MF;
    MSG SYSTEM --> TS;
    AI SYSTEM --> MF;
    SHIP SYSTEM --> MF;
    HUD SYSTEM --> MF;
    HUD SYSTEM --> TS;
    CORE SYSTEM --> MS;
```

## 2. Detailed Component Analysis

### 2.1. Mission Loading and Parsing (`missionparse.cpp`, `missionparse.h`)

1.  **Key Features:**
    *   **File Parsing:** Reads `.fs2` mission files section by section (`#Mission Info`, `#Players`, `#Objects`, `#Wings`, `#Events`, `#Goals`, `#Waypoints`, `#Messages`, `#Reinforcements`, `#Background bitmaps`, `#Asteroid Fields`, `#Sexp_variables`, `#Briefing`, `#Debriefing_info`, `#Command Briefing`, etc.).
    *   **Data Population:** Populates internal structures (`mission`, `p_object`, `wing`, `mission_event`, `mission_goal`, `waypoint_list`, `briefing`, `debriefing`, `cmd_brief`, `reinforcements`, `asteroid_field`) with parsed data.
    *   **Object/Wing Data:** Parses ship/wing properties: class, name, team, position, orientation, initial velocity/hull/shields, AI behavior/goals, cargo, arrival/departure cues (SEXP), locations (Hyperspace, Near Ship, Dock Bay), anchors, delays, flags (`P_SF_*`, `P_OF_*`, `WF_*`), subsystem status, texture replacements (`$Texture Replace`), alternate types (`$Alt`), callsigns (`$Callsign`), hotkeys, score, persona index.
    *   **Player Start:** Parses player ship choices (`$Ship Choices`), weapon pools (`+Weaponry Pool`), and starting ship (`$Starting Shipname`).
    *   **Initial State:** Sets up initial docking (`Initially_docked`), arrival/departure state (`Ship_arrival_list`), SEXP variables, environment settings (backgrounds, nebula, storm).
    *   **Support Ships:** Parses support ship settings (`+Disallow Support`, `+Hull Repair Ceiling`, etc.) and handles logic for bringing them in (`mission_bring_in_support_ship`).
    *   **Multiplayer:** Handles multiplayer-specific sections (respawns, teams, network signatures).
    *   **Post-Processing:** `post_process_mission()` finalizes setup after parsing (resolving names, setting up docks, initial arrivals). `mission_parse_set_arrival_locations()` calculates initial positions for arriving ships/wings.

2.  **Potential Godot Solutions:**
    *   **Parsing:** Implement an FSM/FS2 to JSON/`.tres` converter script (Python recommended) as part of the asset pipeline. This avoids complex runtime parsing in GDScript.
    *   **Data Representation:** Define custom Godot `Resource` types for each major data structure:
        *   `MissionData` (`mission_data.gd`): Top-level mission info, lists of other resources.
        *   `PlayerStartData` (`player_start_data.gd`): Ship choices, weapon pools per team.
        *   `ShipInstanceData` (`ship_instance_data.gd`): Parsed ship object data (class, name, team, pos, orient, initial state, goals, cues, flags, subsystems, etc.). Replaces `p_object`.
        *   `WingInstanceData` (`wing_instance_data.gd`): Parsed wing data (name, waves, threshold, cues, goals, flags, ship references). Replaces `wing`.
        *   `WaypointListData` (`waypoint_list_data.gd`): Array of `Vector3` points.
        *   `MissionEventData` (`mission_event_data.gd`): Event definition (name, formula SEXP, repeat, interval, score, objective text).
        *   `MissionObjectiveData` (`mission_objective_data.gd`): Goal definition (name, type, message, formula SEXP, flags, score, team). Replaces `mission_goal`.
        *   `ReinforcementData` (`reinforcement_data.gd`): Reinforcement definition (name, type, uses, messages).
        *   `BriefingData` (`briefing_data.gd`): Contains stages, icons, lines, camera info.
        *   `DebriefingData` (`debriefing_data.gd`): Contains stages, conditions.
        *   `SEXPVariableData` (`sexp_variable_data.gd`): Initial SEXP variable definitions.
        *   `DockingPairData` (`docking_pair_data.gd`): Stores initial docking pairs (docker name, dockee name, points).
    *   **Loading:** `MissionManager` loads the main `MissionData.tres` resource for the selected mission.
    *   **Object/Wing Management:** `MissionManager` holds arrays of `ShipInstanceData` and `WingInstanceData` from the loaded `MissionData`. It manages their runtime state (arrival, departure, destruction).
    *   **Arrival/Departure:** Logic within `MissionManager` or a dedicated `ArrivalDepartureSystem` node, triggered by SEXP evaluation results from the `SEXPSystem`. Uses timers for delays.
    *   **Docking:** Initial docking state set based on `DockingPairData`. Runtime docking managed by `DockingManager` (see Core Systems) using `Marker3D` points and transforms.
    *   **Subsystem Status:** Initial status stored in `ShipInstanceData`, applied to the ship scene instance by `MissionManager` or the ship's `_ready()` function.
    *   **Texture Replacement:** Apply material overrides in the ship's `_ready()` function based on data in `ShipInstanceData`.
    *   **Multiplayer:** Use Godot's `MultiplayerAPI` and RPCs. Network signatures managed via `MultiplayerSpawner`.

3.  **Outline Target Code Structure:**
    ```
    scripts/mission_system/
    ├── mission_manager.gd       # Singleton: Manages mission lifecycle, state, objects, events, goals.
    ├── arrival_departure.gd     # Node/Helper: Handles arrival/departure logic and timing.
    ├── spawn_manager.gd         # Node/Helper: Handles instantiating ships/wings.
    ├── mission_loader.gd        # Helper: Loads MissionData resources.
    ├── parsing/                 # Scripts defining custom Resource types for parsed data
    │   ├── mission_data.gd
    │   ├── player_start_data.gd
    │   ├── ship_instance_data.gd
    │   ├── wing_instance_data.gd
    │   ├── waypoint_list_data.gd
    │   ├── mission_event_data.gd
    │   ├── mission_objective_data.gd
    │   ├── reinforcement_data.gd
    │   ├── briefing_data.gd
    │   ├── debriefing_data.gd
    │   ├── sexp_variable_data.gd
    │   └── docking_pair_data.gd
    ├── briefing/                # Briefing system scripts
    │   ├── briefing_screen.gd
    │   ├── briefing_map_manager.gd
    │   └── briefing_icon.gd
    ├── debriefing/              # Debriefing system scripts
    │   └── debriefing_screen.gd
    ├── log/                     # Mission Log scripts
    │   ├── mission_log_manager.gd
    │   └── mission_log_entry.gd
    ├── message_system/          # Message system scripts
    │   ├── message_manager.gd
    │   ├── message_data.gd
    │   └── persona_data.gd
    ├── training_system/         # Training system scripts
    │   └── training_manager.gd
    └── hotkey/                  # Mission Hotkey scripts (if managed here)
        └── mission_hotkey_manager.gd
    resources/missions/          # Converted mission data (.tres files)
    │   ├── mission_01.tres
    │   └── campaign_a/
    │       └── mission_a_01.tres
    scenes/missions/             # Mission-specific scenes (if needed beyond resources)
    │   ├── briefing/
    │   │   ├── briefing_screen.tscn
    │   │   ├── briefing_map_viewport.tscn
    │   │   └── briefing_icon.tscn
    │   └── debriefing/
    │       └── debriefing_screen.tscn
    ```
    *(Structure refined for clarity and consistency)*

4.  **Important Methods, Classes, Data Structures:**
    *   `struct mission`: -> `MissionData` resource.
    *   `struct p_object`: -> `ShipInstanceData` resource.
    *   `struct wing`: -> `WingInstanceData` resource.
    *   `struct mission_event`: -> `MissionEventData` resource.
    *   `struct mission_goal`: -> `MissionObjectiveData` resource.
    *   `struct waypoint_list`: -> `WaypointListData` resource.
    *   `struct briefing`, `struct brief_stage`, `struct brief_icon`, `struct brief_line`: -> `BriefingData` resource (or part of `MissionData`).
    *   `struct debriefing`, `struct debrief_stage`: -> `DebriefingData` resource (or part of `MissionData`).
    *   `struct reinforcements`: -> `ReinforcementData` resource.
    *   `struct asteroid_field`: -> `AsteroidFieldData` resource (used by Physics/Space system).
    *   `struct sexp_variable`: -> `SEXPVariableData` resource.
    *   `Initially_docked` array: -> `DockingPairData` resource array.
    *   `Parse_objects` vector: -> `MissionData.ships` array (of `ShipInstanceData`).
    *   `Wings` array: -> `MissionData.wings` array (of `WingInstanceData`).
    *   `parse_mission()`: -> Asset conversion script + `MissionLoader.load_mission()`.
    *   `post_process_mission()`: -> `MissionManager.finalize_load()`.
    *   `mission_eval_arrivals()` / `mission_eval_departures()`: -> `ArrivalDepartureSystem._process()`.
    *   `mission_set_arrival_location()`: -> Helper function in `ArrivalDepartureSystem` or `SpawnManager`.
    *   `parse_dock_one_docked_object()`: -> Part of `MissionManager.finalize_load()` or `DockingManager` init.
    *   `parse_create_object()`: -> `SpawnManager.spawn_ship()`.
    *   `parse_wing_create_ships()`: -> `SpawnManager.spawn_wing_wave()`.

5.  **Identify Relations:**
    *   **Mission Parser** (offline tool) creates `MissionData` resources.
    *   **Mission Loader** loads the appropriate `MissionData` resource.
    *   **Mission Manager** holds the loaded `MissionData`, manages runtime state, and orchestrates other mission systems.
    *   **Arrival/Departure System** uses `MissionData` cues and timers, interacts with `SpawnManager` and `SEXPSystem`.
    *   **Spawn Manager** instantiates ship/wing scenes based on `ShipInstanceData`/`WingInstanceData`, interacting with the `ObjectManager` (Core Systems).
    *   **Briefing/Debriefing Systems** read data from `MissionData` and display UI.
    *   **SEXPSystem** evaluates formulas stored in `MissionData` (goals, events, cues).
    *   **Campaign System** provides the next mission file path to the `Mission Loader`.

### 2.2. Briefing System (`missionbriefcommon.cpp`, `missionbrief.cpp`, `missioncmdbrief.cpp`)

1.  **Key Features:**
    *   **Stages:** Presents mission info in sequential stages (`brief_stage`, `cmd_brief_stage`).
    *   **Content:** Each stage includes text, voice narration, camera position/orientation (briefing), icons/lines (briefing), or full-screen animation (command brief).
    *   **Tactical Map (Briefing):** Renders a 3D map with icons (`brief_icon`) representing ships/wings/waypoints, connecting lines (`brief_line`), and a grid (`The_grid`). Supports icon highlighting, fading, and movement between stages.
    *   **Camera Control (Briefing):** Smoothly interpolates camera position/orientation between stages (`brief_camera_move`).
    *   **Text/Voice:** Displays text with color coding and wipe effect (`brief_render_text`). Plays synchronized voice (`brief_voice_play`, `cmd_brief_voice_play`). Supports auto-advance.
    *   **UI:** Provides buttons for stage navigation, scrolling, pause/play, help, options, commit.

2.  **Potential Godot Solutions:**
    *   **Scenes:** `BriefingScreen.tscn`, `CommandBriefScreen.tscn`. Use `Control` nodes for UI.
    *   **Data:** `BriefingData`/`CommandBriefData` resources (part of `MissionData`) store stage info (text, voice path, camera transforms, icon data/animation path).
    *   **Map (Briefing):** `SubViewport` with `Camera3D`. `Node3D` instances for icons (`BriefingIcon.tscn`). `ImmediateMesh` or `LineRenderer` addon for lines. `GridMap` or custom drawing for grid.
    *   **Animation (Command Brief):** `VideoStreamPlayer` or `AnimationPlayer` controlling sprites/textures.
    *   **Camera/Icon Animation:** `Tween` or `AnimationPlayer`.
    *   **Text/Voice:** `RichTextLabel` (with BBCode) for text display and wipe effect. `AudioStreamPlayer` for voice. Synchronization via timers/signals.

3.  **Outline Target Code Structure:** (See Section 2.1.3)

4.  **Important Methods, Classes, Data Structures:**
    *   `struct brief_stage`, `struct brief_icon`, `struct brief_line`: -> `BriefingData` resource structure.
    *   `struct cmd_brief`, `struct cmd_brief_stage`: -> `CommandBriefData` resource structure.
    *   `brief_init()`, `cmd_brief_init()`: -> `_ready()` in `BriefingScreen.gd`/`CommandBriefScreen.gd`.
    *   `brief_do_frame()`, `cmd_brief_do_frame()`: -> `_process()` in respective screen scripts.
    *   `brief_render_map()`, `brief_render_text()`, `brief_camera_move()`, `brief_voice_play()`: -> Helper methods within `BriefingScreen.gd` and `BriefingMapManager.gd`.
    *   `cmd_brief_voice_play()`, `generic_anim_render()`: -> Helper methods within `CommandBriefScreen.gd`.

5.  **Identify Relations:** Reads `BriefingData`/`CommandBriefData` from `MissionData`. Interacts with `UI System`, `SoundManager`, `Asset Pipeline` (icons, animations, voice). Controlled by `GameSequenceManager`.

### 2.3. Mission Flow and Events (`missiongoals.cpp`, `missiongoals.h`)

1.  **Key Features:**
    *   **Objective Tracking:** Manages `mission_goal` array. Tracks status (`satisfied`: `GOAL_INCOMPLETE`, `GOAL_COMPLETE`, `GOAL_FAILED`). Evaluates SEXP formulas (`formula`) to update status (`mission_eval_goals`). Handles validation flags (`INVALID_GOAL`).
    *   **Event Triggering:** Manages `mission_event` array. Evaluates SEXP formulas (`formula`). Triggers based on result and timing (interval `interval`, repeat count `repeat_count`, chaining `chain_delay`). Can update score (`score`) or display objective text (`objective_text`).
    *   **Success/Failure:** `mission_evaluate_primary_goals()` checks status of primary goals. `mission_goal_fail_incomplete()` marks remaining goals as failed.
    *   **Directives:** HUD display of current objectives/events (`training_obj_display` - also used here). Sound cues (`Mission_directive_sound_timestamp`).

2.  **Potential Godot Solutions:**
    *   **Management:** `MissionManager` singleton manages arrays of `MissionObjectiveData` and `MissionEventData` resources.
    *   **Evaluation:** `MissionManager._process()` calls `SEXPSystem.evaluate_expression()` for active goals/events.
    *   **State:** Store runtime status (`is_completed`, `is_failed`, `has_triggered`, `trigger_count`) directly within the instantiated `MissionObjectiveData`/`MissionEventData` resources or in parallel dictionaries within `MissionManager`.
    *   **Signals:** Emit signals (`objective_updated(objective_resource)`, `event_triggered(event_resource)`) from `MissionManager`.
    *   **Directives:** `HUDManager` listens for `objective_updated` signal to update the directives display. `SoundManager` plays cues.

3.  **Outline Target Code Structure:** (See Section 2.1.3)
    *   Add `scripts/missions/mission_objective.gd` (Resource script).

4.  **Important Methods, Classes, Data Structures:**
    *   `struct mission_goal`: -> `MissionObjectiveData` resource.
    *   `struct mission_event`: -> `MissionEventData` resource.
    *   `Mission_goals[]`, `Num_goals`: -> `MissionData.objectives` array.
    *   `Mission_events[]`, `Num_mission_events`: -> `MissionData.events` array.
    *   `mission_eval_goals()`: -> Core logic in `MissionManager._process()`.
    *   `mission_process_event()`: -> Helper method called by `MissionManager._process()`.
    *   `mission_goal_status_change()`: -> Method in `MissionManager`, emits signal.
    *   `mission_evaluate_primary_goals()`: -> Method in `MissionManager`.

5.  **Identify Relations:** `MissionManager` orchestrates. Calls `SEXPSystem`. Updates `MissionObjectiveData`/`MissionEventData` state. Emits signals to `HUDManager`, `SoundManager`, potentially `CampaignManager`.

### 2.4. SEXP System (`sexp.cpp`, `sexp.h`, `variables.cpp`, `variables.h`)

1.  **Key Features:** Lisp-like evaluation tree (`sexp_node`). Large operator library (`OP_*`). Variable system (`sexp_variable`, `@var_name`) with persistence. Recursive evaluation (`eval_sexp`). Syntax checking.
2.  **Potential Godot Solutions:** Hybrid approach: Parse SEXP structure into Godot Arrays/Dictionaries. Implement `SEXPSystem` singleton with `evaluate_expression(data, context)` method. Implement operators as GDScript functions/lambdas within `SEXPSystem` or a helper node, accessing game state via `context` object or Singletons. Manage variables (`SexpVariableManager`) with persistence linked to `CampaignManager`/`PlayerData`.
3.  **Outline Target Code Structure:** (See `08_scripting.md`)
4.  **Important Methods, Classes, Data Structures:** `sexp_node`, `sexp_variable`, `Operators[]`, `eval_sexp`, `is_sexp_true`, `check_sexp_syntax`.
5.  **Identify Relations:** Used by `MissionManager` (goals, events, cues), `CampaignManager` (branching), potentially AI. Operators interact with nearly all other game systems.

### 2.5. Message System (`missionmessage.cpp`, `missionmessage.h`)

1.  **Key Features:** Manages built-in and mission messages (`MMessage`, `messages.tbl`). Queues messages (`message_q`) by priority/timing. Plays voice (WAV) and head animations (ANI/MVE). Supports personas (`Persona`) linked to ships/messages. Handles token replacement (`$token$`, `#token#`). Multiplayer filtering. Distortion effects.
2.  **Potential Godot Solutions:** `MessageManager` singleton. `MessageData` resource (text, voice path, animation path, persona ref). `PersonaData` resource. Queue using sorted `Array`. `AudioStreamPlayer` for voice. `AnimationPlayer`/`VideoStreamPlayer` in HUD `SubViewport` for heads. Token replacement via `String.format()` or custom parser. Distortion via `AudioEffectDistortion` or text manipulation.
3.  **Outline Target Code Structure:** (See Section 2.1.3)
4.  **Important Methods, Classes, Data Structures:** `struct MMessage` -> `MessageData`. `struct Persona` -> `PersonaData`. `struct message_q` -> Internal queue structure. `message_queue_message()` -> `MessageManager.queue_message()`. `message_queue_process()` -> `MessageManager._process()`. `message_play_wave()` -> `MessageManager` using `AudioStreamPlayer`. `message_play_anim()` -> `MessageManager` controlling HUD animation node. `message_translate_tokens()` -> Helper function. `message_send_*()` -> `MessageManager.send_*()`.
5.  **Identify Relations:** Called by `MissionManager`, `SEXPSystem`, AI. Interacts with HUD, `SoundManager`, `Asset Pipeline`.

### 2.6. Training System (`missiontraining.cpp`, `missiontraining.h`)

1.  **Key Features:** Displays directives (`training_obj_display`). Queues/plays timed training messages (`Training_message_queue`, `message_training_setup/display/queue`). Handles bold formatting (`<b>`). Tracks failure state (`Training_failure`). Sorts objectives (`sort_training_objectives`). Checks key bindings (`translate_message_token`).
2.  **Potential Godot Solutions:** `TrainingManager` singleton (or part of `MissionManager`). Reuse/adapt HUD directives gauge (`hud_directives_gauge.tscn/gd`). Queue messages in `Array`. Use `MessageManager` or dedicated UI (`RichTextLabel`) for messages. Failure state as bool flag. Sorting logic in `TrainingManager`. Key binding check via `InputMap`.
3.  **Outline Target Code Structure:** (See Section 2.1.3)
4.  **Important Methods, Classes, Data Structures:** `training_mission_init()` -> `_ready()`. `training_check_objectives()` -> Periodic update. `training_obj_display()` -> HUD gauge script. `message_training_queue()` -> `TrainingManager.queue_message()`. `message_training_setup/display()` -> Internal logic. `training_fail()` -> `TrainingManager.fail()`. `Training_obj_lines`, `Training_message_queue` -> Arrays in manager/HUD script.
5.  **Identify Relations:** Interacts with `MissionManager` (objectives), `MessageManager`/HUD (messages), `InputMap`. Triggered by `SEXPSystem`.

### 2.7. Debriefing System (`missionbriefcommon.cpp`, `missiondebrief.cpp`)

1.  **Key Features:** Presents post-mission results in stages (`debrief_stage`). Evaluates SEXP conditions (`formula`) to determine which stages to show. Displays text, recommendations, voice. Shows statistics (`debrief_stats_render`), kill lists (`debrief_setup_ship_kill_stats`). Handles awards (medals, promotions, badges) (`debrief_award_init`). Multiplayer support.
2.  **Potential Godot Solutions:** `DebriefingScreen.tscn` scene. `DebriefingData` resource (part of `MissionData`). `DebriefingScreen.gd` evaluates stage SEXPs via `SEXPSystem`, displays text (`RichTextLabel`), plays voice (`AudioStreamPlayer`), shows stats (`Label`, `ItemList`), medals (`TextureRect`). `ScoringSystem` helper calculates awards.
3.  **Outline Target Code Structure:** (See Section 2.1.3)
4.  **Important Methods, Classes, Data Structures:** `struct debriefing`, `struct debrief_stage` -> `DebriefingData`. `debrief_init()` -> `_ready()`. `debrief_do_frame()` -> `_process()`. `debrief_stats_render()`, `debrief_award_init()` -> Helper methods. `parse_debriefing_new()` -> `MissionParser`.
5.  **Identify Relations:** Reads `DebriefingData`, mission results/stats from `MissionManager`/`MissionLogManager`. Calls `SEXPSystem`. Interacts with `UI System`, `SoundManager`, `CampaignManager`. Controlled by `GameSequenceManager`.

### 2.8. Campaign System (`missioncampaign.cpp`, `missioncampaign.h`)

1.  **Key Features:** Loads campaign definitions (`.fsc`). Manages mission sequence (`campaign`, `cmission`), progress (`next_mission`, `num_missions_completed`), looping (`loop_mission`). Evaluates SEXP formulas for branching (`mission_campaign_eval_next_mission`). Saves/loads progress (`.cs2` files) including completed goals/events, stats, persistent variables (`mission_campaign_savefile_save/load`). Manages ship/weapon pools (`ships_allowed`, `weapons_allowed`).
2.  **Potential Godot Solutions:** `CampaignManager` singleton. `CampaignData` resource (from `.fsc`). `CampaignSaveData` resource/Dictionary (for `.cs2`). `CampaignParser` loads `.fsc`. `CampaignManager` handles progression, branching (via `SEXPSystem`), saving/loading (`ConfigFile` or `ResourceSaver`). Ship/weapon pools stored in `CampaignSaveData`.
3.  **Outline Target Code Structure:** (See `scripts/campaign/` in Section 2.1.3)
4.  **Important Methods, Classes, Data Structures:** `struct campaign` -> `CampaignData`. `struct cmission` -> Structure within `CampaignData`. `mission_campaign_load()` -> `CampaignParser.load()`. `mission_campaign_savefile_save/load()` -> `CampaignManager.save/load()`. `mission_campaign_eval_next_mission()` -> `CampaignManager.evaluate_next()`. `mission_campaign_store_goals_and_events_and_variables()` -> Part of save logic.
5.  **Identify Relations:** Provides mission file to `MissionLoader`. Receives results from `MissionManager`. Calls `SEXPSystem`. Interacts with `PlayerData`, `LoadoutScreen`, `TechDatabaseManager`.

### 2.9. Mission Hotkeys (`missionhotkey.cpp`, `missionhotkey.h`)

1.  **Key Features:** Assigns ships/wings to F5-F12 (`Key_sets`). Stores assignments (`Player->keyed_targets`). Handles defaults from mission file (`p_object->hotkey`, `wing->hotkey`). Temporary save/restore (`Hotkey_saved_info`). UI screen for management (`mission_hotkey_init/do_frame`). Validation (`mission_hotkey_validate`).
2.  **Potential Godot Solutions:** `HotkeyManager` singleton or part of `PlayerData`. Store assignments in `Dictionary` within `CampaignSaveData`. `PlayerTargeting` script handles selection on key press. `MissionManager` applies defaults. `HotkeyScreen.tscn/gd` for UI.
3.  **Outline Target Code Structure:** (See `scripts/player/`, `scenes/ui/hotkey_screen/` in Section 2.1.3)
4.  **Important Methods, Classes, Data Structures:** `Key_sets` -> Constants. `Player->keyed_targets` -> `Dictionary`. `hud_target_hotkey_add_remove()` -> `HotkeyManager.assign/remove()`. `mission_hotkey_set_defaults()` -> `HotkeyManager.apply_defaults()`. `mission_hotkey_init/do_frame/close()` -> `HotkeyScreen.gd`.
5.  **Identify Relations:** Modifies `CampaignSaveData`. Read by `PlayerTargeting`. Defaults set by `MissionManager`. UI interacts with `HotkeyManager`. Save/Load handled by `CampaignManager`.

### 2.10. Mission Log (`missionlog.cpp`, `missionlog.h`)

1.  **Key Features:** Stores chronological event list (`log_entry`). Records type, timestamp, entity names/display names, team. Supports various event types (`LOG_*`). Multiplayer sync (`mission_log_add_entry_multi`). Culling/obsolescence (`mission_log_cull_obsolete_entries`). UI display formatting (`message_log_init_scrollback`). Hiding entries (`MLF_HIDDEN`).
2.  **Potential Godot Solutions:** `MissionLogManager` singleton. Store entries in `Array` (of `Dictionary` or `MissionLogEntry` resource). `add_entry()` method called by other systems. RPCs for multiplayer sync. Culling logic in manager. `MissionLogScreen.tscn/gd` for UI (`RichTextLabel` or `ItemList`).
3.  **Outline Target Code Structure:** (See Section 2.1.3)
4.  **Important Methods, Classes, Data Structures:** `struct log_entry` -> `Dictionary` or `MissionLogEntry` resource. `log_entries` -> `Array`. `mission_log_add_entry()` -> `MissionLogManager.add_entry()`. `message_log_init_scrollback()`, `mission_log_scrollback()` -> `MissionLogScreen.gd` UI logic. `mission_log_cull_obsolete_entries()` -> `MissionLogManager.cull_log()`.
5.  **Identify Relations:** Receives calls from `MissionManager`, `ShipManager`, etc. Read by `MissionLogScreen`, `DebriefingScreen`. Uses `MultiplayerAPI`.

## 3. Godot Project Structure (Mission System)

```
wcsaga_godot/
├── resources/
│   ├── missions/           # MissionData resources (.tres) - Converted from .fs2
│   │   ├── mission_01.tres
│   │   └── campaign_a/
│   │       └── mission_a_01.tres
│   ├── objectives/         # MissionObjectiveData resources (.tres) - Part of MissionData
│   ├── events/             # MissionEventData resources (.tres) - Part of MissionData
│   ├── waves/              # WaveData resources (.tres) - Part of MissionData
│   ├── reinforcements/     # ReinforcementData resources (.tres) - Part of MissionData
│   ├── briefing_data/      # BriefingData resources (.tres) - Part of MissionData
│   ├── debriefing_data/    # DebriefingData resources (.tres) - Part of MissionData
│   ├── messages/           # MessageData, PersonaData resources (.tres) - Global or Mission-specific
│   │   ├── personas/
│   │   └── mission_messages/
│   ├── variables/          # SEXPVariableData resources (.tres) - Part of MissionData
│   ├── waypoints/          # WaypointListData resources (.tres) - Part of MissionData
│   └── docking/            # DockingPairData resources (.tres) - Part of MissionData
├── scenes/
│   ├── missions/           # Scenes related to mission flow
│   │   ├── briefing/
│   │   │   ├── briefing_screen.tscn
│   │   │   ├── briefing_map_viewport.tscn
│   │   │   └── briefing_icon.tscn
│   │   ├── debriefing/
│   │   │   └── debriefing_screen.tscn
│   │   └── command_brief/
│   │       └── command_brief_screen.tscn
│   ├── ui/                 # UI scenes used by mission system
│   │   ├── hud/
│   │   │   ├── hud_directives_gauge.tscn
│   │   │   └── talking_head.tscn
│   │   └── mission_log/
│   │       └── mission_log_screen.tscn
│   │   └── hotkey_screen/
│   │       └── hotkey_screen.tscn
│   └── gameplay/           # Main gameplay scene where mission runs
│       └── space_flight.tscn
├── scripts/
│   ├── mission_system/     # Main component scripts
│   │   ├── mission_manager.gd       # Singleton: Manages mission lifecycle, state, objects, events, goals.
│   │   ├── arrival_departure.gd     # Node/Helper: Handles arrival/departure logic and timing.
│   │   ├── spawn_manager.gd         # Node/Helper: Handles instantiating ships/wings.
│   │   ├── mission_loader.gd        # Helper: Loads MissionData resources.
│   │   ├── briefing/                # Briefing system scripts
│   │   │   ├── briefing_screen.gd
│   │   │   ├── briefing_map_manager.gd
│   │   │   └── briefing_icon.gd
│   │   ├── debriefing/              # Debriefing system scripts
│   │   │   ├── debriefing_screen.gd
│   │   │   └── scoring_system.gd    # (Optional) Handles score calculation, medal logic
│   │   ├── log/                     # Mission Log scripts
│   │   │   ├── mission_log_manager.gd # Singleton
│   │   │   └── mission_log_entry.gd   # Resource script
│   │   ├── message_system/          # Message system scripts
│   │   │   ├── message_manager.gd     # Singleton
│   │   │   ├── message_data.gd      # Resource script
│   │   │   └── persona_data.gd      # Resource script
│   │   ├── training_system/         # Training system scripts
│   │   │   └── training_manager.gd    # Singleton or part of MissionManager
│   │   └── hotkey/                  # Mission Hotkey scripts
│   │       └── mission_hotkey_manager.gd # Singleton or part of PlayerData
│   ├── resources/               # Scripts defining custom Resource types
│   │   ├── mission_data.gd
│   │   ├── player_start_data.gd
│   │   ├── ship_instance_data.gd
│   │   ├── wing_instance_data.gd
│   │   ├── waypoint_list_data.gd
│   │   ├── mission_event_data.gd
│   │   ├── mission_objective_data.gd
│   │   ├── reinforcement_data.gd
│   │   ├── briefing_data.gd
│   │   ├── debriefing_data.gd
│   │   ├── sexp_variable_data.gd
│   │   ├── docking_pair_data.gd
│   │   ├── message_data.gd         # Moved from mission_system/message_system
│   │   ├── persona_data.gd         # Moved from mission_system/message_system
│   │   └── mission_log_entry.gd    # Moved from mission_system/log
│   ├── scripting/               # SEXP system scripts (see 08_scripting.md)
│   │   ├── sexp_system.gd
│   │   ├── sexp_node.gd
│   │   ├── sexp_parser.gd
│   │   ├── sexp_evaluator.gd
│   │   ├── sexp_operators.gd
│   │   ├── sexp_variables.gd
│   │   └── sexp_constants.gd
│   ├── campaign/                # Campaign system scripts (see added section)
│   │   ├── campaign_manager.gd
│   │   ├── campaign_parser.gd
│   │   ├── campaign_data.gd
│   │   └── campaign_save_data.gd
│   ├── ui/                      # UI scripts related to mission system
│   │   ├── hud/
│   │   │   └── hud_directives_gauge.gd
│   │   ├── mission_log/
│   │   │   └── mission_log_screen.gd
│   │   └── hotkey_screen/
│   │       └── hotkey_screen.gd
│   └── ...
```

## 4. Relations Summary

*   **MissionManager:** Central orchestrator. Loads `MissionData`. Manages runtime state (time, active ships/wings, objectives, events). Calls `SEXPSystem` for evaluation. Triggers `SpawnManager`, `ArrivalDepartureSystem`, `MessageManager`, `SoundManager`, `HUDManager`. Interacts with `CampaignManager` for progression.
*   **SEXPSystem:** Evaluates formulas from `MissionData` (goals, events, cues, branching). Called by `MissionManager`, `CampaignManager`. Operators within call methods on various managers (Ship, AI, Message, Mission, etc.) to query state or trigger actions.
*   **Briefing/Debriefing/CommandBrief Systems:** Read data from `MissionData`. Display UI. Play voice/animations via `SoundManager`/`AnimationPlayer`. Controlled by `GameSequenceManager`. Debriefing interacts with `ScoringSystem`/`CampaignManager`.
*   **MessageSystem:** Manages message queue, personas, voice/animation playback. Triggered by `MissionManager`, `SEXPSystem`, AI. Interacts with HUD.
*   **TrainingSystem:** Manages training objectives/messages. Interacts with `MissionManager`, `MessageManager`, HUD, `InputMap`.
*   **CampaignSystem:** Loads campaign definitions. Provides mission sequence to `MissionLoader`. Receives results from `MissionManager`. Evaluates branching via `SEXPSystem`. Saves/loads persistent state (`CampaignSaveData`).
*   **MissionLogManager:** Receives events from various systems (`MissionManager`, `ShipManager`) and stores them. Read by `DebriefingScreen` and potentially a dedicated log UI.
*   **HotkeyManager:** Manages hotkey assignments stored in `CampaignSaveData`. Read by `PlayerTargeting`. Defaults set by `MissionManager`.

## 5. Conversion Strategy Notes

*   **FS2 Conversion:** Prioritize creating a robust `.fs2` to Godot Resource (`.tres` or JSON) converter. This simplifies runtime logic significantly.
*   **SEXPs:** The SEXP system is critical and complex. A hybrid approach (parse structure, interpret with GDScript) is likely the most feasible path to maintain compatibility. Define all operators carefully.
*   **Data-Driven:** Use `Resource` files extensively for mission definitions, objectives, events, briefings, etc.
*   **Modularity:** Keep systems like Briefing, Debriefing, Logging, Messages, Training, Campaign, Hotkeys as separate Singletons or scenes/nodes managed by `MissionManager` or `GameSequenceManager`.
*   **Signals:** Use signals for communication between mission events/goals and other systems (HUD updates, sound cues, AI triggers).
*   **State Management:** Clearly define where runtime state is stored (e.g., objective status in `MissionObjectiveData` instance or `MissionManager` dictionary, campaign progress in `CampaignSaveData`).

## 6. Testing Strategy

*   **Parser/Converter:** Test thoroughly with various `.fs2` files, verifying the output JSON/`.tres` structure and data integrity.
*   **SEXPSystem:** Test individual operators and complex nested expressions against known outcomes from the original game or FRED2.
*   **Mission Logic:** Test objective completion/failure triggers, event timing/conditions, arrival/departure cues, reinforcement spawning for multiple missions.
*   **Briefing/Debriefing:** Verify correct stage display, text, voice playback, map icons/lines, camera movement, stats, and awards.
*   **Campaign Flow:** Test mission progression, branching logic based on success/failure/SEXP results, and state persistence (variables, ship/weapon pools, hotkeys).
*   **Training:** Test directive display, message timing/playback, failure conditions.
*   **Log/Hotkeys:** Verify correct event logging and hotkey assignment/recall functionality.
