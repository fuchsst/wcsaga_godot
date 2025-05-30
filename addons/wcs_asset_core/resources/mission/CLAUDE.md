# Mission Resource System Package

## Purpose
Core mission data structures for the WCS-Godot Mission Editor, providing type-safe, validated mission data management using Godot's Resource system.

## Key Classes

### MissionData
**File**: `mission_data.gd`  
**Purpose**: Central mission data container with comprehensive validation and change tracking  
**Key Features**:
- Stores all mission components (ships, wings, events, goals, etc.)
- Real-time validation with caching for performance
- Signal-based change notification for UI updates
- Automatic name generation for new objects
- Statistics and complexity scoring
- Static factory methods for mission creation

**Usage Example**:
```gdscript
# Create a new mission
var mission := MissionData.create_empty_mission()

# Add a ship
var ship := ShipInstanceData.new()
ship.ship_class_name = "GTF Ulysses"
mission.add_ship(ship)

# Validate mission
var result := mission.validate()
if not result.is_valid():
    print("Mission has errors: ", result.get_summary())

# Get statistics
var stats := mission.get_mission_statistics()
print("Mission has %d ships" % stats.total_ships)
```

### ValidationResult
**File**: `validation_result.gd`  
**Purpose**: Container for validation results with detailed error/warning reporting  
**Key Features**:
- Separate error, warning, and info message categories
- Merging capability for combining validation results
- Formatted output for user display
- Statistical summary methods

**Usage Example**:
```gdscript
var result := ValidationResult.new()
result.add_error("Ship name cannot be empty")
result.add_warning("Mission complexity is high")

print(result.get_summary())  # "1 errors, 1 warnings"
print(result.is_valid())     # false (has errors)
```

## Architecture Notes

### Resource-Based Design
- All mission components extend Godot's Resource class
- Automatic serialization to .tres/.res formats
- Type-safe property declarations with @export
- Integration with Godot's property inspector

### Signal-Driven Updates
- MissionData emits `data_changed` signal for all modifications
- UI components can connect to signals for real-time updates
- Validation cache is invalidated automatically on changes
- Supports undo/redo system integration

### Validation System
- Comprehensive validation with specific error messages
- Performance-optimized with caching and hash-based change detection
- Extensible validation system for custom rules
- Real-time feedback during editing

### Integration with Existing Resources
- Compatible with existing ShipInstanceData, WingInstanceData, etc.
- Uses duck typing for validation (checks for validate() method)
- Maintains backward compatibility with existing mission files

## Performance Considerations

### Validation Caching
- Validation results are cached using content hash
- Only re-validates when mission data actually changes
- Hash calculation optimized for most common changes

### Memory Management
- Resource system provides efficient memory usage
- Arrays use typed Array[Resource] for better performance
- Signal connections cleaned up automatically

### Large Mission Handling
- Complexity scoring to warn about performance issues
- Efficient name generation algorithms
- Optimized statistics calculation

## Testing Notes
**Test File**: `../../tests/test_mission_data_validation.gd`

### Test Coverage
- Mission creation and validation
- Error handling and edge cases
- Signal emission verification
- Name generation uniqueness
- ValidationResult functionality
- Statistics calculation

### Key Test Cases
- Empty mission validation
- Invalid player count handling
- Duplicate ship name detection
- Signal-based change notification
- Performance warning thresholds

## Future Enhancement Hooks

### Additional Validation Rules
- Cross-reference validation (ship class exists, etc.)
- Mission balance checking
- Performance impact analysis

### Advanced Features
- Mission templates and presets
- Bulk operations on mission objects
- Mission diff and merge capabilities
- Export to different formats

---

**Created**: 2025-01-25 (STORY-005)  
**Last Updated**: 2025-01-25  
**Dependencies**: Existing mission resource classes, ValidationResult  
**Used By**: Mission Editor UI, FS2 Import/Export, 3D Viewport