# Core Filesystem Package

## Overview

The Core Filesystem package provides a comprehensive file system abstraction layer for the WCS-Godot conversion project. It implements WCS-compatible file operations while leveraging Godot's strengths for modern, efficient file handling.

**Primary Purpose**: Bridge WCS legacy file systems (including VP archives) with Godot-native file operations through a unified, high-performance API.

## Package Structure

```
scripts/core/filesystem/
├── CLAUDE.md                     # This documentation
├── file_manager.gd               # Main file system manager (singleton)
├── file_utils.gd                 # Utility functions and convenience methods
└── ../archives/                  # VP archive support (separate package)
    ├── vp_archive.gd
    ├── vp_file_access.gd
    └── vp_archive_manager.gd
```

## Key Classes

### FileManager (Core Class)
**File**: `file_manager.gd`  
**Type**: Singleton (RefCounted)  
**Purpose**: Central file system coordinator with WCS path type resolution

**Key Features**:
- WCS-style path type enumeration (DATA, MAPS, SOUNDS, etc.)
- Transparent VP archive integration
- Intelligent file caching with LRU eviction
- Cross-platform path resolution
- Access statistics and monitoring

**Usage Example**:
```gdscript
# Initialize the file system
var file_manager: FileManager = FileManager.get_instance()
file_manager.initialize("path/to/wcs/root", "path/to/user/data")

# Read a configuration file with automatic path resolution
var config_content: String = file_manager.read_file_text("settings.cfg", FileManager.PathType.CONFIG)

# Open a model file for reading
var model_file: FileAccess = file_manager.open_file("fighter.pof", FileManager.AccessMode.READ, FileManager.PathType.MODELS)

# Cache management
file_manager.configure_cache(true, 100)  # Enable 100MB cache
var stats: Dictionary = file_manager.get_cache_stats()
```

### FileUtils (Utility Class)
**File**: `file_utils.gd`  
**Type**: Static utility class  
**Purpose**: High-level file operations and WCS-specific convenience functions

**Key Features**:
- Extension management (add, remove, check)
- Directory operations (create, remove, scan)
- File operations (copy, move, checksum)
- Config file parsing (WCS-style INI format)
- Pattern matching and file searching
- VP archive extraction utilities

**Usage Example**:
```gdscript
# Extension utilities
var filename_with_ext: String = FileUtils.add_extension("ship", "pof")  # "ship.pof"
var extension: String = FileUtils.get_extension("texture.pcx")  # "pcx"

# File operations
FileUtils.copy_file("source.txt", "backup.txt")
var checksum: int = FileUtils.calculate_file_checksum("important.dat")

# Directory scanning
var sound_files: PackedStringArray = FileUtils.get_file_list("sounds/", PackedStringArray([".wav", ".ogg"]))

# Config file handling
var config: Dictionary = FileUtils.read_config_file("game.cfg")
FileUtils.write_config_file("settings.cfg", {"Audio": {"volume": "80"}})

# Pattern matching
var mission_files: PackedStringArray = FileUtils.find_files_matching("missions/", "*.fs2")
```

## Architecture Notes

### Path Type System
The package implements WCS's original path type system with 37 distinct content categories:

```gdscript
enum PathType {
    ROOT = 1,           # Base game directory
    DATA = 2,           # General data files
    MAPS = 3,           # Textures and images  
    MODELS = 5,         # 3D model files (.pof)
    TABLES = 6,         # Game data tables (.tbl)
    SOUNDS = 7,         # Audio files
    MISSIONS = 30,      # Mission files (.fs2)
    # ... and 30 more types
}
```

Each path type has:
- **Relative Path**: Directory location relative to root
- **Extensions**: Valid file extensions for the type
- **Parent Type**: Hierarchical relationship

### VP Archive Integration
The filesystem seamlessly integrates with VP archives:

1. **Transparent Access**: Files from VP archives appear as regular files
2. **Priority System**: Filesystem files override VP archive files
3. **Lazy Loading**: VP archives are only opened when needed
4. **Memory Efficiency**: Archive contents are cached intelligently

### Caching Strategy
**LRU Cache Design**:
- Configurable memory limits (default 50MB)
- Automatic eviction of least recently used files
- Cache hit ratio tracking
- Size-based entry filtering (large files bypass cache)

**Cache Benefits**:
- Reduced VP archive access overhead
- Improved performance for frequently accessed files
- Memory usage monitoring and control

## Integration Points

### With VP Archive System
```gdscript
# FileManager automatically integrates with VPArchiveManager
var vp_manager: VPArchiveManager = VPArchiveManager.get_instance()
var archive_file: VPFileAccess = vp_manager.open_file("ship.pof")
```

### With Debug System
```gdscript
# FileManager respects debug console settings
var debug_manager: DebugManager = DebugManager.get_instance()
debug_manager.log_info("FileSystem", "Cache stats: %s" % file_manager.get_cache_stats())
```

### With Error Management
- All file operations include comprehensive error handling
- Graceful fallbacks for missing files
- Detailed error logging with context

## Performance Considerations

### Memory Usage
- **File Cache**: Configurable, monitored, with LRU eviction
- **VP Archives**: Lazy-loaded, shared instances
- **Path Resolution**: Cached internally for repeated lookups

### I/O Optimization
- **Batch Operations**: FileUtils provides bulk file operations
- **Smart Caching**: Frequently accessed files stay in memory
- **Archive Efficiency**: VP files read once, data cached

### Cross-Platform Compatibility
- **Path Separators**: Automatic normalization for Windows/Linux/macOS
- **Case Sensitivity**: Handled transparently
- **File Permissions**: Proper error handling on restricted systems

## Testing Strategy

### Unit Test Coverage
**Files**: `tests/unit/test_file_manager.gd`, `tests/unit/test_file_utils.gd`

**Test Categories**:
1. **Basic Operations**: Read, write, delete, exists
2. **Path Resolution**: All 37 WCS path types
3. **Cache Management**: LRU eviction, memory limits, statistics
4. **Error Handling**: Invalid paths, missing files, permission errors
5. **Cross-Platform**: Path separators, case sensitivity
6. **VP Integration**: Archive file access, fallback behavior
7. **Performance**: Large files, memory usage, concurrent access

### Integration Testing
- Real VP archive compatibility
- Performance benchmarks with large datasets
- Memory usage validation under load

## Common Patterns

### File Reading Pattern
```gdscript
# Pattern: Read file with fallback
var content: String = file_manager.read_file_text("config.cfg", FileManager.PathType.CONFIG)
if content.is_empty():
    content = _get_default_config()
```

### Configuration Management Pattern
```gdscript
# Pattern: Load/save game settings
var settings: Dictionary = FileUtils.read_config_file("settings.cfg")
settings["Graphics"]["resolution"] = "1920x1080"
FileUtils.write_config_file("settings.cfg", settings)
```

### Asset Discovery Pattern
```gdscript
# Pattern: Find all assets of specific type
var ship_models: PackedStringArray = FileUtils.find_files_matching("data/models/", "*.pof")
for model_file in ship_models:
    _load_ship_model(model_file)
```

### Cache Monitoring Pattern
```gdscript
# Pattern: Monitor and adjust cache performance
var stats: Dictionary = file_manager.get_cache_stats()
if stats["hit_ratio"] < 0.7:  # Less than 70% hit ratio
    file_manager.configure_cache(true, stats["max_size"] * 2)  # Double cache size
```

## Future Enhancements

### Planned Features
1. **Async File Operations**: Non-blocking file I/O for large files
2. **File Watching**: Automatic reload on file changes during development  
3. **Compression Support**: Transparent compression for save files
4. **Network Files**: Remote file access for multiplayer scenarios
5. **Mod Support**: Layered file system for game modifications

### Performance Optimizations
1. **Memory Mapping**: For very large files (>100MB)
2. **Parallel Loading**: Multi-threaded file operations
3. **Smart Prefetching**: Predictive file loading based on usage patterns

## Security Considerations

### Path Validation
- All file paths are validated and normalized
- Directory traversal attacks prevented (.., absolute paths)
- File extension validation for each path type

### Access Control
- Read-only access to VP archives
- User directory isolation for save files
- Proper error handling for permission denied scenarios

## Troubleshooting

### Common Issues

**File Not Found Errors**:
```gdscript
# Check if file exists before accessing
if file_manager.file_exists("missing.txt", FileManager.PathType.DATA):
    var content = file_manager.read_file_text("missing.txt", FileManager.PathType.DATA)
```

**Cache Memory Issues**:
```gdscript
# Monitor and adjust cache size
var stats = file_manager.get_cache_stats()
if stats["current_size"] > stats["max_size"] * 0.9:
    file_manager.configure_cache(true, stats["max_size"] / 2)
```

**VP Archive Problems**:
```gdscript
# Check VP archive status
var vp_manager = VPArchiveManager.get_instance()
var archives = vp_manager.get_loaded_archives()
print("Loaded VP archives: ", archives)
```

### Debug Information
```gdscript
# Get comprehensive file system status
print("File Manager Stats:")
print("  Cache: ", file_manager.get_cache_stats())
print("  Access: ", file_manager.get_access_stats())
print("VP Manager Stats:")
print("  Archives: ", VPArchiveManager.get_instance().get_cache_stats())
```

---

This package forms the foundation for all file operations in the WCS-Godot conversion, providing a robust, efficient, and maintainable abstraction layer that honors WCS conventions while leveraging Godot's capabilities.