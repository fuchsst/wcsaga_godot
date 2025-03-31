# Wing Commander Saga Godot - Package Diagram

This diagram illustrates the high-level package structure and dependencies for the Godot conversion project, based on the component analysis. Packages represent major functional areas, and components are key classes or sub-systems within those areas. Dependencies show the primary flow of interaction or data usage.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#2E86C1', 'primaryTextColor': '#FFFFFF', 'lineColor': '#5D6D7E', 'textColor': '#17202A', 'packageBkgColor': '#D6EAF8', 'packageTextColor': '#17202A'}}}%%
packageDiagram
    package "Game Foundation" {
        package "Core Systems" as Core {
            component "GameManager" # (04) Main loop, time, pause
            component "ObjectManager" # (04) Object tracking, lookup
            component "GameSequenceManager" # (04) Game state transitions (Menu, Briefing, Gameplay, etc.)
            component "PlayerData (Resource)" # (04) Player profile, stats, campaign progress
            component "ScoringManager" # (04) Rank, medals, scoring logic
            component "SpeciesManager" # (04) Species definitions (IFF defaults, debris textures)
            component "Globals" # (04) Constants, settings (GameSettings, GlobalConstants)
            component "Error Handling" # (04) Logging, Assertions (Wrappers around Godot functions)
        }

        package "Physics & Space" as Physics {
            component "SpacePhysics (Ship Integration)" # (10) Custom ship physics integrator (_integrate_forces)
            component "CollisionHandler" # (10, 11) Collision detection/response logic (Signals/Callbacks)
            component "AsteroidField" # (10) Asteroid generation & management
            component "DebrisManager" # (10) Debris creation & management
            component "JumpNodeManager" # (10) Jump node tracking & interaction
        }

        package "Scripting & Data" as Scripting {
            component "SEXPSystem" # (08) S-Expression evaluation logic
            component "SexpNode (Resource/Class)" # (08) SEXP tree node representation
            component "SexpVariableManager" # (08) SEXP variable handling (@vars)
            component "HookSystem (Signals)" # (08) Event-driven script execution (GDScript based)
            component "Table Parsers (Offline)" # (08) TBL to Resource/JSON converters
            component "Encryption" # (08) Data encryption utilities (for loading specific files if needed)
            component "Localization (Godot)" # (08) Uses Godot's TranslationServer, tr()
        }

        package "Model System" as Model {
            component "ModelData (Resource)" # (11) Static model properties (ShipData, WeaponData)
            component "ModelMetadata (Resource)" # (11) POF metadata (points, subsystems) per model
            component "Submodel Logic (AnimationPlayer)" # (11) Handles submodel rotations/state via AnimationPlayer & GDScript
        }

        package "Asset Pipeline (Offline)" as Assets {
            component "Asset Converters" # (03) Python tools for POF, ANI, FS2, TBL, etc.
            component "Resource Definitions" # (03) GDScript files defining custom Resource types (.gd)
            component "Godot Importers" # (03) Godot's built-in import settings
        }
    }

    package "Gameplay Logic" {
        package "Ship & Weapon Systems" as ShipWeapon {
            component "ShipBase (Scene/Script)" # (05) Core ship logic, state, physics body
            component "WeaponSystem (Node)" # (05) Manages ship weapons, firing, ammo
            component "ShieldSystem (Node)" # (05) Shield logic, quadrants, recharge
            component "DamageSystem (Node)" # (05) Damage application, hull/subsystem integrity
            component "EngineSystem (Node)" # (05) Afterburner, engine effects logic
            component "Subsystems (Turret, Engine, Sensor)" # (05) Nodes/Scripts for subsystem logic
            component "Projectiles (Scene/Script)" # (05) Weapon projectile logic (movement, homing, impact)
            component "WeaponData (Resource)" # (05) Static weapon properties
        }

        package "AI System" as AI {
            component "AIController (Node)" # (01) Main AI logic per ship, orchestrates components
            component "PerceptionComponent (Node)" # (01) Handles sensing, target finding, threat assessment
            component "BehaviorTree/StateMachine (LimboAI)" # (01) AI decision making structure (reads Blackboard)
            component "Blackboard (Resource)" # (01) Shared data between AIController and BT
            component "TargetingSystem (Node/Helper)" # (01) Target selection logic, aspect lock (Potentially part of Perception)
            component "Navigation (NavigationAgent3D)" # (01) Pathfinding, avoidance logic (Potentially separate component/node)
            component "GoalManager (Node/Helper)" # (01) AI objective handling (integrates with Mission goals)
            component "AIProfile (Resource)" # (01) AI behavior parameters
        }

        package "Mission System" as Mission {
            component "MissionManager (Singleton)" # (07) Orchestrates mission flow, state, events, goals
            component "MissionData (Resource)" # (07) Mission definition (ships, wings, events, goals, etc.)
            component "Event/Goal Logic" # (07) SEXP-driven events/objectives evaluation loop
            component "Arrival/Departure (Node/Helper)" # (07) Ship arrival/departure handling & timing
            component "SpawnManager (Node/Helper)" # (07) Instantiates ships/wings based on MissionData
            component "MessageManager (Singleton)" # (07) In-mission messages, voice, personas
            component "MissionLogManager (Singleton)" # (07) Records mission events
            component "TrainingManager (Singleton)" # (07) Handles training mission logic & directives
        }

        package "Campaign System" as Campaign {
            component "CampaignManager (Singleton)" # (07) Manages campaign progression, state
            component "CampaignData (Resource)" # (07) Campaign definition (mission sequence, branching)
            component "CampaignSaveData (Resource)" # (07) Persistent campaign state (variables, pools)
        }
    }

    package "Presentation Layer" {
        package "Graphics & Effects" as Graphics {
            component "RenderingServer (Godot)" # (14) Godot's rendering backend (Internal)
            component "WorldEnvironment" # (14) Global rendering settings (fog, sky, PPFX)
            component "Shaders (.gdshader)" # (14) Custom visual effects (shields, warp, nebula, etc.)
            component "Effect Managers (Explosion, Decal, etc.)" # (10, 14) Singletons managing effect instances
            component "StarfieldManager" # (10) Background starfield rendering/logic
            component "NebulaManager" # (10) Nebula effects/fog logic
            component "GPUParticles3D" # (10, 14) Node for particle effects
        }

        package "Sound & Animation" as SoundAnim {
            component "SoundManager (Singleton)" # (13) Manages SFX playback (2D/3D), channel limits
            component "MusicManager (Singleton)" # (13) Manages event-driven music playback
            component "AudioStreamPlayer(3D)" # (13) Godot nodes for sound playback
            component "AnimationPlayer" # (13) Godot node for model/UI animations
            component "AniPlayer2D (Custom Node)" # (13) Handles sprite animations playback logic
            component "GameSounds (Resource)" # (13) Sound definitions mapping
            component "MusicTracks (Resource)" # (13) Music definitions mapping
        }

        package "Controls & Camera" as ControlsCamera {
            component "Input (Godot Singleton)" # (12) Handles raw input events
            component "InputMap (Godot)" # (12) Maps inputs to actions
            component "PlayerController (Script)" # (12) Translates input actions to ship control signals/calls
            component "CameraManager (Singleton)" # (12) Manages camera views & transitions
            component "CameraController (Script)" # (12) Implements camera behaviors (follow, cinematic)
            component "AutopilotManager (Singleton)" # (12) Handles autopilot state & camera control requests
            component "SubtitleManager (Singleton)" # (12) Displays subtitles
        }

        package "UI System" as UI {
            package "Menu UI" as MenuUI {
                component "MainMenu (Scene)" # (09) Main menu screen logic
                component "OptionsMenu (Scene)" # (09) Options screen logic
                component "ReadyRoom (Scene)" # (09) Mission selection screen logic
                component "TechRoom (Scene)" # (09) Database screen logic
                component "ControlConfig (Scene)" # (09) Input binding screen logic
                component "PilotManagement (Scene)" # (09) Pilot profile screen logic
                component "PopupManager (Singleton)" # (09) Handles generic popups
                component "ContextHelp (Singleton)" # (09) Context-sensitive help logic
                component "UI Components (Button, List, etc.)" # (09) Reusable custom UI widget scenes/scripts
                component "Theme (Resource)" # (09) UI styling resource
            }
            package "HUD System" as HUD {
                component "HUDManager (Singleton)" # (06) Manages HUD configuration/state loading
                component "HUD (CanvasLayer Scene)" # (06) Main HUD container, instantiates gauges
                component "Gauges (Radar, Shield, Target, etc.)" # (06) Individual HUD element scenes/scripts
                component "SquadMessageManager (Singleton)" # (06) Handles squad comms menu logic
                component "HUDConfigData (Resource)" # (06) HUD layout definitions
            }
            package "Mission UI" as MissionUI {
                 component "BriefingScreen (Scene)" # (07) Briefing UI logic
                 component "DebriefingScreen (Scene)" # (07) Debriefing UI logic
                 component "CommandBriefScreen (Scene)" # (07) Command Briefing UI logic
                 component "ShipSelectScreen (Scene)" # (09) Mission ship selection UI logic
                 component "WeaponSelectScreen (Scene)" # (09) Mission weapon selection UI logic
                 component "MissionLogScreen (Scene)" # (07) Mission log display UI logic
                 component "HotkeyScreen (Scene)" # (07) Hotkey assignment UI logic
            }
        }
    }

    package "Development Tools" as DevTools {
        package "Mission Editor (GFRED)" as GFRED {
            component "EditorPlugin" # (02) Godot editor integration script
            component "Mission Editor UI (Scene)" # (02) Editor interface panels/windows
            component "FS2 Parser/Saver (Script)" # (02) Reads/writes mission files for editor
        }
    }

    %% Dependencies
    Core --> Physics : Provides Object State
    Core --> Scripting : Provides Game State Access
    Core --> Model : Uses Object Definitions
    Core --> Assets : Loads Core Resources (Settings, PlayerData)
    Core --> Campaign : Provides PlayerData

    Physics --> Core : Updates Object Transforms
    Physics --> ShipWeapon : Applies Forces, Reports Collisions
    Physics --> Graphics : Provides Data for Debris/Asteroid Rendering

    Scripting --> Core : Accesses Game State, Globals
    Scripting --> Mission : Evaluates Mission Logic
    Scripting --> Campaign : Evaluates Campaign Logic
    Scripting --> AI : Evaluates AI Conditions
    Scripting --> Assets : Uses Encryption (Potentially)

    Model --> Assets : Defines Asset Structure
    Model --> Graphics : Provides Mesh/Material Data

    ShipWeapon --> Core : Uses Managers, PlayerData, Species
    ShipWeapon --> Physics : Integrates Movement, Detects Collisions
    ShipWeapon --> Model : Uses Model/Metadata Resources
    ShipWeapon --> Graphics : Triggers Visual Effects
    ShipWeapon --> SoundAnim : Triggers Sound Effects
    ShipWeapon --> AI : Provides State, Receives Targeting
    ShipWeapon --> UI : Provides Data for HUD/TechRoom

    AI --> Core : Accesses Game State, Objects, PlayerData
    AI --> Physics : Controls Movement (via ShipWeapon)
    AI --> ShipWeapon : Controls Weapons, Targeting, Reads Status
    AI --> Mission : Receives Goals, Sends Messages
    AI --> Scripting : Uses Variables, Evaluates Conditions
    AI --> ControlsCamera : Engages Autopilot
    AI --> Core : Accesses ObjectManager, IFFManager
    AI --> Physics : Reads Object Transforms, Controls Movement (indirectly)

    Mission --> Core : Manages Game State, Objects, Scoring
    Mission --> ShipWeapon : Spawns Ships/Weapons
    Mission --> AI : Assigns Goals, Sends Messages
    Mission --> Scripting : Executes Mission Logic
    Mission --> UI : Displays Mission Info (Briefing, HUD, Log, Subtitles)
    Mission --> Campaign : Reports Results
    Mission --> SoundAnim : Triggers Music/Voice/SFX
    Mission --> Physics : Spawns Asteroids/Debris
    Mission --> ControlsCamera : Uses Subtitles

    Campaign --> Core : Manages Player Progress
    Campaign --> Mission : Provides Mission Sequence
    Campaign --> Scripting : Evaluates Branching

    Graphics --> Core : Renders Objects
    Graphics --> Model : Uses Mesh/Texture Data
    Graphics --> Physics : Renders Asteroids/Debris
    Graphics --> ShipWeapon : Renders Ships, Weapons, Effects
    Graphics --> SoundAnim : Coordinates Visuals/Sounds
    Graphics --> UI : Renders UI Elements

    SoundAnim --> Core : Attaches Sounds to Objects
    SoundAnim --> ShipWeapon : Plays Weapon/Engine/Impact Sounds
    SoundAnim --> Mission : Plays Music, Voice, Event Sounds
    SoundAnim --> UI : Plays Interface Sounds
    SoundAnim --> Graphics : Provides Sprite Animation Data

    ControlsCamera --> Core : Accesses Player State
    ControlsCamera --> ShipWeapon : Controls Player Ship
    ControlsCamera --> UI : Handles Input, Reads Config
    ControlsCamera --> AI : Engages Autopilot
    ControlsCamera --> Graphics : Controls Camera View
    ControlsCamera --> SoundAnim : Uses Subtitles

    UI --> Core : Accesses Game State, PlayerData, Scoring
    UI --> Mission : Displays Mission Info (Briefing, HUD, Log)
    UI --> Campaign : Displays Campaign Info
    UI --> ControlsCamera : Handles Input, Displays Config
    UI --> SoundAnim : Plays UI Sounds, Uses Subtitles
    UI --> ShipWeapon : Displays Ship/Weapon Info
    UI --> Graphics : Renders UI
    UI --> AI : Sends Squad Commands

    DevTools --> Mission : Reads/Writes MissionData
    DevTools --> Core : Uses Object Definitions
    DevTools --> Model : Uses Model Data
    DevTools --> Assets : Accesses Asset Info
    DevTools --> Scripting : Uses SEXP Definitions
