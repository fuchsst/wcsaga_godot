# Mission Converter Package

## Package Purpose

This package implements mission file format conversion from Wing Commander Saga (WCS) FS2 mission files to Godot scene format with proper object placement and event system integration. It follows the EPIC-003 data migration architecture and implements DM-007 (Mission File Format Conversion).

## Original C++ Analysis

### Key WCS Source File Analyzed
- **`source/code/mission/missionparse.cpp`**: Core mission file parsing implementation (2,500+ lines)
- **Mission file structure**: Sections for #Mission Info, #Objects, #Wings, #Events, #Goals, #Waypoints
- **SEXP expressions**: Mission event scripting language with complex conditional logic
- **Coordinate system**: WCS uses right-handed coordinate system (X=right, Y=up, Z=forward)

### WCS Mission Architecture Insights
The analysis revealed **well-structured mission file format** with clear section-based organization:
- Mission files use clear section headers (#Mission Info, #Objects, etc.)
- Objects include ships, wings, waypoints with detailed positioning and AI configuration
- Events and goals use SEXP (symbolic expressions) for conditional logic
- Clean separation enables standalone conversion tools

## Key Classes

### MissionFileConverter
Main orchestrator for FS2 mission file to Godot conversion.
- **Purpose**: Manages complete mission conversion pipeline with validation
- **Key Methods**: `convert_mission_file()`, `convert_mission_directory()`, `_validate_conversion_output()`
- **Architecture**: Data-driven approach using Godot Resources following EPIC-001/002 principles

### FS2MissionParser
Comprehensive FS2 mission file parser.
- **Purpose**: Parses FS2 mission files into structured Python data classes
- **Key Methods**: `parse_mission_file()`, `_parse_section()`, `_parse_objects()`, `_parse_events()`
- **Approach**: Section-based parsing following WCS C++ implementation patterns

### GodotSceneGenerator
Generates Godot .tscn scene files from mission data.
- **Purpose**: Creates Godot scenes with proper node hierarchy and data-driven controller
- **Key Methods**: `generate_mission_scene()`, `_create_scene_structure()`
- **Design**: Uses generic MissionController with resource-based configuration (not custom scripts)

### MissionEventConverter
Converts SEXP expressions to GDScript equivalents.
- **Purpose**: Translates WCS mission logic to Godot-compatible event system
- **Key Methods**: `convert_mission_events()`, `_convert_sexp_to_gdscript()`, `_parse_sexp_expression()`
- **Functionality**: Handles SEXP operators like `and`, `or`, `is-destroyed`, `time-elapsed`, `send-message`

### MissionResourceGenerator
Creates Godot Resource files (.tres) for mission data.
- **Purpose**: Generates data-driven resources following EPIC-001/002 architecture
- **Key Methods**: `generate_mission_resources()`, `generate_mission_script_resources()`
- **Resources**: MissionData, ShipInstanceData, WingData, MissionEventData, WaypointListData

## Usage Examples

### Basic Mission Conversion
```bash
# Convert single FS2 mission file
conversion_tools/run_script.sh mission_file_converter mission.fs2 --output converted_missions/

# Convert with validation
conversion_tools/run_script.sh mission_file_converter mission.py --output converted_missions/ --validate

# Convert entire mission directory
conversion_tools/run_script.sh mission_file_converter missions/ --output converted_missions/

# Verbose logging for debugging
conversion_tools/run_script.sh mission_file_converter mission.fs2 --output converted_missions/ --verbose
```

### Testing and Validation
```bash
# Test FS2 parser with sample mission
conversion_tools/run_script.sh fs2_mission_parser --test sample_mission.fs2

# Test event conversion
conversion_tools/run_script.sh mission_event_converter --test sample_events.fs2

# Validate converted resources
conversion_tools/run_script.sh mission_file_converter --validate-only converted_missions/
```

## Architecture Notes

### Data-Driven Design (EPIC-001/002 Compliance)
Based on user feedback to "make use of godot features" and "try a more data driven approach":
- **Resource-First**: Mission data stored in .tres resources, not generated code
- **Generic Controller**: Single MissionController handles any mission via resource loading
- **Separation of Concerns**: Data (resources) completely separate from logic (controller)
- **Godot Native**: Leverages Godot's built-in Resource system and caching

### Coordinate System Conversion
```python
# WCS to Godot coordinate conversion
# WCS: X=right, Y=up, Z=forward (right-handed)
# Godot: X=right, Y=up, Z=back (right-handed, Z inverted)
godot_x = wcs_x * coord_scale
godot_y = wcs_y * coord_scale  
godot_z = -wcs_z * coord_scale  # Invert Z axis
```

### SEXP to GDScript Conversion
```python
# Example SEXP conversion
# SEXP: (and (is-destroyed "Enemy 1") (time-elapsed 30))
# GDScript: is_ship_destroyed("Enemy 1") and get_mission_time() >= 30.0

def convert_sexp_operator(self, operator: str, args: List[str]) -> str:
    if operator == "and":
        return " and ".join(args)
    elif operator == "is-destroyed":
        return f'is_ship_destroyed("{args[0]}")'
    elif operator == "time-elapsed":
        return f"get_mission_time() >= {float(args[0])}"
```

## Directory Structure
```
mission_converter/
├── mission_file_converter.py     # Main conversion orchestrator
├── fs2_mission_parser.py         # FS2 mission file parser
├── godot_scene_generator.py      # Godot scene generation
├── mission_event_converter.py    # SEXP to GDScript conversion
├── mission_resources.py          # Resource generation (data-driven)
└── CLAUDE.md                     # This documentation
```

## Key Features

### Comprehensive Mission Parsing
- Parses all mission sections: Info, Objects, Wings, Events, Goals, Waypoints
- Handles complex ship configurations with AI, hull, shields, cargo
- Processes wing formations with arrival/departure logic
- Extracts mission variables and metadata

### Data-Driven Resource Generation
- **MissionData**: Main mission resource with metadata and asset references
- **ShipInstanceData**: Individual ship configuration and positioning
- **WingData**: Wing formation and coordination data
- **MissionEventData**: Event logic and trigger conditions
- **WaypointListData**: Navigation waypoint collections

### Advanced Validation System
- **File Format Validation**: Ensures proper .tres and .tscn format
- **Content Validation**: Checks required fields in each resource type
- **Reference Validation**: Verifies resource paths point to existing files
- **Data Consistency**: Cross-validates relationships between generated files

### SEXP Expression Support
- **Logical Operators**: `and`, `or`, `not` with proper precedence
- **Condition Checking**: `is-destroyed`, `time-elapsed`, `distance-between`
- **Actions**: `send-message`, `warp-in`, `warp-out`, `end-mission`
- **Variables**: Mission variable access and manipulation

## Integration Points

### EPIC-001/002 Asset Management
- Uses Resource-based architecture for all mission data
- Integrates with asset management addon for ship/weapon references
- Follows standardized directory organization

### MissionController Integration
- Generic controller loads mission data from resources at runtime
- Supports any mission without custom code generation
- Handles ship spawning, event processing, objective tracking

### Godot Editor Integration
- Generates proper .tscn scenes for editor visibility
- Creates .tres resources for Inspector editing
- Follows Godot import/export conventions

## Performance Considerations

### Memory Efficiency
- Resource-based loading reduces memory footprint
- Godot's built-in caching handles resource management
- Streaming mission data for large missions (future enhancement)

### Conversion Speed
- Parallel processing for multiple missions
- Efficient SEXP parsing with minimal string operations
- Progressive validation to catch errors early

### Runtime Performance
- Generic MissionController handles any mission efficiently
- Resource loading scales well with mission complexity
- Event system optimized for typical mission sizes

## Testing Notes

### Unit Testing
- FS2 parser validation with known mission files
- SEXP conversion accuracy verification
- Resource generation format compliance

### Integration Testing
- End-to-end mission conversion pipeline
- Godot scene loading and functionality
- Resource reference integrity

### Validation Testing
- Mission conversion accuracy with original WCS missions
- Performance testing with large mission collections
- Edge case handling (malformed missions, missing data)

## Implementation Status

### Completed (DM-007)
- ✅ **DM-007-1**: FS2 mission file parsing with all sections
- ✅ **DM-007-2**: Godot scene generation with MissionController
- ✅ **DM-007-3**: SEXP expression conversion to GDScript
- ✅ **DM-007-4**: Resource generation for mission data (data-driven)
- ✅ **DM-007-5**: CLI tool for batch mission conversion
- ✅ **DM-007-6**: Comprehensive validation system

### Architecture Evolution
**Initial Approach**: Template-based code generation with custom mission scripts
**Final Approach**: Resource-driven design with generic MissionController
**Reason**: User feedback emphasized leveraging Godot features and EPIC-001/002 principles

### Key Deviations from Original Plan
- **No Custom Scripts**: Uses generic MissionController instead of generated scripts
- **Resource-First**: All mission data in .tres files, not embedded in scenes
- **Simplified Architecture**: Fewer components, cleaner separation of concerns
- **Better Godot Integration**: Leverages Resource system instead of fighting it

---

**Implementation Status**: DM-007 COMPLETED with comprehensive validation system  
**Quality**: Production-ready with full error handling and data consistency checks  
**Performance**: Optimized for large mission collections with parallel processing  
**Integration**: Seamless integration with EPIC-001/002 and Godot workflow