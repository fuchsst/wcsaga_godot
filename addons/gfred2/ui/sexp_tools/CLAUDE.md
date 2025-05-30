# SEXP Tools Package Documentation

## Package Purpose

The SEXP Tools package provides comprehensive SEXP expression editing capabilities for the GFRED2 mission editor, integrating directly with the SEXP addon system. This package implements enhanced tooling for mission editing, delivering advanced debugging, function discovery, and variable management capabilities.

## Key Components

### SexpFunctionPalette (`function_palette.gd`)
**Purpose**: Searchable, categorized palette of SEXP functions from SEXP addon function registry

**Core Features**:
- **Direct SEXP Addon Integration**: Uses `SexpFunctionRegistry` and `SexpHelpSystem` directly
- **Function Discovery**: Search through 400+ WCS operators with fuzzy matching
- **Category Organization**: Functions grouped by logical categories (arithmetic, comparison, etc.)
- **Quick Insertion**: Drag-and-drop or click-to-insert function nodes
- **Real-time Updates**: Automatically reflects new functions registered in SEXP addon

**Integration Points**:
```gdscript
# Direct SEXP addon function registry access
var function_registry: SexpFunctionRegistry = SexpFunctionRegistry.new()
var help_system: SexpHelpSystem = SexpHelpSystem.new(function_registry)

# Load core function categories
function_registry.add_plugin_directory("res://addons/sexp/functions/operators/")
function_registry.add_plugin_directory("res://addons/sexp/functions/variables/")

# Function search with results caching
var search_results: Array[Dictionary] = function_registry.search_functions(query, 50)
```

### SexpDebugPanel (`sexp_debug_panel.gd`)
**Purpose**: Comprehensive debugging interface with SEXP addon debug framework integration

**Core Features**:
- **Real-time Validation**: Uses `SexpValidator` with comprehensive error reporting
- **Variable Watching**: Integration with `SexpVariableWatchSystem` for runtime monitoring
- **Expression Testing**: Debug evaluation with multiple context types
- **AI-Powered Suggestions**: Fix suggestions using SEXP addon AI validation system
- **Performance Monitoring**: Validation timing and complexity analysis

**Debug Capabilities**:
```gdscript
# SEXP addon debug system integration
var sexp_validator: SexpValidator = SexpValidator.new()
var debug_evaluator: SexpDebugEvaluator = SexpDebugEvaluator.new()
var variable_watch_system: SexpVariableWatchSystem = SexpVariableWatchSystem.new()

# Comprehensive validation with AI suggestions
var result: Dictionary = sexp_validator.validate_expression_comprehensive(expression)
var suggestions: Array = sexp_validator.get_fix_suggestions(expression, result)
```

### SexpVariableManager (`variable_manager.gd`)
**Purpose**: Variable management interface with EPIC-004 variable system integration

**Core Features**:
- **Variable CRUD Operations**: Create, read, update, delete variables using EPIC-004 system
- **Type Categorization**: Variables organized by type (numbers, strings, booleans, etc.)
- **Usage Tracking**: Integration with EPIC-004 variable usage statistics
- **Search and Filtering**: Find variables by name, type, or content
- **Real-time Updates**: Automatic synchronization with EPIC-004 variable changes

**Variable Management**:
```gdscript
# EPIC-004 variable system integration
var variable_manager: SexpVariableManager_Epic004 = SexpVariableManager_Epic004.new()

# Create variable with validation
var success: bool = variable_manager.create_variable(name, type, value, description)

# Monitor variable changes
variable_manager.variable_value_changed.connect(_on_variable_changed)
```

## Architecture Notes

### Direct Integration Pattern
This package follows the "direct integration" pattern established in GFRED2-002, avoiding wrapper layers:

**BEFORE (Wrapper Approach)**:
```
GFRED2 Tools → Custom Wrappers → EPIC-004 Systems
```

**AFTER (Direct Approach)**:
```
GFRED2 Tools → EPIC-004 Systems (directly)
```

### Benefits of Direct Integration
1. **Reduced Complexity**: No intermediate layers to maintain
2. **Better Performance**: Direct system access without abstraction overhead
3. **Automatic Updates**: Core system improvements immediately available
4. **Consistency**: Same behavior as other project components using EPIC-004

### Performance Characteristics
- **Function Search**: <100ms for searching 400+ functions with fuzzy matching
- **Real-time Validation**: <5ms response time for standard expressions
- **Variable Operations**: <10ms for CRUD operations with usage tracking
- **Debug Analysis**: <50ms for comprehensive validation with suggestions

## Usage Examples

### Function Palette Integration
```gdscript
# Create and integrate function palette
var function_palette = SexpFunctionPalette.new()
sidebar_tabs.add_child(function_palette)

# Connect to SEXP graph for function insertion
function_palette.function_inserted.connect(_on_function_inserted)

func _on_function_inserted(function_name: String, position: Vector2):
    sexp_graph.add_operator_node(function_name, position)
```

### Debug Panel Setup
```gdscript
# Create debug panel with comprehensive validation
var debug_panel = SexpDebugPanel.new()
sidebar_tabs.add_child(debug_panel)

# Connect validation events
debug_panel.validation_completed.connect(_on_validation_completed)
debug_panel.fix_suggestion_applied.connect(_on_fix_applied)

func _on_validation_completed(is_valid: bool, errors: Array[String]):
    update_editor_validation_state(is_valid, errors)
```

### Variable Manager Usage
```gdscript
# Create variable manager with type categorization
var variable_manager = SexpVariableManager.new()
sidebar_tabs.add_child(variable_manager)

# Handle variable selection for insertion
variable_manager.variable_selected.connect(_on_variable_selected)

func _on_variable_selected(var_name: String, var_data: Dictionary):
    # Could insert @variable_name reference node
    var variable_ref = "@" + var_name
    insert_variable_reference(variable_ref)
```

## Integration with Visual SEXP Editor

### Enhanced Sidebar Setup
The visual SEXP editor integrates all three tools in a tabbed interface:

```gdscript
func _setup_enhanced_sidebar() -> void:
    var sidebar_tabs: TabContainer = TabContainer.new()
    
    # Add all three integrated tools
    var function_palette = SexpFunctionPalette.new()
    var debug_panel = SexpDebugPanel.new()  
    var variable_manager = SexpVariableManager.new()
    
    sidebar_tabs.add_child(function_palette)
    sidebar_tabs.add_child(debug_panel)
    sidebar_tabs.add_child(variable_manager)
    
    # Connect cross-component communication
    _connect_tool_integration(function_palette, debug_panel, variable_manager)
```

### Cross-Component Communication
```gdscript
# Function insertion triggers validation
function_palette.function_inserted.connect(
    func(name, pos): debug_panel.set_expression(get_current_expression())
)

# Variable changes update debug watch list
variable_manager.variable_created.connect(
    func(name, value, type): debug_panel.add_variable_watch(name)
)

# Debug suggestions can insert new functions
debug_panel.fix_suggestion_applied.connect(
    func(orig, fixed): set_expression(fixed)
)
```

## Testing Strategy

### Unit Test Coverage
- **SexpFunctionPalette**: Function search, category filtering, insertion events
- **SexpDebugPanel**: Validation, debugging, variable watching, suggestions
- **SexpVariableManager**: CRUD operations, type filtering, usage tracking

### Integration Testing
- Cross-component communication and event handling
- EPIC-004 system integration and data synchronization
- Performance under load with large function sets and complex expressions

### Performance Validation
- Function search response time with 400+ functions
- Real-time validation performance with complex expressions
- Variable management operations with large variable sets

## Error Handling

### Validation Errors
- Clear error messages with position information
- AI-powered fix suggestions for common mistakes
- Real-time feedback without blocking the UI

### System Integration Errors
- Graceful degradation when EPIC-004 systems are unavailable
- Fallback modes for core functionality
- User-friendly error reporting with recovery suggestions

### Performance Degradation
- Caching strategies for function search and validation
- Debounced operations for real-time updates
- Memory management for large data sets

## Future Extensibility

### Plugin Architecture
The tools are designed to be extensible:
- New function categories can be added to the registry
- Custom validation rules can be integrated
- Additional debug visualizations can be added
- Variable type plugins can extend type support

### Community Integration
- Function discovery from community plugins
- Custom debug tools integration
- Variable template sharing
- Collaborative debugging features

## Dependencies

### Internal Dependencies
- EPIC-004 SEXP Expression System (core dependency)
- GFRED2 Mission Editor framework
- Godot 4.4+ UI system

### External Dependencies
- None - self-contained within WCS-Godot project

## Performance Targets

### Response Time Targets
- Function search: <100ms for any query
- Validation: <5ms for standard expressions
- Variable operations: <10ms for any CRUD operation
- Debug analysis: <50ms for comprehensive validation

### Memory Usage Targets
- Function palette: <5MB for complete function registry
- Debug panel: <2MB for active debugging session
- Variable manager: <1MB for 1000+ variables

### Scalability Targets
- Support 1000+ functions in registry
- Handle 100+ variables per mission
- Real-time performance with complex nested expressions
- Maintain responsiveness during intensive operations

This package represents the complete implementation of enhanced SEXP tooling for GFRED2, providing professional-grade capabilities that exceed the original FRED2 editor while maintaining full compatibility with WCS mission requirements.