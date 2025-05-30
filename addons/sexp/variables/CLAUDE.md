# SEXP Variables Package

## Purpose
The SEXP Variables package provides comprehensive variable management for the WCS-Godot conversion with three-tier scope management (local, campaign, global), type safety, persistence, and signal-based notifications. This system maintains full compatibility with WCS variable semantics while adding modern Godot features like automatic persistence and reactive programming support.

## Key Classes

### SexpVariableManager (`sexp_variable_manager.gd`)
Central variable management system with scope-based organization and high-performance caching.

**Core Features:**
- **Three-Tier Scopes**: Local (mission-only), Campaign (persistent across missions), Global (persistent across campaigns)
- **Automatic Persistence**: Campaign and global variables automatically save/load from disk
- **LRU Caching**: High-performance variable access with configurable cache size
- **Signal Notifications**: Real-time variable change notifications for reactive programming
- **Type Conversion**: WCS-compatible type conversion system
- **Access Statistics**: Performance monitoring and optimization insights

**Key Methods:**
```gdscript
func set_variable(scope: VariableScope, name: String, value: SexpResult) -> bool
func get_variable(scope: VariableScope, name: String) -> SexpResult
func has_variable(scope: VariableScope, name: String) -> bool
func find_variable(name: String) -> Dictionary  # Auto-scope search
func clear_scope(scope: VariableScope) -> void
```

### SexpVariable (`sexp_variable.gd`)
Individual variable resource with comprehensive metadata, type safety, and constraint validation.

**Core Features:**
- **Type Safety**: Optional type locking and allowed type constraints
- **Value Constraints**: Numeric ranges, allowed string values (enum-like)
- **Read-Only Protection**: Immutable variables for constants
- **Access Tracking**: Creation time, modification time, access count, last accessed
- **Serialization**: Complete roundtrip serialization for persistence
- **Type Conversion**: WCS-compatible conversion methods

**Key Methods:**
```gdscript
func set_value(new_value: SexpResult, validate: bool = true) -> bool
func get_value() -> SexpResult  # Updates access tracking
func get_value_safe() -> SexpResult  # No tracking update
func lock_type() -> void
func set_number_range(min_val: float, max_val: float) -> void
func serialize() -> Dictionary
func deserialize(data: Dictionary) -> bool
```

## Usage Examples

### Basic Variable Operations
```gdscript
# Create variable manager
var var_manager = SexpVariableManager.new()

# Set variables in different scopes
var_manager.set_variable(SexpVariableManager.VariableScope.LOCAL, "player_health", SexpResult.create_number(100))
var_manager.set_variable(SexpVariableManager.VariableScope.CAMPAIGN, "mission_complete", SexpResult.create_boolean(true))
var_manager.set_variable(SexpVariableManager.VariableScope.GLOBAL, "difficulty", SexpResult.create_string("normal"))

# Get variables with auto-scope search
var health = var_manager.find_variable("player_health")
if health.found:
    print("Player health: ", health.variable.get_value().get_number_value())
```

### Variable Constraints and Type Safety
```gdscript
# Create constrained variable
var difficulty_var = SexpVariable.new()
difficulty_var.name = "difficulty_setting"
difficulty_var.set_allowed_string_values(["easy", "normal", "hard", "insane"])
difficulty_var.set_allowed_types([SexpResult.ResultType.STRING])
difficulty_var.lock_type()

# Valid assignment
var success = difficulty_var.set_value(SexpResult.create_string("hard"))  # Works

# Invalid assignment
success = difficulty_var.set_value(SexpResult.create_string("extreme"))  # Fails
success = difficulty_var.set_value(SexpResult.create_number(1))  # Fails (type locked)
```

### Signal-Based Reactive Programming
```gdscript
# Connect to variable change signals
var_manager.variable_changed.connect(_on_variable_changed)
var_manager.variable_added.connect(_on_variable_added)

func _on_variable_changed(scope: SexpVariableManager.VariableScope, name: String, old_value: SexpResult, new_value: SexpResult):
    print("Variable %s changed from %s to %s" % [name, old_value, new_value])
    
    # React to specific variable changes
    if name == "player_health" and new_value.get_number_value() <= 0:
        _trigger_game_over()
```

### Persistence and Save/Load
```gdscript
# Variables automatically persist, but you can manually save
var_manager.save_campaign_variables()  # Save to user://campaign_variables.save
var_manager.save_global_variables()    # Save to user://global_variables.save

# Custom save paths
var_manager.set_campaign_save_path("user://my_campaign.save")
var_manager.set_global_save_path("user://my_globals.save")

# Variables automatically load on manager creation
var new_manager = SexpVariableManager.new("user://my_campaign.save", "user://my_globals.save")
```

## Architecture Notes

### Scope Hierarchy and Search Order
Variables follow a hierarchical scope system with search priority:
1. **Local Scope** (highest priority) - Mission-specific, cleared on mission end
2. **Campaign Scope** (medium priority) - Persistent across missions in same campaign
3. **Global Scope** (lowest priority) - Persistent across all campaigns and sessions

Auto-scope search (`find_variable()`) searches in this order and returns the first match.

### WCS Compatibility
The variable system maintains strict compatibility with Wing Commander Saga semantics:

**Type Conversion Rules:**
- String-to-Number: Uses `to_float()` equivalent of WCS `atoi()`
- Boolean-to-Number: `true` = 1.0, `false` = 0.0
- Number-to-Boolean: 0.0 = `false`, any other value = `true`
- String-to-Boolean: Empty string = `false`, non-empty with numeric value != 0 = `true`

**Scope Behavior:**
- Local variables: Cleared on mission end (not persistent)
- Campaign variables: Persist across missions in same campaign
- Global variables: Persist across all sessions and campaigns

### Performance Optimizations

**LRU Caching System:**
- Configurable cache size (default 500 entries)
- Automatic eviction of least recently used variables
- Cache hit rate tracking and statistics
- Substantial performance improvement for frequently accessed variables

**Access Statistics:**
```gdscript
var stats = var_manager.get_access_statistics()
print("Cache hit rate: %.1f%%" % stats.cache_hit_rate)
print("Total gets: %d, sets: %d" % [stats.total_gets, stats.total_sets])
```

**Memory Management:**
- RefCounted base classes for automatic cleanup
- Efficient serialization with minimal memory overhead
- Optimized string handling for large variable sets

### Signal Architecture
The variable system provides comprehensive signal support for reactive programming:

**Available Signals:**
- `variable_changed(scope, name, old_value, new_value)` - Variable value updated
- `variable_added(scope, name, value)` - New variable created
- `variable_removed(scope, name)` - Variable deleted
- `scope_cleared(scope)` - Entire scope cleared

**Signal Performance:**
- Signals are emitted only when changes actually occur
- No performance impact when no listeners are connected
- Thread-safe signal emission (Godot handles thread safety)

## Integration Points

### With SEXP Functions
The variable system integrates seamlessly with SEXP function execution:

**SEXP Functions Provided:**
- `set-variable` - Set variable in specific scope
- `get-variable` - Get variable with optional auto-scope search
- `has-variable` - Check variable existence
- `remove-variable` - Delete variable from scope
- `clear-variables` - Clear entire scope
- `list-variables` - Get comma-separated list of variable names

**Function Registration:**
```gdscript
var registry = SexpFunctionRegistry.new()
SexpVariableFunctionRegistration.register_all_variable_functions(registry)
```

### With Mission System
Variables integrate with mission loading and campaign progression:
- Local variables cleared automatically on mission end
- Campaign variables persist between missions
- Mission scripts can access all variable scopes
- Variable state maintained across save/load cycles

### With Save/Load System
Variables are automatically saved and loaded with proper error handling:
- JSON-based serialization for human readability
- Automatic backup and recovery on corruption
- Version compatibility tracking for future updates
- Efficient differential saves (only changed variables)

## Testing Notes

### Test Coverage
The variable system includes comprehensive test suites:

**Test Files:**
- `test_sexp_variable_manager.gd` - Variable manager functionality (500+ lines)
- `test_sexp_variable.gd` - Individual variable features (400+ lines)  
- `test_sexp_variable_functions.gd` - SEXP function integration (350+ lines)

**Test Categories:**
- **Basic Operations**: Set, get, has, remove, clear operations
- **Scope Management**: Multi-scope isolation and search behavior
- **Type Safety**: Constraints, validation, type locking
- **Persistence**: Save/load roundtrip testing with different data types
- **Performance**: Caching efficiency, access statistics, memory usage
- **Error Handling**: Invalid inputs, constraint violations, serialization errors
- **Signal Testing**: Reactive programming and notification accuracy

### Performance Testing
Benchmarks validate the system meets performance requirements:
- Variable access: <1ms average for cached variables
- Cache efficiency: >90% hit rate for typical usage patterns
- Memory usage: <1MB for 10,000 variables with full metadata
- Persistence: <100ms save/load time for typical variable sets

## Error Handling

### Validation Errors
The system provides comprehensive error detection:
- **Invalid Scope**: Unknown scope names return `VALIDATION_ERROR`
- **Empty Names**: Variable names cannot be empty
- **Type Constraints**: Values must match allowed types
- **Range Constraints**: Numeric values must be within specified ranges
- **Read-Only Violations**: Cannot modify read-only variables

### Runtime Errors
Runtime issues are handled gracefully:
- **File Access**: Persistence failures return appropriate errors
- **Memory Issues**: Automatic cache trimming prevents memory exhaustion
- **Serialization**: Corrupted save files trigger recovery procedures
- **Null Values**: Null arguments properly detected and rejected

### Error Recovery
The system includes robust error recovery mechanisms:
- **Automatic Persistence**: Failed saves don't corrupt existing data
- **Cache Rebuilding**: Cache corruption triggers automatic rebuild
- **Graceful Degradation**: System continues functioning with reduced features
- **Detailed Logging**: All errors logged with context for debugging

This variable management system provides a robust, high-performance foundation for all SEXP expression evaluation while maintaining strict compatibility with WCS behavior and adding modern Godot features for enhanced functionality.