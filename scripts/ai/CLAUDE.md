# WCS AI & Behavior Systems Package

## Package Purpose
This package implements the AI & Behavior Systems for the WCS-Godot conversion project (EPIC-010). It provides intelligent AI behavior for ships, formation flying, combat tactics, and autopilot systems using modern behavior tree architecture while maintaining WCS's tactical depth and authenticity.

## Implementation Status: Navigation, Collision, Formation, Autopilot & Target Selection Complete (AI-001 through AI-009)
- ✅ **LimboAI Integration Setup**: Framework prepared for LimboAI addon integration (AI-001)
- ✅ **WCS Behavior Tree Base Classes**: Custom action and condition node base classes (AI-001)
- ✅ **AI Agent Framework**: Core WCSAIAgent class with performance monitoring (AI-001)
- ✅ **AI Manager System**: Central coordination and registration system (AI-001)
- ✅ **Performance Monitoring**: Comprehensive AI performance tracking and optimization (AI-001)
- ✅ **Basic Behavior Nodes**: MoveTo action and HasTarget condition examples (AI-001)
- ✅ **Navigation System**: Comprehensive waypoint navigation and path planning (AI-005)
- ✅ **Collision System**: Advanced collision detection and avoidance with predictive algorithms (AI-006)
- ✅ **Formation System**: Complete formation flying with 6 formation types and collision integration (AI-007)
- ✅ **Autopilot System**: Player assistance and automation with safety monitoring and UI integration (AI-008)
- ✅ **Target Selection & Prioritization**: Multi-factor threat assessment, tactical doctrine, formation coordination, and mission integration (AI-009)
- ✅ **Integration Testing**: Complete test suite for AI foundation, navigation, collision, formation, autopilot, and target selection components

## Key Classes

### WCSAIAgent
- **Purpose**: Core AI agent class that will extend LimboAI when addon is available
- **Type**: Node (will extend LimboAI)
- **Responsibility**: Individual ship AI coordination, personality management, behavior tree execution
- **Key Features**: Skill/aggression levels, formation coordination, performance monitoring, target management

### WCSBTAction / WCSBTCondition
- **Purpose**: Base classes for WCS-specific behavior tree nodes
- **Type**: Node classes (will extend BTAction/BTCondition)
- **Responsibility**: Common WCS AI functionality, performance tracking, helper methods
- **Key Features**: Ship controller integration, performance monitoring, WCS-specific utilities

### AIManager (Singleton)
- **Purpose**: Central AI coordination and management system
- **Type**: AutoLoad singleton
- **Responsibility**: AI agent registration, performance budgeting, global AI coordination
- **Key Features**: Agent lifecycle management, performance monitoring, team-based queries

### AIPerformanceMonitor
- **Purpose**: Individual AI agent performance tracking and optimization
- **Type**: Component class
- **Responsibility**: Frame time monitoring, action/condition timing, performance alerts
- **Key Features**: Microsecond precision timing, history tracking, performance warnings

### WCSCollisionDetector
- **Purpose**: Advanced collision detection system for AI ships with spatial optimization
- **Type**: Node3D class
- **Responsibility**: Real-time collision threat detection, spatial partitioning, performance monitoring
- **Key Features**: Predictive collision detection, threat assessment, multi-ship scaling optimization

### PredictiveCollisionSystem
- **Purpose**: Future collision prediction and safe corridor calculation
- **Type**: Node class
- **Responsibility**: Collision prediction with acceleration, avoidance option generation, safe path planning
- **Key Features**: Physics-based prediction, collision probability assessment, corridor generation

### CollisionAvoidanceIntegration
- **Purpose**: Unified coordination between collision detection and navigation systems
- **Type**: Node class
- **Responsibility**: Avoidance mode management, navigation rerouting, formation coordination
- **Key Features**: Multi-mode avoidance, priority management, formation integrity maintenance

### FormationManager
- **Purpose**: Central manager for AI formation flying and coordination
- **Type**: Node class
- **Responsibility**: Formation creation, member management, position calculations, integrity monitoring
- **Key Features**: 6 formation types (Diamond, Vic, Line Abreast, Column, Finger Four, Wall), dynamic adjustments, leader changes

### FormationPositionCalculator
- **Purpose**: Utility class for calculating formation positions and patterns
- **Type**: RefCounted class
- **Responsibility**: Position algorithms, optimal spacing, obstacle avoidance integration
- **Key Features**: Static calculation methods, formation validation, performance optimization

### FormationCollisionIntegration
- **Purpose**: Integration between formation flying and collision avoidance systems
- **Type**: Node class
- **Responsibility**: Formation-aware collision handling, coordinated avoidance, integrity preservation
- **Key Features**: 4 avoidance modes, threat assessment, automatic formation recovery

### AIBlackboard
- **Purpose**: Simple blackboard implementation for AI behavior trees
- **Type**: RefCounted class
- **Responsibility**: Key-value storage, data sharing between AI nodes, debugging support
- **Key Features**: History tracking, merge operations, debug information

### AutopilotManager
- **Purpose**: Central autopilot system for player assistance and automation
- **Type**: Node class
- **Responsibility**: Autopilot mode switching, control handoff, safety integration, squadron coordination
- **Key Features**: 6 autopilot modes, smooth transitions, emergency stop, performance tracking

### AutopilotSafetyMonitor
- **Purpose**: Safety monitoring system for autopilot operations
- **Type**: Node class
- **Responsibility**: Threat detection, collision prediction, emergency situation monitoring
- **Key Features**: 5 threat levels, predictive collision detection, automatic safety override

### SquadronAutopilotCoordinator
- **Purpose**: Coordinates autopilot operations for multiple player ships in formation
- **Type**: Node class
- **Responsibility**: Squadron formation management, coordinated navigation, multi-ship autopilot
- **Key Features**: 6 coordination modes, formation integrity monitoring, dynamic leadership

### PlayerInputIntegration
- **Purpose**: Manages seamless transitions between player control and autopilot
- **Type**: Node class
- **Responsibility**: Input monitoring, control blending, smooth handoffs, override detection
- **Key Features**: Input conflict detection, blended control modes, transition smoothing

### AutopilotUIIntegration
- **Purpose**: UI integration for autopilot system status and controls
- **Type**: Control class
- **Responsibility**: Status display, manual controls, visual feedback, threat warnings
- **Key Features**: Real-time status updates, threat indicators, control buttons, ETA display

### ThreatAssessmentSystem
- **Purpose**: Multi-factor threat assessment system for target selection
- **Type**: Node class
- **Responsibility**: Target evaluation, threat scoring, prioritization, target tracking
- **Key Features**: Distance/weapon/size/health factors, threat types, hysteresis, mission integration

### SelectTargetAction
- **Purpose**: Intelligent target selection behavior tree action
- **Type**: WCSBTAction
- **Responsibility**: Target selection based on role, doctrine, and coordination
- **Key Features**: 5 selection modes, role-specific targeting, formation coordination, line-of-sight checks

### SwitchTargetAction
- **Purpose**: Dynamic target switching with anti-thrashing protection
- **Type**: WCSBTAction
- **Responsibility**: Intelligent target switching based on changing conditions
- **Key Features**: Hysteresis, improvement thresholds, emergency switching, cooldown management

### ValidateTargetCondition
- **Purpose**: Target validation for behavior tree conditions
- **Type**: WCSBTCondition
- **Responsibility**: Multi-criteria target validation, real-time checks
- **Key Features**: 9 validation checks, caching, performance optimization, failure handling

### TacticalDoctrine
- **Purpose**: Ship role and mission-specific targeting doctrine
- **Type**: Node class
- **Responsibility**: Role-based targeting preferences, mission modifiers, engagement parameters
- **Key Features**: 8 ship roles, 8 mission types, threat type priorities, tactical behavior

### TargetCoordinator
- **Purpose**: Formation-aware target coordination and overlap prevention
- **Type**: Node class
- **Responsibility**: Target assignment, oversaturation prevention, formation coordination
- **Key Features**: 5 coordination modes, assignment tracking, conflict resolution, performance scaling

### MissionTargetIntegration
- **Purpose**: Mission objective and SEXP priority target integration
- **Type**: Node class
- **Responsibility**: Mission-driven targeting, SEXP integration, priority management
- **Key Features**: 7 target types, 5 priority levels, SEXP commands, escort/protection logic

## Usage Examples

### Creating an AI Agent
```gdscript
# Add WCSAIAgent to a ship
var ai_agent: WCSAIAgent = WCSAIAgent.new()
ship_node.add_child(ai_agent)

# Configure AI parameters
ai_agent.skill_level = 0.8
ai_agent.aggression_level = 0.6

# Set personality (when personality system is complete)
ai_agent.ai_personality = preload("res://resources/ai/personalities/veteran_pilot.tres")

# Register with AI manager
AIManager.register_ai_agent(ai_agent)
```

### Creating Custom Behavior Tree Nodes
```gdscript
# Custom action extending WCSBTAction
class_name AttackTargetAction
extends WCSBTAction

func execute_wcs_action(delta: float) -> int:
    var target: Node = get_current_target()
    if not target:
        return 0  # FAILURE
    
    # Move to attack position
    var attack_pos: Vector3 = calculate_attack_position(target)
    set_ship_target_position(attack_pos)
    
    # Fire weapons when in range
    if distance_to_target(target) < 500.0 and is_facing_target(target):
        fire_weapons()
    
    return 2  # RUNNING
```

### Formation Management
```gdscript
# Create formation with formation manager
var formation_manager: FormationManager = get_node("/root/AIManager/FormationManager")
var leader_ship: Node3D = get_node("LeaderShip")
var wingman1: Node3D = get_node("Wingman1")
var wingman2: Node3D = get_node("Wingman2")

# Create diamond formation
var formation_id: String = formation_manager.create_formation(
    leader_ship, 
    FormationManager.FormationType.DIAMOND, 
    120.0  # spacing
)

# Add wingmen to formation
formation_manager.add_ship_to_formation(formation_id, wingman1)
formation_manager.add_ship_to_formation(formation_id, wingman2)

# Check formation status
var integrity: float = formation_manager.get_formation_integrity(formation_id)
print("Formation integrity: ", integrity * 100.0, "%")

# Get formation position for ship
var target_pos: Vector3 = formation_manager.get_ship_formation_position(wingman1)
```

### Autopilot Usage
```gdscript
# Create autopilot manager for player ship
var autopilot_manager: AutopilotManager = AutopilotManager.new()
autopilot_manager.player_ship = player_ship
player_ship.add_child(autopilot_manager)

# Engage autopilot to single destination
var destination: Vector3 = Vector3(2000, 0, 1000)
var success: bool = autopilot_manager.engage_autopilot_to_position(destination)

# Engage autopilot along path
var path: Array[Vector3] = [Vector3(1000, 0, 0), Vector3(2000, 0, 0), Vector3(2000, 0, 1000)]
autopilot_manager.engage_autopilot_along_path(path, AutopilotManager.AutopilotMode.PATH_FOLLOWING)

# Create squadron autopilot
var squadron_coordinator: SquadronAutopilotCoordinator = SquadronAutopilotCoordinator.new()
var leader: Node3D = player_ship
var members: Array[Node3D] = [wingman1, wingman2]
var squadron_id: String = squadron_coordinator.create_squadron(leader, members, SquadronAutopilotCoordinator.CoordinationMode.LOOSE_FORMATION)

# Monitor autopilot status
var status: Dictionary = autopilot_manager.get_autopilot_status()
print("Autopilot mode: ", status.get("mode"))
print("ETA: ", status.get("eta_string"))
print("Distance remaining: ", status.get("distance_to_destination"))

# Safety monitoring
var safety_monitor: AutopilotSafetyMonitor = autopilot_manager.get_node("AutopilotSafetyMonitor")
if safety_monitor.has_active_threats():
    var threat_level: AutopilotSafetyMonitor.ThreatLevel = safety_monitor.get_highest_threat_level()
    print("Threat level: ", AutopilotSafetyMonitor.ThreatLevel.keys()[threat_level])
```

### Target Selection and Threat Assessment
```gdscript
# Create threat assessment system for AI ship
var threat_assessment: ThreatAssessmentSystem = ThreatAssessmentSystem.new()
threat_assessment.initialize_with_ai_agent(ai_ship)
ai_ship.add_child(threat_assessment)

# Add detected targets
for enemy in detected_enemies:
    threat_assessment.add_detected_target(enemy)

# Get highest priority target
var primary_target: Node3D = threat_assessment.get_highest_priority_target()

# Create target selector action
var target_selector: SelectTargetAction = SelectTargetAction.new()
target_selector.ai_agent = ai_ship
target_selector.selection_mode = SelectTargetAction.SelectionMode.ROLE_SPECIFIC
target_selector.search_radius = 3000.0

# Configure tactical doctrine
var tactical_doctrine: TacticalDoctrine = TacticalDoctrine.new()
tactical_doctrine.apply_doctrine_to_target_selector(
    target_selector,
    TacticalDoctrine.ShipRole.FIGHTER,
    TacticalDoctrine.MissionType.INTERCEPT
)

# Execute target selection
var result: int = target_selector.execute_wcs_action(delta)
```

### Formation-Coordinated Targeting
```gdscript
# Setup target coordinator for formation
var target_coordinator: TargetCoordinator = TargetCoordinator.new()
target_coordinator.coordination_mode = TargetCoordinator.CoordinationMode.FORMATION_COORDINATED
target_coordinator.max_attackers_per_target = 2

# Initialize with formation manager
target_coordinator.initialize_with_systems(formation_manager, threat_assessment, tactical_doctrine)

# Request coordinated target assignment
var assigned_target: Node3D = target_coordinator.request_target_assignment(fighter_ship)

# Check target assignment status
var assignment_info: Dictionary = target_coordinator.get_ship_target_assignment(fighter_ship)
print("Assigned target: ", assignment_info.get("target"))
print("Assignment type: ", assignment_info.get("assignment_type"))
```

### Mission Priority Targeting
```gdscript
# Setup mission target integration
var mission_integration: MissionTargetIntegration = MissionTargetIntegration.new()

# Add priority mission targets
mission_integration.add_mission_target(
    enemy_flagship,
    MissionTargetIntegration.MissionTargetType.PRIMARY_OBJECTIVE,
    MissionTargetIntegration.TargetPriority.CRITICAL,
    "destroy_flagship"
)

# Add escort target
mission_integration.add_mission_target(
    friendly_transport,
    MissionTargetIntegration.MissionTargetType.ESCORT_TARGET,
    MissionTargetIntegration.TargetPriority.HIGH
)

# Get mission-relevant targets
var mission_targets: Array[Dictionary] = mission_integration.get_mission_relevant_targets()

# Process SEXP target commands
mission_integration.process_sexp_target_command("set-target-priority", enemy_ace, {"priority": 2.5})

# Check if target is mission priority
if mission_integration.is_mission_priority_target(target):
    var priority_bonus: float = mission_integration.get_target_mission_priority(target)
    print("Mission priority bonus: ", priority_bonus)
```

### Dynamic Target Switching
```gdscript
# Create target switcher for dynamic battlefield adaptation
var target_switcher: SwitchTargetAction = SwitchTargetAction.new()
target_switcher.ai_agent = ai_ship
target_switcher.threat_improvement_threshold = 1.8  # Require 80% improvement to switch
target_switcher.enable_hysteresis(true, 0.2)  # 20% hysteresis to prevent thrashing

# Configure switching parameters
target_switcher.set_switch_parameters(2.0, 3.0, 0.3)  # improvement, cooldown, distance penalty

# Monitor for target switches
target_switcher.target_switched.connect(func(old_target: Node3D, new_target: Node3D, reason: String):
    print("Target switched from ", old_target.name, " to ", new_target.name, " reason: ", reason)
)

# Execute switch evaluation
var switch_result: int = target_switcher.execute_wcs_action(delta)
```

### Target Validation
```gdscript
# Create target validator condition
var target_validator: ValidateTargetCondition = ValidateTargetCondition.new()
target_validator.ai_agent = ai_ship

# Configure validation checks
target_validator.add_validation_check(ValidateTargetCondition.ValidationCheck.LINE_OF_SIGHT)
target_validator.add_validation_check(ValidateTargetCondition.ValidationCheck.WEAPON_RANGE)
target_validator.set_validation_parameters(3000.0, 2.0, 0.1)  # range, threat, health

# Validate current target
var is_target_valid: bool = target_validator.check_wcs_condition()

# Get validation debug info
var validation_info: Dictionary = target_validator.get_validation_debug_info()
print("Validation failures: ", validation_info.get("validation_failures"))
```

## Architecture Notes

### Design Decisions
1. **LimboAI Ready**: Framework designed to integrate with LimboAI when addon is properly installed
2. **Performance First**: Built-in performance monitoring and optimization from the start
3. **WCS Authenticity**: Helper methods and patterns that replicate WCS AI behavior
4. **Modular Design**: Separate components for different AI responsibilities
5. **Static Typing**: Full static typing throughout for performance and reliability

### C++ to Godot Mapping
- **C++ ai.cpp/aicode.cpp** → **WCSAIAgent + Behavior Trees**
- **C++ ai goals system** → **Behavior tree goal nodes and blackboard**
- **C++ formation flying** → **Formation manager + coordination signals**
- **C++ autopilot** → **Autopilot behavior trees + navigation actions**
- **C++ AI performance** → **AIPerformanceMonitor + LOD systems**
- **C++ target selection (aibig.cpp)** → **ThreatAssessmentSystem + SelectTargetAction**
- **C++ AI coordination** → **TargetCoordinator + formation integration**
- **C++ mission targeting** → **MissionTargetIntegration + SEXP commands**
- **C++ AI personalities** → **TacticalDoctrine + ship role behaviors**

### Performance Considerations
- **Frame Time Budgeting**: 5ms total AI budget per frame (configurable)
- **Performance Monitoring**: Microsecond-precision timing for all AI operations
- **LOD System Ready**: Framework supports distance-based AI complexity reduction
- **Efficient Updates**: Time-sliced AI decision making to maintain 60 FPS

## Integration Points

### Current Dependencies
- **Core Foundation**: WCSConstants, WCSPaths for AI configuration
- **Object System**: Ship controllers and physics integration
- **Performance**: Built-in monitoring and optimization systems

### Future Integration (Planned)
- **LimboAI Addon**: Full behavior tree editor and runtime integration
- **SEXP System**: Mission-driven AI goal and behavior modification
- **Ship/Combat Systems**: Weapon firing, damage response, ship capabilities
- **Formation System**: Advanced formation patterns and coordination
- **Mission System**: Objective-driven AI behavior and responses

## Testing Notes

### Test Coverage
- **AI Agent Lifecycle**: Creation, configuration, registration, cleanup
- **Performance Monitoring**: Timing accuracy, history management, alert systems
- **Behavior Tree Nodes**: Custom action and condition node functionality
- **Signal Systems**: Target acquisition, formation changes, state transitions
- **Integration**: Ship controller integration, manager coordination

### Test Structure
```
target/tests/
├── test_ai_integration.gd              # Comprehensive AI foundation tests
├── test_autopilot_systems.gd          # Autopilot system tests
├── test_autopilot_integration_simple.gd # Simplified autopilot tests
├── test_target_selection_systems.gd   # Target selection and threat assessment tests
├── test_target_selection_integration.gd # Integration tests for multi-target scenarios
└── scenes/tests/
    └── ai_integration_test.tscn        # Test scene with AI agent setup
```

### Running Tests
```bash
# Run AI tests specifically
export GODOT_BIN="/path/to/godot"
bash addons/gdUnit4/runtest.sh -a tests/test_ai_integration.gd

# Check syntax
godot --headless --check-only --script-editor=false --quit
```

## Implementation Deviations

### Intentional Changes from C++
1. **Behavior Trees**: Modern behavior tree architecture instead of C++ state machines
2. **Component System**: Node-based AI components instead of monolithic C++ classes
3. **Signal Communication**: Godot signals for AI coordination instead of C++ callbacks
4. **Performance Monitoring**: Built-in profiling instead of external tools
5. **Type Safety**: GDScript static typing prevents C++ pointer errors

### Justifications
- **Maintainability**: Behavior trees are easier to design, debug, and modify
- **Performance**: Godot's optimized signal system and node architecture
- **Debugging**: Built-in behavior tree visualization and debugging tools
- **Extensibility**: Easy to add new behaviors without recompiling

## Next Implementation Steps

### Story AI-002: AI Manager and Ship Controller Framework
- Enhanced AIManager with more sophisticated coordination
- Ship controller integration for movement and control
- AI personality system implementation
- Formation coordination framework

### Story AI-003: Basic Behavior Tree Infrastructure
- Complete behavior tree template library
- Behavior tree manager with pooling and optimization
- Custom WCS action/condition node library
- Debugging and visualization tools

### Story AI-004: AI Performance Monitoring System
- LOD system for AI complexity management
- Frame time budgeting and enforcement
- Performance analytics and reporting
- Automated performance regression testing

## Version Compatibility
- **Godot Version**: 4.4+ required for full static typing and signal support
- **LimboAI Version**: Compatible with latest LimboAI addon when installed
- **WCS Compatibility**: All AI behaviors maintain WCS tactical authenticity

## Critical Notes
This AI foundation is essential for all ship behavior in WCS-Godot. The framework is designed to support the complex, intelligent AI behaviors that make WCS combat engaging while leveraging modern behavior tree architecture for maintainability and extensibility.