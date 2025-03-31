# Godot Project Structure for Wing Commander Saga Conversion

This document outlines the target directory and file structure for the Godot project, based on the component analysis.

```
wcsaga_godot/
├── addons/                 # Godot addons (external plugins)
│   ├── gfred2/             # GFRED Mission Editor Plugin (See 02_mission_editor.md)
│   │   ├── plugin.cfg      # Godot plugin configuration file
│   │   ├── plugin.gd       # Main plugin script (registers docks, tools)
│   │   ├── scenes/         # Editor UI scenes (main panel, property editors, SEXP editor)
│   │   ├── scripts/        # Editor logic scripts (data manager, UI controllers, viewport logic)
│   │   ├── resources/      # Editor-specific resources (gizmos, help data)
│   │   └── icons/          # Editor icons
│   └── limboai/            # LimboAI addon for Behavior Trees (See 01_ai.md)
├── assets/                 # Converted game assets (read-only at runtime) (See 03_asset_conversion_pipeline.md)
│   ├── animations/         # SpriteFrames (.tres), AnimationLibraries (.tres) - Converted from .ANI/.EFF (See 13_sound_and_animation.md)
│   ├── cutscenes/          # OGV/WebM video files - Converted from .MVE/.OGG (See 13_sound_and_animation.md)
│   ├── fonts/              # TTF/OTF font files (See 09_menu_ui.md)
│   ├── models/             # glTF models (.glb) - Converted from .POF (See 11_model.md)
│   ├── music/              # OGG music tracks (See 13_sound_and_animation.md)
│   ├── sounds/             # OGG/WAV sound effects (See 13_sound_and_animation.md)
│   ├── textures/           # PNG/WebP textures (UI, models, effects) - Converted from .DDS/.PCX etc. (See 14_graphics.md)
│   └── voices/             # OGG/WAV voice files (See 13_sound_and_animation.md)
├── migration_tools/        # Python scripts for asset/data conversion (Not part of the final game build) (See 03_asset_conversion_pipeline.md)
├── resources/              # Godot resource files (.tres) defining game data (Editable game parameters)
│   ├── ai/                 # AI-related resources (See 01_ai.md)
│   │   ├── profiles/       # AIProfile resources (.tres) - Defines AI skill/behavior parameters
│   │   └── behavior_trees/ # LimboAI BehaviorTree resources (.tres) - Defines specific AI logic flows
│   ├── armor/              # ArmorData resources (.tres) - Defines damage resistances (See 05_ship_weapon_systems.md)
│   ├── autopilot/          # Autopilot system resources (See 12_controls_and_camera.md)
│   │   ├── autopilot_config.tres # Global autopilot settings (link distance, messages)
│   │   └── nav_points/     # NavPointData resources (.tres) per mission - Defines navigation targets
│   ├── campaigns/          # CampaignData resources (.tres) - Defines campaign structure and progression (See 07_mission_system.md)
│   ├── game_data/          # Global game data resources (See 04_core_systems.md)
│   │   ├── game_sounds.tres # Mapping sound IDs/names to AudioStream paths (from sounds.tbl) (See 13_sound_and_animation.md)
│   │   ├── music_tracks.tres # Music definitions and event logic (from music.tbl) (See 13_sound_and_animation.md)
│   │   ├── ranks.tres      # Rank definitions and requirements (from rank.tbl)
│   │   ├── medals.tres     # Medal definitions and criteria (from medals.tbl)
│   │   ├── species/        # SpeciesInfo resources (.tres) per species (from species_defs.tbl)
│   │   ├── iff_defs.tres   # IFF definitions and relationships (from iff_defs.tbl) (See 01_ai.md)
│   │   └── global_settings.tres # Miscellaneous global settings
│   ├── hud/                # HUD configuration resources (See 06_hud_system.md)
│   │   ├── configurations/ # HUDConfigData resources (.tres) - Layouts per resolution/ship
│   │   ├── gauge_definitions/ # HUDGaugeConfig resources (.tres) - Base definitions for gauges
│   │   ├── themes/         # HUD Theme resources (.tres) - Colors, fonts, styles
│   │   ├── textures/       # Specific HUD textures not part of general assets/textures
│   │   ├── fonts/          # Specific HUD fonts
│   │   ├── spriteframes/   # SpriteFrames for HUD animations (warnings, lock)
│   │   └── radar_config.tres # Radar specific settings
│   ├── missions/           # MissionData resources (.tres) - Converted from .fs2 files (See 07_mission_system.md)
│   │   ├── mission_01.tres # Example mission resource
│   │   └── campaign_a/     # Subfolder for campaign missions
│   │       └── mission_a_01.tres
│   ├── model_metadata/     # ModelMetadata resources (.tres) - Stores POF metadata (points, subsystems) per model (See 11_model.md)
│   ├── scripting/          # Scripting system resources (See 08_scripting.md)
│   │   ├── sexp_operators.tres # (Optional) Resource defining SEXP operator signatures/validation rules
│   │   └── script_hooks.tres # (Optional) Resource defining GDScript hooks (if not hardcoded)
│   ├── ships/              # ShipData resources (.tres) - Defines static ship properties (from ships.tbl) (See 05_ship_weapon_systems.md)
│   ├── sounds/             # (Potentially merged into game_data/game_sounds.tres) SoundEntry resources (See 13_sound_and_animation.md)
│   └── weapons/            # WeaponData resources (.tres) - Defines static weapon properties (from weapons.tbl) (See 05_ship_weapon_systems.md)
├── scenes/                 # Scene files (.tscn) - Instantiable game elements and UI screens
│   ├── core/               # Core scenes (e.g., main game loop, manager nodes) (See 04_core_systems.md)
│   │   ├── game_manager.tscn        # Main game state and loop integration node
│   │   ├── object_manager.tscn      # Object tracking node
│   │   ├── game_sequence_manager.tscn # Game state machine node
│   │   ├── scoring_manager.tscn     # Scoring/stats management node
│   │   ├── species_manager.tscn     # Species data management node
│   │   ├── camera_manager.tscn      # Camera switching/management node (See 12_controls_and_camera.md)
│   │   ├── subtitle_manager.tscn    # Subtitle management node (See 12_controls_and_camera.md)
│   │   ├── autopilot_manager.tscn   # Autopilot state management node (See 12_controls_and_camera.md)
│   │   └── skybox.tscn         # Scene containing starfield/nebula setup (See 10_physics_and_space.md, 14_graphics.md)
│   ├── effects/            # Reusable effect scenes (explosions, trails, beams, particles, decals, warp) (See 05_ship_weapon_systems.md, 10_physics_and_space.md)
│   │   ├── explosion_medium.tscn # Medium explosion effect scene
│   │   ├── shield_impact.tscn    # Shield hit visual effect scene
│   │   ├── muzzle_flash.tscn     # Weapon muzzle flash effect scene
│   │   ├── shockwave.tscn        # Shockwave visual effect scene
│   │   ├── warp_effect.tscn      # Warp in/out visual effect scene
│   │   ├── spark_effect.tscn     # Damage spark effect scene
│   │   ├── debris_hull.tscn      # Large ship debris piece scene
│   │   ├── debris_small.tscn     # Small debris piece scene
│   │   ├── laser_hit.tscn        # Laser impact effect scene
│   │   └── beam_effect.tscn      # Beam weapon visual effect scene
│   ├── gameplay/           # Main gameplay scenes (space flight environment)
│   │   └── space_flight.tscn   # The primary scene for in-flight gameplay, containing player, environment, managers
│   ├── missions/           # Mission-specific scenes (briefing, debriefing, command brief) (See 07_mission_system.md)
│   │   ├── briefing/           # Briefing screen elements
│   │   │   ├── briefing_screen.tscn     # Main briefing UI scene
│   │   │   ├── briefing_map_viewport.tscn # SubViewport for the 3D map display
│   │   │   └── briefing_icon.tscn       # Scene for individual map icons
│   │   ├── debriefing/         # Debriefing screen elements
│   │   │   └── debriefing_screen.tscn   # Main debriefing UI scene
│   │   └── command_brief/      # Command Briefing screen elements
│   │       └── command_brief_screen.tscn # Main command briefing UI scene
│   ├── ships_weapons/      # Ship and Weapon scenes (visuals, collision, base logic node) (See 05_ship_weapon_systems.md, 11_model.md)
│   │   ├── base_ship.tscn      # Base scene structure for all ships (includes core components)
│   │   ├── hercules.tscn     # Example specific ship scene inheriting from base_ship
│   │   ├── components/       # Reusable ship components scenes
│   │   │   ├── weapon_hardpoint.tscn # Mount point for weapons (Node3D + script)
│   │   │   ├── turret_base.tscn      # Base scene for turrets (Node3D + script + WeaponSystem)
│   │   │   └── engine_nozzle.tscn    # Scene for engine effects (GPUParticles3D + script)
│   │   ├── projectiles/      # Projectile scenes
│   │   │   ├── projectile_base.tscn  # Base scene for projectiles (RigidBody3D/Area3D + script)
│   │   │   ├── laser_projectile.tscn # Laser projectile scene
│   │   │   └── missile_projectile.tscn # Missile projectile scene
│   │   └── weapons/          # Scenes for complex weapons like beams
│   │       └── beam_weapon_visual.tscn # Visual representation of a beam effect
│   ├── ui/                 # UI scenes (menus, HUD, popups, config screens, etc.) (See 09_menu_ui.md, 06_hud_system.md)
│   │   ├── main_menu.tscn      # Main menu screen scene
│   │   ├── options_menu.tscn   # Options/settings screen scene
│   │   ├── hud.tscn            # Root HUD CanvasLayer for in-flight display
│   │   ├── hud_config_screen.tscn # Screen for configuring HUD layout/colors
│   │   ├── control_options_menu.tscn # Screen for configuring input controls
│   │   ├── ready_room.tscn     # Mission selection UI screen scene
│   │   ├── tech_room.tscn      # Tech database UI screen scene
│   │   ├── lab_viewer.tscn     # Model viewer UI screen scene
│   │   ├── ship_select.tscn    # Mission ship selection UI screen scene
│   │   ├── weapon_select.tscn  # Mission weapon selection UI screen scene
│   │   ├── popups/             # Popup dialog scenes
│   │   │   ├── popup_base.tscn   # Base scene for generic popups
│   │   │   └── death_popup.tscn  # Popup shown on player death
│   │   ├── hud/                # Reusable HUD gauge scenes
│   │   │   ├── gauges/         # (radar, shield, target_monitor, reticle, etc.) Individual gauge scenes
│   │   │   └── effects/        # (hud_static_overlay) HUD specific visual effects scenes
│   │   ├── mission_log/        # Mission log UI screen scene
│   │   │   └── mission_log_screen.tscn
│   │   ├── hotkey_screen/      # Hotkey assignment UI screen scene
│   │   │   └── hotkey_screen.tscn
│   │   └── autopilot_message.tscn # UI for displaying autopilot messages
│   └── utility/            # Helper scenes (e.g., observer viewpoint, debug tools)
│       └── observer_viewpoint.tscn # Scene for observer camera (See 12_controls_and_camera.md)
├── scripts/                # GDScript files, organized by component
│   ├── ai/                 # AIController, AI behaviors, targeting, pathfinding, AIProfile script (See 01_ai.md)
│   │   ├── ai_controller.gd         # Main AI logic node script attached to ships
│   │   ├── perception_component.gd  # Handles sensing environment, targets, threats
│   │   ├── ai_state_machine.gd    # State machine implementation (or use LimboAI BTState)
│   │   ├── ai_behavior_tree.gd    # Base/helper for LimboAI BehaviorTree resources
│   │   ├── ai_blackboard.gd       # LimboAI blackboard resource script
│   │   ├── ai_goal_manager.gd     # Handles goal processing and prioritization within AIController
│   │   ├── behaviors/           # Scripts defining specific AI states/behaviors (or LimboAI tasks)
│   │   ├── navigation/          # Navigation related scripts (path_follower, collision_avoidance)
│   │   ├── targeting/           # Targeting related scripts (targeting_system, stealth_detector)
│   │   └── turret/              # Turret specific AI script (turret_ai)
│   ├── core_systems/       # GameManager, ObjectManager, GameSequenceManager, PlayerData, ScoringManager, etc. (See 04_core_systems.md)
│   │   ├── game_manager.gd          # Main game state, loop integration, time, pausing logic
│   │   ├── object_manager.gd        # Object tracking, lookup by signature/ID logic
│   │   ├── base_object.gd           # Base script class for all game objects (ships, weapons, etc.)
│   │   ├── game_sequence_manager.gd # State machine logic for game states (menu, briefing, gameplay, etc.)
│   │   ├── scoring_manager.gd       # Scoring, rank, medal evaluation logic
│   │   ├── species_manager.gd       # Manages loading/accessing SpeciesInfo resources
│   │   ├── camera_manager.gd        # Manages camera creation, switching, lookup logic (See 12_controls_and_camera.md)
│   │   ├── subtitle_manager.gd      # Manages subtitle queue and display logic (See 12_controls_and_camera.md)
│   │   └── autopilot_manager.gd     # Manages autopilot state, engagement, NavPoints logic (See 12_controls_and_camera.md)
│   ├── ship/                 # Ship logic and core components (See 05_ship_weapon_systems.md)
│   │   ├── ship_base.gd             # Base ship logic, physics integration, state management script
│   │   │   ├── func take_damage(hit_pos: Vector3, amount: float, killer_obj_id: int = -1, damage_type_key = -1, hit_subsystem: Node = null)
│   │   │   ├── func fire_primary_weapons()
│   │   │   ├── func fire_secondary_weapons()
│   │   │   ├── func engage_afterburner()
│   │   │   ├── func disengage_afterburner()
│   │   │   ├── func start_destruction_sequence(killer_obj_id: int)
│   │   │   ├── func apply_emp_effect(intensity: float, time: float)
│   │   │   ├── func shipfx_start_cloak(warmup_ms: int = 5000, recalc_matrix: bool = true, device_cloak: bool = false)
│   │   │   ├── func shipfx_stop_cloak(warmdown_ms: int = 5000)
│   │   │   ├── func shipfx_cloak_frame(delta: float)
│   │   │   ├── func shipfx_warpin_start()
│   │   │   ├── func shipfx_warpin_frame(delta: float)
│   │   │   ├── func shipfx_warpout_start()
│   │   │   └── func shipfx_warpout_frame(delta: float)
│   │   ├── player_ship.gd           # Player-specific ship logic script
│   │   ├── weapon_system.gd         # Manages weapon banks, firing, energy/ammo logic script
│   │   │   ├── func initialize_from_ship_data(ship_data: ShipData)
│   │   │   ├── func can_fire_primary(bank_index: int) -> bool
│   │   │   ├── func fire_primary(force: bool = false, bank_index_override: int = -1) -> bool
│   │   │   ├── func can_fire_secondary(bank_index: int) -> bool
│   │   │   ├── func fire_secondary(allow_swarm: bool = false, bank_index_override: int = -1) -> bool
│   │   │   ├── func select_next_primary() -> int
│   │   │   ├── func select_next_secondary() -> int
│   │   │   ├── func get_primary_ammo_pct(bank_index: int) -> float
│   │   │   ├── func get_secondary_ammo_pct(bank_index: int) -> float
│   │   │   └── func get_weapon_energy_pct() -> float
│   │   ├── shield_system.gd         # Manages shield state, recharge, damage absorption logic script
│   │   │   ├── func initialize_from_ship_data(ship_data: ShipData)
│   │   │   ├── func absorb_damage(quadrant: int, damage: float, damage_type_key = -1) -> float
│   │   │   ├── func get_quadrant_strength(quadrant: int) -> float
│   │   │   ├── func get_total_strength() -> float
│   │   │   ├── func get_max_strength_per_quadrant() -> float
│   │   │   ├── func is_quadrant_up(quadrant: int) -> bool
│   │   │   └── func get_quadrant_from_local_pos(local_pos: Vector3) -> int
│   │   ├── damage_system.gd         # Applies damage, handles hull/subsystem integrity logic script
│   │   │   ├── func initialize_from_ship_data(ship_data: ShipData)
│   │   │   ├── func apply_local_damage(hit_pos: Vector3, damage: float, killer_obj_id: int = -1, damage_type_key = -1, hit_subsystem: Node = null)
│   │   │   ├── func apply_global_damage(damage: float, killer_obj_id: int = -1, damage_type_key = -1)
│   │   │   └── func get_damage_sources() -> Dictionary
│   │   ├── engine_system.gd         # Handles afterburner logic, potentially thrust effects script
│   │   │   ├── func initialize_from_ship_data(ship_data: ShipData)
│   │   │   ├── func start_afterburner()
│   │   │   ├── func stop_afterburner(key_released: bool = false)
│   │   │   └── func get_afterburner_fuel_pct() -> float
│   │   └── subsystems/              # Subsystem logic scripts
│   │       ├── ship_subsystem.gd    # Base subsystem state script
│   │       │   ├── func initialize_from_definition(definition: ShipData.SubsystemDefinition)
│   │       │   ├── func take_damage(amount: float, damage_type_key = -1) -> float
│   │       │   ├── func disrupt(duration_ms: int)
│   │       │   ├── func destroy_subsystem()
│   │       │   ├── func get_health_percentage() -> float
│   │       │   └── func is_functional() -> bool
│   │       ├── turret_subsystem.gd  # Logic for turret subsystems (aiming, firing)
│   │       │   ├── func initialize_from_definition(definition: ShipData.SubsystemDefinition)
│   │       │   ├── func aim_at_target(target_global_pos: Vector3, delta: float)
│   │       │   ├── func fire_turret()
│   │       │   ├── func is_turret_ready_to_fire(target: Node3D) -> bool
│   │       │   └── func get_turret_hardpoints(slot_index: int) -> Array[Marker3D]
│   │       ├── engine_subsystem.gd  # Logic for engine subsystems (effects)
│   │       │   ├── func initialize_from_definition(definition: ShipData.SubsystemDefinition)
│   │       │   └── func destroy_subsystem()
│   │       └── sensor_subsystem.gd  # Logic for sensor/AWACS subsystems
│   │           ├── func initialize_from_definition(definition: ShipData.SubsystemDefinition)
│   │           ├── func get_awacs_level_at_pos(target_pos: Vector3) -> float
│   │           └── func destroy_subsystem()
│   ├── weapon/               # Weapon instance and projectile logic (See 05_ship_weapon_systems.md)
│   │   ├── weapon.gd                # Base weapon instance logic script (WeaponInstance)
│   │   │   ├── func initialize(w_system: WeaponSystem, w_data: WeaponData, h_point: Node3D)
│   │   │   └── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   ├── laser_weapon.gd          # Logic for laser weapon instances
│   │   │   └── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   ├── missile_weapon.gd        # Logic for missile weapon instances
│   │   │   └── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   ├── beam_weapon.gd           # Logic for beam weapon instances
│   │   │   ├── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   │   ├── func start_beam_fire()
│   │   │   ├── func stop_firing()
│   │   │   └── func apply_beam_damage(collider: Node, hit_point: Vector3, hit_normal: Vector3)
│   │   ├── flak_weapon.gd           # Logic for flak weapon instances
│   │   │   └── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   ├── emp_weapon.gd            # Logic for EMP weapon instances
│   │   │   └── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   ├── swarm_weapon.gd          # Logic for swarm missile weapon instances
│   │   │   └── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   ├── corkscrew_weapon.gd      # Logic for corkscrew missile weapon instances
│   │   │   └── func fire(target: Node3D = null, target_subsystem: ShipSubsystem = null) -> bool
│   │   └── projectiles/             # Projectile logic scripts
│   │       ├── projectile_base.gd   # Base projectile logic script (movement, lifetime, impact)
│   │       │   └── func setup(w_data: WeaponData, owner: ShipBase, target: Node3D = null, target_sub: ShipSubsystem = null, initial_velocity: Vector3 = Vector3.ZERO)
│   │       ├── laser_projectile.gd  # Logic for laser projectiles
│   │       └── missile_projectile.gd # Logic for missile projectiles (homing)
│   ├── hud/                # HUDManager, HUDGauge base, specific gauge scripts (Radar, Shields, TargetBox, etc.) (See 06_hud_system.md)
│   │   ├── hud.gd                   # Main HUD controller script (attached to hud.tscn)
│   │   ├── hud_manager.gd           # Singleton for config loading, applying settings logic
│   │   ├── gauges/                  # Scripts for individual gauges (hud_gauge_base, hud_radar_base, hud_shield_gauge, etc.)
│   │   ├── effects/                 # Scripts for HUD visual effects (hud_shake_effect, hud_static_overlay)
│   │   └── squad_message_manager.gd # Singleton for squad message logic
│   ├── mission_system/     # MissionManager, Briefing/Debriefing logic, CampaignManager, LogManager (See 07_mission_system.md)
│   │   ├── mission_manager.gd       # Singleton: Manages mission lifecycle, state, objects, events, goals logic.
│   │   ├── arrival_departure.gd     # Node/Helper: Handles arrival/departure logic and timing script.
│   │   ├── spawn_manager.gd         # Node/Helper: Handles instantiating ships/wings script.
│   │   ├── mission_loader.gd        # Helper: Loads MissionData resources script.
│   │   ├── briefing/                # Briefing system scripts (briefing_screen, briefing_map_manager, briefing_icon)
│   │   ├── debriefing/              # Debriefing system scripts (debriefing_screen, scoring_system)
│   │   ├── log/                     # Mission Log scripts (mission_log_manager)
│   │   ├── message_system/          # Message system scripts (message_manager)
│   │   ├── training_system/         # Training system scripts (training_manager)
│   │   └── hotkey/                  # Mission Hotkey scripts (mission_hotkey_manager)
│   ├── scripting/          # SEXPParser, SEXPNode, SEXPEvaluator, SEXPVariableManager, ScriptState (hooks), Table parsers (See 08_scripting.md)
│   │   ├── sexp/                    # SEXP system implementation (sexp_node, sexp_parser, sexp_evaluator, sexp_operators, sexp_variables, sexp_constants)
│   │   └── hook_system/             # Hook system implementation (script_state, script_hook, conditioned_hook, script_condition, script_action, script_parser)
│   ├── menu_ui/            # Scripts for main menus, options, popups, custom UI controls (See 09_menu_ui.md)
│   │   ├── main_menu.gd             # Main menu logic script
│   │   ├── options_menu.gd          # Options menu logic script
│   │   ├── control_options_menu.gd  # Control configuration UI logic script
│   │   ├── ready_room.gd            # Mission selection UI logic script
│   │   ├── tech_room.gd             # Tech database UI logic script
│   │   ├── lab_viewer.gd            # Model viewer UI logic script
│   │   ├── ship_select.gd           # Ship selection UI logic script
│   │   ├── weapon_select.gd         # Weapon selection UI logic script
│   │   ├── popups/                  # Popup logic scripts (popup_base, death_popup)
│   │   ├── help/                    # Context help logic (context_help_manager, help_overlay)
│   │   ├── snazzy/                  # Snazzy UI logic (snazzy_ui, region)
│   │   └── components/              # Custom UI component scripts (wcsaga_button, wcsaga_listbox, etc.)
│   ├── physics_space/      # Custom physics integrator (if needed), AsteroidField, DebrisManager, JumpNode logic (See 10_physics_and_space.md)
│   │   ├── space_physics.gd         # Attached to ShipBase for custom physics integration logic
│   │   ├── asteroid_field.gd        # Manages asteroid fields script
│   │   ├── asteroid.gd              # Logic for individual asteroids script
│   │   ├── debris_manager.gd        # Manages debris creation/cleanup script
│   │   ├── debris_base.gd           # Base script for debris pieces
│   │   ├── debris_hull.gd           # Logic for large hull debris script
│   │   ├── debris_small.gd          # Logic for small debris script
│   │   ├── jump_node.gd             # Logic for jump nodes script
│   │   └── jump_node_manager.gd     # Singleton for managing jump nodes script
│   ├── model_systems/      # Scripts related to model instance handling (e.g., submodel state, metadata loading) (See 11_model.md)
│   │   └── model_metadata_loader.gd # Optional helper script for loading/applying metadata
│   ├── controls_camera/    # PlayerController, CameraController, Autopilot logic, Observer logic (See 12_controls_and_camera.md)
│   │   ├── player_ship_controller.gd # Handles player input mapping to ship actions script
│   │   ├── base_camera_controller.gd # Base script for Camera3D nodes
│   │   ├── cinematic_camera_controller.gd # Specific logic for cutscene/cinematic cameras script
│   │   ├── autopilot_camera_controller.gd # Logic for cinematic autopilot camera movement script
│   │   ├── warp_camera_controller.gd  # Logic for warp effect camera script
│   │   └── observer_viewpoint.gd    # Script for observer viewpoint nodes
│   ├── sound_animation/    # SoundManager, MusicManager, custom animation players (e.g., ani_player_2d) (See 13_sound_and_animation.md)
│   │   ├── sound_manager.gd         # Singleton for managing sound playback logic
│   │   ├── music_manager.gd         # Singleton for managing event music logic
│   │   ├── ani_player_2d.gd         # Custom node/script for ANI playback logic
│   │   └── audio_bus_controller.gd  # Optional script for managing audio bus effects
│   ├── graphics/           # Scripts related to graphics utilities or managing complex effects (See 14_graphics.md)
│   │   ├── graphics_utilities.gd    # Helper functions for graphics tasks script
│   │   ├── post_processing.gd       # Script for custom post-processing effects
│   │   ├── starfield_manager.gd     # Manages starfield background script
│   │   ├── nebula_manager.gd        # Manages nebula effects/fog script
│   │   ├── decal_manager.gd         # Manages decal creation/lifetime script
│   │   ├── explosion_manager.gd     # Manages explosion effects script
│   │   ├── shockwave_manager.gd     # Manages shockwave effects script
│   │   ├── trail_manager.gd         # Manages weapon trail effects script
│   │   ├── muzzle_flash_manager.gd  # Manages muzzle flash effects script
│   │   ├── warp_effect_manager.gd   # Manages warp visual effects script
│   │   └── spark_manager.gd         # Manages spark effects script
│   ├── resources/          # Scripts defining custom Resource types (logic associated with .tres files)
│   │   ├── ai_goal.gd               # Defines AI goal structure
│   │   │   ├── func is_valid() -> bool
│   │   │   ├── func set_flag(flag_enum: GoalFlags, value: bool)
│   │   │   ├── func has_flag(flag_enum: GoalFlags) -> bool
│   │   │   ├── func get_target_ship_name() -> String
│   │   │   ├── func get_target_wing_name() -> String
│   │   │   └── func get_target_waypoint_list_name() -> String
│   │   ├── ai_profile.gd            # Defines AI behavior parameters
│   │   │   ├── func get_accuracy(skill_level: int) -> float
│   │   │   ├── func get_evasion(skill_level: int) -> float
│   │   │   ├── func get_courage(skill_level: int) -> float
│   │   │   ├── func get_patience(skill_level: int) -> float
│   │   │   ├── func get_max_attackers(skill: int) -> int
│   │   │   ├── func get_predict_position_delay(skill: int) -> float
│   │   │   ├── func get_turn_time_scale(skill: int) -> float
│   │   │   ├── func get_cmeasure_fire_chance(skill: int) -> float
│   │   │   ├── func get_in_range_time(skill: int) -> float
│   │   │   ├── func get_link_ammo_levels_maybe(skill: int) -> float
│   │   │   ├── func get_link_ammo_levels_always(skill: int) -> float
│   │   │   ├── func get_primary_ammo_burst_mult(skill: int) -> float
│   │   │   ├── func get_link_energy_levels_maybe(skill: int) -> float
│   │   │   ├── func get_link_energy_levels_always(skill: int) -> float
│   │   │   ├── func get_shield_manage_delay(skill: int) -> float
│   │   │   ├── func get_ship_fire_delay_scale_friendly(skill: int) -> float
│   │   │   ├── func get_ship_fire_delay_scale_hostile(skill: int) -> float
│   │   │   ├── func get_ship_fire_secondary_delay_scale_friendly(skill: int) -> float
│   │   │   ├── func get_ship_fire_secondary_delay_scale_hostile(skill: int) -> float
│   │   │   ├── func get_glide_attack_percent(skill: int) -> float
│   │   │   ├── func get_circle_strafe_percent(skill: int) -> float
│   │   │   ├── func get_glide_strafe_percent(skill: int) -> float
│   │   │   ├── func get_stalemate_time_thresh(skill: int) -> float
│   │   │   ├── func get_stalemate_dist_thresh(skill: int) -> float
│   │   │   ├── func get_chance_to_use_missiles_on_plr(skill: int) -> int
│   │   │   ├── func get_max_aim_update_delay(skill: int) -> float
│   │   │   ├── func get_aburn_use_factor(skill: int) -> int
│   │   │   ├── func get_shockwave_evade_chance(skill: int) -> float
│   │   │   ├── func get_get_away_chance(skill: int) -> float
│   │   │   ├── func get_secondary_range_mult(skill: int) -> float
│   │   │   ├── func get_bump_range_mult(skill: int) -> float
│   │   │   ├── func get_afterburner_recharge_scale(skill: int) -> float
│   │   │   ├── func get_beam_friendly_damage_cap(skill: int) -> float
│   │   │   ├── func get_cmeasure_life_scale(skill: int) -> float
│   │   │   ├── func get_max_allowed_player_homers(skill: int) -> int
│   │   │   ├── func get_max_incoming_asteroids(skill: int) -> int
│   │   │   ├── func get_player_damage_scale(skill: int) -> float
│   │   │   ├── func get_subsys_damage_scale(skill: int) -> float
│   │   │   ├── func get_shield_energy_scale(skill: int) -> float
│   │   │   ├── func get_weapon_energy_scale(skill: int) -> float
│   │   │   ├── func get_max_turret_ownage_target(skill: int) -> int
│   │   │   ├── func get_max_turret_ownage_player(skill: int) -> int
│   │   │   ├── func get_kill_percentage_scale(skill: int) -> float
│   │   │   ├── func get_assist_percentage_scale(skill: int) -> float
│   │   │   ├── func get_assist_award_percentage_scale(skill: int) -> float
│   │   │   ├── func get_repair_penalty(skill: int) -> int
│   │   │   ├── func get_delay_bomb_arm_timer(skill: int) -> float
│   │   │   ├── func has_flag(flag: int) -> bool
│   │   │   └── func has_flag2(flag: int) -> bool
│   │   ├── armor_data.gd            # Defines damage resistances
│   │   │   ├── func get_damage_multiplier(damage_type_key) -> float
│   │   │   ├── func get_shield_pierce_percentage(damage_type_key) -> float
│   │   │   ├── func get_piercing_type(damage_type_key) -> int
│   │   │   └── func get_piercing_limit(damage_type_key) -> float
│   │   ├── game_sounds.gd           # Defines sound/music entries and manages playback
│   │   │   ├── func play_sound(sound: SoundEntry, position: Vector3 = Vector3.ZERO) -> AudioStreamPlayer3D
│   │   │   ├── func play_interface_sound(sound: SoundEntry) -> AudioStreamPlayer3D
│   │   │   ├── func stop_sound(player: AudioStreamPlayer3D) -> void
│   │   │   ├── func stop_all_sounds() -> void
│   │   │   ├── func preload_sounds() -> void
│   │   │   └── func unload_sounds() -> void
│   │   ├── kill_info.gd             # Tracks kill statistics
│   │   ├── medal_info.gd            # Defines medal/badge information
│   │   │   └── func get_bitmap_filename(award_count: int = 1) -> String
│   │   ├── music_entry.gd           # Defines music track properties
│   │   │   ├── func preload_music() -> void
│   │   │   └── func unload_music() -> void
│   │   ├── pilot_tips.gd            # Holds pilot tips
│   │   ├── player_data.gd           # Defines player profile data (PilotData)
│   │   │   ├── func get_rank_name() -> String
│   │   │   ├── func get_stat(stat_enum) -> int
│   │   │   ├── func update_stat(stat_enum, value: int)
│   │   │   ├── func add_kill(ship_class_index: int)
│   │   │   └── func add_assist()
│   │   ├── rank_info.gd             # Defines rank information
│   │   ├── ship_data.gd             # Defines static ship properties
│   │   ├── sound_entry.gd           # Defines sound effect properties
│   │   │   ├── func preload_sound() -> void
│   │   │   └── func unload_sound() -> void
│   │   ├── species_info.gd          # Defines species-specific properties
│   │   ├── subsystem.gd             # Base class/data for runtime subsystem state (Note: Redundant?)
│   │   ├── subsystem_definition.gd  # Defines static subsystem properties (used within ShipData)
│   │   ├── support_info.gd          # Tracks support ship status
│   │   ├── threat.gd                # Defines threat information
│   │   ├── weapon_data.gd           # Defines static weapon properties
│   │   ├── weapon_group.gd          # Defines weapon group state (ammo, linking)
│   │   ├── wingman.gd               # Defines wingman status and orders
│   │   ├── model_metadata.gd        # Defines ModelMetadata resource structure and helper methods
│   │   ├── mission_data.gd          # Defines MissionData resource structure (and related mission sub-resources) and helper methods
│   │   ├── hud_config_data.gd       # Defines HUDConfigData resource structure (and related HUD sub-resources) and helper methods
│   │   ├── music_track.gd           # Defines MusicTrack resource structure and helper methods
│   │   ├── subtitle_data.gd         # Defines SubtitleData resource structure and helper methods
│   │   ├── nav_point_data.gd        # Defines NavPointData resource structure and helper methods
│   │   ├── sexp_node.gd             # Defines SexpNode resource structure (if using Resource for SEXP) and helper methods
│   │   ├── campaign_data.gd         # Defines CampaignData resource structure and helper methods
│   │   ├── campaign_save_data.gd    # Defines CampaignSaveData resource structure and helper methods
│   │   └── mission_log_entry.gd     # Defines MissionLogEntry resource structure and helper methods
│   └── globals/            # Autoloaded global scripts (singletons like GameSettings, InputManager, MathUtils, etc.)
│       ├── game_settings.gd         # Holds global game settings (difficulty, detail levels) script
│       ├── input_manager.gd         # Optional: Central input constants or complex handling script
│       ├── math_utils.gd            # Static helper functions for math operations script
│       ├── global_constants.gd      # Defines global enums and constants script
│       │   ├── static func load_resource_lists()
│       │   ├── static func get_weapon_data(index: int) -> WeaponData
│       │   ├── static func get_ship_data(index: int) -> ShipData
│       │   └── static func get_armor_data(index: int) -> ArmorData
│       ├── game_sounds.gd           # Autoload holding sound references/data script
│       ├── music_data.gd            # Autoload holding music references/data script
│       ├── script_system.gd         # Autoload for hook system management script
│       └── script_encryption.gd     # Autoload for encryption utilities script
├── shaders/                # Godot Shading Language files (.gdshader) (See 14_graphics.md)
│   ├── model_base.gdshader # Base shader for ships/objects (lighting, textures, damage?)
│   ├── shield_impact.gdshader # Shader for shield hit effect visuals
│   ├── cloak.gdshader        # Shader for cloaking effect visuals
│   ├── engine_wash.gdshader  # Shader for engine wash/trail effect visuals
│   ├── nebula.gdshader       # Shader for rendering nebula effects visuals
│   ├── starfield.gdshader    # Shader for rendering the starfield background visuals
│   ├── hud_static.gdshader   # Shader for HUD static/distortion effect visuals
│   ├── wireframe.gdshader    # Shader for wireframe rendering mode visuals
│   └── ...                   # Other custom shaders
└── project.godot           # Main Godot project configuration file
