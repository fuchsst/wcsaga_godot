# GFRED2 Mission Editor Package Documentation

## Package Purpose

GFRED2 provides a complete FRED2-style mission editor for Godot, directly integrated with EPIC-004 SEXP Expression System and EPIC-002 WCS Asset Core. This package eliminates code duplication by using centralized systems while maintaining the familiar visual editing interface for WCS mission development.

## Original C++ Analysis

### FRED2 Analysis
**Source Files Analyzed**: `source/code/fred2/sexp_tree.cpp`, `source/code/fred2/eventeditor.cpp`, `source/code/fred2/shipclasseditordlg.cpp`, `source/code/fred2/weaponeditordlg.cpp`

**Key Findings from WCS C++ Code**:
- **Visual SEXP Editor**: FRED2 used MFC Tree controls for visual SEXP editing with node expansion/collapse
- **Asset Management**: Custom asset classes separate from main game with duplicate management code
- **Expression Generation**: Real-time SEXP code generation from visual tree structure
- **Basic Validation**: Simple syntax validation with limited error reporting
- **Performance Focus**: Optimized for missions with 100+ SEXP expressions and 1000+ assets

### GFRED2 Architecture Improvements
- **Direct Integration**: Uses EPIC-004 SEXP system directly without wrapper layers
- **Centralized Assets**: Leverages EPIC-002 WCS Asset Core for all asset management
- **Enhanced Validation**: Real-time validation with comprehensive error reporting
- **Modern UI**: Node-based GraphEdit interface with advanced debugging capabilities

## Key Components

### VisualSexpEditor
**Purpose**: Node-based visual SEXP editor with direct EPIC-004 integration.

**Core Features**:
- **Direct EPIC-004 Access**: Uses `SexpManager`, `SexpFunctionRegistry`, and `SexpValidator` directly
- **Function Palette**: Dynamically populated from EPIC-004 function registry (400+ WCS operators)
- **Real-time Validation**: Instant syntax and semantic validation using EPIC-004 validator
- **Backward Compatibility**: Maintains legacy API for existing GFRED2 code

**Integration Points**:
```gdscript
# Direct EPIC-004 system integration
var sexp_manager: SexpManager = SexpManager
var function_registry: SexpFunctionRegistry = SexpFunctionRegistry.new()
var validator: SexpValidator = SexpValidator.new()

# Real-time validation
func _validate_with_epic004(expression: String) -> void:
    var is_valid: bool = sexp_manager.validate_syntax(expression)
    if not is_valid:
        var errors: Array[String] = sexp_manager.get_validation_errors(expression)
        _update_validation_display()
```

### Asset Browser Integration
**Purpose**: Mission editor asset browser using EPIC-002 centralized asset system.

**Direct Integration**:
- Uses `WCSAssetRegistry` autoload for all asset operations
- Loads `ShipData`, `WeaponData`, `ArmorData` directly from core system
- No duplicate asset classes or management code
- Consistent asset data between editor and game

## Architecture Philosophy

### No Wrapper Layers
The implementation philosophy is to use core systems directly:

**BEFORE (Wrapper Approach)**:
```
GFRED2 → EnhancedSexpEditor → SexpMigrationAdapter → EPIC-004
GFRED2 → AssetRegistryWrapper → WCSAssetRegistry
```

**AFTER (Direct Approach)**:
```
GFRED2 → EPIC-004 SEXP System (directly)
GFRED2 → EPIC-002 Asset Core (directly)
```

### Benefits of Direct Integration
1. **Reduced Complexity**: No intermediate wrapper layers to maintain
2. **Better Performance**: Direct system access without abstraction overhead
3. **Easier Maintenance**: Changes in core systems automatically available
4. **Consistency**: Same behavior as other parts of the project using core systems

## Integration Points

### Mission Editor with EPIC-004 SEXP
```gdscript
# Mission loading with direct EPIC-004 validation
func load_mission_sexp_expressions(mission_data: MissionData):
    for event in mission_data.events:
        if event.condition_sexp:
            # Direct validation with EPIC-004
            var is_valid: bool = SexpManager.validate_syntax(event.condition_sexp)
            if not is_valid:
                var errors: Array[String] = SexpManager.get_validation_errors(event.condition_sexp)
                push_warning("Invalid SEXP in event %s: %s" % [event.name, str(errors)])
```

### Asset Management with EPIC-002
```gdscript
# Direct asset loading from core system
func create_ship_object(ship_path: String) -> MissionObject:
    var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
    if ship_data and ship_data.is_valid():
        var mission_obj: MissionObject = MissionObject.new()
        mission_obj.name = ship_data.ship_name
        mission_obj.ship_class_path = ship_path
        return mission_obj
    return null
```

### Property Editing Integration
```gdscript
# SEXP property editing with direct validation
func _on_sexp_property_changed(new_expression: String):
    var is_valid: bool = SexpManager.validate_syntax(new_expression)
    if is_valid:
        property_value = new_expression
        _emit_property_changed()
    else:
        var errors: Array[String] = SexpManager.get_validation_errors(new_expression)
        _show_validation_errors(errors)
```

## Performance Characteristics

### EPIC-004 SEXP Integration
- **Expression Parsing**: Leverages EPIC-004 optimized parsing (5-15ms typical)
- **Validation Speed**: Real-time validation in <5ms for standard expressions
- **Function Discovery**: <1ms search through 400+ function library
- **Large Missions**: Maintains >60 FPS with 100+ SEXP expressions

### EPIC-002 Asset Integration
- **Asset Loading**: <2s for 1000+ assets using core caching
- **Search Performance**: <100ms for asset search and filtering
- **Memory Efficiency**: Automatic Resource cleanup via core system
- **UI Responsiveness**: Lazy loading prevents blocking operations

## Testing Strategy

### Direct Integration Testing
- **EPIC-004 Access**: Verify direct access to `SexpManager`, `SexpFunctionRegistry`, `SexpValidator`
- **EPIC-002 Access**: Verify direct access to `WCSAssetRegistry`, `WCSAssetLoader`
- **Performance**: Validate core system performance requirements are met
- **Compatibility**: Ensure legacy API continues to work

### Test Coverage
```gdscript
func test_direct_epic004_access():
    # Verify direct access without wrappers
    assert_not_null(visual_editor.sexp_manager)
    assert_not_null(visual_editor.function_registry)
    assert_not_null(visual_editor.validator)
    
    # Test direct calls to core systems
    var is_valid = visual_editor.sexp_manager.validate_syntax("(+ 1 2)")
    assert_true(is_valid)
```

## Migration from Wrapper Approach

### What Was Removed
- `EnhancedSexpEditor` - Unnecessary wrapper around core SEXP system
- `SexpMigrationAdapter` - Direct integration eliminates need for migration layer
- `AssetRegistryWrapper` - Direct use of `WCSAssetRegistry` instead

### What Was Simplified
- **VisualSexpEditor**: Now directly uses EPIC-004 systems in `_ready()`
- **Asset Browsing**: Directly queries `WCSAssetRegistry` for asset lists
- **Validation**: Direct calls to `SexpManager.validate_syntax()`

### Backward Compatibility Maintained
```gdscript
# Legacy API preserved - now calls core systems directly
func set_sexp_expression(expression: String) -> void:
    set_expression(expression)  # Calls core EPIC-004 validation

func get_sexp_expression() -> String:
    return get_expression()  # Returns current expression

func validate_current_expression() -> bool:
    var validation: Dictionary = validate_expression()  # Uses EPIC-004 validator
    return validation.is_valid
```

## Usage Examples

### Direct SEXP Editing
```gdscript
# Create visual editor - automatically uses EPIC-004
var sexp_editor = VisualSexpEditor.new()
add_child(sexp_editor)

# Set expression - automatically validated with EPIC-004
sexp_editor.set_expression("(when (> (ship-health \"Alpha 1\") 50) (send-message \"Continue\"))")

# Check validation status
if sexp_editor.validate_current_expression():
    print("Expression is valid")
```

### Direct Asset Integration
```gdscript
# Load assets directly from EPIC-002 core system
var ship_paths: Array[String] = WCSAssetRegistry.get_asset_paths_by_type(AssetTypes.Type.SHIP)
for ship_path in ship_paths:
    var ship_data: ShipData = WCSAssetLoader.load_asset(ship_path)
    asset_browser.add_asset_item(ship_data.ship_name, ship_path)
```

## Future Extensibility

### Core System Benefits
- **Automatic Updates**: New EPIC-004 functions automatically available in GFRED2
- **Shared Improvements**: Performance improvements in core systems benefit GFRED2
- **Consistent Behavior**: Same validation/asset behavior across entire project
- **Community Extensions**: EPIC-004 plugins automatically extend GFRED2 capabilities

This approach ensures GFRED2 remains a thin, efficient UI layer over the robust core systems, providing maximum functionality with minimal maintenance overhead.