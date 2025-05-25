# Property Inspector Package

## Overview

The Property Inspector package provides a comprehensive, categorized property editing system for mission objects in the FRED2 mission editor. It extends the basic property editing capabilities with enhanced UI organization, real-time validation, multi-object editing support, and contextual help.

## Key Components

### Core Classes

**ObjectPropertyInspector** (`object_property_inspector.gd`)
- Main inspector interface with categorized property organization
- Supports both single and multi-object editing
- Integrates with visual SEXP editor for complex expressions
- Provides search/filter capabilities and real-time validation

**PropertyCategory** (`categories/property_category.gd`)
- Collapsible property category container
- Supports search filtering and help integration
- Maintains expand/collapse state for user preferences

**PropertyEditorRegistry** (`editors/property_editor_registry.gd`)
- Factory for creating type-specific property editors
- Centralized editor creation and configuration
- Supports both single and multi-object editing modes

### Type-Specific Editors

**Vector3PropertyEditor** (`editors/vector3_property_editor.gd`)
- X/Y/Z component editing with spinboxes
- Copy/paste functionality with multiple format support
- Reset to default values and range validation

**StringPropertyEditor** (`editors/string_property_editor.gd`)
- Single-line and multi-line text editing
- Real-time input validation and filtering
- Support for different input types (numeric, alphanumeric, filename)

**SexpPropertyEditor** (`editors/sexp_property_editor.gd`)
- SEXP expression preview and editing
- Integration with visual SEXP editor
- Formatted preview with main operator extraction

**BooleanPropertyEditor** (`editors/boolean_property_editor.gd`)
- Simple checkbox with label
- Tooltip support for contextual help

**EnumPropertyEditor** (`editors/enum_property_editor.gd`)
- Dropdown selection with custom options
- Support for display names and numeric values

**NumberPropertyEditor** (`editors/number_property_editor.gd`)
- Spinbox with range constraints and validation
- Support for step values, prefixes, and suffixes

**FilePathPropertyEditor** (`editors/file_path_property_editor.gd`)
- File/directory selection with browse dialog
- Path validation and relative path conversion
- File type filtering and existence checking

**ReadOnlyPropertyEditor** (`editors/readonly_property_editor.gd`)
- Display-only properties with copy functionality
- Used for system-generated values like object IDs

### Multi-Object Editing

**MultiVector3PropertyEditor** (`editors/multi_vector3_property_editor.gd`)
- Batch editing of Vector3 properties across multiple objects
- Mixed value detection and display
- Synchronized value updates

**MultiBooleanPropertyEditor** (`editors/multi_boolean_property_editor.gd`)
- Checkbox with indeterminate state for mixed values
- Batch boolean property updates

### Help System

**ContextualHelp** (`help/contextual_help.gd`)
- Static help system with property documentation
- Tooltip generation and detailed help dialogs
- Comprehensive property descriptions and examples

## Architecture

### Property Categories

Properties are organized into logical categories:

1. **Transform**: Position, rotation, scale
2. **Visual**: Model files, textures, visibility
3. **Behavior**: AI settings, orders, ship configuration
4. **Mission Logic**: Goals, events, SEXP expressions
5. **Advanced**: Debug info, special flags

### Data Flow

```
Mission Object Selection
         ↓
ObjectPropertyInspector.edit_objects()
         ↓
Category Creation & Property Analysis
         ↓
PropertyEditorRegistry.create_*_editor()
         ↓
Type-Specific Editor Setup
         ↓
User Interaction & Validation
         ↓
Property Change Events
         ↓
Mission Data Update
```

### Integration Points

**With Mission Object Manager**:
- Receives object selections and updates
- Propagates property changes back to manager
- Handles undo/redo integration

**With Visual SEXP Editor**:
- Opens SEXP editor for complex expressions
- Receives expression updates and applies to properties
- Maintains editing context for property names

**With Validation System**:
- Real-time property validation using ObjectValidator
- Visual feedback for validation errors and warnings
- Type-specific validation rules

## Usage Examples

### Basic Single Object Editing

```gdscript
# Setup property inspector
var inspector: ObjectPropertyInspector = ObjectPropertyInspector.new()
add_child(inspector)

# Edit a single object
var ship_object: MissionObjectData = get_selected_ship()
inspector.edit_objects([ship_object])

# Listen for property changes
inspector.property_changed.connect(_on_property_changed)
```

### Multi-Object Editing

```gdscript
# Edit multiple objects at once
var selected_ships: Array[MissionObjectData] = get_selected_ships()
inspector.edit_objects(selected_ships)

# Common properties will be shown
# Mixed values will be indicated appropriately
```

### Custom Property Validation

```gdscript
# Add custom validation to string editor
var options: Dictionary = {
    "tooltip": "Ship name must be unique",
    "custom_validator": func(value: String) -> Dictionary:
        if is_ship_name_taken(value):
            return {"is_valid": false, "error_message": "Ship name already exists"}
        return {"is_valid": true}
}

var editor = registry.create_string_editor("ship_name", "Name", current_name, options)
```

### SEXP Property Integration

```gdscript
# Handle SEXP edit requests
inspector.sexp_edit_requested.connect(_on_sexp_edit_requested)

func _on_sexp_edit_requested(property_name: String, current_expression: String):
    sexp_editor.load_expression_from_text(current_expression)
    sexp_editor.set_meta("editing_property", property_name)
    show_sexp_editor()
```

## Performance Considerations

### Optimization Strategies

1. **Lazy Property Loading**: Properties are only created when categories are expanded
2. **Validation Debouncing**: Validation is debounced to avoid excessive validation calls
3. **Category State Persistence**: Category expand/collapse states are maintained
4. **Editor Instance Reuse**: Property editors are reused when possible

### Memory Management

- Property editors are properly cleaned up when objects change
- Help system uses static data to minimize memory usage
- Large property lists use scrolling containers to maintain performance

### Performance Targets

- Property inspector loads within 100ms for any object
- Real-time updates maintain 60 FPS during editing
- Memory usage under 20MB for missions with 1000+ objects
- Search/filter operations complete within 50ms

## Testing Notes

### Validation Testing

- Test property validation with invalid values
- Verify visual feedback for validation errors
- Ensure validation works across different property types

### Multi-Object Testing

- Test with objects having identical properties
- Test with objects having mixed property values
- Verify batch operations affect all selected objects

### Integration Testing

- Test SEXP editor integration with property editing
- Verify undo/redo operations work correctly
- Test performance with large numbers of objects

### Edge Cases

- Empty selections should clear the inspector
- Invalid property values should be handled gracefully
- Help system should work for all documented properties

## Future Enhancements

### Planned Features

1. **Property Templates**: Save and load property configurations
2. **Batch Operations**: More sophisticated multi-object operations
3. **Property History**: Track and revert property changes
4. **Custom Property Types**: Support for WCS-specific data types
5. **Property Binding**: Link properties between objects

### Extensibility

The property inspector is designed to be extensible:

- New property types can be added by implementing the property editor interface
- Custom validation rules can be added to any property type
- Help content can be extended with additional property documentation
- Categories can be customized for different object types

## Dependencies

### Internal Dependencies
- `MissionObjectData`: Core data structure for mission objects
- `ObjectValidator`: Property validation system
- `VisualSexpEditor`: SEXP expression editing
- `MissionObjectManager`: Object lifecycle management

### External Dependencies
- Godot 4.4+ UI classes (Control, VBoxContainer, etc.)
- Godot's built-in validation and input systems

## Error Handling

The property inspector includes comprehensive error handling:

- Invalid property values are caught and displayed to the user
- Missing property editors fall back to string editors
- Validation errors are shown with clear error messages
- System errors are logged and don't crash the editor

This package represents a complete property editing solution that significantly enhances the usability and functionality of the FRED2 mission editor while maintaining performance and stability.