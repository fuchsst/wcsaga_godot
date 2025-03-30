# Wing Commander Saga: Godot Conversion Analysis - Component 02: Mission Editor (FRED)

This document analyzes the original Wing Commander Saga mission editor (FRED2) C++ codebase and proposes an implementation strategy for a compatible Godot editor plugin (GFRED), following the guidelines in `tasks/00_analysis_setup.md`.

*Source Code Folders:* `fred2/`, `wxfred2/` (wxWidgets UI layer, less relevant for core logic)

## 1. Original System Overview (FRED2)

FRED2 is a comprehensive tool for creating and editing Wing Commander Saga missions (`.fs2` files). It provides a 3D visual interface for placing objects, defining paths, scripting events, setting goals, managing briefings/debriefings, and configuring mission parameters.

```mermaid
graph TD
    FRED2[Mission Editor] --> VM[Visual Mission Editing]
    FRED2 --> SEXP[Scripting System (SEXP)]
    FRED2 --> DOC[Document Management]
    FRED2 --> RENDER[Rendering System]
    FRED2 --> INPUT[Input Handling]
    FRED2 --> DIALOGS[Dialog System]
    FRED2 --> VALID[Validation & Utilities]

    VM --> SPACE[3D Space Editing]
    VM --> WP[Waypoint/Path Management]
    VM --> PLACE[Object Placement/Orientation]
    VM --> WING[Wing Management]
    VM --> GRID[Grid System]
    VM --> ENV[Environment Setup]

    SEXP --> EDITOR[Visual SEXP Editor]
    SEXP --> EVAL[SEXP Evaluation (Runtime)]
    SEXP --> TRIG[Event Triggers/Conditions]
    SEXP --> GOAL[Goal Conditions]
    SEXP --> BRIEF[Briefing/Debriefing Logic]
    SEXP --> VAR[Variable Management]

    DOC --> LOAD[Mission Loading/Parsing (.fs2)]
    DOC --> SAVE[Mission Saving (.fs2)]
    DOC --> AUTOSAVE[Autosave/Backup]
    DOC --> UNDO[Undo/Redo]
    DOC --> CAMPAIGN[Campaign Saving (.fsc)]

    RENDER --> VIEW[Multiple Viewports]
    RENDER --> AIDS[Visual Aids (Grid, Compass, etc.)]
    RENDER --> SELECT[Selection Highlighting]
    RENDER --> OBJR[Object Rendering (Models/Icons)]
    RENDER --> SUBSYS[Subsystem Highlighting]

    INPUT --> SEL[Selection Modes (Point, Box)]
    INPUT --> TRANSFORM[Transformation Controls (Move, Rotate)]
    INPUT --> CAM[Camera Controls]
    INPUT --> MODES[Editing Modes]
    INPUT --> SHORTCUTS[Keyboard Shortcuts]

    DIALOGS --> SHIP[Ship Editor]
    DIALOGS --> WINGEDIT[Wing Editor]
    DIALOGS --> EVENT[Event Editor]
    DIALOGS --> GOALEDIT[Goal Editor]
    DIALOGS --> BRIEFEDIT[Briefing Editor]
    DIALOGS --> DEBRIEFEDIT[Debriefing Editor]
    DIALOGS --> MSG[Message Editor]
    DIALOGS --> VARMAN[Variable Manager]
    DIALOGS --> BG[Background Editor]
    DIALOGS --> AST[Asteroid Editor]
    DIALOGS --> NOTES[Mission Notes]
    DIALOGS --> PLAYER[Player Start/Loadout]
    DIALOGS --> REINFORCE[Reinforcement Editor]
    DIALOGS --> PATHEDIT[Path Editor]
    DIALOGS --> POPUPS[Generic Popups]
    DIALOGS --> HELP[Context Help]

    VALID --> TEST[Mission Testing Hook]
    VALID --> CHECK[Error Checking]
    VALID --> STATS[Statistics Display]
    VALID --> VOICE[Voice Script Generation]
    VALID --> IMPORT[Import Tools]
```

### 1.1. Key Features (Based on FRED2 Analysis)

1.  **Visual Mission Editing (`fredview.cpp`, `fredrender.cpp`)**
    *   **3D Space Editing:** Multiple viewports (perspective, top-down, ortho - though FRED2 primarily uses one 3D view), camera controls (flying, keypad, look-at, zoom extents). (`fredrender.cpp`, `fredview.cpp`)
    *   **Object Placement & Orientation:** Placing ships, waypoints, jump nodes, player starts. Moving and rotating objects with gizmos (implied) and axis constraints. (`fredview.cpp`, `orienteditor.cpp`)
    *   **Waypoint/Path Management:** Creating and editing waypoint paths (`waypointpathdlg.cpp`, `fredview.cpp`). Visualizing paths and waypoints. (`fredrender.cpp`)
    *   **Wing Management:** Forming, disbanding, deleting wings. Assigning ships, setting leader, waves, thresholds, arrival/departure cues, AI goals. (`wing.cpp`, `wing_editor.cpp`)
    *   **Grid System:** Customizable 3D grid with snapping for precise placement. (`grid.cpp`, `adjustgriddlg.cpp`, `fredrender.cpp`)
    *   **Background & Environment Setup:** Configuring starfields, suns, background bitmaps, nebulae (FS1 & FullNeb), asteroid fields. (`bgbitmapdlg.cpp`, `asteroideditordlg.cpp`)
    *   **Selection:** Point selection, box selection, wing selection, list-based selection, selection lock, hide/show objects. (`fredview.cpp`, `ship_select.cpp`)
    *   **Transformation:** Moving/rotating objects individually or as groups, axis constraints, leveling/aligning objects. (`fredview.cpp`)

2.  **Scripting System (SEXP - `sexp_tree.cpp`, `sexp.cpp`, `parselo.cpp`)**
    *   **Visual SEXP Editor:** Tree-based editor (`sexp_tree` class) for creating/modifying SEXP logic. Context menus for adding/replacing operators and data. (`sexp_tree.cpp`)
    *   **SEXP Operators:** Large library of operators for game state checks, actions, logic flow. (`sexp.cpp`)
    *   **SEXP Variables:** Defining and managing mission, campaign, and player persistent variables (`@variable-name`). (`variables.cpp`, `addvariabledlg.cpp`, `modifyvariabledlg.cpp`)
    *   **Validation:** Syntax and argument type checking. (`sexp.cpp`, `sexp_tree.cpp`)
    *   **Application:** Used for event triggers, goal conditions, arrival/departure cues, briefing/debriefing conditions, campaign branching. (`eventeditor.cpp`, `missiongoalsdlg.cpp`, `briefingeditordlg.cpp`, `debriefingeditordlg.cpp`, `campaigneditordlg.cpp`)

3.  **Data Management & I/O (`freddoc.cpp`, `missionsave.cpp`, `missionparse.cpp`)**
    *   **Mission Loading/Saving:** Parsing and writing `.fs2` mission files, handling different sections (`#Mission Info`, `#Objects`, `#Wings`, etc.). (`freddoc.cpp`, `missionsave.cpp`, `missionparse.cpp`)
    *   **Campaign Loading/Saving:** Parsing and writing `.fsc` campaign files. (`missionsave.cpp`, `missioncampaign.cpp`)
    *   **Autosave & Backup:** Periodically saving backups (`autosave_mission_file`). (`freddoc.cpp`)
    *   **Undo/Redo:** File-based undo system (saving state to backup files). (`freddoc.cpp`)
    *   **Format Compatibility:** Handling different FS1/FS2/FSO format variations during saving. (`missionsave.cpp`)

4.  **Dialog System (Various `*dlg.cpp`, `*editor.cpp`)**
    *   Extensive use of modal dialogs for editing properties of ships, wings, goals, events, briefings, environment settings, etc.
    *   Specialized editors for complex tasks like SEXP editing, ship/weapon loadouts, campaign structure.

5.  **Validation & Utility Tools**
    *   **Mission Testing Hook:** Launching the game to test the current mission (`OnRunFreeSpace` in `fredview.cpp`).
    *   **Error Checking:** Built-in validation for mission logic, object references, SEXP syntax (`global_error_check` in `fredview.cpp`, `error_checker` in `CampaignTreeWnd.cpp`).
    *   **Statistics Display:** Showing mission object counts (`OnMiscStatistics` in `fredview.cpp`).
    *   **Voice Script Generation:** Exporting text and filenames for voice actors (`VoiceActingManager` in `voiceactingmanager.cpp`).
    *   **Import Tools:** Importing data from older formats or external files (`OnFileImportFSM`, `OnFileImportWeapons` in `freddoc.cpp`).

## 2. Detailed Code Analysis Guidelines (Refined for GFRED)

1.  **Identify Key Features:**
    *   List primary editor functions (e.g., Object Placement, Wing Management, SEXP Editing, Briefing Setup).
    *   Describe core data structures (`object`, `wing`, `mission_event`, `mission_goal`, `brief_stage`, `sexp_node`).
    *   Mention specific UI paradigms (e.g., Multiple Viewports, Property Dialogs, Tree Controls, 3D Gizmos).
    *   *Guideline:* Focus on *what* the editor allows the user to do and *how* it represents mission data internally. Reference specific C++ files/classes for each feature (e.g., `fredview.cpp` for 3D view, `sexp_tree.cpp` for SEXP editor).
2.  **List Potential Godot Solutions:**
    *   Map each editor feature to specific Godot `EditorPlugin` APIs, `Control` nodes (`Tree`, `GraphEdit`, `ItemList`, `VBoxContainer`, `SubViewportContainer`), 3D nodes (`Camera3D`, `Node3D`, `GridMap`, `EditorNode3DGizmo`), and `Resource` types (`MissionData`, `ShipData`, `SEXPNodeResource`).
    *   Specify how data structures will be represented (e.g., `Ships` array -> `Array[ShipInstanceData]` in `MissionData` resource).
    *   Identify where custom editor tools (`EditorScript`, `EditorNode3DGizmoPlugin`) are needed.
    *   Propose how the `.fs2` format will be handled (direct parsing/saving via GDScript/C#, or conversion to/from an intermediate format like JSON or Godot Resources).
    *   *Guideline:* Explain *why* specific Godot UI nodes or plugin APIs are chosen (e.g., `GraphEdit` for visual SEXP, `EditorNode3DGizmo` for 3D manipulation).
3.  **Outline Target Godot Project Structure (GFRED Plugin):**
    *   Propose a structure within `addons/gfred2/`.
    *   List key GDScript files (`editor_main_panel.gd`, `mission_data_manager.gd`, `sexp_editor.gd`, `viewport_controller.gd`, `object_browser.gd`, `property_editor.gd`).
    *   List key scene files (`editor_main_panel.tscn`, `ship_editor_panel.tscn`, `sexp_node.tscn`).
    *   List custom `Resource` scripts (`mission_data.gd`, `sexp_node_resource.gd`).
    *   *Guideline:* Ensure clear separation between core editor logic, UI panels, data management, and 3D view interaction. Follow naming conventions established in `00_analysis_setup.md`. Ensure all necessary folders (e.g., `scenes`, `scripts`, `resources`, `icons`, `theme`) are present.
4.  **Identify Important Methods, Classes, and Data Structures:**
    *   List critical C++ classes (`CFREDDoc`, `CFred_mission_save`, `CFREDView`, `sexp_tree`, dialog classes like `CShipEditorDlg`, `wing_editor`, `event_editor`, `CMissionGoalsDlg`, `briefing_editor_dlg`).
    *   List critical structs (`object`, `ship`, `wing`, `mission_event`, `mission_goal`, `brief_stage`, `brief_icon`, `ai_goal`, `sexp_node`).
    *   Describe their purpose (e.g., `CFREDDoc` manages mission data loading/saving, `sexp_tree` provides the SEXP editing UI).
    *   Map to proposed Godot equivalents (e.g., `CFREDDoc` -> `MissionDataManager` node + `MissionData` resource, `sexp_tree` -> `GraphEdit` node + `SEXPEditor.gd` script).
    *   *Guideline:* Focus on high-level components and data containers crucial for editor functionality. Include key UI interaction functions (`OnLButtonDown`, `drag_objects`, `create_wing`).
5.  **Identify Relations:**
    *   Describe how GFRED components interact (e.g., `ObjectBrowser` signals `PropertyEditor` on selection change, `ViewportController` uses `MissionDataManager` to get object data).
    *   Explain how GFRED interacts with the core game's data structures (`MissionData`, `ShipData`, `WeaponData` resources).
    *   Mention dependencies on other planned systems (e.g., `SEXPSystem` for validation/evaluation preview, `AssetPipeline` for accessing ship models/icons).
    *   Use Mermaid diagrams if helpful to show UI panel interactions or data flow during load/save.

## 3. Implementation in Godot (GFRED Plugin)

GFRED will be implemented as a Godot `EditorPlugin`.

### 3.1. Godot Project Structure (GFRED Plugin)

```
wcsaga_godot/
├── addons/
│   └── gfred2/
│       ├── plugin.cfg
│       ├── plugin.gd                 # Main plugin script (registers docks, tools)
│       ├── icons/                    # Icons for editor UI (e.g., gfred_icon.png)
│       ├── scenes/                   # UI scenes for editor panels and dialogs
│       │   ├── editor_main_panel.tscn  # Main dockable panel scene
│       │   ├── object_browser.tscn
│       │   ├── property_editor.tscn
│       │   ├── sexp_editor.tscn        # Using GraphEdit or Tree
│       │   ├── event_editor_panel.tscn
│       │   ├── goal_editor_panel.tscn
│       │   ├── briefing_editor.tscn
│       │   ├── debriefing_editor.tscn
│       │   ├── message_editor.tscn
│       │   ├── variable_editor.tscn
│       │   ├── background_editor.tscn
│       │   ├── asteroid_editor.tscn
│       │   ├── mission_notes.tscn
│       │   ├── ship_loadout_editor.tscn
│       │   ├── wing_editor_panel.tscn
│       │   ├── path_editor_panel.tscn
│       │   ├── campaign_editor.tscn
│       │   ├── popup_dialog.tscn       # Base for generic popups
│       │   └── help_overlay.tscn       # Context help display
│       ├── scripts/
│       │   ├── core/                   # Core editor logic
│       │   │   ├── editor_main_panel.gd
│       │   │   ├── mission_data_manager.gd # Handles loading, saving, UndoRedo, data state
│       │   │   ├── selection_manager.gd
│       │   │   ├── input_manager.gd      # Handles input within editor viewports
│       │   │   └── tool_manager.gd       # Manages selection, placement, rotation tools
│       │   ├── ui/                     # Scripts for UI panels/dialogs
│       │   │   ├── object_browser.gd
│       │   │   ├── property_editor_base.gd
│       │   │   ├── ship_properties.gd
│       │   │   ├── wing_properties.gd
│       │   │   ├── sexp_editor.gd
│       │   │   ├── event_editor_panel.gd
│       │   │   ├── goal_editor_panel.gd
│       │   │   ├── briefing_editor.gd
│       │   │   ├── popup_dialog.gd
│       │   │   └── help_manager.gd       # Manages context help display
│       │   │   └── ... (scripts for other panels)
│       │   ├── viewport/               # 3D viewport related scripts
│       │   │   ├── editor_camera.gd      # Camera controls (ortho, perspective, flying)
│       │   │   ├── grid_manager.gd       # Grid rendering and snapping logic
│       │   │   └── object_gizmo_plugin.gd # Plugin for custom 3D gizmos
│       │   ├── data/                   # Scripts defining editor-specific data structures
│       │   │   └── sexp_node_ui.gd     # UI representation of an SEXP node
│       │   └── io/                     # File I/O, parsing, saving
│       │       ├── fs2_parser.gd         # Logic to parse .fs2 files
│       │       ├── fs2_saver.gd          # Logic to save .fs2 files
│       │       └── campaign_io.gd        # Logic for .fsc files
│       ├── resources/                # Editor-specific resources
│       │   ├── gizmos/                 # Gizmo meshes/materials
│       │   └── help_data.tres        # Parsed help data from help.tbl
│       └── theme/                    # Editor theme overrides
│           └── gfred_theme.tres
└── resources/                      # Game resources used by the editor
    ├── missions/
    │   ├── mission_data.gd         # Resource definition for mission data
    │   ├── mission_objective.gd
    │   ├── wave_data.gd
    │   ├── ship_instance_data.gd   # Renamed from ship_mission_data.gd
    │   └── wing_instance_data.gd   # Resource for wing instance data
    ├── ships/
    │   └── ship_data.gd            # Base ship definition resource
    ├── weapons/
    │   └── weapon_data.gd          # Base weapon definition resource
    └── scripting/
        └── sexp_node_resource.gd   # Resource definition for SEXP nodes (if used)
```
*(Refined structure based on `00_analysis_setup.md` and editor needs, added missing folders and renamed `ship_mission_data.gd`)*

### 3.2. Key Classes and Resources

*   **`GFREDPlugin` (`plugin.gd`):** Extends `EditorPlugin`. Registers custom types, docks, tools, and handles plugin lifecycle (`_enter_tree`, `_exit_tree`).
*   **`EditorMainPanel` (`editor_main_panel.gd`):** Extends `Control`. The main UI panel, likely managing docking of sub-panels using `DockContainer` or similar.
*   **`MissionDataManager` (`mission_data_manager.gd`):** Extends `Node`. Handles loading/parsing `.fs2` files into `MissionData` resources, saving back to `.fs2`, managing the `UndoRedo` history for editor actions, tracking modified state, and handling autosave/backups. Corresponds to `CFREDDoc` and `CFred_mission_save`.
*   **`MissionData` (`resources/missions/mission_data.gd`):** Extends `Resource`. Holds the entire state of a mission (info, player starts, ship instances, wings, events, goals, variables, etc.). This is the central data object the editor manipulates.
*   **`ShipInstanceData` (`resources/missions/ship_instance_data.gd`):** Extends `Resource`. Holds data specific to a ship *instance* within a mission (position, orientation, initial status, AI goals, cargo, specific loadout overrides, arrival/departure cues, etc.). Referenced by `MissionData`.
*   **`WingInstanceData` (`resources/missions/wing_instance_data.gd`):** Extends `Resource`. Holds data for a wing instance (name, ship references, wave settings, arrival/departure cues, wing AI goals). Referenced by `MissionData`.
*   **`ViewportContainer` (`viewport_container.gd`):** Extends `SubViewportContainer`. Manages the 3D editing `SubViewport`.
*   **`EditorCamera` (`viewport/editor_camera.gd`):** Extends `Camera3D`. Implements camera controls (perspective, ortho views, flying controls similar to `process_controls`).
*   **`GridManager` (`viewport/grid_manager.gd`):** Extends `Node3D`. Renders the 3D grid (`GridMap` or custom drawing using `ImmediateMesh`) and handles snapping logic. Corresponds to `grid.cpp`.
*   **`InputManager` (`core/input_manager.gd`):** Extends `Node`. Attached to the `SubViewport`. Handles mouse/keyboard input within the 3D view, translating it into actions (selection, dragging, camera movement). Corresponds to `fredview.cpp` input handling.
*   **`ToolManager` (`core/tool_manager.gd`):** Extends `Node`. Manages the current editing mode (Select, Move, Rotate) and activates the corresponding tool/gizmo.
*   **`SelectionManager` (`core/selection_manager.gd`):** Extends `Node`. Tracks selected objects (`Node3D` placeholders representing objects in the editor scene) and provides selection methods (single, box, add/remove). Corresponds to marking logic in `fredview.cpp`.
*   **`ObjectGizmoPlugin` (`viewport/object_gizmo_plugin.gd`):** Extends `EditorNode3DGizmoPlugin`. Provides custom 3D gizmos for moving and rotating selected objects, potentially with axis constraints.
*   **`ObjectBrowser` (`ui/object_browser.gd`):** Extends `ItemList` or `Tree`. Displays a list of mission objects (ships, wings, waypoints). Allows selection which signals the `SelectionManager` and `PropertyEditor`.
*   **`PropertyEditor` (`ui/property_editor_base.gd` + specific scripts):** Extends `VBoxContainer`. Displays and allows editing properties of the selected object(s). Uses specific editor controls based on property type. Corresponds to various dialogs (`CShipEditorDlg`, `wing_editor`, etc.).
*   **`SEXPEditor` (`ui/sexp_editor.gd`):** Extends `GraphEdit` or `Tree`. Provides a visual interface for creating and editing SEXP trees. Corresponds to `sexp_tree.cpp`. Needs `SEXPNodeUI` (`data/sexp_node_ui.gd`) for node representation.
*   **`FS2Parser` / `FS2Saver` (`io/fs2_parser.gd`, `io/fs2_saver.gd`):** Scripts containing static methods or classes to handle the specific logic of reading and writing the `.fs2` file format, interacting with the `MissionData` resource. Corresponds to `missionparse.cpp` and `missionsave.cpp`.

### 3.3. Core Functionality Mapping

*   **Visual Editing:** Use Godot's 3D viewport, `EditorNode3DGizmoPlugin` for object manipulation, `GridMap` or custom grid drawing, `Path3D` for waypoints.
*   **Object Placement:** Raycasting from mouse position onto the grid plane (`PhysicsDirectSpaceState3D.intersect_ray`). Instantiate object placeholder scenes (`Marker3D` with scripts/metadata).
*   **Wing Management:** UI panel (`wing_editor_panel.tscn`) to list wings and ships. Logic in `MissionDataManager` to create/delete/modify `WingInstanceData` resources and update associated `ShipInstanceData` (wingnum, name).
*   **SEXP Editing:** Use `GraphEdit` for a node-based visual editor or `Tree` for a direct tree representation. `SEXPEditor.gd` handles node creation, linking, validation based on operator definitions (loaded from a resource).
*   **Dialogs:** Recreate FRED2 dialogs as separate scenes (`.tscn`) or panels within the main editor dock. Use standard Godot `Control` nodes.
*   **Document Management:** `MissionDataManager` handles loading (`FS2Parser`), saving (`FS2Saver`), `UndoRedo` actions, modified status, and autosave (`Timer`).
*   **Rendering:** Leverage Godot's renderer. Use `EditorPlugin._forward_3d_draw_over_viewport` for drawing helpers (grid lines, selection outlines, distance measures). Use `SubViewport` for the main 3D editing view.
*   **Input:** `InputManager` script on the `SubViewport` captures mouse/keyboard events, interacts with `ToolManager`, `SelectionManager`, and `EditorCamera`.

### 3.4. SEXP System Implementation

*   **Representation:** Use nested Godot `Array`s or a custom `SEXPNodeResource` (`resources/scripting/sexp_node_resource.gd`) to store the SEXP tree structure within `MissionData`.
*   **Editor UI:** `SEXPEditor.gd` (using `GraphEdit` or `Tree`) allows visual manipulation of this structure. Context menus provide valid operator/data choices based on parent operator rules (loaded from `Operators` resource).
*   **Validation:** Implement SEXP validation logic (`check_sexp_syntax` equivalent) within `SEXPEditor.gd` or a helper script, checking argument counts and types against operator definitions.
*   **Runtime Evaluation:** The separate `SEXPSystem` (see `08_scripting.md`) will handle the actual evaluation during gameplay. The editor might include a basic preview/validation evaluator.

## 4. Relations

*   **GFRED Plugin** interacts with the Godot **Editor Interface** to add docks, menus, and tools.
*   **MissionDataManager** loads/saves mission data using **FS2Parser/Saver** and manages **UndoRedo**. It holds the master `MissionData` resource.
*   **UI Panels** (ObjectBrowser, PropertyEditor, SEXPEditor, etc.) read from and write to the `MissionData` resource via the **MissionDataManager** (often indirectly via signals or selection changes).
*   **ViewportController/InputManager** handles 3D view interactions, signaling **SelectionManager** and **ToolManager**.
*   **ToolManager** activates **Gizmos** (via `EditorNode3DGizmoPlugin`) which modify the `global_transform` of selected placeholder nodes.
*   Changes made via Gizmos or PropertyEditor trigger actions in **MissionDataManager** to update the `MissionData` resource and register `UndoRedo` steps.
*   **SEXPEditor** interacts with operator definitions (likely a global resource/singleton) for validation and context menus.
*   GFRED relies on game **Resources** (`ShipData`, `WeaponData`, etc.) loaded via Godot's standard resource loading for populating choices in property editors.

## 5. Conversion Strategy Notes

*   **File Format:** Decide whether to work directly with `.fs2` (requiring robust GDScript/C# parsers/savers) or convert `.fs2` to an intermediate format like JSON or `.tres` first. Direct `.fs2` handling maintains maximum compatibility but is more complex to implement. Conversion adds an extra step but allows leveraging Godot's native serialization. Given the complexity of `.fs2`, a dedicated parser/saver seems necessary either way. **Decision:** Implement direct `.fs2` parsing and saving within the plugin for maximum compatibility.
*   **UI Framework:** Rebuild the UI using Godot's `Control` nodes. Avoid direct porting of MFC/wxWidgets code. Focus on replicating functionality and workflow.
*   **SEXP Editor:** This is a critical and complex part. `GraphEdit` offers flexibility for a node-based approach, while `Tree` is simpler for direct tree editing. Validation and context-sensitive menus are key.
*   **3D View:** Utilize `SubViewport` and standard Godot 3D rendering. Implement editor-specific drawing using overlays or `EditorPlugin` drawing hooks.
*   **Undo/Redo:** Leverage Godot's built-in `UndoRedo` system instead of FRED2's file-based backup system.

## 6. Testing Plan

*   **Unit Tests:** Test `FS2Parser/Saver` logic, SEXP validation functions, individual UI panel logic.
*   **Integration Tests:** Load existing `.fs2` missions, modify various elements (ships, goals, events), save, and verify the output `.fs2` file integrity and correctness. Test Undo/Redo extensively.
*   **Compatibility Tests:** Ensure saved missions load correctly in the target WCSa game build (once available). Test with missions using various FRED2 features.
*   **Usability Tests:** Evaluate the editor workflow, ease of use, and performance compared to FRED2.

## 7. Next Steps

1.  Finalize the decision on `.fs2` handling (direct I/O vs. conversion). **Decision:** Direct I/O.
2.  Implement the core `EditorPlugin` structure and `MissionDataManager`.
3.  Develop the `FS2Parser` and `FS2Saver`.
4.  Prototype the 3D viewport with basic object placement and selection using placeholder `Marker3D`s.
5.  Prototype the SEXP editor UI (`GraphEdit` or `Tree`).
6.  Implement key property editor panels (Ship, Wing).
7.  Integrate Godot's `UndoRedo` system.
