# WCS Core Foundation Package

## Package Purpose
This package provides the foundational infrastructure for the WCS-Godot conversion project. It contains core constants, type definitions, and path management that all other WCS systems depend upon. This is the absolute foundation layer that must be implemented first before any other systems can be developed.

## Original C++ Analysis Summary

### Analyzed Source Files:
- **`source/code/globalincs/globals.h`**: Core game constants and limits
- **`source/code/globalincs/pstypes.h`**: Fundamental type definitions and mathematical constants  
- **`source/code/globalincs/systemvars.cpp`**: System variables and runtime state

### Key Findings:
- **String length constants**: PATHNAME_LENGTH (192), NAME_LENGTH (32), SEXP_LENGTH (128)
- **Game limits**: MAX_SHIPS (400), MAX_WEAPONS (700), MAX_OBJECTS (2000)
- **Mathematical constants**: PI (3.141592654f), conversion macros, vector/matrix types
- **Platform abstraction**: Directory separators, cross-platform compatibility
- **Type system**: Custom types (ubyte, ushort, fix), vector/matrix structures

## Key Classes

### WCSConstants
- **Purpose**: Centralized storage for all WCS global constants
- **Type**: Resource class (extends Resource)
- **Responsibility**: Provides identical constant values from WCS C++ implementation
- **Key Features**: Validation functions, utility methods, organized constant groups

### WCSTypes  
- **Purpose**: Type definitions and conversion functions between C++ and GDScript
- **Type**: RefCounted utility class
- **Responsibility**: Handles data type conversion, enum definitions, validation
- **Key Features**: Vector/matrix classes, color conversion, type validation

### WCSPaths
- **Purpose**: Standardized path management with cross-platform compatibility
- **Type**: Resource class (extends Resource)  
- **Responsibility**: Manages all game directory structures and file paths
- **Key Features**: Path utilities, cache management, file validation

## Usage Examples

### Accessing Constants
```gdscript
# Get ship limits
var max_ships: int = WCSConstants.MAX_SHIPS  # 400
var max_weapons: int = WCSConstants.MAX_WEAPONS  # 700

# Validate counts
if WCSConstants.validate_ship_count(ship_count):
    print("Ship count is valid")

# Use mathematical constants
var radians: float = WCSConstants.angle_to_radians(90.0)  # PI/2
```

### Type Conversion
```gdscript
# Convert WCS vector to Godot Vector3
var wcs_vec: WCSTypes.WCSVector3D = WCSTypes.WCSVector3D.new(1.0, 2.0, 3.0)
var godot_vec: Vector3 = wcs_vec.to_vector3()

# Convert colors
var color: Color = WCSTypes.vertex_color_to_godot(255, 128, 64, 255)

# Fixed-point conversion
var fix_value: int = WCSTypes.float_to_fix(1.5)
var float_value: float = WCSTypes.fix_to_float(fix_value)
```

### Path Management
```gdscript
# Get standard paths
var mission_path: String = WCSPaths.get_mission_path("training1")  # res://data/missions/training1.fs2
var model_path: String = WCSPaths.get_model_path("fighter")  # res://data/models/fighter.pof

# Validate paths
if WCSPaths.validate_pathname_length(path) and WCSPaths.file_exists(path):
    print("Path is valid and exists")

# Convert WCS paths to Godot format
var godot_path: String = WCSPaths.wcs_to_godot_path("data\\models\\ship.pof")
```

## Architecture Notes

### Design Decisions
1. **Static vs Instance Methods**: Constants and utilities use static methods for global access without instantiation
2. **Resource Classes**: WCSConstants and WCSPaths extend Resource for potential serialization and editor integration
3. **Type Safety**: All functions use strict static typing to prevent runtime errors
4. **Godot Integration**: Seamless conversion between WCS types and Godot native types

### C++ to Godot Mapping
- **C++ globals.h constants** → **WCSConstants static constants**
- **C++ vec3d/matrix structs** → **WCSTypes inner classes with Godot conversion**
- **C++ fixed-point math** → **WCSTypes conversion functions**
- **C++ platform paths** → **WCSPaths cross-platform utilities**

### Performance Considerations
- **Constant Access**: All constants are compile-time values with zero runtime overhead
- **Type Conversion**: Conversion functions are lightweight with minimal allocations
- **Path Operations**: Path utilities use Godot's optimized string operations
- **Memory Management**: All classes use appropriate Godot base classes (Resource/RefCounted)

## Integration Points

### Dependent Systems
All other WCS conversion systems depend on this foundation:
- **CF-002 Platform Abstraction**: Uses WCSConstants and WCSPaths
- **CF-003 Debug System**: Uses constants for configuration and validation
- **CF-004-006 File System**: Uses WCSPaths for all file operations
- **CF-007-009 Math Framework**: Uses WCSTypes for vector/matrix operations
- **CF-010-012 Data Parsing**: Uses all foundation classes for validation and conversion

### External Dependencies
- **Godot Engine**: Core classes (Resource, RefCounted, Vector3, Color, etc.)
- **GDScript**: Static typing system and built-in functions

## Testing Notes

### Test Coverage
- **WCSConstants**: 100% coverage of all constants and validation functions
- **WCSTypes**: Complete type conversion and validation testing
- **WCSPaths**: Path utilities and validation functions tested

### Test Structure
```
target/tests/unit/
├── test_wcs_constants.gd  # Constants validation and utility testing
├── test_wcs_types.gd      # Type conversion and enum testing  
└── test_wcs_paths.gd      # Path management and validation testing
```

### Running Tests
```bash
# Using GUT test framework
godot --headless --script=res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit/
```

## Implementation Deviations

### Intentional Changes from C++ 
1. **Directory Separators**: Godot uses forward slashes universally, eliminating platform-specific separator handling
2. **Memory Management**: Godot's automatic memory management replaces C++ manual memory handling
3. **Type System**: GDScript static typing provides type safety without C++ pointer complexity
4. **Path Handling**: Godot's resource system (res://, user://) replaces C++ absolute paths

### Justifications
- **Simplified Architecture**: Leveraging Godot's built-in systems reduces complexity and maintenance burden
- **Cross-Platform Compatibility**: Godot handles platform differences automatically
- **Type Safety**: Static typing prevents common C++ pointer and type conversion errors
- **Performance**: Godot's optimized implementations often exceed custom C++ code performance

## Critical Dependencies
This foundation package is on the **absolute critical path** - no other system can be implemented until these core definitions are complete and tested. All development scheduling must account for foundation completion before any dependent work begins.

## Version Compatibility
- **Godot Version**: 4.2+ required for full static typing support
- **GDScript Version**: Latest syntax with typed collections and strict typing
- **WCS Compatibility**: All constants and types maintain exact WCS behavior compatibility