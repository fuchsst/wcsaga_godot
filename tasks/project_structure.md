# Godot Project Structure for Wing Commander Saga Conversion

This document outlines the target directory and file structure for the Godot project, based on the component analysis.

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
│   │   ├── autopilot_config.tres # Global autopilot settings (link distance, messages) (Defined by scripts/resources/autopilot/autopilot_config.gd)
│   │   └── nav_points/     # NavPointData resources (.tres) per mission - Defines navigation targets (Defined by scripts/resources/autopilot/nav_point_data.gd)
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
│   ├── messages/           # MessageData, PersonaData resources (.tres) - Global or Mission-specific (See 07_mission_system.md)
│   │   ├── personas/
│   │   └── mission_messages/
│   ├── model_metadata/     # ModelMetadata resources (.tres) - Stores POF metadata (points, subsystems) per model (See 11_model.md)
│   ├── scripting/          # Scripting system resources (See 08_scripting.md)
│   │   ├── sexp_operators.tres # (Optional) Resource defining SEXP operator signatures/validation rules
│   │   └── script_hooks.tres # (Optional) Resource defining GDScript hooks (if not hardcoded)
│   ├── ships/              # ShipData resources (.tres) - Defines static ship properties (from ships.tbl) (See 05_ship_weapon_systems.md)
│   ├── sounds/             # (Potentially merged into game_data/game_sounds.tres) SoundEntry resources (See 13_sound_and_animation.md)
│   ├── subtitles/          # Subtitle resources (See 12_controls_and_camera.md)
│   │   └── mission_x_sub_1.tres # Example SubtitleData resource instance (Defined by scripts/resources/subtitles/subtitle_data.gd)
│   └── weapons/            # WeaponData resources (.tres) - Defines static weapon properties (from weapons.tbl) (See 05_ship_weapon_systems.md)
├── scenes/                 # Scene files (.tscn) - Instantiable game elements and UI screens
│   ├── core/               # Core scenes (e.g., main game loop, manager nodes) (See 04_core_systems.md)
│   │   ├── game_manager.tscn        # Main game state and loop integration node
│   │   ├── object_manager.tscn      # Object tracking node
│   │   ├── script_system.tscn       # Node for ScriptSystem singleton logic (if needed)
│   │   ├── game_sequence_manager.tscn # Game state machine node
│   │   ├── scoring_manager.tscn     # Scoring/stats management node
│   │   ├── species_manager.tscn     # Species data management node
│   │   # camera_manager, subtitle_manager, autopilot_manager are Autoloads, no scenes needed
│   │   ├── message_manager.tscn     # Node for MessageManager singleton logic (See 07_mission_system.md)
│   │   ├── mission_log_manager.tscn # Node for MissionLogManager singleton logic (See 07_mission_system.md)
│   │   ├── mission_manager.tscn     # Node for MissionManager singleton logic (See 07_mission_system.md)
│   │   ├── campaign_manager.tscn    # Node for CampaignManager singleton logic (See 07_mission_system.md)
│   │   └── skybox.tscn         # Scene containing starfield/nebula setup (Created/Updated) (See 10_physics_and_space.md, 14_graphics.md)
│   ├── effects/            # Reusable effect scenes (explosions, trails, beams, particles, decals, warp) (Created directory) (See 05_ship_weapon_systems.md, 10_physics_and_space.md)
│   │   ├── explosion_medium.tscn # (Placeholder) Medium explosion effect scene
│   │   ├── shield_impact.tscn    # (Placeholder) Shield hit visual effect scene
│   │   ├── muzzle_flash.tscn     # (Placeholder) Weapon muzzle flash effect scene
│   │   ├── shockwave.tscn        # (Placeholder) Shockwave visual effect scene
│   │   ├── warp_effect.tscn      # (Placeholder) Warp in/out visual effect scene
│   │   ├── spark_effect.tscn     # (Placeholder) Damage spark effect scene
│   │   ├── debris_hull.tscn      # (Placeholder) Large ship debris piece scene
│   │   ├── debris_small.tscn     # (Placeholder) Small debris piece scene
│   │   ├── laser_hit.tscn        # (Placeholder) Laser impact effect scene
│   │   └── beam_effect.tscn      # Beam weapon visual effect scene (Created)
│   ├── gameplay/           # Main gameplay scenes (space flight environment)
│   │   └── space_flight.tscn   # (Placeholder) The primary scene for in-flight gameplay, containing player, environment, managers
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
│   │   │   │   └── hud_directives_gauge.tscn # Specific gauge for training/mission directives
│   │   │   ├── effects/        # (hud_static_overlay) HUD specific visual effects scenes
│   │   │   └── talking_head.tscn # Scene for displaying talking head animations (See 07_mission_system.md)
│   │   ├── mission_log/        # Mission log UI screen scene
│   │   │   └── mission_log_screen.tscn
│   │   ├── hotkey_screen/      # Hotkey assignment UI screen scene
│   │   │   └── hotkey_screen.tscn
│   │   ├── autopilot_message.tscn # UI for displaying autopilot messages (TODO)
│   │   └── subtitle_display.tscn  # UI Scene (CanvasLayer > MarginContainer > VBox > TextureRect + Label) for rendering a single subtitle. (See 12_controls_and_camera.md)
│   └── utility/            # Helper scenes (e.g., observer viewpoint, debug tools)
│       └── observer_viewpoint.tscn # Node3D scene, potentially with Camera3D child. (See 12_controls_and_camera.md)
├── scripts/                # GDScript files, organized by component
│   ├── ai/                 # AIController, AI behaviors, targeting, pathfinding, AIProfile script (See 01_ai.md)
│   │   ├── ai_controller.gd         # Main AI logic node, manages state, orchestrates BT/components.
│   │   │   ├── func set_mode(new_mode: AIConstants.AIMode, new_submode: int = 0) # Sets the AI's current mode and submode.
│   │   │   ├── func set_target(target_node: Node3D) # Sets the AI's current target object.
│   │   │   ├── func set_targeted_subsystem(subsystem: Node, parent_id: int) # Sets the specific subsystem to target on the current target object.
│   │   │   ├── func add_goal(goal: AIGoal) # Adds a goal to the AI's goal queue via the AIGoalManager.
│   │   │   ├── func clear_goals() # Clears all goals for this AI via the AIGoalManager.
│   │   │   ├── func has_flag(flag: int) -> bool # Checks if a specific AIF_* flag is set.
│   │   │   ├── func set_flag(flag: int, value: bool) # Sets or clears a specific AIF_* flag.
│   │   │   └── func get_target_position() -> Vector3 # Gets the global position of the current target (or targeted subsystem).
│   │   ├── perception_component.gd  # Handles sensing environment, targets, threats.
│   │   │   ├── func update_perception(delta: float) # Main update loop for perception tasks.
│   │   │   └── func is_ignore_object(check_target_id: int) -> bool # Checks if a target ID is on the ignore list.
│   │   ├── ai_goal_manager.gd     # Manages the AI goal queue, prioritization, and selection.
│   │   │   ├── func add_goal(controller: AIController, new_goal: AIGoal) -> bool # Adds a new goal to the queue.
│   │   │   ├── func remove_goal(controller: AIController, goal_signature: int) # Removes a goal by its signature.
│   │   │   ├── func clear_goals(controller: AIController) # Removes all goals for the AI.
│   │   │   ├── func get_active_goal() -> AIGoal # Returns the currently active goal resource.
│   │   │   └── func process_goals(controller: AIController) # Validates, sorts, and activates the highest priority achievable goal.
│   │   ├── ai_state_machine.gd    # (Optional) State machine implementation (or use LimboAI BTState)
│   │   ├── ai_behavior_tree.gd    # (Optional) Base/helper for LimboAI BehaviorTree resources
│   │   ├── ai_blackboard.gd       # (Optional) LimboAI blackboard resource script
│   │   ├── behaviors/           # LimboAI action/condition scripts defining specific behaviors.
│   │   │   ├── approach_target.gd   # BTAction: Steers towards target position.
│   │   │   │   └── func _tick() -> Status # Executes the approach logic each frame.
│   │   │   ├── chase_target.gd      # BTAction: Basic chase movement towards target.
│   │   │   │   └── func _tick() -> Status # Executes the chase logic each frame.
│   │   │   ├── deploy_countermeasure.gd # BTAction: Triggers countermeasure deployment.
│   │   │   │   └── func _tick() -> Status # Sets the deploy flag on the blackboard.
│   │   │   ├── fire_primary.gd      # BTAction: Triggers primary weapon fire.
│   │   │   │   └── func _tick() -> Status # Sets the fire flag on the blackboard.
│   │   │   ├── has_target.gd        # BTCondition: Checks if AI has a target.
│   │   │   │   └── func _tick() -> Status # Reads 'has_target' from blackboard.
│   │   │   ├── is_missile_locked.gd # BTCondition: Checks if AI is locked by a missile.
│   │   │   │   └── func _tick() -> Status # Reads 'is_missile_locked' from blackboard.
│   │   │   ├── is_target_in_range.gd # BTCondition: Checks if target is within weapon range.
│   │   │   │   └── func _tick() -> Status # Reads target distance and compares to weapon range.
│   │   │   ├── select_primary_weapon.gd # BTAction: Selects primary weapon bank based on target/situation.
│   │   │   │   └── func _tick() -> Status # Calls ship's 'set_selected_primary_bank_ai'.
│   │   │   ├── select_secondary_weapon.gd # BTAction: Selects secondary weapon bank based on target/situation.
│   │   │   │   └── func _tick() -> Status # Calls ship's 'set_selected_secondary_bank_ai'.
│   │   │   └── should_deploy_countermeasure.gd # BTCondition: Checks if countermeasures should be deployed based on lock, cooldown, and skill.
│   │   │       └── func _tick() -> Status # Performs the check.
│   │   ├── navigation/          # (Placeholder) Navigation related scripts (path_follower, collision_avoidance)
│   │   ├── targeting/           # (Placeholder) Targeting related scripts (targeting_system, stealth_detector)
│   │   └── turret/              # Turret specific AI scripts
│   │       └── turret_ai.gd     # Manages independent AI logic for a turret subsystem.
│   │           └── func _physics_process(delta: float) # Main update loop for turret AI.
│   ├── core_systems/       # GameManager, ObjectManager, GameSequenceManager, PlayerData, ScoringManager, etc. (See 04_core_systems.md)
│   │   ├── game_manager.gd          # Main game state, loop integration, time, pausing logic
│   │   │   ├── func pause_game() # Pauses the game tree.
│   │   │   ├── func unpause_game() # Unpauses the game tree.
│   │   │   ├── func toggle_pause() # Toggles the pause state.
│   │   │   ├── func set_time_compression(factor: float) # Sets Engine.time_scale.
│   │   │   ├── func get_time_compression() -> float # Gets Engine.time_scale.
│   │   │   ├── func get_mission_time() -> float # Gets the current mission time.
│   │   │   └── func reset_mission_time() # Resets mission time to zero.
│   │   ├── object_manager.gd        # Object tracking, lookup by signature/ID logic
│   │   │   ├── func register_object(obj: Node, signature: int = -1) # Adds an object to the manager.
│   │   │   ├── func unregister_object(obj: Node) # Removes an object from the manager.
│   │   │   ├── func get_object_by_id(id: int) -> Node # Finds an object by its instance ID.
│   │   │   ├── func get_object_by_signature(signature: int) -> Node # Finds an object by its signature.
│   │   │   ├── func get_all_ships() -> Array[Node] # Returns all registered ships.
│   │   │   ├── func get_all_weapons() -> Array[Node] # Returns all registered weapons.
│   │   │   ├── func get_next_signature() -> int # Generates a unique signature (Placeholder).
│   │   │   └── func clear_all_objects() # Clears all tracked objects.
│   │   ├── base_object.gd           # Base script class for all game objects (ships, weapons, etc.), incorporating logic from C++ object.cpp
│   │   │   ├── func get_object_type() -> GlobalConstants.ObjectType # Returns the object's type enum.
│   │   │   ├── func get_signature() -> int # Returns the object's unique signature.
│   │   │   ├── func set_flag(flag: int) # Sets an object flag (OF_*).
│   │   │   ├── func clear_flag(flag: int) # Clears an object flag.
│   │   │   ├── func has_flag(flag: int) -> bool # Checks if an object flag is set.
│   │   │   ├── func set_parent_object(parent_obj: Node) # Sets the parent object reference.
│   │   │   ├── func get_parent_object() -> Node # Gets the parent object node.
│   │   │   ├── func apply_damage(damage: float, source_pos: Vector3, source_obj: Node = null, damage_type_key = -1) # Virtual method for applying damage.
│   │   │   ├── func get_team() -> int # Virtual method to get team affiliation.
│   │   │   ├── func is_destroyed() -> bool # Virtual method to check if destroyed/dying.
│   │   │   ├── func is_arriving() -> bool # Virtual method to check if in arrival sequence.
│   │   │   ├── func assign_sound(sound_index: int, offset: Vector3 = Vector3.ZERO, is_main_engine: bool = false) -> int # Assigns a looping sound (Placeholder).
│   │   │   ├── func stop_sound(handle: int = -1) # Stops assigned sounds (Placeholder).
│   │   │   ├── func is_docked() -> bool # Checks if the object is docked.
│   │   │   └── func is_dead_docked() -> bool # Checks if the object is dead-docked.
│   │   ├── game_sequence_manager.gd # State machine logic for game states (menu, briefing, gameplay, etc.)
│   │   ├── scoring_manager.gd       # Scoring, rank, medal evaluation logic
│   │   ├── species_manager.gd       # Manages loading/accessing SpeciesInfo resources
│   │   ├── camera_manager.gd        # Autoload: Manages camera registration, switching, lookup logic (See 12_controls_and_camera.md)
│   │   │   # - func register_camera(...)
│   │   │   # - func set_active_camera(...)
│   │   │   # - func reset_to_default_camera()
│   │   │   # - func get_camera_by_name(...)
│   │   │   # - func set_camera_zoom(...) # Helper calling BaseCameraController
│   │   │   # - func set_camera_position(...) # Helper
│   │   │   # - func set_camera_rotation(...) # Helper
│   │   │   # - func set_camera_look_at(...) # Helper
│   │   │   # - func set_camera_host(...) # Helper
│   │   │   # - func set_camera_target(...) # Helper
│   │   ├── subtitle_manager.gd      # Autoload: Manages subtitle queue and display logic (See 12_controls_and_camera.md)
│   │   │   # - func queue_subtitle(subtitle_res: SubtitleData)
│   │   │   # - func queue_subtitle_params(...)
│   │   │   # - func clear_all()
│   │   │   # - func _process(delta) # Updates current subtitle display/timing
│   │   │   # - func _show_next_subtitle()
│   │   │   # - func _clear_current_subtitle()
│   │   ├── autopilot_manager.gd     # Autoload: Manages autopilot state, engagement, NavPoints, cinematics, linking, time compression. (See 12_controls_and_camera.md)
│   │   │   # - func start_autopilot()
│   │   │   # - func end_autopilot()
│   │   │   # - func can_autopilot(send_msg: bool = false) -> bool
│   │   │   # - func select_next_nav() -> bool
│   │   │   # - func toggle_autopilot()
│   │   │   # - func load_mission_nav_points(...)
│   │   │   # - func _process(delta) # Handles checks, updates
│   │   │   # - func _send_message(...)
│   │   │   # - func _check_autopilot_conditions()
│   │   │   # - func _update_standard_autopilot(delta)
│   │   │   # - func _update_cinematic_autopilot(delta)
│   │   │   # - func _setup_cinematic_autopilot()
│   │   │   # - func _warp_ships(prewarp: bool = false)
│   │   │   # - func _check_for_linking_ships()
│   │   │   # - func _check_nearby_objects(...)
│   │   │   # - func _set_autopilot_ai_goals(engage: bool)
│   │   ├── script_system.gd         # Autoload for hook system management script (See 08_scripting.md)
│   │   ├── message_manager.gd       # Singleton for message system logic (See 07_mission_system.md)
│   │   ├── mission_log_manager.gd   # Singleton for mission log logic (See 07_mission_system.md)
│   │   ├── mission_manager.gd       # Singleton for mission management logic (See 07_mission_system.md)
│   │   └── campaign_manager.gd      # Singleton for campaign management logic (See 07_mission_system.md)
│   ├── ship/                 # Ship logic and core components (See 05_ship_weapon_systems.md)
│   │   ├── ship_base.gd             # Base ship logic, physics integration, state management script, incorporating logic from C++ ship.cpp and model*.cpp
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
│   ├── player/               # Player specific scripts (See 04_core_systems.md, 12_controls_and_camera.md)
│   │   ├── player_ship_controller.gd # Handles player input mapping to ship actions script (Attached to player ship scene)
│   │   │   # - func _physics_process(delta) # Reads axes
│   │   │   # - func _unhandled_input(event) # Reads actions
│   │   │   # - func set_active(active: bool)
│   │   └── player_autopilot_controller.gd # AI controller used during autopilot (Attached to player ship scene)
│   │       # - func set_active(active: bool)
│   │       # - func set_target_nav_point(nav_point: NavPointData)
│   │       # - func set_speed_cap(cap: float)
│   │       # - func _physics_process(delta) # Uses NavigationAgent3D
│   ├── controls_camera/    # PlayerController, CameraController, Autopilot logic, Observer logic (See 12_controls_and_camera.md)
│   │   ├── base_camera_controller.gd # Attached to Camera3D: Base script for following, targeting, transitions.
│   │   │   # - func set_active(active: bool)
│   │   │   # - func set_object_host(...)
│   │   │   # - func set_object_target(...)
│   │   │   # - func set_zoom(...)
│   │   │   # - func set_position(...)
│   │   │   # - func set_rotation(...)
│   │   │   # - func set_rotation_facing(...)
│   │   │   # - func _physics_process(delta) # Handles following/targeting
│   │   │   # - func _interpolate_rotation(quat: Quaternion) # Tween callback
│   │   ├── cinematic_camera_controller.gd # Attached to Camera3D: Specific logic for cutscenes, AnimationPlayer interaction.
│   │   │   # - func play_animation(animation_name: String)
│   │   │   # - func stop_animation()
│   │   ├── autopilot_camera_controller.gd # Attached to Autopilot Camera: Logic for cinematic camera movement.
│   │   │   # - func set_instant_pose(pos: Vector3, look_at_target: Vector3)
│   │   │   # - func move_to_pose(target_pos: Vector3, target_look_at: Vector3, duration: float)
│   │   │   # - func look_at_target(target_pos: Vector3)
│   │   ├── warp_camera_controller.gd  # Attached to Camera3D: Logic for warp effect camera.
│   │   │   # - func start_warp_effect(player_obj: Node3D)
│   │   │   # - func stop_warp_effect()
│   │   │   # - func _physics_process(delta) # Custom physics movement
│   │   └── observer_viewpoint.gd    # Attached to observer_viewpoint.tscn: Script for observer viewpoint nodes.
│   │       # - func get_eye_transform() -> Transform3D
│   ├── ship/                 # Ship logic and core components (See 05_ship_weapon_systems.md) # Moved player scripts out
│   │   ├── ship_base.gd             # Base ship logic, physics integration, state management script, incorporating logic from C++ ship.cpp and model*.cpp
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
│   │   # Removed player_ship.gd from here
│   │   ├── weapon_system.gd         # Manages weapon banks, firing, energy/ammo logic script (Node within ShipBase scene)
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
│   │   └── subsystems/              # Subsystem logic scripts (Attached to subsystem nodes within ship scene)
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
│   │   ├── gauges/                  # Scripts for individual gauges
│   │   │   ├── hud_gauge_base.gd   # Base class for common gauge logic
│   │   │   ├── hud_attacking_count_gauge.gd
│   │   │   ├── hud_auto_gauges.gd
│   │   │   ├── hud_brackets.gd
│   │   │   ├── hud_cmeasure_gauge.gd
│   │   │   ├── hud_damage_gauge.gd
│   │   │   ├── hud_directives_gauge.gd
│   │   │   ├── hud_escort_gauge.gd
│   │   │   ├── hud_ets_gauge.gd
│   │   │   ├── hud_kills_gauge.gd
│   │   │   ├── hud_lag_gauge.gd
│   │   │   ├── hud_lead_indicator.gd
│   │   │   ├── hud_lock_gauge.gd
│   │   │   ├── hud_message_box_gauge.gd
│   │   │   ├── hud_message_gauge.gd
│   │   │   ├── hud_missile_warning_gauge.gd
│   │   │   ├── hud_mission_time_gauge.gd
│   │   │   ├── hud_objectives_notify_gauge.gd
│   │   │   ├── hud_offscreen_indicator_gauge.gd
│   │   │   ├── hud_offscreen_range_gauge.gd
│   │   │   ├── hud_radar_base.gd
│   │   │   ├── hud_radar_orb.gd
│   │   │   ├── hud_radar_standard.gd
│   │   │   ├── hud_reticle_gauge.gd
│   │   │   ├── hud_shield_gauge.gd
│   │   │   ├── hud_support_gauge.gd
│   │   │   ├── hud_talking_head_gauge.gd
│   │   │   ├── hud_target_mini_icon_gauge.gd
│   │   │   ├── hud_target_monitor.gd
│   │   │   ├── hud_text_flash_gauge.gd
│   │   │   ├── hud_threat_gauge.gd
│   │   │   ├── hud_throttle_gauge.gd
│   │   │   ├── hud_weapon_linking_gauge.gd
│   │   │   ├── hud_weapons_gauge.gd
│   │   │   ├── hud_wingman_gauge.gd
│   │   │   └── radar_blip.gd       # Class for radar blips
│   │   ├── effects/              # Scripts for HUD visual effects
│   │   │   ├── hud_shake_effect.gd
│   │   │   └── hud_static_overlay.gd
│   │   └── squad_message_manager.gd # Singleton for squad message logic
│   ├── mission_system/     # Mission logic, helpers, UI scripts (See 07_mission_system.md)
│   │   ├── mission_manager.gd       # Singleton: Orchestrates mission lifecycle, state. Delegates evaluation.
│   │   │   ├── func load_mission(path)
│   │   │   ├── func start_mission()
│   │   │   └── func end_mission()
│   │   ├── mission_event_manager.gd # Singleton/Node: Manages evaluation and state of mission events.
│   │   │   ├── func set_runtime_events(events_array)
│   │   │   ├── func evaluate_events(delta)
│   │   │   └── func clear_runtime_events()
│   │   ├── mission_goal_manager.gd  # Singleton/Node: Manages evaluation and state of mission goals.
│   │   │   ├── func set_runtime_goals(goals_array)
│   │   │   ├── func evaluate_goals(delta)
│   │   │   ├── func evaluate_primary_goals_status() -> int
│   │   │   ├── func mission_goals_met() -> bool
│   │   │   ├── func fail_incomplete_goals()
│   │   │   ├── func invalidate_goal(name)
│   │   │   ├── func validate_goal(name)
│   │   │   └── func clear_runtime_goals()
│   │   ├── arrival_departure.gd     # Node/Helper: Handles arrival/departure logic and timing script.
│   │   │   ├── func set_managers(m_manager, s_manager)
│   │   │   └── func update_arrivals_departures(delta)
│   │   ├── spawn_manager.gd         # Node/Helper: Handles instantiating ships/wings script.
│   │   │   ├── func spawn_ship(ship_data) -> Node3D
│   │   │   └── func spawn_wing_wave(wing_data, wave_num, num_to_spawn) -> Array[Node3D]
│   │   ├── mission_loader.gd        # Helper: Loads MissionData resources script.
│   │   │   └── static func load_mission(path) -> MissionData
│   │   ├── briefing/                # Briefing system scripts
│   │   │   ├── briefing_screen.gd   # Main briefing UI logic
│   │   │   │   └── func _load_stage(index)
│   │   │   ├── briefing_map_manager.gd # Handles 3D map display
│   │   │   │   └── func set_stage_data(stage_data)
│   │   │   └── briefing_icon.gd     # Represents a single map icon
│   │   │       ├── func setup(data)
│   │   │       └── func update_data(data)
│   │   ├── debriefing/              # Debriefing system scripts
│   │   │   ├── debriefing_screen.gd # Main debriefing UI logic
│   │   │   │   └── func _load_stage(index)
│   │   │   └── scoring_system.gd    # (Optional) Handles score calculation, medal logic
│   │   ├── log/                     # Mission Log scripts
│   │   │   └── mission_log_manager.gd # Singleton for managing log entries
│   │   │       ├── func clear_log()
│   │   │       ├── func add_entry(...)
│   │   │       ├── func get_all_entries() -> Array[MissionLogEntry]
│   │   │       ├── func get_entry_time(...) -> float
│   │   │       └── func get_entry_count(...) -> int
│   │   ├── message_system/          # Message system scripts
│   │   │   └── message_manager.gd     # Singleton for managing messages
│   │   │       ├── func load_mission_messages(mission_data)
│   │   │       ├── func queue_message(...)
│   │   │       ├── func send_unique_to_player(...)
│   │   │       ├── func send_builtin_to_player(...)
│   │   │       └── func kill_all_playing_messages(...)
│   │   ├── training_system/         # Training system scripts
│   │   │   └── training_manager.gd    # Singleton or part of MissionManager
│   │   │       ├── func mission_init()
│   │   │       ├── func mission_shutdown()
│   │   │       ├── func fail_training()
│   │   │       └── func queue_training_message(...)
│   │   └── hotkey/                  # Mission Hotkey scripts
│   │       └── mission_hotkey_manager.gd # Singleton or part of PlayerData
│   │           ├── func clear_hotkey_set(set_index)
│   │           ├── func clear_all_hotkeys()
│   │           ├── func assign_remove_hotkey(set_index, target_node)
│   │           ├── func apply_mission_defaults(mission_data)
│   │           ├── func get_targets_for_set(set_index) -> Array[int]
│   │           ├── func get_hotkey_flags_for_target(sig) -> int
│   │           ├── func get_save_data() -> Dictionary
│   │           └── func load_save_data(data)
│   ├── scripting/          # SEXP evaluation and Hook system runtime logic (See 08_scripting.md)
│   │   ├── sexp/                    # SEXP system implementation
│   │   │   ├── sexp_constants.gd    # Defines SEXP system constants (OP_*, SEXP_*, etc.).
│   │   │   ├── sexp_node.gd         # Resource representing a node in the SEXP tree (list or atom).
│   │   │   │   ├── func is_list() -> bool # Checks if the node is a list.
│   │   │   │   ├── func is_atom() -> bool # Checks if the node is an atom.
│   │   │   │   ├── func is_operator() -> bool # Checks if the node is an operator atom.
│   │   │   │   ├── func is_number() -> bool # Checks if the node is a number atom.
│   │   │   │   ├── func is_string() -> bool # Checks if the node is a string atom.
│   │   │   │   ├── func get_operator() -> int # Returns the operator code if it's an operator atom.
│   │   │   │   ├── func get_number_value() -> float # Returns the float value if it's a number atom.
│   │   │   │   ├── func get_string_value() -> String # Returns the string value if it's a string atom.
│   │   │   │   ├── func get_child_count() -> int # Returns the number of children if it's a list.
│   │   │   │   └── func get_child(index: int) -> SexpNode # Returns the child node at the given index.
│   │   │   ├── sexp_evaluator.gd    # Evaluates parsed SexpNode trees, calling operator handlers.
│   │   │   │   ├── func eval_sexp(node: SexpNode, context: Dictionary) -> Variant # Evaluates a node and returns its result.
│   │   │   │   └── func is_sexp_true(node: SexpNode, context: Dictionary) -> bool # Evaluates a node for a boolean result based on FS2 rules.
│   │   │   ├── sexp_operators.gd    # Autoload Singleton: Handles execution of individual SEXP operators.
│   │   │   │   └── func get_operator_handler(op_code: int) -> Callable # Returns the handler function for a given operator code.
│   │   │   └── sexp_variables.gd    # Autoload Singleton: Manages SEXP variables (@variable_name) and persistence.
│   │   │       ├── func clear_mission_variables() -> void # Clears mission-local variables.
│   │   │       ├── func clear_campaign_variables() -> void # Clears campaign-persistent variables.
│   │   │       ├── func clear_player_variables() -> void # Clears player-persistent variables.
│   │   │       ├── func set_variable(var_name: String, value: Variant, type_flags: int) -> void # Sets a variable's value and persistence.
│   │   │       ├── func get_variable(var_name: String) -> Variant # Gets a variable's value, checking persistence levels.
│   │   │       ├── func get_variable_type_flags(var_name: String) -> int # Gets a variable's type and persistence flags.
│   │   │       └── func has_variable(var_name: String) -> bool # Checks if a variable exists.
│   │   └── hook_system/             # Hook system implementation
│   │       ├── script_state.gd      # Manages ConditionedHooks and triggers execution based on game events.
│   │       │   ├── func add_conditioned_hook(hook: ConditionedHook) -> void # Adds a hook resource.
│   │       │   ├── func clear_all_hooks() -> void # Clears all loaded hooks.
│   │       │   ├── func run_condition(action_type: GlobalConstants.HookActionType, context: Dictionary) -> void # Runs hooks matching the action type if conditions are met.
│   │       │   ├── func is_condition_override(action_type: GlobalConstants.HookActionType, context: Dictionary) -> bool # Checks if any matching hook overrides default behavior.
│   │       │   └── func load_hooks_from_data(hook_data) -> void # Placeholder for loading hook definitions.
│   │       ├── conditioned_hook.gd  # Resource: Groups conditions and actions for a hook.
│   │       │   ├── func are_conditions_valid(context: Dictionary) -> bool # Checks if all conditions are met.
│   │       │   ├── func run_actions_for_type(action_type: GlobalConstants.HookActionType, context: Dictionary) -> void # Executes actions of a specific type if conditions are valid.
│   │       │   └── func check_override_for_type(action_type: GlobalConstants.HookActionType, context: Dictionary) -> bool # Checks if any action of a specific type overrides behavior.
│   │       ├── script_condition.gd  # Resource: Defines a single condition to be checked.
│   │       │   └── func is_valid(context: Dictionary) -> bool # Checks if this specific condition is met based on context.
│   │       ├── script_action.gd     # Resource: Links a game event type to an executable ScriptHook.
│   │       │   └── func is_valid() -> bool # Checks if the associated ScriptHook is valid.
│   │       └── script_hook.gd       # Resource: Represents an executable hook (GDScript function Callable).
│   │           ├── func is_valid() -> bool # Checks if the main hook callable is valid.
│   │           ├── func execute(context: Dictionary) -> Variant # Executes the main hook function.
│   │           └── func check_override(context: Dictionary) -> bool # Executes the override check function.
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
│   │   ├── mission_log/             # Mission log UI script
│   │   │   └── mission_log_screen.gd
│   │   ├── hotkey_screen/           # Hotkey assignment UI script
│   │   │   └── hotkey_screen.gd
│   │   ├── components/              # Custom UI component scripts (wcsaga_button, wcsaga_listbox, etc.)
│   │   └── subtitle_display.gd      # Attached to subtitle_display.tscn: Script for the subtitle UI scene. (See 12_controls_and_camera.md)
│   │       # - func set_subtitle_data(subtitle: SubtitleData)
│   │       # - func update_display(subtitle: SubtitleData, alpha: float)
│   │       # - func clear_display()
│   │       # - func _apply_positioning()
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
│   ├── controls_camera/    # PlayerController, CameraController, Autopilot logic, Observer logic (See 12_controls_and_camera.md)
│   │   ├── base_camera_controller.gd # Attached to Camera3D: Base script for following, targeting, transitions.
│   │   │   # - func set_active(active: bool)
│   │   │   # - func set_object_host(...)
│   │   │   # - func set_object_target(...)
│   │   │   # - func set_zoom(...)
│   │   │   # - func set_position(...)
│   │   │   # - func set_rotation(...)
│   │   │   # - func set_rotation_facing(...)
│   │   │   # - func _physics_process(delta) # Handles following/targeting
│   │   │   # - func _interpolate_rotation(quat: Quaternion) # Tween callback
│   │   ├── cinematic_camera_controller.gd # Attached to Camera3D: Specific logic for cutscenes, AnimationPlayer interaction.
│   │   │   # - func play_animation(animation_name: String)
│   │   │   # - func stop_animation()
│   │   ├── autopilot_camera_controller.gd # Attached to Autopilot Camera: Logic for cinematic camera movement.
│   │   │   # - func set_instant_pose(pos: Vector3, look_at_target: Vector3)
│   │   │   # - func move_to_pose(target_pos: Vector3, target_look_at: Vector3, duration: float)
│   │   │   # - func look_at_target(target_pos: Vector3)
│   │   ├── warp_camera_controller.gd  # Attached to Camera3D: Logic for warp effect camera.
│   │   │   # - func start_warp_effect(player_obj: Node3D)
│   │   │   # - func stop_warp_effect()
│   │   │   # - func _physics_process(delta) # Custom physics movement
│   │   └── observer_viewpoint.gd    # Attached to observer_viewpoint.tscn: Script for observer viewpoint nodes.
│   │       # - func get_eye_transform() -> Transform3D
│   ├── sound_animation/    # SoundManager, MusicManager, custom animation players (e.g., ani_player_2d) (See 13_sound_and_animation.md)
│   │   ├── sound_manager.gd         # Singleton for managing sound playback logic
│   │   ├── music_manager.gd         # Singleton for managing event music logic
│   │   ├── ani_player_2d.gd         # Custom node/script for ANI playback logic
│   │   └── audio_bus_controller.gd  # Optional script for managing audio bus effects
│   │   ├── ani_player_2d.gd         # Custom node/script for ANI playback logic
│   │   └── audio_bus_controller.gd  # Optional script for managing audio bus effects
│   ├── graphics/           # Scripts related to graphics utilities or managing complex effects (Created directory) (See 14_graphics.md)
│   │   ├── graphics_utilities.gd    # Helper functions for graphics tasks script (Created - Placeholder)
│   │   ├── post_processing.gd       # Script for custom post-processing effects (Created - Placeholder)
│   │   ├── starfield_manager.gd     # (Placeholder) Manages starfield background script
│   │   ├── nebula_manager.gd        # (Placeholder) Manages nebula effects/fog script
│   │   ├── decal_manager.gd         # (Placeholder) Manages decal creation/lifetime script
│   │   ├── explosion_manager.gd     # (Placeholder) Manages explosion effects script
│   │   ├── shockwave_manager.gd     # (Placeholder) Manages shockwave effects script
│   │   ├── trail_manager.gd         # (Placeholder) Manages weapon trail effects script
│   │   ├── muzzle_flash_manager.gd  # (Placeholder) Manages muzzle flash effects script
│   │   ├── warp_effect_manager.gd   # (Placeholder) Manages warp visual effects script
│   │   ├── spark_manager.gd         # (Placeholder) Manages spark effects script
│   │   └── shaders/                 # Directory for .gdshader files (Created)
│   │       ├── model_base.gdshader  # Base shader for ships/objects (Created)
│   │       ├── nebula.gdshader      # Shader for nebula effects (Created)
│   │       ├── starfield.gdshader   # Shader for starfield background (Created)
│   │       ├── laser_beam.gdshader  # Shader for laser/beam effects (Created)
│   │       └── particle.gdshader    # (Placeholder) Custom particle shaders
│   ├── resources/          # Scripts defining custom Resource types (logic associated with .tres files)
│   │   ├── ai/
│   │   │   ├── ai_goal.gd           # Resource defining the structure for an AI goal.
│   │   │   │   ├── func is_valid() -> bool
│   │   │   │   ├── func set_flag(flag_enum: GoalFlags, value: bool)
│   │   │   │   ├── func has_flag(flag_enum: GoalFlags) -> bool
│   │   │   │   ├── func get_target_ship_name() -> String
│   │   │   │   ├── func get_target_wing_name() -> String
│   │   │   │   └── func get_target_waypoint_list_name() -> String
│   │   │   └── ai_profile.gd        # Resource defining static AI behavior parameters based on skill level.
│   │   │       ├── func get_accuracy(skill_level: int) -> float
│   │   │       ├── func get_evasion(skill_level: int) -> float
│   │   │       ├── func get_courage(skill_level: int) -> float
│   │   │       ├── func get_patience(skill_level: int) -> float
│   │   │       ├── func get_max_attackers(skill: int) -> int
│   │   │       ├── func get_predict_position_delay(skill: int) -> float
│   │   │       ├── func get_turn_time_scale(skill: int) -> float
│   │   │       ├── func get_cmeasure_fire_chance(skill: int) -> float
│   │   │       ├── func get_in_range_time(skill: int) -> float
│   │   │       ├── func get_link_ammo_levels_maybe(skill: int) -> float
│   │   │       ├── func get_link_ammo_levels_always(skill: int) -> float
│   │   │       ├── func get_primary_ammo_burst_mult(skill: int) -> float
│   │   │       ├── func get_link_energy_levels_maybe(skill: int) -> float
│   │   │       ├── func get_link_energy_levels_always(skill: int) -> float
│   │   │       ├── func get_shield_manage_delay(skill: int) -> float
│   │   │       ├── func get_ship_fire_delay_scale_friendly(skill: int) -> float
│   │   │       ├── func get_ship_fire_delay_scale_hostile(skill: int) -> float
│   │   │       ├── func get_ship_fire_secondary_delay_scale_friendly(skill: int) -> float
│   │   │       ├── func get_ship_fire_secondary_delay_scale_hostile(skill: int) -> float
│   │   │       ├── func get_glide_attack_percent(skill: int) -> float
│   │   │       ├── func get_circle_strafe_percent(skill: int) -> float
│   │   │       ├── func get_glide_strafe_percent(skill: int) -> float
│   │   │       ├── func get_stalemate_time_thresh(skill: int) -> float
│   │   │       ├── func get_stalemate_dist_thresh(skill: int) -> float
│   │   │       ├── func get_chance_to_use_missiles_on_plr(skill: int) -> int
│   │   │       ├── func get_max_aim_update_delay(skill: int) -> float
│   │   │       ├── func get_aburn_use_factor(skill: int) -> int
│   │   │       ├── func get_shockwave_evade_chance(skill: int) -> float
│   │   │       ├── func get_get_away_chance(skill: int) -> float
│   │   │       ├── func get_secondary_range_mult(skill: int) -> float
│   │   │       ├── func get_bump_range_mult(skill: int) -> float
│   │   │       ├── func get_afterburner_recharge_scale(skill: int) -> float
│   │   │       ├── func get_beam_friendly_damage_cap(skill: int) -> float
│   │   │       ├── func get_cmeasure_life_scale(skill: int) -> float
│   │   │       ├── func get_max_allowed_player_homers(skill: int) -> int
│   │   │       ├── func get_max_incoming_asteroids(skill: int) -> int
│   │   │       ├── func get_player_damage_scale(skill: int) -> float
│   │   │       ├── func get_subsys_damage_scale(skill: int) -> float
│   │   │       ├── func get_shield_energy_scale(skill: int) -> float
│   │   │       ├── func get_weapon_energy_scale(skill: int) -> float
│   │   │       ├── func get_max_turret_ownage_target(skill: int) -> int
│   │   │       ├── func get_max_turret_ownage_player(skill: int) -> int
│   │   │       ├── func get_kill_percentage_scale(skill: int) -> float
│   │   │       ├── func get_assist_percentage_scale(skill: int) -> float
│   │   │       ├── func get_assist_award_percentage_scale(skill: int) -> float
│   │   │       ├── func get_repair_penalty(skill: int) -> int
│   │   │       ├── func get_delay_bomb_arm_timer(skill: int) -> float
│   │   │       ├── func has_flag(flag: int) -> bool
│   │   │       └── func has_flag2(flag: int) -> bool
│   │   ├── autopilot/ # Autopilot resource definitions (See 12_controls_and_camera.md)
│   │   │   ├── autopilot_config.gd # Defines AutopilotConfig resource structure
│   │   │   │   # - func get_message(msg_id: MessageID) -> String
│   │   │   │   # - func get_sound(msg_id: MessageID) -> String
│   │   │   └── nav_point_data.gd # Defines NavPointData resource structure
│   │   │       # - func get_target_position() -> Vector3
│   │   │       # - func can_select() -> bool
│   │   │       # - func is_hidden() -> bool
│   │   │       # - func is_no_access() -> bool
│   │   │       # - func is_visited() -> bool
│   │   │       # - func set_visited(visited: bool)
│   │   ├── ship_weapon/
│   │   │   ├── armor_data.gd        # Defines damage resistances
│   │   │   │   ├── func get_damage_multiplier(damage_type_key) -> float
│   │   │   │   ├── func get_shield_pierce_percentage(damage_type_key) -> float
│   │   │   │   ├── func get_piercing_type(damage_type_key) -> int
│   │   │   │   └── func get_piercing_limit(damage_type_key) -> float
│   │   │   ├── ship_data.gd         # Defines static ship properties
│   │   │   ├── subsystem_definition.gd # Defines static subsystem properties (used within ShipData)
│   │   │   ├── subsystem.gd         # Base class/data for runtime subsystem state (Note: Redundant?)
│   │   │   ├── weapon_data.gd       # Defines static weapon properties
│   │   │   └── weapon_group.gd      # Defines weapon group state (ammo, linking)
│   │   ├── mission/
│   │   │   ├── alt_class_data.gd    # Defines an alternate ship class entry for dynamic assignment.
│   │   │   ├── briefing_data.gd     # Holds data for one team's briefing, containing multiple stages.
│   │   │   ├── briefing_icon_data.gd # Defines an icon displayed in a briefing stage.
│   │   │   ├── briefing_line_data.gd # Defines a line connecting two icons in a briefing stage.
│   │   │   ├── briefing_stage_data.gd # Defines a single stage within a mission briefing.
│   │   │   ├── debriefing_data.gd   # Holds data for one team's debriefing, containing multiple stages.
│   │   │   ├── debriefing_stage_data.gd # Defines a single stage within a mission debriefing.
│   │   │   ├── docking_pair_data.gd # Defines a pair of docking points for initial docking setup.
│   │   │   ├── message_data.gd      # Defines a single message entry.
│   │   │   ├── mission_data.gd      # Defines MissionData resource structure (and related mission sub-resources) and helper methods
│   │   │   ├── mission_event_data.gd # Defines a mission event triggered by a SEXP formula.
│   │   │   ├── mission_log_entry.gd # Defines the structure for a mission log entry.
│   │   │   ├── mission_objective_data.gd # Defines a mission objective (goal).
│   │   │   ├── persona_data.gd      # Defines a character persona for messages.
│   │   │   ├── player_start_data.gd # Defines starting ship choices and weapon pools for a specific team in a mission.
│   │   │   ├── reinforcement_data.gd # Defines a reinforcement unit.
│   │   │   ├── sexp_variable_data.gd # Defines an initial SEXP variable value for a mission.
│   │   │   ├── ship_instance_data.gd # Defines ShipInstanceData resource structure (part of MissionData)
│   │   │   ├── subsystem_status_data.gd # Defines initial status overrides for a ship subsystem in a mission.
│   │   │   ├── texture_replacement_data.gd # Defines a texture replacement for a specific ship instance in a mission.
│   │   │   ├── waypoint_list_data.gd # Holds a named list of waypoint positions.
│   │   │   └── wing_instance_data.gd # Defines WingInstanceData resource structure (part of MissionData)
│   │   ├── player/
│   │   │   ├── kill_info.gd         # Tracks kill statistics
│   │   │   ├── medal_info.gd        # Defines medal/badge information
│   │   │   │   └── func get_bitmap_filename(award_count: int = 1) -> String
│   │   │   ├── pilot_tips.gd        # Holds pilot tips
│   │   │   ├── player_data.gd       # Defines player profile data (PilotData)
│   │   │   │   ├── func get_rank_name() -> String
│   │   │   │   ├── func get_stat(stat_enum) -> int
│   │   │   │   ├── func update_stat(stat_enum, value: int)
│   │   │   │   ├── func add_kill(ship_class_index: int)
│   │   │   │   └── func add_assist()
│   │   │   ├── rank_info.gd         # Defines rank information
│   │   │   ├── support_info.gd      # Tracks support ship status
│   │   │   ├── threat.gd            # Defines threat information
│   │   │   └── wingman.gd           # Defines wingman status and orders
│   │   ├── game_data/
│   │   │   ├── game_sounds.gd       # Defines sound/music entries and manages playback
│   │   │   │   ├── func play_sound(sound: SoundEntry, position: Vector3 = Vector3.ZERO) -> AudioStreamPlayer3D
│   │   │   │   ├── func play_interface_sound(sound: SoundEntry) -> AudioStreamPlayer3D
│   │   │   │   ├── func stop_sound(player: AudioStreamPlayer3D) -> void
│   │   │   │   ├── func stop_all_sounds() -> void
│   │   │   │   ├── func preload_sounds() -> void
│   │   │   │   └── func unload_sounds() -> void
│   │   │   ├── music_entry.gd       # Defines music track properties
│   │   │   │   ├── func preload_music() -> void
│   │   │   │   └── func unload_music() -> void
│   │   │   ├── sound_entry.gd       # Defines sound effect properties
│   │   │   │   ├── func preload_sound() -> void
│   │   │   │   └── func unload_sound() -> void
│   │   │   └── species_info.gd      # Defines species-specific properties
│   │   ├── model_metadata.gd        # Defines ModelMetadata resource structure and helper methods
│   │   ├── hud_config_data.gd       # Defines HUDConfigData resource structure (and related HUD sub-resources) and helper methods
│   │   ├── music_track.gd           # Defines MusicTrack resource structure and helper methods
│   │   ├── graphics/                # Graphics-related resource definitions (Created directory)
│   │   │   ├── material_definition.gd # (Placeholder) Base script for material resources if needed beyond ShaderMaterial
│   │   │   └── environment_definition.gd # (Placeholder) Base script for environment resources if needed beyond WorldEnvironment
│   │   ├── subtitles/ # Subtitle resource definitions (See 12_controls_and_camera.md)
│   │   │   └── subtitle_data.gd     # Defines SubtitleData resource structure
│   │   │       # - func calculate_duration() -> float
│   │   # Removed nav_point_data.gd from here (moved to autopilot/)
│   │   ├── scripting/ # Scripting resource definitions moved here
│   │   │   ├── sexp_node.gd         # Defines SexpNode resource structure (if using Resource for SEXP) and helper methods
│   │   │   ├── conditioned_hook.gd  # Defines ConditionedHook resource structure (See 08_scripting.md)
│   │   │   ├── script_condition.gd  # Defines ScriptCondition resource structure (See 08_scripting.md)
│   │   │   ├── script_action.gd     # Defines ScriptAction resource structure (See 08_scripting.md)
│   │   │   └── script_hook.gd       # Defines ScriptHook resource structure (See 08_scripting.md)
│   │   ├── campaign/ # Campaign resource definitions moved here
│   │   │   ├── campaign_data.gd     # Defines CampaignData resource structure and helper methods
│   │   │   └── campaign_save_data.gd # Defines CampaignSaveData resource structure and helper methods
│   ├── campaign/             # Campaign system scripts (See 07_mission_system.md)
│   │   ├── campaign_parser.gd       # Helper script to load CampaignData resources
│   │   └── campaign_save_data.gd    # Script associated with CampaignSaveData resource (if needed)
│   └── globals/            # Autoloaded global scripts (singletons like GameSettings, InputManager, MathUtils, etc.)
│       ├── game_settings.gd         # Holds global game settings (difficulty, detail levels) script
│       ├── input_manager.gd         # Optional: Central input constants or complex handling script
│       ├── math_utils.gd            # Static helper functions for math operations script
│       ├── global_constants.gd      # Defines global enums (e.g., HookActionType, HookConditionType) and constants script
│       │   ├── static func load_resource_lists() # Placeholder
│       │   ├── static func get_weapon_data(index: int) -> WeaponData # Placeholder
│       │   ├── static func get_ship_data(index: int) -> ShipData # Placeholder
│       │   └── static func get_armor_data(index: int) -> ArmorData # Placeholder
│       ├── ai_constants.gd          # Defines AI-specific constants and enums (Modes, Submodes, Flags).
│       ├── game_sounds.gd           # Autoload holding sound references/data script
│       ├── music_data.gd            # Autoload holding music references/data script
│       └── script_encryption.gd     # **PLANNED/OPTIONAL** Autoload for encryption utilities script
├── shaders/                # Godot Shading Language files (.gdshader) (See 14_graphics.md)
│   ├── model_base.gdshader # Base shader for ships/objects (lighting, textures, damage?)
│   ├── shield_impact.gdshader # Shader for shield hit effect visuals
│   ├── cloak.gdshader        # Shader for cloaking effect visuals
│   ├── engine_wash.gdshader  # Shader for engine wash/trail effect visuals
│   ├── nebula.gdshader       # Shader for rendering nebula effects visuals (Created)
│   ├── starfield.gdshader    # Shader for rendering the starfield background visuals (Created)
│   ├── laser_beam.gdshader   # Shader for laser/beam effects (Created)
│   ├── hud_static.gdshader   # (Placeholder) Shader for HUD static/distortion effect visuals
│   ├── wireframe.gdshader    # (Placeholder) Shader for wireframe rendering mode visuals
│   └── particle.gdshader     # (Placeholder) Custom particle shaders
└── project.godot           # Main Godot project configuration file
