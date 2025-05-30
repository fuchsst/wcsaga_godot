# SEXP Events Package

## Purpose
The SEXP Events package provides comprehensive mission event integration for the WCS-Godot conversion with frame-based trigger evaluation, signal-based reactivity, mission objective management, and performance optimization. This system enables dynamic mission scripting, objective tracking, and event-driven gameplay mechanics while maintaining full compatibility with WCS mission semantics.

## Key Classes

### MissionEventManager (`mission_event_manager.gd`)
Central event management system with frame-based evaluation, trigger registration, and signal integration.

**Core Features:**
- **Trigger Management**: Register, activate, and manage event triggers with priority-based execution
- **Frame-Based Evaluation**: Performance-optimized evaluation system with configurable budget
- **Signal Integration**: Connect game systems to SEXP evaluation through Godot's signal system
- **Priority System**: Five priority levels (CRITICAL, HIGH, NORMAL, LOW, BACKGROUND) for execution order
- **Performance Monitoring**: Real-time statistics and optimization tools
- **Objective Integration**: Seamless mission objective tracking and completion handling

**Key Methods:**
```gdscript
func register_trigger(trigger_id: String, trigger: EventTrigger, priority: TriggerPriority = TriggerPriority.NORMAL) -> bool
func activate_trigger(trigger_id: String) -> bool
func deactivate_trigger(trigger_id: String) -> bool
func register_objective(objective_id: String, condition_expr: String, completion_actions: Array[String] = []) -> bool
func get_performance_stats() -> Dictionary
```

### EventTrigger (`event_trigger.gd`)
Individual trigger resource with condition/action expressions, timing modes, and configuration options.

**Core Features:**
- **Multiple Trigger Types**: Generic, Objective, Event, Ambient, Conditional, Timer, Signal
- **Timing Modes**: Frame-based, Interval, Signal-only, Manual evaluation
- **Signal Integration**: Connect to Godot signals for reactive trigger activation
- **Variable Watching**: Monitor SEXP variables for automatic re-evaluation
- **Cooldown System**: Prevent excessive trigger firing with configurable cooldowns
- **Performance Tracking**: Individual trigger performance monitoring and statistics

**Key Methods:**
```gdscript
func is_valid() -> bool
func can_evaluate() -> bool
func is_on_cooldown() -> bool
func add_signal_trigger(source_path: String, signal_name: String, parameters: Dictionary = {}) -> void
func add_watched_variable(variable_name: String) -> void
func serialize() -> Dictionary
```

### MissionObjectiveSystem (`mission_objective_system.gd`)
Comprehensive objective management with state tracking, progress monitoring, and completion handling.

**Core Features:**
- **Objective Types**: Primary, Secondary, Bonus, Hidden objectives with different behaviors
- **State Management**: Inactive, Active, Completed, Failed states with transition validation
- **Progressive Objectives**: Multi-stage objectives with progress tracking and auto-completion
- **Prerequisite System**: Objective dependencies and blocking relationships
- **Display Integration**: UI-ready objective lists with filtering and sorting
- **Statistics Tracking**: Completion rates, performance metrics, and objective analytics

**Key Methods:**
```gdscript
func register_objective(objective_id: String, display_name: String, description: String, condition_expr: String, obj_type: ObjectiveType = ObjectiveType.PRIMARY, completion_behavior: CompletionBehavior = CompletionBehavior.NORMAL) -> bool
func activate_objective(objective_id: String) -> bool
func complete_objective(objective_id: String, completion_data: Dictionary = {}) -> bool
func set_objective_progress(objective_id: String, progress: int) -> bool
func get_display_objectives() -> Array[Dictionary]
```

## Usage Examples

### Basic Event Trigger Setup
```gdscript
# Create event manager
var event_manager = MissionEventManager.new()
var evaluator = SexpEvaluator.new()
var variable_manager = SexpVariableManager.new()
event_manager.setup(evaluator, variable_manager)

# Create a simple trigger
var trigger = EventTrigger.new()
trigger.trigger_id = "enemy_destroyed"
trigger.condition_expression = "(= (num-enemies) 0)"
trigger.action_expression = "(complete-objective \"destroy_all_enemies\")"

# Register and activate trigger
event_manager.register_trigger("enemy_destroyed", trigger, MissionEventManager.TriggerPriority.HIGH)
```

### Mission Objective Management
```gdscript
# Create objective system
var objective_system = MissionObjectiveSystem.new(event_manager)

# Register primary objective
objective_system.register_objective(
    "destroy_enemies",
    "Destroy All Enemies",
    "Eliminate all hostile forces in the area",
    "(= (num-enemies) 0)",
    MissionObjectiveSystem.ObjectiveType.PRIMARY
)

# Register progressive objective
objective_system.register_objective(
    "collect_intel",
    "Collect Intelligence",
    "Gather intelligence data from terminals",
    "(>= (get-objective-progress \"collect_intel\") 5)",
    MissionObjectiveSystem.ObjectiveType.SECONDARY,
    MissionObjectiveSystem.CompletionBehavior.PROGRESSIVE
)

# Activate objectives
objective_system.activate_objective("destroy_enemies")
objective_system.activate_objective("collect_intel")

# Update progress
objective_system.advance_objective_progress("collect_intel", 1)
```

### Signal-Based Reactive Triggers
```gdscript
# Create signal-triggered event
var player_died_trigger = EventTrigger.create_signal_trigger(
    "player_death",
    "player",
    "health_depleted",
    "(fail-mission \"Player destroyed\")"
)

event_manager.register_trigger("player_death", player_died_trigger)

# Create variable-watching trigger
var health_warning = EventTrigger.create_variable_watch_trigger(
    "low_health_warning",
    "player_health",
    "(< (get-variable \"local\" \"player_health\") 25)",
    "(send-message \"Warning: Health critical!\")"
)

event_manager.register_trigger("low_health_warning", health_warning)
```

### Performance Optimization
```gdscript
# Configure performance settings
event_manager.max_triggers_per_frame = 15
event_manager.performance_budget_ms = 0.8

# Monitor performance
var frame_stats = event_manager.get_frame_statistics()
print("Frame time: %.2fms (%.1f%% of budget)" % [frame_stats.frame_time_ms, frame_stats.budget_used_percent])

# Optimize trigger execution
event_manager.optimize_performance()
```

## Architecture Notes

### Frame-Based Evaluation System
The event manager uses a sophisticated frame-based evaluation system:

**Performance Budget**: Configurable time budget (default 1ms) to prevent frame rate impact
**Priority Queues**: Five separate queues for different priority levels with guaranteed execution order
**Evaluation Limiting**: Maximum triggers per frame to prevent performance spikes
**Adaptive Scheduling**: Intelligent trigger scheduling based on evaluation frequency and importance

### Signal Integration Architecture
Deep integration with Godot's signal system enables reactive programming:

**Automatic Connections**: Triggers can specify signals to watch for automatic activation
**Variable Reactivity**: Variable changes automatically re-evaluate watching triggers  
**Signal Propagation**: Mission events propagate through the signal system for system integration
**Memory Management**: Automatic signal disconnection prevents memory leaks

### Priority System and Execution Order
Sophisticated priority system ensures critical events execute first:

1. **CRITICAL Priority**: Mission-critical events (player death, mission failure)
2. **HIGH Priority**: Important mission events (objective completion, major story beats)
3. **NORMAL Priority**: Standard mission triggers (enemy spawns, dialogue)
4. **LOW Priority**: Background events (ambient effects, minor interactions)
5. **BACKGROUND Priority**: Lowest priority events (statistics, logging)

### WCS Compatibility Layer
Complete compatibility with Wing Commander Saga mission semantics:

**Objective Types**: Faithful recreation of WCS objective system with extensions
**Trigger Behavior**: Identical timing and execution semantics to WCS triggers
**State Management**: Compatible objective states and transition rules
**Event Integration**: Seamless integration with WCS mission event paradigms

## Integration Points

### With SEXP Evaluation System
The event system is deeply integrated with SEXP evaluation:

**Direct Evaluation**: Triggers evaluate SEXP expressions directly through the evaluator
**Variable Integration**: Automatic variable watching and reactive evaluation
**Function Access**: Full access to all SEXP functions for complex trigger logic
**Error Handling**: Comprehensive error handling and recovery for failed expressions

### With Mission Loading System
Seamless integration with mission loading and progression:

**Mission Start**: Automatic trigger activation and objective setup
**Mission End**: Proper cleanup and state preservation
**Save/Load**: Trigger and objective state persistence across sessions
**Mission Transitions**: Clean state management between missions

### With Game Systems
Universal integration through Godot's signal system:

**Player System**: Health, shields, weapons, movement events
**AI System**: Enemy behavior, squadron commands, formation changes
**Ship System**: Damage, destruction, subsystem failures
**Weapon System**: Firing, impacts, ammunition depletion
**HUD System**: Objective updates, message display, status changes

## Testing Notes

### Test Coverage
The event system includes extensive test suites:

**Test Files:**
- `test_mission_event_manager.gd` - Event manager functionality (600+ lines)
- `test_event_trigger.gd` - Trigger behavior and configuration (500+ lines)
- `test_mission_objective_system.gd` - Objective management and tracking (450+ lines)

**Test Categories:**
- **Basic Operations**: Registration, activation, evaluation, completion
- **Performance Testing**: Frame budget compliance, trigger limiting, optimization
- **Signal Integration**: Reactive triggers, variable watching, signal propagation
- **Error Handling**: Invalid configurations, evaluation failures, recovery
- **Edge Cases**: Large trigger counts, complex conditions, state transitions

### Performance Validation
Comprehensive performance testing ensures frame rate stability:

- **Frame Time Budget**: <1ms average evaluation time with hundreds of triggers
- **Memory Efficiency**: Automatic cleanup prevents memory leaks
- **Signal Performance**: Efficient signal connection/disconnection management
- **Scalability Testing**: Tested with 500+ concurrent triggers maintaining performance

## Error Handling

### Trigger Evaluation Errors
Robust error handling for trigger evaluation failures:

- **Parse Errors**: Invalid SEXP expressions detected during registration
- **Runtime Errors**: Graceful handling of evaluation failures with detailed logging
- **Recovery Mechanisms**: Failed triggers can be disabled or reactivated automatically
- **Error Propagation**: Clear error messages with context for debugging

### Performance Protection
Multiple layers of performance protection:

- **Budget Enforcement**: Hard limits on evaluation time prevent frame drops
- **Emergency Stopping**: Automatic trigger disabling if performance degrades
- **Resource Monitoring**: Memory usage tracking and automatic cleanup
- **Graceful Degradation**: System continues functioning with reduced features if needed

### Mission State Integrity
Comprehensive protection for mission state:

- **Objective Validation**: Prerequisites and state transitions validated
- **Trigger Consistency**: Automatic cleanup of orphaned or invalid triggers
- **Save/Load Safety**: Error recovery for corrupted mission state
- **Rollback Capability**: Ability to revert to previous valid state on errors

This event system provides the foundation for dynamic, responsive mission gameplay while maintaining the performance and reliability required for real-time space combat simulation.