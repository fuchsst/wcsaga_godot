# Wing Commander Saga: Godot Conversion Analysis - Component 06: HUD System

This document analyzes the Heads-Up Display (HUD) system from the original Wing Commander Saga C++ codebase and proposes an implementation strategy for the Godot conversion project, following the guidelines in `tasks/00_analysis_setup.md`.

*Source Code Folders:* `hud/`, `radar/`

## 1. Original System Overview

The original HUD system renders all the 2D and some 3D elements overlaid on the main game view during flight. It's a complex system responsible for displaying critical flight information, target data, communication, warnings, and mission status. It relies heavily on configuration files (`hud_gauges.tbl`) for layout and appearance, allowing for customization based on ship type and screen resolution.

Key sub-components include:

1.  **HUD Configuration & Parsing:** Loading layouts, coordinates, graphics, and settings from `hud_gauges.tbl` and modular `*-hdg.tbm` files. Handles resolution differences and ship-specific overrides. (`hudparse.cpp`, `hudconfig.cpp`)
2.  **Core HUD Rendering:** Main loop (`HUD_render_2d`, `HUD_render_3d`), managing gauge visibility, popups, flashing, color themes, contrast, and global offsets (e.g., for camera shake). (`hud.cpp`)
3.  **Reticle System:** Central aiming reticle, arcs, throttle/speed display, weapon selection indicators, glide/autopilot icons, and integrated threat warnings (lock, launch). (`hudreticle.cpp`)
4.  **Shield Display:** Player and target shield strength visualization (quadrants), custom ship icons, hit flashing effects, mini-display for target. (`hudshield.cpp`)
5.  **Target Information Display (Target Box):** Detailed target info (name, class, distance, speed, hull, shields, status), 3D model rendering (including wireframe), subsystem targeting display, cargo scanning info, ship orders/time-to-goal. (`hudtargetbox.cpp`)
6.  **Targeting Gauges:** Lead indicators, offscreen indicators (triangles with distance), target brackets (dynamic sizing), missile lock indicators, homing warnings. (`hudtarget.cpp`, `hudbrackets.cpp`, `hudlock.cpp`)
7.  **Energy Management Display (ETS):** Visual representation of energy distribution between engines, shields, and weapons. (`hudets.cpp`)
8.  **Wingman Status Display:** Shows hull integrity and status (alive, dead, departed) for player wingmen, organized by wing. (`hudwingmanstatus.cpp`)
9.  **Squad Message System:** Hierarchical menu for issuing commands to AI ships/wings, including reinforcement requests and order history. (`hudsquadmsg.cpp`)
10. **Escort List:** Displays ships currently marked for escort priority. (`hudescort.cpp`)
11. **Damage Display:** Popup showing detailed player ship hull and subsystem damage status. (`hud.cpp` - `hud_show_damage_popup`)
12. **Message Display:** Renders incoming/outgoing text messages and potentially talking heads. (`hudmessage.cpp`, `hud.cpp`)
13. **Objective Display:** Shows current mission objectives and status updates. (`hud.cpp` - `hud_maybe_display_objective_message`)
14. **Radar System:** Displays nearby objects (ships, weapons, jump nodes) in either a 2D top-down or 3D orb view, with IFF color coding, range settings, and sensor distortion effects. (`radar.cpp`, `radarorb.cpp`, `radarsetup.cpp`)
15. **Navigation Display:** Shows information related to the currently selected autopilot nav point. (`hudnavigation.cpp`)
16. **Observer HUD:** Specialized HUD elements for multiplayer observers. (`hudobserver.cpp`)
17. **Artillery Support:** HUD elements related to calling in artillery strikes (likely specific to certain missions/ships). (`hudartillery.cpp`)

## 2. Detailed Code Analysis (Per Sub-Component)

### A. HUD Parsing & Configuration (`hudparse.cpp`, `hudparse.h`, `hudconfig.cpp`, `hudconfig.h`)

1.  **Key Features:**
    *   **Table Parsing:** Loads `hud_gauges.tbl` and modular `*-hdg.tbm` files using functions from `parselo.cpp`. Handles comments, required/optional strings, lists, numbers, etc. (`parse_hud_gauges_tbl`, `parse_modular_table`).
    *   **Data Structures:**
        *   `hud_info`: Holds all config data for a specific layout (coordinates, filenames, flags, resolution, custom gauge data). Key members: `Player_shield_coords`, `Target_shield_coords`, `Aburn_coords`, `Wenergy_coords`, `Escort_coords`, `custom_gauge_*` arrays. Stores parsed filenames for gauge graphics (e.g., `Aburn_fname`, `Wenergy_fname`, `Shield_mini_fname`, `Escort_filename[]`).
        *   `gauge_info`: Defines properties for each gauge type (parent ref, coordinate offsets, defaults, image/text/color/moveflag/alignment destinations, placement flags `HG_NOADD`, show flags). Key members: `parent`, `coord_dest`, `fieldname`, `defaultx_640`, `defaulty_480`, `defaultx_1024`, `defaulty_768`, `image_dest`, `text_dest`, `color_dest`, `color_parent_dest`, `moveflag_dest`, `alignment_dest`.
        *   `HUD_CONFIG_TYPE`: Stores user-configurable settings (gauge visibility `show_flags`/`show_flags2`, popup behavior `popup_flags`/`popup_flags2`, radar range `rp_dist`, radar flags `rp_flags`, main color `main_color`, individual gauge colors `clr[]`). Loaded/saved via `hud_config_load`/`hud_config_save`.
    *   **Resolution Handling:** Parses specific sections (`$Resolution:`, `$Default:`) for 640x480 and 1024x768 defaults (`parse_resolution_start`). Stores resolution in `hud_info.resolution`. Initializes defaults via `load_hud_defaults`.
    *   **Ship Overrides:** Parses `$Ship:` sections (`parse_ship_start`) to load ship-specific layouts into `ship_huds[]` array, indexed by ship class index.
    *   **Custom Gauges:** Parses `$Name:` blocks in `#Custom Gauges` section (`parse_custom_gauge`) to define new gauge types, storing their properties in the `gauges[]` array and `hud_info` custom arrays.
    *   **Gauge Calculation:** `calculate_gauges()` adjusts positions based on parent gauges and reticle style (`Hud_reticle_style`). `stuff_coords()` parses individual gauge properties (coords, size, percentage, image, text, color, inheritance, movement, alignment).
    *   **Global Settings:** Parses and sets global variables like `Hud_unit_multiplier`, `Hud_lead_alternate`, `Targetbox_wire`, `Lock_targetbox_mode`, `Highlight_tagged_ships`.
    *   **HUD Config Screen:** (`hudconfig.cpp`) Provides UI for modifying `HUD_CONFIG_TYPE` settings (colors, visibility, popups). Uses `UI_WINDOW`, `UI_BUTTON`, `UI_SLIDER2`. Saves/loads `.hcf` files (`hud_config_color_save`, `hud_config_color_load`). Manages color presets (`HC_colors`, `hud_config_set_color`).

2.  **Potential Godot Solutions:**
    *   **Parsing:** Convert `.tbl` files to `.tres` (Godot Resource format) or JSON during asset conversion. A `HUDManager` singleton loads these resources.
    *   **Data Representation:**
        *   `HUDConfigData` resource (`scripts/hud/resources/hud_config_data.gd`): Stores parsed layout data (gauge positions, filenames, flags) equivalent to `hud_info`. Separate resources for default 640, default 1024, and each ship override.
        *   `HUDGaugeConfig` resource (`scripts/hud/resources/hud_gauge_config.gd`): Base resource for gauge definitions (parent ref, offsets, image path, text key, color ref, flags). Derived resources for specific gauge types if needed.
        *   `HUDUserSettings` resource (`scripts/hud/resources/hud_user_settings.gd`): Stores user preferences equivalent to `HUD_CONFIG_TYPE` (visibility flags, popup flags, radar settings, colors). Saved/loaded to `user://` using `ResourceSaver`/`ResourceLoader`.
    *   **Layout:** Use Godot's `Control` nodes within a main HUD scene (`hud.tscn`). A `HUDManager` script applies layout data from the loaded `HUDConfigData` and `HUDUserSettings` resources. Percentage positioning and parent inheritance implemented via script logic during layout application.
    *   **Resolution:** Use Godot's stretch modes or handle scaling within the `HUDManager` based on viewport size.
    *   **Global Settings:** Store in `HUDUserSettings` resource or a dedicated `GameSettings` singleton (`scripts/globals/game_settings.gd`).
    *   **Config Screen:** Create a dedicated scene (`scenes/ui/hud_config_screen.tscn`) using Godot UI nodes (`ColorPickerButton`, `CheckBox`, `OptionButton`, `Slider`) to modify the `HUDUserSettings` resource.

3.  **Target Code Structure:**
    ```
    scripts/hud/
    ├── hud_manager.gd         # Singleton: Loads configs, applies settings, manages gauges
    ├── resources/             # Scripts defining custom Resource types
    │   ├── hud_config_data.gd   # Resource: Parsed layout data (hud_info equivalent)
    │   ├── hud_gauge_config.gd  # Resource: Base gauge definition (gauge_info equivalent)
    │   └── hud_user_settings.gd # Resource: User preferences (HUD_CONFIG_TYPE equivalent)
    └── parsing/               # (Optional) Scripts for runtime parsing if not pre-converted
        └── hud_table_parser.gd
    resources/hud/
    ├── configurations/        # HUDConfigData resources (.tres)
    │   ├── default_640.tres
    │   ├── default_1024.tres
    │   └── ship_specific/
    │       └── hercules.tres
    ├── gauge_definitions/     # HUDGaugeConfig resources (.tres) for each gauge type
    │   ├── player_shield.tres
    │   └── ...
    └── user_settings.tres     # (In user://) Saved HUDUserSettings
    scenes/ui/
    └── hud_config_screen.tscn # Scene for the HUD configuration menu
    scripts/ui/
    └── hud_config_screen.gd   # Logic for the HUD configuration menu
    ```
    *(Added `resources` subfolder to `scripts/hud/` as per project structure)*

4.  **Important Methods, Classes, Data Structures:**
    *   `struct hud_info`: -> `HUDConfigData` resource (`scripts/hud/resources/hud_config_data.gd`).
    *   `struct gauge_info`: -> `HUDGaugeConfig` resource (`scripts/hud/resources/hud_gauge_config.gd`).
    *   `struct HUD_CONFIG_TYPE`: -> `HUDUserSettings` resource (`scripts/hud/resources/hud_user_settings.gd`).
    *   `gauges[]`: -> Dictionary or Array of `HUDGaugeConfig` resources managed by `HUDManager`.
    *   `default_hud`, `ship_huds[]`: -> `HUDConfigData` resources loaded by `HUDManager`.
    *   `current_hud`: -> Reference to the active `HUDConfigData` in `HUDManager`.
    *   `parse_hud_gauges_tbl()`: -> Asset conversion script or runtime parser in `HUDManager`.
    *   `set_current_hud()`: -> `HUDManager.apply_config(ship_class_name)`.
    *   `hud_config_load()` / `hud_config_save()`: -> `ResourceLoader.load()` / `ResourceSaver.save()` for `HUDUserSettings`.
    *   Global vars (`Hud_unit_multiplier`, etc.): -> Properties in `HUDUserSettings` or `GameSettings` singleton (`scripts/globals/game_settings.gd`).
    *   `hud_positions_init()`: -> `HUDManager._ready()` or initialization function.
    *   `hud_get_gauge_index()`: -> Helper method in `HUDManager`.
    *   `hud_config_init()`, `hud_config_do_frame()`, `hud_config_close()`: -> Logic within `hud_config_screen.gd`.

5.  **Relations:**
    *   `HUDManager` loads `HUDConfigData` and `HUDUserSettings`.
    *   `HUDManager` instantiates and positions individual gauge scenes/nodes based on loaded configurations.
    *   Individual gauge scripts read their specific configuration (position, graphics) from data passed by `HUDManager` or directly from loaded resources.
    *   `HUDConfigScreen` modifies the `HUDUserSettings` resource.
    *   Relies on `ShipManager` (or equivalent) for `ship_info_lookup`.
    *   Uses table parsing utilities (potentially ported from `parselo.cpp` or replaced with Godot `ConfigFile`/`JSON`).

### B. Reticle System (`hudreticle.cpp`, `hudreticle.h`)

1.  **Key Features:**
    *   Renders the central reticle and associated arcs (top, left, right).
    *   Displays throttle level graphically, including afterburner indication.
    *   Shows current speed numerically next to the throttle bar.
    *   Indicates weapon selection (primary/secondary banks, linking status).
    *   Provides threat warnings (dumbfire laser/weapon hits, missile lock attempts, full missile lock).
    *   Supports different reticle styles (FS1 vs FS2) with distinct graphics and layouts defined in `Reticle_frame_names` and `Reticle_frame_coords`.
    *   Handles HUD offsets (`HUD_nose_x`, `HUD_nose_y`) for camera shake effects.
    *   Displays glide indicator and auto-speed match icon near speed display.

2.  **Potential Godot Solutions:**
    *   Use `TextureRect` or custom `_draw()` calls within `Control` nodes for rendering reticle components (arcs, center).
    *   Employ `TextureProgress` or custom drawing for the throttle bar.
    *   Use `Label` nodes for displaying speed and weapon names/status.
    *   Implement threat warnings using animated sprites (`AnimatedSprite2D` within `Control`) or custom drawing with timers for flashing.
    *   Manage different reticle styles by swapping themes, scenes, or using conditional logic within scripts based on `Hud_reticle_style`.
    *   Apply HUD offsets directly to the root HUD `CanvasLayer` or individual gauge controls.
3.  **Target Code Structure:**
    ```
    scenes/hud/gauges/
    ├── reticle_gauge.tscn       # Main scene for the reticle group
    ├── throttle_gauge.tscn    # Separate scene for throttle bar/speed
    └── threat_gauge.tscn      # Scene for threat warning elements
    scripts/hud/gauges/
    ├── hud_reticle_gauge.gd     # Manages reticle center, arcs, weapon indicators
    ├── hud_throttle_gauge.gd    # Manages throttle bar, speed display, glide/auto icons
    └── hud_threat_gauge.gd      # Manages lock/dumbfire threat warnings
    resources/hud/textures/reticle/ # Reticle graphics (organized by style)
    ├── fs1/
    │   ├── reticle_center_fs1.png
    │   ├── reticle_arc_top_fs1.png
    │   └── ...
    └── fs2/
        ├── reticle_center_fs2.png
        ├── reticle_arc_top_fs2.png
        └── ...
    resources/hud/spriteframes/
    └── threat_warnings.tres     # SpriteFrames for flashing warnings
    ```

4.  **Important Methods, Classes, Data Structures:**
    *   `Reticle_gauges[]`: Array of `hud_frames` storing animation data for reticle components (arcs, warnings, weapon indicators, center). Indexed by constants like `RETICLE_TOP_ARC`, `RETICLE_LASER_WARN`, `RETICLE_LOCK_WARN`, `RETICLE_LEFT_ARC`, `RETICLE_RIGHT_ARC`, `RETICLE_ONE_PRIMARY`, `RETICLE_TWO_PRIMARY`, `RETICLE_ONE_SECONDARY`, `RETICLE_TWO_SECONDARY`, `RETICLE_THREE_SECONDARY`, `RETICLE_CENTER`. Godot: Use `SpriteFrames` resource or individual `TextureRect` nodes.
    *   `Reticle_frame_names[][][]`: Defines filenames for reticle graphics based on style (`Hud_reticle_style`) and resolution (`gr_screen.res`).
    *   `Reticle_frame_coords[][][]`: Defines coordinates for reticle graphics based on style and resolution.
    *   `Hud_throttle_frame_w[]`, `Hud_throttle_h[]`, `Hud_throttle_bottom_y[][]`, `Hud_throttle_aburn_h[]`, `Hud_throttle_aburn_button[]`: Constants defining throttle gauge dimensions and positions.
    *   `Outer_circle_radius[]`, `Hud_reticle_center[][]`: Constants defining the main reticle circle dimensions.
    *   `Reticle_launch_coords[][]`: Coordinates for the "Launch" warning text.
    *   `Threat_dumbfire_timer`, `Threat_lock_timer`: Timestamps (`timer.h`) controlling flash rate.
    *   `Threat_dumbfire_frame`, `Threat_lock_frame`: Current frame index (0, 1, or 2) for flashing animations.
    *   `THREAT_DUMBFIRE`, `THREAT_ATTEMPT_LOCK`, `THREAT_LOCK`: Flags used in `Player->threat_flags`.
    *   `Max_speed_coords[][]`, `Zero_speed_coords[][]`: Coordinates for max/zero speed text labels.
    *   `hud_init_reticle()`: Loads reticle animations (`bm_load_animation`), initializes threat timers and player threat flags. Godot: `_ready()` function in `hud_reticle_gauge.gd`.
    *   `hud_update_reticle(player* pp)`: Updates threat warning status based on player state (`pp->threat_flags`). Godot: Part of the main HUD update loop or a dedicated threat update function.
    *   `hud_show_throttle()`: Renders the throttle gauge, speed display, and afterburner status. Calls helper functions `hud_render_throttle_background`, `hud_render_throttle_speed`, `hud_render_throttle_line`, `hud_render_throttle_foreground`. Godot: Method in `hud_throttle_gauge.gd`.
    *   `hud_show_reticle_weapons()`: Renders weapon selection indicators based on `Player_ship->weapons` state. Godot: Method in `hud_reticle_gauge.gd` or `hud_weapons_gauge.gd`.
    *   `hud_show_lock_threat()`, `hud_show_dumbfire_threat()`: Render specific threat warnings based on `Player->threat_flags` and timers. Godot: Methods in `hud_threat_gauge.gd`.
    *   `hud_show_center_reticle()`, `hud_show_top_arc()`, `hud_show_right_arc()`, `hud_show_left_arc()`: Render individual parts of the reticle. Godot: Likely handled within `hud_reticle_gauge.gd`'s `_draw()` or via child nodes.
    *   `hudreticle_page_in()`: Preloads reticle graphics (`bm_page_in_aabitmap`).

5.  **Relations:**
    *   Reads coordinates and filenames based on `Hud_reticle_style` and `gr_screen.res` from `Reticle_frame_names` and `Reticle_frame_coords`.
    *   Depends on `Player` state (`Player->threat_flags`, `Player->ci.forward`, `Player_obj->phys_info`, `Player_ship->weapons`, `Player->flags`).
    *   Interacts with `hudtargetbox.cpp` (`hud_targetbox_flash_expired`, `hud_show_text_flash_icon`) for coordinating flashing effects (missile launch warning).
    *   Plays sounds (`SND_THREAT_FLASH`) via `gamesnd.cpp`.
    *   Uses `hud.cpp` functions (`hud_set_gauge_color`, `hud_aabitmap`, `hud_aabitmap_ex`, `hud_num_make_mono`, `HUD_nose_x`, `HUD_nose_y`, `hud_gauge_active`).
    *   Uses `hudparse.h` for `Hud_reticle_style`.
    *   Uses `timer.h` (`timestamp`, `timestamp_elapsed`).
    *   Uses `emp.h` (`emp_active_local`) - although not directly used in the provided snippet, threat warnings might be affected.
    *   Uses `localize.h` for localized strings (`XSTR`, `Lcl_special_chars`, `Lcl_gr`).
    *   Uses `multi.h` for multiplayer checks (`MULTIPLAYER_CLIENT`, `MULTI_OBSERVER`, `Net_players`, `MY_NET_PLAYER_NUM`).
    *   Uses `graphics/2d.h` (`gr_screen.res`, `gr_printf`, `gr_string`, `gr_get_string_size`).
    *   Uses `bmpman/bmpman.h` (`bm_load_animation`, `bm_get_info`, `bm_page_in_aabitmap`).

### C. Shield System (`hudshield.cpp`, `hudshield.h`)

1.  **Key Features:**
    *   Displays player and target shield strength using quadrant-based icons.
    *   Supports custom shield icons per ship type (`Hud_shield_filenames`, `Shield_gauges`).
    *   Generates generic shield icons for ships without custom ones using 3D rendering (`model_render`) if `SIF2_GENERATE_HUD_ICON` flag is set.
    *   Shows shield hit effects (flashing) per quadrant (`Shield_hit_data`, `hud_shield_maybe_flash`).
    *   Displays a mini-shield icon for the target (`Shield_mini_gauge`, `hud_shield_show_mini`).
    *   Includes logic for shield equalization (`hud_shield_equalize`) and quadrant augmentation (`hud_augment_shield_quadrant`).
    *   Handles shield hit registration and timer updates (`hud_shield_quadrant_hit`, `hud_shield_hit_update`).
    *   Uses `Quadrant_xlate` array to map shield sections.

2.  **Potential Godot Solutions:**
    *   Use `TextureRect` nodes for displaying shield icons (both custom and potentially pre-rendered generic ones).
    *   Implement quadrant strength display using custom drawing (`_draw()`) within a `Control` node, coloring segments based on strength.
    *   Use shaders or `Tween` animations for flashing effects on hit.
    *   The mini-shield can be a separate, smaller instance of the shield gauge scene.
    *   Shield management logic (equalize, augment) belongs in the `ShipBase` or a dedicated `ShieldComponent` script, not directly in the HUD script. The HUD script reads data from the ship.
    *   Hit registration and timers should also be managed by the `ShipBase`/`ShieldComponent`.
    *   Generic icon generation could be done offline during asset conversion or potentially using a `SubViewport` in Godot if dynamic generation is needed.

3.  **Target Code Structure:**
    ```
    scenes/hud/gauges/
    ├── shield_gauge.tscn        # Scene for the main shield display
    └── shield_mini_gauge.tscn   # Scene for the mini shield display (part of target box)
    scripts/hud/gauges/
    └── hud_shield_gauge.gd      # Controls drawing, reads data from ship's shield component
    scripts/ship_weapon_systems/components/ # Shield logic moved here
    └── shield_component.gd      # Manages shield state, equalization, hits
    resources/hud/textures/shields/ # Shield icon assets
    ├── player_shield_base.png
    ├── target_shield_base.png
    └── ship_specific/
        └── hercules_shield.png
    ```

4.  **Important Methods, Classes, Data Structures:**
    *   `Shield_gauges[]`: -> Dictionary mapping ship type to `Texture2D` resources managed by `HUDManager` or `AssetManager`.
    *   `Shield_hit_data[]`: -> State managed within `ShieldComponent.gd`.
    *   `hud_shield_show()`: -> Update/drawing logic in `hud_shield_gauge.gd`.
    *   `hud_shield_show_mini()`: -> Update/drawing logic in a separate `hud_shield_mini_gauge.gd` or integrated into `hud_target_monitor.gd`.
    *   `hud_shield_quadrant_hit()`: -> Method in `ShieldComponent.gd`, emits signal to HUD.
    *   `hud_shield_equalize()`, `hud_augment_shield_quadrant()`: -> Methods in `ShieldComponent.gd`.

5.  **Relations:** Reads shield state (quadrant strength, hit status) from the relevant ship's `ShieldComponent` (Player or Target). Reads `HUDConfigData` for coordinates. Reads `ShipData` for custom icon references. Interacts with `HUDManager` for flashing coordination (if needed).

### D. Squad Message System (`hudsquadmsg.cpp`, `hudsquadmsg.h`)

1.  **Key Features:** (As described previously) Hierarchical command menu, target selection (ship/wing/all), command validation (`hud_squadmsg_is_target_order_valid`, `hud_squadmsg_ship_order_valid`), history (`Squadmsg_history`), reinforcement requests (`hud_squadmsg_reinforcements_available`, `hud_squadmsg_call_reinforcement`), multiplayer sync (`send_player_order_packet`). Key input handling (`hud_squadmsg_read_key`, `hud_squadmsg_get_key`). Menu rendering (`hud_squadmsg_display_menu`).
2.  **Potential Godot Solutions:** (As described previously) `Control` nodes for UI, `SquadMessageManager.gd` singleton for state/logic, `InputEventKey` processing, `MultiplayerAPI` for networking.
3.  **Target Code Structure:**
    ```
    scenes/ui/                 # UI scenes are typically outside gameplay HUD
    └── squad_message_menu.tscn # Scene for the squad message UI popup
    scripts/hud/               # Core logic remains under HUD component
    ├── squad_message_manager.gd    # Singleton: Manages menu state, commands, history, validation
    └── squad_message_menu.gd       # Attached to scene: Handles UI display and input
    scripts/ai/
    └── command_handler.gd          # Attached to AI ships: Receives and processes commands
    resources/hud/
    └── squad_commands.tres         # Resource defining available commands, text, validation rules
    ```

4.  **Important Methods, Classes, Data Structures:**
    *   `enum Squad_msg_mode`: -> GDScript `enum` in `SquadMessageManager`.
    *   `struct mmode_item`: -> `Dictionary` or custom class for menu items.
    *   `Comm_orders[]`: -> Data loaded from `squad_commands.tres`.
    *   `struct squadmsg_history`: -> Custom class `CommandHistoryEntry`.
    *   `hud_squadmsg_do_frame()`: -> `_process()`/`_input()` in `squad_message_menu.gd`.
    *   `hud_squadmsg_display_menu()`: -> Update function in `squad_message_menu.gd`.
    *   `hud_squadmsg_send_*_command()`: -> Methods in `SquadMessageManager` that call methods on `CommandHandler.gd` via signals or direct calls.
    *   Validation functions: -> Methods within `SquadMessageManager`.

5.  **Relations:** Reads Player target state. Reads Ship/Wing data. Interacts with AI (`CommandHandler`) to issue orders. Interacts with Mission System for reinforcements. Uses `MultiplayerAPI`. Plays sounds via `SoundManager`.

### E. Targeting System (`hudtarget.cpp`, `hudtarget.h`, `hudbrackets.cpp`, `hudbrackets.h`, `hudlock.cpp`, `hudlock.h`)

1.  **Key Features:** (As described previously) Target cycling, closest targeting, subsystem targeting, hotkeys, lead indicator (`hud_show_lead_indicator`, `polish_predicted_target_pos`), offscreen indicators (`hud_draw_offscreen_indicator`), missile lock (`hud_do_lock_indicator`), target brackets (`hud_show_brackets`, `draw_bounding_brackets*`), cargo scanning (`hud_cargo_scan_update`), AWACS integration (`hud_target_invalid_awacs`), IFF coloring (`hud_set_iff_color`), related gauges (energy, afterburner, countermeasures). Missile lock logic (`hud_calculate_lock_position`) involves timers, distance checks, and cone checks. Bracket drawing (`draw_bounding_brackets*`) handles different shapes (square, diamond) and subsystem brackets.
2.  **Potential Godot Solutions:** (As described previously) `TargetingComponent` on player, `HUDTargetingGauge` and sub-gauges (`HUDLeadIndicator`, `HUDOffscreenGauge`, `HUDLockGauge`, `HUDBrackets`) using `Control` nodes, custom drawing, `AnimatedSprite2D`, `Node2D`.
3.  **Target Code Structure:**
    ```
    scripts/player/
    └── targeting_component.gd    # Core targeting logic, hotkeys, AWACS checks, lead calc
    scripts/hud/gauges/
    ├── hud_targeting_gauge.gd    # Manages overall targeting display elements (optional container)
    ├── hud_lead_indicator.gd     # Draws lead indicator based on TargetingComponent data
    ├── hud_offscreen_gauge.gd    # Draws offscreen triangles/indicators
    ├── hud_lock_gauge.gd         # Handles missile lock display and sounds
    ├── hud_brackets.gd           # Draws target brackets (main and subsystem)
    ├── hud_cmeasure_gauge.gd     # Displays countermeasure count
    └── hud_auto_gauges.gd        # Displays auto-target/speed icons
    scenes/hud/gauges/            # Scenes for visual elements if not pure drawing
    ├── lead_indicator.tscn     # Node2D with script
    ├── offscreen_gauge.tscn    # Node2D with script
    ├── lock_gauge.tscn         # Control with AnimatedSprite2D/script
    └── brackets.tscn           # Node2D with script
    resources/hud/textures/
    ├── lead_indicator.png
    └── target_brackets/          # Bracket textures
    resources/hud/spriteframes/
    └── missile_lock.tres         # SpriteFrames for lock animation
    ```

4.  **Important Methods, Classes, Data Structures:**
    *   Targeting functions (`hud_target_common`, `hud_target_closest`, etc.): -> Methods in `TargetingComponent`.
    *   Hotkey functions (`hud_target_hotkey_*`): -> Methods in `TargetingComponent`.
    *   `hud_show_lead_indicator()`: -> Calculation in `TargetingComponent`, drawing in `HUDLeadIndicator`.
    *   `hud_draw_offscreen_indicator()`: -> Drawing logic in `HUDOffscreenGauge`.
    *   `hud_do_lock_indicator()`: -> Logic and state in `HUDLockGauge`.
    *   `hud_show_brackets()`, `draw_bounding_brackets*()`: -> Drawing logic in `HUDBrackets`.
    *   `hud_cargo_scan_update()`: -> State in `TargetingComponent`, display update in `HUDTargetBox`.
    *   `hud_set_iff_color()`: -> Global helper function or `IFFManager` method.
    *   Gauge display functions (`hud_show_*_gauge`): -> Update logic in respective gauge scripts.
    *   `htarget_list`: -> `Array` or `Dictionary` in `TargetingComponent` or `PlayerData`.
    *   `Homing_beep_info`: -> Logic within `HUDLockGauge` or `SoundManager` to adjust beep frequency/pitch based on distance.

5.  **Relations:** `TargetingComponent` reads game state (object positions, velocities, player weapons). HUD gauges read data from `TargetingComponent` and `Player` state. Interacts with `HUDConfigData` for settings. Uses `IFFManager`. Plays sounds via `SoundManager`.

### F. Target Box (`hudtargetbox.cpp`, `hudtargetbox.h`)

1.  **Key Features:** (As described previously) Detailed target info display, 3D model view (`hud_render_target_setup`, `model_render`), wireframe modes (`Targetbox_wire`), integrity bars (`hud_blit_target_integrity`), cargo/subsystem/status/orders display (`hud_render_target_ship_info`, `hud_targetbox_show_extra_ship_info`), flashing effects (`hud_targetbox_*_flash`), sensor static effect (`hud_targetbox_static_maybe_blit`). Handles various object types (`hud_render_target_*`). Name truncation (`hud_targetbox_truncate_subsys_name`).
2.  **Potential Godot Solutions:** (As described previously) `SubViewport` for 3D model, `Control` nodes (`Label`, `TextureRect`, `TextureProgress`) for info display, shaders/material overrides for wireframe, `Tween`/Timers for flashing, `AnimatedSprite2D`/shader for static.
3.  **Target Code Structure:**
    ```
    scenes/hud/gauges/
    ├── target_monitor.tscn      # Main scene for the target box gauge
    └── target_model_viewport.tscn # Scene for the SubViewport content (Camera, Lights)
    scripts/hud/gauges/
    └── hud_target_monitor.gd    # Script managing target box display, 3D view, info updates
    resources/hud/textures/targetbox/
    ├── target_view_bg.png
    ├── integrity_bar.png
    └── extra_info_bg.png
    shaders/
    └── wireframe.gdshader       # Optional shader for wireframe effect
    ```

4.  **Important Methods, Classes, Data Structures:**
    *   `hud_render_target_model()`: -> Main update/drawing logic in `hud_target_monitor.gd`.
    *   `hud_render_target_setup()` / `close()`: -> Handled by `SubViewport` setup/visibility.
    *   `hud_render_target_*_info()`: -> Helper functions in `hud_target_monitor.gd` to update specific labels.
    *   `hud_blit_target_integrity()`: -> Logic to update integrity bar (`TextureProgress` or custom draw).
    *   Flashing functions (`hud_targetbox_*_flash`): -> Methods using `Tween` or Timers.
    *   `hud_targetbox_static_maybe_blit()`: -> Method controlling static overlay visibility/animation.
    *   `Targetbox_wire`, `Lock_targetbox_mode`: -> Read from `HUDUserSettings`.

5.  **Relations:** Reads target data from `TargetingComponent` (current target, subsystem). Reads ship state (hull, shields, status, orders, cargo) from the target object's script. Uses `ModelSystem` (indirectly via `SubViewport`) to render the target model. Reads `HUDConfigData` for coordinates.

### G. Wingman Status (`hudwingmanstatus.cpp`, `hudwingmanstatus.h`)

1.  **Key Features:** (As described previously) Wing-based status display (`hud_wingman_status_render`), graphical dots for status/hull (`hud_wingman_status_blit_dots`), flashing on events (`hud_wingman_status_maybe_flash`), multiplayer team filtering (`hud_wingman_kill_multi_teams`). Status update logic (`hud_wingman_status_update`). Ship-to-slot mapping (`hud_wingman_status_set_index`).
2.  **Potential Godot Solutions:** (As described previously) `Control` nodes for layout, `TextureRect` for graphics, `Label` for names, `Tween`/Timers for flashing.
3.  **Target Code Structure:**
    ```
    scenes/hud/gauges/
    └── wingman_status_gauge.tscn # Main container for wingman status display
    scripts/hud/gauges/
    └── hud_wingman_gauge.gd      # Manages layout, updates, and rendering of wingman status
    resources/hud/textures/wingman_status/
    ├── wingman_bg_left.png
    ├── wingman_bg_middle.png
    ├── wingman_bg_right.png
    └── wingman_dots.png          # Sprite sheet for status dots
    ```

4.  **Important Methods, Classes, Data Structures:**
    *   `struct Wingman_status`: -> `Dictionary` or custom class holding wing status data within `hud_wingman_gauge.gd` or a global `WingManager`.
    *   `hud_wingman_status_update()`: -> Timer callback or `_process` logic fetching ship status.
    *   `hud_wingman_status_render()`: -> Main update/drawing function in `hud_wingman_gauge.gd`.
    *   Flashing functions: -> Methods using `Tween` or Timers.

5.  **Relations:** Reads ship status (hull, alive/dead/departed flags) from `ShipManager` or individual ship nodes. Reads wing structure (`Squadron_wing_names`) from `MissionData` or `WingManager`. Reads `HUDConfigData` for coordinates.

### H. Core HUD Logic (`hud.cpp`, `hud.h`)

1.  **Key Features:** (As described previously) Main render loop (`HUD_render_2d`, `HUD_render_3d`), initialization (`HUD_init`), visibility toggles (`hud_toggle_draw`), contrast (`hud_toggle_contrast`), global offsets (`HUD_set_offsets`), color management (`HUD_init_colors`), popups/flashing (`hud_gauge_popup_start`, `hud_gauge_start_flash`), global notifications (`hud_show_mission_time`, `hud_show_kills_gauge`, `hud_support_view_blit`, `hud_maybe_display_*`), engine sound loop (`update_throttle_sound`), utility functions (`hud_aabitmap`, `hud_set_gauge_color`), clipping (`HUD_set_clip`), talking head (`hud_maybe_blit_head_border`).
2.  **Potential Godot Solutions:** (As described previously) Main `HUD` scene (`CanvasLayer`), `hud.gd` controller script, `Theme` resource, `CanvasLayer` transform for shake, `Timer`/`Tween` for popups/flashing, separate gauge scenes for notifications, engine sound moved to player ship script.
3.  **Target Code Structure:**
    ```
    scenes/in_flight/
    └── hud.tscn                 # Root CanvasLayer for the HUD
    scripts/hud/
    ├── hud.gd                   # Main HUD controller script (attached to hud.tscn)
    ├── hud_globals.gd           # Singleton/Autoload for shared HUD settings/state (optional)
    └── effects/                 # Scripts for global HUD effects (shake, EMP overlay)
        ├── hud_shake_effect.gd
        └── hud_emp_overlay.gd
    resources/hud/
    └── hud_theme.tres           # Theme resource for colors, fonts, styles
    ```

4.  **Important Methods, Classes, Data Structures:**
    *   `HUD_init()`: -> `_ready()` in `hud.gd`.
    *   `hud_update_frame()`: -> `_process()` in `hud.gd`.
    *   `HUD_render_2d()`, `HUD_render_3d()`: -> Combined update/drawing logic triggered by `_process()` in `hud.gd`.
    *   `HUD_init_colors()`: -> Loading/applying `hud_theme.tres`.
    *   Color setting functions: -> Theme access or helper functions.
    *   Gauge status functions (`hud_gauge_active`, etc.): -> Methods in `hud.gd` reading `HUDUserSettings`.
    *   Popup/flash functions: -> Methods in `hud.gd` using Timers/Tweens.
    *   `HUD_set_offsets()`: -> Method modifying `CanvasLayer` transform.
    *   Clipping functions: -> `Control.clip_contents` or `SubViewport`.
    *   `update_throttle_sound()`: -> Logic moved to player ship script.
    *   Notification display functions: -> Logic within specific notification gauge scripts managed by `hud.gd`.

5.  **Relations:** Central coordinator. Reads `HUDUserSettings`. Calls update/render methods on child gauge nodes. Reads global game state (Mission Time, Player Mode, EMP status). Interacts with `SoundManager`.

### I. Radar System (`radar.cpp`, `radarorb.cpp`, `radarsetup.cpp`, `radar*.h`)

1.  **Key Features:** (As described previously) Standard/Orb modes (`select_radar_mode`), blip system (`blip`, `Blips`, `Blip_*_list`, `radar_plot_object_*`, `radar_stuff_blip_info_*`), IFF coloring, AWACS/sensor effects (`awacs_get_level`, `sensors_str`), range settings (`HUD_config.rp_dist`, `Radar_ranges`), custom icons (`radar_image_2d`), 3D rendering (Orb - `radar_orb_*`), static/distortion effects (`Radar_static_playing`, `BLIP_DRAW_DISTORTED`). Function pointers used for mode switching.
2.  **Potential Godot Solutions:** (As described previously) `Control` node (`HUDRadarGauge`), custom drawing (`_draw`), `RadarBlip` class/Dictionary, mode switching via script logic, shaders/`AnimatedSprite2D` for effects, `SubViewport` or 2D projection for Orb mode.
3.  **Target Code Structure:**
    ```
    scenes/hud/gauges/
    ├── radar_gauge.tscn         # Main radar gauge scene
    └── radar_orb_viewport.tscn  # Optional: SubViewport scene for Orb mode 3D elements
    scripts/hud/gauges/
    ├── hud_radar_base.gd        # Base class for common radar logic (range, etc.)
    ├── hud_radar_standard.gd    # Inherits base, implements 2D drawing
    ├── hud_radar_orb.gd         # Inherits base, implements Orb drawing (2D projection or SubViewport)
    └── radar_blip.gd            # Class definition for radar blips
    resources/hud/textures/radar/
    ├── radar_background_std.png
    ├── radar_background_orb.png
    ├── radar_blip_standard.png
    └── ship_radar_images/
        └── hercules_radar.png
    resources/hud/
    └── radar_config.tres        # Resource storing Radar_globals equivalent data
    ```
    *(Added RadarBlip class)*

4.  **Important Methods, Classes, Data Structures:**
    *   `struct radar_globals`: -> `RadarConfig` resource.
    *   `struct blip`: -> `RadarBlip` class (`scripts/hud/gauges/radar_blip.gd`).
    *   Blip lists: -> `Array`s sorted using `Array.sort_custom()`.
    *   `radar_plot_object_*()`: -> Helper function in radar gauge scripts.
    *   `radar_stuff_blip_info_*()`: -> Part of plotting logic.
    *   `radar_draw_blips_sorted_*()`: -> Main drawing logic in `_draw()`.
    *   `radar_frame_render_*()`: -> `_draw()` function.
    *   `select_radar_mode()`: -> Method in `HUDManager` or `hud.gd` to switch the active radar script/scene.

5.  **Relations:** Reads object data (position, type, IFF, status). Reads `Player` state (position, orientation, target). Uses `AWACSManager` and `SensorSubsystem` data. Reads `HUDUserSettings` for range. Interacts with `EMPManager`. Plays sounds via `SoundManager`. Uses `IFFManager` for colors.

## 3. Godot Project Structure (HUD)

```
wcsaga_godot/
├── resources/
│   ├── hud/
│   │   ├── configurations/     # HUDConfigData resources (.tres)
│   │   │   ├── default_640.tres
│   │   │   ├── default_1024.tres
│   │   │   └── ship_specific/
│   │   │       └── hercules.tres
│   │   ├── gauge_definitions/  # HUDGaugeConfig resources (.tres)
│   │   │   ├── player_shield.tres
│   │   │   ├── target_monitor.tres
│   │   │   ├── radar.tres
│   │   │   ├── reticle.tres
│   │   │   ├── throttle.tres
│   │   │   ├── weapons.tres
│   │   │   ├── wingman_status.tres
│   │   │   ├── ets.tres
│   │   │   ├── damage.tres
│   │   │   ├── escort.tres
│   │   │   ├── messages.tres
│   │   │   ├── objectives.tres
│   │   │   └── ... (all other standard gauges)
│   │   ├── textures/           # HUD graphic assets (backgrounds, icons, etc.)
│   │   │   ├── reticle/        # (fs1/, fs2/)
│   │   │   ├── shields/        # (player_base, target_base, ship_specific/)
│   │   │   ├── targetbox/      # (bg, integrity_bar, extra_bg)
│   │   │   ├── wingman_status/ # (bg_left, bg_middle, bg_right, dots)
│   │   │   ├── radar/          # (bg_std, bg_orb, blip_std, ship_radar_images/)
│   │   │   ├── common/         # (brackets, indicators, etc.)
│   │   │   └── gauges/         # (ets_bar, throttle_bar, etc.)
│   │   ├── fonts/              # Font resources (.ttf, .otf)
│   │   │   └── hud_font.tres
│   │   ├── themes/             # Theme resources (.tres)
│   │   │   └── hud_theme.tres
│   │   ├── spriteframes/       # SpriteFrames resources (.tres)
│   │   │   ├── threat_warnings.tres
│   │   │   ├── missile_lock.tres
│   │   │   └── hud_static.tres
│   │   ├── radar_config.tres   # Radar_globals equivalent
│   │   └── squad_commands.tres # Squad message command definitions
│   └── user_settings.tres      # (In user://) Saved HUDUserSettings
├── scenes/
│   ├── in_flight/
│   │   └── hud.tscn            # Root CanvasLayer for the HUD
│   ├── hud/                    # Reusable HUD gauge scenes
│   │   ├── gauges/
│   │   │   ├── hud_gauge_base.tscn # Optional base scene
│   │   │   ├── radar_gauge.tscn
│   │   │   ├── shield_gauge.tscn
│   │   │   ├── shield_mini_gauge.tscn
│   │   │   ├── reticle_gauge.tscn
│   │   │   ├── throttle_gauge.tscn
│   │   │   ├── threat_gauge.tscn
│   │   │   ├── weapons_gauge.tscn
│   │   │   ├── target_monitor.tscn
│   │   │   ├── target_model_viewport.tscn
│   │   │   ├── wingman_status_gauge.tscn
│   │   │   ├── lead_indicator.tscn # Node2D for drawing
│   │   │   ├── offscreen_gauge.tscn  # Node2D for drawing
│   │   │   ├── lock_gauge.tscn
│   │   │   ├── brackets.tscn         # Node2D for drawing
│   │   │   ├── cmeasure_gauge.tscn
│   │   │   ├── auto_gauges.tscn
│   │   │   ├── ets_gauge.tscn
│   │   │   ├── damage_gauge.tscn     # Popup/gauge for damage
│   │   │   ├── message_gauge.tscn    # For scrolling messages
│   │   │   ├── objective_gauge.tscn  # For objective notifications
│   │   │   ├── escort_gauge.tscn
│   │   │   ├── kills_gauge.tscn
│   │   │   ├── time_gauge.tscn
│   │   │   ├── support_gauge.tscn
│   │   │   ├── lag_gauge.tscn
│   │   │   └── nav_gauge.tscn
│   │   └── effects/
│   │       └── hud_static_overlay.tscn # For sensor damage
│   ├── ui/
│   │   ├── squad_message_menu.tscn
│   │   └── hud_config_screen.tscn
│   └── ...
├── scripts/
│   ├── hud/
│   │   ├── hud.gd                # Main HUD controller (on hud.tscn)
│   │   ├── hud_manager.gd        # Singleton: Loads configs, applies settings
│   │   ├── resources/            # Scripts defining custom Resource types
│   │   │   ├── hud_config_data.gd
│   │   │   ├── hud_gauge_config.gd
│   │   │   └── hud_user_settings.gd
│   │   ├── gauges/               # Scripts for individual gauges
│   │   │   ├── hud_gauge_base.gd   # Base class for common gauge logic
│   │   │   ├── hud_radar_base.gd
│   │   │   ├── hud_radar_standard.gd
│   │   │   ├── hud_radar_orb.gd
│   │   │   ├── radar_blip.gd       # Class for radar blips
│   │   │   ├── hud_shield_gauge.gd
│   │   │   ├── hud_reticle_gauge.gd
│   │   │   ├── hud_throttle_gauge.gd
│   │   │   ├── hud_threat_gauge.gd
│   │   │   ├── hud_weapons_gauge.gd
│   │   │   ├── hud_target_monitor.gd
│   │   │   ├── hud_wingman_gauge.gd
│   │   │   ├── hud_lead_indicator.gd
│   │   │   ├── hud_offscreen_gauge.gd
│   │   │   ├── hud_lock_gauge.gd
│   │   │   ├── hud_brackets.gd
│   │   │   ├── hud_ets_gauge.gd
│   │   │   ├── hud_damage_gauge.gd
│   │   │   ├── hud_message_gauge.gd
│   │   │   ├── hud_objective_gauge.gd
│   │   │   ├── hud_escort_gauge.gd
│   │   │   └── ... (scripts for all other gauges)
│   │   ├── effects/              # Scripts for HUD visual effects
│   │   │   ├── hud_shake_effect.gd
│   │   │   └── hud_static_overlay.gd
│   │   └── squad_message_manager.gd # Singleton for squad message logic
│   │   └── squad_message_menu.gd    # UI script for squad messages
│   ├── ui/
│   │   └── hud_config_screen.gd  # Logic for HUD config UI
│   ├── player/
│   │   └── targeting_component.gd # Handles targeting logic needed by HUD
│   ├── ship_weapon_systems/components/
│   │   └── shield_component.gd   # Shield logic accessed by HUD
│   └── globals/
│       ├── game_state.gd         # Example global state access
│       ├── player_state.gd       # Example player state access
│       └── game_settings.gd      # Access global settings
│   └── ...
├── shaders/
│   ├── hud_static.gdshader
│   └── wireframe.gdshader
│   └── ...
```


## 4. Relations (Summary)

The HUD system is primarily a **display** system. It reads data from various core game systems and presents it visually.

*   **Reads From:**
    *   `PlayerState`/`PlayerShip`: Position, orientation, speed, throttle, afterburner status, energy levels, shield status, weapon status, target info, threat status, wingman references, mission time, kills, countermeasures, comms status, EMP status.
    *   `TargetingComponent`: Current target, targeted subsystem, lead indicator data, lock status, cargo scan status, hotkeys.
    *   `ShipManager`/`ObjectManager`: Positions, orientations, types, IFF, status of all relevant objects for radar, offscreen indicators, target box, wingman status.
    *   `MissionManager`: Current objectives, mission time, reinforcement status, subspace drive status, red alert status.
    *   `MessageManager`: Incoming messages, talking head status.
    *   `HUDManager`: Layout configuration (`HUDConfigData`), user settings (`HUDUserSettings`), theme data.
    *   `IFFManager`: IFF colors and relationships.
    *   `AWACSManager`/`SensorSubsystem`: Sensor strength, AWACS levels for radar visibility/distortion.
*   **Writes To / Interacts With:**
    *   `AI System` (`CommandHandler`): Sends commands via `SquadMessageManager`.
    *   `SoundManager`: Plays UI sounds, warnings, lock tones.
    *   `Input`: Reads player input for squad messages, potentially HUD toggles.
    *   `HUDManager`: Saves user settings via the config screen.
    *   `MultiplayerAPI`: Sends squad messages in multiplayer.

## 5. Conversion Strategy Notes (Summary)

*   **Data-Driven:** Convert `.tbl` files to Godot Resources (`.tres`) or JSON first. Use these resources (`HUDConfigData`, `HUDGaugeConfig`, `HUDUserSettings`, `RadarConfig`, `SquadCommands`) to drive layout, appearance, and behavior.
*   **Modular Gauges:** Implement each distinct HUD element (Radar, Shields, Target Box, Reticle, etc.) as a separate scene (`.tscn`) with an associated script (`.gd`).
*   **Central Controller:** Use the main `hud.gd` script on the root `CanvasLayer` to instantiate, position (based on loaded config), and manage the visibility/updates of these individual gauge scenes. Use `HUDManager.gd` (Singleton) for loading/saving configurations.
*   **Godot UI Nodes:** Leverage `Control` nodes, `TextureRect`, `Label`, `TextureProgress`, `SubViewport`, `AnimatedSprite2D`, `Tween`, `Timer`.
*   **Custom Drawing:** Use `_draw()` for complex elements like radar blips, brackets, indicators, shield quadrants.
*   **Signals:** Use signals extensively for communication (e.g., `ShieldComponent.shield_hit`, `TargetingComponent.target_changed`, `MissionManager.objective_updated`).
*   **Theme:** Utilize Godot's `Theme` system for consistent styling and color management.

## 6. Testing Strategy (Summary)

Focus on visual fidelity compared to the original, functional correctness of each gauge (displaying the right data, responding to game state changes), performance impact, and usability of configuration options. Test across different resolutions and ship types.
